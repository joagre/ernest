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

**MVP 3.2 is done**, and Ernest 0.4.0 is released, the tag `v0.4.0` of 2026-10-18 (the log's *The
Release Review Before 0.4.0*). Its items 1 to 10 were code crossing with a spawn, the bare node,
`Code`, the pick, the deployment guide and the repository laid out again, and its item 11 the
release. MVP 3.26, two subtractions from the type system, is done (2026-10-16), and so are the
tools' five speed changes and the programs tests' defects.
The road to 0.5.0 is MVP 3.27 when the user's machines are ready, MVP 3.28 the formatter's
clause rule, MVP 3.3 the tour and MVP 3.9 the review; the attached shell, ehttpd, the website, the shell's second round and the back end
follow 0.5.0 (the log's *The Road to 1.0, Ordered*, its end set at 0.5.0 on 2026-10-13). A
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
| MVP 3.27 | measured across machines: the exchange's numbers of 2026-10-13 again between the machines the user gives, three on one LAN and a fourth on a separate LAN when it comes, the push against the pull across them, and the spawn's end at the reaper, 5.6 times the host's at 0.4.0 against 4.6 at MVP 3.1 (the log's *The Release Review Before 0.4.0*) | made 2026-10-13; when the user's machines are ready; the guide does not wait for it, and the release only where the machines come first | | below |
| MVP 3.28 | a clause's body all or none: in a `match` or a `receive`, every clause's body beside its pattern or every one below it, which §11.6 states and `ern format` writes | made 2026-10-20 from MVP 3.3's first item; before the tour, which is written in the layout it keeps | | below |
| MVP 3.3 | the tour, `tour/`: a third way into Ernest beside the report and the guide, one program, the counter, grown from a process on one node to its move to new code on a peer, where the deployment guide takes over | outline to be written with the user | | below |
| MVP 3.9 | the review, and Ernest 0.5.0: the full review, the numbering decided once, a release with no promise of stability | the end of the planned road, 2026-10-13; the split of `make test` done 2026-10-13, taken early | | below |
| MVP 4.0 | `--verbose` on `ern build`, `ern run` and `ern test`, then a shell attached to a running node: each input run on the node, its processes listed and its code loaded and reloaded from the prompt, as `erl -remsh` attaches | made 2026-10-13 from MVP 4.3's item 4; the first milestone after 0.5.0 | | below |
| MVP 4.1 | ehttpd, an HTTP/1.1 server in Ernest in a repository of its own, and the libraries it wants | `libs/markdown` done 2026-09-25 | | below |
| MVP 4.2 | the website, served by ehttpd: what Ernest is, its characteristics, the three doors, and a live shell in the browser | | | below |
| MVP 4.3 | the shell's second round | | | below |
| MVP 4.4 | after 0.5.0: a back end to BEAM's own instructions, Ernest's types as the loader's typed registers | a proposal first | | below |

---

## MVP 3.27 (measured across machines), about a week

A milestone made on 2026-10-13, when MVP 3.2 measured the exchange, the picks and the
host's distribution on one machine and found that the asks of different peers did not overlap there,
the host's distribution serializing them, so that every number of that day's that crosses a wire is
one machine's (the log's *The Report for Code with a Spawn*).

The user gives machines to start nodes on, three on one LAN today and a fourth on a separate LAN
when it comes, and the measurements run again between them: a spawn whose code crosses, a compute, a fix's callers,
`Peer.utilization`, the pick of the push (the log's *Placing Work by Name*) against a pull written over
`Peer.utilizations()`, the `Placement` library having gone (Appendix G.5), the carrier's
dial and its loss, on one LAN and, once the fourth machine is there, across the two, each a median over runs with its range, in the log
beside the first.

What differs goes into the log beside the first numbers and, where a sentence of the
deployment guide quotes a number, into the guide, which is written before this milestone on one
machine's numbers and says so; and it decides whether the push's two choices hold under a burst
across a wire, as `docs/proposals/placement/push.md`'s section 5 asks.

It runs when the user's machines are ready, and the release waits for it only where the machines
come first.

1. **The machines.** Built 2026-10-20 (the log's *The Machines*): `test/machines/machines.txt` lists
   the machines, `test/machines/nodes.sh` checks, pulls, starts and stops a bare node on each, and
   `make bench-machines` runs the bench's two node parts across them, the measuring node here. The
   first run found the laptop on Wi-Fi, 3.6 ms a round trip against 0.33 ms between the two wired
   machines, so every number measured from it is the Wi-Fi's.

   **Decided with the user:** a cable for
   the laptop, so that the three are wired and the tooling stands; the fallback is the measuring node
   on a wired machine, a small change the log names. The node on the separate LAN comes last, when it
   comes.
2. **The numbers.** The tables of 2026-10-13 again across machines, and the push's experiment of
   `docs/proposals/placement/push.md`'s section 5; the log's paragraph beside them; `docs/memory.md`
   where a measured fact changes; the deployment guide's numbers for two nodes and for code across
   nodes corrected from them.

   With them, the spawn's end at the reaper measured by itself, the
   bench's spawn row standing at 5.6 times the host's at 0.4.0 against 4.6 at MVP 3.1 (the log's
   *The Release Review Before 0.4.0*), and what costs brought back toward the host's.

   One more run
   of the burst experiment with the laptop back on Wi-Fi as a peer alone, the measuring node on a
   wired machine: a preview of the far peer's row, since the push's choices draw by utilization and a
   far peer is not a busy one, which the node on the separate LAN measures with a steady distance
   when it comes (decided with the user 2026-10-20).

The nodes tests' about sixty limits, each a number of its own today, are derived here from what each
test waits for, as the log's *The Programs Tests' Bounds* leaves them; and a nodes test of
a peer's connection lost and opened again under a function that waits, which no test runs today and
§8.7's sentence that a loss ends the waits that began before the node ran it describes, joins them
(decided with the user on 2026-10-16).

The two Makefile lines that remove an old checkout's `.beam`
copies of compiled modules, `rm -f build/*/ern@*.beam` in the `stdlib` and `shell` rules, go here,
every checkout having been built since 0.4.0.

**After the tag: the annotation out of the hash.** Found by the release review before 0.4.0 (the
log's *The Release Review Before 0.4.0*, KP30), decided with the user 2026-10-18: Appendix H hashes
a type annotation as written beside the scheme that already holds the type, so `fn f(x : Int) : Int`
and `fn f(x) : Int` are one typed tree and two hashes, shipped twice. The form hashes the scheme and
the body, the annotation going to Appendix H's *What is left out*, and the form's version changes
with it, which is why it waits for the tag: the first change of the form since 0.4.0's floor.

**Every fault carries a trace**, built 2026-10-20 (the log's *Every Fault Carries a Trace*): §7.3
gives every fault the host's stack where it was met, E.21 writes a frame as a spawn site is written
and ends the trace at the program's outermost frame, and `ern run`, `ern test` and the shell print it
beneath the fault's line. The three questions the build left, a lambda's frame, the runtime's frames
and a test's own fault, were decided the same day, in the log.

## MVP 3.28 (a clause's body all or none), about a day

Decided with the user on 2026-10-14 as the tour's first item (the log's *Clause Bodies All or
None*) and made a milestone of its own on 2026-10-20, since it is the formatter's work and not the
tour's, and comes before the tour so that the tour is written in the layout it keeps. In a `match`
or a `receive`, every clause's body stands beside its pattern, or every one goes on the line below
it, indented; a block's `{` stays after the arrow. They stay beside where every one fits, and one
that does not, a block or a body too long, sends them all below.

§11.6 says so first, then `ern format` and its tests, then `make format` lays every source and
example out once.

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
a typed mailbox on one node to its move to new code on a peer, and no further: the tour stops
where the operator's work begins and hands over to `guide/deployment.md`, which stays about
running nodes (the log's *The Report for Code with a Spawn*).

The tour is the guide turned inside out: the guide's axis is the rule, and a program illustrates
it; the tour's axis is the program, and a rule appears where the program needs it next. `why.md`'s
five claims are the test the outline passes, each met somewhere along the program's growth and
nothing in the tour there for another reason; they are not its chapters. Decided with the user on
2026-10-20 (the log's *The Tour, Shorter*), which took out the rolling upgrade across three nodes,
`Standing` and the balancer, and with them the library `Mailbox`, now under the log's *Later*.

It comes after MVP 3.2, whose code with a spawn, bare node and `Code.running` its last chapters
need, and before MVP 3.9, whose newcomer reads it: one program across the language's most
important features is its hardest test, so what it finds is found before 0.5.0 (the log's *The
Road to 1.0, Ordered*).

- **The outline first, written with the user**, as a design is: the chapters, the program's growth
  from one to the next, and what each shows, explicitly or by the way.

  The sketch to start from, read against the five claims on 2026-10-20 (the log's *The Tour,
  Shorter*, its paragraph *The outline, read against the claims*): seven chapters of a screen of
  code and half a screen of prose each, a tenth of the guide's length. Each chapter is the
  program's change, so a feature appears where the program first needs it:

  1. The counter, spawned plain; a send, a call with a timeout, and a `String` sent and refused.
  2. A client, a function that parses a line and sends: the one place the plain language appears,
     by the way.
  3. A fault, `restarting`, and a monitor's `Down`.
  4. The counter as a module that counts per key: its tally an abstract type, its report sorted by
     a requirement, and its one test, `ern test`, the one item outside the five claims, admitted
     because a module worth keeping gets a test.
  5. A fix in the shell: two versions side by side, and `Upgrade`.
  6. A `main`, a bare node, and the spawn carrying the code.
  7. The peer's counter moved to new code by the smallest tool, a spawn on the peer that runs
     `Code.running` there; then the handover to `guide/deployment.md`'s §8, which runs the same
     move across three nodes with `examples/upgrade/`, the tour's counter staying its own.
- **Code first.** No paragraph stands before the code it is about: a chapter is the program's
  change, what was run, what it printed, then the prose, a sentence for each line that needs one.
- **It says do, and points for why**, teaching no rule a third time: what a rule is and why is the
  report's and the guides', and the tour names the section, `the guide's §4.4`. Where the program
  meets the operator's world, `ern config`, a peer's key, it names the deployment guide's section
  and goes on.
- **The shell is its medium through the fix in the shell**, `:load` and inputs, so that the reload
  and `Counter$1.Msg` land in the medium the reader has been in, and so that the website's shell
  (MVP 4.2) can run a page as it stands; a `main` and `ern run` from the node's chapter on.
- **Every program in it runs in the tests**, nodes among them, as the guide's examples do.
- **What writing it finds goes to `language_feedback.md`** before any code goes around it, since
  one program grown across the five claims is the language's hardest test before 0.5.0.

## MVP 3.9 (the review, and Ernest 0.5.0)

The last milestone of the planned road, decided with the user on 2026-10-13: it ends in a release,
Ernest 0.5.0, and not in 1.0. Ernest has no users yet and its author has no more of the language in
mind, so nothing is frozen and no promise of stability is made; from 0.5.0 on, a change to the
language, the standard library or the libraries is driven by a need met in use, the author's or
another's, and recorded as `docs/language_feedback.md` records one, and 1.0 is the release that
follows enough use to know what holds still. What the review needs was argued in MVP 2.99c and the
log's *The First Release Is for Others*:

- **The nodes' design note.** The proposals under `docs/proposals/nodes_and_code/`, the carrier, the
  gateway, the exchange, the code table and the processes kept for addresses as built, rewritten as
  one design note under `docs/` beside the shell's, once MVP 3.27's measurements have settled their
  figures; the proposals then stay as the record of how the design was weighed.

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
  `kill_darlings/`, `placement/` and, once MVP 3.27 has measured against it, `balancer/`, and finds
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

1. **`--verbose`**, decided with the user on 2026-10-13 (the log's *A Build Says What It Decided*):
   `ern build`, `ern run` and `ern test` take `--verbose` and write on standard error one line for
   each decision they make without saying: the source root and build root taken, each module
   compiled, as its namespace, its file and the `.erc` written, each module read from the load path
   with the directory that supplied it, and each stale `.erc` the cleanup removed; the default stays
   silent, and standard output stays `--emit-erl`'s and the program's.

   §11.1 and §11.2 state the lines, `ern --help` lists the flag, and a test reads the lines of a
   build, a run and a test. About a day, first in the milestone since it touches `ern_build`, the
   runner and §11 alone.

   The Makefiles pass `--verbose` to every job they run once it exists, so that a build always says
   what it decided (decided with the user on 2026-10-13, the log's *Slow Tools Are Defects*).
2. **The design**, discussed with the user first in `docs/proposals/shell/attached.md` (begun
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
