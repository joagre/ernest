# The findings of the release review before 0.11.0

Found on 2026-11-26 over commit `6c6b8ef1`, by the release review of [`reviews/release.md`](reviews/release.md). It is MVP 4.4's item 5. The lines sorted from the readers' lists come first, and the lists stand whole below them.

A finding is named by its list's heading and its number, `M 1` or `C6 clarity 2`, since the lists number alike. Where a list numbers each group afresh, the group's first word stands between.

The readers' programs, their briefs, the checks' outputs and the panel's driver are kept outside the repository, in the session's probes directory, `release_0110/`. A path below written `readers/X/…`, `listings/…`, `checks/…`, `bench/…` or `panel/…` is under it. `c/` is the clone the readers read, which a fresh clone of `6c6b8ef1` makes again, and a path of the repository is the clone's at that commit.

## The readers

Twenty readers, each an agent of its own with the brief `briefs/X.md`. The readers of the report, the guides and the documents ran on the stronger model at the session's effort, and the readers of the code on the coding model at the stronger effort, as [`agents.md`](agents.md) has them.

The report changed in more than half its paragraphs since `v0.10.0`, so its readers read it whole with the diff beside it. The code's readers read their parts' diff since `93a13b13`, the commit the full review read whole.

| Reader | What it read | Its counts |
|---|---|---|
| P1 | `report/language.md` against §0 | 3 defects, 12 principles, 6 clarity |
| P2 | `report/library.md` against §0 | 12 defects, 7 clarity, 6 kept, 10 principles |
| P3 | `report/toolchain.md` against §0 | 4 defects, 9 principles, 1 clarity, 2 outside the diff |
| K | the report whole and the argument, cold | 8 defects, 7 clarity, 2 outside the diff, 5 kept |
| U1 | `guide/language.md`, every example run | 10 defects, 5 restated, 5 clarity, 4 language, 1 incidental |
| U2 | `guide/deployment.md`, `guide/why.md`, `guide/faq.md` | 11 defects, 13 clarity, 2 language |
| N | the newcomer, with the program `sheet` | 8 defects, 21 clarity, 8 language, 11 names, 7 leftovers |
| L | the Erlang programmer | 4 defects, 21 clarity and answers, 3 leftovers, 5 language |
| M | the Gleam programmer | 3 defects, 18 clarity, 5 language, 3 kept |
| C1 | the lexer, the parser, the formatter, the Emacs mode | 5 defects, 10 clarity |
| C2 | the checker | 5 defects, 11 clarity |
| C3 | the emitter | 1 defect, 12 clarity |
| C4 | the runtime and its helper | 1 defect, 5 clarity, and the call rows' question |
| C5 | the shell's Erlang and the terminal's | 3 defects, 17 clarity |
| C6 | the command line, the builder, the nodes | 1 defect, 11 clarity |
| C7 | the tests, the tools, the site's client, the Makefiles | 5 defects, 13 clarity |
| E1 | `src/stdlib/` | 5 defects, 9 clarity, 4 language, 2 kept |
| E2 | the shell's Ernest | 4 defects, 11 clarity, 3 language |
| E3 | the libraries, the examples, the tour's programs, the Ernest tools | 5 defects, 13 clarity, 8 language |
| S | security, over what changed in what it reads | 1 exposure, 3 hardening, 2 clarity, 1 language |

## What was read in part

Each list says at its head what its reader read and how. Where a finding may be missing:

- No reader ran a `make` target, so `make lengths`, `make terms`, `make citations`, `make unchecked` and `make edits` started no reader. U2 made three of the listings by running the tool itself.
- P3 and K started no node: the attached shell, `ern reload`, `ern stop`, the carrier and the exchange are read and not run by them. L, M, N, U1 and U2 ran nodes.
- C4 did not read `ern_rt_tests`, `ern_tcp_tests`, `ern_stdlib_tests`, `ern_laws_tests` or `ern_os_tests` line by line.
- C7 set aside the 795 lines moved from `ern_nodes_tests` into `ern_harness` and the lines whose one change is the call's prefix.
- U1 read the toolchain's and the library's diff by section and not every hunk, and ran nothing that needs a terminal.
- L did not check the lines of Gleam, which M did, and neither did the guide's exercises, which N did.

## The lines

Sorted on 2026-11-26 by four sorters and a joiner that decide nothing, into the buckets of the log's *The Findings Pre-Sorted*, and read by the session: 382 lines. A finding that several readers met stands in one line that names each.

- `1`, `1r`, `2a` and `2b` are `fix`: 60 lines in a document, 18 in the report with every rule keeping its meaning, 108 in code where nothing a program, a user or a test's outcome sees changes, and 12 defects in code that a report sentence covers, each with a test.
- `3` is `decide`: 123 lines in 16 families, taken with the user a family at a time.
- `4` is filed, 39 lines: an item of the plan, `felt` with its entry of `language_feedback.md` or `new`, `known` with its line of `known_issues.md` or `new`, or `dropped` with the reason.
- `5` is a matter of clarity whose fix is not plain, 22 lines, which `reviews/release.md`'s fourth step drops. The session read each, and none shows a sentence false.

The mark `false` stands where a program shows a sentence of the report false, on 21 lines, and `user` where a first user meets the finding, on 18. An owner is the part of the repository a brief is cut by.

### `1`, fix: a document

Made on 2026-11-26, by two writers whose diffs the session read and by the session, but four: *U2 20*'s row in the deployment guide's table, which a test keys on and the tests' builder makes with it; *E1 C2 (style files)*, made when the standard library's builder turns the order it quotes; and *E1 C7*, *E1 D5* and *E1 D3 (never None)*, the standard library's pages, which are its builder's. `release/README.md` had *N 9*'s bare number too and is mended with it.

- **N 16 (:73), M18** `1` — `guide/language.md:73`: "One bound to a name the code never reads is not reported" has no near antecedent. Fix: "A failure bound to a name the code never reads is not reported". Owner: guide.
- **U1 4** `1` — `guide/language.md:112`: "§9 lists each job's options", and `--verbose`, `--doc-root`, `--version` and `ern test`'s four options are named nowhere. Fix: "§9 lists the options a program first needs, and `ern <job> --help` the rest". Owner: guide.
- **U1 10, N 4, N Leftovers (:147)** `1` — `guide/language.md:147` (§1.2): the session's number is cited to §9.3, which never mentions it; the fact is report §11.2's. Fix: point to "(§9.2, report §11.2)". Owner: guide.
- **N 28** `1` — `guide/language.md:149` (§1.2): "its `main` running beside the prompt" is silent on a `main` that reads lines, which faults with "the shell holds the terminal". Fix: one clause in §1.2. Owner: guide.
- **N 15** `1` — `guide/language.md:292` (§2.2): the contextual words are explained by requirement, member and `needs`, taught in §2.5 and §7.3, with no pointer. Fix: point at §7.3. Owner: guide.
- **U1 14** `1` — `guide/language.md:331` (§2.3): the prelude's `type Optional(a) = None | Some(a)` stands in a block marked `ernest`, so it is checked as a user's type. Fix: mark it `ernest-prelude`. Owner: guide.
- **U1 1, N 1, M1, N Leftovers (:340)** `1` user — `guide/language.md:340` (§2.3): says `type Command = Set(...) | Clear` is refused for its `Set`; it builds, and report §3.1 refuses only a type whose one constructor is named as a type in scope. Fix: cut the sentence, or give the one-constructor case, `type Failure = Down(String)`, read with P1 11. Owner: guide.
- **M20** `1` — `guide/language.md:590`, `:605` (§2.9): the list of modules leaves out `Address`, which `:browse` lists. Fix: name it in §2.9's list. Owner: guide.
- **U1 2** `1` — `guide/language.md:602` (§2.9): a stream that cannot be read is said to fault the entry process; report §7.4 and §12.1 fault the process that asked, as the guide's own :201 says. Fix: "a read that fails faults the process that asked, and a stream that cannot be written ends the program (report §7.4, §12.1)". Owner: guide.
- **U1 6** `1` — `guide/language.md:718` (§3.3): the values that make a top-level `let` polymorphic lack report §4.6's "a tuple or a list of values". Fix: add "a tuple or a list of values". Owner: guide.
- **U1 7** `1` — `guide/language.md:737` (§3.3): "with `xs` never read" is narrower than report §4.6, where `List.size(xs)` leaves the type open. Fix: "Where no use fixes it, as `List.size(xs)` does not, the type stays open". Owner: guide.
- **M15** `1` — `guide/language.md:860` (§4.1): `fn stop()` receiving nothing follows the rule unmarked. Fix: open the sentence with "The exception:". Owner: guide.
- **M16** `1` — `guide/language.md:868`: prints `(Bool) -> Address(m) receiving m`, where the shell prints `Address(a) receiving a`, and :774 makes `m` a name only. Fix: write it as the shell prints it. Owner: guide.
- **N 26** `1` — guide §4.4: whether `after` takes an expression is not said; every example is a literal. Fix: "an `Int` expression". Owner: guide.
- **U1 8** `1` — `guide/language.md:979` (§4.5): "it was restarted (§6.5)" among a `callForever` caller's causes; `callee was restarted` comes only where a restart was asked, §6.6. Fix: "it was restarted with a sibling (§6.6)". Owner: guide.
- **M10** `1` — `guide/language.md:1037` (§4.5): "`main` cannot make the call itself" holds only for a `main` that asks before it puts. Fix: "a `main` that asks before it puts cannot make the call itself". Owner: guide.
- **N 19** `1` user — `guide/language.md:1044-1089` (§4.5): `gather.ern` uses `fault` and `Reason` before §6.3 and §5.2 give them, and the two-file program has only `ern run collect.erc`. Fix: a build line, and pointers for `fault` and `Reason`. Owner: guide.
- **N 20** `1` — `guide/language.md:1511`, `:1525`, `:1925`: "a wrap" as a noun, introduced only as a parameter's name in §5.2; the report uses the noun. Fix: give the noun at §5.2, "its wrap, the function that makes the message". Owner: guide.
- **N 25** `1` — `guide/language.md:1778-1780` (§6.3): the trace keeps a recursion's frames as one (report toolchain §10, E.21), and §6.3 does not say so. Fix: one sentence in §6.3. Owner: guide.
- **U1 18** `1` — `guide/language.md:2451` against `:122`: three ways a program reaches outside against two, and TCP is a system module. Fix: drop the count at :2451. Owner: guide.
- **N 16 (:2533)** `1` — `guide/language.md:2533`: "A value that is computed, `1024 * 1024`, is a function's, `limit()`" read three times. Fix: "write it as a function, `fn limit() = 1024 * 1024`". Owner: guide.
- **U1 9, N 21** `1` — `guide/language.md:2609`, `:2633` (§8.1): cites Appendix C for what the scale measures, which lost its `utilization` entry; §12.8 owns it, and the guide never says what the scale counts. Fix: cite "(§12.8, Appendix E.27)" and add one sentence on what the number counts. Owner: guide.
- **N 22** `1` — `guide/language.md:2766`, `:2831` (§8.2): `Proxy.start(Counter.service, 5000)` never says the `5000`. Fix: say it is the find's milliseconds. Owner: guide.
- **M19** `1` — `guide/language.md:2902`: "Its printed type ... is not the rule", where the shell prints a line beneath that says the rule. Fix: quote the shell's line. Owner: guide.
- **N 24** `1` — `guide/language.md:3035` (§8.5, §8.6): `ets` is never said to be the host's table. Fix: three words at :3035, as `faq.md:47` says. Owner: guide.
- **N 3, N Leftovers (libs/ets)** `1` — `guide/language.md:3120`, `:3471`: `libs/ets` is no path of the repository; the library is `src/libs/ets`. Fix: write `src/libs/ets`, linked. Owner: guide.
- **U1 19** `1` — `guide/language.md:3302` (§9.3): "`Shift-Tab` shows the name's version" reads as a reload's version (`Counter$2`); report §11.2.11 means the release it appeared in. Fix: "the release it appeared in". Owner: guide.
- **U1 5** `1` — `guide/language.md:3444` (§10): "Integers are exact and unbounded"; report §3.1 bounds them by the host's integers. Fix: "Integers are exact, and bounded as Erlang's are". Owner: guide.
- **M2** `1` — `guide/why.md:206`, `guide/language.md:2839`, `guide/deployment.md:372`: a silent peer is said lost in 45 to 75 seconds; report §10 finds it silent then and runs the loss once the host closes, as deployment §2.3 says. Fix: "found silent in 45 to 75 seconds, and lost when the host closes the connection (deployment §2.3)". Owner: guide+guide-other.
- **U2 1** `1` — `guide/deployment.md:92`, `:216` (§1.3, §3): a change to `measures` "holds from the node's next measure of itself", the removed `utilization` entry's rule; :216's "A program may set the number itself" names no function. Fix: :92 as report §12.5's *A reload* has it; :216 names `Peer.setUtilization` and the guide's §8.1, or goes. Owner: guide-other.
- **U2 20** `1` — `guide/deployment.md:115`, `:391`: the site `Counter.serve:14`, from a first draft; `Counter.serve` is the entry point and spawns nothing. Fix: `Counter.main:57`, or `Counter.moving:106` for "spawned by the peer a". Owner: guide-other.
- **L18** `1` — `guide/deployment.md:121-134`: the unit has no `User=`, so as shown the node runs as root, where :162 assumes a service's user. Fix: a `User=` line. Owner: guide-other.
- **U2 4** `1` — `guide/deployment.md:142` (§1.5): `nohup` is said to keep a node running; a hangup is a reload on a node (report §8.6), and the program's own lines are not stamped. Fix: drop `nohup`; say a terminal's close is a reload, and that the node's own lines alone are stamped. Owner: guide-other.
- **U2 23** `1` — `guide/deployment.md:162`, §1.3: names only `ern reload` as refusing another user's `ernest.pid`; report §11.2 has both jobs refuse, the superuser included. Fix: name both commands in §1.3. Owner: guide-other.
- **U2 12** `1` — `guide/deployment.md:208-210`, `:321`; `guide/why.md:204`: a peer at another type "answers `Io.OtherType`"; the find answers the last failure met (E.27), so a later peer's answer can hide it. Fix: one sentence in 3.1 that the find answers its last failure. Owner: guide-other.
- **U2 3** `1` — `guide/deployment.md:226` (§3.3): gives `cpu` the host's parameters; report §12.5 has `cpu` take none and `memory`'s interval in whole minutes. Fix: "`memory` and `disk` each with `check-interval` and `almost-full`, `memory`'s in whole minutes; `cpu` takes none". Owner: guide-other.
- **U2 10, L19** `1` — `guide/deployment.md:279`, `:281`, `:448`: `Counter.serve receiving 3120 bytes` and `memory = 3120`; a fresh node shows 47512 or 114640, the figure names no machine or day against :17, and the test strips it. Fix: say the figure is the run's own, or write one a fresh node shows. Owner: guide-other.
- **M13** `1` — `guide/deployment.md:297`: "No line says how much memory a process holds, and `:processes` shows each process's bytes" reads as a contradiction. Fix: "No line of the node's standard error says". Owner: guide-other.
- **U2 14** `1` — `guide/deployment.md:299` (§5): uses `Counter.main:57`, the second build's tool and the module's first reload before §6.3 gives them. Fix: point at §6.3 there. Owner: guide-other.
- **U2 6** `1` — `guide/deployment.md:459` (§8): "Nothing connects until an operation reaches for `d`"; `d` has no address and is never dialed. Fix: "Nothing connects until `d` dials in". Owner: guide-other.
- **U2 9** `1` — `guide/deployment.md:463-471` (§8): the transcript leaves out `the peer b connected` and `the peer c connected`. Fix: add the two lines, or say `a`'s own lines on standard error are left out. Owner: guide-other.
- **M5** `1` — `guide/faq.md:17`: the list of what Gleam has and Ernest lacks reads complete; several positional fields, a sort by a comparing function and `echo` are missing. Fix: add the three, or write "among them". Owner: guide-other.
- **U2 21** `1` — `guide/faq.md:37`: "Nothing stands in for `terminate`" leaves out `Os.subscribeTermination` at an orderly end. Fix: one clause pointing at it. Owner: guide-other.
- **U2 24** `1` — `guide/faq.md:99`, `guide/why.md:399` cite §4.9 for §4.5 and §4.8; `faq.md:105` cites §8.3 for §8.7, §12.5; `deployment.md:323` cites §12.5 for nothing it states; §8 names no section; :17 omits §2.1's JSON. Fix: each citation to its owner, and :17's list completed. Owner: guide-other.
- **U2 13** `1` — `guide/why.md:9`, `guide/faq.md:115`, `guide/deployment.md:176`: a function known "not by the module it stands in"; report §8.7 puts its qualified name in its hash. Fix: say the name is part of what is hashed, so a moved or renamed module is new code. Owner: guide-other.
- **M11** `1` — `guide/why.md:139`: "the one channel a program makes is a `Reply`", where `adapted` makes another. Fix: "the one channel a call makes". Owner: guide-other.
- **U2 7** `1` — `guide/why.md:182`: every cause is said to name the function; a bad message and a bad reply name the type alone (report §12.3). Fix: "naming the type, and for a return or an argument the function". Owner: guide-other.
- **U2 5** `1` — `guide/why.md:188`: a connection accepted "under the name listed beside that key"; report §12.5 and the FAQ say under the name that key gives it. Fix: "under the name that key gives it". Owner: guide-other.
- **U2 22** `1` — `guide/why.md:296` against `:300`: "able to be delivered to" against "able to deliver" for one rule. Fix: the second wording in both. Owner: guide-other.
- **E1 C2 (style files)** `1` — `guide/style.md:33`, `docs/code_style.md:18`: both quote `let #(draw, seed) = splitMix(seed)`, the private order that the `2a` line P2 25, E1 C2 (code) turns. Fix: `let #(seed, draw) = splitMix(seed)` in both, with that line. Owner: guide-other+docs.
- **M21** `1` user — `tour/README.md:371`: three rules of version numbers in one sentence. Fix: two sentences, the trace's rule and the type's. Owner: tour.
- **N 11, M9, L2** `1` user — `README.md:38-51`, `:115`: the session cannot be typed from the README: `5000` and `<-` unsaid, the four commands name no `--listen`, so the bare `foo` refuses to start, and only `foo` is run. Fix: say `5000` and `<-`, name `--listen` for `foo` and that `a` is the shell, and point at the tour's chapter 2. Owner: readme.
- **L1, M3** `1` user — `README.md:51`: "no cookie, no epmd, no mesh", and every node's command line carries `-setcookie`, which deployment :178 and faq :107 name. Fix: "no shared secret", as `tour/README.md:123` says. Owner: readme.
- **M8** `1` user — `README.md:57-65`: shows the refusal of `other.ern`, a file the README does not show. Fix: say where its lines are, `guide/why.md:143`. Owner: readme.
- **N 9, L21** `1` user — `README.md:97`: "On Linux a node needs 5.3 or later", a bare number. Fix: "a Linux kernel of 5.3 or later". Owner: readme.
- **C2 C4, C3 clarity 2 (its glossary part)** `1` — `docs/code_style.md:198`, glossary *Recorded, Printing*: says definitions record "their printing" and foreign declarations "their schemes and printing", a field `#definition{}`, `#foreign_function{}` and `#recorded{}` no longer hold. Fix: drop both mentions of printing, and *Printing* from the heading. Owner: docs.
- **K 8 (argument)** `1` — `docs/soundness.md:229`: "The standard library's seven such functions" (foreign functions typed by a callback's mailbox type) leaves out `Test`'s, `marked` (`src/stdlib/test.ern:181`, `f : () -> a receiving m`) at least. Fix: the count and the list name `Test`'s own, read from `test.ern`. Owner: docs.
- **E1 C7** `1` — `fs.ern:224-225`: `makeDir`'s page says "a file there answers `Left(Exists)`"; a dangling link answers the same, a link to a directory `Right(Unit)`. Fix: "an entry there that is not a directory, nor a link to one, answers `Left(Exists)`". Owner: stdlib.
- **E1 D5** `1` — `process.ern:145-147`: `Callee`'s page says the callee is "the one whose end the cause says", but `callee had ended` gives `None`; E.21 (library.md:832) and `process.ern:106` say "says how the callee ended". Fix: "…whose end the cause says how, `callee was killed`; `None` for `callee had ended`". Owner: stdlib.
- **E1 D3 (never None)** `1` — `ordered_set.ern:261-279`, `ordered_map.ern:328-348`: `minimum` and `maximum` lack E.0 shape rule 6's "never `None`" sentence, which `List.minimum`'s page has; `ern_doc_tests.erl:247`'s `NeverNone` names none of the four. Fix: add "It is never `None` for a set (map) that is not empty" to each, and the four to `NeverNone`. Owner: stdlib+tests.

### `1r`, fix: the report

Made on 2026-11-26 by the session, but *P1 17*, §4.2's word "reach", which waits for the family on a program's modules and namespaces, since its verdict rewrites that paragraph. The pages of *E1 D1* and *E1 C6* are the standard library's builder's.

- **K 12, K Kept (§3.9 bullet)** `1r` — §3.9 `language.md:311`: asks for an annotation at "the mailbox type of a process spawned on a peer", where §3.11 (`:356`) makes an unfixed one `Never` and refuses only one that still holds a variable. Fix: "a mailbox type that still holds a type variable". Owner: report.
- **P1 17** `1r` — §4.2 `language.md:412-414`: "A job's reach" takes the word §8.7 defines as a definition's reach; the glossary holds both and cites §8.7 alone. Fix: §4.2 says "the modules a job takes". Owner: report.
- **K 11** `1r` false — §4.9 `language.md:549`: one quoted text for two errors; a variable in effect positions alone gives `e is an effect variable, and a requirement names a type variable in a value position`. Fix: quote both texts, each with its case. Owner: report.
- **P1 21 (§5.3)** `1r` — §5.3 `language.md:636`: "the longest `Expr` at the same nesting level (Appendix A)"; Appendix A says nothing of a nesting level. Fix: drop the pointer or the phrase. Owner: report.
- **P1 21 (§7.4)** `1r` — §7.4 `language.md:964`: "A function that receives nothing can fault." ends the paragraph on corrected values. Fix: move the sentence to §7.3. Owner: report.
- **K Outside :1124** `1r` — §8.7 `language.md:1124`: "a reply among them answered by the spawned process as §6.6 says of `spawn`"; §6.6 does not mention `spawn`, and E.27 (`library.md:1079`) holds the sentence. Fix: cite Appendix E.27. Owner: report.
- **P2 8** `1r` — glossary `language.md:1582`: "segment … of what TCP carries (Appendix E.18)"; E.18 no longer holds the word. Fix: drop the fourth sense. Owner: report.
- **P2 15** `1r` — glossary `language.md:1592`, `:1598`: "shape rule" says "of the standard library" where `library.md:186` holds them in every library; "standard library … on the load path by default" fits Appendix G too; "handshake" and "connection" are glossed for nodes alone, E.18 uses both for TLS and TCP. Fix: the three glosses follow the sections. Owner: report.
- **P2 9** `1r` — shape rule 7 `library.md:223`: "A prelude operation a module provides is listed in §9.6"; `Io.show` is listed in §9.4 (`language.md:1215`). Fix: "listed in §9". Owner: report.
- **P2 16** `1r` — E.1 `library.md:266`, `:270`: how `show` takes its type is said twice, and the first wording, "by the argument's type at the call", misses `List.map(xs, Io.show)`. Fix: keep the second sentence. Owner: report.
- **P2 12** `1r` — E.2 `library.md:280`: the list of functions called in the list's order, once each, leaves out `filterMap`, which `list.ern:192` calls in order. Fix: add `filterMap`. Owner: report.
- **P2 7, K 8 (E.24)** `1r` — E.24 `library.md:965-987`: E.0 rule 1 (`:139`) has each section name its primitives, and E.24 names none of `test.ern`'s four `foreign fn`, `marked`, `yield`, `captureWrites`, `captured`; E.10 and E.11 lack E.7's "The module is Ernest". Fix: E.24 names its four; E.10 and E.11 take E.7's sentence. Owner: report.
- **P2 17** `1r` — E.27 `library.md:1065`: "`service`, `offer`, … act as §8.7 and this section state, and answer as the listing gives" states nothing, and lists ten of twelve, `peers` out. Fix: drop the sentence. Owner: report.
- **P2 24** `1r` — Appendix G `library.md:1162`: "Each follows the shape rules E.0 holds a library to and documents itself as shape rule 6 asks" repeats `:186`, which holds every shape rule in every library. Fix: drop the sentence. Owner: report.
- **P2 14, K 15** `1r` false — G.11 `library.md:1364` against `:1397`: the prose gives `""` for a status the registry does not assign; the listing adds "or assigns for a time or has made obsolete", and 104, 306, 418, 510 give `""`. Fix: the prose takes the listing's three cases. Owner: report.
- **K 13** `1r` — §11.2.11 `toolchain.md:394`: "A character is a grapheme (Appendix F)" cites the glossary as owner; E.5 defines the grapheme. Fix: cite Appendix E.5. Owner: report.
- **E1 D1** `1r` — `int.ern:221` and E.8 (library.md:492): both say `Int.toFloat` faults beyond the largest finite `Float`, where §3.1 and the code fault only where the rounding gives no finite `Float`, from 2^1024 − 2^970. Fix: "Faults where `int` rounds to no finite `Float`" on the page, and E.8's comment the same. Owner: report+stdlib.
- **E1 C6** `1r` — `os.ern:501-505` and E.23 (library.md:909): "the first of these that holds: `NotATerminal`…" and then "`Closed` alone on a program whose process has ended" read against each other. Fix: put the ended case first, "…`Left(Closed)`, before the others", and drop "alone", on the page and in E.23. Owner: report+stdlib.

### `2a`, fix: code, nothing seen changes

- **C1 6** `2a` — `ern_ast:type_text/1` (`ern_ast.erl:148-175`): a clause-for-clause copy of `ern_docs:syntax_text/1`. Fix: one function taking the namespace to print, called by `ern_docs`. Owner: front+emitter.
- **C1 7** `2a` — six sites (`ern_lexer.erl:195`, `ern_format.erl:49, 143`, `ern_parser.erl:509, 536, 862`) still read a token by `element/2` beside the new accessors. Fix: use `ern_lexer:symbol/1` and `position/1` there. Owner: front.
- **C1 8** `2a` — `ern_diagnostic.erl:3-5` header says the lexer counts lines here; it counts its own and calls only `without_bom/1` and `without_return/1`. Fix: the reader's sentence, "cut here, for the excerpt and the formatter…". Owner: front.
- **C1 14** `2a` — `ern_diagnostic.erl:96-97`, `lines/1`'s comment names one line; it returns every line. Fix: "the source's lines as an excerpt shows them, each character one column". Owner: front.
- **C1 9** `2a` — `ern_lexer.erl:46-49, 66`: `#lexing` rebuilds the constant symbol table on every `tokenize/2`, under a comment about options. Fix: the table a macro or function of `?SYMBOLS` outside the record, the record the two options. Owner: front.
- **C1 10** `2a` — `ern_lexer.erl:96-98`: the help writes a `\u{…}` escape that `ern_literal:escape/2` already writes (same output shown). Fix: build it from `ern_literal:escape(Char, none)`. Owner: front.
- **C1 15** `2a` — `ern_lexer.erl:503-504`, `symbol/1`'s comment cites §2 for the token tuple's shape, which §2 does not define. Fix: drop "Report §2:", say the shape is the lexer's own. Owner: front.
- **C1 11** `2a` — `ern_parser.erl:826-832`, `parenthesized/4`: builds a node only to read its span. Fix: compute the span from `Position` and the closing token, as `mark_span/2` does. Owner: front.
- **C1 12** `2a` — `editors/emacs/test/*.el`: one prefix `ernest-test-` for `check.el`'s shared helpers and each file's own, and `ernest-test-source`/`-expected` say little. Fix: keep `ernest-test-` for `check.el`, each file's names that file's word (`ernest-typing-part`). Owner: front.
- **C1 13** `2a` — `src/shared/test/ern_tree_tests.erl:36-37`: hand-counts five `-pa` flags, tied to `tools/code_path.sh`. Fix: `[Arg || Arg <- Lines, Arg =/= "-pa"]`. Owner: front.
- **C3 Outside my part** `2a` — `checker/include/ern_types.hrl:90`: `#constructor_info.fields` says "canonical (sorted) order", where §12.2 (toolchain.md:858) and the term shown keep declared order. Fix: say declared order, after the checker's reader confirms. Owner: checker.
- **C2 C5** `2a` — `include/ern_types.hrl:137-141`: `#back_end.position` holds a number or `{Namespace, Number}`. Fix: the number alone, the declaring namespace beside it. Owner: checker.
- **C2 C6** `2a` — `ern_bound.erl` :59, :82, :91, :506-507: the three resource message types tested in four places. Fix: one `case resource_message(T)`, answering `none` for any other type. Owner: checker.
- **C2 C9** `2a` — `ern_canonical.erl:1385, 1397`: `read_recorded(other)` passed only to reach the error clause. Fix: a named `other_version()`. Owner: checker.
- **C2 C11** `2a` — `ern_resolve.erl:10` a short line left by a reflow; `ern_scope.erl:161` a comment that describes the input, not the result. Fix: refill; "The names of Variables, each held with where it is bound." Owner: checker.
- **C2 C2** `2a` — `ern_typecheck.erl:623`, `diagnostic/2` has one caller left (`depends_on_itself`, :2285). Fix: build `#diagnostic{}` there, remove the function. Owner: checker.
- **C2 C7** `2a` — `ern_typecheck.erl:1535`: `restore_scope(Env, #env{})` used to clear the scope. Fix: a `cleared_scope/1`. Owner: checker.
- **C2 C8** `2a` — `ern_typecheck.erl:4945, 4956`: `declared_scheme/3` and `declared_referent/3` repeat one lookup at a made-up position with one catch. Fix: one `declared_value/3`. Owner: checker.
- **C2 C1** `2a` — `ern_types.erl:215-233`: two mailbox reasons, `none_where_mailbox_needed` and `mailbox_where_none_needed`, that `unify_message` maps to one `none_vs_mailbox/6`. Fix: one reason `{none_vs_mailbox, Type}`, the comment's sentence dropped, `ern_types_tests.erl:49,57` updated. Owner: checker.
- **C2 C3, C5 clarity 17, C6 clarity 4** `2a` — test comments name review probes or findings, against `docs/code_style.md:20`: `ern_typecheck_tests.erl:1775, 1851, 5124, 889, 1526, 3512, 625`, `ern_canonical_tests.erl:269`, `test/ern_shell_tests.erl:5781`, `ern_carrier_tests.erl:76-77, 193-195`, `ern_exchange_tests.erl:842-844`; the style check's pattern misses this spelling. Fix: the log entry's title or "a regression test" alone, and widen the style check's pattern. Owner: checker+shell-erl+nodes+tests.
- **C3 clarity 4** `2a` — `ern_compile.erl:414-415`, `qualified_name/3`: a third copy of `ern_canonical:qualified/3` and `ern_typecheck:value_qualified_name/3`, keying a map the other copy built. Fix: export one and call it. Owner: emitter+checker.
- **C3 clarity 11** `2a` — `ern_compile.erl:505`: `#scope{}` spelled whole where defaults would serve. Fix: defaults `namespace = [], form_namespace = [], units = #{}`. Owner: emitter.
- **C3 clarity 2 (its code parts)** `2a` — comments the diff made wrong: `ern_emitter.erl:2614` "as §11.5 prints it" and `ern_compile.erl:443` "(§11.5)", where the type is written from the root by §12.3. Fix: "as §12.3 writes it (printed/2)"; "the state a check's cause prints its types under (§12.3)". Owner: emitter.
- **C3 clarity 5** `2a` — `ern_descriptor.erl:112-115` and `ern_emitter.erl:2745-2748` both write the recursive-type `{mu, Id, Sum}` wrap. Fix: export `ern_descriptor:recursive(Id, Sum)` in place of `refers/2`. Owner: emitter.
- **C3 clarity 12** `2a` — `ern_descriptor.erl:14` names `prompt_shows_as_io_show_test` without its `_`; `ern_docs.erl:91` left at 84 columns; `ern_descriptor.erl:150`'s spec `| term()` takes everything. Fix: add the `_`; reflow; `none | {positional, term()} | {named, [atom()]}`. Owner: emitter.
- **C3 clarity 1** `2a` — `ern_emitter.erl:97, 336`: `#emit_context.printing` copies `unit.link.printing`, and `printed/2` calls `from_root/2` at every check. Fix: drop the field and its header comment, or store `from_root`'s result once in `own_context`. Owner: emitter.
- **C3 clarity 9** `2a` — `ern_emitter:compiled/3` (:255) beside `ern_compile:compiled/2`, and `bound/4` (:3190) beside `bind/3` and `Bound`. Fix: `unit_functions/3` and `let_match/4`. Owner: emitter.
- **C3 clarity 6** `2a` — `ern_emitter.erl:1717-1718`: `primitive/1` gives `{call, 3}` and `{call_forever, 2}`, not the arities a program's call reaches (`call/4`), against its comment. Fix: the comment says these are the standard library's call, or `{call, 4}` and `{call_forever, 3}`. Owner: emitter.
- **C3 clarity 8** `2a` — `ern_emitter.erl:2425, 2433`: the returned term is `Returned` for Unit and `Checked` for a word. Fix: `named_variables(["Checked", "Returned"], Context)`. Owner: emitter.
- **C3 clarity 7** `2a` — `ern_emitter.erl:2552, 2582`: the maker's unused Bound is `_`, the exposer's is bound (`erlc +warn_unused_vars` warns). Fix: one helper that writes `_` where the body reads nothing. Owner: emitter.
- **C3 clarity 10** `2a` — `test/ern_emitter_tests.erl:2861`, `foreign_return_part_test` holds no constructor's field, which §12.3 names (the code is right). Fix: add that case. Owner: emitter.
- **C3 clarity 3** `2a` — `test/ern_emitter_tests.erl:4629-4643`, `prelude_targets_test` treats List's `<>` as a module function, now emitted as `++`. Fix: add `'List'` to `is_inline`'s `<>` clause, and leave only Path in `prelude_target`'s comment. Owner: emitter.
- **C4 5** `2a` — `ern_boundary.erl:120-121` cites `called/1`, which the module lacks. Fix: `(ern_emitter:called/1)`. Owner: runtime.
- **C4 6** `2a` — `ern_code.erl:51-53`: a comment left unrefilled. Fix: refill. Owner: runtime.
- **C4 2, C4 Leftovers (`Limited`)** `2a` — `ern_rt.erl:959-964`: `call_forever/4`'s `Limited` is always `false` since 86d0dcf5; the comment describes a caller none is. Fix: drop the parameter, `limited = false` in the record, drop the comment's clause. Owner: runtime.
- **C4 3** `2a` — `ern_rt.erl:5542`: `told/1` drops unread messages, beside `told/3`, the program end's telling. Fix: rename `told/1`, e.g. `dropped_words/1`. Owner: runtime.
- **C5 clarity 13** `2a` — `ern_tty.erl:27-29`: header says the tests exercise `decode/1` and `flush/1`; they call the exported `more/2` too. Fix: name `more/2`. Owner: runtime.
- **C5 clarity 7, C5 clarity 16, C7 clarity 3, C7 clarity 4** `2a` — fresh directories made by hand beside `ern_helpers:tmp/1,2`: `ern_tty_tests.erl:319-320` `scratch/1` (with direct calls beside it), `ern_harness.erl:53-58` `tmp/0`, `ern_shell_tests.erl:7294`, `ern_docs_tests.erl:139`, `ern_integration_tests.erl:2797`, `ern_guide_tests.erl:214, 301`, `ern_terminal_tests.erl` six sites, `ern_browser_tests.erl:805` (counter-only name). Fix: `ern_helpers:tmp/1` or `tmp/2` at each site. Owner: runtime+tests.
- **E1 D2, E1 K1, Z8** `2a` — `ern_set.erl:1-13`, `set.ern:43-44, 190`: the header says the host makes version 2 sets "only when asked"; OTP 28 made them the default and the floor is OTP 29, so the adapters do nothing. C4's leftovers read the header as true; the session ran `sets:new()` and `sets:from_list([1,2])` on OTP 29.1.2, `#{}` and `#{1 => [],2 => []}`: E1 is right. Fix: `"sets:new/0"` and `"sets:from_list/1"`, `ern_set.erl` deleted, `ern_show_tests.erl`'s use moved. Owner: runtime+stdlib+tests.
- **C6 clarity 10** `2a` — `ern_code_load.erl:65`: `#made_unit.name` holds the file name `code:atomic_load/1` takes. Fix: rename `file_name`. Owner: nodes.
- **C6 clarity 6** `2a` — `ern_exchange.erl:794-798` and `ern_arrival.erl:503-507` write the same five lines over `ern_code:recorded/2`. Fix: `ern_code:definitions(Unit, Read)`, called by both. Owner: nodes.
- **C5 clarity 6** `2a` — `ern_unpack.erl:22, 29, 38`: the term `{ern_unpack, entries}` holds the verbose flag too. Fix: key `{?MODULE, given}`. Owner: shell-erl.
- **C5 clarity 9** `2a` — `ern_shell.erl:61-64` repeats `asked/2`'s sentence (:5072-5075). Fix: keep it at `asked/2`. Owner: shell-erl.
- **C5 clarity 2** `2a` — `ern_shell.erl:393-395`: `prelude()`'s comment gives only speed; it also makes the library's names met before a completion (`docs/design/shell.md:125`). Fix: add the reason, or point there. Owner: shell-erl.
- **C5 clarity 1** `2a` — `ern_shell.erl:1186-1195`, `is_spawn/1`: a third copy of which names spawn, its `Peer` clause unreachable (shown). Fix: drop the `Peer` clause, take the names from the checker's one list. Owner: shell-erl+checker.
- **C5 clarity 3** `2a` — `ern_shell.erl:2017-2024`, `session_printing/3` takes `Scope` that `Session` holds. Fix: `session_printing(Session, TypeState)`. Owner: shell-erl.
- **C5 clarity 8** `2a` — `ern_shell.erl:2066-2070, 2973-2983`: two comments run paragraphs together without a blank `%%`. Fix: insert them. Owner: shell-erl.
- **C5 clarity 5** `2a` — `ern_shell.erl:2604-2611`, `declared_type/2` asks the checker again for a referent `one_name_declared/2` just found. Fix: return the referent with the scheme. Owner: shell-erl.
- **C5 clarity 11** `2a` — `ern_shell.erl:3047`, `is_found/2` builds a list to test membership. Fix: `lists:any/2`. Owner: shell-erl.
- **C5 clarity 10** `2a` — `ern_shell.erl:3212-3238`: `package_form/2`'s `none` means two things, and `source_loaded/4` runs `taken_form/2` again. Fix: a tagged `not_package | Form`, the form passed once. Owner: shell-erl.
- **E2 5** `2a` — `ern_shell.erl:3507`: `ern_rt:evaluate([Unit], <<"Ernest.Shell.load">>, 'Interrupted')` names the private `ShellMsg.Interrupted` by its host atom, unchecked. Fix: pass `Interrupted` from Ernest as an argument of `load` and `reload`. Owner: shell-erl+shell-ern.
- **C5 defects 3 (the shared helper)** `2a` — `ern_shell.erl:3841` `reload_changed/1` and :3885 `changed_at_start/1` each compute "the sources that changed", and can drift. Fix: one helper for a source whose hash differs. Owner: shell-erl.
- **C5 clarity 14** `2a` — `ern_shell.erl:3967`, `kept_values_line/2` trims with `string:trim` where the rest use `without_line_feed/1`. Fix: use it. Owner: shell-erl.
- **C5 clarity 4** `2a` — `ern_shell.erl:4903-4913`, `compiled_of/2` builds one refusal text twice. Fix: one local `not_compiled(File)`. Owner: shell-erl.
- **C5 defects 2** `2a` — `src/shell/test/ern_unpack_tests.erl:98-105`, `printed/1` reads `?capturedOutput`, which answered `""` 33 of 300 times under load, so `verbose_test` and `lock_link_test` can flake. Fix: `ern_helpers:captured_output()` in both places. Owner: shell-erl.
- **E2 14** `2a` — `editor.ern:89, 1515-1590`: the rename of `state` to `editing` left `states()` and "the state" in the tests and a comment. Fix: `editings`, or "the inputs a key is tried on". Owner: shell-ern.
- **E2 6** `2a` — `history.ern:14-16`: `History.fileMs` now times every file the shell reads, `:output` and the source root among them (`shell.ern:593…2470`). Fix: `shell.ern` has its own `let fileMs`. Owner: shell-ern.
- **E2 7** `2a` — `refusal.ern:15, 39`: `pathNamed` and `pathText` cannot be told apart, and the startup sites (`shell.ern:549, 580-614`) build the same by `fromWorkingDirectory` plus `controlFree`. Fix: name it for its work, `textFromWorkingDirectory`, and have the startup sites call it. Owner: shell-ern.
- **E2 11** `2a` — `region.ern:661-664, 673-679`: two tests cite "Report §11.2" for a rule only `docs/design/shell.md` *Width* states, and `offerWrapsAfterReset` repeats `offerWraps` but for a line. Fix: cite the design note, one test over both lines. Owner: shell-ern.
- **E2 10** `2a` — `shell.ern:36-47, 186-203`: the `///` text of the abstract `ShellMsg` and `LocalMsg` names 26 constructors and `nextRead` that the page hides. Fix: one `///` sentence each, the constructor notes as `//`. Owner: shell-ern.
- **E2 13** `2a` — `shell.ern:171-172, 339-340`: `Desk.sourceRoot` and `workingDirectory` became `Path` only to be turned back with `Path.toString` at their one use. Fix: type `start`'s two parameters `Path`. Owner: shell-ern.
- **E2 8** `2a` — `shell.ern:450`: `unkeptInterrupts()` is a noun for a function that takes messages, beside `dropInterrupts` (1275). Fix: `dropUnkeptInterrupts`. Owner: shell-ern.
- **E2 15** `2a` — `shell.ern:563-568`: `StartupFile = Own(String) | Configured(String)` needs `startupPath` to read the path both carry. Fix: `StartupFile(path : String, kind : StartupKind)`. Owner: shell-ern.
- **C6 clarity 3** `2a` — `ern_cli.erl:407-408`: `packaged/5`'s `{{error, enoent}, package_dir}` clause now does what the catch-all does. Fix: delete it. Owner: cli.
- **C6 clarity 2** `2a` — `ern_cli.erl:487-488` cites §11.3 for a sentence of §11.7 (toolchain.md:659). Fix: cite §11.7. Owner: cli.
- **C6 clarity 9** `2a` — `ern_cli.erl:702, 734-760`, `beam_of/4`'s `Say` serves only the `.erc` branch, the comment says both. Fix: make `Say` in that branch, drop the parameter, say which branch says what. Owner: cli.
- **C6 clarity 5** `2a` — `ern_cli.erl:1456` uses `ern_signals:number(sighup)`, `ern_node.erl:581` `ern_os:signal_number('Termination')`, one table by two names. Fix: one name at both sites. Owner: cli+nodes.
- **C6 clarity 7** `2a` — `ern_cli.erl:1822-1832, 2240-2270`: `reporting_options/2`'s `faults` is overwritten by `cases_launch/6`, each reading `{ern_cli, streams}`. Fix: pass the reporter into `reporting_options`. Owner: cli.
- **C6 clarity 1** `2a` — `ern_cli.erl:2119-2120`, `run_tests/6`'s comment "status 1 unless every one passed" misses a fault outside a case and the answer's shape. Fix: the reader's sentence, as `run_examples/4`'s says. Owner: cli.
- **C6 clarity 8** `2a` — `ern_cli.erl:2182-2183`, `example_launch/3`'s last comment sentence misstates its answer. Fix: "`{told, Passed, Outside}` … or `{ended, Status}`". Owner: cli.
- **C6 clarity 11** `2a` — `src/toolchain/builder/ern_build.erl` ends in a blank line. Fix: remove it. Owner: cli.
- **E2 9, C5 clarity 15** `2a` — `unpack.ern:85-86, 110-127, 232, 386, 422, 476`, `ern_unpack.erl:113-117`: paths made two ways; `packagePath` answers a String wrapped in `Path` at four uses; `isFoundFirst` takes a bare `.beam` member name as a `Path`. Fix: `packagePath` answers a `Path`, texts through `Refusal.pathText`, `isFoundFirst` takes a `String`. Owner: cli+shell-erl.
- **E2 12** `2a` — `unpack.ern`: `said(line)` writes, where the shell's same act is `say`. Fix: `say`. Owner: cli.
- **E1 C4** `2a` — `list.ern:603-626`: `extreme` and `kept` are `extremeBy` (661-675) with the key `fn(x) = x`. Fix: `fn extreme(list, beyond) = extremeBy(list, fn(x) = x, beyond)`. Owner: stdlib.
- **E1 K2** `2a` — `path.ern:95-97`: the private `separator()` is a function answering `"/"`, the shape of the old host read, called at 8 sites. Fix: `let separator = "/"`. Owner: stdlib.
- **P2 25, E1 C2 (code)** `2a` — `src/stdlib/random.ern:64-65, 71, 89`: the private `below`, `spanning` and `splitMix` answer `#(Int, Seed)`, against the listing's `#(Seed, Int)`, and `nextInt` swaps back. Fix: the three answer `#(Seed, …)`, with E1 C2 (style files)'s quotes. Owner: stdlib.
- **E1 C5** `2a` — `string.ern:169-175`: `startsWith` is a `slice` comparison and `endsWith` is `isSome(stripSuffix(…))`, two forms for one question. Fix: `startsWith = Optional.isSome(stripPrefix(text, prefix))`, read with E1 D4's `3` line. Owner: stdlib.
- **E1 C9** `2a` — `supervisor.ern:101-103, 123-126`: the `//` comments on `Join.stop` and `Member` give one reason twice. Fix: keep it on `Join`, `Member` says "`stop`, `Join`'s". Owner: stdlib.
- **E3 C6** `2a` — `http.ern:1700`: the private `isWritable` checks only the value; its callers (1779, 1819) read it as "the header can be written". Fix: `isPlainValue`. Owner: libs.
- **E3 C1** `2a` — `proxy.ern:55, 112-117`: the private constructor `Never` reuses the prelude's empty type's name, which guide/style refuses, and `sent` repeats `send(address, message)` in two arms. Fix: `Nowhere`, and `Found(address) or Away(address) -> …`. Owner: libs.
- **E3 C13** `2a` — crypto, base64, json, utilization, http tests and `tools/links.ern`: a comment that does not parse, `countsNoMultipleOfFour`, `longAt`, comments without a final period, `trickle`'s "a client" twice (http.ern:3411), an unsaid "listing", and `links.ern` inlining `isCapital`. Fix: rewrite each. Owner: libs+tests.
- **E3 C12** `2a` — `examples/snake.ern` `freePoint`: draws with `Int.max(1, List.size(free))` only to avoid `nextInt`'s fault where no cell is free. Fix: match `free` against `[]` first. Owner: examples.
- **U2 11, L4** `2a` — `examples/upgrade/v2/counter.ern:28-29`: a comment cites "the deployment guide's §5.3", gone since sections 5 and 6 changed places. Fix: "§6.3". Owner: examples.
- **U1 13** `2a` — `guide/language.md`: twelve messages quoted in prose (lines 957, 2080, 2116, 2118, 2124, 2514, 3274, 3294, 3304, 3486, 3504, 3512) are held by no test, though each is true today. Fix: `quoted_runs` gains the twelve, or each is shown as a console. Owner: tests.
- **C7 clarity 5** `2a` — `test/Makefile:65`, `RECORDER` names `ern_helpers.beam`, and :13-16 omits `ern_helpers`. Fix: `HELPERS`, and name `ern_helpers` in the comment. Owner: tests.
- **C7 clarity 11** `2a` — `Makefile:333-334` a garbled comment; ragged unrefilled paragraphs at `Makefile:47-50`, `ern_style_tests.erl:48-49, 302-304, 423-424`, `ern_manual_tests.erl:15-16`, `ern_nodes_tests.erl:1-4`. Fix: the reader's sentence, and refill. Owner: tests.
- **C7 clarity 12** `2a` — `Makefile:428-430` checks `MINUTES` beside `tools/flakes.ern:70-72`, and the two disagree on `00`. Fix: one check, make's accepting `[1-9][0-9]*` or the tool's refusal naming `MINUTES=n`. Owner: tests.
- **C4 The session's question (its point 3), C4 Leftovers (`guarded()`)** `2a` — `test/bench/ern_call_costs.erl`: the model has no closure through a `noted_call`-like function, no `at_receive()` in its callee, and `guarded()` (:374-378) pays a `persistent_term` read for `line_guard/1`, gone since f8f0eda9. Fix: add the closure row and the `at_receive()`, remove `guarded()`. Owner: tests.
- **Z1** `2a` — `test/fixtures/bench/bench.ern:111`: the bench's `Float.*, *` row is `Float.truncate(Int.toFloat(index) * 1.5)` and so measures `Int.toFloat`'s bound check (feedback 283), 1.24 to 2.92 times the host's, 17.9 to 40.9 ns. Fix: the row multiplies a `Float` it does not convert in its loop, and `Int.toFloat` gets a row of its own beside the host's `float/1`. Owner: tests.
- **C7 clarity 7** `2a` — seven readers of a fenced block in the tests, three new (`ern_grammar.erl:85-91`, `ern_tour_tests.erl:495-508`, `ern_deployment_tests.erl:690-695`), with rules unlike `ern_helpers`' `opening/3`; feedback 320 (item 175) counts two of them. Fix: one block reader exported beside `opening/3`. Owner: tests.
- **C7 clarity 8** `2a` — `ern_guide_tests.erl:214, 337` replay a shell session the same way twice. Fix: one replay helper. Owner: tests.
- **C7 clarity 1** `2a` — `ern_harness.erl:55, 265-431, 695`, `ern_tour_tests.erl:6-7`, `ern_deployment_tests`: names and comments kept from when the harness lived in `ern_nodes_tests` (`ern_nodes_<pid>`, `ern_nodes_client`, `-ern_nodes_*`). Fix: `ern_harness_` names, comments pointing at `ern_harness` and `ern_nodes_tests:finished/1`. Owner: tests.
- **C7 defects 1** `2a` — `test/ern_harness.erl:76-80`, `nodes_test/2`: a failure and `make slowest` name a nodes test by its bare name under `ern_harness`, a closure by the compiler's name. Fix: `Module:Name` as `counted_test/2` does, and a `nodes_test/3` that takes a name. Owner: tests.
- **C7 defects 4** `2a` — `test/ern_harness.erl:675-684`, `fault_line/4`: a round begun past its time waits 1 ms for the prompt and fails naming `"> "`, not the part missing. Fix: test the deadline before typing, fail with `{not_said, Dir, Part}`. Owner: tests.
- **C7 clarity 13** `2a` — `ern_integration_tests.erl:2927` `finished/1` only renames `collected/2`, beside another `finished/1`; `succeed/1,2` is called from two other modules. Fix: call `collected/2`, move `succeed` into `ern_harness`. Owner: tests.
- **C7 clarity 2** `2a` — `ern_nodes_tests.erl:42-58` holds the harness's own two tests, run only in the nodes area; nodes-only fixtures sit in `ern_harness`. Fix: the two tests in `test/ern_harness_tests.erl` under `make test`, the fixtures back to `ern_nodes_tests`. Owner: tests.
- **C7 clarity 6** `2a` — `ern_nodes_tests.erl:521, 9116`: `held/1`, a hash, beside `held/2`, an accept loop. Fix: `held_hash/1`. Owner: tests.
- **C7 defects 2** `2a` — `test/ern_repository.erl:10-19`, `files/1`: comment says `filelib:wildcard/1`'s rules, the code uses git's `:(glob)`, where a brace pattern matches nothing silently; no caller passes braces. Fix: say "git's `:(glob)` pathspec, no braces", and fail on a pattern that matches no tracked file. Owner: tests.
- **C7 clarity 9** `2a` — `ern_shell_tests.erl:7748, 8031` give `Os.run(..., 60000)`, against the glossary's WaitMs. Fix: `ern_harness:wait_ms_text()`. Owner: tests.
- **E3 C9** `2a` — `tools/documents.ern` `type Reading`: `Unread(why : String)`, a word the glossary refuses for a cause. Fix: `cause`. Owner: tests.
- **E3 C10** `2a` — `tools/documents.ern` `uncheckedRows`: folds a set into a set by hand. Fix: `Set.union(all, placesOf(reading))`. Owner: tests.
- **E3 C11** `2a` — `tools/documents.ern` `type Job`: the constructor `Citations` beside the module `Citations` the file calls. Fix: `CitedSections` or another word. Owner: tests.
- **E3 C3** `2a` — `tools/flakes.ern:356-359`: `quit` copies `Repository.quit("make flakes", message)`. Fix: call `Repository.quit`. Owner: tests.
- **E3 C8** `2a` — `tools/repository.ern:64-75` `pathOf`, `tools/documents.ern:670` `testOf`: a value for the `[]` that `String.split` rules out. Fix: `String.splitOnce`, or match the part always there. Owner: tests.
- **E3 C4** `2a` — `tools/sizes.ern` `listed`, `clones.ern` `cloned`, `words.ern` `withoutBorrowed`: the borrowed-file filter at three sites that must agree, `clones` reading THIRD_PARTY_LICENSES twice. Fix: `Repository.withoutBorrowed(tool, paths)`. Owner: tests.
- **E3 C2** `2a` — `tools/slowest.ern:112-122`: `contents` copies `Repository.contents("slowest", …)`. Fix: call `Repository.contents`. Owner: tests.
- **C7 clarity 10** `2a` — `site.js:76, 612-614`: `panel.terminal` became `panel.screen`, the class stays `panel-terminal` in CSS and tests. Fix: `panel-screen` in all three, or the old name. Owner: site.
- **C7 defects 5** `2a` — `site.js:699-713`, `showLimits`: `.catch(() => {})` swallows a handler's error, and a `data-limit` naming no limit keeps "a while" silently; tests check one span. Fix: keep the catch for `loadClient`'s rejection alone, and hold every `data-limit` to `limitsSaid`'s keys in the site test. Owner: site.

### `2b`, fix: a defect a report sentence covers

- **C1 5 (the help)** `2b` — `ern_parser.erl:513-517`: the help writes "as needs a.compare" plain, where §11.5 (toolchain.md:568) writes what the user is to write in backticks. Fix: ``as `needs a.compare` `` in all three clauses, with a test. Owner: front.
- **C1 1, C1 2** `2b` false — `ern_format.erl:852-854, 940-962`: a block comment ending a bracket's line glues the first item, `f(/* a */x, y)`, against §11.6 (toolchain.md:625), which puts that item on a line of its own; a second format moves it, so `--check` refuses the output; the Emacs mode (`ernest-mode.el:644-655`) reindents the aligned items to 8. Fix: count a block comment that ends the line in `EndsInComment`, check the Emacs reindent agrees, with tests. Owner: front.
- **C2 D5** `2b` — `ern_bound.erl:486-495`, `ern_typecheck.erl:4549-4551`: `ern_types:annotation_name/2`'s `none` for "no name" is also a type variable a user may name `none`, so `names_in_scope` drops it and a mailbox label may read "the signature writes none here"; read, not shown. Fix: `annotation_name/2` answers `{ok, Name} | none`, with a test. Owner: checker.
- **C2 C10** `2b` — `ern_bound.erl:201`: the note writes "a top-level fn" without backticks, where §11.5 (toolchain.md:568) writes source text in backticks and the module's help (:144) does. Fix: "a top-level `fn`", and the line `ern_shell_tests` quotes (about :5810). Owner: checker+tests.
- **C2 D1** `2b` — `ern_typecheck.erl:3406-3428`, `later_use/3`: labels the first node of the name anywhere in the body, so a use of a parameter of that name is labeled at the new local's type; §11.5 (toolchain.md:568) has the label mark "the use that gave" the type. Fix: look only in the statements after the `let`, by `ern_ast:free_uses/2`, with a test. Owner: checker.
- **C2 D2** `2b` — `ern_typecheck.erl:4488`: only `holder_text/5` passes `names_in_scope/1`; `unify_message`'s pair and `ern_bound`'s `capture_crosses`/`mailbox_crosses` print an unnamed variable as `a` beside a signature's `a` (`n1.ern`, `b5.ern`), against §11.5's "avoiding the names in use" (toolchain.md:596). Fix: pass `names_in_scope(Env)` to every format of a definition's message, with a test. Owner: checker.
- **C4 1** `2b` false — `ern_boundary.erl:441-442`: `zero({set, …})` sets every mark to `[]`, so a map that is no set passes as a `Set` (`callback.ern` prints 2, `beside.ern` returns it), against §8.4's check "to the value's whole depth" (language.md:998), and the cause prints a valid set, not the host's term (§12.3). Fix: keep each mark, `Item := Mark <- Value`, with a test. Owner: runtime.
- **E2 2** `2b` false user — `shell.ern:1047-1056`, `ern_shell:is_entry/1`: `ern shell hello.erc` writes `the process of Hello.main faulted`, where §11.2.7 (toolchain.md:328) prints "as `ern run` does" and toolchain.md:241 has the entry's line name "its entry point alone"; `:faults` too. Fix: `is_entry/1` also true for the process `spawn_program/0` starts, and `program_test_` matches the line from its first column. Owner: shell-erl+tests.
- **C5 defects 1** `2b` false — `ern_shell.erl:3843-3844`, `reload_changed/1`: `dependency_source/2` answers `none` for a named package's module, so every `:reload` says "the source root . holds no source of SlLeaf", against §11.2.8 (toolchain.md:360, 362), where a library's module loaded compiled is not named. Fix: leave out a namespace `ern_build:looked_in/3` answers `{none, _}` for, as `package_form/2` does, with a test. Owner: shell-erl.
- **E3 D1, Z11** `2b` false — `http.ern:1955-1962, 2053-2054`: `fourDigits` takes `"-001"`, so `Http.parseDate("Sun, 06 Nov -001 08:49:37 GMT")` faults in `date`, where `library.md:1370` answers `None` "for any other text". ernest-httpd reads `If-Modified-Since` with it on every request for a file, so such a client ends its connection unanswered: a server's security, mended for 0.11.0 (MVP 4.18's item 1). Fix: `fourDigits` takes four ASCII digits only, with a test. Owner: libs.
- **E3 D3, E3 D5** `2b` false — `markdown.ern:421-429` `isRule`, `:957-960` `opens` and `closingRun`: they test `' '` alone, so `---\t` and `_\t_\t_` are paragraphs and `x *\ta* y` is emphasis, the tab lost, where G.2 reads CommonMark 0.31 and its white space as spaces and tabs. Fix: `isSpaceOrTab` at the three, with tests. Owner: libs.
- **E3 D4** `2b` — `examples/interpreter.ern:186-191`: `fault("a run of ASCII digits reads as a number")` is met where `String.toInt` answers `None`, as its page says, for an integer the host cannot hold; a long line of digits ends the loop with a trace. Fix: a `LexError` for a number too large, answered as `BadChar` is, with a test. Owner: examples.

### `3`, decide

#### The sentences

- **P1 5** `3` false — principle 5 against §9.3 `language.md:1194`, `:1201`: a `match` on `Reason` in a program that uses no nodes and no service monitors must name `Unreachable` and `Restarted`. Fix: principle 5 states the departure, or `monitorService`'s wrap takes a type of its own. Owner: report. Decide: which of the two, or neither.
- **P2 1** `3` false — shape rule 8 `library.md:230`: a wait given 0 answers `Left(Timeout)` first "but where its section orders its answers otherwise (E.27)"; `Os.run(…, 0)` answers `Left(Io.NotFound)`, `Http.readRequest` and `writeResponse` given 0 answer other than `Timeout`. Fix: drop the pointer to E.27 alone, and E.23 says `run` given 0 answers `start`'s `Left` first. Owner: report. Decide: whether the report or the code moves for `Os.run`.
- **P2 2** `3` false — shape rule 8 `library.md:228`: the waits without a limit omit a load, which E.21 (`:808`) marks `limited` `false` and which waited 1500 ms on a binding; a child's join read, not shown. Fix: name `Code.load` and a child's join in the list. Owner: report. Decide: whether a load is a wait on another party for this list.
- **P2 6, P2 35 (pair sentence)** `3` false — E.0 `library.md:170`: "Two pairs are two ways to one value"; `Int.toString`/`toStringBase(n, 10)`, `String.toInt`/`toIntBase(s, 10)`, `Clock.monotonic`/`monotonicMicros() / 1000`, `Char.toString`/`String.fromList`, `isAsciiDigit`/`digitValue` agree too, and both named pairs only shorten. Fix: name these pairs, or say what kind of pair the sentence counts. Owner: report. Decide: what the sentence counts, and whether it stays.
- **P2 11** `3` false — E.0 `library.md:175`: "E.13 states its generator whole", and E.13 does not say how a draw becomes a number below a bound or a `Float`; `Random.nextInt(Random.seed(1), 10)` is `5`. Fix: two sentences in E.13 for the two mappings. Owner: report. Decide: whether E.13 states the mappings or E.0's claim narrows.
- **P1 19** `3` — §0 principle 2 `language.md:48`: the paragraph is a list of seven tests each met by one form, and the pun, which only shortens, is among them. Fix: say it lists the second spellings admitted, or cut it to the tests that decide. Owner: report. Decide: a §0 sentence.
- **P2 13** `3` — E.0 `library.md:135`: "where it needs what §10 refuses the standard library" points at no sentence of §10, which never names the standard library. Fix: name the bullet. Owner: report. Decide: which bullet of §10 the admission rule means.
- **P2 19** `3` — E.0 `library.md:160`, E.19 `:774`: `splitOnce` and `graphemes` are in no vocabulary, and `:774` lists `splitOnce` among the functions `String` has for text. Fix: add them, or say rule 3 admits them. Owner: report. Decide: which.
- **U1 11** `3` — `guide/language.md:592` (§2.9): "Mathematics over collections of floats ... is a library's too", dropped from E.9 at this release; the guide alone now states it. Fix: drop it, or give it back to E.0 or E.9. Owner: guide+report. Decide: whether the sentence goes, or returns to the report.

#### What a job of the toolchain does, says or refuses: is each said, refused or changed?

- **P3 1** `3` false — §11.2 `toolchain.md:233`: "the directory may hold several roots, a copy of a build among them", and `ern test all` refuses `all/copy/doubles.erc was compiled from all/src/doubles.ern, which no longer exists`, a source that never existed, while `ern run` runs the copy. Fix: narrow the sentence to a copy whose recorded paths reach its sources, and mend the refusal's text. Owner: cli+report. Decide: whether a copy's tests run or the sentence narrows.
- **N 6** `3` user — `ern doc src/grid.ern` after the guide's `ern build --build-root build src` says "compile Src.Cell first" of a compiled module; only `--source-root src --build-root build` works, and §9.1 (:3268) says nothing. Fix: the message names `--build-root`, and §9.1 says the job reads the compiled forms the module uses. Owner: cli+guide. Decide: the message's text.
- **P3 5** `3` — §11.3 `toolchain.md:508-510`: `ern config --config-dir stroe` makes a new node and prints its key in the form it prints an existing one's, status 0, nothing on standard error. Fix: a creation says `created stroe` on standard error. Owner: cli+report. Decide: whether a creation is said.
- **P3 8** `3` — §11.4 `toolchain.md:538`: `ern doc` refuses a whole directory for a root module `Index`, a name `ern build` takes, only for the listing's file name. Fix: the listing is `_index.md`, and the refusal goes. Owner: cli+report. Decide: the listing's name.
- **P3 9** `3` — §11.4 `toolchain.md:530`, `:552`: `ern doc --doc-root a main.ern` takes an option that does nothing, and `--verbose` prints `doc root a`; other options without effect are refused. Fix: refuse it, `--doc-root is given with a directory: …`; the same for `--build-root` with a file and the source options with a `.erc`. Owner: cli+report. Decide: whether such options are refused.
- **P3 15** `3` — §11.4 `toolchain.md:544`: `ern doc` judges a page by file times, so a source restored with `cp -p` leaves a stale page with status 0, where `ern build` and `:load` judge by digest. Fix: a page's last line records its source's digest. Owner: cli+report. Decide: digest or time.
- **P3 10** `3` — §11.9 `toolchain.md:766`, `:776`: `ern unpack` replaces a link `lib/leaf` to a checkout at another version with status 0 and no line, where a directory at another version is refused. Fix: say each link removed, `removed the link lib/leaf`, with `--verbose` or without. Owner: cli+report. Decide: whether the removal is said.
- **E2 3** `3` — `unpack.ern:446-469, 70-77`: `ern unpack --verbose` writes "stands at" lines before earlier entries' refusals, against `unpack.ern:66`'s "in the order they are made" and the test's "the manifest's order"; §11.9 (toolchain.md:766) is silent on the order. Fix: `unpackedOne` returns its lines for `main`, or `main` says the first two passes' refusals before the third. Owner: cli+report. Decide: which order the job's lines keep, and whether §11.9 says it.
- **P3 16** `3` — §11.2 `toolchain.md:217` against §2.1 `language.md:88`: a blank line in a doc example decides what is a top-level declaration, found by parsing prefixes, a second meaning §2.1 does not name. Fix: §2.1 names it, and §11.2 bounds the parses to the example's paragraphs. Owner: report+cli. Decide: whether the rule is stated or changed.
- **C6 defects 1** `3` — `ern_cli.erl:491-495` checks `--peer-dir` before `ern_node:peer_read/1` (`ern_node.erl:262-265, 397-404`), so a peer directory whose `ernest.conf` or `certificate.pem` is a directory reads "no configuration directory, which --peer-dir names", where `ern reload` reads `is no regular file`; §11.7 (toolchain.md:659) and §11 (:70) can each be read to cover it. Fix: keep only the CLI's no-such-directory test and let `peer_read/1` refuse the rest. Owner: cli+nodes. Decide: which refusal a peer file that is no regular file gets.
- **U2 8** `3` — `ernest.conf` with `"utilization-interval": 1e999`, valid JSON, is refused "is not JSON", where report toolchain §12.5 lists "holds a number too large for the host to read" apart and the deployment guide's §1.2 lists it apart too. Fix: the node's line names the number, or the list joins "is not JSON". Owner: nodes+report. Decide: which moves.
- **S 6** `3` — `ern_node.erl:34` `?FIELDS`: a 0.10 directory's `public-key` is refused as "the file has the unknown field public-key", which reads like a typo; MVP 4.18's item 4 names the refusal. Fix: a refusal of its own, "`public-key` is no longer a field: the key is read from private-key.pem; remove it". Owner: nodes. Decide: whether the field gets its own refusal, and its text.
- **P3 3** `3` — §11.2.8 `toolchain.md:340`: `:load` says `no module Util on the load path` for a used module it also seeks under the source root; the same command says `under the source root . or on the load path` for the module it names. Fix: `no module Util, which Main uses, under the source root . or on the load path`. Owner: shell-erl+report. Decide: the message's text.
- **C5 clarity 12** `3` — `ern_shell.erl:3052-3076`, `took/2`: its comment says the file the session took, but `compiled_of/2` answers the first `.erc` now on the roots, which differs where a form is written earlier on the path after the load; read, not shown. Fix: `held_form(Session, Root, [])` for the compiled case. Owner: shell-erl. Decide: which file `took/2` answers, since what the user is shown may move.

#### What an error or its help names: which slip does each help name, and in what text?

- **P3 4** `3` false user — §11.5 `toolchain.md:566` against §11.2.2 `:271`: "an error in a statement that binds nothing … does not stop the block", and the checker stops at `let _ = e`, which "binds nothing"; the second error in the block is not reported. Fix: §11.5 says "an expression statement", or the checker goes on after a `let` that binds no name. Owner: checker+report. Decide: which.
- **U2 25, N 27, M26, L31 (its message)** `3` user — the parser's messages state the grammar, not the mistake: `receive {...} after 2000`, `total = total + 1`, `import List`, `"inc " <> rest ->`, `area(width = 2, ...)`. Fix: helps that name the mistake: "there is no assignment", "there is no `import`", the `| after` clause inside. Owner: front. Decide: which habits get a help, and its text.
- **N 5, N 8, M22 (its help)** `3` user — helps that answer another mistake: `type Alias = Either(String, Int)` gets "a constructor has exactly one positional field" not "there are no type aliases"; `fn(x) -> x + 1` gets the result-annotation help; `gatherHere needs a mailbox` helps "give main its mailbox type" and never names `Process.run`. Fix: each help names the likely slip. Owner: front+checker. Decide: each help's text.
- **C1 3** `3` — `ern_parser.erl:604-613`, `unmarked_before_body`: a `a=` before `receiving`, `<-` or `needs`, or in a constructor's field, gets a generic parse error at the wrong token, where `a= =` and a parameter get "the equality mark is written in a foreign function's parameters alone" (§3, language.md:211). Fix: match those tokens, and a field's annotation through the parameter's refusal. Owner: front. Decide: whether those sites get the mark's message, an error text the report does not quote.
- **C1 4** `3` — `ern_parser.erl:1786-1791`, `bit_segments/2`: a `;` in a list or a bitstring reads "expected `]`" / "expected `>>`", where a tuple and a call read "expected `,` or `)`", the form the log's 2026-11-25 entry set; the report quotes neither. Fix: `expect_after_items(Tokens, Close)` for `]` and `>>`, in expressions and patterns. Owner: front. Decide: whether the list's and bitstring's close takes the "`,` or" form.
- **P1 10 (help)** `3` — checker, under §4.9: `let build = fn(xs) = OrderedSet.fromList(xs)` is refused with `help: annotate the value where it is bound`, which names no value; what is annotated is the lambda's parameter. Fix: the help names the parameter to annotate. Owner: checker. Decide: the help's text.
- **C2 D3** `3` — `ern_typecheck.erl:2661`, `distinct_param_names/1`: `lists:ukeysort` reports the alphabetically first repeated name (`a`), not the first written (`b`); §4.3 (language.md:489) quotes the error and names no order. Fix: `lists:keysort(2, lists:ukeysort(1, …))`, or report each. Owner: checker. Decide: which repeated parameter is reported, the first written or every one, and does §4.3 say so.
- **P1 21 (§3.9)** `3` — §3.9 `language.md:296`: "A function that receives nothing stands wherever a function … receiving `M` is expected" is narrowed after; `Run(steps)` of such functions is refused with no help. Fix: the sentence says "as an expression's own type", and the error names what to write. Owner: report+checker. Decide: the sentence and the error's help.
- **P1 3** `3` — §3.9 `language.md:292`: for `type Forest = Trees(List(Tree(Int)))` the help says `name Forest at the declaring type's parameters`, which cannot be written since `Forest` takes none. Fix: where the types differ in their parameters, the help says to give the group's types the same parameters. Owner: report+checker. Decide: the help's text and §3.9's sentence.
- **K 2** `3` — E.28 `library.md:1144` against §8.1 `language.md:974`: `Code.running` refuses a loop whose result type is a variable, which `spawn` and an entry point take as `Unit`, and its help does not write `: Unit`. Fix: E.28 takes a variable result as `Unit`, or refuses with a help that writes `: Unit`. Owner: report+checker. Decide: which.
- **K 5** `3` — §5.6 `language.md:665-667`, §8.5 `:1034`: `Ops(..Int)` with a field `compare` is in neither of the fill's cases, and the error names `Int.compare`, an expression the program does not hold. Fix: §5.6 says a member's field is not filled but given, `compare = compare`, and the help writes that. Owner: report+checker. Decide: the rule and the help.
- **C3 defects 1** `3` — `ern_emitter.erl:2392`, `printed/2`: a cause writes an equality-marked variable as `List(a=)`, the one place the declaration refuses the mark; §12.3 (toolchain.md:894) says only `a`, `b` in order, and is silent on the mark. Fix: §12.3 gains a sentence, or `printed/2` drops the restrictions and `#emit_context.restrictions` goes, with a test. Owner: report+emitter. Decide: whether a cause shows §11.5's marks.

#### The report's recuts: does a rule said in three places, a term, or a sentence that buys little stay as it is?

- **P1 6** `3` false — §9 `language.md:1153`: "a function enters it where no declaration, a `foreign fn` among them, could give it its meaning"; `kill`, `demonitor`, `fault`, `answer`, `adapted` are each given their meaning by a program's `foreign fn`. Fix: move those to their type's module, or §9 says what keeps them. Owner: report+stdlib. Decide: whether the five leave the prelude or the sentence changes.
- **K 14, P1 20 (§9 sentence)** `3` — §9 `language.md:1153`: "`Address.call` and `Address.callForever` are the runtime's, as the process functions of §9.4 and §9.5 are", where §9.5 lists both. Fix: drop the sentence, or name what it sets them apart from. Owner: report. Decide: with P1 6, whether the sentence goes or says what holds the two in §9.
- **P1 20 (§9.7, §8.2)** `3` — §9.7 and §8.2: "The prelude binds no system reference" states an absence kept from when it did; *system reference* and *system module* are named terms with three glossary entries that no program can name. Fix: head §9.7 as unused; fold the two terms into "system process". Owner: report. Decide: the recut of §9.7 and the terms.
- **P1 14** `3` — §6.2 `language.md:787`, principle 3: a `send` to an adapted address runs another's function in the sender and returns 1501 ms later; the rule stands at 787, 819 and 823. Fix: one statement in §6.5, and §6.2 points to it. Owner: report. Decide: whether the three statements are recut into §6.5's one.
- **P1 18** `3` — §3.9 `:317`, §4.5 `:485`, §6.1 `:771`: the rule that makes a mailbox variable none is stated three times and `kill(Process.fromAddress(self()))` used five; `Process.current()` serves without the rule. Fix: state it once in §3.9 with the `monitor` example, §4.5 and §6.1 point. Owner: report. Decide: the recut.
- **P3 14** `3` — §11.2.8, §11.2.16 `:484` against §11.2.17, §12.5 `:946`, `:952`: "reload" names the shell's recompile and the node's reading of its configuration. Fix: §12.5 and §11.2.17 write "a reading of the configuration", and "reload" stays the shell's. Owner: report. Decide: the job's name and the wording.
- **P2 21** `3` — E.0 `library.md:182`: "`Io.debug` is kept alone, by name", though a program now writes it in three lines with `needs a.show`, the composition rule 4 refuses. Fix: none given. Owner: report+stdlib. Decide: whether `Io.debug` stays by name.
- **P2 22** `3` — shape rules 4 and 5 `library.md:201-202` are pointers to §7.1, §7.4, §6.1 and §4.7, each a rule of its own at `v0.10.0`. Fix: none given. Owner: report. Decide: whether the two rules go, with the count of eleven.
- **P2 23** `3` — E.0 `library.md:158`: "Where a sequence's vocabulary has `sort`, it has `minimum` and `maximum`" when there is one sequence and the list before names both. Fix: none given. Owner: report. Decide: whether the rule goes.
- **P2 35 (rest)** `3` — E.18 `library.md:707`, "The host's process of a connection over TLS hibernates after a millisecond's wait", observable only in `memory`; E.0 `:147`, "A form is chosen for speed where this rule says so, and nowhere else", restates the clauses above. Fix: none given. Owner: report. Decide: whether the two sentences go.
- **P3 Rules that buy little** `3` — §11.9 `toolchain.md:764` "No job checks the promise", §11.9 `:719`'s sticky-bit refusal, `--emit-erl`, and `:269`'s "`export` at the prompt adds nothing", a word accepted without effect. Fix: none given. Owner: report+cli. Decide: whether any of the four goes.
- **P1 16, K 9, K Kept (listing comment)** `3` — §0 `language.md:66`, §3.11 `:364`, E.0 `library.md:139`: "primitive" means a function that is no value, §9's functions, and the operation beneath a shim; Appendix E calls the five "forms", and the listing comment and the checker say "a primitive, called where it is named". Fix: one sense, the operation beneath. Owner: report+checker+stdlib. Decide: the word for the five, everywhere.

#### Which page owns a fact: where a guide states a fact twice, points only, or claims more than it shows, which place keeps it?

- **N 13, M7, N Leftovers (Copies between README and why.md)** `3` user — `README.md:67`: the `restarting` caveat uses a word the README never gives, and stands in seven places; `README.md:55-65` repeats `why.md:141-165`'s Gleam paragraph and refusal. Fix: the README drops the caveat; the tour and the deployment guide keep it. Owner: readme+guide-other. Decide: whether the README keeps the caveat and the Gleam paragraph.
- **U1 12** `3` — `guide/language.md:686` (§3.2): the guide keeps v0.10.0's list of what ends a lambda's body, which report §5.3 dropped for Appendix A. Fix: keep the two cases a reader meets, `|>` and a `{` the body opens, and point to Appendix A. Owner: guide. Decide: whether the guide cuts the list to two cases.
- **N 18** `3` — `guide/language.md:719`, `:780` (§3.3, §3.4): corners on addresses and `Never` stand before §4.1 teaches them. Fix: move them to §4.1, or behind a pointer. Owner: guide. Decide: move or point.
- **U1 20, N Leftovers (Copies in the guide)** `3` — `guide/language.md`: facts stated more than once: the floor (:2453, :2478, :3472), the load path (four times), a `site` (:1357, :1770), `ern stop` (:2819, :3286), `ern run`'s report (:1823, :1877), `ern shell words.erc` (:149, :3304), `monitorService` (:1355, :1881), `Process.status` (:1139, :1143). Fix: state each once and point to it. Owner: guide. Decide: which place keeps each.
- **N 23, M27, M28, M29, L26, U2 18, N Leftovers (§11)** `3` — `guide/language.md:3476` (§11), `:222` (§1.4), `:3324` (§9.5), `guide/deployment.md:258-264` (§4.3): sections left as pointers after the recut, kept for their numbers; `guide/README.md:7` still lists "the design"; N asks §11 list the five principles. Fix: fold or cut each, or §11 names the principles. Owner: guide+guide-other. Decide: what each section becomes.
- **L3** `3` — `guide/faq.md:43`, `guide/why.md:17`: say §10 maps "each part of OTP", and §10 names no `global`, `pg`, `sys`, `observer`, `gen_statem`, `send_after`, cookie or purge. Fix: §10 gains those items, or the sentences say "§10 and the questions" without "each". Owner: guide+guide-other. Decide: grow §10 or narrow the sentence.
- **U2 17** `3` — `guide/language.md:2478-2512`, `guide/deployment.md` §1.1, §2.1, §8, tour chapter 2: making two nodes that list each other is taught in three documents, while :15 says the guide "points at and does not repeat". Fix: one owner for the commands, a pointer from the others. Owner: guide+guide-other+tour. Decide: which document owns the commands.
- **U2 2, M14** `3` — `guide/deployment.md:178` (§2.2): `-setcookie`, `ps`, "the same on every node of one floor" stand in the guide alone under "(report §12.5)", which was cut; the sentence is some 65 words with an unexplained "the form's version". Fix: the report takes the sentence back, or the guide drops the citation, cut in two. Owner: guide-other+report. Decide: who owns the cookie's details.
- **U2 15** `3` — `guide/deployment.md:329`, `:356`, `:358`: "a reload starts the module's services again beside the old" three times in thirty lines. Fix: keep it in §6.3, and §6.2 points there. Owner: guide-other. Decide: which place keeps it.
- **M12** `3` — `guide/faq.md:9`: "which being the language buys and a library cannot" is asserted; `why.md:167` concedes the first refusal to `gleam/otp`, and the third needs nodes. Fix: drop "and a library cannot", or say which of the three. Owner: guide-other. Decide: whether the claim narrows.

#### The library's names: is any name a user writes renamed, or a missing pair added?

- **P2 5, E1 C1** `3` — E.18 `library.md:765`, `tcp.ern:628`, shape rule 10 (`library.md:232`): `Tcp.address : (String) -> Optional(Bytes)` answers an IP address's bytes, where every other function of `Tcp` takes or answers a process's `Address`. Fix: a name that says an IP address's bytes, `Tcp.parseAddress` or `Tcp.ipBytes`. Owner: report+stdlib. Decide: whether `Tcp.address` is renamed, and to what.
- **P2 31** `3` — E.5 `library.md:385`: `String` and `Bytes` have `drop` and no `take`; `String.take` gives `unknown name String.take` with no help. Fix: both go or both stay; the error names `slice`. Owner: report+stdlib. Decide: whether `take` enters or `drop` goes.
- **P2 33** `3` — E.19 `library.md:774`, principle 1: hexadecimal is `"ff"` in `Bytes.toHex` and `"FF"` in `Int.toStringBase`, `Uri.encode`, `Json.encode`, with a reason the report's writing rule leaves out. Fix: none given. Owner: report+stdlib+libs. Decide: one case, or the split stays without its reason.
- **P2 32** `3` — principle 2, shape rules 2 and 3: text to value and back is `Uri.parse`/`toString`, `Json.parse`/`encode`, `Http.parseDate`/`date`, and `Uri.encode` is percent-encoding; a reader writes `Uri.encode(reference)`. Fix: none given. Owner: libs+report. Decide: one verb pair across the libraries.
- **U1 15** `3` — guide §4.6, §8.4; report §6.10: `Upgrade(next : ...)` keeps a named field whose name told `next` from the removed `migrate`. Fix: none if the name documents; otherwise positional in both, `Upgrade(countTwice)`. Owner: guide+report. Decide: whether `Upgrade`'s one field stays named.
- **N Names (answer, adapted, restarting, monitorService, Process.run)** `3` — names N could not predict: `answer(reply, v)` for `reply`; `adapted` and `restarting`, participles among `spawn`, `send`; `monitorService` for `monitorRestarts`; `Process.run`, saying neither spawn nor wait. Fix: none proposed. Owner: report+stdlib. Decide: whether any of the five is renamed.
- **N Names (Down, Left and Right)** `3` — `Down` and its `site` for `Ended` and `spawnedAt`, Erlang's word; `Left` and `Right` for `Error` and `Ok`, not saying which fails. Fix: none proposed. Owner: report+stdlib. Decide: whether either is renamed.
- **N Names (Io.show, Os.environment, andThen, splitWhile), E3 L1** `3` — `Io.show` writes nothing, beside `Int.toString`; `Os.environment("HOME")` reads as the whole environment; `Optional.andThen` and `Either.andThen` against `List.flatMap`, where guide §2.9 promises one verb per operation; `List.splitWhile` with no `takeWhile`, used with a half dropped at 23 sites, 15 `dropWhile`'s work and 8 `takeWhile`'s, where the log kept `dropWhile` out on 2026-11-07 at 7. Fix: none proposed. Owner: stdlib. Decide: whether any is renamed, and whether `takeWhile` and `dropWhile` enter.
- **N 29** `3` — `:browse OrderedMap` names some first parameters and not others, `OrderedMap.all(OrderedMap.Map(k, v), test : ...)` beside `contains(map : ..., key : k)`. Fix: name each. Owner: stdlib. Decide: whether the library's first parameters are all named.

#### The type rules: does the report's sentence move, or the checker, where what is generalized, a mailbox or a member differs?

- **K 1, K Kept (call)** `3` false — §4.6 `language.md:507`, `:509` against §3.9 `:284`: "Any other binding is not generalized", yet a top-level `let` of an `if`, a block, a `match`, a selection or a record update is generalized by `ern`; `docs/soundness.md:155`, `:201-203` argue "a call's binding". Fix: §4.6 says "no value", and the argument's 6.1 follows. Owner: report+docs. Decide: §4.6's wording, with the argument's paragraph and a cold reading.
- **K Outside :346** `3` false — §3.13 `language.md:346`: "instantiating it with a type that contains a function … is a type error", yet `==` on `Tag((Int) -> Int)` for `type Tag(a) = Tag(Int)` builds, equality going through the fields. Fix: none given. Owner: report. Decide: whether the sentence says "a type whose values hold a function" or the checker refuses.
- **K 4** `3` — §3.9 `language.md:313`, `:323`, §4.5 `:485`, `docs/soundness.md:113`: process-only is written as a function's and `ern` holds it as the variable's; a function that spawns a lambda calling one is `receiving e+` and refuses `: Unit`. Fix: §3.9 says the restriction is the variable's. Owner: report+docs. Decide: the rule's reading, with a cold reading.
- **K 3** `3` — §4.8 `language.md:541`, §4.9 `:559`, §3.5 `:262`, `docs/soundness.md:255`: a member declared at `Vec(Int)` alone is accepted, and what an operator, a requirement or `derives compare` at another instance does is in no section; `derives` reports an annotation nobody wrote. Fix: §4.9 states the whole-type check, §3.5 the derived case, or §4.8 asks the type's own parameters. Owner: report+checker+docs. Decide: which.
- **K 7** `3` — `docs/soundness.md:141`, `:306`: I1 gives every process an expression of type `Unit`, and the compute's step leans on it at `a`; `Process.run` and `Test.faults` start processes at `f`'s type and are absent from the argument. Fix: I1 reads "the type its start gave it, `Unit` for a spawn's", with a sentence for `Process.run`. Owner: docs. Decide: the invariant's restatement.
- **K 6** `3` — E.15 `library.md:613`, §4.6 `language.md:507`, `docs/soundness.md:205`: `Clock.Alarm`'s foreign representation is stated nowhere, E.15 calls it abstract, and the diagnostic names `Foreign.Term`, not `Clock.Alarm`. Fix: E.15 states the representation, and the message names `Clock.Alarm`. Owner: report+checker+docs. Decide: the sentence and the message's text.
- **P1 11** `3` — §3.1 `language.md:226`: the alias rule's second branch refuses `type Failure = Down(String)` and `type Paint = Color(Color)`, which no one reads as an alias, while `Down(String) | Timeout` builds. Fix: refuse only where what is written reads as the type. Owner: report+checker. Decide: whether the branch narrows.
- **P1 12** `3` — §3.11 `language.md:352`, principle 5: the bound-type rule names `Tcp.SocketMsg`, `Tcp.ListenerMsg`, `Os.ProgramMsg`, a table in `ern_bound.erl:30-32`, where `Clock.Alarm` is bound by the general clause through `Foreign.Term`. Fix: the three hold a foreign type, and §3.11 drops the names. Owner: report+checker+stdlib. Decide: whether the names go.
- **P1 13** `3` — principle 5, §4.8, §3.5: in the repository's own Ernest a requirement names `compare` 47 times, `show` 3, operators and `negate` 0, and `derives compare` stands 0 times outside a bench fixture. No fix asked. Owner: report. Decide: whether six of the nine names a requirement takes, and `derives`, stay.

#### Security: is each a mend, a refusal or a stated rule, where another user's file, mode or text reaches a program?

- **E3 D2, S 1** `3` — `uri.ern:333-342`, library.md:1419, 1429: `Uri.toString` writes a reference `parse` did not answer as another one: a path `//evil.example` with no authority reads back as an authority, so `Http.target` plus a `Location` built by `toString` redirects off-site; a first segment with `:` becomes a scheme; a relative path glues onto the host. Fix: fault, or prefix `/.`, `./` or `/`; the report says which. Owner: report+libs. Decide: fault or prefix.
- **S 2** `3` — `markdown.ern`, render: `Markdown.render` passes C0 and C1 controls from a text into terminal rows, so Markdown a program did not write sets a title, clears the screen or writes the clipboard (OSC 52). Fix: write each control as `\u{1B}` but the styles it adds, and G.2 says so. Owner: report+libs. Decide: whether `render` escapes controls and G.2 gains the rule.
- **S 3** `3` — `ern_node.erl:425` `owners_alone/5`, `:443` `found/2`, `shell.ern:592` `isWrittenByOthers`: read, not shown: the checks read mode bits and never the owner, so another user's `0755` directory, `0644` `ernest.conf`, key or `startup` (a link to one) passes. Fix: refuse each not owned by the job's user or root, as sshd's StrictModes. Owner: nodes+shell-ern+report. Decide: whether the owner is checked, and the refusal's text.
- **P3 7** `3` — §11.2.15 `toolchain.md:454`: the shell sets `$HOME/.ernest`, and through a link the directory it reaches, to 700 and says nothing, where every other wrong mode is reported with its `chmod`. Fix: report it and run no startup file, changing no mode. Owner: shell-erl+report. Decide: a security rule, whether the shell changes the mode or reports.
- **S 4** `3` — `ern_fs.erl:371` `temp_dir/1`, `:398` `private/1`: read, not shown: under a umask that lets others write, a directory found `held` is made private and left in the parent with the other's entry, and nothing says so. Fix: `file:del_dir_r(Directory)` before the redraw. Owner: runtime. Decide: whether `makeTempDir` removes what it caught, and E.17 says so.
- **S 5, C4 4** `3` — `ern_build.erl:2892-2905` `make_private_dir/1`, `ern_fs.erl:391-408` `private/1`: two copies of the private-directory mode and listing check answer `held` differently, the builder refusing ("written to by another as it was made"), the runtime redrawing. Fix: `make_private_dir/1` is `file:make_dir/1` then `ern_fs:private/1`, one answer for `held`. Owner: cli+runtime. Decide: refuse or redraw.
- **P3 13** `3` — §11.9 `toolchain.md:699-701`: a manifest's `url` is only printed, yet its form rule refuses every job that reads the manifest, and a tag archive's address. Fix: the rule holds a `url` to `https` alone. Owner: cli+report. Decide: whether the form rule narrows.
- **C2 D4** `3` — `ern_interface.erl:41-43` and `malformed_interface_test`'s comment promise that an interface whose fields are not this build's reads as another build's; a crafted `.erc` with a `back_end` value that is no `#back_end{}` reads `ok` and then crashes the checker. Fix: narrow both comments, or check each `back_end` value in `interface/1`. Owner: checker. Decide: whether the read checks the values, or the comments narrow and the crash stays a known issue.

#### What the guides teach and show a first reader: does each gain, lose or change what it shows?

- **N 14** `3` user — guide §2.1: comments (`//`, `/* */`), `<=`, `>=`, unary minus and precedence are never taught. Fix: three sentences in §2.1. Owner: guide. Decide: whether §2.1 gains them, and what it says of precedence.
- **N 10** `3` user — `README.md:97`, `:111`: installing OTP 29, the hardest step, has no command, only "built from its source ... or a version manager such as kerl". Fix: give the two or three commands. Owner: readme. Decide: whether the README gives the commands, and which.
- **L7** `3` user — `tour/README.md:540`, *Work anywhere*: the page shows `bar` read busy at its connection and `foo` taking all three computes; typed at once both read 0.0 and the work spreads; `Right(8)` is the machine's scheduler count, unnamed. Fix: show the run after the next telling, or say a wait of one interval changes it; name `Right(8)`. Owner: tour. Decide: which run the page shows.
- **N 2, N Leftovers (:browse Prelude)** `3` — `guide/language.md:594` (§2.9): `:browse Prelude` is said to list `Some`, `Left`, `spawn`, `send`; it lists the types and no constructor, and lists `Address.call`, `Address.callForever`, `Io.show` under "without a module's name", which `:browse Address` and `:browse Io` list again. Fix: the guide names `:doc Optional`, or the listing shows constructors. Owner: guide+shell-ern. Decide: guide or listing.
- **N 17** `3` — guide §4.3 to §4.5: "answers" means a function's result and also `answer(reply, v)`, both in one paragraph. Fix: "returns" for a function's result. Owner: guide. Decide: whether the guide's verb for a result changes from the report's.
- **L27** `3` — guide §2.10, §3.5, §4.7, §5.6: the word counter runs beside the counter every other page uses. Fix: none given; the reader asks whether anything still needs it. Owner: guide. Decide: whether the word counter stays.
- **U2 19** `3` — `guide/deployment.md:232`, `:240`, `:254`: October's figures on eight cores are off by two to three and a half times today (130 ms, 2.0 ms, 0.16 ms, 0.6 s). Fix: measure again before the release, or keep them dated and say the machine changed. Owner: guide-other. Decide: whether the figures are measured again.
- **L6** `3` — `guide/why.md:304`: `make bench` is named and no figure of cost against Erlang is given; L measured 788 to 913 ms against 216 to 233 for 200000 spawns. Fix: one measured figure with its machine and day. Owner: guide-other. Decide: whether why.md states a cost figure.

#### Processes, monitors and waits: what does a wait or a monitor promise, and who reaches a process?

- **P1 2** `3` false — §6.5 `language.md:835` against §6.10 `:932`: the list of ways one process reaches another leaves out `Code.running`; `Intruder` sends to a counter whose address it was never given, `Some(41)`. Fix: §6.5 names `Code.running` and says seeing the function grants the permission. Owner: report. Decide: whether `Code.running` stays a way to reach a process, and §6.5 says so, or it narrows.
- **P1 8** `3` — §6.9 `language.md:884`, `:886`, principles 1 and 3: a `monitorService` wrap that sleeps 2000 ms holds the watched service's restart 2001 ms; a monitor touches the monitored. Fix: weigh the narrower promise, `Restarted` unordered with the new run's sends, no wait on a watcher. Owner: report+runtime. Decide: whether the restart stops waiting for a watcher's wrap.
- **P2 10** `3` — E.21 `library.md:808`: `limited` is `true` for a restart's wait "though no time ends its wait for a wrap that does not finish". Read, not shown. Fix: `false` there, or say what bounds the wait. Owner: report+runtime. Decide: which.
- **P1 9** `3` — §6.9 `language.md:888`, principle 3: a helper's `demonitor(p)` ends its caller's `spawnMonitored` monitor, unseen in the call or its type, so `main` waits without end. Fix: `monitor` answers what `demonitor` takes, or §6.9 states the cost. Owner: report+runtime. Decide: whether a monitor gets a value of its own.
- **P2 30** `3` — E.0 `library.md:197`, principles 1 and 3: a second `subscribeFaults` replaces the first unsaid, so two parts of one process cannot both listen. Fix: none given. Owner: report+runtime. Decide: whether a subscription is replaced or added to.
- **P2 18** `3` — G.4 `library.md:1241`: `cpu` "answers `None` too where the service does not answer in time", and the time, 5 seconds, the host's, is not stated, where §0's *Time* asks for one. Fix: state it. Owner: report. Decide: whether the host's 5 s becomes a stated promise.
- **P2 34** `3` — E.18 `library.md:717`, principle 3: `Tcp.close` waits 5005 ms after an unread 30 MB write, up to 3 minutes, with no time at the call. Fix: none given. Owner: report. Decide: whether `Tcp.close` takes a time.

#### The library's promises: does a page or the report state a cost, a failure or a form it now leaves out, or does the code change?

- **P2 4** `3` false — E.17 `library.md:659` against §7.4 `language.md:958`: `Fs.makeTempDir` faults where `TMPDIR` is not UTF-8, though its `Either(Io.Error, Path)` has `NotUtf8`. Fix: answer `Left(NotUtf8(bytes))`, or name the clause of §7.4 that admits the fault. Owner: report+stdlib. Decide: which.
- **P2 27** `3` — §7.4, principle 1: "no room for the failure" follows a result type nothing decides; a base of 37 gives `None` from two functions and a fault from `Int.toStringBase`; `Float.div` and `Float.pow` past range differ. Proposed sentence: a domain the caller writes as a literal faults, data answers `None`. Owner: report+stdlib. Decide: the proposed §7.4 sentence.
- **E1 C8** `3` — library.md `Path.name` (line 591), `path.ern:149-150`: the page and code answer `None` for `Path("")` too; E.14 says only "None for the root". Fix: E.14's line gains "and for `Path("")`". Owner: report. Decide: whether E.14 gains the sentence, where the report is silent.
- **E1 C3** `3` — `path.ern:307-315`, E.14: `Path.isAbsolute` is a foreign function and an atom binding where `Bytes.startsWith` answers alike at the same cost, and the log's reason (2026-11-25:105) cites E.0 rule 1's clause for values the language owns. Fix: write it over `Bytes.startsWith`, E.14's primitive sentence changes, the log's reason corrected. Owner: report+stdlib+log. Decide: whether `isAbsolute` stops being a primitive.
- **E1 D3 (cost)** `3` — `ordered_set.ern`, `ordered_map.ern`: `maximum` is `List.last`, linear (4366 µs at a million against 0 for `minimum`), while the module page says to use an ordered set "where the smallest or the largest is wanted", and "What it costs" omits it. Fix: state the cost and recast the advice, or a representation with a cheap last. Owner: stdlib. Decide: whether `maximum` is stated linear or made cheap.
- **E1 D4** `3` — `string.ern:174-175, 212-223`: `String.endsWith` and `stripSuffix` walk the whole text where it ends with the suffix (1664 µs on 1 MB against 4 for `startsWith`), and no page says so (E.0 shape rule 6). Fix: check the grapheme boundary from the suffix's bytes backwards, or state the linear cost. Owner: stdlib. Decide: the faster code or the stated cost.

#### The release, its measures and its tools: what the release takes on before the tag

- **Z3** `3` — the release's note, nike: OTP 29.1.3 came out on 2026-11-24 and nike runs 29.1.2; a clone under 29.1.3 passed `make test-full` on its second run, the first failing on `reload_waits_on_no_stopped_peer`, item 166's flake; its notes fix none of `docs/otp_bugs.md`'s 28 reports. Fix: none given. Owner: plan. Decided with the user on 2026-11-26: nike moves to 29.1.3 before the fixes' round, and the note names no patch release.
- **C4 The session's question, Z6** `3` — `ern_rt.erl`, `noted_call/4` (86d0dcf5): the call rows rose 6 to 13 percent; `call/4` and `call_forever/4` now build a closure and take one more frame, an estimated 10–20 ns a call (read, not shown), a fifth to a third of `call.txt`'s rise; half the ratio's rise is the host's call falling; `bench.txt`'s excess, `bench.ern`'s reorder (d03a228a). Fix: the reader's A/B runs. Owner: runtime+tests. Decide: whether the closure stays at its measured cost.
- **Z9** `3` — `docs/reviews/release.md`'s first step, `docs/reviews/full.md`: the readers were given `make sizes`, `make clones` and `make slowest` alone and forbidden every `make` target, so `make lengths`, `terms`, `citations`, `unchecked` and `edits` started no reader; the session's own miss. Fix: none given. Owner: docs. Decide: whether `release.md`'s first step makes them too.
- **Z5** `3` — `docs/otp_bugs.md`, report 6 (erlang/otp#12208): its closing invites the issue opened again "if there's a real project that has a module with ~7000 unused functions". Fix: none given. Owner: docs. Decide: whether to answer.
- **C7 defects 3** `3` — `Makefile:704, 717-739`, `coverage`: `CITING_SOURCES` now feeds it `src/stdlib/*.ern src/libs/*/*.ern` whole, so `///` lines and code comments count, against its comment "the number of tests citing it" (§12.8 6 against 2, Appendix G.3 3 against 2). Fix: drop `///` lines before the `grep`. Owner: tests. Decide: whether a doc block's citation, whose examples run as tests, counts as a test citing the section.
- **E3 C5** `3` — `tools/words.ern` `contents` answers `""` for `Io.NotFound`, where `Repository.bytes` and `contents` quit: `sizes` and `clones` exit 1 on a tracked file the tree lacks, `words` exits 0 silent. Fix: one rule in `Repository`. Owner: tests. Decide: quit or skip such a file.

#### Appendix H and what a reference reaches: does a binding's form, a hash's reach or an atom's count change?

- **P3 2** `3` — Appendix H `toolchain.md:1060`: "a reference by hash reaches the one its node loaded first", where §11.2.8 `:368` and §12.7 `:1002` say the latest; the code takes a function from the latest and a type from the first (`ern_code.erl:490-494`). Read, not shown. Fix: H says §11.2 and §12.7 say which unit answers. Owner: report. Decide: H's sentence, with the type's first-loaded rule.
- **P3 12** `3` — Appendix H `toolchain.md:1060`, `:1096`, §11.1 `:111`, §11.2.14 `:438`, §12.7 `:996`: a binding's name travels beside its form, with a reference kind of its own, where functions and types now hold theirs. Read, not shown. Fix: a binding's form holds its name, reference `{hash, Hash}`, the three clauses go. Owner: emitter+runtime+report. Decide: whether 0.11.0's form takes the change.
- **Z2** `3` — the form holds its qualified name (*The Emitter's Lines*), so a reach of N definitions makes N+1 atoms where it made one, a day's spawn 2 where 1, and the days to four fifths of the atom table are 1,969 where 4,029; no sentence of the report or `docs/memory_checks.md` gives a count this breaks. Fix: none given; for the log's entry. Owner: emitter+runtime+log. Decide: whether the cost stands, said in the log.

#### A second way: does it go?

- **P1 4** `3` — principle 2, §5.7 `language.md:677`, `:685`: `x |> f()` and `x |> f` are one thing, `ern format` keeps both, and `x |> Some()` builds where `Some()` is refused elsewhere; `x |> (g(1))` and `x |> { g(1) }` differ. Fix: a filled call with empty parentheses is refused, help writes `x |> f`. Owner: report+checker. Decide: whether `x |> f()` is refused as a second way.
- **U1 17** `3` — `guide/language.md:807` (§3.5): a descending sort taught two ways in one sentence, a reversed sort and a wrapper type (a second way; M24 asks a sort by a function). Fix: the reversed sort for one key, the wrapper only for a key inside a tuple. Owner: guide. Decide: which way the guide teaches, and where.
- **P3 11** `3` — §11.2.3 `toolchain.md:289`, principle 2: a command is selected by a prefix too, a second spelling that only shortens; a startup file's `:r` breaks when a command is added, and settings take no prefix. Fix: a command by its name alone, and the ambiguity refusal goes. Owner: shell-ern+report. Decide: whether prefixes go.

#### A program's modules and namespaces: which modules a build, a node and a session take

- **P1 1, P1 7, P2 29, P3 6, U1 3, U1 25** `3` false user — `language.md:410-414` (§4.2), `toolchain.md:167-171`, `guide/language.md:2068`: `time.ern` builds, then is refused without help once it calls `Http`, at a node's start, or at `:load Http`; `ern shell app.erc` takes it; the guide ties the refusal to a use. Fix: Appendix G's namespaces, or the refusal ends `; give time another name`. Owner: report+cli+shell-erl+guide. Decide: with MVP 4.18's item 6, which; and a session's reach.
- **U1 16, U2 26, L33** `3` user — `guide/language.md:2039-2064` (§7.1): the file-by-file build beside the sources, then the directory build, leaves a tree a node refuses; nothing says the file form and the directory form give two namespaces, met twice by L. Fix: teach the directory build alone, and name the file form once. Owner: guide. Decide: whether §7.1 teaches only the directory build.

#### The shell's keys around `C-c`: mend before the release, which way, or file the corner?

- **E2 1** `3` — `shell.ern:1721-1733, 762-769, 913-920, 1275-1283`: after `C-c` in a `:load`, keys typed are drawn before the session's `Entered`, so the transcript shows `xyz`, not `abc`, as the abandoned line, and an empty `> ` over an editor holding `xyz`; the window spans the compile. Known issue 15 says "once the command has ended". Fix: `Entered` again at `Cancel`, or keys held until drawn. Owner: shell-ern+tests. Decide: mend, which way, or widen the known line.
- **E2 4** `3` — `shell.ern:395-396, 450-454`: read, not shown: `unkeptInterrupts` takes with `after 0` an `Interrupted` the reader sent after its `Prompted` answer, a real `C-c` at the first prompt, while keys typed ahead replay. Fix: `Prompted(Reply(Int))`, the session dropping that many. Owner: shell-ern. Decide: mend it so, or show it first, or file it as a known corner.

#### Alone

- **E3 C7** `3` — 53 sites over the Ernest sources, 33 in E3's part, 11 new: a local shadows its module's top-level function, `let encoded` under `fn encoded` (http.ern:1509), `let written` (uri.ern:739). Fix: rename each, `segments`, `texts`. Owner: guide-other+libs+tests. Decide: whether the style guide refuses such a local, and the 53 are renamed.
- **N 7** `3` — `ern format` breaks a signature inside a type argument, `Either(String,\n Int)`, stable under a second format; no report sentence read says where. Fix: break before the result type, not inside a parameter's type. Owner: front. Decide: the layout rule for a long signature (see feedback 286's staircase).
- **Z7** `3` — `site/templates/shell.html:12`: "It runs in a container of its own, with no network", whatever server serves the page; a server run with no container, as the panel check's was, says it falsely. The page is written for ernest-lang.org, whose server runs the container. Fix: none given. Owner: site. Decide: whether the sentence stays, narrows, or is said only where the server runs one.

### `4`, filed

- **P2 20** `4` — E.0 `library.md:135`: `OrderedSet`, `OrderedMap` and `Random` "enter by name", kept because they were there. Filed: item 6 (MVP 4.18).
- **P2 26** `4` — E.0 `library.md:135`, principle 5: the test of what is a library admits both verdicts for TLS, ECMA-48, JSON, base64, SHA and URIs; a sentence proposed. Filed: item 6 (MVP 4.18), which tries the published-specification test.
- **P2 28** `4` — E.27 `library.md:1091`: `Peer.computeAnywhere`'s draw of two peers is a policy inside the standard library, twelve lines of a program's. Filed: item 6 (MVP 4.18), which asks whether the draw follows the libraries.
- **P1 10 (rule)** `4` — §4.6 `language.md:499`, §4.9 `:563`: a block `let` that binds a lambda is generalized, a second way to a local `fn`, and makes §4.9's refusal; proposed: every block `let` monomorphic. Filed: item 169.
- **E2 17** `4` — 23 sites continue a long string literal with `<>` at run time, two new in `command.ern:64-65, 111-112`. Filed: felt 283.
- **E3 L8** `4` — `examples/fetch.ern`: matches `Io.Other`'s text by its prefix. Filed: felt 285.
- **N 32, E3 L7** `4` — no type alias: `Either(String, Int)` 20 times, `OrderedMap.Map(Formula.Name, Entry)` 11, and `Either(ParseError, #(Expression, List(Token)))` 10 times in `examples/interpreter.ern:256-274`, the new heads 8 lines each. Filed: felt 286.
- **L32** `4` — a call answering an `Optional` has three cases at every site, `Some(Some(v))`, `Some(None)`, `None`. Filed: felt 287.
- **N 30, L30** `4` — `after` reserved everywhere though it stands only in a `receive`: `let #(digits, after)` and `let after = Clock.monotonic()` refused; N names `or`, `as`, `when`, `type` too. Filed: felt 292.
- **U1 21, N 33** `4` — a spawn whose address is unwanted is `let _ = spawn(...)`, 10 sites in the guide, a three-line block in a `Unit` callback; `let _ = Clock.alarm(...)` 4 more. Filed: felt 294.
- **M22 (the wait), S 7** `4` — a wait in a helper reaches its callers' types: a wait on one's own messages in the caller's process takes a `receiving Inbox` helper, a `Process.run` around it and a `Left` arm that can only fault; a helper that monitors declared `receiving Down` on itself and on `main`, the diagnostic clear and the change one line. Filed: felt 303.
- **E1 L1** `4` — `system` 6 times, `callLimited`, `callUnlimited`, `closed`, `timed` and `let global` twice each, 16 declarations for 6 things, and `Fs.asked` a third way. Filed: felt 308 (its count updated).
- **U1 22 (Int.toString)** `4` — a number in a line of output is `Int.toString(...)`, 37 sites in the guide. Filed: felt 309.
- **M23, M6** `4` — a debug print in generic code adds `needs a.show` up the call chain; M6 asks `why.md:399-401` name that cost as the mailbox claim's :171 does. Filed: felt 313.
- **U1 22 (Io.show)** `4` — a value's line is `Io.println(Io.show(...))`, 17 sites in the guide. Filed: felt new.
- **U1 23** `4` — `Process.fromAddress(` at every `kill` and `monitor`, 14 sites, 6 of them `kill(Process.fromAddress(x))`. Filed: felt new.
- **U1 24** `4` — `let me = self();` before a spawn that must reply, 11 sites. Filed: felt new.
- **N 31, M25** `4` — a constructor takes one positional field or all named: `Add(Expr, Expr)` and `Point` refused; the message is good. Filed: felt new.
- **N 34** `4` — no spawn under a service monitor in one step; `spawn(restarting(...))` then `monitorService` leaves the gap `spawnMonitored` closes for `monitor`. Filed: felt new.
- **N 35** `4` — a request with a field beside its reply needs a lambda at every call, 7 times. Filed: felt new.
- **N 36** `4` — nested calls' deadlines staggered by hand, `4 * Cell.patience` and `2 * Cell.patience`. Filed: felt new.
- **N 37** `4` — a `Down` with `Restarted` carries no cause. Filed: felt new.
- **L22, L29** `4` — a `Foreign.Term` has no text: `Io.show` answers `"<foreign>"`, so a printer through `io_lib:format/2` and `iolist_to_binary/1` is two `foreign fn`s. Filed: felt new.
- **L31 (the pattern)** `4` — no pattern on a string's prefix, `"inc " <> rest ->`. Filed: felt new.
- **M24** `4` — no sort by a comparing function; a wrapper type or `List.reverse(List.sort(...))` (see U1 17). Filed: felt new.
- **E1 L2** `4` — a host atom is no §4.6 constant: 4 bindings read through `ern_rt:binding/1` over 7 calls (`bytes.ern:222, 311`, `path.ern:100, 311`). Filed: felt new.
- **E1 L3** `4` — a foreign declaration keeps the host's order, so 12 private host functions swap it: set 5, map 6, list 1. Filed: felt new.
- **E1 L4** `4` — `supervisor.ern:101-104`: a message is bound to its node only by a field that is a function, which nothing in the type shows, 1 site. Filed: felt new.
- **E2 16, E2 18** `4` — `shell.ern:1041-1115`: no library function writes a fault's line as `ern run` does, so the shell rebuilds it (`calleeClause` among 4 new private functions naming no type of the program's own), already drifted (E2 2). Filed: felt new.
- **E3 L2** `4` — `markdown.ern:675, 741, 860-861`: trimming by a predicate written by hand, 3 sites. Filed: felt new.
- **E3 L3** `4` — a byte cannot be compared with an ASCII character literal: 39 lines in uri, base64, json and http, a hex digit's value written twice. Filed: felt new.
- **E3 L4** `4` — `uri.ern:279`: no String from bytes known to be ASCII without a fault arm, 1 site. Filed: felt new.
- **E3 L5** `4` — `documents.ern` `recordOf`: no fold over `Optional` that stops at the first `None`; `List.tryFold` takes `Either`. Filed: felt new.
- **E3 L6** `4` — 740 of 1560 private functions name no type of their program's own, a heuristic count; its candidates are `isSpaceOrTab`, `fourDigits`, `isUnreserved` and the hex digit (E3 L2, L3). Filed: felt new.
- **P1 15, K 10, K Kept (§6.2 tuple)** `4` — §6.2 `language.md:795`: a function inside a tuple's value closes at `Never` where the same function by name keeps its variable; the error names `Never`, the paragraph no reason; the widening was weighed and left 2026-11-24. Filed: known "A mismatch at a mailbox type that §6.2 made `Never`".
- **P2 3** `4` — shape rule 8 `library.md:224`: `Code.load`, `Code.hashes`, `Tcp.listenTls` and `Tcp.listen`'s lookup wait on a file's device or a resolver and take no milliseconds, unsaid; the wait read, not shown. The known line names two; the other two join it. Filed: known "`Code.hashes` and `Tcp.listenTls` read a file with no bound".
- **C5 defects 3** `4` — `ern_shell.erl:3841, 3885`, `source_hash/2` (:4996): a changed source made unreadable (`chmod 000`) gives "no source has changed" and no start line, where `ern build` refuses it and §11.2.8 has `:reload` compile where `ern build` would; met only on purpose. Filed: known new.
- **C1 5 (the variable)** `4` — `ern_parser.erl:513-517`: "expected `.` after a instead of `=`" writes the variable plain. Filed: dropped: §11.5 (toolchain.md:568) writes "a name the program declares or binds … plain", as this one is.
- **Z4** `4` — `docs/otp_bugs.md`: the OTP reports' first lines, report 6 closed as one OTP will not fix, contributors' fixes open for reports 5 and 16, OTP's own for report 10 still open. Filed: dropped: made in 936b34f3.

### `5`, dropped: a matter of clarity

- **P1 20 (rest)** `5` — §9.4 and §9.5, §6.7, `language.md:658`: two lists of the prelude's functions that no rule tells apart; §6.7, a section of pointers with a glossary entry, "remote computation"; "operations record", a named term with no rule of its own. Read, not shown. Asked: whether each earns its place, kept from an earlier milestone. Owner: report.
- **K Kept (T.compare notation)** `5` — §4.3 `language.md:336`, `:340`, `docs/soundness.md:249`: `<` and `compare` are defined by `T.compare(a, b)`, an expression §4.5 makes an error to write. Asked: whether the report defines them by a form a program cannot write. Owner: report+docs.
- **L15** `5` — `guide/language.md:860-870`, `:945` (§4.1, §4.4): where L would close the guide: four marks on a type variable, three bullets on what fixes `n`. Asked: nothing; it is where typed Erlangs lost the reader. Owner: guide.
- **L14** `5` — `guide/language.md:1509` against `:1526`: "the address keeps nothing alive here" and "the process the runtime keeps for the address" read as disagreeing. Asked: the two reconciled. Owner: guide.
- **L13** `5` — `guide/language.md:1980`, `:1986`: tripped on a sibling that never waits keeping a child down and `faulted, restarted` before the limit; both shown true. Asked: nothing; the two read as false until run. Owner: guide.
- **M Does the mailbox..., M Is a requirement convincing** `5` — M's answers: the type buys the build-time refusal and the bound spawn, selective receive gets one clause; a requirement reads as a dictionary passed unseen ("the member it was given goes along", `guide/language.md:2220`), and M did not believe "nothing is invisible" at `sorted([3, 1, 2])`. Asked: nothing explicit. Owner: guide.
- **L11** `5` — `guide/language.md:3459`: a `Down` has no order with the last message, where Erlang's comes after; L's probe gave the result first 20000 times. Asked: a run that shows the difference. Owner: guide.
- **N 16 (:592, :2064), L17** `5` — sentences read three times: `guide/language.md:592` (E.0's rule 2), `:2064` (a program becomes a package); `guide/why.md:17` (`sys` and the release), `:25` ("the same floor" before a floor is anything). Asked: each said plainly. Owner: guide+guide-other.
- **M17** `5` — parts long for what they show: `Bag` (`guide/language.md:2398-2430`), §8.2 from *A loss* (:2839-2861), `why.md:248-304`, `faq.md:121`, and the headings of §4.5 and §5.5. Asked: shorter parts, headings that name what they hold. Owner: guide+guide-other.
- **L20** `5` — `guide/deployment.md:97`: a reload the node refuses exits 0, which tripped L; report toolchain §11.2 says the status is the signal's. Asked: nothing beyond the trip. Owner: guide-other.
- **L28** `5` — `guide/deployment.md:226`: `measures` and the `Utilization` library are named only there, and no program reads them. Asked: whether they need a program or a pointer. Owner: guide-other.
- **U2 16** `5` — `guide/deployment.md` §6.1 to §6.3, §8: a service is moved three ways, `:reload` at an attached prompt, the tool, and `Code.load`, and nothing says when to take which. Asked: one sentence in §6.3 that orders them. Owner: guide-other.
- **L25** `5` — questions left open: where data lives across restarts, with no Mnesia or `dets` named, and whether a release carries its own runtime. Asked: answers in the questions. Owner: guide-other.
- **L9** `5` — `guide/why.md:214`: "A deadlock of the whole program is found" shrinks on reading, since a node finds none. Asked: nothing; disclosed and convincing in tests. Owner: guide-other.
- **L10** `5` — `guide/why.md`, *Built for a WAN*: the 45 to 75 s window, the 84.9 s loss and a call answering only at the wait's end restate the host's `net_ticktime`. Asked: nothing; the deadlines against a silent peer convinced. Owner: guide-other.
- **L24** `5` — L's table of what Erlang cannot do and what each page restates. Asked: nothing. Owner: guide-other+readme.
- **N 12, L16** `5` — `README.md:13`, `:16`, `:51`, `:55`, `:78`, `guide/why.md:139-169`: claims open on what Erlang lacks, with Erlang's words unexplained (cookie, epmd, mesh, behaviors), and comparison paragraphs on Gleam's `Subject` for another reader. Asked: say what Ernest does first, and gloss or drop the words. Owner: readme+guide-other.
- **L5** `5` — `README.md:16`: the second claim, a module not held to two versions, is shown nowhere; the tour kills the old process at chapter 4's reload. Asked: one sentence at chapter 4's reload, before the `kill`. Owner: readme+tour.
- **L12** `5` — `README.md:51`, `tour/README.md:146`: "the `Get` may reach `foo` before the `Inc`" never showed in 150 runs. Asked: nothing; read and not shown. Owner: readme+tour.
- **M4** `5` — `README.md:57-65`, `guide/why.md:143-165`, `tour/README.md:65-69`: the headline claim is shown by one toy three times, its costs in more places. Asked: one refusal from a larger program, a helper that receives called from a server's clause. Owner: readme+guide-other+tour.
- **L23** `5` — where L would close each page: README :78, `why.md`'s *Abstract types and requirements* (130 of 435 lines), the FAQ's Emerald paragraph; slowed at `tour/README.md:371`. Asked: nothing. Owner: readme+guide-other+tour.
- **L8** `5` — `tour/README.md:634`: the tour's "peak", an attached shell's fix, is the scene Erlang is nearest to, and holds only unsupervised; chapters 2 and 7 are what Erlang cannot do. Asked: nothing explicit. Owner: tour.

## The lists

### Z

The session's own findings, which no reader's list carries, and the machines' figures.

**The machines.** A fresh clone of `6c6b8ef1` on nike: `make` in 10 seconds and `make test-full` green in 423, alone on the machine. `make slowest` in 395 seconds, `make sanitize` green in 378, `make load` flat in 61, all seven loads, `make service` green in 6 under systemd, launchd's checks waiting for a Mac, `make sections` empty, and `make test-browser` green three times of three, 23 seconds each.

**The panel against a real shell** passed its five steps, on ernest-httpd at `b297777` running the clone's `ern shell`: a session started from the shell's page and from Try it, a block pasted and loaded, a transcript's input pasted, Stop and Restart, and the warning with Extend and the expiry (`lists/panel.md`, `panel/`). Not checked: that the shell's page shows no notice at an expiry, a takeover by a second tab, and *unavailable*.

**The bench.** `make bench` three times, 479, 465 and 466 seconds, the machine idle. Against the idle run of 2026-11-22 (`bench/ref/`), 259 rows compared, 20 medians more than a fifth worse (`bench/compare.py`). Two are real and follow from decisions, Z1 and Z2. The rest lie within their own ranges: the foreign call's rows of 6 or 10.5 ns, both days' ranges 5.9 to 11.0; a persistent term put and erased, 2.5 to 4.5 ns in a range of 2.0 to 11; the burst of 25,000 processes; `Address.call` with eight callers over one callee, 687 to 870 ns in a range of 686 to 1,026; and `Code.load` of twenty definitions, whose three runs read 6,643, 5,859 and 3,841 µs.

1. **Z1, the bench's `Float.*, *` row measures `Int.toFloat`.** The row went from 1.24 to 2.92 times the host's, 17.9 to 40.9 ns. It is `Float.truncate(Int.toFloat(index) * 1.5)` (`test/fixtures/bench/bench.ern:111`), and `Int.toFloat` compares against its bound since *The Libraries' Build*, the bound a computed `let` read at each call, feedback 283. Fix: the row multiplies a `Float` it does not convert in its loop, and `Int.toFloat` gets a row of its own beside the host's `float/1`.
2. **Z2, a reach of N definitions makes N+1 atoms, where it made one.** `a reach of 1, 5, 20, atoms` read 3, 6 and 21 where each read 1, `a day's spawn, atoms` 2 where 1, and the days to four fifths of the atom table 1,969 where 4,029. An arriving function is named by the atom its form's decoding made, since the form holds its qualified name (*The Emitter's Lines*). No sentence of the report or of `docs/memory_checks.md` gives a count that this breaks. For the log's entry, and for the user to know.
3. **Z3, OTP 29.1.3 came out on 2026-11-24, and nike runs 29.1.2.** Built from its source into a scratch prefix, and a second clone built and tested under it: `make` in 10 seconds; `make test-full` failed once, on `reload_waits_on_no_stopped_peer` alone, the flake MVP 4.5's item 166 holds, with the assertion that item quotes; `make test-nodes` alone passed three times of three, 125 seconds each; and a second `make test-full` exited 0 in 393 seconds. Its notes fix none of the 28 reports of `docs/otp_bugs.md` (`otp.md`). To decide: whether the release's note names the patch release it ran on, and whether nike moves to 29.1.3 before the tag.
4. **Z4, the OTP reports' first lines**, made in `936b34f3`: report 6 closed as one OTP will not fix, contributors' fixes open for reports 5 and 16, and OTP's own for report 10 still open.
5. **Z5, report 6's closing invites the issue opened again** "if there's a real project that has a module with ~7000 unused functions". Whether to answer is the user's.
6. **Z6, the call rows rose 6 to 13 percent**, answered at the head of C4's list.
7. **Z7, the site's page of the shell says "It runs in a container of its own, with no network"** (`site/templates/shell.html:12`) whatever server serves it. A server run with no container, as the panel check's was, says it falsely. The page is written for ernest-lang.org, whose server runs the container.
8. **Z8, E1's defect 2 and C4's leftovers disagree on `ern_set`.** C4 read that the host makes a version 2 set only when asked. The session ran it on OTP 29.1.2: `sets:new()` answers `#{}` and `sets:from_list([1,2])` answers `#{1 => [],2 => []}`. E1 is right.
9. **Z9, the readers were given three listings and `docs/reviews/full.md` names more.** The session made `make sizes`, `make clones` and `make slowest`, which `release.md`'s first step names, and forbade the readers every `make` target, so `make lengths`, `make terms`, `make citations`, `make unchecked` and `make edits` started no reader. The session's own miss. To decide: whether `release.md`'s first step makes them too.
10. **Z10, three findings were met by three readers or more**, which the sort joins: the guide's §2.3 sentence on a constructor named `Set` (M 1, N 1, U1 1); the README's "no cookie" (M 3, L 1); and a program's `time.ern` refused only once it is a node or a session loads `Http` (P1 1 and 7, P2 29, P3 6, U1 3 and 25).
11. **Z11, ernest-httpd meets E3's defect 1 on every request for a file.** Its session ran `Http.parseDate("Sun, 06 Nov -001 08:49:37 GMT")` on the archive of `ab68ef61`: it faults with `the time is before the year 0`, through `Http.date` and `Http.readDate`. That server reads `If-Modified-Since` with it, so a client that sends such a date ends its own connection without a response. It is a line of that repository's known issues until 0.11.0's message answers it. The line is a server's security, which MVP 4.18's item 1 sorts, and it is mended for 0.11.0.

### P1

**Findings: 3 defects, 12 principle findings, 6 matters of clarity.** Counts and the list of programs follow the findings.

What I read: `report/language.md` whole at `6c6b8ef1`. The file holds §0 to §9 and Appendices A, B and F, so that is my part; §10 and Appendices C and D are in the other two files. I did not run `make terms` or `make citations`, since the brief forbids `make` in the clone and gave no listing of either. Log searches are named where I made them.

Principle 4 has no finding. Appendix A has 54 productions, and `git diff v0.10.0 6c6b8ef1 -- report/language.md` changes none of them. Every later-token decision I found is named in Appendix A's prose, §2.4 or §3. Probes `g01` to `g18` behaved as the grammar says.

#### Defects

**1. §4.2 (lines 412 to 414) with §11.2: a session takes at its start a module that its own `:load` refuses.**
- Quote: "a session's is every library and every named package on its load path".
- Program: `readers/P1/t4/time.ern` and `app.ern` beside it, where `App.main` prints `Time.now()`.
- `ern run app.erc` prints `it is noon`.
- `ern run --config-dir conf app.erc` prints `ern run: time.erc: Time hides the library Time, which the library Http uses`, as §4.2 says.
- `ern shell app.erc` prints `it is noon`, and `Time.now()` answers `"noon" : String`. Then `:load Http` answers `time.erc: Time hides the library Time, which the library Http uses`.
- `ern shell` with no file, then `:load App`, answers `time.ern: Time hides the library Time, which the library Http uses`.
- Wrong: one session gives two answers for one module, by the entrance. After the first, that session can never load `Http`.
- A reader predicts one reach for a session, so the file given at the start is refused as `:load` refuses it.
- Fix: `ern shell file.erc` refuses by the session's reach; or §4.2 says a file given at the start is taken by a run's reach.

**2. §6.5 (line 835) against §6.10 (line 932): `Code.running` is a way to reach a process that §6.5's list leaves out.**
- Quote: "There is no registry of a node's own processes. A process reaches another through an address it holds or received, through a top-level binding that holds one, which is a *service*, or, from another node, through the name the service is offered under".
- §6.10 says `Code.running(f)` "lists the addresses of the processes running a function".
- Program: `readers/P1/t2/counter.ern` and `intruder.ern`. `Counter.start` spawns a counter and gives its address to no one. `Intruder.main` sends it `Inc(41)` and calls `Get`, both through `Code.running(Counter.count)`.
- Output: `Some(41)`.
- Wrong: the list is incomplete. §6.5 says "An address is the permission to send to a process", and exporting the function a process runs grants that permission to every module. No sentence says so, where §6.5 says it of a service binding.
- Fix: §6.5 names `Code.running` among the ways and says that seeing the function grants the permission.

**3. §3.9 (line 292), §0 principle 3: the help for a recursive group names a fix that cannot be written.**
- Quote: "with a help line naming the fix: the type named at those parameters".
- Program: `readers/P1/t1/forest.ern`, the report's own refused pair, `type Tree(a) = Leaf(a) | Node(Forest)` with `type Forest = Trees(List(Tree(Int)))`.
- Output: `Forest is named at () in the fields of Tree, and a type of a recursive group is named in its fields at the declaring type's parameters, each in its place, (a)`, with `help: name Forest at the declaring type's parameters, each in its place`.
- Wrong: `Forest(a)` cannot be written, since `Forest` takes no parameter. Line 290's new clause has the real fix, "the types of a group take the same parameters". `group.ern` beside it shows the same for `Config` and `Node(a)`.
- For `Nest(List(a))` the help is right: ``write `Nest(a)`, or `List(Nest(a))` to hold it in a List`` (`nest.ern`).
- Fix: where the two types differ in their parameters, the help says to give the group's types the same parameters.

#### Principle findings

**4. Principle 2, §5.7 (lines 677, 685) with Appendix A (line 1343): `x |> f()` and `x |> f` are one thing, and `x |> Some()` builds.**
- Quote: "A construction is such a value and no call (Appendix A), so the pipe does not fill it".
- Program: `readers/P1/t1/pipe.ern` binds `5 |> Some()`, `5 |> f()`, `5 |> f` and `5 |> { g(1) }`.
- Output: `#(Some(5), 6, 6, 6)`.
- `ern format` keeps both `5 |> f()` and `5 |> f` (`pipefmt.ern`).
- `Some()` alone is refused, `Some takes 1 argument, not 0` (`t3/g01.ern`). `1 |> Some(2)` is refused, ``a construction is a value, not a call, and `|>` does not fill it`` (`t3/g05.ern`).
- A reader predicts one spelling for piping into a function of one parameter, and `x |> Some()` refused as `Some()` is everywhere else.
- Beside it: `x |> (g(1))` is `g(x, 1)` and `x |> { g(1) }` is `g(1)(x)`. Parentheses and a block of one expression differ here and nowhere else.
- Fix: a filled call with empty parentheses is refused, with the help that writes `x |> f`.

**5. Principle 5 against §9.3 (lines 1194, 1201): a program names `Unreachable` and `Restarted` though it uses neither nodes nor service monitors.**
- Quotes: "A feature costs a program that does not use it nothing: no argument, no word, and no name of it is written there" and "a `match` on a `Reason` covers it as any constructor".
- Program: `readers/P1/t1/reason.ern` matches `Returned`, `Killed`, `ProgramEnd`, `Fault` and `Unknown`.
- Output: `match on Reason is not exhaustive; missing Unreachable and Restarted`.
- The diff touches both sentences only by a trim. I give it because the two stand against each other as written.
- Fix: principle 5 states the departure; or `monitorService`'s wrap takes a type of its own that carries `Restarted`.

**6. §9 (line 1153), principle 5: five prelude functions are given their meaning by a `foreign fn`.**
- Quote: "a function enters it where no declaration, a `foreign fn` among them, could give it its meaning".
- Programs: `readers/P1/t2/mykill.ern` declares `kill` and `demonitor` over `ern_rt:kill/1` and `ern_rt:demonitor/1`. `myfault.ern` beside it declares `fault`, `answer` and `adapted` the same way.
- Output of the first: `first: Killed`, then `second: no Down, the monitor was ended`.
- Output of the second: `Some(42)`, then `Fault("stopped by a foreign fn")`, then `Fault("42")`. The one difference seen is a frame `Myfault.stop:3` in the trace.
- This release moved `Reply.process` to `Process.fromReply` and took `Io.debug` out of §9. `kill : (Process) -> Unit` and `demonitor : (Process) -> Unit` are of that kind, and principle 5 puts a function "in the module of the type a reader looks in", which is `Process`.
- Not tried: `self`, `send`, `spawn`, `spawnMonitored`, `monitor`, `monitorService`, `restarting`.
- Fix: move those a declaration gives to their type's module; or §9's sentence says what keeps them.

**7. §4.2 (lines 410 to 414), principle 1: a library's namespace "is not taken", and the program that takes one is refused the day it becomes a node.**
- Quote: "a program's `time.ern` that `ern build` and `ern run` take is refused at a node's start, since `Http` uses `Time`".
- Shown by finding 1's program and output.
- A reader predicts that a program `ern run` takes also runs with `--config-dir`.
- What the rule buys: eleven names, `Ansi`, `Base64`, `Crypto`, `Ets`, `Http`, `Json`, `Markdown`, `Proxy`, `Time`, `Uri` and `Utilization`.
- What it costs: three paragraphs, two help lines, three kinds of reach, and finding 1.
- Fix: the libraries' namespaces are taken, as the standard library's are.

**8. §6.9 (lines 884, 886), principles 1 and 3: a watcher's wrap holds up the watched process's restart.**
- Quote: "so a wrap that does not finish holds up that restart".
- Program: `readers/P1/t2/stall.ern`. A `restarting` service faults, and the program measures until it answers a call again.
- Output: with no watcher, `the service answers again after 51 ms`. With a `monitorService` whose wrap sleeps 2000 ms, `the service answers again after 2001 ms`.
- A reader who knows processes as Erlang has them predicts that a monitor never touches the monitored. The service's text shows nothing, and any holder of its address can do it through `Process.fromAddress`.
- Line 886 extends the wait to a peer's answer. That part is read and not shown.
- What it buys: `Restarted` reaches the watcher before anything the new run sends.
- Fix: weigh the narrower promise, that `Restarted` has no order with what the new run sends and the restart waits for no watcher.

**9. §6.9 (line 888), principle 3: a helper's `demonitor(p)` ends its caller's monitor.**
- Quote: "ends every monitor the caller holds on `p`, whichever function of the process asked for them".
- Program: `readers/P1/t2/scoped.ern`. `main` starts a worker with `spawnMonitored`. A helper `ask` monitors the worker while it waits for one answer, then calls `demonitor`. `main` then kills the worker.
- Output: `asked: 42`, then `main's own monitor, made by spawnMonitored, says nothing`.
- Neither the call of `ask` nor its type shows it, and `main` would wait without end for a `Down`.
- What the rule buys: no value for a monitor, one concept fewer. What it costs: a watch scoped to one function cannot be written safely.
- Fix: `monitor` answers what `demonitor` takes; or §6.9 states this cost beside the rule.

**10. §4.6 (line 499) with §3.9, §4.8, §4.9 (line 563) and §5.5: a block `let` that binds a lambda is a second way to a local `fn`, and it makes §4.9's refusal.**
- Quote: "A lambda a `let` binds is generalized before a call ties its own variables to the signature's".
- Programs: `readers/P1/t3/r01.ern`, `r02.ern` and `r03.ern`, under `needs a.compare`.
- `List.map(lists, fn(xs) = OrderedSet.fromList(xs))` builds and runs.
- The same lambda named first, `let build = fn(xs) = OrderedSet.fromList(xs)`, is refused: `OrderedSet.fromList needs b.compare, at the b of List(b), a type variable no requirement can name`, with `help: annotate the value where it is bound`. The help names no value; what is annotated is the lambda's parameter.
- A reader predicts that naming a lambda changes nothing, since every other block `let` is monomorphic.
- Without the rule, a clause goes from each of five sections, and nothing is lost: `fn` in a block is the polymorphic local function.
- The log decided it in *A Lambda Bound by `let` Is Generalized*, 2026-09-29, before requirements existed.
- Fix: a block `let` is monomorphic, a lambda's too.

**11. §3.1 (line 226): the alias rule's second branch refuses types that no one could read as an alias.**
- Quote: "Elsewhere, `type Failure = Down(String)`, the help is `rename the constructor; Down is the prelude's type`".
- Programs under `readers/P1/t1/`: `alias.ern`, `alias2.ern`, `alias3.ern`, `alias4.ern`.
- `type Paint = Color(Color)` beside `type Color = Red | Green` is refused: `constructor Color is named as the type Color`.
- `type Failure = Down(String)` and `type Failure = Down(why : String)` are refused.
- `type Failure = Down(String) | Timeout` builds and runs.
- A reader predicts all four build, since §4.2 lets a module take a prelude name and the same paragraph says so of `Up | Down | Idle`.
- The branch buys nothing: `Down` takes no parameter, so one field after it reads as no alias.
- Fix: refuse only where what is written reads as the type.

**12. §3.11 (line 352), principle 5: the language's rule for a bound type names three library types.**
- Quote: "the message types of the three, `Tcp.SocketMsg`, `Tcp.ListenerMsg` and `Os.ProgramMsg`, are bound themselves".
- The checker holds them in a table of names, `src/toolchain/checker/ern_bound.erl` lines 30 to 32.
- Programs: `readers/P1/t3/b01.ern`, `b02.ern`, `b03.ern`.
- A program's own message type with a field of `Foreign.Term` is bound by the general clause: `which is bound to its node, since it holds an address whose message type holds a value of the foreign type Foreign.Term`.
- `Address(Tcp.SocketMsg)` is bound by name: `since it holds the address of a socket`.
- Principle 5 says "No rule of the language exists for the runtime's or a library's convenience".
- `Clock.Alarm` is `Alarm(Foreign.Term)` in `clock.ern`, so the general clause binds it already and §3.11 says it twice.
- Fix: the three message types hold a foreign type, as `Clock.Alarm` does, and §3.11 drops the names.

**13. What two rules buy, by what the repository's own Ernest asks of them.**
- Principle 5 says a count decides nothing, so this is given as what each rule buys. Read and counted; no defect shown.
- Counted with `/usr/bin/grep` over every `.ern` under `src`, `tools` and `examples`.
- A requirement names `compare` 47 times, `show` 3 times, and an operator or `negate` 0 times.
- `derives compare` stands 0 times there, and once in `test/fixtures/bench/language.ern`.
- Members of a declared type: two, `Keyed.compare` in `list.ern` and `Counts.+` in `examples/wc.ern`.
- `needs a.+` buys generic arithmetic, which has no literal or zero to start from; §4.8 says "there is no numeric type to generalize over". `readers/P1/t3/r05.ern` writes a sum both ways, and each takes the zero as a parameter.
- `derives` buys a `compare` not written by hand. It holds a word read by position, a clause of the grammar, a paragraph of §3.5, a clause of §4.9 and one of §8.7's hash.
- Fix: none asked; the user weighs whether six of the nine names a requirement takes, and `derives`, stay.

**14. §6.2 (line 787, new) with §6.5, principle 3: a `send` to an adapted address runs another's function in the sender and waits for it.**
- Quote: "To an adapted address made on the sender's node it first applies the address's function, in the sender (§6.5), and returns when that has returned."
- Program: `readers/P1/t2/slow.ern` sends to two values of `Address(Int)`.
- Output: `send returned after 0 ms`, then `send returned after 1501 ms`.
- The line shows a send. Neither the line nor the type shows that it runs code, that what the code opens is the sender's, or that it may not return. A reader who knows Erlang predicts that a send never waits.
- The rule is §6.5's and older than the diff. It now stands three times, at lines 787, 819 and 823.
- Fix: one statement in §6.5, and §6.2 points to it.

**15. §6.2 (line 795): a function written inside a value loses the variable that the same function keeps by its name. Known.**
- Quote: "One that only a function inside a value the definition answers holds, a tuple's, a list's or a constructor's, is unfixed."
- Program: `readers/P1/t3/starters.ern`. `#(start, "…")` works. `#(fn(f) = spawn(f), "…")` is refused at its first use: `expected () -> Unit receiving Never, found () -> Unit receiving Int`, with `help: the types differ at Never and Int`.
- `docs/known_issues.md` holds the mismatch's text. The log of 2026-11-24 says the sentence was "made true of what is built" and the widening "weighed and left".
- I name it as a rule that states the checker's reach and no principle.
- Fix: none beyond the known issue's.

#### Matters of clarity

**16. "primitive" has three senses, and principle 5 counts primitives.**
- §0 line 66: "A function that is no value is a primitive". The sentence before it says a member is no value, so by the letter every member is one. §3.11 line 364: "These five are primitives (§0)".
- §3.9 line 321: "the prelude's types and primitives in §9", the functions of §9.
- §9.6 line 1255: "The operator is the primitive". Glossary line 1554: "an operation beneath what Ernest writes". E.0 rule 1 means the shims, which are values.
- Appendix E line 129 calls the five of §3.11 "forms", and the glossary's new entry for form says the same.
- The count is 5, 16, or every shim, by the sense.
- Fix: one sense for primitive, the operation beneath; §0 and §3.11 call the five forms.

**17. "reach" means two things in the changed text.**
- §8.7 line 1090: "A definition's *reach* is the definition with everything it references".
- §4.2 lines 412 to 414, new: "A job's reach is the modules it is given and each module they depend on".
- The glossary's entry holds both and cites §8.7 alone.
- Fix: §4.2 uses its own words, "the modules a job takes".

**18. The rule that makes a mailbox variable none is said three times, with one example five times.**
- The rule stands at lines 317, 485 and 771, and is used at 298.
- `kill(Process.fromAddress(self()))` stands at lines 317, 485 twice, 487 and 771.
- Appendix E.21 says "`Process.current()` is the short form of `Process.fromAddress(self())`", and `fn f() : Unit = kill(Process.current())` builds with no such rule (`readers/P1/t1/proc.ern`).
- What the rule buys beyond it is a watcher whose wrap faults: `fn watcher(p : Process) = monitor(p, fn(d) = fault("…"))` has the type `(Process) -> Unit` (`t3/unfixed2.ern`, by `:type`).
- Fix: state it once in §3.9 with the `monitor` example; §4.5 and §6.1 point.

**19. Principle 2's second paragraph (line 48) is now a list of the forms admitted.**
- It holds seven tests, each met by one form: nesting, a repeated body, a rebuilt value, the fill, the pun, and the two added in this diff, "a member no caller chooses, a monitor from the process's start".
- It also says "one that only shortens stays out", and the pun only shortens: `P(x = x, y = y)` and `P(=x, =y)` both build and `ern format` keeps both (`readers/P1/t1/punfmt.ern`).
- A list of what entered decides nothing for the next form.
- Fix: say that it lists the second spellings admitted; or cut it to the tests that decide.

**20. Kept from an earlier milestone, or kept because nothing broke.** Read and not shown, but for the last two.
- §9.7 states an absence, "The prelude binds no system reference", from when the prelude bound them.
- §8.2 names *system reference* and *system module*, with three glossary entries. No program can name either; what a program meets is one sentence, that `Io.println` on a peer writes to the peer's output.
- §9 line 1153 ends "`Address.call` and `Address.callForever` are the runtime's, as the process functions of §9.4 and §9.5 are", and §9.5 lists both.
- §9.4, "Built-in functions", and §9.5, "Process functions", are two lists that no rule tells apart.
- §6.7 is one sentence of pointers, with a glossary entry, "remote computation", for a section that states no rule.
- "operations record" (line 658) is a named term with no rule of its own; the rule is the fill's.
- The checker's table of three names (finding 12) and §6.2's narrow rule (finding 15).
- Fix: head §9.7 as unused; cut §9's sentence on `Address.call`; fold the two glossary terms of §8.2 into "system process".

**21. Three smaller ones.**
- §5.3 line 636: "the longest `Expr` at the same nesting level (Appendix A)". Appendix A says nothing of a nesting level, and the list of delimiters that said where a body ends is gone. Fix: drop the pointer or the phrase.
- §7.4 line 964 ends "A function that receives nothing can fault.", in the paragraph on corrected values. Fix: move it to §7.3.
- §3.9 line 296 opens "A function that receives nothing stands wherever a function of the same type receiving `M` is expected", and the paragraph then narrows it. In `readers/P1/t3/e01.ern`, `One(step)` builds and `Run(steps)`, a list of such functions, is refused with `(a function that receives nothing and one that receives do not match)` and no help. Fix: the first sentence says "as an expression's own type", and the error names what to write.

#### Counts

| What | Now | Last, at `93a13b13` | How counted |
|---|---|---|---|
| Reserved words | 18 | 18 | §2.4's table, against the lexer's `?RESERVED`, 16, with `true` and `false` |
| Words read by position | 16 | 16 | `needs`, `derives`, `compare`, `negate`, `show` of §2.4, and `BitSpec`'s 11 |
| Taken top-level namespaces | **30** | 31 | the 27 files of `src/stdlib`, with `Prelude`, `Address` and `Ernest` |
| Prelude types | 21 | 21 | 10 in §9.1, 3 in §9.2, 8 in §9.3 |
| Prelude functions | **16** | 18 | 4 in §9.4 with `Io.show`, 9 in §9.5, `fault` and `compare` in §9.6 |
| Prelude members | 23 | 23 | §9.6: 10 operators, 2 `negate`, 3 more `<>`, 8 `compare` |

- **Taken namespaces moved from 31 to 30.** `Reply` went when `Reply.process` became `Process.fromReply`. Shown: `reply.ern` at the source root builds, `down.ern` builds, and `address.ern`, `prelude.ern` and `ernest.ern` are refused, all under `readers/P1/ns/`.
- **Prelude functions moved from 18 to 16.** `Io.debug` and `Reply.process` left §9.
- The standard library's and the libraries' counts are `library.md`'s. I checked only the two my part's rules rest on: 27 modules and 11 libraries, both unmoved.
- Three more that my part holds, counted the same way at each commit:
  - Appendix A has 54 productions, as at `v0.10.0` and at `93a13b13`.
  - Appendix F has 195 entries, against 187 at `93a13b13` and 179 at `v0.10.0`. Since `93a13b13` it gained chain, effect variable, find, foreign code, form, host, process a session started, process of the shell's own, resource, service binding and wrap, and lost authority, percent-encoding and URI reference.
  - §3.11 names five functions that are no values, as before, with `Peer.computeAt` now `Peer.computeAnywhere`.

#### Programs

All under `readers/P1/`. No process of mine is left running.

- `ns/`: `reply.ern`, `address.ern`, `down.ern`, `prelude.ern`, `ernest.ern`
- `t1/`: `pipe.ern`, `pipefmt.ern`, `alias.ern`, `alias2.ern`, `alias3.ern`, `alias4.ern`, `reason.ern`, `group.ern`, `nest.ern`, `forest.ern`, `showreq.ern`, `proc.ern`, `local.ern`, `punfmt.ern`
- `t2/`: `slow.ern`, `counter.ern`, `intruder.ern`, `mykill.ern`, `myfault.ern`, `stall.ern`, `scoped.ern`, `seteq.ern`
- `t3/`: `g01.ern` to `g18.ern`, `e01.ern` to `e03.ern`, `m01.ern` to `m06.ern`, `r01.ern` to `r05.ern`, `b01.ern` to `b03.ern`, `unfixed.ern`, `unfixed2.ern`, `starters.ern`
- `t4/`: `time.ern`, `app.ern`, `app_test.ern`, and the configuration directory `conf`
- `t5/`: `q01.ern` to `q10.ern`, ten quoted messages of the changed paragraphs, each of which printed as the report quotes it
- `worddiff.txt` and `changed_lines.txt`, the word diff of `report/language.md` since `v0.10.0` and the changed lines' numbers

`seteq.ern` found nothing: ordered sets and maps of the same elements built in different orders are `==`. `showreq.ern` and `local.ern` behaved as the report says, and I give no finding from them. `app_test.ern` did not build, by my own mistake in a type's name, and I did not go back to it.

### P2

Findings: 12 defects (1 to 12), 7 matters of clarity (13 to 19), 6 things kept for a reason a later rule removed (20 to 25), 10 under principles (26 to 35).

Reader P, second part: `report/library.md` (Appendices D, E, G) and Appendix F, read at `6c6b8ef1` after §0. Places are `library.md:line` and `language.md:line` in the clone. Every program was built and run with the clone's `bin/ern`. All stand under `readers/P2/`, called `P2/` below; each program is `P2/tN/main.ern`. I read no log entry beyond the lines that hold the last counts, and read `src/` only to see what a rule means. The clone is unchanged (`git status` empty) and no process of mine is left.

#### Counts

Counted as the last review counted (its method is in the kept `mvp44_item4/lists/P2.md`). My script `P2/count.sh`, run on `93a13b13`, gives that review's figures.

| What | At `93a13b13` | Now | How counted |
|---|---|---|---|
| Taken top-level namespaces | 31 | **30** | each tried as a file at a program's root (`P2/ns/`): the 27 of Appendix E, `Prelude`, `Address`, `Ernest` are refused; `reply.ern` now builds |
| Prelude functions | 18 | **16** | §9.4 five, §9.5 nine, `fault`, `compare` (P1's count; given because both moved into E) |
| Standard library modules | 27 | 27 | sections E.1 to E.28 but E.19; 27 files in `src/stdlib/` |
| Standard library declarations | 369 | **377** | the lines `Name.name :` of E's listings |
| Standard library types | 28 | **30** | the `type`, `abstract type`, `foreign type` lines of E's listings |
| Libraries | 11 | 11 | sections G.1 to G.12 but G.5 |
| Library declarations | 65 | **69** | as E's |
| Library types | 24 | 24 | as E's |
| Glossary terms | 187 | **195** | the `- **` lines of Appendix F (the `terms` listing prints 197 rows) |

What moved:

- Namespaces, one fewer: `Reply`, since `Reply.process` became `Process.fromReply`.
- Prelude functions, two fewer: `Io.debug` and `Reply.process`, both now E's.
- E's declarations, eight more: `Io.debug` and `Process.fromReply` from the prelude; new `List.findIndex`, `List.minimum`, `List.maximum`, `OrderedMap.minimum`, `OrderedMap.maximum`, `Tcp.address`. Renamed: `List.span` to `splitWhile`, `OrderedSet.min`/`max` to `minimum`/`maximum`, `Os.termination` to `subscribeTermination`, `Process.faults` to `subscribeFaults`, `Peer.computeAt` to `compute` and the old `compute` to `computeAnywhere`.
- E's types, two more: `Process.Callee`, `Os.Environment`.
- G's declarations, four more: `Crypto.bitXor`, `Http.filePath`, `Uri.encode`, `Uri.toString`. Renamed: `Ets.owned` to `ownedCount`.
- Glossary: eleven in (`chain`, `effect variable`, `find`, `foreign code`, `form`, `host`, `process a session started`, `process of the shell's own`, `resource`, `service binding`, `wrap`), three out (`authority`, `percent-encoding`, `URI reference`).

Unmoved counts my part holds: functions that are no value 28 (23 members, five forms); `Io.Error` 16 constructors (`NotLoaded` gained a `String`); E.0 four admission rules and eleven shape rules. New for the next review: E.0 admits five things by name (`OrderedSet`, `OrderedMap`, `Random`, E.13's generator, `Io.debug`), one sentence at `93a13b13`, three now; `library.md` is 31,886 words (30,656 then, 27,895 at `v0.10.0`).

Checked and found right:

- All 446 listing lines print the type the shell's `:type` prints, own types' namespaces aside (`P2/types_out.txt`, `P2/types_out_g.txt`).
- The listings' names are exactly the sources' exports less the 23 members and `Io.show` (`P2/src_exports.txt`).
- Appendix D's code is `src/libs/ets/ets.ern` without its comments.
- The prose examples I ran hold: `Path.join`'s four, `Path.name`, `Test.equal`'s text, E.5's three, `Json`'s repeats, `Base64`'s, `Uri.toString` read back on 14 references, `Random.nextInt` past 2^64 (`P2/t7`, `P2/t13`).
- A second `subscribeFaults` replaces the first, as shape rule 2 says (`P2/t3`).

#### Defects

1. **Shape rule 8's zero-time rule names one exception and has three.** `library.md:230`: "a wait given 0 has run out as it begins, answering `Left(Timeout)` before any other answer, the host given nothing ... but where its section orders its answers otherwise (E.27)". `library.md:186` now holds the shape rules "in every library".
   - `P2/t4`: `Os.run(Os.command("nosuchprogram", []), 0)` answers `Left(Io.NotFound)`, and with a U+0000 name `Left(Io.Invalid)`. The source starts the program before its first read, so the host is given a start.
   - `P2/t9`: `Http.readRequest(socket, wholeHead, limits, 0)` answers `Right("/")`; with a bad head carried, `Left(Http.Protocol(Http.Malformed))`; `Http.writeResponse` with a bad header and 0 answers `Left(Http.Protocol(Http.Malformed))`.
   - E.23 (`:937`) and G.11 (`:1352`, `:1368`) order these so, but rule 8 sends the reader to E.27 alone.
   - Fix: end the sentence at "but where its section orders its answers otherwise", and have E.23 say that `run` given 0 answers `start`'s `Left` first.

2. **Shape rule 8's list of waits without a limit leaves out a load.** `library.md:228`: "`Address.callForever`, `Tcp.acceptForever`, `Tcp.readForever`, `Os.readForever`, `Process.run` and `Test.faults` are the waits on another party without a limit". E.21 (`:808`) says `limited` "is `false` for ... `Process.run` and a load", and E.28 (`:1134`) has the caller wait while the program's own bindings run.
   - `P2/t8`: a module whose binding sleeps 1500 ms, loaded by `Code.load`; a watcher prints the loader's status as `Some(#("Calling", None, false))`, and the load answers after the 1500 ms.
   - A child's wait "until the supervisor has it" (`:868`) is a second (read, not shown).
   - Fix: name `Code.load` and a child's join in the list.

3. **Four functions wait on what shape rule 8 names and take no milliseconds, unsaid.** `library.md:224`: "A function that waits on what is outside the runtime, a far end, a peer, a file's device, a started program, takes the milliseconds"; only `Tcp.close` is excepted.
   - `Code.load : (Path) -> ...` and `Code.hashes : (Path) -> ...` (`:1153`) read files "through the runtime".
   - `Tcp.listenTls` (`:755`) reads two PEM files.
   - `Tcp.listen` looks a name up (`:711`), and no time for the lookup is stated.
   - `P2/t18` shows each answering from the file system or the resolver: `Tcp.listen("nosuch.invalid", 0)` gives `Left(Io.Other("non-existing domain"))`. The wait itself is read, not shown.
   - A reader who knows `Fs.read(path, ms)` predicts `Code.load(path, ms)`.
   - Fix: rule 8 names the four beside `Tcp.close`, with what bounds each, or they take the milliseconds.

4. **`Fs.makeTempDir` faults where its result has room, against §7.4.** `library.md:659` (new): "`makeTempDir` faults its caller where `TMPDIR` is not UTF-8, as `Os.environment` does". `language.md:958`: a function faults only where "its result has no room for the failure".
   - Its result is `Either(Io.Error, Path)`, `NotUtf8(Bytes)` is "text that is not UTF-8 ... its bytes as they came" (`:241`), and `:249` lists `NotUtf8` among `Fs`'s answers. `Os.environment`'s `Optional(String)` has no room; this has.
   - `P2/t6`, run with `TMPDIR` set to `/tmp/\377x`: `Main.main faulted: the environment variable TMPDIR is not UTF-8`, with `Os.environment:244` and `Fs.makeTempDir:389` in the trace.
   - A reader who knows `Fs.readLink` answers `Left(NotUtf8(target))` predicts the same here.
   - Fix: answer `Left(NotUtf8(bytes))`, or name the clause of §7.4 that admits the fault.

5. **`Tcp.address` breaks shape rule 10 in the module where "address" is already a type.** `library.md:232`: a name is "not one that a name beside it in the module makes mean something else". `:765` (new): `Tcp.address : (String) -> Optional(Bytes)`. Every other line of the listing says `Address(SocketMsg)` or `Address(ListenerMsg)`, and E.18's prose says "the addresses `listen` and `connect` answer" (`:689`).
   - `P2/t1`: `Tcp.address("::1")` is `Some(<<0, ..., 1>>)`, sixteen bytes and no `Address`.
   - A reader who knows the rest of `Tcp` predicts an `Address`.
   - Fix: a name that says an IP address's bytes; that is a decision.

6. **"Two pairs are two ways to one value" is short by at least five.** `library.md:170` (new), which §0 principle 2 rests on: "The standard library adds a second way only where Appendix E.0 names the pair." `P2/t2`:
   - `Int.toString(n) == Int.toStringBase(n, 10)` is `true` for six numbers, negative and large among them.
   - `String.toInt(s) == String.toIntBase(s, 10)` is `true` for thirteen texts, `"+5"`, `"007"`, `" 5"` and fullwidth digits among them.
   - `Clock.monotonic()` and `Clock.monotonicMicros() / 1000` print `-576460751747` and `-576460751746`: one clock, two primitives (`ern_rt:monotonic/0`, `ern_rt:monotonic_micros/0`).
   - `Char.toString('a') == String.fromList(['a'])` is `true`.
   - `Char.isAsciiDigit(c) == Optional.isSome(Char.digitValue(c, 10))` is `true` for four characters.
   - Shape rule 3 also says a conversion "exists once" (`:200`); `toInt` exists twice.
   - Fix: name these pairs, or say what kind of pair the sentence counts.

7. **E.24 names no primitive and its module has four.** `library.md:139`: "Each module's section names its *primitives*". `src/stdlib/test.ern` declares four `foreign fn`: `marked` (`ern_rt:expected/2`), `yield` (`erlang:yield/0`), `captureWrites` and `captured`. E.24 (`:965` to `:977`) names none. E.7 gained "The module is Ernest (E.0 rule 1)" in this release; E.10 and E.11, with no `foreign fn`, still say nothing.
   - Fix: E.24 names its four, and E.10 and E.11 take E.7's sentence.

8. **The glossary sends "segment" to a sentence that went.** `language.md:1582`: "segment — ... or of what TCP carries (Appendix E.18)". E.18 now has no "segment" (`/usr/bin/grep -c` gives 0; one at `93a13b13`, in a sentence on a reset backlog).
   - Fix: drop the fourth sense.

9. **Shape rule 7 gives the wrong section for `Io.show`.** `library.md:223` (new sentence): "A prelude operation a module provides is listed in §9.6 and not in the module's section." `Io.show` is listed in §9.4 (`language.md:1215`), and E.1 says so (`:237`).
   - Fix: "listed in §9".

10. **`limited` is `true` where the same paragraph says no time ends the wait.** `library.md:808` (new): "`limited` is `true` where a time ends the wait ... It is `true` for a restart's wait too, though no time ends its wait for a wrap that does not finish". Read, not shown.
    - Fix: `false` there, or say what bounds the wait.

11. **E.0 says E.13 states its generator whole, and it does not.** `library.md:175`: "E.13 states its generator whole". E.13 (`:570` to `:576`) names SplitMix64 and "the same seed gives the same sequence everywhere", but not how a draw becomes a number below a bound or a `Float`. The source rejects draws at or above the largest multiple of the bound, takes more draws past 2^64, and makes a float from the top 52 bits plus a half.
    - `P2/t1`: `Random.nextInt(Random.seed(1), 10)` is `5`, which no sentence of E.13 lets a second implementation reach.
    - Fix: two sentences in E.13 for the two mappings.

12. **E.2's sentence on the order of calls leaves out `filterMap`.** `library.md:280` (new) lists ten functions that "call their function on the elements in the list's order, once each"; `List.filterMap` (`:292`) is not among them. The source calls it in order (`src/stdlib/list.ern:192`).
    - Fix: add `filterMap`.

#### Clarity

13. **"what §10 refuses the standard library" points at no sentence.** `library.md:135`. §10 (`toolchain.md:16` to `:50`) never names the standard library and refuses nothing by that word. A builder must guess which bullet makes `Ets` a library, "Processes share no memory" being my guess. Fix: name the bullet.

14. **`Http.reason`'s prose says less than its listing.** `:1364`: "`""` for a status the registry does not assign". `:1397` adds "or assigns for a time or has made obsolete". `P2/t7`: 104, 306, 418 and 510 all give `""`. Fix: the prose takes the listing's three cases.

15. **Three glosses no longer fit.**
    - `language.md:1592`, "shape rule — ... of the standard library", against `library.md:186`, "The shape rules hold in every library".
    - `language.md:1598`, "standard library — the modules that ship with the compiler, on the load path by default", which Appendix G's libraries now also are (`library.md:1160`).
    - "handshake" and "connection" are glossed for nodes alone, and E.18 uses both for TLS and TCP throughout.

16. **E.1 says twice how `show` takes its type, in two wordings.** `:266` "by the argument's type at the call", `:270` "by the type at which the name is used, as a callee or an argument". The first does not cover `List.map(xs, Io.show)`. Fix: keep the second.

17. **`library.md:1065` states nothing.** "`service`, `offer`, ... and `setUtilization` act as §8.7 and this section state, and answer as the listing gives". It lists ten of the twelve and leaves `peers` out with no reason. Fix: drop the sentence.

18. **G.4 gives `cpu` a time and does not say it.** `:1241`: "answers `None` too where the service does not answer in time". The page says 5 seconds, the host's (`src/libs/utilization/utilization.ern:102`). §0's *Time* asks for "a time the report states where the wait stands".

19. **`splitOnce` and `graphemes` are in no vocabulary.** E.0's text vocabulary (`:160`) omits both. `:774` lists `splitOnce` among "the functions `String` has for text" that `Bytes` shares. Fix: add them, or say rule 3 admits them.

#### Kept for a reason a later rule removed

20. **`OrderedSet`, `OrderedMap` and `Random` "enter by name"** (`:135`, new). The sentence before it sends "any other type, with its structure's vocabulary" to a library. E.25 and E.26 say "Nothing is a primitive", and E.13 is "written in Ernest". Nothing in `src/` or `tools/` calls `OrderedSet`, one example calls `OrderedMap`, and `clock.ern` and one example name `Random`. They stay because they were there.

21. **`Io.debug` "is kept alone, by name"** (`:182`). It was the prelude's because no declaration could give `show`. A program now writes the requirement: `P2/t2` declares `fn dbg(value : a) : a needs a.show = { Io.printlnError(Io.show(value)); value }` and it prints as `Io.debug` does. It is the composition rule 4 refuses, three lines of a program's.

22. **Shape rules 4 and 5 are pointers.** `:201` "A function answers and faults as §7.1 and §7.4 say." `:202` "A function's type names a mailbox as §6.1 and §4.7 say." Each held a rule of its own at `v0.10.0`; now each holds a number.

23. **"Where a sequence's vocabulary has `sort`, it has `minimum` and `maximum`"** (`:158`). There is one sequence, the list, and the sentence before it already lists both names.

24. **"Each follows the shape rules E.0 holds a library to and documents itself as shape rule 6 asks"** (`:1162`). This was written when rules 6 and 8 did not reach a library. E.0 now holds every shape rule in every library, so both halves say one thing.

25. **`Random`'s private helpers answer in the order the listing left.** `src/stdlib/random.ern`: `below` and `splitMix` answer `#(Int, Seed)`, and `nextInt` swaps to the listing's new `#(Seed, Int)`. This is code, named for the session's code readers.

#### Principles

26. **E.0's sentence on what is a library admits both verdicts (principle 5).** `:135`: a module is the standard library's "where its functions are the runtime's or the host's to do", and a library's "where it is over a published specification".
    - Both hold of TLS, in `Tcp.listenTls` and `connectTls`, by the host's `ssl`.
    - Both hold of ECMA-48, which `Terminal` reads and the library `Ansi` writes (`:633`).
    - Both hold of JSON ("by the host's `json` module"), base64, SHA and URIs, which are libraries.
    - Program: `Tcp.connectTls(host, 443, Tcp.Unverified, 5000)` is the standard library's, and `Base64.encode(bytes)` is a library's.
    - Proposed sentence: a specification is the standard library's only where a system module's resource cannot be opened without it.

27. **§7.4's "no room for the failure" follows the result type, and nothing decides the type (principle 1).**
    - `P2/t2`: a base of 37 gives `Char.digitValue` `None`, `String.toIntBase` `None`, and `Int.toStringBase` a fault, `a base is from 2 to 36`. The last answered `Optional(String)` at `v0.10.0`.
    - `P2/t7`: a result past the finite range gives `Float.div(1.0e308, 1.0e-308)` `None` and `Float.pow(10.0, 400.0)` a fault, `float arithmetic error`. Both are `Optional(Float)`.
    - A reader who knows either predicts the other alike.
    - Proposed sentence for §7.4: a function whose argument has a domain the caller writes as a literal faults outside it; one whose argument is data answers `None`.

28. **`Peer.computeAnywhere` is a policy inside the standard library (rule 3, principle 2).** `:1091`: it "draws two of the peers ... at random, and runs `f` on the less busy". The new sentence says "`Peer.utilization` is the fresh reading, for a program that picks a peer itself".
    - `P2/t15` writes the pick in twelve lines over `Peer.utilizations`, `Random.nextInt` and `Peer.compute`, and it compiles and runs.
    - Rule 3 states a choice whole "only where the language, the toolchain or the host makes the same choice". None makes this one.
    - Without it a program loses nothing but the lines.

29. **Eleven namespaces are neither taken nor free (principle 1).** `:1160`: "a program's module at the namespace of a library's module hides that module".
    - `P2/t17`: a program with its own `time.ern` builds and prints `true`.
    - `P2/t16`: the same program with one added call, `Http.date(0)`, is refused: `ern build: time.ern: Time hides the library Time, which the library Http uses`. No help line says what to write.
    - A reader who built `time.ern` yesterday predicts it builds today. The names at risk are a first program's: `time`, `uri`, `http`, `json`, `crypto`, `ansi`.
    - The rule itself is §11.1's, the third part's.

30. **A subscription is replaced with nothing said (principles 1 and 3).** `:197` (new): "the next call of the same function replaces it".
    - `P2/t3` subscribes with `first`, then `second`, and faults a process: only `second wrap: boom` prints.
    - A reader who knows `monitor`, where two monitors give two `Down`s, predicts two reports.
    - The rule buys the absence of an unsubscribe. It costs composition: two parts of a program in one process cannot both listen, and the first learns nothing.
    - The principles admit the opposite, as `demonitor` shows.

31. **`String` and `Bytes` have `drop` and no `take` (principle 1).** `:385` (new): "have no `take`: `slice(string, 0, n)`".
    - `P2/t12`: `String.take("hello", 2)` gives `unknown name String.take`, with no help.
    - `drop(s, n)` is `slice(s, n, size)` the same way, and `List` has both.
    - A reader predicts `take`. Either both go or both stay; the error could at least name `slice`.

32. **One job, three verb pairs across the libraries (principle 2, shape rules 2 and 3).** Text to value and back is `Uri.parse` with `Uri.toString` (new), `Json.parse` with `Json.encode`, and `Http.parseDate` with `Http.date`. `Uri.encode` (new) is percent-encoding.
    - `P2/t14`: a reader who knows `Json` writes `Uri.encode(reference)` and gets `the argument does not fit Uri.encode: expected Bytes, found Uri.Reference`.
    - Shape rule 3 names a conversion "by the other type" and now holds in every library; only `Time.toCivil` with `fromCivil` and `Uri.toString` follow it.

33. **Hexadecimal is written in two cases (principle 1).** `P2/t13`: `Bytes.toHex(<<255>>)` is `"ff"`; `Int.toStringBase(255, 16)` is `"FF"`; `Uri.encode(<<255>>)` is `"%FF"`; `Json.encode` writes `\u001F`. `:774` (new) states the split and gives a reason, "the case a digest is written in", which the report's writing rule leaves out.

34. **`Tcp.close` waits with no time at the call (principle 3).** `P2/t10`: after a 30 MB write the far end never reads, `Tcp.close(socket)` answers after 5005 ms. E.18 (`:717`) and shape rule 8 state it, and the bound reaches 3 minutes. The call's text shows `Unit`. The host's own close waits the same way, so the principles admit this rule and its opposite; I name it as the one wait in E whose length a caller cannot write.

35. **Rules that buy a program little.**
    - `:707`, "The host's process of a connection over TLS hibernates after a millisecond's wait": no program can observe it but in `memory`.
    - `:147`, "A form is chosen for speed where this rule says so, and nowhere else": it restates the scope of the two clauses above it.
    - `:170`'s pair sentence: it exists so that §0 principle 2 holds, and both pairs it names only shorten. `P2/t11` shows `Process.current()` equal to `Process.fromAddress(self())` in `main`, in a wrap and in an adapted address's function.

### P3

Reader P3, the principles, `report/toolchain.md` §11, §12 and Appendix H at `6c6b8ef1`, read whole after §0.

**Counts of findings:** 4 defects, 9 against the principles, 1 of clarity, 2 in text the diff does not touch (each shown by a run). 16 in all. Finding 2 and finding 12 are read and not shown by a program; every other is shown by a run of the clone's `bin/ern`.

Not done: no node was started, so the attached shell, `ern reload`, `ern stop`, the carrier and the exchange are read only. `make terms` and `make citations` were not run, as the brief says. §10 and Appendix C were read and are not judged here.

Scratch directory, called `P3/` below: `readers/P3`. The full path of each program is listed at the end.

---

#### Defects

##### 1. `ern test` refuses a copy of a build, which §11.2 says a directory may hold

**Place.** §11.2, `toolchain.md:233` (new at `e9a2e3fb`), against `toolchain.md:211` and `:237`.

**Quote.** "So the directory may hold several roots, a copy of a build among them."

**What is wrong.** A copy is run only where the path its `.erc` records still reaches its source from the copy's place. Any other copy is refused at its turn, and line 237 has that end the job. The refusal names a source that never existed. `ern run` runs the same copy. A reader predicts from line 233 that a copied build's tests run.

**Run**, in `P3/tt` (`proj/src/doubles.ern` has one test and one example; built to `proj/build`):

```
$ cd proj && ern test build            -> 2 cases, 0 failed   [0]
$ cp -r build build2 && ern test build2 -> 2 cases, 0 failed   [0]
$ cp -r build ../all/copy && cd .. && ern test all
ern test: all/copy/doubles.erc was compiled from all/src/doubles.ern, which no longer exists  # status 1
$ cd all && ern run copy/main.erc      -> 8   [0]
```

**Fix.** Line 233 says "a copy of a build that stands where each `.erc`'s recorded path reaches its source". The refusal for a source that is not there should not say "was compiled from" a path that never held it.

##### 2. Appendix H says a hash reaches the unit loaded first; §11.2.8, §12.7 and the code say the latest

**Place.** Appendix H, `toolchain.md:1060` (rewritten for this release), against §11.2.8 `:368` and §12.7 `:1002`.

**Quotes.** H: "Two definitions whose forms are one term have one hash, and a reference by hash reaches the one its node loaded first, by a load or an arrival." §11.2.8: "a peer that names it by its identity (§8.7) finds it in the latest version whose bindings, as its code reads them, have their values."

**What is wrong.** A function's form now holds its qualified name, so two definitions of one term can only be one declaration held in two units. That is the case §11.2.8 and §12.7 already rule, and they say latest. The clause is left over from the nameless form's merge rule ("the first declared, and otherwise the one its node loaded first" at `93a13b13`).

**Read, not shown by a program.** The code agrees with §11.2.8: `src/runtime/ern_code.erl:490-494` takes a type from "the first unit loaded that holds it" and a function from "the one whose initializers have run, the latest loaded"; `answering/1` at `:745-765` does that.

**Fix.** H's sentence becomes "A definition a node holds in several units is one definition; §11.2 and §12.7 say which unit answers."

##### 3. `:load` says `on the load path` for a used module it also looked for under the source root

**Place.** §11.2.8, `toolchain.md:340`.

**Quote.** "A compiled form fails where it is refused, and where a module it uses is found nowhere: `no module Geo on the load path`."

**What is wrong.** `:load` finds a used module under the source root too and compiles it there. So the text leaves out the place where a source would mend it. The same command says `under the source root . or on the load path` for the module it names. §11 has "One cause has one text in every job".

**Run**, in `P3/mm`:

```
$ cd empty && printf ':load Main\n' | ern shell --load-path ../lp      (lp holds main.erc, which uses Util)
> no module Util on the load path
$ cd ../sr && printf ':load Main\n' | ern shell --load-path ../lp      (sr holds util.ern)
> Util, compiled from util.ern
Main, from .../mm/lp/main.erc
```

At one prompt the cause has two more forms: an input gives `no module Geo under the source root or on the load path`, and `:load Util` gives `no module Util under the source root . or on the load path`.

**Fix.** The used module's text is `no module Util, which Main uses, under the source root . or on the load path`.

##### 4. `let _ = e` stops a block's check, though §11.5 says a statement that binds nothing does not

**Place.** §11.5, `toolchain.md:566`, against §11.2.2 `:271`.

**Quotes.** §11.5: "an error in a statement that binds nothing, or in a `let` whose annotation fixes its name's type, does not stop the block". §11.2.2: "`let _ = e` runs `e` and binds nothing."

**What is wrong.** By the report's own words `let _ = e` binds nothing, and the checker stops at it.

**Run**, `P3/blk/main.ern`: three blocks, each with two calls `Io.println(<Int>)`.

```
main.ern:2:16 and main.ern:3:16     both reported (expression statements)
main.ern:8:24                       reported; line 9, a second `let _ =`, is not
main.ern:14:32                      reported (`let #(_, _) = ...`); line 15 is not
```

**Fix.** §11.5 says "an error in an expression statement", or the checker goes on after a `let` whose pattern binds no name.

---

#### Against the principles

##### 5. `ern config --config-dir d` creates a key or prints one, and its output does not say which (3, 2)

**Place.** §11.3, `toolchain.md:508-510`.

**Quote.** "`ern config` prints that key's public key as it prints a created directory's".

**What is wrong.** One command line does two jobs, chosen by what the disk holds. A mistyped name of an existing node makes a new node and prints a new key in the same form, with nothing on standard error and status 0. The reader pastes the wrong key into a peer's list. §0 has a job say "what it did where its reader could not see it".

**Run**, in `P3/cfg`:

```
$ ern config --config-dir store --listen 127.0.0.1:8654 > out1.txt   [0], stderr empty
$ ern config --config-dir store > out2.txt                           [0], out2 = out1
$ ern config --config-dir stroe > out3.txt                           [0], stderr empty, 3 lines, another key
$ ls stroe -> certificate.pem ernest.conf private-key.pem
```

**Fix.** A creation says so on standard error, `created stroe`.

##### 6. A library's namespace is free for a module until another file uses a library that uses it (1, 2)

**Place.** §11.1, `toolchain.md:167-171`, with §11.2 `:199`, §11.2.8 `:342` and `:362`, and §11.9 `:735`.

**Quote.** "`time.ern: Time hides the library Time, which the library Http uses`".

**What is wrong.** A reader predicts a name is free or taken. Here one added line in `main.ern` makes the untouched `time.ern` fail. A package may never be named `time`, so the question has two rules. The refusal names no fix, where the taken-segment refusal two paragraphs below ends `; give io another name`. Three paragraphs and four more refusals exist only because Appendix G's eleven namespaces stand on every load path and §4.2 does not take them.

**Run**, in `P3/hide` and `P3/hide2`:

```
$ ern build --source-root src --build-root build src && ern run build/main.erc   -> 12   [0]
  (main.ern gains one line: Io.println(Int.toString(Http.defaultLimits.line)))
$ ern build --source-root src --build-root build src
ern build: src/time.ern: Time hides the library Time, which the library Http uses
ern build: Main is not compiled, since it uses Time, which failed  # status 1
$ ern unpack      (a manifest entry named time)
ern unpack: package.conf: the entry for time names Time, which a library of the toolchain's own provides  # status 1
```

**Fix.** §4.2 takes Appendix G's namespaces as it takes the standard library's, and the conditional refusal goes. Short of that, the refusal ends `; give time another name`. The log's *What Stands on Every Load Path* (2026-11-23) leaves seven of the libraries waiting for a proposal.

##### 7. The shell changes the mode of `$HOME/.ernest`, through a link too, and says nothing (3, 1)

**Place.** §11.2.15, `toolchain.md:454`.

**Quote.** "The shell makes `$HOME/.ernest` its owner's alone to read, write and enter as it starts, where it is there. … A link at `$HOME/.ernest` is followed."

**What is wrong.** Everywhere else a wrong mode is reported with the `chmod` to run and the job changes nothing: the key, `ernest.conf`, the configuration directory and its `startup` (`:452`, `:936`). Here the job runs the `chmod` itself, in line mode too, on whatever directory a link reaches. A reader who knows the other four predicts a report.

**Run**, with `P3/home2/.ernest` at 755 and `P3/home3/.ernest` a link to `P3/shared` at 775:

```
$ echo ':quit' | HOME=P3/home2 ern shell   [0]
$ echo ':quit' | HOME=P3/home3 ern shell   [0]
$ stat -c '%a %n' home2/.ernest shared
700 .../home2/.ernest
700 .../shared
```

**Fix.** The shell reports a `$HOME/.ernest` that others may write and runs no startup file from it, as it does for a configuration directory's `startup`, and changes no mode.

##### 8. `ern doc` refuses a whole directory for a root module named `Index`

**Place.** §11.4, `toolchain.md:538` (new at `e9a2e3fb`).

**Quote.** "a module `Index` at the directory's root is refused before anything is written, its document's name being the listing's".

**What is wrong.** `Index` is no taken name and `ern build` compiles it. The refusal exists only for the listing's file name. No other module's document is written either, and the advice offers manual pages in place of the CommonMark that was asked for.

**Run**, in `P3/idx`:

```
$ ern doc --source-root src --build-root build --doc-root docs src
ern doc: src/index.ern: the module Index's document would be index.md, which lists the modules; ern doc --man writes its page  # status 1
$ ls docs -> no such directory
```

**Fix.** The listing takes a name the path shape gives no module, `_index.md`, and the refusal goes.

##### 9. `ern doc` takes `--doc-root` with a file, where it does nothing, and `--verbose` names it (3)

**Place.** §11.4, `toolchain.md:530` and `:552`.

**Quote.** "Given a file, the job writes nothing under `doc-root`."

**What is wrong.** An option with no effect is accepted in silence. `--listen` for a directory that exists, `--main` without a file and `--load-path` with `--attach` are each refused. `--verbose` then says a decision that decided nothing.

**Run**, in `P3/cl`:

```
$ ern doc --verbose --build-root b --doc-root a main.ern > /dev/null
source root .
build root b
doc root a
compiled Main from main.ern        [0]; a and b stay empty
$ ern doc --verbose --source-root b --build-root b --doc-root a --load-path a main.erc > /dev/null
read Main from main.erc            [0]
```

**Fix.** `--doc-root` given with a file is refused, `--doc-root is given with a directory: a file's document goes to standard output`. The same question stands for `--build-root` with a file and for the three source options with a `.erc`.

##### 10. `ern unpack` removes a link made by hand and says nothing (3, 1)

**Place.** §11.9, `toolchain.md:766` and `:776`.

**Quotes.** "It says nothing but its refusals and, under `--verbose`, a line … for each named package". "A link at `lib/epx` is removed, and not followed, once the archive has passed every check".

**What is wrong.** A directory at another version is refused and left. A link to a checkout at another version is replaced with status 0 and no line. `ern build` says each stale `.erc` it removed "with it or without" the flag (`:149`), so a reader predicts a line here.

**Run**, in `P3/pk/app`, with `lib/leaf` a link to a checkout at 1.3.0 and the entry at 1.2.0:

```
$ ern unpack          -> no output   [0]
$ ls -l lib           -> leaf is a directory now; lib/leaf/VERSION holds 1.2.0
  (the same with lib/leaf a directory at 1.3.0)
ern unpack: package.conf: the entry for leaf says 1.2.0, and lib/leaf holds 1.3.0; remove it, and ern unpack puts 1.2.0 there  # status 1
```

**Fix.** `ern unpack` says each link it removed, with `--verbose` or without, `removed the link lib/leaf`.

##### 11. A command is selected by a prefix too, a second spelling that only shortens (2)

**Place.** §11.2.3, `toolchain.md:289`.

**Quote.** "A command is selected by its name or by a prefix of its name that begins no other command's name".

**What is wrong.** §0 holds the toolchain to "one way", and principle 2 keeps out a spelling "that only shortens". `Tab` already completes a command at a terminal (§11.2.10). A prefix works in a startup file, where the next command added breaks it: `:r` is `:reload` only until a second command begins with `r`. A setting takes no prefix, so the rule is not even one rule.

**Run**, with `P3/home4/.ernest/startup` holding `:s timing on` and `:t 1 + 1`:

```
$ printf ':b\n:set d 3\n:q\n' | HOME=P3/home4 ern shell
1 + 1 : Int                              (the startup file's `:t`)
> :b is :bindings or :browse
> :set takes depth, length, rows or timing
>                                        (`:q` left the shell)   [0]
```

**Fix.** A command is selected by its name, and the refusal of an ambiguous prefix goes with the prefix.

##### 12. A binding's name still travels beside its form, for a reason the named form removed (2)

**Place.** Appendix H, `toolchain.md:1060` and `:1096`; §11.1 `:111`; §11.2.14 `:438`; §12.7 `:996`.

**Quotes.** "A top-level function's qualified name is in its form. A binding's name is not: two bindings of one form are two bindings, each referenced by its name with the hash." "with the definition's name where the form does not hold it".

**What is wrong.** While no form held a name, a binding's name had to ride in its reference and beside its form. A function's form and a type's now hold theirs. The binding alone keeps the older mechanism: a reference kind of its own, `{binding, QualifiedName, Hash}`, and a name carried beside the form in the `.erc`, in the node's table and in a code frame. That is two ways to give a definition its identity.

**Read, not shown by a program.** The log's *What the form changes* (2026-11-25) says "a binding still by its frame's name".

**Fix.** A binding's form holds its qualified name, its reference is `{hash, Hash}`, and the three "where the form does not hold it" clauses go. This moves the form's version, which 0.11.0 moves already (2 to 3).

##### 13. The manifest's `url` is only ever printed, and its form refuses the whole manifest

**Place.** §11.9, `toolchain.md:699-701`.

**Quote.** "A `url` is an `https` URL whose path's last segment is the entry's name, `-`, its version and `.tar.gz`."

**What is wrong.** `ern unpack` "reads no network". The field's one use is the word after `download` in one refusal. Its form rule still refuses every job that reads the manifest, and it refuses a tag archive's address.

**Run**, in `P3/pk/app`:

```
ern unpack: package.conf: the entry for leaf's url is not an https URL whose path's last segment is leaf-1.2.0.tar.gz: "https://github.com/someone/leaf/archive/refs/tags/v1.2.0.tar.gz"  # status 1
```

**Fix.** The rule holds a `url` to `https` alone, since the advice already says which file name to save it under.

---

#### Clarity

##### 14. "Reload" names two jobs

**Place.** §11.2.8 and §11.2.16 (`:484`, "A reload by any session is the node's") against §11.2.17 and §12.5 (`:946`, "what a reload did"; `:952`, "**A reload.**").

**What is wrong.** `:reload` compiles modules again, and in an attached shell that reload "is the node's". `ern reload` has the node read its configuration again. A reader who knows the first predicts that `ern reload --config-dir n` reloads the node's code. The log holds no entry that weighs the two names. `ern --help` says it plainly: "reload  have a running node read its configuration again".

**Fix.** §12.5 and §11.2.17 write "a reading of the configuration" where they mean the hangup's, and "reload" stays the shell's. The job's own name is a decision for the user.

---

#### In text the diff does not touch, shown by a run

##### 15. `ern doc` judges a page by file times, where `ern build` and `:load` judge by digest (2, 1)

**Place.** §11.4, `toolchain.md:544`. "writes a module's document or page only where none is there, or where the one there is older than what it is made from".

**What is wrong.** A source restored with its old time (`cp -p`, `tar`, `rsync -t`) leaves a page that says what the source no longer does, with status 0. `index.md` in the same paragraph is judged by its text.

**Run**, in `P3/doc1`:

```
$ ern doc --verbose --source-root src --build-root build --doc-root docs src   -> wrote docs/greet.md ("The NEW greeting.")
$ cp -p old/greet.ern src/greet.ern        (other text, dated 2026-01-01)
$ ern doc --verbose ... src                -> writes nothing; docs/greet.md still says "The NEW greeting."   [0]
$ ern build ... src                        -> compiled Greet (the digest sees it)
```

**Fix.** A page's last line records its source's digest, and a page is current where that digest is the source's. The log (2026-10-13) chose times for speed; a digest of the sources costs about the same.

##### 16. A blank line in a doc example decides what is a top-level declaration, by trial parse (4, 1)

**Place.** §11.2, `toolchain.md:217`, against `language.md:88` (§2.1).

**Quotes.** "the longest run of its first paragraphs … that parses as a module's declarations". §2.1: "A blank line has one meaning more: it decides what a doc block documents".

**What is wrong.** §2.1 gives a blank line one extra meaning, and this is a second. The split is found by parsing prefixes, which principle 4 rules out and the prose does not bound. At the prompt the same three lines rebind `x` and give 2.

**Run**, `P3/t2/ex.ern`, `ern test ex.erc`:

```
Ex example 1: passed                                              (fn twice ... / blank / twice(4))
Ex example 2: failed: the name `twice` cannot follow an expression   (the same without the blank line)
Ex example 4: failed: value x is declared twice                   (let x = 1 / blank / let x = x + 1 / blank / x)
Ex example 5: passed                                              ({ let x = 1; let x = x + 1; x })
```

**Fix.** §2.1 names the second meaning, and §11.2 says the parses tried are at most the example's paragraphs. The log's D17 (2026-11-10) stated the code's rule as it was.

---

#### Counts my part holds

The brief's listed counts (reserved words, words by position, taken namespaces, prelude, standard library, libraries) stand in `language.md` and `library.md`; this part holds none of them. The log records no earlier count of the toolchain, so these are first counts, given at `v0.10.0`, `93a13b13` and `6c6b8ef1`.

| Count | How counted | v0.10.0 | 93a13b13 | 6c6b8ef1 |
|---|---|---|---|---|
| Jobs | code spans of §11's first sentence; `ern --help` lists the same | 9 | 10 | 10 |
| Options | bullets of §11.7; the ten `--help` texts hold the same set | 15 | 16 | **17** |
| Shell commands | bullets of §11.2.3; `:help` lists the same | 13 | 14 | 14 |
| Shell settings | `:set`'s words | – | – | 4 |
| Keys | keys named in §11.2.9 to §11.2.11; `:keys` lists the same on 28 lines | – | – | 35 |
| Frames | §12.6's list, counted item by item | 17 | 17 | 17 |
| ABI rows | bullets of §12.2 | 17 | 17 | **18** |
| Form's version | Appendix H | 2 | 2 | **3** |
| Form's shapes | lines of Appendix H's code blocks | 47 | 47 | **48** |
| `ernest.conf` fields | §12.5's first sentence | 8 | 8 | **6** |
| `package.conf` fields | §11.9 | – | 2 and 4 | 2 and 4 |
| Words, §11 | `wc -w` | 18,837 | 25,880 | 27,555 |
| Words, §12 | `wc -w` | 6,005 | 6,271 | 6,517 |

Moved since the full review: options by one, `--doc-root`; ABI rows by one, `Process`; the form's version and one shape, the named function; `ernest.conf` lost its public key and `utilization`. Jobs, commands and frames did not move.

#### Kept for a reason a later rule removed

- Appendix H's "reaches the one its node loaded first": finding 2.
- A binding's name beside its form, and its own reference kind: finding 12.
- Command prefixes, from before §0 held the toolchain to one way (2026-11-23): finding 11.
- `ern doc`'s file times, after `:load` went to digests: finding 15. Its reason, speed, still stands in part.

Checked and still earning their place:

- §11.1's bullet "an interface of the standard library has changed" beside "another build of `ern`": the build's identity hashes the compiler's modules alone (`ern_build:compiler_build/0`), so the two tests are apart.
- `--libs-dir`: decided to stay on 2026-11-23.
- The seventeen frames: held by `runtime_frames_test`.
- Every binding's getter exported: §12.7's link still reads through it.

#### Rules that buy little, or exist only for another

- The root `Index` refusal exists only for the listing's name (finding 8).
- The library-hiding refusal exists only because G's namespaces are not taken (finding 6).
- The `url` form rule exists only for one line of advice (finding 13).
- §11.9 **Versions**, `:764`, "No job checks the promise": it exists only to give meaning to "or a later one" in the build's rule, and a version before 1.0.0 passes that test while promising nothing.
- §11.9's sticky-bit refusal, `:719`, exists only because a job reads the working directory's manifest unnamed.
- `--emit-erl` buys a program nothing; it is for reading the compiler's output.
- "`export` at the prompt adds nothing", `:269`: a word accepted without effect, which buys pasting a module's declaration.

#### Programs, by path

- `readers/P3/tt` (finding 1)
- `readers/P3/mm` (finding 3)
- `readers/P3/blk/main.ern` (finding 4)
- `readers/P3/cfg` (finding 5)
- `readers/P3/hide` and `readers/P3/hide2` (finding 6)
- `readers/P3/home2`, `readers/P3/home3` and `readers/P3/shared` (finding 7)
- `readers/P3/idx` (finding 8)
- `readers/P3/cl` (finding 9, and the command line's refusals, which matched §11)
- `readers/P3/pk` (findings 10 and 13)
- `readers/P3/home4` and `readers/P3/sh2` (finding 11)
- `readers/P3/doc1` (finding 15)
- `readers/P3/t2/ex.ern` and `readers/P3/t1/main.ern` (finding 16)
- `readers/P3/hl`, `readers/P3/ff` and `readers/P3/env` (checks that matched the report: the constructor help of §11.5, §12.3's causes, status 141 and the `ERL_` variables)
- `readers/P3/tc_v0.10.0.md`, `readers/P3/tc_93a13b13.md` and `readers/P3/tc_6c6b8ef1.md` (the three revisions of `toolchain.md` the counts were made from)

The clone is unchanged (`git status` is empty there), and no process of mine is left running.

### K

**Counts.** Defects: 8 (7 shown by a program or a quote, 1 read and not shown). Clarity: 7. Outside the diff, noted in a line each: 2. Kept for an earlier reason: 5 candidates.

**What was read and run.** The three files of `report/` whole, in order, then `docs/soundness.md` whole, against the changed-line lists taken from the four diffs. `make unchecked` and `make edits` were not given, so I went without them. About 120 small programs were built with the clone's `bin/ern build`, and types were read with `:type` in `ern shell` in line mode. Nothing was run on a node, and no runtime fault text was provoked: every check is of the compiler.

All programs are under `readers/K` (below `K/`), in `t1` to `t7`. The helper is `K/try.sh`. No process of mine is left running.

**What held.** Every inline example and quoted error I tried in §2 to §6 and §3.11 came out as the report writes it: the alias errors of §3.1, `derives`, the recursive-group refusals, §4.5's `: T` and `receiving m` cases, §4.9's five quoted errors, paths, fills and puns of §5.6, the pipe cases, the `missing ...` lines, `or` inside a pattern, the bitstring and `receive` errors, the lexical errors, the `Peer.spawn` refusals, and §6.10's two snippets. The counts hold: eighteen reserved words, seventeen frames, four admission rules, eleven shape rules, five primitives, eleven of twelve, six promises. Each job's `--help` has the options §11.7 gives it.

#### Defects

**1. §4.6 refuses a top-level `let` that `ern` generalizes** (`report/language.md:507` and `:509`, against `:284`).
- Quote: "A binding whose initializer is a call, or holds one, has the type the call gives. It is generalized where..." and then "Any other binding is not generalized."
- What is wrong: an initializer that is no value and holds no call (an `if`, a `match`, a block, a selection, a record update) is "any other binding", so by the letter its variable is a type error. `ern` generalizes it. §3.9 already says "a top-level `let` whose initializer is no value is generalized as §4.6 says", and the compiler's own message says "whose initializer is no value". `docs/soundness.md:155` and `:201-203` argue the value and "a call's binding" only.
- Program: `K/t5/gen6.ern` builds with no error. It holds `let a = if true then [] else []`, a block and a `match`, each used at two types (`fn u1() : List(Int) = a`, `fn u2() : List(String) = a`). `K/t4/gen5.ern` (a selection, a record update) builds too. `K/t5/gen7.ern` shows the wording: `the type of f, (a) -> a, is not determined, and a top-level let whose initializer is no value is not generalized where its type holds a function`.
- Fix: §4.6 says "A binding whose initializer is no value has the type the initializer gives, and is generalized where that type ...", and 6.1 of the argument says "no value" for "a call".

**2. `Code.running` refuses a loop that never returns, and E.28 is silent on it** (`report/library.md:1144`, against `report/language.md:974`).
- Quote: "`f` names a top-level `fn` declaration of any arity whose result type is `Unit`". §8.1: "A result type that is a type variable, as a function that never returns has, is taken as `Unit`."
- What is wrong: an unannotated server loop has a type variable as its result. `spawn` and an entry point take it; `Code.running` refuses it, and E.28 does not say which. The help does not name the annotation that mends it. A first user who drops `: Unit` from §6.10's `count` meets this.
- Program: `K/t4/run1.ern` gives `run1.ern:3:26: Code.running lists the processes that run loop, whose result type is a, not Unit`, with help `name the function the processes run, a top-level fn whose result type is Unit`. `K/t7/loop.ern` builds: the same loop under `spawn` and as `main`.
- Fix: E.28 gains one sentence, either taking a variable result as `Unit` as §8.1 does, or refusing it with a help that writes `: Unit`.

**3. A member declared at an instance of its type: three rules silent, and the argument asserts a check §4.9 does not state** (`report/language.md:541`, `:559`, `:262`; `docs/soundness.md:255`).
- Quote: §4.8, "`T` is the type applied to any arguments, the same in each place". §4.9 names only "A call at a type whose member has another result type". The argument: "its whole type is checked against the member's shape at that type, so a member declared for `Vec(Int)` alone does not serve `Vec(String)`."
- What is wrong: `fn Vec.+(l : Vec(Int), r : Vec(Int)) : Vec(Int)` is accepted. What an operator, a supplied requirement or a `derives compare` at `Vec(String)` or `Vec(a)` then does is in no section. The derived case reports an annotation nobody wrote.
- Programs:
  - `K/t2/vec1.ern`: `Vec.+ does not fit two operands of Vec(String): expected (Vec(String), Vec(String)) -> a, found (Vec(Int), Vec(Int)) -> Vec(Int)`.
  - `K/t2/vec2.ern`: `total needs Vec(String).+ : (Vec(String), Vec(String)) -> Vec(String), and the member's type is (Vec(Int), Vec(Int)) -> Vec(Int)`.
  - `K/t2/vec3.ern`: the same for `List.sort` and `<`.
  - `K/t2/vec4.ern`: `vec4.ern:3:40: type variable a in the annotation is used as Int`, at `derives compare` of `type Box(a) = Box(v : Vec(a), n : Int)`.
- Fix: §4.9 states the whole-type check with its text and §3.5 the derived case; or §4.8 asks a member at the type's own parameters.

**4. Process-only is written as a function's, and `ern` holds it as the variable's** (`report/language.md:313` and `:323`, with the changed `:485`; `docs/soundness.md:113`).
- Quote: "No other function is, but for one that calls a process-only function".
- What is wrong: a function that only spawns a lambda calling a process-only function, sharing the variable through `self()`, holds no `receive` and calls no process-only function. By §3.9's letter (none) applies, and §4.5's changed sentence lets `: Unit` stand over it. `ern` marks it `e+` and refuses the annotation. The lemma ("a `receive` either fixes α ... or makes it process-only, and (none) applies to neither") needs the variable reading. Both readings look sound to me; a second toolchain must guess. Lines 313 and 323 are not in the diff; the changed §4.5 rests on them.
- Programs: `K/t6/lemma.ern` gives `Lemma.f2 : () -> Unit receiving e+`. `K/t6/lemma_f4.ern` gives `lemma.ern:19:14: self needs a mailbox, and f4 receives nothing`, help `give f4 its mailbox type, receiving e`.
- Fix: §3.9 says the restriction is the variable's, and that a definition whose mailbox type is bound to a process-only function's variable has it, one it spawns among them.

**5. A fill over a namespace whose declaration of the field's name is a member** (`report/language.md:665-667`, with `:1034`).
- Quote: §5.6, "takes each field not given beside it from the declaration of its name in that namespace that the use site may name". §8.5: "A member is named ... where it is supplied: by a requirement (§4.9), a fill (§5.6)".
- What is wrong: an operations record with a field `compare`, the first one a reader writes, filled from `Int`, is in neither the "lacks" case nor the mismatch case. The error names an expression the program does not hold.
- Program: `K/t7/ops.ern` (`Ops(..Int)`) gives `` `Int.compare` names a member, which an expression reaches through `compare` ``, help ``write `compare` ``. `K/t7/ops2.ern` (`Ops(..Int, compare = compare)`) builds.
- Fix: §5.6 gains "A field whose name is a member's there is not filled; it is given, `compare = compare`", and the help writes that.

**6. `Clock.Alarm`'s representation is stated nowhere, and the argument cites §4.6 for it** (`docs/soundness.md:205`; `report/library.md:613`; `report/language.md:507`).
- Quote: "A `Clock.Alarm` is not generalized, its representation being a foreign type (§4.6)."
- What is wrong: §4.6 does not name `Alarm`, and E.15 calls it "an abstract type". §4.6 reads "through the fields of the declared types it names", so a builder must know the fields of every abstract type of the library, and the report gives them for `OrderedSet.Set` and `OrderedMap.Map` only. The diagnostic names a type the program does not write.
- Program: `K/t2/alarm.ern` gives `the type of pair, #(List(a), Clock.Alarm), is not determined, and a top-level let whose initializer is no value is not generalized where its type holds the foreign type Foreign.Term`.
- Fix: E.15 says the alarm's representation is a foreign type, as §3.11 says of a library's resource, and the message names `Clock.Alarm`.

**7. I1 gives every process an expression of type `Unit`, and the compute's step leans on it at type `a`** (`docs/soundness.md:141`, `:306`).
- Quote: "its expression has type `Unit` at mailbox type `M`" and "So by I1 there the value it answers is of `a`".
- What is wrong: the process of a `Peer.compute`, of `Process.run` and of `Test.faults` runs `f : () -> a`. The step at 306 does not follow from I1 as written. `Process.run` and `Test.faults` appear nowhere in the argument (`/usr/bin/grep -c "Process.run" docs/soundness.md` gives 0), though each starts a process at `f`'s mailbox type.
- Fix: I1 reads "its expression has the type its start gave it, `Unit` for a spawn's", with one sentence for `Process.run`.

**8. The argument's "seven such functions" cannot be read from the report** (`docs/soundness.md:229`; `report/library.md:965-987`). Read and not shown.
- Quote: "The standard library's seven such functions".
- What is wrong: E.0 rule 1 says "Each module's section names its *primitives*". E.24 names none (no "primitive" in the section). `Test.capture : (() -> a receiving m) -> #(a, Captured) receiving m` and `Test.until` are typed by their callback's mailbox type, so whether they are an eighth and a ninth is not in the report. I did not open the code.
- Fix: E.24 names its primitives, or says the module is Ernest and over what.

#### Clarity

**9. "Primitive" has two senses, and "form" a third word for one of them** (`report/language.md:66` and `:364`; `report/library.md:129`, `:139`, `:1065`). §0: "A function that is no value is a primitive". E.0: "its *primitives*, the operations a shim carries out", which are values (`List.size`). Appendix E: the five "are forms, and their listing lines carry the comment `a primitive, called where it is named`". The shell prints `a primitive: called where it is named`. Fix: one word for the five, in §0, §3.11, the listing comment and the shell.

**10. §6.2's split between a function the definition answers and one inside a value it answers** (`report/language.md:795`). The same lambda keeps its variable alone and closes at `Never` in a tuple. `K/t4/gen.ern` gives `Gen.mk2 : () -> (() -> Unit receiving a) -> Address(a)` and `Gen.mk : () -> #((() -> Unit receiving Never) -> Address(Never), Int)`. The report and `ern` agree. A reader predicts one outcome, the paragraph names no principle for the departure, and `docs/soundness.md:221` gives no reason. Fix: one clause saying why the tuple's is unfixed, or the same rule for both.

**11. §4.9 quotes one text for two errors** (`report/language.md:549`): "one in effect positions alone, and one the signature does not name, are errors at the requirement, `b is no type variable of the signature`". `K/t3/need.ern` gives the first as `e is an effect variable, and a requirement names a type variable in a value position`. Fix: quote both, or say the text is the second's.

**12. §3.9 asks for an annotation where §3.11 gives `Never`** (`report/language.md:311`, `:356`). "Inference asks for one too at ... the mailbox type of a process spawned on a peer" reads as if an unfixed one is asked for; §3.11 makes it `Never` and refuses only a type that still holds a variable. Fix: "a mailbox type that still holds a type variable".

**13. A reference to the glossary as an owner** (`report/toolchain.md:394`): "A character is a grapheme (Appendix F)". The preamble makes a gloss yield to its section, and Appendix E.5 defines the grapheme. Fix: cite Appendix E.5.

**14. §9 says one thing twice** (`report/language.md:1153`): "`Address.call` and `Address.callForever` are the runtime's, as the process functions of §9.4 and §9.5 are". The two are §9.5's own. Fix: drop the sentence, or name what it sets them apart from.

**15. G.11's prose and its listing differ on `reason`** (`report/library.md:1364`, `:1397`). Prose: "`\"\"` for a status the registry does not assign". Listing: "or assigns for a time or has made obsolete". Informative. Fix: one wording.

#### Outside the diff, a line each

- `report/language.md:1124`: "answered by the spawned process as §6.6 says of `spawn`". §6.6 does not mention `spawn` (nor did it at `v0.10.0`); Appendix E.27 holds the sentence.
- `report/language.md:346`: "instantiating it with a type that contains a function ... is a type error". `K/t2/tag.ern` builds `==` on `Tag((Int) -> Int)` for `type Tag(a) = Tag(Int)`. Equality is through the fields, as 6.9 of the argument says, and the sentence says "type that contains".

#### Kept for a reason an earlier milestone had

- **`T.compare(a, b)` and `T.+(a, b)` as notation** (`report/language.md:336`, `:340`; `docs/soundness.md:249`). §4.5's changed sentence makes that expression an error to write, and the report still defines `<` and `compare` by it.
- **"A call, or holds one"** in §4.6: the value restriction's old shape, where the rule now built is "no value" (finding 1).
- **The listing comment `a primitive, called where it is named`** beside "are forms" (finding 9): two vocabularies for the five.
- **§6.2's tuple case** (finding 10): a rule whose reason neither the report nor the argument gives.
- **§3.9's annotation bullet for a peer's mailbox type** (finding 12), which §3.11's `Never` replaced for the unfixed case.

### U1

Reader U1, `guide/language.md` at `6c6b8ef1`, read whole against the report and the code in the clone.

**Counts:** 10 defects (false or stale statements), 5 restated or ownerless facts and leftovers, 5 matters of clarity, 4 places the language made the Ernest harder, 1 incidental outside my part. 25 in all, numbered through, most serious first within each group.

**What was run.** Scratch directory: `readers/U1` (written `U1/` below).

- Every fenced example was extracted and run with the clone's `bin/ern`: 134 checks, harness `U1/tools/run_examples.py`, output `U1/run_examples.out`, trees under `U1/ex/`.
- All agree with the guide. The 5 lines marked FAIL there are my harness joining stdout before stderr, which the guide's line 13 allows for.
- The node consoles and §9.6 were replayed by hand and agree: §8.1 in `U1/p8/`, §8.2 in `U1/p13/` (ports 18711 and 18713), §9.6 in `U1/p7/`.
- About 330 prose claims were probed at the shell and in files, under `U1/p1/` to `U1/p13/`. All my processes have ended.

**What was not done.**

- No `make` target, so no `make citations`, `make terms` or `make unchecked`.
- Of the report's diff I read `report/language.md`'s word diff whole; of the toolchain's and the library's I read the removed fragments by section, not every hunk.
- Terminal-only behavior (`Tab`, `Shift-Tab`, `C-c`, colors, the live region) is read against §11.2 and not run.
- §5.4's lease-broker line and §8.4's attached-shell session were not run; the guide's test file says `quoted_runs` holds them.

#### Defects: a rule the report no longer states, or a false statement

**1. §2.3, line 340: a constructor named as a prelude type is said to be refused in a type of two constructors.**
- Quote: "`type Command = Set(key : String, value : String) | Clear` is refused for its `Set`, and the constructor is named otherwise, `Assign`."
- Unchanged since v0.10.0. Report §3.1 now refuses only "a type whose one constructor is named as a type in scope", and says "`type Heading = Up | Down | Idle` builds".
- Program: `readers/U1/p2/command2.ern`, that type with a `main` that uses `Set.fromList`. `ern build command2.ern` exits 0, and `ern run command2.erc` prints `Set.fromList([1])`. At the prompt the declaration answers `type Command`.
- Fix: delete the paragraph, or replace it with §3.1's one-constructor case (`type Failure = Down(String)`, help `rename the constructor; Down is the prelude's type`).

**2. §2.9, line 602: a failed read of standard input is said to fault the entry process.**
- Quote: "a stream that cannot be read faults the entry process, and one that cannot be written ends the program (report §7.4, §8.6)".
- Unchanged since v0.10.0. Report §7.4 and §12.1 now say a failed read "faults the process that asked for the line or the bytes"; only keys that are not UTF-8 fault the entry process, and keys that can no longer be read end the program with no fault. The guide's own §1.3 (line 201) already says "faults the process that read it".
- Program: `readers/U1/p3/stdin.ern`, where `main` monitors a spawned reader. `printf '\377\376 bad\n' | ern run stdin.erc` gives:
  ```
  the process of Stdin.main:10 faulted: the standard input is not UTF-8
      Stdin.reader:4

  main lives on; the reader ended: Fault("the standard input is not UTF-8")
  ```
  Exit status 0.
- Fix: "a read that fails faults the process that asked, and a stream that cannot be written ends the program (report §7.4, §12.1)".

**3. §7.1, line 2068: where a module that hides a library's is refused.**
- Quote: "A module that hides one another library uses is refused where the program uses that library, as `time.ern` is beside a module that uses `Http`".
- Report §4.2 (changed since the release) says a node's reach is its whole load path and a session's every library: "a program's `time.ern` that `ern build` and `ern run` take is refused at a node's start".
- Program: `readers/U1/p10/` holds `time.ern` and a `main.ern` that uses only its own `Time`.
  - `ern build .` and `ern run main.erc` succeed (prints `1`).
  - `ern run --config-dir n main.erc` answers `ern run: time.erc: Time hides the library Time, which the library Http uses`, status 1.
  - `:load Time` in a plain shell answers the same line.
- So a reader who follows §7.1 and then §8 is refused with no module using `Http`.
- Fix: add "and at a node's start and at the shell's `:load`, whether or not the program uses that library".

**4. §1, line 112: "§9 lists each job's options."**
- It does not. `ern <job> --help` shows `--verbose` on build, run, test, doc, format and unpack, and `--doc-root` on doc; the guide names neither (0 occurrences each). `ern --version` is not named either. §9.2's `ern test` bullet names no option, though it takes `--config-dir`, `--load-path`, `--libs-dir` and `--package-dir`.
- Fix: "§9 lists the options a program first needs, and `ern <job> --help` the rest", or add the three.

**5. §10, line 3444: "Integers are exact and unbounded."**
- Unchanged since v0.10.0. Report §3.1 changed "Exact and unbounded" to "Exact, and bounded by the host's integers alone (§10)".
- Program: `readers/U1/p3/ints.ern`. `Int.shiftLeft(1, 100_000_000_000)` gives `Ints.main faulted: error:system_limit`, status 1.
- Fix: "Integers are exact, and bounded as Erlang's are."

**6. §3.3, line 718: the values that make a top-level `let` polymorphic.**
- Quote: "a literal, a name, a lambda, or a constructor applied to values".
- Unchanged since v0.10.0. Report §4.6 gained "a tuple or a list of values".
- Program: `readers/U1/p3/poly.ern`. `let pair = #([], None)` and `let listed = [None]` are each used at two types, and it builds.
- Fix: add "a tuple or a list of values".

**7. §3.3, line 737: "Where nothing settles it, with `xs` never read, the type stays open and the block compiles."**
- The condition is too narrow. Report §4.6: "in `{ let xs = []; List.size(xs) }` the element type stays open."
- At the prompt, `{ let xs = []; List.size(xs) }` answers `0 : Int` (`U1/p9/in6.txt`).
- Fix: "Where no use fixes it, as `List.size(xs)` does not, the type stays open".

**8. §4.5, line 979: "it was restarted (§6.5)" in the list of a `callForever` caller's causes.**
- Guide §6.5 teaches a restart after a fault, where the caller faults with the callee's own cause (line 1877 says so). `callee was restarted` comes only where a restart was asked of the callee, which is §6.6's *What a caller sees* (line 1982) and report §6.6's "where it restarted because a restart was asked of it".
- Fix: "it was restarted with a sibling (§6.6)".

**9. §8.1, line 2609: "What the scale measures, how old a telling may be used and what a peer's loss does are the report's (Appendix C, Appendix E.27)."**
- Appendix C lost its `utilization` entry at this release and now holds only `utilization-interval`. What the scale measures is §12.8, to which E.27 points.
- Fix: "(§12.8, Appendix E.27)".

**10. §1.2, line 147: the session's number "counts the sessions a node has had, a plain shell's own being 1 (§9.3)".**
- Guide §9.3 says nothing of how sessions are numbered; the fact is report §11.2.15's, and the only place a node has several sessions is §9.2's `--attach` bullet.
- Fix: point to "(§9.2, report §11.2)".

#### Restated or ownerless facts, and what an earlier state left

**11. §2.9, line 592: "Mathematics over collections of floats, statistics, matrices and numerical methods, is a library's too."**
- The report dropped this sentence from Appendix E.9 at this release (`git diff v0.10.0 -- report/library.md`, at `Float.toString`'s paragraph), and no file of the report holds "numerical methods" now. The recut added it to the guide.
- The guide is now the only document that states it, and Appendix G lists no such library.
- Fix: drop it, or give it back to E.0 or E.9.

**12. §3.2, line 686: the list of what ends a lambda's body.**
- Quote: "`,`, `;`, `:`, `|`, `->`, `>>` or closing bracket ... `then` or `else`, and at a `{` that opens no part of the body".
- Report §5.3 dropped this list at this release and says only "the longest `Expr` at the same nesting level (Appendix A)". The guide keeps the v0.10.0 list, recut, with no owner but the grammar. Read, not shown wrong.
- Fix: keep the two cases a reader meets (`|>` after a lambda, a `{` the body opens) and point to Appendix A.

**13. Twelve messages quoted in prose are in neither the report nor `docs/diagnostics.md` as written, and no test holds them.** I ran each and each is true today:
- line 957, `skip needs a mailbox, and rest receives nothing`
- line 2080, `Test.Failed("expected 2, got 3")`
- line 2116, `3 cases, 0 failed, 1 fault outside a case`
- line 2118, `, started by the case "adds two"`
- line 2124, `expected the fault division by zero, got a return`
- line 2514, `two peers have one public-key, and two nodes with one key are one node` (its text stands only in `src/nodes/ern_node.erl:758` and that module's unit test; I matched the string and did not provoke it)
- line 3274, `Hello.main killed`
- line 3294, `Left(Io.NotLoaded("the binding $Session1.below has no value here"))`
- line 3304, `Words, compiled from words.ern`
- line 3486, `Reading has no field value of one type`
- line 3504, `Main.main faulted: first of an empty list`
- line 3512, `Peer.service names a service at Registry.Msg, ...`

Probes: `U1/p5/`, `U1/p6/`, `U1/p8/`, `U1/p9/`, `U1/p12/`. Fix: give `quoted_runs` these lines, or show each as a console.

**14. §2.3, line 331: the prelude's `type Optional(a) = None | Some(a)` stands in a block marked `ernest`.**
- The check compiles it as a user module that declares its own `Optional`, and holds nothing to the prelude. The `ernest-prelude` mark, which `guide_prelude_declarations_test` reads, is used only at line 1349.
- Fix: mark it `ernest-prelude`.

**15. §4.6 and §8.4: `Upgrade(next : (Int) -> Unit receiving CounterMsg)` is a constructor of one named field.**
- The name told `next` from `migrate`, which this release removed (the guide's diff, the old `Upgrade(migrate : ..., next : ...)`).
- Four programs carry `Upgrade(=next) -> next(total)` and `Upgrade(next = countTwice)` where one positional field would read `Upgrade(countTwice)`. The report's §6.10 has the same form, so it is the session's to weigh.
- Fix: none where the name is wanted as documentation; otherwise make it positional in both.

#### Clarity

**16. §7.1, lines 2039 to 2064: one program is built two ways in one directory, and the tree that leaves is one a node refuses.**
- The section builds file by file beside the sources, then "Or compile the whole tree at once, into `build/`", and only then says "a program of several modules builds its directory".
- Program: `U1/p11/`, the section's commands as written, then `ern run --config-dir a main.erc`. It answers `ern run: build/main.erc holds Main, not Build.Main; remove it, or keep a build root outside the program's root`, status 1.
- Fix: teach the directory build alone, and name the file-by-file form once as what `ern build file.ern` does.

**17. §3.5, line 807: a descending sort is taught two ways in one sentence.**
- Quote: "by a sort reversed, `List.reverse(List.sort(list))`, or by a wrapper type with a `compare` of its own".
- Fix: give the reversed sort for one key, and the wrapper only for a key inside a tuple, saying so.

**18. Line 122 against line 2451: two counts of one kind of thing.**
- Line 122: "one of the two ways a program reaches the world; the other is `foreign fn`". Line 2451: "A program reaches outside its node's Ernest code in three ways: to peers ..., to foreign code ..., and by bytes over TCP".
- TCP is a system module by §2.9, so it is the first of line 122's two; files and started programs reach outside too and are in neither count.
- Fix: drop the count at line 2451.

**19. §9.3, line 3302: "`Shift-Tab` shows the name's version beside its declaration".**
- Report §11.2.11 means "the version it appeared in". In §8.4 and §9.3 "version" is a reload's (`Counter$2`), so the sentence reads as that.
- Fix: "the release it appeared in".

**20. Facts the guide states more than once.**
- The floor, three times: lines 2453, 2478, 3472.
- "The toolchain's libraries are on the load path already", four times: lines 2829, 3120, 3266, 3278.
- What a `site` names, twice: lines 1357, 1770.
- "`ern stop` returns once the node has ended", twice: lines 2819, 3286.
- "The second line, with the trace beneath it, is `ern run`'s report", twice: lines 1823, 1877.
- That `ern shell words.erc` compiles nothing, twice: lines 149, 3304.
- Fix: state each once and point to it.

#### Where the language made the Ernest harder

Counts are over `guide/language.md`'s own programs; my probes met the same.

**21. A spawn whose address is not wanted is `let _ = spawn(...)`: 10 sites.** In a callback that must be `Unit` it takes a block and a second statement, `{ let _ = spawn(...); Unit }` (lines 1057 to 1060 and 1614 to 1617). `let _ = Clock.alarm(...)` adds 4 sites.

**22. A number in a line of output is `Int.toString(...)`: 37 sites**, and a value's is `Io.println(Io.show(...))`: 17.

**23. An address is turned into a `Process` at every `kill` and `monitor`: `Process.fromAddress(` 14 sites**, 6 of them `kill(Process.fromAddress(x))`.

**24. `let me = self();` before a spawn that must reply: 11 sites.**

#### Incidental, outside my part

**25. A session started on a file takes a module that `:load` refuses.**
- In `U1/p10/`, `ern shell main.erc` starts and `Time.now()` answers `1`, with the program's own `Time` in scope.
- In a plain shell, `:load Time` is refused with `time.ern: Time hides the library Time, which the library Http uses`, and so is the node's start.
- Report §4.2 gives a session "every library and every named package on its load path" as its reach, while §11.1 names only `:load` and `:reload` as the shell's refusals.
- It is safe as built: `:load Http` in that session is refused with the same line. But the report's two sentences can be read either way for `ern shell file.erc`.

### U2

**Counts: 11 defects, 13 matters of clarity, 2 places the language made the work harder.**

Read whole at `6c6b8ef1`: `guide/deployment.md`, `guide/why.md`, `guide/faq.md`, against the report and the clone's `bin/ern` (0.11.0-dev). The clone is unchanged (`git status --short` empty), and no node of mine is left running.

Programs are named P1 to P14; their paths are listed at the end.

#### What ran and matched

- **`why.md`:** all nine programs, both shell sessions and the four fragments print what the page shows.
- **`faq.md`:** the two quoted refusals, the adapted address, the second answer, the callee that ends, and the dropped statement all behave as written.
- **`deployment.md`:** sections 1.1, 1.3, 1.4, 2.1, 5, 6.3 and 8 were run step by step. Every line they quote came out as written, apart from the findings below.
- **Section 7's table:** 19 of its lines were provoked. The others were found as text in `src/nodes/` and `src/runtime/`.
- **Both JSON configurations** are accepted once the placeholder key is replaced, and the unit parses under `systemd-analyze verify`.

**Not run:** a floor refusal, the `replaced` line, a full table of processes or ports, `pidfd_open`, an `.erc` of another build, another user's `ernest.pid`, a silent peer's 45 to 75 seconds, and an attach across releases.

#### Defects

The first two teach what the report no longer states.

**1. `guide/deployment.md:92`, section 1.3: a rule of the removed `utilization` entry.**
- Quote: "A change to `measures` or `utilization-interval` holds from the node's next measure of itself and its next report to its peers".
- "From the node's next measure of itself" was the rule of the `utilization` entry (v0.10.0's §12.5: "a change to `utilization` holds from the next ask"), which the report removed with the entry. Report §12.5, *A reload*, now says a change to `measures` "starts or stops the host's services it names".
- Shown: P7 with `"utilization": "run-queue"` gives `ern run: t/ernest.conf: the file has the unknown field utilization`.
- Line 216, "A program may set the number itself, when it knows its load better than the host does", is the orphan of the same entry: it names neither `Peer.setUtilization` nor a section.
- Fix: write line 92 as §12.5 has it, and give line 216 its function and the language guide's section, or drop it.

**2. `guide/deployment.md:178`, section 2.2: the cookie's details are now owned by no document.**
- Quote: "which every node's command line carries and `ps` shows, `-setcookie` and the digest. It is the same on every node of one floor".
- The report's §12.5 was cut to "The cookie stands on the node's command line, is no secret and grants nothing". The flag's spelling, the listing of processes and "the same on every node of one floor" stand in the guide alone, under the citation "(report §12.5)".
- The fact is true: `ps -o args -p $(cat b/ernest.pid)` shows `-setcookie 8caade9c…`.
- Fix: decide the owner. Either the report takes the sentence back, or the guide stops citing §12.5 for it.

**3. `guide/deployment.md:226`, section 3.3: `cpu` takes no parameters.**
- Quote: "`cpu`, `memory` and `disk`, each with the host's parameters under it, `check-interval` and `almost-full`".
- Report §12.5 says "`cpu` takes none", and that `memory`'s `check-interval` is a multiple of 60000. An operator who follows the guide's sentence writes a file the node refuses.
- Shown (P7):
  - `"measures": {"cpu": {"check-interval": 1000}}` gives `measures' cpu has the unknown field check-interval`.
  - `{"memory": {"check-interval": 1000}}` gives `measures' memory's check-interval is not a whole number of minutes, which the host's memory measure counts`.
- Fix: "`memory` and `disk` each with `check-interval` and `almost-full`, `memory`'s interval in whole minutes; `cpu` takes none."

**4. `guide/deployment.md:142`, section 1.5: `nohup` is not what keeps the node running.**
- Quote: "`nohup ern run --config-dir b ... >> b.log 2>&1 &` keeps a node running once its terminal has closed, with the two streams in one file, stamped."
- A hangup is a reload on a node (report §8.6), so `nohup` does nothing for one.
- Shown (P8): the same command without `nohup`, started from an interactive shell on a pseudo-terminal that is then closed, leaves the node running. `b.log` gains `ernest.conf was read again`, which the guide does not mention.
- Under `nohup` the node still takes the hangup: `ern reload` and `kill -HUP` both write `ernest.conf was read again`.
- "Stamped" is half true: the program's own lines on standard output carry no time (P9 prints `line` bare).
- The line is not among those the intro (line 17) lists as shown and not run.
- Fix: drop `nohup`; say that the terminal's close is a reload, and that the node's lines alone are stamped.

**5. `guide/why.md:188`: the name a connection is accepted under.**
- Quote: "a connection is accepted from a listed key alone, under the name listed beside that key".
- Report §12.5, the FAQ (line 105) and the deployment guide (line 168) say "under the name that key gives it", the name on the carrier that holds the key's digest. The name listed beside a key is the lister's own word, which the peer never presents.
- Shown: P7's reload renames a peer under one key, `the peer d is now named e`, and nothing else changes.
- Fix: "under the name that key gives it".

**6. `guide/deployment.md:459`, section 8: `d` can never be reached by an operation.**
- Quote: "Nothing connects until an operation reaches for `d`."
- `d` is made with no `--listen`, so `b` lists it without an address, and such a peer "is never dialed" (the guide's own section 2.1).
- Shown: at `b`'s prompt after the step, a spawn towards `d` answers at once, `d: Io.Unreachable` (P5).
- Fix: "Nothing connects until `d` dials in."

**7. `guide/why.md:182`: not every cause names the function.**
- Quote: "what does not match is a fault at the crossing, naming the function and the type".
- A bad message and a bad reply name the type alone (report §12.3).
- Shown (P11, with an Erlang shim): `the process of Poke.main:20 faulted: message does not match Int` and `Poke.main faulted: reply does not match Int`.
- Fix: "naming the type, and for a return or an argument the function".

**8. `guide/deployment.md:54-59`, section 1.2: a number too large is refused as "not JSON".**
- Quote: "refused before anything runs, with a line that names the fault", with "holds a number too large for the host to read" as its own entry in the list.
- Shown (P7): `"utilization-interval": 1e999`, which is valid JSON, gives `ern run: t/ernest.conf: is not JSON`.
- Fix: the node's line names the number, or the list's entry joins "is not JSON". Report §12.5 lists it apart too.

**9. `guide/deployment.md:463-471`, section 8: the tool's transcript leaves out two lines.**
- The console block of `ern run --config-dir a upgrade/v2/counter.erc` shows five lines.
- At a terminal `a` also writes, between `total: Some(5)` and `b: 1 moved`, `the peer b connected` and `the peer c connected` (P5). Section 5's session does show the `ops` node's own `the peer b connected`.
- Fix: add the two lines, or say that `a`'s own lines on standard error are left out.

**10. `guide/deployment.md:279, 281, 448`: the counter's bytes are not what a run shows.**
- Quote: "`Counter.serve receiving 3120 bytes`", and `memory = 3120`.
- Shown (P5): a node just started with `--main serve` shows `Counter.serve receiving 47512 bytes` in two separate starts, and 115048 after a `:reload` there.
- `test/ern_deployment_tests.erl:825` strips the figure, so no test holds it.
- Fix: write a figure a fresh node shows, or say in section 5 that the figure differs from run to run.

**11. `examples/upgrade/v2/counter.ern:28-29`: a pointer into this guide is stale.**
- Quote: "the deployment guide's §5.3".
- Sections 5 and 6 changed places since v0.10.0: *A service moved to new code* is now 6.3, and section 5 has no numbered parts.
- It is the one stale pointer outside the log; the tour, the FAQ, `why.md` and the language guide point right.
- Fix: "§6.3".

#### Clarity

**12. `guide/deployment.md:208-210, 321`; `guide/why.md:204`: `Io.OtherType` can be hidden.**
- The guide says a peer at another type "answers `Io.OtherType`" and that the move is to align the builds. The find answers "the last failure met" (report Appendix E.27).
- Shown (P6): with `"counter": ["b", "c"]`, `b` offering at another type and `c` offering nothing, the program prints `no counter: Io.NotOffered`. With `["c", "b"]` it prints `Io.OtherType`.
- Fix: one sentence in 3.1 that the find answers its last failure, so a later peer's answer can hide `OtherType`.

**13. `guide/why.md:9`, `guide/faq.md:115`, `guide/deployment.md:176`: the hash covers the module's name.**
- Quotes: "known by a hash of its definition, not by the module it stands in"; "by its content and not by a module's name"; "computed from what the definition does and what it uses".
- A function's qualified name is in its hash (report §8.7).
- Shown (P10): one body, `fn double(n : Int) : Int = n * 2`, has three hashes as `First.double`, `Second.double` and `Third.First.double`. A comment, a layout and a renamed parameter leave the hash as it was.
- Fix: say that the name is part of what is hashed, so a moved or renamed module is new code and a new type.

**14. `guide/deployment.md:299`, section 5: words used before section 6.3 gives them.**
- Since the two sections changed places, section 5 speaks of "the counter the second build's tool spawns", "`Counter.main:57`" and "the module's first reload" ahead of the example that defines them.
- Fix: point at 6.3 there, or use a site of the first build.

**15. `guide/deployment.md:329, 356, 358`: one fact said three times in thirty lines.**
- "A reload … starts the module's services again beside the old"; "the old service runs on beside it"; "So a reload starts the module's services again beside the old".
- Fix: keep it in 6.3 and have 6.2 point there.

**16. `guide/deployment.md` sections 6.1 to 6.3 and 8: one job, three ways.**
- A service is moved by `:reload` and `Counter.moved()` at an attached prompt, by the tool run from another node, and by `Code.load`.
- Nothing says when the operator takes which.
- Fix: one sentence in 6.3 that orders them. As far as I can tell: the shell for one node with the source at hand, the tool for every peer at once, `Code.load` where the program upgrades itself.

**17. `guide/deployment.md:15`: "points at and does not repeat" the language guide's chapter 8.**
- Making two nodes that list each other (`ern config`, `--listen`, `--peer-dir`, the resulting JSON) is taught in `guide/language.md:2478-2512`, in this guide's 1.1, 2.1 and 8, and in the tour's chapter 2.
- Line 2482 there and line 80 here are nearly one sentence.
- Fix: one owner for the commands, a pointer from the other.

**18. `guide/deployment.md:258-264`, section 4.3: a section that is now only a pointer.**
- Its four lines moved to section 7's table at the recut. What is left sends the reader to section 7 and to report §12.5.
- Fix: fold its one own fact, `Io.NotLoaded(text)` against `Io.Other`, into 4.1, if the number may go.

**19. `guide/deployment.md:232, 240, 254`: measures from October on a machine of eight cores.**
- Measured today on twelve cores under load (P12):

  | What | The guide | Today |
  |---|---|---|
  | First spawn on a bare node | about 250 ms | 130 ms |
  | A spawn that ships one definition | about 7 ms | 2.0 ms |
  | A spawn of a function the peer holds | a third of a ms | 0.16 ms |
  | An attach | about half a second | 0.6 to 0.7 s |

- The order holds, and the figures are off by two to three and a half times.
- Fix: measure again before the release, or leave them dated as they are and say the machine is no longer the one in use.

**20. `guide/deployment.md:115, 391`: the site `Counter.serve:14`.**
- It dates from the first draft (2026-10-12). In the guide's own example `Counter.serve` is the entry point, which has no line and spawns nothing, as section 5 says of it.
- Fix: a site the example has, `Counter.main:57`, or `Counter.moving:106` for the row "spawned by the peer a".

**21. `guide/faq.md:37`: "Nothing stands in for `terminate`".**
- That is said of a killed child. At the program's orderly end `Os.subscribeTermination` is exactly that, and the answer on `gen_server` never names it.
- The deployment guide's 1.3 and `guide/language.md:2813` do.
- Shown: P13 prints `the end waits for 1 subscriber: Keeper.main`, `written`, `the subscriber Keeper.main answered`.
- Fix: one clause with the pointer.

**22. `guide/why.md:296` against `:300`: one rule in two wordings.**
- "a process inside it is read as able to be delivered to" against "is read as able to deliver".
- Report §8.6 says such a process "is not waiting".
- Fix: use the second wording in both.

**23. `guide/deployment.md:162` and section 1.3: `ern stop` refuses another user's `ernest.pid` too. Read and not shown.**
- The guide says only of `ern reload` that it refuses an `ernest.pid` that is not its user's own.
- Report §11.2 says "Each" of the two, and "another user's to the superuser". This changed since v0.10.0, which excepted the superuser.
- An operator who stops a service's node as root is refused, and 1.3 does not say so.
- Fix: name both commands in 1.3.

**24. Citations that name a neighbor of the owner.**
- `guide/faq.md:99` and `guide/why.md:399` cite §4.9 for "a member is declared in its type's own module"; that is §4.5 and §4.8.
- `guide/faq.md:105` cites §8.3 for the accepting rule; that is §8.7 and §12.5.
- `guide/deployment.md:323` cites §12.5 for how a fleet moves, which no section states.
- `guide/deployment.md:15` says "every section here names the section that owns what it teaches", and section 8 names none.
- `guide/deployment.md:17` lists what is shown and not run, and leaves out section 2.1's JSON.

#### What exists for a reason a later rule removed

All are numbered above:

- `nohup` (4): the hangup became a reload on a node.
- "the node's next measure of itself" and the orphan paragraph (1): the `utilization` entry is gone.
- The cookie's `-setcookie` sentence (2): the report cut it.
- Section 4.3 (18): its list moved to section 7.
- `3120 bytes` (10) and `Counter.serve:14` (20): an earlier example.
- The October figures (19): an earlier machine.
- The example's "§5.3" (11): an earlier numbering.

#### Where the language made the work harder

**25. A `receive` with its `after` written the Erlang way.**
- `receive { Got(text) -> … } after 2000 -> …` is answered `expected ';' or '}' instead of the reserved word 'after'` (P3).
- The line does not say that the clause goes inside, `| after 2000 -> …`. I found the form in Appendix A.

**26. A program in a subdirectory took three builds.**
- `ern build probe/probe.ern` made the module `Probe.Probe`, rooted at the working directory.
- `ern run --config-dir x probe/probe.erc` then refused to start as a node over another program's file: `upgrade/v1/counter.erc holds Counter, not Upgrade.V1.Counter`.
- `ern build probe` was refused next, over the `.erc` the first build left: `probe/probe.erc holds Probe.Probe, not Probe; … or remove probe/probe.erc`.
- Each line was clear. Nothing told me beforehand that the file form and the directory form give two namespaces.

#### The programs

All under `readers/U2`:

- P1: `readers/U2/why` — `why.md`'s programs, one directory each (`counter`, `other`, `dead`, `mutual`, `stack`, `sorted`, `color`, `unique`, `reload`, `req`), and `frag` with the four fragments.
- P2: `readers/U2/faq` — `never.ern`, `wrong.ern`, `ticked.ern`.
- P3: `readers/U2/dep/binding/binding.ern` — a spawn that reads a binding, a constant and a missing host module, and a compute that faults.
- P4: `readers/U2/dep/watch/watch.ern` — a monitored spawn, a killed peer, a dial answered by another peer.
- P5: `readers/U2/dep` — section 8 whole: the directories `a`, `b`, `c`, `d`, `ops`, the copy `upgrade/`, the sessions `shell1.out` to `shell4.out`, and the nodes' `*.err` files.
- P6: `readers/U2/dep/svc` — `offer`, `find`, `other`: a service, a find and another type.
- P7: `readers/U2/dep/t` with `readers/U2/dep/t.orig` — the configuration each refusal was provoked from; `meas/meas.ern` beside it reads the measures.
- P8: `readers/U2/dep/pty_close.py` with `readers/U2/dep/b.log` — the terminal closed under a node started without `nohup`.
- P9: `readers/U2/dep/chatty` — exit statuses 141, 9 and 1.
- P10: `readers/U2/hash` — `Code.hashes` of one body in three modules.
- P11: `readers/U2/shim` — `ebin/u2_shim.erl` and `prog/poke.ern`.
- P12: `readers/U2/dep/cost/cost.ern` and `readers/U2/dep/dial/dial.ern` — the spawn's costs and the dial's 7 seconds.
- P13: `readers/U2/dep/keeper/keeper.ern` — a subscriber, one stop and two.
- P14: `readers/U2/unit/counter-b.service` — the unit, as `systemd-analyze verify` read it.

The listings I started from are `unchecked.txt`, `citations.txt` and `terms.txt` in the same directory, made by running `build/tools/documents.erc` directly, with no make target.

### N

**Counts.** Defects: 8. Matters of clarity: 21. Places the language made the program harder: 8. Names I could not have predicted: 11. Leftovers: 7.

All paths below are under `N` = `readers/N`. Line numbers are those of the clone at `6c6b8ef1`. Nothing in the clone was edited, no `make` target was run, and the nodes I started are stopped. `make lengths` and `make terms` were not run, as the brief forbids `make`.

#### The program

`sheet`, a spreadsheet at a prompt: each cell is a process, and a change goes by calls from a cell to the cells that read it.

- **Source:** `readers/N/sheet/src/` holds `formula.ern` (231 lines), `cell.ern` (143), `grid.ern` (261) and `main.ern` (119), 754 lines as `ern format` laid them out.
- **Built:** yes, `ern build --build-root build src`, status 0.
- **Tests:** passed, `ern test build` says `11 cases, 0 failed` (9 tests and 2 doc examples).
- **Ran:** yes, `ern run build/main.erc budget.txt`, status 0, and again from standard input. The script is `N/sheet/budget.txt`.

It uses a recursive-descent parser on `Either` chains, `derives compare` with `OrderedMap`, replies, a selective `receive` with a guard and `after`, `adapted` for a protocol apart from the mailbox, `restarting` with `monitorService`, `Fs`, `Os.arguments` and `Test`. The grid refuses a cycle, and a `drill A3` faults a cell on purpose and gives it its formula back.

The first build failed once, on `after` used as a name (finding 30). After that every module compiled at its first build and every test passed at its first run.

Exercises done and run: §1.5, §2.11, §3.6, §4.8 (b) and (c), §5.7 (b), §6.7, §7.4 (c), §8.9. Each answer in §12 matched what `ern` did. The README's shell session against a bare `foo`, §8.1's two nodes and §9.6's package walk were run and matched.

#### A. Defects

**1. Guide §2.3, `guide/language.md:340`: a refusal the compiler does not make.**
- Quote: "`type Command = Set(key : String, value : String) | Clear` is refused for its `Set`, and the constructor is named otherwise, `Assign`."
- `N/ex1/command.ern` declares exactly that type and matches on `Set(=key)`. `ern build command.ern` exits 0 and `ern run command.erc` prints `a`.
- `N/ex1/command2.ern` uses the constructor `Set` and the prelude's type `Set(String)` in one module. It builds and prints `["a"]`.
- Only a type with one constructor so named is refused, as line 338 says: `type U = Int(Int)` gives `constructor Int is named as the type Int`.
- Fix: drop the sentence, or give an example with one constructor.

**2. Guide §2.9, `guide/language.md:594`: `:browse Prelude` does not list what the sentence says.**
- Quote: "`Some`, `Left`, `spawn` and `send` among them, are the *prelude*'s (report §9), and `:browse Prelude` in the shell lists them."
- `printf ':browse Prelude\n' | ern shell | /usr/bin/grep -c -E 'Some|Left|None|Right'` prints `0`. The listing has `type Optional` and `type Either` and no constructor.
- It also lists `Address.call`, `Address.callForever` and `Io.show`, three names written with a module's name, under a definition that says "without a module's name before them".
- Fix: say that it lists the types by name and that `:doc Optional` shows the constructors, or have it list them.

**3. Guide §8.6 and §10, `guide/language.md:3120` and `:3471`: `libs/ets` is no path of the repository.**
- Quote: "`libs/ets` is such a library, report Appendix G.1".
- `ls libs` in the clone: `No such file or directory`. The library is at `src/libs/ets`.
- Fix: write `src/libs/ets`, linked as the examples are.

**4. Guide §1.2, `guide/language.md:147`: a pointer to a section that says nothing of it.**
- Quote: "the session's number, which counts the sessions a node has had, a plain shell's own being 1 (§9.3)".
- §9.3 never mentions a session's number. A grep for "session" there finds only `$Session1.below` at line 3294.
- Fix: point at the report's section, or give §9.3 the sentence.

**5. The compiler's message for an alias of a type with parameters points the wrong way.**
- At the prompt, `type Alias = Either(String, Int)` answers:
  ```
  input 2:1:27: a constructor has exactly one positional field
    | = help: name the fields, `Either(x : ..., y : ...)`, or hold a tuple, `Either(#(..., ...))`
  ```
- `type Word = String` gets the right help, "there are no type aliases". The alias a newcomer wants is the long one, and I wanted it for `Either(String, Int)`.
- Fix: give the alias help where the one constructor is named as a type in scope, whatever its fields.

**6. `ern doc file.ern` after the guide's own build line says to compile what is compiled.**
- After `ern build --build-root build src` in `N/sheet`:
  ```
  $ ern doc src/grid.ern
  ern doc: no module Src.Cell, which Src.Grid uses: src/cell.erc: no such file or directory; compile Src.Cell first
  $ ern doc --source-root src src/grid.ern
  ern doc: no module Cell, which Grid uses: src/cell.erc: no such file or directory; compile Cell first
  ```
- `build/cell.erc` exists. Only `ern doc --source-root src --build-root build src/grid.ern` works.
- §9.1 (`guide/language.md:3268`) says only "`ern doc file.ern` writes the module's documentation".
- Fix: the message names `--build-root`, and the bullet says that the job reads the compiled forms of what the module uses.

**7. `ern format` breaks a signature inside a type argument.**
- `N/fmt/sig.ern`, `ern format - < sig.ern`:
  ```
  export fn evaluate(expr : Expr,
                     read : (Name) -> Either(String,
                                             Int) receiving e) : Either(String, Int) receiving e =
  ```
- The output is stable under a second format. It is in my program at `N/sheet/src/formula.ern:74`.
- Fix: break before the result type, not inside a parameter's type.

**8. The message for a lambda written with `->` answers another mistake.**
- `N/mistakes/m6.ern`, `List.map(xs, fn(x) -> x + 1)`:
  ```
  m6.ern:3:33: a function's result is annotated with `:`, not `->`
    | = help: write `: T` after the parameters, as a parameter's type is written
  ```
- The slip is the body's `->`, which most other languages write. I wanted no annotation.
- Fix: add "a lambda's body follows `=`".

#### B. Matters of clarity

README:

**9. `README.md:97`: a number without what it counts.** "On Linux a node needs 5.3 or later." 5.3 of what? Fix: "a kernel of 5.3 or later".

**10. `README.md:97` and `:111`: the hardest step of installing has no command.** "OTP 29 is installed as below", and below is "built from its source ... or installed by a version manager such as kerl". This is what put me off. Fix: give the two or three commands.

**11. `README.md:38-51`: the showcase cannot be run from the README.**
- `Peer.spawn("foo", fn() = Counter.count(0), 5000)`: the `5000` is never said, though `1000` is.
- `let far <-` is never said.
- Nothing says how `foo` was started or the two directories made. Line 115 sends the reader to the deployment guide.
- I reproduced the session only with the guide's §8.1, in `N/nodes`.
- Fix: one sentence for `5000` and `<-`, and a pointer to the guide's §8.1 or the tour's chapter 2.

**12. `README.md:13`, `:16`, `:51`, `:78`: claims that open on Erlang.**
- "It exists for two things Erlang does not quite give" opens on what another system lacks.
- "A module is not held to two versions" cannot be read without knowing Erlang's rule.
- "no cookie, no epmd, no mesh" and "without OTP's behaviors" are Erlang's words, unexplained to a reader who knows another language.
- Fix: say what Ernest does first, and gloss or drop the three words.

**13. `README.md:67`: a caveat about a word never introduced.** "The counter runs under no `restarting`: a process under one is back on its old loop at its next fault". `restarting` appears nowhere else in the README. Fix: drop it there; `why.md:49` has it.

Guide:

**14. Comments and operators are never taught.**
- `//` is first used at `guide/language.md:694` with no word. The only "comment" in the guide is at line 3269.
- `/* */` is accepted and unmentioned: `1 /* x */ + 2` answers `3 : Int`, and an open one answers `the block comment never closes`.
- `<=` and `>=` appear nowhere. Unary minus is used at line 800 unsaid. No precedence is given.
- Fix: three sentences in §2.1.

**15. §2.2, `guide/language.md:292`: five contextual words explained by four words not yet taught.** "`compare`, `negate` and `show` stand after the dot of a requirement's member, `needs a.show`, `compare` and `negate` after the dot of a member's name, `fn Coin.compare`". Requirement, member, `needs` and `derives` come in §2.5 and §7.3, and the paragraph gives no pointer. Fix: point at §7.3.

**16. Sentences I read three times.**
- `:73`: "One bound to a name the code never reads is not reported".
- `:592`: "report Appendix E.0's admission rule 2 makes a published specification a library's and no module's vocabulary".
- `:2064`: "A program becomes a package when it names one: a library taken from an archive is a named package of its `package.conf`".
- `:2533`: "A value that is computed, `1024 * 1024`, is a function's, `limit()`, in a module meant for such work".
- Fix: say each plainly, the last as "write it as a function, `fn limit() = 1024 * 1024`".

**17. "Answers" means two things.** The guide's verb for "returns" is "answers" ("`Process.run` ... answers its value", "answers `Some(dir)`"), and `answer(reply, v)` is the reply's one operation. In §4.3 to §4.5 both stand in one paragraph. Fix: "returns" for a function's result.

**18. §3.3 and §3.4, `guide/language.md:719` and `:780`: corners before the thing they are corners of.** The third bullet of *What is polymorphic* (`let empty = fresh()` against `let shared = spawn(...)`) and "One that stands as a type argument is `Never`" rely on addresses and `Never`, which §4.1 teaches. I was lost in both. Fix: move them to §4.1 or behind a pointer.

**19. §4.5, `guide/language.md:1044-1089`: words used before they are said, and a two-file program with no build line.**
- `fault("the gathering ended: ...")` stands in `gather.ern` before §6.3 says what `fault` is.
- `Reason` stands there before §5.2 declares it.
- The program is shown only as `$ ern run collect.erc`, before §7.1 teaches two modules.
- In `N/ex45`, `ern build collect.ern` alone answers `no module Gather, which Collect uses: gather.erc: no such file or directory; compile Gather first`, which helped.
- Fix: a build line, and a pointer for `fault`.

**20. §5.5 and §6.5, `guide/language.md:1511`, `:1525`, `:1925`: "a wrap" as a noun.** It was introduced only as a parameter's name in §5.2. Fix: "the function that makes the message".

**21. §8.1, `guide/language.md:2609` and `:2633`: a number without what it measures.** "On the scale a telling carries, lower is less busy", and `Peer.setUtilization` takes "a number at or above 0.0 on the same scale". `Peer.utilizations()` answered `[#("foo", 0.16666666666666666, 161)]`. I cannot set a number whose 1.0 I do not know. Fix: one sentence on what the scale counts.

**22. §8.2, `guide/language.md:2766` and `:2831`: `Proxy.start(Counter.service, 5000)`.** The `5000` is never said. `:doc Proxy.start` says it is the find's milliseconds. Fix: say so.

**23. §11 and `guide/language.md:93`: "the five principles" are counted and never listed.** The guide cites principle 3, `why.md:399` principle 3 and `faq.md:75` principle 5. A reader of the guide alone never learns the five. Fix: name them in §11, a line each.

**24. §8.5 and §8.6: `ets` is never said to be anything.** "as `ets.ern` does" and "`ets` compares them" assume the reader knows Erlang's tables. Only `faq.md:47` says "the host's table". Fix: three words at line 3035.

**25. §6.3, `guide/language.md:1778-1780`: a trace folds recursion and the section does not say so.**
- `N/tests/deep.ern` faults 21 frames deep in `down`. The trace is `erlang:'div'/2`, `Deep.down:2`, `Deep.main:5`.
- I read it as one call. Only §8.4, line 2902, says "consecutive frames that return to one call counted as one", and of `Code.running`.
- The twelve-line cut is as written: `N/tests/chain.ern` gives twelve lines and `... 8 more frames`.
- Fix: one sentence in §6.3.

**26. §4.4: whether `after` takes an expression is not said.** Every example is a literal. `after Cell.patience` compiles (`N/sheet/src/grid.ern:101`). Fix: say "an `Int` expression".

**27. Two messages that state the grammar and not the mistake.**
- `N/mistakes/m1.ern`, `total = total + 1;`: ``expected `;` or `}` instead of `=` ``.
- `N/mistakes/m7.ern`, `import List`: ``expected a declaration (`export`, `type`, ...) instead of the name `import` ``.
- Fix: "there is no assignment; `let` binds a new name" and "there is no `import`; a module is named where it is used".

**28. §1.2, `guide/language.md:149`: "its `main` running beside the prompt" does not hold for a `main` that reads lines.** `ern shell build/main.erc` on my program answers `the process of Main.main faulted: the shell holds the terminal; run the program with ern run to give it the keyboard`. The message is clear and the guide is silent. Fix: one clause in §1.2.

**29. `:browse OrderedMap` names some first parameters and not others.** `OrderedMap.all(OrderedMap.Map(k, v), test : ...)` stands beside `OrderedMap.contains(map : OrderedMap.Map(k, v), key : k)`. Fix: name each.

#### C. Where the language made the program harder

It was easier than I expected, and these eight are the whole list.

**30. `after` is reserved everywhere, though it stands only in a `receive`.** My one failed build: `src/formula.ern:123:27: \`after\` is a reserved word, and names nothing`, on `let #(digits, after) = ...`. Five other words are "words only where they stand" (§2.2). `after`, `or`, `as`, `when` and `type` are the names a parser reaches for.

**31. A constructor has one positional field or all named ones.** `Add(Expr, Expr)` is refused, so the expression type is `Binary(operator : Operator, left : Expr, right : Expr)`, built as `Binary(operator = Plus, =left, =right)`. The message for it is good.

**32. No type alias.** `Either(String, Int)` is written 20 times in the program, and `OrderedMap.Map(Formula.Name, Entry)` 11 times in `grid.ern`. A wrapper would need unwrapping at each use.

**33. Dropping a value inside a lambda takes a three-line block.** `{ let _ = defined(next, reader); Unit }` at `N/sheet/src/grid.ern:212-215`. The guide writes the same form at lines 1057-1060 and 1614-1617.

**34. No spawn under a service monitor in one step.** `spawn(restarting(...))` and then `monitorService(process, Watched)` at `grid.ern:135-137` leave the gap that §5.2 says `spawnMonitored` exists to close, and that form is for `monitor` only.

**35. A request with a field beside its reply needs a lambda at every call.** `fn(reply) = Define(expr = ..., =sources, =reply)` and its kin, 7 times in the program.

**36. Nested calls have their deadlines staggered by hand.** The grid calls a cell, which calls its readers, so the outer waits are `4 * Cell.patience` and `2 * Cell.patience` (`grid.ern:32`, `:178`), picked by eye.

**37. A `Down` with `Restarted` carries no cause.** The grid knows that a cell restarted and not why. I wanted to show the cause in the cell.

#### D. Names I could not have predicted

| Name | The word I expected | Why |
|---|---|---|
| `answer(reply, v)` | `reply(...)` | the type is `Reply` |
| `adapted(target, f)` | `adapt` or `Address.map` | a participle among `spawn`, `send`, `kill`, `monitor` |
| `restarting(limit, f)` | `restartable` or `supervised` | the same |
| `Down` and its `site` | `Ended` and `spawnedAt` | `Down` is Erlang's word and says nothing to another reader |
| `Left` and `Right` | `Error` and `Ok` | the words do not say which is the failure |
| `Io.show` | `show` or `String.show` | it writes nothing, and `Int.toString` is beside it |
| `Os.environment("HOME")` | `Os.variable` | it reads as the whole environment |
| `Optional.andThen`, `Either.andThen` | `flatMap`, as `List.flatMap` | §2.9 promises one verb per operation |
| `Process.run(f)` | `Process.await` or `Process.call` | "run" says neither that it spawns nor that it waits |
| `monitorService` | `monitorRestarts` | it watches any process restarted in place |
| `List.splitWhile` | `List.span`, or `takeWhile` with `dropWhile` | there is no `takeWhile` |

#### E. Leftovers

I am a cold reader, so each of these is what looks kept from an earlier state, with what I saw and no history.

- **`guide/language.md:340`**, the `Set` and `Assign` sentence (finding 1): a rule the compiler does not hold, beside line 338, which states the rule it does.
- **`guide/language.md:147`**, the `(§9.3)` for the session's number (finding 4): a pointer whose target is gone.
- **`guide/language.md:3120` and `:3471`**, `libs/ets` (finding 3): a path of another layout.
- **`:browse Prelude`** lists `Address.call`, `Address.callForever` and `Io.show`, which `:browse Address` and `:browse Io` list again: one row in two tables.
- **Guide §11, `guide/language.md:3476-3478`**: a section of two sentences, both pointers that line 33, line 93 and §13 already give.
- **Copies in the guide.** The floor is defined at `guide/language.md:2453` and again at `:2478`. `monitorService` is introduced at `:1355` and again at `:1881`. "`Process.status` shows such a queue building" stands at `:1139` and `:1143`.
- **Copies between README and `why.md`.** `README.md:55-65` and `why.md:141-165` hold the same Gleam `Subject` paragraph and the same `other.ern` refusal. `README.md:67` and `why.md:49` hold the same `restarting` caveat.

#### Note

The clone's `ern` says `Ernest 0.11.0-dev, session 1.`, while the README and the guide show `Ernest 0.11.0`, and `VERSION` holds `0.11.0`. I take it for the build before the tag and made no finding of it.

#### Programs tried

- `N/sheet/`: the program, with `budget.txt` and `saved.txt`.
- `N/ex1/`: §1 programs, `command.ern`, `command2.ern`, `in.txt` (the prompt's batch).
- `N/ex4/`: `reset.ern`, `first.ern`, `relay.ern`.
- `N/ex45/`: `gather.ern`, `collect.ern`.
- `N/ex5/`: `jobs.ern`, `firsttwo.ern`.
- `N/ex7/`: `shop/`, `rank.ern`, `killed.ern`.
- `N/ex8/`: `registry.ern`, `client.ern`, `client2.ern`.
- `N/exlb/`: a copy of `examples/lease_broker.ern`, whose deadlock line matches §5.4.
- `N/nodes/`: the two nodes `a` and `foo` on port 18731, `square.ern`, `counter.ern`.
- `N/pkg/`: §9.6's `leaf` and `chart`.
- `N/mistakes/`: `m1.ern` to `m10.ern`.
- `N/tests/`: `checks.ern`, `deep.ern`, `chain.ern`.
- `N/msgs/`: `tf.ern`.
- `N/fmt/`: `sig.ern`.

### L

Counts: 4 defects (L1–L4), 21 matters of clarity and reader's answers (L5–L25), 3 leftovers (L26–L28), 5 places the language or the tools made my own programs harder (L29–L33).

Read whole, in order: `README.md`, `guide/why.md`, `tour/README.md`, `guide/faq.md`, `guide/language.md`, `guide/deployment.md`, at `6c6b8ef1`. Ran with the clone's `bin/ern`: the tour's eight chapters as typed (other ports), the deployment guide's sections 6.3 and 8, the guide's §8.2 store, desk and board on two nodes, and the probes named below. All of these printed what the pages show, but for the numbers in L7 and L19.

Not done: `make lengths` and `make unchecked` (the brief gave no listing), `make install`, the browser shell, the guide's exercises, and any check of the Gleam lines.

Scratch root, written `$L` below: `readers/L`. No process of mine is left running, and the clone's `git status` is empty.

#### Defects

**L1. `README.md:51`, "no cookie".** "They share one TLS connection: no cookie, no epmd, no mesh."
- An Erlang reader runs `ps` on the node first. The bare node `foo` of the tour carries `-setcookie 8caade9c6cb8a8eaed31207fd5ed104c65dd76d35788464c519290ff04228bdc` (read from `/proc/<pid>/cmdline`), beside `-start_epmd false`, `-epmd_module ern_epmd` and `-connect_all false`.
- `guide/deployment.md:178` calls it "its *cookie*", and `guide/faq.md:107` says "The cookie a node's command line carries is no secret and grants nothing".
- "No epmd" and "no mesh" hold. "No cookie" reads as false at the first `ps`.
- Fix: "no shared secret", which the tour's chapter 2 already says.

**L2. `README.md:115`, the four commands do not make the README's own two nodes.** "`ern config --config-dir` makes the node's directory with its key ... each run once for each node".
- No `--listen` is named, and `foo` is a bare node. Followed literally in `$L/readme`:
  ```
  $ ern config --config-dir a; ern config --config-dir foo
  $ ern config --config-dir a --peer-dir foo; ern config --config-dir foo --peer-dir a
  $ ern run --config-dir foo
  ern run: a bare node listens: foo/ernest.conf has no listen
  ```
- The mend is then refused too: `ern config: --listen is not given for a directory that exists: ern config changes nothing in b` (seen on `$L/deploy/b`). The directory is made again and its new key listed again.
- "Each run once for each node" is also off for the README's session: `ern run` and `ern stop` are for `foo` alone, since `a` is the shell.
- Fix: name `--listen address:port` for the node that is dialed, and say that `a` is the shell.

**L3. `guide/faq.md:43` and `guide/why.md:17` promise more of §10 than it holds.** "The guide's §10 says, item by item, what an Erlang programmer finds in place of each part of OTP."
- Counted over `guide/language.md:3432-3474` with `/usr/bin/grep -c`: `global` 0, `pg` 0, `sys` 0, `observer` 0, tracing 0, `application` 0, `gen_statem` 0, `send_after` 0, cookie 0, purge or "two versions" 0.
- §10 maps `erlang:cancel_timer` and not `erlang:send_after`.
- Its *What differs* never says that a module's old versions are never purged, which is the README's second headline against Erlang.
- `global`, `pg`, `sys`, `observer` and releases are answered in the questions only. `gen_statem`, `gen_event`, Mnesia, `dets` and an application's environment are named in none of the six documents.
- Fix: either §10 gains those items, or the two sentences say "§10 and the questions" and no "each part".

**L4. `examples/upgrade/v2/counter.ern:28-29` cites a section that is gone.** "(report §11.2; the deployment guide's §5.3)".
- The deployment guide's section 5 has no numbered parts, and the move is its §6.3, which links this file.
- `$L/scripts/cites.py` checks every guide citation in the six documents, the tour's programs and this example against the headings. This is its one miss.
- Fix: `§6.3`.

#### Clarity, and the reader's answers

**L5. The README's second claim is shown nowhere.** `README.md:16`: "A module is not held to two versions ... where Erlang kills those still running the oldest."
- *Why Ernest* shows two versions, which Erlang holds too.
- The tour has a first-version process alive under the third version at chapter 4's `:reload`, exactly where Erlang's purge would kill it. Its next line kills it by hand (`tour/README.md:216-221`), and nothing says "your language cannot" there.
- Shown in `$L/versions/` (session in `$L/versions/out`): one process spawned on the first load, four edits and reloads, and it answered after each: `Some(2)`, `Some(3)`, `Some(4)`, `Some(5)`.
- Fix: one sentence at chapter 4's reload, before the `kill`.

**L6. First question the README and *Why Ernest* do not answer: what does it cost against Erlang?** `guide/why.md:304`: "`make bench`, in a checkout of the repository, measures a spawn and a monitor so counted against the host's own." No figure is given in any of the six documents.
- My run, with other readers busy on the machine: 200000 spawns, each answered by one message, three runs each.
  - Ernest, `$L/probes/spawn_cost.ern`: 788, 913, 729 ms.
  - Erlang, `$L/probes/erl/spawn_cost.erl`: 216, 219, 233 ms.
- Fix: one measured figure with its machine and day, as the deployment guide gives its own.

**L7. `tour/README.md:540`, "Work anywhere" shows the run where one node does all the work.** "`foo`'s all three times in the run the page shows".
- `bar`'s 0.25 on the page is its reading as it connected, which `guide/deployment.md:218` says "may read busy".
- Typed at once, mine read `[#("foo", 0.0, 974), #("bar", 0.0833…, 130)]` and five of five computes ran on `foo`.
- Six seconds later both read 0.0, and three of six ran on `bar`.
- So a reader typing by hand sees the better picture, and the page prints the worse.
- Also, `Right(8)` is the machine's scheduler count (mine `Right(24)`), which the tour's list of a run's own numbers does not name.
- Fix: show the run after the next telling, or say that a wait of one interval changes it.

**L8. `tour/README.md:634`, the tour's "peak" is the scene Erlang is nearest to.** "*Code travels* at its peak".
- On `foo` the fix arrives as source text from an attached shell and a message. An Erlang reader reads that as a remote shell, `c()` and a message.
- It holds only for an unsupervised process, which the page says three times.
- `$L/probes/upgrade_restarting.ern` shows the limit:
  ```
  after the upgrade: Some(7)
  the process of UpgradeRestarting.main:9 faulted, restarted: a negative amount
  after the fault: None
  and then: Some(1)
  ```
- Chapters 2 and 7, where code crosses to a node with none of it, are what Erlang cannot do, and they are not called the peak.

**L9. The deadlock claim shrinks most on reading.** Title: "A deadlock of the whole program is found" (`guide/why.md:214`).
- A node detects none (`guide/why.md:304`, `guide/deployment.md:84`), and every program an Erlang programmer deploys is a node.
- It is disclosed. What remains is tests and one-node tools, where it is convincing: the tour's planted test faulted as printed.

**L10. "Built for a WAN" is the title I did not believe after the deployment guide's §2.3.**
- The window is 45 to 75 seconds, "measured, the loss came 84.9 seconds" (`guide/deployment.md:186`), and no setting shortens it.
- A local restart "holds ... up until it is given up" behind a silent peer (`guide/language.md:2843`).
- A call "answers only when that wait ends, even where its time ran out long before" (`guide/deployment.md:196`).
- These are the host's `net_ticktime` and busy distribution port, restated.
- What did convince, `$L/hole/prog/silent.ern`, against a peer listed at an address that answers nothing:
  ```
  compute, 1000 ms: Left(Io.Timeout) after 1001 ms
  utilization, 500 ms: Left(Io.Timeout) after 501 ms
  compute, 20000 ms: Left(Io.Unreachable) after 4498 ms
  ```

**L11. `guide/language.md:3459`, read and not shown.** "A `Down` has no order with the last message of the process that ended (§5.2), where Erlang's `'DOWN'` comes after it."
- `$L/probes/down_order.ern`: `result first: 20000, Down first: 0`.
- An Erlang reader trips on a guarantee of the host's that Ernest gives up, with no run that shows the difference.

**L12. `README.md:51` and `tour/README.md:146`, read and not shown.** "the `Get` may reach `foo` before the `Inc` and answer `Some(0)`".
- `$L/race/`: the README's spawn, send and call 150 times, pasted fast, gave `Some(5)` 150 times.
- The README's first session carries a sentence saying it may print something else. Erlang's shell is one process and keeps the order.

**L13. `guide/language.md:1980` and `:1986`, tripped, and both shown.**
- "A sibling that never waits is never restarted ... keeps it down". `$L/probes/busy_sibling.ern`: `answered 3 after 451 ms and 2 calls that answered None`, the faulted child down while its sibling computed.
- "reported `faulted, restarted` ... though the child runs nothing more". `$L/probes/kv.ern`: the third fault's line says `faulted, restarted`, and the next is `Kv.group:11 faulted: supervisor restart limit reached`.

**L14. `guide/language.md:1509` against `:1526`, read and not shown.** "the address keeps nothing alive here meanwhile" and "the process the runtime keeps for the address". A reader takes the two to disagree.

**L15. Where I would close the guide: §4.1's *What receives* and *A process that receives nothing* (`guide/language.md:860-870`), with §4.4's `receiving e+` (`:945`).**
- There are four marks on a type variable: `e`, `e+`, `a=` and `Never`.
- There are three bullets on what fixes `n`.
- `fn stop()` receives nothing while `fn ping()` receives `Int`.
- This is the page where typed Erlangs lost me before. *Why Ernest* lists these costs honestly (`guide/why.md:171`).

**L16. The comparison paragraphs are for another reader.** The README opens on "two things Erlang does not quite give" and spends its one comparison on Gleam's `Subject` (`README.md:55`). `guide/why.md:139-169` gives four paragraphs to `process.new_subject()`, `actor.new` and `Name`. I skimmed both.

**L17. Two sentences of *Why Ernest* I read twice.**
- `guide/why.md:17`: "`sys` is [*Where are `gen_server` and the supervisors?*]..., and the release [...]".
- `guide/why.md:25`: "It stands on the same floor", before a floor is anything.

**L18. First question the deployment guide does not answer: which user runs a node?**
- The unit at `guide/deployment.md:121-134` has no `User=`, so as shown the node runs as root.
- `:43` says "a peer listed may run any code on the node".
- `:162` assumes "one node runs as a service's user".
- Fix: a `User=` line, or a sentence.

**L19. `guide/deployment.md:279`, `:281`, `:448`: `Counter.serve receiving 3120 bytes`.**
- Mine: `114640 bytes` at the first `:processes` on a fresh `b`, `5912` at the second, and `114808` in section 6.3's session.
- `:17` says "Each number quoted names the machine and the day". This one names neither, and the test masks it (`test/ern_deployment_tests.erl:825`).
- Fix: say it is the run's own.

**L20. `guide/deployment.md:97`, tripped.** A changed `listen` or key "it signals with status 0 and the node alone refuses": a reload that is refused exits 0.

**L21. `README.md:97`.** "On Linux a node needs 5.3 or later" gives a bare number. It is Linux 5.3.

**L22. `guide/faq.md:47`, true, and it took three lines to see anything.** "reaches any function of the host's on the node, the host's tracer among them". At a prompt, `erlang:memory/0` declared at `Foreign.Term` prints `<foreign> : Foreign.Term`. I printed it through `io_lib:format/2` and `erlang:iolist_to_binary/1`, each a `foreign fn`.

**L23. Where I would close each page.**
- README: at `:78`, "a plain Erlang node cannot be a peer", with `guide/why.md:17`, "Ernest is for programs written in it from the start". Nobody with an OTP system has an incremental way in. It is said plainly, which I respect.
- *Why Ernest*: at *Abstract types and requirements*, 130 of 435 lines on a question no Erlang programmer asked.
- Tour: nowhere. I slowed at `tour/README.md:371`, the paragraph on which version names a type.
- Questions: at the Emerald, Obliq and spores paragraph.
- Deployment guide: nowhere. Its section 7 table is what I would keep open.

**L24. What Erlang cannot do, and what is restated.**

| | Erlang cannot | Restates what I have |
|---|---|---|
| README | a spawn on a node with none of the code; a send and a wrong-mailbox call refused; more than two versions | `Address.call`; TLS distribution with no epmd and no mesh, which the node's own flags are |
| Why | the foreign check at the crossing (`$L/shim/`: `does not match Either(String, Int): is {ok,42}`); the deadlock trace; a listed key in place of a cookie; abstract types the compiler holds | the `Upgrade` door; selective receive; monitors; the attached shell; the tick window |
| Tour | chapters 1, 2, 5, 6, 7; an address kept through a restart | chapter 3's reload; chapter 4's `kill` and monitor; chapter 8's move |
| Deployment | hash-agreed builds; peers reloaded live; every line with its move | the 1 MB wait; counts never given back; the unit |

**L25. Smaller questions left open.** Where data lives across restarts (a file, by §8.2's example, with no Mnesia or `dets` named), and whether a release can carry its own runtime (`guide/faq.md:51` implies not).

#### Leftovers

**L26. `guide/language.md:3476`, `:222`, `:3324`.** §11 *The design* and §1.4 *A taste of the rest* are two sentences each, and §9.5 is a pointer. They read as sections whose content moved to *Why Ernest*, the tour and the deployment guide, with the numbers staying. §11 and §13 now do one job.

**L27. Two running programs in the guide, read and not shown.** The word counter (§2.10, §3.5, §4.7, §5.6) runs beside the counter that §0, §4, §6 and §8, the README, *Why Ernest* and the tour all use. Does anything still need the first?

**L28. `measures` and the `Utilization` library, read and not shown.** `guide/deployment.md:226` is the only place the six documents name them. They "change nothing of section 3.2's number", and no program on any page reads them.

L4 belongs here too.

#### Where the language or the tools made my programs harder

**L29.** A `Foreign.Term` has no text. `Io.show` answers `"<foreign>"`, so the printer of L22 is needed.

**L30.** `let after = Clock.monotonic()` is refused: `` `after` is a reserved word, and names nothing ``. The pair `before` and `after` cannot be named. The message was clear.

**L31.** No pattern on a string's prefix. `"inc " <> rest ->` gives `expected -> instead of <>` with no help (`$L/probes/habits2.ern`).

**L32.** A call whose answer is an `Optional` has three cases at every site, `Some(Some(value))`, `Some(None)` and `None` (`$L/probes/kv.ern`).

**L33.** A file built from the directory above takes that directory as its program's root. As a node it then reads every `.erc` beneath it and refuses: `ern run: upgrade/v1/counter.erc holds Counter, not Upgrade.V1.Counter; remove it, or keep a build root outside the program's root` (`$L/deploy/stranger/`, met twice). The line names the fix.

#### What convinced me, and whether I would try it

What convinced me:
- Everything on the pages ran as printed.
- The foreign check names `{ok,42}` at the crossing.
- A bare node ran code it never had.
- Five versions lived under one process.
- An unlisted node was refused by its key: `a node with the key 6529… was refused: no peer has its key`.
- Deadlines held against a dead address.
- `ern run hello.erc` took 0.25 s.
- The documents say their limits themselves: no tracing, no `sys`, no upgrade in place under a supervisor.

I would try it for a new, small distributed tool. I would not move an OTP system to it: there is no way in by parts, and supervised processes cannot be upgraded in place.

Other programs: `$L/tour/` (the tour, sessions in `a.out` and `ops.out`), `$L/deploy/` (sections 6.3 and 8), `$L/service/` (§8.2), `$L/why/` (the reload session), `$L/probes/arith.ern`, `$L/probes/foreign_bad.ern`, `$L/scripts/anchors.py` (34 anchors checked, none missing).

### M

**Counts.** Defects: 3 (M1 to M3). Clarity: 18 (M4 to M21). Places the language made my Ernest harder: 5 (M22 to M26). Kept for a reason an earlier milestone had: 3 (M27 to M29). Lines of Gleam that are not Gleam's: 0.

Read as briefed: `guide/style.md`, then `README.md`, `guide/why.md`, `tour/README.md`, `guide/faq.md`, then `guide/language.md` and `guide/deployment.md` whole. `make lengths` and `make unchecked` were not run, since the brief allows no make target; in their place I ran about ninety of the guides' unprogrammed assertions with the clone's `bin/ern`. All but M1 held.

Scratch directory, called `$M` below: `readers/M`

#### Defects

**M1. `guide/language.md:340` (§2.3): the guide says a constructor named `Set` is refused, and it builds.**
- Quote: "a constructor may not take one's name: `type Command = Set(key : String, value : String) | Clear` is refused for its `Set`, and the constructor is named otherwise, `Assign`."
- `$M/t5/command.ern` holds that exact declaration with a `match` on `Set(=key)`. `ern build command.ern` exits 0 and `ern run command.erc` prints `a`.
- `$M/t5/command2.ern` uses the constructor `Set` and the prelude's `Set(String)` type in one module. It builds and prints `1`.
- `$M/t5/command1.ern`, the same type with `Set` as its one constructor, is refused: `command1.ern:1:16: constructor Set is named as the type Set`.
- Report §3.1 refuses only "a type whose one constructor is named as a type in scope", and the guide's own §7.1 says "A module's own name hides the prelude's".
- The sentence states an older, wider rule, so it also belongs with M27 to M29.
- Fix: cut the sentence, or give the one-constructor case, `type Failure = Down(String)`.

**M2. Three places give 45 to 75 seconds as when a silent peer is lost; the deployment guide's §2.3 says the loss can come later, with no bound.** Read and not shown.
- `guide/why.md:206`: "found lost at once, and one that falls silent after 45 to 75 seconds".
- `guide/language.md:2839` (§8.2, *A loss*): "A peer that fell silent is given up in 45 to 75 seconds", followed by "Each node then ends what it held".
- `guide/deployment.md:372` (§7's table): "Nothing came from `b` for 45 to 75 seconds".
- Against them, `guide/deployment.md:186`: "the host closes later, by a time of its own and no bound: measured, the loss came 84.9 seconds after the last traffic". Its `:194` adds that a restart's "new run begins at `the peer b was lost`".
- So the `Down` with `Unreachable` and the held restart follow the later moment, not the window.
- Fix: the three say "found silent in 45 to 75 seconds, and lost when the host closes the connection, which the deployment guide's §2.3 bounds".

**M3. `README.md:51`: "no cookie", and every node's command line carries one.**
- Quote: "They share one TLS connection: no cookie, no epmd, no mesh."
- Shown on my bare node: `tr '\0' ' ' < /proc/3217259/cmdline` held `-setcookie 8caade9c6cb8a8eaed31207fd5ed104c65dd76d35788464c519290ff04228bdc` and `-start_epmd false`.
- `guide/deployment.md:178` describes this cookie, and `guide/faq.md:107` says it "is no secret and grants nothing".
- Fix: the README says "no shared secret", as `tour/README.md:123` does.

#### Clarity

**M4. The headline claim is shown by one toy, three times; what it buys in a real program is asserted.**
- Places: `README.md:57-65`, `guide/why.md:143-165`, `tour/README.md:65-69`.
- Each shows a function of another mailbox type calling `count(0)` directly, and nothing larger.
- The claim's costs are shown in more places than the claim: `tour/README.md:393-411` splits the protocol in two types, `guide/language.md:1041-1091` needs `Process.run` and a helper, and `guide/why.md:171` lists four costs.
- Fix: one refusal from a program of more than a `main`, a helper that receives called from a server's clause.

**M5. `guide/faq.md:17`: the list of what Gleam has and Ernest lacks reads as complete, and I met three more in the first hour.**
- Several positional fields. `$M/t3/point.ern`: `a constructor has exactly one positional field`.
- A sort by a comparing function, Gleam's `list.sort(names, by: ...)`. The library has `List.sort` and `List.sortBy` alone (report E.2); see M24.
- Printing a value in generic code without changing a signature, Gleam's `echo`; see M23.
- Fix: add the three, or write "among them".

**M6. `guide/why.md:399-401`: the requirement claim names no cost, where the mailbox claim has its paragraph at `:171`.**
- The cost I met is M23: one `Io.debug` in a generic function was refused twice up the call chain.
- Fix: one sentence after `:401`, that a generic function that shows a value declares `needs a.show`, and so does each generic caller.

**M7. `README.md:67` uses `restarting` before any text says what it is.**
- Quote: "The counter runs under no `restarting`: a process under one is back on its old loop at its next fault".
- The same caveat stands in seven places: `README.md:67`, `guide/why.md:49`, `tour/README.md:484` and `:634`, `guide/faq.md:41`, `guide/language.md:2904`, `guide/deployment.md:356`.
- Fix: the README drops it, and the tour and the deployment guide keep it.

**M8. `README.md:57-65` shows the refusal of `other.ern`, a file the README does not show.**
- The excerpt's lines 4 to 6 are all of it a reader sees; the program is `guide/why.md:143`'s.
- Fix: show its ten lines, or say where they are.

**M9. The README's session cannot be typed from the README.**
- `$M/t9`: `ern shell --config-dir a` answers `ern shell: a: no such file or directory, which --config-dir names`.
- `README.md:115` gives the four commands in prose and points to the deployment guide. The tour's chapter 2 has the seven commands for exactly this session.
- Fix: point at the tour's chapter 2 beside the session.

**M10. `guide/language.md:1037` (§4.5): "`main` cannot make the call itself" holds only for the order the example chose.**
- Quote: "`main` cannot make the call itself, since the answer comes only after the `Put`, which `main` sends."
- `$M/t9/queue.ern` is the same queue with a `main` that puts and then calls `Address.callForever(queue, Take)` itself. It prints `took 7`.
- Fix: "a `main` that asks before it puts cannot make the call itself".

**M11. `guide/why.md:139`: "the one channel a program makes is a `Reply`", and `adapted` makes another.**
- `guide/faq.md:67` says an Ernest process "hands out such an address where another language opens a second channel".
- `$M/port/scatter.ern` hands three workers `adapted(self(), Squared)` and takes three messages through it.
- Fix: "the one channel a call makes".

**M12. `guide/faq.md:9`: "which being the language buys and a library cannot" is asserted.**
- Three refusals follow it. `guide/why.md:167` concedes the first to `gleam/otp`'s actor, and the third needs nodes.
- Fix: drop "and a library cannot", or say which of the three it means.

**M13. `guide/deployment.md:297` reads as a contradiction.**
- Quote: "No line says how much memory a process holds, and `:processes` shows each process's bytes".
- Fix: "No line of the node's standard error says".

**M14. `guide/deployment.md:178`: a sentence of some 65 words, with "the form's version" and no word of what the form is.**
- The guide's only other use is "compiled form", at `:21`.
- Fix: "the compiled form's version", and the sentence cut in two at "which every node's command line carries".

**M15. `guide/language.md:860` (§4.1, *What receives*): the exception follows the rule unmarked.**
- The rule says a function receives where "it answers the process's own address, as `self` does". The next sentence says `fn stop() = kill(Process.fromAddress(self()))` "receives nothing".
- I did not believe it. The shell answers `stop : () -> Unit`, so it is true.
- Fix: open the second sentence with "The exception:".

**M16. `guide/language.md:868`: the guide prints `(Bool) -> Address(m) receiving m`, and the shell prints `standIn : (Bool) -> Address(a) receiving a`.**
- `guide/language.md:774` says the letters `e`, `m` and `n` are names only, and `a` is none of the three.
- Shown in `$M/t5/inputs.txt`, input 16.
- Fix: write it as the shell prints it.

**M17. Parts long for what they show.**
- `guide/language.md:2398-2430`: `Bag`, a second record of closures straight after `Shape`.
- `guide/language.md:2839-2861`: §8.2 from *A loss* on, seven bold paragraphs and no program. With no distribution of my own I stopped at *A loss*, as its opening line allows.
- `guide/why.md:248-304`: the second deadlock program adds `on` to the first, and five paragraphs of mechanism follow.
- `guide/faq.md:121`: six systems named to answer one question.
- Two headings carry more than they name: §4.5 `Address.call` holds *Pacing* and *Fan-out*, and §5.5 *A process's addresses* holds the alarms and the clock.

**M18. `guide/language.md:73`: "One bound to a name the code never reads is not reported".**
- "One" has no near antecedent. Under the heading **A failure dropped**, the hole in the promise is said in passing.
- `$M/t3/dropped.ern` binds `Fs.write` to an unwritable path to a name it never reads. It builds and prints `saved`.
- Fix: "A failure bound to a name the code never reads".

**M19. `guide/language.md:2902`: "Its printed type ... is not the rule".**
- The shell already says more than the guide quotes. Beneath the type it prints `a primitive: called where it is named; a is the name of a top-level fn and m its mailbox type`.
- Fix: quote that line.

**M20. Nothing says what `Address` in `Address.call` is.**
- `:browse` lists `Address` among the modules. §2.9's list of modules (`guide/language.md:590`) does not, and `:605` names it apart, "`Prelude` and `Address`".
- Fix: name it in §2.9.

**M21. `tour/README.md:371` puts three rules of version numbers in one sentence.**
- Quote: "a trace numbers every version but the first, and a type only one that is no longer current".
- Fix: two sentences, the trace's rule and the type's.

#### Where the language made my Ernest harder

I ported three Gleam habits. Each program ran on its first or second build.

**M22. A wait on my own messages in the caller's process.**
- Gleam: `process.new_subject()`, hand it to N workers, `process.receive` N times, from any process.
- Ernest, `$M/port/scatter.ern`: a `gatherHere` that is `receiving Inbox`, a second function `gather` around `Process.run`, and a `Left(reason)` arm that can only fault. It prints `[1, 4, 9]`.
- `$M/port/here.ern` shows the refusal: `gatherHere needs a mailbox, and main receives nothing`. Its help says "give main its mailbox type", and does not name `Process.run`.
- The guide teaches the pattern at §4.5, *A library that waits*.

**M23. A debug print in generic code changes signatures up the call chain.**
- `$M/t3/debug.ern`: `Io.debug needs a.show, which firstOf does not declare`.
- `$M/t3/debug2.ern`, with that added: `firstOf needs a.show, which firstOfFirst does not declare`.

**M24. No sort by a comparing function.**
- Strings sorted last first took a wrapper type with `fn Descending.compare`, or `List.reverse(List.sort(names))`.
- `$M/t3/desc.ern` prints `["cy", "bo", "al"]` both ways.

**M25. One positional field to a constructor.**
- `$M/t3/point.ern`. The message is good: "name the fields, `Point(x : ..., y : ...)`, or hold a tuple".

**M26. Two Gleam forms the FAQ names as absent fail as bare syntax errors with no help.**
- `$M/t2/prefix.ern`: `"inc " <> rest ->` gives ``expected `->` instead of `<>` ``.
- `$M/t2/labeled.ern`: `area(width = 2, height = 3)` gives ``expected `,` or `)` instead of `=` ``.

#### Kept for a reason an earlier milestone had

**M27. `guide/language.md:3476-3478`, §11 *The design*.**
- Two sentences of pointers. At v0.10.0 it held 543 words, by `git show v0.10.0:guide/language.md`.
- Nothing cites the guide's §11. The heading stays for §12 and §13's numbers, and `guide/README.md:7` still lists "the design" as a part of the guide.
- With it, the guide points at `why.md` and `faq.md` three times: `:33`, §11 and §13.

**M28. `guide/language.md:222-224`, §1.4 *A taste of the rest*.**
- Two sentences. At v0.10.0 it held the two-node session, 177 words, which the README and the tour's chapter 2 now have.
- Nothing cites it.

**M29. `guide/language.md:3324-3326`, §9.5.**
- A pointer to the deployment guide's §1.5. Its one citation is the guide's own `:1782`, which could cite §1.5 directly.

#### The lines of Gleam, checked

Checked against gleam_erlang 1.3.0 and gleam_otp 1.3.0 on hexdocs, their sources (saved under `$M/gleam/`), the language tour and the command-line reference. None is not Gleam's.

- **`process.receive(subject, 1000)` and the panic** (`README.md:55`, `guide/why.md:141` and `:169`). Gleam's source: `panic as "Cannot receive with a subject owned by another process"`. The documents' reading is the `## Panics` section's and the code's. Gleam's own page also keeps an older sentence, "it will not receive a message", two paragraphs above it.
- **"on a named subject receives nothing"** (`guide/why.md:169`): the named branch receives without the owner check.
- **`process.new_subject()`, and `process.spawn` answering a `Pid`** (`guide/why.md:139`): `pub fn spawn(running: fn() -> anything) -> Pid`.
- **`actor.new`, the `Subject` handed to the parent, `Name`, `process.named_subject(name)`, a new process taking a failed one's name** (`guide/why.md:167`): all as Gleam's pages say.
- **"two ways to another order, a subject for each kind or Erlang code"** (`guide/why.md:169`): `send`'s `# Ordering` section, nearly word for word.
- **`process.call` panics at a timeout and at the callee's end** (`guide/faq.md:9`): both are in its `## Panics` list.
- **`Result(value, error)`, `Ok`, `Error`, `Option`, `Nil`, `Pid`** (`guide/faq.md:15`): correct.
- **`gleam add`, labeled arguments, `use`, type aliases, the actor's support for OTP's debugging and tracing, `"inc " <> rest`, the language server, the opaque type, `const`** (`guide/faq.md:17` and `:121`): correct. Gleam writes the word with two l's.

#### Chapter by chapter: what it shows that Gleam lacks, and where it only asserts

**README**
- Shows a spawn on a bare node that carries its code. I ran it: `$M/nodes`, `foo` started in an empty directory, `far : Address(Counter.CounterMsg)`, `Some(5)`.
- Shows the compile-time refusal.
- Asserts the versions side by side, the tour's move, and "no cookie, no epmd, no mesh".

**Why Ernest**
- *Code travels*: two fragments and a shell session. The `:reload` session with `Counter$1` shows what Gleam lacks. The `Upgrade` door shows nothing Gleam lacks, as its own sentence says. `Peer.computeAnywhere` is asserted here and run in the tour.
- *The mailbox in the function's type*: shown, with an honest paragraph on `gleam/otp` and one on costs. Selective receive, the part a `Subject` cannot do, gets one clause. I ran one, `$M/t4/urgent.ern`: `urgent 3`, `normal 1`, `normal 2`.
- *Foreign code is checked*: a fragment and a quoted fault. Gleam's `@external` trusts. I ran it, `$M/t3/hosttime.ern`: `the return of foreign function erlang:system_time/0 does not match String: is 1795714905358994364`.
- *A distribution built for a WAN*: a configuration file, the rest asserted.
- *A deadlock*: shown twice. Gleam has nothing like it.
- *Abstract types and requirements*: the abstract type is Gleam's opaque type, as the FAQ says. `Operations(..Set)` is a fill Gleam lacks. The requirement is below.
- *Little else*: asserted, as `:433` admits.

**The tour**
- Chapter 1 restates what a typed `Subject` gives, and says so, then gives the one refusal.
- Chapter 2 shows the spawn on a bare node.
- Chapters 3 and 4 show the quiet reload, `restarting` with the address kept, and a `Down` as a typed message. Gleam has the last through a `Selector`.
- Chapter 5 shows the deadlock found in a test, and a protocol refused across versions.
- Chapter 6 shows `Peer.spawn` refused for a bound mailbox, and the cost, two types and an adapted address.
- Chapter 7 quotes the foreign check and does not run it. It shows `computeAnywhere`.
- Chapter 8 shows the move from an attached shell. I ran it against `tour/8`'s files, in `$M/nodes/t8`: `Code.running(Counter.count)` went from `[<address.195>]` to `[]`, and `countGuarded` the other way. `apples: 3` was kept, and `inc apples -1` passed over.

**The questions**
- The Gleam answer is fair and names what Ernest lacks.
- *What does a typed mailbox catch, and what does it not?* and *Is a forgotten answer caught?* are the most convincing pages for me, since they say what is not caught.

**The language guide**
- §0 to §3 show nothing Gleam lacks but the refusal of a dropped failure, with M18's hole.
- §4 shows selective receive, the `Reply` kept in a list, and code replacement.
- §5 shows `Process.run` and `adapted`.
- §6 shows `restarting`, `monitorService` and the `Supervisor`. I did not believe "a sibling busy in a long computation keeps it down" (`:1980`). `$M/t4/busy.ern` shows it true: calls at 101 and 602 ms answer `None` while a sibling computes for 3 seconds, and the call at 3604 ms answers `Some(3)`, the two unanswered requests having run.
- §7 shows the requirement, the fill, and the test's mailbox type.
- §8 is all of it beyond Gleam, and §8.2 is long (M17).
- §9 shows the shell.
- §10 is for the Erlang reader. §11 is M27.

**The deployment guide**
- Everything in it is beyond Gleam.
- Its numbers each name a machine and a day.
- I ran eleven of its refusals in `$M/dep`, and each printed the line the guide gives.

#### Does the mailbox in the function's type buy anything over a `Subject`, on the page

Something, and narrower than the README's weight on it.

- **What the page shows it buys.** The wrong-mailbox call is refused at build time, where Gleam panics at the first `receive` with a message that names the cause. And the spawn on a peer of a bound mailbox is refused, which needs nodes.
- **What does not come from the type.** That no process reads another's mailbox follows from `receive` taking no subject. `$M/t1/same.ern`, two processes of one type, shows a function called in the "wrong" process reading its own mailbox, with no error and none needed.
- **What a `Subject` cannot do.** Selective receive over one mailbox. The documents give it one clause in `why.md` and none in the README.
- **What it costs.** The page shows this as plainly: `Process.run` and a helper for a wait of one's own, two types and an adapted address for a protocol with a door, and `receiving e` on every callback (`$M/t2/callback.ern`).

#### Is a requirement convincing as not a type class

- **Convincing** that no program declares a class or an instance for another's type. `guide/why.md:382-395` shows both refusals, and `$M/t2/member.ern` shows that a member is no value.
- **Not convincing** as anything but a type class's constraint over a closed set, which `guide/why.md:399` itself says.
- **The guide's own words describe a dictionary passed unseen**: "the member it was given goes along" (`guide/language.md:2220`), and "the lambdas it makes close over the member it was given with the set" (`:2430`).
- **I did not believe "nothing is invisible" here.** At `sorted([3, 1, 2])` nothing is written, and §2.5's `Rank(1) > Rank(2)` is true by a declaration elsewhere.
- **`needs a.show` is where it bit** (M23).
- The FAQ's "Not as a construct" is the accurate sentence.

#### What convinced me, and whether I would try Ernest

- **The three things I ran that Gleam cannot do each did what the page said, first time**: the counter spawned on a node with none of its code, the same process moved to new code from an attached shell with its tally kept, and the wrong foreign type faulted at the crossing.
- **The documents say what is not caught and what each claim costs**, which a pitch seldom does.
- **The mailbox in the type did not convince me by itself; selective receive did.**
- **I would try it**: the tour's evening, for a program that wants nodes or reload, which I had chosen to do without.
- **I would not move a Gleam program to it.** It has no package manager with hex behind it and no language server. It allows one positional field, has no sort by a comparing function, and passes `needs a.show` through every generic caller.

#### Housekeeping

- Nothing in the clone or in any checkout was edited, and no make target was run.
- One bare node of mine ran, pid 3217259 on 127.0.0.1:47613, ended with `ern stop --config-dir foo` and checked gone.
- An `epmd`, pid 3873608, is not mine and was left alone.
- Shells ran with `HOME` set to `$M/home`.

Programs, all under `readers/M`:
- `t1/`: `counter.ern`, `other.ern`, `same.ern`
- `t2/`: `prefix.ern`, `alias.ern`, `callback.ern`, `member.ern`, `addrkey.ern`, `addreq.ern`, `ping.ern`, `labeled.ern`, `assert.ern`, `never.ern`
- `t3/`: `debug.ern`, `debug2.ern`, `point.ern`, `hosttime.ern`, `dropped.ern`, `desc.ern`, `sig.ern`
- `t4/`: `urgent.ern`, `busy.ern`, `vec.ern`
- `t5/`: `inputs.txt`, `command.ern`, `command1.ern`, `command2.ern`
- `t6/`: `inputs.txt`
- `t7/` and `t7b/`: the module and namespace refusals
- `t8/`: `registry.ern`, `checks.ern`, `killed.ern`, `cycle.ern`, `nopeers.ern`, `forever.ern`
- `t9/`: `queue.ern`
- `port/`: `scatter.ern`, `here.ern`
- `tour/`: chapter 1 at a piped shell
- `nodes/`: `a`, `foo`, `ops`, `foo.log`, and `t8/` with `a.out`
- `dep/`: the deployment guide's refusals
- `gleam/`: `process.gleam`, `actor.gleam` and the two `gleam.toml`, as fetched

### C1

I found 15 things: **5 defects**, **10 matters of clarity**, and **0 things kept for an earlier reason**. The diff deletes the leftovers it made dead itself. I checked each deletion: `resolve({align, …})`, the `leading_break` clauses, `spanned/1`'s `[]` clause and `prune_docs`.

I read the diff `93a13b13..6c6b8ef1` over `src/toolchain/lexer`, `src/toolchain/parser`, `src/toolchain/formatter`, `src/shared` and `editors/emacs`, with the changed tests. Every program and output below comes from the clone's build at `6c6b8ef1`. Scratch directory: `readers/C1` (written `C1/` below). `C1/codepath.txt` holds the clone's code path, `C1/parse.escript` prints a parse diagnostic for each argument, and `C1/old/ern_format.erl` is the formatter at `93a13b13`.

#### Defects

**1. `ern format` is not idempotent for a block comment that ends a bracket's line.**
- **Place:** `src/toolchain/formatter/ern_format.erl:852-854` and `trailing/3` at 940-962.
- **Quote:** `EndsInComment = Cursor2#cursor.previous =:= line`, with the comment "a line comment the bracket's line ends in … ends its line".
- **What is wrong:** a block comment after `(` that ends the line is glued to the first item with no space. Formatting the output again adds the space, so the output is not in the formatter's own layout and `--check` refuses it.
- **Old or new:** the formatter at `93a13b13` does the same. The diff rewrote `trailing/3` and added `EndsInComment` beside it for a line comment only, which left this case as it was.
- **Program:** `C1/idem/glued.ern`, the outputs in `C1/idem/once.ern` and `C1/idem/once_copy.ern`.
  ```

  $ bin/ern format - < idem/glued.ern      # glued.ern: "    f( /* a */\n        x,\n        y)"
      f(/* a */x, y)
  $ ern format --check once_copy.ern; echo $?
  once_copy.ern
  1
  $ bin/ern format - < idem/once.ern
      f(/* a */ x, y)
  ```
- **Same in a broken bracket:** `C1/long.ern` → `C1/long_formatted.ern` gives `someFunction(/* the first */aVeryLongArgumentName,` with the items at column 32. A second format moves them to 33. `C1/idem/both.ern` → `C1/idem/both_once.ern` shows it in a list, `[/* a */x]` → `[/* a */ x]`. The tests cover only `h( /* f */x)` (`ern_format_tests.erl:31`), not a comment that ends the line.
- **Fix:** count a block comment that ends the bracket's line in `EndsInComment`, as §11.6's "A comment … before the first item puts that item on a line of its own" reads. Otherwise keep its space before the next token.

**2. The Emacs mode moves what `ern format` lays out when a block comment stands before the first item.**
- **Place:** `editors/emacs/ernest-mode.el:644-655`.
- **Quote:** `(unless (or (eolp) (looking-at-p "/[/*]")) (current-column))`.
- **What is wrong:** the formatter aligns the further items under the first item after `/* … */`, at column 33. `ernest--first-item-column` returns nil at any comment, so reindenting puts them at the content column, 8.
- **Program:** `C1/blockfirst.ern`.
  ```
  $ bin/ern format - < blockfirst.ern | diff blockfirst.ern - && echo unchanged
  ern format: unchanged
  $ cd editors/emacs && SHOW=1 emacs -Q -batch -l test/reindent.el …/C1/blockfirst.ern
  blockfirst.ern:3: 33 -> 8 |anotherVeryLongArgumentName,
  blockfirst.ern:4: 33 -> 8 |yetAnotherOneThatIsLong)
  2 of 5 lines moved, 1 of 1 files touched
  ```
- **Where it comes from:** the Emacs rule dates from `db4dcb4c` (2026-09-27). The diff's log entry, *The Front End's Lines*, says "the Emacs mode reindents that layout unmoved", and that holds only for the line comment.
- **Fix:** make one rule for both tools. Either the formatter puts the first item on its own line after any comment, as finding 1's fix would and as §11.6 reads, or the Emacs mode returns nil only at `//`.

**3. A mark before `receiving`, `<-` or `needs` is misnamed, and a field's mark is not given §4.7's words.**
- **Place:** `src/toolchain/parser/ern_parser.erl:604-613`.
- **Quote:** `unmarked_before_body({#t_var{…}, [{'=', MarkPosition}, {'=', _} | _]}, Marks)`.
- **What is wrong:** only `a= =` gets the mark's words. Every other place a marked variable can end a type falls through to a generic message at the wrong token. `fn f(x : a=)` gets the mark's words, but a constructor's field does not. This is a user-facing hole in the change *The Parser Held to Appendix A* made.
- **Program:** `C1/parse.escript`.
  ```
  fn f() : a= receiving m = 1      -> t.ern:1:13: expected an expression instead of the reserved word `receiving`
  fn f() = { let x : a= <- y; x }  -> t.ern:1:23: expected an expression instead of `<-`

  fn f() : a= needs a.compare = 1  -> t.ern:1:19: the name `a` cannot follow an expression
                                      help: a call is written `f(x)`, and statements are separated by `;`
  type Box(a) = Box(value : a=)    -> t.ern:1:28: expected `,` or `)` instead of `=`
  fn f(x : a=) = 1                 -> t.ern:1:10: the equality mark is written in a foreign function's parameters alone
  ```
- **Fix:** make `unmarked_before_body` also match `=` followed by `<-`, `receiving` or `needs`. Read a field's annotation through the same refusal as a parameter's.

**4. A `;` in a list or a bitstring names the close alone, where a tuple and a call name both.**
- **Place:** `src/toolchain/parser/ern_parser.erl:1786-1791` and `bit_segments/2` at 1700-1703.
- **Quote:** `expect_after_items([{')', _} | Rest])` and `{Segments, expect(Rest, '>>')}`.
- **What is wrong:** §11.5's form, which the diff's log entry gives, says "``expected `,` or `)` `` stands where a list of items may go on". The list `]` and the bitstring `>>` use plain `expect`. `match x { [a, b; c] -> 1 }` reads "expected `]`" the same way.
- **Program:** `C1/parse.escript`.
  ```
  fn f() = [1, 2; 3]    -> t.ern:1:15: expected `]` instead of `;`
  fn f() = <<1, 2; 3>>  -> t.ern:1:16: expected `>>` instead of `;`
  fn f() = #(1, 2; 3)   -> t.ern:1:16: expected `,` or `)` instead of `;`

  fn f() = g(1, 2; 3)   -> t.ern:1:16: expected `,` or `)` instead of `;`
  ```
- **Fix:** give `expect_after_items` the closing symbol, `expect_after_items(Tokens, Close)`, and use it for `]` and `>>` in expressions and patterns.

**5. The requirement's message and help write source text without backticks.**
- **Place:** `src/toolchain/parser/ern_parser.erl:513-517`. The diff rewrote this line.
- **Quote:** `"expected `.` after " ++ atom_to_list(Variable) ++ " instead of "` and `"… as needs a.compare"`.
- **What is wrong:** the variable reads as the article "a". Every other help the diff wrote quotes source, for example ``write `a`; ``.
- **Program:** `C1/parse.escript`.
  ```
  fn f(x : a) : a needs a = x -> t.ern:1:25: expected `.` after a instead of `=`
                                 help: a requirement names a member of a type variable, as needs a.compare
  ```
- **Fix:** write ``after `a` `` and ``as `needs a.compare` `` in all three clauses.

#### Clarity

**6. `ern_ast:type_text/1` copies the emitter's function.**
- **Place:** `src/toolchain/parser/ern_ast.erl:148-175`.
- **What is wrong:** it is a new clause-for-clause copy of `ern_docs:syntax_text/1` (`src/toolchain/emitter/ern_docs.erl:270-287`), the same five clauses and the same §3.4 parenthesis rule. The only difference is `written` against `namespace`, and the result is a string rather than an iolist.
- **Fix:** keep one function that takes which namespace to print, and let `ern_docs` call it.

**7. Raw `element/2` stands beside the new token accessors.**
- **Place:** `ern_lexer.erl:195`, `ern_format.erl:49` and `:143`, `ern_parser.erl:509`, `:536` and `:862`.
- **Quote:** `element(2, Token)` and `element(1, Token) =/= comment`.
- **What is wrong:** the diff added `ern_lexer:symbol/1` and `position/1` and moved 63 sites in the formatter and the parser to them. These six still reach into the tuple, so one thing is read two ways.
- **Fix:** use `ern_lexer:symbol/1` and `ern_lexer:position/1` at the six sites.

**8. The `ern_diagnostic` header overclaims.**
- **Place:** `src/shared/ern_diagnostic.erl:3-5`.
- **Quote:** "A source's lines are counted here once, for the lexer, the excerpt and the formatter alike."
- **What is wrong:** the lexer counts its own lines. It calls only `without_bom/1` and `without_return/1` (`ern_lexer.erl:69, 76, 219, 220`). `source_lines/1` serves the excerpt and the formatter (`ern_format.erl:168`).
- **Fix:** "A source's lines are cut here, for the excerpt and the formatter, and the lexer reads each line's end as they do."

**9. The `#lexing` record rebuilds a constant on every call under a comment about options.**
- **Place:** `src/toolchain/lexer/ern_lexer.erl:46-49, 66`.
- **Quote:** "What a call reads under its options, read once" and `symbols = [{Text, list_to_atom(Text), length(Text)} || Text <- ?SYMBOLS]`.
- **What is wrong:** the symbol table does not depend on the options. It is rebuilt on every `tokenize/2`, and the shell calls that per line.
- **Fix:** make the table a macro or a function of `?SYMBOLS` outside the record, and keep the record to the two options.

**10. The lexer writes a `\u{…}` escape that the code already has.**
- **Place:** `src/toolchain/lexer/ern_lexer.erl:96-98`.
- **Quote:** ``io_lib:format("a string or a character literal writes it `\\u{~.16B}`", [Char])``.
- **What is wrong:** `ern_literal:escape/2` writes the same escape.
- **Program:** `C1/texts.escript`.
  ```
  lexer help: a string or a character literal writes it `\u{1B}`
  ern_literal:escape/2: \u{1B}
  lexer help: a string or a character literal writes it `\u{9B}`
  ern_literal:escape/2: \u{9B}
  ```
- **Fix:** build the help from `ern_literal:escape(Char, none)`.

**11. `parenthesized/4` builds a node only to get a span.**
- **Place:** `src/toolchain/parser/ern_parser.erl:826-832`.
- **Quote:** `{#t_var{span = Span}, _} = spanned({Variable#t_var{span = Position}, Rest})`.
- **Fix:** compute the span from `Position` and the closing token directly, as `mark_span/2` does.

**12. The Emacs tests give one prefix to shared helpers and to each file's own.**
- **Place:** `editors/emacs/test/check.el:12-22`, `color.el:39`, `format.el:17`, `half_typed.el:38`, `typing.el:29, 40, 73`, and the variables `ernest-test-source` and `ernest-test-expected`.
- **What is wrong:** `check.el`'s `ernest-test-fail`, `-want` and `-finish` read as one family with `ernest-test-part` and `ernest-test-next-column`, which belong to single files. `-source` and `-expected` do not say whose source or what is expected. `docs/design/emacs_mode.md:33` names `check.el` but no prefix.
- **Fix:** keep `ernest-test-` for `check.el`'s functions, and give each file's own names that file's word, such as `ernest-typing-part`.

**13. A test hand-counts the code path's flags.**
- **Place:** `src/shared/test/ern_tree_tests.erl:36-37`.
- **Quote:** `-- ["-pa", "-pa", "-pa", "-pa", "-pa"]`.
- **What is wrong:** the count must track `tools/code_path.sh`'s five patterns by hand.
- **Fix:** `[Arg || Arg <- Lines, Arg =/= "-pa"]`.

**14. The `lines/1` comment names one line.**
- **Place:** `src/shared/ern_diagnostic.erl:96-97`.
- **Quote:** "a line of an excerpt, each character shown as one column".
- **What is wrong:** the function returns every line of the source.
- **Fix:** "Report §11.5: the source's lines as an excerpt shows them, each character one column (shown/1)."

**15. The `symbol/1` comment cites the report for an Erlang tuple.**
- **Place:** `src/toolchain/lexer/ern_lexer.erl:503-504`.
- **Quote:** "Report §2: a token is {Symbol, Position} or {Symbol, Position, Value}".
- **What is wrong:** §2 (`report/language.md:84-175`) defines lexical elements, not this tuple's shape. Read and not shown beyond that quote.
- **Fix:** drop "Report §2:" and say the token's shape is the lexer's own.

#### Scratch files
- **Programs:** `C1/parse.escript`, `C1/fmt.escript`, `C1/texts.escript`, `C1/codepath.txt`, and `C1/old/ern_format.erl` (the formatter at `93a13b13`).
- **Inputs:** `C1/brackets.ern`, `C1/long.ern`, `C1/blockfirst.ern`, `C1/hug.ern`, `C1/idem/glued.ern` and `C1/idem/both.ern`.
- **Outputs:** `C1/brackets_formatted.ern`, `C1/long_formatted.ern`, `C1/hug_formatted.ern`, `C1/idem/once.ern`, `C1/idem/once_copy.ern` and `C1/idem/both_once.ern`.
- **Diffs I read:** `C1/parser.diff` and `C1/parser_tests.diff`.

`hug.ern` shows that a line comment after `(`, `#(` or a constructor's or a pattern's bracket is laid out a step in, stays the same on a second format, and is not moved by the Emacs reindent. That part of the change holds.

No process of mine is left running.

### C2

The checker, `src/toolchain/checker/` and its `test/`, over the diff `93a13b13..6c6b8ef1`, in the clone at `c`.

**Counts:** 5 defects (4 shown by a program, 1 read and not shown) and 11 clarity findings (earlier milestones' leftovers among them).

All paths below are under the clone, and every scratch program is under `readers/C2/`, abbreviated `R/` here.

#### Defects

**D1. `later_use/3` labels a use of a different variable with the same name.** Place: `src/toolchain/checker/ern_typecheck.erl:3406-3428`.
- Quote: `Use = fun(#e_call{... callee = #e_var{... name = Used, referent = var}}, Acc) when Used =:= Name ->`, run as `ern_ast:walk(Use, Body, [])` over the whole body.
- What is wrong: the label meant for "the first use of the local a `let` binds" picks the first node with that name anywhere in the body, by position. It ignores scope, so a use of an earlier binding of the same name (a parameter, an outer `let`) gets the label and is described at the new local's type.
- Program, `R/later_use/main.ern`:
  ```
  fn f(eq : Int) : Bool = {
      let n = eq + 1;
      let eq = same;
      eq(Int.abs, fn(x : Int) = x) && n > 0

  }
  ```
  `ern build main.ern` gives:
  ```
  main.ern:5:14: (Int) -> Int, a function type, does not support equality, which same requires: same : (a=, a=) -> Bool
  4 |     let n = eq + 1;
    |             -- this use takes eq at ((Int) -> Int receiving e, (Int) -> Int receiving e) -> Bool
  5 |     let eq = same;
  ```
  The labeled `eq` on line 4 is the `Int` parameter.
- Fix: look for the use only in the statements after the `let` in its own block, with `ern_ast:free_uses/2`, which honors shadowing.

**D2. A type variable with no name of its own still takes a name the signature uses, except in `holder_text/5`.** Place: `src/toolchain/checker/ern_typecheck.erl:4488` is the only call of `names_in_scope/1`. `unify_message`'s `format_pair/4` and ern_bound's `capture_crosses` format with no `InScope`.
- What is wrong: §11.5 and the comment on `unnamed_variable_avoids_names_in_use_test` say such a variable "takes no name an annotation's variable keeps, in the type printed and in the signature around the error". That holds only when the signature's own variable is also printed in the same message.
- Programs:
  - `R/probes/n1.ern`, `fn f(x : a, ys) : Int = { let g = fn(y) = #(y, ys); g }`, gives `expected Int, found (a) -> #(a, b)`. The variable printed `a` is not the signature's `a`.
  - `R/probes/n2.ern`, `fn f(x : a) : Int = { let g = fn(y) = #(y, x); g }`, gives `found (b) -> #(b, a)`, which is right because the signature's `a` is printed.
  - `R/probes/b5.ern`, `fn start(x, z : a) : Unit = { let _ = Peer.spawn("w", fn() = receive { y -> if y == x then Unit else Unit }, 1000); Unit }`, gives `captures x, whose type a= holds a type variable`. Here `a=` is x's own variable, not z's `a`.
- Fix: pass `names_in_scope(Env)` through every format of a message about the definition (`unify_message`'s pair, ern_bound's `capture_crosses` and `mailbox_crosses`), or hold it in the type state for the length of the definition.

**D3. `distinct_param_names/1` reports the alphabetically first of two repeated names, not the first one written.** Place: `src/toolchain/checker/ern_typecheck.erl:2661`.
- Quote: `Binders = lists:ukeysort(1, [{Name, Span} || {Name, Span, _} <- ern_ast:pattern_binders(Pattern)])`.
- Program, `R/probes/d3.ern`, `fn f(a : Int, b : Int, #(b, a) : #(Int, Int)) : Int = a`, gives:
  ```
  d3.ern:1:29: parameter a appears twice
    |      - first bound here
    |                             ^
  ```
  The repeated `b` at column 26 is written first and is not the one reported.
- Fix: `lists:keysort(2, lists:ukeysort(1, ...))`, which drops repeats inside one parameter (that pattern's own error) and keeps the order they are written in.

**D4. The interface read promises more than it checks.** Place: `src/toolchain/checker/ern_interface.erl:41-43`, `%% and an interface whose fields are not what this build writes is another build's`, and the comment on `malformed_interface_test`, `reads as another build's, ... and raises nothing`.
- What is wrong: `read/1` checks only the record's arity and that each field goes through `maps:from_list`. A `back_end` value that is no `#back_end{}` reads as `ok` and raises later in the checker.
- Program, `R/crafted/crafted.erl`: it encodes the interface of `export fn f() : Int = 1`, sets `back_end` to `[{['M', f], garbage}]`, then runs `ern_interface:read/1` and `ern_typecheck:with_interfaces/2`. It ran with the clone's code path from `tools/code_path.sh`:
  ```
  read: ok
  with_interfaces: error:function_clause {ern_typecheck,'-honored/3-fun-0-',[garbage],[{file,".../ern_typecheck.erl"},{line,843}]}
  ```
- Only a crafted `.erc` reaches this.
- Fix: narrow both comments to what is checked, "whose fields are no lists of pairs". Or, in `interface/1`, check that every `back_end` value is a `#back_end{}`.

**D5 (read and not shown). The `none` returned by `ern_types:annotation_name/2` for "no name" is also a name a user can give a type variable.**
- Places:
  - `src/toolchain/checker/ern_bound.erl:486-495`: `Written = ern_types:annotation_name(Mailbox, TypeState)`, then `{variable, {tvar, _}} when is_map_key({annotation, Written}, Scope)`.
  - `ern_typecheck.erl:4549-4551`, `names_in_scope/1`: `Name =/= none`.
- What is wrong:
  - In a signature that writes a type variable named `none`, a mailbox variable with no name would be labeled "the signature writes none here", with the help "write the mailbox type in place of none".
  - `names_in_scope` drops a signature variable that really is named `none`.
- Not shown: I tried `R/probes/b4.ern`, `b6.ern` and `b11.ern`. Each hit another refusal first, or a mailbox already settled to Never.
- Fix: have `annotation_name/2` answer `{ok, Name} | none`, or guard `Written =/= none`.

#### Clarity, and what earlier milestones left

**C1. Two mailbox reasons that nothing reads apart any more.** Place: `src/toolchain/checker/ern_types.erl:215-233`. The comment reads `which is which decides between none_where_mailbox_needed and mailbox_where_none_needed`, and `unify_resolved` passes both atoms to `bind_variable`.
- Their `format_error` clauses are gone in this diff. `unify_message` (`ern_typecheck.erl:8111-8113`) maps both, and `{none_vs_mailbox, _}`, to the same `none_vs_mailbox/6`.
- Fix: one reason, `{none_vs_mailbox, Type}`, the comment's sentence dropped, and `ern_types_tests.erl:49,57` updated.

**C2. `diagnostic/2` has one caller left.** Place: `ern_typecheck.erl:623`, `diagnostic(Span, Message) -> #diagnostic{span = ern_diagnostic:span(Span), message = Message}.`
- It converted the old three-tuple, which the diff removed. Its only caller is `depends_on_itself` (`:2285`).
- Fix: build the `#diagnostic{}` in place there and remove the function.

**C3. New test comments name review probes, which `docs/code_style.md:20` forbids** ("A comment names no MVP, milestone, plan item, review finding or date ... It cites ... the log entry by its title").
- Places:
  - `ern_typecheck_tests.erl:1775`, `(cold42/t1, t4, cold2/work/n1, n4)`
  - `:1851`, `(cold42/t1's third.ern, cold3/CA/t10b, t11b, cold1/n5)`
  - `:5124`, `(cold2)`
  - `:889`, `:1526` and `:3512`, "the cold reading's"
  - `ern_canonical_tests.erl:269` and the diff's `ern_typecheck_tests` line 625, "the fix of the full review"
- `:6835`, "the log's *Leg 4's Answers*", is the right form.
- Fix: replace each with the title of its log entry, or with "a regression test" alone.

**C4. The glossary still describes a removed field.** Place: `docs/code_style.md:198`, **Recorded, Printing**, which says definitions record "their printing" and foreign declarations "their schemes and printing".
- `include/ern_canonical.hrl` dropped `printing` from `#definition{}` and from `#recorded{}`'s comment.
- Fix: remove both mentions of printing from the entry, and rename the entry to **Recorded** if Printing then names nothing.

**C5. `#back_end.position` holds two different shapes.** Place: `include/ern_types.hrl:137-141`: `position: pos_integer() ... in a checker's environment {namespace(), pos_integer()}`. `add_interface` writes `Facts#back_end{position = {Namespace, Number}}`.
- Fix: keep `position` as the number alone and hold the declaring namespace beside it (the env's `declaring`, or a field of its own).

**C6. The three resource message types are tested in four places** in `ern_bound.erl`: `resource/1` (:82), `resource_message/1` (:91), `bound_leaf`'s guard (:59) and `mailbox_crosses`'s guard (:506-507), which then calls `resource_message/1` again.
- Fix: one `case resource_message(T) of {Phrase, Held} -> ...; none -> ... end`, with `resource_message` answering `none` for any other type.

**C7. The name `restore_scope` is used to clear the scope.** Place: `ern_typecheck.erl:1535`, `restore_scope(run_group(Group, restore_scope(Env, #env{})), Env)`. The inner call clears the scope by "restoring" an empty `#env{}`.
- Fix: a `cleared_scope/1` named for what it does.

**C8. Two helpers repeat a lookup at a made-up position.** Place: `ern_typecheck.erl:4945` and `:4956`. `declared_scheme/3` and the new `declared_referent/3` each do `try lookup_value({1, 1, {1, 1}}, Namespace, Name, Env) of` with the same catch.
- Fix: one `declared_value/3` that returns what both take parts of.

**C9. An atom is passed only to reach the error clause.** Place: `ern_canonical.erl:1385` and `:1397`, `read_recorded(other)`, to fall into the last clause.
- Fix: a named `other_version()` that returns the error.

**C10. A note writes `fn` without backticks.** Place: `ern_bound.erl:201`, `"a primitive: called where it is named; a is the name of a top-level fn and m its mailbox type"`.
- The same module writes "a top-level `fn`" in its help (:144), and §11.5 puts source text in backticks.
- Fix: "a top-level `fn`", with the line the shell test quotes updated to match (ern_shell_tests, about :5810).

**C11. A short line after a reflow, and a comment that describes the input.**
- `ern_resolve.erl:10`: the reflow left the short line `%% reads each name whole. The pass`.
- `ern_scope.erl:161`: `%% The names of variables each with where it is bound.` sits over `names(Variables) -> [Name || {Name, _} <- Variables].`, which drops where each is bound.
- Fix: refill the paragraph, and change the comment to "The names of Variables, each held with where it is bound."

#### Checked and dropped

- The merge order in `ern_types:format/3` and `format_pair/6`, `maps:merge(in_scope(InScope), claimed(...))`, would let a name the type claims override one in scope. But within a definition one written name is one variable, and an instance keeps none of its scheme's names (`R/probes/m4.ern` prints `shown needs a.show` for the callee's `k`). So the two maps cannot disagree.
- §5.9 witnesses (`R/p1/main.ern`, "missing Dot, Circle(_), Blob(_) and more") and another module's witnesses in shortest form (`R/probes2/top/{util,main}.ern`) match the report.
- The new helps in `R/probes/p1.ern` to `p6.ern`, `r1.ern` to `r4.ern`, `c1.ern` to `c6.ern` and `s1.ern` to `s5.ern`, and the shell's receive helps, read correctly.
- The clone tables (`ern_typecheck_tests` 5325-5372, `ern_prelude` 609-636) are data rows, so no finding.
- No checker test is among the slowest.
- No processes of mine remain.

Diffs read are kept under `R/diffs/`.

### C3

**Counts.** 1 defect, which is a place where the report is silent. 12 matters of clarity.

**Scope.** I read the emitter's diff `93a13b13..6c6b8ef1`, in `ern_emitter.erl`, `ern_compile.erl`, `ern_descriptor.erl`, `ern_docs.erl`, `include/ern_unit.hrl` and `test/ern_emitter_tests.erl`. Each changed function was read whole as it stands, with its callers where needed. The checks were made against `docs/code_style.md`, §12.3, §11.5, §4.5, §8.4 and Appendix H.

The emitter's EUnit suite at the commit passes: "All 235 tests passed." It was run from a copy of the clone, `readers/C3/tree`, with its output in `readers/C3/emitter_tests.out`. The first try from `readers/C3/run` failed on the tests' relative paths. The tests the diff removed (`call_ends_with_callee`, `sleep_*`, `cancel`, `maps_sets`, `random`, `clock_path`, `io_write_*`, `preemption_and_precision`, `kill_dead`, `kill_by_identity`) all stand now in `src/runtime/test/ern_rt_tests.erl` or `ern_stdlib_tests.erl`. `todo_is_unknown` stands in `ern_typecheck_tests.erl:4833`, so no coverage was lost. No processes of mine are left running.

Programs, each under `readers/C3/`:
- `vars/main.ern` and `order/main.ern`: variable order in a cause.
- `parts/main.ern`: a return's parts, Unit and Bool; `main.erl` emitted.
- `restricted/main.ern`: `a=` in a cause.
- `append/main.ern`: List `<>`; `main.erl` emitted.
- `exposer/main.ern`: the exposer's unused Bound; `main.erl` emitted.
- `call/main.ern`: `Address.call`'s target; `main.erl` emitted.
- `fields/main.ern`: named fields' order, with a shell run.
- Diffs: `emitter.diff`, `compile.diff`, `tests.diff`.

#### Defects

##### 1. The report is silent: a cause writes an equality-marked variable as `a=`
- **Place:** `ern_emitter.erl:2392` `printed/2`, rewritten by the diff under §12.3. It keeps `ern_types:fresh(Acc, maps:get(Number, Restrictions, []))`. The header comment at lines 63–66 says "restrictions: … by which a check's cause prints it (§11.5)".
- **What is wrong:** §12.3 says "a type variable in it is written `a`, `b` and on in the order the variables stand in the type". The cause writes `a=`, which is §11.5's diagnostic mark. It writes it in the result type, the one place the declaration refuses it. The report does not say whether a cause shows the mark, and no test holds either form.
- **Shown:** `restricted/main.ern` is `foreign fn same(x : a=, y : a) : List(a) = "erlang:max/2"`. Its run prints `the return of foreign function erlang:max/2 does not match List(a=): is 2`. Writing `List(a=)` in the declaration is refused: `a foreign function's result type takes no equality mark`.
- **Fix:** the user decides. Either §12.3 gains a sentence that a cause writes §11.5's marks, or `printed/2` drops the restrictions, and with them the `restrictions` field of `#emit_context{}`, and a test holds the choice.

#### Clarity

##### 1. `#emit_context.printing` is a copy of `unit.link.printing`
- **Place:** `ern_emitter.erl:97` (the field) and `:336` `own_context`: `printing = Unit#unit.link#link.printing`. It is read only in `printed/2` at `:2392`, which also matches `unit = Unit`.
- **What is wrong:** `entering/4` and `foreign_function/2` used to set a printing for each definition, and 3963c3cf removed that. The field is now set once from the unit the context already holds. It also means `printed/2` calls `from_root/2` again at every check.
- **Fix:** drop the field and the header comment at lines 62–63. Better still, store `ern_types:from_root(Session, Printing)` once in `own_context`, so `printed/2` reads only its own fold.

##### 2. Comments the diff made wrong
- **`ern_emitter.erl:2614`:** "a check's cause, its Prefix and the type as §11.5 prints it". The type is now written whole from the root, as §12.3 says. Fix: "as §12.3 writes it (printed/2)".
- **`ern_compile.erl:443` (link/5):** "and the state a type prints under from the module (§11.5)". Its one reader prints from the root, and `ern_unit.hrl:79` already says §12.3. Fix: "the state a check's cause prints its types under (§12.3)".
- **`docs/code_style.md:198`, glossary *Recorded, Printing*:** "its definitions with their sourced forms, their names and their printing … its foreign declarations with their schemes and printing". The diff removed `printing` from `#definition{}`, `#foreign_function{}` and `recorded/2`. Fix: drop both mentions of printing, and with them the word *Printing* in the heading.

##### 3. `prelude_targets_test` still treats List's `<>` as a module function
- **Place:** `test/ern_emitter_tests.erl:4629–4643`. `is_inline([TypeName, '<>']) -> TypeName =:= 'String' orelse TypeName =:= 'Bytes'`, and `prelude_target`'s comment says "Float's operators, and the `<>` of List and Path, their modules' functions".
- **What is wrong:** the diff made List's `<>` the host's `++` (`binop` at `:2202`, and `appended_in` excludes it). The test now checks that `ern@list` exports a function that no emission calls.
- **Shown:** `append/main.erl` line 9 is `'$1'(Xs_1, Ys_2) -> Xs_1 ++ Ys_2.`. An `erl` run over the clone's `build/` lists `ern_prelude:values()`'s `<>` names as `['String','<>'],['List','<>'],['Bytes','<>'],['Path','<>']`, each with `primitive/1` = `none`.
- **Fix:** add `'List'` to `is_inline`'s `<>` clause and its comment, and leave only Path in `prelude_target`'s comment.

##### 4. `ern_compile:qualified_name/3`, new in the diff, is a third copy of one rule whose copies must agree
- **Place:** `ern_compile.erl:414–415`. The same two clauses are `ern_canonical.erl:313–314` `qualified/3` and `ern_typecheck.erl:1560–1561` `value_qualified_name/3`.
- **What is wrong:** `foreign_functions/3` does `maps:get(QualifiedName, ForeignSchemes)` on a map that `ern_canonical` keyed with its own copy. If the two copies differ, the build crashes.
- **Fix:** export `ern_canonical:qualified/3` (or the checker's) and call it from `ern_compile`.

##### 5. The two describers still copy the recursive-type wrap
- **Place:** `ern_descriptor.erl:112–115` and `ern_emitter.erl:2745–2748`. Both read `Descriptor = case …refers(Sum, Id) of true -> {mu, Id, Sum}; false -> Sum end`.
- **What is wrong:** the module comment says the two "share how … a recursive type [is] described", but they share only `refers/2`, and the wrap is still written twice.
- **Fix:** export `ern_descriptor:recursive(Id, Sum)` in place of `refers/2`, and call it from both.

##### 6. `primitive/1`'s arity for `Address.call` and `callForever` is not the arity a program's call reaches
- **Place:** `ern_emitter.erl:1717–1718`, `{call, 3}` and `{call_forever, 2}`, under the comment "the function of ern_rt's a call of it calls and that function's arity, a spawn's site among its parameters".
- **What is wrong:** a program's call passes the check as well, so it calls `call/4`. Spawn's arity counts its extra site, but these two do not count their check. So `prelude_targets_test` checks `call/3`, which only the standard library calls.
- **Shown:** `call/main.erl` lines 23–26: `ern_rt:call(A_3, fun …, 100, {int, <<"reply does not match Int">>})`.
- **Fix:** have the comment say these arities are the standard library's call, or give `{call, 4}` and `{call_forever, 3}`.

##### 7. The maker's unused Bound is `_` and the exposer's is not
- **Place:** `ern_emitter.erl:2552`, `MakerBound = case lists:any(fun crosses_from/1, ParamDescriptors) of … erl_syntax:underscore()`, new in the diff. Beside it, `:2582` `Exposer = …clause([Function, Bound], …)` always binds `Bound`.
- **Shown:** `exposer/main.erl` (`applied(f : () -> Int, …)`) holds `fun (Function, Result, _) ->` beside `fun (Function, Bound) ->`. Running `erlc +warn_unused_vars main.erl` gives `main.erl:65:21: Warning: variable 'Bound' is unused`.
- **Fix:** treat both alike: one helper that writes `_` where the body reads nothing, or `Bound` in both.

##### 8. The returned term is named two ways in `check_form`
- **Place:** `ern_emitter.erl:2425` uses `fresh_variables(1, "Returned", …)` for Unit. `:2433` uses `fresh_variables(2, "Checked", …)` for a word, where the second variable is the returned term.
- **Shown:** `parts/main.erl` has `Returned_18 ->` for Unit beside `Checked_24 ->` for Bool, the same role in each.
- **Fix:** `named_variables(["Checked", "Returned"], Context)`.

##### 9. Two new names say too little or collide
- **`ern_emitter:compiled/3` (`:255`):** it returns `{DefinitionFunctions, ForeignForms, InitFunction, Context}` and sits beside `ern_compile:compiled/2`, which is the host's compile. Fix: `unit_functions/3`.
- **`bound/4` (`:3190`):** it makes a block `let`'s match. It stands beside `bind/3` (`:3833`, which makes a variable) and `Bound`, the recursive types in `built_descriptor`. Fix: `let_match/4`.
- Read and not shown.

##### 10. `foreign_return_part_test` does not hold a constructor's field
- **Place:** `test/ern_emitter_tests.erl:2861`. §12.3 names "a tuple's or a constructor's field by its place", and the test holds a list's element, a tuple's field, a map's key, the value of a key, a set's member and a return that fails whole.
- **Shown:** the code is right. `parts/main.ern` gives `does not match Optional(Address(Main.Msg)): field 1, is 3`.
- **Fix:** add that case to the test.

##### 11. `ern_compile`'s new `#scope{}` could carry defaults
- **Place:** `ern_compile.erl:505`. `named/2` spells `#scope{namespace = [], form_namespace = [], env = Env, units = #{}}`, and `linked/3` reads only `env` and `units`.
- **Fix:** give the record defaults `namespace = [], form_namespace = [], units = #{}`, so the call is `#scope{env = Env}`. Read and not shown.

##### 12. Small things in changed lines
- **`ern_descriptor.erl:14`:** the comment names `prompt_shows_as_io_show_test`. The test is the generator `prompt_shows_as_io_show_test_` (`test/ern_shell_tests.erl:641`). Fix: add the `_`.
- **`ern_docs.erl:91`:** the diff reflowed the line above, and this one is left at 84 columns against about 75 around it. Fix: reflow the paragraph.
- **`ern_descriptor.erl:150`:** the new spec `constructor_descriptor(atom(), {named, [atom()]} | term(), …)` says nothing, because `| term()` takes everything. Fix: `none | {positional, term()} | {named, [atom()]}`.

**Checked and found right:**
- `ern_boundary` applies the maker with three arguments (`ern_boundary.erl:388`).
- `ern_rt:at_receive/0` exists and is called before an untimed receive (`call/main.erl:11`).
- `foreign_call/5` and `session_lined/3` are cited at the right arities.
- Nothing reaches the removed `{known, {named, [_, _]}, []}` operator clause: the checker refuses `List.<>` as a value.
- No changed function counts past `Context2`.
- No comment names a milestone or a finding.
- A cause's variables follow the type's order: `order/main.ern` prints `List(#(a, b))` for `List(#(b, a))`.

**Outside my part, not taken further:** the comment on `#constructor_info.fields` in `checker/include/ern_types.hrl` says "canonical (sorted) order". Yet `fields/main.ern` shows the term `{'R', <<"s">>, 1}` for `R(b = "s", a = 1)`, and the shell and `Io.show` both print `R(b = "s", a = 1)`. So the order there looks like declared order; the checker's reader can confirm.

### C4

**Counts:** 1 defect; 5 matters of clarity, one of which (2) is also a leftover; 1 leftover outside my part, in C7's file.

#### The session's question: the rise of the call rows

**Which change pays.** From bac35532 to 6c6b8ef1, the only `ern_rt.erl` change on the measured path is 86d0dcf5 (2026-11-25). It routes `call/4` and `call_forever/4` through the new `noted_call/4`, with the wait passed in as a closure.
- `call/4` now makes a fun on every call with three free variables (Reply, Deadline, Check). `callForever` makes one with two (Reply, Check).
- Each call goes through one more frame (`noted_call`, `allocate 6`) and calls the wait through `call_fun`.
- `call/4`'s closure has its own frame and its own `try` for `untimed()`, and `forever_answer/2` is now a function of its own.
- I compared the assembly before and after: `asm/old_call.txt` against `asm/new_call.txt`, and `asm/old_forever.txt` against `asm/new_forever.txt`, made by `asm/fnasm.escript`. The new path is roughly 20–25 more instructions and one heap fun per call. By that count it costs about 10–20 ns a call (read, not shown).

Everything else on the path has the same text at both commits: `watched`, `pending`, `settled`, `sent`, `adapted_way`, `current`, `answer/2`, `waited_answer/3`, `timed`/`untimed`, `deadline`, `callee_site`, `foreign_answer`, `closed`.
- `remaining/1` now calls the local `monotonic/0`, which wraps the same BIF.
- The answers' forms are unchanged.
- `call_limited`'s move to `until_answered/3` is used only by Tcp and Os, so it is on no measured row.

Two changes outside `ern_rt` also touch these rows:
- **The emitter's `ern_rt:at_receive()`** (5f6039e0) now runs in the callee's loop. It is an empty remote call. The row "send and receive to self" also pays it, and moved less than 1 ns (99.4 to 99.6–100).
- **`bench.ern`'s reorder** (d03a228a, 2026-11-22, which is after bac35532) now runs the raises first, at 3,000 faults where there were 300 at the end, and sets backtrace depth 64 before every row. Only `bench.txt` is affected.

**What the numbers say:**
- **`call.txt`, one caller:**
  - The host's call itself fell, from 1021.5 to 983–1006 ns. That accounts for about half of the ratio's rise from 1.50 to 1.59–1.63: at the old Ernest figure against the new host figure the ratio is already 1.56.
  - The real `Address.call` rose 60–72 ns, and `callForever` rose 26–33 ns.
  - The model's final row fell 45–82 ns, and its code did not change.
- **`bench.txt`:**
  - The gen_server baseline is flat (731 to 725–735).
  - `callForever` rose 77–121 ns, and the call with a limit rose 197–212 ns. That is two to three times `call.txt`'s rise on the same runtime, which points at the bench program's reorder for the excess.

**Verdict.** The closure in `noted_call/4` is the one runtime change that can pay, at an estimated 10–20 ns. That is a fifth to a third of `call.txt`'s rise and less of `bench.txt`'s. Reading accounts for no more.

**What would show it:**
1. **`call.txt` A/B:** put `call/4` and `call_forever/4` back inline as they were at bac35532 (about 30 lines). Run `make bench-call` three times each way, alternating, on the idle machine. The difference is the closure's cost.
2. **`bench.txt` A/B:** run `bench.ern` at this commit with `raises(...)` and `systemFlag(backtraceDepth, 64)` moved back after the measures, alternated with the file as it stands.
3. **Bring the model in line with the code** (`test/bench/ern_call_costs.erl`, C7's file):
   - Add a row with the wait in a closure called through a `noted_call`-like function.
   - Put an `at_receive()` in the model's callee.
   - Remove `guarded()` (see the leftovers below).

#### Leftovers: kept for a reason a later change removed

- **`call_forever/4`'s `Limited` parameter** (finding 2). `call_limited/2` used to pass `true`; since 86d0dcf5 nothing does.
- **`test/bench/ern_call_costs.erl:374–378`, `guarded()`**, commented "ern_rt's line_guard/1". `line_guard/1` left the runtime in f8f0eda9 on 2026-10-30, and the real `call/4` reads no `terminal_holder()`. The model's first piece (`addressed/2`) and every model function after it (lines 230–335) still pays a `persistent_term` read that the call does not. This is C7's file.
- **Checked and not leftovers:**
  - `ern_set`'s two shims: the host makes a version 2 set only when asked for one.
  - `ern_bytes:from_hex/1`.
  - `call/3` and `call_forever/2`, which `ern_shell` and the tests use.
  - `ern_fs:private/1`'s export: its test calls it, which the style's rule allows.

#### Defects

**1. `src/runtime/ern_boundary.erl:441–442`: the boundary's zeroing turns a map that is no set into a set.**

```erlang
zero({set, ElementDescriptor}, Value, Bound) when is_map(Value) ->
    maps:from_list([{zero(ElementDescriptor, Item, Bound), []} || Item <- maps:keys(Value)]);
```

This sets every mark to `[]`. So `conformed/3`'s second match accepts a map whose values are not `[]` as a `Set`. That contradicts `zero`'s own comment: "A part of another shape than its descriptor's is left as it is, for the match that follows to refuse."

`conformed/3` runs in three places:
- every argument foreign code passes to a function of the program's (`argument/5`);
- every answer to a Reply foreign code gave (`value/3`);
- every return whose type holds a Float, a function, an address or a Reply (`returned/3`).

The new `returned_cause/3` also zeroes before it reads the part. So where `check/3` refuses, the cause prints a term that is a valid set, not the host's term (§12.3).

The flaw was already there for the tagged form at 93a13b13. The changed line keeps it, the untagged representation now lets any plain map reach it, and the new cause prints it.

The programs, each built and run with the clone's `bin/ern`:
- `readers/C4/sets/callback.ern`: foreign `erlang:apply/2` calls `fn(set : Set(Int)) = Set.size(set)` with `maps:from_list([{1,2},{3,"x"}])`. It prints `2` and exits 0. It should be refused.
- `readers/C4/sets/beside.ern`: the return is declared `#(Float, Set(Int))` and is that map beside a float. It prints `1.5`, `Set.fromList([1, 3])`, `2` and exits 0.
- `readers/C4/sets/main.ern`: the return is declared `Set(Int)` alone, so `check/3` refuses it. The cause is `the return of foreign function maps:from_list/1 does not match Set(Int): is #{1 => [],3 => []}`, a term that would match.

**Fix:** keep each mark: `maps:from_list([{zero(ElementDescriptor, Item, Bound), Mark} || Item := Mark <- Value])`.

#### Clarity

**2. `src/runtime/ern_rt.erl:959–964`: `call_forever/4`'s `Limited` is always `false`.** The comment says "Limited where the request gives its callee a time." Its only caller is line 849, `call_forever(Address, Request, Check, false)`. At 93a13b13, `call_limited/2` passed `true` (old line 853); it now goes through `until_answered/3`. No caller does what the comment describes. **Fix:** drop the parameter, write `limited = false` in the record, and drop the comment's clause.

**3. `src/runtime/ern_rt.erl:5542`: one name for two different jobs.** `told(Ref) -> receive {Ref, _} -> told(Ref) after 0 -> ok end.` takes out the evaluator's unread messages, while `told/3` at line 4747 is the program end's telling. The name says neither. **Fix:** rename `told/1` to a name that says what it does, for example `dropped_words/1`.

**4. `src/runtime/ern_fs.erl:391–408` and `src/toolchain/builder/ern_build.erl:2892–2905`: one check in two copies that must agree.** `private/1` ("`ok` where it holds nothing then, as ern_build:make_private_dir/1 checks") repeats `make_private_dir/1`'s `change_mode(…, 8#700)` and then `list_dir_all` check. **Fix:** have `make_private_dir/1` call `ern_fs:private/1` after `file:make_dir/1` (ern_build is C6's part).

**5. `src/runtime/ern_boundary.erl:120–121`: the comment cites a function by a name its module lacks.** The comment reads "every function it gives the host is wrapped (called/1)". `ern_boundary` has no `called/1`; the function meant is `ern_emitter:called/1` (`ern_emitter.erl:2603`). I found it with `/scratchpad/readers/C4/localrefs.escript` (full path `readers/C4/localrefs.escript`) run over the diff, which printed `src/runtime/ern_boundary.erl: called/1`. **Fix:** write `(ern_emitter:called/1)`.

**6. `src/runtime/ern_code.erl:51–53`: a comment left unrefilled.** It breaks mid-paragraph: "…and the table is / a bag. It is made at / its first use, by a process…". **Fix:** refill the paragraph.

#### Checked, no finding

These are all under `readers/C4/`:
- **`lacked/nomodule.ern`, `noexport.ern`, `deeper.ern`:** they print `…: no module no_such_module_c4 on the load path`, `…: lists exports no no_such_function_c4/1`, and `… raised error:undef` for an undef met deeper. These match §12.3.
- **`env/only.ern`:** `Os.Only` gives `LANG=C\n`; two variables of one name give `A=2\n`; `Only([])` gives empty output and `env` is still found; `Inherited` runs.
- **`trace/deep.ern`:** 15 frames are cut to 12 lines plus `... 3 more frames`, and a recursive run collapses to one line, as E.21 says.
- **Also read and found sound:** `called_on/2` against §12.4; `strict_address/1` probed against the host's parser; the load interrupt's phases (`beginning/2`, `waited_end/4`, `initializing/1`); the `-receives` lists.
- **Scans:** no added comment names an MVP, an item or a date. `localrefs.escript` over all 17,340 lines of the test diff found no dangling local reference beyond cross-module ones.

**Not done:** I read the test diff's helpers whole (`ern_helpers`, `ern_program`, `ern_waits`, `ern_flakes`, `ern_named`, `ern_recorder`) and the tests tied to the changed functions: the status and limited-read tests, `make_temp_dir_held_test`, and the emitter's return-part tests. I did not read `ern_rt_tests`, `ern_tcp_tests`, `ern_stdlib_tests`, `ern_laws_tests` or `ern_os_tests` line by line. I started no process that is still running.

Other scratch files: `counter/src/call_costs.ern` (the compiled counter used to read the emitted call forms), and `src.diff`, `test.diff`, `ern_rt_bac.erl`, `ern_rt_93a.erl`, all in the same directory.

### C5

**Defects: 3. Clarity: 17.** The scratch directory is `readers/C5`, written `$R` below. `ern` is the clone's `bin/ern`. Every run used `HOME=$R/home`.

#### Defects

**1. `:reload` names a named package's module as having no source** (src/shell/ern_shell.erl:3843-3844, `reload_changed/1`)
- **Quote:** `SourcelessLines = sourceless(Session, [Namespace || {Namespace, _, none} <- Sources, is_map_key(Namespace, Expected)])`
- **What is wrong:** The diff made `Sources` come from `dependency_source/2`. That function answers `none` for a named package's module (§11.9: such a file is no module's source). So the `{_, _, none}` pattern now catches the package's module too. Where the program is compiled at the package root, `lib/<pkg>/build/*.erc` lies under the module root, so the package's module is in `Expected`. Every `:reload` then says that module has no source. §11.2.8 names only a module "whose source the source root no longer holds", and "a library's, loaded from its compiled form, is not". The src/build layout does not show it (`$R/pkgshell2`, where `:reload` says only `no source has changed`).
- **Shown:** `$R/pkgshell` has `package.conf` naming `sl_leaf 1.0.0`, `lib/sl_leaf/{src/sl_leaf.ern, build/sl_leaf.erc, package.conf, VERSION}`, and `sl_main.ern` compiled beside it. The command `printf ':reload\n' | ern shell sl_main.erc` prints:
  ```
  > no source has changed

  the source root . holds no source of SlLeaf
  ```
  The same line comes again at every `:reload`.
- **Fix:** Leave out of `SourcelessLines` any namespace that `ern_build:looked_in/3` answers `{none, _}` for, as `package_form/2` already tests.

**2. `printed/1` reads `?capturedOutput`, which `ern_helpers` says can answer `""` under load** (src/shell/test/ern_unpack_tests.erl:98-105)
- **Quote:** `Before = unicode:characters_to_binary(?capturedOutput), ... After = unicode:characters_to_binary(?capturedOutput)`
- **What is wrong:** Commit e84fb74c replaced the earlier reliable read with EUnit's macro. `ern_helpers:captured_output/0` exists for exactly this; its comment (lines 114-118) says the macro first samples the group leader's `current_function` and can answer `""`. If the empty answer comes at `After`, `binary:part` gets a negative length and the test crashes. If it comes at `Before`, the test reads the whole capture. Either way the tests `verbose_test` and `lock_link_test` can flake.
- **Shown:** `$R/captured/c5_captured_tests.erl`, run with `erl -noshell -pa . -eval 'eunit:test(c5_captured_tests, []), halt().'`, prints: `of 300 asks while output was captured: ?capturedOutput "" 33 times, the group leader asked directly "" 0 times`. An earlier run gave 41 times.
- **Fix:** Use `ern_helpers:captured_output()` in both places.

**3. An unreadable changed source is "no source has changed"; `ern build` refuses it** (src/shell/ern_shell.erl:3841 in `reload_changed/1`, re-indented by the diff; 3885 in the new `changed_at_start/1`; `source_hash/2` at 4996)
- **Quote:** `{ok, Hash} <- [source_hash(Session, File)],` and `{error, _} -> none`
- **What is wrong:** `source_hash/2` turns a read error into `none`, and both comprehensions drop it. §11.2.8 says `:reload` compiles "where `ern build` would recompile it", and `ern build` refuses the file. The new start line copies the same silent drop. A first user meets this only on purpose (`chmod 000`), so it is a line for known_issues.md if it is not fixed. The two copies of "the sources that changed" can also drift apart. (`changed_at_start/1` leaves out `is_resolved_otherwise/2`. That is consistent with §11.2.15's wording, "whose source … changed": shown with `$R/resolved` and `--source-root src`, where the start is silent and `:reload` then says `App.Main, compiled again`.)
- **Shown:** In `$R/pkgshell2`, I changed `src/sl_main.ern` and ran `chmod 000` on it.
  - `printf ':reload\n:load SlMain\n' | ern shell build/sl_main.erc` prints no start line, then `> no source has changed`.
  - `ern build --build-root build src` prints `ern build: src/sl_main.ern: permission denied` and exits 1.
  - In `$R/s5` (`in5`), a source changed and then made unreadable gives `> no source has changed`, then `1 : Int` (the old value). `:load Perm` of the same file says `perm.ern: permission denied`.
- **Fix:** Have `source_hash/2` return the read's error, and have `:reload` and the start line report it as `:load` does. Share one helper for "a source whose hash differs" between the two functions.

#### Clarity

**1. `is_spawn/1` is a third copy of "which names spawn", and its `Peer` clause cannot be reached** (src/shell/ern_shell.erl:1186-1195, new in the diff)
- **Quote:** `is_spawn(#e_call{callee = #e_var{referent = #remote_declaration{namespace = ['Peer'], ...`
- **What is wrong:** The checker refuses a `Peer.spawn` whose mailbox type is open before the input gets undetermined help. So the clause never answers `true`. The prelude's names repeat `ern_typecheck`'s `spawned_position` and `ern_bound`'s `spawn_name`, which must agree with it.
- **Shown:** `$R/s1/inputs2.txt`. Line 6 answers `input 6:1:26: Peer.spawn starts a process whose mailbox type Optional(a) is not known whole here`. Lines 1-2 show the spawn help, and lines 3-4 show it correctly absent.
- **Fix:** Drop the `Peer` clause, and take the spawning names from the checker's one list.

**2. `prelude()` at a session's start gives only a speed reason** (ern_shell.erl:393-395)
- **Quote:** `%% built as the host's first session starts, so that its first input does not wait for it`
- **What is wrong:** With `stdlib_met` gone, this call is also what makes the standard library's names met before a completion lexes with `no_new_names`. docs/design/shell.md line 125 says so; the comment does not.
- **Shown:** Read and not shown.
- **Fix:** Add the second reason to the comment, or point to docs/design/shell.md.

**3. `session_printing/3` takes `Scope`, which `Session` already holds** (ern_shell.erl:2017-2024; caller at 2236)
- **Quote:** `session_printing(Scope, Session, TypeState)`
- **What is wrong:** Both callers pass `Session#session.scope` beside `Session`.
- **Fix:** `session_printing(Session, TypeState)`.

**4. `compiled_of/2` builds the same refusal twice** (ern_shell.erl:4903-4906 and 4911-4913)
- **Quote:** `{error, unicode:characters_to_binary([ern_build:path_text(File), ": not a compiled module"])}`
- **What is wrong:** The not-loadable branch and the unreadable-interface branch carry two copies of one text.
- **Fix:** One local `not_compiled(File)`, or fold the two cases into one.

**5. `declared_type/2` looks the name up twice** (ern_shell.erl:2604-2611)
- **Quote:** `{ok, Referent} = ern_typecheck:declared_referent(Namespace, Name, Env)`
- **What is wrong:** `one_name_declared/2` has just found the declaration, and its only caller asks the checker again for its referent.
- **Fix:** Have `one_name_declared/2` return the referent with the scheme.

**6. The persistent term `{ern_unpack, entries}` holds the verbose flag too** (src/shell/ern_unpack.erl:22, 29, 38)
- **Quote:** `persistent_term:put({?MODULE, entries}, {Entries, IsVerbose})`
- **What is wrong:** The key names one of the two values it holds, and `is_verbose/0` reads `entries`.
- **Fix:** Key it `{?MODULE, given}`.

**7. `scratch/1` is a forwarder kept after its body moved to the shared helper** (src/runtime/test/ern_tty_tests.erl:319-320; callers 246, 260, 291)
- **Quote:** `scratch(Prefix) -> ern_helpers:tmp(Prefix).`
- **What is wrong:** The diff replaced its own copy with a call. The name is kept for the earlier reason, which the shared helper removed.
- **Fix:** Call `ern_helpers:tmp/1` at the three sites.

**8. Two comments run two paragraphs together without a blank `%%`** (ern_shell.erl:2066-2070 at `browse/2`; 2973-2983 at `beam_of/2`)
- **Quote:** `%% (§9).` / `%% \`:browse\` alone lists what it takes (browsable/1).` and `... has none (report §11.2).` / `%% Report §4.2: a namespace is a module's only where ...`
- **What is wrong:** docs/code_style.md separates comment paragraphs with a blank `%%`.
- **Fix:** Insert the `%%` lines.

**9. The `FILE_MS` comment repeats `asked/2`'s** (ern_shell.erl:61-64 and 5072-5075)
- **Quote:** `asked/2 waits for its local half to answer for a file of the source root that long and a dial beside it, the carrier's longest wait`
- **What is wrong:** The same sentence is said in two places.
- **Fix:** Keep it at `asked/2`, and let the macro say only what it is.

**10. `package_form/2` overloads `none`, and `source_loaded/4` looks a second time** (ern_shell.erl:3212-3217, 3238)
- **Quote:** `{none, _} -> taken_form(Session, Namespace); _ -> none` and `none -> form_loaded(..., taken_form(Session, Namespace))`
- **What is wrong:** `none` means both "not a package's" and "the package's form found nothing". `taken_form/2` runs again on the path where the source is missing.
- **Fix:** Return a tagged answer, `not_package | Form`, and pass the form found once.

**11. `is_found/2` tests membership by building a list** (ern_shell.erl:3047)
- **Quote:** `[Loaded || #interface{namespace = [First | _]} = Loaded <- Interfaces, First =:= Segment] =/= []`
- **Fix:** `lists:any(fun(#interface{namespace = [First | _]}) -> First =:= Segment end, Interfaces)`.

**12. `took/2` searches the form roots again, where its comment says it gives the file the session took** (ern_shell.erl:3052-3076)
- **Quote:** `%% the file the session took for the module Root ...` and `case compiled_of(Session, Root) of`
- **What is wrong:** `compiled_of/2` answers the first `.erc` now on the roots. `held_form/3` (3390) answers the one the session loaded. A form written earlier on the path after the load makes them differ.
- **Shown:** Read and not shown.
- **Fix:** Use `held_form(Session, Root, [])` for the compiled case.

**13. `ern_tty`'s header no longer names all of what the tests exercise** (src/runtime/ern_tty.erl:27-29)
- **Quote:** `Decoding is decode/1 over the characters read, and flush/1 for what is left when nothing follows; both are functions and are what the unit tests exercise`
- **What is wrong:** `unended_paste_test` now calls `more/2` (ern_tty_tests.erl:474), as `paste_test` does (461), and `more/2` is exported.
- **Fix:** Name `more/2` in the sentence.

**14. Two ways of trimming a line's end** (ern_shell.erl:3967, `kept_values_line/2`)
- **Quote:** `string:trim(iolist_to_binary([Line, "\n", end_trace(End)]), trailing, "\n")`
- **What is wrong:** The diff's other answers trim through `without_line_feed/1`.
- **Fix:** Use `without_line_feed/1`.

**15. `isFoundFirst` takes a `Path` for a bare member name** (src/shell/ern_unpack.erl:113-117; src/shell/ernest/unpack.ern:386, 592)
- **Quote:** `isFoundFirst(Path(beam))`
- **What is wrong:** `beam` is a `.beam` file name such as `lists.beam`, tested against module names, and never a path. It is wrapped only to match the type. Low.
- **Shown:** Read and not shown.
- **Fix:** Take a `String` back, or name the parameter for what it is.

**16. The tests' scratch directory is spelled two ways in one file** (src/runtime/test/ern_tty_tests.erl)
- **What is wrong:** After the diff, the file reaches the run's directory both through `scratch/1` and through `ern_helpers` directly.
- **Shown:** Read and not shown.
- **Fix:** It goes with clarity finding 7.

**17. A test comment names a review finding** (test/ern_shell_tests.erl:5781, added in this release's range but outside the paths my brief's diff names: for the reader of `test/`)
- **Quote:** `regression test of the cold reading's finding (cold3/CA/t10b)`
- **What is wrong:** docs/code_style.md says a comment names no review finding. The style check's pattern misses this spelling. src/toolchain/checker/test/ern_typecheck_tests.erl:1851 holds the same, for the checker's reader.
- **Fix:** Say what the test holds and drop the label.

#### Kept for an earlier reason a later rule removed

- **Removed correctly in the diff:**
  - `ern_tty:unmade/3`: `start_reader` fails only with no subscriber, and the courier is always fresh.
  - `flush/1`'s `?PASTE_BEGIN` clause: the pending list never holds the whole marker.
  - `stdlib_met` in `slot/1`, `fields/1` and `enclosing_call/1`: the standard library is now read at the start.
- **Still standing:**
  - `ern_tty_tests`' `scratch/1` (clarity 7).
  - `source_loaded/4`'s second `taken_form/2` look (clarity 10).
- `is_spawn/1`'s `Peer` clause (clarity 1) is new in the diff, not kept.

#### Checked and found right (not findings)

- `ern_tty:write/1` writes bracketed paste only where stdout is a terminal, as §12.1 says.
- `is_entry/1` and `waiting/1` read right.
- In `$R/s1/inputs.txt`:
  - `:browse` alone lists what it takes.
  - `:doc list.map` says `no documentation for list.map`.
  - `:load Nope` says `no module Nope under the source root . or on the load path`.
- `:type spawn` carries no primitive note, consistent with §3.11's five primitives.
- The start line for a changed program source is right (`$R/pkgshell2`).
- A faulting `:load` binding shows its trace, and a faulting `:reload` binding gives the kept-values line, with a constant keeping its new value (`$R/s3`, `in3`).
- A taken segment's refusal escapes a control character in the root (`$R/s4`).
- `$R/s2/boom.ern`'s fault line matches the report.
- `test/fixtures/pty/pty.ern`'s `K` and `J` handling matches the four sequences the shell writes (`\e[2K`, `\e[J`, `\e[2J`, `\e[H`).
- Every `name/N` cited in the comments of my files is defined (`$R/tools/refs.escript`).

#### Programs kept

All under `readers/C5/`:
- `pkgshell/`: defect 1
- `pkgshell2/`: defect 3 and the start line
- `captured/c5_captured_tests.erl`: defect 2
- `s5/in5`: defect 3
- `resolved/`: the start line against a changed resolution
- `s1/inputs.txt`, `s1/inputs2.txt`: clarity 1 and the checks
- `s2/boom.ern`, `s3/in3`, `s4/`: the checks
- `tools/refs.escript`: the comment-reference check
- `shell.diff`: the part's diff

No process of mine is left running; every run was in the foreground with a timeout.

### C6

I found 1 defect and 11 matters of clarity. Of the 11, 4 are comments that no longer hold, 5 are code that could be shorter or clearer, and 2 are names.

All programs are under `readers/C6/`, and each was run with the clone's `bin/ern`. I started no process that outlives its job, so I left nothing to kill.

#### Defects

1. **`--peer-dir` is checked twice, the two copies disagree, and the CLI's copy hides the owner's.**
   - **Place:** `src/toolchain/cli/ern_cli.erl:491-495` (`named_directories/3`), against `src/nodes/ern_node.erl:262-265` (`peer_read/1`) and `ern_node.erl:397-404` (`checked/2`).
   - **Quote:** `lists:all(fun filelib:is_regular/1, [ern_node:file(Directory, conf), ern_node:file(Directory, certificate)]) orelse ern_build:fail(Directory ++ ": no configuration directory, which --peer-dir names")`
   - **What is wrong:**
     - The diff gave `peer_read/1` its own checks. It now calls `checked(PeerDir, "--peer-dir")` and then `found(certificate, regular) =/= missing orelse no_configuration(PeerDir, "--peer-dir")`, with the same text.
     - The CLI's older copy runs first, so the owner's checks are never reached from `ern config`.
     - The two copies differ on a file of the wrong kind. The CLI uses `filelib:is_regular`. The node uses `found/2`, which says `is no regular file` as §11 says it.
     - So `add_peer/2`'s comment, "Both directories are read as a node reads its own", does not hold.
   - **Shown** (in `cfg/`, where `d` is a copy of `n` with `ernest.conf` made a directory, and `d3` the same with `certificate.pem`):
     ```
     $ ern config --config-dir n --peer-dir d
     ern config: d: no configuration directory, which --peer-dir names
     $ ern reload --config-dir d
     ern reload: d/ernest.conf: is no regular file
     $ ern config --config-dir n --peer-dir d3
     ern config: d3: no configuration directory, which --peer-dir names
     ```
   - **Fix:** in `named_directories/3`, keep only the `no_such_directory` test for `--peer-dir` and let `ern_node:peer_read/1` refuse the rest.

#### Clarity

1. **The comment of `run_tests/6` no longer holds.**
   - **Place:** `src/toolchain/cli/ern_cli.erl:2119-2120`.
   - **Quote:** `status 1 unless every one passed`
   - **What is wrong:**
     - Since the diff, a fault outside a case also gives status 1 when every case passed.
     - The function now answers `{ran, Status, Tally}` or `{ended, Status}`, and the comment does not say so.
   - **Shown** with `t2/waits.ern`, which is the test `fault_after_its_case_test` copied (`ern build waits.ern && ern test waits.erc`):
     ```
     waited: passed
     … the process of Waits.keeper:8 faulted: callee returned without answering, the callee waited, started by the case "waited", which had ended
     1 case, 0 failed, 1 fault outside a case
     status 1
     ```
   - **Fix:** "status 1 where a case failed or a fault counted (§11.8); what the module's run came to, `{ran, Status, Tally}` or `{ended, Status}`", as `run_examples/4`'s comment says.

2. **A comment cites the wrong section.**
   - **Place:** `src/toolchain/cli/ern_cli.erl:487-488`.
   - **Quote:** `%% report §11.3: one that names nothing is refused as a --load-path is`
   - **What is wrong:** that sentence is in §11.7, at `report/toolchain.md:659`. §11.3 is *Configuration setup*.
   - **Shown:** by quote.
   - **Fix:** cite §11.7.

3. **A clause of `packaged/5` is left over from an earlier text.**
   - **Place:** `src/toolchain/cli/ern_cli.erl:407-408`.
   - **Quote:** `{{error, enoent}, package_dir} -> ern_build:refused(Manifest, enoent);`
   - **What is wrong:**
     - The clause existed to write the old `": no such file"` text.
     - The diff changed its body to the host's words, so it now does exactly what the catch-all below it does: `{{error, Error}, _} -> ern_build:refused(Manifest, Error)`.
   - **Shown** in `pk/`. Both refusals come out the same way:
     ```
     $ ern run --package-dir empty x.erc
     ern run: empty/package.conf: no such file or directory
     $ ern run --package-dir looped x.erc
     ern run: looped/package.conf: too many levels of symbolic links
     ```
   - **Fix:** delete the clause.

4. **Test comments still name review findings.**
   - **Place:** `src/nodes/test/ern_carrier_tests.erl:76-77` and `:193-195`, and `src/nodes/test/ern_exchange_tests.erl:842-844`.
   - **Quote:** `(the release review found a badmatch; the full review found \`+0.4.0\` taken)`
   - **What is wrong:** `docs/code_style.md:20` says a comment names no review finding. The diff removed "before 0.4.0" and "before 0.5.0" but kept the findings.
   - **Shown:** by quote.
   - **Fix:** say only "A regression test", with the log entry's title where the history matters.

5. **A signal's number is named two ways, at two sites the diff wrote.**
   - **Place:** `src/toolchain/cli/ern_cli.erl:1456` and `src/nodes/ern_node.erl:581`.
   - **Quote:** `ern_node:signaled(ConfigDir, ern_signals:number(sighup))` beside `node_signaled(ConfigDir, ern_os:signal_number('Termination'), true)`
   - **What is wrong:**
     - `ern_signals:number/1` (new) only renames `ern_os:signal_number/1`, which its own comment calls "the one table of them".
     - The reload goes through the new name and the stop through the old one.
   - **Shown:** read and not shown.
   - **Fix:** use one name at both sites. Either `stopped/1` calls `ern_signals:number(sigterm)`, or `number/1` goes and `reload/3` calls `ern_os:signal_number('Hangup')`.

6. **The same five lines are written in two modules.**
   - **Place:** `src/nodes/ern_exchange.erl:794-798` (`member_of/3`) and `src/nodes/ern_arrival.erl:503-507` (`type_form/2`).
   - **Quote:** `{Recorded, Read1} = ern_code:recorded(Unit, Read), Definitions = case Recorded of #recorded{definitions = Held} -> Held; none -> [] end,`
   - **What is wrong:** the diff wrote the same form in both modules, and the two copies must agree.
   - **Shown:** by quote.
   - **Fix:** add `ern_code:definitions(Unit, Read) -> {Definitions, Read1}` and call it from both.

7. **`reporting_options/2` sets a `faults` option that `cases_launch/6` overwrites.**
   - **Place:** `src/toolchain/cli/ern_cli.erl:1822-1832` and `:2240-2243`, `:2269-2270`.
   - **Quote:** `RunOptions#{faults => Reporter, unasked => Unasked}`
   - **What is wrong:**
     - `reporting_options/2` builds `Faults` from `fault_reporter()`.
     - `cases_launch/6` calls `fault_reporter()` again and replaces `faults`, so the first one is dead in every test and example launch.
     - Each of the two calls reads the persistent term `{ern_cli, streams}`.
   - **Shown:** read and not shown.
   - **Fix:** let `reporting_options` take the reporter as an argument (`fault_reporter()` by default), and have `cases_launch` pass its `Reporter`.

8. **The last sentence of `example_launch/3`'s comment no longer holds.**
   - **Place:** `src/toolchain/cli/ern_cli.erl:2182-2183`.
   - **Quote:** `Whether the example passed, or the status of that end.`
   - **What is wrong:** it answers `{told, Passed, Outside}`, with the count of faults outside the case, or `{ended, Status}`.
   - **Shown:** by quote, against the body at lines 2191-2201.
   - **Fix:** "`{told, Passed, Outside}`, with the faults outside the case, or `{ended, Status}`".

9. **`beam_of/4`'s `Say` serves one of its two branches.**
   - **Place:** `src/toolchain/cli/ern_cli.erl:702` and `:734-760`.
   - **Quote:** `beam_of(Options, Path, ErrorDevice, ern_build:verbose(Options, ErrorDevice))`
   - **What is wrong:**
     - The `.ern` branch says its roots and its modules through `compile_in_memory`'s own `Say`, from `Options`.
     - The comment's "each module read or compiled said by Say …, the source root, the build root" is true only of the `.erc` branch.
   - **Shown:**
     - With `doc1/src/main.ern`, `ern doc main.ern --verbose` printed `source root .`, `build root .`, `read Util from util.erc`, `compiled Main from main.ern`, all of them from `compile_in_memory`.
     - `ern doc main.erc --verbose` printed `read Main from main.erc`, the one line that comes from `beam_of`'s `Say`.
   - **Fix:** make `Say` inside the `.erc` branch, drop the parameter, and make the comment say which branch says what.

10. **A record field's name does not say its value.**
    - **Place:** `src/nodes/ern_code_load.erl:65`.
    - **Quote:** `-record(made_unit, {unit, name, beam, recorded}).`
    - **What is wrong:**
      - `name` holds the file name that `code:atomic_load/1` takes: `File`, or `atom_to_list(Unit)` (lines 282 and 298).
      - The unit's name is already the `unit` field.
    - **Shown:** by quote.
    - **Fix:** rename the field `file_name`.

11. **A trailing blank line.**
    - **Place:** the end of `src/toolchain/builder/ern_build.erl`, after `form_fail/1`.
    - **What is wrong:** the file ends in `\n\n`.
    - **Shown:** `tail -c 200 src/toolchain/builder/ern_build.erl | od -c` ends `)   .  \n  \n`.
    - **Fix:** remove the last line feed.

#### Tried, and found as the report says

- **`doc1/src/{util,main}.ern`:**
  - `ern doc` with `Util` unbuilt is refused, naming `src/util.erc`.
  - `--verbose` writes the roots, the module read and the module compiled.
  - `--doc-root ../docs` is said absolute and writes `index.md` there.
- **`t1/cases.ern`:** the count line, and the fault line of a process a case started.
- **`t1/init.ern`:** an initializer's fault under `ern run` and under `ern test`.
- **`t1/hello.ern`:** `--main` with a qualified name, a private function, a private binding, a malformed name and a missing name, under `ern run` and `ern shell`.
- **`cfg/`:**
  - `ern config` on a new directory and on an existing one prints the key.
  - On an existing directory `--listen` is refused.
  - The form refusals name the help.
  - Missing, file and empty `--config-dir` and `--peer-dir`.
  - A `--peer-dir` given as `$PWD/m` or `./m/` is written `m`.
  - A peer directory whose `ernest.conf` others may write is refused, naming `chmod go-w`.
- **`doc2/`:** a root `Index` is refused as §11.4 says, and `Net.Index` is written.
- **`tk/`:** taken segments `Io` and `List` are named, with the component to rename, at a file and at a directory.
- **`fn/`:** `no module Geo under the source root or on the load path`, for a name and for a type, at the root and below it.
- **`hd/`:** `src/time.ern` is taken while nothing in the job's reach uses the library `Time`, and is refused once `Http` is in reach, by both `ern build` and `ern doc`.
- **`ex/zz.ern`:** a doc example's frames name the source's lines (`Zz.alpha example 1:22`).

#### Read and dropped

- **`ern_examples`' `start = none`:** it is still reachable where a doc block's text is not found among the source's tokens, so it is not dead.
- **`--listen`'s mapped address refused without the help:** the value is well formed, so this is not a form refusal.
- **`bin/ern`'s list of cleared variables beside `ern_exec.c`'s `names[]`:** the two must agree, and `test/ern_integration_tests.erl` holds them together.
- **`ern_build:build_root/1` beside `build_root/2`:** both are a build's root.

### C7

**5 defects and 13 matters of clarity.** I read the diff `93a13b13..6c6b8ef1` for my part: the tests' Erlang and scripts (the pty harness excepted), `tools/` scripts, `site.js`, and every Makefile and `.mk` file. To keep reading time for real changes I set aside two kinds of change, after normalizing the `ern_harness:` prefix. The first is code moved from `ern_nodes_tests` into `ern_harness`: `git diff --color-moved` counts 795 of the harness's 845 lines as moved. The second is lines whose only change is the call prefix.

The programs I tried are under `readers/C7/`. I started no node and left no process running.

#### Defects

**1. `test/ern_harness.erl:76-80`, `nodes_test/2`: a failure and `make slowest` name a nodes test without its module, and name a closure by the compiler's name.**
- The code is `{name, Name} = erlang:fun_info(Test, name), ... {atom_to_list(Name), fun() -> ... end}`.
- Since the move, EUnit files every such test under `ern_harness: -nodes_test/2-fun-1-`. Only the function's bare name follows, and `counted_test/2` names `Module:Name` instead.
- The slowest listing shows both problems:
  - `ern_harness:nodes_test (picked)` is actually `ern_machine_tests`' test.
  - `ern_harness:nodes_test (-parted_one_way_test_/0-fun-0-)` is a closure. Four nodes tests are written this way (`ern_nodes_tests.erl:9138-9147, 9309-9331`).
- Shown by `naming/c7_named_tests.erl`, compiled with the clone's harness:
  ```
  ern_harness: -nodes_test/2-fun-1- (named)...ok
  ern_harness: -nodes_test/2-fun-1- (-closure_test_/0-fun-0-)...ok
  ern_harness: -counted_test/3-fun-0- (c7_named_tests:counted)...ok
  ```
- Fix: name a nodes test `Module:Name` as `counted_test/2` does, and add a `nodes_test/3` that takes a name for a closure, as `counted_test/3` does.

**2. `test/ern_repository.erl:10-19`, `files/1`: the comment states the wrong wildcard rules, and a brace pattern silently matches nothing.**
- The comment says "A wildcard is filelib:wildcard/1's". The code now hands the pattern to `git ls-files -- ':(glob)Pattern'`, which has no braces.
- A suite given a brace pattern reads no file; only some callers guard with `length(Files) > 20`.
- Shown in the clone:
  ```
  git ls-files -- ':(glob)src/{stdlib,shell}/*.ern' | wc -l    -> 0
  filelib:wildcard("src/{stdlib,shell}/*.ern")                 -> 27 files
  ```
- No caller passes braces today.
- Fix: say "git's `:(glob)` pathspec, no braces", and fail on a pattern that matches no tracked file.

**3. `Makefile:704, 717-739`, `coverage`: it counts doc-block citations as tests, though its comment says "the number of tests citing it".**
- `CITING_SOURCES` now feeds `coverage` the whole of `src/stdlib/*.ern src/libs/*/*.ern`, so `///` doc lines count, and so do code comments.
- `coverage.sh` is the recipe run as written; `coverage_tests_only.sh` is the same count without `///` lines. Their output:
  ```
  §12.8           recipe   6  tests alone   2
  Appendix G.3     recipe   3  tests alone   2
  ```
- Fix: drop `///` lines before the `grep -oE '$(CITED)'`.

**4. `test/ern_harness.erl:675-684`, `fault_line/4`: when its time runs out, the failure usually names the prompt, not the fault line.**
- `Left` is computed before the prompt's wait. A round begun with `Left =< 0` still types `Unit` and waits `max(Left, 1)`, i.e. 1 ms, for the prompt.
- So the test fails with `{not_said, Dir, "> "}` even though the shell answered; the missing thing was `Part`.
- This is moved code, unchanged from the old `ern_nodes_tests`.
- Read and not shown.
- Fix: test the deadline before typing another input, and fail with `{not_said, Dir, Part}`.

**5. `site/root/assets/js/site.js:699-713`, `showLimits`: errors in the handler are now swallowed silently.**
- The handler gained `if (said !== undefined)` and `.catch(() => {})`.
- A span whose `data-limit` names no limit keeps "a while". A server whose `limits` changed shape throws inside the handler, and the catch swallows it.
- The console says nothing in either case. The browser tests check only the first span.
- Read and not shown.
- Fix: keep the catch for `loadClient`'s rejection alone, and let an unknown key throw, or make the site test hold every `data-limit` to `limitsSaid`'s keys.

#### Clarity

**1. Names kept from where the harness lived (the "earlier reason" the brief asks after).**
- `ern_harness.erl:55`: every harness test's directory is `ern_nodes_<pid>_<n>`, the deployment, tour, guide and machine tests' among them.
- `:265-327, 365-431`: the modules `ern_nodes_frame` and `ern_nodes_client` and the flags `-ern_nodes_port|target|wait|ms`. `ern_deployment_tests:refused_code` writes `ern_nodes_client` too.
- `program/1`'s doc says "The test program" without saying whose.
- Stale comments:
  - `ern_tour_tests.erl:6-7`: "the nodes' harness starts (ern_nodes_tests)".
  - `ern_harness.erl:695`: "once finished/1 does", but `finished/1` is `ern_nodes_tests`' function.
- Fix: `ern_harness_` / `ern_harness_client`, and point the comments at `ern_harness` and `ern_nodes_tests:finished/1`.

**2. The harness's own tests stayed behind, and nodes-only fixtures moved into the harness.**
- `ern_nodes_tests.erl:42-58`: `steps_past_the_count_test` and `fewer_steps_than_counted_test` test `ern_harness`. They live in a module that runs only in the full run's nodes area, though they start no node.
- The reverse also happened. These harness exports are used by `ern_nodes_tests` alone: `forged/2`, `host/1`, `digest/1`, `fault_line/3`, `shell_started/2,3`, `counting/0`.
- Fix: put the two tests in `test/ern_harness_tests.erl` under `make test`, and give the nodes-only fixtures back to `ern_nodes_tests`.

**3. `ern_harness.erl:53-58`, `tmp/0`, copies `ern_helpers:run_dir/0` and `tmp/1`.**
- It is `os:getenv("ERN_TEST_DIR", os:getenv("TMPDIR", "/tmp"))`, joined with pid and counter, then `ensure_path`.
- It is the one copy left that reads `ERN_TEST_DIR` itself; grep shows every other site goes through `ern_helpers`.
- Fix: `tmp() -> ern_helpers:tmp("ern_harness_")`.

**4. Fresh directories are written out by hand where `ern_helpers:tmp/1,2` already exist.**
- `ern_shell_tests.erl:7294`: `scratch/1` is just `ern_helpers:tmp(Prefix)` under another name.
- `ern_docs_tests.erl:139`: `cited_as_the_guide/1` is `tmp/2` written out by hand (`try ... after file:del_dir_r`).
- These remove their directory only when they pass: `ern_integration_tests.erl:2797` (`diagnostic_as_cataloged`) and `ern_guide_tests.erl:214, 301` (`why_reload_session`, `quoted_runs`).
- `ern_terminal_tests.erl:268, 317, 343, 376, 405, 435`: six tests build `run_dir() ++ "terminal_X_" ++ os:getpid()` plus `ensure_path`. The diff moved a seventh, `stalled_terminal_ends_at_once`, to `tmp/1`.
- `ern_browser_tests.erl:805`: the Chrome profile is named by the counter alone. That is exactly the case `ern_shell_tests.erl:7289-7293` warns of: "a name made by it alone could be one an earlier run left".
- Fix: `ern_helpers:tmp/1` or `tmp/2` at each site.

**5. `test/Makefile:65`: `RECORDER = ../build/runtime/test/ern_helpers.beam`.**
- `ern_recorder` is a different module, the listings' recorder (`Makefile:760`), and `ern_helpers` holds much besides the record.
- Also, `test/Makefile:13-16` says the runtime-test modules the tests call are "ern_named and ern_waits". It leaves out `ern_helpers`, which they now call most.
- Fix: `HELPERS`, and name `ern_helpers` in that comment.

**6. `ern_nodes_tests.erl:521` and `:9116`: one name for two jobs.**
- The new `held/1`, "The hash of the program's Node.held", stands beside the older `held/2`, a listener's accept loop.
- Fix: `held_hash/1`.

**7. Seven readers of a fenced block in the tests, three of them new.**
- New: `ern_grammar.erl:85-91` `fenced/1` (prefix "```"), `ern_tour_tests.erl:495-508` `fenced/1` with `is_prefix/2`, and `ern_deployment_tests.erl:690-695` `blocks/3` (closes only on an exact "```").
- Already there: `ern_docs_tests` and `ern_guide_tests` `fence/1`, and `ern_integration_tests:2816` (exact match).
- Every one of them records through `ern_helpers:record_checked/3`, whose `opening/3` has its own rule: "a line that begins with three backticks".
- `is_prefix/2` is also `string:prefix/2` written by hand.
- Fix: one block reader exported from `ern_helpers` beside `opening/3`.

**8. `ern_guide_tests.erl:214` (`why_reload_session`) and `:337` (`listed/3`) replay a session the same way, twice.**
- Both write `counter.ern`, run `launched(Shell, ["cd ", Dir, " && HOME=", Dir, " ", ..., " shell"])`, type each input at its prompt with an edit before one, then `:quit`, `Wait()` and `said/1`.
- Fix: one replay helper that both call.

**9. Waits written as a number in new tests.**
- `ern_shell_tests.erl:7748` (`end_of_input_waits`) and `:8031` (`input_typed_while_a_load_runs`) give `Os.run(..., 60000)`.
- The glossary's WaitMs says a program a test writes gives each wait the harness's time. They copy the older sites at `:1795` and `:6569`.
- Fix: `ern_harness:wait_ms_text()`.

**10. `site.js:76, 612-614`: the rename is half done.**
- `panel.terminal` became `panel.screen`, but the element keeps `className = "panel-terminal"`, and the CSS and the browser tests select `.panel-terminal`.
- Fix: class `panel-screen`, or keep the old name in both places.

**11. `Makefile:333-334`: a garbled comment.**
- It reads "the areas run side by side, each with as many, ran past it, and tests ran past their limits".
- Several paragraphs the diff touched were not refilled, and their lines are ragged though within 100 characters: `Makefile:47-50`, `ern_style_tests.erl:48-49, 302-304, 423-424`, `ern_manual_tests.erl:15-16`, `ern_nodes_tests.erl:1-4`.
- Fix: "run side by side, each with that many, the areas ran past what the host carries, and tests ran past their limits", and refill the paragraphs.

**12. `Makefile:428-430`: the `MINUTES` check restates `tools/flakes.ern:70-72`'s check, and the two disagree on `00`.**
- Shown:
  ```
  MINUTES='00': make passes it on     (flakes.ern then refuses "minutes, a positive whole number, is required")
  ```
- Fix: one check. Either keep make's and accept `[1-9][0-9]*`, or let the tool's refusal name `MINUTES=n`.

**13. Duplicate and misplaced helpers named `finished` and `succeed`.**
- `ern_integration_tests.erl:2927`: `finished(Program) -> ern_harness:collected(Program, 1)` is a rename and nothing more.
- A different `finished/1` in `ern_nodes_tests.erl:8954` runs a shell command.
- `ern_integration_tests:succeed/1,2` is called by `ern_docs_tests:cited/2` and `ern_manual_tests:manual_footer_test`, so two modules depend on another module's test helper.
- Fix: call `collected/2` directly, and move `succeed` into `ern_harness`.

#### Kept for an earlier reason

I checked these for a reason that has gone; they keep theirs:
- `ern_docs_tests`' `-- ["docs/findings.md", ...]`: the file is gone at `7d84db81` but returns with each review.
- `ern_repository:is_editors/1`: still used by `ern_install_tests:457`.
- The `utilization` measure: dropped from `ern_pick_costs` and `test/Makefile` in this same diff.

The one real case is Clarity 1, the `ern_nodes_` names.

### E1

Counts: 5 defects, 9 matters of clarity, 4 places the language made the code harder, 2 things kept for an earlier reason. 20 findings in all.

The probes are under `readers/E1/probes/` (written `P/` below). The pages are in `.../readers/E1/doc/` and the diff is `.../readers/E1/stdlib.diff`. Every run was in the foreground, and none of my processes is left.

#### Defects

**D1. `Int.toFloat`'s Errors sentence is wrong** (`src/stdlib/int.ern:221`).
- The page says: "Faults where `int` is beyond the largest finite `Float`".
- The code faults only from 2^1024 − 2^970, as §3.1 says ("where that rounding gives no finite `Float`"). Integers above the largest finite Float and below that bound round down and are answered.
- `P/to_float.ern` printed `largest finite Float as an Int + 1: 1.7976931348623157e308`, then `Left(Fault("Int out of Float range"))` at 2^1024 − 2^970.
- Fix: "Faults where `int` rounds to no finite `Float`, at 2^1024 − 2^970 or beyond in magnitude". Sharpen E.8's line 492 ("faults outside the finite range") the same way.

**D2. `ern_set`'s header is false on the floor's OTP, and `Set.empty` and `Set.fromList` are adapters for an OTP the floor no longer supports** (`src/runtime/ern_set.erl:1-13`, `src/stdlib/set.ern:43-44, 190`).
- The header says the version 2 sets are made "which the host makes only when asked". OTP 28 made version 2 the default.
- `erl -noshell -eval 'io:format("~p ~p ~s~n",[sets:new(),sets:from_list([1,2]),erlang:system_info(otp_release)]),halt().'` printed `#{} #{1 => [],2 => []} 29`.
- So E.0 rule 1 gives both to the host exactly.
- Fix: `emptySet` = `"sets:new/0"`, `fromList` = `"sets:from_list/1"`, and `ern_set.erl` deleted.

**D3. `OrderedSet` and `OrderedMap`'s `minimum` and `maximum` lack E.0 rule 6's sentences** (`ordered_set.ern:261-279`, `ordered_map.ern:328-348`).
- The pages say "or `None` for the set with no elements" and never say that the result is never `None` for a set or map that is not empty. `List.minimum`'s page does. `ern_doc_tests:stated_test`'s `NeverNone` list (line 247) names List's four and none of these four.
- `maximum` is `List.last(list)`, a walk of the whole set. The module page says "Use an ordered set … where the smallest or the largest is wanted", and its "What it costs" paragraph does not name `maximum`.
- `P/ordered_cost.ern` printed `OrderedSet.minimum of 1,000,000: 0 us a call` and `OrderedSet.maximum of 1,000,000: 4366 us a call`.
- Fix: add "It is never `None` for a set that is not empty" and "`maximum` takes time linear in the size" to each pair, and add the four to `NeverNone`.

**D4. `String.endsWith` and `stripSuffix` walk the whole text where it ends with the suffix, and no page says so** (`string.ern:174-175, 212-223`). E.0 rule 6 asks for "a cost its name does not suggest".
- The new byte check makes the `false` case fast. The `true` case still runs `size(text)` and `slice(text, …)` over every grapheme.
- `P/suffix_cost.ern` on 1 MB of ASCII: `endsWith` true 1664 µs, false 2 µs; `startsWith` 4 µs; `Bytes.endsWith` 1 µs.
- `P/suffix_cost2.ern` on 700 kB of Swedish: `endsWith` 19775 µs, `stripSuffix` 16817 µs, `startsWith` 6 µs.
- Fix: check the grapheme boundary from the suffix's bytes backwards rather than from the text's start, or state the linear cost on both pages.

**D5. `Process.Callee`'s page promises more than the field gives** (`process.ern:145-147`).
- The page says the callee is "the one whose end the cause says, `callee was killed`".
- The cause `callee had ended` also says an end, but the field is `None` there. E.21 is narrower ("says how the callee ended").
- `P/callee3.ern` (a `readForever` on a socket that `acceptForever` opened, killed beforehand) printed `socket site: Some("Tcp.acceptForever")`, then `#("callee had ended", None)`.
- Fix: "…the one whose end the cause says how, `callee was killed`; `None` for `callee had ended`".

#### Clarity

**C1. The name `Tcp.address` means something else beside its own module's `Address`** (`tcp.ern:628`, E.18 line 765).
- Every other function of Tcp takes or answers an `Address(SocketMsg)` or `Address(ListenerMsg)`, a process's address. `address(text)` answers the `Bytes` of an IP address.
- E.0 rule 10 refuses "one that a name beside it in the module makes mean something else". A reader of Erlang predicts `inet:parse_address`'s word.
- Read and not shown.
- Fix: `Tcp.parseAddress` (or `Tcp.ipBytes`).

**C2. `Random`'s private draws answer the seed last, against the order the module now exports** (`random.ern:64-65, 71, 89`).
- `nextInt` swaps back: `let #(drawn, seed) = below(seed, bound); #(seed, drawn)`. `below`, `spanning` and `splitMix` answer `#(Int, Seed)`.
- `guide/style.md:33` and `docs/code_style.md:18` quote the private order as their model: `let #(draw, seed) = splitMix(seed)`.
- Fix: make the three answer `#(Seed, …)`, and change both style files to `let #(seed, draw) = splitMix(seed)`.

**C3. `Path.isAbsolute` is a foreign function and an atom binding where Ernest does the work** (`path.ern:307-315`). This is the brief's E.0 rule 1 question.
- The separator is now the literal `"/"`, and `endsInSeparator` beside it answers by `Bytes.endsWith`. `Bytes.startsWith(String.toUtf8(text), <<47>>)` answers as `filename:pathtype/1` does.
- `P/absolute_cost.ern` gave both `[true, false, true, false, true]` on `/etc/hosts`, `etc/hosts`, `/\u{301}x`, `""` and `//x`. Both cost 34 to 42 ns a call in a loop.
- The log's reason is misapplied: 2026-11-25:105 says "2.05 times the host's, below E.0 rule 1's three". That clause (library.md:145) is for values the language owns. A path's text is a `String`, the runtime's, and is held to "measurably costs" (line 143).
- Fix: write `isAbsolute` over `Bytes.startsWith`. Because E.14 names `isAbsolute` a primitive, its sentence changes too. Correct the log's reason.

**C4. `List.minimum` and `maximum` write a second loop beside `extremeBy`'s fold** (`list.ern:603-626` beside `661-675`). `extreme` and `kept` do what `extremeBy` does with the key `fn(x) = x`. Read and not shown. Fix: `fn extreme(list, beyond) = extremeBy(list, fn(x) = x, beyond)`.

**C5. `String.startsWith` and `endsWith` are now two forms for one question** (`string.ern:169-175`). `startsWith` is `slice(text, 0, size(prefix)) == prefix`, and `endsWith` is `Optional.isSome(stripSuffix(text, suffix))`. Fix: `startsWith = Optional.isSome(stripPrefix(text, prefix))`.

**C6. `Os.resize`'s order reads against itself** (`os.ern:501-505`).
- The page says "It answers the first of these that holds: `Left(NotATerminal)` for a program `start` started, whatever the size; `Left(Invalid)`…". Then it says "On a program whose process has ended … `Left(Closed)` alone."
- `P/ended.ern` (a `start` program killed, then rows −1) printed `os resize after kill: Left(Io.Closed)`.
- Fix: put the ended case first, "On a program whose process has ended … `Left(Closed)`, before the others", and drop "alone".

**C7. `Fs.makeDir`'s new sentence names a file, and a dangling link answers the same** (`fs.ern:224-225`, "a file there answers `Left(Exists)`").
- `P/fs_link.ern` printed `makeDir on link to dir: Right(Unit)` and `makeDir on dangling link: Left(Io.Exists)`.
- Fix: "an entry there that is not a directory, nor a link to one, answers `Left(Exists)`".

**C8. E.14 is silent where the new page speaks** (`path.ern:149-150`, library.md `Path.name` line).
- The page and the code answer `None` for `Path("")` as well as for the root. E.14 says "None for the root, which has none".
- `P/ordered_cost.ern`'s last line printed `#(None, None, [])` for `name`, `parent` and `split` of `Path("")`.
- Fix: E.14's line gains "and for `Path("")`".

**C9. `supervisor.ern` gives one reason twice** (lines 101-103 and 123-126). The `Join` field's comment and `Member`'s comment both say that `stop` "binds `GroupMsg` and a supervisor's address to their node (report §3.11)… refused when the program is compiled". Fix: keep it on `Join`, and let `Member` say "`stop`, `Join`'s".

#### Where the language made the code harder

**L1. No private declaration is shared between library modules, and the copies have grown since feedback 308.** Feedback 308 says "`callLimited` twice". The copies now stand:
- `system` 6 times (clock, fs, io, os, tcp, terminal)
- `callLimited` 2 times (os, tcp)
- `callUnlimited` 2 times (os, tcp)
- `closed` 2 times (os, tcp)
- `timed` 2 times (os, tcp)
- `let global` 2 times (bytes, path)

That is 16 declarations for 6 things (`/usr/bin/grep -c` over `src/stdlib/*.ern`). Fs writes the same timed call a third way, `asked`. Fix: update 308's count, or give the library a visibility of its own.

**L2. A host atom is no §4.6 constant.** Every option is a top-level binding read through `ern_rt:binding/1` at each call:
- `bytes.ern:222` `let global : List(Foreign.Term) = [Foreign.atom("global")]`
- `bytes.ern:311` `lowercase`
- `path.ern:100` `global`
- `path.ern:311` `absolute`

That is 4 bindings over 7 call sites, kept because "a foreign name passes no atom" (log 2026-11-22:118).

**L3. A foreign declaration keeps the host's argument order,** so each difference in order is a private host function plus an export that swaps:
- set 5 (`isElement`, `withElement`, `withoutElement`, `mapped`, `filtered`)
- map 6 (`withEntry`, `withoutKey`, `mapped`, `filtered`, `folded`, `mergedWith`)
- list 1 (`sorted`)

These 12 private functions name no type of their module's own.

**L4. A message can be bound to its node only by holding a function** (`supervisor.ern:101-104`, `Join.stop`). The binding that makes `Peer.spawn` refuse a capture comes from the field's being a function, which nothing in the type shows. This is 1 site.

#### Kept for an earlier reason

**K1. `Set.empty` and `Set.fromList`'s adapters** were kept for an OTP before 28, when sets defaulted to version 1. The floor is OTP 29. See D2.

**K2. `Path.separator()` is a function answering `"/"`** (`path.ern:95-97`), called at 8 sites. It is the shape of `ern_path:separator/0`, which read the host and wrote `\` on Windows. E.14 now fixes `/`. Fix: a constant, `let separator = "/"`.

#### Read and found right

- The `Callee` example's `Ended(site = "Tcp.acceptForever")` can happen: a socket that `acceptForever` opens has that site (`P/callee3.ern`).
- `Left(Timeout)` for a wait of 0 on an ended socket or program is E.0 rule 8's.
- The order in which the List functions call their function holds (`P/order.ern`: `123`, `123`, `123`, `12`, `12`).
- `String.toIntBase` and `Char.digitValue` answer `None` for base 37 while `Int.toStringBase` faults. That follows the log's *An Argument Outside a Domain* (`P/base.ern`).
- No old name (`List.span`, `Process.faults`, `Ets.owned`, `ern_path`, `ern_set:contains`, …) is left outside the log. `Reply.process` is left only in `docs/plan.md` and `ern_cli_tests.erl`, which are outside my part.

### E2

**Counts:** 4 defects (3 shown by a program, 1 read and not shown), 11 matters of clarity, 3 places where the language made the code harder, and 0 leftovers from an earlier milestone.

**Scope:** the diff `93a13b13..6c6b8ef1 -- src/shell/ernest`, which is 10 files (+868 −634), read in the clone. The commits are e84fb74c, f6b644c0, 1c0e6432 and the rename commits.

**Programs:** all are under `readers/E2/`:
- `scripts/abandon.sh`, with `scripts/gen_big.py` and `abandon/big.ern`
- `scripts/entryfault.sh`, with `entryfault/hello.ern`
- `scripts/unpack_order.sh`
- the pages written by `ern doc`, under `doc/`

Every shell run used `HOME=…/E2/home` and a private tmux server (`-L e2reader`). Each script kills that server when it ends. Nothing of mine is left running.

#### Defects

**1. A line abandoned with `C-c` while the session is busy is replaced in the transcript by what is typed after it. The prompt then shows empty while the editor still holds that text.**
- **Where:** `shell.ern:1721-1733` (the reader's `Editor.Cancel`), `:762-769` (`await`), `:913-920` (`keyLoop`) and `:1275-1283` (`dropInterrupts`).
- **What changed:** e84fb74c removed `send(screen, Entered);` from the reader's `Cancel` arm. The old line was at 93a13b13 `shell.ern:1595`. The session now sends `Entered` (the line's end), as the design note's *Cancel* says, "so that one sender draws both".
- **What is wrong:** that order is only the session's own. The reader goes on sending `ShowInput` for the keys typed after `C-c`. The screen gets those before the session's `Entered`, and `Entered` then commits whatever the region shows. During `:load` or `:reload` the gap is the rest of the command, compile included, because `dropInterrupts` runs only once `load` returns.
- **Shown by:** `scripts/abandon.sh`. It runs `:load Big` (about 4 s to compile), then types `abc`, then `C-c`, then `xyz`:
  ```
  --- while the load runs
  > :load Big

  xyz
  --- after the load answered
  > :load Big
  xyz
  Big.answer:21003 was killed; nothing was loaded
  >
  --- after one more key, w
  > :load Big
  xyz
  Big.answer:21003 was killed; nothing was loaded
  > xyzw
  ```
  The history file holds `abc`, which is right. The transcript never shows `abc`. It shows `xyz` as the abandoned line, and `> ` stands empty over an editor that holds `xyz`. A second run gave the same result.
- **Gap in the tests:** `interrupts_in_one_read_test_` holds the opposite order (the session's prompt against the reader's end). No test types after `C-c`.
- **Fix:** order the line's end with the reader's own drawing. Either the reader sends `Entered` at `Cancel` again and the session's prompt after an interrupt waits on the reader, or the reader holds its keys until the session has drawn the end.

**2. In a plain shell given a file, the fault line for the program's entry point reads `the process of Hello.main faulted`, where `ern run` writes `Hello.main faulted`.**
- **Where:** `shell.ern:1047-1056`:
  ```
  let process = if isEntry(report.process) then "" else "the process of ";
  ```
  `isEntry` is `ern_shell:is_entry/1`, which returns `Process =:= ern_rt:entry_process()`. In a plain shell that is the shell's own `main`. The program's `main` is started by `spawn_program/0` through `ern_rt:spawn_root`, so it is never "the entry".
- **What is wrong:** §11.2.7 says the shell prints the line "as `ern run` does", and §11.2's `ern run` paragraph says "The entry process's line names its entry point alone".
- **Shown by:** `scripts/entryfault.sh`:
  ```
  $ ern run build/hello.erc
  2026-11-26T17:44:50.147Z Hello.main faulted: division by zero
  $ ern shell build/hello.erc
  the process of Hello.main faulted: division by zero
  ```

  `:faults` goes through `reportLine` too, so it gives the same wrong line.
- **Gap in the tests:** `test/ern_shell_tests.erl:254,269,277` (`program_test_`) passes anyway. Its `expect` and `ern_pty:count` match `"Counter.main faulted: division by zero"` as a substring of the prefixed line.
- **Fix:** `is_entry/1` also answers true for the process `spawn_program/0` starts, and the test expects the line from its first column.

**3. `ern unpack --verbose` writes its "stands at" and "unpacked" lines before the refusals of earlier entries, so its output follows neither the manifest's order nor the order of its passes.**
- **Where:** `unpack.ern:446-469`. `said(...)` writes at once during the third pass (`unpackedOne`). `main` (`:70-77`) prints the collected refusals of all passes only after `passes` returns.
- **What is wrong:** the page says "its refusals said in the order they are made". The test comment says "in the manifest's order".
- **Shown by:** `scripts/unpack_order.sh`. The manifest order is leaf (refused), then epx and zed (both standing):
  ```
  lib/epx stands at 0.2.1
  lib/zed stands at 1.0.0
  ern unpack: package.conf: the entry for leaf has no sha256
  ern unpack: package.conf: leaf 1.2.0 is not under lib; put leaf-1.2.0.tar.gz in lib
  status 1
  ```
- **Fix:** `unpackedOne` returns its verbose lines for `main` to say in order, or `main` says the first two passes' refusals before the third pass runs.

**4. Read and not shown: a `C-c` typed just after the reader answers `Prompted` is dropped.**
- **Where:** `shell.ern:395-396` and `:450-454`:
  ```
  let _ = Address.call(given, Prompted, screenMs);
  unkeptInterrupts();
  ```
- **What is wrong:** `unkeptInterrupts` takes every `Interrupted` in the mailbox with `after 0`. That includes one the reader sent from `readLoop` after its answer, which is a real `C-c` at the first prompt. No `Entered` and no prompt follow it. The comment claims "every one it passed on is in the mailbox, ahead of its answer", but nothing keeps later ones out. The window is narrow: it lasts while the reader replays keys typed ahead.
- **Fix:** the reply says how many interrupts the reader passed on (`Prompted(Reply(Int))`), and the session drops that many.

#### Clarity

**5. The Erlang matches an Ernest constructor by its host atom, unchecked.**
- **Where:** `ern_shell.erl:3507`, `ern_rt:evaluate([Unit], <<"Ernest.Shell.load">>, 'Interrupted')`. The Ernest side is `shell.ern:2549-2558`, `foreign fn load(...) … receiving ShellMsg`.
- **What is wrong:** `'Interrupted'` is the private `ShellMsg.Interrupted` written as its runtime atom. If the constructor is renamed, the interrupt stops killing a load, and no checker says so. `ern_rt:evaluate/3` already takes the interrupt as a term.
- **Fix:** pass `Interrupted` from Ernest as an argument of `load` and `reload`.

**6. `History.fileMs` now governs every file the shell reads, not only the history.**
- **Where:** `history.ern:14-16`:
  ```
  /// How long the shell waits for the file system, which is a local file:
  /// for the history file, and for every other file the shell reads.
  export let fileMs = 5000
  ```
  It is used at `shell.ern:593, 604, 2316, 2326, 2341, 2349, 2357, 2470`, for `:output`'s appends, the source root's reads and the local half's wait.
- **What is wrong:** the History module's page now documents a wait that is not the history's. A reader of `served` meets `History.fileMs` at an `:output` append. `unpack.ern:58` keeps its own copy.
- **Fix:** give `shell.ern` its own `let fileMs` (a constant) again. Nothing makes the two values agree.

**7. Two names that no reader can tell apart.**
- **Where:** `refusal.ern:15` `pathNamed(path)` (from the working directory, through `controlFree`) and `:39` `pathText(path)` (as given, through `controlFree`). This is the old `named`, renamed by the diff.
- **What is wrong:** E.0 rule 10. Also, `pathNamed`'s doc says it names a startup file, but `shell.ern` names startup files as `Refusal.fromWorkingDirectory` (`:549`) plus `controlFree` at each message (`:580, 608, 610, 614`). That is a second way to do the same thing.
- **Fix:** name it for what it does, e.g. `textFromWorkingDirectory`, and have the startup sites call it.

**8. `unkeptInterrupts()` (`shell.ern:450`) beside `dropInterrupts(screen)` (`:1275`).**
- **What is wrong:** the first is a noun for a function that takes messages (the guide: "A function that does something is a verb"). The two do the same thing but for the `Entered`, and their names do not say so.
- **Fix:** rename it `dropUnkeptInterrupts`.

**9. `unpack.ern` makes its paths in two ways.**
- **Where and what is wrong:**
  - The new `packagePath` (`:232`) answers a String, and 4 of its 6 uses wrap it in `Path(...)` (`:110, 114, 127, 476`, and `:422` with `<> "/ebin"`).
  - Line 85 builds `hold(Path(lib) <> Path(".unpack"))` while line 86 writes `lib <> "/.unpack: "`.
  - `isFoundFirst(Path(beam))` (`:386`) types a file name as a path. The shim calls `code:where_is_file/1` on a base name.
- **Fix:** `packagePath` answers a `Path` and the texts go through `Refusal.pathText`; `isFoundFirst` takes a String.

**10. The `Ernest.Shell` page explains its two abstract types by constructors the page hides.**
- **Where:** `shell.ern:36-47` and `:186-203`, shown in `doc/ernest/shell.md`.
- **What is wrong:** `ShellMsg`'s and `LocalMsg`'s `///` text names 26 constructors and the private `nextRead`. A programmer sees `abstract type ShellMsg` and can use none of them.
- **Fix:** one `///` sentence saying what each type is, and the notes on each constructor as `//`.

**11. The region tests cite the report for a rule only the design note states, and one new test repeats another.**
- **Where:** `region.ern:661-664` (`wrapKeepsColor`) and `:673` (`offerWrapsAfterReset`) cite "Report §11.2" for "a row … begins with the escape sequences since the last reset". Only `docs/design/shell.md` *Width* states that.
- **Also:** `offerWrapsAfterReset` (`:674-679`) is `offerWraps` (`:655-659`) with one line changed. It is the clone listing's 112-token pair `region.ern:652-666/670-683`.
- **Fix:** cite the design note, and make one test over both lines.

**12. `said(line)` in unpack is named for what it did, but it writes.**
- **Where:** `unpack.ern`, after `unpackedOne`. `shell.ern`'s function for the same act is `say`.
- **Fix:** `say`.

**13. Two `Desk` fields become Paths only to be turned back into Strings.**
- **Where:** `Desk.sourceRoot` and `workingDirectory` became `Path` (`shell.ern:171-172`). Their one use converts them back: `start(local, screenProcess, Path.toString(desk.sourceRoot), Path.toString(desk.workingDirectory), …)` (`:339-340`). Meanwhile `sourceRoot = Path(givenSourceRoot())` (`:2157`).
- **Fix:** type `start`'s two parameters `Path`, as `ern_unpack`'s shims now read `{'Path', Bin}`.

**14. The rename from `state` to `editing` stopped short in the editor's tests.**
- **Where:** `editor.ern:1515-1590` keep `states()` and "the state", and `:89` "The state to type the next input in".
- **Fix:** `editings`, or "the inputs a key is tried on".

**15. An accessor written out where a field would do.**
- **Where:** `type StartupFile = Own(String) | Configured(String)` needs `startupPath` (`shell.ern:563-568`) to read the path that both constructors carry.
- **Fix:** `StartupFile(path : String, kind : StartupKind)` reads it as a field.

#### Where the language made the code harder

**16. The standard library has no function that writes a fault's line as `ern run` writes it.**
- **Where:** the shell rebuilds it in Ernest: `reportLine`, `causeLine`, the new `calleeClause`, `clause`, `escaped` and `escapedChar` (`shell.ern:1041-1115`). The runtime writes the same line in Erlang. One Ernest site holds this copy.
- **Why it matters:** the copy has already drifted (defect 2). Any program that subscribes with `Process.subscribeFaults` and prints faults would have to write it again.

**17. A string literal too long for a line is continued with `<>` at run time.**
- **Count:** 23 sites (shell 5, libs 7, tools 11, stdlib 0, examples 0, tour 0). The diff adds two, in `command.ern:64-65` and `:111-112`.
- **Method:** a line that opens with `<> "` after a line that ends in `"`.
- **Already held:** feedback 283 covers the same problem for a number.

**18. New private functions whose types name none of the program's own types.**
- **Count:** counted over the diff's new functions only, not the whole sources. There are 4: `isWrittenByOthers(String) : Bool` (`shell.ern:592`), `killedLine(Process) : String` (`:814`), `calleeClause(Optional(Process.Callee)) : String` (`:1067`) and unpack's `said(String) : Unit`.
- **Judgment:** only `calleeClause` points at a function the library lacks (16).

#### Leftovers from an earlier milestone

None remains in the diff's lines. The diff itself removed three:
- the `Attached` arm of `served`
- `hexadecimal`, now that `Int.toStringBase` answers a String
- the `printing : Bool`, replaced by `Origin`

### E3

**Counts:** 5 defects, 13 matters of clarity (three of them copies kept after the rule that needed them was removed: C2, C3 and C4), and 8 places where the language made the code harder (two already held by feedback 285 and 286).

Paths: **C** is the clone, `c`. **S** is my scratch directory, `readers/E3`. Every program was built and run with C/bin/ern.

#### Defects

**D1. `Http.parseDate` faults on network input with a negative year** (C/src/libs/http/http.ern:1955-1962, 2053-2054)
- Quotes: `else if time < yearZero then fault("the time is before the year 0")`, from `date`, the new code. `fn fourDigits(year : String) : Optional(Int) = if String.size(year) == 4 then String.toInt(year) else None`.
- What is wrong:
  - The IMF-fixdate path hands `date` to `readDate` as its writer.
  - `fourDigits` accepts `"-001"`, because `String.toInt` reads a sign.
  - So a header sent by a client faults the server instead of answering `None`.
  - The asctime path answers `None`, because its writer `yearText` writes the sign.
- Shown by S/dates/dates.ern:
  ```
  Some(784111777000)
  None
  ... Dates.main faulted: the time is before the year 0
      Http.date:1959
      Http.readDate:2033
      Dates.main:6
  ```
  The third line is `Http.parseDate("Sun, 06 Nov -001 08:49:37 GMT")`.
- Fix: `fourDigits` takes four ASCII digits only.

**D2. `Uri.toString` (new) writes a reference of no form as a different reference** (C/src/libs/uri/uri.ern:333-342)
- Quote: `"//" <> authorityText(authority)` is followed by `reference.path`, written as it stands.
- What is wrong:
  - With an authority and a path that does not begin with `/`, the path runs into the host.
  - With no authority, a path beginning `//` reads back as an authority.
  - With no scheme, a first segment holding `:` reads back as a scheme.
  - RFC 3986 §3.3 rules out all three forms. The page promises a round trip only for what `parse` answered, but a program that builds a Reference from a host and a path sends to a different host.
- Shown by S/paths/paths.ern:
  ```

  "//ha" reads back as Some(...authority = Some(Uri.Authority(userinfo = None, host = "ha", port = None)), path = ""...)
  "//h/p" reads back as Some(...host = "h"..., path = "/p"...)
  "a:b" reads back as Some(Uri.Reference(scheme = Some("a"), authority = None, path = "b", ...))
  ```
  The inputs were authority `h` with path `"a"`; path `"//h/p"` with no authority; and path `"a:b"` with no scheme.
- Fix: fault on a reference of none of RFC 3986's forms, and say so under the page's Errors. The alternative is writing `/` or `./` before the path, as Go does.

**D3. A thematic break with a trailing tab is a paragraph** (C/src/libs/markdown/markdown.ern:421-429)
- Quote: `match List.filter(String.toList(line), fn(char) = char != ' ')`.
- What is wrong:
  - The diff moved blank lines and stripping to spaces and tabs, as CommonMark 0.31 has them, but left `isRule` on spaces alone.
  - `-\t-\t-` passes only because `prefixExpanded` expands a tab after a list marker. `_` is no marker, so `_\t_\t_` fails.
- Shown by S/rules/rules.ern:
  ```
  "---" -> [Markdown.Rule]
  "---\t" -> [Markdown.Paragraph([Markdown.Text("---")])]
  "-\t-\t-" -> [Markdown.Rule]
  "***\t " -> [Markdown.Paragraph([Markdown.Text("***")])]
  "a\n\n___\t" -> [..., Markdown.Paragraph([Markdown.Text("___")])]
  "_\t_\t_" -> [Markdown.Paragraph([Markdown.Emphasis([]), Markdown.Text("\t_")])]
  ```
- Fix: filter with `!isSpaceOrTab(char)`.

**D4. The interpreter example faults on input the diff says cannot come** (C/examples/interpreter.ern:186-191)
- Quote: `| None -> fault("a run of ASCII digits reads as a number")`.
- What is wrong:
  - The diff turned `Optional.withDefault(..., 0)` into this fault.
  - `String.toInt`'s own page says it answers `None` for "an integer the host cannot hold".
  - So a line of digits past the host's limit ends the example's loop with a stack trace. The case is not ruled out by the value's shape, so the guide's rule does not apply.
- Shown by S/digits/interpreter.ern, a copy of the example, fed `1 + 2`, a line of 1,300,000 nines, then `3 * 4`:
  ```
  3
  ... Interpreter.main faulted: a run of ASCII digits reads as a number
      Interpreter.lex:190
      Interpreter.evaluateLine:81
      Interpreter.interpret:75
  exit 1
  ```

  S/digits/digits.ern shows `String.toInt` answering `None` for that text.
- Fix: a `LexError` for a number too large, answered as a value like `BadChar`.

**D5. A tab after an emphasis mark opens emphasis, and the tab is lost** (C/src/libs/markdown/markdown.ern:957-960 `opens`, `closingRun`; low, and older than the diff)
- Quote: `char :: _ -> char != ' ' && char != '\n'`.
- What is wrong:
  - CommonMark's flanking rule treats a tab as white space, so `x *\ta* y` is text.
  - Ernest makes emphasis of it, and `inlines`' stripping then drops the tab.
  - `_\t_` gives an empty `Emphasis([])`.
  - The old `String.trim` dropped the tab too, so this predates the diff. The diff's alignment to spaces and tabs skipped these two tests as well.
- Shown by S/flanking/flanking.ern:
  ```
  "x _ _ y" -> [Markdown.Paragraph([Markdown.Text("x _ _ y")])]
  "x _\t_ y" -> [..., Markdown.Emphasis([]), Markdown.Text(" y")]
  "x *\ta* y" -> [Markdown.Text("x "), Markdown.Emphasis([Markdown.Text("a")]), ...]
  ```
- Fix: `opens` and `closingRun` test `isSpaceOrTab` where they test `' '`.

#### Clarity

**C1. The proxy's constructor `Never` reuses the prelude's empty type's name** (C/src/libs/proxy/proxy.ern:55)
- Quote: `type Target(m) = Found(Address(m)) | Away(Address(m)) | Never`.
- What is wrong: guide/style says a prelude name is bound to nothing else in the library.
- Also: `sent` (lines 112-117) repeats `send(address, message)` in two arms. An or-pattern binds across constructors, as S/orpattern/orpattern.ern shows: `Found(address) or Away(address) -> ...` prints `1`, `2`, `none`.
- Fix: rename it `Nowhere`, the old code's word, and join the two arms.

**C2. Copy kept: `slowest.contents`** (C/tools/slowest.ern:112-122)
- Quote: `fn contents(path : Path) : String`.
- What is wrong: it is `Repository.contents("slowest", Path.toString(path))`, with the same reads and the same messages. The diff moved the tools' reading into `Repository` and left this copy, with no comment. Read and not shown.
- Fix: call `Repository.contents`.

**C3. Copy kept: `flakes.quit`** (C/tools/flakes.ern:356-359)
- Quote: `fn quit(message) : a = { said(message); Os.exit(1) }`.
- What is wrong: it is `Repository.quit("make flakes", message)`. Read and not shown.
- Fix: call `Repository.quit`.

**C4. The borrowed-file filter is written at 3 sites that must agree**
- Places: C/tools/sizes.ern (`listed`), C/tools/clones.ern (`cloned`), C/tools/words.ern (`withoutBorrowed`).
- Quote: `Set.fromList(Repository.borrowed(tool))`, then a filter.
- What is wrong: `clones` builds the set once per language, so it reads THIRD_PARTY_LICENSES twice. Read and not shown.
- Fix: `Repository.withoutBorrowed(tool, paths)`.

**C5. The tools disagree on a tracked file the working tree no longer holds**
- Places: C/tools/words.ern `contents`, which answers `""` for `Io.NotFound`; `Repository.bytes` and `Repository.contents`, which quit.
- Shown in S/missing/repo, a repository of mine with one tracked file removed, running the clone's built tools:
  ```
  sizes: cannot read src/b.ern: Io.NotFound     (exit 1)
  clones: cannot read src/b.ern: Io.NotFound    (exit 1)
  words comments 1 -> no output                 (exit 0)
  ```
- Fix: one rule in `Repository` for a file `git ls-files` lists and the working tree lacks.

**C6. `isWritable` checks only the value** (C/src/libs/http/http.ern:1700)
- Quote: `fn isWritable(header : Header) : Bool = isPlain(String.toUtf8(header.value))`.
- What is wrong: a header this calls writable still faults `checkHeader` (line 1686) when its name is no token. Its callers at 1779 and 1819 read it as "the header can be written".
- Fix: rename it `isPlainValue`.

**C7. Locals shadow their module's own top-level functions**
- Count: 33 sites in my part, 53 over all the Ernest sources. At least 11 were added by the diff.
- Examples:
  - http.ern:1509 `let encoded = List.filter(String.split(relative, "/"), ...)`, under `fn encoded` at 1429
  - uri.ern:739 `let written = List.map(references, toString)`, under `fn written`
  - http.ern:4205 `let written =`, in the test `writtenMalformed`
  - markdown.ern:675 `kept` and 1529 `spaced`
  - clones.ern:137 `kept`
  - links.ern:268 `named` and 288 `linked`
  - run.ern:409 `titled`
- Shown by a shell loop over `git ls-files` that matches `let name =` against the file's own `fn name`. Its output is at S/shadows.txt.
- Fix: rename each local; for example, `segments` at http.ern:1509 and `texts` at uri.ern:739.

**C8. A value given to a case `String.split` rules out** (C/tools/repository.ern:64-75 `pathOf`; C/tools/documents.ern:670 `testOf`)
- Quotes: `match String.split(String.trim(named), " ") { first :: _ -> ... | [] -> None }` and `Optional.withDefault(List.last(String.split(source, "/")), source)`.
- What is wrong: `String.split`'s page says the list "holds one part at least", and guide/style gives such a case no value.
- Fix: `String.splitOnce`, or match the part that is always there.

**C9. `Unread(why : String)`** (C/tools/documents.ern, `type Reading`)
- What is wrong: the glossary refuses `why` for a cause or an error.
- Fix: `cause`.

**C10. `uncheckedRows` folds a set into a set by hand** (C/tools/documents.ern)
- Quote: `List.foldLeft(readings, Set.empty, fn(all, #(_, reading)) = Set.fold(placesOf(reading), all, Set.put))`.
- Fix: `Set.union(all, placesOf(reading))`.

**C11. A constructor `Citations` beside the module `Citations`** (C/tools/documents.ern, `type Job = Lengths | Citations | ...`)
- What is wrong: the same file calls `Citations.pieces`, `Citations.Report` and `Citations.numberAt`, so a reader meets one name for two things.
- Fix: rename the job `CitedSections`, or another word.

**C12. `snake.freePoint` draws a random number it does not use** (C/examples/snake.ern)
- Quote: `Random.nextInt(world.seed, Int.max(1, List.size(free)))`, with the comment "a bound of 1 where no cell is free, whose draw finds none".
- What is wrong: it draws to avoid `nextInt`'s fault at bound 0. The old `[] -> None` arm said the same thing directly. Read and not shown.
- Fix: match `free` against `[]` first.

**C13. Minor comments and names** (read and not shown)
- The crypto test comment "fault the caller, either the shorter" does not parse.
- The base64 test name `countsNoMultipleOfFour` reads oddly.
- The json helper `longAt` says nothing of its work.
- Test comments without a final period:
  - utilization `cpuTimeout`, "...is not met"
  - http `datesOutside`, "Written with the code"
  - http `writtenMalformed`
- "the cause the listing gives" does not say which listing.
- The comment on http's `trickle` (line 3411) says "a client" twice: "A client that writes one byte at a time, 10 milliseconds apart, a client that writes slowly".
- links.ern inlines `first >= 'A' && first <= 'Z'` where citations.ern keeps `isCapital`.
- Fix: rewrite each.

#### Where the language made the code harder

**L1. `List.splitWhile` with one half dropped: 23 sites**
- 15 keep the rest, which is `dropWhile`'s work, and 8 keep the prefix, which is `takeWhile`'s.
- By file: markdown 9; documents 2; site/links 2; site/document 2; words 1; site/run 1; site/report 1; site/code_block 1; site.ern 1; manual 1; shell complete 1; shell listing 1.
- The log decided `dropWhile` stays out on 2026-11-07, at 7 sites. The diff's rename of `List.span` to `List.splitWhile` grew the count.

**L2. Trimming by a predicate, written by hand: 3 sites** (markdown.ern:675, 741, 860-861)
- Form: `List.splitWhile(List.reverse(String.toList(line)), isSpaceOrTab)`.
- `String.trim` trims all white space, and no trim takes a predicate.

**L3. A byte cannot be compared with an ASCII character literal: 39 lines in 4 libraries**
- By library: uri 14, base64 15, json 5, http 5. An example: `octet >= 0x41 && octet <= 0x5A`.
- A hex digit's value is written in uri.ern:251-256 and tested again in json.ern:491.

**L4. `Uri.encode` checks its own ASCII again** (uri.ern:279)
- Quote: `match String.fromUtf8(...) { Some(text) -> text | None -> fault("a percent-encoding is ASCII") }`.
- The language gives no way to make a String from bytes known to be ASCII without a fault arm. 1 site.

**L5. No fold over Optional that stops at the first `None`** (documents.ern `recordOf`)
- It folds with `List.foldLeft` and `let record <- read`, walking the rest of the list after a failure. `List.tryFold` (list.ern:765) takes `Either` only.

**L6. Private functions whose type names no type of their program's own: 393 of 792 in my part, 740 of 1560 over all `.ern` sources**
- Largest: http 55; markdown 49; documents 24; site/links 24; manual 17; site.ern 17; code_block 16; json 15.
- Counted by S/scripts/owntypes.py. It is a heuristic: a signature naming no type the module declares counts.
- Library candidates the diff adds: markdown's `isSpaceOrTab`, http's `fourDigits`, uri's `isUnreserved` and its hex digit.

**L7. The interpreter writes its parse type over and over (feedback 286 holds it)** (C/examples/interpreter.ern:256-274)
- `Either(ParseError, #(Expression, List(Token)))` appears 10 times.
- `ern format` lays the new `leftAssociative` and `joined` over 8 lines each.

**L8. `fetch.ern` matches the prefix of `Io.Other`'s text (feedback 285 holds it)**
- Quote: `Io.Other(text) when String.startsWith(text, Path.toString(caFile) <> ": ")`.

#### Read, with no finding
- The clones listing's lines in my part:
  - http 1875-1935 is `reason`'s table
  - http 3093/4062 and 3137/4071, json 569/715, markdown 2146/2362 and documents 1016/1026 are tests of one shape
- The json shim for a repeated member, and its tests.
- `Crypto.bitXor`.
- `Ets.ownedCount` and its page.
- `Http.filePath` at its edges: in S/paths/paths.ern, an encoded `..`, `%2F`, NUL and non-UTF-8 are all refused.
- `Http.reason`: 60 entries.
- The Markdown renderer's styled rows: S/render/render.ern and S/render/plain.ern.
- `Html.fragment` as `Uri.encode`: site.js decodes the fragment at lines 842 and 1057-1061.
- An IPvFuture literal answers `None`, as the page says: S/future/future.ern.
- utilization's 5000 ms timeout.
- services `asked`, wc's line count, the upgrade examples, links' `parts`, citations' `main`, manual's `raised`.
- The pages for crypto, ets, json, uri, http, markdown, proxy, utilization, time and base64, written under S/pages/<lib>/.

I started no long-running process or node.

### S

The review covers `git diff 93a13b13 6c6b8ef1` over src/runtime, src/nodes, src/toolchain/cli, src/toolchain/builder, src/shell, src/stdlib, src/libs and site/root/assets/js, read against §8.4, §11.2, §11.3, E.17, E.18 and E.23.

**Counts:** real exposures 1 · hardening 3 · other defects 0 · clarity 2 · kept for a reason a later rule removed 0 · where the language made the work harder 1.

All probes are kept under `readers/S`, written `S/` below. None of my processes is left running.

#### Real exposures

1. **`Uri.toString` writes a text that parses as a different reference. Combined with `Http.target`, a request target becomes an off-site redirect.**
   - **Place:** `src/libs/uri/uri.ern:333` (`toString`, new in 0.11.0) and `report/library.md:1419`.
   - **Quote:** the report says "the reference recomposed as RFC 3986 §5.3 has it: each component that is there, as it stands, with its delimiter… A reference `parse` answered is written as a text `parse` reads as that reference."
   - **What's wrong:** the promise covers only references `parse` answered, and is silent on every other reference. `Http.target` answers others on purpose (http.ern:1385, "a path that begins with `//` would be read as an authority's start"). For `GET //evil.example`, its path is `//evil.example` with no authority. `toString` writes that path as it stands, and the text reads back with `evil.example` as the authority. A server that adds a trailing `/` to a directory request and writes `Location` with `toString` therefore redirects off-site. Two other recompositions also change meaning:
     - no scheme, and a first path segment that holds `:`. The path becomes a scheme (`javascript:`).
     - an authority before a path that does not begin with `/`. The path is glued onto the host.
   - **Who is exposed:** no program in the repository uses `toString` yet. ernest-httpd writes its `Location` as `https://` plus its canonical host, so it is not exposed.
   - **Program:** `S/probe4/src/redirect.ern`, run with `ern run src/redirect.erc`:
     ```
     target: Some(Uri.Reference(scheme = None, authority = None, path = "//evil.example", query = None, fragment = None))
     /docs -> Location: /docs/
     //evil.example -> Location: //evil.example/
     //evil.example/%2e%2e -> Location: //evil.example/%2e%2e/
     parsed back: Some(Uri.Reference(scheme = None, authority = Some(Uri.Authority(userinfo = None, host = "evil.example", port = None)), path = "/", query = None, fragment = None))
     colon path: javascript:alert(1) parsed back: Some(Uri.Reference(scheme = Some("javascript"), authority = None, path = "alert(1)", query = None, fragment = None))
     glued: https://good.example.evil.example/x parsed back: Some(Uri.Reference(scheme = Some("https"), authority = Some(Uri.Authority(userinfo = None, host = "good.example.evil.example", port = None)), path = "/x", query = None, fragment = None))
     ```
   - **Fix:** in the report and in the code, write `/.` before a path that begins `//` when there is no authority (the WHATWG serializer does this), and `./` before a first segment that holds `:` when there is no scheme (RFC 3986 §4.2). When there is an authority and the path is neither empty nor begins `/`, put `/` before the path or fault.

#### Hardening

2. **`Markdown.render` passes control characters from the text into rows meant for a terminal.**
   - **Place:** `src/libs/markdown/markdown.ern`, the render path. The file changed in this diff, but this behavior did not: neither version filters controls.
   - **What's wrong:** a program that renders Markdown it did not write, for example a comment from the network, passes the author's OSC and CSI sequences straight to the terminal. Those include setting the title, clearing the screen and, on many terminals, writing the clipboard with OSC 52. Ernest's own uses are safe: the lexer refuses raw controls in source, so a doc comment cannot carry one.
   - **Program:** `S/probe6/src/render.ern`:
     ```
     "Nice \u{1B}[3mpost\u{1B}[23m\u{1B}]0;owned\u{7}\u{1B}[2J and \u{1B}[36mcode\u{1B}[39m\u{9B}31mred"
     ```
   - **Lexer check:** `S/probe9/src/dep.ern` gives `src/dep.ern:1:11: control character U+001B`.
   - **Fix:** render writes each C0 and C1 control in the text, other than the styles it adds itself, as `\u{1B}` (the form `Refusal.controlFree` and `Io.show` use), and the report says so in G.2.

3. **The node's and the shell's file checks look at mode bits and never at the owner. Read and not shown, since showing it needs a second user.**
   - **Place:** `src/nodes/ern_node.erl:425` `owners_alone/5` and `:443` `found/2`, both new in this diff. Also `src/shell/ernest/shell.ern:592` `isWrittenByOthers`.
   - **Quote:** "Mode band Bits =:= 0" and "its mode where it is there…, a link followed".
   - **What's wrong:** the configuration directory, `ernest.conf`, `private-key.pem` and the configured `startup` pass when they are owned by another user with mode `0755`/`0644`. That user then writes the node's peers and key, or what the shell runs. Two paths lead there: a directory of another user's chosen by mistake, or a `startup` that is a link to another user's file. The checks were otherwise good: a `0777` directory and a `0666` startup were both refused (`S/probe7`, outputs `ern shell: n2 may be written by others than its owner; chmod go-w n2` and `n2/startup may be written by others than its owner, and is not run`).
   - **Fix:** also refuse each of these when it is not owned by the job's user or by root, as sshd's StrictModes does.

4. **`Fs.makeTempDir` leaves a "held" directory behind on each redraw. Read and not shown.**
   - **Place:** `src/runtime/ern_fs.erl:371` `temp_dir/1`, `:398` `private/1`.
   - **Quote:** "`held` where another put an entry in it… the entry left where it stands", and `held -> temp_dir(Parent)`.
   - **What's wrong:** the window between `make_dir` (under the umask) and the `chmod 0700` is caught. But the caught directory, now private and holding another user's entry, stays in the parent, and nothing says so. Only a umask that lets others write opens the window.
   - **Fix:** `file:del_dir_r(Directory)` before the redraw. It removes links without following them.

#### Clarity

5. **The private-directory check now exists twice, and the two copies answer the same event differently.**
   - **Place:** `src/toolchain/builder/ern_build.erl:2893` `make_private_dir/1` and `src/runtime/ern_fs.erl:398` `private/1`, the second added in this diff. The comment on the second reads "as ern_build:make_private_dir/1 checks".
   - **What's wrong:** on a held directory, the builder's copy refuses with "it was written to by another as it was made", which reaches `ern config` and `ern test`'s example directory. The runtime's copy redraws.
   - **Fix:** `make_private_dir` becomes `file:make_dir` followed by `ern_fs:private/1`, choosing one answer for `held`.

6. **A 0.10 configuration directory is refused with a text that reads like a typo.**
   - **Place:** `src/nodes/ern_node.erl:34`. `?FIELDS` dropped `public-key`.
   - **Program:** `S/probe7`, an `ern config` directory with a top-level `public-key` added:
     ```
     ern run: node/ernest.conf: the file has the unknown field public-key
     status 1
     ```
   - **What's wrong:** the log's 2026-11-23 *The key has one owner* and 2026-11-25 entries know about the break. The refusal does not say the field was removed or that the key now lives in `private-key.pem`.
   - **Fix:** a refusal of its own for this field, for example "`public-key` is no longer a field: the key is read from private-key.pem; remove it".

#### Kept for a reason a later rule removed

None found. I checked these and each still has a reason:
- The startup file's mode check, now that the directory is checked: the directory's mode does not protect a `0666` file inside it.
- `ernest.conf`'s own mode check: same reason.
- `is_unopened` together with `O_NOFOLLOW` in `ern_exec.c`: they cover different cases, a FIFO and a link.
- `Tcp.address`'s filter of `%`, `+` and `-`: `inet:parse_strict_address` accepts `fe80::1%eth0` and `+1.2.3.4`.
- The own-key-among-peers check.
- The `ERN_GIVEN_` list.

#### Where the language made the work harder

7. In `S/probe3/src/boundary.ern`, a helper that monitors had to declare `receiving Down` on itself and on `main`, after "monitor needs a mailbox, and taken receives nothing". The diagnostic was clear and the change took one line.

#### Read and held, with the input tried

- **`Http.filePath` traversal** held: `/%2e%2E/x`, `/a/%2e%2e%2fetc`, `/.%2e/x`, `http://h/%2e%2e/etc`, `//../etc` and `/%C0%AE%C0%AE/x` all gave `None`. Program: `S/probe1/src/paths.ern`.
- **`Os.Only` and `Os.Inherited`** held. Run with `ERL_OTP29_FLAGS`, `ERL_MAX_PORTS` and `ERL_ROOTDIR` set:
  - `Only([])` gives an empty environment.
  - `Only([A=1,A=2])` gives `A=2`.
  - `Inherited` gives the child the three variables, and `Os.environment` answers them.
  - Names that are empty or hold `=`, and NUL anywhere, give `Invalid`.

  Program: `S/probe2/src/envs.ern`.
- **The foreign boundary** held:
  - A function returned, nested, in a list, or given back through a callback: each receiver faulted with "message does not match Int".
  - Foreign code returning the caller's own pid was refused with "the return of foreign function sly:own_pid/0 does not match Address(Int): is <0.163.0>".

  Programs: `S/probe3/src/boundary.ern` and `S/probe3/src/sly.erl`.
- **The TLS listener** held:
  - A TLS 1.2 renegotiation the client asks for is refused: the client printed "no renegotiation" and the server answered `Left(Io.Closed)`.
  - Garbage and a malformed hello are answered as `Io.Other(...)` in the host's own words, with nothing on standard error.
  - An Ed25519 certificate fails every TLS 1.2 handshake. That is the host's ssl, not this diff.

  Program: `S/probe5/src/tls.ern`.
- **The attached shell's local half** held: `isUnder` refuses `..`, `.`, absolute paths outside the root and `root/../x`, and accepts `//` inside the root. Program: `S/probe8/src/under.ern`, a copy of the shell's function.
- **Read, nothing found:** header values with CR, LF or NUL are refused on write; `Json` refuses a repeated member; the doc sweep removes only a page whose title and place agree (it reads each `.md` under the mirror whole, which only costs time); `ern_out`'s stamped host reports; the shell's history file (unchanged); the program's arguments (unchanged); `site.js` (renames, a stylesheet promise, a guard in `showLimits`, the same-origin swap of four parts, with no new sink).
