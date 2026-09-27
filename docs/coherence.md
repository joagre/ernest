# Coherence

Whether the project agrees with itself: the report with its principles and with itself, the teaching documents and every other document with the report and the code, and the code with the report, with the principles and with its own standards. This document owns what a change runs, by a command or by a reader, and when each check passes. [`review.md`](review.md) begins by running every row.

## What a change runs

The documents that cite or describe a change are found by searching the repository for the section numbers, names and paths it changed. A batch of report changes is a plan item that changes more than one report section.

| A change to | The commands | The rows |
|---|---|---|
| anything | `make test`, once per plan item, before the commit that closes it | C1 for the report sections the item changed; C2 and C3, whose tests `make test` runs |
| a report section | `make test-docs` | C4 to C8 for the section; C9 when the guide teaches it; C11 for every document that cites or describes it; C17 and C18 once built |
| §0 or Appendix E.0 | `make test-docs` | C4 over the whole report, and C14 over the code E.0 governs |
| §11.5 | `make test-docs` | C21 once built |
| the guide | `make test-guide`, `make test-docs` | C9 for the sections changed; C10 with one newcomer for a section added |
| `shell/README.md` | `make test-docs` | C11 for it; C10 with one shell reader for a section added |
| another document | `make test-docs`, or `make xref` for citations and paths alone | C11 for it |
| a rule document: CLAUDE.md, `docs/style.md`, this document, `review.md` | `make test-docs`, and `make test` for `docs/style.md` | C11 for every document that applies it, and for `docs/style.md` C13 and C14 over the code it governs |
| the Erlang of an application under `erl/`, its tests included | `make test-erl APP=<app>` and `make test-programs`; `make test` for the checker, the emitter or the runtime | C13 for the application; C11 for every document that describes it; C19 for a change a user of `ern` or the shell meets; C21 for a change to a diagnostic, once built; C15 for a change to `ern_page`, which renders a module's page |
| the helper in C, `erl/runtime/c_src/` | `make`, then `make test-erl APP=runtime` and `make test-programs` | C13 over the helper |
| `stdlib/` | `make test-erl APP=runtime`, `make test-programs` | C14 for the module; C15 for its page; C11 for every document that describes it |
| `shell/` | `make test-shell` | C14 for the shell; C19; C11 for `shell/README.md` and `docs/shell_design.md` |
| `libs/` | `make test-erl APP=runtime`, which reads their pages | C14 for the library; C15 for its page |
| `examples/` | `make test-programs` | C14 for the example; C11 for every document that cites it |
| `bin/ern`, the Makefiles, `tools/` | `make test` | C11 for the README, CLAUDE.md's *Tests* and `docs/architecture.md`; C19 for `bin/ern` |
| the Emacs mode | `make test-emacs` | C16 |
| a vendored file or a table built from another's data | `make test` | C20 |
| the section numbers of a document other than the report, whose never change | `make xref` | C12 |
| a batch of report changes | | C9 and C11 over every document |
| a release | every command above | every row over the whole: C4 to C8 over the whole report, C10 with four newcomers, one for each of its programs, and one shell reader |

## The checks

| | What agrees | Checked by | Passes when |
|---|---|---|---|
| C1 | the report's sections and their tests | `make sections` (the README, *Building*); a reader of the tests of each section the item changed, and of every section before a release | `make sections` lists only the sections the plan's *Standing gaps* names, and each section read has a test of each rule it states and each refusal |
| C2 | the documents' citations and paths, and the report's and the guide's contents lists | `make xref`, `make test-docs` | green: every citation names a heading, every path named exists, and each contents list equals its headings |
| C3 | every list that lives in the code and in a document | the mirror tests; a reader who lists the lists | green, and every list has a test holding the two equal |
| C4 | the report and its principles | the principles reader | its findings decided |
| C5 | each rule and its place in the language | the sceptical reader | its findings decided |
| C6 | the report and itself | the adversary, reading cold | its findings decided |
| C7 | the report and those who build and program from it | the implementer and the programmer, reading cold | their findings decided |
| C8 | the report and its register | the register reader | its findings decided |
| C9 | the guide and the report | `make test-guide`; the guide's sweep reader | green, and its findings decided |
| C10 | a teaching document and a newcomer | the newcomer, or for `shell/README.md` the shell reader | its findings decided |
| C11 | every other document and the report and the code | the documents' sweep reader | its findings decided |
| C12 | citations of renumbered sections and their meaning | a reader of every citation of the old numbers | each still names what its sentence means |
| C13 | the Erlang and the C, and the report and `docs/style.md` | Dialyzer and Erlang's xref, `make dialyzer` and the target MVP 2.95 names, once built; the code reader | Dialyzer and the xref target clean, and its findings decided |
| C14 | the Ernest and the report, Appendix E.0 and the principles | the Ernest reader | its findings decided |
| C15 | the module pages and E.0 shape rule 6 | the documentation tests; a reader of `ern doc`'s pages | green, and every exported name documented, its errors stated, its examples run |
| C16 | the Emacs mode and the Ernest in the repository | `make test-emacs`; before a release, a session editing a copy of a module of the standard library, outside the repository | green, and what the session found wrong in indentation and faces decided |
| C17 | the report's own examples and the compiler | a test MVP 2.95 builds, once the report marks its blocks as the guide does | every block marked an example compiles, every one whose value is written runs to it, and every one marked rejected is refused with the error it names |
| C18 | Appendix A and the parser | a program MVP 2.95 builds | every non-terminal defined and used, the FIRST sets of every alternative disjoint or the lookahead named in the prose, a thousand programs generated from the grammar, reaching every alternative, parsed, and each near miss refused with a diagnostic |
| C19 | the toolchain and the shell as a user meets them, and the principles | the tool reader | its findings decided |
| C20 | borrowed code and `THIRD_PARTY_LICENSES` | a reader of every file and table taken from another | each listed with its licence, its upstream header kept |
| C21 | the lexer's, the parser's and the checker's messages, and §11.5 | a catalogue of one small program for every error they give, which MVP 2.95 builds; the diagnostics reader | every error has its program, and the reader's findings decided |

## Readers

- **A reader who took no part reads**, since an independent reader is among what has found what no test did (CLAUDE.md, *Tests*).
- **One lens a reader.** A reader is given one row's brief and the files that answer it, and nothing that argues for the text; a cold reader is never given the log.
- **A reader hands in** a numbered list, most serious first, each finding with where, a short quote, what is wrong, and a one-line fix, defects apart from matters of clarity. It reads only the files named, and edits nothing in the repository.
- **A finding is decided** when it is fixed, with a regression test where the defect is in code; planned, as CLAUDE.md's *Defects and gaps* plans a gap; entered in [`language_feedback.md`](language_feedback.md), when it questions a rule of the language rather than showing a defect; or kept, with a line in the log.
- **A finding that changes the report runs again the rows that read what it changed.**
- **Measured, not felt.** A reader's row that finds nothing at two releases running becomes a test, or is dropped, and this document says which.

## Briefs

`<sections>` is the sections a plan item changed, with every section they cite and every section that cites them, and the whole report before a release. `<document>` is the document the row reads; `<area>` the module, library, example or shell a change touched; `<program>` one of C10's four programs.

- **C4, the principles reader.** "Read §0 of `ernest_report.md`, then `<sections>` against its five principles alone: every second way to do one job (principle 2); anything a program does that its text does not show (3); grammar that needs backtracking, or lookahead that is unbounded or that the prose does not name (4); and, before a release, every concept, primitive and reserved word, counted against the last release's count (5). For each finding, write the smallest program that shows it and say what a reader who knows the rest of Ernest would have predicted (1)."
- **C5, the sceptical reader.** "Read `<sections>` of `ernest_report.md`. For each rule, say what it buys a program and what the language would lose without it. Report every rule whose answer is little, and every rule that exists only for another."
- **C6, C7, the cold readers.** "You know Erlang, Haskell or ML, Rust and Go, but not Ernest. Read `ernest_report.md`'s `<sections>`, and nothing else." The adversary reports two sections that disagree, prose against Appendix A, a signature against its prose, and a rule another makes unreachable. The implementer reports every place one who builds a conforming toolchain must guess, and every case the rules leave silent. The programmer reports every example that would not compile under the rules as written, every name used before it is defined, and every reference that points at the wrong section.
- **C8, the register reader.** "Read `<sections>` of `ernest_report.md` for sentences that argue rather than state, and every section over 600 words for restating, against CLAUDE.md's *Writing*."
- **C9, C11, the sweep readers.** "Read `<document>`, or its changed sections, against `ernest_report.md` and the code it describes; report every statement that is false or stale, and every fact restated outside its owner or owned by no document, checking CLAUDE.md's *Who owns each fact*; in the guide, also every job it teaches two ways."
- **C10, the newcomer.** "You know another language and not Ernest. Read `ernest_guide.md` alone, doing its exercises with `bin/ern` as it says, then write `<program>` with only what it taught you: a chat server, a tool over files, a game at a terminal, or a pipeline over standard input. Report every place you were lost, every message you did not understand, and everything you wanted and could not find." For a section added, the newcomer reads the guide up to and through that section and does its exercises. A program that shows what no example does joins `examples/`.
- **C10, the shell reader.** "You know Ernest and not the shell's code. Read `shell/README.md` alone, then find in `shell/` what it says is there. Report every place you were lost or it led you wrong."
- **C13, the code reader.** "Read `erl/<app>/src` and `erl/<app>/test`, or `erl/runtime/c_src`, against `docs/style.md` and the report sections its comments cite. Report defects, dead code, missing specs, comments that no longer hold, and code that could be shorter and clearer."
- **C14, the Ernest reader.** "Read `<area>` against the report sections it implements, Appendix E.0, and the principles. Report defects, code that could be shorter and clearer, and what a reader who knows the rest of Ernest would not predict."
- **C19, the tool reader.** "Use `bin/ern`'s jobs and options, its messages, and the shell's commands, as a programmer who has read the guide. Report every job done two ways (principle 2), everything the toolchain does that its user does not see (3), and every behaviour a user who knows the rest would not predict (1)."
- **C21, the diagnostics reader.** "You have not read the toolchain's code. For each program of the catalogue, read the message it gives against §11.5, and say whether, having made that mistake, you would know the fix."
