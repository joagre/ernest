# Ernest @VERSION@

Ernest is a small functional language for concurrent programs, on the Erlang runtime. This is the README of a release: the archive `ern-@VERSION@.tar.gz` holds it, and an installation holds it as `share/doc/ernest/README.md`.

## Installing

From the archive, on Linux; macOS is expected to work the same way, and is not yet verified. It needs Erlang/OTP 29 on your `PATH`, make, and a C compiler, for the one part of Ernest in C, the helper that runs another program for `Os.run` and removes a tree for `Fs.removeAll`:

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
- `share/doc/ernest/ernest_guide.md` is the guide, *Programming in Ernest*, which teaches the language to a programmer who knows another. Start there.
- `man ern` is the toolchain's page and `man Ernest.List` a module's; the prelude, every module of the standard library and every library has one.
- `share/doc/ernest/report/` holds the report, the language's definition, which everything else defers to, in three files: `language.md`, `toolchain.md` and `library.md`.
- `share/emacs/site-lisp/ernest-mode.el` is the Emacs mode.

The repository, https://github.com/joagre/ernest, holds what an installation does not: the examples and the documents the guide links to, the toolchain's source, and `emacs/README.md`, which says how to turn the Emacs mode on.

## License

Ernest is released under the terms in `share/doc/ernest/LICENSE`. Third-party components are listed, with their licenses, in `share/doc/ernest/THIRD_PARTY_LICENSES`.
