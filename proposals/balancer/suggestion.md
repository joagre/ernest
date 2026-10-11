# Placing Work on the Least Loaded Node

Status: under discussion, written on 2026-10-10 from a program written against `Balancer` that day, and rewritten on 2026-10-11 from shape A to shape B after the discussion of its section 7, with the node's measure the maintainer's. It stands on MVP 3.2 as [`mvp3.2.md`](../nodes_and_code/mvp3.2.md) designs it, taken as built: code crosses with a spawn, and a bare node runs what its peers spawn on it. Nothing here is decided, and nothing flows from it into the report, the plan or the log until the user says it is ready.

## 1. The normal case

A program has a computation and several nodes. It wants the computation run where there is room, and its value back: now, waiting for it, or later, as one message. Nothing else is on its mind: not which node, not how busy each is, not what to do when one is silent, beyond being told.

A reader who knows Erlang writes `erpc:call(Node, Fun, Timeout)` and picks `Node` as they like; Erlang's own picker by load, `pool:pspawn`, has been in its library for decades and is rarely used (the log's *No Remote Computation in the Language*, 2026-09-27). So the reader's expectation is a call that runs a function on a node and answers its value, with the choice of node near it and visible.

What that reader should be able to write in Ernest, the shape this proposal argues for in section 8:

```ernest
// now: the least busy of the peers, or here where there is none
match Placement.leastBusy(Peer.peers(), 1000) {
    Some(name) -> Peer.compute(name, fn() = heavy(n), 5000)
  | None -> Right(heavy(n))
}

// later, as one message, by a local process
let me = self();
let _ = spawn(fn() = send(me, Computed(computed(n))));
```

## 2. What exists

Appendix G.5's `Balancer`, Appendix G.4's `Load`, and E.27's `Peer.peers`, `Peer.spawn` and `Peer.spawnMonitored`. The program spawns a balancer over its places, `Here` and `On(name)`; spawns a measuring process on every place, which registers with the balancer; asks the balancer for a place; and spawns its work there, with `spawn` for `Here` and `Peer.spawn` for a peer, since a node is no peer of itself. A pick draws two of the measured places at random, asks each for its load, and takes the lower.

The program written on 2026-10-10 against it, ten computations placed by load with their values printed, is forty lines in four parts: the places, the measures, the pick, and a `computeAt` with a `match` on the place into two spawns of two result types, and a loop that keeps `#(Process, Int)` pairs so that a `Down` can be matched to its computation. It compiled, ran on one node, and ran on two nodes on one machine, the peer taking three of the ten. It is kept in the session's scratchpad and not in the repository; its shape is the guide's peer chapter's, and nothing in it goes around a gap.

Two costs showed. A measured pick costs the two measures added together: `Load.schedulers(100)` waits out its window, and the balancer asks its two drawn places one after the other (`asked` in `balancer.ern`), so a pick is at least 200 ms and ten picks in a row at least two seconds. And every node needs the same build on its load path, the program and both libraries.

## 3. Why it came out so

Each rule holds on its own. The shape is their product.

1. **The policy left the language on 2026-09-27.** `remote(f)` ran a function on a peer the runtime chose by load and answered its value. It was removed, with its failure type and the `"remote-peer"` flag of `ernest.conf`, for three reasons: waiting is what a spawn and a `receive` do; a failure type that existed for it alone; and a choice of node by a measure the program could not see (principle 3). `spawn(Remote, f)` went with it: on a node with no peer it must fault or run here, the fallback principle 3 refuses, and `Anywhere` kept the policy in the runtime. The verdict: the two facts only the runtime has, the nodes and how busy one is, enter the standard library; the policy over them is a library's, since sampling, ties and a silent peer are choices E.0's rule 3 refuses to bury (the log's *No Remote Computation in the Language*).
2. **The library cannot spawn the program's function.** §3.11: the function a spawn on a peer starts is written where the spawn can see it, a declaration's name or a lambda of the same definition, since a function that came as a parameter carries its captures in no type. A check at run time was set aside because a value carries nothing of its type: a pid of a bound `Address(m)` looks like any pid (the log's *The Bound Type in the Checker*, 2026-10-08). So `Balancer` answers a place and the program spawns.
3. **This node is no peer of itself.** A spawn that takes a place, `Here` or a name, was weighed and refused as a second way to write `spawn(f)` (principle 2; the log's *Placing Work Without `Where`*, 2026-10-01), and a node has no name of its own in `ernest.conf` (`nodes.md`'s section 19). So every program branches on `Here` and `On(name)` into two spawns.
4. **Nothing is installed globally.** A chooser registered once would make every spawn depend on code its reader cannot see, and two libraries registering one would collide (principle 1). So the program installs a measure on every place, and the measuring processes register with the balancer because a find cannot name a node (the log's *A Balancer Reaches Its Measures by Their Registering*, 2026-10-08).
5. **A fault is the process's, and every wait on a peer is a value.** The result comes back by a message the program declares, a `Down` by a monitor, and a failure of the spawn as `Left`, each matched where it arrives.
6. **A measure costs what measuring costs.** The schedulers' utilisation over a window waits the window; `cpu_sup` keeps its time per calling process; and the pick asks in turn.

The log of 2026-09-27 designed a library that took the program's function and spawned it, the branch written once inside the library, which is what its section recommended. The captures rule of 2026-10-08 took that away, and the branch moved into every program. Neither entry foresaw the other.

## 4. Why it cannot be as nice as it could be

The limits that stand whatever this proposal decides, since each is a choice of the language's or the host's, with its reason. The proposal moves some of the cost; it removes none of these.

**The language.**

- **Functions do not cross.** A function type is bound to its node (§3.11), since its captures are not in its type. So no function of the standard library or of a library takes a function and runs it on a peer: `Balancer.compute(f)` cannot be a library function. The function a spawn starts is written at the spawn, and an operation that starts a function on a peer is a form, called where it is named, as `Peer.spawn` and `Code.running` are (§3.11, `mvp3.2.md`'s section 2), and counted as a primitive (principle 5).
- **Hindley-Milner, and nothing of a type at run time.** A library generic in the result, `compute : (() -> a, Int) -> Either(Io.Error, a)`, cannot write the spawn itself even where a lambda of its own is allowed: its lambda captures an address or a reply at the type variable `a`, and a value whose type holds a type variable is refused, since whether it crosses depends on the instantiation, which the compiled code does not know (§3.11, §3.9). Only the program's call site, where `a` is concrete, or the runtime, which checks nothing and ships what the compiler admitted, can do it. A witness that `a` crosses, a requirement the compiler supplies (§4.9), would let a library do it, at the cost of a concept (principle 5); section 7 weighs it.
- **A value's type is gone at run time.** A pid is a pid, so the runtime cannot check at a spawn that a captured address's mailbox type crosses, and the check is the compiler's, at the one place it sees the lambda. This is why rule 2 of section 3 is what it is.
- **A policy is not the standard library's.** A module is a library's where it is over a policy, and no policy is buried in a standard function: a choice its result depends on is an argument, or its section states it whole so that a program can make another (E.0's module rule and rule 3). Which node, by which measure, with what on silence, is such a policy.
- **One way to spawn here.** `spawn(f)` is the one way, and a form that places on `Here` beside it is a second (principle 2). A node has no name for itself, since no peer uses it (`nodes.md`'s section 19).
- **A fault belongs to its process.** A spawned process's fault reaches its spawner by a monitor as a `Down`, and in no other way (§6.9, §7); a program that wants the cause writes the monitor.
- **Every wait on a peer is a value with a time.** A peer out of reach is what a program of several nodes is written to meet, so a spawn and a find answer `Left` and take milliseconds (`nodes.md`'s section 13, E.0 shape rule 8). The price is a `match` at every operation on a peer where a local `spawn` has none.
- **Every message a process sends goes from that process.** No process of the runtime's sends on a caller's behalf, since the host keeps order per sender and receiver (`nodes.md`'s section 11). What arrives later arrives from the process that computed it, or as a monitor delivers.

**The host.**

- **The compiler of the host runs on the worker.** A function the worker lacks crosses as canonical forms and is compiled there before the process starts (`mvp3.2.md`'s section 1); the first call of a function on a node pays the host's compiler, the next pays nothing, and a unit let go pays it again.
- **A bare node ran no binding of the program's.** A function that names a top-level `let` of the program, a service binding above all, answers `NotLoaded` there; it carries what it needs as captured locals (`mvp3.2.md`'s section 2).
- **A spawn whose time ran out may have started its process**, and one whose connection was lost runs on (§8.7); a silent peer is found by the detector in 45 to 75 seconds (`nodes.md`'s section 13), so a wait without a time is a wait of a minute.
- **The host's measures are what they are.** `scheduler_wall_time` is a difference over a window; `cpu_sup:util` is since the calling process's last call; `memsup` counts in minutes. A measure that answers at once with no state is the run queue, which is noisy.
- **A pid carries no type**, so every address of another node's process came from a find or a spawn, which compare types by hash (§3.11); there is no address the runtime can make up.

## 5. What MVP 3.2 changes

- **Three kinds of program, and no fourth.** A node running a program; a bare node, `ern run --config-dir dir` with no `.erc`, which has an `ernest.conf`, listens, and runs what its peers spawn on it; and a program without `--config-dir`, which is no node and has no peers. The bare node is the natural worker: install `ern`, run `ern config`, list the store. There is no node without a configuration that could be spawned on.
- **The function need not be of the build.** `heavy` may be typed at a shell that is a node, or belong to a program the worker was never given; the first spawn ships its reach. "Compute this lambda where there is room" is an operator's line at the shell as much as a program's.
- **The captures rule is unchanged.** `mvp3.2.md` keeps MVP 3.1's: the function is written where the spawn sees it. 3.2 ships code; it does not let a function value cross.
- **A measure on a bare node is nobody's.** A bare node has no program to install one, so each program that uses the pool pushes its own measuring process there and keeps its own balancer; two programs sharing four workers hold two views of one load. The measuring processes never end, so their units are never let go: the one part of every program that lives on every worker for ever.

## 6. Two questions

**Is the current balancer story over-engineered, and over-complicated for no reason?** Over-complicated for the normal case, yes. For no reason, no: every piece has a reason, section 3, and each was sound when given. What went wrong is that the reasons were decided one at a time, each in its own entry, and the product was never read as a program until 2026-10-10. Principle 1 says the resulting code decides, not the rule, and that test was not run. Where the engineering exceeds the normal case: the balancer process with its turns, the pick spawned as a process of its own, the random draw threading a seed, the measuring processes that register and are monitored, and the `Here`/`On` branch all exist to serve a measure of the program's own, which the design of 2026-09-27 put first and no program has asked for; the normal case uses none of them. One cost is an oversight rather than a design: the pick asks its two measures one after the other, so a pick costs their sum where it could cost the slower.

**Is the language too restricted to do what section 8 suggests?** For shape B, no: a form of `Peer` is within what the language has, `Peer.spawn` and `Code.running` being forms already, and `compute` adds nothing to §3.11 but a result type checked as a service's type is; a pick over names is an ordinary library, since a name crosses. For anything beyond B, yes, and that is the honest state: Ernest cannot put a function that takes the program's function and runs it elsewhere in a library, since a function does not cross and a library generic in the result cannot spawn even a lambda of its own at a type variable (section 4). So running a function on a peer can be given only by a primitive, counted, and a language that wanted it in a library would need shape C, a witness and function values that cross in a spawn, which is a concept. The restriction bought what §3.11 states: nothing is looked through at a send, a message is values only, no code on the receiving node, and no check of types at run time. Whether that price is right is decision 4 of section 11; this proposal pays the primitive and keeps the restriction.

## 7. The shapes weighed

Each judged against the five principles first, and against what it adds to the language.

**A. A form of `Peer` over a list of places, the policy stated whole.** `Peer.compute(places, f, ms)` picks among the places given by a rule E.27 states whole, two drawn at random and asked their load within half the time, runs `f` there, and answers its value. One line for the normal case, and the reader's `erpc:call` with the node drawn beside it. Not taken, for two reasons found when the proposal was read again. The rule is a policy of four clauses, sampling, a time, silence and a fallback, which is what the verdict of 2026-09-27 kept out of the standard library because E.0's rule 3 refuses to bury it, and "stated whole in E.27" carries four clauses less well than it carries `List.sort`'s stability. And "within half the time" is a time of the runtime's own, which §0's *Time* paragraph forbids: the runtime chooses no time of its own. The proposal's own last paragraph had named B as the honest shape where the distinction between a rule in the report and a pick in the code is read as none; it is read so.

**B. A form of `Peer` over one name, and the fact a pick is made from.** `Peer.compute(name, f, ms)`, `erpc:call` exactly: the function runs on the named peer and its value comes back, the pick the program's. With it `Peer.utilisation(name, ms)`, how busy a peer is, the one fact only the runtime has, on a scale every node answers alike whatever it measures; and the node's measure the maintainer's, one entry of `ernest.conf`. The pick is then a few lines over `Peer.utilisation` in the program, or one function of a library, which a library can be since a name crosses where a function does not. No policy enters the standard library, the verdict of 2026-09-27 stands whole, the choice of node is in the program's code, and the runtime chooses no time. What B gives up against A is the empty list meaning "here": a program writes `heavy(n)` for here, which is the one way there already is. **Recommended**, by principles 3 and 5 and the *Time* paragraph; section 8 states it.

**C. A witness that a type crosses, and function values that cross in a spawn.** A requirement the compiler supplies, `needs a.crosses`, so that a library generic in `a` can write the spawn; and a flag per lambda, computed by the checker from its captures' types and checked by the runtime at a spawn of a function that came as a value, which would let a library take the program's function. The design the log of 2026-09-27 wanted, the branch written once inside a library, becomes possible, with the program's own measure as a function given. It costs a concept and a change to §3.11's rule, a compile-time refusal becoming `Left` for the by-value case alone, and the walk over a closure's captures at each such spawn. Not taken now, by principle 5: B gives the normal case without it; what would reopen it is a program whose right measure is not the node's and whose policy must be a library's over its function, section 9.

**D. Today's shape with the fact alone.** `Peer.utilisation` enters and the program installs no measure, but the pick and the `Here`/`On` branch stay in the program and the normal case is still forty lines. Not taken alone; the fact enters with B.

## 8. The proposal

**`Peer.compute(name, f, ms)`** is a form of `Peer`, called where it is named as `Peer.spawn` is, and counted as a primitive: `f` is a lambda written in the same definition, a declaration's name or a local `fn`, as §3.11 admits for a spawn, and its captures are checked as a spawn's are. `name` is a peer's name as `ernest.conf` lists it. On that peer it starts a process that runs `f()`, and `compute` answers `Right(v)` within `ms` milliseconds, or `Left` with E.27's failures: `NotListed`, `Unreachable`, `Timeout`, `NotLoaded`, `Other(text)`. The result type `a` is known whole where `compute` is written and crosses, as a service's type must (§3.11); a bound `a` or one holding a type variable is refused there. `f` runs with the peer's system processes and bindings, as a spawned function does, and the code it needs crosses as a spawn's does (`mvp3.2.md`'s section 1).

**`Peer.utilisation(name, ms)`** answers how busy the peer is, a `Float` on one scale: 1.0 is every scheduler busy, below it room, above it work waiting. Every node answers it as its configuration says it measures itself.

```
Peer.compute(name, f, ms) : Either(Io.Error, a) with n+       // a form: f : () -> a, written where compute is
Peer.utilisation(name, ms) : Either(Io.Error, Float) with n+  // how busy the peer is, 1.0 every scheduler busy
```

- **A fault in `f` is the caller's, reported once.** `compute` is a call of `f` that runs elsewhere, and a call's fault is its caller's: the process that runs `f` is the call's and has no life of its own, so its fault is carried to the caller, which faults with the cause and site `f` gave, as if `f()` had faulted here, and is reported there as every fault is (§11.2); the peer writes nothing of it, as `erpc` carries the callee's exception and logs none. No failure type of its own, which the 2026-09-27 verdict refused, and no monitor to write.
- **A late answer ends its process.** Where the caller's time ran out, the caller's node tells the peer by the note a remote call already keeps (`nodes.md`'s section 11), and the process is killed as a spawn's late process is (§8.7), since nobody can reach it; where the connection was lost it runs on, the limit §8.7 states.
- **Here is `f()`.** A node has no name for itself and `compute` takes none: a program that runs the work on this node writes `heavy(n)`, or `spawn` where it wants a process, the one way there is (principle 2). `Peer.peers()` is empty in a program that is no node, so a pick over it answers `None` and the program's `None` clause runs here.
- **The asynchronous form is a local process.** `spawn(fn() = send(me, Computed(computed(n))))`, with `computed` the four lines of section 1 as a function: one message later, the value or the failure, no monitor, and the fault, if any, in that process. No `Peer.request` enters: it would be this one line as a function (E.0 rule 4), and the log of 2026-09-27 saw that a program wrote the process anyway.
- **The measure is the node's.** `ernest.conf` gains one entry, `"utilisation"`, node-global, read at the start and at the hangup reload as the rest of the configuration is (§8.7): `"run-queue"`, the default, the length of the run queue over the number of schedulers, `erlang:statistics(total_run_queue_lengths)`, the one measure the host answers at once with no state and no window, and `pool:pspawn`'s; or `"schedulers"`, the schedulers' utilisation since the node was last asked, the one reading the node keeps, which needs no clock of the runtime's. Another measure the runtime offers is added by name there, and a program never chooses it: how a node counts itself is the operator's, visible in the operator's own document (principle 3); which peer a program picks is the program's.
- **The pick is a library's, over names.** `Placement.leastBusy(names, ms) : Optional(String) with n+`, the one function of `libs/placement`, asks every name its utilisation at once, each within `ms`, and answers the least busy of those that answered, the first given at a tie, and `None` where none answered. Every name and not a sample, by principles 1 and 3: a reader predicts the least busy of the names given, and a random draw would put a choice into the pick the program cannot see or repeat; the asks go out together, so a pick costs the slowest answer whatever the count. A program with many peers and many pickers passes a sample it drew itself. The rule is in the library's doc block, and a program that wants another writes its own over `Peer.utilisation`.
- **Bare nodes need nothing.** A bare node is a name in `ernest.conf`; `compute` ships `f`'s reach as a spawn does, the first time. No mark, no process of the program's living there, and no measure installed: the node answers its own.
- **At the shell.** `Peer.compute("worker", fn() = 6 * 7, 1000)` at a shell that is a node answers `Right(42)` from the worker, the function typed there and shipped.
- **Soundness.** The paragraph of `soundness.md`'s section 7 on what crosses extends by one case: `compute`'s value crosses back at the type `a` the compiler checked at the call, which is the type the process's `f` answers, since `f`'s form hashes its result type; the fault crosses as a spawned process's does to its monitor. Nothing new crosses: a function's captures as a spawn's, a value of a crossing type as a message's.
- **Cost.** A `compute` is a spawn's frames and one answer; a `utilisation` is one ask and one answer, the host's own counter and no scan; a pick is one ask per name, all at once. No process of the runtime's on the caller's node, and no process of the program's on a peer beyond the work itself.

## 9. `Balancer` and `Load` afterwards

- **`Balancer` goes, and `Placement` takes its place.** `start`, `serve`, the balancer process, the measuring processes and their registering, the random draw and the place type go, and with them the name, which named a process that kept balancing and says nothing of a rule; `libs/placement` has one function, `leastBusy(names, ms)` over `Peer.utilisation`, named for its rule so that the policy stands in the call, and a second rule, if one ever earns its place, is a function beside it and not an argument. What the old library alone could do, a measure of the program's own, is kept out until a program asks with a principle: a program whose right measure is not the node's, a pool of connections full on an idle processor, writes its pick over `Peer.spawn` with measuring processes of its own, as today's program does; whether that earns a library is decided then, and shape C is what would make it a library over the program's function. A "Later" entry in the log holds that.
- **`Load` stays**, as the readings of this node, under its name: its shims are over OTP's modules, so a bare node has them, and a program that wants its node's numbers reads them. It is the operator's word for those numbers, and it stands beside nothing that loads code; `Peer.utilisation` is not named `load`, since `Code.load` and `:load` load code and a reader takes the verb.
- **Before 0.4.0.** Built as items of MVP 3.2 placed before its release item, so that 0.4.0 ships `Peer.compute`, `Peer.utilisation` and `Placement`, and never ships `Balancer`.

## 10. What this reverses, and what changed since

Nothing is reversed. The verdict of 2026-09-27 removed `remote(f)` for a choice of node by a measure the program could not see, kept the facts only the runtime has for the standard library and the policy over them for a library or the program, and refused a failure type of its own and an asynchronous primitive. B is that verdict built: `compute` runs where the program says, `utilisation` is the fact, the pick is a library's over names, a fault is the caller's, and the later form is a process the program writes, now one line.

What changed is three things the verdict did not have. The captures rule of 2026-10-08 made the library it designed unable to spawn the program's function, so a pick that spawns cannot be a library's; a pick that answers a name can, and that is the shape taken. MVP 3.2 made the bare node the normal worker, which no program's measure should have to live on, so the measure became the node's own, chosen by its maintainer. And a program was written against `Balancer` and read back (section 2), which is what principle 1 asks: the resulting code decides, not the rule.

## 11. Decisions

Decided with the user on 2026-10-11, each with the principle that decided it.

1. **Shape B over A.** A put a four-clause policy into the runtime and chose a time of its own; B adds one form and one fact and keeps the verdict whole (principles 3 and 5; §0's *Time* paragraph).
2. **A fault in `f` is the caller's, reported once on the caller's node.** `compute` is a call that runs elsewhere, and a call's fault is its caller's; the process is the call's and the peer writes nothing (principles 1 and 3).
3. **The measure is the node's, chosen by its maintainer** in `ernest.conf`, `"run-queue"` by default and `"schedulers"` where said, on one scale with 1.0 every scheduler busy, so that peers compare whatever each measures (principle 3; E.0 rule 1 for the fact).
4. **The pick asks every name**, not a sample, and is named for its rule, `Placement.leastBusy`, since `Balancer` named a process that no longer exists and said nothing of the rule (E.0 shape rule 10): a reader predicts the least busy of the names given, and a random draw is a choice the program cannot see; a program with many peers samples itself (principles 1 and 3).
5. **Shape C later**, with its Later entry: functions that do not cross is the right trade, and no program has yet paid the price of writing its own measure (principle 5).
6. **The name is `utilisation`**, not `load`: `load` is the verb that loads code in `Code.load` and `:load`, and utilisation is the operator's word for the number on this scale (E.0 shape rule 10).

**The order of the work**, once the proposal is ready: the report's sentences first, §3.11 for the form and its result type, §8.7 for the frames, the carried fault and the late process, §10's cost line, §11.3 for the entry, E.27 for `compute` and `utilisation`, G.5 for `libs/placement` in `Balancer`'s place; the soundness paragraph; the log's entry; the plan's items; then the code, the guide and the tests.

## 12. Left out, with the reason

- *Shape A, the pick in the runtime*: section 7.
- *`Peer.request`, the asynchronous form as a primitive*: section 8, one line as a function (E.0 rule 4; principle 2).
- *A place type in `Peer`, `Here | On(name)`, or the empty list meaning here*: a node has no name for itself, and `Here` in the prelude was refused as a second spawn (principle 2); here is `f()`.
- *A pool or a mark in `ernest.conf` for the workers*: the `"remote-peer"` flag was removed on 2026-09-27; the names are the program's argument (principle 3). The configuration's one entry says how a node measures itself, not where work goes.
- *A policy argument, `leastBusy(names, policy, ms)`, or a `pick` named for no rule*: the rule is the function's name, and another rule is another function; a program that wants its own writes it over `Peer.utilisation`.
- *A program's own measure in the library*: shape C, section 7 and 9.
- *A function that crosses in a message*: §3.11's "nothing is looked through at a send" stands; a function crosses in a spawn alone, where code already crosses.
- *A worker pool with a queue, retries, or an election*: the program's or a library's (`nodes.md`'s section 19).

## 13. What other systems do

- **Erlang**: `erpc:call(Node, Fun, Timeout)` runs a fun on a named node and raises the callee's exception in the caller, a fault being the caller's; `rpc:async_call` answers a key for a later `yield`. `pool:pspawn` picks the node with the least load, by the run queue, and is rarely used; programs build their own pools.
- **Elixir**: `Task.Supervisor.async({sup, node}, fun)` on a named node, the node the program's; no placement by load in the library.
- **Orleans**: a grain's placement is a strategy named per grain, among them one that samples a few silos and takes the least active, the power of two choices; the runtime places, the program names the strategy.
- **Akka**: a cluster-metrics router that weights nodes by heap, CPU and load, a router the program configures.
- **Unison**: `remote` evaluates a function at a location the program holds, shipping the code by hash; the location is the program's.

All but Orleans place where the program says and ship the function; where a runtime picks, the program names the policy. Section 8's `name` is the first, and its pick, a library's over names or the program's, the second.
