# Ernest: Node Protocol

Status: tentative design, 23 September 2026, brought to the report 28 September 2026. Target: MVP 3.0, but for what content addressing adds in MVP 3.1: a function as `{hash, env}`, the type hash in an address, the hello's IR and hash-scheme versions, and the have, want and code frames. How MVP 3.0 names a function between two nodes of one build is open question 15. Companion to [`code_distribution.md`](code_distribution.md), which designs what a spawn ships and how the peer resolves it.

> **Tentative.** A first pass, to be thought through again before it is built. The report owns what a program sees; a line marked *Changed* brings this note to it. The plan's MVP 3.0 lists what is still to decide. The rationale is the log's, in its entries from *Distribution* to *Code Travels Only With a Spawn* and in *Atoms, Counted*, *The Shell's Code Memory*, *MVP 3.0 Is Distributed Code and the Node Protocol*, *A Process's Addresses, Taught in Order* and *The Security Reader's Decisions*; the alternatives rejected, and the reasons this note gave, are its *What the Design Notes Argued*.

## 1. Scope

Ernest nodes talk over TLS connections of their own; Erlang distribution is not used. This note designs node identity, the address on the wire, and the connection and its frames.

## 2. What the protocol carries

The protocol adds nothing to the language. It carries §6's `spawn`, `spawnMonitored`, `send`, adapted addresses, `Reply`, `monitor` and `kill` between nodes, with `Down` (§9.3) and `Process` (Appendix E.21). `Peer.find`, `Peer.nodes` and `Peer.runQueue` are the plan's MVP 3.0.

*Changed:* the note's `Node`, `node(name)`, `self_node()`, `spawn_at(node, f)`, `MonitorRef`, `demonitor` and `Down = Exited | Crashed(Text) | NoProcess | Unreachable` are gone. The report places a process with `Where = Local | Peer(String)`, writes text as `String`, and has a `monitor` that answers nothing.

## 3. Nodes

### 3.1 Identity

A node's `NodeId` is the SHA-256 hash of its TLS public key, and mutual TLS proves that a peer holds it. The `NodeId` is stable across restarts. A new key is a new `NodeId`: every address to the old identity is dead, and every peer table that names it must change.

### 3.2 Incarnation

Each start of a node draws a random 64-bit incarnation. An address carries it (section 4.2), so an address of an earlier start is dead.

### 3.3 The peer table

`ernest.conf` lists each peer's name, network address and public key (§11.3, Appendix C), and the key gives its `NodeId`. Names are local and `NodeId`s global. There is no discovery: a diskless node receives its table at boot with the platform, and every node that must reach a new one is updated by hand.

## 4. Addresses

### 4.1 Meaning

An address names one process and is the permission to send to it (§6.5). It is dead once its process has died, once its node has restarted, and, on a node that has lost that peer, after the loss (section 9.4).

### 4.2 Wire form

An address on the wire has four fields:

1. the `NodeId` of the process's node,
2. that node's incarnation,
3. a `LocalId`, a random 128-bit value, so that addresses cannot be guessed,
4. the hash of the process's mailbox type.

The receiver checks the type hash against the mailbox type of the process, and a frame that fails the check tears the connection down, rather than being dropped alone.

### 4.3 On BEAM

A local address wraps a pid. When an address first leaves its node, its `LocalId` enters an export table to the pid, and a monitor removes the entry when the process dies. `send` to a remote address hands the message to the connection process for that node; there is no proxy process per address.

A `Process` crosses as its `NodeId`, incarnation and `LocalId`, so two copies of one remote address give equal processes (Appendix E.21). A `Process` that names one of the receiving node's own processes is decoded to its local handle, so one that went out and came back equals the original.

## 5. Sending

`send` never blocks (§6.2). Each connection has an outgoing queue with a configured limit. At the limit, open question 1's, the connection is torn down, which is the loss of the peer (section 9.4). A message is never dropped alone, so what arrives stays an unbroken prefix of what was sent (section 8).

A message is dropped without notice (§10) when its connection is torn down with it still queued, when its process is dead, and when its node is absent from the peer table.

## 6. Spawning on a peer

*Changed:* the note's `spawn_at` returned at once, held messages for a process not yet started, and gave a dead address on failure. §6.2 and §8.7 fault the caller instead, so the caller waits for the peer's answer.

`spawn(Peer(name), f)` and `spawnMonitored(Peer(name), f, wrap)` send a spawn frame (section 9.3) that holds `f` as `{hash, env}`, a `LocalId` the spawner draws, and the spawn's site (§6.9), which the peer reports in `Down`. For `spawnMonitored` the frame also sets the monitor, before the process runs. The caller waits for a connection where there is none, for the handshake, for the exchange of code (code distribution, section 7), and for the peer's answer once the process has started. An unknown or unreachable peer and a failed resolution fault the caller as §7.4 says. How long the spawn waits, and what a timeout or a loss during the wait faults with, is open question 2. `send` and `monitor` return at once while a connection opens (section 9.1).

## 7. Monitors and `kill`

*Changed:* the note stopped a monitor at a lost connection and let a new one see the process again when the connection returned, where §10 makes the loss terminal.

`monitor(a, wrap)` works on a remote address as on a local one (§6.9). Only an identifier that the watcher's node draws crosses. That node keeps `wrap` and applies it as it delivers the `Down`, as §6.9 says of every monitor, so a wrap that does not finish holds up no other delivery. The watched process's node sends the `Down` when the process dies, and a monitor set on a dead process answers `Unknown` at once. When a watcher dies, its node removes its monitors on peers, so that no peer keeps a monitor that nothing will read.

The processes of a lost peer are dead with `Fault("peer lost")` (§10), and the watcher's node makes their `Down` itself. A node whose program ends is lost to its peers (§8.6).

`kill(a)` on a remote address sends a kill frame, and the process dies as §6.9 says, its monitors seeing `Killed`. *Changed:* the note had no `kill`; §6.9 has one, and §8.6 lets it reach a peer.

## 8. Ordering

Messages from one process to another arrive in sending order (§6.4), and what arrives is an unbroken prefix of what was sent: a connection drops no message alone (section 5), and a loss ends every pair across it (§10).

One connection per pair of nodes carries the order. A message fetches no code. A spawn's exchange of code holds only its spawner, which waits for the answer; no other sender's frames are ordered against it, so the peer holds none of them back.

## 9. Connections

### 9.1 One per pair

Exactly one TLS connection joins a pair of nodes. It is opened by the first operation that needs it. Connections are not transitive: that A knows B and B knows C does not connect A to C. When both nodes dial at once, the connection opened by the lower `NodeId` is kept and the other closed.

### 9.2 Handshake

1. Mutual TLS 1.3.
2. An Ernest hello: the `NodeId`, checked against the certificate; the incarnation; the protocol version; the version of the IR and of the hash scheme.

A hello whose versions differ is refused, so a change of the IR or the hash scheme is a cutover of every node at once, with no rolling upgrade.

### 9.3 Frames

Frames are length-prefixed, each with a type.

| Frame | Purpose |
|---|---|
| have | the hashes, of code and types, that the next spawn references |
| want | the hashes the receiver lacks |
| code | the IR of the hashes wanted |
| spawn | start a process from `{hash, env}` under a `LocalId`, with its site and, for `spawnMonitored`, its monitor |
| spawned | the peer's answer to a spawn: started, or the cause of the resolution failure |
| message | a value for an address, with an adapted address's `{hash, env}` (section 10) |
| monitor | set a monitor under the watcher node's identifier |
| demonitor | remove a monitor whose watcher has died |
| down | the `Down` for a monitor |
| kill | kill a process (§6.9) |
| heartbeat | liveness |

A spawn frame follows its have frame (code distribution, section 7.2). *Changed:* `spawned` and `kill` are new, and `demonitor` serves the runtime alone, since the language has none.

### 9.4 Loss

A connection torn down is the loss of the peer: by the network, a full outgoing queue, a faulty frame, or a peer silent past the heartbeat timeout. The node then treats every process of that incarnation as dead with `Fault("peer lost")`, delivers each monitor on one, and drops what was queued (§10). It also drops the monitors that the lost peer's processes held on its own, and ends the pending calls of their callers, so that nothing of the lost peer stays behind. Loss is terminal: the addresses held before it stay dead if the connection returns. *Changed:* the note opened the connection again on the next `send`, and an address whose node had not restarted then worked again.

### 9.5 Reconnecting

After a loss, a connection is opened again only on demand, with increasing delay between attempts, and never in the background.

## 10. Encoding of values

*Changed:* the note had an encoding of its own, a constructor as its type hash and index. §8.4 carries values in the runtime's external term format, in the representations of its ABI.

No peer creates an atom on a receiving node by sending data (open question 11). An address crosses in its wire form (section 4.2), and a `Process` as section 4.3 says, in place of their local handles. The function a spawn starts crosses as `{hash, env}`, and so does every function it reaches, through data and through other functions' captures alike (§3.11; code distribution, section 7). A foreign value or a function that cannot cross, which that walk finds, faults the transporting operation (§3.8, §3.11, §7.4). An adapted address crosses as its target's address and its function's `{hash, env}`. A message to it carries the value, unconverted, and that `{hash, env}` to the node that made it, which applies the function on delivery (§6.5). No other function crosses (§3.11).

## 11. Deferred

Each is left out of MVP 3.0 or placed by open question 21.


- A separate connection for code, so that a spawn's large transfer delays no other frame.
- The network address as a hint in an address's wire form, to reach a peer absent from the table.
- Automatic discovery, by mDNS or gossip.
- Authorization beyond authentication (code distribution, section 9).

## 12. Open questions

1. What limit has a connection's outgoing queue? Proposed: 64 MB.
2. How long does a spawn wait for a connection and for the peer's answer before it faults? Proposed: 5 s for a first connection.
3. What heartbeat interval and timeout has each pair of nodes, when too short a timeout makes a brief interruption a loss, and a watcher that replaces a process still running then has two? Proposed: 5 s and 15 s.
4. What backoff does reconnection follow? Proposed: doubling from 100 ms to 30 s.
5. How does a node keep a loss terminal (§10) when the lost incarnation returns, directly or in an address a third node hands over: by refusing it until the peer restarts, or by keeping only the old addresses dead, which the wire form cannot tell from new ones?
6. Must a watcher tell a lost peer, whose process may live on, from a fault by more than the cause `peer lost`? The plan's MVP 3.0 names `Unreachable` for it, which §9.3's `Reason` would gain. §10 requires the reason to be distinguishable from every other, which a process calling `fault("peer lost")` breaks as the report stands, so the answer changes §10 or §9.3.
7. What `site` has the `Down` a watcher's node makes on a loss, for a process it did not spawn: one the peer sends when the monitor is set, or the empty string, as with `Unknown`, which §6.9 gives `Unknown` alone and would have to change?
8. What does a monitor of an address whose node is absent from the peer table answer: `Unknown` at once, or `Fault("peer lost")`? And what does a `send` to one do, which section 5 drops and the report does not say (§8.3, §10)? Both answers go to the report.
9. How does a node's deadlock check (§8.6) learn what peers can still deliver: that a process it spawned on a peer has ended, that no message is in flight to or from a peer, that no remote process holds one of its addresses or waits on one of its calls, and that no monitor waits on a remote process? By frames of their own, or does a node with a connected peer never declare a deadlock?
10. How does a `Reply` cross, and how does a caller learn that a callee on another node ended or restarted before it answered (§6.6)?
11. How are values in the external term format decoded so that no peer creates an atom? Decoding with `safe` refuses an atom the receiver lacks, and a constructor the receiving code never names may be one.
12. Who draws a spawned process's `LocalId`: the spawner, as now, or the peer in its answer, since the spawner waits for that anyway?
13. How does a diskless node receive the same private key at every boot, without an unauthenticated channel that hands its identity to anyone? Decided in MVP 3.0 together with code distribution's open question 6.
14. What is the largest frame? Proposed: a larger payload in chunks, never interleaved with another's, with heartbeats between them, so that a large frame causes no false loss.
15. What identifies a function between two nodes of one build in MVP 3.0, before content addressing, and how does the hello carry the build's identity, so that a peer of another build is refused with an error naming MVP 3.1?
16. Where are the limits of questions 1 to 4 and 14 set: constants of the runtime, documented with the wire format (§10), or keys of `ernest.conf` (§11.3, Appendix C)?
17. Which process applies an adapted address's function on the node that made it, when a message from a peer arrives for it (section 10): does a sender's order survive it (§6.4), and what does a function that does not finish do to the connection it arrived on?
18. What becomes of a process a peer starts after its spawner has faulted, the spawn having timed out?
19. Does section 8's unbroken prefix become a sentence of §6.4, as the plan's MVP 3.0 asks, before this note relies on it?
20. How is a remote callee's restart told to a caller waiting on a call across nodes, since §6.9 tells no monitor of a restart?
21. Is each item of section 11 left out of MVP 3.0, with the principle that leaves it out and what would change it, or placed in a milestone?
