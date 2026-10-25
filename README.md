<picture>
  <source media="(prefers-color-scheme: dark)"
          srcset="assets/ernest-combined-dark.svg">
  <source media="(prefers-color-scheme: light)"
          srcset="assets/ernest-combined-light.svg">
  <img src="assets/ernest-combined-light.svg" alt="Ernest" width="520">
</picture>

# Ernest

*The Importance of Being Ernest, a Trivial Comedy for Serious People*

Ernest is a small functional language for concurrent programs, on the Erlang runtime. A process receives messages of one type, which the compiler checks every send against, and a process started on another node brings its code along: nothing is installed there first.

`foo` is a *node*, a running program or shell that lists its peers in a configuration directory, started here with no program, `ern run --config-dir foo` in a terminal of its own, and it holds nothing of the counter's. The shell is a node too, and the two are two directories each listing the other by key and address, which [the tour](tour/README.md)'s chapter 2 makes, with a third, in seven commands. `Peer.spawn` starts `count` on `foo`, its code crossing with the spawn, and the shell counts on it from here:

```console
$ ern shell --config-dir a
listening on 0.0.0.0:8654
Ernest 0.6.0. :help for the commands, :quit to leave.
> :load Counter
Counter, compiled from counter.ern
> let far = match Peer.spawn("foo", fn() = Counter.count(0), 5000) { Right(address) -> address | Left(error) -> fault(Io.show(error)) }
the peer foo connected
far : Address(Counter.CounterMsg)
> send(far, Counter.Inc(5))
> send(far, Counter.Inc(3))
> Address.call(far, Counter.Get, 1000)
Some(8) : Optional(Int)
```

`counter.ern` is the whole of the counter. Its mailbox type, `CounterMsg`, is in the type of `count`, the loop the process runs, so that every message sent to its address is checked against it: `Inc` is sent, and `Get` is a call, `Address.call` making the reply, `Get` building the request around it, and the call waiting 1000 milliseconds at most for the answer:

```ernest
export type CounterMsg = Inc(Int) | Get(Reply(Int))

export fn count(total : Int) : Unit receiving CounterMsg =
    receive {
        Inc(amount) ->
            count(total + amount)
      | Get(reply) -> {
            answer(reply, total);
            count(total)
        }
    }
```

A function that receives runs only in a process whose mailbox takes what it receives, so `count` called by a `main` whose mailbox takes another type is refused before the program runs:

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

Its parts come from elsewhere: Erlang's processes, the types of ML, which Gleam made ordinary on that runtime, and Unison's small core and its code known by the hash of its definition.

What Ernest adds is where the parts meet, six claims that [Why Ernest](guide/why.md) argues, four of them with a program, one with its configuration file and one with the report:

- **[The mailbox in the function's type](guide/why.md#the-mailbox-in-the-functions-type).** A function that receives says what it receives, and the compiler checks every message against the mailbox it will reach.
- **[Code known by its hash](guide/why.md#code-known-by-its-hash).** A module's versions run side by side, a running process moves to a new one when told, and a process spawned on another node brings its code along.
- **[A distribution built for a WAN](guide/why.md#a-distribution-built-for-a-wan).** Two nodes are two configuration files, each naming the other by key and address, with one TLS connection between them and no cluster to join.
- **[Abstract types and requirements](guide/why.md#abstract-types-and-requirements).** A type keeps its representation to its module, and a generic function names the operations it needs, which the compiler supplies at each call.
- **[A deadlock is found](guide/why.md#a-deadlock-is-found).** A program in which every process waits for a message none can send ends with a fault and a trace under `ern run` and `ern test`; [Why Ernest](guide/why.md#a-deadlock-is-found) says where it cannot be found. Finding it costs a running program almost nothing.
- **[Little else](guide/why.md#little-else).** Functions and processes are the whole language, and a report of three files defines all of it.

Ernest is for programs written in it from the start, not for an OTP application or a codebase of several languages; [Why Ernest](guide/why.md) says how it meets Erlang.

Three ways in, each for a reader:

- **[The tour](tour/README.md)**, for the programmer who wants the whole picture in an evening: one program, a counter, grown through eight chapters from a process with a typed mailbox to the same counter on a node started with none of its code, moved to new code there. An hour to read, about three to do along.
- **[The guide](guide/language.md)**, *Programming in Ernest*, for the programmer learning the language, who has used a functional language: every rule taught where a program first needs it, with the report's section named. An afternoon to read; [`guide/README.md`](guide/README.md) says what stands beside it, for whom and how long.
- **[The report](report/README.md)**, for whoever builds or checks a toolchain or writes a library against the exact rules: the definition, three files, which everything else defers to.

The counter above is the first three claims at work, and the rest of the argument is [Why Ernest](guide/why.md).

## Where it stands

It is young. Programs run on one node and across nodes, and 0.6.0, the release after what that reading and 0.5.0 left was done, is the latest release. Where the project stands is "Where we are" in the [plan](docs/plan.md), and what the toolchain does not do yet is a table in [`docs/development.md`](docs/development.md). Until 1.0 a release may refuse a program the previous release accepted, as the plan says; each release's notes, on the [releases page](https://github.com/joagre/ernest/releases), say where to read what changed.

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

OTP 29 is built from its source at [erlang.org/downloads](https://www.erlang.org/downloads), or installed by a version manager such as kerl, where a distribution's own packages hold an older release.

Or from a release: download `ern-<version>.tar.gz` from the [releases page](https://github.com/joagre/ernest/releases), and in the directory it unpacks to run `make` and `sudo make install`, as its own README says; the archive holds the source, which `make` compiles, with OTP 29 as above.

Two nodes on one machine take four more commands: `ern config --config-dir` makes each node's directory with its key, `ern config --peer-dir` lists one node in the other's file, `ern run --config-dir` starts a node, and `ern stop --config-dir` ends it; [the deployment guide](guide/deployment.md) walks through them.

`make install PREFIX=$HOME/.local` installs Ernest for you alone, with no `sudo`, where `~/.local/bin` is on your `PATH`. `make uninstall`, with the same `PREFIX`, removes it. Without installing, the checkout's `bin/ern` runs in place. The Emacs mode is installed with the rest, as `share/emacs/site-lisp/ernest-mode.el`, and [`editors/emacs/README.md`](editors/emacs/README.md) says how to turn it on.

## Reading more

- **[Why Ernest](guide/why.md)** is the argument for the design, and **[the questions](guide/faq.md)** answer what a reader of another BEAM language asks first.
- **[Style](guide/style.md)** is the rules a program is written by: its layout, its names, and the names every program shares.
- **[The deployment guide](guide/deployment.md)**, *Running Ernest*, is for whoever runs nodes: a node's directory and its service manager, its peers, and a running program given new code.
- **[`examples/`](examples/)** holds complete programs, from `hello.ern` to a game at a terminal, [`snake.ern`](examples/snake.ern), and a small web server, [`web_server.ern`](examples/web_server.ern); [`examples/README.md`](examples/README.md) lists them by topic, with what each shows.
- **[The manual pages](docs/man/)**, as Markdown: the prelude's, every standard library module's and every library's, which `man Ernest.List` shows where Ernest is installed.
- **[`ernest-template`](https://github.com/joagre/ernest-template)** is where an application written in Ernest begins: a repository copied with *Use this template*, with one Makefile, the documents and the working rules of this repository cut to an application's size, and `TEMPLATE.md` saying why.
- **[Working on Ernest](docs/development.md)** is for those who work on the language and its toolchain, and says how the repository is laid out: `report/` and `guide/` are the language, `src/` holds the Ernest a release ships and `erl/` the Erlang, `editors/` holds the editor modes, and `docs/` every other document.

## License

Ernest is released under the Zero-Clause BSD license, 0BSD, the terms in [`LICENSE`](LICENSE). Third-party components are listed, with their licenses, in [`THIRD_PARTY_LICENSES`](THIRD_PARTY_LICENSES).
