# Ernest: Findings

What readers found of how other systems treat what [`mvp3.0.md`](mvp3.0.md) proposes, to be read beside it. A finding is something to weigh. None is a decision.

Each reader was a research session of its own, which fetched the sources it names on 6 October 2026. A quotation is as the reader reported it, and was not fetched again for this document. Where a reader could not verify something, it is marked *unverified*. A finding is named by its reader's letter and a number: *O* for Orleans, *A* for Akka.

Two readers have not reported yet, and sections 4 and 5 wait for them.

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

Not reported yet. The reader was asked about Swift's distributed actors, Unison and its cloud, and the capability systems, OCapN and Spritely Goblins: whether a remote call is typed differently from a local one, what a reference means after a disconnection, and how a reference handed over by a third party is treated.
