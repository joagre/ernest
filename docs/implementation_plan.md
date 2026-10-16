# Ernest Implementation Plan

The roadmap: what will be built, in what order, and what is built already. Why anything is the
way it is belongs to [`decisions.md`](decisions.md), what the language is to
the report in [`report/`](../report/), how the code is arranged to
[`architecture.md`](architecture.md), and the commands and what the toolchain does not do yet
to [`development.md`](development.md).

Read "Where we are" first, then the table of milestones; the milestones to come follow in order. A gap
stands in the milestone whose item closes it, a defect of OTP's in [`otp_bugs.md`](otp_bugs.md),
and a feature declined in the log's *Later*; nothing stands between.

---

## Where we are

**MVP 3.2 is in progress.** Its items 1 to 10 are done, code crossing with a spawn, the bare
node, `Code`, the pick, the deployment guide and the repository laid out again, and its item 11,
Ernest 0.4.0, waits for the user's word. MVP 3.26, two subtractions from the type system, is done
(2026-10-16), and so are the tools' five speed changes and the programs tests' defects. Every
paragraph before the tag, in MVP 3.2 below, is done (2026-10-17); item 11 waits for the user's word.
The road to 0.5.0 is MVP 3.27 when the user's machines are ready, MVP 3.3 the tour and MVP 3.9
the review; the attached shell, ehttpd, the website, the shell's second round and the back end
follow 0.5.0 (the log's *The Road to 1.0, Ordered*, its end set at 0.5.0 on 2026-10-13). A
finished milestone is a row of the table below, its reasons in the log entries the row names.

---

## Milestones

| | What | Done | Release | Where its reasons are |
|---|---|---|---|---|
| MVP 1 | the chain: parser, types, BEAM | 2026-09-18 | tag `mvp1` | the log's entries of 2026-09-17 and 2026-09-18; [`architecture.md`](architecture.md) |
| MVP 2 | the rest of the report on one node | 2026-09-19 | | the log's entries of 2026-09-19 |
| MVP 2.5 | a complete standard library | 2026-09-20 | | *The Erlang Standard Library, Read for Ernest*, *Fs by Its Structure, and the Table*, *One Token for the Project* |
| MVP 2.9 | an Emacs major mode | 2026-09-23, out of order | | [`emacs_mode.md`](emacs_mode.md) |
| The report read as a Wirth report | the report read against Wirth's register and §0, about thirty issues decided one at a time | 2026-09-23 and 2026-09-24 | | the log's entries of those two days, one an issue |
| MVP 2.61 | the guide as the user's document | 2026-09-24, out of order | | the log's entries of 2026-09-24 |
| MVP 2.6 | the shell | 2026-09-25 | | [`shell_design.md`](shell_design.md); the log's entries from 2026-09-20 to 2026-09-25 |
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
| MVP 2.99b | what the release review left, names that read among it; operations records: the requirement `needs a.compare`, a record filled from a namespace, an ordered set and an ordered map; running as a service | 2026-10-03 | | *The Erlang Read and Renamed*, *The Ernest Read and Renamed*, *The Requirement Built*, *MVP 2.99b's Questions, One by One*, *`Address.ask` Is Taken Out*, *The Operators Stay Ernest*, *The Hardening Built*, *The Runtime as a Service, Built*, *The Service Manager's Checks*, *The Reaper's Look at Rest*, *The Boundary Trusts a Type Variable*, *The Report in Three Files*; `findings.md` as it stood at `d6996f1` |
| The full review's findings | the 570 findings of MVP 2.99c's item 6, worked before its release | 2026-10-05 | | *The Full Review Run*, *The Full Review's Questions, One by One*, *A Release Carries No History*; `findings.md` as it stood at `0d2de61` |
| MVP 2.99c | the language argued: the type system's argument, generated programs, the grammar and the library's laws as machines; then a release, Ernest 0.3.0 | 2026-10-05 | tag `v0.3.0` | *The Language Argued Before Peers*, *The Grammar Generated Against*, *The Library's Laws Held*, *The Typed Programs Generated*, *The Replies Generated*, *The Type System Argued*, *What Erlang Held, Moved*, *The Release Review Before 0.3.0*; [`soundness.md`](soundness.md) |
| Ernest 0.3.1 | the documentation rewritten: the manual pages, the examples, the guide and the report's precision, from MVP 2.99d's items 4, 5, 7 and 8 | 2026-10-05 | tag `v0.3.1` | MVP 2.99d's entries |
| MVP 2.99d | the library stands on the host, measured with the prelude and the emitted code, and the report's and the guide's feedback | 2026-10-06 | | *MVP 2.99d's First Measurements*, *The Prelude Measured*, *The Library Stands on the Host*, *The Emitted Code Measured*, *Spawn Keeps Its Wait*, *Kept Only for Speed, Taken Out*, *Fs.removeAll Removed*; [`otp_bugs.md`](otp_bugs.md) |
| The shell shows a bracket's match | a closing bracket stands the cursor on its match, ahead of MVP 4.3 | 2026-10-06 | | *The Shell Shows a Bracket's Match* |
| MVP 3.0 | peers: one program on several nodes, by its proposal | 2026-10-09 | | [`mvp3.0.md`](proposals/nodes_and_code/mvp3.0.md); *The Carrier*, *Addresses, Messages and Monitors Across Nodes*, *Calls Across Nodes*, *A Node's End and Its Reload*, *The Module Peer*, *Load and Balancer*, *The Module Json*, *The Tests Wait on What They Mean*, *The Milestones After 3.0, Weighed Again*, *The Plan Rewritten from the Split Proposals*, *MVP 3.0's Findings Decided* |
| MVP 3.1 | code by its hash: a hash for each definition, nodes of different builds on one floor, the shell's reload by hash, termination told, and `Standing`; then a read of what it built | 2026-10-10 | | [`mvp3.1.md`](proposals/nodes_and_code/mvp3.1.md); *The Canonical Form, Built*, *The Code Table, Built*, *The Spawn by Hash, Built*, *The Shell's Reload by Hash, Built*, *Termination Told, Built*, *Standing and the Refusal, Built*, *What MVP 3.1 Costs, Measured*, *MVP 3.1 Read*, *MVP 3.1 Done*, *The Feedback Pass Before MVP 3.2*, *A Milestone for Placing Work by Load*, *The Back End Last* |
| MVP 3.25 | placing work by name: `Peer.compute` on a named peer, `Peer.utilization` with the node's measure its maintainer's, and `Placement` in `Balancer`'s place | 2026-10-11 | | [`suggestion.md`](proposals/balancer/suggestion.md); *Placing Work by Name* |
| MVP 3.26 | kill darlings: the reply's obligation and `!` gone, `receiving M` in place of `with M` on a function that receives alone, the value restriction relaxed for data, the held replies gone, and the guide's *A library that waits* | 2026-10-16 | | [`proposal.md`](proposals/kill_darlings/proposal.md); *Kill Darlings*, *§0 Read Again* |
| MVP 3.2 | code with a spawn: the exchange, the bare node, a unit let go, and `Code`; then a release, Ernest 0.4.0 | items 1 to 10 done by 2026-10-15; item 11, the release, waits for the user's word | | below |
| MVP 3.26 | kill darlings: the reply's obligation goes, and the mark on every function that acts, `with` becoming `receiving`; before MVP 3.2's item 11, the tag | decided 2026-10-14 with the user; `docs/proposals/kill_darlings/` is the specification | | below |
| MVP 3.27 | measured across machines: item 7's numbers again between four machines the user gives, one on a separate LAN, and item 8's push against the pull across them | made 2026-10-13; when the user's machines are ready, after MVP 3.2's item 8; the guide does not wait for it, and the release only where the machines come first | | below |
| MVP 3.3 | the tour, `tour/`: a third way into Ernest beside the report and the guide, one program grown from one node to a rolling upgrade | outline to be written with the user | | below |
| MVP 3.9 | the review, and Ernest 0.5.0: the full review, the numbering decided once, a release with no promise of stability | the end of the planned road, 2026-10-13; the split of `make test` done 2026-10-13, taken early | | below |
| MVP 4.0 | `--verbose` on `ern build`, `ern run` and `ern test`, then a shell attached to a running node: each input run on the node, its processes listed and its code loaded and reloaded from the prompt, as `erl -remsh` attaches | made 2026-10-13 from MVP 4.3's item 4; the first milestone after 0.5.0 | | below |
| MVP 4.1 | ehttpd, an HTTP/1.1 server in Ernest in a repository of its own, and the libraries it wants | `libs/markdown` done 2026-09-25 | | below |
| MVP 4.2 | the website, served by ehttpd: what Ernest is, its characteristics, the three doors, and a live shell in the browser | | | below |
| MVP 4.3 | the shell's second round | | | below |
| MVP 4.4 | after 0.5.0: a back end to BEAM's own instructions, Ernest's types as the loader's typed registers | a proposal first | | below |

---

## MVP 3.2 (code with a spawn), about four weeks

Designed in [`mvp3.2.md`](proposals/nodes_and_code/mvp3.2.md), split from `mvp3.1.md` on
2026-10-09 and read through with the user the same day; its reasons are
[`code.md`](proposals/nodes_and_code/code.md)'s sections 1, 3 and 5. It stands on MVP 3.1
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

**Second, before item 1, MVP 3.25's discussion.** Held on 2026-10-11: the proposal was read
through, rewritten to its shape B and decided, and MVP 3.25 was built before this milestone's item
1, on which nothing here depends (the log's *Placing Work by Name*).

**Third, before item 1, an example of typed channels.** Written on 2026-10-10 (the log's *The
Typed-Channels Example*): `examples/typed_channels.ern`, an answer of `guide/faq.md` since 2026-10-16, a counter whose mailbox has one type, met
with four doubts a reader may have of a typed channel, each answered in a line of `main` under a
numbered comment with the refused line quoted beside it in the compiler's words, a send of another
type, a reply answered twice, a clause that cannot run; and `examples/typed_channels_nodes.ern`, the
same counter on a node of its own, offered under a key and found and called from another, the hash
the key carries and a lost connection's cost in one comment. Both are plain programs: what the first
draft carried of `restarting`, `Os.terminating`, `kill`, monitors, `Standing`, a reply answered from a
peer and a foreign send was cut, each a concept beside the one the example teaches. Run by the tests
as the other examples are, and on two real nodes. What writing it found is `language_feedback.md`'s
101 and 102; it seeds the tour's outline (MVP 3.3).

**Fourth, before item 1, names read as a newcomer reads them.** `Peer.Key(m)` became
`Peer.Service(m)` on 2026-10-10, with `Peer.service`, `"services"` in the configuration and the
fault's words (report §8.7, Appendix E.27; the log's *The Service Named*); and with it, the same
day, fifteen names a cold reader could not predict, `Standing` to `Proxy`, `via` to `adapted`,
`Foreign.from` to `Foreign.term`, `Process.info` to `Process.status`, `Char.toInt` to
`toCodePoint`, `List.remove` to `removeAt`, the unordered `foldLeft` to `fold`, `foreach` to
`forEach`, `Terminal.columns` to `width`, `Os.terminating` to `termination`, `Random.next` to
`nextInt`, `Fs.makeLink` to `makeSymlink`, `Entry.mtime` to `modified`, `FaultReport.peer` to
`spawnedBy` and `Link.address` to `url`, and `slice` taking an end index (the log's *Names Read as
a Newcomer Reads Them*; E.0's tenth shape rule), all before 0.4.0 freezes a name. The reviews'
newcomer now lists the names it could not predict. On 2026-10-13, after item 9, the library
`Load` became `Utilization`, since in Ernest `load` loads code and the library reads the
utilization §8.7 names (report Appendix G.4; the log's *Placing Work by Name*). The same day the
spelling became American throughout, in every document, name and message, `Color` and the
morning's `Utilization` among the names respelled (`docs/style.md`; the log's *American English
Throughout*). The same day `make man` came to write `man/`'s pages from `main`, the libraries
written since 0.3.1 among them, and `make manual` the manual pages alone (the log's *The Pages
Written From `main`*).

**Fifth, with item 3, two shell tests under load.** Done 2026-10-11, with item 3. `command_argument`
in `test/ern_shell_tests.erl` had failed once in the whole suite, its final bytes not holding the
completed line before the listing: after `C-c` the session's new prompt reaches the screen only
once the screen is flushed, so keys typed before it painted the line without the prompt, and a wait
for the listing alone met that paint; every such wait now waits for the completed line with its
prompt, which the screen paints only with the listing under it. `reader_and_screen_ends` waited a
fixed 300 ms for nothing the input does not already show; the input itself now ends the reader or
the screen while it runs, and the session's bound on a failure, 10 seconds, which a shell started
under load outlasted before its first prompt, is the file's 30. No number chosen.

1. **The report and the soundness argument.** Done 2026-10-11. §8.7's *The exchange*: a peer
   that lacks the function asks for its reach, the four frames beside the nine, each form
   verified against its hash on arrival and held apart until the reach is whole, one load,
   `Other(text)` with the peer's reason for a reach it cannot compile or load, a peer that may
   spawn on a node running what it sends, and the bare node in *Its start and its end*; §11.2's
   bare node in place of the refusal, *What a node holds* with the let-go, and a shell's function
   carried with its code; §8.1, §8.5, §8.6 and §11.8 for the bare node's entry process; §6.10's
   fix crossing with the spawn and its upgrade written over `Code.running`, which §3.11 makes a
   form; §10's cost line and the let-go's limits; Appendix E.28's page for `Code` in prose, its
   listing landing with item 6, since the tests hold Appendix E's listings to `stdlib/`; E.1 and
   E.27; G.1; Appendix F's bare node, code frame and exchange, and the glossary's; Appendix H's
   form crossing; `soundness.md`'s section 7. The named decision: a reply a failed spawn's
   function held ends its call at once, `Address.call` `None` and `callForever` `Fault("callee did
   not start")` (§6.6, §8.7), built in item 3. The proposal's `Refused` is `Other(text)`, since
   `Io.Error`'s `Refused` carries no text (the log's *The Report for Code with a Spawn*). With
   the build, as it reaches each: `architecture.md` for the exchange's process and the let-go;
   `memory.md` for what a node holds of received code and when it lets go; `docs/development.md`'s
   table, from which the refusal of a node without a program goes in item 5.
2. **The limit a table sets.** Done 2026-10-11, by item 1's sentences: a unit whose function an
   `Ets.Table` holds is never let go, since the host's check sees a process's functions and not a
   table's, stated in §10, §11.2 and G.1 and counted against the limits of section 7; no refusal
   of the compiler's (the review of 2026-10-09, S7, §0's principle 5). Its test, that such a unit
   survives a sweep, needs the sweep, and is item 4's. Subsumed 2026-10-12 by item 4's decision: no
   unit is let go, so a table's unit is held as every unit is, G.1's sentence went, and the test
   with it.
3. **The exchange.** Done 2026-10-11. `ern_exchange`, one registered process on each node beside
   the gateway, both parts: a peer that lacks a spawned or computed function's identity asks the
   spawner's node for the reach, the node answers the identities the function reaches, code and
   types, the reach's bindings and its foreign declarations with the host's module and function,
   from the code table and the forms it holds, the build's read from the unit's `.erc` and a
   session's kept in the code table beside the code, the peer answers `NotLoaded` for a module or
   a binding's value it lacks before any code crosses, or the identities it lacks, and the node
   sends a code frame for each, a group whole in one, dependencies first; the four frames beside
   MVP 3.25's nine, thirteen; each frame verified against its hash as it arrives and held apart,
   the units that hold what the peer said it holds pinned meanwhile; a faulty frame ending the
   connection; two spawns on one identity sharing one exchange; a loss dropping the exchanges
   asked of the lost node; a spawner's node that no longer holds the reach failing the spawn with
   `Other`; a reply a failed spawn's function held ending its call at once, `None` and
   `Fault("callee did not start")`, and the end's telling of a subscriber going on without it
   (§6.6, §8.6, §8.7). A reach complete and verified answers `Other` naming item 4, which compiles
   it, listed in `docs/development.md`'s table. The log's *The Report for Code with a Spawn*
   records the decisions, and item 4 names what it plugs in.
4. **A unit on arrival, and the let-go.** Done 2026-10-12. Every unit is made by the back end from
   the canonical forms alone, the build's path typed tree, form, unit, and its functions are named
   by their position in it, `'$N'`, a lifted local `fn` `'$N.P'`, the entry a spawn on a peer starts
   `'$N.P.entry'`, so that a unit adds one atom, its name, and every caller by name finds its
   function through the code table (§11.1; the first half, below). The definitions of one exchange
   are one unit under a name from the node's pool, `ern$1`, `ern$2`, each reference linked through
   the code table and the prelude's environment, compiled by the build's back end from the same
   forms and loaded whole by the host's atomic load, nothing of it running before; the code frame
   and the `.erc` carry beside the form the definition's name, the lines of its source and what
   prints its types as its module does, the name as text and the locals numbered, so that a received
   definition's sites, faults and traces read as the sender's, its unit named as the node names it
   (§8.7, §11.1, §11.2); a `foreign fn` spawned or computed by its name crosses as its declaration
   with its type, the peer calling the host's function through §8.4's check from a function of the
   arrival's own, `NotLoaded` where the module or its function is not there; a unit exports the
   functions its module exports and every binding's getter, and a definition the peer holds in no
   unit that exports its function is lacked and crosses again (§8.7, §11.1), since exporting every
   function cost the host compiler's narrowing of a private function's arguments, 19.5% on the
   bench's operator scenario; a compiled module the shell loads beside another unit of its name is
   made a unit of its own from its `.erc`'s forms; a `foreign fn` whose implementation names a unit
   is refused; the build emits a module once every module its forms reference is checked;
   `docs/development.md`'s three rows are lifted and `docs/memory.md` measured again. **The let-go,
   decided 2026-10-12 with the user:** a unit once loaded is held for the node's life (§11.2, §10,
   Appendix F; `soundness.md`'s section 7), since the host tells, since OTP 20, of the code on a
   process's stack alone and of no function a process holds, and its counts of module names,
   exports, function entries and atoms never fall, so a let-go would give names back and free the
   code's memory and nothing else, and the shell's rule, keeping a unit whose code builds a function
   value, would fire for almost no unit; the node says once at four fifths of a count, a load or an
   arrival that would pass one fails as one the node cannot load, and a node restarted holds its
   build and is sent the rest again; G.1's table sentence went with it, and item 2's test; item 3's
   pinning went, nothing being let go; item 7 measures what an upgrade and a development day add to
   the counts, and item 9's guide says when to restart (the log's *The Report for Code with a
   Spawn*, and *Later*). The first half, every unit from its forms and its functions named by their
   position, is built, 2026-10-12 (the log's *The Report for Code with a Spawn*), and decided what
   the code met: two definitions of one module whose forms are one term are one definition, a
   reference to either to the first declared (Appendix H); a fault's cause writes a type variable by
   its order, `a`, `b`, since a form holds no annotation's name (§7.4); a `foreign fn` whose
   implementation names a unit, `ern@...`, is refused at compile time (§11.1), the refusal the
   second half's to build; a code frame carries the definition's name and the lines of its source
   beside its form, as the `.erc` records them, so that a received definition's code shows, faults
   and reports as the sender's does (§8.7, §11.1, §11.2), the name as text and the locals numbered,
   so that a frame makes no atom of a name; and the build emits a module once every module its forms
   reference is checked, so that a standard library module reached through a prelude name or an
   operator alone has its position whatever the order, which today's order satisfies by chance.
5. **The bare node, and the shell.** Done 2026-10-13. `ern run --config-dir dir` with no `.erc`
   starts a bare node: the standard library's bindings evaluated and no other, the entry process
   waiting under the site `bare node`, the node listening and taking what its peers spawn and
   compute on it, their code crossing, offering what the processes spawned on it offer, answering
   its utilization and placed on by name, ending by termination with §11.8's status, by a spawned
   process's `Os.exit` or by a stream that can no longer be written; refused without `listen`, since
   it never dials, while a shell with no `.erc`, which dials from its prompt, is not; `--main` with
   no file refused, and no `--config-dir` with no file the usage error it was, since `--config-dir`
   is what makes a run a node (§8.1, §8.5, §8.6, §8.7, §11.2, §11.8). A defect of item 4's exchange,
   found by the test and fixed with it: a lambda crosses as the definition that encloses it, whose
   form may name a binding or a foreign function the lambda does not, which the peer could not link,
   so a lambda in a `main` that names a program binding could not run on a bare node; now the code
   frame carries the host's module and function of each foreign declaration its definition calls,
   what the definition names beyond the spawned function's reach that the peer lacks is linked to a
   fault that names it, which no process reaches, and the arrival records every declaration it was
   sent, a lacked one's module and function as text, so that a held definition's `NotLoaded` names
   the module and the node ships the definition, and a lacked foreign function's declaration, onward
   to a third node, which links it itself (§8.7, §11.2; `soundness.md`'s section 7).
   `docs/development.md`'s last row is lifted. Tests on real nodes: a lambda spawned onto a bare
   node with its code, a compute, a service offered from a spawned process and found, utilization
   and `Placement.leastBusy`, `NotLoaded` for a library binding the bare node does not evaluate, the
   sender's sites in the bare node's faults, the second spawn crossing nothing, `ern stop` with
   status 143 and `Os.exit(3)` with status 3, a lambda beside a binding and a foreign function it
   does not use, a relay over four nodes, and the refusals (the log's *The Report for Code with a
   Spawn*).
6. **`Code`.** Done 2026-10-13. `stdlib/code.ern`, Appendix E.28: `Code.load(path)` loads a compiled
   module and its reach, found under the module's root and then on the node's load path, each form
   verified against its hash, each module the node's own unit or one made from its forms beside
   another of its name, in one atomic load, the bindings of the module and of its reach that have no
   value evaluated in the calling process in §8.5's order, a faulting one loading nothing, killing
   what it started and answering `Left(Other(text))`, `Left(Invalid)`, `Left(NotFound)` and the
   host's error as E.28 states them, a module loaded again making no unit; `Code.hashes(path)`, each
   definition's name and hash in hexadecimal; `Code.running(f)`, a form of §3.11 declared `running(f
   : a)` and refused as a value, the call's `m` tied to `f`'s mailbox type, the processes whose
   stack holds a frame of `f` within the 64 frames the host keeps, the runtime keeping twelve from
   its start, which E.21 promised and nothing set, and 64 from the first call (§10). An example may
   begin with declarations (E.0 shape rule 6), so `Code`'s page shows §6.10's pattern.
   `examples/upgrade_tool.ern`, now `examples/upgrade/`, the proposal's tool, moves a counter's processes alone and on every
   peer. §11.1 names `Code.load` as the way a build reaches a running node. Found and decided (the
   log's *The Report for Code with a Spawn*): a type that carries `Upgrade` holds a function and is
   bound to its node (§3.11), so a service upgraded by §6.10's pattern is offered through an adapted
   address (§6.5) of a type without it, stated in §6.10; two declarations whose forms are one term
   are one definition, so `Code.running(f)` lists a process on either (Appendix H, E.28); both in
   `docs/language_feedback.md`. Tests: the form's rules and refusals, `load`'s paths and its fault,
   `hashes`, `running` beneath 32 frames, a lambda not listed and none after an `Upgrade`, a trace
   of twelve frames, the upgrade over nodes with build 2's tool spawned onto build 1's node and
   `Code.load` on a bare node; `Code.load` past a host count untested, since no test may near a
   limit.
7. **The tests, the measurements and the guide.** Done 2026-10-13. The proposal's section 8 is held
   sentence by sentence, each by a named test, on real nodes where nodes can observe it: a fix
   spawned from a shell crossing with the callers whose hash changed and no unchanged definition,
   `fix_from_shell_test_`; a code frame whose bytes are not its hash's ending the connection, a
   frame of an ended exchange dropped, a frame held apart never entering the code table once the
   connection closes, and a spawn timed out then answered from one unit, `broken_exchange_test_`;
   the service with `Upgrade` in its type offered through an adapted address and moved by the tool,
   `code_upgrade_test_`; the rest by the tests of items 3 to 6; two sentences superseded, a unit let
   go and a shell fixing a service through `Upgrade`, and the four-fifths line held by unit tests
   over given counts, since no test may near a limit. The measurements are in `make bench`,
   `test/ern_code_costs.erl` tracing two nodes through a probe: a spawn crossing one, five and
   twenty definitions, a fix's callers, what an arrival and a `Code.load` add to the host's four
   counts and how many development days a node lives before four fifths of one, a raise at depths of
   8, 12 and 64, the pull's cost for item 8, and the sizes of the `.erc`s and of a code frame,
   medians over seven runs with their ranges in the log. Three defects the measurements found, fixed
   here: the spawner's node read its unit's whole `.erc` at each answer, growing with the module and
   not the reach, and a build unit's forms are now read once and kept in the code table as every
   other unit's are, a spawn crossing five definitions falling from 16 to 9 ms; every load read the
   host's counts through a text of 289 KB, 2.4 ms, and the runtime now sums what each unit adds and
   reads the host at its start, atoms at each load, and once more to confirm before it says the
   line, 13 µs; the depth switch went, 64 at the runtime's start, since a raise at 64 costs a
   fraction (§10, E.28). `Clock.monotonicMicros` (E.15), decided from `docs/language_feedback.md`
   105, so that no program of ours declares the host's clock. Found for the guide: a bare node's
   first spawn costs about 254 ms after a dial of 115, the host compiler's first run and the
   prelude's environment, which item 9 says. The two proposals' status lines say what this milestone
   built and changed.

8. **Placement by push.** Done 2026-10-13, decided the same day from `proposals/placement/push.md`,
   read back with the user, every question of its section 7. Each node that lists peers tells each
   connected one how busy it is, every `utilization-interval` milliseconds of its `ernest.conf`,
   5000 where left out and refused unless a whole number of at least one, and once as a peer
   connects, the telling carrying the teller's interval, the fourteenth frame, the gateway's since
   it owns the connections; a node holds of each peer the last utilization heard, its moment and its
   teller's interval, a peer not heard from not chosen, a utilization older than two of its teller's
   intervals not used, a peer's loss dropping its utilization; `Peer.compute(f, ms)` draws two peers
   with a usable utilization at random and runs `f` on the less busy, one taken as it is, two
   equally busy the first in the configuration's order, `Left(Unreachable)` where none has a usable
   utilization and `Left(NotListed)` where none is listed; `Peer.computeAt(name, f, ms)` is the
   compute by name, both forms of §3.11; `Peer.utilizations()` the table for a program's own rule,
   which is never a line of `ernest.conf`; `Peer.setUtilization(x)` the utilization a program
   designs, 0.0 to 1.0, a value outside faulting, told until set again or the run ends, the
   configured measure the default, which a telling reads as an ask does; the `Placement` library
   gone with Appendix G.5's content, its tests moved to `Peer`'s, the guide's §8.1 taught over the
   new names. Measured on one machine: the pick 3.6 µs, a table read and a draw, about one part in a
   hundred of a compute, three idle nodes exchanging 1.2 packets a second, the tellings replacing
   the host's ticks (the log's *Placing Work by Name*). Found and decided: a program's own rule
   cannot wrap the compute over a function parameter (§3.11), so it answers a name and the compute
   is written at the call, `docs/language_feedback.md` 106, and `List` has no `minimumBy`, 107. MVP
   3.27 measures the push against the pull across machines. Renamed the same day: `Peer.load` to
   `Peer.setUtilization` and `Peer.loads` to `Peer.utilizations`, since the number told is the
   utilization and "load" named it a second time beside `Code.load`'s verb and G.4's library (the
   log's *Placing Work by Name*).
9. **The deployment guide.** Done 2026-10-13. `guide/deployment.md`, *Running Ernest*, for the
   operator, written whole and read back by the user: one node, its directory, `ernest.conf` entry
   by entry, start, reload and stop, statuses and streams, and the service manager, moved here from
   the language guide's §9.5, which points at it; two nodes, listing each other, the connection and
   the floor, a lost peer; services and placement as the configuration sees them, the measures and
   the bare node; code across nodes as the operator meets it, what a node keeps and when to restart,
   the lines a spawn can leave; builds on one floor, a fix from a shell, a service moved by the
   upgrade tool; looking in from a shell beside a node, with what an attached shell will add (MVP
   4.0); the catalog of what a node says, each line with its cause and the operator's move; and a
   deployment end to end as a runbook over `examples/upgrade_tool.ern`, now `examples/upgrade/`. The tests run the guide:
   `test/ern_deployment_tests.erl` reads the guide's consoles and runs sections 1, 5.3 and 8 on real
   nodes, the runbook step by step with every quoted line checked, the refusals of a held
   `ernest.pid`, an existing directory and a node's own key, the statuses 0, `Os.exit`'s and 143, a
   peer frozen until it fell silent, a faulty code frame refused and the four-fifths line over given
   counts; and a catalog test holds every line sections 7 and 4.3 quote to a line the nodes tests
   see, so a changed text in the code fails the guide. Six lines of the draft were corrected to the
   code's words by it, and the runbook to what the nodes found: `ops` without `listen`, three ports
   on one machine, a shell started with no file. The guide says which of its commands the tests run
   and which are shown alone, the service manager's unit and the `kill` lines among the latter, and
   its numbers are one machine's, said so, until MVP 3.27 (the log's *The Report for Code with a
   Spawn*).
10. **The repository laid out again.** Done 2026-10-15. `stdlib/`, `libs/` and `shell/` moved
   under `src/`, `emacs/` under `editors/`, and `proposals/` and `man/` under `docs/`; `erl/`,
   `tools/` and the rest stay where they were. The rule is `development.md`'s: `src/` holds the
   Ernest a release ships, `erl/` the Erlang it ships, `editors/` the editor modes, and the rest
   serves the repository. The installation mirrors the clone, so only the installer's list of
   paths changed (the log's *The Repository Laid Out Again*). A second commit the same day named
   three applications under `erl/` for what they are, `checker`, `formatter` and `shared`, moved
   the catalog of diagnostics to `docs/` and the tests' data under `test/fixtures/`, gave `docs/`
   its index, `docs/README.md`, and left the standard library's source out of an installation
   (the log's *The Layout Completed*).
11. **The release, Ernest 0.4.0.** The first release with nodes, and the first since `v0.3.1`: the
   review before a release as [`release_review.md`](release_review.md) says, its readers over what
   MVP 3.0, 3.1 and 3.2 changed, the code's reader since `v0.3.1`, the guide's over chapter 8 and
   the deployment guide, and the argument's over `soundness.md`'s section 7; and, decided
   2026-10-13, one principles reader beside them, on Fable, reading §8.7, §11.2, Appendix E.27 and
   E.28 and the guide's chapter 8 against §0, since this milestone wrote its rules under build
   pressure and reversed two, the whole principles review being MVP 3.9's full review's to hold;
   every finding fixed, planned or dropped; then `VERSION` at 0.4.0, the `since` of every module and
   exported declaration that appeared since 0.3.1, the pages in `docs/man/`, the notes, which say what a
   program written for 0.3.1 changes and what the shell does not yet do beside a node, attach to it
   with its inputs run there, which MVP 4.0 brings and the deployment guide's section 6 says (decided 2026-10-13: nothing more goes into 0.4.0, but tables in `libs/markdown`, decided with the user the same day, the log's *Tables in `libs/markdown`*; reopened 2026-10-14 for MVP 3.26 alone, the log's *Kill Darlings*, whose two subtractions the notes then state: `with` written `receiving` where a function receives and nowhere else, and no `!`), the README rewritten from
   `docs/proposals/handouts/readme_after_mvp3_2.md`, which then goes, the language guide's §0 list
   changing with its fourth bullet, the tag `v0.4.0` and the archive (decided with the user on
   2026-10-10, the log's *Ernest 0.4.0 Ends MVP 3.2*, and on 2026-10-13 for the README).

**Before the tag: the tools' speed.** Done 2026-10-13: pages written only where out of date, a
no-op `make` 16.5 s to 14.6 s (the log's *Pages Written Where Out of Date*); and the
investigation, whose seven fixes took a no-op `make` to 13.0 s (the log's *The Tools Measured*).
Done 2026-10-16, four of the five changes decided on 2026-10-13 (the log's *The Tools Measured
Again*): `ern doc` reads a module's current `.erc` and compiles nothing where every page is
current, `index.md` is written only where its text differs, `make man` writes beside the build's
`.erc`s, and the Makefile runs its independent builds and docs side by side; a no-op `make` is
3.1 s, `make man` 4.3 s, `make test-install` 42.6 s. The fifth, `:load` taking a current `.erc`
(§11.2), is done 2026-10-16 too, its sentence corrected the same day to a form compiled from that
source and calling no module the session holds at a unit other than its own. `make diagnostics`, which started
the host once for each of the catalog's 261 rejected examples, 98.7 s, builds them in the running
host since 2026-10-16 evening, 7.6 s, of which the no-op `make` it depends on is 3 s.

**Before the tag: the installation.** Done 2026-10-16 (the log's *The Programs Tests' Bounds*):
`make install` installs every `.md` under `report/`, `guide/` and `tour/` by directory, so
`guide/deployment.md`, `why.md` and `faq.md` are installed as `language.md` is, and the install
test's link check reads every depth, where it had read the top directory alone.

**Before the tag: the design notes.** Done 2026-10-16 (the log's *The Design Notes Leave the
Proposals*): the three design notes of built components, `emacs_mode.md`, `shell_design.md` and
`install.md`, moved from `docs/proposals/` to `docs/` under their own names, and the spelling test
reads them there. `docs/proposals/emacs/` and `install/` went with them; `shell/` keeps
`attached.md`, its README pointing at the note. Each was trimmed to what its component does and
why, what it does not do going to the log, and the Emacs note keeps its table of tests. Every
pointer changed in the same commit; the log's old paths stay as history. `docs/proposals/` goes one
proposal at a time (MVP 3.9).

**Before the tag: the examples.** Done 2026-10-16 (the log's *The Examples Are Programs*):
`shout.ern` prints the port the system gave it and answers a connection's lines until the client
closes it; `services.ern` keeps a stock by `add`, `take`, `count` and `audit` read a line each, a
take of more than the stock faulting the store; the typed-channels example's doubts are
`guide/faq.md`'s *What does a typed mailbox catch*; `examples/upgrade/` holds `v1/` and `v2/`, each
built as a directory, which the deployment guide's §5.3 and section 8 run from `examples/`, and
whose `count` and its type hash alike in both; `word_count.ern` counts a file's words; `tally.ern`'s
last clause shows the rest by `Io.show` as the other two now do; the emitter's run of `services`
went, since it reads standard input, its golden file written again. Decided 2026-10-16. A
new reader's first Ernest program on disk is one of `examples/`, so each is a program its reader
would want to have written, and nothing in one is shaped by the test that runs it. Five change.
`shout.ern` serves until stopped and is talked to with `nc` from another terminal, its three
clients gone. `services.ern`'s fault comes from its input, a command read from standard input that
the store cannot take, not from a `Corrupt` it sends itself. `typed_channels.ern` leaves for the
guide, its four doubts an answer in the guide's §12 or a passage of chapter 4, the compiler's words
kept; `typed_channels_nodes.ern` stays. `upgrade_tool.ern` becomes `examples/upgrade/`, the same
module `Counter` in `v1/`, the counter alone, and `v2/`, the counter with `count2` and the tool, so
that a reader diffs the two builds and the peers at the first build lack `count2` when the tool's
spawn arrives (§8.7); the deployment guide's §5.3 and its runbook of section 8 build `v1` for the
counters and `v2` for the tool, and `test/ern_deployment_tests.erl` runs it so. `word_count.ern`
counts the words of a file named on the command line and prints each map's counts, the assertion
line gone. Three fixes beside: the README's order is by topic and says so, not by size; every
command runs from `examples/`; `file_sync.ern`'s "once Ernest has peers" goes. The `errorText` of
sixteen clauses in `file_sync.ern` and `web_server.ern` shrinks to the errors each program says in
its own words with `Io.show` for the rest, as `tally.ern` writes it; feedback item 113 decides that
`Io.Error` gets no text of its own in Appendix E. The tests build every example as
now, run each that ends of itself, and connect to each server, `shout.ern` and `web_server.ern`,
reading one answer, which only `web_server.ern`'s test did.

**Before the tag: the programs tests.** Done 2026-10-16 (the log's *The Programs Tests' Bounds*):
the install test split, each part bound by the first's own time; a timed-out run's read-only
`closed` directory made writable by the cleanup; the desk's "send at once" bound by the dial's
seven seconds with the store's port held silent, and each call by its own limit; the full run's
second phase running its areas one after another, each at the host's schedulers, `one_node` and
`replaced` bound by the sum of their waits, and `exchange`'s missing answer a deadline too short
under load, its sender's waits now the test's own; the deployment harness's two unbounded waits
bounded. Left: about sixty limits in the nodes tests are numbers of their own, derived in MVP 3.27
once each test's waits are bounded; and `answering/1` in the deployment tests, which polled `connect` in a
tight loop while a node started, waits since 2026-10-16 evening between attempts as long as it has
waited so far, since the port's answering is the only sign a node that names its port gives.

**Before the tag: the reaper and the runtime's own processes.** Done 2026-10-16 (the log's *The
Runtime's Own Processes*): the reaper traps exits and holds them, and so does the clock for an
alarm's delivery; a refused `:load` under a running wrap hung the session before. Found 2026-10-16
by item 2b's read-back. The process that applies a wrap or an adapted function (§6.5, §6.9) is linked to the
reaper, which does not trap exits, so one that ends abnormally, killed by the purge of the unit it
runs, ends the reaper and the run with it; the shell's check that no process runs a unit and
`Code.load`'s kill before its purge read the process rows alone, and such a process has none. The
shape of the fix: the runtime's own processes held by a holder that lives the run long and traps
exits, or rows of their own that the two checks read; probed first by a reload under a wrap that is
still running; a regression test in the runtime's tests. Fixed before the tag.

**Before the tag: the gateway's worker across a loss.** Done 2026-10-16 (the log's *The Runtime's
Own Processes*): one worker for a node across a loss, kept until it has taken every frame handed to
it and keeps no process, and a loss taking the spawn rows written before the node ran it, which
§8.7 now says. Found 2026-10-16 by item 2b's read-back.
When a peer's connection is lost and opened again, the gateway starts a new worker for the peer
while the old one may still hold frames, and now a process kept for an address whose function
waits: a message sent after the loss can pass one sent before it, against §6.4's order to one
address; and `ern_peer:lost/1` takes every spawn row of the node, so a spawn made after the
reconnection can be taken by the old worker's loss and answered `Unreachable`, its process killed
as its answer arrives. The shape of the fix: one worker for a node across a loss, kept until it
holds no frame and no process, running the loss in order and reading the frames after the
reconnection itself; and a loss taking only the rows written before it. Regression tests in the
gateway's and the peer's tests; fixed before the tag.

**Before the tag: purges and the runtime's deliveries.** Decided with the user on 2026-10-16
(the log's *The Runtime's Own Processes*, its last paragraph): the shell and `Code.load` keep a
refused load's units loaded, as §11.2 says and E.28 now says, so no purge remains and the second
decision below falls with the first; a delivery to a process that has ended ends with it (§6.9);
the end's tellers are held as the reaper holds its deliveries. Built the same night. Found
2026-10-16 by the read-back of the reaper's fix; four decisions, each with its recommendation. The shell's `withdraw/3` deletes and purges the units a refused `:load` or `:reload`
brought, against §11.2, where such a unit stays loaded while the session runs, and
`docs/memory.md` says what the code does: the code should follow §11.2 (principle 1), after which
no purge of the shell's reaches a running delivery. `Code.load`'s purge (E.28) kills a wrap's or an
adapted function's delivery in flight, so the monitor makes no message, against §6.9's one message
for each `monitor`: a delivery a purge kills should fault its recipient as a wrap that faults does,
its cause naming the load, with a sentence in §6.9 and E.28. A delivery whose recipient has ended
runs until its function returns, out of the program's reach: it should end with the recipient, as a
restart ends the deliveries to its process, with a §6.9 sentence. The end's tellers (`tell_all/3`)
are linked to the runner, which traps no exit, and each applies a subscriber's wrap: they should
be held as the reaper holds its deliveries. Fixed before the tag, once decided.

**Before the tag: the waits each runtime module lists.** Done 2026-10-17 (the log's *Before the Tag,
the Last Builds*): the test lives with the emitter's, thirteen primitives listed. Decided with the
user on 2026-10-16: the
deadlock count takes a standard library operation as a computation that may deliver where its
runtime module lists it in `-waits`, which §8.6 now says in one sentence; a test walks every foreign
function the standard library declares and holds the set its modules list equal to a list of its
own, so that a new primitive forces a decision, since an unlisted primitive that waits is a false
`Fault("deadlock")` no test would catch. Built before the tag.

**Before the tag: an unfixed mailbox type is `Never`.** Done 2026-10-17 (the log's *Before the Tag,
the Last Builds*), with what the build found: a variable a parameter's type holds, or that is the
definition's own mailbox type, is fixed by each call and keeps, so `fn start(f) = spawn(f)` stays
generic (§3.11, §6.2). Decided with the user on 2026-10-16: at the
end of a definition's inference, a mailbox type variable of a spawned function's address that
nothing fixed is `Never`, for `spawn`, `spawnMonitored`, `Peer.spawn` and the entry point alike, at
the shell's prompt as in a module, in place of §3.11's rule that defaults it so only where the
definition's type does not hold it and refuses it where it does, and of §4.6's refusal of a
top-level `let p = spawn(fn() = Io.println("x"))`; the compiler asked for a word whose one value
it knew (principle 1), and `Never` has no values, so nothing is ever sent to such an address
(soundness). The report first, §3.11's sentence, §6.2's rule and §4.6's example, with its soundness
sentence; then the checker at generalization, the guide's §8.1 sentence, and the `receiving Never`
marks the nodes tests restored under item 2, which go. Built before the tag.

**Before the tag: a wrap acts for its recipient.** Done 2026-10-17 (the log's *Before the Tag, the
Last Builds*): every delivery, the terminal's courier and a kept process whose target is on this node
carry whom they act for; a resource a load's binding opens itself stays its evaluator's, which E.28
says. Decided with the user on 2026-10-17 (the cold read's
D1): what a wrap opens, spawns or asks of the runtime is the process it delivers to's, as its fault
already is, and `Process.current()` in it is that process (§6.9); what an adapted function does on
arrival is the target's where the target is on that node, and where it is not, a resource it opens
ends with the application and a process it spawns heads a chain of its own (§6.5). The report's
sentences are written; then the delivery's row names the recipient as owner and root, for a socket's
and a program's ownership (E.18, E.23), a spawn's chain and a refused load's kill (§11.2, E.28), and
`Process.current`; tests of the four cases the read named. Built before the tag.

**Before the tag: what still counts at the end and in the deadlock count.** Done 2026-10-17 (the
log's *Before the Tag, the Last Builds*), with a defect found on the way, a delivery killed in a
call leaving the call's rows. Decided with the user on 2026-10-17 (the cold read's C27 and D2). The end's teller applies a subscriber's wrap in itself and
is no delivery the runtime ends, so a wrap that never finishes holds the end past the subscriber's
end or restart, against §8.6 and §6.9: the teller applies the wrap in a delivery of its own, noted
against the subscriber, which its end or restart ends. An alarm whose process has ended holds off
the deadlock fault until it fires, against §8.6 read with E.15: the clock monitors a process while it
holds an alarm of it, one monitor for each, gone as its last alarm fires, and forgets an ended
process's alarms as it forgets a restarted one's. And under `ern test` over a directory a unit is held
for its run and an adapted address made by an earlier run is dead (§11.2, D4): the kept process's
check of this start is a check of this run there, the runner's run number beside the start's, and the
runner's purge of an earlier run's code is the stated case. Regression tests for all three. Built
before the tag.

**Before the tag: `List.minimumBy` and `maximumBy`.** Done 2026-10-17 (the log's *Before the Tag, the
Last Builds*): one fold each, the guide's `least.ern` using `minimumBy`. Decided with the user on 2026-10-17
(`docs/language_feedback.md`'s entry 107): admitted under E.0's vocabulary rule, since a sequence's
smallest by a key is what a reader looks for in one call and the guide's `least.ern` wrote the sort
and the head around their absence. `List.minimumBy : (List(a), (a) -> k) -> Optional(a) needs
k.compare` and `maximumBy` likewise, `None` of an empty list, the first of equals, beside
`List.sort` in Appendix E.2 with their pages, written with the code since the listings are held to
the compiler; the guide's `least.ern` then uses `minimumBy`. Built before the tag.

**Before the tag: a module cycle through the load path.** Done 2026-10-17 whole (the log's *Before
the Tag, the Last Builds*): the build reads the load path's recorded dependencies and refuses a
cycle in its words, `ern run` and a node's start refuse one before anything runs (§11.2), and
`Code.load` answers `Left(Invalid)` (E.28). The shell's half first: the shell refuses the cycle with its modules' names, where a
cycle through a source module loaded silently and one between two compiled forms recursed for ever.
The build found three more, planned here: `ern build` accepts a cycle through the load path, against
§11.1, since it reads no recorded dependency of a load-path module, and `ern run` of such a program
never ends, and `Code.load` of a module in such a cycle faults its caller with the host's `badkey`
(E.28 names no error for it). The shape of the fix: the build reads the load-path modules' recorded
dependencies transitively and refuses a cycle naming its modules, as it refuses one among its own
sources, so that `ern run` never meets one; `Code.load` answers `Left(Invalid)` for a module in a
cycle, which E.28 then says; regression tests for the three. Found 2026-10-16 by the read-back of the
refused load's units. The shell accepts a module that uses, through the load path, a module that
uses it, which §11.1 calls an error, and in that case alone a load refused and tried again makes a
new unit. The shape of the fix: the shell refuses the cycle as `ern build` refuses one, naming its
modules, with a regression test in the shell's tests. Fixed before the tag.

**Before the tag: the shell and a private mailbox type.** Done 2026-10-16 (the log's *The Shell
on a Private Type*): the interface carries the private types an exported signature names (§11.1),
which mended the shell's binding and three faults of compiled programs the probe found, `Io.show`
of such a value, its address exposed to foreign code and its function spawned on a peer; with it,
the shell takes a compiled form only from this build of `ern` (§11.2), a private type named by a
dependent or at the prompt is refused as one the module keeps private (§11.5), §11.5 says an empty
line follows each error, and one integration test holds `bin/ern build`'s own printing to the
catalog, which `make diagnostics` building in the host no longer did. Found 2026-10-15 by use. With `count`
exported and its mailbox type `Msg` kept private, which the report's rule on exported declarations
allows (§4.2), the input `let p = spawn(fn() = Plain.count(0))` faults the shell and ends it with
status 70, `ern_descriptor:descriptor/3`'s `case_clause` on `undefined`: the compiled interface
tells the descriptor nothing of a type the module keeps private, while `:type` of the same
expression answers `Address(Plain.Msg)` and the binding works once the type is exported. The shape
of the fix: the interface carries every type's description for the descriptor's use, a private
type staying private to names, so the shell binds and prints `p : Address(Plain.Msg)` and the
checker in front of an exposed address keeps its check of each message; whether a compiled program
reaches the same fault, through `Io.show` of such a value or an address of a private type exposed
to foreign code, is probed first; a regression test in the shell's tests. Nothing routes around
it meanwhile: the README's counter exports its type because its reader sends `Counter.Inc`.

---

## MVP 3.26 (kill darlings), about four weeks

Decided with the user on 2026-10-14 (the log's *Kill Darlings*). The specification is
[`docs/proposals/kill_darlings/proposal.md`](proposals/kill_darlings/proposal.md), its findings
[`findings.md`](proposals/kill_darlings/findings.md), and its programs the three pairs under
`programs/`, each as today and as it will be. Two subtractions from the type system, built before
MVP 3.2's item 11, which reopens the decision of 2026-10-13 that nothing more goes into 0.4.0:
a release that is for others does not ship a mark the next release removes, every 0.4.0 program
would otherwise break at 0.5.0 on each `with` line, and the tour would teach processes twice. The
tag slips about three weeks. MVP 3.2's five speed changes before the tag run meanwhile, by agents,
since they touch `ern doc`, the Makefile and the reading of `.erc`s and not the checker.

Each item: the report first, its revision date and the soundness paragraph of each rule changed in
the same commit; then the log; then the code, by an agent from the settled report text; then
`make test-full`, and a stop. The proposal's section 6 names what each touches beyond the code.

0. **§0 read again.** Done 2026-10-16 (the log's *§0 Read Again*): the three sentences below,
   as `principles_review.md` reads §0 against what it decided, with the user, before item 1: the sentence that defines *pure* goes, since the report then calls nothing pure
   and describes a function without `receiving` as one that receives nothing; principle 3's
   "visible in the code or in the type" says it means visible where it happens, as failure is; and
   whether a principle says what a type carries, what keeps values and messages safe and nothing
   more, is decided there. CLAUDE.md's first line and the README's change with §0.
1. **The reply's obligation goes.** Done 2026-10-16 (the log's *Kill Darlings*, its paragraphs of
   that day). The held replies of §8.7 were kept here and reopened by what the build found; decided
   with the user the same day, they go, as item 2a below, built once item 2 has landed. §6.6 keeps what a call does at run time, the deadline, `None`
   or a fault where the callee ends before it answers, a late or second answer dropped, and the
   one sentence that a callee that lives on without answering holds a `callForever` caller; it
   loses the obligation and the rules for where a reply may stand. §3.9's three inferred
   restrictions become two, §11.5's `!` goes, §8.7's held replies stay, since they rest on a
   reply's type and not on the obligation, and `soundness.md` loses its part on replies. Then
   `ern_reply.erl` goes with the checker's places that call it, the catalog of diagnostics is
   written again, the rejected programs of the reply rule go or change, and
   `examples/typed_channels.ern`'s comment on a reply answered twice changes to what is then
   true. Code changes nowhere else: the three programs' `_today` and `_after` files differ by
   no line under this item.
2. **The mark on every action goes.** Done 2026-10-16 (the log's *Kill Darlings*, its paragraph
   *Item 2's code half*), but for what the build found, decided the same day as item 2b below.
   `receiving M` in place of `with M`, on a function that
   receives, calls `self`, asks for a message to be delivered into its mailbox, or calls one that
   does, and no mark on any other action. The report's §0, §2.3's reserved words, §3.9, where
   the process-only restriction survives for a `receive` with an `after` clause alone, printed
   `+` there and nowhere else, §3.11, where `Code.running` asks of its function a result type
   `Unit` alone, §4.5, §4.6, which takes ML's value restriction for a top-level `let` in place of
   the process-only rule, closing the hole the findings' item 3 shows, §6.1, §9.4, §9.5, every
   signature of Appendix E, E.21, which gains `Process.current : () -> Process` so that a function
   that needs its identity and not its mailbox names none, E.28, §11.5, and Appendix A's token;
   `soundness.md`'s part on effects rewritten, the one claim argued as a paragraph of its own,
   that every message a `receive` matches is of its process's mailbox type; `docs/style.md`'s
   glossary and Appendix F, where *obligation*, *pure function* and *process-only* go or change
   and *receiving* enters. Then the lexer, the parser, the formatter, the printer, the Emacs mode
   and the checker; every Ernest source, about 1,670 lines that write `with`, the compiler naming
   the rest, the proposals' programs the tests run among them; the catalog of diagnostics; the
   guide as the proposal's section 7 and the findings' item 6 say, the front page's *What Ernest
   adds* and the README's lines the test holds equal to it among them; and `docs/man/` at the release.
2b. **What item 2's build found.** Done 2026-10-16 (the log's *Kill Darlings*, its paragraphs
   *Item 2b* and *Item 2b's order*); decided the same day (its paragraph *Item 2's code half*),
   built before 2a. The process for each message broke a sender's order through one address, which
   the full run's `code_upgrade` showed; the function runs in a process of the address's own,
   started as a message arrives and ended once none waits (§6.5, §8.7, §10). §4.6 generalizes a top-level `let` whose initializer is
   a call where its type, read through the fields of the declared types it names, holds no function
   type, no foreign type, no address and no reply, so that `Map.empty` and `Set.empty` are the
   values Appendix E lists; the checker exempts the two by name meanwhile, marked INTERIM, and the
   walk of the type replaces it, with tests of a call whose type holds an address, a function, a
   foreign type, and none of the four. The function of an adapted address made on this node is
   applied, for a message from another node, in a process of the address's own
   (§6.5, §8.7), where the gateway applied it itself, with a test of one that calls. A `receive`
   whose patterns fix no type is process-only (§3.9), which the checker does and a test cites.
2a. **The held replies go.** Done 2026-10-16 (the log's *Kill Darlings*, its paragraphs *Held
   replies* and *Item 2a's code half*); decided the same day. With a reply a value, the spawner keeps its copy of a reply its function captured and
   can answer the caller with the failure a spawn on a peer gives it, which the runtime's ending of
   the call with `Fault("callee did not start")` took away; "whose types carry a reply" lost its
   definition with the obligation; and a compute's or a local function's replies were never held.
   The report first: §6.6's and §7.4's `Fault("callee did not start")`, §8.6's sentence on a
   subscriber's reply a failed spawn held, §8.7's and E.27's sentences, Appendix H's `Held`, and
   `soundness.md`'s sentences on them; then the emitter's `held_replies`, `not_started` in
   `ern_peer` and `ern_rt`, their tests, and the glossary's *HeldReplies*. A failed spawn's
   captured reply is then any dropped reply: the caller's deadline, or the spawner's own answer.
3. **A library that waits.** Done 2026-10-16 (the log's *Kill Darlings*, its paragraph *Item 3*):
   the guide's §4.4 passage,
   [`guide_passage.md`](proposals/kill_darlings/guide_passage.md), after the queue, and §8.1's
   *Many at once* pointing at it, checked by `make test-guide`. The guide's §12 then gains three
   questions items 1 and 2 answer: why a function that receives carries `receiving M` and one that
   only sends carries nothing; whether a forgotten answer is caught (`None` at the deadline, a fault
   where the callee ends, `Fault("deadlock")` where nothing else can run, and `callForever` waiting
   on a callee that lives on); and why the compiler is so strict with no warnings, its examples
   without the refusal of a print in a pure function.

The tour's library `Mailbox`, `drained(keep)` and `refilled(messages)`, two functions over the
language as it stands, is MVP 3.3's, written where its rolling upgrade needs it (the proposal's
section 4).

## MVP 3.27 (measured across machines), about a week

A milestone made on 2026-10-13, when MVP 3.2's item 7 measured the exchange, the picks and the
host's distribution on one machine and found that the asks of different peers did not overlap there,
the host's distribution serializing them, so that every number of item 7's that crosses a wire is
one machine's. The user gives four machines to start nodes on, one of them on a separate LAN, and
the measurements run again between them: a spawn whose code crosses, a compute, a fix's callers,
`Peer.utilization`, the pick of item 8's push against `Placement.leastBusy`'s pull, the carrier's
dial and its loss, on one LAN and across the two, each a median over runs with its range, in the log
beside item 7's. What differs goes into the log beside item 7's numbers and, where a sentence of the
deployment guide quotes a number, into the guide, which is written before this milestone on one
machine's numbers and says so; and it decides whether the push's two choices hold under a burst
across a wire, as `docs/proposals/placement/push.md`'s section 5 asks. It runs when the user's machines
are ready, and the release waits for it only where the machines come first.

1. **The machines.** The four nodes' configuration directories and keys, made with `ern config` and
   listed as peers across the machines, a script that starts and stops them, and the measuring
   programs of `make bench` run between them, the node on the separate LAN last.
2. **The numbers.** Item 7's tables again across machines, and the push's experiment of
   `docs/proposals/placement/push.md`'s section 5; the log's paragraph beside item 7's; `docs/memory.md`
   where a measured fact changes; the deployment guide's numbers for two nodes and for code across
   nodes corrected from them.

The nodes tests' about sixty limits, each a number of its own today, are derived here from what each
test waits for, as the plan's *Before the tag: the programs tests* leaves them; and a nodes test of
a peer's connection lost and opened again under a function that waits, which no test runs today and
§8.7's sentence that a loss ends the waits that began before the node ran it describes, joins them
(decided with the user on 2026-10-16).

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
3.2's item 9). It comes after MVP 3.2, whose code with a spawn, bare node and `Code.running` its
last chapters need, and before MVP 3.9, whose newcomer reads it: it is the language's hardest
test, so what it finds is found before 0.5.0 (the log's *The Road to 1.0, Ordered*).

- **First, a clause's body all or none** (decided with the user on 2026-10-14, the log's *Clause
  Bodies All or None*): in a `match` or a `receive`, every clause's body stands beside its
  pattern, or every one goes on the line below it, indented; a block's `{` stays after the
  arrow. They stay beside where every one fits, and one that does not, a block or a body too
  long, sends them all below. §11.6 says so first, then `ern format` and its tests, then `make
  format` lays every source and example out once, so that the tour is written in the layout
  it keeps.
- **Second, the library `Mailbox`** under `src/libs/`, decided with the user on 2026-10-14 (the
  log's *Kill Darlings*): `drained(keep)`, every message of the caller's mailbox that `keep` says,
  in arrival order, by a selective receive with `after 0`, and `refilled(messages)`, which puts
  them into the caller's own mailbox behind what it holds; a channel is a `List(m)`, a value sent
  anywhere. It moves what has arrived, never what will arrive, which its doc block says; redirecting
  the senders is the program's protocol. Written where the rolling upgrade's chapter needs it, by
  Appendix E.0 a library's and not the standard library's.
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
  one program grown across every feature is the language's hardest test before 0.5.0.

## MVP 3.9 (the review, and Ernest 0.5.0)

The last milestone of the planned road, decided with the user on 2026-10-13: it ends in a release,
Ernest 0.5.0, and not in 1.0. Ernest has no users yet and its author has no more of the language in
mind, so nothing is frozen and no promise of stability is made; from 0.5.0 on, a change to the
language, the standard library or the libraries is driven by a need met in use, the author's or
another's, and recorded as `docs/language_feedback.md` records one, and 1.0 is the release that
follows enough use to know what holds still. What the review needs was argued in MVP 2.99c and the
log's *The First Release Is for Others*:

- **`make test` split in two**, done 2026-10-13, taken early (the log's *The Light Run and the
  Full Run*). `make test` is the light run, the applications' unit tests and the document and
  style tests, 85 s, for every commit; `make test-full` is every area, about ten minutes, for
  the commit that closes a plan item and for a release; a commit of documents alone runs
  `make test-docs`. `test-programs` runs as five targets, `test-integration`, `test-nodes`,
  `test-deployment`, `test-manual` and `test-install`, the last after `test-manual`, since
  both write the manual pages; `docs/development.md`'s *Building* has the table of which
  targets a change runs. No test went or was made shallower. CLAUDE.md's *Tests* states which
  run guards which commit.
- **Lighter documents**, done 2026-10-13 (the log's *Lighter Documents*). The plan's finished
  milestones are rows of its table of milestones, each with its date, its release and the log
  entries that argue it, and the paragraphs went, a third of the plan; CLAUDE.md and
  `docs/style.md` lost their history, no rule dropped.
- **The full review**, when the user says so: every reader over the whole of its area
  ([`full_review.md`](full_review.md)), the principles reader among them, so that no principles
  review runs beside it (decided 2026-10-13), and its findings worked.
- **The numbering decided once.** Whether the report's section numbers have drifted enough since
  0.1.0 to renumber, with the mapping table written first and one commit that rewrites every
  citation, in the report, the guide, the log, the code, the tests and the diagnostics; or the
  numbers kept for good (the log's *The Language Argued Before Peers*).
- **The proposals built by then go**, decided 2026-10-16 (the log's *The Design Notes Leave the
  Proposals*). A proposal's directory goes when the milestone built from it closes, after one pass
  takes to the log what it still argues that the log lacks; the review runs that pass over every
  proposal built by 0.5.0, `nodes_and_code/`, `operations/`, `kill_darlings/`, `placement/` and,
  once MVP 3.27 has measured against it, `balancer/`, and finds the operations programs and the
  code-update experiments, which the tests run, a home under `examples/` or `test/fixtures/`, or
  lets them go with their tests. The attached shell's, the site's and `ernest_host/` stay for the
  milestones after 0.5.0, each going as its milestone closes; the last to go takes
  `docs/README.md`'s line, `docs/development.md`'s layout and CLAUDE.md's *Proposals* and
  *Handouts and scratch* paragraphs with it. CLAUDE.md's sentence that a built proposal is kept
  changes in the commit that removes the first directory.
- **The release, Ernest 0.5.0**, as `release_review.md` says, its notes saying what changed since
  0.4.0 and that a release may still refuse a program the previous release accepted, as every
  release before 1.0 may (the log's *A Release Carries No History*); no section of the report states
  a promise, since none is made.

---

## MVP 4.0 (a shell attached to a running node), about a week

The first milestone after Ernest 0.5.0, made on 2026-10-13 from MVP 4.3's item 4 when the deployment
guide's section 6 was written and the user saw how thin a shell beside a node is for an operator:
every look is a compute wrapped by hand, and nothing of the node's own is at the prompt. An attached
shell runs each input on the node, over MVP 3.0's peers and MVP 3.2's shipping of code, so that a
binding read is the node's, a process listed is the node's and a function called runs there without
the wrapping; its `:processes` lists the node's processes, and its `:load` and `:reload` load and
reload code on the node, as `erl -remsh` attaches to an Erlang node. The shell's design does not
assume it runs on the node whose code it evaluates (`docs/shell_design.md`). Nothing of
it goes into 0.4.0, whose notes say what the shell does not yet do and that this milestone brings
it.

1. **`--verbose`**, decided with the user on 2026-10-13 (the log's *A Build Says What It Decided*):
   `ern build`, `ern run` and `ern test` take `--verbose` and write on standard error one line for
   each decision they make without saying: the source root and build root taken, each module
   compiled, as its namespace, its file and the `.erc` written, each module read from the load path
   with the directory that supplied it, and each stale `.erc` the cleanup removed; the default
   stays silent, and standard output stays `--emit-erl`'s and the program's. §11.1 and §11.2 state
   the lines, `ern --help` lists the flag, and a test reads the lines of a build, a run and a test.
   About a day, first in the milestone since it touches `ern_build`, the runner and §11 alone.
   The Makefiles pass `--verbose` to every job they run once it exists, so that a build always says
   what it decided (decided with the user on 2026-10-13, the log's *Slow Tools Are Defects*).
2. **The design**, discussed with the user first in `docs/proposals/shell/attached.md` (begun
   2026-10-13): `ern shell --attach dir` to the node of a directory on this machine and `ern shell
   --config-dir ops --attach name` to a listed peer over the carrier, never a process number or an
   address, since a node is reached by its key (decided 2026-10-13); a session's namespace of its
   own, `$Session3.T`, and the code table keeping each session's units apart, since operators attach
   to one node at once; `:detach` in `:quit`'s place; what an input's process is on the node and who
   its root is; what `:processes`, `:load` and `:reload` do there; what the session shows when the
   node is lost; and the deployment guide's section 6 rewritten over it. The attached shell is the
   operator's alone, trusted as a peer is, with no sandbox: the website runs the plain shell in a
   container per visitor (MVP 4.2).
3. **The build**, about a week, with the nodes tests over a shell attached to a bare node and to a
   program's node, the guide's section 6 run by them, and the release that follows.

## MVP 4.1 (ehttpd, and the libraries it wants)

**ehttpd**, an HTTP/1.1 server written in Ernest, in a repository of its own, decided with the
user on 2026-10-10 (the log's *ehttpd and the Website*): the base of Ernest's own website, MVP
4.2, and the first program built against an installed Ernest by a build of its own, which the
examples cannot be. Its plan lives in its repository; this one records what it asks of the
language and the libraries, and each is written as it asks, the libraries below among them.
What it will evidently ask for, named here for the milestone's size and decided one by one
when the need comes: HTTP's message format, `libs/http`; WebSocket, RFC 6455, for the website's
terminal, a library over `libs/http` and `Tcp`; base64; TLS on a socket; and what of `Tcp` a
server needs beyond what E.18 gives. What it lacks is added where it belongs and never worked around in
Erlang or behind a `foreign fn`: a function the standard library lacks enters by E.0's admission
rules, our need the occasion and the rules deciding the function; a format or a protocol is a
library's; what the prelude or the language lacks goes to `language_feedback.md` first, as any
Ernest written here, and is discussed before any code goes around it (decided with the user on
2026-10-10, with the site's generator, MVP 4.2).

A library not yet written waits, and is written when our work needs it, MVP 3.0 and 3.1 among
that work, when someone asks for it, or when we want it, decided 2026-09-25 (the log's
*Libraries As They Are Wanted*). Each is an Ernest source root under `src/libs/<name>/` that a
program adds with `--load-path`, with `src/stdlib/`'s test discipline, documented in one pass to
[`module_doc_template.md`](module_doc_template.md) with its executed examples as its first
user, and a section in the appendix of libraries. Own repositories come later, when there is a
package story. Written: `libs/ets`, `libs/markdown`, `libs/ansi`, `libs/utilization`,
`libs/json` and `libs/proxy` (Appendix G; `libs/markdown` in the table of milestones, `utilization`, named
`load` until 2026-10-13, and `json` in MVP 3.0, and `proxy`, named `standing` until 2026-10-10,
in MVP 3.1). Named so far:

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

Ernest's website, served by ehttpd (MVP 4.1), decided with the user on 2026-10-10: what Ernest is,
its characteristics, and the three doors of MVP 3.3, the tour, the guide and the report, each with
the reader it is for; and a live shell, a terminal in the visitor's browser, a JavaScript terminal
such as xterm.js, connected by WebSocket to `ern shell` behind a pseudo-terminal on the server. The
shell runs on the server, since no full BEAM runs in a browser, and the shell drives a terminal
through `Terminal` and so runs behind one unchanged. Its sandbox is decided, on 2026-10-10 and again
on 2026-10-13: the operating system's and not the language's, one isolated container per visitor,
with limits on time, memory, processes and network, running the plain shell behind a
pseudo-terminal, nothing kept when the visitor leaves, and `:clear` the container started again. One
node for every visitor with sandboxed sessions attached to it was weighed on 2026-10-13 and set
aside (`docs/proposals/shell/attached.md`): a language-level sandbox is buildable but never the one wall,
since a visitor who exhausts the machine's memory ends every session on the node, and the container
costs little and needs nothing of the language; the attached shell, MVP 4.0, is the operator's
alone. The site's pages are written in Markdown and rendered by `libs/markdown`. The site's
generator is a program of its own beside `tools/manual.ern`, written in Ernest against the library's
tree, `Block` and `Inline`, with an `html` function of one clause per constructor and the site's
template and per-function layout around it, built from the doc chunk's parts as the manual is; the
library renders to its tree and to the terminal alone, and nothing of the site enters it (decided
with the user on 2026-10-10). When something next touches the library, `roff` moves to
`tools/manual.ern`, its one user, with its `Manual` record. The generator may come before the rest
of the milestone whenever it is wanted.

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
4. **A shell attached to a running node**: MVP 4.0's since 2026-10-13, the first milestone
   after 0.5.0.
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

The first milestone after Ernest 0.5.0, decided with the user on 2026-10-10 (the log's *The Road
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
