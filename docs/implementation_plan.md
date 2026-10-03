# Ernest Implementation Plan

The roadmap: what will be built, in what order, and what is built already. Why anything is the
way it is belongs to [`decisions.md`](decisions.md), what the language is to
the report in [`report/`](../report/), how the code is arranged to
[`architecture.md`](architecture.md), and the commands and what the toolchain does not do yet
to [`development.md`](development.md).

Read "Where we are" first. The milestones to come follow in order, then what is in no
milestone, the standing gaps, and what is done.

---

## Where we are

**MVP 2.99c is next**: the core language argued sound and generated against, the grammar,
well-typed programs and the standard library's laws as machines and the type system as a
written argument, then what Erlang holds that Ernest can, and last the next release, Ernest
0.3.0. MVP 2.99b, what the release review left, the code's names read and made to read,
operations records, and running as a service, was done on 2026-10-03, and `findings.md` went
with it; the principles review, a milestone of its own between its items 3 and 4, closed on
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
| The principles review | the report and the guide against §0, and §0 against what it decided | done 2026-10-01 |
| Ernest 0.2.0 | the review's rules shipped as one, after the release review | done 2026-10-01, tag `v0.2.0` |
| MVP 2.99c | the language argued: the type system's argument, generated programs, the grammar and the library's laws as machines; then a release, Ernest 0.3.0 | moved from MVP 3.9 on 2026-10-01 |
| MVP 3.0 | peers: distributed code and the node protocol | |
| MVP 3.1 | content addressing | |
| MVP 3.2 | the libraries, as they are wanted | `libs/markdown` done 2026-09-25 |
| MVP 3.3 | the shell's second round | |
| MVP 3.9 | the review before 1.0: the full review, the numbering decided once, the promise | |

---

## MVP 2.99c (the language argued, and a release), about a week

The core language argued sound and generated against, before peers build on it, moved here
from MVP 3.9 on 2026-10-01 (the log's *The Language Argued Before Peers*). After MVP 2.99b,
since the review's phase 5 and the operations records are the last changes to the type system
on one node, and before MVP 3.0, whose code shipping and type identity extend the argument
rather than begin it. The machines first, cheapest first, since each finds concrete defects
in a day or two, and the argument last, written over a parser and a checker the machines have
shaken (reordered 2026-10-01). Weighed again on 2026-10-03 before it starts (the log's *MVP
2.99c Weighed Before It Starts*): about a week at the pace MVP 2.99b set; item 3 before item 2
as the cheaper; item 2 given its rounds and its oracles, item 4 its bound and its owner; and
[`release_review.md`](release_review.md) a sixth machine, the bench, and a reader of the guide.

1. **The grammar generated against**, done 2026-10-03 (the log's *The Grammar Generated
   Against*): `make test-grammar`, a part of `make test`, derives a thousand programs from
   Appendix A as data and one more for each choice they leave untaken, so that every one of
   the grammar's choices is taken in every run; each is parsed, laid out and parsed again to
   the same tree, and given with one token changed as a near miss, which a recognizer built
   from the same grammar judges. It found seven places where the parser, the checker or the
   formatter left the grammar: Appendix A now says that a block ends with an expression;
   `Foo()` and `Foo(a, b)` are calls of the constructor's value, which the checker refuses;
   the binding rule of §3.5 and the message for a function in two clauses are the checker's;
   a type's parameters are distinct (§4.3, §4.7); and the formatter keeps two tokens that
   would read as others apart and a pipe's stage in its parentheses, which change nothing
   (§5.7, §11.6).
3. **The standard library's laws as properties**, done 2026-10-03 (the log's *The Library's
   Laws Held*): `ern_laws_tests`, a part of the runtime's tests in `make test`, checks 101
   laws drawn from Appendix E's sections of `List`, `String`, `Map`, `Set`, `OrderedSet`,
   `OrderedMap`, `Bytes`, `Int`, `Float`, `Char`, `Optional`, `Either` and `Path`, each on 200
   cases drawn afresh each run, the text among them hard at the graphemes. Every search of
   `String` matches whole graphemes of the string searched, `split` then `join` gives the
   string back, `sort` is stable, and the rest hold; none was broken.
2. **Well-typed programs generated**, done 2026-10-03 (the log's *The Typed Programs
   Generated*): `make test-typed`, a part of `make test` in about eighteen seconds, builds
   four hundred pure programs by type and sixty of four process shapes, checks, compiles,
   loads and runs each in one host through the runtime's entry, and holds what each prints
   to what an interpreter of the same program, written in the test from the report's rules,
   computes. The pure programs cover `let`, `if`, `match` over every pattern form with
   guards, constructors positional and named, records with selection and update, tuples,
   lists, lambdas, helper and local functions, structural recursion, and the operations of
   `Int` and `String` with a few of `List` and `Optional`; the shapes are a worker that
   sends its value back, a server that answers a call, a receive that times out, and a
   deadlock. No program was refused, miscompiled or ended otherwise than predicted.
4. **The type system argued.** A written argument that a well-typed program does not go wrong:
   the core calculus, then effects and mailbox types, the reply discipline's linearity as §6.6
   now states it, naming no type and a list element among the places a reply stands, and where
   rules meet, generalization against effects, a pure function standing for one with a mailbox,
   a reply captured by a lambda, an operator resolved where its operand's type is known and
   carrying nothing hidden, and what MVP 2.99b added: a requirement and what supplies it
   (§4.9), a derived `compare`, and the rule for a recursive group's types (§3.9). Bounded on
   2026-10-03: a calculus stated in two pages, its invariants, then a paragraph for each
   reduction rule and one for each place above where rules meet; no mechanization. Where it
   cannot be made, that is a finding and a plan item, and the argument stops there; a model a
   machine checks follows only if the argument meets a rule it cannot settle. Its owner is
   `docs/soundness.md`, the argument that a well-typed program does not go wrong, which this
   item writes and names in CLAUDE.md's owners in the same commit; the report keeps the rules
   and the log the rationale by entry. Its first line names the three tests of items 1 to 3,
   which check what it argues; the tests own the machines, as every test does, and no review
   document holds the milestone's items (decided 2026-10-03). The argument is kept, not run:
   in the same commit CLAUDE.md gains the rule that a change to a rule it covers rewrites its
   paragraph for that rule, so it cannot go stale between full reviews; MVP 3.0 extends it.
   The same commit gives [`release_review.md`](release_review.md) a row: when a rule the
   argument covers changed since the last release, the report's reader reads the argument's
   paragraphs for those rules beside the report's sections (decided 2026-10-03).
5. **The report in three files**: moved to MVP 2.99b, its item 24, on 2026-10-03.
7. **What Erlang holds that Ernest can**, decided with the user 2026-10-03, after CLAUDE.md
   gained the rule that as much as can be is written in Ernest; before item 6, the
   release. Moved: `String.trimStart` and `String.trimEnd`, exported shims though trimming
   is Ernest's, written over the module's `slice`, `drop` and `Char.isSpace`, `trimEnd`
   without a walk from the start for each grapheme it drops, since `slice` by index walks;
   and `String.toIntBase`'s reading of digits, a shim where `String.toInt` reads in Ernest,
   written as `toInt` is. E.5's list of primitives loses the three, and the log's entry
   that called finding and trimming the host's is corrected. Two named decisions, taken
   with the user before the item is built: **`:output` in Ernest**, the shell's redirection
   of a program's output, which the front end opens in Erlang since `Fs` writes regular
   files only; recommended: `Fs.append` writes a device as well, a terminal or a pipe,
   E.17 saying so, and the screen appends there, the cost of an open per write weighed
   when it is built. And **the terminal's key decoding**, ECMA-48 read in `ern_tty`, the
   runtime's by E.16 and §8.2's system process; recommended: kept, since a system process
   is the runtime's own, and stated so in the log.
8. **The full review**, decided with the user 2026-10-03: after item 7 and before item 6,
   in place of the release review's readers for 0.3.0. [`full_review.md`](full_review.md)
   is run whole: each of its nineteen readers and parts is a fresh agent of one workflow,
   never a fork, given only its brief and its files, as its *How it runs* says. P and K run
   on Fable 5.1, every other reader and part on Opus 5.5. The lists are collected into
   `findings.md` as its *The findings* says, and the work stops there for the user to read
   them before any finding is worked.
6. **A release, Ernest 0.3.0**, the milestone's last item, decided with the user
   2026-10-03, with no hurry: after the machines have run and the argument is written, so
   that what is released has been generated against. The review and the release run as
   [`release_review.md`](release_review.md) says, its readers being item 8's. Item 10's
   launchd checks of MVP 2.99b have run on a Mac by then, or the notes say that the agent has
   not been checked.

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

A full review ([`full_review.md`](full_review.md)) runs before it, since others build on
it, and what the review finds is worked through before its work begins (2026-09-29, the
log's *A Full Review Now and Then*).

- **The distribution notes' rewrite, read with the user before any of it is built.** Brought to
  the report on 2026-09-28, the two notes also gained design no one has weighed: a `spawned`
  and a `kill` frame, `demonitor` kept to the runtime, the spawn site in the spawn frame, the
  hash modules named `ern#<base32>`, and new open questions, the protocol note's 5, 7 to 12
  and 15 to 21, and the distribution note's 8 to 17 (the second read-back, 2026-09-30, placed
  here with the user the same day).
- The module `Peer`, with `Peer.spawn(name, f)` and `Peer.spawnMonitored(name, f, wrap)` (§8.3),
  in a section added at the end of Appendix E; the checker's refusal of a name of `Peer` goes,
  and the guide's examples in §8.1 and §8.4 are compiled again (2026-10-01, the log's *The Rules
  That Exist for Another*). It spawns over the peers in `ernest.conf`, authenticated with the
  configured keys: the connection is `ssl`, with the peer's public key from `ernest.conf` as the only
  trust, read with `public_key`, inside `ern`; a program never sees either module.
- Peer loss as §10 says: every process on the lost peer dead with `Fault("peer lost")`, its
  monitors delivered; a peer that reappears is a new instance.
- `Supervisor.child` refusing a supervisor on another node, `Fault("a child runs on its
  supervisor's node")`, which Appendix E.22 states and no code can reach before peers exist
  (the release review's C1-35, 2026-09-30).
- **Placement by load, in `Peer` and a library** (feedback items 14 and 25, decided in MVP
  2.66; the log's *No Remote Computation in the Language*). `Peer.nodes` answers the nodes
  a program can place work on, the running node first, then each peer of `ernest.conf` in its
  order. How a program places work on the node chosen, since `Where` left the prelude on
  2026-10-01, is this item's decision, made with the user when it is built; the recommendation
  is that the library spawn on the node it chooses, `Balancer.spawn(measure, f)`, so that no
  node type exists (the log's *Placing Work Without `Where`*). `Peer.runQueue : () -> Int with m` answers how many processes
  wait to run on the node that evaluates it. Both are shims by E.0 rule 1, stated in `Peer`'s
  section of Appendix E.
- **`libs/balancer`**, in Ernest over those two. `Balancer.pick(measure)` draws two nodes at
  random from `Peer.nodes()`, spawns on each a process that evaluates `measure()` there and
  sends the number back, and answers the node with the lower number, the first on a tie. A
  node lost before it answers is dropped and another drawn; the running node always answers,
  and with one node `pick` answers it without measuring. `measure : () -> Int with m`, so the
  common call is `Balancer.pick(Peer.runQueue)`. Its module page states the cost, two round
  trips per `pick`.
- **What the protocol note asks of the report**, each decided before it is built: whether
  `Reason` gains `Unreachable` for a lost peer whose process may live on (the note's question 6,
  §9.3, §6.9), and whether §6.4 states that what arrives is an unbroken prefix of what was sent,
  a sender told nothing of a drop, as the note's section 8 promises.
- **Where a node's configuration is read**, decided before `ernest.conf` is: its default,
  `./.ernest`, is the directory a program starts in, whose `ernest.conf` would name the peers
  and keys the node trusts, as its `startup` ran inputs until MVP 2.95 (§11.2, §11.3; the log's
  *A Directory Runs Nothing of Its Own*). Recommended: the default goes, and a node reads a
  configuration directory only where `--config-dir` names it. With it goes where the node's
  private key lives, which `ern config` writes there by default, into the working tree, where
  a commit can take it (the security reader's S-H, 2026-09-29); nothing reads the key before
  this milestone.
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

- **The normalized definition, decided first**: the typed tree or the untyped one, and what
  becomes of the effect variables, which are inferred and
  never written. With it, whether a type's identity holds the hash of its `compare`, so that
  a value ordered under one order is not read under another where versions meet (on one
  node MVP 2.99b's item 5 made it the type's `compare`, supplied by the compiler, so that a
  set built before an `Upgrade` of its `compare` is misordered after it, `operations.md`'s
  *Typing*). Whether `ern_interface:hash/1`, which hashes a canonical interface, grows into
  the definition hash or a second scheme stands beside it is part of that decision.
- Every definition gets a hash of its typed AST; modules are named by hash, with a registry
  per node `{Hash -> Module}`. A function spawned on a peer carries its hash, and a node that
  lacks it fetches the code from the sender. Erlang's module distribution is not used.
- Hash modules never change, and versions coexist on a node for as long as a process runs one
  ([`code_distribution.md`](code_distribution.md) section 8). The shell's reload then ends
  nothing: §7.3's unloading cause, §7.4's `Fault("its code was unloaded")` and §11.2's
  second-reload rule go, with the test that pins them.
- **The loader's one `code_server`**, measured under the loader's batches before it is relied
  on, and **normalization**, given a test suite of its own (the note's section 6 and risk 1).
- **A node whose atoms near the host's limit**, decided with the hash modules: the note's
  section 10.2 drains and restarts it, which CLAUDE.md's rule that memory no collection
  reclaims is fixed at its cause, never by a cap, questions (a reader's finding).
- Two nodes with different versions of one type never meet in a message, decided 2026-09-27
  (§8.7, *Identity*): an address carries its mailbox type's hash and is obtained only through
  typed operations. A frame that breaks it comes from a faulty peer and tears the connection
  down (node protocol, section 4.2).
- The library fetcher, decided 2026-09-19: `ern fetch name url` fetches a library's source
  tree from a git URL into a directory on the load path, compiles it, and records the hashes of
  its definitions. No resolver, no semver, no lockfile beyond those hashes, and no registry.

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
- **`Udp`**, a system module of Appendix E beside `Tcp` and not a library, admitted by E.0
  rule 1 and written as wanted too, with `Tcp`'s shapes: a socket an address, a read pulled
  with a time, a datagram `Bytes` (the log's *`Clock.monotonic` Is In, and `Udp` Is
  Placed*).

---

## MVP 3.3 (the shell's second round), about three weeks

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
   names an owner for its inputs (`findings.md`'s C1-2, placed here 2026-09-30).

---

## MVP 3.9 (the review before 1.0)

What a promise of stability needs and a first release could leave out (the log's *The First
Release Is for Others*), after the language was argued in MVP 2.99c:

- **The full review**, every reader over the whole of its area ([`full_review.md`](full_review.md)),
  and its findings worked.
- **The numbering decided once.** Whether the report's section numbers have drifted enough since
  0.1.0 to renumber, with the mapping table written first and one commit that rewrites every
  citation, in the report, the guide, the log, the code, the tests and the diagnostics; or the
  numbers kept for good (the log's *The Language Argued Before Peers*).
- **The promise**: what 1.0 holds stable, stated in the report's §0 and the release's notes.

---

## Not in any MVP

`Slot(a)`, a one-shot credit parallel to `Reply(a)`, is out on principles 2 and 5; the log
holds its shape if the verdict is revisited. String interpolation is declined for now on
principles 2, 3 and 4. Erlang scheduling hints are out: a priority breaks §10's rule that a
process cannot prevent others from running, and the memory options of a spawn change no
meaning; a program reaches either through `foreign fn` (the log's *Scheduling Hints Are the
Host's*). A library is not found by its name: its URL is the one way to say where it comes
from, and an index of libraries is others' to publish (the log's *A Library Is Fetched by Its
URL*). No HTTP
server, ever, and no database connectors: those are libraries for others to write on Appendix
D's pattern.

Three parts of the shell's later work are out (the log's *The Shell's Second Round*): the
grey suggestion, a third way into the history beside `Up` and `C-r` (principle 2), told from
what was typed by colour alone, which the plain mode lacks; re-running an input by number, a
second way to name an input, which `Up` or `C-r` and `Enter` already re-run (principle 2);
and a report of a program's quiescence at the prompt, since a later input may send to any
waiting process, so the report would be a guess (§11.2 detects no deadlock while a shell holds
the terminal). The rest is MVP 3.3's.

---

## Standing gaps

- **§3.11, §6.7 and §8.7 have no citing test**, which `make sections` lists. All three are MVP
  3.0 and 3.1 material and unbuilt, since 2026-10-01 a spawn on a peer being `Peer.spawn`'s,
  which §8.3 introduces and a test of its refusal cites; anything else it lists is a gap.
- **A termination or hangup that comes while the host starts**, before the runtime can take
  signals, is lost, or ends the program with status 0 and a line of OTP's own, `SIGTERM
  received - shutting down`; on this machine on 2026-10-02 the window was about a quarter of a
  second. §8.6 and §11.8 state it as the host's limit since 2026-10-02 (MVP 2.99b's item 6,
  the log's *MVP 2.99b's Questions, One by One*). Its fix is OTP's, a signal held until the
  host's signal server runs, which the user takes to OTP's maintainers; since 2026-10-03
  (item 9) the host installs Ernest's handler as the first thing it runs, and the second
  outcome's window measured about 5 milliseconds where it had been about 12.
- **A signal that ends the host while it starts a port**, for a host program, for `ern_exec`,
  or for OTP's lookup of the host's name, leaves a line of OTP's helper on standard error,
  `erl_child_setup: failed with error 32 on line 284`, where §8.6 has the runtime print
  nothing (found 2026-10-01). Every run starts two such ports before `main`, and a program
  that starts host programs meets it while it runs. A port closed while it starts would
  leave the same line by OTP's source, and was not met in thirty tries. Its fix is OTP's: the
  child exits silently when the host is gone, as the helper does, which the user takes to
  OTP's maintainers (decided 2026-10-01, the log's *A Port Lost While It Starts*). Ernest adds
  nothing around it, and the gap stands until a release of OTP that Ernest requires has it.

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
libraries are out, and the shell's later work is MVP 3.3's. A load samples a node at rest,
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
`VERSION` at the release (the release review's step 5); `Udp` to MVP 3.2 (the log's
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
and the Erlang that Ernest can hold, MVP 2.99c's item 7. `language_feedback.md` holds no
entry, and stays as the place new feedback is written.
