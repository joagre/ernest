# Ernest — Claude Instructions

Ernest is a functional language for concurrent programs, designed by the user (joagre). Two concepts: pure functions (Hindley-Milner) and processes with typed mailboxes. [`report/`](report/) holds the full report, in three files.

The rules follow the order of work, and each is stated once. *Closing an item*, at the end of *Done*, names the rules an item meets as it closes.

## Authority

- **The report is the single normative document, in three files under [`report/`](report/)**: [`language.md`](report/language.md), §0 to §10 and Appendices A, B and F; [`toolchain.md`](report/toolchain.md), §11 and Appendix C; and [`library.md`](report/library.md), Appendices D, E and G. Every one of the three is normative, none ranks above another, and a citation's first number or letter names the file it is in. Nothing else in this repo overrides them.
- **Appendix A, the grammar, is the truth.** A conflict between the prose and Appendix A is resolved in favour of Appendix A.
- **Section 0, the five principles, is the tiebreaker.** It decides where Appendix A is ambiguous and when a design decision is under discussion. Principles 2 to 5 are the constructive rules; principle 1 audits the resulting code.

## Who owns each fact

- **Each fact has one owner.** The report owns the language, [`docs/decisions.md`](docs/decisions.md) the rationale, [`docs/implementation_plan.md`](docs/implementation_plan.md) the roadmap and where we are, the code and its tests what is built, and [`docs/architecture.md`](docs/architecture.md) how the code is arranged.
- **The other documents own one thing each:**

  | Document | Owns |
  |---|---|
  | [`docs/style.md`](docs/style.md) | the code's form and naming |
  | [`README.md`](README.md) | what Ernest is and where to begin |
  | [`docs/development.md`](docs/development.md) | the layout, the commands, and what the toolchain does not do yet |
  | a design note, `proposals/shell/shell_design.md`, `proposals/install/install.md` | its component's design |
  | [`shell/README.md`](shell/README.md) | how the shell's code reads |
  | [`proposals/emacs/emacs_mode.md`](proposals/emacs/emacs_mode.md) | the Emacs mode |
  | [`emacs/README.md`](emacs/README.md) | how to install the Emacs mode |
  | [`docs/module_doc_template.md`](docs/module_doc_template.md) | the worked example of a documented module, which a test holds equal to `ern doc`'s output |
  | [`docs/release_review.md`](docs/release_review.md) | what a release runs to be ready |
  | [`docs/full_review.md`](docs/full_review.md) | the review of every area whole, run seldom |
  | [`docs/principles_review.md`](docs/principles_review.md) | the report and the guide read against §0, and §0 against what it decided |
  | [`docs/memory.md`](docs/memory.md) | how memory is checked |
  | [`docs/soundness.md`](docs/soundness.md) | the argument that a well-typed program does not go wrong |
  | [`docs/otp_bugs.md`](docs/otp_bugs.md) | the defects found in OTP, each a report ready for OTP's tracker, until a release Ernest requires has its fix |
  | [`test/diagnostics.md`](test/diagnostics.md) | the catalogue of diagnostics, which `make diagnostics` writes |
  | [`man/`](man/) | the last release's pages, which `make pages` writes |
  | [`assets/README.md`](assets/README.md) | the logo files |
  | [`tools/release/README.md`](tools/release/README.md) | what a reader of the release archive, or of an installation, needs first |

- **Two hold a list until a plan item decides each entry:** [`docs/language_feedback.md`](docs/language_feedback.md) what writing Ernest has felt against the principles; and `findings.md` in `docs/`, while a review's findings are open, what its readers found ([`docs/release_review.md`](docs/release_review.md), [`docs/full_review.md`](docs/full_review.md), [`docs/principles_review.md`](docs/principles_review.md)).
- **[`proposals/`](proposals/) holds what is designed**, a directory for each proposal: the proposal, the reasons for it, what other systems do, and its experiments or programs.
  - Until a proposal is decided all of it is tentative, and nothing flows from it into the report, the plan or the log.
  - Nothing in it is authoritative, built or not: only the report is.
  - Once a proposal is built it is kept as the record of its design, and its status line says so.
  - A component's design note among them still changes when its component's design does, and no other built proposal changes again.

  | Directory | What it holds |
  |---|---|
  | [`proposals/nodes_and_code/`](proposals/nodes_and_code/) | MVP 3.0 and 3.1: `mvp3.0.md`, what MVP 3.0 built, kept as the record; `mvp3.1.md`, what MVP 3.1 builds, rewritten smaller on 2026-10-08 and under discussion; `nodes.md` and `code.md`, the reasons; `set_aside/`, the two proposals it was rewritten from, `builds_side_by_side.md` and `ordered_rolling_restart.md`, with their reasons, kept as the record; `other_systems.md`, how other systems treat the same questions; and `experiments/`, what was tried on the host. Its `README.md` says which is current. |
  | [`proposals/operations/`](proposals/operations/) | built: `operations.md`, the comparison of operations records, code written once over several representations, with type classes, what the forms cost, and three programs that use them, which the tests still run |
  | [`proposals/shell/`](proposals/shell/), [`proposals/emacs/`](proposals/emacs/), [`proposals/install/`](proposals/install/) | built too: the design notes of the shell, of the Emacs mode and of the installation |

- **The decisions log is rationale only.** It says why the report and the plan say what they say, and changes with them. It is never normative.
- **The plan and the programs under `examples/` are illustrative**, not sources of truth about the language.
- **`proposals/scratch/` holds a copy written for one reader outside the project.** It restates its owner in that reader's terms, cites nothing, and is no source of truth; nothing points at it, and it is removed when its reader is done.
- **Every other document points at the owner and does not restate it.** A fact a reader must not miss gets a line naming its owner, in the place that reader opens first.
- **A restatement is allowed in a teaching document only.** The guide and `shell/README.md` restate what they teach. Where a list must live in two places, a test keeping the two equal is welcome, not required.
- **A sentence goes to its owner before it is written.** What will be built and when goes in the plan; why goes in the log. A paragraph that does both is split at that line.
- **A decision the user must see goes in the plan**, since the user reads the plan and not the log. The plan states it in one sentence, with the report section that states it and the log entry that argues it. A finished milestone in the plan is a paragraph and its pointers.

## The repository

- **The implementation is Erlang, OTP 29.** The toolchain is one command, `ern`, whose first word is its job: `ern build` compiles and `ern run` runs. `make` builds; `make test` tests.
- **Third-party code is listed in `THIRD_PARTY_LICENSES`.** A borrowed file keeps its upstream header.
- **The work is done in the main checkout, on `main`.** No worktree and no branch of a session's own: the user reads and edits this one checkout.
- **A commit names its paths**, `git commit -F message -- path...`, never a bare `git commit` after `git add`. The user stages their own work in this checkout while a session works, so `git status --short` is read first for entries that are not the session's, and the index keeps the user's staging.

## Before code

- **The report changes first.** An anomaly found while implementing changes the report, then the decisions log, then the code.
- **A change to a rule the soundness argument covers rewrites the argument's paragraph for that rule in the same commit.** [`docs/soundness.md`](docs/soundness.md) argues over §3 to §9 of the report as they stand; where the paragraph can no longer be made, that is a finding, discussed before the rule changes.
- **A design is discussed in its proposal until the user says it is ready.** The user thinks in a proposal or a note, reads it back with care and discusses it until it is solid. Until then nothing of it is brought to the plan, the log or the report, nor asked about. The next step offered at a pause is another reading back or a harder question: the principles, Erlang, other systems, the operator's day, a real program written against it. *A change to the report or the plan is stated and made* applies once the user has opened the plan, the log or the report for the work.
- **A change to the report or the plan is stated and made, not asked about.** Give the change and its argument, make it, and report it in the conformance section. Stop and wait only where the answer decides what gets built and guessing would throw the work away.
- **That rare case is a design question, discussed one at a time, in prose.** The argument comes before the verdict, with a recommendation; never a form of choices.
- **No decision is left pending.**
  - A question a step raises is decided in the same turn, with its argument, and recorded in the plan and the log.
  - One that needs the user is discussed at once, and until it is decided it stands in the plan as a named decision in a named milestone, never as "open".
  - An undiagnosed defect is planned the same way, with a date and the shape of its fix.
- **List the report sections a module implements before writing it.**
- **Quote the exact section or grammar rule** when touching normative material.

## Design

- **Prefer minimal, direct implementations** over speculative abstraction.
- **Features are judged on the principles.**
  - A feature enters or stays out by the five principles, and a standard library function by E.0's four admission rules, weighed one by one.
  - How many programs ask for it decides nothing: the log names the principle that decided, and a "Later" entry its verdict and what would change it, never a count of programs.
  - A library under `libs/` is not a feature of the language: one is written when our work needs it, when someone asks for it, or when we want it.
- **Bring options, not defenses.** When a simplification seems to conflict with a principle, first check whether the principle is being applied too dogmatically. The ambient system references were once refused on a misreading of "nothing invisible".
- **What Ernest adds to a host operation costs a fraction of it.**
  - A check, a count or a table row around a native call never costs a multiple of the call, and an operation Erlang makes without a message makes none in Ernest; only a system process costs a message by design.
  - No scan on an operation's path grows with anything but the operation's own input.
  - The runtime is kept readable: a cost goes by needing less, never by a trick.
  - `make bench` measures it.
- **Ernest is beautiful, inside and out.**
  - No code is kept only to make it go faster: a second way of writing what the code already says, or a special case for speed, goes, and the cost the plain form leaves is stated in the log, not hidden.
  - Measure first, and where the plain form is fast enough it stays plain; where it is not, the host's own function is the first answer, and anything cleverer is decided with the user.
- **No fixed sleep, in the code or in a test.**
  - A process waits on what it means: a message, a monitor, a port that answers, a line written, a process's end, or a deadline the report states.
  - A wait that is a time stays only where nothing else can show what it waits for, an absence above all, and is then derived from what it waits for, never a number chosen, with the reason beside it.

## Shims

- **The shell's, a tool's and a program's work is written in Ernest.**
  - Where a piece of work could be Ernest or Erlang, it is Ernest.
  - Where only a missing function of the standard library, or a missing library, keeps it out, the gap is discussed with the user and filled, and the work is then written in Ernest, never in Erlang or behind a `foreign fn` meanwhile.
  - There `foreign` is only what the host alone can do, *given the layers beneath it*: the shell reads its history file in Ernest because `Fs` is beneath it.
- **The standard library and the libraries stand on the host.**
  - Where a host function does exactly an operation's work, the operation is its shim, so that Ernest runs at the host's speed wherever the host does the work.
  - Where one almost does, Ernest closes the difference around a shim that is the host function exactly, and an Erlang adapter only where that Ernest measurably costs, with the numbers in the log, or where Ernest cannot close it: a raise it cannot foresee short of doing the host's work, or a host term no Ernest type describes.
  - Where none does, the operation is Ernest.
  - An operation Ernest writes as the host's own operators applied once, `if int < 0 then -int else int`, already runs at the host's speed, and a shim would add a call to it.
  - E.0 rule 1 is the normative half of this rule; where the two differ the report is corrected.
- **Whether a type's representation is the runtime's is a decision of its own**, recorded in Appendix E.0 and the log.
  - `Map` is Erlang's map and `String` a binary, so the operations that reach the representation are the host's.
  - An operation on a value the language owns, a list, a tuple or a bitstring, is a shim where a host function does exactly its work, as any other is.
  - Where one only almost does, the operation is Ernest alone, which reaches the value as the host does, unless that Ernest costs more than three times the host function or grows where it does not (E.0 rule 1).
- **A shim is written with the upstream manual page open.**
  - Its arguments, edge cases, and the errors it returns and raises are carried into the Ernest contract.
  - A host function is exact only by its page: one whose page leaves unspecified what the Ernest contract states, the order it calls a callback in among it, is not exact, and Ernest closes the difference.
  - The page is a source of truth, never of wording: the prose is ours, by E.0 shape rule 6, and nothing is copied.
  - A host module whose documentation is hidden is used only where decided with the user: `unicode_util`'s tables behind `Char` (the log's *Char Reads the Host's Tables*).
- **No regular expression answers a fixed question in the runtime.** A shim that asks one thing of each value, a category, a literal's form, tests it directly.

## Defects and gaps

- **No warts.** Never leave an approximation, a silent deviation from the report, or an unstated semantic choice in the code.
- **Memory that no collection reclaims is a defect, fixed at its cause**, in the runtime, the toolchain, the shell and Ernest code alike. It is never fixed by capping a list, a table or a cache. A cache is added only with an argument for what it holds and when it lets go. How memory is checked is [`docs/memory.md`](docs/memory.md)'s.
- **A known defect is fixed when found.** A gap too large to fix now goes in the plan with a date, never in a comment.
- **Nothing routes around a defect or a gap**, in the standard library, the shell, `examples/`, the guide, the report's examples or the tests.
  - Code that meets a toolchain bug, a missing function, module or feature, or a command that cannot show something does not work around it or hide it by choosing another example.
  - Stop and say so: the gap goes to the report, Appendix E or the plan first, and what needed it says that it waits.
- **A published specification or a general-purpose engine is a library's work**: a pattern language, a data format, a protocol, dates and times.
  - Where Ernest code finds itself writing one, stop; the need goes to [`docs/language_feedback.md`](docs/language_feedback.md), and whether a library is written is decided with the user first.
  - Splitting, trimming and sorting stay in the program.
- **Writing Ernest tests the language.** Where it feels against a principle, a workaround, a second way, something invisible, a function the library lacks, say so at once, add it to [`docs/language_feedback.md`](docs/language_feedback.md), and discuss it with the user before any code goes around it.
- **Where the report is silent, add the sentence to the report or reject the input with an error.** Never accept it silently, and state the choice to the user.
- **A refusal made for a later MVP's sake names that MVP in its error text**, and `docs/development.md`'s table lists it, which a test checks.

## Tests

- **Every report section has a test** whose comment cites it (`%% report §5.4`); `make sections` names a section without one, which is not implemented.
- **A test written after the code is a regression test.** Say so, and name what it does not cover. What has found defects here is the terminal harness, a read-back of the code, an independent reader, and the user, not a test that passed on its first run.
- **`make test` runs before the commit that closes a plan item.** While working, the area a change touches runs its own target (`docs/development.md`, *Building*).
- **An edit to a proposal's documents under discussion runs no test.** While a proposal under `proposals/nodes_and_code/` is discussed, an edit to its prose is committed by its paths and pushed at once, since the user reads it on GitHub between questions. The documents test is owed once: before the discussion closes, or with the first commit that touches anything outside the directory, where the usual rule holds. Code, the Makefile and other documents are tested as always.
- **Readers run before a release, and when the user asks**, as [`docs/release_review.md`](docs/release_review.md) says. The full review's readers read every area whole, when [`docs/full_review.md`](docs/full_review.md) says.

## Writing

- **The report and the guide are tight, in a Wirth language report's register.** State the rule; no rationale, no restating.
- **A proposal and its reasons say what Ernest does, and why.** What was tried and set aside, and what Ernest does not do, stays in the experiment or goes to the log, not into the paragraph that states the rule.
- **Clear before short.** Plain sentences, one rule per sentence, its exception and its example in sentences of their own. A sentence is cut for restating or rationale, never for a count: a long section is kept when every sentence states a rule.
- **A report edit updates the revision date** in line 3 of each file it changes.
- **The report's section numbers never change**, since the documents, the tests and the code cite them.
  - A section is never renumbered, removed, or put between two others.
  - A new rule goes into the section it belongs to; where none can hold it, a new section is added at the end of its chapter or appendix.
  - The guide's numbers change only where a section cannot be placed otherwise.
- **Compiler behaviour goes to §11** of the report.
- **No document or message names who proposed an idea**, or that person's role; it states the argument.

## Done

- **Read the result back before reporting it.** After a design change, read the resulting Ernest code as a reader who knows the rest of Ernest would, against the principles and Appendix E.0, which bind the standard library and the toolchain as well, and say what surprised.
- **Every surprise is decided, not only said.** Each is acted on in the same item, or left with its reason, and either way recorded where its owner keeps it; one that needs the user goes to the user with a recommendation in the same report.
- **Stop after each plan item.** Finish it with its tests, documents, conformance section and commit, report the status and any open report question, and wait: the user sees each item's design choices before the next builds on them.
- **Done means four things:**
  1. `make test` passes;
  2. the conformance section is written;
  3. every known gap is in the plan;
  4. and the same commit removes every sentence elsewhere that says the item still waits, in `docs/development.md`'s table, the plan's tables, or an example's header.
- **Commit only after the checks pass**, never chained after them with `;`. Push only when the user says so.
- **Every message that reports code work ends with a "Report conformance" section**: the sections applied; every place the report was silent and what was done, or "none"; and every deliberate omission, with the MVP that will lift it and the error the code gives meanwhile. "Tests green" does not replace it.

**Closing an item.** Each line names a rule above; none adds one.

1. The report changed first, with its revision date, and the soundness paragraph of a rule it changed (*Before code*, *Writing*).
2. Every question decided, and every gap and needed decision in the plan with its log entry (*No decision is left pending*, *A known defect is fixed when found*).
3. A refusal for a later MVP named in its text and listed in `docs/development.md`'s table (*Defects and gaps*).
4. What writing Ernest felt against a principle in `docs/language_feedback.md` (*Writing Ernest tests the language*).
5. Every report section the item built cited by a test, and a test written after the code called a regression test (*Tests*).
6. A new name in the glossary, and a new term in Appendix F (*The glossary is living*).
7. The result read back, and every surprise decided (*Read the result back*, *Every surprise is decided*).
8. `make test`, then a commit that names its paths, and the four things of *Done means four things*.
9. The report to the user, ending with *Report conformance*, then a stop until the user's word (*Stop after each plan item*); a push only on that word.

## Style

[`docs/style.md`](docs/style.md) holds the style guides for Erlang, C and Ernest, imported here.

- **The glossary is living.** A name that comes to recur across modules, or a concept the code names in two places, goes into `docs/style.md`'s glossary in the commit that writes it, in the report's word where the report names the concept. Appendix F is living the same way: a report edit that introduces a term adds its line in that edit. A name the glossary holds is used as it stands. Where the code and the glossary differ, the one that is wrong is corrected in the same commit, and a new word that departs from the report's goes to the user first.

@docs/style.md
