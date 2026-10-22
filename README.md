<picture>
  <source media="(prefers-color-scheme: dark)"
          srcset="assets/ernest-combined-dark.svg">
  <source media="(prefers-color-scheme: light)"
          srcset="assets/ernest-combined-light.svg">
  <img src="assets/ernest-combined-light.svg" alt="Ernest" width="520">
</picture>

# Ernest

Ernest is a small functional language for concurrent programs, on the Erlang runtime. A program is functions, whose types the compiler infers, and processes that talk through typed mailboxes.

Its parts come from elsewhere: Erlang's processes, the types of ML, which Gleam made ordinary on that runtime, and Unison's small core and its code known by the hash of its definition.

What Ernest adds is where the parts meet, six claims that [Why Ernest](guide/why.md) argues, with a program for each but the last two:

- **[The mailbox in the function's type](guide/why.md#the-mailbox-in-the-functions-type).** A function that receives says what it receives, and the compiler checks every message against the mailbox it will reach.
- **[Code known by its hash](guide/why.md#code-known-by-its-hash).** A module's versions run side by side, a running process moves to a new one when told, and a process spawned on another node brings its code along.
- **[A distribution built for a WAN](guide/why.md#a-distribution-built-for-a-wan).** Two nodes are two files, each naming the other by key and address, with one TLS connection between them and no cluster to join.
- **[Abstract types and requirements](guide/why.md#abstract-types-and-requirements).** A type keeps its representation to its module, and a generic function names the one operation it needs, which the compiler supplies at each call.
- **[Little else](guide/why.md#little-else).** Functions and processes are the whole language, and a report of three files defines all of it.
- **[A deadlock is found](guide/why.md#a-deadlock-is-found).** A program in which every process waits for a message none can send ends with a fault and a trace, since the runtime owns every source of a message, at no cost to a program at work.

Ernest is for programs written in it from the start, not for an OTP application or a codebase of several languages; [Why Ernest](guide/why.md) says how it meets Erlang.

A counter is a process that holds a number. Its mailbox type, `CounterMsg`, is in the type of `count`, so a `send` of anything else to its address is refused before the program runs. `counter` is bound at the top of the module under `restarting(Unlimited, f)`, which runs `f` again after every fault in the same process, so any module sends to it by name and a fault keeps the address:

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

`main` receives nothing, so its type names no mailbox. `Address.call` gives `Get` a `Reply(Int)` of its own, which the counter answers with `answer`, and waits at most 1000 milliseconds: `None` is an answer that did not come. The same counter on a node that holds none of its code, and the rest of the argument, is [Why Ernest](guide/why.md).

## Where it stands

It is young. Programs run on one node and across nodes, and 0.4.0, the first release with nodes, is the latest release. Where the project stands is "Where we are" in the [plan](docs/plan.md), and what the toolchain does not do yet is a table in [`docs/development.md`](docs/development.md). Until 1.0 a release may refuse a program the previous release accepted, as the plan says; each release's notes, on the [releases page](https://github.com/joagre/ernest/releases), say where to read what changed.

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

Or from a release: download `ern-<version>.tar.gz` from the [releases page](https://github.com/joagre/ernest/releases), and in the directory it unpacks to run `make` and `sudo make install`, as its own README says; the archive holds the source, which `make` compiles, with OTP 29 as above.

Two nodes on one machine take three more commands: `ern config` makes a node's directory with its key, `ern run --config-dir` starts the node, and `ern stop --config-dir` ends it; [the deployment guide](guide/deployment.md) walks through them.

`make install PREFIX=$HOME/.local` installs Ernest for you alone, with no `sudo`, where `~/.local/bin` is on your `PATH`. `make uninstall`, with the same `PREFIX`, removes it. Without installing, the checkout's `bin/ern` runs in place. The Emacs mode is installed with the rest, as `share/emacs/site-lisp/ernest-mode.el`, and [`editors/emacs/README.md`](editors/emacs/README.md) says how to turn it on.

## Reading more

- **[The guide](guide/language.md)**, *Programming in Ernest*, teaches the language to a programmer who knows another. Start here. Beside it, [Why Ernest](guide/why.md) is the argument for the design, and [the questions](guide/faq.md) answer what a reader of another BEAM language asks first.
- **[Style](guide/style.md)** is the rules a program is written by: its layout, its names, and the names every program shares.
- **[The deployment guide](guide/deployment.md)**, *Running Ernest*, is for whoever runs nodes: a node's directory and its service manager, its peers, and a running program given new code.
- **[`examples/`](examples/)** holds complete programs, from `hello.ern` to a game at a terminal, [`snake.ern`](examples/snake.ern), and a small web server, [`web_server.ern`](examples/web_server.ern); [`examples/README.md`](examples/README.md) lists them by topic, with what each shows.
- **[The manual pages](docs/man/)**, as Markdown: the prelude's, every standard library module's and every library's, which `man Ernest.List` shows where Ernest is installed.
- **[The report](report/language.md)** is where the details are: the language's definition, which everything else defers to, in three files under `report/`, the language, the toolchain and the standard library.
- **[`ernest-template`](https://github.com/joagre/ernest-template)** is where an application written in Ernest begins: a repository copied with *Use this template*, with one Makefile, the documents and the working rules of this repository cut to an application's size, and `TEMPLATE.md` saying why.
- **[Working on Ernest](docs/development.md)** is for those who work on the language and its toolchain, and says how the repository is laid out: `report/` and `guide/` are the language, `src/` holds the Ernest a release ships and `erl/` the Erlang, `editors/` holds the editor modes, and `docs/` every other document.

## License

Ernest is released under the Zero-Clause BSD license, 0BSD, the terms in [`LICENSE`](LICENSE). Third-party components are listed, with their licenses, in [`THIRD_PARTY_LICENSES`](THIRD_PARTY_LICENSES).
