# The findings of the release review before 0.4.0

Read at commit fb2324e8 on 2026-10-18 by four readers, as [`release_review.md`](release_review.md) runs them: KP, the report's reader, K and P as one, over what changed since `v0.3.1`; N, the newcomer, who wrote `pubsub`, a broker of topics, and ran it on one node and on two; U, the guide's reader, over the sections that teach what changed; C, the code's reader, C, E and S as one, over the node's modules. The lines are sorted as [`full_review.md`](full_review.md)'s *The findings* says, and each now carries what became of it, decided 2026-10-18 and argued in the log's *The Release Review Before 0.4.0*: `done`, made in MVP 3.2's item 11, the line saying what was done; `dropped`, with the reason; `planned`, with the milestone; `release`, done by the release's own steps. The file goes with the tag. Each reader's whole list stands below the lines. The list's milestone is MVP 3.2, item 11.

## The lines

**Defects of the language and the runtime**

- KP1 `done`: `Code.running(f)` of a function that receives nothing answers addresses at a free mailbox type, and a send through one breaks the receiver's mailbox; a well-typed program dies of a host case clause. Done: `List(Address(Never))` for such a function, as §6.2 makes an unfixed spawned mailbox type `Never`; §3.11 and E.28 state it, the checker holds it, the soundness paragraph (KP8) follows.
- KP2 `done`: two functions with one body are one definition, and a fault names the first declared as its spawn site, a function the program never ran. Done: state the merge in §6.9 and §11.1 and its cost in the log; a duplicate body is rare, and a site of its own would need a function of its own per declaration against one identity.
- S1 `done`: on a dial, a listed peer can answer under another listed peer's name, since the server certificate is tied to no dialed host. The dial binds the certificate to the host dialed and refuses another, saying which peer answered the dial of which, with a test that dials and is answered by another listed key.
- KP28 `done`: a `Test.Case(m)` a helper builds is refused where §6.2 leads a reader to expect `Never`. Done: in §4.6 an effect-only variable left in such a type is `Never`, as §6.2.
- KP6 `done`: a program may not set a utilization above 1.0 where the measure reports one. Done: `setUtilization` takes any number at or above 0.0; §8.7, E.27 and §7.4 follow.
- KP12 `done`: `memory`'s `check-interval` is stated in minutes and taken as milliseconds that are a multiple of 60000; the report says a multiple of 60000.
- U35 `done`: a file at a module's path that holds another module makes a node say the module is not on the load path; the message names the file and the module it holds.
- S2 `done`: an exchange a peer never completes stays until a loss; the frames carry the sender's `ms`, and the exchange drops when the latest passes, said and not answered.
- S3 `done`: a gateway's record of a node that said it ends stays while the node stays connected; the node stops telling once it has said it, and a telling after the word drops the record.

**The report**

- KP3 `done`: §3.11 names `Peer.compute` alone for the result-type refusal that `computeAt` meets too; both named, in E.27 too. KP10 `done`: §3.9's capture refusal names the computes too.
- KP4 `done`: §6.10's snippet writes `Upgrade` where another module must write `Counter.Upgrade`.
- KP5 `done`: how a bare node ends, §8.7 against §8.6; §8.7 says "as §8.6 says, never by its entry process's return".
- KP7 `done`: "within `ms`" in §6.7 and E.27 against §8.7's step; the two say "within `ms` and the step of the attempt (§8.7)".
- KP9 `done`: §8.1's "whose site is `bare node` (§6.9)"; §6.9 gains the sentence.
- KP11 `done`: Appendix F's **gateway** against §8.7 on a compute's frame; one wording.
- KP13 `done`: §11.2's "lambdas" against "function entries"; one word.
- KP14 `done`: §8.7's pointer to **Connections** for a rule under **A loss**.
- KP15 `done`: Appendix F's **unit** gains `ern test`'s exception.
- KP16 `done`: E.28 states that `hashes` writes lower-case hexadecimal.
- KP17 `done`: §8.7 states that a name is held by one address whatever its hash, once the code is read for it.
- KP18 `done`: E.28's error list, one answer a sentence.
- KP19 `done`: what a patch release may not change is unstated. Done: §8.7 states that a patch changes no type of the standard library's, no foreign declaration's type and no form's version, which the floor admits unhashed.
- KP20 `done`: run-queue's wording, §8.7 against G.4; the two read different counters, and each says which.
- KP21 `release`: §11.7's `ern 0.3.1` example, with the version.
- KP22 `done`: soundness.md's revision date.
- KP8 `done` after KP1: soundness's "three refusals" are four; cite `computeAt`; a `Code.running` paragraph.
- KP23 `dropped`: every node that lists peers sends each a telling every five seconds whether or not the program picks by it. Kept, argued in the log: a frame each way per interval is the cost of knowing a peer is alive and how busy, which a program that never picks still reads in `Peer.utilizations`, and the loss detector rides on the same connection.
- KP24 `dropped`: `Peer.compute` is `utilizations` plus a pick plus `computeAt` with the library's policy, which G.5's `Placement` was removed for. Kept, argued in the log: the pick is two at random and the less busy taken, one rule stated in E.27, and a program that wants another writes `computeAt`; the decision of 2026-10-13 stands.
- KP25 `done`: two ways to learn a utilization, asked and told. Done: E.27 says when each is the one, the ask for a peer not connected or a fresh reading, the tellings for the pick's view; one sentence.
- KP26 `planned`, MVP 3.9: §8.7 states runtime machinery, fourteen frames, the gateway's workers, the notes' bookkeeping, a dozen Appendix F concepts. Recommendation: at 0.5.0's full review, with G's read of the report's register, move what a program never sees to docs/architecture.md; not before the tag.
- KP27 `dropped`: `measures` in `ernest.conf` serves G.4 alone. Kept, argued in the log: the node's own telling reads the measures, so the node owns them.
- KP29 `dropped`: `Peer.name` and `Code.hashes` buy little. Kept: `Peer.name` is G.7's and `Code.hashes` is `ern`'s job given to a program, each with one user.
- KP30 `planned`, MVP 3.27: Appendix H hashes a type annotation beside the scheme that holds it, so two spellings of one typed tree are two hashes. Recommendation: hash the scheme and the body and leave the annotation out, with a form version; after the tag, as the first change of the form.

**The guide and the questions**

- U1, N6 `done`: §10's "carries its captured values and no code"; a spawn or a compute carries what the peer lacks.
- U2 `done`: §10's "whether it may send or receive"; whether it receives.
- U3, N7 `done`: §8.1's "runs only where the peer holds it" and the load path; the peer is sent what it lacks, and `NotLoaded` is a binding without a value or a host module missing.
- U4, N14 `done`: §13's answer to §8.8, by reach, in two sentences.
- U5 `done`: §10's "only the shell's `:reload`"; `Code.load` and a peer's spawn or compute too.
- U9 `done`: §8.1 starts `foo` as a bare node and drops `idle.erc`.
- U11 `done`: §9.1's rule of recompilation gains a dependency's definition the code uses.
- U12 `done`: §3.3's call-initialized `let`, generalized where its type holds no function, foreign value, address or reply.
- U14 `done`: the floor is one minor release, any patch.
- U15 `done`: `callForever`'s causes gain the node out of reach.
- U16 `done`: a fault crossing back carries a stack beneath a runtime failure or a foreign raise alone, in §8.1 and §11.2.
- U17, N11 `done`: the FAQ's "§8.7" is §8.1, and its "§4.1" for `adapted` is §5.5.
- U7 `done`: a send dials a lost peer again, in the deployment guide and §8.3.
- U6 `done`: the deployment guide's §8 says the shell is connected to `b` alone.
- U10 `done`: the deployment guide's "where one is slow" goes.
- U13 `done`: the deployment guide's cause of "answered under another name", a mismatched key and address; copies go to the `replaced` row.
- U18 `done`: the deployment guide's §6 session printed as the shell prints it, with the program it assumes named.
- U19 `done`: why.md's reload session shows the diagnostic whole.
- U8 `done`: nothing in the guide teaches `Code.running`, `Code.load` or §6.10's rule that a type carrying `Upgrade` is bound, which the deployment guide's §5.3 sends its reader to. Done: a section in chapter 8 before the tag, from `examples/upgrade`, since a running service moved to new code is what this release is for.
- U20, N10 `done`: the FAQ's `Mailbox` paragraph, a proposal's API, goes.
- U21 `done`: the deployment guide's "planned and not yet built" goes; `docs/development.md`'s table gains the row.
- U22 `done`: the FAQ says a message is checked on delivery, as §8.4.
- U23, N28, N29, N30, N31, N32, N33, N27 `done`: a word relied on before said gets its sentence or its pointer at first use: hash, find, `Peer.find`, `Foreign.Term`, `<<>>`, supervisor, `Process.status`, `Tcp.give`, the principles, `spawnMonitored` and `Down` in §4.4.
- U24 `dropped`: §8.3 calls `Gather.gathered` instead of writing it again; it stands, since each section's program is built on its own and the chapter's reader starts there.
- U25 `done`: §8.1 cites the deployment guide's §4.1.
- U26 `done`: §5.5 qualifies where an adapted address applies its function.
- U27 `done`: §8.1 names `restarting` among the forms a peer runs.
- U28 `done`: §11's summary of §0 gains principle 5's clause and principle 3's.
- U29, U30, U31, U32, U33, U34 `done`: the shell's count, `:reload`'s scope, the store's `kill`, the load path for the nodes of §8.2, whose lines a console shows, "need only dial".
- N8 `done`: why.md says `OrderedSet` is a module of the standard library whose type is `OrderedSet.Set`, and `Set` the prelude's type.
- N9, N26 `done`: the FAQ's `todo` goes.
- N12 `done`: §3.1 says which `{` ends a lambda's body.
- N13 `done`: §3.5's sentence on what fixes `n`, in two with examples.
- N15 `done`: §8.3's sentence gets its verb. N16 `done`: §2.9's `k=` is `a=`.
- N17 `done`: §8.1 says what to wait for before the second node runs: the first's `the peer a connected` on its terminal.
- N24, N35 `done`: §2.9 points at Appendix E for the list of modules in place of "a few more".
- N19 `dropped`: `ern format` lays `else {` of a `let`-bound `if` at the `let`'s column. Kept: §11.6's layout of a construct that does not fit its line is the same in every position, and the guide's §2.7 shows it.
- N34 `dropped`: "a report of three files" counts files, which is what it says. N36 `dropped`: "the rules are few" is followed by the rules.
- N37, N38, N39, N40, N42 `dropped`: the FAQ's answers to "what differs" and §10's list for an Erlang programmer compare by the question asked; the rule binds the claims. N41 `dropped`: the lead names what the reader looks for, not another system's lack.
- N18 `release`: the shell transcripts' version line, with `VERSION`.
- N1 `release`: the README's *Where it stands* says the version the reader holds at the tag; what does not work yet is `docs/development.md`'s table, which it points at.
- N2, N3, N4, N5 `done`: the README's "for each but the last"; `restarting(Unlimited, f)` said and `count is 8` shown; the manual pages' line; what the archive holds.

**The toolchain's messages**

- N20 `done`: the compiler's help cites a bare section number, which a guide reader takes for the guide's. Done: `(report §3.11)`, in `ern_bound`'s three help texts and wherever else a help cites; the catalog is written again.
- N23 `done`: a receive guard that calls a function is refused with the help to `match` the message, which changes the meaning. Done: the help offers a `let` before the `receive` first.
- N21 `done`: `:browse Address` says no module is in scope where `:doc Address` answers. Done: `:browse` of a prelude namespace lists its functions, as `:browse Prelude` does; §11.2 states it.
- N22 `dropped`: a fault's line `Pubsub.subscriberOf:247 faulted` reads as a line of the fault and names the spawn site. Kept: §6.9 defines the site as where the process was spawned and §11.2 the line, and the trace beneath names the line of the fault.

**The code**

- C1 `done`: the comment on a code frame's `References` says it is a check the arrival recomputes.
- C2 `done`: a malformed `VERSION` is refused plainly.
- C3 `done`: the stale measured number goes.
- C4, C5, C6, C7 `done`: one helper for a qualified name's text, for a scheme's arity, for a peer name's text, and for the gateway's pid.
- E1 `done`: `Code.load`'s doc names the two `Invalid` causes of E.28. E2, E3 `done`: reflowed. E4 `done`: a `Service` is made by `service` alone.

**What writing Ernest felt against a principle**, to `docs/language_feedback.md`

- N43 `done`: a request with named fields is not a function, so a call writes a six-line lambda, and the call chose the messages' shape.
- N44 `done`: `receiving MainMsg` spreads up the chain of helpers that spawn a monitored process.
- N45 `done`: addresses have no equality, so a broker keeps two maps that must agree.
- N46, N47 `done`: a receive guard may not call `Process.fromAddress`; a precondition needs `else Unit`.
- N25 `done`: a call to many processes at once is thirty-five lines a use.

**Names**, each decided after the word is searched across the report, the code and the shell

- N48 `adapted` for `Address.map` `dropped`: keep; an adapted address is §6.5's word, and `map` would say the value changes where the address does.
- N49 `OrderedSet.Set(a)` `dropped`: keep; a module's type bears the module's name, as `Stack.Stack`, and `Set` is the prelude's.
- N50 `answer` for `reply` `dropped`: keep; `Reply` is the value and `answer` what is done with it, one word each.
- N51 `spawnMonitored` `dropped`: keep; the style's past participle for a value made so.
- N52 `fault` for `panic` `dropped`: keep; §7's word.
- N53 `Process.current()` beside `self()` `dropped`: keep; `self()` is the address and `current` the process, two types.
- N54 `Returned` for `Normal` `dropped`: keep; the reason says what happened.
- N55 `Unknown` for a process already dead `dropped`: keep; the runtime does not know how it ended.
- N56 `Os.termination(wrap)` `dropped`: keep; the shape of every subscription, E.0 rule 8.
- N57 `Peer.offer`/`find` for `register`/`lookup` `dropped`: keep; §8.7's words, and a registry is what Ernest has not.
- N58 `List.maximumBy(list, key)` `done`: Haskell's `maximumBy` takes a comparator, Ernest's a key. Done: E.2's two `By` functions both take a key, and E.2 says so; kept.

## The lists

### KP

# Findings KP: the report read for 0.4.0 (K and P as one)

Repository at fb2324e8. Read: §0 whole; every section `git diff v0.3.1 fb2324e8 -- report/` touches, which is nearly every section of the three files, each whole as it stands; Appendix A wherever a touched section names syntax; docs/soundness.md whole, since its diff covers it whole. Programs were built and run under `scratchpad/release/KP/` with `bin/ern`; the repository was not changed. Line numbers are of the files at fb2324e8.

## Defects

**KP1. `Code.running` of a function that receives nothing gives addresses at a free mailbox type, and a message sent through one breaks the receiver's mailbox.** report/language.md §3.11 line 330: "the call's type is `List(Address(m))`, `m` the function's mailbox type ... since every process listed has it as its mailbox type, or, for a function that receives nothing, a type variable that nothing fixes". The "since" clause is false for a function that receives nothing: it runs on the stack of a process whose mailbox type is another function's, and the free `m` lets `send` put a value of any type there. Program (`KP/a/main.ern`): `fn work(n : Int) : Unit = if n == 0 then Unit else work(n - 1)`, `fn loop() : Unit receiving Msg = receive { m -> match m { Text(s) -> ... } }`, `spawn(fn() = { work(30_000_000); loop() })`, then `List.forEach(Code.running(work), fn(q) = send(q, 42))`. It compiles, and `ern run` prints `Main.main:14 faulted: error:{case_clause,42}`, a cause §7.4 does not list; soundness claims 1 and 2 and invariant I2 fall. Fix: for a function that receives nothing, `Code.running(f)` is `List(Address(Never))`, as §6.2 makes an unfixed spawned mailbox type `Never`; state it in §3.11 and E.28 line 814/821, and give soundness.md a paragraph for `Code.running` (KP8).

**KP2. Two functions with one body are one definition, and the spawn site and the trace name the first declared: control flow the text shows is reported under another name.** Appendix H line 349: "within their module a reference to either is to the first declared, whose spawn sites (§6.9) its processes carry and whose name a fault's trace shows"; §8.7 line 1010: "two functions with one body are one definition". Program (`KP/b/main.ern`): `fn a()` and `fn b()` each spawn `fn() = fault("boom")` and wait; `main` calls `b()` alone. `ern run` prints `Main.a:2 faulted: boom`, a site in a function the program never ran, at a line where no spawn of `b`'s stands. A reader who knows §6.9 ("the qualified name of the top-level declaration in which the `spawn` ... is written, with the line") predicts `Main.b:7`. Principle 3: a fault is visible at the line that faults; here it is visible at another's. E.28 line 814 makes `Code.running(b)` list `a`'s processes by the same rule. Fix: the identity may merge; the site may not. §11.1 line 36 already keeps the definition's name and lines beside the form, outside the hash; record the site from the declaration written, and let `Code.running(f)` list processes of `f`'s declaration alone, or state in §6.9 that a site may name another declaration of the same body.

**KP3. §3.11 names `Peer.compute` alone for the result-type refusal; the toolchain refuses `Peer.computeAt` too.** report/language.md §3.11 line 324: "and a `Peer.compute` whose function's result type, which crosses back, is bound (§8.7)"; line 326: "the result type of the function a `Peer.compute` runs are known whole where they are written". Both sentences name `Peer.computeAt` beside `Peer.compute` for the other checks, so the omission reads as deliberate. Program (`KP/c/main.ern`): `Peer.computeAt("x", fn() = fn(y : Int) = y, 100)` is refused, `Peer.computeAt answers a value of type (Int) -> Int, which is bound to its node`. The code is right and the report is the gap. Fix: "a `Peer.compute` or a `Peer.computeAt` whose function's result type ..." in both lines, and E.27 line 778 likewise ("its result type is known whole where `compute` is written").

**KP4. The §6.10 upgrade-by-spawn example does not compile.** report/language.md §6.10 line 801: `Peer.spawn(name, fn() = send(Counter.service, Upgrade(migrate = Counter.double, next = Counter.count2)), 5000)`. `Counter.service` qualified says the writer is another module (§4.2 line 366: the qualified form within its own module is an error), where `Upgrade` must be `Counter.Upgrade`. Program (`KP/e/other.ern`, `counter.ern` as §6.10): `unknown constructor Upgrade`; with `Counter.Upgrade` it compiles, and so does line 803's `Code.running(Counter.count)` form. Fix: `Counter.Upgrade(...)`.

**KP5. How a bare node ends: §8.7 and §8.6 disagree.** report/language.md §8.7 line 984: a bare node "ends by termination alone (§8.6)"; §8.6 line 946: "a bare node ends by termination, by an `Os.exit` a process spawned on it calls, or by a stream that can no longer be written"; §11.8 line 316 agrees with §8.6, and §11.2 line 78 makes `ern shell --config-dir dir` a bare node, which ends by `:quit`. Fix §8.7: "ends as §8.6 says, never by its entry process's return".

**KP6. A program may not set a utilization the measure can report.** report/language.md §8.7 line 978: the scale is "1.0 is every scheduler busy, below it room, above it work waiting", and `"run-queue"` passes 1.0; line 1080 and E.27 lines 784 and 803: `Peer.setUtilization(x)`, "`x` from 0.0 to 1.0, a value outside the scale faulting (§7.4)"; §7.4 line 843. The scale the report defines goes above 1.0; the fault names 1.0 as "the scale". A program that knows it has work waiting cannot say so. Fix: `x` at or above 0.0, faulting below it; or state why a program's number is capped where the host's is not.

**KP7. A peer operation answers "within `ms`" in two sections and "later than `ms`" in a third.** report/language.md §6.7 line 750: "Each answers within `ms` milliseconds"; E.27 line 774: "within `ms` milliseconds"; §8.7 line 1044: "the runtime's own step of making the attempt ... comes beside it, so that the answer may come later than `ms` by that step, for a find, a compute and a utilization as for a spawn". Fix §6.7 and E.27: "within `ms` milliseconds and the runtime's step of making the attempt (§8.7)".

**KP8. The argument has no paragraph for the rule that breaks it, and miscounts the refusals it rests on.** docs/soundness.md section 7, line 234: "That no bound value is used on another node is by the three refusals"; §3.11 lines 324 to 326 list four (a service at a bound type, captures, a mailbox type, a compute's result). Line 240: "A compute's function is checked as a spawn's is ... its value crosses back at the type `a` the compiler checked at the compute, known whole and unbound there (§3.11)", which §3.11 states for `Peer.compute` alone (KP3). `Code.running` (§3.11 line 330, E.28), a rule changed since v0.3.1 that gives a program addresses, has no paragraph, and invariant I2 (line 93, "Each address of `a` has the type `Address(M)` for the mailbox type `M` of `a`") does not hold of what it answers for a function that receives nothing (KP1). Fix: a paragraph in section 7 or 6 for `Code.running` once KP1 is decided; "four refusals"; cite computeAt with compute.

## K, the cold reader: clarity

**KP9.** report/language.md §8.1 line 859: "its entry process, whose site is `bare node` (§6.9)". §6.9 line 768 says of the entry process only "For the entry process it is the entry point's name" and never names `bare node`; §11.2 line 144 cites nothing for it. Fix: add the sentence to §6.9, or cite §8.7.

**KP10.** report/language.md §3.9 line 289: "A `Peer.spawn` or `Peer.spawnMonitored` whose function captured a value whose type holds a type variable is refused (§3.11)". §3.11 line 324 refuses `Peer.compute` and `Peer.computeAt` for the same captures. Fix: name all four, or "a spawn or a compute on a peer".

**KP11.** report/language.md Appendix F line 1441, **gateway**: "a call's two notes, a compute, a utilization, a telling and a node's end, which it handles itself"; §8.7 line 1018: "a compute's frame, which it records so and hands on". The glossary says the gateway handles a compute; the section says it hands it to a worker. Fix one.

**KP12.** report/language.md §8.7 line 976: "`check-interval`, in milliseconds, and for `memory` a whole number of minutes"; Appendix C line 341: `"memory": {"check-interval": 60000, ...}`. The sentence reads as "a count of minutes" for `memory`, which makes the example 60000 minutes; the code (`erl/cli/src/ern_node.erl:374`, `Ms div 60000`) takes milliseconds that are a multiple of 60000. Fix: "in milliseconds, and for `memory` a multiple of 60000, since the host counts minutes there".

**KP13.** report/toolchain.md §11.2 line 96: "65,536 module names, 524,288 export entries, ..., 524,288 lambdas and 1,048,576 atoms"; line 202 and language.md §10 line 1204: "module names, export entries, function entries and atoms". Two names for the third count. Fix: one word.

**KP14.** report/language.md §8.7 line 1080: "a peer's loss drops its utilization (**Connections**)". The rule stands under **A loss** (line 1022, "drops ... its utilization"). Fix the pointer.

**KP15.** report/language.md Appendix F line 1543, **unit**: "held for the node's life"; §11.2 line 88: under `ern test` over a directory "a unit is held for its run and not the node's life". Fix: "held for the node's life, or a test run's (§11.2)".

**KP16.** report/library.md E.28 line 812: `hashes(path)` answers "a `String` of the digest in hexadecimal"; the case is unstated, and `Bytes.toHex` (E.20 line 593) writes upper-case letters. Program (`KP/f/main.ern`): `Code.hashes(Path("main.erc"))` answers `c704f2fb...`, lower-case. Fix: state the case.

**KP17.** report/language.md §8.7 line 1086: an offer answers "`Left(holder)` ... where the service is held", the node keeping an address "under the service's name and its type's hash"; line 1088: a find compares the hash after finding the name. Whether a second offer of the same name at another hash is `Left(holder)` or a second entry, and so whether a find can meet two, is left to guess. Fix: one sentence, "a name is held by one address, whatever its hash".

**KP18.** report/library.md E.28 line 810: "`Left(NotFound)` for a path with no file or a module of the reach the load path lacks, a directory or a file at a module's path that holds another module `Left(Invalid)`, and a file the host cannot read the host's error". The list loses its verbs: which answer a directory gets is read two ways. Fix: one answer a sentence.

**KP19.** report/language.md §8.7 line 1006: "a patch release of `ern` adds nothing and fixes, so two patch levels stand on one floor"; docs/soundness.md line 262: "two patch levels compute alike up to the fix". What a patch may not change is unstated: a standard library type's constructors, a foreign declaration's type or a prelude function's meaning each cross by the floor, unhashed (line 1008), and a patch that changed one would break I1 between two nodes the handshake admits. Fix: state in §8.7 what a patch release leaves as it is, or move those into the cookie.

**KP20.** report/language.md §8.7 line 978: `"run-queue"` "measures it as the processes running or ready to run, the one that answers left out"; report/library.md G.4 line 899: `runQueue` "answers the processes ready to run and waiting for a scheduler". The two readings of one counter differ by the running ones. Fix: one wording, or say the two read different counters.

**KP21.** report/toolchain.md §11.7 line 308: "`ern 0.3.1`, written to standard output". The example names the previous release.

**KP22.** docs/soundness.md line 5: "in their revision of 16 October 2026"; report/language.md and toolchain.md are of 17 October (§11.6's layout, which the argument does not cover). Fix the date.

## P, the principles

**KP23. A node that lists peers tells each of them its utilization every 5 seconds whether or not the program ever picks a peer by it.** report/language.md §8.7 line 1080, §10 line 1203, Appendix C line 341. Principle 5: "A feature costs a program that does not use it nothing". A program of two nodes that uses `Peer.spawn` alone pays a frame each way every `utilization-interval` for `Peer.compute`'s draw, and `ernest.conf` without the entry does not turn it off. Program: any node with one peer, `tcpdump` or the gateway's counters between two idle nodes. Fix: a node tells only while a peer has asked once (`Peer.utilization`, `Peer.compute` or `Peer.utilizations` called there), or the telling runs only where `utilization-interval` is written.

**KP24. `Peer.compute(f, ms)` is a second way to do what `Peer.utilizations()`, a pick and `Peer.computeAt` do, with a policy of the library's.** report/library.md E.27 line 778: "two at random and the less busy taken"; §8.7 line 1082. A program writes the same pick over `Peer.utilizations()` in four lines, which E.27 line 782 invites ("so that a program writes a rule of its own over them"); G.5 line 913 removed `Placement` for that reason and `Peer.compute` puts a pick back, this time in the runtime. E.0 rule 4 refuses a composition and rule 3 a buried policy; principle 2 refuses the second way. What it buys: one call. What would be lost: nothing a program cannot write, but a seed for the draw, which `Clock.now()` gives. Fix: drop `Peer.compute` and the telling with it (KP23), keeping `Peer.computeAt`; or state in the log why the draw must be the runtime's.

**KP25. Two ways to learn how busy a peer is.** report/library.md E.27 lines 782 and 800 to 802: `Peer.utilization(name, ms)` asks the peer; `Peer.utilizations()` reads what its tellings brought. A reader who wants a peer's number has to choose between a fresh one that costs a frame and a stale one that costs none, and nothing in either name says which. Principle 2. Fix: with KP24 the tellings go and `Peer.utilization` stays; otherwise state in E.27 when each is the one to call.

**KP26. §8.7 states the runtime's machinery, which buys a program nothing and adds a dozen concepts to Appendix F.** report/language.md §8.7 lines 1016 to 1018 ("Fourteen frames are the runtime's own ... A node has one *gateway*, a process that takes every frame ... hands each to a worker"), line 1040 (the notes' bookkeeping), line 1060 (the exchange's process). No rule a program is held to follows from which process hands a frame to which; §10 line 1211 already says the carrier is "the runtime's, fixed and documented with it". Appendix F gains gateway, detector, tick, carrier, note, code frame, exchange, frame, handshake, cookie, dial and start number, and principle 5 counts them. What a program sees and the report must keep: the loss and its 45 to 75 seconds, the 1 MB buffer, a dead address after a restart, §6.5's one step more, what a node says on standard error. Fix: move the machinery to docs/architecture.md and keep the observable rules; Appendix F then shrinks by about twelve.

**KP27. `measures` in `ernest.conf` is a normative rule that exists for one informative library.** report/language.md §8.7 line 976 and Appendix C line 341 configure `cpu_sup`, `memsup` and `disksup` so that G.4's `Utilization.cpu`, `memory` and `disk` answer `Some`. A program that never calls G.4 reads a section of §8.7 for it, and the configuration of every node carries a library's needs. Fix: let G.4 start the host's services itself through its own foreign functions, and take `measures` out of §8.7 and Appendix C; or say in §8.7 why the node must own them.

**KP28. A test case a helper builds is refused, where E.24 and §11.2 lead a reader to expect `Never`.** report/toolchain.md §11.2 line 84: "an `m` left open being `Never`, as §8.1 has it for an entry point"; report/language.md §4.6 line 443: a top-level `let` whose initializer is a call and whose type holds a function is not generalized, "and a type variable left in its type ... is a type error". Program (`KP/d/main.ern`): `fn case(name : String) : Test.Case(m) = Test.Case(name = name, run = fn() = Test.Passed)`, `let t = case("x")` is refused, "the type of t is not determined (Test.Case(e)) ... annotate it", and `let u : Test.Case(m) = case("y")` too; only `: Test.Case(Never)` passes. A reader who knows §6.2 (an unfixed mailbox type is `Never`) predicts the same of an effect-only variable left in a binding's type. Principle 1. Fix: in §4.6, a variable left in such a type that stands in effect positions alone is `Never`, as §6.2 says of a spawn's; the `: Test.Case(Never)` on every test built by a helper goes.

**KP29. Rules whose answer to "what does it buy a program" is little.** `Peer.name(service)` (E.27 line 793): the name the program wrote three tokens earlier; a library's fault text is its one user (G.7 line 939). `Code.hashes(path)` (E.28 line 812): what a program does with its own `.erc`'s hashes is unsaid; it reads as a job of `ern`'s given to a library. Neither is wrong; each is a function a reader who knows the type does not look for (principle 5's clause).

**KP30. Appendix H hashes a function's annotations as written.** report/toolchain.md Appendix H line 362: `{function, Scheme, Params, Annotation, Annotation, Needs, Expr}`, "the annotations of its result type and of its mailbox type, its requirement as written"; the `Scheme` already holds the type and the requirement. `fn f(x : Int) : Int = x` and `fn f(x) : Int = x` are one typed tree and two hashes, so two nodes with one function differently annotated ship it twice. What it buys: nothing the scheme does not hold. Fix: hash the scheme and the body, and leave the annotations as written to **What is left out**.

Principle 4 (parsing): every decision a touched section's syntax needs is one or two tokens and Appendix A's closing paragraph names it (`fn` then ident or `(`; ident `.` then `userop` or ident; `=` or `:` after a constructor's first identifier; `->` after a parenthesized type list; `needs`, `derives` and the specifiers by position). No finding.

## The argument: steps that do not follow

See KP8 for the three. Beside them, docs/soundness.md section 7 line 258: "A unit once loaded is held for the node's life, but for an input's ... and for a unit of a run of `ern test` over a directory" rests on §11.2 line 88, which states it; Appendix F does not (KP15). Section 7 line 218, "two nodes that hold one hash hold one definition", with Appendix H line 349, is the step that makes KP2's site report: the argument says the hash leaves the name and site out "as a `String` the runtime never compares", which holds of I1 to I3 and says nothing of principle 3, where the defect lies.

## Kept for a reason an earlier milestone had

- report/language.md §3.9 line 289, the spawn-only sentence (KP10): written when only `Peer.spawn` and `Peer.spawnMonitored` crossed a function; the computes were added to §3.11 and not here.
- report/language.md §3.11 line 330, "or, for a function that receives nothing, a type variable that nothing fixes" (KP1): the clause predates §6.2's rule that an unfixed mailbox type is `Never`, which was carried to spawns on a peer and computes (line 326) and not to `Code.running`.
- report/language.md §4.6 line 443, "once a spawned function's unfixed mailbox type is `Never` (§6.2)": the wording of a transition; the rule is simply that it is `Never`.
- report/library.md G.5 line 913: the stub keeps its number by rule, but its paragraph argues ("The library asked every peer its utilization at the moment of a pick ..."), rationale the log owns; E.19 line 569 shows the register a stub needs.
- docs/soundness.md line 216: "MVP 3.0 runs one program on several nodes": a milestone's name in the one document that argues from the report.
- report/toolchain.md §11.7 line 308, `ern 0.3.1` (KP21).
- report/language.md Appendix F line 1543, **unit** (KP15): written before `ern test` over a directory held units for a run.

## Counts

Each against the last count given in the brief, with how I counted.

- **Reserved words: 18** (§2.4's table, counted by word). The brief's last count was 20; v0.3.1's table also holds 18, `with` now `receiving`. No word entered or left. The words a reader must know by position grew: `compare`, `negate` and `show` joined `needs` and `derives` (§2.4 line 128) without moving the count.
- **Contextual words: 16, or 17 with `Prelude`**: `needs`, `derives`, `compare`, `negate`, `show` (§2.4), the eleven bitstring specifiers (§5.11, Appendix A `BitSpec`). Last 14 or 15: `compare`, `negate` and `show` came; the brief's 14 is one short of my method's 13 + 2 for v0.3.1, so by one method the delta is +3 and by the brief's +2.
- **Prelude types: 21** (§9.1 ten, §9.2 three, §9.3 eight). Unchanged.
- **Prelude functions: 33** (§9.4 six with `Io.show` and `Io.debug`, §9.5 seven, §9.6 twenty). Unchanged in count; `via` went and `adapted` came.
- **Primitives outside §9, functions that are no value: 5**: `Peer.spawn`, `Peer.spawnMonitored`, `Peer.compute`, `Peer.computeAt`, `Code.running` (§3.11 line 330, E.27 line 774, E.28 line 814). Last 4: +1, `Peer.computeAt`. E.22's three private primitives counted apart as before.
- **Taken namespaces: 29**: the 27 files under `src/stdlib/` (E.1 to E.28 less E.19), `Address` and `Prelude` (§4.2 line 370). Last 28: +1 net, `Erl` out, `Peer` and `Code` in.
- **Concepts: 142**: Appendix F has 162 entries (`grep -c '^- \*\*'`), 137 at v0.3.1; 34 came (`adapted`, bare node, bound type, canonical form, carrier, code frame, code table, compute, connection, cookie, detector, dial, exchange, floor, frame, gateway, handshake, hash, identity, key, loss, measure, note, offer, reach, receiving, start number, subscriber, telling, tick, unfixed, unit, utilization) and 9 went (consumed, content addressing, not-reply-carrying, obligation, pure function, reply-carrying, `via`, `with`). The 20 that cite the toolchain's or the library's sections alone (admission rule, build root, canonical form, child, container, diagnostic, grapheme, group, line mode, live region, load path, runner, sequence, shape rule, shim, span, startup file, strategy, supervisor, vocabulary) are taken out as before: 162 − 20 = 142 against 117, +25, of which §8.7 and §10 account for about 20 (KP26).
- **Inferred restrictions: 2; printed marks: 2**: equality `=` and process-only `+` (§3.9 line 295, §11.5 line 265). Last 3 and 3: not-reply-carrying and its `!` went with `via`.
- **Primitives as Appendix E's sections name them: 131 exported, 168 with the private ones and the host functions "beneath"**, counted from each section's "The primitives are" sentence, E.17's "every function" as 16 and E.12's "its functions" as 8. Last 86: the method that gave 86 is not stated and I could not reproduce it; by mine the change since v0.3.1 is +14 (E.27's eleven, E.28's three) and `Erl.atom` renamed.
- **`foreign fn`s as built: 145** (`grep -c 'foreign fn' src/stdlib/*.ern`, summed; per file: string 19, float 16, map 13, set 13, bytes 11, peer 11, char 10, foreign 10, int 8, os 6, process 5, supervisor 5, clock 4, code 3, io 3, list 3, path 3, terminal 2, fs 1, tcp 1). Last 93. The libraries add 19 (ets 9, utilization 8, json 2).
- **Listed functions: 326 in Appendix E, 28 in Appendix G** (lines `Name.fn : ` between the appendix headings). Last 305 and 20: +21 (E.27 twelve, E.28 three, and six elsewhere) and +8 (G.4 five, G.6 two, G.7 one).

### N

# Findings of N, the newcomer, for the release 0.4.0

The language I know: Erlang, and OCaml beside it. The checkout is at fb2324e8. The toolchain is `/home/jocke/projects/ernest/bin/ern`, which says `ern 0.3.1-dev`. I read README.md, then guide/language.md, doing every exercise (§1.4 to §8.8, each checked with `ern build` or `ern run` where it could be). My answers matched §13's but §8.8's second half, whose answer I could not parse (N14). Then I read guide/why.md and guide/faq.md, and the first two sections of guide/deployment.md for the two nodes. Then I wrote `pubsub`, a broker of topics. It ran on one node and on two nodes, the second a bare node.

## The README

N1. README.md:56. Quote: "0.4.0, the first release with nodes, is the plan's next tag, and where the project stands is "Where we are" in the plan". Reading the 0.4.0 release, this tells me 0.4.0 is not out yet, and `ern --version` says `0.3.1-dev`. The only place that says what works is an implementation plan under `docs/`, which a newcomer does not open. Fix: state the version the reader holds, and in two lines what works and what does not yet (macOS unverified, the `Mailbox` library of faq.md:23 unwritten), with the plan for the rest.

N2. README.md:15. Quote: "five claims that [Why Ernest] argues with a program for each". why.md:3 says "a program for each but the last", and so do language.md:34 and :92. Fix: "with a program for each but the last".

N3. README.md:25-52. The counter relies on `restarting`, on `Unlimited`, and on `Get` passed as a function before the prose says what they are. `Unlimited` is never said. Nor does the README show what the program prints. Fix: add one clause, "`restarting(Unlimited, f)` runs `f` again after every fault", and the output line, `count is 8`.

N4. README.md:84. Quote: "The manual pages, as `make man` last wrote them from `main`". This is an insider's phrase: I could not tell whether `main` is a branch or the function. Fix: "The manual pages, as Markdown".

N5. README.md:73. Quote: "the archive is compiled where it is installed". I could not tell whether the archive holds binaries, or whether it needs OTP 29 too. Fix: "the archive holds the source, which `make` compiles, with OTP 29 as above".

## Lost or misled in the guide

N6. guide/language.md:2976. Quote: "work on a peer is a process spawned there, which carries its captured values and no code (§8.1, §8.4)". Four other places say the opposite:
- language.md:2338: "a peer that lacked it would be sent the definition, with every one it reaches"
- language.md:2978: "a spawn or a compute carries to a peer the code it lacks"
- README.md:18
- why.md:12 and :96

My program's subscriber ran on a bare node that held none of my code, so line 2976 is wrong. language.md:1048, "since a function does not cross nodes in a message", made it worse until I tried it. Fix: "a function value does not travel in a message; a process spawned on a peer carries its captured values, and the peer is sent the definitions it lacks".

N7. guide/language.md:2298. Quote: "so a library any program beside it uses must be on every node's load path". My module ran on a bare node whose load path held nothing of mine. why.md:12 says "any node can run anything" and "no program is deployed first". I could not tell which code must be present on a node. Fix: say what must be there, the Erlang modules a foreign declaration calls, as 2346 says, and that Ernest definitions are sent.

N8. guide/why.md:188. Quote: "`Set` is the standard library's, in scope everywhere and with no order of its own, and `OrderedSet` is a library, so its type is written whole". The guide says "The standard library's `OrderedSet`" (language.md:2047) and shows its source as `src/stdlib/ordered_set.ern` (2211), and it needs no `--load-path`. "Written whole" did not explain to me why one type is `Set(Int)` and the other `OrderedSet.Set(Int)`: `Set.Set(Int)` is refused with `unknown type Set.Set`. Fix: "`Set` is the prelude's type; `OrderedSet` is a module of the standard library, and its type is `OrderedSet.Set`".

N9. guide/faq.md:7. Quote: "its line comment and `todo` were taken outright". Ernest has no `todo`. `ern build` says `unknown name todo`, and `:doc fault` says "Code not written yet is `fault("todo: ...")`". Fix: drop `todo`, or say that `fault("todo: ...")` stands in its place.

N10. guide/faq.md:23. Quote: "`Mailbox.drained(keep)` takes them from the old mailbox ... and the new process puts them into its own with `Mailbox.refilled(messages)` ...; the `Mailbox` library is planned and not yet written". The answer describes, in the present tense, functions that do not exist, and says so only in its last clause. I had started looking for `Mailbox`. Fix: open with "Not yet:", or drop the paragraph.

N11. guide/faq.md:79 and :43. Two cross-references are wrong:
- faq.md:79: "(report §8.3, the guide's §8.7)". The guide's §8.7 is Sockets; nodes are §8 to §8.2.
- faq.md:43: an adapted address is cited to "the guide's §4.1", which does not teach `adapted`; §5.5 does.

Fix: §8.2 and §5.5.

N12. guide/language.md:634. Quote: "A lambda's body extends as far as the text allows: to the `,`, `;`, `:`, `|`, `->`, `{`, `>>`, or closing bracket". Read as written, `fn() = { ... }` and `fn() = match x { ... }` would end at their `{`. Yet the guide writes both (2509, 1466), and both compile. I could not tell which `{` ends a body. Fix: name the case, "a `{` after the lambda's body, as in `if f(x) then ...`", or give an example.

N13. guide/language.md:781. Quote: "So does each call of the definition where a parameter's type holds `n` or `n` is the definition's own mailbox type". I read it four times and still could not say what fixes `n`. Fix: two sentences, each with its example call.

N14. guide/language.md:3032, the answer to §8.8. Quote: "written in a module `foo`'s program depends on too, or in one that, with every module it depends on, has no top-level `let` `foo`'s program has not run (§8.1)". I could not parse it, so I could not check my answer to the exercise's second question. Fix: two sentences, one saying where the spawn's module must be and one saying why.

N15. guide/language.md:2620. Quote: "A peer that fell silent is given up in 45 to 75 seconds, and one that closed at once". The sentence lacks a verb, and at first I read that a closed peer also takes 45 to 75 seconds. Fix: "and one whose connection closed is given up at once".

N16. guide/language.md:557. Quote: "`k=` needs equality (§2.5): `fn equal(a, b) = a == b` prints as `equal : (a=, a=) -> Bool`". The rule names `k=` and the example shows `a=`, so I looked for something special about `k`. Fix: "a variable marked `=`, as `a=`, needs equality".

N17. guide/language.md:2331-2332. The guide starts `ern run --config-dir foo idle.erc &` and then runs the second node at once. deployment.md:59 says a node listens only once its bindings have values, so the second command can race the first. Nothing says how to know that `foo` is up; I polled for `foo/ernest.pid`, which may come before the listener. Fix: say what to wait for, or say that the first dial is retried.

N18. guide/language.md:133, and the 15 other shell transcripts. Quote: "Ernest 0.3.1. :help for the commands". The release is 0.4.0, and my shell says `Ernest 0.3.1-dev.` This is minor. Fix: update the version, or cut it from the transcripts.

N19. `ern format` on my program, pubsub.ern:93-98. My layout,

    let watched =
        if Map.contains(state.watched, process) then
            state.watched
        else { ... };

became `let watched = if ... then`, with `state.watched` and `else {` back at the `let`'s column. Now the `else` reads as if it belonged to the block, not to the `let`. The guide never shows a `let` bound to an `if` (§2.7, §9.1). Fix: show this layout in §2.7, or have the formatter keep the `if` under the `let`, as it does for `match`.

## Messages not understood

N20. Compiler help, as at language.md:2712 and in my probes. Two quotes:
- "= help: a value of a bound type never crosses to another node; give the process what crosses (§3.11)"
- "= help: export Msg, or declare it `abstract type` so that its constructors stay private (§4.4)"

The guide uses a bare § for its own sections, so I read these as the guide's. The guide has no §3.11, and its §4.4 is `Address.call`. Fix: "(report §3.11)", "(report §4.4)".

N21. In `ern shell`, `:browse Address` answers "no module Address is in scope". Yet `Address.call` and `Address.callForever` are documented under that name, and `:doc Address` shows the type. I concluded that `call` lived somewhere else, and only `:browse Prelude` showed where it was. Fix: have `:browse Address` list the prelude's `Address.` names, or have the message say "Address is the prelude's type; `:browse Prelude` lists `Address.call`".

N22. ern run's fault line. Quote: `Pubsub.subscriberOf:247 faulted: bob was told to crash`. I read it as "subscriberOf faulted at line 247", but the fault was at line 27, in `subscriber`; 247 is where the process was spawned. On the peer it says `Pubsub.subscriberOf:245 faulted: ..., spawned by the peer a`. language.md:1619 explains this, but the line does not. Fix: "the process spawned at Pubsub.subscriberOf:247 faulted: ...", the wording the guide's own program prints (1616).

N23. A receive guard: `when p == Process.fromAddress(a)`. Quote: "a comparison in a `receive` guard compares variables, literals, and nullary constructors" and "= help: receive the message and `match` it". The help proposes a change of meaning: the message then leaves the mailbox, as language.md:824 warns. What I needed was to compute the `Process` before the `receive`. Fix: "bind the value with `let` before the `receive`, or receive the message and `match` it".

## Wanted and not found

N24. A list of the standard library's modules. language.md:539 names some, then "a few more, `Random` among them", and `:browse` with no module says `:browse takes a module`. Fix: let `:browse` alone list the modules, or have §2.9 list them all.

N25. A call to many processes at once. The broker delivers a publication by `Address.call` to one subscriber after another, so that a dead subscriber shows at once as `None`. But a slow subscriber holds the broker for up to 1000 ms per publication. Doing all the calls at once takes a gathering process per publication, the 35 lines of §4.4's `gathered`. Fix: a library function, or a recipe in §4.4.

N26. `todo`, which the FAQ promises (N9).

## Words relied on before said

N27. language.md:904-934, §4.4's "A library that waits". It uses `spawnMonitored`, `Down`, `Down(reason = Returned)` and "its Down keeps no order with that message" in thirty lines of code, before §5.2 teaches `monitor` and `Down`. Fix: move the example to §5.2, or point to it: "spawnMonitored and Down are §5.2's".

N28. language.md:552, in §2.9. Quote: "`Timeout` is `Io.Error`'s, whichever module answers it, `Peer.find` among them" and "asks again on each `Left(Timeout)` (§8.7)". This names peers and a server's loop before §4 and §8. Fix: drop `Peer.find` here.

N29. language.md:409-410, in §2.5. Quote: "`Foreign.Term` among them" and "key it by the process behind each address instead (§5.5)". Foreign types and `Process` come before either is said. Fix: cut `Foreign.Term` here.

N30. language.md:188, in §1.3. `input = <<>>` and `finished.stdout` appear before §2.1 says what bytes are and §2.4 what a field is. Fix: a clause, "`<<>>` is no bytes (§2.1)".

N31. language.md:843, in §4.4. Quote: "was restarted by its supervisor". `restarting` is §6.5's and supervisors §6.6's. Fix: add "(§6.5)".

N32. Three names come before their sections, each without a pointer:
- `Process.status` (language.md:1002)
- `Tcp.give` (language.md:1408)
- "in the order a find asks them" (language.md:2269), before §8.2's `Peer.find`

Fix: a forward pointer for each.

N33. language.md:92. Quote: "the second is principle 3's (§11)". This is a numbered principle before the guide has said there are principles. Fix: "the second is the rule that nothing is invisible (§11)".

## Counts without content

N34. README.md:21 and why.md:15. Quote: "a report of three files defines all of it". Three files say nothing of how small the language is, since a file can be any length. Fix: give a measure, words or pages, or drop the count.

N35. language.md:539. Quote: "and a few more, `Random` among them". It does not say which (N24).

N36. faq.md:103. Quote: "The rules are few". It does not say how few, and the list after it is not all of them. Fix: drop "few", or count them.

## Claims that open on another system's lack

N37. faq.md:9. Quote: "Gleam's typed messaging is a library over the runtime's processes, well made too. What differs is how far the types reach". It opens on Gleam. Fix: open "In Ernest the process is the language: ...".

N38. faq.md:31. Quote: "Unison runs a distributed program on Unison Cloud, its hosted service or, since October 2025, its software on machines of your own; in Ernest the nodes are yours". Fix: open on Ernest's nodes.

N39. faq.md:81. Quote: "There is no mesh, so ...; no port mapper, so ...; and the key is the identity". It opens on what Erlang's distribution has and Ernest leaves out. Fix: "A program's nodes talk where its configuration says, through one port each, ...".

N40. faq.md:101. Quote: "A warning is a rule the compiler states and does not hold". It opens on other compilers' warnings. Fix: open with "A program builds or it does not".

N41. why.md:134. Quote: "A reader who knows another language looks for a type class, an interface or a trait. Three things stand in their place". Fix: open "Three things serve where a program needs a type's operations".

N42. language.md:2967-2974, §10's "What differs". Five bullets open "There are no exceptions", "no links", "no registered names", "no atoms", "no OTP behaviors": each says first what Ernest lacks. Fix: lead each with what Ernest has: a fault ends the process; monitors alone; a service binding; constructors as the tags; a `receive` loop with `Reply`.

## Apart: where the language made the program harder

N43. A request with named fields is not a function. So every `Address.call` with one needs a lambda that names each field twice: `fn(reply) = Subscribe(topic = topic, name = name, subscriber = address, reply = reply)`, which the formatter lays over six lines (pubsub.ern:148-153). The patterns repeat `topic = topic` again. I made `Inbox(Reply(...))` and `Stats(Reply(...))` positional only so that `Address.call(x, Stats, 1000)` reads short: the call picked my messages' shape.

N44. `receiving MainMsg` spreads up the chain of calls. `subscriberOf` starts a monitored process, so it, `perform` (the command interpreter) and `run` must all declare `main`'s mailbox (pubsub.ern:132, 143, 238). Any function that may start a monitored helper is tied to one process's message type. In Erlang only the receiver knows.

N45. Addresses have no equality, so the broker keeps two maps that must agree: topic, then name, to address, to deliver; and `Process` to name, to act on a `Down` (pubsub.ern:44-46, 77-84, 88-108). In Erlang one map keyed by pid would do.

N46. A `receive` guard calls nothing, so `when ended == Process.fromAddress(address)` is refused, and `awaitEnd` takes a `Process` instead of the address (pubsub.ern:251-255). This is minor.

N47. `if` has no form without `else`, so a precondition is `if String.isEmpty(topic) then fault("...") else Unit;` (pubsub.ern:66). This is minor.

## Apart again: names I could not predict

N48. `adapted(address, f)`: I expected `Address.map`. The word is a participle, and it lives in the prelude, not under `Address.`, where `call` lives.

N49. `OrderedSet.Set(a)`: I expected `OrderedSet(a)`, as the prelude has `Set(a)` and `Map(k, v)` and the guide's own module has `Stack.Stack`.

N50. `answer(reply, v)`: I expected `reply(r, v)`, as Erlang's `gen_server:reply/2`, since the type is `Reply`.

N51. `spawnMonitored(f, wrap)`: I expected `spawnMonitor`, as Erlang's `spawn_monitor/1`.

N52. `fault(cause)`: I expected `panic` or `error`, as Gleam's `panic` and Erlang's `error/1`.

N53. `Process.current()`: I expected `Process.self()`, beside the prelude's `self()`. There are two words for "this process".

N54. `Down(reason = Returned)`: I expected `Normal`, as Erlang's `normal`. And `Unknown`, for a process already dead: I expected `NoProcess`, as Erlang's `noproc`.

N55. `Os.termination(wrap)`: I expected `Os.onTermination`. It is a noun that subscribes.

N56. `Peer.offer` and `Peer.find`: I expected `Peer.register` and `Peer.lookup`, as Erlang's `global:register_name` and `whereis_name`.

N57. `List.maximumBy(list, key)`: it takes a key. From Haskell's `maximumBy` I expected a comparator, and for a key `maximumOn`.

N58. `Process.live()`: I expected `Process.list()`.

## The program: pubsub

A broker of topics, driven by a script on standard input. Each subscriber is a process. The broker is a service binding under `restarting`, and it monitors each subscriber's process. A publication reaches every subscriber of its topic by a call, so a subscriber that has ended answers `None` at once and is forgotten. The script's `main` also monitors the subscribers it starts, and waits for one's `Down` after telling it to crash. A name `name@peer` starts the subscriber on that peer with `Peer.spawnMonitored`.

It uses processes, four typed mailboxes, replies and `Address.call`, `monitor`, `spawnMonitored`, `Peer.spawnMonitored` and `restarting`. From the standard library it uses `Map`, `List`, `String`, `Optional`, `Io`, `Process` and `Peer`.

It has 257 lines, as `ern format` laid it out; I adopted its layout, and `ern format --check` passes.

**Did it compile?** The program compiled at its first `ern build`, before the peer form was added and after. Nothing in it was refused.

**What the compiler said to my probes.** I wrote other small programs to try what a newcomer writes wrong. Each message below I understood at once and could act on, except the three noted:
- `receive` needs a mailbox, and wait receives nothing
- `server is exported and its type names Msg, which this module keeps private`, whose `(§4.4)` I did not understand (N20)
- `Address(Never) does not support equality ... compare the processes behind addresses`
- `if` needs an `else`
- `expected Int, found Optional(Int)`
- `unknown name todo` (N9)
- `the pattern does not fit the value: expected Msg, found String`
- `worker needs mailbox A, and the mailbox here is B`
- `this statement's value is discarded: expected Unit, found List(Unit)`
- `missing field age`
- `spawnMonitored needs a mailbox, and start receives nothing`
- the receive guard (N23)
- `match on Color is not exhaustive; missing Blue`
- `add takes 2 arguments, not 1`
- `push cannot be a member of Stack: a member is an operator, compare or negate`
- `unknown type Set.Set` (N8)

**Did it run?** Yes, on one node and on two.

### Source, pubsub.ern

```ernest
/// A broker of topics, driven by a script on standard input.
///
/// Each subscriber is a process. The broker delivers a publication to every
/// subscriber of its topic by a call, and forgets a subscriber whose process
/// has ended, by a monitor. The broker runs under `restarting`.

//
// The subscriber
//

type SubscriberMsg =
    Delivered(topic : String, text : String, reply : Reply(Unit))
  | Inbox(Reply(List(String)))
  | Crash

fn subscriber(name : String, received : List(String)) : Unit receiving SubscriberMsg =
    receive {
        Delivered(topic = topic, text = text, reply = reply) -> {
            answer(reply, Unit);
            subscriber(name, received <> [topic <> ": " <> text])
        }
      | Inbox(reply) -> {
            answer(reply, received);
            subscriber(name, received)
        }
      | Crash ->
            fault(name <> " was told to crash")
    }

//
// The broker
//

type BrokerMsg =
    Subscribe(topic : String,
              name : String,
              subscriber : Address(SubscriberMsg),
              reply : Reply(Int))
  | Unsubscribe(topic : String, name : String, reply : Reply(Bool))
  | Publish(topic : String, text : String, reply : Reply(Int))
  | Stats(Reply(List(#(String, List(String)))))
  | SubscriberEnded(Down)

type Broker =
    Broker(topics : Map(String, Map(String, Address(SubscriberMsg))),
           watched : Map(Process, String))

let broker : Address(BrokerMsg) =
    spawn(restarting(RestartLimit(restarts = 3, within = 10000),
                     fn() = brokering(Broker(topics = Map.empty, watched = Map.empty))))

fn brokering(state : Broker) : Unit receiving BrokerMsg =
    receive {
        Subscribe(topic = topic, name = name, subscriber = address, reply = reply) -> {
            let next = subscribe(state, topic, name, address);
            answer(reply, Map.size(members(next, topic)));
            brokering(next)
        }
      | Unsubscribe(topic = topic, name = name, reply = reply) -> {
            let subscribers = members(state, topic);
            answer(reply, Map.contains(subscribers, name));
            brokering(Broker(..state,
                             topics = Map.put(state.topics, topic, Map.remove(subscribers, name))))
        }
      | Publish(topic = topic, text = text, reply = reply) -> {
            if String.isEmpty(topic) then fault("a publication needs a topic") else Unit;
            let #(reached, missed) =
                Map.toList(members(state, topic))
                    |> List.partition(fn(#(_, address)) = deliver(address, topic, text));
            answer(reply, List.size(reached));
            brokering(List.foldLeft(missed, state, fn(acc, #(name, _)) = forget(acc, name)))
        }
      | Stats(reply) -> {
            answer(reply, stats(state));
            brokering(state)
        }
      | SubscriberEnded(Down(process = process)) ->
            match Map.get(state.watched, process) {
                Some(name) ->
                    brokering(forget(Broker(..state, watched = Map.remove(state.watched, process)),
                                     name))
              | None ->
                    brokering(state)
            }
    }

// The broker watches each subscriber's process once, whatever topics it takes.
fn subscribe(state : Broker,
             topic : String,
             name : String,
             address : Address(SubscriberMsg)) : Broker receiving BrokerMsg = {
    let process = Process.fromAddress(address);
    let watched = if Map.contains(state.watched, process) then
        state.watched
    else {
        monitor(process, SubscriberEnded);
        Map.put(state.watched, process, name)
    };
    Broker(topics = Map.put(state.topics, topic, Map.put(members(state, topic), name, address)),
           watched = watched)
}

fn members(state : Broker, topic : String) : Map(String, Address(SubscriberMsg)) =
    Optional.withDefault(Map.get(state.topics, topic), Map.empty)

fn forget(state : Broker, name : String) : Broker =
    Broker(..state,
           topics = Map.map(state.topics, fn(_, subscribers) = Map.remove(subscribers, name)))

// A delivery is a call, so a subscriber that has ended answers None at once.
fn deliver(address : Address(SubscriberMsg), topic : String, text : String) : Bool =
    Optional.isSome(Address.call(address,
                                 fn(reply) = Delivered(topic = topic, text = text, reply = reply),
                                 1000))

fn stats(state : Broker) : List(#(String, List(String))) =
    Map.toList(state.topics)
        |> List.filter(fn(#(_, subscribers)) = !Map.isEmpty(subscribers))
        |> List.map(fn(#(topic, subscribers)) =
                        #(topic, List.sort(Map.keys(subscribers), String.compare)))
        |> List.sort(fn(#(left, _), #(right, _)) = String.compare(left, right))

//
// The script
//

type MainMsg = SubscriberGone(Down)

export fn main() : Unit receiving MainMsg =
    run(Map.empty)

fn run(subscribers : Map(String, Address(SubscriberMsg))) : Unit receiving MainMsg =
    match Io.readLine() {
        None ->
            Io.println("end of script")
      | Some(line) -> {
            Io.println("> " <> line);
            run(perform(subscribers, String.words(line)))
        }
    }

fn perform(subscribers : Map(String, Address(SubscriberMsg)),
           words : List(String)) : Map(String, Address(SubscriberMsg)) receiving MainMsg =
    match words {
        ["sub", name, topic] ->
            match subscriberOf(subscribers, name) {
                Right(address) -> {
                    let request =
                        fn(reply) =
                            Subscribe(topic = topic,
                                      name = name,
                                      subscriber = address,
                                      reply = reply);
                    match Address.call(broker, request, 1000) {
                        Some(count) ->
                            say(name <> " takes " <> topic <> ", which has " <> Int.toString(count))
                      | None ->
                            say("the broker did not answer")
                    };
                    Map.put(subscribers, name, address)
                }
              | Left(error) -> {
                    say("cannot start " <> name <> ": " <> Io.show(error));
                    subscribers
                }
            }
      | ["unsub", name, topic] -> {
            match Address.call(broker,
                               fn(reply) = Unsubscribe(topic = topic, name = name, reply = reply),
                               1000) {
                Some(true) -> say(name <> " leaves " <> topic)
              | Some(false) -> say(name <> " did not take " <> topic)
              | None -> say("the broker did not answer")
            };
            subscribers
        }
      | "pub" :: rest -> {
            let #(topic, text) = match rest {
                [] -> #("", "")
              | topic :: more -> #(topic, String.join(more, " "))
            };
            match Address.call(broker,
                               fn(reply) = Publish(topic = topic, text = text, reply = reply),
                               1000) {
                Some(count) -> say(topic <> " reached " <> Int.toString(count))
              | None -> say("the broker did not answer")
            };
            subscribers
        }
      | ["inbox", name] -> {
            match Map.get(subscribers, name) {
                Some(address) ->
                    match Address.call(address, Inbox, 1000) {
                        Some(lines) -> List.forEach(lines, fn(line) = say(name <> " got " <> line))
                      | None -> say(name <> " did not answer")
                    }
              | None ->
                    say("no subscriber " <> name)
            };
            subscribers
        }
      | ["crash", name] ->
            match Map.get(subscribers, name) {
                Some(address) -> {
                    send(address, Crash);
                    awaitEnd(Process.fromAddress(address));
                    say(name <> " has ended");
                    Map.remove(subscribers, name)
                }
              | None -> {
                    say("no subscriber " <> name);
                    subscribers
                }
            }
      | ["stats"] -> {
            match Address.call(broker, Stats, 1000) {
                Some([]) ->
                    say("no topic has a subscriber")
              | Some(topics) ->
                    List.forEach(topics,
                                 fn(#(topic, names)) =
                                     say(topic <> ": " <> String.join(names, ", ")))
              | None ->
                    say("the broker did not answer")
            };
            subscribers
        }
      | [] ->
            subscribers
      | _ -> {
            say("not a command: " <> String.join(words, " "));
            subscribers
        }
    }

// A subscriber named `name@peer` runs on that peer, any other on this node.
fn subscriberOf(subscribers : Map(String, Address(SubscriberMsg)),
                name : String) : Either(Io.Error, Address(SubscriberMsg)) receiving MainMsg =
    match Map.get(subscribers, name) {
        Some(address) ->
            Right(address)
      | None ->
            match String.split(name, "@") {
                [_, peer] ->
                    Peer.spawnMonitored(peer, fn() = subscriber(name, []), SubscriberGone, 5000)
              | _ ->
                    Right(spawnMonitored(fn() = subscriber(name, []), SubscriberGone))
            }
    }

fn awaitEnd(process : Process) : Unit receiving MainMsg =
    receive {
        SubscriberGone(Down(process = ended)) when ended == process -> Unit
    }

fn say(text : String) : Unit =
    Io.println("  " <> text)
```

### Run on one node

The script, script.txt:

```
sub alice news
sub bob news
sub bob sports
sub carol sports
stats
pub news rain tomorrow
pub sports three to one
inbox bob
crash bob
pub sports two all
stats
unsub alice news
unsub alice news
pub news snow
inbox alice
inbox carol
pub
stats
sub alice news
stats
dance
```

The command was `ern build pubsub.ern && ern run pubsub.erc < script.txt > run1.out 2>&1`. Standard error is in the same file, and its two fault lines come early, where the guide says they may (language.md:13):

```
> sub alice news
  alice takes news, which has 1
> sub bob news
  bob takes news, which has 2
> sub bob sports
  bob takes sports, which has 1
> sub carol sports
  carol takes sports, which has 2
> stats
  news: alice, bob
  sports: bob, carol
> pub news rain tomorrow
  news reached 2
> pub sports three to one
  sports reached 2
> inbox bob
  bob got news: rain tomorrow
  bob got sports: three to one
> crash bob
2026-10-18T08:20:34.627Z Pubsub.subscriberOf:247 faulted: bob was told to crash
2026-10-18T08:20:34.633Z Pubsub.broker:49 faulted, restarted: a publication needs a topic
  bob has ended
> pub sports two all
  sports reached 1
> stats
  news: alice
  sports: carol
> unsub alice news
  alice leaves news
> unsub alice news
  alice did not take news
> pub news snow
  news reached 0
> inbox alice
  alice got news: rain tomorrow
> inbox carol
  carol got sports: three to one
  carol got sports: two all
> pub
  the broker did not answer
> stats
  no topic has a subscriber
> sub alice news
  alice takes news, which has 1
> stats
  news: alice
> dance
  not a command: dance
end of script
status 0
```

### Run on two nodes

`foo` is a bare node, `ern run --config-dir nodes/foo` with no program, listening on 127.0.0.1:18655. `a` runs the program with `ern run --config-dir nodes/a pubsub.erc < script2.txt`, listening on 127.0.0.1:18654. Each `ernest.conf` lists the other by the key `ern config` printed, and `foo` lists no address for `a`. I stopped `foo` afterwards with `ern stop --config-dir nodes/foo`, which exited with status 0.

The script, script2.txt:

```
sub alice news
sub dave@foo news
sub dave@foo sports
sub erin@nowhere news
stats
pub news rain tomorrow
pub sports three to one
inbox dave@foo
crash dave@foo
pub news sun
stats
```

On node `a`, standard output and standard error together:

```
> sub alice news
  alice takes news, which has 1
> sub dave@foo news
2026-10-18T08:20:49.293Z the peer foo connected
  dave@foo takes news, which has 2
> sub dave@foo sports
  dave@foo takes sports, which has 1
> sub erin@nowhere news
  cannot start erin@nowhere: NotListed
> stats
  news: alice, dave@foo
  sports: dave@foo
> pub news rain tomorrow
  news reached 2
> pub sports three to one
  sports reached 1
> inbox dave@foo
  dave@foo got news: rain tomorrow
  dave@foo got sports: three to one
> crash dave@foo
  dave@foo has ended
> pub news sun
  news reached 1
> stats
  news: alice
end of script
status 0
```

On `foo`, standard error:

```
2026-10-18T08:20:49.292Z the peer a connected
2026-10-18T08:20:49.819Z Pubsub.subscriberOf:245 faulted: dave@foo was told to crash, spawned by the peer a
2026-10-18T08:20:49.837Z the peer a ended
```

The subscriber `dave@foo` ran on a node that held none of the program's code, which is the evidence for N6 and N7. Its fault was reported on `foo` alone, where language.md:2490 says it would be.

The files are under `/tmp/claude-1001/-home-jocke-projects-ernest/25a617e1-f7ac-4613-92f8-97e89ee6bf4a/scratchpad/release/N/`: `pubsub/` holds the program, its scripts, its outputs and the two node directories; `ex/` holds the exercises and `probe/` the probes.

### U

# Findings U, the guide, for the release 0.4.0 (commit fb2324e8)

## Defects
U1. language.md:2976 (§10) "A function does not travel to another node: ... carries its captured values and no code" — false since the exchange; :2978 says the opposite. Fix: a spawn or compute names its function by hash and carries the code the peer lacks.
U2. language.md:2969 (§10) "A function says in its type whether it may send or receive" — stale (`with` era). Fix: whether it receives; one that only sends says nothing.
U3. language.md:2346 (§8.1) "runs on the peer only where the peer holds it, by its hash ... otherwise Left(NotLoaded)" — the peer is sent it; NotLoaded only for a binding without value or a missing host module. Contradicts :2338.
U4. language.md:3032 (§13, answer to §8.8) module-level rule from before the exchange; §8.7 decides by reach; leaves out compute. Fix: in any module; the spawn carries what foo lacks and runs since Registry.registry has its value on foo.
U5. language.md:2975 (§10) "Only the shell's :reload loads a new version" — Code.load and a peer's spawn/compute do too.
U6. deployment.md:378 (§8) the shell "connected to both ... the peer b ended then the peer c ended" — the shell only computes on b, never dials c; test asserts only b. Fix: connected to b alone; no node hears c's end.
U7. deployment.md:151 (§2.3) lost "until a find, a spawn, a compute or an ask" — a send opens the connection too (§8.7 Messages); :63 leaves out "or it dials in". language.md:2622 "a later send vanishes until the two connect again" — it dials again, vanishes only where the dial fails.
U8. deployment.md:236 (§5.3) "How a service is written to take it is the language guide's chapter 8" — chapter 8 teaches no upgrade; nothing teaches Code.running/load/hashes (E.28) or §6.10's rule (type carrying Upgrade is bound; adapted address; upgraded on its own node); §4.6 :1048 promises and shows nothing. Fix: teach E.28 and §6.10's pattern (examples/upgrade moved/moving); point the deployment guide there.
U9. language.md:2296–2336 (§8.1) `idle.erc` never shown; the bare node is the report's form; language guide never names it; one job two ways. Fix: start foo bare, say the compute carries heavy, drop idle.erc.
U10. deployment.md:71 (§1.3) "the end waits for 1 subscriber ... where one is slow" — written whenever the end has subscribers. Fix: drop "where one is slow".
U11. language.md:2905 (§9.1) recompiled only when source/interface/stdlib interface/compiler changed — a dependency's body change whose hash the code references recompiles too (§11.1). Shown: lib.ern n+1 → n+2 rewrote user.erc.
U12. language.md:665, :683 (§3.3) call-initialized let "has the type the call gives"/"must have their types settled" — §4.6 now generalizes a call's result whose type holds no function, foreign type, address or reply. Shown: let xs = List.reverse([]) used at Int and String.
U13. deployment.md:131, :298 "dialed node answers under another name ... as a copied directory does" — a copy has one key hence one name (shows as `replaced`); a dial answered under another name fails silently; the line is only on the accepting side. Fix: mismatched key and address as cause; dialer writes nothing; copies → replaced row.
U14. language.md:2271, :2978 floor "one release of ern on one major OTP" — one major and minor release, patches share it; dev build its own digest. Fix: "one minor release of ern, any patch".
U15. language.md:843 (§4.4), :1552 (§6.2) callForever causes leave out the node out of reach, `callee is unreachable` (§6.6, §7.4).
U16. language.md:2342 "reports the fault once, with the stack that crossed with it" — an arithmetic fault prints no stack; only a runtime failure or foreign raise does. §11.2's sentence reads unconditional too.
U17. faq.md:79 "the guide's §8.7" is Sockets. Fix: §8.1.
U18. deployment.md:257–271 (§6) shell session omits the types the shell prints and the :load answer; Counter.config belongs to another Counter than examples/upgrade's. Fix: print as the shell does; name the program.
U19. why.md:86–94 reload session: diagnostic shown without source/label/caret lines; `input 4` holds only if started over the file (after :load it is input 5). Fix: show them or mark abridged.

## Facts outside their owner
U20. faq.md:23 Mailbox.drained/refilled — an API from a proposal, no report section; planned is the plan's. Fix: drop or point at the plan.
U21. deployment.md:281 "Attaching is planned and not yet built" — development.md's table owns what is not built (no row); the plan owns planned. Fix: keep "a shell does not attach; the wrapped compute is the way in"; record the gap with its owner.
U22. faq.md:73 "checked by a process the runtime puts in front of the address" — the mechanism is architecture.md's; §8.4 says "checked on delivery".

## Clarity
U23. language.md:2338 "holds heavy by its hash" — hash never explained in the language guide; "a find" at :2269 before §8.2. Fix: one sentence at first use citing §8.7.
U24. language.md:2384–2421 "It is §4.4's gathered with a compute as each helper's work", then gathered written again — one job two ways; Gather.gathered([3,1,2], Placed.computed) works. Fix: call the library.
U25. language.md:2338 cites "the deployment guide's §3.4"; the exchange as the operator meets it is §4.1.
U26. language.md:1360 "A send to an adapted address applies the function in the sender" — only on the node that made it; elsewhere on arrival with §8.2's order exception (§6.5). Fix: qualify.
U27. language.md:2344 forms a peer may run leave out `restarting` over one (§3.11).
U28. language.md:2984–2992 (§11) summary of §0 lags: principle 5's "a type carries nothing of what a function does", principle 3's "visible where it happens", Time. Fix: add or point to report §0.
U29. language.md:148 "n counting the inputs entered" — commands counted too (§11.2).
U30. language.md:2933 :reload "each loaded module whose source has changed" — also dependents and the session's declarations; a failing one leaves scope (§11.2).
U31. language.md:2937 "kill(c), c a binding that holds the old one's address" — store.ern's counter is private; no "write and end" request. Fix: say what the store exports, or drop.
U32. language.md:2650 (§8.2) store/desk as nodes from this directory need Proxy on the load path (a node reads every module of its load path). Fix: give both command lines.
U33. language.md:2330–2336, deployment §5.3 and §8 consoles omit the other node's lines on the same terminal (the peer a connected/ended). Fix: show them or say whose lines a console shows.
U34. deployment.md:255, :328 "since a shell only dials" — a shell with listen listens (§11.2). Fix: "since this shell need only dial".

## Outside the brief
U35. A stray module compiled under another root (client2.erc holding Client2 at Reg.Client2's path) makes a node refuse with "cannot find module Client2 (client2.erc) on the load path" — the file exists; the fault is §11.2's "a file at a module's path that holds another module" and the message says neither. Fix: name the file and the module it holds.

Tools: first ern build 3.4 s, ern config 4.4 s cold; warm 0.3–0.6 s; node start ~1.4 s. No slow-tool defect.

### C

# Findings C, the code (C, E and S as one), for the release 0.4.0 (commit fb2324e8)

## S, security
S1 (real exposure). On a dial, a server certificate is bound to no particular peer, so a listed peer can answer under another listed peer's name. erl/cli/src/ern_carrier.erl:324-336 (verify/3), :341-346 (listed/1), client options :68-72. §8.7 Connections: "A node it dials must answer under the name it dialed". verify/3 passes when listed/1 finds ANY listed peer for the cert's key and names_own_host/1 holds; neither ties the cert to the host dialed. The comment at :316 claims the host's handshake checks the dialed name, but dist_util checks only the node name the responder declares, which an impostor sets. Reproduced: dirs b, c, x; x lists b and c; a bare erl with c's certificate and key, named ernest@<host-of-b>, listening at b's port with x's floor cookie and a stand-in ern_gateway; `Peer.utilization("b", 5000)` from x printed `the peer b connected` and `Right(0.123)` from the holder of c's key. The accept side is safe (allowed_nodes from the verified cert host). Fix: on the dial, bind the cert to the dialed host (thread the dialed host into the client verify_fun state, or server_name_indication/customize_hostname_check) and refuse a cert whose names_own_host is not the host dialed. Test gap: test/ern_nodes_tests.erl:605 answered_test_ covers only a peer answering under its own name; nothing dials and is answered by a different listed key named as the dialed peer.
S2 (hardening). The asked node's exchange entry has no timeout: ern_exchange.erl:301-316 (reached sends lacks, calls kept), cleared only at a loss (dropped/2 :408-417). A peer that requests a reach, gets the lacks and never sends the code frames leaves the #exchange{} and its waiting spawn frames until the connection drops; the spawner gives up at its own ms. Fix: a deadline recorded at ask/3, dropped when it passes.
S3 (hardening). ern_gateway's Ended map entry is never cleared without a nodedown: :149-150 adds Node => true, removed only on nodedown :186-190. A peer that sends node_ends and stays connected leaves an entry. Fix: drop it on the next frame from the node, or ignore node_ends from a node whose connection does not then close.

## C, the toolchain's code
C1. A received code frame's References field is validated only as a hash list (ern_exchange.erl:236-248, :239), then :247 `References = referenced(Forms)` matches the recomputed value against the received one (a mismatch is `unreadable`): a redundant cross-check, not a used value, while the comment :68-70 describes it as frame data; faulty_frame_test covers only the mismatch. Fix: say in the comment it is a redundant check the arrival recomputes, or drop the field.
C2. ern_carrier:cookie/2 (:117-124) `[Major, Minor, _Patch] = string:split(Release, ".", all)` badmatches on a version not of three dot-parts; the `[_, "dev"]` clause assumes one `-`. A stray VERSION aborts the node opaquely. Fix: match the shape and fail plainly, or comment that VERSION's shape is a build invariant.
C3. ern_carrier.erl:133-135 "36 milliseconds for the 91 modules of the tree at 0.3.1": stale measured number. Fix: drop the count or re-measure as illustrative.
C4. Two functions name one concept (a qualified name as a line writes it): ern_peer.erl:708-709 identity_text (ern_namespace:text) and :641-642 named_text (lists:join). They can differ for a segment that needs escaping. Fold to one.
C5. scheme_arity/1 (§4.9 arity sum) defined three times: ern_peer.erl:638-639, ern_arrival.erl:377-378, ern_exchange.erl:768-769 (in is_scheme). One shared helper.
C6. texts/1 + text/1 (a peer's qualified name as text) copied verbatim: ern_exchange.erl:752-757, ern_arrival.erl:251-256, plus a test copy. One helper.
C7. Three whereis(ern_gateway) call sites: ern_rt.erl:3220-3225 gateway/0, ern_exchange.erl:141-145 told/2, and the notes path. A shared accessor.

## E, the Ernest code
E1. Code.load's doc (src/stdlib/code.ern:74-80) omits two Left(Invalid) causes E.28 gives: a module of a cycle through the load path (§4.1), and a directory or a file at a module's path that holds another module. Fix: add both; confirm ern_code_load returns Invalid for both.
E2. peer.ern:171-172 spawn doc breaks a sentence mid-line ("A binding\n`f` does not reach"). Reflow.
E3. peer.ern:202-203 compute doc, same cosmetic break before "`computeAt`'s, and meets what it meets".
E4. The Service type doc (peer.ern:73-76, 87) invites building one by hand; a reader cannot tell the hash is filled only by service(...). Fix: state that a Service is made only by `service`.
No E.0 rule-1 violation: every foreign fn in both modules reaches the gateway, the node's records, a host file or the host's stacks.

## Kept for an earlier milestone's reason
- ern_carrier.erl:316's comment "the host's handshake checks" is a kept assumption; the cert-to-dialed-host binding (S1) was never added.
- C3's 91-module figure from 0.3.1.
- No dead table or copy beyond C4–C6; the only state with no reclaiming path short of a loss is S3's Ended entry and S2's exchange entry.

