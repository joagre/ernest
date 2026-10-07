# Ernest: MVP 3.1, Code by Its Hash

Status: a proposal, written one question at a time from [`code.md`](code.md) on 2026-10-07, before MVP 3.0 is built, and made whole the same day; to be read back against section 1 of [`mvp3.0.md`](mvp3.0.md). The reasons for what it says are in [`code.md`](code.md), marked *Decided*, beside the thinking they came from; what other systems do is [`other_systems.md`](other_systems.md), section 6.

## 1. What it is

MVP 3.1 names every definition by a hash of its content, and lets nodes of different builds work together. A process on one node spawns a process on a peer with code the peer does not have, and the code crosses with the spawn. Versions of a definition stand side by side on a node, and a process keeps the code it was started with until it ends.

It is step C of [`mvp3.0.md`](mvp3.0.md)'s section 11, and nothing of step D. Three things bound it:

- **A hash for each definition.** The compiler computes it from a canonical form of the definition, and it is the identity of code and of types everywhere: in a spawn, in a key, on a message.
- **Code crosses with a spawn, and only then.** The peer asks for the hashes it lacks, the sender ships them, and the whole closure is present before the process starts. A message ships no code; a find ships no code.
- **No change in place.** A process never takes new code. A deploy is a rolling restart, node by node: new nodes start beside old ones, old processes run old code until they end, and a service is found by its key at whichever version it is.

The bounds of MVP 3.0 stay: a few nodes with one owner, listed by hand, trusted completely; no discovery; nothing the runtime retries. Its four rules rule here too, and the fourth, *what crosses is identified, never named*, is this milestone whole: the two names that crossed in MVP 3.0, a function's module and place, and the type's text in a key, become hashes, and a key's name alone stays a name.

**The building block.** A *definition* is a function, a type, or a top-level binding, and its *hash* is the identity it has on every node: two definitions with one hash are one definition, and two with different hashes are two, whatever they are called. A node holds code by hash, loads by hash, and ships by hash. A name is a build's own word for a hash, and a build moves a name from one hash to another without touching either.

## 2. What a program sees

**The operations** are MVP 3.0's, with one difference: a spawn on a peer carries its code where the peer lacks it. `Peer`'s functions and `Peer.Failure` are unchanged. `NotLoaded` means what the function needs and the peer does not have: a binding's value, or the module a foreign declaration names. `OtherType` means a service at another version.

**What is new.**

- **A bare node.** `ern run --config-dir dir` with no `.erc` starts a node that holds no definition of a program's: it runs the runtime and the system processes, evaluates the standard library's bindings, listens, and waits. Everything it runs arrives by a spawn from a peer, with the code. A spawned function there names no binding but the standard library's and captures the rest, and a spawned process may offer itself under a key. Nothing is copied to such a machine but `ern`, and it is upgraded by restarting it. A balancer places work on it as on any peer, and installs its measure there by `Balancer.measure(place, f)`.
- **`Code`**, a module of the standard library for the toolchain's own Ernest code and for tools. `Code.load(path)` loads a compiled module and its closure from a build, at once, its bindings evaluated, and answers `Either(error, Unit)`. `Code.hashes(path)` answers a compiled module's definitions as name and hash. A program has nothing to load by name, since it names every function it calls; `Code` is what the shell's `:load` and `:reload` and `ern diff` stand on.
- **`ern diff old-build new-build`** lists the definitions whose hash differs between two builds, and among them the keys whose type identity differs, which are the services that answer `OtherType` across a rollout.
- **The shell's `:load` and `:reload`** work in a shell that is a node, which MVP 3.0 refused: a load adds hashes and moves the session's names, and a function typed at the shell spawns on a peer with its code.

**What may cross** is MVP 3.0's rule unchanged: a bound type never crosses, the compiler refuses a key of a bound type and a spawn whose captures are bound, and an adapted address's captures are checked as it crosses. The function a spawn starts crosses with its code, where the peer lacks it.

## 3. Examples

The counter of [`mvp3.0.md`](mvp3.0.md)'s section 3 runs on the store, and the desk and the board find it by `Counter.key`. The program is at build 1 on every node.

**A fix behind the protocol.** Build 2 changes `count` to log each `Add`. `ern diff build1 build2` prints:

```
store.ern  fn count       changed
```

No key is listed: `Counter.Msg` is unchanged, so `Counter.key`'s identity is the same in both builds. The operator copies build 2 to the store's machine, stops the store and starts it. The board's monitor on the counter gives `ProgramEnd`; the board finds the counter again by its key and gets build 2's counter. The desk and the board are still at build 1, and nothing shows.

**A changed protocol.** Build 3 adds `Reset` to `Counter.Msg`. `ern diff build2 build3` prints:

```
counter.ern  type Msg        changed
counter.ern  let key         changed    key "counter": identity changed
store.ern    fn count        changed
desk.ern     fn main         changed
board.ern    fn main         changed
```

The store is restarted with build 3 first. Until the board is restarted too, its find answers `Left(OtherType)`, and the board prints "the store is not there" and finds again on its next tick; once the board is at build 3, it finds the counter. The desk at build 1 meets the same, and is restarted in its turn.

**A bare node.** A fourth machine, `worker`, is started with `ern run --config-dir /etc/ernest/worker` and no program, and listed by the store. The store spawns on it:

```ernest-fragment
match Peer.spawn("worker", fn() = count(0), 5000) {
    Left(_) -> Io.println("no worker")
  | Right(counter) -> Peer.offer(Counter.key, counter)
}
```

The first spawn ships `count` and `Counter.Msg`, verified and loaded on the worker before the process starts; the second ships nothing. `count` captures nothing and names no binding of the store's, so it runs there. The worker's output goes to the worker's standard output. When the store is restarted with a new build, its next spawn ships the new `count`, and the old one runs on until it ends.

## 4. What holds

1. **A hash names one definition everywhere.** Two nodes that hold one hash hold one definition, whatever each build calls it.
2. **A node holds a hash only with its whole closure.** Nothing enters a node's store before everything it references is there and verified.
3. **Code arrives verified or not at all.** Every definition that crosses is checked against its hash on arrival, and a frame that fails ends the connection.
4. **A process keeps its code.** Loading only adds; nothing a process runs is ever changed or taken from it.
5. **No message of one version is read as another's.** Every remote address came from a find, a spawn or an agreed message, so what is sent through it is of the type the receiver's code was compiled with.
6. **A rename changes nothing that is not renamed.** Renaming a function or a binding changes no hash but its own build's name for it. A type is the exception (section 5).
7. **Nodes of different builds connect, and of different `ern`, OTP or hash scheme never.**

## 5. What does not hold

1. **A renamed type is a new type.** A type's hash holds its qualified name, so renaming a type or a constructor, or moving a type to another module, changes its hash and every dependent's, and a service whose protocol holds it is at another version to every client of the old build.
2. **A changed protocol parts old clients from new services for the length of a rollout.** An old client's find on a node of the new build answers `OtherType`, and a new client's on an old node the same, until both are of one build; a client written for peers waits and finds again, as it does for `Unreachable`. A change to a type that many protocols carry parts clients from every service that carries it at once.
3. **Code loaded on a node stays until the node restarts.** Nothing is unloaded. The host gives no module name back on unloading, a purge stalls every process, and a closure held in a value would break; a node's life is one rolling deploy, so what it accumulates is what its peers' deploys sent it meanwhile. A node that outlives many deploys of its peers, a bare node among them, grows by what it receives, and says so on its standard error when it nears a limit of the host's (section 7), which is the cue to restart it.
4. **An upgrade of `ern`, of OTP or of the hash scheme stops every node.** Nodes of different versions of any of the three never connect: the runtime's surface is what shipped code calls by name, and nothing hashes it. A program's own code is what a rolling restart changes.
5. **A spawn that ships code is slow once.** The first spawn of a definition on a node that lacks it crosses the closure, compiles it there, and loads it, within the spawn's time or `Timeout`; what arrived complete stays, and the next spawn ships nothing.
6. **A spawned function finds no binding the peer did not run.** It names the standard library's bindings and captures the rest, or the peer answers `NotLoaded`. On a bare node that is every binding of the program's.
7. **A foreign declaration's implementation is outside the hashes.** A `foreign fn` names a host module, which is each node's own; two builds whose Erlang under one foreign name differs are not told apart, and a shipped definition that names it runs the peer's. The standard library's foreign declarations agree by `ern`'s version.

## 6. How it works

**The hash.** A definition's hash is the SHA-256 of its canonical form: the typed tree after checking, with local variables numbered by position, layout and comments gone, every name resolved, and types written out. A reference to another definition is the hash of what it names, and nothing else; a reference to a foreign declaration, which has no hash, is its qualified name and its type, and each node resolves it for itself. A function's own name and its source positions are not in its hash: two functions with one body are one definition. A type's hash covers its qualified name, its parameters by position, and its constructors in declared order with their fields' names and the hashes of their types; a type's *identity*, which a key carries and a find compares, is that hash with the hashes of the members the type declares, `compare` among them, so that no hash contains a hash that names it. A mutually recursive group is the strongly connected component of the dependency graph, hashed as one in source order, and each member's identity is the group's hash and its position in it. No project name stands above a qualified name. The scheme's version is mixed into every hash, so that hashes of two schemes are never equal; the canonical form is written down with it before any hash is computed, literals and order fixed, and everything that runs before hashing is part of it.

**The cookie.** The host's cookie is the digest of the protocol's version, the hash scheme's version, `ern`'s version and OTP's version. A program's code is not in it: the build's checksum of MVP 3.0 leaves, and nodes of different builds connect. What the hashes leave out agrees by the cookie: the runtime and the compiler's back end, which are `ern`'s; the standard library, which is hashed as a program's code is but ships with `ern`; the host's functions that code calls by name, which are OTP's; and a foreign declaration, which a peer resolves by name and type and has, its `ern` and OTP being the same. So a function of the standard library written in Ernest is hashed code, which crosses with a spawn and may differ between builds, while one that is a shim is the platform's, fixed by `ern`'s version and changed only by an upgrade of `ern`; the pure half of the library moves with a program, and the shim half with the runtime.

**Messages and keys.** A message carries nothing of its type, as in MVP 3.0, and goes straight into the mailbox: every remote address a program holds came from a find, where the peer compared the key's type identity, from a spawn of the program's own function, or inside a message whose type was agreed by one of the two, and there is no fourth way. A key carries its type's identity, hash and members, in place of MVP 3.0's text; a find answers the address where the identities are the same, and `OtherType` where they differ. Serialization and the gateway are MVP 3.0's.

**Bindings.** A node holds its bindings' values by the hash of their definition. A spawned function that names a binding finds the value where the peer's own build ran that hash, and fails with `NotLoaded` where it did not; nothing is initialized because a peer asked, as in MVP 3.0, and a value a spawned function is to have on the peer is captured. A service is one per node: a node runs one build and offers what that build started, and an old client that finds a service on a node restarted with a new build gets the new service where the type's identity is unchanged, and `OtherType` where it is not. Versions stand side by side as code, in processes spawned from peers of other builds, never as services.

**A spawn across builds.** The spawn frame carries the function's hash, its captured values and the site. A peer that has the hash starts the process at once. A peer that lacks it asks for the closure's list; the sender sends the hashes the function references transitively, code and types, with the foreign declarations it names; the peer answers with the hashes it lacks, and with `NotLoaded` where it lacks the module a foreign declaration names; the sender ships the missing code, dependencies first. A code frame carries one definition's canonical form, the form that is hashed, with its immediate references, and never a compiled binary. The peer verifies each frame against its hash as it arrives and holds it apart until the closure is complete; then it compiles the closure with its own back end, loads it all at once by the host's atomic load, and starts the process. What the peer said it has is pinned until the load is done. A frame whose content does not match its hash is a faulty frame, and the connection ends. The spawn's time covers the exchange; what arrived complete stays, cached by hash, and two spawns waiting on one hash share one exchange.

**`Code`.** `Code.load` is `ern run`'s loading reached from Ernest: the compiled module, refused where it was compiled against another interface, and its closure, loaded at once and its bindings evaluated. The host's own load, which checks nothing and runs no initializer, is not offered. A load changes nothing under a running process; the shell's `:reload` loads the new hashes and moves the session's names to them. Nothing is unloaded by `Code`: code goes when the node restarts.

**The shell.** `ern shell --config-dir dir` is a node, as in MVP 3.0, and its `:load` and `:reload` work: each adds hashes and moves the session's names. A function typed at the shell has a hash as any definition has, and spawns on a peer with its code.

**A rolling deploy.** A node restarted with a new build connects to the old ones as any node does, its `ernest.conf` unchanged. The operator copies the build to one machine, stops that node, which is no loss to its peers, and starts it again; one machine at a time, in the order the program allows. A service's protocol that is unchanged, which is the ordinary fix, shows nothing to a client of either build. `ern diff` says beforehand which will not.

**A node's code.** A node holds definitions by hash, in a table from each hash to the host's module and function that hold it; that table is the cache, and the compiled code lives once, as loaded modules of the host. Definitions that arrive in one exchange are compiled together into one unit of the host's, under a name of the node's own, and references between definitions are compiled through the table; the node's own build is compiled as `ern build` compiles it, one unit per source module, with the same table over it. Nothing names a unit of the host's. The canonical form of the node's own definitions is in its `.erc` files, read when the node ships one; the canonical form of a received definition is kept beside its compiled code, text-sized, so that the node can ship it onward. Loading is by the host's `prepare_loading` and `atomic_load`, one batch per closure, skipping what is loaded already, with no `-on_load`; the node runs in embedded mode, and its units are off the code path.

## 7. The numbers

| What | Value |
|---|---|
| a definition's hash | SHA-256 over its canonical form, the scheme's version mixed in |
| the cookie | the digest of the protocol's, the hash scheme's, `ern`'s and OTP's versions |
| a code frame | one definition's canonical form, with its immediate references |
| module names a node can load in its life | 65,536, the host's, never reclaimed (OTP 29) |
| lambdas a node can load in its life | 524,288, the host's, never reclaimed (OTP 28 and later) |
| a node says it nears a limit at | four fifths of either |

## 8. How it is checked

The canonical form has a test suite of its own, written with the form before any hash is computed: the same definition hashes the same across a rebuild; a renamed function keeps its dependents' hashes; a renamed type changes them; a moved definition in a group changes the group's hash; two bodies that differ only in local names or layout hash the same; a literal's encoding is fixed. Two hashes for one definition, and one hash for two, are its cases.

The runtime's tests build one program twice with one definition changed, start a node of each on one machine as the experiment starts nodes, and hold the claims of section 4: the cookie lets them connect; a find across them answers the address where the key's identity is unchanged and `OtherType` where it changed; a spawn of changed code onto the old node ships exactly the lacking definitions, verified and loaded at once, and the process runs; `NotLoaded` for a binding the old node did not run and for a foreign declaration it lacks; a faulty frame ends the connection; a bare node takes a spawn and offers a service; a late or broken exchange leaves nothing half-loaded. `ern diff` on the two builds names the changed definition and the changed key. A node told to load many units says so at four fifths of a limit, once, measured.

A program's own tests of two builds need nothing new: `ern test --config-dir dir` with the other build started by `Os`, as MVP 3.0 has it.

## 9. Unsolved

Every question the proposal was written through is decided. What remains is the build's: the canonical form's document, with the hash scheme's version, written before any hash is computed; and the measurements of section 7 and of what a spawn that ships code costs.

## 10. Left out on purpose

- An upgrade in place of a running process, a change of protocol by a translation, and a rollback: step D, the milestone after this one, where [`code.md`](code.md)'s section 3 waits.
- The deploy tool that plans from the hashes, and the keeper: step D's. `ern diff` is a list, not a plan.
- Unloading code, and a pool of host module names reused: MVP 3.1a measures what the host's tables cost, and step D needs the answer.
- A node that boots the platform over the network, and the key such a node receives; a bare node has `ern` on its disk.
- A drain and restart of a node whose atoms near the host's limit, and the hybrid that interprets cold code: both serve a node that takes new code without a stop, which this milestone has not.
- A compiled binary in a code frame, trusted as its sender is.
- A project's name above a qualified name.

## 11. Room for what comes after

Step D lets a running process take new code, and later a new protocol, and MVP 3.1a narrows the cookie to the runtime's surface. What MVP 3.1 leaves room for:

1. **A process's code is a hash it can be asked for.** `Process.info` gains the hash of the function a process was started with, which a deploy tool reads to list the processes still on old code. It is added without breaking a program, and MVP 3.1 does not add it.
2. **A process may come to accept more than one identity.** The gateway and a key compare identities, and never ask how many a process serves; a process that has changed its protocol serves two, through a translation, and a find then matches either.
3. **The memory of code is step D's problem**, measured in MVP 3.1a: a node that never restarts takes every version, and the host's tables never shrink. No name of a unit of the host's is a hash, so a pool of reused names stays possible.
4. **The cookie narrows.** MVP 3.1a puts the runtime's surface in it in place of `ern`'s version, and a release of `ern` rolls out node by node. Nothing a program writes names a version.
5. **The canonical form is frozen** when it is written down, and changed seldom, each change a new scheme version and a stop of every node; whatever runs before hashing is part of it.

Three places carry the most risk. The canonical form, where two hashes for one definition or one hash for two cost most, and where everything that runs before hashing, elaboration and how supplies are filled, must be fixed with it. The host's limits, which bound a node's life by what it loads, and which a later OTP relieves. And the discipline of a service's protocol being small, stable and its own, which the hashes reward and which only programs written on them will show.
