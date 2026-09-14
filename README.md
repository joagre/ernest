# Ernest

A functional language for concurrent programs. Two concepts: pure functions with Hindley-Milner types, and processes with typed mailboxes. On BEAM (Erlang OTP 27).

## Status

Design complete for MVP 1 (single-node subset). Implementation begins with the lexer and parser, in Erlang. The compiler is `ernc`; the runner is `ern`.

## Reading order

### Start here

- **[`docs/ernest.md`](docs/ernest.md)** — the language report. Normative. Everything else in this repo defers to it. About ten pages of prose plus a grammar appendix, a configuration appendix, a foreign-library appendix, and a standard-library appendix.

- **[`docs/ernest-guide.md`](docs/ernest-guide.md)** — a tutorial for a first-time reader. Walks through hello world, types, functions, one process (a counter), two processes talking (ping-pong), the `<-` chaining idiom, and a syntactic-quirks reference. Ends with the five principles.

### Then the paper programs, in this order

- **[`docs/ernest-tick-game.md`](docs/ernest-tick-game.md)** — a snake game with tick-based updates. Introduces `..` record update, `Map` folds, one process per player.
- **[`docs/ernest-repl.md`](docs/ernest-repl.md)** — a read-eval-print loop for a small expression language. Heavy use of `<-`, `try` as a supervised child process, `monitor` for detecting child death.
- **[`docs/ernest-filesync.md`](docs/ernest-filesync.md)** — file synchronization between two nodes. Introduces mutual-address setup and additional ambient runtime references (`Sys.fs`).
- **[`docs/ernest-webserver.md`](docs/ernest-webserver.md)** — HTTP server with sessions. Introduces `foreign fn`, opaque types with signatures, ETS as a foreign process.
- **[`docs/ernest-comparison-webserver.md`](docs/ernest-comparison-webserver.md)** — the same web server in idiomatic Erlang, for measurement.

### Then, as reference material

- **[`docs/ernest-decisions.md`](docs/ernest-decisions.md)** — dated design decisions and their rationale. What was tried, what was rejected, why the report says what it says. Not normative — the report wins any conflict. Browse as needed; not intended to be read straight through.

- **[`docs/ernest-implementation-plan.md`](docs/ernest-implementation-plan.md)** — MVP 1 roadmap. About eight weeks of one-person work in Erlang, with a hand-written parser.

## Ground rules

- **`docs/ernest.md` is the single normative document.** Nothing else in this repo overrides it.
- **Appendix A of the report is the grammar.** Any conflict between prose and Appendix A is resolved in favor of Appendix A.
- **Section 0 of the report is the five principles.** They break ties when the design admits options.
- **The decisions log is rationale only.** It's updated when the report is updated. Historical entries are dated and reflect their point in time.
- **Paper programs are illustrative.** They test the report by putting it through real programs. When they surface an anomaly, the report changes first, then the log, then the code.

## Layout of the language

Three layers:

- **Language.** The rules in `ernest.md`: syntax, types, processes, evaluation. Small and stable.
- **Prelude.** What the report requires to exist. Small — a handful of sum types (Optional, Either, Ordering, Down, Reason, ClockMsg, RemoteError, Foreign), a handful of process functions (via, Address.call, answer, remote, parallelRemote, monitor, kill), a few required operations (Int.div, compare, todo), and system references (Sys.stdout, Sys.stderr, Sys.clock).
- **Standard library** (Appendix E). Ordinary Ernest code on the load path by default: Io, List, Map, Set, Text, Char, Int, Float, Optional, Either, Foreign. Grows when a paper program writes the same pattern three times.
