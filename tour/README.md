<picture>
  <source media="(prefers-color-scheme: dark)"
          srcset="../assets/ernest-combined-dark.svg">
  <source media="(prefers-color-scheme: light)"
          srcset="../assets/ernest-combined-light.svg">
  <img src="../assets/ernest-combined-light.svg" alt="Ernest" width="520">
</picture>

# The tour

*The Importance of Being Ernest, a Trivial Comedy for Serious People*

Ernest in an evening: one program, a counter, grown through eight chapters from a process with a typed mailbox to the same counter on a node started with none of its code, moved to new code there. It is for the programmer who has used a functional language and will read neither the report nor the guide first. Every rule the tour meets is the guide's, [*Programming in Ernest*](../guide/language.md), or the [deployment guide](../guide/deployment.md)'s where the operator's world is met, and the tour names the section, the report's where no guide states the rule; what the program has just done that your language cannot, the tour says where it happens, naming the claim of [*Why Ernest*](../guide/why.md) it meets.

An hour to read, and about three to do along, with `ern` installed as the [README](../README.md) says and four terminals: your own, the shell's, and from chapter 2 one for each of two nodes. Each chapter is a change to the program, then what was typed and what was printed, then a few sentences.

The directories `tour/1/` to `tour/8/` hold the program as it stands at the end of each chapter, each a program of its own, so a chapter's build and tests run from its directory alone. Work in a directory of your own, make the nodes' directories in it, copy a chapter's files into it as the chapter begins, and from chapter 2 on the shell you started runs to the end: the sessions of chapters 2 to 8 are one session, and a reader who starts at chapter 5 types chapters 2 to 4 first.

- [1. The counter](#1-the-counter): a process with a typed mailbox, and a wrong message and a wrong mailbox refused
- [2. Two bare nodes](#2-two-bare-nodes): the same counter on a node that holds none of its code
- [3. The client](#3-the-client): a function that reads a line, and a quiet reload
- [4. A fault](#4-a-fault): a process ended, a restart that keeps the address, a watcher told
- [5. Per key](#5-per-key): an abstract type with a requirement, a test, a deadlock found, and a protocol refused across versions
- [6. The door](#6-the-door): the message by which new code will reach the counter
- [7. Work anywhere](#7-work-anywhere): a host question checked at the crossing, and work placed on whichever node has room
- [8. The fix](#8-the-fix): the counters moved to new code with their tallies kept, and a node's end

## 1. The counter

`counter.ern`, the whole program:

```ernest
export type CounterMsg = Inc(Int) | Get(Reply(Int))

export fn count(total : Int) : Unit receiving CounterMsg =
    receive {
        Inc(amount) ->
            count(total + amount)
      | Get(reply) -> {
            answer(reply, total);
            count(total)
        }
    }
```

In the directory that holds it:

```console
$ ern shell
Ernest 0.6.0. :help for the commands, :quit to leave.
> :load Counter
Counter, compiled from counter.ern
> let counter = spawn(fn() = Counter.count(0))
counter : Address(Counter.CounterMsg)
> send(counter, Counter.Inc(5))
> Address.call(counter, Counter.Get, 1000)
Some(5) : Optional(Int)
> send(counter, "five")
input 5:1:15: the argument does not fit send: expected Counter.CounterMsg, found String
1 | send(counter, "five")
  | ---- send : (Address(a), a) -> Unit
  |               ^^^^^^
> fn other() : Unit receiving String = Counter.count(0)
input 6:1:38: Counter.count needs mailbox Counter.CounterMsg, and the mailbox here is String
1 | fn other() : Unit receiving String = Counter.count(0)
  |                             ------ other is declared `receiving String` here
  |                                      ^^^^^^^^^^^^^^^^
```

A counter is a process that holds a number, and `count` is its loop: it takes one message, `Inc` or `Get`, does what the message says, and calls itself with the total. Its type says what it takes, `receiving CounterMsg`; the type and the loop are exported so that the prompt can name `Counter.Inc` and `Counter.count` (the guide's §7.1). `spawn` starts a process on the loop and answers its address, whose type comes from the loop's. `send` puts a message in the mailbox and answers nothing. `Address.call` makes a `Reply`, gives it to `Get`, sends the request and waits up to 1000 milliseconds for the answer, which the counter gives with `answer`: `Some(5)`, where `None` would be an answer that did not come (§4.4).

The last two inputs never run. The address carries the mailbox's type, and a `String` is not a `CounterMsg`; the refusal is placed at `input 5:1:15`, the session's fifth input, line 1, column 15. And `count` receives from its own process's mailbox, so a function whose mailbox takes a `String` cannot call it, though no address is in sight. That is the first claim of *Why Ernest*. The mailbox type is in the function's type, so a wrong send is refused before the program runs, and `count` runs only in a process of that type.

`:load` puts a module in scope: it compiles `counter.ern` from the shell's directory, or takes a compiled form where one is as new, and its line says which; `:quit` ends the shell. The guide's §1.2 has the rest of it.

## 2. Two bare nodes

The program does not change. In your own terminal, in your directory, seven commands:

```console
$ ern config --config-dir a
-----BEGIN PUBLIC KEY-----
MCowBQYDK2VwAyEA6UybIOO9Cx/+QIRHGqSce3mvI+1v/B3pmkxPHm+wLCk=
-----END PUBLIC KEY-----
$ ern config --config-dir foo --listen 127.0.0.1:8655
-----BEGIN PUBLIC KEY-----
MCowBQYDK2VwAyEAt0us/x3+136OtVNkAwklPbf6lv1ZhqfVLwyncvrF3Qw=
-----END PUBLIC KEY-----
$ ern config --config-dir bar --listen 127.0.0.1:8656
-----BEGIN PUBLIC KEY-----
MCowBQYDK2VwAyEANy/2jjlu+c2WNavTjSFQAoHBb9F3IXodXnpM//xyrdI=
-----END PUBLIC KEY-----
$ ern config --config-dir a --peer-dir foo
$ ern config --config-dir a --peer-dir bar
$ ern config --config-dir foo --peer-dir a
$ ern config --config-dir bar --peer-dir a
```

`a/ernest.conf` now reads:

```json
{
  "listen": "0.0.0.0:8654",
  "public-key": "-----BEGIN PUBLIC KEY-----\nMCowBQYDK2VwAyEA6UybIOO9Cx/+QIRHGqSce3mvI+1v/B3pmkxPHm+wLCk=\n-----END PUBLIC KEY-----\n",
  "peers": [
    {
      "name": "foo",
      "network-address": "127.0.0.1:8655",
      "public-key": "-----BEGIN PUBLIC KEY-----\nMCowBQYDK2VwAyEAt0us/x3+136OtVNkAwklPbf6lv1ZhqfVLwyncvrF3Qw=\n-----END PUBLIC KEY-----\n"
    },
    {
      "name": "bar",
      "network-address": "127.0.0.1:8656",
      "public-key": "-----BEGIN PUBLIC KEY-----\nMCowBQYDK2VwAyEANy/2jjlu+c2WNavTjSFQAoHBb9F3IXodXnpM//xyrdI=\n-----END PUBLIC KEY-----\n"
    }
  ],
  "services": {}
}
```

In a second terminal `ern run --config-dir foo`, in a third `ern run --config-dir bar`; each says where it listens, `listening on 127.0.0.1:8655` for `foo`, and waits. Then the shell, started again in your directory as a node:

```console
$ ern shell --config-dir a
listening on 0.0.0.0:8654
Ernest 0.6.0. :help for the commands, :quit to leave.
> :load Counter
Counter, compiled from counter.ern
> let counter = spawn(fn() = Counter.count(0))
counter : Address(Counter.CounterMsg)
> let far <- Peer.spawn("foo", fn() = Counter.count(0), 5000)
the peer foo connected
far : Address(Counter.CounterMsg)
> send(far, Counter.Inc(5))
> Address.call(far, Counter.Get, 1000)
Some(5) : Optional(Int)
```

`foo`'s terminal says `the peer a connected`. At a terminal a node's line, there and in the shell, is as shown; where standard error is a file or a pipe, it begins with the time (the deployment guide's §1.4).

A node is a program, or a shell, started with a configuration directory, and `ern config` makes one: a key, a certificate, and `ernest.conf` with the port the node listens on. `a` keeps the port `ern config` gives, 8654 on every interface, and `--listen` gives `foo` and `bar` ports of their own, since three nodes on one machine cannot share one, and `--peer-dir` lists one node in another's file by the name of its directory, its key and its address, read from the directory.

A node accepts a connection from a listed key alone, and nothing else is set up: two nodes are two configuration files each naming the other, with no cluster to join and no shared secret, the third claim of *Why Ernest* (the deployment guide's §2). `foo` and `bar` are *bare nodes*, started with no program: they hold nothing of the counter's and wait for work.

`Peer.spawn` starts `count` on `foo` and answers `Right(address)`, or `Left(error)` with the reason it could not, an `Either`; `let far <-` binds the address inside a `Right`, as `<-` does in a block, and on a `Left` binds nothing and shows the reason, `Left(NotListed)` where no peer is named `foo` (the guide's §2.7). The shell connected to `foo` as the spawn needed it, and `count` crossed with the spawn, since `foo` had no code of it. The counter there is then the counter of chapter 1: the same `send`, the same call, the same answer. That is the second claim of *Why Ernest*: a process started on another node brings its code along, and nothing was installed first.

Chapter 1's counter ended with its shell; this shell runs to the end of the tour. A shell started with `--config-dir` is a node like any other (the guide's §9.2 and §8.1). A node started with a program reads every compiled module under the program's directory at its start, where `ern run` without a configuration reads only those the program uses, so an `.erc` there built from another source root keeps the node from starting (the deployment guide's §5.1).

## 3. The client

`counter.ern` gains a function that reads a line and does what it says, answering what to print:

```ernest
export fn apply(counter : Address(CounterMsg), line : String) : String =
    match String.words(line) {
        ["inc", text] ->
            match String.toInt(text) {
                Some(amount) -> {
                    send(counter, Inc(amount));
                    "ok"
                }
              | None ->
                    "not a number: " <> text
            }
      | ["get"] ->
            match Address.call(counter, Get, 1000) {
                Some(total) -> Int.toString(total)
              | None -> "no answer"
            }
      | _ ->
            "unknown: " <> line
    }
```

```console
> :reload
Counter, compiled again
> Counter.apply(counter, "inc 3")
"ok" : String
> Counter.apply(far, "get")
"5" : String
```

`apply` is the plain language in passing: a `match` over the list of words, with a pattern for each shape of line; `Optional`, `Some(amount)` or `None`, for a number that may not parse; strings joined with `<>` (the guide's §2.3, §2.5 and §2.6). It sends an `Inc` without waiting and answers `"ok"`, and asks for the total with the call of chapter 1.

`:reload` compiles again every loaded module whose source changed, and says so and nothing more: no type changed, so every binding of the session stands as it was (the guide's §9.3). The counter `apply` is given is a value like any other, so the same function serves the counter here and the one on `foo`, which still holds its 5.

## 4. A fault

`count` refuses a negative amount, and `watch` hears a counter's end:

```ernest
type WatchMsg = Ended(Down)

export fn count(total : Int) : Unit receiving CounterMsg =
    receive {
        Inc(amount) -> {
            if amount < 0 then fault("a negative amount") else Unit;
            count(total + amount)
        }
      | Get(reply) -> {
            answer(reply, total);
            count(total)
        }
    }

export fn watch(counter : Address(CounterMsg)) : Unit receiving WatchMsg = {
    monitor(Process.fromAddress(counter), Ended);
    receive {
        Ended(Down(reason = reason)) -> Io.println("the counter ended: " <> Io.show(reason))
    }
}
```

The counter of chapter 3 keeps the loop it was started with, so `kill` ends it from outside and a new one is spawned on the new loop (the guide's §4.6); the new one is given a bad amount:

```console
> :reload
Counter, compiled again
> kill(counter)
> let counter = spawn(fn() = Counter.count(0))
counter : Address(Counter.CounterMsg)
> Counter.apply(counter, "inc -1")
"ok" : String
input 11:1 faulted: a negative amount
    Counter$3.count:8
> Counter.apply(counter, "get")
"no answer" : String
```

The precondition is written as the guide's §6.3 writes one: `fault` ends the process with its cause, and nothing catches it, since there is no handler to write; a process that must outlive a fault is restarted, below. The `inc -1` answers `"ok"`, since a send does not wait, and the fault is reported as the counter meets it, under the input that spawned the process, `input 11:1`, and the place it faulted, `Counter$3.count:8`; the `$3` numbers the module's versions in this session, which chapter 5 comes to. The report and the answer are written as each happens, in no fixed order; the page shows one. The next `get` has no one to answer it.

A counter that must come back is started under `restarting`, and a watcher monitors it:

```console
> let counter = spawn(restarting(RestartLimit(restarts = 1, within = 60000), fn() = Counter.count(0)))
counter : Address(Counter.CounterMsg)
> let watcher = spawn(fn() = Counter.watch(counter))
watcher : Address(Counter.WatchMsg)
> Counter.apply(counter, "inc 2")
"ok" : String
> Counter.apply(counter, "inc -1")
"ok" : String
input 14:1 faulted, restarted: a negative amount
    Counter$3.count:8
> Counter.apply(counter, "get")
"0" : String
```

A process started under `restarting` runs its function again from the start after a fault, its mailbox emptied and its address kept, so `counter` is still good and the count is gone: `"0"` (§6.5). The limit allows one restart in a minute, so the next fault within that minute is the end:

```console
> Counter.apply(counter, "inc -1")
"ok" : String
input 14:1 faulted: a negative amount
    Counter$3.count:8
the counter ended: Fault("a negative amount")
```

`watch` monitors the counter, giving `monitor` the constructor that wraps the end into the watcher's own type, so the end arrives as `Ended(Down(...))`, a `Down` whose reason is the fault, `Fault` with its cause (§5.2, §6.4). Here too the fault's report and the watcher's line may come in either order.

A program binds such an address at the top of a module and sends to it by name, and the restart is what keeps the binding good; that is a *service*, the guide's §6.5, which the tour's counters at the prompt do not need. The counter on `foo` has felt nothing of this.

## 5. Per key

The counter now counts per key, which is why it gets a module, a build and a test. `tally.ern`, a second file beside `counter.ern`:

```ernest
export abstract type Tally(k) = Tally(Map(k, Int))

export fn empty() : Tally(k) =
    Tally(Map.empty)

export fn inc(Tally(counts) : Tally(k), key : k, amount : Int) : Tally(k) =
    Tally(Map.update(counts, key, fn(count) = Optional.withDefault(count, 0) + amount))

export fn get(Tally(counts) : Tally(k), key : k) : Int =
    Optional.withDefault(Map.get(counts, key), 0)

export fn report(Tally(counts) : Tally(k)) : List(#(k, Int)) needs k.compare =
    List.sortBy(Map.toList(counts), fn(#(key, _)) = key)
```

Below are `counter.ern`'s type, its loop, the helper that writes a report, and two tests; `apply` grows a key, `inc apples 2` and `get apples`, and a `report`, as `tour/5/` has it. The second test is the tour's one planted mistake: it waits for a message nothing sends.

```ernest
export type CounterMsg =
    Inc(key : String, amount : Int)
  | Get(key : String, reply : Reply(Int))
  | Report(reply : Reply(List(#(String, Int))))

type TestMsg = Reported(List(#(String, Int)))

export fn count(tally : Tally.Tally(String)) : Unit receiving CounterMsg =
    receive {
        Inc(key = key, amount = amount) -> {
            if amount < 0 then fault("a negative amount") else Unit;
            count(Tally.inc(tally, key, amount))
        }
      | Get(key = key, reply = reply) -> {
            answer(reply, Tally.get(tally, key));
            count(tally)
        }
      | Report(reply = reply) -> {
            answer(reply, Tally.report(tally));
            count(tally)
        }
    }

fn shown(entries : List(#(String, Int))) : String =
    String.join(List.map(entries, fn(#(key, total)) = key <> ": " <> Int.toString(total)), ", ")

let countsPerKey : Test.Case(m) = Test.Case(name = "counts per key", run = fn() = {
    let counter = spawn(fn() = count(Tally.empty()));
    let _ = apply(counter, "inc apples 2");
    let _ = apply(counter, "inc apples 1");
    Test.equal(apply(counter, "get apples"), "3")
})

let reports : Test.Case(TestMsg) = Test.Case(name = "reports", run = fn() = {
    let counter = spawn(fn() = count(Tally.empty()));
    let _ = apply(counter, "inc apples 2");
    receive {
        Reported(entries) -> Test.equal(entries, [#("apples", 2)])
    }
})
```

`Tally` is an *abstract type*: its constructor is its module's alone, so `counter.ern` holds a tally through `empty`, `inc`, `get` and `report` and never sees the map inside (the guide's §7.1, §7.2).

The notation is the guide's §2.3 to §2.5: `#(k, Int)` is a tuple, a constructor's fields may be named and are matched by name, `Tally(counts) : Tally(k)` takes a parameter apart in the head, and `let _ =` discards a value on purpose. `report` sorts by the key, and says what it needs of the key's type, `needs k.compare`; at the call in `count` you wrote nothing, and the compiler supplied `String`'s own `compare`. That is the fourth claim of *Why Ernest*. A generic function names the operations it needs of its type, and the compiler supplies that type's own at each call; the guide's §7.3 has the rules.

`empty` is a function and not a value: a binding `let empty = Tally(Map.empty)` would be evaluated only on a node that loaded the module, and chapter 6 spawns this counter on a node that loaded nothing. A *constant*, a binding written in literals, constructors, tuples and lists alone, has its value wherever its code is, and the standard library's values, `Map.empty` among them, are on every node, since every node holds the library (the guide's §2.2, §8.1).

In your own terminal:

```console
$ ern build .
$ ern test counter.erc
counts per key: passed
reports: faulted: deadlock
    Counter.reports:70
    1 process of Counter.countsPerKey:62 waits in Counter.count:10
    1 process of Counter.reports:69 waits in Counter.count:10
```

A module worth keeping gets a test: `ern build .` compiles both modules, and `ern test` runs every `Test.Case` the program declares (the guide's §7.1). The planted test waits for a `Reported` that no process sends, and the runtime ends it with a fault where your test framework would wait for its timeout, the trace naming the line of the last call before the wait, since a wait leaves no frame of its own (report Appendix E.21): that is the fifth claim of *Why Ernest*, a program in which every process waits for a message none can send is a deadlock, found.

Beneath the trace come the processes left waiting, a line for each spawn site and the frame its processes wait in (report §12.4): the planted test's counter, and the first test's, which outlived its test.

The fix, a `Report` call in place of the `receive`, is chapter 6's. The test's type, `Test.Case(TestMsg)`, is the mailbox in the type once more: its `run` receives, so its type says what; the first test's `Test.Case(m)` leaves it open, since its `run` receives nothing.

At the shell, the reload brings the new type in, and the counter on `foo` is still of the old one:

```console
> :reload
Tally, from tally.erc
Counter, compiled again
Counter.CounterMsg changed: the bindings counter and far are of its previous version, Counter$3.CounterMsg
> Counter.apply(far, "inc apples 2")
input 21:1:15: the argument does not fit Counter.apply: expected Address(Counter.CounterMsg), found Address(Counter$3.CounterMsg)
1 | Counter.apply(far, "inc apples 2")
  | ------------- Counter.apply : (Address(Counter.CounterMsg), String) -> String
  |               ^^^
  | = help: the types differ at Counter.CounterMsg and Counter$3.CounterMsg; Counter$3.CounterMsg is of a previous version of Counter, which a reload replaced
> kill(far)
```

`:reload` brings `Tally` in from the build and compiles `Counter` again, and this time a type changed. Each reload makes a *version* of the module, counted from the first load, `Counter$3` now the previous one; a process keeps its mailbox type for life, so the two counters spawned under the old type, chapter 4's ended one and the one on `foo`, are of `Counter$3.CounterMsg`, though `far` was spawned under the first: a type several versions hold unchanged takes the number of the last of them (report §11.2), and the compiler refuses them the new protocol, the new mailbox type, with the reason (the guide's §9.3).

The first claim and the second meet here: a process on another node that has run since chapter 2 cannot be sent what it does not take, and only `far`, bound before the reload, still reaches it. It is killed; chapter 6 gives the counter a door by which its code changes without a kill. A new counter counts per key:

```console
> let counter = spawn(fn() = Counter.count(Tally.empty()))
counter : Address(Counter.CounterMsg)
> Counter.apply(counter, "inc apples 2")
"ok" : String
> Counter.apply(counter, "inc pears 1")
"ok" : String
> Counter.apply(counter, "inc apples 1")
"ok" : String
> Counter.apply(counter, "report")
"apples: 3, pears: 1" : String
```

## 6. The door

The counter is given the door by which new code will reach it, and its protocol is split in two: what a client sends, and what the counter itself takes. `start` makes a counter where it is called and answers a client's address; `watch` and `apply` take `Address(ClientMsg)` and change in nothing else, and `shown` is unchanged:

```ernest
export type ClientMsg =
    Inc(key : String, amount : Int)
  | Get(key : String, reply : Reply(Int))
  | Report(reply : Reply(List(#(String, Int))))

type CounterMsg =
    Client(ClientMsg)
  | Upgrade(next : (Tally.Tally(String)) -> Unit receiving CounterMsg)

type WatchMsg = Ended(Down)

export fn start() : Address(ClientMsg) =
    adapted(spawn(fn() = count(Tally.empty())), Client)

export fn count(tally : Tally.Tally(String)) : Unit receiving CounterMsg =
    receive {
        Client(message) -> count(handle(tally, message))
      | Upgrade(next = next) -> next(tally)
    }

fn handle(tally : Tally.Tally(String), message : ClientMsg) : Tally.Tally(String) =
    match message {
        Inc(key = key, amount = amount) -> {
            if amount < 0 then fault("a negative amount") else Unit;
            Tally.inc(tally, key, amount)
        }
      | Get(key = key, reply = reply) -> {
            answer(reply, Tally.get(tally, key));
            tally
        }
      | Report(reply = reply) -> {
            answer(reply, Tally.report(tally));
            tally
        }
    }
```

The tests spawn with `start()`, and the second asks for its report instead of waiting for one:

```ernest
let reports : Test.Case(m) = Test.Case(name = "reports", run = fn() = {
    let counter = start();
    let _ = apply(counter, "inc apples 2");
    Test.equal(Address.call(counter, fn(reply) = Report(reply = reply), 1000),
               Some([#("apples", 2)]))
})
```

```console
> :reload
Counter, compiled again
Counter.CounterMsg changed: the binding counter is of its previous version, Counter$4.CounterMsg
> Peer.spawn("foo", fn() = Counter.count(Tally.empty()), 5000)
input 29:1:19: Peer.spawn starts a process whose mailbox type Counter.CounterMsg is bound to its node, since it holds a function
1 | Peer.spawn("foo", fn() = Counter.count(Tally.empty()), 5000)
  |                   ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  | = help: keep a function on this node and send the process values that cross, or spawn on this node (report §3.11)
> kill(counter)
> let counter = Counter.start()
counter : Address(Counter.ClientMsg)
> let far <- Peer.computeAt("foo", fn() = Counter.start(), 5000)
far : Address(Counter.ClientMsg)
> Counter.apply(counter, "inc apples 2")
"ok" : String
> Counter.apply(far, "inc apples 3")
"ok" : String
> Counter.apply(far, "inc pears 1")
"ok" : String
> Counter.apply(far, "report")
"apples: 3, pears: 1" : String
```

`Upgrade` carries the loop the counter is to run next, a function of the counter's own type, and the loop switches to it with a tail call, keeping the tally (the guide's §4.6). A function cannot cross to another node as a value, so a type that carries one is *bound* to its node, and `Peer.spawn` refuses the loop that receives it (§8.4). The spawn of chapter 2 carried `count` as code, by its hash, and this spawn would have to carry a function as a message's value, which nothing does.

So the counter's messages are two types: `ClientMsg`, what a client sends, which crosses, and `CounterMsg`, which wraps each client message in `Client` and adds the door. `start` spawns the loop and answers an *adapted address*, an `Address(ClientMsg)` whose messages reach the counter as `Client(...)` (§5.5), and the client, `apply`, knows nothing of the door. Such an address crosses to another node though it holds `Client`, since its function never leaves the node that made it: a message to the address from elsewhere is wrapped there, by a process of the runtime's, before the counter sees it.

The type changed again, so chapter 5's counter is killed and its tally lost, as a restart loses one; from here the counter's type does not change, and the tally is kept through everything that follows. `start` runs on `foo` by `Peer.computeAt`, which runs a function on the named peer and answers its value, here the address: `Tally`, which `foo` never had, crossed with the compute, as `count` did with the spawn in chapter 2, the second claim once more. A program that did not start a process finds it as a service, by its name and the hash of its message type, which the deployment guide's §3.1 and the guide's §8.2 have; the tour's shell started both counters and holds their addresses.

Both counters are spawned plain, with no `restarting` around them: a restart runs the function it was given, so a counter moved to new code through its door would fall back to the old loop at its next fault (report §6.9); how a service under `restarting` takes new code is the deployment guide's §5.3.

## 7. Work anywhere

This chapter leaves the counter for a page. `counter.ern` gains a question to the host and some invented work, the primes below a number:

```ernest
export fn schedulers() : Int =
    systemInfo(Foreign.atom("schedulers"))

foreign fn systemInfo(item : Foreign.Term) : Int =
    "erlang:system_info/1"

export fn primes(below : Int) : Int = {
    Io.println("counting the primes below " <> Int.toString(below));
    List.size(List.filter(List.range(2, below - 1), isPrime))
}

fn isPrime(number : Int) : Bool =
    hasNoDivisorFrom(number, 2)

// A divisor above the square root of `number` pairs with one below it,
// so the search stops there.
fn hasNoDivisorFrom(number : Int, divisor : Int) : Bool =
    divisor * divisor > number || number % divisor != 0 && hasNoDivisorFrom(number, divisor + 1)
```

First the question, asked on each bare node:

```console
> :reload
Counter, compiled again
> Peer.computeAt("foo", fn() = Counter.schedulers(), 5000)
Right(8) : Either(Io.Error, Int)
> Peer.computeAt("bar", fn() = Counter.schedulers(), 5000)
the peer bar connected
Right(8) : Either(Io.Error, Int)
```

The host's own code, Erlang's libraries and whatever else runs on the runtime, is *foreign code* to a program, reached through a `foreign fn` that declares the Ernest type of a host function; `erlang:system_info/1` takes an atom, so the question is passed as one (the guide's §8.3). The declaration promised an `Int` of the host, and the runtime checked the answer against it as it arrived; declared `: String`, the same call faults its caller at the crossing, `the return of foreign function erlang:system_info/1 does not match String`, naming the function and the type.

That is the first claim of *Why Ernest* at its boundary: the type is checked, not trusted, and a wrong value from the host is a fault where it crosses, not a crash later in code that believed it. The shell connected to `bar` as the first compute on it needed to, and `bar`'s terminal says `the peer a connected`. With these two computes both peers are connected, and each has told the shell how busy it is, as a peer does as it connects, so the computes below that name no node have utilizations to draw by (report Appendix E.27).

Then the work, three times, naming no node:

```console
> Peer.utilizations()
[#("foo", 0.0, 720), #("bar", 0.25, 387)] : List(#(String, Float, Int))
> Peer.compute(fn() = Counter.primes(200000), 5000)
Right(17984) : Either(Io.Error, Int)
> Peer.compute(fn() = Counter.primes(200000), 5000)
Right(17984) : Either(Io.Error, Int)
> Peer.compute(fn() = Counter.primes(200000), 5000)
Right(17984) : Either(Io.Error, Int)
```

Each compute printed `counting the primes below 200000` in the terminal of the node that ran it, `foo`'s all three times in the run the page shows. Each node tells its peers how busy it is, on a scale where 1.0 is every scheduler busy, and `Peer.utilizations()` is what the shell has heard: each peer, its utilization and how many milliseconds ago it said so.

`Peer.compute` draws two of the peers at random, both of them here, and runs the function on the one that was less busy at its last telling, carrying its code there as the spawn did, and answers the value; the tellings come every few seconds, so which node ran each is the terminals' to show, and the program never names one (the guide's §8.1, *Which peer*). With two peers the draw takes both each time, so the computes made within one telling go to the one less busy at it; a draw spreads them only among three peers or more.

`bar` reads 0.25, though it has no work of yours: a node tells a peer how busy it is as the peer connects, and at that moment the processes that open the connection are running or ready to run, which is what a node counts by default, over its schedulers (the deployment guide's §3.2). Its next telling, five seconds later, reads it idle.

The number is written into each lambda, since a `let` typed at the prompt is a binding of the shell's node, which no peer has: after `let below = 200000`, `Peer.compute(fn() = Counter.primes(below), 5000)` answers `Left(Io.NotLoaded)`, where `{ let n = below; Peer.compute(fn() = Counter.primes(n), 5000) }` carries the value, a local the lambda captures (the guide's §8.1).

Nothing was installed on `foo` or `bar`, and nothing named either: that is the last sentence of the second claim of *Why Ernest*, a computation that names no node goes to the less busy of two peers drawn at random, and no program is deployed first.

## 8. The fix

A client's bad amount ends the counter and its tally, and a restart would start it from nothing. The new loop passes it over, beside the old loop, which stays as it is; `move` moves every counter of its node:

```ernest
export fn count2(tally : Tally.Tally(String)) : Unit receiving CounterMsg =
    receive {
        Client(Inc(amount = amount)) when amount < 0 -> count2(tally)
      | Client(message) -> count2(handle(tally, message))
      | Upgrade(next = next) -> next(tally)
    }

export fn move() : Unit =
    List.forEach(Code.running(count), fn(counter) = send(counter, Upgrade(next = count2)))
```

First on this node:

```console
> :reload
Counter, compiled again
> Code.running(Counter.count)
[<address 221>] : List(Address(Counter.CounterMsg))
> Code.running(Counter.count2)
[] : List(Address(Counter.CounterMsg))
> Counter.move()
> Counter.apply(counter, "report")
"apples: 2" : String
> Code.running(Counter.count)
[] : List(Address(Counter.CounterMsg))
> Code.running(Counter.count2)
[<address 221>] : List(Address(Counter.CounterMsg))
> Counter.apply(counter, "inc apples -1")
"ok" : String
> Counter.apply(counter, "report")
"apples: 2" : String
```

`Code.running(f)` lists the processes on this node that are running `f`, by the hash of its definition, so the two lists are the two versions side by side. It is a *form*, written as a call and read by the compiler by a rule of its own, `f` the name of a top-level `fn` (the guide's §8.9). `move` sends each counter on the old loop its `Upgrade`, `next` a function of this node's that never crosses, and the counter switches to `count2` with its tally in hand. The `report` in between was answered after the `Upgrade`: a `send` puts its message in the mailbox before it returns, and the shell runs an input only once the one before it has ended (the guide's §1.2, §4.1). The lists then read the other way round, the same address in each, which is what shows where the process now runs.

`Client(Inc(amount = amount)) when amount < 0` names one field and guards the clause (the guide's §2.6). A negative amount is now passed over, and the tally stands.

That is the second claim of *Why Ernest* at its peak: the same process, new code, its state kept, told by a message of its own type. `count` stays in the source unchanged, since it is how the counters still on it are found, until `Code.running(count)` is empty on every node and it may go; nothing a node has loaded is unloaded while it runs, so a node reloaded without end grows with its versions (the guide's §8.9, the deployment guide's §4.2).

Then on `foo`, which never had `count2` or `move`:

```console
> Peer.computeAt("foo", fn() = Counter.move(), 5000)
Right(Unit) : Either(Io.Error, Unit)
> Counter.apply(far, "inc apples -1")
"ok" : String
> Counter.apply(far, "report")
"apples: 3, pears: 1" : String
```

The compute carried the new loop and `move` to `foo` and ran `move` there, where `Code.running` finds `foo`'s counter and sends it the door's message, so no function crossed in a message. It answered once `move` had sent, and a `send` on the counter's own node puts its message in the mailbox before it returns (the guide's §4.1), so the `Upgrade` was there before anything of ours reached it. The counter on the node started with none of this program's code runs its new code, with the tally it has counted since chapter 6.

In your own terminal, `ern stop --config-dir foo`, and the shell says:

```console
the peer foo ended
> Counter.apply(far, "inc apples 1")
"ok" : String
> Counter.apply(far, "report")
"no answer" : String
```

`ern stop` ends a node in order, and the shell is told. `far` now names a process that ended with its node: the send answers `"ok"` and is dropped, and the request has no one to answer it, at once; a process that monitored the counter would have heard a `Down` with the reason `ProgramEnd`, and a peer started again is reached by a new spawn or compute, since its processes are gone with it (the deployment guide's §2.3). `ern stop --config-dir bar` ends the rest, and the shell says `the peer bar ended`. One command, and you have seen a node's whole life.

The tour ends here, where the operator's work begins. The deployment guide's §8 runs this move across three nodes with `examples/upgrade/`, and the deployment guide's §5.3 is the operator's side of it; the guide's §9 names the tools, and the guide's §8.9 the rule the move rests on.
