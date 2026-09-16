# Ernest report — consolidated change summary

For the next reviewer pass on [`ernest.md`](ernest.md). Groups the changes made across all review rounds by area, so a reader who last saw an earlier revision can locate the differences without walking `ernest-decisions.md` end-to-end. Report sections are cited so the current wording is one lookup away.

## Reading order for a re-review

If you're catching up on many rounds: start with §0 and §4.2 (the module system settled into its current shape only in the most recent round), then skim §3.9 (type-variable kinds and inferred restrictions) and §6.6 (reply ownership). Everything else is refinement.

If you're checking against a specific earlier review: the sections below map areas to the report sections where the current text lives.

## What has not changed

Preserved from the earliest rounds:

- Two organizing concepts: pure functions with HM types, and processes with typed mailboxes (§0).
- Five principles (§0). Least surprise is the final arbiter.
- Hand-written recursive-descent parser with first-token dispatch and bounded lookahead; no backtracking (Appendix A epilogue).
- Standard Hindley-Milner inference with a mailbox-effect slot on the arrow; no row polymorphism, no user-defined effect handlers (§3.9).
- Total prelude philosophy with a listed set of deliberate faulting operations (§7.4).
- Content-addressed code shipping with no reconnection semantics (§8.7, §10).
- BEAM as the target runtime.

## What did change, by area

### Grammar and reserved words (§2.4, §3, Appendix A)

- Sixteen → seventeen reserved words: added `export`.
- `recv` → `receive`; `opaque` → `abstract`; unit type `()` → `Void`; cons `+:` → `::`; concat `++` → `<>`; text type → `String`; `Nat` removed.
- Tuples require `#(...)` prefix; `<<...>>` for bitstrings; `#(` and `<<` are single tokens.
- Negative numeric patterns admitted: `AtomPat` includes `literal | "-" ( int | float )`.
- `ParenType = "(" Type ")"` production for grouping — `(A) -> ((B) -> C) with M` expressible.
- Lambda after `|>` must be parenthesized.
- Match/receive "arms" → "clauses".
- Constructor "payloads" → "fields" (except message-payload uses).
- `Declaration = [ "export" ] ( TypeDecl | ... )`. Declaration-side names use `DeclName = [ typename "." ] ( ident | binop )` — no file-namespace prefix at declaration sites; single-typename prefix reserved for abstract-type accessors.
- `Name` and `QTypeName` productions removed (replaced by `DeclName` for declarations, `QName` unchanged for use sites).

### Type system (§3.9, §3.10)

- Effect polymorphism specified: mailbox effect can be a type variable, generalized alongside other type variables.
- One kind of type variable; position controls whether *empty* is admissible. `self : () -> Address(m) with m` and `apply : ((a) -> b with e, a) -> b with e` now share one rule.
- Prelude primitives (`send`, `spawn`, `Address.call`, `answer`, `monitor`, `kill`, `remote`, `parallelRemote`, `receive`) are non-empty — pure code cannot invoke them.
- Three inferred restrictions consolidated in §3.9: equality (from `==`), non-empty effect, not-reply-carrying. All propagate through function values, branches, and compiled module interfaces.
- Block bindings: escape path (variables can escape to the enclosing scope through the block's result); wildcard `let _ = e` is a discard that suppresses variable-resolution requirements.
- Top-level `let` generalizes; block `let` is monomorphic.
- Top-level `let` initializers must be pure; evaluated in dependency order before `main`.

### Reply ownership (§6.6)

- Extended from `Reply(a)` to any *reply-carrying type* — a type that transitively contains a `Reply(a)`.
- Six consumption forms listed: `answer`, delegation to a reply-carrying parameter, `send`, placement into a constructor / tuple, return from a reply-carrying return type, spawn-lambda capture.
- Pattern-match on a reply-carrying scrutinee transfers the obligation to bound reply-carrying fields; nullary case discharges.
- Wildcard omission of a reply-carrying field and `as` on a reply-carrying scrutinee are type errors.
- `Address.call`'s `mk` callback grounded: reply consumed by placement + return.

### `Address.call` semantics (§6.6)

- Mandatory timeout; `Address.callForever` opts out by name.
- Deadline starts at invocation.
- Late answers silently discarded after timeout.
- Reply mechanism is private (works in `Never` mailbox).
- Race between reply and timeout has no deterministic tiebreak.

### Distributed failure (§8.6, §10)

- Loss is terminal from the observing node's view.
- Peer reappearance is a new instance; no reconnection.
- `send` best-effort; in-flight messages at loss dropped.
- Deadlock detection is per-node; external event sources prevent false positives (`Sys.*` subscriptions, timers, pending I/O, connected peers with pending outgoing computation).
- `main` return terminates *local* processes; remote workers unaffected.

### Numeric types (§3.1, §3.10)

- `Int` arbitrary precision. Division truncates toward zero; `Int.div` / `Int.mod` return `Optional`.
- `Float` finite-only, IEEE 754 binary64 round-to-nearest ties-to-even. Overflow, div-by-zero of non-zero numerator, and `0.0 / 0.0` fault. Gradual underflow to signed zero is not a fault.
- No `Infinity` or `NaN`; `Float.compare/round/floor/ceil` are total.
- `Int.toFloat` faults on out-of-range integers.

### Bitstrings (§5.11, §7.4)

- `bytes` unit 8; `bits` unit 1. Both must bind to byte-multiple lengths when binding to `Bytes`; sub-octet fields use `int`.
- Compile-time constant alignment violations are compile-time errors; dynamic violations fault or fail-match.
- `size(Expr)` in a pattern is pure; a fault in `Expr` faults the process.

### Foreign code and ABI (§4.7, §8.4, Appendix D)

- Foreign-boundary promises: three checked breaches (wrong return type, thrown exception, malformed foreign message) fault the *receiving* Ernest process. Purity is a trusted promise, not checked.
- §8.4 ABI table added: base types, constructors (quoted-atom source-preserving tags), tuples, lists, `Void`, `Address`/`Reply`/functions as opaque handles.
- Same-named constructors of different types share an atom; receiver's declared type disambiguates.
- Case-preserving constructor atoms (`'Ready'` distinct from `'READY'`).
- Named-field canonical layout: lexicographic ASCII field-name order for storage, hashing, and transport. Source-order evaluation preserved.
- Appendix D (Ets shim) updated; `{ok, V}` from Erlang no longer auto-maps to Ernest `Either` — either decode with a `match` or use an Erlang helper that produces quoted-atom form.

### Code shipping (§8.7)

- Full contract added for peer ship (`spawn(Peer, ..)`, `remote(f)`, and `send` to a remote address).
- Content-addressed identity for functions, constructors, types.
- Recursive definitions hashed as SCC groups.
- Normalization strips α-conversion and reorders named-field declarations into canonical order; function bodies preserve source evaluation order.
- Abstract-type hash includes qualified name and exported signature — not only representation.
- Peer-side `Sys.*` resolves on the peer; captured address values retain their sender-side target; top-level bindings evaluated on demand in the peer's environment.
- Any cross-node transport of a value transitively containing a foreign value faults.
- Failure model: `Left(PeerLost)` covers unreachable peer, resolution failure, and callback fault. Remote-`send` failures fault the sender asynchronously.

### Modules, namespaces, and `main` (§4.2, §4.4, §8.1) — most recent round

- **Files are namespaces.** A file at `a/b/c.ern` under the source root provides declarations at namespace `A.B.C`.
- **Canonical typename form.** Each namespace segment is the first-letter-cap of the corresponding path segment (`http.ern` → `Http`, `http_server.ern` → `Http_server`). One-to-one with the lowercase path.
- **Declarations use local names.** `export fn parse(...)` in `net/http.ern` exports as `Net.Http.parse`. The file-namespace prefix is never written at declaration sites.
- **`export` marks cross-module visibility.** Applies to `fn`, `type`, `abstract type`, `let`, `foreign fn`, `foreign type`. Constructor visibility follows the enclosing type.
- **Type-member declarations** — any locally declared type `T`, concrete or abstract, creates a nested namespace `T`. Members are declared with `T.` prefix (`fn Distance.+`, `fn Stack.push`). The file-namespace prefix is still implicit.
- **Module ownership of type-member namespaces.** `Main.Stack.push` is compiled into the same `.erc` as `Main.Stack` (the enclosing module's), not a hypothetical `main/stack.erc`. The compiled interface records ownership so the loader routes qualified references correctly.
- **Case rules:** path segments are lowercase; the canonical typename form is the source of truth. Two path segments whose lowercase forms coincide is a compile-time error. Portable across case-insensitive filesystems.
- **`main` is a naming convention.** Any file's `export fn main() -> Void with m` is an entry-point candidate. `ern module.erc` looks up `main` in the loaded module; `--main Qualified.Name` overrides. Multiple entry-point modules per project.
- **No "root namespace" concept.** The prelude occupies the unnamed top; every user file is at some namespace.

### Toolchain (§11.1, §11.2)

- `ernc [-I src-root] [-o build-dir] file.ern` — single-file compile with explicit source root and output directory.
- `ernc [-I src-root] [-o build-dir] src-dir` — directory mode: walks the tree in dependency order, mirrors outputs, creates missing directories.
- **Output path formula:** `output = build-dir / relpath(source-file, source-root)`. When `-o` is omitted, `build-dir` defaults to the source root.
- **Cleanup scope:** the sweep is confined to the subtree mirroring the compiled source subtree. `ernc -I src -o build src/net` sweeps `build/net/`, not `build/`. `--no-clean` disables.
- Path-shape rejection applies only to `.ern` files the compiler considers as modules (and their intermediate directories to the source root). Unrelated content under the tree (`.ernest/`, `README.md`, editor artifacts) is ignored.
- `ern [--config-dir dir] [--load-path dir ...] [--main Qualified.Name] file.erc` — runner. `--load-path` replaces the previous `-pa`.
- **Type-member loading:** `A.B.C.T.member` uses the compiled interface of `a/b/c.erc` (which owns type `T`), not `a/b/c/t.erc`.

## Where to look for specific things

| Question | Section |
|---|---|
| What is a namespace and how do I get one? | §4.2 |
| How do I make a declaration visible outside its module? | §4.2 (`export`) |
| How does the ownership discipline on `Reply` work? | §6.6 |
| What faults, and where? | §7.4 (list); §3.1 (Int/Float); §5.11 (bitstrings); §8.7 (code shipping); §3.8 (foreign values) |
| Does `main` have to be in a specific file? | §8.1 (no; the runtime picks it) |
| How is code shipped to a peer? | §8.7 |
| What does the ABI look like on BEAM? | §8.4 |
| How do abstract types work? | §4.4 |
| How does `Address.call` handle a late answer? | §6.6, subsections *Late answers* and *Mailbox isolation* |
| How does deadlock detection work? | §8.6 |
| Grammar? | Appendix A |

## Rationale and rejected alternatives

Each of the choices above is expanded in [`ernest-decisions.md`](ernest-decisions.md) — one dated entry per change, with the alternatives weighed and the reason for the pick. That document is not intended for reviewer consumption in one sitting; use it as a lookup when a specific decision needs deeper background.

## Companion documents in this repository

- [`ernest.md`](ernest.md) — the report; normative.
- [`ernest-guide.md`](ernest-guide.md) — tutorial guide; not normative. The recent module-system changes are reflected there too.
- [`ernest-decisions.md`](ernest-decisions.md) — dated decisions log.
- Paper programs: [`ernest-tick-game.md`](ernest-tick-game.md), [`ernest-repl.md`](ernest-repl.md), [`ernest-filesync.md`](ernest-filesync.md), [`ernest-webserver.md`](ernest-webserver.md).
- [`ernest-implementation-plan.md`](ernest-implementation-plan.md) — MVP roadmap.

The report and the guide are the two documents intended for review; the rest is supporting material.
