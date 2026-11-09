# Deadlock: what we claim, and a report of who waits on whom

Under discussion, written 2026-11-06. Nothing here is authoritative, and nothing goes into the report, the plan or the log until it is decided.

## The doubts

Two doubts about the deadlock check began this.

- Only a cyclic `Address.callForever` is a deadlock.
- It is hard to see why the type system could help with deadlock detection.

They raise questions of their own. What does the check look for, and is it relevant? If all processes sit in `Address.callForever`, is that always a deadlock? What if they all wait for a long computation somewhere? What can Ernest promise, and is the approach valid?

Part 1 answers them. The second doubt is right (**Types play no part in the check**). The first is the word's usual sense, and not Ernest's case (**A cycle of `callForever` is not the definition**). It still has force, because a cycle in a running server is exactly what the check does not find, and Part 3 answers that with a report.

## Where this stands

**Decided so far:** a stuck part of a running program gets a report of who waits on whom, and never a fault.

**How far this is checked.** The report, `look/0` and the log were read. The host's status was read in OTP 29.1.2's source. No Ernest program was run, so the examples below are argued from the report and are not observed. A design session runs them first (Part 4).

---

## Part 1: what we found

**What the check is.** §8.6 looks for quiescence and not for a cycle. Every live process waits in a `receive` without `after` or in `callForever`, no message is in flight, and nothing the runtime counts can deliver one. `look/0` in `src/runtime/ern_rt.erl` reads each process's status and reductions twice. It builds no graph of who waits for whom.

**A long computation is no false alarm.** A computing process is not `waiting`, so the look answers `running`, however many callers wait on it. A process in foreign code counts as able to deliver.

**One false alarm exists.** A foreign function starts a host process to do the work and returns, nothing monitors that process, and everyone waits for its message. §8.6 reads that as deadlocked and says so. A monitor of the host process cures it.

**Everyone in `callForever` is always a deadlock, and always holds a cycle.** Each process waits on exactly one live callee, and following those edges through a finite set must come back round. A callee that has ended faults its caller, and a call to a system process does not count as a wait.

**A cycle of `callForever` is not the definition.** It is neither necessary nor sufficient in Ernest.

- *Not necessary.* The first example of `guide/why.md`'s deadlock section has no `callForever`: `main` waits for `Done` and the worker for `Go`. A lone process in a `receive` nothing can satisfy has no cycle either, nor has A calling B while B waits for a message that never comes. The textbook term is communication deadlock (Chandy, Misra and Haas): a set of processes each waiting for a message only that set could send. A cycle is its special case, where each waits on one named other.
- *Not sufficient.* A reply is a value and may be handed on (§6.6). A calls B, B gives A's reply to a worker C, then B calls A. That is a cycle of callees, but C answers A, and A goes on to answer B. The program is correct, and a fault from a cycle check would kill it.

**Types play no part in the check.** `look/0` reads no type, and Go's runtime makes the same check without typed mailboxes. Who holds which address does not matter either, since everyone is asleep. The check is decidable because the runtime owns every source of a message.

Types answer "what may arrive", and a deadlock asks "will anything arrive". They meet only at `Never`, where a `receive` in a body receiving `Never` is refused (§6.8). Even a typed message can sit unmatched forever, since §6.3 does not require coverage. Ruling out deadlock statically takes session types and a restricted process topology, a third concept against §0's two (principle 5).

**The status premise holds, as read.** The two reads prove "nothing in flight" only if a process with a message on its way does not read as `waiting`. In OTP 29.1.2 a local send sets the receiver's `ACTIVE_SYS` in the sender's own call (`erl_proc_sig_queue.c`, `erts_proc_notify_new_sig`), and `erts_process_state2status` then answers `runnable` (`erl_process.c`). Until then the sender is `running`. Erlang's documentation does not promise this, so an upgrade of OTP could change it.

### What we can promise

- When `Fault("deadlock")` fires, nothing could ever have delivered again, apart from the foreign case above.
- A program that is no node gets the fault once it reaches that state, unless a shell holds the terminal. It comes after 100 ms to 1 s of quiet, and the report states no bound.

### What we cannot promise

- A stuck part of a program. Two workers in a cycle hang silently, as in Erlang, while anything else can run or deliver, such as an open listener or a timer.
- Anything on a node, which never looks.
- Livelock, such as a retry loop around `Address.call`.

**Who it serves.** Tests, scripts and learners, where a stuck test faults and the run goes on. It barely serves a production server, which has a listener open or runs as a node.

---

## Part 2: the changes to the documents

None of these changes a rule of the report.

| # | Change | Where | Decided by |
|---|---|---|---|
| 1 | Keep the check. It is cheap at rest and, given the status premise, not wrong inside Ernest. | nothing to change | principle 1: a program that hangs with no word is the surprise |
| 2 | Retitle the claim, so that it says what is found. | `README.md`'s list of what Ernest adds; `guide/why.md`'s list and the heading of its section; `tour/README.md`'s contents and its chapter 5; `docs/design/site.md`'s *Anchors* and *The homepage* | principle 1 |
| 3 | State the limit in plain words. | `guide/why.md`'s section, `guide/language.md` §5.4 | principle 1 |
| 4 | Drop the typed mailbox from the argument for why the check is decidable. | `guide/why.md`'s paragraph on why Ernest can decide it; a note on the log's *The Sitting on §8.6's Bookkeeping* | the check reads no type |
| 5 | Mark the log's idea of a fault from the calls in flight as unsound. | a note on *What Ernest Adds Stays at Four*, and a new log entry arguing Parts 1 and 3 | §6.6's hand-off |
| 6 | Name the status premise as what the look rests on. | `docs/design/runtime.md`, *The look* | a design note states the rule a mechanism rests on |
| 7 | Hold the four programs of Part 4 as regression tests, where none holds them yet. | `src/runtime/test/`, citing §8.6 | CLAUDE.md's *Tests* |

**Change 2's wording.** The bold name and first sentence of the claim in `guide/why.md`'s list reach the homepage word for word, so both must be honest alone:

> **A program that can never go on is ended.** A program in which every process waits for a message none can send ends with a fault and a trace under `ern run` and `ern test`, where the host would wait forever.

The heading's anchor changes with it, and the site's check catches every link inside. The site is not live yet, so a broken link from outside costs nothing now. `test/fixtures/site/` is a fixture with its own text, to be changed only if a test holds it to the guide.

**Change 3's sentence:**

> A process stuck while another can still run or deliver is not found: two workers waiting on each other in a server with its listener open wait on, as they would on Erlang.

**Why change 2 is due.** The log's *What Ernest Adds Stays at Four* (2026-09-28) refused this claim on principle 1, since a reader who meets it expects to be told of a deadlock. The 2026-10-23 entry gave the claim a program, and a search found no entry that answers that argument.

**What stays.** The fault keeps the name `Fault("deadlock")`, unless question 2 below says otherwise. The word has Go's precedent and fits the textbook's communication deadlock with the whole program as the set.

---

## Part 3: the report of who waits on whom

### What exists

- `Process.status` answers `Running`, `Receiving` or `Calling` (Appendix E.21), and it reads the caller's `CALL` key, which already holds the callee.
- `ern_callees` holds a row for each pending call, keyed by the callee.
- A shell attached to a node is the operator's window, and `:processes` lists each process by its site and activity (§11.2).
- §12.4's lines name each stuck group's site and frame, and "nothing of who waits for whom" (`docs/design/runtime.md`).

So the runtime already knows the edge, and it tells nobody. An operator sees `calling` and cannot see on whom.

### The proposal

1. **The library gives the fact.** `Process.status` says, for a process that is `Calling`, which process it calls and whether the call has no limit. It gives a `Process`, never an `Address`, so nothing can be sent through it and no authority is added: `Process.live()` already hands out every process.
2. **The shell shows it.** `:processes`, or a new command, writes each call's callee by its site, follows the chains, and marks a cycle of calls without limit. It is written in Ernest, over the library's function, as CLAUDE.md's *Shims* asks.
3. **A program may watch for itself.** Since the fact is a library function, a service can read it and log what it finds, at a time of its own choosing.
4. **It states facts and gives no verdict.** It says "these processes call each other" and does not say "deadlock", because a hand-off makes such a cycle legal.

An illustration of the shell's form, which question 5 decides:

```
> :processes
Mutual.main       calling Mutual.first (no limit)
Mutual.first      calling Mutual.second (no limit)
Mutual.second     calling Mutual.first (no limit)
Server.listen     receiving
    a cycle of calls: Mutual.first, Mutual.second
```

### What it never does

- It never faults, kills or ends a process, and it changes nothing it reads.
- It writes no shared row on a call's path, so it keeps the runtime's rule (`docs/design/runtime.md`).
- It costs nothing until it is asked, since only the reader pays.

### Weighed against §0

- **Principle 1, least surprise, decides.** An operator who sees `calling` predicts being able to ask on whom. A report that calls a legal cycle a deadlock would surprise, so it states facts.
- **Principle 2, one way.** Extending `Process.status` adds no second way, where a new `Process.waits` beside it would overlap it.
- **Principle 3, nothing invisible.** The wait is at present invisible to the one person who needs it, and this makes it visible.
- **Principle 5, small.** It adds no concept and no syntax: one field of a library type, and one line of a shell's listing.

### What it does not solve

- A `receive` has no edge, since anyone holding the address may send. The report shows it as the end of a chain, which is often the useful answer.
- A hand-off is invisible, so a cycle may be legal. That is why it gives no verdict.
- The operator must ask. Question 6 weighs telling them.
- A cycle across nodes is not seen from one node. Question 7 weighs it.

### A sound partial check, not proposed

Addresses cannot be forged, so a process whose address and replies no running process can reach can never wake. That is the one real link between types and detection, and it would be sound, even with a hand-off. It is the idea behind Pony's actor collector and Go's recent goroutine-leak work (both from memory, to be checked). It needs a reading of every process's heap, which the host does not appear to offer. Worth one paragraph in the log and nothing more for now.

---

## Part 4: what a design session decides

Nothing below is decided. A design session runs the four programs first and then takes the questions one at a time.

### Read first

`report/language.md` §6.6, §6.9, §8.6, §8.7, §11.2 and `report/toolchain.md` §12.4; `report/library.md` E.21; `docs/design/runtime.md`, `nodes.md`, `shell.md`; `docs/soundness.md`'s claims and §8.6 paragraphs; the log's *Deadlock Is Quiescence*, *What Ernest Adds Stays at Four*, *The Sitting on §8.6's Bookkeeping*; the plan's MVP 4.5.

### Run first

Each is short, kept in the session's scratchpad, and shows a sentence of Part 1. CLAUDE.md asks for the program before a finding is argued.

1. **A long computation.** `main` calls a worker with `callForever`, and the worker computes for some seconds and answers. Expected: the answer, and no fault.
2. **A hand-off through a cycle.** A calls B, B hands A's reply to a worker and then calls A. Expected: all finish, and no fault.
3. **A stuck part.** Two workers in a `callForever` cycle, beside a process with a timer that keeps ticking. Expected: a silent hang, with `calling` shown for both.
4. **The false alarm.** A foreign function starts an unmonitored host process that sends after a while. Expected: `Fault("deadlock")`, and no fault once a monitor of that process stands.

If any of these differs from what is expected, that is a finding, and it comes before the questions.

### The questions, one at a time

Each has a recommendation for the session to test, and not to assume.

1. **What is the claim, and does it stay among the homepage's four?** Recommendation: the wording of Part 2, kept in Why's list. Whether it stays on the homepage is weighed on principle 1, against the 2026-09-28 argument, since the limit does not reach that page.
2. **Does `Fault("deadlock")` keep its name?** Recommendation: yes. It is the textbook's communication deadlock with the whole program as the set, and a new word renames a fault for no gain.
3. **Does §8.6 itself state the limit?** Recommendation: no sentence in the report, since §8.6's "no forward progress is possible" already states it, and the guide teaches it. Test this against principle 1's rule that a departure from what the reader predicts is stated.
4. **What does the fact look like in the library?** Candidates: `Calling` carries the callee and the limit, or `Status` gains a field. Open points: a callee that is a system process, a load's evaluator or a compute's gateway, which `Process.live` and `status` leave out, and an adapted address. Recommendation: `Calling(callee : Optional(Process), limited : Bool)`, weighed against E.0's rules.
5. **What does the shell show?** Candidates: a longer `:processes`, or a command of its own. Recommendation: `:processes`, since it is already what an operator types. A second command is a second way (principle 2).
6. **Does the runtime ever tell unasked?** A line on standard error when a cycle has stood needs a time, and CLAUDE.md asks that a time be derived and never chosen. Nothing here gives one. Recommendation: no line from the runtime. A program that wants one reads the library's function at its own time, as Part 3 says. Name what would change this.
7. **What of a call to another node?** The edge is known, and the callee's `Process` names its node, but `Process.status` answers `None` there. Recommendation: show the edge and stop at the node, the operator attaching there to go on. Walking peers is a later decision, weighed on its messages.
8. **How does the report tell a standing cycle from a passing one?** A snapshot may catch a hand-off in passing. Candidates: the operator reads twice, the call marks its start time, or the second read compares the same `Reply`. Recommendation: test the cost of a start time with `make bench` before deciding, against *What Ernest adds to a host operation costs a fraction of it*. A plain second read is the fallback, since it costs the call nothing.
9. **Does a deadlock's fault name the callee too?** With the same read, §12.4's line could say on whom a group waits, which shows the cycle in `Mutual`'s report. A group of one site and frame may have several callees, which the line form must answer. Recommendation: yes if the form stays simple, as an item of its own.

### What it produces

- This directory's proposal, reported ready once the questions are decided, its README's status line saying so. Until then this document is the discussion.
- Before it is reported ready, a read against every owner it touches: the design notes above, the report's sections, the plan's MVP 4.5 and its seam with `:trace f`, and `docs/soundness.md`.
- The cold reading of any report sentence before the build (CLAUDE.md's *Before code*). E.21's change is built when decided. A change to §8.6 would also rewrite its soundness paragraph in the same commit.

### Then

Back to an item session.

- **Item 1, the documents of Part 2.** They need only `make test-docs`, and belong before the launch, since the launch is when the claim is read most. Its plan line is the session's to place in MVP 4.15 or 4.4.
- **Item 2, the report.** Library, shell and tests, placed by the session. MVP 4.5 is the natural home, since `:trace f` is the same operator's prompt, and it follows the launch.
- **Item 2's checks.** It touches the runtime, so it closes on `make test-full`, and `make bench` shows the call's path unchanged.
