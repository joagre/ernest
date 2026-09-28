# The installation

How Ernest is installed, moved, and removed, from a checkout and from the release archive. The README says how a user installs it from a checkout, and the archive's own README how from the archive; this note says how both are built. The decisions behind it are the plan's MVP 2.95, items 2 and 3, and the log's *`bin/ern` Is a Launcher*, *The Layout Under the Prefix* and *One Archive, Compiled Where It Is Installed*.

## The layout

An installation is a staged tree copied under a prefix, and every path after a staging directory where one is given. The tree, as it is staged and as it is installed:

```
bin/ern                          a relative link, ../lib/ernest/bin/ern
lib/ernest/                      the toolchain's tree, as the repository lays it out
    bin/ern                      the launcher
    erl/<app>/ebin/              the toolchain's modules, its tests left out
    erl/runtime/priv/ern_exec    the helper Os.run runs a program through
    stdlib/*.ern                 the standard library's source, its source root (report §4.2)
    build/stdlib/                the standard library, compiled
    build/shell/                 the shell, compiled, libs/markdown with it
    build/libs/<name>/           each library, compiled, a root for --load-path
    installed                    every file put outside the tree
share/man/man1/ern.1             §11 of the report (report §11)
share/man/man3/Ernest.*.3ern     the prelude's page, each module's, and each library's (report §11.4)
share/doc/ernest/                the report, the guide, README.md, LICENSE, THIRD_PARTY_LICENSES
share/emacs/site-lisp/ernest-mode.el
```

Every module in the tree is stripped of the host's debug information, by `tools/strip.escript`, which keeps the two chunks of Ernest's own, `ErnI` and `Docs`; nothing at run time reads what goes, and the host's development tools that do run in the checkout. The tree keeps the repository's layout, `build/` included, because the toolchain finds every file it reads relative to its own modules: the helper beside the runtime's, the standard library's source root three directories above `ern_cli`'s, and the compiled standard library and shell by their directories on the code path. The Erlang sources, the tests, the shell's source and the examples are not installed. A program that uses a library names it by its place, `--load-path $PREFIX/lib/ernest/build/libs/markdown`.

`tools/install.sh` has four jobs. `stage` writes the tree above from the checkout into a directory; `install` copies a staged tree under the prefix; `uninstall` removes an installation; and `release` writes the archive. `make` writes the manual pages, and `make install` stages the checkout in a directory of its own outside it, installs what it staged, and removes the stage, so that an installation run as another user writes nothing into the checkout. The prefix is `PREFIX`, `/usr/local` by default, and the staging directory `DESTDIR`, empty by default, which a packager passes. Nothing in the installation names either: the prefix can be moved whole, and runs where it is moved to.

## The launcher

`bin/ern` is a POSIX sh script, the same in the repository and in an installation. It follows its own links, a `readlink` loop, to the tree it stands in, so the link in the prefix's `bin/` and any link to that link find it. It refuses a working directory whose name `iconv` does not read as UTF-8, before the host starts, with the refusal of report §11. It then starts `erl` from the `PATH` with the tree's code paths:

- `+B`, so that the host's interrupt ends it rather than opening its break menu (report §8.6);
- `-boot no_dot_erlang`, so that a user's `~/.erlang` is not read;
- `-noshell -noinput`, in that order, since the host takes the last of the two, so that it reads no input and standard input is the runtime's alone (report §8.2);
- `-run ern_cli start -extra` and the command line, which `ern_cli:start/0` hands to `ern_cli:main/1`, and a failure of the toolchain itself ends with status 70 rather than a crash dump in the working directory (report §11).

It needs `erl` of Erlang/OTP 29, `sh`, `readlink`, and `iconv`, which Linux and macOS have. It checks no version of the host.

## The release archive

`make release` writes `build/release/ern-VERSION.tar.gz`, a staged tree under the directory `ern-VERSION`, with the helper left out and its C source, `ern_exec.c`, beside the tree, and with `install.sh` and the `Makefile` and `README.md` of `tools/release`. The archive's `make` compiles the helper for the machine it is on, with `cc` or the `CC` given, since the helper is the one part of Ernest that is not the host's bytecode; its `make install` and `make uninstall` are the checkout's, taking `PREFIX` and `DESTDIR`, and install the tree it holds. So one archive serves every system OTP 29 runs on, and needs a C compiler beside OTP and make.

## Removing it

`make install` writes `lib/ernest/installed`: every file it put outside the tree, a line each, relative to the prefix, and each directory of its own with a slash after it, `share/doc/ernest/`. `make uninstall` removes those files, then those directories where they are empty, then the tree, so that a file of the user's in `share/man/man3` stays, and so does every directory the prefix shares. An installation already in the prefix is removed the same way before `make install` puts the new one there.

Neither changes anything where it cannot finish. Before it writes or removes, each checks that every directory it must write can be written, or, where the directory is not there yet, the nearest one above it that is, and stops with the directory's name and the two ways out: to run as a user who can write there, or to give another `PREFIX`. `make install` refuses a `lib/ernest` or a `bin/ern` that is not an installation of Ernest, and `make uninstall` a prefix that holds none.

## The tests

`release_test_` makes the archive, checks that it holds the C source and no compiled helper, unpacks it, installs it under a prefix with its own `make install`, which compiles the helper, runs a program that runs another through the helper, and uninstalls. Both tests check that no installed module carries the host's debug information.


`test/ern_integration_tests.erl`'s `install_test_` installs into a scratch prefix, checks the link, moves the prefix, and from the new place runs `ern --version`, builds and runs a program that runs another through the helper, runs the shell, writes a manual page, and has `man` find `ern(1)`, a module's page and a library's through the `PATH` alone. It uninstalls with a page of its own in `man3`, which stays, and a second uninstall is refused. It installs under a `DESTDIR` and runs there, and a prefix that cannot be written is refused with nothing written. `working_directory_test_` has the launcher refuse a directory whose name is not UTF-8 under a UTF-8 locale and under `C`.
