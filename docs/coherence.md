# Coherence

Whether the project agrees with itself: the report with its principles and with itself, the teaching documents and every other document with the report and the code, and the code with the report, with the principles and with its own standards. This document owns what a change runs, by a command or by a reader, and when each check passes. The commands run with every change. The rows a reader runs are gone through before a release, as the table's last line says, and for a change only when the user asks for them, the table saying which rows such a request runs. [`review.md`](review.md) begins by running every row.

**Enough.** A check a machine can make is built once, since it costs nothing after: it runs with every change where it is quick, in `make test`, and at every release where it is not. A reader is given only what needs judgment, ten readers a release: the principles reader and the cold reader of the report, the register reader of its long sections, the guide's sweep and the documents' sweep, one newcomer, the code reader and the Ernest reader on what changed since the last release, the tool reader, and the diagnostics reader; and a session editing a module in the Emacs mode. The effort goes where findings have come from, the tests under load, a read-back, an independent reader, and the user.

## What a change runs

The documents that cite or describe a change are found by searching the repository for the section numbers, names and paths it changed. A batch of report changes is a plan item that changes more than one report section.

| A change to | The commands | The rows |
|---|---|---|
| anything | `make test`, once per plan item, before the commit that closes it | C1 for the report sections the item changed; C2 and C3, whose tests `make test` runs |
| a report section | `make test-docs` | C4, C6 and C8 for the section; C9 when the guide teaches it; C11 for every document that cites or describes it; C17 and C18 once built |
| §0 or Appendix E.0 | `make test-docs` | C4 over the whole report, and C14 over the code E.0 governs |
| §11.5 | `make test-docs` | C21 once built |
| the guide | `make test-guide`, `make test-docs` | C9 for the sections changed; C10 with one newcomer for a section added |
| the README | `make test-docs` | C11 for it; C10 with one newcomer, who reads it and stops |
| `shell/README.md` | `make test-docs` | C11 for it; C10 with one shell reader for a section added |
| another document | `make test-docs`, or `make xref` for citations and paths alone | C11 for it |
| a rule document: CLAUDE.md, `docs/style.md`, this document, `review.md` | `make test-docs`, and `make test` for `docs/style.md` | C11 for every document that applies it, and for `docs/style.md` C13 and C14 over the code it governs |
| the Erlang of an application under `erl/`, its tests included | `make test-erl APP=<app>` and `make test-programs`; `make test` for the checker, the emitter or the runtime; `make load` for the runtime or the shell's front end, as [`memory.md`](memory.md) says | C13 for the application; C11 for every document that describes it; C19 for a change a user of `ern` or the shell meets; C21 for a change to a diagnostic, once built; C15 for a change to `ern_page`, which renders a module's page |
| the helper in C, `erl/runtime/c_src/` | `make`, then `make test-erl APP=runtime` and `make test-programs` | C13 over the helper |
| `stdlib/` | `make test-erl APP=runtime`, `make test-programs` | C14 for the module; C15 for its page; C11 for every document that describes it |
| `shell/` | `make test-shell` | C14 for the shell; C19; C11 for `shell/README.md` and `docs/shell_design.md` |
| `libs/` | `make test-erl APP=runtime`, which reads their pages | C14 for the library; C15 for its page |
| `examples/` | `make test-programs` | C14 for the example; C11 for every document that cites it |
| `bin/ern`, the Makefiles, `tools/` | `make test` | C11 for `docs/development.md`, CLAUDE.md's *Tests* and `docs/architecture.md`; C19 for `bin/ern` |
| the Emacs mode | `make test-emacs` | C16 |
| a vendored file or a table built from another's data | `make test` | C20 |
| the section numbers of the guide, which change only where a section cannot be placed otherwise | `make xref` | C11 for every document that cites the guide |
| a batch of report changes | | C9 and C11 over every document |
| a release | every command above, and every machine of the rows below | every row: C4, C6 and C9 over the whole report and guide, C8 over every section over 600 words, C11 over every document, C10 with one newcomer and one of its programs, the next in turn, and the shell reader where `shell/README.md` changed, C13 and C14 over what changed since the last release, C16, C19 and C21 |

## The checks

| | What agrees | Checked by | Passes when |
|---|---|---|---|
| C1 | the report's sections and their tests | `make sections` and `make coverage` (`docs/development.md`, *Building*) | `make sections` lists only the sections the plan's *Standing gaps* names, and every section `make coverage` shows cited by one test has been read, by whoever runs the review, for a rule it states without a test |
| C2 | the documents' citations and paths, and the report's and the guide's contents lists | `make xref`, `make test-docs` | green: every citation names a heading, every path named exists, and each contents list equals its headings |
| C3 | every list that lives in the code and in a document | the mirror tests; the documents' sweep reader (C11), who lists the lists | green, and every list has a test holding the two equal |
| C4 | the report and its principles, and each rule and its place in the language | the principles reader | its findings decided |
| C6 | the report and itself, and those who build and program from it | the cold reader | its findings decided |
| C8 | the report's long sections and its register | the register reader | its findings decided |
| C9 | the guide and the report | `make test-guide`; the guide's sweep reader | green, and its findings decided |
| C10 | the README and a teaching document, and a newcomer | the newcomer, or for `shell/README.md` the shell reader | its findings decided |
| C11 | every other document and the report and the code | the documents' sweep reader | its findings decided |
| C13 | the Erlang and the C, and the report and `docs/style.md` | `make dialyzer`, over the toolchain and the Erlang the compiler writes; `make calls`, Erlang's xref for undefined calls, unused exports and deprecated calls, which `make test` runs; `make untested`, the functions `make test` never runs, by the host's native coverage; `make sanitize`, the helper in C built with the address and undefined-behaviour sanitizers under `make test-erl APP=runtime` and `make test-programs`, and Clang's static analyzer; each over the whole; the code reader, over what changed since the last release | Dialyzer, the xref analyses, the sanitizers and the analyzer clean, each function never run read as dead code or a missing test, or decided with its reason in `tools/ern_cover.erl`, as `make untested` requires, and the reader's findings decided |
| C14 | the Ernest and the report, Appendix E.0 and the principles, and the module pages and E.0 shape rule 6 | `make unused`, every private declaration of `stdlib/`, `shell/`, `libs/`, `examples/` and `tools/` that nothing uses, a function or a `let` by the host compiler's warning on the Erlang they compile to and a type by its module's tokens, which `make test` runs; the Ernest reader, over what changed since the last release and the pages `ern doc` writes of it | nothing unused, and the reader's findings decided |
| C15 | the module pages and E.0 shape rule 6 | the documentation tests | green: every exported name documented, its errors stated, its examples run |
| C16 | the Emacs mode and the Ernest in the repository | `make test-emacs`; before a release, a session editing a copy of a module of the standard library, outside the repository | green, and what the session found wrong in indentation and faces decided |
| C17 | the report's own examples and the compiler | a test MVP 2.95 builds, once the report marks its blocks as the guide does | every block marked an example compiles, every one whose value is written runs to it, and every one marked rejected is refused with the error it names |
| C18 | Appendix A and the parser | a program MVP 2.95 builds | every non-terminal defined and used, and the FIRST sets of every alternative disjoint or the lookahead named in the prose; programs generated from the grammar are MVP 3.9's |
| C19 | the toolchain and the shell as a user meets them, and the principles | the tool reader | its findings decided |
| C20 | borrowed code and `THIRD_PARTY_LICENSES` | a test MVP 2.95 builds, that every file with an upstream header, and every table built from another's data, is listed with its licence | green |
| C21 | the lexer's, the parser's and the checker's messages, and §11.5 | a catalogue of one small program for every error they give, which MVP 2.95 builds; the diagnostics reader | every error has its program, and the reader's findings decided |
| C22 | the front end and input it was not written for | `make garbled`, which MVP 2.95 builds: every example and module of the standard library with its tokens garbled, one deleted, one doubled, two swapped, given to `ern build`, and the lines of the shell's sessions so garbled given to the shell | every one answered with a diagnostic, never a failure of the toolchain |

C5, C7 and C12 were retired on 2026-09-27: C5's question is C4's brief, C7's are C6's, and C12's, whether a citation of a renumbered section still names what its sentence means, is C11's where the guide renumbers, since the report never does. A row's number is never given again.

## Readers

- **A reader who took no part reads**, since an independent reader is among what has found what no test did (CLAUDE.md, *Tests*).
- **One row a reader.** A reader is given one row's brief and the files that answer it, and nothing that argues for the text; a cold reader is never given the log.
- **A reader hands in** a numbered list, most serious first, each finding with where, a short quote, what is wrong, and a one-line fix, defects apart from matters of clarity. It reads only the files named, and edits nothing in the repository.
- **A finding is decided** when it is fixed, with a regression test where the defect is in code; planned, as CLAUDE.md's *Defects and gaps* plans a gap; entered in [`language_feedback.md`](language_feedback.md), when it questions a rule of the language rather than showing a defect, as what C10 and C14 report apart does; or kept, with a line in the log.
- **Each row runs once.** A defect is fixed or planned; a matter of clarity is fixed where that is cheap, and otherwise kept with a line in the log. A row runs again only over a report section a finding rewrote.
- **Measured, not felt.** A reader's row that finds nothing at two releases running becomes a test, or is dropped, and this document says which.

## Briefs

`<sections>` is the sections a plan item changed, with every section they cite and every section that cites them, and the whole report before a release. `<document>` is the document the row reads; `<area>` the module, library, example or shell a change touched; `<program>` the one C10's newcomer writes.

- **C4, the principles reader.** "Read §0 of `ernest_report.md`, then `<sections>` against its five principles alone: every second way to do one job (principle 2); anything a program does that its text does not show (3); grammar that needs backtracking, or lookahead that is unbounded or that the prose does not name (4); and, before a release, every concept, primitive and reserved word, counted against the last release's count (5). For each finding, write the smallest program that shows it and say what a reader who knows the rest of Ernest would have predicted (1). Then, for each rule, say what it buys a program and what the language would lose without it, and report every rule whose answer is little, and every rule that exists only for another."
- **C6, the cold reader.** "You know Erlang, Haskell or ML, Rust and Go, but not Ernest. Read `ernest_report.md`'s `<sections>`, and nothing else. Report two sections that disagree, prose against Appendix A, a signature against its prose, and a rule another makes unreachable; every place one who builds a conforming toolchain must guess, and every case the rules leave silent; and every example that would not compile under the rules as written, every name used before it is defined, and every reference that points at the wrong section."
- **C8, the register reader.** "Read the sections of `ernest_report.md` over 600 words, and `<sections>` where a change asks for this row, for sentences that argue rather than state, and for restating, against CLAUDE.md's *Writing*."
- **C9, C11, the sweep readers.** "Read `<document>`, or its changed sections, against `ernest_report.md` and the code it describes; report every statement that is false or stale, and every fact restated outside its owner or owned by no document, checking CLAUDE.md's *Who owns each fact*; in the guide, also every job it teaches two ways." C11's reader also lists every list that lives in two places, and reports each one no test holds equal (C3).
- **C10, the newcomer.** "You know another language and not Ernest. Read `README.md`, then `ernest_guide.md` alone, doing its exercises with `bin/ern` as it says, then write `<program>` with only what it taught you." `<program>` is one of a chat server, a tool over files, a game at a terminal, and a pipeline over standard input, the next in turn at each release. "Report what on the README put you off or told you too little to go on, every place you were lost, every message you did not understand, and everything you wanted and could not find; and, apart, every place the language itself, not the guide, made your program harder to write than you expected." For a section added, the newcomer reads the guide up to and through that section and does its exercises. A program that shows what no example does joins `examples/`.
- **C10, the shell reader.** "You know Ernest and not the shell's code. Read `shell/README.md` alone, then find in `shell/` what it says is there. Report every place you were lost or it led you wrong."
- **C13, the code reader.** "Read `erl/<app>/src` and `erl/<app>/test`, or `erl/runtime/c_src`, against `docs/style.md` and the report sections its comments cite. Report defects, missing specs, comments that no longer hold, and code that could be shorter and clearer." What is unused, and what the suite never runs, the row's machines list, and the reader reads their lists rather than hunting for it.
- **C14, the Ernest reader.** "Read `<area>` against the report sections it implements, Appendix E.0, and the principles, and read the page `ern doc` writes of each module in it as a programmer would. Report defects, code that could be shorter and clearer, what a reader who knows the rest of Ernest would not predict, and what a page leaves a programmer unable to use; and, apart, every place the language made the code harder than it should be: a workaround that should not be needed, a second way, something invisible, a function the standard library lacks."
- **C19, the tool reader.** "Use `bin/ern`'s jobs and options, its messages, and the shell's commands, as a programmer who has read the guide. Report every job done two ways (principle 2), everything the toolchain does that its user does not see (3), and every behaviour a user who knows the rest would not predict (1)."
- **C21, the diagnostics reader.** "You have not read the toolchain's code. For each program of the catalogue, read the message it gives against §11.5, and say whether, having made that mistake, you would know the fix."
