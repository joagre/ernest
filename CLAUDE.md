# Ernest — Claude Instructions

Ernest is a functional language for concurrent programs, designed by the user (joagre). Two concepts: pure functions (Hindley-Milner) and processes with typed mailboxes. [`ernest_report.md`](ernest_report.md) is the full report.

The rules are in the order of work: what is authoritative and who owns each fact, the repository, before code, design, shims, defects and gaps, tests, writing, reading back, and when a task is done. Each rule is stated once.

## Authority

- **[`ernest_report.md`](ernest_report.md) is the single normative document.** Nothing else in this repo overrides it.
- **Appendix A, the grammar, is the truth.** A conflict between the prose and Appendix A is resolved in favour of Appendix A.
- **Section 0, the five principles, is the tiebreaker.** It decides where Appendix A is ambiguous and when a design decision is under discussion. Principles 2 to 5 are the constructive rules; principle 1 audits the resulting code.

## Who owns each fact

- **Each fact has one owner.** The report owns the language, [`docs/decisions.md`](docs/decisions.md) the rationale, [`docs/implementation_plan.md`](docs/implementation_plan.md) the roadmap, the code and its tests what is built, and [`docs/architecture.md`](docs/architecture.md) how the code is arranged.
- **The other documents own one thing each.** [`docs/style.md`](docs/style.md) owns the code's form; the README the layout and the commands; a design note its component's design (`docs/shell_design.md`, `docs/node_protocol.md`, `docs/code_distribution.md`); [`shell/README.md`](shell/README.md) how the shell's code reads; [`docs/review.md`](docs/review.md) the review before a release; and [`docs/language_feedback.md`](docs/language_feedback.md) and [`docs/report_cold_read.md`](docs/report_cold_read.md) the questions still open.
- **The decisions log is rationale only.** It says why the report and the plan say what they say, and changes with them. It is never normative.
- **The plan and the programs under `examples/` are illustrative.** They are the roadmap and the motivating examples, not sources of truth about the language.
- **Every other document points at the owner and does not restate it.** The README says where things are, not what they are.
- **Visible means a pointer where a reader looks, never a copy.** A fact a reader must not miss gets a line that names its owner, in the place that reader opens first.
- **A restatement is allowed in two cases only.** A document meant to teach, the guide and `shell/README.md`, restates what it teaches, because teaching is restating. A list that must live both in the code and in a document has a test keeping the two equal; the tests that read `ernest_report.md` or the README are these mirrors. A teaching document that would repeat such a list without a test points at the code instead. Any other restatement is a wart.
- **A sentence goes to its owner before it is written.** What will be built and when goes in the plan; why goes in the log. A paragraph that does both is split at that line.
- **A decision the user must see goes in the plan.** The user reads the plan and not the log, so a decision that is only in the log is one the user will not see.
- **The plan states a decision in a sentence and points; the log argues it.** The plan gives the decision in one sentence, with the report section that states it and the log entry that argues it. The log carries the argument and names the decision without restating the report's words. A finished milestone in the plan is a paragraph and its pointers.

## The repository

- **The plan says where we are.** It holds the current phase and its decisions; what is built is what `erl/` and `make test` say.
- **The implementation is Erlang, OTP 29.** The toolchain is one command, `ern`, whose first word is its job: `ern build` compiles and `ern run` runs. The programs the toolchain runs are the `PROGRAMS` macro in `test/ern_integration_tests.erl`.
- **The README owns the layout and the commands**, under "Layout of the repository" and "Building". `make` builds; `make test` tests.
- **The style guide owns the naming of the code**, one rule for every Erlang module and every module compiled from Ernest. It is imported at the end of this file.
- **Third-party code is listed in `THIRD_PARTY_LICENSES`.** A borrowed file keeps its upstream header.

## Before code

- **The report changes first.** An anomaly found while implementing changes the report, then the decisions log, then the code.
- **A change to the report or the plan is stated before it is made, not asked about.** Give the change and the argument for it, make it, and report it in the conformance section. Stop and wait only where the answer decides what gets built and guessing would throw the work away; that case is rare, and everything else is stated and done.
- **That rare case is a design question, discussed one at a time, in prose.** The argument comes before the verdict, with a recommendation; never a form of choices.
- **No decision is left pending.** A question a step raises is decided in the same turn, with its argument, and recorded in the plan and the log. Where guessing would throw work away, it is placed in the plan as a named decision inside a named milestone or checkpoint, never left as "open". An undiagnosed defect is planned the same way, with a date and the shape of its fix.
- **List the report sections a module implements before writing it.**
- **Quote the exact section or grammar rule** when touching normative material.

## Design

- **Prefer minimal, direct implementations** over speculative abstraction.
- **Features are judged on the principles.** A feature enters or stays out by the five principles, and a standard library function by E.0's four admission rules, weighed one by one. How many programs ask for it decides nothing; a feature is not deferred until one asks. A library under `libs/` is not a feature of the language: one is written when our work needs it, when someone asks for it, or when we want it.
- **The log names the principle that decided.** A "Later" entry states the verdict and what would change it, never a count of programs as its trigger.
- **Bring options, not defenses.** When a proposed simplification seems to conflict with a principle, first check whether the principle is being applied too dogmatically. The ambient `Sys.*` values were once refused on a misreading of "nothing invisible".

## Shims

- **`foreign` is only what the host alone can do, in every Ernest we write.** One rule, and the standard library is not exempt from it: a `foreign fn` is admitted where Ernest cannot express the work *given the layers beneath it*, and nowhere else. The shell reads its history file in Ernest because `Fs` is beneath it; `String.toUpper` is a shim because nothing is beneath `String` but the host and its Unicode tables. Reading a file, splitting it, escaping it, trimming it, sorting a list is ordinary programming and is written in Ernest. E.0 rule 1 is the report's half of this rule and the normative one for the standard library; where the two differ it is the report that is corrected.
- **Performance is never the reason for a shim.** Write it in Ernest, and if a measurement later demands otherwise, that comes back as a decision with the numbers beside it.
- **Whether a type's representation is the runtime's is a decision of its own**, not an exemption from the `foreign` rule. `Map` is Erlang's map and `String` a binary, so the operations that reach the representation are the host's, and the rest are Ernest over them; that choice is recorded in Appendix E.0 and the log, and it is revisitable. What it never licenses is a shim for a value the language already owns.
- **A shim is written with the upstream manual page open.** What the function underneath promises — its arguments, its edge cases, the errors it returns and the ones it raises — is read from the page and carried into the Ernest contract, since that is where a shim goes wrong without saying so. The page is a source of truth, never of wording: the prose is ours, by E.0 rule 6 and the module template, and nothing is copied.

## Defects and gaps

- **No warts.** Never leave an approximation, a silent deviation from the report, or an unstated semantic choice in the code.
- **Memory that no collection reclaims is a defect, fixed at its cause.** Waste the garbage collector reclaims is allowed; growth over time that nothing reclaims is not, in the runtime, the toolchain, the shell, and Ernest code alike. It is never fixed by capping a list, a table or a cache, whatever the size. A cache is added only with an argument for what it holds and when it lets go, and that argument is weighed like any other design.
- **A known defect is fixed when found**, however few programs it has misled. A gap too large to fix now goes in the plan with a date, never in a comment.
- **Nothing routes around a defect or a gap, in code or in a document.** A toolchain bug, a missing standard library function, a missing module or language feature, a shell command that cannot show something: the Ernest code, the example, the guide, the report's examples, or the test that meets it does not work around it, and does not hide it by choosing another example. Where the work cannot be expressed, stop and say so: the gap goes to the report, to Appendix E, or to the plan before any code goes around it, and what needed it says that it waits. This holds for the standard library, the shell, `examples/`, the guide, and the tests alike. The same holds for a missing library. Code that implements a published specification or a general-purpose engine another program would want whole, a pattern language, a data format, a protocol, dates and times, is a library's work, not the program's. Where Ernest code finds itself writing one, stop: the need goes to [`docs/language_feedback.md`](docs/language_feedback.md), and whether a library under `libs/` is written, and when, is decided with the user before the program goes on. Ordinary programming over what is there, splitting, trimming, sorting, stays in the program.
- **Writing Ernest tests the language, and what it finds is written down.** Code written in Ernest, the standard library and the shell above all, is where the language is felt. Where it feels against a principle — a workaround that should not be needed, a second way, something invisible, a function the standard library lacks — say so at once and add it to [`docs/language_feedback.md`](docs/language_feedback.md), which holds the list until a plan item decides it. Discuss it with the user before any code goes around it: the fix may be a report change, an Appendix E function, a library, or a verdict that it stays as it is, and each of those is a decision someone must make.
- **Where the report is silent, add the sentence to the report or reject the input with an error.** Never accept it silently, and state the choice to the user when it is made.
- **A refusal made for a later MVP's sake names that MVP in its error text.** A test checks that the README's table lists it.

## Tests

- **Every report section has a test.** Each has at least one test whose comment cites it (`%% report §5.4`); a section without a test is not implemented. `make sections` lists the sections without one, `make coverage` how thinly each is cited, and `make xref`, also part of `make test`, fails on a citation that names no heading.
- **A test written after the code is a regression test.** Say so, and name what it does not cover. A test that passed on its first run has confirmed the code, not discovered anything; what has actually found defects here is the terminal harness under load, a read-back of the resulting code, an independent reader, and the user.
- **Run the check that fits the change, and the whole suite once per plan item.** A change runs the areas it touches: under `erl/<app>`, `make test-erl APP=<app>` and `make test-programs`; under `stdlib/`, `make test-erl APP=runtime` and `make test-programs`; under `shell/`, `make test-shell`; the guide, `make test-guide` and `make test-docs`; any other document, `make test-docs` (or `make xref` for the section citations and document paths alone); the Emacs mode, `make test-emacs`. A change to the checker, the emitter, or the runtime reaches every area, and runs `make test`. The whole of `make test` runs once per plan item, before the commit that closes it.

## Writing

- **The report and the guide are tight, in a Wirth language report's register.** State the rule; no rationale, no restating.
- **Clear before short.** A rule reads easily at first pass, in plain sentences, one rule per sentence, its exception and its example in sentences of their own, never compressed into a cryptic one. A sentence is cut for restating or rationale, never for the count alone.
- **A report edit updates the revision date** in its line 3.
- **The report's section numbers never change.** Other documents, the tests, and the code cite them, so an edit stays inside the existing headings, and a new rule goes into the section it belongs to.
- **A report section over 600 words is read for restating.** There is no word limit; a long section is kept when every sentence states a rule of its own.
- **Compiler behaviour goes to §11** of the report.
- **The log records arguments, never who proposed them.** No document or message names who suggested an idea, or that person's role; it states the argument.

## Reading back

- **Read the result back before reporting it.** After a design change, read the resulting Ernest code as a reader who knows the rest of Ernest would, against principles 1 and 2 and Appendix E.0, and say what surprised. The principles apply to the standard library and the toolchain as much as to the language.
- **A change to a section the guide teaches is followed by a re-read of the guide** against it.
- **Sweep the documents after a batch of report changes, and at the end of every plan step.** Two readings, the guide against the report and every other document against the report and the code; both have found real defects every time. A reader who did not write the text reads best.
- **After renumbering a document's sections, read every citation of the old numbers.** The citation check confirms that a number exists, not that it still names what the sentence means.
- **A document meant to teach is read cold.** A reader who knows another language and not Ernest reads it alone, and where they got lost is fixed; a check against the report does not show whether it teaches.

## Done

- **Stop after each plan item.** Finish it fully, with its tests, documents, conformance section, and commit, then report the status and any open report question, and wait. The next item starts in the next turn, since each is a rule with design choices the user wants to see before the next builds on it.
- **Done means four things:** the tests pass; the conformance section is written; every known gap is in the plan; and the same commit removes every sentence elsewhere, in the README's table, the plan's tables, or an example's header, that says the item still waits.
- **Commit only after the checks pass.** A commit follows a passing check, never a command chained after it with `;`. Push only when the user says so.
- **Every message that reports code work ends with a "Report conformance" section.** It lists the sections applied; every place the report was silent and what was done; and every deliberate omission, with the MVP that will lift it and the error the code gives meanwhile. If nothing was silent, it says "none". The section is not optional, and "tests green" does not replace it.

## Style

The Erlang style guide for `erl/` and the Ernest style guide for `examples/` and `stdlib/` are [`docs/style.md`](docs/style.md), imported here.

@docs/style.md
