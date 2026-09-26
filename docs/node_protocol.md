# Ernest: Node Protocol

Status: tentative design decisions, 23 September 2026. Target: MVP 3. Companion to `code_distribution.md`, which covers how code is identified, transferred and loaded.

> **Tentative.** Everything in this document is a first pass and must be thought through again before it is built. "Decision" here means the current best answer, not a commitment. The language surface in section 11 should be revisited before it enters `ernest_report.md`.

## 1. Purpose

Ernest nodes communicate over their own TLS connections. Erlang distribution is not used. This document specifies what a node is, what an address is, how processes are spawned and monitored across nodes, what ordering and delivery are guaranteed, and how connections behave.

## 2. Decisions in brief

- A node is identified by the hash of its TLS public key. An incarnation number, random at each start, distinguishes restarts.
- An address identifies one process instance and does not survive a restart of its node.
- `spawn_at` never fails at the call. The spawner creates the address itself. Spawned processes have no owner.
- There are monitors, not links. A monitor notice is an ordinary message in the watcher's own mailbox type.
- `send` never blocks. A full outgoing queue tears down the connection.
- Messages from one sender to one receiver arrive in order, and what arrives is an unbroken prefix of what was sent. Delivery is never guaranteed.
- There is exactly one TLS connection per pair of nodes, opened on demand.
- Values are encoded with Ernest's own encoding. Peers can never create atoms on a receiving node.
- Peers are configured statically. There is no automatic discovery.
- All new language operations are operations in `{Proc m}`, the single effect.

## 3. Nodes

### 3.1 Identity

A node's `NodeId` is the SHA-256 hash of its TLS public key. Mutual TLS already proves that the peer holds the key, so a node cannot pose as another. The `NodeId` is stable across restarts. How a node without persistent storage receives the same key at every boot is open question 9.

### 3.2 Incarnation

Each start of a node draws a random 64-bit incarnation number. A counter is not used, since it would require persistent state and diskless nodes have none. Addresses carry the incarnation (section 4), so messages to processes of an earlier incarnation are recognized as dead.

### 3.3 Names

Readable node names are local. Each node's configuration maps names to `NodeId` and network endpoint (host and port). This mirrors code: names are local, hashes are global.

### 3.4 Discovery

Discovery is static. Each node has a peer table in its configuration. A diskless node receives its peer table at boot, together with the platform.

An address naming a `NodeId` absent from the local peer table cannot be reached. Messages to it are dropped, and monitors on it report `Unreachable`.

### 3.5 Key change

A new key is a new `NodeId`. All addresses to the old identity become dead, and peer tables must be updated. Key rotation is therefore a planned change of identity, not routine maintenance.

## 4. Addresses

### 4.1 Meaning

An address identifies one specific process instance. It is a capability: only a holder of the address can send to the process. An address does not survive a restart of its node. Finding a process by name, on its own node or another, is open question 8 (section 14).

### 4.2 Wire form

An address on the wire has four fields:

1. `NodeId` of the node where the process lives.
2. Incarnation of that node.
3. `LocalId`: a random 128-bit value. Not a counter, so addresses cannot be guessed.
4. Type hash of the mailbox's message type.

On decoding, the receiver checks that the type hash matches the type its code expects. An address to a mailbox whose message type has changed can therefore not be passed to code that believes in the old type.

### 4.3 Implementation on BEAM

A local address wraps a BEAM pid. When an address leaves its node for the first time, it is entered into an export table from `LocalId` to pid. The entry is removed when the process dies, via a monitor.

`send` to a remote address hands the message to the connection process for that node. There is no proxy process per remote address.

At language level there is one type, `Address(m)`, and `send` behaves the same for local and remote addresses.

### 4.4 Equality

`Address` has no equality, as decided in the language. Two copies of the same remote address cannot be compared. Deduplication of addresses, for instance in a subscriber list, must use another key.

## 5. Sending and delivery

### 5.1 `send` never blocks

`send` never blocks, locally or across nodes. This deliberately differs from Erlang, which suspends the sender when the distribution port is busy (`busy_dist_port`).

### 5.2 Outgoing queue

Each connection has an outgoing queue with a configured limit. When the limit is reached:

1. The connection is torn down.
2. All monitors on processes of that node receive `Unreachable`.
3. Queued messages are dropped.

Dropping individual messages is not allowed, since it would leave gaps and break the ordering guarantee (section 8). Tearing down the connection keeps what was delivered an unbroken prefix of what was sent, and makes overload visible.

### 5.3 Back-pressure

Back-pressure remains a convention at user level: a credit protocol. The queue limit is a safety net for programs that do not use it.

### 5.4 Delivery

Delivery is never guaranteed. A message is dropped when:

- the connection is torn down with the message still queued (5.2),
- the destination process is dead or its node has restarted,
- the destination node is absent from the peer table (3.4),
- fetching the code or types the message needs fails (code distribution, section 7.2),
- a type hash in the message does not match the type the receiving code expects (sections 4.2 and 10).

The sender is not told of any of these; there is no error path back.

This is the semantics of Erlang's `send` to a node that has disappeared. Protocols that need confirmation build it with replies and timeouts.

Code fetching does not affect the sender: have/want is resolved on the receiving side before decoding, so `send` only enqueues.

## 6. Spawning on another node

### 6.1 Primitive

`spawn_at(node, f)` beside `spawn`, with the same type apart from the node argument. `f` is a function from `()` as usual. It travels as `{hash, env}` with have/want (code distribution, section 7).

### 6.2 The spawner creates the address

The spawner draws the `LocalId` itself and takes the target's incarnation from the connection handshake. The risk of collision with 128 random bits is negligible.

When a connection to the target already exists, `spawn_at` returns at once. When none exists, `spawn_at` waits for the connection to be established and the handshake to complete, within a configured time. This happens only at first contact, or after a teardown.

If the connection cannot be established, `spawn_at` returns a dead address whose incarnation no node has. A monitor on it reports `NoProcess`. `spawn_at` therefore never fails at the call.

### 6.3 Messages before start

The target's connection process holds messages to a `LocalId` whose spawn is in progress, and delivers them once the process has started. Order is kept, since the spawn and the messages travel over the same connection. The holding buffers have a limit and are freed if the spawn fails.

### 6.4 Failed spawn

If the spawn fails after it was sent (code fetch fails, the node goes away), the address is dead from the start. Held messages are dropped, and a monitor on the address reports `NoProcess` at once, or `Unreachable` if the connection was lost. This is the same as sending to a process that has already died.

### 6.5 No owner

A spawned process's lifetime is independent of its spawner, as in Erlang. A spawner that wants to know sets a monitor. Since a monitor on an address that is already dead reports at once, there is no race, and no separate `spawn_monitor` is needed.

## 7. Monitors

### 7.1 Primitive

`monitor(addr, f)` returns a `MonitorRef`. `f` maps the notice onto the watcher's own message type, for example `fn(r) = Msg.WorkerDown(r)`. This follows the language's use of `contramap` instead of subtyping. `f` stays local and is never sent. `demonitor(ref)` removes the monitor. The same primitives serve local and remote addresses.

### 7.2 Notice

A prelude type, `Down`, with four cases:

- `Exited`: the process ended normally.
- `Crashed(Text)`: the process crashed. The reason is text, not a typed term, so that it can cross node boundaries without agreement on types.
- `NoProcess`: there was no process at the address when the monitor was set (already dead, or spawn failed).
- `Unreachable`: the connection to the node was lost. The process may still be alive.

### 7.3 `Unreachable` is final

After `Unreachable` the monitor is removed and is not restored if the connection returns. A watcher that wants to continue sets a new monitor, which reports `NoProcess` if the node restarted in the meantime (the incarnation changed). This is Erlang's `noconnection` semantics.

The distinction between `Unreachable` and `Crashed` is essential. After `Unreachable` the process may live on, and a watcher that starts a replacement may end up with two.

### 7.4 Detection

The connection process sends heartbeats. Missing heartbeats within a configured time give `Unreachable` to all monitors on that node (section 9.5).

### 7.5 No links

Links kill processes with exit signals, an effect beside messages. That breaks the principle that messages are the only effect. Supervision is built from monitors. Monitors alone cannot stop a process that does not cooperate; see open question 11.

## 8. Ordering

### 8.1 Guarantee

Messages from one sending process to one receiving process are delivered in the order they were sent, and what is delivered is an unbroken prefix of what was sent.

Nothing more is guaranteed:

- no order between different senders,
- no order along different paths: if A sends to C directly and via B, C may receive them in either order.

### 8.2 Code fetching and order

With one connection per node pair the guarantee follows almost for free. The only threat is code fetching: if message 1 waits for have/want and message 2 does not, message 2 must not be delivered first.

The receiving side pauses delivery on the whole connection while a fetch is in progress. The connection keeps reading, and heartbeat, have, want and code frames are still processed during the pause, so the requested code can arrive on the same connection and a long fetch is not mistaken for a dead connection. No messages are delivered to processes until the fetch is complete.

### 8.3 Lifetime

The guarantee holds for the lifetime of a connection. When a connection is torn down and re-established, a new stream begins. What was queued before the teardown is gone (section 5.2).

## 9. Connections

### 9.1 One per node pair

Exactly one TLS connection per pair of nodes. The ordering guarantee rests on a single stream.

### 9.2 Establishing

Connections are opened on demand, the first time something is sent to or spawned on a node. Connections are not transitive: that A knows B and B knows C does not make A connect to C.

If both sides dial each other at the same time, the connection initiated by the node with the lower `NodeId` is kept and the other is closed. This comparison is internal to the runtime and not visible in the language.

### 9.3 Handshake

1. Mutual TLS 1.3.
2. Ernest hello, carrying:
   - `NodeId`, checked against the certificate,
   - incarnation,
   - protocol version,
   - IR and hash scheme version.

If the versions differ, the connection is refused, since identical code would otherwise get different hashes.

### 9.4 Frames

Frames are length-prefixed, each with a type:

| Frame | Purpose |
|---|---|
| have | hashes (code and types) the next message or spawn references |
| want | hashes the receiver lacks |
| code | IR for requested hashes |
| message | deliver a value to an address |
| spawn | start a process from `{hash, env}` under a given `LocalId` |
| monitor | set a monitor, identified by its `MonitorRef` |
| demonitor | remove a monitor by its `MonitorRef` |
| down | a `Down` notice for a `MonitorRef` |
| heartbeat | liveness |

Every message and spawn frame is preceded by a have frame. Its payload is decoded only when the resulting want is satisfied.

Frame size and chunking are open question 10.

### 9.5 Heartbeats

Interval and timeout are configured per node pair. The timeout trades false alarms against delay of detection. Too short gives `Unreachable` on brief network interruptions, and duplicate processes if watchers start replacements. Too long gives late detection. No single value is right everywhere.

### 9.6 Reconnecting

After a teardown, a connection is re-established on the next `send` or `spawn_at` to that node, with increasing delay between attempts. There is no reconnection in the background.

## 10. Encoding of values

Ernest uses its own encoding, not `term_to_binary`:

- Constructors are encoded as (type hash, constructor index), never as atoms. A peer can then never create atoms on a receiver merely by sending data, which would be a second atom leak beside module names.
- Addresses have the wire form of section 4.2.
- Functions and closures travel as `{hash, env}` (code distribution, section 7.1).
- `Node` and `MonitorRef`: open question 12.

## 11. Language surface

Additions to the prelude. All operations are in `{Proc m}`. Signatures in the notation of the language report are written when these enter `ernest_report.md`.

| Name | Kind | Meaning |
|---|---|---|
| `Node` | opaque type | a node in the local peer table, or the node itself |
| `node(name)` | operation | the node with that name in the peer table, as `Optional(Node)` |
| `self_node()` | operation | the node the process runs on |
| `spawn_at(node, f)` | operation | spawn on another node (section 6) |
| `MonitorRef` | opaque type | identifies one monitor |
| `monitor(addr, f)` | operation | set a monitor, returning a `MonitorRef` (section 7) |
| `demonitor(ref)` | operation | remove a monitor |
| `Down` | type | `Exited`, `Crashed(Text)`, `NoProcess`, `Unreachable` |

## 12. Alternatives considered and rejected

- **Addresses that survive restarts.** A process that has died is dead; a new process under the same name is another process, possibly with other state. Durable identity belongs to a registry.
- **Counter as `LocalId`.** Simpler, but addresses could be guessed.
- **Proxy process per remote address.** Costly, and gives nothing the connection process does not.
- **Address without type hash.** An address to a mailbox with a changed type could be passed to code expecting the old type.
- **Synchronous spawn** with the target creating the address. Blocks the spawner on every spawn and gives two failure paths instead of one.
- **`spawn_at` failing at the call** when no connection can be made. Would add a second failure path beside the monitor.
- **No spawn primitive**, only a spawner process on each node. Works, but is boilerplate everyone would write the same way.
- **Links, and ownership** where a process dies with its spawner. Exit signals are an effect beside messages (7.5).
- **Monitors that survive reconnection.** Would require nodes to resynchronize monitor state after an interruption, and the watcher still could not know what happened during it.
- **Merging `Unreachable` and `Crashed`.** Loses the most important distinction (7.3).
- **Typed crash reason.** Would require the watcher to know the watched process's error type.
- **Blocking `send`** as in Erlang. A hidden block that makes `send` something other than it appears to be.
- **Unbounded outgoing queue.** Memory runs out slowly and without warning.
- **Dropping individual messages on overflow.** Breaks the ordering guarantee.
- **Causal ordering across nodes.** Requires vector clocks or similar on every message; Erlang has done without.
- **No ordering guarantee.** Request and reply, spawn followed by messages, and the credit protocol all depend on per-pair order.
- **`name@host` as node identity.** Independent of the key, can be confused, and breaks when the host changes address.
- **Random UUID per node.** Must be tied to a key to be safe anyway, so the key may as well be the identity.
- **Multiple connections per node pair.** Breaks the single stream that ordering rests on.
- **`term_to_binary` with `safe`.** `safe` refuses unknown atoms, and the code defining the constructors may not yet be fetched when a message arrives.

## 13. Deferred

- **Pause per receiving process** instead of per connection (8.2). Correct in the long run: a slow fetch for one process would not stall the others. Requires a queue per process on the receiving side.
- **Separate connection for code transfer.** Would remove head-of-line blocking from large transfers, but makes the pause in 8.2 harder to reason about. Natural together with pause per process.
- **Network endpoint as a hint in an address's wire form.** Would let a node reach a peer absent from its table. Key verification would prevent misdirection. Grows the address and the hint goes stale.
- **Automatic discovery** (mDNS, gossip). Unnecessary while one owner controls all nodes.
- **Authorization beyond authentication** (code distribution, section 9).

## 14. Open questions

Configuration and measurement:

1. Limit of the outgoing queue per connection.
2. Limit of the holding buffers for spawns in progress.
3. Time `spawn_at` waits for a first connection.
4. Heartbeat interval and timeout, per node pair.
5. Backoff schedule for reconnection.

Whether to set starting values now, marked as adjustable after measurement in MVP 3, so that the specification is complete. Proposed starting values: queue limit 64 MB per connection; heartbeat every 5 s with timeout 15 s (Erlang's equivalent is 60 s, judged too slow for `Unreachable`); `spawn_at` waits 5 s; reconnection delay doubling from 100 ms up to 30 s. No proposal yet for the holding buffers.

Language:

6. The name of the text type in `Crashed(Text)`, to agree with the prelude in `ernest_report.md`.
7. Whether `Node` has equality. Proposed: yes. Unlike `Address`, a node is not a capability, and code needs to ask whether something is its own node (`node == self_node()`). Equality gives no universal ordering, only equality for this type.
8. A name registry in the first version. Without one, the only ways to obtain an address are to spawn the process or to be sent the address. A long-running service started by another node's own `main` is then unreachable: nobody can hand over its address, `spawn_at` only creates new processes, and a spawned helper has no way to find the service locally. Proposed: a minimal registry, a local table per node from name to address, with a remote lookup returning `Optional(Address(m))` checked against the type hash. Registration would be a `{Proc m}` operation, and the lookup would need its own frame pair. Durable identity across restarts would still not follow: a name points to an address, and the address dies with its node's incarnation. Decided 2026-09-26 in the plan's MVP 2.65 step 5: no registry; a service is a top-level binding, and a spawned helper finds it by reading the binding on its node, which MVP 3.0's `Peer.find` does in one call.
11. A way to stop a process that does not cooperate. Rejecting links (7.5) leaves no way to terminate a process stuck in an endless loop or one that never reads its mailbox. A supervisor can see such a process die but cannot make it die, and "let it crash" needs both. Possible answer: a single `kill(addr)` as a runtime operation, kept out of the message model, with the killed process's monitors reporting `Crashed`. This is a language question more than a protocol question, and it should be settled in `ernest_report.md`. If `kill` works across nodes, it also needs a frame.

Platform and wire format:

9. Key provisioning for diskless nodes. The `NodeId` is the hash of the TLS key and must be stable across restarts, so a node without persistent storage must be given the same private key at every boot. If the key arrives over an unauthenticated boot channel, anyone on the network can take the node's identity. Depends on how the platform is booted (code distribution, open question 6).
10. Maximum frame size. On the sending side, a single large message or code frame blocks everything queued behind it, heartbeats included, and a slow link can then produce a false `Unreachable`. Proposed: a maximum frame size, large payloads split into chunks, and heartbeats allowed between chunks. Chunks of different payloads are not interleaved, so ordering (section 8) is unaffected.
12. Encoding of `Node` and `MonitorRef` (section 11). Proposed: `Node` travels as its `NodeId`; the receiver can decode it even when the node is absent from its peer table, and simply cannot reach it (3.4). `MonitorRef` means something only on the node that created it. Proposed: it cannot be sent at all, enforced by the type checker, rather than travelling and becoming inert, since a value known to be useless should not be sent and then fail silently. The rule for which types can cross nodes belongs in `ernest_report.md`.

## 15. Risks

1. **Head-of-line blocking** at start-up, when many fetches happen and all traffic on a connection stands still during each. The reason pause per process remains the next step.
2. **Heartbeat timeout** set wrong, giving either duplicate processes after false `Unreachable` or late detection.
3. **Own encoding** is more code to write and test than `term_to_binary`, and another place where type hashes must agree. Faults show as decoding errors in live traffic.
4. **Export table** grows with the number of live processes whose addresses have left the node. One entry per process, not per send, but long-lived processes keep theirs.
5. **Static configuration** requires every node that should reach a new node to be updated. Acceptable with one owner and few nodes; the first limit that will be felt if the system grows.
6. **Peer-chosen `LocalId`** in spawns. Covered by the trust model, but a faulty peer could in principle occupy identifiers.
7. **`spawn_at` at first contact** waits for a connection. The only place a process operation can stall on the network; bounded by the configured time.
8. **Changing the IR or hash scheme version is a cluster-wide cutover.** The handshake refuses connections across such a change (9.3), so a rolling upgrade is impossible: nodes on the old and new versions cannot talk at all while the upgrade is in progress. One more reason to freeze the IR format early (code distribution, open question 3).
