# Ernest — Claude Instructions

Ernest is a functional language for concurrent programs, designed by the user (joagre). It has two concepts: functions with Hindley-Milner types, and processes with typed mailboxes. The report under [`report/`](report/) is the language, in three files.

The rules follow the order of work. Each is stated once, and the checklist under *Done* names them.

## Authority

- **The report is the only normative document**: [`language.md`](report/language.md), §0 to §9 and Appendices A, B and F; [`toolchain.md`](report/toolchain.md), §10 to §12 and Appendices C and H; [`library.md`](report/library.md), Appendices D, E and G. None of the three ranks above another, and a citation's first number or letter names its file. Nothing else in this repository overrides them.
- **Appendix A, the grammar, wins** over the prose where they conflict.
- **Section 0, the five principles, is the tiebreaker**, where Appendix A is ambiguous and in every design discussion. Principles 2 to 5 construct, and principle 1 audits the result. A recommendation weighs the candidate rule against the five first, then against what it adds to the language, and names the principle that decided. The principles guide and are not law: §0 lets principle 1 override the others where following them surprises.

## Who owns each fact

Each fact has one owner. Every other document points at the owner and does not restate it. A fact a reader must not miss gets one line naming its owner, in the place that reader opens first.

| Owner | Owns |
|---|---|
| the report | the language, the library and the toolchain |
| [`docs/log/`](docs/log/README.md) | the rationale: why the report and the plan say what they say. Never normative, changes with them |
| [`docs/plan.md`](docs/plan.md) | the roadmap and where we are. Illustrative, as the programs under `examples/` are |
| the code and its tests | what is built |
| [`docs/README.md`](docs/README.md) | what each other document under `docs/` is, and each README it lists from outside `docs/`; each of them owns its subject |
| `findings.md` in `docs/`, while a review's findings are open | the findings, each line until a plan item decides it; it goes when every line is done, dropped or planned |
| [`guide/style.md`](guide/style.md) | what a program written in Ernest looks like, and the names every program shares |
| [`README.md`](README.md) | what Ernest is and where to begin |
| [`report/README.md`](report/README.md) | what the report's three files hold and how the report is read |
| [`guide/README.md`](guide/README.md) | what each guide is, for whom, and how long |
| [`tour/README.md`](tour/README.md) | the tour, whose chapters' programs under `tour/1/` to `tour/8/` a test holds equal to its blocks |
| [`CONTRIBUTING.md`](CONTRIBUTING.md) | how one takes part before 1.0: no contribution, a defect to the repository's issues |
| [`SECURITY.md`](SECURITY.md) | where to report a security hole |
| [`ACKNOWLEDGMENTS.md`](ACKNOWLEDGMENTS.md) | the people Ernest stands on, by name alone |
| [`CHANGES.md`](CHANGES.md) | each release's note, newest first: what the release is, and one line a change naming where it is read, restating nothing. The release step writes it and copies it to the release on GitHub |
| [`site/templates/README.md`](site/templates/README.md) | the site's templates and fragments, which a test holds each file to |
| [`site/projects.md`](site/projects.md) | the projects written in Ernest in repositories of their own, a line each, which a test holds to its form |

**A new owner.** A kind of fact that lands in the log entry after entry, with no document stating its present shape, has no owner. It gets one, a component's design note under `docs/design/`, as the shell's and the runtime's are, proposed when its third entry is written and not when a reader asks.

A design note states its component's design as it stands, and changes when its component does. It cites the report, names the log entry that argues each point, and states no why. It is written at the shape's altitude: what a reader must know to change the component without breaking a promise, which kind of fact lives where, and the rule a mechanism rests on, never what one function does. So it changes when the design does, and not with a line of code. A list in it that could drift from the code is held equal by a test.

**Proposals.** [`docs/proposals/`](docs/proposals/) holds what is designed, a directory for each: the proposal, its reasons, what other systems do, and its experiments or programs. Each directory's `README.md` says what its files are and which is current.

Until a proposal is decided all of it is tentative, and nothing flows from it into the report, the plan or the log. Nothing in it is ever authoritative, built or not.

A program with a repository of its own is written only by its own sessions. A session here reads it, and writes there only a change across the repositories, in the program's shape and never in what it says. How the two sessions work, and which files are which, is [`docs/clean_room.md`](docs/clean_room.md)'s. The program holds its proposal there, and what it asks of Ernest stays here under the program's name, the two citing each other by address. A proposal begun here before the repository exists is written whole, and split along that line in the commit that makes the repository.

A proposal refused or not taken up stays, its README's status line saying which. Only a built one goes.

A built proposal is kept as the record of its design, its status line saying so. It goes once its milestone's row names the log entries that argue it and nothing else cites the directory. First a reading, decided with the user, finds what it holds that no owner has yet, an experiment's finding or a table of what other systems do, and that goes to the design note or the log.

Meanwhile it changes only in its form, every decision, fact and number kept. A program under it that the tests still run follows the library's names, since the tests hold it to the library and not to the proposal.

**Handouts and scratch.** `docs/proposals/handouts/` holds a copy written for one reader outside the project, in that reader's terms, citing nothing. Nothing points at it, and it goes when its reader is done. A `scratch/` directory inside a proposal's own directory, untracked, is the user's own thinking: no session edits it, commits it or builds on it.

**Restating.** Only a teaching document restates: the guide and `src/shell/README.md` restate what they teach. Where a list must live in two places, a test keeping the two equal is welcome, not required.

**Where a sentence goes.** Decide the owner before you write. What will be built and when goes in the plan, and why goes in the log; a paragraph that does both is split at that line. A decision the user must see goes in the plan, in one sentence, with the report section that states it and the log entry that argues it, since the user reads the plan and not the log. A finished milestone is a row of the plan's table of milestones, naming its proposal and the log entries that argue it.

## The repository

- The implementation is Erlang, OTP 29. The toolchain is one command, `ern`, whose first word is its job: `ern build`, `ern run`. `make` builds; `make test` tests.
- Third-party code is listed in `THIRD_PARTY_LICENSES`. A borrowed file keeps its upstream header.
- All development runs on the main machine. Another machine only tests nodes across a real network, as `test/machines/` does.
- Work in the main checkout, on `main`, with no worktree and no branch of a session's own: the user reads and edits this checkout.
- An application's CLAUDE.md is `ernest-template`'s, which is cut from this file. A rule that changes here and applies there goes to the template, then to each copy. A good rule found in an application goes to the template, here where it applies, and from the template to the other copies.
- A job the discussion should not wait for goes to an agent, and so do one whose bulky output only its conclusion needs, an independent reader, and work that can run side by side. The session does the rest itself, since a short dependent chain costs more through an agent. An agent has one job, and its report is a claim: the session reads its diff and runs the check before reporting the work done.
- An agent follows this file. Its report comes back to the user and is written to a file under the session's scratchpad, which a compaction keeps whole. A step of many commands, a release's, keeps its checklist in such a file too. An agent drafts its log paragraph in that file and never edits the log: the session places it, so that the log keeps one voice and two agents never edit one file at once.
- An untracked file is the user's. `git status --short` is read before agents start and compared after they end, untracked files among it, and an agent is told in one line to leave them. An agent that dies leaves its processes and its nodes running: they are looked for and killed by their process numbers, never by a pattern.
- A session has one kind of work, chosen when it opens, since a change of model cold-starts its cache. A design session, for design, soundness, the weighing against §0 and report sentences, runs on the stronger model, because no test catches its errors. An item session, for an item's diagnosis, its plan and log, its read-backs and its agents, runs on the lesser model at the stronger effort. Their names are the session's memory's, not this repository's. The session cannot change its own model, so it tells the user in one line when the work calls for the other kind of session, with the command that opens it, and again when the work can go back.
- An agent is given its model and its effort when it is started: the stronger effort for a build in the checker, the emitter, the runtime or the nodes; the lesser for any other build from a settled brief, re-run once at the stronger from a brief naming the failure and then returned to the session; the lesser for a mechanical job with a test behind it; the stronger model for a review's reader and a cold reading of report sentences; the smallest model for a search that asks no judgment.
- Where one pass must be right with nobody reading along, a soundness paragraph or a large read-back, it runs in a design session, and the user is asked to raise that session's effort, in one line saying why and when to come back down.
- Context is most of what a session costs, so sessions stay short and the thinking stays strong. One item, one session: `/clear` follows its report, and the plan, the log, the commit and a scratch file hold what matters. A large session is finished or compacted before a long break, since the next message past the cache's life rebuilds it.
- Where a check that costs cycles and one that costs tokens would find the same thing, the one that costs cycles runs: a full run, a probe or a make target before a reader or a rework.
- A commit names its paths, `git commit -F message -- path...`, never a bare `git commit` after `git add`. The user stages their own work while a session runs: read `git status --short` first for entries that are not yours, and leave the index as the user left it. The message says what changed in one or two sentences and points to the log or the plan for why, restating neither. It carries no attribution line, no co-author and no session link: this file says who works here.

## Before code

- **The report changes first.** An anomaly found while implementing changes the report, then the log, then the code. Quote the exact section or grammar rule when touching normative material, and list the report sections a module implements before writing it.
- **A changed rule rewrites its soundness paragraph in the same commit.** [`docs/soundness.md`](docs/soundness.md) argues over §3 to §9 as they stand. Where the paragraph can no longer be made, that is a finding, discussed before the rule changes.
- **A design is discussed in its proposal, or in the user's note, until the user says it is ready.** Until then bring nothing of it to the plan, the log or the report, and ask nothing about it there. At a pause offer another reading back or a harder question: the principles, Erlang, other systems, the operator's day, a real program written against it. Once the user has opened the plan, the log or the report for the work, the next rule applies.

  A proposal, or a plan section written over one, is reported ready only after it has been read, unasked, against every owner it touches: each design note whose component it changes, the report sections it cites, the plan's items for it, and each proposal it meets at a seam. A seam is read from both sides, so that what one requires the other provides and no fact stands twice. The report to the user names the owners read.
- **State a change to the report or the plan and make it; do not ask.** Give the change and its argument, make it, and report it in the conformance section (*Done*). Stop and wait only where the answer decides what gets built and a guess would throw the work away.

  That rare case is a design question. It is discussed one at a time, in prose, the argument before the verdict, with a recommendation, never as a form of choices. Smaller decisions the user must make come together as one numbered list, each with its recommendation, for the user to accept or amend in one answer.

  A session opened to discuss alone writes nothing until the user asks. Then each write to the plan or the log is named in one line before it is made. A "go" covers the piece just discussed and not the topic. Where more rounds are coming, the writes are gathered into one commit at the pause.
- **A change to the grammar or to a rule of §3 to §9 is built the day it is decided**, after one cold reading of its sentences in the report and the log, before the code starts. The reading is the guard, since a decision of that kind built in one pass has been reversed the same afternoon. Everything else is built when decided.
- **Where a step looks wrong, say so once, hard**: the verdict, the principle that decides, the argument. If the user insists, build it whole, and the log entry records the decision with the argument against it. The code carries no trace of the dissent.
- **A finding is argued only after the log and the program.** The log is searched for the decision a finding or a `decide` line may sharpen, and the program that shows it is run in the session. A verdict recommended on a reader's probe alone says so. A batch of rules that changes what a job refuses, prints or exits with is run over the repository's own programs and tests, `make test-full` in the review's clone, once a batch before it is decided: an example's restart test is such a program.
- **Leave no decision pending.** A question a step raises is decided in the same turn, with its argument, and recorded in the plan and the log. One that needs the user is discussed at once, and stands in the plan meanwhile as a named decision in a named milestone, never as "open".

## Design

- **Prefer minimal, direct implementations** over speculative abstraction.
- **Judge features on the principles.** A feature enters or stays out by the five principles, and a standard library function by E.0's four admission rules, weighed one by one. The log names the principle that decided, never a count of programs (§0, principle 5). A feature left out is dropped, its verdict in the log, or goes into a milestone; nothing is kept for later.
- **A library under `src/libs/` is not a feature of the language.** Write one when our work needs it, when someone asks for it, or when we want it. It is Ernest's where it is over a specification a program of any kind may meet. One that a single kind of program speaks is that program's own module until another asks.
- **Bring options, not defenses.** When a simplification seems to conflict with a principle, first check whether the principle is being applied too dogmatically.
- **The tools are fast.** A job with nothing to do ends in about the time the host takes to start, and one with work spends its time on that work. A slow tool is a defect: measure it, and fix it at its cause or plan it with a date (the log's *Slow Tools Are Defects*). Every run of a tool or a target is timed against its work, and one that costs more is named to the user in the same message, not waited out.
- **What Ernest adds to a host operation costs a fraction of it.** A check, a count or a table row around a native call never costs a multiple of the call. An operation Erlang makes without a message makes none in Ernest; only a system process, and the runtime at a spawn or a monitor (§10), costs a message by design. No scan on an operation's path grows with anything but the operation's own input. Against a call that answers at once there is no fraction but nothing. How the runtime keeps its books under this rule is its design note's. Keep the runtime readable: a cost goes by needing less, never by a trick. `make bench` measures it.
- **Ernest is beautiful, inside and out.** Keep no code only to make it go faster: a second way of writing what the code already says, or a special case for speed, goes, and the cost the plain form leaves is stated in the log, not hidden. Measure first. Where the plain form is fast enough it stays plain. Where it is not, the host's own function is the first answer, and anything cleverer is decided with the user.
- **A measurement ends when its number stops deciding anything.** A number that confirms the plain form goes to the log once, and its item closes. Following it further is an item of its own, planned with the decision it would change.
- **No fixed sleep, in the code or in a test.** A process waits on what it means: a message, a monitor, a port that answers, a line written, a process's end, or a deadline the report states. A wait that is a time stays only where nothing else can show what it waits for, an absence above all. Derive it from what it waits for, never choose a number, and write the reason beside it.

## Shims

- **The shell's, a tool's and a program's work is written in Ernest.** Where a piece of work could be Ernest or Erlang, it is Ernest. Where only a missing function or library keeps it out, discuss the gap with the user and fill it, then write the work in Ernest; never in Erlang or behind a `foreign fn` meanwhile. In that work `foreign` is only what the host alone can do, given the layers beneath it: the shell reads its history file in Ernest because `Fs` is beneath it.
- **How a shim is written** is [`docs/code_style.md`](docs/code_style.md)'s *Shims*: where an operation is the host's function and where Ernest closes the difference, a type's representation, the upstream page, and no regular expression for a fixed question.

## Defects and gaps

- **No warts.** Never leave an approximation, a silent deviation from the report, or an unstated semantic choice in the code.
- **Fix a known defect when found.** A gap too large to fix now, or a defect not yet diagnosed, goes in the plan with a date and the shape of its fix, never in a comment. A refusal made for a later MVP's sake names that MVP in its error text, and `docs/development.md`'s table lists it, which a test checks.
- **Memory that no collection reclaims is a defect, fixed at its cause**, in the runtime, the toolchain, the shell and Ernest code alike. Never fix it by capping a list, a table or a cache. Add a cache only with an argument for what it holds and when it lets go. How memory is checked is [`docs/memory_checks.md`](docs/memory_checks.md)'s.
- **Nothing routes around a defect or a gap**, in the standard library, the shell, `examples/`, the guide, the report's examples or the tests. Code that meets a toolchain bug, a missing function, module or feature, or a command that cannot show something does not work around it, and does not hide it by choosing another example. Stop and say so: the gap goes to the report, Appendix E or the plan first, and what needed it says that it waits.
- **A refusal is a decision, and a workaround in prose is a gap.** A refusal the report states is weighed on the principles in its log entry. One whose only reason is how the code was built was never decided, and is weighed when found. A sentence that teaches a way around the tool, "the shortest way to", "write it as ... instead", is a gap with its workaround beside it, and goes as the rule above says.
- **A published specification or a general-purpose engine is a library's work**: a pattern language, a data format, a protocol, dates and times. Where Ernest code finds itself writing one, stop. The need goes to [`docs/language_feedback.md`](docs/language_feedback.md), and whether a library is written is decided with the user first. Splitting, trimming and sorting stay in the program.
- **Writing Ernest tests the language.** Where it feels against a principle, a workaround, a second way, something invisible, a function the library lacks, say so at once, add it to [`docs/language_feedback.md`](docs/language_feedback.md), and discuss it with the user before any code goes around it. A form the code repeats at site after site is felt the same way. The read-back that closes an item (*Done*) looks for one across the Ernest the item wrote, by a search over the sources with its count, never by the feel of one site (the log's *The Pun*).
- **Where the report is silent, add the sentence to the report or reject the input with an error.** Never accept it silently, and state the choice to the user.

## Tests

- **Every report section has a test** whose comment cites it (`%% report §5.4`). `make sections` names a section without one, which is not implemented.
- **A test written after the code is a regression test.** Say so, and name what it does not cover. What has found defects here is the terminal harness, a read-back of the code, an independent reader, and the user, not a test that passed on its first run.
- **A flake is tested under what it was seen under**, its browser or its load. A green run under anything else says nothing of it, and a cause not found is reported as not found. A step a long run rests on, a pull or a build, is checked in a call of its own before the run starts.
- **`make test`, the light run, runs before every commit.** `make test-full`, every area, runs before a release and before the commit that closes an item that touched the runtime, the nodes or the emitter. Any other item closes on its area's target and `make test`, the check that fits the change. A commit of documents alone runs `make test-docs`. While working, the area a change touches runs its own target; `docs/development.md`'s *Building* names them.
- **A new file is added before its check runs**, since the documents' and the style's tests read tracked files alone.
- **Edits to a proposal under discussion are committed at a pause**, at the end of a topic and not after each verdict: one `make test-docs`, which reads every tracked document, a proposal's among them, then one commit by their paths, pushed then. Code, the Makefile and other documents are tested as always.
- **Readers run before a release, and when the user asks**, as [`docs/reviews/release.md`](docs/reviews/release.md) says. The full review's readers read every area whole, when [`docs/reviews/full.md`](docs/reviews/full.md) says. The findings of any review or read are sorted as that document's *The findings* says, the `fix` lines made at once, and the rest decided as *Before code* says. A batch's report sentences are read cold, one reader over their diff, before the build starts: a sentence built on costs more to reword than one read.

## Writing

- **The report and the guide are tight, in a Wirth language report's register.** State the rule; no rationale, no restating. Clear before short: plain sentences, one rule per sentence, its exception and its example in sentences of their own. Cut a sentence for restating or rationale, never for a count: a long section is kept when every sentence states a rule.
- **Every other document is plain and short**, the plan, the log, a proposal, a commit message and this file among them. One point to a sentence, in the order a reader needs it, without chains of clauses.
- **A paragraph is one turn of the text**, in every document, in a comment of the code and in a message to the user. It says one thing, with that thing's exception and example, and a new paragraph begins where the text turns. A break is made where it helps the reader take the next thing in, and nowhere else: never at a count of words, never to shorten, and never later than the turn.

  A paragraph past about a hundred words, a list item among them, is read again for a turn it may hide, and left whole where it holds one thing; `make paragraphs` lists them. One past 150 words no reader takes in whole, so a test refuses it in every tracked document the listing reads, and the writer splits it at its turn before the commit.
- **A proposal and its reasons say what Ernest does, and why.** What was tried and set aside, and what Ernest does not do, stays in the experiment or goes to the log, not into the paragraph that states the rule.
- **An edit to a set a document names reads the whole page first**, a list, a count or the sections that restate it, and changes every place that enumerates the set, the README's and the plan's among them, in the same commit.
- **A shell session shown in the tour or the guide is cut where the lesson turns**, a sentence between the parts saying what the next lines show. A chapter's program stays one block, which a test holds equal to its file.
- **A report edit updates the revision date** in line 3 of each file it changes.
- **The report's section numbers never change**, since the documents, the tests and the code cite them. Never renumber, remove or insert a section between two others. A new rule goes into the section it belongs to; where none can hold it, a new section goes at the end of its chapter or appendix. The guide's numbers change only where a section cannot be placed otherwise.
- **Compiler behavior goes to §11.**
- **The spelling is American English**, in every document, name and message; `guide/style.md` states the rule and `docs/code_style.md`'s *Every language* the test's scope.
- **No document or message names who proposed an idea**, or that person's role; it states the argument. [`ACKNOWLEDGMENTS.md`](ACKNOWLEDGMENTS.md) and the report's dedication with its epigraph name people and argue nothing.

## Done

- **Read the result back before reporting it.** After a design change, read the resulting Ernest code as a reader who knows the rest of Ernest would, against the principles and E.0, which bind the standard library and the toolchain too, and say what surprised. Decide every surprise: act on it in the same item or leave it with its reason, and record it where its owner keeps it. One that needs the user goes to the user with a recommendation in the same report.
- **A step forward sweeps what it leaves behind.** What a step makes redundant goes in the step's own commit, never left for a review to find: a sentence, a file or a directory, a built proposal, a decided finding, a citation of what went. A done item's paragraph goes too, one line naming its log entry in its place until the milestone's row takes it.
- **Commit only after the checks pass**, on make's own exit status read in a call of its own, never chained after them with `;` and never on a pipe's, which a `grep` of the output would give. A deletion of tracked files is committed by path at once, or stays staged until the test has run. Push only when the user says so, a proposal's pause excepted (*Tests*).
- **Every message that reports an item that touched the report, the plan or an error's text ends with a "Report conformance" section**: the sections applied; every place the report was silent and what was done, or "none"; every deliberate omission, with the MVP that lifts it and the error the code gives meanwhile. "Tests green" does not replace it. A report of any other item says in one line that the report was not touched.
- **Stop after each plan item.** Finish it whole, report it, and wait: the user sees each item's design choices before the next builds on them.

**Closing an item.** Each line names a rule of this file; none adds one.

1. The report changed first, with its revision date, and the soundness paragraph of a rule it changed (*Before code*, *Writing*).
2. Every question decided, and every gap and needed decision in the plan with its log entry (*Before code*, *Defects and gaps*).
3. A refusal for a later MVP named in its text and listed in `docs/development.md`'s table (*Defects and gaps*).
4. What writing Ernest felt against a principle in `docs/language_feedback.md` (*Defects and gaps*).
5. Every report section the item built cited by a test, and a test written after the code called a regression test (*Tests*).
6. A new name in the glossary, and a new term in Appendix F (*Style*).
7. The result read back, and every surprise decided (*Done*).
8. The check that fits the item green, `make test-full` where it touched the runtime, the nodes or the emitter, and the conformance section written where it is due (*Tests*, *Done*).
9. A commit that names its paths. It sweeps what the item made redundant, every sentence elsewhere that says the item still waits among it, in `docs/development.md`'s table, the plan's tables, or an example's header (*Done*, *The repository*).
10. Where the item was its milestone's last, the same commit sweeps the plan: the milestone's section goes, its row names its proposal and the log entries that argue it, and every sentence of a later milestone that cited the section's items cites the log instead (*Where a sentence goes*, *Done*).
11. The report to the user, ending with *Report conformance*, then a stop until the user's word; a push only on that word (*Done*).

## Style

The two style documents, [`guide/style.md`](guide/style.md) for a program's Ernest and [`docs/code_style.md`](docs/code_style.md) for the repository's own code, are read before their language is written, the first before Ernest and the second before Erlang or C, by a session and by an agent, whose brief says so. Neither is imported here.

**The glossary is living.** A name that comes to recur across modules, or a concept the code names in two places, goes into the glossary in the commit that writes it, `guide/style.md`'s for an Ernest name and `docs/code_style.md`'s for the toolchain's, in the report's word where the report names the concept. Appendix F is living the same way: a report edit that introduces a term adds its line in that edit. Use a name the glossary holds as it stands. Where the code and the glossary differ, correct the wrong one in the same commit; a new word that departs from the report's goes to the user first.
