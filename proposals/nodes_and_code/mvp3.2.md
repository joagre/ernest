# Ernest: MVP 3.2, Code with a Spawn

Status: the proposal for MVP 3.2, split on 2026-10-09 from [`mvp3.1.md`](mvp3.1.md), on which it stands: MVP 3.1 gives every definition its hash, and this lets the code cross with a spawn to a peer that lacks it. It is read through before a line of it reaches the plan, the log or the report, and changes only by a question raised against it. What was tried and set aside is [`code.md`](code.md)'s section 8. The reasons are [`code.md`](code.md)'s and [`nodes.md`](nodes.md)'s sections 13, 15 and 17; what other systems do is [`other_systems.md`](other_systems.md), sections 6 and 7.

## 1. What it is

MVP 3.2 lets a spawn carry its code to a peer that lacks it.

A process on one node spawns a process on a peer. The function may be one the peer does not have: one typed at the shell, or one of a program the peer was never given. The code crosses with the spawn, named by its hash, verified on arrival, and compiled on the peer. A node that runs no program, the bare node, runs whatever its peers spawn on it. Nothing of MVP 3.1 changes.

Three things bound it.

- **Code crosses with a spawn, and nowhere else.** A find ships nothing. A message ships nothing. The shell's load is the session's.
- **A peer runs what it is sent, trusted as the peer is.** A peer that may spawn on a node may run anything on it.
- **The memory of code is what runs.** A unit no process runs is let go when the node nears a limit, and comes again when asked.

**Words.** Those of [`mvp3.1.md`](mvp3.1.md), and two more. The *exchange* is the frames by which a spawn ships code. A *bare node* runs no program.

## 2. What a program sees

**The operations** are MVP 3.1's, with one difference: a spawn on a peer carries its code where the peer lacks it. `NotLoaded` then means a binding's value the peer did not run, or the module a foreign declaration names, and never a function. `Refused` means that the peer could not load what was sent, and its text says why. A connection the handshake refused is `Unreachable`, as in MVP 3.0.

**What is new.**

- **A bare node.** `ern run --config-dir dir` with no `.erc` starts a node that holds no definition of a program's. It runs the runtime and the system processes, its entry process evaluates the standard library's bindings, and the node listens and waits. It ends by termination alone. Everything it runs arrives by a spawn from a peer, with the code. Nothing is copied to its machine but `ern`. A node without `listen` is refused at its start, since it never dials. A balancer places work on it as on any peer, and installs its measure there with `Balancer.serve`. A shell whose load path holds no program is a bare node with a prompt.
- **A function typed at the shell spawns on a peer**, with its code.
- **`Code`**, a module of the standard library, three functions. `Code.load(path)` loads a compiled module and its closure, from the load path, into the node's code table, as `ern run` loads a program; a file that is no `.erc` of this `ern`, or one whose closure the load path lacks, answers `Left`. `Code.hashes(path)` answers a compiled module's definitions, each as its name and its hash. `Code.running(f)` answers the addresses of the processes on this node whose stack holds a frame of `f`, at the moment of the call. It takes the function as a value, so a build that moves processes off `count` keeps `count` beside `count2`, unchanged, until the next deploy; `count`'s hash is then the old build's, and the processes are found. An upgrade is the program's own line over it: `List.each(Code.running(count), fn(p) = send(p, Counter.Upgrade(migrate = fn(n) = n, next = count2)))`. No function sends an `Upgrade` for a program.

```
Code.load : (Path) -> Either(Io.Error, Unit) with m+
Code.hashes : (Path) -> Either(Io.Error, List(#(String, Code.Hash))) with m+
Code.running : ((s) -> Unit with m) -> List(Address(m)) with n
```

**What may cross** is MVP 3.1's rule, with one addition: the function a spawn starts crosses with its code, where the peer lacks it.

**Captures and references** are MVP 3.1's. On a bare node every binding of the program's is one the peer did not run, so a function spawned there names the standard library's bindings and carries the rest as captured locals.

## 3. Examples

The counter of [`mvp3.0.md`](mvp3.0.md)'s section 3 runs on the store, and the desk and the board find it by `Counter.key`.

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

The spawn ships `count2`, which the store lacks. The spawned process sends the message on the store's own node, where a function in a message is allowed (§3.11). The counter switches by a tail call, its total kept, as §6.10 has it. Under MVP 3.1 the spawn answered `NotLoaded` naming `count2`. The fix is in the running process alone: a restart of the store runs the build's `count` again.

**An upgrade tool.** The same fix on every node, by a program. Build 2 keeps `count` as it was and adds `count2`; the tool is built with it and run as a node of its own, `ern run --config-dir /etc/ernest/tool upgrade.erc`, whose `ernest.conf` lists every node:

```ernest
// upgrade.ern, build 2

type Msg = Moved(node : String, count : Int)

fn main() : Unit with Msg = {
    let me = self();
    let nodes = Peer.nodes();
    List.each(nodes, fn(node) =
        match Peer.spawn(node, fn() = {
            let old = Code.running(Counter.count);
            List.each(old, fn(p) =
                send(p, Counter.Upgrade(migrate = fn(n) = n, next = Counter.count2)));
            send(me, Moved(node = node, count = List.length(old)))
        }, 5000) {
            Left(failure) -> Io.println(node <> ": " <> Io.show(failure))
          | Right(_) -> Unit
        });
    told(List.length(nodes))
}

fn told(left : Int) : Unit with Msg =
    if left == 0 then Unit
    else receive {
        Moved(node = node, count = count) -> {
            Io.println(node <> ": " <> Int.toString(count) <> " moved");
            told(left - 1)
        }
    }
```

On a node still at build 1 the spawn carries `count2`, the lambda and `Msg`; `count` it has, at the same hash, and `Counter.Msg` too. The spawned process finds every process on `count`, sends each its `Upgrade`, and reports back through `me`, an address the lambda captured. Each counter switches by its own tail call, its total kept; its address and its key are unchanged, so no client notices. A node whose spawn fails is printed and skipped, and the tool ends when every node has reported. Nothing of the runtime orders this: the order is the list's, the check is the program's, and a tool that waits for each node's report before the next is the same program with `told(1)` inside the loop.

## 4. What holds

MVP 3.1's claims, and three more.

1. **A node holds a hash only with its whole closure.** Nothing enters a node's code table before everything it references is there and verified.
2. **Code arrives verified or not at all.** Every definition that crosses is checked against its hash on arrival. A frame that fails ends the connection.
3. **A process keeps its code.** Nothing a process runs is ever changed or taken from it, in a spawn or when a unit is let go.

## 5. What does not hold

MVP 3.1's limits stand, but its third, which this milestone lifts. MVP 3.0's ninth holds for code that crosses: a peer's code is verified against its hash and run as the peer's own, trusted as the peer is.

1. **Code that arrived stays while something runs it, and comes again when asked.** A unit let go crosses again at the next spawn that needs one of its definitions. A node that holds many versions at once, their processes alive, says so on its standard error when it nears a limit of the host's (section 7).
2. **A spawn that ships code is slow once.** The first spawn of a definition on a node that lacks it crosses the closure, compiles it there and loads it, within the spawn's time or `Timeout`. The next spawn ships nothing. A fix to a definition many call ships every caller too, since each caller is a new definition, and costs the peer their compile. For a definition everyone calls that is the program, crossed and compiled once per node per fix.
3. **A spawned function finds no binding the peer did not run.** On a bare node that is every binding of the program's.
4. **A foreign declaration's implementation is outside the hashes.** A shipped definition that names a `foreign fn` runs the peer's copy of its module. A library's own Erlang is where the library is, and a bare node lacks it. So `Load`'s shims are over OTP's modules, and `Json`'s primitives are `ern`'s, in `erl/json`.
5. **A second offer under a key a living process holds faults the offerer**, on a bare node as on any. A peer that is to take a key over finds its holder by the key and kills it first.
6. **A table holds no function.** The compiler refuses `Ets.Table(k, v)` where `k` or `v` holds a function type. A program that kept handlers in a table keeps them in a process's state.

## 6. How it works

**A spawn that carries its code.** The spawn frame is MVP 3.1's: the function's hash, its captured values and the site. A peer that has the hash starts the process at once. A peer that lacks it asks for the closure's list. The sender sends the hashes the function references transitively, code and types, with the foreign declarations it names. The peer answers with the hashes it lacks, or with `NotLoaded`, where it lacks the module a foreign declaration names or the value of a binding the function names. The sender ships the missing code, dependencies first. A code frame carries one definition's canonical form with its immediate references, and never a compiled binary. The four frames, the request, the list, the lacks and the code frame, are Ernest's beside MVP 3.0's six. The peer verifies each frame against its hash as it arrives and holds it apart until the closure is complete. Then it compiles the closure with its own back end, loads it all at once, and starts the process. What the peer said it has is pinned until the load is done. A frame whose content does not match its hash is a faulty frame, and the connection ends. A closure the peer cannot compile or load fails the spawn with `Refused`, whose text is the peer's. The exchange runs in a process of its own on each node, and the gateways only pass its frames. The spawn's time covers the exchange. What arrived complete stays in the code table, and two spawns waiting on one hash share one exchange.

**A unit on arrival.** The definitions that arrive in one exchange become one unit, under a name of the node's own, its functions named by their position in it. Before the unit is compiled, each reference is linked through the table, as a build's units are: a reference to a definition of the unit becomes a local call, and one to a definition of another unit a call into that unit. The unit is made by the same back end from the same forms as a build's. The canonical form of a received definition, and of one typed at the shell, is kept beside its compiled code, and the node ships it onward as its own. Loading is by the host's `prepare_loading` and `atomic_load`, one batch per closure, with no `-on_load`. The node's units are off the code path, where nothing loads them but the node. Nothing of a node's code is on its disk but its build directory: a node restarted holds its build, and is sent the rest again.

**What a node lets go.** A unit that arrived by an exchange or a load is unloaded when no process executes it or holds a function of it. The host tells, `erlang:check_process_code`. The build's own units are never unloaded. A table holds no function: the compiler accepts `Ets.Table(k, v)` only where `k` and `v` hold no function type, the first case of §3.11's bound check. So every holder of a function is a process, and the host's check sees it. The node sweeps when it nears a limit of section 7, and lets go the units no process runs, oldest first, until it is under the limit; a unit no process runs stays until then, so a worker whose tasks end and are spawned again ships nothing. A unit unloaded leaves the table, and its name returns to the pool. A spawn that asks for one of its definitions again is sent it again, one exchange.

**The bare node.** Its entry process evaluates the standard library's bindings and waits; the node listens, takes spawns, and ends by termination. It offers what the processes spawned on it offer.

**The shell.** A function typed at the shell has a hash as any definition has, and spawns on a peer with its code. The rest is MVP 3.1's.

**`Code`.** `load` is `ern run`'s loading reached from Ernest: the module's canonical forms and its closure's are read from the load path, verified against their hashes, and become a unit as a load of the shell's does, counted against the limits of section 7. `hashes` reads the `.erc` and answers its table of names and hashes. `running` asks the host for each process's stack, maps each frame's unit and position through the code table to a hash, and keeps the processes with a frame of `f`'s hash, or of a lambda written in `f`; a function value names its unit and position, which the table maps to its hash the same way. Every process running `f` has `f`'s mailbox type, so the list is typed `Address(m)`. The list is a snapshot: a process that enters or leaves `f` after the call is not in it, and a process in it may have ended by the time it is sent to, as any address may.

## 7. The numbers

| What | Value |
|---|---|
| a code frame | one definition's canonical form, with its immediate references |
| what a fix crosses | the changed definitions and every caller whose hash changed with them, once per node |
| the frames of this milestone | four, beside MVP 3.0's six |
| a unit let go | one no process executes or holds a function of, oldest first, when the node nears a limit; a table holds none; the build's never |
| atoms a node can make in its life | 1,048,576, the host's, never reclaimed; a unit's name is reused when the unit is let go |
| module names a node can load in its life | 65,536, the host's (OTP 29); a unit let go returns its name to the pool |
| lambdas a node can load in its life | 524,288, the host's, never reclaimed (OTP 28 and later) |
| a node says it nears a limit at | four fifths of any of the three |

## 8. How it is checked

The runtime's tests start nodes on one machine, as MVP 3.0's do. A spawn of a function typed at a shell that is a node ships exactly the lacking definitions, verified and loaded at once, and the process runs; a spawn onto a bare node ships the program's closure once and nothing the second time, and the process offers a service the program finds; `NotLoaded` for a binding the peer did not run and for a foreign declaration it lacks; a faulty frame ends the connection; a late or broken exchange leaves nothing half-loaded; a fix crosses with its callers, and the callers compile on the peer; a unit whose processes have ended stays until the node nears a limit, is then let go, and crosses again at the next spawn that needs it, and one a process holds a function of stays; a table of a function type is refused by the compiler; a node told to load many units says so at four fifths of a limit, once, measured; the shell fixes a service on a peer through `Upgrade`; `Code.load` of a module and its closure lets a spawn of its function run, and a file that is no `.erc` or whose closure is missing answers `Left`; `Code.hashes` answers the names and hashes `ern build` wrote; `Code.running` lists the processes on `count`, none of them once each took its `Upgrade`, and a lambda's process under its enclosing function.

## 9. Unsolved

Every question the proposal was written through is decided. What remains is the build's:

- the measurements of section 7, and of what a spawn that ships code costs, a bare node's first spawn and the callers of a fix above all;
- the soundness argument's section 7, extended to code that crosses;
- the report's sentences: §8.7 for the spawn that carries its code, the bare node, and a peer that may spawn on a node running what it sends; §11.2 for a bare node and for what a node lets go; Appendix G.1 for a table that holds no function; Appendix E's page for `Code`, with `Code.Hash`; and the glossary's word, exchange, in Appendix F and in `docs/style.md`;
- the sections whose rules change: §8.1, §8.5, §8.6 and §11.8, for a bare node's entry process that runs no `main` and ends by termination; §6.10, whose cross-node sentence is completed by a spawn that carries its code; and `docs/development.md`'s table, from which the refusal of a node without a program goes.

## 10. Left out on purpose

The reasons are [`code.md`](code.md)'s section 8.

- Deltas on the wire: a caller whose hash changed with a fix crosses whole, not as the held hash and the references that differ.
- A scan of tables, or a count per table, before a unit is let go.
- A cache on disk of what a node received.
- A bare node of a build, given it by its configuration or by its first peer.
- A node that boots the platform over the network, and the key such a node receives.
- A compiled binary in a code frame.
- `Code.upgrade`, by address or by function.

## 11. Room for what comes after

1. **Deltas on the wire.** A caller a fix renames differs from what the peer holds in its references alone, so the sender could ship the held hash and the references that differ, and the peer make the form. What would bring it back is a measurement: a fix to a definition many call crossing more than a node's network can carry in a spawn's time.
2. **When a node sweeps.** A unit is let go when the node nears a limit; a sweep on a clock, or by how long a unit has gone unused, is a measurement away.

Two places carry the most risk. The compile on the peer, a bare node's first spawn and the callers of a fix, which the spawn's time bounds and the measurements must show fits it. And the let-go's reliance on the host's check seeing every holder of a function, which the table rule secures: a new place a function could rest outside a process would have to be refused the same way.
