# Ernest: Code Distribution

Status: tentative design decisions, 23 September 2026. Target: MVP 3. Consequences for MVP 1 in section 11. Companion to `node_protocol.md`, which covers nodes, addresses, connections and delivery.

> **Tentative.** Everything in this document is a first pass and must be thought through again before it is built. "Decision" here means the current best answer, not a commitment. The one exception is section 11, which shapes MVP 1 and should be settled before the compiler's IR stage is written.

## 1. Purpose

Ernest runs on BEAM but does not use Erlang distribution. Nodes talk over their own sockets with TLS. Code is identified by content hash, as in Unison, so that nodes never need to share the same version of user code. A node may start with no user code at all and receive what it needs from its peers.

## 2. Decisions in brief

- Code is identified by the SHA-256 hash of its canonical IR.
- Each hash is compiled to its own BEAM module, named after the hash. Dependency closures are loaded atomically with `code:atomic_load/1`, beside an unchanged `code_server`. Nodes run in embedded mode.
- IR travels between nodes, never binaries. The receiver verifies the hash and compiles locally.
- There is one node type. Nodes differ only in the policy of their code cache.
- Names are not part of the hash. `.ern` files are the source of truth for names; each build produces a name table.
- Missing code and types are fetched eagerly, before a message or spawn is decoded. Code cannot be missing at run time.
- Running processes change code by receiving a new function as a message in their own type. BEAM module replacement is never used.
- The prelude is compiled into hash modules like user code.
- A hash is removed from a node only when nothing on the node can reach it; the build's hash store only grows.
- Any authenticated peer may load code. Finer authorization is a known limitation.
- Interpretation (hybrid: interpret first, compile hot code) is held in reserve and not part of MVP 3.

## 3. Code identity

### 3.1 What is hashed

The hash covers the IR after type checking, in canonical form:

1. A version number of the IR format, first in the hashed data.
2. All references to other definitions replaced by their hashes.
3. Local variables numbered by position, so that renaming a local does not change the hash.
4. The hashes of all types the definition uses. A change to a type therefore changes the hash of every definition that uses it.

Names, comments, formatting and source positions are not hashed.

### 3.2 Unit of hashing

One hash per strongly connected component of the definition graph. Mutually recursive definitions are hashed and compiled together, since they must live in the same module in any case.

### 3.3 Hash function and module names

SHA-256 via `crypto:hash/2`. The module name is `e_` followed by the base32 encoding of the full hash. This fits well within the 255-character atom limit.

### 3.4 Types

Types are nominal, as in the type checker: two declared types with the same shape are different types. Unlike functions, a type's name is part of its hash. The hash of a type covers:

1. its fully qualified name,
2. its type parameters, numbered by position,
3. its constructors, by name and in declared order,
4. the types of its fields, as type hashes.

This applies to all declared types, opaque or not. The hash thus means what the type checker means: `UserId` and `SessionId`, or `Red | Green` and `On | Off`, are different on the wire as they are in the compiler. Constructor order must be in the hash, since constructors travel as (type hash, index) (node protocol, section 10).

Renaming a type or a constructor, or moving a type to another module, changes its hash and the hash of everything that uses it. That is a real change to the protocol between processes, not a cosmetic one.

A mailbox type whose message type has changed is a new hash. Together with the type hash carried by every address on the wire (node protocol, section 4.2), two nodes can therefore not exchange messages under different ideas of the same type.

## 4. Names

### 4.1 Source of truth

`.ern` files are what is edited and versioned in git. Every build resolves all names afresh and produces a name table from name to hash.

The name table is derived from the source and never edited. There is no operation that points a name at a hash. A name means whatever its definition in the source means in the current build, so what the developer reads is what runs.

### 4.2 Hash store

Every hash ever built is kept in a store that only grows. Old versions remain available to running processes and to nodes that ask for them. Only the build writes to the store. It holds hashes, not names, and there are no tools that manage it beyond that. Read-only inspection, such as looking up the name behind a hash (section 4.4), is allowed.

### 4.3 Changing a definition

Changing a definition means editing the source and rebuilding. The name then refers to the new version automatically, and because the build resolves every name again, dependent definitions get new hashes automatically too. If a type changed, the dependents fail to compile in the ordinary way and must be edited.

A new build is not an upgrade of running processes. Those continue on the hashes they hold until they are sent new functions (section 8).

### 4.4 Names at run time

Names are needed at run time only for entry points (`main`, spawning from a REPL or command line) and for debugging. Each node keeps a reverse table from hash to name, so that stack traces and error messages are readable.

Names are local to a build. Two nodes need not share names, only hashes.

### 4.5 Versions

Versions coexist fully at run time and across builds. Hash modules never change, so processes on old and new versions of a definition run side by side on one node for as long as needed. Names are local to a build, so nodes built from different commits cooperate through shared hashes. The hash store keeps every version ever built.

Within one build, a name has exactly one meaning. Two consequences follow:

1. New code cannot refer to an old version under the same name. Where needed, the old version keeps a separate name in the source. There are no pinned references to hashes in source (section 13).
2. A change to a type must be carried through every dependent before the build compiles. There is no half-migrated state in which old dependents keep using the old type while new code uses the new one. This is the one real difference from a codebase kept as a database, as in Unison, and it matters more for a large shared codebase than for one with a single owner.

## 5. Nodes

### 5.1 One node type

Every node has a local code cache keyed by hash. The cache policy is configuration:

- persistent: the cache lives on disk and may be pre-filled at deployment,
- volatile: the cache lives in memory and starts empty.

Both load code the same way. A single node uses the same path, reading from a persistent cache.

### 5.2 What every node must carry

User code may be absent. The platform may not. Every node carries:

- BEAM and OTP (kernel, stdlib, crypto, ssl, compiler),
- the Ernest runtime and the loader,
- the compiler back end (IR to Erlang forms to BEAM).

A node without a disk can boot these through `-loader inet` and `erl_boot_server`. That path does not use Erlang distribution, but it has no TLS; see open question 6.

## 6. The loader

The loader does not replace or extend `code_server`. It is a thin layer beside it that resolves hashes and hands binaries to BEAM. `code_server` keeps doing what it does: the table of loaded modules, coordination of purging, and serialization of loads. Replacing it would be deep surgery in the kernel for no gain, since the rest of OTP assumes it.

Components:

1. **Cache**: ETS from hash to IR and compiled binary. For persistent nodes, one file per hash. Compiled binaries are cached under the key (hash, back-end version, OTP version).
2. **Verification**: the hash of incoming IR is computed before anything else happens. Mismatch means rejection.
3. **Compilation**: IR to Erlang forms, then `compile:forms` with `deterministic`.
4. **Dependency order**: every unit carries the list of hashes it references, so that a fetched closure is known to be complete before it is loaded.
5. **Loading**: a whole closure is loaded at once with `code:prepare_loading/1` and `code:atomic_load/1`, under the hash module names. Either every module in the closure is loaded or none is, so a half-loaded closure cannot occur. `prepare_loading` does the heavy work in the calling process, which keeps the single `code_server` process from becoming a bottleneck.

Nodes run in embedded mode, which turns off automatic loading from the code path. Since code cannot be missing (section 7.2), automatic loading would serve no purpose and would only hide errors. In embedded mode a missing module is an honest failure.

## 7. Transfer

### 7.1 Wire representation

Functions and closures travel as `{hash, env}`. Raw BEAM funs are never serialized, since they carry module names and module checksums that mean nothing on another node.

### 7.2 Have/want

Every message and every spawn is preceded on the connection by a have frame (node protocol, section 9.4):

1. The sender lists the hashes the payload references, transitively: code and types.
2. The receiver answers with those it lacks.
3. The sender sends the IR for those.
4. The receiver verifies, compiles and loads them.
5. Only then is the payload decoded and delivered.

Decoding must wait, since constructors are encoded by type hash (node protocol, section 10) and cannot be read without their type.

Because the whole transitive closure is present before anything runs, and a hash is never removed while loaded code depends on it (section 10.1), code cannot be missing at run time.

If the exchange fails, the payload is dropped. Delivery semantics are specified in the node protocol, section 5.4.

## 8. Code change in running processes

A process changes code by receiving a new function as a message in its own type and tail-calling into it. Hash modules never change, so any number of versions can live side by side. BEAM's limit of two versions per module (old and current) is irrelevant.

The process must cooperate. Its state lives in the arguments of its recursive function, where the runtime cannot see it, so only the process can carry the state over to new code. Upgrade is opt-in: a process whose message type has no upgrade case cannot be upgraded in place and is replaced instead.

Nominal type hashes (3.4) limit what an in-place upgrade can change. An address carries the hash of its mailbox type, so the new code must keep the same message type. If the upgrade case carries a function from the current state type, the state type is part of the message type and cannot change either. Changing the protocol or the shape of the state then means replacing the process: start a new one on the new code, hand the state over by message, and point clients at the new address, which depends on a registry (node protocol, open question 8). Whether this holds, and in which form, is open question 7.

## 9. Trust model

- The trust boundary is mutual TLS authentication and nothing else. Loading code from the network is remote execution by design.
- The receiver does not type check incoming IR again. It trusts that the sender did.
- Ill-typed IR cannot corrupt BEAM, which is memory safe, but can produce run-time errors.
- The hash guarantees integrity: what is loaded is what was named.

Known limitation: there is no authorization beyond authentication. Any authenticated peer may load and run any code on any node it talks to. This is acceptable while one owner controls all nodes. Per-peer permissions are to be designed only if nodes with different owners become relevant.

## 10. Resource management

### 10.1 Unloading and cache cleaning

The build's hash store (4.2) only grows. It is small and it is the history.

On a node, a hash may be unloaded and removed from the cache when all of the following hold:

1. no name table on the node refers to it,
2. no loaded hash depends on it,
3. `code:delete/1` followed by `code:soft_purge/1` succeeds. BEAM itself checks that no process runs the code or holds a fun from it.

Unloading frees code memory. Removal from the cache frees disk or memory. Both are attempted after a configured idle time. Reference counting per process is not used: closures live in process state and cannot be tracked without scanning memory, which BEAM's own check already does.

### 10.2 Atoms

Every module name is an atom, and atoms are never garbage collected (default limit about 1 million). A long-lived node that receives many versions leaks atoms.

Policy: the node counts its atoms. Above a configured threshold (proposed: 80 % of the limit) the node drains and restarts.

The restart is cheap for code, since the cache refills on demand. It is not cheap for processes: every process on the node dies, every address to it becomes dead, and watchers on other nodes receive notices (node protocol, sections 3.2 and 7). A threshold restart is therefore an operational event, and how often it happens is the measure that decides whether the hybrid is needed.

### 10.3 Hybrid in reserve

If threshold restarts become too frequent, the hybrid is activated: incoming units are first interpreted by an IR interpreter written in Erlang and compiled to hash modules only when hot. Cold code then costs no atoms. The IR format allows this without change, since the hash identifies IR, not binaries.

## 11. Consequences for MVP 1

MVP 1 does no hashing and no distribution, but prepares for both:

- IR is a separate, named stage between type checking and generation of Erlang forms.
- In the IR, names are already resolved to fully qualified references.
- In the IR, local variables are already numbered by position.

Normalization in MVP 3 then amounts to replacing references with hashes. Nothing in MVP 1 needs to be torn apart.

## 12. What remains versioned by platform

The requirement that code be identical across nodes disappears for everything that is hashed. What remains:

1. **The hash scheme**: same hash function, same canonical form, same IR version. Checked in the connection handshake (node protocol, section 9.3).
2. **The compiler back end**: needed on every node, but outside the hash. Its version is part of the key for cached binaries (section 6).
3. **Everything called by name from hashed code**: `erlang:` BIFs and the Ernest runtime. A difference in their behaviour between nodes leaks through unseen.

The prelude is compiled into hash modules like user code, from MVP 3. It then gets the same freedom from versioning as user code, and what remains name bound shrinks to the BIFs, the runtime and the OTP version. The OTP version is pinned per deployment.

## 13. Alternatives considered and rejected

- **Two node types** (all code on disk in the same version, or no code at all). A function reference crossing between them must be a hash anyway, so the name-based side would need a translation layer that leaks. One mechanism with two cache policies does the same work.
- **BEAM module replacement for single-node code change.** Hash modules never change, and Ernest's code change is already a message.
- **Hashing binaries.** The hash would depend on the compiler version, and interpreted and compiled code would have different identities.
- **Interpretation only.** Roughly an order of magnitude or more slower.
- **Hashes for verification only**, all nodes on the same release. Gives up diskless nodes, which are the point.
- **`error_handler` as fallback for missing code.** Eager transitive fetching and dependency-aware cleaning make missing code impossible, and the fallback had no defined source to fetch from.
- **Reference counting per process** for cache cleaning. Cannot track closures in process state, and misses dependencies between hashes.
- **Operations that point a name at a hash**, as Unison's codebase allows. The mapping from names to hashes becomes state kept apart from the source, so what the developer reads is no longer what runs. Error prone, and against the principle that the source is the whole truth.
- **Codebase as database**, with tools to manage it, as the source of truth for names. Its purpose is to make the mapping from names to hashes editable, which Ernest rejects (4.1). It would also need its own tools for editing, diffing and version control, where Ernest uses text and git.
- **Structural type hashes**, where a type's name is not hashed. Would make the check on the wire more lenient than the type checker, and would let opaque types with the same representation pass for each other.
- **Unison's split into structural and unique types**, where a unique type carries a random identifier. The identifier must live either in the source, as noise, or beside it, as the hidden state rejected in 4.1.
- **Nominal hashing for opaque types only.** Two rules instead of one, and ordinary types with the same shape would still collide.
- **Pinned references to hashes in source** (for example `handle@3fa9`). A hand-written pointer to a hash is the same name-to-hash operation in another form. An old version that is still needed keeps its own name.
- **Replacing or extending `code_server`.** Its work is still needed, OTP depends on it, and everything Ernest adds fits beside it.

## 14. Deferred

- **Sending binaries** as an optimization between nodes with the same back end and OTP version, if compile time proves a problem. The receiver cannot verify a binary against an IR hash without a compiler, so IR remains the unit of transfer.

## 15. Open questions

All are measurement questions for MVP 3, except 5, which is a specification still to be written, and 6 and 7, which are decisions:

1. The atom threshold for draining and restarting.
2. The frequency of threshold restarts that triggers activation of the hybrid.
3. When the IR format is frozen. Every change to it changes every hash, so it must be frozen and explicitly versioned before distribution is taken into use. A change after that is a cluster-wide cutover (node protocol, risk 8).
4. The idle time before unloading and cache removal.
5. The full normalization rules. Section 3.1 gives the principles only. Before MVP 3, a separate document must specify how references inside a strongly connected component are numbered, how literals, closures and constructors are put in canonical form, and how type expressions are hashed: type applications such as `Msg(Nat)`, function types, and the effect marker `{Proc m}`. Section 3.4 covers type declarations only, but addresses carry the hash of an instantiated mailbox type (node protocol, section 4.2), so type expressions need rules of their own. This is where risk 1 lives.
6. How a diskless node boots the platform. `erl_boot_server` has no TLS and checks only the IP address, so the platform, loader included, would arrive over an unauthenticated channel, contrary to the trust model (section 9). Alternatives: a read-only boot image holding the platform (network boot of a signed image, or local flash), which keeps the node free of user code without an unauthenticated step; or accept the gap on a trusted network and state it as a known limitation. The answer also decides how the node receives its key (node protocol, open question 9).
7. How the upgrade case is typed, and what an in-place upgrade may change (section 8). The limit on the message type follows from typed addresses. The limit on the state type follows only if the upgrade case carries a function from the current state type, which depends on how code change is typed in `ernest_report.md`. To be settled there, together with whether replacement with state handover needs support from the language or can stay a convention.

## 16. Risks

1. **Normalization.** The part where errors cost most. A fault gives either different hashes for identical code or, worse, the same hash for different code. It deserves its own test suite.
2. **Atom leak** on nodes that receive highly varied code, and the process loss of each threshold restart. Handled by 10.2, with 10.3 in reserve.
3. **Compile latency** when a node receives much code at once, typically at start-up.
4. **Name-bound behaviour below the hashes** (section 12), which does not show itself.
5. **Load throughput at start-up.** `code_server` is a single process. `prepare_loading` and batching closures with `atomic_load` should keep it from becoming a bottleneck, but this is the one thing to measure before relying on it. If it proves a bottleneck, the answer is larger batches, not a replacement server.
6. **Accidental type identity.** Two unrelated codebases that share a fully qualified type name and definition get the same type hash and are treated as one type (3.4). Unlikely with one owner. If it ever matters, a project name at the top of every qualified name removes it.
