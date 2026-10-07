# Ernest: Code Update, the thinking for step D

Status: a thinking document for step D of [`code.md`](code.md)'s section 1, *The four steps*, a running system that takes new code. Begun 2026-10-07 from one recovery path and a matrix of cases, read by four readers the same day ([`other_systems.md`](other_systems.md), section 7), and rewritten the same day under what they found. Nothing in it is decided, and no proposal is written from it yet. `code.md`'s part two, the thinking for one process that takes new code, moves here when this document's shape is agreed.

## 1. The problem

After MVP 3.1 a node holds versions side by side, a process keeps its code until it ends, a service is found by its key at whichever version it is, and a deploy is a rolling restart. That serves every process that can end and begin again without loss, and not the three a real system is made of: a service whose state is in its loop's arguments and worth keeping; a service that may not run twice on a node, since it holds a database connection, a listening socket, a file lock or a table; and a process whose address or connection is what its clients hold.

§6.10 gives one process a way to take new code, by a message in its own type and a tail call. It says nothing of the system: who sends the message, what the resources, the clients, the mailbox, the supervisor and the other nodes do, and how to come back.

OTP's answer is the `appup`: a second path through every process, written by hand, untyped, ordered by hand, and run seldom, so that it decays. OTP's own applications mostly restart, Elixir left the mechanism out as unviable in practice, and the field loads modules by hand and skips it (*U6*, *U7*, *U9*).

Ernest starts with three things OTP lacks. The hashes say exactly what changed between two builds, down to each service's state and protocol. Two versions of a type are two types, so no message of one version reaches a process of the other unchecked. And a process's state is a value of a declared type, so a function from one state to the next is checked like any function. The aim is a deploy planned from the hashes, refused before it starts wherever it cannot be made safely, with everything a human writes typed and run on every commit.

## 2. The concept

**A service is a step function, and the library runs it.** The shape the field converged on is one function from a state and a message to the next state, with the loop that calls it holding the state and owning the mailbox: `gen_server` beneath its callbacks, Akka Persistence's handler, Elm's `update` (*U3*, *V9*, *S7*). Every message boundary is then a safe point, since no frame of the old code is live when the next message is taken, which is the condition the dynamic-updating field proved and found by hand in each loop (*D1*, *D2*, *D13*). Ernest takes the shape as a library type over the language it has, `Service(Msg, State)`: `Service.start(init, step)` spawns the library's loop, which holds the `State`, calls `step : (State, Msg) -> State` on each message, and takes one message of its own that carries new code. A service binding reads `let counter = Service.start(fn() = 0, count)`, and says what the service is. The language's process, a function that loops with its state in its arguments, stays for a worker, a connection and whatever a service is not.

**An upgrade is one message, and nothing is handed over.** The library's loop takes `Upgrade(migrate, step)` as any message: when the step in progress returns, it applies `migrate : (State1) -> State2` to the state it holds and goes on with the new step, in the same process, at the same address, with the same mailbox and everything the process owns. It is §6.10 written once for every service, and OTP's suspend, `code_change` and resume without the suspend window, since the mailbox queues what arrives (*U3*, *U4*). A resource the service owns is still owned, so nothing is given. What an upgrade costs is the step in progress, which it waits for.

**The envelope tells the versions apart, and old clients are never told.** A local address is a pid alone, and a constructor of one name in two versions of `Msg` is one term on the host, so a message in the mailbox does not say which protocol it is of. The library never hands out its loop's raw address: a client gets `via(self(), fn(m) = Message(identity, m))`, an adapted address whose function wraps each message in the library's envelope with the protocol's identity. An address made under one version wraps with that version's identity for as long as it is held; a key offered for an old protocol after an upgrade is that adapted address; and the loop reads the tag and applies the translations it calls for, one after another for a client two versions behind, before the step sees the message. A request's reply is carried into the new message by the reply rule and answered in the old answer type through an adapted reply, and a retired request in that type's failure. So an old client, however long it runs, is never told, and the cost falls on its messages: one tag on every message of every service, and every client's address an adapted one, which §6.5 makes free to cross: a client on a node of the old build sends through it as any client does, the tag put on at the service's node by the service's build, so the old node needs no new code. The loop's own mailbox type never changes, so the library needs no `become`. The old protocol ends when its declaration and translation are deleted from the source, which the plan refuses while a process still speaks it and shows otherwise with the count of messages still translated.

**The node that stops is the one case in place does not reach.** A new `ern` or OTP, or a fault of the host, ends every process on the node. A service's state then leaves as a value to a successor elsewhere, before the stop, or is outside the process; a resource is reopened there, since no system moves a connection, and a listening socket alone can be handed (*U12*). The drain is of the node, minutes long, graded, and ending by a close (*U13*). A process that is a connection loses it.

**Two versions of a type are two types, at a price that is paid at the boundary.** The field chose to transform every value at an update and rejected coexisting versions as disastrous with side effects (*D3*). Ernest's choice is sound because values are immutable and a message is a copy, and its price is a translation wherever versions meet: an old address, a second key, a node of another build. A value of a new type is refused by its hash before any frame is decoded, which is where Orleans's rolling upgrade broke (*V5*).

## 3. What the program writes

**Nothing, for a change of logic.** A changed loop behind an unchanged `State` and `Msg` is `Upgrade(identity, step)`, which the plan writes. It is the commonest deploy and the one the field makes in place (*U9*).

**A `migrate`, where the diff cannot derive it.** For a changed `State`, `migrate` is derived by the one rule every system shares: match fields by name and type, a default for a field the new type adds, drop a field it removes, promote a number's width (*S1*, *V6*, *V11*, *D4*). A rename reads as a removal and an addition, and is told by one word in the new declaration, `was`, as Avro's and Orleans's aliases do (*S2*, *V6*). Where the rule stops, a constructor removed or changed, a field whose type changed otherwise, the derived `migrate` is written out with a hole the checker refuses as it refuses a partial `match`, never with a default (*D4*). A program may give a `migrate` for a `State` whose hash did not change, since a changed meaning behind an unchanged type is invisible to any diff (*D5*).

**A translation, where the protocol changed.** The same rule derives `translate : (Msg1) -> Msg2` where every old constructor is kept in form, and leaves a hole for a retired or changed request, which the program answers in the old answer type's failure, as part two has it (*S9*). The upgraded service serves the old key through the translation for as long as the build holds both types. A protocol is of independent requests; a conversation has no safe point between its messages and is a process of its own (*D12*).

**The old declaration stays until nothing holds it.** The new build names both types, so the previous `State` stays under its name and the new one is `State2` beside it, as part two decided for a protocol and as safecopy keeps its chain (*S11*). Deleting the old declaration and its `migrate` retires the version; a process or a stored value still of it refuses the deletion, and the plan lists it.

**A state outside the process is the store's, and its row type is Ernest's.** A database's schema is not in the hashes; the type a service reads a row into is, and the diff sees it change as it sees any `State`. A stored value migrates when it is next read, through `migrate` from every shape still in the store, and is written back in the new form at the next write (*V12*, *D9*). So a schema change is the industry's expand then contract (*S3*): the database's own change is additive while both versions of the service run against it, the new version reads the old shape and the new and writes the new, and the old shape leaves the database when no row of it remains, which the deletion of the old row type from the source marks. The plan checks the service's side, a `migrate` from each shape still stored, and cannot check the database's, and says so. In place the process keeps its connection; only the node that stops reopens one.

**The way back ships with the new build.** A previous build cannot hold a function from a type written after it (*V11*, *S11*, *V13*). The reverse `migrate` is derived and holed like the forward one; where it has a hole the plan says the change is forward-only for that service, and otherwise the way back is one more `Upgrade`, at any time, with nothing drained.

## 4. The matrix

What changed is read from the hashes by `ern diff`; what kind of process meets it is one of three.

| | a worker | a service, `Service.start` | a loop, a process of its own |
|---|---|---|---|
| **C1 the logic** | nothing | `Upgrade(identity, step)`, written by the plan | its own upgrade case (§6.10), or nothing |
| **C2 the state's shape** | nothing | `Upgrade(migrate, step)`, `migrate` derived or holed | its own |
| **C3 the protocol, every constructor kept** | nothing | the same, `translate` derived, the old key served through it | its own, by `become` where the address must be kept |
| **C4 a request retired or changed** | nothing | the same, `translate` holed for the retired request | its own |
| **C5 a type many protocols carry** | nothing | C2, C3 or C4 of every service that carries it, listed by the plan | the same |

A supervisor is a service whose `State` is its children. The platform's change ends every process on the node, as section 2 says. A worker ends on its code and the next spawn runs the new. The loop column is part two's: §6.10 by hand, and `become` with a translation where a protocol changes under an address that must be kept.

**One program for each cell**, under `experiments/code_update/`, run by the tests and written twice, as today and under the concept, so that what the design saves is measured in lines and in what can go wrong: a counter for C1 and C2; a store over a listening socket for the node that stops; the counter with `Reset` for C3 and with `Get` retired for C4; three services sharing a record for C5; a supervisor over two of them; and a chat server holding connections for the loop column.

## 5. The plan and the test

**The plan is computed from a baseline.** `ern diff` grows into the deploy's planning step. It needs the previous release's hashes and canonical forms without a running system, which the kept build directory of the last release gives, as Dapr's shipped file does (*V13*). For each service it names the row, from the hashes of its `State` and `Msg`, and the column, from how its binding is written; what the build must hold; and what is derived, holed or told. Everything the two builds decide is refused at planning, with the function named: `Counter: State changed and migrate has a hole at Reset`.

**The order of a rollout is free one way.** An old client meets the upgraded service through the translation. A new client meeting a service still on old code, on a node not yet reached, finds `OtherType` by MVP 3.1's rule and waits, as for `Unreachable` (*V4*, *S3*). A stored state migrates when next read and is written back in the new form at the next write (*V12*, *D9*); a `migrate` pure by its effect row pays nothing for being lazy (*D8*). A service's own state migrates once, at its `Upgrade`.

**What the running system decides is answered per service.** A service that does not take its `Upgrade` within its time is left as it was and named; the services before it stand upgraded; the plan prints what stands at which version and the way back for each. Nothing is suspended, and there is no point of no return, since no node restarts for a change of code (*U5*).

**The upgrade runs as a test on every commit.** The shape half runs with nothing started: each row from the baseline, each hole and each untold rename refused. The run half starts the previous build, writes a state into each service through its protocol, applies the plan, reads the state back, applies the way back and reads it again (*U11*, *D14*). The oracle is identity for a change of logic and the round trip for a changed state; a property a human writes is asked for only where the round trip is not total, which is the one piece no system has automated (*D14*, *V14*). The cost of testing by hand is the stated reason Ericsson's divisions, Elixir and WhatsApp restart instead (*U7*, *U9*), and the generated run is the answer to it.

## 6. What is to hold

What a proposal written from this would claim, each to be tested.

1. **A process keeps its code unless it acts.** It takes new code by a message in its own type, or ends (`mvp3.1.md`, claim 4; §6.10).
2. **No message of one version is read as another's**, on one node as across nodes, refused by hash before any frame is decoded.
3. **State crosses a version through `migrate` alone**, written in the build, derived where the diff decides, holed where it does not, and checked against both types.
4. **An upgrade keeps the process**: its address, its mailbox, what it owns and what it asked the runtime for.
5. **An upgrade runs the recovery path's function.** What a successor would begin from after a stop, `migrate` of the kept state, an upgrade begins from in place.
6. **Every version in flight is listed** by the plan: the processes on each code, the protocols each service serves, the stored states of each shape.
7. **What the hashes can refuse is refused before the deploy**, and what the running system decides is answered per service, nothing suspended.
8. **The way back is the new build's**, one `Upgrade` with the reverse `migrate`, or forward-only, said so.

## 7. What was read

Four readers on 2026-10-07, into [`other_systems.md`](other_systems.md), section 7: the upgrade practice, OTP's appup and relup, Elixir's releases and the proxies' hot restart (*U*); versioned actors, Orleans, Akka, Durable Functions and Dapr (*V*); schema evolution and the step-function shape, Avro, protobuf, Elm, safecopy and Smalltalk (*S*); and dynamic software updating as a field, Kitsune, Ginseng, Rubah, Ekiden, con-freeness and CLOS (*D*). Its *What recurs* is what this document was rewritten under.

## 8. Open, for the experiment programs

- The `Upgrade` message's exact shape, and who may send it: the address the service keeps, clients being given one narrowed by `via`.
- How a supervisor's children are a `State`, and whether a child keeps its place under a successor supervisor, read against `Supervisor`.
- What a step that blocks costs an upgrade, and whether the plan should refuse a service whose step may not return.
- The form of the baseline: the kept build directory, or a file of hashes and forms.
- How the test writes a state into a service through its protocol, and reads it back, without a message the protocol does not have.
- Whether `migrate` for a stored state in a keeper or a table runs at the read, as every system read does, or the keeper is upgraded like any service.

## 9. What this changes in part two

Part two of `code.md` thought through one process taking new code in place, and settled seven things for a change of protocol. This document keeps them for the loop column, and changes the frame: the step function is the service, so the upgrade case part two wanted every service to carry is the library's `Upgrade`; the handover it weighed is only for the node that stops; the forwarder it refused stays refused, since in place keeps the address; its question of how a process tells an older protocol's message from its own is answered by the library's envelope; and `become` is the one addition to the language the step function does not remove, for the loop whose protocol changes under a kept address. Part two moves here whole when the shape is agreed.
