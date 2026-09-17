# Response to guide follow-up review

Targeted corrections applied in place — no structural change. Guide grew from 793 to 913 lines to fit completed checkpoints and coverage bullets.

## High-priority fixes

- **UG07 — abstract-type identity (§6.2).** Corrected "not by their private representation" to "not *just* by private representation". Name and signature participate in identity *alongside* content addressing; matching signatures alone do not guarantee cross-node representation compatibility. Cross-referenced §8.7.

- **UG09 — opaque foreign decoding (§7.5).** Replaced the "declare as `Foreign` and pattern-match" claim (`Foreign` values cannot be inspected by ordinary constructor patterns) with the Erlang-side helper example you suggested. The helper returns `{'Right', V}` / `{'Left', R}` matching §8.4's ABI. Also fixed the non-existent `Ok`/`Error` constructor names to Ernest's actual `Left`/`Right`.

- **UG02 — Address.call vs answer (§4.2).** Corrected the conflation: `Address.call` *consumes the constructed message by sending it*, transferring the ownership obligation to the recipient's `receive` clause. Only `answer(r, v)` finally discharges the underlying `Reply`. Restored the static-check qualification: the ownership check verifies every syntactic path calls `answer`, but does not guarantee execution reaches that call — timeouts are the caller's safety net.

- **UG06 — counter output and shutdown wording (§§4.5, 5.1).**
  - Output is now conditional: "if the call succeeds, it returns 8" and "if the deadline expires, `main` prints `counter did not answer`". The timeout branch is no longer described as dead code.
  - Shutdown softened from "would kill both children before either sends its first message" to "may terminate the children before their work finishes". `PongDone(_)` accepts every death reason.

- **§6.1 — qualified-name claim.** Softened from "top-level declarations use their qualified name at every reference" to a distinction between cross-module lookup (qualified) and within-module lookup (unqualified: module's own → enclosing namespace → prelude).

- **§3.5 — `receive` is syntax.** Split the list into prelude *primitives* (`send`, `spawn`, `Address.call`, `answer`, `monitor`, `kill`, `remote`, `parallelRemote`) and expression *forms* (`receive`, `after`). Both require a non-empty mailbox effect.

## Coverage additions

Each flagged row has an explicit rule or example beside its existing coverage:

- **§2.1** — `Int` and `Float` are separate; no implicit conversion; `Int.toFloat`, `Float.round`/`floor`/`ceil` for the boundary. Their contracts point to the report.
- **§§2.2, 3.1** — strict left-to-right evaluation; a block's final statement is an expression with no trailing semicolon.
- **§§2.5–2.6** — equality restriction extends to any type containing functions or addresses, not only direct `Map`/`Set` parameters. Guards do not count toward `match` exhaustiveness.
- **§2.7** — prelude `Optional` and `Either` definitions shown; one successful/failed Either example added.
- **§3.3** — top-level `let` initializers must be pure; effectful setup belongs in `main`.
- **§4.5** — `self()` inside a spawned callback returns the child's address; a parent that wants to hand its own address to the child must capture `self()` before spawning.
- **§5.4** — new "`Deadlock` as a safety net" subsection: per-node detection, pending timers/subscriptions/I/O/peer computations prevent a false conclusion that progress is impossible.
- **§7.6** — construction range fault added: a segment value that doesn't fit its declared width faults; the frame precondition extended to include the length field's width.

## Runnable checkpoints

The advertised checkpoints now compile to complete files:

- **§3.2** — lambda example rewritten as a valid block with `let` separators between statements.
- **§4.6** — Upgrade example completed. A `doublingCounter` replacement loop is defined; the full `main` sends `Inc(5)`, `Inc(3)`, verifies state 8, sends `Upgrade(migrate = fn(n) = n, next = doublingCounter)`, sends `Inc(1)`, verifies state 10.
- **§6.1** — modules example: `Net.Http.parse` body replaced with a tiny working implementation. Compilation-in-dependency-order shown with `ernc Net/Http.ern`, `ernc main.ern`, then `ern main.erc -pa .`; expected output `parsed`.
- **§7.1** — added a runnable `remote(fn() = heavy(3, 4))` program with all three `Either` cases handled: `Right(n)`, `Left(NoRemotePeer)`, `Left(PeerLost)`.

## Editorial

- **§1.2** — exercise reformulated as "can hello-world's `main` omit its mailbox effect while calling `Io.println`?" Answer: no.
- **§2.3** — constructor uses split into three rows: nullary (value), positional-with-one-field (also a function value), named fields (uses field syntax).
- **§5.5** — `ClockMsg` labelled as an excerpt of the prelude type; minimal `GameMsg`, `World`, `step` definitions added to make the periodic-tick example a complete definition.
- **§7.3** — foreign-boundary promises split into three runtime-checked (wrong return type, thrown exception, wrong message shape) and one not-checked (purity).
- **§9 (reading further)** — "ETS as a foreign process" → "ETS accessed through foreign functions".
- **§1 configuration** — replaced "you don't need it for local programs" with the report's actual toolchain contract: the `.ernest/` directory must exist; the peer list can be empty for programs that never invoke peer-crossing operations.

## Cost

Ten targeted section edits. No structural change. Guide grew ~15 % to accommodate the completed checkpoints and coverage bullets; still much shorter than the pre-rewrite version.

Full rationale, rejected alternatives, and per-edit details: `decisions.md` (entry dated 2026-09-15 titled "Guide Round 2: Targeted Corrections").
