# Ernest Compiler: Implementation Plan

Target architecture: an Erlang-based compiler, `ernc`, that reads `.ern` files, type-checks them, and produces `.erc` files (BEAM under the hood), and a runner, `ern`, that starts a program or a REPL. One person, about eight working weeks for MVP 1 according to the budget below. The language was called Actorson until 12 September 2026.

**MVP 1 (this plan):** prove the chain parser, types, BEAM, with the report's language, syntax, and semantics unchanged. MVP 1 accepts a subset and checks less: `Int` but no `Float`, no ownership rule for abstract types, no foreign code, no `net`, no distribution — `spawn(Peer, ...)` and `remote` are MVP 3. Exhaustiveness checking is in: it is the check that shaped `receive` and `if`, and a first user should not form habits the report forbids. Every program MVP 1 accepts is a valid Ernest program or one the report already says is wrong. One Erlang module per `.ern` file.

Later MVPs at the end of the document.

## Architecture

```
.ern → Parser → AST → Type checker → typed AST → Compiler → Erlang abstract format → compile:forms → .beam → BEAM
```

The compiler is written in Erlang and runs on BEAM. The type checker is the source of truth. The compiler is a mechanical transformation of the typed AST into Erlang's abstract format via `erl_syntax`, and `compile:forms` builds `.beam` in memory. No `.erl` text, no `erlc`. `erl_prettypr` prints the text when debugging. No type checking in the compiler.

All `.ern` files are read; definitions have full names (`Net.Http.parse`) and the compiler builds a global table. One Erlang module per file, functions with the full name as atom (`'Net.Http.parse'/1`); cross-file calls go through the table to the right module. Tail position is preserved: the last expression of a block, a `match` clause, and a `receive` clause becomes the last expression of the emitted Erlang clause.

## Repository Layout

Standard Erlang application layout under `lib/`, one application per compiler stage: `lib/lexer`, `lib/parser`, `lib/type_system`, `lib/utils` (vendored `getopt`), each with `src/`, `include/`, `ebin/`, `test/`. Phases 2 and 3 add `lib/compiler`, `lib/runtime`, and `lib/cli`. Module names carry the `ern_` prefix, since Erlang's module namespace is flat. `stdlib/` holds the Ernest standard library as a source root, so `stdlib/io.ern` is `Io`. `examples/` holds the paper programs and the small programs from the report and the guide; `bin/` holds `ernc` and `ern`. Build: a generic `src/Makefile` per application compiling into `../ebin` with `erlc -MMD` header tracking, and a top-level `Makefile` that runs them; `make test` runs EUnit. No rebar3, no OTP behaviours.

## Phase 1: Type Checker (4 weeks)

**Goal:** read `.ern` files, infer types, output a typed AST.

### 1.1 Parser (3 days)

- Lexer, hand-written (not leex: `/* */` nests and `///` blocks must be joined). Braces, `;` as separator, whitespace means nothing, `//` and `/* */` dropped. Seventeen reserved words, `true` and `false` among them as literals; `export` marks cross-module visibility. Tokens are plain tuples in yecc's shape, `{Category, {Line, Col}, Value}` and `{Symbol, {Line, Col}}`, with no parser fields. Every nonterminal is decided by its first token, and the parser never re-reads. Three spots need one more token: the constructor-fields peek documented in Appendix A (`T(ident =` vs `T(ident :` vs `T(expr`), the FnType-vs-ParenType decision (parse the parenthesized type list, then look for `->`), and `fn` followed by an identifier (declaration) or `(` (lambda). No backtracking. Qualified references (`Net.Http.parse`, `ServerMsg.Get`, `Int.+`) are one loop: after an uppercase token, `.` continues, anything else ends; an operator as the final segment must be a `userop` and must be qualified.
- The grammar is in Appendix A of the report. The lambda's extent, `fn(x) = e` up to the next delimiter at the same level, is expressed there; the parser tests it. If it fails, lambda bodies must be required in braces. Patterns are parsed by a second small Pratt loop with `::` as its only infix operator, right-associative, and `as ident` as an optional postfix on the whole.
- Expressions: a direct precedence-climbing loop over the token list, threading `{Node, RestTokens}`; the operator table is §2.6's. No generic Pratt engine and no yecc: the hand parser is the executable test of principle 4, and the two mandated diagnostics below need it. Recursive descent for declarations (`type`, `abstract type ... with { }`, `fn`, `let`, `foreign`). Error messages in the `Expected 'a', 'b' or 'c' instead of X` style, prefixed `file:line:column:`.
- `let x <- e;` as a binding in a block: parsed as a binding form, rewritten before type inference into `match e { Left(err) -> Left(err) | Right(x) -> <rest of block> }` (or `None`/`Some`); which one is decided by the block's type, so the rewrite happens after the block's return type is inferred, or both are generated and one is chosen at unification. Simplest in MVP 1: `Either` only, `Optional` in MVP 2.
- Block `{ ... }` is an expression form. `match e { P -> e | ... }` and `receive { P -> e | ... | after millis -> e }`, guards with `when`. `if then else`. Calls `f(x, y)`, n-ary functions, no currying: too few arguments is an arity error on the line, with a suggestion of the tuple reading.
- Constructors: no field, one field `T(e)`, or named fields `T(f = e)`; partial patterns `T(f = p)`, base `T(..e, f = e)`. Positional or named is decided by whether `=` or `:` follows the first identifier. Named fields in canonical (field-name) order, report §3.5; compiled to tuples. `fn` definitions allowed in blocks, recursive and generalized; `let` bindings monomorphic.
- AST as Erlang records with line and column on every node.
- Error message with its own text for a function written with two clauses, Haskell-style: "a function has one clause; write match". Three paper programs out of three made the mistake. Its own text also for `f x` where `f(x)` was meant, since that is the first thing a Unison or Haskell reader writes; for a trailing `;` before `}` ("a block ends with an expression"); for `if` without `else`; and for `let p <- e` at top level ("`<-` is a block form").
- Doc comments. `///` to end of line, consecutive `///` lines form a doc block, attached to the following declaration when there is no blank line between. Lexer emits a doc-comment token; parser records the joined block as an optional field on the declaration's AST node. Approximately 0.5 days.

**Output:** `lib/lexer/src/ern_lexer.erl`, `lib/parser/src/ern_parser.erl`, AST records in `lib/parser/include/ern_ast.hrl`.

### 1.2 Type Inference (13 days)

- Hindley-Milner algorithm: W or J. Unification via a substitution register. Function types are n-ary: `(A, B) -> C` is a type with an argument list, not two arrows; unification requires the same length, and a length mismatch is reported as an arity error with a suggestion of the tuple reading. `fn` generalizes, `let` does not.
- Typing environment: `#{var => type}`, generalization with forced parameters.
- Pattern matching is type-checked, with exhaustiveness checking on `match`; `receive` is exempt by the report. Two days. Uniqueness: a variable at most once per pattern, checked in the type checker, since the grammar cannot. Also checked there: type and constructor names unique within a module (a module may shadow prelude names, §4.2); under `Never`, a `receive` with only an `after` clause is legal and any pattern clause is a type error (§6.8).
- Reply-carrying types (report §6.6). A type is reply-carrying if it is `Reply(a)` or transitively contains one. Reply-carrying values are linear: at each binding site (function parameter, receive-bound variable, spawn-lambda capture, pattern-bound field, or the result of a call whose return type is reply-carrying), every path from the binding must consume the value exactly once, by one of: `answer`, passing to a function whose parameter is reply-carrying, sending with `send`, placing into a constructor or tuple of reply-carrying type, returning from a function whose declared return type is reply-carrying, or capturing in a spawn-lambda. Pattern-match on a reply-carrying scrutinee transfers the obligation to its pattern-bound reply-carrying fields; a nullary case discharges the obligation; a `let` transfers it to the variables it binds; an `if`, `match`, `receive`, or block with a reply-carrying value carries the obligation to where that value is bound or consumed. The check is compositional per function definition; compiled interfaces carry the obligation. `Address.call`'s `mk` callback is the canonical case: its `Reply` parameter is consumed by placement into the reply-carrying message it returns, and the returned value's obligation is discharged by `Address.call`'s runtime. MVP 1 restriction: when a spawn-lambda captures a reply-carrying value, the spawn's second argument must be a direct `fn() = ...` at the call site (no `let`-bound intermediate), so the checker does not have to follow function values around. Approximately 5 days.
- The mailbox effect as part of the function type, report §3.9: the arrow constructor has three parameters — arguments, effect, result — represented `Arrow(args, E, result)`. The effect slot holds one of three things: the distinguished value `pure`, a mailbox type, or an effect variable. An annotation without `with` puts `pure` in the slot; an annotation `with M` puts `M`; an unannotated function gets a fresh effect variable. Unification is component-wise. An effect variable unifies with anything; `pure` unifies only with `pure` or an unrestricted variable; two different mailbox types, or a mailbox type against `pure`, is a type error. An effect variable is *process-only* when it also occurs in a value position (`self : () -> Address(m) with m`) or belongs to a process primitive (`send`, `spawn`, `Address.call`, `answer`, `monitor`, `kill`, `remote`, and foreign functions declared `with M`); a process-only variable does not unify with `pure`, and the flag is part of the type scheme. A free effect variable at generalization is generalized like any other, which is effect polymorphism: `List.map` runs a pure or a process callback in the caller's process. The only departure from textbook HM is `pure` as a non-type value in the slot and the process-only flag.
- Base types `Int`, `Bool`, `Char`, `String`, `Bytes`, `Unit`; no `Float`. `+` is `Int.+`; no name resolution for operators. Float and type-directed resolution are MVP 2. When it comes, it is one post-inference pass that serves four things: the `userop` operators (`+` to `Int.+` or `Money.+`), `==` (a type error on types containing functions or addresses), `<`, `<=`, `>`, `>=` (to the operand type's `compare`, a type error without one), and `<-` (`chain(e, fn(p) = rest)` to `Either.andThen` or `Optional.andThen` by the type of `e`). `/` and `%` on `Int` fault on zero (`badarith` becomes a `Fault`); `Int.div` and `Int.mod` return `Optional(Int)`.

**Code:** `ern_types.erl` for the type representation, `ern_typecheck.erl` for inference.

**Output:** a type checker that takes an AST and returns `{ok, TypedAst, Iface, Env}` or `{error, Errors}`.

Local `fn`s in a block are generalized only once every later local `fn` they reference, transitively, is checked; until then they are monomorphic, as any recursive reference is. Generalizing at the definition would close the scheme over variables a later `fn` still pins, and accept `a("s")` for `fn a(x) = b(x); fn b(x) = x + 1`.

### 1.3 Abstract Types (1 day)

- `abstract type ... with` is parsed and the signature type-checked against the definitions. The ownership rule (constructor only in the owner set) is MVP 2; in MVP 1 an abstract type is an ordinary type with a signature.

**Output:** a type checker that checks signatures against definitions.

### 1.4 Standard Types (2 days)

- Built-in: `Int`, `Bool`, `String`, `Bytes`, `Char`, `Unit`, `List(a)`, `Map(k, v)`, `Optional(a)`, `Either(e, a)`. Structural `==` on all data values; `Int.compare` and `String.compare`, no universal ordering.
- `Address(m)`, `Reply(a)`, `Never`.

**Output:** the prelude in the type checker.

**Test:** `examples/counter.ern`, `examples/counter_upgrade.ern`, `examples/ping_pong.ern`, `examples/stack.ern`, `examples/hello.ern`, and a parser with three failing steps over `Either` with `let x <- e`.

---

## Phase 2: Compiler and Runtime (2 weeks)

**Goal:** typed AST → Erlang code that runs on BEAM.

**Order of work, with status.** (1) The runtime `ern_rt` and the hand-written target modules `test/target/{hello,counter}.erl`, run by the runtime's tests: done 2026-09-17. (2) Two tables in 2.1 below, decided before any emitter code: every record of `ern_ast.hrl` to its Erlang shape, and every prelude name of report §9.4 to §9.6 to what is emitted for it; with a test asserting that the AST record tags occurring in `examples/` equal the tags declared in `ern_ast.hrl`, minus `e_bits` and `p_bits` until MVP 2, so the examples corpus exercises every construct the emitter must handle. (3) The three pre-passes, (4) the emitter `lib/compiler/src/ern_compiler.erl`, golden-tested against the target modules, and (5) the stdlib modules of Appendix E as Erlang: done 2026-09-17, one traversal doing the pre-passes on the way. (6) Every MVP 1 example compiles and runs under the compiler's tests; the `ernc` and `ern` programs and the integration tests of 3.2 remain.

### 2.1 Compiler Architecture (2 days)

- Two tables, decided before the emitter was written and kept as its specification. Values follow report §8.4 throughout.

  **AST record to Erlang.** Types are erased: `type_decl`, `abstract_decl`, `foreign_type_decl`, `signature`, `field`, and the `t_*` records produce no code; the interface chunk carries them.

  | Record | Erlang |
  |---|---|
  | `constructor` | nullary: the quoted atom; positional: `{'C', V}`; named: `{'C', V1, ..., Vn}` in canonical field order |
  | `fn_decl`, top level | a function clause; exported if `export`; a type member is `'Stack.push'` |
  | `fn_decl`, in a block | lifted to a module function with its free variables as leading parameters; the name is bound to a closure over them |
  | `let_decl` | `name/0`, reading a value the module's `'$init'/0` computed once in dependency order before `main` (§8.5) |
  | `foreign_fn_decl` | MVP 2: a clause calling the named `M:F/A` |
  | `param` | the pattern in the clause head |
  | `e_lit` | integer, float, or char literal; string as a binary; bool as an atom |
  | `e_var` | a local: the Erlang variable; a top-level fn as a value: `fun f/N`; a top-level let: `name()`; a prelude name: table below |
  | `e_con` | as `constructor`; a single-positional constructor as a value: `fun(V) -> {'C', V} end` |
  | `field_set` | its value at its canonical position |
  | `e_tuple`, `e_list` | tuple, list |
  | `e_bits`, `bit_seg` | MVP 2: bit syntax |
  | `e_block` | a sequence; `binding` with `=` as `Pat = Expr`; `binding` with `<-` as a `case` on `Left`/`Right` or `None`/`Some` with the rest of the block in the second clause (§5.5) |
  | `e_call` | `F(Args)` for a local; `f(Args)` or `'ernest@m':f(Args)` for a known function; a prelude name: table below |
  | `e_neg` | `-E` |
  | `e_binop` | `Int`: `+ - * div rem` (`/` is `div`, `%` is `rem`; a zero divisor's `badarith` becomes `Fault("division by zero")` in the runtime); `<>`: binary append for `String` and `Bytes`, `++` for `List`; `==`, `!=`: `=:=`, `=/=`; `<`, `<=`, `>`, `>=` on `Int`, `Float`, `Char`, `String`: the native operators, since binaries compare by code point; `&&`, `||`: `andalso`, `orelse`; `::`: `[H \| T]` |
  | `e_lambda` | `fun(Pats) -> Body end` |
  | `e_if` | `case C of true -> T; false -> E end` |
  | `e_match`, `clause` | `case`; a clause whose guard is not an Erlang guard expression falls through by a continuation: `Rest = fun() -> <remaining clauses> end` and `case G of true -> B; false -> Rest() end`, so no code is duplicated |
  | `e_receive`, `after_clause` | `receive ... after T -> B end`; guards: see 2.2 |
  | `p_wild`, `p_var`, `p_lit` | `_`, a variable, a literal (a string as a binary) |
  | `p_con`, `field_pat` | as `constructor`, an omitted named field as `_` |
  | `p_tuple`, `p_list`, `p_cons` | tuple, list, `[H \| T]` |
  | `p_as` | `Var = Pat` |
  | `p_bits` | MVP 2 |

  **Prelude name to Erlang** (report §9.4 to §9.7, Appendix E). Called, or taken as a value with `fun M:F/A`.

  | Name | Erlang |
  |---|---|
  | `self` | `ern_rt:self/0` |
  | `send`, `answer`, `via`, `monitor`, `kill` | `ern_rt:send/2`, `answer/2`, `via/2`, `monitor/2`, `kill/1` |
  | `spawn` | `ern_rt:spawn/3`, the third argument the spawn site for `Down` (§6.9) |
  | `Address.call`, `Address.callForever` | `ern_rt:call/3`, `call_forever/2` |
  | `remote`, `parallelRemote` | MVP 3; until then `ern_rt:remote/1` answers `Left(NoRemotePeer)` |
  | `Int.+` and the other `userop`s on `Int`, `Int.negate` | the inline operators above |
  | `Float.*` | MVP 2, inline |
  | `String.<>`, `List.<>`, `Bytes.<>` | inline as above |
  | `Int.div`, `Int.mod`, `*.compare`, `Int.toString`, ... | `'ernest@int':'div'/2` and so on: the namespace's module |
  | `todo` | `ern_rt:fault(<<"todo: ...">>)` |
  | `Sys.stdout`, `Sys.clock` | `ern_rt:sys(stdout)`, `ern_rt:sys(clock)` |
  | `Io.*`, `List.*`, ... | `'ernest@io':println/1` and so on |

- Typed AST → Erlang's abstract format with `erl_syntax`, `erl_syntax:revert`, `compile:forms`.
- Three passes on the typed AST first: unique variable names, since Ernest shadows and Erlang does not; lambda lifting of local `fn`s to module-level functions with their free variables as leading parameters, which handles self- and mutual recursion uniformly; and the `<-` desugaring of report §5.5, choosing Either or Optional from the type the checker left on the node. The checker returns its environment so the compiler has the layouts of private types.
- Functions become Erlang functions. Blocks become sequences in a function clause; bindings become `=`.
- Processes become recursive functions.
- `send(addr, msg)` becomes `Addr ! Msg`.

**Code:** `ern_compiler.erl`.

**Output:** `.beam` in memory, written to `_build/`.

### 2.2 Processes (3 days)

- `spawn(Local, f)` becomes `erlang:spawn(fun() -> F() end)`; `spawn(Peer(name), f)` and `remote` are MVP 3; `self()` becomes `self()`. Functions with n arguments become Erlang functions of arity n, directly.
- `receive { P -> e | ... }` becomes `receive P -> E; ... end`, and `receive { ... | after T -> e }` becomes `receive ... after T -> E end`; an `after`-only receive becomes `receive after T -> E end`. `monitor` is `erlang:monitor/2`, which already delivers at once for a dead target (§6.9); `kill` is `exit/2`, asynchronous as §6.9 says. Clauses are translated like `match` clauses. **Omission, 2026-09-17:** report §5.9 allows any pure `Bool` expression as a guard, but BEAM tests a receive guard before taking the message and so admits only Erlang guard expressions. In MVP 1 a `receive` guard must be a comparison, or `&&`/`||` of comparisons, over pattern variables, enclosing variables, and literals; anything else is a compile-time error naming §5.9 and MVP 4, which lifts the restriction. `match` guards are general from the start, by the continuation in 2.1. No mailbox scanning in MVP 1.

**Code:** translation of patterns and guards into Erlang patterns and guards, shared with `match`.

**Output:** processes as recursive Erlang functions with `receive`.

### 2.3 Abstract Types (0 days)

- Nothing to do in MVP 1: an abstract type compiles as an ordinary type, `Stack.push` becomes the function `'Stack.push'/2` in the Erlang module compiled from the Ernest module that defines it. One Erlang module per type with the signature as export list is MVP 2.

### 2.4 Standard Library (3 days)

- The representation of values on BEAM, the ABI that foreign code sees: `Int` integer, `Float` float, `String` UTF-8 binary, `Char` integer code point, `Bytes` binary, `Bool` `true | false`, tuples tuples, `List(a)` list, a nullary constructor the quoted atom of its name (`Stop` is `'Stop'`, `Unit` is `'Unit'`), a single-field constructor `{'Tag', V}`, named fields `{'Tag', F1, F2, ...}` in canonical field-name order (`None` is `'None'`, `Some(v)` is `{'Some', V}`, `Left`/`Right` `{'Left', E}`/`{'Right', V}`), as report §8.4, `Address(m)` a pid, `Reply(a)` a process alias (2.4), a function a fun, a `foreign type` value whatever the implementation returns. Erlang functions whose conventions differ (`{ok, V} | {error, R}`) get a wrapper module, as Gleam's `gleam_stdlib.erl`. `List`, `String`, `Int` as wrappers around Erlang's; `Map` as Erlang's `maps` (structural equality on keys, no ordering). `sort` takes `compare`. Total: `Int.div` and `Int.mod` return `{'Some', N}` or `'None'`, `List.head` and `List.at` likewise. No built-in function may let an Erlang exception reach the process, except `/` and `%` on zero, whose `badarith` the runtime turns into `Fault("division by zero")`.
- **The three layers.** Language (built-ins), prelude (always imported, minimal — report §9), stdlib (default on the load path — report Appendix E). A namespace is an Erlang module named by its path with `@` for `/` and the prefix `ernest@` (`ernest@net@http`, `ernest@list`), as Gleam names `gleam@list`: lowercase, one-to-one with the path since a segment never contains `@`, compilable by `erlc` from a file of the same name, and never a bare name in the BEAM's flat module namespace (rejected the same day: bare `'Io'`, which claims a name any BEAM library might want, and `'Ernest.Io'`, which `erlc` cannot compile from a lowercase file without a forms-compiling build step); functions keep their local names and type members their prefix (`'Stack.push'/2`). MVP 1 ships the prelude and Appendix E signatures as the checker's tables (`ern_prelude`) and the stdlib modules the test programs use (`Io`, `Int`, `List`, `String`, `Char`, `Optional`, `Either`) as hand-written Erlang modules `ernest@io`, `ernest@int`, ... in `lib/runtime/src/ernest@io.erl` and so on, exporting Appendix E under the ABI, since Ernest source for them needs `foreign fn`, which is MVP 2. Generated code calls `ernest@list:map/2` the same way whether the module is Erlang or Ernest, so rewriting a stdlib module in Ernest later changes nothing for callers. `Io.print`/`println` send to `Sys.stdout`; `Sys.stdout` and `Sys.clock` are top-level values the launcher wires per-node (report §8). A module's `#iface{}` is stored in its `.erc` as an extra BEAM chunk, readable with `beam_lib` without loading, together with a hash of the module's source and, per dependency, the hash of the interface it was compiled against; `ernc` recompiles a module when its own hash or a dependency's current interface hash differs from what is recorded (report §11.1), so a body-only edit never cascades. For the hashes to mean anything an interface must be canonical: quantified type variables renumbered in order of appearance, and sorted lists rather than maps. The dependency graph comes from a parse-only scan of the qualified names in each source; a cycle is reported as §11.1 requires.
- System processes `stdout` and `clock` are started by the launcher, and their addresses are bound to the `Sys.*` top-level references (report §8); no named processes. `net` and `fs` are MVP 2, as foreign processes: Erlang modules that speak an Ernest-declared type, connected in the launcher's configuration and exposed under names like `Sys.fs`.
- Runtime, `ern_rt`: every `Address` is a pid. `via` and `monitor` each spawn a proxy process, so `send` is `!`, `self()` is `self()`, and a generated `receive` never sees a foreign message shape. `Reply(a)` is a process alias made with `alias([reply])`, which deactivates after the first answer; `unalias` after a timeout drops late ones, which is report §6.6 for free. The runtime wraps every process body so an exception becomes an exit reason the monitor proxy turns into `Down(reason = Fault(...), function = ...)`; `badarith` maps to `Fault("division by zero")`; a compiled `badarith` carries no operands, so the `Float` operators of §7.4 are functions of `ernest@float` that catch it and fault with `Fault("float arithmetic error")`, and the emitter calls them when `Float` arrives in MVP 2.
- Launcher: starts the system processes, binds their addresses to the `Sys.*` top-level references, calls `main()`; when `main` returns all *local* processes are killed with `ProgramEnd` and the node stops (remote workers on peers survive under their own runtime; this only matters from MVP 3 when peers exist). If `main`'s declared mailbox is polymorphic (`with m`), the runtime instantiates it to `Never`. Deadlock detection (`Deadlock`) is MVP 2: it requires the runtime to know whether all processes are waiting without `after` and no timers are active.

**Output:** `launcher.erl` and the Erlang wrapper modules that the stdlib primitives call; `stdlib/*.ern` for the Ernest-facing surface.

### 2.5 Code Generation (1 day)

- Module header, export of all top-level functions, `compile:forms` with `[return_errors, debug_info]`, write `.beam`.
- Erlang errors from `compile:forms` are mapped back to Ernest lines via node positions.

**Code:** part of `ern_compiler.erl`.

**Test:** `examples/ping_pong.ern`, `examples/counter_upgrade.ern`, and a pure parser run on BEAM.

---

## Phase 3: Assembly (1 week)

**Goal:** `ernc hello.ern` produces `hello.erc`, and `ern hello.erc` runs it.

### 3.1 Integration (3 days)

- Two escripts, `bin/ernc` and `bin/ern`, committed as escript source files whose `%%!` line puts `lib/*/ebin` on the code path; no escriptize step and no build product under `bin/`. `ernc foo.ern` reads, parses, type-checks, compiles, writes `foo.erc`. `ern [--config-dir <dir>] [--load-path <dir> ...] foo.erc` starts the system processes, binds their addresses to the `Sys.*` top-level references, calls `main()`; `ern --repl` starts a REPL; `ern --create-config-dir <dir>` creates `<dir>/.ernest/` with `ernest.conf` (JSON: this node's address and public key, an empty peer list) and a private key readable only by the owner, and does nothing else. `--config-dir` defaults to `./.ernest`.
- Error format `file:line:column: text`, one line per error.
- `lib/cli/src/ern_cli.erl` orchestrates everything; the escripts are thin.

**Output:** `bin/ernc` and `bin/ern`.

### 3.2 Testing (2 days)

- The MVP 1 programs under `examples/`: `hello`, `counter`, `counter_upgrade`, `ping_pong`, `stack`, plus a pure parser with `Either`. The list is explicit in the Makefile; the other examples need later MVPs and are not built.
- Compile: `ernc program.ern`. Run: `ern program.erc`.
- These are the tests for the runtime sections of the report, §6.4, §6.5, §6.9, §6.10, §7, §8, §11.2, §11.3, which no unit test cites; `make sections` lists the sections still without a citing test.
- Smoke test in a top-level `test/`: every listed program compiles and runs, output compared against an expected-output file of the same name. The comparison treats output as a multiset of lines, since the interleaving of prints from different processes (ping-pong) is scheduling-dependent.
- The web server and the file sync are MVP 2, when `net` exists.

### 3.3 Documentation (3 days)

- User readme: how to write Ernest, which constructs are supported.
- Internal architecture notes for the next phase.
- `ernc --doc file.ern` walks the AST, groups doc comments by declaration, and writes Markdown to stdout. Approximately 1 day.

### 3.4 Type error placement (2 days)

Hindley-Milner reports a mismatch where unification fails, which is the second use of a variable, not necessarily the wrong one, and shows two whole types where the reader wants the difference. The checker already anchors every unification to a node with a context sentence, unifies annotated shapes before bodies, and resolves operators, `<-`, exhaustiveness, and replies with their own messages. The remaining fix is bidirectional checking at annotated boundaries: wherever an expected type is known, push it down into the expression instead of inferring up. A function body against its declared return type, each argument against the parameter type of a known callee, branches after the first, annotated `let`s, constructor fields. The mismatch then surfaces at the leaf, naming the expectation: "expected Int here, because `f` is declared to return Int". An optional expected-type argument to `infer`, not a rewrite. With it: effect errors name the primitive and the annotation that made the caller pure, and messages print only the differing part of two large types. Done after the first programs run end to end, since real mistakes are the only good test of messages; the checker's tests pin current positions and wording.

---

## Tools and Environment

Erlang, OTP 27, Makefiles (see Repository Layout); no rebar3, no OTP behaviours. EUnit per module under `lib/*/test`; integration tests under `test/` run `ernc` on the example programs and compare output against expected. The compiler is distributed as the escript sources in `bin/`.

---

## Risk and Uncertainty

**The mailbox effect.** HM with an effect slot per arrow is a small extension of the textbook, but not zero: the slot admits `pure`, which is not a type, and effect variables carry a process-only flag (§1.2, report §3.9). Unification is component-wise; a free effect variable is generalized like any other, which lets `List.map` run a process lambda. No wrapping type constructor, no rows, no effect system beyond the slot. Risk: `let`-bound lambdas fix their mailbox slot at first use (standard let-monomorphism, but easy to trip on if generalization gets attached to `let` by accident); and every arrow in the AST must carry a mailbox slot from day one, including arrows that look pure, so that higher-order pure functions like `List.map` accept process callbacks without a special case.

**What MVP 1 does not prove.** The ownership rule for abstract types, foreign code, and everything past one node.

---

## Decisions Before Start

Decided: hand-written lexer and a direct precedence-climbing parser over a token list (no yecc, no generic Pratt engine, decided 2026-09-17); yecc-shaped tokens; Erlang's abstract format via `erl_syntax` and `compile:forms`; OTP 27; Makefiles, no rebar3, no OTP behaviours; the `lib/` layout above; error format `file:line:column: text`; one Erlang module per Ernest module, named after it.

Nothing open.

---

## Time Budget

| Phase | Parts | Days | Weeks |
|-------|-------|------|-------|
| 1     | Parser, type check, abstract, stdlib types | 24.5 | 4.9 |
| 2     | Compiler, processes, stdlib, codegen | 9 | 1.8 |
| 3     | Integration, tests, docs, error placement | 10 | 2.0 |
| **Total** | | **43.5** | **8.7 weeks** |

One person full-time: about eight and two thirds working weeks. Half-time: three to four calendar months.

---

## Later MVPs

**MVP 2 (the whole report on one node), about four weeks:** ownership rule for abstract types with a module per type and the signature as export list (4 days); `Float` (finite IEEE 754 doubles per §3.1; arithmetic that would produce a non-finite result faults) with type-directed name resolution interleaved with inference (5 days, and the piece most likely to double, since nobody has written it); `foreign fn` and `foreign type` compiled to direct calls with a catch that turns exceptions into `Fault` (3 days); bitstrings (4 days: lexer tokens `<<` and `>>`, `BitExpr` and `BitPat` in the grammar, specifier list, type checking against `Bytes`, direct compilation to BEAM's bit syntax so the runtime's mature optimizer handles prefix-heavy protocol matches); `net` and `fs` as foreign processes (4 days); `Deadlock` (2 days); the web server as test (3 days). The web server as test, and an `Ets.ern` as the first foreign library, with an `Erl` stdlib module for what every shim needs: `Erl.atom : (String) -> Foreign` and `type Erl.Result(v, r) = Ok(v) | Error(r)`. Under the ABI `Ok(v)` is `{'Ok', v}`, not `{ok, V}`, so an Erlang-side helper rewrites `{ok, V} | {error, R}` into the declared shape, as report Appendix D and guide §7.5 describe.

**MVP 3 (distribution with content addressing):** every definition gets a hash of its typed AST; modules are named by hash; a registry per node `{Hash -> Module}`. A message with a function carries the hash, and a node that lacks it fetches the code from the sender. `spawn(Peer(name), f)` and `remote(f)` over the peers in `ernest.conf`, authenticated with the configured keys; `remote` picks among peers flagged `"remote-peer": true` by load, criterion to be chosen then. Erlang's module distribution is not used.

**MVP 4 (optimizations and general receive guards):** a runtime-managed mailbox, a ring buffer the runtime fills from the BEAM mailbox and scans with compiled clause functions in arrival order, which lifts the MVP 1 restriction on `receive` guards (2.2) and makes selective receive independent of BEAM's; every `receive` pays for it, which is the price of §5.9's general guards. Erlang side: `process_flag(priority, ...)` and scheduling hints.

**MVP 5 (ecosystem):** HTTP server, JSON, database connectors written in Ernest. A standard library in Ernest, not just Erlang wrappers.

MVP 1 is about eight and two thirds working weeks and shows that the chain holds, not that the design holds. The latter is decided beforehand, on paper.
