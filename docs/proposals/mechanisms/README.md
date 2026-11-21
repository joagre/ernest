# The mechanisms read against what they force

Status: a reading under way, MVP 4.4's item 6 (the log's *The Mechanisms Read, Planned*). The rows are found and counted, on 2026-11-21. No row has its loss or its narrower promise written, and no row is decided. Nothing here is authoritative, and nothing in the report or the code changes by it.

| File | What it is | Status |
|---|---|---|
| `README.md` | the measure, what a row is, how it is counted, and the rows ranked | the rows counted; the argument of each row not begun |

## The measure

Sound first, then the simplest thing that holds it. No row trades one of the four claims of [`docs/soundness.md`](../../soundness.md). Where a mechanism holds one, its row asks for a simpler way to hold it and never for its removal.

## What a row is

A mechanism is what the runtime does of its own that no program names: a process, a message between its processes, a wait, a count or a table. A row is one mechanism, or the few that exist only together to keep one promise.

These are not rows:

- **The language's own steps**: a send, a spawn, a `receive`, a call and its alias, a monitor, the loop of `restarting`, the entry process and the initializers.
- **A check made in the calling process**: a foreign function's return, a reply and an argument (§8.4). It is no process and no wait. So 873 of §8.4's 1,529 words stand in no row, most of them on these checks, on `Unit` and on type variables.
- **A library function's own work**, where nothing stands behind it that the program did not ask for: a service's offer and find, a socket's reads and writes, a file, `Code.running`, `Code.hashes`.
- **What is the host's**: the alias, the monitor, the distribution's buffer, the detector of a silent peer.

## How a row is counted

- **The report.** The sentences of the three files that name the mechanism or the promise only it keeps, found by the row's patterns, a few phrases each, some held to the sections where the phrase means the mechanism. A sentence may stand in two rows. Fenced blocks and headings are not counted, which leaves 87,500 words of the report's 99,000.
- **The code.** The lines of the functions that exist for the mechanism in `src/runtime/` and `src/nodes/`, each with its comment and its spec, listed by name. A function stands in one row, but for two that stand in two.
- **The tests.** The lines of the test functions whose text matches the row's phrases, under `test/`, the runtime's, the nodes', the emitter's and the command line's tests. It is the roughest of the four.
- **The items.** The plan's items whose title names the mechanism, assigned by hand, closed and left. The plan holds the items of MVP 4.16 and later, 125 closed and 44 left, so an older mechanism shows few.

The patterns, the script and each row's list of sentences are the session's probe, kept outside the repository. The counts rank the rows and are no measure of a saving: a row decided against removes some of its sentences and keeps the rest in a narrower form.

## What the count found

- **37 rows.**
- **19,800 of the report's 87,500 words stand in a row**, 23 percent. By chapter: §6 35 percent, §8 56, §10 69, §12 59, Appendix E 28 and §11 14.
- **10,100 of the 16,400 lines** in the functions of the runtime and the nodes are a row's. The rest is the language's own steps, the library's primitives, the checks in the caller and the reading of a node's configuration.
- **56 of the plan's 125 closed items and 15 of its 44 left name a row.** One row, the check, has 14 of them.

## The rows

Ranked by the report's words. The sections are where most of its sentences stand.

| | The row | The promise it keeps | Words (sentences) | Code | Tests | Items closed, left |
|---|---|---|---|---|---|---|
| 1 | The exchange and the code table | A function spawned or computed on a peer that lacks it runs there, carried as its form by its hash (§8.7, §12.7) | 3,097 (69) | 1,872 | 3,450 | 0, 0 |
| 2 | How busy a node is: the measure, the telling, the rows held and the pick | `Peer.compute` runs on the less busy of two peers, and `Peer.utilization` answers (§8.7, §12.8, E.27) | 2,160 (52) | 302 | 3,571 | 0, 1 |
| 3 | The carrier: its keys, its floor, its own acceptor and port map | A node connects only to a listed key, on one floor (§8.7, §12.5) | 1,550 (43) | 847 | 3,252 | 0, 0 |
| 4 | The gateway, a worker for each peer, and the seventeen frames | What a message cannot do on a peer is done there in order, and the runtime's own processes wait on no peer (§8.7, §12.6) | 1,359 (31) | 637 | 3,825 | 5, 1 |
| 5 | The eight system processes | Each system module is answered by a process the runtime starts (§8.2, §12.1) | 1,337 (42) | 452 | 326 | 0, 1 |
| 6 | A load's evaluator and its settler | A load evaluates its bindings outside its caller, and is whole or undone however the caller ends (E.28, §11.2) | 1,240 (24) | 334 | 831 | 2, 0 |
| 7 | A full table and the limit of open files, answered | At a limit of the host's a request answers a value, a delivery faults its recipient, and the end can still run (§7.4, §12, §12.5) | 1,167 (31) | 97 | 2,184 | 4, 0 |
| 8 | A restart told to its service monitors and waited for, on other nodes too | A `Down` with `Restarted` reaches its watcher before anything the new run sends (§6.9, §8.7, §12.6) | 993 (22) | 202 | 1,726 | 1, 0 |
| 9 | The end's wait for the subscribers of `Os.termination` | Each subscriber is told and waited for before the program ends (§8.6, §11.2, E.23) | 973 (27) | 398 | 2,164 | 7, 1 |
| 10 | The check of what foreign code sends: a process for each address that crossed | A message foreign code sends to an address it was given is of the mailbox's type, or faults its receiver (§8.4) | 922 (32) | 308 | 837 | 11, 3 |
| 11 | The process kept for an adapted address on the node that made it | An adapted address works from any node, its function applied where it was made, a peer's messages in order (§6.5) | 815 (18) | 164 | 825 | 4, 2 |
| 12 | A reload of `ernest.conf` at the hangup | A node's peers change while it runs (§8.7, §12.5) | 795 (20) | 115 | 1,269 | 1, 1 |
| 13 | The deadlock look, and what each process marks for it | A program in which nothing can deliver faults with `deadlock`, and its report lists who waits (§8.6, §12.4) | 794 (27) | 431 | 5,770 | 9, 0 |
| 14 | What a node holds of code and lets go, and the host's limits counted | A session's units and a test run's go, and a node says when it nears a limit of the host's (§10, §11.2) | 784 (19) | 168 | 2,643 | 0, 0 |
| 15 | A node's end told to each peer and waited for | A peer says `ended` and not `lost`, and what was placed before the word crossed (§8.7, §12.6) | 762 (17) | 67 | 3,227 | 3, 1 |
| 16 | A session's screen and a session's own processes | What a session's processes write goes to its shell's screen (§11.2, §12.1) | 761 (15) | 110 | 504 | 1, 0 |
| 17 | The record of a waiting call: the caller's mark, the callee's row and the note on its node | A restart ends every call waiting on it, and `Process.status` and a deadlock's report say who waits on whom (§6.6, §6.9, §8.7, E.21) | 748 (13) | 202 | 708 | 2, 0 |
| 18 | A process for each delivery through a wrap, acting for its recipient | A wrap that does not finish holds up no other delivery, and what it opens is its recipient's (§6.5, §6.9, §10) | 719 (16) | 343 | 1,994 | 2, 1 |
| 19 | A restart a supervisor asks for, taken at the child's next wait | A supervisor restarts a child's siblings in place (§6.9, E.22) | 634 (19) | 83 | 1,045 | 2, 0 |
| 20 | The terminal's claim, its reader and its holder | One terminal is read as keys or as lines, and is given back as it was found (§12.1) | 632 (17) | 359 | 331 | 3, 0 |
| 21 | A fault's trace: twelve lines, the runtime's frames left out | A trace shows the program's frames (§7.3, E.21) | 625 (14) | 71 | 1,825 | 1, 0 |
| 22 | A resource's process owned by its opener | A socket, a listener and a running program end with the process that opened them or was given them (§6.9, E.18, E.23) | 546 (14) | 227 | 1,063 | 0, 1 |
| 23 | The lock on `ernest.pid` | One node to a directory, and `ern stop` returns once the node has ended (§11.2, §12.5) | 408 (13) | 115 | 1,726 | 1, 0 |
| 24 | A fault that stands in a mailbox and is met at the next wait | A fault in an adapted address's function, and a bad message's, is its target's (§6.5, §7.3, §8.4) | 371 (10) | 79 | 607 | 3, 3 |
| 25 | A compute's process on the peer and its fault carried to the caller | A fault in the function a compute runs is the caller's, with its trace (§8.7, E.27) | 355 (7) | 222 | 1,453 | 0, 0 |
| 26 | The reaper and a row for each process | A `Down` and a fault's line name the spawn site, and `Process.live` lists the program's processes (§6.9, E.21) | 328 (6) | 363 | 3,189 | 0, 0 |
| 27 | A socket's writer and its closer | A write that waits holds up no read, and bytes a socket took are sent after it ends, within a bound (E.18) | 293 (7) | 164 | 1,963 | 2, 2 |
| 28 | The runtime's own lines: a line that waits for standard error, and the sayer of lines said later | None of the report's: the order of the runtime's lines among a program's output is promised nowhere | 267 (4) | 169 | 25 | 1, 0 |
| 29 | A listener's workers and the close that waits for its end | `Tcp.closeListener` answers once the listener has ended, each accept it held answered first (E.18) | 253 (7) | 193 | 1,134 | 2, 2 |
| 30 | A capture's collector | `Test.capture` takes what its caller's chain writes, and writes it back where the caller ends first (E.24) | 245 (6) | 167 | 173 | 0, 0 |
| 31 | The killer: every kill through one process | A kill ends the call its victim waited in, and needs no room in a full table (§6.9, §10) | 230 (4) | 120 | 1,044 | 0, 0 |
| 32 | The helper `ern_exec` | A program `Os.start` started has its pipes or its terminal, its signals and its process group, which ends with it (E.23) | 227 (9) | 2,034 | 1,617 | 6, 0 |
| 33 | A courier for each subscription to keys and to faults | A subscriber's keys and reports arrive in order, and a wrap that does not finish delays no other subscriber's (§12.1, E.21) | 176 (4) | 150 | 250 | 0, 0 |
| 34 | A restart cancels what the old run asked for | An alarm, a monitor and a subscription of the old run, with what is on its way, reach no new run (§6.9) | 161 (5) | 135 | 313 | 0, 0 |
| 35 | `Process.run`'s second process and the mark of an expected fault | `Process.run` answers a fault as a value, and `Test.faults` keeps its fault from every report (E.21, E.24) | 121 (3) | 48 | 490 | 0, 0 |
| 36 | The launch's tag in an adapted address | An adapted address an earlier run made is dead, its function not applied (§8.7, §11.2) | 113 (3) | 16 | 0 | 0, 0 |
| 37 | The supervisor's two processes | A group keeps its children across its supervisor's restart, and ends them in order at its death (E.22) | 100 (2) | 510 | 1,179 | 2, 0 |

Row 37 is the library's, written in Ernest, and its lines are `supervisor.ern` whole. Row 32's lines are most of `ern_os.erl` and `ern_exec.c` whole, 1,375 lines of C.

## The rows that hold a claim

A paragraph of `docs/soundness.md` argues from each of these mechanisms. Its row asks first what that paragraph needs of it, and for a simpler way to hold the claim, never for the claim's removal.

- **Claim 2, every message fits its mailbox**: rows 10 and 24, the check and the fault that stands in a message's place (its sections 2 and 5); row 11, by which no function crosses in a message (section 7); row 6, by which a load's binding is evaluated in no process of the program's (6.4); rows 18 and 33, a wrap applied outside the process it delivers to (6.3).
- **Claim 4, every answer fits its call**: row 17, the record that ends a call and answers nothing (section 4, I3).
- **The new run's mailbox at a restart**: rows 8 and 19 (sections 5 and 7).
- **A process on a peer runs the code it was typed with**: rows 1 and 25, and row 3's floor, which the argument assumes the same on every node (section 7).
- **A process's code stands while it runs**: rows 14 and 36 (section 7).
- **No process runs after the end**: rows 9 and 34 (section 7, *The end*).

The argument names no other row. It leaves a deadlock out, so row 13 holds no claim.

## What is not done

- **Read.** §6 to §8, §10, §12 and Appendices E.15, E.18, E.21 to E.24, E.27 and E.28 were read whole, with the runtime's and the nodes' design notes. §11.2 was read to the shell's part. The rest of the report was searched by the patterns and not read.
- **Each row's argument**: the log's entries that decided the mechanism, the simpler way to hold the same promise, the narrower promise that would take the mechanism out, and what a program loses by it, the loss before the saving.
- **The second reader** of the rows whose loss must be right.
