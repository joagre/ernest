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

**MVP 2.65, the language and the toolchain read back after the shell, has begun.** Its
first nine steps are done: the feedback list and this plan consolidated, the report read
cold, the five themes, names and namespaces, expressions, patterns and types, processes and
the system, the standard library under E.0, and the toolchain, the Erlang code's open
questions, and the cold read's last findings. Step 10, the build, has begun: its gate, its
ledger, its report pass and the report's cold read are done, and four decisions come before
its rename.
MVP 2.6, the shell, was closed on
2026-09-25, and the code read back after it the same day, both under "Done".

**Taken out of order and done:** MVP 2.9, the Emacs mode, on 2026-09-23; MVP 2.61, the
guide as the user's document, on 2026-09-24, after which CLAUDE.md was rewritten for
clarity, every rule kept; and `libs/markdown`, now MVP 3.2's, on 2026-09-25. All three are
under "Done".

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
| MVP 2.6 | the shell | done 2026-09-25 |
| MVP 2.61 | the guide as the user's document | done 2026-09-24, out of order |
| **MVP 2.65** | **the language and the toolchain read back** | **begun 2026-09-25** |
| MVP 2.66 | the standard library's `Supervisor` | after 2.65 |
| MVP 2.7 | a program started from a command line, and the appendix of libraries | |
| MVP 2.9 | an Emacs major mode | done 2026-09-23, out of order |
| MVP 3.0 | peers | |
| MVP 3.1 | content addressing | |
| MVP 3.2 | the libraries, as they are wanted | `libs/markdown` done 2026-09-25 |

---

## MVP 2.65 (the language and the toolchain read back after the shell), about two weeks

The shell is the first program of size written in Ernest by the people who designed it, and
what it and the libraries felt is in [`language_feedback.md`](language_feedback.md), which
owns that list, grouped there by theme. This item decides each entry rather than
collecting it, a theme at a time, in the order below: each theme decides things the next
ones assume. It grew from about twenty questions to about sixty with the shell's close and
the code's read-back, so the estimate is two weeks of turns where it was four days.

- **Each entry is judged on §0's five principles**, and a standard library entry on E.0's
  four admission rules, one by one and in writing. How many sites felt it is an argument,
  never the gate.
- **Every entry ends in one of three things:** a report change, made before any code; an
  entry in the log under "Later" stating the verdict and what would change it; or a line
  saying it was weighed and left alone. It then leaves the feedback list. Nothing is left
  open, since the next program will feel the same things and a second collection is not a
  decision.

The steps:

1. **Done 2026-09-25: the list consolidated.** The feedback list is grouped by the question
   its entries share, each keeping the number it is cited by, and the settled entries have
   left it; this plan's "Done" is a paragraph a milestone, the detail being the log's and
   the history's.
2. **Done 2026-09-25: the report read cold, by an implementer**, and its plain half written
   into the report (the log's *The Report Read Cold, Its Plain Half*). What is open is in
   [`report_cold_read.md`](report_cold_read.md), each finding under the theme that decides
   it; what no theme takes is decided in step 9.
3. **Done 2026-09-25: names and namespaces**, the feedback list's first theme. An abstract
   type's boundary is its module (items 32, 33 and 49; report §4.4). Constructor names stay
   unique in a module (item 2), names stay qualified without import or alias (item 4), and
   two visibilities are enough (item 43), each weighed and kept. A later input may add a
   member to a session type (item 17; report §11.2). The log has an entry for each; item 46
   moved to the standard library's theme.
4. **Done 2026-09-26: expressions, patterns and types**, the second theme. **Decided
   2026-09-25:** field selection, `e.f` where every constructor has the field (item 51; report
   §3.5); no projection from a tuple (item 18, weighed and kept out); a `match` and a
   `receive` are operands (item 19; report §5.9); a type variable is not-reply-carrying by
   what the body does with it, which closes the hole the cold read found in §6.6 (findings 2.1
   and 2.2; report §3.9); constant patterns and a reserved `after`, each weighed and kept
   (items 3 and 5); an initializer depends on every name it mentions (item 48 and finding
   1.13; report §8.5); and seven smaller rules from the cold read: source order for a callee
   and a pipe (1.2, §5.1), `..` only on a type with one constructor (1.6, §5.6), a type
   argument a value position only where its fields make it one (2.6, §3.9), the shape of an
   operator, `compare` or `negate` member (2.8, §4.8), a local `fn` never named like a
   variable in scope (2.9, §5.4), a receive guard's grammar written out (2.17, §6.3), and a
   local `fn`'s signature sharing the enclosing type variables (2.34, §3.9). **Decided
   2026-09-26:** a pure function stands wherever one with a mailbox type is expected, each
   expression of a pure function type opening its effect (1.1; report §3.9); a redundant
   clause is a type error, in `match` and `receive` (2.13; report §5.9); a foreign type's
   parameter written `k=` requires equality, as `Map`'s key does (item 39; report §4.7); one
   contract over several representations is a record of functions, taught in the guide's §7.3,
   and a check-only contract waits for a design (item 52, weighed and kept); an exported
   function takes no `Bool` that chooses a behaviour, and `Markdown.render` takes a `Style`
   (item 45; report Appendix E.0 rule 9). The log has an entry for each.
5. **Done 2026-09-26: processes and the system**, the third theme, after a survey of the
   BEAM languages, the typed and virtual actors, and the capability languages (the log's
   *Names, Restarts and Supervision*). Nothing is built yet; step 10 builds it, report first,
   in §4.6, §6.5, §6.6, §6.9, §7.4, §8.2, §8.5, §8.7, §9, §11.2 and Appendix E. Items 14 and
   25 stay with MVP 3.0 and 16 with MVP 2.7. The decisions, each argued in the log entry
   named:
   - **No registry; a restart keeps the address** (item 53). `restarting(Limit(restarts,
     within), f)` runs `f` again in the same process and mailbox on a fault, past the limit
     dying with the last cause, with no strategy and no backoff (*A Restart Has a Limit and
     No Strategy*). A service is a top-level binding, `export let service : Address(M) =
     ...`, and an initializer is checked as a `Never` process in the entry process before
     `main` (*An Initializer Runs as a `Never` Process*).
   - **A call ends when its callee faults or dies**: `Address.call` answers `None` at once,
     and `Address.callForever` faults its caller with the callee's cause, `Fault("callee was
     killed")` or `Fault("callee returned without answering")` (*A Call Ends When Its Callee
     Faults*, completed in *A Stream Keeps Its Own Time Limit*).
   - **Every fault reaches standard error**, with `restarted` after one the limit allowed;
     `monitor` stays one message at death (item 9; *Every Fault Reaches Standard Error*).
   - **A peer's service is found through its binding**, and `Peer.find` does it in one
     call in MVP 3.0 (*A Peer's Service Is Found Through Its Binding*).
   - **A `Supervisor` in the standard library, and `fault(cause)` in the prelude**, the
     supervisor built in MVP 2.66 and `fault` in step 10 (*A `Supervisor` in the Standard
     Library, and `fault`*).
   - **A process's identity is a `Process`**, from `Address.process`, with equality; an
     address keeps none (item 24; *A Process's Identity Is a `Process`*).
   - **`stdlib/process.ern`**: `Process.live`, `site`, `mailboxSize`, `state` (item 26; *The
     Live Processes Are a Library Function*) and `Process.faults` with `FaultReport` (item
     28; *Every Fault Is Delivered to Whoever Subscribes*). The shell's doors to the
     runtime's processes go. A `FaultReport` carries the host's stack as a field `trace`,
     empty beneath a §7.4 cause, and every printed fault shows it, the shell's lines among
     them (step 8; *A Failure of the Runtime Shows Its Stack*).
   - **A stream keeps its own time limit**: `Tcp.read`, `accept` and `connect` carry their
     milliseconds in the request (item 50; *A Stream Keeps Its Own Time Limit*). Found in
     step 8: a caller waiting with `callForever` on a listener is read as a deadlock within
     100 ms, since neither the listener nor its worker counts as a source, so the socket,
     listener and connect processes count a pending request as a source while it waits, as
     the terminal does (§8.6).
   - **A system message is its module's to make**, and `Sys.stdout` and `Sys.stderr` take an
     `OutMsg` (item 47; *A System Message Is Its Module's to Make*). The means changed at the gate, G13: each reference and
     message type moves into its module.
   - **`Tcp.port(listener)`** (item 37; *A Listener Says Its Port*).
   - **`Terminal.subscribe` answers `Left(NotATerminal)`** where standard input is not a
     terminal, and the shell's `isTerminal()` goes (item 27; *A Subscription Says Whether It
     Has Keys*).

   The guide gains a section on services in step 10 and one on the supervisor in MVP 2.66.
6. **Done 2026-09-26: the standard library under E.0**, the fourth theme, in three batches.
   Nothing is built yet; step 10 builds it, report first, in Appendix E, each rewritten or
   new function with tests of the edge cases its contract names.
   - **Batch 1 decided 2026-09-26: a shim is only an operation that reaches the
     representation** (items 11, 13, 42, 46, and 34 with them). E.0 rule 1 says so, and
     each module's section names its primitives, chosen to pass data out and never to call
     back into Ernest: `Map` and `Set` keep six shims each, `empty`, `size`, `get` or
     `contains`, `put`, `remove`, `toList`; `String` keeps `indexOf`, `lastIndexOf`, `part`
     and `size` for searching, its Unicode operations and its conversions, and `startsWith`,
     `endsWith`, `contains`, `parts`, `copy` and `replace` become Ernest, so every search
     matches whole graphemes, which E.5 says (item 34); `Bytes` keeps `size` and `part`;
     `Path` keeps the separator and `isAbsolute`. `Random` is SplitMix64 in Ernest, `Seed` an
     abstract type, the same sequence everywhere, as E.13 says by naming it. `Path`, `Block`
     and `Inline` stay transparent, and a socket an address. Built in step 10, with tests of
     each edge case a contract names. The log's *A Shim Reaches the Representation*.
   - **Batch 2 decided 2026-09-26: a name follows the vocabulary** (items 40, 41, 38). E.0's
     third shape rule says that between a type and one its module builds on both directions
     are the building module's, `Map.fromList` and `Either.fromOptional`, and otherwise each
     is its argument's module's `toX`; nothing moves. `Set.intersect` becomes
     `Set.intersection`; `String.contains` stays a substring test, which the second shape
     rule says of text. E.0's shape rules cover the libraries under `libs/`, and `Ets` takes
     `put`, `get`, `contains`, `remove` and `close`. Built in step 10. The log's *A Name
     Follows the Vocabulary*.
   - **Batch 3 decided 2026-09-26: what the library lacked** (items 7, 8, 15, 20, 21, 22, 23,
     31, 35, 44, and the socket's addresses from item 37). Admitted: `Map.mergeWith`,
     `String.trimStart` and `trimEnd`, `Char.isAsciiDigit`, `Terminal.columns` in Ernest over
     a table from Unicode's width data, used by the shell's region and the Markdown library,
     `Io.show`, and `Tcp.peer` and `Tcp.local`. Kept: `String.lines` (its See also gains
     `split`), no `String.drop`, `dropWhile` or flatten (rule 4), and no text for `IoError`
     (rule 3; `Io.show` serves a log). E.0's fifth shape rule applies `with m` to what reaches
     a system reference, and rule 4 names the pairs the library keeps, `Io.debug` with
     `Io.show`. The log's *What the Library Lacked*.
7. **Done 2026-09-26: the toolchain**, the fifth theme: the options of `ernc` and `ern`, read
   whole for the first time, and the shell's own questions (items 29, 30 and 54). Items 29
   and 30 were defects and are fixed; the rest is built in step 10, report first.
   - **Decided 2026-09-26: one tool, the job its first word.** `ernc` goes into `ern`:
     `ern build`, `ern doc`, `ern run`, `ern test`, `ern shell` and `ern config`, with
     `--help` and `--version` as options. §11 states the rule for a directory's option:
     `-root` where its layout gives namespaces, `-dir` a plain directory, `-path` a root
     given more than once; `--out-dir` becomes `--build-root`. `ern config [--config-dir d]`
     creates the configuration directory itself (the cold read's 3.12). `--no-clean` goes,
     and `--errors short` and `--emit erl` become the flags `--short-errors` and
     `--emit-erl`. A refusal of an old spelling names the new one. Report §11.1 to §11.4,
     the README, the guide's tools page, the Makefile, the Emacs mode and the tests change
     together in step 10. The log's *One Tool, the Job Its First Word*.
   - **Fixed 2026-09-26: a word is Readline's** (item 29). The `M-` keys walk over runs of
     letters and digits and `C-w` back to a space, as §11.2 now says; the editor had used
     spaces for all five, against §11.2's promise of Readline's keys. The log's *A Word Is
     Readline's*.
   - **Fixed 2026-09-26: the path rule has one owner** (item 30). `:load`'s completion asks
     the compiler, `ern_shell:segment`, for the namespace segment a file or directory names,
     and the shell's copy of §11.1's path shape goes. The log's *The Path Rule Has One
     Owner*.
   - **Decided 2026-09-26: completion reaches a value's fields** (item 54). After a name the
     session binds or a module exports, and a `.`, `Tab` completes the fields its type
     selects (§3.5), along a chain; a name the unfinished input binds is not completed, as
     §11.2 says. Built in step 10, with terminal tests. The log's *Completion Reaches What
     the Session Knows*.
8. **Done 2026-09-26: the Erlang code's open questions**, from its review on 2026-09-25,
   gone through before what was decided is built. Fixed as found, each with its test: the
   pipe's right operand parsed once; an unannotated lambda's effect error; `compile_source`'s
   two shapes; a bitstring pattern's variables, whose omission crashed the compiler; one AST
   walk; `ern_diag` in `utils`; the interface chunk's one owner, `ern_iface`; public OTP
   calls for `prim_tty` and `pubkey_cert_records`; listeners and sockets that end with the
   program; the chains of `orelse` before a `fail`, and the style guide's rule for them.
   Decided with the user, each with its log entry: a function may be named `module_info`
   (*A Function May Be Named `module_info`*); one subscription to the terminal a process
   (§8.2, *One Subscription to the Terminal a Process*); a precondition is one line (*A
   Precondition Is One Line*); a failure of the runtime shows its stack (*A Failure of
   the Runtime Shows Its Stack*); what a name resolved to is recorded (*What a Name
   Resolved To Is Recorded*); one copy of each scope rule (*One Copy of Each Scope Rule*);
   where the modules split (*Where the Toolchain's Modules Split*); a process watched from
   its start, `spawnMonitored`, and `Unknown` (*A Process Is Watched From Its Start*); the
   shell lets go of an input (*The Shell Lets Go of an Input*); and an input's number given
   again (*An Input's Number Is Given Again*). Left, each placed: the holders of `it` and
   the shell's split in step 10; memory and atoms measured under load in MVP 2.7;
   `names()` at every `Tab`, measured at 13 ms and kept, since a cache would need an
   argument for when it lets go.
9. **Done 2026-09-26: the cold read's own findings**, the last ten, in one batch (the log's
   *The Cold Read's Last Findings*). Fixed now, as defects: a `monitor` wrap that faulted
   killed the runtime's reaper and an alarm's that never finished froze the clock, so a
   wrap is applied as `via`'s function is, its fault the receiver's and in a process of its
   own (§6.9); `kill` on a system process faults the caller (§6.9, §7.4). Decided, for step
   10 to write: `send(Sys.stdout, ...)` is refused by item 47 (1.8); code-point order for
   `compare`, `trim` by `Char.isSpace`, full case mapping without language rules (1.7, E.5,
   E.6); the program ends when the entry process dies, a killed one printing `killed` with
   status 1, a signal exiting 128 plus its number and printing nothing (2.19, §8.6, §11.2);
   a line of standard input is UTF-8 whatever the locale, one carriage return before a line
   feed dropped, a last line without one still a line (2.24, §8.2); `Float.toString`'s
   shortest digits, plain from 0.0001 to below 1.0e16 (2.26, E.9); a Commands paragraph in
   §11.2 held equal to the shell's list by a test (2.33); `////` an ordinary comment (3.17,
   §2.2); `ern --test` printing each line as its test ends, a deadlock the test's fault
   (3.30, §11.2); and the terminal's wraps delaying only their subscriber's keys (§8.2).
   Reading bytes from standard input went to the feedback list, item 57.
10. **What was decided is built**, in seven sub-steps, each its own commit. Step 9 comes
   first, so that the report is edited in one pass rather than two. Before step 10 begins,
   `make sections` and `make coverage` are run and kept, so that it can show every new or
   changed section gained a citing test.
   1. **Done 2026-09-26: the gate, steps 5 to 7 read back as a whole.** A reader who took no part reads every
      log entry from *Names, Restarts and Supervision* to *Completion Reaches What the Session
      Knows* together, against principles 5 and 1 only, and reports: what the decisions add
      to the prelude, the standard library, the report and the toolchain, counted, and what
      they remove; any two decisions that overlap or give a second way to do one job; any
      decision a later one made unnecessary; and what could be dropped or merged, with what
      the language loses if it is. Each finding is decided with the user, one at a time,
      before anything below is written. The log's *A Gate Before the Build*. Run on
      2026-09-26 over steps 5 to 9, since step 8 changed the language too; decided so far:
      - **G13, the system references live in their modules.** Each `Sys.*` reference moves
        into its system module as a top-level binding the runtime binds, `Clock.reference`,
        and its message type with it, abstract under §4.4, refined in sub-step 3 to private but for
        `Tcp`'s two; `OutMsg`, item 47's owner table and its mirror test go. §8.2, §9.7, E.0 rules 7 and 8, and each system module's
        section. The log's *The System References Live in Their Modules*.
      - **G1, `todo` goes; `fault` stays.** One prelude function ends a process with a
        cause; unfinished code writes `fault("todo: ...")`. §7.4 and §9, the example and the
        guide that used `todo` for a broken invariant. The log's *One Way to Fault*.
      - **G9, `Process.info`.** `Process.site`, `mailboxSize` and `state` become one
        `Process.info(p) : Optional(Process.Info) with m`, `type Info = Info(site : String,
        queued : Int, activity : Activity)` and `type Activity = Running | Receiving |
        Calling`, one snapshot of a live process and `None` once it has ended. The log's
        *One Question About a Process*.
      - **G2, one name for the spawn site, and `Process` in its module.** `Down.function`
        becomes `Down.site`, as `FaultReport` and `Process.Info` name it; `Address.process`
        becomes `Process.fromAddress`, by step 6's conversion rule; and `Process` is
        `process.ern`'s foreign type, with `Info`, `Activity` and `FaultReport`, the
        prelude keeping only the types the language's rules name. §6.9, §9.3, E and the
        `Process` section; the guide, the shell, the examples and the tests. The log's
        *Everything About a Process in Its Module*.
      - **G8, `trim` a named pair.** E.0 rule 4 names `String.trim` beside `Io.debug`, as a
        composition, `trimStart` then `trimEnd`, that text wants more often than either half;
        `Map.merge` is no pipe of two functions and needs nothing. The log's *`trim` Is a
        Named Pair*.
      - **G7, `Tcp.peer` and `Tcp.local` keep their names.** A connection's peer is TCP's
        word, another context than a peer node, and E.18's line for `Tcp.peer` says so, "the
        connection's far end, in TCP's sense, not a peer of §8.3". The log's *A TCP Peer Is
        TCP's*.
      - **G6, `Peer.find` stands**, its one dependency on item 14 written in MVP 3.0. The
        log's *`Peer.find` Stands*.
      - **G10, the `Supervisor` keeps its start notice.** A subscription to faults is
        global, every supervisor receiving every fault, where the notice is one message a
        restart to the one supervisor that owns the child; `Process.faults` stays for
        diagnostics, and MVP 2.66 writes why into the `Supervisor`'s documentation. The log's
        *A Supervisor Is Told by Its Own Children*.
      - **G15, the types named.** `Tcp.peer` and `Tcp.local` answer `Either(IoError,
        Tcp.Endpoint)`, `Endpoint(host : String, port : Int)`; `restarting`'s limit is the
        prelude's `RestartLimit(restarts : Int, within : Int)`, which the `Supervisor` takes
        for its group's limit too; the strategies are `Supervisor.Strategy = OneForOne |
        OneForAll | RestForOne`. The log's *The Last Types Named*.
      - **Kept, each with a line in the guide:** `monitor` beside `Process.faults`, the one
        for a process one holds and the other for diagnostics (G3); spawn followed by
        `monitor` named as the mistake `spawnMonitored` avoids (G4); `restarting` beside
        `OneForOne`, a layer and not a duplicate (G5); the report on standard error as
        `Process.faults`' first subscriber, said once (G11); an initializer with effects,
        the `start` and `service` pair, and a library's service in a module of its own
        (G14). G12, an earlier entry overtaken by a later one, is the log's history and
        stays.
   2. **Done 2026-09-26: the ledger.** A table in this plan, a row for each decision the gate
      leaves: the report sections it changes; the Erlang modules and Ernest files it reaches;
      its tests, the new ones and the mirror tests that must change; the documents it
      reaches; what it depends on; and the grep that finds what it makes false, so that the
      commit that builds it removes every such sentence. Three readers who took no part
      filled it on 2026-09-26; the counts leave out this plan and the log. A row names the
      decision it builds by its step and the log entry, and the order below is what the
      dependencies give.

      | Row | Decision | Report | Code | Tests | Documents | After | Grep, hits |
      |---|---|---|---|---|---|---|---|
      | A1 | `ern` subcommands (step 7) | §7.4, §8.1, §9, §9.3, §11 and §11.1 to §11.5, App. C, E.0 rule 6 | `bin/ernc` goes; `ern_cli` options, usage, refusals, the generated header; `ern_page` footer; `ern_rt` fault text; `Makefile`, `test/Makefile` | `ern_cli_tests` (95 calls), `ern_shell_tests`, `ern_integration_tests`, `ern_terminal_tests`, `ern_guide_tests` console grammar, `emacs/test/editing.el`; mirror: the template page's marker; new: each subcommand, each old spelling refused | README, guide §1, §7.1, §9 and 57 console lines, `architecture.md`, `shell_design.md`, `module_doc_template.md`, `emacs_mode.md`, `shell/README.md`, example headers, CLAUDE.md's line on `ernc` | none | `ernc`, `--out-dir`, `--no-clean`, `--errors`, `--emit`, `--create-config-dir`, `ern --test`/`--shell`/`--doc`, `ern x.erc`: 498 in 40 files |
      | A2 | completion of fields (step 7) | §11.2 | `ern_shell` context, one copy of §3.5's selection through `ern_typecheck:resolve_select/4`; `shell.ern` `offered`, a foreign fn; `complete.ern` | `ern_shell_tests` `completion_test_`; `complete.ern`'s `Test`s | guide §1.2, `shell_design.md`, `shell/README.md` | A1 | `names a namespace`, `segment by segment`, `completes the word before the cursor`: 5 |
      | B1 | `restarting` (step 5) | §6.5, §6.6 (L1), §6.9, §7.3, §9.3, §9.5 | `ern_prelude`, `ern_emitter`, `ern_rt` restart loop, window, reaper row, pending calls ended, `restarted`; `ern_reply` | `ern_rt_tests` same pid and mailbox, the limit; `ern_typecheck_tests` a reply-carrying function refused; mirrors: `ern_prelude_tests` | guide services section, §6.4, §10; `architecture.md`, `node_protocol.md` | none | `A fault ends the process that meets it`, `a new process with a new address`, `fifteen lines`: 4 |
      | B2 | service bindings (step 5) | §4.6 (L2), §6.5, §6.8, §8.5, §8.7, §11.2 | `ern_typecheck` initializer as a `Never` body, generalization; `ern_emitter` `init_fun`; `ern_shell` load and reload; `ern_cli` | `ern_typecheck_tests` two change; new: spawn and send allowed, `receive` refused, two services in a cycle, a reload with a service | guide §2.2, §6.4, services section; `shell_design.md`, `node_protocol.md`, `architecture.md` | B1 | `initializer is pure`, `Effectful setup belongs`, `no registry`, `cannot reach a process the program spawned`: 13 |
      | B3 | a call ends when its callee faults (step 5) | §6.6, §7.2, §7.4 | `ern_rt` `call`, `call_forever` watch the callee, through `via` | `call_forever_deadlock_test`; new: a dead, faulted, killed, returned callee; the cause passed on | guide §0, §4.4, §6.2 | B1 | `waits for ever`, `waits without limit`, `the only way to tell a slow process`: 7 |
      | B4 | every fault to stderr (step 5, G11) | §11.2 | `ern_rt` `died`, `run_main` the reporter as first subscriber; `ern_cli` `report_fault` | new: a worker's fault on stderr, `restarted`, a system process's not printed; changed output: `test/expected/repl.out`, guide §6.3 and §6.4 consoles | guide §6.3, §6.4 (`Only supervise prints`), §9.2; `shell_design.md`, `shell/README.md`, `architecture.md` | with B5 | `A fault of the entry process`, `read by the shell and not by a program`, `Only \`supervise\` prints`: 6 |
      | B5 | `Process` (steps 5, 8, G2, G9) | §6.5, §9.1, §11.2, E.21 (L6), E.0 rules 1, 5, 7, 8, E.1, a new section of Appendix E | `stdlib/process.ern`; `ern_rt` `live`, a Calling mark, fault subscribers through `wrapped/3`; `ern_show` `<process 84>`, `<address 84>`; `ern_typecheck` equality error; `ern_shell` loses eight doors; `shell.ern` keeps its hundred faults | `ern_stdlib_tests`, `ern_rt_tests`, `ern_show_tests`, `ern_shell_tests` `:processes` and `:faults`, `test/session/basic.out`; mirrors: `ern_prelude_tests` | guide §3.6, §5.2, §9.3, §10; `shell/README.md`, `shell_design.md`, `node_protocol.md`, `architecture.md`; `examples/repl.ern`'s run number, which becomes a process | B7, B1, B8, A1 | `watchDeaths`, `processes()`, `faults()`, `mine()`, `<address>`, `no equality`, `identity is expressed in the protocol`: 29 |
      | B6 | `fault`, `todo` gone (G1) | §3.7, §7.4, §9.5, §9.6 | `ern_prelude`, `ern_emitter`, `ern_rt` `todo` | `ern_emitter_tests`, `ern_stdlib_tests`, `ern_typecheck_tests`; mirrors: `ern_prelude_tests`, the template page | guide §3.4, §6.3, §6.5 and its answers to the exercises; `examples/template.ern`, `module_doc_template.md`, `shell_design.md` | none | `todo`: 41 in 12 files |
      | B7 | `Down.site` (G2) | §6.9, §9.3 | the tuple becomes `{'Down', Reason, Site}`, fields in canonical order: `ern_prelude`, `ern_rt`, `ern_cli`, `ern_shell`, `shell.ern` | `ern_rt_tests` 10, `ern_emitter_tests` 5, printed `Down(reason = ..., site = ...)`; mirrors: `declared_types_test`, the guide's §5.2 | guide §5.2, §5.6, §6.3, §6.4 | none | `function = `, `Down.function`, `{'Down', Site`: 35 in 11 files |
      | B8 | the references in their modules (G13) | §4.2, §8.2, §8.5, §8.7, §9, §9.3, §9.7, §10, §11.2, E.0 rules 1, 5, 7, 8, E.1, E.15 to E.18, App. F; L4, L5 | `ern_prelude` loses the `Sys` values and types; `ern_emitter`; `io`, `clock`, `terminal`, `fs`, `tcp` `.ern` each bind their reference, private to the module; `ern_rt` keeps `sys/1`, and `kill`'s check for a system process goes, since no program can name one | `ern_prelude_tests` (the §9.7 mirror shrinks), `ern_doc_tests`, `ern_emitter_tests`, `ern_typecheck_tests`, `ern_cli_tests`, `ern_shell_tests`; new: another module's message constructor refused, a system reference not visible outside its module | guide, README, `architecture.md`, `shell_design.md`, `examples/` webserver, filesync, repl, echo | A1, B2 | `Sys.` references 103, the seven message types 53, `system reference` 15, `sys.ern` 3, `IoError` 79 (L4) |
      | B9 | `Tcp` keeps its time limit, `port`, `peer`, `local` (steps 5, 6, G7, G15), and a socket lives until `Tcp.close` (L3) | E.0 rule 8, E.18 | `tcp.ern` over `callForever`; `ern_tcp` timers, late bytes kept, a pending request a source, `peername`, `sockname`, a closed connection answering `Left(Closed)` until `Close` | `ern_tcp_tests`; new: a timed-out accept takes nothing, a late connect is closed, `callForever` on a listener no deadlock, `port` after `listen(0)`, reads after the far end closes, a read after `Tcp.close` faults; `ern_stdlib_tests` | `tcp.ern` docs, `examples/echo.ern`, `architecture.md` | B8, B3 | `answered(Address.call` in `tcp.ern` 3, `Recv(reply` 3, `Tcp.listen, and Io.readLine take none` 1, `dies with the connection` 5 |
      | B10 | `Terminal.subscribe` answers `Either` (step 5, step 9) | §8.2, §9.3 `IoError`, E.16, §11.2 | `terminal.ern`; `ern_tty` refuses before raw mode, each subscriber's wraps in order; `ern_shell` `is_terminal` goes; `shell.ern`, `snake.ern`; a `NotATerminal` arm in three matches | `ern_tty_tests`, `ern_rt_tests` sources, `ern_terminal_tests` (a piped program gets `Left(NotATerminal)`), `ern_emitter_tests`; mirrors: `declared_types_test`, `values_test` | guide §1.3, §5.5; `shell_design.md`, `shell/README.md` | B8 | `isTerminal` 3, `where there is no terminal` 7, `A program that does both faults` 1 |
      | C1 | a shim reaches the representation (step 6) | E.0 rule 1, E.3, E.4, E.5, E.14, E.20 | `map.ern`, `set.ern`, `string.ern`, `bytes.ern`, `path.ern` in Ernest over their primitives; `ern_map`, `ern_set`, `ern_string`, `ern_path` shrink, `ern_path:dirname` with them | `ern_stdlib_tests` and each edge case a contract names; new mirror: each module's `foreign fn`s equal the primitives its section names | `architecture.md`, the module pages | none | `ern_map:`/`ern_set:`/`maps:` 30, `ern_string:` six, `ern_path:` 6 |
      | C2 | `Random` is SplitMix64 (step 6) | E.13, E.0 rule 7's example | `random.ern` over `Int`'s bit operations; `ern_random` goes | `random_test` known answers; `stdlib_types_test` an abstract type | guide §8.4's node-bound example, which is `Random.Seed`, gets another; `architecture.md` | C1 | `foreign type Seed` 4, `bound to its node` 4, `exsss` 3 |
      | C3 | names follow the vocabulary (step 6) | E.0 shape rules 2 and 3, E.4, App. D | `set.ern` `intersection`; `libs/ets` `put`, `get`, `contains`, `remove`, `close` | `ern_stdlib_tests`; mirror: `appendix_d_library_test` | guide §2.9, §8.3, §8.5 | C1 | `intersect` 7, `Ets.insert`/`lookup`/`member`/`delete`/`drop` 16 |
      | C4 | what the library lacked (step 6, G8) | E.0 rule 4 and shape rule 5, E.1, E.3, E.5, E.6, E.16 | `mergeWith`, `trimStart`, `trimEnd`, `Char.isAsciiDigit`, `Terminal.columns` over a width table in `terminal.ern`, `Io.show` with the emitter's case; the shell's region and `libs/markdown` use `columns` | `ern_stdlib_tests`, `ern_doc_tests`, `values_test`, `ern_emitter_tests`, a wide glyph in the terminal harness | THIRD_PARTY_LICENSES (Unicode's data), `shell_design.md`'s open question, guide §2.9, `examples/repl.ern` and `webserver.ern` | D1, B8, B10 | `Only the system modules carry`, `It is not a composition`, `One character is one column`, `c >= '0' && c <= '9'`: 7 |
      | D1 | code-point order, `trim` by `Char.isSpace` (step 9) | §3.10, E.5, E.6 | `ern_string` trim; `compare` and case mapping already conform | `string_test`: U+00A0 and U+3000 stripped, U+200E kept | `string.ern` docs, `test/session/basic.out` | none | `without leading and trailing` 3 |
      | D2 | how a program ends (step 9) | §8.6, §11.2 | `ern_cli` a signal handler exits 128 plus the signal; `run_main` prints `killed` | `ern_cli_tests`, `ern_integration_tests` status 143, SIGHUP 129 | guide §6.3, §9.2 | none | `The program ends when main returns or faults`, `exits with status 0 when`: 3 |
      | D3 | standard input is UTF-8 (step 9) | §8.2, E.1 | `ern_rt`'s reader reads bytes and checks UTF-8 | integration under `LANG=C`: UTF-8, CRLF, no last line feed, invalid bytes | `io.ern` doc, guide §1.3 | B8 | `without its line feed` 3 |
      | D4 | `Float.toString` (step 9, L7) | E.9 | `ern_float:to_string`, `ern_show:float_text` | `float_test` at 0.0001, 1.0e15, 1.0e16, 1.0e-5, each read back | `float.ern` doc | none | `shortest decimal that reads back` 2 |
      | D5 | the shell's commands in §11.2 (step 9) | §11.2 | `shell/shell/command.ern` | new mirror: the paragraph against the command list | `shell_design.md`, guide §1.2, §9.3, `shell/README.md` | A1, B5 | `The shell's help lists the commands` 1 |
      | D6 | `////` is a comment (step 9) | §2.2, App. F | `ern_lexer`; `emacs/ernest-mode.el` | `four_slashes_is_a_doc_line_test` inverts; `emacs/test/colour.el` | `docs/emacs_mode.md` | none | `` `///` to end of line `` 2 |
      | D7 | `ern test` streams, a deadlock one test's fault (step 9) | §11.2 | `ern_cli` `run_tests`; `ern_rt` faults the running test | `ern_cli_tests`; new: a deadlocked test then a passing one | guide §9.2, `shell_design.md`, `shell/README.md` | A1 | `It prints each test's name` 1 |
      | D8 | a function value foreign code returns is checked at each call (a standing gap) | §7.4 | `ern_boundary` wraps such a value so each call's result is checked, as a proxy checks each message | new: a foreign function returning a function whose result is ill-typed faults at the call with `Fault("foreign return does not match T")` | the plan's standing gap goes | none | `is not checked when it is called` 1 |
      | E1 | the holders of `it` freed (step 8) | none | `ern_shell` holders recycled as inputs are, each input's dependencies recorded, `forget` purges a holder | `ern_shell_tests` the unload tests' "not covered"; new: a holder freed, one kept by a later declaration, 2,000 inputs measured | `shell_design.md` `A session never shrinks`, `architecture.md` if the module splits | B5, A1 | `A session never shrinks`, `frees nothing`, `holder of it`: 4 |

      **Added by sub-step 4's sweeps**, each place a row's commit also rewrites, and what the
      cold read's fixes added to a row's work:
      - A1: the synopses' `[--load-path dir]...`, `ern doc`'s and `ern test`'s options, and
        `--short-errors` on `ern build`, `ern doc` and `ern shell` (§11); this plan's own
        lines on `ernc`, its Reference table, and `ernc --format`; `architecture.md`'s tools.
      - B1: the lines of guide sections 2.1, 5.5, 6 and 6.3 that say a fault ends its process.
      - B2: `:load` and `:reload` evaluate a module's bindings in a process of the shell's
        own, a faulting binding loading nothing (§11.2); guide sections 1.2, 3.3, 7.3 and
        §10; `shell_design.md`'s "requires a pure initializer"; `code_distribution.md`'s
        registry sentence.
      - B3: `Fault("callee had ended")` for a callee ended before the call (§6.6, §7.4); the
        "three cases" of guide sections 5.2 and 6.3, and guide section 4.2.
      - B4: the `fault: ` of guide section 5.4 and of the answers to the exercises;
        `architecture.md`'s `fault: Msg`.
      - B5: `Process` is the prelude's (§9.1), its operations `process.ern`'s; `info` is
        `None` for a process on another node; sockets and listeners are in `live` and
        `faults` (E.18); guide sections 2.9 and 3.5; `language_feedback.md`'s head.
      - B8: `shell/README.md`'s prelude types, `examples/snake.ern`'s header,
        `shell_design.md`'s `Event`, `Pasted` and bare `Sys`, `stdlib/io.ern`'s header, the
        guide section 0 on printing, and `language_feedback.md` item 16.
      - B9: every function that waits on an ended socket or listener faults as a call does,
        and a listener lives until it is killed (E.18).
      - C1: `String.trim` is Ernest over its halves, and the conversions between text and
        numbers are primitives by rule 1 (E.0, E.5).
      - C3: `libs/ets`'s header, whose `drop` is unprefixed.
      - C4: `String.lines`' See also gains `split`, and its doc says `""` has no lines;
        `architecture.md`'s `ern_io:debug/2`; `shell_design.md` on `Io.debug`.
      - D2: `architecture.md`'s exit status.
      - D7: guide sections 6.3 and 7.1 on a deadlock and the order of tests;
        `architecture.md`'s `run_tests/3`.
      - B7: "the function that spawned it" in guide sections 5.2 and 6.3.

      What the readers found against the code, each a row's work: D2's three defects, SIGHUP
      ignored, SIGTERM exiting 0 and a killed entry printing `fault: 'Killed'`; D1 built but
      for `trim`, which keeps U+00A0 and U+3000 and strips U+200E; D3's garbled line under
      `LANG=C`; D4's `1.0e15`, where plain digits are decided; and D6 inverting a test the
      log's *Warts Audit* added to follow the report as it then stood, which it still does.

      **The order of sub-step 6**, a group a `make test`: first D2, D6, D7, D8, B6 and B7, the
      rules that need nothing; then the library, C1 with C3, C2, D1 and D4; then the
      processes, B1, B3 and B2; then the system modules, B8, D3, B9 and B10; then B5 with
      B4, as G11 builds them; last C4, D5 and A2. A1 is sub-step 5, and E1 goes with
      sub-step 7.

      **Decided with the ledger**, each argued in the log's *What the Ledger Found*:
      - **L1, `restarting`'s function is never reply-carrying.** It runs its function more
        than once, so a captured `Reply` would be answered more than once; §6.6 says so and
        the checker refuses it.
      - **L2, an initializer with an effect is not generalized.** A top-level `let` whose
        initializer calls a process-only function (§3.9) is typed as a block `let` is, a
        variable left unresolved a type error at the binding; a pure initializer generalizes
        as now. §4.6.
      - **L5, a system reference is a `let` over its module's private `foreign fn`**, an
        initializer with an effect under B2, evaluated at each start; the grammar gains
        nothing.
      - **L6, a subscription to faults is not a source** (§8.6): a fault comes only from a
        process that runs, so a program in which none can is still deadlocked.
      - **L7, an exponent carries a sign only when negative**, `1.0e16` and `1.0e-5`, as
        §2's literals are written.
      - **L8, §3.9's rule for a `foreign fn` that takes a function stays**, though after C1
        no `foreign fn` of the standard library takes one: it types a library's or a
        program's.
      - **Under E.0 rule 7, the moved types lose their module's name**: `ClockMsg` becomes
        `Clock.Msg`, `FsMsg` `Fs.Msg`, `TerminalMsg` `Terminal.Msg`, `TcpMsg` `Tcp.Msg`,
        and `ListenerMsg`, `SockMsg`, `StdinMsg` and `OutMsg` keep their names in `Tcp` and
        `Io`. `Event` and `Size` go to `Terminal` and `Entry` to `Fs`, since §9 keeps in
        the prelude only a type the language's rules name or one whose module is named
        after it; `Path` stays by the second. §9's third criterion, a type a system
        reference speaks, goes.

      - **L3, a socket lives until `Tcp.close`**, decided with the user: after its
        connection closes every read answers `Left(Closed)`, `Tcp.close` ends its process,
        and a read after that faults under B3; a socket never closed lives until the program
        ends. E.18; the log's *A Socket Lives Until It Is Closed*.

      - **L4, `IoError` becomes `Io.Error`**, decided with the user: one error type for
        every system module, so that E.0 rule 8's `Timeout` stays one constructor and `<-`
        joins a file and a socket, placed in the module named for input and output. E.1,
        E.15 to E.18, §9 and §9.3; the log's *The Error of Input and Output*.

   3. **Done 2026-09-26: every report change in one pass**, Appendix E among them, as a
      commit of the report alone, with `make xref` and `make test-docs` green and the count
      in the log's *Measure*. Every row of the ledger is in the report, and the new Appendix
      E.21 is `Process`'s; Appendix B's ping-pong spawns its monitored process with
      `spawnMonitored`. The mirror tests that read the report, `ern_prelude_tests`,
      `ern_guide_tests` and Appendix D's, now fail until sub-step 6 builds each row, which
      is the order this step chose. Decided in the pass where the report was silent, each
      argued in the log's *The Report Pass of Step 10*:
      - **A system reference is private to its module**, and a module's message types are
        private but `Tcp`'s `ListenerMsg` and `SockMsg`, which are exported abstract. No
        program can name a system process, so `kill`'s refusal of one leaves §6.9 and §7.4.
      - **`restarting(limit, f)` is a function**, run wherever it is called: a fault in `f`
        runs `f` again in the calling process, and after `n` restarts within `t`
        milliseconds the next fault ends it (§6.9).
      - **`ern run`'s fault line is the shell's**, `Site faulted: cause`, and `Site faulted,
        restarted: cause` for one after which the process restarts; the entry process's
        fault takes the same form, and `fault:` goes (§11.2).
      - **`ern test` runs its tests one at a time**, in the order the module declares them,
        which a deadlock that is one test's fault needs (§11.2).
      - **A line of standard input that is not UTF-8 faults the process that asked for it**,
        `Fault("the standard input is not UTF-8")` (§8.2, §7.4).
      - **A process holds one subscription to faults**, a second replacing the first, as it
        holds one to the terminal (E.21).
   4. **The whole report read cold**, with the two sweeps, run 2026-09-26: a reader who took
      no part read the report alone and found 37 places, the guide was read against the
      report and every other document against the report and the code. The guide's and the
      documents' findings that a row's build will fix are in the ledger, under *Added by
      sub-step 4's sweeps*; the rest were fixed at once, among them six older errors of the
      guide, `architecture.md`'s reaper table, and this plan's own stale lines. Decided in
      the report where it was silent or wrong, each argued in the log's *The Report Read
      Cold After the Pass*:
      - **`Process` is the prelude's**, as `Map` is, and `process.ern` provides its
        operations: E.0 rule 7 refuses a type named for its module, `Process.Process`, and
        §9's second criterion already names it (§9.1, E.21). G2's placement is corrected.
      - **A call to a process that had ended before it** faults a `callForever` caller with
        `Fault("callee had ended")` (§6.6, §7.4).
      - **Every function that waits on an ended socket or listener faults as a call does**,
        and `Left(Closed)` is a live socket's answer after its connection closed (E.18).
      - **`:load` and `:reload` evaluate a module's bindings** in a process of the shell's
        own, and one that faults loads nothing (§11.2).
      - **Shape rules 1 to 4, 7 and 9 reach a library outside the standard library**, and the
        two lists of E.0 are cited as rules and shape rules.
      - **The conversions between text and numbers are primitives**, as rule 1 already
        admits `Int.toString`; `String.trim` is Ernest over its halves (E.0, E.5).
      - **The terminal's interrupt goes to every subscriber** while the terminal is claimed
        for keys (§8.2), and sockets and listeners are foreign processes but not system
        processes, so `Process.live` and `Process.faults` include them (E.18).

      **Four decisions for the user**, taken before sub-step 5, each a feedback item no step
      had placed: whether `examples/webserver.ern` waits for `libs/http` or keeps a subset
      it names (item 55, which the build's B8 and C4 touch); whether E.16 gains the terminal's
      control sequences or a library owns them (item 56); whether E.1 gains a read of bytes
      (item 57); and whether `Tcp` gains a close for a listener (item 58, found by the cold
      read).
   5. **The toolchain first.** `ern build` and its siblings replace `ernc` before anything
      else is built, since the rename reaches the Makefile, the tests, the README, the guide
      and the Emacs mode, and every later test is then written against the final commands.
   6. **The build, in the ledger's order**, one decision or tight group a commit, each with
      its tests and with the sentences its row's grep finds removed in the same commit;
      `make test` at the end of each group.
   7. **The guide's section on services, and the closing sweep.** The section teaches a
      service as a top-level binding, `restarting` and its `RestartLimit`, the `start` and `service`
      pair for tests, a call that ends when its callee faults, and `fault`; §6.4's sentence
      that a restarted service must hand out its new address goes. The section on the
      supervisor is MVP 2.66's. `ern_shell`, its doors to the runtime gone, is measured
      again and whether its `:browse` and `:doc` leave it is decided (step 8, *Where the
      Toolchain's Modules Split*). The holder module of each `it`, its value and its
      interface are freed once no module the session keeps refers to them, each input
      recording what earlier inputs it depends on as `ernc` records a module's; measured in
      step 8, 2,000 expressions still grow the code by 8 MB and the process heaps by 16 MB,
      nearly all of it the holders and the environment they lengthen (*The Shell Lets Go of
      an Input*). The document sweep closes the step.

---

## MVP 2.66 (the standard library's `Supervisor`), about three days

MVP 2.65 step 5 decided what a supervisor is (question 6; the log's *A `Supervisor` in the
Standard Library, and `fault`*), after the claim of 2026-09-13, that a supervisor is fifteen
lines of `spawn`, `monitor` and `receive`, met a restarted child's new address. This item
builds it, after step 10 of 2.65 has built `restarting`, `fault`, the service binding and
the fault report it stands on.

- **`stdlib/supervisor.ern`**, in Ernest but for one shim, the in-place restart of a child,
  which only the host can do. Appendix E gains its section, with its module page and
  examples as E.0 rule 6 asks.
- **`examples/supervisor.ern`**, three long-lived services under one supervisor as
  top-level bindings, faulted on purpose, read back against principles 1 and 2 and E.0.
  The guide gains a section on the supervisor, after the one on services: a tree as
  top-level bindings, the three strategies, the group's limit, and stopping.
- **Two things to settle in the build, report first where the report is silent.** A
  supervisor that faults by a defect of its own, not by `fault`, leaves its children
  running, since nothing owns a process; a watcher the module spawns beside it, holding
  the children's addresses and killing them on its `Down`, is written in Ernest. And
  stopping a child is `kill`, which gives it no chance to finish; a child that must
  finish carries a stop message in its own protocol, which the module cannot impose.

---

## MVP 2.7 (a program started from a command line, and the appendix of libraries), about a week

What a command-line program needs, report first: the program's arguments, a
`List(String)`, and its environment, bound by the runtime as a system module's references
are (§8.2), in a module this item names, and an exit status in §8.6. The guide's cold read asked for the arguments at once
(`language_feedback.md` item 16, 2026-09-24); an entry point that takes a `List(String)` is
weighed against the binding before the report changes, and parsing options from the list is a
library's, by E.0. With the environment, the shell reads `NO_COLOR` in Ernest, where its front end
reads it today.

**Memory, read for what only grows.** Noted 2026-09-26. The line it draws: waste the garbage
collector reclaims is allowed, and growth over time that no collection reclaims is a defect,
in the runtime, in the toolchain and the shell, and in Ernest code alike. The Erlang code under `erl/` and
every Ernest program in the repository, the standard library, the shell, `libs/` and
`examples/`, read again for memory that is kept with no need, capped or not, as the table of
ended processes was (MVP 2.65 step 8, *A Process Is Watched From Its Start*): a table, a
cache, a list or a map that grows with the work done rather than with what is alive. The
reading is checked by measurement: representative programs, the examples, the shell under a
long session, a server under many requests, each run under load with the host's memory, its
atoms and its processes measured before and after, as the shell was in step 8, whose
per-input growth reading alone had not shown. Each finding is fixed, or decided with the user
where the fix changes what the language promises. A cap on a list, a table or a cache is
never the fix, and every cache found is weighed for what it holds and when it lets go
(CLAUDE.md, *Memory that no collection reclaims is a defect*).

**Atoms, counted.** Noted 2026-09-26: how many atoms the runtime and the toolchain make while
a program runs, measured, since the host never collects one and a node dies at about a
million: those the emitted code makes, those a shim or a system module makes from a value it
is given, and those the shell makes per input, which step 8 of MVP 2.65 cut from four to the
two of `it`'s holder, and step 10 to none. Each source found is bounded by what the program
holds, or decided with the user.

**A simple log.** Noted 2026-09-26, to be decided in this milestone: `ern` writes what it
prints to standard error, the fault reports first among them, to a file as well, and
perhaps only there. A very simple logger, the smallest thing that keeps a long-running
program's faults; whether it is an option to `ern run` or a system module's binding (§8.2) is
the decision. `Process.faults` (MVP 2.65 step 5, item 28) is beneath it, so the log of faults can
be a process written in Ernest that subscribes and appends.

**The report lists the libraries that exist**, `libs/ets` and `libs/markdown`, in a new
informative appendix, one section per library with its signatures and contracts, and a mirror
test holding each compiled interface equal to it, as `ern_prelude_tests` holds the prelude to
Appendix E. Third-party libraries are not listed; Appendix D is what they follow.

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
  question rather than a protocol question. MVP 2.65 step 5 decided it: a service is a top-level
  binding, and a peer's service is found by reading its binding on the peer. Built here:
  **`Peer.find(name, fn() = M.service)`**, and §8.7's two sentences on a node's own
  initialization and on a definition that differs by hash. Its failure type is decided
  with item 14, `remote`, since both evaluate a pure function on a peer; `Peer` as a
  namespace beside the constructor `Peer` of `Where` is checked against §4.2. The note's open question 11, a way to stop an uncooperative
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
  milestone, before `remote` is built over peers. What `remote` is for: a synchronous call
  that evaluates a pure function on the node with the lowest load among those that accept
  remote computation, the runtime choosing by load. Once `spawn(Peer(name), f)` ships code
  and answers across nodes, `remote` may be a second way to do what a spawned process that
  answers does. If it goes, §6.7, §9.4, `RemoteError`, the `"remote-peer"` flag and the
  guide's §8.1 go with it, and the bullets above that build it are rewritten. Decided with
  it, item 25, the suggestion to spawn a process where the load is lowest:
  `spawn(Remote, f)`, a third `Where` that gives the runtime's choice of peer to a process,
  with which `remote` is a composition; the flag would then admit any process and not only
  a pure function. `Peer.find` (MVP 2.65 step 5) depends on the outcome: if `remote` stays
  and takes a named peer, `Peer.find` is its composition and goes by E.0 rule 4; otherwise
  `Peer.find` stands, as the gate of step 10 kept it (G6).
- **Two more places the protocol note disagrees with the report, found 2026-09-24 in the
  closing sweep of MVP 2.61**, also decided before building: the note's `spawn_at` never
  fails at the call and returns a dead address, where §6.2 faults the caller on an unknown or
  unreachable peer; and the note's `Down` is `Exited | Crashed(Text) | NoProcess |
  Unreachable` with no `site`, where §9.3 and §6.9 have `Down(reason, site)` with
  `Returned`, `Killed`, `ProgramEnd`, `Fault(String)` and `Unknown`.
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
`ern_iface:hash/1` already hashes a canonical interface; whether it grows into the
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

## MVP 3.2 (the libraries, as they are wanted)

Decided 2026-09-25: the libraries not yet written wait, and each is written when our work
needs it, MVP 3.0 and 3.1 among that work, when someone asks for it, or when we want it (the
log's *Libraries As They Are Wanted*). Each is an Ernest source root
under `libs/<name>/` that a program adds with `--load-path`, with `stdlib/`'s test discipline,
documented in one pass to [`module_doc_template.md`](module_doc_template.md) with its executed
examples as its first user, and a section in the appendix of libraries. Own repositories
later, when there is a package story. Named so far:

- **`libs/json`**, pure Ernest: a `Json` type, a parser over `String` returning `Either`, a
  printer.
- **`libs/base64`**, a shim over `base64`.
- **`libs/tls`**, a shim over `ssl` and `public_key` with their manual pages open: `listen`,
  `accept`, `connect`. Whether it answers `Tcp`'s `Address(SockMsg)`, its foreign process then
  speaking an encoding private to `Tcp` (E.18), or a socket type of its own with its own
  `read`, `write` and `close`, is decided when it is written. Certificate verification is the
  caller's to ask for.
- **`libs/http`**, Ernest over `Tcp` and `Tls`: request and response types, a client. No
  server; that is the webserver example's job. With it, `examples/fetch.ern`, a command-line
  tool that fetches JSON over HTTPS and prints a report, since a paper program travels with
  the stack it needs, and `Time` in Appendix E over the clock's milliseconds, which only it
  wants so far.
- **`libs/regex`**, a shim over `re`, a library and never syntax: `Regex.compile : (String)
  -> Either(RegexError, Regex)` with `Regex` a foreign type, so a bad pattern is a value the
  program handles, as Gleam's `gleam_regexp` does.
- **`libs/crypto`**, a shim over `crypto` for hashes, HMAC and random bytes; **`libs/uri`**,
  pure Ernest or a shim over `uri_string`; **`libs/zlib`**, a shim over `zlib`.

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
- **`e_bits` and `p_bits` are in no example**, so the AST coverage test excludes them
  (2026-09-19).
- **A label at the first use of the variable whose type a mismatch names** was planned for
  §3.4's placement work and not built (2026-09-18).
- **A function value that foreign code returns is not checked when it is called**, though
  §7.4 says its result is checked against its declared result type (found by the cold
  read's check, 2026-09-25). The fix is the address proxy's shape: the boundary wraps such a
  value so that each call's result is checked, as a proxy checks each message. With it goes
  the one way an ill-typed value reaches Ernest arithmetic, where the host's error is
  reported as `Fault("division by zero")` whatever the operator was; only a zero divisor
  gives that cause. Built in MVP 2.65's step 10, the ledger's D8.

---

## Done

A paragraph a milestone: what it delivered, and where its reasons are. The work in detail is
in the history and the log's dated entries; what binds now is the report's, the
architecture note's and the style guide's.

### MVP 1 — the chain (done 2026-09-18, tag `mvp1`)

Parser, types and BEAM proved with the report's language unchanged, a subset accepted: no
`Float`, no ownership rule for abstract types, no foreign code, no `Tcp`, no distribution,
and exhaustiveness checking from the start. A hand-written lexer and a direct
precedence-climbing parser, Hindley-Milner with an effect slot (§3.9), the reply discipline
(§6.6), one Erlang module per Ernest module, and one diagnostic record from every stage
(§11.5); [`architecture.md`](architecture.md) says how they are arranged, and the log's
entries of 2026-09-17 and 2026-09-18 why. The report was pared the same day, 13,084 words
to under 8,000, and read back the next, which restored five lost rules; the rule since is
in CLAUDE.md.

### MVP 2 — the rest of the report on one node (done 2026-09-19)

Each item was a rule MVP 1 refused or did not check: `Float` and operators on user types
(§3.1, §4.8, §5.1); `foreign fn` and `foreign type`, checked at the boundary by
`ern_boundary` (§4.7, §8.4); bitstrings (§5.11); pattern alternatives (§5.9); `Io.debug`
(E.1); raw strings (§2.5); abstract-type ownership (§4.4); the reply discipline through
function values (§6.6); `Deadlock` as global quiescence (§8.6); and nine points from the
consistency pass. The log's entries of 2026-09-19 hold the arguments.

### MVP 2.5 — a complete standard library (done 2026-09-20)

Twenty-one modules in Ernest under E.0's rules, a shim only where its first rule admits one;
the system processes, each used through its Appendix E module and never by `send`; the
checker reading the standard library's compiled interfaces as any dependency's; the shape
of a module's documentation, [`module_doc_template.md`](module_doc_template.md), and the
documentation in the `.erc`'s EEP 48 chunk; four paper programs, three under test. `Tcp`
was measured at 1.8 times raw Erlang with a process per socket, and the processes kept.
The naming of the toolchain, `ern_<thing>` and `ern@<namespace>`, was done on the way; the
log's *One Token for the Project* holds it. Erlang's standard library, read module by
module, is under "Reference".

### MVP 2.9 — an Emacs major mode (done 2026-09-23, out of order)

`emacs/ernest-mode.el` and its tests, run by `make test-emacs`;
[`emacs_mode.md`](emacs_mode.md) owns the mode. It gave the style guide six indentation
rules, the sources were reindented to them, and a test mirrors the mode's word lists
against the lexer.

### The report read as a Wirth report (done 2026-09-23 and 2026-09-24)

A standalone reading of the report as a Wirth report and against §0. Its plain errors were
fixed and about thirty issues decided one at a time, each a report change with its entry in
the log. The largest: a statement other than a block's last has type `Unit`, and a value is
discarded with `let _ = e` (§5.4); `Ets` left the standard library for `libs/ets` (§10, E.0
rule 1); a fault is a death with `Fault(cause)`, every cause listed in §7.4, a deadlock the
entry process's (§8.6); `Prelude.X` reaches a shadowed prelude name (§4.2); a parenthesized
right side of `|>` is a value (§5.7); §9 states what makes a type the prelude's; a
`String`'s unit is a grapheme (E.5); the bit syntax dropped `bits` and `native` (§5.11); and
§6.6 was rewritten top-down. A last reading closed it, finding seams and no new rule.

### MVP 2.61 — the guide as the user's document (done 2026-09-24, out of order)

The guide rewritten to teach Ernest on its own, in nine steps, each a stop: every example
checked by `test/ern_guide_tests.erl`, an opening that shows four mistakes `ernc` finds,
one running example, a section on failure with a supervisor, pages for the tools and for the
Erlang programmer, a two-reader sweep, and a cold read by a reader new to Ernest. It changed
§11.2 and §11.5 and fixed two defects of `ernc` and `ern`; the log has each.

### MVP 2.6 — the shell (done 2026-09-25)

The shell, an Ernest program under `shell/`, designed in
[`shell_design.md`](shell_design.md), which owns the design, and specified by §11.2; the
guide to its code is [`shell/README.md`](../shell/README.md). Five checkpoints, each a stop:
expressions (2026-09-20); bindings, the commands, fault reports and the startup files
(2026-09-20); the terminal and its live region (2026-09-21); the line editor, the history
and its search, multi-line input and paste (2026-09-21); and completion and documentation
(2026-09-24). Then a closing sweep by two readers, a session of real use whose thirteen
findings each became a rule of §11.2 with a regression test, an independent review whose
five more did the same, and a last sweep of the documents. On the way it built
`test/ern_pty.py`, the pseudo-terminal harness every terminal test runs through; turned
`Keys` into `Terminal`; made the pure parts modules of their own, each tested by
`ern --test`; stated the rule for `foreign` now in CLAUDE.md; split `make test` into areas;
and found about twenty defects in the toolchain, none of them the shell's. The log's
entries from 2026-09-20 to 2026-09-25 hold every argument.

### `libs/markdown` — a CommonMark renderer (done 2026-09-25, now under MVP 3.2)

Pure Ernest, about five hundred lines: `Markdown.parse` reads CommonMark 0.31's blocks and
inlines, and `Markdown.render` lays them out at a width, with the terminal's styles or as
written; where it is simpler than the specification, its doc block says so. How a heading
looks at a terminal is policy inside a namespace of its own, so E.0 puts it under `libs/`.
The shell renders `:doc` and `Shift-Tab` with it. Its place in the report's informative
appendix of libraries is MVP 2.7's, with `libs/ets`'s.

### The code read back after the shell (done 2026-09-25)

Every line of Ernest under `shell/`, `stdlib/` and `libs/`, and every line of Erlang under
`erl/`, read for what goes against the principles, for clumsy code, and for defects; about
twenty-five defects fixed, each with a regression test, and the report's §2.3, §7.4 and §11.2
changed first where a fix needed a rule. The shell gained `Shell.Command` and
[`shell/README.md`](../shell/README.md). The log's *The Code Read Back* has the decisions,
the feedback list the Ernest questions it raised, and MVP 2.65's step 8 the Erlang ones.

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
| `e_var` | a local: the Erlang variable; a top-level fn as a value: `fun f/N`, and another module's `M:'$fun'(f, N)`, a fun of the version current when it is taken (§11.2); a top-level let: `name()`; a prelude name: table below |
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

**Prelude name to Erlang** (§9.4 to §9.7, Appendix E). Called, or taken as a value: a
runtime name as `fun ern_rt:F/A`, and a standard library module's through `M:'$fun'(F, A)`
since 2026-09-25, as another module's function is (the `e_var` row).

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
| `erlang` BIFs | the language; `Int`, `Float`, `String`, `Char` | `spawn`, `self`, `send`, `monitor` as §9.4 and §9.5; `abs`, `min`, `max`, rounding, `toString`, `toFloat`, the bit operations | an exit status for §8.6, the arguments and the environment, MVP 2.7 | `register`, `whereis`: §6.5 has no registry. `link`, `exit`, `throw`, `catch`: §7 and §6.9. `term_to_binary`: MVP 3's transport. `phash2`, `md5`: a hashing library. `make_ref`: identity is a `Process` (E.21). `iolist_to_binary`: `String.fromList`, `<>`. `memory`, `system_info`: the runtime's |
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
| `gen_tcp`, `inet`, `socket`, `ssl` | `Tcp` | E.18 | `Udp` as its own module, a later MVP | socket options: tuning is a library's. TLS: `libs/tls` in MVP 3.2 |
| `ets` | `libs/ets` | Appendix D | | match specifications, `qlc`: `Ets` is a key-value table |
| `os` | a system module, MVP 2.7 | | the environment and the arguments, MVP 2.7 | `cmd`: a door to the system a program opens itself, MVP 3 at the earliest |
| `calendar` | `Time` | | a `Time` type and its parts, MVP 3.2 | formatting: a format is the program's, rule 3 |
| `binary` | `Bytes` | E.20, and `<>` | | `split`, `match`, `replace`, `encode_unsigned`: `<<...>>` and the `Int` operations |
| `array`, `queue` | | | | `List` and `Map` give both, rule 4; a persistent array is a library |
| `eunit` | `Test` | §9.3's `Test` and `TestResult`, run by `ern --test` (§11.2) | | |
| `base64`, `json`, `uri_string`, `re`, `crypto`, `zlib`, `dets`, `digraph`, `sofs`, `erl_tar`, `zip`, `disk_log`; the applications `ssl`, `inets`, `xmerl`, `public_key`, `asn1`, `mnesia`, `snmp` | libraries | | | each a namespace of its own on Appendix D's pattern, never stdlib |
| `observer`, `dbg`, `cover`, `debugger`, `dialyzer`, `edoc`, `common_test`, `syntax_tools`, `parsetools`, `argparse`, `escript` | | | | tooling: `ernc --doc`, Ernest's own types, the compiler, `ern`; an argument parser is a library |
| `gen_*`, `supervisor`, `proc_lib`, `sys`, `logger`, `application`, `code`, `rpc`, `erpc`, `global`, `pg`, `net_kernel`, `persistent_term`, `atomics`, `counters`, `init`, `heart`, `os_mon`, `wx`, `erl_*`, the shell | | | | a function with a mailbox type, the standard library's `Supervisor` (MVP 2.66), `send` to a sink, MVP 3's distribution, the runtime's internals, `ernc` and `ern` |

Gleam's `gleam_stdlib` v1.0.5, Elixir's core and Haskell's `base` were read the same way, and
what they have that this table does not take is a position, not a gap: `gleam/order`,
`gleam/pair` and `gleam/function` (patterns and compositions), `string_tree` (a builder
BEAM's binary append makes unnecessary), `gleam/uri` (a library), `dynamic/decode` (`Foreign`
and a JSON library), `string.inspect` (no universal printer), `bool.guard` (`<-`); Elixir's
`Stream` (§5.1 is strict, a lazy source is a process) and `Keyword` lists (`Map`); Haskell's
type classes (`toString` per type, `==` structural, `compare` per type).

### Tools, and what was decided before the start

Erlang, OTP 29 (raised from 27 on 2026-09-20), Makefiles in the style guide's shape; EUnit
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
