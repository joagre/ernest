# Plan

The roadmap: what will be built, in what order, and what is built already. Why anything is the
way it is belongs to [`log.md`](log.md), what the language is to
the report in [`report/`](../report/), how the code is arranged to
[`architecture.md`](architecture.md), and the commands and what the toolchain does not do yet
to [`development.md`](development.md).

Read "Where we are" first, then the table of milestones; the milestones to come follow in order. A gap
stands in the milestone whose item closes it, a defect of OTP's in [`otp_bugs.md`](otp_bugs.md),
and a feature declined in a dated entry of the log; nothing stands between.

---

## Where we are

**MVP 3.2 is done**, and Ernest 0.4.0 is released, the tag `v0.4.0` of 2026-10-18 (the log's *The
Release Review Before 0.4.0*). Its items 1 to 10 were code crossing with a spawn, the bare node,
`Code`, the pick, the deployment guide and the repository laid out again, and its item 11 the
release. MVP 3.26, two subtractions from the type system, is done (2026-10-16), and so are the
tools' five speed changes and the programs tests' defects.
MVP 3.27, the measurements across machines, is done (2026-10-21), and so are MVP 3.28, what stood
before the tour, and MVP 3.29, the bookkeeping behind §8.6 and the foreign call (2026-10-22). MVP 3.295,
what the language measurement found, is done the same day. MVP 3.296, what the tour's outline asked, is done (2026-10-23), the outline decided and the
plan's MVP 3.3 written from it. The road to 0.5.0 is MVP 3.3 the tour and MVP 3.9 the review; the attached shell, ehttpd,
the website, the shell's second round and the back end follow 0.5.0 (the log's *The Road to 1.0, Ordered*, its end set at 0.5.0 on 2026-10-13). A
finished milestone is a row of the table below, its reasons in the log entries the row names.

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
| MVP 2.6 | the shell | 2026-09-25 | | [`shell_design.md`](design/shell.md); the log's entries from 2026-09-20 to 2026-09-25 |
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
| MVP 3.2 | code with a spawn: the exchange, the bare node, every unit held for the node's life, and `Code`; then a release, Ernest 0.4.0, the first with nodes | the code by 2026-10-15; the release 2026-10-18 | tag `v0.4.0` | [`mvp3.2.md`](proposals/nodes_and_code/mvp3.2.md); *The Feedback Pass Before MVP 3.2*, *The Typed-Channels Example*, *The Service Named*, *Names Read as a Newcomer Reads Them*, *The Report for Code with a Spawn*, *Placing Work by Name*, *American English Throughout*, *The Pages Written From `main`*, *Pages Written Where Out of Date*, *The Tools Measured*, *The Tools Measured Again*, *The Repository Laid Out Again*, *The Layout Completed*, *Tables in `libs/markdown`*, *The Programs Tests' Bounds*, *The Design Notes Leave the Proposals*, *The Examples Are Programs*, *The Runtime's Own Processes*, *The Shell on a Private Type*, *Before the Tag, the Last Builds*, *Ernest 0.4.0 Ends MVP 3.2*, *The Release Review Before 0.4.0* |
| MVP 3.27 | measured across machines: the exchange's numbers of 2026-10-13 again between three machines on one LAN, the push against the pull across them, the spawn's end at the reaper and the bench's three other rows that grew measured piece by piece, every fault with a trace, the programs tests' limits derived, and the annotation out of the hash | 2026-10-21 | | [`push.md`](proposals/placement/push.md); *The Machines*, *The Numbers Across Machines*, *The Rows That Grew*, *Every Fault Carries a Trace*, *The Nodes Tests' Bounds*, *The Later List Sorted*, *The Annotation Out of the Hash* |
| MVP 3.28 | what stands before the tour: a clause's body all or none, which §11.6 states and `ern format` writes; `--libs-dir dir`; `--verbose`; and seven items the feedback left: four messages that name the form, the rules of an Ernest program installed, the libraries on the default load path, `ok` as `Unit`, `Test.faults`, the foreign call measured, and doc examples run by `ern test`; with what the builds found: a type and the module of its name share a namespace, a module under a taken namespace refused, `List.mapFold`, a mailbox type ending in `Msg`, the prelude's `Unit` as a descriptor word, a `make` with nothing to do measured, and each doc example a program of its own in a directory of its own | 2026-10-22 | | *The Later List Sorted*; *Clause Bodies All or None*; *A Libs Flag Instead of the Environment*; *A Build Says What It Decided*; *A Make With Nothing to Do*; *What the Feedback Left*; *The Window's Three Asks*; *Nothing Waits for a Program*; *The Foreign Call Measured* |
| MVP 3.29 | the bookkeeping behind §8.6 on one rule, the look reads what a process marks and no operation writes a shared row: the foreign call's count gone for a read of the waiting process, the timed receive's and the call's marks in the process's own dictionary, every slow wait of the runtime's own marked and held by a test, the callees' row kept on a write-concurrent table and measured against two other kinds, a kill one function and a frame from another node; a ground `let` compiled to its term; the foreign cause naming the function; one checker of the library's examples; a launch a row of its own table, halved; the runtime's fixed waits and the tests' sleeps, polls and limits gone for waits on what each means; `make bench` with a memory of its last run and of the release's, by ratio; the language measured against the host's own Erlang, construct by construct and in three programs written twice; the runtime's design note; and a deadlock found among *Why Ernest*'s claims | 2026-10-22 | | *The Sitting on §8.6's Bookkeeping*; *`make bench` Read Against the Cost Rules*; *The Language Against the Host*; *The Foreign Call Measured*; *Deadlock Is Quiescence* |
| MVP 3.295 | what the language measurement found: a `Float` operation the host's own with no `try`, the runtime reading a `badarith`'s frame, a chain of five from 1.65 to 1.23 times the host's and the ray tracer from 1.95 to 1.70; `Map.get`'s number closed as the type's; and the bench's parts as targets, its memory kept a table at a time | 2026-10-22 | | *The Sitting on §8.6's Bookkeeping*, its paragraphs *The Float chain* and *Built*; *The Language Against the Host* |
| MVP 3.296 | what the tour's outline asked: a restart runs the function it was given, stated in §6.9 and the deployment guide, with the guide's sentence that a binding is its node's own; `ern config --listen` and `--peer-dir dir`; the Erlang and the Gleam programmer reading `why.md` and `faq.md`, and every guide read for a word used before it is said; two messages the tour's spike found wanting; and the runtime's own frames out of a designed fault's trace | 2026-10-23 | | *What the Outline Asked*, *Two Nodes on One Machine, Built*, *The Skeptics' Read*, *What the Skeptics Found*, *The Hash's Parents*, *Two Messages, and the Runtime's Frames Weighed Again*; `findings.md` as it stood at `fd5b361c` |
| MVP 3.3 | the tour, `tour/`: a third way into Ernest beside the report and the guide, one program, the counter, grown from a process with a typed mailbox, through the same counter on a peer that holds none of its code, to its move to new code there, where the deployment guide takes over | the outline decided 2026-10-23, [`outline.md`](proposals/tour/outline.md); the programs next | | below |
| MVP 3.9 | the review, and Ernest 0.5.0: the full review, the numbering decided once, a release with no promise of stability | the end of the planned road, 2026-10-13; the split of `make test` done 2026-10-13, taken early | | below |
| MVP 4.0 | a shell attached to a running node: each input run on the node, its processes listed and its code loaded and reloaded from the prompt, as `erl -remsh` attaches | made 2026-10-13 from MVP 4.3's item 4; the first milestone after 0.5.0 | | below |
| MVP 4.1 | ehttpd, an HTTP/1.1 server in Ernest in a repository of its own, and the libraries it wants | `libs/markdown` done 2026-09-25 | | below |
| MVP 4.2 | the website, served by ehttpd: what Ernest is, its characteristics, the three doors, and a live shell in the browser | | | below |
| MVP 4.3 | the shell's second round | | | below |
| MVP 4.4 | after 0.5.0: a back end to BEAM's own instructions, Ernest's types as the loader's typed registers | a proposal first | | below |

---

## MVP 3.3 (the tour)

A third way into Ernest beside the report and the guide, `tour/`, for the reader who wants the
whole picture in an evening and will read neither: the report is for whoever builds or checks a
toolchain, the guide for the programmer learning the language, and the tour a crash course. It
is a directory of its own at the top level, its document and the programs it grows side by side,
and the README opens on the three doors, each with the reader it is for, what it gives and how
long it takes, so that a reader chooses one and walks in; CLAUDE.md's table of owners gains its
row when the tour exists, with `why.md` the paragraph before them, as the website has it (MVP
4.2). Decided with the user on 2026-10-10 (the log's *The Tour*).

Its reader is the guide's reader in a hurry: a programmer who has used a functional language, who
is told nothing the guide's section number would not, and that section is named (decided with the
user on 2026-10-20, the log's *The Tour, Shorter*).

One program, the counter of the guide and `why.md`, grown chapter by chapter from a process with
a typed mailbox, through the same counter on a peer that holds none of its code, to its move to
new code there, and no further: the tour stops where the operator's work begins and hands over to
`guide/deployment.md`, which stays about running nodes (the log's *The Report for Code with a
Spawn*).

The tour is the guide turned inside out: the guide's axis is the rule, and a program illustrates
it; the tour's axis is the program, and a rule appears where the program needs it next. `why.md`'s
claims are the test the outline passes, each met somewhere along the program's growth, and one
chapter alone is in the tour for a claim and says so; they are not its chapters. Decided with the
user on 2026-10-20 (the log's *The Tour, Shorter*), which took out the rolling upgrade across
three nodes, `Standing` and the balancer, and with them the library `Mailbox`, dropped on
2026-10-21 (the log's *The Later List Sorted*).

It comes after MVP 3.296, whose two options of `ern config` its chapter 2 types and whose
sentences its chapters point at, and before MVP 3.9, whose readers read it: one program across the
language's most important features is its hardest test, so what it finds is found before 0.5.0
(the log's *The Road to 1.0, Ordered*).

- **The outline, decided with the user on 2026-10-23**, is
  [`proposals/tour/outline.md`](proposals/tour/outline.md), the design's record until the tour is
  built: three rules of the report that fix what the last chapters can do, since a process keeps
  its mailbox type for life, a type that carries `Upgrade` is bound to its node, and
  `Code.running` lists the processes on a hash; eight chapters, each a screen of code and half a
  screen of prose, with each one's change to the program, its session as the toolchain printed
  it, and what it shows; and the decisions, each with its reason. The outline was read by a
  skeptical Erlang programmer, a Gleam programmer and a reviewer, and every session line was run
  against the toolchain before it was decided (its section 8).

  The eight chapters: the counter, a process with a typed mailbox and a `String` refused; two
  bare nodes, `foo` and `bar`, made by `ern config --peer-dir` and the counter spawned on `foo`;
  the client, the plain language by the way and a quiet `:reload`; a fault, a restart that keeps
  the address and loses the count, and a monitor's `Down`; per key, the tally an abstract type
  with a requirement, two tests of which one deadlocks on purpose, and the compiler refusing the
  new protocol to the peer's old counter; the door, the protocol split and `Upgrade` added, the
  tally lost once more and the counter started on `foo` by a compute; work anywhere, a host
  question through a `foreign fn` and `Peer.compute` placing invented work on whichever node has
  room; and the fix, a second loop beside the first, every counter moved to it by `Code.running`
  on this node and on `foo`, the tally kept, `foo` stopped, and the handover to the deployment
  guide's §8.
- **The tally is lost twice and kept once.** Counting is dull, so what carries the reader is the
  count: lost at chapter 4's restart and chapter 6's type change, and kept across chapter 8's
  move, which is the point the two losses set up.
- **Code first.** No paragraph stands before the code it is about: a chapter is the program's
  change, what was run, what it printed, then the prose, a sentence for each line that needs one.
  The blocks are `ern format`'s layout, and the message type is exported from chapter 1, so that
  the prompt can name its constructors.
- **It says do, and points for why**, teaching no rule a third time: what a rule is and why is the
  report's and the guides', and the tour names the section, `the guide's §4.4`. Where the program
  meets the operator's world, `ern config`, a peer's key, it names the deployment guide's section
  and goes on. A planted mistake is used once, chapter 5's deadlocking test, and the tour says it
  is one.
- **It names a claim where the program meets one.** One line of the tour's own, where the program
  has just done what the reader's language cannot, names `why.md`'s claim and states no rule, and
  names no other language's tools, so that the moment is marked and the tour is not a lab manual
  with cross-references nor an argument; the FAQ argues.
- **The shell is its medium throughout**, `:load`, `:reload` and inputs, so that the reload and
  the previous version's type land in the medium the reader has been in, and so that the website's
  shell (MVP 4.2) can run a page as it stands. A shell started with `--config-dir` is a node
  (§11.2); the two bare nodes run in terminals of their own, and `ern build` and `ern test` in the
  reader's, four in all.
- **Every program in it runs in the tests**, nodes among them, as the guide's examples do:
  `tour/1/` to `tour/8/` hold the program as it stands at each chapter's end, each block of the
  document held equal to its chapter's file, the sessions run as the guide's are with the bare
  nodes started by the nodes' harness, and chapter 5's `ern test` expected to report the deadlock.
  The whole tour runs in about eleven seconds of the toolchain's time.
- **The work in its order, each piece on its model.** The programs and their tests first, by an
  Opus 5.5 xhigh agent from the outline, before any prose, since code first demands real output;
  with them `why.md`'s shell transcript run again with `CounterMsg`, and its two `Peer` fragments
  given the line that points at chapter 2 (the skeptics' findings M25 and M6, `findings.md` as it
  stood at `fd5b361c`). Then the prose,
  chapter by chapter on Fable 5.1, the user reading each. Then the reads below.
- **A fresh reader reads it last**: an agent given `README.md` and then the tour, reading as a
  programmer who has used a functional language and never seen Ernest, reporting where it was lost
  or bored, and every word met before the document says what it is, the reading the five guides
  had on 2026-10-23. Its
  findings are sorted as a review's (`docs/release_review.md`'s *The findings*). A read of this
  kind has found what no passing test did. Then the full review's two skeptics, L the Erlang
  programmer and M the Gleam programmer, walk the whole path, `README.md`, `why.md`, the tour, the
  FAQ and the guide's chapter 1, decided with the user on 2026-10-23 (the log's *The Skeptics'
  Read*), since the README and the guide's first chapter change with the tour; the language guide
  and the deployment guide whole they read in MVP 3.9's full review, at their first run there.
- **The README's door promises two numbers**, an hour to read and about three to do along on a
  machine with four terminals, which the build measures, decided with the user on 2026-10-23 (the
  outline's section 8).
- **The guide's chapter 1 ends with a taste**, once the tour's chapter 2 reads well: the same
  lines, the counter on a bare node, pointing at the guide's §8.1. The guide's order stays by rule;
  the reader who wants the picture first is sent to the tour by the README's doors.
- **What writing it finds goes to `language_feedback.md`** before any code goes around it, since
  one program grown across the claims is the language's hardest test before 0.5.0. The outline
  left six entries, decided as MVP 3.296, and the spike two more, 146 and 147, which stand. Among
  what the build decides is a call to many processes at once, feedback 5, which the log's *Kill
  Darlings* left to the program the idiom cannot write well.

## MVP 3.9 (the review, and Ernest 0.5.0)

The last milestone of the planned road, decided with the user on 2026-10-13: it ends in a release,
Ernest 0.5.0, and not in 1.0. Ernest has no users yet and its author has no more of the language in
mind, so nothing is frozen and no promise of stability is made; from 0.5.0 on, a change to the
language, the standard library or the libraries is driven by a need met in use, the author's or
another's, and recorded as `docs/language_feedback.md` records one, and 1.0 is the release that
follows enough use to know what holds still. What the review needs was argued in MVP 2.99c and the
log's *The First Release Is for Others*:

- **The first day of the new machine** (a 12-core AMD with 64 GB, expected about 2026-11-12; moved
  here from MVP 3.295 on 2026-10-22, since the machine comes after that milestone's close):
  its line in `test/machines/machines.txt` beside bee and xena; one `make bench` before any code
  changes, kept as the release's reference with `make bench-release`, since every number in the
  log is the old laptop's and the first run there is a reference and not a move; and the bench's
  rows of eight processes at once gain a row at the host's scheduler count, so that scaling shows
  as a line and not a point, which `test/ern_foreign_costs.erl` and `test/ern_call_costs.erl` take
  from `erlang:system_info(schedulers)`.

- **The nodes' design note.** The proposals under `docs/proposals/nodes_and_code/`, the carrier, the
  gateway, the exchange, the code table and the processes kept for addresses as built, rewritten as
  one design note under `docs/` beside the shell's, the measurements across machines having settled
  their figures (the log's *The Numbers Across Machines*); the proposals then stay as the record of how the design was weighed.

  Its sources, in order: §8.7 and §11.2 and the code as built, with `architecture.md`'s map, for
  what the component is; `mvp3.0.md` to `mvp3.2.md` and the log's entries for why each part is
  shaped so; `nodes.md` and `code.md` for the intent and the alternatives weighed at the start,
  several of which the build changed; `set_aside/` for one line each on what went and why;
  `experiments/` for the numbers a cost section quotes; `other_systems.md` for the comparison.

  The paragraphs of §8.7 that state the runtime's machinery a program never sees, its frames, the
  gateway's workers and the notes' bookkeeping, move into the note then, with their Appendix F
  entries, and §8.7 keeps what a program meets, as the release review before 0.4.0 found (the log's
  *The Release Review Before 0.4.0*, KP26).

  A proposal that redesigned a rule of the language and built no component, kill darlings, the
  balancer's suggestion and the placement push, becomes no note, its outcome being the report's
  (decided with the user on 2026-10-17).
- **`make test` split in two**, done 2026-10-13, taken early (the log's *The Light Run and the Full
  Run*). `make test` is the light run, the applications' unit tests and the document and style
  tests, 85 s, for every commit; `make test-full` is every area, about ten minutes, for the commit
  that closes a plan item and for a release; a commit of documents alone runs `make test-docs`.

  `test-programs` runs as five targets, `test-integration`, `test-nodes`, `test-deployment`,
  `test-manual` and `test-install`, the last after `test-manual`, since both write the manual pages;
  `docs/development.md`'s *Building* has the table of which targets a change runs.

  No test went or was made shallower. CLAUDE.md's *Tests* states which run guards which commit.
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
  takes to the log what it still argues that the log lacks.

  The review runs that pass over every proposal built by 0.5.0, `nodes_and_code/`, `operations/`,
  `kill_darlings/`, `placement/` and `balancer/`, measured against across machines (the log's *The
  Numbers Across Machines*), and finds
  the operations programs and the code-update experiments, which the tests run, a home under
  `examples/` or `test/fixtures/`, or lets them go with their tests.

  The attached shell's, the site's and `ernest_host/` stay for the milestones after 0.5.0, each
  going as its milestone closes; the last to go takes `docs/README.md`'s line,
  `docs/development.md`'s layout and CLAUDE.md's *Proposals* and *Handouts and scratch* paragraphs
  with it. CLAUDE.md's sentence that a built proposal is kept changes in the commit that removes the
  first directory.
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
reload code on the node, as `erl -remsh` attaches to an Erlang node. Whether the shell's design, `docs/design/shell.md`, assumes it runs
on the node whose code it evaluates is the proposal's first question, read against the note before
anything is built. Nothing of
it goes into 0.4.0, whose notes say what the shell does not yet do and that this milestone brings
it.

1. **The design**, discussed with the user first in `docs/proposals/shell/attached.md` (begun
   2026-10-13): `ern shell --attach dir` to the node of a directory on this machine and `ern shell
   --config-dir ops --attach name` to a listed peer over the carrier, never a process number or an
   address, since a node is reached by its key (decided 2026-10-13).

   A session's namespace of its own, `$Session3.T`, and the code table keeping each session's units
   apart, since operators attach to one node at once; `:detach` in `:quit`'s place; what an input's
   process is on the node and who its root is; what `:processes`, `:load` and `:reload` do there;
   what the session shows when the node is lost.

   The deployment guide's sections 5.3 and 6 rewritten over it, the upgrade of the language
   guide's §8.9 becoming a `:load` of the new build at the node's prompt with `Code.running` run
   there, and `docs/development.md`'s row on attaching gone with the gap (asked by the user
   2026-10-18).

   The attached shell is the operator's alone, trusted as a peer is, with no sandbox: the website
   runs the plain shell in a container per visitor (MVP 4.2).
2. **The build**, about a week, with the nodes tests over a shell attached to a bare node and to a
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
  beside an `Fs.list` that stays whole or an error (§8.2; the log's *The Full Review's Questions,
  One by One*, S17).
- **A read and a write in `Fs` that refuse a link under a root**, decided when a program
  serving files from a root others can write is written: `Fs.readUnder` and `Fs.writeUnder`,
  through E.0 rule 1, walking by opened directories in the runtime's helper, started per call
  or resident as that program's cost decides (E.17; the log's *The Full Review's Questions, One by
  One*, S16).
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
5. **Whether the session owns what its inputs open**, a decision with the user: a socket and a
   running program an input opens end with the input's process, their owner (§11.2), and the session
   could own them instead, so that they live until it ends, by a way the shell names an owner for
   its inputs (`findings.md`'s C1-2, placed here 2026-09-30).

   Half decided 2026-10-10 by feedback entry 91: what a `:load`'s binding opens is the evaluation
   process's, which lives while the session runs (§11.2), so the decision left is the input's own
   process alone, which MVP 3.1's read kept ending with the input (its W10).
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
