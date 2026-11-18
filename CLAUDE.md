# Ernest — Claude Instructions

Ernest is a functional language for concurrent programs, designed by the user (joagre). It has two concepts: functions with Hindley-Milner types, and processes with typed mailboxes. The report under [`report/`](report/) is the language, in three files.

The rules follow the order of work. Each is stated once, and the checklist under *Done* names them.

## Authority

- **The report is the only normative document**: [`language.md`](report/language.md), §0 to §9 and Appendices A, B and F; [`toolchain.md`](report/toolchain.md), §10 to §12 and Appendices C and H; [`library.md`](report/library.md), Appendices D, E and G. None of the three ranks above another, and a citation's first number or letter names its file. Nothing else in this repository overrides them.
- **Appendix A, the grammar, wins** over the prose where they conflict.
- **Section 0, the five principles, decides where Appendix A is ambiguous**, and is the measure in every design discussion. Principles 2 to 5 construct, and principle 1 audits the result: where following them yields code that surprises, principle 1 overrides (§0). A recommendation weighs the candidate rule against the five first, then against what it adds to the language, and names the principle that decided. The principles guide and are not law: each is weighed with judgment, and one applied too dogmatically yields (*Design*).

## Who owns each fact

Each fact has one owner. Every other document points at the owner and does not restate it. A fact a reader must not miss gets one line naming its owner, in the place that reader opens first.

| Owner | Owns |
|---|---|
| the report | the language, the library and the toolchain |
| [`docs/log/`](docs/log/README.md) | the rationale: why the report and the plan say what they say. Never normative. It gains an entry when they change |
| [`docs/plan.md`](docs/plan.md) | the roadmap and where we are. Illustrative, as the programs under `examples/` are |
| the code and its tests | what is built |
| [`docs/README.md`](docs/README.md) | what each other document under `docs/` is, and each README it lists from outside `docs/`; each of them owns its subject |
| `findings.md` in `docs/`, while a review's findings are open | the findings, each line until a plan item decides it; it goes when every line is done, dropped or planned |
| [`CHANGES.md`](CHANGES.md) | each release's note, newest first; [`docs/reviews/release.md`](docs/reviews/release.md) says how it is written, and a test holds its form |

**A new owner.** A kind of fact that lands in the log entry after entry, with no document stating its present shape, gets an owner: a component's design note under `docs/design/`, proposed when its third entry is written.

A design note states its component's design as it stands. It cites the report, names the log entry that argues each point, and states no why. It is written at the shape's altitude: what a reader must know to change the component without breaking a promise, which kind of fact lives where, and the rule a mechanism rests on, never what one function does. So it changes when the design does, and not with a line of code. A list in it that could drift from the code is held equal by a test.

**Proposals.** [`docs/proposals/`](docs/proposals/) holds what is designed, a directory for each: the proposal, its reasons, what other systems do, and its experiments or programs. Each directory's `README.md` says what its files are and which is current.

Until a proposal is decided all of it is tentative. Nothing in it is ever authoritative, built or not.

A program with a repository of its own is written only by its own sessions. A session here reads it, and writes there only a change across the repositories. [`docs/clean_room.md`](docs/clean_room.md) says how, and where the program's proposal lives. A session reads that file before it writes in another repository.

A proposal refused or not taken up stays, its README's status line saying which. A built one stays as the record of its design until its milestone's release, its status line saying so. Meanwhile it changes only in its form, every decision, fact and number kept.

Before that release, an item of the milestone that built the proposal reads it for what it holds that no owner has yet, in a reading decided with the user, and that goes to the design note or the log. The same item removes the directory, once the milestone's row names the log entries that argue it and nothing else cites the directory.

**Restating.** Only a teaching document restates: the guide, the tour and `src/shell/README.md` restate what they teach. Where a list must live in two places, a test keeping the two equal is welcome, and required in a design note.

**Where a sentence goes.** Decide the owner before you write. What will be built and when goes in the plan, and why goes in the log; a paragraph that does both is split at that line. A decision the user must see goes in the plan, in one sentence, with the report section that states it and the log entry that argues it. A finished milestone is a row of the plan's table of milestones, naming its proposal and the log entries that argue it.

## The repository

- The implementation is Erlang, OTP 29, and Ernest where *Ernest or Erlang* says. The toolchain is one command, `ern`, whose first word is its job: `ern build`, `ern run`. `make` builds; `make test` tests.
- Third-party code is listed in `THIRD_PARTY_LICENSES`. A borrowed file keeps its upstream header.
- All development runs on the main machine. Another machine only tests nodes across a real network, as `test/machines/` does.
- Work in the main checkout, on `main`, with no worktree and no branch of a session's own: the user reads and edits this checkout. The one exception is the fresh clone a review builds and tests in, as [`docs/reviews/release.md`](docs/reviews/release.md) says.
- An application's `CLAUDE.md` is `ernest-template`'s, which is cut from this file. A rule that changes in one of them goes to the template, then to this file and each copy where it applies.
- The session is for design, reasoning and coordination, and code is written by agents. The session diagnoses, writes each brief, reads each diff back and decides. The session itself makes an edit that adds no function and no test: a sentence, a one-line fix or a version, since a short dependent chain costs more through an agent.
- An independent reader, a job the discussion should not wait for, and work that can run side by side go to agents too. An agent has one job, and its report is a claim: the session reads its diff and runs the check before reporting the work done.
- Before a session starts its first agent it reads [`docs/agents.md`](docs/agents.md): what a brief holds, the model and the effort each job gets, and what is checked before agents start and after they end.
- An untracked file the session did not write is the user's: no session edits it, commits it or builds on it.
- Every session runs on the stronger model, since the design, the weighing against §0 and the read-back have no test to catch their errors. Its agents run on the models `docs/agents.md` names.
- The session keeps conclusions in its context and not working material. It takes an agent's report from its file and a test's exit status and failures, and reads no file just to follow along.
- Where one pass must be right with nobody reading along, a soundness paragraph or a large read-back, the user is asked to raise the session's effort, in one line saying why and when to come back down.
- Context is most of what a session costs, so sessions stay short and the thinking stays strong. One item or one run of items, one session: `/clear` follows its report to the user, and the plan, the log, the commit and a scratch file hold what matters. Each suggestion of `/clear` gives, word for word, the message to send after it. A large session is finished or compacted before a long break, since the next message past the cache's life rebuilds it.
- Where a check that costs cycles and one that costs tokens would find the same thing, the one that costs cycles runs: a full run, a probe or a make target before a reader or a rework.
- A commit names its paths, `git commit -F message -- path...`, never a bare `git commit` after `git add`. The user stages their own work while a session runs: read `git status --short` first for entries that are not yours, and leave the index as the user left it, but for a new file of the session's own and a deletion (*Tests*, *Done*). The message says what changed in one or two sentences and points to the log or the plan for why, restating neither. It carries no attribution line, no co-author and no session link: this file says who works here.

## Before code

- **The report changes first.** An anomaly found while implementing changes the report, then the log, then the code. Quote the exact section or grammar rule when touching normative material, and list the report sections a module implements before writing it.
- **A changed rule rewrites its soundness paragraph in the same commit.** [`docs/soundness.md`](docs/soundness.md) argues over §3 to §9 as they stand. Where the paragraph can no longer be made, that is a finding, discussed before the rule changes.
- **A design is discussed in its proposal, or in the user's note, until the user says it is ready.** Until then bring nothing of it to the plan, the log or the report, and ask nothing about it there. At a pause offer another reading back or a harder question: the principles, Erlang, other systems, the operator's day, a real program written against it. Once the user has opened the plan, the log or the report for the work, the next rule applies.

  A proposal, or a plan section written over one, is reported ready only after it has been read, unasked, against every owner it touches: each design note whose component it changes, the report sections it cites, the plan's items for it, and each proposal it meets at a seam. A seam is read from both sides, so that what one requires the other provides and no fact stands twice. The report to the user names the owners read.
- **A no-brainer is stated and made; everything else is discussed first.** A change to the report or the plan that nobody would argue about once it is read is made, with its argument, and reported in the conformance section (*Done*). Any other, a wider rule than the one agreed, another error's text or a finding of the session's own among them, is brought to the user before it is written, with a recommendation and its reason, and discussed carefully.

  A design question is discussed one at a time, in prose, the argument before the verdict, with a recommendation, never as a form of choices. Smaller decisions the user must make come as a numbered list, each with its recommendation.

  A session opened to discuss alone writes nothing until the user asks. Then each write to the plan or the log is named in one line before it is made. A "go" covers the piece just discussed and not the topic. Where more rounds are coming, the writes are gathered into one commit at a pause, the end of a topic and not each verdict, by their paths. A proposal's commit is pushed then.
- **One issue at a time, or a few.** A round of findings, a build's brief and a message to the user each take one issue, or a few that belong together, never everything at once. What waits stands in the findings file or the plan meanwhile.
- **Once a build has started, the sentences it builds to do not change until it is back.**
- **A change to the grammar or to a rule of §3 to §9 is built the day it is decided**, after one cold reading of its sentences in the report and the log, before the code starts. The reading is the guard, since a decision of that kind built in one pass has been reversed the same afternoon. Everything else is built when decided.
- **Where a step looks wrong, say so once, hard**: the verdict, the principle that decides, the argument. A plan's item, the user's own idea and a suggestion of the session's own are steps too: before work starts on one, say whether it is worth doing, and say no where it is not. If the user insists, build it whole, and the log entry records the decision with the argument against it. The code carries no trace of the dissent.
- **A finding is argued only after the log and the program.** The log is searched for the decision a finding or a `decide` line may sharpen, and the program that shows it is run in the session. A verdict recommended on a reader's probe alone says so. A batch of rules that changes what a job refuses, prints or exits with is run over the repository's own programs and tests, `make test-full` in the review's clone, once a batch before it is decided: an example's restart test is such a program.
- **Leave no decision pending.** A question that waits for the user stands in the plan as a named decision in a named milestone, never as "open".

## Design

- **Prefer minimal, direct implementations** over speculative abstraction.
- **Judge features on the principles.** A feature enters or stays out by the five principles, and a standard library function by E.0's four admission rules, weighed one by one. The log names the principle that decided, never a count of programs (§0, principle 5). A feature left out is dropped, its verdict in the log, or goes into a milestone; nothing is kept for later.
- **A library under `src/libs/` is not a feature of the language**, and needs no principle to enter: our work needing it, someone asking for it, or our wanting it is reason enough. It is Ernest's where it implements a specification that programs of any kind may meet. Where one kind of program alone speaks the specification, the library is that program's own module until another asks. Ernest code that finds itself writing one stops first (*Defects and gaps*).
- **Bring options, not defenses.** When a simplification seems to conflict with a principle, first check whether the principle is being applied too dogmatically. Then bring the ways the simplification could be made, not a defense of what stands.
- **A hole is answered first by a narrower promise.** Where a reading finds a hole in a guarantee, ask first whether the guarantee can be stated more narrowly and still be useful and true. A mechanism that keeps the wider one is added only where the narrow one is not worth making, and the log says which was chosen.
- **A defense names its attacker.** A rule or a check against a hostile or broken input says who can make that input and what they could do without it. Where they could already do more, it is a robustness fix: one guard at the cause, one sentence, and no rule for each place.
- **The tools are fast.** A job with nothing to do ends in about the time the host takes to start, and one with work spends its time on that work. A slow tool is a defect: measure it (the log's *Slow Tools Are Defects*). Every run of a tool or a target is timed against its work, and one that costs more is named to the user in the same message, not waited out.
- **Ernest is lean.** Memory counts as much as time. A run, a node and each resource hold only what their work needs. What would be held in every run for a rare case is a cost every run pays, and is weighed as one (the log's *Lean at the Limits*).
- **What Ernest adds to a host operation costs a fraction of it.** A check, a count or a table row around a native call costs a fraction of the call. An operation Erlang makes without a message makes none in Ernest; only a system process, and the runtime at a spawn or a monitor (§10), costs a message by design. No scan on an operation's path grows with anything but the operation's own input. Around a call that answers at once a fraction has no meaning: there the bookkeeping writes nothing on the call's path. How the runtime keeps its books under this rule is its design note's. `make bench` measures it.
- **Ernest is beautiful, inside and out.** Keep no code only to make it go faster: a second way of writing what the code already says, or a special case for speed, goes, and the cost the plain form leaves is stated in the log, not hidden. Measure first. Where the plain form keeps the three rules above, it stays plain. Where it does not, the cost goes first by needing less, then by the host's own function, and anything cleverer is decided with the user.
- **A measurement ends when its number stops deciding anything.** A number that confirms the plain form goes to the log once, and its item closes. Following it further is an item of its own, planned with the decision it would change.
- **No fixed sleep, in the code or in a test.** A process waits on what it means: a message, a monitor, a port that answers, a line written, a process's end, or a deadline the report states. A wait that is a time stays only where nothing else can show what it waits for, an absence above all. Derive it from what it waits for, never choose a number, and write the reason beside it.
- **Ernest asks a machine for a new OTP, and nothing else new.** A call of the operating system's that Ernest's own code rests on has been in its kernel for five years or more. Its floor stands in the README, and a machine below it is refused with its reason (*Defects and gaps*). Where only a newer call would do, the choice goes to the user.

## Ernest or Erlang

- **What must run before an Ernest program can is Erlang**: the compiler, the runtime, the nodes and what reads their configuration. The existing jobs of `ern` stay Erlang. The shell's work, a program's, a program under `tools/` and a new job of `ern` that an Ernest program could do are written in Ernest. Any other piece of work that could be either is Ernest.
- **A gap does not move that work to Erlang.** Where only a missing function or library keeps a piece of it out of Ernest, the gap takes its path (*Defects and gaps*) and is filled first, and the work is then written in Ernest; never in Erlang or behind a `foreign fn` meanwhile. In that work `foreign` is only what the host alone can do, given the layers beneath it: the shell reads its history file in Ernest because `Fs` is beneath it.
- **How a shim is written** is [`docs/code_style.md`](docs/code_style.md)'s *Shims*.

## Defects and gaps

- **No warts.** Never leave an approximation, a silent deviation from the report, or an unstated semantic choice in the code.
- **Nothing routes around a defect or a gap**, anywhere Ernest is written or shown. Code that meets a toolchain bug, a missing function, module or feature, or a command that cannot show something does not work around it, and does not hide it by choosing another example. A sentence that teaches a way around the tool, "the shortest way to", "write it as ... instead", is such a gap with its workaround beside it. Stop and say so: the gap takes its path, the next rule's, and what needed it says that it waits.
- **A gap has one path.** It is said to the user at once, and nothing is written around it meanwhile. A defect is fixed when found. One too large to fix now, or not yet diagnosed, goes in the plan with the date it was found and the shape of its fix, never in a comment. What the language or the library lacks, and what felt against a principle, is an entry in [`docs/language_feedback.md`](docs/language_feedback.md) until the user decides it: a report change, a milestone's item, or a line in the log saying it was dropped.
- **A refusal is a decision.** One the report states was decided, and its log entry weighs it on the principles. One made for a later MVP's sake says `… is not implemented` in its error text and names no MVP, and `docs/development.md`'s table lists it with the MVP that lifts it, which a test checks. One whose only reason is how the code was built was never decided: when found, it is brought to the user and weighed.
- **Memory that no collection reclaims is a defect, fixed at its cause**, in the runtime, the toolchain, the shell and Ernest code alike. Never fix it by capping a list, a table or a cache. Add a cache only with an argument for what it holds and when it lets go. How memory is checked is [`docs/memory_checks.md`](docs/memory_checks.md)'s.
- **A published specification or a general-purpose engine is a library's work**: a pattern language, a data format, a protocol, dates and times. Where Ernest code finds itself writing one, stop. The need takes the gap's path, and whether a library is written is decided with the user first (*Design*). Splitting, trimming and sorting stay in the program.
- **Writing Ernest tests the language.** Where writing it feels against a principle, say so at once and give it its entry, before any code goes around it. A workaround, a second way, something invisible, a function the library lacks and a form the code repeats at site after site are each felt so.
- **A function over the library's types is weighed before it is written.** A private function in Ernest whose type names no type of its program's own is read against E.0's admission rules. Where a rule admits it, it is a function the library lacks, and takes the gap's path to Appendix E and the library, where the program calls it. Where none does, it stays the program's.
- **The read-back that closes an item runs two searches** over the Ernest the item wrote (*Done*), each over the sources with its count and never by the feel of one site. One looks for a form the code repeats (the log's *The Pun*). The other looks for a private function whose type names no type of its program's own (the log's *A Library's Function in a Program*).
- **Where the report is silent on what a user meets, add a sentence to the report**: one that says what the input means, or one that says it is refused, with its error. Never accept the input silently. A corner no user meets gets a test and no sentence.

## Tests

- **Every report section has a test** whose comment cites it (`%% report §5.4`). A section without one counts as not implemented, and `make sections` names it.
- **A test written after the code is a regression test.** Its comment says so and names what it does not cover. What has found defects here is the terminal harness, a read-back of the code, an independent reader, and the user, not a test that passed on its first run.
- **A flake is tested under what it was seen under**, its browser or its load. A green run under anything else says nothing of it, and a cause not found is reported as not found.
- **A flake is hunted for two hours at most**, under what it was seen under, and the hunt ends at its first sighting. One that does not show is closed as not reproducible, its log entry naming the test and what it wrote, and is opened again where it shows again. Where a probe makes the failure at will, it shows the cause and the fix, and no hunt follows. Where none can, the hunt runs to its third sighting, and the hunt after the fix runs three times the rounds one sighting took.
- **A timing test that fails under another session's load is run again, not hunted.** A timing test is one whose failing assertion compares a measured time, or a ratio of measured times. The failure's text is read first: a test whose wait ran out of its deadline is no timing test but a flake, whatever the load. When a timing test fails, the session reads the machine's load. Where another session made the load, the failure is said to the user with the load, and the test runs again on a quiet machine. Where it passes there, a log line naming the test and the load closes it, and no hunt follows. Any other test that fails under that load is a flake, and the rules above hold.
- **A long run's first step is checked alone.** A step a long run rests on, a pull or a build, is checked in a call of its own before the run starts.
- **`make test`, the light run, runs before a commit.** A commit of documents alone runs `make test-docs` in its place. `make test-full`, every area, runs before a release and before the commit that closes an item that touched the runtime, the nodes or the emitter. Any other item closes on its area's target and `make test`, the check that fits the change. While working, the area a change touches runs its own target; `docs/development.md`'s *Building* names them.
- **A new file is staged with `git add` before its check runs**, since the documents' and the style's tests read tracked files alone.
- **Readers run before a release, and when the user asks**, as [`docs/reviews/release.md`](docs/reviews/release.md) says. The full review's readers read every area whole, when [`docs/reviews/full.md`](docs/reviews/full.md) says. The findings of any review or read are sorted as `docs/reviews/full.md`'s *The findings* says, the `fix` lines made at once, and the rest decided as *Before code* says.

## Writing

- **The report and the guide are tight, in a Wirth language report's register.** State the rule; no rationale, and nothing said twice. The guide restates the report as it teaches it (*Restating*), and no more. Clear before short: plain sentences, one rule per sentence, its exception and its example in sentences of their own. Cut a sentence for restating or rationale, never for a count: a long section is kept when every sentence states a rule.
- **User-facing text has no project timeline.** The report, the guide, the tour, the manual pages and every text `ern` and the shell print name no MVP, no milestone and no date of the project's history. They say what Ernest is at the release they ship with. The one exception is a manual page's `since` line, the release a part arrived in. The history is `CHANGES.md`'s, the log's and the plan's, and a test holds the rule.
- **Every document but the report and the guide is plain and short**, the plan, the log, a proposal, a commit message, a message to the user and this file among them. One point to a sentence, in the order a reader needs it, without chains of clauses.
- **A paragraph is one turn of the text**, in every document, in a comment of the code and in a message to the user. It says one thing, with that thing's exception and example, and a new paragraph begins where the text turns. A break is made where it helps the reader take the next thing in, and nowhere else: never at a count of words, never to shorten, and never later than the turn.

  A paragraph past about a hundred words, a list item among them, is read again for a turn it may hide, and left whole where it holds one thing; `make paragraphs` lists them. Past 150 words a paragraph always hides a turn, since no reader takes it in whole. A test refuses it in every tracked document the listing reads, and the writer finds the turn and splits there before the commit.
- **A proposal and its reasons say what Ernest does, and why.** What was tried, and the designs set aside, stay in the experiment, and go to the log once the user has opened the log for the work. None of it goes into the paragraph that states the rule.
- **An edit to a set that documents name changes every place that holds it.** Such a set stands in more than one place: a list, a count, a section that restates it. An edit to the set reads the whole page first and changes every such place, the README's and the plan's among them, in the same commit.
- **A shell session shown in the tour or the guide is cut where the lesson turns**, a sentence between the parts saying what the next lines show. A chapter's program stays one block, which a test holds equal to its file.
- **Each report file's third line names the release it describes**, `For Ernest x.y.z.`, and changes only with `VERSION`, by `make version`.
- **The report's section numbers never change**, since the documents, the tests and the code cite them. Never renumber, remove or insert a section between two others. A new rule goes into the section it belongs to; where none can hold it, a new section goes at the end of its chapter or appendix. A section that goes keeps its heading, titled `Unused`, and nothing else. The guide's numbers change only where a section cannot be placed otherwise.
- **Compiler behavior goes to §11.**
- **The spelling is American English**, in every document, name and message; `guide/style.md` states the rule and `docs/code_style.md`'s *Every language* the test's scope.
- **No document or message names who proposed an idea**, or that person's role; it states the argument. [`ACKNOWLEDGMENTS.md`](ACKNOWLEDGMENTS.md) and the report's dedication with its epigraph name people and argue nothing.

## Done

In this file "the report" alone is the language's. The session's is "the report to the user", and an agent's is "its report".

- **Read the result back before reporting it.** The session reads each diff as its agent returns it (*The repository*). At an item's close it reads what the item made as a reader who knows the rest of Ernest would, against the principles and E.0, which bind the standard library and the toolchain too. It runs the two searches over the Ernest the item wrote (*Defects and gaps*), and says what surprised.

  Decide every surprise: act on it in the same item or leave it with its reason, and record it where its owner keeps it. One that needs the user goes to the user with a recommendation in the same report to the user.
- **Hard work is done, and stupid work is not.** Nothing is left, or recommended left, for its size or its difficulty: where it is right it is done in the item, or planned. Work is left only where it would hold nothing, decide nothing and remove nothing, and the reason given is that one, never the cost.
- **A report to the user names each thing that remains**, specific enough to act on or to drop, and says nothing where there is none.
- **A step forward sweeps what it leaves behind.** What a step makes redundant goes in the step's own commit, never left for a review to find: a sentence, a file or a directory, a decided finding, a citation of what went. Every sentence elsewhere that says the item still waits goes too, in `docs/development.md`'s table, the plan's tables or an example's header. A done item's paragraph goes, one line naming its log entry in its place until the milestone's row takes it.

  Where the item was its milestone's last, the same commit sweeps the plan. The milestone's section goes, its row names its proposal and the log entries that argue it, and every sentence of a later milestone that cited the section's items cites the log instead.
- **Commit only after the checks pass**, on make's own exit status read in a call of its own, never chained after them and never on a pipe's, which a `grep` of the output would give. A deletion of tracked files is staged with `git rm` before its check runs, and committed with the item. Push only when the user says so, a proposal's pause excepted (*Before code*).
- **Every message that reports an item that touched the report, the plan or an error's text ends with a "Report conformance" section**: the sections applied; every place the report was silent and what was done, or "none"; every deliberate omission, with the MVP that lifts it and the error the code gives meanwhile. "Tests green" does not replace it. A message that reports any other item says in one line that the report was not touched.
- **Stop after each plan item**, but within a run of items, the next rule's. Finish it whole, report it, and wait: the user sees each item's design choices before the next builds on them. The next step the report to the user names is the plan's next item, in the order the plan gives.
- **A run of items.** Where the plan's next items stand alone, the session takes them one after another, an agent for each, and closes and commits each before the next starts. It stops at the first thing that needs the user, however small: a decision, a surprise, one the session decides itself among them, a departure from the brief, a check that fails. The session judges that from each diff and its check, never from an agent's report alone. Where nothing stops it, it stops after three items. The report to the user covers each item of the run.

**Closing an item.** Each line names a rule of this file.

1. The report first, and the soundness paragraph of a changed rule (*Before code*).
2. Every question decided, every defect not fixed in the plan, and every gap in `docs/language_feedback.md` (*Before code*, *Defects and gaps*).
3. A refusal for a later MVP in `docs/development.md`'s table (*Defects and gaps*).
4. Every section built cited by a test, and a test written after the code called a regression test (*Tests*).
5. A new name in the glossary, and a new term in Appendix F (*Style*).
6. The result read back, with its two searches, and every surprise decided (*Done*, *Defects and gaps*).
7. The check that fits the item green (*Tests*).
8. One commit by its paths, sweeping what the item made redundant, and the plan where the item was its milestone's last (*The repository*, *Done*).
9. The report to the user, at the run's end where the item is one of a run, ending with *Report conformance* where it is due, then a stop until the user's word; a push only on that word (*Done*).

## Style

The two style documents, [`guide/style.md`](guide/style.md) for a program's Ernest and [`docs/code_style.md`](docs/code_style.md) for the repository's own code, are read before their language is written: the first before any Ernest, and the second before Erlang, C or the repository's own Ernest, by a session and by an agent, whose brief says so. Neither is loaded with this file.

**The glossary is living.** A name that comes to recur across modules, or a concept the code names in two places, goes into a glossary in the commit that writes it, in the report's word where the report names the concept. A name every program shares goes to `guide/style.md`'s glossary, and a name of the repository's own, the toolchain's or the shell's, to `docs/code_style.md`'s.

Appendix F is living the same way: a report edit that introduces a term adds its line in that edit. Use a name the glossary holds as it stands. Where the code and the glossary differ, correct the wrong one in the same commit; a new word that departs from the report's goes to the user first.
