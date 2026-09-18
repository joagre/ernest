# Ernest Compiler: Implementation Plan

Target architecture: an Erlang-based compiler, `ernc`, that reads `.ern` files, type-checks them, and produces `.erc` files (BEAM under the hood), and a runner, `ern`, that starts a program, with a shell on request. One person, about nine working weeks for MVP 1 according to the budget below. The language was called Actorson until 12 September 2026. MVP 1 is done, 2026-09-18, tag `mvp1`; the current phase is MVP 2 under "Later MVPs", in the order written there.

**MVP 1 (done):** prove the chain parser, types, BEAM, with the report's language, syntax, and semantics unchanged. MVP 1 accepts a subset and checks less: `Int` but no `Float`, no ownership rule for abstract types, no foreign code, no `net`, no distribution — `spawn(Peer, ...)` and `remote` are MVP 3. Exhaustiveness checking is in: it is the check that shaped `receive` and `if`, and a first user should not form habits the report forbids. Every program MVP 1 accepts is a valid Ernest program or one the report already says is wrong. One Erlang module per `.ern` file.

Later MVPs at the end of the document.

## Architecture

```
.ern → Parser → AST → Type checker → typed AST → Compiler → Erlang abstract format → compile:forms → .beam → BEAM
```

The compiler is written in Erlang and runs on BEAM. The type checker is the source of truth. The compiler is a mechanical transformation of the typed AST into Erlang's abstract format via `erl_syntax`, and `compile:forms` builds `.beam` in memory. No `.erl` text, no `erlc`. `erl_prettypr` prints the text when debugging. No type checking in the compiler.

All `.ern` files are read; definitions have full names (`Net.Http.parse`) and the compiler builds a global table. One Erlang module per file, functions with the full name as atom (`'Net.Http.parse'/1`); cross-file calls go through the table to the right module. Tail position is preserved: the last expression of a block, a `match` clause, and a `receive` clause becomes the last expression of the emitted Erlang clause.

## Repository Layout

The layout and the build are the README's. Decided here: one Erlang application per compiler stage under `lib/`, so a stage can be tested alone; module names with the `ern_` prefix, since Erlang's module namespace is flat; a generic `src/Makefile` per application with `erlc -MMD` header tracking and a top-level `Makefile` that runs them; no rebar3, no OTP behaviours; the standard library as Erlang under `lib/runtime/src` until MVP 2.5, then Ernest source under `stdlib/`, so `stdlib/io.ern` is `Io`.

## Phase 1: Type Checker (4 weeks)

**Goal:** read `.ern` files, infer types, output a typed AST.

### 1.1 Parser (3 days)

- Lexer, hand-written (not leex: `/* */` nests and `///` blocks must be joined). Braces, `;` as separator, whitespace means nothing, `//` and `/* */` dropped. Seventeen reserved words, `true` and `false` among them as literals; `export` marks cross-module visibility. Tokens are plain tuples in yecc's shape, `{Category, Pos, Value}` and `{Symbol, Pos}`, with no parser fields; `Pos` is `{Line, Col, End, Before}`, the token's end and the end of the token before it, since 2026-09-18, so the parser can close every node's span (3.4). Every nonterminal is decided by its first token, and the parser never re-reads. Three spots need one more token: the constructor-fields peek documented in Appendix A (`T(ident =` vs `T(ident :` vs `T(expr`), the FnType-vs-ParenType decision (parse the parenthesized type list, then look for `->`), and `fn` followed by an identifier (declaration) or `(` (lambda). No backtracking. Qualified references (`Net.Http.parse`, `ServerMsg.Get`, `Int.+`) are one loop: after an uppercase token, `.` continues, anything else ends; an operator as the final segment must be a `userop` and must be qualified.
- The grammar is in Appendix A of the report. The lambda's extent, `fn(x) = e` up to the next delimiter at the same level, is expressed there; the parser tests it. If it fails, lambda bodies must be required in braces. Patterns are parsed by a second small Pratt loop with `::` as its only infix operator, right-associative, and `as ident` as an optional postfix on the whole.
- Expressions: a direct precedence-climbing loop over the token list, threading `{Node, RestTokens}`; the operator table is §2.6's. No generic Pratt engine and no yecc: the hand parser is the executable test of principle 4, and the two mandated diagnostics below need it. Recursive descent for declarations (`type`, `abstract type ... with { }`, `fn`, `let`, `foreign`). Error messages in the `Expected 'a', 'b' or 'c' instead of X` style, rendered as §11.5 says.
- `let x <- e;` as a binding in a block: parsed as a binding form; the checker defers which of `Either` and `Optional` it is until inference has typed `e` (report §5.5), and the compiler emits it as a `case` whose second clause holds the rest of the block. Both forms from MVP 1.
- Block `{ ... }` is an expression form. `match e { P -> e | ... }` and `receive { P -> e | ... | after millis -> e }`, guards with `when`. `if then else`. Calls `f(x, y)`, n-ary functions, no currying: too few arguments is an arity error on the line, with a suggestion of the tuple reading.
- Constructors: no field, one field `T(e)`, or named fields `T(f = e)`; partial patterns `T(f = p)`, base `T(..e, f = e)`. Positional or named is decided by whether `=` or `:` follows the first identifier. Named fields in canonical (field-name) order, report §3.5; compiled to tuples. `fn` definitions allowed in blocks, recursive and generalized; `let` bindings monomorphic.
- AST as Erlang records with a span on every node: line, column, and the end.
- Error message with its own text for a function written with two clauses, Haskell-style: "a function has one clause", with the help line "write one clause whose body is a `match`". Three paper programs out of three made the mistake. Its own text also for `f x` where `f(x)` was meant, since that is the first thing a Unison or Haskell reader writes; for a trailing `;` before `}` ("a block ends with an expression"); for `if` without `else`; and for `let p <- e` at top level ("`<-` is a block form").
- Doc comments. `///` to end of line, consecutive `///` lines form a doc block, attached to the following declaration when there is no blank line between. Lexer emits a doc-comment token; parser records the joined block as an optional field on the declaration's AST node. Approximately 0.5 days.

**Output:** `lib/lexer/src/ern_lexer.erl`, `lib/parser/src/ern_parser.erl`, AST records in `lib/parser/include/ern_ast.hrl`.

### 1.2 Type Inference (13 days)

- Hindley-Milner algorithm: W or J. Unification via a substitution register. Function types are n-ary: `(A, B) -> C` is a type with an argument list, not two arrows; unification requires the same length, and a length mismatch is reported as an arity error with a suggestion of the tuple reading. `fn` generalizes, `let` does not.
- Typing environment: `#{var => type}`, generalization with forced parameters.
- Pattern matching is type-checked, with exhaustiveness checking on `match`; `receive` is exempt by the report. Two days. Uniqueness: a variable at most once per pattern, checked in the type checker, since the grammar cannot. Also checked there: type and constructor names unique within a module (a module may shadow prelude names, §4.2); under `Never`, a `receive` with only an `after` clause is legal and any pattern clause is a type error (§6.8).
- Reply-carrying types (report §6.6). A type is reply-carrying if it is `Reply(a)` or transitively contains one. Reply-carrying values are linear: at each binding site (function parameter, receive-bound variable, spawn-lambda capture, pattern-bound field, or the result of a call whose return type is reply-carrying), every path from the binding must consume the value exactly once, by one of: `answer`, passing to a function whose parameter is reply-carrying, sending with `send`, placing into a constructor or tuple of reply-carrying type, returning from a function whose declared return type is reply-carrying, or capturing in a spawn-lambda. Pattern-match on a reply-carrying scrutinee transfers the obligation to its pattern-bound reply-carrying fields; a nullary case discharges the obligation; a `let` transfers it to the variables it binds; an `if`, `match`, `receive`, or block with a reply-carrying value carries the obligation to where that value is bound or consumed. The check is compositional per function definition; compiled interfaces carry the obligation. `Address.call`'s `mk` callback is the canonical case: its `Reply` parameter is consumed by placement into the reply-carrying message it returns, and the returned value's obligation is discharged by `Address.call`'s runtime. MVP 1 restriction, lifted in MVP 2: when a spawn-lambda captures a reply-carrying value, the spawn's second argument must be a direct `fn() = ...` at the call site (no `let`-bound intermediate), so the checker does not have to follow function values around. Approximately 5 days.
- The mailbox effect as part of the function type, report §3.9: the arrow constructor has three parameters — arguments, effect, result — represented `Arrow(args, E, result)`. The effect slot holds one of three things: the distinguished value `pure`, a mailbox type, or an effect variable. An annotation without `with` puts `pure` in the slot; an annotation `with M` puts `M`; an unannotated function gets a fresh effect variable. Unification is component-wise. An effect variable unifies with anything; `pure` unifies only with `pure` or an unrestricted variable; two different mailbox types, or a mailbox type against `pure`, is a type error. An effect variable is *process-only* when it also occurs in a value position (`self : () -> Address(m) with m`) or belongs to a process primitive (`send`, `spawn`, `Address.call`, `answer`, `monitor`, `kill`, `remote`, and foreign functions declared `with M`); a process-only variable does not unify with `pure`, and the flag is part of the type scheme. A free effect variable at generalization is generalized like any other, which is effect polymorphism: `List.map` runs a pure or a process callback in the caller's process. The only departure from textbook HM is `pure` as a non-type value in the slot and the process-only flag.
- Base types `Int`, `Bool`, `Char`, `String`, `Bytes`, `Unit`; `Float` was MVP 2 and its arithmetic refused meanwhile. Operators resolve on the operand type, in MVP 1 in one post-inference pass, since MVP 2 during inference: the `userop` operators (`+` to `Int.+`, `Money.+` on user types since MVP 2), `==` (a type error on types containing functions or addresses), `<`, `<=`, `>`, `>=` (to the operand type's `compare`, a type error without one), and `<-` by the type of `e`. `/` and `%` on `Int` fault on zero (`badarith` becomes a `Fault`); `Int.div` and `Int.mod` return `Optional(Int)`.

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

**Test:** `examples/counter.ern`, `examples/upgrade.ern`, `examples/pingpong.ern`, `examples/stack.ern`, `examples/hello.ern`, and `examples/kvparser.ern`, a parser with three failing steps over `Either` with `let x <- e`.

---

## Phase 2: Compiler and Runtime (2 weeks)

**Goal:** typed AST → Erlang code that runs on BEAM.

**Order of work, with status.** (1) The runtime `ern_rt` and the hand-written target modules `test/target/{hello,counter}.erl`, run by the runtime's tests: done 2026-09-17. (2) Two tables in 2.1 below, decided before any emitter code: every record of `ern_ast.hrl` to its Erlang shape, and every prelude name of report §9.4 to §9.6 to what is emitted for it; with a test asserting that the AST record tags occurring in `examples/` equal the tags declared in `ern_ast.hrl`, minus `e_bits` and `p_bits` until MVP 2, so the examples corpus exercises every construct the emitter must handle. (3) The three pre-passes, (4) the emitter `lib/compiler/src/ern_compiler.erl`, golden-tested against the target modules, and (5) the stdlib modules of Appendix E as Erlang: done 2026-09-17, one traversal doing the pre-passes on the way. (6) Every MVP 1 example compiles and runs under the compiler's tests and, through `ernc` and `ern`, the integration tests of 3.2: done 2026-09-17.

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
  | `Sys.stdin`, `Sys.keys`, `Sys.fs`, `Sys.tcp`, `Io.readLine`, `Keys.*`, `Fs.*`, `Tcp.*` | MVP 2.5; until then `ern_compiler:refused/1` makes the compiler say `X is not in MVP 1` |
  | `Clock.*`, `Path.*`, `Random.*` | `'ernest@clock':alarm/2` and so on: the namespace's module |
  | `Io.*`, `List.*`, ... | `'ernest@io':println/1` and so on |

- Typed AST → Erlang's abstract format with `erl_syntax`, `erl_syntax:revert`, `compile:forms`.
- Three passes on the typed AST first: unique variable names, since Ernest shadows and Erlang does not; lambda lifting of local `fn`s to module-level functions with their free variables as leading parameters, which handles self- and mutual recursion uniformly; and the `<-` desugaring of report §5.5, choosing Either or Optional from the type the checker left on the node. The checker returns its environment so the compiler has the layouts of private types.
- Functions become Erlang functions. Blocks become sequences in a function clause; bindings become `=`.
- Processes become recursive functions.
- `send(addr, msg)` becomes `Addr ! Msg`.

**Code:** `ern_compiler.erl`.

**Output:** BEAM in memory, written by `ernc` as `.erc` under the build directory (report §11.1).

### 2.2 Processes (3 days)

- `spawn(Local, f)` becomes `ern_rt:spawn('Local', F, Site)` with the spawn site for `Down` (report §6.9); `spawn(Peer(name), f)` and `remote` are MVP 3, `remote` answering `Left(NoRemotePeer)` meanwhile; `self()` becomes `ern_rt:self()`. Functions with n arguments become Erlang functions of arity n, directly.
- `receive { P -> e | ... }` becomes `receive P -> E; ... end`, and `receive { ... | after T -> e }` becomes `receive ... after T -> E end`; an `after`-only receive becomes `receive after T -> E end`. `monitor` and `kill` go through the runtime of 2.4, which delivers at once for a dead target with its recorded cause (§6.9) and kills asynchronously as §6.9 says. Clauses are translated like `match` clauses. **Omission, 2026-09-17:** report §5.9 allows any pure `Bool` expression as a guard, but BEAM tests a receive guard before taking the message and so admits only Erlang guard expressions. In MVP 1 a `receive` guard must be a comparison, or `&&`/`||` of comparisons, over pattern variables, enclosing variables, and literals; anything else is a compile-time error naming §5.9 and MVP 4, which lifts the restriction. `match` guards are general from the start, by the continuation in 2.1. No mailbox scanning in MVP 1.

**Code:** translation of patterns and guards into Erlang patterns and guards, shared with `match`.

**Output:** processes as recursive Erlang functions with `receive`.

### 2.3 Abstract Types (0 days)

- Nothing to do in MVP 1: an abstract type compiles as an ordinary type, `Stack.push` becomes the function `'Stack.push'/2` in the Erlang module compiled from the Ernest module that defines it, which is also how it stays: §11.2 finds a type member through the interface of the file that owns the type, one module per file. The constructor-visibility check is MVP 2.

### 2.4 Standard Library (3 days)

- The representation of values on BEAM, the ABI that foreign code sees: `Int` integer, `Float` float, `String` UTF-8 binary, `Char` integer code point, `Bytes` binary, `Bool` `true | false`, tuples tuples, `List(a)` list, a nullary constructor the quoted atom of its name (`Stop` is `'Stop'`, `Unit` is `'Unit'`), a single-field constructor `{'Tag', V}`, named fields `{'Tag', F1, F2, ...}` in canonical field-name order (`None` is `'None'`, `Some(v)` is `{'Some', V}`, `Left`/`Right` `{'Left', E}`/`{'Right', V}`), as report §8.4, `Address(m)` a pid, `Reply(a)` a process alias (2.4), a function a fun, a `foreign type` value whatever the implementation returns. Erlang functions whose conventions differ (`{ok, V} | {error, R}`) get a wrapper module, as Gleam's `gleam_stdlib.erl`. `List`, `String`, `Int` as wrappers around Erlang's; `Map` as Erlang's `maps` (structural equality on keys, no ordering). `sort` takes `compare`. Total: `Int.div` and `Int.mod` return `{'Some', N}` or `'None'`, `List.get` and `List.last` likewise. No built-in function may let an Erlang exception reach the process, except `/` and `%` on zero, whose `badarith` the runtime turns into `Fault("division by zero")`.
- **The three layers.** Language (built-ins), prelude (always imported, minimal — report §9), stdlib (default on the load path — report Appendix E). A namespace is an Erlang module named by its path with `@` for `/` and the prefix `ernest@` (`ernest@net@http`, `ernest@list`), as Gleam names `gleam@list`: lowercase, one-to-one with the path since a segment never contains `@`, compilable by `erlc` from a file of the same name, and never a bare name in the BEAM's flat module namespace (rejected the same day: bare `'Io'`, which claims a name any BEAM library might want, and `'Ernest.Io'`, which `erlc` cannot compile from a lowercase file without a forms-compiling build step); functions keep their local names and type members their prefix (`'Stack.push'/2`). MVP 1 ships the prelude and Appendix E signatures as the checker's tables (`ern_prelude`) and the modules of Appendix E as hand-written Erlang modules, `ernest@io` in `lib/runtime/src/ernest@io.erl` and so on, exporting Appendix E under the ABI, since Ernest source for them needs `foreign fn`, which is MVP 2. Generated code calls `ernest@list:map/2` the same way whether the module is Erlang or Ernest, so rewriting a stdlib module in Ernest later changes nothing for callers. `Io.print`/`println` send to `Sys.stdout`; `Sys.stdout` and `Sys.clock` are top-level values the launcher wires per-node (report §8). A type the stdlib declares, `Random.Seed`, is a fourth table of `ern_prelude`, Ernest source by namespace, declared under that namespace when the checker builds the prelude environment; it prints qualified like any other module's type (report §11.5). A module's `#iface{}` is stored in its `.erc` as an extra BEAM chunk, readable with `beam_lib` without loading, together with a hash of the module's source and, per dependency, the hash of the interface it was compiled against; `ernc` recompiles a module when its own hash or a dependency's current interface hash differs from what is recorded (report §11.1), so a body-only edit never cascades. For the hashes to mean anything an interface must be canonical: quantified type variables renumbered in order of appearance, their annotation names left out of the hash (report §11.5 keeps them for printing), and sorted lists rather than maps. The chunk carries a format number; a chunk of another version reads as stale. The dependency graph comes from a parse-only scan of the qualified names in each source; a cycle is reported as §11.1 requires.
- System processes `stdout` and `clock` are started by the launcher, and their addresses are bound to the `Sys.*` top-level references (report §8); no named processes. `stdin`, `keys`, `fs`, and `tcp` are MVP 2.5, as foreign processes: Erlang modules that speak the types of report §9.3, bound to `Sys.stdin`, `Sys.keys`, `Sys.fs`, and `Sys.tcp`, and used through the Appendix E modules `Io.readLine`, `Keys`, `Fs`, and `Tcp`, never by `send` (E.0).
- Runtime, `ern_rt`: every `Address` is a pid. `via` and `monitor` each spawn a proxy process, so `send` is `!`, `self()` is `self()`, and a generated `receive` never sees a foreign message shape. `Reply(a)` is a process alias made with `alias([reply])`, which deactivates after the first answer; `unalias` after a timeout drops late ones, which is report §6.6 for free. The runtime wraps every process body so an exception becomes an exit reason the monitor proxy turns into `Down(reason = Fault(...), function = ...)`; `badarith` maps to `Fault("division by zero")`; a compiled `badarith` carries no operands, so the `Float` operators of §7.4 are functions of `ernest@float` that catch it and fault with `Fault("float arithmetic error")`, and the emitter calls them when `Float` arrives in MVP 2.
- Launcher: starts the system processes, binds their addresses to the `Sys.*` top-level references, runs every module's `'$init'/0` (report §8.5, so a top-level `let` may name `Sys.stdout`), calls `main()`; when `main` returns all *local* processes are killed with `ProgramEnd` and the node stops (remote workers on peers survive under their own runtime; this only matters from MVP 3 when peers exist). If `main`'s declared mailbox is polymorphic (`with m`), the runtime instantiates it to `Never`. Deadlock detection (`Deadlock`) is MVP 2: it requires the runtime to know whether all processes are waiting without `after` and no timers are active.

**Output:** the launcher as `ern_rt:run_main/3`, called by `ern` (3.1), and the Erlang stdlib modules; `stdlib/*.ern` for the Ernest-facing surface is MVP 2.

### 2.5 Code Generation (1 day)

- Module header, export of the exported declarations, `compile:forms` with `[return_errors, debug_info]` and the interface chunk, written as `.erc`.
- Erlang errors from `compile:forms` are mapped back to Ernest lines via node positions.

**Code:** part of `ern_compiler.erl`.

**Test:** `examples/pingpong.ern`, `examples/upgrade.ern`, and `examples/kvparser.ern` run on BEAM.

---

## Phase 3: Assembly (1 week)

**Goal:** `ernc hello.ern` produces `hello.erc`, and `ern hello.erc` runs it.

### 3.1 Integration (3 days)

- Two escripts, `bin/ernc` and `bin/ern`, committed as escript source files that put `lib/*/ebin`, found relative to the script, on the code path; no escriptize step and no build product under `bin/`. Options are long only, report §11; short aliases come later as additions. `ernc [--source-root dir] [--out-dir dir] [--emit erl] [--no-clean] foo.ern` reads, parses, type-checks, compiles, writes `foo.erc`; `--emit erl` writes the pretty-printed Erlang source instead. `ern [--config-dir <dir>] [--load-path <dir> ...] [--main Q.name] foo.erc` loads the module and its dependencies by namespace, calls each module's `'$init'/0` dependencies first, starts the system processes, binds their addresses to the `Sys.*` top-level references, calls `main()`; `ern --create-config-dir <dir>` creates `<dir>/.ernest/` with `ernest.conf` (JSON: this node's address and public key, an empty peer list) and a private key readable only by the owner, and does nothing else. `--config-dir` defaults to `./.ernest`. **Deferred, 2026-09-17:** `--shell` needs an incremental checker and is MVP 2; until then it errors with "the shell is not in MVP 1". `--config-dir` is accepted and unread until peers exist in MVP 3.
- Errors as §11.5 says: `file:line:column: message`, then the source with the span underlined; `--errors short` for the first line alone. One `#diag{}` record from every stage, rendered by `ern_diag`, with labels and help placed as 3.4 says.
- `lib/cli/src/ern_cli.erl` orchestrates everything; the escripts are thin.

**Output:** `bin/ernc` and `bin/ern`. Done 2026-09-17, with `--shell` deferred to MVP 2.

### 3.2 Testing (2 days)

- The MVP 1 programs are the `PROGRAMS` macro in `test/ern_integration_tests.erl`, which is also the golden-file set. The rest of `examples/` is type-checked only, each file's header naming what it waits for: `ets` needs `foreign fn`, MVP 2; the four paper programs need their system processes, MVP 2.5 step 4, which adds their expected-output files.
- Compile: `ernc program.ern`. Run: `ern program.erc`.
- These are the tests for the runtime sections of the report, §6.4, §6.5, §6.9, §6.10, §7, §8, §11.2, §11.3, which no unit test cites; `make sections` lists the sections still without a citing test.
- Smoke test in a top-level `test/`: every listed program compiles and runs, output compared against an expected-output file of the same name. The comparison treats output as a multiset of lines, since the interleaving of prints from different processes (ping-pong) is scheduling-dependent.
- The four paper programs run in MVP 2.5, when their system processes exist.
- Done 2026-09-17: `test/ern_integration_tests.erl`, run by `make test` after the unit tests, with `test/expected/<name>.out`; the program list is in the test module.
- Golden files, 2026-09-17: `test/golden/*.erl` holds the Erlang source the compiler emits for every MVP 1 example, as `--emit erl` writes it; the compiler's tests compare against them and write a `.new` beside a differing file; `make golden` rewrites them after an intended emitter change. The hand-written targets under `test/target/` remain the two tests that are not self-referential.
- Sections `make sections` lists, 2026-09-17: §3.11, §8.3, §8.7, all MVP 3 and unimplemented; anything else it prints is a gap.
- Thin sections, 2026-09-17: `make coverage` listed §5.7, §6.5, §6.10, §6.8, §9.5, and §7.3 with one citing test each. Read against their tests the same day: added the pipe's precedence and lambda cases and its type rule (§5.7), the `with Never` root's callers (§6.8), and kill, fault, via, and parallelRemote through compiled code (§6.5, §7.3, §9.5); §6.10 is the upgrade example end to end.

### 3.3 Documentation (3 days)

- User readme: how to write Ernest, which constructs are supported. Done 2026-09-17: the guide is the first half; the README's "What MVP 1 accepts" table is the second; the guide's code blocks were run through the checker and agree with it.
- Internal architecture notes for the next phase. Done 2026-09-17: `docs/architecture.md`.
- `ernc --doc file.ern` type-checks the module and writes Markdown to stdout: every exported and every documented declaration with its type, printed by the checker's printer so the §11.5 marks appear, and its doc comment. Done 2026-09-17.

### 3.4 Type error placement (2 days)

**Diagnostics first, done 2026-09-18.** One record for every stage, `#diag{span, message, labels, help}` in `ern_diag.hrl`, and one renderer, `ern_diag`, in the lexer's application since positions are the lexer's type: `short/2` is the first line a tool parses, `format/3` the source with a gutter, the spans underlined, the labels, and the help line, as §11.5 says; `ernc --errors short` prints the first line alone. Spans: a token's position is `{Line, Col, End, Before}`, its own end and the end of the token before it, and the parser sets every node's position to `{Line, Col, End}` with `w/1` from the token before the rest, so a call spans callee to closing paren and a declaration its whole body. The lexer, parser, checker, and compiler return diagnostics instead of `{Line, Col, Msg}` triples; golden files are unchanged since positions do not reach the emitted Erlang. The labels and the help are the placement below. No colour until an editor renders through an LSP, when the JSON form is a second renderer of the same record; no error codes.

**Placement, done 2026-09-18.** `ern_typecheck:check/5` takes an expected type, a context sentence, and an origin, and pushes the expectation into `if` branches, `match` and `receive` clauses, and a block's last statement, so the mismatch is reported at the leaf as §11.5 now states; `infer/2` for those forms is `check` with a fresh variable. The call sites: a body against its return annotation, each argument against the parameter type of a known callee, an annotated `let`, a constructor field, the `if` condition, a right operand against the left, a list element against the first, a pattern against the value matched. The origin becomes the label; the first branch, clause, or element is the origin when nothing outside fixed the type. The message keeps both whole types, and when they differ inside, `ern_types:mismatch_pair/3` gives the help line, "the types differ at Int and String". Effect errors: the environment carries what is pure and why (`effect_origin`: the function's `->` without `with`, a top-level `let`, a guard, a lambda's own annotation), and the error names the callee, labels the annotation, and helps with `with`. The parser's mandated diagnostics are now message and help, the rule and the fix, through `fail/3`. An operator expression's span starts at its left operand. The checker's tests pin the spans, labels, and help of each placement; a body without a return annotation gets no "declared return type" context.

### 3.5 Paring the report (1 day)

Done 2026-09-18. Sections 0 to 11 without code blocks or tables went from 13,084 words to under 8,000, thirty-three pages to twenty, in one pass, the exact count in the decisions log's "Measure": every heading kept, every code block kept byte for byte, every cut inside a section, so every `§x.y` citation and `make sections` still hold; the mirror tests proved the grammar and the prelude did not move, and `make test` that no cited rule changed meaning. Rationale went to the decisions log, one entry listing what left by section. What remains is rules, 81 sections at a median of 76 words, the longest 548, so the measure was revised rather than the report cut past it: the log's "Measure" now says under 8,000 words and no section over 600, measured the same way after every pass.

The standing rule for edits, from here on: a change to the report is made inside its heading, in the report's register, and a section that passes 600 words is restating something.

---

## Tools and Environment

Erlang, OTP 27, Makefiles (see Repository Layout); no rebar3, no OTP behaviours. EUnit per module under `lib/*/test`; integration tests under `test/` run `ernc` on the example programs and compare output against expected. The compiler is distributed as the escript sources in `bin/`.

---

## Risk and Uncertainty

**The mailbox effect.** HM with an effect slot per arrow is a small extension of the textbook, but not zero: the slot admits `pure`, which is not a type, and effect variables carry a process-only flag (§1.2, report §3.9). Unification is component-wise; a free effect variable is generalized like any other, which lets `List.map` run a process lambda. No wrapping type constructor, no rows, no effect system beyond the slot. Risk: `let`-bound lambdas fix their mailbox slot at first use (standard let-monomorphism, but easy to trip on if generalization gets attached to `let` by accident); and every arrow in the AST must carry a mailbox slot from day one, including arrows that look pure, so that higher-order pure functions like `List.map` accept process callbacks without a special case.

**What MVP 1 does not prove.** The ownership rule for abstract types, foreign code, and everything past one node.

---

## Decisions Before Start

Decided: hand-written lexer and a direct precedence-climbing parser over a token list (no yecc, no generic Pratt engine, decided 2026-09-17); yecc-shaped tokens; Erlang's abstract format via `erl_syntax` and `compile:forms`; OTP 27; Makefiles, no rebar3, no OTP behaviours; the `lib/` layout above; the error format of §11.5, whose first line is `file:line:column: message`; one Erlang module per Ernest module, named `ernest@` and its path (2.4).

Nothing open.

---

## Time Budget

| Phase | Parts | Days | Weeks |
|-------|-------|------|-------|
| 1     | Parser, type check, abstract, stdlib types | 24.5 | 4.9 |
| 2     | Compiler, processes, stdlib, codegen | 9 | 1.8 |
| 3     | Integration, tests, docs, error placement, paring | 11 | 2.2 |
| **Total** | | **44.5** | **8.9 weeks** |

One person full-time: about nine working weeks. Half-time: three to four calendar months.

---

## Later MVPs

**MVP 2 (the whole report on one node), about five weeks.** Each item is a report rule MVP 1 refuses or does not check; the README's table names the refusal it lifts. The order below is the order of work, audited 2026-09-18: what MVP 2.5's standard library needs comes first (`Float` for `Float`'s module, operators for the types the stdlib declares, `foreign fn` for every shim, bitstrings for `Bytes`), then the checks and runtime rules that touch no other item, and the shell last, since it runs everything else.

- **`Float`, and operators on user types** (§3.1, §4.8, §3.10, §5.1). Done 2026-09-18. Resolution is in inference: `ern_typecheck:operator_result/4` looks the operator up as soon as the operand type is known, `Int`, `Float`, `String`, `Char`, `List`, `Bytes` by table, a user type by its member `T.+` or `T.compare`, instantiated like a reference and unified with `(T, T) -> r`, its effect used like a call's; an operand still a variable is a `{operator, ...}` entry in the definition's deferred list, solved with the `<-` bindings at the end, and "annotate it" if still unknown. The result is the operator's, so `Vec.* : (Vec, Vec) -> Float` gives `(a * b) + 1.0` its Float, and one consequence is deliberate: the operand type comes from the operands, never from where the result goes, so `fn cat(a, b) = a <> b <> "!"` now asks for an annotation where MVP 1's `(t, t) -> t` guess accepted it. The reference graph that orders definitions counts an operator as a reference to that member in every local type, since the operand type is not known before inference; a group the approximation merges is checked together, and the §8.5 cycle rule uses the exact references within the group. The compiler emits Erlang's operators for `Int` and the four ordered prelude types, `'ernest@float'` for `Float`, the member for a user operator, and `T.compare(a, b) =:= Less` and its three variants for an ordering; a receive guard that orders a user type is a call and so falls under MVP 1's guard rule; the `$init` order sees through an operator to the member's lets. Prefix `-` resolves to `negate` in the operand type's namespace, `Int`, `Float`, or a user type's `T.negate`, §5.1 as changed the same day.
- **`foreign fn` and `foreign type`** (§4.7, §8.4). Done 2026-09-18. As planned below, with these choices: the check is data, a descriptor term the compiler builds from the declared type (`any`, `int`, `string`, `{list, D}`, `{con, [{Tag, [D]}]}`, `{mu, Id, D}` for a recursive type, and the rest) and `ern_check` in the runtime interprets, one `$type_N` function per distinct descriptor per module, so a recursive or imported type needs no runtime table; a type variable in a declared type checks nothing; the reply of `Address.call` and `callForever` is checked as a message is, since a foreign process may answer; every receive clause binds the whole message and checks it, Ernest senders included, which is the cost MVP 4's mailbox lifts; an Ernest fault raised inside foreign code passes through as itself; the checker validates the implementation name `module:function/arity` against the parameter count, §8.4 now stating the shape. Found on the way and fixed: a function named like an auto-imported BIF, `size`, `max`, could not be called by its name, since Erlang refuses the ambiguity; the module now switches the auto-import off for those names. The three fault texts are in §7.4. Plan text before the work: The compiler generates the check from the type: `Int` is an integer, `Float` a float, `Bool` `true` or `false`, `Char` a code point, `String` a binary of valid UTF-8, `Bytes` a binary, a tuple and a list checked element by element, a constructor by its tag and arity with its fields checked, `Map` and `Set` by their handles with keys and values checked, and `Foreign`, `Address`, `Reply`, and function values by shape only, since Ernest does not inspect them. A `foreign type` value is not checked. A mismatch is `Fault("foreign return does not match ...")` naming the declared type. Messages from a foreign process are checked the same way by the `receive` that binds them, generated per mailbox type, until MVP 4's runtime mailbox takes it over. The check is linear in the value's size and runs once, at the boundary. 4 days.
- **Bitstrings** (§5.11). Done 2026-09-18; the lexer and parser had them since MVP 1. The checker types each segment by its specifiers (`ern_typecheck:segment_spec/1` folds them with the defaults and refuses a conflict, a utf size, a float width other than 16, 32, 64, a `bits` or `bytes` width that is not whole bytes, a unit outside the runtime's 1 to 256), a size expression in a pattern in the scope of the earlier segments and pure, and a constant bit count that is not a multiple of 8, a segment with a dynamic size and a unit not divisible by 8 leaving the count open. The compiler emits the runtime's bit syntax: `ern_bits` checks each value against its width, since Erlang truncates an `Int`, rounds a `Float` to infinity, and takes a prefix of a binary where §7.4 faults; a `badarg` is the overflow fault; an open count is checked for alignment after construction; a `bits` segment in a pattern is bound and guarded `is_binary`, so an unaligned rest fails the match. Two rules the runtime forced went into the report first: a segment pattern is a variable, `_`, or a literal, since the bit syntax has no nested patterns, and a match on bitstring patterns ends with a wildcard, since coverage of bitstrings is not decided (`ern_exhaust` treats a bitstring pattern as never complete). One refusal until MVP 4, in the README's table: a size expression in a pattern that is not an Erlang guard expression, since the match compiles to a pattern. Original estimate 4 days.
- **Abstract-type ownership** (§4.4): the constructor-visibility check in the checker, in `check_values`, rejecting a constructor of an abstract type in any definition the signature does not name; the signature's types checked against the definitions as today. No compiler change: a type member lives in the Erlang module of the file that owns the type, as §11.2 says, and the earlier idea of one Erlang module per type is dropped, since the loader never looks for one. Before the standard library is written in Ernest, so its abstract types are checked under the final rule. 2 days.
- **The reply discipline through function values** (§6.6), lifting 1.2's spawn-lambda restriction. Report first: §6.6 says a lambda that captures a reply-carrying value is itself a reply-carrying value, a function type being reply-carrying when its captures are, and is consumed exactly once, by `spawn` or by a call, so `let f = fn() = worker(r); spawn(Local, f)` is legal and `let f = ...; spawn(Local, f); f()` is a type error. The checker then follows the value as it follows any other binding, with no special case for `spawn`'s argument; `ern_reply` drops its direct-argument rule. Decisions log to match. 3 days.
- **`Deadlock`** (§8.6): the reaper tracks waiting processes and timers. 2 days.
- **`ern --shell`** (§11.2): a shell process added to the running program, or started over the standard library alone, with every loaded module in scope. Each line is parsed as a declaration or an expression, checked against the loaded interfaces and the shell's own bindings so far, compiled as a throwaway module, and run in the shell process, whose mailbox type is the entry point's; a `let` at the shell binds for the lines after it. Last, since it is the one item that uses every other. 3 days.

The system processes and the paper programs as their tests are MVP 2.5.

**MVP 2.5 (a complete standard library for one node), about two weeks.** What makes Ernest useful to someone else for a single-node project, before distribution. Appendix E is the shape, with its rules in E.0; the MVP 1 programs compile against it, and the four paper programs lack only the processes behind E.15 to E.18 and the `Ets` library. A function is written in Ernest unless E.0's first rule admits a shim: pure Ernest are `Optional`, `Either`, `Bool`, `List`, `Path`, `Char.fromInt`, and the system modules `Io`, `Clock`, `Keys`, `Fs`, `Tcp`, each a `send` or an `Address.call` to its `Sys.*` reference; shims over `foreign fn` are `Map` and `Set` over Erlang maps, `String` and `Char` for Unicode, `Float`, `Int.toString`, `Int.toFloat` and the bit operations, `Foreign`, and `Random` over `rand`. In order:

1. **Report first.** Appendix E gains sections for `Ets`, today only source in Appendix D, and `Erl`, today only in step 4, so every module of MVP 2.5 has its signatures in the appendix before the rewrite starts. §4.2's rule that a module namespace may not coincide with a prelude namespace gets the exception that the standard library's source root defines them, since `stdlib/list.ern` must be `List`. Decisions log to match.
2. **The checker reads the standard library's compiled interfaces** as it reads any dependency's. `ern_prelude` shrinks to §9: the built-in types, the declared types, the built-in and process functions, the operators, `todo`, `Sys.*`; its stdlib types table goes with the modules, `Random.Seed` becoming `foreign type Seed` in `stdlib/random.ern`.
3. **Rewrite Appendix E module by module, pure modules first.** The Erlang modules of MVP 1 export Appendix E under the ABI and `ernest_stdlib_tests` tests them by that ABI, so the same tests run against the Ernest-compiled modules unchanged; a module is done when its Erlang original is deleted with the tests green. `ernc` in directory mode on `stdlib/` builds it; `make` runs that. From then on a rule, not a milestone: a shim exists only where E.0's first rule admits it, and a shim that stops meeting that test is rewritten in Ernest when noticed.
4. **The system processes**, 4 days, moved here from MVP 2: `Sys.stdin`, `Sys.keys`, `Sys.fs`, `Sys.tcp` as runtime processes bound by the launcher, each speaking its §9.3 type, with `Io.readLine`, `Keys`, `Fs`, `Tcp` over them as Appendix E has them, `Keys` reading the terminal in raw mode with echo off through `prim_tty` or `shell:start_interactive`, the one process whose Erlang side is not an existing module and so the risk of the step; `ern_compiler:refused/1` and the README's table row go. `Ets` under `stdlib/` as Appendix D has it, with the `Erl` module every shim needs: `Erl.atom : (String) -> Foreign` and `type Erl.Result(v, r) = Ok(v) | Error(r)`, `Ok(v)` being `{'Ok', v}` under the ABI, so an Erlang-side helper rewrites `{ok, V} | {error, R}` into the declared shape as Appendix D and guide §7.5 describe. The four paper programs then run and become integration tests. `Tcp` is processes first: `Sys.tcp` answers `Listen` and `Connect`, each socket is a process speaking `SockMsg` over its `gen_tcp` port, so every socket is an address that `monitor`, `kill`, and `via` accept and that dies with the connection. An echo server under `examples/` measures it; if the two hops per read cost, `Tcp.read` and `Tcp.write` become foreign calls on the socket's port while the socket process keeps identity and lifetime, and no program changes a line.
5. **What "complete" means beyond that is decided by programs.** Erlang's standard library was read module by module on 2026-09-18, and this table is the result for the roadmap; the reasons are in the decisions log. Every user-facing OTP module is a row; what is not a row is OTP's own machinery, which Ernest's concepts or toolchain replace. A function moves from "waiting" to Appendix E when its trigger fires, report first, by the rules of E.0, and never as a composition of two functions already there.

   | Erlang | Ernest | In Appendix E | Waiting, and its trigger | Out, and why |
   |---|---|---|---|---|
   | `erlang` BIFs | the language; `Int`, `Float`, `String`, `Char` | `spawn`, `self`, `send`, `monitor` as §9.4 and §9.5; `abs`, `min`, `max`, rounding, `toString`, `toFloat`, the bit operations | `Float.truncate`, a program that computes; bases for `Int.toString` and `String.toInt`, which §2.5 promises, a program that reads hex; an exit status for §8.6, `Sys.args`, `Sys.env`, the first command-line program | `register`, `whereis`: §6.5 has no registry. `link`, `exit`, `throw`, `catch`: §7 and §6.9. `term_to_binary`: MVP 3's transport. `phash2`, `md5`: a hashing library. `make_ref`: identity is a `Reply` or an address, §6.5. `iolist_to_binary`: `String.fromList`, `<>`. `memory`, `system_info`: the runtime's |
   | `lists` | `List` | E.2, thirty functions | `foldRight`, `scan`, `mapFold`, `window`, `chunk`, `sum`, `max`, `min`, a program that writes one, `sum`, `max`, `min` being `foldLeft` with `Int.+` or `compare` until then | `first`, `rest`, `flatten`, `count`, `map2`: one pipe each. `permutations`, `transpose`, `combinations`: specialities. `key*`: `Map` |
   | `maps`, `dict`, `orddict`, `gb_trees`, `proplists` | `Map` | E.3 | | the four alternatives: history |
   | `sets`, `ordsets`, `gb_sets` | `Set` | E.4 | | `symmetric_difference`, `is_disjoint`: compositions |
   | `string`, `unicode` | `String`, `Char` | E.5, E.6 | | the list-based half of `string`; graphemes, since a `Char` is a code point |
   | `io`, `io_lib` | `Io` | `print`, `println`, `readLine` | `Sys.stderr` with `Io.printError`, `Io.printlnError`, the first command-line program | `format`: no format strings, `<>` and `toString` are the one way |
   | `file`, `filelib` | `Fs` | E.17, nine functions | `watch`, a program that must not poll; the working directory and absolute paths, a program that needs them | `wildcard`: a glob library. `fold_files`: five lines over `list` |
   | `filename` | `Path` | E.14, eight functions | | `absname`, `expand`: `Fs`'s, they read the working directory. `nativename`: a `Path` is in the runtime's syntax |
   | `timer` | `Clock` | `now`, `alarm`, `alarmAt` | `Clock.monotonic`, the echo server of step 4 | `send_interval`, `cancel`: E.15's positions. `sleep`: `receive { after ms -> Unit }`. `seconds`, `minutes`: arithmetic |
   | `rand` | `Random` | `seed`, `next` | a float draw, a program that needs one | |
   | `math` | `Float` | the operators, `abs`, `min`, `max`, `round`, `floor`, `ceil`, `toString` | `sqrt`, `pow`, `exp`, `log`, the trigonometry, `looselyEquals`, and `toPrecision`, a program that computes, compares, or prints with a precision | |
   | `gen_tcp`, `inet`, `socket`, `ssl` | `Tcp` | E.18 | `Udp` as its own module, a program that needs datagrams | socket options: tuning is a library's. TLS: a library whose `listen`, `accept`, and `connect` return the same `Address(SockMsg)`, the encryption inside the socket process, so a program's `Tcp.read` and `Tcp.write` do not change |
   | `ets` | `Ets` | Appendix D; its E section is step 1 | | match specifications, `qlc`: `Ets` is a key-value table |
   | `os` | `Sys` | | `Sys.env`, `Sys.args`, the first command-line program | `cmd`: a program that runs commands has not been written |
   | `calendar` | `Time` | | a program that formats a timestamp | |
   | `binary` | `Bytes` | `<>` | `size`, `get`, `slice`, `toList`, `fromList`, when bitstrings show what a protocol needs | |
   | `array`, `queue` | | | indexed access or a FIFO that two lists cannot give | |
   | `eunit` | `Test` | | a `Test` module, the first test written in Ernest; the decisions log of 2026-09-14 sketches its type | |
   | `base64`, `json`, `uri_string`, `re`, `crypto`, `zlib`, `dets`, `digraph`, `sofs`, `erl_tar`, `zip`, `disk_log`; the applications `ssl`, `inets`, `xmerl`, `public_key`, `asn1`, `mnesia`, `snmp` | libraries | | | each a namespace of its own on Appendix D's pattern, never stdlib |
   | `observer`, `dbg`, `cover`, `debugger`, `dialyzer`, `edoc`, `common_test`, `syntax_tools`, `parsetools`, `argparse`, `escript` | | | | tooling: `ernc --doc`, Ernest's own types, the compiler, `ern`; a command-line program parses `Sys.args` itself, an argument parser being a library |
   | `gen_*`, `supervisor`, `proc_lib`, `sys`, `logger`, `application`, `code`, `rpc`, `erpc`, `global`, `pg`, `net_kernel`, `persistent_term`, `atomics`, `counters`, `init`, `heart`, `os_mon`, `wx`, `erl_*`, the shell | | | | a function with a mailbox type, fifteen lines of `spawn` and `monitor`, `send` to a sink, MVP 3's own distribution, the runtime's internals, `ernc` and `ern` |

   Gleam's `gleam_stdlib` v1.0.5, Elixir's core, and Haskell's `base` were read the same way, and what they have that the table does not take is a position, not a gap: `gleam/order` (`Ordering.reverse` is `fn(a, b) = compare(b, a)`), `gleam/pair` and `gleam/function` (patterns and compositions), `string_tree` and `bytes_tree` (builders BEAM's binary append makes unnecessary), `gleam/uri` (a library), `dynamic/decode` (`Foreign` and a JSON library between them), `string.inspect` (no universal printer; `toString` per type), `bool.guard` (`<-`); `Optional.orElse` and `Either.orElse` wait for a program; Elixir's `Stream` (§5.1 is strict, a lazy source is a process), grapheme strings (a `Char` is a code point), `Keyword` lists (`Map`); Haskell's type classes (`toString` per type, `==` structural, `compare` per type, §3.10 and §4.8).

The standard library is then the first Ernest program of size, and the compiler's first user other than the examples.

**MVP 2.6 (the first libraries), about two weeks.** Appendix D has been written to once, for `Ets`; a pattern tried once is a guess. Four libraries written to it confirm or correct it before anyone outside writes to it, and they are the compiler's second real user. A library enters only when a paper program asks, which keeps 2.6 at four; being first-party changes nothing about the tier, since a library is not on the load path by default and not in Appendix E.

- **The paper program:** `examples/fetch.ern`, a command-line tool that fetches JSON over HTTPS and prints a report to stdout, errors to stderr, with an exit status. Its assumptions are the command-line items of step 5's table and the four libraries below; its header says so, as the other four programs' do.
- **Report first**, for what the program needs of the runtime: `Sys.args` and `Sys.env` in §8.2 and §9.7 as runtime-bound values; `Sys.stderr` with `Io.printError` and `Io.printlnError` in E.1; an exit status in §8.6; `Time` in Appendix E, over the clock's milliseconds, for the report's timestamp. Decisions log to match.
- **`libs/json`**, pure Ernest: a `Json` type, a parser over `String` returning `Either`, a printer; the first test of `<-`, `tryMap`, and `tryFold` at size.
- **`libs/tls`**, a shim over `ssl` and `public_key`: `Tls.listen`, `accept`, `connect` returning `Address(SockMsg)` with the encryption inside the socket process, so `Tcp.read`, `write`, and `close` serve both. Certificate verification is on by default; the program names the trust root and, for `listen`, its own certificate and key as PEM files, read with `public_key`; nothing else is configurable. `crypto` is reached only through these two and gets no module of its own until a program asks.
- **`libs/http`**, Ernest over `Tcp` and `Tls`: request and response types, a client. No server; that is the webserver example's job, and the plan's position on HTTP servers stands.
- **`libs/base64`**, a shim over `base64`, which HTTP authentication needs.
- Each library is an Ernest source root under `libs/<name>/` that a program adds with `--load-path`, with tests under the same discipline as `stdlib/`, a README of its own, and no entry in Appendix E. Their own repositories later, when there is a package story. Appendix D is corrected where the four disagree with it, report first.
- **The report lists them.** A new informative appendix, "First-party libraries", one section per library with its exported signatures and their contracts, as Appendix E lists the standard library, and a mirror test holding each library's compiled interface equal to it, as `ern_prelude_tests` holds the prelude tables to Appendix E. Third-party libraries are not listed; Appendix D is what they follow.
- **Out of 2.6:** `Regex`, `Crypto`, `Uri`, `Zlib`, until a program asks; an HTTP server; a package manager.

**MVP 3 (distribution with content addressing).**

- Every definition gets a hash of its typed AST; modules are named by hash; a registry per node `{Hash -> Module}`. A message with a function carries the hash, and a node that lacks it fetches the code from the sender. Erlang's module distribution is not used.
- `spawn(Peer(name), f)` and `remote(f)` over the peers in `ernest.conf`, authenticated with the configured keys: the node-to-node connection is `ssl` with the peer's public key from `ernest.conf` as the only trust, read with `public_key`, inside `ern`, and a program never sees either module. `remote` picks among peers flagged `"remote-peer": true` by load, criterion to be chosen then.
- Peer loss as §10 says: every process on the lost peer dead with `Fault("peer lost")`, monitors delivered, pending `remote` calls `Left(PeerLost)`; a peer that reappears is a new instance.
- Two nodes with different versions of one type: reject at send, each message carrying its type hash and an unknown hash refused with a fault or `Left`; fetch on receipt waits for a program that needs it. The decisions log has the two shapes.

**MVP 4 (optimizations and general receive guards).**

- A runtime-managed mailbox: a ring buffer the runtime fills from the BEAM mailbox and scans with compiled clause functions in arrival order. It lifts the MVP 1 restriction on `receive` guards (2.2) and makes selective receive independent of BEAM's; every `receive` pays for it, which is the price of §5.9's general guards.
- Erlang side: `process_flag(priority, ...)` and scheduling hints.

**Toolchain, no MVP yet.** A canonical formatter, `ernc --format`, one style and no configuration, mechanical over the grammar; it lands before a second person writes Ernest. `Slot(a)`, a one-shot credit parallel to `Reply(a)` for backpressure, waits until the credit protocol has been written as a convention three times; the decisions log has its shape.

No HTTP server or database connectors are planned; those are libraries for others to write on the foreign-library pattern of Appendix D, as MVP 2.5 step 5 lists. MVP 2.6 writes the first four libraries, JSON among them, to prove the pattern.

MVP 1 is about nine working weeks and shows that the chain holds, not that the design holds. The latter is decided beforehand, on paper.
