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

**MVP 3.9 is done**, and Ernest 0.5.0 is released, the tag `v0.5.0` of 2026-10-25 (the log's *The
Release Review Before 0.5.0*): the nodes' and the code's design notes, the proposals built by then
swept, the full review of 2026-10-24 and its 218 findings worked the same day, the member regime
and what the lease broker found, and the release review, nine readers and the machines, its 191
lines made in two rounds. It is the last milestone of the road planned on 2026-10-13, and no promise
of stability is made: from 0.5.0 on a change to the language, the standard library or the libraries
is driven by a need met in use and recorded as `docs/language_feedback.md` records one. MVP 3.95,
what the review and 0.5.0 left, is under way, its first item done 2026-10-25; then the report pared to the language, the attached shell, ehttpd, the website, the shell's
second round and the back end (the log's *The Road to 1.0, Ordered*). A finished milestone is a row
of the table below, its reasons in the log entries the row names.

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
| MVP 3.95 | what the review and 0.5.0 left: the release review read back, the service monitor across nodes decided, the harness counting a test's steps, the review round's method with an owner, the site proposal's sitting, the first fault's cost measured, and a release, 0.5.1 or 0.6.0 as the service monitor's decision leaves the protocol | made 2026-10-24; the first milestone after 0.5.0 | | below |
| MVP 3.96 | the report pared to the language: `language.md` holds what decides what a program means, the runtime's mechanism a chapter of its own at the end of `toolchain.md`, chapter 12, and §10 moved whole with its number; every citation of a moved paragraph redirected | made 2026-10-25 from MVP 3.95's item 3; after 0.6.0 | | below |
| MVP 4.0 | a shell attached to a running node: each input run on the node, its processes listed and its code loaded and reloaded from the prompt, as `erl -remsh` attaches | made 2026-10-13 from MVP 4.3's item 4 | | below |
| MVP 4.1 | ehttpd, an HTTP/1.1 server in Ernest in a repository of its own, and the libraries it wants | | | below |
| MVP 4.2 | the website, served by ehttpd: what Ernest is, its characteristics, the three doors, and a live shell in the browser | | | below |
| MVP 4.3 | the shell's second round | | | below |
| MVP 4.4 | after 0.5.0: a back end to BEAM's own instructions, Ernest's types as the loader's typed registers | a proposal first | | below |

---

## MVP 3.95 (what the review and 0.5.0 left), about a week

The days after the tag, before the attached shell: what the release itself teaches, two
discussions the full review left, what it decided for after the release, and a release of its own,
in the order to do them, the word 0.5.0 ships decided before §8.7's text moves.

1. **The release review read back**, done 2026-10-25 (the log's *The Release Review Read
   Back*): the clone, the machines and the readers weighed against what they found,
   `release_review.md` amended, the round's reader among it, and dialyzer in the full run held as
   item 11.
2. **A restart told across nodes**, done 2026-10-25 (the log's *A Restart Told Across Nodes* and
   *A Restart Told Across Nodes, Built*): two frames, each node whose process monitors the
   restarting one told, as the host lists its monitors, and its answer waited for, a loss ending
   the wait (report §8.7, §10); the protocol's version 4; the store and the desk's program the
   regression test.
3. **The report pared to the language**, MVP 3.96's, after 0.6.0, so that the release reads the
   report as it is (the log's *The Report Pared After 0.6.0*).
4. **The harness counts a test's steps.** Decided with the user on 2026-10-24 from the full review's
   C6-C8 and C6-C10b: about sixty nodes tests give a bare `{waits, N}` nothing checks, the machine
   tests' own waits have no bound, and the shell's tests bound themselves two ways, seven in counted
   steps and the rest by chosen numbers, where a test whose one step is a long terminal session ties
   eunit's timeout with the harness's. The harness counts a test's steps as they happen and fails
   past the count it was given, refusing a bare number; `ern_machine`'s waits take `wait_ms()`
   bounds; and the shell's tests convert under one rule, a session's bound being its steps' sum as
   any test's is. With it `reload_version_sites`, red once in the full run of 2026-10-25 on the
   end's line of two subscribers, which six runs by hand and the shell's tests alone did not repeat
   and whose output the assertion did not keep, carries the shell's output in its failure, so that
   the next red is diagnosed. The repository's own, costing no program anything; the log's *The
   Review's Fixes, First Round* and the findings' lines. Its shape, decided 2026-10-25: a step is
   each bounded wait the harness runs, a `says`, a `prints`, a node's end, a `said`, a job or one
   typed input of a shell session, counted in the harness's own wait functions and nowhere else;
   the count is exact, a test failing past it and at its end short of it; EUnit's timeout stays as
   the fallback, set from the same count; the first run with the counter is the audit of the sixty
   numbers, each wrong one read against its comment's list, and a test whose waits vary between
   runs comes back for a decision rather than loosening the rule. Built by an agent after item 2's
   build, since both edit the nodes tests, by 2026-10-31.
5. **The review round's method gets an owner**, done 2026-10-25: `full_review.md`'s *How it runs*
   states the round after the readers, agents by file ownership compiling in scratch with no `make`,
   a second round for the decisions, the session integrating and reading back, and `git status`
   compared before and after, and `release_review.md` points at it for a release's smaller round
   (the log's *The Full Review Before 0.5.0* and *The Release Review Before 0.5.0*).
6. **The site proposal's sitting**, done 2026-10-25: its three stale lines, MVP 3.3 "writes" the
   tour, a list of four claims, and a test that did not exist, now say the tour is written and
   name the six claims `claims_test` holds, dated in its `decisions.md` (the full review's D23,
   the log's *The Review's Decisions*).
7. **The first fault's cost**, done 2026-10-25: measured, `ern_peer` about 2.8 ms and `ern_show` about
   1.7 ms loaded cold at a program's first fault, `ern_peer` alone in the shell; the plain form stays
   and the number is the log's (*The First Fault's Cost*).
8. **A monitor asked by an old run's delivery after the restart's `new_run`**, done 2026-10-25
   (the log's *A Restart Told Across Nodes, Built*): the clock and the terminal take a restart
   before the reaper. A teller's late delivery remains, as the item said; item 12 closes it.
9. **The member regime's missing test**, done 2026-10-25: the checker's
   `module_level_compare_gives_no_ordering_test`, from before the prelude's `compare`, sharpened to
   hold that a module's own bare `fn compare` hides the prelude's whatever its type and gives the
   type no ordering, citing §4.2's *Unqualified lookup* (the log's *A Member Has One Face*).
10. **The release that closes the milestone**, so that MVP 4.0 starts from a tag: run as
   `release_review.md` says, whole, since the machines are what make a tag solid. 0.6.0, since item
   2 adds two frames and the protocol's version moves, so that its nodes and 0.5.0's do not mix
   (report §8.7).
11. **Dialyzer in the full run**, done 2026-10-25 (the log's *The Release Review Read Back*):
   `make test-full` runs `make dialyzer`, 27 s, so that a warning is met at its item's commit, and
   the release review's machines are five; the fresh clone builds the PLT once, a cost the next
   review measures.
12. **The teller's late delivery**, decided with the user on 2026-10-25 (the log's *The Teller's Late
   Delivery*): a delivery an end's teller starts after the reaper has answered a restart reaches the
   new run, and a monitor its wrap asks for stands there, against §6.9's rule that the new run begins
   with nothing of the old; the same class of hole as item 8, which 0.6.0 does not ship. The delivery
   reads its subscription's row for the end's telling after it has written its own row and before it
   delivers, and delivers nothing to a run the end has not told; the argument that the reaper's order
   makes the check exact goes to the log with the build, and the runtime's note's restart steps say
   so. Built by an agent with item 4, by 2026-10-31; a test where one can be placed, else the reason
   in the log.

## MVP 3.96 (the report pared to the language), after 0.6.0, about three days

Made on 2026-10-25 from MVP 3.95's item 3, decided with the user on 2026-10-24 from the full review's
E.18 reading and the question what a Wirth report holds: the Pascal report defined files because
Pascal had no modules, and the Modula-2 and Oberon reports hold the language alone, the library's
modules documented apart with an authority of their own. Why it is worth its cost, asked again on
2026-10-25, is the log's *The Report Pared After 0.6.0*.

1. **The report pared.** `language.md` keeps what decides what a program means, §0 to §7, §8's
   rules, §9 and Appendix A; what says how the runtime does it or what a module does moves, each to
   its owner, `toolchain.md` for the runtime's promises and `library.md` for the modules: §8.7's
   machinery beyond a page, the floor, the keys, the frames, the exchange, the reach and the
   utilization measure; §8.2's system modules, one sentence staying, that a process the runtime
   starts has an owner and a message type foreign code holds; §8.4's ABI table, the host binding,
   `foreign fn` staying as the door; §7.4's catalog of fault texts; §10's costs, which §0's
   principle 5 then points at; and §8.6's mechanism, its rule staying. The moved mechanism is a new
   chapter at the end of `toolchain.md`, chapter 12, the runtime, a section for each mass, and §10 moves
   whole and keeps its number, since a chapter is one file's or another's; no section is renumbered.
   The paring is the session's work; an agent then redirects every citation of a moved paragraph,
   in the Erlang, the tests, the Ernest and the documents, from a table of moved paragraph to new
   number, the citations of a rule standing, and `make sections` demands each new section's test.
   With it CLAUDE.md's authority rule and `report/README.md` say what each file holds, and
   `docs/soundness.md` cites chapter 12 where it cited §8.4 and §8.7. After 0.6.0, so that the release
   reads the report as it is.

## MVP 4.0 (a shell attached to a running node), about a week

Made on 2026-10-13 from MVP 4.3's item 4 when the deployment
guide's section 6 was written and the user saw how thin a shell beside a node is for an operator:
every look is a compute wrapped by hand, and nothing of the node's own is at the prompt. An attached
shell runs each input on the node, over MVP 3.0's peers and MVP 3.2's shipping of code, so that a
binding read is the node's, a process listed is the node's and a function called runs there without
the wrapping; its `:processes` lists the node's processes, and its `:load` and `:reload` load and
reload code on the node, as `erl -remsh` attaches to an Erlang node. Whether the shell's design, `docs/design/shell.md`, assumes it runs
on the node whose code it evaluates is the proposal's first question, read against the note before
anything is built. Nothing of
it goes into 0.5.0, whose notes say what the shell does not yet do and that this milestone brings
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
3. **The first day of the new machine**, a 12-core AMD with 64 GB expected in November 2026, done
   when the machine is there, before or after the milestone's own items, and waited for by no
   release (moved out of MVP 3.9 on 2026-10-23, the log's *MVP 3.9 Weighed*): its line in
   `test/machines/machines.txt` beside bee and xena; one `make bench` before any code changes, kept
   as the release's reference with `make bench-release`, since every number in the log is the old
   laptop's and the first run there is a reference and not a move; and the bench's rows of eight
   processes at once gain a row at the host's scheduler count, so that scaling shows as a line and
   not a point, which `test/ern_foreign_costs.erl` and `test/ern_call_costs.erl` take from
   `erlang:system_info(schedulers)`.

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
*Libraries As They Are Wanted*). Each is an Ernest source root under `src/libs/<name>/` whose build
ends every job's load path, so that a program names none (§11.2), with `src/stdlib/`'s test discipline, documented in one pass to
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
its characteristics, and the README's three ways in, the tour, the guide and the report (the log's *The Tour Written*), each with
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

## MVP 4.4 (a back end to BEAM's own instructions)

The last milestone, after Ernest 0.5.0, decided with the user on 2026-10-10 (the log's *The Road
to 1.0, Ordered*): a second back end beside the emitter's Erlang abstract format, writing the
BEAM's own instructions, its generic opcodes (`genop.tab`, format 0, additions only, OTP 29's
record instructions among them), with Ernest's proven types written as the loader's typed
registers, so that the JIT emits code without the run-time type tests the Erlang compiler must
keep. It changes no rule of the language, and it makes the soundness argument load-bearing for
the VM's memory safety: a value from outside, a peer's message, foreign code's return, is fully
checked before its register is typed, which §8.4's checks and the argument's section 7 must
then be read as carrying. Conditions before it is built: the language held still, as 1.0 will say, OTP
pinned for the long term, and `make bench`'s numbers for what the type tests cost today, which
decide whether it is worth its cost. A first, safe step to measure against: a type guard at each
function's entry, from which the Erlang compiler's own inference types the body. Its design is a
proposal first, discussed with the user, as MVP 3.1's was.

---
