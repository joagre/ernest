# Coherence

Whether the project agrees with itself: the report with its principles and with itself, the guide with the report, every other document with the report and the code, and the code with the report and with its own standards. This document owns what is checked, by a command or by a reader, and when. The release review, [`review.md`](review.md), runs it whole; CLAUDE.md says that a plan step ends by running it. Soundness, a well-typed program not going wrong, is the type system's argument and not this document's (the plan's MVP 3.9).

## When

- **At the end of every plan step**, the rows the step touched: a report section changed runs C4 to C8 for that section, and C9 when the guide teaches it; a changed document runs C11 for it, and C10, with one newcomer, for a new section of a teaching document; changed code runs C13 or C14 for its area; renumbered sections run C12. C1 to C3 run with `make test`, and C17 and C18 will once built.
- **After a batch of report changes**, C9 and C11 whole: the guide against the report, and every other document against the report and the code.
- **Before a release**, every row, whole, C10 with three newcomers, each writing one of its three programs. [`review.md`](review.md) adds a release's own rows, and none of them repeats a row here.

## The checks

| | What agrees | Checked by | Done when |
|---|---|---|---|
| C1 | every report section and its tests | `make sections`, `make coverage` | no section is untested but MVP 3.0 and 3.1 material, and a section a step touched has its positive rule and its refusals tested |
| C2 | the documents' citations, paths and contents lists with what they name | `make xref`, `make test-docs` | green |
| C3 | every list that lives in the code and in a document | the mirror tests in `make test`; a reader who lists the lists | every list has a test holding the two equal |
| C4 | the report and its principles | the principles reader | every second way (principle 2), anything a program does that its text does not show (3), grammar that needs lookahead or backtracking (4), and the count of concepts, primitives and reserved words (5), each finding with the smallest program that shows it |
| C5 | each rule and its place in the language | the sceptical reader | for each rule, what it buys and what the language would lose without it |
| C6 | the report and itself | the adversary | two sections that disagree, prose against Appendix A, a signature against its prose, a rule another makes unreachable |
| C7 | the report and an implementer's needs | the implementer, reading cold | every place an implementer must guess, and every case the rules leave silent |
| C8 | the report and its register | a reader of every section over 600 words | restating and rationale gone, one rule a sentence (CLAUDE.md, *Writing*) |
| C9 | the guide and the report | `make test-guide`; the guide's sweep reader | every example runs as shown, and every statement is true to the report |
| C10 | the guide and a newcomer | the newcomer, reading cold and writing one program with only what it taught: a chat server, a tool over files, or a pipeline over standard input | where they got lost, and where the language, the library or a message stopped them, fixed; a program that shows what no example does joins `examples/` |
| C11 | every other document and the report and the code | the documents' sweep reader | no statement false or stale, and no fact restated outside its owner (CLAUDE.md, *Who owns each fact*) |
| C12 | citations of renumbered sections and their meaning | a reader of every citation of the old numbers | each still names what its sentence means |
| C13 | the Erlang and the report and `docs/style.md` | `make test`; Dialyzer and Erlang's xref, once MVP 2.95 builds their targets; a reader per application | no defect, dead code, missing `-spec` or stale comment, and the code structured and tight |
| C14 | the Ernest and the report, Appendix E.0 and principles 1 and 2 | `make test-programs`, `make test-shell`; a reader of the standard library, the shell, `libs/` and `examples/` | no defect, the code reads as one who knows the rest of Ernest would predict, and what feels against a principle is in `language_feedback.md` |
| C15 | the module pages and E.0 shape rule 6 | the documentation tests; a reader of `ern doc`'s pages | every exported name documented, its errors stated, its examples run |
| C16 | the Emacs mode and the Ernest in the repository | `make test-emacs` | green |
| C17 | the report's own examples and the compiler | a test MVP 2.95 builds | every example compiles, and every one whose value is written runs to it |
| C18 | Appendix A and the parser | a program MVP 2.95 builds | every non-terminal defined and used, the FIRST sets of every alternative disjoint or the lookahead named in the prose, programs generated from the grammar parsed, and each near miss refused with a diagnostic |

## Readers

- **A reader who took no part reads**, since what no test found has come from such readers (CLAUDE.md, *Tests*).
- **One lens a reader.** A reader is given one row's question and the files that answer it, and nothing that argues for the text; a cold reader is never given the log.
- **Every finding is decided.** It is fixed with a regression test, planned in a named milestone with its shape, or weighed and kept with a line in the log. The report changes first.
- **A reader hands in** a numbered list, most serious first, each finding with where, a short quote, what is wrong, and a one-line fix, defects apart from matters of clarity; it reads only the files named and edits nothing.

## Briefs

- **C4, the principles reader.** "Read §0 of `ernest_report.md`, then every other section against its five principles alone. For each finding, write the smallest program that shows it and say what a reader who knows the rest of Ernest would have predicted."
- **C5, the sceptical reader.** "Read `ernest_report.md`. For each rule, say what it buys a program and what the language would lose without it. Report every rule whose answer is little, and every rule that exists only for another."
- **C6, C7, the cold readers.** "You know Erlang, Haskell or ML, Rust and Go, but not Ernest. Read `ernest_report.md` from its first line to its last, and nothing else. As the adversary / the implementer, report ..." with the row's question.
- **C9, C11, the sweep readers.** "Read `<document>` against `ernest_report.md` and the code it describes; report every statement that is false, stale, or restates what another document owns, checking CLAUDE.md's *Who owns each fact*."
- **C10, the newcomer.** "You know another language and not Ernest. Read `ernest_guide.md` alone, doing its exercises with `bin/ern` as it says, then write `<program>` with only what it taught you. Report every place you were lost, every message you did not understand, and everything you wanted and could not find."
- **C13, C14, the code readers.** "Read `erl/<app>/src` (or the Ernest named) against `docs/style.md` and the report sections its comments cite. Report defects, dead code, missing specs, comments that no longer hold, code that could be shorter and clearer, and, for Ernest, what feels against principles 1 and 2 or Appendix E.0."
