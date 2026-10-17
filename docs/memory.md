# Memory

How the project checks that nothing grows with the work done: the loads that measure it, the reading that looks for it, what each kind of memory is kept for and what lets it go, and how a growth is traced to its cause. The rule is CLAUDE.md's *Memory that no collection reclaims is a defect*. [`release_review.md`](release_review.md) says when the loads run, and [`architecture.md`](architecture.md) how each table is keyed.

## The loads

`make load` runs each load in an Erlang node of its own. It prints each load's samples and whether it stayed flat, and writes the same to `test/build/load/<load>.txt`. It takes about 110 seconds (measured 2026-09-30).

A load does the same work in each of fourteen rounds and calls `mark(round)` after each, a `foreign fn` of `test/ern_load.erl`. The programs are under `test/fixtures/load/`; the harness writes the shell's session.

| Load | Each round |
|---|---|
| `processes` | 300 times: a call answered; a callee monitored and killed; a call answered after its time, and one never answered; a process that faults, watched from its start; a short-lived process that watches a service which outlives it; a subscription to faults that ends with its process |
| `supervisors` | 100 times: a child of a `OneForOne` group and one of a `OneForAll` group fault and restart in place, each then answering a call; a child joins and returns |
| `sockets` | 200 connections to an echo server, one message each way, a read that times out, then closed |
| `programs` | 20 times: `Os.run` of `cat` and of a program not found; `Os.start` of `sleep` killed; one that runs past its time |
| `files` | 100 times: a file written, appended, read, stated, copied, listed, renamed and removed |
| `alarms` | 500 times: an alarm after a millisecond and one at the time now, each taken, and a wait that times out |
| `shell` | 101 inputs at the prompt in line mode: expressions, `let`s, a function as a value, a value of a type, output, a process spawned, and `:type`, `:bindings`, `:doc` and `:faults`; the function, the type and what the process runs are declared once, before the first round, since an input that declares is kept while the session runs |

`mark` waits until what the round set going has ended, collects every other process's garbage, and samples the node at rest. Its comments give the steps, and the one chosen wait, 100 milliseconds for the host to count the heaps it freed, which nothing the host reports shows (the log's *A Load Samples a Node at Rest* and *The Tests Wait on What They Mean*). A sample holds:

- `memory`, the node's memory in use, without the harness's own and the unused words of every heap;
- `code`, the loaded code's memory;
- `reaper`, the memory of the runtime's reaper, which holds every wait on a process (report §6.9);
- `atoms`, `procs` and `ports`, the node's counts;
- `rows`, the rows of the runtime's tables, `ern_rt:tables()`, and of the code table, `ern_code`;
- `terms`, the persistent terms.

The first six rounds are the warm-up, in which heaps, caches and windows settle, the supervisors' restart window of a second among them. From the seventh on:

- the code, the atoms, processes, ports, rows, persistent terms and the reaper's memory may not grow at all, the last sample against the first;
- the node's memory may not grow by more than 128 KB, the mean of the last three samples against the mean of the first three.

On loads that leak nothing the memory varies by about 15 KB either way, and a leak of about a hundred bytes an operation passes the bound over a load's eight counted rounds. A load that grew prints what grew and by how much, and `make load` fails.

## Reading the code

The loads show only what they exercise, so the code is read too, for what a long-lived process, a table or a persistent term keeps, and when it lets it go:

- a table row, a persistent term, or an entry in the process dictionary, and what removes it;
- a map or a list in a long-lived process's loop state, the runtime's system processes, the reaper and the shell's session among them;
- anything kept for one process by another, a monitor, a subscription, a waiting request, a call's row, and whether it goes when the first one dies, not only when the second does;
- a module or an atom made for an input at the prompt, and whether it is given back;
- in Ernest, a service's state that grows with its requests, as a store without expiry would.

## What is kept, and what lets it go

Something may be kept as long as a program holds what it stands for: a socket until `Tcp.close`, a running program until it has answered its exit status, a checker (report §8.4) for as long as the process behind it (the log's *A Check at the Boundary Lasts as Long as Its Process*). What nothing can use again is a defect. A limit the report states, as §11.2's history of a thousand inputs, is a rule and not a cap.

### The host's code and atoms

**The host's code.** OTP keeps an entry for each lambda of each distinct version of a module it loads, for as long as the node lives. It shows as `code` that rises with every new version of a module, and not with a version loaded again. New versions come from the shell's inputs and loads, from code that arrives from peers, and from `Code.load`. The log's *The Shell's Code Memory* has the figures.

**The host's limits.** The host's counts of module names, export entries, lambdas and atoms never fall, and each has a limit, which the runtime says a load nears and which no load passes (report §11.2). The runtime watches them by sums kept beside the code table, a row a count in `ern_code_sums`.

**Atoms.** The host never frees an atom, so what makes one is read for as well as counted. A running program makes none from what it is given. The shell makes them of the inputs it runs, and none of text that is typed and not run. The log's *Atoms, Counted* has what each costs.

### The shell

- An input that declares nothing and builds no function value is unloaded once it has its answer (report §11.2).
- An input that declares, or builds a function value, is kept while the session runs (report §11.2).
- Such an input costs about 24 KB and two atoms where it declares a function, and about 8 KB and the same two where it binds a lambda, the atoms its namespace's and its unit's (measured 2026-10-12 over 2,000 inputs of each). Its definitions make none, since a unit's functions are named by their position.
- A holder, a session module that holds what inputs bound, is kept while a name in the session's scope, or an input the session keeps, reaches it. The session collects once an input has answered and at each `:forget`, and lets go of an unreached holder's values, code, interface and number (`ern_shell:collected/1`, [`design/shell.md`](design/shell.md)).
- `:load` and `:reload` unload nothing while the session runs: each version's unit, its bindings' values, and the interface of every type a reload changed, under its previous version's namespace, are kept for the session's life, by design (report §11.2; the log's *The Shell's Reload by Hash, Built*). The host's limits bound the units, and the session says when it nears one.
- A unit a refused load brought stays, out of reach (report §11.2). The same module refused again makes no unit.

### A node's tables (report §8.7)

- An offer's rows in `ern_offers` and `ern_offered` go when its process ends, which the reaper sees for a process the runtime started or opened, and watches for in any other.
- `ern_initialized` holds a row for each unit whose initializers a run or a load has run, which the build and the session's loads bound.
- The utilization a program set is one row of `ern_launch`, each set in place of the last, for the launch's life.
- The note of a call from another node, in `ern_notes` and `ern_callees`, goes at an answer given on this node, the callee's restart or end, the caller's second note, or the loss of the caller's node. The call sends the second note wherever it ends otherwise, its caller's end among them.

### The gateway and its peers (report §8.7)

- A spawn's row in `ern_spawns` goes when its answer comes, when the spawner gives up, or at a loss of the peer's connection that the gateway learned of after the row was written. A later answer ends its process.
- `ern_utilizations` holds a row for each peer that told the node its utilization, a later telling in its place, until that peer's connection is lost: at most a row for each peer the configuration lists.
- The gateway holds one timer, of its next telling, while the node lists peers.
- A worker for each peer that sent a frame lives until that peer's connection is lost and the worker holds no frame and no kept process.
- A process kept for an adapted address and a peer that sends to it lives until no message of that peer's to the address waits.
- A monitored spawn's process waits on the peer until its spawner has made the monitor or has ended.

### The code table

- A unit's rows stay until the unit is loaded again with other code or unloaded, as the shell unloads an input's.
- A unit no file holds, a load's, a shell input's or an arrival's, keeps what its compiled form records, its forms among it, in a row of its own for as long as its other rows (report §11.2).
- A build's unit's forms are read from its `.erc` at the first request of an exchange that needs them, and kept from then on for as long as the unit, which is the node's life (report §11.2). The build bounds them: the standard library's 27 units' forms, all read, take 2,425,824 bytes in the table, about 25 times their compressed chunks, `Terminal`'s 588 KB the largest (measured 2026-10-12, the same in seven runs; the log's *The Report for Code with a Spawn*).

### Code from peers

- The node's `ern_exchange` holds each exchange it asked a peer for, with the code frames it verified, apart from the code table (report §8.7). It goes once the reach is received, made a unit and loaded, or refused with its reason; once the reach answers `NotLoaded`, or that the spawner's node no longer holds it, at the request or at the lacks; once a frame of that peer's is faulty; and at that peer's loss.
- No time of its own bounds an exchange. A peer that stopped answering without its connection ending would hold it until the loss, which a peer's exchange, answering every frame, gives no cause for.
- As the spawner's node, `ern_exchange` keeps nothing between a peer's frames.
- `ern_exchange` keeps the prelude's environment, built at its first arrival, and its pool's count for the node's life, since neither the prelude nor the standard library changes while it runs.
- An arrival's unit and its row of forms are held for the node's life, as every unit is (report §11.2; the log's *The Report for Code with a Spawn*, and *A let-go of a node's units* under its *Later*).
- A node sent code without end holds each definition once, in the unit of the exchange that brought it, so it grows with the exchanges that bring it distinct definitions and the definitions they bring, not with its spawns or its time.
- An arrival adds one module name and an atom, an export entry for each function it holds and four more, and a function entry for each lambda (measured 2026-10-12 by `make bench`).

### `Code.load`

- A unit `Code.load` makes is held for the node's life, as every unit is (report §11.2, Appendix E.28). A module of twenty functions, each with a lambda, and a binding adds one module name, two atoms, twenty-five export entries and twenty function entries (measured 2026-10-12 by `make bench`).
- A module loaded again, unchanged, makes no unit: its code is the node's, or a unit an earlier load made from the same forms (`ern_code:unit_beside/2`).
- A load whose binding faulted keeps its units, out of reach, with their bindings' values erased and the processes it started killed (Appendix E.28).
- The run's load path, which `Code.load` reads, is one persistent term, replaced at each run's start (`ern_cli:load_path/0`).
- The rows of the processes a load's evaluation starts carry a mark in place of their root only while it runs, and take the root back as it ends.

## Tracing a growth

- **One kind at a time.** The same input a hundred times at the prompt, between two readings of `erlang:system_info(atom_count)` through `foreign fn info(k : Foreign.Term) : Int = "erlang:system_info/1"`, one kind of input a run.
- **A longer run.** The load edited to forty rounds and run through `ern_cli:ern(["run", ...])`, with the table `ern_load_samples` made by hand, tells settling from growth.
- **One process's memory.** A column for the suspected process, as `reaper` was added, shows a growth that the node's total hides in its variation.
- **Every process at each sample.** Each process's memory and heap sizes (`erlang:process_info(P, garbage_collection_info)`) written at each sample, beside the kinds of `erlang:memory()` at the sample and a moment after. A heap that steps between two sizes is a swing and not a growth; a kind that differs only at the sample is the host's lag.
- **Same and distinct.** The same input a hundred times against a hundred inputs that each differ, `1 + 1` against `1 + n`, between two readings of `erlang:memory(code)`: a cost of the distinct ones alone is a cost per version of the code. One module loaded, deleted and purged in a loop in plain Erlang tells the host's cost from the program's.
- **With and without.** The fix set aside, a copy of the file kept and the committed file restored, since the checkout is shared, then rebuilt and the load run again beside the run with it: the difference is the fix's. A regression test is checked the same way, and fails without the fix.

A growth found becomes a regression test in `make test-full` where one can show it in seconds:

- `declarations_kept_while_reached_test_`, `expressions_leave_no_code_test_` and `expressions_again_leave_no_code_test_` in `test/ern_shell_tests.erl`;
- `monitors_let_go_test` in `erl/emitter/test/ern_reaper_tests.erl`, and `tellers_leave_no_monitor_test` in `erl/emitter/test/ern_terminating_tests.erl`;
- `work_makes_no_atoms_test_` in `erl/emitter/test/ern_emitter_tests.erl`;
- the editor's `lastThousand` in `src/shell/shell/editor.ern`.

## Adding a load

A new system module, a new long-lived process, or a new kind of state the shell keeps gets a load, or a line in an existing one, and a row in the table above. A load is an Ernest program under `test/fixtures/load/`, named for what it loads and not for a module of the standard library, whose namespaces a program may not take. It declares `mark`, does the same work in each of its fourteen rounds, and is added to `LOADS` in `test/Makefile`.

A round that sets work going for later waits for it before it marks, as the supervisors' load waits out its restart window. A sample that meets a delivery on its way counts a process and a row more than the node holds at rest (the log's *The Supervisors Load Sampled at Rest*).

## What the loads leave out

The loads leave out the terminal's keys, which need a terminal; the shell at a terminal, whose editor and screen the line-mode session does not reach; peers, whose calls were measured by hand and left nothing on the callee's node (the log's *Nodes a Failed Test Left Running*); and checkers, which are kept by design. Each is read for instead.

Growth with time rather than with work, and the examples' own programs, were measured by a soak of hours until it was removed on 2026-10-02 (the log's *MVP 2.99b Read After the Review*). `examples/web_server.ern`'s session store, which forgets its sessions every ten minutes, is bounded by design, and its path through the runtime is the `sockets` load's (the log's *MVP 2.99b's Questions, One by One*). A program that grows over hours brings the soak, or a load, back with that evidence.
