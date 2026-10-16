# Frequently asked questions

The questions a reader of [*Programming in Ernest*](language.md) brings, each answered by what Ernest does, with the section that states it. [Why Ernest](why.md) is the argument the answers rest on.

**It looks like Gleam. What differs?**

The types are the same family, Hindley-Milner as ML has it, which Gleam made ordinary on the Erlang runtime, and made well, in semantics and in syntax. Ernest owes Gleam its look: `fn`, the pipe `|>`, the update `Con(..x, f = v)` and foreign declarations as the one door to Erlang follow it, its line comment and `todo` were taken outright, and every other form was weighed on the five principles and left out where it only shortened (the guide's §11).

Gleam's typed messaging is a library over the runtime's processes, well made too. What differs is how far the types reach, since in Ernest the process is the language: a function that receives names its mailbox's type, a `receive` is checked against it, every `send` against the address it reaches, a request carries its `Reply`, and `spawn`, `monitor` and `Address.call` are the prelude's, so the compiler sees all of them (the guide's §4).

Nodes are the language too: a node lists its peers by key, a spawn carries code by its hash to a peer that lacks it, and a module keeps every version it has had (the guide's §8, report §8.7, report §11.2). A function generic in a type names what it needs of that type, `needs a.compare` (the guide's §7.3). Ernest compiles to the Erlang runtime, OTP 29, and to nothing else. Gleam's author is named in the acknowledgments.

**Where are `gen_server` and the supervisors?**

In the language, as what they were made of. A server is a `receive` loop that keeps its state in its arguments, and a request carries its `Reply`, which `Address.call` waits on with a deadline (the guide's §4.4). A process that must come back is started with `restarting`, which restarts it in place so that its address holds, and that is why there is no registry: a service is a top-level binding that holds the address, made once and good for the program's life (the guide's §6.5). A supervision tree is the standard library's `Supervisor`, its children restarted in place (the guide's §6.6).

A process replaces its own code while it runs, by a message of its type that carries the new loop, keeping its address and its state (the guide's §4.6), and a module reloaded or brought by a peer runs beside its earlier versions (report §11.2). In a rolling upgrade the messages a process has not yet taken move with the work: `Mailbox.drained(keep)` takes them from its mailbox in arrival order, as a list, and the new process puts them into its own with `Mailbox.refilled(messages)`, behind what it already holds; the library is MVP 3.3's, planned with the tour and not yet written.

Failure arrives as a message: a `monitor` delivers a `Down` of the mailbox's own type, and there are no links, no exit signals and no exceptions (the guide's §5.2, the guide's §6). An Ernest program is not an OTP application, and the guide's §10 says, item by item, what an Erlang programmer finds in its place.

**Is this Unison on the Erlang runtime?**

It began there. Ernest's core was taken from Unison's: types inferred with signatures optional, sums and products with exhaustive matching, a type that tells code that only computes from code that acts, structural equality with none on functions, and a definition known by the hash of its form.

What was left behind is Unison's concurrency, its abilities, its exceptions and its codebase manager, since Ernest keeps modules and files and takes Erlang's processes whole; the hash serves the exchange between nodes and a module's versions, not a store in place of files (the guide's §8, report §8.7, report §11.1). Unison runs a distributed program on Unison Cloud, its hosted service or, since October 2025, its software on machines of your own; in Ernest the nodes are yours with no service between them, each listed in the other's `ernest.conf`.

The idea has an older parent on this runtime. Joe Armstrong asked the Erlang list in May 2011 [why modules are needed at all](https://erlang.org/pipermail/erlang-questions/2011-May/058768.html): "all functions have unique distinct names", and "all functions go into a global (searchable) Key-value database". At the Erlang User Conference in 2012, in *A Few Improvements to Erlang*, he said "I don't like modules. It's a sort of love/hate relationship. The problem with modules is the classification problem", and "If you look at something like git, the way you deal with time is checksum, timestamp".

Unison names Erlang among its influences, and stands on parents of its own: a thing known by the hash of its content is Git's and Nix's, and its abilities are Frank's, Eff's and Koka's, from the last of which Ernest takes the form of its effect subsumption (the guide's §3.5). Unison's founders are named in the acknowledgments.

**Why one mailbox per process, and not several typed channels?**

A process receives values of one type, so a `receive` is a `match` over that type and the compiler can say what is left out. A process that hears from several sources gives each an adapted address, `adapted(self(), Logged)`, which turns that source's messages into the process's own as they arrive, written where the reader sees it (the guide's §4.1, report §6.5). The process's protocol is one type, read in one place, and a channel is a value: a list of messages, sent anywhere.

**Why does a function that receives say `receiving M`, while one that only sends says nothing?**

A `receive` reads the mailbox of the process the function runs in, and a mailbox takes messages of one type, so the function runs only in a process whose mailbox is of that type. `receiving M` is that fact in the function's type, and the compiler refuses to run the function anywhere else: as the function a `spawn` starts with a mailbox of another type, or as a guard, which runs while a message is selected (report §3.9, report §6.1). A send needs no such fact. What it sends is in the address, `Address(M)`, and it reads nothing of the sender's mailbox; neither does a spawn, an answer, or a call, which waits on its reply and not on the caller's mailbox. So a function that only sends runs in any process, stands wherever one receiving `M` is expected, and says nothing, since a type carries what keeps messages safe and nothing of what a function does (report §0, principle 5).

**Is a forgotten answer caught?**

Not by the compiler: a reply is a value, kept, passed on or dropped as any value is (the guide's §4.2). The caller is caught by what it chose. `Address.call` has a deadline, and answers `None` when it passes, which says that no answer came and nothing of why. Where the callee ends before it answers, the wait ends at once: `None` for `Address.call`, and for `Address.callForever` a fault that names how the callee ended (report §6.6). Where every process waits and nothing is in flight, the program ends with `Fault("deadlock")` (report §8.6). What nothing catches is `Address.callForever` on a callee that lives on and never answers: the caller waits for as long as the callee lives, which is why `callForever` is for a callee that always answers, a queue's `Take` among them (the guide's §4.4).

**How does Ernest talk to Erlang, and to the other languages on the runtime?**

Through `foreign fn` and `foreign type`, which are the one door: a `foreign fn` names a function of the host's, in any language the runtime runs, a library from hex among them, and declares its Ernest type, with nothing generated from the other side; a `foreign type` names a value Ernest holds without looking inside (the guide's §8.3, report §4.7).

The foreign side promises the declared types. A return value that breaks the promise faults the caller when the call returns, and a message from foreign code is checked by a process the runtime puts in front of the exposed address, so that a compiled `receive` never sees a value of the wrong shape (report §8.4).

The standard library stands on the host through such declarations (the guide's §8.5), and an Ernest program is otherwise written in Ernest: it is not an OTP application and is not mixed with another language's modules.

**What does "built for a WAN" mean?**

That two nodes on two networks are the ordinary case. The carrier is Erlang's own distribution, run under one rule and not under its options: a node knows a peer by a name, a public key and an address in its own configuration, accepts a connection from a listed key alone, under the name that key gives it, and opens one TLS connection to a peer when an operation first needs it (report §8.3, the guide's §8.7).

There is no mesh, so a program's nodes talk where its configuration says and nowhere else; no port mapper, so one port per node is opened; and the key is the identity, so the configuration is the whole of what an operator reads to know who talks to whom ([the deployment guide](deployment.md)).

**How is code replaced in a running program, and why not old and new code?**

A process replaces its own loop by a message in its type that carries the new function, and switches with a tail call, so the replacement is a line of the program and the type says when it may arrive (the guide's §4.6, report §6.10).

A module reloaded in the shell gets a version beside its earlier ones, each named, so that a process still running the old version runs it to its end and a value of an old type prints as that version's (report §11.2). Nothing is purged: a version, once loaded, is held for the node's life, so the memory of a node that reloads without end grows with its versions, a limit the report states.

Across nodes a definition is known by the hash of its form, so two nodes agree on a function by its content and not by a module's name and a count of two (report §8.7).

**Is there a type class, an interface or a trait?**

No. A function that needs an operation of a type it is generic in names the type's member, `needs a.compare`, and a call writes nothing, since a type has one `compare` and the compiler supplies it; code written once over several representations takes a record the program declares and fills from a representation's module, `Operations(..Set)` (the guide's §7.3). Nothing is inferred and nothing is declared an instance.

**Why `fn(x) = ...` for a lambda, and not `x -> ...`?**

It begins with `fn`, so a reader and the parser see a lambda begin at its first word. A function's number of arguments is part of its type, and `fn(x, y)` shows it where the lambda is written, in the form a declaration and a call already have.

**Why is the compiler so strict, and why does it give no warnings?**

A warning is a rule the compiler states and does not hold, so a program that builds with warnings is one whose author decided each, or did not, and its reader cannot tell which. Ernest gives one answer, a program builds or it does not, so that a program that builds meets every rule, and its reader knows which rules those are. The rules are few, and each catches a mistake concurrent programs are prone to: a message of a type the process does not take, a failure dropped (the guide's §0), a constructor a `match` leaves out, a value discarded without `let _` (the guide's §11). What is a habit of style the compiler leaves alone: `ern format` lays the code out, and the reader's eye does the rest.
