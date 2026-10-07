# Ernest: MVP 3.2, The Ordered Rolling Restart

Status: the proposal for step D of [`code.md`](code.md)'s section 1, *The four steps*, written on 2026-10-07 from [`code_update.md`](code_update.md), whose every question was decided with the user the same day; to be read back before anything is planned or built. The reasons for what it says are `code_update.md`'s; what other systems do is [`other_systems.md`](other_systems.md), section 7; what six programs showed is [`experiments/code_update/`](experiments/code_update/README.md). Its number in the plan is taken when it is settled.

## 1. What it is

MVP 3.2 makes a deploy a rolling restart that the runtime orders and checks. One command plans the rollout from the hashes the nodes run, refuses it before it starts where it would part a client from its service, stops each node in order with its services' state handed on, starts it with the new build, checks it before the next, and runs the whole of it as a test on every commit. No code changes in a running process: a process keeps its code until it ends, as MVP 3.1 has it.

Three things bound it:

- **Nothing in place.** A deploy ends every process on a node and starts new ones. No process takes new code, no mailbox type changes, and no protocol changes under a running process.
- **One owner through a planned stop, and none promised at a failure.** A service's state has one owner at every instant of a planned stop. At a failure nothing moves by itself.
- **The team writes only what no tool can know**: a translation where a request was retired or changed, a migration where a type's diff does not decide one, and a word where a field was renamed. Everything else the hashes derive.

MVP 3.0's and MVP 3.1's bounds stay: a few nodes with one owner, listed by hand, trusted completely; no discovery; nothing the runtime retries.

**The building block.** A *rollout* is one build replacing another on every node, one node at a time. A *planned stop* is a node's end in four steps: its keys withdrawn, its calls drained, its services' state handed on, and the close. A *plan* is what the coordinator computes from two builds and prints before the first stop: for each service, what will be done and what the build must hold for it.

## 2. What a program sees

**The operations.** `Peer` gains two things and the configuration one.

```
Peer.find     : (Peer.Key(m), Int) -> Either(Peer.Failure, Address(m)) with n
Peer.standing : (Peer.Key(m), Int) -> Either(Peer.Failure, Address(m)) with n
```

- `Peer.find(key, ms)` asks the nodes `ernest.conf` lists as the key's, in order, and answers the first address offered under the key at the key's type identity, with MVP 3.0's failures; `Peer.find(name, key, ms)` stays, for one named node.
- `Peer.standing(key, ms)` answers an address that finds again: its process holds the key, monitors the service, and finds it again among the key's nodes when told it went. A send to it while the service is away is dropped, as a send during a loss is; a call waits by its own time and answers `None` where the service is not back; a monitor on the service says it went. Nothing else differs from an address `Peer.find` gives.
- `ernest.conf` gains a section `keys`: for a key's name, the peers that may offer it, by their aliases, in the order a find asks them. A key not listed is found on one named node, as in MVP 3.0.

**The commands.** `ern deploy build --config-dir dir` is the coordinator: a node like the shell, listed by the nodes it deploys to. It prints the plan and waits for a yes, then does the rollout, and prints what stands at which version when it ends or stops. Run again after a crash or a cancel, it continues from where the nodes are. `ern stop --config-dir dir` is the planned stop, by `ernest.pid`; the signal the machine's service manager sends stays the quick end. Both take `--drain ms`, the drain's bound.

**What the program writes.** For a service whose protocol changes, a function `forward : (OldMsg, Address(NewMsg)) -> Unit with n`, in the build that serves both; where every old constructor is kept in form the tool writes it. For a state type that changes, `migrate : (OldState) -> NewState`, derived where the diff decides it, written where it does not, and the same the other way. A renamed field is told by `was` in the new declaration. A new declaration takes a module of its own, and the old stays where it is until the build that drops it.

**The state file.** A node writes, at its planned stop, the state of each service it alone may offer to `state/` in its configuration directory, one file for each key, and the new build's service reads it at its start. A program sees nothing of it but the directory.

**The refusal.** `Supervisor.child`'s function run inside a process that is already a child faults with `Fault("a process runs one child function")`.

## 3. Examples

The counter of [`mvp3.0.md`](mvp3.0.md)'s section 3 runs on the store, found by `Counter.key`, with the desk and the board as clients. `ernest.conf` on the desk and the board lists the key's nodes as the store, then the backup. Every node runs build 1.

**A fix behind the protocol.** Build 2 changes `count` to log each `Add`. `ern deploy build2` prints:

```
plan: build 1 to build 2
  Counter.key   logic changed             nothing to write
order: store, backup, desk, board
```

The operator says yes. The store's keys are withdrawn; the desk's and the board's finds go to the backup, where nothing offers the key yet, so a standing address waits and a call through it answers `None` at its time; the store drains, writes nothing, since the counter's state may move, moves the counter to the backup, and closes; the store starts with build 2 and is checked; and so on through the four. The board sees one `Down` with `Unreachable` per node that stopped, which its standing address absorbs.

**A changed protocol.** Build 3 adds `Reset` to `Counter.Msg`, in a module of its own, `counter2.ern`, with `Counter.Msg` kept and `Counter2.forward` written by the tool. `ern deploy build3` prints:

```
plan: build 2 to build 3
  Counter2.key  protocol added Reset       Counter2.forward, derived
  Counter.key   served through Counter2.forward until build 4 drops it
order: store, backup, desk, board
```

A board still on build 2 finds `Counter.key` on a node of build 3 and is served through the `forward`. Build 4 deletes `Counter.Msg` and `Counter2.forward`; `ern deploy build4` refuses while any node runs build 2, and accepts when none does.

**A changed state.** Build 5 changes the counter's state from an `Int` to a record that also counts the adds. `ern deploy build5` prints:

```
plan: build 4 to build 5
  Counter2.key  state changed: Count       Counter2.migrate, derived: adds = 0
                the way back               Counter2.migrate back, derived
order: store, backup, desk, board
```

Had the record's new field no default, the plan would have printed the hole and refused.

## 4. What holds

1. **No message of one version is read as another's**, refused by its hash before any frame is decoded.
2. **A rollout the plan refuses never starts**: a changed protocol the new build does not also serve the old way, a crossing state without a `migrate`, a build that drops a protocol while a node still speaks it.
3. **Through a planned stop a service's state has one owner at every instant.**
4. **The next node is not touched until the last answers** its keys at the identities the plan expects.
5. **State crosses a version through `migrate` alone**, derived where the diff decides, written where it does not, and never with a default the program did not write.
6. **Every version in flight is listed**: the build each node runs, the protocols each service serves, the stored states of each shape.
7. **The way back during a rollout is the previous build**, node by node; after the build that drops the old protocol it is forward.
8. **A process keeps its code until it ends.**
9. **A client reaches its service after a restart without code of its own**, through `Peer.standing`.
10. **The team writes only what no tool can know.**

## 5. What does not hold

MVP 3.0's and MVP 3.1's limits stand.

1. **A service with one eligible node is away for its node's restart**, seconds, through which a standing address drops sends and a call answers `None` at its time.
2. **At a failure nothing moves.** A service whose node is lost is unavailable until the node returns or an operator edits the configuration; one owner across a failure needs a lease in a store outside the nodes, a library's.
3. **A connection holder loses its connections at its node's restart.** A process that keeps them does so behind a protocol that never changes, with its logic in a service beside it.
4. **Two of a key's nodes offering at once is possible by mistake**, as two services under one name on one node are; the find answers the first.
5. **A find over a key's nodes may dial several**, where a service has moved; the list bounds it.
6. **A changed meaning behind an unchanged type is invisible to the plan**, which sees declarations and not code's intent; a program may give a `migrate` whose types are equal.
7. **A protocol that is a conversation has no point between its messages where versions change**; a conversation is a process of its own, and a protocol is of independent requests.
8. **The database's side of a schema change is not checked.** The plan checks a `migrate` from every row shape still stored, and says it cannot check the database.
9. **A change whose reverse `migrate` has a hole is forward-only**, which the plan says.
10. **Where the order's graph has a cycle, some finds wait during the rollout**, which the plan names.
11. **A retry is the program's.** A call that answered `None` may or may not have run, so a request must be harmless when run twice.
12. **A drain does not grow firmer**; what a process has not finished by the close it loses, as at any restart.

## 6. How it works

**The plan.** The coordinator reads from each node the hashes its build runs, and from the new build its hashes and canonical forms; `ern diff` over the two is the plan's first half. For each key, from the configuration and from what the nodes offer: the identity of its protocol and of its service's state type in each build; whether the new build holds a `forward` from the old protocol, a `migrate` from the old state and one back, and whether each is derived, written or a hole. A protocol unchanged and a state unchanged is nothing to do. A protocol changed is accepted where the new build serves the old one too, by a `forward` the plan names, and refused otherwise. A state changed is accepted where the `migrate` is whole. A build that drops a protocol is accepted where no node runs a build older than the one that first served both, and refused otherwise. The plan prints each service's line and the order, and the refusals name the function: `Catalog: Msg changed and the build does not serve Catalog.Msg of build 4`. Nothing starts before the yes.

**What is derived.** `migrate` is derived by one rule: fields matched by name and type, a default for a field the new type adds, a field the new type drops dropped, a number promoted to a wider width; a field renamed is matched by `was` in the new declaration, `stock : Int was count`. Where the rule stops the derived function is written out with a hole, which the checker refuses as it refuses a partial `match`, so the build does not compile until the program fills it. `forward` is derived where every constructor of the old protocol is kept in form, each to its namesake, and holed for a constructor retired or changed; the program's `forward` answers a retired request by asking the new service and answering the old caller, and converts an answer whose type changed back to the old type.

**The new declaration takes a module of its own.** A type's qualified name is in its identity, so the old declaration stays where it is while any node may hold a value of it, and the new one is declared in a new module, `counter2.ern`, whose clients write its name. Deleting the old declaration with its `forward` or `migrate` is the act that drops the version, which the plan accepts when no node is older than the build that first served both. A `forward` and a `migrate` live in the new module beside the new declaration.

**Two builds for a changed protocol.** The first serves both protocols: it offers the new key, and the old key through the `forward`, under which an old client and a new service meet in any order. The second drops the old. The plan enforces the two; a build that changes a protocol and drops the old at once is refused.

**The order.** The coordinator knows which keys each node offers and which keys each node's code finds, since a find is a reference the hashes see. It orders the nodes so that a node offering a changed service goes before the nodes whose code finds it, and in that order a new client never finds an old service. Where the graph has a cycle the coordinator picks an order and the plan names the finds that will wait.

**The planned stop.** `ern stop`, or the coordinator's frame carrying the drain's bound and the next build's root hashes, runs four steps on the node. First, the node withdraws its keys: a find from a peer answers `NotOffered`, and a standing address asks the key's next node. Second, the drain: the node waits until no call waits on any of its services and their mailboxes are empty, or the bound passes, a minute unless `--drain` says otherwise. Third, each service's state: a service whose key another node may offer, which the coordinator names, is moved there, the successor started on that node by `Peer.spawn` from the next build's code, which the cache holds, with the state as a captured value, through `migrate` on the successor's side, and the old service forwards to it until the close; a service whose key this node alone may offer writes its state to the file; a service whose state cannot cross, by §3.11's rule, writes nothing and begins afresh. Where the next build is older, the state is written through the reverse `migrate`, which the stopping build holds. Fourth, the close: the node ends as a node ends, in order, and the loss is the ordinary one.

**The state file.** Under `state/` in the configuration directory, one file for each key the node alone may offer, named by the key's name, holding the hash of the state type's identity and then the value in the encoding a value crosses in. It is written to a temporary name and renamed. The service that offers the key reads it at its start, through `migrate` where the hash is not its own state type's, and removes it; where its build holds no `migrate` from that hash the service begins afresh and says so on its standard error, which the plan said before the yes.

**Lockstep.** After a node's planned stop the coordinator starts it with the new build, waits until the node offers its keys, and finds each key at the identity the plan expects; then the next node. A node that does not answer within the plan's time stops the rollout: the coordinator starts that node with the previous build, the other nodes stand as they are, and the plan prints what stands at which version. The coordinator keeps no record: each node answers which build it runs, so a second `ern deploy` of the same build continues.

**The way back.** `ern deploy` of the previous build is a rollout like any other, accepted while every protocol the previous build speaks is still served, which holds until the build that dropped one; the state files and the moves go through the reverse `migrate`, which the newer build holds. After the drop the way back is forward.

**The cache.** Each node keeps the code it runs on its disk, by hash: the closures of the builds it has run and of the one it is about to run. The coordinator sends a node the next build's root hashes before its stop; the node fetches the closure it lacks by MVP 3.1's exchange at a spawn, each definition verified against its hash on arrival, and holds it apart until the closure is complete. A node restarts into a build from its cache and nothing else. A build's hashes leave the cache when a newer build has run on the node and the plan no longer names the old one as the way back, which is the drop of its protocols. No build directory is copied to a node.

**The standing address.** `Peer.standing(key, ms)` spawns a process on the caller's node that finds the key, holds the address found, monitors its process, and gives the caller `via` of itself; what it is sent it forwards. Told that the service went, it finds the key again among its nodes, with MVP 3.0's dial and time, and forwards again when found; meanwhile a message is dropped, and a call through it, which waits by its own time, answers `None` where the service is not back. A monitor on the service, which the caller makes through the address found or through `Process.fromAddress`, says what happened as any monitor does.

**The refusal.** `Supervisor.child`'s function reads the process's start cause when it begins; run inside a process that is already a child it would read the outer child's, so it faults instead with `Fault("a process runs one child function")`, and E.22 says so.

**The test.** `ern test --config-dir dir` runs the rollout's test where a build names the previous one. The shape half runs with nothing started: each service's line of the plan, each hole and each untold rename refused. The run half starts two nodes: it generates values of each service's state type from the previous build and writes them as the state files a stop would have written; starts the previous build on both nodes; rolls one node to the new build, checks every key at the identity the plan expects, rolls the other, and stops both; and compares what the stops wrote with what went in, identity where the state type is unchanged and the round trip through the reverse `migrate` where it changed. It rolls back the same way. A service whose state cannot cross is skipped and listed. The test sends no message of any protocol.

## 7. The numbers

| What | Value |
|---|---|
| the drain | 60,000 ms unless `--drain` says otherwise; ends early when nothing waits |
| a find over a key's nodes | at most one dial per node listed, each MVP 3.0's |
| the coordinator's wait for a restarted node | the drain's bound |
| the state file | `state/<key>` in the configuration directory, the type's hash then the value |
| a build's stay in the cache | until a newer build has run and the plan names the old as no way back |

## 8. How it is checked

The plan has a test suite of its own: two builds differing in each of the matrix's rows, and the plan's line for each, derived, written, holed or refused; a build that drops a protocol refused while an older node runs and accepted after; the order from a graph with and without a cycle.

The runtime's tests run three nodes on one machine, as MVP 3.0's do: a planned stop writes the file, withdraws the keys, moves a service with two nodes listed and writes one with one, and closes in order; a service reads its file through `migrate` and removes it, and begins afresh where no `migrate` fits; `Peer.standing` drops a send and answers `None` to a call while the service is away, and reaches it again where it comes back on the same node and on another; a rollout in lockstep stops at a node that does not answer and puts it back; a rollback through the reverse `migrate`; the cache holding the next build before the stop and letting an old one go; the refusal of E.22; and the generated test itself, run over the experiment programs' builds.

## 9. Unsolved

What remains is the build's: a generator of values for a type, which the test needs and the descriptors give; the exact syntax of `was`; the frame the coordinator sends a node, one or several; the texts of the plan's lines; the report's sentences, §8.7 for the rollout and the planned stop, §11.2 for `ern deploy` and `ern stop`, Appendix E for `Peer.find`, `Peer.standing` and E.22's refusal, §11.3 for `keys` in `ernest.conf`; and the soundness argument's paragraph for the state file and `migrate`.

## 10. Left out on purpose

- A change of a running process's code, a change of its mailbox type under a translation, and the library's `Upgrade`: nothing in place, section 1; what they would cost is `code_update.md`'s section 4.
- An election, a lease, and a service that moves by itself at a failure: a library's over a store outside the nodes.
- A drain that grows firmer: the runtime holds no connections of its own.
- A set of addresses under one key, a service offered by several nodes at once.
- A registry nodes share, and discovery.
- The database's side of a schema change.
- A plan that reasons about a changed meaning behind an unchanged type.

## 11. Room for what comes after

- **A change of code in place**, with `become`, where a deployment shows that a restart's gap matters for a process that holds connections; the experiments say what it costs.
- **A key offered by several nodes at once**, which the `keys` section's shape already allows a find to ask.
- **MVP 3.1a's rolling release of `ern` itself**, which this rollout then carries, the cookie narrowed to the runtime's surface.
- **A coordinator that runs unattended**, taking the yes from a flag, once the plan has been read often enough to be trusted.
