# Thinking for MVP 3.0 and 3.1

The thinking about peers, code distribution and code change, before MVP 3.0 decides any of it. Everything here is tentative: nothing is a decision, nothing is built, and nothing in the report changes because of it.

**A clean room.** This note stands on its own. It reads [`node_protocol.md`](node_protocol.md) and [`code_distribution.md`](code_distribution.md) as input, and their solutions are valuable, but it is not bound by them. Nothing flows from it into the report, the notes, the plan or the log until the thinking is covered. Then each decision goes to its owner, the report for a rule and the log for the why, and the design to the documents the thinking settles on: which those are, the two notes kept, merged, rewritten or joined by others, is itself part of what this note decides. The leading candidate: this note, its thinking settled and its tentative marks gone, becomes the one design note for nodes, code and code change, under a name of its own, `distribution.md` perhaps, and the two notes retire into it. Otherwise this note goes.

**What is carried in.** Sections 2 to 6 carry in the two notes' design as it stands, in this note's words and unweighed, so that the whole story is in one place; each says which sections it comes from. Until the thinking is covered the two notes own that design, and where a paragraph here and a note differ, the note says what was brought to the report. Section 11 carries in their open questions, each with its number there: *P* for the protocol note's and *D* for the distribution note's.

## 1. The aim

Unison names every definition by a hash of its content. Builds become incremental, two versions of a definition are two things and never conflict, a rename costs nothing, and code can move between machines because its identity is exact. Ernest takes that idea openly (the plan's MVP 3.1). The aim is to do what it promises soundly and realistically:

- **Sound.** What holds across nodes is argued, as [`soundness.md`](soundness.md) argues the core, before it is built (MVP 3.0's first item). Failure is part of the language: a peer's loss kills its processes with `Fault("peer lost")` and delivers their monitors (§10), a message is sent at most once, a call waits with a deadline, and a reply is checked.
- **Typed processes as the unit of distribution.** Shipping code is spawning a typed process on a peer, its protocol's hash checked.
- **Realistic.** Source stays text files under git, edited and reviewed as any code; the compiler computes the hashes. The runtime is the BEAM, with its decades of production behaviour, on machines a program's owner runs, listed in `ernest.conf` and authenticated by mutual TLS, with no platform to depend on. What hash modules cost on the BEAM, atoms and code memory, is measured before anything is promised.

Unison has shipped for years, and Ernest has a design, so "better" is true only when MVP 3.0 and 3.1 run and their numbers hold. Unison's codebase is a database rather than text files, and its distributed promise lives largely in its hosted cloud; what is said of its internals is said from the outside, and modestly.

## 2. Nodes and connections

From the protocol note, sections 1 to 3 and 9.

**No Erlang distribution.** Nodes talk over TLS connections of their own. The protocol adds nothing to the language: it carries §6's `spawn`, `spawnMonitored`, `send`, adapted addresses, `Reply`, `monitor` and `kill` between nodes, with `Down` and `Process`.

**A node's identity.** A node's `NodeId` is the SHA-256 hash of its TLS public key, and mutual TLS proves that a peer holds the key. It is stable across restarts. A new key is a new node, and every address to the old one is dead. Each start of a node draws a random 64-bit *incarnation*, which an address carries, so an address of an earlier start is dead.

**The peer table.** `ernest.conf` lists each peer's name, network address and public key (§11.3). Names are local to a node, and `NodeId`s global. There is no discovery: every node that must reach a new one is updated by hand.

**One connection for each pair of nodes.** It is opened by the first operation that needs it. Connections are not transitive: that A knows B and B knows C does not connect A to C. Where both nodes dial at once, the connection the lower `NodeId` opened is kept.

**The handshake.** Mutual TLS 1.3, then a hello: the `NodeId`, checked against the certificate; the incarnation; the protocol's version; and the versions of the IR and the hash scheme. A hello whose versions differ is refused, so a change of the IR or the hash scheme is a cutover of every node at once.

**The frames.** Each is length-prefixed and has a type: have, want and code, the exchange before a spawn (section 6); spawn and spawned; message; monitor, demonitor and down; kill; and heartbeat. `demonitor` serves the runtime alone, when a watcher dies.

**Loss.** A connection torn down is the loss of the peer: by the network, a full outgoing queue, a faulty frame, or a peer silent past the heartbeat's timeout. The node then treats every process of that incarnation as dead with `Fault("peer lost")` and delivers each monitor on one. It drops what was queued, drops the monitors the lost peer's processes held on its own, and ends the calls waiting on them. Loss is terminal (§10): the addresses held before it stay dead if the connection returns. A connection is opened again only on demand, with increasing delay between attempts, never in the background.

## 3. Addresses and what crosses

From the protocol note, sections 4, 5, 8 and 10.

**An address** names one process and is the permission to send to it (§6.5). On the wire it has four fields: the `NodeId` of its process's node; that node's incarnation; a `LocalId`, random and 128 bits long, so that no address is guessed; and the hash of the process's mailbox type. The receiver checks the type's hash against the process's mailbox type. A frame that fails the check tears the connection down, since an address is obtained only through typed operations and such a frame comes from a faulty peer.

**On the host.** A local address wraps a pid. When an address first leaves its node, its `LocalId` enters an export table, which a monitor clears when the process dies. A `send` to a remote address hands the message to that node's connection process, and there is no proxy process for each address. A `Process` crosses as its `NodeId`, incarnation and `LocalId`, so two copies of one remote address give equal processes, and one that went out and came back equals the original.

**Sending.** `send` never blocks. Each connection has an outgoing queue with a limit, and at the limit the connection is torn down, which is the loss of the peer. A message is never dropped alone, so what arrives from one process to another is in sending order and an unbroken prefix of what was sent. A message is dropped without notice when its connection is torn down with it still queued, when its process is dead, and when its node is absent from the peer table.

**A message fetches no code.** A spawn's exchange of code holds up only its spawner, and no other sender's frames wait behind it.

**Values** cross in the runtime's external term format, in the representations of §8.4's ABI, and no peer creates an atom on a node by sending data. An address crosses in its wire form. The function a spawn starts crosses as `{hash, env}`, and so does every function it reaches, through data and through captures. A foreign value, and a function anywhere else, faults the operation that would transport it (§3.8, §3.11). An adapted address crosses as its target's address and its function's `{hash, env}`. A message to it carries the value, unconverted, back to the node that made the address, which applies the function on delivery (§6.5).

## 4. Processes on a peer

From the protocol note, sections 6 and 7.

**A spawn.** `Peer.spawn(name, f)` and `Peer.spawnMonitored(name, f, wrap)` send a spawn frame: `f` as `{hash, env}`, a `LocalId` the spawner draws, and the spawn's site, which the peer reports in `Down`. For `spawnMonitored` the frame sets the monitor before the process runs. The caller waits: for a connection where there is none, for the handshake, for the exchange of code, and for the peer's answer once the process has started. An unknown or unreachable peer and a failed resolution fault the caller. `send` and `monitor` return at once while a connection opens.

**A monitor** works on a remote process as on a local one. Only an identifier the watcher's node draws crosses. That node keeps `wrap` and applies it as it delivers the `Down`. The watched process's node sends the `Down` when the process dies, and a monitor set on a dead process answers `Unknown` at once. When a watcher dies, its node removes its monitors on peers. For a lost peer's processes the watcher's node makes the `Down` itself, and a node whose program ends is lost to its peers (§8.6).

**`kill`** on a remote address sends a kill frame, and the process's monitors see `Killed`.

The plan's MVP 3.0 holds what is decided around these: `Peer.find`, which answers a `Peer.Failure`; placement by `Peer.nodes` and `Peer.runQueue`, with a balancer library over them; and a supervisor's children on its own node.

## 5. Code by its hash

From the distribution note, sections 1 to 4 and 11.

**What is hashed.** A definition's hash is the SHA-256 of its canonical form: the version of the format first; each external reference as its qualified name and the hash of what it names; local variables numbered by position; the hashes of the types it uses; named fields in declared order, and construction in source evaluation order (§8.7). Comments and layout are not hashed. Mutually recursive definitions are hashed as one group. The toolchain has no IR today: the emitter goes from the typed tree to Erlang's abstract format in one pass, and whether an IR is added or the typed tree made canonical is the first decision of the plan's MVP 3.1.

**Hash modules.** Each hash, and each group's, is compiled to a module of its own on the host, named `ern#` and the hash in base32. A hash module never changes.

**Types.** A type's hash covers its qualified name, its parameters by position, its constructors by name in declared order, each constructor's field names, and the hashes of its fields' types. An abstract type's hash also covers the types of its module's exported declarations. So renaming a type or a constructor, or moving a type to another module, is a change of protocol between processes. Two unrelated codebases with a type of one qualified name and definition share its hash.

**Names.** The `.ern` files are the source of truth for names. Each build resolves every name afresh and writes a table from name to hash, derived and never edited: no operation points a name at a hash, and no source names a hash. The build keeps every hash it has built in a store that only grows. A definition changes by editing and rebuilding. Its dependents get new hashes, and where a type changed they fail to compile until they are edited, so a build is never half migrated. At run time names serve entry points and debugging, and each node keeps a table from hash back to name. Names are local to a build, and nodes share hashes: nodes built from different commits cooperate through the hashes they share. Within one build a name has one meaning, and an old version still needed keeps a name of its own in the source.

**What the hashes leave out.** Three things are not hashed and must agree across nodes: the hash scheme, checked in the handshake; the compiler's back end, on every node, whose version keys the cached binaries; and what hashed code calls by name, the host's built-in functions and Ernest's runtime, pinned for each deployment with the OTP version. The prelude's types and the standard library are hashed as a program's code is. Their foreign declarations are excepted, and are each node's own (§8.7).

## 6. A node's code

From the distribution note, sections 5 to 7, 9, 10 and 14.

**One kind of node.** Each node has a cache of code keyed by hash: persistent, on disk and possibly filled at deployment, or volatile, in memory and empty at start. A program's code may be absent, and a node receives what it needs from its peers. The platform may not be absent: the host and its applications, Ernest's runtime and loader, and the compiler's back end. A diskless node can boot the platform over the network by the host's boot server, which has no TLS.

**The loader** stands beside the host's unchanged code server. It verifies first: the hash of incoming code is computed before anything else, and a mismatch rejects it. It compiles to a binary, deterministically, and caches the binary under the hash, the back end's version and OTP's. Every unit lists the hashes it references, so a fetched closure is known to be complete before any of it is loaded, and the closure is loaded at once, all of it or none. Nodes run in the host's embedded mode, which loads nothing from the code path on demand, so a missing module is an honest failure.

**Have and want.** Only a spawn on a peer ships code (§8.7). Before a spawn frame's payload is decoded, the sender lists the hashes, of code and types, that the function references transitively, its captures included. The receiver answers with those it lacks, and the sender sends them. The receiver verifies, compiles and loads them. Only then is the payload decoded, since a value cannot be read before its types are loaded, and the process starts. So the whole closure is present before anything runs. A failed exchange is a resolution failure, which faults the caller of the spawn.

**Trust.** The boundary is mutual TLS and nothing else: loading code from the network is remote execution by design. The receiver does not type-check incoming code again, and ill-typed code can fault at run time. The hash guarantees only that what is loaded is what was named. Any authenticated peer may load and run any code on any node it talks to, a known limit while one owner runs every node.

**Unloading.** A hash may be unloaded, and removed from the cache, when no name table on the node refers to it, no loaded hash depends on it, and the host's soft purge succeeds, which checks that no process runs its code or holds a function of it. It is tried after a configured idle time. The host's check sees the closures in each process's state, so nothing counts references.

**Atoms and lambdas.** Every module's name is an atom, and the host never collects atoms; its limit is about a million. The host's table of lambdas grows the same way, an entry for each lambda of each version loaded, up to 524,288, and unloading frees neither. So a long-lived node that receives many versions leaks both. The note's answer is that a node counts its atoms and, above a threshold, drains and restarts: every process on it dies, and every address to it is dead. In reserve it holds a hybrid: incoming code is interpreted first, and compiled to a hash module only when hot, so that cold code costs no atom.

**Risks.** Normalization, where an error costs most: two hashes for identical code or, worse, one hash for different code. And the time to compile when a node receives much code at once, typically as it starts.

## 7. Code change in running processes

**The objection.** A typed language, it is said, cannot have Erlang's code loading. Of the mechanism that is true. Erlang swaps a module under every process that runs it, a state takes a new shape in `code_change`, and messages of any shape keep arriving: the types of live data and of messages in flight change with nothing to check them against. Of what the mechanism is for it is not true. A running system upgraded without a stop, old and new code side by side, has a typed form, and §6.10 is a start of it: a process takes a message in its own type that carries the new loop, checked against its mailbox type before it arrives, and carries its state over by a typed function, Erlang's `code_change` checked. What a typed process cannot do is change its mailbox type in place, since its clients hold an address of the old type. In Erlang the same mismatch shows at run time, as messages nobody matches; Ernest would make a program say how old clients are served.

**Loading never disturbs running code.** A hash module never changes, so loading only adds. A process keeps the code it runs until its own upgrade case moves it, or until it ends, so loading new code is as safe as starting a process. BEAM's limit of two versions of a module, which kills a process still in the old one on a third load, does not arise. The cost moves to unloading: code stays loaded while any process, message or value refers to it, and memory no collection reclaims is a defect, so code is collected.

**An upgrade arrives as code does, by a spawn.** A function does not cross nodes in a message (§3.11). A process on another node is sent its upgrade by a process spawned on that node, to which the spawn gives the new function (§6.10).

**An upgrade in place is not a restart.** It is a tail call. Nothing the process asked the runtime for is cancelled, its alarms, monitors and subscriptions; its mailbox is kept; and the replies it holds go on in its state. A restart begins afresh (§6.9).

**The service that never ends.** A short-lived process ends on its old code, and its successor begins on the new. A long-serving service never ends, so it sees new code only through an upgrade case of its own; the runtime cannot migrate a state it cannot see, which lives in the loop's arguments. A process whose type has no upgrade case is replaced instead. A change of logic behind the same protocol, the common case, upgrades in place with no outage: the address stays, and what arrives meanwhile waits in the mailbox. A change of protocol needs an overlap: a new service under its own binding, the state handed over by message, and the old service a forwarder that translates old messages for the clients still holding its address, until it may retire, which the runtime cannot tell.

**A discipline around upgrade types.** An upgrade case each service writes by hand is forgotten, or written in a shape of its own, and then nothing upgrades services alike. A fixed shape lets a supervisor, the shell or a tool upgrade any service, as OTP's system messages reach every behaviour, but visibly, in each protocol's type (principle 3). One form is a library type over the language's own: a service's mailbox `Service(Msg, State)`, its messages and an `Upgrade` that carries the new loop as `(State) -> Unit`, which adds no concept (principle 5). A rule of the language that every service binding holds one would be stronger, and would bind services that never change.

**The state as a schema.** In that form, the state's type at the switch is the service's contract with its later versions. A new loop may hold any state it likes inside, and hands over a `State` at its next upgrade; a change of `State` itself is a change of protocol.

**A restart after an upgrade.** `restarting(limit, f)` and a supervisor's child hold `f` by its hash. A service upgraded and then faulting would restart into the `f` it was spawned with, and the fix would vanish at the first fault. Erlang's restart calls the start function by name and finds the new module. An upgrade would have to replace what a restart runs, so the discipline reaches `restarting` and `Supervisor`, not the loop alone.

**Clients of two versions.** Clients that share a protocol type share its hash, and the service sees one type from all of them, whatever their own code's version. A client built against another version of the protocol holds an address of another type, and an address carries its mailbox type's hash, so no message of one version is read as the other's. Nor does such a client reach the old service through its binding: its own binding is another binding, which starts a second service on the peer (section 8). The price is strictness. A type's hash covers what it refers to, so a change to a record deep in a protocol is a new protocol, and a change to a type many protocols share means replacing every service that carries it. So the discipline has a second half: a service's protocol types are small, stable and its own, not built from types shared across a program, and most changes are then changes of logic behind a stable protocol.

**Compatible evolution.** A second version that adds a constructor and is accepted where the first is, as protobuf's systems allow, would be an exception to "two versions of a type are two types". Principle 2 argues against it while a forwarder does the work; the inclination is to keep it out until a real service misses it.

## 8. Where the design and the thinking meet

What reading sections 2 to 6 beside section 7 shows. Each is a finding to weigh, not a verdict.

**A service across two builds.** §8.7 gives a top-level binding the hash of its definition, with everything the definition refers to. A service binding refers to the loop it spawns, so a fix to the loop gives the binding a new hash. §8.7 says what follows: a binding whose definition differs from the peer's by hash is another binding, and code of the new build that names the service starts a second one on the peer, running the new version, beside the first. That is versions side by side, as designed, and it is replacement with no handover: the new service starts empty, and the old one runs on for the clients of the old build, with nothing to end it. An upgrade in place needs the opposite, code of the new build reaching the service that runs. As the rules stand it cannot name it: its own binding is another binding, and no source names a hash. Two shapes of answer are in sight.

- *The binding's identity changes.* A service's identity across builds is its binding's qualified name and its protocol's hash, in place of its definition's hash, so that the new build's binding is the running service wherever the protocol is unchanged. That gives a binding an identity unlike every other definition's (principle 2), and lets new clients talk to old code until the upgrade lands, which nothing in their text shows (principle 3).
- *The deploy tool bridges the builds.* The language stays as it is, and the tool does what it alone can, since it holds both builds' name tables. It finds the running service with the old build's code. It sends the upgrade with the new build's, the address captured as a value. Then it has the node take the running process as the value of the new build's binding, so that later code of the new build finds it and starts no second one. That adoption is a new operation of the runtime, checked by the protocol's hash, and no change to the language.

**A changed protocol takes a new name.** A forwarder holds the old protocol and the new one in one build. A type's hash covers its qualified name, and within one build a name has one meaning. So the old type cannot be the one renamed: under another name it has another hash, and the old clients' addresses no longer fit it. The new protocol takes the new name, `CounterMsg2` beside `CounterMsg`, and the old type stays in the source unchanged, with every type it refers to, for as long as a forwarder serves it. A protocol whose service must outlive the change is then not edited: a new type is added beside it.

**A drain and restart ends the service that never ends.** An upgrade in place loads new hash modules: an atom, and its lambdas, for each definition whose hash changed, its dependents included. The node that upgrades without a stop is the one that never sheds them. The distribution note's drain and restart is then the very outage the upgrade was to avoid, on a schedule the leak sets, and the plan's MVP 3.1 already questions it by the rule that memory no collection reclaims is fixed at its cause. So the leak is the floor under the whole story. It wants a number first: how many definitions change hash in an ordinary deploy, and so how many deploys a node takes. Then its cause, in three directions, none tried against the host: whether a module's name must be the hash, or can be drawn from names reused once a module is unloaded, with the node's registry from hash to module; whether a closure in a hash module must be a lambda of the host's, since a function already crosses as `{hash, env}`; and the hybrid, which moves from a reserve toward the main road.

**An address across nodes lives as long as its connection.** Loss is terminal, and a silence past the heartbeat's timeout is a loss. A service that never ends still loses every client on another node at each loss, though both nodes run on: their addresses are dead and their calls ended, and they find the service again with `Peer.find`. So "without a dropped connection" is a promise about a node's own processes and the sockets they hold. A client on a peer is written to find its service again in any case.

**The platform is outside the hashes.** The deploy plan compares hashes, and the hash scheme, the back end, the runtime and OTP are not hashed: a hello whose versions differ is refused. So a new runtime, or a new OTP, is no upgrade in place. Each node restarts, every process on it ends, and state leaves the node first or is lost. The standard library is hashed as a program's code is, so a release that changes one of its functions changes the hash of everything that uses it, an upgrade in place of every such service at once; and a change to a library type that protocols carry is a change of each of those protocols.

**What holds old code.** Code is collected when nothing refers to it, and several things refer in ways the thinking added or the notes left open: the function `restarting`, or a supervisor's child, restarts into; the old loop a rollback keeps; a forwarder, which holds the old protocol's types for as long as it serves; a binding's evaluation on a node; and an adapted address, whose `{hash, env}` a peer may still send to after the node that made it would unload the code (*D14*). Each needs its answer before "old code is collected" is true.

**An upgrade case is a permission.** An address is the permission to send, so whoever holds a service's address may send its upgrade. A service would hand its clients an address of its requests alone, made with `via`, and keep the address of its whole protocol for what deploys it; `via` gives that with no new concept. On the wire an adapted address holds its target's address, so between nodes this narrows nothing that the trust in a peer has not already granted.

**Positions in the hash.** The distribution note asks whether source positions are hashed (*D11*), since a spawn's site names its line. The deploy plan weighs on it: with positions hashed, a line added above a definition changes its hash, and the plan reports every definition below an edit as changed.

**The order in a type's identity.** The plan's MVP 3.1 asks whether a type's identity holds the hash of its `compare`. The state handed over at an upgrade weighs on it. With it, a new `compare` is a new state type, a change of protocol, and declared. Without it, an ordered set carried through the upgrade is misordered, and nothing says so.

**MVP 3.0 alone upgrades nothing.** MVP 3.0 ships code between nodes of one build, and a peer of another build is refused. Until MVP 3.1 a deploy stops every node and starts every node, and everything in sections 7 to 10 waits for the hashes.

## 9. In practice

Most production systems, Erlang's among them, do not upgrade in place. They start the new version beside the old, move the traffic and drain the old, with the state kept outside the processes. An upgrade in place serves where reconnecting costs: a telephone call, a chat or game server holding many connections, a trading gateway. So the thinking is to make the ordinary path excellent and the upgrade in place safe.

- **A deploy planned from the hashes.** For each service binding, by its name in the two builds' name tables: its definition and its protocol unchanged is nothing to do; its definition changed behind the same protocol is an upgrade in place; its protocol changed is a replacement with an overlap. Erlang's `appup` files say this by hand. A tool that prints the plan before a deploy, and refuses what it cannot do safely, is worth more than a feature of the language.
- **A keeper.** A service built as a process that holds the state behind a small protocol that seldom changes, with the logic that changes often in processes cheap to replace, or in functions the keeper upgrades. Most deploys are then changes of logic. The guide would teach it as the ordinary way to build a service.
- **Rollback by default.** Where the new loop faults within a limit, the old loop resumes with the state it handed over.
- **A restart follows the upgrade**, as in section 7.
- **The code's hash in `Process.info`**, so that a deploy lists the processes still on old code.
- **A protocol change run by the tool.** The new service started, the state handed over, the old one a forwarder that counts the clients still using it, retired by the operator when the count is zero.
- **An upgrade tested.** Each build tested against the last release's: the old started, the plan applied, the state checked. A path that runs once a quarter decays unless a machine runs it on every commit.

The order the thinking suggests: the plan from the hashes and the code's hash in `Process.info`; then replacement with forwarders; then the upgrade in place with its rollback.

## 10. The story

Not "hot code loading, but typed": that promises the mechanism, the part that cannot be typed. The story is about deploys:

> Ernest knows exactly what changed between two builds, down to each process's protocol. Before a deploy, it tells you which services upgrade in place without a dropped connection, which need a replacement, and which are untouched. And the compiler guarantees that a client and a service of different protocol versions never exchange a message.

It is told only once it runs: a demo, a chat server holding many connections upgraded in place with none dropped, then a protocol change carried through a forwarder, with the plan printed before each step. Its limits are stated with it: a service cooperates; a protocol change needs an overlap; strict hashes make a shared type ripple; a new runtime or a new OTP restarts each node; and a client on another node finds its service again after a loss.

## 11. Open questions

The two notes' questions and this note's, by subject. *P n* is the protocol note's question n, and *D n* the distribution note's. All thirty-eight of theirs are here and still apply. Two apply only if the drain and restart stays (*D1*, *D2*), one is a question of this note's as well (*D7*), and two ask one thing (*P10*, *P20*). The plan's MVP 3.0 and 3.1 hold further ones the notes do not: when a module's top-level bindings run on a peer, where a node's configuration and its key are read, which tree the normalized definition is and what becomes of its effect variables, and what a foreign function's hash compares.

**Limits, and where they are set**

- The limit of a connection's outgoing queue. Proposed: 64 MB. (*P1*)
- How long a spawn waits for a connection and for the peer's answer, and what a timeout or a loss during the wait faults with. Proposed: 5 s for a first connection. (*P2*)
- The heartbeat's interval and timeout, when too short a timeout makes a brief interruption a loss, and a watcher that replaces a process still running then has two. Proposed: 5 s and 15 s. (*P3*)
- The backoff of reconnection. Proposed: doubling from 100 ms to 30 s. (*P4*)
- The largest frame. Proposed: a larger payload in chunks, never interleaved with another's, with heartbeats between them, so that a large frame causes no false loss. (*P14*)
- How long a hash is idle before it is unloaded and removed from the cache. (*D4*)
- Where these limits are set: constants of the runtime, documented with the wire format (§10), or keys of `ernest.conf`. (*P16*)

**Loss, and a peer that returns**

- How a node keeps a loss terminal when the lost incarnation returns, directly or in an address a third node hands over: by refusing it until the peer restarts, or by keeping only the old addresses dead, which the wire form cannot tell from new ones. (*P5*)
- Whether a watcher must tell a lost peer, whose process may live on, from a fault by more than the cause `peer lost`; `Reason` would gain `Unreachable`. §10 requires the reason to be distinguishable from every other, which a process calling `fault("peer lost")` breaks as the report stands, so the answer changes §10 or §9.3. The plan's MVP 3.0 holds it. (*P6*)
- What `site` has the `Down` a watcher's node makes on a loss, for a process it did not spawn: one the peer sends when the monitor is set, or the empty string, which §6.9 gives `Unknown` alone. (*P7*)
- What a monitor of an address whose node is absent from the peer table answers, `Unknown` at once or `Fault("peer lost")`, and what a `send` to one does, which the report does not say. (*P8*)
- What becomes of a process a peer starts after its spawner has faulted, the spawn having timed out. (*P18*)
- What a long-serving service's clients on other nodes do at a loss, and whether a library finds the service again for them (section 8).

**Calls, order and deadlock across nodes**

- How a `Reply` crosses, and how a caller learns that a callee on another node ended or restarted before it answered, since §6.9 tells no monitor of a restart. (*P10*, *P20*)
- Which process applies an adapted address's function on the node that made it, when a peer's message arrives for it: whether a sender's order survives it, and what a function that does not finish does to the connection it arrived on. (*P17*)
- Whether the unbroken prefix becomes a sentence of §6.4 before anything relies on it. The plan's MVP 3.0 holds it. (*P19*)
- How a node's deadlock check (§8.6) learns what peers can still deliver: that a process it spawned on a peer has ended, that no message is in flight to or from a peer, that no remote process holds one of its addresses or waits on one of its calls, and that no monitor waits on a remote process. By frames of their own, or does a node with a connected peer never declare a deadlock? (*P9*)

**The wire**

- How values in the external term format are decoded so that no peer creates an atom, when a safe decoding refuses an atom the receiver lacks, and a constructor the receiving code never names may be one. (*P11*)
- Who draws a spawned process's `LocalId`: the spawner, or the peer in its answer, since the spawner waits for that anyway. (*P12*)
- What identifies a function between two nodes of one build in MVP 3.0, before content addressing, and how the hello carries the build's identity, so that a peer of another build is refused with an error naming MVP 3.1. (*P15*)
- Which versions the hello carries and checks, the back end's, the runtime's and OTP's, and which differences between nodes are allowed. (*D15*)

**The hash**

- The full normalization rules, written apart before MVP 3.1: how references inside a group are numbered; how literals, closures and constructors are made canonical; and how type expressions such as `Msg(Int)`, function types and `with m` are hashed, since an address carries the hash of an instantiated mailbox type. (*D5*)
- When the format that is hashed is frozen: every change to it changes every hash, a cutover of every node. (*D3*)
- Whether a function's own name is in its hash; §8.7 names only its references'. (*D8*)
- Whether source positions are hashed. Unhashed, two definitions that differ only in a line share a hash, and a peer reports the wrong line. Hashed, the line and the function's own name are part of the identity, which settles *D8*, and an edit above a definition changes it (section 8). (*D11*)
- Whether a mutually recursive group is one module, each member's identity derived from the group's hash. (*D12*)
- Whether a project name at the top of every qualified name parts two unrelated codebases' types of one name and definition. (*D16*)
- Whether a type's identity holds the hash of its `compare`, which the plan's MVP 3.1 asks (section 8).

**Resolution and foreign code**

- Whether a node running hash modules keeps embedded mode, or finds a `foreign fn`'s Erlang module on the load path as §11.2 does. (*D9*)
- What makes a peer's foreign declaration compatible with the one a shipped function names: the same type and implementation, or the same type alone. (*D10*)
- How the exchange finds a system module the peer's runtime lacks and a foreign definition that differs, which §8.7 counts as resolution failures and the hashes leave out; and whether code that fails verification is a resolution failure or the loss of the peer. (*D13*)

**The memory of code**

- How code no process, message or value refers to is collected, and how the runtime learns that nothing does (section 8, *What holds old code*).
- How unloading keeps code present: a delete before a soft purge that fails leaves a hash with no current code, and an adapted address sent to a peer carries a `{hash, env}` whose code the making node may unload while the peer can still send to it. (*D14*)
- What hash modules cost on the host, atoms, lambda entries and code memory, measured: how many definitions change hash in an ordinary deploy, and how many deploys a node takes.
- Whether a module's name can be reused once its module is unloaded, and whether a closure in a hash module need be a lambda of the host's (section 8).
- At what count of atoms a node drains and restarts. Proposed: 80 % of the limit. It applies only if the drain and restart stays, which section 8 and the plan's MVP 3.1 question. (*D1*)
- How often a threshold restart may come before the hybrid is built, on the same condition. (*D2*)

**Booting a node, and its key**

- How a diskless node boots the platform, loader included, when the host's boot server has no TLS and checks only the IP address: from a signed boot image or local flash, or with the gap accepted on a trusted network. (*D6*)
- How a diskless node receives the same private key at every boot, without an unauthenticated channel that hands its identity to anyone. Decided with *D6*. (*P13*)
- Whether booting the platform over the network belongs in MVP 3 at all, apart from the volatile cache of a program's code, which needs no such boot.

**Code change**

- What a service is across two builds: its binding's definition, as §8.7 has it; its name and its protocol; or the running process the deploy tool has the node adopt (section 8).
- Whether a protocol must hold an upgrade case, or is encouraged to.
- What an upgrade in place may change: the state's type at the switch, the mailbox type.
- How a restart after an upgrade runs the new function, in `restarting` and in `Supervisor`.
- How a rollback is made, since a fault ends the run that held the state: what keeps the old loop and the state handed over, and for how long.
- How a protocol change reaches clients that hold the old address: a forwarder, `via`, a new binding; when a forwarder retires; and what a caller is told when the service behind a forwarder ends, since a request handed on is watched only where it was sent (§6.6).
- How the new protocol is named beside the old in one build (section 8).
- How a supervisor's tree is upgraded.
- Whether replacing a process with a handover of its state needs support from the language, is a library's work, or stays a convention of each program. (*D7*)
- Who may send an upgrade: whether a service hands out an address narrowed by `via` (section 8).
- How the platform itself is upgraded, node by node, and where state goes meanwhile (section 8).
- Compatible evolution: kept out, unless a real service misses it.
- How an upgrade is made a test.

**Left out, or placed**

- Each of the protocol note's deferred items, left out of MVP 3.0 with the principle that leaves it out and what would change it, or placed in a milestone: a separate connection for code, so that a spawn's large transfer delays no other frame; the network address as a hint in an address's wire form, to reach a peer absent from the table; discovery, by mDNS or gossip; and authorization beyond authentication. (*P21*)
- Each of the distribution note's: binaries sent between nodes of one back end and OTP version, if compile time proves a problem; permissions for each peer; and the hybrid. (*D17*)
