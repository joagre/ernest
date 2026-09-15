# Ernest — Claude Instructions

## What Ernest is

A functional language for concurrent programs, designed by the user (joagre). Two concepts: pure functions (Hindley-Milner) and processes with typed mailboxes. See `docs/ernest.md` for the full report.

## Normative structure

- **`docs/ernest.md` is the single normative document.** Nothing else in this repo overrides it.
- **Appendix A (grammar) is the truth.** Any conflict between prose and Appendix A is resolved in favor of Appendix A. The lexer and parser must accept exactly the language of Appendix A and reject everything else.
- **Section 0 (Introduction + five principles) is the tiebreaker.** When Appendix A leaves something ambiguous, or a design decision is under discussion, resolve it by section 0's principles — in order (least surprise; one way, one job; nothing invisible; simple to parse — recursive descent with bounded lookahead; small).
- **`docs/ernest-decisions.md` is rationale only.** It explains *why* the report says what it says; it is updated only when `docs/ernest.md` is updated. Never treat it as normative and never edit it in isolation.
- **The other `docs/ernest-*.md` files are illustrative programs and plans**, not normative. Use them as motivating examples and roadmap, not as sources of truth.
- **The report can be updated if we find anomalies** while implementing the example programs (counter, ping-pong). When that happens, update `docs/ernest.md` first, then reflect the reason in `docs/ernest-decisions.md`, then adjust code.

## Current task (from `docs/ernest-implementation-plan.md`, Phase 1.1)

Build a lexer and parser that reads Appendix A and rejects everything else.

- Implementation language: **Erlang** (OTP 27). The compiler is `ernc`, the runner is `ern`. See the plan for architecture.
- Hand-written Pratt parser for expressions; recursive descent for declarations. First-token dispatch with small bounded lookahead (the constructor-payload peek documented in Appendix A, and the FnType-vs-tuple decision after the closing paren), no backtracking.
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

## Ernest style guide

Conventions for Ernest source code. Ernest is order-independent at top level, so these are style choices, not correctness requirements — but the paper programs and any Ernest code we write should follow them for consistency.

- **Define functions top-down.** Types stay at the top of the module. In a program module (has `main`), `main` comes next, then the functions it calls in call order, then their helpers, and so on — each root and its subtree are laid out contiguously. In a library module (no `main`), each exported function is a root: it appears at the top level with its own helpers immediately below it, and the next exported function's subtree follows. A helper used by more than one exported function goes under whichever root uses it first (or, if it's genuinely shared infrastructure, at the bottom of the module as a small utilities section).

- **Four-space indent.** No tabs. Every level of nesting is four spaces. Whitespace is inert to Ernest's lexer, so this is a readability choice, not a language requirement — but the paper programs and any Ernest code we write should follow it consistently.

- **No alignment padding, anywhere.** Don't add spaces to make tokens line up with the corresponding token on another line. This applies uniformly: no padding around `->` in `match`/`recv` arms; no padding before `=` in declarations; no padding across `foreign fn` bodies; no padding before trailing `//` comments to align them. Alignment reads well when written but breaks the moment an edit adds a longer identifier, forcing every neighboring line to be re-padded. Keep tokens close: one space where a space is needed, and exactly one space before a trailing `//` comment.

    Good:
    ```
    Some(Right(())) -> answer(ack, okAck)
    | Some(Left(e)) -> answer(ack, Failed(e))
    | None -> answer(ack, Failed(Io("timeout")))
    ```

    Bad (arrows aligned by padding before `->`):
    ```
    Some(Right(())) -> answer(ack, okAck)
    | Some(Left(e))   -> answer(ack, Failed(e))
    | None            -> answer(ack, Failed(Io("timeout")))
    ```

    Structural indentation (blocks, arm separators, function bodies) is not alignment padding — a `|` at the start of a subsequent arm, or a `let` at the start of a block statement, is part of the syntactic form, not a padding choice.

- **100-character line limit for code.** Code inside code blocks stays at or under 100 columns. Prose in markdown documents can be longer (renderers wrap it). Split long expressions or arguments across lines rather than let one line run wide.

- **Section banners are three lines, not a horizontal rule.** For section headers inside a module, use a small block-comment banner rather than a comment padded with dashes:

    Good:
    ```
    //
    // Processes
    //
    ```

    Bad:
    ```
    // Processes ------------------------------------------------
    ```

    The dash-padded form is another kind of alignment padding — it depends on a visual column that shifts if the section name is renamed. The three-line banner is stable, scans clearly, and reads as an intentional block comment rather than a decoration.
