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

## Current task (from [`docs/implementation_plan.md`](docs/implementation_plan.md), Phase 2)

Phase 1 is done: `lib/lexer`, `lib/parser`, `lib/type_system`, all tested; `make test` is green. Phase 2 turns the typed AST into BEAM. Next step: the runtime API `lib/runtime/src/ern_rt.erl` as a stub with specs, then `lib/compiler`. The decisions for Phase 2 are in the plan's 2.1 and 2.4. What follows describes the front end as built.

- Implementation language: **Erlang** (OTP 27). The compiler is `ernc`, the runner is `ern`. See the plan for architecture.
- Hand-written parser: a direct precedence-climbing loop over a plain token list for expressions (no generic Pratt engine, no yecc), recursive descent for declarations. Hand-written lexer emitting yecc-shaped tokens. First-token dispatch with small bounded lookahead (the constructor-fields peek documented in Appendix A, the FnType-vs-ParenType decision after the closing paren, and `fn` followed by an identifier versus `(`), no backtracking.
- Seventeen reserved words. `true`/`false` are literals, not keywords in the general sense.
- Patterns via a second small precedence loop with `::` right-associative and postfix `as ident`.
- AST as Erlang records with `{line, column}` on every node.

## First test programs

- **Counter** (with `Upgrade` code replacement) — [`ernest_report.md`](ernest_report.md) §6.10 and Appendix B; files `examples/counter.ern` and `examples/counter_upgrade.ern`.
- **Ping-pong** — [`ernest_report.md`](ernest_report.md) Appendix B; file `examples/ping_pong.ern`.

The other MVP 1 programs are `examples/hello.ern` and `examples/stack.ern`. The remaining files under `examples/` need later MVPs; each header says which.

If either test surfaces an anomaly in the report, propose an update to [`ernest_report.md`](ernest_report.md) (and matching [`docs/decisions.md`](docs/decisions.md)) before working around it in the parser.

## Repository layout and build

- `lib/<app>/{src,include,ebin,test}` per compiler stage: `lexer`, `parser`, `type_system`, `utils` (vendored `getopt`). Later: `compiler`, `runtime`, `cli`. Module names carry the `ern_` prefix.
- `stdlib/` is the Ernest standard library, a source root. `examples/` holds the example programs. `bin/` will hold `ernc` and `ern` as committed escript sources.
- Build with `make` (per-app `src/Makefile` compiling into `../ebin` with `erlc -MMD`; top-level `Makefile` runs them), `make test` for EUnit, `make clean`. No rebar3, no OTP behaviours.
- File and directory names use underscores everywhere (report §11.1 forbids hyphens in module paths). One exception, by Erlang's rule: an Erlang module implementing an Ernest namespace is named after its module atom, `lib/runtime/src/Ernest.Io.erl` for `'Ernest.Io'`, since `erlc` requires it.
- Third-party code is listed in `THIRD_PARTY_LICENSES`; keep the upstream header on any borrowed file.

## Working style

- Prefer minimal, direct implementations over speculative abstraction.
- Ask before scaffolding when a decision affects the report or the plan.
- **No warts.** Never leave an approximation, a silent deviation from the report, or an unstated semantic choice in the code. When the report is silent, either add the sentence to the report (report, then decisions log, then code) or reject the input with an error; never accept it silently. State every such choice to the user when it is made. A known gap goes in the plan with a date, not in a comment.
- **Read before code.** Before implementing a module, list the report sections it implements. After, each section has at least one test whose comment cites it (`%% report §5.4`). A section without a test is not implemented.
- **Every message that reports code work ends with a "Report conformance" section.** It lists the sections applied; every place the report was silent and what was done; every deliberate omission, each with the MVP that will lift it and the error the code gives meanwhile. If nothing was silent, say "none". This section is not optional, and "tests green" does not replace it.
- **Done means three things:** the tests pass, the conformance section is written, and no known gap exists outside the plan.
- When touching normative material, quote the exact section or grammar rule being applied.
- Prose in the report and the guide is tight, in the register of a Wirth language report: state the rule, no rationale, no restating. Rationale goes to `docs/decisions.md`, compiler behaviour to §11.

## Erlang style guide

For the compiler's own code under `lib/`.

- **Four-space indent, no tabs. Lines ≤ 100 characters.**
- **Module names carry the `ern_` prefix.** One `-export` list at the top, in the order the functions appear.
- **`-spec` on every exported function.** Types shared between modules are `-type`s in the owning module.
- **Records live in `include/*.hrl`** when shared, else in the module. No macros beyond record definitions and the few constants that need a name.
- **Tests are EUnit, in `test/<module>_tests.erl`**, one test function per behaviour, named after the behaviour.
- **No OTP behaviours, no rebar3.** `make` builds with `+debug_info -Werror`; a warning is an error.
- **Tokens and AST nodes are plain tuples and records**, never closures or ETS state.

## Ernest style guide

Ernest is order-independent at top level; these are style choices, not correctness. Follow them consistently.

- **Top-down layout.** Types first. Then `main` (in program modules) or exported functions (in library modules). Each root's helpers follow immediately below it, before the next root. Shared helpers go with the first user, or in a bottom utilities section if genuinely shared.
- **Four-space indent, no tabs.**
- **No alignment padding, anywhere.** Don't add spaces to align tokens across lines: `->`, `=`, trailing `//` comments, anything. Structural indentation (block bodies, clause separators) isn't padding — that stays. One space where a space is needed.
- **Code lines ≤ 100 characters.** Split long expressions rather than let one line run wide. Prose in markdown can be longer.
- **Block-comment banners for sections.** Open with `//` on its own line, one or more `// text` lines, close with `//` on its own line. Blank line before the opening, blank line after the closing. Not `// Section ----------`.
