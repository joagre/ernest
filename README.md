<picture>
  <source media="(prefers-color-scheme: dark)"
          srcset="assets/ernest-dark.svg">
  <source media="(prefers-color-scheme: light)"
          srcset="assets/ernest-light.svg">
  <img src="assets/ernest-light.svg" alt="Ernest" width="50%">
</picture>

# Ernest

Ernest is a small functional language for concurrent programs, on the Erlang runtime. A program is pure functions, whose types the compiler infers, and processes that talk through typed mailboxes. Most of its parts come from elsewhere: the Erlang runtime's processes, Gleam's static types on that runtime, and Unison's code known by the hash of its definition, planned here, which is what will let a message be checked across nodes. What Ernest adds is where the parts meet:

- **The mailbox in the function's type.** A process receives one type of message, and the functions it runs say so, `with CounterMsg`. An address carries the same type, so every `send` is checked against its receiver: an address's type is the type of the mailbox it reaches.
- **Checked replies.** A request carries a `Reply`, answered exactly once on every path, which the compiler checks as it checks types. `Address.call` waits with a deadline, so an answer that never comes is a case the program handles.
- **Purity in the type.** `with` separates the functions that may send or receive from those that cannot. A pure function computes and returns, and the compiler holds it to that.
- **Distribution by content, planned.** Every function and type is known by a hash of its definition, a type's name included, so a message is checked across nodes as it is within one. Code travels only with a process spawned on a peer, and two versions of a type are two types.

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

It is young. The language and its toolchain are complete enough for programs on one node, and programs across nodes come in a later release, with MVP 3.0, the plan's milestone for peers, which is the name a message gives where a program asks for them; where the project stands is "Where we are" in the [plan](docs/implementation_plan.md). Until 1.0 a release may refuse a program the previous release accepted, as the plan's MVP 3.9 says; each release's notes, on the [releases page](https://github.com/joagre/ernest/releases), say where to read what changed.

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

`make install PREFIX=$HOME/.local` installs Ernest for you alone, with no `sudo`, where `~/.local/bin` is on your `PATH`. `make uninstall`, with the same `PREFIX`, removes it. Without installing, the checkout's `bin/ern` runs in place. The Emacs mode is installed with the rest, as `share/emacs/site-lisp/ernest-mode.el`, and [`emacs/README.md`](emacs/README.md) says how to turn it on.

## Reading more

- **[The guide](ernest_guide.md)**, *Programming in Ernest*, teaches the language to a programmer who knows another. Start here.
- **[`examples/`](examples/)** holds complete programs, from `hello.ern` to a game at a terminal, [`snake.ern`](examples/snake.ern), and a small web server, [`web_server.ern`](examples/web_server.ern); guide §14 says what the larger ones show.
- **[The manual pages](man/)** of the latest release, the prelude's, every standard library module's and every library's, as `man Ernest.List` shows them where Ernest is installed.
- **[The report](report/language.md)** is where the details are: the language's definition, which everything else defers to, in three files under `report/`, the language, the toolchain and the standard library.
- **[Working on Ernest](docs/development.md)** is for those who work on the language and its toolchain.

## License

Ernest is released under the terms in [`LICENSE`](LICENSE). Third-party components are listed, with their licenses, in [`THIRD_PARTY_LICENSES`](THIRD_PARTY_LICENSES).
