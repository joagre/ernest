# Ernest: MVP 3.1, Builds That Differ

Status: the proposal for MVP 3.1, written on 2026-10-08 by MVP 3.0's item 12 from two proposals set aside the same day, [`set_aside/builds_side_by_side.md`](set_aside/builds_side_by_side.md), which was MVP 3.1, and [`set_aside/ordered_rolling_restart.md`](set_aside/ordered_rolling_restart.md), which was MVP 3.2 (the log's *The Milestones After 3.0, Weighed Again*), and rewritten twice on its read-through with the user the same day. First the planned stop and the kept state, kept at first from the second proposal, gave way to a program told of its termination, one subscription, so that a process writes what it keeps for itself. Then the hash scheme, kept at first from the first proposal, gave way to the module as the grain: nodes of different builds connect on one floor, a release of `ern` on a major release of OTP, and what may run where is told by the digests of modules that MVP 3.0 already computes, so that no canonical form, no exchange and no code table is built, and the only code that crosses is a shell's own modules, compiled. It changes only by a question raised against it, and nothing of it reaches the plan, the log or the report before the read-through ends. The reasons for what it says are [`code.md`](code.md)'s, written with it, and [`nodes.md`](nodes.md)'s sections 4, 6, 13, 14, 15 and 17, each paragraph dated where it was decided; what other systems do is [`other_systems.md`](other_systems.md), sections 6 and 7; what six programs showed of a change of code in place is [`experiments/code_update/`](experiments/code_update/README.md).

## 1. What it is

MVP 3.1 lets nodes of different builds work together, and tells a program of its termination before the end. Two nodes connect where they run one release of `ern` on one major release of OTP, whatever each was built with. A spawn on a peer runs where the peer holds the function's module, and the modules it depends on, unchanged, and where the bindings the function names have their values there; a find answers a service where the key's type is unchanged on both sides, and `OtherType` where it is not. A node that runs no program takes any build and runs what its peers spawn on it. A shell that is a node spawns on a peer what was typed at it, its own modules crossing with the spawn. A process that subscribes to the program's termination is told of it in its own mailbox type, answers when it has written what it keeps, and the program ends once every subscriber has answered.

Four things bound it:

- **One floor.** The cookie holds the protocol's version, `ern`'s version and OTP's major release, and nothing of a program's code. Below the floor nothing may differ; above it a build is each node's own.
- **The module is the grain.** Whether code is the same on two nodes is told by the host's digest of the compiled module, the one MVP 3.0's fingerprint already lists, never by anything finer. A changed function makes its module another module, and every type that module declares another type to a find.
- **No code crosses but a shell's.** A program's code is on each node's load path, copied there by whoever deploys; a spawn names a function the peer has, or fails with `NotLoaded`. The shell's inputs are in no build, so a spawn from a shell carries the session's modules the function needs, compiled, to a peer that trusts the session as it trusts any peer.
- **No change in place, and nothing kept.** A process never takes new code but by its own act, §6.10's message on its own node. A deploy is `ern stop` and `ern run` on each node, in whatever order the program's protocols allow, by an operator's script; nothing orders it. The runtime holds no state for a program: a process told of its termination writes what it keeps, with `Fs`, and reads it at its next start.

The bounds of MVP 3.0 stay: a few nodes with one owner, listed by hand, trusted completely; no discovery; nothing the runtime retries. Its four rules rule here too, and the fourth, *what crosses is identified, never named*, is kept at the module's grain: a function's module is named in a spawn and identified by its digest, and a key's type is named by its text and identified by the digests of the modules its definition reaches.

**The building blocks.** A module's *digest* is the host's digest of its compiled code, `beam_lib:md5`, which leaves out documentation, line numbers and attributes, so that a fixed typo in a doc block changes no module. A module's *dependencies* are the modules it uses, which its `.erc` names, and its *closure* is its dependencies transitively, itself included. A definition's *reach* is the top-level bindings it names, through every function it calls within the build, which the compiler writes into the `.erc` for each definition.

## 2. What a program sees

**The operations** are MVP 3.0's. `Peer`'s functions and `Peer.Failure` are unchanged. `NotLoaded` means what the function needs and the peer does not have: its module or one of its closure, unchanged; a binding's value; or the module a foreign declaration names. `OtherType` means the key's type is another type on the peer: declared in a module whose digest differs, or in one that depends on such a module. `Refused` is the peer's refusal of a shell's module it could not load, with the host's text; a connection the handshake refused is `Unreachable`, as MVP 3.0 has it.

**What is new.**

- **Nodes of different builds connect.** A node restarted with a new build connects to the old ones as any node does, its `ernest.conf` unchanged. A service whose type's modules are unchanged shows nothing to a client of either build; one whose type changed answers `OtherType` to a client of the other build until that client is restarted too, which a client written for peers meets as it meets `Unreachable`, by waiting and finding again. So a deploy may be rolling, by hand, where the program's protocols allow it, and stop all and start all where they do not.
- **A node that runs no program.** `ern run --config-dir dir --load-path dir...` with no `.erc` starts a node of whatever build its load path holds: it runs the runtime and the system processes, its entry process evaluates the standard library's bindings, as any program's does, and the node listens and waits, and ends by termination alone. Everything it runs arrives by a spawn from a peer; a spawned function there names no binding but the standard library's and carries the rest as captured locals, and a spawned process may offer itself under a key. A balancer places work on it as on any peer, and installs its measure there with `Balancer.serve`, whose process captures the balancer's address and names no binding.
- **The shell's `:load` and `:reload`** work in a shell that is a node, which MVP 3.0 refused: a load adds a module under a name of its own and moves the session's names, a binding made before it keeps the type it was checked under, and a function typed at the shell spawns on a peer with the session's modules it needs. A shell is a node of whatever its load path holds, and spawns a function of the build as a program does.
- **Termination told.** `Os.terminating(wrap)` subscribes the calling process to the program's end: when the program ends, by termination from the machine's service manager, from `ern stop --config-dir dir` or from `kill -TERM`, by its entry process's end or by `Os.exit`, the runtime delivers `wrap(reply)` to each subscriber, and the program ends once every subscriber has answered its reply or has ended. The process handles the message in its own `receive`, between two of its steps, writes what it keeps, and answers. The interrupt, and a second termination, end at once, as today. A subscription is one per process, the latest, and ends with its process. A program that is no node is told the same way.
- **`Standing.start(key, ms)`**, of the library `Standing` under `libs/`, spawns a process that finds the key and forwards to the service what it is sent, and answers `via` of that process; it is an ordinary process the program spawned, and every rule of the report holds of its address as of any. It finds the key within `ms`, monitors the service, finds again when the service ends or its node is lost, with `ms` between finds while a find fails, and ends with the process that started it. A send to it while the service is away is dropped, as a send during a loss is, and a call through it waits by its own time and answers `None` where the service is not back. A program that is to monitor the service itself holds the address `Peer.find` gives.
- **The refusal.** `Supervisor.child`'s function run inside a process that is already a child faults with `Fault("a process runs one child function")`.

```
Os.terminating : ((Reply(Unit)) -> m) -> Unit with m
Standing.start : (Peer.Key(m), Int) -> Address(m) with n
```

**What may cross** is MVP 3.0's rule unchanged: a bound type never crosses, the compiler refuses a key of a bound type and a spawn whose captures are bound or have a type variable in their type, and an adapted address's captures cross inside it as payload, touched only on the node that made it.

**Captures and references.** A top-level binding a spawned function names is the peer's, and `NotLoaded` where the peer did not run it; a local the function captures crosses as a value. A value the function is to carry from the spawner is bound to a local first, `let key = Counter.key`, and captured as any local is. The rule is one, and nothing is read off the function's text but which names are locals. So MVP 3.0's rule by module goes: a function spawns on a peer where every binding in its reach has its value there, whatever else its module holds.

## 3. Examples

The counter of [`mvp3.0.md`](mvp3.0.md)'s section 3 runs on the store, and the desk and the board find it by `Counter.key`. The program is at build 1 on every node.

**A worker.** A fourth machine, `worker`, has `ern` and build 1 copied to it, as every node has, and a directory `ern config` made whose `ernest.conf` lists the store. It runs `ern run --config-dir /etc/ernest/worker --load-path /srv/app/build1` and no program, and the store lists it. The store spawns on it:

```ernest-fragment
let key = Counter.key;
match Peer.spawn("worker", fn() = { Peer.offer(key, self()); count(0) }, 5000) {
    Left(_) -> Io.println("no worker")
  | Right(_) -> Unit
}
```

The lambda is written in `Store`, which the worker holds unchanged with its closure, so it runs; it captures `key`, a local holding the key's value, and names no binding of the store's; written with `Counter.key` inside it, the binding would be the worker's, which never ran it, and the spawn would fail with `NotLoaded`. The process offers itself, since only a process of the offering node may be offered. The worker's output goes to the worker's standard output. A worker still on build 1 when the store runs build 2, whose `Store` changed, answers `NotLoaded` naming `Store` until build 2 is copied to it and it is restarted.

**A fix from the shell.** The counter's `count` is to log each `Add`, and the program is not to be stopped for it. At a shell that is a node of the build, the operator types the new loop and sends it through §6.10's `Upgrade`, by a process spawned on the store:

```ernest-fragment
fn count2(total : Int) : Unit with Counter.Msg = ...
let counter = Optional.withDefault(Either.toOptional(Peer.find(Counter.key, 5000)), ...);
Peer.spawn("store", fn() = send(counter, Counter.Upgrade(migrate = fn(n) = n, next = count2)), 5000)
```

The lambda is in the session's eighth input and `count2` in its seventh, two modules no peer has, so the spawn carries both, compiled, under names of the session's own; the store loads them and starts the process, which sends the message on the store's own node, where a function in a message is allowed (§3.11). The counter switches by a tail call, its total kept, as §6.10 has it. `Counter`, which both inputs use, is the build's, and the store holds it unchanged. Under MVP 3.0 the spawn answered `NotLoaded`. The fix is in the running process alone: a restart of the store runs build 1's `count` again.

**A deploy behind the protocol.** Build 2 changes `count` to log each `Add`, and the counter keeps its total across the stop, in a file it writes when it is told of the end and reads at its start:

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

The operator copies build 2 to the store's machine, stops the store and starts it with build 2; the desk and the board stay at build 1. At the store's stop the counter is told, writes its total and answers, and the node ends in order; at its start the counter begins with the total from the file, and `main` offers it. The board, which holds `Standing.start(Counter.key, 5000)` in place of its find, sees one `Down` with `ProgramEnd` and finds the counter again once the store is back, since `Counter.Msg` is declared in `Counter`, which build 2 did not change; a call through its standing address meanwhile answers `None` at its time. Nothing of the two builds shows.

**A changed protocol.** Build 3 adds `Reset` to `Counter.Msg`. The store is restarted with build 3 first. The board's standing address, finding again, gets `OtherType`, since `Counter` changed, and finds again at its interval until the board is restarted with build 3 too; the desk at build 1 meets the same. Had `Store` changed in build 2 and `Counter` not, the finds would have answered the counter throughout, as above: what parts old clients from new services is a changed module among those the protocol's type reaches, and nothing else.

**A changed state.** Build 4 counts the adds as well, and its state is a record `Count(total : Int, adds : Int)`. Its `saved` reads a file build 3 wrote, which holds a number, into `Count(total = n, adds = 0)`, and one build 4 wrote, an object, into the record; a file nothing reads begins the counter at `Count(total = 0, adds = 0)`. Nothing of the runtime takes part: the shape of the state, its file and its reading are the program's.

## 4. What holds

1. **Nodes of one release of `ern` on one major release of OTP connect, and of different ones never.**
2. **A spawn runs the function the spawner named, byte for byte**: the peer holds the function's module and its closure with the digests the spawner's build has, or answers `NotLoaded` and starts nothing.
3. **No message of one version is read as another's.** Every remote address a program holds came from a find, where the peer compared the digests of the modules the key's type reaches; from a spawn of the program's own function, whose closure the peer compared; or inside a message whose type was agreed by one of the two, and a type reaches every module a value of it can carry. There is no fourth way, so a message carries nothing of its type and goes straight into the mailbox, as in MVP 3.0.
4. **A process keeps its code.** Loading only adds; nothing a process runs is ever changed or taken from it, in a spawn from a shell or in the shell's reload.
5. **A shell's module arrives whole or not at all**, under a name no other session's module has, and a module the peer cannot load fails the spawn with `Refused` and leaves nothing loaded.
6. **A subscriber is told before the end and answers before it**: the program ends once every subscriber has answered or ended, and nothing of the program runs after the end, which is in order, as MVP 3.0 has it.
7. **A client reaches its service after a restart without code of its own**, through the `Standing` library.

## 5. What does not hold

MVP 3.0's limits stand, but the first half of its eleventh: builds that differ connect.

1. **A changed module parts old and new for the length of a rollout**, and the module is the grain: an edit to any function in a module changes every type that module declares, to a find, and refuses every spawn of a function from it onto a peer that holds the old one. A program keeps a protocol's types in a module of their own, small and seldom edited, which the guide teaches; the finer grain, a definition's hash, is [`set_aside/builds_side_by_side.md`](set_aside/builds_side_by_side.md)'s.
2. **A changed protocol parts old clients from new services for the length of a rollout.** An old client's find on a node of the new build answers `OtherType`, and a new client's on an old node the same, until both are of one build; a client written for peers waits and finds again, as it does for `Unreachable`. A change to a type that many protocols reach parts clients from every service that reaches it at once.
3. **A node runs what is copied to it.** A spawn ships no code of a program's; a worker on a stale build answers `NotLoaded` naming the module, and the operator copies the build and restarts it. Nothing is loaded on a node but by its start, by the shell's load, and by a spawn from a shell.
4. **A shell's modules are trusted as the shell is.** They cross compiled, verified by nothing but the connection, which the key and the floor already vouch for; a peer loads what any listed peer sends it, as it does anything else a listed peer asks.
5. **Code loaded on a node stays until the node restarts.** A node that takes many spawns from a shell, or a shell that reloads often, says so on its standard error when it nears a limit of the host's (section 7), and is restarted.
6. **A spawned function finds no binding the peer did not run.** It names the standard library's bindings and carries the rest as captured locals, or the peer answers `NotLoaded`. On a node that runs no program that is every binding of the program's.
7. **A foreign declaration's implementation is outside the digests.** A `foreign fn` names a host module, which is each node's own; a module of OTP's or of `ern`'s is on every node of the floor, and one of a library's own Erlang is where the library is, so `Load`'s shims are over OTP's modules and `Json`'s primitives are `ern`'s.
8. **A patch of OTP may refuse a shell's module.** Within one major release the compiler may learn an instruction an earlier patch's emulator lacks, which OTP does not promise against; a shell on a newer patch spawning on a peer on an older one may be answered `Refused` with the host's text, and the operator patches the peer. The floor could refuse it at the handshake only by splitting every system at every patch.
9. **What a program keeps is its own.** The runtime holds no state and reads none back; a process told of the end writes what it wants, in the form it wants, and reads it at its next start, and a changed shape is its own reading code. A process that is not told keeps nothing.
10. **The end waits for its subscribers and for nothing else.** A request in flight at the end is lost, as at any loss, and a message that reaches a subscriber after it answered is lost with the process. A subscriber that neither answers nor ends holds the program until a second termination, the interrupt, or its service manager's own patience, which kills; a subscriber writes and answers. Nothing withdraws a key before the end.
11. **A retry is the program's.** A call that answered `None` may or may not have run, so a request must be harmless when run twice.
12. **A second offer under a key a living process holds faults the offerer**, as MVP 3.0 has it; a peer that is to take a key over finds its holder by the key and kills it first.

## 6. How it works

**The floor.** The cookie is the digest of the protocol's version, `ern`'s version and OTP's major release, `erlang:system_info(otp_release)`, in place of MVP 3.0's full version of OTP and checksum of the build. The host's handshake proves both sides hold it before anything passes, as before, and the refusing side says why on its standard error, `the peer x was refused: it runs another release`. What the digests leave out agrees by the floor: the runtime's functions and the standard library, which compiled code calls by name, and every foreign declaration over a module of OTP's or `ern`'s.

**The digests.** Each node keeps, from its start, the table MVP 3.0 computed for its fingerprint, each module on its load path with the host's digest of its code, and beside it the module's dependencies from its `.erc`. A spawn frame carries, with the function's module and place as in MVP 3.0, the digests of the module's closure as the spawner's node holds them, in name order; the peer compares them against its own table, and answers `NotLoaded` naming the first module it lacks or holds with another digest. The reach of the function, the bindings it names through the calls it makes, is in the `.erc` the peer holds, written there by the compiler for each definition, so the peer reads it from its own copy and answers `NotLoaded` naming the first binding without a value; nothing crosses for it. A key holds, with its name and its type's text, the digests of the modules its type's definition reaches, which the compiler computes where `Peer.key` is written, through every field type to the modules that declare them, in name order; a find compares them against the peer's table, and answers `OtherType` where one differs or is missing. The compiler refuses a key whose type reaches a module typed at the shell, since no two sessions hold one; a function typed at the shell spawns, below.

**Messages.** A message carries nothing of its type and goes straight into the mailbox, as in MVP 3.0, by claim 3. Serialization and the gateway are MVP 3.0's; the frames are MVP 3.0's six, the spawn's and the find's grown by their digests, and one more for a shell's modules.

**Bindings.** A node holds its bindings' values as MVP 3.0 has it, and initializes nothing because a peer asked. A spawned function finds a binding's value where the peer's own program ran it, which the peer's table of initialized modules and the function's reach decide together, and fails with `NotLoaded` where it did not; a value a spawned function is to have on the peer is captured. A service is one per node and key, a second offer faulting while it lives: a node of a build offers what that build started, and a node that runs no program what its peers spawned on it.

**A node that runs no program.** `ern run --config-dir dir --load-path dir...` with no `.erc` loads what its load path holds, as `ern run` loads a program's build whole, evaluates the standard library's bindings in its entry process and no module's of the program's, listens, and waits in its entry process for termination. Its digests are those of what it loaded, so it takes a spawn from any peer whose build it holds unchanged. It is refused at its start without `listen`, since it never dials.

**The shell's modules.** A session's inputs are modules, as today, and each is named on the host after the session as well as the input, so that two sessions' seventh inputs never share a name on a peer; the session shows `$Input7` as before. A spawn from a shell of a function in the session's module carries, in one frame beside the spawn's, the compiled code of every module of the session's in the function's closure, the reach of each with it, each named and with its digest; a module of the build's is not carried, and is compared by its digest as any. The peer loads what it lacks by `code:load_binary`, all of it before the process starts, and a module whose name it holds already with another digest, or one the host refuses to load, fails the spawn with `Refused` naming the module, nothing loaded. What arrived stays, so the next spawn of the same input carries nothing. `:load` compiles a module of the source root into a name of the session's own and binds the module's name to it; `:reload` compiles it again into a fresh name, so that no module of the host's takes a second version, and §11.2's fault for a further reload, `its code was unloaded`, goes, and with it from §7.4 and §8.4, since nothing is unloaded. A type in the session carries the load it came from, so a binding made before a reload keeps the type it was checked under, and a message of a type's new version sent to an address of the previous one, or the reverse, is a type error whose diagnostic says which of the two is of the previous version; a process of a previous version runs on until it ends or is killed, reachable through the addresses of its version alone, its key offered again only once it has ended. A load evaluates the module's bindings in a fresh process at `Never` while the session waits. Each load and each reload adds a module name of the host's, which section 7 bounds.

**Termination told.** `Os.terminating(wrap)` is a subscription the runtime keeps for the calling process, as it keeps a subscription to faults: one per process, the latest, ended with its process. When the program ends, by termination, by its entry process's end or by `Os.exit`, the runtime delivers `wrap(reply)` to every subscriber, each delivery a process of its own as a monitor's is, and watches each subscriber as it watches a callee; it goes on to the end once every reply is answered or its subscriber has ended, and the end is MVP 3.0's, in order: every live process ends with `ProgramEnd`, the `Down`s cross, the connections close. While the runtime waits, every other process runs, a peer finds, calls and sends to the node as before, and nothing withdraws a key. A subscription made after the subscribers were told is told at once. The interrupt, and a second termination, end at once, as today, and a fault's end of a subscriber while it writes is a fault as any, reported, the end going on without it. A program that is no node is told the same way, under `ern test` and in the shell too.

**The standing address.** `Standing.start(key, ms)` is Ernest, in a library, and the runtime has no part in it. Its process has the mailbox type `Message(m) | Went(Down)`, and the caller is given `via` of it with `Message`. It finds the key by `Peer.find(key, ms)`, holds the address found, monitors the service's process, and forwards each `Message`; at `Went` it finds again, and where a find fails, `OtherType` among the failures, it waits `ms` and finds again. A message that arrives while no address is held is dropped. It monitors the process that called `start` and ends at its `Down`, so that nothing is left finding. The forwarder is one more process on a message's way, and a message through it may pass a message sent directly, as through any process (mvp3.0.md's claim 4.1).

**The refusal.** `Supervisor.child`'s function reads the process's start cause when it begins; run inside a process that is already a child it would read the outer child's, so it faults instead with `Fault("a process runs one child function")`, and E.22 says so.

## 7. The numbers

| What | Value |
|---|---|
| the cookie | the digest of the protocol's version, `ern`'s version and OTP's major release |
| a module's digest | the host's `beam_lib:md5` of its compiled code, 16 bytes |
| a spawn frame's digests | one for each module of the function's closure, in name order |
| a key's digests | one for each module its type's definition reaches, in name order, computed where the key is written |
| the frames of this milestone | one, a shell's modules, beside MVP 3.0's six |
| module names a node can load in its life | 65,536, the host's, never reclaimed (OTP 29): the build's, and one for each load, reload and shell's module shipped |
| atoms a node can make in its life | 1,048,576, the host's, never reclaimed |
| a node says it nears a limit at | four fifths of either |
| the end's wait | until every subscriber has answered or ended; none of the runtime's own |

## 8. How it is checked

The runtime's tests build one program twice with one module changed, start a node of each on one machine as MVP 3.0's tests do, and hold the claims of section 4: the floor lets them connect, and a node of another release of `ern`, which the test fakes in the cookie, is refused with the line; a find across them answers the address where the key's type reaches no changed module and `OtherType` where it reaches the changed one; a spawn of a function from an unchanged module runs on the other build, and one from the changed module answers `NotLoaded` naming it; a function that names no binding spawns where MVP 3.0's rule by module refused it, and one that names a binding the peer did not run answers `NotLoaded` naming the binding; a node with no program and the build on its load path takes a spawn and offers a service the program finds, and one on a stale build answers `NotLoaded`; a shell that is a node spawns a function it typed, which carries the session's modules once and nothing the second time, two sessions' inputs of one number both loading on one peer, and a module the peer holds with another digest answering `Refused`; the shell fixes a service on a peer through `Upgrade`; in the shell, a binding made before a `:reload` that changed its type refuses a message of the new version and takes one of its own, and the previous version's service runs on through two further reloads of its module; a node that loads many modules says so at four fifths of a limit, once, measured. A subscriber is told at termination, at the entry process's end and at `Os.exit`, and the program ends after its answer and not before; a subscriber that ended holds nothing up; a subscriber that faults while it writes is reported and the end goes on; a second termination and the interrupt end at once; a subscription made during the end is told at once, and one made by a process that ended is gone with it; a program that is no node, a test under `ern test` and the shell are told the same way; a peer finds and calls a node whose subscribers are being told. The `Standing` library drops a send and answers `None` to a call while the service is away, reaches it again on the same node, on another and after `OtherType` once the client is of the new build, and ends its process with its caller; and E.22's refusal.

A program's own test of two builds needs nothing new: `ern test --config-dir dir` with the other build started by `Os`, as MVP 3.0's test of two nodes has it.

## 9. Unsolved

Every question the proposal was written through is decided. What remains is the build's: the measurements of section 7, what a spawn's digests and a shell's shipped modules cost; the soundness argument's section 7 extended to builds that differ, by claim 3's induction over the digests, and to a load on one node; and the report's sentences, §8.7 for the floor, the digests at a spawn and a find, the node that runs no program and the shell's modules, §8.6 for the end that tells its subscribers and waits for their answers, Appendix E.23 for `Os.terminating`, §11.1 for what an `.erc` holds, its dependencies and each definition's reach, §11.2 for a node without a program and for the shell's load under a name of its own and its reload with nothing purged, Appendix E.22 for the refusal, Appendix E.27 for `NotLoaded` and `OtherType` as they mean here, Appendix G for `Standing`, and the glossary's words, floor, digest, closure and reach, in Appendix F and in `docs/style.md`. The rewrite names the sections whose rules it changes: §8.1, §8.5, §8.6 and §11.8, for an entry process that runs no `main` and ends by termination; §8.7's *Connections*, whose fingerprint becomes the floor and the digests; §7.4, §8.4 and §11.2, from which `Fault("its code was unloaded")` goes, since nothing is unloaded; §3.11, which keeps its rule; and `docs/development.md`'s table, from which the refusals naming MVP 3.1 go, and the two naming MVP 3.2 become plain unknown-field refusals.

## 10. Left out on purpose

- A definition's hash as the grain, with its canonical form, its exchange that ships a program's code to a peer that lacks it and its code table, kept at first from the first proposal and set aside on the read-through of 2026-10-08: its precision pays only where two versions must be told apart definition by definition during a rollout, which is the orchestration's, and the module's grain is what the host already computes and what a reader who knows Erlang expects. [`set_aside/builds_side_by_side.md`](set_aside/builds_side_by_side.md) is its record, and it is the finer answer for a day a module's grain is too coarse.
- A type's identity by its shape, by which a renamed type stayed one type across builds: with the module as the grain a type is its module's, and the shape served the kept state's file alone, which went.
- A deploy the runtime orders and checks: the coordinator, the plan, lockstep, a node's restart inside its host process, the `build` file, the cache, the way back, the generated test, `ern deploy`, `ern diff`, `ern status` and `ern state`, and `drain` and `coordinator` in `ernest.conf`. A deploy is the operator's script over `ern stop` and `ern run`; [`set_aside/ordered_rolling_restart.md`](set_aside/ordered_rolling_restart.md) is the record.
- A state the runtime holds and writes, `kept`, a member `migrate`, a state file and `./.ernest/state/`, and the planned stop's withdrawal of keys and its drain, kept at first from that proposal and set aside on the read-through: the keys and the drain served the rollout's find and its next node, and the kept state dragged in five concepts for what a program does for itself with `Fs` and `Json` once it is told of its end. What a program lacked was only to be told, which `Os.terminating` gives.
- A node of no build that takes its build from its configuration, or from the first peer that connects: a node runs what its load path holds, and the floor is all the cookie checks.
- A module `Code` of the standard library, `load` and `hashes`: no Ernest code has anything to load by name, the shell's load is the session's, and `hashes` served `ern diff`.
- A version a program declares on a protocol, in place of the digests: it lets a human say unchanged of a change, which a digest cannot.
- An upgrade in place of a running process by anything but §6.10's message on its own node, and a change of a mailbox type under a translation: [`set_aside/deploy.md`](set_aside/deploy.md)'s section 15 says what they would cost, and [`set_aside/code.md`](set_aside/code.md)'s part two is the record of the thinking.
- A state moved to another of its key's peers; an election, a lease, and a service that moves by itself at a failure: a library's, over a store outside the nodes.
- A bound of the runtime's own on the end's wait: a subscriber's answer is what the end waits for, and a second termination or the service manager's patience is the bound.
- Unloading code: a node's code is bounded by section 7's limits, and a node warned restarts.
- A node that boots the platform over the network, and the key such a node receives.

## 11. Room for what comes after

1. **A finer grain**, the definition's hash, which [`set_aside/builds_side_by_side.md`](set_aside/builds_side_by_side.md) designs whole: a spawn frame and a key already carry identities and compare them, and a hash could take a digest's place in each without a program noticing. What would bring it back is a program whose protocols cannot be kept in modules of their own, or a system too large to stop whole whose rollouts the digests part too often.
2. **A deploy the runtime orders**, which [`set_aside/ordered_rolling_restart.md`](set_aside/ordered_rolling_restart.md) designs whole over the first, and a state the runtime holds for it, with `migrate`: the end that tells its subscribers is the half of its planned stop that stays, and a kept state would stand on it. What would bring it back is the same.
3. **A process's code is a module it can be asked for.** `Process.info` may gain the module and digest of the function a process was started with, so that a node can list the processes still on old code after a fix from the shell.
4. **The memory of code is bounded, not reclaimed.** A node that never restarts takes every module it is sent and every reload, the host's tables never shrink, and section 7's limits and warning are the answer.
5. **A rolling deploy the program orders**, over `Peer.nodes`, `Os.start` and `ern stop`, where an operator's script has grown into one: a library's, as `Balancer` is.

Three places carry the most risk. The grain, where an edit to a function beside a protocol parts clients from the service for a rollout, which the guide's discipline of a protocol's own module answers and only programs written on it will show. The host's limits, which bound a node's life by what it loads, and which a later OTP relieves. And the end's wait, which has no bound of the runtime's, so that a subscriber that forgets to answer holds a node until its service manager's patience runs out, which the deployment guide teaches to set above what the program's writing takes.
