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

Written as the questions are decided.

## 3. Examples

Written as the questions are decided.

## 4. What holds

Written as the questions are decided.

## 5. What does not hold

1. **An upgrade of `ern`, of OTP or of the hash scheme stops every node.** Nodes of different versions of any of the three never connect: the runtime's surface is what shipped code calls by name, and nothing hashes it. A program's own code is what a rolling restart changes.

The rest is written as the questions are decided.

## 6. How it works

**The hash.** A definition's hash is the SHA-256 of its canonical form: the typed tree after checking, with local variables numbered by position, layout and comments gone, every name resolved, and types written out. A reference to another definition is the hash of what it names, and nothing else; a reference to a foreign declaration, which has no hash, is its qualified name and its type, and each node resolves it for itself. A function's own name and its source positions are not in its hash: two functions with one body are one definition. A type's hash covers its qualified name, its parameters by position, its constructors in declared order with their fields' names and the hashes of their types, and the hashes of the members the type declares, `compare` among them. A mutually recursive group is hashed as one, in declared order, and each member's identity is the group's hash and its position in it. No project name stands above a qualified name. The canonical form is written down, with the hash scheme's version, before any hash is computed, and that version is in the cookie.

**The cookie.** The host's cookie is the digest of the protocol's version, the hash scheme's version, `ern`'s version and OTP's version. A program's code is not in it: the build's checksum of MVP 3.0 leaves, and nodes of different builds connect. What the hashes leave out agrees by the cookie: the runtime and the compiler's back end, which are `ern`'s; the standard library, which is hashed as a program's code is but ships with `ern`; the host's functions that code calls by name, which are OTP's; and a foreign declaration, which a peer resolves by name and type and has, its `ern` and OTP being the same.

The rest is written as the questions are decided.

## 7. The numbers

Written as the questions are decided.

## 8. How it is checked

Written as the questions are decided.

## 9. Unsolved

The questions, in the order they are taken; each leaves the list as it is decided.

1. **A node's code.** The cache keyed by hash, in memory or on disk; the loader beside the host's `code_server`; what a module of the host is for a hash; whether a node keeps embedded mode. (`code.md` 2.3, *D9*.)
2. **Code crossing with a spawn.** The have-and-want exchange; what a code frame carries, the form that is hashed or the compiled module; verification; what happens to the spawn when the exchange fails; a foreign declaration a peer lacks or has differently. (`code.md` 2.3, *D10*, *D13*, *D17*.)
3. **Messages and keys across builds.** A message carries its mailbox type's hash and the gateway checks it, which MVP 3.0's section 11 planned; a key carries its type's hash; what a peer of another build is answered where a type differs.
4. **Bindings across builds.** A top-level binding is evaluated once on a node for each hash of its definition, and a service binding of a new build beside the old one's on a peer: what `Peer.find` answers, and whether two services run. (`code.md` 2.5, 3.3.)
5. **The memory of code.** What holds code: a process, a value, a `restarting` function, an adapted address a peer may still send to; when a hash is unloaded; the host's atoms and lambda entries for each module loaded, measured. (`code.md` 2.4, 2.5, *D1*, *D4*, *D14*.)
6. **The standard library's `Code`.** What a module is to it, what a program does with one it has loaded, which functions are in, what it leaves in the host, and whether the shell's `:load` and `:reload` stand on it. (The plan's MVP 3.1, its first items.)
7. **The rolling deploy.** How a node of a new build joins nodes of the old; what a program sees of a service at another version; what `ern` shows of what changed between two builds, by hash.
8. **How it is checked**, with nodes of two builds on one machine.

## 10. Left out on purpose

- An upgrade in place of a running process, a change of protocol by a translation, and a rollback: step D, the milestone after this one, where [`code.md`](code.md)'s section 3 waits.
- The deploy tool that plans from the hashes, and the keeper: step D's.
- A node that boots the platform over the network, and the key such a node receives.
- A drain and restart of a node whose atoms near the host's limit, and the hybrid that interprets cold code: both serve a node that takes new code without a stop, which this milestone has not.

## 11. Room for what comes after

Written when the questions are decided, for step D. One thing is known already: a milestone after this one narrows `ern`'s version in the cookie to the runtime's surface, the part shipped code calls by name, and lets the rest of `ern` differ between nodes; that breaks no program, since nothing a program writes names a version.
