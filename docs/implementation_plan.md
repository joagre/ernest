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

**MVP 2.95, the first release, is under way.** The manual pages, the installation, the release
archive, the review and the time of `make test` are done (2026-09-28); the next are the
readers' fixes before the tag, item 4's step 2, two of which are done, then the tag. Every
earlier milestone is done, the last MVP 2.7 on 2026-09-28; MVP 2.9, MVP 2.61, `libs/markdown`
and MVP 2.8 were taken out of order. Each has its paragraph under "Done".

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
| **MVP 2.95** | **the first release: manual pages, an installation, the review** | **under way: manual pages, installation, archive, review and the time of `make test` done 2026-09-28; the readers' fixes next** |
| MVP 2.96 | a result annotation written with `:` | |
| MVP 2.97 | one contract, several representations: an ordered set | waits on language feedback 64 |
| MVP 3.0 | peers | |
| MVP 3.1 | content addressing | |
| MVP 3.2 | the libraries, as they are wanted | `libs/markdown` done 2026-09-25 |
| MVP 3.9 | the review before 1.0: soundness argued and generated against | |

---

## MVP 2.95 (the first release: manual pages, an installation, and the review)

The first release is Ernest for programs on one node, for other programmers to install and use,
decided 2026-09-27 (the log's *The First Release Is for Others*); peers are the next release's.
It follows MVP 2.7 and comes before MVP 3.0.

1. **Manual pages, done 2026-09-28.** `ern doc --man` writes a module's page as a manual page
   in roff, `Ernest.List(3ern)`, `Ernest.Prelude(3ern)` for the prelude and
   `Ernest.Net.Http(3ern)` for a user's module, rendered by `libs/markdown`'s `roff`. `ern(1)`
   is §11 of the report, rendered by `tools/manual.ern`, its SEE ALSO naming the standard
   library's pages. `make man` writes them all (report §11, §11.4, Appendix G.2; the log's
   *Manual Pages Named `Ernest.List`*, *`ern(1)` Is §11* and *What Building the Manual Pages
   Found*).
2. **An installation, done 2026-09-28.** `make install` installs Ernest under `PREFIX`,
   `/usr/local` by default, each path after `DESTDIR`, and `make uninstall` removes exactly
   what it installed; neither changes anything where it cannot write. `bin/ern` is a POSIX sh
   launcher, in the repository and the installation alike: it follows its links to its tree,
   refuses a working directory whose name is not UTF-8 before the host starts, and starts the
   host. The tree is the repository's layout under `lib/ernest`. The design note is
   [`install.md`](install.md); the log's *`bin/ern` Is a Launcher*, *The Layout Under the
   Prefix* and *What Building the Installation Found* argue it.
3. **A release archive, done 2026-09-28.** `make release` writes
   `build/release/ern-0.1.0.tar.gz`: the tree `make install` stages, with the helper as its C
   source, `install.sh`, and a `Makefile` and a `README.md` of its own, from which a user
   installs Ernest without building it. Decided 2026-09-28: one archive for every system, whose
   `make` compiles the helper where it is installed; and the installed tree, from the checkout
   and the archive alike, carries no host debug information, stripped keeping `ErnI` and
   `Docs` (the log's *One Archive, Compiled Where It Is Installed*).
4. **The review, done 2026-09-28**, heavier than a first release needs: a machine for every
   check, built in eleven steps, and twelve readers. What they found that was real is fixed or
   planned below (the log's entries from *What Dialyzer Found* to *A Signal Ends a Job*). The
   machines that found little are gone, and the review is [`review.md`](review.md)'s one page
   (the log's *A Lean Review*). No Mac verification for the first release: the README and the
   archive's README say Linux, with macOS expected to work and not yet verified (the log's *No
   Mac for the First Release*). What a first release leaves out is MVP 3.9's.
   1. **The lean-down, done 2026-09-28.** `make calls`, `make untested`, `make unused`,
      `make garbled`, `make stress` and `make fresh` are gone with their tools, and so are the
      catalogue's completeness scanner, the Makefiles' coverage plumbing and the coherence
      note. CLAUDE.md asks for `make test` before a commit and for readers at a release.
      `make dialyzer`, `make sanitize`, `make load`, the report's checked examples, the
      grammar's FIRST sets, the licences test and the catalogue of diagnostics stay.
   2. **The readers' fixes before the tag**, decided 2026-09-28: the defects that lose data,
      expose a user, or break a program, each with a regression test. They are the `tag` lines
      of [`findings.md`](findings.md), which holds every finding of the review with its
      decision:
      - the directory build's sweep, which deleted what no build of its own wrote (§11.1),
        done 2026-09-28 (the log's *The Sweep Removes What a Build Wrote*);
      - `ern shell` running `./.ernest/startup` from the working directory, done 2026-09-28
        (the log's *A Directory Runs Nothing of Its Own*), and the working directory on the
        host's code path ahead of the load path (§11.2), done 2026-09-28;
      - `Fs` over a FIFO blocking every file operation of the node, done 2026-09-28 (the
        log's *`Fs` Reads Regular Files*), and `Fs.list` failing for a whole directory over
        one dangling link (E.17), done 2026-09-28;
      - `Tcp.listen` and `Tcp.connect` hanging on a bad port or host, `Tcp.listen` binding
        every interface, and a socket's write holding up its reads (E.18), done 2026-09-28:
        `Tcp.listen` takes the host as `Tcp.connect` does (the log's *`Tcp.listen` Names Its
        Interface*);
      - the shell's history readable by others, which waits on a decision, how `Fs` makes a
        file its owner's alone (language feedback 66, discussed with the user); `ern config`'s
        race on the key, done 2026-09-28; and control characters of a fault or a doc block
        reaching the terminal (§11.2, §11.3), done 2026-09-28;
      - a program's end leaving processes a late spawn made (§8.6), done 2026-09-28;
        `:reload` initializing in the wrong order, and a failed `:load` leaving its processes
        (§11.2), done 2026-09-28; a foreign function value inside a recursive type (§8.4),
        done 2026-09-28;
      - a closed pipe crashing every job but `ern run`, done 2026-09-28; the internal errors
        on an empty directory, a name that is not UTF-8 and a corrupt `.erc`, and `ern format`
        of a file that cannot be written (§11);
      - `Supervisor`'s restart limit, which a child passes before the supervisor counts it
        (E.22), and `String`'s searches, which match inside a grapheme (E.5);
      - `emacs_mode.md`'s Emacs 29 or later, where only Emacs 31.1 runs the mode's tests
        here.
   3. **The time of `make test`, done 2026-09-28**, taken before step 2's other fixes: 280
      seconds to 112, the suite in two phases of jobs side by side, as many at once as the
      host has cores, and bound by its CPU. The compiler's hash now covers the six modules
      that shape a `.erc` it had left out (§11.1), two jobs writing one file each write it
      whole (§11), and a test that slept where the runtime could not see it naps. The
      measurement and the arguments are the log's *The Time of `make test`*.
   4. **Planned after the release**, in MVP 3.0's first step, decided 2026-09-28: the rest of what
      the readers found, `findings.md`'s `cheap` lines, a batch a document, and its `3.0` lines, the
      report's contradictions and silent cases, the diagnostics' positions and labels (§11.5),
      `Io.show`'s dependence on the type at the call and where `via`'s function runs, whether
      `Fs` sees a symbolic link (language feedback 65, decided with the user), the guide's
      gaps (`Tcp` untaught), the documents the code has left behind, and three changes that
      take work from `make test`: the shell's tests waiting for the prompt or a program's
      output, not a fixed time; `ern_cli`'s build in a module of its own, so that the
      compiler's hash leaves out its other jobs and a change to them recompiles nothing; and
      the programs area's builds in the test's node, where a launch of `ern` costs 0.6 seconds
      a build and the node 0.08.
5. **The release**, tagged once the review is done, with its notes (`review.md`, *Done*), and
   the archive published beside it, where the README then says to download it.

---

## MVP 2.96 (a result annotation is written with `:`), about two days

Decided 2026-09-28 (the log's *A Result Is Annotated With `:`*): a function's result annotation
is written `: T`, as a parameter's is, in every function head, `fn`, `foreign fn`, a lambda and
a type member: `fn show(x : Optional(Int)) : String = …`. A function type keeps its arrow,
`(A) -> B with e`, and so do the clauses of `match` and `receive` and `after`. It follows MVP
2.95, the first release, and comes before MVP 3.0.

1. **The report.** Appendix A's `Return` becomes `":" Type [ "with" Type ]`; §3.4's `with` in a
   result annotation, §4.5's `-> T` and `-> T with M`, and §8.1's entry point are restated.
2. **The parser and the formatter.** The parser reads both spellings while the sources change,
   and the formatter writes `:`. `make format` then rewrites every Ernest source and every
   Ernest block of the report and the guide (`style.md`).
3. **What the formatter does not reach**: the Ernest held in Erlang tests, `style.md`'s
   example, the README's, the guide's prose on `:` and `=`, `ern doc`'s signatures and
   `module_doc_template.md`, the diagnostics that quote a head (`` `-> Unit` with no `with`
   declares main pure ``), and the Emacs mode.
4. **One spelling.** `->` after a head's `)` is a parse error whose help names `:`, as §11
   refuses a job spelled as an earlier version spelled it.

---

## MVP 2.97 (one contract, several representations: an ordered set), about two days

Decided 2026-09-28 (the log's *§7.3 Written Around an Ordered Set*): the guide's §7.3 is
rewritten to test whether a record of functions does what an interface does in Java and a type
class in Haskell. Its first form, a value that carries its operations (`Shape`), goes. Its
second is rewritten around a contract `SetOps(s, a)` holding the operations of the built-in
`Set` (Appendix E), which `Set` fills in, and so does a module `OrderedSet`, a set kept in a
`compare`'s order that exports functions of its own beyond the contract, such as `min` and
`max`. It follows MVP 2.96.

1. **The contract waits on a decision**, discussed with the user first (language feedback
   64): whether a field may be polymorphic in a variable its type does not take, as
   `foldLeft`'s accumulator and `any`'s effect are. Without it the contract cannot hold nine
   of `Set`'s twenty functions, and the section does not go around that. The suggestion,
   against type classes: polymorphic record fields, as OCaml has them. A field quantifies the
   variables its type does not take, so `foldLeft` sits in the record; there is no instance
   resolution, no constraint in an inferred type and no hidden argument. Its cost is a type
   scheme inside a type declaration, a rank-2 type confined to declared fields, where the
   log's *Dropped from Unison* drops rank-n types.
2. **What the section verifies**, each stated in it or in the log: code written once against
   the contract (a Java parameter of an interface type, a Haskell constraint); a
   representation's own functions beside the contract (a class's further methods); a contract
   that extends another, an `OrderedSetOps` holding a `SetOps` (`SortedSet extends Set`, a
   superclass); defaults built from a smaller record (a default method); the representation
   chosen at the call, never found by its type (instance resolution, which principle 3 leaves
   out); two ordered sets of different `compare`s meeting in `union` (Haskell's coherence;
   Java's `TreeSet`, which keeps its comparator); and values of different representations in
   one list, which the first form gave. What Ernest cannot express goes to
   [`language_feedback.md`](language_feedback.md) and is decided with the user before the
   section goes around it.
3. **The section's examples** compile and run under the guide's checks.

---

## MVP 3.0 (peers), about three weeks

Designed in [`node_protocol.md`](node_protocol.md), which owns the protocol. The note is
tentative, and was brought to the report on 2026-09-28, each change a line marked *Changed*;
what it still asks of the report, listed below, and its open questions are decided before any
of it is built.

Nodes that reach each other, a spawn on a peer that ships code (§8.7), and messages between
them that carry values (§3.11). Code is shipped only between nodes running the same build,
§8.7's easiest case, and a peer whose build differs is refused with an error naming 3.1. Split
from MVP 3.1 on 2026-09-20.

- **First, what MVP 2.95's review left for after the release**, its item 4.4.
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
- **Code travels only with a spawn**, decided 2026-09-27 (§3.11, §6.5, §8.7; the log's *Code
  Travels Only With a Spawn*). A value that holds a function faults at the operation that
  would take it to another node, `function cannot cross nodes`, found by the walk that finds a
  foreign value; the function a spawn starts, with its captures, is shipped. An adapted address
  crosses as its target's address and its function's `{hash, env}`, and the node where it was
  made applies the function on delivery; one made around another node's process faults.
- **Running as a service, in production**, moved here from MVP 2.7 on 2026-09-27 (the log's
  *Running as a Service*):
  - a systemd unit: start and stop, a stop asked for ending the program by its signal;
    `Restart=on-failure` after a program ends with `Os.exit(1)`; and the journal showing fault
    lines without a doubled time;
  - a launchd plist on macOS, with the same checks;
  - a soak of hours: `examples/webserver.ern` under steady requests, measured as
    [`memory.md`](memory.md) says;
  - standard error on a full or failing disk ending the run with status 141, as §8.2 says;
  - `Clock.alarmAt` when the host's wall clock jumps: deadlines use the monotonic clock and a
    time does not, and the report decides what an alarm at a time does when the clock moves
    (Appendix E.15).
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
  passes a signal on to the host until the host has taken it would close it, and is decided at
  MVP 3.0 (2026-09-28).

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
