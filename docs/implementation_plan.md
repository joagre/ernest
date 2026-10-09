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
2026-10-09, and their sections below are written from them. Next is the principles review over
MVP 3.1's proposal, then MVP 3.1 from its item 1. A release waits until the user calls it.

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
| The principles review | the report and the guide against §0, and §0 against what it decided | done 2026-10-01 |
| Ernest 0.2.0 | the review's rules shipped as one, after the release review | done 2026-10-01, tag `v0.2.0` |
| MVP 2.99c | the language argued: the type system's argument, generated programs, the grammar and the library's laws as machines; then a release, Ernest 0.3.0 | done 2026-10-05, tag `v0.3.0` |
| The full review's findings | the 570 findings of MVP 2.99c's item 6, worked before its release | done 2026-10-05 |
| Ernest 0.3.1 | the documentation rewritten: the manual pages, the examples, the guide and the report's precision, from MVP 2.99d's items 4, 5, 7 and 8 | done 2026-10-05, tag `v0.3.1` |
| MVP 2.99d | the library stands on the host, measured with the prelude and the emitted code, and the report's and the guide's feedback | done 2026-10-06 |
| MVP 3.0 | peers: one program on several nodes, by its proposal | done 2026-10-09 |
| MVP 3.1 | code by its hash: a hash for each definition, nodes of different builds on one floor, the shell's reload by hash, termination told, and `Standing` | design read through 2026-10-09; the principles review runs before its item 1 |
| MVP 3.2 | code with a spawn: the exchange, the bare node, a unit let go, and `Code` | design read through 2026-10-09; stands on MVP 3.1 |
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
the guide's peer chapter from the report on the same day, item 10.**

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
    since its examples run only once items 3 to 9 are built. Done 2026-10-08 but for one part,
    in the log's *The Tests, the Costs and the Guide*: real nodes hold the proposal's section 4
    and the cases of its section 8, a silent peer, the network parted one way and both through
    a proxy, and a dial nothing answers, the detector's and the dial's times read and held;
    `make bench`'s third part measures section 9's three costs between two nodes; `make
    sections` names nothing; and `guide/language.md`'s chapter 8 teaches peers from §8.7. The
    last part, a program's own test of two nodes, wrote the second node's `ernest.conf`, JSON,
    so `libs/json` was written first, decided with the user (`language_feedback.md`'s entry 93):
    Appendix G.6, its primitives in Erlang the application `erl/json`, as E.0 rule 1 now has a
    difference Ernest cannot close (the log's *The Module Json*). Measuring it found the
    boundary rebuilding every value whose type holds a float, and the check now walks a value
    once, decided with the user (*The Boundary Rebuilt Every Float*); and a test that failed
    left its nodes running, which `make test` now stops (*Nodes a Failed Test Left Running*).
    The test is `test/peers/pair.ern`, run as a node by `program_test_` (the log's *A
    Program's Own Test of Two Nodes*). The guide moves first, decided
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
    on 2026-10-08 as item 4's tests were written. Done 2026-10-08, the log's *The Tests Wait on
    What They Mean*: about a hundred sleeps and polls in sixteen files, where the plan had
    counted 33 in ten, each now a wait on what it means, through `erl/runtime/test/ern_waits.erl`
    where only the host reports it; a node's output through pipes to a watcher; the terminal
    harness waiting on output and on the child's end; an absence a time derived from what it
    waits for; and the load harness's one pause after its collections, which nothing the host
    reports shows, stated with its measurement. Found doing it: the sleeps hid tests' wrong
    beliefs, a restart's emptied mailbox among them, and no defect of the runtime; and the
    toolchain's own flush, which asks a port's queue every millisecond, keeps its poll, since
    the host answers a port's close alike whether its reader took the bytes or had gone.

12. **The milestone after this one, trimmed.** Decided with the user on 2026-10-08, the
    log's *The Milestones After 3.0, Weighed Again*: what `mvp3.1.md` and `mvp3.2.md` design
    is weighed against the principles, and most of MVP 3.2 is an operations layer and not the
    language's, a coordinator, a plan from the hashes, lockstep, `drain`, the cache and four
    commands, which a reader who knows Erlang expects outside the runtime (principle 1) and
    which add concepts a few nodes listed by hand do not need (principle 5). A new
    `mvp3.1.md` is written by copying: from the present `mvp3.1.md`, the spawn that ships code
    by its hash, the peer that loads what it lacks and refuses with `Refused`, `NotLoaded` by
    binding, the bare node and the shell as a node that spawns what is typed at it, and not the
    identity by shape across builds, the type-change bookkeeping or `ern diff`, which served the
    rollout; from `mvp3.2.md`, the planned stop, keys withdrawn, calls drained, kept states
    written and the close, the kept state read back through `migrate` at the next start, and
    the `Standing` library, and not the orchestration. The reasons come with them, from `code.md`
    and `deploy.md`, each paragraph dated where it was decided. The present two files are moved
    aside under names that say what they are, their status lines saying they were set aside on
    the date and why, and the directory's `README.md` says which is current. The number 3.1
    stays, since three refusals name it in their text. Then the plan's MVP 3.1 and 3.2 sections
    are rewritten from the new proposal, 3.2's gone, and the log says why, by the principles.
    Nothing of MVP 3.0 changes but the two refusals that name MVP 3.2, `drain` and
    `coordinator`, which become plain unknown-field refusals with their rows gone from
    `docs/development.md`'s table, and `mvp3.0.md`'s status line, which names what 3.2 would
    have changed. §6.10's code replacement stays as it is, a message that carries the new loop;
    the new proposal says that code travelling with a spawn gives it its half across nodes, a
    shell on one node shipping a new loop to a service on another and upgrading it in place,
    its state kept, which under MVP 3.0 works only for code the peer's build already has. Written as a proposal is written: read through with the user before a line
    reaches the plan, the log or the report (CLAUDE.md, *A design is discussed in its proposal
    until the user says it is ready*). Done 2026-10-09: `mvp3.1.md` was written on 2026-10-08
    and split on 2026-10-09 into identity, `mvp3.1.md`, and code with a spawn, `mvp3.2.md`,
    which stands on it, so the number 3.2 names a milestone of the language's after all; both
    were read through with the user, their status lines and the directory's `README.md` say
    so, and the two sections below are written from them (the log's *The Plan Rewritten from
    the Split Proposals*). The refusals of `drain` and `coordinator` went with the set-aside,
    and `mvp3.0.md`'s status line names both milestones.

13. **What MVP 3.0 changed, read.** Decided with the user on 2026-10-08, the log's *MVP 3.0
    Read Without a Release*: no release follows the milestone, and four of
    [`release_review.md`](release_review.md)'s readers, run as [`full_review.md`](full_review.md)
    runs them with its briefs, read what it changed. The report's reader, K and P as one, on the
    most advanced model, over §3.11, §8.3, §8.7, §6.10's part for a peer, Appendix C, E.27, G.4
    to G.6 and §11's node jobs; the argument's reader over `soundness.md`'s section 7; the code's
    reader, C, E and S as one, over what changed in `erl/`, `stdlib/` and `libs/` since
    `v0.3.1`, which a review run that reads only code may be where it can be given that range;
    and the guide's reader, on the model below, over chapter 8. The findings go to
    `findings.md` and are decided as a review's are. The principles review runs before MVP 3.1
    where its proposal adds to the type system, and reads peers, which are built. Done 2026-10-09:
    the report's, the argument's and the guide's readers ran on 2026-10-08, and the code's on
    2026-10-09 over what changed since `v0.3.1`, in two parts, C over `erl/` and `test/` and E
    and S as one over `stdlib/`, `libs/`, `shell/` and the node's code, the range chosen since
    the full review had read the code whole on 2026-10-05; every finding is decided in
    `findings.md`, the shape of each fix in its line (the log's *MVP 3.0's Findings Decided*).
    One finding is MVP 3.1's item 1, P1, a function value at `Peer.spawn`; three are dropped;
    the rest are item 14's.

14. **The findings worked, and the milestone closed.** The `cheap` lines of `findings.md`, each
    fixed as its line says, by area: the soundness argument's section 7 and 8, A1 to A10, with
    the shell's refusal of a key at a session type naming MVP 3.1 and the checker's `Never` for
    a free mailbox type at `Peer.spawn`; the report's sentences, P2, P4, P7 to P9 and K1 to
    K23, `Peer.nodes` renamed `Peer.peers` and `Ets.Table` gone from §3.11 among them, each a
    report edit first with its revision date; the node's defects, K2, K3 and K11, each with a
    test; `libs/json`'s K21; the guide's U1 to U18; and the code readers' lines. Then
    `docs/findings.md` goes, as `full_review.md` says, every line done, dropped or standing in
    MVP 3.1's item 1; the milestone's paragraph is written under *Done*; and `mvp3.0.md`'s
    status line says what the findings changed. A fix whose shape its line names is built as it
    stands; one that turns out to need a decision stops and asks. Done 2026-10-09, in two
    builds and a discussion of every line that was not a plain fix (the log's *MVP 3.0's
    Findings Decided*): 87 fixed, each with its test where it was a defect, four dropped, one
    MVP 3.1's; what the discussion changed is in the log's entry, a listed key bound to its own
    node name by the host's own check among it, and `findings.md` is gone.

Decisions the proposal leaves as they are, named here so that none is open: a key's name is
the program's, and two peers offering one key by mistake are told apart by nothing but the
order of the finder's list (its section 5, point 4); a connected peer may do anything on this
carrier, and no right is narrowed but the planned stop, which MVP 3.2 gives to peers marked
`coordinator`; and what other systems teach beyond the carrier and the address rule is
`nodes.md`'s and `other_systems.md`'s, and no item's.

---

## MVP 3.1 (code by its hash), about five weeks

Designed in [`mvp3.1.md`](../proposals/nodes_and_code/mvp3.1.md), read through with the user
on 2026-10-09; its reasons are [`code.md`](../proposals/nodes_and_code/code.md)'s and
[`nodes.md`](../proposals/nodes_and_code/nodes.md)'s sections 4, 6, 14, 15 and 17, what was
set aside `code.md`'s section 8 and the two proposals under
[`set_aside/`](../proposals/nodes_and_code/set_aside/), what other systems do
[`other_systems.md`](../proposals/nodes_and_code/other_systems.md)'s sections 6 and 7, and what
six programs showed of a change of code in place
[`experiments/code_update/`](../proposals/nodes_and_code/experiments/code_update/README.md).
The proposal is the specification and this list the order: each item builds its area as the
proposal's section 6 states it, whole. What the milestone gives: a hash for every definition,
the SHA-256 of its canonical form; nodes of different builds connected on one floor, a key
naming its type by hash and a spawn its function, so that a find answers `OtherType` and a
spawn `NotLoaded` exactly where the builds disagree; `NotLoaded` by definition and by binding,
which lifts MVP 3.0's rule by module; the shell's `:load` and `:reload` in a shell that is a
node, two versions of a type two types in one session; a program told of its termination,
`Os.terminating`, which writes what it keeps and answers before the end; the `Standing`
library; and E.22's refusal. No code crosses: that is MVP 3.2.

The items, in build order, each with the report's sentences first, its tests, and a commit.
The order is the dependency's: the report first; the canonical form and its tests before any
hash is computed; the code table before anything looks a hash up; the cookie opened to other
builds only once a key and a spawn carry hashes; the shell, which needs units side by side;
termination told, which needs nothing of the hashes and comes after them so that section 3's
deploy runs whole; then the library, and the tests over all of it.

Before item 1 the principles review runs, as [`principles_review.md`](principles_review.md) says,
over this proposal and over peers, which are built, on the user's word of 2026-10-09.

1. **The report and the soundness argument.** The sections the proposal's section 9 names:
   §8.7 for the floor, the cookie without the build, the key's hash beside its text and
   `OtherType` by hash, the spawn by hash with `NotLoaded` by definition and by binding, and the
   rule by module gone; §8.6 for the end that tells its subscribers and waits for their answers,
   under termination, the entry process's end and `Os.exit` alike, the interrupt and a second
   termination ending at once; Appendix E.23 for `Os.terminating`; §11.1 for what an `.erc`
   holds, the canonical forms and the hashes; §11.2 for the shell's load and reload by hash, a
   binding keeping the type it was checked under, the diagnostic that names the previous version,
   and the refusals of `:load` and `:reload` in a shell that is a node lifted; §7.4, §8.4 and
   §11.2, from which `Fault("its code was unloaded")` goes; Appendix E.22 for the refusal, `a
   process runs one child function`; Appendix G for `Standing`; Appendix F and `style.md`'s
   glossary for hash, identity, closure, unit, code table and subscriber. The decision P1 of
   the review of MVP 3.0 is built here: §3.11 admits `restarting` applied to a function it
   already admits as the spawned function, since the prelude states what its result captures,
   its two arguments; `Peer.spawn` stays a form, and a mark on function types that would make
   it an ordinary function is the log's *Later* (the log's *MVP 3.0's Findings Decided*,
   decided with the user on 2026-10-09). `soundness.md`'s section 7 is
   extended to the hashes between nodes of different builds and to identity by hash on one node
   across a load, and gains the end's paragraph. The log's entries, pointing at `code.md` and
   `nodes.md` for the argument. With them, as the build reaches each: `architecture.md` for the
   code table and the units; `memory.md` for the three tables the host never shrinks;
   `test/diagnostics.md` for the shell's diagnostic; `docs/development.md`'s table, from which
   the shell's three refusals, `:load`, `:reload` and a key at a session type, and the reload's forgotten binding go, and whose refusal of a node
   without a program names MVP 3.2.
2. **The canonical form, and the hash.** The form's document with the scheme's version, written
   before any hash is computed, literals and order fixed, and its test suite first: the same
   definition hashes the same across a rebuild; a renamed function keeps its dependents' hashes
   and a renamed constructor changes them; a moved definition in a group changes the group's;
   two bodies that differ only in local names or layout hash the same; a literal's encoding is
   fixed; two hashes for one definition and one hash for two are what it guards against. The
   compiler computes every definition's hash as section 6 states it: the typed tree after
   checking, locals numbered by position, every name resolved, types written out, a reference
   the hash of what it names, a foreign declaration its qualified name and type, a function's
   own name and positions out; a type's hash over its qualified name, its parameters by position
   and its constructors in order with their fields' names and types' hashes; a binding's
   identity its qualified name with its hash; a group one hash in source order with each
   member's position; a lambda's its enclosing definition's and its position; an applied type's
   its constructor's over its arguments'; a built-in type's its name; the scheme's version in
   every hash. The `.erc` carries the forms and the hashes; a library under `libs/` is hashed
   as a program's code is. What an abstract type's hash covers beyond its declaration is decided
   here and recorded in the form's document and the log.
3. **A node's code.** The code table from each hash to the unit and function that hold it; the
   build's units one per source module, made by the back end from the canonical forms through
   the table, a reference to a definition of the unit a local call and one to another unit's a
   call into it, functions named by their position so that a unit adds one atom, a trace and the
   shell showing a function by the build's name for its hash; nothing naming a unit; a build
   directory never changed under a running node; the node loading as `ern run` does; the three
   limits, 65,536 module names, 524,288 lambdas and 1,048,576 atoms, and the node's line on its
   standard error at four fifths of any, once.
4. **The cookie, the key and the spawn by hash.** The cookie as the digest of the protocol's
   version, `ern`'s version and OTP's major release, MVP 3.0's fingerprint gone, so that nodes
   of different builds connect; the key carrying its type's hash beside its text, a find
   comparing the hash and answering `OtherType` where the holder's differs; the spawn frame with
   the function's hash in place of its module and place, the peer looking the hash up in its
   table and answering `NotLoaded` naming the function where it lacks it, a binding's value by
   its identity and `NotLoaded` naming it where the peer did not run it, and `NotLoaded` for the
   module a foreign declaration names; a function that names no binding spawning where the rule
   by module refused it; nothing initialized because a peer asked; the site in the frame the
   spawner's words, shown and never compared. The Ernest tests of `Load` and `Balancer` return here from
   `test/ern_integration_tests.erl` to their modules, where a `Test.Case` binding kept their
   functions off a peer under the rule by module (`language_feedback.md`'s entry 95).
5. **The shell.** `:load` and `:reload` in a shell that is a node, and in any: a load adding
   hashes and moving the session's names to them; what a load brings to a node that already
   holds a unit of the module's name becoming a unit of its own, counted against item 3's limits,
   so that no unit takes a second version and §11.2's fault goes; a type in the session its hash,
   a binding made before a load keeping the type it was checked under, a message of one version
   to an address of the other a type error whose diagnostic says which is of the previous
   version; a previous version's process running on, reachable through its version's addresses
   alone, its key offered again only once it has ended; a load evaluating the closure's bindings
   in a fresh process at `Never` while the session waits; a function typed at the shell with a
   hash as any definition has, `NotLoaded` on every peer until MVP 3.2; the two gaps the
   experiments of 2026-10-07 found closed, a function of a previous version held in a process's
   state and a binding of a previous version forgotten (the log's *A Binding of a Previous
   Version Is Forgotten*).
6. **Termination told.** `Os.terminating(wrap)`, kept as a subscription to faults is, one per
   process, the latest, ending with its process; at the end, by termination, the entry process's
   end or `Os.exit`, `wrap(reply)` delivered to every subscriber, each delivery a process of its
   own as a monitor's is, the subscriber watched as a callee is; the end going on, MVP 3.0's in
   order, once every reply is answered or its subscriber has ended; every other process running
   meanwhile, and a peer finding, calling and sending to the node; a subscription made during the
   end told at once; a subscriber that faults while it writes reported; the interrupt and a
   second termination ending at once; a program that is no node, a test under `ern test` and the
   shell told the same way; no bound of the runtime's own on the wait.
7. **`Standing`, and the refusal.** The library under `libs/`: `Standing.start(key, ms)`, a
   process with the mailbox `Message(m) | Went(Down)` and the caller given `via` of it with
   `Message`, finding the key within `ms`, holding the address, monitoring the service and
   forwarding each message, finding again at `Went` with `ms` between failed finds, dropping a
   send while the service is away, a call through it answering `None` at its own time, and ending
   at its caller's `Down`. E.22's refusal: `Supervisor.child`'s function run inside a process
   that is already a child faults with `Fault("a process runs one child function")`.
8. **The tests, the measurements and the guide.** The proposal's section 8 whole, on nodes of
   two builds on one machine as MVP 3.0's tests run them: two builds connect, a find answers
   `OtherType` where the key's type differs and an address where it does not, a spawn of a
   function the peer lacks answers `NotLoaded` naming it and one of a function it has runs,
   `NotLoaded` for a binding and for a foreign declaration, a function naming no binding spawns
   where the rule by module refused it; the shell's binding of a previous version refuses the new
   version's message and takes one of its own, and the previous version's service runs on through
   two further reloads; a session that loads many units says so at four fifths of a limit, once,
   measured; the end's cases, a subscriber told at termination, at the entry process's end and at
   `Os.exit`, the program ending after its answer and not before, a subscriber that ended or
   faults holding nothing up, a second termination and the interrupt ending at once, a
   subscription made during the end told at once, a program that is no node, a test and the shell
   told the same way, a peer finding and calling a node whose subscribers are being told;
   `Standing`'s cases and E.22's refusal; a program's own test of two builds with the other
   started by `Os`. The measurements of section 7, and of what hashing costs a build and a load.
   `guide/deployment.md` begun, the deployment guide, which owns running nodes: a node's
   configuration directory whole, `ern reload` and `ern stop`, a deploy by stop all and start
   all with a service that keeps its state through `Os.terminating`, `Fs` and `Json`, and the
   service manager's patience set above what the program's writing takes; the language guide's
   chapter 8 pointing at it. `mvp3.1.md`'s status line.

---

## MVP 3.2 (code with a spawn), about four weeks

Designed in [`mvp3.2.md`](../proposals/nodes_and_code/mvp3.2.md), split from `mvp3.1.md` on
2026-10-09 and read through with the user the same day; its reasons are
[`code.md`](../proposals/nodes_and_code/code.md)'s sections 1, 3 and 5. It stands on MVP 3.1
and changes nothing of it. The proposal is the specification and this list the order. What the
milestone gives: a spawn whose function the peer lacks ships the lacking definitions of its
closure, as canonical forms, verified, compiled and loaded on the peer before the process
starts; the bare node, `ern run --config-dir dir` with no `.erc`, which runs what its peers spawn
on it; a function typed at the shell spawned on a peer with its code; a unit let go when no
process runs it and the node nears a limit; `Code`, with `load`, `hashes` and `running`; and
a table that holds no function.

The items, in build order, each with the report's sentences first, its tests, and a commit.
The order is the dependency's: the report first; the table rule, a refusal programs meet, before
anything is let go; the exchange before the unit it fills; the let-go once units arrive; then
what stands on the exchange, the bare node and the shell; `Code`, which reads the table; and the
tests and measurements over all of it.

1. **The report and the soundness argument.** §8.7 for the spawn that carries its code, the
   four frames, verification, quarantine and one load, `Refused` with the peer's text, a peer
   that may spawn on a node running what it sends, and the bare node; §11.2 for a bare node, for
   what a node lets go and for a function typed at the shell spawned with its code; §8.1, §8.5,
   §8.6 and §11.8 for a bare node's entry process, which runs no `main` and ends by termination;
   §6.10, whose cross-node sentence is completed by a spawn that carries its code; Appendix G.1
   for a table that holds no function; Appendix E's page for `Code`, with `Code.Hash`; Appendix F
   and `style.md`'s glossary for exchange and bare node; `soundness.md`'s section 7 extended to
   code that crosses. The log's entries, pointing at `code.md`. With them, as the build reaches
   each: `architecture.md` for the exchange's process and the let-go; `memory.md` for what a
   node holds of received code and when it lets go; `test/diagnostics.md` for the table's
   refusal; `docs/development.md`'s table, from which the refusal of a node without a program
   goes.
2. **The table rule in the checker.** `Ets.Table(k, v)` accepted only where `k` and `v` hold no
   function type, the first case of §3.11's bound check, one line and nothing at run time; its
   diagnostic, and the programs under `examples/` and `proposals/operations/` read for a table
   of functions, which keep their handlers in a process's state.
3. **The exchange.** The spawn frame MVP 3.1's; a peer that has the hash starting at once; a
   peer that lacks it asking for the closure's list, the sender listing the hashes the function
   reaches transitively, code and types, with the foreign declarations it names, the peer
   answering the hashes it lacks or `NotLoaded` for a foreign module or a binding, and the sender
   shipping the lacking definitions dependencies first, each code frame one definition's canonical
   form with its immediate references and never a compiled binary; the four frames beside MVP
   3.0's six; each frame verified against its hash as it arrives and held apart until the closure
   is complete, what the peer said it has pinned meanwhile; a faulty frame ending the connection;
   a closure the peer cannot compile or load failing the spawn with `Refused` and the peer's
   text; the exchange in a process of its own on each node, the gateways only passing its frames,
   the spawn's time covering it, two spawns waiting on one hash sharing one exchange.
4. **A unit on arrival, and the let-go.** The definitions that arrive in one exchange one unit,
   under a name from the node's pool, its functions named by position, each reference linked
   through the table before the unit is compiled by the build's back end from the same forms;
   the canonical form of a received definition, and of one typed at the shell, kept beside its
   compiled code and shipped onward as the node's own; loading by the host's `prepare_loading`
   and `atomic_load`, one batch per closure, no `-on_load`; the node's units off the code path;
   nothing on disk but the build directory, a node restarted sent the rest again. The let-go: a
   unit that arrived by an exchange or a load unloaded when no process executes it or holds a
   function of it, which `erlang:check_process_code` tells, when the node nears a limit of
   section 7, oldest first, until it is under; an idle unit staying until then; the build's own
   units never; a unit let go leaving the table and returning its name to the pool, and crossing
   again at the next spawn that needs it.
5. **The bare node, and the shell.** `ern run --config-dir dir` with no `.erc`: the runtime and
   the system processes, the entry process evaluating the standard library's bindings and
   waiting, the node listening and taking spawns, ending by termination alone, refused without
   `listen`, offering what the processes spawned on it offer; a balancer placing work on it and
   installing its measure there; a shell whose load path holds no program a bare node with a
   prompt. A function typed at the shell spawning on a peer with its code, where MVP 3.1 answered
   `NotLoaded`; the refusal of a node without a program lifted from `docs/development.md`'s
   table.
6. **`Code`.** `Code.load(path)`, `ern run`'s loading reached from Ernest, the module's canonical
   forms and its closure's read from the load path, verified against their hashes and made a unit
   as a load of the shell's is, counted against the limits, `Left` for a file that is no `.erc`
   of this `ern` or whose closure the load path lacks; `Code.hashes(path)`, the `.erc`'s table of
   names and hashes; `Code.running(f)`, the host's stack of each process mapped through the table
   to hashes, the processes with a frame of `f`'s hash or of a lambda written in `f`, typed
   `Address(m)` since every process running `f` has `f`'s mailbox type, a snapshot; `Code.Hash`;
   the page with its executed examples, section 3's upgrade tool among them under `examples/`.
7. **The tests, the measurements and the guide.** The proposal's section 8 whole, on nodes on
   one machine: a spawn of a function typed at a shell that is a node ships exactly the lacking
   definitions, verified and loaded at once, and the process runs; a spawn onto a bare node ships
   the program's closure once and nothing the second time, and the process offers a service the
   program finds; `NotLoaded` for a binding and for a foreign declaration; a faulty frame ends the
   connection; a late or broken exchange leaves nothing half-loaded; a fix crosses with its
   callers, which compile on the peer; a unit whose processes have ended stays until the node
   nears a limit, is then let go and crosses again at the next spawn that needs it, and one a
   process holds a function of stays; a table of a function type is refused; a node told to load
   many units says so at four fifths of a limit, once, measured; the shell fixes a service on a
   peer through `Upgrade`; `Code.load`, `Code.hashes` and `Code.running` as section 8 states them.
   The measurements of section 7, and of what a spawn that ships code costs, a bare node's first
   spawn and the callers of a fix above all, against the spawn's time. The deployment guide's
   chapter on a worker given its code and on a fix from the shell. `mvp3.2.md`'s status line, and
   `mvp3.1.md`'s for what this milestone changed in it.

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
