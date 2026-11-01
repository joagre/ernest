# Findings of the release review before 0.8.0

The review of 2026-11-01 over commit `9237801b`, run as [`release_review.md`](release_review.md) says: the fresh clone built and ran `make test-full` green in 13 minutes 31 seconds; `make load` green; `make sections` empty; `make sanitize` not due, the helper unchanged since 0.7.0; `make bench` over the review's commit and `make bench-release` over the release's, recorded in the log's entry for the review. Nine readers, the principles reader P on the most advanced model and the others on the one below: K the cold reader over the report's diff since v0.7.0 and the argument's changed paragraphs, A the argument's reader, N the newcomer, L and M the Erlang and the Gleam programmer, U the guide's reader, C the code's reader with E's and S's questions, and F over the census of forms the plan's item 2 asked for. Each line names its reader and number; a line carries its decision and `done` once made. The readers' lists are under the lines, condensed; the whole lists stand in the session's scratchpad until this document goes.

## The lines

### The report's rules (fix, the session; one decided)

- K1 — §3.9 says a function that "calls a function that is not process-only" names no mailbox; one that calls a function receiving `Int` does. fix: "calls only functions that receive nothing". done 2026-11-01.
- K2 — §4.5 and §6.1 name only a `receive` as what makes a variable process-only; §3.9 names three ways. fix: "that is process-only (§3.9)" in both. done 2026-11-01.
- K3 — E.0 shape rule 8 binds every function that waits to `Left(Timeout)`, and `Clock.sleep` answers `Unit`. fix: the rule opens on a wait for another party, and names the sleep as the wait for a time alone. done 2026-11-01.
- K4, U3, C1 — a sleeping process shows `Receiving`, and no document says which activity a sleep has. decide: `Receiving` covers a `receive` and a `Clock.sleep`, stated at E.21's `Activity`, in `process.ern`'s page and in the deployment guide; no fourth constructor, since the runtime tells a sleep from a timed `receive` only with a book of its own, and every program that matches an `Activity` would pay a clause (principle 5). done 2026-11-01.
- K6 — rule 6's list is no instance of the test before it: an abstract value is written `<abstract>` every run, and a `Process` differs and is not listed. fix: the abstract value a reason of its own, and "holds an address or a `Process`". done 2026-11-01.
- K7 — E.15 never says that after `cancel` answers `true` no message comes, nor which side of the delivery's window `cancel` sees. fix: `true` and the alarm's message never comes; `false` where its message has come or is on its way, or the alarm had ended. done 2026-11-01.
- K8 — §4.6 refuses "a `receive` in it" of an initializer, which read literally refuses a lambda the initializer builds. fix: in its own body, outside its lambdas and local `fn`s. done 2026-11-01.
- K9, A7, H2 — a `Clock.sleep` in a wrap or in an adapted address's function: whose wait is it, and does a restart reach it? fix, stating what the runtime does: a function the runtime applies runs in a process of the runtime's own, or in the sender for an adapted address, so a wait in it is that process's; a restart asked of the recipient reaches the recipient's own next wait, a fault in the function is the recipient's (§6.5), and a sleep in an adapted address's function is the sender's time. §6.5, E.15 and the argument's 6.3. done 2026-11-01.
- K10 — §11.5's effect-error bullet leaves out the call of a function that receives. fix. done 2026-11-01.
- K11 — §3.10 writes `Alarm` where the clock's type is `Clock.Alarm`. fix. done 2026-11-01.
- K12 — §6.1 "a `receive` with pattern clauses", every `receive` having one now. fix. done 2026-11-01.
- K13, C8 — E.15's "a fault or a restart waiting in the mailbox" and "a fault met on a message's way": a restart is not in the mailbox, and the fault is an adapted address's function's or a foreign message's. fix: both sentences, in E.15 and `clock.ern`. done 2026-11-01.
- K14 — Appendix D's "raw bindings are module-local" against two exported foreign bindings. fix. done 2026-11-01.
- K15 — G.1's comment on `Ets.owned` lacks "and for a process on another node", which D's has. fix. done 2026-11-01.
- K16 — Appendix D cites E.28 for `made` and `owned`, which E.28 does not name. fix: G.1 alone, E.28 for the evaluator a table keeps. done 2026-11-01.
- A6 — §8.4's list of the waits a foreign fault reaches, and §6.9's list of where an asked restart runs, leave out `Clock.sleep` and a load's wait (E.28). fix. done 2026-11-01.
- P1 — §10 states two waits whose cost grows with the messages waiting, and a sleep is a third: 2 ms with an empty mailbox, 7 ms with 300,000 messages. fix: the sleep in §10's exceptions and the call's-wait bullet, and E.15 citing §10. done 2026-11-01.
- P2 — `receive { _ when false -> Unit | after ms -> Unit }` compiles and waits, so the refused wait for a time is written back by a dead clause. decide: refused; §5.9 makes a guard that is the literal `false` a redundant clause, with the redundancy error, so that a `receive` left with its `after` alone meets §6.3's help. Principle 3's own words, a clause the text alone shows cannot run; the literal alone, since evaluating guards is a slope the report does not start down. A rule of §5, so it waits its night: decided 2026-11-01, built 2026-11-02, after this release, as the plan's MVP 4.1 says. The log's *The Release Review Before 0.8.0*.
- P3 — §11.5 writes `skip : () -> Unit receiving m+` where the compiler prints `e+`. fix. done 2026-11-01.
- P4 — §0 principle 2's "pair each of a record's fields" describes the fill, not the pun of one field. fix: "pair a record's field with the declaration of its name in one namespace or with the name in scope that gives or binds it". done 2026-11-01.
- P5 — `Alarm` costs a program that never cancels `let _ =` at every alarm, principle 3 against 5, and the report does not say which won. decide: principle 3, a value dropped is written; E.15 states it. done 2026-11-01.
- P6 — process-only rests on one form now, `receive { _ -> Unit }`, and an annotation demanded instead would drop the concept. decide: kept; principle 3 puts the `receive` in the type, and the demand would be the first annotation the language requires of an effect. The log's *The Release Review Before 0.8.0*.
- P7 — §3.11 reads "the address of ... or an alarm", and §6.9's resource paragraph excepts the alarm silently. fix: `or an Alarm (E.15)`, and §6.9 citing E.15 for an alarm's end with its setter's restart. done 2026-11-01.
- P8 — Appendix D, the model library, binds two functions of the runtime's own that a library elsewhere cannot. fix: one sentence saying so where the reader meets them. done 2026-11-01.
- P9 — §6.3's guard operand does not say the variable may be the clause's own, bound by its pattern or `as`. fix: "a variable in scope, the pattern's among them". done 2026-11-01.

### The argument (fix, the session)

- K5, A5 — the preamble names the toolchain's revision of 31 October; it is 1 November. fix. done 2026-11-01.
- A1 — no step for `Clock.sleep` and none for an asked restart; 6.3 points at 6.2, whose argument does not cover a wait. fix: a (sleep) step, and section 5 saying a fault or a restart met at a wait is the running process's own and binds nothing. done 2026-11-01.
- A2 — 6.3 and the lemma state the process-only rule over patterns alone; §3.9 says "fixes no type", which a guard or a body may fix. fix: §3.9's words. done 2026-11-01.
- A3 — 6.4 states the deadlock rule over a function that returns what it receives, where §6.8 covers any variable mailbox type and faults only where nothing else can run. fix. done 2026-11-01.
- A4 — 6.4's "Nothing therefore reaches the entry process's mailbox before `main` runs" is false of a wrap's fault, and 6.4 names only two wraps. fix: "No value reaches"; a wrap's fault, a monitor's, an alarm's or a subscription's, is the entry process's, met at its next wait. done 2026-11-01.
- A8 to A12 — `sleep` listed among the primitives without a step; "waits so at `Never`" idle; "takes any message" without its guards; the `after` clause shown as required; 6.1's exception's reason. fix. done 2026-11-01.

### The code and the library's pages (fix, one agent)

- P10 — §6.3's help writes `Clock.sleep(ms)` with a placeholder where the parser holds the expression. fix: write the expression.
- C2 — the parser gives §6.3's text to a `receive` whose `after` comes first with clauses after it; the fault is the order. fix: §6.3's text only where `}` follows the `after` body; otherwise Appendix A's, the `after` clause comes last.
- C3 — the selection error's help "annotate a" at a receive pattern's variable names an annotation the grammar has no place for. fix: where the variable is a pattern's, the help names the enclosing function's `receiving` or a constructor pattern.
- C5 — a test comment names "a timed wait's" effect variable, a form this release removed. fix.
- C9 — the clock's request was renamed `AlarmAfter` to free the abstract type's constructor, against the style's rule that a request is the function it serves. fix: the request is `Alarm`, the constructor `Held(Foreign.Term)`.
- C10 — the emitter's comment says a nested selection is read "at no cost". fix: twice, and a selection of such a selection twice again.
- C11 — the positional-reply test's comment does not say the Erlang tests' strings are excepted, as the pun test's does. fix.
- C12 — `mailbox_type/2` has one caller and a constant argument since the after-only `receive` went. fix: folded into `clause_mailbox/2`.
- M16 — the bound-mailbox refusal's help for `Peer.spawn` names neither `Peer.computeAt` nor the adapted address, the routes the tour takes next. fix, the report's sentence first where §11.5 or §8.7 quotes the help.
- C1, with K4 — `process.ern`'s `Activity` doc and page name three activities without the sleep. fix.
- C6, C7, C8 — `clock.ern`: the garden-path sentence on `Alarm`, "ends until then", and "a fault met on a message's way". fix.
- C4 — `Utilization.schedulers` sets the host's flag, sleeps, and unsets it; a restart or a fault met at the sleep leaves the flag set for the process's life. fix: the page says so. The gap behind it, no form that runs as a wait is left by a restart or a fault, is `language_feedback.md`'s line 183.
- F5, F14 — 38 tests in the shell's and markdown's modules answer `Passed` from an `if` over equalities, with hand-made failure texts, where `Test.equal` over a tuple says the same. fix: the sites, and `docs/style.md`'s Ernest paragraph: a test that compares answers `Test.equal`, over a tuple for several values.
- F12 — five guards in `test/fixtures/peers/desk.ern` compare a variable with a literal the pattern could hold. fix: literal patterns.
- F13 — three lambdas only rename a function value, and the prelude's doc example for `adapted` is one. fix: the function bare.
- N20 — a missing `;` is reported as "unexpected type name `Io`". 4.4: the diagnostics reader's question, whether a user who made the mistake knows the fix.

### The guides, the README and the tour (fix, one agent)

- U1, L12 — the guide and the FAQ say a sibling restarts "in a `receive` or for a call's answer"; §6.9 names `Clock.sleep` too. fix.
- U2, N2, L2 — the guide cites §3.5 for `Clock.sleep`; the rule is §4.1's. fix.
- U4 — the guide's restatement of principle 2 misstates the pun's ground. fix, to §0's sentence as P4 leaves it.
- U5 — the guide never names `Clock.Alarm` or says `Clock.alarm` answers one, yet writes `let _ = Clock.alarm(...)`; §8.4's list of resources lacks the alarm. fix: one sentence where §5.5 first sets an alarm, and the alarm in §8.4's list.
- U6 — the guide gives a test's mailbox type and not a doc example's. fix: one sentence citing §11.2.
- U7 — "an alarm that has not fired" for `cancel`'s `true`; the rule is "neither fired nor ended". fix.
- U8 — the guide says an initializer may "wait a while" without naming `Clock.sleep`. fix.
- U9 — the pun is shown beside a named field alone; §5.6 shows it in an update and a fill and refuses `Some(=x)`. fix: `Person(..alice, =name)` in the session and one sentence on the refusal.
- M1, N1, N27 — "an address is the authority to reach a process, which is why `kill` takes one" and the FAQ's "by `kill` alone", while `Process.kill` exists and the guide uses it untaught. fix: §5.3 teaches `Process.kill` beside `kill`, and the two sentences read as §6.5 does, an address the permission to send and a `Process` the identity a `Down` carries, a monitor watches and `Process.kill` ends.
- M2 — the FAQ's "its members are a closed set no program adds to", two lines after saying a program declares members. fix: the operations a requirement can name are the closed set.
- M3, N18 — *Why Ernest*'s deadlock paragraph promises no false deadlock and then names one. fix: the promise limited to what the runtime sees, then the one case.
- M4 — the FAQ and the tour count a wrong-type send refused among what a library cannot do; Gleam's `Subject` refuses it too. fix: the list keeps the receiving function refused in another mailbox's process, the address typed by `spawn` and the `Peer.spawn` refusal.
- M7, N10 — the requirement's closedness is asserted and never shown, and "stands in its declaration alone" is opaque. fix: the two refusals shown in one session block, and the sentence saying a member is reached by its operator and is no value.
- M8 — *Why Ernest* line 61 makes five claims in one paragraph and uses "bound to its node" before defining it. fix: split, and the words defined at first use.
- M9, L9 — the README's sentences at lines 15 and 72 are chains of participles. fix: split at their turns.
- M10, L7 — the tour's sentence on `far`'s version did not parse, and the tour shows a site's `$N` and a type's before saying a site's number is the spawning version's and a type's an older version's. fix: one sentence in chapter 4.
- M11, M12, N9, M13, M14, N12, N13 — one ungrammatical sentence, one misattached clause, §4.4's last sentence with nine ways a callee ends inline, two deployment sentences, a hundred-word sentence and a three-case sentence. fix: each split or reworded.
- N4, N5, N6, N7, L10 — the README uses `Reply`, `answer` and `let far <-` before a word on them, never says what `None` from a call means, and "a program that is no node" is unclear. fix: half a sentence each.
- N8 — `needs` and `derives` act as reserved words but are not among the eighteen, and the guide never says they are read by position. fix: one sentence, §2.4's rule.
- N11, N14 — effect variables and `Never` are relied on before taught, and §7.2 relies on "compute" and "bare node" before §8.1. fix: a forward reference each.
- N16 — *Why Ernest* names `make bench`, which an installed `ern`'s user does not have. fix: name it as the repository's.
- N17 — "quiet for a while" is never given a length. fix: the rule §8.6 states, no forward progress possible, in place of the time.
- N19 — the FAQ's "a node of Erlang's own is no peer" is unclear. fix.
- N21, N22 — two claims open on what another system lacks. fix: Ernest's rule first.
- N25 — the guide does not say how a test compares several values. fix: one sentence, `Test.equal` over a tuple.
- L1 — the tour's chapter 8 and the guide's §8.9 and deployment §5.3 say a process a callee's fix hides from `Code.running` can be "moved by a message of its own type", which needs an address the program kept. fix: the sentence says so, and the tour says a fix inside the loop's reach hides the counters.
- L4 — the deadlock claim is shown on a bare `receive` against `gen_server:call`, and a program run as a node detects none, unsaid in the claim's paragraph. fix: the mutual `callForever` program with its trace, as a block the guide's test runs, and the node sentence beside the claim.
- L6 — the deployment guide does not say the 45 to 75 second silence is the protocol's and fixed, nor what the operator does meanwhile. fix: one sentence citing §12.5.
- L8 — the deployment guide's and the guide's site examples, `Counter.service:5`, name no program's site, and the entry process's site has no line, unsaid. fix: a site the example prints, and the sentence.
- L11 — a prompt `let` captured by a lambda sent to a peer fails with a bare `Left(NotLoaded)` at the prompt, the reason on the peer, unsaid. fix: the sentence.
- N23, L5 — the guide guards every result-and-monitor pattern against a `Down` overtaking the last message and never says when it can. fix: one sentence, that §6.4 promises no order, that on one node the host delivers the message first, and that across nodes either may come first.
- M5, N3, L3 — `README.md`'s "0.7.0 is the latest release" against the transcripts' 0.8.0. The release step's.

### Dropped, with the reason

- M6 — the counter and its refusal stand in the README, *Why Ernest* and the tour's chapters 1 and 2. dropped: each is a door of its own for a reader who opens one, the log's *The Claims, the README and the Tour*.
- M15 — `store.ern` teaches three things in 75 lines. dropped: the holder hand-off, `Os.termination` and the kept file are the one lesson of a service that survives its node's end.
- N24, F11, M's L3 — a `forEach` callback that spawns ends in `let _ = ...; Unit`. dropped: `forEach` takes `(a) -> Unit` so that no value is dropped unseen, principle 3.
- N26 — no string interpolation. dropped 2026-10-31, the log's *The Pun's Opening Round*, line 180.
- N28 — nine names a newcomer would spell otherwise. dropped: each was decided with its module, `adapted` in *A Wrap's `self` Is Its Recipient's*, the sockets' addresses in E.18, `span` and `indexed` in *One Name for Every Order*.
- N30 — a pattern takes no type annotation at the prompt. dropped: a `let` with its type is the form, §4.6; C3 fixes the help that pointed elsewhere.
- L13 — the WAN claim is shown on one machine. dropped: the deployment guide's test runs its commands end to end on one machine by design, and §8.7's code is the same on two.
- L14 — the cost of a message at each spawn and monitor is given as `make bench` and no number. 4.4: the cost analysis.
- F1, F3, F4, F8, F9, F10 — `let`, `#(`, `let _ =`, the pattern assertion, the clause block, the pin: each longer than Erlang's by a few characters and each decided by a principle the reader named. dropped, the log's entry for the review.
- F2 — `Test.Case(name = ..., run = fn() = ...)` against EUnit's pair. dropped: a `Test.case(name, run)` is a second spelling of a construction, E.0 rule 4.
- F6 — the lambda around a request of more fields. decided 2026-11-01, the log's *Ernest 0.8.0, a Small Release*.
- F7 — a value of several parts as a chain of `<>`. dropped: a format string is a library's work, E.0 rules 2 and 3.
- H1 — a malformed tuple from a peer makes a guard's field read false where a body's would fault. dropped: peers are trusted, §12.5.
- A's and C's `++` and the qualified `Supervisor.OneForAll`. dropped: `<>` decided in *List and Concat Operators*; a constructor of another module is qualified, §4.2.

## The census (F)

Of 13,055 lines in 184 files, 645 are one generated table. Eleven forms an Erlang programmer writes shorter, none of the pun's size: the largest, `let` before every binding, costs four characters a site and is principle 4's first token; the one for the review, the request lambda, was decided the same day. Three for the style are the lines above. By the plan's rule the census does not become a standing reader; its counts are in the log's entry for the review.

## Reader P's list

Three defects: §10 silent on a sleep's cost (P1); the dead-guarded `receive` that waits (P2); §11.5's `m+` for `e+` (P3). Seven matters: §0's sentence on a second spelling, which refuses what it refused and admits only the pun, "each" misdescribing it (P4); `Alarm`'s `let _ =` cost unstated as a decision (P5); process-only resting on one form (P6); "resource" naming a thing without a process (P7); Appendix D binding the runtime's own functions (P8); the guard's selection buying a `let`, the pattern's variable unsaid (P9); the help's placeholder (P10). Counts: reserved words 18 to 18; nonterminals 53 to 54; alternatives net +3; glossary 171 to 172; language primitives 5 to 5; E.15's functions 5 to 7 and types 0 to 1; §3.10's exact-equality types gain `Alarm`; §3.11's resource kinds 3 to 4; Appendix D's `foreign fn`s 8 to 11.

## Reader K's list

Ten defects, K1 to K10, and six matters, K11 to K16, all above; the argument's steps read against the rules it cites follow but for K5 and K9.

## Reader A's list

Seven defects, A1 to A7, and five matters, A8 to A12, above; the safety conclusions hold.

## Reader N's list

The program is a job scheduler, 335 lines in two modules, which runs at most `capacity` jobs at once in monitored workers, each attempt under a deadline by `Clock.alarm`, an overrunning worker killed and a failed job retried; it built at the first try, its four tests passed, and it ran. Three defects (N1 to N3), sixteen unclear places (N4 to N19), two claims that open on another system (N21, N22), five places the language made it harder (N23 to N27), nine names (N28), two notes (N29, N30).

## Reader L's list

Three defects (L1 to L3), eleven matters (L4 to L14). What Erlang cannot do, each run: the wrong-type send refused, the spawn on a bare node by hash, the foreign return checked, the deadlock found with sites and frames, a service find by type hash, `Code.running` by hash. Where they would close the page: the restart held up by a silent peer. What convinced them: their own mutual `callForever` program. Would try Ernest for a new small distributed service.

## Reader M's list

Five defects (M1 to M5), eleven matters (M6 to M16), three places the language made the work harder, two of them N23's and L1's twins and one the sort by two keys. The mailbox in the type buys the refused call and the typed spawn; a requirement is partly convincing as not a type class until its refusals are on the page. Would try Ernest for a small service across two machines.

## Reader U's list

Four defects (U1 to U4), five matters (U5 to U9), nothing against the language; eight rules checked and found right.

## Reader C's list

Five defects (C1 to C5), seven matters (C6 to C12), no real exposure and two hardening notes (H1, H2), two places the language made the work harder, the bracketed wait (C4) and a field read on a pattern's variable in a lambda bound by a block `let` (C3). Two leftovers of the after-only `receive` found (C5, C12), and four checked and not leftovers.

## Reader F's list

Eleven forms ranked (F1 to F11), four matters (F12 to F15), none a defect; the census above.
