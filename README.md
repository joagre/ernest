# Ernest

A functional language for explicit process protocols. Mailbox effects and reply ownership are part of the type system. Two organizing ideas: pure functions with Hindley-Milner types, and processes with typed mailboxes. On BEAM (Erlang OTP 27).

## Status

Design complete for MVP 1 (single-node subset). Implementation begins with the lexer and parser, in Erlang. The compiler is `ernc`; the runner is `ern`.

## Reading order

### Start here

- **[`ernest_report.md`](ernest_report.md)** — the language report. Normative. Everything else in this repo defers to it. Prose in eleven numbered sections plus six appendices: grammar (A), examples (B), configuration (C), a foreign-library walk-through (D), the standard library (E), and a glossary (F).

- **[`ernest_guide.md`](ernest_guide.md)** — a reading guide for a first-time reader. Walks through hello world, types (including abstract), functions, one process (a counter), two processes talking (ping-pong), watching processes (`monitor`, `kill`), adapting messages with `via`, the `<-` chaining idiom, remote computation, foreign types and functions, bitstrings, and the toolchain. Closes with a short FAQ and pointers to the paper programs.

### Then the small programs

The complete programs from the report's Appendix B and the guide's checkpoints are collected under [`examples/`](examples/): `hello`, `counter`, `counter_upgrade`, `ping_pong`, `stack`, the two-module pair under `modules/`, and `remote`. The first four and `stack` are the MVP 1 test programs. Each file's header says where it comes from and which MVP it needs.

### Then the paper programs, in this order

- **[`examples/tick_game.ern`](examples/tick_game.ern)** — a snake game with tick-based updates. Introduces `..` record update, `Map` folds, one process per player.
- **[`examples/repl.ern`](examples/repl.ern)** — a read-eval-print loop for a small expression language. Heavy use of `<-`, `try` as a supervised child process, `monitor` for detecting child death.
- **[`examples/filesync.ern`](examples/filesync.ern)** — file synchronization between two nodes. Introduces mutual-address setup and additional runtime references (`Sys.fs`).
- **[`examples/webserver.ern`](examples/webserver.ern)** — HTTP server with sessions. Introduces `foreign fn`, abstract types with signatures, ETS as a foreign process.
- **[`docs/webserver_comparison.md`](docs/webserver_comparison.md)** — the same web server in idiomatic Erlang, for measurement.

### Then, as reference material

- **[`docs/decisions.md`](docs/decisions.md)** — dated design decisions and their rationale. What was tried, what was rejected, why the report says what it says. Not normative — the report wins any conflict. Browse as needed; not intended to be read straight through.

- **[`docs/implementation_plan.md`](docs/implementation_plan.md)** — MVP 1 roadmap. About eight weeks of one-person work in Erlang, with a hand-written parser.

## Ground rules

- **`ernest_report.md` is the single normative document.** Nothing else in this repo overrides it.
- **Appendix A of the report is the grammar.** Any conflict between prose and Appendix A is resolved in favor of Appendix A.
- **Section 0 of the report is the five principles.** They break ties when the design admits options.
- **The decisions log is rationale only.** It's updated when the report is updated. Historical entries are dated and reflect their point in time.
- **Paper programs are illustrative.** They test the report by putting it through real programs. When they surface an anomaly, the report changes first, then the log, then the code.

## Layout of the language

Three layers:

- **Language.** The rules in `ernest_report.md`: syntax, types, processes, evaluation. Small and stable.
- **Prelude.** What the report requires to exist. Small — the built-in types (Address, Reply, Never, plus List, Map, and Set); a handful of declared sum types (Unit, Optional, Either, Ordering, Down, Reason, ClockMsg, RemoteError, Foreign, Where); the built-in functions (self, send, spawn); the process functions (via, Address.call, Address.callForever, answer, remote, parallelRemote, monitor, kill); the operations Ernest's operators resolve to (`Int.+` through `Int.%`, `Float.+` through `Float./`, negation, `String.<>`, `List.<>`, `Int.div`/`Int.mod`, the `.compare` functions, `todo`); and system references (Sys.stdout, Sys.clock).
- **Standard library** (Appendix E). Ordinary Ernest code on the load path by default: Io, List, Map, Set, String, Char, Bool, Int, Float, Optional, Either, Foreign. Grows when a paper program writes the same pattern three times.
