# Ernest Report Changelog

A curated summary of the changes made to [`ernest.md`](ernest.md) during design and review. Ordered by area rather than by commit; within an area, entries run roughly chronological. For per-commit rationale and rejected alternatives, see [`ernest-decisions.md`](ernest-decisions.md); for the current state of any rule, [`ernest.md`](ernest.md) is authoritative.

## Grammar and syntax

- **Sixteen → seventeen reserved words.** Added `export` for cross-module visibility on top-level declarations.
- **`recv` renamed to `receive`** (report-wide sweep).
- **`opaque` renamed to `abstract`** for abstract types.
- **Text type renamed to `String`.**
- **`Nat` removed** in favour of a total `Int` API.
- **Unit type/value renamed from `()` to `Void`.**
- **Cons operator renamed from `+:` to `::`; string concat from `++` to `<>`.**
- **Match/receive "arms" renamed to "clauses"** (matches Erlang/Haskell/SML tradition).
- **"Bit arrays" renamed to "bitstrings"** (matches Erlang's name).
- **Constructor "payloads" renamed to "fields"** (except message-payload uses).
- **Tuples require `#(...)` prefix** to keep them distinct from expression grouping and function types.
- **`ParenType = "(" Type ")"` production** added for function-type grouping — lets you write `(A) -> ((B) -> C) with M` (function returning a pure function).
- **Negative numeric patterns** admitted: `AtomPat = ... | literal | "-" ( int | float ) | ...`.
- **Lambda after `|>` must be parenthesized** (`x |> (fn(y) = y + 1)`); the report and Appendix A both state this explicitly.
- **Grammar first-token dispatch note** in Appendix A epilogue lists `#(` for tuples, `<<` for bitstrings, and the greedy constructor-suffix rule for `QName` when a `conname` is followed by `(`.
- **`Declaration = [ "export" ] ( TypeDecl | AbstractDecl | FnDecl | LetDecl | ForeignDecl )`.** Declarations use `DeclName = [ typename "." ] ( ident | binop )` — no file-namespace prefix at declaration sites, single-typename prefix for abstract-type accessors.
- **Max-munch tokens listed** in §2.6 (`>>`, `<-`, `->`, `==`, `!=`, `<=`, `>=`, `&&`, `||`, `|>`, `<>`, `::`, `#(`, `<<`, `..`).
- **`|` is a delimiter, never a `binop`.** The Pratt loop terminates at `|`.

## Type system and inference

- **Effect polymorphism specified** in §3.9: a function type's mailbox effect can be a type variable, generalized alongside other type variables.
- **One kind of variable, position controls admissibility.** A variable in a value position resolves to a value type; a variable in an effect position may bind to a mailbox type or *empty* (pure). A variable that appears in both cannot be empty. This resolves the two occurrences of `m` in `self : () -> Address(m) with m`.
- **Primitives are non-empty.** `send`, `spawn`, `Address.call`, `answer`, `monitor`, `kill`, `remote`, `parallelRemote`, and the `receive` expression form have outer effect variables that cannot bind to empty — pure code cannot invoke them. Closes the U01 soundness hole.
- **Two-callbacks-with-independent-effects rule.** Ernest has no effect union; two effect variables in one body unify to the outer function's single effect.
- **Higher-order effect polymorphism** made explicit in Appendix E's `List.map`, `List.foreach`, `Map.map`, `List.foldLeft`, `List.find`, `List.any`, `List.all`, `List.span`, `List.sort`, `List.filter`, `List.filterMap`, `Map.foldLeft`, `String.all`, `Optional.map`, `Optional.andThen`, `Either.map`, `Either.mapLeft`, `Either.andThen` signatures.
- **Equality constraint on polymorphic types.** A function using `==` on a type variable induces an implicit equality restriction, checked at instantiation, propagated through function values, branches, and compiled module interfaces.
- **Inferred restrictions on type variables** consolidated (§3.9): equality, non-empty effect, not-reply-carrying. All propagate the same way through the type scheme.
- **Not-reply-carrying restriction** (from U03): a generic function that duplicates or discards its parameter cannot be instantiated with a reply-carrying type.
- **Block bindings: escape path and wildcard rule.** A block `let p = e` binds `p` monomorphically. Unresolved variables can escape to the enclosing scope through the block's result type (so `fn namedEmpty() = { let xs = []; xs }` is polymorphic). `let _ = e` is a discard; unresolved variables in `e` never propagate.
- **Top-level `let` generalization.** Top-level `let` generalizes over free type variables (so `let empty : Stack(a) = ...` works). Block `let` remains monomorphic.
- **Top-level `let` initializers are pure** and evaluated in dependency order before `main`.
- **Reply ownership extended from `Reply(a)` to reply-carrying types** (§6.6): any type transitively containing a `Reply(a)`. Six consumption forms listed. Pattern-match on a reply-carrying scrutinee transfers the obligation to bound reply-carrying fields; a nullary case discharges. Wildcard omission of a reply-carrying field and `as` on a reply-carrying scrutinee are type errors.

## Numeric types and Float semantics

- **`Int` is arbitrary precision.** Division `/` truncates toward zero; `%` matches. `Int.div` and `Int.mod` return `Optional(Int)` instead of faulting.
- **`Float` committed to finite-only.** IEEE 754 binary64 round-to-nearest ties-to-even, restricted to the finite range. Arithmetic that would produce a non-finite result (overflow, div-by-zero of non-zero numerator, `0.0 / 0.0`) faults with `Fault("float arithmetic error")`. Gradual underflow to signed zero is not a fault.
- **`Float.compare`, `Float.round`, `Float.floor`, `Float.ceil` are total** on the finite domain.
- **`Int.toFloat` faults** on integers whose magnitude exceeds the largest finite `Float`; in-range values round to nearest with ties to even.
- **Removed `sqrt` mention** from §§3.1 and 7.4 (the report declares no `sqrt`).

## Bitstrings

- **`bytes` specifier byte-aligned** (unit 8); `bits` remains for construction. Both must be byte-multiple when binding to `Bytes`; sub-octet fields use `int`.
- **Total bit count must be a multiple of 8.** Compile-time constant violations are compile-time errors; dynamic-size violations fault at construction or fail matching in patterns.
- **`size(Expr)` in a pattern** is pure (no mailbox effect); scope is earlier-bound segment variables + enclosing scope; a fault in `Expr` faults the process.
- **Frame precondition stated:** for `<<len:size(16)-big, body:bytes>>`, `len` must fit the 16-bit field and match the body's byte count.

## Faults and initialization

- **§7.4 opening softened:** "The operations listed below deliberately fault on specified inputs or runtime conditions. Absence of a mailbox effect does not guarantee absence of faults."
- **Fault list completed:** Int `/`, `%`; Float arithmetic operations; bitstring segment overflow and per-segment alignment; `todo`; cross-node foreign-value transport; `spawn(Peer, ..)` unreachable or resolution failure; remote-`send` async resolution failure; invalid foreign returns.
- **`Fault` is a `Reason`** alongside `Killed`, `Returned`, `ProgramEnd`; each carries a distinguishable cause.
- **Initialization can fail:** a top-level `let` initializer that faults ends the program before `main`; a nonterminating initializer prevents unrelated ones from being reached. Which of two independent faulting initializers is reported is unspecified.
- **Cycle detection:** within-module cycles caught at compile time; cross-module cycles at load time.

## Processes, addresses, and concurrency

- **Reply-request pattern specified** in §6.6: `Address.call(addr, mk, ms)` allocates a fresh `Reply(a)`, invokes `mk(r)` to build the message, sends it, and returns `Some(v)` or `None` on timeout.
- **`Address.callForever(addr, mk)`** for the no-timeout variant.
- **Late-answer semantics:** after `Address.call` returns `None`, a subsequent `answer(r, v)` from the recipient is silently discarded by the runtime.
- **Mailbox isolation:** reply values are delivered via the `Reply`'s fresh identifier, never appearing in the caller's declared mailbox.
- **Timeout deadline starts at `Address.call` invocation.** `None` does not cancel the recipient's work; a reply arriving exactly at the deadline may be delivered or discarded.
- **`Address.call` works in a `Never` mailbox** — the reply mechanism is separate from the declared mailbox.
- **`remote` and `parallelRemote` gained mailbox effects.** Callback is pure (compute-and-return contract); the outer operation carries `with m`.
- **Distributed failure model:** loss is terminal from the observer's view; peer reappearance is a new instance; `send` is best-effort while reachable; in-flight messages at loss are dropped.
- **Deadlock detection** is per-node; external event sources (`Sys.*` subscriptions, timers, pending I/O, connected peers with pending outgoing computation) prevent false conclusions.
- **`main` de-specialized.** Entry point is any `export fn main() -> Void with m` in any module; runtime chooses via `ern module.erc` (default: loaded module's `main`) or `--main Qualified.Name`.
- **Local process termination scoped to local** (`ProgramEnd`); remote workers on peer nodes are unaffected by the initiating program's exit.
- **Ping-pong example** uses `monitor(pongAddr, PongDone)` and waits on the notification.
- **Ping-pong output labelled a possible trace** — cross-sender stdout ordering isn't guaranteed.

## Modules and namespaces (recent overhaul)

- **Files are namespaces.** A file at `a/b/c.ern` under the source root provides declarations at namespace `A.B.C`.
- **Path segments are lowercase.** `Net.Http.parse` is at `net/http.erc`. Two typename segments whose lowercase forms coincide (`Http` and `HTTP`) is a compile-time error.
- **Declarations use local names.** No file-namespace prefix at declaration sites. `export` marks cross-module visibility.
- **Abstract-type accessors** carry the type-name prefix (`fn Stack.push(...)`) — the one qualified-declaration form.
- **Constructor visibility follows the type:** `export type Optional(a) = None | Some(a)` exports `None` and `Some`.
- **Strict path-based ownership:** a declaration `A.B.C.name` lives exclusively in `a/b/c.ern`.
- **Abstract types hashed by qualified name + exported signature**, not private representation; independent implementations of the same abstract type do not silently interoperate across nodes.
- **Compiled `.erc` files carry inferred types** for cross-module type-checking.
- **No more "root namespace"** as a first-class term. Prelude occupies the unnamed top of the hierarchy (runtime-provided); every user file is at some namespace.

## Code shipping and distribution

- **§8.7 Code shipping section added** — full contract for how `spawn(Peer, ..)`, `remote(f)`, and `send` to remote addresses ship closures and dependencies.
- **Content-addressed identity:** functions, constructors, and types are identified across nodes by hash of normalized definition plus dependencies.
- **Recursive definitions hashed as SCC groups** with internal indices for intra-group references.
- **Normalization:** strips local variable names (α-conversion); named-field layouts use lexicographic ASCII order; function bodies preserve source evaluation order.
- **Dependency resolution before execution.** Any resolution failure surfaces as `Left(PeerLost)` for `remote` or as a caller fault for `spawn(Peer, ..)`. Remote-`send` failures fault the sender asynchronously.
- **Peer-side `Sys.*` resolution.** Shipped code's `Sys.stdout` reference resolves on the peer, not the sender.
- **Captured address values retain their targets.** A closure capturing `Sys.stdout` from the sender still points to the sender after transport.
- **Top-level bindings on peers initialized on demand** in the peer's environment; per-node result may differ from sender's if the initializer references `Sys.*`.
- **Node-bound foreign values.** Any cross-node transport of a value transitively containing a foreign value faults with `Fault("foreign value cannot cross nodes")`.

## Foreign code and ABI (Appendix D + §8.4)

- **§8.4 ABI table** added: BEAM-side mapping for base types, constructors (quoted-atom, source-preserving), tuples, lists, `Void`, `Address`/`Reply`/function values as opaque handles.
- **Injective constructor tags:** `Ready` and `READY` map to distinct atoms `'Ready'` and `'READY'` (no case folding on the wire).
- **Foreign-boundary fault attribution:** three runtime-checked breaches (wrong return type, thrown exception, malformed foreign message) fault the *receiving* Ernest process on first observation; purity is a trusted, non-checked promise.
- **Appendix D (Ets shim)** rewritten twice: first to fix pre-sweep syntax and the `atom("ernest")` native-type mismatch, then to align with §8.4's quoted-atom ABI. `{ok, V}` from Erlang APIs no longer auto-maps to Ernest's `Either`; a shim decodes or an Erlang helper produces the quoted-atom form.
- **`export` extended to `foreign fn` and `foreign type`** with the same rule as ordinary declarations.

## Toolchain (§11)

- **`ernc [-I src-root] [-o build-dir] file.ern`** — single-file compile with explicit source root and output directory.
- **`ernc [-I src-root] [-o build-dir] src-dir`** — directory mode: walks the source tree, compiles in dependency order, mirrors outputs under `build-dir`, creates missing intermediate directories.
- **Build-directory cleanup:** after successful directory-mode compilation, `.erc` files whose mirror-source `.ern` is gone are removed, along with directories that become empty. Only `.erc` files and empty directories are touched; `--no-clean` disables the sweep.
- **Path-shape rejection:** below any source or load-path root, each directory component and `.ern`/`.erc` filename stem must match `[a-z][a-z0-9_]*`; extensions are exactly `.ern`/`.erc`. Violations are compile-time errors.
- **`ern [--config-dir dir] [--load-path dir ...] [--main Qualified.Name] file.erc`** — runner with load-path extension and entry-point override. `--load-path` replaces the previous `-pa` (Ernest is not Erlang).
- **`ern --create-config-dir dir`** creates `.ernest/` with `ernest.conf` and a fresh private key.
- **`ern --repl`** starts a REPL.
- **`ernc --doc file.ern`** extracts doc comments (`///`) to markdown.

## Section 0 — Introduction and principles

- **Ernest introduced with two concepts:** pure functions (HM types, full inference) and processes with typed mailboxes.
- **Five principles** (numbered §0.1–§0.5 in text): least surprise; one way, one job; nothing invisible; simple to parse; small.
- **"Ambient values"** renamed to "top-level bindings" or "top-level references"; principle 3 refined to say a top-level binding is visible when its name appears at the use site, but hidden effects are not.

## Small but important corrections

- **Guards in `match` / `receive` are pure** (`Bool`, no mailbox effect); a guard that evaluates to `false` falls through; a guard that faults faults the process.
- **`monitor` and `via`** consolidated: `monitor(child, wrap)` is a special case of the `via` shape.
- **Reserved-word list count** ensured to be exactly 17 across §2.4, Appendix F glossary, and CLAUDE.md.
- **`Never` (uninhabited)** vs **`Void` (unit)** distinguished; `main`'s send-only mailbox is `Never`, its "no interesting return" is `Void`.
- **Pipe (`|>`) semantics** clarified for chained calls: `x |> f(a)(b)` fills the outermost call — `f(a)(x, b)`, not `f(x, a)(b)`.
- **Constructor-call ambiguity** resolved (editorial): when a `conname` is immediately followed by `(`, the parser consumes it as part of `QName`'s constructor-fields suffix, not as a subsequent `Call`.

---

**Report state today:** 1,373 lines, 17 reserved words, five principles held. The typing rules, effect system, and reply-ownership discipline haven't changed since the module-and-toolchain overhaul; the surface language (grammar productions, `export` keyword, path conventions) is what the recent rounds have moved.

For chronological detail on any single decision — including alternatives considered and rejected — see [`ernest-decisions.md`](ernest-decisions.md).
