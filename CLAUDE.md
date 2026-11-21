# Ernest — Claude Instructions

Ernest is a functional language for concurrent programs, designed by the user (joagre). It has two concepts: functions with Hindley-Milner types, and processes with typed mailboxes. The report under [`report/`](report/) is the language.

This file holds what judgment cannot supply: what is the user's, who decides, and what the user wants of the work. Everything else is left to judgment. A document that a job needs is read when the job starts (*Read when the job starts*).

A mistake adds no rule to this file. It gets an honest account when it happens, and a sentence here only where the user sees it come back.

## Authority

- **The report is the only normative document**, in three files: `language.md`, `toolchain.md` and `library.md`. Nothing else in the repository overrides it.
- **Appendix A, the grammar, wins** over the prose where they conflict.
- **Section 0, the five principles, is the measure** in every design discussion, and decides where the grammar is ambiguous. A recommendation names the principle that decided. The principles guide and are not law: each is weighed with judgment.

## Where a fact lives

Each fact has one owner, and every other document points at it.

- **The report**: the language, the library and the toolchain.
- **[`docs/log/`](docs/log/README.md)**: why the report and the plan say what they say. Never normative.
- **[`docs/plan.md`](docs/plan.md)**: what is built next, and where we are.
- **The code and its tests**: what is built.
- **`docs/design/`**: each component's design as it stands.
- **[`docs/known_issues.md`](docs/known_issues.md)**: what is known to be wrong or missing and not planned, a line each.
- **[`docs/proposals/`](docs/proposals/)**: what is designed and not decided. Nothing in it is authoritative.

## What is the user's

- Work in the main checkout, on `main`, with no worktree and no branch.
- All development runs on the main machine. Another machine only tests nodes across a network.
- An untracked file the session did not write is the user's. Do not edit it, commit it or build on it.
- A commit names its paths, `git commit -F message -- path...`, and leaves the index as the user left it. Its message says what changed and points to the log for why. It carries no attribution line.
- Push only when the user says so.
- Another repository is written only as [`docs/clean_room.md`](docs/clean_room.md) says.

## Who decides

- **The report changes first**, then the log, then the code.
- **A changed rule of §3 to §9 rewrites its paragraph of [`docs/soundness.md`](docs/soundness.md)** in the same commit.
- **A change to the grammar or to a rule of §3 to §9, or a form that would replace a mechanism, gets one cold reading** of its sentences before the code starts.
- **Where the report is silent on what a user meets, it gains a sentence.** Input is never accepted silently.
- **The user decides the language.** A change to the report, the library, an error's text or the plan that someone could argue with goes to the user first, with a recommendation and its reason. One that nobody would argue with is made and reported.
- **One question at a time**, the argument before the verdict.
- **Where a step looks wrong, say so once, plainly.** The user's own idea is a step too. If the user insists, build it whole.
- **A design stays in its proposal** until the user says it is ready. It is called ready only after it is read against each owner it touches.
- **A session opened to discuss writes nothing** until the user asks.
- **Stop after each item and wait**, unless the user has said to go on.

## The work

- **The session designs, reads and decides, and agents write the code.** A question about what the host or the code does is the session's own: it reads, and runs what the reading leaves open. [`docs/agents.md`](docs/agents.md) says how an agent is briefed, and is read before the first agent starts.
- **What must run before an Ernest program can is Erlang.** Any other work that could be either is Ernest.
- **Nothing routes around a defect or a gap.** A defect that a first user meets is fixed when found, or is an item of the plan. A gap in the language or the library is said to the user at once, and nothing is written around it meanwhile.
- **Before the launch stands what a first user meets.** It is asked of each item when it is written and before it starts. A corner that must be built on purpose to be met gets its line in [`docs/known_issues.md`](docs/known_issues.md), and becomes an item when the user takes it up.
- **Nothing is left for its size or its difficulty.** What is left is what no first user meets, and it has its line in the known issues.
- **Writing Ernest tests the language.** A workaround, a second way, a helper that belongs in the library or a form repeated at site after site is said at once, and gets its entry in [`docs/language_feedback.md`](docs/language_feedback.md).
- **The log is searched before a finding is argued**, for the decision the finding may sharpen or reverse.
- **Work in proportion.** Read the code before running anything. What the reading shows to be deterministic is verified once, and only what is intermittent is run again. The checks an item gets are sized to what it changes.
- **A published specification or a general-purpose engine is a library's work.** A program that finds itself writing one stops, and the user decides whether a library is written.
- **`make test` runs before a commit**, `make test-docs` for documents alone, and `make test-full` before the commit that closes an item that changed code. Commit only after the check passes, on make's own exit status.
- **Every report section has a test** whose comment cites it.
- **The plan holds no stale sentence and no open question.** A step sweeps what it makes redundant in its own commit, and a question that waits for the user is a named decision in a milestone.
- **The report's section numbers never change.**

## What the user wants of Ernest

These are taste, and the log argues each.

- Sound first, then the simplest thing that holds it.
- Minimal and direct, with no speculative abstraction.
- Ernest follows the host's semantics. What it promises beyond them needs a reason.
- The tools are fast, and a slow tool is a defect.
- Lean: a run holds only what its work needs.
- What Ernest adds to a host operation costs a fraction of it.
- No code is kept only to make it go faster.
- No fixed sleep and no busy loop: a process waits on what it means.
- A hole in a guarantee is answered first by a narrower promise, and by a mechanism only where the narrow one is not worth making.
- Ernest asks a machine for a new OTP, and nothing else new.

## Honest reports

- **Read the result back before reporting it.** An agent's report is a claim: read its diff and run its check.
- **Say what was done, what was not, and what remains**, each specific enough to act on or to drop. A failure is reported with its output.
- **A report on an item that touched the report** names the sections applied and each place where the report was silent.

## Writing

- **The report and the guide are tight**: the rule, no rationale, nothing said twice, one rule to a sentence.
- **Every other document is plain and short**, a message to the user among them.
- **American English.** No document names who proposed an idea.

## Read when the job starts

| The job | Read first |
|---|---|
| Starting an agent | [`docs/agents.md`](docs/agents.md) |
| Writing Ernest | [`guide/style.md`](guide/style.md) |
| Writing Erlang, C or the repository's own Ernest | [`docs/code_style.md`](docs/code_style.md) |
| Writing in another repository | [`docs/clean_room.md`](docs/clean_room.md) |
| A review or a release | [`docs/reviews/`](docs/reviews/) |
| Building, testing, a flake | [`docs/development.md`](docs/development.md) |
| A check of memory | [`docs/memory_checks.md`](docs/memory_checks.md) |
| Any other document | [`docs/README.md`](docs/README.md), which says what each one is |
