# The release review's findings, before 0.5.0

The lists of the nine readers run on 2026-10-24 over `0e37caeb`, P on the most advanced model and the rest on the one below, over what changed since the full review's commit `1329d1d2`, and since `v0.4.0` for the guide and its skeptics; and the machines' lines. A line per finding, by area, naming its reader's letter and number, with its decision: `fix`, `decide` with a recommendation, a milestone's number, or `dropped` with the reason; `done` with the date once made. The same finding by several readers is one line naming each. Each reader's whole list stands below the lines, as [`full_review.md`](full_review.md) says.

## The report

- P1, K1, U22 — E.18's `Process.live` sentence spliced by a pasted sentence that also contradicts the section's later paragraph. fix: restore the sentence, merge the pasted rule into the later paragraph. done 2026-10-25.
- P2, K2 — §5.6 "A qualified operator is a function value, `Int.+`", against §4.5 and Appendix A. fix: delete. done 2026-10-25.
- P3, K8, C1-C6 — §4.9 quotes a message with a report citation the parser does not write. fix. done 2026-10-25.
- P5, K11, E4b — §3.10 and §9.6 say E.2, E.10 and E.11 provide `List.compare`, `Optional.compare` and `Either.compare`, and none says so. fix: E.8's sentence in each. done 2026-10-25.
- P6 — §4.5 accepts `: Unit receiving m` over `kill(self())` and drops the `receiving m` from the type. decided with the user 2026-10-25, to build in this round, superseding *A Wrap's `self`*'s clause: refuse `receiving m` wherever §3.9 makes `m` none, with the help "write f's type without `receiving`", and strike the clause; principle 2, one spelling, and 3, a type that keeps what was written. done 2026-10-25.
- P7 — `Restarted` in `Reason` costs every exhaustive match on a `Reason` an arm in a program that never calls `monitorService`. dropped, decided with the user 2026-10-25: `Restarted` stays in `Reason`, as `Unreachable` was kept, since a service monitor is a monitor and one wrap serves both, and a second wrap type is the second form principle 5 refuses more than the arm; the arm is written where `Reason` is matched whole, which few programs do.
- P8 — the carried cause, `division by zero, the fault of the callee Ledger.start:6`, chains along calls and reaches the cause a program matches on, so `Test.faults(ask, "division by zero")` fails and a test writes a line number. decided with the user 2026-10-25, to build in this round: the caller's cause is the callee's cause, and the site goes where `, spawned by the peer desk` goes, in the report's line and the trace, for a call and for a compute alike; principle 1. U9 and U14 follow the verdict. done 2026-10-25.
- P9 — §4.6's none for an effect variable in a parameter's type of a top-level `let`, so `let h = makeApplier()` and `fn h2() = makeApplier()` differ in type. fix: the rule is kept, since a top-level `let` is a value whose type must close and none is the closing that refuses nothing a value can do, and §4.6 shows this example as the rule's own; decided in the review's session. done 2026-10-25.
- K6, K32 — §4.6 is silent where one variable is both a function's effect and a type argument, where the toolchain writes `Never` throughout, and the argument's 6.1 says none wherever it stands. fix: §4.6 adds the sentence, 6.1 the `Never` case and its line. done 2026-10-25.
- P10 — §6.9's "A `wrap` that does not finish holds up no other delivery" beside the service monitor's wrap holding up the restart. fix: name the exception there. done 2026-10-25.
- P4, K10, E1, with P11, K14, E15 — `Clock.toString` past the year 9999 faults with the host's term, against E.15's "written as the host writes it" and shape rule 4; E.0 rule 2 keeps dates out of the standard library and E.15 admits the function without naming the rule; shape rule 3 names a second policy by the policy. decided with the user 2026-10-25, to build in this round: keep `Clock.toString` in E.15 as the one text form of a time the runtime's own lines write, E.0 rule 2 stating that admission; a time past the year 9999 faults with a cause of Ernest's own, `the time is past the year 9999`, stated in E.15 and on the page's Errors section, since the runtime's lines never write one and an `Optional` on every call would cost each caller a match; the name stays, the subject being a time and `Clock` the module of times. done 2026-10-25.
- P12, K27 — "constant" and "ground term" name one concept, in Appendix F twice, §11.1 and §8.7. fix: "constant" alone; `docs/style.md`'s glossary follows. done 2026-10-25.
- P13 — §11.2's doc examples take "the longest run of leading paragraphs that parses as declarations", a trial parse. fix: a first-token rule, a paragraph that begins `type`, `abstract`, `foreign`, `export`, `let` or `fn` and a name is a declaration and the rest is the body, in §11.2 and `ern_examples`; principle 4; decided in the review's session. done 2026-10-25.
- P14, K9 — §4.2's clash rule for a member and an exported value of one name has lost its stated reason, and §11.1's "depends too on the module whose namespace its own stands under" is no §4.1 dependency, since `main.ern` beside `main/stack.ern` builds. fix for K9: §11.1 says the build reads the parent's exported types and that is no dependency of §4.1's. fix for P14: the clash rule is kept, since `ern doc`'s and `:doc`'s heading `Main.Stack.compare` would name two things, and §4.2 states that reason; decided in the review's session. done 2026-10-25.
- P15 — Appendix H's "the host's order of their names". fix: "the order of their names' code points". done 2026-10-25.
- P16, K12 — §0's principle 5 says every prelude function is a value or a counted primitive, where §9.6 lists members no expression names. fix for §9.6: its paragraph says a member it lists is named in a declaration and a requirement alone and is no value. decided with the user 2026-10-25, to make in this round, for §0: the sentence names a member, reached through its operator or `compare`, as the third kind; a sentence of §0. done 2026-10-25.
- K3, C1-C1 — §6.3's guards order "the types whose `compare` §9.6 provides", now lists and optionals too, where the checker orders the four. fix: §6.3 names `Int`, `Float`, `String` and `Char`. done 2026-10-25.
- K4 — §0's introduction and §6.1 ¶1 say a function that asks for a delivery names its mailbox, against §3.9's `fn f() = kill(self())`. fix: §6.1 states §3.9's condition and §0's sentence follows. done 2026-10-25.
- K5 — two identical definitions in two modules: §6.9 and Appendix H say the site is the module compiled first, the toolchain names the module the call reached. decided with the user 2026-10-25, corrected the same day after the probes were run: the report follows the code's one rule, a reference to either of two definitions that are one reaches the one the node loaded first, within a module the first declared, and a spawn's site and a trace name that definition; "compiled first" goes, and no code changes, since a reader predicts the name written at the spawn; across nodes the arrival names the definition as the sender's build does (§8.7), which is that declaration; "compiled first" goes.
- K7 — §3.5 "In a body with a requirement, `a.member` names a member". fix: refused where `a` is a type variable of the signature (§4.5). done 2026-10-25.
- K13 — E.0 shape rule 8's one wait without a limit against `Test.faults`. fix: name the second exception. done 2026-10-25.
- K15, U23, C1-C8 — §11.6's example of two tokens kept apart, `a.-` before `>>`, can no longer occur, and the formatter's check never fires. fix: the example goes, and the check with its call and `apart_test`'s case. done 2026-10-25.
- K16 — §6.8 says a pattern `receive` in a body receiving `Never` is a type error, where the toolchain refuses an annotated `receiving Never` alone and `spawn(fn() = receive { x -> Unit })` compiles. fix: the code follows the report, the checker refusing the pattern `receive` where the definition's end fixes its mailbox `Never` by §6.2, with the help that names the wait that can never end; principle 3; decided in the review's session. done 2026-10-25.
- K17 — `Code.running(apply)`'s help cites §3.11 for E.28's rule. fix: the help cites nothing, as §11.5 says. done 2026-10-25.
- K18 — §8.4, §8.7 and §3.11 cite each other for facts neither states. fix: each fact in one section. done 2026-10-25.
- K19 — §4.2's "or member" at the plain-form rule, and the prelude-name rule against `compare`'s exception. fix. done 2026-10-25.
- K20 — E.21's `Process.current` narrower than §6.5. fix. done 2026-10-25.
- K21 — E.22's `faulted, restarted` for the fault at which the group gives up, against E.21's `restarted`. fix: E.22 says the child's own `restarting` restarts it and the group then ends it, so `restarted` is true, as decided before 0.5.0 (B9). done 2026-10-25.
- K22 — §8.6's deadlock lines "in the sites' order" names no order, and the lines share the trace's indent. fix: by declaration then line, numerically, the code following, and the lines' form stated. done 2026-10-25.
- K23 — §6.6's text for a callee with no site. fix. done 2026-10-25.
- K24 — Appendix H's `{member, Supply}` unexplained. with C1-C9.
- K25 — §6.6 "refuse its caller". fix: drop the word. done 2026-10-25.
- K26 — §3.9 "A function whose body holds a `receive`" reads as including a nested lambda's. fix. done 2026-10-25.
- K28 — §5.6's "annotate ops" and §3.5's `Date` message with no antecedent. fix. done 2026-10-25.
- K29 — Appendix F's load path order against §11.2's. fix: align with the code. done 2026-10-25.
- K30 — §11.1 leaves out the compute. fix. done 2026-10-25.
- K31 — §3.10's clause on a function given as an order. fix. done 2026-10-25.
- C1-C2 — Appendix H states where an effect variable is written none for a `let`'s and a `<-`'s type alone, where the code writes it for a lambda's type, a call's answer type and an operation's too. fix: Appendix H states it for every type the checker gives a node. done 2026-10-25.
- K33 — the argument's section 3, "typed at every instance" does not follow at none, and no rule gives `fn f() = kill(self())` its type. fix: §3.9's defaulting rule in the calculus and the lemma stated. done 2026-10-25.
- K34 — the argument's 6.2 gives the wrong reason for the spawned-at-`Never` case. fix: `Never` alone. done 2026-10-25.
- K35 — the argument's 5 and 7 list the sources of addresses incompletely. fix. done 2026-10-25.
- K36 — the argument's 2 asserts a consequence it does not argue. fix. done 2026-10-25.
- K37 — the argument's 5 rests on §4.8's open result type unstated. fix. done 2026-10-25.
- K38 — the argument's 7 cites the reload paragraph for §8.7's premise. fix. done 2026-10-25.
- E5 — E.27's "the runtime's own first steps of a dial come beside that time" names no bound. fix: §8.7 states the bound, the host's setup time of seven seconds for a connection's handshake, which the carrier sets; decided in the review's session. done 2026-10-25.
- L1, U8 — the deadlock look does not see a delivery foreign code arranges for after its call returns, a host timer or a host process, so `ern run` faults such a program; why.md's "never wrong" and §8.6's rule on an unmonitored foreign process. fix: §8.6 states that a delivery arranged by foreign code after its call returns is not seen, why.md and the guide's §5.4 say so, and why.md's "never wrong" takes §8.6's exception. done 2026-10-25.

## The guide, the tour, the README and the questions

- M1, L9 — why.md's "can never send a server a message it does not take" and the FAQ's silence on a request no clause takes, which waits for good. fix: "a message of a type the server does not take"; one FAQ line; §10's sentence scoped. done 2026-10-25.
- M2, L7, U1 — four places say no binding reaches a bare node, where a constant does. fix: the rule as it stands, a constant crossing with the code and any other binding staying, with an example that stays. done 2026-10-25.
- M3 — a prompt's `let` reaches no peer, and nothing says so. fix: one sentence in §8.1 and the tour. done 2026-10-25.
- M4 — "an operator" undefined in why.md, faq.md and the guide, and the message "expected an operator, `compare` or `negate`" calls `<` not one. fix: the six named in §7.2; the message names them. done 2026-10-25.
- M5, U2 — §7.3's `Optional(Int)` example of a field without `compare`. fix: `Bool`. done 2026-10-25.
- M6 — the FAQ's Gleam answer lists as differences three things Gleam has. fix: what Gleam lacks alone. done 2026-10-25.
- M7 — tour chapter 1 shows only the refused send, which Gleam refuses too. fix: one input showing the mailbox refusal. done 2026-10-25.
- M8 — the FAQ's one-mailbox answer reads as all gain. fix: one sentence pointing at §4.4. done 2026-10-25.
- M9 — why equality is inferred and order written is never said. fix: one sentence in §7.3. done 2026-10-25.
- M10 — nothing in §1.2 or §9.3 says what ends a running input, `C-c`. fix: one sentence, as the shell's README has it. done 2026-10-25.
- M11 — §8.2 shows only the failure path. fix: the two-node run shown, as §8.1 shows its compute. done 2026-10-25.
- M12 — the type-class contrast drawn against dispatch at run time, which a Haskell class lacks too. fix: the closed set of members is the line. done 2026-10-25.
- M13 — the FAQ's list of what Gleam has leaves out aliases, string-prefix patterns and a language server. fix. done 2026-10-25.
- M14, U10 — §2.5's list of types with a `compare`. fix: the prelude's orders as §3.10 has them, and `derives compare`. done 2026-10-25.
- M15 — §8.9 leaves out `Code.running`'s 64-frame clause. fix. done 2026-10-25.
- M16, L15 — deployment.md's send "returns at once" beside the host's buffer, and the language guide's §4.1 silent on it. fix. done 2026-10-25.
- M17, L21 — §1.1's "as in ML and Erlang". fix: drop. done 2026-10-25.
- M18 — four long sections. dropped: decided before 0.5.0 (M28), the guide's long sections kept whole where every sentence teaches; deployment.md:49's twelve refusals become a list, fix. done 2026-10-25.
- M19 — the help "annotate it" where the fix is a `needs`. fix: the help names the `needs`. done 2026-10-25.
- L2, U15 — why.md:96, faq.md:67 and the guide's §8.3 say a wrong-typed message from foreign code faults on delivery, where a delivery into the caller's own mailbox is the foreign side's promise. fix. done 2026-10-25.
- L3 — what a service binding names after its last restart, a dead process, the program going on, is said nowhere. fix: one sentence in §6.5 and the FAQ. done 2026-10-25.
- L4 — why.md's upgraded counter runs under `restarting`, which undoes the upgrade at its next fault. fix: one sentence citing deployment §5.3. done 2026-10-25.
- L5 — with two peers "two drawn at random" is both, so a burst within one telling goes to one node, and the tour's chapter 7 run was luck. fix: tour chapter 7 and §8.1 say so. done 2026-10-25.
- L6 — a node reads the whole tree beneath its program's directory, and a stray `.erc` refuses the start. fix: §8.1 and deployment §5.1. done 2026-10-25.
- L8 — a sibling busy in a long computation keeps the faulted child down. fix: one sentence in §6.6. done 2026-10-25.
- L10 — "`Address.call` is `gen_server:call` with a timeout", which answers `None` with no reason. fix. done 2026-10-25.
- L11 — the `Down` order given up is Erlang's promise, which §10 does not name. fix. done 2026-10-25.
- L12 — faq.md:93 and §10 contradict each other on tables. fix: one wording. done 2026-10-25.
- L13 — §2.9's "no time that means no limit" against `callForever` and a bare `receive`. fix: scoped. done 2026-10-25.
- L14 — §4.2's "never through a mailbox". fix: "the caller's typed mailbox". done 2026-10-25.
- L16 — the shell's `Counter$1` names cannot be written. fix: one sentence in why.md. done 2026-10-25.
- L17 — deployment §8's "the counters go on with their totals" shows nothing of it. fix: the clause says what the walk shows. done 2026-10-25.
- L18, U7 — the tour says a node's line begins with the time, which holds at a file or a pipe alone. fix. done 2026-10-25.
- L19, U6, U7 — consoles omit the node's `listening on` line, and §8.1's foo's lines land in the same terminal. fix. done 2026-10-25.
- L20 — `-setcookie` visible in `ps`, said nowhere. fix: one line in deployment §2.2. done 2026-10-25.
- N2 — a doc example of an exported declaration must write the qualified name, and the message says nothing of it. fix: §7.1 says an example is written as a caller writes it, and the help writes `Checks.add`. done 2026-10-25.
- N3, U4 — `Peer.setUtilization`'s range in §8.1. fix. done 2026-10-25.
- N5 — §2.3 never says a prelude type's name is barred as a constructor's, and the help assumes an alias. fix: the sentence, and the help for a constructor with fields. done 2026-10-25.
- N6 — the development build prints `0.4.0-dev` beside pages saying `since 0.5.0`. dropped: the mark says the build is no release, and `since` names the release a name ships in; VERSION moves at the tag.
- N7 — §5.4's garbled sentence. fix. done 2026-10-25.
- N8 — §2.5's equality sentence. fix: three sentences. done 2026-10-25.
- N9 — §4.1's `+` mark unexplained. fix. done 2026-10-25.
- N10 — §3.3's `emptyMap` undefined and the rule unargued. fix. done 2026-10-25.
- N11 — the README's numbers without units and `Get` passed unexplained. fix. done 2026-10-25.
- N12 — the README's and why.md's deadlock claim leans on the runtime's words. fix. done 2026-10-25.
- N13 — "one with its file" counts without what it counts. fix. done 2026-10-25.
- N14 — "Two nodes are two files". fix. done 2026-10-25.
- N15 — code before the text says what it is, four places. fix. done 2026-10-25.
- N16 — a request queued behind the message that faults a child is lost. fix: one sentence in §6.6. done 2026-10-25.
- N17 — `Io.debug` "prints any value" against `needs a.show`. fix. The shell printing another module's constructors unqualified: dropped, since `show` writes a value as its module's construction and the type beside it names the module, principle 1 against a text that changes with where it is printed; decided in the review's session. done 2026-10-25.
- N18 — `ern build`'s help where an `.erc` of another namespace stands. fix: "or remove main.erc". done 2026-10-25.
- N19 — the FAQ's no-warnings answer opens on other compilers. fix. done 2026-10-25.
- N20 — §8's sentence of ninety words on `Proxy.start`. fix. done 2026-10-25.
- N22 — the README's OTP 29 with no pointer. fix: one line. done 2026-10-25.
- U3 — deployment §1.1's group-write rule stale. fix. done 2026-10-25.
- U5 — deployment §6's `ern$3` clause. fix. done 2026-10-25.
- U9, U14 — a compute's and a call's cause in the guide. after P8.
- U11 — §3.3 states one of §4.6's three cases. fix. done 2026-10-25.
- U12 — deployment §3.4's "since it never dials". fix. done 2026-10-25.
- U13 — §4.4 and §8.2 omit `callee ended with its program`. fix. done 2026-10-25.
- U16 — §5.5 does not teach the wrap's `self`. fix. done 2026-10-25.
- U17 — §7.1 omits `ern test`'s `killed`. fix. done 2026-10-25.
- U18 — §6.3's frames rule narrower than E.21. fix. done 2026-10-25.
- U19 — deployment §5.3's "is not moved so". fix. done 2026-10-25.
- U20 — deployment §4.3's `--libs-dir`. fix. done 2026-10-25.
- U21 — §4.1 cites §4.5 for §3.9's rule. fix. done 2026-10-25.

- B-S1, found by the guide's agent — at the prompt, `let p = twice(fn(x : Int) = x)` is refused as undetermined, where `let q = List.reverse([fn(x : Int) = x])` is `List((Int) -> Int)` and a module's `let p` is `(Int) -> Int` by §4.6. decided with the user 2026-10-25, to build in this round: the prompt's `let` follows §4.6 as a module's does, since §11.2 gives the prompt no rule of its own; or §11.2 states the prompt's rule. done 2026-10-25.

## The language and the names

- N21 — a split at the first separator, a sibling path, a line reader for a socket. decided with the user 2026-10-25: `String.splitOnce(text, separator) : Optional(#(String, String))`, a shim of the host's `string:split/2` under admission rule 1, built in this round `since 0.5.0`; the sibling path is one line in the program and a line reader for a socket is a library's, dropped.
- N23 — a prelude type's name barred as a constructor's. dropped: kept, since a constructor of a type's name reads as the type, the prelude's included, and §2.3 states it (N5); decided in the review's session. done 2026-10-25.
- N24 — one mailbox type puts a process's own events in its clients' protocol, a second type and `adapted` the way out. dropped: `adapted` is the one way (principle 2); recorded for the user's eye.
- N25 — a restart empties the mailbox, so a test waits for `Restarted` before it calls. dropped: §6.9 as decided; the service monitor is the tool.
- N26 — `after` reserved; every `Fs` call takes a time. dropped: §2.4; shape rule 8.
- H1 — no stable greatest-first sort by a key that is no number since `List.sort` takes no order. dropped, decided 2026-10-24 in *A Member Has One Face*, read again with the user 2026-10-25: `List.sortBy(list, key)` stays, and a descending order by a key is a key of a type whose `compare` is reversed; weighed against `Ordering`'s reverse, a `Descending(a)` wrapper in the prelude, or a `List.sortByDescending`; recommendation to the user, principle 5 first.
- H2 — a test that needs a binding evaluated hides its initializer. dropped: §4.6's constant is the rule; the tests say why at each site (C3-C10).
- H3 — `(Int) -> Int.compare` in a message. fix. `ern format --check tour` refusing the numbered directories: dropped, §11.1; the tour's README says so. done 2026-10-25.
- N27–N37, the names, each searched: N27 `Os.termination`, N28 `Process.faults`, N31 `Supervisor.group`, N32 `Fs.makeFile`, N33 `Fs.makeDir`, N35 `within`, N37 `monotonicMicros`: dropped, kept, each the report's word, a subscription named for what arrives (shape rule 8), a record whose other field says what it counts, and E.15's pair; decided in the review's session. N34 `List.first`: dropped, since `x :: _` is the first element and `List.last` exists for the pattern no list has; decided in the review's session. N36 `setUtilization(x)`: fix, `utilization`. N29 `OrderedSet.Set`: dropped, decided 2026-09-29 in *Operations Records*, shape rule 7 naming a type for what it is and never for its module. N30 `Supervisor.Msg`: decided with the user 2026-10-25, to build in this round, `Supervisor.GroupMsg` by the guide's rule, across E.22, the guide, the examples and the tests. Weighed as: N29 beside the prelude's `Set`, and N30 `Supervisor.Msg` against the guide's rule that a mailbox type is named for its process with `Msg`, `GroupMsg`: decide, searched; a word of the user's. done 2026-10-25.
- E4, N4 — a member's page, `:doc` and `:browse` head a call the language refuses, and `:browse` shows no parameter names. decided with the user 2026-10-25, to build in this round: §11.4 states that a member is headed by the form a program writes, `compare(left, right)` or `left < right` at its type, and listed under its type as a member, which `ern doc`, `:doc` and `:browse` follow; `:browse` with parameter names as `:doc` has them. done 2026-10-25.

## The code

- C2-C1, S1 — `ern run prog.erc --config-dir x`, the flag among the program's arguments, runs the program twice, the hidden run reading standard input. fix: the launcher reads the words before the file alone, as_node's `undefined` branch throws, and a test. done 2026-10-25.
- C2-C2 — a full scan of the callees table on every restart's and end's path through `undelivered`. fix: `delivery_ended` ends with `{ern, killed}` and `left_call` runs where `is_host_end`. done 2026-10-25.
- C2-C3 — `say/2` waits for standard error, so the gateway and the TLS check block on a slow reader. decided with the user 2026-10-25, to build in this round: an asynchronous say for the gateway and the verify fun, keeping the order where a program's output is beside it; or blocking accepted and stated in the runtime's note. done 2026-10-25.
- C2-C4 — `ern_shell:own/0` answers `[none]` against its spec. fix. done 2026-10-25.
- C2-C5 — entry_end's unreachable `carried` clause. fix. done 2026-10-25.
- C2-C6 — ern_show's unreachable `<foreign>` branch. fix. done 2026-10-25.
- C2-C7 — `ern_peer:picked/0` kept for tests, beside `pick/0`. fix. done 2026-10-25.
- C2-C8 — `ern_code:ground/1` takes an identity whose name it ignores. fix: by hash. done 2026-10-25.
- C2-C9 — the process row a positional 6-tuple across modules. fix: a record. done 2026-10-25.
- C1-C12, C2-C10 — a foreign declaration's six fields as tuples in two orders. fix: a record. done 2026-10-25.
- C2-C11 — a monitor's kind by nesting its wrap. fix: a record. done 2026-10-25.
- C2-C12 — five copies of the root's distance. fix: one function. done 2026-10-25.
- C2-C13 — a private directory made twice the same way. fix. done 2026-10-25.
- C2-C14 — three texts of one refusal. fix. done 2026-10-25.
- C2-C15 — an option's long name spelled three ways. fix. done 2026-10-25.
- C2-C16 — `demonitored` twice, `noted`, `placed`, `started`, `unheld`. fix. done 2026-10-25.
- C2-C17 — the glossary refuses `Frame` for a trace's line, where E.21 and the code use it. fix: the glossary. done 2026-10-25.
- C2-C18 — a timer's message under four names. fix: `deadline`. done 2026-10-25.
- C2-C19 — six comments and notes that no longer hold. fix. done 2026-10-25.
- C2-C20 — four places shorter. fix. done 2026-10-25.
- S2 — a connecting node's handshake name written raw. fix: `ern_show:controls`. done 2026-10-25.
- S3 — `is_source/1` accepts any integer from a peer. fix: refused as faulty. done 2026-10-25.
- S4 — the configuration directory's parent unchecked. dropped, decided with the user 2026-10-25: §8.3's rule is the directory's own mode, and a parent check would refuse every directory under `/tmp`, world-writable by design; weighed: check the parents up to the root as ssh does, a sentence of §8.3; or dropped, the directory's own mode being the rule the report states.
- C1-C3 — the alias help writes a fix that does not compile. fix. done 2026-10-25.
- C1-C4 — `derives compare` offered to a foreign type. fix. done 2026-10-25.
- C1-C5 — a member in a type or a pattern told it is in an expression. fix. done 2026-10-25.
- C1-C7 — `ern_types:elided/2` and `format_pair/3` without callers. fix. done 2026-10-25.
- C1-C9, K24 — `#e_member{}` and `{member, Supply}` serve the derived compare alone. decided with the user 2026-10-25, to build in this round: the derived compare calls the prelude's `compare` and the machinery goes, the form version moving; principles 2 and 5; recommended now, since 0.5.0 moves the form version anyway and the three forms cross nodes. done 2026-10-25.
- C1-C10 — §4.9's rule that a declaration with a requirement binds no name of its type variables has lost its reason. fix: dropped from §4.9 and the checker with its tests, principle 1; decided in the review's session. done 2026-10-25.
- C1-C11 — `peekUntil`'s retry on a chosen number. fix: `callForever`. done 2026-10-25.
- C1-C13 — two four-part tuples. fix: records. done 2026-10-25.
- C1-C14 — `?IS_USEROP` a guard macro, the set written four times. fix. done 2026-10-25.
- C1-C15 — `orelse` chains before `fail`. fix: `case`. done 2026-10-25.
- C1-C16, C3-C5 — comments citing the review's finding ids and feedback numbers. fix: the log entry. done 2026-10-25.
- C1-C17 — `#fence{}` without a glossary entry. fix. done 2026-10-25.
- C1-C18 — five stale comments. fix. done 2026-10-25.
- C1-C19 — seven names. fix. done 2026-10-25.
- C1-C20 — `<` on a type without `compare` refused two ways; a help that restates; code quoted unevenly; `f(x).+`. fix. done 2026-10-25.
- C1-C21 — six places shorter. fix. done 2026-10-25.
- C1-C22 — `is_member` true for `Address.compare`; two refusals outside the diff without help. fix. Fenced container blocks: dropped, none exists. done 2026-10-25.
- E2 — line mode's `:faults` misses a report that arrived while the session waited for the line. fix. done 2026-10-25.
- E3 — line mode stamps a fault with the time the next line arrived. decided with the user 2026-10-25, to build in this round: the report carries its time, E.21's `FaultReport` gaining `time`, since `ern run` stamps the fault's moment and the shell should too; or line mode reads in a reader process of its own. done 2026-10-25.
- E6, E7, E8 — `own` for two things, `faultedLine` beside `faultLine`, five names for the region's rows. fix. done 2026-10-25.
- E9 — the shell's README on `leave` in line mode, and the repeated pair. fix. done 2026-10-25.
- E10 — lease_broker's `main` after its helpers. fix. done 2026-10-25.
- E11 — `takeBack` rests on §6.9's order unsaid. fix. done 2026-10-25.
- E12 — the tour's `isPrime(number, divisor)`. fix. done 2026-10-25.
- E13 — word_count's reversed ties against its comment. fix: `sortBy` on a pair. done 2026-10-25.
- E14 — three doc sentences. fix. done 2026-10-25.
- N1 — a `fault` in a `match` clause loses every caller frame. diagnosed 2026-10-25: the host compiler's type optimization proves a local call that faults cannot return and compiles it as a tail call, so the callers' frames go; only `no_type_opt` restores them. decide: build with `no_type_opt` and measure it in the bench's three runs; keep it where the ratios hold, else §7.3 and E.21 state that a frame whose call the host proves cannot return is absent.
- U24 — a function computed on a peer compiles `a / b` as a call of `Int./`, losing its own frame. diagnosed 2026-10-25: `heavy`'s form is `Int./`'s, one hash, and the peer runs the unit it holds, so the frame names `Int./:52`; dropped under K5's decision, a trace naming the unit that ran, which Appendix H and E.21 state.
- C3-C1 — `make bench-library` fails on a clean checkout. fix. done 2026-10-25.
- C3-C2 — the shell tests' `waits/1` copy. fix. done 2026-10-25.
- C3-C3 — `--load-path` for libraries in two tests. fix. done 2026-10-25.
- C3-C4 — `deployment` and `tour` depend on `machines` for nothing; `answering/4`'s `Ms`. fix. done 2026-10-25.
- C3-C6 — the shell tests' bounds two ways. 3.95: item 4.
- C3-C7 — the parser fixture held from `fn tokenize` on. fix. done 2026-10-25.
- C3-C8 — loops written by hand beside `looped/1`; two names reused. fix. done 2026-10-25.
- C3-C9 — `Number` for a row's name. fix. done 2026-10-25.
- C3-C10 — a split literal unexplained. fix. done 2026-10-25.
- C3-C11 — `module_named/1` re-implements §4.2. fix. done 2026-10-25.
- C3-C12 — `told/1` repeats `ended/1`. fix. done 2026-10-25.
- C3-C13 — bin/ern's iconv check before `--help`, and its header. fix. done 2026-10-25.
- C3-C14 — paragraphs.sh's repeated test. fix. done 2026-10-25.

## The machines

- Y1 — dialyzer: `ern_lexer:error_at/3,4` and `ern_bits:overflow/2` have no local return, without a spec saying so. fix: `-spec … -> no_return()`. done 2026-10-25.
- Y2 — dialyzer: `ern_rt:trace_line/1` gives `ern_namespace:site_text/2` a string segment, which `text/1`'s spec refuses though its code takes it. fix: the spec. done 2026-10-25.
- Y3 — dialyzer: `ern_release:release/0` matches `""` against a macro the development build never gives. fix: the decision by a function the analyzer does not fold. done 2026-10-25.
- Y4 — the fresh clone's full run: `job_output_drained` timed out at 60 s while the readers' builds ran beside it. dropped: run again on the quiet machine; its bound is MVP 3.95's item 4.
- The sanitizers wrote nothing; the seven loads were flat; the service manager's checks passed under systemd, launchd's not run; `make sections` named nothing.


# The readers' lists

## P, the principles

Read §0 whole, then every section `git diff 1329d1d2 -- report/` touched, each with its neighbors, against the five principles alone. Programs under the reader's scratch directory (t1..t31), built with bin/ern at 0e37caeb; outputs quoted below are the toolchain's.

### Defects

P1. Appendix E.18, report/library.md:608. Quote: "so `Process. An operation on a socket or a listener is a call on its process, and faults as a call does, with §6.6's causes, `callee was closed` for one the program closed.live`, `Process.status` and `Process.faults` include them." A sentence was spliced into the middle of the name `Process.live`; the paragraph is unreadable and the inserted rule is lost. Fix: close the first sentence at "`Process.live`, `Process.status` and `Process.faults` include them." and put "An operation on a socket or a listener is a call on its process, and faults as a call does, with §6.6's causes, `callee was closed` for one the program closed." after it.

P2. §5.6, last paragraph. Quote: "A qualified operator is a function value, `Int.+`." Contradicts §4.5 ("its name ... stands in a declaration and in a requirement and in no expression"), §4.8 ("an operation the language writes as an operator has no function form") and Appendix A, whose `QName` and `Primary` no longer have the `userop` alternatives. Program t2: `let f = Int.+` is refused, "`Int.+` names a member, which an expression reaches through `+`". Fix: delete the sentence.

P3. §4.9, first paragraph. Quote: "`zero is not a member: a requirement names compare, negate, an operator or show (report §4.8, E.1)`". §11.5 now states "No message, label or help cites the report, but the help of a §3.11 refusal", and the compiler agrees: t28 prints `zero is not a member: a requirement names compare, negate, an operator or show` with no citation. The report quotes a message the toolchain does not write. Fix: drop "(report §4.8, E.1)" from the quoted message.

P4. Appendix E.15. Quote: "a time outside the years 0 to 9999 is written as the host writes it". False above 9999: t7, `Clock.toString(253402300800000)` faults with `foreign function calendar:system_time_to_rfc3339/2 raised error:{badarg, ...}`; below 0 it is written (t7b: `-0001-12-31T23:59:59.999Z`). The fault stands in no list of §7.4, against E.0 shape rule 4 ("A function faults only as §7.4 says"), and shape rule 4's own answer for a partial operation is `Optional`. Fix: `Clock.toString : (Int) -> Optional(String)`, `None` past year 9999, or state the host's bound and the fault in §7.4; see P11 for whether the function belongs in the standard library at all.

P5. §9.6 beside Appendix E.2, E.10, E.11. Quote (§9.6): "`List.compare` ... // Appendix E.2 provides it, as List.<>", "// Appendix E.10 provides it", "// Appendix E.11 provides it". E.2's prose says the module provides `List.<>` and says nothing of `compare`; E.10 and E.11 do not contain the word `compare` at all. The owner §9 points at says nothing. Fix: one sentence in each of E.2, E.10 and E.11, as E.2 has for `List.<>`: "`Optional.compare` is the prelude's, §9.6; this module provides it."

P6. §4.5, second paragraph. Quote: "`fn f() : Unit = kill(self())` has type `() -> Unit`, as it has with `: Unit receiving m`", two sentences before "`receiving M` where `M` is a type variable that names no parameter's mailbox type is written only where the body involves its mailbox". Two spellings of one declaration are accepted and give one type (principle 2), and the `receiving m` the writer wrote is dropped from the type the compiler prints (t4: `fm() : Unit receiving m = kill(self())` documents as `T4.fm() : Unit`), so an annotation says what its signature does not keep (principle 3). A reader who knows that `fn k() : Int receiving m = 5` is refused with "write k's type without `receiving`" predicts the same refusal here. Fix: refuse `: T receiving m` wherever §3.9 makes `m` none, with that help, and strike "as it has with `: Unit receiving m`".

### Matters of principle

P7. §9.3 and §6.9, `Restarted` in `Reason`. Quote: "type Reason = ... | Unreachable | Restarted // Restarted to a service monitor alone". Principle 5: "A feature costs a program that does not use it nothing: no argument, no word, and no name of it is written there." Every exhaustive match on a monitor's reason now writes the word: t3, a six-clause `match reason { Returned -> ... | Unreachable -> ... }` is refused, "match on Reason is not exhaustive; missing Restarted", in a program that never calls `monitorService`. Principle 1 beside it: §6.9 says "A restart is not a death", yet the restart arrives as a `Down`; a reader predicts a message of its own. The report accepted the same cost once for `Unreachable` ("a `match` on a `Reason` covers it as any constructor"), so this is a decision, not an oversight; `Unreachable` at least is a kind of not knowing whether the process lives, where `Restarted` is the opposite of down. Fix: deliver a restart through a wrap of its own type, `monitorService : (Process, (Down) -> m, (Restarted) -> m) -> Unit receiving m` with `type Restarted = Restarted(process : Process, site : String)`, and `Reason` as it was; principle 5 decides, since the cost falls on the programs that do not use the feature.

P8. §6.6, §7.4, §8.7 (compute). Quote: "with the callee's cause and the callee's site as a `Down` names it (§6.9) after it, `division by zero, the fault of the callee Ledger.start:6`", and for a compute "that cause followed by `, on the peer p`". A cause that was one value is now a text composed of the cause, a site and a line number, and it chains along a chain of calls. Program t31: `Test.faults(ask, "division by zero")`, `ask` a `callForever` on a server that divides by zero, fails with `expected the fault division by zero, got the fault division by zero, the fault of the callee T31.ask:9`; the test must write the line of the spawn, which moves with every edit above it. A reader who knows §11.2 predicts the site where §11.2 already puts the spawner, after the cause in the report's line, `, spawned by the peer desk`, and not in the cause a program matches on. Fix: the caller's cause is the callee's cause; `ern run`'s line and the trace carry `, the fault of the callee Ledger.start:6` and `, on the peer p`, as they carry `, spawned by the peer desk`.

P9. §4.6 against §3.9. Quote (§4.6): "an effect variable left in its type ... is none (§3.9) where it stands as a function type's effect, a parameter's among them"; (§3.9): "A variable in a parameter's type stays". Program t4d: with `fn makeApplier() = fn(f) = f() + 1`, `let h = makeApplier()` is `(() -> Int) -> Int` and `fn h2() = makeApplier()` is `() -> (() -> Int receiving e) -> Int receiving e`; so t4e `h(waits)` with `waits : () -> Int receiving Int` is refused, "a function that receives nothing and one that receives do not match", and t4f `h2()(waits)` compiles. A reader who knows §3.9's rule predicts the same type for the two. The rule buys `let p = twice(fn(x : Int) = x)` compiling, where the asymmetry does not show. Fix: for a top-level `let`, an effect variable in a parameter's type is a type error that asks for an annotation, as any other variable left is, or §4.6 shows this example as the departure it is.

P10. §6.9, the service monitor. Quote: "the restarting process empties its mailbox, waits until each service monitor's `wrap` has placed its message, and then runs `f` again, so a wrap that does not finish holds up that restart", beside the standing sentence "A `wrap` that does not finish holds up no other delivery." A watcher's code now delays the watched service's restart, and nothing in the service's text shows who watches it (principle 3: control flow visible where it happens). The ordering it buys, "reaches its watcher before anything the new run sends", is the feature; so keep it, and name the exception where the reader meets the rule it breaks. Fix: "A `wrap` that does not finish holds up no other delivery, but a service monitor's holds up the restart it is told of (below)."

P11. Appendix E.15 against E.0 rule 2. Quote (E.0): "A published specification, a date, a pattern language, a format, a protocol, is a library's and no module's vocabulary"; (E.15): "`toString` writes an epoch time in RFC 3339 ... as the runtime's own lines write theirs (§11.2); nothing else of dates is the standard library's". The second sentence admits the breach without naming the rule that admits it; the function exists so that a program's log lines look like the runtime's. Principle 5's last sentence: "No rule of the language exists for the runtime's or a library's convenience." Fix: either E.0 rule 2 states the admission (one fixed text form the toolchain itself writes, as E.9 states `Float.toString`'s), or `Clock.toString` goes to a library beside `libs/json`.

P12. §4.6 and §11.1, Appendix F. Quote (F): "**constant** — a top-level binding's initializer that is a literal, a negated number literal, a constructor of no fields, or a constructor, a tuple or a list of constants"; "**ground term** — a literal, a negated number literal, a constructor of no fields, or a constructor applied to ground terms or a tuple or a list of them". Two names, two glossary entries, one concept (principle 2, principle 5's count). §11.1 writes both in one sentence, "whose initializer is a constant (§4.6), a *ground term*". Fix: §11.1 says "a constant (§4.6)" alone, and F's "ground term" entry goes.

P13. §11.2, doc examples. Quote: "An example's declarations are the longest run of its leading paragraphs, short of its last, that parses as declarations". A rule that needs trial parses, in a report whose principle 4 is first-token dispatch and no backtracking; Appendix A already decides by the first token, "an identifier or type name after `fn` makes it a declaration, `(` a lambda", and an example's body is an expression, so a paragraph that begins `type`, `abstract`, `foreign` or `fn` followed by a name is a declaration and the rest is the body. Fix: state that first-token rule and drop the longest-run search.

P14. §4.2, type members. Quote: "A member of an exported type and an exported value of the module of its name, a function or a `let`, may not share a name all the same". The reason for the clash rule, that `Main.Stack.compare` named two things, is gone: "A qualified name `Main.Stack.compare` in an expression is the module `Main.Stack`'s `compare`". The rule survives for `ern doc`'s heading and `:doc` alone, and §11.1 adds a dependency for it, "A module depends too on the module whose namespace its own stands directly under". Fix: name the reason that keeps it in §4.2, or drop the rule with §11.1's dependency.

P15. Appendix H, derived `compare`. Quote: "a parameter's several members in the host's order of their names". The form is normative and crosses nodes by hash; "the host's order" is stated nowhere in the report. Fix: "in the order of their names' code points".

P16. §9.6 against §0 principle 5 and F's **primitive**. Quote (§0): "Every function the prelude or a library names is a value, taken, passed and stored as any function is. One that is not is a primitive, named where the report states it and counted here." §9.6 lists 22 members with function types, `Int.+ ... : (Int, Int) -> Int`, that no expression names (t2, t2b, t2c refused); by §0's own words they are primitives now, and §9.6's paragraph says only that the operator is the primitive. Fix: §9.6's paragraph states that a member it lists is named in a declaration alone (§4.5) and is no value, so the reader counts it where §0 says.

### Counts over the whole report

- Reserved words: 18, §2.4's table added by row, 4 + 6 + 3 + 2 + 1 + 2. Unchanged.
- Words read by position: 16, `needs`, `derives`, `compare`, `negate`, `show` (§2.4) and the 11 `BitSpec` alternatives of Appendix A. Unchanged.
- Operator and delimiter tokens: 36, the two lines of §2.6's first block, 19 and 17. Unchanged; the grammar lost the `typevar "." userop` and `typename "." userop` alternatives but no token.
- Prelude types: 21, §9.1's 10, §9.2's 3, §9.3's 8. Unchanged.
- Prelude functions: 40, each line of §9.4 (6), §9.5 (10) and §9.6 (24), a line with several names counted once each. Was 33: §9.5 adds `Reply.process`, `monitorService`, `demonitor`; §9.6 adds `List.compare`, `Optional.compare`, `Either.compare` and `compare`. Of the 40, 22 are members that no expression names (P16) and 18 are values; `compare` is a value (t1, t1b, t1c). Forms called where named: 5, unchanged, `Peer.spawn`, `Peer.spawnMonitored`, `Peer.compute`, `Peer.computeAt`, `Code.running`, all library names.
- Concepts: about 71, at the grain of a rule a reader must hold to predict a program, counted as the previous reader counted: the members' one face replaces "a qualified operator as a value" with "a member reached by its operator alone" (0), `compare` as the one way to an `Ordering` joins §3.10's order (0), and *constant* and *service monitor* are new (+2); minus one where the reader takes "constant" and "ground term" as one (P12). So 70 to 72.
- Appendix F: 167 entries. Was 163: `constant`, `demonitor`, `service monitor`, `version text`.
- Standard library modules: 27, the 29 `### Appendix E.` headings less E.0 and E.19 (folded). Unchanged.
- Exported signatures: 357, the lines `Name.name :` inside Appendix E's and G's code blocks. Was 356: `List.sortBy` and `Clock.toString` in, `Bool.not` out.
- Admission rules 4, shape rules 10. Unchanged.
- Libraries: 6, G.1 to G.7 less G.5 (removed). Unchanged.

### What each changed rule buys, and what the language would lose without it

- Members have one face (§2.3, §2.6, §4.2, §4.5, §4.8, §4.9, Appendix A, F): buys one way to each operation, two grammar alternatives gone, `Bool.not` gone, `a.compare(x, y)` gone beside `x < y`. Costs a lambda where a fold wants an operator. Worth it; principle 2 decided.
- The prelude's `compare`, and `compare` for tuples, lists, `Optional` and `Either`: buys one word for an `Ordering` as `<` is one for a `Bool`, and sorting by a tuple key. Worth it.
- `List.sort(list)` with `needs a.compare`, `List.sortBy(list, key)`, shape rule 1's "takes no function of the member's shape": buys that the type's own order is the one used. Loses sorting by an order that is no key, now a declared type with its `compare`. Worth it.
- None for an effect variable left unfixed (§3.9, §4.5, §4.6, §11.5, Appendix H): buys `kill(self())`, `monitor` wraps and `Process.current`-style bodies without a mailbox type. Costs P6 and P9. Worth it with those two fixed.
- Constants (§4.6, §8.5, §8.7, §11.1, §11.2): buys a binding a peer values from its form without evaluation, and a reload that leaves no constant without a value. Costs the second name (P12). Worth it.
- Service monitor, `Restarted`, `demonitor` (§6.9, §8.7, §9.3, §9.5): buys a watcher told of a restart before the new run speaks, and the letting go of a monitor. Costs P7 and P10.
- `Reply.process` (§6.6, §8.4, §9.5): buys a callee that can monitor or refuse its caller; the ABI pays a pid beside the alias. Worth it.
- The chained cause (§6.6, §7.4, §8.7): buys a report that names the callee; see P8 for where that belongs.
- The deadlock report's lines, the node's `listening on` line, `ern test`'s lines, `:faults` without traces, the CLI's refusals: each buys what an operator sees; none costs a program a word.
- A toolchain library's namespace not taken (§4.2, G): buys that a new library breaks no program. Worth it.
- `Clock.toString` (E.15): see P4 and P11.
- `Test.faults` waiting without a limit, its process killed with its caller, its mark the runtime's (E.24): buys a test that matches a direct call; costs nothing.
- Foreign code's third promise (§4.7) and the ABI's `Unit` line (§8.4): state what was unstated; cost nothing.

Rules whose answer is little: §4.5's acceptance of `: T receiving m` over a body whose type drops it (P6); §4.6's none in a parameter's type of a non-generalized `let` (P9); §11.2's longest-run example rule (P13); Appendix H's "host's order" (P15); §4.2's shared-name clash rule (P14).

Rules that exist only for another: §11.1's dependency on the parent module, for §4.2's shared namespace (P14); §9.3's `Restarted`, for `monitorService` alone (P7); §8.4's `Reply` as `{Alias, Pid}`, for `Reply.process` (fine, since its reason is stated there); Appendix F's **ground term**, for §11.1's word (P12); E.15's `Clock.toString`, for the runtime's own lines (P11).

Grammar (principle 4): Appendix A's changes remove alternatives and add none; every decision its paragraph names is one token, and `a.compare` in an expression parses as a selection the checker refuses, with no backtracking. No new finding there.

## K, the cold reader

Read the report where it changed since 1329d1d2 and the changed paragraphs of docs/soundness.md, at 0e37caeb; programs under the reader's scratch directory, each compiled with `ern build` and run where it runs.

### A. Report: defects

K1. E.18 (library.md:608): the paragraph is corrupted. Quote: "so `Process. An operation on a socket or a listener is a call on its process, and faults as a call does, with §6.6's causes, `callee was closed` for one the program closed.live`, `Process.status` and `Process.faults` include them." A sentence was pasted into the middle of the name `Process.live`; it also contradicts the later paragraph of the section, which gives `callee was closed` only when the close comes while the call waits untaken and `callee had ended` when the socket ended before the call. Fix: restore "so `Process.live`, `Process.status` and `Process.faults` include them", and drop the pasted sentence or merge it into the later paragraph.

K2. §5.6 (language.md:592) contradicts Appendix A and §4.5: "A qualified operator is a function value, `Int.+`." `QName` has no `userop` branch and §4.5 says a member's name stands in no expression; `let f = Int.+` is refused, "`Int.+` names a member, which an expression reaches through `+`" (qop.ern). Fix: delete the sentence, or "A member is no value (§4.5)".

K3. §6.3 (language.md:708): "`<`, `<=`, `>`, and `>=` compare the types whose `compare` §9.6 provides". §9.6 now provides `List.compare`, `Optional.compare` and `Either.compare`, Ernest code over the element's compare, against "A guard expression calls nothing and cannot fault"; the toolchain refuses them, "a `receive` guard orders only Int, Float, String, and Char, not List(Int)" (guard.ern). Fix: "compare `Int`, `Float`, `String` and `Char`, in their order (§3.10)".

K4. §0 (line 35) and §6.1 ¶1 (line 680) contradict §3.9 (line 293) and §4.5 (line 429). §6.1 says a function is `receiving M` if it "asks for a message to be delivered into it, as `monitor` ... or calls a function whose type names one, a prelude function of §9.4", and §0 that such a function "names the mailbox in its type"; §3.9's example `fn f() = kill(self())` has type `() -> Unit`, and `fn w(p : Process) = monitor(p, fn(d) = fault("x"))` documents as `w(p : Process) : Unit` (wmon.ern). Fix: state the condition once in §6.1 ¶1 and §0: the mailbox type is named only where it stays in a value position, a wait, or a parameter's type at the definition's end (§3.9).

K5. §6.9 (line 769) and Appendix H (toolchain.md:405) disagree with the toolchain on two identical definitions in two modules: "where the two stand in two modules, in the one the build compiled first (§11.1)". `dup/`: `src/alpha.ern` and `src/zed.ern` hold the same `boom`, `Code.hashes` gives one hash, `ern build --verbose` compiles Alpha first, yet the fault line and the trace say `Zed.boom:2`, the module Main called; "compiled first" is undefined for an incremental build that recompiles one of the two. Fix: decide the rule, the unit the call reached or the module first in path order, and make the report and the code agree.

K6. §4.6 (line 447) is silent where one variable is both a function's effect and a type argument: "none ... where it stands as a function type's effect ... and `Never` where it stands as a type argument". eff1.ern, `let q = both(fn(x : Int) = Unit)` with `both` returning `#((Int) -> Unit receiving e, Handler(e))`, gives `#((Int) -> Unit receiving Never, Handler(Never))`, `Never` in both places. Fix: "a variable that stands as both is `Never` throughout".

K7. §3.5 (line 259) contradicts §4.9 and §4.5: "In a body with a requirement, `a.member` names a member and selects nothing (§4.9)", where §4.9 says `a.member` is written in a requirement alone and Appendix A's prose says §4.5 refuses it. Fix: "In a body, `a.member` is refused where `a` is a type variable of the signature (§4.5)."

K8. §4.9 (line 473) contradicts §11.5 (toolchain.md:276): §4.9 quotes "`zero is not a member: ... or show (report §4.8, E.1)`", §11.5 says no message cites the report but a §3.11 help, and zero.ern prints it without the citation. Fix: drop "(report §4.8, E.1)".

K9. §11.1 (toolchain.md:38) contradicts §4.1: "A module depends too on the module whose namespace its own stands directly under, where that module exports a type of its name"; with §4.1's acyclic dependencies, `main.ern` exporting `Stack` and calling `Main.Stack.depth`, beside `main/stack.ern`, is a cycle, yet cyc/ builds and prints 3. Fix: say it reads the members from the source or `.erc`, and is no dependency of §4.1's.

K10. E.15 (library.md:538): "a time outside the years 0 to 9999 is written as the host writes it" is false past 9999: `Clock.toString(253402300800000)` faults with "foreign function calendar:system_time_to_rfc3339/2 raised error:{badarg,\n ...}", a multi-line host term; a negative year is written (clk.ern). E.0 shape rule 4 requires the fault stated. Fix: state the fault and its cause, or answer `Optional(String)`.

K11. §3.10 (line 312) and §9.6 (lines 1196–1198) say `List.compare`, `Optional.compare` and `Either.compare` are "each provided by its module as `List.<>` is (Appendix E.2, E.10, E.11)"; E.2's prose names only `List.<>`, and E.10 and E.11 have no prose at all, where E.8 has "`Int.compare`, `Int.negate`, and the operators are the prelude's, §9.6; this module provides them". Fix: add that sentence to E.2, E.10 and E.11.

K12. §0 principle 5 (line 67) contradicts §4.5 (line 437) and §9.6: "Every function the prelude or a library names is a value ... One that is not is a primitive, named where the report states it and counted here", where §9.6 lists `Int.+`, `Int.negate`, `List.compare` and others as typed prelude operations, §4.5 makes none a value, `List.<>`, `Path.<>` and `List.compare` are Ernest code and not primitives, and §0 counts nothing; §4.8's "an operation the language writes as an operator has no function form" sits oddly beside `compare`. Fix: §0 names members as the exception reached by operators, and §9.6 calls them members, not functions.

K13. E.0 shape rule 8 (library.md:210) contradicts E.24 (line 766): "`Address.callForever` is the one wait on another party without a limit", where `Test.faults` "waits for `run`'s end without a limit", on another process. Fix: name `Test.faults` as the second exception, or give it a time.

K14. E.0 shape rule 3 (line 182) against E.15's `Clock.toString : (Int) -> String`: a conversion is its argument's module's `toX`, and "when one conversion has several policies, the policy is the name"; an `Int` to `String` conversion under an RFC 3339 policy, in `Clock`, fits neither. Fix: rename it for its policy (`Clock.toRfc3339`), or state the departure as shape rule 10 asks.

K15. §11.6 (toolchain.md:318): "stay a space apart, a member `a.-` before a bitstring's `>>`" can no longer occur, `a.-` standing only in `needs`. Fix: a case that still occurs, or drop the example.

K16. §6.8 (line 755) disagrees with the toolchain: "a `receive` with a pattern clause written in a body receiving `Never` is a type error"; `spawn(fn() = receive { x -> Unit })` compiles, its mailbox `Never` by §6.2 (spawn_never.ern), `fn main() = receive { x -> ... }` compiles and deadlocks (never3.ern), and only a written `receiving Never` is refused (never4.ern). Fix: "written in a body annotated `receiving Never`", and state that a variable `Never` fixes later admits it.

K17. `Code.running(apply)` is refused with a help ending "(report §3.11)" (running2.ern); the rule is now E.28's, and §11.5 allows a citation only for a §3.11 refusal. Fix: cite E.28 and widen §11.5's exception, or drop the citation.

K18. Sections cite each other for facts neither states: §8.4 (line 904), "a value of another type a faulty peer sends is met where the receiving process matches on it (§8.7)", which §8.7 no longer says; §8.7 (line 1044), "A large value crosses in pieces ... (§8.4)", which §8.4 says nothing of; §3.11 (line 334), "A program holds an address of another node's process only from a find, a spawn or a compute, or inside a message (§8.7)", which §8.7 has no list of. Fix: each fact in one section, the others pointing at it.

K19. §4.2 (lines 368 and 390): line 368, "A module's own type, constructor or member ... is written plain within it; the qualified form there is an error", where a member is written in no expression; line 390, "A module may declare ... a function ... with a prelude name, and the name then means the local one throughout the module", against line 386's "`compare` in a body there is the prelude's", list.ern declaring `compare` and calling `compare(head, otherHead)` as the prelude's. Fix: drop "or member" at 368, and mark the prelude-type modules' members as the exception at 390.

K20. E.21 (lines 671 and 692) is narrower than §6.5 (line 720): `Process.current` is "the running process, or a wrap's recipient", where §6.5 makes it the sender, the target or the kept process in an adapted address's function. Fix: add "or the owner of an adapted address's function (§6.5)".

K21. E.22 (line 708) contradicts E.21 (line 679): "a child's fault is reported as its own `restarting` restarts it, `faulted, restarted`", which includes the fault at which the group gives up, after which the child "runs nothing more", where E.21 has `restarted` true "where the process restarts after the fault"; sup.ern prints `Sup.main:11 faulted, restarted: division by zero` for a child that never runs again. Fix: say how the giving-up fault is reported, and set `restarted` to match.

### B. Report: places a builder must guess

K22. §8.6 (line 970): "in the sites' order" names no order; dead.ern prints `Dead.alpha:10` before `Dead.alpha:9`, in text order, and the lines carry the same four-space indent as the trace frames above them. Fix: state the order, by declaration and then numeric line, and the lines' form.

K23. §6.6 (line 745): "the site left out where the callee has none" does not say whether ", the fault of the callee" is still written. Fix: give the text.

K24. Appendix H (toolchain.md:480): `{member, Supply}` is listed and never explained; its source is a derived compare's comparison of a field. Fix: say which expressions are `{member, Supply}`.

K25. §6.6 (line 743): the callee "may monitor or refuse its caller"; "refuse" names no operation. Fix: say what refusing is, or drop the word.

K26. §3.9 (line 291): "A function whose body holds a `receive`" reads as including a receive inside a nested lambda; `fn mk() = fn() = receive { after 5 -> Unit }` gives `mk() : () -> Unit receiving e+`, so `mk` itself is not process-only (po.ern). Fix: "a function whose own body, outside its lambdas, holds ...".

### C. Report: clarity

K27. Two names for one set of bindings: Appendix F has "constant" (1434) and "ground term" (1463), §11.1 says "a constant (§4.6), a *ground term*", and §8.7 (1054) states the same bindings twice, "having it wherever its form is" and "wherever its code is". Fix: "constant" alone, one clause.

K28. Examples whose names have no antecedent: §5.6 (590), "annotate ops", with no `ops` in the section, where the toolchain names the local and says "annotate it" when there is none (fill.ern, fill2.ern); §3.5 (257), "`Date.compare cannot be derived: Bool has no compare`" after a `Date` with no `Bool` field. Fix: give the declarations the messages belong to.

K29. Appendix F's load path (1479) orders every `--load-path` root before `--libs-dir`'s directories, where §11.2 orders them "in the order the options are given". Fix: align the two.

K30. §11.1 (toolchain.md:42) leaves out the compute: line 40 covers a lambda that "a `Peer.compute` or a `Peer.computeAt` runs", line 42 still "the function a lambda or a local `fn` that a spawn starts is compiled to". Fix: add "or a compute runs".

K31. §3.10 (316): "Where any other function is given as an order" and "the function it is given" no longer apply, `List.sort` taking no order. Fix: drop or reword.

### D. The argument

K32. Section 6.1 (168) misstates §4.6: "An effect variable that stands in no value position and is not process-only is none, wherever it stands", where §4.6 makes it `Never` as a type argument and the toolchain `Never` as a function's effect too where it also stands as a type argument (eff1.ern); a function `receiving Never` held by a top-level binding is never argued, though safe since it runs only at `Never`. Fix: add the `Never` case and its one-line argument.

K33. Section 3 (90–92): "Its body is typed at every instance of the variable" does not follow at none; `self`'s scheme keeps its `m` in a value position, so it is never none and none is no type, and no rule of the calculus gives `fn f() = kill(self())` the type `() -> Unit`; the argument rests on an unstated parametricity claim, "a call whose result is of the variable answers no value it was not given at it", and cites §4.5 where §3.9 is the rule. Fix: add §3.9's defaulting rule to the calculus, and state the lemma that a body with no value of α runs alike at every instance.

K34. Section 6.2 (180) gives the wrong reason for the spawned-at-`Never` case, "and the function, which receives nothing, reads no mailbox": a process-only function is spawned at `Never` too and reads the mailbox with a pattern clause (spawn_never.ern); the conclusion holds because `Never` has no values. Fix: rest the claim on `Never` alone.

K35. Sections 5 and 7 list the sources of addresses incompletely: section 5 (132), "every address to the process is made in one of four ways", leaves out the addresses system modules give and those foreign code gives; section 7 (249) leaves out an address inside a call's answer, which travels by alias. Fix: name these sources.

K36. Section 2 (28) asserts "a broken one is met where the receiving process matches on the value" without argument; a variable pattern binds the bad value and later steps go wrong. Fix: say only that a broken promise is outside the argument.

K37. Section 5's example (128), `{ let f = fn(n) = List.map([1], fn(d) = d + n); f(6) }`, rests on an unstated premise, that an operator's result type stays open until resolution (§4.8). Fix: add that sentence.

K38. Section 7 (241) says a ground-term binding has its value wherever its code is "as the paragraph on reloads below argues of it", where that paragraph argues the value has the binding's type, and §8.7's "made from the form and evaluated nowhere" is the premise needed. Fix: cite §8.7.

## N, the newcomer

Read README.md, guide/language.md whole, guide/why.md and guide/faq.md, with the `:doc` and `:browse` pages; did every exercise and checked each against the compiler: 1.5, 2.11, 3.7, 4.8(b), 4.8(c), 7.4(c) and 8.8 came out as §12 says, 8.8 to the exact message, and 6.7 matched but for its trace missing frames (N1). Then wrote `kvd`, 732 lines in four modules, a key-value server over TCP that keeps its values in a log file: a session per connection with a reader process, a tracker and a store; `Address.call` to the store and the tracker; a `Supervisor.group` (`OneForOne`) with the store and the tracker as children; `monitor` in the tracker and `monitorService` in a test; an append-only log compacted by writing beside it and renaming over it, read back at start; a listener, sessions and a client; `Clock.alarm` for keys that lapse and a compaction every 30 s; `Os.termination`; `Test.Case` cases and doc examples. It ran: `ern format --check kvd` clean, `ern build --build-root build .` in 1.3 s, `ern test build` 9 tests and 3 examples passed, two runs of the server with the client over a script, a `CRASH` restarted by the group (`Kvd.Store.start:41 faulted, restarted: asked to crash`), the log compacted at the end (exit status 143 on TERM), the values read again by the second run, two clients at once counted. Sources under the review's `kvd/`, with `demo.sh`.

### README and guide

N1. guide §6.3, language.md:1702, "the trace ends with the program's outermost frame". A `fault` raised inside a `match` clause loses every caller frame: `first` doing `match list { x :: _ -> x | [] -> fault("…") }`, called from `shown`, called from `main`, traces `Lost.first:4` alone (`ex/trace/lost.ern`); the same with `if List.isEmpty(list) then fault(…)` traces `first:2 / shown:5 / main:8` (`lost2.ern`), and so does `1 / List.size(list)` in the same `match` clause (`lost3.ern`). The §6.7 exercise's trace has no `main` frame either. Fix: keep the caller frames for a `fault` raised in a `match` clause, as for `if` and division.

N2. guide §7.1, language.md:2001–2035, shows only a private `fn add`. A doc example of an exported declaration fails unless it writes the qualified name: `export fn add` with `/// add(1, 2)` / `// => 3` gives `Checks.add example 1: failed: unknown name add`, the module's own example fails the same way, a private fn's example passes, `Checks.add(1, 2)` passes; the message says nothing about qualifying (`ex/dt/checks.ern`). Fix: resolve the module's own names in its examples as in its body; failing that, state the rule in §7.1 and add the help "write `Checks.add`".

N3. language.md:2593, "`x` from 0.0 to 1.0 … A number outside the scale faults the caller". `:doc Peer.setUtilization` says at or above 0.0, `Peer.setUtilization(1.5)` is accepted, and line 2519 says the scale goes above 1.0. Fix: "`x` at or above 0.0; a negative number faults the caller".

N4. guide §2.9 (596) and §9.3 (3156). `:browse` shows no parameter names, `Tcp.connect : (String, Int, Int)` not saying which `Int` is the port, and lists `String.compare`, `String.<>`, `List.compare`, `Int.+` among the functions; `:doc String.compare` prints `String.compare(left, right)` as a call, which is refused when written. Fix: print `:browse` lines with parameter names as `:doc` does, and mark members as reached through `compare` or the operator.

N5. `export type Command = Set(key : String, value : String) | …` gives `constructor Set is named as the type Set` with the help "there are no type aliases; a type that holds a Set is written type Command = Command(Set)", where no alias was meant; guide §2.3 (356) states the rule for the alias case only and never says every prelude type name is barred as a constructor name. Fix: one sentence in §2.3; where the constructor has fields or the type several constructors, the help says "rename the constructor; Set is the prelude's type".

N6. `ern --version` prints `0.4.0-dev`, the shell `Ernest 0.4.0-dev`, README:95 says 0.4.0 is the latest release, and `:doc List.sortBy` says "*Since 0.5.0.*". Fix: a development build after 0.4.0 calls itself 0.5.0-dev.

N7. language.md:1398, "a program started with `--config-dir` waits on where every process waits", garbled. Fix: "goes on waiting where every process waits".

N8. language.md:433 puts "and on a value of a foreign type, `Foreign.Term` … it is the runtime's exact equality" between the exceptions and their consequence, "so a map keyed by addresses is a type error". Fix: three sentences, the exceptions, foreign values, map keys.

N9. language.md:819 says a variable inside `Address` "stands for a mailbox type only"; 821 says a timed wait's variable is process-only, "a printed type marks it `+`"; the shell prints `standIn : (Bool) -> Address(a) receiving a` with no `+` and `pause : (Int) -> Unit receiving e+`. Fix: say which restriction `+` marks, and that an `Address(m)` in the type already shows it.

N10. language.md:706, "polymorphic where that type holds no function, foreign value, address or reply, `let empty = emptyMap()`; `let shared = spawn(fn() = cell(None))` is not": `emptyMap` is defined nowhere and no reason is given. Fix: split the sentence, define `emptyMap`, one example each way.

N11. README:19 `within = 5000` and README:24 `Address.call(counter, Get, 1000)` with no unit, and `Get` passed as a function unexplained. Fix: one clause naming the milliseconds, one saying `Get` builds the request.

N12. README:80, "pays for the question with a mark in a process's own state at each timed wait, call and callback from foreign code", repeated at why.md:15; why.md:340 sends a newcomer to `docs/design/runtime.md` and "the look", never explained. Fix: "finding it costs a running program almost nothing", the mechanism left to the report.

N13. README:74 and why.md:3, "six claims, four of them with a program and one with its file": a count without what it counts. Fix: "four with a program, one with its configuration file, one with the report".

N14. README:78, "Two nodes are two files". Fix: "Two nodes are two configuration files, each naming the other…".

N15. Code used before the text says what it is: language.md:188 `String.fromUtf8` answering an `Optional` and `Optional.withDefault`; 232 `fault(…)` and `Peer.spawn` in §1.4; 968 `Reply.process(reply)` "is the caller's `Process`" two sections before §5.2 says what a `Process` is; 1873 `Address(Supervisor.Msg)` with no sentence on `Supervisor.Msg`. Fix: a clause at each.

N16. guide §6.6, language.md:1922, "A call to the child that faulted, made after its fault, is answered by the group restarted whole": a client cannot know when the fault happened, and `send(store, Crash)` followed by a call always answered `None`, the request sitting in the mailbox the restart emptied. Fix: one sentence at §6.6.

N17. language.md:124 says `Io.show` prints a value "as its … construction is written"; the shell prints `Right(Get(key = "x")) : Either(String, Kvd.Command.Command)`, which cannot be pasted back outside the module; §1.1 says `Io.debug` "prints any value" while its type is `needs a.show`. Fix: print the qualified name outside the module, and say "needs a.show" in §1.1.

N18. `ern build main.ern` inside a directory whose `main.erc` was built from the parent says `main.erc holds E67.Main, not Main; name Main's source root with --source-root`, where removing the file is the plain fix. Fix: add "or remove main.erc" to the help.

N19. faq.md:105 opens on what other compilers do, "A warning is a rule the compiler states and does not hold…". Fix: open with "A program builds or it does not".

N20. language.md:2519–2521, tellings, intervals and the draw of two peers, and 2812, one sentence of about 90 words on `Proxy.start`. Fix: break 2812 into sentences.

N21. Wanted and not found: a way to split a string at its first separator (`String.split` plus `String.join` round-trips single spaces only); a sibling path such as `kvd.log.new`, `Path.withExtension` replacing the extension, so `Path(Path.toString(path) <> ".new")`; a line reader for a socket, lines framed twice with `Bytes.split` and `Bytes.indexOf`. Fix: decide each; a sentence in the guide for the path at least.

N22. README:99 asks for Erlang/OTP 29 on the PATH with no pointer. Fix: one line on where to get it.

### The language, apart

N23. Prelude type names are barred as constructor names: `Set`, the natural constructor for a SET command, refused, renamed `Assign`.

N24. One mailbox type puts a process's own events in its clients' protocol: the store's alarms and `Os.termination`'s `Terminating` share its type with the clients' requests, so keeping them out of what a client may send took a second type, `Inbox`, a `Request(…)` wrapper on every request clause, and an exported `start` handing out `adapted(spawn(…), Request)`.

N25. A restart empties the mailbox, so a test cannot just call after a fault; it waited with `monitorService` and a `receive` on the `Down`, which gave the test a type of its own.

N26. `after` is reserved and lost as a variable name, the error clear; every `Fs` call takes a timeout, a `waitMs` constant passed about a dozen times.

### Names, apart, with the word expected

N27 `Os.termination(wrap)` subscribes, `Os.onTermination` expected. N28 `Process.faults(wrap)`, `Process.subscribeFaults`. N29 `OrderedSet.Set` and `OrderedMap.Map` clash with the prelude's, `OrderedSet.OrderedSet`. N30 `Supervisor.Msg`, `Supervisor.SupervisorMsg` or `GroupMsg` as `Tcp.SocketMsg`. N31 `Supervisor.group(strategy, limit)`, `Supervisor.supervise`. N32 `Fs.makeFile`, an exclusive create, `Fs.create`. N33 `Fs.makeDir` makes the parents, `Fs.makeDirs`. N34 `List.last` with no `List.first`. N35 `RestartLimit(restarts, within)`, `within` milliseconds, `ms` or `withinMs`. N36 `Peer.setUtilization(x)`, `utilization`. N37 `Clock.monotonicMicros`, `monotonicMicroseconds`.

## L, the Erlang programmer

Read README.md, guide/why.md, tour/README.md with tour/1 to tour/8, guide/faq.md, guide/language.md whole and guide/deployment.md whole; ran the tour's chapters 2 to 8 on three nodes, deployment §8 end to end on a copy of examples/upgrade, and the probes below, under the reader's scratch directory, the machine's load about 37 on 8 cores from other jobs, so no timing claims.

L1. why.md:338 (also :336, README:80, guide §5.4 l.1394). Quote: "the runtime's look for one may be late but is never wrong … it reports no deadlock that is not one." A message that foreign code arranged to deliver later is not seen, a host timer or a host process the call started, which is how hex libraries answer and why.md:18 invites them; `ern run` faults such a program with `deadlock` about 0.5 s in, and the same program run as a node prints its line 8 s later. `L/hostproc` (a helper sending `{'Woke',7}` after 3 s): `ern run host_wait.erc` gives `HostWait.main faulted: deadlock`; `L/lf` (`timer:send_after/2` through a foreign fn declared `receiving MainMsg`): `ern run later_foreign.erc` deadlock, `ern run --config-dir ../solo later_foreign.erc` `woke with 7`. Fix: why.md:338 and guide §5.4 say that a delivery foreign code arranges for later is not seen, and that `ern run` and `ern test` fault such a program.

L2. why.md:96, faq.md:67. Quote: "So a mailbox type holds for messages from the host too … not a crash later in code that trusted it"; "a compiled `receive` never sees a value of the wrong shape". Guide §8.3 l.2833 says a foreign fn without `receiving` is trusted not to deliver into its caller's mailbox and "nothing checks that"; a foreign fn that sends `{'Inc', <<"five">>}` to its caller gets past `Inc(amount)` and the program crashes later inside `ern_show` with a host error (`L/sneak2.ern`: `Sneak2.main faulted: error:badarg / erlang:integer_to_list/1 / ern_show:by_type/4:49 / … / Sneak2.count:15`); `L/sneak.ern` gives `queued = 2`, two messages nothing can take. Fix: limit both sentences to returns and to addresses handed to foreign code, and say a foreign function's delivery into its caller's own mailbox is trusted, as §8.3 says.

L3. guide §6.5 l.1812, faq.md:19 ("good for its life"). No document says what a service binding names after its last restart: it names a dead process for the rest of the run, every call answers `None` at once, nothing escalates, `ern run` exits 0, so `Restart=on-failure` never restarts the node; in Erlang the failure escalates to the supervisor and the application. `L/exhaust.ern`: `Some(2)`, `faulted, restarted`, `None`, `faulted`, `None`, `None`, `main goes on with a dead service`, exit 0. Fix: one sentence in §6.5 and faq.md:19 saying what the binding is after the limit, and that the program goes on unless something monitors the service.

L4. why.md:100–123, the fragment at :120 upgrading the counter of :29–30, which runs under `restarting`; suspected trick. A restart runs the old `count` again, so the upgrade is undone at the next fault; tour:452 and deployment §5.3 say so, why.md does not; the tour drops `restarting` in chapter 6 so that chapter 8's move works. `L/revert/counter.ern`: `upgraded, after Inc(10): Some(2)`, the fault, `after Inc(10) again: Some(1)`. Fix: one sentence after why.md:123, citing deployment §5.3.

L5. guide §8.1 l.2591, why.md:12 and :159, tour:505. Quote: "`Peer.compute` draws two peers at random for each piece and spreads them"; "which spreads work with no central choice". With two peers, two drawn at random is always both, so the pick is the less busy at the last telling, the rule §8.1 says sends a burst to one peer, and the tour's chapter 7 is that case: in the reader's run all three computes went to foo and none to bar; `Peer.utilizations()` read `#("bar", 0.5, 1017)` for an idle bare node just after it connected. So the tour's "twice and bar's once, in this run" was luck. `L/scripts/tour.py`, `L/tour/foo.log` with three `counting the primes` lines, `bar.log` none. Fix: tour chapter 7 and §8.1 say spreading needs three or more peers, and that with two a burst within one telling goes to one node.

L6. guide §8.1 l.2447. Quote: "A node reads every module of its load path at its start, the directory of its program among it." The node reads the whole tree beneath that directory, and one stray `.erc` built elsewhere stops it, though the same program runs as no node: `cd L/r && ern run hello.erc` gives `hi`; `ern run --config-dir ../n hello.erc` gives `ern run: old/counter.erc holds Counter, not Old.Counter; remove it, …`, exit 1. Fix: §8.1 and deployment §5.1 say subdirectories are read, and that an `.erc` of another namespace there refuses the start.

L7. guide §8.1 l.2503, why.md:12 ("any node can run anything"). A spawned function's value "is a parameter, or a local it captures, and not a binding of its module"; a literal binding does cross, and a computed one fails at run time, not at build: `let limit : Int = 10`, `fn() = limit + 1` gives `Right(11)`; `let computed : Int = List.size([1, 2, 3])`, `fn() = computed + 1` gives `Left(NotLoaded)`, foo saying `the binding Main.computed has no value here` (`L/bind`). Fix: say which bindings have their value on a bare node, and that the rest fail as `NotLoaded` when run.

L8. guide §6.6 l.1918, faq.md:21. Quote: "A sibling that never waits is never restarted … The child that faulted waits meanwhile". In OTP siblings are killed and the restart is immediate; here a sibling busy in a long computation keeps the faulted child down, its callers getting `None` the whole time (`L/sup/busy.ern`, OneForAll: four `None`, `ms since the fault: 3003`). Fix: say that calls to the faulted child answer `None` until every sibling has reached a wait.

L9. guide §10 l.3201. Quote: "not a message that sits in the mailbox forever". The guide's §12 answer to 4.8(c) and §5.5's alarm paragraph say a message of the right type that no clause takes sits for the process's life, and L2 shows `queued = 2`. Fix: say the type stops a message of another type, not one that no clause takes.

L10. guide §10 l.3194. Quote: "`Address.call` is `gen_server:call` with a timeout". gen_server:call exits with the timeout or the callee's reason; `Address.call` answers `None` for both, "nothing of why" (faq.md:57). Fix: say so, and that `callForever` carries the cause.

L11. guide §5.2 l.1329, §10 l.3206. A `Down` "has no order with that process's own messages" gives up Erlang's guarantee that a process's last message arrives before its `'DOWN'`, and no document says Erlang made it; §4.4, §5.2, §6.4 and §8.1 each carry code for the lost order. `L/order/order.ern`: `the Down came first in 0 of 20000`. Fix: §10's bullet names the Erlang promise Ernest drops.

L12. faq.md:93 vs guide §10 l.3216. "a process's own table" vs "a table is state that processes share" contradict each other. Fix: one wording in both places.

L13. guide §2.9 l.591. "There is no time that means no limit", where `Address.callForever`, `Io.readLine` and a bare `receive` wait without one. Fix: scope the sentence to the system modules.

L14. guide §4.2 l.874. "never through a mailbox": on the host every message lands in the process's queue; a late answer is dropped (`L/late.ern`, `queued = 0`). Fix: "never through the caller's typed mailbox".

L15. guide §4.1 l.813 vs deployment §2.3 l.163. A send "returns at once, without waiting" vs "a sender waits only where … the host's buffer for it, 1 MB"; the language guide never names the exception. Fix: name it in §4.1.

L16. why.md:127 and the shell. The shell prints `Counter$1.CounterMsg`, but `send(old, Counter$1.Inc(1))` is refused with `illegal character $`; after a reload the old counter could not even be asked `Get` (`L/scripts/reload2.py`). Fix: say the `$1` names are printed only, and to bind what you will need before reloading.

L17. deployment §8 l.392; suspected arranged demo. Quote: "The counters go on with their totals, on the new code". Nothing in the walk shows it: no process ever sends to b's or c's counter, its type bound, so their totals are 0; `count2` is private, so from the ops shell `Code.running(Counter.count2)` gives `unknown name`; only `b: 1 moved` is shown (`L/deploy`, `L/scripts/ops2.py`). Fix: show a peer's total before and after, or drop the clause.

L18. tour:122. "A node's line … begins with the time": not at a terminal; guide §6.3 and deployment §1.4 say the time is written only to a file or pipe, and foo printed `the peer a connected` with no time at a terminal. Fix: add "where standard error is a file or a pipe".

L19. tour chapter 2 transcript, l.108–120, omits the `listening on 0.0.0.0:8654` line that `ern shell --config-dir a` prints before its banner. Fix: show the line.

L20. why.md:13 ("no shared secret"), deployment §2.2. Every node runs with `-setcookie 7c3f3228…` visible in `ps`, the same on every node of this build, and no document says what it is (`ps -eo args | grep -o -- '-setcookie [0-9a-f]*' | sort | uniq -c`). Fix: one line in deployment §2.2 saying it is the floor's public constant and grants nothing.

L21. guide §1.1 l.120. "says nothing, as in ML and Erlang": Erlang has no function types in which a function could say what it receives. Fix: drop "and Erlang".

### Closing words

Where L would close the page: README:83 ("not for an OTP application or a codebase of several languages"), where a shop with an OTP system ends its evaluation; faq.md:17 and :93 and deployment §6 l.301, no sys, no tracing, no observer and no remsh, and every lambda typed into the ops shell kept by the node for its life, where an operator closes it; deployment §5.1 l.240, a new minor release of `ern` or a new major release of OTP moving the whole fleet at once, so a fleet of "a laptop and two data centers" cannot roll its upgrades; guide §6.6 (L8) and §8.7, sockets pull-only, every accept and read needing a timeout, each socket its own reader process.

The first question no document answers, at why.md:18: how to use a host library that answers by message, an active socket, gun, httpc in async mode; only §8.3's negative sentence touches it, and L1 and L2 gave the answer.

What it showed that Erlang cannot do, all reproduced: a wrong-typed send and a receiving function called in a process of another mailbox type refused at build; a spawn on a node holding none of the program, its code shipped by hash; after a reload, the compiler refusing the new protocol to an old process, naming the version; a deadlocked test faulted with the waiting processes listed; a foreign return checked against its declared type; `Code.running` plus a door message moving a process on a node that never had the new code, its state kept.

What only restates what Erlang has, often with less: `restarting` a supervised child behind a registered name; `Supervisor` the OTP supervisor without a shutdown timeout and with cooperative restarts; `Address.call` gen_server:call answering `None` with no reason; monitor and Down with weaker ordering; upgrade by message the universal-server loop with a fixed state type, less than code_change; the WAN distribution inet_tls_dist with pinned keys, no epmd and no mesh, the 45–75 s silence window unsettable; `Os.termination` trapping the shutdown, `Code.running` check_process_code, `Process.status` part of process_info; credit windows and `Proxy` what Erlang already does.

What convinced: the tour ran line for line across three nodes, the input numbers, the error texts, the versions `Counter$3` and `$4`, the deadlock lines and `Right(17984)` all matching, only L18 and L19 off; the typed send and the mailbox refusal, code crossing to a bare node by hash, and old versions protected by the compiler are things no typed Erlang has delivered. L would try Ernest for a greenfield service on a few nodes owned end to end, whose host libraries answer calls rather than reply by message; not in production beside OTP until L1, L2 and L3 are stated plainly.

## M, the Gleam programmer

Read README.md, guide/why.md, the tour with tour/1 to tour/8, guide/faq.md, and guide/language.md and guide/deployment.md whole, at 0e37caeb; programs under the reader's scratch directory, `probe/` and `ground/`. Ran and found matching the documents: the README counter and its refusal; tour chapter 5's build and test with the deadlock lines; the chapter 1 shell session; the chapter 6 to 8 refusal, computeAt, move and compute on two bare nodes; why.md's sorted, color and unique; the foreign-return fault; §1.5(a); §8.2's store, desk and board on two nodes.

M1. why.md:11 and faq.md:47-53, against the guide's §12 answer to §4.8(c) (language.md:3253). Quote: "and a program can never send a server a message it does not take." A `receive` need not cover its type, so a request of the server's type that no clause takes compiles, waits in the mailbox for good, and its caller gets `None`; a Gleam actor's handler is an exhaustive `case`, so this mistake is a compile error there. The FAQ's "What does a typed mailbox catch, and what does it not?" never names it. Program `probe/reset.ern` (`CounterMsg` with `Reset(Reply(Int))` and no clause for it) prints `None`, then `Some(5)`, status 0. Fix: in why.md write "a message of a type the server does not take"; one line in the FAQ answer: a request that no clause takes compiles and waits (the guide's §4.8).

M2. language.md:2076 (§7.2); also deployment.md:205, tour/README.md:316 and language.md:2503. Quote: "`empty` is a binding of the module's, and has its value only on a node that loaded the module: a spawn or a compute on a bare node whose function names it is not started there"; deployment: "Two things never cross: a top-level binding's value…". False for the guide's own example: `export let empty = Stack([])` and `export let limit : Int = 7` both reach a bare node, `Peer.computeAt("foo", fn() = Stack.size(Stack.push(Stack.empty, 1)), 5000)` answers `Right(1)` and `Stack.limit` `Right(7)`; a binding `= Map.empty` answers `Left(NotLoaded)`. No document states which bindings cross. Program `ground/stack.ern`. Fix: state the rule as it stands, a constant initializer crosses with the code and any other binding stays with its node; pick an example that stays, as Tally's `Map.empty` does.

M3. §8.1, §9.3 and tour ch.7; no sentence anywhere. After `let below = 2000` at the prompt, `Peer.computeAt("foo", fn() = Counter.primes(below), 5000)` answers `Left(NotLoaded)`, foo logging "the binding $Session.below has no value here"; `{ let n = below; Peer.computeAt("foo", fn() = Counter.primes(n), 5000) }` answers `Right(303)`. The tour lives at the prompt for chapters 2 to 8, so this is the first experiment a reader tries. Fix: one sentence in §8.1 and in the tour: a prompt's `let` belongs to the shell's node, so send its value through a local.

M4. why.md:233, faq.md:87, language.md:2053 and 2163. Quote: "A requirement names `compare`, `negate`, an operator, or `show`". Only `+ - * / % <>` may be members; `fn D.<`, `==`, `>`, `!=`, `&&` and `needs a.<` / `needs a.==` are refused with "expected an operator, `compare` or `negate` after `.` instead of `<`", a message that calls `<` not an operator. Programs `probe/s.ern`, `s2.ern`, `r1.ern`. Fix: name the six operators in §7.2, and in the message.

M5. language.md:2192. Quote: "A field whose type has no `compare`, an `Optional(Int)`, is refused at the declaration". `type Slot = Slot(at : Optional(Int)) derives compare` compiles and sorts (`probe/p2b.ern`); a `Color` field is the refusal, "Slot.compare cannot be derived: Color has no compare" (`p2c.ern`). Fix: use a type of the program's own without `compare`, such as why.md's `Color`.

M6. faq.md:9. Quote: "What differs is how far the types reach: a function that receives names its mailbox's type, a `receive` is checked against it, every `send` against the address it reaches, a request carries a `Reply`…". Gleam's `Subject(m)` checks every send, `process.receive` answers an `m`, and `process.call` hands the request a reply subject; three of the listed items are Gleam's too. The real difference is the next paragraph (faq.md:11). Fix: list only what Gleam lacks: the function's type names its mailbox, `spawn` types the address from the function, and a `receive` reads only its own process's mailbox.

M7. tour/README.md:57 (and :3). Quote: "so a wrong send is refused before the program runs, and `count` runs only in a process of that type." The chapter shows only the refused `send`, which a Gleam `Subject` refuses as well; the half Gleam lacks is stated but never run. Fix: one more input, `fn other() : Unit receiving String = Counter.count(0)`, which gives "Counter.count needs mailbox Counter.CounterMsg, and the mailbox here is String".

M8. faq.md:33-39, against language.md §4.4 "A library that waits" (970-1026) and §5.2:1329. The one-mailbox answer reads as all gain; the guide shows that a library function that waits on its own messages needs a process of its own and a call, where a Gleam library would make a fresh `Subject` in the caller's process, and a `Down` has no order with the dead process's messages, which costs the `owed`/`Returned` bookkeeping in four programs. `probe/q3.ern` gives "collect needs a mailbox, and gathered receives nothing". Fix: one sentence in the FAQ pointing at §4.4.

M9. why.md:14, language.md:2161 and 339. `fn same(a, b) = a == b` infers `(a=, a=) -> Bool`; `fn less(a, b) = a < b` is refused ("the operand type of `<` is not determined"), and `needs a.==` is refused; from Gleam, where neither needs anything, the asymmetry trips the reader. `probe/p4.ern`, `r1.ern`. Fix: one sentence in §7.3: equality is no requirement but the runtime's own, so it is inferred and marked.

M10. language.md §1.2 and §9.3, and the shell's `:help`. `Counter.count(0)` typed bare runs the loop in the input's own process, and the prompt waits for it; with piped input it waited until a 30 s timeout; under `script`, C-c ended the whole shell with exit 130, losing the session (not confirmed at a real terminal, since the line editor did not engage under `script`). Fix: one sentence on what ends a running input.

M11. language.md:2767-2770. §8.2 shows only the failure path, `no store: NotListed`; the find that succeeds, the proxy and the end's lines are only stated. Run on two nodes they hold: "the counter is at 5", then 10 and 15, then "the end waits for 1 subscriber: Store.counter:6". Fix: show the two-node run, as §8.1 shows `foo computed 25`.

M12. why.md:298 and faq.md:89. Quote: "What a class, an interface or a trait would have added, a declared instance, a hierarchy, a dispatch decided as the program runs". A Haskell class has no dispatch at run time either, and "the caller passing the member as an argument the program never writes" is how classes are compiled; the difference that holds is the closed set of members and the member in its type's own module, which the FAQ does state. Fix: let that closed set be the line drawn.

M13. faq.md:13. The list of what Gleam has that Ernest lacks leaves out type aliases (refused, §2.3), string-prefix patterns (`"inc " <> rest` gives "expected `->` instead of `<>`"), and a language server (§9.4 has Emacs only). `probe/u1.ern`. Fix: add them.

M14. language.md:435. Quote: "`Int`, `Float`, `String`, and `Char` have one, and a type of your own gets one by declaring it". `Optional`, lists and tuples have one too (`List.sort([Some(2), None, Some(1)])` works, `probe/p3.ern`), and `derives compare` is the other way. Fix: "the prelude's types have one where their parts do".

M15. language.md:3060, and tour:511 ("`move` moves every counter of its node"). `:doc Code.running` says a process whose frame of `f` lies beneath the innermost 64 frames is not listed; the guide does not. Fix: carry that clause into §8.9.

M16. deployment.md:163. Quote: "returns at once, as every `send` does", then "a sender waits only where … fills the host's buffer for it, 1 MB". Fix: "returns at once unless …".

M17. language.md:120. Quote: "says nothing, as in ML and Erlang". ML has no send and Erlang has no types. Fix: drop "as in ML and Erlang".

M18. Sections too long for what they show: §7.3 "For the curious" (2360-2402) repeats what `largestOf` showed, only `map`'s `needs b.compare` being new; §8.1 "Many at once" (2543-2591) repeats §4.4's gather, `owed` comment and all; §4.4 is 1,535 words under a heading naming one function, its "Pacing" and "Fan-out" not about the call; deployment.md:49 is one sentence of about 110 words holding twelve refusals. Fix: cut "For the curious" to the `map` signature; point §8.1 at §4.4; give Pacing and Fan-out their own heading; make deployment.md:49 a list.

M19. `probe/ops2.ern` gives "fromList needs a.compare, and the record's type leaves the variable a undetermined; annotate it", where the fix is `needs a.compare` on the enclosing fn (`ops3.ern` compiles). Fix: the help names the `needs`.

### Chapter by chapter

README: the one thing Gleam lacks is shown with output, a receiving function refused in a process whose mailbox is another type; the other claims are bullets pointing on. why.md: the mailbox section shows the wrong-mailbox refusal and the foreign-return check (quoted, not run; run, the message is exact; Gleam's `@external` trusts the return), stated more strongly than shown (M1); the hash section shows the versions in the shell transcript, spawn and compute as fragments the tour runs; the WAN section is the least shown, a file and no run off 127.0.0.1; abstract types are Gleam's opaque type, the requirement and the module-filled record shown with output and the refusal; the deadlock is shown and convincing; the hash section is 784 words, most of it fragments. Tour: ch.1 shows only what Gleam also does (M7); ch.2, 6 and 8, code crossing to a bare node, the refused spawn of a type that carries a function, and the move with state kept, all new, shown, and ran; ch.3 a quiet reload; ch.4 `restarting` keeping the address, where Gleam gives a new pid; ch.5 the heaviest, doing five things, the test deadlock and the protocol refused across versions its best lines; ch.7 quotes the foreign check rather than showing it, and a fresh shell going straight to `Peer.compute` gets `Left(Unreachable)` with both peers up, which §8.1 explains and the tour avoids by the order of its inputs. FAQ: M1, M6, M8, M12, M13; the gen_server and supervisor answers dense but accurate. Guide: §0's first refusal is Gleam's too; §2's `let x <-` is Gleam's `use … <- result.try`; §3's effect polymorphism and operator members are real gains, `value + value` refused costing an annotation Gleam would not need; §4's call and `Reply` are Gleam's `process.call`, the costs shown honestly, the library that waits and a `main` that waits needing `receiving Never`; §5 has no `Down` ordering, which §10 states and four programs pay for, `adapted` being `select_map` turned around; §6's service bindings as top-level spawns Gleam cannot write; §8 all new. Deployment: precise and all new, honest that no shell attaches to a running node.

### The mailbox in the type, against a Subject

On the page it buys four things: a function's type says which process it may run in, checked at the call; `spawn` types the address from the loop, with no subject handshake; `receiving e` flows through higher-order types; a remote spawn's mailbox type is checked before it crosses. Its costs shown: a library that waits needs its own process; every process has one sum type, with adapted wrappers where Gleam uses a selector; `receiving e+` through every timed wait; a forgotten clause compiles (M1). For someone who has `Subject`, the gain at the type level is the README's one refusal; the larger gains are the deadlock check, code crossing and versions.

### A requirement as not a type class

Not convincing as "not a type class"; convincing as something much smaller: a closed, built-in set of members, the member declared only in its type's own module, always written and never inferred, supplied implicitly. `show` is the most class-like, every type having it while generic code must still say `needs a.show`. The line that holds is that no new one can be declared. The error messages are excellent.

### What convinced, and whether M would try it

Convincing, all run: the deadlock found and its waiting processes listed; a spawn onto a node with none of the code; a running counter moved to new code with its tally kept, on a peer that never had the code; the refusal to spawn remotely a loop whose type carries a function; the foreign return checked at the crossing. M would try Ernest for a program across two machines, where Gleam offers nothing, and stay with Gleam for a single-node service.

## U, the guide

Read all of guide/language.md, why.md, faq.md, deployment.md, style.md and tour/README.md against `git diff v0.4.0 -- report/`, and ran the consoles that teach a changed rule under the reader's scratch directory, the two-node runs on ports 18761 and 18762. These printed as shown, apart from the timestamp a pipe adds: language.md's money, faults, tasks, the §6.5 counter, lease, pair, largest, generic, members, sets, mixed, twice, pause, words, checks (with `Test.faults`), moved and bag; why.md's dead, color and the §11.2 reload session; tour/5's `ern test` with the deadlock grouping; the shell's `:type`, the member refusals and `:faults`.

### Defects, a false or stale statement

U1. A binding whose value is a constant now has that value on a bare node, and the guide still says it does not: language.md §7.2 line 2076 ("`empty` … has its value only on a node that loaded the module … a module meant for such work makes its empty value a function, `empty()`"), §8.1 line 2503 ("a program's own empty value, spawned with on a bare node, is a function"), deployment.md §4.1 line 205 ("Two things never cross: a top-level binding's value …"); lesser, tour §5 line 316 and language.md §2.2 lines 310 and 320. `Stack([])` is a constant (report §4.6), with its value wherever its form is and evaluated nowhere (§8.5, §8.7); the guide teaches a workaround no longer needed. `nodes/st/stack.ern` with `export let empty = Stack([])` and `export let limit = 1024 * 1024`: `Peer.computeAt("foo", fn() = Stack.size(Stack.push(Stack.empty, 1)), 5000)` prints `Right(1)`; `fn() = Stack.limit` prints `Left(NotLoaded)`, foo saying `the binding Stack.limit has no value here`. Fix: say that a constant binding has its value on every node, and keep the "make it a function" advice for a binding whose initializer computes.

U2. language.md §7.3 line 2192, "A field whose type has no `compare`, an `Optional(Int)`, is refused at the declaration": `Optional` now has a `compare` (§3.10, §9.3), and the report's §3.5 example changed to `Bool`. `type T = T(x : Optional(Int)) derives compare` builds; `type U = U(x : Bool) derives compare` gives `U.compare cannot be derived: Bool has no compare`. Fix: write "a `Bool`".

U3. deployment.md §1.1 line 36, a node refuses a directory "whose files anyone beyond the owner and the owner's group may write": since v0.4.0 the rule is anyone but its owner (§8.3). `chmod g+w a/ernest.conf; ern run --config-dir a` prints `ern run: a/ernest.conf may be written by others than its owner`; with `chmod g+w a`, `ern run: a may be written by others than its owner`. Fix: "that anyone but its owner may write".

U4. language.md §8.1 line 2593, "`Peer.setUtilization(x)`, `x` from 0.0 to 1.0 … A number outside the scale faults the caller": only a value below 0.0 faults (§8.7, E.27). `util.ern` prints `set 2.0` after `Peer.setUtilization(2.0)`; `-1.0` faults, `Util.main faulted: a utilization is 0.0 or above`. Fix: "`x` at or above 0.0 … a number below 0.0 faults the caller".

U5. deployment.md §6 line 299, a trace "names a received unit `ern$3`, which tells you the code arrived from a peer (report §11.2)": §11.2 now says a trace names a received definition as the sender's build does. `nodes/sp.ern` spawned on foo: `Sp.main:8 faulted: division by zero, spawned by the peer a`, then `erlang:'div'/2`, `Sp.heavy:2`, `Sp.work:5`, nothing naming `ern$N`. Fix: drop the `ern$3` clause; `, spawned by the peer a` is what tells.

U6. language.md §8.1 lines 2486–2491: `ern run --config-dir a square.erc` first prints `listening on 0.0.0.0:8654` (§8.7), which the console omits while showing `the peer foo connected`; with `ern run --config-dir foo &` in the same terminal, foo's lines land there too, `listening on 127.0.0.1:8655`, `the peer a connected`, `the peer a ended`. Fix: add a's `listening on` line, and show foo's lines or run foo in its own terminal as the prose says.

U7. tour §2 lines 108–122 and language.md §1.4 lines 228–238: `ern shell --config-dir a` writes `listening on 0.0.0.0:8654`, then the banner, before the first prompt, and both consoles show neither; tour line 122 says "A node's line, there and in the shell, begins with the time; the tour leaves it out", where at a terminal no line carries a time (§11.2). Under `script`: `listening on 127.0.0.1:18761`, then `Ernest 0.4.0-dev. …`, no time. Fix: add the two lines to both consoles, and cut the tour's sentence about the time or say the time appears only where standard error is a file or a pipe.

U8. why.md *A deadlock is found* line 338, the look "may be late but is never wrong: a process it cannot see into … is read as able to deliver, so it reports no deadlock that is not one": §8.6 now says a foreign process the runtime did not start counts as one that may deliver only while a monitor of it stands, so an unmonitored foreign process holding an exposed address can deliver after a deadlock fault. Fix: qualify "never wrong" with that exception, citing §8.6.

U9. language.md §8.1 line 2497 and why.md line 159, a compute's fault faults the caller "with its cause … as if `heavy(3, 4)` had faulted here": the cause now carries the peer and the trace gains the caller's frame (§8.7). `bad.erc` on `a` prints `Bad.main faulted: division by zero, on the peer foo`, the trace ending `Bad.main:5`. Fix: "faults with its cause followed by `, on the peer foo`, the crossed trace followed by the caller's frame".

U10. language.md §2.5 line 435, "`Int`, `Float`, `String`, and `Char` have one": exhaustive at v0.4.0, where now `Optional`, `Either`, tuples and lists are ordered where their components are (§3.10, §9.6) and `derives compare` gives one too; it contradicts §3.6 line 766, which orders tuples. `opt.ern`: `Some(1) < Some(2)` true, `compare([1, 2], [1])` `Greater`, `List.sort([Right(1), Left("a")])` `[Left("a"), Right(1)]`. Fix: list the prelude's orders as §3.10 does, and name `derives compare`.

U11. language.md §3.3 line 724, "a mailbox type nothing fixed is `Never` … (report §4.6)": §4.6's rule has three cases, an effect variable left as a function type's effect is none, left as a type argument it is `Never`, a process-only one is a type error, and the guide states one. `eff.ern` with `let p = twice(fn(x : Int) = x)` at top level builds and runs; `eff2.ern` with `let ws = List.reverse([waiter])`, `waiter` a timed wait, is refused, `the type of ws, List(() -> Unit receiving e+), is not determined…`; at the prompt `let p` is refused as undetermined. Fix: state the three cases.

### Matters of clarity

U12. deployment.md §3.4 line 195, "It must listen, since it never dials": code spawned or computed on a bare node can reach other peers through `Peer` (§8.7), and the report dropped the reason. Fix: "It must listen, or no peer could reach it".

U13. language.md §4.4 line 913 and §8.2 *A loss* lines 2780–2782: the list of `callForever` causes omits `callee ended with its program`, new in §6.6, §7.4, given when the callee's node ends in order. Fix: add it.

U14. language.md §6.5 line 1814, "`Address.callForever` would fault the caller with the same cause": the cause is the callee's cause and its site, `a negative amount, the fault of the callee Counter.start:9` (§6.6). Fix: say so, as §4.4 does.

U15. language.md §8.3 line 2834, "a message of the wrong type from foreign code faults its receiver on delivery": only a message sent to an address exposed to foreign code is checked; one foreign code sends by the host's identity is the foreign side's promise (§4.7, §8.4), which why.md line 94 and faq.md line 67 say precisely. Fix: "a message foreign code sends to an address the program gave it".

U16. language.md §5.5 *Where the function runs* line 1438: the new rule is not taught, that in an adapted address's function and in a wrap `self()`, `Process.current()` and `monitor` are those of the process that owns what the function opens, the sender, the target or the kept process (§6.5, §6.9). Fix: one sentence there.

U17. language.md §7.1 line 2035, `ern test`'s lines are "passed, failed with its text, or faulted with its cause": §11.2 adds `killed`. Fix: add it.

U18. language.md §6.3 line 1702, the runtime's frames kept only "where the runtime itself failed": E.21 keeps them for a foreign function's raise too. Fix: "where the cause names a host error, a failure of the runtime or a foreign function's raise".

U19. deployment.md §5.3 line 254, "A service under `restarting` … is not moved so": it is moved by the message and returns to its old code at its next fault (§6.9), as tour line 452 says. Fix: "is moved only until its next fault, when the restart runs the old code".

U20. deployment.md §4.3 line 224, "`--libs-dir` names the libraries' root of": `--libs-dir` names a directory of the host's applications, each one's `ebin` added (§11.2), and "libraries" reads as Appendix G's. Fix: "or `--libs-dir` adds each application's `ebin` from".

U21. language.md §4.1 line 817, "`fn stop() = kill(self())` is a `() -> Unit` (report §4.5)": the unannotated rule with this example is §3.9's. Fix: cite §3.9.

### Outside the guide, seen on the way

U22. report/library.md line 608 (E.18): an edit spliced into a code span, "so `Process. An operation on a socket or a listener is a call on its process, … `callee was closed` for one the program closed.live`, `Process.status` …". Fix: end the sentence after `Process.faults` include them, and put the new sentence after it.

U23. report/toolchain.md §11.6: the example "a member `a.-` before a bitstring's `>>`" names a member in an expression, which §4.5 and Appendix A now refuse. Fix: another pair of tokens that would run together.

U24. Runtime: a computed function compiles `/` differently on the peer. `cmp/cmp2.ern`, `fn heavy(a : Int, b : Int) : Int = a / b` computed on foo gives a trace of `erlang:'div'/2`, `Int./:52`, `Cmp2.main:5`, `heavy`'s frame gone and a stdlib frame in its place; the same function locally (`dv.ern`) gives `erlang:'div'/2`, `Dv.heavy:2`, and a `100 / n` computed on foo gives its own frame. So the arrival seems to compile a two-variable `/` as a call of `Int./`, against §9.6, which says the operator is the runtime's own operation, and §11.1. Undiagnosed.

## C, part 1: the compiler's front end and middle

Read over `git diff 1329d1d2 -- erl/lexer erl/parser erl/formatter erl/checker erl/emitter erl/shared` at 0e37caeb; programs under the reader's scratch directory, a probed copy of ern_format in `probe/`.

### Defects

C1-C1. §6.3 and the checker disagree on which types a receive guard may order: `guard_order/3` (ern_typecheck.erl:4990) says "a `receive` guard orders only Int, Float, String, and Char", where §6.3 (language.md:708) says guards order "the types whose `compare` §9.6 provides", which now includes lists, optionals, eithers and tuples, whose compare is a call a guard may not make. `receive { l when l < limit -> Unit }` with `l : List(Int)` or `#(Int, Int)` is refused (t4/x1, x2). Fix: §6.3 names the four types the runtime orders, as the code does.

C1-C2. Appendix H states where an effect variable is written `none` in fewer places than the code writes it: `given_type/2` (ern_canonical.erl:745) applies it to a lambda's type (985), `Address.call`'s answer type (917), an operation's `{runtime, Type}` (1018), a `let`'s type and a `<-`'s type; Appendix H states it for a `let`'s and a `<-`'s alone, and these hashes cross nodes. Fix: Appendix H states the rule for every type the checker gives a node.

C1-C3. The alias help writes a fix that does not compile (`alias_help/2`, ~383): `type Words = List(String)` gets "is written type Words = Words(List)", which is refused, "List takes 1 type argument, not 0"; `type Pair = Optional(Int) | Other` gets `type Pair = Pair(Optional)`, dropping the argument and the other constructor (t4/z1–z3). Fix: write the constructor's field into the held type, `Words(List(String))`, or give the help only to a constructor with no fields.

C1-C4. The no-compare help offers `derives compare` to a foreign type (`no_member/6`, the `{own, Name}` help): `compare(make(), make())` on a `foreign type Handle` gets "give Handle a compare, `derives compare` on its declaration or `fn Handle.compare`" (t4/ft). Fix: for a foreign type, name `fn Handle.compare` alone.

C1-C5. A member written in a type or a pattern is told it is in an expression: `qualified/4` (ern_parser.erl:793) serves types, expressions and patterns and calls `member_written/3` for all; `fn f(x : Int.+)` and a pattern `Int.+` get "`Int.+` names a member, which an expression reaches through `+`" (t2/r1, r2). Fix: raise `member_written` on the expression path only.

C1-C6. §4.9 (language.md:473) quotes "`zero is not a member: … (report §4.8, E.1)`", which the parser's `member/1` writes without the citation (t4/y1). Fix: drop the citation from §4.9.

C1-C7. Two exports have lost every caller: `ern_types:elided/2` (386), since `never_in_no_value_position` went, though this diff edited its comment; `ern_types:format_pair/3` (596), `unify_message` calling `format_pair/4`. Fix: remove both.

### Kept because nothing broke

C1-C8. The formatter's check that keeps two tokens apart never fires: `reads_with_previous/2` (ern_format.erl:862) lexes the two tokens at every closing bracket; its one case was a member, `<<a.- >>`, gone with the members, `apart_test` losing its case. The probe over 131 .ern and 84 .md files called it 19,224 times and it returned true 0 times. Fix: remove it and the call at 839, or give it a case that occurs.

C1-C9. `#e_member{}` serves only the derived compare: two `infer(#e_member…)` clauses (4551, 4562) and `field_compared/1` (3477), canonical `expr_form(#e_member…)` to `{member, Supply}` (ern_canonical.erl:976) with Appendix H's form, the emitter's `expr_form({member, …})` (951) and `callee(_, {member, {known…}})` (1462). It existed because `a.compare` was written in source; the prelude's `compare` reaches every order with the same pending supply through `member_applied`. Fix: the derived compare calls the prelude's `compare` and the machinery goes; the forms change, so the form version moves.

C1-C10. The rule that a declaration with a requirement binds no name of its type variables has lost its reason (`binds_no_type_variable/1`, 2147; §4.9, language.md:479): it existed so that `a.compare` in a body named the member, and now `a.compare` names no member anywhere, `written_member/2` refusing it. Decide: drop the rule from §4.9 and the checker, or state the reason it still has.

C1-C11. ern_supervisor_tests.erl:243, `peekUntil`, `Address.call(c, fn(r) = Peek(reply = r), 1000)` with a retry on None: both `Restarted` are heard first and a call after `Restarted` reaches the new run, so the retry's reason is gone and 1000 is a chosen number. Fix: `Address.callForever`.

### Style

C1-C12. One foreign declaration crosses modules as three tuple shapes: `{QualifiedName, Scheme, HostModule, HostFunction, Printing, Source}` in ern_canonical.hrl:33, ern_compile.erl:176 and :333, ern_code.erl:225; ern_arrival uses a five-tuple and a six-tuple in another order; the hrl's prose omits Printing. Fix: a record `#foreign_function{}`.

C1-C13. Four-part tuples within one module: ern_typecheck.erl's fill `{Written, Namespace, Missing, Binder}` and `host_names/1`'s `{Span, MemberOf, Name, Kind}`. Style: a value of more than three parts is a record.

C1-C14. `?IS_USEROP(Operator)` (ern_parser.erl:21) is a guard macro, where style says macros are named constants alone, and expands into a guard sequence; the same set is written in ern_typecheck.erl:5429–5431, `ern_prelude:is_member/1` (733) and ern_emitter's `is_primitive(['Int', _])`. Fix: `-define(USEROPS, [...])` with `lists:member`.

C1-C15. ern_bound.erl chains two conditions before `fail` with `orelse` in `capture_crosses`, `result_crosses`, `mailbox_crosses` and `declared_running`. Style: two conditions are a `case`.

C1-C16. New comments cite the review's finding IDs (X1/X5/X7–X9/X14/X15/X17/X20/X26, P2, K13, C2–C4, "C2's `make`", "P's `twice`", "K's `mkWaiter`", B-C3, N25 in ern_typecheck_tests and ern_emitter_tests) and "feedback 159" and "feedback 163" (ern_emitter_tests, ern_restart_tests), where findings.md is gone and feedback entries go once decided. Fix: cite the log entry.

C1-C17. `#fence{}` (ern_fence.hrl) and `ern_parser:fenced/1` recur across ern_parser, ern_format and ern_examples with no glossary entry.

### Stale comments

C1-C18. ern_ast.hrl:43 says "Appendix A's Member", now `Need`; ern_typecheck.erl:6587 `written_plain/3` says "a module's own type, constructor or member", where a member is no longer written; ern_bound.erl:99–102's Scope comment omits the new `{named, Declared}` entry; ern_typecheck.erl:2550's comment on the result annotation describes `result_origin` above it; the `binder` set for a top-level `let` (2355) is never restored, harmless left-over state.

### Names

C1-C19. `Bound` in `let_binding/2` (5879) holds an Env, while `bound` is also the pattern's names, unification and `bound_names/1`, and the glossary's Bound is §3.11's; the `annotated` field of `#deferred_operator`/`_selection`/`_guard_order` holds the local to annotate and reads as a boolean; `#fence{lines, content}` both hold the content's lines, `lines` to be `written`; `ern_types:in_value_position/2` reads the per-variable mark while `value_variables/2` is structural, `own_type/2` reading as a contradiction; `chosen_annotation/2` and `ern_types:format_annotation/2` do one job two ways; `fences(Lines, Text, Written, IsLaid)`'s `Text` and `Written` are funs named as values; `declared_running` reads a scheme's variables through a printing state.

### Diagnostics

C1-C20. `Foo(1) < Foo(2)` gets "`<` is not defined on Foo" with no help, while `compare(Foo(1), Foo(2))` and `#(Foo(1), 1) < …` get "needs Foo.compare, and Foo has no compare" with a help (t2/f1, g1, g3), and the prelude page says `compare(true, false)` is refused "as `true < false` is", yet the two differ (g4, g5); `no_member`'s `{other, compare}` help restates its message, and for a function type says to hold it in a type that declares `compare`; code quoted unevenly in new helps (`type Word = Word(String)`, "write a; the mark is written…", "as List(a=) or (a=) -> Bool", "write List.reverse" without backticks); `calls/2` writes "`.+` names a member" after an expression that is not a name, `f(x).+`.

### Shorter and clearer

C1-C21. `Marks` threaded through every clause of `type/2` (ern_parser.erl) to pick one help line; `specifiers_help/0` reverses its list twice; a fence's line count computed in `headings/4` and in `laid_out_fences/3`; the `lets = []` test made in `ern_compile:interface/5` and `with_terms/3`; the tuple compare in `supply_form({tuple…})` calling `erlang:element/2` per component; the `{named, Declared}` entry in ern_bound used only for `Code.running`'s help while a spawn of the same local still says "a function that came as a value".

### Low, or outside the diff

C1-C22. `ern_parser:fenced/1` claims CommonMark 0.31's fenced blocks but ignores container blocks, none existing today; `ern_prelude:is_member/1` answers true for `Address.compare`, `Reply.+` and the like, `member_types/0` holding every type whose namespace the prelude fills; outside the diff, `fn g(f : () -> Unit receiving e) : Unit = f()` gets "type variable e in the annotation is used as none" spanning the whole declaration with no help (t4/rr1), and `fn f(x : a=)` gets "expected `)` instead of `=`" with no help (t2/q2).

Held: tuple, list and Optional compare and sort, an own `Foo.compare` declared after its use among them; uses of a failed definition drew no second error; the fills checked against annotations.

## C, part 2: the runtime and the command line's and shell's Erlang, with S

Read the diff 1329d1d2..HEAD for erl/runtime and erl/cli, functions whole with callers, and the changed bin/ern lines, at 0e37caeb; trials under the reader's scratch directory.

### C: defects

C2-C1. A hidden first run of the program: `ern run` with `--config-dir` among the program's arguments runs the program twice and the first run eats standard input. bin/ern:95-101 scans every word, the program's words after the .erc among them; ern_cli.erl:86-104 (`node_flags/0`) then runs the whole job, and as_node/5 (1219) throws `{node_flags, ...}` only when the job's own options hold config_dir, so when the word is only a program argument the branch is `undefined -> Run(#{})` and the program runs to completion inside the flags start, its output discarded, its side effects made, the real stdin read. twice.ern appends a line to ran.txt: after `ern run twice.erc --config-dir x` it holds 2 lines, after `ern run twice.erc` 1; `printf 'secret\n' | ern run reads.erc` prints `read: secret`, with `--config-dir x` after the file `nothing to read`. No test covers node_flags/0. Fix: in as_node/5's `undefined` branch throw `{node_flags, []}` when `{ern_cli, flags}` is set, or have the launcher look only at the words before the file; add a test.

C2-C2. A scan of every pending call on a restart's path: ern_rt.erl:1831-1832, `undelivered(Pid, _ExitReason) -> left_call(Pid), ...`, where left_call/1 (857) does `match_object(?CALLEES, {{'_', Pid}, '_'})`, a full scan. It fires at a restart or an end, where abandoned/1 kills every delivery to the process, deliveries another process started among them, whose starter gets `{'EXIT', Pid, killed}`, then held_ended or the clock's EXIT clause, then undelivered, then the scan; redundant, since killed/2 has already dropped the call. Measured: one left_call per restart in a probe with 1000 pending calls; each scan 1.4 ms at 10k rows and 11 ms at 100k, paid in the reaper or the clock. Fix: delivery_ended/1 ends with `{ern, killed}`, and undelivered calls left_call only where `is_host_end(ExitReason)`.

C2-C3. `say/2` now waits for standard error to take each line (ern_rt.erl:3522-3533), so the gateway (ern_gateway.erl:242, 354, 500, 503), the TLS verify fun inside the ssl connection process (ern_carrier.erl:342-367) and net_kernel's callback in ern_epmd block on stderr; stream_loop answers only after port_command returns, the port busy while it holds a byte. While stderr's reader is slow the gateway stops routing every frame and handshakes stall. Fix: an asynchronous say for the gateway and the verify fun, or decide that blocking is accepted and state it in runtime.md.

C2-C4. `ern_shell:own/0` returns `[none]` before the first input, against its spec `[pid()]` (ern_shell.erl:2348-2349). Fix: `[Pid || Pid <- [kept(input, none)], is_pid(Pid)]`.

### C: dead code and remnants

C2-C5. entry_end's `carried` clause is unreachable (ern_rt.erl:3653, `{{'Fault', Cause}, {ern, carried, _, Trace}}`), only a compute's own process on the peer exiting `carried`, the caller re-raising with `fault/2`; outcome()'s doc repeats the claim. Fix: drop the clause and the doc phrase.

C2-C6. ern_show's `"<foreign>"` branch for a `foreign_reply` cannot be reached (ern_show.erl:116-118), a foreign_reply being built only by ern_boundary:arm/3 after the shape check. Fix: `represented({foreign_reply, _, _, _}, _) -> "<reply>"`.

C2-C7. `ern_peer:picked/0` (346) survives only for tests, compute/3 calling pick/0 (355); the glossary still names it, one concept under two names. Fix: tests use pick/0, picked/0 goes, the glossary points at pick/0.

C2-C8. `ern_code:ground/1` and `grounded/1` (350/362) take a binding's identity whose name they ignore, ern_exchange.erl:586 passing a dummy name `{binding, [], Hash}`, a leftover of the `{term, QualifiedName, Hash}` key. Fix: `ground(Hash)` and `grounded(Hash)`.

### C: rules from a small toolchain, followed by every later field

C2-C9. The process row is a positional 6-tuple that crosses modules, `{Pid, Site, SpawnOrder, Root, Peer, Expected}`, some 20 patterns `{_, _, _, _, _, _}` in ern_rt plus test/ern_load.erl:92 and the tests, written by magic positions, `update_element(..., {4, Mark})` (1983, 2013), `{6, true}` (2201), `{2, Site}` (3776). Fix: a `#process_row{}` record with `keypos`.

C2-C10. A foreign declaration's six fields travel in two orders: `#recorded.foreign` and ern_code:declared/1,2 use `{QN, Scheme, HostModule, HostFunction, Printing, Source}`, the reach's Foreigns, ern_peer:foreign_lacked/1, ern_arrival and ern_exchange `{QN, HostModule, HostFunction, Scheme, Printing, Source}`, ern_peer:lacked_module/2 (~795) reordering one into the other, and the Calls form a 5-tuple without Scheme. Fix: one record, or one order.

C2-C11. A monitor's kind is encoded by nesting its wrap, `{asked, Asker, {service_monitor, Wrap}}` beside `{raw, Tag}`, unwrapped by recursive `unmarked/1` and `is_service_monitor/1` (ern_rt.erl:1744-1750). Fix: a `#monitor{wrap, asker = none, service = false}` record.

### C: copies

C2-C12. Five copies of "the root lies as many directories up as the namespace is deep", `lists:foldl(fun(_, Dir) -> filename:dirname(Dir) end, File, Namespace)`, at ern_cli.erl:495 (new in source_named/2) and 1404, ern_examples.erl:232 and 239, ern_code_load.erl:111. Fix: one `ern_build:root_of(File, Namespace)`.

C2-C13. A private directory is made twice in the same steps, ern_node:create/2 (74-79) and ern_examples:made_directory/1 (138-151), make_dir, chmod 0700, check it is empty. Fix: one helper in ern_build.

C2-C14. Three texts of one refusal under two names: `held_by_another/4` (ern_build.erl:138, 142) and `held_another/3` (152) build "X holds A, not B; …" three ways; ern_tty.erl:304 has an unrelated `held_by_another/1`. Fix: one function with the advice as a parameter.

C2-C15. Three ways to spell an option's long name: `option_long/1` (ern_cli.erl:287-290) restates the Spec, given_once's lambda (314) and parse_refusal's comprehension (243) each search the Spec. Fix: one `long_name(Spec, Key)`.

### C: names

C2-C16. `ern_rt:demonitored/5` (the reaper's, 1470) and `demonitored/2` (the clock's, 3192), two meanings of one name in one module; `ern_rt:noted/2` (809) writes a local call's CALL key and callee row where the glossary gives **Note** to another node's call; `ern_examples:placed/2` (202) uses the glossary's **Placement** word for doc blocks with their source lines; `ern_examples:started/2` (222) answers a line number; `ern_build:unheld/3` (124) answers `{Kept, Held}`.

C2-C17. The glossary contradicts the report on "Frame": docs/style.md *Trace* says "Not `Frame`, which is §8.7's", where E.21 calls a trace's lines frames, and the new code agrees with the report, `#example.frames`, `frames/2`, `framed/3`, `framed_at/3` (ern_examples.erl:364-389), `Frames(Trace)` in ern_cli, `waiting_frame/1` (ern_rt.erl:1644). Fix: correct the glossary.

C2-C18. A timer's message has four names against the glossary's "a timer's message is `deadline` in every module": ern_tcp.erl:500/504 `{read_timeout, Ref}` and `{write_timeout, Reply}`, ern_os.erl:350 `{Kind, Deadline}`, the clock's ern_rt.erl:3171 `fire`.

### C: comments and notes that no longer hold

C2-C19. ern_rt.erl:885, compute/4's comment says "Where being the two" with no `Where`; ern_rt.erl:2124, live_rows/0's comment omits Expected; docs/design/nodes.md:27 says a `#kept{}` holds "the messages waiting" where the field is `handed`; docs/design/runtime.md:64 says "a kill of a process of this node" where it acts only on a process the runtime started; ern_rt's `-receives({own_process, [... say/2]})` where a bare node's entry process calls say/2 through `say_limits/0` (ern_cli.erl:1541); ern_cli.erl:1759 `ended(Reason)` prints "faulted: ProgramEnd" or "faulted: Unreachable" for an end that met no fault, its comment naming only Killed and Fault.

### C: shorter and clearer

C2-C20. ern_arrival.erl:312-321 reads its accumulator positionally; ern_arrival's local `valued/1` and `ground/1` (406-414) reuse ern_code's two names with other result shapes; ern_exchange.erl:574-578 binds `Referenced` three times in one comprehension; ern_cli.erl:1177 calls `one_argument("", "one .erc or none", Rest)` with a dummy first argument.

### S: real exposure

S1. A program's arguments reach the launcher (C2-C1): untrusted program arguments, a wrapper passing user input, can trigger a second hidden run of the program with the real stdin attached, which takes the input meant for the real one and repeats every side effect. `printf 'secret\n' | ern run reads.erc --config-dir x` prints `nothing to read`. Fix as C2-C1.

Nothing else read lets untrusted input reach what it should not; the diff closes earlier exposures: a peer's kill frame reaches only processes the runtime started (ern_peer.erl:556); a peer's site text is escaped in fault lines and the gateway's "not loaded" line; a peer's fault answer is checked for shape and UTF-8 (answer_taken/1); names from a peer are escaped in trace lines; ern config writes ernest.conf and the certificate 0644 and the key 0600, and a node refuses group-writable files. The shell's history changed only in a comment; the C helper, the TCP shim and Os's program code are unchanged in the diff.

### S: hardening

S2. Carrier lines name a connecting node's handshake name raw, control characters included, ern_carrier.erl:515-516 and named/1 (452-459) on the "Invalid challenge" path; only a holder of a listed key gets this far. Fix: `ern_show:controls`.

S3. `is_source/1` (ern_exchange.erl:840) accepts any integer from a peer; `erl_anno:new({-1, -5})` raises badarg, so a negative line fails the arrival's compile, caught and answered Other. Fix: require `Line >= 1, Column >= 1`, so the frame is refused as faulty.

S4. The configuration directory's parent is not checked: owned/4 (ern_node.erl ~306) checks the directory and its files, not the parent; another user who can write the parent can swap the directory between all_owned/2 and the reads; ssh checks the path up to home.

## C, part 3: the Ernest code, the tests and the build, with E

Read `git diff 1329d1d2` over src/stdlib, src/shell, src/libs, examples, tour, tools, bin/ern, the Makefile and test/, each changed function whole, at 0e37caeb; programs tried under the reader's scratch directory. `ern format --check` passes on the changed Ernest; lease_broker's three console blocks match what `ern run` and `ern test` print; no tool ran slowly. Every exported declaration new since v0.4.0 in src/stdlib and src/libs ends with `since 0.5.0`: Clock.toString, Either.compare, List.compare, List.mapFold, List.sortBy, Optional.compare and Test.faults.

### Ernest: defects

E1. src/stdlib/clock.ern:59-84, `Clock.toString`: "one after the year 9999 faults, as the host refuses it". E.15 says "a time outside the years 0 to 9999 is written as the host writes it", where the host raises past 9999; the page has no `### Errors` section, which shape rule 6 asks of a function that faults; §7.4 makes an argument the host cannot take whole `Left(Invalid)` or `None`, not a fault; the cause is the host's term pretty-printed over several lines. `printf 'Clock.toString(253402300800000)\n' | ern shell` prints `fault: foreign function calendar:system_time_to_rfc3339/2 raised error:{badarg,\n …`. Fix: decide it in E.15 first, a check of the bound with a fault or an answer of Ernest's own, or the report stating the host's fault; then the Errors section.

E2. src/shell/shell.ern:1511-1525, `lineLoop`: in line mode `:faults` misses a fault reported while the session waited for that line, since `reportPending` runs only before the prompt and the report sits in the mailbox while `:faults` reads `state.faults`. `(sleep 2; printf 'let q = spawn(fn() = fault("late"))\n'; sleep 1.5; printf ':faults\n') | ern shell` prints `> no process has faulted` and then the fault's line. Fix: take pending reports again once `Io.readLine` returns, before `submit`.

E3. shell.ern:688 (`reported`) and :698 (`stampedLine`): `:faults` stamps a fault with the wrong time in line mode, the stamp being `Clock.now()` when the session takes the report, which in line mode is the moment the next line arrives; §11.2 asks for the time as a stamped line of `ern run`'s writes it. `(sleep 2; printf '{ let _ = spawn(fn() = fault("late")); Clock.toString(Clock.now()) }\n'; sleep 3; printf ':faults\n') | ern shell`: the input answers `…39.127Z`, `:faults` lists the fault at `…42.283Z`. E2's fix does not close this. Fix, a decision: line mode reads lines in a reader process of its own, as the keys are read at a terminal, or the report carries its own time (an E.21 change).

### Ernest: pages

E4. Every member's page, `:doc` and `:browse` show a call the language refuses: build/stdlib/list.md:68-72 heads `List.compare(left : List(a), right : List(a)) : Ordering needs a.compare`, and the same for Int/Float `negate` and `compare`, String/Char `compare`, Optional/Either `compare` and a program's own members (`:doc Shape.Point.compare`, which member_doc_test holds); `:browse Optional` lists `Optional.compare : …` (test/fixtures/session/basic.out:77) while Tab does not complete it; §11.4 heads a declaration "by its name as a caller writes it", and no caller writes a member's name. `printf 'List.compare([1], [2])\n:doc List.compare\n' | ern shell` refuses the call, then documents it. Fix: §11.4 states how a member is headed and listed, and `ern doc`, `:doc` and `:browse` follow. Beside it: §3.10 says List/Optional/Either.compare are "provided by its module as `List.<>` is (Appendix E.2, E.10, E.11)", and none of the three says so.

E5. src/stdlib/peer.ern:26-30: "The runtime's own first steps of a dial come beside that time, so an answer may come later than it by them"; nothing says what bounds those steps. The page restates §8.7; the fix is the report's.

### Ernest: names and clarity

E6. shell.ern: `State.own : Set(Process)` (57) is the shell's own processes, while `appended(path, text, own : String)` (1109) and `place(destination, own : String)` (1118) use `own` for the name of the screen's own place. Fix: `fallback` or `screenPlace`.

E7. shell.ern:710 `faultedLine(report)` and :724 `faultLine(down)`, two functions a letter apart, one from a FaultReport and one from a Down. Fix: `reportLine` and `downLine`.

E8. `:set output` became `:set rows` only halfway: `Settings.rows` and `Command.Rows` follow, Region keeps `outputRows`, `outputSized` and `tailRows`, the screen `SetHeight` and `height` (region.ern:33, 38, 132, 345; shell.ern:94). Fix: one word, `rows`, `SetRows`, `rowsSized`.

E9. src/shell/README.md:39: "`leave` ends the session, in either mode … `finish` takes the region away", where in line mode `lineLoop` ends by `leaveLines`, which calls neither, `leave` running in line mode only after a startup file's `:quit`; `leave` and `leaveLines` (1129, 1532) each repeat `waitForDeliveries(); reportPending(...)`. Fix: say which ends it in each mode, and one helper for the pair.

E10. examples/lease_broker.ern:323: `main` stands after the broker's and the client's helpers, which begin at :164, against guide/style.md's order. Fix: move *Program* after *Services*.

E11. lease_broker.ern:208-229, `takeBack`, is correct only because a `Restarted` reaches the broker before anything the client's new run sends (§6.9), which neither the comment nor *What to look at* says. Fix: one sentence.

E12. tour/7/counter.ern:83-86 and tour/8, `isPrime(number, divisor)` answers whether no divisor from `divisor` upward divides `number`, so `isPrime(9, 4)` is true; the comment says so, the name does not. Fix: `isPrime(n) = hasNoDivisorFrom(n, 2)`, with tour/README.md's block.

E13. examples/word_count.ern:85-89: `|> List.sort |> List.reverse` puts the words of equal counts in reverse alphabetical order, where `Entry`'s comment says "ordered by count and then by word"; no regression, the old `Entry.compare(right, left)` did the same. Fix: `List.sortBy(…, fn(entry) = #(-entry.count, entry.word))`, after checking the expected output the test holds.

E14. Doc wording: src/stdlib/code.ern:117 "since it runs in a process whose mailbox type it does not know" gives a reason, which shape rule 6 keeps out; test.ern:89 "the call `run`, the subject," brings E.0's jargon onto a page; test.ern:135-137 "the function a process `faults` starts runs, its process marked in its row as it begins" does not parse. Fix: reword.

E15. `Clock.toString`'s name: shape rule 3 has a conversion exist once and names a second policy by the policy; `Int.toString` already converts the same Int, and `Clock` has no type of its own. Weigh `Clock.rfc3339` when E1 is decided.

### Where the language made the work harder

H1. No stable greatest-first sort by a key that is not a number: `List.sort` takes no function, `sortBy` orders by the key's `compare`, and `-` reverses only a number's order, so descending text or a declared type needs `List.reverse`, which reverses ties, or a wrapper type with a reversed `compare`. `List.reverse(List.sortBy([#("b", 1), #("a", 2), #("b", 3)], fn(#(name, _)) = name))` gives `[#("b", 3), #("b", 1), #("a", 2)]`. Before, `List.sort(list, fn(a, b) = compare(b, a))` did it in one line.

H2. A test that needs a binding evaluated rather than made a constant has to hide its initializer: `"never run" <> " on the server"`, `2 + 3`, `99 + 1` (ern_nodes_tests.erl:2309, 2475, 3133, 3833, 4012, 5018; fixtures/peers/lonely.ern:5); nothing lets a program say "evaluate this".

H3. Outside the part: the refusal `sort needs (Int) -> Int.compare, and (Int) -> Int has no compare` reads as a function type whose result is `Int.compare`; `ern format --check tour` refuses every chapter's file ("path component `7` must be words joined by `_`") while `ern format --check tour/7` passes.

### Tests and build: defects

C3-C1. test/Makefile:341, `bench-library: $(EBIN)/ern_measure.beam named`, dropped `benched`, the one prerequisite that made `build/bench`, and ern_measure.erl:57-60 writes `build/bench/library.txt`, so after `make clean && make`, `make bench-library` measures the whole library and fails with enoent; read, not run. Fix: `filelib:ensure_dir(File)` in main/1, or the rule makes the directory.

### Tests and build: kept for a reason that has gone

C3-C2. ern_shell_tests.erl:5040-5054: `waits/1` and `wait_seconds/0` copy `ern_nodes_tests:waits/1`, their comment naming `ern_integration_tests:waits/1`, which the diff removed; `wait_seconds()` is `waits(1)`. Fix: call `ern_nodes_tests:waits/1` and drop both.

C3-C3. Libraries still named with `--load-path`: ern_guide_tests.erl:183-189 passes every library to `ern build` under the comment "a program that uses a library under libs/ has it on its load path"; ern_terminal_tests.erl:177, 208, 220 build and run snake with `--load-path ../build/libs/ansi`. Fix: drop the options and the comment.

C3-C4. test/Makefile:96-103: `deployment` and `tour` depend on `machines` for a node's port waited on by `ern_machine:answering/4`, where since 03ba0b7b neither calls ern_machine, both waiting on the listening line through `listens/2`; `answering/4` (279-320) keeps a deadline `Ms` its one caller passes as `infinity`. Fix: drop the prerequisite, the comment and `Ms`.

C3-C5. Comments added in the diff cite review finding ids where findings.md is gone: "the full review's S3" (ern_shell_tests.erl:356-357), "B11" (869), "B-C8" (3202), "feedback 159" (853); "G-B" (ern_deployment_tests.erl:676, ern_nodes_tests.erl:969), "K14" (ern_nodes_tests.erl:2876, 2950), "T34" (ern_integration_tests.erl:926). Fix: name the log entry.

C3-C6. ern_shell_tests.erl's move to counted waits stopped partway: 19 tests count with `waits(N)`, 147 keep `{timeout, 60|90|120, …}`, 16 terminal sessions use a literal `30` beside three that take `wait_seconds()`. Fix: count the rest, or say in the module's head why these stay fixed.

### Tests: copies, names, clarity

C3-C7. ern_style_tests.erl:65-72, `parser_fixture_test`, holds fixtures/bench/parser.ern to examples/repl.ern only from `fn tokenize` on; the type declarations (parser.ern:11-37) are copied and held to nothing. Fix: compare those too, or the bench builds the example itself.

C3-C8. Loops written by hand beside the shared helper: ern_spawn_costs.erl:87-139 (six), ern_restarting_costs.erl:47-63 and ern_foreign_costs.erl:127-131 write `fun Loop(0) -> ok; Loop(Left) -> …` where `ern_costs:looped/1` is shared; `ern_language_costs:looped/2` and `ern_rules_costs:launched/1` reuse `ern_costs`' names for different things. Fix: call `looped/1`; rename the two.

C3-C9. ern_last_run.erl, `moved_text/3`: `{Number, {Old, Before}, {New, Now}} <- Moved` binds the row's name as `Number`. Fix: `Row`, and `Reference` for `last` or `release`.

C3-C10. ern_nodes_tests.erl:3833 and :4012 split a literal without saying why, where other sites say "computed, since a constant has its value wherever its code is". Fix: the same line at both.

C3-C11. ern_docs_tests.erl, `module_named/1`, re-implements §4.2's path-to-namespace rule. Fix: `ern_namespace:namespace/1`.

C3-C12. fixtures/peers/desk.ern:222-226: `told/1` repeats `ended/1` (216-220) but for its constructor. Fix: one function from a `Down`.

C3-C13. bin/ern:29-33 runs the iconv check before the `--help`/`--version` case, so both refuse without iconv; the header's "hangs as it boots in one where its names are UTF-8" reads as the opposite of its meaning. Fix: move the check into the `*)` branch, and write "in one whose name is not UTF-8".

C3-C14. tools/paragraphs.sh:26 and :30 repeat the same `skip` test (low).

