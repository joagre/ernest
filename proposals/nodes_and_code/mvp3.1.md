# Ernest: MVP 3.1, Code with a Spawn

Status: the proposal for MVP 3.1, written on 2026-10-08 by MVP 3.0's item 12 from two proposals set aside the same day, [`set_aside/builds_side_by_side.md`](set_aside/builds_side_by_side.md), which was MVP 3.1, and [`set_aside/ordered_rolling_restart.md`](set_aside/ordered_rolling_restart.md), which was MVP 3.2 (the log's *The Milestones After 3.0, Weighed Again*). It keeps from the first the spawn that carries its code, the bare node, the shell as a node and `NotLoaded` by binding, and from the second the `Standing` library and E.22's refusal; it keeps nothing that ordered a rollout. Restored on the evening of 2026-10-08 after a day's detour through the module as the grain, which shipped compiled modules whole under names that held their digests and was set aside the same evening, the definition being the grain after all; the detour left one thing, the floor: the cookie holds the protocol's version, `ern`'s version and OTP's major release, and not the build, so that nodes of different builds connect, and a key carries its type's identity, as [`set_aside/builds_side_by_side.md`](set_aside/builds_side_by_side.md) had it. Three questions were read through the same evening and decided with the user, each in section 6: how a definition that arrives becomes code the host runs, which is a unit per exchange, linked through the table and compiled on the peer; the canonical form, which is the typed tree and nothing beside it; and what does not hash, a foreign declaration and a binding, which section 5 states. Two things came of them: a fix crosses as a delta, and a unit no process runs is let go, which asks that a table hold no function. The two that were left, the table and the tree, were decided the same night: the rule, and the tree. Changed on the read-through of 2026-10-08: the planned stop and the kept state, kept at first from the second proposal, were set aside with it, and in their place a program is told of its termination, one subscription, so that a process writes what it keeps for itself. It changes only by a question raised against it, and it is read through with the user before a line of it reaches the plan, the log or the report. The reasons for what it says are [`code.md`](code.md)'s, written with it, and [`nodes.md`](nodes.md)'s sections 4, 6, 14 and 15, each paragraph dated where it was decided; what other systems do is [`other_systems.md`](other_systems.md), sections 6 and 7; what six programs showed of a change of code in place is [`experiments/code_update/`](experiments/code_update/README.md).

## 1. What it is

MVP 3.1 lets a spawn carry its code to a peer that lacks it, and tells a program of its termination before the end. A process on one node spawns a process on a peer with a function the peer does not have, a function typed at the shell or one of a program the peer was never given, and the code crosses with the spawn, named by its hash. A process that subscribes to the program's termination is told of it in its own mailbox type, answers when it has written what it keeps, and the program ends once every subscriber has answered.

Four things bound it:

- **The floor.** Every node runs the same release of `ern` on the same major release of OTP, which the cookie holds, and nothing else is required to agree: nodes of different builds connect, and what may run where is told by the hashes, at a spawn and at a find. A node that runs no program, the bare node, is of no build.
- **A hash for each definition.** The compiler computes it from a canonical form of the definition, and it names code where code crosses, in a spawn, where the peer says which hashes it lacks, and nowhere else.
- **No change in place.** A process never takes new code but by its own act, §6.10's message on its own node, and a deploy is stop all and start all: every node is ended by termination, of which each subscribed process is told, and started again with the new build.
- **Nothing ordered, and nothing kept.** No coordinator, no plan, no rollout and no command of `ern`'s orders a deploy; an operator's script does, with `ern stop` and `ern run`, as a balancer is a library and not a feature. The runtime holds no state for a program and reads none back: a program told of its termination writes what it keeps, with `Fs`, and reads it at its next start.

The bounds of MVP 3.0 stay: a few nodes with one owner, listed by hand, trusted completely; no discovery; nothing the runtime retries. Its four rules rule here too.

**The building block.** A *definition* is a function, a type, or a top-level binding, and its *hash* is the identity it has on every node: two definitions with one hash are one definition, and two with different hashes are two, whatever they are called. A node holds code by hash, loads by hash, and ships by hash.

## 2. What a program sees

**The operations** are MVP 3.0's, with one difference: a spawn on a peer carries its code where the peer lacks it. `Peer`'s functions and `Peer.Failure` are unchanged. `NotLoaded` means what the function needs and the peer does not have: a binding's value, or the module a foreign declaration names. `Refused` is the peer's refusal of a closure: its text says why the peer could not load what was sent; a connection the handshake refused is `Unreachable`, as MVP 3.0 has it.

**What is new.**

- **A bare node.** `ern run --config-dir dir` with no `.erc` starts a node that holds no definition of a program's: it runs the runtime and the system processes, its entry process evaluates the standard library's bindings, as any program's does, and the node listens and waits, and ends by termination alone. Everything it runs arrives by a spawn from a peer, with the code. A spawned function there names no binding but the standard library's and carries the rest as captured locals, and a spawned process may offer itself under a key. Nothing is copied to such a machine but `ern`. One without `listen` is refused at its start, since it never dials. A balancer places work on it as on any peer, and installs its measure there with `Balancer.serve`, whose process captures the balancer's address and names no binding. The code spawned on it stays until the node restarts, bounded by section 7's limits and their warning, at which an operator stops it with `ern stop` and its service manager starts it again.
- **The shell's `:load` and `:reload`** work in a shell that is a node, which MVP 3.0 refused: a load adds hashes and moves the session's names, a binding made before it keeps the type it was checked under, and a function typed at the shell spawns on a peer with its code. A shell is a node of the build on its load path, or of the build its configuration names where its load path holds no program, a bare node with a prompt.
- **Termination told.** `Os.terminating(wrap)` subscribes the calling process to the program's end: when the program ends, by termination from the machine's service manager, from `ern stop --config-dir dir` or from `kill -TERM`, by its entry process's end or by `Os.exit`, the runtime delivers `wrap(reply)` to each subscriber, and the program ends once every subscriber has answered its reply or has ended. The process handles the message in its own `receive`, between two of its steps, writes what it keeps, and answers. The interrupt, and a second termination, end at once, as today. A subscription is one per process, the latest, and ends with its process. A program that is no node is told the same way.
- **`Standing.start(key, ms)`**, of the library `Standing` under `libs/`, spawns a process that finds the key and forwards to the service what it is sent, and answers `via` of that process; it is an ordinary process the program spawned, and every rule of the report holds of its address as of any. It finds the key within `ms`, monitors the service, finds again when the service ends or its node is lost, with `ms` between finds while a find fails, and ends with the process that started it. A send to it while the service is away is dropped, as a send during a loss is, and a call through it waits by its own time and answers `None` where the service is not back. A program that is to monitor the service itself holds the address `Peer.find` gives.
- **The refusal.** `Supervisor.child`'s function run inside a process that is already a child faults with `Fault("a process runs one child function")`.

```
Os.terminating : ((Reply(Unit)) -> m) -> Unit with m
Standing.start : (Peer.Key(m), Int) -> Address(m) with n
```

**What may cross** is MVP 3.0's rule unchanged: a bound type never crosses, the compiler refuses a key of a bound type and a spawn whose captures are bound or have a type variable in their type, and an adapted address's captures cross inside it as payload, touched only on the node that made it. The function a spawn starts crosses with its code, where the peer lacks it.

**Captures and references.** A top-level binding a spawned function names is the peer's, resolved by its identity, and `NotLoaded` where the peer did not run it; a local the function captures crosses as a value. A value the function is to carry from the spawner is bound to a local first, `let key = Counter.key`, and captured as any local is. The rule is one, and nothing is read off the function's text but which names are locals. So MVP 3.0's rule by module goes: a function spawns on a peer where every binding it names has its value there, whatever its module holds.

## 3. Examples

The counter of [`mvp3.0.md`](mvp3.0.md)'s section 3 runs on the store, and the desk and the board find it by `Counter.key`. The program is at build 1 on every node.

**A worker.** A fourth machine, `worker`, has `ern` installed and a directory `ern config` made, whose `ernest.conf` lists the store. It runs `ern run --config-dir /etc/ernest/worker` and no program, and the store lists it. The store spawns on it:

```ernest-fragment
let key = Counter.key;
match Peer.spawn("worker", fn() = { Peer.offer(key, self()); count(0) }, 5000) {
    Left(_) -> Io.println("no worker")
  | Right(_) -> Unit
}
```

The first spawn ships the function, `count` and `Counter.Msg`, verified and loaded on the worker before the process starts; the second ships nothing. The process offers itself, since only a process of the offering node may be offered. The function captures `key`, a local holding the key's value, and names no binding of the store's, so it runs there; written with `Counter.key` inside it, the binding would be the worker's, which never ran it, and the spawn would fail with `NotLoaded`. The worker's output goes to the worker's standard output.

**A fix from the shell.** The counter's `count` is to log each `Add`, and the program is not to be stopped for it. At a shell that is a node of the build, the operator types the new loop and sends it through §6.10's `Upgrade`, by a process spawned on the store with the code:

```ernest-fragment
fn count2(total : Int) : Unit with Counter.Msg = ...
let counter = Optional.withDefault(Either.toOptional(Peer.find(Counter.key, 5000)), ...);
Peer.spawn("store", fn() = send(counter, Counter.Upgrade(migrate = fn(n) = n, next = count2)), 5000)
```

The spawn ships `count2`, which the store lacks, and the spawned process sends the message on the store's own node, where a function in a message is allowed (§3.11). The counter switches by a tail call, its total kept, as §6.10 has it. Under MVP 3.0 the spawn answered `NotLoaded`, since `count2` is in a module no peer has. The fix is in the running process alone: a restart of the store runs build 1's `count` again.

**A deploy.** Build 2 changes `count` to log each `Add`, and the counter keeps its total across the stop, in a file it writes when it is told of the end and reads at its start:

```ernest-fragment
// store.ern, build 2

type Msg =
    Add(Int)
  | Get(reply : Reply(Int))
  | Terminating(reply : Reply(Unit))

let total : Path = Path("total.json")

let counter : Address(Msg) =
    spawn(restarting(RestartLimit(restarts = 3, within = 5000), fn() = {
        Os.terminating(Terminating);
        count(saved())
    }))

fn count(n : Int) : Unit with Msg =
    receive {
        Add(amount) -> {
            Io.println("add " <> Int.toString(amount));
            count(n + amount)
        }
      | Get(reply = reply) -> {
            answer(reply, n);
            count(n)
        }
      | Terminating(reply = reply) -> {
            let _ = Fs.write(total, String.toUtf8(Json.format(Json.Integer(n))), 5000);
            answer(reply, Unit)
        }
    }

// The total the last run wrote, or 0 where there is none.
fn saved() : Int with m =
    match Fs.read(total, 5000) {
        Right(bytes) -> match Optional.andThen(String.fromUtf8(bytes),
                                               fn(text) = Either.toOptional(Json.parse(text))) {
            Some(Json.Integer(n)) -> n
          | _ -> 0
        }
      | Left(_) -> 0
    }
```

The operator's script copies build 2 to every machine, runs `ern stop --config-dir dir` on each node and `ern run` on each with the new build; the worker is not touched. At the store's stop the counter is told, writes its total and answers, and the node ends in order; at the store's start the counter begins with the total from the file, and `main` offers it. The board, which holds `Standing.start(Counter.key, 5000)` in place of its find, sees one `Down` with `ProgramEnd` and finds the counter again once the store is back; a call through its standing address meanwhile answers `None` at its time.

**A changed state.** Build 3 counts the adds as well, and its state is a record `Count(total : Int, adds : Int)`. Its `saved` reads a file build 2 wrote, which holds a number, into `Count(total = n, adds = 0)`, and one build 3 wrote, an object, into the record; a file nothing reads begins the counter at `Count(total = 0, adds = 0)`. Nothing of the runtime takes part: the shape of the state, its file and its reading are the program's.

## 4. What holds

1. **A hash names one definition everywhere.** Two nodes that hold one hash hold one definition, whatever each build calls it.
2. **A node holds a hash only with its whole closure.** Nothing enters a node's code table before everything it references is there and verified.
3. **Code arrives verified or not at all.** Every definition that crosses is checked against its hash on arrival, and a frame that fails ends the connection.
4. **A process keeps its code.** Loading only adds; nothing a process runs is ever changed or taken from it, in a spawn or in the shell's reload.
5. **No message of one version is read as another's.** A key carries its type's identity, the hash, beside its text, and a find answers `OtherType` where the holder's differs; a spawn carries its closure's hashes, so the function runs at the peer over the definitions it was compiled with. So what is sent through a remote address is of the type the receiver's code was compiled with, whichever builds the two nodes are of. On one node, across the shell's reload, a value keeps the type it was checked under: two versions of a type are two types in one scope, and the checker refuses a message of one to an address of the other.
6. **A subscriber is told before the end and answers before it**: the program ends once every subscriber has answered or ended, and nothing of the program runs after the end, which is in order, as MVP 3.0 has it.
7. **A client reaches its service after a restart without code of its own**, through the `Standing` library.

## 5. What does not hold

MVP 3.0's limits stand, every one. Its ninth holds for code that crosses: a peer's code is verified against its hash and run as the peer's own, trusted as the peer is.

1. **A deploy stops every node and starts every node**, and nothing orders it: the operator's script does, and a service is away for its node's restart. Nodes of different builds never connect, so a node started with the new build before another has been stopped is `Unreachable` to it.
2. **A protocol changed is a service not found.** A key at a type that changed has a new identity, and a client of the old finds `OtherType` until it is rebuilt and restarted; nothing serves the old identity through a conversion.
3. **Code that arrived stays while something runs it, and comes again when asked.** A unit no process executes or holds, and no table holds, is let go, and the next spawn that needs one of its definitions crosses the code again; the build's own code stays. A node that holds many versions at once, their processes alive, says so on its standard error when it nears a limit of the host's (section 7).
4. **A spawn that ships code is slow once.** The first spawn of a definition on a node that lacks it crosses the closure, compiles it there, and loads it, within the spawn's time or `Timeout`; what arrived complete stays, and the next spawn ships nothing. A fix to a definition many call costs the peer the compile of every caller, since each is a new definition, which for a definition everyone calls is the compile of the program, once per node.
5. **A spawned function finds no binding the peer did not run.** It names the standard library's bindings and carries the rest as captured locals, or the peer answers `NotLoaded`. On a bare node that is every binding of the program's.
6. **A foreign declaration's implementation is outside the hashes.** A `foreign fn` names a host module, which is each node's own; a shipped definition that names it runs the peer's. A foreign declaration over a module of OTP's or of `ern`'s is on every node; one over a library's own Erlang is where the library is, and a bare node lacks it, so `Load`'s shims are over OTP's modules and `Json`'s primitives are `ern`'s.
7. **A second offer under a key a bare node's living process holds faults the offerer**, as MVP 3.0 has it; a peer that is to take a key over finds its holder by the key and kills it first.
8. **What a program keeps is its own.** The runtime holds no state and reads none back; a process told of the end writes what it wants, in the form it wants, and reads it at its next start, and a changed shape is its own reading code. A process that is not told, one that did not subscribe or one that faults before the end, keeps nothing.
9. **The end waits for its subscribers and for nothing else.** A request in flight at the end is lost, as at any loss, and a message that reaches a subscriber after it answered is lost with the process. A subscriber that neither answers nor ends holds the program until a second termination, the interrupt, or its service manager's own patience, which kills; a subscriber writes and answers. Nothing withdraws a key before the end: a peer finds, calls and sends to a process told of the end until the end.
10. **A retry is the program's.** A call that answered `None` may or may not have run, so a request must be harmless when run twice.

## 6. How it works

**The hash.** Two words, used so throughout: a definition's *hash* is the SHA-256 of its canonical form, and nothing else; its *identity* is what a reference names, a function's its hash, a type's its hash, a binding's its qualified name with its hash. The canonical form is the typed tree after checking, with local variables numbered by position, layout and comments gone, every name resolved, and types written out. A reference to another definition is the hash of what it names, and nothing else; a reference to a foreign declaration, which has no hash, is its qualified name and its type, and each node resolves it for itself. A function's own name and its source positions are not in its hash: two functions with one body are one definition. A top-level binding's identity is its qualified name with its definition's hash, since a binding is a thing that exists on a node, a value or a process, and two bindings with one initializer are two. A type's hash covers its qualified name, its parameters by position and its constructors in declared order with their fields' names and the hashes of their types, as the checker tells two declarations apart by name, and a key carries it beside the type's text (section 2). A mutually recursive group is the strongly connected component of the dependency graph, hashed as one in source order, and each member's identity is the group's hash and its position in it. A lambda's identity is its enclosing definition's hash and its position in it, and an applied type's is its constructor's hash over its arguments' identities, a built-in type's its name. The site a spawn frame carries is the spawner's build's words, shown and never compared. The scheme's version is mixed into every hash, and changes with any change to what runs before hashing, the canonical form and the checker among it. The canonical form is written down with it before any hash is computed, literals and order fixed.

**The cookie and the floor.** The cookie is the digest of the protocol's version, `ern`'s version and OTP's major release, `erlang:system_info(otp_release)`, and the build is not in it: nodes of different builds connect, and MVP 3.0's fingerprint goes. The major is where OTP sets its own promise, that the term format, the distribution protocol and a compiled module hold across one major's patch and minor releases, so a patch of the host rolls node by node; and `ern`'s version stands for what the hashes leave out, the runtime's functions and the standard library, which shipped code calls by name, and every foreign declaration over a module of OTP's or of `ern`'s, which a peer resolves by name and type. So two connected nodes agree on everything beneath the hashes, and the hashes tell the rest apart. A library under `libs/` is a program's code, hashed and crossing with it.

**Messages and keys.** A message carries nothing of its type and goes straight into the mailbox, and a key carries its type's text, as in MVP 3.0. Serialization and the gateway are MVP 3.0's.

**Bindings.** A node holds its bindings' values by their identity, name and hash. A spawned function that names a binding finds the value where the peer's own build ran that identity, and fails with `NotLoaded` where it did not; nothing is initialized because a peer asked, as in MVP 3.0, and a value a spawned function is to have on the peer is captured. A service is one per node and key, a second offer faulting while it lives, as MVP 3.0 has it: a node of a build offers what that build started, and a bare node what its peers spawned on it.

**A node's code.** A node holds definitions by hash, in a table from each hash to the host's module and function that hold it; that table is the code table, and the compiled code lives once, as loaded modules of the host. Definitions that arrive in one exchange are compiled together into one unit of the host's, under a name of the node's own, its functions named by their position in the unit so that the names are reused and the atom table grows by the unit's name alone, and references between definitions are linked through the table before the unit is compiled, a reference to a definition of the unit a local call and one to a definition of another unit a call into that unit; the node's own build is compiled by the same back end from the same forms, one unit per source module, with the same table over it, so that a unit is made one way whether a build or an exchange brings it. What one load brings to a node that holds a unit of the module's name already is compiled the same way, into one unit under a name of the node's own, from the forms its `.erc` or its source holds: a unit of the host's never takes a second version, so the host's limit of two versions never ends a process, and a load counts against the limits of section 7. Nothing names a unit of the host's. The canonical form of the node's own definitions is in its `.erc` files, read and verified against its hash when the node ships one; a build directory is never changed under a running node, and a new build goes in a directory of its own. The canonical form of a received definition, and of one typed at the shell, is kept beside its compiled code, and the node ships it onward as its own. Loading is by the host's `prepare_loading` and `atomic_load`, one batch per closure, skipping what is loaded already, with no `-on_load`; the node's units are off the code path, where nothing loads them but the node, and the node loads otherwise as `ern run` does today. Nothing of a node's code is kept on its disk but its build directory: a node restarted holds its build and what its peers spawn on it again.

**What a node lets go.** A unit that arrived by an exchange or a load is unloaded when no process executes it or holds a function of it, which the host tells, `erlang:check_process_code`; the build's own units are never unloaded. A table holds no function: `Ets.Table(k, v)` is accepted by the compiler only where `k` and `v` hold no function type, the first case of §3.11's bound check, so that nothing but a process holds a function and the host's check sees every holder. The node sweeps when a unit arrives and when it nears a limit of section 7. A unit unloaded leaves the table, its name returns to the pool, and a spawn that asks for one of its definitions again is sent it again, one exchange. So a node that ran a program through three fixes holds, once the processes of the first two have ended, one program's worth of code, and the memory of code is bounded by what runs, not by what ever arrived.

**A spawn that carries its code.** The spawn frame carries the function's hash, its captured values and the site. A peer that has the hash starts the process at once. A peer that lacks it asks for the closure's list; the sender sends the hashes the function references transitively, code and types, with the foreign declarations it names; the peer answers with the hashes it lacks, and with `NotLoaded` where it lacks the module a foreign declaration names or the value of a binding the function names; the sender ships the missing code, dependencies first. The request for the list, the list, the lacks and a code frame are four frames of Ernest's beside MVP 3.0's six. A code frame carries one definition's canonical form, the form that is hashed, with its immediate references, and never a compiled binary; or a delta: the hash of a definition the peer holds and the references in which the shipped one differs from it, from which the peer makes the form itself and verifies it against its hash as it verifies any. The peer's answer names, for each hash it lacks, the hashes it holds under the same source name, which is the one use the exchange makes of a name, a hint and never an identity; the sender sends a delta where the two forms differ in references alone, and the form otherwise. So a fix to a definition many call ships the fix and a line for each caller, and the callers, whose hashes changed with the fix, are compiled on the peer and never cross. The peer verifies each frame against its hash as it arrives and holds it apart until the closure is complete; then it compiles the closure with its own back end, loads it all at once by the host's atomic load, and starts the process. What the peer said it has is pinned until the load is done. A frame whose content does not match its hash is a faulty frame, and the connection ends. A closure the peer cannot compile or load, a limit of the host's reached among the reasons, fails the spawn with `Refused`, whose text is the peer's. The exchange runs in a process of its own on each node, and the gateways only pass its frames. The spawn's time covers the exchange; what arrived complete stays in the code table, and two spawns waiting on one hash share one exchange.

**The shell.** `ern shell --config-dir dir` is a node, as in MVP 3.0, and its `:load` and `:reload` work: each adds hashes and moves the session's names. A type in the session is its hash, so a binding made before a load keeps the type it was checked under, and a message of a type's new version sent to an address of the previous one, or the reverse, is a type error, whose diagnostic says which of the two is of the previous version. A local address is a pid alone on the host, and constructors of one name in two versions are one term, so the checker is the one thing that tells the versions apart on one node, as one build is between nodes. A process of a previous version runs on until it ends or is killed, reachable through the addresses of its version alone, its key offered again only once it has ended, as any key is; nothing a reload loads is a second version of a unit (*A node's code*), and §11.2's fault for a further reload, `its code was unloaded`, goes, and with it from §7.4 and §8.4, since nothing is unloaded. A function typed at the shell has a hash as any definition has, and spawns on a peer with its code; the session's load is the session's, as today, and no module of the standard library loads code by name.

**Termination told.** `Os.terminating(wrap)` is a subscription the runtime keeps for the calling process, as it keeps a subscription to faults: one per process, the latest, ended with its process. When the program ends, by termination, by its entry process's end or by `Os.exit`, the runtime delivers `wrap(reply)` to every subscriber, each delivery a process of its own as a monitor's is, and watches each subscriber as it watches a callee; it goes on to the end once every reply is answered or its subscriber has ended, and the end is MVP 3.0's, in order: every live process ends with `ProgramEnd`, the `Down`s cross, the connections close. While the runtime waits, every other process runs, a peer finds, calls and sends to the node as before, and nothing withdraws a key. A subscription made after the subscribers were told is told at once. The interrupt, and a second termination, end at once, as today, and a fault's end of a subscriber while it writes is a fault as any, reported, the end going on without it. A program that is no node is told the same way, under `ern test` and in the shell too.

**The standing address.** `Standing.start(key, ms)` is Ernest, in a library, and the runtime has no part in it. Its process has the mailbox type `Message(m) | Went(Down)`, and the caller is given `via` of it with `Message`. It finds the key by `Peer.find(key, ms)`, holds the address found, monitors the service's process, and forwards each `Message`; at `Went` it finds again, and where a find fails it waits `ms` and finds again. A message that arrives while no address is held is dropped. It monitors the process that called `start` and ends at its `Down`, so that nothing is left finding. The forwarder is one more process on a message's way, and a message through it may pass a message sent directly, as through any process (mvp3.0.md's claim 4.1).

**The refusal.** `Supervisor.child`'s function reads the process's start cause when it begins; run inside a process that is already a child it would read the outer child's, so it faults instead with `Fault("a process runs one child function")`, and E.22 says so.

## 7. The numbers

| What | Value |
|---|---|
| a definition's hash | SHA-256 over its canonical form, the scheme's version mixed in |
| the cookie | the protocol's version, `ern`'s version and OTP's major release; no build |
| a code frame | one definition's canonical form, with its immediate references; or a delta, a held hash and the references that differ |
| what a fix crosses | the changed definitions, and a delta for each caller whose hash changed with them |
| a unit let go | one no process executes or holds a function of; a table holds none; the build's never; swept at an arrival and near a limit |
| the frames of this milestone | four, beside MVP 3.0's six |
| atoms a node can make in its life | 1,048,576, the host's, never reclaimed: every unit's name and every function's, a name reused when its unit is let go |
| module names a node can load in its life | 65,536, the host's (OTP 29); a unit let go returns its name to the pool |
| lambdas a node can load in its life | 524,288, the host's, never reclaimed (OTP 28 and later) |
| a node says it nears a limit at | four fifths of any of the three |
| the end's wait | until every subscriber has answered or ended; none of the runtime's own |

## 8. How it is checked

The canonical form has a test suite of its own, written with the form before any hash is computed: the same definition hashes the same across a rebuild; a renamed function keeps its dependents' hashes, and a renamed constructor changes them; a moved definition in a group changes the group's hash; two bodies that differ only in local names or layout hash the same; a literal's encoding is fixed. Two hashes for one definition, and one hash for two, are its cases.

The runtime's tests start nodes on one machine as MVP 3.0's do, and hold the claims of section 4: a spawn of a function typed at a shell that is a node ships exactly the lacking definitions, verified and loaded at once, and the process runs; a spawn onto a bare node ships the program's closure once and nothing the second time, and the process offers a service the program finds; `NotLoaded` for a binding the peer did not run and for a foreign declaration it lacks, and a function that names no binding spawning where MVP 3.0's rule by module refused it; a faulty frame ends the connection; a late or broken exchange leaves nothing half-loaded; a fix crosses as deltas and the callers compile on the peer; a unit whose processes have ended is let go and crosses again at the next spawn that needs it, and one a process holds a function of stays; a table of a function type is refused by the compiler; two nodes of different builds connect, and a find across them answers `OtherType` where the key's type differs and an address where it does not; a node told to load many units says so at four fifths of a limit, once, measured; the shell fixes a service on a peer through `Upgrade`; in the shell, a binding made before a `:reload` that changed its type refuses a message of the new version and takes one of its own, and the previous version's service runs on through two further reloads of its module. A subscriber is told at termination, at the entry process's end and at `Os.exit`, and the program ends after its answer and not before; a subscriber that ended holds nothing up; a subscriber that faults while it writes is reported and the end goes on; a second termination and the interrupt end at once; a subscription made during the end is told at once, and one made by a process that ended is gone with it; a program that is no node, a test under `ern test` and the shell are told the same way; a peer finds and calls a node whose subscribers are being told. The `Standing` library drops a send and answers `None` to a call while the service is away, reaches it again on the same node and on another, and ends its process with its caller; and E.22's refusal.

A program's own test of two nodes needs nothing new: `ern test --config-dir dir` with the other node started by `Os`, as MVP 3.0 has it.

## 9. Unsolved

Every question the proposal was written through is decided. What remains is the build's: the canonical form's document, with the hash scheme's version, written before any hash is computed; the measurements of section 7 and of what a spawn that ships code costs; the soundness argument's section 7 extended to identity by hash on one node across a load; and the report's sentences, §8.7 for the spawn that carries its code, the bare node and `build`, §8.6 for the end that tells its subscribers and waits for their answers, Appendix E.23 for `Os.terminating`, §11.1 for what an `.erc` holds, §11.2 for a bare node, for the shell's reload, which is a load of what changed, and for what a node lets go, §8.7 for a peer that can spawn on a node running what it sends, §11.3 for `build`, Appendix E.22 for the refusal, Appendix G.1 for a table that holds no function, Appendix G for `Standing`, and the glossary's words, hash, identity, closure and code table, in Appendix F and in `docs/style.md`. The rewrite names the sections whose rules it changes: §8.1, §8.5, §8.6 and §11.8, for a bare node's entry process that runs no `main` and ends by termination; §6.10, whose cross-node sentence is completed by a spawn that carries its code; §7.4, §8.4 and §11.2, from which `Fault("its code was unloaded")` goes, since nothing is unloaded; and `docs/development.md`'s table, from which the refusals naming MVP 3.1 go, and the two naming MVP 3.2 become plain unknown-field refusals.

## 10. Left out on purpose

- Of nodes of different builds working together, which the floor and the key's identity bring back, the rest: a type's identity by its shape, `ern diff`, a service offered at an old identity through a conversion or a forwarder, and two builds for a changed protocol; [`set_aside/builds_side_by_side.md`](set_aside/builds_side_by_side.md) is their record.
- A deploy the runtime orders and checks: the coordinator, the plan, lockstep, a node's restart inside its host process, the `build` file, the cache, the way back, the generated test, `ern deploy`, `ern status` and `ern state`, and `drain` and `coordinator` in `ernest.conf`. A deploy is the operator's script over `ern stop` and `ern run`; [`set_aside/ordered_rolling_restart.md`](set_aside/ordered_rolling_restart.md) is the record.
- A state the runtime holds and writes, `kept`, a member `migrate`, a state file and `./.ernest/state/`, and the planned stop's withdrawal of keys and its drain, kept at first from that proposal and set aside on the read-through of 2026-10-08: the keys and the drain served the rollout's find and its next node, and the kept state dragged in five concepts, the type's identity by its shape among them, for what a program does for itself with `Fs` and `Json` once it is told of its end. What a program lacked was only to be told, which `Os.terminating` gives.
- A module `Code` of the standard library, `load` and `hashes`: no Ernest code has anything to load by name, the shell's load is the session's, and `hashes` served `ern diff`.
- A bare node of a build, given it by its configuration or by its first peer: with no build in the cookie it is of none, and needs neither.
- An upgrade in place of a running process by anything but §6.10's message on its own node, and a change of a mailbox type under a translation: [`set_aside/deploy.md`](set_aside/deploy.md)'s section 15 says what they would cost, and [`set_aside/code.md`](set_aside/code.md)'s part two is the record of the thinking.
- A state moved to another of its key's peers; an election, a lease, and a service that moves by itself at a failure: a library's, over a store outside the nodes.
- A bound of the runtime's own on the end's wait: a subscriber's answer is what the end waits for, and a second termination or the service manager's patience is the bound.
- Unloading code: a node's code is bounded by section 7's limits, and a node warned restarts.
- A node that boots the platform over the network, and the key such a node receives.
- A compiled binary in a code frame, trusted as its sender is.
- A project's name above a qualified name.

## 11. Room for what comes after

1. **Nodes of different builds**, which [`set_aside/builds_side_by_side.md`](set_aside/builds_side_by_side.md) designs whole: the hash and the canonical form are built here as it needs them, and a key compares a text that an identity can replace without a program noticing. What would bring it back is a system too large to stop whole.
2. **A deploy the runtime orders**, which [`set_aside/ordered_rolling_restart.md`](set_aside/ordered_rolling_restart.md) designs whole over the first, and a state the runtime holds for it, with `migrate`: the end that tells its subscribers is the half of its planned stop that stays, and a kept state would stand on it. What would bring it back is the same.
3. **A process's code is a hash it can be asked for.** `Process.info` may gain the hash of the function a process was started with, so that a node can list the processes still on old code after a fix from the shell.
4. **The memory of code is bounded, not reclaimed.** A node that never restarts takes every version, the host's tables never shrink, and section 7's limits and warning are the answer; no name of a unit of the host's is a hash, so a pool of reused names stays possible.
5. **The canonical form is frozen** when it is written down, and changed seldom, each change a new scheme version and a stop of every node; whatever runs before hashing is part of it.

Three places carry the most risk. The canonical form, where two hashes for one definition or one hash for two cost most, and where everything that runs before hashing, elaboration and how supplies are filled, must be fixed with it. The host's limits, which bound a node's life by what it loads, and which a later OTP relieves. And the end's wait, which has no bound of the runtime's, so that a subscriber that forgets to answer holds a node until its service manager's patience runs out, which the deployment guide teaches to set above what the program's writing takes.
