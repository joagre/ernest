# Ernest Implementation Plan

The roadmap: what will be built, in what order, and what is built already. Why anything is the
way it is belongs to [`decisions.md`](decisions.md), what the language is to
[`ernest_report.md`](../ernest_report.md), how the code is arranged to
[`architecture.md`](architecture.md), and the commands and what the toolchain does not do yet
to [`development.md`](development.md).

Read "Where we are" first. The milestones to come follow in order, then what is in no
milestone, the standing gaps, and what is done.

---

## Where we are

**MVP 2.98 is under way.** The decision on how a contract is written, which
[`contract.md`](contract.md) weighs, is taken in MVP 2.99b, after the first release
(2026-09-29). Every earlier milestone
is done, the last MVP 2.96 on 2026-09-29; MVP 2.9, MVP 2.61, `libs/markdown` and MVP 2.8 were
taken out of order. Each has its paragraph under "Done". The first release is MVP 2.99's.

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
| **MVP 2.98** | **what the first review left** | **under way** |
| MVP 2.99 | running as a service, and the first release | |
| MVP 2.99b | one contract, several representations: an ordered set | the contract's decision first (`contract.md`) |
| MVP 3.0 | peers: distributed code and the node protocol | |
| MVP 3.1 | content addressing | |
| MVP 3.2 | the libraries, as they are wanted | `libs/markdown` done 2026-09-25 |
| MVP 3.9 | the review before 1.0: soundness argued and generated against | |

---

## MVP 2.98 (what the first review left), about two weeks

What the review of MVP 2.95 found and did not fix there, decided 2026-09-28 and moved from MVP
3.0 the same day, since none of it needs a peer (the log's *MVP 3.0 Is Distributed Code and the
Node Protocol*). It is taken in this order: 4, 5, 6, 3, 1, 2, the design questions of 2
discussed with the user one at a time as they are met.

1. **[`findings.md`](findings.md)'s `cheap` lines**, a batch a document, done 2026-09-29 (the
   log's entries from *The Report's Cheap Lines* to *The Documents' Cheap Lines*). Measuring
   the loads for it found the shell's code growing with every input, T26's sites compiled into
   each input's module, fixed the same day.
2. **Its `2.98` lines**: the report's contradictions and silent cases, among them `Io.show`'s
   dependence on the type at the call; a type that breaks laid one alternative a line, as a
   `match` is, decided with the user and done 2026-09-29 (N10; the log's *A Type That Breaks
   Holds One Alternative a Line*); three decisions of the shell's, decided with the user and
   done 2026-09-29 (the log's *Three of the Shell's Choices*): a typed input named by its count,
   `input 3` (T26), line mode taking an input's further lines as a terminal does (T29), and the
   shell's exit status and streams stated in §11.2 (T32); the diagnostics'
   positions and labels (§11.5); the guide's gaps, `Tcp` untaught among them; and the documents
   the code has left behind.
3. **`Fs` brought to what a program needs of a file system** (the log's *What `Fs` Holds*):
   `create`, a new file or none; `removeAll`; `setModified`, done 2026-09-29, `readLink`
   answering `None` for what is no link; and, decided with the user, a file read and written in
   parts, which a file too large to hold whole needs, done 2026-09-29 as `readRange`, a part read
   by its path, and `append`. An entry's kind and
   its links were built in MVP 2.95.
4. **The formatter's one-constructor type**: a type of one constructor too long for its line
   breaks inside its parameters, `SetOps(s,` and `a)`, where `style.md`'s rule for a type
   breaks after its `=`, as the guide's §7.3 shows (found 2026-09-29); done 2026-09-29, one
   alternative breaking after the `=` as several do, but where a doc block opens its bracket.
5. **Three changes that take work from `make test`**, done 2026-09-29: the shell's tests waiting
   for the prompt or a program's output, not a fixed time, 17 of 21 sleeps now text a test
   waits for and the four left moments no text marks, a game's ticks, a late paste end, and
   two Tabs that must do nothing, with no gain in time, the area being bound by its CPU; `ern_cli`'s build in a module of its own, so that
   the compiler's hash leaves out its other jobs and a change to them recompiles nothing, done
   2026-09-29 as `ern_build`; and the programs area's builds in the test's node, where a
   launch of `ern` costs 0.6 seconds a build and the node 0.08, done 2026-09-29, the area 23
   seconds to 20 and `make test` 93 to 90.
6. **`==` on a value that holds a function** (found 2026-09-29, weighing the contract): §3.10
   makes it a type error, and the checker accepts it in two ways. A declared type whose field
   holds a function, `type Box = Box((Int) -> Int)`, passes, since the check reads the type as
   written and not its fields. And a variable with the equality restriction, bound to a type
   that holds another variable, drops the restriction: with `fn eq(a, b) = a == b`,
   `fn g(x) = eq([x], [x])` carries none, and `g(fn(y : Int) = y)` compares two functions. The
   fix: the check (`has_fn_or_address`) reads a declared type's fields with its arguments in
   place, and binding a restricted variable to a type (`ern_types:bind_var`) checks that type
   and restricts the variables in it, each with a regression test.

---

## MVP 2.99 (running as a service, and the first release), about four days

A program on one node run for days under a service manager, and then the first release. It
follows MVP 2.98.

1. **Running as a service**, moved from MVP 2.7 on 2026-09-27 (the log's *Running as a
   Service*) and from MVP 3.0 on 2026-09-28, since it needs no peer (the log's *MVP 3.0 Is
   Distributed Code and the Node Protocol*):
   - a systemd unit: start and stop, a stop asked for ending the program by its signal;
     `Restart=on-failure` after a program ends with `Os.exit(1)`; and the journal showing fault
     lines without a doubled time;
   - a launchd plist on macOS, with the same checks;
   - a soak of hours: `examples/webserver.ern` under steady requests, measured as
     [`memory.md`](memory.md) says;
   - standard error on a full or failing disk ending the run with status 141, as §8.2 says;
   - `Clock.alarmAt` when the host's wall clock jumps: deadlines use the monotonic clock and a
     time does not, and the report decides what an alarm at a time does when the clock moves
     (Appendix E.15);
   - a termination or hangup that comes while the host starts, which the host drops (*Standing
     gaps* below): whether a launcher passes a signal on to the host until the host has taken
     it, at the price of a second process between a service manager and the program.
   - the host's port helper, `erl_child_setup`, which once in some twenty runs of `make test`
     wrote `failed with error` as an interrupt ended the host, where §8.6 has the interrupt
     end the program printing nothing (`interrupt_test_`, found 2026-09-28, not yet
     diagnosed). Its shape: read the helper's source for what it reports, meet it under load,
     and end the host so that its helper is not caught mid-write.
2. **The first release**, placed here on 2026-09-28 (the log's *The First Release Follows MVP
   2.99*): Ernest for programs on one node, for other programmers to install and use, decided
   2026-09-27 (the log's *The First Release Is for Others*); peers are the next release's.
   [`review.md`](review.md) runs on the code as it is then; `VERSION` is set to the release's
   version before the tag; `ern(1)` is given the sections man-pages(7) names, SYNOPSIS,
   OPTIONS and EXIT STATUS among them, where it is §11 rendered as it stands (`findings.md`'s
   T31, 2026-09-29); and the release is tagged with its notes, the archive published beside it,
   where the README then says to download it.

## MVP 2.99b (one contract, several representations: an ordered set), about two days

Decided 2026-09-28 (the log's *§7.3 Written Around an Ordered Set*): the guide's §7.3 is
rewritten to test whether a record of functions does what an interface does in Java and a type
class in Haskell. Its first form, a value that carries its operations (`Shape`), goes. Its
second is rewritten around a contract `Set.Operations(s, a)` holding the operations of the built-in
`Set` (Appendix E), which `Set` fills in, and so does a module `OrderedSet`, a set kept in a
`compare`'s order that exports functions of its own beyond the contract, such as `min` and
`max`. It follows the first release, MVP 2.99: the contract's decision is taken here, and
not before the release (decided 2026-09-29, the log's *The Contract's Decision After the First
Release*).

1. **The contract's decision**, taken first, with the user (language feedback 64), over what
   [`contract.md`](contract.md) recommends and compares with full type classes:
   a contract is a record of functions that the caller passes; a named field may be
   polymorphic in a variable its type does not take, as `foldLeft`'s accumulator and `any`'s
   effect are, without which the contract cannot hold nine of `Set`'s twenty functions; and
   `<` on a type variable gives it an ordering restriction, as `==` gives equality, so that an
   ordered set holds only its elements. The section does not go around the decision. Taken,
   the recommendation makes the milestone about seven days (the note's *Cost*).
2. **What the section verifies**, each stated in it or in the log: code written once against
   the contract (a Java parameter of an interface type, a Haskell constraint); a
   representation's own functions beside the contract (a class's further methods); a contract
   that extends another, an ordered set's record holding a `Set.Operations` (`SortedSet extends Set`, a
   superclass); defaults built from a smaller record (a default method); the representation
   chosen at the call, never found by its type (instance resolution, which principle 3 leaves
   out); two ordered sets of different `compare`s meeting in `union` (Haskell's coherence;
   Java's `TreeSet`, which keeps its comparator); and values of different representations in
   one list, which the first form gave. What Ernest cannot express goes to
   [`language_feedback.md`](language_feedback.md) and is decided with the user before the
   section goes around it.
3. **The section's examples** compile and run under the guide's checks.
4. **When a type's operation is a member and when a module function** (`findings.md`'s U8,
   moved here 2026-09-29): §7.2 declares them `fn Stack.push` and §7.3 `toList` of a module,
   and the contract's decision settles how a type's operations are declared, so the guide
   states one rule with it.

---

## MVP 3.0 (peers: distributed code and the node protocol), about three weeks

Designed in [`node_protocol.md`](node_protocol.md), which owns the protocol. The note is
tentative, and was brought to the report on 2026-09-28, each change a line marked *Changed*;
what it still asks of the report, listed below, and its open questions are decided before any
of it is built.

Nodes that reach each other, a spawn on a peer that ships code (§8.7), and messages between
them that carry values (§3.11). Code is shipped only between nodes running the same build,
§8.7's easiest case, and a peer whose build differs is refused with an error naming 3.1. Split
from MVP 3.1 on 2026-09-20. It holds distributed code and the node protocol alone, decided
2026-09-28 (the log's *MVP 3.0 Is Distributed Code and the Node Protocol*).

- **The distribution notes' rewrite, read with the user before any of it is built.** Brought to
  the report on 2026-09-28, the two notes also gained design no one has weighed: a `spawned`
  and a `kill` frame, `demonitor` kept to the runtime, the spawn site in the spawn frame, the
  hash modules named `ern#<base32>`, and new open questions, the protocol note's 5 and 7 to
  12 and the distribution note's 8 to 10.
- `spawn(Peer(name), f)` over the peers in `ernest.conf`, authenticated with the configured
  keys: the connection is `ssl`, with the peer's public key from `ernest.conf` as the only
  trust, read with `public_key`, inside `ern`; a program never sees either module.
- Peer loss as §10 says: every process on the lost peer dead with `Fault("peer lost")`, its
  monitors delivered; a peer that reappears is a new instance.
- **Placement by load, in `Peer` and a library** (feedback items 14 and 25, decided in MVP
  2.66; the log's *No Remote Computation in the Language*). `Peer.nodes : () -> List(Where)
  with m` answers the nodes a program can place work on, `Local` first, then each peer of
  `ernest.conf` in its order. `Peer.runQueue : () -> Int with m` answers how many processes
  wait to run on the node that evaluates it. Both are shims by E.0 rule 1, stated in `Peer`'s
  section of Appendix E.
- **`libs/balancer`**, in Ernest over those two. `Balancer.pick(measure)` draws two nodes at
  random from `Peer.nodes()`, spawns on each a process that evaluates `measure()` there and
  sends the number back, and answers the node with the lower number, the first on a tie. A
  node lost before it answers is dropped and another drawn; `Local` always answers, and with
  one node `pick` answers `Local` without measuring. `measure : () -> Int with m`, so the
  common call is `Balancer.pick(Peer.runQueue)`. Its module page states the cost, two round
  trips per `pick`.
- **What the protocol note asks of the report**, each decided before it is built: whether
  `Down` gains `Unreachable` for a lost peer whose process may live on (the note's question 6,
  §9.3, §6.9), and whether §6.4 states that what arrives is an unbroken prefix of what was sent,
  a sender told nothing of a drop, as the note's section 8 promises.
- **Where a node's configuration is read**, decided before `ernest.conf` is: its default,
  `./.ernest`, is the directory a program starts in, whose `ernest.conf` would name the peers
  and keys the node trusts, as its `startup` ran inputs until MVP 2.95 (§11.2, §11.3; the log's
  *A Directory Runs Nothing of Its Own*). Recommended: the default goes, and a node reads a
  configuration directory only where `--config-dir` names it.
- **`Peer.find(name, fn() = M.service)`**: a peer's service is found by reading its binding on
  the peer, decided in MVP 2.65's step 5 (the log's *A Peer's Service Is Found Through Its
  Binding* and *`Peer.find` Stands*). Built here with §8.7's two sentences on a node's own
  initialization and on a definition that differs by hash. It answers a failure rather than
  faulting, `Peer.Failure = NoSuchPeer | Lost`, `Peer`'s own; `Peer` as a namespace beside the
  constructor `Peer` of `Where` is checked against §4.2.
- **When a module's top-level bindings run**, decided with §8.7's sentence on a node's own
  initialization: whether one rule serves both nodes, where the node a program starts on runs
  those of every module the entry point depends on, though their names may appear nowhere at a
  use (§8.5, principle 3), and a peer runs them lazily (a reader's finding, P4).
- **Code travels only with a spawn**, decided 2026-09-27 (§3.11, §6.5, §8.7; the log's *Code
  Travels Only With a Spawn*). A value that holds a function faults at the operation that
  would take it to another node, `function cannot cross nodes`, found by the walk that finds a
  foreign value; the function a spawn starts, with its captures, is shipped. An adapted address
  crosses as its target's address and its function's `{hash, env}`, and the node where it was
  made applies the function on delivery; one made around another node's process faults.
- **Shipped code and the host's lambda entries**, noted 2026-09-27 (the log's *The Shell's
  Code Memory*): OTP keeps an entry for each lambda of each version of a module it loads, up
  to 524,288, for as long as the node lives. A node that receives code loads one version per
  definition, by its hash, and `docs/memory.md` gains a load of peers spawning the same and
  new definitions.
- **A supervisor's children run on its node**, decided 2026-09-27 (Appendix E.22; the log's
  *The `Supervisor`'s Shape*): `Supervisor.child` asks the runtime, through a private shim,
  whether `sup` is on the child's node, and faults with `a child runs on its supervisor's
  node` before the child joins when it is not.

---

## MVP 3.1 (content addressing), about four weeks

Designed in [`code_distribution.md`](code_distribution.md), which owns it. The note is
tentative, and was brought to the report on 2026-09-28; its open questions are decided here,
report first. Its question 9 meets the code as it stands: whether a node running hash modules
keeps embedded mode, which loads nothing from the code path on demand, where §11.2 finds a
`foreign fn`'s Erlang module on the load path. The toolchain has no IR: `ern_emitter` goes from
the typed AST to Erlang's abstract format in one traversal, and whether an IR is introduced or
the typed AST canonicalized is part of the decision on the normalized definition below.

The milestone is §8.7's identity in full:

- **The normalized definition, decided first**: the typed tree or the untyped one, whether
  local names are erased, and what becomes of the effect variables, which are inferred and
  never written. Whether `ern_iface:hash/1`, which hashes a canonical interface, grows into
  the definition hash or a second scheme stands beside it is part of that decision; the first
  is the cheaper.
- Every definition gets a hash of its typed AST; modules are named by hash, with a registry
  per node `{Hash -> Module}`. A function spawned on a peer carries its hash, and a node that
  lacks it fetches the code from the sender. Erlang's module distribution is not used.
- Hash modules never change, and versions coexist on a node for as long as a process runs one
  ([`code_distribution.md`](code_distribution.md) section 8). The shell's reload then ends
  nothing: §7.3's unloading cause, §7.4's `Fault("its code was unloaded")` and §11.2's
  second-reload rule go, with the test that pins them.
- **A node whose atoms near the host's limit**, decided with the hash modules: the note's
  section 10.2 drains and restarts it, which CLAUDE.md's rule that memory no collection
  reclaims is fixed at its cause, never by a cap, questions (a reader's finding).
- Two nodes with different versions of one type never meet in a message, decided 2026-09-27
  (§8.7, *Identity*): an address carries its mailbox type's hash and is obtained only through
  typed operations. A frame that breaks it comes from a faulty peer and tears the connection
  down (node protocol, section 4.2).
- The library fetcher, decided 2026-09-19: `ern fetch name url` fetches a library's source
  tree from a git URL into a directory on the load path, compiles it, and records the hashes of
  its definitions. No resolver, no semver, no lockfile beyond those hashes, and no registry;
  discovery by name is a tooling question for later.

---

## MVP 3.2 (the libraries, as they are wanted)

A library not yet written waits, and is written when our work needs it, MVP 3.0 and 3.1 among
that work, when someone asks for it, or when we want it, decided 2026-09-25 (the log's
*Libraries As They Are Wanted*). Each is an Ernest source root under `libs/<name>/` that a
program adds with `--load-path`, with `stdlib/`'s test discipline, documented in one pass to
[`module_doc_template.md`](module_doc_template.md) with its executed examples as its first
user, and a section in the appendix of libraries. Own repositories come later, when there is a
package story. Written: `libs/ets` and `libs/markdown` (Appendix G; `libs/markdown` under
"Done"). Named so far:

- **`libs/json`**, pure Ernest: a `Json` type, a parser over `String` returning `Either`, a
  printer.
- **`libs/base64`**, a shim over `base64`.
- **`libs/tls`**, a shim over `ssl` and `public_key`: `listen`, `accept`, `connect`. Whether
  it answers `Tcp`'s `Address(SockMsg)`, its foreign process then speaking an encoding private
  to `Tcp` (E.18), or a socket type of its own with its own `read`, `write` and `close`, is
  decided when it is written. Certificate verification is the caller's to ask for.
- **`libs/http`**, Ernest over `Tcp` and `Tls`: request and response types, their parsing and
  rendering in both directions, and a client. No server loop; that is the webserver example's,
  whose hand-written parser and renderer the library replaces (feedback item 55; the log's *The
  Web Server Waits for Its Library*). With it, `examples/fetch.ern`, a command-line tool that
  fetches JSON over HTTPS and prints a report, and `Time` in Appendix E over the clock's
  milliseconds.
- **`libs/regex`**, a shim over `re`, a library and never syntax: `Regex.compile : (String) ->
  Either(RegexError, Regex)`, `Regex` a foreign type.
- **`libs/crypto`**, a shim over `crypto` for hashes, HMAC and random bytes; **`libs/uri`**,
  pure Ernest or a shim over `uri_string`; **`libs/zlib`**, a shim over `zlib`.

---

## MVP 3.9 (the review before 1.0)

What a first release could leave out and a promise of stability cannot (the log's *The First
Release Is for Others*):

- **The type system argued.** A written argument that a well-typed program does not go wrong:
  the core calculus, then effects and mailbox types, the reply discipline's linearity, and
  where rules meet, generalization against effects, a pure function standing for one with a
  mailbox, a reply captured by a lambda. Where it cannot be made, that is a finding; a model a
  machine checks follows only if the argument meets a rule it cannot settle.
- **Well-typed programs generated.** Programs generated to type-check run under the runtime and
  end by returning, by a cause of §7.4, or by a deadlock; a host error that is none of those is
  a finding in the checker or the runtime.
- **The grammar generated against.** A thousand programs generated from Appendix A, reaching
  every alternative, parsed, and each near miss refused with a diagnostic (the log's *Enough
  Coherence*).
- **The standard library's laws as properties**, generated against each module's contract:
  `String.split` then `String.join` gives the string back, `List.sort` is stable, a search
  matches whole graphemes, and the rest its sections and doc blocks state.

---

## Not in any MVP

`Slot(a)`, a one-shot credit parallel to `Reply(a)`, is out on principles 2 and 5; the log
holds its shape if the verdict is revisited. String interpolation is declined for now on
principles 2, 3 and 4. Erlang scheduling hints wait for a program that needs them.
`Clock.monotonic`, and `Udp` as a module of its own, wait for a later MVP (2026-09-18). No HTTP
server, ever, and no database connectors: those are libraries for others to write on Appendix
D's pattern.

The shell's later work waits for a milestone that takes it, each part weighed on its own
merits: the grey suggestion; the kill ring with `M-y`, and `C-t`, `M-t`, `M-u`, `M-l` and
`M-c`; completion by type once the checker checks an unfinished input, a `match`'s clauses,
a mailbox's constructors, the functions after `|>` and an argument's bindings; re-running an
input by number; `:trace f`; a report of a program's quiescence; and, with MVP 3.0's peers,
a shell attached to a running node (moved from `shell_design.md`, 2026-09-28).

---

## Standing gaps

- **§3.11, §8.3 and §8.7 have no citing test**, which `make sections` lists. All three are MVP
  3.0 and 3.1 material and unbuilt; anything else it lists is a gap.
- **A label at the first use of the variable whose type a mismatch names** was planned for
  §3.4's placement work and not built (2026-09-18).
- **A termination or hangup that comes while the host starts**, before any of `ern` runs, is
  dropped by the host, on this machine in the first 0.2 seconds (report §11). A launcher that
  passes a signal on to the host until the host has taken it would close it, and is decided in
  MVP 2.99 (2026-09-28).

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
[`emacs_mode.md`](emacs_mode.md) owns the mode. It gave the style guide six indentation rules,
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

The shell, an Ernest program under `shell/`, designed in [`shell_design.md`](shell_design.md)
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

### `libs/markdown` — a CommonMark renderer (done 2026-09-25, now under MVP 3.2)

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
placement by load going to MVP 3.0's `Peer.nodes`, `Peer.runQueue` and `libs/balancer` (items
14 and 25; §6.7; the log's *No Remote Computation in the Language*). The command line is
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
([`emacs_mode.md`](emacs_mode.md); the log's *Format on Save*). Built ahead of MVP 2.7's last
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
where standard error is a file, and a stop ends it by its signal (guide §9.5; the log's
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
installed ([`install.md`](install.md); the log's *`bin/ern` Is a Launcher*, *The Layout Under
the Prefix* and *One Archive, Compiled Where It Is Installed*). The review ran a machine for
every check and twelve readers, and is now [`review.md`](review.md)'s one page (the log's *A
Lean Review*); `make test` went from 280 seconds to under a minute (the log's *The Time of
`make test`*). The readers' findings that lose data, expose a user or break a program were
fixed, each with a regression test, and the rest are MVP 2.98's ([`findings.md`](findings.md);
the log's entries from *The Sweep Removes What a Build Wrote* to *An Unfinished Line Leaves
the Region a Row at a Time*). Three entries of the language feedback were decided: names stay
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
