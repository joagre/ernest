# The tour's outline

MVP 3.3's first item, read against the report. The plan's sketch of 2026-10-20 (its *The Tour, Shorter*) gives the tour's reader, its rules of form and seven chapters; this outline keeps all of that and works the chapters through against three rules of the report the sketch had not weighed. Where it departs from the sketch it says so, and section 7 lists what it asks the user to decide.

The code in it is a sketch: the names, the exact messages and every line a tool prints are the build's to settle, and `make test` holds the tour to them. The guide's sections named are the ones each chapter points at.

## 1. Three rules that fix the last chapters

**A process keeps its mailbox type for life.** A message of a type's new version to a process of the old one is a type error, and the shell prints the old one as `Counter$1.CounterMsg` (report §11.2). So a reload that changes the message type leaves every running counter on the old protocol, reachable through bindings made before the reload alone, and the only thing to do with such a process from new code is to kill it. A move to new code, `Upgrade`, carries a loop of the process's own type (§6.10): it changes the loop and never the messages.

**A type that carries `Upgrade` is bound to its node.** It holds a function type, so `Peer.spawn` of a loop that receives it is refused, and no address of it crosses (§3.11). A process that is to be moved on another node is started there by a function spawned or computed there, is reached from elsewhere through an adapted address of a type without `Upgrade` (§6.5, §6.10), and is moved by a function run on its node, which finds it with `Code.running` (Appendix E.28).

**`Code.running(f)` lists the processes on `f`'s hash.** A definition is its reach: a loop whose helper changed is a new definition, and the processes on the old one are not listed (Appendix H). So the loop a process was started on stays in the source unchanged, and the fix is a second loop beside it, as the guide's §8.9 and `examples/upgrade/` have it.

Two consequences for the sketch. The counter spawned on the peer in chapter 2 cannot be the one moved in chapter 7: its type has no `Upgrade`, and chapter 5's keys change the type under it. It stays the process the compiler refuses the new protocol to, and the reader kills; the counter moved in chapter 7 is started on the peer in chapter 6, after the last change of the type. And the refusal across versions and the move cannot share one reload: the refusal is a type change, the move a loop change. The refusal is chapter 5's, on the peer's old counter, and the move is chapter 7's.

## 2. The reader, the medium and the rules of form

As the plan has them. The reader is the guide's reader in a hurry; the medium is the shell, `:load`, `:reload` and inputs, with the program in `counter.ern` and from chapter 5 `tally.ern`, edited beside the shell; the one `ern run` starts the bare node in a second terminal, and the one `ern test` runs chapter 5's test. Code first, then what was run and what it printed, then the prose; say do and name the guide's section; one line of the tour's own where the program has just done what the reader's language cannot, naming `why.md`'s claim. The tally is the spine from chapter 6 on, where it is first kept through a change, and chapter 5's loss of it is what chapter 6 answers.

The reader works in a directory of their own, where `counter.ern` is edited chapter by chapter; the shell started in chapter 1 is started again in chapter 2, as a node, and runs to the end.

## 3. The chapters

### 1. The counter

`counter.ern`, the module `Counter`: the message type and the loop of `why.md`'s first program, the loop alone.

```ernest-fragment
type CounterMsg = Inc(Int) | Get(Reply(Int))

export fn count(total : Int) : Unit receiving CounterMsg =
    receive {
        Inc(amount) -> count(total + amount)
      | Get(reply) -> { answer(reply, total); count(total) }
    }
```

The session: `ern shell`, `:load Counter`, `let counter = spawn(fn() = Counter.count(0))`, which prints `counter : Address(Counter.CounterMsg)`; `send(counter, Counter.Inc(5))`; `Address.call(counter, Counter.Get, 1000)`, which prints `Some(5) : Optional(Int)`; and `send(counter, "five")`, refused at the prompt, `the argument does not fit send: expected Counter.CounterMsg, found String`.

What it shows: the mailbox in the function's type, the tour's line at the refusal, claim 1. The guide's §1.2 for the shell, §4.1 for the loop and §4.4 for the call.

### 2. The counter on foo

No change to the program. In a second terminal `ern config --config-dir foo` and `ern config --config-dir a`, each printing its key; `a/ernest.conf` lists `foo` with its key and `127.0.0.1:8654` and loses its `listen`, `foo/ernest.conf` lists `a` with its key and no address; `ern run --config-dir foo` in the second terminal. The first terminal: `ern shell --config-dir a`, `:load Counter`, and

```
> let far = match Peer.spawn("foo", fn() = Counter.count(0), 5000) { Right(a) -> a | Left(e) -> fault(Io.show(e)) }
far : Address(Counter.CounterMsg)
```

then `send(far, Counter.Inc(5))`, the call answering `Some(5)`, and `send(far, "five")` refused as in chapter 1. The second terminal says `the peer a connected`.

What it shows: a process started on a node that holds none of its code, the tour's line at the spawn, claim 2; and by the way the two files that list each other by key, one line pointing at the deployment guide's §2.1, claim 3. The guide's §8.1. The shell started again is said in one sentence: a node is a shell with a configuration directory (the guide's §9.2), and chapter 1's counter ended with its shell.

### 3. The client

`apply(counter, line)`, a function that reads a line and does what it says, answering what to print:

```ernest-fragment
export fn apply(counter : Address(CounterMsg), line : String) : String =
    match String.words(line) {
        ["inc", amount] ->
            match String.toInt(amount) {
                Some(n) -> { send(counter, Inc(n)); "ok" }
              | None -> "not a number: " <> amount
            }
      | ["get"] ->
            match Address.call(counter, Get, 1000) {
                Some(total) -> Int.toString(total)
              | None -> "no answer"
            }
      | _ -> "unknown: " <> line
    }
```

The session: `:reload`, which says `Counter, compiled again` and nothing else, since no type changed; `Counter.apply(counter, "inc 3")` answering `"ok"`, `Counter.apply(far, "get")` answering `"5"`: one function serves both counters, an address being a value.

What it shows: the plain language by the way, a match on a list, `Optional`, strings, with the guide's §2.3, §2.5 and §2.6 named; and `:reload` met where nothing dramatic happens, the guide's §9.3.

### 4. A fault

`count` refuses a negative amount, the precondition in the form the guide's §6.3 gives it; `watch` hears a counter's end:

```ernest-fragment
type WatchMsg = Ended(Down)

export fn count(total : Int) : Unit receiving CounterMsg =
    receive {
        Inc(amount) -> {
            if amount < 0 then fault("a negative amount") else Unit;
            count(total + amount)
        }
      | Get(reply) -> { answer(reply, total); count(total) }
    }

export fn watch(counter : Address(CounterMsg)) : Unit receiving WatchMsg = {
    monitor(Process.fromAddress(counter), Ended);
    receive {
        Ended(Down(reason = reason)) -> Io.println("the counter ended: " <> Io.show(reason))
    }
}
```

The session: `:reload`; `Counter.apply(counter, "inc -1")`, after which the shell prints the fault with its site, and `Counter.apply(counter, "get")` answers `"no answer"`, the process gone. Then `let counter = spawn(restarting(RestartLimit(restarts = 1, within = 5000), fn() = Counter.count(0)))`, `spawn(fn() = Counter.watch(counter))`, `inc 2`, `inc -1`, which the shell reports as `faulted, restarted`, `get` answering `"0"`, the count lost and the address kept, and `inc -1` again, past the limit, after which the watcher prints `the counter ended: Fault("a negative amount")`.

What it shows: a fault ends the process and nothing catches it, a restart keeps the address and loses the state, and whoever monitors hears of an end as a message of their own type: `why.md`'s paragraph under claim 1. The guide's §6.3, §6.4, §6.5 and §5.2. The peer's counter runs on, untouched.

### 5. Per key

`tally.ern`, the module `Tally`, whose type is abstract and whose report needs the key's order; the counter counts per key and holds a tally; one test.

```ernest-fragment
// tally.ern
export abstract type Tally(k) = Tally(Map(k, Int))

export fn empty() : Tally(k) = Tally(Map.empty)
export fn inc(Tally(counts), key, amount) = Tally(Map.update(counts, key, fn(count) = Optional.withDefault(count, 0) + amount))
export fn get(Tally(counts), key) = Optional.withDefault(Map.get(counts, key), 0)
export fn report(Tally(counts)) : List(#(k, Int)) needs k.compare =
    List.sort(Map.toList(counts), fn(#(a, _), #(b, _)) = a.compare(b))
```

```ernest-fragment
// counter.ern
type CounterMsg =
    Inc(key : String, amount : Int)
  | Get(key : String, reply : Reply(Int))
  | Report(reply : Reply(List(#(String, Int))))

export fn count(tally : Tally.Tally(String)) : Unit receiving CounterMsg = ...   // the three clauses, the precondition kept

export fn apply(counter, line) = ...   // inc KEY N, get KEY, report; the report as "apples: 3, pears: 1"

let countsPerKey : Test.Case(m) =
    Test.Case(name = "counts per key", run = fn() = {
        let counter = spawn(fn() = count(Tally.empty()));
        let _ = apply(counter, "inc apples 2");
        let _ = apply(counter, "inc apples 1");
        Test.equal(apply(counter, "get apples"), "3")
    })
```

The session, in the second terminal first: `ern build counter.ern`, which compiles `Tally` with it, and `ern test counter.erc`, one line passed. Then at the prompt `:reload`, which loads `Tally`, compiles `Counter` again and says `Counter.CounterMsg changed: the binding far is of its previous version, Counter$1.CounterMsg`; `Counter.apply(far, "inc apples 2")`, refused, `expected Counter.CounterMsg, found Counter$1.CounterMsg`, with the help that `Counter$1.CounterMsg` is of a previous version; `kill(far)`. Then `let counter = spawn(fn() = Counter.count(Tally.empty()))`, three `inc`s and `Counter.apply(counter, "report")` answering `"apples: 3, pears: 1"`.

What it shows: an abstract type and a requirement, the tour's line at `report`, claim 4; a module worth keeping gets a test, and the one sentence that a test left waiting for a message none can send is faulted with `deadlock` while the run goes on, claim 5, met by a sentence as `why.md` meets it; and the compiler refusing the new protocol to a process on another machine that has run since chapter 2, the tour's line there, claims 1 and 2 meeting. The guide's §7.1, §7.2, §7.3 and §9.3's versions.

`Tally.empty` is a function, since a top-level `let` that is no ground term has no value on a bare node, and chapter 6 spawns the counter there (report §8.7, §11.1); section 6 below.

### 6. The counter on foo, kept

The counter is given the door by which new code reaches it, and the protocol is split: what a client sends, and what the counter itself takes. `start` makes a counter where it is called and answers a client's address.

```ernest-fragment
export type ClientMsg =
    Inc(key : String, amount : Int)
  | Get(key : String, reply : Reply(Int))
  | Report(reply : Reply(List(#(String, Int))))

type CounterMsg =
    Client(ClientMsg)
  | Upgrade(next : (Tally.Tally(String)) -> Unit receiving CounterMsg)

export fn start() : Address(ClientMsg) =
    adapted(spawn(fn() = count(Tally.empty())), Client)

export fn count(tally : Tally.Tally(String)) : Unit receiving CounterMsg =
    receive {
        Client(msg) -> count(handle(tally, msg))
      | Upgrade(next = next) -> next(tally)
    }

fn handle(tally : Tally.Tally(String), msg : ClientMsg) : Tally.Tally(String) =
    match msg { ... }   // chapter 5's three clauses, the precondition kept

export fn apply(counter : Address(ClientMsg), line : String) : String = ...   // unchanged but for the type
```

The session: `:reload`, which names `counter` as of its previous version; `Peer.spawn("foo", fn() = Counter.count(Tally.empty()), 5000)`, refused, `Peer.spawn starts a process whose mailbox type Counter.CounterMsg is bound to its node, since it holds a function`; `kill(counter)`; `let counter = Counter.start()`; `let far = match Peer.computeAt("foo", fn() = Counter.start(), 5000) { ... }`, printing `far : Address(Counter.ClientMsg)`; `inc`s to each, and `Counter.apply(far, "report")`.

What it shows: a type change is a new process, and chapter 5's tally is lost with the old one, as a restart loses it; from here the counter has `Upgrade`, by which a loop changes and the type does not, and the tally is kept through every chapter after. The module `Tally`, which `foo` never had, crossed with the compute, the tour's line, claim 2 again. The guide's §4.6 for `Upgrade`, §8.4 for what is bound, §5.5 for `adapted`.

Both counters are spawned plain, not under `restarting`: a restart runs the function it was given, the old loop, and starts from nothing (report §6.9), which is what chapter 7's fix is for.

### 7. The fix

A client's bad amount ends the counter and its tally, and a restart would start it from nothing. The new loop passes it over, beside the old loop, which stays as it is; `move` moves every counter of its node.

```ernest-fragment
export fn count2(tally : Tally.Tally(String)) : Unit receiving CounterMsg =
    receive {
        Client(Inc(amount = amount)) when amount < 0 -> count2(tally)
      | Client(msg) -> count2(handle(tally, msg))
      | Upgrade(next = next) -> next(tally)
    }

export fn move() : Unit =
    List.forEach(Code.running(count), fn(counter) = send(counter, Upgrade(next = count2)))
```

The session: `:reload`, `Counter, compiled again`, no type changed; `Code.running(Counter.count)` listing one address and `Code.running(Counter.count2)` none, the two versions side by side; `Counter.move()`; the two lists the other way round; `Counter.apply(counter, "inc apples -1")` answering `"ok"` and `report` the tally kept. Then `Peer.spawn("foo", fn() = Counter.move(), 5000)`, which carries `count2` and `move` to a node that never had them; `Counter.apply(far, "inc apples -1")`, `"ok"`; `Counter.apply(far, "report")`, the peer's tally kept.

What it shows: the same process, new code, its state kept, on this node and on one that lacked the code, the tour's last line, claim 2, the peak. `count` stays unchanged since it is how the peer's counters are found, one sentence pointing at the guide's §8.9. The handover: the deployment guide's §8 runs the same move across three nodes with `examples/upgrade/`, and the guide's §9 names the tools.

## 4. The claims, met

Claim 1 in chapter 1, and across versions in chapter 5; claim 2 in chapters 2, 6 and 7; claim 3 by the way in chapter 2; claim 4 in chapter 5; claim 5 by one sentence in chapter 5; claim 6 is the tour's size. Nothing is in the tour for another reason: chapter 3 is the program's client, chapter 4 the fault that chapter 7 fixes, and the test is the one admitted item.

## 5. The layout and the tests

`tour/README.md` is the document, seven chapters, and `tour/1/` to `tour/7/` hold the program as it stands at each chapter's end, `counter.ern` and from `5/` `tally.ern`, so that a reader can start at any chapter. Each block in the document is text of its chapter's program, held equal by a test. The sessions run in the tests as the guide's do: chapter 1's shell over `tour/1/`; one shell started as a node over the chapters' directories in turn, each chapter's files copied in and `:reload` typed, with the bare node started by the nodes' harness; chapter 5's `ern build` and `ern test`. Each printed line in the document is what the tool printed.

The README's three doors, CLAUDE.md's row for `tour/`, and the guide's chapter 1 taste follow the build, as the plan has them.

## 6. What the writing has felt against the principles

Each is an entry of `docs/language_feedback.md` since 2026-10-23, entries 140 to 143 in this order, decided before the tour is written; the two findings below are `docs/findings.md`'s T1 and T2.

- A top-level `let` that is no ground term, `let empty = Tally(Map.empty)`, has no value on a bare node, so a spawn whose reach names it fails with `NotLoaded` (report §8.7, §11.1); the tour's `Tally.empty` is a function for it, where E.0 would have a value. A module written for one node is not spawnable on a bare node until its bindings are ground, and nothing tells the writer before the spawn fails.
- Taking the `Right` of an `Either` at the prompt is a `match` with a `fault` clause, a line of ninety columns at chapter 2's spawn; the guide's `<-` works in a block alone.
- Two nodes on one machine take two `ern config` and four edits of two files by hand, which chapter 2 asks of the reader before the second claim.
- `restarting` runs the function it was given: after an `Upgrade` the next restart runs the old loop again, silently. The tour avoids it by spawning plain; a program under both has a trap nothing names (report §6.9, §6.10).

## 7. What it asks the user to decide

The design question, argued in section 1: the peer's counter of chapter 2 is the one the compiler refuses and the reader kills, and the counter moved in chapter 7 is started on the peer in chapter 6. The sketch's "counting since chapter 2" cannot stand, since a process keeps its mailbox type for life. Recommended as above; the alternative, the type final from chapter 1, puts `Upgrade`, the keys and the split before any program needs them, against the sketch's own rule.

The smaller decisions, each with its recommendation:

1. The door, `Upgrade`, the split into `ClientMsg` and `CounterMsg`, and `adapted`, comes in chapter 6 with the peer, after the last change of the type, and chapter 5's tally is lost there as the chapter's lesson. The alternative puts all of it into chapter 5 with the keys, which is two chapters of code in one. Recommended: chapter 6.
2. The fix is a bad amount passed over, as `count2` with one guard clause beside an unchanged `count`, answering chapter 4. The alternative is the deployment guide's loop that says each `Inc`, visible but unmotivated. Recommended: the former.
3. The bare node is `foo` and the shell's directory `a`, as the guide's §8.1 and `why.md` have them; the deployment guide's §8 keeps `a`, `b`, `c` and `ops`, a floor of three with no bare node in it. Recommended so; `dev` for the shell's directory is the alternative, which says the word the tour leaves unsaid.
4. `Tally.empty` is a function, with the feedback line above. The alternative, `count(Tally.fromList([]))`, hides the same fact. Recommended: the function.
5. Claim 5 is met by one sentence at chapter 5's `ern test`, with no program, as `why.md` meets it; the shell does not look for a deadlock while it holds the terminal (report §11.2). Recommended so.
6. Chapter 4's counter ends by the restart limit, so the `Down` carries the fault, and `kill` first appears in chapter 5 on the peer's old counter. The alternative ends it with `kill` under `Unlimited`. Recommended: the limit.
7. The layout of section 5, `tour/README.md` and `tour/1/` to `tour/7/`. Recommended so.

Two findings beside the outline. `why.md`'s fragment under *Code known by its hash*, `Peer.spawn("foo", fn() = count(0), 5000)`, stands after the type that carries `Upgrade`, at which the spawn is refused as bound (report §3.11); it is a fragment, which nothing checks, and the fix is to name the first claim's counter. And the plan's sketch, items 2 and 7, says what section 1 shows cannot be built; the plan changes when this outline is decided.
