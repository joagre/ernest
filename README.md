<picture>
  <source media="(prefers-color-scheme: dark)"
          srcset="assets/ernest-combined-dark.svg">
  <source media="(prefers-color-scheme: light)"
          srcset="assets/ernest-combined-light.svg">
  <img src="assets/ernest-combined-light.svg" alt="Ernest" width="256">
</picture>

# Ernest

*The Importance of Being Ernest, a Trivial Comedy for Serious People*

The home of Ernest is [ernest-lang.org](https://ernest-lang.org).

Ernest is a small BEAM language built around code that travels. It takes Unison's code known by the hash of its definition, Gleam's kind of types and Erlang's processes, and adds what none of them has. A process started on another node brings its code along, each function crossing by its hash, and nothing is installed there first. A process's mailbox type is part of its function's type, so the compiler checks every send against the mailbox it reaches. And two nodes are two configuration files over one TLS connection, with no cluster to join.

A counter, whose mailbox type, `CounterMsg`, is in the type of the loop it runs:

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

On a second node, `foo`, which holds none of the counter's code, `Peer.spawn` starts `count`, and the shell counts on it from here. Two configuration directories make the pair, four `ern config` commands of the kind [the tour](tour/README.md) shows:

```console
$ ern shell --config-dir a
Ernest 0.10.0, session 1. :help for help.
> :load Counter
Counter, compiled from counter.ern
> let far <- Peer.spawn("foo", fn() = Counter.count(0), 5000)
the peer foo connected
far : Address(Counter.CounterMsg)
> send(far, Counter.Inc(5))
> Address.call(far, Counter.Get, 1000)
Some(5) : Optional(Int)
```

`foo` compiled `count` and its type before the process started.

A function that receives runs only in a process whose mailbox takes what it receives, so `count` called from a `main` with another mailbox is refused before the program runs. A Gleam `Subject` lets this through: `process.receive(subject, 1000)` compiles wherever a subject is in hand, and panics at run time in a process that does not own it.

```console
$ ern build other.ern
other.ern:6:5: count needs mailbox CounterMsg, and the mailbox here is OtherMsg
4 |
5 | export fn main() : Unit receiving OtherMsg =
  |                                   -------- main is declared `receiving OtherMsg` here
6 |     count(0)
  |     ^^^^^^^^
```

What Ernest adds, which [Why Ernest](guide/why.md) argues:

- [Code travels](guide/why.md#code-travels)
- [The mailbox in the function's type](guide/why.md#the-mailbox-in-the-functions-type)
- [A distribution built for a WAN](guide/why.md#a-distribution-built-for-a-wan)
- [A deadlock is found](guide/why.md#a-deadlock-is-found)
- [Abstract types and requirements](guide/why.md#abstract-types-and-requirements)
- [Little else](guide/why.md#little-else)

The questions a Gleam or Erlang programmer asks first are [answered here](guide/faq.md).

## Where to begin

- **[The tour](tour/README.md)**: one program grown through eight chapters, in an evening.
- **[The guide](guide/language.md)**, *Programming in Ernest*: the language, a rule where a program first needs it.
- **[The report](report/README.md)**: the definition, which everything else defers to.
- **[`examples/`](examples/)**: complete programs, from `hello.ern` to a game at a terminal.
- **[`ernest-template`](https://github.com/joagre/ernest-template)**: where an application in Ernest begins.
- **[The projects](site/projects.md)**: libraries and programs written in Ernest, each in a repository of its own.

[`guide/README.md`](guide/README.md) lists the other guides: style, and running nodes.

## Where it stands

Young: the [releases page](https://github.com/joagre/ernest/releases) names the latest, and until 1.0 a release may refuse a program the previous one accepted.

## Installing

On Linux, with Erlang/OTP 29 on your `PATH`, GNU make and a C compiler. On Debian and Ubuntu the last two are the packages `make` and `gcc`, and OTP 29 is installed as below, since their own `erlang` package is older. Ernest is tested on Linux; on macOS the same steps are expected to work:

```
git clone https://github.com/joagre/ernest.git
cd ernest
make
sudo make install           # into /usr/local
ern build examples/hello.ern
ern run examples/hello.erc  # hello, world
ern shell                   # :quit to leave
man ern                     # the toolchain
man Ernest.List             # a module
```

OTP 29 is built from its source at [erlang.org/downloads](https://www.erlang.org/downloads), or installed by a version manager such as kerl, where a distribution's own packages hold an older release.

Or from a release: download `ern-<version>.tar.gz` and its checksum, `ern-<version>.tar.gz.sha256`, from the [releases page](https://github.com/joagre/ernest/releases), check the archive with `sha256sum -c ern-<version>.tar.gz.sha256`, and in the directory it unpacks to run `make` and `sudo make install`, as its own README says; the archive holds the source, which `make` compiles, with OTP 29 as above.

Two nodes on one machine take four more commands: `ern config --config-dir` makes each node's directory with its key, `ern config --peer-dir` lists one node in the other's file, `ern run --config-dir` starts a node, and `ern stop --config-dir` ends it; [the deployment guide](guide/deployment.md) walks through them.

`make install PREFIX=$HOME/.local` installs Ernest for you alone, with no `sudo`, where `~/.local/bin` is on your `PATH`. `make uninstall`, with the same `PREFIX`, removes it. Without installing, the checkout's `bin/ern` runs in place. The Emacs mode is installed with the rest, as `share/emacs/site-lisp/ernest-mode.el`, and [`editors/emacs/README.md`](editors/emacs/README.md) says how to turn it on.

## License

Ernest is released under the Zero-Clause BSD license, 0BSD, the terms in [`LICENSE`](LICENSE). Third-party components are listed, with their licenses, in [`THIRD_PARTY_LICENSES`](THIRD_PARTY_LICENSES).
