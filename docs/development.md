# Working on Ernest

For those who work on the language and its toolchain: where things are, how to build and test them, and what the toolchain does not do yet. A reader who wants to learn Ernest starts with the [guide](../guide/language.md) instead.

The report, in three files under [`report/`](../report/), is the one normative document. How work proceeds, and which document owns which fact, is in [`CLAUDE.md`](../CLAUDE.md).

## The documents

- **[`implementation_plan.md`](implementation_plan.md)**: where the project stands and what comes next.
- **[`decisions.md`](decisions.md)**: the dated rationale for the report and the plan, and what was rejected. Not normative.
- **[`architecture.md`](architecture.md)**: how the toolchain is built, from the lexer to the runtime, and what each test runs.
- **[`memory.md`](memory.md)**: how the project checks that nothing grows with the work done.
- **[`soundness.md`](soundness.md)**: the argument that a well-typed program does not go wrong, kept with the rules it covers.
- **[`otp_bugs.md`](otp_bugs.md)**: the defects found in OTP, each written as a report for OTP's tracker.
- **[`release_review.md`](release_review.md)**: what a release runs to be ready.
- **[`full_review.md`](full_review.md)**: every reader over the whole of its area, run seldom.
- **[`principles_review.md`](principles_review.md)**: the report and the guide read against §0, and §0 against what it decided.
- **[`style.md`](style.md)**: the style of the Erlang, the C and the Ernest.
- **[`module_doc_template.md`](module_doc_template.md)**: a documented module, as `ern doc` renders it.
- **[`language_feedback.md`](language_feedback.md)**: what writing Ernest has felt against the principles, until the plan decides it.
- **[`proposals/`](proposals/)**: what is designed, a directory for each proposal. The peer protocol of MVP 3.0 is there, decided, and the report's §8.7 is rewritten from it; operations records are there as the record of what was built, with three programs the tests run; and so are the design notes of the shell, [`shell_design.md`](proposals/shell/shell_design.md), of the Emacs major mode, [`emacs_mode.md`](proposals/emacs/emacs_mode.md), and of the installation, [`install.md`](proposals/install/install.md).
- **[`src/shell/README.md`](../src/shell/README.md)**: a guide to the shell's code.
- **[`editors/emacs/README.md`](../editors/emacs/README.md)**: how to install the Emacs mode.

The prelude is the report's §9 and the standard library its Appendix E, which admits a module or a function by Appendix E.0's rules. The libraries under `src/libs/` are Appendix G's; a program adds one to its load path when it wants it, and which are first-party is the plan's MVP 4.1.

## The layout of the repository

`src/` holds the Ernest code a release ships, the standard library, the libraries and the shell; `erl/` holds the Erlang it ships; `editors/` holds the editor modes; everything else serves the repository. `report/` and `guide/` stand at the top, since they are the language, where `docs/` is the project talking about itself, the manual pages and the proposals among its documents.

```
VERSION            the toolchain's version, read at build time
README.md          what Ernest is and where to begin
CLAUDE.md          the working rules
Makefile           the build and the tests' targets
LICENSE, THIRD_PARTY_LICENSES  the license, and the third-party code's
ACKNOWLEDGMENTS.md the people Ernest stands on
report/            the report (normative), in three files: language.md, §0 to §10 and
                   Appendices A, B and F; toolchain.md, §11 and Appendices C and H;
                   library.md, Appendices D, E and G
guide/             the guides: language.md, the language guide, and deployment.md,
                   Running Ernest, the operator's
assets/            the logo the README, the guide and a release show, light and dark, the
                   stoat mark alone as a vector and as a
                   512-pixel avatar, and the social preview GitHub's settings take,
                   with a note on each
docs/              the documents listed above, and this one
docs/proposals/    what is designed, a directory for each proposal: the proposal, the
                   reasons for it, what other systems do, and its experiments or
                   programs; tentative until decided, and kept as a record once built
docs/man/          the pages as CommonMark, which make man writes from main and a
                   release commits: the prelude's and the standard library's under
                   stdlib/, each library's under libs/, an index in each and one over
                   them, each its directory's README.md
examples/          Ernest programs written for a reader of the language, which
                   examples/README.md lists in the order to read them
erl/               the toolchain, as Erlang applications: lexer, parser, format,
                   typer, runtime, emitter, cli, utils, which holds the vendored
                   getopt, and json, the primitives of src/libs/json; each has src/, include/, ebin/ and test/, and the runtime
                   also c_src/, the helper ern_exec's C source, and priv/, where make
                   builds it
test/              what spans applications: the integration, nodes, deployment guide,
                   document, style, guide, grammar, generated-program, shell and
                   terminal tests, the harnesses of the loads, the benchmark, the
                   service manager's checks and the pseudo-terminal, ern_grammar.erl,
                   which reads Appendix A,
                   ern_repository.erl, which the document and style tests read the
                   repository through, and the catalog of diagnostics; target/, the
                   hand-written target modules; programs/, the programs the tests keep:
                   the first test programs, a two-module tree, the module of
                   docs/module_doc_template.md and the echo measurement; expected/ and
                   golden/, what programs/, hello, services and the operations programs print,
                   repl's session among them, and the Erlang they compile to; and
                   bench/, input/, layout/, load/, service/, session/, stdin/ and
                   terminal/, the programs and inputs tests run
bin/               ern, the launcher, a POSIX sh script
src/stdlib/        the standard library as Ernest source
src/libs/          the first-party libraries, each a source root a program adds
                   with --load-path: ansi, ets, json, markdown, which needs ansi,
                   proxy and utilization
src/shell/         the shell as Ernest source; its README.md guides a reader
                   through the code
editors/emacs/     ernest-mode.el, the Emacs major mode, and its tests under test/
tools/             the programs of the build: manual.ern writes ern(1) from the
                   report's §11, for make; unicode_width.escript writes Terminal.width's
                   table, for make unicode; install.sh, with strip.escript, stages,
                   installs and archives, for make install, uninstall and release; and
                   release/ holds the archive's own Makefile and README.md
build/             build products, not in git: stdlib/, libs/, shell/, tools/ and man/
                   from make, with the manual pages; the standard library's pages
                   in stdlib/ from make doc; pages/ from make man; release/ from
                   make release; dialyzer/ and dialyzer.plt from make dialyzer;
                   sanitize/ from make sanitize
```

A module's path follows report §11.1. A file that is not a module is named with underscores, but for the Emacs mode's, which follow Emacs's convention.

## Building

Beyond what the README's *Installing* needs, `make test-full` needs python3, which opens the terminal tests' pseudo-terminal and signals `ern` in the tests of how it ends, and `make sanitize` needs clang. Emacs, man, and groff or mandoc are optional: where one is missing, the tests that need it say so and are skipped.

```
make              build the helper, compile every application into its ebin/, then
                  src/stdlib/, src/libs/, src/shell/ and tools/, and write each manual page
                  that is missing or older than what it is made from
make test         build, then the unit tests of every application and the document
                  and style tests, side by side: the light run, a minute or two
make test-full    build, then every area below, side by side: the whole suite
make test-erl     the unit tests of every application under erl/, side by side;
                  APP=typer for one
make test-programs  the five parts below, side by side
make test-integration  the programs compiled and run as a user runs them, the
                  signals, the streams, Os and the libraries' tests, and that the
                  measuring machine reaches every function of the library
make test-nodes   nodes on one machine
make test-deployment  the deployment guide's commands and its deployment end to end
                  run on nodes, and the lines it quotes held to a node's
make test-manual  the manual pages against §11, each rendered
make test-install  the installation and the release archive, installed and run
                  where they are put; after test-manual, which it runs first,
                  since both write the manual pages
make test-docs    the document tests and the style tests
make test-guide   the guide's examples, the report's, the README's, and the catalog of
                  diagnostics
make test-grammar  Appendix A read as data, and a thousand programs generated from it,
                  parsed, laid out and given as near misses; ERN_SEED=n runs a failing
                  seed again
make test-typed   well-typed programs generated, checked, compiled and run in one host,
                  each printing what an interpreter of it computes, and programs that
                  hand a reply on, changed so that the checker must refuse them;
                  ERN_SEED=n runs a failing seed again
make test-shell   the shell's sessions and the terminal
make test-emacs   the Emacs mode's tests (docs/proposals/emacs/emacs_mode.md)
make load         the loads of docs/memory.md; not part of make test-full, whose
                  test-integration builds their programs and the benchmark's
make service      a program run by the host's service manager, a user's systemd or
                  launchd: started, stopped, started again after Os.exit(1); not
                  part of make test-full
make bench        what each of a few operations costs in Ernest beside the same
                  operation in Erlang, in nanoseconds, a raise at each backtrace depth
                  among them; then every function of the library beside the host's, at
                  10, 100 and 10,000, its time and what it allocates, with what costs
                  more than three times the host's and whether the machine was idle, the
                  whole table in test/build/bench/library.txt; then, between two nodes on
                  this machine, the host's ping over TLS and over TCP, a call to the other
                  node's process, and a round trip to it straight and through an adapted
                  address made there; then, on nodes it starts, what a spawn and a compute
                  cost whose code crosses, each step of the exchange, a fix's callers,
                  what an arrival, a Code.load and a day's spawns add to the host's
                  counts, a utilization, a compute on a peer picked and on one named,
                  the pick alone, what connected nodes exchange idle with their tellings,
                  and the sizes of an .erc and a code frame; not part of make
                  test-full
make doc          write the standard library's and the prelude's pages to build/stdlib/,
                  with index.md
make man          write every page: the manual pages make writes, and docs/man/, main's pages
                  as CommonMark, the standard library's, the prelude's and each
                  library's, with their indexes (docs/release_review.md)
make manual       the manual pages alone, which make also writes: each module's beside
                  its .erc, as build/stdlib/Ernest.List.3ern, and ern(1) as
                  build/man/ern.1, which man -l shows
make install      install under PREFIX, /usr/local by default, within DESTDIR if one
                  is given (docs/proposals/install/install.md)
make uninstall    remove the installation under the same PREFIX and DESTDIR
make release      write the release archive, build/release/ern-VERSION.tar.gz
make dialyzer     Dialyzer over the toolchain and the Erlang the compiler writes for
                  src/stdlib/, src/shell/ and src/libs/; its first run builds
                  build/dialyzer.plt
make sanitize     the helper in C under Clang's analyzer, and the runtime's and the
                  programs' tests with it built under the sanitizers
make sections     list the report sections no test cites
make xref         the document tests alone, without a build: every citation and
                  document path resolves
make coverage     every section with how many tests cite it and its length, thinnest first
make golden       rewrite test/golden/, the Erlang the compiler emits for each program
                  `golden_names/0` lists: test/programs/, hello and services
make diagnostics  rewrite the outputs of test/diagnostics.md, the front end's errors,
                  from what ern build prints
make contents     rewrite the contents lists of the report and the guide from their headings
make format       lay out every Ernest module, and the Ernest blocks of the report and the
                  guide, as ern format does (report §11.6)
make unicode UC_SPEC=dir
                  write Terminal.width's table from Unicode's data in dir, OTP's
                  lib/stdlib/uc_spec of the host's version
make clean        remove build products
make clean-emacs  remove Emacs backup, auto-save, and lock files
```

While a change is worked on, it runs the targets of its kind; which run a commit needs is CLAUDE.md's *Tests*.

| A change to | Runs |
|---|---|
| the Erlang of one application | `make test-erl APP=<app>`, then `make test`; the parser and the formatter `make test-grammar` too, the checker and the emitter `make test-typed` |
| the runtime | `make test`, `make test-integration` |
| nodes, or the deployment guide | `make test`, `make test-nodes`, `make test-deployment` |
| the standard library, or a library under `src/libs/` | `make test`, `make test-integration` |
| the shell | `make test`, `make test-shell` |
| the installation, the release, or the manual pages | `make test-install`, which runs `test-manual` first; the pages alone `make test-manual` |
| the Emacs mode | `make test-emacs` |
| the language guide, the report, the README, `test/diagnostics.md` or `docs/module_doc_template.md` | `make test`, `make test-guide`; report Appendix A `make test-grammar` too, report §11 `make test-manual` and `make test-shell` |
| a proposal, or any other document | `make test-docs` |

Which programs the tests compile and run is [`architecture.md`](architecture.md)'s *Tests*.

One application's test module runs alone as the suite runs it: its test beams by `make -s -C erl/<app>/src beams`, then, from `erl/<app>/src`, `ERN_TEST_DIR=$(mktemp -d) erl -noshell -pa ../../*/ebin -pa $(realpath ../../../build/stdlib) -pa $(realpath ../../../build/shell) -eval 'eunit:test(ern_chunk_tests, [])' -s init stop`. A whole `make test-full` takes about ten minutes: run it with its output in a file, and read the file for "timed out" and for EUnit's word for a canceled test, which it spells the British way, beside "failed", since EUnit prints `Failed: 0` beside a canceled test.

## Using

`bin/ern` is the toolchain, its first word the job, with long options only (report §11). Where the guide writes `ern`, this repository's `bin/` is on the `PATH`.

```
bin/ern build examples/hello.ern                  # writes examples/hello.erc
bin/ern run examples/hello.erc                    # hello, world
bin/ern build --build-root build/modules test/programs/modules  # a tree, in dependency order
bin/ern run build/modules/main.erc                # loads net/http.erc by namespace
bin/ern build --emit-erl examples/hello.ern       # the Erlang source, for reading
bin/ern doc src/stdlib/list.ern                   # the module's documentation as CommonMark
bin/ern build --short-errors examples/hello.ern   # the first line of each error only
bin/ern config                                    # ./.ernest with a key pair
bin/ern reload --config-dir node                  # the node running from node/ reads its ernest.conf again
bin/ern stop --config-dir node                    # and ends, in order
bin/ern shell                                     # a shell over the standard library
bin/ern shell build/modules/main.erc              # a shell beside a running program
bin/ern test build/shell/shell/editor.erc         # the module's tests
bin/ern test --load-path build/libs/ansi build/libs   # the tests of every module under it
```

A program whose source tree `app` uses a library adds the library's build to its load path, both to build and to run:

```
bin/ern build --load-path build/libs/ets --build-root build/app app
bin/ern run --load-path build/libs/ets build/app/main.erc
```

The shell's `:help` lists its commands; the language guide §9.3 teaches the shell, report §11.2 defines it, and [`shell_design.md`](proposals/shell/shell_design.md) says how it is built.

## What the toolchain accepts

The toolchain is the report, on one node and across nodes. Everything the report describes type-checks, and all that the table leaves out compiles and runs. Each row is what the toolchain refuses or does not yet do, with the milestone of the [plan](implementation_plan.md) that lifts it; today the table has no row.

| Construct | Until | What you see today |
|---|---|---|

Every refusal the toolchain makes for a later milestone's sake names that milestone in its error text, and `mvp_refusals_listed_test` in `erl/cli/test/ern_cli_tests.erl` fails when such a text is missing from this table. Runtime behavior that stands in for a later milestone is listed by hand. `make sections` prints only a section of a milestone not yet built, which that milestone's plan item names.
