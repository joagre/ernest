<picture>
  <source media="(prefers-color-scheme: dark)"
          srcset="assets/ernest-combined-dark.svg">
  <source media="(prefers-color-scheme: light)"
          srcset="assets/ernest-combined-light.svg">
  <img src="assets/ernest-combined-light.svg" alt="Ernest" width="256">
</picture>

# Ernest

*The Importance of Being Ernest, a Trivial Comedy for Serious People*

[Ernest](https://ernest-lang.org) is a small BEAM language built around code that travels. It exists for two things Erlang does not quite give:

- A process started on another node brings its code along, even where that node has none of the program installed. Code is known by its hash, much as in [Unison](https://www.unison-lang.org/).
- A module is not held to two versions: a new one loads without disturbing the processes that run older ones, where Erlang kills those still running the oldest. The price is that every version is kept for the node's life.

Mailboxes have types as well. A process's mailbox type is part of its function's type, so the compiler checks every send against the mailbox it reaches. The types are Hindley-Milner, as in ML.

A counter, whose loop names its mailbox type, `CounterMsg`:

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

And a shell talking to a bare node `foo`, which holds only Ernest's standard library:

```console
$ ern shell --config-dir a
Ernest 0.11.0, session 1. :help for help.
> :load Counter
Counter, compiled from counter.ern
> let far <- Peer.spawn("foo", fn() = Counter.count(0), 5000)
the peer foo connected
far : Address(Counter.CounterMsg)
> send(far, Counter.Inc(5))
> Address.call(far, Counter.Get, 1000)
Some(5) : Optional(Int)
```

`foo` compiled `count` and its type before the process started. Each input runs in a process of its own, so the `Get` may reach `foo` before the `Inc` and answer `Some(0)`. The two nodes are two configuration directories, `a` and `foo`. Each names the other's public key. They share one TLS connection: no cookie, no epmd, no mesh.

You can run this in your browser. The front page of [ernest-lang.org](https://ernest-lang.org) has the same counter with a Try it button, and each visitor gets a shell and a bare `foo` of their own. The site and its shell are served by [a web server written in Ernest](https://github.com/joagre/ernest-httpd).

The compiler checks more than sends. `count` receives from the mailbox of the process that runs it, so a call from a `main` with another mailbox is refused before the program runs. A Gleam `Subject` lets this through: `process.receive(subject, 1000)` compiles wherever a subject is in hand, and panics at run time in a process given a subject it did not make, unless the subject is a named one.

```console
$ ern build other.ern
other.ern:6:5: count needs mailbox CounterMsg, and the mailbox here is OtherMsg
4 |
5 | export fn main() : Unit receiving OtherMsg =
  |                                   -------- main is declared `receiving OtherMsg` here
6 |     count(0)
  |     ^^^^^^^^
```

[The tour](tour/README.md) ends by moving this running counter to new code on the remote node, its state intact.

What Ernest adds, which [Why Ernest](guide/why.md) argues:

- [Code travels](guide/why.md#code-travels)
- [The mailbox in the function's type](guide/why.md#the-mailbox-in-the-functions-type)
- [A distribution built for a WAN](guide/why.md#a-distribution-built-for-a-wan)
- [A deadlock of the whole program is found](guide/why.md#a-deadlock-of-the-whole-program-is-found)
- [Abstract types and requirements](guide/why.md#abstract-types-and-requirements)

Ernest runs on the BEAM without OTP's behaviors: a server is a `receive` loop, a supervision tree is the library's `Supervisor`, and a process's end arrives as a message from a monitor. [The questions](guide/faq.md) say what stands in their place, and how Ernest differs from Gleam and Unison.

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

On Linux, with Erlang/OTP 29 on your `PATH`, GNU make and a C compiler. On Debian and Ubuntu the last two are the packages `make` and `gcc`, and OTP 29 is installed as below, since their own `erlang` package is older. On Linux a node needs 5.3 or later. Ernest is tested on Linux; on macOS the same steps are expected to work:

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

OTP 29 is built from its source at [erlang.org/downloads](https://www.erlang.org/downloads), or installed by a version manager such as kerl, where a distribution's own packages hold an older release. `erl -noshell -eval 'io:format("~s~n", [erlang:system_info(otp_release)]), halt().'` prints the release of the OTP on `PATH`. To try Ernest before installing anything, the front page of [ernest-lang.org](https://ernest-lang.org) runs a shell in the browser.

Or from a release: download `ern-<version>.tar.gz` and its checksum, `ern-<version>.tar.gz.sha256`, from the [releases page](https://github.com/joagre/ernest/releases), check the archive with `sha256sum -c ern-<version>.tar.gz.sha256`, and in the directory it unpacks to run `make` and `sudo make install`, as its own README says; the archive holds the source, which `make` compiles, with OTP 29 as above.

Two nodes on one machine take four more commands, each run once for each node: `ern config --config-dir` makes the node's directory with its key, `ern config --peer-dir` lists the other node in its file, `ern run --config-dir` starts the node, and `ern stop --config-dir` ends it; [the deployment guide](guide/deployment.md) walks through them.

`make install PREFIX=$HOME/.local` installs Ernest for you alone, with no `sudo`, where `~/.local/bin` is on your `PATH`. `make uninstall`, with the same `PREFIX`, removes it. Without installing, the checkout's `bin/ern` runs in place. The Emacs mode is installed with the rest, as `share/emacs/site-lisp/ernest-mode.el`, and [`editors/emacs/README.md`](editors/emacs/README.md) says how to turn it on. There is no language server, so another editor has no mode of Ernest's.

## License

Ernest is released under the Zero-Clause BSD license, 0BSD, the terms in [`LICENSE`](LICENSE). Third-party components are listed, with their licenses, in [`THIRD_PARTY_LICENSES`](THIRD_PARTY_LICENSES).
