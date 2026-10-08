# Ernest: MVP 3.1, Code with a Spawn

Status: the proposal for MVP 3.1, written on 2026-10-08 by MVP 3.0's item 12 from two proposals set aside the same day, [`set_aside/builds_side_by_side.md`](set_aside/builds_side_by_side.md) and [`set_aside/ordered_rolling_restart.md`](set_aside/ordered_rolling_restart.md), and rewritten on its read-through with the user the same day and night. It is read through before a line of it reaches the plan, the log or the report, and changes only by a question raised against it. What was tried that day and set aside is [`code.md`](code.md)'s section 8. The reasons are [`code.md`](code.md)'s and [`nodes.md`](nodes.md)'s sections 4, 6, 14 and 15; what other systems do is [`other_systems.md`](other_systems.md), sections 6 and 7; what six programs showed of a change of code in place is [`experiments/code_update/`](experiments/code_update/README.md).

## 1. What it is

MVP 3.1 does two things. A spawn carries its code to a peer that lacks it. A program is told of its termination before the end.

A process on one node spawns a process on a peer. The function may be one the peer does not have: one typed at the shell, or one of a program the peer was never given. The code crosses with the spawn, named by its hash. A process that subscribes to the program's termination is told of it, in its own mailbox type. It writes what it keeps and answers. The program ends once every subscriber has answered.

Four things bound it.

- **The floor.** Every node runs the same release of `ern` on the same major release of OTP. The cookie holds that and nothing else. Nodes of different builds connect, and the hashes say what may run where, at a spawn and at a find.
- **A hash for each definition.** The compiler computes it from the definition's canonical form. It names code where code crosses, in a spawn, and nowhere else.
- **No change in place.** A process takes new code only by its own act, §6.10's message on its own node. A deploy is stop all and start all.
- **Nothing ordered, and nothing kept.** No coordinator, no plan and no command of `ern`'s orders a deploy: an operator's script does, with `ern stop` and `ern run`. The runtime holds no state for a program. A program told of its termination writes what it keeps, with `Fs`, and reads it at its next start.

The bounds of MVP 3.0 stay: a few nodes with one owner, listed by hand, trusted completely; no discovery; nothing the runtime retries.

**Words.** A *definition* is a function, a type or a top-level binding. Its *hash* is the SHA-256 of its canonical form. Its *identity* is what a reference to it names: for a function or a type, its hash; for a binding, its qualified name with its hash. Two definitions with one hash are one definition, whatever they are called. A definition's *closure* is the definition with everything it references, transitively. A *unit* is one module of the host's, holding compiled definitions. The *code table* is a node's table from each hash to the unit and function that hold it. The *exchange* is the frames by which a spawn ships code. A *bare node* runs no program. A *subscriber* is a process that called `Os.terminating`.

## 2. What a program sees

**The operations** are MVP 3.0's, with one difference: a spawn on a peer carries its code where the peer lacks it. `Peer`'s functions and `Peer.Failure` are unchanged. `NotLoaded` means that the peer lacks something the function needs: a binding's value, or the module a foreign declaration names. `Refused` means that the peer could not load what was sent, and its text says why. A connection the handshake refused is `Unreachable`, as in MVP 3.0.

**What is new.**

- **A bare node.** `ern run --config-dir dir` with no `.erc` starts a node that holds no definition of a program's. It runs the runtime and the system processes, its entry process evaluates the standard library's bindings, and the node listens and waits. It ends by termination alone. Everything it runs arrives by a spawn from a peer, with the code. Nothing is copied to its machine but `ern`. A node without `listen` is refused at its start, since it never dials. A balancer places work on it as on any peer, and installs its measure there with `Balancer.serve`.
- **The shell's `:load` and `:reload`** work in a shell that is a node. A load adds hashes and moves the session's names to them. A binding made before a load keeps the type it was checked under. A function typed at the shell spawns on a peer with its code. A shell whose load path holds no program is a bare node with a prompt.
- **Termination told.** `Os.terminating(wrap)` subscribes the calling process to the program's end. The program ends by termination, which the machine's service manager, `ern stop --config-dir dir` and `kill -TERM` send; by its entry process's end; or by `Os.exit`. At the end the runtime delivers `wrap(reply)` to each subscriber. The process takes the message in its own `receive`, writes what it keeps, and answers. The program ends once every subscriber has answered or ended. The interrupt, and a second termination, end at once. A subscription is one per process, the latest, and ends with its process. A program that is no node is told the same way.
- **`Standing.start(key, ms)`**, of the library `Standing` under `libs/`, spawns a process that finds the key and forwards to the service what it is sent, and answers `via` of that process. The process finds the key within `ms`, monitors the service, and finds again when the service ends or its node is lost, waiting `ms` between failed finds. It ends with the process that started it. A send to it while the service is away is dropped. A call through it waits by its own time and answers `None` where the service is not back. It is an ordinary process, and every rule of the report holds of its address. A program that is to monitor the service itself holds the address `Peer.find` gives.
- **The refusal.** `Supervisor.child`'s function, run inside a process that is already a child, faults with `Fault("a process runs one child function")`.

```
Os.terminating : ((Reply(Unit)) -> m) -> Unit with m
Standing.start : (Peer.Key(m), Int) -> Address(m) with n
```

**What may cross** is MVP 3.0's rule. A bound type never crosses. The compiler refuses a key of a bound type, and a spawn whose captures are bound or hold a type variable. An adapted address's captures cross inside it as payload, touched only on the node that made it. The function a spawn starts crosses with its code, where the peer lacks it.

**Captures and references.** A top-level binding a spawned function names is the peer's, found by its identity, and `NotLoaded` where the peer did not run it. A local the function captures crosses as a value. So a value the function is to carry from the spawner is bound to a local first, `let key = Counter.key`, and captured. Nothing is read off the function's text but which names are locals. MVP 3.0's rule by module goes: a function spawns on a peer where every binding it names has its value there, whatever its module holds.

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

The first spawn ships the function, `count` and `Counter.Msg`. They are verified and loaded on the worker before the process starts. The second spawn ships nothing. The process offers itself, since only a process of the offering node may be offered. The function captures `key`, a local, and names no binding of the store's, so it runs there. Written with `Counter.key` inside it, the binding would be the worker's, which never ran it, and the spawn would answer `NotLoaded`. The worker's output goes to the worker's standard output.

**A fix from the shell.** The counter's `count` is to log each `Add`, and the program is not to be stopped for it. At a shell that is a node of the build, the operator types the new loop and sends it through §6.10's `Upgrade`, by a process spawned on the store with the code:

```ernest-fragment
fn count2(total : Int) : Unit with Counter.Msg = ...
let counter = Optional.withDefault(Either.toOptional(Peer.find(Counter.key, 5000)), ...);
Peer.spawn("store", fn() = send(counter, Counter.Upgrade(migrate = fn(n) = n, next = count2)), 5000)
```

The spawn ships `count2`, which the store lacks. The spawned process sends the message on the store's own node, where a function in a message is allowed (§3.11). The counter switches by a tail call, its total kept, as §6.10 has it. Under MVP 3.0 the spawn answered `NotLoaded`, since `count2` is in a module no peer has. The fix is in the running process alone: a restart of the store runs build 1's `count` again.

**A deploy.** Build 2 changes `count` to log each `Add`. The counter keeps its total across the stop, in a file it writes when it is told of the end and reads at its start:

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

The operator's script copies build 2 to every machine, runs `ern stop --config-dir dir` on each node and `ern run` on each with the new build. The worker is not touched. At the store's stop the counter is told, writes its total and answers, and the node ends in order. At the store's start the counter begins with the total from the file, and `main` offers it. The board holds `Standing.start(Counter.key, 5000)` in place of its find: it sees one `Down` with `ProgramEnd`, and finds the counter again once the store is back. A call through its standing address meanwhile answers `None` at its time.

**A changed state.** Build 3 counts the adds as well, and its state is a record `Count(total : Int, adds : Int)`. Its `saved` reads a file build 2 wrote, a number, into `Count(total = n, adds = 0)`, and a file build 3 wrote, an object, into the record. A file nothing reads begins the counter at `Count(total = 0, adds = 0)`. Nothing of the runtime takes part: the shape of the state, its file and its reading are the program's.

## 4. What holds

1. **A hash names one definition everywhere.** Two nodes that hold one hash hold one definition, whatever each build calls it.
2. **A node holds a hash only with its whole closure.** Nothing enters a node's code table before everything it references is there and verified.
3. **Code arrives verified or not at all.** Every definition that crosses is checked against its hash on arrival. A frame that fails ends the connection.
4. **A process keeps its code.** Nothing a process runs is ever changed or taken from it, in a spawn, in the shell's reload, or when a unit is let go.
5. **No message of one version is read as another's.** A key carries its type's hash beside its text, and a find answers `OtherType` where the holder's differs. A spawn carries its closure's hashes, so the function runs at the peer over the definitions it was compiled with. So what is sent through a remote address is of the type the receiver's code was compiled with, whichever builds the two nodes are of. On one node, across the shell's reload, a value keeps the type it was checked under: two versions of a type are two types in one scope, and the checker refuses a message of one to an address of the other.
6. **A subscriber is told before the end and answers before it.** The program ends once every subscriber has answered or ended. Nothing of the program runs after the end, which is in order, as in MVP 3.0.
7. **A client reaches its service after a restart without code of its own**, through the `Standing` library.

## 5. What does not hold

MVP 3.0's limits stand, every one. Its ninth holds for code that crosses: a peer's code is verified against its hash and run as the peer's own, trusted as the peer is. A peer that may spawn on a node may run anything on it.

1. **A deploy stops every node and starts every node.** Nothing orders it: the operator's script does, and a service is away for its node's restart. A node started with the new build before another was stopped connects to it. A find across them answers `OtherType` where the key's type changed, and an address where it did not.
2. **A protocol changed is a service not found.** A key at a type that changed has a new identity. A client of the old finds `OtherType` until it is rebuilt and restarted. Nothing serves the old identity through a conversion.
3. **Code that arrived stays while something runs it, and comes again when asked.** A unit let go crosses again at the next spawn that needs one of its definitions. A node that holds many versions at once, their processes alive, says so on its standard error when it nears a limit of the host's (section 7).
4. **A spawn that ships code is slow once.** The first spawn of a definition on a node that lacks it crosses the closure, compiles it there and loads it, within the spawn's time or `Timeout`. The next spawn ships nothing. A fix to a definition many call costs the peer the compile of every caller, since each caller is a new definition. For a definition everyone calls that is the compile of the program, once per node.
5. **A spawned function finds no binding the peer did not run.** It names the standard library's bindings and carries the rest as captured locals, or the peer answers `NotLoaded`. On a bare node that is every binding of the program's.
6. **A foreign declaration's implementation is outside the hashes.** A `foreign fn` names a host module, which is each node's own. A shipped definition that names it runs the peer's copy. A module of OTP's or of `ern`'s is on every node. A library's own Erlang is where the library is, and a bare node lacks it. So `Load`'s shims are over OTP's modules, and `Json`'s primitives are `ern`'s, in `erl/json`.
7. **A second offer under a key a living process holds faults the offerer**, on a bare node as on any. A peer that is to take a key over finds its holder by the key and kills it first.
8. **What a program keeps is its own.** The runtime holds no state and reads none back. A process told of the end writes what it wants, in the form it wants, and reads it at its next start. A changed shape is its own reading code. A process that is not told keeps nothing: one that did not subscribe, or one that faults before the end.
9. **The end waits for its subscribers and for nothing else.** A request in flight at the end is lost, as at any loss. A message that reaches a subscriber after it answered is lost with the process. A subscriber that neither answers nor ends holds the program until a second termination, the interrupt, or the service manager's patience, which kills. Nothing withdraws a key before the end: a peer finds, calls and sends to a process told of the end, until the end.
10. **A retry is the program's.** A call that answered `None` may or may not have run, so a request must be harmless when run twice.

## 6. How it works

**The hash.** The canonical form is the typed tree after checking: local variables numbered by position, layout and comments gone, every name resolved, types written out. A reference to another definition is the hash of what it names, and nothing else. A reference to a foreign declaration, which has no hash, is its qualified name and its type; each node resolves it for itself. A function's own name and its source positions are not in its hash, so two functions with one body are one definition. A binding's identity is its qualified name with its definition's hash, since a binding is a thing that exists on a node, and two bindings with one initializer are two. A type's hash covers its qualified name, its parameters by position, and its constructors in declared order with their fields' names and the hashes of their types. A mutually recursive group is the strongly connected component of the dependency graph, hashed as one in source order; each member's identity is the group's hash and its position in it. A lambda's identity is its enclosing definition's hash and its position in it. An applied type's identity is its constructor's hash over its arguments' identities; a built-in type's is its name. The scheme's version is mixed into every hash, and changes with any change to what runs before hashing, the canonical form and the checker among it. The canonical form is written down, literals and order fixed, before any hash is computed. The site a spawn frame carries is the spawner's build's words, shown and never compared.

**The cookie and the floor.** The cookie is the digest of the protocol's version, `ern`'s version and OTP's major release, `erlang:system_info(otp_release)`. The build is not in it, and MVP 3.0's fingerprint goes. What the hashes leave out agrees by the cookie: the runtime's functions and the standard library, which shipped code calls by name, and every foreign declaration over a module of OTP's or of `ern`'s. A library under `libs/` is a program's code, hashed and crossing with it.

**Messages and keys.** A message carries nothing of its type and goes straight into the mailbox. A key carries its type's text, as in MVP 3.0, and its type's hash beside it. Serialization and the gateway are MVP 3.0's.

**Bindings.** A node holds its bindings' values by identity. Nothing is initialized because a peer asked. A node of a build offers what that build started, and a bare node what its peers spawned on it.

**A node's code.** A node holds definitions by hash in its code table. The compiled code lives once, as units. The definitions that arrive in one exchange become one unit, under a name of the node's own, its functions named by their position in it. Before the unit is compiled, each reference is linked through the table: a reference to a definition of the unit becomes a local call, and one to a definition of another unit a call into that unit. The node's own build is compiled the same way, by the same back end from the same forms, one unit per source module, with the same table over it. What one load brings to a node that already holds a unit of that module's name becomes a unit of its own, so a unit of the host's never takes a second version. Nothing names a unit. The canonical form of the node's own definitions is in its `.erc` files, read and verified against its hash when the node ships one. A build directory is never changed under a running node; a new build goes in a directory of its own. The canonical form of a received definition, and of one typed at the shell, is kept beside its compiled code, and the node ships it onward as its own. Loading is by the host's `prepare_loading` and `atomic_load`, one batch per closure, with no `-on_load`. The node's units are off the code path, where nothing loads them but the node, and the node loads otherwise as `ern run` does today. Nothing of a node's code is on its disk but its build directory: a node restarted holds its build, and is sent the rest again.

**What a node lets go.** A unit that arrived by an exchange or a load is unloaded when no process executes it or holds a function of it. The host tells, `erlang:check_process_code`. The build's own units are never unloaded. A table holds no function: the compiler accepts `Ets.Table(k, v)` only where `k` and `v` hold no function type, the first case of §3.11's bound check. So every holder of a function is a process, and the host's check sees it. The node sweeps when it nears a limit of section 7, and lets go the units no process runs, oldest first, until it is under the limit; a unit no process runs stays until then, so a worker whose tasks end and are spawned again ships nothing. A unit unloaded leaves the table, and its name returns to the pool. A spawn that asks for one of its definitions again is sent it again, one exchange.

**A spawn that carries its code.** The spawn frame carries the function's hash, its captured values and the site. A peer that has the hash starts the process at once. A peer that lacks it asks for the closure's list. The sender sends the hashes the function references transitively, code and types, with the foreign declarations it names, and each definition's source name as a hint. The peer answers with the hashes it lacks, and for each, the hashes it holds under the same source name; or with `NotLoaded`, where it lacks the module a foreign declaration names or the value of a binding the function names. The sender ships the missing code, dependencies first. A code frame carries one definition's canonical form with its immediate references, never a compiled binary; or a delta, where the peer holds a definition that differs from the shipped one in its references alone: the held hash and the references that differ, from which the peer makes the form. So a fix to a definition many call ships the fix and a line for each caller; the callers are compiled on the peer and never cross. The four frames, the request, the list, the lacks and the code frame, are Ernest's beside MVP 3.0's six. The peer verifies each frame against its hash as it arrives and holds it apart until the closure is complete. Then it compiles the closure with its own back end, loads it all at once, and starts the process. What the peer said it has is pinned until the load is done. A frame whose content does not match its hash is a faulty frame, and the connection ends. A closure the peer cannot compile or load fails the spawn with `Refused`, whose text is the peer's. The exchange runs in a process of its own on each node, and the gateways only pass its frames. The spawn's time covers the exchange. What arrived complete stays in the code table, and two spawns waiting on one hash share one exchange.

**The shell.** `ern shell --config-dir dir` is a node, as in MVP 3.0, and its `:load` and `:reload` work. Each adds hashes and moves the session's names to them. A type in the session is its hash, so a binding made before a load keeps the type it was checked under. A message of a type's new version sent to an address of the previous one, or the reverse, is a type error, whose diagnostic says which of the two is of the previous version. A local address is a pid alone, and constructors of one name in two versions are one term, so the checker is the one thing that tells the versions apart on one node, as the hashes are between nodes. A process of a previous version runs on until it ends or is killed, reachable through the addresses of its version alone, its key offered again only once it has ended. A load evaluates the closure's bindings in a fresh process at `Never` while the session waits. Nothing a reload loads is a second version of a unit, so §11.2's fault for a further reload, `its code was unloaded`, goes, and with it from §7.4 and §8.4. A function typed at the shell has a hash as any definition has, and spawns on a peer with its code. The session's load is the session's, as today, and no module of the standard library loads code by name.

**Termination told.** The runtime keeps the subscription as it keeps one to faults. At the end it delivers `wrap(reply)` to every subscriber, each delivery a process of its own as a monitor's is, and watches each subscriber as it watches a callee. Once every reply is answered or its subscriber has ended, the end is MVP 3.0's, in order: every live process ends with `ProgramEnd`, the `Down`s cross, the connections close. While the runtime waits, every other process runs, and a peer finds, calls and sends to the node as before. A subscription made after the subscribers were told is told at once. A subscriber that faults while it writes is reported, and the end goes on without it. Under `ern test` and in the shell the program is told the same way.

**The standing address.** `Standing` is Ernest, and the runtime has no part in it. Its process has the mailbox type `Message(m) | Went(Down)`, and the caller is given `via` of it with `Message`. It holds the address `Peer.find` gave, monitors the service's process, and forwards each `Message`. At `Went` it finds again. It monitors the process that called `start`, and ends at its `Down`. The forwarder is one more process on a message's way, so a message through it may pass a message sent directly, as through any process (mvp3.0.md's claim 4.1).

**The refusal.** `Supervisor.child`'s function reads the process's start cause when it begins. Run inside a process that is already a child, it would read the outer child's, so it faults instead, `Fault("a process runs one child function")`, and E.22 says so.

## 7. The numbers

| What | Value |
|---|---|
| a definition's hash | SHA-256 over its canonical form, the scheme's version mixed in |
| the cookie | the protocol's version, `ern`'s version and OTP's major release; no build |
| a code frame | one definition's canonical form, with its immediate references; or a delta, a held hash and the references that differ |
| what a fix crosses | the changed definitions, and a delta for each caller whose hash changed with them |
| a unit let go | one no process executes or holds a function of, oldest first, when the node nears a limit; a table holds none; the build's never |
| the frames of this milestone | four, beside MVP 3.0's six |
| atoms a node can make in its life | 1,048,576, the host's, never reclaimed: every unit's name and every function's; a name is reused when its unit is let go |
| module names a node can load in its life | 65,536, the host's (OTP 29); a unit let go returns its name to the pool |
| lambdas a node can load in its life | 524,288, the host's, never reclaimed (OTP 28 and later) |
| a node says it nears a limit at | four fifths of any of the three |
| the end's wait | until every subscriber has answered or ended; none of the runtime's own |

## 8. How it is checked

The canonical form has a test suite of its own, written with the form before any hash is computed. Its cases: the same definition hashes the same across a rebuild; a renamed function keeps its dependents' hashes, and a renamed constructor changes them; a moved definition in a group changes the group's hash; two bodies that differ only in local names or layout hash the same; a literal's encoding is fixed. Two hashes for one definition, and one hash for two, are what it guards against.

The runtime's tests start nodes on one machine, as MVP 3.0's do. Of code: a spawn of a function typed at a shell that is a node ships exactly the lacking definitions, verified and loaded at once, and the process runs; a spawn onto a bare node ships the program's closure once and nothing the second time, and the process offers a service the program finds; `NotLoaded` for a binding the peer did not run and for a foreign declaration it lacks; a function that names no binding spawns where MVP 3.0's rule by module refused it; a faulty frame ends the connection; a late or broken exchange leaves nothing half-loaded; a fix crosses as deltas, and the callers compile on the peer; a unit whose processes have ended stays until the node nears a limit, is then let go, and crosses again at the next spawn that needs it, and one a process holds a function of stays; a table of a function type is refused by the compiler; two nodes of different builds connect, and a find across them answers `OtherType` where the key's type differs and an address where it does not; a node told to load many units says so at four fifths of a limit, once, measured; the shell fixes a service on a peer through `Upgrade`; in the shell, a binding made before a `:reload` that changed its type refuses a message of the new version and takes one of its own, and the previous version's service runs on through two further reloads of its module. Of the end: a subscriber is told at termination, at the entry process's end and at `Os.exit`, and the program ends after its answer and not before; a subscriber that ended holds nothing up; a subscriber that faults while it writes is reported, and the end goes on; a second termination and the interrupt end at once; a subscription made during the end is told at once, and one made by a process that ended is gone with it; a program that is no node, a test under `ern test` and the shell are told the same way; a peer finds and calls a node whose subscribers are being told. Of the library: `Standing` drops a send and answers `None` to a call while the service is away, reaches it again on the same node and on another, and ends its process with its caller. And E.22's refusal.

A program's own test of two nodes needs nothing new: `ern test --config-dir dir`, with the other node started by `Os`, as in MVP 3.0.

## 9. Unsolved

Every question the proposal was written through is decided. What remains is the build's:

- the canonical form's document, with the scheme's version, written before any hash is computed; what an abstract type's hash covers beyond its declaration is its to decide;
- the measurements of section 7, and of what a spawn that ships code costs, a bare node's first spawn and the callers of a fix above all;
- the soundness argument's section 7, extended to the hashes between nodes of different builds and to identity by hash on one node across a load;
- the report's sentences: §8.7 for the floor, the spawn that carries its code, the bare node, and a peer that may spawn on a node running what it sends; §8.6 for the end that tells its subscribers and waits for their answers; Appendix E.23 for `Os.terminating`; §11.1 for what an `.erc` holds; §11.2 for a bare node, for the shell's reload, and for what a node lets go; Appendix E.22 for the refusal; Appendix G.1 for a table that holds no function; Appendix G for `Standing`; and the glossary's words, hash, identity, closure, unit, code table and exchange, in Appendix F and in `docs/style.md`;
- the sections whose rules change: §8.1, §8.5, §8.6 and §11.8, for a bare node's entry process that runs no `main` and ends by termination; §6.10, whose cross-node sentence is completed by a spawn that carries its code; §7.4, §8.4 and §11.2, from which `Fault("its code was unloaded")` goes; and `docs/development.md`'s table, from which the refusals naming MVP 3.1 go.

## 10. Left out on purpose

The reasons are [`code.md`](code.md)'s section 8.

- Of nodes of different builds working together, the rest: a type's identity by its shape, `ern diff`, a service offered at an old identity through a conversion or a forwarder, and two builds for a changed protocol.
- A deploy the runtime orders and checks: the coordinator, the plan, lockstep, a node's restart inside its host process, the `build` file, the cache, the way back, the generated test, `ern deploy`, `ern status`, `ern state`, and `drain` and `coordinator` in `ernest.conf`.
- A state the runtime holds and writes, `kept`, a member `migrate`, a state file and `./.ernest/state/`; and the planned stop's withdrawal of keys and its drain.
- A module `Code` of the standard library, `load` and `hashes`.
- A bare node of a build, given it by its configuration or by its first peer.
- An upgrade in place of a running process by anything but §6.10's message on its own node, and a change of a mailbox type under a translation.
- A state moved to another of its key's peers; an election, a lease, and a service that moves by itself at a failure.
- A bound of the runtime's own on the end's wait.
- A scan of tables, or a count per table, before a unit is let go.
- The emitter's forms as what crosses, in place of the typed tree.
- A node that boots the platform over the network, and the key such a node receives.
- A compiled binary in a code frame.
- A project's name above a qualified name.

## 11. Room for what comes after

1. **The rest of nodes of different builds**, which [`set_aside/builds_side_by_side.md`](set_aside/builds_side_by_side.md) designs whole: a service that serves an old identity through a conversion, two builds for a changed protocol, `ern diff`. What would bring them back is a protocol that cannot be changed by rebuilding its clients.
2. **A deploy the runtime orders**, which [`set_aside/ordered_rolling_restart.md`](set_aside/ordered_rolling_restart.md) designs whole over the first, and a state the runtime holds for it, with `migrate`. What would bring it back is a system too large to stop whole.
3. **A process's code is a hash it can be asked for.** `Process.info` may gain the hash of the function a process was started with, so that a node can list the processes still on old code after a fix from the shell.
4. **When a node sweeps.** A unit is let go when the node nears a limit; a sweep on a clock, or by how long a unit has gone unused, is a measurement away.
5. **The canonical form is frozen** when it is written down, and changed seldom: each change is a new scheme version and a stop of every node. Whatever runs before hashing is part of it.

Three places carry the most risk. The canonical form, where two hashes for one definition or one hash for two cost most, and where everything that runs before hashing, elaboration and how supplies are filled, must be fixed with it. The compile on the peer, a bare node's first spawn and the callers of a fix, which the spawn's time bounds and the measurements must show fits it. And the end's wait, which has no bound of the runtime's, so that a subscriber that forgets to answer holds a node until its service manager's patience runs out, which the deployment guide teaches to set above what the program's writing takes.
