# The Ernest Runtime: Design

Status: the runtime's design note, which changes when the runtime does. It is not a proposal, and not authoritative: the report states what a program is promised, in §6 to §10 and Appendix E, and this note states the shape the runtime keeps those promises by, as it stands. A line here is a shape a reader must know to change the runtime without breaking a promise, never what one function does, which is the code's; the module map is [`architecture.md`](../architecture.md)'s, and the reasons are the log's, named at each line. Where the code and this note differ, the code is what is built and this note is corrected.

## The rule

What the runtime adds to an operation of the host costs a fraction of it, and nothing on a call that answers at once (CLAUDE.md's *Design*, §10). Its bookkeeping follows one rule: what the deadlock look needs of a process, the process marks in its own state, and the look reads it when the program seems idle; no operation writes a shared row for the look's sake. A shared row exists only where a process other than its owner must read it, and each such row names that reader below. The log's *The Sitting on §8.6's Bookkeeping* argues the rule.

## The process model

A program's processes are the host's, spawned by the runtime, which keeps a row for each (§6.9, §8.5). The reaper, one process, monitors every process the program spawns and every resource a system module opens, delivers each `Down` through a process of its own, and makes the deadlock look (§8.6). The system processes, stdout, stderr, stdin, the clock, the file system, the terminal, TCP and the host (§8.2), are foreign processes the runtime starts at a launch and stops at its end; each counts what it holds that can still deliver. The entry process runs the initializers in dependency order and then `main` (§8.5). A launch is one run of the runner, tagged by a reference the adapted addresses carry (§6.5, §11.2); the log's *The Numbers Across Machines* and *The Rows That Grew* measure what a spawn, a monitor and a restart cost.

## What the runtime keeps, and where

A process's own, in its dictionary, dying with it, read by the process and by the look alone:

- the mark that it is inside foreign code, put by the boundary's wrapper while a function given to foreign code runs, and by each slow wait of the runtime's own around its receive (§8.4, §8.6);
- the mark that it is in a receive with a deadline (§6.3);
- its call, the callee and the reply, while a call waits (§6.6), which the look, `Process.status` and a kill read;
- the root of a load's evaluation, and what a process of the runtime's own acts for (§11.2, §6.9).

Shared rows, in the runtime's tables, each with the reader outside its owner that needs it (`ern_rt:tables/0`):

- a process's row: its spawn site, order, root and the peer whose spawn started it, read by a fault's report, the program's end and `Process.current` (§6.9, §8.6);
- the callees' rows, one for each pending call, keyed by the callee, read by the callee's restart to end every call waiting on it, and dropped by the caller's end or its kill (§6.6, §6.9); the one shared write a call makes, on a table with the host's write concurrency, an ordered set since the restart reads its own rows by prefix (the log's *Measured 2026-10-22, the callee's table under eight writers*);
- the sources and the opened resources, few rows, read first by the look (§8.6);
- the deliveries and the restarts' aliases, read by a recipient's restart (§6.9);
- the fault and termination subscriptions, read by a fault and by the end (E.21, E.23);
- the checkers in front of exposed addresses (§8.4);
- the launch's one row, the runner, the tag, the reaper, the reporter, the arguments and how the run ends, gone with its table at the end, read by every process of the launch (§8.6, §11.2);
- a node's offers, each process's own offers, the initialized modules, and the notes of calls from other nodes, keyed by the caller's node so that a loss drops a peer's together (§8.7).

The host's persistent terms, one word each and replaced rarely, since replacing or erasing a larger term makes every process scan its heap: the system processes' pids, the holder of a source, and the toolchain's own modules; a top-level binding's value, which a ground binding needs no read of (§8.5, §11.1).

## The look

A deadlock is quiescence (§8.6; the log's *Deadlock Is Quiescence*): nothing in the program can deliver a message, and every process waits. The runtime can decide it because it owns every source of a message. The look runs in the reaper after a while without a message, and never on a node or while a shell holds the terminal. It reads the cheap facts first, the sources, the terminations, the system processes' quiet; only where nothing can deliver does it read every process, its status and reductions, twice, and in the second read each waiting process's top frame and three marks in one `process_info`. A host module on top of a waiting process is a host receive inside foreign code; the foreign mark is a callback inside foreign code; the timed mark and the call's mark are theirs; anything else is Ernest's wait. A module is Ernest's where the code table holds it as a unit or it is one of the toolchain's own beams, never by a prefix. Every slow wait of the runtime's own that a program process can be inside marks itself, which a test holds for every `receive` of the toolchain's Erlang by the module's `-receives` attributes (docs/style.md's *Erlang*).

## A call, a restart, a kill

A call is the host's monitor with an alias, a send, a receive with its deadline and the answer (§6.6); it writes its callee's row and marks itself, and its wait reads the caller's mailbox so that a restart asked for is taken there (§6.9, §10). A restart runs in the restarting process: it empties the mailbox, reads its own callees' rows and tells each caller `restarted` with the cause (§6.9). Every end the runtime gives a process from outside it but the program's end goes through one kill: a process of the runtime's own suspends the victim, reads its call's mark, drops the callee's row and the peer's note, and ends it (§6.9, §10); a kill of a process of another node is a frame carried out by that node's own kill (§8.7). A fault's trace is the host's stack as it stood, twelve program frames of the sixty-four the host keeps (§7.3, E.21).

## The boundary

What crosses between foreign code and the program is checked where it enters the program: a foreign function's return, a reply foreign code gives, a message to an address exposed to foreign code through a checker process, and each argument foreign code calls an Ernest function with (§8.4, §7.4). The standard library and the system processes are the runtime's own and are not checked. A function given to foreign code runs inside a wrapper that marks the process and turns a raise into the fault §7.4 names; a function value foreign code gives is a foreign function, named as the host names it. The foreign call itself is the host's call inside one `try`, and writes nothing.

## Nodes

Two nodes are two files and one TLS connection, the host's distribution as the carrier runs it (§8.3, §8.7). Fifteen frames are the runtime's own, which the gateway takes from each peer and hands to that peer's worker: a message to an adapted address, a spawn and its answer, a compute, a find, a utilization and a node's telling, that a call waits and that it is over, a kill of a process of this node, that a node ends, and the exchange's four, the request for a reach, the reach, the lacks and a code frame; a test holds this list to the gateway's reader. The exchange carries to a peer the definitions its spawn's reach names and the peer lacks, verified by hash and loaded whole before the process starts; its record is the proposal under `docs/proposals/nodes_and_code/`. A node detects no deadlock, since a peer can reach it.

## What the runtime does not do

It makes no scan on an operation's path that grows with other processes' work: a restart reads its own rows, a kill reads its victim, the look reads every process only when nothing else can deliver. It keeps no cache without a rule for letting go, which is why a launch reads the host's facts again (E.23). It routes around no defect of the host: what the host does not signal, a port's queue emptied, is waited for through the host's own busy state and not polled (§8.2; the log's *Built* paragraphs on the fixed waits).
