<picture>
  <source media="(prefers-color-scheme: dark)"
          srcset="assets/ernest-combined-dark.svg">
  <source media="(prefers-color-scheme: light)"
          srcset="assets/ernest-combined-light.svg">
  <img src="assets/ernest-combined-light.svg" alt="Ernest" width="520">
</picture>

# Ernest

Ernest is a small functional language for concurrent programs, on the Erlang runtime. A program is functions, whose types the compiler infers, and processes that talk through typed mailboxes. Its parts come from elsewhere: Erlang's processes, the types of ML, which Gleam made ordinary on that runtime, and Unison's small core and its code known by the hash of its definition. What Ernest adds is where the parts meet:

- **The mailbox in the function's type.** Every process receives messages of one type. A function that receives says that type in its own type, and a process's address carries it too. So the compiler checks every message sent against the mailbox it will reach, and every receive against the mailbox it reads. A server is such an address bound to a name at the top of a module. The address stays good while the process behind it is restarted after a fault. A program reaches its servers by name, and can never send one a message it does not take.
- **Code known by its hash.** A function or a type is known by a hash of its definition, not by the name of the module it stands in. A module reloaded is a new version beside its earlier ones, as many as there have been, and each keeps running wherever a process still runs it. A running process moves to the new version of its function when a message tells it to. A process started on another node brings its code along, so any node can run anything. A node with no program of its own takes part, a computation that names no node goes to one with room, and no program is deployed first.
- **A distribution built for a WAN.** A node lists its peers in a file, each by name, public key and address. It accepts a connection only from a key it lists, and opens one TLS connection to a peer when it first needs it. There is no cluster to join and no shared secret. A laptop and a server, or two data centers, are two nodes with one file each naming the other.
- **Abstract types and requirements.** A type declared abstract keeps its constructor to its own module. Other modules hold its values and reach them through the functions it exports, so the representation can change and no caller knows. A generic function names the one operation it needs of its type, and the compiler supplies that type's own at each call. A type's operation is a function declared under the type's name, nothing is declared an instance of anything, and there is no type class, interface or trait.
- **Little else.** Functions and processes are the whole language, with one way to do each thing. A report of three files defines all of it. Five principles decide what goes in, and the first is that nothing surprises a reader who knows the rest.

Ernest is for programs written in it from the start. An Ernest program is not an OTP application and is not mixed with Elixir or Gleam code; What ships with Erlang/OTP is reached through declarations that give it Ernest types, which a program may write for itself, and anything else is written in Ernest.

## The claims, in code

**The mailbox in the function's type.** A counter is a process that holds a number. Its mailbox type, `CounterMsg`, is in the type of `count`, so a `send` of anything else to its address is refused before the program runs, `the argument does not fit send: expected CounterMsg, found String`. `counter` is the program's counter, bound at the top of the module and started under `restarting`, so any module sends to it by name, and a fault in `count` starts it again with the address kept:

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

`main` receives nothing, so its type names no mailbox. The counter is spawned on this node as the program starts, before `main` runs. `Address.call` gives `Get` a `Reply(Int)` of its own, which the counter answers with `answer`, and waits for the answer at most 1000 milliseconds: `None` is an answer that did not come.

A fault, a division by zero or a `fault` call, ends the process, and nothing catches it. Whoever monitors the process hears of its end as a message of their own type. A process started under `restarting` runs its function again in place after a fault, keeping its address, so the name `counter` stays good; the guide's §6.5 shows a restart.

**Code known by its hash.** The hash is never written in a program. It is what tells two versions of a definition apart, and what a peer asks for. The counter replaces its own code while it runs. A message of its type carries the new loop, and the process switches to it with a tail call, keeping its address and its state; the old loop keeps running wherever a process still runs it. `countTwice` is a loop of the same type, sent as a value:

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

**A distribution built for a WAN.** A node is Ernest started from a configuration directory, with a program or with none. Its `ernest.conf` lists the peers it knows, each by a name, a public key and an address. A connection is accepted from a listed key alone, under the name listed beside that key, and is opened over TLS when an operation first needs it:

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

An *operations record* is a record of functions, filled from a module by naming it. `Operations(..Set)` takes `fromList` and `toList` from the module `Set`, and `Operations(..OrderedSet)` the same two from `OrderedSet`. `Set` is the standard library's, in scope everywhere and with no order of its own, and `OrderedSet` is a library, so its type is written whole:

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

**Little else.** No program shows this claim. Its evidence is the report under `report/`: the language, the toolchain and the library, a file each, which state everything the programs above rely on.

## Where it stands

It is young. Programs run on one node and across nodes; 0.4.0, the first release with nodes, is the plan's next tag, and where the project stands is "Where we are" in the [plan](docs/implementation_plan.md). Until 1.0 a release may refuse a program the previous release accepted, as the plan's MVP 3.9 says; each release's notes, on the [releases page](https://github.com/joagre/ernest/releases), say where to read what changed.

## Installing

On Linux, with Erlang/OTP 29 on your `PATH`, GNU make and a C compiler; macOS is expected to work the same way, and is not yet verified:

```
git clone https://github.com/joagre/ernest.git
cd ernest
make
sudo make install                  # into /usr/local
ern build examples/hello.ern
ern run examples/hello.erc         # hello, world
ern shell                          # :quit to leave
man ern                            # the toolchain; man Ernest.List for a module
```

Or from a release: download `ern-<version>.tar.gz` from the [releases page](https://github.com/joagre/ernest/releases), and in the directory it unpacks to run `make` and `sudo make install`, as its own README says; the archive is compiled where it is installed.

`make install PREFIX=$HOME/.local` installs Ernest for you alone, with no `sudo`, where `~/.local/bin` is on your `PATH`. `make uninstall`, with the same `PREFIX`, removes it. Without installing, the checkout's `bin/ern` runs in place. The Emacs mode is installed with the rest, as `share/emacs/site-lisp/ernest-mode.el`, and [`editors/emacs/README.md`](editors/emacs/README.md) says how to turn it on.

## Reading more

- **[The guide](guide/language.md)**, *Programming in Ernest*, teaches the language to a programmer who knows another. Start here. Beside it, [Why Ernest](guide/why.md) is the argument above, whole, and [the questions](guide/faq.md) answer what a reader of another BEAM language asks first.
- **[`examples/`](examples/)** holds complete programs, from `hello.ern` to a game at a terminal, [`snake.ern`](examples/snake.ern), and a small web server, [`web_server.ern`](examples/web_server.ern); [`examples/README.md`](examples/README.md) lists them by topic, with what each shows.
- **[The manual pages](docs/man/)**, as `make man` last wrote them from `main`, the prelude's, every standard library module's and every library's, as `man Ernest.List` shows them where Ernest is installed.
- **[The report](report/language.md)** is where the details are: the language's definition, which everything else defers to, in three files under `report/`, the language, the toolchain and the standard library.
- **[Working on Ernest](docs/development.md)** is for those who work on the language and its toolchain, and says how the repository is laid out: `report/` and `guide/` are the language, `src/` holds the Ernest a release ships and `erl/` the Erlang, `editors/` holds the editor modes, and `docs/` every other document.

## License

Ernest is released under the terms in [`LICENSE`](LICENSE). Third-party components are listed, with their licenses, in [`THIRD_PARTY_LICENSES`](THIRD_PARTY_LICENSES).
