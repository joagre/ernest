# Findings of the principles review

The findings of the principles review, run on 2026-09-30 as [`principles_review.md`](principles_review.md) says, on commit `57b8356`: P over §0 to §11 with Appendices A to D (P1) and over Appendices E to G (P2); K, the cold reader; W, over the guide; and L over the log in two halves, to 2026-09-19 (L1) and after (L2). R is the release review's report reader, whose parked list stands under its own heading below. A line carries its decision: **sentence**, a rule added to §0 or E.0; **report**, a rule changed or removed; **kept**, with the principle that keeps it; **guide**, the guide changed where its rule stays; **fix**, a defect or a disagreement between two sections, fixed in the milestone's edits; **log**, an entry marked superseded or its reason restated; **later**, to the log's *Later* with what would change it; **2.99b**, taken by that milestone's item; **dropped**, with the reason; and **round 1** or **round 2**, not yet decided, the sentences first. Each reader's whole list stands below the lines, condensed to a line a finding; the readers' programs are in the session's scratch directory.

## The families

Each family is the decisions one sentence would decide. A line names the readers that found it and the sentences they propose; round 1 decides the sentence, round 2 the family's rules under it. The families are ordered by how many readers reached them independently.

- sentence — decided 2026-10-01, §0's *The host* (the log's *The Host Paragraph*); the family's rules in round 2 — **The host's semantics.** No sentence says when the host's rule is Ernest's; the log takes it, hides it, overrides it and refuses on it, each with a reason of its own, and cites principles 1, 3 and 5 for both sides (L1 family 1, 8 of 11 undecided; L2 family B, 14 of 21; P1-63, P1-70, P1-71, P1-75; K-50). `Float`'s domain, the guard-fault rule and `Random`'s generator were each decided both ways under it (L1-2, L1-3, L1-138, L1-150). Two sentences proposed: L1's, the host's rule is Ernest's where its outcome is a value or a fault the program sees, and where the host would be silent Ernest checks the value or refuses the form; L2's, a rule of the host is Ernest's only by a sentence of the report, and where the report is silent the runtime carries the host's rule without letting it show.
- sentence — decided 2026-10-01, principle 1's second to fourth sentences (the log's *The Reader Principle 1 Means*); the family's rules in round 2 — **Which reader principle 1 means.** §0's reader "knows the rest of Ernest"; the log cites principle 1 about 25 times for what a reader of Rust, Gleam, Elm, Haskell, Python, Erlang or OTP expects, and the neighbours disagree, so which one the entry chose decided (L2 family A, 19 of 23; L1 family 3, 7 of 9; P1-73). `Void` then `Unit` by the same principle in two days (L1-140); `Int.rem` argued both sides (L2-3). Three sentences proposed, each a second sentence of principle 1 naming what else the reader knows: Hindley-Milner as Standard ML and OCaml state it and processes as Erlang has them (P1); the Erlang runtime beneath, then the ML family its types come from (L2); the reader's other languages where two names read alike within Ernest (L1).
- sentence — decided 2026-10-01, §7.4's opening and E.0 shape rule 4 (the log's *A Failure's Shape*); the family's rules in round 2 — **A failure's shape: fault, value, clamp, refusal, and whom it lands on.** §7.4's list grew from one deliberate exception to eight with no criterion; an `Int` out of range gets five shapes, a fault from `Os.exit`, `Left(Other)` from a port, `None` from `Bytes.fromList`, 0 from a time, 1 from a window; `Terminal.size` and `Terminal.subscribe` answer one cause in two shapes (L1 family 4, 6 of 9; L2 family G, 6 of 19; P1-15, P1-80; P2-4, P2-17, P2-101; K-28, K-43; L2-24, L2-29, L2-30, L2-32). Sentences proposed: an operator or a construction the grammar gives faults, a function answers, and a fault stands only where a `Float` leaves its finite range (L1, P2-101, K-43); a refused request faults the process that asked, and a failure no request stands behind faults the entry process (L2, for §7.4); an argument outside its range answers `None` or `Left`, a floor is named by the function's section, and nothing is corrected in silence (L2, P1-80). With it `Io.Error`, one type for six modules carrying the report's own causes as text (P2-2).
- sentence — decided 2026-10-01, E.0 shape rule 8 restated (the log's *What Waits With a Limit*); the family's rules in round 2 — **What waits with a limit, what without, and what answers at once.** E.0 shape rule 8 names twenty-three functions in three kinds because no criterion says what waits: `Tcp.read` takes milliseconds and `Os.read` does not, `Fs.write` does and `Tcp.write` does not; `Os.start`'s bound a life, `removeAll`'s a whole, `Fs`'s a call (L1 family 7, 3 of 7; L2 family E, 5 of 18; P1-20; P2-8, P2-9, P2-34, P2-50, P2-105; K-44; W-11, W-12). The deciding sentence stands in the log alone (L2-23). Proposed: a stream of the program's own is waited on without a limit, anything another party holds for the milliseconds given, which bound the one request, and a refusal is answered at once (L2); K-44's restatement by what is waited for, with `Os.start` the one exception kept; `Address.callForever` opting out by name (L1). With it the prelude's `Address.call` answering `None` where the library answers `Left(Timeout)` (P1-20, P2-34), and the blocking send refused between the program's processes on principle 3 and made the rule for eight system writes (L1-64, L1-146).
- sentence — decided 2026-10-01, principle 2's fourth and fifth sentences (the log's *When a Second Spelling Enters*); the family's rules in round 2 — **Which forms enter the language: a second spelling, a literal form.** Principle 2 as written refuses every second spelling and the log admitted half: `|>`, `as`, `export`, raw strings, `0x` and `1_000` in; `^x`, `f(_, y)`, `use` and list spread out, by a count since abolished or by nothing (L1 family 2, 8 of 13; L2 family A's literals; P1-34, P1-83; W-19). Proposed (L1): a second spelling enters when the first would nest where the reader reads a sequence or would rebuild what a pattern already holds, and a literal form when the value has no faithful spelling without it. With it the pairs the language keeps: `with Never` beside `with m` (P1-5, P1-74; W-2, W-48), a `match` guard beside a `receive` guard (P1-6, P1-75; W-39), a block `let` beside the prompt's (P1-48, P1-18), and `(e)` meaning something else after `|>` (P1-7, P1-83; K-2).
- sentence — decided 2026-10-01, §4.5's and §4.8's last sentences (the log's *Members, Operators, and No Hidden Argument*); the family's rules in round 2 — **Member or module function, and which operations are operators.** Undecided by the log's own words (L2-26); the built-in operators went member, shim, member, shim in four entries (L2-28, L2-105); `!` was refused on a count and then admitted, the bit operators refused on a count and a collision (L1 family 9, 2 of 7; L2 family F, 6 of 12; P1-9, P1-10, P1-67, P1-79; P2-40, P2-88; K-3, K-5, K-6, K-9; W-4). Proposed: a type's operations are functions of its module, and a member is declared only for what the language resolves by the operand's type, an operator, `compare`, `negate` and a field (L2); the operators are §2.6's closed set, an operation written as one where the reader's languages agree on its symbol and the symbol is free (L1); what one of `==`, `<` and `+` does on a type variable, every one does (P1-79, P2-40, proposed). MVP 2.99b's item 4 holds the first question; the sentence is decided here and item 4 builds on it.
- sentence — decided 2026-10-01, §9's opening (the log's *What the Prelude Holds*), with principle 5's sentences for what a feature costs; the family's rules in round 2 — **Where a thing lives: the language, the prelude, the library.** §9 says what the prelude guarantees and nothing says what it may hold, so `spawnMonitored` and `Address.callForever` stay for a race and a deadlock count while `parallelRemote` and `Int.div` leave on principle 2 (L1 family 8, 3 of 8; L2 family H, 4 of 14; L2-33, L2-34; P1-46, P1-61, P1-62, P1-72, P1-76, P1-78; P2-93). Proposed: the prelude holds a function only where a rule names it or where no function written over the prelude could keep the rule's promise (L2); an operation is the language's when the runtime alone gives it its meaning and the library's when Ernest can write it over the language (L1); the prelude's functions have the library's shapes (P1-78); a feature costs a program that does not use it nothing, no `Local` at every spawn and no `Test` in the prelude (P1-76).
- sentence — decided 2026-10-01, E.0 rules 1 to 4 restated (the log's *What the Library Admits*), with principle 5's sentences; the family's rules in round 2 — **What the standard library admits.** E.0's four rules decide most, and their edges are read against their text: speed refused as a reason and taken for three primitives, `List.sort`, `String.graphemes` and `String.drop`, the last "decided over those numbers" (L2-12, L2-13, L2-89); `Udp`, `Process.restart` and `Event`'s keys gated on a count the preamble abolishes (L2-14 to L2-16); `Random`, `Bytes` and the terminal's text builders admitted by no rule (K-32 to K-34); `isAsciiDigit`, `orElse`, `Float.pi` and `Float.toString`'s thresholds at rule 3's edge (P2-16, P2-18, P2-25, P2-30); rule 1's list, rule 2's copied lists and rule 4's five kept compositions restated so the lists fall out (K-42, K-45, K-46, K-47; L1 family 10; L2 family C, 9 of 27; P2-94 to P2-97, P2-107, P2-108). Proposed: the standard library is Ernest, and a foreign function stands only where the host alone can do the work (P2-94); a primitive beneath an operation Ernest can write is admitted only by a measurement recorded in the log (L2); principle 5 counts the language, and the library is counted by principle 1, where a reader who knows the type looks (P2-95); a published specification is a library's (L1); a form the language's own literals read back is no policy (P2-96); a composition is kept only where its name is the operation a reader looks for (P2-97, K-42); a type the language's syntax builds is the language's, and one only a module's functions build is the runtime's (P2-108).
- sentence — decided 2026-10-01, principle 3's third to fifth sentences (the log's *Compiled, Run, or Silent*); the family's rules in round 2 — **What is refused when compiled, what faults when run, and what is silent.** The rule is stated for one form, a bitstring's constant size (L1-50), and "Ernest has no warnings" stands in the log alone, so a dead clause is an error and an unused binding silent (L2-19), `<<-1>>` a fault one day and an error the next (L2-20, L2-84), an orphan doc block silent beside a misplaced one refused (P1-19), and a block ending in `let` a parse error unstated (K-10) (L1 family 5, 4 of 10; L2 family D, 5 of 16). Proposed: a rule the type decides is checked when compiled and one the value decides faults when run, and a compile-time refusal of a sound program is a rule of the report whose error names what to write (L1); the compiler refuses what the text alone shows can have no effect and accepts the unused without a word, there being no warning (L2).
- sentence — decided 2026-10-01, §6.2's one silence and §8.2's *Text from the host* (the log's *The One Silence*); the family's rules in round 2 — **What is dropped without notice.** Principle 3 is cited on both sides: a late answer, a second answer and a message in flight at a peer's loss are dropped silently, while a guard's fault must not be swallowed (L1 family 6, 3 of 6; L1-147). Text that is not UTF-8 meets five treatments, a fault, an entry left out, `Left(Other)`, a refused run and `None`, so `Fs.list` of two files lists one (P2-12; L2 family K, 3 of 9; L2-39). Proposed: a `send` promises the sender nothing, and a message whose receiver has ended, whose call has timed out or whose peer is lost is the one silence in the language (L1, for §6.2); text the host gives is UTF-8 or is refused where the program asked for it, and what it did not ask for by name is left out (L2, for §8.2), which P2-12 would tighten to never left out. With it `via`'s function faulting the target from the sender's `send` (P1-2).
- sentence — decided 2026-10-01, §6.9's last sentences (the log's *Who Owns a Process*); the family's rules in round 2 — **Who owns a process or a resource.** Nothing owns a spawned process (§6.9), a socket and a program die with their opener (E.18, E.23), and a supervisor's children die through a watcher the library spawns, which `Process.live` shows as a third process (L2 family J, 3 of 8; L2-37, L2-38; P2-7, P2-13, P2-22; P1-21; W-1, W-16, W-17). Proposed (L2, for §6.9): a process the program spawns belongs to no one, and a process the runtime starts for a resource belongs to the process that opened it or was given it and ends with it; P2-7 would own a child by its supervisor the same way, `group` spawning nothing. With it `kill(socket)` beside `Tcp.close` with no stated difference (P2-13), a `Down` naming no process (W-1), and `spawnMonitored` beside `spawn` and `monitor` for a race the runtime's forgetting makes (W-16, P1-21).
- sentence — decided 2026-10-01, §6.6 names no type and §3.9's restrictions never written but on a foreign type (the log's *The Reply Discipline Names No Type*); the family's rules in round 2 — **The reply discipline and the inferred restrictions.** A reply may live in a list the program declares and not in `List(Reply(Int))`, and the refusal is checked at `[]` alone (P1-1; L2-35; W-5); only the name `fault` discharges an obligation, a callee whose result is a bare variable does not (P1-12, P1-84; W-18); a process-only variable prints unmarked, so two functions with one printed type differ in what may call them (P1-4; W-6); `a=` is printed, written in §4.7 and §9.2, and refused in an annotation (P1-14; W-6) (L2 family I, 2 of 11; P1-16, P1-44, P1-45; K-49). Proposed: §6.6 names no type, and a reply stands wherever inference shows it consumed exactly once (L2); a check that crosses no call boundary reads a callee by its type alone, a bare variable result meaning it does not return (P1-84). Whether a restriction may be written is MVP 2.99b's item 4 (R-23).
- sentence — decided 2026-10-01, §3.5's declared order (the log's *No Canonical Order*); the family's rules in round 2 — **Source order or a normal form.** Named fields are placed in canonical order for §8.7's normalization, and the order shows in `Io.show` and the ABI: `S(z = 1, a = 2)` prints `S(a = 2, z = 1)` (P1-11, P1-50, P1-77; W-14). Proposed (P1): the order the source shows is the order the runtime keeps and shows, and a normal form serves the hash alone.
- sentence — decided 2026-10-01, Appendix E.1's `Io.show` at a known type (the log's *A Value Shows Itself at a Known Type*); the family's rules in round 2 — **What a value shows of itself.** `Io.show` through a type variable prints the representation, `wrap('a')` is `97`, and no user `foreign fn` can have the mechanism the compiler gives `Io.show` (P1-8, P1-86; P2-5; K-7, K-31; W-80). MVP 2.99b's item 13 decides it one way; the sentence, a value prints as the program wrote it at whatever type it is seen (P1-86), is decided here and item 13 builds on it. With it the *shown* restriction's mark, which refuses nothing (P1-30, P2-46).
- sentence — decided 2026-10-01, §3.8's last sentence (the log's *One Door for the Host's Values*); the family's rules in round 2 — **One door for the host's values.** `Foreign`, an unnamed type of every host value, beside `foreign type T`, a named one (P1-26, P1-85). Proposed (P1): the host's values enter Ernest through declared foreign types alone.

## What the proposal would add

- 2.99b — the operations records' findings, to item 4 before it decides: `<` constrains while `+` errs, both dispatching to a member (P1-9, P2-40); a representation's own functions beside the generic ones, two ways by rule (P2-41); the sketch's `OrderedSet.size` both left out and called (P2-42); `map`'s callback before its records, against shape rule 1 (P2-43); a top-level `let` generalized over an equality variable and not an ordering one (P1-29, P2-44); `ordered_set.ern` a second spelling of a multi-word name beside the directory (P1-27, P2-45); the shown mark that refuses nothing (P1-30, P2-46); `List.<>` made a shim against rule 1 (P2-47); a generic `min`, `max` and `sort` beside the per-type four (P2-48); tuples ordered without a `compare`, the one such type (P1-28, P2-49); and the counts, three concepts, three prelude functions, eighteen shims and two marks (P1's and P2's counts).

## Defects and disagreements

Found on the way. The review judges rules, and a defect is fixed when found (CLAUDE.md, *Defects and gaps*).

- fix, phase 4 — **The library against E.0 and itself:** `Enter` a constructor while Backspace and Tab are `Key` (P2-6); `Path.join` not taking what `Path.split` gives (P2-10); `padStart`'s pad a scalar in a module that counts graphemes (P2-20); `Tcp.peer` borrowing the report's word (P2-23); `withExtension("")` a flag in a string (P2-28); two `Style` types (P2-36); `SockMsg` (P2-39); shape rule 2's verb broken five times, `size`, `join`, `split`, `repeat`, `create` (K-35), and `closeListener` beside `close` (K-41); `makeLink`'s subject second (K-36); E.22's primitives unnamed (K-39).
- fix, phase 4 — **A builder must guess, or the rules are silent:** a block ending in `let` (K-10); a doc block above a local `fn` (K-11); a field given twice (K-12); `restarting` inside `restarting` (K-13); a module without `since` (K-14); a negative number printed (K-15); `ern test` with no tests (K-16); two doc blocks before the first declaration (K-17); a private `main` (K-19); `abstract type` at the prompt (K-20); a result annotation's `with` on a returned function (P1-13); §3's look past the matching `)` that the parser does not perform (P1-22).
- fix, phase 4 — **Clarity and references:** K-21 to K-23, K-25 to K-27; Appendix F's missing and stray terms (K-24, P2-37, P2-38); and the guide's W-55, bytes scanned by hand beside `Bytes.split`. With them the three diagnostics that say "return type" where the report says result type (MVP 2.99b's item 2).
- fix, phase 5 — **Inside a family, fixed with it:** with the reply discipline and the inferred restrictions, §3.10's `Map((Int) -> Int, Int)` "not itself an error" against §4.7's and §9.2's "wherever the type is written" (K-1) and §6.6's sentence that a reply-carrying value is not a statement (K-4); with the forms that enter, §5.7's list of what stands right of `|>` against Appendix A (K-2), a pipe into a function of no parameters (K-18), `1e10` (P1-23) and `String.toFloat("1")` `None` (P2-19), the shell refusing the `let f = fn(x) = x` that §4.6 generalizes (P1-18), and a `receive` guard's operands taught wrongly (W-7); with the members and operators, §9.6 making `List.<>` the runtime's (K-3), `fn Float.+` with and without `export` (K-5), `(T, T) -> R` read as `R = T` (K-6) and `%` on `Float` (K-9); with a failure's shape, `Tcp.read` after the program's own `close` and `accept` after `closeListener` (P2-3) and `Path.name` `""` where `parent` is `None` (P2-29); with what the library admits, `Bytes.get` without `String.get` (P2-11), `dropLast` without a count, `last` without `first`, `List.remove` by value (P2-14), no `Io.writeError` (P2-15), `styled` inside `styled` turning the outer off (P2-21), `slice` beside `take` and `drop` (P2-31) and `split("")` and `lines("")` disagreeing (P2-32); with who owns a process, no `Os.give` (P2-22); with what a value shows, `Io.debug` on standard output (P2-24); with one door for the host's values, no `Foreign.toBytes` (P2-27) and the encodings and `Erl.atom` outside shape rule 3 (K-37); with where a thing lives, a group of one child beside `restarting` (P2-35); and with the guide's prose, rewritten at the end of the edits, W-25, a `let` explained away, W-60, annotations the rules do not ask for, and W-70, a queue appended with `<>`.
- fixed, phase 4 — the guide's output order, which §8.2's synchronous write fixes (W-3); §8.4's result variable, which the check meets only at a value of it (K-8).
- kept, phase 4 — whole-grapheme search (P2-1), by principle 1's stated departure and principle 2's one unit of text: every index E.5 answers counts whole graphemes, and a match begun inside one has none; `String.lines` reads text whose lines end either way (the log's *A Search Matches Whole Graphemes*).
- fix, MVP 2.99b's item 5 — `alarmAt` unexplained beside `alarm` (P2-33): its sentence waits for the decision on a wall clock that jumps.
- fixed — rule 1 naming `toInt` where E.5's primitive is `toIntBase` (P2-26, K-40), by E.0 rule 1's restatement of 2026-10-01.

## Rules that buy little

- round 2 — P1-35 to P1-49 and P2-50 to P2-75, each with its family where it has one. Against the release review's parked list, nine of its fourteen were named again by a reader who had not seen it: the private abstract type error (P1-25, P1-41), "not a recursive call" (P1-10), `Prelude.` (P1-33, P1-40), the type-directed `Io.show` (P1-8), `Test` and `TestResult` in the prelude (P1-61), `////` (P1-35), `Path.toString` (P2-62), `k=` writable in a foreign type alone (P1-14), and the guard-expression language (P1-6, P1-63). Named once: lambda-let generalization, where P1-17 asks for more of it; the reply linearity machinery (P1-44, P1-45); a result type variable taken as `Unit` (W-94); `abstract`, `export` and `foreign` reserved; §6.7 restating §6.2; `Map.merge`. The guide never teaches or uses 31 groups of rules (W-73 to W-103), evidence for the same question.

## Rules that exist only for another

- round 2 — For peers, unbuilt: P1-50 to P1-60, eleven places outside §3.11, §8.3 and §8.7 that exist for them, `Local` in every spawn (P1-52) and the canonical field order (P1-50) among them. For something else: P1-61 to P1-72 and P2-76 to P2-93, the terminal's text builders for the shell (P2-81), `Process.info`, `live` and `faults` for the shell and `ern run` (P2-82), and `Fs.makePrivate` for the shell (P2-83) among them.

## Where the guide works hard

- round 2 — W-1 to W-30, each with its family above; the rest are the guide's evidence for rules no family holds: W-10, mailboxes unbounded; W-13, `let me = self()` before nine spawns; W-15 and W-35, addresses without equality and `Process.fromAddress` twice; W-19, a lambda after `|>`; W-31, `let _ =` in eleven programs; W-34, a helper process to ask and go on; W-38, results routed through `main` for order; W-52, two record forms for one contract in 110 lines. W-13 and W-31 go to language feedback if their rules are kept.
- dropped — decided before: an `if` without `else` (W-32, the release review's N-C4) and an alarm without a cancel (W-9's rule, N-C1); W-9 stands as the rule's cost.

## The log

- log — the entries whose reason has lapsed or was abolished and that stand unmarked: L1-99 to L1-136, 22 resting on the three-uses count and 9 whose reason no longer holds, and L2-41 to L2-80, 14 whose reason no longer holds; each marked superseded or its verdict restated on the reason that holds.
- round 2 — the pairs of alike cases decided differently, L1-137 to L1-156 and L2-81 to L2-105, each with its family.

## Counts

Against the release review's, in parentheses. Reserved words 18 (18). Contextual words 12 (12), with `compare`, `negate` and the shell's `it` named as not counted by that method. Prelude types 25 (25). Prelude functions 30 (30). Primitives outside §9: 3 (3) as counted then, 5 (5) as rule 1 names them. Taken namespaces 35 (35) by the older method, 25 (25) by §4.2. Concepts 95 (89), Appendix F at 106 entries. Inferred restrictions 3, printed marks 2. Primitives as the sections name them 79, with the system modules' unnamed shims 91, `foreign fn` as built 94. Listed functions 264 in E and 13 in G. The proposal would add 3 prelude functions, 3 concepts at least, 3 primitives outside §9, 18 shims, 2 restrictions and 2 marks, a namespace, and 12 to 16 functions.

## The readers' lists

Each reader's list as it was handed in, condensed to a line a finding, on commit `57b8356`.

### P, part 1: §0 to §11 and Appendices A to D

#### Findings

P1-1 §6.6: a reply may sit in a declared list type but not in `List(Reply(Int))`, and the refusal fires at `[]`, not `::`; let a reply-carrying element make its container so, or check at `::`, `[x]` and the puts.
P1-2 §6.5: a fault in `via`'s `f` kills the target, whose code holds no trace of `f`, though `f` runs in the sender at its `send`; say "A fault in `f` is the sender's, at the `send` that applies it."
P1-3 §4.2: a module declaring `type List` splits `List.` between the local type and the library per member; a dotted name whose first segment is a declared type names its member, the namespace reached through `Prelude`.
P1-4 §3.9, §11.5: a process-only effect variable prints unchanged, so two functions print alike while one cannot be called from pure code; print it with a mark and say so in §11.5 beside `a=` and `a!`.
P1-5 §6.8, §6.2: `with Never` and `with m` both say "receives nothing", and `with Never` refuses every caller with a mailbox; admit `with Never` on a process root alone, or drop it and let `with m` say it.
P1-6 §6.3 against §5.9: a `match` guard may call and a `receive` guard may not, two guard languages for `when`; one guard, §6.3's restriction stated as the host's in §10, or `receive` refusing `when` altogether.
P1-7 §5.7: `x |> f(a)(b)` is `f(a)(x, b)` but `x |> (f(a))` is `f(a)(x)`, parentheses changing an operand's meaning nowhere else; one rule for both spellings, a parenthesized call refused as an operand.
P1-8 §4.4, E.1: `Io.show` through a type variable prints by representation, so one value prints two texts; proposed item 13 removes the sentence and prints by the caller's type; the finding stands until it does.
P1-9 proposed item 1 and §4.8: a comparison on an undetermined operand type gives a constraint while `+` on one stays a type error, both dispatching to the operand type; one rule for every operator resolved per type.
P1-10 §9.6: `fn Int.+(a, b) = a + b` is said not to be a recursive call, which the text is; proposed item 14 makes each such body a `foreign fn` and removes the sentence; the finding stands until it does.
P1-11 §3.5, §8.4, E.1: named fields are placed in lexicographic order, so a value prints and reaches foreign code in an order the source does not show; declaration order for both, §8.7 sorting when it hashes.
P1-12 §6.6: `fault` consumes every open obligation, a call to a function whose result is a bare type variable, which only one that never returns has, consumes nothing; such a call consumes too, or say only `fault` does.
P1-13 §3.4: in `fn f() : (A) -> B with M` the `with` is the returned function's, against `Return = ":" Type [ "with" Type ]`; the `with` of a `Return` belongs to the declared function, a returned function's in parentheses.
P1-14 §3.10, §4.7, §11.5: `Set(a=)` and `foreign type Table(k=, v)` write a mark no annotation may hold, and `fn eq(x : a=)` fails to parse; admit `a=` in every annotation, or write a foreign type's constraint otherwise.
P1-15 §6.3, §6.6, §6.9: a negative time or count is clamped without a word while `Os.exit(300)` faults; fault with `Fault("negative time")`, or one sentence in §7.4 saying what is clamped and why.
P1-16 §3.9: a type variable named first in a non-generalized lambda's annotation is an error, though a signature's variables scope over the whole definition; such a variable belongs to the enclosing definition.
P1-17 §4.6: a block `let` is monomorphic unless it binds a lambda, so `let xs = []` used at two element types fails, against ML's value restriction; generalize a `let` bound to a value, or say in §3.9 why not.
P1-18 §11.2 against §4.6: a prompt `let` is said to bind as a block `let`, yet `let f = fn(x) = x` is refused as undetermined where §4.6 generalizes it; generalize at the prompt, or say in §11.2 that it is not.
P1-19 §2.2: a doc block that precedes no declaration vanishes from `ern doc` without a word, while a `///` after a token is an error; make a doc block that precedes no declaration an error.
P1-20 §6.6, §9.5 against E.0 rule 8: `Address.call` answers `Optional(a)`, `callForever` faults, the library's waits answer `Left(Timeout)`; one `call` answering `Either(Io.Error, a)`, no `callForever`, or §9 says why.
P1-21 §6.2, §9.5: `spawnMonitored` and `spawn` then `monitor` do one job, and the second loses the reason when the process ends first; say in §6.2 that the pair exists for the race, or make `monitor` keep the reason.
P1-22 §3, Appendix A: the `->` "after the matching `)`" names an unbounded look ahead the parser does not make; a parenthesized list of types is parsed as one, a `->` after it making an `FnType`.
P1-23 §2.5: `1e10` is refused, "e cannot follow a number directly", where a float is expected; admit `decimal exponent`, or say in §2.5 that an exponent needs a point, beside `1.0e-9`.
P1-24 §4.6, §5.4: `let x = 1; let x = 2` builds while `let f = 1; fn f() : Int = 2` fails, two shadowing rules in one block; say in §5.4 that a `fn` is visible throughout its block, or refuse shadowing by `let` too.
P1-25 §4.4: every `abstract type` must carry `export`, a private one being an error, so the word decides nothing; `abstract type` exported without the word, `AbstractDecl` outside `[ "export" ]` in the grammar.
P1-26 §3.7, §4.7: `Foreign`, the type of any uninspected host value, and `foreign type T` are two concepts for one thing; `Foreign` becomes `Erl.Term`, a foreign type of E.19, `Erl.atom` and `Foreign.from` answering it.
P1-27 proposed item 9 and §11.1: a `_`-joined file name and a nested directory are two ways to name a multi-word module; `orderedset.ern` as `Orderedset`, as `httpv2.ern` is `Httpv2`, or every multi-word name `_`-joined.
P1-28 proposed item 2: tuples get a built-in order, a second mechanism beside `T.compare` that `:doc` cannot find; no order on tuples, or a `Tuple` page in the prelude naming the operation as §9.6 names `Int.compare`.
P1-29 proposed item 3: a top-level `let` is generalized over an equality variable but not an ordered one, since ordering passes a hidden `compare` and equality does not; say so in §4.6, or pass equality the same way.
P1-30 proposed item 13: the shown restriction is a fifth restriction, a third mark, and a hidden argument a foreign declaration does not show; state the argument in §4.7 and §8.4, the mark in §11.5, the count in §3.9.
P1-31 §5.6, §5.7: `1 |> Some` builds while `1 |> W` with one named field fails, a named constructor being neither value nor function; say in §5.6 why, or make a one-field named constructor a function.
P1-32 §3.9: polymorphic recursion is refused even where the whole signature is written, though a rigid annotation variable means every type; state why in §3.9, or admit it where the signature is whole.
P1-33 §4.2: `Prelude.Some` where nothing shadows is an error, so removing a module's own `Some` breaks every `Prelude.Some` in it; admit `Prelude.x` everywhere, `ern format` or a diagnostic naming the shorter spelling.
P1-34 §2.5: `"a\\b"` and `` `a\b` `` are two spellings of one `String`, and a multi-line string has three ways, pairs principle 2 admits in the library only; keep one literal, or say what the raw string alone can do.

#### Rules that buy little

P1-35 §2.2: `////` beginning an ordinary comment buys a banner of slashes, without which a line of slashes is a doc comment; little.
P1-36 §2.3: `_`-prefixed identifiers buy names like `_x` that nothing reads differently, there being no unused-variable diagnostic; little.
P1-37 §2.5: `"0o" octdigit` buys `0o644`; little.
P1-38 §3.2: tuples of one component buy uniformity, and a one-tuple has no use; little.
P1-39 §3.9: the error on a variable named first in a non-generalized lambda (P1-16) buys nothing over the enclosing definition's variable.
P1-40 §4.2: the refusal of `Prelude.x` where nothing shadows (P1-33) buys one spelling and costs a refactoring trap.
P1-41 §4.4: `export` on every `abstract type` (P1-25) buys nothing; the word is forced.
P1-42 §5.3: the delimiters ending a lambda body, `{` for a `match` scrutinee and `:` for a bitstring segment, buy nothing over "the body is an `Expr`", since neither can continue an `Expr` and nobody writes the two forms.
P1-43 §5.4: a `fn` visible throughout its block, with three consequences and a reachability check, buys mutual recursion across a `let`; visibility from the declaration on, adjacent `fn`s recursive together, buys the same.
P1-44 §6.6: "A reply-carrying value is not a statement" restates §5.4, which already refuses a statement that is not `Unit`.
P1-45 §6.6: the refusal of a local `fn` capturing a reply-carrying value buys a simpler check and costs a helper written as a lambda in a `let`.
P1-46 §9.3: `type Path = Path(String)` in the prelude buys a taken namespace the standard library's own rule already gives, since `io.ern` is refused too; the language names `Path` in no rule.
P1-47 §5.9: "A guarded clause leaves every value its pattern matches" follows from "guards do not count toward coverage" two sentences earlier.
P1-48 §11.2: a prompt `let` binding as a block `let` buys patterns at the prompt and costs a second meaning of `let` at file scope, and today the refusal of P1-18.
P1-49 §2.6: `|` as a clause delimiter the first `match` clause omits buys a layout and costs the asymmetry §11.6's "its bar two columns to the left" exists to dress.

#### Rules that exist only for another

P1-50 §3.5: canonical order of named fields exists for §8.7's normalization alone, for peers; declaration order is a fixed order too, and P1-11 shows the cost.
P1-51 §3.8, second paragraph: a foreign value bound to the node that made it, with its transports and the fault's owner, exists for peers alone.
P1-52 §6.2, §9.3: `type Where` and the first argument of `spawn` and `spawnMonitored` exist for peers, every spawn writing `Local` for a feature none uses; `spawn(f)`, and `Peer.spawn(name, f)` in a module of its own.
P1-53 §6.5: the three sentences from "An adapted address crosses to another node" to `Fault("function cannot cross nodes")` exist for peers alone.
P1-54 §7.4: `Fault("foreign value cannot cross nodes")`, `Fault("function cannot cross nodes")`, `Fault("peer unreachable")`, `Fault("peer resolution failed: ...")` and `Fault("peer lost")` exist for peers alone.
P1-55 §8.2: "a system module the peer's runtime does not provide is a resolution failure" exists for peers alone.
P1-56 §8.4: "Cross-node transport uses the runtime's external term format" exists for peers alone.
P1-57 §8.6: the sentences on workers spawned on peers, peers observing the ending node, a connected peer's timer, a process spawned on a peer counting as a computation, and detection per node exist for peers alone.
P1-58 §10: the bullets on the hash, the normal form, authentication and the wire format, on shipping code, and on the loss of a peer exist for peers alone.
P1-59 §11.2, §11.3, §11.7, Appendix C: `--config-dir`, `ern config`, `ernest.conf` and its keys exist for peers; the shell's `startup` file is the one use that is not a peer's.
P1-60 §4.4 through §8.7: "An abstract type's hash also includes the types of its module's exported declarations" reaches into the meaning of an abstract type for peers alone.
P1-61 §9.3: `Test` and `TestResult` exist for `ern test` (§11.2); two of the prelude's 25 types belong to a toolchain job.
P1-62 §9.1, §9.3: `Process` exists for E.21 and `Path` for E.14; the language's rules name neither.
P1-63 §6.3: the guard expression exists for the host's `receive`, and §10 does not say so (P1-6).
P1-64 §6.6: the exemption of a variable that is an element of `List`, `Map` or `Set` exists for the container refusal, and the refusal for the exemption (P1-1).
P1-65 §5.4: "A local `fn` may not take the name of a parameter or a variable in scope" exists for the visibility of a `fn` throughout its block (P1-24, P1-43).
P1-66 §5.3: the `{` and `:` delimiters exist for a lambda as a `match` scrutinee and as a bitstring segment (P1-42).
P1-67 §4.2, §4.8: the standard library's source-root exception and the built-in types' module exception exist for built-in types having no declaring module, `fn Int.+` prefixed and `fn abs` bare in one file.
P1-68 §8.5: "The standard library is initialized whole" exists for §8.2's system references.
P1-69 §7.4: `Fault("its code was unloaded")`, `Fault("the binding has no value, ...")`, `Fault("the shell holds the terminal; ...")` and `Os.exit`'s `Fault("exited with status n")` exist for the shell and `ern test`.
P1-70 §2.3: the 255-character limit on identifiers, type names and qualified-name segments exists for the host's atoms.
P1-71 §3.10, §8.4: exact equality on a foreign or `Process` value, and same-named constructors sharing an atom, exist for the ABI.
P1-72 §9.6: `Int.negate` and `Float.negate` exist for prefix `-`'s resolution (§5.1), and `Bool.not` (§4.8) pairs `!`; the prelude carries the pair principle 2 reserves for the library.

#### Undecided by the principles

P1-73 §0, the reader's prior knowledge (P1-6, P1-17, P1-23, P1-32): nothing says what else principle 1's reader knows, and a reader of Standard ML and one of Erlang predict differently; sentence: "Principle 1's reader also knows Hindley-Milner as Standard ML and OCaml state it and processes as Erlang has them; where Ernest departs from what that reader predicts, the departing sentence says so."
P1-74 §0, a concrete form beside a variable form (P1-5): `with Never` and `with m` both say "receives nothing"; sentence: "Where a type variable says what a concrete type says, only the variable form is admitted."
P1-75 §0, one form, one meaning (P1-6, P1-48): a guard in `match` and in `receive`, a `let` in a block and at the prompt; sentence: "A form has one meaning wherever it stands; a restriction the host imposes on it in one place is stated in §10 and lifted where the host allows."
P1-76 §0, the cost of an unused feature (P1-52, P1-61): `Local` in every spawn, `Test` in the prelude; sentence: "A feature costs a program that does not use it nothing: no argument, no word, and no prelude name of it is written there."
P1-77 §0, source order or a normal form (P1-11, P1-50); sentence: "The order the source shows is the order the runtime keeps and shows; a normal form serves the hash alone."
P1-78 §0, the prelude and the library's shapes (P1-20); sentence: "The prelude's functions have the shapes Appendix E.0 gives the library's; a prelude function differs from a library function of the same kind by nothing but its place."
P1-79 §0, one rule for the operators resolved per type (P1-9, proposed); sentence: "The operators the language resolves against the operand type are resolved by one rule; what one of `==`, `<`, `+` does on a type variable, every one does."
P1-80 §0, a value outside its domain (P1-15): clamping and faulting are both visible in the report and invisible in the program; sentence: "An argument outside its domain faults or is refused; nothing is corrected in silence."
P1-81 §0, a forced word (P1-25): principle 3 asks for the visible `export`, principle 5 for fewer words; sentence: "A word the rules force is not written; a marker stands only where its absence would mean something."
P1-82 §0, qualification (P1-33); sentence: "A qualified name is admitted wherever its unqualified form is; a change elsewhere never makes a longer spelling an error."
P1-83 §0, parentheses (P1-7); sentence: "Parentheses group and mean nothing: `(e)` stands for `e` in every position."
P1-84 §0, a check that reads a body (P1-12); sentence: "A check that crosses no call boundary reads a callee by its type alone, and a result type that is a bare variable says the callee does not return."
P1-85 §0, one door for the host's values (P1-26); sentence: "The host's values enter Ernest through declared foreign types alone; there is no type of every host value."
P1-86 §0, what a value shows of itself (P1-8; proposed item 13 decides it one way); sentence: "A value prints as the program wrote it, at whatever type it is seen."

#### Counts

Counted from the report at 57b8356; the last review's count in parentheses. Proposed additions are counted apart.

Reserved words: 18 (18). §2.4's table, read across: `type`, `abstract`, `with`, `foreign`; `match`, `when`, `receive`, `after`, `as`, `or`; `if`, `then`, `else`; `fn`, `let`; `export`; `true`, `false`. Proposed: 0 ("The syntax does not change").

Contextual words: 12 (12). §5.11's specifiers, 11: `size`, `bytes`, `int`, `float`, `utf8`, `utf16`, `utf32`, `big`, `little`, `signed`, `unsigned`; and `Prelude` (§4.2). Not counted by that method, named so the next count decides: the member names the language reads, `compare` (§3.10) and `negate` (§5.1), 2; the shell's `it` (§11.2), 1; `main` is a convention (§8.1). Proposed: 0 words; `_` in a file name (item 9) is a new lexical rule of §11.1, not a word.

Prelude types: 25 (25). §9.1, 11: `Int`, `Float`, `Char`, `String`, `Bytes`, `Bool`, `Address`, `Reply`, `Never`, `Foreign`, `Process`. §9.2, 3: `List`, `Map`, `Set`. §9.3, 11: `Unit`, `Optional`, `Either`, `Ordering`, `Down`, `Reason`, `RestartLimit`, `Where`, `Path`, `Test`, `TestResult`. Proposed: 0 in the prelude; `Set.Operations` is the library's (Appendix E).

Prelude functions: 30 (30). §9.4, 4: `self`, `send`, `spawn`, `spawnMonitored`. §9.5, 7: `via`, `Address.call`, `Address.callForever`, `answer`, `restarting`, `monitor`, `kill`. §9.6, 19: `Int.+ - * / %` (5), `Int.negate`, `Float.+ - * /` (4), `Float.negate`, `String.<>`, `List.<>`, `Bytes.<>`, `Int.compare`, `Float.compare`, `String.compare`, `Char.compare`, `fault`. Proposed: +3 in §9.6, `List.compare`, `Optional.compare`, `Either.compare` (item 2), 33; and the tuples' built-in order, an operation with no name (P1-28).

Primitives outside §9: 3 as counted then (3), 5 as E.0 rule 1 names them (5). The three: the type-directed `Io.show` (E.1), the supervisor's restart request (§6.9), the system references (§8.2). E.0 rule 1 adds why a restarting function began and the order in which the runtime spawned its processes. Proposed: +3: the hidden `compare` the emitter passes (item 12); the type description a generic function, a foreign function, and `Foreign.from` receive (item 13), which changes `Io.show`'s primitive from a type at the call to an argument at run time; and the tuples' built-in ordering (item 2). Item 14 removes one special case, §9.6's "names that operation and is not a recursive call", and adds no primitive: 5 becomes 8 by rule 1's method, or 7 with the removal counted.

Inferred restrictions (§3.9, "Three restrictions"): 3 (3); printed marks, 2 (`a=`, `a!`). Proposed: 5, with the ordering constraint `a<` (item 1) and the shown restriction (item 13); marks, 4.

### P, part 2: Appendices E to G

#### Findings

P2-1 Appendix E.5 (principle 1): a search matches whole graphemes, so "\n" is not found in CRLF text: endsWith, contains, indexOf, replace and split all miss it; fix: a search matches code points and answers grapheme indices.
P2-2 Appendix E.1, E.17, E.18, E.23 (principle 3): causes the report names are text in Other, matched by string, and one Error serves six modules; fix: a constructor per named cause, Other for the host's reason alone.
P2-3 Appendix E.18 (principle 1): Tcp.read faults after the program's own close but answers Left(Closed) after the far end's, and accept after closeListener faults or not by timing; fix: an ended socket or listener answers Left(Closed) always.
P2-4 E.0 shape rule 4, E.8, E.9, §7.4 (principles 2, 3): an out-of-range float is None from sqrt and log, a fault from /, exp and Int.toFloat; Int has div, Float none; fix: rule 4 without exceptions, Int.div and rem gone or Float.div added.
P2-5 Appendix E.1 (proposed item 13 removes it; principle 3): Io.show of a type-variable argument writes the runtime representation, so a polymorphic helper prints 97 for a Char and text for Bytes; fix: as proposed.
P2-6 Appendix E.16 (principle 1): Enter is a constructor for \r and \n alike while Backspace and Tab arrive as Key(Char); fix: Key(Char) for every character, Enter being Key('\r'), or a constructor per key the shell names.
P2-7 Appendix E.22, E.21 (principle 3): Supervisor.group spawns a process of its own, two spawns making three, and answers a one-shot function; fix: a child is owned by its supervisor as a socket by its owner, and group spawns nothing.
P2-8 E.0 shape rule 8, E.1, E.23 (principle 1): Io.readLine, Io.read and Os.read wait unbounded where every other wait takes milliseconds last, out of an alarm's reach; fix: each takes ms last and answers Left(Timeout).
P2-9 Appendix E.23, shape rule 8 (principle 1): Os.start's last Int bounds the program's run, the library's one last Int that is not the call's wait; fix: Os.start(command), Os.read(program, ms), a run bounded by kill after an alarm.
P2-10 Appendix E.14 (principle 1): Path.join takes two paths and Path.split gives List(String), so join(split(p)) is a type error; fix: Path.join(segments : List(String)) : Path, and the two-path operation is Path.<>.
P2-11 Appendix E.5, E.20 (principle 2): Bytes.get exists though E.20 says Bytes is not a container, and String has no get; fix: drop Bytes.get, or add String.get : (String, Int) -> Optional(String), the grapheme at an index.
P2-12 Appendix E.17, E.23, §8.2 (principles 2, 3): text that is not UTF-8 meets five treatments, fault, entry left out, Left(Other), refused run, None; fix: E.0 or §8.2: an error of the function that met it, never left out or a fault.
P2-13 Appendix E.18 (principle 2): kill and Tcp.close both end a socket, kill and closeListener a listener, and the report states no difference; fix: state the difference, or drop Tcp.close and Tcp.closeListener.
P2-14 Appendix E.2 (principle 1): dropLast takes no count where drop does, last is in and first out, remove is by value where get is by index; fix: dropLast(xs, n), first with last or neither, remove takes what get takes.
P2-15 Appendix E.1 (principle 1): print and println have error-stream twins, write has none, so bytes cannot reach standard error; fix: Io.writeError.
P2-16 Appendix E.6 (principle 2): isAsciiDigit is the library's one ASCII predicate, admitted by no rule of E.0; fix: drop it, or rule 2 names the predicates Char has.
P2-17 Appendix E.8 (principles 2, 3): a negative count makes shiftLeft shift right and shiftRight shift left, two spellings of one shift; fix: a count below 0 is 0, as take's is.
P2-18 Appendix E.10, E.11, E.0 rule 4 (principle 2): Optional.orElse and Either.orElse are a pipe of two, which rule 4 refuses, and its five kept compositions name neither; fix: name them in rule 4 or drop them.
P2-19 Appendix E.5 (principle 1): String.toFloat reads only a literal with a point, so "1", "1e5" and ".5" are None; fix: toFloat reads decimal ["." decimal] [exponent].
P2-20 Appendix E.5 (principle 3): padStart's pad is a Char, a scalar value in a module that counts graphemes, so a combining pad leaves the string shorter than asked; fix: the pad is a String, whole copies of which pad the text.
P2-21 Appendix E.16 (principle 3): styled turns its style off by its own code and Bold and Dim share one, so text after a Bold inside a Dim is not dim; fix: styled(text, styles : List(Style)), set at once, reset by ESC[0m after.
P2-22 Appendix E.23, E.18 (principle 1): a running program is owned as a socket is but has no give, so it cannot be handed to another process; fix: Os.give(program, process).
P2-23 Appendix E.18, Appendix F (principles 5, 1): Tcp.peer borrows peer, the report's word for a node, for the connection's far end and must say so; fix: Tcp.remote beside Tcp.local.
P2-24 Appendix E.1 (principle 1): Io.debug writes to standard output where all a program says of itself goes to standard error, so a piped run breaks on it; fix: Io.debug is printlnError(show(x)), at proposed item 13's rewrite.
P2-25 Appendix E.9, E.0 rule 3: Float.toString's thresholds and toStringBase's and toHex's case are formats the library chose, which rule 3 refuses; fix: rule 3 says a canonical form §2.5's literals read back is no policy.
P2-26 E.0 rule 1, E.5, E.8: rule 1 names Int.toString, Float.toString and their inverses as primitives, but E.5's is toIntBase, not toInt, and E.8's a private base writer; fix: rule 1 names String.toIntBase and String.toFloat.
P2-27 Appendix E.12: Foreign.toString and no toBytes, so a binary a foreign code answers that is not UTF-8 has no way out, and a Char only through toInt; fix: Foreign.toBytes.
P2-28 Appendix E.14 (shape rule 9's kind): Path.withExtension removes the extension on "", a flag in a String of the kind rule 9 refuses for Bool; fix: withExtension(p, Optional(String)) or Path.withoutExtension.
P2-29 Appendix E.14 (principle 2): the root's absence is None from Path.parent and "" from Path.name; fix: name : Optional(String).
P2-30 Appendix E.9 (principle 1): trigonometry and no Float.pi, and no rule of E.0 admits a constant; fix: rule 3 admits a type's constants, and Float.pi.
P2-31 Appendix E.5, E.20, E.2: a sub-sequence is slice on String and Bytes and take and drop on List, against shape rule 2's one verb per operation; fix: rule 2 gives text take and drop, or gives a sequence slice.
P2-32 Appendix E.5 (principle 2): split("", ",") is [""] and lines("") is [], and lines drops a last empty part where split keeps it; fix: rule 2 states lines as split at line ends less a last empty part, or the two agree on "".
P2-33 Appendix E.15 (principle 2): alarmAt(t, w) is alarm(t - Clock.now(), w) but for a clock set in between, which E.15 does not say; fix: say it in one sentence, or drop alarmAt.
P2-34 Appendix E.1, §6.6 (principle 2): a timeout is Left(Timeout) in the library and None from Address.call in the prelude, and Tcp.connect, a call, answers the first; fix: E.0 shape rule 8 at least names the seam.
P2-35 §6.9, Appendix E.22 (principle 2): restarting(limit, f) and a Supervisor.group of one child restart one process the same way; fix: E.22 says a group of one child is restarting.
P2-36 Appendix G.2, E.16 (principle 1): Markdown.Style = Plain | Styled beside Terminal.Style = Bold | Dim | ..., both met in Markdown.render; fix: Markdown.Output = Plain | Styled.
P2-37 Appendix F: no entry for adapted address, foreign process and address, block, statement, scrutinee, segment, grapheme, shim, subscription, owner, child, group, strategy, type scheme, rigid, vocabulary, container, sequence, raw string, selector, compiled interface; fix: add them or narrow F's first sentence.
P2-38 Appendix F: the generalization entry omits the block let that binds a lambda (§3.9, §4.6); fix: add it.
P2-39 Appendix E.18 (principle 1): Tcp.SockMsg is the library's one abbreviation, beside ListenerMsg, ProgramMsg and Supervisor.Msg; fix: SocketMsg.
P2-40 (proposed) Rule 1 of the proposal (principles 1, 2): an ordering constraint accepts a < b on type variables where §4.8 refuses a + b; fix: §4.8 says why comparison resolves at the call and arithmetic not, or refuses both.
P2-41 (proposed) Rule 6 of the proposal (principle 2): a representation exports its own functions, each calling the generic one, so OrderedSet.union and Set.Operations.union are two ways for every operation; fix: one of them.
P2-42 (proposed) The sketch: it leaves OrderedSet's size, contains, remove and toList out, and its usage calls OrderedSet.size, so a reader cannot tell whether it exists; fix: say which.
P2-43 (proposed) The sketch: Operations.map(set, f, from, to) puts the callback before the records, against shape rule 1's callbacks last; fix: map(set, from, to, f).
P2-44 (proposed) Rule 3 of the proposal (principle 1): no top-level let is generalized over an ordered variable, while §3.10 generalizes one over an equality-constrained variable; fix: §4.6 states the rule for both marks at once.
P2-45 (proposed) Rule 9 of the proposal (principle 2): a file name of words joined by _ names one namespace, a second spelling beside §11.1's directory, which refuses _; fix: set/ordered.ern, the namespace Set.Ordered, no new rule.
P2-46 (proposed) Item 13 (principles 3, 5): a shown restriction refuses no instantiation, every type being shown, and adds a fourth mark to a=, a! and a<; fix: no mark, the description passed as a compare is, or say what it refuses.
P2-47 (proposed) Item 14: List.<> becomes a foreign fn though rule 1 keeps what the language owns in Ernest and it is a fold with ::; fix: item 14 covers Int, Float, String, Bytes and the four compares; List.<> stays Ernest.
P2-48 (proposed) The proposal (principle 2): the ordering constraint puts Int's and Float's min and max and List.sort(xs, compare) beside a generic min, max and sort(xs); fix: place the generic three, drop the per-type four.
P2-49 (proposed) Rule 2 of the proposal: tuples are ordered without a compare, where §3.10 says ordering is per type through compare in the type's namespace; fix: §3.10 names the exception.

#### Rules and functions that buy little

E.0: admission rules 1 to 4 and shape rules 1 to 5 buy much, rule 3's edge being P2-25, rule 4's five exceptions little (P2-51) and shape rule 4's exceptions P2-4; shape rule 6 buys medium, §11.4 restated (P2-90); shape rules 7, 8 and 9 buy little (P2-72, P2-50, P2-73).
E.1 Io: print, printError, write, readLine, read and show are primitives, show uncomputable in Ernest; println, printlnError and debug are a line each.
E.2 List: size, map, filter, foldLeft, foldRight, foreach, any, all, find, filterMap, flatMap, sort, reverse, take, drop, zip, range, span, partition, unique, tryMap, tryFold and isEmpty are each a recursion; get is medium; contains, remove, last, dropLast, indexed, repeat and unzip are a line each.
E.3 Map: empty, size, get, put, remove and toList are the primitives; fromList, map, filter, filterMap, foldLeft, foreach, any, all, find, isEmpty, contains, keys, values, merge, mergeWith and update are a line each over them, kept by the vocabulary.
E.4 Set: empty, size, contains, put, remove and toList are the primitives; fromList, the eight folds, isEmpty, union, intersection, difference and isSubset are a line each, the folds kept by the vocabulary and the set operations by a reader's looking for them.
E.5 String: size, graphemes, indexOf, lastIndexOf, slice, trimStart, trimEnd, toLower, toUpper, toIntBase, toFloat, toList, fromList, toUtf8, fromUtf8 are the primitives; contains, startsWith, endsWith, replace, split, join, lines, trim, repeat, padStart, padEnd, isEmpty, toInt, toBool are a line each.
E.6 Char: isDigit, isAlpha, isSpace, isUpper, isLower, toUpper, toLower, toInt and fromInt are the primitives, the tables and the check; toString is a line, and isAsciiDigit two comparisons (P2-16).
E.7 Bool: not is !b as a value, for §2.6 alone (P2-87); toString is a conditional, kept as String.toBool's inverse by rule 2.
E.8 Int: bitAnd, bitOr, bitXor, bitNot, shiftLeft, shiftRight, toString and toFloat are the primitives and toStringBase the base writer; pow is medium; abs, min, max, div and rem are a line each, div and rem a second way to divide (P2-4).
E.9 Float: toString, truncate, floor, ceil, sqrt, pow, exp, log, sin, cos, tan, asin, acos, atan and atan2 are the host's library, uncomputable in Ernest to its precision; round is medium; abs, min and max are a line each.
E.10 Optional: withDefault, map and andThen are vocabulary, andThen buying only the expression position beside a block's <-; isSome, isNone and orElse are a line each (P2-18).
E.11 Either: withDefault, map and andThen are as Optional's; mapLeft, toOptional and fromOptional are medium, the last two converting between §7.1's error shapes; isLeft, isRight and orElse are a line each.
E.12 Foreign: from, toInt, toFloat, toString, toBool and toList are the only way to read an untyped foreign result, and Appendix D falls without them; toBytes is missing (P2-27).
E.13 Random: seed and next are the generator; nextFloat is a line.
E.14 Path: isAbsolute is the host's syntax; split, parent, name, extension and withExtension are a line each over String.split with the private separator, which a program cannot write; join is <> with a separator (P2-10); toString is a line, since Path is Path(String) in §9.3.
E.15 Clock: now and monotonic are the clock; alarm is the one way to wait and receive at once; alarmAt is alarm(t - now()) but for a set clock (P2-33).
E.16 Terminal: subscribe, size and columns are primitives, columns a table of widths; styled, up, down, left, right, clearBelow and clearScreen would be a line each if the codes were public, which they are not; all but subscribe and size exist for the shell (P2-81).
E.17 Fs: read, write, append, list, stat, makeDir, remove, rename, create, makeLink, readLink, removeAll, setModified, readRange and makePrivate are the host's alone; copy is read then write, a pipe of two; setModified is one example's, makePrivate one policy for the shell (P2-83), readRange used by tests alone.
E.18 Tcp: listen, accept, connect, read, write, port and give are primitives; close and closeListener do what kill does (P2-13); peer and local are medium.
E.19 Erl: atom is the host's atoms for a shim's arguments; no program's own.
E.20 Bytes: size is the primitive; slice, toList, fromList, contains, lastIndexOf, split, replace, join, repeat, startsWith, endsWith and isEmpty are a line each over <<...>> and size, and indexOf a loop, kept by the vocabulary; get is a pattern (P2-11); toHex and fromHex are medium, a loop each.
E.21 Process: fromAddress is identity with equality, needed by Tcp.give, the supervisor and a set of processes; info, live and faults are the runtime's knowledge, for the shell and ern run (P2-82), a program having monitor for its own.
E.22 Supervisor: group and child are the group; without them a program writes its own of restarting, monitor and kill, which is what the module is.
E.23 Os: arguments, environment, workingDirectory, exit, start, read, write and closeInput are the host's; run is start, closeInput and a read loop, more than a pipe of two and what most programs want.
G.1 Ets: new, put, get, contains, remove, size, close and toList are the host's table; clear is a loop of toList and remove.
G.2 Markdown: parse and render are the library; roff and firstSentence are ern doc --man's and the shell's (P2-84).
P2-50 Shape rule 8: 24 named exceptions (twelve answered at once, three unbounded, eight on a stream, Os.start's bound) for 20 conforming functions, unusable without the list; P2-8 and P2-9 leave three kinds and no names.
P2-51 Rule 4's five kept compositions, Io.debug, println, printlnError, Optional.isNone, Either.isRight: each buys a name for !isSome(x) or print(s <> "\n"); little, though println is the most called function and stays.
P2-52 E.8 Int.div, Int.rem: a conditional over /, and a second way to divide (P2-4).
P2-53 E.7 Bool.toString, E.5 String.toBool: a conditional and two comparisons; each exists for the other by rule 2's inverse sentence.
P2-54 E.7 Bool.not: !b as a value, for §2.6 alone (P2-87).
P2-55 E.6 Char.toString: String.fromList([c]).
P2-56 E.6 Char.isAsciiDigit: two comparisons (P2-16).
P2-57 E.2 List.last, dropLast, indexed, repeat, unzip, remove, contains: a call of two others each, a name being what each buys; the vocabulary keeps them.
P2-58 E.3 Map.isEmpty, contains, keys, values, merge, update, and map, filter, filterMap, foldLeft, foreach, any, all, find: a line each over toList, get and put; the vocabulary keeps them.
P2-59 E.4 Set.isEmpty, union, intersection, difference, isSubset, and the eight folds: a line each; a reader looks for the set operations, and the folds are vocabulary.
P2-60 E.5 String.contains, startsWith, endsWith, isEmpty, repeat, join, padStart, padEnd, trim, toInt, toBool; E.20 Bytes.isEmpty, startsWith, endsWith, repeat, join: a line each; the vocabulary keeps them.
P2-61 E.20 Bytes.get: a pattern (P2-11).
P2-62 E.14 Path.toString: let Path(s) = p, since §9.3 makes the constructor public.
P2-63 E.15 Clock.alarmAt (P2-33).
P2-64 E.16 Terminal.up, down, left, right, clearBelow, clearScreen: six functions for two ECMA-48 forms, the shell's (P2-81); styled one more.
P2-65 E.17 Fs.setModified: one example's; a sync tool's need, nothing of the language's.
P2-66 E.17 Fs.makePrivate: one policy where Fs.setMode(path, mode) would give every one for the same shim; the shell's (P2-83), and against rule 3 as any format is.
P2-67 E.17 Fs.copy: read then write, a pipe of two that holds the whole file.
P2-68 E.13 Random.nextFloat: next scaled.
P2-69 E.10 Optional.orElse, E.11 Either.orElse (P2-18).
P2-70 E.10 Optional.isNone, E.11 Either.isRight: negations, kept by rule 4 alone.
P2-71 E.10 Optional.andThen, E.11 Either.andThen: <- in a block does the job (§5.5); they buy the expression position, inside a lambda.
P2-72 Shape rule 7: Random.Seed over Random.RandomSeed; nothing is lost without it but a longer name.
P2-73 Shape rule 9: no function of E has or nearly has a Bool choice; the rule exists for G.2's render(doc, Plain).
P2-74 E.0 preamble, a module's section naming the functions that require equality: ern doc prints the mark (§11.5); the listing's comments duplicate it.
P2-75 Rule 2's inverse sentence: buys String.toBool and names two exceptions (Char through toList, Path through Path(s)) for one function.

#### Rules that exist only for another

P2-76 E.0 rule 1: the restart a Supervisor asks for, why a restarting function began, and the runtime's spawn order are three private primitives for E.22 alone.
P2-77 E.0 shape rule 2: the new sentence is for G.1 alone, which Appendix D also shows; no function of E is new.
P2-78 E.0 shape rule 5: its clock-reading clause and its Clock.monotonic sentence are for E.15 alone.
P2-79 E.0 shape rule 8: the Os.start and Os.run sentences are for E.23 alone (P2-9).
P2-80 E.0 shape rule 9: its example render(doc, Plain) is G.2's.
P2-81 E.16 Terminal.up, down, left, right, clearBelow, clearScreen, columns, styled: the shell's live region, completion and styles and G.2's render; one example uses clearScreen; the set, moves without moveTo, is the shell's need.
P2-82 E.21 Process.info, live, faults: the shell's :processes and :faults, ern run's fault report (§11.2), and E.22.
P2-83 E.17 Fs.makePrivate: the shell's history directory (§11.2); ern config's (§11.3) is Erlang.
P2-84 G.2 Markdown.firstSentence and roff: §11.4's NAME line and --man, and the shell's Shift-Tab; G.2 whole is ern doc's and the shell's :doc's.
P2-85 E.19 Erl.atom: E's shims and Appendix D; no program of its own.
P2-86 E.12 Foreign: a foreign fn's untyped results (Appendix D, §8.4); nothing in Ernest makes one otherwise.
P2-87 E.7 Bool.not: §2.6 keeps ! out of userop, so Bool.not is the value ! cannot be; && and || have none, since they short-circuit.
P2-88 List.<>, String.<>, Bytes.<>, Int.compare, Float.compare, String.compare, Char.compare, Int.negate, Float.negate and the arithmetic operators: §9.6's, which their modules provide.
P2-89 E.1 Io.show: Io.debug, the shell's printing of a value (§11.2), and shape rule 6's // => v; the documentation format depends on it.
P2-90 E.0 shape rule 6: §11.4's and the shell's contract restated among the library's rules.
P2-91 E.8 Int.toStringBase, E.5 String.toIntBase: Bytes.toHex and fromHex, and the shell.
P2-92 E.17 Fs.readRange: nothing in the repository but its tests; E.17 gives its reason.
P2-93 §9.3 Path in the prelude: E.14, E.17 and E.23; the prelude holds it since the module of its operations is named after it (§9).

#### Undecided by the principles

P2-94 Admission rule 1: the opposite, a shim where the host is faster, is admitted by principles 1 to 5 as written, none naming the host or speed; sentence for §0 after principle 5: "The standard library is Ernest: a foreign function stands only where the host alone can do the work."
P2-95 Admission rule 2: the opposite, a function entering when a program needs it, is admitted and favoured by principle 5 as written, principle 1 favouring the vocabulary; sentence for §0: "Principle 5 counts the language, its concepts, primitives and reserved words; the library is counted by principle 1: a function is there where a reader who knows the type looks for it."
P2-96 Admission rule 3: decided by principle 3 for a format or a locale, not for its edge, Float.toString's thresholds, toUpper's mapping, toHex's case; sentence for E.0 rule 3: "A form the language's own literals read back is no policy."
P2-97 Admission rule 4: decided by principle 2, its five exceptions not; sentence for rule 4: "A composition is kept only when its name is the operation a reader looks for, `println`; every other is written at the call."
P2-98 Shape rule 1: decided by §5.7, the pipe filling the first argument; not undecided.
P2-99 Shape rule 2: decided by principles 1 and 2.
P2-100 Shape rule 3: the opposite is admitted by every principle, principle 1 deciding by which the reader learnt first; sentence for E.0: "A function lives with its subject's type, its first argument's, and a conversion is named for its result; a module builds its own type from another with `fromX`."
P2-101 Shape rule 4: decided by principle 3, a fault being visible neither in the code nor in the type; its exceptions and §7.4's operator faults are not; sentence for E.0 or §7.4: "An operation of the language faults; a function of the library answers." (/ faults; Int.toFloat, Float.exp, Float.pow answer.)
P2-102 Shape rule 5: decided by §0's own sentence, a pure function's result depending only on its arguments, which a clock reading does not.
P2-103 Shape rule 6: no principle reaches it, and the opposite, no doc blocks, is admitted; it is §11.4's rule, and the sentence belongs there, not in §0.
P2-104 Shape rule 7: the opposite, Random.RandomSeed, is admitted by every principle; sentence for E.0: "A name is read qualified and does not repeat its module."
P2-105 Shape rule 8: the opposite is admitted, principle 2 could as well ask for one mechanism, and the report has three shapes of a limit (after t, None, Left(Timeout)); sentence for §0 under principle 2, or E.0: "A wait takes its limit the same way everywhere, and its passing has one answer."
P2-106 Shape rule 9: the opposite is admitted, principle 1 against it only weakly; sentence for E.0: "An argument that chooses between behaviours is a constructor, so a call reads without its signature."
P2-107 E.0's sentence that none of its rules counts programs: §0 is silent, and the opposite is what most libraries do; sentence for §0: "A feature enters by the principles, never by how many programs ask for it."
P2-108 Rule 1's runtime-owned representations: which types are the runtime's (Map, Set, String, Bytes, Float) and which the language's (List, tuples) no principle says, and at the ABI List is the host's list as Map is its map; sentence for E.0 rule 1: "A type the language's syntax builds, a list, a tuple, a bitstring, is the language's; a type only a module's functions build is the runtime's."

#### Counts

Taken namespaces, older method: 35, unchanged. Prelude (1) + the prelude's types (§9.1: Int, Float, Char, String, Bytes, Bool, Address, Reply, Never, Foreign, Process = 11; §9.2: List, Map, Set = 3; §9.3: Unit, Optional, Either, Ordering, Down, Reason, RestartLimit, Where, Path, Test, TestResult = 11; 25) + the standard library's namespaces (E.1 to E.23: 23) − those that are both (List, Map, Set, String, Char, Bool, Int, Float, Optional, Either, Foreign, Path, Process, Bytes = 14) = 1 + 25 + 23 − 14 = 35.
Taken namespaces, §4.2 as written: 25, unchanged. Prelude (1) + the prelude types with a member in §9 (Address by §9.5; Int, Float, String, List, Bytes, Char by §9.6 = 7) + 23 − those that are both (Int, Float, String, List, Bytes, Char = 6) = 25. The 18 prelude types without a member take none.
Proposed: 36 and 26. OrderedSet is a new namespace of the standard library; Optional and Either gain a §9.6 member (compare) but are library namespaces already.
Concepts: 95, from 89. Appendix F has 106 entries, from 100. Not concepts, 11: about the toolchain (build root §11.1, configuration directory §11.3, line mode §11.2, load path §11.2, source root §11.1) or the library (admission rule, shape rule, primitive, standard library, system module E.0, supervisor E.22); doc block and doc comment are §2.2's lexical forms and counted as the language's. If the last review's 11 were these, the six entries added since are all concepts. F's own count is short: P2-37 names the terms the report introduces without an entry.
Proposed concepts: +3 at least. Ordering constraint (a<), the operations record (Set.Operations), the shown restriction (item 13); the fourth mark on a type variable (P2-46) and the _ file-name spelling (P2-45) beside them.
Primitives. As E's sections name them: Map 6, Set 6, String 16 (15 and the private drop), Char 10 (9 and the private conversion), Int 9 (8 and the private base writer), Float 15 (4 and the 11 beneath the mathematics), Path 2 (isAbsolute and the private separator), Bytes 1, Foreign 6 (rule 1 names the module), Erl 1, Process 4 (rule 1 names the module), Supervisor 3 (private): 79. The six system modules' shims the sections do not name: each module's system binding (6), Io.show and Io.debug (2), Os.exit, commandLine, hostEnvironment, hostDirectory (4): 12 more, 91. As built, foreign fn in stdlib/: 94 (string 16, float 15, char 10, int 9, foreign 8, map 6, set 6, os 5, process 4, io 3, supervisor 3, path 2, clock 2, erl 1, bytes 1, terminal 1, tcp 1, fs 1); Random, List, Optional, Either, Bool have none. Proposed item 14 adds the operators and compares of §9.6 as shims: Int's 5 operators, Float's 4, <> for String, List and Bytes (3), negate (2), compare (4) = 18, or 17 without List.<> (P2-47).
Listed functions: 264 in E, 13 in G; 20 types in E, 6 in G. Per module: List 31, String 29, Map 22, Set 20, Float 19, Bytes 17, Fs 16, Int 15, Tcp 11, Char 11, Terminal 10, Os 9, Io 9, Either 9, Path 8, Optional 6, Foreign 6, Process 4, Clock 4, Random 3, Supervisor 2, Bool 2, Erl 1. Proposed: List.compare, Optional.compare, Either.compare in §9.6 (3), Set.Operations and Set.setOperations, Set.Operations.union, Set.Operations.map (3 functions, 1 type), OrderedSet's setOperations, union, empty, put, min, max (6, and size, contains, remove, toList if P2-42 says they are in: 10): 12 to 16 functions and 2 types.
Reserved words: 18 (§2.4), unchanged; the proposal adds none. E.0's shape rule 2 reserves verbs, not words: 17 container verbs, 3 sum-type verbs, new, isX.

### K, the cold reader

#### Sections that disagree

K-1 §3.10 against §4.7 and §9.2: the `=` constraint holds where the type is written in §4.7 and §9.2, at the first operation in §3.10, which the toolchain follows; §4.7 and §9.2 say at every operation, citing §3.10.
K-2 §5.7 against Appendix A: §5.7's list of pipe targets omits a block, a `match` and a `receive`, which Appendix A and the toolchain admit; §5.7 says any other operand is a value applied to `x`, and a non-function is a type error.
K-3 §9.6 against E.0 rule 1: §9.6 makes `List.<>` the runtime's append, though rule 1 writes what the language owns, `[]` and `::` among it, in Ernest; rule 1 exempts §9.6's operators, or §9.6 drops `List`.
K-4 §6.6 against §5.4: that a reply-carrying value is not a statement adds no rule, since §5.4 refuses every non-`Unit` statement and gives that error; delete it, or say it is refused as any non-`Unit` statement is. clarity
K-5 §4.2 against §4.8 and the standard library: §4.2 says `fn Float.+` declares and exports `Float.+`, as if the form exported by itself, while §4.8 and float.ern write `export fn`; §4.2 writes `export fn Float.+`. clarity
K-6 §4.8 against its own example: a member operator has the type `(T, T) -> R`, but the `Vec.+` example reads as `R = T`, and a `Distance.+` returning `Int` builds; the example says `(Vec(a), Vec(a)) -> R`. clarity

#### A builder must guess

K-7 §8.4 and E.1: `Io.show` writes by the argument's static type, but §8.4's ABI passes values, never types, so the mechanism is a guess; §8.4 says the compiler gives `Io.show` and `Io.debug` alone the argument's type at the call.
K-8 §8.4: a foreign result's type variable no parameter names faults on every return, yet `rawNew` (Appendix D) and `Map.empty`'s shim run; say it matches no value the check reaches, none in a foreign type or an empty container.
K-9 §4.8: what `%` on `Float` or `<>` on `Int` is, an operator on a determined type without that member, is not said; the toolchain refuses it; §4.8 adds that a type without the member has no such operator, a type error.
K-10 §5.4: Appendix A allows a `Stmt` last in a block, and whether a block ending in a `let` or a `fn` is a syntax or a type error is not said; the parser refuses it; say a block not ending in an expression is a syntax error.
K-11 §2.2: a `///` block above a block-level `fn`, a `Stmt` in Appendix A, is either documentation §11.4 must extract or a comment, and it builds silently; §2.2 says preceding a top-level declaration.
K-12 §5.6: a field given twice in a construction is not ruled on, though §5.10 states it for patterns and the toolchain refuses it; §5.6 adds "and each once".
K-13 §6.9: nested `restarting` says which runs when a supervisor asks, not which restarts an inner fault nor whose limit counts it; the innermost `restarting` restarts a fault and counts it against its limit alone.
K-14 §11.4: `ern doc` writes the module's `since v` line, but shape rule 6 binds only the standard library, so a module without one is not covered; the toolchain leaves the line out; add "where the module has one".
K-15 §3.5 and §3.10 (E.1 against §2.5): `Io.show` writes a value as its literal is written, and literals carry no sign, so `Io.show(-1)` is a guess; it prints `-1`; E.1 adds "a negative number with `-` before it". clarity

#### Cases left silent

K-16 §11.8: whether `ern test` on a module without tests, which prints `no tests` (§11.2), succeeds is not said, and it exits 0; add "and with status 0 where there are none".
K-17 §2.2: which of two doc blocks before the first declaration, each followed by a blank line, is the module's, and what the other is, is not said; the first is the module's, a later one an ordinary comment.
K-18 §5.7: a pipe into a function of no parameters, `x |> f` with `f : () -> Int`, is not covered by "the target's first parameter type"; add that a target without parameters is a type error at the pipe.
K-19 §8.1 and §11.2: a private `fn main` of the right shape is neither the `export fn main` §11.2 runs nor the other shape §8.1 refuses; §8.1 adds "and a private one".
K-20 §4.4 and §11.2: a private abstract type is an error (§4.4) and `export` adds nothing at the prompt (§11.2), so whether `abstract type` without `export` is refused there is not said; §11.2's Inputs says whether it needs `export`.

#### Examples, names and references

K-21 §3.9: the examples use `Box` before §6.6 declares it, and `double`, declared nowhere; declare both beside their use. clarity
K-22 §1 and §2.3: `userop` is missing from §1's list of the tokens §2 defines, is used in §2.3 before §2.6 defines it, and stands in Appendix A; add `userop` to §1's list. clarity
K-23 Appendix F, "configuration directory": cites §11.3 for the `startup` file, which §11.2 owns (Startup and history) and §11.3 does not mention; cite §11.2 too. clarity
K-24 Appendix F: "record update", "or-pattern" and "operator resolution" appear in no section, while shim, rigid, grapheme, live region, startup file and vocabulary are used by sections and missing; align both ways. clarity
K-25 Appendix D and E.19: both say the helper E.19 "describes", but `Erl` provides `atom` alone, so a reader looks for a function that does not exist; say "a helper the library writes in Erlang". clarity
K-26 §8.2: `Event`, `Pasted`, `Escape`, `Interrupt` and `Resized` are E.16's names, used with only the section's head pointer "(Appendix E)"; write "(Appendix E.16)" at The terminal. clarity
K-27 §5.3: points at §5.9 for a `{` ending a lambda body where the lambda is a `match` scrutinee, a rule §5.9 does not state; cite Appendix A's `MatchExpr` instead. clarity

#### Appendix E against E.0

K-28 E.16 against shape rule 4: `Terminal.size` answers `None` and `Terminal.subscribe` `Left(NotATerminal)` for one cause, no terminal, though a cause returns `Either`; `Terminal.size : () -> Either(Io.Error, Size) with m`.
K-29 E.0 rule 4 against E.1: `Io.print` is a pipe of two functions already here, outside the vocabularies, and rule 4 keeps `println`, not `print`; restate as K-42, or make `print` the primitive and `write` its byte form.
K-30 E.0 rule 4 against shape rule 3: rule 4 exempts only rule 2's and shape rule 2's operations, refusing `Char.toString` and `Bool.toString`, one call each; exempt shape rule 3's conversions too, and rule 1 defines "beneath it".
K-31 E.1 against shape rule 3: `Io.show` converts `Int`, `Float` and `Bool` to text beside their `toString`s, though a conversion exists once; say `Io.show` renders, not converts, or that the `toString`s are its restrictions.
K-32 E.20 against rule 2: `Bytes` is no container and rule 2 has no octets kind, so E.20 admits by its own rule and `Bytes.get` by none; rule 2 adds an octets kind, text's vocabulary less case plus `get`, or E.20 is a container.
K-33 E.13 against rules 1 to 3: `Random` is no shim, no kind has `seed` or `next`, and its algorithm and ranges are policy rule 3 refuses; rule 3 admits policy a section states and a program can replace, or E.13 goes to Appendix G.
K-34 E.16 against E.0: `styled`, the cursor moves, the clears and `columns` are pure Ernest over ECMA-48, admitted by no rule; rule 1 lets a system module add the pure operations its protocol needs, or they go to a library.
K-35 Shape rule 2 broken by `Terminal.size`, `Path.join`, `Path.split`, `List.repeat` and `Fs.create`; rename to `dimensions`, `under`, `segments`, `replicate`, `makeFile`, or make the verb per kind of type, which admits all but `Fs.create`.
K-36 Shape rule 1 against E.17: `Fs.makeLink` makes the link at its second argument, while `write`, `append` and `create` take the path they make first; `Fs.makeLink(at, target, ms)`, a link at the first path to the second.
K-37 Shape rule 3: `toUtf8` and `toHex` are named by an encoding, `Erl.atom` by neither type nor direction, `Foreign.from` by nothing; say an encoding names both directions, in one module, and `Erl.atom` is `Erl.toAtom`. clarity
K-38 E.5 and E.20 against rule 2: "Text adds" extends the container vocabulary, yet both deny being containers while providing `size`, `isEmpty` and `toList`; rule 2 says text and octets are containers read through `toList`. clarity
K-39 E.0 rule 1 against E.22: rule 1 names the supervisor's shims, the restart asked for, why a restarting began and the spawn order, which E.22 does not list as E.5 lists `drop`; E.22 names its primitives. clarity
K-40 E.0 rule 1 against E.5: rule 1 calls the `toString`s' inverses on `String` shims, but E.5's primitives are `toIntBase` and `toFloat`, and `toInt` is Ernest over `toIntBase`; rule 1 says `toIntBase` and `toFloat`. clarity
K-41 E.18 against shape rules 1 and 2: `Tcp.closeListener` beside `Tcp.close` is one verb, two names, like `Random.nextFloat`, which no rule covers; shape rule 2 says the second type a verb serves carries its name. clarity

#### Exceptions inside a rule

K-42 E.0 rule 4: the five kept compositions are four pairs §0's principle 2 already allows, and `Io.print` (K-29) is a sixth the list forgot; restated: "It is not a composition. A function outside rule 2's vocabulary, shape rule 2's operations and shape rule 3's conversions that is one call of a function already here, or a pipe of two, is not added: `List.concat`, `List.sum`. A pair is admitted whole as the vocabulary is: a predicate with its negation, `isSome` and `isNone`, `isLeft` and `isRight`, and a print with its line form, `print` and `println`, `printError` and `printlnError`. `Io.debug` is kept alone, since it stands where an expression stands." The list falls to the one exception.
K-43 Shape rule 4: the three exceptions that fault beyond `Float`'s range restate §3.1 by name, and `Float.pow` sits in it while also answering `None`; restated: "A partial operation returns `Optional`; one with a cause returns `Either`. An operation faults only where §3.1's float arithmetic faults, beyond the finite range, and as §7.4 or its own section says." No list remains.
K-44 Shape rule 8: the three lists of what takes no milliseconds are the rule, so `Tcp.read` takes them and `Os.read` does not, `Fs.write` does and `Tcp.write` does not; restated: "A function that waits for the file system, for a connection to be made or to deliver, or for a program to start, takes the milliseconds as its last argument and answers `Left(Timeout)`. One answered from what the runtime holds takes none, and so does one that waits on a stream, for its next input or for its reader to take what is written, since a stream ends or does not. One that delivers later takes a function into the caller's mailbox type." The one exception kept: `Os.start`'s milliseconds bound the program's run, not its start, so `Os.read` answers `Left(Timeout)` when they pass.
K-45 E.0 rule 1: what is a shim is a list of operations at the level of the sections; restated: "Its value is the runtime's: it reaches a representation the runtime owns, a table of the host's (Unicode's, the floating-point library's), or a process of the runtime's (§8.2, E.21, E.22). Each section names its primitives." The list falls out; `Erl.atom` is an atom, a representation the runtime owns.
K-46 E.0 rule 2: the path and filesystem vocabularies are E.14's and E.17's function lists copied into the rule, though one path type and one filesystem share nothing across modules; restated: "A kind of type that more than one module has, a container, a sequence, text, a set, a map, has a vocabulary below; a type alone of its kind lists its own in its section." The two lists move to E.14 and E.17.
K-47 Shape rule 2: `contains` on text finding a substring is an exception stated inside the verb list; restated: "`contains` asks whether the second argument is in the first: an element of a container, a substring of a text or of octets, so the empty one is in every one." Falls out.
K-48 Shape rule 5: what carries `with m` is a list with three named pure exceptions; restated: "A function is pure unless its result or its effect depends on more than its arguments: the process it runs in, the runtime's processes, or the host's clock." The list and the examples fall out.
K-49 §3.9: "which are all of them but `via` and `restarting`" restates §9.5's signatures after the sentence already says "whose own effect is a mailbox type"; restated: "A function of §9.4 or §9.5 whose own effect is a mailbox type, and a `foreign fn` whose effect is its own, is process-only." clarity
K-50 §6.3: the four types `<`, `<=`, `>` and `>=` compare are §3.10's list of the prelude `compare` types, copied; restated: "compare the types whose `compare` §9.6 provides". clarity
K-51 Shape rule 6: the reasons an example has no `// =>` line are a list; restated: "An example that the page's process cannot run and show, since it needs what that process lacks, a mailbox, a file, a socket, or a value `Io.debug` can write, has no `// =>` line and is only type-checked." clarity

### W, where the guide works hard

#### Where the guide explains, warns or notes

W-1 guide §5.2 line 1123, report §9.3, §6.9: a Down names no process, so each worker gets a tag, a closure wrap and a three-clause wait with two guards and a stale-skipping clause; a Down carrying its Process makes the wait one clause.
W-2 guide §1.1 line 154, §1.4 lines 237–251, report §4.5, §6.8: a bare result type means pure and none means inferred, so hello-world carries with Never and §1.4 teaches the asymmetry; an inferred effect under a bare type drops §1.4.
W-3 guide §5.1 line 1102, §5.7 line 1362, §6.4 line 1519, report §8.2, §6.4: print order is called uncertain and a worker reports via its supervisor, but Io.println is a synchronous call and the order is fixed; say which model holds.
W-4 guide §3.3 lines 628–635, report §4.8, §3.1: no numeric default, so the guide's one bold warning says an unannotated n + n is refused; a default to Int or an operator class would show it inferred and drop the warning.
W-5 guide §4.2 line 751, §4.4 line 807, report §6.6: a reply cannot be an element of a List, Map or Set, so a server keeps each pending reply in a waiter process of its own; a list of replies carrying one obligation would drop the waiter.
W-6 guide §3.5 lines 657–659, §5.1 line 1098, §7.3 line 1868, report §3.9, §11.5: a printed type hides two restrictions and shows two unwritable marks, so the guide says four times what it does not mean; print or admit the marks.
W-7 guide §4.3 line 790, report §6.3: the guide lists a receive guard's operands and leaves out a top-level let, which the report admits and which compiles; correct the sentence, or define a guard in one line so no list need be copied.
W-8 guide §2.3 line 347, report §3.1, §4.3: no aliases, and a constructor may take a type's name, so type Word = String is a nullary constructor named String and needs a warning and a help line; refuse such a name or admit aliases.
W-9 guide §5.5 lines 1282–1306, report E.15: an alarm cannot be cancelled, so the loop splits in two, deadlines carry an id, stale ones are dropped and a growing mailbox is warned of; a handle and Clock.cancel would give one loop.
W-10 guide §4.4 lines 859–906, report §10: mailboxes are unbounded and backpressure is the program's, so two paragraphs and a 37-line credit protocol teach it; a send that waits at a bound would make the section a sentence.
W-11 guide §2.9 line 538, §8.7 line 2081, report E.0 rule 8, E.18: no wait but a call's is unbounded, so a server retries accept and read on each Timeout and the prelude pairs call with callForever; a Forever time would drop the clauses.
W-12 guide §2.9 line 538, §5.5 line 1235, §8.7 line 2083, report E.0, E.18: three reads take no time and a socket sends nothing to a mailbox, so the guide lists them and teaches a reader process twice; Tcp.subscribe would drop it.
W-13 guide §4.1 line 727, §5.5 line 1220, report §6.2: self() in the spawned lambda is the child, so nine programs bind let me = self() first and two warnings explain it; a spawn passing the spawner's address would remove the line.
W-14 guide §2.4 lines 363 and 370, report §3.5, E.1: the canonical order reserved for storage and transport leaks into Io.show, so the guide says a value does not print as declared; Io.show in declaration order removes the sentence.
W-15 guide §2.5 line 402, §5.5 line 1269, report §3.10, §6.5: an adapted address is a function, so addresses have no equality and comparisons go through Process.fromAddress, taught twice; equality on the process behind removes it.
W-16 guide §5.2 line 1121, report §6.9, §6.2: a late monitor learns only Unknown, so the guide explains a race to justify spawnMonitored, used five times to monitor's none; a reason kept for its monitors would let spawn and monitor do.
W-17 guide §5.2 line 1167, §6.4 lines 1495–1497, report §6.9: a Down is unordered with the dead process's messages and cannot be taken back, so a receive nests in a receive and stale deaths are skipped; a demonitor would make it one.
W-18 guide §4.2 line 749, report §6.6: only a literal fault discharges a reply, so a path that faults through a helper must still answer on paper; a Never result type on a function that does not return would let the check see through.
W-19 guide §2.8 line 526, §3.2 line 617, §12 line 2255, report §5.3, §5.7: a lambda's body extends as far as it can, so one after |> needs parentheses, taught as a note, a warning and a FAQ; a body ending at |> would drop them.
W-20 guide §12 lines 2251–2253, §7.1 line 1661, report §4.2: there is no import, so a FAQ and a note explain names written whole; none while principle 3 stands, the FAQ answers a question the rule guarantees.
W-21 guide §6.5 line 1571, report §8.5, §11.2: a module's service bindings run under ern test too, so every service exports a start for its tests; if a test could run without the bindings, start need not be exported.
W-22 guide §3.4 line 646, §6.3 line 1473, report §7.4: a pure function can fault, said twice since a reader expects pure to mean total; a line in the report's §6.1 table would give the guide one place to point.
W-23 guide §6.6 lines 1618 and 1622, report E.22, §6.9: a restart comes at its next wait and a kill is not a stop, so the guide warns of a sibling's old state and of a stop message first; a restart at a receive would shorten the first.
W-24 guide §4.4 line 805, §4.8 line 1052, §13 line 2271, report §6.6: a timeout does not cancel the work, so a warning and an exercise say a resent request may act twice; none, it is what a deadline means.
W-25 guide §7.3 line 1798, report §4.6: a top-level let generalizes, so the hashed operations could be a let, yet the guide makes it a function of nothing and explains the choice; write the let, or drop the sentence.
W-26 guide §8.6 line 2077, report §5.11: a bitstring pattern counts as matching no value, so a match that covers every Bytes value still ends in a clause that takes anything; coverage that knows the empty and rest patterns would drop it.
W-27 guide §8.6 line 2045, report §5.11: only big and little, so the guide says host-order data comes through foreign code; a native specifier would remove the sentence.
W-28 guide §2.1 line 262, report §2.5: there is no interpolation, so every printed line is a concatenation, about forty times; none while principle 5 holds, the note is the cost.
W-29 guide §1.1 line 158, report E.1: Io.debug sends, so a pure function cannot use it and no guide program does; an Io.debug pure by fiat, as a trace is, would remove the warning.
W-30 guide §1.3 line 233, §4.5 line 941, report §8.2: a program reads lines or keys, not both, since the first claim stands; none, the rule is the sentence.

#### Ways around a rule

W-31 guide §0 line 100, §2.2 line 299, report §5.4: a non-last statement has type Unit, so let _ = e discards a value in eleven programs and a foreach body is a block; a foreach taking (a) -> b would make it one expression.
W-32 guide §4.4 line 885, report §5.8, §5: no if without else, so a conditional send ends in else Unit; an if without else at type Unit would drop it.
W-33 guide §4.4 lines 833–836, report §6.6: see W-5.
W-34 guide §4.4 line 844, report §6.6: a Reply is made only by a call, so a process that must ask and keep receiving spawns a helper to block for it; an Address.ask delivering the answer to the caller's mailbox would make it one line.
W-35 guide §5.5 line 1269, §8.7 line 2100, report §3.10, E.18: Tcp.give takes a Process where kill and monitor take an Address, so the guide writes Process.fromAddress, see W-15; Tcp.give taking the address would drop it.
W-36 guide §2.9 line 538, §8.7 lines 2081–2083: see W-11, W-12.
W-37 guide §5.2 lines 1123–1145: see W-1, W-17.
W-38 guide §5.6 line 1358, report §6.4, §6.9: a worker's message may arrive after main's, so results go through main and each count crosses two mailboxes; a Down delivered after the dead process's messages would let workers send direct.
W-39 guide §4.3 line 790, report §6.3: a guard admits no call, so the guide says to receive then match, losing the selection a guard is for; a pure call in a guard, its fault a fall-through, would remove the sentence.
W-40 guide §2.7 line 504, §6.1 line 1376, §6.2 line 1417, report §5.5: all <- bindings in a block share one sum type, so Either.fromOptional joins the two chains; none, the conversion is where the reason belongs.
W-41 guide §3.1 line 596, report §5.2: no partial application, so a lambda stands for it; none, the note is the cost.
W-42 guide §5.5 line 1222, §5.2 line 1136, report §5.6, E.15: a named constructor is neither a value nor a function, so a wrap is a bare name when positional and a lambda otherwise; none, two spellings are the cost of named fields.
W-43 guide §10 line 2228, §6.4 line 1521, report §6.9: there are no links, so a loop that must die with another needs a Down clause the guide never shows; none, but a program showing the clause would teach it.
W-44 guide §2.6 line 443, report §5.10: no pinned variable in a pattern, so equality is a guard; none, the Erlang reader is told once.
W-45 guide §2.3 lines 344 and 347, report §3.5, §3.1: exactly one positional field and no alias, so a point is a wrapped tuple and an alias a wrapper; several positional fields would let Point(Int, Int) stand, and see W-8 for the alias.
W-46 guide §8.5 lines 1979–2018, report §8.4, E.19: Either's ABI is {'Right', V} and {'Left', R}, so calling an OTP-style API needs an Erlang helper, erlc and a .erl file; an ABI of {ok, V} and {error, R} would drop them.
W-47 guide §6.6 line 1622: see W-23.

#### Jobs taught two ways

W-48 guide §1.1 line 154, report §6.8, §3.9: a function that does not receive is with Never or with m, the guide varies and the wrong one is refused; one spelling, with m, and with Never only for a root that waits, makes §1.1 a sentence.
W-49 guide §5.2 lines 1109–1121: see W-16.
W-50 guide §4.4 line 805, §6.5 line 1569, report §6.6: a request is call with a limit or callForever, eleven to one, and the wrong choice faults the caller with the callee's cause; one call whose time may be Forever, or name the default.
W-51 guide §6.4, §6.5, §6.6, report §6.9, E.22: surviving a fault is a process per job, restarting or Supervisor, a section each, in an order not the report's; none, the guide could name the default for a server.
W-52 guide §7.3 lines 1760–1866, report §3.9: Hindley-Milner alone, so one contract over several representations is taught in two record forms over 110 lines and two projects, then when to use which; one form named, the other cut.
W-53 guide §5.5 lines 1222 and 1235, §8.7 line 2083: see W-12.
W-54 see W-42.
W-55 guide §8.6 lines 2054–2075, §8.7 line 2128, report E.20: bytes are split at a line feed by hand in one program and by Bytes.split in the next, against the guide's own advice; drop the hand-written pair and teach Bytes.split once.
W-56 guide §2.4 line 372, report §3.5: a field is read by a selector on a record and by a match on a sum; none, the two ways follow the type's shape.
W-57 guide §7.1 lines 1665–1677, report §11.1: building is shown file by file and as the tree; the guide could show directory mode alone.
W-58 guide §2.7 line 513, §6.1 line 1370, report §5.5, §7.1: a failure as a value is Optional or Either, never both in one block; none, noted for the count.
W-59 guide §4.3 line 788, §5.5 line 1282, report §6.3, E.15: waiting a while is receive after for a Never process and Clock.alarm for one that receives; none.

#### Examples a reader would not have predicted

W-60 guide §2.5 line 409, §7.2 line 1725, §4.4 line 833, report §4.4: annotations the rules do not ask for, on members, lambdas, service bindings and Down fields, all compile without; use the report's spelling, or say they are for the reader.
W-61 guide §5.6 lines 1327–1330, §8.7 lines 2129–2132: see W-31.
W-62 guide §4.4 line 885: see W-32.
W-63 guide §6.4 lines 1498–1504: see W-17.
W-64 guide §5.2 lines 1140–1145: see W-1.
W-65 guide §8.6 lines 2069–2075: see W-55.
W-66 guide §8.7 line 2100: see W-35.
W-67 guide §5.5 lines 1292–1302: see W-9.
W-68 guide §4.4 line 844: see W-34.
W-69 guide §7.3 line 1803: see W-25.
W-70 guide §4.4 lines 825 and 836, report §3.3, E.2: a queue is appended with <> on a linked list where a reader expects it kept reversed, or :: and a List.reverse; none, a teaching program may accept the cost and could say so.
W-71 guide §5.6 lines 1316–1347: see W-38.
W-72 guide §6.5 line 1550, report §4.6, §3.9: a block let binding a lambda that calls a process-only function is generalized, which the top-level exception does not predict; §4.6 could say the exception is the top-level form's alone.

#### Rules the guide never teaches and never uses

W-73 report §2.2: block comments and their nesting, never written; //// as an ordinary comment; a /// after a token is an error.
W-74 report §2.5: a Char literal, never written; float literals with an exponent; \u{...}, \r and \'; a raw string only at the prompt; hex, octal and binary literals only in a list; a float literal beyond the finite range is an error.
W-75 report §2.6: the precedence table; a < -1 against a<-1, for which §11.5 promises a help line the parser does not give at declaration level; prefix - and ! bind tighter than every binary operator and do not apply twice.
W-76 report §3.4: with binds to the nearest arrow, and how a function whose result is a function is annotated.
W-77 report §3.9: a type variable named first in a lambda's annotation is an error unless the lambda is a let's whole value; no polymorphic recursion; two callbacks with different concrete effects are a type error; §4.5's pure annotation making pure every parameter the body calls.
W-78 report §3.10: Bool, Optional and Path have no ordering; the equality constraint is the union over branches.
W-79 report §4.2: Prelude. past a shadowing name, mentioned once, never written; Prelude.List.size past a member of the module's own; a type member's namespace against a module's; a dotted name's first segment is the module's type where it has a member of the name.
W-80 report §4.4: Io.show writes an abstract value as <abstract> outside its module, and by its representation through a type variable.
W-81 report §4.5, §5.4, §4.6: a local fn in a block, mentioned once, never written; use only after every let it references; two fns of one name; a local fn may not take a parameter's or a let's name; a binding does not see its own name, so a recursive function is declared with fn.
W-82 report §4.7: a foreign function's parameters' type variables are not reply-carrying; Foreign.from on a reply is a type error.
W-83 report §4.8, §5.1: T.negate for prefix -; an operator member, named twice in prose, never written; let T.op is an error; fn add(a, b) = a + b in a block is an error whatever calls it; the callee is evaluated before its arguments; the order of x |> f(a)(b).
W-84 report §5.5: let p : T <- e; the sum type decided from the block's type where the expression's is open, and the error where both are.
W-85 report §5.7: x |> Some is Some(x); x |> Some(2) and x |> [f] are type errors; x |> f(a)(b) is f(a)(x, b).
W-86 report §5.10: Circle() for a named constructor with every field omitted, and the errors None(), Some, Some() and bare Circle; a negative literal pattern; x :: rest as all; as in a program, prose only, never written.
W-87 report §5.11: utf8, utf16, utf32, signed and float segments, never written; an expression and a top-level let as a size; a negative signed segment; the redundancy rule for bitstring patterns.
W-88 report §6.1: two calls with different concrete effects in one body are a type error.
W-89 report §6.2, §6.9: sending to a dead process has no effect; kill on a dead process has no effect; kill, monitor and restarting(Unlimited, f), never written; a wrap that does not finish holds up no other delivery; the entry process's site and Unknown's site; the site of spawn passed as a value.
W-90 report §6.3: after with a time below 0 is 0; a top-level let read when the receive begins, taught as the opposite in W-7.
W-91 report §6.6: a request handed on is watched only where it was sent, so a waiter's death leaves the queue's caller to its deadline, unsaid; a local fn may not capture a reply; as on a reply scrutinee and let h = g on a reply-capturing lambda are errors; a Reply is answered twice only by foreign code.
W-92 report §6.8: a with Never function can be called only where the mailbox is Never; the guide teaches when to write with Never, not what it forbids.
W-93 report §7.4: the causes by their text but division by zero: float arithmetic error, Int out of Float range, segment overflow, bitstring not byte-aligned, callee, the foreign mismatches; Os.exit outside 0 to 255.
W-94 report §8.1: a pure () -> Unit is an entry point; a result type that is a variable is taken as Unit; main is a convention, not a reserved name; --main refuses a let.
W-95 report §8.2: the terminal's events, paste bracketing and echo; Terminal.subscribe, Io.read and Io.write, never written; standard error's end ending the program.
W-96 report §8.4: an address foreign code gives is foreign unless it names a process of the program; a result type variable no parameter names matches no value; the standard library's own crossings are unchecked; Foreign.from gives the value without a proxy or a check.
W-97 report §8.5: the standard library is initialized whole; the order two modules' initializers print in; a faulting initializer is reported under its binding; a let naming a function that names the let is a cycle.
W-98 report §9.3: Test's run is with Never, so a test cannot receive and a test of a process must call it; the guide says it may spawn and send, and stops.
W-99 report §10: tail positions include the right operand of && and || and the call a pipe makes; preemptive scheduling; no shared memory but foreign state.
W-100 report §11.2, the shell: let x <- e, an input binding a name whose type it does not settle, and a reply-carrying input are refused; :type refuses a let; $Input2.T for a shadowed type; :output, :set output n and :faults keeping the last hundred; a startup file that is not UTF-8.
W-101 report §11.5: an effect variable that occurs once prints as pure; the label naming the prelude's qualified name where a module's declaration hides it; a control character drawn as its picture.
W-102 report §11.6, §11.8: ern format's layout beyond one layout; exit status 70 for a failure of ern itself and 130 for the shell under an interrupt.
W-103 Appendix E, unused: Char, Bool, Random, Path, Fs, Terminal, Os (start, run, read, write), Clock (alarmAt, monotonic, now), Process (info, live, faults), Optional (map, andThen), Either (map, mapLeft, andThen), List (tryMap, tryFold), String.graphemes, Io (debug, print, write, read), Erl.atom, Foreign, Bytes (toHex, fromHex), Set.

### L, part 1: the log to 2026-09-19

#### Families

##### Family 1. What the host's semantics decide (11 entries, 8 undecided)

Verdict: no deciding sentence; the practice is consistent and unstated, the host's rule taken where its outcome is seen and refused where it would be silent. Proposed for §10, or under principle 3: "Where the host has a rule for an operation, that rule is Ernest's when its outcome is a value or a fault the program sees. Where the host's outcome would be silent, a truncation, a fault made false, a value coerced, Ernest checks the value or refuses the form, and the cost of the check falls on that form alone. A message is the one exception (§6.2, §10)."
L1-1 *Numeric Semantics and Fault Rules* (l. 908): Int division truncates toward zero, matching BEAM; principle 3 cited. Undecided by §0: principle 3 asks that the rule be stated, not which convention; the host decided.
L1-2 *Third-Round Review Response* (l. 1455): finite-only Float taken as aligning with BEAM; principle 5. Undecided: the same principle argued the opposite in L1-3 the same day.
L1-3 *Float Semantics: Minimal Reparation, Reject the Bloat* (l. 1942): finite-only Float rejected for IEEE simplicity; principles 2 and 5. Undecided: principle 5 on both sides in one day; BEAM's badarith decided, unstated as a rule.
L1-4 *Guards and Bitstring Size Expressions* (l. 1739): guard faults as match failure, the Erlang model, rejected as silently swallowing a fault; principle 3. Decided as stated.
L1-5 *Receive Guards Are Guard Expressions* (l. 2662): BEAM's rule taken; principles 1, 3 and 5. Undecided: the principles recruited after the cost argument; the grammar restriction that reconciles it with L1-4 is unstated.
L1-6 *Bitstrings* (l. 2654): the host's silent truncation overridden by a per-segment overflow check; no principle. Undecided; the opposite of L1-5's economy.
L1-7 *Reply Timeout Semantics* (l. 962): silent discard taken, matching gen_server:call; principle 3 cited for the stating. Undecided: principle 3 as written, failure visible, implies the rejected option, a late answer seen.
L1-8 *Distributed Failure: One Simple Model* (l. 1700): loss is terminal, the Erlang model, taken; principles 2, 3 and 5. Decided as far as it goes; the best-effort send is family 6's.
L1-9 *Terminology Sweep* (l. 600): on BEAM the Erlang convention wins; no principle. Undecided; a rule the log applies elsewhere and never states.
L1-10 *Report Read-Through Fixes* (l. 2394): monitor on a dead process delivers immediately, Erlang's rule, least surprise on BEAM; principle 1 read as the BEAM reader, not §0's. Undecided by §0's text.
L1-11 *Appendix D (ETS) Fixes* (l. 2151): the ABI does not silently convert binaries to atoms, a policy call not a coercion; no principle named, the argument is principle 3's. Decided in substance.

##### Family 2. Which forms enter the language: a second spelling, a literal form (13 entries, 8 undecided)

Verdict: undecided; the practice admits a second spelling where the first nests where the reader reads a sequence or rebuilds what a pattern holds, and refuses one that only shortens. Proposed under principle 2: "A second spelling of what the language writes enters when the first would nest where the reader reads a sequence, or would rebuild what a pattern already holds; a spelling that only shortens stays out. A literal form enters when the value has no faithful spelling without it."
L1-12 *Tried and Rejected* (l. 86): `?` for Either, `use Net.Http` and application by juxtaposition rejected; principles 2 and 3. Decided as stated; `use` is a "for now".
L1-13 *Grammar Audit* (l. 140): `let` returned, the grammar LL(1) throughout outranking four characters a line; principle 4. Decided.
L1-14 *`as`* (l. 204): taken because the first outside reader reached for it and four languages have it; no principle, and principle 2 as written says variant. Undecided; `^x` refused alongside with no dividing line.
L1-15 *Against Gleam* (l. 208): `use`, `|>`, labelled arguments, `let assert`, `panic`, field access, `import`, `pub`, aliases absent; no reason for `|>`, `pub` and field access, all since admitted. Undecided.
L1-16 *Pipe Operator `|>`* (l. 463): admitted as every typed FP language has it, small cost; no principle, and principle 2 as written refuses a second f(x). Undecided; its "reads left to right" is the family's missing sentence.
L1-17 *Against Labeled Function Arguments* (l. 438): rejected; principles 2 and 5. Decided as stated; the count trigger at its end is family 10's.
L1-18 *Bit Arrays in the Report* (l. 487): borrowed not explored, which flips the cost calculus; no principle, a cost decision. Undecided by §0; stands by §5.11.
L1-19 *Section 2 Tightening* (l. 632), items 5 and 6: raw strings refused on principle 2, non-decimal literals and separators on principle 5; §2.5 has all today. Undecided: a literal form has no rule in §0 or the log.
L1-20 *Grammar: Negative Numeric Patterns and Lambda-After-Pipe Parens* (l. 1629): principles 4 and 1. Decided.
L1-21 *`export` Keyword* (l. 1090): visibility by naming convention rejected; principles 2 and 5. Decided, but overturns Grammar Audit l. 159's visibility in the name on principle 3 without citing principle 3; see L1-100.
L1-22 *Gleam Feature Pass* (l. 2318): `use x <-`, function capture `f(_, y)` and list spread deferred under the growth rule. Undecided today: the rule is abolished for the library and nothing replaced it for a form.
L1-23 *Pattern Alternatives* (l. 2682): admitted on a count, a reviewer counting as a program; the spelling `or` over `|` on principle 1, exactly §0's. Admission undecided, spelling decided.
L1-24 *`Bool.ern` Added* (l. 2278): prefix `!` refused because no program wrote negation three times; a count. §4.8 has `!` today. Undecided by §0.

##### Family 3. Which reader principle 1 means (9 entries, 7 undecided)

Verdict: undecided; the log cites principle 1 as often for the reader arriving from other languages as for §0's reader who knows the rest of Ernest. Proposed as the second sentence of principle 1: "The reader is one who knows the rest of Ernest. Where two names read alike within Ernest, the one the reader's other languages use is taken."
L1-25 *`Text` → `String`* (l. 699): a programmer arriving looks for `String`; principle 1 for the arriving reader, not §0's. Undecided by §0's text.
L1-26 *`()` → `Void`* (l. 717): C-family readers get it instantly; principle 1 for the arriving reader. Undecided; reversed two days later by L1-27 on the other reading.
L1-27 *`Void` → `Unit`* (l. 2378): a reader who knows `Never` predicts `Void` is its cousin; principle 1 for §0's reader. Decided as stated; the pair proves the two readings differ.
L1-28 *`Set(a)` Restored* (l. 564): a reader wanting deduplication looks for `Set(a)`; principle 1 for the arriving reader. Undecided by §0; decided today by E.0 rule 2.
L1-29 *`opaque` → `abstract`* (l. 653): the reviewer's vocabulary is the audience's; principle 1 for the arriving reader. Undecided by §0.
L1-30 *`recv` → `receive`* (l. 645): least surprise argued against `recv`; principle 1 for the Erlang reader. Undecided by §0.
L1-31 *List and Concat Operators* (l. 616): `::` universal in typed FP, `<>` from Gleam; no principle. Undecided.
L1-32 *Grammar Audit* second pass (l. 149): Gleam's `True` lost to every other language's `true`; no principle. Undecided.
L1-33 *Colliding Words* and *The Word* (l. 192, 196): the type-theory reader's collisions removed; no principle named. Decided in substance, since a word meaning something else surprises §0's reader too.

##### Family 4. What faults at run time and what returns `Optional` or `Either` (9 entries, 6 undecided)

Verdict: undecided; the practice is that operators and grammar forms fault, functions return Optional or Either, and a function faults only where Float's finite range is the type's own fault. Proposed for §7.4's opening or E.0 shape rule 4: "An operator, and a construction the grammar gives, faults, since the form has no place for `Optional`: `/`, `%`, `<<...>>`. A function returns `Optional` or `Either` for an input outside its domain, and faults only where its result is a `Float` the finite range cannot hold, which is the type's own fault (§3.1), or where it is `fault` itself."
L1-34 *Tried and Rejected* (l. 92): a dying prelude rejected for a total one, a death something that happened to the process; no principle. Decided as the rule; the entries below are its exceptions.
L1-35 *Grammar Audit*, Division (l. 144): three positions in a day, `/` returning Optional, then never failing, then a fault; principle 1 for two of them. Undecided by §0: an operator having no place for Optional is unstated.
L1-36 *Against Gleam* (l. 210): `todo`, a fault the process chose, the second deliberate exception; no principle. Decided by naming; today `fault` (§9.6).
L1-37 *Numeric Semantics* (l. 908): Float division by zero is IEEE, faults for catastrophes only, `Float.compare` on NaN faults; principle 3. Undecided; reversed by L1-2 the same day.
L1-38 *Fourth-Round Review Response* (l. 1355): `Int.toFloat` faults out of range; principles 1 and 5. Undecided: shape rule 4 names it an exception, and principle 1 would as easily predict Optional, as `Int.div` gives.
L1-39 *`Bytes` and Bitstring Alignment* (l. 938): non-aligned constructions a compile error for constant sizes, a fault for dynamic; no principle, matches every use. Compile half decided (family 5); fault half undecided.
L1-40 *Fault List and Initialization* (l. 1807): softening §7.4's opening rejected, the list of exceptions fine when complete; principle 3. Undecided: a complete list is not a rule, and it has changed twice since.
L1-41 *Gleam Feature Pass* (l. 2331): `panic` and `assert` collapsed into `todo(msg)`; principle 2 in substance. Decided.
L1-42 *Appendix E: Admission and Shape Rules* (l. 2517): partial returns Optional, faults only per §7.4; a rule by reference to a list. Undecided.

##### Family 5. What is refused when a program is compiled and what faults when it runs (10 entries, 4 undecided)

Verdict: decided in the main by the sentence L1-50 states for one form and L1-52 for another. Proposed for §0 or §7: "A rule the type decides is checked when the program is compiled; one the value decides faults when it runs. Where a compile-time check refuses a sound program, the refusal is a rule of the report and its error names what to write."
L1-43 *Equality Policy for Polymorphic Types* (l. 808): runtime check rejected on the static bias, principle 3, which the entry also charges against its own choice. Undecided by principle 3; principle 5 and no type classes decided.
L1-44 *`Reply` Ownership Made Compositional* (l. 786): the static check chosen on the static bias; principle 3. Decided as stated; a runtime one-shot is visible in neither code nor type.
L1-45 *Reply Ownership Extends to Reply-Carrying Types* (l. 2103): `Stop` values cannot be duplicated, an over-approximation accepted because no program does it; a count. Undecided; §6.6 keeps it with no sentence admitting it.
L1-46 *Effect Variables: Primitives Are Non-Empty* (l. 1600): ignoring the hole because programs miss it rejected, soundness matters unexercised. Decided; the one refusal of a count before 2026-09-20.
L1-47 *Third-Round Review Response*, U01 (l. 1493): a pure `work` for spawn rejected, `with Never` required; principle 3. Undecided by principle 3: §6.2 today lets a pure `f` fit, reversed 2026-09-26.
L1-48 *Top-Level Initialization Specified* (l. 880): pure, eager, dependency-ordered lets; principle 3 carried it. Undecided by principle 3: every alternative states a semantics; §4.6 today allows spawn, send and call.
L1-49 *Fault List and Initialization* (l. 1818): strict-total initializers rejected as undecidable. Decided: what cannot be checked faults.
L1-50 *`Bytes` and Bitstring Alignment* (l. 955) and *Bitstring `bits` Segments* (l. 1862): constant violations are compile errors, dynamic ones fault. Decided: the family's rule, stated for one form.
L1-51 *Operators Resolved in Inference* (l. 2644): `a <> b <> "!"` unannotated refused rather than guess the result type; no principle. Decided by §4.8, not by §0.
L1-52 *Bitstrings* (l. 2658): a bitstring pattern counts as never complete; principles 2 and 5 keep one sentence, principle 1 answered by the error. Decided; an over-approximation with its ground named, the model for L1-45.

##### Family 6. What is dropped without notice at run time (6 entries, 3 undecided)

Verdict: undecided; the practice is that a message with no one to receive it is dropped silently and nothing else is. Proposed for §6.2, beside "sending to a dead process has no effect": "A `send` promises the sender nothing. A message whose receiver has ended, whose call has timed out, or whose peer is lost is dropped without notice, and that is the one silence in the language; every other loss is a fault."
L1-53 *Backpressure* (l. 240): silent drop rejected as data loss without notification; principle 3. Decided.
L1-54 *Reply Timeout Semantics* (l. 970): silent discard taken, "invisible to caller and callee" in its own words; principle 3 cited. Undecided by principle 3.
L1-55 *Distributed Failure* (l. 1722): `send` best-effort, in-flight messages dropped at loss without notification; principle 3 cited as now stated explicitly. Undecided: stated, not visible.
L1-56 *Guards and Bitstring Size Expressions* (l. 1746): a swallowed guard fault refused; principle 3. Decided; the opposite verdict to L1-54 on the same principle.
L1-57 *What the Reply Check Guarantees* (l. 2626): a second answer discarded like a late one; no principle. Undecided.
L1-58 *The Message Check Moves to the Point of Exposure* (l. 2668): ends the invisible breach of a foreign message no clause matched; principle 3 in substance. Decided.

##### Family 7. What waits with a limit, what without, and what answers at once (7 entries, 3 undecided)

Verdict: undecided. Proposed for E.0 shape rule 8, in place of its list: "A function waits with a limit where what it waits for can end or hang unseen, a callee, a file, a socket, a peer; it waits without one where it waits for the program's user or for its own stream to take what it wrote; it answers at once where nothing is waited for. `Address.callForever` opts out of the limit by name."
L1-59 *Request-Reply* (l. 220): `Address.call` takes a mandatory timeout, Optional in the return, Erlang's five-second default picked wrong; principle 3. Decided.
L1-60 *`Address.callForever` in the Prelude* (l. 420): added for consistency with `receive` without `after`; argued not a variant since the return type differs, which would license any pair. Undecided by §0; kept 2026-09-29.
L1-61 *Four "Partly Resolved" Tails*, R11 (l. 1560): the clock starts at the call, no tiebreak between reply and timeout, the most natural reading; no principle. Decided in substance.
L1-62 *System Modules* (l. 2546): a waiting function takes milliseconds last and answers `Left(Timeout)`, a later delivery takes a message function; principles 1 and 2. Decided for the shape, not for which functions wait.
L1-63 *Nine Points from the Consistency Pass* (l. 2676): `Clock.now`, `Tcp.listen` and `Io.readLine` named as exceptions to shape rule 8 rather than changing. Undecided: a rule naming twenty-three members has no criterion.
L1-64 *Backpressure* (l. 234): block-on-full rejected as a block invisible at the `send`; principle 3. Undecided by principle 3: §8.2 and shape rule 8 today make eight system writes wait so (2026-09-27).
L1-65 *The Erlang Standard Library, Read for Ernest* (l. 2561): `cancel` absent since an alarm is one message to ignore and a cancel needs a handle and a race; principle 5 in substance. Decided.

##### Family 8. Where a thing lives: the language, the prelude, the standard library (8 entries, 3 undecided)

Verdict: decided for names by §9's sentence; for where an operation's code lives, the language or the library, the log has no sentence, and supervision moved twice. Proposed for §9: "An operation is the language's when the runtime alone can give it its meaning, a restart that keeps an address, and the library's when Ernest can write it over the language. That an operation is common puts it nowhere."
L1-66 *Three Layers* (l. 326): the prelude is what the report needs, the stdlib what the ecosystem provides. Decided; §9's opening today.
L1-67 *`parallelRemote` in the Prelude* (l. 402): put in the prelude for symmetry with `remote` and for speed; principle 5 against a keyword. Undecided: E.0 rule 1 refuses those reasons; superseded, §6.7 has no `remote`.
L1-68 *Against OTP as a Language Feature* (l. 542): no canonical restart policy, one policy too many; principle 5. Undecided by principle 5: §9.5 has `restarting` and E.22 three strategies today; the line moved twice.
L1-69 *Tests* (l. 292): a naming convention rejected as invisible in the type, principle 3; a `test` keyword rejected; tests as values taken. Decided; §9.3 today.
L1-70 *Bit Operators as Stdlib Functions* (l. 2310): library, not language; principle 5. Decided.
L1-71 *Appendix E: Admission and Shape Rules* (l. 2532): prelude or stdlib is about which document guarantees a name, never the code. Decided; the family's sentence for names, §9 today.
L1-72 *System Modules* (l. 2550): `Random` over `rand`, `Seed` a foreign type, on E.0 rule 1 read against its text. Undecided by that reading; reversed 2026-09-20, E.13 is SplitMix64 in Ernest.
L1-73 *Tests, `Erl`, and `Ets` Moved* (l. 2700): `run` is `() -> TestResult with Never`, a process root; principle 2 in substance. Decided.

##### Family 9. Which operations are operators and which are functions of a type's module (7 entries, 2 undecided)

Verdict: which operations are members is decided (§4.8's closed `userop`, `compare`); which are operators at all is not, `!` refused on a count then admitted, the bit operators refused on a count and a collision. Proposed for §2.6 or §4.8: "The operators are the closed set of §2.6. An operation is written as an operator when the reader's languages agree on its symbol and the symbol is free; it is then a member of the operand's type, or the language's where §4.8 says it cannot be defined per type. Every other operation is a function of its type's module."
L1-74 *Dropped from Unison* (l. 75): ordering per type in its namespace, `Int.compare`, `<` resolved like `+`. Decided; §3.10 today.
L1-75 *Grammar Audit* (l. 141, 153): `Int.+` is grammar not a lexer rule, `+ : (Money, Money) -> Money` declares `Money.+`; principle 4. Decided.
L1-76 *Sixth-Round Review Response*, NR02 (l. 995): members for any local type, concrete or abstract; principle 2. Decided.
L1-77 *`Bool.ern` Added* (l. 2289): `not` a function, not `!`, on a count. §4.8 today has both `!` and `Bool.not`. Undecided by §0.
L1-78 *Bit Operators as Stdlib Functions* (l. 2310): keyword operators refused as six reserved words, principle 5; symbols blocked by `<<`. Keyword half decided; symbol half undecided, nothing says why `!` may be a symbol and `&` not.
L1-79 *Pipe Operator `|>`* (l. 483): `Int.|>` rejected, `|>` a syntactic form not a namespaced function. Decided; §2.6's `userop` today.
L1-80 *Operators Resolved in Inference* (l. 2648): `negate` in the operand type's namespace; principle 2 in substance. Decided.

##### Family 10. What the standard library admits (17 entries, 0 undecided today)

Verdict: decided by E.0's four rules and Nothing Waits for a Program (2026-09-20); two names the counts deferred, a `Time` module and `Fs.watch`, are decided by no rule today. Proposed for E.0 rule 2's closing: "A published specification, a date, a pattern language, a format, is a library's, not a module's vocabulary."
L1-81 *Three Layers* (l. 340): a pattern a paper program writes three times is promoted; no principle. Decided on a count; superseded by E.0.
L1-82 *Standard Library Baseline* (l. 375, 396): the three-uses rule and a deferred list of thirty names; no principle. Decided on a count; superseded by E.0.
L1-83 *`Sys.stderr`, `Io.eprint`, `Io.eprintln` Removed* (l. 514): no paper program sends to stderr; no principle. Decided on a count; superseded by E.0.
L1-84 *`Set(a)` Removed From the Prelude* (l. 527): neither the grammar nor any program uses it; no principle. Decided on a count; superseded by E.0.
L1-85 *`Set(a)` Restored* (l. 564): principle 1 for the arriving reader (family 3). Superseded by E.0 rule 2.
L1-86 *`Bool.ern` Added* (l. 2278): a function because no program wrote negation three times; no principle. Decided on a count; superseded by E.0.
L1-87 *Bit Operators* (l. 2312): the same growth-rule exception as `parallelRemote` and `Address.callForever`. Decided on a count; superseded by E.0.
L1-88 *Gleam Feature Pass* (l. 2361): future adds to pass through the growth rule. Decided on a count; superseded by E.0 and Nothing Waits for a Program.
L1-89 *Appendix E: Three Rules* (l. 2507): in when the value lives in the runtime or the hand-written version is the same few lines every time. Superseded by E.0's four rules.
L1-90 *Appendix E: Admission and Shape Rules* (l. 2515): corpus-driven, one program under `examples/` enough. Decided on a count; superseded by Nothing Waits for a Program.
L1-91 *Appendix E: Read Back* (l. 2540): `printTo`, `String.any` and `toBool` removed by rules 3 and 4. Decided by the rules.
L1-92 *The Erlang Standard Library, Read for Ernest* (l. 2564, 2569): `binary`, `array`, `queue`, `Float.sqrt`, a `Time` module, `Sys.args` and `Sys.env` wait for a program. Superseded by E.0; `Time` is decided by nothing.
L1-93 *Gleam's Standard Library, Compared* (l. 2579): `Float.looselyEquals` and stderr wait for a program. Decided on a count; superseded by E.0.
L1-94 *Path by Its Structure* (l. 2581): rule 2's vocabulary, `withSuffix` out by rule 4. Decided by the rules.
L1-95 *Fs by Its Structure* (l. 2587): rule 2's vocabulary; `watch` waits for a program that must not poll. Decided by the rules, but `Fs.watch` is decided by nothing today.
L1-96 *The Final Pass* (l. 2597): `Map.update` by rule 3, `Char` case functions by shape rule 2. Decided by the rules.
L1-97 *Ambient Sys* (l. 369): `Io.print` beside `Io.printTo`, neither a variant, and principle 2's convenience clause written for them; L1-91 removed the pair by rule 4 four days later. Superseded.

##### Family 11. Distribution and remote computation (9 entries, 0 undecided today)

Verdict: decided; principle 3 throughout for what stands, §8.7 content addressing, §10 loss is terminal, §8.6 per-node deadlock, and everything decided for `remote` superseded by §6.7. No sentence proposed.
L1-98 *Distribution*, *Remote Ergonomics*, *`parallelRemote`*, *`remote` Is Not Pure*, the three code-shipping entries, *Distributed Failure*, *Deadlock Detection*, *Four Tails* R12, R13 (l. 165 to 2231): principle 3 throughout. Decided; `remote` superseded by §6.7.

#### Decided on cost, time or for now

L1-99 *Request-Reply* (l. 228): the MVP 1 restriction, spawn's second argument a direct `fn()` at the call site. No longer holds: §6.6 admits a `let`-bound fn; the tag left 2026-09-19.
L1-100 *Grammar Audit* (l. 159): unqualified top-level names file-local, no `pub`, visibility in the name, principle 3. Held until 2026-09-16; replaced by `export` (L1-21) without being marked superseded.
L1-101 *Backpressure* (l. 242, 246): a spawn-time bound deferred, `Slot(a)` revisited at three uses. The reason for unbounded holds by §10; the trigger is abolished, and the reason for deferring rather than refusing does not hold.
L1-102 *No Registry* (l. 264): a receptionist deferred until three programs. Trigger abolished; holds by argument, §6.5's services answer the need.
L1-103 *Remote Ergonomics* (l. 282, 290): `Task(a)` rejected for now, the stdlib helper deferred on a count. No longer holds either way: `remote` is gone (§6.7).
L1-104 *Tests* (l. 308): the concrete prelude type deferred to MVP 1 Phase 3. Done 2026-09-19 (l. 2700); holds.
L1-105 *Packages* (l. 324): the load path now, content addressing later, no package manager ever. The reason holds for code shipped to a peer (§8.7), not for a library fetched by URL (2026-09-30); the verdict stands unrestated.
L1-106 *Three Layers* (l. 338): output classes introduced when programs demand a message type. Trigger abolished; nothing decides it; §8.2 has `stdout` and `stderr`, no classes.
L1-107 *Ambient Sys, Five Principles* (l. 352, 371): a per-process ambient revisited at three hurt programs, paid for then. Trigger abolished; node-wide stands; the "then" has no date.
L1-108 *`parallelRemote` in the Prelude* (l. 413, 418): the runtime schedules it directly, speed as a reason, revisited if unused. No longer holds: superseded with `remote`, and E.0 rule 1 refuses speed.
L1-109 *`Address.callForever` in the Prelude* (l. 436): revisited if no program reaches for it. Trigger abolished; kept 2026-09-29 by argument.
L1-110 *Against Labeled Function Arguments* (l. 461): revisited at three five-parameter signatures with two bools. Trigger abolished; the verdict stands on principles 2 and 5, and shape rule 9 forbids the bools.
L1-111 *Pipe Operator `|>`* (l. 485) and *Gleam Feature Pass* (l. 2336): `use`, function capture and list spread wait for three programs. Trigger abolished; no rule decides them (family 2).
L1-112 *Bit Arrays in the Report* (l. 493, 510): borrowing flips the cost calculus, MVP 2 at 4 days. Holds for `<<...>>` (§5.11); `bits`, `native` and `unit` have since left.
L1-113 *`Sys.stderr` ... Removed* (l. 525): back when a program needs a distinct stream. Reversed: E.1 has `printError` and `printlnError`; the count never held by E.0.
L1-114 *`Set(a)` Removed* (l. 538): back when a program writes the pattern three times. Reversed the next day.
L1-115 *Against OTP* (l. 555): a `Supervisor.ern` by the three-uses rule, never in the language. The first half happened by E.0 rules, not a count; the second no longer holds, `restarting` is §9.5's.
L1-116 *Section 2 Tightening* item 6 (l. 641): hex revisited if bit-protocol programs demand it, principle 5 against. Reversed: §2.5 has `0x`, `0o`, `0b` and `_`; principle 5 not revisited in this range.
L1-117 *Numeric Semantics* (l. 922): `Int.rem` refused as a rename's cost. No longer holds: E.8 has `Int.rem` (2026-09-29).
L1-118 *`Bytes` and Bitstring Alignment* (l. 950, 960): non-alignment forbidden at no cost, revisited if a program needs it. Holds (§5.11); the trigger is abolished and the shape of the lift stands nowhere.
L1-119 *Reply Timeout Semantics* (l. 973): a hidden auxiliary queue rejected, no program motivating it. Holds by §6.6; the reason is a count.
L1-120 *Third-Round Review Response* (l. 1464): full IEEE with runtime extension rejected on footprint and count. Holds (§3.1 finite); the reason that holds, BEAM's badarith, is family 1's.
L1-121 *Four "Partly Resolved" Tails* (l. 1579): cross-node deadlock detection refused as machinery without a need. Holds: §8.6, detection per node.
L1-122 *Bitstring `bits` Segments* (l. 1851): a `BitString` type rejected for an unstressed use case. Holds; `bits` itself has since left §5.11.
L1-123 *Float Semantics: Minimal Reparation* (l. 1966): `Float.isFinite` waits for a program. Moot: no non-finite value exists (§3.1).
L1-124 *Reply Ownership Extends to Reply-Carrying Types* (l. 2120): constructing `Stop` twice is fine, no program does otherwise. Holds (§6.6); the reason is a count (L1-45).
L1-125 *Deadlock Detection Distinguishes Idle Server* (l. 2238): removing detection rejected, its value disproportionate to its cost. Holds (§8.6, §10).
L1-126 *Bit Operators as Stdlib Functions* (l. 2312, 2316): revisited if unused; a fixed-width Int at three shifts. Triggers abolished; E.8 holds by rule 1; the fixed-width type is decided by nothing.
L1-127 *`Bool.ern` Added* (l. 2289): negation in the stdlib as the low-cost place, on a count. Reversed: `!` in §2.6 and §4.8.
L1-128 *The Erlang Standard Library, Read for Ernest* (l. 2564): `Float.sqrt`, `Sys.args` and `binary` wait for a program. Entered by rules (E.9, E.23, E.20), not the trigger; a `Time` module and `Fs.watch` decided by nothing.
L1-129 *Gleam's Standard Library, Compared* (l. 2579): `Float.looselyEquals` waits for a program comparing floats. Decided since by rule 3's tolerance clause, against; the entry does not say so.
L1-130 *System Modules* (l. 2548): `Tcp.read` and `Tcp.write` may become foreign calls, an echo server deciding on a number. Decided on a measurement to come; E.18 keeps sockets as processes, the reading entry outside this range.
L1-131 *System Modules* (l. 2550): `Seed` a foreign type, no program asking otherwise. Reversed (E.13, L1-72).
L1-132 *`Down`'s `function` Field and the Already-Dead Reason* (l. 2465): the runtime remembers every ended process, a memory cost accepted for principle 1. No longer holds: §6.9 keeps nothing, reason `Unknown`.
L1-133 *The Message Check Moves to the Point of Exposure* (l. 2668): an exposure flag on every receive refused as a third of a hop forever. Holds (§8.4).
L1-134 *Receive Guards Are Guard Expressions* (l. 2664): a buffer and a scan on every `receive` forever refused. Holds (§6.3).
L1-135 *Tuples: `#(...)` Prefix* (l. 682): dropping tuples would add nine named types, a disproportionate cost. Holds (§3.2).
L1-136 *Tried and Rejected* (l. 104): `use Net.Http` outside until it hurts; no date, no trigger. Decided by rule today, §4.2 has no `import`; the entry could say so.

#### Alike cases decided differently

L1-137 *Tests* (l. 300) and *Grammar Audit* (l. 159): a naming convention refused as invisible in the type, and visibility made a naming rule, both on principle 3. Opposite verdicts; `export` settled the second without citing it.
L1-138 *Guards and Bitstring Size Expressions* (l. 1746) and *Receive Guards Are Guard Expressions* (l. 2664): Erlang's guard rule refused, then taken, both with principle 3. The reconciling grammar, no guard can fault, stated in neither.
L1-139 *Float Semantics: Minimal Reparation* (l. 1951) and *Third-Round Review Response* (l. 1463): finite-only Float rejected and taken the same day, both on principle 5. Unreconciled in this range.
L1-140 *`()` → `Void`* (l. 729) and *`Void` → `Unit`* (l. 2380): one name decided both ways by principle 1 in two days, for the C-family reader then for the reader who knows `Never`. The second stands; the reading is unstated.
L1-141 *Against Gleam* (l. 210), *Pipe Operator* (l. 463) and *`export` Keyword* (l. 1090): `|>` and `pub` deliberately absent, then admitted, neither naming what changed. Still unmarked.
L1-142 *Section 2 Tightening* (l. 640, 641): raw strings refused on principle 2, non-decimal literals and separators on principle 5; §2.5 has all three. Admitted outside this range; both principles stand cited against the report.
L1-143 *Ambient Sys* (l. 369) and *Appendix E: Read Back* (l. 2540): `Io.printTo` kept as no variant and principle 2's convenience clause written for it, then removed by rule 4. The clause outlived the pair.
L1-144 *`Bool.ern`* (l. 2289) and *Bit Operators* (l. 2310): negation a function on a count, bit operations functions on principle 5; §4.8 has `!` as an operator and `Int.bitAnd` as a function. Three answers on three grounds.
L1-145 *Bitstrings* (l. 2656), *The Message Check* (l. 2668) and *Receive Guards* (l. 2664): a per-segment check bought, a per-receive check refused as cost forever. Decided by cost each way; no sentence on where a check may cost.
L1-146 *Backpressure* (l. 234): a blocking `send` rejected as invisible in the code; §8.2 and shape rule 8 make eight system writes wait so (2026-09-27, outside this range). The entry is not marked.
L1-147 *Reply Timeout Semantics* (l. 975) and *Guards* (l. 1746): a silent discard taken, a silent swallow refused, both on principle 3. Family 6's sentence would separate them.
L1-148 *Top-Level Initialization Specified* (l. 895): initializers pure on principle 3; §4.6 today lets an initializer spawn, send and call. Reversed 2026-09-26, outside this range; the entry stands unmarked with principle 3.
L1-149 *Third-Round Review Response*, U01 (l. 1497): a pure spawn callback rejected, `with Never` required, on principle 3; §6.2 today lets a pure `f` fit. Reversed 2026-09-26; the entry stands unmarked.
L1-150 *Appendix E: Admission and Shape Rules* (l. 2528) and *System Modules* (l. 2550): pure SplitMix64 for repeatable tests, then `Seed` foreign on rule 1 and a count, the same day; E.13 is SplitMix64 in Ernest. Rule 1 as written says Ernest.
L1-151 *`Down`'s `function` Field and the Already-Dead Reason* (l. 2465): the runtime remembers every ended process's reason, principle 1; §6.9 keeps nothing, answers `Unknown`. A fifth `Reason` answers the surprise; the entry did not weigh it.
L1-152 *Against OTP* (l. 551): no canonical restart policy, principle 5; E.22 has three strategies and §9.5 `restarting`. Marked revisited; principle 5 is not answered in this range.
L1-153 *Numeric Semantics* (l. 922): `Int.mod` kept for the cost of a rename; E.8 has `Int.rem`. The cost argument not revisited at the rename (2026-09-29, outside this range).
L1-154 *`Set(a)` Removed* (l. 527) and *`Set(a)` Restored* (l. 564): removed on a count, restored on principle 1 for the arriving reader. Both superseded; the two grounds decided one case oppositely on consecutive days.
L1-155 *`as`* (l. 206): `as` admitted as a variant of two `let`s and `^x` refused as sugar for `when` in one paragraph; no sentence divides the two kinds of sugar. Still undivided (family 2).
L1-156 *Code Shipping Boundaries* (l. 1889) and *Third-Round Review Response*, U07 (l. 1513): peer-side bindings' per-node result matches, and may differ, the same day. §8.7 says evaluated on the peer on first use; the first stands uncorrected.

### L, part 2: the log from 2026-09-19

#### L2. The log read as a set, `docs/decisions.md` 2704 to the end

#### Families

##### Family A. What a neighbouring language does, cited as principle 1 (23 entries, 19 open)

*Raw Strings, and No Regex Literals*, 09-19, 2724: raw strings in; principle 1, the reader of every language near Ernest; open.
*Integer Literals in Every Common Base*, 09-19, 2776: `0x` in; principle 1, a reader of Rust, Go, Python, Gleam or Elixir; open.
*Digit Separators*, 09-19, 2788: `1_000` in; principle 1, a reader of Rust, Python, Gleam or Java; open.
*Prefix `!`*, 09-20, 2826: `!` in; principle 1, a reader who has `&&`, `||` and `!=`; decided, on Ernest's own operators.
*Two Panes, and One Module for the Terminal*, 09-20, 3252: `Terminal`; principle 1, a reader of `Key`; decided.
*Constructor Names Stay Unique in a Module*, 09-25, 4012: kept; principle 1, a reader of Haskell, Elm and Gleam; open.
*Names Stay Qualified, Without Import or Alias*, 09-25, 4016: kept; principle 1 for the future, and 3; decided on 3.
*Field Selection*, 09-25, 4028: `e.f` in; principle 1, a reader of Gleam, Elm, OCaml, Rust or Haskell; open.
*No Projection From a Tuple*, 09-25, 4032: out; principles 3 and 4, the same neighbours having `t.0`; open under 1.
*A `match` Is an Operand*, 09-25, 4036: in; principle 1, a reader of Rust and Gleam, and 4; decided on 4.
*A Redundant Clause Is an Error*, 09-26, 4086: error; principle 1, five neighbours warn and Elm errors, and 3; decided on 3.
*A `Bool` Does Not Choose a Behaviour*, 09-26, 4098: rule 9; principle 1, what Elm advises and Gleam's libraries do, and 3; decided on 3.
*A Name Follows the Vocabulary*, 09-26, 4220: `intersection`; principle 1, a reader of Erlang's `sets`, Gleam, Haskell and Elixir; open.
*What the Library Lacked*, 09-26, 4228: `lines` drops the last empty; principle 1, a reader of Haskell, Rust and Python; open.
*One Tool, the Job Its First Word*, 09-26, 4238: job first; principle 1, `go build`, `cargo test`, `gleam run`; open, toolchain.
*A Sibling Restarts at Its Next Wait*, 09-27, 4546: at its wait; principle 1, a reader of an OTP `gen_server`; open.
*The `Supervisor`'s Shape*, 09-27, 4556: subtree restart in; principle 1, what a reader from Erlang predicts; open.
*A Program Ends With `Os.exit`*, 09-27, 4542: the page says so; principle 1, a reader from Erlang who knows `exit`; open.
*Back Pressure, Again*, 09-27, 4624: unbounded mailbox; principle 1, what an Erlang programmer expects; open.
*A Result Is Annotated With `:`*, 09-28, 4915: `: T`; principle 1, a reader who knows the rest of Ernest; decided, as written.
*The Library's and the Examples' Cheap Lines*, 09-29, 5085: `.bashrc` without extension; principle 1, the shell tools a reader knows; open.
*`Int.div` and `Int.rem` Are the Library's*, 09-29, 5183: keep `-1`, rename; principle 1, a reader of Haskell, ML or Python expects 2; open.
*A Constructor With Fields Is Matched With Its Parentheses*, 09-29, 5203: `Circle()`; principle 1, the rest of Ernest decides; decided, as written.
*Five Small Rules Kept*, 09-29, 5211: `true` kept; principle 1, readers split on the spelling; open, and says so.
*Sockets Are Read by Pulling*, 09-29, 5249: pull; Erlang's active mode refused on principle 2; decided on 2.
*A Group Restarts Whole*, 09-30, 5393: whole; principle 1, an Erlang reader expects the group whole; open.
*The Release Review's Questions, N-B5*, 09-30, 5491: host's order given up, stated; principle 1, an Erlang reader assumes otherwise; open, against the neighbour.
Proposed for §0, principle 1: "The reader knows Ernest, then the Erlang runtime beneath it and the ML family its types come from. A form is not admitted because another language has it; where Ernest's own rules do not decide, those two sources do, in that order."
L2-1. *Integer Literals in Every Common Base*, 2776: decided by what a reader of Rust, Go, Python, Gleam or Elixir expects; §0's reader knows Ernest and predicts decimal from its lexer. Right verdict, not principle 1's.
L2-2. *Field Selection*, 4028, against *No Projection From a Tuple*, 4032: the neighbours' missing `e.f` admitted on principle 1, their `t.0` refused on 3 and 4 with the same reader unasked; principle 1 consulted once.
L2-3. *`Int.div` and `Int.rem`*, 5183: a Haskell, ML or Python reader expects 2, a C, Java, Rust, Erlang or Ernest `%` reader expects -1; the entry keeps -1 and renames, so principle 1 argued both sides of one verdict.
L2-4. *Five Small Rules Kept*, 5211: the one entry that says readers split and principle 1 does not ask, deciding by the host instead; the other twenty do not say it.
L2-5. *A Sibling Restarts at Its Next Wait*, 4546, and *A Group Restarts Whole*, 5393: supervision's shape is decided throughout by what an OTP `gen_server` or supervisor does; §0 does not say OTP is the reader.

##### Family B. What the host's semantics decide (21 entries, 14 open)

*Deadlock Is Quiescence*, 09-19, 2742: global quiescence, over what the scheduler already knows; no principle, cost.
*No Negative Zero*, 09-19, 2792: IEEE `-0.0` overridden, one addition per operation; principle 1.
*A Time Below 0 Is 0*, 09-24, 3722: `timeout_value` hidden, clamped; the library's count rule.
*The Shell's Reload Ends a Process*, 09-24, 3714: two versions of a module, stated in §6.10 until MVP 3.1; no principle.
*`bits` and `native` Leave the Bit Syntax*, 09-24, 3738: Erlang's bit syntax pared; principle 2, not useful enough.
*A `String` Counts Graphemes*, 09-24, 3742: `string`'s unit stated; no principle.
*The Code Read Back*, 09-25, 3962: the 255-character atom stated in §2.3; every implementation needs one.
*The Report Read Cold, Its Plain Half*, 09-25, 3992: the 2^32-1 ms timer hidden by slicing; no principle.
*A Function May Be Named `module_info`*, 09-26, 4290: reserved names hidden by mangling, the report says nothing; principle 5.
*The Cold Read's Last Findings*, 09-26, 4302: UTF-8 byte order, White_Space and full case mapping stated as the language's; no principle.
*The Build's First Group*, 09-26, 4440: `sigint` cannot be handled, stated in §8.6; no principle.
*The Build's Fourth Group*, 09-26, 4470: the io server's decoding bypassed by a port; no principle.
*A Sibling Restarts at Its Next Wait*, 09-27, 4546: OTP 28 priority messages and no remote raise, §6.9's rule; principle 1.
*Back Pressure, Again*, 09-27, 4624: selective receive, §10's unbounded mailbox; principle 1.
*Running as a Service*, 09-27, 4638: `SIGPIPE` ends the run, §8.2; no principle.
*Atoms, Counted*, 09-27, 4648: the atom table, `Erl.atom` carries the host's promise; no principle.
*A `receive` Guard Reads a Top-Level `let`*, 09-29, 5147: guard built-ins half lifted, calls still refused; no principle.
*A Pattern's Size Reads a Top-Level `let`*, 09-29, 5179: binary matching, one limit lifted and one kept; principles 1 and 2.
*Five Small Rules Kept*, 09-29, 5211: `true` and `false` terms, reserved words kept; principle 5.
*Char Reads the Host's Tables*, 09-30, 5293: `unicode_util`, hidden; the Unicode version is the host's; no principle.
*Scheduling Hints Are the Host's*, 09-30, 5333: priorities refused by §10; principle 3.
*`Other` Says the Host's Words*, 09-30, 5385: `format_error`, the host's English in `Other`; rule 3.
*The Release Review's Questions, N-B5*, 5491: `DOWN` order given up, stated; no principle.
Proposed for §10, which the Principles Review, 5541, asks for: "A rule of the host is a rule of Ernest only by a sentence of this report, stated as Ernest's own. Where the report is silent, the runtime carries the host's rule without letting it show; where it cannot, the program is refused with an error that names the limit as the host's."
L2-6. *The Code Read Back*, 3962, against *Five Small Rules Kept*, 5211: a limit is the language's when every implementation needs one, yet a host without it would lift it; one only this host needs is stated as Ernest's.
L2-7. *A Function May Be Named `module_info`*, 4290: the host's reserved names hidden on principle 5, its name length stated (L2-6), its timer limit hidden by slicing (3992); no sentence says which a host limit becomes.
L2-8. *A Pattern's Size Reads a Top-Level `let`*, 5179: both limits were Erlang's binary matching showing through; one lifted by reading a value first, one kept since `receive` cannot; principle 2 would keep or lift both.
L2-9. *Char Reads the Host's Tables*, 5293: the Unicode version of the language is the host's, and the report says so nowhere.
L2-10. *`Other` Says the Host's Words*, 5385: the host's wording, in English, becomes what a program prints; rule 3 refused a locale in *What the Library Lacked*, 4228, and is not cited here.
L2-11. *No Negative Zero*, 2792, against *A `receive` Guard Reads a Top-Level `let`*, 5147: floats overridden at an addition an operation, guards kept for the host's receive; §0 does not say which price buys a rule.

##### Family C. What the standard library admits (E.0) (27 entries, 9 open)

*MVP 2.7, the Fetcher, and No Server*, 09-19, 2730: an HTTP server a library; policy over `Tcp`; decided.
*`Bytes` Has a Module*, 09-20, 2808: in; rule 2, program or none; decided.
*Nothing Waits for a Program*, 09-20, 2812: many in and out; rules 3 and 4 rewritten; decided.
*`Float`'s Boundary*, 09-20, 2818: E.9's boundary sentence; rule 5; decided.
*Shims Where the Runtime Owns the Representation*, 09-20, 2838: shim; rule 1, `List.sort` on 75 against 110 ms; open, reversed.
*`Foreign` in Ernest, and `Foreign.from`*, 09-20, 2846: in; rule 3; decided.
*`Random` in Ernest*, 09-20, 2850: shim; rule 1; open, reversed at 4212.
*The Corpus Decisions, Re-judged*, 09-20, 2864: verdicts; rules 3 and 4, 2 and 5; decided.
*`Ets` in the Standard Library*, 09-20, 2914: in; as fundamental as `Map`; open, reversed at 3692.
*One Event, and the Page Keys Go*, 09-21, 3388: page keys out; what a program has needed; open, a count.
*Ets Is a Library*, 09-24, 3692: out; rule 1 and §10; decided.
*Libraries As They Are Wanted*, 09-25, 4078: libraries wait; the tier rule; decided.
*A `Supervisor` in the Standard Library, and `fault`*, 09-26, 4156: in; rule 3 gains a sentence; decided by the new sentence.
*The Live Processes Are a Library Function*, 09-26, 4172: in; rules 1 and 3; decided.
*A Shim Reaches the Representation*, 09-26, 4212: primitives; rule 1 corrected; decided.
*What the Library Lacked*, 09-26, 4228: in and out; rules 3 and 4, and rarely wanted as principle 5; one open.
*`trim` Is a Named Pair*, 09-26, 4324: kept; rule 4's list; decided.
*The Web Server Waits for Its Library*, 09-26, 4412: a library; a published protocol; decided.
*The Terminal Writes Its Own Sequences*, 09-26, 4420: ECMA-48 into E.16; rule 3, and `libs/` off the load path; open.
*The Build's Sixth Group*, 09-26, 4498: `String.graphemes`; rule 1, quadratic; open.
*The Working Directory*, 09-28, 4726: `absname` and `expand` out; rule 4 and principle 1; decided.
*`Fs.makePrivate`*, 09-28, 5002: in; rules 1 and 4; decided.
*What `Fs` Holds*, 09-28, 5006: in and out; rules 1, 3 and 4, and few programs need as principle 5; one open.
*What MVP 2.95 Takes From the Rest*, 09-28, 5024: `intersperse` out; rule 4; decided.
*`Bytes` Gains `String`'s Text Functions*, 09-29, 5241: Ernest over `slice`; rule 1, performance no reason; decided.
*The Supervisor's Restart on Request Stays Its Own*, 09-29, 5161: `Process.restart` out; rule 1, a need nobody has shown; open, a count.
*`Clock.monotonic` Is In, and `Udp` Is Placed*, 09-30, 5301: `Udp` waits; rules 1, 3 and 4, and someone asking; open, a count.
*`Other` Says the Host's Words*, 09-30, 5385: the host's words; rule 3; open, L2-10.
*The Release Review's Wrong Results*, 09-30, 5459: `String.drop` a primitive; rule 1, over those numbers; open.
*The Release Review's Questions, R-6*, 5491: vocabulary wins; rule 4 against rule 2; decided by the new sentence.
Proposed for E.0 rule 1: "A primitive beneath an operation Ernest can write over the module's other primitives is admitted only by a measurement, recorded in the decisions log, that the Ernest form costs more than a multiple of the host's own; the operation stays Ernest over it, and the primitive is private where the operation is the module's word."
Proposed for the preamble: no new sentence; `Udp` is written or the sentence "None of them counts programs" is false.
L2-12. *The Release Review's Wrong Results*, 5459: self-refuting; rule 1 says speed is no reason for a shim, and `drop` is computable over `slice`, which rule 1's test refuses. Maybe right; no report sentence makes it.
L2-13. *Shims Where the Runtime Owns the Representation*, 2838: `List.sort` a shim on 75 against 110 ms, reversed by rule 1's later text; with L2-12 and 4498, speed decided three primitives, two after the rule forbade it.
L2-14. *`Clock.monotonic` Is In, and `Udp` Is Placed*, 5301: `Udp` admitted by rule 1 waits for someone asking; E.0's preamble admits by rule, program or none, so a module is gated on the count 2812 removed.
L2-15. *The Supervisor's Restart on Request Stays Its Own*, 5161: `Process.restart` refused for a need nobody has shown, a count, where the design reason, misuse of authority on principle 3 (5369), would decide.
L2-16. *One Event, and the Page Keys Go*, 3388: a library type's constructors decided by need, back the day a program wants them, against rule 2's vocabulary admitted whole; E.16's `Event` has no membership sentence.
L2-17. *The Terminal Writes Its Own Sequences*, 4420: ECMA-48 goes to E.16 on rule 3 while HTTP (4412) and CommonMark (3938, 3946) go to libraries as a specification's work; one reason is the load path, a toolchain fact.
L2-18. *What the Library Lacked*, 4228, and *What `Fs` Holds*, 5006: rarely wanted and few programs need are each named principle 5; principle 5 counts concepts, not callers, so a count is named by a principle's number.

##### Family D. What is refused when compiled and what is silent or faults when run (16 entries, 5 open)

*A Statement Is Unit*, 09-24, 3686: a value dropped is a compile error; principles 3 and 2, no warnings.
*The Report Read Cold, Its Plain Half*, 09-25, 3992: a meaningless specifier, a float literal and the entry point's shape are compile errors; no principle.
*The Cold Read's Smaller Rules*, 09-25, 4060: `..` on many constructors and a local `fn` beside a variable are compile errors; principle 3.
*A Redundant Clause Is an Error*, 09-26, 4086: a dead clause is a compile error; principles 3 and 5.
*A Foreign Type States the Equality It Needs*, 09-26, 4090: `k=` on an ordinary type refused; principle 2.
*No Control Character Reaches the Terminal Unasked*, 09-28, 4984: a control character in source is a compile error; no principle.
*A `///` After Code Is an Error*, 09-28, 5040: a doc comment after code is a compile error; principles 1 and 2.
*The Report's Silences*, 09-29, 5111: `<<-1>>` faults, though the compiler could see it; no principle.
*`Prelude.` Only Where a Name Is Hidden*, 09-29, 5195: a needless qualifier is a compile error; principle 2.
*A Block Binding's Open Variable Stays Free*, 09-29, 5199: an unused binding is silent; principles 1 and 5, no warnings.
*A Constructor With Fields Is Matched With Its Parentheses*, 09-29, 5203: a bare `Circle` is a compile error; principles 2, 1, 5 and 3.
*The Security Reader's Decisions*, 09-29, 5245: `foreign fn cast(x : Foreign) : a` faults whenever it returns; no principle.
*The Release Review's Questions, R-13*, 5491: `<<-1>>` is a compile error; principle 1.
*The Release Review's Questions, R-22*, 5491: `let f = fn` beside `fn f`, both stay; principle 2 read narrowly.
*The Release Review's Questions, R-26*, 5491: a local helper over an operator refused; principle 1.
*The Release Review's Questions, N-C3*, 5491: `type Word = String` accepted, with a help line; principle 2.
Proposed for §0, principle 3, or §11.1: "The compiler refuses a program whose text alone shows a statement, a clause or a declaration that can have no effect, a value dropped, a clause that cannot run, a result no value can be. What the text shows only unused it accepts without a word; there is no warning."
L2-19. *A Block Binding's Open Variable Stays Free*, 5199, and *A Redundant Clause Is an Error*, 4086: both text with no effect, one refused on 3, one silent on 5; the splitting rule, no warnings, stands only in the log.
L2-20. *The Report's Silences*, 5111, against R-13, 5491: `<<-1>>` stays a fault at construction on the 29th, a compile-time error on principle 1 on the 30th; the same case, two verdicts, one day.
L2-21. *The Security Reader's Decisions*, 5245: a declaration the compiler can see is wrong for any returning function is accepted and faults at run time, where 3992 refuses a meaningless specifier at compile time.

##### Family E. What waits and what answers at once, E.0 rule 8 (18 entries, 5 open)

*`Clock` in Ernest*, 09-20, 2872: `now` a call, alarms a send; rule 8.
*A Test Waits for the Screen*, 09-20, 3310: `subscribe` a call answered once the mode is set; no principle.
*An Alarm Carries the Time It Fired*, 09-24, 3790: rule 8 unchanged; no principle.
*A Time Below 0 Is 0*, 09-24, 3722: clamp; the library's count rule.
*Three Failures Principle 3 Answers For*, 09-24, 3746: `Tcp.write` `Unit`, at a round trip a write; principle 3; reversed.
*A Stream Keeps Its Own Time Limit*, 09-26, 4186: milliseconds travel in the request; no principle.
*A Listener Says Its Port*, 09-26, 4202: answered at once, no milliseconds; rule 8.
*A Subscription Says Whether It Has Keys*, 09-26, 4206: `Left(NotATerminal)` at once; principle 3.
*Standard Input and Output Carry Bytes*, 09-26, 4428: `read` and `readLine` take none, since both wait for input; rule 1.
*Every Fault Is Delivered to Whoever Subscribes*, 09-26, 4180: delivers later; rule 8.
*What Building `Os` Found*, 09-27, 4678: a write after `closeInput` dropped; no principle; reversed.
*A Running Program Is a Process*, 09-27, 4608: one time bounds the life; principle 1 and rule 4.
*Back Pressure, Again*, 09-27, 4624: every write waits for its stream; principle 1.
*What `Fs` Holds*, 09-28, 5006: `removeAll` waits per step; no principle; reversed.
*A Write to a Socket or a Program Answers*, 09-29, 5175: `Either`; `Io.print` stays `Unit`; principles 3 and 1, rule 4.
*Sockets Are Read by Pulling*, 09-29, 5249: `Tcp.read` takes milliseconds, waits on the world; principle 2 and rule 8.
*`Address.callForever` Stays Beside `Address.call`*, 09-29, 5187: kept; two properties.
*The Release Review's Questions, R-25 and C1-3*, 5491: `Os.start`'s time is the life, `removeAll` waits once; rule 8 read three ways.
Proposed for E.0 rule 8: "A stream of the program's own, standard input, standard output, standard error and the terminal, is waited on without a limit, and its failure ends the program (§8.2, §8.6). Anything another party holds, a file, a socket, a peer or a program the runtime started, is waited on for the milliseconds given, which bound the one request, and its failure is a value. A refusal is answered at once, as a value."
L2-22. *Standard Input and Output Carry Bytes*, 4428, and *Sockets Are Read by Pulling*, 5249: no milliseconds as input waits, milliseconds as a peer may never answer; a pipe may not either; rule 8 lists, not reasons.
L2-23. *A Write to a Socket or a Program Answers*, 5175: `Io.print` stays `Unit` since its streams are the program's own and a far end or a child's input is another's; the deciding sentence is only in the log, not rule 8.
L2-24. *A Subscription Says Whether It Has Keys*, 4206: `Terminal.size` answers `None`, `Terminal.subscribe` `Left(NotATerminal)`, for one fact, not a terminal; a partial `None` and a cause's `Left`, rule 4 read both ways.
L2-25. R-25, 5491: a time per read weighed and left on the release's eve; with C1-3's `removeAll` waiting once and `Fs`'s per-call time, the milliseconds bound a call, an operation or a life, rule 8 saying which by name only.

##### Family F. Member or module function (12 entries, 6 open)

*Abstract-Type Ownership*, 09-19, 2754: members only, §4.4 as written; no principle; reversed.
*A Built-in Type's Operators in Its Module*, 09-19, 2770: operators members, `fn Float.abs` refused for one spelling, `fn abs`; the rule users already know.
*What Makes a Type the Prelude's*, 09-24, 3750: a type is the prelude's where the module is named after it; principle 5.
*An Abstract Type's Boundary Is Its Module*, 09-25, 3982: members need not be members; principles 1, 2, 4 and 5.
*Field Selection*, 09-25, 4028: `e.f` found as an operand type is; principle 1.
*The Cold Read's Smaller Rules*, 09-25, 4060: a member's shape, an operator, `compare` and `negate`; no principle.
*Everything About a Process in Its Module*, 09-26, 4320: `Process` a foreign type of `process.ern`; principles 1 and 5; reversed at 4394.
*The Pages Line*, 09-29, 5089: `compare` written with `<` names the runtime's operation; §9.6's sentence.
*The Contract's Decision After the First Release*, 09-29, 5101: one rule for a type's operations only with the decision; undecided by its own words.
*A Member Is Written `T.name`*, 09-29, 5139: the unqualified member step removed, operator shims left; principles 1 and 2.
*`Int.div` and `Int.rem` Are the Library's*, 09-29, 5183: from the prelude to E.8, no program changes for the move; principles 2 and 1.
*A Prelude Type Without Members Takes No Namespace*, 09-29, 5191: the first segment is a type only where it has that member; principles 1 and 5.
*The Release Review's Questions, R-3 and R-27*, 5491: `T.name` the member where `T` declares one, operators become shims; principles 1 and 2.
Proposed for §4.5 and §4.8: "A type's operations are functions of the module named after it. A member, `fn T.name`, is declared only for what the language resolves by the operand's type, an operator, `compare` and `negate`, and for a field; nothing else is a member, and a module reaches an abstract type's constructors by being its module, not by membership."
L2-26. *The Contract's Decision After the First Release*, 5101: the guide states one rule for a type's operations, members or module functions, only with the decision (U8); the log states the family is undecided.
L2-27. *`Int.div` and `Int.rem` Are the Library's*, 5183: a member and a module function of a type's module are one spelling at every call, so principle 2 cannot tell them apart; only constructor visibility and §8.7's hash do.
L2-28. *A Built-in Type's Operators in Its Module*, 2770, *A Member Is Written `T.name`*, 5139, R-27, 5491: operators shims, then members with an inline body, then left, then shims again; four verdicts, 1 and 2 on both sides.

##### Family G. A failure's shape: fault, value, clamp, refusal, and whom a fault lands on (19 entries, 6 open)

*`Keys`, and Who Owns the Terminal*, 09-20, 2900: a double claim faults the entry process; no principle.
*A Fault Is a Death With `Fault`*, 09-24, 3700: a deadlock is the entry process's fault; principle 5.
*`remote` Catches Nothing*, 09-24, 3706: a fault on a peer faults the caller; principle 2.
*A Time Below 0 Is 0*, 09-24, 3722: a negative time is 0; the count rule.
*Three Failures Principle 3 Answers For*, 09-24, 3746: a remote send faults after return, `Tcp.write` answers `Unit`; principle 3; both reversed.
*`Float.pow` Is Partial in Its Type*, 09-24, 3754: a domain gap answers `None`, an overflow faults; rule 4.
*A Call Ends When Its Callee Faults*, 09-26, 4114: the callee dies, `None` or the caller faults; principle 3.
*The Cold Read's Last Findings*, 09-26, 4302: `kill` on a system process faults the caller; no principle.
*A Socket Lives Until It Is Closed*, 09-26, 4362: a read after the own close faults, after the far close `Left(Closed)`; principle 3.
*The Report Pass of Step 10*, 09-26, 4378: a line not UTF-8 faults the reader; no principle.
*The Build's Fourth Group*, 09-26, 4470: keys not UTF-8 fault the entry process; no principle.
*A Program Ends With `Os.exit`*, 09-27, 4542: a status outside 0 to 255 faults; no principle.
*`Tcp.listen` Names Its Interface*, 09-28, 4972: a port outside 0 to 65535 answers `Left(Other(...))`; no principle.
*What `Fs` Holds*, 09-28, 5006: `readLink` of a non-link answers `Right(None)`, a question and not a failure; rule 4.
*The Report's Cheap Lines*, 09-29, 5052: `Int.toFloat` beyond range faults, only an integer above 10^308; rule 4's exception.
*A Claim of the Terminal the Other Way Faults Its Caller*, 09-29, 5171: a double claim faults the caller; principles 3 and 1.
*A Write to a Socket or a Program Answers*, 09-29, 5175: the far end gone answers `Left(Closed)`, faulting the writer weighed and left; principles 3 and 1.
*`Int.div` and `Int.rem` Are the Library's*, 09-29, 5183: a zero divisor answers `None` beside `/`'s fault; principle 2.
*No Limit Is `Unlimited`*, 09-30, 5377: `within` below 1 is 1; principle 2.
*The Release Review's Security Lines*, 09-30, 5429: a host with U+0000 answers `Left(Other(...))`; no principle.
Proposed for §7.4: "A refused request faults the process that made it; a failure no request stands behind faults the entry process."
Proposed for E.0 shape rule 4: "An argument outside the range its type admits answers `None`, or `Left` where the cause is the host's; a time or a count below its floor is that floor, which the function's section names; only an operation that cannot return faults on such an argument."
L2-29. *A Program Ends With `Os.exit`*, 4542, *`Tcp.listen` Names Its Interface*, 4972, and E.20's `Bytes.fromList`: an `Int` outside its range is a fault, a cause or `None`; rule 4 has all three and no rule for which.
L2-30. *A Time Below 0 Is 0*, 3722, against *No Limit Is `Unlimited`*, 5377: one quantity, two floors, 0 and 1; the second made necessary by the meaning 0 was given at 4998 and then taken away.
L2-31. *`Keys`, and Who Owns the Terminal*, 2900, against *A Claim of the Terminal the Other Way*, 5171: the second states the rule, a refused request faults its asker, else the entry process; §7.4 lists cases only.
L2-32. *The Report's Cheap Lines*, 5052: a likelihood, only an integer above 10^308, decides between shape rule 4's `Optional` and a fault; *`Float.pow` Is Partial*, 3754, gave `None` to a gap as rare.

##### Family H. What is the prelude's (14 entries, 4 open)

*The Test Type and the Standard Library's Layout*, 09-19, 2708: `Test` in the prelude, as that entry sketched it; no principle.
*What Makes a Type the Prelude's*, 09-24, 3750: three criteria; principle 5.
*One Primitive for Remote Computation*, 09-24, 3730: `parallelRemote` out; principle 2.
*A Supervisor in the Standard Library, and `fault`*, 09-26, 4156: `fault` in, principle 5 pays one function; principle 5.
*A Process Is Watched From Its Start*, 09-26, 4276: `spawnMonitored` in; principles 3 and 5.
*The System References Live in Their Modules*, 09-26, 4308: eight types and seven values out; principles 5 and 2.
*One Way to Fault*, 09-26, 4312: `todo` out; principles 2 and 1.
*What the Ledger Found*, 09-26, 4344: the third criterion dropped; no principle.
*The Error of Input and Output*, 09-26, 4370: `Io.Error`, no third criterion; principle 5 and rule 7.
*The Report Read Cold After the Pass*, 09-26, 4394: `Process` the prelude's by the second criterion; rule 7.
*No Remote Computation in the Language*, 09-27, 4526: `remote` out; principles 3, 2 and 5.
*`Int.div` and `Int.rem` Are the Library's*, 09-29, 5183: out, to where a pair is allowed; principle 2.
*`Address.callForever` Stays Beside `Address.call`*, 09-29, 5187: kept; two properties.
*Five Small Rules Kept*, 09-29, 5211: `Path` stays; principle 1.
Proposed for §9: "The prelude holds a function only where a rule of this report names it, or where no function written over the prelude could keep the rule's promise; anything else, however common, is the standard library's."
L2-33. *A Process Is Watched From Its Start*, 4276, and *`Address.callForever` Stays*, 5187, against 3730, 5183: a composition and a variant stay in the prelude, another pair go on 2; §0 never says a race or deadlock keeps one.
L2-34. *`Int.div` and `Int.rem` Are the Library's*, 5183: the prelude line is used as the lever that makes a pair legal in the standard library; §9 has no sentence saying what the line holds, so the lever moves.

##### Family I. The reply discipline and the inferred restrictions (11 entries, 2 open)

*Reply-Carrying Lambdas*, 09-19, 2746: a lambda consumed once, the function type not taken since no program has asked; a count.
*No Not-Reply-Carrying Mark on a Container Element*, 09-19, 2762: no mark on `Optional(a)` elements; principle 1.
*A Statement Is Unit*, 09-24, 3686: §6.6's statement rule subsumed; principles 3 and 2.
*Not-Reply-Carrying by What the Body Does*, 09-25, 4040: by the body; §6.6.
*A Foreign Type States the Equality It Needs*, 09-26, 4090: `k=` on the type; principles 3, 2 and 5.
*What the Ledger Found, L1*, 09-26, 4344: `restarting`'s function refused; §6.6.
*The Closing of Step 10, item 60*, 09-26, 4510: a path through `fault` consumes; principles 1 and 5.
*`==` on a Value That Holds a Function*, 09-29, 5105: fields read; §3.10.
*What a Foreign Function's Variables Carry*, 09-29, 5121: not reply-carrying, `Foreign` loses `==`; no principle.
*`Optional` and `Either` Hold a Reply*, 09-29, 5143: hold; `List`, `Map` and `Set` keep the ban; principles 1 and 2.
*The Release Review's Questions, R-21 and R-23*, 5491: two equality rules stay, marks not writable yet; no principle; time.
Proposed for §6.6: "§6.6 names no type. A reply stands wherever §3.9's inference shows it consumed exactly once; a type whose operations are the runtime's holds none by that inference, since its functions' variables carry the restriction (§3.9)."
L2-35. *`Optional` and `Either` Hold a Reply*, 5143: `List`, `Map` and `Set` keep the ban; `List` needs no equality, `withDefault` drops as `filter` does, a user's `Cons(a)` holds a reply, and 5121 makes the ban needless.
L2-36. *Reply-Carrying Lambdas*, 2746: no program has asked is the count rule abolished at 2864, and the entry is not marked superseded; the design half, a `FnOnce` restriction, holds and should carry it alone.

##### Family J. Who owns a process or a resource (8 entries, 3 open)

*A Restart Has a Limit and No Strategy*, 09-26, 4124: processes spawned before a fault run on, since nothing owns a process (§6.9); no principle.
*One Subscription to the Terminal a Process*, 09-26, 4294: a subscription ends with its process; no principle.
*A Socket Lives Until It Is Closed*, 09-26, 4362: a leaked socket is the program's defect, never the runtime's; principle 3 and the memory rule.
*The `Supervisor`'s Shape*, 09-27, 4556: a watcher kills the children on the supervisor's `Down`; no principle.
*What Building `Os` Found*, 09-27, 4678: a program is killed with the process that started it; no principle.
*What the Loads Found*, 09-27, 4662: a dead waiter's monitor waits are dropped; the memory rule.
*A Check at the Boundary Lasts as Long as Its Process*, 09-30, 5323: the proxy lives with its process; principle 3.
*A Restart Begins Afresh*, 09-30, 5407: what it spawned, opened or put in a table lives on; principles 1 and 3.
*The Release Review's Questions, C1-2*, 5491: a socket has an owner and dies with it; the memory rule.
Proposed for §6.9: "A process the program spawns belongs to no one and ends only as this section says. A process the runtime starts for a resource, a socket or a program, belongs to the process that opened it or was given it, and ends with it."
L2-37. *A Socket Lives Until It Is Closed*, 4362, against C1-2, 5491: growth the program causes, never the runtime's, then a socket kept until the program ended, one a fault; the memory rule cited both ways, four days apart.
L2-38. *A Restart Has a Limit and No Strategy*, 4124, against E.18 and E.23 after C1-2 and 4678: a spawned process belongs to no one, a socket or a program to its opener, children to a watcher; no sentence says which is owned.

##### Family K. Input the host gives that is not UTF-8 (9 entries, 3 open)

*The Cold Read's Last Findings*, 09-26, 4302: a line, the reader's fault.
*The Report Pass of Step 10*, 09-26, 4378: a line faults the process that asked.
*The Build's Fourth Group*, 09-26, 4470: a key faults the entry process.
*A Program's Command Line Is `Os`'s*, 09-27, 4536: an argument refuses the run, a variable is left out; principle 1.
*The Environment Read Through the Helper*, 09-27, 4612: a directory entry is left out.
*`Os.run` Runs Through a Helper in C*, 09-27, 4598: U+0000 in a name, `run` says so.
*The Working Directory*, 09-28, 4726: the directory refused before the host starts.
*The Release Review's Security Lines*, 09-30, 5429: a `Tcp` host with U+0000 answers `Left(Other(...))`.
*The Release Review's Crashes*, 09-30, 5437: a source, an error at the first bad byte.
Proposed for §8.2: "Text the host gives a program is UTF-8 or is refused where the program asked for it: an argument or the working directory before the program runs, a line or a key by a fault of the process that asked, a path or a host by `Left(Other(...))`. What the program did not ask for by name, a variable of the environment or an entry of a directory, is left out."
L2-39. *A Program's Command Line Is `Os`'s*, 4536: an argument refuses the run as given to this program, a variable is left out (1); a line of input faults a process, a listed entry is left out; five outcomes, one argued.

##### Family L. Where an adapting function runs (4 entries, decided)

*`via` Is a Value*, 09-20, 3041: a faulting wrap in a proxy vanished and nobody was told; principle 3; decided.
*The Cold Read's Last Findings*, 09-26, 4302: a wrap applied by the delivery, in a process of its own; principle 3; decided.
*A Process's Addresses, Taught in Order*, 09-28, 5034: P11 reconciled, `via` in the sender, a wrap in the runtime's process; principle 3; decided.
*The Release Review's Questions, R-24*, 5491: kept; principle 3, §6.5 states it; decided.

##### Family M. Names and scope (11 entries, decided; one wavered)

*Constructor Names Stay Unique*, 09-25, 4012: decided; §4.2's order and principle 3's last sentence.
*Names Stay Qualified*, 09-25, 4016: decided; §4.2's order and principle 3's last sentence.
*`Prelude` Names the Prelude*, 3710, widened at 5111 and R-3, 5491: decided; §4.2's order and principle 3's last sentence; wavered, L2-40.
*`Prelude.` Only Where a Name Is Hidden*, 09-29, 5195: decided; §4.2's order and principle 3's last sentence.
*The Closing of Step 10*, feedback 59, 09-26, 4510: decided; §4.2's order and principle 3's last sentence.
*A Prelude Type Without Members Takes No Namespace*, 09-29, 5191: decided; §4.2's order and principle 3's last sentence.
*A Namespace From Words Joined by `_`*, 5127: decided; §4.2's order and principle 3's last sentence.
*A Later Input May Add a Member*, 4020: decided; §4.2's order and principle 3's last sentence.
*Two Visibilities Are Enough*, 4024: decided; §4.2's order and principle 3's last sentence.
*A File Beside the Prompt*, 3225: decided; §4.2's order and principle 3's last sentence.
*An Abstract Type's Boundary Is Its Module*, 09-25, 3982: decided; §4.2's order and principle 3's last sentence.
L2-40. *`Prelude` Names the Prelude*, 3710, 5111, R-3 at 5491: principle 2 refused `Prelude.Io.println` as a second way, then allowed the segment wherever a name is hidden, no second way there; settled on the third reading.

##### Family N. Documentation's shape, E.0 rule 6 (6 entries, decided)

*Bool's Read-Back*, 2704: principle 2; decided by rule 6 as amended.
*Documentation Before the Standard Library*, 2750: principle 2; decided by rule 6 as amended.
*Rule 6 Matched to the Agreed Template*, 2796: principle 2; decided by rule 6 as amended.
*`List` in Ernest*, 2804: principle 2; decided by rule 6 as amended.
*`Clock` in Ernest*, 09-20, 2872: principle 2; decided by rule 6 as amended.
*The Prelude Documented*, 3864: principle 2; decided by rule 6 as amended.
Rule 6 changed four times in ten days by principle 2.

#### Decided on cost, on time, or for now

L2-41. *Deadlock Is Quiescence*, 09-19, 2742: partial deadlock reserved as hard and expensive. Holds as cost; but 4710 calls a `callForever` cycle Ernest's own, the runtime keeps calls in flight, and the cost is unmeasured.
L2-42. *Reply-Carrying Lambdas*, 09-19, 2746: no program has asked. The count rule is abolished at 2864 and the entry is not marked; the design reason holds (L2-36).
L2-43. *`Io.debug`, and String Interpolation Considered*, 09-19, 2758: waits for the corpus. No longer holds; *Later*, 5587, re-argues it on principles 2, 3 and 4, and the entry is unmarked.
L2-44. *A Built-in Type's Operators in Its Module*, 09-19, 2770: floats inlined to spare a foreign call's check and counter. No longer holds: library calls uncounted (5253), unchecked (5271); R-27 makes them foreign.
L2-45. *Integer Literals in Every Common Base*, 09-19, 2776: digit separators stay out for now. Lifted the same day at 2788.
L2-46. *Shims Where the Runtime Owns the Representation*, 09-20, 2838: `List.sort` a shim on 75 ms against 110. Reversed by rule 1's own text; the reason is refused by the rule.
L2-47. *`Tcp`, Measured, and the Refusals Gone*, 09-20, 2906: 35 microseconds a round trip, 1.8 times raw, the processes kept. Holds; re-measured at 5253.
L2-48. *`Ets` in the Standard Library*, 09-20, 2914: in because Appendix D writes it out and `webserver` assumes it. Convenience; reversed at 3692 on rule 1 and §10.
L2-49. *The Terminal Reads Keys Again*, 09-20, 3015: an escape alone fifty milliseconds is `Escape`, a burst constant; §8.2 says once no sequence can follow, the fifty is the runtime's. Holds on one machine, not a slow link.
L2-50. *`via` Is a Value*, 09-20, 3041: ten processes a second per tick, and principle 3. Holds.
L2-51. *One Event, and the Page Keys Go*, 09-21, 3388: they come back the day a program wants them. A count gate on E.16's type; does not hold under the rules (L2-16).
L2-52. *The Terminal Module, and `io_ansi` Measured Again*, 09-20, 3340: a wake-up every 200 ms in one system process buys a rule with no callback. Reversed by *No OTP in the Toolchain*, 4000, the rule read past its reason.
L2-53. *Three Failures Principle 3 Answers For*, 09-24, 3746: `Tcp.write` returns `Unit`, refusing a round trip a write. No longer holds; every write is a round trip since 4624 and answers `Either` since 5175.
L2-54. *`with` Keeps Its Two Uses*, 09-24, 3786: reopened by a position where the two could meet. Moot; 3982 removed the second use the next day.
L2-55. *The Closing Sweep of the Shell*, 09-24, 3902: generalizing the prompt's `let` refused as a second meaning of `let`. Overtaken by 5151, which generalizes every block `let` of a lambda, the prompt's among them.
L2-56. *Libraries As They Are Wanted*, 09-25, 4078: the language is still moving. Holds while it moves; 5301 put `Udp`, a module of Appendix E, under it (L2-14).
L2-57. *A Process Is Watched From Its Start*, 09-26, 4276: about 150 bytes a request. Memory decided `Unknown` and `spawnMonitored`; holds.
L2-58. *A Supervisor Is Told by Its Own Children*, 09-26, 4336: a cost that grows with supervisors times faults. Holds.
L2-59. *A Socket Lives Until It Is Closed*, 09-26, 4362: a socket never closed keeps its process until the program ends, growth the program causes. Reversed by C1-2 (L2-37).
L2-60. *The Web Server Waits for Its Library*, 09-26, 4412: waits for a library for HTTP under `libs/`, MVP 3.2. Holds.
L2-61. *The Shell's Reload Ends a Process*, 09-24, 3714: the limit is the BEAM's, content addressing lifts it in MVP 3.1. Holds until 3.1; §6.10 carries a host limit meanwhile (Family B).
L2-62. *What Building `Os` Found*, 09-27, 4678: faulting the writer would need a reply on every write, which a send lacks. No longer holds; writes are calls (4624) and answer `Either` (5175).
L2-63. *Back Pressure, Again*, 09-27, 4624: a round trip a write, on work that is I/O already. Holds; the 09-24 cost argument against it (L2-53) was dropped without a word.
L2-64. *Atoms, Counted*, 09-27, 4648: the lexer's atoms kept; changed by a shell fed text a program generates. Holds.
L2-65. *What the Loads Found*, 09-27, 4662: the deadlock poll every hundred milliseconds, since nothing else will do. Holds.
L2-66. *What `Fs` Holds*, 09-28, 5006: `removeAll` waited a step for want of `Clock.monotonic`. Lapsed: `Clock.monotonic` is in (5301), `removeAll` waits once (C1-3); hard links out as few need them, a count (L2-18).
L2-67. *The Report's Cheap Lines*, 09-29, 5052: `Int.toFloat` faults because only an integer above 10^308 meets the case. A likelihood; holds as rule 4's named exception (L2-32).
L2-68. *`Io.show` Follows Its Type*, 09-29, 5135, and R-1, 5491: holding the release for it was weighed and left. The leak is stated in §4.4 until MVP 2.99b's item 13; holds, with a report sentence to be removed.
L2-69. *The Supervisor's Restart on Request Stays Its Own*, 09-29, 5161: a need nobody has shown. A count; does not hold under the rules (L2-15).
L2-70. *`Bytes` Gains `String`'s Text Functions*, 09-29, 5241: performance is no reason for a shim. Holds, and is the rule L2-12 breaks the next day.
L2-71. *What Ernest Adds to a Host Call*, 09-29, 5253: the deadlock count skipped for the library's mailbox-less functions on 118 ns, held by a reading of the code; §8.6 names no such source. Holds as cost, not as a rule.
L2-72. *The Runtime's Own Is Not Checked*, 09-30, 5271: `Map.get` from 63 ns to 24, against Erlang's 19. Holds; §8.4 states it.
L2-73. *A Value Is Checked Where It Crosses*, 09-30, 5275: 6% of a call with a one-string reply and 190% of one answering 1,000 strings. Holds.
L2-74. *Supervision Stays in the Reaper*, 09-30, 5285: the round trip at a spawn is the supervision itself. Holds.
L2-75. *Char Reads the Host's Tables*, 09-30, 5293: nothing to write from, and a host release could change the module unannounced. A hidden module taken on cost, pinned by tests; holds, the Unicode version unstated (L2-9).
L2-76. *The Release Review's Wrong Results*, 09-30, 5459: `String.drop` decided with the user over the numbers. Holds as a decision; rule 1 has no sentence for it (L2-12).
L2-77. R-2, R-23, R-27, 5491: trusting foreign code at a variable for good, making the marks writable before the tag, and the operators, each weighed and left, not before the tag. Each holds until its MVP 2.99b item.
L2-78. R-25, 5491: three signatures and the program's process changed on the release's eve. The time reason lapsed with the release; the design one, a program could outlive every read bounding it, holds and should stand alone.
L2-79. *`Random` in Ernest*, 09-20, 2850: shims over `rand`. Reversed at 4212, where the seed had to cross nodes; rule 1 read as lives in the runtime, then as cannot be computed.
L2-80. Toolchain and review entries on cost or time, named only: 3129 (planned at C3-39), 3868, 4946, 4656, 4830, 4834, 4838, 4674, 4652 (kept until MVP 3.0). Each says what would change it; none decides a language rule.

#### Alike cases decided differently

L2-81. *Three Failures Principle 3 Answers For*, 3746, against *Code Travels Only With a Spawn*, 4574: a remote send the peer cannot resolve faulting the sender after return kept on 3, removed on 1 and 3 three days later.
L2-82. *Three Failures Principle 3 Answers For*, 3746, against *A Write to a Socket or a Program Answers*, 5175: `Tcp.write` `Unit`, its failure seen by monitor or next read, then refused as out of the type; 3 on both sides.
L2-83. *`Keys`, and Who Owns the Terminal*, 2900, against *A Claim of the Terminal the Other Way Faults Its Caller*, 5171: a double claim faults the entry process, reported like `Deadlock`, then the caller.
L2-84. *The Report's Silences*, 5111, against R-13, 5491: `<<-1>>` stays a fault at construction though the compiler could see it, then a compile-time error as the likeliest slip in an unsigned byte; one day apart.
L2-85. *A Time Below 0 Is 0*, 3722, against *No Limit Is `Unlimited`*, 5377: a time clamped to 0 in one and to 1 in the other (L2-30).
L2-86. *A Program Ends With `Os.exit`*, 4542, against *`Tcp.listen` Names Its Interface*, 4972, and E.20's `Bytes.fromList`: a status out of range faults, a port `Left(Other(...))`, a byte `None`; three shapes (L2-29).
L2-87. *The Code Read Back*, 3962, against *A Function May Be Named `module_info`*, 4290, and 3992: the 255-character atom becomes §2.3's rule, reserved names and the timer limit are hidden; by no rule (L2-6, L2-7).
L2-88. *The Terminal Writes Its Own Sequences*, 4420, against 4412 and 3946: ECMA-48 into E.16 on rule 3, HTTP and CommonMark to libraries as specifications; the reason given would put HTTP beside `Tcp` too (L2-17).
L2-89. *Shims Where the Runtime Owns the Representation*, 2838, *`Bytes` Gains `String`'s Text Functions*, 5241, and 5459: speed refused for a `Bytes` search, taken for `List.sort` and `String.drop` (L2-12, L2-13).
L2-90. *`Bytes` Has a Module*, 2808, against *`Clock.monotonic` Is In, and `Udp` Is Placed*, 5301: rule 2 gives `Bytes` its vocabulary program or none, `Udp` admitted and waiting for someone asking (L2-14).
L2-91. *One Primitive for Remote Computation*, 3730, against *No Remote Computation in the Language*, 4526: `remote` kept since the runtime picks the peer, removed as policy unseen by the program (3); one property, both ways.
L2-92. *What the Library Lacked*, 4228, against *`Other` Says the Host's Words*, 5385: `IoError` gets no text since rule 3 will not choose a wording, then `Other` holds the host's English; refused, then admitted (L2-10).
L2-93. *A Socket Lives Until It Is Closed*, 4362, against C1-2, 5491: the memory rule cited for never the runtime's, then for an owner that kills the socket (L2-37).
L2-94. *Standard Input and Output Carry Bytes*, 4428, against *Sockets Are Read by Pulling*, 5249: `Io.read` takes no milliseconds since it waits for input, `Tcp.read` takes them since a peer may never answer (L2-22).
L2-95. *A Subscription Says Whether It Has Keys*, 4206: `Terminal.size` answers `None` and `Terminal.subscribe` answers `Left(NotATerminal)` for not a terminal (L2-24).
L2-96. *Abstract-Type Ownership*, 2754, against *An Abstract Type's Boundary Is Its Module*, 3982: member-only access from §4.4 as written, no principle; removed on 1, 2, 4 and 5 six days later, which should have come first.
L2-97. *One Primitive for Remote Computation*, 3730, and *`Int.div` and `Int.rem`*, 5183, against 4276 and *`Address.callForever` Stays*, 5187: a composition and a variant leave the prelude on 2, another pair stays (L2-33).
L2-98. *`Ets` in the Standard Library*, 2914, against *Ets Is a Library*, 3692: as fundamental to a server as `Map` to a function, then refused by rule 1's own sentence; four days, and the first cites no rule.
L2-99. *No Not-Reply-Carrying Mark on a Container Element*, 2762, against *`Optional` and `Either` Hold a Reply*, 5143: `Optional(a!)` needless under §6.6, then `Optional` holds a reply; 1 both times, `List` left (L2-35).
L2-100. *Field Selection*, 4028, against *No Projection From a Tuple*, 4032: the neighbours' `e.f` admitted on principle 1, the same neighbours' `t.0` refused on 3 and 4 with 1 not asked (L2-2).
L2-101. *`Random` in Ernest*, 2850, against *A Shim Reaches the Representation*, 4212: E.12's questions shims, `rand` behind `Seed`, then SplitMix64 in Ernest; rule 1 read as in the runtime, then as uncomputable (L2-79).
L2-102. *A Restart Has a Limit and No Strategy*, 4124, against *What Building `Os` Found*, 4678, and C1-2: nothing owns a process, then a program's process is killed with its starter, and a socket dies with its owner (L2-38).
L2-103. *The Closing Sweep of the Shell*, 3902, against *A Lambda Bound by `let` Is Generalized*, 5151: the prompt's `let` not generalized, a second meaning, then every lambda `let` generalized, the prompt's by §11.2 (L2-55).
L2-104. *What `Fs` Holds*, 5006, *A Running Program Is a Process*, 4608, and C1-3, 5491: `removeAll` waits a step, `Os.start`'s time bounds the life, then `removeAll` waits once; a step, a life or a whole, by function (L2-25).
L2-105. *A Built-in Type's Operators in Its Module*, 2770, *A Member Is Written `T.name`*, 5139, R-27, 5491: members with an inline body, shims left, shims taken; the same operators, member, shim, member, shim (L2-28).

### X, the sixteen sentences read back

Read at a6a93ab against the rest of the report; each line carries its decision.

- fixed — X-1 §6.6: a built-in type never reply-carrying through its arguments let `[r]` escape; `List` exempted, a list element and `::` named.
- gap, and fixed for `let` — X-2 §4.5 against §4.4's example, §4.2, §4.6, §11.2: members that are not operators; a `let` declares no member.
- fixed, the code a gap — X-3 §8.2 against E.17's `Fs.list` and E.23's `environment`: nothing left out; an error naming the entry, a fault naming the variable.
- fixed — X-4 §3.8 against §3.10: `Foreign`'s equality; §3.10 no longer denies it.
- fixed — X-5 E.1: `Io.debug` written over `Io.show` at a variable; both are primitives resolved at the call, the type known whole.
- fixed — X-6 rule 2 against E.5 and E.20: text and octets are containers read through `toList`, their operations named.
- gap — X-7 shape rule 8 against E.18's and E.23's signatures (`Tcp.write`, `Os.write`, `Os.read`, `Os.start`).
- fixed, the code a gap — X-8 E.18: a listener dies with its owner.
- fixed — X-9 §6.2: a restart's dropped messages and a program's end named with the one silence.
- fixed, `via` a gap — X-10 §9 against §9.5: milliseconds after any callback (rules 1 and 8); `via(f, addr)`'s order for round 2.
- fixed, `readRange` a gap — X-11 §7.4 against §6.9 and E.17: no other value corrected unsaid; a negative count answers `Left` for round 2.
- gap — X-12 principle 5 against `spawn`'s `Where`: the sentence's intended `report` line.
- gap — X-13 rule 2 against E.16's ECMA-48 builders: to a library in round 2.
- fixed — X-14 rule 1 lost the host's path syntax; named among its tables.
- fixed — X-15 principle 3: a rule the value decides is a value or a fault when it runs.
- fixed, the reader right — X-16 principle 3's "a result no value can be" is `fault`'s type; the item went, §8.4 stands.
- fixed — X-17 §3.8: a host value Ernest does not inspect.
- fixed — X-18 §4.8: `==` exact on a foreign type and `Process`.
- fixed — X-19 rule 4: a two-constructor type's pair.
- fixed — X-20 rule 2: the kinds it lists, not "more than one module".
- fixed — X-21 glossary and §11.5 on the mark a foreign type writes.
- fixed — X-22 §9: a rule that names it, or the runtime alone.
- fixed — X-23 §7.4: a stream's failure faults the entry process.
- fixed — X-24 rule 1: a system module's functions are its primitives; E.12 says so.
- fixed — X-25 glossary: *primitive* in §0's sense too.
- fixed — X-26 principle 1: the report states the departure as a rule.
- fixed — X-27 §6.2: `kill` or a close of what has ended is within the silence.
- dropped — X-28 E.20's `size` and E.8's `toString`: `size` is the operation, not a primitive beneath one; `Int.toString`'s admission is E.8's in round 2.
- fixed — X-29 §7.4: a duration has no upper bound.

### Y, the fixes read back

Read at 143f34a against the rest of the report; each line carries its decision.

- gap — Y-1 §4.5's "a `let` declares no member" against §4.2, §4.4, §4.6, §11.2 and Appendix A's `DeclName`: the rule; the sections and the grammar are the dated gap.
- fixed — Y-2 §6.6's definition of reply-carrying names a list element; a pattern binds every reply-carrying field and element.
- fixed — Y-3 §7.4: an unwritable output stream ends the program without a fault (§8.6); an unreadable input and keys not UTF-8 fault the entry process.
- fixed — Y-4 E.23's "variables `environment` leaves out" went.
- fixed, naming a gap — Y-5 rule 1: each section names its primitives, a system module's too; E.16 and E.1 name theirs in round 2.
- fixed — Y-6 §6.2: the one silence is an act on what has ended, `give` among them, stated once.
- fixed — Y-7 §3.8: a host value of no other Ernest type.
- gap — Y-8 shape rule 1 against `via(f, addr)`: dated.
- fixed — Y-9 §9: where no declaration, a `foreign fn` among them, could give it its meaning.
- fixed, `readRange` a gap — Y-10 §6.9: a window below 1 is 1, since a window of none would be `Unlimited` written otherwise.
- fixed — Y-11 shape rule 2: `size` on text counts graphemes.
- fixed — Y-12 glossary: *primitive* one concept, beneath what Ernest writes, the language's and a module's.
- fixed — Y-13 §11.5: `Map(k=, v)` and `Set(a=)` written so by the report.
- fixed — Y-14 E.1: by the type at which the name is used, more than an operator asks.
- fixed — Y-15 E.18: a listener's owner is `listen`'s caller.
- fixed — Y-16 principle 3 and §6.2: a value, a message, or a fault.
- fixed — Y-17 §7.4 lists `Os.environment`'s initializer fault.
- fixed — Y-18 rule 1: a primitive calls no Ernest function but a wrap it delivers through.

### Z, the second fixes read back

Read at 2ac2603; each line carries its decision. Nine of the fourteen fixes conflicted with nothing.

- fixed — Z-1 §6.2: an act on what has ended that asks nothing back.
- fixed — Z-2 rule 1: in a system module, a function that reaches its process is a primitive and the rest is Ernest.
- fixed — Z-3 §7.4 names the restart window's floor; §6.9 loses its rationale clause.
- fixed, the reader right — Z-4 §9's test makes `Io.show` and `Io.debug` the prelude's, which they are: §9.4 lists them, E.1 provides them.
- fixed — Z-5 E.1: the type at which the name is used as a callee or an argument.
- fixed — Z-6 §6.6: the pattern `[]` discharges.
- fixed — Z-7 §11.5: §9.2 lists `Map(k=, v)` and `Set(a=)` with the mark, though neither is a foreign type.

---

# Findings of the release review

The findings of the review of the first release, run on 2026-09-30 as [`release_review.md`](release_review.md) says, on commit `691b4d6`: its machines, and its readers, the report's (R, the principles and the cold reader as one), a newcomer's (N), and the code's in three parts, over what changed since `0753fd8`: C1 the runtime and the standard library, C2 the front end, the checker and the emitter, C3 the command line, the shell and the libraries. M is a machine's. A line carries its decision: **tag**, fixed before the release's tag; **ask**, a question for the user, decided before the tag; **cheap**, clarity fixed before the tag where it is cheap; **2.99b**, planned in the plan's MVP 2.99b, its first item; **dropped**, with the reason; **next full review**, left for it. Each reader's list stands below the lines, condensed from what the reader handed in. This file goes when every line is done, dropped, or planned.

## Hardening

- 2.99b — foreign code forging the runtime's handles (C1-5)
- 2.99b — the signals a started program inherits (C1-9), and the launcher's environment (C1-10)
- 2.99b — a temporary name, the configuration directory's window, startup files' owner, a crafted `.erc`, the shell's atoms, and `:output` to a pipe with no reader (C3-26 to C3-31)
- dropped — the proxies of distinct `via` addresses (C1-20): decided 2026-09-30, §8.4

## Where the language made the work harder

- dropped — decided before: a list of functions as a binding (C3-47, *A Cycle Through a Function Stays One*), `kill` on a `Process` (C1-39, *`kill` and `monitor` Keep the Address*), `Io.Error`'s text (C3-45, *`Other` Says the Host's Words*), an `if` without `else` (N-C4, N-L6), a `List` of `Reply` (C1-38, §6.6)
- dropped — decided since the review: `Int.toStringBase`'s `Optional` for a literal base (C1-42, C3-43), since an argument outside its range answers `None` (§7.4, *A Failure's Shape*); a timeout on every call on a local file (C3-44), since a file is another party's and its wait is bounded (E.0 shape rule 8, *What Waits With a Limit*); the order of a `Down` among the ended process's messages (N-C2), stated in §6.9 in MVP 2.99; string formatting (N-C5), declined in the log's *Later* and *Erlang's Standard Library, Module by Module*
- dropped — held by the principles review's findings, which decide them: a position carried through a `String` and `slice` to the end (C1-41), P2-31 and L2-89; a bitstring segment compared with a bound value (C1-42), a guard comparing it meanwhile, the pin `^x` of L1's family 2; a grapheme classified by `Char`'s predicates (C3-42), P2-1 and P2-20; `Map.get` in a `receive` guard (N-C6), P1-6 and P1-63
- dropped — weighed: a process waiting on what its mailbox type does not hold (C1-40) does so by a call, §6.6's one way, which the supervisor's `Hold` is; `List.findMap` (C1-42) is `List.filterMap(xs, f) |> List.get(0)`, a pipe of two that E.0 rule 4 refuses, and that it applies `f` past the first `Some` is speed, no reason (E.0 rule 1); a cause's controls written as escapes (C3-41) is §11.2's form, its quotes and backslashes left as they are, the toolchain's and not one the language's literals read back (E.0 rule 3), so it stays the shell's, and `Io.show` writes the literal; the `[]` clause on `String.split`'s answer (C3-46) is the price of one list type, a non-empty one being a second sequence (principle 2), and other languages' `split` answers a list too; a shim and its wrapper for a host answer the program discards (C3-48) state the boundary's two sides, what the host gives and what Ernest answers, which principle 3 keeps visible

## Rules that buy little

- principles review — the report reader's list of rules that buy little, taken by the principles review above, whose *Rules that buy little* compares it with P's, and its counts, which that review counts against (R's list below)

## The readers' lists

Each reader's list as it was handed in, condensed to a line a finding; the readers' programs are in the session's scratch directory, and each line names the file and line of `691b4d6`.

### R

Defects
R-1 E.1 vs §4.4: Io.show by static type breaks abstraction: fn show2(x) = Io.show(x) prints Seed(42) where Io.show(s) prints <abstract>; show2('a') 97.
R-2 §4.7/§7.4/§8.4 silent on a result type variable named by a parameter: foreign fn weird(x : a) : a = "erlang:length/1" returns 3 unchecked into List(Int); fault later in Io.show with host stack. Same for a callback parameter at a type variable.
R-3 §4.2 Prelude. escape: "Prelude.List.size is the prelude's List.size" but List.size is E.2's; reaches List.size past local type List but not Io.println past local type Io; a root module's function unreachable from a module whose type shares its name; toolchain refuses Stack.other that §4.2 resolves to the root module.
R-4 §3.9 vs §4.6: "a binding that is not generalized whose type keeps a variable nothing resolves" asks annotation; block lets not generalized but §4.6's { let xs = []; List.size(xs) } stays open. Fix: "a top-level binding".
R-5 §5.10 "as binds loosest" vs Appendix A (or looser than as): Some(1) or Some(2) as x refused; patterns can't be parenthesized.
R-6 E.0 rule 4 vs the listing and rule 2: Map.merge, Map.contains, List.any, String/Bytes.contains, Set.union/intersection/difference/isSubset, Map.keys/values, Io.println are compositions.
R-7 §7.3 says causes are §7.4's; E.22's four causes not in §7.4.
R-8 E.1 "<reply>" cannot happen (Io.show is (a!) -> String).
R-9 E.0 shape rule 5 vs Supervisor.group with m (spawns, reaches no system reference): add "or spawns".
R-10 E.0 shape rule 8's kinds omit Clock.monotonic and Io.debug.
R-11 §3.10 omits Foreign in "instantiating it with a type that contains a function or an address".
R-12 §5.7 vs Appendix A: x |> Some(1) and x |> W(b = 2) unsettled; toolchain treats them differently.
R-13 §5.11: <<256>> and <<-1>> compile (fault at run time) but <<1:size(4)>> refused; which violations are compile-time.
R-14 §6.9/E.22: a sibling that never waits blocks the faulted child forever; not stated.
R-15 §6.9 "whichever run asked": restarting entered partway (monitor before restarting) — cancelled? say "before or within a run".
R-16 §11.8 no status for ern run ended by the host's interrupt.
R-17 §8.2 order of checks: stdin not a terminal, a line read, then Terminal.subscribe: NotATerminal or "already read as lines"?
R-18 §11 refuses old spellings it never lists.
R-19 §11.4 ern doc's usage line omits file.erc and src-dir forms (SYNOPSIS).
R-20 E.1/E.3 Io.show of a Map has no fixed order: // => examples nondeterministic.
R-21 §3.7/§3.10 vs §3.8: Foreign and a foreign type differ in equality.
R-22 §4.5/§4.6 two ways to declare a function (fn f vs let f = fn), differ (recursion).
R-23 §3.9 inferred restrictions never written; exported signatures don't show process-only/equality/reply.
R-24 §6.5 send through via runs hidden code in the sender; a fault in f kills the target.
R-25 E.23 Os.start's ms is a lifetime, not a wait (shape rule 8).
R-26 §4.8 a local helper over an operator needs an annotation (fn add(a, b) = a + b inside a body).
R-27 §9.6 fn Int.+(a, b) = a + b "not a recursive call": declare as foreign fn shims.
Clarity
R-C1 §3.9 uses a! before §11.5 defines it. R-C2 §8.4 "and so is one Ernest code gives to a Reply foreign code gave" unclear. R-C3 §6.6 "callee was restarted where its supervisor restarted it" -> where a restart was asked for. R-C4 §6.9 "a process that computes without waiting is not restarted" reads as never. R-C5 §6.9 "begins with nothing of the old one" but children, sockets, programs, tables survive. R-C6 §8.2/E.21 "one subscription" -> one of each kind. R-C7 §8.5 "in the order §8.5 evaluates them" self-reference. R-C8 §5.4 cites §4.6 for let _, should be §5.10. R-C9 §4.4 external names omit Main.Stack.pop/empty. R-C10 §3.7 lacks Process. R-C11 E.0 rule 1 "the cause of a restart" undefined. R-C12 E.17 Left(Other("exists")) vs Fs.Kind's Other. R-C13 §11.2 --source-root dir vs §11.7 src-root. R-C14 §11.2 ./.ernest/startup not run without --config-dir though ./.ernest is default. R-C15 E.18 site "Tcp.listen" without line. R-C16 Appendix F gaps/order/stale entries. R-C17 G.1 "abridged" but D shows all nine.
Rules that buy little: private abstract type error; lambda-let generalized; "not a recursive call"; Prelude.; reply linearity machinery; type-directed Io.show; Test/TestResult in prelude; result type variable taken as Unit; §6.7 restates §6.2; ////; Path.toString and Map.merge; reserved abstract/export/foreign could be contextual; k= only in foreign type; guard-expression language. Keep spawnMonitored, callForever modest.
Counts: reserved 18 (18); contextual 11 (12, or 12 with Prelude); namespaces 35 by old method / 25 by §4.2 now; prelude functions 30 (32: §9.6 19 was 21); prelude types 25; primitives outside §9 3 (5-6 counted the same way now); concepts 89 (79; Appendix F 100 entries).
Toolchain divergences: Stack.other not resolved to root module; no `a < -1` help inside a block (§11.5); follow-on "operand type not determined" error reported (§11.5 says not).

### N

A. Defects
A1 guide §2.9 l533: Io.show example Other("eaddrinuse") now "address already in use" (stale after E-C5).
A2 guide §1.4 l244 "(b) with `-> Unit`" and §2.4 l366 "function result types use `->`": a result is `: T`.
A3 §8.1 square.ern: peers fault "peer unreachable"; nothing says peers unbuilt; `ern config` writes config nothing reads; "MVP 3.0" meaningless to newcomer.
A4 §4.4 l904 fan-out cites §8.7 for member/writer/credit (§8.7 is echo server); §9.5 systemd unit for "the chat server" never built.
A5 §2.5 l400 address-as-map-key error underlines Map.size/Map.get/Map.empty, never the key.
A6 guide l3 "needs nothing beside it" vs pointers to style.md, development.md, Appendix C, libs/ets load path.
A7 §8.4 l1938 Ets.new/put "a function §8.5 builds": §8.5 builds only get.
B. Clarity
B1 README counter example unexplained (with Never, Local, Reply/answer, 1000 ms).
B2 README leads with distribution (unbuilt); name the release.
B3 README: minimum OTP version.
B4 guide: alarms cannot be cancelled not said in §5.5.
B5 order between Down and a process's earlier messages unstated (§5.2).
B6 fault-line timestamps when stderr piped: note at §6.3.
B7 error "NotText has named fields; write NotText(field = p, ...)" should name the field.
B8 shell: `let w : Word = "x"` says "body ... declared to return Word": wrong words for a let.
B9 :doc Fs.Entry "milliseconds ... a whole number of seconds" reads as contradiction.
B10 :browse Fs shows `type Fs.Entry` without fields; :browse not mentioned at §2.9.
B11 §7.2 Stack.push(x, stack) breaks subject-first.
B12 §14 l2276 "paper programs" unexplained.
B13 ern format: `if` inside a lambda laid out awkwardly (else under lambda start).
C. Language made it harder
C1 alarms can't be cancelled; deadline messages pile up in a long-lived coordinator (queued grows one per job).
C2 no stated order between Down and messages.
C3 `type Word = String` declares a new type with a nullary constructor String shadowing prelude name; no warning; no alias.
C4 no one-armed if.
C5 no string formatting.
C6 four near-identical match arms (Map.get in receive guards impossible).
C7 String.split literal separator only.
C8 nested record updates spell both constructors.
Program: /home/jocke/.claude/jobs/0fab4189/tmp/review/newcomer/findex/findex.ern

### C1

A. Security exposures
C1-1 ern_tcp.erl:95-98 guarded catches only error: ; host with U+0000 -> gen_tcp exit:badarg, worker dies, caller hangs, deadlock detection stops. Refuse U+0000 in host (E.18), catch every class.
C1-2 ern_tcp:45-49 socket outlives the handler that faulted (linked only to Tcp): fd/process leak per connection. E.18 says so literally -> report question: a socket killed when the process that opened it dies (E.23's rule).
C1-3 fs.ern:306-331 removeAll TOCTOU (readLink, stat, list) -> symlink swap empties another dir (CVE-2022-21658). Fix in ern_fs with lstat before each list, or state the race.
C1-4 §8.4 checks skipped: Foreign.from carries an address past the proxy; function nested in argument/message/answer not wrapped (=C2-7); foreign answer to a stdlib call not checked (standard mode).
B. Hardening
C1-5 ern_boundary:170 chk pid accepts forged {via,F,T}/{foreign,...}/{foreign_reply,...} from foreign code; foreign `R ! {R, answered, V}` skips the check.
C1-6 ern_rt:127-133 held/3 undoes a proxy without comparing descriptors: Address(Int) handed back as Address(String) delivers unchecked. Report question.
C1-7 fresh_run waits for {Ref, fresh} with no monitor: a dead clock/terminal holds every restart forever.
C1-8 settled/1 flushes only one stray answer.
C1-9 ern_exec.c:202-207 children inherit ignored SIGFPE; reset all catchable signals.
C1-10 Os.environment carries the launcher's BINDIR, EMU, PROGNAME, ROOTDIR.
C. Defects
C1-11 supervisor: A faults, B asked; B faults on its own before taking the ask; emptied() drains the ask; B restarts AfterFault, no Settled(B); A waits forever. Fix: Faulted(p) -> settled(waiting, p).
C1-12 held/3: a via address round-tripped through foreign code loses its function (behind row holds process_of). Type-unsound delivery.
C1-13 ern_boundary raised/6: '$ern_restart' thrown in a callback foreign code runs becomes a fault. Let it through.
C1-14 String.split/lines/replace quadratic (parts re-measures). Predates.
C1-15 ern_exec.c:335-339 memmove per partial write: quadratic stdin to started program.
C1-16 supervisor watcher releases held child on Run before askRestart: child runs f twice.
C1-17 supervisor counted: callForever(sup, Faulted) -> a child waiting when the supervisor restarts in place gets Fault("callee was restarted"), reported/counted. Use Address.call + Process.info.
C1-18 second process running a group after first supervisor died: "callee had ended" not "a group runs in one process"; a supervisor killed before Run lets the next become supervisor silently.
C1-19 child joined but not yet in restarting: ask_restart does nothing but counted as asked -> faulted child hangs. askRestart answers Bool, filter.
C1-20 proxies accumulate per distinct via (decided §8.4) — noted.
C1-21 restart scans: restarted/1 ets_match(?CALLS) over all calls (was ets:take on callee bag at 0753fd8); cancelled/1 ets:match over ?HELD in reaper and clock; three round trips per restart. Against CLAUDE.md cost rule.
C1-22 ern_rt:1395-1398 {fault, Msg, Trace} in an initializer not reported under the binding.
C1-23 supervisor.ern:10-11 page says mailbox kept; :20-21 "not when it restarts because it was asked" vs Settled sent then.
C1-24 Tcp.connect can't reach IPv6 (no family).
C1-25 Fs.readRange with huge count allocates: Other("not enough memory"/"invalid argument"); E.17 promises fewer bytes or none. Cap count.
C1-26 Os.start: argument > 128 KiB -> "the runtime's helper ern_exec failed" (E2BIG status 7 before s).
C1-27 Foreign.toList accepts improper list.
C1-28 ern_os:145-149 stop/1 leaves the deadline timer; stale {timeout, Ref} makes quiet/1 read busy (deadlock detection).
C1-29 Path: extension(Path("..")) = Some(""); withExtension(Path("a/.."), "") = "a/."; withExtension/join normalize "a//b".
C1-30 String.isEmpty O(n); E.20 promises Bytes.lastIndexOf, missing; Clock.monotonic `with m` vs E.0 rule 5.
C1-31 page examples without // => (process.ern:43, terminal.ern:33,113,213,222); bytes_test covers none of 10 new functions; restart_ends_subscription_test ignores subscribe result.
D. Clarity
C1-32 supervisor run numbering now dead (clock cancels alarms at restart): Group.run, Expired(Int), runs counter, Run's Optional(Int).
C1-33 ern_rt comments: HELD comment omits delivering rows; :14-15 answered form "as §8.4 says"; :444 dead `_ -> ok`; ets_match name.
C1-34 ern_tty_tests silent/0 comment misplaced; Makefile -pa comment merged into PARTS paragraph.
C1-35 supervisor: counted recomputes fromAddress(me); Msg doc "what it sends itself"; group's "one process runs it" ambiguous; child's Errors "a child runs on its supervisor's node" unreachable.
C1-36 ern_boundary header omits {callback, Make}; check/3 comment; ern_tcp:219-222 stacked comments; ern_os:83 history; guarded name clash; armed/zeroed walk whole descriptor per value.
C1-37 pages: Map/Set signatures without k=/a=; Set.toList order; Path.name(Path("/")) = ""; Process.live "started" omits adopted; io.ern:33 and/or; bytes.ern wording; terminal.ern:266 two lookups; ern_show:169 comment \\n.
E. Language harder
C1-38 List cannot hold a Reply -> Held/Waiting hand-rolled.
C1-39 kill/monitor take Address(a) -> closures (decided E-C2).
C1-40 a process cannot wait without a message of its own type -> Hold call.
C1-41 Strings: no position carried; slice has no "to the end".
C1-42 Int.toStringBase Optional for literal base; no List.findMap; bitstring pattern can't compare a segment with a bound value.

### C2

A. Defects
C2-1 emitter ern_emitter.erl:545,611 swaps a module's own Io.show/Io.debug (type Io + fn Io.show) for the stdlib's: matches the written path, not the checker's ref.
C2-2 emitter :271 Unnamed = type_vars(Ret) -- ...: `--` removes one copy; foreign fn pair(n : Int, x : a) : #(a, a) faults on every return ({tuple,[never,never]}).
C2-3 typecheck :2788 `fn f(x as x) = x` / `#(a, b) as a` crashes (exit 70): p_as names not walked.
C2-4 parser :479-482 regression: shell no longer takes another line after `if c then a` (error at `if`, not eof → not incomplete). Also older: `fn f(g : ()` at eof not incomplete.
C2-5 parser :826-827 pattern `-0.0` is host negative zero: never matches; `0.0 | -0.0` not redundant (§3.1 no negative zero).
C2-6 emitter :257-266 fault inside an Ernest callback called by foreign code reported as "foreign function lists:foreach/2 raised error:badarith" instead of Fault("division by zero") (§7.4).
C2-7 emitter exposed/2 :940-950 + crosses/1 :1044: a function nested in a foreign argument (#(Int, (Int) -> Int)) not wrapped (§8.4 requires the check).
C2-8 typecheck :1377 impl name regex `$` accepts trailing "\n": "erlang:abs/1\n" builds.
C2-9 typecheck :1203,:1211-1216 init-cycle message names member let without its type (`empty` not `Stack.empty`).
C2-10 typecheck :1209-1212 cycle help for lambda-valued let with Others≠[] suggests `fn f() = ...` which changes f's type; give `fn f(...) = ...` whenever Body is a lambda.
C2-11 typecheck :1198,:1209 "through" list usorted (not cycle order); help names wrong function (f vs g that reads a).
C2-12 `fn k(g) = { let _ = g == g; g(1) }` equality error reported at g(1), not at ==.
C2-13 ern_diag.erl:81 lone CR dropped in excerpt while lexer counts a column: caret off by one; should show U+240D.
C2-14 parser help lines false: `x : ()` "the type of no value is Unit"; `x : Io.println` "type arguments are written Io(println)"; `type _p` "...: _p" unchanged; `Circle()` with fields "written without them".
C2-15 ern_types.erl:455 signature help uses `->` for zero-param/pattern-param heads, `:` otherwise.
C2-16 formatter trailing/3 ern_format.erl:731-735 adds a space after an opening bracket before a block comment: `g( /* a */ 1, ...)`.
C2-17 (unverified) emitter :398-403 a match's size-let reads run before its scrutinee (§5.11 "when the match begins" after scrutinee §5.1).
B. Clarity/specs/comments
- ern_emitter :1250 stale comment above pattern_names/1; :1436 unreachable clause {{named,Names},none}; :120 use #scheme record; :1521 + ern_bitspec :20 unit key now only 8/1.
- typecheck :3187 -spec prelude_one separated from its function; :632 filter N =/= none never false; :1897 declared_scheme/3 catches only {type_error,_,_} (lookup_value throws {type_error,#diag{}}) -> catch throw:_; :1149-1186 reference_graph built twice; declared_twice/first_repeat/twice quadratic.
- parser :418 help deep list vs fail/3 spec string(); :964 through/3 placement.
- ern_prelude :455 restarting's "### Errors" untrue under Unlimited, doc never mentions Unlimited; :608 comment cites "(plan, MVP 2.5)".
- ern_pretty :216-219 accept/3 comment omits `alternative`; header "style guide" vs §11.6.
- ern_format :342-344 confusing comment about the parameters' bracket.
Conforming: == on function types; one-constructor type formatting; lexer control chars; `...` gap; standard mode; RestartLimit/Unlimited.

### C3

Options match §11.7 exactly; conforming statuses: --help/--version 0, refused command line 1, format --check 1, ern test 1, ern run Os.exit, killed entry 1, closed stdout 141 via ern_out.
Security
C3-1 shell.ern:476, :492 an input's own fault cause and a report cause written raw ("fault: " <> text): control chars reach the terminal; §11.2 says escaped.
C3-2 editor.ern:165 pasted text and C1 typed chars inserted raw; region paints them: OSC reaches terminal (title/clipboard), cursor miscounted, history replays. Paint controls as pictures.
Defects
C3-3 ern_shell:1342 with_sources catches only throws; parse_module {ok,Bin}=file:read_file: :load of unreadable/0xFF source ends the whole session (status 1). Also :1593, :1716, compiled_of :1739.
C3-4 I/O errors exit 70 (ern_build :112,:278,:422,:433; ern_cli :403,:432,:507,:617,:1001,:1047): unreadable source, build-root in /proc, config in ro dir. §11.8 says 1.
C3-5 non-UTF-8 source crashes (70) in ern_diag:lines via report_errors/error_text; --short-errors gives 1.
C3-6 ern_build:194,:202 re:run without unicode: path component outside Latin-1 crashes (70); shell completion of such a dir kills the reader. No regex (CLAUDE.md).
C3-7 ern config --config-dir dir/ creates dir then refuses it (eexist), leaves it.
C3-8 ern shell with stdout closed exits 0 with host error report; §11/§11.8 say 141.
C3-9 :load of a compiled module skips interface/stdlib checks (needed_one, compiled_of) vs ern run's; report silent.
C3-10 startup file's :load/:reload/:type diagnostics lose file and line (§11.2).
C3-11 editor.ern:147-151 Delete/Home/End/PgUp/PgDn/F1-F4/Ctrl-arrows insert characters ("a3~", "aH"); §11.2 every other control key does nothing.
C3-12 ern format dir takes dir as source root: namespace rules refuse valid modules (util/list.ern "takes the prelude namespace List").
C3-13 ern run/test/shell of a non-Ernest .erc prints the binary (438 KB) instead of "x.erc is not a compiled module".
C3-14 --main not checked: 300 A's -> system_limit (70); ../../etc.main looks outside the load path; A..b.
C3-15 ern_build:119-120 nested non-UTF-8 names crash (70) instead of §11.1's error.
C3-16 ern_build:628 doc sweep list_to_atom of a page's title: 300 A's -> system_limit (70); unreadable page crashes.
C3-17 ern_cli:894 ern test writes a test's name raw (controls).
C3-18 ern_cli:809,:814 the shell's own session fault exits 1 (§11.8 says 70); Msg unescaped.
C3-19 (unverified) reload end_previous exits then purges without waiting: processes may end Killed rather than Fault("its code was unloaded").
C3-20 :load List answers as success (plain), §11.2 says refused (red).
C3-21 :type let _ = 1 accepted, :type let x = 1 refused.
C3-22 history.ern:55-57 two shells trimming share history.new.
C3-23 report silent on whether C-c keeps the line in history; code keeps it.
C3-24 shell/README.md:75 run/3 (is run/4); :69 "only Shell.Editor uses another" (Complete uses Command).
Hardening
C3-25 ern_build:741 write_whole follows a .erc link planted in the build tree (overwrites the link's target).
C3-26 ern_build:751-761 predictable temp name, not exclusive: planted link truncates victim's file in a shared dir.
C3-27 ern_cli:1048-1049 config dir made then chmod 700: window; key file not exclusive/600 at creation.
C3-28 startup files run without owner/mode check.
C3-29 binary_to_term without [safe] on .erc chunks (ern_iface:37, ern_docs:23); ern_page:81-83 source name into roff comment unescaped.
C3-30 ern_shell:805 binary_to_atom from :doc/:forget/:browse/:load/Shift-Tab; lexer on every Tab: atoms grow.
C3-31 :output to a FIFO without reader blocks the session.
Clarity
C3-32 no_job/1 repeats old_spelling/1 messages. C3-33 ern_build header claims other jobs out of compiler hash (false). C3-34 orphan comment ern_cli_tests:307. C3-35 shell obey 8 copies of refuse; Continue. C3-36 editor names back/from/step double meanings. C3-37 complete.ern repeats. C3-38 history made per append (two fs requests per input). C3-39 persistent_term replaced per input/test (global GC). C3-40 Markdown.roff(page, blocks) subject second.
Language harder
C3-41 no library fn writes a string's controls as escapes. C3-42 grapheme vs Char predicates. C3-43 Int.toStringBase Optional. C3-44 every local-file call needs a timeout. C3-45 Io.Error has no text. C3-46 exhaustive match on String.split forces [] arm. C3-47 list of functions as let (E-C1). C3-48 shim answering true needs raw fn + wrapper.

