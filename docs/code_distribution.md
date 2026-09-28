# Ernest: Code Distribution

Status: tentative design, 23 September 2026, brought to the report 28 September 2026. Target: MVP 3.1; MVP 3.0 spawns only between nodes of one build (the plan). Companion to [`node_protocol.md`](node_protocol.md), which designs the connection that carries the code.

> **Tentative.** A first pass, to be thought through again before it is built. The report owns what a program sees (§3.11, §6.10, §8.7); a line marked *Changed* brings this note to it. The plan's MVP 3.1 lists what is still to decide. The rationale is the log's, in its entries from *Distribution* to *Code Travels Only With a Spawn*, and the alternatives rejected are its *What the Design Notes Argued*.

## 1. Scope

Code is identified by the hash of its content, as in Unison, so nodes need not share a version of user code, and a node may start with none and receive what it needs from its peers.

The *IR* below is the canonical form that is hashed and shipped. MVP 1 built none: `ern_emitter` goes from the typed AST to Erlang's abstract format in one traversal. Whether MVP 3.1 adds an IR or canonicalizes the typed AST is the plan's decision. *Changed:* the note said that MVP 1 had a named IR stage, with names resolved and locals numbered.

## 2. Code identity

### 2.1 What is hashed

A definition's hash is the SHA-256, by `crypto:hash/2`, of its IR after type checking, in canonical form:

1. the version of the IR format, first;
2. each external reference as its qualified name and the hash of what it names (§8.7);
3. local variables numbered by position;
4. the hashes of the types the definition uses;
5. named fields in canonical order (§3.5), and construction in source evaluation order (§8.7).

Comments, formatting and source positions are not hashed. *Changed:* the note replaced references by their hashes and hashed no name; §8.7 keeps the qualified names of external references.

Mutually recursive definitions are hashed as one group (§8.7) and compiled into one module.

### 2.2 Hash modules

Each hash is compiled to a BEAM module of its own, named `ern#` and the base32 encoding of the full hash, well within the 255 characters of an atom. A hash module never changes. *Changed:* the name was `e_…`, which the `ern` prefix of [`style.md`](style.md) refuses; that guide takes the name when it is built.

## 3. Types

A type's hash covers its qualified name, its parameters by position, its constructors by name in declared order, and the hashes of its fields' types. An abstract type's hash also covers the types of its module's exported declarations (§8.7, *Identity*). *Changed:* the note hashed an abstract type as any other.

Renaming a type or a constructor, or moving a type to another module, changes its hash, which an address of a mailbox of that type carries (node protocol, section 4.2): it is a change of protocol between processes. Two unrelated codebases with a type of the same qualified name and definition share its hash; a project name at the top of every qualified name would part them, if that ever matters.

## 4. Names

`.ern` files are the source of truth for names. Each build resolves every name afresh and writes a name table from name to hash, derived and never edited. No operation points a name at a hash, and no source names a hash.

The build keeps every hash it has built in a store that only grows. Only the build writes to it, and it holds hashes, not names; a read-only lookup, such as the name behind a hash, is allowed.

A definition changes by editing and rebuilding. Its dependents get new hashes, and where a type changed they fail to compile until they are edited, so a build is never half migrated. A new build upgrades no running process (section 8).

At run time names serve entry points and debugging only. Each node keeps a reverse table from hash to name for stack traces and error messages. Names are local to a build: nodes share hashes, not names.

Nodes built from different commits cooperate through the hashes they share, and old and new versions run side by side on one node (section 8). Within one build a name has one meaning, and an old version still needed keeps a name of its own in the source.

## 5. Nodes

There is one node type. Each node has a code cache keyed by hash: *persistent*, on disk and possibly filled at deployment, or *volatile*, in memory and empty at start. Both load code the same way, and a single node reads from a persistent cache.

User code may be absent; the platform may not. Every node carries BEAM and OTP (kernel, stdlib, crypto, ssl, compiler), the Ernest runtime and the loader, and the compiler's back end, from IR to Erlang forms to BEAM. A diskless node can boot these through `-loader inet` and `erl_boot_server`, which use no Erlang distribution and no TLS (open question 6).

## 6. The loader

The loader stands beside an unchanged `code_server`: it resolves hashes and hands binaries to BEAM, and `code_server` keeps its table of loaded modules, its purging and its serialized loads.

1. **Cache**: ETS from hash to IR and compiled binary, and on a persistent node one file per hash. A binary is cached under its hash, the back end's version and the OTP version.
2. **Verification**: the hash of incoming IR is computed before anything else, and a mismatch rejects it.
3. **Compilation**: IR to Erlang forms, then `compile:forms` with `deterministic`.
4. **Dependencies**: every unit lists the hashes it references, so a fetched closure is known to be complete before it is loaded.
5. **Loading**: a whole closure at once, by `code:prepare_loading/1` and `code:atomic_load/1`, all of it or none. `prepare_loading` does the heavy work in the calling process, so the one `code_server` process should not become a bottleneck. That is measured before it is relied on, and a bottleneck is answered with larger batches.

Nodes run in embedded mode, which loads nothing from the code path on demand: code cannot be missing (section 7.2), so a missing module is an honest failure (open question 9).

## 7. Shipping

### 7.1 What is shipped

Only a spawn on a peer ships code (§8.7): the function it starts and every function among its captures, each as `{hash, env}`. A raw BEAM fun is never serialized, since its module names and checksums mean nothing on another node. An adapted address carries a `{hash, env}` but no code, since the node that made it applies the function (node protocol, section 10). A message ships nothing (§3.11, §8.7), and one whose type hash does not match its receiver comes from a faulty peer (node protocol, section 4.2).

### 7.2 Have and want

Before a spawn frame's payload is decoded (node protocol, section 9.3):

1. the sender lists the hashes, of code and types, that the function references transitively, its captures included;
2. the receiver answers with those it lacks;
3. the sender sends their IR;
4. the receiver verifies, compiles and loads them;
5. the payload is decoded, since a value cannot be read before its types are loaded, and the process starts.

The whole closure is present before anything runs, and a hash is never removed while loaded code depends on it (section 10.1), so code cannot be missing at run time. A failed exchange is a resolution failure, which faults the caller of `spawn` (§8.7).

## 8. Code change in running processes

A process changes code by receiving a new function in its own type and tail-calling it (§6.10). Hash modules never change, so any number of versions live side by side, and BEAM's two versions of a module do not limit them. BEAM's module replacement is never used.

On another node the function cannot travel in the message (§3.11). A process spawned there brings it and sends the upgrade: `spawn(Peer(name), fn() = send(counter, Upgrade(migrate = m, next = k)))`. *Changed:* the note wrote `Upgrade(m, k)`, which §3.5's named fields refuse.

The process must cooperate, since its state lives in its loop's arguments, where only it can carry the state over. A process whose type has no upgrade case is replaced instead. An address carries its mailbox type's hash (section 3), so an upgrade in place keeps the message type; in §6.10's form the upgrade case names the state type, which then cannot change either. Changing the protocol or the state's shape means replacing the process: a new one on the new code, the state handed over by message, and clients of the new version reaching it through that version's service binding, which is another binding (§8.7, *Bindings*).

## 9. Trust

The trust boundary is mutual TLS authentication and nothing else: loading code from the network is remote execution by design. The receiver does not type check incoming IR again. Ill-typed IR cannot corrupt BEAM, which is memory safe, but can fault at run time. The hash guarantees integrity: what is loaded is what was named.

There is no authorization beyond authentication: any authenticated peer may load and run any code on any node it talks to. That is a known limitation while one owner runs every node, and per-peer permissions wait for nodes with different owners.

## 10. Resources

### 10.1 Unloading

On a node, a hash may be unloaded and removed from the cache when no name table on the node refers to it, no loaded hash depends on it, and `code:delete/1` followed by `code:soft_purge/1` succeeds, BEAM checking that no process runs its code or holds a fun of it. Both are tried after a configured idle time. That check sees the closures in process state, so nothing counts references per process.

### 10.2 Atoms

Every module name is an atom, and atoms are never collected (the default limit is about a million), so a long-lived node that receives many versions leaks them. The node counts its atoms, and above a configured threshold it drains and restarts. The cache refills on demand, but every process on the node dies, every address to it is dead, and watchers on peers see the node lost (§10). How often a threshold restart happens decides whether the hybrid is needed.

### 10.3 The hybrid in reserve

If threshold restarts come too often, incoming units are first interpreted by an IR interpreter in Erlang, and compiled to hash modules only when hot, so cold code costs no atoms. The IR allows it unchanged, since the hash names IR, not binaries. It is not part of MVP 3.1.

## 11. What stays versioned by platform

Three things are not hashed and must agree across nodes:

1. The hash scheme, its function, canonical form and IR version, checked in the handshake (node protocol, section 9.2).
2. The compiler's back end, on every node and outside the hash; its version keys the cached binaries (section 6).
3. What hashed code calls by name, the `erlang:` BIFs and the Ernest runtime, where a difference between nodes leaks through unseen.

The prelude's declared types (§9.3) and the standard library are hashed like user code, their foreign declarations excepted, which are per node (§8.7). What stays bound by name is then the BIFs, the runtime and the OTP version, pinned per deployment.

## 12. Deferred

- Sending binaries between nodes with the same back end and OTP version, if compile time proves a problem. The IR stays the unit of transfer, since a binary cannot be checked against an IR hash without a compiler.

## 13. Open questions

1. At what count of atoms does a node drain and restart? Proposed: 80 % of the limit.
2. How often may threshold restarts come before the hybrid is built?
3. When is the IR format frozen? Every change to it changes every hash, and once distribution is in use it is a cutover of every node (node protocol, section 9.2).
4. How long is a hash idle before it is unloaded and removed from the cache?
5. What are the full normalization rules, written apart before MVP 3.1: how references inside a group are numbered, how literals, closures and constructors are made canonical, and how type expressions such as `Msg(Int)`, function types and `with m` are hashed, since an address carries the hash of an instantiated mailbox type?
6. How does a diskless node boot the platform, loader included, when `erl_boot_server` has no TLS and checks only the IP address: from a signed boot image or local flash, or with the gap accepted on a trusted network? The answer also decides how the node receives its key (node protocol, open question 13).
7. Does replacing a process with a handover of its state need support from the language, or does it stay a convention?
8. Is a function's own name in its hash? §8.7 names only its references'.
9. Does a node running hash modules keep embedded mode, or find a `foreign fn`'s Erlang module on the load path as §11.2 does?
10. What makes a peer's foreign declaration compatible with the one a shipped function names (§8.7): the same type and implementation, or the same type alone?

## 14. Risks

1. Normalization, where an error costs most: different hashes for identical code or, worse, one hash for different code. It gets a test suite of its own.
2. Compile latency when a node receives much code at once, typically at start-up.
