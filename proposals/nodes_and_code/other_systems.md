# Ernest: Other Systems

How other systems treat nodes, the loss of one, and what passes between them: what readers found, set beside what [`mvp3.0.md`](mvp3.0.md) proposes. A finding is something to weigh. None is a decision.

Each reader was a research session of its own, which fetched the sources it names on 6 October 2026. A quotation is as the reader reported it, and was not fetched again for this document. Where a reader could not verify something, it is marked *unverified*. A finding is named by its reader's letter and a number: *O* for Orleans, *A* for Akka, *E* for the Erlang ecosystem, *T* for the typed and capability systems.

## 1. What recurs

What more than one reader said, or what bears on a choice the proposal made. Each names the place in the proposal it bears on.

1. **Finding a failure takes us three to five times longer.** Akka finds one in seconds, Orleans in about 15 seconds, the proposal in 45 to 75, and as a constant. Akka's speed costs it false alarms, which its documentation admits (*A9*, *O7*). Bears on section 6, *The detector*, and section 7.
2. **A full queue does happen.** Akka's send queue overflows in practice under bursts, and Akka then drops the one message. The proposal ends every conversation between the two nodes (*A1*). Erlang's own answer, a sender made to wait, is one its documentation says "cannot be fixed", and its way out is memory without a bound (*E4*). Bears on section 5, point 4.
3. **One connection for everything.** Akka gives each peer three streams so that a large message cannot block an urgent one (*A2*). Partisan, Riak, RabbitMQ and gen_rpc each ended with several connections or channels to a peer (*E3*). Bears on section 5, point 5.
4. **A call's failure has two meanings.** A request that was never sent may be sent again, and one that was sent has an unknown outcome. The proposal answers `None` for both (*O1*). Bears on section 5, point 2.
5. **What must exist once needs something outside the nodes.** Each node decides alone, so two can disagree about a third; a lease works only through a store all of them consult, with a token that only grows (*O3*, *A5*). Bears on section 5, point 1.
6. **Finding a service matters more than spawning on a peer.** Akka's typed interface has no remote spawn at all and discourages it; a "find it again" helper is the first library anyone writes (*A4*, *O4*). The proposal now finds a service by a typed key that its node offers, as Akka, Swift and Gleam do, and ships no function for it. Bears on section 9, point 2, and section 10, the standing address.
7. **One side may be unable to dial.** Behind address translation or in containers, A reaches B and B does not reach A (*A3*). The proposal has one connection for both ways, opened by the side that can dial, and states what the other side loses after a loss (section 4, *An experiment*). Bears on section 5, point 13.
8. **Bytes prove the link and not the node.** A node that is starved and still connected looks alive (*O6*). Bears on section 6, *The detector*.
9. **A broken reference stays broken in the capability systems,** wherever it goes, and a new one is made from a durable reference (*T1*). The proposal first had an address die with its connection, and now has it outlive a loss, as Erlang, Akka and Swift have it at an ordinary loss. Bears on section 4, claim 7, and section 5, point 10.
10. **How an address is obtained again is a design of its own** in every system read: a durable reference in the capability systems, a typed key in Swift and Akka, a named service in Unison (*T3*). Bears on section 9, point 2.
11. **An address also lets its holder kill.** The capability systems give a reference the right to send and nothing more (*T6*). The proposal keeps Erlang's rule, that the holder can kill, and says so among its limits. Bears on section 5, point 12.
12. **What Erlang's own distribution cannot give.** Three things are decided inside the host's runtime, where neither a layer above nor another carrier beneath reaches them: that a message's type is checked before it reaches a mailbox, that a peer's data creates no atom, and that a peer's rights are narrower than everything (*E1*). The reader counted a fourth, an address that stays dead after a reconnection, which the proposal no longer asks. The proposal now rides on the distribution all the same: it keeps the first by a gateway of its own, and gives up the other two. Bears on section 9, point 1.
13. **A protocol of our own costs about what the host's does over TLS,** where frames are sent several at a time. Sent one at a time, small messages were 11 to 15 times slower in a reader's own measurement (*E2*). Bears on section 9, point 5.
14. **The runtime must not also be a node of distributed Erlang.** One that is hands everything to whoever holds its cookie (*E6*). The proposal is now one by choice, with TLS and listed keys before the cookie, and says that a peer is trusted completely.
15. **Erlang's distribution can carry frames of our own, with what hurts in it turned off.** Tried on OTP 29: TLS with listed keys and no port-mapper daemon, no mesh, a sender that does not wait, both nodes told of a loss, a pid that reaches its process again after one, and monitors and one-shot replies across nodes (section 4, *An experiment*). What stays is that a connected node may do anything. Bears on section 9, point 1.

## 2. Orleans and its relatives

Orleans is Microsoft's system of *virtual actors*: an actor is named by a logical identity, and the runtime decides on which machine it lives.

### How Orleans does it

- **Membership.** Machines probe each other and write their verdicts to a table outside the cluster. "Every silo is monitored by 10 other silos", "Probes are sent every 10 seconds", "3 missed probes trigger a suspicion", "2 suspicions are required to declare a silo dead", and "typical failure detection time is approximately 15 seconds" [O-1]. The agreement is borrowed: "this protocol outsources the hard problem of distributed consensus to the cloud" [O-1].
- **A machine declared dead is killed.** "Once a silo is declared dead in the table, everyone considers it dead, even if it isn't truly dead ... Once the silo learns it's dead (by reading its new status from the table), it terminates its process" [O-1].
- **Identity is logical.** A directory maps an actor's identity to a machine. When that machine dies, "you'll receive an exception ... The grain that failed with the silo will get automatically re-instantiated upon the next call to it" [O-4]. What the actor had not saved is gone: "Orleans does not impose a checkpointing strategy" [O-3].
- **One instance, eventually.** "In failure-free times, Orleans guarantees that an actor only has a single activation. However, when failures occur, this is only guaranteed eventually." [O-3]
- **Delivery.** "Orleans messaging delivery guarantees are at-most-once by default." [O-7] A request times out after 30 seconds by default [O-8]. With retries a message can arrive twice, and nothing removes the duplicate: "Orleans currently doesn't durably store which messages have already arrived ... (We believe this would be quite costly.)" [O-7]
- **Order.** Order for each pair of actors was built and then dropped: "The per-actor-pair state totals n² sequence numbers and queues. This is too much state to maintain efficiently." [O-3] Today "Message ordering was never guaranteed regardless of this attribute" [O-9].
- **Mixed builds.** Machines may run different builds, with numbered interfaces. "You should never change the signature of existing methods", and "Writing backward-compatible code can be hard and difficult to test" [O-13].
- **Placement** is automatic, since the indirection lets the runtime handle "actor placement and load balancing, deactivation of unused actors, and actor recovery after server failures, which are notoriously difficult for them to get right" [O-3].

### What it supports

- **`Unreachable`, and not dead.** Orleans kills a live machine to make its verdict true. The proposal says what is known.
- **Order for each sender and receiver.** Orleans dropped it for the state it cost for each pair of actors. The proposal's state is for each connection.
- **Telling the caller of a restart.** Orleans hides it, and the actor that returns lacks what it had not saved.
- **One build, for now.** Orleans' own guidelines show what mixed builds cost.
- **Agreement kept outside the core.** Orleans keeps it in a store outside too.
- **An address that names one process on one node.** The reader calls it practical and the older family. Orleans' authors state its cost: "As in Erlang, an actor's location is fixed at creation time, which prevents dynamic load balancing, actor migration, and automatic handling of machine failures" [O-3]. What people build on top is logical identity as a library.

### What it questions

- *O1.* **Split a call's failure.** "Never sent", which may be sent again, against "sent, outcome unknown".
- *O2.* **A convention for a request's identity,** since any second attempt after a reconnection can run twice.
- *O3.* **Two nodes can disagree about a third,** each deciding alone. A library for "exactly one" has to go through a store outside the nodes that orders every change, and the proposal should say so where it names a lease.
- *O4.* **A helper that reads the binding again after a loss** will be the first library, perhaps across a list of nodes. It is also where duplicates enter.
- *O5.* **Timers that survive a restart.** Orleans and both its relatives have them, since recovery needs something to wake the replacement.
- *O6.* **Bytes arriving find a dead link and not a starved node.** Orleans added checks of a node's own health because starved "slow nodes might otherwise incorrectly suspect healthy nodes" [O-1]. A time on a call covers a call; a monitor on a stuck node stays silent.
- *O7.* **Detection in about 15 seconds,** against the proposal's 45 to 75.

### Its relatives, and durable execution

- **Service Fabric's actors** live in parts of a replicated service, so the platform replicates their state. Its client tries again across failures, hence "Actors may receive duplicate messages from the same client" [O-18].
- **Dapr's actors** run beside the program, for any language, with a central service that decides placement. That this service uses Raft is *unverified*.
- **Temporal and Restate** record each step of a function and replay the record after a failure: "If your function crashes or fails, Restate replays the journal, skipping completed steps and resuming from exactly where it left off" [O-24]. The doubt survives at the edge, so "Temporal recommends that Activities be idempotent" [O-25]. Both need a central durable record, which the proposal declines. What carries over is smaller: a result that says "outcome unknown", and a request's identity as a convention.

### What the reader could not verify

The paper "Orleans: Cloud Computing for Everyone" was found and not read. Only two practitioners' accounts were found, [O-16] and [O-17], and no report of an incident. An older option for detecting deadlocks is *unverified*.

### Sources

- [O-1] https://learn.microsoft.com/en-us/dotnet/orleans/implementation/cluster-management
- [O-3] https://www.microsoft.com/en-us/research/wp-content/uploads/2016/02/Orleans-MSR-TR-2014-41.pdf
- [O-4] https://learn.microsoft.com/en-us/dotnet/orleans/resources/frequently-asked-questions
- [O-5] https://learn.microsoft.com/en-us/dotnet/orleans/host/grain-directory
- [O-7] https://learn.microsoft.com/en-us/dotnet/orleans/implementation/messaging-delivery-guarantees
- [O-8] https://raw.githubusercontent.com/dotnet/orleans/main/src/Orleans.Core/Configuration/Options/MessagingOptions.cs
- [O-9] https://raw.githubusercontent.com/dotnet/docs/main/docs/orleans/migration-guide.md
- [O-13] https://raw.githubusercontent.com/dotnet/docs/main/docs/orleans/grains/grain-versioning/backward-compatibility-guidelines.md
- [O-16] https://theburningmonk.com/2014/12/a-look-at-microsoft-orleans-through-erlang-tinted-glasses/
- [O-17] https://github.com/dotnet/orleans/discussions/8205
- [O-18] https://raw.githubusercontent.com/MicrosoftDocs/azure-compute-docs/main/articles/service-fabric/service-fabric-reliable-actors-introduction.md
- [O-24] https://docs.restate.dev/foundations/key-concepts.md
- [O-25] https://docs.temporal.io/activity-definition.md

## 3. Akka and Pekko

Akka is the best-known actor system on the Java runtime, and Pekko is its open fork. The quotations are from Pekko's documentation, which the reader checked against Akka's for the central pages.

### How Akka does it

- **Remoting is not meant to be used alone.** "you would usually not use the Remoting concepts directly, but instead use the more high-level Pekko Cluster utilities" [A-1].
- **Three streams to each peer:** one for the system's own messages, one for ordinary messages, one for large ones. The first exists so that "a large user message cannot block an urgent system message" [A-1].
- **A program's messages** are sent at most once and "will not be received out-of-order" for each pair [A-4]. They are lost when a connection breaks, when "filling up the outbound send queue", and "if serialization or deserialization of a message fails (only that message will be dropped)" [A-1]. The queue holds 3072: "Messages will be dropped if the queue becomes full" [A-2]. A hole inside a stream is silent.
- **The system's own messages,** a watch and its notice among them, "are delivered ... with 'exactly-once' guarantee by confirming each message and resending unconfirmed messages" [A-1].
- **The detector** adapts its patience to the heartbeats it has seen, which come every second. It allows a pause of 3 seconds within a cluster and 10 seconds for a watch outside one [A-2][A-5][A-8].
- **Unreachable, down, removed.** Unreachable "is not a separate member state but rather a flag", and can be withdrawn. Down is decided by a rule or an operator. A node that was downed "cannot join the cluster again ... the process has to be restarted" [A-7].
- **Quarantine.** "It is the specific incarnation (UID) that is quarantined. The only way to recover from this state is to restart one of the actor systems." [A-1] The reason given is that the system's own messages "cannot be dropped because that would result in an inconsistent state between the systems" [A-1].
- **A watch within a cluster says nothing on unreachability alone.** Its notice comes "when the unreachable cluster node has been downed and removed" [A-11], and carries no reason.
- **Split brain.** "network partitions (split brain scenarios) and machine crashes are indistinguishable for the observer" [A-9]. A resolver decides which side lives, after 20 seconds of stability. It exists because downing by timeout means "two singleton instances or two sharded entities with the same identifier would be running" [A-9]. A pause defeats it: "When the node un-pauses there will be a short time before it sees its self as down where singletons and sharded actors are still running" [A-9].
- **Types across nodes.** A typed address crosses as a text, and the type is taken from whoever reads it back: nothing checks the message's type on arrival. This is read from the code [A-13].
- **A spawn on another node** "isn't supported in Typed. This feature would be discouraged because it often results in tight coupling between nodes and undesirable failure handling." [A-17]
- **Finding a service** is by a key that is replicated: "each node will eventually reach the same set of actors per ServiceKey" [A-15].

### What goes wrong in production

- **Quarantine removed nodes behind the resolver's back** and caused a split brain, in 2018. The Akka team's answer: "The decision of downing should be completely in control of the downing provider" [A-19][A-20].
- **The send queue overflows under bursts.** The team's answer names sustained overload and "head of line blocking, if a few of the messages are very large" [A-21].
- **False unreachability** from "long (unexpected) garbage collection pauses, overloading the system, too restrictive CPU quotas" [A-5][A-22].
- **A killed node stays a member** and stalls the membership until it is downed [A-7].
- **Address translation and containers** break the rule that "if a system A can connect to a system B then system B must also be able to connect to system A independently" [A-24].

### What it supports

- **No membership and no agreement in the core.** The resolver, quarantine against downing, and a stalled membership all come from membership that nodes share.
- **A loss that ends addresses and not the node.** It has quarantine's consistency without the restart.
- **At most once.** "The only meaningful way for a sender to know whether an interaction was successful is by receiving a business-level acknowledgement message" [A-4].
- **A long fixed timeout with any bytes as a sign of life.** Akka's separate stream was built for "reducing false failure detection in case of heavy traffic" [A-1].
- **One build.** Nodes of one service "share the same code and are deployed together" [A-25].
- **The type checked on arrival, and a call that learns of its callee's death.** Akka has neither. Its `ask` ends by timeout alone: "the receiving actor does not know and may still process it to completion" [A-16].
- **No gap.** Akka keeps that for the system's own messages alone.

### What it questions

- *A1.* **A full queue as the loss of everything.** Akka keeps that for the system's own messages, and a program's bursts overflow in practice [A-21]. One fast producer would end every address and monitor between two nodes. The reader suggests a limit in bytes, a way to see how much waits, and a library in which "The flow control is driven by the consumer side" [A-26].
- *A2.* **One connection.** A large message delays every call that has a time on it. Erlang keeps the order of a pair without separate streams: "Use fragmented distribution messages to send large messages" [A-27].
- *A3.* **Two nodes that dial at once, and a node that cannot be dialled.** Akka avoids both by connections that carry traffic one way. One connection for both ways needs a rule for the tie, which the proposal has, and a stated answer where only one side can dial, which it has not.
- *A4.* **A spawn on a peer.** Say what a spawned process does when its spawner's node is lost, and weigh a list for each peer of what it may start, as Akka's older interface has because a spawn "can potentially be abused" [A-18].
- *A5.* **A lease needs a token that only grows,** since "a lease can be lost due to a timeout with the third party system" [A-35], and a paused node acts on for a moment.
- *A6.* **A message that cannot be decoded.** Akka drops it, which the proposal's rule against a gap forbids. So a build's identity in the hello, and a refusal, are right for now; whether a type's hash must be exact or may allow a compatible type is a later question.
- *A7.* **A number drawn at each start,** in the hello and in every address. The proposal has it; the reader was not told so.
- *A8.* **The delay before a dial.** Akka's is a fixed second. The proposal's grew and had a random part when the reader read it; on Erlang's distribution it has none (*An experiment*, section 4).
- *A9.* **Detection in seconds,** against the proposal's 45 to 75, at the price of the false alarms above.

### What the reader could not verify

A post from Credit Karma on quarantine is often cited, and its site did not answer. Whether the fix to the incident of 2018 changed quarantine in later versions was not checked. One practitioner's page [A-23] was read through a summary and is not quoted.

### Sources

- [A-1] https://pekko.apache.org/docs/pekko/current/remoting-artery.html
- [A-2] https://raw.githubusercontent.com/apache/pekko/main/remote/src/main/resources/reference.conf
- [A-4] https://pekko.apache.org/docs/pekko/current/general/message-delivery-reliability.html
- [A-5] https://pekko.apache.org/docs/pekko/current/typed/failure-detector.html
- [A-7] https://pekko.apache.org/docs/pekko/current/typed/cluster-membership.html
- [A-8] https://raw.githubusercontent.com/apache/pekko/main/cluster/src/main/resources/reference.conf
- [A-9] https://pekko.apache.org/docs/pekko/current/split-brain-resolver.html
- [A-11] https://pekko.apache.org/docs/pekko/current/cluster-usage.html
- [A-13] https://raw.githubusercontent.com/apache/pekko/main/actor-typed/src/main/scala/org/apache/pekko/actor/typed/ActorRefResolver.scala
- [A-15] https://pekko.apache.org/docs/pekko/current/typed/actor-discovery.html
- [A-16] https://pekko.apache.org/docs/pekko/current/typed/interaction-patterns.html
- [A-17] https://pekko.apache.org/docs/pekko/current/typed/from-classic.html
- [A-18] https://pekko.apache.org/docs/pekko/current/remoting.html
- [A-19] https://github.com/akka/akka/issues/25632
- [A-20] https://discuss.akka.io/t/quarantine-breaks-cluster-abstraction/2141
- [A-21] https://discuss.akka.io/t/message-was-dropped-due-to-overflow-of-send-queue-size-3072/10204
- [A-22] https://pekko.apache.org/docs/pekko/current/additional/deploying.html
- [A-23] https://petabridge.com/blog/proper-care-of-akkadotnet-clusters/
- [A-24] https://pekko.apache.org/docs/pekko/current/general/remoting.html
- [A-25] https://pekko.apache.org/docs/pekko/current/typed/choosing-cluster.html
- [A-26] https://pekko.apache.org/docs/pekko/current/typed/reliable-delivery.html
- [A-27] https://www.erlang.org/doc/apps/erts/erl_dist_protocol.html
- [A-35] https://pekko.apache.org/docs/pekko/current/coordination.html

## 4. The Erlang ecosystem

Erlang's own distribution, what has been built beside it, and the evidence for and against standing on it, which is unsolved point 1 of the proposal. The reader checked its quotations from Erlang's documentation, the Partisan paper and OTP's release notes against the text. A quotation marked † came through a tool that summarises, and its wording is to be checked before it is cited.

### What Erlang's distribution promises

- **Order for a pair, and silent loss.** "When communicating over the distribution, signals can be lost if the distribution channel goes down." And of two signals: "`S1` is guaranteed not to arrive after `S2`. Note that `S1` may or may not have been lost." [E-1]
- **A held pid is not dead after a loss.** The reader tried it on OTP 29: after a disconnection the monitor fired `noconnection`, and the next send to the same pid connected again and was delivered. Only a restart of the node changes the number that marks its pids [E-6].
- **Connecting again** is a setting for the whole node: never, or once, "If a node goes down, it must thereafter be explicitly connected." [E-3]
- **The mesh.** "Connections are by default transitive." [E-2] Since OTP 25 the module `global` prevents overlapping partitions "by actively disconnecting from nodes that reports that they have lost connections to other nodes" [E-4].

### Where it hurts

- **One connection for a pair.** "a large message can thus hold heartbeats back" [E-19]. OTP 22 sends a large message in fragments; it is still one stream.
- **A sender made to wait.** "the sending process may be suspended even though the signal is supposed to be sent asynchronously", which "cannot be fixed" [E-1]. A flag turns the wait off, and without a limit of its own that "will typically cause the sending runtime system to crash on an out of memory condition" [E-8].
- **Size.** The Partisan paper cites 200 nodes at Ericsson and Riak "not … beyond 60" [E-17].
- **Atoms.** A peer's data can "create resources, such as atoms and remote references, that cannot be garbage collected" [E-8], and distribution has no safe decoding.
- **Trust.** "The Erlang Distribution protocol is not by itself secure and does not aim to be so." [E-6] "if one node in a cluster is compromised, all nodes are" [E-20]. TLS proves who a peer is and narrows nothing it may do.

### What was built beside it

- **Partisan** replaces the distribution with a library of its own, and reports "up to an order of magnitude increase in the number of nodes" and "up to a 38.07x increase in throughput" [E-17]. Its criticism is the one connection: "a single TCP connection, therefore multiplexing actor-to-actor communication on a single channel" [E-17]. It had to write its own versions of Erlang's servers and of monitoring†.
- **Another carrier.** Erlang lets a module replace how nodes are found, connected and authenticated [E-5]. It must deliver bytes "in the exact same order, with no loss", and what a signal means, whether a pid is valid, how data is decoded and what a peer may do all stay the runtime's.
- **Languages.** The reader found none on the Erlang runtime that avoids Erlang's distribution.
- **Large deployments** work around it. Riak "avoids using Distributed Erlang for background data synchronization … to avoid head-of-line blocking" [E-17]. RabbitMQ moved its metadata to Raft, since the earlier store's "weakness is its failure recovery characteristics, in particular when it comes to network partitions"† [E-26]. Discord groups its sends by node†, and WhatsApp runs a filter on the distribution's messages [E-36].

### The three ways

| Way | What it gives | What it cannot give | Cost |
|---|---|---|---|
| A protocol of our own over TLS, as proposed | All that is asked, by construction: identity by key, addresses bound to a connection, a decoder of our own, one typed way in, any shape of network | Erlang's sends, links, monitors and tools across nodes; heartbeats, limits and fragments are ours to write | About the host's own over TLS, where frames are sent several at a time |
| Erlang's distribution, with our rules above it | Links, monitors, spawns and tools; no mesh, by a setting; identity by key in part | A held pid lives again; nothing checks a message before the mailbox; a peer creates atoms; any peer can end, start and call anything; the cookie remains | The fastest without encryption |
| Another carrier beneath Erlang's distribution | Transport, authentication and discovery of our own; several streams | The same as the second way for pids, checks, atoms and trust | About the host's own over TLS |

### A measurement

The reader measured on one machine, both nodes on it, on OTP 29, one to three runs each, with no limit on the sender in the protocol of our own. It is a first look and no more.

| Transport | A round trip | 100 bytes, 16 senders | 10 KB | 1 MB |
|---|---|---|---|---|
| Erlang's, no encryption | 73 to 102 µs | 82 to 94 thousand a second | 460 to 570 MB/s | 1280 to 1470 MB/s |
| Erlang's over TLS | 153 µs | 194 thousand a second | 279 MB/s | 333 MB/s |
| Our own over TCP, a message a frame | 84 to 98 µs | 29 thousand a second | 190 to 213 MB/s | 671 MB/s |
| Our own over TCP, up to 32 a frame | 88 µs | 324 thousand a second | 539 MB/s | 558 MB/s |
| Our own over mutual TLS 1.3, a message a frame | 144 to 168 µs | 15 thousand a second | 114 to 116 MB/s | 330 to 346 MB/s |
| Our own over mutual TLS 1.3, up to 32 a frame | 151 µs | 225 thousand a second | 253 MB/s | 241 MB/s |

Over TLS the two are within about a third of each other. Sending several messages in a frame decides the rate of small messages. Without encryption Erlang's is about twice as fast for large values. The reader found no published comparison of the two.

### An experiment

After the reader's report, the carrier was tried: four nodes on one machine, on OTP 29, each with a self-signed certificate and a list of the keys it accepts. Its code and how to run it are in `proposals/nodes_and_code/experiments/erlang_distribution/`.

| Tried | Found |
|---|---|
| TLS between nodes that list each other, with no port-mapper daemon | It connects. A table from a node's name to its port stands in for the daemon |
| A node that is not listed | Refused in the TLS handshake, by a rule of ours that accepts a peer by its public key |
| A certificate that names another host | Accepted by its key all the same. A node's name on the carrier need not hold its address either: a name that resolves nowhere works, the table answering for it |
| No mesh | With a setting, two nodes that share a peer stay unconnected. A connection opens at the first send |
| A sender that does not wait | With the peer stopped, a send that refuses to wait is refused at once; the node then ends the connection itself, and both nodes are told | The proposal keeps the host's own way instead, a sender that waits, which the experiment's first step 8 run showed: a thousand sends behind a dial that nothing answered held the sender until the dial was given up |
| A silent peer, with the timeout at 4 seconds | Found lost after 4.6 to 4.8 seconds. A monitor on its process gives `noconnection`. The peer is told as it wakes |
| An address after a loss | The same pid reaches the same process, and the connection opens again by itself |
| Monitors and replies | A kill and a fault arrive with Ernest's own reasons. A reply through an alias takes one answer and drops a second |
| A node started again | A monitor on a process of its earlier start gives `noproc`, and a send to it is dropped |
| Two nodes with one key and name | To their peer they are one node. Each one's dial ends the other's connection, with `wait_pending` at the peer; what is sent to the other's processes is dropped, and a monitor on them gives `noconnection` |
| A node with another cookie | Refused in the host's handshake, with nothing sent and the other connections untouched. So the cookie can carry the build's fingerprint, and a node of another build is refused before anything passes |
| A parted network, through a proxy that drops bytes and closes | Both ways: both nodes find the loss within the detector's time. One way: the side that hears nothing finds it within the detector's time, and its close passes the open direction, so the other side is told at once |
| A send where no connection is open | It returns in microseconds, whether the peer's port refuses or nothing answers there. A refused dial costs about 90 microseconds, and the host makes one at each send, with no delay between them. Where nothing answers, the sends wait behind one dial, which the host gives up after 7 seconds |
| A node that does not listen, which its peer has no address for | The peer cannot connect to it. Once it has dialled, the peer reaches it and spawns on it over that connection. After a loss both are told, and what the peer sends is dropped until the node dials again; the same pid then reaches the same process. The host calls such a node hidden: it is left out of `nodes/0`, and of the notices of a loss unless every kind of node is asked for |

So the host gives the handshake, the detector, a loss that both nodes run, an address that outlives a loss, monitors and one-shot replies. What would be ours is a frame that carries a message's type, the check before a mailbox, and the check that two nodes run one program. Three things it does not show: a network that really parts, a certificate that names another host, and any speed. And one thing nothing turns off: a connected node may start, end and call anything on the other.

### What it questions, and advises

- *E1.* **Stay with a protocol of our own.** What the other two ways cannot give is decided in the runtime, and no carrier or layer reaches it. The price is to build failure detection, monitors and limits ourselves.
- *E2.* **Send several frames at a time** from the connection's process, and keep the heartbeat out of the queue of data.
- *E3.* **Do not copy the single stream.** Leave room in a frame for fragments and for more than one connection to a peer.
- *E4.* **Say what a sender sees when the queue is full.** Erlang's waiting sender cannot be fixed, and its way out has no bound.
- *E5.* **Bind an address to its connection.** Erlang needed aliases, thirty years on, to come near it.
- *E6.* **Run the host without its distribution,** or with one that listens to this machine alone. A node that is also a node of distributed Erlang gives everything to whoever holds the cookie. Trust a peer's key and not an authority that signs keys.

### What the reader could not verify

The versions that introduced two settings. The figure of 1,500 nodes in one cluster at WhatsApp, which is the text of a search result for a talk. Why Erlang's own distribution was slower than the protocol of our own for small messages in the measurement.

### Sources

- [E-1] https://www.erlang.org/doc/system/ref_man_processes.html
- [E-2] https://www.erlang.org/doc/system/distributed.html
- [E-3] https://www.erlang.org/doc/apps/kernel/kernel_app.html
- [E-4] https://www.erlang.org/doc/apps/kernel/global.html
- [E-5] https://www.erlang.org/doc/apps/erts/alt_dist.html
- [E-6] https://www.erlang.org/doc/apps/erts/erl_dist_protocol.html
- [E-8] https://www.erlang.org/doc/apps/erts/erlang.html
- [E-17] https://www.usenix.org/system/files/atc19-meiklejohn.pdf
- [E-19] https://learnyousomeerlang.com/distribunomicon
- [E-20] https://security.erlef.org/secure_coding_and_deployment_hardening/distribution
- [E-26] https://www.rabbitmq.com/docs/metadata-store
- [E-36] https://github.com/WhatsApp/erldist_filter

## 5. Typed and capability systems

Swift's distributed actors, Unison and its cloud, and the capability systems that descend from the language E: OCapN, its protocol CapTP, and Spritely Goblins. The reader took the quotations for Swift, Unison's `Remote`, OCapN, Goblins, E and Cloud Haskell from the sources themselves. Those for Ray, Gleam, wasmCloud and Cap'n Proto came through a tool that summarises, and their wording is to be checked before it is cited.

### Swift's distributed actors

- **A remote call is typed differently, by the actor's kind and not by where it is.** A call from outside a distributed actor can always fail and always waits, even where the actor is local: "It is, by design, not possible to *statically* determine if a distributed actor instance is remote or local, therefore all programming against a distributed actor must be done as-if it was remote." [T-1] The benefit argued: "it allows us to surface any potential network issues that might occur during these calls" [T-1].
- **What crosses** is checked when the program is compiled, and a function is refused [T-1]. The target on the wire is the method's full signature: "any change in the method signature will result in not being able to resolve the target method anymore" [T-2]. No code moves.
- **Failure.** A membership protocol with gossip finds failures. On a node's fall, "'terminated' signals are generated for all actors watching" [T-4], "regardless if it really has deinitialized or not" [T-3]. A fall is for ever: "once a node is down/dead, it may never again be considered up/alive" [T-5]. A lost connection alone ends nothing.
- **Delivery.** A call has a time of 5 seconds by default. "A remote call may be delivered (and processed!) successfully, while only the reply to it may not" [T-7].
- **Finding** is by a typed key that an actor registers under [T-8].

### Unison and its cloud

- **Documented.** "Each Unison definition is identified by a hash of its syntax tree", and whoever receives a computation "requests the ones it's missing and the sender syncs them on the fly" [T-12]. Any value can be sent, a function among them.
- **Failure is in the type.** Distribution is an ability, `Remote`, and its operations answer `Either Failure` [T-14]. A service is typed by what it takes and what it gives [T-15].
- **Not documented, as far as the reader found:** what is promised of delivery and of order, what a node's death does to what runs on it, and whether a type is checked on arrival. The cloud's runtime is a licensed product and not open [T-16]. "As easy as a local function call" [T-13] is what it is sold with, and the ability in the type says otherwise.

### OCapN, Goblins and E

- **A loss is for ever, as in the proposal.** "Even after a partition heals, all references broken by that partition stay broken." "A partition simultaneously breaks all references crossing in a given direction between two vats." [T-22]
- **Order without a gap.** "Later messages will only be delivered by a reference if all earlier messages sent on that same reference were already delivered" [T-22]. OCapN requires "only one active session between two peers" [T-18].
- **The difference in the language** is between a call that waits and a send that does not, and it follows the boundary between two units of computation, not between two machines [T-21][T-22]. A failure is a broken promise.
- **Getting a reference again.** A durable reference holds the key's fingerprint, hints of where the node is, and a secret number. It "can be passed between vats even when the vat of the target object is inaccessible", and "one makes a new reference from an offline capability" [T-22].
- **A reference handed over by a third party.** The giver deposits the gift with the node that owns the object and sends the receiver a signed note; the receiver opens a session of its own and collects it [T-18]. The specification does not say what follows where the giver's session ends before the gift is collected, and OCapN is "still pre-specification" [T-20].
- **A broken reference stays broken wherever it goes.** "Broken is a terminal state (once Broken always Broken)", and broken references "are transitively passed by copy" [T-23].

### Others, briefly

- **Cloud Haskell.** "Every node is running the same code", and only a function known when the program is compiled crosses [T-29]. "Once a network connection breaks (even temporarily) no further communication on that connection will be possible" until the program calls `reconnect`, accepting "that some messages to B might have been lost" [T-29].
- **Ray.** "By default, actor tasks execute with at-most-once semantics", and a second attempt is asked for [T-25].
- **Proto.Actor.** "At-most-once delivery" and "message ordering per sender–receiver pair" [T-26].
- **Gleam.** "Type safe message passing is implemented in Gleam in libraries" [T-31]. The reader found no stated position on distribution.
- **Pony** has distribution in a thesis of 2013 alone. The reader found no stated reason.

### What it supports

- **A loss that is for ever, and getting an address again,** is E's design, argued from consistency. Cloud Haskell and Akka came to nearby positions.
- **At most once, order for each pair, nothing tried again unseen** is the default in Proto.Actor, Ray, Swift and Akka.
- **A time on a call, and "no answer",** match Swift's own admission that a lost answer and a lost call look the same.
- **No function in a message, and a spawn by reference within one build,** is Cloud Haskell's line and Swift's. Unison shows that the later step, code by its hash, works.
- **The same operations on one node and across nodes.** Swift types a remote call differently because a local call there cannot otherwise fail. A call in Ernest already answers "no answer" on one node, so it stands where E stands and needs nothing more.
- **No membership** is workable because a loss is a connection's. Swift and Akka need gossip, a verdict and a record of the fallen to make "terminated" final.

### What it questions

- *T1.* **Is being dead said of the value or of its holder?** Where A sends its dead address to C and C sends it back, is it live? Does it equal a fresh one? E answers by making breakage a reference's own: a broken reference is passed on as broken, and a third party introduces only by a live reference of its own.
- *T2.* **Both sides must come to know of the loss.** E relies on "eventual common knowledge of the loss of connection" [T-22], and OCapN states one session for each pair with a rule for crossed hellos. The proposal has both.
- *T3.* **How an address is obtained again.** Every system has an answer of its own: a durable reference, a first object every session starts from, a typed key, a named service. The proposal needs a typed and lasting form that keeps an address a permission.
- *T4.* **A type's hash and a new version.** Swift met this with signatures, and Unison puts a name between a service and its hash. A changed message type cuts nodes of two versions off from each other.
- *T5.* **Order across an introduction.** A's message to X, and the message B sends X after A introduced them, can arrive in either order. E strengthened its order for this. The proposal should state its rule.
- *T6.* **The right to kill travels with the right to send.** A reference in OCapN conveys messaging alone. An address that only sends would need a process in front of it.

### Sources

- [T-1] https://github.com/swiftlang/swift-evolution/blob/main/proposals/0336-distributed-actor-isolation.md
- [T-2] https://github.com/swiftlang/swift-evolution/blob/main/proposals/0344-distributed-actor-runtime.md
- [T-3] https://github.com/apple/swift-distributed-actors/blob/main/Sources/DistributedCluster/Docs.docc/Lifecycle.md
- [T-4] https://github.com/apple/swift-distributed-actors/blob/main/Sources/DistributedCluster/Docs.docc/Clustering.md
- [T-5] https://github.com/apple/swift-distributed-actors/blob/main/Sources/DistributedCluster/Cluster/Cluster+Member.swift
- [T-7] https://github.com/apple/swift-distributed-actors/blob/main/Sources/DistributedCluster/Docs.docc/Introduction.md
- [T-8] https://github.com/apple/swift-distributed-actors/blob/main/Sources/DistributedCluster/Docs.docc/Receptionist.md
- [T-12] https://www.unison-lang.org/docs/the-big-idea/
- [T-13] https://www.unison.cloud/docs/core-concepts/
- [T-14] https://share.unison-lang.org/@unison/cloud/code/main/latest/types/Remote
- [T-15] https://www.unison.cloud/our-approach/
- [T-16] https://www.unison-lang.org/blog/cloud-byoc/
- [T-18] https://github.com/ocapn/ocapn/blob/main/draft-specifications/CapTP%20Specification.md
- [T-20] https://github.com/ocapn/ocapn/blob/main/README.md
- [T-21] https://files.spritely.institute/docs/guile-goblins/0.18.0/Handling-Disconnects.html
- [T-22] https://papers.agoric.com/assets/pdf/papers/concurrency-among-strangers.pdf
- [T-23] https://web.archive.org/web/2023/http://www.erights.org/elib/concurrency/refmech.html
- [T-25] https://docs.ray.io/en/latest/ray-core/fault_tolerance/actors.html
- [T-26] https://github.com/Asynkron/Asynkron.Documentation/blob/HEAD/docs/ProtoActor/durability.md
- [T-29] https://www.microsoft.com/en-us/research/wp-content/uploads/2016/07/remote.pdf
- [T-31] https://gleam.run/frequently-asked-questions/
