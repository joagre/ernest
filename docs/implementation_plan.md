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

**MVP 2.99d is done** on 2026-10-06: the standard library stands on the host and is
measured, with the prelude and the emitted code, and the report's and the guide's feedback
shipped as Ernest 0.3.1 (*Done* below). Next is MVP 3.0, peers, whose design is
[`mvp3.0.md`](../proposals/nodes_and_code/mvp3.0.md), settled with the user on 2026-10-07; before it is
built, MVP 3.1's design is written the same way, to check what MVP 3.0 leaves room for. A release waits until the user calls it.

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
| The principles review | the report and the guide against §0, and §0 against what it decided | done 2026-10-01 |
| Ernest 0.2.0 | the review's rules shipped as one, after the release review | done 2026-10-01, tag `v0.2.0` |
| MVP 2.99c | the language argued: the type system's argument, generated programs, the grammar and the library's laws as machines; then a release, Ernest 0.3.0 | done 2026-10-05, tag `v0.3.0` |
| The full review's findings | the 570 findings of MVP 2.99c's item 6, worked before its release | done 2026-10-05 |
| Ernest 0.3.1 | the documentation rewritten: the manual pages, the examples, the guide and the report's precision, from MVP 2.99d's items 4, 5, 7 and 8 | done 2026-10-05, tag `v0.3.1` |
| MVP 2.99d | the library stands on the host, measured with the prelude and the emitted code, and the report's and the guide's feedback | done 2026-10-06 |
| MVP 3.0 | peers: one program on several nodes, by its proposal | design reviewed 2026-10-08 |
| MVP 3.1 | code by its hash, and the standard library's `Code` | design reviewed 2026-10-08 |
| MVP 3.2 | the ordered rolling restart: `ern deploy`, by its proposal | design reviewed 2026-10-08 |
| MVP 3.3 | the shell's second round | |
| MVP 3.4 | the libraries, as they are wanted | `libs/markdown` done 2026-09-25 |
| MVP 3.9 | the review before 1.0: the full review, the numbering decided once, the promise | |

---

## MVP 3.0 (peers), about four weeks

Designed in [`mvp3.0.md`](../proposals/nodes_and_code/mvp3.0.md), settled with the user on
2026-10-07 after a read-back against its four rules, and reviewed with mvp3.1.md and mvp3.2.md by
six readers on 2026-10-08, every finding decided with the user (the log's *The Three Proposals
Reviewed Before Anything Is Built*); its reasons are
[`nodes.md`](../proposals/nodes_and_code/nodes.md), what the host showed is the experiment under
[`experiments/`](../proposals/nodes_and_code/experiments/erlang_distribution/), and
[`other_systems.md`](../proposals/nodes_and_code/other_systems.md) holds what other systems do.
**The report's §8.6, §8.7 and §10 and the guide's peer chapter describe the design before the
proposal. The report's are rewritten from it as this milestone's first item and the guide's as
its last, and nothing is built from them until then.**

The items, in build order, each with the report's sentences first, its tests, and a commit.
Each builds its area as the proposal's section 6 states it, whole: the proposal is the
specification, and this list the order.

1. **The report rewritten from the proposal, and the soundness argument's section 7.**
   §6.2's one silence widened to a `send` or a `kill` to a process whose node is out of reach
   or not listed, and its `send` that returns at once, which to a process of another node may
   wait for the network up to the host's buffer; §6.4's order for one sender and one receiver
   across nodes, with the one corner of an adapted address made on the receiver's node (the
   proposal's section 4, point 1); §6.5's adapted address across nodes, its captured values
   crossing inside it as payload touched only on the node that made it, the requirement that
   they can cross gone, a fault in its function the target's, and "there is no registry" beside
   offers under keys; §6.6's calls across nodes; §6.7's shape for `Peer.spawn`; §6.9's site,
   which crosses in a `Down` and is empty in `Unreachable`; §7.4's causes; §3.8, §3.11 and §3.9,
   whose run-time faults become the compiler's refusals of a key, a spawn and a capture with a
   type variable; §8.2's resolution failure, which is MVP 3.1's `NotLoaded`; §8.3, §8.5, §8.6
   and §8.7 as the proposal has them, no code crossing; §8.4, since a peer's message is not
   checked on arrival; §9.3's `Unreachable`, a reason only a monitor on another node's process
   gives, a one-node program's arm for it accepted; §10 whole; §11.2 and §11.3 for
   `--config-dir`, `ern config`, `ern reload` and `ern stop`, for a program without
   `--config-dir` being no node with `./.ernest` its directory, and §11's job list and §11.7's
   options; Appendix C rewritten for the directory's shape; Appendix E's section for `Peer`,
   E.21's `Process.info`, E.18 and E.23 for a resource bound to its node; Appendix F's words
   for a node, a peer, a key and the gateway; §8.6 for a node's end, hangup a reload and
   termination an end, which MVP 3.2 makes the planned stop. The log's entries for each,
   pointing at `nodes.md` for the argument. The rewrite leaves room for `ern run --config-dir
   dir` with no file, MVP 3.1's bare node, and adds nothing for it. `soundness.md`'s section 7
   is written here, before item 2, as the proposal's section 9 asks. With them, as the build
   reaches each: `architecture.md` for the gateway and its workers, the peer table and the rows
   a call keeps; `memory.md` for what those hold and when they let go; `style.md`'s glossary
   for peer, gateway, key and bound type; `test/diagnostics.md` for the compiler's refusals;
   the manual pages and `ern --help` for `ern config`, `ern reload`, `ern stop` and
   `--config-dir`; and the proposal's program of three nodes under `examples/`. When it is
   built, `mvp3.0.md`'s status line says so and the report owns the rules; the proposal and
   `nodes.md` stay as the record, as CLAUDE.md has it.
2. **The node.** `ern config`: the key on prime256v1, the curve the experiment proved, with
   ed25519 in the handshake under the rule tried first and taken where it serves; the
   certificate with the longest validity; `ernest.conf`; the public key printed. The
   configuration: `listen`, with port 0 taking the host's choice and the node saying which it
   bound; the peers with name, key and `network-address`, one family of addresses; `keys`, a
   key's peers in the order a find asks them; `measures`. The rule that accepts a peer by its
   key, with the host's name check off and the certificate's dates ignored; the table in place
   of the port-mapper daemon; no mesh; the cookie as the build's fingerprint over the checksum
   of what runs; the detector's time, watching hidden nodes as well as listening ones.
   `ernest.pid` and its guard; the bindings before the listener; hangup a reload and
   termination an end, `ern stop`; the orderly end; what a node says, with the host's reports
   off but the handshake's, the one line that tells a refused build.
3. **Messages and addresses.** The bound type in the checker: `Peer.key` of a bound type or
   of a type not fully known where it is written, a spawn whose captures are bound or have a
   type variable, and a spawn whose mailbox type is bound, refused. Serialization as the
   proposal's section 6 has it, the host's format, a constructor as its name's text, nothing
   looked through before a send and nothing looked into on arrival, with a test that a correct
   program's messages make no new atom on the node that receives them. `send` as the host's,
   a plain send to a peer with no connection returning at once and its message queued behind
   the dial, the sender waiting only past the host's buffer; `Reason`'s `Unreachable`; the
   site in a `Down` across nodes; `kill`; one registered gateway per node with a worker for
   each peer, taking the frame that opens a connection; a message to an adapted address
   carried unconverted to the node that made it, its function's fault the target's.
4. **Calls.** The request sent as a plain send is, the caller waiting at a full buffer and no
   helper process, so that everything one process sends keeps its order; `answer` the same,
   a second answer's crossing a message's cost; the note to the callee's node that a call
   waits, and the second at its time; `callee is unreachable`.
5. **`Peer`.** `key`; `offer`, which faults the caller for a key a living process holds; one
   `find(key, ms)` over the key's peers in the configuration's order, each given the time left,
   passing over `Unreachable`, `Refused`, `NotOffered` and `OtherType`, answering the first
   address at the type's text and otherwise the last failure met or `Timeout`, and `NotListed`
   for a key with no entry; `spawn` and `spawnMonitored` with their time, the site in the
   frame, `NotLoaded`, and the kill of a process whose spawner stopped waiting; one
   `Peer.Failure`, each operation's constructors stated, a connection the handshake refused
   being `Unreachable`; `Peer.nodes` without peers marked `coordinator`. `ern reload` by
   `SIGHUP` and the table. The shell as a node, its `:load` and `:reload` refused naming MVP
   3.1; `ern test` as a node, two of them on one machine on port 0; `Peer`'s page with its
   executed examples. The deadlock detector told by `--config-dir` that a monitor on a peer's
   process declares none, and the host's lost connection `Unreachable` to it.
6. **`Load` and `Balancer`**, in Ernest on the runtime, with `measures` starting the host's
   services: the first programs written on the design.
7. **The tests**, with real nodes on one machine as the experiment runs them, holding the
   proposal's section 4 whole and the cases of its section 8, nodes with keys of their own, a
   peer stopped for a silent one, a node started again, a node that does not listen, a node
   of another build and a node that ends, the parted network through the proxy among them,
   and the find over a key's peers in the order, the time and the failures stated; a
   program's own test of two nodes with `ern config` and `Os`, as section 8 has it; the costs
   of the proposal's section 9 measured; `docs/development.md`'s table for the refusals that
   name MVP 3.1, the shell's two and `ern run --config-dir dir` with no file; and the guide's
   peer chapter, here and not in item 1, since its examples run only once items 2 to 6 are
   built.

Decisions the proposal leaves as they are, named here so that none is open: a key's name is
the program's, and two nodes offering one key by mistake are told apart by nothing but the
order of the finder's list (its section 5, point 4); a connected peer may do anything on this
carrier, and no right is narrowed but the planned stop, which MVP 3.2 gives to peers marked
`coordinator`; and what other systems teach beyond the carrier and the address rule is
`nodes.md`'s and `other_systems.md`'s, and no item's.

---

## MVP 3.1 (code by its hash), about five weeks

Designed in [`mvp3.1.md`](../proposals/nodes_and_code/mvp3.1.md), written from the thinking in
[`code.md`](../proposals/nodes_and_code/code.md), settled with the user on 2026-10-07 after
a cross-check with `mvp3.0.md`, a fresh reader's findings and a read-back, and reviewed with the
other two proposals on 2026-10-08; its reasons are `code.md`'s part one, and what three readers
found of Unison, Dhall, Nix, Git and the BEAM is
[`other_systems.md`](../proposals/nodes_and_code/other_systems.md), section 6. It is step C of
`code.md`'s section 1: a hash for each definition, a type's identity its shape, code crossing by
one exchange, versions side by side; nothing of step D, which is the milestone after this one
and `code.md`'s part two. The standard library's `Code`, placed as a milestone of its own on
2026-10-06, is here: `Code` is two functions for the toolchain's Ernest code and the tools,
`load` and `hashes`, with `Code.Error`, a program having nothing to load by name.

The items, in build order, each with the report's sentences first, its tests, and a commit:

1. **The report and the soundness argument.** §8.7 rewritten from the proposal: identity by
   hash, a type's identity its shape and not its name, what crosses with a spawn and what a
   node told a root fetches, a binding's identity, nothing on a message; §11.1 for what an
   `.erc` holds; §11.2 for a bare node, for the shell's `:load` and `:reload` in a shell that
   is a node, the reload a load of what changed with nothing purged, and for `ern diff`; §6.10's
   cross-node sentence rewritten over a spawn that carries its code; `Fault("its code was
   unloaded")` gone from §7.4, §8.4 and §11.2, since nothing is unloaded; §8.1, §8.5, §8.6 and
   §11.8 for a bare node's entry process, which runs no `main` and ends by termination; §8.5
   for `Code.load`'s fresh process at `Never`; Appendix E's section for `Code`, with
   `Faulted(cause)`; `soundness.md`'s section 7 extended to identity by hash, and its paragraph
   for `Code.load`. The log's entries, pointing at `code.md` for the argument.
2. **The canonical form, and the hash.** The form's document with the scheme's version, which
   changes with anything that runs before hashing, written before any hash is computed, and its
   test suite: the same definition hashes the same across a rebuild, a renamed function or type
   keeps its dependents' hashes, a renamed constructor, field or binding changes them, a moved
   definition in a group changes the group's, two bodies that differ in local names or layout
   hash the same, a literal's encoding is fixed; two hashes for one definition and one hash for
   two are its cases. The compiler computes every definition's hash, a type's identity as its
   shape with its `compare`, a binding's with its name, a group's in source order, a lambda's by
   its enclosing definition and position; the `.erc` carries the canonical forms and the hashes.
3. **`ern diff` and `Code.hashes`.** The first use of the hashes, visible before any node uses
   them: `changed` and `follows`, and the keys whose identity changed.
4. **The cookie and the key.** The cookie without the build's checksum, `ern`'s version in it
   until MVP 3.2 puts the runtime's surface there; a key carrying its type's identity in the
   find frame; `OtherType` by identity; `Refused`, the peer's refusal of a closure, with its
   text.
5. **A node's code.** The code table from hash to the host's module and function; the node's
   own build compiled through it; what arrives in one exchange compiled into one unit of the
   host's, its functions named by position; a build directory never changed under a running
   node; the units off the code path, loading otherwise as `ern run` does; the cache on disk,
   each form with its compiled unit; the node's line on its standard error at four fifths of a
   limit, modules, lambdas and atoms.
6. **The exchange at a spawn.** The spawn frame with the function's hash; the request for the
   list, the list with the foreign declarations, the lacks and the code frames, each one
   definition's canonical form with its immediate references; verification on arrival,
   quarantine until the closure is complete, one atomic load, what the peer said it has pinned
   meanwhile; the exchange in a process of its own on each node, written so that MVP 3.2's
   second asker, a node told a root, fits it; `NotLoaded` for a foreign module the peer lacks
   and `Refused` for a closure it cannot load; a form verified before it is shipped; the forms
   of received and shell-typed definitions kept.
7. **Bindings, the bare node and the shell.** Bindings' values by identity; the one rule for
   captures and references, a binding a spawned function names the peer's and a value to carry
   bound to a local first; `ern run --config-dir dir` with no file, its entry process
   evaluating the standard library's bindings and waiting, refused without `listen`; the
   shell's two refusals lifted, a shell-typed function spawning with its code;
   `Balancer.measure` carrying the key as a captured local.
8. **`Code.load`**, its bindings evaluated in a fresh process at `Never` while the caller waits,
   with `Code.Error` and `Faulted`, and the shell's `:load` and `:reload` written in Ernest
   over it, compiling staying the toolchain's.
9. **The tests, the measurements and the guide.** Two builds of one program as nodes on one
   machine, holding the proposal's section 4 whole; a node told to load many units, once,
   measured, with the growth of the host's module, lambda and atom tables; what a spawn that
   ships code costs; the guide's chapter for code by its hash and the rolling deploy by hand;
   `docs/development.md`'s table for the refusals lifted; `mvp3.1.md`'s status line.

What the plan once held for this milestone, the normalized definition, hash modules named
`ern#<base32>`, a registry per node, a loader beside the host's with a cache on disk, versions
coexisting by unloading, a drain and restart, a fetcher of libraries by hash, is decided
otherwise or placed: the first three by the proposal's *The hash* and *A node's code*, the
cache by *A node's code* and MVP 3.2's restart from it, the unloading by the proposal's limits
alone, the fetcher by MVP 3.4's library story.

---

## MVP 3.2 (the ordered rolling restart), about five weeks

Designed in [`mvp3.2.md`](../proposals/nodes_and_code/mvp3.2.md), whose every question was decided
with the user on 2026-10-07, and which the review of 2026-10-08 changed most, every finding
decided with the user; its reasons are
[`deploy.md`](../proposals/nodes_and_code/deploy.md), what other systems do is
[`other_systems.md`](../proposals/nodes_and_code/other_systems.md)'s section 7, and what six
programs and their library showed is [`experiments/code_update/`](../proposals/nodes_and_code/experiments/code_update/README.md).
It is step D of `code.md`'s section 1: a deploy is a rolling restart the runtime orders and
checks, no code changes in a running process, a kept state outlives the restart through a file,
and the team writes a `migrate` and a conversion where a type changed and is told which.
What the plan held as MVP 3.1a, the runtime's surface in the cookie, is this milestone's. Each
item builds its area as the proposal's section 6 states it, whole.

1. **The report and the soundness argument.** §8.7 for the rollout, the planned stop and the
   kept state; §9.5 for `kept`, a function of `restarting`'s family whose loop the runtime owns;
   §8.6 for termination as the planned stop, the one way a node ends, and the interrupt as the
   quick end; §11.2 for `ern deploy`, `ern status`, `ern state`, `ern diff`'s printed text and
   a node's restart inside its host process; §11.3 for `keys`, `drain` and `coordinator` in
   `ernest.conf`, the `build` file and `state/`; Appendix E for E.22's refusal, `a process runs
   one child function`; Appendix F's and `style.md`'s glossary words, build, root, kept state,
   planned stop, rollout, plan, code table and cache; `soundness.md`'s paragraphs for a kept
   state leaving its process, for the state file and `migrate`, and for a protocol served at
   the old identity. The log's entries, pointing at `deploy.md`.
2. **The plan from the hashes.** `ern diff` grown into the plan: each key's row from the
   identities of its protocol and its kept state's type in every build in flight, the `migrate`
   found by its type and paired by the key, a protocol changed accepted where the old identity
   is offered, a build that drops a protocol accepted only when no node is older than the one
   that first offered both; the order over the running nodes whose root changed, services
   before clients, each told the root of its own qualified name; what the plan prints, the
   releases, the skipped nodes, each node's time and their sum, an older target, the way back
   as a command, what a standing address drops, the builds the way back reaches; its
   refusals, a node down unless `--without`, a mark, a changed configuration, a full disk,
   and what to write.
3. **The old shape and what the program writes.** The offer table by name and type identity;
   the old key offered as `via(service, convert)` with a pure conversion for a gained
   constructor, and through a forwarder of the library `Forward` for a retired request;
   `migrate` as a member of the new type from the old and of the old from the new; `ern diff`
   printing the `migrate` and the conversion to paste, with what needs a decision left empty;
   the library `Standing` under `libs/`, an ordinary process over `Peer.find` and `monitor`
   that always answers an address and ends with its caller.
4. **The kept state, the planned stop and the state file.** `kept(key, init, step)`; termination
   as the planned stop, from the service manager, `ern stop` and `kill -TERM` alike, accepted
   as a frame from a peer marked `coordinator` alone: keys withdrawn, the drain until no call
   waits in the node's table and every `kept` loop is idle or the node's time passes, each
   kept state asked for between two steps and written, the close; a second termination ending
   the drain early, the interrupt the quick end; the state file written, synced and renamed,
   its hash read before its value, read by the `kept` loop in place of `init` through `migrate`
   where the identity differs, removed once the node listens, and a failed write ending the
   stop before the close; the `build` file, and the restart of the runtime inside its host
   process where a next build was carried; a failed start going back to the previous build
   once by the node's own act.
5. **The cache and the surface.** A node restarting from its cache, every form verified against
   its hash and nothing compiled; the fetch of the next build before the yes by the exchange's
   second occasion, the coordinator shipping a build directory's forms; a build let go when the
   plan has printed that no way back reaches it; the runtime's surface named, versioned, taking
   in the standard library's identity, and in the cookie in place of `ern`'s version; a release
   of `ern` deployed by restarting each node whose release differs, after the operator installs
   it.
6. **`ern deploy`, `ern status` and `ern state`.** The coordinator in Ernest, a node like the
   shell, listed as `coordinator`: the question frame and its answer; the plan and the yes per
   node, `next` or `all`; the lockstep, the wait for the node to be back within its time, the
   check by key at the plan's identities; at a node not back or lost, stopping and printing
   what stands, rolling nothing back, `ern deploy` of either build the way on or back; a
   node's rollout mark; nothing kept between runs. `ern status`, from the same frame, and
   `ern state`.
7. **The generated test**, `ern test --config-dir dir` given two build directories: the shape
   half, and the run half with two nodes, values generated for each kept state's type and
   written as state files, the rollout, the comparison by identity and round trip, the
   rollback; the generator of values for a type.
8. **The tests, the measurements and the guide.** The proposal's section 8 whole, on three nodes
   on one machine; `experiments/code_update/`'s programs run as the generated test's first
   subjects; the guide's chapter on a deploy, which teaches `kept`, the two builds, the old
   shape in its module and small protocols of a service's own with the shared record's number;
   `mvp3.2.md`'s status line.

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

## MVP 3.4 (the libraries, as they are wanted)

A library not yet written waits, and is written when our work needs it, MVP 3.0 and 3.1 among
that work, when someone asks for it, or when we want it, decided 2026-09-25 (the log's
*Libraries As They Are Wanted*). Each is an Ernest source root under `libs/<name>/` that a
program adds with `--load-path`, with `stdlib/`'s test discipline, documented in one pass to
[`module_doc_template.md`](module_doc_template.md) with its executed examples as its first
user, and a section in the appendix of libraries. Own repositories come later, when there is a
package story. Written: `libs/ets`, `libs/markdown` and `libs/ansi` (Appendix G; `libs/markdown` under
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

- **A child's function run in a process that is already a supervisor's child** (found
  2026-10-07 by the supervisor experiment under
  `proposals/nodes_and_code/experiments/code_update/`): `Supervisor.child(group, f)()` called
  inside a running child reads the process's start cause, which is the outer restart's, and
  reports a fault that did not happen, so the group may give up. Appendix E.22 is silent on
  it. Decided with the user on 2026-10-07 (`deploy.md`, section 13): the call is refused,
  `Fault("a process runs one child function")`, which E.22 states and `Supervisor` does
  when step D is built; an operation by which a child replaces the function its restart runs
  was decided the same day and withdrawn, no code changing in place. Until then the call is
  the program's mistake, and the experiment's README says so.
- **The shell's reload does not see a function of the previous version held in a process's
  state** (found 2026-10-07 by the counter experiment under `proposals/nodes_and_code/experiments/code_update/`):
  §11.2 lists the processes still running a previous version by the host's
  `check_process_code`, which sees a process's code and not a function held in its arguments
  (the survey's *B8*), so a library loop that holds a module's `step` is not listed, and the
  further reload that purges the version leaves it to fail with the host's `undef` at its next
  call rather than §7.4's `its code was unloaded`. The host offers no way to see a function in
  another process's state. MVP 3.1 removes the purge, nothing being unloaded and no unit taking a
  second version (`mvp3.1.md`, section 6, *A node's code*), which closes it; since 2026-10-07 §11.2
  says the limit, as it says the host's others.
- **The shell does not tell a previous version of a type from the current one** (found
  2026-10-07 by an experiment while [`mvp3.1.md`](../proposals/nodes_and_code/mvp3.1.md) was
  read back): after a `:reload` that added a constructor to `Counter.Msg`, a message of the
  new version sent to a binding of the old was accepted, and sat unmatched in the old
  process's mailbox (§6.3). Since 2026-10-07 §11.2 has the reload forget such a binding,
  naming MVP 3.1, which `reload_forgets_previous_version` in `test/ern_shell_tests.erl` holds
  (the log's *A Binding of a Previous Version Is Forgotten*). Its fix is MVP 3.1's items 2
  and 7, a type's identity its hash in the session's scope as everywhere (`mvp3.1.md`,
  section 6, *The shell*), which keeps the binding, of its own type, and refuses only a
  message of the other version.
- **The shell's `live_region` test, unmet once** (2026-10-05, in a full `make test` under
  load; MVP 2.99d's item 11): its terminal script found an expected line missing; run
  again alone it passed, and under `make test-shell` too, and it has not failed since in
  the full runs of 2026-10-06. Undiagnosed: when it fails again, its step file in the run's directory
  says which expectation went unmet, and the fix follows from it.
- **§3.11, §6.7 and §8.7 have no citing test**, which `make sections` lists. All three are MVP
  3.0 and 3.1 material and unbuilt, since 2026-10-01 a spawn on a peer being `Peer.spawn`'s,
  which §8.3 introduces and a test of its refusal cites; anything else it lists is a gap.
- **A termination or hangup that comes while the host starts**, before the runtime can take
  signals, is lost, or ends the program with status 0 and a line of OTP's own, `SIGTERM
  received - shutting down`; on this machine on 2026-10-02 the window was about a quarter of a
  second. §8.6 and §11.8 state it as the host's limit since 2026-10-02 (MVP 2.99b's item 6,
  the log's *MVP 2.99b's Questions, One by One*). Its fix is OTP's, a signal held until the
  host's signal server runs, which the user takes to OTP's maintainers (`docs/otp_bugs.md`,
  report 2); since 2026-10-03
  (item 9) the host installs Ernest's handler as the first thing it runs, and the second
  outcome's window measured about 5 milliseconds where it had been about 12.
- **A signal that ends the host while it starts a port**, for a host program, for `ern_exec`,
  or for OTP's lookup of the host's name, leaves a line of OTP's helper on standard error,
  `erl_child_setup: failed with error 32 on line 284`, where §8.6 has the runtime print
  nothing (found 2026-10-01). Every run starts two such ports before `main`, and a program
  that starts host programs meets it while it runs. A port closed while it starts would
  leave the same line by OTP's source, and was not met in thirty tries. Its fix is OTP's: the
  child exits silently when the host is gone, as the helper does, which the user takes to
  OTP's maintainers (`docs/otp_bugs.md`, report 1; decided 2026-10-01, the log's *A Port Lost While It Starts*). Ernest adds
  nothing around it, and the gap stands until a release of OTP that Ernest requires has it.
- **OTP 29's compiler refuses a recursive call through `rem`** (found 2026-10-05 by `make
  test-typed`, seed 74183997, program 220): a well-typed program whose emitted Erlang is valid
  fails to build, `emitted Erlang does not compile`, OTP's validator reporting "Internal
  consistency check failed - please report this bug". Five lines of Erlang show it, with
  nothing of Ernest's: `f() -> h([1000, -79], -62).`, `h([], Acc) -> Acc;` and `h([X | Rest],
  _Acc) -> h(Rest, X rem (X - 3)).` OTP's type pass gives the accumulator the list's range,
  -79 to 1000, where `rem`'s is -996 to 996, a divisor whose range holds 0; compiled with
  `+no_type_opt` it builds and answers -79. Met in OTP 29's compiler 10.0.5. Its fix is OTP's,
  which the user takes to OTP's maintainers (`docs/otp_bugs.md`, report 3). Meanwhile, decided with the user on 2026-10-05
  (the log's *OTP's Compiler, Worked Around*), the emitter compiles a module the validator
  refuses again with that pass off, that module alone, `ern_emitter`'s
  `compiled_without_type_pass`, whose comment says so. Its test holds that the host still
  refuses the shape, so that it fails, and says the workaround goes, once an OTP with the fix
  runs it.
- **The launchd checks** of `make service`, written for macOS in MVP 2.99b's item 10, have
  not run, since no Mac has been at hand; 0.3.0's and 0.3.1's notes say so. They run on the
  first Mac the project has, and a release's notes say they have not until then.

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

### `libs/markdown` — a CommonMark renderer (done 2026-09-25, now under MVP 3.4)

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
*Standing gaps*.

### The shell shows a bracket's match (done 2026-10-06, ahead of MVP 3.3)

A `)`, `]` or `}` typed at the prompt stands the cursor on the bracket it closes for half a
second or until the next key, as Readline's `blink-matching-paren` does, and a mismatch shows
nothing (§11.2 *Editing*). The compiler's lexer finds the bracket, so a string, a character or
a comment hides what it holds (the log's *The Shell Shows a Bracket's Match*).
