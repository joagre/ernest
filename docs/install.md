# Installing Ernest

The design of Ernest's installation: what `make install` puts where, how the installed tree finds itself, and how it is staged for a package. This note owns that design; the plan's MVP 2.95 says when it is built, and the README how to build from the repository. Nothing here is built yet, and until it is, the toolchain runs from the repository as `bin/ern`.

## The two variables

There is no configure step. The installation takes two make variables, as projects without one do:

- **`PREFIX`**, where Ernest is installed, `/usr/local` by default: `make install PREFIX=/opt/ernest`.
- **`DESTDIR`**, prepended to every path the installation writes, empty by default, so that a packager stages the tree in a directory of its own and moves it into place later: `make install DESTDIR=/tmp/stage PREFIX=/usr`.

`make uninstall`, with the same two variables, removes what `make install` put there and nothing else.

## The layout

Under the prefix:

```
PREFIX/bin/ern                        a relative symbolic link to ../lib/ernest/bin/ern
PREFIX/lib/ernest/bin/ern             the escript
PREFIX/lib/ernest/VERSION             the version
PREFIX/lib/ernest/erl/<app>/ebin/     the toolchain's compiled applications
PREFIX/lib/ernest/build/stdlib/       the standard library, compiled
PREFIX/lib/ernest/build/shell/        the shell, compiled
PREFIX/lib/ernest/build/libs/<name>/  the libraries under libs/, compiled
PREFIX/share/man/man3/                the manual pages of the modules
PREFIX/share/man/man1/                `ern`'s own page, should MVP 2.95 give it one
```

The tree under `lib/ernest` is the repository's own layout for what runs, so `bin/ern` finds everything as it does in the repository. The manual pages are in `share/man`, where the file system hierarchy puts them and where `man` looks by default. What the pages are named is decided with MVP 2.95's manual pages.

## Relocation

Nothing is written into the installed files: no path is compiled in and no file is edited at install time. `bin/ern` finds the toolchain relative to its own path, as it does in the repository, and the installed escript first follows the symbolic link it was started through. So a prefix moved or copied whole still runs, and so does a tree staged with `DESTDIR` and moved into place.

## What it needs

Erlang/OTP 29, with `escript` on the path. The installation does not carry its own runtime; a release that does is a later decision.
