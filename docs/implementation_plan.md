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
of 2026-10-09*). MVP 3.1 is done on 2026-10-10 (the log's *MVP 3.1 Done*). MVP 3.25 is done on 2026-10-11, built before MVP 3.2's item 1 (the log's *Placing Work by Name*). MVP 3.2's items 1 to 3, the report for code with a spawn and the exchange, are done the same day (the log's *The Report for Code with a Spawn*). The road to 1.0 is MVP 3.1, 3.25,
3.2, the tour and the review; the attached shell, ehttpd, the website, the shell's second round and the back end follow
0.5.0 (the log's *The Road to 1.0, Ordered*, its end set at 0.5.0 on 2026-10-13). MVP 3.1 ended with a read of what it built, its item
9, and MVP 3.2 ends with a release, Ernest 0.4.0, its item 10 (the log's *A Read Before MVP 3.2* and
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
| MVP 3.25 | placing work by name: `Peer.compute` on a named peer, `Peer.utilisation` with the node's measure its maintainer's, and `Placement` in `Balancer`'s place, by `proposals/balancer/suggestion.md` | done 2026-10-11 |
| MVP 3.27 | measured across machines: item 7's numbers again between four machines the user gives, one on a separate LAN, and item 8's push against the pull across them | made 2026-10-13; when the user's machines are ready, after MVP 3.2's item 8; the guide does not wait for it, and the release only where the machines come first |
| MVP 3.3 | the tour, `tour/`: a third way into Ernest beside the report and the guide, one program grown from one node to a rolling upgrade | outline to be written with the user |
| MVP 3.9 | the review, and Ernest 0.5.0: the full review, the numbering decided once, a release with no promise of stability | the end of the planned road, 2026-10-13 |
| MVP 4.0 | a shell attached to a running node: each input run on the node, its processes listed and its code loaded and reloaded from the prompt, as `erl -remsh` attaches | made 2026-10-13 from MVP 4.3's item 4; the first milestone after 0.5.0 |
| MVP 4.1 | ehttpd, an HTTP/1.1 server in Ernest in a repository of its own, and the libraries it wants | `libs/markdown` done 2026-09-25 |
| MVP 4.2 | the website, served by ehttpd: what Ernest is, its characteristics, the three doors, and a live shell in the browser | |
| MVP 4.3 | the shell's second round | |
| MVP 4.4 | after 0.5.0: a back end to BEAM's own instructions, Ernest's types as the loader's typed registers | a proposal first |

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

**Second, before item 1, MVP 3.25's discussion.** Held on 2026-10-11: the proposal was read
through, rewritten to its shape B and decided, and MVP 3.25 was built before this milestone's item
1, on which nothing here depends (the log's *Placing Work by Name*).

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
newcomer now lists the names it could not predict.

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
   its utilisation and placed on by name, ending by termination with §11.8's status, by a spawned
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
   node with its code, a compute, a service offered from a spawned process and found, utilisation
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
   `examples/upgrade_tool.ern`, the proposal's tool, moves a counter's processes alone and on every
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
   connected one how busy it is, every `utilisation-interval` milliseconds of its `ernest.conf`,
   5000 where left out and refused unless a whole number of at least one, and once as a peer
   connects, the telling carrying the teller's interval, the fourteenth frame, the gateway's since
   it owns the connections; a node holds of each peer the last utilisation heard, its moment and its
   teller's interval, a peer not heard from not chosen, a utilisation older than two of its teller's
   intervals not used, a peer's loss dropping its utilisation; `Peer.compute(f, ms)` draws two peers
   with a usable utilisation at random and runs `f` on the less busy, one taken as it is, two
   equally busy the first in the configuration's order, `Left(Unreachable)` where none has a usable
   utilisation and `Left(NotListed)` where none is listed; `Peer.computeAt(name, f, ms)` is the
   compute by name, both forms of §3.11; `Peer.utilisations()` the table for a program's own rule,
   which is never a line of `ernest.conf`; `Peer.setUtilisation(x)` the utilisation a program
   designs, 0.0 to 1.0, a value outside faulting, told until set again or the run ends, the
   configured measure the default, which a telling reads as an ask does; the `Placement` library
   gone with Appendix G.5's content, its tests moved to `Peer`'s, the guide's §8.1 taught over the
   new names. Measured on one machine: the pick 3.6 µs, a table read and a draw, about one part in a
   hundred of a compute, three idle nodes exchanging 1.2 packets a second, the tellings replacing
   the host's ticks (the log's *Placing Work by Name*). Found and decided: a program's own rule
   cannot wrap the compute over a function parameter (§3.11), so it answers a name and the compute
   is written at the call, `docs/language_feedback.md` 106, and `List` has no `minimumBy`, 107. MVP
   3.27 measures the push against the pull across machines. Renamed the same day: `Peer.load` to
   `Peer.setUtilisation` and `Peer.loads` to `Peer.utilisations`, since the number told is the
   utilisation and "load" named it a second time beside `Code.load`'s verb and G.4's library (the
   log's *Placing Work by Name*).
9. **The deployment guide.** `guide/deployment.md`, *Running Ernest*, written whole as a teaching
   document of its own for the operator, who runs nodes and may write no Ernest, after item 8, so
   that it teaches the placement that ships; a number it quotes is one machine's until MVP 3.27
   measures across machines, and says so, since a guide teaches shapes and moves and the log owns
   the measurements (decided 2026-10-13). Its outline, agreed 2026-10-13 and tightened the same day
   to the operator's half of each subject, the programmer's half the language guide's chapter 8 with
   one line pointing there: one node, `ern config`, the directory and `ernest.conf` line by line,
   `ern run`, `ern stop`, `ern reload`, the pid file, what the node says and its statuses, the
   service manager, which §9.5 of the language guide holds today and moves here with a pointer; two
   nodes, keys, certificates, the floor, the handshake, a lost peer on each side and in the program;
   services and placement as the configuration sees them, the `services`, `utilisation` and
   `utilisation-interval` entries and the measures, a bare node given its work; code across nodes as
   the operator meets it, what a node keeps for its life, the counts and the four-fifths line, the
   restart and what it holds, the `NotLoaded` and `Other` lines and the move for each; builds,
   several on one floor, two versions of a type, a fix from a shell, and `examples/upgrade_tool.ern`
   run against a running service, how a service is written to be upgradable being chapter 8's;
   looking in, a shell beside a running node, `Process.status`, `Peer.utilisation` and `Peer.loads`,
   the measures, a trace; what a node says and what to do, the catalogue of standard-error lines,
   each with its cause and the operator's move; and a deployment end to end as a runbook, three
   nodes on one machine to a rolling upgrade, each command in order, each node's configuration, what
   each says after each step, the check and what to do where a step fails, run by the tests, while
   the tour (MVP 3.3) tells the same deployment as a story and points here to operate it; containers
   and orchestration left out, and the design to the log. Decided 2026-10-13 (the log's *The Report
   for Code with a Spawn*, and *Later*): no `Code.upgrade`, since the message it would send is the
   program's own type, which no library function can build at a type, and the two lines show the
   mechanism whole.
10. **The release, Ernest 0.4.0.** The first release with nodes, and the first since `v0.3.1`: the
   review before a release as [`release_review.md`](release_review.md) says, its readers over what
   MVP 3.0, 3.1 and 3.2 changed, the code's reader since `v0.3.1`, the guide's over chapter 8 and
   the deployment guide, and the argument's over `soundness.md`'s section 7; and, decided
   2026-10-13, one principles reader beside them, on Fable, reading §8.7, §11.2, Appendix E.27 and
   E.28 and the guide's chapter 8 against §0, since this milestone wrote its rules under build
   pressure and reversed two, the whole principles review being MVP 3.9's full review's to hold;
   every finding fixed, planned or dropped; then `VERSION` at 0.4.0, the `since` of every module and
   exported declaration that appeared since 0.3.1, the pages in `man/`, the notes, which say what a
   program written for 0.3.1 changes and what the shell does not yet do beside a node, attach to it
   with its inputs run there, which MVP 4.0 brings and the deployment guide's section 6 says (decided 2026-10-13: nothing more goes into 0.4.0), the README rewritten from
   `proposals/scratch/readme_after_mvp3_2.md`, which then goes, the language guide's §0 list
   changing with its fourth bullet, the tag `v0.4.0` and the archive (decided with the user on
   2026-10-10, the log's *Ernest 0.4.0 Ends MVP 3.2*, and on 2026-10-13 for the README).

---

## MVP 3.27 (measured across machines), about a week

A milestone made on 2026-10-13, when MVP 3.2's item 7 measured the exchange, the picks and the
host's distribution on one machine and found that the asks of different peers did not overlap there,
the host's distribution serialising them, so that every number of item 7's that crosses a wire is
one machine's. The user gives four machines to start nodes on, one of them on a separate LAN, and
the measurements run again between them: a spawn whose code crosses, a compute, a fix's callers,
`Peer.utilisation`, the pick of item 8's push against `Placement.leastBusy`'s pull, the carrier's
dial and its loss, on one LAN and across the two, each a median over runs with its range, in the log
beside item 7's. What differs goes into the log beside item 7's numbers and, where a sentence of the
deployment guide quotes a number, into the guide, which is written before this milestone on one
machine's numbers and says so; and it decides whether the push's two choices hold under a burst
across a wire, as `proposals/placement/push.md`'s section 5 asks. It runs when the user's machines
are ready, and the release waits for it only where the machines come first.

1. **The machines.** The four nodes' configuration directories and keys, made with `ern config` and
   listed as peers across the machines, a script that starts and stops them, and the measuring
   programs of `make bench` run between them, the node on the separate LAN last.
2. **The numbers.** Item 7's tables again across machines, and the push's experiment of
   `proposals/placement/push.md`'s section 5; the log's paragraph beside item 7's; `docs/memory.md`
   where a measured fact changes; the deployment guide's numbers for two nodes and for code across
   nodes corrected from them.

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

- **The full review**, when the user says so: every reader over the whole of its area
  ([`full_review.md`](full_review.md)), the principles reader among them, so that no principles
  review runs beside it (decided 2026-10-13), and its findings worked.
- **The numbering decided once.** Whether the report's section numbers have drifted enough since
  0.1.0 to renumber, with the mapping table written first and one commit that rewrites every
  citation, in the report, the guide, the log, the code, the tests and the diagnostics; or the
  numbers kept for good (the log's *The Language Argued Before Peers*).
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
assume it runs on the node whose code it evaluates (`proposals/shell/shell_design.md`). Nothing of
it goes into 0.4.0, whose notes say what the shell does not yet do and that this milestone brings
it.

1. **The design**, discussed with the user first in `proposals/shell/attached.md` (begun
   2026-10-13): `ern shell --attach dir` to the node of a directory on this machine and `ern shell
   --config-dir ops --attach name` to a listed peer over the carrier, never a process number or an
   address, since a node is reached by its key (decided 2026-10-13); a session's namespace of its
   own, `$Session3.T`, and the code table keeping each session's units apart, since operators attach
   to one node at once; `:detach` in `:quit`'s place; what an input's process is on the node and who
   its root is; what `:processes`, `:load` and `:reload` do there; what the session shows when the
   node is lost; and the deployment guide's section 6 rewritten over it. The attached shell is the
   operator's alone, trusted as a peer is, with no sandbox: the website runs the plain shell in a
   container per visitor (MVP 4.2).
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
aside (`proposals/shell/attached.md`): a language-level sandbox is buildable but never the one wall,
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

### MVP 3.25 — placing work by name (done 2026-10-11)

Placing work by name, by [`suggestion.md`](../proposals/balancer/suggestion.md), kept as the
record of its design; the report's §3.11, §6.7, §8.7, §10, §11.2, §11.3, §11.5, Appendix C,
E.27 and G.5 own the rules. `Peer.compute(name, f, ms)` runs a function on a named peer and
answers its value, its frame the call's first note and its answer through the host's alias, a
fault in `f` the caller's, carried whole and reported once on the caller's node, a process that
ends unanswering `Other`, the late process killed by the call's second note; `Peer.utilisation(name,
ms)` answers how busy a peer is on one scale, as the peer's `ernest.conf` says under
`"utilisation"`, the running with the ready over the schedulers by default or the schedulers'
time since last asked, answered by the gateway itself; `libs/placement`'s
`Placement.leastBusy(names, ms)` asks every name at once and answers the least busy, in
`Balancer`'s place, which is gone with its measures and its places; the guide's §8.1 teaches
compute, the pick, here as `f()`, and the later form as a process that sends. On the way the
checker's generalization was found making a lone effect variable in a parameter's type pure, so
that `fn ignore(f : () -> Unit with e)` refused an impure argument; it is kept and printed now
(§3.9, §11.5). Built in three items on one day, each by the report first, with the eleven
decisions the code forced (the log's *Placing Work by Name*, its last three paragraphs);
nothing of the verdict of 2026-09-27 reversed, and 0.4.0 never ships `Balancer`.
