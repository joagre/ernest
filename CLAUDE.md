# Ernest — Claude Instructions

## What Ernest is

A functional language for concurrent programs, designed by the user (joagre). Two concepts: pure functions (Hindley-Milner) and processes with typed mailboxes. See [`ernest_report.md`](ernest_report.md) for the full report.

## Normative structure

- **[`ernest_report.md`](ernest_report.md) is the single normative document.** Nothing else in this repo overrides it.
- **Appendix A (grammar) is the truth.** Any conflict between prose and Appendix A is resolved in favor of Appendix A.
- **Section 0 (Introduction + five principles) is the tiebreaker.** When Appendix A leaves something ambiguous, or a design decision is under discussion, resolve it by section 0's principles. Principles 2–5 (one way, one job; nothing invisible; simple to parse — recursive descent with bounded lookahead; small) are the constructive rules; principle 1 (least surprise) is the backstop that audits the resulting code.
- **[`docs/decisions.md`](docs/decisions.md) is rationale only.** It explains *why* the report says what it says; it is updated only when [`ernest_report.md`](ernest_report.md) is updated. Never treat it as normative and never edit it in isolation.
- **The programs under `examples/` and the plan in `docs/implementation_plan.md` are illustrative**, not normative. Use them as motivating examples and roadmap, not as sources of truth.
- **The report can be updated if we find anomalies** while implementing. When that happens, update [`ernest_report.md`](ernest_report.md) first, then reflect the reason in [`docs/decisions.md`](docs/decisions.md), then adjust code.

## Where we are

The current phase and its decisions are in [`docs/implementation_plan.md`](docs/implementation_plan.md); what is built is what `lib/` and `make test` say. Implementation language: Erlang, OTP 27. The compiler is `ernc`, the runner is `ern`. The programs MVP 1 runs are the `PROGRAMS` macro in `test/ern_integration_tests.erl`.

## Repository layout and build

- The README owns the layout ("Layout of the repository") and the commands ("Building"); `make` builds, `make test` tests.
- A module path segment is one lowercase word (report §11.1), so `.ern` files and their directories never carry underscores; every other file and directory name uses underscores. The one `@` is Erlang's: a module implementing an Ernest namespace is `ernest@io` in `ernest@io.erl`, the path with `@` for `/`, as Gleam does.
- Third-party code is listed in `THIRD_PARTY_LICENSES`; keep the upstream header on any borrowed file.

## Working style

- Prefer minimal, direct implementations over speculative abstraction.
- **One owner per fact.** The report owns the language, the decisions log the rationale, the plan the roadmap, the code and its tests what is built, the architecture note how the code is arranged. Every other document points at the owner and does not restate it; the README says where things are, not what they are. Two exceptions: the guide restates the report because teaching is restating, and a list that must live in the code and in a document has a test keeping them equal. A restatement without a test is a wart. The mirrors with tests today: the README's "What MVP 1 accepts" table against the toolchain's error texts (`ern_cli_tests`), the prelude tables against §9 and Appendix E (`ern_prelude_tests`), and the section grammars against Appendix A (`ern_parser_tests`).
- Ask before scaffolding when a decision affects the report or the plan.
- **Read the result back before reporting it.** After a design change, read the resulting Ernest code as a reader who knows the rest of Ernest would, against principles 1 and 2 and the rules of Appendix E.0, and say what surprised. The principles apply to the standard library and the toolchain as much as to the language; the 2026-09-18 stdlib drift, `send` to system processes, a generator of our own, a reserved word as a function name, came from applying them to the language only and reading back after committing.
- **No warts.** Never leave an approximation, a silent deviation from the report, or an unstated semantic choice in the code. When the report is silent, either add the sentence to the report (report, then decisions log, then code) or reject the input with an error; never accept it silently. State every such choice to the user when it is made. A known gap goes in the plan with a date, not in a comment; a refusal made for MVP 1's sake says "MVP 1" in its error text, and a test checks the README's table lists it.
- **Read before code.** Before implementing a module, list the report sections it implements. After, each section has at least one test whose comment cites it (`%% report §5.4`); `make sections` lists the sections still without one, `make coverage` how thinly each is cited. A section without a test is not implemented.
- **Every message that reports code work ends with a "Report conformance" section.** It lists the sections applied; every place the report was silent and what was done; every deliberate omission, each with the MVP that will lift it and the error the code gives meanwhile. If nothing was silent, say "none". This section is not optional, and "tests green" does not replace it.
- **Done means three things:** the tests pass, the conformance section is written, and no known gap exists outside the plan.
- When touching normative material, quote the exact section or grammar rule being applied.
- Prose in the report and the guide is tight, in the register of a Wirth language report: state the rule, no rationale, no restating. Rationale goes to `docs/decisions.md`, compiler behaviour to §11.

## Erlang style guide

For the compiler's own code under `lib/`.

- **Four-space indent, no tabs. Lines ≤ 100 characters.**
- **Module names carry the `ern_` prefix**, except modules implementing Ernest namespaces, `ernest@io`. One `-export` list at the top, in the order the functions appear.
- **`-spec` on every exported function.** Types shared between modules are `-type`s in the owning module.
- **Records live in `include/*.hrl`** when shared, else in the module. No macros beyond record definitions and the few constants that need a name.
- **Tests are EUnit, in `test/<module>_tests.erl`**, one test function per behaviour, named after the behaviour, each with a `%% report §x.y` line.
- **No OTP behaviours, no rebar3.** `make` builds with `+debug_info -Werror`; a warning is an error.
- **Tokens and AST nodes are plain tuples and records**, never closures or ETS state.

## Ernest style guide

Ernest is order-independent at top level; these are style choices, not correctness. Follow them consistently.

- **Top-down layout.** Types first. Then `main` (in program modules) or exported functions (in library modules). Each root's helpers follow immediately below it, before the next root. Shared helpers go with the first user, or in a bottom utilities section if genuinely shared.
- **Four-space indent, no tabs.**
- **No alignment padding, anywhere.** Don't add spaces to align tokens across lines: `->`, `=`, trailing `//` comments, anything. Structural indentation (block bodies, clause separators) isn't padding — that stays. One space where a space is needed.
- **Code lines ≤ 100 characters.** Split long expressions rather than let one line run wide. Prose in markdown can be longer.
- **Block-comment banners for sections.** Open with `//` on its own line, one or more `// text` lines, close with `//` on its own line. Blank line before the opening, blank line after the closing. Not `// Section ----------`.
