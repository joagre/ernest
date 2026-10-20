# Ernest — Claude Instructions

Ernest is a functional language for concurrent programs, designed by the user (joagre). Two concepts: functions with Hindley-Milner types, and processes with typed mailboxes. The report under [`report/`](report/) is the language, in three files.

The rules follow the order of work. Each is stated once; the checklist under *Done* names them.

## Authority

- **The report is the only normative document**: [`language.md`](report/language.md), §0 to §10 and Appendices A, B and F; [`toolchain.md`](report/toolchain.md), §11 and Appendices C and H; [`library.md`](report/library.md), Appendices D, E and G. None of the three ranks above another; a citation's first number or letter names its file. Nothing else in this repository overrides them.
- **Appendix A, the grammar, wins** over the prose where they conflict.
- **Section 0, the five principles, is the tiebreaker**: where Appendix A is ambiguous, and in every design discussion. Principles 2 to 5 construct; principle 1 audits the result. Every recommendation weighs the candidate rule against the five first, and against what it adds to the language, and names the principle that decided. The principles guide and are not law: §0 itself lets principle 1 override the others where following them surprises.

## Who owns each fact

Each fact has one owner. Every other document points at the owner and does not restate it; a fact a reader must not miss gets one line naming its owner, in the place that reader opens first.

| Owner | Owns |
|---|---|
| the report | the language, the library and the toolchain |
| [`docs/decisions.md`](docs/decisions.md) | the rationale: why the report and the plan say what they say. Never normative, changes with them |
| [`docs/implementation_plan.md`](docs/implementation_plan.md) | the roadmap and where we are. Illustrative, as the programs under `examples/` are |
| the code and its tests | what is built |
| [`docs/architecture.md`](docs/architecture.md) | how the code is arranged |
| [`docs/style.md`](docs/style.md) | the code's form and naming |
| [`README.md`](README.md) | what Ernest is and where to begin |
| [`ACKNOWLEDGMENTS.md`](ACKNOWLEDGMENTS.md) | the people Ernest stands on, by name alone |
| [`docs/development.md`](docs/development.md) | the layout, the commands, and what the toolchain does not do yet |
| [`docs/README.md`](docs/README.md) | what each document under `docs/` is |
| `docs/design/shell.md`, `docs/design/install.md`, [`docs/design/emacs_mode.md`](docs/design/emacs_mode.md) | each its component's design; a design note changes when its component does |
| [`src/shell/README.md`](src/shell/README.md) | how the shell's code reads |
| [`editors/emacs/README.md`](editors/emacs/README.md) | how to install the Emacs mode, and what it leaves to the reader's configuration |
| [`docs/module_doc_template.md`](docs/module_doc_template.md) | the worked example of a documented module, held equal to `ern doc`'s output by a test |
| [`docs/release_review.md`](docs/release_review.md) | what a release runs to be ready |
| [`docs/full_review.md`](docs/full_review.md) | the review of every area whole, run seldom |
| [`docs/principles_review.md`](docs/principles_review.md) | the report and the guide read against §0, and §0 against what it decided |
| [`docs/memory.md`](docs/memory.md) | how memory is checked |
| [`docs/soundness.md`](docs/soundness.md) | the argument that a well-typed program does not go wrong |
| [`docs/otp_bugs.md`](docs/otp_bugs.md) | the defects found in OTP, each a report ready for OTP's tracker, until a release Ernest requires has its fix |
| [`docs/diagnostics.md`](docs/diagnostics.md) | the catalog of diagnostics, which `make diagnostics` writes |
| [`docs/man/`](docs/man/) | the pages as CommonMark, which `make man` writes from `main` |
| [`assets/README.md`](assets/README.md) | the logo files |
| [`tools/release/README.md`](tools/release/README.md) | what a reader of the release archive, or of an installation, needs first |
| [`docs/language_feedback.md`](docs/language_feedback.md) | what writing Ernest has felt against the principles, each line until a plan item decides it |
| `findings.md` in `docs/`, while a review's findings are open | the findings, each line until a plan item decides it; it goes when every line is done, dropped or planned |

**Proposals.** [`docs/proposals/`](docs/proposals/) holds what is designed, a directory for each: the proposal, its reasons, what other systems do, and its experiments or programs. Each directory's `README.md` says what its files are and which is current. Until a proposal is decided all of it is tentative, and nothing flows from it into the report, the plan or the log; nothing in it is ever authoritative, built or not. A built proposal is kept as the record of its design, its status line saying so, until its milestone's row names the log entries that argue it and nothing else cites the directory; then it goes, after a reading decided with the user of what it holds that no owner has yet, an experiment's finding or a table of what other systems do, which goes first to the design note or the log that keeps it. Meanwhile it does not change but in its form, a paragraph broken where it turns with every decision, fact and number kept; a program under it that the tests still run follows the library's names, since the tests hold it to the library and not to the proposal.

**Handouts and scratch.** `docs/proposals/handouts/` holds a copy written for one reader outside the project, in that reader's terms, citing nothing; nothing points at it, and it goes when its reader is done. A `scratch/` directory inside a proposal's own directory, untracked, is the user's own thinking: no session edits it, commits it or builds on it.

**Restating.** Only a teaching document restates: the guide and `src/shell/README.md` restate what they teach. Where a list must live in two places, a test keeping the two equal is welcome, not required.

**Where a sentence goes.** Decide the owner before you write. What will be built and when goes in the plan; why goes in the log; a paragraph that does both is split at that line. A decision the user must see goes in the plan, in one sentence, with the report section that states it and the log entry that argues it, since the user reads the plan and not the log. A finished milestone in the plan is a row of its table of milestones, naming the log entries that argue it.

## The repository

- The implementation is Erlang, OTP 29. The toolchain is one command, `ern`, whose first word is its job: `ern build`, `ern run`. `make` builds; `make test` tests.
- Third-party code is listed in `THIRD_PARTY_LICENSES`. A borrowed file keeps its upstream header.
- Work in the main checkout, on `main`. No worktree and no branch of a session's own: the user reads and edits this checkout.
- A coding job of many steps goes to an agent, so that the discussion with the user goes on while it runs. The agent follows this file, and its report comes back to the user.
- Where the work changes kind, between design, report prose or a read-back on one side and a build from a settled brief on the other, say in one line which model the next piece wants before starting it: the user switches the session's model by hand. An agent is given its model when it is started.
- A commit names its paths, `git commit -F message -- path...`, never a bare `git commit` after `git add`. The user stages their own work while a session runs: read `git status --short` first for entries that are not yours, and leave the index as the user left it. The message says what changed in one or two sentences and points to the log or the plan for why, restating neither.

## Before code

- **The report changes first.** An anomaly found while implementing changes the report, then the log, then the code. Quote the exact section or grammar rule when touching normative material, and list the report sections a module implements before writing it.
- **A changed rule rewrites its soundness paragraph in the same commit.** [`docs/soundness.md`](docs/soundness.md) argues over §3 to §9 as they stand. Where the paragraph can no longer be made, that is a finding, discussed before the rule changes.
- **A design is discussed in its proposal until the user says it is ready.** The user thinks in a proposal or a note, reads it back with care and discusses it until it is solid. Until then bring nothing of it to the plan, the log or the report, and ask nothing about it there. At a pause offer another reading back or a harder question: the principles, Erlang, other systems, the operator's day, a real program written against it. Once the user has opened the plan, the log or the report for the work, the next rule applies.
- **State a change to the report or the plan and make it; do not ask.** Give the change and its argument, make it, report it in the conformance section (*Done*). Stop and wait only where the answer decides what gets built and a guess would throw the work away.

  That rare case is a design question: discussed one at a time, in prose, the argument before the verdict, with a recommendation, never as a form of choices. Smaller decisions the user must make come together, as one numbered list, each with its recommendation, for the user to accept or amend in one answer.

  A session opened to discuss alone writes nothing until the user asks. Then each write to the plan or the log is named in one line before it is made, a "go" covers the piece just discussed and not the topic, and where more rounds are coming the writes are gathered into one commit at the pause.
- **Leave no decision pending.** A question a step raises is decided in the same turn, with its argument, and recorded in the plan and the log. One that needs the user is discussed at once and stands in the plan meanwhile as a named decision in a named milestone, never as "open". An undiagnosed defect is planned the same way, with a date and the shape of its fix.

## Design

- **Prefer minimal, direct implementations** over speculative abstraction.
- **Judge features on the principles.** A feature enters or stays out by the five principles, and a standard library function by E.0's four admission rules, weighed one by one. How many programs ask for it decides nothing: the log names the principle that decided, never a count of programs. A feature left out is dropped, its verdict in the log, or goes into a milestone; nothing is kept for later. A library under `src/libs/` is not a feature of the language: write one when our work needs it, when someone asks for it, or when we want it.
- **Bring options, not defenses.** When a simplification seems to conflict with a principle, first check whether the principle is being applied too dogmatically.
- **The tools are fast.** A job with nothing to do ends in about the time the host takes to start, and one with work spends its time on that work. A slow tool is a defect: measure it, and fix it at its cause or plan it with a date (the log's *Slow Tools Are Defects*). Every run of a tool or a target is timed against its work; one that costs more is named to the user in the same message, not waited out.
- **What Ernest adds to a host operation costs a fraction of it.** A check, a count or a table row around a native call never costs a multiple of the call; an operation Erlang makes without a message makes none in Ernest; only a system process, and the runtime at a spawn or a monitor (§10), costs a message by design. No scan on an operation's path grows with anything but the operation's own input. Keep the runtime readable: a cost goes by needing less, never by a trick. `make bench` measures it.
- **Ernest is beautiful, inside and out.** Keep no code only to make it go faster: a second way of writing what the code already says, or a special case for speed, goes, and the cost the plain form leaves is stated in the log, not hidden. Measure first; where the plain form is fast enough it stays plain; where it is not, the host's own function is the first answer, and anything cleverer is decided with the user.
- **No fixed sleep, in the code or in a test.** A process waits on what it means: a message, a monitor, a port that answers, a line written, a process's end, or a deadline the report states. A wait that is a time stays only where nothing else can show what it waits for, an absence above all; derive it from what it waits for, never choose a number, and write the reason beside it.

## Shims

- **The shell's, a tool's and a program's work is written in Ernest.** Where a piece of work could be Ernest or Erlang, it is Ernest. Where only a missing function or library keeps it out, discuss the gap with the user and fill it, then write the work in Ernest; never in Erlang or behind a `foreign fn` meanwhile. In that work `foreign` is only what the host alone can do, given the layers beneath it: the shell reads its history file in Ernest because `Fs` is beneath it.
- **The standard library and the libraries stand on the host.** Where a host function does exactly an operation's work, the operation is its shim, so that Ernest runs at the host's speed wherever the host does the work.

  Where one almost does, Ernest closes the difference around a shim that is the host function exactly; an Erlang adapter only where that Ernest measurably costs, with the numbers in the log, or where Ernest cannot close it: a raise it cannot foresee short of doing the host's work, or a host term no Ernest type describes. Where none does, the operation is Ernest. An operation that is the host's own operators applied once, `if int < 0 then -int else int`, already runs at the host's speed, and a shim would add a call.

  E.0 rule 1 is the normative half of this rule; where the two differ, correct the report.
- **Whether a type's representation is the runtime's is a decision of its own**, recorded in E.0 and the log. `Map` is Erlang's map and `String` a binary, so the operations that reach the representation are the host's.

  An operation on a value the language owns, a list, a tuple or a bitstring, is a shim where a host function does exactly its work. Where one only almost does, the operation is Ernest alone, which reaches the value as the host does, unless that Ernest costs more than three times the host function or grows where it does not (E.0 rule 1).
- **Write a shim with the upstream manual page open.** Carry its arguments, edge cases and the errors it returns and raises into the Ernest contract. A host function is exact only by its page: one whose page leaves unspecified what the contract states, the order it calls a callback in among it, is not exact, and Ernest closes the difference.

  The page is a source of truth, never of wording: the prose is ours (E.0 shape rule 6), nothing is copied.

  A host module whose documentation is hidden is used only where decided with the user: `unicode_util`'s tables behind `Char` (the log's *Char Reads the Host's Tables*).
- **No regular expression answers a fixed question in the runtime.** A shim that asks one thing of each value, a category, a literal's form, tests it directly.

## Defects and gaps

- **No warts.** Never leave an approximation, a silent deviation from the report, or an unstated semantic choice in the code.
- **Fix a known defect when found.** A gap too large to fix now goes in the plan with a date, never in a comment. A refusal made for a later MVP's sake names that MVP in its error text, and `docs/development.md`'s table lists it, which a test checks.
- **Memory that no collection reclaims is a defect, fixed at its cause**, in the runtime, the toolchain, the shell and Ernest code alike. Never fix it by capping a list, a table or a cache. Add a cache only with an argument for what it holds and when it lets go. How memory is checked is [`docs/memory.md`](docs/memory.md)'s.
- **Nothing routes around a defect or a gap**, in the standard library, the shell, `examples/`, the guide, the report's examples or the tests. Code that meets a toolchain bug, a missing function, module or feature, or a command that cannot show something does not work around it or hide it by choosing another example. Stop and say so: the gap goes to the report, Appendix E or the plan first, and what needed it says that it waits.
- **A published specification or a general-purpose engine is a library's work**: a pattern language, a data format, a protocol, dates and times. Where Ernest code finds itself writing one, stop; the need goes to [`docs/language_feedback.md`](docs/language_feedback.md), and whether a library is written is decided with the user first. Splitting, trimming and sorting stay in the program.
- **Writing Ernest tests the language.** Where it feels against a principle, a workaround, a second way, something invisible, a function the library lacks, say so at once, add it to [`docs/language_feedback.md`](docs/language_feedback.md), and discuss it with the user before any code goes around it.
- **Where the report is silent, add the sentence to the report or reject the input with an error.** Never accept it silently, and state the choice to the user.

## Tests

- **Every report section has a test** whose comment cites it (`%% report §5.4`); `make sections` names a section without one, which is not implemented.
- **A test written after the code is a regression test.** Say so, and name what it does not cover. What has found defects here is the terminal harness, a read-back of the code, an independent reader, and the user, not a test that passed on its first run.
- **`make test`, the light run, runs before every commit; `make test-full`, every area, before the commit that closes a plan item and before a release.** A commit of documents alone runs `make test-docs`. While working, the area a change touches runs its own target; `docs/development.md`'s *Building* names them.
- **Edits to a proposal under discussion are committed at a pause**, at the end of a topic and not after each verdict: one `make test-docs`, which reads every tracked document, a proposal's among them, then one commit by their paths, pushed then. Code, the Makefile and other documents are tested as always.
- **Readers run before a release, and when the user asks**, as [`docs/release_review.md`](docs/release_review.md) says; the full review's readers read every area whole, when [`docs/full_review.md`](docs/full_review.md) says; the findings of any review or read are sorted as that document's *The findings* says, the `fix` lines made at once, and the rest decided as *Before code* says: a design question on its own, the smaller decisions as one numbered list with recommendations.

## Writing

- **The report and the guide are tight, in a Wirth language report's register.** State the rule; no rationale, no restating. Clear before short: plain sentences, one rule per sentence, its exception and its example in sentences of their own. Cut a sentence for restating or rationale, never for a count: a long section is kept when every sentence states a rule.
- **A paragraph is one turn of the text, in every document and in a message to the user.** It says one thing, with that thing's exception and example, and a new paragraph begins where the text turns to the next thing.

  A break is made where it helps the reader take the next thing in, and nowhere else: never at a count of words, never to shorten, and never later than the turn. A paragraph past about a hundred words, a list item among them, which `make paragraphs` lists, is read again for a turn it may hide, and left whole where it holds one thing.

  This binds an answer in the guide's §12, a log entry, a README and a proposal as it binds the report: the writer who has filled a block with five points has written five paragraphs.
- **The plan, the log, a proposal and a commit message are plain and short.** One point to a sentence, in the order a reader needs it, without chains of clauses; the register above is the report's and the guide's alone.
- **A proposal and its reasons say what Ernest does, and why.** What was tried and set aside, and what Ernest does not do, stays in the experiment or goes to the log, not into the paragraph that states the rule.
- **A report edit updates the revision date** in line 3 of each file it changes.
- **The report's section numbers never change**, since the documents, the tests and the code cite them. Never renumber, remove or insert a section between two others. A new rule goes into the section it belongs to; where none can hold it, a new section goes at the end of its chapter or appendix. The guide's numbers change only where a section cannot be placed otherwise.
- **Compiler behavior goes to §11.**
- **The spelling is American English**, in every document, name and message; `docs/style.md`'s *Every language* states the rule and its two exceptions.
- **No document or message names who proposed an idea**, or that person's role; it states the argument. [`ACKNOWLEDGMENTS.md`](ACKNOWLEDGMENTS.md) and the report's dedication with its epigraph name people and argue nothing.

## Done

- **Read the result back before reporting it.** After a design change, read the resulting Ernest code as a reader who knows the rest of Ernest would, against the principles and E.0, which bind the standard library and the toolchain too, and say what surprised. Decide every surprise, not only say it: act on it in the same item or leave it with its reason, record it where its owner keeps it, and take one that needs the user to the user with a recommendation in the same report.
- **Commit only after the checks pass**, never chained after them with `;`. Push only when the user says so, a proposal's pause excepted (*Tests*).
- **Every message that reports code work ends with a "Report conformance" section**: the sections applied; every place the report was silent and what was done, or "none"; every deliberate omission, with the MVP that lifts it and the error the code gives meanwhile. "Tests green" does not replace it.
- **Stop after each plan item.** Finish it whole, report it, and wait: the user sees each item's design choices before the next builds on them.

**Closing an item.** Each line names a rule above; none adds one.

1. The report changed first, with its revision date, and the soundness paragraph of a rule it changed (*Before code*, *Writing*).
2. Every question decided, and every gap and needed decision in the plan with its log entry (*Before code*, *Defects and gaps*).
3. A refusal for a later MVP named in its text and listed in `docs/development.md`'s table (*Defects and gaps*).
4. What writing Ernest felt against a principle in `docs/language_feedback.md` (*Defects and gaps*).
5. Every report section the item built cited by a test, and a test written after the code called a regression test (*Tests*).
6. A new name in the glossary, and a new term in Appendix F (*Style*).
7. The result read back, and every surprise decided (*Done*).
8. `make test-full` green; the conformance section written; every known gap in the plan; the same commit removes every sentence elsewhere that says the item still waits, in `docs/development.md`'s table, the plan's tables, or an example's header; then a commit that names its paths (*Tests*, *Done*, *The repository*).
9. The report to the user, ending with *Report conformance*, then a stop until the user's word; a push only on that word (*Done*).
10. Where the item was its milestone's last, the same commit sweeps the plan: the milestone's section goes, its row names its proposal and the log entries that argue it, and every sentence of a later milestone that cited the section's items cites the log instead (*Where a sentence goes*).

## Style

[`docs/style.md`](docs/style.md) holds the style guides for Erlang, C and Ernest, imported here.

**The glossary is living.** A name that comes to recur across modules, or a concept the code names in two places, goes into `docs/style.md`'s glossary in the commit that writes it, in the report's word where the report names the concept. Appendix F is living the same way: a report edit that introduces a term adds its line in that edit. Use a name the glossary holds as it stands. Where the code and the glossary differ, correct the wrong one in the same commit; a new word that departs from the report's goes to the user first.

@docs/style.md
