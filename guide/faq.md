# Frequently asked questions

The questions a reader of [*Programming in Ernest*](language.md) brings, each answered by what Ernest does, with the section that states it. [Why Ernest](why.md) is the argument the answers rest on.

**It looks like Gleam. What differs?**

The process is the language, where Gleam's typed messaging is a library over the runtime's processes, well made too. What differs is how far the types reach: a function that receives names its mailbox's type, a `receive` reads only the mailbox of its own process, the one that type names, and `spawn` and `monitor` are the prelude's, what every module sees without naming a module, and `Address.call` is the prelude type's, written with the type's name, so the compiler sees all of them (the guide's §4).

Being the language buys what a library cannot: the function's type says which mailbox it runs in, so `spawn` types the address from the function and refuses the function for a mailbox of another type, where a `Subject` is a value a process makes and hands out, or that an actor's start answers.

What is the same is the types, Hindley-Milner as ML has it, which Gleam made ordinary on the Erlang runtime, and made well, in semantics and in syntax, and the look, which Ernest owes Gleam: `fn`, the pipe `|>`, the update `Con(..x, f = v)` and foreign declarations as the one door to Erlang follow it, its line comment was taken outright, and every other form of Gleam's was weighed against the design principles of report §0 and left out where it only gave a shorter way to write what the language already says (the guide's §11).

Nodes are the language too: a node lists its peers by their public keys, a spawn on a peer sends it the definitions it lacks, each known by a hash of its content, and a module keeps every version it has had (the guide's §8, report §8.7, report §11.2). A function generic in a type names what it needs of that type, `needs a.compare` (the guide's §7.3).

Ernest compiles to the Erlang runtime, OTP 29, and to nothing else. What Gleam has that Ernest lacks: a JavaScript target, packages from hex through `gleam add`, labeled arguments on a function, `use`, type aliases, a pattern on a string's prefix, `"inc " <> rest`, and a language server; its opaque type is Ernest's abstract type, and its record of functions the operations record. Gleam's author is named in the acknowledgments.

**Where are `gen_server` and the supervisors?**

In the language, as what they were made of. A server is a `receive` loop that keeps its state in its arguments, and a request carries a `Reply`, which `Address.call` waits on with a deadline (the guide's §4.4). Of what `gen_server` adds to the loop: `code_change` is the message of the process's own type that carries the new loop (the guide's §4.6); `terminate`'s work is the runtime's, since what a process opened ends with it (the guide's §8.7), and what the other side hears is a monitor's `Down` with the reason (the guide's §5.2); and `sys`, its suspend, its state read from outside and its trace, has nothing in its place, a shell beside the node being the operator's window (the deployment guide's §6).

A process that must come back runs its function under `restarting`, which runs the function again in the same process when it faults, so that the address holds; that is why there is no registry on a node: a service is a top-level binding that holds such an address, made when the program starts, in dependency order with every other binding (report §8.5), and good for its life (the guide's §6.5).

Past its restart limit the process ends, and the binding names an ended process for the rest of the run: `Address.call` to it answers `None` at once, and the program goes on unless a process that monitors the service acts on its end, by ending the program or by starting a new service (the guide's §6.5). A process that keeps something for the service, a lock granted to it, hears of each of its restarts through a service monitor, `monitorService` (the guide's §6.5).

A supervision tree is the standard library's `Supervisor`: a group with a strategy, `OneForOne`, `OneForAll` or `RestForOne`, and a restart limit, its children restarted in place with their addresses kept, and killed in the reverse of their order when the supervisor dies (the guide's §6.6, report Appendix E.22). A child joins the group when it starts, whenever that is, so there is no `simple_one_for_one`; and a child is killed, not asked to stop, so there is no shutdown timeout.

A sibling restarts only when it next waits, in a `receive` or for a call's answer, so a sibling that never waits is never restarted, and the child that faulted stays down until every sibling has reached a wait, a call to it answering `None` meanwhile (the guide's §6.6).

A process replaces its own code while it runs, by a message of its type that carries the new loop, keeping its address and its state (the guide's §4.6); it keeps its mailbox type for life, so a change of its messages is a new process. A module reloaded or brought by a peer runs beside its earlier versions (report §11.2).

Failure arrives as a message: a `monitor` is given a function of the watcher's, `wrap`, that turns the watched process's end, a `Down` with its reason, into a message of the watcher's own type, and there are no links, no exit signals and no exceptions; a process is ended from outside by `kill` alone, and by the program's end, and a worker that must end with its owner monitors it (the guide's §5.2, §5.3, the guide's §6). An Ernest program is not an OTP application, and the guide's §10 says, item by item, what an Erlang programmer finds in its place.

**Is this Unison on the Erlang runtime?**

It began there. Ernest's core was taken from Unison's: types inferred with signatures optional, sums and products with exhaustive matching, an effect written in a function's type, of which Ernest keeps one, what the function receives, structural equality with none on functions, and a definition known by the hash of its form.

What was left behind is Unison's concurrency, its abilities, its exceptions and its codebase manager, since Ernest keeps modules and files and takes Erlang's processes whole; the hash serves the exchange of code between nodes and a module's versions, not a store in place of files (the guide's §8, report §8.7, report §11.1). Unison runs a distributed program on Unison Cloud, its hosted service, or with its software on machines of your own; in Ernest the nodes are yours with no service between them, each listed in the other's `ernest.conf`. Unison's founders are named in the acknowledgments.

**Why one mailbox per process, and not several typed channels?**

A process receives values of one type, so every clause of a `receive` is checked against that type, and a clause that can never match is refused. A `receive` takes the first message a clause matches and leaves the others in the mailbox (the guide's §4.3).

A process that hears from several sources gives each an adapted address, `adapted(self(), Logged)`, `Logged` a constructor of the process's own type, which wraps that source's messages as they arrive, written where the reader sees it (the guide's §5.5, report §6.5).

The process's protocol is one type, read in one place, and where another language opens a second channel an Ernest process hands out such an address: a value, sent to whoever should write to it (the guide's §5.5). The gain over channels is not that the protocol is one type but that the type is in the function: the loop runs only in a process of that type, and the compiler sees it at the spawn.

Its cost is the library that waits on messages of its own: it runs a process of its own and is reached by a call, where a channel would be made in the caller's process (the guide's §4.4).

**Why does a function that receives say `receiving M`, while one that only sends says nothing?**

A `receive` reads the mailbox of the process the function runs in, and a mailbox takes messages of one type, so the function runs only in a process whose mailbox is of that type. `receiving M` is that fact in the function's type, and the compiler refuses to run the function anywhere else: as the function a `spawn` starts with a mailbox of another type, or as a guard, which runs while a message is selected (report §3.9, report §6.1).

A send needs no such fact. What it sends is in the address, `Address(M)`, and it reads nothing of the sender's mailbox; neither does a spawn, an answer, or a call, which waits on its reply and not on the caller's mailbox. So a function that only sends runs in any process, stands wherever one receiving `M` is expected, and says nothing, since a type carries what keeps messages safe and nothing of what a function does (report §0, principle 5).

**What does a typed mailbox catch, and what does it not?**

A message is checked at both ends against the mailbox's one type. A `receive` is checked against it, and a clause that cannot run is refused: in the counter of the guide's §4.1, `Inc(_) -> count(total)` after `Inc(amount)` is refused with `this clause can never match` (report §6.3). A `send` is checked against the type its address carries, and `send(counter, "increment")` is refused with `the argument does not fit send: expected CounterMsg, found String` (the guide's §0, report §6.5).

An address takes exactly its type and no smaller one. A client written to send only `Ticked`, a type whose one constructor is `Ticked`, is given an address of that type, `adapted(counter, fn(Ticked) = Inc(1))`, an `Address(Ticked)` whose messages reach the counter as `Inc(1)` (the guide's §5.5, report §6.5).

A `receive` need not cover its type, so a request of the mailbox's type that no clause takes compiles: it waits in the mailbox for good, and its caller's `Address.call` answers `None` at its deadline (the guide's §4.8).

Whether a reply is answered is not checked; the caller's call bounds its wait. A request carries a `Reply`, which is answered once: a second answer is no error the compiler sees, and is dropped as it runs, the caller keeping the first (the guide's §4.2, report §6.6). An answer never made is the next question.

**Is a forgotten answer caught?**

Not by the compiler: a reply is a value, kept, passed on or dropped as any value is (the guide's §4.2). What protects the caller is the call it chose. `Address.call` has a deadline, and answers `None` when it passes, which says that no answer came and nothing of why. Where the callee ends before it answers, the wait ends at once: `None` for `Address.call`, and for `Address.callForever` a fault, which ends the calling process with the callee's cause where the callee faulted, and otherwise with a cause that names how it ended; an answer that comes after the deadline is discarded (the guide's §6.3, report §6.6).

Where every process waits and nothing is in flight, the program ends with `Fault("deadlock")` (report §8.6). A node detects no deadlock, nor does the shell while it holds the terminal (report §11.2).

What nothing catches is `Address.callForever` on a callee that lives on and never answers: the caller waits for as long as the callee lives, which is why `callForever` is for a callee that always answers, a queue's `Take` among them (the guide's §4.4).

**How does Ernest talk to Erlang, and to the other languages on the runtime?**

Through `foreign fn` and `foreign type`, which are the one door: a `foreign fn` names a function of the host's, in any language the runtime runs, a library from hex among them, built by its own tools and given to `ern run`, `ern test` or `ern shell` with `--libs-dir dir`, which puts each `dir/*/ebin` on the load path (report §11.2), and declares its Ernest type, with nothing generated from the other side; a `foreign type` names a value Ernest holds without looking inside (the guide's §8.3, report §4.7).

The foreign side promises the declared types. A return value that breaks the promise faults the caller when the call returns, a check that walks the value and so costs with its size, and where a program hands an address to foreign code, a message the foreign side sends to it is checked on delivery, so that a compiled `receive` never sees a value of the wrong shape from it (report §8.4). A foreign function that delivers into its caller's own mailbox, declared `receiving M`, is trusted to deliver values of `M` alone, and nothing checks it (report §4.7).

The standard library stands on the host through such declarations (the guide's §8.5), and an Ernest program is otherwise written in Ernest: it is not an OTP application, no Erlang or Elixir module is built with it, and foreign code reaches it only through what the program hands it, an address or a function (report §8.4).

**What does "built for a WAN" mean?**

That two nodes on two networks are the ordinary case. Nodes talk over Erlang's own distribution, set up one way and not through its options: a node knows a peer by a name, a public key and an address in its own configuration, accepts a connection from a listed key alone, under the name that key gives it, and opens one TLS connection to a peer when an operation first needs it (report §8.3, the guide's §8.1).

There is no mesh, so a program's nodes talk where its configuration says and nowhere else; no port mapper, so one port per node is opened, the node's own carrier finding a peer by its listed address, which is also why a node of Erlang's own is no peer; and the key is the identity, so the configuration is the whole of what an operator reads to know who talks to whom ([the deployment guide](deployment.md)).

**How is code replaced in a running program, and why not old and new code?**

A process replaces its own loop by a message in its type that carries the new function, and switches with a tail call, so the replacement is a line of the program and the type says when it may arrive (the guide's §4.6, report §6.10).

A module reloaded in the shell gets a version beside its earlier ones, each named, so that a process still running the old version runs it to its end and a value of an old type prints as that version's (report §11.2). Nothing is purged: a version, once loaded, is held for the node's life, so the memory of a node that reloads without end grows with its versions, a limit the report states; the deployment guide's §4.2 says when a node is restarted.

Across nodes a definition is known by the hash of its form, so two nodes agree on a function by its content and not by a module's name, which in Erlang stands for whichever of its two loaded versions is current (report §8.7). A service's protocol evolves the same way: a service of a new message type is a new service, found by the new type's hash, and the old runs on for the finders built against it.

**Is there a type class, an interface or a trait?**

Not as a construct. A type's members are the functions declared under its name in its own module, `Int.compare`, so a type has one `compare`. A requirement names `compare`, `negate`, one of the six operators `+`, `-`, `*`, `/`, `%` and `<>`, or `show`, and nothing else. A function generic in `a` that needs it writes `needs a.compare`, and a call writes nothing, since the compiler supplies the type's own; code written once over several representations takes a record of functions the program declares, and `Operations(..Set)` fills each field from the declaration of its name in the module `Set` (the guide's §7.3).

The `needs` is written, never inferred, and no type is declared an instance of anything. What sets a requirement apart from a class is that its members are a closed set no program adds to, a type's own declared in its own module. All three stand in code under *Abstract types and requirements* in [Why Ernest](why.md), with the refusal of a type that lacks the member.

**Where are ETS, tracing, `observer`, back pressure and releases?**

A table is the library `Ets`, the host's table with Ernest types on it, owned by the process that made it and read and written by every process of its node (report Appendix G.1). There is no tracing and no `observer`: a shell started beside a node is the operator's window, each look through it a compute on the node (the deployment guide's §6). A shell does not attach to a running node: its inputs run on its own node.

In place of `global`, a service has one holder on each node that offers it, and a find answers the address offered by the first peer that offers it, in the order the configuration lists them (the guide's §8.2). In place of `pg`, a group of processes across nodes is the program's own, a process that keeps their addresses.

A mailbox is unbounded, as Erlang's is, and back pressure is the program's, a credit the receiver grants or a call, since a full mailbox that held a sender would hold a caller waiting on that sender's reply, and the two would wait for good. A release of a program is its `.erc` files beside `ern`, which `ern build` writes and the deployment guide's §1 and §5 run.

**Why `fn(x) = ...` for a lambda, and not `x -> ...`?**

It begins with `fn`, so a reader and the parser see a lambda begin at its first word. A function's number of arguments is part of its type, and `fn(x, y)` shows it where the lambda is written, in the form a declaration and a call already have (report §5.3).

**Why is the compiler so strict, and why does it give no warnings?**

A program builds or it does not, so that a program that builds meets every rule, and its reader knows which rules those are. A warning would be a rule the compiler states and does not hold, and a program built with warnings one whose author decided each, or did not, which its reader cannot tell.

The rules are few, and each catches a mistake concurrent programs are prone to: a message of a type the process does not take, a value a statement drops without `let _`, a failure among them (the guide's §0), and a constructor a `match` leaves out (the guide's §2.3).

What is a habit of style the compiler leaves alone: `ern format` lays the code out, and the reader's eye does the rest.
