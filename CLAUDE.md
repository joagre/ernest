# Ernest — Claude Instructions

## What Ernest is

A functional language for concurrent programs, designed by the user (joagre). Two concepts: pure functions (Hindley-Milner) and processes with typed mailboxes. See `docs/ernest.md` for the full report.

## Normative structure

- **`docs/ernest.md` is the single normative document.** Nothing else in this repo overrides it.
- **Appendix A (grammar) is the truth.** Any conflict between prose and Appendix A is resolved in favor of Appendix A. The lexer and parser must accept exactly the language of Appendix A and reject everything else.
- **Section 0 (Introduction + seven principles) is the tiebreaker.** When Appendix A leaves something ambiguous, or a design decision is under discussion, resolve it by section 0's principles — in order (least surprise, no variants, nothing invisible, orthogonal, LL(1)/first-token, few reserved words, small).
- **`docs/ernest-decisions.md` is rationale only.** It explains *why* the report says what it says; it is updated only when `docs/ernest.md` is updated. Never treat it as normative and never edit it in isolation.
- **The other `docs/ernest-*.md` files are illustrative programs and plans**, not normative. Use them as motivating examples and roadmap, not as sources of truth.
- **The report can be updated if we find anomalies** while implementing the example programs (counter, ping-pong). When that happens, update `docs/ernest.md` first, then reflect the reason in `docs/ernest-decisions.md`, then adjust code.

## Current task (from `docs/ernest-implementation-plan.md`, Phase 1.1)

Build a lexer and parser that reads Appendix A and rejects everything else.

- Implementation language: **Erlang** (OTP 27). The compiler is `ernc`, the runner is `ern`. See the plan for architecture.
- Hand-written Pratt parser for expressions; recursive descent for declarations. LL(1), first-token dispatch, no backtracking.
- Sixteen reserved words. `true`/`false` are literals, not keywords in the general sense.
- Patterns via a small Pratt loop with `+:` right-associative and postfix `as ident`.
- AST as Erlang records with `{line, column}` on every node.

## First test programs

- **Counter** (with `Upgrade` code replacement) — see the sketch in `docs/ernest.md` §6.
- **Ping-pong** — see `docs/ernest.md` Appendix B.

If either test surfaces an anomaly in the report, propose an update to `docs/ernest.md` (and matching `docs/ernest-decisions.md`) before working around it in the parser.

## Working style

- Prefer minimal, direct implementations over speculative abstraction.
- Ask before scaffolding when a decision affects the report or the plan.
- When touching normative material, quote the exact section or grammar rule being applied.
