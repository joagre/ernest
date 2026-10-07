# Ernest: MVP 3.2, The Ordered Rolling Restart

Status: the proposal for step D of [`code.md`](code.md)'s section 1, *The four steps*, written on 2026-10-07 from the thinking that is now [`deploy.md`](deploy.md), whose every question was decided with the user the same day, and settled with the user the same day. The reasons for what it says are [`deploy.md`](deploy.md)'s; what other systems do is [`other_systems.md`](other_systems.md), section 7; what six programs and the library they share showed is [`experiments/code_update/`](experiments/code_update/README.md).

## 1. What it is

MVP 3.2 makes a deploy a rolling restart that the runtime orders and checks. One command plans the rollout from the hashes the nodes run, refuses it before it starts where it would part a client from its service, stops each node in order with its kept state written, which restarts itself into the new build, checks it before the next, and runs the whole of it as a test on every commit. No code changes in a running process: a process keeps its code until it ends, as MVP 3.1 has it.

Three things bound it:

- **Nothing in place.** A deploy ends every process on a node and starts new ones. No process takes new code, no mailbox type changes, and no protocol changes under a running process.
- **One owner, and nothing moved.** A kept state is held by one process, or by the file between two. Nothing moves a state to another node, at a planned stop or at a failure.
- **The team writes two things, and is told which.** A `migrate` where a kept state's type changed, and a conversion or a `forward` where a protocol changed; the plan names each before anything stops, and `ern diff` prints the text to paste. Nothing is derived into source.

MVP 3.0's and MVP 3.1's bounds stay: a few nodes with one owner, listed by hand, trusted completely; no discovery; nothing the runtime retries.

**The building block.** A *build* is the set of entry points compiled together, a build directory; each entry point's closure is named by its *root*, the hash of the entry point's definition, inside which every hash of the closure is, and a node's root is the entry point it runs. A *rollout* is one build replacing another on every node whose root differs between the two, one node at a time. A *planned stop* is a node's end in four steps: its keys withdrawn, its calls drained, its kept states written, and the close; one that carries a next build is followed by the node's restart into it, inside the same host process. A *plan* is what the coordinator computes from two builds and prints before the first stop: for each service, what will be done and what the build must hold for it.

## 2. What a program sees

**The operations.** §9.5 gains one function and a library is written; `Peer.find(key, ms)` and the `keys` section are MVP 3.0's, used here.

```
Peer.find     : (Peer.Key(m), Int) -> Either(Peer.Failure, Address(m)) with n
kept          : (Peer.Key(m), () -> s with m, (s, m) -> s with m) -> () -> Unit with m
Standing.start : (Peer.Key(m), Int) -> Address(m) with n
```

- `Peer.find(key, ms)` and `keys` are as mvp3.0.md's section 2 has them: a key's nodes are the configuration's, in the order a find asks them.
- `Standing.start(key, ms)`, of the library `Standing` under `libs/`, spawns a process that finds the key and forwards to the service what it is sent, and answers `via` of that process; it is an ordinary process the program spawned, and every rule of the report holds of its address as of any. It finds the key within `ms`, monitors the service, finds again when the service ends or its node is lost, with `ms` between finds while a find fails, and ends with the process that started it. A send to it while the service is away is dropped, as a send during a loss is, and a call through it waits by its own time and answers `None` where the service is not back. A program that is to monitor the service itself holds the address `Peer.find` gives.

**The commands.** `ern deploy build --config-dir dir` is the coordinator: a node like the shell, listed by the nodes it deploys to. It prints the plan and waits for a yes, then stops, restarts and checks the first node and asks again, `next` or `all`, and prints what stands at which version when it ends or stops; the pause between nodes and the one node tried first are the operator's, with no option. It acts on nothing the yes did not cover: it never rolls a node back, and a cancel ends the coordinator alone, the node in its stop finishing its steps and restarting itself. Run again after a crash or a cancel, it continues from where the nodes are. A node accepts a planned stop only from a peer its `ernest.conf` marks as a coordinator, `"coordinator": true` in the peer's entry. `ern status --config-dir dir` asks the nodes what the plan asks and prints it: each node's roots, its release of `ern`, the keys it offers with their identities, its kept states and any rollout mark. `ern state path` prints a state file's type and value as Ernest literals. Termination is the planned stop: from the machine's service manager, from `ern stop --config-dir dir`, which sends it by `ernest.pid`, and from `kill -TERM` alike, a node withdraws its keys, drains, writes its kept states and closes, and then restarts where a next build was carried and ends where none was. There is one way a node ends. The interrupt is the quick end, as §8.6 has it for a program, and a second termination during the drain ends the drain and goes on to the states and the close. The drain's bound is the node's time, `drain` in `ernest.conf`, a minute unless the configuration says otherwise, which also bounds the coordinator's wait for the node to be back; the node tells the coordinator its time and each kept state's size, and the plan prints them. The configuration directory names the build the node runs, in its file `build`: `ern run --config-dir dir prog.erc` runs the program and writes its root there, and `ern run --config-dir dir` runs the build the file names, from the cache, and is MVP 3.1's bare node where the file names none. So a node started by anyone, the machine's service manager or an operator, runs the build the last planned stop named.

**A kept state.** `kept(key, init, step)` is a function of `restarting`'s family: it runs a loop the runtime owns, whose state is what `init` gives, and runs `step` on each message, over the state and the message, for the next state. The runtime holds the state between steps, and at a planned stop asks the process for it between two steps, as a supervisor asks for a restart (§6.9); the loop then holds what arrives until the close. Where the state file holds a state under the key, the loop begins with it, through `migrate` where its type changed, and `init` is not run. `kept` composes with `spawn` and `restarting`: a fault in `step` restarts the loop from `init`, with nothing of the old run, as §6.9 says of every restart. A service whose state is to outlive a deploy is a `kept` loop; any other process begins afresh at its node's restart, and a deploy promises it nothing.

**What the program writes.** A type's identity is its shape and not its name (mvp3.1.md, section 6), so a changed declaration keeps its module, its name and its key, and the old shape is kept under another name in a module of its own, `counter_v1.ern`, copied from what `ern diff` prints, until the build that drops it. For a kept state whose type changed, a member `migrate` on the new type from the old, `fn Count.migrate(old : CountV1.Count) : Count`, and one on the old from the new for the way back, both in the newer build. For a protocol that gained constructors, the old key offered as `via(service, convert)` with a pure conversion from the old type to the new, §6.5's adapted address; for one that retired or changed a request, a process the program starts with the library's `Forward.start(forward, service)`, whose `forward : (OldMsg, Address(NewMsg)) -> Unit with n` answers a retired request on the old side, offered under the old key. The offer table is by name and identity, so one node offers a key at two identities. `ern diff` prints the `migrate` and the conversion the matching fields and constructors give, with what needs a decision left empty, for the program to paste and complete.

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
  store, backup: ern 0.4.0, scheme 1; desk, board: the same
  counter       logic changed             nothing to write
order: store, backup; desk and board unchanged, not restarted
each node's time: 60 s; the rollout takes at most 4 min
the way back: ern deploy build1
meanwhile: a standing address drops its sends to counter through each restart
```

The operator says yes, and after the store is checked says `all`. The store's keys are withdrawn, and a find of the key answers `NotOffered` on every node, so the board's standing address waits and a call through it answers `None` at its time; the store drains, asks the counter for its total, writes it to `state/counter`, and closes; the store starts with build 2, the counter begins with the total from the file, `main` offers it, the board's standing address finds it again, and the coordinator checks the key; then the backup, the desk and the board the same way. The board's standing process sees one `Down` with `ProgramEnd` per node that stopped, and finds again.

**A changed protocol.** Build 3 adds `Reset` to `Counter.Msg`. The old shape is kept as `CounterV1.Msg` in `counter_v1.ern`, pasted from `ern diff`, with `CounterV1.key : Peer.Key(Msg) = Peer.key("counter")`, and the store offers it too:

```ernest-fragment
export fn main() : Unit with Never = {
    Peer.offer(Counter.key, counter);
    Peer.offer(CounterV1.key, via(counter, CounterV1.convert));
    wait()
}
```

where `CounterV1.convert` maps `Add` to `Add` and `Get` to `Get`, pasted whole. `ern deploy build3` prints:

```
plan: build 2 to build 3
  counter       protocol added Reset       served at build 2's identity through CounterV1.convert
                                           until the build that drops counter_v1.ern
order: store, backup, board; desk unchanged, not restarted
```

A board still on build 2 finds `counter` at its identity on a node of build 3 and is served through the conversion. Build 4 deletes `counter_v1.ern`; `ern deploy build4` refuses while any node runs build 2, and accepts when none does.

**A changed state.** Build 5 changes the counter's state from an `Int` to a record `Count`, which also counts the adds, and writes `fn Count.migrate(old : Int) : Count = Count(total = old, adds = 0)`. `ern deploy build5` prints:

```
plan: build 4 to build 5
  counter       state changed: Int to Count   Count.migrate
                the way back                  none: Int takes no member; forward-only
order: store, backup; desk and board unchanged, not restarted
```

Had `Count.migrate` been missing, the plan would have refused, naming it and the fields `total` and `adds`.

## 4. What holds

1. **No message of one version is read as another's**: a build of another runtime surface is refused by the cookie at the handshake, and a key of another identity by the find, as mvp3.1.md's claim 5 has it.
2. **A rollout the plan refuses never starts**: a changed protocol the new build does not also offer at the old identity, a kept state whose type changed without a `migrate`, a build that drops a protocol while a node still speaks it.
3. **Through a planned stop a service's state has one owner at every instant.**
4. **The next node is not touched until the last answers** its keys at the identities the plan expects.
5. **State crosses a version through a `migrate` the program wrote**, and through nothing the program did not write.
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
9. **A change without a reverse `migrate` is forward-only**, which the plan says; a state of a prelude type, which takes no member, has none.
10. **Where the order's graph has a cycle, some finds wait during the rollout**, which the plan names.
11. **A retry is the program's.** A call that answered `None` may or may not have run, so a request must be harmless when run twice.
12. **A drain does not grow firmer**; what a process has not finished by the close it loses, as at any restart.
13. **A release of `ern` that changes the runtime's surface stops every node.**
14. **A machine rebuilt from nothing starts by hand.** It has a new key and an empty cache; its first start is `ern run --config-dir dir prog.erc` with a build directory on it, and the nodes' `ernest.conf` lists its key.
15. **A program that is not running is in no rollout.** A one-shot program is started with the build it should run, and the plan cannot see it: one started from an old build after the drop finds `OtherType`.
16. **A node down when the plan is made is deployed by hand**, and until it is, the drop of a protocol it may speak cannot be checked; the plan refuses unless told `--without node`, and says so.
17. **The first deploy to this milestone's nodes is by hand**, since nodes of an earlier release refuse the coordinator at the handshake.
18. **A release of `ern` is installed by the operator**; the coordinator restarts a node into it, and carries nothing of it.

## 6. How it works

**The plan.** The coordinator asks each node, by one frame, the root it started from, its release of `ern` and its scheme version, its time, the digest of its configuration, any rollout mark it holds, the keys it offers with their type identities, and the kept states it holds with their identities and sizes; and reads from the new build its hashes and canonical forms; `ern diff` over the two is the plan's first half. For each key, from what the nodes offer and hold and from the new build: the identity of its protocol and of its kept state's type in each; whether the new build offers the key at the old identity, by a conversion or a forwarder; and whether it holds a `migrate` from the old state's identity to the new and one back, found as members by their types, the old and the new paired by the key and never by a name. Every check runs against every build any node runs or any state file holds. A protocol unchanged and a state unchanged is nothing to do. A protocol changed is accepted where the new build offers the old identity too, and refused otherwise. A state changed is accepted where the `migrate` exists. A build that drops a protocol is accepted where no node runs a build older than the one that first served both, and refused otherwise. The plan prints each node's release and scheme version first, each service's line, the order, the nodes it skips since their root is unchanged, each node's time and their sum as the most the rollout takes, a line saying the target is older than what runs where it is, the way back as the command to type, what a standing address drops meanwhile, and the builds the way back can reach after this rollout; a node that does not answer refuses the plan, naming it, unless `--without node` was given, and the plan then says that node must be deployed by hand before any build that drops a protocol; a node marked by another coordinator refuses it too. Free disk on each node is compared against its kept states' sizes; the refusals name what to write: `catalog: the protocol changed and the build does not offer catalog at build 4's identity`, `catalog: the state changed and Stock.migrate from build 4's Stock is missing: fields reserved, bin`. Before the plan is printed the coordinator tells every node the next build's root, each node fetches what it lacks and writes it to its cache, and a node that cannot, its disk full or its cache refusing, fails the plan naming the node and the cause. Nothing starts before the yes, and the yes is asked only when every node holds the next build whole.

**What `ern diff` prints.** For a kept state whose type changed, the `migrate` the matching fields give, a field matched by name and type copied, a field the new type drops left out, and a field the new type adds or renamed left empty for the program; and the reverse the same way. For a protocol that changed, the conversion each old constructor kept in form gives, to its namesake, and an arm left empty for a constructor retired or changed, which the program answers in a `forward` instead. The text is for pasting: the tool writes into no source, and what the program commits it has read.

**The old shape keeps a module of its own.** Constructor names are one module's, so the old shape of a type cannot stand beside the new in one module; the program keeps it under another name in a module of its own, `counter_v1.ern`, pasted from the form `ern diff` prints, with its key at the old identity where it is a protocol. Its identity is unchanged by the name, so an old client's key and an old state file match it. Deleting that module is the act that drops the version, which the plan accepts when no node is older than the build that first served both, and `migrate` and the conversion go with it.

**Two builds for a changed protocol.** The first offers the key at both identities: the new, and the old through a conversion or a forwarder, under which an old client and a new service meet in any order. The second drops the old. The plan enforces the two; a build that changes a protocol and drops the old at once is refused.

**The order.** The coordinator knows which keys each node offers and which keys each node's code finds, since a find is a reference the hashes see. The nodes in the order are the running nodes whose root differs between the two builds, each told the root of the entry point of its own qualified name in the next build; a build that lacks that name refuses the plan. It orders them so that a node offering a changed service goes before the nodes whose code finds it, and in that order a new client never finds an old service. Where the graph has a cycle the coordinator picks an order and the plan names the finds that will wait.

**The planned stop.** Termination, or the coordinator's frame carrying the next build's root, runs four steps on the node. The frame is accepted from a peer the configuration marks as a coordinator and from no other; the node then holds a mark, the coordinator's key and the next root, until it has restarted and offered its keys, and refuses a frame from another coordinator while it holds one. Before the frame the coordinator asks the node its configuration's digest again, and stops where it differs from the plan's. First, the node withdraws its keys: a find from a peer answers `NotOffered`. Second, the drain: the node waits until no call waits in its table of calls, which the call's note fills for a remote caller, and every `kept` loop is idle, between two steps with an empty mailbox, or until its time passes, `drain` in its configuration. A request in flight at that moment, or in another process's hands, is lost with what the loop holds, as limit 12 says. A call that reaches a service through a standing process is the service's to the drain, since the forwarder sends the request on and the service answers the caller directly. Third, each kept state: the node asks each `kept` loop for its state between two steps, writes it to the file, and the loop holds what arrives from then, which is lost at the close. A write that fails ends the stop before the close: the loops go on, the keys are offered again, the node says why on its standard error and answers the coordinator, which stops and prints it. A state that cannot cross, by §3.11's rule, is not written, and the next build's loop begins with `init`. Where the next build is older, the state is written through the reverse `migrate`, which the stopping build holds. Where a next build was carried, its root is written to the directory's `build` file before the close. Fourth, the close: the node ends as a node ends, in order, and the loss is the ordinary one. A stop that carried a next build does not end the host process: the runtime restarts inside it, by the host's own restart from the same command line, and `ern` runs the build the directory names. The pid is unchanged, so `ernest.pid` stays true and the service manager sees nothing. `ern stop` and the signal end the process.

**The state file.** Under `state/` in the configuration directory, one file for each kept state, named by its key's name, holding the hash of the state type's identity and then the value in the encoding a value crosses in. It is written to a temporary name, synced, and renamed, so that a power loss after the stop leaves the old file or the new and never an empty one; the hash is read before the value is decoded, so that a build without the `migrate` decodes nothing it does not declare. The `kept` loop under the key reads it at its start, through `migrate` where the hash is not its own state type's; where its build holds no `migrate` from that hash the loop begins with `init` and says so on its standard error, which the plan said before the yes. The node removes the files it read once it listens, every initializer having its value, so that a start which fails leaves them for the build that comes back.

**Lockstep.** After a node's planned stop the coordinator waits until the node is back and offers its keys, and finds each key at the identity the plan expects; then the next node. The coordinator starts nothing: the node restarts itself, and one that is gone for another reason is the service manager's to start, and runs what its directory names. A start that fails goes back by itself: a restart into a next build whose initializer faults writes the previous build to the `build` file and restarts into it, once, and a second fault ends the node as a faulting initializer ends a program. A node that is not back within its time, or that the coordinator loses, stops the rollout: the coordinator rolls nothing back, the other nodes stand as they are, and it prints what stands at which version; `ern deploy` of either build, with its own yes, is the way on or back. The coordinator keeps no record: each node answers which build it runs, so a second `ern deploy` of the same build continues.

**The way back.** `ern deploy` of the previous build is a rollout like any other, accepted while every protocol the previous build speaks is still served, which holds until the build that dropped one; the state files go through the reverse `migrate`, which the newer build holds. After the drop the way back is forward.

**The cache.** Each node keeps the code it runs on its disk, by hash, as mvp3.1.md's section 6 has it: each definition's canonical form with its compiled unit, for the builds it has run and the one it is about to run. Told the next build's root before the plan, the node fetches the closure it lacks from the coordinator by MVP 3.1's exchange, each definition verified against its hash on arrival, compiles it, and writes it; it loads nothing until its restart. A node restarts into a build from its cache and nothing else, verifying every form against its hash as it loads, and compiling nothing. A build leaves the cache when the plan has printed that no way back reaches it, the drop of its protocols. No build directory is copied to a node.

**What passes.** Beside MVP 3.0's and MVP 3.1's frames, three of Ernest's: the coordinator's question to a node, its build, offers and kept states, and the answer; the next build's root, which the exchange's four frames follow; and the planned stop, with the next build's root. The withdrawal is no frame: a find answers `NotOffered`.

**The standing address.** `Standing.start(key, ms)` is Ernest, in a library, and the runtime has no part in it. Its process has the mailbox type `Message(m) | Went(Down)`, and the caller is given `via` of it with `Message`. It finds the key by `Peer.find(key, ms)`, holds the address found, monitors the service's process, and forwards each `Message`; at `Went` it finds again, and where a find fails it waits `ms` and finds again. A message that arrives while no address is held is dropped. It monitors the process that called `start` and ends at its `Down`, so that nothing is left finding. The forwarder is one more process on a message's way, and a message through it may pass a message sent directly, as through any process (mvp3.0.md's claim 4.1).

**The runtime's surface, and a release of `ern`.** Decided with the user on 2026-10-07 to be this milestone's and not one of its own: the cookie is the digest of the protocol's version, the hash scheme's version, OTP's version and the version of the runtime's surface, in place of `ern`'s whole version. The surface is what shipped code calls by name, the runtime's functions and the standard library's foreign declarations, with the identity of the standard library's own Ernest, named and given a version of its own that changes when any of it does, so that two releases of `ern` with one surface connect, and a spawned function never meets a standard-library binding of another identity on a peer. The operator installs a release on each machine; `ern deploy` with the build the nodes run then restarts each node whose release is not the coordinator's, which its line says, and carries nothing of the release. A release that changes the surface still stops every node, and says so in its notes.

**The refusal.** `Supervisor.child`'s function reads the process's start cause when it begins; run inside a process that is already a child it would read the outer child's, so it faults instead with `Fault("a process runs one child function")`, and E.22 says so.

**The test.** `ern test --config-dir dir` runs the rollout's test where a build names the previous one. The shape half runs with nothing started: each service's line of the plan, each missing `migrate` and each old identity not offered refused. The run half starts two nodes: it generates values of each service's state type from the previous build and writes them as the state files a stop would have written; starts the previous build on both nodes; rolls one node to the new build, checks every key at the identity the plan expects, rolls the other, and stops both; and compares what the stops wrote with what went in, identity where the state type is unchanged and the round trip through the reverse `migrate` where it changed. It rolls back the same way. A service whose state cannot cross is skipped and listed. The test sends no message of any protocol.

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
| the plan's estimate | the sum of the nodes' times, the most the rollout takes |

## 8. How it is checked

The plan has a test suite of its own: two builds differing in each of the matrix's rows, and the plan's line for each, accepted or refused, and `ern diff`'s text for each; a build that drops a protocol refused while an older node runs and accepted after; the order from a graph with and without a cycle, over three builds in flight, with a node skipped for an unchanged root and a node absent with and without `--without`; a plan refused by a mark, by a changed configuration and by a full disk.

The runtime's tests run three nodes on one machine, as MVP 3.0's do: a planned stop withdraws the keys, writes each kept state's file, and closes in order; a kept loop reads its file through `migrate` and removes it, and begins afresh where no `migrate` fits; the `Standing` library's tests drop a send and answer `None` to a call while the service is away, reach it again where it comes back on the same node and on another, and end the standing process with its caller; a rollout in lockstep stops at a node that does not answer and puts it back; a rollback through the reverse `migrate`; the cache holding the next build before the stop and letting an old one go; the refusal of E.22; and the generated test itself, run over the experiment programs' builds.

## 9. Unsolved

What remains is the build's: a generator of values for a type, which the test needs and the descriptors give; the texts of the plan's lines; the naming of the runtime's surface, measured by what the exchange ships and what it calls by name; the report's sentences, §8.7 for the rollout and the planned stop, §11.2 for `ern deploy` and `ern stop`, §9.5 for `kept`, Appendix E for `Peer.find` and E.22's refusal, §11.3 for `keys` and `drain` in `ernest.conf` and the `build` file, §8.6 for termination as the planned stop, and §11.2 for a node's restart inside its process; the glossary's words, *build*, *root*, *kept state*, *planned stop*, *rollout* and *plan*, in Appendix F and in `docs/style.md`, written with the report's sentences; and the soundness argument's paragraph for the state file and `migrate`.

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
