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
| MVP 3.0 | peers: one program on several nodes, by its proposal | items 1 to 9 done 2026-10-08 |
| MVP 3.1 | code by its hash, and the standard library's `Code` | design reviewed 2026-10-08 |
| MVP 3.2 | the ordered rolling restart: `ern deploy`, by its proposal | design reviewed 2026-10-08 |
| MVP 3.3 | the shell's second round | |
| MVP 3.4 | the libraries, as they are wanted | `libs/markdown` done 2026-09-25 |
| MVP 3.9 | the review before 1.0: the full review, the numbering decided once, the promise | |

---

## MVP 3.0 (peers), about four weeks

Designed in [`mvp3.0.md`](../proposals/nodes_and_code/mvp3.0.md), settled on 2026-10-07 after a
read-back against its four rules, and reviewed with mvp3.1.md and mvp3.2.md by six readers on
2026-10-08, every finding decided (the log's *The Three Proposals Reviewed Before Anything Is
Built*); its reasons are [`nodes.md`](../proposals/nodes_and_code/nodes.md), what the host showed
is the experiment under
[`experiments/`](../proposals/nodes_and_code/experiments/erlang_distribution/), and
[`other_systems.md`](../proposals/nodes_and_code/other_systems.md) holds what other systems do.
**The report's §8.6, §8.7 and §10 were rewritten from the proposal on 2026-10-08, item 1, and
the guide's peer chapter describes the design before it until the last item rewrites it; nothing
is built from the report's sections until each item below builds its area.**

The items, in build order, each with the report's sentences first, its tests, and a commit.
Each builds its area as the proposal's section 6 states it, whole: the proposal is the
specification, and this list the order. Item 8, `Peer`, is built after item 4 and before items 5
to 7 (decided on 2026-10-08): a program reaches another node's process only through an
address the standard library gives, since one foreign code gives is held behind the
boundary's checking proxy (§8.4), so items 5 to 7's tests of real nodes need `Peer.find`
and `Peer.spawn` first, and item 5's two parts that `Peer` uses, `Unreachable` from a lost
connection and an adapted address made on another node, come with it. The order is the dependency's: the checker's rules
first, since every later item's tests are written against them; then a node that starts; then
its connections; then what crosses, monitors, calls and the loss; then the node's end and its
reload, which need them; then `Peer`; then what stands on `Peer`.

1. **The report rewritten from the proposal, and the soundness argument's section 7.** The
   sections the proposal's section 9 names: §6.2's one silence widened to a `send` or a `kill`
   to a process whose node is out of reach or not listed, and its `send` that returns at once,
   which to a process of another node may wait for the network up to the host's buffer; §6.5's
   adapted address across nodes, its transport sentence whose run-time fault becomes a
   refusal, its captured values crossing inside it as payload touched only on the node that
   made it, the requirement that they can cross gone, a fault in its function the target's,
   and "there is no registry" beside offers under keys; §6.7's shape for `Peer.spawn`; §6.9's
   site, empty in a `Down` from another node's process and in `Unreachable`; §7.4's causes, the three
   faults of section 6's table, and the older peer chapter's three gone; §3.8, §3.11 and §3.9,
   whose run-time faults become the compiler's refusals of a key, a spawn and a capture with a
   type variable; §8.2's resolution failure, which is MVP 3.1's `NotLoaded`; §8.3, §8.5, §8.6
   and §8.7 as the proposal has them, no code crossing; §8.4, since a peer's message is not
   checked on arrival; §9.3's `Unreachable`, a reason only a monitor on another node's process
   gives, a one-node program's arm for it accepted; §10 whole; §11.2 and §11.3 for
   `--config-dir`, `ern config`, `ern reload` and `ern stop`, for a program without
   `--config-dir` being no node with `./.ernest` its directory, and §11's job list and §11.7's
   options, which gain `ern config`, `ern reload` and `ern stop` here and MVP 3.1's and 3.2's
   commands with theirs; Appendix C rewritten for the directory's shape; Appendix E's section
   for `Peer`, E.21's `Process.info` answering `None` for another node's process, E.18 and E.23
   for a resource bound to its node; Appendix F's words for a node, a peer, a key, the gateway
   and a bound type; §8.6 for a node's end, hangup a reload and termination an end, which MVP
   3.2 makes the planned stop. The log's entries for each, pointing at `nodes.md` for the
   argument. The rewrite leaves room for `ern run --config-dir dir` with no file, MVP 3.1's
   bare node, and adds nothing for it. `soundness.md`'s section 7 is written here, before item
   2, as the proposal's section 9 asks: which two types are one across nodes, and what crosses
   a node. With them, as the build reaches each: `architecture.md` for the gateway and its
   workers, the peer table and the rows a call keeps; `memory.md` for what those hold and when
   they let go; `style.md`'s glossary for peer, gateway, key and bound type; `test/diagnostics.md`
   for the compiler's refusals; the manual pages and `ern --help` for `ern config`, `ern reload`,
   `ern stop` and `--config-dir`; and the proposal's program of three nodes under `examples/`.
   When it is built, `mvp3.0.md`'s status line says so and the report owns the rules; the
   proposal and `nodes.md` stay as the record, as CLAUDE.md has it. Done 2026-10-08: the log's
   *The Report Rewritten for Peers* lists what the writing decided, an adapted address crossing
   whatever node its target is on among it; the prelude's `Reason` gained `Unreachable` in the
   same commit, since a test holds §9.3's declarations to the prelude's.
2. **The bound type in the checker.** A type bound to its node where it holds a function type,
   a foreign type, a resource, `Ets.Table` or the address of a socket, a listener or a program
   the runtime started, or an `Address(m)` or `Reply(m)` whose `m` is bound; the three refusals,
   a `Peer.key` of a bound type or of a type not fully known where it is written, a spawn whose
   captures are bound or have a type variable in their type, and a spawn whose mailbox type is
   bound; `Peer.offer` accepted only where the key and the address have one message type; a
   key's text as the compiler prints it. Nothing else is checked, and nothing is looked through
   at a send. Done 2026-10-08, with what the building decided, in the log's *The Bound Type in
   the Checker*: the function a spawn on a peer starts is a declaration's name or a lambda
   written in the definition, at the spawn or bound by a `let` the spawn names, decided with
   the user; `Peer.spawn` is not taken as a value; a key's message type and a spawned
   process's mailbox type are known whole where they are written; a key's text qualifies every
   name; `Peer`'s namespace is the standard library's from here; and `==` on another module's
   abstract type over a private type, which stopped the checker, reads the private type.
3. **The node's directory, its configuration and its start.** `ern config [--config-dir dir]`:
   the key, ed25519, which served in a TLS 1.3 handshake under a key rule where prime256v1
   had; the certificate the node signs itself, its name a constant and its validity from 1970
   to the end of 9999; `ernest.conf` with `listen`, the public key, no peer and no key; the
   public key printed; a directory made for one machine and never copied. `ernest.conf` read
   whole and checked: `listen`, an interface or all, port 0 the host's choice, a node without
   one dialling only; the peers with name, key and `network-address`, a name kept for the dial,
   a peer without an address never dialled; one family of addresses, the other refused at
   reading with the peer named; `keys`, a key's peers in the order a find asks them;
   `measures`, `cpu`, `memory` and `disk`, `check-interval` in milliseconds and `almost-full`
   a fraction, none running where the section is absent; a field unknown or given twice
   refused, `drain` and a peer's `coordinator` naming MVP 3.2. The start: the directory and the
   files it reads its user's or the superuser's and written by none beyond owner and group, the
   key read by none but its owner; `ernest.pid` made at the start, a living process's refused
   and a dead one's replaced, removed at the end however the run ends. A program without
   `--config-dir` is no node. Done 2026-10-08, with what the building decided in the log's
   *The Node's Directory*; what the plan had here of the carrier, the node's name on it, the
   number of its start in every address and the listener after the bindings, is item 4's,
   since a listener opens only under the rule that accepts a peer by its key.
4. **Connections and the carrier.** The host booted with the carrier's flags: `bin/ern` runs
   the host once where its arguments hold `--config-dir`, which parses the command line with
   the CLI's own parser and prints the flags a node needs, or none, and then starts the host
   with them, since the host takes its carrier only as it boots (decided with the user on
   2026-10-08, the log's *The Node's Directory*). The node's name on the carrier the key's
   digest with a constant, holding no network address; the number of its start in every
   address; the listener opened once the bindings have their values, a faulting initializer
   ending the node before it. One connection per pair, opened by the first operation that
   needs it, TLS 1.3 with a certificate on each side; the rule that accepts a peer by its key
   alone, the host's name check off and the certificate's dates ignored; no port-mapper daemon,
   the address from the configuration; connections not transitive; both dialling at once kept
   to one by the host. The cookie as the build's fingerprint: the protocol's, `ern`'s and OTP's
   versions and the checksum of every module on the load path in name order by the host's
   digest, the standard library out, two builds failing the handshake with nothing sent; a
   refused handshake `Unreachable` to the dialer, said by the acceptor. The detector's
   15-second tick and four intervals, a silence found in 45 to 75 seconds, the same on every
   node; connecting again on demand with no delay, a refused dial failing at once and a silent
   one given up after 7 seconds with what waited dropped. The seven frames of Ernest's and the
   host's carriers, as section 6's table has them: a message by the host's send, a message to
   an adapted address by a frame to the maker's gateway, a spawn and its answer, a find with a
   key's name and its type's text and its answer, a call's note and its second, a monitor and
   its `Down` by the host's, a `kill` by the host's exit signal, a call's answer by the host's
   alias, a sign of life by the host's tick, one build by the handshake. One registered gateway
   per node with a worker for each peer, taking the frame that opens a connection, through
   which go a spawn, a find and a message to an adapted address and nothing else; a frame it
   cannot read ending the connection. What a node says, one line each on its standard error,
   naming the alias or the key's digest where the peer is not listed: a peer connected; a peer
   lost, and whether it fell silent or closed; a peer refused for its key, by the rule, or for
   its build, by the cookie, the handshake's line the one report of the host's the node keeps,
   the rest off; a living connection replaced by another from the same name; nothing for a
   message, a call or a spawn. Done 2026-10-08, with what the building decided in the log's
   *The Carrier*: the TLS options passed to the host on the command line, no options file; the
   gateway's frames, which no item has added yet, each one it receives faulty, its kinds
   written by items 5, 6 and 8 with the operations that send them; a node detecting no
   deadlock here, where it first listens, in place of item 7.
5. **Addresses, messages and monitors across nodes.** An address the host's name for a process,
   the node, its start's number and the process's number, as good on a third node, outliving a
   loss, ended by its process's end or its node's new start, after which a send is dropped, a
   call ends at once and a monitor gives `Unknown`; a monitor not kept through a loss, and one
   made again while the node is out of reach or not listed giving `Unreachable`; `Reason`'s
   `Unreachable`, and a `Down`'s site empty from another node's process. `send` as the host's: it
   returns at once, a message to a peer with no connection queued behind the dial and dropped
   where the dial fails, the sender waiting only where the host's buffer is full and at most the
   detector's time, a large value crossing in pieces with other senders' messages between them.
   `kill` across nodes. Serialization in the host's format, a constructor as its name's text
   looked up among the node's atoms, nothing looked through before a send and nothing looked
   into on arrival, with a test that a correct program's messages make no new atom on the node
   that receives them. A message to an adapted address carried unconverted to the node that
   made it, whose gateway applies the function, a fault in it the target's, one step more than
   a send; `via` across nodes. The two parts `Peer` uses, `Unreachable` from a lost connection
   and an adapted address made on another node, were built with item 8, and so was
   `Address.callForever`'s `callee is unreachable`. Done 2026-10-08, with nothing in the
   runtime changed, since each operation is the host's and item 8 read the host's reasons: the
   test of three nodes holds it, in the log's *Addresses, Messages and Monitors Across Nodes*.
6. **Calls across nodes, and the loss.** The caller monitoring the callee while it waits; the
   request sent as a plain send is, the caller waiting at a full buffer and no helper process,
   so that everything one process sends keeps its order; `answer` the same, a second answer's
   crossing a message's cost; the note to the callee's node that a call waits with its reply,
   the row kept until the answer, the restart or the end, and the second note at the call's
   time; `Address.call`'s `None` and `Address.callForever`'s `callee is unreachable`; five of
   the host's signals. The loss: told by the host, hidden nodes watched as listening ones, no
   frame announcing it; a `Down` with `Unreachable` and an empty site for each monitor held on
   the peer's processes, what waited dropped, the calls waiting ended and every row of that
   peer gone, a dial to a peer that believes the old connection alive making it run its loss
   first; a node's own processes untouched but one in `Address.callForever`. Done 2026-10-08,
   with what the building decided in the log's *Calls Across Nodes*: the gateway records the
   notes itself and a restart asks it, and the second note goes wherever a call ends but by
   an answer on the callee's node, a restart or an end.
7. **The node's end and its reload.** The end: the program's end or termination, `ern stop` and
   `kill -TERM` by `ernest.pid`, in order as the host stops a node, every `Down` on its way
   crossing before the connection closes, the processes dying with `ProgramEnd`, a monitor made
   after that giving `Unreachable`. Hangup a reload, `ern reload` and `kill -HUP`, failing where
   there is no file or no such process: the peer table the rule and the dial read; a peer added
   a row; a peer removed or with a changed key its connection ended and both nodes running the
   loss; a changed address kept until the next dial; a changed name under the same key its
   connection kept; `measures` started or stopped; the node's own key and `listen` immutable, a
   file that changes either or does not parse refused with the old configuration kept; the
   lines said, which peers were added and removed or why the file was refused; the signal
   carrying nothing back, the command's status saying only that it was delivered. A node
   detects no deadlock, which item 4 built; the host's lost connection is `Unreachable` to a
   monitor, never a fault. `ern_signals`' second's sleep after `ern` sends itself the signal
   that ended it goes, the end waited for as what it is (CLAUDE.md, *No fixed sleep*). Done
   2026-10-08, with what the building decided in the log's *A Node's End and Its Reload*:
   the end in order by the reaper's wait for the deaths and the host's own question to each
   peer, no frame added; a monitor made while the node stops giving `Unknown`; a reload's
   lines, a peer renamed among them; and the two jobs' refusals.
8. **`Peer`.** `key`, a value that starts nothing; `offer`, under the key's name and its type's
   identity for as long as the process lives, faulting for a key a living process holds and
   for a process that is not this node's, with section 6's two causes; one `find(key, ms)` over
   the key's peers in the configuration's order, each given the time left, passing over
   `Unreachable`, `Refused`, `NotOffered` and `OtherType`, answering the first address at the
   type's text and otherwise the last failure met or `Timeout`, `NotListed` for a key with no
   entry, shipping no code; `spawn` and `spawnMonitored` with their time, the connection's
   opening among it, the frame with the function as a reference to its code, its captures and
   the site the peer records, `NotListed` for a name that is no peer's, a failed monitored spawn
   leaving no monitor, a spawn never faulting, a late answer making the node kill the process
   with what it keeps for that until the answer or the loss, and `NotLoaded` for a function
   whose bindings have no values on the peer or that arrives before the peer's bindings have
   theirs; one `Peer.Failure`, each operation's constructors stated; `Peer.nodes` without the
   running node and without peers marked `coordinator`. Bindings in spawned code the peer's,
   captures the spawner's, the system processes the peer's; nothing initialized because a peer
   asked. `Process.info` answering `None` for another node's process; a supervisor's children
   on its own node. The shell as a node, a function typed at it `NotLoaded` on a peer, its
   `:load` and `:reload` refused naming MVP 3.1; `ern run --config-dir dir` with no `.erc`
   refused naming MVP 3.1; `ern test` as a node; `Peer`'s page with its executed examples.
   Appendix E.27's listing, its type block and its primitives sentence are written here with
   the module, since four tests hold Appendix E's listings, types and primitives to `stdlib/`
   (the log's *The Report Rewritten for Peers*); until then E.27 states them in prose. The
   emitter passes `Peer.key` the key's text the checker supplies, and `test/diagnostics.md`
   gains §3.11's refusals of item 2, which a program reaches only once `Peer` is here; the
   checker's tests then take the module's interface in place of their stand-in. Done
   2026-10-08, with item 5's two parts, and with what the building decided in the log's *The
   Module Peer*: `NotLoaded` by module, decided with the user, a function's module checked at its
   version, a node carrying its whole build, a node dialling only once its bindings have their
   values, a find's answer the host's and the runtime's frames six, a foreign process's offer
   ending with it, and the help of a shell that is a node naming MVP 3.1.
9. **`Load` and `Balancer`**, in Ernest on the runtime: `Load`'s measures as shims, the run queue
   and the schedulers' utilisation on any node, memory and disk from the host's services, which
   answer a failure where `measures` did not start them, its page giving the host's names for
   the services; `Balancer.start(places)`, a place this node or a peer's name,
   `Balancer.pick(balancer, ms)` answering the place the program spawns its work on, round robin
   unless given a measure, a measure installed by the program spawning on each place a process
   that runs `Balancer.serve(balancer, place, measure)` and registers with the balancer, the
   measure named by its declaration, a pick drawing two candidates at random and taking the lower, a node
   without a measure or out of reach passed over: the first programs written on the design. The
   balancer picks and the program spawns, since a spawn on a peer starts only a function written
   at it (item 2). Decided with the user on 2026-10-08 as the item began (the log's *A Balancer
   Reaches Its Measures by Their Registering*): the measuring process registers with the
   balancer, whose address and place the program's spawn captures, since `Peer.find` names no
   node and so could not reach the two places a pick draws; `Balancer` has no key and no
   binding. Done 2026-10-08, with what the building decided in the log's *Load and Balancer*,
   Appendix G.4 and G.5 stating the two: `Load`'s five measures, the services' three answering
   `None` where they do not run; `Place` as `Here | On(String)`; a measured pick asked by a
   process of its own, so that a slow measure holds no other pick.
10. **The tests, the measurements and the guide.** Real nodes on one machine as the experiment
    runs them, holding the proposal's section 4 whole and the cases of its section 8: nodes
    with keys of their own, a peer stopped for a silent one, a node started again, a node that
    does not listen, a node of another build, a node that ends, the parted network through the
    proxy that drops what passes one way or both, and the find over a key's peers in the order,
    the time and the failures stated; a program's own test of two nodes, `ern test --config-dir
    dir` as a node, a second directory made by `ern config`, each listed in the other's
    `ernest.conf` on two ports of this machine, the second node started with `Os` on the same
    build and ended; the costs of the proposal's section 9 measured, the gateway's step, a
    call's five signals and TLS; the numbers of section 7 held; `docs/development.md`'s table
    for the refusals that name MVP 3.1, the shell's two and `ern run --config-dir dir` with no
    file; `make sections`, which lists §6.7 today for want of this milestone, naming no section
    after it; and the guide's peer chapter, here and not in item 1,
    since its examples run only once items 3 to 9 are built. The guide moves first, decided
    with the user on 2026-10-08 (the log's *The Guide in Two Files*): `ernest_guide.md` becomes
    `guide/language.md`, its section numbers kept, with every document, test and script that
    names it, and a citation of it becomes "the language guide §9.3", since `guide/` will hold
    a second file. The peer chapter teaches what a program writes, `Peer.find`, `Peer.spawn`,
    a monitor's `Unreachable` and a program of two nodes, with one paragraph on `ern config`;
    running nodes is `guide/deployment.md`'s, which MVP 3.1 begins. The chapter teaches, as §6.5
    and §8.7 state, that across nodes nothing orders a message through an adapted address
    against one sent to its target's own address, which the user decided on 2026-10-08 to keep
    (`language_feedback.md`'s entry 92, the log's *The Module Peer*).

11. **The fixed sleeps out of the tests.** CLAUDE.md's *No fixed sleep*, decided with the user
    on 2026-10-08 as item 4's tests were written: the 33 fixed sleeps of the tests in ten files,
    `ern_rt_tests`, `ern_reaper_tests`, `ern_tcp_tests`, `ern_os_tests`,
    `ern_system_module_tests`, `ern_emitter_tests`, `ern_integration_tests`, `ern_service_tests`,
    the load harness and the bench's, each made a wait on what it means, or, where an absence is
    what a test shows, a wait derived from what it waits for with the reason beside it.

Decisions the proposal leaves as they are, named here so that none is open: a key's name is
the program's, and two peers offering one key by mistake are told apart by nothing but the
order of the finder's list (its section 5, point 4); a connected peer may do anything on this
carrier, and no right is narrowed but the planned stop, which MVP 3.2 gives to peers marked
`coordinator`; and what other systems teach beyond the carrier and the address rule is
`nodes.md`'s and `other_systems.md`'s, and no item's.

---

## MVP 3.1 (code by its hash), about five weeks

Designed in [`mvp3.1.md`](../proposals/nodes_and_code/mvp3.1.md), written from the thinking in
[`code.md`](../proposals/nodes_and_code/code.md), settled on 2026-10-07 after a cross-check with
`mvp3.0.md`, a fresh reader's findings and a read-back, and reviewed with the other two
proposals on 2026-10-08; its reasons are `code.md`'s part one, and what three readers found of
Unison, Dhall, Nix, Git and the BEAM is
[`other_systems.md`](../proposals/nodes_and_code/other_systems.md), section 6. It is step C of
`code.md`'s section 1: a hash for each definition, a type's identity its shape with its
`compare`, code crossing by one exchange, versions side by side; nothing of step D, which is the
milestone after this one and `code.md`'s part two. The standard library's `Code`, placed as a
milestone of its own on 2026-10-06, is here: `Code` is two functions for the toolchain's Ernest
code and the tools, `load` and `hashes`, with `Code.Error`, a program having nothing to load by
name.

The items, in build order, each with the report's sentences first, its tests, and a commit.
The order is the dependency's: the hash before anything compares one, its first use visible in
`ern diff` before any node depends on it, the node's code before the exchange that fills it,
the cookie opened to other builds only once a spawn carries its code by hash, and the shell
last among what uses the exchange.

1. **The report and the soundness argument.** §8.7 rewritten from the proposal: identity by
   hash, a type's identity its shape with its `compare` and not its name, what crosses with a
   spawn and what a node told a root fetches, a binding's identity, nothing on a message; §11.1
   for what an `.erc` holds, the canonical forms and the hashes; §11.2 for a bare node, for the
   shell's `:load` and `:reload` in a shell that is a node, the reload a load of what changed
   with nothing purged, and for `ern diff`, with §11's job list and §11.7's options for it;
   §6.10's cross-node sentence rewritten over a spawn that carries its code; `Fault("its code
   was unloaded")` gone from §7.4, §8.4 and §11.2, since nothing is unloaded; §8.1, §8.5, §8.6
   and §11.8 for a bare node's entry process, which runs no `main` and ends by termination;
   §8.5 for `Code.load`'s fresh process at `Never`; Appendix E's section for `Code`, with
   `Code.Error`'s four constructors; Appendix F's and `style.md`'s glossary words, hash,
   identity, closure, code table and cache; `soundness.md`'s section 7 extended to identity by
   hash, on one node across a load as across nodes, and its paragraph for `Code.load`. The
   log's entries, pointing at `code.md` for the argument. With them, as the build reaches each:
   `architecture.md` for the code table, the cache and the exchange's process; `memory.md` for
   the three tables the host never shrinks; the manual pages and `ern --help` for `ern diff`;
   `docs/development.md`'s table for the refusals lifted.
2. **The canonical form, and the hash.** The form's document with the scheme's version, which
   changes with anything that runs before hashing, the form and the checker among it, written
   before any hash is computed, literals and order fixed, and its test suite: the same
   definition hashes the same across a rebuild, a renamed function or type keeps its
   dependents' hashes, a renamed constructor, field or binding changes them, a moved definition
   in a group changes the group's, two bodies that differ in local names or layout hash the
   same, a literal's encoding is fixed; two hashes for one definition and one hash for two are
   its cases. The compiler computes every definition's hash, the SHA-256 of its canonical form,
   the typed tree after checking, locals numbered by position, every name resolved and types
   written out, a reference the hash of what it names, a foreign declaration its qualified name
   and type, a function's own name and positions left out; a type's identity as its shape,
   parameters by position and constructors in order with their fields' names and their types'
   hashes, with its `compare` beside it, a mark where derived and the member's hash where
   written, and no other member's; a binding's identity its qualified name with its hash; a
   group's hash in source order with each member's position; a lambda's by its enclosing
   definition and position; an applied type's its constructor's hash over its arguments'
   identities, a built-in type's its name; no project name above a qualified name; the site a
   spawn frame carries the spawner's words, shown and never compared. The `.erc` carries the
   canonical forms and the hashes; a library under `libs/` is a program's code, hashed with it.
3. **`ern diff` and `Code.hashes`.** The first use of the hashes, visible before any node uses
   them: `changed` and `follows`, and the keys whose type identity changed, which are the
   services that answer `OtherType` across a rollout; `Code.hashes(path)`, a compiled module's
   definitions as name and hash.
4. **A node's code.** The code table from hash to the host's module and function; the node's own
   build compiled through it, one unit per source module; what arrives in one exchange compiled
   into one unit of the host's under a name of the node's own, its functions named by position,
   references compiled through the table; a load into a node that holds a unit of the module's
   name compiled the same way, so that no unit takes a second version and a load counts against
   the limits; nothing naming a unit of the host's; a build directory never changed under a
   running node, a new build in a directory of its own; the units off the code path, the node
   loading otherwise as `ern run` does; the cache on disk, each definition's canonical form with
   its compiled unit, the forms of received and shell-typed definitions kept and shipped onward
   as the node's own; the own build's forms read and verified from the `.erc` before they are
   shipped; the three limits, 65,536 module names, 524,288 lambdas and 1,048,576 atoms, never
   reclaimed, and the node's line on its standard error at four fifths of any, once.
5. **The exchange.** The spawn frame with the function's hash, its captures and the site; a peer
   that has the hash starting at once; the request for the list, the list of what the function
   references transitively, code and types, with the foreign declarations it names, the lacks
   with `NotLoaded` for a foreign module the peer lacks, and the code frames, each one
   definition's canonical form with its immediate references and never a compiled binary,
   dependencies first; verification on arrival, quarantine until the closure is complete, the
   closure compiled with the peer's own back end and loaded at once by the host's atomic load
   with no `-on_load`, what the peer said it has pinned meanwhile; a faulty frame ending the
   connection; `Refused` with the peer's text for a closure it cannot compile or load, a limit of
   the host's among the reasons; the exchange in a process of its own on each node, the
   gateways only passing its frames, the spawn's time covering it, two spawns on one hash
   sharing one, what arrived complete staying in the code table and the cache, and the second
   asker MVP 3.2 adds, a node told a root, fitting it.
6. **The cookie and the key.** The cookie as section 6 states it, without the build's checksum,
   `ern`'s version standing for the runtime surface's until MVP 3.2 names and versions the
   surface, so that nodes of different builds connect now that a spawn carries its code by
   hash; a key carrying its type's identity in the find frame in place of its text, `OtherType`
   by identity; `Refused`, the peer's refusal of a closure, with its text, a refused handshake
   staying `Unreachable`.
7. **Bindings, captures and the bare node.** Bindings' values by identity, name and hash; a
   spawned function finding a binding where the peer's own build ran that identity and
   `NotLoaded` otherwise, which lifts MVP 3.0's rule by module (§8.7, the log's *The Module
   Peer*), so that a function naming no binding spawns on any peer; the one rule for captures and references, a binding the function names
   the peer's and a value to carry bound to a local first; a service one per node, key and
   identity, a second offer faulting while it lives, a node of a build offering what that build
   started and a bare node what its peers spawned on it; `ern run --config-dir dir` with no
   file, the bare node, its entry process evaluating the standard library's bindings and
   waiting, ending by termination, refused without `listen`, taking spawns and offers;
   `Balancer.measure` carrying the key as a captured local; the refusal of `ern run --config-dir
   dir` with no file lifted from `docs/development.md`'s table.
8. **`Code.load` and the shell.** `Code.load(path)`, `ern run`'s loading reached from Ernest, the
   compiled module refused where it was compiled against another interface, the closure loaded
   at once and its bindings evaluated in a fresh process at `Never` while the caller waits,
   `Code.Error`'s `NotFound`, `Stale`, `Incomplete` and `Faulted(cause)`, the host's own load
   not offered, nothing unloaded; the shell's `:load` and `:reload` written in Ernest over it,
   compiling staying the toolchain's, in a shell that is a node: a load adding hashes and moving
   the session's names, a binding made before it keeping the type it was checked under, a
   message of one version to an address of the other a type error whose diagnostic names the
   previous version, a previous version's process running on with its key offered again only
   once it has ended, the reload's purge and `its code was unloaded` gone, which closes the
   two gaps the experiments found on 2026-10-07, a function of a previous version held in a
   process's state that the purge did not see, and a binding of a previous version forgotten
   where it is now kept at its own type (the log's *A Binding of a Previous Version Is
   Forgotten*), a shell-typed
   function spawning on a peer with its code; the shell's two refusals lifted from
   `docs/development.md`'s table.
9. **The tests, the measurements and the guide.** Two builds of one program as nodes on one
   machine, holding the proposal's section 4 whole and its section 8's cases: the cookie lets
   them connect, a find answers by identity and `OtherType`, a spawn of changed code ships
   exactly the lacking definitions, verified and loaded at once, and the process runs,
   `NotLoaded` for a binding and for a foreign declaration, a faulty frame ends the connection,
   a bare node takes a spawn and offers a service, a late or broken exchange leaves nothing
   half-loaded, `ern diff` names the changed definition and the changed key, a node told to
   load many units says so at four fifths of a limit, once, the shell's binding of a previous
   version refuses the new version's message and takes one of its own and its service runs on
   through two further reloads; a program's own test of two builds with the other started by
   `Os`; the numbers of section 7 held; a node told to load many units measured, with the
   growth of the host's module, lambda and atom tables; what a spawn that ships code costs;
   `guide/deployment.md` begun, the deployment guide, which owns running nodes: a node's
   configuration directory whole, `ern reload` and `ern stop`, and this milestone's chapter for
   code by its hash and the rolling deploy by hand, in place of a chapter of the language
   guide; `mvp3.1.md`'s status line.

What the plan once held for this milestone, the normalized definition, hash modules named
`ern#<base32>`, a registry per node, a loader beside the host's with a cache on disk, versions
coexisting by unloading, a drain and restart, a fetcher of libraries by hash, is decided
otherwise or placed: the first three by the proposal's *The hash* and *A node's code*, the
cache by *A node's code* and MVP 3.2's restart from it, the unloading by the proposal's limits
alone, the fetcher by MVP 3.4's library story.

---

## MVP 3.2 (the ordered rolling restart), about five weeks

Designed in [`mvp3.2.md`](../proposals/nodes_and_code/mvp3.2.md), whose every question was decided
on 2026-10-07, and which the review of 2026-10-08 changed most, every finding decided; its
reasons are [`deploy.md`](../proposals/nodes_and_code/deploy.md), what other systems do is
[`other_systems.md`](../proposals/nodes_and_code/other_systems.md)'s section 7, and what six
programs and their library showed is [`experiments/code_update/`](../proposals/nodes_and_code/experiments/code_update/README.md).
It is step D of `code.md`'s section 1: a deploy is a rolling restart the runtime orders and
checks, no code changes in a running process, a kept state outlives the restart through a file,
and the team writes a `migrate` and a conversion where a type changed and is told which.
What the plan held as MVP 3.1a, the runtime's surface in the cookie, is this milestone's. Each
item builds its area as the proposal's section 6 states it, whole.

The items, in build order, each with the report's sentences first, its tests, and a commit.
The order is the dependency's, and it begins on one node: `kept` and its file need no peer and
are tested first; the planned stop and the node's restart need no coordinator; the library, the
old shape and the cache are each a thing of their own; the plan's rows need them all, the
plan's order and print the rows, and `ern deploy` the plan; the generated test comes last,
since it runs the rest.

1. **The report and the soundness argument.** §8.7 for the rollout, the planned stop and the
   kept state; §9.5 for `kept`, a function of `restarting`'s family whose loop the runtime owns;
   §8.6 for termination as the planned stop, the one way a node ends, the program's own end
   the same, and the interrupt as the quick end; a section of §11's own after §11.8, no
   section renumbered, for `ern deploy`, `ern stop` as termination's sender, `ern status`
   and `ern state`, with §11's job list and §11.7's options for them; §11.2 for `ern diff`'s
   printed text, beside MVP 3.1's `ern diff`, and for a node's restart inside its host process;
   §11.3 for `keys`, `drain` and `coordinator` in `ernest.conf`, the `build` file, `state/` and
   `./.ernest` for a program that is no node; Appendix E for `Peer.find` over a key's peers as
   used here and for E.22's refusal, `a process runs one child function`; Appendix F's and
   `style.md`'s glossary words, build, root, kept state, planned stop, rollout and plan;
   `soundness.md`'s paragraphs for a kept state leaving its process, for the state file and
   `migrate`, and for a protocol served at the old identity. The log's entries, pointing at
   `deploy.md`. With them, as the build reaches each: `architecture.md` for the coordinator,
   the planned stop and the state files; `memory.md` for the cache and what the plan holds
   while it runs; `test/diagnostics.md` for the plan's refusals; the manual pages and
   `ern --help` for `ern deploy`, `ern status`, `ern state` and `ern stop`;
   `docs/development.md`'s table.
2. **The kept state, on one node.** `kept(key, init, step)`: the runtime's loop, the state held
   between steps, `step` on each message, composing with `spawn` and `restarting`, a fault in
   `step` restarting from `init`; the state file under `state/` in the directory, named by the
   key, the type's identity hash then the value in the crossing encoding, written to a temporary
   name, synced and renamed; `migrate` as a member of the new type from the old, found by its
   type, and the loop reading the file in place of `init` through it where the hash is not its
   own type's, the hash read before the value, beginning with `init` and saying so on its
   standard error where its build holds no `migrate`; the files removed once the node listens,
   every initializer having its value; a state that cannot cross not written. Termination as
   the planned stop for a program that is no node, in `./.ernest`: the kept states written at
   termination or the program's own end and read at the next start, the interrupt writing
   nothing. E.22's refusal, `a process runs one child function`, which closes the gap the
   supervisor experiment found on 2026-10-07 (`deploy.md`, section 13), the call being the
   program's mistake until then.
3. **The planned stop and the node's restart.** Termination, from the service manager, `ern stop`
   and `kill -TERM` alike, running the four steps: keys withdrawn, a find answering
   `NotOffered`; the drain until no call waits in the node's table, which the call's note fills
   for a remote caller, and every `kept` loop is idle, between two steps with an empty mailbox,
   or the node's time passes, `drain` in `ernest.conf`, a minute unless the configuration says
   otherwise, a request in flight lost; each kept state asked for between two steps and
   written, the loop holding what arrives, a failed write ending the stop before the close with
   the loops going on, the keys offered again and the node saying why on its standard error;
   the close in order, the loss the ordinary one. A second termination ending the drain early;
   the interrupt the quick end; the program's own end the same four steps. The `build` file:
   `ern run --config-dir dir prog.erc` writing its root, `ern run --config-dir dir` running what
   the file names from the cache and being the bare node where it names none; a stop that
   carries a next build writing the root before the close and restarting the runtime inside its
   host process by the host's own restart from the same command line, the pid unchanged and
   `ernest.pid` true; `ern stop` and the signal ending the process where no build was carried;
   a failed start writing the previous build and restarting into it once, a second fault ending
   the node. The frame carrying a next build accepted from a peer marked `coordinator` alone,
   the node's rollout mark, the coordinator's key and the next root, held through its restart
   until its keys are offered, another coordinator's frame refused while it holds one; the
   node's answer to the stop, done or the failure that ended it.
4. **The `Standing` library**, under `libs/`: `Standing.start(key, ms)`, an ordinary process with
   the mailbox `Message(m) | Went(Down)`, the caller given `via` of it with `Message`, finding
   the key by `Peer.find`, holding the address, monitoring the service and forwarding each
   message, finding again at `Went` and with `ms` between failed finds, dropping what arrives
   while no address is held, always answering an address, and ending at its caller's `Down`;
   its tests, a send dropped and a call `None` while the service is away, the service reached
   again on the same node and on another, the process ended with its caller.
5. **The old shape and what the program writes.** A changed declaration keeping its module, name
   and key, the old shape under another name in a module of its own, with its key at the old
   identity where it is a protocol, its deletion the drop; the old key offered at the old
   identity as `via(service, convert)` with a pure conversion for gained constructors, and
   through a forwarder the program writes for a retired request, the offer table by name and
   identity serving both; `migrate` on the old type from the new for the way back; `ern diff`
   printing the `migrate` both ways and the conversion that the matching fields and
   constructors give, a field matched by name and type copied, a dropped field left out, an
   added or renamed field and a retired or changed constructor left empty, for pasting, the
   tool writing into no source; the state written through the reverse `migrate` where the next
   build is older.
6. **The cache and the fetch.** A node restarting from its cache and nothing else, every form
   verified against its hash as it loads and the node refusing to start naming the first that
   fails, nothing compiled, a unit compiled from forms checked against no interface; the
   exchange's second asker, a node told a root asking the coordinator for the root's list, the
   coordinator shipping a build directory's forms from its `.erc` files as a node ships its
   own, the node compiling, writing to its cache and loading nothing until its restart; no
   build directory copied to a node.
7. **The plan's rows and their checks.** The coordinator's question frame and its answer: the
   root the node started from, its release and scheme version, its time, its configuration's
   digest, any rollout mark, the keys it offers with their identities, the kept states it holds
   with their identities and sizes. `ern diff` over the nodes' hashes and the new build's grown
   into the rows: each key's row from the identities of its protocol and its kept state's type
   in every build any node runs or any state file holds, the `migrate` found as a member by its
   type and paired by the key and never by a name, a changed protocol accepted where the old
   identity is offered by a conversion or a forwarder, a changed state where the `migrate`
   exists, a dropped protocol only when no node is older than the build that first offered
   both, nothing to do where both are unchanged; the refusal texts naming what to write, the
   member and its fields, the key and the identity not offered. Its own test suite: two builds
   in each of the matrix's rows and the row's line for each, accepted or refused, `ern diff`'s
   text for each, and the drop refused while an older node runs and accepted after.
8. **The plan's order, its print and its refusals.** The order over the running nodes whose root
   differs between the two builds, services before clients from the keys each node offers and
   its code finds, each node told the root of the entry point of its own qualified name, a
   cycle given an order with the finds that will wait named; every node told the next build's
   root before the plan is printed and fetching what it lacks, the yes asked only when every
   node holds the next build whole; the plan printed, each node's release and scheme version
   first, each service's line, the order, the nodes skipped for an unchanged root, each node's
   time and their sum as the most the rollout takes, a line saying the target is older than
   what runs where it is, the way back as the command to type, what a standing address drops
   meanwhile, and the builds the way back can reach, with the texts of its lines written here;
   its refusals, a node that does not answer unless `--without node`, the plan then saying that
   node must be deployed by hand before any build that drops a protocol, a node marked by
   another coordinator, a changed configuration, free disk short of a node's kept states, a
   node that cannot fetch for a full disk or a refusing cache, named with the cause, and a
   build lacking a node's entry point. Its tests: the order from a graph with and without a
   cycle over three builds in flight, a node skipped for an unchanged root, a node absent with
   and without `--without`, and a plan refused by a mark, by a changed configuration and by a
   full disk.
9. **`ern deploy`, `ern status` and `ern state`.** The coordinator in Ernest, a node like the
   shell, listed as `coordinator` by the nodes it deploys to: the plan and the yes, then one
   node stopped, restarted and checked by key at the plan's identities, and `next` or `all`,
   the pause between nodes and the one node tried first the operator's with no option; the
   wait for a node to be back within its time; at a node not back or lost, stopping and
   printing what stands at which version, rolling nothing back, `ern deploy` of either build
   with its own yes the way on or back; a cancel ending the coordinator alone, the node in its
   stop finishing and restarting itself; the configuration's digest asked again before each
   stop; nothing kept between runs, a second run continuing from what the nodes answer; a
   build let go from a node's cache when the plan has printed that no way back reaches it.
   `ern status --config-dir dir`, from the same frame, each node's root, release, keys with
   their identities, kept states and rollout mark; `ern state path`, a state file's type and
   value as Ernest literals.
10. **The runtime's surface, and a release of `ern`.** The surface named by what the exchange
    ships and what it calls by name, measured; versioned, taking in the standard library's
    identity, and in the cookie in place of `ern`'s version, so that two releases with one
    surface connect and a spawned function never meets a standard-library binding of another
    identity; a release installed by the operator and deployed by `ern deploy` with the build
    the nodes run, each node whose release is not the coordinator's restarted, its line saying
    so; a release that changes the surface stopping every node, said in its notes.
11. **The generated test**, `ern test --config-dir dir` given two build directories, the previous
    and the new: the shape half with nothing started, each service's line, each missing `migrate`
    and each old identity not offered refused; the run half with two nodes, values generated for
    each kept state's type from the previous build and written as state files, the previous
    build started on both, one node rolled and every key checked at the plan's identities, the
    other rolled, both stopped, what the stops wrote compared with what went in by identity and
    by the round trip through the reverse `migrate`, the rollback the same way, a state that
    cannot cross skipped and listed, no message of any protocol sent; the generator of values
    for a type, from the descriptors.
12. **The tests, the measurements and the guide.** The proposal's section 8 whole, on three nodes
    on one machine: a planned stop withdraws the keys, writes each kept state's file and closes
    in order; a kept loop reads its file through `migrate` and removes it, and begins afresh
    where no `migrate` fits; the `Standing` library's cases; a rollout in lockstep stops at a
    node that does not answer; a rollback through the reverse `migrate`; the cache holding the
    next build before the stop and letting an old one go; the refusal of E.22; and the generated
    test itself run over `experiments/code_update/`'s programs as its first subjects; the
    numbers of section 7 held; the deployment guide's chapter on a deploy, which teaches
    `kept`, the two builds and the old shape in its module, with the drain, the coordinator and
    the ordered rolling restart; `mvp3.2.md`'s status line, and `mvp3.0.md`'s and
    `mvp3.1.md`'s for what this milestone changed in them.

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
6. **The `live_region` test's one miss**, 2026-10-05 in a full `make test` under load (MVP
   2.99d's item 11), passed again alone and under `make test-shell`, and not failed since: when
   it fails again its step file in the run's directory says which expectation went unmet, and
   the fix follows from it; diagnosed here where it recurs, and nowhere before.

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
`VERSION` at the release (the release review's step 5); `Udp` to MVP 3.4 (the log's
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
MVP 3.3.

### The shell shows a bracket's match (done 2026-10-06, ahead of MVP 3.3)

A `)`, `]` or `}` typed at the prompt stands the cursor on the bracket it closes for half a
second or until the next key, as Readline's `blink-matching-paren` does, and a mismatch shows
nothing (§11.2 *Editing*). The compiler's lexer finds the bracket, so a string, a character or
a comment hides what it holds (the log's *The Shell Shows a Bracket's Match*).
