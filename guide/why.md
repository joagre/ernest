# Why Ernest

The argument for the design, in six claims, four of them with a program, one with its configuration file and one with the report. [*Programming in Ernest*](language.md), the guide, teaches the language; this document says why it is as it is.

What Ernest adds is where the parts meet:

- **Code travels.** A process started on another node brings its code along, and a module keeps every version it has had: each function is known by a hash of its definition, not by the module it stands in.
- **The mailbox in the function's type.** Every process receives messages of one type, which a function that receives names in its own type and a process's address carries.
- **A distribution built for a WAN.** A node lists its peers in a file, each by name, public key and address, accepts a connection only from a key it lists, and opens one TLS connection to a peer when it first needs it.
- **A deadlock is found.** A program in which every process waits for a message none can send ends with a fault and a trace under `ern run` and `ern test`, where the host would wait forever.
- **Abstract types and requirements.** A type declared abstract keeps its constructor to its own module, so the representation can change and no caller knows.
- **Little else.** Functions and processes are the whole language, with one way to do each thing.

Its parts come from elsewhere: Unison's small core and its code known by the hash of its definition, the types of ML, which Gleam made ordinary on that runtime, and Erlang's processes.

Ernest is for programs written in it from the start. An Ernest program is not an OTP application, and its own code is Ernest: what ships with Erlang/OTP, and any library of the host's, a package from hex among them, is reached through declarations that give it Ernest types, which a program may write for itself. What an OTP programmer finds in place of each part, the supervisor, the release and `sys` among them, is the guide's §10 and [the questions](faq.md).

## The claims, in code

### Code travels

The hash is never written in a program. It is what a peer asks for, and what tells two versions of a definition apart.

A spawn names its function by hash, and a peer that lacks it is sent the definition with every definition it references, before the process starts. `foo` is a bare node, started from a configuration directory and no program. It stands on the same floor, one minor release of `ern` on one major release of OTP, and holds the standard library and the host's modules the program's foreign declarations name, and of the program nothing, and runs whichever version the spawn names:

```ernest-fragment
match Peer.spawn("foo", fn() = count(0), 5000) {
    Right(counter) -> send(counter, Inc(5))
  | Left(error) -> Io.println("no foo: " <> Io.show(error))
}
```

`Peer.spawn` waits at most 5000 milliseconds for the peer, and answers `Left` with the reason where it cannot reach it. The tour's chapter 2 runs this spawn, on a bare node started for it, and shows what each terminal printed. What crosses is code and what the function captured, never a node's values: a top-level binding whose initializer is no constant has its value on the node that evaluated it alone (the guide's §8.1).

So a counter whose messages carry no function may run on a peer that holds none of its code: a spawned function crosses as code, by its hash, where a function in a message would have to cross as a value, which none does (the guide's §8.4). A type that holds a function, a foreign type or a resource such as a socket is *bound to its node*, and `Peer.spawn` refuses before the run a function whose mailbox type is bound (report §3.11).

A computation need not name a node at all. `Peer.compute(f, ms)` runs `f` on the less busy of two peers drawn at random from those that have told the node how busy they are, carrying its code there as the spawn does, and answers the value within `ms` milliseconds, or `Left` with the reason (the guide's §8.1, report Appendix E.27):

```ernest-fragment
match Peer.compute(fn() = render(scene, row), 5000) {
    Right(pixels) -> putRow(row, pixels)
  | Left(error) -> Io.println("no peer: " <> Io.show(error))
}
```

Nothing of the program was installed on the peer, and nothing names it: the node that ran `render` was the less busy of two peers drawn at random when the row was asked for, and `scene` and `row`, which the function captured, crossed with each call. The tour's chapter 7 runs such a compute three times between two bare nodes.

On one node the message type's hash finds the processes a new version is for. The door by which a counter replaces its own code is ordinary: a message of its type carries the new loop, and the process switches to it with a tail call, keeping its address and its state, as any language with closures in messages writes it; the old loop keeps running wherever a process still runs it. The hash is what finds the processes such a message is for: `Code.running(f)` lists, typed, the processes of the node that run `f`, or another version of it with the same message type, by `f`'s name and the hash of its message type, which a fix leaves as it is (the tour's chapter 8). `countTwice`, a loop of the same type that the guide's §4.6 writes, is sent as a value:

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
      | Upgrade(=next) ->
            next(total)
    }

send(counter, Upgrade(next = countTwice))
```

`=next` is `next = next`, the field bound to a variable of its own name (the guide's §2.6). `next` is of the counter's own type, `receiving CounterMsg`, so the type says that the loop a message may install reads this mailbox and no other, and such a message changes the loop and not the messages. A process keeps its mailbox type for life, so a change of the messages is a new process, started beside the old or in its place. A module compiled again with a changed message type is a new version of it, beside the old, as the shell session below shows.

In the shell the versions are visible. `:reload` compiles again every module edited since it was loaded; a module so compiled is a new version beside the old, and a binding made under the old keeps it.

Here the counter is the module `Counter`, and `CounterMsg` gained a `Reset` between the two spawns. Both processes run. A message of the new type to the old process is refused by the compiler, with the reason. `Counter.Inc(1)` is refused the same way, every constructor being the new type's.

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

A version's name, `Counter$1`, is printed and cannot be written: the old version's types are gone from the session, so its process is reached only through a value bound while they were there, `old` here (the guide's §9.3).

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

`main` receives nothing, so its type names no mailbox. The counter is spawned on this node as the program starts, before `main` runs: the top-level bindings of the standard library and of every module the program uses are evaluated first, each after those it depends on (report §8.5). `Address.call` gives `Get` a `Reply(Int)` of its own, which the counter answers with `answer`, and waits for the answer at most 1000 milliseconds: `None` is an answer that did not come.

A fault, a division by zero or a `fault` call, ends the process, and nothing catches it. Whoever monitors the process hears of its end as a `Down` with the reason, wrapped as a message of their own type. A process started under `restarting` runs its function again from its start after a fault, its mailbox emptied and its address kept, so the name `counter` stays good and a request that waited in the mailbox is lost; the guide's §6.5 shows a restart.

A function that receives runs only in a process of its mailbox's type. `spawn` takes the address's type from the function, `spawn(fn() = count(0))` being an `Address(CounterMsg)` and nothing else, and the one channel a program makes is a `Reply`, which a caller makes and hands over in its request (report §6.6). A Gleam `process.spawn` answers a `Pid`, which takes no message: the child makes a `Subject` with `process.new_subject()` and sends it back to its parent before the parent can send to it.

No process reads another's mailbox, since `receive` reads the mailbox of the process it runs in, the one the function's type names. Called in a process whose mailbox takes another type, here `main`'s, `count` is refused, though no address is in sight. This is the mistake a Gleam `Subject` lets through: `process.receive(subject, 1000)` compiles wherever a subject is in hand, and panics at run time in a process given a subject it did not make:

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

A delivery that foreign code arranges after its call has returned, by a host timer or by a host process nothing monitors, is one the runtime cannot see, so `ern run` and `ern test` fault a program that waits for it alone with `deadlock` (report §8.6).

### A distribution built for a WAN

A node is Ernest started from a configuration directory, with a program or with none. Nodes talk over Erlang's own distribution, set up one way and not through its options ([the questions](faq.md#what-does-built-for-a-wan-mean)). Its `ernest.conf` lists the peers it knows, each by a name, a public key and an address. A connection is accepted from a listed key alone, under the name listed beside that key, and is opened over TLS when an operation first needs it:

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

`ern config` makes the directory, the node's private key and its certificate, and prints the public key, which is what another node lists. A service is a process a node offers its peers under a name; a peer finds its address by that name and the hash of its message type, so two programs built apart agree on what passes between them, or the find answers `Io.OtherType`. `services`, empty here, names for each service a program looks up the peers that may offer it.

A listed peer is trusted whole. One that may spawn on a node may run anything on it, so the list of peers is the whole of the trust.

The same trust is the operator's window. `ern shell --config-dir ops --attach foo` runs a shell whose every input runs on `foo`: its processes are listed, their faults said at the prompt, its modules loaded and reloaded from there, and a binding made at the prompt lives on the node while its name is in scope, the operator's machine keeping the terminal and the files alone. The shell is a node of its own, listed by `foo` under its key, so attaching is a connection like any other and nothing is installed on `foo` first; `:quit` leaves the node running. The deployment guide's §6 looks into a node this way, and the tour's chapter 8 moves a fix from a prompt on a node started with none of the program's code.

The connection is one, opened at the first operation towards the peer and kept. A peer that closes is found lost at once, and one that falls silent after 45 to 75 seconds, as the host's distribution finds a silence; the next operation towards it dials again. A restart here of a process that one of the silent peer's processes monitors or calls waits as long, and no setting shortens the window (the deployment guide's §2.3). A node that only dials, a laptop behind a router, lists no `listen` (report §8.7, §12.5, Appendix C).

A peer that goes out of reach is the monitor's `Down` with the reason `Unreachable` to whoever monitors a process on it, which says nothing of whether the process lives. A program is written for that case as for any other end.

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

Beneath the trace the fault lists the processes left waiting, a line for each spawn site and the frame its processes wait in: here the worker, spawned on line 7, waiting in `work` (report §12.4).

Two servers that call each other wait the same way. The first answers `AskFirst` by calling the second, the second answers `AskSecond` by calling the first, and `main` calls the first, each call with `Address.callForever`, which waits as long as its callee lives:

```ernest
type FirstMsg = Meet(Address(SecondMsg)) | AskFirst(Reply(Int))

type SecondMsg = AskSecond(Reply(Int))

export fn main() : Unit = {
    let first = spawn(fn() = meet());
    let second = spawn(fn() = secondLoop(first));
    send(first, Meet(second));
    Io.println(Int.toString(Address.callForever(first, AskFirst)))
}

fn meet() : Unit receiving FirstMsg =
    receive {
        Meet(second) -> firstLoop(second)
    }

fn firstLoop(second : Address(SecondMsg)) : Unit receiving FirstMsg =
    receive {
        AskFirst(reply) -> {
            answer(reply, Address.callForever(second, AskSecond));
            firstLoop(second)
        }
    }

fn secondLoop(first : Address(FirstMsg)) : Unit receiving SecondMsg =
    receive {
        AskSecond(reply) -> {
            answer(reply, Address.callForever(first, AskFirst) + 1);
            secondLoop(first)
        }
    }
```

The fault comes once the program is quiet, and its lines name both servers, each by its spawn site and the call it waits in:

```console
$ ern run mutual.erc
Mutual.main faulted: deadlock
    Mutual.main:9
    1 process of Mutual.main:6 waits in Mutual.firstLoop:20
    1 process of Mutual.main:7 waits in Mutual.secondLoop:28
```

The fault names the deadlock and the processes it left waiting. On Erlang a bare `receive` waits forever, and a `gen_server:call` gives up after five seconds with an exit that names the timeout and not the cause; a programmer learns of the deadlock from that, a dashboard or a user.

Ernest can decide it because the runtime owns every source of a message but one, which the next paragraph names. A mailbox is typed and reached through an address the program holds. A process is spawned by the runtime, which monitors it. The clock, the file system and TCP are system processes, and a socket and a running program are processes of the runtime, each counting what it holds. Foreign code is entered through a declaration, and a process inside it is read as able to be delivered to.

So "nothing can deliver and everyone waits" is a question with an answer, and the runtime answers it by report §8.6's rule: no forward progress is possible when every process waits, no message is in flight, and nothing the runtime counts holds a timer, a pending I/O or a computation that would deliver one.

A deadlock is quiescence, not a cycle, and the runtime's look for one may be late, and is wrong in one case alone. A process it cannot see into, in foreign code or on a socket, is read as able to deliver, so such a process makes no false deadlock. The one false deadlock is a delivery that foreign code arranges for after its call has returned, a host timer's or that of a host process nothing monitors, which the runtime cannot see coming: `ern run` and `ern test` fault a program that waits for it alone with `deadlock` (report §8.6).

Finding one costs a program at work the count behind it, a message at each spawn and each monitor, and the check itself runs only once the program has been quiet. `make bench`, in a checkout of the repository, measures a spawn and a monitor so counted against the host's own; the prose here carries no number, since the bench owns it. A program run as a node, `ern run` or `ern test` with `--config-dir`, looks for no deadlock, since a peer can always deliver to it (report §8.6).

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

`main.ern` uses it. `ern build .` compiles the two to `stack.erc` and `main.erc`, and `ern run` runs `main.erc`:

```ernest
// main.ern  (namespace Main)
export fn main() : Unit = {
    let stack = Stack.push(Stack.push(Stack.empty, 1), 2);
    Io.println(Int.toString(Stack.size(stack)))
}
```

```console
$ ern build .
$ ern run main.erc
2
```

`Stack.Stack([])` in `main.ern` is refused, so a caller holds a stack through `empty`, `push` and `size` alone. The list inside can become anything, and no caller knows.

A *requirement* names the operations a generic function needs of its type, several with commas: a type's `compare`, `negate`, one of the six operators `+`, `-`, `*`, `/`, `%` and `<>`, or `show`, and nothing else. `sorted` needs a `compare` of `a`, the type of the list's elements, since `List.sort` needs one. Written over `List(Int)` it would sort integers alone. Written with `needs`, the caller writes nothing more, and the compiler finds the `compare` declared under the element type's name, in that type's own module.

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

A requirement names nothing outside that set, and a member is declared in its type's own module alone. At the prompt a requirement of a `hash` is refused, and so is a `negate` for `String`, a type the prompt does not declare:

```console
$ ern shell
Ernest 0.11.0, session 1. :help for help.
> fn hashed(x : a) : Int needs a.hash = 0
input 1:1:30: `hash` is not what a requirement names: `+`, `-`, `*`, `/`, `%`, `<>`, `compare`, `negate` or `show`
1 | fn hashed(x : a) : Int needs a.hash = 0
  |                              ^^^^^^
> fn String.negate(s : String) : String = s
input 2:1:4: String is not a type declared in this module
1 | fn String.negate(s : String) : String = s
  |    ^^^^^^^^^^^^^
```

A member is also no value: `Int.compare` in an expression is refused, and `compare` reaches it (report §4.5).

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

`sorted` and `unique` are not two ways to one thing. A requirement asks for what every element type has of its own, and a record carries what the caller chooses.

A requirement is a type class's constraint, declared again by each generic caller and supplied by the compiler at each call by the type, but for two things: the set it names is closed, `compare`, `negate`, the six operators and `show`, which no program adds to, and a type's member is declared in its type's own module alone (report §4.9). No program declares a class, so no abstraction stands on one, no functor, no monad, no tower of them, and that closed set is the whole of what a type can promise.

`show` is no member a type declares, and every value has it through `Io.show` (report §4.9). A function generic in `a` that shows a value writes `needs a.show` all the same, since `Io.show` writes a value by its type, which the function does not know and each call supplies (the guide's §7.3). The type tells what the value does not carry: which of `String` and `Bytes`, or of `Char` and `Int`, a host value is, since each pair is one host value, `"hi"` and `<<104, 105>>` as `'a'` and `97` (report §12.3). The guide's §7 teaches requirements.

### Little else

No program shows this claim. Its evidence is the report under [`report/`](../report/): the language, the toolchain and the library, a file each, which state everything the programs above rely on.

## Reading on

The guide's §0 shows what the compiler refuses and how it says so, and its §1 runs the first program. The questions a reader brings, the likeness to Gleam among them, are answered in [the questions](faq.md). The reasons behind each rule, dated, are the log's, [`docs/log/`](../docs/log/README.md). The [projects](../site/projects.md), libraries and programs in repositories of their own, are built against Ernest's release alone, as a stranger builds with it, and never against its source.
