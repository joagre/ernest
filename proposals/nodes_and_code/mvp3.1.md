# Ernest: MVP 3.1, Code by Its Hash

Status: a proposal being written, one question at a time, from [`code.md`](code.md), before MVP 3.0 is built. Its section 1 is decided; the rest is written as its questions are decided, and section 9 holds them. The reasons for what it says go to [`code.md`](code.md) as they are settled.

## 1. What it is

MVP 3.1 names every definition by a hash of its content, and lets nodes of different builds work together. A process on one node spawns a process on a peer with code the peer does not have, and the code crosses with the spawn. Versions of a definition stand side by side on a node, and a process keeps the code it was started with until it ends.

It is step C of [`mvp3.0.md`](mvp3.0.md)'s section 11, and nothing of step D. Three things bound it:

- **A hash for each definition.** The compiler computes it from a canonical form of the definition, and it is the identity of code and of types everywhere: in a spawn, in a key, on a message.
- **Code crosses with a spawn, and only then.** The peer asks for the hashes it lacks, the sender ships them, and the whole closure is present before the process starts. A message ships no code; a find ships no code.
- **No change in place.** A process never takes new code. A deploy is a rolling restart, node by node: new nodes start beside old ones, old processes run old code until they end, and a service is found by its key at whichever version it is.

The bounds of MVP 3.0 stay: a few nodes with one owner, listed by hand, trusted completely; no discovery; nothing the runtime retries. Its four rules rule here too, and the fourth, *what crosses is identified, never named*, is this milestone whole: the two names that crossed in MVP 3.0, a function's module and place, and the type's text in a key, become hashes, and a key's name alone stays a name.

**The building block.** A *definition* is a function, a type, or a top-level binding, and its *hash* is the identity it has on every node: two definitions with one hash are one definition, and two with different hashes are two, whatever they are called. A node holds code by hash, loads by hash, and ships by hash. A name is a build's own word for a hash, and a build moves a name from one hash to another without touching either.

## 2. What a program sees

**What is new.** Nothing in `Peer`: its functions and `Peer.Failure` are MVP 3.0's, with `NotLoaded` meaning what the function needs and the peer does not have, a binding's value or a foreign declaration's module, and `OtherType` a service at another version. One module of the standard library, `Code`, for the toolchain's own Ernest code and for tools: `Code.load(path)` loads a compiled module and its closure from a build, at once, its bindings evaluated, and answers `Either(error, Unit)`; `Code.hashes(path)` answers a compiled module's definitions as name and hash. A program has nothing to load by name, since it names every function it calls, so `Code` is what the shell's `:load` and `:reload` and `ern diff` stand on, and nothing a program needs. One command: `ern diff old-build new-build` lists the definitions whose hash differs between two builds, and among them the keys whose type identity differs, which are the services that answer `OtherType` across a rollout.

**A bare node.** `ern run --config-dir dir` with no `.erc` starts a node that holds no definition of a program's: it runs the runtime and the system processes, evaluates the standard library's bindings, listens, and waits. Everything it runs arrives by a spawn from a peer, with the code; a spawned function there names no binding but the standard library's and captures the rest, and a spawned process may offer itself under a key. Nothing is copied to such a machine but `ern`, and it is upgraded by restarting it.

The rest is written as the questions are decided.

## 3. Examples

Written as the questions are decided.

## 4. What holds

1. **A node holds a hash only with its whole closure.** Nothing enters a node's store before everything it references is there and verified.

The rest is written as the questions are decided.

## 5. What does not hold

1. **A renamed type is a new type.** A type's hash holds its qualified name, so renaming a type or a constructor, or moving a type to another module, changes its hash and every dependent's, and a service whose protocol holds it is at another version to every client of the old build. A renamed function changes nothing but its own build's name for its hash.
2. **A changed protocol parts old clients from new services for the length of a rollout.** An old client's find on a node of the new build answers `OtherType`, and a new client's on an old node the same, until both are of one build; a client written for peers waits and finds again, as it does for `Unreachable`. A change to a type that many protocols carry parts clients from every service that carries it at once.
3. **Code loaded on a node stays until the node restarts.** Nothing is unloaded. The host gives no module name back on unloading, a purge stalls every process, and a closure held in a value would break; and a node's life is one rolling deploy, so what it accumulates is what its peers' deploys sent it meanwhile. A node that outlives many deploys of its peers, a bare node among them, grows by what it receives, and says so on its standard error when it nears a limit of the host's (section 7), which is the cue to restart it.
4. **An upgrade of `ern`, of OTP or of the hash scheme stops every node.** Nodes of different versions of any of the three never connect: the runtime's surface is what shipped code calls by name, and nothing hashes it. A program's own code is what a rolling restart changes.

The rest is written as the questions are decided.

## 6. How it works

**The hash.** A definition's hash is the SHA-256 of its canonical form: the typed tree after checking, with local variables numbered by position, layout and comments gone, every name resolved, and types written out. A reference to another definition is the hash of what it names, and nothing else; a reference to a foreign declaration, which has no hash, is its qualified name and its type, and each node resolves it for itself. A function's own name and its source positions are not in its hash: two functions with one body are one definition. A type's hash covers its qualified name, its parameters by position, and its constructors in declared order with their fields' names and the hashes of their types; a type's *identity*, which a key carries and a find compares, is that hash with the hashes of the members the type declares, `compare` among them, so that no hash contains a hash that names it. A mutually recursive group is the strongly connected component of the dependency graph, hashed as one in source order, and each member's identity is the group's hash and its position in it. No project name stands above a qualified name. The scheme's version is mixed into every hash, so that hashes of two schemes are never equal; the canonical form is written down with it before any hash is computed, literals and order fixed, and everything that runs before hashing is part of it.

**The cookie.** The host's cookie is the digest of the protocol's version, the hash scheme's version, `ern`'s version and OTP's version. A program's code is not in it: the build's checksum of MVP 3.0 leaves, and nodes of different builds connect. What the hashes leave out agrees by the cookie: the runtime and the compiler's back end, which are `ern`'s; the standard library, which is hashed as a program's code is but ships with `ern`; the host's functions that code calls by name, which are OTP's; and a foreign declaration, which a peer resolves by name and type and has, its `ern` and OTP being the same. So a function of the standard library written in Ernest is hashed code, which crosses with a spawn and may differ between builds, while one that is a shim is the platform's, fixed by `ern`'s version and changed only by an upgrade of `ern`; the pure half of the library moves with a program, and the shim half with the runtime.

**Messages and keys.** A message carries nothing of its type, as in MVP 3.0, and goes straight into the mailbox: every remote address a program holds came from a find, where the peer compared the key's type identity, from a spawn of the program's own function, or inside a message whose type was agreed by one of the two, and there is no fourth way. A key carries its type's identity, hash and members, in place of MVP 3.0's text; a find answers the address where the identities are the same, and `OtherType` where they differ, which is a service at another version.

**Bindings.** A node holds its bindings' values by the hash of their definition. A spawned function that names a binding finds the value where the peer's own build ran that hash, and fails with `NotLoaded` where it did not; nothing is initialized because a peer asked, as in MVP 3.0, and a value a spawned function is to have on the peer is captured. A service is one per node: a node runs one build and offers what that build started, and an old client that finds a service on a node restarted with a new build gets the new service where the type's identity is unchanged, and `OtherType` where it is not. Versions stand side by side as code, in processes spawned from peers of other builds, never as services.

**A spawn across builds.** The spawn frame carries the function's hash, its captured values and the site. A peer that has the hash starts the process at once. A peer that lacks it asks for the closure's list; the sender sends the hashes the function references transitively, code and types, with the foreign declarations it names; the peer answers with the hashes it lacks, and with `NotLoaded` where it lacks the module a foreign declaration names; the sender ships the missing code, dependencies first. A code frame carries one definition's canonical form, the form that is hashed, with its immediate references, and never a compiled binary. The peer verifies each frame against its hash as it arrives and holds it apart until the closure is complete; then it compiles the closure with its own back end, loads it all at once by the host's atomic load, and starts the process. What the peer said it has is pinned until the load is done. A frame whose content does not match its hash is a faulty frame, and the connection ends. The spawn's time covers the exchange; what arrived complete stays, cached by hash, and two spawns waiting on one hash share one exchange.

**`Code`.** `Code.load` is `ern run`'s loading reached from Ernest: the compiled module, refused where it was compiled against another interface, and its closure, loaded at once and its bindings evaluated. The host's own load, which checks nothing and runs no initializer, is not offered. A load changes nothing under a running process; the shell's `:reload` loads the new hashes and moves the session's names to them. Nothing is unloaded by `Code`: code goes when nothing refers to it.

**A rolling deploy.** A node restarted with a new build connects to the old ones as any node does, its `ernest.conf` unchanged. The operator copies the build to one machine, stops that node, which is no loss to its peers, and starts it again; one machine at a time, in the order the program allows. A service's protocol that is unchanged, which is the ordinary fix, shows nothing to a client of either build. `ern diff` says beforehand which will not.

**A node's code.** A node holds definitions by hash, in a table from each hash to the host's module and function that hold it; that table is the cache, and the compiled code lives once, as loaded modules of the host. Definitions that arrive in one exchange are compiled together into one unit of the host's, under a name of the node's own, and references between definitions are compiled through the table; the node's own build is compiled as `ern build` compiles it, one unit per source module, with the same table over it. Nothing names a unit of the host's. The canonical form of the node's own definitions is in its `.erc` files, read when the node ships one; the canonical form of a received definition is kept beside its compiled code, text-sized, so that the node can ship it onward. Loading is by the host's `prepare_loading` and `atomic_load`, one batch per closure, skipping what is loaded already, with no `-on_load`; the node runs in embedded mode, and its units are off the code path.

The rest is written as the questions are decided.

## 7. The numbers

| What | Value |
|---|---|
| module names a node can load in its life | 65,536, the host's, never reclaimed (OTP 29) |
| lambdas a node can load in its life | 524,288, the host's, never reclaimed (OTP 28 and later) |
| a node says it nears a limit at | four fifths of either |

The rest is written as the questions are decided.

## 8. How it is checked

Written as the questions are decided.

## 9. Unsolved

The questions, in the order they are taken; each leaves the list as it is decided.

1. **How it is checked**, with nodes of two builds on one machine.

## 10. Left out on purpose

- An upgrade in place of a running process, a change of protocol by a translation, and a rollback: step D, the milestone after this one, where [`code.md`](code.md)'s section 3 waits.
- The deploy tool that plans from the hashes, and the keeper: step D's.
- A node that boots the platform over the network, and the key such a node receives.
- A drain and restart of a node whose atoms near the host's limit, and the hybrid that interprets cold code: both serve a node that takes new code without a stop, which this milestone has not.

## 11. Room for what comes after

Written when the questions are decided, for step D. The memory of code is step D's problem: a node that takes new code without a stop never restarts, and the host's tables never shrink; MVP 3.1a measures it and weighs what can be done (the plan). One thing is known already: a milestone after this one narrows `ern`'s version in the cookie to the runtime's surface, the part shipped code calls by name, and lets the rest of `ern` differ between nodes; that breaks no program, since nothing a program writes names a version.
