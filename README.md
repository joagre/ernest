# Ernest

Ernest is a small functional language for concurrent programs, on the Erlang runtime. A program is pure functions, whose types the compiler infers, and processes that talk through typed mailboxes. Most of its parts come from elsewhere: the Erlang runtime's processes, Gleam's static types on that runtime, and Unison's code known by the hash of its definition. What Ernest adds is where the parts meet:

- **The mailbox in the function's type.** A process receives one type of message, and the functions it runs say so, `with CounterMsg`. An address carries the same type, so every `send` is checked against its receiver. Gleam types the channel a message travels on; Ernest types the process.
- **Checked replies.** A request carries a `Reply`, answered exactly once on every path, which the compiler checks as it checks types. `Address.call` waits with a deadline, so an answer that never comes is a case the program handles.
- **Purity in the type.** `with` separates the functions that may send or receive from those that cannot. A pure function computes and returns, and the compiler holds it to that.
- **Distribution by content, planned and not yet built.** Unison's content addressing, on the Erlang runtime. Every function and type is known by a hash of its definition, a type's name included, so a message is checked across nodes as it is within one. Code travels only with a process spawned on a peer, which brings the definitions it needs, the peer fetching what it has not seen; a message between nodes is values. Two nodes need not run the same version of a program, and two versions of a type are two types, never one type read two ways.

It is young. The language and its toolchain are complete enough for programs on one node, and programs across nodes come after the first release, which is on its way; where the project stands is "Where we are" in the [plan](docs/implementation_plan.md).

## Installing

On Linux, with Erlang/OTP 29 on your `PATH`, GNU make and a C compiler, in a checkout of this repository; macOS is expected to work the same way, and is not yet verified:

```
make
sudo make install                  # into /usr/local
ern build examples/hello.ern
ern run examples/hello.erc         # hello, world
ern shell                          # :quit to leave
man ern                            # the toolchain; man Ernest.List for a module
```

`make install PREFIX=$HOME/.local` installs Ernest for you alone, with no `sudo`, where `~/.local/bin` is on your `PATH`. `make uninstall`, with the same `PREFIX`, removes it. The installation can be moved to another directory whole, and runs there. Without installing, the checkout's `bin/ern` runs in place. The Emacs mode is installed with the rest, and [its page](docs/emacs_mode.md) says how to turn it on.

## Reading more

- **[The guide](ernest_guide.md)**, *Programming in Ernest*, teaches the language to a programmer who knows another. Start here.
- **[`examples/`](examples/)** holds complete programs, from `hello.ern` to a game at a terminal, [`snake.ern`](examples/snake.ern), and a small web server, [`webserver.ern`](examples/webserver.ern); guide §14 says what each shows.
- **[The report](ernest_report.md)** is where the details are: the language's definition, which everything else defers to.
- **[Working on Ernest](docs/development.md)** is for those who work on the language and its toolchain.

## License

Ernest is released under the terms in [`LICENSE`](LICENSE). Third-party components are listed, with their licenses, in [`THIRD_PARTY_LICENSES`](THIRD_PARTY_LICENSES).
