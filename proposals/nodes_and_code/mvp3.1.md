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

Written as the questions are decided.

## 6. How it works

Written as the questions are decided.

## 7. The numbers

Written as the questions are decided.

## 8. How it is checked

Written as the questions are decided.

## 9. Unsolved

The questions, in the order they are taken; each leaves the list as it is decided.

1. **What a definition's hash covers.** The canonical form: whether the typed tree or an intermediate form; whether a function's own name and its source positions are in it; how an external reference is written, by qualified name beside the hash of what it names or by the hash alone, and so what a rename costs; how a mutually recursive group is hashed; whether a type's hash holds the hash of its `compare`; whether a project's name parts two codebases' types of one name. (`code.md` 2.1, 2.5, 2.6: *D5*, *D8*, *D11*, *D12*, *D16*.)
2. **What the hashes leave out**, and what the cookie then holds: the hash scheme's version, the compiler's back end, the runtime, OTP, and the host's functions that code calls by name. (`code.md` 2.2.)
3. **A node's code.** The cache keyed by hash, in memory or on disk; the loader beside the host's `code_server`; what a module of the host is for a hash; whether a node keeps embedded mode. (`code.md` 2.3, *D9*.)
4. **Code crossing with a spawn.** The have-and-want exchange; what a code frame carries, the form that is hashed or the compiled module; verification; what happens to the spawn when the exchange fails; a foreign declaration a peer lacks or has differently. (`code.md` 2.3, *D10*, *D13*, *D17*.)
5. **Messages and keys across builds.** A message carries its mailbox type's hash and the gateway checks it, which MVP 3.0's section 11 planned; a key carries its type's hash; what a peer of another build is answered where a type differs.
6. **Bindings across builds.** A top-level binding is evaluated once on a node for each hash of its definition, and a service binding of a new build beside the old one's on a peer: what `Peer.find` answers, and whether two services run. (`code.md` 2.5, 3.3.)
7. **The memory of code.** What holds code: a process, a value, a `restarting` function, an adapted address a peer may still send to; when a hash is unloaded; the host's atoms and lambda entries for each module loaded, measured. (`code.md` 2.4, 2.5, *D1*, *D4*, *D14*.)
8. **The standard library's `Code`.** What a module is to it, what a program does with one it has loaded, which functions are in, what it leaves in the host, and whether the shell's `:load` and `:reload` stand on it. (The plan's MVP 3.1, its first items.)
9. **The rolling deploy.** How a node of a new build joins nodes of the old; what a program sees of a service at another version; what `ern` shows of what changed between two builds, by hash.
10. **How it is checked**, with nodes of two builds on one machine.

## 10. Left out on purpose

- An upgrade in place of a running process, a change of protocol by a translation, and a rollback: step D, the milestone after this one, where [`code.md`](code.md)'s section 3 waits.
- The deploy tool that plans from the hashes, and the keeper: step D's.
- A node that boots the platform over the network, and the key such a node receives.
- A drain and restart of a node whose atoms near the host's limit, and the hybrid that interprets cold code: both serve a node that takes new code without a stop, which this milestone has not.

## 11. Room for what comes after

Written when the questions are decided, for step D.
