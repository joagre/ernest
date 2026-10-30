# The installation

Status: the installation's design note, which changes when the installation does. It is not a proposal, and not authoritative.

How the installation is built, from a checkout and from the release archive; the README and the archive's own README tell a user how to install. The plan's MVP 2.95 decided it, and the log's *`bin/ern` Is a Launcher*, *The Layout Under the Prefix*, *One Archive, Compiled Where It Is Installed*, *The Release Has a README of Its Own* and *The Layout Completed* argue it. `installation_test_` in `test/ern_install_tests.erl` and `working_directory_test_` in `test/ern_integration_tests.erl` test it.

## The layout

`make install` copies this tree under `$DESTDIR$PREFIX`. `PREFIX` is `/usr/local` by default; `DESTDIR`, empty by default, is the staging directory a packager passes.

```
bin/ern                          a relative link, ../lib/ernest/bin/ern
lib/ernest/                      the toolchain's tree, as the repository lays it out
    bin/ern                      the launcher
    erl/<app>/ebin/              the toolchain's modules, without its tests
    erl/runtime/priv/ern_exec    the helper Os.run runs a program through
    build/stdlib/                the standard library, compiled, one .erc for each module
    build/shell/                 the shell, compiled
    build/libs/<name>/           each library, compiled, a root of every load path
    installed                    every file put outside the tree
share/man/man1/ern.1             §11 of the report
share/man/man3/Ernest.*.3ern     the prelude's page, each module's and each library's (report §11.4)
share/doc/ernest/                the tracked files of report/, guide/, tour/ and examples/, and
                                 editors/emacs/README.md, each where it stands, the release's
                                 README.md, the logo they show under assets/, LICENSE,
                                 THIRD_PARTY_LICENSES, ACKNOWLEDGMENTS.md, CHANGES.md
share/emacs/site-lisp/ernest-mode.el
```

The tree keeps the repository's layout, `build/` included, because the toolchain finds every file it reads relative to its own modules. The Erlang sources, the Ernest sources, the standard library's among them, and the tests are not installed, but for the examples, which go in with the documents. A program names no library by its place: `ern_tree:libraries/0` lists `build/libs` under the tree, the installation's as the checkout's, and each library's build ends every job's load path (report §11.1, §11.2). `tools/strip.escript` strips every module of the host's debug information, keeping `ErnI`, the module's interface, and `Docs`, the host's EEP 48 chunk (report §11.1).

The documents installed are for a reader with no checkout. A file is installed by the path it stands in: every file the repository tracks under `report/`, `guide/`, `tour/` and `examples/`, and `editors/emacs/README.md`, is for a user of Ernest, and goes in where it stands, a path the repository does not hold passed over. The examples are the programs the guide runs, and the Emacs README the note that turns on the mode installed with them. `tools/install.sh` asks `git` for the files the repository tracks, so a file of the checkout's that it does not track, a draft or an editor's, stays out; `docs/`, the proposals among it, and `CLAUDE.md` are the project's, and stay out too.

The README is `tools/release/README.md`, the release's: it says how to install from the archive and where to begin, names each thing by its place under the prefix, and holds no link into the checkout.

Each `.md` of those paths is staged with each link into the checkout, to a file that is not installed, made a link into the repository: on `main` where a checkout is installed, and at the release's tag, `v<version>`, in the archive. A link to one of the paths installed, or to the logo under `assets/`, stays a link to the installed copy, as the guide's links to the examples and to the Emacs README do; the guide's other links outside them, to the log and to `docs/module_doc_template.md`, go to the repository. Every other file is copied as it is. So every link of an installed document names what is installed beside it, or an address.

`tools/install.sh` stages, installs, uninstalls and writes the archive. `make` builds everything installed, the manual pages included, and `make install` stages the checkout in a temporary directory outside it and installs from there, so that one run as another user writes nothing into the checkout. Nothing installed names the prefix, so a prefix moved whole runs where it is moved to.

## The launcher

`bin/ern` is a POSIX sh script, the same in the repository and in an installation. It follows its own links to the tree it stands in, however many lead to it. Before the host starts, it refuses a `PATH` without `iconv` and a working directory whose name `iconv` does not read as UTF-8 (report §11), but for `ern --help` and `ern --version`, which start the host in the root directory, and a `PATH` without `erl`, and it exits with status 141 where standard output or standard error is closed, since the host would open `/dev/null` in its place (report §11.8). It then starts `erl` with the tree's applications, `erl/*/ebin`, on its code path, which holds no compiled Ernest module, since `ern` loads each from its `.erc` at its first call, and:

- `+B`: the interrupt ends it, and opens no break menu (report §8.6);
- `-boot no_dot_erlang`: `~/.erlang` is not read;
- `-noshell -noinput`, in that order, since the host takes the last of the two: the host reads no input, and standard input is the runtime's alone (report §12.1);
- `-run ern_signals install`, first: the host's termination and hangup are `ern`'s before the entry's module is loaded, since until then the host's own handler ends a program with status 0 (report §12.4);
- `-run ern_cli start -extra` and the command line: `ern_cli:start/0` runs the job, and a failure of the toolchain itself exits with status 70 instead of writing a crash dump (report §11).

Before it clears the host's flags, `ERL_AFLAGS`, `ERL_FLAGS`, `ERL_ZFLAGS` and `ERL_LIBS`, it keeps each of them, and `PATH`, `BINDIR`, `EMU`, `PROGNAME` and `ROOTDIR`, which the host's own start sets or changes, as `ERN_GIVEN_<NAME>`, with `ERN_GIVEN` to say so: the runtime's helper puts each back, so that a program's environment is the one `ern` was started in (report Appendix E.23).

It needs `sh`, `readlink` and `iconv`.

## The release archive

`make release` writes `build/release/ern-<version>.tar.gz`: under `ern-<version>/`, the staged tree without the compiled helper, and beside it the helper's source `ern_exec.c`, `install.sh`, the `Makefile` of `tools/release`, the `README.md` it installs, and the logo that README shows, under `assets/`. The archive's `make` compiles the helper with `cc`, or the `CC` given; its `make install` and `make uninstall` take `PREFIX` and `DESTDIR` as the checkout's do.

## Removing it

The tree's `installed` lists every file put outside it, one a line, relative to the prefix, and each directory of the installation's own with a slash after it, `share/doc/ernest/` and each beneath it, each listed before the one that holds it. `make uninstall` removes the files, then those directories, in that order, where they are empty, then the tree; a file of the user's in `share/man/man3` stays, and so does every directory the prefix shares. `make install` first removes an installation already in the prefix the same way.

Neither target changes anything where it cannot write. Each first checks every directory it must write, or, for one not there yet, the nearest one above it that is, and stops with that directory's name and the two ways out: to run as a user who can write there, or to give another `PREFIX`. `make install` refuses a `lib/ernest` or a `bin/ern` that is not an installation of Ernest, and `make uninstall` a prefix that holds none.
