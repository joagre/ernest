# Memory

How the project checks that nothing grows with the work done: the loads that measure it, the reading that looks for it, and the ways a growth is traced to its cause. The rule is CLAUDE.md's *Memory that no collection reclaims is a defect*; [`release_review.md`](release_review.md) says when the loads run.

## The loads

`make load` runs each load in an Erlang node of its own and prints its samples and whether it stayed flat, which it also writes to `test/build/load/<load>.txt`. It takes about 110 seconds (measured 2026-09-30).

A load does the same work in each of fourteen rounds and calls `mark(round)`, a `foreign fn` of `test/ern_load.erl`, after each. The programs are under `test/load/`; the shell's session is written by that harness.

| Load | Each round |
|---|---|
| `processes` | 300 times: a call answered; a callee monitored and killed; a call answered after its time, and one never answered; a process that faults, watched from its start; a short-lived process that watches a service which outlives it; a subscription to faults that ends with its process |
| `supervisors` | 100 times: a child of a `OneForOne` group and one of a `OneForAll` group fault and restart in place, each then answering a call; a child joins and returns |
| `sockets` | 200 connections to an echo server, one message each way, a read that times out, then closed |
| `programs` | 20 times: `Os.run` of `cat` and of a program not found; `Os.start` of `sleep` killed; one that runs past its time |
| `files` | 100 times: a file written, appended, read, stated, copied, listed, renamed and removed |
| `alarms` | 500 times: an alarm after a millisecond and one at the time now, each taken, and a wait that times out |
| `shell` | 101 inputs at the prompt in line mode: expressions, `let`s, a function and a type declared again under the same names, a function as a value, output, a process spawned, and `:type`, `:bindings`, `:doc` and `:faults` |

`mark` waits for what the round set ending: each process the runtime still lists that is no longer alive, by a monitor; then the reaper, idle, having taken their ends; then every delivery it started, a `Down` among them, by a monitor each. A load whose round sets work for later rests until that work is done before it marks: the supervisors' load sets an alarm for each fault, a second on, which a process of its own delivers, and waits its restart window first, since a sample that catches a delivery on its way counts a process and a row more than the node holds at rest. It then waits while a process of the harness's own collects every other process's garbage, gives the host 100 milliseconds to count the heaps the collections freed, the one chosen time in the harness, since nothing the host reports shows it (the log's *The Tests Wait on What They Mean*), and samples:

- `memory`, the node's memory in use: what the processes and the system use, less the harness's own table and process and the words of every heap that hold nothing. The structures the host keeps for processes to come are not in use;
- `code`, the loaded code's;
- `reaper`, the memory the runtime's reaper holds, which holds every wait on a process, collected again just before it is read, since a message it takes after the first collection leaves words in its heap that the next collection frees, and read until two readings in a row agree, since the reaper wakes to look for a deadlock (§8.6), once a second while a load samples, and a look that falls between a collection and its reading leaves words that count as held;
- `atoms`, `procs` and `ports`, the node's counts;
- `rows`, the rows of the runtime's thirteen tables, `ern_processes`, `ern_calls`, `ern_callees`, `ern_faults`, `ern_held`, `ern_deliveries`, `ern_restarts`, `ern_proxies`, `ern_launch`, `ern_offers`, `ern_offered`, `ern_initialized` and `ern_notes`;
- `terms`, the persistent terms.

The first six rounds are the warm-up, in which heaps, caches and windows settle, the supervisors' restart window of one second among them. From the seventh on:

- the code, the atoms, processes, ports, rows, persistent terms and the reaper's memory may not grow at all, the last sample against the first;
- the node's memory may not grow by more than 128 KB, the mean of the last three samples against the mean of the first three. On loads that leak nothing it varies by about 15 KB either way, and a leak of about a hundred bytes an operation passes the bound over a load's eight counted rounds.

A load that grew prints what grew and by how much, and `make load` fails.

**The host's code.** OTP keeps an entry for each lambda of each distinct version of a module it loads, for as long as the node lives, up to a limit that stops the node. It shows as `code` that rises with every new version of a module, and not with a version loaded again. New versions come from the shell's inputs and declarations, and in MVP 3.0 from code shipped between peers; the log's *The Shell's Code Memory* has the figures and weighs it.

**Atoms.** The host never frees an atom and stops a node when it has made too many, so what makes one is read for as well as counted: a running program makes none from what it is given, and the shell makes them of the inputs it runs and none of text that is typed and not run. What each costs, and why the numbers of inputs are given again, is the log's *Atoms, Counted*.

## Reading the code

The loads show only what they exercise, so the code is read too, for what a long-lived process, a table or a persistent term keeps, and when it lets it go:

- a table row, a persistent term, or an entry in the process dictionary, and what removes it;
- a map or a list in a long-lived process's loop state, the runtime's system processes, the reaper and the shell's session among them;
- anything kept for one process by another, a monitor, a subscription, a waiting request, a call's row, and whether it goes when the first one dies, not only when the second does;
- a module or an atom made for an input at the prompt, and whether it is given back;
- in Ernest, a service's state that grows with its requests, as a store without expiry would.

A node keeps these, each with what lets it go (report §8.7): an offer's rows in `ern_offers` and `ern_offered`, until its process ends, which the reaper sees for a process the runtime started or opened and watches for any other; a row of `ern_initialized` for each module whose initializers a run has run, which the build bounds; a spawn's row in the gateway's `ern_spawns`, until its answer comes or the spawner gives up, which takes it, a later answer ending its process; the gateway's worker for each peer that sent a frame, until that peer's connection is lost; a monitored spawn's process, held on the peer until its spawner has made the monitor or has ended; and the note of a call from another node, in `ern_notes` and `ern_callees`, until an answer given on this node, the callee's restart or end, the caller's second note, which its call sends wherever it ends otherwise, its caller's end among them, or the loss of the caller's node.

Something may be kept as long as a program holds what it stands for: a socket until `Tcp.close`, a running program until it has answered its exit status, a checking proxy (report §8.4) for as long as the address it checks, which foreign code may still hold. What nothing can use again is a defect. A limit the report states, as §11.2's history of a thousand inputs, is a rule and not a cap.

## Tracing a growth

- **One kind at a time.** At the prompt, the same input a hundred times between two readings of `erlang:system_info(atom_count)`, through `foreign fn info(k : Foreign.Term) : Int with m = "erlang:system_info/1"`, one kind of input a run.
- **A longer run.** The load edited to forty rounds and run through `ern_cli:ern(["run", ...])`, with the table `ern_load_samples` created by hand, tells settling from growth.
- **One process's memory.** A column for the process suspected, as `reaper` was added, shows a growth that the node's total hides in its variation.
- **Every process at each sample.** Each process's memory and heap sizes (`erlang:process_info(P, garbage_collection_info)`) written at each sample, beside the kinds of `erlang:memory()` read at the sample and a moment after: a process whose heap steps between two sizes tells a swing from a growth, and a kind that differs only at the sample tells the host's lag.
- **Same and distinct.** The same input a hundred times, and a hundred inputs that each differ, `1 + 1` against `1 + n`, between two readings of `erlang:memory(code)`: a cost of the distinct ones alone is a cost per version of the code. The same test in plain Erlang, one module loaded, deleted and purged in a loop, tells the host's cost from the program's.
- **With and without.** The fix stashed (`git stash -- file`), rebuilt, and the load run again beside the run with it: the difference is the fix's. A regression test is checked the same way, and fails without the fix.

A growth found becomes a regression test in `make test` where one can show it in seconds: `declarations_let_go_test_`, `declarations_kept_while_reached_test_`, `expressions_leave_no_code_test_` and `expressions_again_leave_no_code_test_` in `test/ern_shell_tests.erl`, `monitors_let_go_test` in `erl/emitter/test/ern_emitter_tests.erl`, and the editor's `lastThousand` in `shell/shell/editor.ern`.

## Adding a load

A new system module, a new long-lived process, or a new kind of state the shell keeps gets a load, or a line in an existing one, and a row in the table above. A load is an Ernest program under `test/load/`, named for what it loads and not for a module of the standard library, whose namespaces a program may not take. It declares `mark`, does the same work in each of its fourteen rounds, and is added to `LOADS` in `test/Makefile`.

## What the loads leave out

The terminal's keys, which need a terminal; the shell at a terminal, whose editor and screen the line-mode session does not reach; peers, which MVP 3.0 builds; and a foreign function's checking proxies, which are kept by design. Each is read for instead. Growth with time rather than with work, and the examples' own programs, `examples/web_server.ern`'s session store among them, which forgets its sessions every ten minutes, were measured by a soak of hours until it was removed on 2026-10-02 (the log's *MVP 2.99b Read After the Review*); the web server's path through the runtime is the `sockets` load's. A program that grows over hours brings the soak, or a load, back with that evidence.
