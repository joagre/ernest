# The installation

How the installation is built, from a checkout and from the release archive; the README and the archive's own README tell a user how to install. The plan's MVP 2.95 decided it, and the log's *`bin/ern` Is a Launcher*, *The Layout Under the Prefix*, *One Archive, Compiled Where It Is Installed* and *The Release Has a README of Its Own* argue it. `installation_test_` and `working_directory_test_` in `test/ern_integration_tests.erl` test it.

## The layout

`make install` copies this tree under `$DESTDIR$PREFIX`. `PREFIX` is `/usr/local` by default; `DESTDIR`, empty by default, is the staging directory a packager passes.

```
bin/ern                          a relative link, ../lib/ernest/bin/ern
lib/ernest/                      the toolchain's tree, as the repository lays it out
    bin/ern                      the launcher
    erl/<app>/ebin/              the toolchain's modules, without its tests
    erl/runtime/priv/ern_exec    the helper Os.run runs a program through, and Fs.removeAll removes a tree
    stdlib/*.ern                 the standard library's source root (report §4.2)
    build/stdlib/                the standard library, compiled
    build/shell/                 the shell, compiled, with libs/markdown and libs/ansi
    build/libs/<name>/           each library, compiled, a root for --load-path
    installed                    every file put outside the tree
share/man/man1/ern.1             §11 of the report
share/man/man3/Ernest.*.3ern     the prelude's page, each module's and each library's (report §11.4)
share/doc/ernest/                the report, the guide, the release's README.md, LICENSE, THIRD_PARTY_LICENSES
share/emacs/site-lisp/ernest-mode.el
```

The tree keeps the repository's layout, `build/` included, because the toolchain finds every file it reads relative to its own modules. The Erlang sources, the tests, the shell's source and the examples are not installed. A program names a library by its place: `--load-path $PREFIX/lib/ernest/build/libs/markdown`. `tools/strip.escript` strips every module of the host's debug information, keeping `ErnI`, the module's interface, and `Docs`, the host's EEP 48 chunk (report §11.1).

The documents installed are for a reader with no checkout. The README is `tools/release/README.md`, the release's: it says how to install from the archive and where to begin, names each thing by its place under the prefix, and holds no link into the checkout. The report and the guide are staged with each link into the checkout, to a file that is not installed, made a link into the repository: on `main` where a checkout is installed, and at the release's tag, `v<version>`, in the archive. So every link of an installed document names a file installed beside it or an address.

`tools/install.sh` stages, installs, uninstalls and writes the archive. `make` builds everything installed, the manual pages included, and `make install` stages the checkout in a temporary directory outside it and installs from there, so that one run as another user writes nothing into the checkout. Nothing installed names the prefix, so a prefix moved whole runs where it is moved to.

## The launcher

`bin/ern` is a POSIX sh script, the same in the repository and in an installation. It follows its own links to the tree it stands in, however many lead to it. Before the host starts, it refuses a working directory whose name `iconv` does not read as UTF-8 (report §11), and a `PATH` without `erl`, and it exits with status 141 where standard output or standard error is closed, since the host would open `/dev/null` in its place (report §11.8). It then starts `erl` with the tree's code paths and:

- `+B`: the interrupt ends it, and opens no break menu (report §8.6);
- `-boot no_dot_erlang`: `~/.erlang` is not read;
- `-noshell -noinput`, in that order, since the host takes the last of the two: the host reads no input, and standard input is the runtime's alone (report §8.2);
- `-run ern_signals install`, first: the host's termination and hangup are `ern`'s before the entry's module is loaded, since until then the host's own handler ends a program with status 0 (report §8.6);
- `-run ern_cli start -extra` and the command line: `ern_cli:start/0` runs the job, and a failure of the toolchain itself exits with status 70 instead of writing a crash dump (report §11).

Before it clears the host's flags, `ERL_AFLAGS`, `ERL_FLAGS`, `ERL_ZFLAGS` and `ERL_LIBS`, it keeps each of them, and `PATH`, `BINDIR`, `EMU`, `PROGNAME` and `ROOTDIR`, which the host's own start sets or changes, as `ERN_GIVEN_<NAME>`, with `ERN_GIVEN` to say so: the runtime's helper puts each back, so that a program's environment is the one `ern` was started in (report Appendix E.23).

It needs `sh`, `readlink` and `iconv`, and checks no version of the host.

## The release archive

`make release` writes `build/release/ern-<version>.tar.gz`: under `ern-<version>/`, the staged tree without the compiled helper, and beside it the helper's source `ern_exec.c`, `install.sh`, the `Makefile` of `tools/release`, and the `README.md` it installs. The archive's `make` compiles the helper with `cc`, or the `CC` given; its `make install` and `make uninstall` take `PREFIX` and `DESTDIR` as the checkout's do.

## Removing it

The tree's `installed` lists every file put outside it, one a line, relative to the prefix, and each directory of the installation's own with a slash after it, `share/doc/ernest/`. `make uninstall` removes the files, then those directories where they are empty, then the tree; a file of the user's in `share/man/man3` stays, and so does every directory the prefix shares. `make install` first removes an installation already in the prefix the same way.

Neither target changes anything where it cannot write. Each first checks every directory it must write, or, for one not there yet, the nearest one above it that is, and stops with that directory's name and the two ways out: to run as a user who can write there, or to give another `PREFIX`. `make install` refuses a `lib/ernest` or a `bin/ern` that is not an installation of Ernest, and `make uninstall` a prefix that holds none.
