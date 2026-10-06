# Ernest: Other Systems

How other systems treat nodes, the loss of one, and what passes between them: what readers found, set beside what [`mvp3.0.md`](mvp3.0.md) proposes. A finding is something to weigh. None is a decision.

Each reader was a research session of its own, which fetched the sources it names on 6 October 2026. A quotation is as the reader reported it, and was not fetched again for this document. Where a reader could not verify something, it is marked *unverified*. A finding is named by its reader's letter and a number: *O* for Orleans, *A* for Akka, *T* for the typed and capability systems.

One reader has not reported yet, and section 4 waits for it.

## 1. What recurs

What more than one reader said, or what bears on a choice the proposal made. Each names the place in the proposal it bears on.

1. **Finding a failure takes us three to five times longer.** Akka finds one in seconds, Orleans in about 15 seconds, the proposal in 45 to 75, and as a constant. Akka's speed costs it false alarms, which its documentation admits (*A9*, *O7*). Bears on section 6, *The detector*, and section 7.
2. **A full queue does happen.** Akka's send queue overflows in practice under bursts, and Akka then drops the one message. The proposal ends every conversation between the two nodes (*A1*). Bears on section 5, point 4.
3. **One connection for everything.** Akka gives each peer three streams so that a large message cannot block an urgent one (*A2*). Bears on section 5, point 5.
4. **A call's failure has two meanings.** A request that was never sent may be sent again, and one that was sent has an unknown outcome. The proposal answers `None` for both (*O1*). Bears on section 5, point 2.
5. **What must exist once needs something outside the nodes.** Each node decides alone, so two can disagree about a third; a lease works only through a store all of them consult, with a token that only grows (*O3*, *A5*). Bears on section 5, point 1.
6. **Finding a service matters more than spawning on a peer.** Akka's typed interface has no remote spawn at all and discourages it; a "find it again" helper is the first library anyone writes (*A4*, *O4*). Bears on section 9, points 2 and 3.
7. **One side may be unable to dial.** Behind address translation or in containers, A reaches B and B does not reach A (*A3*). The proposal does not say what follows.
8. **Bytes prove the link and not the node.** A node that is starved and still connected looks alive (*O6*). Bears on section 6, *The detector*.
9. **A dead address can stay dead when it travels.** In the language E a broken reference is passed on as broken, and only a live reference of the third party's own introduces anew (*T1*). The proposal lets a dead address come alive by a round trip. A node knows which addresses it holds dead, and could send them on as dead. Bears on section 6, *Addresses*.
10. **How an address is obtained again is a design of its own** in every system read: a durable reference in the capability systems, a typed key in Swift and Akka, a named service in Unison (*T3*). Bears on section 9, point 2.
11. **An address also lets its holder kill.** The capability systems give a reference the right to send and nothing more (*T6*). Bears on section 2.

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
- *A8.* **The delay before a dial.** Akka's is a fixed second. The proposal's grows and has a random part.
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

Not reported yet. The reader was asked what Erlang's own distribution guarantees and where it hurts in production, what Partisan and custom carriers change, and for the evidence for and against standing on Erlang's distribution, which is unsolved point 1 of the proposal.

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
