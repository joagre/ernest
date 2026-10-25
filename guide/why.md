# Why Ernest

The argument for the design, in six claims, four of them with a program, one with its configuration file and one with the report. [*Programming in Ernest*](language.md), the guide, teaches the language; this document says why it is as it is.

Ernest is a small functional language for concurrent programs, on the Erlang runtime. A process receives messages of one type, which the compiler checks every send against, and a process started on another node brings its code along: nothing is installed there first. `ern` is its one command, which builds, runs and tests a program and opens its shell.

What Ernest adds is where the parts meet:

- **The mailbox in the function's type.** Every process receives messages of one type, which a function that receives names in its own type and a process's address carries. So the compiler checks every message sent against the mailbox it will reach and every receive against the mailbox it reads, and a program can never send a server a message of a type the server does not take. A function that receives runs only in a process of its mailbox's type.
- **Code known by its hash.** A function or a type is known by a hash of its definition, not by the name of the module it stands in. So a module reloaded is a new version beside its earlier ones, a running process moves to the new version of its function when a message tells it to, and a process started on another node brings its code along: any node can run anything, a computation that names no node goes to the less busy of two peers drawn at random, which spreads a burst among three peers or more, and no program is deployed first.
- **A distribution built for a WAN.** A node lists its peers in a file, each by name, public key and address, accepts a connection only from a key it lists, and opens one TLS connection to a peer when it first needs it. There is no cluster to join and no shared secret: a laptop and a server, or two data centers, are two nodes with one file each naming the other.
- **Abstract types and requirements.** A type declared abstract keeps its constructor to its own module, so the representation can change and no caller knows. A generic function names the operations it needs of its type, and the compiler supplies that type's own at each call. Nothing is declared an instance of anything: a type's members are declared in its own module, a requirement is written and never inferred, and the members are a closed set no program adds to, which is what sets a requirement apart from a class.
- **A deadlock is found.** A program in which every process waits for a message none can send ends with a fault and a trace, where the host would wait forever. The runtime owns every source of a message, a typed mailbox, a process it spawned, a timer or a socket, which it counts, but for a delivery foreign code arranges for after its call has returned, so it can decide that nothing can deliver, under `ern run` and `ern test`; a node, which its peers can reach, detects none, and nor does the shell while it holds the terminal. Finding one costs a running program almost nothing.
- **Little else.** Functions and processes are the whole language, with one way to do each thing. A report of three files defines all of it. Five principles decide what goes in, and the first is that nothing surprises a reader who knows the rest.

Its parts come from elsewhere: Erlang's processes, the types of ML, which Gleam made ordinary on that runtime, and Unison's small core and its code known by the hash of its definition.

Ernest is for programs written in it from the start. An Ernest program is not an OTP application, and its own code is Ernest: what ships with Erlang/OTP, and any library of the host's, a package from hex among them, is reached through declarations that give it Ernest types, which a program may write for itself. What an OTP programmer finds in place of each part, the supervisor, the release and `sys` among them, is the guide's §10 and [the questions](faq.md).

## The claims, in code

### The mailbox in the function's type

A counter is a process that holds a number. Its mailbox type, `CounterMsg`, is in the type of `count`, so a `send` of anything else to its address is refused before the program runs, `the argument does not fit send: expected CounterMsg, found String`. `counter` is the program's counter, bound at the top of the module and started under `restarting`, so any module sends to it by name, and a fault in `count` starts it again with the address kept:

```ernest
export type CounterMsg = Inc(Int) | Get(Reply(Int))

export let counter : Address(CounterMsg) =
    spawn(restarting(RestartLimit(restarts = 3, within = 5000), fn() = count(0)))

export fn main() : Unit = {
    send(counter, Inc(5));
    send(counter, Inc(3));
    match Address.call(counter, Get, 1000) {
        Some(total) -> Io.println("count is " <> Int.toString(total))
      | None -> Io.println("counter did not answer")
    }
}

fn count(total : Int) : Unit receiving CounterMsg =
    receive {
        Inc(amount) ->
            count(total + amount)
      | Get(reply) -> {
            answer(reply, total);
            count(total)
        }
    }
```

```console
$ ern run counter.erc
count is 8
```

`main` receives nothing, so its type names no mailbox. The counter is spawned on this node as the program starts, before `main` runs, the top-level bindings of the standard library and of every module the program uses evaluated in dependency order (report §8.5). `Address.call` gives `Get` a `Reply(Int)` of its own, which the counter answers with `answer`, and waits for the answer at most 1000 milliseconds: `None` is an answer that did not come.

A fault, a division by zero or a `fault` call, ends the process, and nothing catches it. Whoever monitors the process hears of its end as a `Down` with the reason, wrapped as a message of their own type. A process started under `restarting` runs its function again from its start after a fault, its mailbox emptied and its address kept, so the name `counter` stays good and a request that waited in the mailbox is lost; the guide's §6.5 shows a restart.

A function that receives runs only in a process of its mailbox's type. `spawn` takes the address's type from the function, `spawn(fn() = count(0))` being an `Address(CounterMsg)` and nothing else; no channel is made inside the process and handed out, and no process reads another's mailbox, since `receive` reads the mailbox of the process it runs in, the one the function's type names. Called in a process whose mailbox takes another type, here `main`'s, `count` is refused, though no address is in sight:

```ernest-rejected
type CounterMsg = Inc(Int)

type OtherMsg = Ticked

export fn main() : Unit receiving OtherMsg =
    count(0)

fn count(total : Int) : Unit receiving CounterMsg =
    receive {
        Inc(amount) -> count(total + amount)
    }
```

```console
$ ern build other.ern
other.ern:6:5: count needs mailbox CounterMsg, and the mailbox here is OtherMsg
4 |
5 | export fn main() : Unit receiving OtherMsg =
  |                                   -------- main is declared `receiving OtherMsg` here
6 |     count(0)
  |     ^^^^^^^^
```

The host's own code, Erlang's libraries and whatever else runs on the runtime, is *foreign code* to a program, reached through a `foreign fn` that declares the Ernest type of a host function (the guide's §8.3):

```ernest-fragment
foreign fn systemTime() : Int =
    "erlang:system_time/0"
```

Where foreign code meets the program the type is checked, not trusted. The runtime checks each answer against the declared type as it arrives, so `: String` in its place would fault the caller at the first call, `the return of foreign function erlang:system_time/0 does not match String`. It checks the same way a reply foreign code gives, a message foreign code sends to an address exposed to it, and each argument foreign code calls an Ernest function with; what does not match is a fault at the crossing, naming the function and the type (report §8.4).

So a mailbox type holds for messages the host sends to an address the program gave it, and a wrong value from a library is a fault at the crossing with a trace, not a crash later in code that trusted it. A foreign function that delivers into its caller's own mailbox is trusted to deliver its declared type, and nothing checks it (the guide's §8.3). The standard library is the runtime's own and pays no check; a check walks the value it checks, and costs with its size.

### Code known by its hash

The hash is never written in a program. It is what tells two versions of a definition apart, and what a peer asks for. The counter replaces its own code while it runs. A message of its type carries the new loop, and the process switches to it with a tail call, keeping its address and its state; the old loop keeps running wherever a process still runs it. `countTwice`, a loop of the same type that the guide's §4.6 writes, is sent as a value:

```ernest-fragment
type CounterMsg =
    Inc(Int)
  | Get(Reply(Int))
  | Upgrade(next : (Int) -> Unit receiving CounterMsg)

fn count(total : Int) : Unit receiving CounterMsg =
    receive {
        Inc(amount) ->
            count(total + amount)
      | Get(reply) -> {
            answer(reply, total);
            count(total)
        }
      | Upgrade(next = next) ->
            next(total)
    }

send(counter, Upgrade(next = countTwice))
```

`next` is of the counter's own type, `receiving CounterMsg`, so the type says that the loop a message may install reads this mailbox and no other, and such a message changes the loop and not the messages. A process keeps its mailbox type for life, so a change of the messages is a new process, started beside the old or in its place; a new message type is a new version of the module, which the shell shows.

The first claim's counter runs under `restarting`, and a restart runs the function the process was started with, so a counter moved to `countTwice` runs `count` again after its next fault; how a service under `restarting` takes new code is the deployment guide's §5.3.

In the shell the versions are visible. `:reload` compiles again every module edited since it was loaded; a module so compiled is a new version beside the old, and a binding made under the old keeps it. Nothing is purged: every version a node has loaded stays for the node's life, so a node reloaded without end grows with its versions, and the deployment guide's §4.2 says when a node is restarted.

Here the counter is the module `Counter`, and `CounterMsg` gained a `Reset` between the two spawns. Both processes run. A message of the new type to the old process is refused by the compiler, with the reason. `Counter.Inc(1)` is refused the same way, every constructor being the new type's: new code reaches a process of the old version through a binding made before the reload alone.

```
$ ern shell
> :load Counter
Counter, compiled from counter.ern
> let old = spawn(fn() = Counter.count(0))
old : Address(Counter.CounterMsg)
> :reload
Counter, compiled again
Counter.CounterMsg changed: the binding old is of its previous version, Counter$1.CounterMsg
> let new = spawn(fn() = Counter.count(0))
new : Address(Counter.CounterMsg)
> send(old, Counter.Reset)
input 5:1:11: the argument does not fit send: expected Counter$1.CounterMsg, found Counter.CounterMsg
1 | send(old, Counter.Reset)
  | ---- send : (Address(a), a) -> Unit
  |           ^^^^^^^^^^^^^
  | = help: Counter$1.CounterMsg is of a previous version of Counter, which a reload replaced
```

A version's name, `Counter$1`, is printed and cannot be written, so what a later input will need of the old version is bound before the reload: `let oldGet = Counter.Get` beside `old` lets `Address.call(old, oldGet, 1000)` ask the old counter after it.

The first claim's counter, whose messages carry no function and so may cross to another node, runs on a peer that holds none of its code: a spawned function crosses as code, by its hash, where a function in a message would have to cross as a value, which none does (the guide's §8.4). A spawn names its function by hash, and a peer that lacks it is sent the definition with every definition it references, before the process starts. `foo` is a bare node, started from a configuration directory and no program. It holds the same `ern` on the same OTP, the standard library and the host's modules the program's foreign declarations name, and of the program nothing, and runs whichever version the spawn names:

```ernest-fragment
match Peer.spawn("foo", fn() = count(0), 5000) {
    Right(counter) -> send(counter, Inc(5))
  | Left(error) -> Io.println("no foo: " <> Io.show(error))
}
```

`Peer.spawn` waits at most 5000 milliseconds for the peer, and answers `Left` with the reason where it cannot reach it. The tour's chapter 2 runs this spawn, on a bare node started for it, and shows what each terminal printed.

A computation need not name a node at all. `Peer.compute(f, ms)` runs `f` on the less busy of two peers drawn at random from those the node knows, carrying its code there as the spawn does, and answers the value within `ms` milliseconds, or `Left` with the reason. The draw spreads work among three peers or more with no central choice; with two peers it takes both each time, so a burst within one telling goes to the one less busy at it. A fault in `f` is the caller's, with `f`'s cause, and the line the caller's node writes of it names the peer `f` ran on, `, on the peer foo`:

```ernest-fragment
match Peer.compute(fn() = render(scene, row), 5000) {
    Right(pixels) -> putRow(row, pixels)
  | Left(error) -> Io.println("no peer: " <> Io.show(error))
}
```

Nothing of the program was installed on the peer, and nothing names it: the node that ran `render` was the less busy of two peers drawn at random when the row was asked for, and `scene` and `row`, which the function captured, crossed with each call. The tour's chapter 7 runs such a compute three times between two bare nodes.

### A distribution built for a WAN

A node is Ernest started from a configuration directory, with a program or with none. Its `ernest.conf` lists the peers it knows, each by a name, a public key and an address. A connection is accepted from a listed key alone, under the name listed beside that key, and is opened over TLS when an operation first needs it:

```json
{
  "listen": "0.0.0.0:8654",
  "public-key": "-----BEGIN PUBLIC KEY-----\nMCowBQYDK2VwAyEAxPrYwmRdoys5yu9UJVah/ssQO8AeM8Sz8XSW+1BQOVg=\n-----END PUBLIC KEY-----\n",
  "peers": [
    {
      "name": "foo",
      "public-key": "-----BEGIN PUBLIC KEY-----\nMCowBQYDK2VwAyEAbcsDUdMBCWTaHU5iYs2EHT4fDQzaUBer/dL+n5DPJrk=\n-----END PUBLIC KEY-----\n",
      "network-address": "foo.example.net:8654"
    }
  ],
  "services": {}
}
```

`ern config` makes the directory, the node's private key and its certificate, and prints the public key, which is what another node lists. A service is a process a node offers its peers under a name, whose address they find by that name. `services`, empty here, names for each service a program looks up the peers that may offer it. A service a node offers under a name is found from a peer by that name and the hash of its message type, so two programs built apart agree on what passes between them, or the find answers `OtherType`.

A listed peer is trusted whole. One that may spawn on a node may run anything on it, so the list of peers is the whole of the trust.

The connection is one, opened at the first operation towards the peer and kept. A peer that closes is found lost at once, and one that falls silent after 45 to 75 seconds, as the host's distribution finds a silence; the next operation towards it dials again. A node that only dials, a laptop behind a router, lists no `listen` (report §8.7, Appendix C).

A peer that goes out of reach is the monitor's `Down` with the reason `Unreachable` to whoever monitors a process on it, which says nothing of whether the process lives. A program is written for that case as for any other end.

### Abstract types and requirements

Three forms carry what a type does and how code is written over several types: an abstract type, a requirement and an operations record, each shown here. None of them is a type class, an interface or a trait.

An *abstract type* keeps its constructor to its module. Every function of `stack.ern` takes a `Stack` apart, and no other module can:

```ernest
// stack.ern  (namespace Stack)
export abstract type Stack(a) = Stack(List(a))

export let empty = Stack([])

export fn push(Stack(items), item) =
    Stack(item :: items)

export fn size(Stack(items)) =
    List.size(items)
```

`main.ern` uses it. `ern build` compiles the two to `main.erc`, which `ern run` runs:

```ernest
// main.ern  (namespace Main)
export fn main() : Unit = {
    let stack = Stack.push(Stack.push(Stack.empty, 1), 2);
    Io.println(Int.toString(Stack.size(stack)))
}
```

```console
$ ern run main.erc
2
```

`Stack.Stack([])` in `main.ern` is refused, so a caller holds a stack through `empty`, `push` and `size` alone. The list inside can become anything, and no caller knows.

A *requirement* names the operations a generic function needs of its type, several with commas: a type's `compare`, `negate`, one of the six operators `+`, `-`, `*`, `/`, `%` and `<>`, or `show`, and nothing else. `sorted` needs a `compare` of `a`, the type of the list's elements, since `List.sort` needs one. Written over `List(Int)` it would sort integers alone. Written with `needs`, a call supplies nothing, and the compiler finds the `compare` declared under the element type's name, in that type's own module.

```ernest
fn sorted(list : List(a)) : List(a) needs a.compare =
    List.sort(list)

export fn main() : Unit = {
    Io.println(Io.show(sorted([3, 1, 2])));
    Io.println(Io.show(sorted(["b", "a"])))
}
```

```console
$ ern run sorted.erc
[1, 2, 3]
["a", "b"]
```

One `sorted` sorts integers and strings. Nothing declared `Int` or `String` sortable: each has its own `compare`, and the compiler supplies it. A type of the program's own gets one by `derives compare`, or by declaring the function under its name in its own module, and another order is a key, `List.sortBy(list, String.size)`. A type that has none is refused at the call:

```ernest-rejected
type Color = Red | Green

fn sorted(list : List(a)) : List(a) needs a.compare =
    List.sort(list)

export fn main() : Unit =
    Io.println(Io.show(sorted([Green, Red])))
```

```console
$ ern build color.ern
color.ern:7:24: sorted needs Color.compare, and Color has no compare
6 | export fn main() : Unit =
7 |     Io.println(Io.show(sorted([Green, Red])))
  |                        ^^^^^^
  | = help: give Color a compare, `derives compare` on its declaration or `fn Color.compare`
```

An *operations record* is a record of functions, filled from a module by naming it. `Operations(..Set)` takes `fromList` and `toList` from the module `Set`, and `Operations(..OrderedSet)` the same two from `OrderedSet`. `Set` is the prelude's type, what every module sees without naming a module, and has no order of its own; `OrderedSet` is a module of the standard library, so its type is written whole, `OrderedSet.Set`:

```ernest
type Operations(s, a) = Operations(fromList : (List(a)) -> s, toList : (s) -> List(a))

let unordered : Operations(Set(Int), Int) = Operations(..Set)

let ordered : Operations(OrderedSet.Set(Int), Int) = Operations(..OrderedSet)

fn unique(list : List(a), operations : Operations(s, a)) : List(a) =
    operations.toList(operations.fromList(list))

export fn main() : Unit = {
    Io.println(Io.show(unique([3, 1, 3], ordered)));
    Io.println(Int.toString(List.size(unique([3, 1, 3], unordered))))
}
```

```console
$ ern run unique.erc
[1, 3]
2
```

`unique` is one function over two representations, and the caller chooses at each call. The unordered set's list comes in no order a program may rely on, so its size is printed. `Operations` is the program's own record of the two functions it uses; the standard library declares no such record.

`sorted` and `unique` are not two ways to one thing. A requirement asks for what every element type has of its own, and a record carries what the caller chooses. What sets a requirement apart from a class, an interface or a trait is that its members are a closed set, `compare`, `negate`, the six operators and `show`, which no program adds to: a type's are declared in its own module, and no type is declared an instance of anything. The guide's §7 teaches them.

### A deadlock is found

A program in which every process waits for a message none can send ends with `Fault("deadlock")` and a trace, under `ern run`, and under `ern test`, where it is the test's fault and the run goes on (report §8.6, §11.2). `main` waits for `Done` from the worker, and the worker waits for `Go` from `main`:

```ernest
type MainMsg = Done

type WorkerMsg = Go

export fn main() : Unit receiving MainMsg = {
    let me = self();
    let worker = spawn(fn() = work(me));
    receive {
        Done -> Io.println("done")
    }
}

fn work(main : Address(MainMsg)) : Unit receiving WorkerMsg =
    receive {
        Go -> send(main, Done)
    }
```

```console
$ ern run dead.erc
Dead.main faulted: deadlock
    Dead.main:7
    1 process of Dead.main:7 waits in Dead.work:13
```

The trace names line 7, the `spawn`, and not the `receive` below it: a wait leaves no frame of its own, so a waiting process's frame names the last call before the wait (report Appendix E.21).

Beneath the trace the fault lists the processes left waiting, a line for each spawn site and the frame its processes wait in: here the worker, spawned on line 7, waiting in `work` (report §8.6).

On Erlang a bare `receive` waits forever, and a `gen_server:call` gives up after five seconds with an exit that names the timeout and not the cause; a programmer learns of the deadlock from that, a dashboard or a user.

Ernest can decide it because the runtime owns every source of a message but one, which the next paragraph names. A mailbox is typed and reached through an address the program holds; a process is spawned by the runtime, which monitors it; the clock, the file system and TCP are system processes, and a socket and a running program are processes of the runtime, each counting what it holds; foreign code is entered through a declaration, and a process inside it is read as able to be delivered to. So "nothing can deliver and everyone waits" is a question with an answer, and the runtime asks it when a program has been quiet for a while, never on a node, which a peer can always reach.

A deadlock is quiescence, not a cycle, and the runtime's look for one may be late, and is wrong in one case alone. A process it cannot see into, in foreign code or on a socket, is read as able to deliver, so it reports no deadlock that is not one. The case is a delivery that foreign code arranges for after its call has returned, a host timer's or that of a host process nothing monitors, which the runtime cannot see coming: `ern run` and `ern test` fault a program that waits for it alone with `deadlock` (report §8.6).

Finding one costs a program at work almost nothing, since the runtime asks only once the program has been quiet.

### Little else

No program shows this claim. Its evidence is the report under `report/`: the language, the toolchain and the library, a file each, which state everything the programs above rely on.

## Reading on

The guide's §0 shows what the compiler refuses and how it says so, and its §1 runs the first program. The questions a reader brings, the likeness to Gleam among them, are answered in [the questions](faq.md). The reasons behind each rule, dated, are the log's, [`docs/log.md`](../docs/log.md).
