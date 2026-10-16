*A draft of the top-level `README.md` as it will read once MVP 3.2 has shipped as Ernest 0.4.0, written 2026-10-12 for one reader. It is not the README: the fourth of the four additions changes with the guide's §0 list, which a test holds word for word, and the deployment guide it points at is item 8's. It goes when the README is rewritten from it.*

---

<picture>
  <source media="(prefers-color-scheme: dark)"
          srcset="assets/ernest-combined-dark.svg">
  <source media="(prefers-color-scheme: light)"
          srcset="assets/ernest-combined-light.svg">
  <img src="assets/ernest-combined-light.svg" alt="Ernest" width="75%">
</picture>

# Ernest

Ernest is a small functional language for concurrent programs, on the Erlang runtime. A program is pure functions, whose types the compiler infers, and processes that talk through typed mailboxes, on one node or on many. Most of its parts come from elsewhere: the Erlang runtime's processes, Gleam's static types on that runtime, and Unison's code known by the hash of its definition, which is what lets a message be checked across nodes and a function run on a node that has never seen its code. What Ernest adds is where the parts meet:

- **The mailbox in the function's type.** A process receives one type of message, and the functions it runs say so, `with CounterMsg`. An address carries the same type, so every `send` is checked against its receiver: an address's type is the type of the mailbox it reaches.
- **Checked replies.** A request carries a `Reply`, answered exactly once on every path, which the compiler checks as it checks types. `Address.call` waits with a deadline, so an answer that never comes is a case the program handles.
- **Purity in the type.** `with` separates the functions that may send or receive from those that cannot. A pure function computes and returns, and the compiler holds it to that.
- **Code by its hash, across nodes.** Any number of a module's revisions run side by side, and a function spawned on a peer carries the code the peer lacks. Every definition is known by the hash of what it means, so two nodes agree on a type without agreeing on a build: a message is checked against the type the receiver was compiled with, and the definitions a spawn carries are verified by their hashes before any of it runs. A value bound to its node, a resource or a function value, is refused at a service or a spawn, so nothing crosses that cannot mean the same thing on the other side.

Ernest is for programs written in it from the start. An Ernest program is not an OTP application and is not mixed with Elixir or Gleam code; a library that ships with Erlang/OTP comes as a shim, and anything else is written in Ernest.

A counter is a process that holds a number. Its mailbox type, `CounterMsg`, is in its type, so a `send` of anything else is refused, and a `Get` that the counter left unanswered would be refused too:

```ernest
type CounterMsg = Inc(Int) | Get(reply : Reply(Int))

fn count(total : Int) : Unit with CounterMsg =
    receive {
        Inc(amount) -> count(total + amount)
      | Get(reply = reply) -> {
            answer(reply, total);
            count(total)
        }
    }

export fn main() : Unit with Never = {
    let counter = spawn(fn() = count(0));
    send(counter, Inc(5));
    send(counter, Inc(3));
    match Address.call(counter, fn(reply) = Get(reply = reply), 1000) {
        Some(total) -> Io.println("count is " <> Int.toString(total))
      | None -> Io.println("counter did not answer")
    }
}
```

`main` receives nothing, `with Never`, and spawns the counter on this node. `Address.call` gives `Get` a `Reply(Int)` of its own, which the counter answers once with `answer`, and waits for the answer at most 1000 milliseconds: `None` is an answer that did not come.

The same counter runs on another node with one change. A node is a program started with a configuration directory, which names its peers, and `Peer.spawn` starts a process on one of them by name:

```ernest
export fn main() : Unit with Never =
    match Peer.spawn("b", fn() = count(0), 5000) {
        Right(counter) -> {
            send(counter, Inc(5));
            send(counter, Inc(3));
            match Address.call(counter, fn(reply) = Get(reply = reply), 1000) {
                Some(total) -> Io.println("count on b is " <> Int.toString(total))
              | None -> Io.println("counter did not answer")
            }
        }
      | Left(error) -> Io.println("no counter on b: " <> Io.show(error))
    }
```

Node `b` need not hold this program. Where it lacks `count`, the spawn carries the definition and everything it references, each verified against its hash, and the process starts once all of it is loaded; a node started with no program at all, a *bare node*, takes whatever its peers spawn on it. The address that comes back is typed `Address(CounterMsg)` as on one node, and the `send` and the `call` are checked the same way. A peer that is not listed, not reachable, or not answering in time is a `Left` the program handles; a service a node offers by name is found the same way, with `Peer.find`.

Ernest 0.4.0 is the first release with nodes: peers, services found by name and checked by type, work placed on the least busy node, code shipped with a spawn, a shell attached to a running node, and a program's own code moving a running service to a fix. It is young. Until 1.0 a release may refuse a program the previous release accepted, as the plan's MVP 3.9 says; where the project stands is "Where we are" in the [plan](docs/implementation_plan.md), and each release's notes, on the [releases page](https://github.com/joagre/ernest/releases), say where to read what changed.

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

Two nodes on one machine take three more commands: `ern config` makes each node's directory with its key, `ern run --config-dir` starts it, and `ern stop --config-dir` ends it. The deployment guide walks through them.

## Reading more

- **[The guide](guide/language.md)**, *Programming in Ernest*, teaches the language to a programmer who knows another, from a first program to processes across nodes. Start here.
- **[The deployment guide](guide/deployment.md)**, *Running Ernest*, is for whoever runs nodes: a node's directory and its service manager, several builds on one floor, a fix shipped with a spawn, a bare node given its work, and a running service moved to new code.
- **[`examples/`](examples/)** holds complete programs, from `hello.ern` to a game at a terminal, [`snake.ern`](examples/snake.ern), a small web server, [`web_server.ern`](examples/web_server.ern), and a counter found across nodes, [`typed_channels_nodes.ern`](examples/typed_channels_nodes.ern); [`examples/README.md`](examples/README.md) lists them by topic, with what each shows.
- **[The manual pages](docs/man/)**, as `make man` last wrote them from `main`, the prelude's, every standard library module's and every library's, as `man Ernest.List` shows them where Ernest is installed.
- **[The report](report/language.md)** is where the details are: the language's definition, which everything else defers to, in three files under `report/`, the language, the toolchain and the standard library.
- **[Working on Ernest](docs/development.md)** is for those who work on the language and its toolchain, and says how the repository is laid out: `report/` and `guide/` are the language, `src/` holds the Ernest a release ships and `erl/` the Erlang, `editors/` holds the editor modes, and `docs/` the project's own documents.

## License

Ernest is released under the terms in [`LICENSE`](LICENSE). Third-party components are listed, with their licenses, in [`THIRD_PARTY_LICENSES`](THIRD_PARTY_LICENSES).
