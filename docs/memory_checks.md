# Memory

How the project checks that nothing grows with the work done: the loads that measure it, the reading that looks for it, what the host keeps, with where the design notes say what each component keeps and what lets it go, and how a growth is traced to its cause. The rule: memory that no collection reclaims is a defect. [`reviews/release.md`](reviews/release.md) says when the loads run, and [`architecture.md`](architecture.md) how each table is keyed.

## The loads

`make load` runs each load in an Erlang node of its own. It prints each load's samples and whether it stayed flat, and writes the same to `test/build/load/<load>.txt`. It takes about a minute (measured 2026-11-08 on nike).

A load does the same work in each of fourteen rounds and calls `mark(round)` after each, a `foreign fn` of `test/ern_load.erl`. The programs are under `test/fixtures/load/`; the harness writes the shell's session.

| Load | Each round |
|---|---|
| `processes` | 300 times: a call answered; a callee monitored and killed; a call answered after its time, and one never answered; a process that faults, watched from its start; a short-lived process that watches a service which outlives it; a subscription to faults that ends with its process; a capture that returns, and one whose caller faults inside it |
| `supervisors` | 100 times: a child of a `OneForOne` group and one of a `OneForAll` group fault and restart in place, each then answering a call; a child joins and returns |
| `sockets` | 200 connections to an echo server, one message each way, a read that times out, then closed |
| `programs` | 20 times: `Os.run` of `cat` and of a program not found; `Os.start` of `sleep` killed; one that runs past its time |
| `files` | 100 times: a file written, appended, read, stated, copied, listed, renamed and removed |
| `alarms` | 500 times: an alarm after a millisecond and one at the time now, each taken, and a wait that times out |
| `shell` | 101 inputs at the prompt in line mode: expressions, `let`s, a function as a value, a value of a type, output, a process spawned, and `:type`, `:bindings`, `:doc` and `:faults`; the function, the type and what the process runs are declared once, before the first round, since an input that declares is kept while the session runs |

`mark` waits until what the round set going has ended, collects every other process's garbage, and samples the node at rest. Its comments give the steps, and the one wait that is a time, the host timer's millisecond, in which the schedulers go idle and the host counts the heaps it freed, which nothing the host reports shows (the log's *A Load Samples a Node at Rest* and *The Tests Wait on What They Mean*). A sample holds:

- `memory`, the node's memory in use, without the harness's own and the unused words of every heap;
- `code`, the loaded code's memory;
- `reaper`, the memory of the runtime's reaper, which holds every wait on a process (report §6.9);
- `atoms`, `procs` and `ports`, the node's counts;
- `rows`, the rows of the runtime's tables, `ern_rt:tables()`, and of the code table, `ern_code`;
- `terms`, the persistent terms.

The first six rounds are the warm-up, in which heaps, caches and windows settle, the supervisors' restart window of a second among them. The sockets load runs on one scheduler, since on more a stack of the host's socket buffers can fill after the warm-up, and on one its one stack holds what each round has outstanding (*Socket buffers* below). From the seventh round on:

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

Something may be kept as long as a program holds what it stands for: a socket until `Tcp.close`, a running program until it is killed, `Os.run`'s once it has read the exit status, a checker (report §8.4) for as long as the process behind it (the log's *A Check at the Boundary Lasts as Long as Its Process*). What nothing can use again is a defect. A limit the report states, as §11.2's history of a thousand inputs, is a rule and not a cap.

What each component keeps, and when it lets it go, is its design note's, which a reading of the code reads it against: the shell's session, its inputs and its front end's table, [`design/shell.md`](design/shell.md)'s; a process's own, the runtime's tables and the persistent terms, [`design/runtime.md`](design/runtime.md)'s *What the runtime keeps, and where*, with a load's evaluator in its *The process model*; the gateway's rows, the peers' workers, the notes of calls and the offers, [`design/nodes.md`](design/nodes.md)'s; and the code table, the exchange, the arrivals and what a load brings, [`design/code.md`](design/code.md)'s. What the host keeps beneath them is this document's.

### What the host keeps

**The host's code.** OTP keeps an entry for each lambda of each distinct version of a module it loads, for as long as the node lives. It shows as `code` that rises with every new version of a module, and not with a version loaded again. New versions come from the shell's inputs and loads, from code that arrives from peers, and from `Code.load`. The log's *The Shell's Code Memory* has the figures.

**The host's limits.** The host's counts of module names, export entries, lambdas and atoms never fall, and each has a limit, which the runtime says a load nears and past which the host ends the node (report §11.2). The runtime watches them by sums kept beside the code table, a row a count in `ern_code_sums`.

**Atoms.** The host never frees an atom, so what makes one is read for as well as counted. A running program makes none from what it is given. The shell makes them of the inputs it runs, and none of text that is typed and not run. The log's *Atoms, Counted* has what each costs.

**Socket buffers.** The host's inet driver keeps up to 14 released receive buffers on each scheduler, of 9,216 bytes each and 1 MiB at most, for the next reads of any socket. No process references them, so they show as `binary` memory that a collection leaves, up to about 130 KB a scheduler, 3 MB on 24 schedulers. A buffer released on another scheduler than the one that took it moves between their stacks, so a stack fills once the host first gives its scheduler a socket's work, which may come at any time (the log's *The Sockets Load on One Scheduler*).

## Tracing a growth

- **One kind at a time.** The same input a hundred times at the prompt, between two readings of `erlang:system_info(atom_count)` through `foreign fn info(k : Foreign.Term) : Int = "erlang:system_info/1"`, one kind of input a run.
- **A longer run.** The load edited to forty rounds and run through `ern_cli:ern(["run", ...])`, with the table `ern_load_samples` made by hand, tells settling from growth.
- **One process's memory.** A column for the suspected process, as `reaper` was added, shows a growth that the node's total hides in its variation.
- **Every process at each sample.** Each process's memory and heap sizes (`erlang:process_info(P, garbage_collection_info)`) written at each sample, beside the kinds of `erlang:memory()` at the sample and a moment after. A heap that steps between two sizes is a swing and not a growth; a kind that differs only at the sample is the host's lag.
- **Same and distinct.** The same input a hundred times against a hundred inputs that each differ, `1 + 1` against `1 + n`, between two readings of `erlang:memory(code)`: a cost of the distinct ones alone is a cost per version of the code. One module loaded, deleted and purged in a loop in plain Erlang tells the host's cost from the program's.
- **One process's binaries.** `Process.status` counts them with no scan (report Appendix E.21), and `process_info(Pid, binary)` lists them. A wait for them to go reads after a traced collection (`ern_waits:freed/2`), and not in a loop. A new process's small heap is collected as soon as it fills, so a test of what a waiting process holds gives its processes room (`ern_waits:with_room/1`).
- **With and without.** The fix set aside, a copy of the file kept and the committed file restored, since the checkout is shared, then rebuilt and the load run again beside the run with it: the difference is the fix's. A regression test is checked the same way, and fails without the fix. A file put back takes a new modification time, since `make` goes by time and would keep the beam built without the fix, and each case starts from a run that passes, since a beam left over fails the next case for the wrong reason.

A growth found becomes a regression test in `make test-full` where one can show it in seconds:

- `declarations_kept_while_reached_test_`, `expressions_leave_no_code_test_` and `expressions_again_leave_no_code_test_` in `test/ern_shell_tests.erl`;
- `monitors_let_go_test` in `src/toolchain/emitter/test/ern_reaper_tests.erl`, and `tellers_leave_no_monitor_test` in `src/toolchain/emitter/test/ern_terminating_tests.erl`;
- `work_makes_no_atoms_test_` in `src/toolchain/emitter/test/ern_emitter_tests.erl`;
- `kept_tables_stay_bounded_test` in `src/runtime/test/ern_rt_tests.erl`, and `tls_connection_hibernates_test` in `src/runtime/test/ern_tcp_tests.erl`;
- the editor's `lastThousand` in `src/shell/ernest/shell/editor.ern`.

## Adding a load

A new system module, a new long-lived process, or a new kind of state the shell keeps gets a load, or a line in an existing one, and a row in the table above. A load is an Ernest program under `test/fixtures/load/`, named for what it loads and not for a module of the standard library, whose namespaces a program may not take. It declares `mark`, does the same work in each of its fourteen rounds, and is added to `LOADS` in `test/Makefile`.

A round that sets work going for later waits for it before it marks, as the supervisors' load waits out its restart window. A sample that meets a delivery on its way counts a process and a row more than the node holds at rest (the log's *The Supervisors Load Sampled at Rest*).

## What the loads leave out

The loads leave out the terminal's keys, which need a terminal; the shell at a terminal, whose editor and screen the line-mode session does not reach; peers, whose calls were measured by hand and left nothing on the callee's node (the log's *Nodes a Failed Test Left Running*); and checkers, which are kept by design. Each is read for instead.

Growth with time rather than with work, and the examples' own programs, were measured by a soak of hours until it was removed on 2026-10-02 (the log's *MVP 2.99b Read After the Review*). `examples/web_server.ern`'s session store, which forgets its sessions every ten minutes, is bounded by design, and its path through the runtime is the `sockets` load's (the log's *MVP 2.99b's Questions, One by One*). A program that grows over hours brings the soak, or a load, back with that evidence.
