# Ernest — Claude Instructions

## What Ernest is

A functional language for concurrent programs, designed by the user (joagre). Two concepts: pure functions (Hindley-Milner) and processes with typed mailboxes. See [`ernest_report.md`](ernest_report.md) for the full report.

## Normative structure

- **[`ernest_report.md`](ernest_report.md) is the single normative document.** Nothing else in this repo overrides it.
- **Appendix A (grammar) is the truth.** Any conflict between prose and Appendix A is resolved in favor of Appendix A. The lexer and parser must accept exactly the language of Appendix A and reject everything else.
- **Section 0 (Introduction + five principles) is the tiebreaker.** When Appendix A leaves something ambiguous, or a design decision is under discussion, resolve it by section 0's principles. Principles 2–5 (one way, one job; nothing invisible; simple to parse — recursive descent with bounded lookahead; small) are the constructive rules; principle 1 (least surprise) is the backstop that audits the resulting code.
- **[`docs/decisions.md`](docs/decisions.md) is rationale only.** It explains *why* the report says what it says; it is updated only when [`ernest_report.md`](ernest_report.md) is updated. Never treat it as normative and never edit it in isolation.
- **The programs under `examples/` and the plan in `docs/implementation_plan.md` are illustrative**, not normative. Use them as motivating examples and roadmap, not as sources of truth.
- **The report can be updated if we find anomalies** while implementing the example programs (counter, ping-pong). When that happens, update [`ernest_report.md`](ernest_report.md) first, then reflect the reason in [`docs/decisions.md`](docs/decisions.md), then adjust code.

## Current task (from [`docs/implementation_plan.md`](docs/implementation_plan.md), Phase 1.1)

Build a lexer and parser that reads Appendix A and rejects everything else.

- Implementation language: **Erlang** (OTP 27). The compiler is `ernc`, the runner is `ern`. See the plan for architecture.
- Hand-written Pratt parser for expressions; recursive descent for declarations. First-token dispatch with small bounded lookahead (the constructor-fields peek documented in Appendix A, the FnType-vs-ParenType decision after the closing paren, and `fn` followed by an identifier versus `(`), no backtracking.
- Seventeen reserved words. `true`/`false` are literals, not keywords in the general sense.
- Patterns via a small Pratt loop with `::` right-associative and postfix `as ident`.
- AST as Erlang records with `{line, column}` on every node.

## First test programs

- **Counter** (with `Upgrade` code replacement) — see the sketch in [`ernest_report.md`](ernest_report.md) §6.
- **Ping-pong** — see [`ernest_report.md`](ernest_report.md) Appendix B.

If either test surfaces an anomaly in the report, propose an update to [`ernest_report.md`](ernest_report.md) (and matching [`docs/decisions.md`](docs/decisions.md)) before working around it in the parser.

## Working style

- Prefer minimal, direct implementations over speculative abstraction.
- Ask before scaffolding when a decision affects the report or the plan.
- When touching normative material, quote the exact section or grammar rule being applied.

## Ernest style guide

Ernest is order-independent at top level; these are style choices, not correctness. Follow them consistently.

- **Top-down layout.** Types first. Then `main` (in program modules) or exported functions (in library modules). Each root's helpers follow immediately below it, before the next root. Shared helpers go with the first user, or in a bottom utilities section if genuinely shared.
- **Four-space indent, no tabs.**
- **No alignment padding, anywhere.** Don't add spaces to align tokens across lines: `->`, `=`, trailing `//` comments, anything. Structural indentation (block bodies, clause separators) isn't padding — that stays. One space where a space is needed.
- **Code lines ≤ 100 characters.** Split long expressions rather than let one line run wide. Prose in markdown can be longer.
- **Block-comment banners for sections.** Open with `//` on its own line, one or more `// text` lines, close with `//` on its own line. Blank line before the opening, blank line after the closing. Not `// Section ----------`.
