# Why Ernest

The argument for the design, in five claims, and a program for each that code can show. [*Programming in Ernest*](language.md), the guide, teaches the language; this document says why it is as it is.

Ernest is a small functional language for concurrent programs, on the Erlang runtime. A program is functions, whose types the compiler infers, and processes that talk through typed mailboxes. Its parts come from elsewhere: Erlang's processes, the types of ML, which Gleam made ordinary on that runtime, and Unison's small core and its code known by the hash of its definition. What Ernest adds is where the parts meet:

- **The mailbox in the function's type.** Every process receives messages of one type. A function that receives names that type in its own type, and a process's address carries it too. So the compiler checks every message sent against the mailbox it will reach, and every receive against the mailbox it reads. A server is such an address bound to a name at the top of a module. The address stays good while the process behind it is restarted after a fault. A program reaches its servers by name, and can never send one a message it does not take.
- **Code known by its hash.** A function or a type is known by a hash of its definition, not by the name of the module it stands in. Two versions of a module run side by side. A running process moves to the new version of its function when a message tells it to. A process started on another node brings its code along, so any node can run anything. A node with no program of its own joins, and work is placed where there is room, with nothing deployed first.
- **A distribution built for a WAN.** A node lists its peers in a file, each by name, public key and address. It accepts a connection only from a key it lists, and opens one TLS connection to a peer when it first needs it. There is no cluster to join and no shared secret. A laptop and a server, or two data centers, are two nodes with one file each naming the other.
- **Abstract types and requirements.** A type declared abstract keeps its constructor to its own module. Other modules hold its values and reach them through the functions it exports, so the representation can change and no caller knows. A generic function names the one operation it needs of its type, and the compiler supplies that type's own at each call. Nothing is declared an instance of anything: there is no type class, interface or trait.
- **Little else.** Functions and processes are the whole language, with one way to do each thing. A report of three files defines all of it. Five principles decide what goes in, and the first is that nothing surprises a reader who knows the rest.

Ernest is for programs written in it from the start. An Ernest program is not an OTP application and is not mixed with Elixir or Gleam code; a library that ships with Erlang/OTP comes as a shim, and anything else is written in Ernest.

## The claims, in code

**The mailbox in the function's type.** A counter is a process that holds a number. Its mailbox type, `CounterMsg`, is in the type of `count`, so a `send` of anything else to its address is refused before the program runs, `the argument does not fit send: expected CounterMsg, found String`:

```ernest
type CounterMsg = Inc(Int) | Get(Reply(Int))

fn count(total : Int) : Unit receiving CounterMsg =
    receive {
        Inc(amount) ->
            count(total + amount)
      | Get(reply) -> {
            answer(reply, total);
            count(total)
        }
    }

export fn main() : Unit = {
    let counter = spawn(fn() = count(0));
    send(counter, Inc(5));
    send(counter, Inc(3));
    match Address.call(counter, Get, 1000) {
        Some(total) -> Io.println("count is " <> Int.toString(total))
      | None -> Io.println("counter did not answer")
    }
}
```

`main` receives nothing, so its type names no mailbox, and it spawns the counter on this node. `Address.call` gives `Get` a `Reply(Int)` of its own, which the counter answers with `answer`, and waits for the answer at most 1000 milliseconds: `None` is an answer that did not come.

**Code known by its hash.** The counter replaces its own code while it runs. A message of its type carries the new loop, and the process switches to it with a tail call, keeping its address and its state; the old version runs on wherever a process still runs it:

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

In the shell the versions are visible. A module compiled again after an edit is a new version beside the old, and a binding made under the old keeps it. Here the counter is a module `Counter` whose message type is `Msg`; `Msg` gained a `Reset` between the two spawns, both processes run, and a message of the new type to the old process is refused with the reason.

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

The same counter runs on a peer that holds none of its code. A spawn names its function by hash, and a peer that lacks it is sent the definition with every one it reaches, before the process starts. `foo` may be a bare node, started with a configuration and no program:

```ernest-fragment
match Peer.spawn("foo", fn() = count(0), 5000) {
    Right(counter) -> send(counter, Inc(5))
  | Left(failure) -> Io.println("no foo: " <> Io.show(failure))
}
```

**A distribution built for a WAN.** A node is a program started with a configuration directory. Its `ernest.conf` lists the peers it knows, each by a name, a public key and an address. A connection is accepted from a listed key alone, under the name the key gives it, and is opened over TLS when an operation first needs it:

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

**Abstract types and requirements.** A reader who knows another language looks for a type class, an interface or a trait. Three things stand in their place, and each is shown here.

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

A *requirement* names the one operation a generic function needs of its type. `sorted` needs a `compare` of `a`, the type of the list's elements, and a call supplies nothing: the compiler finds the `compare` declared under that type's name.

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

One `sorted` sorts integers and strings. Nothing declared `Int` or `String` sortable: each has its own `compare`, and the compiler supplies it.

An *operations record* is a record of functions, filled from a module by naming it. `Operations(..Set)` takes `fromList` and `toList` from the module `Set`, and `Operations(..OrderedSet)` the same two from `OrderedSet`:

```ernest
type Operations(s, a) = Operations(fromList : (List(a)) -> s, toList : (s) -> List(a))

let hashed : Operations(Set(Int), Int) = Operations(..Set)

let ordered : Operations(OrderedSet.Set(Int), Int) = Operations(..OrderedSet)

fn unique(list : List(a), operations : Operations(s, a)) : List(a) =
    operations.toList(operations.fromList(list))

export fn main() : Unit = {
    Io.println(Io.show(unique([3, 1, 3], ordered)));
    Io.println(Int.toString(List.size(unique([3, 1, 3], hashed))))
}
```

```console
$ ern run unique.erc
[1, 3]
2
```

`unique` is one function over two representations, and the caller chooses at each call. `Operations` is the program's own record of the two functions it uses; the standard library declares no such record. What a class, an interface or a trait would have added, a declared instance, a hierarchy, a dispatch the reader cannot see, the three do without. The guide's chapter 7 teaches them.

**Little else.** No program shows this claim. Its evidence is the report under `report/`: the language, the toolchain and the library, a file each, which state everything the programs above rely on.

## Reading on

The guide's §0 shows what the compiler refuses and how it says so, and its §1 runs the first program. The questions a reader brings, the likeness to Gleam first, are answered in [the questions](faq.md). The reasons behind each rule, dated, are the log's, [`docs/decisions.md`](../docs/decisions.md).
