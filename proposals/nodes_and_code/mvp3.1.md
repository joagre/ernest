# Ernest: MVP 3.1, Code by Its Hash

Status: built, by MVP 3.1's items 1 to 8 on 2026-10-09 and 2026-10-10, and kept as the record of its design; the report owns the rules, and the plan records where the build departed from it. The proposal was read through with the user on 2026-10-09, from which the plan's MVP 3.1 section was written, and changed after only by a question raised against it; the plan's item 9 read what was built on 2026-10-10, 106 findings worked (the log's *MVP 3.1 Read*). It was written on 2026-10-08 by MVP 3.0's item 12, from the two proposals under [`set_aside/`](set_aside/), and split on 2026-10-09 from [`mvp3.2.md`](mvp3.2.md), which builds on it. The reasons are [`code.md`](code.md)'s and [`nodes.md`](nodes.md)'s; what was set aside is code.md's section 8; what other systems do and what the experiments showed, the README names.

## 1. What it is

MVP 3.1 does two things. It gives every definition a hash, which names it on every node. And it tells a program that it is about to end.

The hash lets nodes of different builds work together. Two nodes connect whatever build each runs. A key names its type by hash, so a find answers `OtherType` where the two builds disagree about the type. A spawn names its function by hash, so a peer answers `NotLoaded` where it lacks the function. No code crosses from one node to another yet; that is [`mvp3.2.md`](mvp3.2.md).

The same hash lets the shell's `:load` and `:reload` work in a shell that is a node. A reload loads the new version of a module beside the old. Two versions of a type are two types in one session, and the checker keeps them apart.

A process that wants to know of the program's end calls `Os.terminating`. At the end the runtime sends it a message of its own mailbox type. The process writes what it keeps and answers. The program ends once every subscriber has answered.

Four things bound it.

- **The floor.** Every node runs the same release of `ern` on the same major release of OTP. The cookie holds that and nothing else. Nodes of different builds connect, and the hashes say what agrees, at a spawn and at a find.
- **A hash for each definition.** The compiler computes it from the definition's canonical form. It names a type at a key and a function at a spawn, and nothing else is named by it.
- **No change in place.** A process takes new code only by its own act, §6.10's message on its own node. A deploy is stop all and start all.
- **Nothing ordered, and nothing kept.** No coordinator, no plan and no command of `ern`'s orders a deploy: an operator's script does, with `ern stop` and `ern run`. The runtime holds no state for a program. A program told of its termination writes what it keeps, with `Fs`, and reads it at its next start.

The bounds of MVP 3.0 stay: a few nodes with one owner, listed by hand, trusted completely; no discovery; nothing the runtime retries.

**Words.** A *definition* is a function, a type or a top-level binding. Its *hash* is the SHA-256 of its canonical form. Its *identity* is what a reference to it names: for a function or a type, its hash; for a binding, its qualified name with its hash. Two definitions with one hash are one definition, whatever they are called. A definition's *reach* is the definition with everything it references, transitively. A *unit* is one module of the host's, holding compiled definitions. The *code table* is a node's table from each hash to the unit and function that hold it. A *subscriber* is a process that called `Os.terminating`.

## 2. What a program sees

**The operations** are MVP 3.0's, with one difference in what they answer. A spawn on a peer carries the function's hash, and the peer answers `NotLoaded` where it lacks something the function needs: the function itself, a binding's value, or the module a foreign declaration names. A find compares the key's type by hash, and `OtherType` means a service at another version of the type. `Peer`'s functions are unchanged; they answer `Io.Error`, into which `Peer.Failure` went by the principles review of 2026-10-09 (S24).

**What is new.**

- **The shell's `:load` and `:reload`** work in a shell that is a node. A load adds hashes and moves the session's names to them. A binding made before a load keeps the type it was checked under. A function typed at the shell spawns on a peer only where the peer has it, so on no peer until MVP 3.2.
- **Termination told.** `Os.terminating(wrap)` subscribes the calling process to the program's end. The program ends by termination, which the machine's service manager, `ern stop --config-dir dir` and `kill -TERM` send; by its entry process's end; or by `Os.exit`. At the end the runtime delivers `wrap(reply)` to each subscriber. The process takes the message in its own `receive`, writes what it keeps, and answers. The program ends once every subscriber has answered or ended. The interrupt, and a second termination, end at once. A subscription is one per process, the latest, and ends with its process. A program that is no node is told the same way.
- **`Standing.start(key, ms)`**, of the library `Standing` under `libs/`, spawns a process that finds the key and forwards to the service what it is sent, and answers `via` of that process. The process finds the key within `ms` and monitors the service; when the service ends or its node is lost it holds no address, and finds again, within `ms`, when the next message arrives, waiting on no clock of its own. It ends with the process that started it. A send to it while the service is away, and one whose find fails, is dropped, which its page states. A call through it waits by its own time and answers `None` where the service is not back. It is an ordinary process, and every rule of the report holds of its address. A program that is to monitor the service itself holds the address `Peer.find` gives.
- **The refusal.** `Supervisor.child`'s function, run inside a process that is already a child, faults with `Fault("a process runs one child function")`.

```
Os.terminating : ((Reply(Unit)) -> m) -> Unit with m
Standing.start : (Peer.Key(m), Int) -> Address(m) with n+
```

**What may cross** is MVP 3.0's rule. A bound type never crosses. The compiler refuses a key of a bound type, and a spawn whose captures are bound or hold a type variable. An adapted address's captures cross inside it as payload, touched only on the node that made it. No code crosses.

**Captures and references.** A top-level binding a spawned function names is the peer's, found by its identity, and `NotLoaded` where the peer did not run it. A local the function captures crosses as a value. So a value the function is to carry from the spawner is bound to a local first, `let key = Counter.key`, and captured. Nothing is read off the function's text but which names are locals. MVP 3.0's rule by module goes: a function spawns on a peer where the peer has it and every binding it names has its value there, whatever its module holds.

## 3. Examples

The counter of [`mvp3.0.md`](mvp3.0.md)'s section 3 runs on the store, and the desk and the board find it by `Counter.key`. The program is at build 1 on every node.

**A deploy.** Build 2 changes `count` to log each `Add`. The counter keeps its total across the stop, in a file it writes when it is told of the end and reads at its start:

```ernest-fragment
// store.ern, build 2

type Msg =
    Add(Int)
  | Get(reply : Reply(Int))
  | Terminating(Reply(Unit))

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
      | Terminating(reply) -> {
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

The operator's script copies build 2 to every machine, runs `ern stop --config-dir dir` on each node and `ern run` on each with the new build, one node at a time. At the store's stop the counter is told, writes its total and answers, and the node ends in order. At the store's start the counter begins with the total from the file, and `main` offers it. The board, still at build 1, connects to the store at build 2, since the floor is the same; `Counter.Msg` is unchanged, so its hash is, and the board's find answers the counter. The board holds `Standing.start(Counter.key, 5000)` in place of its find: it sees one `Down` with `ProgramEnd`, and finds the counter again once the store is back. A call through its standing address meanwhile answers `None` at its time.

**A changed protocol.** Build 3 adds a constructor to `Counter.Msg`. Its hash changes, and with it the key's. A board still at build 2 finds `OtherType` until it is rebuilt and restarted; nothing serves it the old protocol.

**A changed state.** Build 3 also counts the adds, and its state is a record `Count(total : Int, adds : Int)`. Its `saved` reads a file build 2 wrote, a number, into `Count(total = n, adds = 0)`, and a file build 3 wrote, an object, into the record. A file nothing reads begins the counter at `Count(total = 0, adds = 0)`. Nothing of the runtime takes part: the shape of the state, its file and its reading are the program's.

**A fix in the shell, on one node.** At `ern shell` over the store's build, `:reload` after an edit to `count` loads the new `Counter` beside the old. A binding made before the reload, `let c = Counter.service`, keeps its type, the old `Counter.Msg`; a `send(c, Add(1))` with the new `Add` is a type error, whose diagnostic says that `c` is of the previous version. The old counter runs on.

## 4. What holds

1. **A hash names one definition everywhere.** Two nodes that hold one hash hold one definition, whatever each build calls it.
2. **A process keeps its code.** Nothing a process runs is ever changed or taken from it, in the shell's reload above all.
3. **No message of one version is read as another's.** A key carries its type's hash beside its text, and a find answers `OtherType` where the holder's differs. A spawn carries the function's hash, so the function runs at the peer over the definitions it was compiled with. So what is sent through a remote address is of the type the receiver's code was compiled with, whichever builds the two nodes are of. On one node, across the shell's reload, a value keeps the type it was checked under: two versions of a type are two types in one scope, and the checker refuses a message of one to an address of the other.
4. **A subscriber is told before the end and answers before it.** The program ends once every subscriber has answered or ended. Nothing of the program runs after the end, which is in order, as in MVP 3.0.
5. **A client reaches its service after a restart without code of its own**, through the `Standing` library.

## 5. What does not hold

MVP 3.0's limits stand, every one.

1. **A deploy stops every node and starts every node.** Nothing orders it: the operator's script does, and a service is away for its node's restart. A node started with the new build before another was stopped connects to it. A find across them answers `OtherType` where the key's type changed, and an address where it did not.
2. **A protocol changed is a service not found.** A key at a type that changed has a new identity. A client of the old finds `OtherType` until it is rebuilt and restarted. Nothing serves the old identity through a conversion.
3. **A spawn starts only what the peer has.** A function the peer lacks, at its hash, is `NotLoaded`; a function typed at the shell is on no peer. Code crosses in MVP 3.2.
4. **A spawned function finds no binding the peer did not run.** It names the standard library's bindings and carries the rest as captured locals, or the peer answers `NotLoaded`.
5. **A foreign declaration's implementation is outside the hashes.** A `foreign fn` names a host module, which is each node's own. A module of OTP's or of `ern`'s is on every node. A library's own Erlang is where the library is.
6. **A load counts.** Each `:load` and `:reload` makes a unit, and nothing a session loaded is unloaded while the session runs. An input's module is unloaded once the input has its answer and its number given again, as today, so inputs do not count. A session that loads much says so on its standard error when it nears a limit of the host's (section 7).
7. **What a program keeps is its own.** The runtime holds no state and reads none back. A process told of the end writes what it wants, in the form it wants, and reads it at its next start. A changed shape is its own reading code. A process that is not told keeps nothing: one that did not subscribe, or one that faults before the end.
8. **The end waits for its subscribers and for nothing else.** A request in flight at the end is lost, as at any loss. A message that reaches a subscriber after it answered is lost with the process. A subscriber that neither answers nor ends holds the program until a second termination, the interrupt, or the service manager's patience, which kills; a process that waits with nothing in flight while the end waits is no deadlock, and the detector does not run against the end. Nothing withdraws a key before the end: a peer finds, calls and sends to a process told of the end, until the end.
9. **A retry is the program's.** A call that answered `None` may or may not have run, so a request must be harmless when run twice.

## 6. How it works

**The hash.** The canonical form is the typed tree after checking: local variables numbered by position, layout and comments gone, every name resolved, types written out. A reference to another definition is the hash of what it names, and nothing else. A reference to a foreign declaration, which has no hash, is its qualified name and its type; each node resolves it for itself. A function's own name and its source positions are not in its hash, so two functions with one body are one definition. A binding's identity is its qualified name with its definition's hash, since a binding is a thing that exists on a node, and two bindings with one initializer are two. A type's hash covers its qualified name, its parameters by position, and its constructors in declared order with their fields' names and the hashes of their types. A mutually recursive group is the strongly connected component of the dependency graph, hashed as one in source order; each member's identity is the group's hash and its position in it. A lambda's identity is its enclosing definition's hash and its position in it. An applied type's identity is its constructor's hash over its arguments' identities; a built-in type's is its name. The form's version is mixed into every hash, and changes with any change to what runs before hashing, the canonical form and the checker among it. The canonical form is written down, literals and order fixed, before any hash is computed. The site a spawn frame carries is the spawner's build's words, shown and never compared.

**The cookie and the floor.** The cookie is the digest of the protocol's version, `ern`'s version and OTP's major release, `erlang:system_info(otp_release)`. The build is not in it, and MVP 3.0's fingerprint goes. What the hashes leave out agrees by the cookie: the runtime's functions and the standard library, which code calls by name, and every foreign declaration over a module of OTP's or of `ern`'s.

**Messages and keys.** A message carries nothing of its type and goes straight into the mailbox. A key carries its type's text, as in MVP 3.0, and its type's hash beside it. Serialization and the gateway are MVP 3.0's.

**A spawn.** The spawn frame carries the function's hash, its captured values and the site, where MVP 3.0's carried the function's module and place. The peer looks the hash up in its code table and starts the process, or answers `NotLoaded` naming the function. A top-level binding the function names is found by its identity in the peer's bindings, and `NotLoaded` names it where the peer did not run it. Nothing is initialized because a peer asked.

**A node's code.** A node holds definitions by hash in its code table, and the compiled code lives once, as units. The build's units are one per source module, compiled as today, the `.erc` holding the canonical forms beside the compiled code. Nothing in a program names a unit. Naming a unit's functions by position, and making a unit from the forms, are MVP 3.2's, where code first arrives from another build (`mvp3.2.md`, *A unit on arrival*); a load in the shell brings function names that are already the program's atoms, and adds its unit's name. A build directory is never changed under a running node; a new build goes in a directory of its own. The node loads as `ern run` does today.

**The shell.** `ern shell --config-dir dir` is a node, as in MVP 3.0, and its `:load` and `:reload` work. Each adds hashes and moves the session's names to them. What a load brings to a node that already holds a unit of that module's name becomes a unit of its own, so a unit never takes a second version, and the load counts against the limits of section 7. A type in the session is its hash, so a binding made before a load keeps the type it was checked under. A message of a type's new version sent to an address of the previous one, or the reverse, is a type error, whose diagnostic says which of the two is of the previous version. A local address is a pid alone, and constructors of one name in two versions are one term, so the checker is the one thing that tells the versions apart on one node, as the hashes are between nodes. A process of a previous version runs on until it ends or is killed, reachable through the addresses of its version alone, its key offered again only once it has ended. A load evaluates the reach's bindings in a fresh process at `Never` while the session waits. Nothing a reload loads is a second version of a unit, so §11.2's fault for a further reload, `its code was unloaded`, goes, and with it from §7.4 and §8.4. A function typed at the shell has a hash as any definition has. The session's load is the session's, as today, and no module of the standard library loads code by name.

**Termination told.** The runtime keeps the subscription as it keeps one to faults. At the end it delivers `wrap(reply)` to every subscriber, each delivery a process of its own as a monitor's is, and watches each subscriber as it watches a callee. Once every reply is answered or its subscriber has ended, the end is MVP 3.0's, in order: every live process ends with `ProgramEnd`, the `Down`s cross, the connections close. While the runtime waits, every other process runs, and a peer finds, calls and sends to the node as before. A subscription made after the subscribers were told is told at once. A subscriber that faults while it writes is reported, and the end goes on without it. When termination arrives the node says on its standard error, once, that it waits for its subscribers and how many, and says each as it answers or ends, as it says a peer's loss (§8.7); nothing times the wait. Under `ern test` and in the shell the program is told the same way.

**The standing address.** `Standing` is Ernest, and the runtime has no part in it. Its process has the mailbox type `Message(m) | Went(Down)`, and the caller is given `via` of it with `Message`. It holds the address `Peer.find` gave, monitors the service's process, and forwards each `Message`. At `Went` it drops the address it held, and finds again, within `ms`, at the next `Message`; a message that arrives while it holds no address and whose find fails is dropped. It monitors the process that called `start`, and ends at its `Down`. The forwarder is one more process on a message's way, so a message through it may pass a message sent directly, as through any process (mvp3.0.md's claim 4.1).

**The refusal.** `Supervisor.child`'s function reads the process's start cause when it begins. Run inside a process that is already a child, it would read the outer child's, so it faults instead, `Fault("a process runs one child function")`, and E.22 says so.

## 7. The numbers

| What | Value |
|---|---|
| a definition's hash | SHA-256 over its canonical form, the form's version mixed in |
| the cookie | the protocol's version, `ern`'s version and OTP's major release; no build |
| the spawn frame | MVP 3.0's, with the function's hash in place of its module and place |
| the frames of this milestone | none beside MVP 3.0's six |
| atoms a node can make in its life | 1,048,576, the host's, never reclaimed; a load adds its unit's name and the names of functions the program had not, typed at the shell; nothing a correct peer sends makes one |
| module names a node can load in its life | 65,536, the host's (OTP 29); a unit per load |
| lambdas a node can load in its life | 524,288, the host's, never reclaimed (OTP 28 and later) |
| export entries a node can make in its life | 524,288, the host's (OTP 29), a unit's names among them |
| a node says it nears a limit at | four fifths of any of the four |
| the end's wait | until every subscriber has answered or ended; none of the runtime's own; said once, and each answer said |

## 8. How it is checked

The canonical form has a test suite of its own, written with the form before any hash is computed. Its cases: the same definition hashes the same across a rebuild; a renamed function keeps its dependents' hashes, and a renamed constructor changes them; a moved definition in a group changes the group's hash; two bodies that differ only in local names or layout hash the same; a literal's encoding is fixed. Two hashes for one definition, and one hash for two, are what it guards against.

The runtime's tests start nodes on one machine, as MVP 3.0's do. Of identity: two nodes of different builds connect, and a find across them answers `OtherType` where the key's type differs and an address where it does not; a spawn of a function the peer lacks answers `NotLoaded` naming it, and one of a function it has runs; `NotLoaded` for a binding the peer did not run and for a foreign declaration it lacks; a function that names no binding spawns where MVP 3.0's rule by module refused it; in the shell, a binding made before a `:reload` that changed its type refuses a message of the new version and takes one of its own, and the previous version's service runs on through two further reloads of its module; a session that loads many units says so at four fifths of a limit, once, measured. Of the end: a subscriber is told at termination, at the entry process's end and at `Os.exit`, and the program ends after its answer and not before; a subscriber that ended holds nothing up; a subscriber that faults while it writes is reported, and the end goes on; a second termination and the interrupt end at once; a subscription made during the end is told at once, and one made by a process that ended is gone with it; a program that is no node, a test under `ern test` and the shell are told the same way; a peer finds and calls a node whose subscribers are being told. Of the library: `Standing` drops a send and answers `None` to a call while the service is away, reaches it again on the same node and on another, and ends its process with its caller. And E.22's refusal.

A program's own test of two nodes needs nothing new: `ern test --config-dir dir`, with the other node started by `Os`, as in MVP 3.0.

## 9. Unsolved

Every question the proposal was written through is decided. What remains is the build's:

- the canonical form's document, with the form's version, written before any hash is computed; what an abstract type's hash covers beyond its declaration is its to decide;
- the measurements of section 7, and of what hashing costs a build and a load;
- the soundness argument's section 7, extended to the hashes between nodes of different builds and to identity by hash on one node across a load;
- the report's sentences: §8.7 for the floor, the key's hash, and the spawn by hash with `NotLoaded` by definition and by binding; §8.6 for the end that tells its subscribers and waits for their answers; Appendix E.23 for `Os.terminating`; §11.1 for what an `.erc` holds; §11.2 for the shell's reload; Appendix E.22 for the refusal; Appendix G for `Standing`; and the glossary's words, hash, identity, reach, unit and code table, in Appendix F and in `docs/style.md`;
- the sections whose rules change: §8.6 and §8.7, for the end that waits; §7.4, §8.4 and §11.2, from which `Fault("its code was unloaded")` goes; and `docs/development.md`'s table, from which the refusal of `:load` and `:reload` in a shell that is a node goes, and whose refusal of a node without a program names MVP 3.2.

## 10. Left out on purpose

The reasons are [`code.md`](code.md)'s section 8.

- Code that crosses, the bare node, and a function typed at the shell spawned on a peer: [`mvp3.2.md`](mvp3.2.md).
- Of nodes of different builds working together, the rest: a type's identity by its shape, `ern diff`, a service offered at an old identity through a conversion or a forwarder, and two builds for a changed protocol.
- A deploy the runtime orders and checks: the coordinator, the plan, lockstep, a node's restart inside its host process, the `build` file, the cache, the way back, the generated test, `ern deploy`, `ern status`, `ern state`, and `drain` and `coordinator` in `ernest.conf`.
- A state the runtime holds and writes, `kept`, a member `migrate`, a state file and `./.ernest/state/`; and the planned stop's withdrawal of keys and its drain.
- A module `Code` of the standard library: [`mvp3.2.md`](mvp3.2.md).
- An upgrade in place of a running process by anything but §6.10's message on its own node, and a change of a mailbox type under a translation.
- A state moved to another of its key's peers; an election, a lease, and a service that moves by itself at a failure.
- A bound of the runtime's own on the end's wait.
- The emitter's forms as the canonical form, in place of the typed tree.
- A project's name above a qualified name.

## 11. Room for what comes after

1. **Code with a spawn**, [`mvp3.2.md`](mvp3.2.md), which stands on everything here and changes nothing of it.
2. **The rest of nodes of different builds**, which [`set_aside/builds_side_by_side.md`](set_aside/builds_side_by_side.md) designs whole: a service that serves an old identity through a conversion, two builds for a changed protocol, `ern diff`. What would bring them back is a protocol that cannot be changed by rebuilding its clients.
3. **A deploy the runtime orders**, which [`set_aside/ordered_rolling_restart.md`](set_aside/ordered_rolling_restart.md) designs whole, and a state the runtime holds for it, with `migrate`. What would bring it back is a system too large to stop whole.
4. **A process's code is a hash it can be asked for.** `Process.info` may gain the hash of the function a process was started with.
5. **The canonical form is frozen** when it is written down, and changed seldom: each change is a new scheme version and a stop of every node. Whatever runs before hashing is part of it.

Two places carry the most risk. The canonical form, where two hashes for one definition or one hash for two cost most, and where everything that runs before hashing, elaboration and how supplies are filled, must be fixed with it. And the end's wait, which has no bound of the runtime's, so that a subscriber that forgets to answer holds a node until its service manager's patience runs out, which the deployment guide teaches to set above what the program's writing takes.
