# Deadlock: what we claim, and a report of who waits on whom

Written 2026-11-06. Its programs were run and its nine questions answered in a design session on 2026-11-09, and it was said to be ready that day. It is planned as MVP 4.16's items 1 to 3. Nothing here is authoritative: the report, the plan and the log say what holds as each item is built.

## The doubts

Two doubts about the deadlock check began this.

- Only a cyclic `Address.callForever` is a deadlock.
- It is hard to see why the type system could help with deadlock detection.

They raise questions of their own. What does the check look for, and is it relevant? If all processes sit in `Address.callForever`, is that always a deadlock? What if they all wait for a long computation somewhere? What can Ernest promise, and is the approach valid?

Part 1 answers them. The second doubt is right (**Types play no part in the check**). The first is the word's usual sense, and not Ernest's case (**A cycle of `callForever` is not the definition**). It still has force, because a cycle in a running server is exactly what the check does not find, and Part 3 answers that with a report.

## Where this stands

**Decided:** a stuck part of a running program gets a report of who waits on whom, and never a fault. The nine questions are answered, and Part 5 lists the answers.

**How far this is checked.** The report, `look/0` and the log were read. The host's status was read in OTP 29.1.2's source, and no program shows it. The four programs ran on 2026-11-09 and did what Part 1 says, and the cost of a start time was measured ([`experiment.md`](experiment.md)).

**Read against its owners**, on 2026-11-09: `docs/design/runtime.md`, `nodes.md`, `shell.md` and `site.md`; report §0, §6.6, §6.9, §8.6, §8.7, §10, §11.2 and §12.4, and Appendices E.0, E.21, E.27 and F; `docs/soundness.md`; the plan's MVP 4.15, 4.4 and 4.5; `guide/why.md`, `guide/language.md` §5.4, `guide/faq.md` and the tour's chapter 5. It meets no other proposal at a seam.

---

## Part 1: what we found

**What the check is.** §8.6 looks for quiescence and not for a cycle. Every live process waits in a `receive` without `after` or in `callForever`, no message is in flight, and nothing the runtime counts can deliver one. `look/0` in `src/runtime/ern_rt.erl` reads each process's status and reductions twice. It builds no graph of who waits for whom.

**A long computation is no false alarm.** A computing process is not `waiting`, so the look answers `running`, however many callers wait on it. A process in foreign code counts as able to deliver. Program 1 shows it.

**One false alarm exists.** A foreign function starts a host process to do the work and returns, nothing monitors that process, and everyone waits for its message. §8.6 reads that as deadlocked and says so. A monitor of the host process cures it. Program 4 shows both, and the host's timer besides.

**Everyone in `callForever` is always a deadlock, and always holds a cycle.** Each process waits on exactly one live callee, and following those edges through a finite set must come back round. A callee that has ended faults its caller, and a call to a system process does not count as a wait.

**A cycle of `callForever` is not the definition.** It is neither necessary nor sufficient in Ernest.

- *Not necessary.* The first example of `guide/why.md`'s deadlock section has no `callForever`: `main` waits for `Done` and the worker for `Go`. A lone process in a `receive` nothing can satisfy has no cycle either, nor has A calling B while B waits for a message that never comes. The textbook term is communication deadlock (Chandy, Misra and Haas): a set of processes each waiting for a message only that set could send. A cycle is its special case, where each waits on one named other.
- *Not sufficient.* A reply is a value and may be handed on (§6.6). A calls B, B gives A's reply to a worker C, then B calls A. That is a cycle of callees, but C answers A, and A goes on to answer B. The program is correct, and a fault from a cycle check would kill it. Program 2 is that program, its cycle standing three seconds.

**Types play no part in the check.** `look/0` reads no type, and Go's runtime makes the same check without typed mailboxes. Who holds which address does not matter either, since everyone is asleep. The check is decidable because the runtime owns every source of a message.

Types answer "what may arrive", and a deadlock asks "will anything arrive". They meet only at `Never`, where a `receive` in a body receiving `Never` is refused (§6.8). Even a typed message can sit unmatched forever, since §6.3 does not require coverage. Ruling out deadlock statically takes session types and a restricted process topology, a third concept against §0's two (principle 5).

**The status premise holds, as read.** The two reads prove "nothing in flight" only if a process with a message on its way does not read as `waiting`. In OTP 29.1.2 a local send sets the receiver's `ACTIVE_SYS` in the sender's own call (`erl_proc_sig_queue.c`, `erts_proc_notify_new_sig`), and `erts_process_state2status` then answers `runnable` (`erl_process.c`). Until then the sender is `running`. Erlang's documentation does not promise this, so an upgrade of OTP could change it.

### What we can promise

- When `Fault("deadlock")` fires, nothing could ever have delivered again, apart from the foreign case above.
- A program that is no node gets the fault once it reaches that state, unless a shell holds the terminal. It comes after 100 ms to 1 s of quiet, 0.3 s in programs 3 and 4, and the report states no bound.

### What we cannot promise

- A stuck part of a program. Two workers in a cycle hang silently, as in Erlang, while anything else can run or deliver, such as an open listener or a timer. Program 3 shows it.
- Anything on a node, which never looks.
- Livelock, such as a retry loop around `Address.call`.

**Who it serves.** Tests, scripts and learners, where a stuck test faults and the run goes on. It barely serves a production server, which has a listener open or runs as a node.

---

## Part 2: the changes to the documents

None of these changes a rule of the report.

| # | Change | Where | Decided by |
|---|---|---|---|
| 1 | Keep the check. It is cheap at rest and, given the status premise, not wrong inside Ernest. | nothing to change | principle 1: a program that hangs with no word is the surprise |
| 2 | Give the claim its scope, in its name and in its first sentence. | `README.md`'s list of what Ernest adds; `guide/why.md`'s list and the heading of its section; `tour/README.md`'s contents and its chapter 5; `docs/design/site.md`'s *Anchors* and *The homepage* | principle 1, and principle 2 for the word |
| 3 | State the limit in plain words. | `guide/why.md`'s section, `guide/language.md` §5.4 | principle 1 |
| 4 | Drop the typed mailbox from the argument for why the check is decidable. | `guide/why.md`'s paragraph on why Ernest can decide it; a note on the log's *The Sitting on §8.6's Bookkeeping* | the check reads no type |
| 5 | Mark the log's idea of a fault from the calls in flight as unsound. | a note on *What Ernest Adds Stays at Four*, and a new log entry arguing this proposal | §6.6's hand-off, which program 2 runs |
| 6 | Name the status premise as what the look rests on. | `docs/design/runtime.md`, *The look* | a design note states the rule a mechanism rests on |
| 7 | Hold the programs of `experiment/` as regression tests, where none holds them yet. | `src/runtime/test/`, citing §8.6 | CLAUDE.md's *Tests* |

**Change 2's wording.** The bold name and first sentence of the claim in `guide/why.md`'s list reach the homepage word for word, so both must be honest alone:

> **A deadlock of the whole program is found.** A program that is no node, in which every process waits for a message none can send, ends with a fault and a trace under `ern run` and `ern test`, where the host would wait forever.

**Why the name keeps the word and gains a scope.** "A deadlock is found" reads as any deadlock. What was wrong in it is its scope, and "of the whole program" tells a reader that a stuck part is not promised. The word stays, since the fault, the guide's §5.4, the tour and Appendix F all use it, and a second name for one concept is a second way.

**Why the sentence names the node.** The homepage sets this claim beside "A distribution built for a WAN". A newcomer composes the two, and a node never looks. "Under `ern run`" does not exclude a node, which is `ern run` too. "A program that is no node" is §8.6's own phrase.

**Why it stays among the homepage's four.** The log's *What Ernest Adds Stays at Four* (2026-09-28) refused the claim on principle 1, on two legs. The entry of 2026-10-23 gave the claim a program, and a search found no entry that answers either. The first leg, that a reader expects to be told of any deadlock, is answered by the scope.

The second leg was that the other entries hold in every program, and this one only in a program that has stopped waiting on the world. That is true of a deployed server. But every program has tests, and under `ern test` a case that waits for a message nobody sends faults and the run goes on, which is where a newcomer meets the claim, in the tour's chapter 5.

**What follows from the rewording.** The heading's anchor becomes `#a-deadlock-of-the-whole-program-is-found`, and the site's check catches every link inside. The site is not live yet, so a broken link from outside costs nothing now. `test/fixtures/site/`'s `guide/why.md` is a fixture with its own text, which no test holds to the guide. The tour's chapter 5 quotes the claim's sentence and calls it the fifth claim of Why, where it is the fourth, and the change corrects both.

**Change 3's sentence:**

> A process stuck while another can still run or deliver is not found: two workers waiting on each other in a server with its listener open wait on, as they would on Erlang.

**What stands as it is.**

- **The fault's name**, `Fault("deadlock")`. Appendix F defines the word with the whole program as its scope, "no process can progress", and the cause uses the term as defined. A cause names what happened to this program, and the report shows the scope: the entry process faults and every waiting process stands beneath the trace. Part 3's report never says the word, so it appears only where the runtime is sure.
- **§8.6, but for one restated clause that Part 4 cuts.** Principle 1 has the report state a departure from what a reader who knows Erlang's processes predicts. For a stuck part that reader predicts a wait, and Ernest waits. The limit also follows from "every live process" in §8.6's own definition, and §6.6 states it where the cycle is written: a callee that lives on holds a `callForever` caller for as long as it lives.
- **§10's "The runtime detects a deadlock (§8.6)" and `docs/soundness.md`'s "The runtime detects it (§8.6)".** Both use Appendix F's term with its section beside it.
- **`guide/faq.md`**, which already says "where every process waits and nothing is in flight".

---

## Part 3: the report of who waits on whom

### What exists

- `Process.status` answers `Running`, `Receiving` or `Calling` (Appendix E.21), and it reads the caller's own mark of its call, which already holds the callee.
- A call with a limit marks itself timed, and a compute's callee is its gateway, so the limit is read from the caller's own state too ([`experiment.md`](experiment.md)).
- `ern_callees` holds a row for each pending call, keyed by the callee.
- A shell attached to a node is the operator's window, and `:processes` lists each process by its site and activity (§11.2).
- §12.4's lines name each stuck group's site and frame, and "nothing of who waits for whom" (`docs/design/runtime.md`).

So the runtime already knows the edge, and it tells nobody. An operator sees `calling` and cannot see on whom.

### The library gives the fact

```
type Activity = Running | Receiving | Calling(callee : Optional(Process), limited : Bool, since : Int)
Process.peer : (Process) -> Optional(String) // the name of the peer the process is on; None for this node's, and for a peer the configuration no longer lists
```

**The fact is on the constructor.** A callee exists only while a process calls. As a field of `Status` it would need a value in the other two states, and two fields would have to agree. A reader who knows types as ML has them predicts it on `Calling`.

**The callee is `Process.fromAddress` of the address called**, which E.21 defines through every adapted address and which the call's mark holds.

**It is `None` for a system process and for one of the runtime's own**, a load's evaluator or a compute's gateway. `kill` takes a `Process`, and `Process.live` and `Process.status` leave those processes out, so `status` hands none of them out. Every other callee is `Some`: a program's process, a listener, a socket or a running program, a foreign process the program called, and a process of another node. It gives a `Process` and never an `Address`, so nothing can be sent through it.

**`limited` says whether a deadline ends the wait.** It is true for `Address.call`, `Fs.read` and a compute, and false for `Address.callForever`, `Process.run` and `Io.readLine`. It is a fact, as `FaultReport`'s `restarted` is, and chooses no behavior (E.0 shape rule 9).

**`since` is the moment the call began, as `Clock.monotonic` counts it.** It tells a call that stands from a thousand short ones to the same callee, which two readings of the listing cannot tell apart. It costs a wait without a limit 23 ns, 3% of the host's round trip ([`experiment.md`](experiment.md)), a mark in the process's own state. `Address.call` already reads the clock for its deadline. The name goes to the glossary, which today says a moment is a `time`.

**`Process.peer` reads a process's node**, which nothing in the library does today, though E.21 says a `Process` names its node. The shell is written in Ernest and needs it to write the peer's name. E.0's rule 1 admits it, since it reads the identity the host owns and the runtime's table of peers. It is a general operation of the type (rule 3): after `Peer.find` it says which peer answered, and for a `Down` which peer's process ended. `FaultReport`'s `spawnedBy` names a peer the same way in the same module.

**`callee` means one thing in two types.** `FaultReport`'s `callee` is the callee's site, an `Optional(String)`, since that callee may have ended. This one lives, a site names many processes, and no chain can be followed by a site, so it is a `Process`.

**What it breaks.** A match on `Process.Calling` must take its fields. One site matches it under `src`, `examples` and `tour`, `src/shell/ernest/shell.ern`'s `activity`. ernest-httpd names it at four sites, one a pattern and three a value passed, and its session meets the change at its floor's rise. It gets a line in `CHANGES.md`.

**What it changes besides.** E.21's paragraphs on `status` and its doc blocks, from which the manual page is written; `docs/design/runtime.md`'s line on a process's call, which gains the start; and the glossary.

### The shell shows it

`:processes` writes each process's activity "as `Process.status` answers them" (§11.2), so the listing writes the callee, the limit and the age. No command is added.

```
> :processes
Stuck.main:14 calling Stuck.main:15 without limit for 41 s 2848 bytes
Stuck.main:15 calling Stuck.main:14 without limit for 41 s 2848 bytes
Stuck.main:17 calling Stuck.main:14 without limit for 41 s 2848 bytes
Client.main:9 calling a process of b without limit for 3 s 2848 bytes
Server.listen:4 receiving 3120 bytes
a cycle of calls without limit for 41 s: Stuck.main:14, Stuck.main:15
```

- **The callee is named by its site.** A call with a limit writes the callee without "without limit".
- **A callee of another node is named by its peer**, through `Process.peer`, and the walk stops there. The operator attaches to that node to go on, and sees the other half there.
- **A callee with neither a status nor a peer writes `calling` alone**, as a callee that is `None` does. The shell cannot tell a foreign process from a callee that ended between two reads.
- **A cycle of calls without limit gets a line after the listing**, by its sites in the calls' order, with the age of its youngest call. A site does not identify a process, so the operator cannot find a cycle by eye, and the end of a long listing is where the eye is.
- **The line says "a cycle of calls" and never "deadlock".** Program 2's cycle is legal and gets the same line while its worker computes.

**The cycle line is true.** The listing reads one process at a time, so two reads could show a cycle that stood at no instant. The shell notes `Clock.monotonic()` before its first read and writes a cycle only where each of its calls began before that. Each such call stood from before the listing until its own read, so all stood together at the listing's start. A call younger than the listing is the passing one.

**The walk is the shell's Ernest.** A cycle holds only processes that call without limit, which the shell keeps in a `Map` from caller to callee and follows once each. A `Process` has equality, which a `Map`'s key needs. E.0's rule 3 keeps a walk out of the library, since what counts as a cycle is a policy.

**The plain shell gains too.** No deadlock is detected while a shell holds the terminal (§11.2), so a learner whose input deadlocks at the prompt gets no fault, and `:processes` then shows the cycle.

The exact words of the lines are §11.2's when it is built, read cold with E.21's. `docs/design/shell.md`'s sentence on `:processes` and `guide/deployment.md`'s paragraph on the listing, which restates it, change with it.

### A program may watch for itself

The fact is a library function, so a service reads `Process.live` and `Process.status` and logs what it finds, at a period it derives from what it knows: whether it hands replies on, and how long a legal call may take. A program that is no node has no shell to attach, so with a listener open and a stuck part its only reader is itself.

A program that wants a callee's status on another node writes `Peer.computeAt(name, fn() = Process.status(callee), ms)`, with `Process.peer`'s name. `Process.status` itself stays a local read that waits on nobody (principle 3).

### What it never does

- It never faults, kills or ends a process, and it changes nothing it reads.
- It writes no shared row on a call's path, so it keeps the runtime's rule (`docs/design/runtime.md`).
- The runtime never tells unasked. An unasked line is read as a verdict, and for program 2 the verdict would be wrong. A time for it could only be chosen: the time of a wait on a callee is the caller's `ms`, and `callForever` says that none applies.
- It makes no look of its own. A read of every process at a period, or a walk at each call, would break the runtime's rule.

### Weighed against §0

- **Principle 1, least surprise, decides.** An operator who sees `calling` predicts being able to ask on whom. A report that calls a legal cycle a deadlock would surprise, so it states facts.
- **Principle 2, one way.** The fact extends `Process.status`, and the listing extends `:processes`. Neither gets a second function or command beside it.
- **Principle 3, nothing invisible.** The wait, its callee and its age are invisible today to the one person who needs them.
- **Principle 5, small.** It adds no concept and no syntax: three fields of a library type, one function, and a longer line of a listing.

### What it does not solve

- A `receive` has no edge, since anyone holding the address may send. The report shows it as the end of a chain, which is often the useful answer.
- A hand-off is invisible, so a cycle may be legal. That is why it gives no verdict.
- The operator must ask.
- A cycle across nodes is not seen from one node, and connections are not transitive (§8.7), so no walk from one node could be whole.

---

## Part 4: the callee in a deadlock's report

A deadlock's lines gain the callee's site, so that the fault says on whom each group waits:

```
Stuck.main faulted: deadlock
    Stuck.main:19
    1 process of Stuck.main:14 waits in Stuck.firstLoop:52 on Stuck.main:15
    1 process of Stuck.main:15 waits in Stuck.secondLoop:60 on Stuck.main:14
    1 process of Stuck.main:17 waits in Stuck.main:17 on Stuck.main:14
```

**Why.** Once `:processes` names the callee, a reader predicts that the fault does, in the one case where the runtime is sure (principle 1). `guide/why.md`'s `Mutual` then shows its cycle in two lines.

**It costs nothing on any path.** The look's second read already takes each waiting process's mark of its call, and the callee's site is its row. All of it is read after the verdict, as the lines are now.

**The form stays simple.** A call with a limit, a call to the system and a call to another node cannot be in a deadlock. So a callee there is a process with a site, or a foreign one, whose line stays as it is today. A process that waits in a `receive` has no callee, and its line stays too.

**A group is one spawn site, one frame and one callee's site.** A group with several callees is split. One line listing them, `on A, B`, would read as each process waiting on both.

**§8.6 loses a restated clause.** It says "a line for each group of processes with one spawn site and one waiting frame (§12.4)". The clause goes, leaving "lists the waiting processes beneath the trace (§12.4)", so that §12.4 alone owns the form. No rule changes, and `docs/soundness.md` argues nothing of the lines. The sentence is read cold before the build.

**What it changes besides.** §12.4's paragraph, `docs/design/runtime.md`'s *The look*, the console blocks of `guide/why.md` and `guide/language.md` §5.4 where a line has a callee, and the tests that match the lines. The tour's chapter 5 shows waits in a `receive` alone and stays.

---

## Part 5: the nine answers

Each was argued and accepted in the session of 2026-11-09. The parts above state each with its reason.

| # | Question | Answer | Decided by |
|---|---|---|---|
| 1 | What is the claim, and does it stay among the homepage's four? | "A deadlock of the whole program is found", its sentence naming the node, in Why's six and the homepage's four | principle 1; principle 2 keeps the word |
| 2 | Does `Fault("deadlock")` keep its name? | yes | principle 2, on Appendix F's term |
| 3 | Does §8.6 itself state the limit? | no: §8.6, §10, Appendix F and `docs/soundness.md` stand, and the guide teaches the limit | principle 1's rule of what the report states |
| 4 | What does the fact look like in the library? | `Calling(callee : Optional(Process), limited : Bool, since : Int)`, the callee by `fromAddress`, `None` for the runtime's own alone, no walk in the library | principle 1 for the shape; E.0's rules 1 and 3 |
| 5 | What does the shell show? | `:processes` alone, the callee, the limit and the age on each line, and a line for each cycle of calls without limit | principle 2, on §11.2's sentence |
| 6 | Does the runtime ever tell unasked? | no | principle 1; principles 2 and 3 on the time |
| 7 | What of a call to another node? | the edge by the peer's name, the walk stopping at the node; `Process.peer` added | principle 3 |
| 8 | How does the report tell a standing cycle from a passing one? | by `since`: a cycle is written where each of its calls began before the listing did, with its age | principle 3, the cost rule kept at 3% of the host's call |
| 9 | Does a deadlock's fault name the callee too? | yes, as an item of its own: `on` and the callee's site, groups split by it, §8.6's restated clause cut | principle 1 |

---

## Part 6: weighed and not taken

Each has its verdict here until the log's entry takes it. None is kept for later.

- **A new name for the claim that drops the word**, "A program that can never go on is ended". A retry loop can never go on, nor can a server whose client never comes, and neither is ended.
- **A cause that states the fact**, "every process waits". It would be true even in the false alarm of program 4. §8.6 already states that case as "read as deadlocked", the fact is in §12.4's lines, and an idle server's processes all wait too.
- **A sentence of the limit in §8.6.** It would restate the contrapositive of "every live process".
- **A deadline in place of `limited`.** Nothing asks how long is left (principle 5).
- **A second command beside `:processes`**, a second view of one fact (principle 2).
- **A tree of chains, or a count of callers for each callee.** A chain is read line by line, and a `receive` is where it ends.
- **`calling a foreign process`** as a line. The shell cannot tell a foreign process from a callee that has just ended.
- **A line from the runtime when a cycle has stood.** Only a condition that makes the line true would change this, never a time, and with such a condition the answer would be a fault for the cycle.
- **A status read over the network, or a walk across peers.** A program writes the compute, and the operator attaches (principle 3; the log's *A node is no peer of itself*, 2026-10-09).
- **The host's reductions in `Status`, read twice.** It costs a call nothing and makes the cycle line true, but tells nobody how long, in the host's unit, for the shell's sake alone.
- **In the fault's report: a cycle line, the age, and the faulting process's own callee.** The lines are a summary by site and the verdict is given; a walk in the reaper would be a second cycle finder, in Erlang. Everything in a deadlock is quiet now. `FaultReport`'s `callee` means the callee whose fault was carried.
- **A sound partial check.** Addresses cannot be forged, so a process whose address and replies no running process can reach can never wake. That is the one real link between types and detection, and it would be sound even with a hand-off. It is the idea behind Pony's actor collector and Go's recent goroutine-leak work (both from memory, to be checked). It needs a reading of every process's heap, which the host does not appear to offer.

---

## Then

Three items, for an item session: MVP 4.16's items 1 to 3, placed with the user on 2026-11-09 (the log's *MVP 4.16, the Proposals Before the Launch*). All three stand before the launch.

- **Item 1, the documents of Part 2.** The launch is when the claim is read most, and the full review reads the documents as they will ship. It closes on `make test-docs`, and on the runtime's target for the programs it holds as tests.
- **Item 2, the callee in a deadlock's report, Part 4.** It cuts a clause of §8.6, and a change there is built the day it is decided, after its cold reading. So it is decided when its item opens. The launch's readers then see `Mutual`'s cycle in Why. It touches the runtime and closes on `make test-full`.
- **Item 3, the report of Part 3.** E.21's type and `Process.peer`, the start time in the call's mark, the shell's lines and their tests. MVP 4.4's cost analysis then reads the call's mark with its start time in it, and the full review reads E.21 and the shell whole. It touches the runtime, so it closes on `make test-full`, and `make bench` confirms the call's rows within their noise.

Each item's report sentences are read cold before its build (CLAUDE.md's *Before code*), and the log's entry arguing Parts 1 to 6 is written with item 1.
