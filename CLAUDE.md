# Ernest — Claude Instructions

Ernest is a functional language for concurrent programs, designed by the user (joagre). Two concepts: pure functions (Hindley-Milner) and processes with typed mailboxes. [`ernest_report.md`](ernest_report.md) is the full report.

The rules below are in the order of work: what is authoritative, the repository, before code, while working, and when a task is done.

## Authority

- **[`ernest_report.md`](ernest_report.md) is the single normative document.** Nothing else in this repo overrides it.
- **Appendix A, the grammar, is the truth.** A conflict between the prose and Appendix A is resolved in favour of Appendix A.
- **Section 0, the five principles, is the tiebreaker.** It decides where Appendix A is ambiguous and when a design decision is under discussion. Principles 2 to 5 are the constructive rules; principle 1 audits the resulting code.
- **Each fact has one owner.** The report owns the language, [`docs/decisions.md`](docs/decisions.md) the rationale, [`docs/implementation_plan.md`](docs/implementation_plan.md) the roadmap, the code and its tests what is built, and [`docs/architecture.md`](docs/architecture.md) how the code is arranged.
- **The decisions log is rationale only.** It says why the report and the plan say what they say, and changes with them. It is never normative.
- **The plan and the programs under `examples/` are illustrative.** They are the roadmap and the motivating examples, not sources of truth about the language.
- **Every other document points at the owner and does not restate it.** The README says where things are, not what they are.
- **A restatement is allowed only in two cases.** The guide restates the report, because teaching is restating. A list that must live both in the code and in a document has a test keeping the two equal; the tests that read `ernest_report.md` or the README are these mirrors. Any other restatement is a wart.
- **A sentence goes to its owner before it is written.** What will be built and when goes in the plan; why goes in the log. A paragraph that does both is split at that line.
- **A decision the user must see goes in the plan.** The user reads the plan and not the log, so a decision that is only in the log is one the user will not see.

## The repository

- **The plan says where we are.** It holds the current phase and its decisions; what is built is what `erl/` and `make test` say.
- **The implementation is Erlang, OTP 27.** The compiler is `ernc`, the runner `ern`. The programs the toolchain runs are the `PROGRAMS` macro in `test/ern_integration_tests.erl`.
- **The README owns the layout and the commands**, under "Layout of the repository" and "Building". `make` builds; `make test` tests.
- **The style guide owns the naming of the code**, one rule for every Erlang module and every module compiled from Ernest.
- **Third-party code is listed in `THIRD_PARTY_LICENSES`.** A borrowed file keeps its upstream header.

## Before code

- **The report changes first.** An anomaly found while implementing changes the report, then the decisions log, then the code.
- **Ask before scaffolding** when a decision affects the report or the plan.
- **List the report sections a module implements before writing it.**
- **Quote the exact section or grammar rule** when touching normative material.

## While working

### Design

- **Prefer minimal, direct implementations** over speculative abstraction.
- **Features are judged on the principles.** A feature enters or stays out by the five principles, and a standard library function by E.0's four rules, weighed one by one. How many programs ask for it decides nothing; a feature is not deferred until one asks.
- **The log names the principle that decided.** A "Later" entry states the verdict and what would change it, never a count of programs as its trigger.
- **Bring options, not defenses.** When a proposed simplification seems to conflict with a principle, first check whether the principle is being applied too dogmatically. The ambient `Sys.*` values were once refused on a misreading of "nothing invisible".
- **Writing Ernest tests the language.** Code written in Ernest, the standard library above all, is where the language is felt. Where it feels against a principle, a workaround that should not be needed, a second way, something invisible, say so and discuss it with the user before working around it; the fix may be a report change.
- **Sweep the documents after a batch of report changes, and at the end of every plan step.** Two readings, the guide against the report and every other document against the report and the code; both have found real defects every time.
- **Read the result back before reporting it.** After a design change, read the resulting Ernest code as a reader who knows the rest of Ernest would, against principles 1 and 2 and Appendix E.0, and say what surprised. The principles apply to the standard library and the toolchain as much as to the language.

### Correctness

- **No warts.** Never leave an approximation, a silent deviation from the report, or an unstated semantic choice in the code.
- **A known defect is fixed when found**, however few programs it has misled. A gap too large to fix now goes in the plan with a date, never in a comment.
- **Where the report is silent, add the sentence to the report or reject the input with an error.** Never accept it silently, and state the choice to the user when it is made.
- **A refusal made for a later MVP's sake names that MVP in its error text.** A test checks that the README's table lists it.
- **Every report section has a test.** Each has at least one test whose comment cites it (`%% report §5.4`); a section without a test is not implemented. `make sections` lists the sections without one, `make coverage` how thinly each is cited, and `make xref`, also part of `make test`, fails on a citation that names no heading.

### Writing

- **The report and the guide are tight, in a Wirth language report's register.** State the rule; no rationale, no restating.
- **Clear before short.** A rule reads easily at first pass, in plain sentences, one rule per sentence, its exception and its example in sentences of their own, never compressed into a cryptic one. A sentence is cut for restating or rationale, never for the count alone.
- **A report edit updates the revision date** in its line 3.
- **A change to a section the guide teaches is followed by a re-read of the guide** against it.
- **Compiler behaviour goes to §11** of the report.
- **The log records arguments, never who proposed them.**

## Done

- **Stop after each plan item.** Finish it fully, with its tests, documents, conformance section, and commit, then report the status and any open report question, and wait. The next item starts in the next turn, since each is a rule with design choices the user wants to see before the next builds on it.
- **Done means four things:** the tests pass; the conformance section is written; every known gap is in the plan; and the same commit removes every sentence elsewhere, in the README's table, the plan's tables, or an example's header, that says the item still waits.
- **Every message that reports code work ends with a "Report conformance" section.** It lists the sections applied; every place the report was silent and what was done; and every deliberate omission, with the MVP that will lift it and the error the code gives meanwhile. If nothing was silent, it says "none". The section is not optional, and "tests green" does not replace it.

## Style

The Erlang style guide for `erl/` and the Ernest style guide for `examples/` and `stdlib/` are [`docs/style.md`](docs/style.md), imported here.

@docs/style.md
