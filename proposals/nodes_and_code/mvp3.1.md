# Ernest: MVP 3.1, Code by Its Hash

Status: the proposal for MVP 3.1, code by its hash, written on 2026-10-07 before MVP 3.0 is built; it changes only by a question raised against it. Changed on 2026-10-07 by [`mvp3.2.md`](mvp3.2.md), whose reasons are [`deploy.md`](deploy.md)'s: a node keeps its code on disk by hash, and the cookie carries the runtime surface's version in place of `ern`'s. The reasons for what it says are [`code.md`](code.md)'s part one; what other systems do is [`other_systems.md`](other_systems.md), section 6.

## 1. What it is

MVP 3.1 names every definition by a hash of its content, and lets nodes of different builds work together. A process on one node spawns a process on a peer with code the peer does not have, and the code crosses with the spawn. Versions of a definition stand side by side on a node, and a process keeps the code it was started with until it ends.

It is step C of [`code.md`](code.md)'s section 1, *The four steps*, and nothing of step D; step B is not built on its own. Three things bound it:

- **A hash for each definition.** The compiler computes it from a canonical form of the definition, and it is the identity of code and of types everywhere: in a spawn, in a key, on a message.
- **Code crosses by one exchange, on two occasions.** A node that lacks a hash asks for the closure's list, the node that named the hash ships what the asker lacks, and the whole closure is present before anything is done with it. The occasions are a spawn, where the spawner names the function's hash and the peer then compiles, loads and starts; and a root a node is told before a planned stop (`mvp3.2.md`), where the coordinator names it and the node compiles and writes to its cache, and loads nothing. A message ships no code; a find ships no code.
- **No change in place.** A process never takes new code. A deploy is a rolling restart, node by node: new nodes start beside old ones, old processes run old code until they end, and a service is found by its key at whichever version it is.

The bounds of MVP 3.0 stay: a few nodes with one owner, listed by hand, trusted completely; no discovery; nothing the runtime retries. Its four rules rule here too, and the fourth, *what crosses is identified, never named*, is this milestone whole: a function's module and place, and the type's text in a key, become hashes; a key's name stays a name, and so does a foreign declaration's, which names the host's and has no hash.

**The building block.** A *definition* is a function, a type, or a top-level binding, and its *hash* is the identity it has on every node: two definitions with one hash are one definition, and two with different hashes are two, whatever they are called. A node holds code by hash, loads by hash, and ships by hash. A name is a build's own word for a hash, and a build moves a name from one hash to another without touching either.

## 2. What a program sees

**The operations** are MVP 3.0's, with one difference: a spawn on a peer carries its code where the peer lacks it. `Peer`'s functions and `Peer.Failure` are unchanged. `NotLoaded` means what the function needs and the peer does not have: a binding's value, or the module a foreign declaration names. `OtherType` means a service at another version. `Refused` is the peer's refusal of a closure: its text says why the peer could not load what was sent; a connection the handshake refused is `Unreachable`, as MVP 3.0 has it.

**What is new.**

- **A bare node.** `ern run --config-dir dir` with no `.erc` starts a node that holds no definition of a program's: it runs the runtime and the system processes, evaluates the standard library's bindings, listens, and waits. Its entry process evaluates the standard library's bindings, as any program's does, and then waits; the node ends by termination alone. Everything it runs arrives by a spawn from a peer, with the code. A spawned function there names no binding but the standard library's and carries the rest as captured locals, and a spawned process may offer itself under a key. Nothing is copied to such a machine but `ern`. A balancer places work on it as on any peer, and installs its measure there by `Balancer.measure(place, f)`, whose measuring process carries `Balancer.key` as a captured local and names no binding. A bare node has no root and nothing of a build is its own, so no rollout restarts it (`mvp3.2.md`): the code spawned on it stays until the node restarts, bounded by section 7's limits and their warning, at which an operator restarts it with `ern stop`. A bare node whose `ernest.conf` has no `listen` is refused at its start, since it never dials.
- **`Code`**, a module of the standard library for the toolchain's own Ernest code and for tools. `Code.load(path)` loads a compiled module and its closure from a build, at once, its bindings evaluated in a fresh process at `Never`, as §8.5 evaluates a program's, while the caller waits, and answers `Either(Code.Error, Unit)`, where `Code.Error = NotFound | Stale | Incomplete | Faulted(String)`: no compiled module at the path, one compiled against another interface, a closure whose definitions the build does not hold, or an initializer that faulted, with its cause. `Code.hashes(path)` answers a compiled module's definitions as name and hash. `Code` is what the shell's `:load` and `:reload` and `ern diff` stand on; a program has nothing to load by name.
- **`ern diff old-build new-build`** lists the definitions whose hash differs between two builds, `changed` where the definition's own form differs and `follows` where only a reference does, and among them the keys whose type identity differs, which are the services that answer `OtherType` across a rollout.
- **The shell's `:load` and `:reload`** work in a shell that is a node, which MVP 3.0 refused: a load adds hashes and moves the session's names, a binding made before it keeps the types it was checked under, and a function typed at the shell spawns on a peer with its code.

**What may cross** is MVP 3.0's rule unchanged: a bound type never crosses, the compiler refuses a key of a bound type and a spawn whose captures are bound or have a type variable in their type, and an adapted address's captures cross inside it as payload, touched only on the node that made it. The function a spawn starts crosses with its code, where the peer lacks it.

**Captures and references.** A top-level binding a spawned function names is the peer's, resolved by its identity, and `NotLoaded` where the peer did not run it; a local the function captures crosses as a value. A value the function is to carry from the spawner is bound to a local first, `let key = Counter.key`, and captured as any local is. The rule is one, and nothing is read off the function's text but which names are locals.

## 3. Examples

The counter of [`mvp3.0.md`](mvp3.0.md)'s section 3 runs on the store, and the desk and the board find it by `Counter.key`. The program is at build 1 on every node.

**A fix behind the protocol.** Build 2 changes `count` to log each `Add`. `ern diff build1 build2` prints:

```
store.ern  fn count       changed
store.ern  let counter    follows
store.ern  fn main        follows
```

`follows` marks a definition whose own form is unchanged and whose hash changed through a reference. No key is listed: `Counter.Msg` is unchanged, so `Counter.key`'s identity is the same in both builds. The operator copies build 2 to the store's machine, stops the store and starts it. A board that monitors the counter is told `ProgramEnd`, finds the counter again by its key, and gets build 2's counter; the board as MVP 3.0's section 3 writes it, without a monitor, sees the restart as it sees any, its calls answering `None`. The desk and the board are still at build 1, and nothing of the two builds shows.

**A changed protocol.** Build 3 adds `Reset` to `Counter.Msg`. `ern diff build2 build3` prints:

```
counter.ern  type Msg        changed
counter.ern  let key         follows    key "counter": identity changed
store.ern    fn count        changed
store.ern    let counter     follows
store.ern    fn main         follows
desk.ern     fn main         follows
board.ern    fn main         follows
board.ern    fn show         follows
```

The store is restarted with build 3 first. A board started on build 1 after the store's restart gets `Left(Peer.OtherType)` from its find and prints "the store is not there"; once the board is at build 3, it finds the counter. The desk at build 1 meets the same, and is restarted in its turn.

**A bare node.** A fourth machine, `worker`, is started with `ern run --config-dir /etc/ernest/worker` and no program, and listed by the store. The store spawns on it:

```ernest-fragment
let key = Counter.key;
match Peer.spawn("worker", fn() = { Peer.offer(key, self()); count(0) }, 5000) {
    Left(_) -> Io.println("no worker")
  | Right(_) -> Unit
}
```

The first spawn ships the function, `count` and `Counter.Msg`, verified and loaded on the worker before the process starts; the second ships nothing. The process offers itself, since only a process of the offering node may be offered. The function captures `key`, a local holding the key's value, and names no binding of the store's, so it runs there; written with `Counter.key` inside it, the binding would be the worker's, which never ran it, and the spawn would fail with `NotLoaded`. The worker's output goes to the worker's standard output. When the store is restarted with a new build, its next spawn ships the new `count`, and the old one runs on until it ends.

## 4. What holds

1. **A hash names one definition everywhere.** Two nodes that hold one hash hold one definition, whatever each build calls it.
2. **A node holds a hash only with its whole closure.** Nothing enters a node's store before everything it references is there and verified.
3. **Code arrives verified or not at all.** Every definition that crosses is checked against its hash on arrival, and a frame that fails ends the connection.
4. **A process keeps its code.** Loading only adds; nothing a process runs is ever changed or taken from it.
5. **No message of one version is read as another's.** What is sent through a remote address is of the type the receiver's code was compiled with, since a find compares identities before any address crosses. What is sent through a local address is of the type its process was spawned under, since a value keeps the hash it was checked under through a load: two versions of a type are two types in one scope, as they are across nodes, and the checker refuses a message of one to an address of the other.
6. **A renamed function changes nothing that is not renamed.** Renaming a function changes no hash but its own build's name for it. A type and a binding are the exceptions (section 5).
7. **Nodes of different builds connect, and of different `ern`, OTP or hash scheme never.**

## 5. What does not hold

MVP 3.0's limits stand, but the first half of its eleventh: builds that differ connect. Its ninth holds for code that crosses: a peer's code is verified against its hash and run as the peer's own, trusted as the peer is.

1. **A renamed type is the same type, a renamed constructor or field a new one, and a renamed binding a new binding.** Renaming a type or moving it to another module changes no hash, since a type's hash is its shape; renaming a constructor or a field changes its hash and every dependent's, and a service whose protocol holds it is at another version to every client of the old build. Renaming a top-level binding changes its identity and every dependent's, and a peer that ran the old name has no value for the new.
2. **A changed protocol parts old clients from new services for the length of a rollout.** A changed member of the type, `compare` among them, is a changed protocol. An old client's find on a node of the new build answers `OtherType`, and a new client's on an old node the same, until both are of one build; a client written for peers waits and finds again, as it does for `Unreachable`. A change to a type that many protocols carry parts clients from every service that carries it at once.
3. **Code loaded on a node stays until the node restarts, and on its disk until the plan lets it go.** Nothing is unloaded while a node runs. A node keeps the closures of the builds it has run and of the one it is about to run on its disk, by hash, and a build's hashes leave when a newer build has run and `ern deploy`'s plan no longer names the old one as the way back (`mvp3.2.md`). A node that outlives many deploys of its peers, a bare node among them, says so on its standard error when it nears a limit of the host's (section 7), and is restarted.
4. **An upgrade of OTP, of the hash scheme or of the runtime's surface stops every node.** Nodes of different versions of any of the three never connect. A release of `ern` that keeps the runtime's surface is a rollout like a program's (`mvp3.2.md`).
5. **A spawn that ships code is slow once.** The first spawn of a definition on a node that lacks it crosses the closure, compiles it there, and loads it, within the spawn's time or `Timeout`; what arrived complete stays, and the next spawn ships nothing.
6. **A spawned function finds no binding the peer did not run.** It names the standard library's bindings and carries the rest as captured locals, or the peer answers `NotLoaded`. On a bare node that is every binding of the program's.
7. **A foreign declaration's implementation is outside the hashes.** A `foreign fn` names a host module, which is each node's own; two builds whose Erlang under one foreign name differs are not told apart, and a shipped definition that names it runs the peer's. A foreign declaration over a module of OTP's or of `ern`'s is on every node; one over a library's own Erlang is where the library is, and a bare node lacks it, so the `Load` library's shims are over OTP's modules.
8. **Two peers that offer under one key on a bare node replace each other**, the latest offer holding, as MVP 3.0 has it.

## 6. How it works

**The hash.** Two words, used so throughout: a definition's *hash* is the SHA-256 of its canonical form, and nothing else; its *identity* is what a reference names and a find compares, a function's its hash, a binding's its qualified name with its hash, a type's its hash with its members' hashes. A definition's hash is the SHA-256 of its canonical form: the typed tree after checking, with local variables numbered by position, layout and comments gone, every name resolved, and types written out. A reference to another definition is the hash of what it names, and nothing else; a reference to a foreign declaration, which has no hash, is its qualified name and its type, and each node resolves it for itself. A function's own name and its source positions are not in its hash: two functions with one body are one definition. A top-level binding's *identity* is its qualified name with its definition's hash, since a binding is a thing that exists on a node, a value or a process, and two bindings with one initializer are two; a reference to a binding is its identity, so a renamed binding is a new binding to what names it. A type's hash covers its parameters by position and its constructors in declared order with their fields' names and the hashes of their types, and not its qualified name: a type's representation at the boundary is its constructors and fields, so two declarations of one shape under two names are one type where a value crosses, and a type renamed or moved between modules keeps its identity. A type's *identity*, which a key carries and a find compares, is that hash with the hashes of the members the type declares, `compare` among them. The checker tells two declarations apart by name within a build as it does today. A mutually recursive group is the strongly connected component of the dependency graph, hashed as one in source order, and each member's identity is the group's hash and its position in it. A lambda's identity is its enclosing definition's hash and its position in it, and an applied type's is its constructor's hash over its arguments' identities, a built-in type's its name. No project name stands above a qualified name. The site a spawn frame carries is the spawner's build's words, shown and never compared. The scheme's version is mixed into every hash, and changes with any change to what runs before hashing, the canonical form and the checker among it, so that two releases hash one source alike or refuse each other. The canonical form is written down with it before any hash is computed, literals and order fixed, and everything that runs before hashing is part of it.

**The cookie.** Stated here and pointed at from everywhere else: the host's cookie is the digest of the protocol's version, the hash scheme's version, OTP's version and the version of the runtime's surface. A program's code is not in it: the build's checksum of MVP 3.0 leaves, and nodes of different builds connect. The runtime's surface is what shipped code calls by name, the runtime's functions and the standard library's foreign declarations, with the identity of the standard library's own Ernest, named and given a version of its own that changes when any of it does (`mvp3.2.md`); the compiler's back end and the standard library's Ernest are hashed as a program's code is. What the hashes leave out agrees by the cookie: the surface, the host's functions that code calls by name, OTP's; and a foreign declaration, which a peer resolves by name and type. A library under `libs/` is a program's code, hashed and crossing with it; the standard library is `ern`'s, and the same on every connected node.

**Messages and keys.** A message carries nothing of its type, as in MVP 3.0, and goes straight into the mailbox. A key carries its type's identity, in place of MVP 3.0's text; a find answers the address where the identities are the same, and `OtherType` where they differ. Serialization and the gateway are MVP 3.0's.

**Bindings.** A node holds its bindings' values by their identity, name and hash. A spawned function that names a binding finds the value where the peer's own build ran that identity, and fails with `NotLoaded` where it did not; nothing is initialized because a peer asked, as in MVP 3.0, and a value a spawned function is to have on the peer is captured. A service is one per node and key, the latest offer, as MVP 3.0 has it: a node of a build offers what that build started, and a bare node what its peers spawned on it. An old client that finds a service on a node restarted with a new build gets the new service where the type's identity is unchanged, and `OtherType` where it is not. Versions stand side by side as code, in processes spawned from peers of other builds, never as services.

**A node's code.** A node holds definitions by hash, in a table from each hash to the host's module and function that hold it; that table is the code table, and the compiled code lives once, as loaded modules of the host. Definitions that arrive in one exchange are compiled together into one unit of the host's, under a name of the node's own, its functions named by their position in the unit so that the names are reused and the atom table grows by the unit's name alone, and references between definitions are compiled through the table; the node's own build is compiled as `ern build` compiles it, one unit per source module, with the same table over it. What one load brings to a node that holds a unit of the module's name already is compiled the same way, into one unit under a name of the node's own, from the forms its `.erc` or its source holds: a unit of the host's never takes a second version, so the host's limit of two versions never ends a process, and a load counts against the limits of section 7. Nothing names a unit of the host's. The canonical form of the node's own definitions is in its `.erc` files, read and verified against its hash when the node ships one; a build directory is never changed under a running node, and a new build goes in a directory of its own. The canonical form of a received definition, and of one typed at the shell, is kept beside its compiled code, and the node ships it onward as its own. Loading is by the host's `prepare_loading` and `atomic_load`, one batch per closure, skipping what is loaded already, with no `-on_load`; the node's units are off the code path, where nothing loads them but the node, and the node loads otherwise as `ern run` does today. What a node has received or compiled it keeps on its disk by hash, each definition's canonical form with the unit it was compiled into: that store is the cache, and a node restarts into a build from it (`mvp3.2.md`). At a restart the node verifies every form against its hash before it loads, and refuses to start naming the first that fails; the units are trusted as a build directory's `.erc` files are, since the node alone wrote them, and a unit the node compiled from forms is checked against no interface, since it was compiled against what the node holds.

**A spawn across builds.** The spawn frame carries the function's hash, its captured values and the site. A peer that has the hash starts the process at once. A peer that lacks it asks for the closure's list; the sender sends the hashes the function references transitively, code and types, with the foreign declarations it names; the peer answers with the hashes it lacks, and with `NotLoaded` where it lacks the module a foreign declaration names; the sender ships the missing code, dependencies first. The request for the list, the list, the lacks and a code frame are four frames of Ernest's beside MVP 3.0's. A code frame carries one definition's canonical form, the form that is hashed, with its immediate references, and never a compiled binary. The peer verifies each frame against its hash as it arrives and holds it apart until the closure is complete; then it compiles the closure with its own back end, loads it all at once by the host's atomic load, and starts the process. What the peer said it has is pinned until the load is done. A frame whose content does not match its hash is a faulty frame, and the connection ends. A closure the peer cannot compile or load, a limit of the host's reached among the reasons, fails the spawn with `Refused`, whose text is the peer's. The exchange runs in a process of its own on each node, and the gateways only pass its frames. The spawn's time covers the exchange; what arrived complete stays, in the code table and the cache, and two spawns waiting on one hash share one exchange. The same four frames carry a build to a node told its root: the node asks the coordinator for the root's list, and the coordinator ships the forms of the build directory it was given, from its `.erc` files, as a node ships its own; the node compiles what arrives, writes it to its cache, and loads nothing.

**`Code`.** `Code.load` is `ern run`'s loading reached from Ernest: the compiled module, refused where it was compiled against another interface, and its closure, loaded at once and its bindings evaluated. The host's own load is not offered. A load changes nothing under a running process; the shell's `:reload` loads the new hashes and moves the session's names to them. Nothing is unloaded by `Code`: code goes when the node restarts.

**The shell.** `ern shell --config-dir dir` is a node, as in MVP 3.0, and its `:load` and `:reload` work: each adds hashes and moves the session's names. A type in the session is its hash, so a binding made before a load keeps the type it was checked under, and a message of a type's new version sent to an address of the previous one, or the reverse, is a type error, whose diagnostic says which of the two is of the previous version. A local address is a pid alone on the host, and constructors of one name in two versions are one term, so the checker is the one thing that tells the versions apart on one node, as the find is across nodes. A process of a previous version runs on until it ends or is killed, reachable through the addresses of its version alone, its offer replaced by a later one's as any offer is; nothing a reload loads is a second version of a unit (*A node's code*), and §11.2's fault for a further reload, `its code was unloaded`, goes. A function typed at the shell has a hash as any definition has, and spawns on a peer with its code.

**A rolling deploy.** A node restarted with a new build connects to the old ones as any node does, its `ernest.conf` unchanged. In this milestone the operator copies the build to one machine, stops that node and starts it again, one machine at a time, in the order the program allows; MVP 3.2's `ern deploy` carries the build and the order (`mvp3.2.md`). A service's protocol that is unchanged shows nothing to a client of either build. `ern diff` says beforehand which will not.

## 7. The numbers

| What | Value |
|---|---|
| a definition's hash | SHA-256 over its canonical form, the scheme's version mixed in |
| the cookie | section 6, *The cookie*: the protocol's, the hash scheme's, OTP's and the runtime surface's versions |
| atoms a node can make in its life | 1,048,576, the host's, never reclaimed: every unit's name and every function's |
| a code frame | one definition's canonical form, with its immediate references |
| module names a node can load in its life | 65,536, the host's, never reclaimed (OTP 29) |
| lambdas a node can load in its life | 524,288, the host's, never reclaimed (OTP 28 and later) |
| a node says it nears a limit at | four fifths of any of the three |

## 8. How it is checked

The canonical form has a test suite of its own, written with the form before any hash is computed: the same definition hashes the same across a rebuild; a renamed function or type keeps its dependents' hashes, and a renamed constructor changes them; a moved definition in a group changes the group's hash; two bodies that differ only in local names or layout hash the same; a literal's encoding is fixed. Two hashes for one definition, and one hash for two, are its cases.

The runtime's tests build one program twice with one definition changed, start a node of each on one machine as the experiment starts nodes, and hold the claims of section 4: the cookie lets them connect; a find across them answers the address where the key's identity is unchanged and `OtherType` where it changed; a spawn of changed code onto the old node ships exactly the lacking definitions, verified and loaded at once, and the process runs; `NotLoaded` for a binding the old node did not run and for a foreign declaration it lacks; a faulty frame ends the connection; a bare node takes a spawn and offers a service; a late or broken exchange leaves nothing half-loaded. `ern diff` on the two builds names the changed definition and the changed key. A node told to load many units says so at four fifths of a limit, once, measured. In the shell, a binding made before a `:reload` that changed its type refuses a message of the new version and takes one of its own, and the previous version's service runs on through two further reloads of its module.

A program's own tests of two builds need nothing new: `ern test --config-dir dir` with the other build started by `Os`, as MVP 3.0 has it.

## 9. Unsolved

Every question the proposal was written through is decided. What remains is the build's: the canonical form's document, with the hash scheme's version, written before any hash is computed; the measurements of section 7 and of what a spawn that ships code costs; the soundness argument's section 7 extended to identity by hash, on one node across a load as across nodes; and the report's sentences, §8.7 whole, §11.1 for what an `.erc` holds, §11.2 for a bare node, for the shell and for its reload, which is a load of what changed with nothing purged, and Appendix E's section for `Code`. The rewrite names the sections whose rules it changes: §8.1, §8.5, §8.6 and §11.8, for a bare node's entry process that runs no `main` and ends by termination; §6.10, whose cross-node sentence is rewritten over a spawn that carries its code; §7.4, §8.4 and §11.2, from which `Fault("its code was unloaded")` goes, since nothing is unloaded; and §8.5, for `Code.load`'s fresh process.

## 10. Left out on purpose

- An upgrade in place of a running process, a change of protocol by a translation, and a rollback: step D, the milestone after this one, where [`code.md`](code.md)'s section 7 waits.
- The deploy tool that plans from the hashes, and the keeper, a service that holds its state behind a protocol that seldom changes: step D's. `ern diff` is a list, not a plan.
- Unloading code: a node's code is bounded by section 7's limits, and a node warned restarts.
- A node that boots the platform over the network, and the key such a node receives.
- A drain and restart of a node whose atoms near the host's limit, and the hybrid, which interprets code until it is hot and compiles it then: step D's.
- A compiled binary in a code frame, trusted as its sender is.
- A project's name above a qualified name.

## 11. Room for what comes after

Step D, MVP 3.2, is a rolling restart the runtime orders and checks, and narrows the cookie to the runtime's surface. What MVP 3.1 leaves room for:

1. **A process's code is a hash it can be asked for.** `Process.info` gains the hash of the function a process was started with, so that a node can list the processes still on old code. It is added without breaking a program, and MVP 3.1 does not add it.
2. **A process may come to accept more than one identity.** The gateway and a key compare identities, and never ask how many a process serves; a process that has changed its protocol serves two, through a translation, and a find then matches either.
3. **The memory of code is bounded, not reclaimed.** A node that never restarts takes every version, the host's tables never shrink, and section 7's limits and warning are the answer; no name of a unit of the host's is a hash, so a pool of reused names stays possible.
4. **The cookie narrows.** Section 6, *The cookie*: the runtime's surface in place of `ern`'s version, so that a release of `ern` is deployed node by node (`mvp3.2.md`). Nothing a program writes names a version.
5. **The canonical form is frozen** when it is written down, and changed seldom, each change a new scheme version and a stop of every node; whatever runs before hashing is part of it.

The report's rewrite for MVP 3.0 leaves room for `ern run --config-dir dir` with no file, a bare node, which is this milestone's and not MVP 3.0's, and adds nothing for it.

Three places carry the most risk. The canonical form, where two hashes for one definition or one hash for two cost most, and where everything that runs before hashing, elaboration and how supplies are filled, must be fixed with it. The host's limits, which bound a node's life by what it loads, and which a later OTP relieves. And the discipline of a service's protocol being small, stable and its own, which the hashes reward and which only programs written on them will show.
