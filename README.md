# Ernest

A functional language for explicit process protocols. Mailbox effects and linear replies are part of the type system. Two organizing ideas: pure functions with Hindley-Milner types, and processes with typed mailboxes. On BEAM (Erlang OTP 27).

## Status

Design complete for MVP 1 (single-node subset). The toolchain is done in Erlang: lexer, parser, type checker, runtime, the compiler to BEAM, and the two programs `ernc` and `ern` under `bin/`, with every MVP 1 example program under `examples/` compiled and run as a test.

## Reading order

### Start here

- **[`ernest_report.md`](ernest_report.md)** — the language report. Normative. Everything else in this repo defers to it. About twenty pages of rules in twelve numbered sections, 0 through 11, in the register of a Wirth report, no rationale and no restating, plus six appendices: grammar (A), examples (B), configuration (C), a foreign-library walk-through (D), the standard library (E), and a glossary (F). The reasons are in the decisions log.

- **[`ernest_guide.md`](ernest_guide.md)** — a reading guide for a first-time reader. Walks through hello world, types (including abstract), functions, one process (a counter), two processes talking (ping-pong), watching processes (`monitor`, `kill`), adapting messages with `via`, the `<-` chaining idiom, remote computation, foreign types and functions, bitstrings, and the toolchain. Closes with a short FAQ and pointers to the paper programs.

### Then the small programs

The complete programs from the report's Appendix B and D and the guide's checkpoints are collected under [`examples/`](examples/). Each file's header says where it comes from and which MVP it needs. Together the examples exercise every construct of the grammar except bitstrings, and a test keeps it so.

**What MVP 1 runs.** The programs `make test` compiles and runs are the `PROGRAMS` macro in `test/ern_integration_tests.erl`, with their expected output under `test/expected/` and the Erlang they compile to under `test/golden/`. The rest of `examples/` is type-checked only, and each file's header says which MVP runs it.

### Then the paper programs

[`examples/snake.ern`](examples/snake.ern), [`examples/repl.ern`](examples/repl.ern), [`examples/filesync.ern`](examples/filesync.ern), and [`examples/webserver.ern`](examples/webserver.ern), in that order; guide §9 says what each one shows.

### Then, as reference material

- **[`docs/decisions.md`](docs/decisions.md)** — dated design decisions and their rationale. What was tried, what was rejected, why the report says what it says. Not normative — the report wins any conflict. Browse as needed; not intended to be read straight through.

- **[`docs/implementation_plan.md`](docs/implementation_plan.md)** — MVP 1 roadmap. About eight weeks of one-person work in Erlang, with a hand-written parser.

- **[`docs/architecture.md`](docs/architecture.md)** — how the toolchain is built: the stages, what flows between them, the checker's passes, the compiler's one traversal, the runtime, the tests, and where MVP 2 hooks in.

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
- **Standard library** (Appendix E). On the load path by default: one module per type and one per system process, which is the way a program uses a `Sys.*` reference. Appendix E.0 has the rules for what enters and how it is named. Erlang modules under `lib/runtime/src` until MVP 2.5, then Ernest under `stdlib/`.
- **Libraries.** Everything else, `Json`, `Tls`, `Regex`, `Http`, and the rest: written on the foreign-library pattern of Appendix D, by anyone, added to a program's load path when wanted. The first four, `json`, `tls`, `http`, `base64`, are first-party under `libs/` from MVP 2.6, listed with their signatures in an informative appendix of the report as Appendix E lists the standard library; their own repositories come with a package story. The line between the standard library and a library is Appendix E.0: a namespace of its own with policy inside is a library, however useful.

## Layout of the repository

```
ernest_report.md   the language report (normative)
ernest_guide.md    the reading guide
docs/              decisions log, implementation plan
examples/          Ernest programs: the paper programs and the small ones
lib/               the compiler, as Erlang applications: lexer, parser,
                   type_system, runtime, compiler, cli, utils (vendored
                   getopt); each has src/, include/, ebin/, test/
test/              what spans applications: the hand-written target modules,
                   the integration tests, expected/, golden/
bin/               ernc and ern, as escript sources
stdlib/            the standard library as Ernest source, from MVP 2.5
libs/              the first-party libraries, each a source root, from MVP 2.6
```

A module path segment is one lowercase word (report §11.1); a multi-word module is a nested directory. Files that are not modules use underscores.

## Building

Erlang/OTP 27 and GNU make. No rebar3, no OTP behaviours.

```
make              compile every application into its ebin/
make test         run the EUnit tests, then the integration tests in test/
make sections     list the report sections no test cites
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
bin/ernc --doc examples/ets.ern              # doc comments as Markdown
bin/ern --create-config-dir .                # .ernest/ with a key pair
```

## What MVP 1 accepts

MVP 1 is the report on one node. Everything the report describes type-checks, and what the table leaves out compiles and runs: pure functions with inference, sum and abstract types, processes with typed mailboxes, `receive` with `after`, `Address.call`, `monitor` and `kill`, `<-`, `match` with any guard, top-level `let`, and modules in directories. The table is what the toolchain refuses or does not yet check, each with the MVP that lifts it in [`docs/implementation_plan.md`](docs/implementation_plan.md).

| Construct | Until | What you see today |
|---|---|---|
| `Float` arithmetic and negation (§3.1); `Float` values and the `Float` functions work | MVP 2 | `Float arithmetic is not in MVP 1` |
| `foreign fn`, `foreign type` (§4.7) | MVP 2 | type-checks; `ernc` says `foreign functions are not in MVP 1` |
| Bitstrings (§5.11) | MVP 2 | `bitstrings are not in MVP 1` |
| The ownership rule of abstract types (§4.4) | MVP 2 | not checked; a constructor is usable anywhere in its module |
| A `Reply` captured by a lambda that reaches `spawn` through a `let` rather than as its direct argument (§6.6) | MVP 2 | `in MVP 1 the reply-carrying value r is captured by a lambda that is not passed directly to spawn` |
| `Deadlock` (§8.6) | MVP 2 | a deadlocked program waits |
| `Sys.stdin`, `Sys.keys`, `Sys.fs`, `Sys.tcp` and their modules `Io.readLine`, `Keys`, `Fs`, `Tcp` (§8.2, Appendix E.15 to E.18) | MVP 2.5 | type-checks; `ernc` says `Tcp.listen is not in MVP 1`, and the same for each of those names |
| `ern --shell` (§11.2) | MVP 2 | `the shell is not in MVP 1` |
| `spawn(Peer(...))`, peers, `--config-dir` (§6.2, §8.3) | MVP 3 | `spawn` faults with `peer unreachable`; the configuration is not read |
| `remote`, `parallelRemote` (§6.7) | MVP 3 | `Left(NoRemotePeer)` |
| `receive` guards beyond comparisons joined by `&&` and `\|\|` (§5.9) | MVP 4 | `in MVP 1 a receive guard is a comparison, ...` |

Every refusal the toolchain makes for MVP 1's sake says "MVP 1" in its error text, and a test in `lib/cli/test` fails when such a text is missing from this table. Runtime behaviour that stands in for a later MVP, the peer fault and `Left(NoRemotePeer)`, is listed by hand. `make sections` lists the report sections no test cites; the three it prints are MVP 3 material. `make coverage` lists every section with how many tests cite it and its length, thinnest first: a long section with one citation is where a rule can hide untested.

## License

Ernest is released under the terms in [`LICENSE`](LICENSE). Third-party components are listed, with their licenses, in [`THIRD_PARTY_LICENSES`](THIRD_PARTY_LICENSES).
