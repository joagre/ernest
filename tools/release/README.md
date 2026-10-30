<picture>
  <source media="(prefers-color-scheme: dark)"
          srcset="assets/ernest-combined-dark.svg">
  <source media="(prefers-color-scheme: light)"
          srcset="assets/ernest-combined-light.svg">
  <img src="assets/ernest-combined-light.svg" alt="Ernest" width="520">
</picture>

# Ernest @VERSION@

Ernest is a small functional language for concurrent programs, on the Erlang runtime. This is the README of a release: the archive `ern-@VERSION@.tar.gz` holds it, and an installation holds it as `share/doc/ernest/README.md`. Until 1.0 a release may refuse a program the previous release accepted; this release's notes, on the [releases page](https://github.com/joagre/ernest/releases), say where to read what changed.

## Installing

From the archive, on Linux; macOS is expected to work the same way, and is not yet verified. It needs Erlang/OTP 29 on your `PATH`, make, and a C compiler, for the one part of Ernest in C, the helper that runs another program for `Os.run`:

```
make
sudo make install                  # into /usr/local
ern --version
man ern
```

`make install PREFIX=$HOME/.local` installs Ernest for you alone, with no `sudo`, where `~/.local/bin` is on your `PATH`. `make uninstall`, with the same `PREFIX`, removes it. The installation can be moved to another directory whole, and runs there.

## Where to begin

Each path below is under the prefix, `/usr/local` unless another was given, and under the archive's own directory before it is installed.

- `ern shell` starts the shell, and `:quit` leaves it.

Three ways in, each for a reader:

- `share/doc/ernest/tour/README.md` is the tour, for the programmer who wants the whole picture in an evening: one program, a counter, grown through eight chapters, each chapter's program under `tour/1/` to `tour/8/` beside it.
- `share/doc/ernest/guide/language.md` is the guide, *Programming in Ernest*, for the programmer learning the language: every rule taught where a program first needs it, and `guide/README.md` beside it says what else stands there.
- `share/doc/ernest/report/` holds the report, for whoever builds or checks a toolchain or writes a library against the exact rules: the language's definition, which everything else defers to, in three files, `language.md`, `toolchain.md` and `library.md`.

Beside them:

- `share/doc/ernest/guide/why.md` is the argument for the design, and `share/doc/ernest/guide/faq.md` answers the questions a reader of another language on the runtime asks first.
- `share/doc/ernest/guide/deployment.md` is *Running Ernest*, the operator's guide to nodes, their configuration and a program's upgrade.
- `share/doc/ernest/guide/style.md` is what a program written in Ernest looks like: what `ern format` writes, what the report asks of a library's names, and the names the standard library uses.
- `share/doc/ernest/examples/` holds the programs the guide runs, and its `README.md` lists them by topic.
- `man ern` is the toolchain's page and `man Ernest.List` a module's; the prelude, every module of the standard library and every library has one.
- `share/emacs/site-lisp/ernest-mode.el` is the Emacs mode, and `share/doc/ernest/editors/emacs/README.md` says how to turn it on.
- `share/doc/ernest/CHANGES.md` is what changed in each release, newest first, a line each naming where it is read.

The repository, https://github.com/joagre/ernest, holds what an installation does not: the source of the toolchain and of the standard library, and the project's own documents.

## License

Ernest is released under the Zero-Clause BSD license, 0BSD, the terms in `share/doc/ernest/LICENSE`. Third-party components are listed, with their licenses, in `share/doc/ernest/THIRD_PARTY_LICENSES`.
