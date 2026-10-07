# Ernest: MVP 3.2, The Ordered Rolling Restart

Status: the proposal for step D of [`code.md`](code.md)'s section 1, *The four steps*, written on 2026-10-07 from the thinking that is now [`deploy.md`](deploy.md), whose every question was decided with the user the same day, and settled with the user the same day. The reasons for what it says are [`deploy.md`](deploy.md)'s; what other systems do is [`other_systems.md`](other_systems.md), section 7; what six programs showed is [`experiments/code_update/`](experiments/code_update/README.md).

## 1. What it is

MVP 3.2 makes a deploy a rolling restart that the runtime orders and checks. One command plans the rollout from the hashes the nodes run, refuses it before it starts where it would part a client from its service, stops each node in order with its kept state written, which restarts itself into the new build, checks it before the next, and runs the whole of it as a test on every commit. No code changes in a running process: a process keeps its code until it ends, as MVP 3.1 has it.

Three things bound it:

- **Nothing in place.** A deploy ends every process on a node and starts new ones. No process takes new code, no mailbox type changes, and no protocol changes under a running process.
- **One owner, and nothing moved.** A kept state is held by one process, or by the file between two. Nothing moves a state to another node, at a planned stop or at a failure.
- **The team writes only what no tool can know**: a translation where a request was retired or changed, a migration where a type's diff does not decide one, and a word where a field was renamed. Everything else the hashes derive.

MVP 3.0's and MVP 3.1's bounds stay: a few nodes with one owner, listed by hand, trusted completely; no discovery; nothing the runtime retries.

**The building block.** A *build* is an entry point's closure, named by its *root*, the hash of the entry point's definition, inside which every hash of the closure is. A *rollout* is one build replacing another on every node, one node at a time. A *planned stop* is a node's end in four steps: its keys withdrawn, its calls drained, its kept states written, and the close; one that carries a next build is followed by the node's restart into it, inside the same host process. A *plan* is what the coordinator computes from two builds and prints before the first stop: for each service, what will be done and what the build must hold for it.

## 2. What a program sees

**The operations.** §9.5 gains one function and a library is written; `Peer.find(key, ms)` and the `keys` section are MVP 3.0's, used here.

```
Peer.find     : (Peer.Key(m), Int) -> Either(Peer.Failure, Address(m)) with n
kept          : (Peer.Key(m), () -> s with m, (s, m) -> s with m) -> () -> Unit with m
Standing.start : (Peer.Key(m), Int) -> Address(m) with n
```

- `Peer.find(key, ms)` and `keys` are as mvp3.0.md's section 2 has them: a key's nodes are the configuration's, in the order a find asks them.
- `Standing.start(key, ms)`, of the library `Standing` under `libs/`, spawns a process that finds the key and forwards to the service what it is sent, and answers `via` of that process; it is an ordinary process the program spawned, and every rule of the report holds of its address as of any. It finds the key within `ms`, monitors the service, finds again when the service ends or its node is lost, with `ms` between finds while a find fails, and ends with the process that started it. A send to it while the service is away is dropped, as a send during a loss is, and a call through it waits by its own time and answers `None` where the service is not back. A program that is to monitor the service itself holds the address `Peer.find` gives.

**The commands.** `ern deploy build --config-dir dir` is the coordinator: a node like the shell, listed by the nodes it deploys to. It prints the plan and waits for a yes, then does the rollout, and prints what stands at which version when it ends or stops. Run again after a crash or a cancel, it continues from where the nodes are. Termination is the planned stop: from the machine's service manager, from `ern stop --config-dir dir`, which sends it by `ernest.pid`, and from `kill -TERM` alike, a node withdraws its keys, drains, writes its kept states and closes, and then restarts where a next build was carried and ends where none was. There is one way a node ends. The interrupt is the quick end, as §8.6 has it for a program, and a second termination during the drain ends the drain and goes on to the states and the close. The drain's bound is the node's time, `drain` in `ernest.conf`, a minute unless the configuration says otherwise, which also bounds the coordinator's wait for the node to be back; the node tells the coordinator its time and each kept state's size, and the plan prints them. The configuration directory names the build the node runs, in its file `build`: `ern run --config-dir dir prog.erc` runs the program and writes its root there, and `ern run --config-dir dir` runs the build the file names, from the cache, and is MVP 3.1's bare node where the file names none. So a node started by anyone, the machine's service manager or an operator, runs the build the last planned stop named.

**A kept state.** `kept(key, init, step)` is a function of `restarting`'s family: it runs a loop the runtime owns, whose state is what `init` gives, and runs `step` on each message, over the state and the message, for the next state. The runtime holds the state between steps, and at a planned stop asks the process for it between two steps, as a supervisor asks for a restart (§6.9); the loop then holds what arrives until the close. Where the state file holds a state under the key, the loop begins with it, through `migrate` where its type changed, and `init` is not run. `kept` composes with `spawn` and `restarting`: a fault in `step` restarts the loop from `init`, with nothing of the old run, as §6.9 says of every restart. A service whose state is to outlive a deploy is a `kept` loop; any other process begins afresh at its node's restart, and a deploy promises it nothing.

**What the program writes.** For a service whose protocol changes, a function `forward : (OldMsg, Address(NewMsg)) -> Unit with n`, in the build that serves both; where every old constructor is kept in form the tool writes it. For a state type that changes, `migrate : (OldState) -> NewState`, derived where the diff decides it, written where it does not, and the same the other way. A renamed field is told by `was` in the new declaration. A new declaration takes a module of its own, and the old stays where it is until the build that drops it.

**The state file.** A node writes, at its planned stop, each kept state to `state/` in its configuration directory, one file for each key, and the `kept` loop under that key reads it at its start, in place of `init`. A program sees nothing of it but the directory.

**The refusal.** `Supervisor.child`'s function run inside a process that is already a child faults with `Fault("a process runs one child function")`.

## 3. Examples

The counter of [`mvp3.0.md`](mvp3.0.md)'s section 3 runs on the store, found by `Counter.key`, with the desk and the board as clients. The store keeps its total through `kept`, so that a deploy carries it, and is otherwise as MVP 3.0 has it:

```ernest-fragment
// store.ern, build 1

let counter : Address(Counter.Msg) =
    spawn(restarting(RestartLimit(restarts = 3, within = 5000),
                     kept(Counter.key, fn() = 0, step)))

fn step(total : Int, message : Counter.Msg) : Int with Counter.Msg =
    match message {
        Counter.Add(amount) -> total + amount
      | Counter.Get(reply = reply) -> {
            answer(reply, total);
            total
        }
    }

export fn main() : Unit with Never = {
    Peer.offer(Counter.key, counter);
    wait()
}
```

The desk and the board are as they are in MVP 3.0, but that the board holds `Standing.start(Counter.key, 5000)` in place of its find. `ernest.conf` on the desk and the board lists the key's nodes as the store, then the backup. Every node runs build 1.

**A fix behind the protocol.** Build 2 changes `count` to log each `Add`. `ern deploy build2` prints:

```
plan: build 1 to build 2
  Counter.key   logic changed             nothing to write
order: store, backup, desk, board
```

The operator says yes. The store's keys are withdrawn, and a find of the key answers `NotOffered` on every node, so the board's standing address waits and a call through it answers `None` at its time; the store drains, asks the counter for its total, writes it to `state/counter`, and closes; the store starts with build 2, the counter begins with the total from the file, `main` offers it, the board's standing address finds it again, and the coordinator checks the key; then the backup, the desk and the board the same way. The board's standing process sees one `Down` with `ProgramEnd` per node that stopped, and finds again.

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
9. **A client reaches its service after a restart without code of its own**, through the `Standing` library.
10. **The team writes only what no tool can know.**
11. **Two releases of `ern` with one runtime surface connect**, and a release of `ern` that keeps the surface is a rollout.

## 5. What does not hold

MVP 3.0's and MVP 3.1's limits stand.

1. **A service is away for its node's restart**, seconds, from the moment its state is handed to its first offer, since nothing tells a finder of a withdrawal; a standing address drops sends through it, and a call answers `None` at its time.
2. **Nothing moves a state to another node.** A service whose node is lost is unavailable until the node returns or an operator moves the program and its state file; one owner across a node's loss or a hot standby needs a lease in a store outside the nodes, a library's.
3. **A connection holder loses its connections at its node's restart.** A process that keeps them does so behind a protocol that never changes, with its logic in a service beside it.
4. **Two of a key's nodes offering at once is possible by mistake**, as two services under one name on one node are; the find answers the first.
5. **A find over a key's nodes may dial several**, where the operator has moved a program; the list bounds it.
6. **A changed meaning behind an unchanged type is invisible to the plan**, which sees declarations and not code's intent; a program may give a `migrate` whose types are equal.
7. **A protocol that is a conversation has no point between its messages where versions change**; a conversation is a process of its own, and a protocol is of independent requests.
8. **The database's side of a schema change is not checked.** The plan checks a `migrate` from every row shape still stored, and says it cannot check the database.
9. **A change whose reverse `migrate` has a hole is forward-only**, which the plan says.
10. **Where the order's graph has a cycle, some finds wait during the rollout**, which the plan names.
11. **A retry is the program's.** A call that answered `None` may or may not have run, so a request must be harmless when run twice.
12. **A drain does not grow firmer**; what a process has not finished by the close it loses, as at any restart.
13. **A release of `ern` that changes the runtime's surface stops every node.**
14. **A machine rebuilt from nothing starts by hand.** It has a new key and an empty cache; its first start is `ern run --config-dir dir prog.erc` with a build directory on it, and the nodes' `ernest.conf` lists its key.

## 6. How it works

**The plan.** The coordinator asks each node, by one frame, its build, the root it started from, the keys it offers with their type identities, and the kept states it holds with theirs; and reads from the new build its hashes and canonical forms; `ern diff` over the two is the plan's first half. For each key, from the configuration and from what the nodes offer: the identity of its protocol and of its service's state type in each build; whether the new build holds a `forward` from the old protocol, a `migrate` from the old state and one back, and whether each is derived, written or a hole. A protocol unchanged and a state unchanged is nothing to do. A protocol changed is accepted where the new build serves the old one too, by a `forward` the plan names, and refused otherwise. A state changed is accepted where the `migrate` is whole. A build that drops a protocol is accepted where no node runs a build older than the one that first served both, and refused otherwise. The plan prints each service's line, the order, and the builds the way back can reach after this rollout; the refusals name the function: `Catalog: Msg changed and the build does not serve Catalog.Msg of build 4`. Before the plan is printed the coordinator tells every node the next build's root, each node fetches what it lacks and writes it to its cache, and a node that cannot, its disk full or its cache refusing, fails the plan naming the node and the cause. Nothing starts before the yes, and the yes is asked only when every node holds the next build whole.

**What is derived.** `migrate` is derived by one rule: fields matched by name and type, a default for a field the new type adds, a field the new type drops dropped, a number promoted to a wider width; a field renamed is matched by `was` in the new declaration, `stock : Int was count`. Where the rule stops the derived function is written out with a hole, which the checker refuses as it refuses a partial `match`, so the build does not compile until the program fills it. `forward` is derived where every constructor of the old protocol is kept in form, each to its namesake, and holed for a constructor retired or changed; the program's `forward` answers a retired request by asking the new service and answering the old caller, and converts an answer whose type changed back to the old type.

**The new declaration takes a module of its own.** A type's qualified name is in its identity, so the old declaration stays where it is while any node may hold a value of it, and the new one is declared in a new module, `counter2.ern`, whose clients write its name. Deleting the old declaration with its `forward` or `migrate` is the act that drops the version, which the plan accepts when no node is older than the build that first served both. A `forward` and a `migrate` live in the new module beside the new declaration.

**Two builds for a changed protocol.** The first serves both protocols: it offers the new key, and the old key through the `forward`, under which an old client and a new service meet in any order. The second drops the old. The plan enforces the two; a build that changes a protocol and drops the old at once is refused.

**The order.** The coordinator knows which keys each node offers and which keys each node's code finds, since a find is a reference the hashes see. It orders the nodes so that a node offering a changed service goes before the nodes whose code finds it, and in that order a new client never finds an old service. Where the graph has a cycle the coordinator picks an order and the plan names the finds that will wait.

**The planned stop.** Termination, or the coordinator's frame carrying the next build's root, runs four steps on the node. First, the node withdraws its keys: a find from a peer answers `NotOffered`. Second, the drain: the node waits until no call waits in its table of calls, which the call's note fills for a remote caller, and every `kept` loop is idle, between two steps with an empty mailbox, or until its time passes, `drain` in its configuration. A request in flight at that moment, or in another process's hands, is lost with what the loop holds, as limit 12 says. A call that reaches a service through a standing process is the service's to the drain, since the forwarder sends the request on and the service answers the caller directly. Third, each kept state: the node asks each `kept` loop for its state between two steps, writes it to the file, and the loop holds what arrives from then, which is lost at the close. A state that cannot cross, by §3.11's rule, is not written, and the next build's loop begins with `init`. Where the next build is older, the state is written through the reverse `migrate`, which the stopping build holds. Where a next build was carried, its root is written to the directory's `build` file before the close. Fourth, the close: the node ends as a node ends, in order, and the loss is the ordinary one. A stop that carried a next build does not end the host process: the runtime restarts inside it, by the host's own restart from the same command line, and `ern` runs the build the directory names. The pid is unchanged, so `ernest.pid` stays true and the service manager sees nothing. `ern stop` and the signal end the process.

**The state file.** Under `state/` in the configuration directory, one file for each kept state, named by its key's name, holding the hash of the state type's identity and then the value in the encoding a value crosses in. It is written to a temporary name and renamed. The `kept` loop under the key reads it at its start, through `migrate` where the hash is not its own state type's; where its build holds no `migrate` from that hash the loop begins with `init` and says so on its standard error, which the plan said before the yes. The node removes the files it read once it listens, every initializer having its value, so that a start which fails leaves them for the build that comes back.

**Lockstep.** After a node's planned stop the coordinator waits until the node is back and offers its keys, and finds each key at the identity the plan expects; then the next node. The coordinator starts nothing: the node restarts itself, and one that is gone for another reason is the service manager's to start, and runs what its directory names. A start that fails goes back by itself: a restart into a next build whose initializer faults writes the previous build to the `build` file and restarts into it, once, and a second fault ends the node as a faulting initializer ends a program. A node that is up but does not offer its keys within its time stops the rollout: the coordinator sends it a planned stop that carries the previous build, the other nodes stand as they are, and the plan prints what stands at which version. The coordinator keeps no record: each node answers which build it runs, so a second `ern deploy` of the same build continues.

**The way back.** `ern deploy` of the previous build is a rollout like any other, accepted while every protocol the previous build speaks is still served, which holds until the build that dropped one; the state files go through the reverse `migrate`, which the newer build holds. After the drop the way back is forward.

**The cache.** Each node keeps the code it runs on its disk, by hash, as mvp3.1.md's section 6 has it: each definition's canonical form with its compiled unit, for the builds it has run and the one it is about to run. Told the next build's root before the plan, the node fetches the closure it lacks from the coordinator by MVP 3.1's exchange, each definition verified against its hash on arrival, compiles it, and writes it; it loads nothing until its restart. A node restarts into a build from its cache and nothing else, verifying every form against its hash as it loads, and compiling nothing. A build leaves the cache when the plan has printed that no way back reaches it, the drop of its protocols. No build directory is copied to a node.

**What passes.** Beside MVP 3.0's and MVP 3.1's frames, three of Ernest's: the coordinator's question to a node, its build, offers and kept states, and the answer; the next build's root, which the exchange's four frames follow; and the planned stop, with the next build's root. The withdrawal is no frame: a find answers `NotOffered`.

**The standing address.** `Standing.start(key, ms)` is Ernest, in a library, and the runtime has no part in it. Its process has the mailbox type `Message(m) | Went(Down)`, and the caller is given `via` of it with `Message`. It finds the key by `Peer.find(key, ms)`, holds the address found, monitors the service's process, and forwards each `Message`; at `Went` it finds again, and where a find fails it waits `ms` and finds again. A message that arrives while no address is held is dropped. It monitors the process that called `start` and ends at its `Down`, so that nothing is left finding. The forwarder is one more process on a message's way, and a message through it may pass a message sent directly, as through any process (mvp3.0.md's claim 4.1).

**The runtime's surface, and a release of `ern` as a rollout.** Decided with the user on 2026-10-07 to be this milestone's and not one of its own: the cookie is the digest of the protocol's version, the hash scheme's version, OTP's version and the version of the runtime's surface, in place of `ern`'s whole version. The surface is what shipped code calls by name, the runtime's functions and the standard library's foreign declarations, named and given a version of its own that changes when it does, so that two releases of `ern` with one surface connect and a release of `ern` is a rollout like a program's, which `ern deploy` carries. A release that changes the surface still stops every node, and says so in its notes.

**The refusal.** `Supervisor.child`'s function reads the process's start cause when it begins; run inside a process that is already a child it would read the outer child's, so it faults instead with `Fault("a process runs one child function")`, and E.22 says so.

**The test.** `ern test --config-dir dir` runs the rollout's test where a build names the previous one. The shape half runs with nothing started: each service's line of the plan, each hole and each untold rename refused. The run half starts two nodes: it generates values of each service's state type from the previous build and writes them as the state files a stop would have written; starts the previous build on both nodes; rolls one node to the new build, checks every key at the identity the plan expects, rolls the other, and stops both; and compares what the stops wrote with what went in, identity where the state type is unchanged and the round trip through the reverse `migrate` where it changed. It rolls back the same way. A service whose state cannot cross is skipped and listed. The test sends no message of any protocol.

## 7. The numbers

| What | Value |
|---|---|
| a node's time, `drain` in `ernest.conf` | 60,000 ms unless the configuration says otherwise; the drain ends early when nothing waits |
| a find over a key's nodes | at most one dial per node listed, each MVP 3.0's |
| the coordinator's wait for a restarted node | the node's time |
| the state file | `state/<key>` in the configuration directory, the type's hash then the value; removed once the node listens |
| the build file | `build` in the configuration directory, the root of the build the node runs |
| a failed start's way back | one restart into the previous build; a second fault ends the node |
| a service's absence at its node's restart | the restart's time: the close, the start, the first offer |
| a build's stay in the cache | until the plan has printed that no way back reaches it |
| the frames of this milestone | three, beside MVP 3.0's seven and MVP 3.1's four |

## 8. How it is checked

The plan has a test suite of its own: two builds differing in each of the matrix's rows, and the plan's line for each, derived, written, holed or refused; a build that drops a protocol refused while an older node runs and accepted after; the order from a graph with and without a cycle.

The runtime's tests run three nodes on one machine, as MVP 3.0's do: a planned stop withdraws the keys, writes each kept state's file, and closes in order; a kept loop reads its file through `migrate` and removes it, and begins afresh where no `migrate` fits; the `Standing` library's tests drop a send and answer `None` to a call while the service is away, reach it again where it comes back on the same node and on another, and end the standing process with its caller; a rollout in lockstep stops at a node that does not answer and puts it back; a rollback through the reverse `migrate`; the cache holding the next build before the stop and letting an old one go; the refusal of E.22; and the generated test itself, run over the experiment programs' builds.

## 9. Unsolved

What remains is the build's: a generator of values for a type, which the test needs and the descriptors give; the exact syntax of `was`; the texts of the plan's lines; the naming of the runtime's surface, measured by what the exchange ships and what it calls by name; the report's sentences, §8.7 for the rollout and the planned stop, §11.2 for `ern deploy` and `ern stop`, §9.5 for `kept`, Appendix E for `Peer.find` and E.22's refusal, §11.3 for `keys` and `drain` in `ernest.conf` and the `build` file, §8.6 for termination as the planned stop, and §11.2 for a node's restart inside its process; the glossary's words, *build*, *root*, *kept state*, *planned stop*, *rollout* and *plan*, in Appendix F and in `docs/style.md`, written with the report's sentences; and the soundness argument's paragraph for the state file and `migrate`.

## 10. Left out on purpose

- A change of a running process's code, a change of its mailbox type under a translation, and the library's `Upgrade`: nothing in place, section 1; what they would cost is [`deploy.md`](deploy.md)'s section 15.
- A state moved to another of its key's nodes for its node's restart; a hot standby is a lease's, below.
- An election, a lease, and a service that moves by itself at a failure: a library's over a store outside the nodes.
- A drain that grows firmer: the runtime holds no connections of its own.
- A set of addresses under one key, a service offered by several nodes at once.
- A registry nodes share, and discovery.
- The database's side of a schema change.
- A plan that reasons about a changed meaning behind an unchanged type.

## 11. Room for what comes after

- **A change of code in place**, with `become`, where a deployment shows that a restart's gap matters for a process that holds connections; the experiments say what it costs.
- **A key offered by several nodes at once**, which the `keys` section's shape already allows a find to ask.
- **A kept state that follows a lease**, so that a singleton is not away for its node's restart, once a library holds a lease in a store outside the nodes.
- **A coordinator that runs unattended**, taking the yes from a flag, once the plan has been read often enough to be trusted.
