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

**MVP 2.6, the shell, its closing sweep.** Checkpoints 0 to 4 are done: the loop and the
terminal harness, bindings and the commands, the live region, the line editor with history,
multi-line input and paste, and completion and documentation. What is left of the milestone,
the sweep and a session of real use, is in "MVP 2.6" below, in order.

**Taken out of order and done:** MVP 2.9, the Emacs mode, on 2026-09-23, and MVP 2.61, the
guide as the user's document, on 2026-09-24, after which CLAUDE.md was rewritten for
clarity, every rule kept. Both are under "Done".

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
| **MVP 2.6** | **the shell** | **checkpoints 0–4 and the closing sweep done; a session of real use** |
| MVP 2.61 | the guide as the user's document | done 2026-09-24, out of order |
| MVP 2.65 | the language and the toolchain read back | after 2.6 |
| MVP 2.66 | introduce a supervisor behaviour? | after 2.6 |
| MVP 2.7 | the first libraries and the network stack | |
| MVP 2.8 | five more libraries | `libs/markdown` done 2026-09-25, out of order |
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
| 4 | completion and documentation | done 2026-09-24 |

**What is left.**

- **Checkpoint 4, completion and documentation.** Built, 2026-09-21: `Shell.Complete`, pure
  and tested, matching by prefix and by abbreviation segment by segment and filtering by what
  may stand at the cursor, types after `:`, constructors in a pattern, a constructor's
  fields; `Tab` replacing the word and indenting four spaces where there is none; a second
  `Tab` listing the candidates with their types, forty at most; a command completing as a
  word of the shell's own; `Shift-Tab` showing a name's type and first sentence, and its page
  when pressed again. **Left, in this order:**
  1. **Done 2026-09-24: the prelude's documentation.** `:doc monitor` had said "no
     documentation". Each entry of `ern_prelude`'s table now carries its documentation,
     written by E.0 rule 6: a doc string beside each built-in type and primitive, a doc block
     above each declared type in its Ernest source, and `module` on an operation its type's
     module documents, which a test checks that module does. `ern_prelude:docs/0` builds the `Docs` term
     `ern_page` renders, so `:doc`, `Shift-Tab`, and the prelude's page from `ernc --doc` of
     the standard library's root share one renderer. The doc tests type-check the page's
     examples and run those that end in `// => v`. Report §9 says the prelude is documented
     so, with no example for a type a system reference speaks (rule 8), and §11.4 where the
     page is written. The guide's quotes of `Down`, `Reason`, and `RemoteError` are checked
     against the table, marked `ernest-prelude`, rather than turned into `:doc` sessions,
     whose whole pages would bury the two lines the guide means to show.
  2. **Done 2026-09-24: an input that is one name prints its declared type.** `:type
     Io.readLine` had printed `with e` where `:browse Io` printed `with m`, since an
     instance's variables carry no names (found by the guide's cold read). Report §11.2 now
     says an input that is one name has its type printed as the declaration writes it,
     whether `:type` asks for it or the input is evaluated; any other expression prints its
     own type. `ern_typecheck:declared_scheme/3` resolves the name as the checker does and
     gives its scheme, whose variables keep their names. The guide's `:type` sessions were
     regenerated, and a shell test holds the rule.
  3. **Done 2026-09-24: test areas, and faster suites.** A full `make test` had taken five
     minutes. `make test` still runs everything, and each area has its own target:
     `test-erl` (with `APP=` for one application), `test-programs`, `test-docs`,
     `test-guide`, `test-shell`, and `test-emacs`, which was `emacs-mode`. CLAUDE.md maps a
     change to the areas it needs, and the whole suite runs once per plan item. Measured
     after: the guide's examples 103 s to 13 s, compiling and running a module's example in
     the test's own node and the rest in parallel; the integration programs 39 s to 19 s
     and the Emacs mode 38 s to 15 s, run side by side; the unit tests side by side under
     `make -j`. The shell's sessions, 76 s, waited for step 5; most of their time turned out
     to be one session waiting out the harness's timeout, fixed there.
  4. **Done 2026-09-24: the signature inside a call, and a declaration's `since`.** Where
     no name before the cursor is documented and the cursor is inside a call, `Shift-Tab`
     shows the callee's signature, its parameters under their declared names and the one at
     the cursor in the terminal's cyan: `List.map(xs : List(a), f : (a) -> b with e) ->
     List(b) with e`, `f` coloured. The parser's diagnostic carries the innermost call and
     argument index (`within`), `ern_types:format_call/4` prints the signature in three
     parts around it, and the parameter names come from the `Docs` entry; a prelude function
     shows types alone. The region learned escape sequences: they take no column, and a row
     cut short resets its colour. The brief on a name ends with its `Since`, its own or its
     module's.
  5. **Done 2026-09-24: the program session waits on its faults, not on time.** It ran on
     two waits of 400 ms and had failed once under load. It now runs in the pseudo-terminal
     and waits on the screen for each fault report and each answer; the program's own fault
     is awaited before the first input, since nothing at the prompt holds the entry point's
     address to monitor. It passed eight runs at once. Timing the shell's area found that
     `multiline` spent 30 s waiting out the harness's timeout, `C-d` leaving only on an
     empty line; it cancels the input first now, and the area went from 76 s to 48 s.
  6. **Done 2026-09-24: a terminal test for `Shift-Tab` and command completion.** The first
     attempt had raced its own output, waiting for text the input echoes. `shift_tab_test_`
     waits only for text the answer holds: the brief on a name with its type, sentence and
     `Since`, the page on a second press, the signature inside a call, `:br` completed to
     `:browse`, and the listing a second `Tab` gives; `shift_tab_colour_test_` reads the raw
     output for the cyan around the parameter at the cursor. Six runs at once passed.
  7. **Done 2026-09-24: colour where it carries meaning, at a terminal only, and never with
     `NO_COLOR` set.** `Shell.Style`, pure and tested by `ern --test`: a fault report, a
     fault's `fault:` line, and a diagnostic's first line in red; the type after a printed
     value dimmed; a name bold in a completion listing and a `Shift-Tab` brief; the
     parameter at the cursor in cyan. No syntax highlighting of what is typed; `ernc`'s
     diagnostics stay plain. The front end answers whether to colour, from the terminal and
     `NO_COLOR`, until `Sys.env` (MVP 2.7) lets the shell read the environment itself. The
     harness waits on text with its colour sequences left out, stripping them once per read,
     and the shell's tests read the terminal's output the same way, one colour test raw.
     Running the shell's area alone found two things the full suite hid: the pure modules
     `region.ern` and `complete.ern` had tests `make test` never ran, and the snake test ran
     a program another suite had left in `build/`; every shell module's tests run now, and
     snake runs what its own test compiled.
- **Done 2026-09-24: typing ahead while an input runs.** The session, awaiting an input's
  result, took an input typed meanwhile out of its mailbox and dropped it, so the second
  was echoed and never answered. It is left in the mailbox now and runs after the first,
  which report §11.2 states; the prompt said after the first answer, which the typed-ahead
  input was never entered under, is taken away when the session takes that input (the
  screen's `Taken`), so its answer starts a row of its own. `typing_ahead_test_` is the
  regression test, and the program session types its second input ahead again.
- **Done 2026-09-24: the closing sweep.** The guide was read against the report, and every
  other document against the report and the code, by two readers who had not written them.
  Report §11.2 now states `Tab` completion, `Shift-Tab` documentation, colour, `it`, the
  file name `input`, the Readline keys, and a missing `HOME`; §11.5 the effect variable
  printing elides. Read for restating at 1,584 words, every sentence a rule of its own, and
  kept. Four defects the readers met in the toolchain were fixed, each with a regression
  test: a timed wait as a session's first input in line mode was a deadlock, from a race
  at spawn that a program could meet too, and §11.2's rule of no deadlock while a shell
  holds the terminal had not been built (`spawned_row_test`, `shell_holds_no_deadlock_test`);
  a prompt `let` with an unsettled effect variable crashed the next input
  (`effect_variable_test_`); a declared name could print through another input's
  substitution (the same test); and `:doc` painted a page red. The start line reads
  `VERSION`, and a session without `HOME` says it keeps no history (`no_home_test_`). The
  guide, the design note, the README, the architecture note, the feedback list, three
  example headers, and two test headers were corrected.
- **A session of real use.** The user works in the shell and reports what it is like; what
  that finds is fixed before the milestone closes or recorded in the design note. Nothing so
  far has been driven by hand — every test goes through the pseudo-terminal harness, which
  tests what was thought of.
  1. **Done 2026-09-25: what `Tab` and `Shift-Tab` show stands under the line.** A listing
     was committed above the region, where it read as the answer before; it is now painted
     in the region under the input, wrapped, cut to the screen with a count of the rest,
     and taken away by the next key, as Erlang's shell does. A `Tab` that adds nothing to
     the line lists at once, so `:` and `Tab` shows the commands. Report §11.2 states both;
     `listing_at_once_test_` is the regression test, and the region's own tests cover the
     wrapping and the count.
  2. **Done 2026-09-25: a command's argument completes from what the command takes.**
     `:browse` and `Tab` did nothing, `:browse ` and `Tab` indented, and `:browse Li`
     offered constructors. A whole command that takes an argument takes its space; the
     argument completes from what the command takes, a module for `:browse` listed by its
     name alone, a module under the source root for `:load` read a directory at a time,
     any name for `:doc`, the session's names for `:forget`, an expression for `:type`, and
     `:set`'s four words; `Tab` never indents after a command. A lone candidate is listed,
     so `:bindings` and `Tab` shows its help line. `command_argument_test_` is the
     regression test.
  3. **Done 2026-09-25: the commands in alphabetical order, and an ambiguous prefix
     refused.** The listing's order was §11.2's priority for an ambiguous prefix, which a
     reader of `:help` could not see. `:help` and the listing give the commands
     alphabetically, and `:b` answers `:b is :bindings or :browse`; the golden session
     checks both.
  4. **Done 2026-09-25: every name that completes after `:doc` has documentation.**
     `:doc Accept` answered none. A constructor now shows its type's section, a module the
     head of its page, a session declaration its name and type as the session writes them
     rather than `Input1.sz`, and a `let` at the prompt its name and type. `:doc` on a
     module `:load` compiled had never worked, since the front end looked for a file; it
     reads the session's copy. Report §11.2 states it; `doc_every_name_test_` is the
     regression test.
  5. **Done 2026-09-25: documentation is rendered for the terminal.** Asked of `:doc`'s `##`
     and fences. First decided the same day to stay unrendered, since a doc block is any
     CommonMark (§2.2) and rendering only what §11.4 writes would leave a page half
     rendered; then `libs/markdown` was written (under "Done") and the shell renders every
     page with it, `:doc`, the page on a second `Shift-Tab`, and the brief. §11.2 states
     what is rendered and how it is coloured.
  6. **Done 2026-09-25: `:load`'s refusals.** `:load aaaa` left the prompt on its answer's
     line, since the front end's refusals had no line feed where the compiler's
     diagnostics do; they end in one now. `:load List` said there was no module `List`,
     where §4.2 makes a standard library namespace taken and the module is in scope from
     the start, which is now the answer. A name that is not a module's, `aaaa`, is refused
     as such by `:load` and `:browse`, rather than looked for. The golden session checks
     all three.
  7. **Done 2026-09-25: the session's names in spawn sites, and `main` at the prompt.**
     `:processes` showed a process spawned at the prompt as `Input2.main:1`, the input's
     internal module and its wrapper. §11.2 now says a site in the session is written as
     the session writes names, `input:1` in an input's expression and `start:1` in a
     function it declares; the emitter writes it so for an input, the `Down` a monitor
     gives included. The wrapper was named `main`, and §11.2's scope looks in the input's
     own declarations first, so `main()` after `fn main` called the wrapper forever; it is
     `'$input'` now, which no identifier is spelled as. A constructor's refusal named
     `Input28.S`; it names `S` and the input that declared it. `session_names_test_` is
     the regression test.

**Out of 2.6:** every library, which is 2.7 with the paper program that needs it; `Regex`,
`Crypto`, `Uri`, `Zlib`, `Markdown`, which are 2.8; the library fetcher, 3.1; an HTTP server, never.
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

## MVP 2.65 (the language and the toolchain read back after the shell), about four days

The shell is the first program of size written in Ernest by the people who designed it, and
what it felt is in [`language_feedback.md`](language_feedback.md), which owns that list.
This item decides each entry rather than collecting it: the language questions first, field
selection at their head, then what belongs to Appendix E, then the names of the toolchain's
options, then what is recorded and left alone.

- **Each entry is judged on §0's five principles**, and a standard library entry on E.0's
  four admission rules, one by one and in writing. The note's last entry asked two of E.0 itself: rule
  1's second clause, the library's only opening for an argument from performance, went on
  2026-09-23 with `List.sort` written in Ernest; `path.ern`'s shims over string surgery are
  explained in the note and decided here. How many sites in the shell felt it is an argument,
  never the gate.
- **Every entry ends in one of three things:** a report change, made before any code; an
  entry in the log under "Later" stating the verdict and what would change it; or a line
  saying it was weighed and left alone. Nothing is left open, since the next program will
  feel the same things and a second collection is not a decision.
- **Field selection**, `s.upper`, the note's first candidate, with three witnesses in the
  shell and Gleam's totality rule to copy: a field read with a dot when every constructor of
  the type has a field of that name and type. Against it is principle 2, a pattern already
  reading a field; for it, that Ernest took `..` for update from the family whose readers
  expect `.` for read. The report changes first if it is taken: §3.5 for the rule, Appendix
  A for the production, §11.5 for what a selector on an absent field says. The note's second
  candidate, naming a prelude constructor a module has shadowed, was decided in the report's
  review: `Prelude.Close` (§4.2).
- **A registry, or the argument that none is needed.** §6.5 refuses one; the node protocol
  note asks for one (its open question 8), and a restarted service's new address has no
  other way to reach those who held the old one (MVP 2.66, the guide's §6.4). Decided here,
  report first: a table per node from name to address, or the argument that addresses handed
  on in messages suffice.
- **An address's identity, decided with the registry** (feedback item 24), since
  unregistering needs address equality. Either outcome changes the shell: `:processes`
  lists three processes spawned by three inputs as `input:1` three times, which tells them
  apart not at all. If addresses get equality, as *reaches the same process*, §3.10 loses
  the address half of its exception, `Io.debug` prints the identity (E.1), `<address 3>`,
  and `:processes` and a fault line show the same one, so a printed address and a row
  match; the runtime needs equal addresses to be equal terms. If they do not, `Io.debug`
  keeps `<address>`, and `:processes` and a fault line number each process for the shell
  alone. Until then `:processes` shows the site and nothing more.
- **The entries found in 2026-09-24's guide work**: item 15, a `Map` merge that combines the
  values of a key both maps hold, and item 17, a type's members at the prompt.
- **The entries found writing `libs/markdown`**, 2026-09-25: items 18 to 23, tuple
  projection, `match` as an operand, `String.trimStart` and `trimEnd`, `String.drop` and
  `dropWhile` against E.0 rule 4, and where counting a styled row's columns belongs.
- **The report read cold, by an implementer.** A reader who has not seen Ernest reads the
  report alone, as someone who must implement it, and reports every place where two
  readings are possible, where a rule is missing that an implementation needs, or where
  they had to guess. The guide's cold read on 2026-09-24 found more than every check
  against the report had, and the report has had no such reading; Wirth's measure of a
  report is that it suffices to implement the language. What it finds is decided here,
  report first.
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
- **The experiment first.** The guide's §6.4 shows the easy case since 2026-09-24, a
  supervisor in fifteen lines that runs a worker per job. The experiment is the hard one:
  `examples/supervisor.ern`, three long-lived workers restarted on fault under a
  restart-intensity limit, written with nothing but `spawn`, `monitor` and `receive`, and
  read back against the claim. If it reads as a program a person would write, the guide's
  section is the answer and no code. If every program would write the same sixty lines, that
  is the argument for `libs/supervisor`.
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
  the reverse monitor: each child monitors its supervisor and returns when it dies, which the
  guide's §6.4 states. Whether a sentence is enough is part of this item.

---

## MVP 2.7 (the first libraries and the network stack), about two weeks

Appendix D has been written to once, for `Ets`, and a pattern tried once is a guess: four
libraries written to it confirm or correct it before anyone outside writes to one, and they
are the compiler's second real user. `libs/` and `build/libs/` exist since 2026-09-24, when
`Ets` left the standard library for `libs/ets` and `ernc` took `--load-path`. Being
first-party changes nothing about the tier: a library is not on the load path unless a
program puts it there.

- **Report first**, for what a command-line program needs: `Sys.args : List(String)` and
  `Sys.env` in §8.2 and §9.7 as runtime-bound values, ambient as the other `Sys.*` references
  are, an exit status in §8.6, and `Time` in Appendix E over the clock's milliseconds. They
  came back here on 2026-09-20 when the shell's colour went later. The guide's cold read
  asked for the arguments at once (`language_feedback.md` item 16, 2026-09-24); an entry
  point that takes a `List(String)` is weighed against `Sys.args` before the report changes,
  and parsing options from the list is a library's, by E.0. With `Sys.env`, the shell reads
  `NO_COLOR` in Ernest, where its front end reads it today.
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
  `--load-path`, with `stdlib/`'s test discipline, its documentation in its module's doc
  block, which says how a program adds it, and no entry in
  Appendix E. Own repositories later, when there is a package story.
- **The report lists them** in a new informative appendix, one section per library with its
  signatures and contracts, and a mirror test holding each compiled interface equal to it, as
  `ern_prelude_tests` holds the prelude to Appendix E. Third-party libraries are not listed;
  Appendix D is what they follow.

---

## MVP 2.8 (five more libraries), about two weeks

`libs/regex`, a shim over `re`, a library and never syntax: `Regex.compile : (String) ->
Either(RegexError, Regex)` with `Regex` a foreign type, so a bad pattern is a value the
program handles, as Gleam's `gleam_regexp` does. `libs/crypto`, a shim over `crypto` for
hashes, HMAC and random bytes, the key and cipher surface waiting for a program. `libs/uri`,
pure Ernest or a shim over `uri_string`. `libs/zlib`, a shim over `zlib`. Each is written and
documented in one pass to [`module_doc_template.md`](module_doc_template.md), and its
executed doc examples are its first user, so no paper program is required (decided
2026-09-19). Each gets an appendix section beside 2.7's four.

`libs/markdown` was taken out of order and is done (under "Done", 2026-09-25); the other
four remain.

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
   escape alone for fifty milliseconds being the key. `snake` was checked by hand
   then, and MVP 2.6's terminal harness has played it since.
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

### MVP 2.9 — an Emacs major mode (done 2026-09-23, out of order)

Taken out of order, between checkpoints of MVP 2.6. [`emacs_mode.md`](emacs_mode.md) owns
the mode and [`decisions.md`](decisions.md) the arguments. `emacs/ernest-mode.el`, its tests
under `emacs/test/`, run by `make test-emacs` and last in `make test`.

Three decisions of the milestone reach beyond it:

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

### The report read as a Wirth report (done 2026-09-23 and 2026-09-24)

A standalone reading of the report, as a Wirth report and against §0. Its errors that asked
for no decision were fixed, and its other issues decided one at a time:

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
- §6.6 was rewritten top-down on 2026-09-24, the rules unchanged. It opens with the rule a reader needs first, that a `Reply`, and any value that contains
  one, is used exactly once on every path, by `answer` or by a use that hands the
  obligation on; then which types contain a reply, where such a value may not go, how
  branches share the obligation, and one accepted and one rejected example side by side.
  The report stays one document: splitting out the ABI and the toolchain was weighed
  against the single source of truth and refused.

### `libs/markdown` — a CommonMark renderer (done 2026-09-25, out of MVP 2.8's order)

The shell showed documentation as CommonMark, `##` headings and ```` ```ernest ```` fences
included, since a doc block may hold any CommonMark (§2.2) and rendering only what §11.4
writes would have left pages half rendered. `libs/markdown` is the renderer that ruling
waited for, pure Ernest, about five hundred lines: `Markdown.parse` reads CommonMark 0.31's
blocks, headings ATX and setext, paragraphs, fenced and indented code, block quotes with
lazy lines, bullet and ordered lists, thematic breaks, and HTML blocks kept as `Raw`, and
its inlines, code spans, emphasis, strong emphasis, links, images, autolinks, and hard
breaks; `Markdown.render` lays them out at a width, with the terminal's styles or as
written. Where it is simpler than the specification, emphasis by the nearest closing run
and a run of three marks as text, its doc block says so, and inline HTML, entities, and
links by reference stay in the text.

- **Why a library.** How a heading or a link looks at a terminal is policy inside a
  namespace of its own, so E.0 puts it under `libs/` and not in the standard library. It is
  the second parser written in Ernest at size after `Json` is, and any command-line program
  that shows Markdown has a use for it.
- **The shell uses it.** `make` builds `libs/` before the shell, compiles the shell with
  `--load-path build/libs/markdown`, and ships the compiled library beside the shell's
  modules. `:doc`, the page on a second `Shift-Tab`, and the brief on the first are
  rendered at the screen's width, 80 columns where there is no terminal. Report §11.2 states
  what is rendered and how it is coloured.
- **Tests.** Its doc examples run in `ern_doc_tests`, as every library's do; 23 `Test`
  values for the edge cases run by `ern --test` in the new `libs_test_`, which runs every
  library's. They passed on their first run, so they confirm the code rather than having
  found anything; the terminal harness and the golden session show the shell's pages.
- **Not yet:** the report's informative appendix of libraries and its mirror test are MVP
  2.7's item, and the library joins it there, as `libs/ets` will.
- **What it felt:** six entries in the feedback list, 18 to 23, judged in MVP 2.65.

### MVP 2.61 — the guide as the user's document (done 2026-09-24, out of order)

A newcomer reads the guide and not the report, so the guide was rewritten to teach Ernest on
its own, in nine steps, each a stop: every example checked by `test/ern_guide_tests.erl`
(67 at the close: programs with their output, rejected blocks with their errors, shell
sessions, files in parts, input piped in); an opening that shows four mistakes `ernc`
finds and credits Erlang, Gleam and Unison; §2 to §8 cut to a rule and an example each;
failure in a section of its own, with a supervisor; one running example, a word counter,
through §2 to §5; a page for the tools and a section for the Erlang programmer; a closing
section on the design; a two-reader sweep; and a cold read by a reader new to Ernest. What
it changed beyond the guide, each argued in the log:

- **Report §11.2:** the prompt's `let` takes a pattern and `let x <- e` is refused; a `Unit`
  value prints nothing; a file without `main` is loaded with nothing spawned; an Erlang
  module a `foreign fn` names is found on the load path. **§11.5:** an error names its file
  from the working directory.
- **Defects fixed:** `ernc` crashing on an error whose source line holds a character outside
  Latin-1, and `ern` printing such text byte by byte; the message for a pure callback given
  to `spawn`.
- **Decided and placed:** the prelude's documentation and `:type` of a name (MVP 2.6
  checkpoint 4); §11.2's `Tab` and `Shift-Tab` (MVP 2.6's closing sweep); the arguments
  (MVP 2.7); a registry and feedback items 15 and 17 (MVP 2.65); whether `remote` stays
  (MVP 3.0).

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
