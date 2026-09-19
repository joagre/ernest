# Ernest — Claude Instructions

## What Ernest is

A functional language for concurrent programs, designed by the user (joagre). Two concepts: pure functions (Hindley-Milner) and processes with typed mailboxes. See [`ernest_report.md`](ernest_report.md) for the full report.

## Normative structure

- **[`ernest_report.md`](ernest_report.md) is the single normative document.** Nothing else in this repo overrides it.
- **Appendix A (grammar) is the truth.** Any conflict between prose and Appendix A is resolved in favor of Appendix A.
- **Section 0 (the five principles) is the tiebreaker.** When Appendix A leaves something ambiguous, or a design decision is under discussion, resolve it by section 0: principles 2 to 5 are the constructive rules, principle 1 audits the resulting code.
- **[`docs/decisions.md`](docs/decisions.md) is rationale only.** It explains *why* the report says what it says; it is updated only when [`ernest_report.md`](ernest_report.md) is updated. Never treat it as normative and never edit it in isolation.
- **The programs under `examples/` and the plan in `docs/implementation_plan.md` are illustrative**, not normative. Use them as motivating examples and roadmap, not as sources of truth.
- **An anomaly found while implementing changes the report first**, then the decisions log, then the code.

## Where we are

The current phase and its decisions are in [`docs/implementation_plan.md`](docs/implementation_plan.md); what is built is what `lib/` and `make test` say. Implementation language: Erlang, OTP 27. The compiler is `ernc`, the runner is `ern`. The programs MVP 1 runs are the `PROGRAMS` macro in `test/ern_integration_tests.erl`.

## Repository layout and build

- The README owns the layout ("Layout of the repository") and the commands ("Building"); `make` builds, `make test` tests.
- A module implementing an Ernest namespace is `ernest@io` in `ernest@io.erl`, the path with `@` for `/`, as Gleam does; every file that is not an Ernest module uses underscores.
- Third-party code is listed in `THIRD_PARTY_LICENSES`; keep the upstream header on any borrowed file.

## Working style

- Prefer minimal, direct implementations over speculative abstraction.
- **One owner per fact.** The report owns the language, the decisions log the rationale, the plan the roadmap, the code and its tests what is built, the architecture note how the code is arranged. Every other document points at the owner and does not restate it; the README says where things are, not what they are. The test for a sentence: if it says what will be built and when, it goes in the plan; if it says why, in the log; a paragraph that does both is split at that line before it is written. The user reads the plan and not the log, so a decision that is only in the log is a decision the user will not see. Two exceptions: the guide restates the report because teaching is restating, and a list that must live in the code and in a document has a test keeping them equal. A restatement without a test is a wart; the tests that read `ernest_report.md` or the README are the mirrors.
- Ask before scaffolding when a decision affects the report or the plan.
- **Stop after each plan item.** Finish it fully, tests, documents, conformance section, commit, then report the status and any open report question and wait; the next item starts in the next turn, since each is a rule with design choices the user wants to see before the next builds on it.
- **Bring options, not defenses.** When a proposed simplification seems to conflict with a principle, check whether the principle is being applied too dogmatically before defending it; the ambient `Sys.*` values were once refused on a misreading of "nothing invisible".
- **Read the result back before reporting it.** After a design change, read the resulting Ernest code as a reader who knows the rest of Ernest would, against principles 1 and 2 and Appendix E.0, and say what surprised. The principles apply to the standard library and the toolchain as much as to the language.
- **No warts.** Never leave an approximation, a silent deviation from the report, or an unstated semantic choice in the code. The corpus rule, three programs, admits a feature; it never excuses a defect. That no program has yet been misled by a known defect is not a reason to keep it: a defect with a known fix is fixed when found, or goes in the plan with a date if the fix is large. When the report is silent, either add the sentence to the report or reject the input with an error; never accept it silently. State every such choice to the user when it is made. A known gap goes in the plan with a date, not in a comment; a refusal made for MVP 1's sake says "MVP 1" in its error text, and a test checks the README's table lists it.
- **Read before code.** Before implementing a module, list the report sections it implements. After, each section has at least one test whose comment cites it (`%% report §5.4`); `make sections` lists the sections still without one, `make coverage` how thinly each is cited, and `make xref`, also part of `make test`, fails on a citation that names no heading. A section without a test is not implemented.
- **Every message that reports code work ends with a "Report conformance" section.** It lists the sections applied; every place the report was silent and what was done; every deliberate omission, each with the MVP that will lift it and the error the code gives meanwhile. If nothing was silent, say "none". This section is not optional, and "tests green" does not replace it.
- **Done means four things:** the tests pass, the conformance section is written, no known gap exists outside the plan, and the same commit removes every sentence elsewhere, the README's table, the plan's tables, an example's header, that says the item still waits.
- When touching normative material, quote the exact section or grammar rule being applied.
- Prose in the report and the guide is tight, in the register of a Wirth language report: state the rule, no rationale, no restating. Clear before short: a rule is easy to read at first pass, in plain sentences, one rule per sentence, its exception and its example in sentences of their own, never compressed into a cryptic one; a sentence is cut for restating or rationale, never for the count alone. A report edit updates the revision date in line 3, and a change to a section the guide teaches is followed by a re-read of the guide against it. Rationale goes to `docs/decisions.md`, compiler behaviour to §11.

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
