# Ernest Compiler: Implementation Plan

Target architecture: an Erlang-based compiler, `ernc`, that reads `.ern` files, type-checks them, and produces `.erc` files (BEAM under the hood), and a runner, `ern`, that starts a program or a REPL. One person, about seven working weeks for MVP 1 according to the budget below. The language was called Actorson until 12 September 2026.

**MVP 1 (this plan):** prove the chain parser, types, BEAM, with the report's language, syntax, and semantics unchanged. MVP 1 accepts a subset and checks less: only Int, no ownership rule for opaque types, no foreign code, no `net`. Exhaustiveness checking is in: it is the check that shaped `recv` and `if`, and a first user should not form habits the report forbids. Every program MVP 1 accepts is a valid Ernest program or one the report already says is wrong. One Erlang module per `.ern` file.

Later MVPs at the end of the document.

## Architecture

```
.ern → Parser → AST → Type checker → typed AST → Compiler → Erlang abstract format → compile:forms → .beam → BEAM
```

The compiler is written in Erlang and runs on BEAM. The type checker is the source of truth. The compiler is a mechanical transformation of the typed AST into Erlang's abstract format via `erl_syntax`, and `compile:forms` builds `.beam` in memory. No `.erl` text, no `erlc`. `erl_prettypr` prints the text when debugging. No type checking in the compiler.

All `.ern` files are read; definitions have full names (`Net.Http.parse`) and the compiler builds a global table. One Erlang module per file, functions with the full name as atom (`'Net.Http.parse'/1`); cross-file calls go through the table to the right module. Tail position is preserved: the last expression of a block, a `match` arm, and a `recv` arm becomes the last expression of the clause.

## Phase 1: Type Checker (4 weeks)

**Goal:** read `.ern` files, infer types, output a typed AST.

### 1.1 Parser (3 days)

- Lexer: braces, `;` as separator, whitespace means nothing, `//` and nesting `/* */` comments dropped before parsing. Sixteen reserved words, `true` and `false` among them as literals. The grammar is LL(1): every nonterminal is decided by its first token, and the parser never re-reads. Qualified references (`Net.Http.parse`, `ServerMsg.Get`) are one loop: after an uppercase token, `.` continues, anything else ends.
- The grammar is in Appendix A of the report. The lambda's extent, `fn(x) = e` up to the next delimiter at the same level, is expressed there; the parser tests it. If it fails, lambda bodies must be required in braces. Patterns are parsed by a second small Pratt loop with `+:` as its only infix operator, right-associative, and `as ident` as an optional postfix on the whole.
- Hand-written Pratt parser for expressions; operator precedence is the table. Recursive descent for declarations (`type`, `opaque type ... with { }`, `fn`).
- `let x <- e;` as a binding in a block: parsed as a binding form, rewritten before type inference into `match e { Left(err) -> Left(err) | Right(x) -> <rest of block> }` (or `None`/`Some`); which one is decided by the block's type, so the rewrite happens after the block's return type is inferred, or both are generated and one is chosen at unification. Simplest in MVP 1: `Either` only, `Optional` in MVP 2.
- Block `{ ... }` is an expression form. `match e { P -> e | ... }` and `recv { P -> e | ... | after millis -> e }`, guards with `when`. `if then else`. Calls `f(x, y)`, n-ary functions, no currying: too few arguments is an arity error on the line, with a suggestion of the tuple reading.
- Constructors: no field, one field `T(e)`, or named fields `T(f = e)`; partial patterns `T(f = p)`, base `T(..e, f = e)`. Positional or named is decided by whether `=` or `:` follows the first identifier. Field order from the declaration; compiled to tuples. `fn` definitions allowed in blocks, recursive and generalized; `let` bindings monomorphic.
- AST as Erlang records with line and column on every node.
- Error message with its own text for a function written with two clauses, Haskell-style: "a function has one clause; write match". Three paper programs out of three made the mistake. Its own text also for `f x` where `f(x)` was meant, since that is the first thing a Unison or Haskell reader writes.

**Output:** `ern_ast.erl`, data structures and parser functions.

### 1.2 Type Inference (13 days)

- Hindley-Milner algorithm: W or J. Unification via a substitution register. Function types are n-ary: `(A, B) -> C` is a type with an argument list, not two arrows; unification requires the same length, and a length mismatch is reported as an arity error with a suggestion of the tuple reading. `fn` generalizes, `let` does not.
- Typing environment: `#{var => type}`, generalization with forced parameters.
- Pattern matching is type-checked, with exhaustiveness checking on `match`; `recv` is exempt by the report. Two days. Linearity: a variable at most once per pattern, checked in the type checker, since the grammar cannot.
- The mailbox type as part of the function type, written `-> T with M`: an arrow is `(args, κ, result)` where κ is a type variable of its own kind, unified with `M` by `self`, `recv`, `send`, `spawn`, and foreign calls with a mailbox type, or left free. A free κ at generalization means pure, and pure means polymorphic in the mailbox type: the function can be called anywhere, and its function arguments run in the caller's κ. Two different `M` in one function is a unification error. The only kind of variable outside the textbook; see risk.
- Only Int, Bool, Text, Bytes. `+` is `Int.+`; no name resolution for operators. Float and type-directed resolution are MVP 2. When it comes, it is one post-inference pass that serves three things: operators (`+` to `Int.+` or `Money.+`), `==` (a type error on types containing functions or addresses), and `<-` (`chain(e, fn(p) = rest)` to `Either.andThen` or `Optional.flatMap` by the type of `e`). `/` and `%` on `Int` fault on zero (`badarith` becomes a `Fault`); `Int.div` and `Int.mod` return `Optional(Int)`.

**Code:** `ern_types.erl` for the type representation, `ern_typecheck.erl` for inference.

**Output:** a type checker that takes an AST and returns `{ok, TypedAst, Env}` or `{error, Errors}`.

### 1.3 Opaque Types (1 day)

- `opaque type ... with` is parsed and the signature type-checked against the definitions. The ownership rule (constructor only in the owner set) is MVP 2; in MVP 1 an opaque type is an ordinary type with a signature.

**Output:** a type checker that checks signatures against definitions.

### 1.4 Standard Types (2 days)

- Built-in: `List(a)`, `Map(k, v)`, `Text`, `Int`, `Bool`, `Bytes`, `Optional(a)`, `Either(e, a)`. Structural `==` on all data values; `Int.compare` and `Text.compare`, no universal ordering.
- Address, Never.

**Output:** the prelude in the type checker.

**Test:** counter, ping-pong, opaque stack, Never, a parser with three failing steps over `Either` with `let x <- e`.

---

## Phase 2: Compiler and Runtime (2 weeks)

**Goal:** typed AST → Erlang code that runs on BEAM.

### 2.1 Compiler Architecture (2 days)

- Typed AST → Erlang's abstract format with `erl_syntax`, `erl_syntax:revert`, `compile:forms`.
- Functions become Erlang functions. Blocks become sequences in a function clause; bindings become `=`.
- Processes become recursive functions.
- `send(addr, msg)` becomes `Addr ! Msg`.

**Code:** `ern_compiler.erl`.

**Output:** `.beam` in memory, written to `_build/`.

### 2.2 Processes (3 days)

- `spawn(Local, f)` becomes `erlang:spawn(fun() -> F() end)`; `spawn(Peer(name), f)` and `remote` are MVP 3; `self()` becomes `self()`. Functions with n arguments become Erlang functions of arity n, directly.
- `recv { P -> e | ... }` becomes `receive P -> E; ... end`, and `recv { ... | after T -> e }` becomes `receive ... after T -> E end`. Arms are translated like `match` arms; patterns and guards are Erlang's. No mailbox scanning; what was MVP 2 vanished with the filter function.

**Code:** translation of patterns and guards into Erlang patterns and guards, shared with `match`.

**Output:** processes as recursive Erlang functions with `receive`.

### 2.3 Opaque Types (0 days)

- Nothing to do in MVP 1: an opaque type compiles as an ordinary type, `Stack.push` becomes the function `'Stack.push'/2` in the file's module. Module per type with the signature as export list is MVP 2.

### 2.4 Standard Library (3 days)

- The representation of values on BEAM, the ABI that foreign code sees: `Int` integer, `Float` float, `Text` UTF-8 binary, `Char` integer code point, `Bytes` binary, `Bool` `true | false`, `()` `{}`, tuples tuples, `List(a)` list, a nullary constructor a lowercase atom (`Stop` is `stop`), a single-field constructor `{tag, V}`, named fields `{tag, F1, F2, ...}` in declaration order (`None` is `none`, `Some(v)` is `{some, V}`, `Left`/`Right` `{left, E}`/`{right, V}`), `Address(m)` a pid or `{Node, Pid}`, a function a fun, a `foreign type` value whatever the implementation returns. Erlang functions whose conventions differ (`{ok, V} | {error, R}`) get a wrapper module, as Gleam's `gleam_stdlib.erl`. `List`, `Text`, `Int` as wrappers around Erlang's; `Map` as Erlang's `maps` (structural equality on keys, no ordering). `sort` takes `compare`. Total: `Int.div` and `Int.mod` return `{some, N}` or `none`, `List.head` and `List.at` likewise. No built-in function may let an Erlang exception reach the process, except `/` and `%` on zero, whose `badarith` the runtime turns into `Fault("division by zero")`.
- System processes `stdout` and `clock` are started by the launcher and given to `main` in `Sys`; no named processes. `net` and `fs` are MVP 2, as foreign processes: Erlang modules that speak an Ernest-declared type, connected in the launcher's configuration.
- Launcher: starts the system processes, builds `Sys`, calls `main`; when `main` returns all processes are killed with `ProgramEnd` and the node stops. Deadlock detection (`Deadlock`) is MVP 2: it requires the runtime to know whether all processes are waiting without `after` and no timers are active.

**Output:** `stdlib.erl`, the launcher code.

### 2.5 Code Generation (1 day)

- Module header, export of all top-level functions, `compile:forms` with `[return_errors, debug_info]`, write `.beam`.
- Erlang errors from `compile:forms` are mapped back to Ernest lines via node positions.

**Code:** part of `ern_compiler.erl`.

**Test:** ping-pong, counter with Upgrade, and a pure parser run on BEAM.

---

## Phase 3: Assembly (1 week)

**Goal:** `ernc hello.ern` produces `hello.erc`, and `ern hello.erc` runs it.

### 3.1 Integration (3 days)

- Two escripts. `ernc foo.ern` reads, parses, type-checks, compiles, writes `foo.erc`. `ern [--config-dir <dir>] [-pa <dir> ...] foo.erc` starts the system processes, builds `Sys`, calls `main`; `ern --repl` starts a REPL; `ern --create-config-dir <dir>` creates `<dir>/.ernest/` with `ernest.conf` (JSON: this node's address and public key, an empty peer list) and a private key readable only by the owner, and does nothing else. `--config-dir` defaults to `./.ernest`.
- Error format `file:line:column: text`, one line per error.
- A main module `ern_cli.erl` that orchestrates everything.

**Output:** `ernc` as an escript.

### 3.2 Testing (2 days)

- Three programs in Ernest: ping-pong, counter with Upgrade, a pure parser with Either.
- Compile: `ernc program.ern`. Run: `ern program.erc`.
- Smoke test: every program compiles and runs, output compared against expected.
- The web server and the file sync are MVP 2, when `net` exists.

### 3.3 Documentation (2 days)

- User readme: how to write Ernest, which constructs are supported.
- Internal architecture notes for the next phase.

---

## Tools and Environment

Erlang, OTP 27, Rebar3 to build the compiler itself. EUnit per module; integration tests that run `ernc` on the test programs and compare output against expected. The compiler is distributed as an escript.

---

## Risk and Uncertainty

**The mailbox type.** HM with one mailbox type per arrow is not the textbook. The model: an arrow is a type with three parts (arguments, mailbox type κ, result); κ is a variable unified with `proc(M)` or left free, and a free κ is generalized like any type variable, which is what makes pure functions callable from process code and lets `List.map` run a process lambda. Not a lattice, not row polymorphism: one variable kind. Risk: four days too few if generalization of κ over `let` causes trouble; `let` is monomorphic, so a lambda bound with `let` fixes its κ at first use, which is intended.

**What MVP 1 does not prove.** The ownership rule for opaque types, foreign code, and everything past one node.

---

## Decisions Before Start

Decided: hand-written Pratt parser; Erlang's abstract format via `erl_syntax` and `compile:forms`; OTP 27; error format `file:line:column: text`; one module per file with the file's name.

Nothing open.

---

## Time Budget

| Phase | Parts | Days | Weeks |
|-------|-------|------|-------|
| 1     | Parser, type check, opaque, stdlib types | 19 | 3.8 |
| 2     | Compiler, processes, stdlib, codegen | 9 | 1.8 |
| 3     | Integration, tests, docs | 7 | 1.4 |
| **Total** | | **35** | **7 weeks** |

One person full-time: seven working weeks. Half-time: three to four calendar months.

---

## Later MVPs

**MVP 2 (the whole report on one node), about four weeks:** ownership rule for opaque types with a module per type and the signature as export list (4 days); `Float` with type-directed name resolution interleaved with inference (5 days, and the piece most likely to double, since nobody has written it); `foreign fn` and `foreign type` compiled to direct calls with a catch that turns exceptions into `Fault` (3 days); `net` and `fs` as foreign processes (4 days); `Deadlock` (2 days); the web server as test (3 days). The web server as test, and an `Ets.ern` as the first foreign library, with an `Erl` prelude namespace for what every shim needs: `Erl.atom : (Text) -> Foreign` and `type Erl.Result(v, r) = Ok(v) | Error(r)`, matching `{ok, V} | {error, R}` under the ABI.

**MVP 3 (distribution with content addressing):** every definition gets a hash of its typed AST; modules are named by hash; a registry per node `{Hash -> Module}`. A message with a function carries the hash, and a node that lacks it fetches the code from the sender. `spawn(Peer(name), f)` and `remote(f)` over the peers in `ernest.conf`, authenticated with the configured keys; `remote` picks among peers flagged `"remote-peer": true` by load, criterion to be chosen then. Erlang's module distribution is not used.

**MVP 4 (optimizations):** selective receive with a ring buffer instead of list scanning. Erlang side: `process_flag(priority, ...)` and scheduling hints.

**MVP 5 (ecosystem):** HTTP server, JSON, database connectors written in Ernest. A standard library in Ernest, not just Erlang wrappers.

MVP 1 is seven working weeks and shows that the chain holds, not that the design holds. The latter is decided beforehand, on paper.
