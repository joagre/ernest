# What the tour must cover

The outline read against `why.md`, item by item, and against what a skeptical Erlang or Gleam programmer brings, as `faq.md` and the guide's §10 record it. Section 1 says who the skeptic is, section 2 lists every item of `why.md` with where the outline meets it, section 3 works through the items it misses, section 4 is the chapter list that results, and section 5 what this adds to the feedback file before anything is written.

## 1. The two skeptics

**The Erlang programmer** has processes, `gen_server`, supervisors, hot code loading, distribution and a registry, and has heard of typed Erlangs before. Their questions, in the order they ask them: what does a type buy me on a mailbox; where are `gen_server` and the supervisor; where is `register`; how do I call my Erlang; how do nodes connect without cookies and a mesh; and is hot code loading still there. What turns them is seeing each answered in a running program, and one thing their language cannot do at all: the deadlock found, the message refused across versions, and a node that runs code it never had.

**The Gleam programmer** has the types already, a typed `Subject` for messages, and no type classes; Gleam has neither distribution nor a reload. Their question is sharper: what does the mailbox in the function's type buy over a `Subject`, and what is a `needs` if not a type class. What turns them is the `receive` checked as well as the `send`, a function's type saying it receives, the versions and the nodes, none of which Gleam has.

Both are the guide's reader in a hurry, so the tour shows and points; it argues nowhere, since `why.md` and `faq.md` argue.

## 2. `why.md`, item by item

Each row is a sentence of `why.md`, where the outline of 2026-10-23 meets it, and the verdict: shown by the program, pointed at in a line, or missing.

| `why.md` | The outline | Verdict |
|---|---|---|
| the mailbox type in the function's type; a send refused before the program runs | chapter 1, the `String` refused | shown |
| every receive checked against the mailbox it reads | nowhere | missing, a line (section 3.1) |
| the counter bound at the top of a module under `restarting`, sent to by name: no registry | nowhere | missing, a line (section 3.2) |
| a fault ends the process, nothing catches it, a monitor hears of it as a message | chapter 4 | shown |
| `restarting` keeps the address, the state is lost | chapter 4 | shown |
| foreign code checked, not trusted: a `foreign fn` declares the type, the runtime checks the answer | nowhere | missing, a program (section 3.3) |
| the hash never written; `Upgrade` carries the new loop, the process switches with a tail call, address and state kept | chapter 7 | shown |
| `next` is of the counter's own type: a new message type is a new version | chapters 5 and 6 | shown |
| the shell's versions: `:reload`, `Counter$1.Msg`, a message of the new type to the old process refused with the reason | chapter 5 | shown |
| nothing is purged; a node reloaded without end grows with its versions | nowhere | a line, in chapter 7 |
| the same counter on a peer that holds none of its code; the bare node | chapters 2 and 6 | shown |
| `Peer.spawn` answers `Left` with the reason | chapter 2's `match` | shown |
| `Peer.compute`: work that names no node runs on the less busy of two peers, carrying its code | nowhere | missing, a chapter (section 3.4) |
| a node's `ernest.conf`: peers by name, key and address; a connection from a listed key alone, under that name, over TLS, opened when first needed | chapter 2, by the way | pointed, with a stronger line (section 3.5) |
| `ern config` makes the directory and the key | chapter 2 | shown |
| a service found by its name and the hash of its message type, or `OtherType` | nowhere | missing, a program (section 3.5) |
| a listed peer is trusted whole | nowhere | a line, in chapter 2 |
| a lost peer is a `Down` with `Unreachable` | nowhere | a line at the end (section 3.5) |
| an abstract type keeps its constructor to its module | chapter 5, `Tally` | shown |
| a requirement names the one operation a generic function needs; the compiler supplies the type's own | chapter 5, `report` | shown |
| an operations record, `Operations(..Set)` | nowhere | left to `why.md` (section 3.6) |
| a deadlock is found: a fault and a trace where the host waits forever | chapter 5, one sentence | a program is possible (section 3.7) |
| the look costs a program at work nothing | nowhere | left to `why.md` |
| little else: a report of three files | the closing paragraph | pointed |
| not an OTP application, not mixed with Elixir or Gleam, OTP reached through declarations | the closing paragraph | pointed |

## 3. The missing items

### 3.1 The receive checked too

The Gleam reader's `Subject` checks a send. What is new is the other end: a `receive` is a `match` over the mailbox's type, a clause that cannot run is refused, and a function that receives says so in its type, which is why it runs only in a process of that type. Chapter 1's line at the refusal says both ends in one sentence, and names the guide's §3.4 and §4.1; the FAQ's *What does a typed mailbox catch* carries the rest. No program: a refused clause would be a second rejected input in the first chapter, and the `String` is the one that lands.

### 3.2 The service binding

`why.md`'s first program binds the counter at the top of its module, `export let counter = spawn(restarting(...))`, and every module sends by name: Ernest's answer to `register` and `whereis`. The tour's medium works against showing it: a module's top-level binding is evaluated again at every `:reload`, so a service binding in `counter.ern` would start a new counter at each chapter from 3 on, beside the one the reader holds, and the tally would move to a process the reader did not spawn. The tour says it in one line in chapter 4, where `restarting` is met: a program binds the address at the top of a module and sends by name, and the restart is what keeps the binding good, the guide's §6.5. The Erlang reader's registry question is answered twice more by the program: the service found by name on a peer (section 3.5) and the counters found by `Code.running` in chapter 7.

### 3.3 Foreign code checked, not trusted

The Erlang reader's first practical question is whether their Erlang can be called, and the answer `why.md` gives, that the host's answer is checked against the declared type as it arrives, is Ernest's whole position on interop. The counter needs nothing of the host, so a `foreign fn` enters only where the program asks the host something Ernest has no word for.

The compute chapter (section 3.4) has such a need: before work is placed, the reader asks each peer what machine it is. `erlang:system_info(schedulers)` answers it, and the standard library's `Utilization` does not, since it measures how busy a node is and not how large:

```ernest-fragment
foreign fn systemInfo(what : Foreign.Term) : Int =
    "erlang:system_info/1"

export fn schedulers() : Int =
    systemInfo(Foreign.atom("schedulers"))
```

`Peer.computeAt("foo", fn() = Counter.schedulers(), 5000)` answers `Right(8)` on an eight-core machine. The tour's line: the host promised an `Int`, and the runtime checked it as the answer arrived, naming the guide's §8.3; a declaration `: String` would have faulted the caller at the crossing with the function and the type named. Shown with the right declaration and told for the wrong one, since a planted mistake in a tour is a device to use once (section 3.7 uses it).

### 3.4 `Peer.compute`, work anywhere

`why.md`'s second claim ends with it: a computation that names no node goes to one with room, and no program is deployed first. One bare node cannot show a choice, and the counter has no work that needs room. So the chapter needs a second bare node, `bar`, and work the tour says is invented: a function that counts the primes below a number, run three times, each run printing a line where it runs, so that the second and third terminals show where each landed.

```ernest-fragment
export fn primes(below : Int) : Int = {
    Io.println("counting the primes below " <> Int.toString(below));
    ...   // a sieve, a few lines
}
```

The session: `Peer.utilizations()`, both peers with their utilization and how old it is; `Peer.compute(fn() = Counter.primes(200000), 5000)` three times, answering `Right(17984)` each time, the two terminals sharing the lines; `Peer.computeAt("foo", fn() = Counter.schedulers(), 5000)` from section 3.3. The tour's line: nothing was installed on `foo` or `bar`, and nothing named either, claim 2's last sentence. The guide's §8.1, *Which peer*.

Two facts bound what it can show. A node has no name for itself, so the computed function cannot say where it ran, and the terminals say it instead, which is why the function prints; `docs/language_feedback.md`'s entry 117 decided this on 2026-10-20. And the pick draws two peers at random and takes the less busy, so with two idle peers the three runs may all land on one; the tour says the rule and shows what happened, and the test holds the lines, not their distribution.

This is the one chapter in the tour for a claim and not for the program. The plan's rule says nothing is in the tour for another reason; the chapter bends it for the sentence of `why.md` the Erlang reader most doubts, and says in its first line that it leaves the counter for a page.

### 3.5 The WAN: the service by name and hash, the lost peer

Chapter 2's two files are the WAN claim by the way, and the tour's line there should say the three things the Erlang reader has the opposite of: no cookie, since the key is the identity; no mesh, since a node talks to the peers its file lists and to no other; no port mapper, since one port is opened. One sentence, pointing at the deployment guide's §2.

The service found by name and the hash of its type is the claim's second half, and the registry's cross-node answer. The outline's chapter 6 has the shell reach the peer's counter through the address a compute answered, which works and is a trick: no program finds its services so. The chapter should instead offer the counter as a service on `foo` and find it from the shell:

```ernest-fragment
export fn service() : Peer.Service(ClientMsg) =
    Peer.service("counter")

export fn serve() : Unit = {
    let client = start();
    let _ = Peer.offer(service(), client);
    Unit
}
```

`Peer.spawn("foo", fn() = Counter.serve(), 5000)`, then `let far = match Peer.find(Counter.service(), 5000) { ... }`, printing `far : Address(Counter.ClientMsg)`. `a/ernest.conf` lists `foo` under `"services": {"counter": ["foo"]}`, one more edit in chapter 2. The tour's line: the service is found by its name and the hash of `ClientMsg`, so a shell built against another protocol gets `OtherType` and never a wrong message, claim 3. The deployment guide's §3.1, the guide's §8.2.

`service` and `Tally.empty` are functions for the same reason: a top-level `let` that is no ground term has no value on a bare node (section 5).

The lost peer closes the tour. After the move, `ern stop --config-dir foo` in the second terminal, and the shell says `the peer foo ended`; the tour's last line says a process on it would have been a `Down` with `Unreachable` to whoever monitored it, and that `ern stop --config-dir bar` ends the rest. One command, and the reader has seen a node's whole life.

### 3.6 The operations record

The Gleam reader asks for the type class, and the requirement answers it; the operations record is the third device, for code over two representations, which `why.md` shows and the counter does not need. Left to `why.md`, and the tour's line at `report` says that a function generic in a type names what it needs of it, nothing is declared an instance of anything, and the guide's §7.3 has the rest.

### 3.7 The deadlock, shown

The claim no Erlang programmer believes until they see it, and the outline meets it with a sentence. `ern test` looks for a deadlock where the shell does not, so chapter 5's tests can show it: a second test, written as the reader might write one, that waits for a message nothing sends.

```ernest-fragment
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

`ern test counter.erc` prints the first test passed and `reports: faulted: deadlock`, and the run goes on. The tour's line: the test waits for a message no process can send, and the runtime knows it, where the reader's test framework would wait for its timeout, claim 5. It is the tour's one planted mistake, and the tour says it is one; the fix, a `Report` call in place of the `receive`, is a sentence, not a listing.

## 4. The chapters that result

Eight chapters, each a screen of code and half a screen of prose, the added one marked.

1. **The counter.** As the outline; the line at the refusal says both ends are checked (3.1).
2. **Two bare nodes.** `foo` and `bar` made and started, `a` listing both and the service `counter` on `foo`, all of the operator's work in one place pointing at the deployment guide's §2 and §3.1; the counter spawned on `foo`, the `String` refused; the line on key, mesh and port (3.5).
3. **The client.** As the outline.
4. **A fault.** As the outline; the line on the service binding (3.2).
5. **Per key.** As the outline, with the second test that deadlocks (3.7).
6. **The counter on foo, kept.** The door and the split as the outline; the counter offered as a service on `foo` and found by name and hash (3.5).
7. **Work anywhere** *(added)*. `schedulers` asked of each peer through a `foreign fn` (3.3); `primes` placed by `Peer.compute` three times, the terminals showing where (3.4).
8. **The fix.** As the outline's chapter 7; then `ern stop --config-dir foo`, the shell saying `the peer foo ended` (3.5), and the handover.

The spine holds: the tally is kept from chapter 6 through 7, which does not touch the counters, and through 8's two moves. Chapter 7 is the one chapter for a claim and not for the program, and says so.

## 5. What goes to the feedback file first

The user's rule for this milestone: every line of `docs/language_feedback.md` and of `findings.md` is addressed before the tour is written. The outline's section 6 has four; this reading adds three.

- A `Peer.service(name)` cannot be a top-level `let` in a module a bare node runs, for the ground-term rule, so the tour writes `service()` as it writes `Tally.empty()`: the sharp edge of the outline's first feedback line met a second time in one program. Whether the exchange should evaluate a module's bindings on arrival, as `Code.load` does, is a design question beyond the tour.
- A computed function cannot say where it ran, so the compute chapter shows the node by the line it prints in the peer's terminal; entry 117 decided it on 2026-10-20, and the tour is the first program to feel it.
- `erlang:system_info/1` takes an atom, so one host question costs a `Foreign.atom` beside the declaration; the guide's §8.3 says so, and the tour meets it in its one foreign call.

The finding on `why.md`'s spawn fragment stands as the outline has it.
