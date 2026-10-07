# Ernest: The Deploy, the reasons

Status: the reasons behind [`mvp3.2.md`](mvp3.2.md), the ordered rolling restart, in the order of its section 6. Written on 2026-10-07 as a thinking document, read against four readers ([`other_systems.md`](other_systems.md), section 7), tried in six programs and the library they share ([`experiments/code_update/`](experiments/code_update/README.md)), and decided with the user one question at a time, each decision dated where it stands. Nothing here is normative: the proposal states the rules, and this document says why. The reasons for a key's peers and for `Peer.standing`, which change `mvp3.0.md`, are [`nodes.md`](nodes.md)'s section 14; the reason for the cache on a node's disk, which changes `mvp3.1.md`, is [`code.md`](code.md)'s section 5. The test of every decision was that the team that deploys writes and does only what no tool can know.

## 1. The aim

After MVP 3.1 a deploy is a rolling restart, and it is what Orleans, Akka, Elixir, WhatsApp and the cloud do (*V2*, *V10*, *U7*, *U9*). Done by hand it is done blind: the operator chooses the order of the nodes and guesses the drain; a changed protocol is found in production, where it parts old clients from new services or, decoded before its version is checked, takes a service down (*V5*); a service's state is lost at its node's stop unless it lives outside; and the rollout is tested by hand or not at all (*V14*, *U7*). Ernest knows what the operator guesses: the hashes say which definitions changed, down to each service's protocol and state type; a service is found by a key that carries its type's identity; and a process's state is a value of a declared type, which crosses as any value does. So the runtime orders and checks the restart, and the team writes only what no tool can know.

## 2. The plan

**The plan comes from the hashes the nodes run.** `ern diff` over what each node runs and the new build is the plan's first half, so that the coordinator keeps no record of its own and no baseline is committed (*V13*). For each key: a protocol and a state type unchanged is nothing to do; a changed protocol is accepted only where the new build serves the old one too; a changed state type is accepted only with a whole `migrate`; and a build that drops a protocol is accepted only where no node runs a build older than the one that first served both. Everything the two builds decide is refused before the rollout, with the function named, since a refusal at planning costs nothing and one during a rollout costs a half-rolled system (*U5*). A rollout and its way back put at most three builds in flight, and the plan checks each pair and not the last alone (*S4*).

## 3. What is derived

**`migrate` by the one rule every system shares**, match by name and type, a default for what is added, drop what is removed, promote a number's width (*S1*, *V6*, *V11*, *D4*); a rename, which a diff reads as a removal and an addition, told by `was` in the new declaration, as Avro's and Orleans's aliases do (*S2*, *V6*). Where the rule stops the derived function has a hole the checker refuses as it refuses a partial `match`, never a default, since the field's generated zero is the one defect the migration tools of the field all shipped (*D4*). A changed meaning behind an unchanged type is invisible to any diff, so a program may give a `migrate` whose types are equal (*D5*). In the experiments a `migrate` was one line, or a `Map.map` over a record's conversion.

**`forward` where every constructor is kept in form**, each to its namesake, 5 lines in the counter experiment; a retired or changed request is the program's, 7 lines there, answered by the forwarder asking the new service, and an answer whose type changed converted back, 2 lines. A conversation has no point between its messages where versions can change, so a protocol is of independent requests and a conversation is a process of its own (*D12*).

**A type many protocols carry costs each of them.** Changing an item three services' protocols carried cost a copy of each service, retyped, and a `forward` each, 84 lines, against 37 where each protocol owned its types. The guide teaches a protocol's types as its own, small and of independent requests, with that number.

**A stored state is the store's, and its row type is Ernest's.** A stored value migrates when next read and is written back in the new form at the next write, as every system read does (*V12*, *D9*), and a `migrate` pure by its effect row pays nothing for being lazy (*D8*). A schema change is expand then contract in the database too; the plan checks the service's side and says it cannot check the database's.

## 4. The new declaration's module

A type's qualified name is in its identity, so an old declaration moved would be another type, which no running client holds (`mvp3.1.md`, section 5, limit 1); and two types in one module cannot share constructor names, so an old and a new declaration in one module rename every constructor the clients write. The new declaration therefore takes a module of its own, `counter2.ern`, and the old stays where it is, which the shared record experiment did for an item and three protocols. Deleting the old declaration with its `forward` or `migrate` is the act that drops the version, an edit a reviewer sees.

## 5. Two builds for a changed protocol

The first build serves both protocols, the new key and the old through the `forward`, so that an old client and a new service meet in any order; the second drops the old. This is the two deployments of Akka's rollout without degradation (*V11*) and the industry's expand then contract (*S3*), made a rule the tool checks: a build that changes a protocol and drops the old at once is refused, so that the discipline cannot be forgotten.

## 6. The order

Decided with the user on 2026-10-07. The `forward` lets a new service serve an old client, and nothing lets an old service serve a new one, whose find with the new key on a node not yet reached answers `OtherType`. The coordinator knows which keys each node offers and which keys each node's code finds, a find being a reference the hashes see, so it upgrades the nodes that offer changed services before the nodes whose code calls them, and the window closes. Where the graph has a cycle no order avoids a wait, so the coordinator picks one and the plan names the finds that will wait. The team states nothing about order.

## 7. The planned stop

**`ern stop` is the planned stop.** Decided with the user on 2026-10-07: it is what anyone who types it wants, and the quick end stays the signal the machine's service manager sends, so the operator learns no second command. The coordinator sends the same operation as one frame, carrying the drain's bound and the next build's root hashes.

**The keys first.** A node about to stop stops offering, so that a find goes to another of the key's peers, as Orleans's placement stops placing on a silo about to stop (*V3*).

**The drain.** Decided with the user on 2026-10-07: a minute by default, ended early when no call waits on any of the node's services and their mailboxes are empty, bounded by `--drain` on `ern stop` and `ern deploy` and carried in the frame, since its length is the deployment's choice at the moment and not the machine's and so not `ernest.conf`'s. The survey's precedents are ten and fifteen minutes for proxies holding thousands of long connections (*U13*); a few nodes with one owner, whose calls carry deadlines of seconds, need none of it, and a drain that ends when nothing waits costs nothing by having a bound. It does not grow firmer: the runtime holds no connections of its own to close, and a program that holds them has what it needs, its keys withdrawn first and its own listener to stop accepting on; what it has not finished by the close it loses, as any restart loses it, which the plan said before the yes.

**The state, moved or written.** Decided with the user on 2026-10-07, first as state staying with its node, since a client found a service by its node's name and a service that moved would answer `NotOffered` where every client looked, and then widened by a key's peers (nodes.md, section 14): a service whose key another peer may offer moves there before the stop, the successor started by `Peer.spawn` from the next build's code with the state as a captured value, so that a singleton has no gap; one whose key this node alone may offer writes its state to the node's disk; one whose state cannot cross, by §3.11's rule, which the compiler already decides, begins afresh, and the plan lists it before the yes. A library service hands its state on by default, nothing written. The state has one owner at every instant, where Orleans's shutdown can make a second (*V2*).

**The close** is the ordinary loss as `mvp3.0.md` has it, so nothing new is added for it: a call still waiting answers `None`, a monitor gives `Unreachable`, a message in flight is gone, and a client finds the service again through its standing address. Connections drain to their own end, since no system moves one across machines (*U12*).

## 8. The state file

Decided with the user on 2026-10-07. Its place is `state/` in the configuration directory, which the node owns as it owns `ernest.pid`, so nothing new is created or secured; one file per key, named by the key's name. Its form is the hash of the state type's identity and then the value in the encoding a value crosses between nodes in, so that the service that reads it knows which `migrate` applies, or that none does. It is written to a temporary name and renamed, so that a stop that dies mid-write leaves the previous file or none. The new build's service reads it at its start, through `migrate` where the hash differs from its own, and removes it; a service that finds a hash its build cannot migrate from begins afresh and says so, which the plan told the operator before the yes. When the coordinator says the next build is older, the stop writes the state through the reverse `migrate`, which the stopping build holds, so that the way back needs nothing of the old build.

## 9. The coordinator and the lockstep

**One command, keeping nothing.** Decided with the user on 2026-10-07: `ern deploy build --config-dir dir` prints the plan, waits for a yes, and does the rest; a job of `ern`, written in Ernest, and a node like the shell, listed by the nodes it deploys to, so that nothing new is trusted. It keeps no record of the rollout, since a record can be lost or disagree with the nodes, and each node answers which build it runs; so a second `ern deploy` after a crash or a cancel continues from where the nodes are. The team's whole burden for a deploy is to build, run one command, and read the plan before the yes.

**The check is the protocol's.** After each node's restart the coordinator finds every key the node offers at the identity the plan expects, which says that the services are up and of the right version, where a process being alive says neither. A check that fails stops the rollout, and the stopped node goes back to the previous build, which stays whole until told, as nginx keeps its old master (*U14*). Nothing is suspended and nothing restarts the whole system, where OTP's failure past its point of no return reboots into the old release (*U5*).

## 10. The way back

The previous build cannot hold a function from a type written after it (*V11*, *S11*, *V13*), so the reverse `migrate` ships with the new build, derived and holed like the forward one, and a change whose reverse has a hole is forward-only, which the plan says. During a rollout the way back is the previous build, node by node, accepted while every protocol it speaks is still served, which holds until the build that drops one; after that the way back is forward.

## 11. The cache

The reason is `code.md`'s section 5: one mechanism moves code between nodes, MVP 3.1's exchange, and a node restarts into a build from its own disk. What is the deploy's: a node fetches the next build's closure before its stop, so that the restart does not wait on the network; and a build's hashes leave the cache when a newer build has run and the plan no longer names the old one as the way back, which is the moment the old protocols are dropped, so that the cache holds exactly the builds a rollout or its way back can need.

## 12. The runtime's surface

Decided with the user on 2026-10-07 to be this milestone's and not one of its own, which the plan had held as MVP 3.1a. MVP 3.1 puts `ern`'s whole version in the cookie because shipped code calls the runtime by name and nothing hashes that surface, which is honest; its cost is that a release of `ern` stops every node, which is exactly what the deploy exists to avoid. The surface's value appears when a deploy is a rollout the runtime orders, so it is named, versioned and put in the cookie here, where the deploy's tests exercise it; and it is best named once the exchange runs and shows what shipped code calls by name.

## 13. The refusal

A supervised process's restart runs the function the child was spawned with, so an upgrade in place of one vanished at its first fault in the supervisor experiment, and `Supervisor.child`'s function run again inside the child made the group count a fault that had not happened, since the inner function read the outer child's start cause. An operation by which a child replaces the function its restart runs was decided and withdrawn the same day with the change of logic in place (section 15); what remains is to refuse the call, `Fault("a process runs one child function")`, the smaller of the two answers, since nothing of the deploy needs the other.

## 14. The test

Decided with the user on 2026-10-07. The test's channel into and out of every service is the state file of the planned stop, so that it sends no message of any protocol and the team writes no test of its own: values generated for each state type go in as the files a stop would have written, and the states the stops write come out. The oracle is identity where the state type is unchanged and the round trip through the reverse `migrate` where it changed; a property a human writes is asked for only where the reverse has a hole, which the plan has named forward-only, the one piece no system has automated (*D14*, *V14*). The test covers the deploy's whole path and not the service's logic, which the program's own tests cover. The cost of testing a rollout by hand is the stated reason the field does it seldom (*U7*, *U9*), and the generated run is the answer.

## 15. Why not in place

The six experiments asked what upgrading a running process in place would cost. A change of logic took one message and kept everything: the counter's total, the store's items and listener, the chat server's connections. Any other change failed at the type, since the loop's mailbox type names its protocol and its state; in place it needs `become`, a gate through which a running process's mailbox type changes, which would be the language's one addition for step D and its riskiest, the only part the soundness argument would have to carry beyond MVP 3.1's. A replace, a successor with the state and the old address forwarding, ran today for every other change, and the planned stop's third step is its half that moves or writes the state out.

What in place keeps that a restart loses is a process's connections through a change of its state or protocol, and a process can keep them another way: it owns the sockets behind a small protocol that never changes, and the logic that changes is a service beside it. So in place is set aside, and no change of code in place stays, not even the change of logic the experiments ran: decided with the user on 2026-10-07. The rolling restart is the one way to deploy; a change of logic in place would be a second, would reach the library's services and not a module's loops and helpers, leaving mixed versions on one node, and would need `Supervisor`'s operation. What would bring `become` back is a program that must change the protocol of a process holding connections, where the shape above does not serve. The library's `Upgrade` stays in the experiments as the record of what in place would have been; §6.10 stays in the report as a statement that a process takes new code only by its own act, by a message that carries a function on one node, and that there is no other way, which nothing of the deploy builds on; and part two of `code.md` stays as the record of the thinking for in place.

## 16. Left out, with the reason

- *A change of a running process's code, `become`, and the library's `Upgrade`*: section 15.
- *An election, a lease, a service that moves by itself at a failure*: one owner across a failure needs a lease in a store outside the nodes with a token that only grows (*O3*, *A5*), a library's work; Erlang's `global`, Orleans's duplicate activation and Akka's downing resolver each show the two owners that follow a guess (*V2*).
- *A drain that grows firmer*: section 7; the runtime holds no connections of its own.
- *A record the coordinator keeps*: section 9; the nodes are the record.
- *A committed baseline for the plan*: section 2; the nodes' hashes are the baseline.
- *A policy for the gap of a standing address*: nodes.md, section 14; the gap has a loss's semantics.
- *A plan that reasons about a changed meaning behind an unchanged type*: section 3; invisible to any diff.
- *The database's side of a schema change*: section 3.
- *A hello, a point of no return, a suspend*: sections 2 and 9; nothing is suspended, and a refusal comes before the rollout or is answered per node.
