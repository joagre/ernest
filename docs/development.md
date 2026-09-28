# Working on Ernest

For those who work on the language and its toolchain: where things are, how to build and test them, and what the toolchain does not do yet. A reader who wants to learn Ernest starts with the [guide](../ernest_guide.md) instead.

The report, [`ernest_report.md`](../ernest_report.md), is the one normative document; everything else defers to it. How work proceeds, and which document owns which fact, is in [`CLAUDE.md`](../CLAUDE.md).

## The documents

- **[`implementation_plan.md`](implementation_plan.md)**: where the project stands, what is done, and what comes next.
- **[`decisions.md`](decisions.md)**: dated design decisions and their rationale, what was tried and rejected. Not normative.
- **[`architecture.md`](architecture.md)**: how the toolchain is built, from the lexer to the runtime, and what each test runs.
- **[`coherence.md`](coherence.md)**: the checks that the project agrees with itself, and when each runs.
- **[`memory.md`](memory.md)**: how the project checks that nothing grows with the work done.
- **[`review.md`](review.md)**: what a release adds to those checks.
- **[`testing_improvements.md`](testing_improvements.md)**: where the time of `make test` goes, and what would shorten it, until the plan decides it.
- **[`style.md`](style.md)**: the style of the Erlang, the C and the Ernest.
- **[`module_doc_template.md`](module_doc_template.md)**: a documented module, as `ern doc` renders it.
- **[`language_feedback.md`](language_feedback.md)**: what writing Ernest has felt against the principles, until the plan decides it.
- **[`shell_design.md`](shell_design.md)**, **[`node_protocol.md`](node_protocol.md)**, **[`code_distribution.md`](code_distribution.md)**: the design notes of the shell, of the protocol between nodes, and of code distribution.
- **[`emacs_mode.md`](emacs_mode.md)**: the Emacs major mode.
- **[`shell/README.md`](../shell/README.md)**: a guide to the shell's code.

What the language requires is the report's §9, the prelude; the standard library is its Appendix E, and what enters it is Appendix E.0's rules. A library under `libs/` is added to a program's load path when it is wanted; Appendix G lists them, and which libraries are first-party is the plan's MVP 3.2.

## The layout of the repository

```
VERSION            the toolchain's version, read at build time
ernest_report.md   the language report (normative)
ernest_guide.md    the guide
docs/              the documents listed above, and this one
examples/          Ernest programs: the paper programs and the small ones
erl/               the toolchain, as Erlang applications: lexer, parser,
                   format, typer, runtime, emitter, cli, utils (vendored getopt);
                   each has src/, include/, ebin/, test/; the runtime also
                   c_src/, ern_exec's C source, and priv/, where make builds it
test/              what spans applications: the hand-written target modules,
                   the integration tests, the guide's examples, the shell's
                   sessions, the pseudo-terminal harness, the loads' harness,
                   expected/, golden/, input/, load/, session/, stdin/, terminal/
bin/               ern, as an escript source
stdlib/            the standard library as Ernest source
shell/             the shell as Ernest source; its README.md guides a reader
                   through the code
emacs/             ernest-mode.el, the Emacs major mode, and its tests under test/
build/             build products, not in git: build/stdlib/, build/shell/, and
                   build/libs/ from make, the standard library's pages from make doc,
                   its manual pages, build/man/ and build/tools/ from make man
libs/              the first-party libraries, each a source root a program adds
                   with --load-path: ets, markdown
tools/             the programs of the build: unicode_width.escript writes
                   Terminal.columns' table, run by make unicode, and manual.ern
                   writes ern(1) from the report's §11, run by make man
```

A module's path follows report §11.1. A file that is not a module is named with underscores, but for the Emacs mode's, which follow Emacs's convention.

## Building

Beside what the README's *Trying it* needs, `make test` needs python3, for the pseudo-terminal the terminal tests run a program under, since Erlang cannot open one. Emacs is optional: without it the mode's tests are skipped and the rest runs. So are groff and mandoc: the manual pages are rendered by whichever is installed, and by neither where neither is. The toolchain's Erlang uses no rebar3 and no OTP behaviours, by design ([`style.md`](style.md)).

```
make              compile every application into its ebin/, then stdlib/, libs/, shell/
make test         build, then run every area below
make test-erl     the unit tests of every application under erl/, side by side;
                  APP=typer for one
make test-programs  the example programs, compiled and run
make test-docs    the citations and the style
make test-guide   the guide's examples
make test-shell   the shell's sessions and the terminal
make test-emacs   the Emacs mode's tests (docs/emacs_mode.md)
make load         the loads of docs/memory.md, which a release runs; not part of make test
make doc          write the standard library's and the prelude's pages to build/stdlib/,
                  with index.md
make man          write their manual pages beside them, Ernest.List.3ern, and ern(1)
                  to build/man/; man -l build/man/ern.1 shows one
make sections     list the report sections no test cites
make xref         check that every section citation and document path in the documents resolves
make coverage     every section with how many tests cite it and its length, thinnest first
make golden       rewrite test/golden/, the Erlang the compiler emits per example
make contents     rewrite the contents lists of the report and the guide from their headings
make format       lay out every Ernest module, and the Ernest blocks of the report and the
                  guide, as ern format does (report §11.6)
make unicode UC_SPEC=dir
                  write Terminal.columns' table from Unicode's data in dir, OTP's
                  lib/stdlib/uc_spec of the host's version
make clean        remove build products
make clean-emacs  remove Emacs backup, auto-save, and lock files
```

Which programs the tests compile and run is [`architecture.md`](architecture.md)'s *Tests*.

## Using

`bin/ern` is the toolchain, its first word the job, with long options only (report §11). Where the guide writes `ern`, this repository's `bin/` is on the `PATH`.

```
bin/ern build examples/hello.ern                  # writes examples/hello.erc
bin/ern run examples/hello.erc                    # hello, world
bin/ern build --build-root build/modules examples/modules  # a source tree, in dependency order
bin/ern run build/modules/main.erc                # loads net/http.erc by namespace
bin/ern build --emit-erl examples/hello.ern       # the Erlang source, for reading
bin/ern doc stdlib/list.ern                       # the module's documentation as CommonMark
bin/ern build --short-errors examples/hello.ern   # the first line of each error only
bin/ern config                                    # ./.ernest with a key pair
bin/ern shell                                     # a shell over the standard library
bin/ern shell build/modules/main.erc              # a shell beside a running program
bin/ern test build/shell/shell/editor.erc         # the module's tests
```

A program whose source tree `app` uses a library adds the library's build to its load path, both to build and to run:

```
bin/ern build --load-path build/libs/ets --build-root build/app app
bin/ern run --load-path build/libs/ets build/app/main.erc
```

The shell's `:help` lists its commands; guide §9.3 teaches the shell, report §11.2 defines it, and [`shell_design.md`](shell_design.md) says how it is built.

## What the toolchain accepts

The toolchain is the report on one node; the plan's milestones lift the table row by row. Everything the report describes type-checks, and what the table leaves out compiles and runs. The table is what the toolchain refuses or does not yet do, each with the milestone that lifts it in the [plan](implementation_plan.md).

| Construct | Until | What you see today |
|---|---|---|
| `spawn(Peer(...))`, `spawnMonitored(Peer(...))`, peers, `ernest.conf` (§6.2, §8.3) | MVP 3.0 | the spawn faults with `peer unreachable`; `ernest.conf` is not read, and of the configuration directory only the shell's `startup` is |
| a working directory whose name is not UTF-8, under a UTF-8 locale (§11) | MVP 2.95 | `ern` hangs as the host boots, before its refusal can run, and only `kill -9` ends it; under a locale whose names are bytes it refuses |

Every refusal the toolchain makes for a later milestone's sake names that milestone in its error text, and a test in `erl/cli/test` fails when such a text is missing from this table. Runtime behaviour that stands in for a later milestone, the peer fault and the hang in a working directory whose name is not UTF-8, is listed by hand. `make sections` prints only what the plan's *Standing gaps* names.
