# Why Ernest

The argument for the design, in six claims, the first four with a program. [*Programming in Ernest*](language.md), the guide, teaches the language; this document says why it is as it is.

Ernest is a small functional language for concurrent programs, on the Erlang runtime. A program is functions, whose types the compiler infers, and processes that talk through typed mailboxes.

Its parts come from elsewhere: Erlang's processes, the types of ML, which Gleam made ordinary on that runtime, and Unison's small core and its code known by the hash of its definition.

What Ernest adds is where the parts meet:

- **The mailbox in the function's type.** Every process receives messages of one type, which a function that receives names in its own type and a process's address carries. So the compiler checks every message sent against the mailbox it will reach and every receive against the mailbox it reads, and a program can never send a server a message it does not take.
- **Code known by its hash.** A function or a type is known by a hash of its definition, not by the name of the module it stands in. So a module reloaded is a new version beside its earlier ones, a running process moves to the new version of its function when a message tells it to, and a process started on another node brings its code along: any node can run anything, a computation that names no node goes to one with room, and no program is deployed first.
- **A distribution built for a WAN.** A node lists its peers in a file, each by name, public key and address, accepts a connection only from a key it lists, and opens one TLS connection to a peer when it first needs it. There is no cluster to join and no shared secret: a laptop and a server, or two data centers, are two nodes with one file each naming the other.
- **Abstract types and requirements.** A type declared abstract keeps its constructor to its own module, so the representation can change and no caller knows. A generic function names the one operation it needs of its type, and the compiler supplies that type's own at each call. Nothing is declared an instance of anything, and there is no type class, interface or trait.
- **A deadlock is found.** A program in which every process waits for a message none can send ends with a fault and a trace, where the host would wait forever. The runtime owns every source of a message, a typed mailbox, a process it spawned, a system process that counts what it holds, so it can decide that nothing can deliver, and a program at work pays nothing for the question.
- **Little else.** Functions and processes are the whole language, with one way to do each thing. A report of three files defines all of it. Five principles decide what goes in, and the first is that nothing surprises a reader who knows the rest.

Ernest is for programs written in it from the start. An Ernest program is not an OTP application and is not mixed with Elixir or Gleam code; What ships with Erlang/OTP is reached through declarations that give it Ernest types, which a program may write for itself, and anything else is written in Ernest.

## The claims, in code

### The mailbox in the function's type

A counter is a process that holds a number. Its mailbox type, `CounterMsg`, is in the type of `count`, so a `send` of anything else to its address is refused before the program runs, `the argument does not fit send: expected CounterMsg, found String`. `counter` is the program's counter, bound at the top of the module and started under `restarting`, so any module sends to it by name, and a fault in `count` starts it again with the address kept:

```ernest
export type CounterMsg = Inc(Int) | Get(Reply(Int))

export let counter : Address(CounterMsg) = spawn(restarting(Unlimited, fn() = count(0)))

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

`main` receives nothing, so its type names no mailbox. The counter is spawned on this node as the program starts, before `main` runs. `Address.call` gives `Get` a `Reply(Int)` of its own, which the counter answers with `answer`, and waits for the answer at most 1000 milliseconds: `None` is an answer that did not come.

A fault, a division by zero or a `fault` call, ends the process, and nothing catches it. Whoever monitors the process hears of its end as a message of their own type. A process started under `restarting` runs its function again in place after a fault, keeping its address, so the name `counter` stays good; the guide's §6.5 shows a restart.

### Code known by its hash

The hash is never written in a program. It is what tells two versions of a definition apart, and what a peer asks for. The counter replaces its own code while it runs. A message of its type carries the new loop, and the process switches to it with a tail call, keeping its address and its state; the old loop keeps running wherever a process still runs it. `countTwice` is a loop of the same type, sent as a value:

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

`next` is of the counter's own type, so such a message changes the loop and not the messages. A new message type is a new version of the module, which the shell shows.

In the shell the versions are visible. A module compiled again after an edit is a new version beside the old, and a binding made under the old keeps it. Nothing is purged: every version a node has loaded stays for the node's life, so a node reloaded without end grows with its versions. Here the counter is a module `Counter` whose message type is `Msg`; `Msg` gained a `Reset` between the two spawns, both processes run, and a message of the new type to the old process is refused by the compiler, with the reason.

```
> let old = spawn(fn() = Counter.count(0))
old : Address(Counter.Msg)
> :reload
Counter, compiled again
Counter.Msg changed: the binding old is of its previous version, Counter$1.Msg
> let new = spawn(fn() = Counter.count(0))
new : Address(Counter.Msg)
> send(old, Counter.Reset)
input 4:1:11: the argument does not fit send: expected Counter$1.Msg, found Counter.Msg
  = help: Counter$1.Msg is of a previous version of Counter, which a reload replaced
```

The same counter runs on a peer that holds none of its code. A spawn names its function by hash, and a peer that lacks it is sent the definition with every definition it references, before the process starts. `foo` is a bare node, started from a configuration directory and no program. It holds no code of the counter's, and runs whichever version the spawn names:

```ernest-fragment
match Peer.spawn("foo", fn() = count(0), 5000) {
    Right(counter) -> send(counter, Inc(5))
  | Left(failure) -> Io.println("no foo: " <> Io.show(failure))
}
```

`Peer.spawn` waits at most 5000 milliseconds for the peer, and answers `Left` with the reason where it cannot reach it.

A computation need not name a node at all. `Peer.compute(f, ms)` runs `f` on the less busy of two peers drawn from those the node knows, carrying its code there as the spawn does, and answers the value, or `Left` with the reason where no peer can be reached within `ms`:

```ernest-fragment
match Peer.compute(fn() = render(scene, row), 5000) {
    Right(pixels) -> putRow(row, pixels)
  | Left(failure) -> Io.println("no peer: " <> Io.show(failure))
}
```

Nothing was installed on the peer, and nothing names it: the node that ran `render` was whichever had room when the row was asked for.

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

`ern config` makes the directory, the node's private key and its certificate, and prints the public key, which is what another node lists. `services`, empty here, names for each service a program looks up by name the peers that may offer it.

A listed peer is trusted whole. One that may spawn on a node may run anything on it, so the list of peers is the whole of the trust.

A peer that goes out of reach is a `Down` with the reason `Unreachable` to whoever monitors a process on it, which says nothing of whether the process lives. A program is written for that case as for any other end.

### Abstract types and requirements

A reader who knows another language looks for a type class, an interface or a trait. Three things stand in their place, and each is shown here.

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

A *requirement* names the one operation a generic function needs of its type. `sorted` needs a `compare` of `a`, the type of the list's elements. Written with `Int.compare` it would sort integers alone. Written with `needs`, a call supplies nothing, and the compiler finds the `compare` declared under the element type's name.

```ernest
fn sorted(list : List(a)) : List(a) needs a.compare =
    List.sort(list, a.compare)

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

One `sorted` sorts integers and strings. Nothing declared `Int` or `String` sortable: each has its own `compare`, and the compiler supplies it. A type of the program's own gets one by `derives compare`, or by declaring the function under its name.

An *operations record* is a record of functions, filled from a module by naming it. `Operations(..Set)` takes `fromList` and `toList` from the module `Set`, and `Operations(..OrderedSet)` the same two from `OrderedSet`. `Set` is the prelude's type, in scope everywhere and with no order of its own; `OrderedSet` is a module of the standard library, so its type is written whole, `OrderedSet.Set`:

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

`sorted` and `unique` are not two ways to one thing. A requirement asks for what every element type has of its own, and a record carries what the caller chooses. What a class, an interface or a trait would have added, a declared instance, a hierarchy, a dispatch decided as the program runs, the three do without. The guide's §7 teaches them.

### A deadlock is found

No program shows this claim, and it follows from the first; its evidence is a line of the report and a page of the design. A program in which every process waits for a message none can send ends with `Fault("deadlock")` and a trace, under `ern run`, under `ern test`, where it is the test's fault and the run goes on, and in the shell (report §8.6, §11.2). On Erlang that program waits forever, and a programmer learns of it from a timeout, a dashboard or a user, which is why every call there carries a default of five seconds.

Ernest can decide it because the runtime owns every source of a message. A mailbox is typed and reached through an address the program holds; a process is spawned by the runtime, which monitors it; a timer, a socket, a file and a running program are system processes that count what they hold; foreign code is entered through a declaration, and a process inside it is read as able to be delivered to. So "nothing can deliver and everyone waits" is a question with an answer, and the runtime asks it when a program has been quiet for a while, never on a node, which a peer can always reach. A deadlock is quiescence, not a cycle, and the look may be late but is never wrong.

What it costs a program is what the design note of the runtime states ([`docs/design/runtime.md`](../docs/design/runtime.md)): a mark a process leaves in its own state as it enters foreign code through a callback, a timed receive or a call, which costs it nanoseconds and no other process anything; and one reading of every process when the program seems idle, which a program at work never pays. A foreign call that answers at once costs what the host's call costs and a `try`. The log's *The Sitting on §8.6's Bookkeeping* measured each piece.

### Little else

No program shows this claim. Its evidence is the report under `report/`: the language, the toolchain and the library, a file each, which state everything the programs above rely on.

## Reading on

The guide's §0 shows what the compiler refuses and how it says so, and its §1 runs the first program. The questions a reader brings, the likeness to Gleam among them, are answered in [the questions](faq.md). The reasons behind each rule, dated, are the log's, [`docs/log.md`](../docs/log.md).
