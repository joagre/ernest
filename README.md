# Ernest

A functional language for explicit process protocols. Mailbox effects and linear replies are part of the type system. Two organizing ideas: pure functions with Hindley-Milner types, and processes with typed mailboxes. On BEAM (Erlang OTP 27).

## Status

Design complete for MVP 1 (single-node subset). The toolchain is done in Erlang: lexer, parser, type checker, runtime, the compiler to BEAM, and the two programs `ernc` and `ern` under `bin/`, with every MVP 1 example program under `examples/` compiled and run as a test.

## Reading order

### Start here

- **[`ernest_report.md`](ernest_report.md)** — the language report. Normative. Everything else in this repo defers to it. Prose in twelve numbered sections, 0 through 11, plus six appendices: grammar (A), examples (B), configuration (C), a foreign-library walk-through (D), the standard library (E), and a glossary (F).

- **[`ernest_guide.md`](ernest_guide.md)** — a reading guide for a first-time reader. Walks through hello world, types (including abstract), functions, one process (a counter), two processes talking (ping-pong), watching processes (`monitor`, `kill`), adapting messages with `via`, the `<-` chaining idiom, remote computation, foreign types and functions, bitstrings, and the toolchain. Closes with a short FAQ and pointers to the paper programs.

### Then the small programs

The complete programs from the report's Appendix B and D and the guide's checkpoints are collected under [`examples/`](examples/): `hello`, `counter`, `upgrade`, `pingpong`, `stack`, `patterns`, `kvparser`, the two-module pair under `modules/`, `remote`, and the foreign library `ets`. All but `ets` are the MVP 1 test programs, compiled and run by `make test`. Each file's header says where it comes from and which MVP it needs. Together the examples exercise every construct of the grammar except bitstrings, and a test keeps it so.

### Then the paper programs, in this order

- **[`examples/snake.ern`](examples/snake.ern)** — a snake game with tick-based updates. Introduces `..` record update, `Map` folds, one process per player.
- **[`examples/repl.ern`](examples/repl.ern)** — a read-eval-print loop for a small expression language. Heavy use of `<-`, `try` as a supervised child process, `monitor` for detecting child death.
- **[`examples/filesync.ern`](examples/filesync.ern)** — file synchronization between two nodes. Introduces mutual-address setup and additional runtime references (`Sys.fs`).
- **[`examples/webserver.ern`](examples/webserver.ern)** — HTTP server with sessions. Introduces `foreign fn`, abstract types with signatures, ETS as a foreign process.

### Then, as reference material

- **[`docs/decisions.md`](docs/decisions.md)** — dated design decisions and their rationale. What was tried, what was rejected, why the report says what it says. Not normative — the report wins any conflict. Browse as needed; not intended to be read straight through.

- **[`docs/implementation_plan.md`](docs/implementation_plan.md)** — MVP 1 roadmap. About eight weeks of one-person work in Erlang, with a hand-written parser.

## Ground rules

- **`ernest_report.md` is the single normative document.** Nothing else in this repo overrides it.
- **Appendix A of the report is the grammar.** Any conflict between prose and Appendix A is resolved in favor of Appendix A.
- **Section 0 of the report is the five principles.** They break ties when the design admits options.
- **The decisions log is rationale only.** It's updated when the report is updated. Historical entries are dated and reflect their point in time.
- **Example programs are illustrative.** They test the report by putting it through real programs. When they surface an anomaly, the report changes first, then the log, then the code.

## Layout of the language

Three layers:

- **Language.** The rules in `ernest_report.md`: syntax, types, processes, evaluation. Small and stable.
- **Prelude.** What the report requires to exist. Small — the built-in types (Address, Reply, Never, Foreign, plus List, Map, and Set); a handful of declared sum types (Unit, Optional, Either, Ordering, Down, Reason, ClockMsg, RemoteError, Where); the built-in functions (self, send, spawn); the process functions (via, Address.call, Address.callForever, answer, remote, parallelRemote, monitor, kill); the operations Ernest's operators resolve to (`Int.+` through `Int.%`, `Float.+` through `Float./`, negation, `String.<>`, `List.<>`, `Bytes.<>`, `Int.div`/`Int.mod`, the `.compare` functions, `todo`); and system references (Sys.stdout, Sys.clock).
- **Standard library** (Appendix E). On the load path by default, as Erlang modules under `lib/runtime/src` until `foreign fn` arrives in MVP 2: Io, List, Map, Set, String, Char, Bool, Int, Float, Optional, Either, Foreign. Grows when a paper program writes the same pattern three times.

## Layout of the repository

```
ernest_report.md   the language report (normative)
ernest_guide.md    the reading guide
docs/              decisions log, implementation plan
examples/          Ernest programs: the paper programs and the small ones
lib/               the compiler, as Erlang applications: lexer, parser,
                   type_system, runtime, compiler, utils; each has src/,
                   include/, ebin/, test/
bin/               ernc and ern
```

A module path segment is one lowercase word (report §11.1); a multi-word module is a nested directory. Files that are not modules use underscores.

## Building

Erlang/OTP 27 and GNU make. No rebar3, no OTP behaviours.

```
make              compile every application into its ebin/
make test         run the EUnit tests, then the integration tests in test/
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
| `Float` arithmetic (§3.1) | MVP 2 | `Float arithmetic is not in MVP 1` |
| `foreign fn`, `foreign type` (§4.7), the `Foreign` namespace (E.12) | MVP 2 | type-checks; `ernc` says `foreign functions are not in MVP 1` |
| Bitstrings (§5.11) | MVP 2 | `bitstrings are not in MVP 1` |
| The ownership rule of abstract types (§4.4) | MVP 2 | not checked; a constructor is usable anywhere in its module |
| `Deadlock` (§8.6) | MVP 2 | a deadlocked program waits |
| `ern --shell` (§11.2) | MVP 2 | `the shell is not in MVP 1` |
| `spawn(Peer(...))`, peers, `--config-dir` (§6.2, §8.3) | MVP 3 | `spawn` faults with `peer unreachable`; the configuration is not read |
| `remote`, `parallelRemote` (§6.7) | MVP 3 | `Left(NoRemotePeer)` |
| `receive` guards beyond comparisons joined by `&&` and `\|\|` (§5.9) | MVP 4 | `in MVP 1 a receive guard is a comparison, ...` |

`make sections` lists the report sections no test cites; the six it prints are definitions with nothing to run or MVP 3 material.

## License

Ernest is released under the terms in [`LICENSE`](LICENSE). Third-party components are listed, with their licenses, in [`THIRD_PARTY_LICENSES`](THIRD_PARTY_LICENSES).
