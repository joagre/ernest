# Ernest Implementation Plan

The roadmap: what will be built, in what order, and what is built already. Why anything is
the way it is belongs in [`decisions.md`](decisions.md); what the language is belongs in
[`ernest_report.md`](../ernest_report.md); how the code is arranged belongs in
[`architecture.md`](architecture.md). This document points at them rather than repeating
them.

Read "Where we are" first. The milestones follow in order, then the standing gaps, then what
is done, then the tables worth keeping.

The toolchain is `ernc`, which compiles `.ern` to `.erc`, and `ern`, which runs a `.erc` and
adds a shell on request. Written in Erlang on OTP 29, one person. The language was called
Actorson until 12 September 2026.

---

## Where we are

**MVP 2.6, the shell, checkpoint 4.** Checkpoints 0 to 3 are done: the loop and the terminal
harness, bindings and the commands, the live region, and the line editor with history,
multi-line input and paste. What is left of the milestone is in "MVP 2.6" below: completion
and the prelude's documentation, the closing sweep, and a session of real use.

**MVP 2.61, the guide, done 2026-09-24, out of order.** A newcomer reads the guide and not
the report, so the guide was rewritten to teach Ernest on its own; the steps are in "MVP
2.61" below. MVP 2.6 resumes after the rewrite of CLAUDE.md.

**After MVP 2.61, CLAUDE.md is rewritten for clarity**, every rule kept: the working rules
read in the order of work, each stated once. Asked for 2026-09-24; the rule that nothing
routes around a defect, in code or in a document, is already in it.

**The rhythm.** One item a turn, with its tests, its documents, its conformance section and
its commit; then a stop for review before the next. The user reads the plan and not the log,
so a decision they must see goes here.

---

## Milestones

| | What | State |
|---|---|---|
| MVP 1 | the chain: parser, types, BEAM | done 2026-09-18, tag `mvp1` |
| MVP 2 | the rest of the report on one node | done 2026-09-19 |
| MVP 2.5 | a complete standard library | done 2026-09-20 |
| **MVP 2.6** | **the shell** | **checkpoints 0–3 done; checkpoint 4 next** |
| MVP 2.61 | the guide as the user's document | done 2026-09-24, out of order |
| MVP 2.65 | the language and the toolchain read back | after 2.6 |
| MVP 2.66 | introduce a supervisor behaviour? | after 2.6 |
| MVP 2.7 | the first libraries and the network stack | |
| MVP 2.8 | four more libraries | |
| MVP 2.9 | an Emacs major mode | done 2026-09-23, out of order |
| MVP 3.0 | peers | |
| MVP 3.1 | content addressing | |

---

## MVP 2.6 (the shell), about two weeks

The program that exercises everything at once, and the whole milestone: the libraries moved
to 2.7 on 2026-09-20 so that one large thing is measured rather than two. Designed in
[`shell_design.md`](shell_design.md), which owns the design; §11.2 owns what a user may rely
on. The source is a tree of its own, `shell/`, compiled by `make` into `build/shell/`, since
the shell is neither standard library nor library but the toolchain's own program.

**The checkpoints**, each a stop for review.

| | What | State |
|---|---|---|
| 0 | expressions only: the three processes, the foreign interface, an input checked, compiled, run, printed | done 2026-09-20 |
| 1 | bindings, `it`, timing, declarations at the prompt, the commands, fault reports, `:load`/`:reload`, the startup files | done 2026-09-20 |
| 2 | the terminal and the live region, `:output <path>` | done 2026-09-21 |
| 3 | the line editor: editing, history and its search, multi-line input, bracketed paste | done 2026-09-21 |
| 4 | completion and documentation | **next** |

**What is left.**

- **Checkpoint 4, completion and documentation.** Steps 1 to 3 are done, 2026-09-21:
  `Shell.Complete`, pure and tested, matching by prefix and by abbreviation segment by
  segment; `Tab` replacing the word before the cursor and indenting four spaces where there
  is none; a second `Tab` listing the candidates with their types above the region, forty at
  most; and the parser saying what may stand at the cursor, which filters the candidates by
  kind. What is left of the checkpoint: what completes by position, bindings and modules and constructors in an
  expression, types after `:`, a constructor's remaining fields, a command and then its
  argument; `Shift-Tab` for documentation, the type and first sentence and `since`, a second
  press for the `:doc` section, and inside a call the signature with the parameter at the
  cursor marked. Step 4 is half done, 2026-09-21: the editor reads `Escape [ Z` as one key,
  `Shift-Tab` shows a name's type and first sentence and the whole page when pressed again,
  and a command completes as a word of the shell's own, `:br` to `:browse`, with a second
  `Tab` listing them all. **Left of step 4:** the signature with the parameter at the cursor
  marked, which wants a parser tag for "inside a call's argument n" as the field position
  got one; a declaration's own `since`, which the page does not carry per declaration; and
  a terminal test for `Shift-Tab` and command completion — the editor's own tests cover the
  key, and the behaviour was checked by hand, but the pty test written for it raced its own
  output and was taken out rather than left failing.
- **Done 2026-09-24: an Erlang module of one's own is loaded from the load path.** A
  `foreign fn` could name `store_helper:lookup/1`, and nothing put a user's `.beam` where the
  host found it. Report §11.2 now says that such a module is the host's own or a `.beam` in a
  directory of the load path, the host's own first, and `ern` adds the load path to the
  host's code path. The guide's §8.5 helper is a complete module the guide test compiles with
  `erlc` and runs. MVP 2.7's libraries build their Erlang modules into their own directory
  under `build/libs/`, which `--load-path` already names.
- **`ern_shell_tests`' program session is timed, and failed once.** Found 2026-09-24: it
  failed in one `make test` and passed in the next two, alone eight times, and twelve at
  once, so the failing assertion was not captured. The session's asserts rest on two waits
  of 400 ms against faults due at 100 and 150 ms, so a slow moment lets a fault report land
  after `:faults` or after `:quit`. Fixed in this checkpoint, with the harness work: the
  inputs wait on the faults, not on time, by monitoring the worker they spawn and by a
  command or a wait that ends when the program's entry point has ended.
- **`:type` of a name prints its instance, so its variables lose their names.** Found
  2026-09-24 by the guide's cold read: `:type Io.readLine` prints `with e` where `:browse Io`
  prints `with m`, since an instance's variables carry no names (`ern_types:instantiate/2`,
  report §11.5). Right for an expression, surprising for a name (principle 1). **Decided
  2026-09-24:** `:type` of an input that is one name, qualified or not, prints that name's
  declared type, as `:browse`, `:doc` and `Shift-Tab` do, and report §11.2 says so; any
  other expression prints its type as now. Built with the prelude's documentation below,
  which needs the same lookup of a prelude name's declared type.
- **`:doc` knows nothing of the prelude.** Found 2026-09-24: `:doc monitor`, `:doc Down`,
  `:doc Optional` and `:doc IoError` print "no documentation", so the names a program uses
  most are the ones the shell cannot explain, and `Shift-Tab` shows nothing on them. The
  prelude is a table in `erl/typer/src/ern_prelude.erl` whose source is report §9, kept
  equal to it by `ern_prelude_tests`, and no doc block exists for it. **Decided
  2026-09-24:** each entry of the table carries its documentation, written by E.0 rule 6
  as a standard library export's is, since the table is the prelude's one source in code
  and a `stdlib/prelude.ern` cannot declare `spawn` or `Int`. Report §9 gains the sentence
  that the prelude's names are documented as the standard library's are; `:doc`,
  `Shift-Tab`, and `ernc --doc` of a page named `Prelude` read it, and a test fails on a
  name without it. Built in checkpoint 4, before the in-call signature, since that
  signature shows the prelude's calls too. The guide's declarations of `Down`, `Reason` and
  `RemoteError`, fragments until then, then become `:doc` sessions the guide test checks.
- **Typing ahead while an input runs looks wrong.** A test that sent a second input before
  the first had finished never saw the second's result. Found 2026-09-21, not diagnosed, and
  recorded in the language note; it belongs with the session of real use below.
- **The closing sweep**, as the working rules require at the end of a plan step: the guide
  read against the report, then every other document against the report and the code.
  **Decided 2026-09-24:** report §11.2 states `Tab` completion and `Shift-Tab`
  documentation as it states the editing keys, since they are the shell's behaviour and
  §11 owns the toolchain's; `docs/shell_design.md` keeps how they are built. Written in
  this sweep, once checkpoint 4 has finished them.
- **A session of real use.** The user works in the shell and reports what it is like; what
  that finds is fixed before the milestone closes or recorded in the design note. Nothing so
  far has been driven by hand — every test goes through the pseudo-terminal harness, which
  tests what was thought of.

**Out of 2.6:** every library, which is 2.7 with the paper program that needs it; `Regex`,
`Crypto`, `Uri`, `Zlib`, which are 2.8; the library fetcher, 3.1; an HTTP server, never.
Field selection and the names of the toolchain's options moved to 2.65 on 2026-09-21.

**What the shell has changed so far**, one line each, the arguments in the log.

- **Before any of it**, 2026-09-20: `test/ern_pty.py`, a pseudo-terminal harness, since
  Erlang cannot open one; `make test` needs python3. It tests §8.2's rules and drives snake.
  Rewritten the same week to wait for what it expects on the screen rather than to send at
  fixed times, which had failed about one run in ten.
- **§9.3 and §8.2 gained what the shell needs**, 2026-09-20: the terminal's interrupt as a
  key for the terminal's holder, the terminal's size, whether input is a terminal, and the
  runtime's record of how every process ended as a door for the shell alone.
- **Incremental checking was the estimate's risk and is not**, 2026-09-20: the checker takes
  the session as a fourth argument and resolution rewrites a session name to the input that
  declared it, so nothing downstream knows of a session. Two small changes.
- **`Keys` became `Terminal`**, 2026-09-20, one module for the resource; `io_ansi:scan` was
  measured twice and refused, being a capability scanner.
- **The panes became a live region**, 2026-09-21: the transcript is written into the terminal
  and scrolled by it, and the shell paints only the bottom rows. `Key` folded into one flat
  `Event`; the pane routing went in the same commit.
- **The pure parts became modules of their own**, 2026-09-21: `Shell.Editor`, `Shell.History`
  and `Shell.Region`, each tested by `ern --test` as top-level `Test` values — the first use
  of §9.3's `Test` here. Each split was forced by a name collision, which is the namespace
  rule doing the pushing; the log's entries say so.
- **The rule for `foreign`**, 2026-09-21, now in CLAUDE.md: a door is admitted for what the
  host alone can do, and everything else is written in Ernest. Its first sweep found one
  door of twenty-three in breach, `startup/0`.
- **Report changes it forced**, all 2026-09-21 unless dated otherwise: §11.2's whole core,
  the live region, `:output`, the history file, multi-line input, and the paste; §9.3's
  `Event` and `Pasted`; §8.2's bracketed paste and the answered subscription; §4.2's
  exported-declaration rule and the sentence on reaching a child module from its parent; E.5
  `indexOf`, `lastIndexOf`, and what a character is.
- **Defects it found, none of them the shell's**: `ernc` crashing on an exported declaration
  naming a private type; a binding compiled inside an unmarked foreign call, which fired
  `Deadlock`; a `let` of function type emitted as a `fn`; a subscription answered before the
  mode was set; the terminal process counting its source after `stty`, which fired `Deadlock`
  under load; `process_of/1` answering a checking proxy's own pid; the key decoder reading
  `\e[2` as `Escape` and two characters; and initializers running in alphabetical order
  rather than §8.5's dependency order.

---

## MVP 2.61 (the guide as the user's document), taken 2026-09-24

A reading of `ernest_guide.md` as a newcomer's document found it accurate against the report
and written as its companion: framed for reading rather than writing, heavy with the report's
corners, and without a reason to learn the language. A newcomer does not read the report, so
the guide must teach Ernest on its own, in Wirth's register, and sell it on its merits,
without boasting. Each step is a stop.

1. **Done 2026-09-24: the guide's examples are checked mechanically**, as the standard library's are. A
   complete program in an `ernest` block type-checks; one followed by an `output` block is
   run and its output compared; an `ernest-rejected` block must fail for a reason of its own.
   Anything else is a fragment, which nothing checks. `test/ern_guide_tests.erl` owns the
   convention; 22 examples and one rejected example are checked, and step 5 makes more of the
   fragments complete.
2. **Done 2026-09-24: the opening: why Ernest, and a first program.** The guide is
   *Programming in Ernest*. §0 shows four mistakes `ernc` finds, each as the program and its
   error: a wrong message to a process, a request left unanswered, a function that acts
   through a process without saying so, an `Either` dropped by a statement. §1 runs hello
   world with no configuration, which moves to §7 where peers need it, and opens the
   shell. The test compares a rejected block's error, and a shell session's output, with the
   console after it. Writing it found three things, fixed here: `ernc` crashed printing an
   error whose source line holds a character outside Latin-1, and `ern` printed such text
   byte by byte; the report did not say which path an error names (§11.5), nor that the
   shell prints nothing for a `Unit` value (§11.2).
3. **Done 2026-09-24: §2 and §3 cut to teaching weight.** A rule and an example stay; a
   corner points to the report in a line. The prose went from 3,532 words to 2,271: the
   standard library's rules keep one example each instead of Appendix E's lists, and the
   literal corners, the evaluation order of fields, and the rules for a local `fn` became
   pointers. The `receive` guard moved to §4.3, where `receive` is taught.
4. **Done 2026-09-24: the error model gets a section of its own:** a value, a message, or a
   fault, and nothing is caught. It is §6, *Handle failure*, after process lifetime, since a
   fault is observed through `monitor`; the sections after it moved up by one. Each of the
   three has a complete program that the test runs, and the rules on faults that were in
   §3.4 and §5.2 are said there once. Step 6's supervision joins it.
5. **Done 2026-09-24: every fragment completed or cut.** An expression became a shell
   session the test replays, a declaration a complete module, and a signature the shell's
   `:type`; blocks naming one file are its parts, and a console may run `ern --test`. The
   guide test checks 57 examples. Two blocks wait, `Down` and `Reason`, and `RemoteError`,
   on `:doc` for the prelude, MVP 2.6 checkpoint 4; §8.5's Erlang helper, which waited on
   loading an Erlang module of one's own, is complete since that was built the same day.
   Completing them found and fixed two defects: the
   prompt took a name alone in a `let`, where §11.2 makes it a block `let` with a pattern,
   and a pure callback given to `spawn` was reported as "process code called from a pure
   function". Split from the running example on 2026-09-24.
5b. **Done 2026-09-24: one running example through §2 to §5**, a word counter: values at
   the prompt, functions in `words.ern` tried in the shell, a tally process, and workers
   that count at once under a monitor, closing the guide's sections 2 to 5, each checked by
   the test.
   A block headed `// words.ern, continued` adds to the file as it stood, and a console of
   `ern --shell words.erc` is a session with the module loaded. Writing it found that the
   shell refused a file without `main`; §11.2 now loads such a file and spawns nothing.
6. **Done 2026-09-24: supervision and "let it crash"**, §6.4: a supervisor in fifteen lines
   of spawn, monitor, and receive that runs a worker per job, reports the job that faulted,
   and goes on; state that must survive lives in the supervisor, a restarted service has a
   new address to hand out, and a link is a monitor that returns. MVP 2.66 still decides
   whether a supervisor becomes a library behaviour.
7. **Done 2026-09-24: the tools and a bridge.** The guide's section 9 puts `ernc`, `ern`,
   the shell's commands and keys, and the Emacs mode on one page, teaching report §11; its
   section 10 says what an Erlang programmer keeps and what differs, from typed mailboxes to
   the absence of links, atoms, and exceptions. The FAQ and the reading list moved on,
   to the guide's sections 12 and 14 after step 8.
8. **Done 2026-09-24: the small things.** The Plauger aside left §2.3 for a closing section,
   the guide's section 11, on the five principles; the exercises' answers stand apart in its
   section 13, each naming its exercise; §5.5's game takes `Tick(Int)` from `Clock.alarm`,
   so the section has one `Tick`; and §0 maps the whole guide, not only its stages.
9. **Done 2026-09-24: §4 to §8 and the FAQ cut to teaching weight, and read cold.** The
   sections step 3 did not reach lost a third of their words, and one register holds
   throughout. A reader new to Ernest then read the guide alone and reported where they got
   lost; the fixes: the rule for `with Never` against `with m` moved from the FAQ to the first section,
   with the entry process named and one convention for `main`; reading input got a subsection of its own;
   `compare` for a type of one's own, the `=` and `!` marks, a queue that keeps pending
   replies in waiter processes, and how new code reaches a running process are shown; a
   positional constructor takes one value; the teaser's names are pointed forward. Three
   findings went further than the guide: `:type` of a name loses its variable names
   (decided, MVP 2.6 checkpoint 4), a program has no command-line arguments (MVP 2.65),
   and a type's members cannot come in a later input than the type (feedback item 17).

---

## MVP 2.65 (the language and the toolchain read back after the shell), about four days

The shell is the first program of size written in Ernest by the people who designed it, and
what it felt is in [`language_feedback.md`](language_feedback.md), which owns that list.
This item decides each entry rather than collecting it: the language questions first, field
selection at their head, then what belongs to Appendix E, then the names of the toolchain's
options, then what is recorded and left alone.

- **Arguments to a program**, `docs/language_feedback.md` item 16, found 2026-09-24 by the
  guide's cold read: an entry point takes no arguments (§8.1), and nothing gives a program
  the command line it was started with, so every program has its inputs written in or read
  from standard input. Built here, report first. The leading shape, 2026-09-24: the
  standard library gives the arguments as `Sys.args : List(String)`, ambient as the other
  `Sys.*` references are, since they are a value the runtime holds and fixes at start
  (E.0 rule 1), and one way in keeps principle 2; an entry point that takes a
  `List(String)` is weighed against it and would change §8.1, `--main`, the shell's
  entry, and `ern --test`. Parsing options from the list is policy, a library outside
  the standard library by E.0.
- **Each entry is judged on §0's five principles**, and a standard library entry on E.0's
  four rules, one by one and in writing. The note's last entry asked two of E.0 itself: rule
  1's second clause, the library's only opening for an argument from performance, went on
  2026-09-23 with `List.sort` written in Ernest; `path.ern`'s shims over string surgery are
  explained in the note and decided here. How many sites in the shell felt it is an argument,
  never the gate.
- **Every entry ends in one of three things:** a report change, made before any code; an
  entry in the log under "Later" stating the verdict and what would change it; or a line
  saying it was weighed and left alone. Nothing is left open, since the next program will
  feel the same things and a second collection is not a decision.
- **The two candidates the note puts forward** are field selection, `s.upper`, with three
  witnesses in the shell and Gleam's totality rule to copy — a field read with a dot when
  every constructor of the type has a field of that name and type — and, tentatively, some
  way to name a prelude constructor a module has shadowed. Against the first is principle 2,
  a pattern already reading a field; for it, that Ernest took `..` for update from the family
  whose readers expect `.` for read. The report changes first if it is taken: §3.5 for the
  rule, Appendix A for the production, §11.5 for what a selector on an absent field says.
- **A standalone reading of the report, 2026-09-23**, as a Wirth report and against §0.
  Its errors that asked for no decision are fixed. Its other issues are decided one at a
  time, and each decision is listed here as it is made:
  - A statement other than a block's last has type `Unit`, and a value is discarded with
    `let _ = e` (§5.4). The shell refuses an input whose value or `let` carries a reply
    (§11.2), which it had never enforced.
  - `Ets` leaves the standard library for `libs/ets`, the first library: a table is state
    processes share, which §10 and E.0 rule 1 refuse the standard library. Its section of
    Appendix E goes, and with it the checker's special case for `Ets.Table`'s key (§3.10).
    `ernc` takes `--load-path`, so a program compiles against a library's interface
    (§11.1). The webserver keeps its sessions in a process that owns a `Map`.
  - A fault is a death with `Fault(cause)`; `Killed` and `ProgramEnd` are not faults
    (§6.9, §7.3), and every cause is listed in §7.4. A deadlock is the entry process's
    fault, `Fault("deadlock")` (§8.6), and `ern` reports `fault: deadlock`.
  - `remote` catches nothing: a fault in its callback faults the caller with the same
    cause, and a resolution failure faults it as `spawn(Peer(...), ...)` does. `PeerLost`
    means only that the peer was lost (§6.7, §8.7). `remote` is MVP 3's; today it returns
    `Left(NoRemotePeer)`, so only the report and the example changed.
  - `Prelude` names the prelude's namespace, so `Prelude.Close` reaches a prelude name a
    module has shadowed (§4.2). It takes one name, and no module or type takes `Prelude`.
    This decides the second of the two candidates above; field selection remains.
  - Types are inferred except where an operator's operand type must be named (§0, §3.9,
    §4.8); "full inference" is no longer claimed.
  - The shell's second reload of a module ends the processes still on its oldest version
    with `Fault("its code was unloaded")`, and §6.10 says the shell never changes a
    running process's code (§7.3, §7.4, §11.2). The limit is the BEAM's two versions of a
    module, and MVP 3.1 lifts it.
  - A parenthesized right-hand side of `|>` is a value, applied to the left: `x |> (f(a))`
    is `f(a)(x)` (§5.7), where it was `f(x, a)`.
  - A time below 0 is 0 in `after`, `Address.call`, and every library function that waits
    or delivers later (§6.3, §6.6, E.0 rule 8). Each had faulted with the host's error, and
    a negative `Clock.alarm` crashed the clock.
  - A type's hash includes its qualified name, so the wire means what the checker means
    (§8.7), as `code_distribution.md` section 3.4 has it; §8.7 had also called identity
    structural. "Code version" is now the hash of a binding's definition.
  - `parallelRemote` leaves the prelude: several `remote` calls run at once from processes
    of their own, which the guide shows (§6.7).
  - `Erl.Result` leaves the standard library: a shim's Erlang helper rewrites `{ok, V}` and
    `{error, R}` to `Either` (E.19).
  - The bit syntax drops `bits` and `native` (§5.11, Appendix A): `Bytes` stays octets, so
    `bits` was `bytes` with another unit, and a byte order is stated or converted at the
    foreign boundary.
  - A `String`'s unit is named a grapheme in E.5, the module and the guide; "character" is
    left to §2.5's lexical grammar.
  - Weighed and left: a remote `send` that fails to resolve faults the sender later, and
    `Tcp.write` is a send. E.18 now says where a failed write shows, and §8.7 what a faulting
    initializer does on a peer.
  - §9 states what makes a type the prelude's: the language's rules name it, its module is
    named after it, or a system reference speaks it. The system types stay in the prelude;
    moving them would take `Sys.*` with them. This decides language_feedback.md's entry 12.
  - `Float.pow` returns `Optional(Float)`: `None` for a negative base with a fractional
    exponent and for zero to a negative power, a fault on overflow (E.9).
  - §8.2 and §11.2 read as short paragraphs under run-in headings, as §11.1 does, and the
    terminal's lines-and-keys fault joins §7.4's list.
  - §3.9's effect polymorphism is four paragraphs and E.0 rule 6 three sub-items.
  - Module acyclicity moves from §11.1 to §4.1, and the `receive` guard's restriction from
    §5.9 to §6.3.
  - §4.2 says a function's mailbox type is exempt from the private-type rule, where it said
    "the effect of a function aside"; §7.2's sentence that stated no rule is cut.
  - E.0 rule 2 states its no-synonyms constraint instead of requiring a log entry.
  - An input that reads a line under the shell faults with the subscriber's cause, as §11.2
    said; it had ended the program at a terminal and taken the shell's line in line mode.
  - `Event`'s typed character is `Key(Char)`, where it was `Char(Char)` (§9.3).
  - Weighed and left: `with` for both a mailbox and an abstract type's signature.
  - `Clock.alarm` and `alarmAt` deliver the time the alarm fired, so a constructor passes as
    the wrap (§9.3, E.15).
  - `a<-1` is `a <- 1` by max-munch; §2.6 gives the example, and the parser's error says how
    to write the comparison (§11.5).
  - A last reading of the whole report after the day's changes closes the review; it found
    seams, no new rule. The review is done.
  - **Done 2026-09-24, before the outside reading:** §6.6 rewritten top-down, the rules unchanged. It
    opens with the rule a reader needs first, that a `Reply`, and any value that contains
    one, is used exactly once on every path, by `answer` or by a use that hands the
    obligation on; then which types contain a reply, where such a value may not go, how
    branches share the obligation, and one accepted and one rejected example side by side.
    The report stays one document: splitting out the ABI and the toolchain was weighed
    against the single source of truth and refused.
- **The names of the options to `ernc` and `ern`.** Both tools grew their options one MVP at
  a time and the set has never been read whole. Under review: the three words for a
  directory, `--source-root`, `--out-dir`, `--config-dir`, `--load-path`, and whether the
  rule that tells them apart is worth stating; the options that are modes rather than
  modifiers, `--doc`, `--test`, `--emit`, `--shell`, `--create-config-dir`, and whether a
  mode is a subcommand; `--create-config-dir`, a whole job in an option's clothes that names
  the same directory as `--config-dir`; `--no-clean`, the only negative; and `--errors
  short`, a value option with one value. The names are in §11.1 to §11.4, so each is a report
  change and worth deciding once.

---

## MVP 2.66 (a supervisor, or the argument that none is needed), about three days

The claim has stood since 2026-09-13 and has never been tested: a supervisor is fifteen
lines of `spawn`, `monitor` and `receive`, so Ernest needs no behaviour for it. This item
tests it by writing one, and decides what it should be, if anything.

- **Not in the language.** §6.9 gives monitors and no links, and §0's fifth principle keeps the surface
  small; a behaviour would be a second way to structure processes beside the three
  primitives. Nothing here proposes a report change.
- **Not in the standard library either, by E.0 rule 3.** A supervisor is policy and almost
  nothing else: which strategy, how many restarts in what time, in what order children stop.
  Rule 3 refuses a function whose result depends on a choice the library makes for the
  program. If it is written at all it is a library under `libs/`, on Appendix D's pattern,
  where a program that disagrees writes its own.
- **The experiment first:** `examples/supervisor.ern`, a supervisor of three workers with
  restart on fault and a restart-intensity limit, written with nothing but `spawn`,
  `monitor` and `receive`, and read back against the claim. If it is fifteen lines and reads
  as a program a person would write, the answer is the guide's idiom section and no code. If
  it is sixty and every program would write the same sixty, that is the argument for
  `libs/supervisor`.
- **Two things it will run into, and they are the content of the discussion.**
  - **A restarted child has a new address, and §6.5 has no registry**, so nobody who held
    the old one can reach it. A supervisor that restarts children is therefore a name
    service for them, or its children are unreachable after the first fault. This is the
    same hole the node protocol note's open question 8 names, and it is queued for MVP
    2.65; the supervisor is the second witness for it.
  - **Stopping a child needs `kill` or a protocol message.** `kill` is asynchronous and
    gives the child no chance to finish (§6.9); a message means the child's mailbox type
    carries a stop case, which is the child's business and cannot be imposed by a library.
    OTP solves this with exit signals and a shutdown timeout, which Ernest refuses.
- **What no-links costs, and the idiom that answers it.** A supervisor that dies leaves its
  children running, where OTP's would take them with it. The answer within the language is
  the reverse monitor: each child monitors its supervisor and returns when it dies. Whether
  that belongs in the guide beside the supervisor idiom is part of this item.

---

## MVP 2.7 (the first libraries and the network stack), about two weeks

Appendix D has been written to once, for `Ets`, and a pattern tried once is a guess: four
libraries written to it confirm or correct it before anyone outside writes to one, and they
are the compiler's second real user. `libs/` and `build/libs/` exist since 2026-09-24, when
`Ets` left the standard library for `libs/ets` and `ernc` took `--load-path`. Being
first-party changes nothing about the tier: a library is not on the load path unless a
program puts it there.

- **Report first**, for what a command-line program needs: `Sys.args` and `Sys.env` in §8.2
  and §9.7 as runtime-bound values, an exit status in §8.6, and `Time` in Appendix E over the
  clock's milliseconds. They came back here on 2026-09-20 when the shell's colour went later.
- **`libs/json`**, pure Ernest: a `Json` type, a parser over `String` returning `Either`, a
  printer; the first test of `<-`, `tryMap` and `tryFold` at size.
- **`libs/base64`**, a shim over `base64`: the smallest there is, so Appendix D's pattern is
  written a second time before the two large ones.
- **`libs/tls`**, a shim over `ssl` and `public_key` with their manual pages open: `listen`,
  `accept`, `connect` returning `Address(SockMsg)` with the encryption inside the socket
  process, so `Tcp.read`, `write` and `close` serve both. Certificate verification is the
  caller's to ask for.
- **`libs/http`**, Ernest over `Tcp` and `Tls`: request and response types, a client. No
  server; that is the webserver example's job.
- **The paper program:** `examples/fetch.ern`, a command-line tool that fetches JSON over
  HTTPS and prints a report, errors to stderr, with an exit status. A paper program travels
  with the stack it needs; MVP 2.5 taught that a program which only compiles proves little.
- **Each library** is an Ernest source root under `libs/<name>/` that a program adds with
  `--load-path`, with `stdlib/`'s test discipline, a README of its own, and no entry in
  Appendix E. Own repositories later, when there is a package story.
- **The report lists them** in a new informative appendix, one section per library with its
  signatures and contracts, and a mirror test holding each compiled interface equal to it, as
  `ern_prelude_tests` holds the prelude to Appendix E. Third-party libraries are not listed;
  Appendix D is what they follow.

---

## MVP 2.8 (four more libraries), about two weeks

`libs/regex`, a shim over `re`, a library and never syntax: `Regex.compile : (String) ->
Either(RegexError, Regex)` with `Regex` a foreign type, so a bad pattern is a value the
program handles, as Gleam's `gleam_regexp` does. `libs/crypto`, a shim over `crypto` for
hashes, HMAC and random bytes, the key and cipher surface waiting for a program. `libs/uri`,
pure Ernest or a shim over `uri_string`. `libs/zlib`, a shim over `zlib`. Each is written and
documented in one pass to [`module_doc_template.md`](module_doc_template.md), and its
executed doc examples are its first user, so no paper program is required (decided
2026-09-19). Each gets an appendix section beside 2.7's four.

---

## MVP 2.9 (an Emacs major mode), done 2026-09-23

Taken out of order, between checkpoints of MVP 2.6. [`emacs_mode.md`](emacs_mode.md) owns
the mode and [`decisions.md`](decisions.md) the arguments. `emacs/ernest-mode.el`, its tests
under `emacs/test/`, run by `make emacs-mode` and last in `make test`.

Two decisions of the milestone reach beyond it:

- **`docs/style.md` gained four indentation rules**, and the seventeen sources that held a
  construct two ways were reindented to them: indentation is a step and never an alignment;
  `else` returns to the line its `if` begins on; a broken signature continues one step in; a
  clause bar sits two spaces left of its arms.
- **A review the same day found the mode had placed lines against the guide**, and the
  sources had been reindented to follow it: a line opening with an operator never carried
  on, `|>` was taken for a clause bar, and a `then` leading a line fell to the block's
  column. Eleven lines in four sources were moved back to the guide, whitespace only.
  `docs/style.md` gained two rules: a line opening with a binary operator is one step in,
  and `then` returns to the line its `if` begins on, as `else` does.
- **The mode's word and operator lists are mirrored** by
  `emacs_mode_mirrors_the_lexer_test` in `test/ern_style_tests.erl`, since they restate
  Appendix A.

---

## MVP 3.0 (peers), about three weeks

Designed in [`node_protocol.md`](node_protocol.md), which owns the protocol: node identity
as the hash of the TLS key, incarnations, addresses, spawning, monitors, ordering,
connections and the wire encoding. It is marked tentative, and it is written against an
older spelling of the language; the report changes it implies are listed at the end of this
section and are decided before any of it is built.

Nodes that reach each other and the four operations of §8.7 between them, with code shipping
restricted to nodes running the same build: identical definitions have identical hashes,
which is §8.7 in its easiest case. A peer whose build differs is refused with an error naming
3.1. Split from 3.1 on 2026-09-20, since content addressing proper is the larger half and
peers are the useful one.

- `spawn(Peer(name), f)` and `remote(f)` over the peers in `ernest.conf`, authenticated with
  the configured keys: the connection is `ssl` with the peer's public key from `ernest.conf`
  as the only trust, read with `public_key`, inside `ern`, and a program never sees either
  module. `remote` picks among peers flagged `"remote-peer": true` by load, criterion chosen
  then.
- Peer loss as §10 says: every process on the lost peer dead with `Fault("peer lost")`,
  monitors delivered, pending `remote` calls `Left(PeerLost)`; a peer that reappears is a new
  instance.
- **What the protocol note asks of the report**, each to be decided before it is built:
  `Down` gains `Unreachable` and a cause for an address that never had a process, since a
  watcher must tell a lost connection from a death (§9.3, §6.9); §6.4 gains that what
  arrives is an unbroken prefix of what was sent and that a sender is told nothing of a
  drop; and the note's `spawn_at(node, f)`, `MonitorRef` with `demonitor`, and a name
  registry are surface the report does not have — `spawn(Peer(name), f)` is one primitive
  with a placement argument (§9.4), `monitor` is one message and no handle (§9.5), and
  §6.5 refuses a registry outright. The registry is the one of these that is a language
  question rather than a protocol question, and it belongs with MVP 2.65's list: without
  one, a service another node started cannot be reached, since only spawning or being sent
  an address gives you one. The note's open question 11, a way to stop an uncooperative
  process, is already answered: `kill` is the language's (§6.9), asynchronous, and a killed
  process's monitors see `Killed`; across nodes it needs a frame the note's table lacks.
- **Where the two notes disagree with the report, found 2026-09-24**, also to be decided
  before building: the protocol note encodes values in Ernest's own format where §8.4 uses the
  runtime's external term format; both notes drop a payload whose code cannot be fetched or
  resolved where §7.4 and §8.7 fault the caller or the sender; the distribution note hashes no
  name where §8.7's normalization keeps the qualified names of external references; both write
  the effect `{Proc m}` where the report writes `with m`; and the protocol note's open question
  on stopping a process is §6.9's `kill`.
- **Whether `remote` stays**, `docs/language_feedback.md` item 14, decided first in this
  milestone, before `remote` is built over peers: once `spawn(Peer(name), f)` ships code and
  answers across nodes, `remote` may be a second way to do what a spawned process that
  answers does. If it goes, §6.7, §9.4, `RemoteError`, the `"remote-peer"` flag and the
  guide's §8.1 go with it, and the bullets above that build it are rewritten.
- **Two more places the protocol note disagrees with the report, found 2026-09-24 in the
  closing sweep of MVP 2.61**, also decided before building: the note's `spawn_at` never
  fails at the call and returns a dead address, where §6.2 faults the caller on an unknown or
  unreachable peer; and the note's `Down` is `Exited | Crashed(Text) | NoProcess |
  Unreachable` with no `function`, where §9.3 and §6.9 have `Down(reason, function)` with
  `Returned`, `Killed`, `ProgramEnd` and `Fault(String)`.
- **An adapted address across a node** is open, and report first when it is taken. `via(f,
  addr)` has been the pair of the function and the address since 2026-09-20 (§6.5), so an
  `Address` that leaves a node may carry a function, which is the same question as a message
  that carries one. Whether the function travels or the adaptation stays behind is the
  decision.

---

## MVP 3.1 (content addressing), about four weeks

Designed in [`code_distribution.md`](code_distribution.md), which owns it: what is hashed,
names as a build product, the loader beside `code_server`, have/want before every message,
the trust model, and the atom-leak restart. Marked tentative, and two things in it meet the
code as it stands. Its section 11 asks MVP 1 for a named IR stage with locals numbered by
position: there is none, since `ern_emitter` goes from the typed AST to Erlang's abstract
format in one traversal, so the choice is to introduce an IR here or to canonicalise the
typed AST, which is the decision below either way. Its section 3.4 hashes every declared
type nominally, name included, which §8.7 says too since 2026-09-24; but it hashes an
abstract type as it hashes any other, where §8.7 adds the signature to an abstract type's
hash, and the note is brought to §8.7 before it is built. Its section 6 runs nodes in
embedded mode, which loads nothing from the code path on demand, where §11.2 since
2026-09-24 finds a `foreign fn`'s own Erlang module on the load path; which of the two a
node running hash modules does is decided here, report first.

Hash modules never change, so versions coexist on a node for as long as a process runs one
([`code_distribution.md`](code_distribution.md) section 8). The shell's reload then ends
nothing: §7.3's unloading cause, §7.4's `Fault("its code was unloaded")`, and §11.2's
second-reload rule go in this MVP, with the test that pins them.

§8.7's identity in full. The first decision is what "normalized definition" means, since two
nodes must agree exactly: the typed tree or the untyped one, whether local names are erased,
and what becomes of the effect variables, which are inferred and never written.
`ern_emitter:iface_hash/1` already hashes a canonical interface; whether it grows into the
definition hash or a second scheme stands beside it is part of that decision, and the cheaper
answer is the first.

- Every definition gets a hash of its typed AST; modules are named by hash; a registry per
  node `{Hash -> Module}`. A message with a function carries the hash, and a node that lacks
  it fetches the code from the sender. Erlang's module distribution is not used.
- Two nodes with different versions of one type: reject at send, each message carrying its
  type hash; fetch on receipt is the alternative, decided when peers exist and the two can be
  measured. The log has both shapes.
- The library fetcher, decided 2026-09-19: `ern fetch name url` fetches a library's source
  tree from a git URL into a directory on the load path, compiles it, and records the hashes
  of its definitions. No resolver, no semver, no lockfile beyond those hashes, and no
  registry; discovery by name is a tooling question for later.

---

## Not in any MVP

A canonical formatter, `ernc --format`, one style and no configuration, mechanical over the
grammar; it lands before a second person writes Ernest. `Slot(a)`, a one-shot credit parallel
to `Reply(a)`, is out on principles 2 and 5; the log holds its shape if the verdict is
revisited. String interpolation is declined for now on principles 2, 3 and 4. Erlang
scheduling hints wait for a program that needs them. No HTTP server, ever, and no database
connectors: those are libraries for others to write on Appendix D's pattern.

---

## Standing gaps

- **§3.11, §8.3 and §8.7 have no citing test**, which `make sections` lists. All three are
  MVP 3.0 and 3.1 material and unimplemented; anything else that appears there is a gap.
- **How the region measures a wide character.** A tab is settled — painted as the spaces to
  the next stop of eight — but a wide glyph is one column to the region and two to the
  terminal, and nothing in the runtime knows a glyph's width. `expand` in
  `shell/shell/region.ern` is the one function that has to learn it. The design note's only
  open item.
- **`e_bits` and `p_bits` are in no example**, so the AST coverage test excludes them
  (2026-09-19).
- **A label at the first use of the variable whose type a mismatch names** was planned for
  §3.4's placement work and not built (2026-09-18).

---

## Done

### MVP 1 — the chain (done 2026-09-18, tag `mvp1`)

Prove parser, types and BEAM with the report's language unchanged, accepting a subset: `Int`
but no `Float`, no ownership rule for abstract types, no foreign code, no `Tcp`, no
distribution. Exhaustiveness checking was in from the start, being the check that shaped
`receive` and `if`. What still binds:

- **A hand-written lexer and a direct precedence-climbing parser** over a token list, no yecc
  and no generic Pratt engine: the hand parser is the executable test of principle 4. Tokens
  are yecc-shaped, `{Category, Pos, Value}`, with `Pos` carrying the token's end and the
  previous token's end so the parser can close every node's span. Three places need one more
  token: the constructor-fields peek, `FnType` against `ParenType`, and `fn` before an
  identifier or `(`. No backtracking.
- **Hindley-Milner with an effect slot**, §3.9: the arrow is `Arrow(args, E, result)`, the
  slot holding `pure`, a mailbox type, or an effect variable; unification is component-wise;
  an effect variable that also occurs in a value position or belongs to a process primitive
  is *process-only* and does not unify with `pure`. A free effect variable generalizes, which
  is what lets `List.map` run a process callback. The only departures from the textbook are
  `pure` as a non-type in the slot and that flag.
- **The reply discipline**, §6.6: a reply-carrying value is consumed exactly once on every
  path from its binding, the obligation passing through patterns, blocks and constructors;
  compiled interfaces carry it. `Address.call`'s `mk` callback is the canonical case.
- **Local `fn`s generalize late**, once every later local `fn` they reference has been
  checked, so `fn a(x) = b(x); fn b(x) = x + 1` does not accept `a("s")`.
- **One Erlang module per Ernest module**, `ern@` and the path with `@` for `/`, functions
  keeping their local names and type members their prefix (`'Stack.push'/2`). The reasons for
  the name are in the log's *One Token for the Project*.
- **Three pre-passes inside the emitter's one traversal**: unique variable names, lambda
  lifting of local `fn`s with their free variables as leading parameters, and the `<-`
  desugaring of §5.5 from the type the checker left on the node.
- **Diagnostics**, 3.4 below and §11.5: one `#diag{span, message, labels, help}` from every
  stage and one renderer, `ern_diag`; `ern_typecheck:check/5` pushes an expected type into
  `if` branches, `match` and `receive` clauses and a block's last statement, so a mismatch is
  reported at the leaf, with the origin as the label. No colour until an editor renders
  through an LSP; no error codes.
- **Testing**: the MVP 1 programs are the `PROGRAMS` macro in `test/ern_integration_tests.erl`
  and the golden set; `test/golden/*.erl` holds the Erlang the emitter writes, rewritten by
  `make golden`; `test/target/*.erl` holds the two hand-written targets, the only tests that
  are not self-referential. Output is compared as a multiset of lines, since interleaving is
  scheduling-dependent.
- **The report was pared** on 2026-09-18, 13,084 words to under 8,000 in one pass, and read
  back on 2026-09-19: the paring had lost five rules and compressed 86 sentences past easy
  reading, all restored. The standing rule since: a change is made inside its heading, in the
  report's register, clear before short, and a section past 600 words is read for restating.

### MVP 2 — the rest of the report on one node (done 2026-09-19)

Each item was a rule MVP 1 refused or did not check; the README's table named the refusal it
lifted. In the order worked, with what the log's entries explain in full: `Float` and
operators on user types, resolved during inference from the operand type (§3.1, §4.8, §5.1);
`foreign fn` and `foreign type`, the check a descriptor term the compiler builds and
`ern_boundary` interprets, with a checking proxy standing in front of every Ernest address a
foreign function is given (§4.7, §8.4); bitstrings, with `ern_bits` checking each value
against its width (§5.11); pattern alternatives (§5.9); `Io.debug` printing by the argument's
type through `ern_show` (E.1); raw strings (§2.5); abstract-type ownership (§4.4); the reply
discipline through function values, narrower than planned — a lambda is reply-carrying as a
value, and a reply-carrying function *type* is not taken (§6.6); `Deadlock` as global
quiescence rather than a wait-for graph (§8.6); and nine points from the consistency pass of
2026-09-19.

### MVP 2.5 — a complete standard library (done 2026-09-20)

Twenty-one modules in Ernest, every system door open, four paper programs written and three
under test, documentation in the `.erc`, and the manual terminal check made. Appendix E is
the shape and E.0 the rules; **a shim exists only where E.0's first rule admits it**, which
is a standing rule and not a milestone. The steps, in the order done:

0. **The shape of a module's documentation**, 2026-09-19, first because every module after it
   is written to it: [`module_doc_template.md`](module_doc_template.md) is generated from
   `examples/template.ern` and two tests keep them equal, type-check its examples, and run
   every example ending in `// => v` against `Io.debug`'s rendering. §2.2 and §11.4 say what
   a doc block is and what `ernc --doc` emits.
1. **Report first**, 2026-09-19: E.19 `Erl`; §4.2's exception for the standard library's own
   source root; the `Test` and `TestResult` types in §9.3; and the layout, `stdlib/*.ern`
   with its Erlang halves in `erl/runtime/src/` and its ABI tests in `erl/runtime/test/`.
2. **The checker reads the standard library's compiled interfaces** as it reads any
   dependency's, 2026-09-19, which shrank `ern_prelude` to §9. `ern --test` runs every
   top-level `Test` in the modules it is given (§11.2).
3. **Appendix E rewritten module by module**, pure modules first, each done when its Erlang
   original is deleted with the ABI tests and `ern --test` green. `Map` and `Set` stay over
   Erlang's `maps`, which share structure on update. Read-backs of the first modules changed
   the language: based literals and digit separators (§2.5), no negative zero (§3.1), the
   not-reply-carrying mark not inferred on a container's element (§3.9), and the module of a
   built-in type declaring its own operators (§4.8).
4. **The system processes**, 2026-09-20: `Sys.stdin`, `Sys.fs`, `Sys.keys` and `Sys.tcp` as
   runtime processes bound by the launcher, each speaking its §9.3 type and used through its
   Appendix E module, never by `send` (E.0 rule 8); `Ets` under `stdlib/` as Appendix D has
   it, moved to `libs/ets` on 2026-09-24. `Tcp` is processes first: every socket is a process, so `monitor`, `kill` and `via`
   accept it. **Measured** with `examples/echo.ern`: 2,000 round trips over loopback take
   160 ms through socket processes against 90 ms in raw Erlang, 35 µs a round trip, 1.8
   times raw — the verdict is to keep the processes; a foreign fast path stays available
   under E.0 rule 1 if a program ever shows it matters, and `read` would move socket
   ownership between processes, which principle 3 refuses. Writing the paper programs found
   three defects, one of them in the report (E.17 now says what an `Entry`'s path is). Two
   terminal defects went into §8.2: raw mode set with `stty` on an inheriting port, and an
   escape alone for fifty milliseconds being the key. `snake` stays compiled-only and was
   checked by hand, since no test can press a key.
5. **What "complete" means beyond that**: Erlang's standard library read module by module on
   2026-09-18; the table is under "Reference". A function enters Appendix E when E.0's rules
   admit it, report first; nothing waits for a program to ask.
6. **Documentation in the `.erc`**, 2026-09-20: `ernc` writes each module's doc blocks and
   each function's parameters as written into EEP 48's `Docs` chunk, so `code:get_doc/1`
   reads an Ernest module and `ernc --doc` on a compiled module reads the chunk. §11.1 and
   §11.4 say so. The shell's `:doc` and `Shift-Tab` depend on it.

**The naming of the toolchain**, a detour between steps 4 and 5, done 2026-09-20: every
Erlang module `ern_<thing>`, every compiled Ernest module `ern@<namespace>`, `lib/` became
`erl/`, the standard library's Erlang half joined the runtime, and two wrong names were fixed
(`ern_compiler` to `ern_emitter`, `ern_check` to `ern_boundary`). The rule is in the style
guide, the record in the log's *One Token for the Project*.

---

## Reference

### The emitter's two tables

Decided before the emitter was written and kept as its specification; the code is the truth
now, and these are what a change to it is read against. Values follow §8.4 throughout. Types
are erased: `type_decl`, `abstract_decl`, `foreign_type_decl`, `signature`, `field` and the
`t_*` records produce no code, the interface chunk carrying them.

| Record | Erlang |
|---|---|
| `constructor` | nullary: the quoted atom; positional: `{'C', V}`; named: `{'C', V1, ..., Vn}` in canonical field order |
| `fn_decl`, top level | a function clause; exported if `export`; a type member is `'Stack.push'` |
| `fn_decl`, in a block | lifted to a module function with its free variables as leading parameters; the name is bound to a closure over them |
| `let_decl` | `name/0`, reading a value the module's `'$init'/0` computed once in dependency order before `main` (§8.5) |
| `foreign_fn_decl` | a clause calling the named `M:F/A` |
| `param` | the pattern in the clause head |
| `e_lit` | integer, float, or char literal; string as a binary; bool as an atom |
| `e_var` | a local: the Erlang variable; a top-level fn as a value: `fun f/N`; a top-level let: `name()`; a prelude name: table below |
| `e_con` | as `constructor`; a single-positional constructor as a value: `fun(V) -> {'C', V} end` |
| `field_set` | its value at its canonical position |
| `e_tuple`, `e_list` | tuple, list |
| `e_bits`, `bit_seg` | bit syntax, each value checked by `ern_bits` |
| `e_block` | a sequence; `binding` with `=` as `Pat = Expr`; `binding` with `<-` as a `case` on `Left`/`Right` or `None`/`Some` with the rest of the block in the second clause (§5.5) |
| `e_call` | `F(Args)` for a local; `f(Args)` or `'ern@m':f(Args)` for a known function; a prelude name: table below |
| `e_neg` | `-E`; on `Float`, `0.0 - E`, so that no negative zero arises (§3.1) |
| `e_binop` | `Int`: `+ - * div rem` (`/` is `div`, `%` is `rem`; a zero divisor's `badarith` becomes `Fault("division by zero")`); `<>`: binary append for `String` and `Bytes`, `++` for `List`; `==`, `!=`: `=:=`, `=/=`; `<`, `<=`, `>`, `>=` on `Int`, `Float`, `Char`, `String`: the native operators, since binaries compare by code point; `&&`, `\|\|`: `andalso`, `orelse`; `::`: `[H \| T]` |
| `e_lambda` | `fun(Pats) -> Body end` |
| `e_if` | `case C of true -> T; false -> E end` |
| `e_match`, `clause` | `case`; a clause whose guard is not an Erlang guard expression falls through by a continuation: `Rest = fun() -> <remaining clauses> end`, so no code is duplicated |
| `e_receive`, `after_clause` | `receive ... after T -> B end`; a receive guard is §6.3's guard expression and is emitted as an Erlang guard |
| `p_wild`, `p_var`, `p_lit` | `_`, a variable, a literal (a string as a binary) |
| `p_con`, `field_pat` | as `constructor`, an omitted named field as `_` |
| `p_tuple`, `p_list`, `p_cons` | tuple, list, `[H \| T]` |
| `p_as` | `Var = Pat` |
| `p_bits` | bit syntax |

**Prelude name to Erlang** (§9.4 to §9.7, Appendix E). Called, or taken as a value with
`fun M:F/A`.

| Name | Erlang |
|---|---|
| `self` | `ern_rt:self/0` |
| `send`, `answer`, `via`, `monitor`, `kill` | `ern_rt:send/2`, `answer/2`, `via/2`, `monitor/2`, `kill/1` |
| `spawn` | `ern_rt:spawn/3`, the third argument the spawn site for `Down` (§6.9) |
| `Address.call`, `Address.callForever` | `ern_rt:call/3`, `call_forever/2` |
| `remote` | MVP 3; until then `ern_rt:remote/1` answers `Left(NoRemotePeer)` |
| `Int.+` and the other `userop`s on `Int`, `Int.negate` | the inline operators above |
| `Float.*` | inline, the operands bound first and the operation's own `badarith` caught and raised as the §7.4 fault |
| `String.<>`, `List.<>`, `Bytes.<>` | inline as above |
| `Int.div`, `Int.mod`, `*.compare`, `Int.toString`, ... | `'ern@int':'div'/2` and so on: the namespace's module |
| `todo` | `ern_rt:todo/1`, which faults with `todo: ` and the text |
| `Sys.stdout`, `Sys.clock`, `Sys.stdin`, `Sys.terminal`, `Sys.fs`, `Sys.tcp` | `ern_rt:sys(stdout)` and so on; `Io`, `Terminal`, `Fs`, `Tcp` are the namespaces' modules |
| `Clock.*`, `Path.*`, `Random.*`, `Io.*`, `List.*`, ... | `'ern@clock':alarm/2`, `'ern@io':println/1`: the namespace's module |

### Erlang's standard library, read module by module (2026-09-18)

Every user-facing OTP module is a row; what is not a row is OTP's own machinery, which
Ernest's concepts or toolchain replace.

| Erlang | Ernest | In Appendix E | Waiting, and when | Out, and why |
|---|---|---|---|---|
| `erlang` BIFs | the language; `Int`, `Float`, `String`, `Char` | `spawn`, `self`, `send`, `monitor` as §9.4 and §9.5; `abs`, `min`, `max`, rounding, `toString`, `toFloat`, the bit operations | an exit status for §8.6, `Sys.args`, `Sys.env`, MVP 2.7 | `register`, `whereis`: §6.5 has no registry. `link`, `exit`, `throw`, `catch`: §7 and §6.9. `term_to_binary`: MVP 3's transport. `phash2`, `md5`: a hashing library. `make_ref`: identity is a `Reply` or an address. `iolist_to_binary`: `String.fromList`, `<>`. `memory`, `system_info`: the runtime's |
| `lists` | `List` | E.2, thirty-one functions and `<>` | | `first`, `rest`, `flatten`, `count`, `map2`, `sum`, `max`, `min`: one pipe each, rule 4. `scan`, `mapFold`, `window`, `chunk`: a `foldLeft` with an accumulator, and each hides a choice about the ends. `permutations`, `transpose`, `combinations`: specialities. `key*`: `Map` |
| `maps`, `dict`, `orddict`, `gb_trees`, `proplists` | `Map` | E.3 | | the four alternatives: history |
| `sets`, `ordsets`, `gb_sets` | `Set` | E.4 | | `symmetric_difference`, `is_disjoint`: compositions |
| `string`, `unicode` | `String`, `Char` | E.5, E.6 | | the list-based half of `string` |
| `io`, `io_lib` | `Io` | E.1: `print`, `println`, `printError`, `printlnError`, `debug`, `readLine` | | `format`: no format strings, `<>` and `toString` are the one way |
| `file`, `filelib` | `Fs` | E.17, nine functions | `watch`, and the working directory with absolute paths, MVP 2.7 | `wildcard`: a glob library. `fold_files`: five lines over `List` |
| `filename` | `Path` | E.14, eight functions | | `absname`, `expand`: `Fs`'s, they read the working directory. `nativename`: a `Path` is in the runtime's syntax |
| `timer` | `Clock` | `now`, `alarm`, `alarmAt` | `Clock.monotonic` | `send_interval`, `cancel`: E.15's positions. `sleep`: `receive { after ms -> Unit }`. `seconds`, `minutes`: arithmetic |
| `rand` | `Random` | E.13: `seed`, `next`, `nextFloat` | | |
| `math` | `Float` | the operators, `abs`, `min`, `max`, `round`, `floor`, `ceil`, `truncate`, `toString`, `sqrt`, `pow`, `exp`, `log`, the trigonometry | | `looselyEquals`: the tolerance is the program's. `toPrecision`: a format, and §9.6 has no format strings |
| `gen_tcp`, `inet`, `socket`, `ssl` | `Tcp` | E.18 | `Udp` as its own module, a later MVP | socket options: tuning is a library's. TLS: `libs/tls` in MVP 2.7, returning the same `Address(SockMsg)` |
| `ets` | `libs/ets` | Appendix D | | match specifications, `qlc`: `Ets` is a key-value table |
| `os` | `Sys` | | `Sys.env`, `Sys.args`, MVP 2.7 | `cmd`: a door to the system a program opens itself, MVP 3 at the earliest |
| `calendar` | `Time` | | a `Time` type and its parts, MVP 2.7 | formatting: a format is the program's, rule 3 |
| `binary` | `Bytes` | E.20, and `<>` | | `split`, `match`, `replace`, `encode_unsigned`: `<<...>>` and the `Int` operations |
| `array`, `queue` | | | | `List` and `Map` give both, rule 4; a persistent array is a library |
| `eunit` | `Test` | §9.3's `Test` and `TestResult`, run by `ern --test` (§11.2) | | |
| `base64`, `json`, `uri_string`, `re`, `crypto`, `zlib`, `dets`, `digraph`, `sofs`, `erl_tar`, `zip`, `disk_log`; the applications `ssl`, `inets`, `xmerl`, `public_key`, `asn1`, `mnesia`, `snmp` | libraries | | | each a namespace of its own on Appendix D's pattern, never stdlib |
| `observer`, `dbg`, `cover`, `debugger`, `dialyzer`, `edoc`, `common_test`, `syntax_tools`, `parsetools`, `argparse`, `escript` | | | | tooling: `ernc --doc`, Ernest's own types, the compiler, `ern`; an argument parser is a library |
| `gen_*`, `supervisor`, `proc_lib`, `sys`, `logger`, `application`, `code`, `rpc`, `erpc`, `global`, `pg`, `net_kernel`, `persistent_term`, `atomics`, `counters`, `init`, `heart`, `os_mon`, `wx`, `erl_*`, the shell | | | | a function with a mailbox type, fifteen lines of `spawn` and `monitor`, `send` to a sink, MVP 3's distribution, the runtime's internals, `ernc` and `ern` |

Gleam's `gleam_stdlib` v1.0.5, Elixir's core and Haskell's `base` were read the same way, and
what they have that this table does not take is a position, not a gap: `gleam/order`,
`gleam/pair` and `gleam/function` (patterns and compositions), `string_tree` (a builder
BEAM's binary append makes unnecessary), `gleam/uri` (a library), `dynamic/decode` (`Foreign`
and a JSON library), `string.inspect` (no universal printer), `bool.guard` (`<-`); Elixir's
`Stream` (§5.1 is strict, a lazy source is a process) and `Keyword` lists (`Map`); Haskell's
type classes (`toString` per type, `==` structural, `compare` per type).

### Tools, and what was decided before the start

Erlang, OTP 29 (raised from 27 on 2026-09-20), Makefiles, no rebar3, no OTP behaviours; EUnit
per application under `erl/*/test`, integration tests under `test/`; the toolchain shipped as
the escript sources in `bin/`, which put `erl/*/ebin` on the code path with no escriptize
step. Also decided before the start and unchanged: the `erl/` layout, one Erlang application
per stage; the error format of §11.5; one Erlang module per Ernest module.

### The MVP 1 time budget

| Phase | Parts | Days |
|---|---|---|
| 1 | parser, type inference, abstract types, standard types | 24.5 |
| 2 | compiler, processes, standard library, code generation | 9 |
| 3 | integration, tests, documentation, error placement, paring | 11 |
| **Total** | | **44.5, about nine working weeks** |

The actual: MVP 1 done 2026-09-18, MVP 2 the day after, MVP 2.5 the day after that.
