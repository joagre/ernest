# Ernest

A functional language for explicit process protocols. Mailbox effects and linear replies are part of the type system. Two organizing ideas: pure functions with Hindley-Milner types, and processes with typed mailboxes. On BEAM (Erlang OTP 27).

## Status

The toolchain is written in Erlang: lexer, parser, type checker, runtime, the compiler to BEAM, and the two programs `ernc` and `ern` under `bin/`, with every example program the toolchain runs compiled and run as a test. Where the project stands and what comes next is the first paragraph of [`docs/implementation_plan.md`](docs/implementation_plan.md).

## Reading order

### Start here

- **[`ernest_report.md`](ernest_report.md)** — the language report. Normative. Everything else in this repo defers to it. About twenty pages of rules in twelve numbered sections, 0 through 11, in the register of a Wirth report, no rationale and no restating, plus six appendices: grammar (A), examples (B), configuration (C), a foreign-library walk-through (D), the standard library (E), and a glossary (F). The reasons are in the decisions log.

- **[`ernest_guide.md`](ernest_guide.md)** — a reading guide for a first-time reader. Walks through hello world, types (including abstract), functions, one process (a counter), two processes talking (ping-pong), watching processes (`monitor`, `kill`), adapting messages with `via`, the `<-` chaining idiom, remote computation, foreign types and functions, bitstrings, and the toolchain. Closes with a short FAQ and pointers to the paper programs.

### Then the small programs

The complete programs from the report's Appendix B and D and the guide's checkpoints are collected under [`examples/`](examples/). Each program's header comment says where it comes from and what it needs; `template.ern`, a documented module with no header comment, is described by [`docs/module_doc_template.md`](docs/module_doc_template.md). Together the examples exercise every construct of the grammar except bitstrings, and a test keeps it so.

**What the toolchain runs.** The programs `make test` compiles and runs are the `PROGRAMS` macro in `test/ern_integration_tests.erl`, with their expected output under `test/expected/` and the Erlang they compile to under `test/golden/`. The `modules` pair runs there too, and the paper programs have tests of their own: `repl` on a fixed input, `filesync` given two directories, and `webserver` asked twice over one session, each stopped when it has shown what it must. `snake` wants a terminal, so it is compiled by its test and played by hand, and `echo` is a measurement run by hand; the rest of `examples/` is type-checked only, and each file's header says where it stands.

### Then the paper programs

[`examples/snake.ern`](examples/snake.ern), [`examples/repl.ern`](examples/repl.ern), [`examples/filesync.ern`](examples/filesync.ern), and [`examples/webserver.ern`](examples/webserver.ern), in that order; guide §9 says what each one shows.

### Then, as reference material

- **[`docs/decisions.md`](docs/decisions.md)** — dated design decisions and their rationale. What was tried, what was rejected, why the report says what it says. Not normative — the report wins any conflict. Browse as needed; not intended to be read straight through.

- **[`docs/implementation_plan.md`](docs/implementation_plan.md)** — the roadmap: MVP 1 and MVP 2, done, and the later MVPs.

- **[`docs/architecture.md`](docs/architecture.md)** — how the toolchain is built: the stages, what flows between them, the checker's passes, the compiler's one traversal, the runtime, the tests, and where MVP 2.5 and later hook in.

## Ground rules

- **`ernest_report.md` is the single normative document.** Nothing else in this repo overrides it.
- **Appendix A of the report is the grammar.** Any conflict between prose and Appendix A is resolved in favor of Appendix A.
- **Section 0 of the report is the five principles.** They break ties when the design admits options.
- **The decisions log is rationale only.** It's updated when the report is updated. Historical entries are dated and reflect their point in time.
- **Example programs are illustrative.** They test the report by putting it through real programs. When they surface an anomaly, the report changes first, then the log, then the code.

## Layout of the language

Four layers:

- **Language.** The rules in `ernest_report.md`: syntax, types, processes, evaluation. Small and stable.
- **Prelude.** What the report requires to exist, §9: the built-in and declared types, the process functions, the operations the operators resolve to, and the system references. A prelude operation in a type's namespace is provided by that type's standard library module.
- **Standard library** (Appendix E). On the load path by default: one module per namespace of Appendix E, mostly one per type and one per system process, which is the way a program uses a `Sys.*` reference. Appendix E.0 has the rules for what enters and how it is named. Where the modules live and when they move to Ernest under `stdlib/` is the plan's MVP 2.5.
- **Libraries.** Everything else, `Json`, `Tls`, `Regex`, `Http`, and the rest: written on the foreign-library pattern of Appendix D, by anyone, added to a program's load path when wanted. Which are first-party under `libs/`, and when, is the plan's MVP 2.6 and 2.7. The line between the standard library and a library is Appendix E.0: a namespace of its own with policy inside is a library, however useful.

## Layout of the repository

```
VERSION            the toolchain's version, read at build time
ernest_report.md   the language report (normative)
ernest_guide.md    the reading guide
docs/              decisions log, implementation plan, architecture note, style guides, naming record,
                   module documentation template, shell design
examples/          Ernest programs: the paper programs and the small ones
erl/               the toolchain, as Erlang applications: lexer, parser,
                   typer, runtime, emitter, cli, utils (vendored getopt);
                   each has src/, include/, ebin/, test/
test/              what spans applications: the hand-written target modules,
                   the integration tests, the pseudo-terminal harness,
                   expected/, golden/, input/, terminal/
bin/               ernc and ern, as escript sources
stdlib/            the standard library as Ernest source
shell/             the shell as Ernest source, from MVP 2.6
build/             build products, not in git: build/stdlib/ from make and make doc
libs/              the first-party libraries, each a source root, from MVP 2.6
```

A module path segment is one lowercase word (report §11.1); a multi-word module is a nested directory. Files that are not modules use underscores.

## Building

Erlang/OTP 27 and GNU make. No rebar3, no OTP behaviours. `make test` also needs python3, for the pseudo-terminal the terminal tests run a program under; Erlang cannot open one.

```
make              compile every application into its ebin/, then stdlib/
make test         build, run the EUnit tests, then the tests in test/
make doc          write the standard library's pages to build/stdlib/, with index.md
make sections     list the report sections no test cites
make xref         check that every section citation in the documents resolves
make coverage     every section with how many tests cite it, thinnest first
make golden       rewrite test/golden/, the Erlang the compiler emits per example
make clean        remove build products
make clean-emacs  remove Emacs backup, auto-save, and lock files
```

## Using

`bin/ernc` compiles, `bin/ern` runs; both take long options only (report §11).

```
bin/ernc examples/hello.ern                  # writes examples/hello.erc
bin/ern examples/hello.erc                   # hello, world
bin/ernc --out-dir build examples/modules    # a source tree, in dependency order
bin/ern build/main.erc                       # loads net/http.erc by namespace
bin/ernc --emit erl examples/hello.ern       # the Erlang source, for reading
bin/ernc --doc stdlib/list.ern                           # the module's documentation as CommonMark
bin/ernc --errors short examples/hello.ern  # the first line of each error only
bin/ern --create-config-dir .                # .ernest/ with a key pair
```

## What the toolchain accepts

The toolchain is the report on one node; the plan's MVPs lift the table row by row. Everything the report describes type-checks, and what the table leaves out compiles and runs: pure functions with inference, `Float` and operators on user types, `foreign fn` and `foreign type` with the checks of §8.4, bitstrings, sum and abstract types, processes with typed mailboxes, `receive` with `after`, `Address.call`, `monitor` and `kill`, `<-`, `match` with any guard, top-level `let`, and modules in directories. The table is what the toolchain refuses or does not yet check, each with the MVP that lifts it in [`docs/implementation_plan.md`](docs/implementation_plan.md).

| Construct | Until | What you see today |
|---|---|---|
| `ern --shell` (§11.2) | MVP 2.6 | `the shell is not in this toolchain yet; it arrives in MVP 2.6` |
| `spawn(Peer(...))`, peers, `--config-dir` (§6.2, §8.3) | MVP 3 | `spawn` faults with `peer unreachable`; the configuration is not read |
| `remote`, `parallelRemote` (§6.7) | MVP 3 | `Left(NoRemotePeer)` |

Every refusal the toolchain makes for a later MVP's sake names in its error text the MVP that brings the thing, and a test in `erl/cli/test` fails when such a text is missing from this table. Runtime behaviour that stands in for a later MVP, the peer fault and `Left(NoRemotePeer)`, is listed by hand. `make sections` lists the report sections no test cites; the three it prints are MVP 3 material. `make coverage` lists every section with how many tests cite it and its length, thinnest first: a long section with one citation is where a rule can hide untested.

## License

Ernest is released under the terms in [`LICENSE`](LICENSE). Third-party components are listed, with their licenses, in [`THIRD_PARTY_LICENSES`](THIRD_PARTY_LICENSES).
