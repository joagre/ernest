# Ernest Implementation Plan

The roadmap: what will be built, in what order, and what is built already. Why anything is
the way it is belongs in [`decisions.md`](decisions.md); what the language is belongs in
[`ernest_report.md`](../ernest_report.md); how the code is arranged belongs in
[`architecture.md`](architecture.md). This document points at them rather than repeating
them.

Read "Where we are" first. The milestones follow in order, then the standing gaps, then what
is done, then the tables worth keeping.

The toolchain is `ernc`, which compiles `.ern` to `.erc`, and `ern`, which runs a `.erc` and
adds a shell on request. Written in Erlang on OTP 29, one person. The language was called
Actorson until 12 September 2026.

---

## Where we are

**MVP 2.65, the language and the toolchain read back after the shell, has begun.** Its
first seven steps are done: the feedback list and this plan consolidated, the report read
cold, and the five themes, names and namespaces, expressions, patterns and types, processes
and the system, the standard library under E.0, and the toolchain. Step 8, the Erlang
code's open questions, is next.
MVP 2.6, the shell, was closed on
2026-09-25, and the code read back after it the same day, both under "Done".

**Taken out of order and done:** MVP 2.9, the Emacs mode, on 2026-09-23; MVP 2.61, the
guide as the user's document, on 2026-09-24, after which CLAUDE.md was rewritten for
clarity, every rule kept; and `libs/markdown`, now MVP 3.2's, on 2026-09-25. All three are
under "Done".

**The rhythm.** One item a turn, with its tests, its documents, its conformance section and
its commit; then a stop for review before the next. The user reads the plan and not the log,
so a decision they must see goes here.

---

## Milestones

| | What | State |
|---|---|---|
| MVP 1 | the chain: parser, types, BEAM | done 2026-09-18, tag `mvp1` |
| MVP 2 | the rest of the report on one node | done 2026-09-19 |
| MVP 2.5 | a complete standard library | done 2026-09-20 |
| MVP 2.6 | the shell | done 2026-09-25 |
| MVP 2.61 | the guide as the user's document | done 2026-09-24, out of order |
| **MVP 2.65** | **the language and the toolchain read back** | **begun 2026-09-25** |
| MVP 2.66 | the standard library's `Supervisor` | after 2.65 |
| MVP 2.7 | a program started from a command line, and the appendix of libraries | |
| MVP 2.9 | an Emacs major mode | done 2026-09-23, out of order |
| MVP 3.0 | peers | |
| MVP 3.1 | content addressing | |
| MVP 3.2 | the libraries, as they are wanted | `libs/markdown` done 2026-09-25 |

---

## MVP 2.65 (the language and the toolchain read back after the shell), about two weeks

The shell is the first program of size written in Ernest by the people who designed it, and
what it and the libraries felt is in [`language_feedback.md`](language_feedback.md), which
owns that list, grouped there under five themes. This item decides each entry rather than
collecting it, a theme at a time, in the order below: each theme decides things the next
ones assume. It grew from about twenty questions to about sixty with the shell's close and
the code's read-back, so the estimate is two weeks of turns where it was four days.

- **Each entry is judged on §0's five principles**, and a standard library entry on E.0's
  four admission rules, one by one and in writing. How many sites felt it is an argument,
  never the gate.
- **Every entry ends in one of three things:** a report change, made before any code; an
  entry in the log under "Later" stating the verdict and what would change it; or a line
  saying it was weighed and left alone. It then leaves the feedback list. Nothing is left
  open, since the next program will feel the same things and a second collection is not a
  decision.

The steps:

1. **Done 2026-09-25: the list consolidated.** The feedback list is grouped by the question
   its entries share, each keeping the number it is cited by, and the settled entries have
   left it; this plan's "Done" is a paragraph a milestone, the detail being the log's and
   the history's.
2. **Done 2026-09-25: the report read cold, by an implementer**, and its plain half written
   into the report (the log's *The Report Read Cold, Its Plain Half*). What is open is in
   [`report_cold_read.md`](report_cold_read.md), each finding under the theme that decides
   it; what no theme takes is decided in step 9.
3. **Done 2026-09-25: names and namespaces**, the feedback list's first theme. An abstract
   type's boundary is its module (items 32, 33 and 49; report §4.4). Constructor names stay
   unique in a module (item 2), names stay qualified without import or alias (item 4), and
   two visibilities are enough (item 43), each weighed and kept. A later input may add a
   member to a session type (item 17; report §11.2). The log has an entry for each; item 46
   moved to the standard library's theme.
4. **Done 2026-09-26: expressions, patterns and types**, the second theme. **Decided
   2026-09-25:** field selection, `e.f` where every constructor has the field (item 51; report
   §3.5); no projection from a tuple (item 18, weighed and kept out); a `match` and a
   `receive` are operands (item 19; report §5.9); a type variable is not-reply-carrying by
   what the body does with it, which closes the hole the cold read found in §6.6 (findings 2.1
   and 2.2; report §3.9); constant patterns and a reserved `after`, each weighed and kept
   (items 3 and 5); an initializer depends on every name it mentions (item 48 and finding
   1.13; report §8.5); and seven smaller rules from the cold read: source order for a callee
   and a pipe (1.2, §5.1), `..` only on a type with one constructor (1.6, §5.6), a type
   argument a value position only where its fields make it one (2.6, §3.9), the shape of an
   operator, `compare` or `negate` member (2.8, §4.8), a local `fn` never named like a
   variable in scope (2.9, §5.4), a receive guard's grammar written out (2.17, §6.3), and a
   local `fn`'s signature sharing the enclosing type variables (2.34, §3.9). **Decided
   2026-09-26:** a pure function stands wherever one with a mailbox type is expected, each
   expression of a pure function type opening its effect (1.1; report §3.9); a redundant
   clause is a type error, in `match` and `receive` (2.13; report §5.9); a foreign type's
   parameter written `k=` requires equality, as `Map`'s key does (item 39; report §4.7); one
   contract over several representations is a record of functions, taught in the guide's §7.3,
   and a check-only contract waits for a design (item 52, weighed and kept); an exported
   function takes no `Bool` that chooses a behaviour, and `Markdown.render` takes a `Style`
   (item 45; report Appendix E.0 rule 9). The log has an entry for each.
5. **Done 2026-09-26: processes and the system**, the third theme, after a survey of the
   BEAM languages, the typed and virtual actors, and the capability languages (the log's
   *Names, Restarts and Supervision*). Nothing is built yet; step 10 builds it, report first,
   in §4.6, §6.5, §6.6, §6.9, §7.4, §8.2, §8.5, §8.7, §9, §11.2 and Appendix E. Items 14 and
   25 stay with MVP 3.0 and 16 with MVP 2.7. The decisions, each argued in the log entry
   named:
   - **No registry; a restart keeps the address** (item 53). `restarting(Limit(restarts,
     within), f)` runs `f` again in the same process and mailbox on a fault, past the limit
     dying with the last cause, with no strategy and no backoff (*A Restart Has a Limit and
     No Strategy*). A service is a top-level binding, `export let service : Address(M) =
     ...`, and an initializer is checked as a `Never` process in the entry process before
     `main` (*An Initializer Runs as a `Never` Process*).
   - **A call ends when its callee faults or dies**: `Address.call` answers `None` at once,
     and `Address.callForever` faults its caller with the callee's cause, `Fault("callee was
     killed")` or `Fault("callee returned without answering")` (*A Call Ends When Its Callee
     Faults*, completed in *A Stream Keeps Its Own Time Limit*).
   - **Every fault reaches standard error**, with `restarted` after one the limit allowed;
     `monitor` stays one message at death (item 9; *Every Fault Reaches Standard Error*).
   - **A peer's service is found through its binding**, and `Peer.find` does it in one
     call in MVP 3.0 (*A Peer's Service Is Found Through Its Binding*).
   - **A `Supervisor` in the standard library, and `fault(cause)` in the prelude**, built in
     MVP 2.66 (*A `Supervisor` in the Standard Library, and `fault`*).
   - **A process's identity is a `Process`**, from `Address.process`, with equality; an
     address keeps none (item 24; *A Process's Identity Is a `Process`*).
   - **`stdlib/process.ern`**: `Process.live`, `site`, `mailboxSize`, `state` (item 26; *The
     Live Processes Are a Library Function*) and `Process.faults` with `FaultReport` (item
     28; *Every Fault Is Delivered to Whoever Subscribes*). The shell's doors to the
     runtime's processes go.
   - **A stream keeps its own time limit**: `Tcp.read`, `accept` and `connect` carry their
     milliseconds in the request (item 50; *A Stream Keeps Its Own Time Limit*).
   - **A system message is its module's to make**, and `Sys.stdout` and `Sys.stderr` take an
     `OutMsg` (item 47; *A System Message Is Its Module's to Make*).
   - **`Tcp.port(listener)`** (item 37; *A Listener Says Its Port*).
   - **`Terminal.subscribe` answers `Left(NotATerminal)`** where standard input is not a
     terminal, and the shell's `isTerminal()` goes (item 27; *A Subscription Says Whether It
     Has Keys*).

   The guide gains a section on services in step 10 and one on the supervisor in MVP 2.66.
6. **Done 2026-09-26: the standard library under E.0**, the fourth theme, in three batches.
   Nothing is built yet; step 10 builds it, report first, in Appendix E, each rewritten or
   new function with tests of the edge cases its contract names.
   - **Batch 1 decided 2026-09-26: a shim is only an operation that reaches the
     representation** (items 11, 13, 42, 46, and 34 with them). E.0 rule 1 says so, and
     each module's section names its primitives, chosen to pass data out and never to call
     back into Ernest: `Map` and `Set` keep six shims each, `empty`, `size`, `get` or
     `contains`, `put`, `remove`, `toList`; `String` keeps `indexOf`, `lastIndexOf`, `part`
     and `size` for searching, its Unicode operations and its conversions, and `startsWith`,
     `endsWith`, `contains`, `parts`, `copy` and `replace` become Ernest, so every search
     matches whole graphemes, which E.5 says (item 34); `Bytes` keeps `size` and `part`;
     `Path` keeps the separator and `isAbsolute`. `Random` is SplitMix64 in Ernest, `Seed` an
     abstract type, the same sequence everywhere, as E.13 says by naming it. `Path`, `Block`
     and `Inline` stay transparent, and a socket an address. Built in step 10, with tests of
     each edge case a contract names. The log's *A Shim Reaches the Representation*.
   - **Batch 2 decided 2026-09-26: a name follows the vocabulary** (items 40, 41, 38). E.0's
     third shape rule says that between a type and one its module builds on both directions
     are the building module's, `Map.fromList` and `Either.fromOptional`, and otherwise each
     is its argument's module's `toX`; nothing moves. `Set.intersect` becomes
     `Set.intersection`; `String.contains` stays a substring test, which the second shape
     rule says of text. E.0's shape rules cover the libraries under `libs/`, and `Ets` takes
     `put`, `get`, `contains`, `remove` and `close`. Built in step 10. The log's *A Name
     Follows the Vocabulary*.
   - **Batch 3 decided 2026-09-26: what the library lacked** (items 7, 8, 15, 20, 21, 22, 23,
     31, 35, 44, and the socket's addresses from item 37). Admitted: `Map.mergeWith`,
     `String.trimStart` and `trimEnd`, `Char.isAsciiDigit`, `Terminal.columns` in Ernest over
     a table from Unicode's width data, used by the shell's region and the Markdown library,
     `Io.show`, and `Tcp.peer` and `Tcp.local`. Kept: `String.lines` (its See also gains
     `split`), no `String.drop`, `dropWhile` or flatten (rule 4), and no text for `IoError`
     (rule 3; `Io.show` serves a log). E.0's fifth shape rule applies `with m` to what reaches
     a system reference, and rule 4 names the pairs the library keeps, `Io.debug` with
     `Io.show`. The log's *What the Library Lacked*.
7. **Done 2026-09-26: the toolchain**, the fifth theme: the options of `ernc` and `ern`, read
   whole for the first time, and the shell's own questions (items 29, 30 and 54). Items 29
   and 30 were defects and are fixed; the rest is built in step 10, report first.
   - **Decided 2026-09-26: one tool, the job its first word.** `ernc` goes into `ern`:
     `ern build`, `ern doc`, `ern run`, `ern test`, `ern shell` and `ern config`, with
     `--help` and `--version` as options. §11 states the rule for a directory's option:
     `-root` where its layout gives namespaces, `-dir` a plain directory, `-path` a root
     given more than once; `--out-dir` becomes `--build-root`. `ern config [--config-dir d]`
     creates the configuration directory itself (the cold read's 3.12). `--no-clean` goes,
     and `--errors short` and `--emit erl` become the flags `--short-errors` and
     `--emit-erl`. A refusal of an old spelling names the new one. Report §11.1 to §11.4,
     the README, the guide's tools page, the Makefile, the Emacs mode and the tests change
     together in step 10. The log's *One Tool, the Job Its First Word*.
   - **Fixed 2026-09-26: a word is Readline's** (item 29). The `M-` keys walk over runs of
     letters and digits and `C-w` back to a space, as §11.2 now says; the editor had used
     spaces for all five, against §11.2's promise of Readline's keys. The log's *A Word Is
     Readline's*.
   - **Fixed 2026-09-26: the path rule has one owner** (item 30). `:load`'s completion asks
     the compiler, `ern_shell:segment`, for the namespace segment a file or directory names,
     and the shell's copy of §11.1's path shape goes. The log's *The Path Rule Has One
     Owner*.
   - **Decided 2026-09-26: completion reaches a value's fields** (item 54). After a name the
     session binds or a module exports, and a `.`, `Tab` completes the fields its type
     selects (§3.5), along a chain; a name the unfinished input binds is not completed, as
     §11.2 says. Built in step 10, with terminal tests. The log's *Completion Reaches What
     the Session Knows*.
8. **The Erlang code's open questions**, from its review on 2026-09-25, gone through one by
   one after the language is decided and before what was decided is built, since a split
   is cheapest before the code it moves is changed. Where the code lives and how big it is:
   splitting `ern_typecheck` (2,600 lines), `ern_emitter` and `ern_shell` (1,700 each);
   `ern_diag` moving from the lexer to `utils`, since every stage uses it; one AST walker
   for the copies in `ern_reply`, `ern_exhaust` and `ern_typecheck`; a `#scope` record for
   the seven fields a definition saves and restores; the standard library's interfaces
   decoded in two places. How it reads: the parser's `|>`, which parses its right side
   twice and compares what is left; `Cond orelse fail(...)` in fifteen places; an effect
   error inside an unannotated lambda, which names the enclosing function. What it holds
   and for how long: an atom for every identifier the lexer reads, which a long session
   grows; the process table, which never shrinks; the Tcp waiters and processes that
   outlive a program; a subscriber subscribed twice; the session's environment in
   `persistent_term`, and `names()` computed at every `Tab`. What it leans on: `prim_tty`
   and `pubkey_cert_records`, OTP internals an upgrade may break; `module_info`, which no
   Ernest function may be called. And three shapes: `compile_source`'s mixed error values,
   `run/1` dropping the stacktrace, and the owner a qualified name records.
9. **The cold read's own findings**, those no theme takes, in a batch: the report's wording,
   its cross-references and examples, and the rules it leaves an implementer to invent.
10. **What was decided is built**, in seven sub-steps, each its own commit. Step 9 comes
   first, so that the report is edited in one pass rather than two. Before step 10 begins,
   `make sections` and `make coverage` are run and kept, so that it can show every new or
   changed section gained a citing test.
   1. **The gate: steps 5 to 7 read back as a whole.** A reader who took no part reads every
      log entry from *Names, Restarts and Supervision* to *Completion Reaches What the Session
      Knows* together, against principles 5 and 1 only, and reports: what the decisions add
      to the prelude, the standard library, the report and the toolchain, counted, and what
      they remove; any two decisions that overlap or give a second way to do one job; any
      decision a later one made unnecessary; and what could be dropped or merged, with what
      the language loses if it is. Each finding is decided with the user, one at a time,
      before anything below is written. The log's *A Gate Before the Build*.
   2. **The ledger.** A table in this plan, a row for each decision the gate leaves: the
      report sections it changes; the Erlang modules and Ernest files it reaches; its tests,
      the new ones and the mirror tests that must change, a mirror test planned for every
      new list that lives in the code and the report (the owners of the system message
      types, `Process`'s section, the new prelude names); the documents it reaches, the
      guide, the README, the shell's design note and `shell/README.md`, the module pages,
      `examples/` and the Emacs mode; and what it depends on, `Process` before
      `Process.faults`, `restarting` before `Supervisor`. The dependencies give the order of
      sub-step 6. Each row carries the grep that finds what the decision makes false, `ernc`,
      `--out-dir`, `intersect`, `Ets.insert`, the guide's §6.4 sentence on a new address and
      the like, so that the commit that builds it removes every such sentence.
   3. **Every report change in one pass**, Appendix E among them, as a commit of the report
      alone: `make xref` and `make test-docs` green, the count recorded in the log's
      *Measure*, and a section over 600 words read for restating.
   4. **The whole report read cold.** A reader who took no part reads the report as it now
      stands, every section and not the changed ones alone, since the decisions cut across
      sections: a service binding reaches §4.6, §6.5, §8.5 and §8.7 at once. With it the two
      sweeps a batch of report changes asks for, the guide against the report and every other
      document against the report and the code. What they find is decided before the build.
   5. **The toolchain first.** `ern build` and its siblings replace `ernc` before anything
      else is built, since the rename reaches the Makefile, the tests, the README, the guide
      and the Emacs mode, and every later test is then written against the final commands.
   6. **The build, in the ledger's order**, one decision or tight group a commit, each with
      its tests and with the sentences its row's grep finds removed in the same commit;
      `make test` at the end of each group.
   7. **The guide's section on services, and the closing sweep.** The section teaches a
      service as a top-level binding, `restarting` and its `Limit`, the `start` and `service`
      pair for tests, a call that ends when its callee faults, and `fault`; §6.4's sentence
      that a restarted service must hand out its new address goes. The section on the
      supervisor is MVP 2.66's. The document sweep closes the step.

---

## MVP 2.66 (the standard library's `Supervisor`), about three days

MVP 2.65 step 5 decided what a supervisor is (question 6; the log's *A `Supervisor` in the
Standard Library, and `fault`*), after the claim of 2026-09-13, that a supervisor is fifteen
lines of `spawn`, `monitor` and `receive`, met a restarted child's new address. This item
builds it, after step 10 of 2.65 has built `restarting`, `fault`, the service binding and
the fault report it stands on.

- **`stdlib/supervisor.ern`**, in Ernest but for one shim, the in-place restart of a child,
  which only the host can do. Appendix E gains its section, with its module page and
  examples as E.0 rule 6 asks.
- **`examples/supervisor.ern`**, three long-lived services under one supervisor as
  top-level bindings, faulted on purpose, read back against principles 1 and 2 and E.0.
  The guide gains a section on the supervisor, after the one on services: a tree as
  top-level bindings, the three strategies, the group's limit, and stopping.
- **Two things to settle in the build, report first where the report is silent.** A
  supervisor that faults by a defect of its own, not by `fault`, leaves its children
  running, since nothing owns a process; a watcher the module spawns beside it, holding
  the children's addresses and killing them on its `Down`, is written in Ernest. And
  stopping a child is `kill`, which gives it no chance to finish; a child that must
  finish carries a stop message in its own protocol, which the module cannot impose.

---

## MVP 2.7 (a program started from a command line, and the appendix of libraries), about a week

What a command-line program needs, report first: `Sys.args : List(String)` and `Sys.env` in
§8.2 and §9.7 as runtime-bound values, ambient as the other `Sys.*` references are, and an
exit status in §8.6. The guide's cold read asked for the arguments at once
(`language_feedback.md` item 16, 2026-09-24); an entry point that takes a `List(String)` is
weighed against `Sys.args` before the report changes, and parsing options from the list is a
library's, by E.0. With `Sys.env`, the shell reads `NO_COLOR` in Ernest, where its front end
reads it today.

**A simple log.** Noted 2026-09-26, to be decided in this milestone: `ern` writes what it
prints to standard error, the fault reports first among them, to a file as well, and
perhaps only there. A very simple logger, the smallest thing that keeps a long-running
program's faults; whether it is an option to `ern` or a runtime-bound value in §8.2 is the
decision. `Process.faults` (MVP 2.65 step 5, item 28) is beneath it, so the log of faults can
be a process written in Ernest that subscribes and appends.

**The report lists the libraries that exist**, `libs/ets` and `libs/markdown`, in a new
informative appendix, one section per library with its signatures and contracts, and a mirror
test holding each compiled interface equal to it, as `ern_prelude_tests` holds the prelude to
Appendix E. Third-party libraries are not listed; Appendix D is what they follow.

---

## MVP 3.0 (peers), about three weeks

Designed in [`node_protocol.md`](node_protocol.md), which owns the protocol: node identity
as the hash of the TLS key, incarnations, addresses, spawning, monitors, ordering,
connections and the wire encoding. It is marked tentative, and it is written against an
older spelling of the language; the report changes it implies are listed at the end of this
section and are decided before any of it is built.

Nodes that reach each other and the four operations of §8.7 between them, with code shipping
restricted to nodes running the same build: identical definitions have identical hashes,
which is §8.7 in its easiest case. A peer whose build differs is refused with an error naming
3.1. Split from 3.1 on 2026-09-20, since content addressing proper is the larger half and
peers are the useful one.

- `spawn(Peer(name), f)` and `remote(f)` over the peers in `ernest.conf`, authenticated with
  the configured keys: the connection is `ssl` with the peer's public key from `ernest.conf`
  as the only trust, read with `public_key`, inside `ern`, and a program never sees either
  module. `remote` picks among peers flagged `"remote-peer": true` by load, criterion chosen
  then.
- Peer loss as §10 says: every process on the lost peer dead with `Fault("peer lost")`,
  monitors delivered, pending `remote` calls `Left(PeerLost)`; a peer that reappears is a new
  instance.
- **What the protocol note asks of the report**, each to be decided before it is built:
  `Down` gains `Unreachable` and a cause for an address that never had a process, since a
  watcher must tell a lost connection from a death (§9.3, §6.9); §6.4 gains that what
  arrives is an unbroken prefix of what was sent and that a sender is told nothing of a
  drop; and the note's `spawn_at(node, f)`, `MonitorRef` with `demonitor`, and a name
  registry are surface the report does not have — `spawn(Peer(name), f)` is one primitive
  with a placement argument (§9.4), `monitor` is one message and no handle (§9.5), and
  §6.5 refuses a registry outright. The registry is the one of these that is a language
  question rather than a protocol question. MVP 2.65 step 5 decided it: a service is a top-level
  binding, and a peer's service is found by reading its binding on the peer. Built here:
  **`Peer.find(name, fn() = M.service)`**, and §8.7's two sentences on a node's own
  initialization and on a definition that differs by hash. Its failure type is decided
  with item 14, `remote`, since both evaluate a pure function on a peer; `Peer` as a
  namespace beside the constructor `Peer` of `Where` is checked against §4.2. The note's open question 11, a way to stop an uncooperative
  process, is already answered: `kill` is the language's (§6.9), asynchronous, and a killed
  process's monitors see `Killed`; across nodes it needs a frame the note's table lacks.
- **Where the two notes disagree with the report, found 2026-09-24**, also to be decided
  before building: the protocol note encodes values in Ernest's own format where §8.4 uses the
  runtime's external term format; both notes drop a payload whose code cannot be fetched or
  resolved where §7.4 and §8.7 fault the caller or the sender; the distribution note hashes no
  name where §8.7's normalization keeps the qualified names of external references; both write
  the effect `{Proc m}` where the report writes `with m`; and the protocol note's open question
  on stopping a process is §6.9's `kill`.
- **Whether `remote` stays**, `docs/language_feedback.md` item 14, decided first in this
  milestone, before `remote` is built over peers: once `spawn(Peer(name), f)` ships code and
  answers across nodes, `remote` may be a second way to do what a spawned process that
  answers does. If it goes, §6.7, §9.4, `RemoteError`, the `"remote-peer"` flag and the
  guide's §8.1 go with it, and the bullets above that build it are rewritten. Decided with
  it, item 25: `spawn(Remote, f)`, a third `Where` that gives the runtime's choice of peer to
  a process, with which `remote` is a composition; the flag would then admit any process
  and not only a pure function.
- **Two more places the protocol note disagrees with the report, found 2026-09-24 in the
  closing sweep of MVP 2.61**, also decided before building: the note's `spawn_at` never
  fails at the call and returns a dead address, where §6.2 faults the caller on an unknown or
  unreachable peer; and the note's `Down` is `Exited | Crashed(Text) | NoProcess |
  Unreachable` with no `function`, where §9.3 and §6.9 have `Down(reason, function)` with
  `Returned`, `Killed`, `ProgramEnd` and `Fault(String)`.
- **An adapted address across a node** is open, and report first when it is taken. `via(f,
  addr)` has been the pair of the function and the address since 2026-09-20 (§6.5), so an
  `Address` that leaves a node may carry a function, which is the same question as a message
  that carries one. Whether the function travels or the adaptation stays behind is the
  decision.

---

## MVP 3.1 (content addressing), about four weeks

Designed in [`code_distribution.md`](code_distribution.md), which owns it: what is hashed,
names as a build product, the loader beside `code_server`, have/want before every message,
the trust model, and the atom-leak restart. Marked tentative, and two things in it meet the
code as it stands. Its section 11 asks MVP 1 for a named IR stage with locals numbered by
position: there is none, since `ern_emitter` goes from the typed AST to Erlang's abstract
format in one traversal, so the choice is to introduce an IR here or to canonicalise the
typed AST, which is the decision below either way. Its section 3.4 hashes every declared
type nominally, name included, which §8.7 says too since 2026-09-24; but it hashes an
abstract type as it hashes any other, where §8.7 adds the signature to an abstract type's
hash, and the note is brought to §8.7 before it is built. Its section 6 runs nodes in
embedded mode, which loads nothing from the code path on demand, where §11.2 since
2026-09-24 finds a `foreign fn`'s own Erlang module on the load path; which of the two a
node running hash modules does is decided here, report first.

Hash modules never change, so versions coexist on a node for as long as a process runs one
([`code_distribution.md`](code_distribution.md) section 8). The shell's reload then ends
nothing: §7.3's unloading cause, §7.4's `Fault("its code was unloaded")`, and §11.2's
second-reload rule go in this MVP, with the test that pins them.

§8.7's identity in full. The first decision is what "normalized definition" means, since two
nodes must agree exactly: the typed tree or the untyped one, whether local names are erased,
and what becomes of the effect variables, which are inferred and never written.
`ern_emitter:iface_hash/1` already hashes a canonical interface; whether it grows into the
definition hash or a second scheme stands beside it is part of that decision, and the cheaper
answer is the first.

- Every definition gets a hash of its typed AST; modules are named by hash; a registry per
  node `{Hash -> Module}`. A message with a function carries the hash, and a node that lacks
  it fetches the code from the sender. Erlang's module distribution is not used.
- Two nodes with different versions of one type: reject at send, each message carrying its
  type hash; fetch on receipt is the alternative, decided when peers exist and the two can be
  measured. The log has both shapes.
- The library fetcher, decided 2026-09-19: `ern fetch name url` fetches a library's source
  tree from a git URL into a directory on the load path, compiles it, and records the hashes
  of its definitions. No resolver, no semver, no lockfile beyond those hashes, and no
  registry; discovery by name is a tooling question for later.

---

## MVP 3.2 (the libraries, as they are wanted)

Decided 2026-09-25: the libraries not yet written wait, and each is written when our work
needs it, MVP 3.0 and 3.1 among that work, when someone asks for it, or when we want it (the
log's *Libraries As They Are Wanted*). Each is an Ernest source root
under `libs/<name>/` that a program adds with `--load-path`, with `stdlib/`'s test discipline,
documented in one pass to [`module_doc_template.md`](module_doc_template.md) with its executed
examples as its first user, and a section in the appendix of libraries. Own repositories
later, when there is a package story. Named so far:

- **`libs/json`**, pure Ernest: a `Json` type, a parser over `String` returning `Either`, a
  printer.
- **`libs/base64`**, a shim over `base64`.
- **`libs/tls`**, a shim over `ssl` and `public_key` with their manual pages open: `listen`,
  `accept`, `connect` returning `Address(SockMsg)` with the encryption inside the socket
  process, so `Tcp.read`, `write` and `close` serve both. Certificate verification is the
  caller's to ask for.
- **`libs/http`**, Ernest over `Tcp` and `Tls`: request and response types, a client. No
  server; that is the webserver example's job. With it, `examples/fetch.ern`, a command-line
  tool that fetches JSON over HTTPS and prints a report, since a paper program travels with
  the stack it needs, and `Time` in Appendix E over the clock's milliseconds, which only it
  wants so far.
- **`libs/regex`**, a shim over `re`, a library and never syntax: `Regex.compile : (String)
  -> Either(RegexError, Regex)` with `Regex` a foreign type, so a bad pattern is a value the
  program handles, as Gleam's `gleam_regexp` does.
- **`libs/crypto`**, a shim over `crypto` for hashes, HMAC and random bytes; **`libs/uri`**,
  pure Ernest or a shim over `uri_string`; **`libs/zlib`**, a shim over `zlib`.

---

## Not in any MVP

A canonical formatter, `ernc --format`, one style and no configuration, mechanical over the
grammar; it lands before a second person writes Ernest. `Slot(a)`, a one-shot credit parallel
to `Reply(a)`, is out on principles 2 and 5; the log holds its shape if the verdict is
revisited. String interpolation is declined for now on principles 2, 3 and 4. Erlang
scheduling hints wait for a program that needs them. No HTTP server, ever, and no database
connectors: those are libraries for others to write on Appendix D's pattern.

---

## Standing gaps

- **§3.11, §8.3 and §8.7 have no citing test**, which `make sections` lists. All three are
  MVP 3.0 and 3.1 material and unimplemented; anything else that appears there is a gap.
- **How the region measures a wide character.** A tab is settled — painted as the spaces to
  the next stop of eight — but a wide glyph is one column to the region and two to the
  terminal, and nothing in the runtime knows a glyph's width. `expand` in
  `shell/shell/region.ern` is the one function that has to learn it. The design note's only
  open item.
- **`e_bits` and `p_bits` are in no example**, so the AST coverage test excludes them
  (2026-09-19).
- **A label at the first use of the variable whose type a mismatch names** was planned for
  §3.4's placement work and not built (2026-09-18).
- **A function value that foreign code returns is not checked when it is called**, though
  §7.4 says its result is checked against its declared result type (found by the cold
  read's check, 2026-09-25). The fix is the address proxy's shape: the boundary wraps such a
  value so that each call's result is checked, as a proxy checks each message. With it goes
  the one way an ill-typed value reaches Ernest arithmetic, where the host's error is
  reported as `Fault("division by zero")` whatever the operator was; only a zero divisor
  gives that cause. Built in MVP 2.65's last step, with what was decided.

---

## Done

A paragraph a milestone: what it delivered, and where its reasons are. The work in detail is
in the history and the log's dated entries; what binds now is the report's, the
architecture note's and the style guide's.

### MVP 1 — the chain (done 2026-09-18, tag `mvp1`)

Parser, types and BEAM proved with the report's language unchanged, a subset accepted: no
`Float`, no ownership rule for abstract types, no foreign code, no `Tcp`, no distribution,
and exhaustiveness checking from the start. A hand-written lexer and a direct
precedence-climbing parser, Hindley-Milner with an effect slot (§3.9), the reply discipline
(§6.6), one Erlang module per Ernest module, and one diagnostic record from every stage
(§11.5); [`architecture.md`](architecture.md) says how they are arranged, and the log's
entries of 2026-09-17 and 2026-09-18 why. The report was pared the same day, 13,084 words
to under 8,000, and read back the next, which restored five lost rules; the rule since is
in CLAUDE.md.

### MVP 2 — the rest of the report on one node (done 2026-09-19)

Each item was a rule MVP 1 refused or did not check: `Float` and operators on user types
(§3.1, §4.8, §5.1); `foreign fn` and `foreign type`, checked at the boundary by
`ern_boundary` (§4.7, §8.4); bitstrings (§5.11); pattern alternatives (§5.9); `Io.debug`
(E.1); raw strings (§2.5); abstract-type ownership (§4.4); the reply discipline through
function values (§6.6); `Deadlock` as global quiescence (§8.6); and nine points from the
consistency pass. The log's entries of 2026-09-19 hold the arguments.

### MVP 2.5 — a complete standard library (done 2026-09-20)

Twenty-one modules in Ernest under E.0's rules, a shim only where its first rule admits one;
the system processes, each used through its Appendix E module and never by `send`; the
checker reading the standard library's compiled interfaces as any dependency's; the shape
of a module's documentation, [`module_doc_template.md`](module_doc_template.md), and the
documentation in the `.erc`'s EEP 48 chunk; four paper programs, three under test. `Tcp`
was measured at 1.8 times raw Erlang with a process per socket, and the processes kept.
The naming of the toolchain, `ern_<thing>` and `ern@<namespace>`, was done on the way; the
log's *One Token for the Project* holds it. Erlang's standard library, read module by
module, is under "Reference".

### MVP 2.9 — an Emacs major mode (done 2026-09-23, out of order)

`emacs/ernest-mode.el` and its tests, run by `make test-emacs`;
[`emacs_mode.md`](emacs_mode.md) owns the mode. It gave the style guide six indentation
rules, the sources were reindented to them, and a test mirrors the mode's word lists
against the lexer.

### The report read as a Wirth report (done 2026-09-23 and 2026-09-24)

A standalone reading of the report as a Wirth report and against §0. Its plain errors were
fixed and about thirty issues decided one at a time, each a report change with its entry in
the log. The largest: a statement other than a block's last has type `Unit`, and a value is
discarded with `let _ = e` (§5.4); `Ets` left the standard library for `libs/ets` (§10, E.0
rule 1); a fault is a death with `Fault(cause)`, every cause listed in §7.4, a deadlock the
entry process's (§8.6); `Prelude.X` reaches a shadowed prelude name (§4.2); a parenthesized
right side of `|>` is a value (§5.7); §9 states what makes a type the prelude's; a
`String`'s unit is a grapheme (E.5); the bit syntax dropped `bits` and `native` (§5.11); and
§6.6 was rewritten top-down. A last reading closed it, finding seams and no new rule.

### MVP 2.61 — the guide as the user's document (done 2026-09-24, out of order)

The guide rewritten to teach Ernest on its own, in nine steps, each a stop: every example
checked by `test/ern_guide_tests.erl`, an opening that shows four mistakes `ernc` finds,
one running example, a section on failure with a supervisor, pages for the tools and for the
Erlang programmer, a two-reader sweep, and a cold read by a reader new to Ernest. It changed
§11.2 and §11.5 and fixed two defects of `ernc` and `ern`; the log has each.

### MVP 2.6 — the shell (done 2026-09-25)

The shell, an Ernest program under `shell/`, designed in
[`shell_design.md`](shell_design.md), which owns the design, and specified by §11.2; the
guide to its code is [`shell/README.md`](../shell/README.md). Five checkpoints, each a stop:
expressions (2026-09-20); bindings, the commands, fault reports and the startup files
(2026-09-20); the terminal and its live region (2026-09-21); the line editor, the history
and its search, multi-line input and paste (2026-09-21); and completion and documentation
(2026-09-24). Then a closing sweep by two readers, a session of real use whose thirteen
findings each became a rule of §11.2 with a regression test, an independent review whose
five more did the same, and a last sweep of the documents. On the way it built
`test/ern_pty.py`, the pseudo-terminal harness every terminal test runs through; turned
`Keys` into `Terminal`; made the pure parts modules of their own, each tested by
`ern --test`; stated the rule for `foreign` now in CLAUDE.md; split `make test` into areas;
and found about twenty defects in the toolchain, none of them the shell's. The log's
entries from 2026-09-20 to 2026-09-25 hold every argument.

### `libs/markdown` — a CommonMark renderer (done 2026-09-25, now under MVP 3.2)

Pure Ernest, about five hundred lines: `Markdown.parse` reads CommonMark 0.31's blocks and
inlines, and `Markdown.render` lays them out at a width, with the terminal's styles or as
written; where it is simpler than the specification, its doc block says so. How a heading
looks at a terminal is policy inside a namespace of its own, so E.0 puts it under `libs/`.
The shell renders `:doc` and `Shift-Tab` with it. Its place in the report's informative
appendix of libraries is MVP 2.7's, with `libs/ets`'s.

### The code read back after the shell (done 2026-09-25)

Every line of Ernest under `shell/`, `stdlib/` and `libs/`, and every line of Erlang under
`erl/`, read for what goes against the principles, for clumsy code, and for defects; about
twenty-five defects fixed, each with a regression test, and the report's §2.3, §7.4 and §11.2
changed first where a fix needed a rule. The shell gained `Shell.Command` and
[`shell/README.md`](../shell/README.md). The log's *The Code Read Back* has the decisions,
the feedback list the Ernest questions it raised, and MVP 2.65's step 8 the Erlang ones.

---

## Reference

### The emitter's two tables

Decided before the emitter was written and kept as its specification; the code is the truth
now, and these are what a change to it is read against. Values follow §8.4 throughout. Types
are erased: `type_decl`, `abstract_decl`, `foreign_type_decl`, `signature`, `field` and the
`t_*` records produce no code, the interface chunk carrying them.

| Record | Erlang |
|---|---|
| `constructor` | nullary: the quoted atom; positional: `{'C', V}`; named: `{'C', V1, ..., Vn}` in canonical field order |
| `fn_decl`, top level | a function clause; exported if `export`; a type member is `'Stack.push'` |
| `fn_decl`, in a block | lifted to a module function with its free variables as leading parameters; the name is bound to a closure over them |
| `let_decl` | `name/0`, reading a value the module's `'$init'/0` computed once in dependency order before `main` (§8.5) |
| `foreign_fn_decl` | a clause calling the named `M:F/A` |
| `param` | the pattern in the clause head |
| `e_lit` | integer, float, or char literal; string as a binary; bool as an atom |
| `e_var` | a local: the Erlang variable; a top-level fn as a value: `fun f/N`, and another module's `M:'$fun'(f, N)`, a fun of the version current when it is taken (§11.2); a top-level let: `name()`; a prelude name: table below |
| `e_con` | as `constructor`; a single-positional constructor as a value: `fun(V) -> {'C', V} end` |
| `field_set` | its value at its canonical position |
| `e_tuple`, `e_list` | tuple, list |
| `e_bits`, `bit_seg` | bit syntax, each value checked by `ern_bits` |
| `e_block` | a sequence; `binding` with `=` as `Pat = Expr`; `binding` with `<-` as a `case` on `Left`/`Right` or `None`/`Some` with the rest of the block in the second clause (§5.5) |
| `e_call` | `F(Args)` for a local; `f(Args)` or `'ern@m':f(Args)` for a known function; a prelude name: table below |
| `e_neg` | `-E`; on `Float`, `0.0 - E`, so that no negative zero arises (§3.1) |
| `e_binop` | `Int`: `+ - * div rem` (`/` is `div`, `%` is `rem`; a zero divisor's `badarith` becomes `Fault("division by zero")`); `<>`: binary append for `String` and `Bytes`, `++` for `List`; `==`, `!=`: `=:=`, `=/=`; `<`, `<=`, `>`, `>=` on `Int`, `Float`, `Char`, `String`: the native operators, since binaries compare by code point; `&&`, `\|\|`: `andalso`, `orelse`; `::`: `[H \| T]` |
| `e_lambda` | `fun(Pats) -> Body end` |
| `e_if` | `case C of true -> T; false -> E end` |
| `e_match`, `clause` | `case`; a clause whose guard is not an Erlang guard expression falls through by a continuation: `Rest = fun() -> <remaining clauses> end`, so no code is duplicated |
| `e_receive`, `after_clause` | `receive ... after T -> B end`; a receive guard is §6.3's guard expression and is emitted as an Erlang guard |
| `p_wild`, `p_var`, `p_lit` | `_`, a variable, a literal (a string as a binary) |
| `p_con`, `field_pat` | as `constructor`, an omitted named field as `_` |
| `p_tuple`, `p_list`, `p_cons` | tuple, list, `[H \| T]` |
| `p_as` | `Var = Pat` |
| `p_bits` | bit syntax |

**Prelude name to Erlang** (§9.4 to §9.7, Appendix E). Called, or taken as a value: a
runtime name as `fun ern_rt:F/A`, and a standard library module's through `M:'$fun'(F, A)`
since 2026-09-25, as another module's function is (the `e_var` row).

| Name | Erlang |
|---|---|
| `self` | `ern_rt:self/0` |
| `send`, `answer`, `via`, `monitor`, `kill` | `ern_rt:send/2`, `answer/2`, `via/2`, `monitor/2`, `kill/1` |
| `spawn` | `ern_rt:spawn/3`, the third argument the spawn site for `Down` (§6.9) |
| `Address.call`, `Address.callForever` | `ern_rt:call/3`, `call_forever/2` |
| `remote` | MVP 3; until then `ern_rt:remote/1` answers `Left(NoRemotePeer)` |
| `Int.+` and the other `userop`s on `Int`, `Int.negate` | the inline operators above |
| `Float.*` | inline, the operands bound first and the operation's own `badarith` caught and raised as the §7.4 fault |
| `String.<>`, `List.<>`, `Bytes.<>` | inline as above |
| `Int.div`, `Int.mod`, `*.compare`, `Int.toString`, ... | `'ern@int':'div'/2` and so on: the namespace's module |
| `todo` | `ern_rt:todo/1`, which faults with `todo: ` and the text |
| `Sys.stdout`, `Sys.clock`, `Sys.stdin`, `Sys.terminal`, `Sys.fs`, `Sys.tcp` | `ern_rt:sys(stdout)` and so on; `Io`, `Terminal`, `Fs`, `Tcp` are the namespaces' modules |
| `Clock.*`, `Path.*`, `Random.*`, `Io.*`, `List.*`, ... | `'ern@clock':alarm/2`, `'ern@io':println/1`: the namespace's module |

### Erlang's standard library, read module by module (2026-09-18)

Every user-facing OTP module is a row; what is not a row is OTP's own machinery, which
Ernest's concepts or toolchain replace.

| Erlang | Ernest | In Appendix E | Waiting, and when | Out, and why |
|---|---|---|---|---|
| `erlang` BIFs | the language; `Int`, `Float`, `String`, `Char` | `spawn`, `self`, `send`, `monitor` as §9.4 and §9.5; `abs`, `min`, `max`, rounding, `toString`, `toFloat`, the bit operations | an exit status for §8.6, `Sys.args`, `Sys.env`, MVP 2.7 | `register`, `whereis`: §6.5 has no registry. `link`, `exit`, `throw`, `catch`: §7 and §6.9. `term_to_binary`: MVP 3's transport. `phash2`, `md5`: a hashing library. `make_ref`: identity is a `Reply` or an address. `iolist_to_binary`: `String.fromList`, `<>`. `memory`, `system_info`: the runtime's |
| `lists` | `List` | E.2, thirty-one functions and `<>` | | `first`, `rest`, `flatten`, `count`, `map2`, `sum`, `max`, `min`: one pipe each, rule 4. `scan`, `mapFold`, `window`, `chunk`: a `foldLeft` with an accumulator, and each hides a choice about the ends. `permutations`, `transpose`, `combinations`: specialities. `key*`: `Map` |
| `maps`, `dict`, `orddict`, `gb_trees`, `proplists` | `Map` | E.3 | | the four alternatives: history |
| `sets`, `ordsets`, `gb_sets` | `Set` | E.4 | | `symmetric_difference`, `is_disjoint`: compositions |
| `string`, `unicode` | `String`, `Char` | E.5, E.6 | | the list-based half of `string` |
| `io`, `io_lib` | `Io` | E.1: `print`, `println`, `printError`, `printlnError`, `debug`, `readLine` | | `format`: no format strings, `<>` and `toString` are the one way |
| `file`, `filelib` | `Fs` | E.17, nine functions | `watch`, and the working directory with absolute paths, MVP 2.7 | `wildcard`: a glob library. `fold_files`: five lines over `List` |
| `filename` | `Path` | E.14, eight functions | | `absname`, `expand`: `Fs`'s, they read the working directory. `nativename`: a `Path` is in the runtime's syntax |
| `timer` | `Clock` | `now`, `alarm`, `alarmAt` | `Clock.monotonic` | `send_interval`, `cancel`: E.15's positions. `sleep`: `receive { after ms -> Unit }`. `seconds`, `minutes`: arithmetic |
| `rand` | `Random` | E.13: `seed`, `next`, `nextFloat` | | |
| `math` | `Float` | the operators, `abs`, `min`, `max`, `round`, `floor`, `ceil`, `truncate`, `toString`, `sqrt`, `pow`, `exp`, `log`, the trigonometry | | `looselyEquals`: the tolerance is the program's. `toPrecision`: a format, and §9.6 has no format strings |
| `gen_tcp`, `inet`, `socket`, `ssl` | `Tcp` | E.18 | `Udp` as its own module, a later MVP | socket options: tuning is a library's. TLS: `libs/tls` in MVP 3.2, returning the same `Address(SockMsg)` |
| `ets` | `libs/ets` | Appendix D | | match specifications, `qlc`: `Ets` is a key-value table |
| `os` | `Sys` | | `Sys.env`, `Sys.args`, MVP 2.7 | `cmd`: a door to the system a program opens itself, MVP 3 at the earliest |
| `calendar` | `Time` | | a `Time` type and its parts, MVP 3.2 | formatting: a format is the program's, rule 3 |
| `binary` | `Bytes` | E.20, and `<>` | | `split`, `match`, `replace`, `encode_unsigned`: `<<...>>` and the `Int` operations |
| `array`, `queue` | | | | `List` and `Map` give both, rule 4; a persistent array is a library |
| `eunit` | `Test` | §9.3's `Test` and `TestResult`, run by `ern --test` (§11.2) | | |
| `base64`, `json`, `uri_string`, `re`, `crypto`, `zlib`, `dets`, `digraph`, `sofs`, `erl_tar`, `zip`, `disk_log`; the applications `ssl`, `inets`, `xmerl`, `public_key`, `asn1`, `mnesia`, `snmp` | libraries | | | each a namespace of its own on Appendix D's pattern, never stdlib |
| `observer`, `dbg`, `cover`, `debugger`, `dialyzer`, `edoc`, `common_test`, `syntax_tools`, `parsetools`, `argparse`, `escript` | | | | tooling: `ernc --doc`, Ernest's own types, the compiler, `ern`; an argument parser is a library |
| `gen_*`, `supervisor`, `proc_lib`, `sys`, `logger`, `application`, `code`, `rpc`, `erpc`, `global`, `pg`, `net_kernel`, `persistent_term`, `atomics`, `counters`, `init`, `heart`, `os_mon`, `wx`, `erl_*`, the shell | | | | a function with a mailbox type, fifteen lines of `spawn` and `monitor`, `send` to a sink, MVP 3's distribution, the runtime's internals, `ernc` and `ern` |

Gleam's `gleam_stdlib` v1.0.5, Elixir's core and Haskell's `base` were read the same way, and
what they have that this table does not take is a position, not a gap: `gleam/order`,
`gleam/pair` and `gleam/function` (patterns and compositions), `string_tree` (a builder
BEAM's binary append makes unnecessary), `gleam/uri` (a library), `dynamic/decode` (`Foreign`
and a JSON library), `string.inspect` (no universal printer), `bool.guard` (`<-`); Elixir's
`Stream` (§5.1 is strict, a lazy source is a process) and `Keyword` lists (`Map`); Haskell's
type classes (`toString` per type, `==` structural, `compare` per type).

### Tools, and what was decided before the start

Erlang, OTP 29 (raised from 27 on 2026-09-20), Makefiles in the style guide's shape; EUnit
per application under `erl/*/test`, integration tests under `test/`; the toolchain shipped as
the escript sources in `bin/`, which put `erl/*/ebin` on the code path with no escriptize
step. Also decided before the start and unchanged: the `erl/` layout, one Erlang application
per stage; the error format of §11.5; one Erlang module per Ernest module.

### The MVP 1 time budget

| Phase | Parts | Days |
|---|---|---|
| 1 | parser, type inference, abstract types, standard types | 24.5 |
| 2 | compiler, processes, standard library, code generation | 9 |
| 3 | integration, tests, documentation, error placement, paring | 11 |
| **Total** | | **44.5, about nine working weeks** |

The actual: MVP 1 done 2026-09-18, MVP 2 the day after, MVP 2.5 the day after that.
