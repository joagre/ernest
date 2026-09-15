# Response to fourth-round review

## Design decisions taken

- **N01 — canonical field order.** Named fields are stored, hashed, and transported in canonical order (sorted by field name). §3.5, §8.4, §8.7 all reference this order. Field expressions are still evaluated in source order per §5.1; their values are placed into canonical positions. Two nodes declaring the same-named type with different source field order now agree on both hash *and* on-wire layout.

- **N02 — injective constructor tags.** Constructor atoms preserve source spelling in a quoted BEAM atom: `'Ready'` and `'READY'` are distinct. §8.4 updated. Same-named constructors of different types still share an atom on the wire, disambiguated by the receiving type — the injectivity is *within* a type.

- **N03 — function-value use before initialization.** §5.4's rule extended from "called" to "used" (called, obtained as a value, passed, stored, returned, captured by another closure). `invoke(read)` before `read`'s captures are initialized is now rejected at the point where `read` is obtained. Dependency graph is references between local functions — same graph, wider notion of use.

- **N04 — underflow to signed zero is finite.** §3.1 and §7.4 corrected: gradual underflow to signed zero is not a fault. Faults are limited to overflow, division by zero of a non-zero numerator, `0.0 / 0.0`, and `sqrt` of a negative value. `Int.toFloat` faults on integers whose magnitude exceeds the largest finite `Float` (`Fault("Int out of Float range")`); in-range values round to nearest per IEEE.

## Small corrections applied

- **§6.2** — spawn example fixed to `fn() -> Void with Never = Void` (grammar requires `->`).
- **§8.4** — added `Map(k, v)` and `Set(a)` as opaque runtime handles backed by BEAM's `maps`.
- **§6.6** — late-answer paragraph now notes that cross-node foreign-value fault (§3.8) still applies to `answer` with a remote caller.
- **§7.4** — heading renamed "The total prelude" → "Prelude operations and faults".
- **§5.3** — lambda-body termination delimiter list extended to include `]` and `>>`.
- **Appendix A** — constructor-call canonical parse sentence adopted verbatim from the review.
- **Appendix E.10 / E.11** — `Optional.map`, `Optional.andThen`, `Either.map`, `Either.mapLeft`, `Either.andThen` signatures now show explicit effect variables.

## Cost of this round

Eight section edits, five stdlib signature updates. No new keyword, no new type, no new operator, no new type-system machinery.

## Constructor-call parse

The reviewer's suggested wording — "When a constructor name is immediately followed by a parenthesized constructor argument, the parser consumes that argument in the constructor branch of QName; a single-positional construction has the semantics of calling the constructor's function value." — is now in the Appendix A epilogue.

Full rationale and rejected alternatives: `ernest-decisions.md` (entry dated 2026-09-15 titled "Fourth-Round Review Response").
