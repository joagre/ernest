# Language feedback

What writing Ernest has felt against the principles: the shell, the standard library,
`libs/markdown` and the guide. This file holds each entry until a plan item decides it,
and MVP 2.65 decides them, theme by theme (the plan's MVP 2.65); a few wait for a later
MVP, which the entry names. An entry ends in a report change, a "Later" entry in the log,
or a line saying it was weighed and left alone, and then it leaves this file.

The entries are grouped by the question they share, and keep the numbers they were found
under, since the plan, the log and the code cite them. Fifty-five have left, each decided in
a step of the plan's MVP 2.65, which names the decision and the log entry that argues it.

## 1. Names and namespaces

Decided on 2026-09-25, and no entry is left; the plan's MVP 2.65 names each decision, and
item 46 went to the standard library's theme.

## 2. Expressions, patterns and types

Decided on 2026-09-25 and 2026-09-26, and no entry is left; the plan's MVP 2.65 names each
decision.

## 3. Processes and the system

Decided on 2026-09-26; the plan's MVP 2.65 step 5 names each decision. Items 14 and 25 are
MVP 3.0's, and 16 is MVP 2.7's; they stay here because they are the same question.

14. **Is `remote` needed once the node protocol and code distribution exist?** Raised while
    the guide was being checked, with `docs/node_protocol.md` and `docs/code_distribution.md`
    in view. `remote(f)` (report §6.7, guide §8.1) runs a pure function on a peer the runtime
    chooses among those marked `"remote-peer": true`, and answers `Right(v)`,
    `Left(NoRemotePeer)` or `Left(PeerLost)`; a fault in `f` faults the caller.

    The case for removing it, on the principles. Once `spawn(Peer(name), f)` ships code and
    answers across nodes, `remote` is a second way to do what a spawned process that answers
    already does, `spawn` on a peer and `Address.call` for the value (principle 2). It
    brings a type of its own, `RemoteError`, a configuration flag, and a placement policy
    the runtime applies where the program cannot see it (principle 3). The guide's
    `inParallel` already spawns a local process per computation around it, so the
    primitive does not spare the program the processes it would otherwise write.

    What would be lost, and has to be answered before it goes. A pure computation shipped
    as a value is simpler to reason about than a process: no mailbox, no reply, a fault
    that reaches the caller as if the call were local. The runtime's choice of peer is a
    load-balancing policy that would become a library's or the program's. And `remote` is
    in the report's prelude, §9, and the guide's examples, so removing it is a report change
    with the log's *Remote Ergonomics* (2026-09-13) to revisit.

    Decided first in MVP 3.0, before `remote` is built over peers.
25. **`spawn(Remote, f)`, the asynchronous `remote`.** A process already starts on a named
    peer, `spawn(Peer(name), f)` (§6.2), and answers asynchronously; what only `remote(f)`
    has is the runtime's choice of peer, among those §11.3 marks as accepting remote
    computation, and it is synchronous. A third place, `type Where = Local | Peer(String) |
    Remote`, would give that choice to a process: a long computation no longer holds the
    caller, and it may send more than one answer. With it, `remote(f)` is `spawn(Remote,
    ...)` and a reply, a composition, which strengthens item 14's case against it by
    principle 2. To be answered: what `spawn(Remote, f)` does where no peer accepts remote
    computation, where `remote` answers `Left(NoRemotePeer)` and `spawn` has only an
    address to return, and a silent fall back to `Local` is what principle 3 refuses, so
    it faults; and that the flag in `ernest.conf` then admits any process a peer sends,
    where today it admits a pure function, so what a peer accepts widens and §11.3 says
    so. The placement stays the runtime's, as unseen by the program as `remote`'s is.
    Decided with item 14 in MVP 3.0.
16. **A program cannot read its command-line arguments.** An entry point takes no
    arguments (report §8.1), and neither the prelude nor a system module gives the command
    line, so a program's inputs are written into it or read from standard input. A reader
    new to the language asked for it at once. Planned since 2026-09-20 in MVP 2.7, which
    builds `Sys.args` report first and weighs an entry point `main(args : List(String))`
    against it.

## 4. The standard library under E.0

Decided on 2026-09-26 in three batches; the plan's MVP 2.65 step 6 names each decision. Two
entries came since, and step 10 decided both: 57, standard input and output carry bytes, and
58, `Tcp.closeListener`.


## 5. The toolchain and the shell

Decided on 2026-09-26, and no entry is left; the plan's MVP 2.65 step 7 names each decision.

## 6. What a library should own

Code that implements a published specification or a general-purpose engine by hand, which
CLAUDE.md gives to a library under `libs/`. Found on 2026-09-26 by reading every Ernest
program in the repository for it; `libs/markdown`, a CommonMark implementation, is already
where such code belongs, and the Unicode width table for `Terminal.columns` was decided into
the standard library (step 6, batch 3).

Both entries were decided in MVP 2.65's step 10: 55, the web server waits for `libs/http`, and
56, `Terminal` writes the terminal's sequences.
