<picture>
  <source media="(prefers-color-scheme: dark)"
          srcset="assets/ernest-combined-dark.svg">
  <source media="(prefers-color-scheme: light)"
          srcset="assets/ernest-combined-light.svg">
  <img src="assets/ernest-combined-light.svg" alt="Ernest" width="520">
</picture>

# Ernest

Ernest is a small functional language for concurrent programs, on the Erlang runtime. A program is functions, whose types the compiler infers, and processes that talk through typed mailboxes. Its parts come from elsewhere: Erlang's processes, the types of ML, which Gleam made ordinary on that runtime, and Unison's small core and its code known by the hash of its definition. What Ernest adds is where the parts meet:

- **The mailbox in the function's type.** A message no clause matches waits in a mailbox for ever, and nothing says so until it does. In Ernest a process receives one type of message, and a function that receives says which, `receiving CounterMsg`. An address carries the same type, so every `send` is checked against the mailbox it reaches, and every `receive` against the mailbox it reads. A service is a top-level binding of such an address, which `restarting` keeps good across the process's faults, so there is no registry: a server is reached by writing its name.
- **Code known by its hash.** A module is loaded by name, two versions at a time, and a function sent to a node that lacks its module fails there. In Ernest a definition is known by the hash of its form. A module has as many versions as it has had, each named apart, and a running process takes a new version of its function as a message. A spawn carries its function to a peer that lacks it, with every definition it reaches, so any node can run anything: a bare node joins with no program of its own, and work is placed where there is room, with no deployment first.
- **A distribution built for a WAN.** A cluster, as the runtime has it, is a set of nodes on one trusted network, each connected to every other and all sharing one secret. In Ernest a node lists its peers by name, public key and address, accepts a connection from a listed key alone, and opens one TLS connection to a peer when an operation first needs it. No mesh and no port mapper: the key is the identity, and a laptop and a server, or two data centers, are two nodes with one file each naming the other.
- **Little else.** Two concepts, five principles, one way for each thing, and a report of three files that is the whole language.

Ernest is for programs written in it from the start. An Ernest program is not an OTP application and is not mixed with Elixir or Gleam code; a library that ships with Erlang/OTP comes as a shim, and anything else is written in Ernest.

## The four, in code

**The mailbox in the function's type.** A counter is a process that holds a number. Its mailbox type, `CounterMsg`, is in the type of `count`, so a `send` of anything else to its address is refused before the program runs, `the argument does not fit send: expected CounterMsg, found String`:

```ernest
type CounterMsg = Inc(Int) | Get(Reply(Int))

fn count(total : Int) : Unit receiving CounterMsg =
    receive {
        Inc(amount) -> count(total + amount)
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
        Inc(amount) -> count(total + amount)
      | Get(reply) -> {
            answer(reply, total);
            count(total)
        }
      | Upgrade(next = next) -> next(total)
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
- **[`examples/`](examples/)** holds complete programs, from `hello.ern` to a game at a terminal, [`snake.ern`](examples/snake.ern), and a small web server, [`web_server.ern`](examples/web_server.ern); [`examples/README.md`](examples/README.md) lists them in an order to read them, with what each shows.
- **[The manual pages](docs/man/)**, as `make man` last wrote them from `main`, the prelude's, every standard library module's and every library's, as `man Ernest.List` shows them where Ernest is installed.
- **[The report](report/language.md)** is where the details are: the language's definition, which everything else defers to, in three files under `report/`, the language, the toolchain and the standard library.
- **[Working on Ernest](docs/development.md)** is for those who work on the language and its toolchain, and says how the repository is laid out: `report/` and `guide/` are the language, `src/` holds the Ernest a release ships and `erl/` the Erlang, `editors/` holds the editor modes, and `docs/` every other document.

## License

Ernest is released under the terms in [`LICENSE`](LICENSE). Third-party components are listed, with their licenses, in [`THIRD_PARTY_LICENSES`](THIRD_PARTY_LICENSES).
