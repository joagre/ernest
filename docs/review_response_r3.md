# Response to third-round review

## Design decisions taken

- **Float — committed to finite-only.** IEEE 754 doubles restricted to the finite range; arithmetic that would produce a non-finite result (overflow, div-by-zero, `0.0 / 0.0`) faults with `Fault("float arithmetic error")`. Aligns with BEAM's native domain; no representation extension needed. Net simplification: removed the IEEE-exception paragraph in §3.10, the Map/Set-Float restriction, and `Float.isNaN` from Appendix E.9. `Float.compare`, `Float.round`, `Float.floor`, `Float.ceil` are total.

- **R07 early-call — rejected.** §5.4: a local `fn` may only be *called* after every `let` binding it references — directly or through calls to other local `fn`s in the same block — has been evaluated. The check follows local-function call edges to catch indirect dependencies.

- **U01 pure spawn callback — rejected.** §6.2: `spawn`'s callback mailbox effect `n` (also in `Address(n)`) must be a real mailbox type. A pure callback must annotate `with Never` (`fn() : Void with Never = ...`).

- **Three inferred restrictions unified.** §3.9 gains one paragraph naming *equality*, *non-empty effect*, and *not-reply-carrying* as inferred restrictions that propagate through function values, branches, and compiled module interfaces, and are surfaced in diagnostics. Same treatment for all three; no new syntax.

- **U07 PeerLost — kept unified.** No new error constructor. Added: `Left(PeerLost)` signals that a specific `remote` operation did not complete; it does not invalidate other `Address` values held for the same peer, which are only invalidated by actual peer-loss detection (§10).

- **Remote-send failure — asynchronous.** `send` returns immediately (§6.2); a peer-side resolution failure faults the sending process *after* `send`'s return, once the peer runtime reports the failure.

- **R16 ABI table — added.** §8.4 now includes a compact table: base values, nullary/positional/named constructors (lowercase-atom tag, tuple with fields in declaration order), tuples, lists, `Void`, `Address`/`Reply` opaque handles, foreign values, Ernest function values opaque. Same-named constructors of different types share an atom; the receiving side's declared type disambiguates. Foreign-return breaches fault on the receiving Ernest process on first observation.

## Small repairs

- **§7.4 opening softened** to the wording you suggested.
- **§7.4 fault list** gains remote-send resolution failure; the bitstring item now covers per-segment alignment (U08).
- **§8.5 cycle detection** phases stated together: within-module compile-time, cross-module load-time.
- **§8.6 termination** scopes `ProgramEnd` to *local* processes; remotely spawned workers are unaffected by the initiating program's exit.
- **§8.6 deadlock** excludes connected peers with pending outgoing computation as "messages in flight" — a program awaiting a reply from a still-computing peer is not deadlocked.
- **§5.7 pipe/lambda** — pipe fills outermost call's first arg: `x |> f(a)(b)` is `f(a)(x, b)`; `x |> (f(a))` is `f(x, a)`.
- **Grammar** — `[ "-" ] literal` → `literal | "-" ( int | float )`; `ParenType` parsing described as consume-common-prefix-then-inspect.
- **§6.6 match transfer** — explicit: matching a reply-carrying scrutinee transfers the obligation to pattern-bound fields; nullary reply-carrying-sum case (e.g., `Stop`) discharges with no new binding.
- **U07 top-level bindings** — no longer claim results "match the sender's"; peer-local initializer runs in the peer's environment. Each initializer evaluated at most once per node per code version.

## Constructor-call ambiguity — accepted as editorial

Your R18 note that `Some(x)` has one canonical parse via `QName`'s constructor-suffix branch, and matches call semantics for single-positional constructors, is accepted. No spec change beyond the grammar description.

## Cost of this round

Twelve section edits, one new ~15-line ABI table, one new propagation paragraph. No new keyword, no new type, no new operator. Float finite-only is a net simplification.

Full rationale and rejected alternatives: `decisions.md` (entry dated 2026-09-15 titled "Third-Round Review Response").
