# Coherence

Whether the project agrees with itself: the report with its principles and with itself, the teaching documents and every other document with the report and the code, and the code with the report, with the principles and with its own standards. This document owns what is checked, by a command or by a reader, and when. A plan item ends by running the rows for what it touched, and a release runs every row.

## When

| A change to | Runs |
|---|---|
| any plan item | C1, and the tests of C2 and C3, which `make test` runs |
| a report section | C4 to C8 for that section; C9 when the guide teaches it; C11 for every document that cites or describes it; C17 and C18 once built |
| the guide or `shell/README.md` | C9 for the guide's changed sections, C11 for `shell/README.md`'s; C10 with one newcomer for a section that is new or rewritten |
| any other document | C11 for it |
| the Erlang | C13 for its application; C11 for every document that describes it; C19 when it changes what a user of `ern` or the shell meets; C21 when it changes a diagnostic |
| the Ernest | C14 for its area; C15 for a module page it changed; C11 for every document that describes it; C19 for the shell |
| the Emacs mode | C16 |
| a document's section numbers | C12 |
| a vendored file or a table built from another's data | C20 |
| a batch of report changes | C9 and C11, whole |
| a release | every row, whole: the readers of C4 to C8 over the whole report, and C10 with four newcomers, each writing one of its four programs |

## The checks

A command's row passes when the command does what its row says. A reader's row passes when the reader has handed in and every finding is decided; what the reader looks for is its brief, below.

| | What agrees | Checked by | Passes when |
|---|---|---|---|
| C1 | every report section and its tests | `make sections` and `make coverage` (CLAUDE.md, *Tests*); a reader of the tests of each section read | `make sections` lists only the sections the plan's *Standing gaps* names, and each section read has a test of its rule and of each of its refusals |
| C2 | the documents' citations, paths and contents lists and what they name | `make xref`, `make test-docs` | green |
| C3 | every list that lives in the code and in a document | the mirror tests; a reader who lists the lists | green, and every list has a test holding the two equal |
| C4 | the report and its principles | the principles reader | the reader's findings decided |
| C5 | each rule and its place in the language | the sceptical reader | the reader's findings decided |
| C6 | the report and itself | the adversary | the reader's findings decided |
| C7 | the report and those who build and program from it | the implementer and the programmer, reading cold | the readers' findings decided |
| C8 | the report and its register | the register reader | the reader's findings decided |
| C9 | the guide and the report | `make test-guide`; the guide's sweep reader | green, and the reader's findings decided |
| C10 | a teaching document and a newcomer | the newcomer | the reader's findings decided |
| C11 | every other document and the report and the code | the documents' sweep reader | the reader's findings decided |
| C12 | citations of renumbered sections and their meaning | a reader of every citation of the old numbers | each still names what its sentence means |
| C13 | the Erlang and the report and `docs/style.md` | the tests CLAUDE.md's *Tests* names for its application; Dialyzer and Erlang's xref, once MVP 2.95 builds their targets; the Erlang reader | green, Dialyzer and xref clean, and the reader's findings decided |
| C14 | the Ernest and the report, Appendix E.0 and the principles | the tests CLAUDE.md's *Tests* names for its area; the Ernest reader | green, and the reader's findings decided |
| C15 | the module pages and E.0 shape rule 6 | the documentation tests; a reader of `ern doc`'s pages | green, and every exported name documented, its errors stated, its examples run |
| C16 | the Emacs mode and the Ernest in the repository | `make test-emacs`; before a release, a session editing a module of the standard library | green, and what the session found wrong in indentation and faces decided |
| C17 | the report's own examples and the compiler | a test MVP 2.95 builds | every example compiles, and every one whose value is written runs to it |
| C18 | Appendix A and the parser | a program MVP 2.95 builds | every non-terminal defined and used, the FIRST sets of every alternative disjoint or the lookahead named in the prose, a thousand programs generated from the grammar, reaching every alternative, parsed, and each near miss refused with a diagnostic |
| C19 | the toolchain and the shell as a user meets them, and the principles | the tool reader | the reader's findings decided |
| C20 | borrowed code and `THIRD_PARTY_LICENSES` | the style tests' check of vendored files; a reader of every file and table taken from another | green, and each listed with its licence, its upstream header kept |
| C21 | the checker's messages and §11.5 | a catalogue of one small program for every error the checker gives, which MVP 2.95 builds; the diagnostics reader | the reader's findings decided |

## Readers

- **A reader who took no part reads**, since an independent reader is among what has found what no test did (CLAUDE.md, *Tests*).
- **One lens a reader.** A reader is given one row's brief and the files that answer it, and nothing that argues for the text; a cold reader is never given the log.
- **A reader hands in** a numbered list, most serious first, each finding with where, a short quote, what is wrong, and a one-line fix, defects apart from matters of clarity. It reads only the files named, and edits nothing in the repository.
- **Every finding is decided.** A defect is fixed with a regression test, or planned in a named milestone with its shape. A finding that questions a rule of the language, rather than showing a defect, becomes an entry in [`language_feedback.md`](language_feedback.md), decided with the user before anything changes. What is weighed and kept has a line in the log. The report changes first (CLAUDE.md, *Before code*).
- **A finding that changes the report runs again the rows that read what it changed.**
- **Measured, not felt.** A reader's row that finds nothing at two releases running becomes a test, or is dropped, and this document says which.

## Briefs

Each brief names what the reader reads: `<sections>` is the sections a plan item changed, and the whole report before a release.

- **C4, the principles reader.** "Read §0 of `ernest_report.md`, then `<sections>` against its five principles alone: every second way to do one job (principle 2), anything a program does that its text does not show (3), grammar that needs lookahead or backtracking (4), and every concept, primitive and reserved word, counted against the count the last release recorded (5). For each finding, write the smallest program that shows it and say what a reader who knows the rest of Ernest would have predicted (1)."
- **C5, the sceptical reader.** "Read `<sections>` of `ernest_report.md`. For each rule, say what it buys a program and what the language would lose without it. Report every rule whose answer is little, and every rule that exists only for another."
- **C6, C7, the cold readers.** "You know Erlang, Haskell or ML, Rust and Go, but not Ernest. Read `ernest_report.md`'s `<sections>`, and nothing else." The adversary reports two sections that disagree, prose against Appendix A, a signature against its prose, and a rule another makes unreachable. The implementer reports every place one who builds a conforming toolchain must guess, and every case the rules leave silent. The programmer reports every example that would not compile under the rules as written, every name used before it is defined, and every reference that points at the wrong section.
- **C8, the register reader.** "Read `<sections>` of `ernest_report.md` for sentences that argue rather than state, and every section over 600 words for restating, against CLAUDE.md's *Writing*."
- **C9, C11, the sweep readers.** "Read `<document>` against `ernest_report.md` and the code it describes; report every statement that is false or stale, every fact restated outside its owner or owned by no document, checking CLAUDE.md's *Who owns each fact*, and, in the guide, every job it teaches two ways."
- **C10, the newcomer.** "You know another language and not Ernest. Read `<document>` alone, doing its exercises with `bin/ern` as it says, then write `<program>` with only what it taught you: a chat server, a tool over files, a game at a terminal, or a pipeline over standard input. Report every place you were lost, every message you did not understand, and everything you wanted and could not find." A program that shows what no example does joins `examples/`.
- **C13, the Erlang reader.** "Read `erl/<app>/src` against `docs/style.md` and the report sections its comments cite. Report defects, dead code, missing specs, comments that no longer hold, and code that could be shorter and clearer."
- **C14, the Ernest reader.** "Read `<area>` against the report sections it implements, Appendix E.0, and the principles, as CLAUDE.md's *Reading back* reads the result of a change. Report defects, code that could be shorter and clearer, and what feels against a principle."
- **C19, the tool reader.** "Use `bin/ern`'s jobs and options, its messages, and the shell's commands, as a programmer who has read the guide. Report every job done two ways (principle 2), everything the toolchain does that its user does not see (3), and every behaviour a user who knows the rest would not predict (1)."
- **C21, the diagnostics reader.** "You have not read the checker's code. For each program of the catalogue, read the message it gives against §11.5, and say whether, having made that mistake, you would know the fix."
