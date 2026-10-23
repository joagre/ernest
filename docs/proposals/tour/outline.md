# The tour's outline

MVP 3.3's first item, read against the report and against `why.md`. The plan's sketch of 2026-10-20 (the log's *The Tour, Shorter*) gives the tour's reader, its rules of form and seven chapters; this outline keeps the reader and the rules, works the chapters through against three rules of the report the sketch had not weighed, and adds the one chapter the reading against `why.md` found missing ([`coverage.md`](coverage.md)). Where it departs from the sketch it says so, section 7 records what was decided with the user, and section 8 the skeptics' read and the spike of 2026-10-23 and what each changed.

The code in it is a sketch, in a layout `ern format` lays out over more lines; the spike of 2026-10-23 ran every session against the toolchain (section 8), so the lines quoted are the toolchain's but for the few the build settles, and `make test` holds the tour to them. A node's line on its terminal or in the shell carries a timestamp, left out here. The guide's sections named are the ones each chapter points at.

## 1. Three rules that fix the last chapters

**A process keeps its mailbox type for life.** A message of a type's new version to a process of the old one is a type error, and the shell prints the old one as `Counter$1.CounterMsg` (report §11.2). So a reload that changes the message type leaves every running counter on the old protocol, reachable through bindings made before the reload alone, and the only thing to do with such a process from new code is to kill it. A move to new code, `Upgrade`, carries a loop of the process's own type (§6.10): it changes the loop and never the messages.

**A type that carries `Upgrade` is bound to its node.** It holds a function type, so `Peer.spawn` of a loop that receives it is refused, and no address of it crosses (§3.11). A process that is to be moved on another node is started there by a function spawned or computed there, is reached from elsewhere through an adapted address of a type without `Upgrade` (§6.5, §6.10), and is moved by a function run on its node, which finds it with `Code.running` (Appendix E.28).

**`Code.running(f)` lists the processes on `f`'s hash.** A definition is its reach: a loop whose helper changed is a new definition, and the processes on the old one are not listed (Appendix H). So the loop a process was started on stays in the source unchanged, and the fix is a second loop beside it, as the guide's §8.9 and `examples/upgrade/` have it.

Two consequences for the sketch. The counter spawned on the peer in chapter 2 cannot be the one moved in the last chapter: its type has no `Upgrade`, and chapter 5's keys change the type under it. It stays the process the compiler refuses the new protocol to, and the reader kills; the counter moved in chapter 8 is started on the peer in chapter 6, after the last change of the type. And the refusal across versions and the move cannot share one reload: the refusal is a type change, the move a loop change. The refusal is chapter 5's, on the peer's old counter, and the move is chapter 8's.

## 2. The reader, the medium and the rules of form

As the plan has them. The reader is the guide's reader in a hurry; the medium is the shell, `:load`, `:reload` and inputs, with the program in `counter.ern` and from chapter 5 `tally.ern`, edited beside the shell; two `ern run` start the bare nodes in a second and a third terminal, and the one `ern test` runs chapter 5's tests. Code first, then what was run and what it printed, then the prose; say do and name the guide's section; one line of the tour's own where the program has just done what the reader's language cannot, naming `why.md`'s claim. The tally is lost twice, at chapter 4's restart and chapter 6's type change, and kept once, across chapter 8's move, which is the point the two losses set up.

The reader works in a directory of their own, where `counter.ern` is edited chapter by chapter; the shell started in chapter 1 is started again in chapter 2, as a node, and runs to the end. The tour shows and points, and argues nowhere, since `why.md` and `faq.md` argue; a planted mistake is a device used once, chapter 5's deadlocking test, and the tour says it is one.

## 3. The chapters

Eight chapters, each a screen of code and half a screen of prose.

### 1. The counter

`counter.ern`, the module `Counter`: the message type and the loop of `why.md`'s first program, the loop alone.

```ernest-fragment
export type CounterMsg = Inc(Int) | Get(Reply(Int))

export fn count(total : Int) : Unit receiving CounterMsg =
    receive {
        Inc(amount) -> count(total + amount)
      | Get(reply) -> { answer(reply, total); count(total) }
    }
```

The session: `ern shell`, `:load Counter`, `let counter = spawn(fn() = Counter.count(0))`, which prints `counter : Address(Counter.CounterMsg)`; `send(counter, Counter.Inc(5))`; `Address.call(counter, Counter.Get, 1000)`, which prints `Some(5) : Optional(Int)`; and `send(counter, "five")`, refused at the prompt, `the argument does not fit send: expected Counter.CounterMsg, found String`, with the input's line and the caret under `"five"`. The type is exported so that the prompt can name its constructors.

What it shows: the mailbox in the function's type, claim 1. The tour's line at the refusal says what the program showed and no more: the mailbox type is in the function's type, so a wrong send is refused before the program runs, and the function runs only in a process of that type. The guide's §1.2 for the shell, §3.4 and §4.1 for the loop and §4.4 for the call; the FAQ has the comparison with a typed channel.

### 2. Two bare nodes

No change to the program. All of the operator's work is here, in a terminal of the reader's own, and points at the deployment guide's §2:

```console
$ ern config --config-dir a
$ ern config --config-dir foo --listen 127.0.0.1:8655
$ ern config --config-dir bar --listen 127.0.0.1:8656
$ ern config --config-dir a --peer-dir foo
$ ern config --config-dir a --peer-dir bar
$ ern config --config-dir foo --peer-dir a
$ ern config --config-dir bar --peer-dir a
```

then `a/ernest.conf` shown once, and `ern run --config-dir foo` and `ern run --config-dir bar`, each in a terminal of its own. `--listen` and `--peer-dir` are MVP 3.296's item 2, built before this chapter is written.

The shell's terminal: `ern shell --config-dir a`, `:load Counter`, `let counter = spawn(fn() = Counter.count(0))` as in chapter 1, since chapter 1's counter ended with its shell, and

```
> let far = match Peer.spawn("foo", fn() = Counter.count(0), 5000) { Right(address) -> address | Left(error) -> fault(Io.show(error)) }
the peer foo connected
far : Address(Counter.CounterMsg)
```

then `send(far, Counter.Inc(5))` and the call answering `Some(5)`. `foo`'s terminal says `the peer a connected`, and nothing before it.

What it shows: a process started on a node that holds none of its code, the tour's line at the spawn, claim 2. The tour's line at the files says, in `why.md`'s words, that two nodes are two files each naming the other by key, with no cluster to join and no shared secret, and that a listed peer is trusted whole, claim 3; the FAQ has the comparison with cookies, the mesh and the port mapper. The guide's §8.1 and the deployment guide's §2. The shell started again is said in one sentence: a node is a shell with a configuration directory (the guide's §9.2).

### 3. The client

`apply(counter, line)`, a function that reads a line and does what it says, answering what to print:

```ernest-fragment
export fn apply(counter : Address(CounterMsg), line : String) : String =
    match String.words(line) {
        ["inc", text] ->
            match String.toInt(text) {
                Some(amount) -> { send(counter, Inc(amount)); "ok" }
              | None -> "not a number: " <> text
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

The session: `:reload`; `kill(counter)` and `let counter = spawn(fn() = Counter.count(0))`, one sentence saying that a process keeps the loop it was started with (report §6.10), which chapter 8 returns to; `Counter.apply(counter, "inc -1")`, after which the shell prints `faulted: a negative amount` with the site, `Counter$3.count:8`, and then `"ok"`, since the send did not wait, one clause each: the `$3` is the version's number, which chapter 5 teaches, and the answer came before the fault. `Counter.apply(counter, "get")` answers `"no answer"`, the process gone. Then `let counter = spawn(restarting(RestartLimit(restarts = 1, within = 5000), fn() = Counter.count(0)))`, `let watcher = spawn(fn() = Counter.watch(counter))`, `inc 2`, `inc -1`, which the shell reports as `faulted, restarted: a negative amount`, `get` answering `"0"`, the count lost and the address kept, and `inc -1` again, past the limit, after which the watcher prints `the counter ended: Fault("a negative amount")`.

What it shows: a fault ends the process and nothing catches it, a restart keeps the address and loses the state, and whoever monitors hears of an end as a message of their own type: `why.md`'s paragraph under claim 1. The tour's line on the service binding, the Erlang reader's `register`: a program binds the address at the top of a module and sends by name, and the restart is what keeps the binding good, the guide's §6.5. The outline's reason for telling and not showing, that a module's top-level binding is evaluated again at every `:reload`, so a counter bound so would be a new process at each chapter, stays out of the tour's text. The guide's §6.3, §6.4, §6.5 and §5.2. The peer's counter runs on, untouched.

### 5. Per key

The counter now counts per key, which is why it gets a module, a build and a test, said in the chapter's first sentence so that the reader is told the turn. `tally.ern`, the module `Tally`, whose type is abstract and whose report needs the key's order; the counter holds a tally; two tests.

```ernest-fragment
// tally.ern
export abstract type Tally(k) = Tally(Map(k, Int))

export fn empty() : Tally(k) = Tally(Map.empty)
export fn inc(Tally(counts), key, amount) = Tally(Map.update(counts, key, fn(count) = Optional.withDefault(count, 0) + amount))
export fn get(Tally(counts), key) = Optional.withDefault(Map.get(counts, key), 0)
export fn report(Tally(counts)) : List(#(k, Int)) needs k.compare =
    List.sort(Map.toList(counts), fn(#(a, _), #(b, _)) = k.compare(a, b))
```

```ernest-fragment
// counter.ern
export type CounterMsg =
    Inc(key : String, amount : Int)
  | Get(key : String, reply : Reply(Int))
  | Report(reply : Reply(List(#(String, Int))))

export fn count(tally : Tally.Tally(String)) : Unit receiving CounterMsg = ...   // the three clauses, the precondition kept

export fn apply(counter, line) = ...   // inc KEY N, get KEY, report; a request with named fields is made in a lambda,
                                      // Address.call(counter, fn(reply) = Get(key = key, reply = reply), 1000); the report as "apples: 3, pears: 1"

let countsPerKey : Test.Case(m) =
    Test.Case(name = "counts per key", run = fn() = {
        let counter = spawn(fn() = count(Tally.empty()));
        let _ = apply(counter, "inc apples 2");
        let _ = apply(counter, "inc apples 1");
        Test.equal(apply(counter, "get apples"), "3")
    })

type TestMsg = Reported(List(#(String, Int)))

let reports : Test.Case(TestMsg) =
    Test.Case(name = "reports", run = fn() = {
        let counter = spawn(fn() = count(Tally.empty()));
        let _ = apply(counter, "inc apples 2");
        receive {
            Reported(entries) -> Test.equal(entries, [#("apples", 2)])
        }
    })
```

The session, in the reader's own terminal first: `ern build .`, which compiles both modules, and `ern test counter.erc`, which prints `counts per key: passed` and `reports: faulted: deadlock` with the test's site, the run going on. Then at the prompt `:reload`, which says `Tally, from tally.erc`, `Counter, compiled again` and `Counter.CounterMsg changed: the bindings counter and far are of its previous version, Counter$3.CounterMsg`, the number that of the last version that held the type (report §11.2), and `counter` chapter 4's ended counter, still bound; `Counter.apply(far, "inc apples 2")`, refused, `expected Address(Counter.CounterMsg), found Address(Counter$3.CounterMsg)`, with the help that `Counter$3.CounterMsg` is of a previous version of `Counter`, which a reload replaced; `kill(far)`, with the forward line that chapter 6 gives the counter the door by which a loop changes without a kill. Then `let counter = spawn(fn() = Counter.count(Tally.empty()))`, three `inc`s and `Counter.apply(counter, "report")` answering `"apples: 3, pears: 1"`.

What it shows: an abstract type and a requirement, the tour's line at `report`, claim 4, saying what the reader wrote at the call for the key's order, nothing, and pointing at the guide's §7.3, where the argument is; the second test waits for a message none can send, and the runtime ends it with a fault where the host would wait forever, in `why.md`'s words, the tour's line, claim 5, the tour's one planted mistake, its fix a `Report` call in place of the `receive`, said in a sentence and made in chapter 6's program, whose two tests spawn with `start()`; and `Test.Case(TestMsg)`, the test's type naming what its `run` receives, the mailbox in the type seen in code, one clause; and the compiler refusing the new protocol to a process on another node that has run since chapter 2, the tour's line there, claims 1 and 2 meeting. The guide's §7.1, §7.2, §7.3 and §9.3's versions.

`Tally.empty` is a function, said in one line pointing at the guide's §8.1: a binding is its node's own, and chapter 6 spawns the counter on a bare node, which evaluated none (report §8.7; decided 2026-10-23, the log's *What the Outline Asked*).

### 6. The door

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

fn handle(tally : Tally.Tally(String), message : ClientMsg) : Tally.Tally(String) =
    match message { ... }   // chapter 5's three clauses, the precondition kept, each answering the tally

export fn apply(counter : Address(ClientMsg), line : String) : String = ...   // unchanged but for the type
```

The session: `:reload`, which names `counter` as of its previous version; `Peer.spawn("foo", fn() = Counter.count(Tally.empty()), 5000)`, refused, `Peer.spawn starts a process whose mailbox type Counter.CounterMsg is bound to its node, since it holds a function`, with the one sentence that reconciles it with chapter 2: a spawned function crosses as code, by its hash, and a function inside a message would have to cross as a value, which none does (the guide's §8.4); `kill(counter)`; `let counter = Counter.start()`; `let far = match Peer.computeAt("foo", fn() = Counter.start(), 5000) { ... }`, printing `far : Address(Counter.ClientMsg)`; `inc`s to each, and `Counter.apply(far, "report")`.

What it shows: a type change is a new process, and chapter 5's tally is lost with the old one, as a restart loses it; from here the counter has `Upgrade`, by which a loop changes and the type does not, and the tally is kept through every chapter after. The module `Tally`, which `foo` never had, crossed with the compute, claim 2 again. The program that started a process holds its address from the spawn or the compute; the tour's line says that another program finds a service by its name and the hash of its message type, claim 3's second half, pointed at and not shown, the deployment guide's §3.1 and the guide's §8.2. The guide's §4.6 for `Upgrade`, §8.4 for what is bound, §5.5 for `adapted`.

Both counters are spawned plain, not under `restarting`, said in one line pointing at report §6.9: a restart runs the function it was given, the old loop, which is what chapter 8's fix is for.

### 7. Work anywhere

The one chapter for a claim and not for the program: `why.md`'s second claim ends with a computation that names no node going to one with room, and no program deployed first. That reason is the outline's; the tour's text says only that the work is invented, the primes below a number, each run printing a line where it runs, so that `foo`'s and `bar`'s terminals show where each landed. First the reader asks each peer the one question in the tour Ernest has no word for, how many schedulers it has, for the crossing's sake alone, which the tour says in a clause.

```ernest-fragment
foreign fn systemInfo(what : Foreign.Term) : Int =
    "erlang:system_info/1"

export fn schedulers() : Int =
    systemInfo(Foreign.atom("schedulers"))

export fn primes(below : Int) : Int = {
    Io.println("counting the primes below " <> Int.toString(below));
    ...   // a sieve over a Set, two helpers, about 0.1 s for 200000
}
```

The session: `Peer.computeAt("foo", fn() = Counter.schedulers(), 5000)` answering `Right(8) : Either(Io.Error, Int)` on an eight-core machine, and the same of `bar`, which the shell first connects here, `the peer bar connected`; `Peer.utilizations()`, `[#("foo", 0.0, 720), #("bar", 0.25, 387)]`, each peer with its utilization and the age of the telling; `Peer.compute(fn() = Counter.primes(200000), 5000)` three times, answering `Right(17984)` each time, the two terminals sharing the lines. The wrong declaration, told, would fault with `the return of foreign function erlang:system_info/1 does not match String`.

What it shows: foreign code checked, not trusted, the tour's line at `schedulers`: the host promised an `Int`, and the runtime checked it as the answer arrived; a declaration `: String` would have faulted the caller at the crossing with the function and the type named, told and not shown, claim 1's boundary; the guide's §8.3. And nothing was installed on `foo` or `bar`, and nothing named either, claim 2's last sentence: the tour states the rule, a computation that names no node goes to the less busy of two drawn, and shows the lines the terminals printed; the guide's §8.1, *Which peer*. Two facts bound it, which stay in the outline: a node has no name for itself, so the function prints and the terminals say where (decided 2026-10-20, the log's *What the Feedback Left*); and with two idle peers the three runs may all land on one, so the test holds the lines, not their distribution. `Peer.setUtilization` on `bar` would make the pick come out the same every time, and was not taken: a demo arranged to come out.

### 8. The fix

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

The session: `:reload`, `Counter, compiled again`, no type changed; `Code.running(Counter.count)` listing one address, this node's, and `Code.running(Counter.count2)` none, the two versions side by side; `Counter.move()`; `report`, the tally kept, whose answer proves the move taken, since the `Upgrade` and the request went from the shell's process to the counter in that order; the two lists the other way round; `Counter.apply(counter, "inc apples -1")` answering `"ok"` and `report` the tally still kept. Then `Peer.computeAt("foo", fn() = Counter.move(), 5000)`, answering `Right(Unit)` once `move` has sent, which carries `count2` and `move` to a node that never had them and puts the `Upgrade` in the peer's counter's mailbox before anything of `a`'s reaches it; `Counter.apply(far, "inc apples -1")`, `"ok"`; `Counter.apply(far, "report")`, the peer's tally kept.

Then, in the second terminal, `ern stop --config-dir foo`, and the shell says `the peer foo ended`; the tour's line says a process on it would have been a `Down` with `Unreachable` to whoever monitored it, that `far` now names a process that ended with its node, so `inc` answers `"ok"` and `report` `"no answer"` at once, and a peer started again is reached by a new spawn or compute, the deployment guide's §2.3, and that `ern stop --config-dir bar` ends the rest. One command, and the reader has seen a node's whole life.

What it shows: the same process, new code, its state kept, on this node and on one that lacked the code, the tour's last line, claim 2, the peak. `count` stays unchanged since it is how the counters are found, until `Code.running(count)` is empty on every node, when it may go, one sentence pointing at the guide's §8.9; nothing is purged, every version a node has loaded stays for the node's life, one line. The handover: the deployment guide's §8 runs the same move across three nodes with `examples/upgrade/`, and the guide's §9 names the tools.

## 4. The claims, met

Claim 1 in chapter 1, its boundary in chapter 7, and across versions in chapter 5; claim 2 in chapters 2, 6, 7 and 8; claim 3 in chapter 2, its second half, the service found by name and type hash, pointed at in chapter 6; claim 4 in chapter 5; claim 5 in chapter 5's second test; claim 6 is the tour's size. Chapter 7 is in the tour for a claim and says so; everything else is in it for the program: chapter 3 is its client, chapter 4 the fault that chapter 8 fixes, and the tests are the one admitted item. What `why.md` has that the tour leaves to it: the operations record and the look's cost ([`coverage.md`](coverage.md), sections 3.6 and 2).

## 5. The layout and the tests

`tour/README.md` is the document, eight chapters, and `tour/1/` to `tour/8/` hold the program as it stands at each chapter's end, `counter.ern` and from `5/` `tally.ern`, so that a reader can start at any chapter. Each block in the document is text of its chapter's program, held equal by a test. The sessions run in the tests as the guide's do: chapter 1's shell over `tour/1/`; one shell started as a node over the chapters' directories in turn, each chapter's files copied in and `:reload` typed, with the two bare nodes started by the nodes' harness; chapter 5's `ern build` and `ern test`, whose expected lines hold `reports: faulted: deadlock`, since `tour/5/` holds the test as the chapter shows it and `tour/6/` the fixed one. Each printed line in the document is what the tool printed, chapter 7's placement lines excepted, which the test holds by their text and not by which terminal printed them.

The README's three doors, CLAUDE.md's row for `tour/`, and the guide's chapter 1 taste follow the build, as the plan has them. The tour's door promises two numbers, an hour to read and about three to do along on a machine with four terminals, and the build measures both.

## 6. What the writing felt against the principles, decided

The six entries this outline and its reading left in `docs/language_feedback.md`, 140 to 145, were decided with the user on 2026-10-23 (the log's *What the Outline Asked*): 140, 141, 144 and 145 dropped, 142 and 143 the two items of MVP 3.296, built before a chapter is written. What each decision fixes in the tour: `Tally.empty` is a function, with chapter 5's line pointing at the guide's §8.1 (140); the `match` with its `fault` clause is written at chapter 2's spawn and chapter 6's compute, and every later take is a function of the program (141); chapter 2's operator work is the commands above and one edit (142); the counters are spawned plain from chapter 6, with the line pointing at report §6.9 (143); chapter 7's function prints where it runs (144); and `schedulers` keeps its atom (145).

The two findings, T1 and T2 of the findings file as it stood at `fd5b361c`: `why.md`'s spawn fragment names the first claim's counter since 2026-10-23, and the plan's sketch is rewritten from this outline when it is decided.

## 7. What was decided

Decided with the user on 2026-10-23, the design question and the eight below, each as recommended. The design question, argued in section 1: the peer's counter of chapter 2 is the one the compiler refuses and the reader kills, and the counter moved in chapter 8 is started on the peer in chapter 6. The sketch's "counting since chapter 2" cannot stand, since a process keeps its mailbox type for life. Recommended as above; the alternative, the type final from chapter 1, puts `Upgrade`, the keys and the split before any program needs them, against the sketch's own rule.

The smaller decisions, each with its recommendation:

1. The door, `Upgrade`, the split into `ClientMsg` and `CounterMsg` and `adapted` come in chapter 6 with the peer, after the last change of the type, and chapter 5's tally is lost there as the chapter's lesson. The alternative puts all of it into chapter 5 with the keys, which is two chapters of code in one. Recommended: chapter 6.
2. The fix is a bad amount passed over, as `count2` with one guard clause beside an unchanged `count`, answering chapter 4. The alternative is the deployment guide's loop that says each `Inc`, visible but unmotivated. Recommended: the former.
3. The bare nodes are `foo` and `bar` and the shell's directory `a`, as the guide's §8.1 and `why.md` have `foo` and `a`; the deployment guide's §8 keeps `a`, `b`, `c` and `ops`, a floor of three with no bare node in it. Recommended so.
4. Both bare nodes are made and started in chapter 2, so that the operator's work stands in one place and no node's configuration changes while it runs; `bar` then idles until chapter 7. The alternative makes `bar` in chapter 7, three lines of the same shape, where `a` must be told of its new peer while its shell runs. Recommended: chapter 2.
5. Claim 5 is shown by chapter 5's second test, the tour's one planted mistake, and not by a sentence as the sketch had it; the shell does not look for a deadlock while it holds the terminal, and `ern test` does (report §11.2). Recommended: the test.
6. Chapter 7, work anywhere, is in the tour for a claim and not for the program, against the plan's rule that nothing is, and says so in its first line; the work is invented and said to be. The alternative leaves `Peer.compute` and the foreign boundary to `why.md`, and the tour then shows four claims of six by a program. Recommended: the chapter.
7. Chapter 4's counter ends by the restart limit, so the `Down` carries the fault; `kill` first appears in chapter 4, on the counter of the old loop. The alternative ends it with `kill` under `Unlimited`. Recommended: the limit.
8. The layout of section 5, `tour/README.md` and `tour/1/` to `tour/8/`, and four terminals: the reader's own, the shell's, `foo`'s and `bar`'s. Recommended so.

Eight chapters, each a screen of code and half a screen of prose, is an evening; the README's door promises how long, and the build measures it.

## 8. The skeptics' read

On 2026-10-23 a fresh reader read this outline three times, as the Erlang programmer, the Gleam programmer and a reviewer holding it to the plan's rules of form and §0, with `why.md`, `coverage.md`'s first three sections and the FAQ beside it. Its verdict: the Gleam reader finishes on chapters 2, 5 and 8; the Erlang reader closes the page at chapter 5's kill unless a line says chapter 6 gives the counter a door; a hurried reader of neither camp finishes if chapter 6 is lightened.

Its continuity findings were corrected at once: chapter 2's shell bound no `counter`; chapter 4 faulted a counter on the old loop; the build and the test ran in `foo`'s terminal; the previous version's number; chapter 6's bound refusal unreconciled with chapter 2's shipped function; `Code.running`'s node and when `count` may go; the spine said kept where it is lost; which directory holds the deadlocking test.

Six decisions, each taken with the user the same day: chapter 6 lightened to the door, the service told and not shown; the lines name the claim and point, the comparisons with other languages' tools left to the FAQ and the writer's reasons to this outline; chapter 7's host question asked for the crossing alone and its sieve shown plain, `Peer.setUtilization` not taken; `Tally` kept, the turn to a vehicle said in chapter 5's first sentence; the README's door promising an hour to read and three to do; and the lost peer's address answered in the closing line.

**The spike.** The same day an agent made the eight programs real and ran every session line against the toolchain, two bare nodes made by chapter 2's commands, the shell driven as the guide's tests drive it. Four places failed as written and are corrected above: the message type must be exported for the prompt to name its constructors; a requirement's member is read on the type variable, `k.compare(a, b)`, not on a value; `ern build counter.ern` does not compile `Tally` with it, and `ern build .` does; and the reload names two bindings, chapter 4's ended counter among them. Everything else behaved as claimed, and the printed lines above are the toolchain's. Noted for the prose: every node line carries a timestamp; the shell prints `the peer foo connected` before the spawn's binding; the fault's trace shows the version's number a chapter before versions are taught; `apply` answers `"ok"` after a fault, since a send does not wait; and a request with named fields is made in a lambda at `Address.call`. The whole tour runs in about eleven seconds of the toolchain's time, each `ern config` in about a third of a second, and `ern test` in half of one. What the spike's writer felt against a principle is `docs/language_feedback.md`'s entries 146 and 147, and the two messages it found wanting were the findings file's S1 and S2, MVP 3.296's item 4.

**The build.** The programs and their tests were built the same day, `tour/1/` to `tour/8/` and `test/ern_tour_tests.erl`, which runs the whole tour under `make test-tour`, a part of `make test-full`, in about thirteen seconds. It found two places where the session rested on timing: `Code.running` typed straight after `Counter.move()`, before the counter had taken its `Upgrade`, and an `inc` to `far` straight after a `Peer.spawn` of `move` on `foo`, which answers when the process starts and before it has sent, so that the `inc` could reach the old loop first and end the counter. Chapter 8 above now reads a `report` between the move and the lists, and moves the peer's counter by `Peer.computeAt`, which answers once `move` has sent. It found too that the shell prints a fault's report, a monitor's line and a peer's connection line in no fixed order against an input's answer, so the prose says "and" and never "then" between them (feedback 148). Decided with the user: the directories keep their numbers, each chapter a program of its own that the reader copies, though `ern build tour` refuses them as one tree; `count2` keeps its name, the report's own in §6.10; and chapter 5's `TestMsg` stands with the module's types, as the style guide orders a module.
