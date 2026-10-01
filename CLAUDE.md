# Ernest — Claude Instructions

Ernest is a functional language for concurrent programs, designed by the user (joagre). Two concepts: pure functions (Hindley-Milner) and processes with typed mailboxes. [`ernest_report.md`](ernest_report.md) is the full report.

The rules follow the order of work, and each is stated once.

## Authority

- **[`ernest_report.md`](ernest_report.md) is the single normative document.** Nothing else in this repo overrides it.
- **Appendix A, the grammar, is the truth.** A conflict between the prose and Appendix A is resolved in favour of Appendix A.
- **Section 0, the five principles, is the tiebreaker.** It decides where Appendix A is ambiguous and when a design decision is under discussion. Principles 2 to 5 are the constructive rules; principle 1 audits the resulting code.

## Who owns each fact

- **Each fact has one owner.** The report owns the language, [`docs/decisions.md`](docs/decisions.md) the rationale, [`docs/implementation_plan.md`](docs/implementation_plan.md) the roadmap and where we are, the code and its tests what is built, and [`docs/architecture.md`](docs/architecture.md) how the code is arranged.
- **The other documents own one thing each.** [`docs/style.md`](docs/style.md) the code's form and naming; the README what Ernest is and where to begin; [`docs/development.md`](docs/development.md) the layout, the commands, and what the toolchain does not do yet; a design note its component's design (`docs/shell_design.md`, `docs/node_protocol.md`, `docs/code_distribution.md`, `docs/install.md`); [`shell/README.md`](shell/README.md) how the shell's code reads; [`docs/emacs_mode.md`](docs/emacs_mode.md) the Emacs mode; [`docs/module_doc_template.md`](docs/module_doc_template.md) the worked example of a documented module, which a test holds equal to `ern doc`'s output; [`docs/release_review.md`](docs/release_review.md) what a release runs to be ready; [`docs/full_review.md`](docs/full_review.md) the review of every area whole, run seldom; [`docs/principles_review.md`](docs/principles_review.md) the report and the guide read against §0, and §0 against what it decided; [`docs/memory.md`](docs/memory.md) how memory is checked; [`test/diagnostics.md`](test/diagnostics.md) the catalogue of diagnostics, which `make diagnostics` writes; [`man/`](man/index.md) the last release's pages, which `make pages` writes; and [`tools/release/README.md`](tools/release/README.md) what a reader of the release archive needs first. Two hold a list until a plan item decides each entry: [`docs/language_feedback.md`](docs/language_feedback.md) what writing Ernest has felt against the principles, and [`docs/findings.md`](docs/findings.md), while a review's findings are open, what its readers found ([`docs/release_review.md`](docs/release_review.md), [`docs/full_review.md`](docs/full_review.md), [`docs/principles_review.md`](docs/principles_review.md)). [`docs/operations.md`](docs/operations.md) holds the proposal for code written once over several representations, operations records, compared with type classes, until MVP 2.99b decides.
- **The decisions log is rationale only.** It says why the report and the plan say what they say, and changes with them. It is never normative.
- **The plan and the programs under `examples/` are illustrative**, not sources of truth about the language.
- **Every other document points at the owner and does not restate it.** A fact a reader must not miss gets a line naming its owner, in the place that reader opens first.
- **A restatement is allowed in a teaching document only.** The guide and `shell/README.md` restate what they teach. Where a list must live in two places, a test keeping the two equal is welcome, not required.
- **A sentence goes to its owner before it is written.** What will be built and when goes in the plan; why goes in the log. A paragraph that does both is split at that line.
- **A decision the user must see goes in the plan**, since the user reads the plan and not the log. The plan states it in one sentence, with the report section that states it and the log entry that argues it. A finished milestone in the plan is a paragraph and its pointers.

## The repository

- **The implementation is Erlang, OTP 29.** The toolchain is one command, `ern`, whose first word is its job: `ern build` compiles and `ern run` runs. `make` builds; `make test` tests.
- **Third-party code is listed in `THIRD_PARTY_LICENSES`.** A borrowed file keeps its upstream header.
- **The work is done in the main checkout, on `main`.** No worktree and no branch of a session's own: the user reads and edits this one checkout.

## Before code

- **The report changes first.** An anomaly found while implementing changes the report, then the decisions log, then the code.
- **A change to the report or the plan is stated and made, not asked about.** Give the change and its argument, make it, and report it in the conformance section. Stop and wait only where the answer decides what gets built and guessing would throw the work away.
- **That rare case is a design question, discussed one at a time, in prose.** The argument comes before the verdict, with a recommendation; never a form of choices.
- **No decision is left pending.** A question a step raises is decided in the same turn, with its argument, and recorded in the plan and the log. One that needs the user is discussed at once, and until it is decided it stands in the plan as a named decision in a named milestone, never as "open". An undiagnosed defect is planned the same way, with a date and the shape of its fix.
- **List the report sections a module implements before writing it.**
- **Quote the exact section or grammar rule** when touching normative material.

## Design

- **Prefer minimal, direct implementations** over speculative abstraction.
- **Features are judged on the principles.** A feature enters or stays out by the five principles, and a standard library function by E.0's four admission rules, weighed one by one. How many programs ask for it decides nothing: the log names the principle that decided, and a "Later" entry its verdict and what would change it, never a count of programs. A library under `libs/` is not a feature of the language: one is written when our work needs it, when someone asks for it, or when we want it.
- **Bring options, not defenses.** When a simplification seems to conflict with a principle, first check whether the principle is being applied too dogmatically. The ambient system references were once refused on a misreading of "nothing invisible".
- **What Ernest adds to a host operation costs a fraction of it.** A check, a count or a table row around a native call never costs a multiple of the call, and an operation Erlang makes without a message makes none in Ernest; only a system process costs a message by design. No scan on an operation's path grows with anything but the operation's own input. The runtime is kept readable: a cost goes by needing less, never by a trick. `make bench` measures it.

## Shims

- **`foreign` is only what the host alone can do, in every Ernest we write**, the standard library included. A `foreign fn` is admitted where Ernest cannot express the work *given the layers beneath it*. The shell reads its history file in Ernest because `Fs` is beneath it; `String.toUpper` is a shim because nothing is beneath `String` but the host and its Unicode tables. Reading, splitting, escaping, trimming and sorting are written in Ernest. E.0 rule 1 is the normative half of this rule; where the two differ the report is corrected.
- **Performance is never the reason for a shim.** A measurement that demands one comes back as a decision with the numbers beside it.
- **Whether a type's representation is the runtime's is a decision of its own**, recorded in Appendix E.0 and the log. `Map` is Erlang's map and `String` a binary, so the operations that reach the representation are the host's and the rest are Ernest over them. It never licenses a shim for a value the language already owns.
- **A shim is written with the upstream manual page open.** Its arguments, edge cases, and the errors it returns and raises are carried into the Ernest contract. The page is a source of truth, never of wording: the prose is ours, by E.0 shape rule 6, and nothing is copied. A host module whose documentation is hidden is used only where decided with the user: `unicode_util`'s tables behind `Char` (the log's *Char Reads the Host's Tables*).
- **No regular expression answers a fixed question in the runtime.** A shim that asks one thing of each value, a category, a literal's form, tests it directly.

## Defects and gaps

- **No warts.** Never leave an approximation, a silent deviation from the report, or an unstated semantic choice in the code.
- **Memory that no collection reclaims is a defect, fixed at its cause**, in the runtime, the toolchain, the shell and Ernest code alike. It is never fixed by capping a list, a table or a cache. A cache is added only with an argument for what it holds and when it lets go. How memory is checked is [`docs/memory.md`](docs/memory.md)'s.
- **A known defect is fixed when found.** A gap too large to fix now goes in the plan with a date, never in a comment.
- **Nothing routes around a defect or a gap**, in the standard library, the shell, `examples/`, the guide, the report's examples or the tests. Code that meets a toolchain bug, a missing function, module or feature, or a command that cannot show something does not work around it or hide it by choosing another example. Stop and say so: the gap goes to the report, Appendix E or the plan first, and what needed it says that it waits.
- **A published specification or a general-purpose engine is a library's work**: a pattern language, a data format, a protocol, dates and times. Where Ernest code finds itself writing one, stop; the need goes to [`docs/language_feedback.md`](docs/language_feedback.md), and whether a library is written is decided with the user first. Splitting, trimming and sorting stay in the program.
- **Writing Ernest tests the language.** Where it feels against a principle, a workaround, a second way, something invisible, a function the library lacks, say so at once, add it to [`docs/language_feedback.md`](docs/language_feedback.md), and discuss it with the user before any code goes around it.
- **Where the report is silent, add the sentence to the report or reject the input with an error.** Never accept it silently, and state the choice to the user.
- **A refusal made for a later MVP's sake names that MVP in its error text**, and `docs/development.md`'s table lists it, which a test checks.

## Tests

- **Every report section has a test** whose comment cites it (`%% report §5.4`); `make sections` names a section without one, which is not implemented.
- **A test written after the code is a regression test.** Say so, and name what it does not cover. What has found defects here is the terminal harness, a read-back of the code, an independent reader, and the user, not a test that passed on its first run.
- **`make test` runs before the commit that closes a plan item.** While working, the area a change touches runs its own target (`docs/development.md`, *Building*).
- **Readers run before a release, and when the user asks**, as [`docs/release_review.md`](docs/release_review.md) says. The full review's readers read every area whole, when [`docs/full_review.md`](docs/full_review.md) says.

## Writing

- **The report and the guide are tight, in a Wirth language report's register.** State the rule; no rationale, no restating.
- **Clear before short.** Plain sentences, one rule per sentence, its exception and its example in sentences of their own. A sentence is cut for restating or rationale, never for a count: a long section is kept when every sentence states a rule.
- **A report edit updates the revision date** in its line 3.
- **The report's section numbers never change**, since the documents, the tests and the code cite them. A section is never renumbered, removed, or put between two others. A new rule goes into the section it belongs to; where none can hold it, a new section is added at the end of its chapter or appendix. The guide's numbers change only where a section cannot be placed otherwise.
- **Compiler behaviour goes to §11** of the report.
- **No document or message names who proposed an idea**, or that person's role; it states the argument.

## Done

- **Read the result back before reporting it.** After a design change, read the resulting Ernest code as a reader who knows the rest of Ernest would, against the principles and Appendix E.0, which bind the standard library and the toolchain as well, and say what surprised.
- **Stop after each plan item.** Finish it with its tests, documents, conformance section and commit, report the status and any open report question, and wait: the user sees each item's design choices before the next builds on them.
- **Done means four things:** `make test` passes; the conformance section is written; every known gap is in the plan; and the same commit removes every sentence elsewhere that says the item still waits, in `docs/development.md`'s table, the plan's tables, or an example's header.
- **Commit only after the checks pass**, never chained after them with `;`. Push only when the user says so.
- **Every message that reports code work ends with a "Report conformance" section**: the sections applied; every place the report was silent and what was done, or "none"; and every deliberate omission, with the MVP that will lift it and the error the code gives meanwhile. "Tests green" does not replace it.

## Style

[`docs/style.md`](docs/style.md) holds the style guides for Erlang, C and Ernest, imported here.

@docs/style.md
