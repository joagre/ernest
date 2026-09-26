# The review before a release

How Ernest is reviewed before a release: the report as a specification, the report against the code, the code as code, the documents, and the language in use. This document owns the procedure: its phases, what each reader is asked, and when the review is done. The plan says when a review runs and holds its ledger; the log records what its findings decided; the report, the code and the other documents stay the owners of what the review checks.

The review is run whole before every release, and in part whenever a milestone changes what a phase covers. The sweeps CLAUDE.md asks for at the end of every plan step are its lightest form.

## Rules

- **A reader who took no part reads.** Every finding the project has had that no test found came from the terminal harness under load, a read-back of code, an independent reader, or the user. A reader is given one question, the files that answer it, and nothing that argues for the text: never the log, where a phase reads the report or the guide cold.
- **One lens a reader.** A reader asked to check everything checks nothing well. Each phase below names its lenses; a lens is one reader, and two readers on one lens find different things.
- **Every finding is decided, none left open.** A finding is fixed with a regression test, planned in a named milestone with its shape, or weighed and kept with a line in the log. The report changes first, as always.
- **The findings go to their owners.** The review's ledger is a table in the plan, as step 10 of MVP 2.65 had; an open question about the report waits in `docs/report_cold_read.md`, and one about how the language feels in `docs/language_feedback.md`, until the ledger decides it.
- **Measured, not felt.** Where a phase can be a test, it is one, and the next review runs it instead of reading again. A phase that finds nothing twice running becomes a test or is dropped, and this document says which.
- **The order is the owners' order.** The report first, since everything is checked against it; then the code against the report; then the code as code; then the documents against both; then the language in use. A finding in an earlier phase that changes the report is decided before a later phase reads what it changed.

## Phase 0: freeze and baseline

The tree is clean and `make test` is green. The review records, in the plan's ledger, the numbers the next review compares against:

- the report's measure, as the log's *Measure* counts it, and each section's length;
- `make sections` and `make coverage`: the sections no test cites and the thinnest;
- the count of tests by suite, of prelude names, of standard library functions by module, of primitives, and of the lines of Erlang and of Ernest by application;
- the memory, atoms and processes of the load programs (Phase 3), before and after a long run;
- the speed of the load programs, a round trip of the echo server and a compile of the standard library, so that a change is seen; a number is recorded and compared, never a reason for a shim (CLAUDE.md, *Shims*).

A number that moved without a plan item that moved it is a finding.

## Phase 1: the report as a specification

The report is read alone, as the one normative document it is, for what it says and for what it leaves unsaid.

**1a. Cold reads.** Three readers, each with the report alone:

- *The implementer*, who must build a conforming toolchain from it: every place where they would have to guess, a case the rules leave silent, a rule that cannot be applied without knowing the existing code.
- *The programmer*, who must write programs from it: every example that would not compile under the rules as written, every name used before it is defined, every reference that points at the wrong section.
- *The adversary*, who looks for contradictions: two sections that disagree, prose against Appendix A, a signature against its prose, a rule that makes another unreachable.

**1b. The principles.** A fourth reader reads the report against §0 alone and reports, section by section: a second way to do one job (principle 2), anything a program does that its text does not show (3), grammar that needs lookahead or backtracking (4), and every concept, primitive and reserved word counted against the last release's count (5). Principle 1 is judged on the code the principles produce, so this reader writes a small program for each finding and says what a reader of the rest of Ernest would have predicted.

**1c. The grammar, mechanically.** Appendix A is read by a program, not a person: every non-terminal defined and used, the FIRST sets of every alternative disjoint or the lookahead that separates them named in the prose, as Appendix A's closing paragraph promises. Then the parser against Appendix A: programs generated from the grammar parse, and each mutated into a near miss is refused with a diagnostic, never a crash.

**1d. The type system.** A written argument that a well-typed program does not go wrong: the core calculus, then effects and mailbox types, the reply discipline's linearity, and the places where rules meet, generalization against effects, a pure function standing for one with a mailbox, a reply captured by a lambda. The argument is short and in the log; where it cannot be made, that is a finding. A model a machine checks is a later step, taken if the written argument finds a rule it cannot settle.

**1e. The cousins.** For each feature a later release added, a reader compares Ernest with the languages its decisions name, Erlang, Elixir, Gleam, OCaml, Akka, Pony, Unison, and reports where Ernest is worse without a reason the log gives.

**1f. The register.** Every section over 600 words is read for restating, and the report is read for sentences that argue rather than state (CLAUDE.md, *Writing*).

## Phase 2: the report against the code

**2a. Coverage.** Every section cited by a test, the thinnest raised, and every section's positive rule and its refusals each tested, a rule without its refusal tested being a finding.

**2b. The report's own examples.** Every `ernest` block in the report compiles, and every one whose value is written runs to it, as the guide's examples do.

**2c. The mirrors.** Every list that lives in the code and in a document has a test holding the two equal (CLAUDE.md, *Who owns each fact*). A reader lists the lists: the prelude, Appendix E's signatures and types, the primitives, the shell's commands, the refusals that name an MVP, the system modules, the guide's prelude declarations; each has its test, or the missing test is a finding.

**2d. Well-typed programs do not crash.** Programs generated to type-check, run under the runtime, end by returning, by a cause of §7.4, or by a deadlock; a host error that is none of §7.4's causes is a finding in the checker or the runtime. This is the test of Phase 1d's argument.

**2e. The standard library's laws.** Properties rather than cases: `String.split` then `String.join` gives the string back, `Map.fromList` then `Map.toList` the pairs, `Float.toString` reads back, `List.sort` is stable and ordered, a search matches whole graphemes. Each module's contract, as its section and its doc blocks state it, generated against.

**2f. Diagnostics.** Every error the checker can give, from a catalogue of one small program each, read for §11.5's shape and for whether a reader who made the mistake understands the fix.

## Phase 3: the code as code

**3a. The Erlang, read back.** A reader per application, against `docs/style.md` and correctness: dead code, a missing `-spec`, a case a function does not handle, a comment that says what the code no longer does. Then the machines: Dialyzer over every application, and Erlang's xref for undefined calls and unused exports.

**3b. The Ernest, read back.** The standard library, the shell, the libraries and the examples, against principles 1 and 2 and Appendix E.0, as CLAUDE.md's *Reading back* asks; what feels against a principle goes to `language_feedback.md`.

**3c. Load and memory.** The load programs, the examples as servers, the shell over a long scripted session, a server under many requests, each run long, with the host's memory, atoms and processes measured before and after. Growth that no collection reclaims is a finding fixed at its cause, never by a cap (CLAUDE.md, *Defects and gaps*).

**3d. Timing.** The whole suite run with the emulator's modified timing (`+T`), which reorders scheduling, and the terminal harness under load, since races show only when the order changes.

**3e. The boundaries.** A reader looks at what crosses a trust boundary: the foreign boundary's checks, the configuration directory and its key, a path from the network, a socket's input, the shell's history file.

**3f. Versions.** The compiled `.erc` of the last release: the current toolchain recompiles it, as §11.1's rule says, rather than loading it; and every declaration added since the last release carries a `since` line with the new version (E.0 shape rule 6).

**3g. What we borrow.** Every vendored file and every table built from another's data, `getopt` and Unicode's among them, is listed in `THIRD_PARTY_LICENSES` with its licence and keeps its upstream header; a new one is a finding until it is.

**3h. Portability.** The suite on the OTP versions the README names, on Linux and on macOS, under `LANG=C`, and in the terminals the shell promises: a plain terminal, `tmux`, and one without colour.

## Phase 4: the documents

**4a. The guide, cold.** A reader who knows another language and not Ernest reads the guide alone and writes the programs its exercises ask for; where they got lost is fixed (CLAUDE.md, *Reading back*).

**4b. The sweeps.** The guide against the report, and every other document against the report and the code, by two readers who did not write them.

**4c. The owners.** A reader checks each fact against CLAUDE.md's owners: a restatement outside a teaching document or a mirror is a finding, and so is a fact no document owns.

**4d. The README, run.** Every command the README gives is run in a fresh clone, on a machine with only what the README says is needed, and does what the README says.

**4e. The module pages.** `ern doc` of the standard library and of every library, read as a reader of a manual page reads: every exported name documented, its errors stated, its examples run (E.0 shape rule 6).

**4f. The Emacs mode.** Its tests over every Ernest file in the repository, and a session of editing a module of the standard library, what its indentation and faces get wrong recorded (`docs/emacs_mode.md`).

**4g. The installation.** Once the plan's MVP 2.95 has built one: installed into a temporary prefix, moved to another, and run from there, `ern run`, `ern shell`, `ern doc` and a manual page each; then uninstalled, leaving nothing.

**4h. The release notes.** What changed since the last release, written from the plan's milestones and the log's entries, each change with the report section that states it.

## Phase 5: the language in use

**5a. Programs from scratch.** Readers who know only the guide each write a program of a kind Ernest is for, a chat server, a tool over files, a game at a terminal, a pipeline over standard input, and report where the language, the library or a message stopped them. Their programs join `examples/` when they show something no example does.

**5b. The shell in real use.** A scripted session of an hour at a terminal, under the harness, and a person's session, as MVP 2.6 closed with.

**5c. Mistakes.** The mistakes the guide names, and those the programs of 5a made, each checked for the message the toolchain gives.

## Done

The review is done when every finding in its ledger is fixed, planned in a named milestone, or weighed and kept; `make test` is green; the numbers of Phase 0 are recorded again beside the old ones; and the release notes are written. The release is then tagged.

## Reader briefs

What each reader is given, to be copied into the brief and completed. Every brief ends the same way: read only the files named; edit nothing; report findings as a numbered list, most serious first, each with where, a short quote, what is wrong, and a one-line suggested fix, separating defects from matters of clarity.

- **Cold reader of the report (1a, one of three lenses).** "You know Erlang, Haskell or ML, Rust and Go, but not Ernest. Read `ernest_report.md` from its first line to its last, and nothing else. As *the implementer* / *the programmer* / *the adversary*, report ..." with the lens's sentence from 1a.
- **Principles reader (1b).** "Read §0 of `ernest_report.md`, then every other section against its five principles alone. For each finding, write the smallest program that shows it and say what a reader who knows the rest of Ernest would have predicted."
- **Cousin reader (1e).** "For each feature named, say how Erlang, Elixir, Gleam, OCaml and Akka do the same job, and where Ernest's way is worse; read `docs/decisions.md`'s entry for the feature first, and report only what it does not answer."
- **Code reader (3a, 3b).** "Read `erl/<app>/src` (or the Ernest named) against `docs/style.md` and the report sections its module comments cite. Report defects, dead code, missing specs, comments that no longer hold, and, for Ernest, what feels against principles 1 and 2 or Appendix E.0."
- **Sweep reader (4b).** "Read `<document>` against `ernest_report.md` and the code it describes; report every statement that is false, stale, or restates what another document owns, checking CLAUDE.md's *Who owns each fact*."
- **Newcomer (4a, 5a).** "You know another language and not Ernest. Read `ernest_guide.md` alone, then write `<program>` with only what it taught you, running `bin/ern` as it says. Report every place you were lost, every message you did not understand, and everything you wanted and could not find."
