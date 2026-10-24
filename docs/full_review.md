# The full review

Fifteen readers, each over the whole of its area. Between them they read the report, the guide, every other document, and all the code: the Erlang and the Ernest, the helper in C, the Emacs mode, the Makefiles and the launcher. It is expensive and runs seldom. What every release runs is [`release_review.md`](release_review.md)'s.

## When it runs

- Only when the user says so. It is expensive, and no milestone, plan item or release starts one of itself.

It does not run while the findings of the last one are open.

## How it runs

- Each reader is a session of its own. It is given its brief and the files it reads, and nothing that argues for them, such as the log or another reader's list.
- A reader edits nothing in the repository. It tries a program in a scratch directory of its own, with `bin/ern`.
- The readers read one commit, which the findings name, and run side by side.
- An area too large for one reader is read in parts, each by a reader of its own with the same brief.
- An area a release review's reader read whole since the last full review is read again only where it changed since: the release review's findings name the commit it read, and `git diff` from it says what changed.
- Every reader names, in its area, each thing that exists for a reason an earlier milestone had and a later rule removed: a copy, a helper, a table, a check or a rule kept because nothing broke. The pattern is a decision made when the toolchain was small and followed by every later rule in the same shape; the log says what each was for, and the reader asks whether anything still needs it.
- Each reader hands in a numbered list, most serious first. A finding gives its place, a file and line or a section; a short quote; what is wrong; a program or a command that shows it, where there is one; and a one-line fix. Defects stand apart from matters of clarity. Where a reader writes Ernest, the places the language made the work harder stand apart from both.
- A reader hands its list back as text, which the review's own session saves, since the harness refuses a report file written by a subagent.

## The readers

A reader's letter names its findings: C12 is the code reader's twelfth. The lists of a reader's parts are numbered through, as one list.

- **P, the principles.** Reads the report, the three files of `report/`.

  "Read §0, then the whole report against its five principles alone: every second way to do one job (principle 2); anything a program does that its text does not show (3); grammar that needs backtracking, or lookahead that is unbounded or that the prose does not name (4); and every concept, primitive and reserved word, counted against the last counts the log records (5). For each finding, write the smallest program that shows it, and say what a reader who knows the rest of Ernest would have predicted (1). Then, for each rule, say what it buys a program and what the language would lose without it, and report every rule whose answer is little and every rule that exists only for another."

  It gives the counts, each with how it counted; the log's entry for the last review that counted, a full review's or a release review's, holds the counts before them.
- **K, the cold reader.** Reads the report, the three files of `report/`, and then [`soundness.md`](soundness.md), the one document that argues from the report, and nothing else.

  "You know Erlang, Haskell or ML, Rust and Go, but not Ernest. Report two sections that disagree, prose against Appendix A, a signature against its prose, and a rule another makes unreachable; every place one who builds a conforming toolchain must guess, and every case the rules leave silent; and every example that would not compile under the rules as written, every name used before it is defined, and every reference that points at the wrong section. Then read the argument against the rules it cites, and report every step that does not follow from them, each with the program that shows it where there is one."
- **G, the register.** Reads the report, the three files of `report/`, and CLAUDE.md's *Writing*. "Read every section of the report over 600 words for sentences that argue rather than state, and for restating, against CLAUDE.md's *Writing*." It lists the sections it read, each with its count of words.
- **U, the guide.** Reads `guide/` whole, the language guide, *Why Ernest*, the questions and the deployment guide, with the report and `src/stdlib/`, and runs `bin/ern`. "Read each guide against the report and the code it describes. Report every statement that is false or stale, every fact restated outside its owner or owned by no document (CLAUDE.md's *Who owns each fact*), and every job it teaches two ways."
- **N, the newcomer.** Reads `README.md`, then `guide/language.md` alone, then `guide/why.md` and `guide/faq.md`, and uses `bin/ern`.

  "You know another language and not Ernest. Read the README, then the guide alone, doing its exercises as it says, then the argument and the questions, then write a program with only what it taught you. Report what on the README put you off or told you too little to go on, every place you were lost, every message you did not understand, everything you wanted and could not find, every word of Ernest's or piece of code relied on before the text said what it is, every count given without what it counts, and every claim that opens on what another system lacks before saying what Ernest does; and, apart, every place the language itself, not the guide, made your program harder to write than you expected; and, apart again, every name of the prelude and of the standard library you met whose word you could not have predicted from the thing it names, with the word you expected."

  The program is one no earlier newcomer wrote; the log's entry for each full review and the notes of each release name them. The newcomer hands in the program's source and whether it ran.
- **L, the Erlang programmer.** Reads `README.md`, `guide/why.md`, the tour and `guide/faq.md`, in that order, then the guide's chapters that changed since the last review, or the language guide and the deployment guide whole at the readers' first run, and uses `bin/ern`.

  "You have written Erlang/OTP for years: gen_server, supervisors, hot code loading, distribution with cookies, epmd, global and pg. You have seen typed Erlangs fail and you are in a hurry. Read each document as that person. Report where you would close the page and why; the first question you asked that the document does not answer; every place it shows you something Erlang cannot do and every place it only restates what you have; every sentence you suspect of a trick, a demo arranged to work; and, in the guide, every sentence you tripped on or did not believe. End with what convinced you, if anything, and whether you would try Ernest." It argues the documents' claims nowhere and proposes no change to the language.
- **M, the Gleam programmer.** Reads what L reads, in L's order, and uses `bin/ern`.

  "You write Gleam: typed processes through `Subject`, no type classes, no distribution and no reload, and you chose that. Read each document as that person. Report, chapter by chapter, what it shows you that Gleam lacks and where it only asserts it; whether the mailbox in the function's type buys anything over a `Subject` that you can see on the page; whether a requirement is convincing as not a type class; where it is too long for what it shows; and, in the guide, every sentence you tripped on or did not believe. End with what convinced you, if anything, and whether you would try Ernest." The same two closing rules as L's.
- **D, the documents.** Reads every tracked Markdown file but the report's three files, the guide, the log and `docs/man/`'s generated pages: `README.md`, `CLAUDE.md`, `ACKNOWLEDGMENTS.md`, `report/README.md`, `tour/README.md`, `examples/README.md`, `src/shell/README.md`, `editors/emacs/README.md`, `tools/release/README.md`, `docs/man/README.md`, `assets/README.md` and `docs/`. "Read each document against the report and the code it describes. Report every statement that is false or stale, and every fact restated outside its owner or owned by no document (CLAUDE.md's *Who owns each fact*). List every list that lives in two places, with the test that holds it equal, or none."
- **C, the toolchain's code.** Reads `erl/`, the Erlang and the scripts of `test/`, `test/ern_pty.py` among them, the scripts under `tools/`, the Makefiles, `bin/ern` and `editors/emacs/`, in six parts of about the same size: the front end (the lexer, the parser, the formatter and the utilities) with the Emacs mode, whose indentation follows the formatter's; the checker; the emitter; the runtime with its helper in C; the shell's Erlang, `ern_shell` with its tests and the terminal's; and the rest of the command line with `test/`, the Makefiles and `bin/ern`.

  "Read the part whole, the sources and their tests, against `docs/style.md` and the report sections its comments cite. Report defects, missing specs, comments that no longer hold, code that could be shorter and clearer, and every name that does not say what its value or its work is, or that names one thing two ways."
- **E, the Ernest code.** Reads `src/stdlib/`, `src/shell/`, `src/libs/`, `examples/` and `tools/` in three parts, `src/stdlib/`, `src/shell/` and the rest, with the page `ern doc` writes of each module.

  "Read the part whole against the report sections it implements, Appendix E.0, the principles and `docs/style.md`, and read each module's page as a programmer would. Report defects, code that could be shorter and clearer, every name that does not say what its value or its work is, what a reader who knows the rest of Ernest would not predict, every `foreign fn` whose work Ernest could do given the layers beneath it (Appendix E.0 rule 1), and what a page leaves a programmer unable to use; and, apart, every place the language made the code harder than it should be: a workaround that should not be needed, a second way, something invisible, a function the standard library lacks."
- **T, the tools.** Has read the guide, and uses `bin/ern`'s jobs, options and messages and the shell's commands, with `ern(1)` and the report's §0. "Report every job done two ways (principle 2), everything the toolchain does that its user does not see (3), and every behavior a user who knows the rest would not predict (1)." A finding gives the command, what it did and what was expected.
- **X, the diagnostics.** Reads `docs/diagnostics.md` and the report, and not the toolchain's code. "For each program of the catalog, read the message it gives against §11.5, and say whether, having made that mistake, you would know the fix." It says how many entries it judged clear.
- **S, security.** Reads the runtime, its helper, `ern config`, the shell and the standard library, against the report's §8.4, §11.2, §11.3, E.17, E.18 and E.23. "Read the foreign boundary's checks, the configuration directory and its key, a path from the network, a socket's input, a program's arguments and environment, the host programs `Os` starts and what they write back, and the shell's history file. Report each place where untrusted input reaches something it should not, with an input that shows it." Real exposures stand apart from hardening.
- **H, the shell's guide.** Knows Ernest and not the shell's code. Reads `src/shell/README.md` alone, then `src/shell/`. "Find in the shell's code what the README says is there. Report every place you were lost or it led you wrong."
- **B, the broken program.** Has read the guide, and uses `bin/ern`. "Write a small program against each area, a process and a call, a file, a socket, a test, a peer, and break each on purpose: a fault deep in a chain of calls, in a lambda, a division by zero, a deadlock, a foreign raise, one carried from a peer. Run each under `ern run`, under `ern test` and in the shell, and judge the output by one question: could a developer who did not write the program pinpoint the fault from it alone?" A finding gives the program, the output and what could not be found.

## The models

Two models serve a review: the most advanced there is, and the one below it, which costs less and, on a brief that holds text or code to a rule already stated, finds as much. The most advanced runs where the work is judgment over the language, where a reader asks whether a rule should be and what it buys. So P runs on the most advanced, and every other reader on the one below: K's cold reading, two sections that disagree, prose against the grammar and a step that does not follow, holds text to text that is there, and L and M, whose briefs are concrete, where a reader would close the page and what convinced them, find on the one below what the walk of 2026-10-24 found there (decided with the user on 2026-10-24). Every other reader and part runs on the one below: each holds what it reads to a rule, the report's, `docs/style.md`'s or a brief's, and the newcomer is no more a newcomer for being the strongest. Working the findings follows the same line: a design question, a sentence of the report or of §0, and a reading of an argument take the most advanced; a defect whose fix the finding names takes the one below.

## The findings

- The lists become one document, `findings.md` beside this one: a line per finding, by area, each naming its reader's letter and number.
- A line carries its decision: `fix`, `decide`, a milestone's number, planned there, or `dropped`, with the reason; and `done`, with the date, once made.
- Each reader's whole list is kept below the lines, since a line is too short to fix from.
- The lines are sorted before anything is built, and the sorting is read first. A line nobody would argue about once the finding is read is `fix`, made at once, the line saying what was done: a sentence, a soundness paragraph or prose in the review's own session, on the most advanced model; code or a test as one batch on the one below it, built from a brief that names each line and the shape of its fix (*The models*).

  Every other line is `decide`: a rule, a sentence of §0 or E.0, what an error text means, a fix that could go two ways, a departure from a proposal. Each is discussed with the user one at a time, the argument before the verdict, with a recommendation that weighs the candidate rule against §0's five principles and names the one that decided (CLAUDE.md, *Authority*).

  A milestone's read (the log's *MVP 3.0 Read Without a Release*) sorts its lines the same way.
- The plan gives the list a milestone.
- The document goes when every line is done or dropped, or stands in the plan as an item of its own.
- The log gains an entry for the review: its date and commit, the principles reader's counts, the newcomer's program, and how many findings took each decision.

## Its cost

Twenty-two sessions, counting the parts of C and E, for most of a day; then the milestone the plan gives the findings.
