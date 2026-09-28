# Memory

How the project checks that nothing grows with the work done: the loads that measure it, the reading that looks for it, and the ways a growth has been traced to its cause. The rule is CLAUDE.md's *Memory that no collection reclaims is a defect*; this document is the procedure. It runs before every release, as [`review.md`](review.md) says, and whenever it is asked for.

## The loads

`make load` runs each load in an Erlang node of its own and prints, for each, its samples and whether it stayed flat; the same lands in `test/build/load/<load>.txt`. It is not part of `make test`, and takes about a minute and a half.

A load does the same work round after round and calls `mark(round)`, a `foreign fn` of `test/ern_load.erl`, after each. The programs are under `test/load/`; the shell's session is written by the harness.

| Load | Each round | Rounds |
|---|---|---|
| `processes` | 300 times: a call answered; a callee monitored and killed; a call answered after its time, and one never answered; a process that faults, watched from its start; a short-lived process that watches a service which outlives it; a subscription to faults that ends with its process | 14 |
| `supervisors` | 100 times: a child of a `OneForOne` group and one of a `OneForAll` group fault and restart in place, each then answering a call; a child joins and returns | 14 |
| `sockets` | 200 connections to an echo server, one message each way, a read that times out, then closed | 14 |
| `programs` | 20 times: `Os.run` of `cat` and of a program not found; `Os.start` of `sleep` killed; one that runs past its time | 14 |
| `files` | 100 times: a file written, appended, read, stated, copied, listed, renamed and removed | 14 |
| `alarms` | 500 times: an alarm after a millisecond and one at the time now, each taken, and a wait that times out | 14 |
| `shell` | 101 inputs at the prompt in line mode: expressions, `let`s, a function and a type declared again under the same names, a function as a value, output, a process spawned, and `:type`, `:bindings`, `:doc` and `:faults` | 14 |

`mark` gives what the round set ending, a killed process or a delivery of a `Down`, 200 milliseconds to end, collects every process's garbage, and samples:

- `memory`, the node's total, less the harness's own table;
- `code`, the loaded code's;
- `reaper`, the memory of the runtime's reaper, which holds every wait on a process;
- `atoms`, `procs` and `ports`, the node's counts;
- `rows`, the rows of the runtime's tables `ern_processes`, `ern_calls` and `ern_held`;
- `terms`, the persistent terms.

The first six rounds are the warm-up, in which heaps, caches and windows settle; the supervisors' restart window, which holds the restarts of its last second, is one. From the seventh on:

- the code, the atoms, processes, ports, rows, persistent terms and the reaper's memory may not grow at all, comparing the last sample with the first;
- the node's memory may not grow by more than 128 KB, comparing the mean of the last three samples with the mean of the first three. On loads that leak nothing it varies by about 100 KB either way; a leak of about a hundred bytes an operation passes the bound over a load's eight counted rounds.

A load that grew prints what grew and by how much, and `make load` fails.

**The host's own.** OTP keeps an entry, about 176 bytes, for each lambda of each distinct version of a module it loads, for as long as the node lives, and stops a node at 524,288 of them. It shows as `code` that rises with every new version of a module, and not with a version loaded again. The shell's inputs and declarations, and in MVP 3.0 code shipped between peers, are where new versions come from; the log's *The Shell's Code Memory* weighs it.

**Atoms.** The host never frees an atom and stops a node at 1,048,576 of them, so what makes one is read for as well as counted. A running program makes none from what it is given: the runtime makes atoms only of the names compiled into a program, and `Erl.atom` is a program's own request (Appendix E.19). The shell makes them of the text it is typed, through the lexer, for the prompt's inputs, its completion and its `Shift-Tab`: a name bound or declared costs about three the first time and none again, a name only mentioned, or a module name `:load` is given, one. An input's module and holder numbers are given again, so an input costs none of its own. Measured as the section below describes, one kind of input at a time.

## Reading the code

The loads show only what they exercise, so the code is read too, for what a long-lived process, a table, or a persistent term keeps and when it lets it go:

- a table row, a persistent term, or an entry in the process dictionary, and what removes it;
- a map or a list in a long-lived process's loop state, the runtime's system processes, the reaper and the shell's session among them;
- anything kept for one process by another, a monitor, a subscription, a waiting request, a call's row, and whether it goes when the first one dies, not only when the second does;
- a module or an atom made for an input at the prompt, and whether it is given back;
- in Ernest, a service's state that grows with its requests, as a store without expiry would.

Something may be kept as long as a program holds what it stands for: a socket until `Tcp.close`, a running program until it has answered its exit status, a checking proxy (report §8.4) for as long as the address it checks, which foreign code may still hold. What nothing can use again is a defect, fixed at its cause and never by a cap; a limit the report states, as §11.2's history of a thousand inputs, is a rule and not a cap.

## Tracing a growth

The procedures that have found a growth's cause:

- **One kind at a time.** At the prompt, the same input a hundred times between two readings of `erlang:system_info(atom_count)`, through `foreign fn info(k : Foreign) -> Int with m = "erlang:system_info/1"`, one kind of input a run. A declaration made again and a function as a value each cost about two atoms, and expressions and `let`s none, which named the cause.
- **A longer run.** The load edited to forty rounds, run through `ern_cli:ern(["run", ...])` with the sample table created by hand, tells settling from growth: the supervisors' memory settled after seven rounds and stayed flat for forty.
- **One process's memory.** A column for the process suspected, as `reaper` was added: the node's total varied too much to show 13 KB a round, and the reaper's own memory showed it plainly.
- **Same and distinct.** The same input a hundred times, and a hundred inputs that each differ, `1 + 1` against `1 + n`, between two readings of `erlang:memory(code)`: a cost of the distinct ones alone is a cost per version of the code, and the same test in plain Erlang, one module loaded, deleted and purged in a loop, tells the host's cost from the program's.
- **With and without.** The fix stashed (`git stash -- file`), rebuilt, and the load run again beside the run with it; the difference is the fix's, and the regression test is checked the same way, failing without the fix.

A growth found becomes a regression test in `make test` where one can show it in seconds: `declarations_let_go_test` and `declarations_kept_while_reached_test` in `test/ern_shell_tests.erl`, `expressions_leave_no_code_test` in the same file, `monitors_let_go_test` in `erl/emitter/test/ern_emitter_tests.erl`, and the editor's `lastThousand`.

## Adding a load

A new system module, a new long-lived process, or a new kind of state the shell keeps gets a load, or a line in an existing one, and a row in the table above. A load is an Ernest program under `test/load/` named for what it loads, not for a module of the standard library, whose namespaces a program may not take; it declares `mark`, does its work in rounds of the same work, and is added to `LOADS` in `test/Makefile`.

## What the loads leave out

The terminal's keys, which need a terminal; the shell at a terminal, whose editor and screen the line-mode session does not reach; peers, which MVP 3.0 builds; and a foreign function's checking proxies, which are kept by design. Each is read for instead.
