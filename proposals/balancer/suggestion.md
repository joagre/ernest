# Placing Work on the Least Loaded Node

Status: under discussion, written on 2026-10-10 from a program written against `Balancer` that day. It stands on MVP 3.2 as [`mvp3.2.md`](../nodes_and_code/mvp3.2.md) designs it, taken as built: code crosses with a spawn, and a bare node runs what its peers spawn on it. Nothing here is decided, and nothing flows from it into the report, the plan or the log until the user says it is ready.

## 1. The normal case

A program has a computation and several nodes. It wants the computation run where there is room, and its value back: now, waiting for it, or later, as one message. Nothing else is on its mind: not which node, not how busy each is, not what to do when one is silent, beyond being told.

A reader who knows Erlang writes `erpc:call(Node, Fun, Timeout)` and picks `Node` as they like; Erlang's own picker by load, `pool:pspawn`, has been in its library for decades and is rarely used (the log's *No Remote Computation in the Language*, 2026-09-27). So the reader's expectation is a call that runs a function on a node and answers its value, with the choice of node near it and visible.

What that reader should be able to write in Ernest, the shape this proposal argues for in section 8:

```ernest
// now
match Peer.compute(Peer.peers(), fn() = heavy(n), 5000) {
    Right(result) -> ...
  | Left(error) -> ...
}

// later, as one message, by a local process
let me = self();
let _ = spawn(fn() = send(me, Computed(Peer.compute(Peer.peers(), fn() = heavy(n), 5000))));
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

**Is the language too restricted to do what section 8 suggests?** For shape A, no: a form of `Peer` is within what the language has, `Peer.spawn` and `Code.running` being forms already, and `compute` adds nothing to §3.11 but a result type checked as a key's is. For anything beyond A, yes, and that is the honest state: Ernest cannot put this in a library, since a function does not cross and a library generic in the result cannot spawn even a lambda of its own at a type variable (section 4). So the normal case can be given only by a primitive, counted, and a language that wanted it in a library would need shape C, a witness and function values that cross in a spawn, which is a concept. The restriction bought what §3.11 states: nothing is looked through at a send, a message is values only, no code on the receiving node, and no check of types at run time. Whether that price is right is decision 4 of section 11; this proposal pays the primitive and keeps the restriction.

## 7. The shapes weighed

Each judged against the five principles first, and against what it adds to the language.

**A. A form of `Peer` over a list of places, the policy stated whole.** `Peer.compute(places, f, ms)` picks among the places given by a rule E.27 states whole, runs `f` there, and answers its value. The policy is stated, not buried (E.0 rule 3's second clause), and the candidates are the program's argument, visible at the call (principle 3); a program that wants another policy makes it over `Peer.spawn` and `Peer.load`. It costs one primitive counted (principle 5) and reverses part of the 2026-09-27 verdict, section 10. One way to say it, whether the work is here or on a peer (principle 2), and the Erlang reader's `erpc:call` with its node chosen beside it (principle 1). **Recommended**, by principles 1 and 2; section 8 states it.

**B. A form of `Peer` over one name.** `Peer.compute(name, f, ms)`, `erpc:call` exactly, the pick the program's. Truest to principle 1's reader, and no policy enters the standard library. But the running node has no name, so the program that runs here or on a peer branches as today, and the pick needs the loads, so `Peer.load` enters anyway; the normal case stays three operations and a `match`. Not taken, by principle 1's test of the resulting code.

**C. A witness that a type crosses, and function values that cross in a spawn.** A requirement the compiler supplies, `needs a.crosses`, so that a library generic in `a` can write the spawn; and a flag per lambda, computed by the checker from its captures' types and checked by the runtime at a spawn of a function that came as a value, which would let a library take the program's function. The design the log of 2026-09-27 wanted, the branch written once inside a library, becomes possible, with the program's own measure as a function given. It costs a concept and a change to §3.11's rule, a compile-time refusal becoming `Left` for the by-value case alone, and the walk over a closure's captures at each such spawn. Not taken now, by principle 5: A gives the normal case without it; what would reopen it is a program whose right measure is not the node's load and whose policy must be a library's, section 9.

**D. Today's shape with `Peer.load`.** `Peer.load(name, ms)` answers a peer's load from the runtime, so the program installs no measure and `Balancer` drops `serve`; the pick and the branch stay in the program. Smaller than A by nothing counted, but the normal case is still the forty lines. Not taken alone; `Peer.load` enters with A, as the fact a program's own policy is made from.

## 8. The proposal

**`Peer.compute(places, f, ms)`** is a form of `Peer`, called where it is named as `Peer.spawn` is, and counted as a primitive: `f` is a lambda written in the same definition, a declaration's name or a local `fn`, as §3.11 admits for a spawn, and its captures are checked as a spawn's are. `places` is a list of peers' names as `ernest.conf` lists them. The runtime draws two of the places at random, asks each its load within half the time, takes the lower, passes over one that does not answer, and where neither answers takes the first given; with one place it takes it; with none it takes the running node. On the place taken it starts a process that runs `f()` and answers the value, and `compute` answers `Right(v)` within `ms` milliseconds, or `Left` with E.27's failures: `NotListed`, `Unreachable`, `Timeout`, `NotLoaded`, `Other(text)`. The result type `a` is known whole where `compute` is written and crosses, as a key's type must (§3.11); a bound `a` or one holding a type variable is refused there. `f` runs with the place's system processes and bindings, as a spawned function does.

```
Peer.compute(places, f, ms) : Either(Io.Error, a) with n+   // a form: f : () -> a, written where compute is
Peer.load(name, ms) : Either(Io.Error, Int) with n+
```

- **A fault in `f` is the caller's.** `compute` is a call of `f` that runs elsewhere, and a call's fault is its caller's: the caller faults with the cause and site the process gave, as if `f()` had faulted here (principle 1). No failure type of its own, which the 2026-09-27 verdict refused, and no monitor to write. The alternative, the fault as a value, `Left(Other(cause))`, makes a program that calls `heavy` on bad input live on where the local call would die; it is named for the user in section 11.
- **A late answer ends its process.** Where the caller's time ran out, the caller's node tells the place by the note a remote call already keeps (`nodes.md`'s section 11), and the process is killed as a spawn's late process is (§8.7), since nobody can reach it; where the connection was lost it runs on, the limit §8.7 states.
- **The running node.** With no places the work runs here, in a process of its own as on a peer, so that one line serves the laptop and the cluster: `Peer.peers()` is empty in a program that is no node. This is the 2026-09-27 objection to `spawn(Remote, f)`, section 10, answered by the argument: the places are the program's, written at the call, and an empty list is a value the program can read, where `Remote` chose silently. Whether the running node is also a candidate when places are given is a decision for the user, section 11.
- **The asynchronous form is a local process.** `spawn(fn() = send(me, Computed(Peer.compute(places, fn() = heavy(n), ms))))`: one message later, the value or the failure, no monitor, and the fault, if any, in that process. No `Peer.request` enters: it would be this one line as a function (E.0 rule 4), and the log of 2026-09-27 saw that a program wrote the process anyway.
- **The measure is the runtime's.** Every node answers its load to a peer that asks: the length of its run queue, `erlang:statistics(total_run_queue_lengths)`, the one measure the host answers at once with no state and no window, and `pool:pspawn`'s. `Peer.load(name, ms)` answers it to a program, by E.0 rule 1, so that a program's own policy over `Peer.spawn` needs no measuring process on any node. The schedulers' utilisation since the node was last asked is the alternative, steadier and needing a system process to keep the last reading; section 11 names it.
- **Bare nodes need nothing.** A bare node is a name in `ernest.conf`; `compute` ships `f`'s reach as a spawn does, the first time. No mark, no section of the configuration, no process of the program's living there.
- **At the shell.** `Peer.compute(["worker"], fn() = 6 * 7, 1000)` at a shell that is a node answers `Right(42)` from the worker, the function typed there and shipped.
- **Soundness.** The paragraph of `soundness.md`'s section 7 on what crosses extends by one case: `compute`'s value crosses back through a reply of the runtime's at the type `a` the compiler checked at the call, which is the type the process's `f` answers, since `f`'s form hashes its result type; the fault crosses as a spawned process's does to its monitor. Nothing new crosses: a function's captures as a spawn's, a value of a crossing type as a message's.
- **Cost.** A `compute` is a spawn's frames, two loads asked, and one answer: three messages to peers beside the spawn's, and no process of the runtime's on the caller's node. The pick grows with nothing; two loads are asked whatever the number of places. The measure is the host's own counter, no scan.

## 9. `Balancer` and `Load` afterwards

- **`Balancer` goes.** Once `Peer` places work by a stated rule, a library that also does is the second way (principle 2). What it alone could do, a measure of the program's own, is kept out until a program asks with a principle: a program whose right measure is not the node's load, a pool of connections full on an idle processor, writes its pick over `Peer.spawn` with measuring processes of its own, as today's program does; whether that earns a library is decided then, and shape C is what would make it a library over the program's function. A "Later" entry in the log holds that.
- **`Load` stays**, as the readings of this node: its shims are over OTP's modules, so a bare node has them, and a program that wants its node's numbers reads them. `Load.runQueue` and `Peer.load` answer one number, this node's and a peer's.
- **If 0.4.0 has shipped `Balancer`**, the release that removes it says so in its notes; G.5 goes, G.4 stays, and the guide's peer chapter names `Peer.compute` where it names `Balancer`.

## 10. What this reverses, and what changed since

The verdict of 2026-09-27 removed `remote(f)` for a choice of node by a measure the program could not see. `compute` keeps the choice in the runtime, among places the program names, by a rule E.27 states whole: the policy is visible in the report and the candidates in the code, which is E.0 rule 3's second clause, and the reader reads `compute(Peer.peers(), ...)` as `erpc:call` with the node drawn from a list beside it. The verdict's other two reasons stand met: no failure type of its own, and the asynchronous form a process the program writes, now one line.

What changed is three things the verdict did not have. The captures rule of 2026-10-08 made the library it designed unable to spawn the program's function, so the policy it wanted in a readable function cannot be in one, by section 4, and lives either in the program, forty lines each time, or in the runtime, stated. MVP 3.2 made the bare node the normal worker, which no program's measure should have to live on. And a program was written against `Balancer` and read back (section 2), which is what principle 1 asks: the resulting code decides, not the rule.

## 11. Decisions for the user

Each is named so that it is decided, with the lean stated.

1. **A fault in `f`**: the caller's, as a call's is (lean), or a value `Left(Other(cause))`.
2. **The running node among the candidates**: only where no place is given (lean), so that a store that lists its workers takes no work; or always, so that `compute(Peer.peers(), ...)` may run here.
3. **The measure**: the run queue, stateless (lean), or the schedulers' utilisation since last asked, steadier and kept by a system process.
4. **Shape C now or later**: later, with its Later entry (lean); or now, so that a library may take a function and a program's own measure has a home from the start.
5. **`Peer.load` enters with `compute`** (lean) or waits for a program that writes its own policy.

## 12. Left out, with the reason

- *`Peer.request`, the asynchronous form as a primitive*: section 8, one line as a function (E.0 rule 4; principle 2).
- *A place type in `Peer`, `Here | On(name)`*: `Here` as a candidate is a value the program cannot otherwise write, but a list of names with the empty list for here says the same in the words the configuration uses, and `Here` in the prelude was refused as a second spawn (principle 2); reopened only if decision 2 goes to "always".
- *A pool or a mark in `ernest.conf`*: the `"remote-peer"` flag was removed on 2026-09-27; the places are the program's argument (principle 3).
- *A policy argument, `compute(places, pick, f, ms)`*: E.0 rule 3 is met by stating the rule whole; a `pick` the runtime calls back on the caller's node would be a process of the runtime's acting for the caller.
- *A function that crosses in a message*: §3.11's "nothing is looked through at a send" stands; a function crosses in a spawn alone, where code already crosses.
- *A worker pool with a queue, retries, or an election*: the program's or a library's (`nodes.md`'s section 19).

## 13. What other systems do

- **Erlang**: `erpc:call(Node, Fun, Timeout)` runs a fun on a named node and raises the callee's exception in the caller, a fault being the caller's; `rpc:async_call` answers a key for a later `yield`. `pool:pspawn` picks the node with the least load, by the run queue, and is rarely used; programs build their own pools.
- **Elixir**: `Task.Supervisor.async({sup, node}, fun)` on a named node, the node the program's; no placement by load in the library.
- **Orleans**: a grain's placement is a strategy named per grain, among them one that samples a few silos and takes the least active, the power of two choices; the runtime places, the program names the strategy.
- **Akka**: a cluster-metrics router that weights nodes by heap, CPU and load, a router the program configures.
- **Unison**: `remote` evaluates a function at a location the program holds, shipping the code by hash; the location is the program's.

All but Orleans place where the program says and ship the function; where a runtime picks, the program names the policy. Section 8's `places` is the first, its stated rule the second.
