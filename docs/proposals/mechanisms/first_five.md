# The five rows read first

Status: read on 2026-11-21, the pass that must be right, on rows 10, 11, 18 with 24 and 33, 8 and 9 of [`README.md`](README.md). All are decided with the user, and each stays (the log's *The Check Stays a Process*).

Each reading has the log's entries that decided the mechanism, the other forms it could take, what a program loses by each, and what would go. A second reader then read each cold. It was given the mechanism, the report's sections and the forms, and neither the log nor this reading, and was asked for the case in which a form answers wrongly.

## What came of it

- **Two forms break a claim of `docs/soundness.md`**: foreign code's messages with no check at all, and an adapted address whose function crosses with it. Every other form holds the four claims, and gives up something a program can do, an order, or a fault.
- **Row 10, the check, has a form with no process that holds the same claim.** Its sentences were then drafted and read cold, and they grew exceptions of their own ([`row_10.md`](row_10.md)). It stays, decided with the user (the log's *The Check Stays a Process*).
- **Rows 11, 18 with 24 and 33, 8 and 9 stay.** Each other form gives up a promise that the log chose on purpose, and the second reader found the program that shows it.
- **Rows 18, 8 and 11 rest on two earlier decisions.** A function that receives nothing may still call and wait (the log's *Kill Darlings*), and a `receive` runs no code as it takes a message (*A Process's Addresses, Taught in Order*). So a function on a message's way needs a process of its own, that process must act for someone, and a restart that keeps its order must wait for it.

## Row 10: the check of what foreign code sends

**Why it is a process.** Foreign code is given a pid and sends with the host's `!`, and only another pid can stand in front of a pid. The log chose it over a flag read at every `receive` (*The Message Check Moves to the Point of Exposure*) and over a check in the receiver (*One Proxy in Front of an Address*). Its life is the target's, since the host cannot say when foreign code lets go (*A Check at the Boundary Lasts as Long as Its Process*).

**The form with no process.** An address crosses as a handle that is no host process: the node it crossed on, the address, and the hash of the type it crossed at. Foreign code sends by one function of the runtime's, stated in §12.2 beside how a `Reply` is answered. The function checks in the process that calls it, as a return is checked in its caller, and then sends as `send` does. A message that fails is not sent, and its receiver faults as today. A handle given back is the program's address at the type it crossed at. A table holds one row for each type that crossed, for the run. The search of the log found no entry that weighs this form.

**What a program loses.**

- **An address is no process to host code.** A host function that takes a pid and sends to it later cannot be given one: `erlang:send_after/3`, a library's `subscribe(Pid)`, `gen_tcp:controlling_process/2`. Bound with no Erlang, it raises. Its binding writes a few lines of Erlang, a process that takes the host's messages and sends each through the function. Today the checker is that process, written once.
- **The easy way is no longer the checked way.** A binding's author who writes no relay passes a `Process` and sends by host identity, which §8.4 leaves unchecked.
- **A handle is good on the node where it crossed.** Foreign code that carries one to another node by its own means cannot send through it there. Today the pid leads back.
- **An adapted address's function runs in the foreign sender**, as a `send` applies it, and not in a process that acts for the target.
- **Foreign code cannot monitor, link or kill the handle.** Today those act on the checker and not on the process. A `Process` is the pid.

**What goes.** The checker, the lookout, the checkers' table and the look's read of them: 210 of the row's 308 lines. 368 of its 922 words: the check's life, a different address for each check, the step more, the message not yet in the mailbox, the order through one check, and §10's bullet. Order through foreign code is then whole. MVP 4.5's item 113 goes, and item 149's two corners on a check's pid.

**The form with no check** breaks claim 2 for these messages and is no simpler. An adapted address has no pid, so it needs a process kept for it or a handle. The first keeps the mechanism and removes only the check. The second is the form above without its check.

**What the second reader found.** No claim fails under the form with no process, and no order or loss is new. Its first two losses above are the reader's, sharper than this reading had them. It also read two holes in the checker as it stands, listed below.

**Use.** No foreign function outside the standard library takes or gives an address: 77 foreign functions in nine libraries and ernest-epx. Principle 5 has such a count decide nothing.

**Recommended at first:** the form with no process, since it holds claim 2 with no process and no exception to §6.4. The user took it on one condition, that its sentences be read cold before any code.

**Decided since that reading:** the checker stays. [`row_10.md`](row_10.md) has the draft and what the reader found: a handle reaches Ernest code through a type variable, and an ordinary `send` to a foreign address on another node puts a handle where it cannot send.

## Row 11: the process kept for an adapted address

**Why it is so.** The function ran in the gateway until *Kill Darlings*: "a `callForever` in it would hold every frame of that node". A process for each message raced. An adapted address that crosses only where its target is on the making node was dropped in *The Report Rewritten for Peers*: "where a target lives is not a type, so no refusal replaces the fault".

**The forms, and what each loses.**

- **The peer's worker applies the function.** A function that waits holds every frame from that peer, its finds, spawns and kills. `test/fixtures/peers/desk.ern` has the program: both nodes wait for ever.
- **An adapted address is good on its own node alone.** The guide's service, `Peer.offer(Counter.service, adapted(self(), Request))`, and §6.10's recipe go. A program writes a relay process, which a peer's call then watches in place of the service, so the service's fault no longer ends the call. No failure is honest: a drop is a second silence, a fault charges a sender for a function it never wrote, and a refusal looks through every value sent to a peer.
- **The function crosses with the address.** A captured table or socket is used on another node (§3.11), and a `send` carries code.

**What is the mechanism's and what is the promise's.** The step more and "keeps nothing alive", 512 words, are forced by a function applied on the node that made it, under any mechanism. The process alone forces 221 words and buys the isolation.

**Decided:** stays. The second reader named one narrowing inside it, not weighed: on arrival the function acts for no process, and §6.5's three owners become two.

## Rows 18, 24 and 33: a function applied on a message's way

**Why it is so.** A wrap has no sender to run in. Applying it in the target as it takes the message was weighed and refused twice (*A Process's Addresses, Taught in Order*, *The Release Review's Questions*).

**The forms, and what each loses.**

- **The recipient applies the wrap at its `receive`.** A process that does not `receive` gets nothing of a wrap. A `main` of mailbox type `Never`, where a `receive` is a type error, that subscribes with `Os.termination(fn(_) = { tidy(); Os.exit(0) })` never has its wrap applied, and the end waits for ever. A wrap that waits holds its recipient, and an `after` comes late behind it. Every `receive` is written twice over.
- **The process that makes the delivery applies it.** One wrap that loops holds the reaper, and with it every spawn, every `Down` and the end. A wrap that spawns waits on itself.
- **Such a function may not wait.** A print in a wrap faults. Alone it removes no process, since a wrap can still compute without end, and it cannot be complete, since no foreign call declares its wait.
- **The fault is reported and the message dropped.** A caller in `callForever` waits for ever, a `Down` is never told, and a tick stops, each in a process that lives on.

**Use.** Every wrap in the repository's own Ernest is a constructor or a lambda that builds a constant. By principle 5 that decides nothing.

**Decided:** stay. No form keeps the five promises.

## Row 8: a restart told and waited for

**Why it is so.** A service monitor exists for "a program's registry, a lock's guard, a broker's subscriber list" (*The Review's Decisions*). It is told across nodes since a restart is "the one event a process's clients cannot see" (*A Restart Told Across Nodes*). No order between a death's `Down` and a `Restarted` was refused in *No Restarted After a Death*.

**The forms, and what each loses.**

- **No order with what the new run sends**, on every node or on other nodes alone. `examples/lease_broker.ern` then lends one lease to two holders, and its client waits for ever. A restart loop under a slow wrap fills the table with deliveries.
- **Told to no one.** `Process.run` cannot keep E.21's "killed where the caller ends or restarts", and a broker cannot watch a client it knows by `Reply.process`.
- **The restarting process sends the word itself.** It rests on the recipient applying its wrap, which the rows above refuse. It also keeps the order between the two processes alone, where the example rests on more.

**Decided:** stays. Its 772 words of waits follow from row 18, not from its promise.

## Row 9: the end's wait

**Why it is so.** It follows OTP's `terminate/2`: "the program's own end tells too, as `init:stop` runs `terminate/2` and `halt` does not" (*The Nodes' Reasons, Kept*). Nothing of the runtime's times it (§0, **Time**; *MVP 3.1 Read*).

**The forms, and what each loses.**

- **The entry process alone is told.** A service started by a binding cannot act at the end unless `main` knows it. A bare node has no `main`. Under the shell and `ern test` a program's `main` is not the entry process. ernest-httpd, which subscribes in its entry process alone, loses nothing.
- **No reply, and the end waits for each subscriber's end.** A subscriber that others still need while they finish must end to let the end go on.
- **A termination alone is told.** A `main` that returns or faults, and an `Os.exit`, end a store with its state unwritten.
- **A subscription made while the end waits is not told.** A store that faults as it writes, restarts and subscribes again is not told, the defect *MVP 3.1 Read* closed.

**Decided:** stays. The row holds two things, the subscribers' wait at 763 words and the end's flush with its cut at 496, and five of its eight items are the second's. The flush and its cut are a row of their own, to be read with the rest.

## Found beside the reading

Read from the code by the second readers, and not run. Each is a suspicion until a program shows it.

- A `kill` of a checker's pid ends the checker and leaves the process (`ern_rt.erl:1311`).
- A checker traps no exit, so foreign code that links to its pid or exits it ends the check, and what it sends afterwards vanishes (`ern_rt.erl:3248`).
- `Process.current()` in an adapted address's function on arrival is the kept process. Sent on and killed, it ends with what it was handed (`ern_gateway.erl:540`).
- A sole subscriber's restart ends the end's wait, so its new run that subscribes again may not be told (`ern_rt.erl:4524`), where E.23 has "a restarted run as a new one".
- Across nodes a `Restarted` can follow the `Down` of a death, where the watcher monitors again at once (`ern_rt.erl:1854`).
- `examples/lease_broker.ern`'s client acts on a call's answer from the new run before it reads the `Restarted` already in its mailbox (lines 367 and 385). A call's answer does not pass through the mailbox, so §6.9's order does not cover it.

The first two are the checker's and joined MVP 4.5's item 149. The other four are its item 157.

## What is left

The other 30 rows, at the session's usual effort, and the flush as a thirty-eighth.
