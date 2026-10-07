# Ernest: Code Update, the thinking for step D

Status: a thinking document for step D of [`code.md`](code.md)'s section 1, *The four steps*, a running system that takes new code. Begun 2026-10-07, read against four readers the same day ([`other_systems.md`](other_systems.md), section 7), tried in six experiment programs ([`experiments/code_update/`](experiments/code_update/README.md)), and rewritten the same day around an ordered rolling restart, upgrading in place set aside for the reasons of section 4. Nothing in it is decided, and no proposal is written from it yet.

## 1. The problem

After MVP 3.1 a deploy is a rolling restart: nodes of the new build start beside the old, node by node, and a service is found by its key at whichever version it is. It is what Orleans, Akka, Elixir, WhatsApp and the cloud do (*V2*, *V10*, *U7*, *U9*), and what every developer does. It is also done blind. The operator chooses the order of the nodes and guesses the drain; a changed protocol is found in production, where it parts old clients from new services or, decoded before its version is checked, takes the service down (*V5*); a service's state is lost at its node's stop unless it lives outside; and the rollout is tested by hand or not at all (*V14*, *U7*).

Ernest knows what the operator guesses. The hashes say which definitions changed, down to each service's protocol and state type. A service is found by a key that carries its type's identity. A process's state is a value of a declared type, which crosses to another node as any value does. The aim is a rolling restart the runtime orders and checks: planned from the hashes, refused before it starts where it would part a client from its service, each node stopped in order with its services' state handed on, the next node not touched until the last answers, and the whole of it run as a test on every commit.

## 2. The concept

**The plan comes from the hashes.** `ern diff` grows into the deploy's planning step, against a committed baseline of the last release's hashes and canonical forms, as Dapr's shipped file is (*V13*). For each service, by its key: a protocol and a state type unchanged is nothing to do, and its nodes roll in any order; a changed protocol is refused unless the new build serves the old one too; a changed state type that crosses a node is refused without a `migrate`. Everything the two builds decide is refused before the rollout, with the function named: `Catalog: Msg changed and the build does not serve Catalog.Msg of the release`.

**A changed protocol is two builds, expand then contract, and the tool enforces it.** The expand build serves both protocols: the new key, and the old key through the program's `forward` (section 3). It rolls out completely, and during it an old client and a new service meet through the `forward`, so the nodes go in any order (*S3*). The contract build deletes the old declaration and its `forward`, which the plan accepts only when no node older than the expand build remains. This is the two deployments of Akka's rollout without degradation (*V11*) and the industry's expand then contract, made a rule the tool checks rather than a discipline. A rollout and its way back put at most the release, the expand build and the contract build in flight, and the plan checks each pair, not the last alone (*S4*).

**A node stops by a plan, not by a kill.** The planned stop is a runtime operation in four steps:

1. The node stops offering its keys, so that a find goes to another node, as Orleans's placement stops placing on a silo about to stop (*V3*).
2. Calls in flight finish, for a drain the operator sets in minutes, firmer as it runs, ended by a close (*U13*).
3. Each service whose state is worth keeping hands it to a successor on another node, the library's replace with the successor started by `Peer.spawn`, the state crossing as a value through `migrate`, as Orleans's grain migration does (*V3*). The old service forwards to the successor until the node stops, so that the state has one owner at every instant, where Orleans's shutdown can make a second (*V2*).
4. The node closes. Connections drain to their own end, since no system moves one across machines (*U12*).

**The rollout goes in lockstep.** A coordinator, written in Ernest, walks the nodes one at a time: the planned stop, the start with the new build, and a check before the next. The check is the protocol's, not the process's: the node offers its keys again, and a find by each key answers at the type identity the plan expects. A check that fails stops the rollout, and the stopped node goes back to the previous build, which stays whole until the coordinator says otherwise, as nginx keeps its old master (*U14*). Nothing is suspended and nothing restarts the whole system, where OTP's failure past its point of no return reboots into the old release (*U5*).

**A client survives its service's restart without code of its own.** Every client finds again after a restart, which nodes.md's section 14 left to a library: the standing address, a forwarder on the client's node that holds the key, monitors the service and finds it again when told, given to the client through `via`, which is the first library everyone writes (*A4*, *O4*). The client writes only its policy for the gap, to hold with a bound, drop, or fail each call. What no library hides is the call itself: a `None` may or may not have run (nodes.md, section 11), so the retry is the program's and a request must be harmless when run twice.

**A singleton has one owner through a planned stop, and none is promised at a failure.** The handover of step 3 gives the state one owner at every instant. At a failure, a node that seems lost may live on, and one owner then needs a lease through a store outside the nodes, with a token that only grows (*O3*, *A5*); that stays out, as MVP 3.0 has it.

**Two versions of a type are two types.** A frame of a type the node lacks is refused by its hash before any of it is decoded, which is where Orleans's rolling upgrade broke (*V5*). Values are immutable and a message is a copy, so versions meet only where something translates: a `forward`, a second key, a `migrate` (*D3*).

## 3. What the program writes

**Nothing, for a change behind unchanged protocols and state types.** It is the commonest deploy.

**A `forward` for each changed protocol, in the expand build.** It takes an old message and the new service's address, and sends the translated message or answers an old request itself by asking the new service. Where every old constructor is kept in form it is the namesake map, 5 lines in the counter experiment, which a tool writes. A retired request was 7 lines, and an answer converted back to the old type 2. A protocol is of independent requests; a conversation has no point between its messages where versions can change, and is a process of its own (*D12*).

**A `migrate` where state crosses a version**, at a handover or when a stored value is read. It is derived by the one rule every system shares: match fields by name and type, a default for a field the new type adds, drop a field it removes, promote a number's width (*S1*, *V6*, *V11*, *D4*). A rename reads as a removal and an addition and is told by one word in the new declaration, `was` (*S2*). Where the rule stops, the derived `migrate` has a hole the checker refuses, never a default (*D4*). A changed meaning behind an unchanged type is invisible to any diff, so a program may give a `migrate` whose types are equal (*D5*).

**The new declaration takes a module of its own, and the old stays where it is until the contract build.** A type's qualified name is in its identity, so an old declaration moved would be another type (`mvp3.1.md`, section 5, limit 1), and two types in one module cannot share constructor names. The new protocol is `catalog2.ern`, whose clients write its name.

**A type many protocols carry costs each of them.** Changing an item that three services' protocols carried cost a copy of each service and a `forward` each, 84 lines, against 37 where each protocol owned its types. A protocol's types are its own, small and of independent requests, which the guide teaches with that number.

**A stored state is the store's, and its row type is Ernest's.** A stored value migrates when next read and is written back in the new form at the next write (*V12*, *D9*), and a `migrate` pure by its effect row pays nothing for being lazy (*D8*). A schema change is expand then contract in the database too; the plan checks the service's side and says it cannot check the database's.

**The way back is the previous build, node by node, until the contract.** The coordinator rolls a stopped node back, and a whole rollout back, while the previous build's protocols are all still served. After the contract build the way back is forward, and a state handed on needs a reverse `migrate` that the new build ships, since an old build cannot hold a function from a type written after it (*V11*, *S11*).

## 4. Why not in place

The six experiments asked what upgrading a running process in place would cost. A change of logic took one message and kept everything: the counter's total, the store's items and listener, the chat server's connections. Any other change failed at the type, since the loop's mailbox type names its protocol and its state; in place it needs `become`, a gate through which a running process's mailbox type changes, which would be the language's one addition for step D and its riskiest. A replace, a successor with the state and the old address forwarding, ran today for every other change, and it is the planned stop's step 3 on one node.

What in place keeps that a rolling restart loses is a process's connections through a change of its state or protocol. A process can keep them another way: it owns the sockets behind a small protocol that never changes, and the logic that changes is a service replaced freely. In place is therefore set aside. What would bring `become` back is a program that must change the protocol of a process holding connections, where that shape does not serve. A change of logic in place may stay as the library's convenience, and if it does, a supervised service needs `Supervisor`'s operation by which a child replaces the function its restart runs, decided with the user on 2026-10-07, since a restart otherwise runs the function the child was spawned with. Part two of `code.md` stays there as the record of the thinking for in place.

## 5. The test

**The rollout runs as a test on every commit.** The shape half runs with nothing started: each service's row against the baseline, each hole and each untold rename refused. The run half needs two nodes: it starts the release on both, writes a state into each service through its protocol, rolls one node to the new build, checks the protocols from both, rolls the other, reads the state back, rolls back, and reads it again (*U11*, *D14*). The oracle is identity where nothing changed and the round trip where a state crossed; a property a human writes is asked for only where the round trip is not total, the one piece no system has automated (*D14*, *V14*). The cost of testing a rollout by hand is the stated reason the field does it seldom (*U7*, *U9*), and the generated run is the answer.

## 6. What is to hold

1. **No message of one version is read as another's**, refused by hash before any frame is decoded.
2. **A rollout the plan refuses never starts**: a changed protocol the new build does not also serve the old way, a crossing state without a `migrate`, a contract build while an older node remains.
3. **Through a planned stop a service's state has one owner at every instant.**
4. **The next node is not touched until the last answers** its keys at the identities the plan expects.
5. **State crosses a version through `migrate` alone**, derived where the diff decides, holed where it does not.
6. **Every version in flight is listed**: the build of each node, the protocols each service serves, the stored states of each shape.
7. **The way back during a rollout is the previous build**, node by node, and after the contract it is forward.
8. **A process keeps its code until it ends** (`mvp3.1.md`, claim 4).

## 7. What was read, and what was tried

Four readers on 2026-10-07, into [`other_systems.md`](other_systems.md), section 7: the upgrade practice and the proxies' hot restart (*U*); versioned actors, Orleans, Akka, Durable Functions and Dapr (*V*); schema evolution and the step-function shape (*S*); and dynamic software updating as a field (*D*). The node sections' findings on finding a service again and on one owner are *A* and *O*. Six programs under [`experiments/code_update/`](experiments/code_update/README.md), each written twice and run on one node: a counter, a chat server, a store, a protocol change, a supervisor and a shared record; section 4 is their summary.

## 8. Open

- The coordinator's shape: a job of `ern`, `ern deploy`, or an Ernest program a node runs, and where it keeps what it has done so that it survives its own restart.
- The planned stop's name and form, and how a service says that its state is worth handing on: the library's service, or every service of a key.
- The order of the nodes where the plan finds a translation one way only, and whether the coordinator derives it or the program states it.
- The drain: who sets its length, how it grows firmer, and what the close does with what still arrives.
- The standing address: its policy for the gap, and whether every client of a singleton needing it moves it beside `restarting`, as nodes.md's section 14 set as the condition.
- The baseline's form: the kept build directory of the release, or a file of hashes and forms.
- How the test writes a state into a service through its protocol and reads it back, without a message the protocol does not have.
- Whether a change of logic in place stays as the library's convenience, and with it `Supervisor`'s operation (section 4).
