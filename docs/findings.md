# Findings of the full review

The findings of the full review, run on 2026-10-04 as [`full_review.md`](full_review.md) says, on commit `d90a5b3`. Nineteen readers read side by side, each a fresh session given its brief and its files and nothing that argues for them, P and K on the most advanced model and the others on the one below, each in a scratch directory of its own. They handed in 570 findings. A line below is a finding's first line as its reader wrote it, with its place, by area; it names its reader's letter and number, and the parts of C and of E are numbered through, each as one list. Each reader's whole list follows the lines, as it was handed in. A line takes its decision, `cheap`, a milestone, `done` or `dropped`, when the list is worked, in the milestone the plan gives it.

The lines were triaged on 2026-10-04, each checked against the code, the report, the log and the plan, and each carries its decision after its reader's letter and number: `cheap`, with its size, S for a line or two, M for a function and its test or a paragraph, L for more; `dropped`, with the log entry that decided it or the evidence that it does not hold; a later milestone, with what it waits on there; or `question`, a design question taken with the user one at a time, which becomes one of the others when it is decided. A line marked "decided in triage" is a choice where the report was silent on what the toolchain does, stated here and in the report as it is fixed. After the decision comes the finding's first line, its place, and, after the dash, the fix, the question or the reason.

| Decision | Findings |
|---|---|
| `cheap` | 508 |
| `question` | 34 |
| `dropped` | 22 |
| a later milestone | 6 |

| Reader | Findings | Of which defects, or exposures |
|---|---|---|
| P, the principles | 19 | 4 |
| K, the cold reader | 22 | 8 |
| G, the register | 48 | 39 |
| U, the guide | 21 | 10 |
| N, the newcomer | 21 | 4 |
| D, the documents | 30 | 21 |
| C, part 1, the front end with the Emacs mode | 36 | 12 |
| C, part 2, the checker | 35 | 11 |
| C, part 3, the emitter | 31 | 11 |
| C, part 4, the runtime with its helper in C | 33 | 9 |
| C, part 5, the shell's Erlang | 40 | 21 |
| C, part 6, the rest of the command line | 33 | 13 |
| E, part 1, the standard library | 34 | 15 |
| E, part 2, the shell | 31 | 14 |
| E, part 3, the libraries, the examples and the tools | 43 | 23 |
| T, the tools | 34 | 20 |
| X, the diagnostics | 26 | 9 |
| S, security | 17 | 5 |
| H, the shell's guide | 16 | 7 |
| All | 570 | 256 |

## The report and its argument

### P, the principles

Defects

- **P1** `MVP 3.0`: `Peer.spawn` and `Peer.spawnMonitored` are named in ten places, listed nowhere, and a program may take the namespace `Peer` (§8.3 (language.md:733), §3.8, §3.11, §6.2, §6.7, §7.4, §8.7, §10; Appendix E has no `Peer` section) — Waits on MVP 3.0's `Peer` item, which adds `Peer`'s section with both types at the end of Appendix E and takes the namespace; the stale `Fault("peer unreachable")` Errors on `spawnMonitored`'s prelude page (erl/typer/src/ern_prelude.erl:333), left from when it took a `Where`, can go now.
- **P2** `done`: The fill `C(..N)` is a second spelling that only shortens, and the names it takes do not appear at the use site (§5.6 (language.md:470), §4.9 (language.md:376)) — decided with the user: the fill stays, and principles 2 and 3 say why (§0; the log's *The Full Review's Questions, One by One*).
- **P3** `done`: A constructor named like a standard library module takes the fill away, and `..Prelude.Set` reaches nothing (§5.6 (language.md:470), §4.2 (language.md:307)) — decided with the user: after `..`, a name of type names alone is a namespace, and `..Prelude.N` is refused (§5.6; the log's *The Full Review's Questions, One by One*).
- **P4** `done`: `needs a.show` reaches the bare variable alone, and §11.5's help asks for an annotation no annotation can give (Appendix E.1 (library.md:157), §11.5 (toolchain.md:93)) — decided with the user: `Io.show` and `Io.debug` state `needs a.show` (§9.4) and write any type whose variables the requirement names (E.1; the log's *The Full Review's Questions, One by One*).

Clarity

- **P5** `MVP 3.0`: Principle 3's sentence on top-level bindings does not cover §8.5: a binding no use site names still acts at start (§0 (language.md:38), §8.5 (language.md:764)) — Waits on MVP 3.0's item *When a module's top-level bindings run*, which decides with §8.7 whether principle 3's use-site sentence covers §8.5's evaluation of every binding at start.
- **P6** `done`: `let _ = e` of a pure `e` is accepted, though principle 3 says the compiler refuses what the text alone shows can have no effect (§0 (language.md:38), §5.4 (language.md:458)) — decided with the user: `let _ = e` discards a value whatever `e` is, and §5.4 says so (the log's *The Full Review's Questions, One by One*).
- **P7** `done`: A module's own qualified name is allowed where nothing hides it, while `Prelude.` is refused there (§4.2 (language.md:289, 307)) — decided with the user: a module writes its own declaration qualified only where a binding hides the plain name, and its own type, constructor or member plain (§4.2; the log's *The Full Review's Questions, One by One*).
- **P8** `done`: `kill` takes an `Address`, `monitor` a `Process`, and the report says why for one only (§6.9 (language.md:644), §9.5 (language.md:853)) — §6.5's address is the permission to send to the process and to kill it, and §6.9's reason for `monitor` reads with it.
- **P9** `dropped`: A declared operator member may answer any type, but a requirement's operator must answer the variable, so the one cannot meet the other (§4.8 (language.md:362), §4.9 (language.md:370)) — decided: *The Operations Specification Read*: a member's shape under a requirement is fixed at `(a, a) -> a` and a call at a type whose member answers otherwise is refused naming both, §4.9 already saying a function over another shape takes it as a parameter, while §4.8 keeps `-> R` by *The Members Family's Rules*.
- **P10** `done`: `Io.show` and `Io.debug` are the prelude's under a library namespace, and the shell's prelude listing omits them and `String.compare` (§9.4 (language.md:834), §9 (language.md:786), §11.2 (toolchain.md:44)) — §9.4 lists `Io.show` and `Io.debug` apart, with their restriction, §9's sentence names the process functions, and `:browse Prelude` lists them and `String.compare`, which the prelude's table gained.
- **P11** `done`: Five system modules name no primitives, though E.0 rule 1 says each module's section names them (Appendix E.0 rule 1 (library.md:120); E.15, E.17, E.18, E.21, E.23) — E.15, E.17, E.18, E.21 and E.23 name their primitives, held by ern_prelude_tests' primitives_test where they are listed.
- **P12** `done`: `with m` on a body that needs no process is a second spelling of a pure signature (§3.9 (language.md:245), §11.5 (toolchain.md:95)) — decided with the user: an effect variable that names no parameter's effect is written only where the body acts through a process, and refused otherwise (§4.5, §3.9; the log's *The Full Review's Questions, One by One*).
- **P13** `done`: Appendix A reads `a.compare` by the enclosing signature, which no token shows (Appendix A (language.md:971)) — Appendix A says `a.compare` parses as a selection, which §4.9 makes the member.

Rules that buy little

- **P14** `dropped`: §6.9's second paragraph, the restart a supervisor asks for, exists for Appendix E.22 alone (§6.9 (language.md:648), E.22 (library.md:549)) — decided: *The Supervisor's Restart on Request Stays Its Own* and *The Rules That Exist for Another*: the restart a supervisor asks for is kept so a child keeps its address, and E.22's three private primitives are named in E.22, the finding's own fix keeping the rule.
- **P15** `dropped`: §8.7, code shipping, exists for `Peer.spawn` alone, which is not there (§8.7 (language.md:772), §10 (language.md:894)) — decided: *The Rules That Exist for Another*: the peer sentences, §8.7 among them, are kept unread, each costing a program without peers nothing, and are MVP 3.0's to build or cut.
- **P16** `dropped`: `export` is required on `abstract type`, where it says nothing (§4.4 (language.md:315), Appendix A) — decided: *The Rules That Buy Little*: `export` on every abstract type keeps one word for every export, a private abstract type being `type` written otherwise (P1-41).
- **P17** `done`: `needs` and `derives` are reserved where no identifier can stand (§2.4 (language.md:96), Appendix A) — decided with the user: `needs` and `derives` are words read by position and identifiers elsewhere; §2.4 counts eighteen reserved words (the log's *The Full Review's Questions, One by One*).
- **P18** `dropped`: `Prelude` and the shadowing of prelude names exist for shape rule 7 (§4.2 (language.md:307), E.0 shape rule 7 (library.md:136), E.25, E.26) — decided: *`Prelude` Names the Prelude*: shadowing a prelude name, reached past it by `Prelude.`, was kept over forbidding the shadowing, which would take `Close`, `Timeout` and `Other` from every program; the finding's own fix keeps them.
- **P19** `dropped`: Prefix `!` beside `Bool.not` (§2.6 (language.md:152), §4.8 (language.md:364), E.7) — decided: *Prefix `!`* and *The Members Family's Rules*: `!` stands beside `Bool.not` as prefix `-` beside `Int.negate`, an operator with its function, one stated pair (L1-77).

### K, the cold reader

Defects

- **K1** `done`: §8.5's dependency order misses the members a requirement supplies, so a well-typed program reads a binding with no value and faults (report/language.md:764 (§8.5); docs/soundness.md:115 (section 5)) — the checker counts a member supplied at a named function's use, a fill's and a derived compare's among them, and §8.5 and soundness section 5 say so; regression test let_order_through_supplied_member_test.
- **K2** `done`: `restarting` is not process-only, so a pure function restarts its process, emptying its mailbox and ending the calls waiting on it (report/language.md:852 (§9.5), :241 (§3.9); docs/soundness.md:13 (claim 3), :155 (6.3)) — decided with the user: `restarting` is process-only, §3.9 and the argument's 6.3 saying so (the log's *The Full Review's Questions, One by One*).
- **K3** `done`: §9.4 states no restriction on `Io.show` and `Io.debug`, though §3.9 sends the reader to §9 for it and E.1 relies on it (report/language.md:841-842 (§9.4), :245 (§3.9); report/library.md:157 (E.1); docs/soundness.md:185 (6.7)) — done with P10: §9.4 writes `Io.show : (a!) -> String` and `Io.debug : (a!) -> a! with m`.
- **K4** `done`: §5.9's redundancy rule, read as written, refuses every clause after a guarded one whose pattern covers the type; how a guard counts is unstated (report/language.md:490 (§5.9)) — §5.9 says a guarded clause before is taken to match no value for redundancy.
- **K5** `done`: Soundness 6.1's reason that a `fn` may always be generalized does not hold for a local `fn` that captures a block's process (docs/soundness.md:147 (6.1); report/language.md:235 (§3.9)) — §3.9 generalizes over the variables no name in scope around holds, and soundness 6.1 argues the local `fn` case.
- **K6** `done`: §4.6 forbids a top-level initializer to receive; §6.8 lets a `Never` body wait in an `after`-only `receive`, and the toolchain accepts one (report/language.md:352 (§4.6), :638 (§6.8)) — §4.6 says the initializer receives no message, a `receive` in it having only an `after` clause.
- **K7** `done`: Two of the report's own examples are refused by §4.2: `export fn Distance.+` over a private `Distance`, and `export let log : Address(LogMsg)` over a private `LogMsg` (report/language.md:362 (§4.8), :583-584 (§6.5), :289 (§4.2)) — §4.8's `Distance` and §6.5's `LogMsg` are exported.
- **K8** `done`: §10 cites Appendix E.4, the set module, for the Unicode tables that decide a `Char`'s category and case; those are E.6's (report/language.md:889 (§10)) — §10 cites E.6, E.5 and E.16.

Clarity

- **K9** `done`: A local `fn` that names a parameter which a later `let` of its block shadows: §5.4's two sentences give two answers (report/language.md:460 (§5.4)) — §5.4 says a later `let` of a name a local `fn` reads does not reach it, and the error is for a name only a later `let` binds.
- **K10** `done`: §4.2 makes two declarations of one name an error only when both are exported; two private ones are left unsaid (report/language.md:289 (§4.2)) — §4.2 says two declarations of one name in a module are an error, exported or not.
- **K11** `done`: §4.2 says a module may declare a type or constructor with a prelude name; whether a function or a `let` may is unsaid (report/language.md:307 (§4.2)) — §4.2's sentence covers a function and a value with a prelude name.
- **K12** `done`: §3.9 says nothing of the order in which a module's definitions are inferred, nor that a mutually recursive group is inferred as one (report/language.md:235 (§3.9), :344 (§4.5)) — §3.9 says definitions are inferred in the order of what they name, a group together.
- **K13** `done`: Appendix A lets a result annotation carry two `with`s, `(A) -> B with M with N`, a second spelling of `((A) -> B with M) with N` (report/language.md:275 (`Return`), :201 (§3.4)) — Appendix A's `FnResult` takes one `with` after a result that is no function type, in a type and in a `Return`, and the parser refuses the second; the printer parenthesizes a function result only under an outer `with`, as §3.4 writes it, where it had printed an outer effect after a bare result.
- **K14** `done`: §6.6 says a lambda holding a reply is consumed "as the function argument of `spawnMonitored`", which takes two functions (report/language.md:607 (§6.6)) — §6.6 says the first argument of `spawn` or `spawnMonitored`, the function the spawn runs, and the checker's two messages say the same.
- **K15** `done`: §9.4 is headed "Built-in functions (§6)" and lists `Io.show` and `Io.debug`, which §6 does not define and §9 gives to `io.ern` (report/language.md:834-843 (§9.4), :786 (§9)) — done with P10.
- **K16** `done`: A prelude type is used in §3 before §9 defines it, with no pointer: `Optional`, `Path`, `Map`, `Ordering`, `Less`, and `Fault` before §7.3 (report/language.md:181 (§3.1), :210 (§3.5), :249 (§3.10)) — §3's first `Optional`, `Ordering`, `Path` and `Fault` cite §9.3 and §7.3.
- **K17** `done`: §2.5 says `\u{...}` denotes a scalar value and excludes surrogates, but not that `'\u{D800}'` is an error (report/language.md:119 (§2.5)) — §2.5 says an escape naming a surrogate or a value above U+10FFFF is an error.
- **K18** `done`: Soundness 6.4 says a function that returns what it receives, called in an initializer, "waits for ever"; §8.6 faults it with a deadlock (docs/soundness.md:159 (6.4); report/language.md:638 (§6.8), :764 (§8.5), :770 (§8.6)) — soundness 6.4 says the function waits and the runtime faults it with `deadlock`, and §6.8 says its refusal is of a `receive` written in a `Never` body.
- **K19** `done`: Soundness's (receive) rule drops the guard that its own grammar line gives a `receive` clause (docs/soundness.md:70-71 (section 3), :50) — soundness's (receive) rule has its guard.
- **K20** `done`: Appendix E's listings hide the not-reply-carrying mark, so a reader cannot tell from E.2 that `List.size` takes no list of replies (report/library.md:114 (Appendix E), :164 (E.2), :369 (E.10)) — decided with the user: every listing prints its type as §11.5 does, its marks among it, and a test holds each to its module's interface (the log's *The Full Review's Questions, One by One*).

Where the language made the work harder

- **K21** `done`: A single-file build is refused for the case of a directory above the file, since the working directory is the source root (report/toolchain.md:21, :23 (§11.1)) — decided with the user: the working directory stays the root, a file's namespace is its path from there, and a directory breaking the path shape is refused with the root that leaves it out (§11.1; the log's *The Full Review's Questions, One by One*).
- **K22** `dropped`: A constructor of two positional fields is refused, so a message of two parts must name them (report/language.md:205 (§3.5)) — decided: *Tried and Rejected*: a constructor of several positional fields was rejected, positions being invisible information where names are visible; the finding asks no fix, and D30's help line for the parser's refusal is its own. Same as D30.

### G, the register

Defects

- **G1** `done`: §11.2 gives the prompt's `let` a reason, "so that a lambda it binds is generalized", that is false: a top-level `let` generalizes a lambda too. (report/toolchain.md:39 (§11.2, *Inputs*)) — Cut "so that a lambda it binds is generalized" from §11.2's *Inputs*, which is false as a reason since §3.9 generalizes a lambda bound by a top-level `let` as well (the shell shows `id : (a) -> a` and refuses `let xs = []`).
- **G2** `done`: Appendix F's gloss says a foreign process's messages are checked; §8.4 makes the system processes foreign processes whose messages are not checked. (report/language.md:1099 (Appendix F); report/language.md:737 (§8.4)) — Rewrite Appendix F's *foreign process* gloss as a process whose implementation lies outside the language, the system processes among them, and point to §8.4 for which of its messages are checked.
- **G3** `done`: §3.5 and §4.9 both state the rule for `a.member` in a body with a requirement; §3.5's copy names `compare` and `negate` and leaves out operators. (report/language.md:217 (§3.5); report/language.md:370 (§4.9)) — End §3.5 with "In a body with a requirement, `a.member` names a member and selects nothing (§4.9)", leaving §4.9 alone to state the rule, operators included.
- **G4** `done`: §11.6 restates §11.1's path shape as "one word". §11.1 allows several words joined by `_`, and `ern format` accepts `ordered_set.ern`. (report/toolchain.md:99 (§11.6)) — §11.6 says a file named alone is a module when its name meets §11.1's path shape, in place of "otherwise one word", which `ern format` already does not apply to `ordered_set.ern`.
- **G5** `dropped`: E.0 rule 1 makes a shim's admission depend on numbers "in the decisions log", a rationale document, and argues one case with `String.trimEnd`. (report/library.md:120 (Appendix E.0, rule 1)) — decided: *What the Library Admits*: rule 1 states that a shim is admitted on a measurement whose numbers stand in the log, moved there from CLAUDE.md on purpose, and *What Erlang Held, Moved* decided that the rule gives `trimEnd` as its example.
- **G6** `done`: E.25 states a policy for later implementations, "only where a program's measurement shows the cost", which no program meets as a rule. (report/library.md:599 (Appendix E.25)) — Cut E.25's clause "a representation of another shape replaces the list only where a program's measurement shows the cost", a plan that nothing a program sees depends on, and keep the costs.
- **G7** `done`: §7.4 restates §8.2's terminal and standard-input fault rules in full, and which section owns a cause's text changes from one cause to the next. (report/language.md:703 (§7.4); report/language.md:691; report/language.md:719, 721 (§8.2)) — §8.2 states each terminal and standard-input condition with its text, the unreadable standard input's text among them, and §7.4's list keeps the text with a pointer, its first paragraph's examples staying as *A Failure's Shape* decided them.
- **G8** `done`: §6.6 comments on itself ("§6.6 names no type") and restates the consumption rule and §3.9's restriction to argue that the rule is general. (report/language.md:628 (§6.6, *Where such a value may stand*)) — Cut §6.6's "§6.6 names no type: ..." sentence, whose substance the rule and the list of where a value may stand now carry (*The Reply Discipline Names No Type* decided the substance, not the restatement).
- **G9** `done`: §8.4 announces its own restatement ("as the sentences before say") and gives three reasons in the same paragraph. (report/language.md:737 (§8.4)) — In §8.4 cut "as the sentences before say", "since the function was given none of that type" and "since its type is the caller's", and state the "so that" clause as the rule that what is sent to such an address is checked as a message foreign code sends.
- **G10** `done`: Appendix F glosses one concept twice, as *member* and *type member*. The *type member* gloss leaves out a derived `compare` and a prelude type's unprefixed members. (report/language.md:1118, 1187 (Appendix F)) — Merge Appendix F's *member* and *type member* into one gloss that covers declared, derived and a prelude type's unprefixed members (§4.2, §4.5, §4.9).
- **G11** `done`: Five glosses in Appendix F say less than their sections: *fault*, *not-reply-carrying*, *structural equality*, *tail position*, and *type variable*. (report/language.md:1094, 1125, 1176, 1183, 1189 (Appendix F)) — Correct the glosses of *fault*, *not-reply-carrying*, *structural equality*, *tail position* and *type variable* to their sections: a restart, a type variable not a parameter, exact equality on a foreign type and `Process`, the logical operators' right operands and the pipe's call, and §3.9's generalization.
- **G12** `done`: E.1 restates §9.4's description of `Io.debug` and drops the line feed that §9.4 states and the runtime writes. (report/library.md:157 (Appendix E.1); report/language.md:842 (§9.4)) — Replace E.1's "`Io.debug` writes `Io.show`'s text to standard error", which drops the line feed §9.4 states and the runtime writes, with a pointer to §9.4.
- **G13** `done`: §3.9's paragraph on inferred restrictions says three times that they are printed, and restates what §3.10 says of the equality constraint. (report/language.md:245 (§3.9); report/language.md:251 (§3.10)) — Keep "Each prints with its mark (§11.5)" and the type-scheme sentences in §3.9, cut its two further pointers to §11.5, and cut §3.10's scheme, interface and check sentences to "(§3.9)", keeping its examples.
- **G14** `dropped`: The sentence "carries no argument the program has not declared ... which a call supplies without writing it" argues for principle 3 and stands in §4.8, §4.9 and E.1. (report/language.md:364 (§4.8); report/language.md:372 (§4.9); report/library.md:157 (E.1)) — decided: *Members, Operators, and No Hidden Argument* put "carries no hidden argument" in §4.8 and *A Value Shows Itself at a Known Type* in E.1, and *The Operations Specification Read* made §4.8's sentence the one on a declared argument with the requirement in view.
- **G15** `done`: §4.9 and E.0 shape rule 1 give the same advice, take a member as a parameter or declare a requirement, in nearly the same words. (report/language.md:374 (§4.9); report/library.md:127 (E.0, shape rule 1)) — Cut §4.9's last sentence on a member as a parameter or a requirement, which E.0 shape rule 1 owns (*The Requirement Written into the Report*).
- **G16** `done`: §4.9's last paragraph describes an idiom, the operations record, that has no rule of its own, and its one rule repeats E.0 rule 4. (report/language.md:376 (§4.9)) — Reduce §4.9's last paragraph to one sentence defining an operations record, which E.0 cites, with its example, cutting the restatements of §3.5, §4.8 and E.0 rule 4.
- **G17** `done`: §6.6's paragraph on where a reply-carrying value may stand gives reasons for three of its rules. (report/language.md:628 (§6.6)) — In §6.6 state "A top-level binding of reply-carrying type is a type error" and cut the selection-and-update reason and the sentence on the runtime's types, which restates the reply-carrying definition and §4.7.
- **G18** `dropped`: §6.6's sentence on guards derives a consequence from §5.9 and the rule, instead of stating what a guard may do with a reply. (report/language.md:630 (§6.6, *Patterns and branches*)) — decided: *The Type System Argued*: "A guard gets no rule", the guard sentence being argued there and placed in §6.6 on purpose, and the finding's program behaves as the sentence says.
- **G19** `done`: §6.6 restates its own capture rule, the definition of reply-carrying, and §5.4's rule on statements. (report/language.md:626, 628 (§6.6), against report/language.md:607) — State §6.6's capture rule once, with "`let h = g` is a type error", and cut the `Optional`/`Either` sentence and the statement sentence, which restate the definition and §5.4.
- **G20** `done`: §4.9 argues "A type has one member of each name, so ..." and adds advice on a second order, which E.25 repeats. (report/language.md:368 (§4.9); report/library.md:599 (E.25)) — Keep "A type has one member of each name" in §4.9 and cut the derivation and the advice on a second order, which E.25 states for its module.
- **G21** `done`: §4.9 advises and derives where it should state rules: "takes it as a parameter", and "so `let build = ...` meets the error above". (report/language.md:372, 374 (§4.9)) — Give §4.9's `let build` as an example of the error without "so"; the clause "takes it as a parameter" is that error's help line, which §4.9 holds as the errors' texts, and stays marked as such.
- **G22** `done`: §6.9's paragraph on death gives two reasons and a piece of advice, and says twice that a late `monitor` reports `Unknown`. (report/language.md:644 (§6.9)) — In §6.9 cut the "permission to send" and "keeps nothing" reasons and state the ordering as a rule: a call's answer is not overtaken by its callee's `Down`. Same as P8.
- **G23** `done`: §6.9's paragraph on a restart a supervisor asks for repeats the previous paragraph's list and one of its own sentences. (report/language.md:648, 646 (§6.9)) — Write §6.9's supervisor paragraph as "It restarts as a fault restarts it (above)", cut its own restatement of when it next waits, and cut the "since it is another's or the runtime's" clause.
- **G24** `done`: §3.9 counts "five places" where inference asks for an annotation. The list restates rules owned elsewhere, and the shell's rule for inputs is a sixth place. (report/language.md:239 (§3.9)) — Drop §3.9's count of "five places" and add the two it misses, a fill whose record type leaves a variable undetermined (§5.6) and an input at the prompt (§11.2), so that Appendix F's *Hindley-Milner* stays true. Same as X22.
- **G25** `done`: §3.9's paragraph on inferred restrictions argues twice: a "So" sentence that comments on process-only, and a "since" clause about where the variable stands. (report/language.md:245 (§3.9)) — Cut §3.9's "So one annotation can give two behaviours" and keep `fn h` as the example of inheritance, and state the "since" clause as its own rule: a function the definition returns or holds is read as the definition is.
- **G26** `done`: §11.2 states the configuration directory's default twice in one paragraph, and §11.3 states it a third time. (report/toolchain.md:77 (§11.2, *Startup and history*); report/toolchain.md:81 (§11.3); report/toolchain.md:29) — Cut the last sentence of §11.2's *Startup and history* and the clause from "though", leaving the default to §11.3.
- **G27** `done`: §11.2 gives reasons for four of its rules: fault lines, an abstract type at the prompt, `:load` of a loaded module, and the history of `C-c`. (report/toolchain.md:33, 39, 65, 77 (§11.2)) — Cut §11.2's four reason clauses: the fault line's "so that", the abstract type's "since each input is a module of its own", `:load`'s "since each is in scope from the start" and `C-c`'s "so that `C-p` recalls it".
- **G28** `done`: §11.1 writes the `ern build` usage line twice in one paragraph. (report/toolchain.md:19 (§11.1)) — Replace §11.1's second usage line with "Given `src-dir`, it compiles every `.ern` under it in dependency order", which also stops `ern(1)`'s SYNOPSIS listing `ern build` twice. Same as E76.
- **G29** `done`: §11.5 gives a reason for when the checking of a block stops, and comments on §9.2 to excuse an apparent exception. (report/toolchain.md:91, 95 (§11.5)) — Cut §11.5's "since what follows may use the name" and everything from "and §9.2 lists `Map(k=, v)`".
- **G30** `done`: E.0 argues for its rules in three "since" clauses and restates §0's principle 5. (report/library.md:118, 123, 129 (Appendix E.0)) — Cut E.0's three "since" clauses (the vocabulary, `Io.debug`, `from`); "None of them counts programs" stays, since §0 speaks of a feature and E.0 applies it to a library function.
- **G31** `done`: E.1's paragraph on `Io.show` gives three reasons: why maps and sets print in order, why an effect variable does not matter, and a comparison with operators. (report/library.md:157 (Appendix E.1)) — In E.1 cut "so that equal maps and equal sets print alike", "since a function is written `<function>`" and "more than an operator asks", keeping the rules they hang on.
- **G32** `done`: Four sentences give the program advice instead of stating a rule: on input of untrusted size, on line endings, and on bounding a program's run. (report/language.md:719 (§8.2); report/library.md:461 (E.17); report/library.md:255 (E.5); report/library.md:564 (E.23)) — Cut the four pieces of advice: §8.2's input of untrusted size, `Fs.read`'s comment on `readRange`, E.5's `String.lines` and E.23's "a run is bounded as any process is".
- **G33** `done`: E.17 and E.18 each restate shape rule 8, which already puts the milliseconds last. (report/library.md:456 (E.17), 482 (E.18), against report/library.md:137 (E.0, shape rule 8)) — Cut E.17's and E.18's sentences on the milliseconds last, which E.0 shape rule 8 states.
- **G34** `done`: E.17 and E.18 put reasons and commentary beside their rules: on the `removeAll` walk, a site without a line, what a write's answer means, and framing. (report/library.md:456 (E.17), 482 (E.18)) — State E.17's walk as a rule, a directory replaced by a link while the walk runs is not followed, and cut E.18's "since the runtime opened it", "which does not mean that the far end has them" and "framing is bitstrings".
- **G35** `done`: §4.2 argues that the mapping from files to namespaces is one-to-one, and §11.1 and §11.2 restate the word rule and its examples. (report/language.md:287 (§4.2); report/toolchain.md:23, 29) — Cut §4.2's "A word begins with a letter, so the mapping is one-to-one", keeping the inverse rule that a segment's words begin at its uppercase letters, and leave the word rule's examples to §11.1. Same as G48.
- **G36** `done`: §4.2 derives two lookup rules with "therefore" and "so", and the second leaves unclear which module it hides. (report/language.md:305, 307 (§4.2)) — Write §4.2's two derived lookups as rules without "therefore" and "so", naming plainly that a member `T.f` of the module's own type is reached before a program module `T`'s `f`.
- **G37** `done`: §5.11 states twice how a segment's size is counted, and twice that a value too wide is a compile-time error or a fault. (report/language.md:513, 515 (§5.11)) — Cut §5.11's restated count of a segment's size and state the width rule once, in the second paragraph's form, removing the ambiguous "So is".
- **G38** `done`: §7.4's first paragraph argues and restates: a reason why operators fault, E.0 shape rule 4 in other words, and §7.3's sentence on causes. (report/language.md:691 (§7.4)) — Cut §7.4's "since the form has no place for a value" and the restatement of §7.3 to "The causes are these:"; the `Optional`/`Either` sentence stays in §7.4, which *A Failure's Shape* made its owner.
- **G39** `MVP 3.1`: §8.7 states three times that types are told apart by their declarations across nodes. (report/language.md:776, 780 (§8.7)) — §8.7's *Identity* is the milestone's to state in full ("The milestone is §8.7's identity in full"), and its restatements are read there with the normalized definition.

Clarity

- **G40** `done`: §8.4's first paragraph is 603 words long and covers five topics: which crossings are checked, foreign addresses, result variables, callbacks, and what the checks do not confine. (report/language.md:737 (§8.4)) — Split §8.4's 603-word first paragraph into paragraphs under run-in headings by topic, as the log's *§8.2 and §11.2 Split Into Headed Paragraphs* split those sections.
- **G41** `done`: E.5's sentence that lists the primitives nests appositives three deep and mixes private primitives with exported ones. (report/library.md:255 (Appendix E.5)) — Write E.5's list of primitives as two sentences, the exported primitives and then the private ones by name. Same as E21.
- **G42** `done`: §11.2's `:output` item joins four rules in one comma-spliced sentence. (report/toolchain.md:50 (§11.2, *Commands*)) — Write §11.2's `:output` item a sentence per rule: what `:output path` does, what it refuses, `:output -`, and `:output` alone.
- **G43** `done`: §6.9's first paragraph, 430 words, joins the ways a process dies, monitors, `wrap`, spawn sites, and ownership of resources. (report/language.md:644 (§6.9)) — Split §6.9's first paragraph into death, monitors, the spawn site and ownership, words unchanged.
- **G44** `done`: §11.5's paragraph on where a mismatch is reported is 540 words of placements for different errors, written as running prose. (report/toolchain.md:93 (§11.5)) — Keep §11.5's mismatch rule as prose and set the error-by-error placements as a list.
- **G45** `done`: §7.4's second paragraph opens with "These faults come from no operation of the list above", whose "These" points ahead to sentences not yet read. (report/language.md:703 (§7.4)) — Reword §7.4's "These faults come from no operation of the list above" so that it names what follows, as "Beside the list, these faults are raised:".
- **G46** `done`: §7.4, the section on what causes a fault, holds the rules for values the runtime corrects, which are no faults. §6.3, §6.6 and §6.9 restate them. (report/language.md:691 (§7.4)) — State each corrected value once, §7.4 holding a duration's and a count's (*A Failure's Shape*) and §6.9 the window's, and have §6.3, §6.6 and §7.4 point rather than restate.
- **G47** `done`: §3.9's sentence about type variables named first in a lambda gives "one" and "it" referents that are hard to resolve. (report/language.md:235 (§3.9)) — Reword §3.9's sentence on a type variable named first in a lambda's or a block `let`'s annotation so that each "one" and "it" has one referent.
- **G48** `done`: §11.1's *Path shape* sentence on modules of several words also gives a nested directory, which is two namespace segments, not one module name of several words. (report/toolchain.md:23 (§11.1)) — Cut §11.1's sentence that lists `http/parser.ern`, two segments, as a module of several words, leaving the mapping to §4.2. Same as N8, G35.

## The diagnostics

### X, the diagnostics

Defects

- **X1** `done`: An error in a `<-` binding does not stop its block: a later statement's error hides it, and later statements change the types it prints. (test/diagnostics.md:2754; §11.5) — the checker checks a `<-` whose sum type is known before it binds the pattern's names, `known_bind_arrow`, so an error there stops the block as §11.5 says; regression test bind_arrow_checked_where_it_stands_test.
- **X2** `done`: Printed types rename the variables a declaration's annotations name, `t` to `a` and `m` to `e`, so a single message can show two different variables as `a`. (test/diagnostics.md:1769, 1772, 665, 671; §11.5) — a callee's type in a label is its declared scheme under its own names, a fill's field under its type's parameters, and a mismatch names both types under one naming, `ern_types:format_pair`; regression test declared_names_in_labels_test.
- **X3** `done`: The entry for a recursive top-level `let` prints, first and across the whole declaration, a type mismatch that exists only because of the self-dependency error printed after it. (test/diagnostics.md:2606) — a top-level `let`'s own mismatch with its placeholder is not reported, since only a use in its cycle binds the placeholder and §8.5 refuses the cycle; the entry is retitled; regression test let_named_by_itself_one_error_test.
- **X4** `done`: §11.5 says a missing requirement's fix is a help line, but §4.9 and every entry of that kind put it in the message, so the report contradicts itself. (§11.5 (report/toolchain.md:93); §4.9 (report/language.md:372); test/diagnostics.md:2160, 2175, 2190, 2204, 2329) — the fix stands on the help line, ``add `needs a.compare` to unique's signature``, and under a top-level `let` ``declare a `fn` with `needs a.compare` ``; §4.9's quotations cut to the message; the guide's and the operations note's excerpts follow.
- **X5** `done`: A rejected call site's error names no parameter and marks the callee, so with two arguments of one type the reader cannot tell which fails. (§11.5 (report/toolchain.md:95); test/diagnostics.md:2143, 2655, 3654, 3914) — a rejected call site is reported at the first argument whose type breaks the restriction, names the argument's place, and labels the callee with its type; a callee that is no name, or a restriction a later use breaks, keeps the old form at the name, as §11.5 now says; the tests of the messages updated.
- **X6** `done`: Eleven catalogue headings cite a report section that does not hold the rule: §3.8 for abstract types, §4.4 for function syntax, §5.2 for `if`, §3.3 and §3.2 for type syntax. (test/diagnostics.md:325, 338 (§3.8, Foreign types); 435, 887 (§4.4, Abstract types); 583 (§5.2, Calls); 914 (§3.3, Lists); 501, 529, 543 (§3.2, Tuples); 1095 (§4.5 for `let`); 515 (§3.2 for the `FnType`/`ParenType` rule of §3)) — the eleven headings cite §3.6 and §4.4, §4.5, §5.8, §2.3 and §4.3, §3, §4.6, and §3 with §3.2 for the parenthesized types.
- **X7** `done`: "zero is not a member" underlines only the type variable `a`, not `zero`, which is the erroneous part. (test/diagnostics.md:2257) — the parser underlines `a.zero` whole; regression test in requirement_test.
- **X8** `done`: §11.5 says a fill's error is reported "at the construction", but the entries underline the namespace after `..`. (§11.5 (report/toolchain.md:93); test/diagnostics.md:1753, 1769, 1790) — §11.5 says a fill's error is reported at the namespace after `..`.
- **X9** `done`: The catalogue has no entry for two diagnostics §11.5 specifies: `Io.show` at a type that is not known whole, and a callee named "the callee". (test/diagnostics.md:1 ("Errors the lexer, the parser and the checker give, each with one small program"); §11.5) — the catalogue holds `Io.show` at a type not known whole, a callee that is no name, "the callee", and a selected field's call, `ops.size`.

Clarity

- **X10** `done`: When a pattern variable hides a reply, the message says only that the reply is "not consumed on this path"; it should label the binder that hides it. (test/diagnostics.md:3819-3836) — a path that does not consume a reply labels the first binding on it that shadows the reply's name, "this r is a new binding, which shadows the reply-carrying r", and §11.5 says so.
- **X11** `done`: §11.5 defines the help line as "naming the fix", yet sets help lines that name a rule or a reason, so the `Nest` entry gives no fix. (§11.5 (report/toolchain.md:91, 93); test/diagnostics.md:1076, 1090) — the recursive call's message names the rule, "the argument of a recursive call does not fit f at its own type (§3.9)", and its help the fix, a second function; the recursive type's help writes the type at its parameters, ``write `Nest(a)`, or `List(Nest(a))` to hold it in a List``; §11.5's two sentences say "naming the fix".
- **X12** `done`: For an effect variable, "e is no type variable of the signature" is false on its face, since `e` stands in the signature after `with`. (test/diagnostics.md:2285; §4.9) — an effect variable has its own message, "e is an effect variable, and a requirement names a type variable in a value position".
- **X13** `done`: The `Foreign.from` message ends with the type `a!`, which reads as an exclamation, and its help opens with a fix that cannot apply to a signature's type variable. (test/diagnostics.md:2344-2348) — the type comes first, "the type a! is not known whole here, and Foreign.from gives foreign code a value by its type", `Io.show`'s alike, and the help at a signature's variable is the `foreign fn` clause alone; regression test in foreign_from_at_a_known_type_test.
- **X14** `done`: Only replies passed to a function get the help on discharging them; `_`, `as`, omitted fields and "never consumed" get none, and "consumed" and "discharged" alternate. (test/diagnostics.md:3585, 3602, 3621, 3640, 3752, 3773; §11.5 (report/toolchain.md:93)) — every error of a reply's obligation, `_`, `as`, a wildcard or omitted field, twice, on a path, never, and a function that duplicates or discards it, has one help line, "a reply is consumed by answering it, passing it on once, or matching it (§6.6)", and §11.5 says so. Same as N11.
- **X15** `done`: The help for `unit` suggests `size(n * 8)`, but in its own program `n` is the segment's value, so the help reads as "the value times 8". (test/diagnostics.md:850, 858) — `unit` is refused at the segment, where the help writes the size given, ``write `size(2 * 8)` ``, and where either is no integer "write the size multiplied by the unit"; regression test in no_unit_specifier_test.
- **X16** `done`: When a later statement settles an operand's type, the mismatch message does not label that statement, so the "found" type has no visible source. (test/diagnostics.md:1594, 1993) — a deferred selection or operator keeps the span of the unification that fixed its operand type and labels it, "this fixes `+`'s operands as Int", which names no variable, since the use that fixed it may be another operand's; §11.5 says so; regression test settled_operand_labelled_test.
- **X17** `done`: The occurs-check messages for `<-` label the block's value but not the two expressions that force the type to contain itself, so the fix is hard to find. (test/diagnostics.md:2790, 2809) — where the block's value is an `if` or a `match`, each branch is labelled, the first with the block's type and the others "and here", in place of the whole expression.
- **X18** `done`: "expected a, found Int" against a rigid variable has no help line saying that `a` stands for every type. (test/diagnostics.md:2625, 2639) — a mismatch that would bind an annotation's variable has the help "`a` stands for every type a caller may choose, not for Int alone", and for two "`a` and `b` stand for types a caller chooses apart, which may differ"; §11.5 says so.
- **X19** `done`: §11.5's "the line before" does not say which line it precedes, and the output shows the line before the first line shown, so `...` can stand for one blank line. (§11.5 (report/toolchain.md:91); test/diagnostics.md:1108, 1126, 2043) — §11.5 says "the line before the first line a span covers".
- **X20** `done`: A type parameter written twice underlines the whole declaration, while a field or variable written twice underlines the second and labels the first. (test/diagnostics.md:1047-1049) — the AST keeps each type parameter's span, and the checker underlines the second `a` and labels the first, "first written here"; the rule stays the checker's, since Appendix A admits the sentence; regression test in type_parameters_distinct_test.
- **X21** `done`: Messages cite the report in two styles, "(§3.9)" and "(report §5.9)". (test/diagnostics.md:2911, against 1076, 2257, 2655) — every message cites as "(§5.9)": the guard's label, `ern build`'s namespace clash and `ern run`'s entry point.
- **X22** `done`: The fill message "leaves a undetermined" does not ask for an annotation, as every other undetermined-type message does, and "a" reads as an article. (test/diagnostics.md:1790; §5.6; §3.9 (report/language.md:239)) — the fill's message reads "leaves the variable a undetermined; annotate it", §5.6 quotes it, and §3.9's list names the fill. Same as G24.
- **X23** `done`: "expected a declaration (type, abstract, fn, let, foreign)" omits `export`, which also begins a declaration. (test/diagnostics.md:305; Appendix A `Declaration`) — the list names `export` where it may begin the declaration, and not after it; regression test in type_declarations_test.
- **X24** `done`: "the implementation of size is named module:function/arity, here module:function/1" is hard to read as the form to write. (test/diagnostics.md:1202) — the message is "the implementation of size is not written `module:function/arity`", with the help "write the host's module and function and the arity 1, as `module:function/1`"; regression test in foreign_implementation_name_test.
- **X25** `done`: The `receive` guard that orders `Money` has no help line, while the two other `receive` guard errors suggest receiving the message and matching it. (test/diagnostics.md:3532) — the guard that orders `Money` has the help "receive the message and `match` it".
- **X26** `done`: The heading "A `receive` guard that compares a sum" means an arithmetic sum, but elsewhere the catalogue uses "sum" for a sum type. (test/diagnostics.md:3556) — the heading reads "compares a computed value".

## The guide

### U, the guide

Defects

- **U1** `done`: The guide says running out of memory is a process fault that ends only that process; on the runtime it crashes the whole node, and no document says otherwise. (ernest_guide.md:1474 (§6.3)) — decided with the user: exhausting memory ends the program with status 1 and no crash dump (§10, §11.8), and the guide says so (the log's *The Full Review's Questions, One by One*).
- **U2** `done`: §3.3's bullet on polymorphism is false: a block `let` that binds a lambda is generalized, and a generalized top-level `let` needs nothing settled. The bullet also contradicts itself. (ernest_guide.md:666 (§3.3)) — the bullet restates report §4.6, a block `let` that binds a lambda polymorphic and what must be settled said once, N16's split with it.
- **U3** `done`: §2.9 says a library function carries `with m` "only where" it reaches a system process or asks about processes, but `Clock.monotonic` and `Supervisor.group` do neither and still carry it. (ernest_guide.md:563 (§2.9)) — §2.9 gives shape rule 5's four cases and cites it.
- **U4** `done`: The shell's `:doc` prints prelude types without their restriction marks, unlike `:type`; this breaks report §11.2, which the guide's §2.9 relies on. (report §11.2 (*Documentation*, toolchain.md:71); the guide's promise is at ernest_guide.md:567) — settled by N3's work: `:doc`, `Shift-Tab` and `ern doc` print a declaration through the checker's printer, marks and all, the prelude's among them.
- **U5** `done`: The answer to exercise §7.4 says the constructor is visible in `main.ern`, but §7.2 puts `Stack` in `stack.ern`. (ernest_guide.md:2479 (§13, answer to §7.4)) — the answer says `stack.ern`.
- **U6** `done`: The word counter writes by hand a weaker version of `String.words`, so the guide teaches splitting words two ways and gets tabs and newlines wrong. (ernest_guide.md:694 and :714 (§3.6); also §2.10 at :578) — the word counter and §2.10's console use `String.words`.
- **U7** `done`: The §8.5 transcript starts with `erlc -o build`, which fails in a fresh directory because `build/` does not exist yet. (ernest_guide.md:2238 (§8.5)) — §8.5's transcript builds before `erlc -o build`, so `build/` exists.
- **U8** `done`: §8.5 cites E.0 rule 3 for "a data format, a protocol and a pattern language belong to a library", but rule 2 says that. (ernest_guide.md:2246 (§8.5)) — §8.5 cites E.0 rule 2.
- **U9** `done`: §6.3 says report §7.4 lists every fault, but §7.3 also counts the causes that standard library sections give, such as the supervisor's. (ernest_guide.md:1474 (§6.3)) — §6.3 says report §7.4 lists the language's causes and a library function's section gives its own (§7.3).
- **U10** `done`: §0 says every error has the `file:line:column` form with the source shown, but a module cycle is reported without either. (ernest_guide.md:67 (§0)) — §0 says an error in a module's source has the form.

Clarity

- **U11** `done`: §2.9 glosses `m+` as "an effect variable that is never pure", but `self`'s `m` is never pure and carries no mark. (ernest_guide.md:567 (§2.9)) — §2.9 glosses `m+` as a process-only effect variable that stands nowhere else in the type.
- **U12** `done`: §5.5 says "the system modules deliver so too", then lists `monitor` and `Process.faults`, which belong to no system module. (ernest_guide.md:1250 (§5.5)) — §5.5's paragraph opens with the function that asks for it taking the function that makes the message (E.0 shape rule 8).
- **U13** `done`: The guide's "shim" means a private `foreign fn` plus an Ernest wrapper, which differs from the report's meaning, and §8.3 binds a function a third way. (ernest_guide.md:2185 (§8.5); ernest_guide.md §8.3 (`export foreign fn contains`)) — §8.5 uses Appendix F's sense of shim and says when a `foreign fn` is exported as it is and when an Ernest function wraps it.
- **U14** `done`: §7.1's *Entry point* paragraph says each entry point gets a module of its own, then runs `check` from a shared `tools.ern` with `--main`. (ernest_guide.md:1751 (§7.1)) — §7.1 keeps one arrangement: a module exports several entry points and `--main` names one.
- **U15** `done`: §6.6 says a sibling that computes without waiting "is not restarted"; the report says it restarts when it next waits, and the child that faulted waits for it. (ernest_guide.md:1647 (§6.6)) — §6.6 says a sibling restarts when it next waits, the faulted child waiting for it, and one that never waits is never restarted.
- **U16** `done`: §3.3 says "`*` on `Int` fixes `value : Int`", but the literal `2` fixes the type, not the `*`. (ernest_guide.md:655 (§3.3)) — §3.3 says the literal `2` is an `Int`, so `*` is `Int.*`.
- **U17** `done`: §9.4 says the Emacs mode "indents it as the style guide does", but it indents to `ern format`'s layout and can format on save. (ernest_guide.md:2385 (§9.4)) — §9.4 says the Emacs mode indents as `ern format` lays out.
- **U18** `done`: In §2.5, "(§8.3)" sends the reader to the guide's §8.3 for exact equality on foreign values, but that section does not explain it. (ernest_guide.md:427 (§2.5)) — §2.5 cites report §3.10.
- **U19** `done`: §4.4's list of `callForever` causes leaves out `callee was closed`. (ernest_guide.md:836 (§4.4)) — §4.4's list has "was closed".
- **U20** `done`: The claim that an adapted address "costs nothing to keep" is in no document. (ernest_guide.md:1227 (§5.5)) — §5.5 says an adapted address is a value, kept like any other.
- **U21** `done`: §0 states distribution's build status ("planned and not yet built") without naming the document that owns it. (ernest_guide.md:131 (§0); the same text is in the README) — the README's and guide §0's entry says "planned".

### N, the newcomer

Defects

- **N1** `done`: Guide §13's answer to exercise §7.4 says code in `main.ern` may name `Stack`'s constructor. It should say `stack.ern`; `main.ern` is refused. (ernest_guide.md:2479) — with U5.
- **N2** `done`: The printed type of `Io.show` leaves out its requirement. A generic caller is refused for not declaring `needs a.show`, which no printed type of `Io.show` mentions. (ernest_guide.md:2032 (§7.3); `:type Io.show`, `:browse Io`, `:doc Io.show`) — decided with the user: `Io.show` and `Io.debug` state `needs a.show` (§9.4) and write any type whose variables the requirement names (E.1; the log's *The Full Review's Questions, One by One*).
- **N3** `done`: `:doc` and `ern doc` print a function's type without its parameter names, but the documentation's prose refers to the parameters by name, so a reader cannot tell which argument is which. (ernest_guide.md:189 (`:doc`), ernest_guide.md:2365 (`ern doc`)) — decided with the user: a page shows a function's declaration, its parameters named, and the prelude's functions take names (§11.4; the log's *The Full Review's Questions, One by One*).
- **N4** `done`: For the same function, `:doc` prints a different type from `:type` and `:browse`: it drops the `+` of `m+` and the `!` of `a!`, marks the guide teaches as meaningful. (ernest_guide.md:567) — settled by N3's work, with U4.

Clarity

- **N5** `done`: User-facing messages name "MVP 3.0", which neither the README nor the guide explains, so a newcomer cannot tell what, or when, it is. (`ern run --help`; the compiler's refusal of `Peer.spawn`; ernest_guide.md:2107 (§8)) — decided with the user: the messages keep the milestone's name, and the README and guide §8 name MVP 3.0 as the plan's milestone for peers (the log's *The Full Review's Questions, One by One*).
- **N6** `done`: The guide never lists the reserved words, and the parser's message does not say that a word is reserved, so `needs` as a field name fails without a clear reason. (ernest_guide.md:2449 (the guide's only mention of reserved words); ernest_guide.md:1802 (`needs` introduced)) — the parser calls a reserved word in a name's place "the reserved word `w`", tested, and guide §2.2 lists §2.4's eighteen words; `needs` is no longer reserved (P17).
- **N7** `done`: The guide refers to `Os.read`, `Os.write` and "a program the runtime started" but never shows how to start one. I simulated my tasks with sleeps instead of running commands. (ernest_guide.md:565, ernest_guide.md:1263) — guide §1.3 shows `Os.run(Os.Command(...), ms)` with its console, and says what `Os.start`, `Os.read` and `Os.write` do.
- **N8** `done`: Guide §7.1's sentence "A module of two words may also be a directory" suggests that `http/parser.ern` is the same module as `http_parser.ern`. It is a different namespace. (ernest_guide.md:1711) — §7.1 says a directory adds a namespace segment, `http/parser.ern` a module apart from `http_parser.ern`.
- **N9** `done`: Exercise §3.7 asks what is inferred for `map2` "when called as" an expression whose `address` is never bound. A function's type does not change with one call. (ernest_guide.md:735) — exercise §3.7 gives `address` its type and asks for `map2`'s type and what the call binds.
- **N10** `done`: The shell's error for an unsettled address underlines only column 1, and its help suggests a list annotation instead of `with Never`. (ernest_guide.md:760) — the shell underlines the whole binding, and an address's help names the annotation `let p : Address(T) = ...` or the spawned function's mailbox, `with Never`; §11.2 says so; regression test unsettled_binding_test_.
- **N11** `done`: The error for a forgotten reply says "never consumed", but the guide teaches that a reply is "answered". (ernest_guide.md:83) — "is never consumed" and every other obligation error has the help naming the ways to consume a reply. Same as X14.
- **N12** `done`: The help for a missing requirement ends with "add needs a.compare" without backticks. It reads as if a function named `add` needed something. (ernest_guide.md:2026) — the help is code and says where, ``add `needs a.compare` to unique's signature``, since `needs` may stand without a result type (Appendix A's FnDecl). With X4.
- **N13** `done`: Guide §7.3 prints a whole 145-line standard library module and introduces three new mechanisms in one section, which buries the one a newcomer needs. (ernest_guide.md:1802-1949) — decided with the user: §7.3 shows the declarations that carry the requirement and points at the file and `:doc OrderedSet` for the rest; a test holds each part to the module (the log's *The Full Review's Questions, One by One*).
- **N14** `done`: `ern run` on a `.ern` file says only that the name does not end in `.erc`, not that the module must be built first. (ernest_guide.md:147) — `ern run` given a module's source says to build it first, tested.
- **N15** `done`: The guide shows shell errors at `input 2:1:1` without saying that the first number counts the inputs. (ernest_guide.md:459) — §1.2 says an error at the prompt is placed as `input n:line:column`.
- **N16** `done`: Guide §3.3's first bullet ends with an inverted clause that I could not parse on a first reading. (ernest_guide.md:666) — with U2.
- **N17** `done`: Guide §6.5 justifies a declaration's place by pointing a newcomer to the project's style guide, a document for the project's workers. (ernest_guide.md:1600) — §6.5's sentence citing `docs/style.md` is gone.
- **N18** `done`: The README's opening paragraph presents hash-identified code as one of Ernest's parts. Three lines later it says that feature is "planned and not yet built". (README.md:11) — the README's opening marks code known by its hash as planned.
- **N19** `done`: The README explains its first point by contrast with Gleam, which a reader who does not know Gleam cannot use. (README.md:13) — the README's and guide §0's first entry says an address's type is the type of the mailbox it reaches.

Where the language made the work harder

- **N20** `done`: `needs`, `derives`, `after`, `as`, `or` and `when` are reserved everywhere, so common English words cannot name a field, a parameter or a binding. (ernest_guide.md:1802 (`needs`), ernest_guide.md:2034 (`derives`)) — decided with the user: `needs` and `derives` are words read by position and identifiers elsewhere; §2.4 counts eighteen reserved words (the log's *The Full Review's Questions, One by One*).
- **N21** `dropped`: Without formatting or interpolation, a one-line summary of four counts takes four `Int.toString` calls and seven `<>`, which `ern format` then lays out as eight lines. (ernest_guide.md:270) — decided: *Later*: string interpolation is declined on principles 2, 3 and 4 and reconsidered only for a design that keeps holes to `String` and adds nothing to the lexer, which the finding does not bring.

## The documents

### D, the documents

Defects

- **D1** `done`: The loads' `rows` sample, as docs/memory.md describes it, counts four of the runtime's six tables, so a row leaked into `ern_callees` or `ern_deliveries` passes the exact count. (docs/memory.md:27; test/ern_load.erl:112) — `ern_load`'s `rows` counts all six tables, and docs/memory.md names them.
- **D2** `done`: docs/architecture.md says `ern_rt` keeps four tables, with deliveries as `{{delivering, Pid}, Target, Starter}` rows of `ern_held`. It keeps six tables, and deliveries have one of their own. (docs/architecture.md:80-85) — docs/architecture.md lists the six tables with their rows.
- **D3** `done`: Three doc blocks added since 0.2.0 state a version they did not ship in. `OrderedSet` and `OrderedMap` say "since 0.2.0", `Os.user` inherits "since 0.1.0", and no test can catch it. (stdlib/ordered_set.ern:40, stdlib/ordered_map.ern:26, stdlib/os.ern:152; docs/release_review.md:14) — the doc test holds every `since` to the release tags: a module or an exported declaration says the first tag that holds it, by its kind and name, and one no tag holds says the next patch, minor or major release after the last tag; the lines it named are corrected, as E4 lists. Same as E4.
- **D4** `done`: docs/shell_design.md's foreign interface lists `output`, which item 5 rewrote in Ernest. It also leaves out `declaredType`, a foreign function the shell does declare. (docs/shell_design.md:54 (the groups at :52-56)) — `output` left the commands group and `declaredType` joined the result's.
- **D5** `done`: docs/shell_design.md names three shell functions that no longer exist: `pending`, `offered` and `quietly`. They are now `reportPending`, `namesFor` and `executeQuietly`. (docs/shell_design.md:42, :145, :167) — docs/shell_design.md writes `reportPending`, `namesFor` and `executeQuietly`.
- **D6** `done`: docs/operations.md quotes `mixed.ern`'s refusal as "does not fit the callee". `ern build` actually names the function, "does not fit OrderedSet.union". (docs/operations.md:174; docs/scratch/operations.md:309) — the note and its scratch copy quote `does not fit OrderedSet.union`.
- **D7** `done`: docs/operations.md says its code is excerpted from the files, but its `ordered_set.ern` block predates the renaming: it writes `x` and `y` where the file has `element`, `head`, `first` and `second`. (docs/operations.md:3 and :42-101; the same block in docs/scratch/operations.md) — settled by D22's trim: the text it names is gone from the note, the report owning the rule.
- **D8** `done`: docs/operations.md's example of a fill error, `Ops(..Set) lacks isSubset: Set has no isSubset`, cannot happen: `Set` has `isSubset`, and that fill compiles. (docs/operations.md:26; docs/scratch/operations.md:132) — settled by D22's trim: the text it names is gone from the note, the report owning the rule.
- **D9** `done`: docs/operations.md's console for `unique` without its requirement shows one error. `ern build` prints a second, spurious one, `Io.show ... not known whole here: a!`, a cascade in the checker. (docs/operations.md:154-157) — a declaration whose check failed is published at the scheme its signature states, any type where the signature is itself in error, so `Io.show` of its result follows from nothing; the note's excerpt names line 18; regression test failed_declaration_keeps_its_signature_test.
- **D10** `done`: docs/operations.md prints `fromList`'s type without the restriction marks. `ern doc`, `:doc` and `:type` print `(List(a!)) -> OrderedSet.Set(a!) needs a.compare`. (docs/operations.md:298) — settled by D22's trim: the text it names is gone from the note, the report owning the rule.
- **D11** `done`: docs/operations.md says MVP 3.0 decides where versions of a type's `compare` meet. The plan puts that question in MVP 3.1, with the normalized definition. (docs/operations.md:316; docs/implementation_plan.md:269-272) — the note names MVP 3.1's normalized definition.
- **D12** `done`: docs/operations.md says E.0 lacks the rule that an operations record comes after the subjects. E.0 shape rule 1 states it, and names the argument `operations`. (docs/operations.md:324; report/library.md:127) — settled by D22's trim: the text it names is gone from the note, the report owning the rule.
- **D13** `done`: docs/node_protocol.md says the report places a process with `Where = Local | Peer(String)`. `Where` left the language on 2026-10-01, and the report has no such type. (docs/node_protocol.md:15) — docs/node_protocol.md says the report places a process with `Peer.spawn(name, f)`.
- **D14** `done`: The plan's MVP 3.0 still checks `Peer` "beside the constructor `Peer` of `Where`", a type that the same section says left the prelude. (docs/implementation_plan.md:231-232, against :202-205) — the plan's clause on `Where`'s constructor is gone.
- **D15** `done`: The plan's MVP 3.2 lists the libraries written so far as `libs/ets` and `libs/markdown`. It leaves out `libs/ansi`, Appendix G.3, written on 2026-10-01. (docs/implementation_plan.md:305) — the plan lists `libs/ansi` among the libraries written.
- **D16** `done`: docs/architecture.md's *Tests* section, the owner of "what each test runs", leaves out the generated grammar programs, the typed programs, the library's laws and the operations programs. (docs/architecture.md:140-155; docs/development.md:11) — docs/architecture.md's *Tests* names the grammar, typed-program and laws machines and `operations_test_`.
- **D17** `done`: docs/development.md's layout of the repository predates MVP 2.99c. Its `test/` entry leaves out the grammar and typed tests, `ern_grammar.erl`, `layout/` and `expected/operations/`, and its `build/` entry leaves out `build/pages`. (docs/development.md:51-59, :76-79, :144; Makefile:266-272) — docs/development.md's layout names the grammar and typed tests, `ern_grammar.erl`, `layout/`, `expected/operations` and `build/pages`, which `make clean` removes.
- **D18** `done`: docs/architecture.md uses names and arities from before the renaming. `run_tests/3` is now `/4`, and `Main`, `Opts`, `Msg`, `Alias` and `To` are names the glossary refuses and the code has dropped. (docs/architecture.md:83, :84, :99, :103, :129) — docs/architecture.md writes `EntryPoint`, `Options`, `Cause`, `Reply` and `run_tests/4`.
- **D19** `done`: docs/memory.md says the reaper wakes ten times a second. While a load samples, it looks once a second, and has since MVP 2.99b's item 26. (docs/memory.md:25; the comment at test/ern_load.erl:138-145) — docs/memory.md says the reaper looks once a second while a load samples.
- **D20** `done`: docs/full_review.md says its readers read every document and all the code. Yet no brief names `emacs/README.md`, `tools/release/README.md`, `man/README.md`, `assets/README.md`, `test/ern_pty.py` or `tools/install.sh`. (docs/full_review.md:3, :29, :30, :31) — D's brief names every tracked Markdown file, and C's the scripts under `tools/` and `test/`.
- **D21** `done`: docs/style.md says `make test` holds every Ernest source to `ern format`'s layout. The `docs/operations/*.ern` programs are outside every style test, outside `make format`, and outside the citation test. (docs/style.md, *Ernest*, first paragraph; test/ern_style_tests.erl:122-129 (`modules/0`); Makefile, `ERNEST_SOURCES`; test/ern_docs_tests.erl, `citations_resolve_test`) — `docs/operations/*.ern` are in the style tests, `ERNEST_SOURCES` and the citation test.

Clarity

- **D22** `done`: docs/operations.md restates §4.9, §3.5, §5.6, E.25 and E.26 as "The specification", a second owner of the report's rules; findings 6 to 12 are its drift. (docs/operations.md:3 and :16-31, *What changes in Ernest* at :318-330; CLAUDE.md, *Who owns each fact*, the line on operations.md) — decided with the user: the note keeps its goals, its programs, its costs and its comparison, and the contract on `compare`'s laws until MVP 2.99d's item 4 moves it to §3.10; its rules point at the report (the log's *The Full Review's Questions, One by One*).
- **D23** `done`: `docs/operations/usage.ern`, operations.md and its scratch copy name the record `Ops` and `ops`. The report (§4.9, E.0 shape rule 1) and guide §7.3 write `Operations` and `operations`. (docs/operations/usage.ern:10-24; docs/operations.md:25, :109-122, :324; docs/scratch/operations.md) — the record is `Operations` and its argument `operations` in usage.ern, the note and its scratch copy.
- **D24** `done`: `assets/README.md` is owned by no entry of CLAUDE.md's *Who owns each fact*, and restates the `<picture>` block that README.md, the guide and the release README each carry. (assets/README.md:1-15; CLAUDE.md, *Who owns each fact*) — CLAUDE.md names `assets/README.md` as the logo files' note, which points at README.md's `<picture>` block.
- **D25** `done`: The plan's MVP 3.0 lists the check that a supervisor's children run on its node twice, once as the release review's C1-35 and once as a decision of 2026-09-27. (docs/implementation_plan.md:196-198 and :248-251) — the plan's two bullets are one.
- **D26** `done`: docs/principles_review.md says its readers read the report and the guide, not the code, yet sends a reader in doubt to `erl/` and gives L the log. (docs/principles_review.md:3, :12, :21) — docs/principles_review.md's opening says what its readers read.
- **D27** `done`: The checker names the type whose fields it reads `Owner`, a word the glossary keeps for a resource's process alone. (erl/typer/src/ern_typecheck.erl:694-731 (`at_parameters`) and :2454-2473 (`cannot_derive`); docs/style.md, glossary entries *Owner* and *MemberOf*) — the checker's `Owner` is `Declaring` in `at_parameters` and `MemberOf` in `cannot_derive`.
- **D28** `done`: `mvp_refusals_listed_test` finds only texts that say "in MVP n". `--config-dir`'s help, "its ernest.conf is read from MVP 3.0", names an MVP and slips past it. (erl/cli/test/ern_cli_tests.erl:1709; erl/cli/src/ern_cli.erl:578, :582, :585) — `mvp_refusals_listed_test` finds `MVP n` anywhere in a string, and docs/development.md's table holds the two help texts it found.
- **D29** `done`: docs/install.md lists what the release archive holds but leaves out `assets/`. `install.sh release` copies it there beside the README, which shows it. (docs/install.md:50; tools/install.sh:170) — docs/install.md says the archive holds the logo under `assets/`.

Where the language made the work harder

- **D30** `done`: A constructor of two positional fields, `Vec(Float, Float)`, is refused with only the parser's "expected `)` instead of `,`", and no help line names §3.5's rule. (§3.5; the parser's diagnostic for a type declaration) — the parser refuses a second positional field with "a constructor has exactly one positional field" and the help ``name the fields, `Vec(x : ..., y : ...)`, or hold a tuple, `Vec(#(..., ...))` ``; a catalogue entry; regression test second_positional_field_test.

### H, the shell's guide

Defects

- **H1** `done`: The modules table says `Shell` alone reaches the host, but the history file; `Shell.Complete` declares seven foreign functions and lists the source root through `Fs`. (shell/README.md:60) — the `Shell` row names the history file and `Shell.Complete`'s questions.
- **H2** `done`: "The front end" never says that `Shell.Complete` declares foreign functions, yet it gives `names` as an example, and `names` is not in `shell.ern`. (shell/README.md:78) — *The front end* says `Shell.Complete` declares its own questions.
- **H3** `done`: The README's command for one module's tests fails for `Shell.Region` and `Shell.Style`, because `Ansi` is not on the load path. (shell/README.md:94) — the README's test command gives Style's and Region's load paths.
- **H4** `done`: The README says that at a terminal `main` writes the first prompt itself, unlike `prompt`; the code writes it through `prompt`, draining the screen first. (shell/README.md:36) — the README says `prompt` writes every prompt.
- **H5** `done`: The README and five comments in `shell/` cite §9.3 for the modules' `Test` values; §9.3 is "Declared types", and tests are Appendix E.24 and §11.2. (shell/README.md:72) — the README, the five comments and the design note cite Appendix E.24 and §11.2.
- **H6** `done`: The `ScreenMsg` comment says the reader sends `Said`; it sends only `Noted`. The README points to these comments to learn who sends what. (shell/shell.ern:72) — `ScreenMsg`'s comment says `Said` comes from the session alone.
- **H7** `done`: Two regression-test comments cite "findings.md", which this commit does not have. They point nowhere. (shell/shell/editor.ern:471) — the two comments state their defects without the past findings.

Clarity

- **H8** `done`: `showing`'s comment says "the session is told once", but `hint` tells the screen; elsewhere "the session" names the process that holds `State`. (shell/shell.ern:1033) — `showing`'s comment says the person is told.
- **H9** `done`: `Shell.Region`'s header says the screen process holds nothing but the region, but the screen also holds where `:output` sends; the README never mentions it. (shell/shell/region.ern:8) — `Shell.Region`'s header says "nothing else of the drawing", and the README says the screen holds where `:output` sends.
- **H10** `done`: The README puts what a `:` line does in the Commands part, but the `:output` command's `output` and `cannotWrite` stand in the session part. (shell/shell.ern:331) — the README names `output` and `cannotWrite` as the exception in its part 2.
- **H11** `done`: The README cites *Ordering*, *Queueing* and *The front end's copy* as design-note sections, but they are bold paragraphs inside *Processes* and *The foreign interface*. (shell/README.md:3) — the README cites the design note by its sections and paragraphs.
- **H12** `done`: The design note's *Line mode* and *Startup files*, to which the README sends the reader, name functions `pending` and `quietly` that the shell does not have. (docs/shell_design.md:42) — with D5.
- **H13** `done`: README:72 says the pure modules are tested by their `Test` values, but the impure `Shell.History` and `Shell.Complete` have them too. (shell/README.md:72) — the README says each module but `Shell` is tested by its `Test` values.
- **H14** `done`: The README's note on names that two modules share leaves out `Resized`, which `shell.ern` uses as `Terminal.Resized` and as a bare `ScreenMsg` constructor on adjacent lines. (shell/README.md:28) — the README's note on shared names has `Resized`.
- **H15** `done`: The README says the Erlang front end serves "what only the compiler knows", but it also answers `write`, `setScreen`, `version`, `startupFiles` and `program`, which are the host's. (shell/README.md:3) — the README says the front end answers what only the compiler or the host can.
- **H16** `done`: A comment in `Shell.Complete` writes "after `:`" for a type annotation's colon, in a program where `:` begins a command. (shell/shell/complete.ern:278) — the comment says "where a type stands".

## The toolchain's code

### C, part 1, the front end with the Emacs mode, C1 to C36

Defects

- **C1** `done`: `ern_ast:free_names` skips a clause's pattern, so a local fn whose pattern's `size(n)` reads an outer name does not capture it, and `ern build` crashes. (erl/parser/src/ern_ast.erl:236) — `ern_ast:free_names` reads a pattern's bitstring size expressions, each in the scope of its bitstring's earlier segments, in a clause and a binding; regression test free_names_test.
- **C2** `done`: `ern_ast:free_names` binds a local fn only from the statement after it, not throughout its block (§5.4), and `ern build` crashes on a forward call. (erl/parser/src/ern_ast.erl:250 (and the comment at 224)) — a block's local fns are bound for all its statements, as §5.4 says, and the comment says so; regression test free_names_test, the reader's forward call beside a later `let`.
- **C3** `done`: The formatter strips four columns from a raw string's continuation lines in a body example of a doc block or a CommonMark text, changing the string's value. (erl/format/src/ern_format.erl:106 (dedent at 114-122)) — a wrapped example dedents only the lines no multi-line token continues on, a raw string's or a block comment's; regression test doc_example_raw_string_test.
- **C4** `done`: `ern format` lays out a module whose misplaced doc block the parser refuses, since it removes doc tokens before parsing. (erl/format/src/ern_format.erl:149 (split), 43) — `ern format` parses the module with its doc blocks in place, as `ern build` does, before the layout; regression test in not_parsed_test.
- **C5** `done`: The shell refuses a doc block typed alone instead of taking another line, though the declaration it documents can only follow on the next line. (erl/parser/src/ern_parser.erl:125-137) — a doc block with the end of input after it throws its diagnostic as incomplete, so the shell takes another line; regression test doc_placement_test.
- **C6** `done`: A parenthesized expression's span begins after its `(` but ends at its `)`, so a diagnostic underlines `1 + 2)` and `true)`. (erl/parser/src/ern_parser.erl:829-831) — a parenthesized expression spans its parentheses, so a diagnostic underlines `(1 + 2)` whole, and the formatter finds a node's parentheses at its own first token through the pairs map; regression cases in spans_test.
- **C7** `done`: An unclosed or extra bracket earlier in a file is reported as "a doc block documents nothing here" at a later, correctly placed doc block. (erl/parser/src/ern_parser.erl:122-150 (prune_docs, run before parsing)) — a doc block's refusal yields to an error no later than the token it stands above, found by parsing without the doc blocks; regression test doc_placement_test.
- **C8** `done`: The `a < -1` help line is missing where a `<-` stands in place of a block's `;` or `}`, or after a top-level body. (erl/parser/src/ern_parser.erl:971-972 and 178-181) — one helper, `expected_instead/2`, gives every failure at a `<-` the `a < -1` help, in `expect`, a block's separator, the declaration start and the input's end; regression cases in negative_comparison_help_test.
- **C9** `done`: The Emacs mode places a bitstring's further items at column 0 or under the call's bracket, where `ern format` aligns them under the first item after `<<`. (emacs/ernest-mode.el:489-500) — `<<` and `>>` are a bracket pair through `syntax-propertize`, `->`, `|>` and `<-` taken whole first, and a bitstring's items align under the first after `<<`; test/layout/bitstrings.ern joins the corpus.
- **C10** `done`: The Emacs mode puts the operand after an operator line that ends in a trailing comment at column 0, where `ern format` puts it at the operator's step. (emacs/ernest-mode.el:602-610) — a line after one whose code ends in a binary operator before a trailing comment carries it on, at the operator's step; test/layout/bitstrings.ern holds the layout.
- **C11** `done`: The lexer's octal messages read "a octal": "0o needs a octal digit" and "8 is not a octal digit". (erl/lexer/src/ern_lexer.erl:265, 272) — the base's name carries its article, "0o needs an octal digit"; regression cases in the lexer's number test.
- **C12** `done`: The Emacs mode's colours disagree with the lexer twice: `1.0e1_0` is painted only as far as `1.0`, and a `///` after a block comment is painted as an ordinary comment. (emacs/ernest-mode.el:180, 153-154) — an exponent's digits may be grouped with `_`, and a `///` with only white space and block comments before it on its line is painted a doc comment; a colour.el check for each, which fails on the old mode.

Clarity

- **C13** `done`: `ern_ast.hrl` documents a bitstring spec `{unit, integer()}` that the parser refuses and nothing builds. (erl/parser/include/ern_ast.hrl:97) — the spec() comment no longer names `{unit, integer()}`.
- **C14** `done`: `ern_ast.hrl` holds a "DeclName" comment attached to no record, and `#e_constructor.base` is documented as a record update's alone, leaving out the fill. (erl/parser/include/ern_ast.hrl:18-19, 86) — the DeclName lines stand above #fn_declaration{}, and #e_constructor.base is the expression after `..`, a record update's base or a fill's namespace.
- **C15** `done`: Sixteen test comments cite entries of a findings.md that no longer exists, "findings.md's P1-23", "findings C17", "C3-29". (erl/lexer/test/ern_lexer_tests.erl:74, 209, 267; erl/parser/test/ern_parser_tests.erl:160, 226, 600, 926; erl/format/test/ern_format_tests.erl:26, 320, 328, 335, 346, 353; erl/utils/test/ern_chunk_tests.erl:16, 30; erl/utils/test/ern_diagnostic_tests.erl:69) — every test comment and every comment in Ernest code that cited a review's list by its label states the defect in words instead, 145 places across the repository, and the citations of plan items and feedback items by number with them; a citation of the full review's design questions, which the log names in its entries' titles, stays. Same as C66, C99, C119, C171, C198, E61, E91, H7.
- **C16** `done`: `softline` is a layout element no template ever builds, handled in six places across the printer and the formatter. (erl/format/src/ern_pretty.erl:8, 31, 69, 71, 207, 209; erl/format/src/ern_format.erl:698, 747) — `softline` is gone from ern_pretty's type, print and fits and from ern_format.
- **C17** `done`: `#cursor.previous` is said to hold "the code token before" but holds a comment's kind too, and `#trivium`'s comment confuses its `line` field with a kind. (erl/format/src/ern_format.erl:24-27, 29-32 (set at 867, 916)) — #cursor.previous is the symbol of what was written last, a code token or a comment's kind, and #trivium's comment reads its fields apart.
- **C18** `done`: The lexer's main loop names its options parameter `_KeepComments` in its first clause and `Options` in every other. (erl/lexer/src/ern_lexer.erl:99) — lex/6's first clause names its parameter `_Options`.
- **C19** `done`: The parser abbreviates type variables as `Vars`, `Var`, `ForeignVars`, `AfterVars`. (erl/parser/src/ern_parser.erl:208-209, 447-456) — the parser's type parameters are `Parameters`, `Parameter`, `Variable` and `Written`, and the foreign type's parse is `foreign_type_parameter`.
- **C20** `done`: `worst` in the Emacs corpus tests holds the last misplaced line, which they print as "last". (emacs/test/flatten.el:16, 35-38; emacs/test/typing.el:37, 58-65) — `worst` is `last-moved` in flatten.el and typing.el.
- **C21** `done`: `reads_with_previous` names an index `At`, which the glossary refuses for an index. (erl/format/src/ern_format.erl:821-823) — reads_with_previous's index is `Each`.
- **C22** `dropped`: A token's position is a four-part tuple, and a span a three-part one, read by counting across the lexer, the parser, the formatter and the diagnostics. (erl/utils/src/ern_diagnostic.erl:48, 54-55; read at erl/parser/src/ern_parser.erl:1229, erl/format/src/ern_format.erl:844) — decided: *The Erlang Read and Renamed*: a term language stays tuples, the tokens and their positions and a node's span among them, since each is a format matched by shape and a record would add a definition for every reader and save none.
- **C23** `done`: `ern_namespace:erlang_module` cites report §4.2 for the `ern@` naming, which the report does not state. (erl/utils/src/ern_namespace.erl:89-90) — ern_namespace:erlang_module cites docs/style.md and the log's *One Token for the Project*.
- **C24** `done`: The Emacs mode cites the wrong report sections: declarations as "section 3", and its reserved words as restating Appendix A. (emacs/ernest-mode.el:296, 62-64, 73) — ernest-mode.el cites report section 4 for a declaration and sections 2.4 and 2.6 for the words and operators.
- **C25** `done`: The lexer's symbol list says "max-munch is clause order", but it is a list searched in order, not clauses. (erl/lexer/src/ern_lexer.erl:39) — the symbol list's comment says the first symbol found is the longest.
- **C26** `done`: Three preconditions break the style guide's form: an inverted `andalso`, a two-condition `orelse` chain, and a three-line `orelse`. (erl/lexer/src/ern_lexer.erl:110-112; erl/format/src/ern_format.erl:841-842; erl/parser/src/ern_parser.erl:303-305, 352-357) — the three preconditions are in style.md's form: `not is_after_token(...) orelse`, a `case` in consume/3, and the parser's messages named before one-line preconditions.
- **C27** `done`: `ern_lexer_tests` and `ern_parser_tests` open with `-module` and no comment stating their job. (erl/lexer/test/ern_lexer_tests.erl:1; erl/parser/test/ern_parser_tests.erl:1) — ern_lexer_tests and ern_parser_tests open with a comment stating what each tests.
- **C28** `done`: `misc_errors_test` checks fifteen unrelated refusals, and `errors_test` in the lexer's tests twenty, each under one name. (erl/parser/test/ern_parser_tests.erl:740; erl/lexer/test/ern_lexer_tests.erl:249) — the lexer's errors_test is four tests and the parser's misc_errors_test seven, each named for its rule.
- **C29** `done`: The reserved-word test omits `or`, one of §2.4's twenty words. (erl/lexer/test/ern_lexer_tests.erl:32-36) — reserved_words_test holds `or`.
- **C30** `done`: `ern_ast:walk` is said to visit records, but visits every atom-tagged tuple, `{positional, T}`, `{named, Fs}`, `{size, E}`, `{prelude, Q}`. (erl/parser/src/ern_ast.erl:173-176) — walk's comment says it visits every atom-tagged tuple, a record or a tagged part of one.
- **C31** `done`: The Emacs mode writes three walks twice: the previous and the next code line, the first-item and more-items comma searches, and the limit 100 in three loops. (emacs/ernest-mode.el:246-268, 466-487, 365, 386, 422) — the mode walks to a code line once, `ernest--code-line`, searches for a bracket's comma once, `ernest--comma-between-p`, and names the limit `ernest--walk-limit`.
- **C32** `done`: The per-application Makefile is copied byte for byte into every `erl/*/src`. (erl/lexer/src/Makefile:1 (and erl/parser, erl/format, erl/utils)) — erl/app.mk holds the rules once, each erl/*/src/Makefile includes it, and the line-length test reads it.
- **C33** `done`: A doc block inside a type's positional argument or a field's annotation is refused as "expected a type instead of doc comment", not as a doc block that documents nothing. (erl/parser/src/ern_parser.erl:129, 1241) — inside a type, a doc block documents a constructor or its `|` outside every bracket, or a named field's name, and one in a field's type documents nothing; the parser describes the token as a doc block; regression test doc_placement_test.
- **C34** `dropped`: One parser message cites report sections inside the diagnostic, "(§4.8, E.1)", which no other message does. (erl/parser/src/ern_parser.erl:304-305) — does not hold: §4.9 states this message verbatim with its "(§4.8, E.1)", and the checker's messages cite sections the same way (ern_typecheck.erl:703, 2048, 2233, 3875, 5328; ern_reply.erl:146, 155); X21 holds the citations' style.
- **C35** `done`: In typing.el the body of an `unless` is indented as its sibling. (emacs/test/typing.el:47-48) — typing.el is indented as emacs-lisp-mode does, with spaces.
- **C36** `done`: Missing spec: neither §11.5 nor §2.1 says how an excerpt shows a byte that is not UTF-8, or where "input is not valid UTF-8" stands. (erl/utils/src/ern_diagnostic.erl:133-138; erl/lexer/src/ern_lexer.erl:71-72) — §2.1 says a source that is not UTF-8 is an error at its first byte that begins no character, before any other, and §11.5 that an excerpt shows such a byte as U+FFFD, one column; reading it back found the excerpt keeping a leading byte-order mark as a column, which it now strips as the lexer does; regression cases in the lexer's and the excerpt's not_utf8_test.

### C, part 2, the checker, C37 to C71

Defects

- **C37** `done`: The checker crashes with an internal error when an unannotated fn's result type was fixed by an earlier use and its body gives another type (erl/typer/src/ern_typecheck.erl:3731) — an unannotated fn's body is checked against a variable of its own and then unified with the result type its uses gave it, so the mismatch is a diagnostic, "the body does not have the result type h's uses give it"; the body's own recursive use that would contain itself, a third crash, too; regression test unannotated_result_fixed_by_use_test and a catalogue entry.
- **C38** `done`: A reply in a declared type whose field is `List(a)` is not reply-carrying, so `Box(Reply(Int))` for `type Box(a) = Box(List(a))` is dropped silently (erl/typer/src/ern_typecheck.erl:848) — in_reply/3 reads a List's element as reply_in/3 does, and with_reply_params' comment says so; the report already said a list element carries a reply, so the soundness argument stands as written; regression test reply_in_a_list_field_test, and reply_carrying_by_the_fields_test, which had held the defect, corrected.
- **C39** `done`: A bitstring size naming an earlier segment's variable is counted as a reference to the top-level `let` of that name, so a false initialization cycle is reported (erl/typer/src/ern_typecheck.erl:1224) — a size expression in a pattern is read with its bitstring's earlier segments' variables bound, as §5.11 scopes them; regression test size_names_no_let_test.
- **C40** `done`: A `receive` guard's ordering is refused when its operands' type is fixed later in the definition, before operators are resolved (erl/typer/src/ern_typecheck.erl:3770) — a `receive` guard's ordering whose operand type is still a variable is deferred to the definition's end, a #deferred_guard_order{} beside the operator; regression test guard_order_fixed_later_test.
- **C41** `done`: The interface hash keeps type declarations' raw variable ids, so adding or reordering a type changes the hash of an equal interface and recompiles dependents (erl/typer/src/ern_interface.erl:58) — the canonical interface numbers each type's parameters by place and its constructors' schemes over the same numbers, as a value's scheme is numbered; regression case in interface_chunk_test.
- **C42** `done`: A requirement naming one member twice, `needs a.compare, a.compare`, is accepted and printed twice, where the report is silent (erl/typer/src/ern_typecheck.erl:1713) — the checker refuses a variable's member named twice at the second naming, "the requirement names a.compare twice", the first labelled, an operator's and a local fn's alike, and §4.9 and §11.5 say so; regression test requirement_named_twice_test and a catalogue entry.
- **C43** `done`: The prelude page prints the primitives' signatures from the table's text, without the `m+` mark §11.5 and `:type` print (erl/typer/src/ern_prelude.erl:503) — the page and `:doc` print each signature from its scheme since N3's work; the completion listing printed the table's text still, and now prints each prelude value's scheme. Same as T5, U4, N4.
- **C44** `done`: The prelude table lists `compare` for Int, Float and Char but not `String.compare`, which §9.6 lists beside them (erl/typer/src/ern_prelude.erl:463) — done with P10.
- **C45** `done`: A non-exhaustive match's missing case prints a named-field constructor bare, `Circle`, which is neither a value nor an accepted pattern (erl/typer/src/ern_exhaust.erl:267) — a named-field constructor with no field shown is written `Circle()`, §5.10's pattern for any of its values; regression case in the exhaustiveness test.
- **C46** `done`: After a round of solve_deferred solves something, the undetermined-operator error names a later operator in the source than the first (erl/typer/src/ern_typecheck.erl:2096) — of the unresolved deferred items the one first in the source is reported, `earliest/1`; regression test unresolved_operator_first_test.
- **C47** `done`: A fresh variable name past `z` is a nested list, so the 26th unnamed variable prints `a1` beside an annotation's own `a1` (erl/typer/src/ern_types.erl:706) — a name past `z` is a flat string, `a1`, compared with the names taken; regression test variable_names_past_z_test.

Clarity

- **C48** `done`: ern_typecheck's header lists a post-check of "undetermined block bindings (§4.6)" that does not exist, and omits checks that do (erl/typer/src/ern_typecheck.erl:11) — the header lists the steps post_checks/3 runs, in its order.
- **C49** `done`: format_result's comment says the parentheses make `with` read as the outer arrow's, the opposite of what they do (erl/typer/src/ern_types.erl:660) — format_result's comment says the parentheses keep the result's own `with` inside them.
- **C50** `done`: The printing section's banner says a process-only variable prints unchanged, while format_type/3 marks it `+` (erl/typer/src/ern_types.erl:386) — the printing banner says a process-only variable in no value position prints as `m+`.
- **C51** `done`: Three duplicate-declaration checks are unreachable, since declared_twice/1 has already refused every repeated type, constructor and value (erl/typer/src/ern_typecheck.erl:874) — the three unreachable refusals are gone; `not_prelude/2` keeps the refusal of a type named `Prelude`.
- **C52** `done`: format_error/1's clauses for `pure_vs_effect` and `mismatch` are dead, unify_message/5 handling both before it calls format_error (erl/typer/src/ern_types.erl:715) — format_error/1's `pure_vs_effect` and `mismatch` clauses are gone.
- **C53** `done`: by_first_segment/1 filters the first segments by the set of themselves, which keeps them all (erl/typer/src/ern_typecheck.erl:2791) — by_first_segment/1 iterates over the names in the order they first stand.
- **C54** `done`: selection/2 builds an `#e_var{}`, not a selection, for a path update's base (erl/typer/src/ern_typecheck.erl:2782) — the path update's base is written as the `#e_var{}` it is, and selection/2 is gone.
- **C55** `done`: `Owner` names a declared type in at_parameters, reach and cannot_derive, where the glossary keeps Owner for a resource's process (erl/typer/src/ern_typecheck.erl:694) — done with D27.
- **C56** `done`: A requirement is called `needs` in format_needs/3, needs/1 and the variable `Needs`, where the glossary says Requirement (erl/typer/src/ern_types.erl:522) — format_needs/3 is format_with_requirement/3, needs/1 requirement_of/1, and the variable RequirementText.
- **C57** `done`: ern_reply:value_variables/2 and ern_types:value_variables/2 share a name and differ in what they count and return (erl/typer/src/ern_reply.erl:104) — ern_reply reads ern_types:value_variables/2 and its own function of the name is gone.
- **C58** `done`: instantiate/2 repeats instance/2's fold, fresh_effect/1 is fresh/1 under a second name, and member_qualified_name/3 is session_member/3 under a second name (erl/typer/src/ern_types.erl:69) — instantiate/2 is instance/2 without the requirement, fresh_effect/1 is gone for fresh/1, and session_member/3 is exported under its own name.
- **C59** `done`: value_positions/3 restates value_args/3's choice of the arguments in value positions, and in_value/3 restates it a third time (erl/typer/src/ern_types.erl:469) — `ern_types:args_in_value/3` chooses a type's arguments in value positions once, which value_args/3, value_positions/3 and the checker's in_value/3 call.
- **C60** `done`: #type_info.params holds integers, atoms or type variables by kind of type and phase of checking, and a reader tests is_tuple to tell (erl/typer/include/ern_types.hrl:62) — #type_info.params holds a type variable for each parameter of every kind of type, built-in, foreign and declared, and the names a declaration writes stand in `param_names`; the interface's format is 5, and the hash leaves the names out as it leaves a value's out.
- **C61** `done`: A requirement has two shapes, `{Id, Member}` in a scheme and `{Type, Member}` at an instance, which requirement_text/3 tells apart by is_integer (erl/typer/src/ern_types.erl:536) — a scheme's requirement is turned into `{{tvar, Id}, Member}` before printing, so requirement_text/3 takes one shape.
- **C62** `done`: The variables a pattern binds are found by seven separate walks across the checker (erl/typer/src/ern_scope.erl:66) — `ern_ast:binder/1` decides what one node binds, the name after `as` at its own span, and `ern_ast:pattern_binders/1` gives a pattern's names with their spans and types, an `or` by its first alternative; pattern_bindings, ern_scope, the checker's four walks and ern_reply's read them.
- **C63** `done`: Every failed check rebuilds the prelude, reading each standard library .beam again, to label hidden prelude names (erl/typer/src/ern_typecheck.erl:186) — the checker labels hidden prelude names from the environment the check seeded, and the shell's session keeps the prelude's environment from its start, which completion, `:browse` and `:doc` read.
- **C64** `done`: The prelude's documentation names parameters its signatures never show, `v`, `mk`, `ms`, and uses `a` for both the address and the message type (erl/typer/src/ern_prelude.erl:304) — done with N3 and T22: the prelude's functions take names for their roles, and their pages say them.
- **C65** `done`: process_only/0 says it lists the primitives whose effect variables are process-only, but leaves out `self` and includes `monitor` and `spawnMonitored`, which need no listing (erl/typer/src/ern_prelude.erl:276) — process_only/0 lists the primitives whose effect variable stands in no value position, and says so; `monitor` and `spawnMonitored` are marked by signature_scheme as `self` is.
- **C66** `done`: Test comments cite entries of findings.md, `C2-3`, `R-6`, `P1-1`, though no findings.md is in the tree (erl/typer/test/ern_typecheck_tests.erl:691) — done with C15.
- **C67** `done`: warts_audit_test and smaller_silences_test are named after the audits that wrote them, and each tests several behaviours (erl/typer/test/ern_typecheck_tests.erl:1559) — the two tests are eight named for their behaviours, the two repeated foreign implementation cases dropped and the line-feed case moved into foreign_implementation_name_test.
- **C68** `done`: declared_scheme/3 takes the environment first, and set_scope/4 and set_effect_params/2 the type state first, against their modules' state-last order (erl/typer/src/ern_typecheck.erl:3388) — declared_scheme/3, set_scope/4 and set_effect_params/2 take their state last.
- **C69** `done`: ern_exhaust prints literal and bitstring witnesses and simplifies `{positional, none}`, none of which can occur (erl/typer/src/ern_exhaust.erl:250) — the literal and bitstring witness clauses and the `{positional, none}` simplification are gone, and the banner says why.
- **C70** `done`: derived_name/1 restates declaration_text/1, and needer_name/2's four declaration clauses each compute local_name/2 (erl/typer/src/ern_typecheck.erl:2914) — declaration_text/1 replaces derived_name/1, and needer_name/2 is three clauses over local_name/2.
- **C71** `done`: ern_bitspec names a constant size `Bits`, though for a `bytes` segment it counts octets (erl/typer/src/ern_bitspec.erl:52) — the constant size is `Count`, the unit saying what it counts.

### C, part 3, the emitter, C72 to C102

Defects

- **C72** `done`: A local fn that reads a local binding, or calls a local fn, named like a top-level declaration crashes the emitter (erl/emitter/src/ern_emitter.erl:1593) — a local fn's free name is a top-level declaration's only where no parameter, `let` before the fn, local fn or captured variable in scope binds it (`declared_local/6`'s `InScope`); regression test local_name_over_top_level_test.
- **C73** `done`: A bitstring pattern's size that names an outer variable, which the same pattern also binds elsewhere, crashes the emitter (erl/emitter/src/ern_emitter.erl:1896-1907, with `size_form/2` at 1947) — a bitstring pattern's sizes compile against the variables in scope before the pattern and those its own earlier segments bind (`pattern/2` sets `#emit_context.outer`); regression test pattern_size_reads_the_outer_scope_test.
- **C74** `done`: A bitstring construction evaluates a segment's size expression twice, so the size's effects happen twice (erl/emitter/src/ern_emitter.erl:393-395 and 1955-1961) — a segment's size that is neither a literal nor a variable is bound once before the binary, its value with it, in the segments' order (`segments_bound/2`); regression test construction_size_once_test.
- **C75** `done`: A spawn site and an initializer's fault name a function or `let` called `module_info` or `record_info` with the host's `$` (erl/emitter/src/ern_emitter.erl:1065 (`site/2`), fed by 251, 264 and 346) — done with C87: a spawn site and an initializer's fault name the declaration's Ernest name; regression tests host_named_site_test and the CLI's `record_info` initializer.
- **C76** `done`: A list literal of about a thousand calls fails in the host's compiler, which `$tests` already works around (erl/emitter/src/ern_emitter.erl:381-383 (`e_list`); compare 138-140) — a list or tuple literal of more than 256 elements is built an element at a time, from the first, onto the list so far (`built_in_order/2`); regression test long_literals_test_ of 1,100 calls.
- **C77** `done`: Identifiers of the 255 characters §2.3 allows crash the emitter, whose Erlang names add a suffix past the host's atom limit (erl/emitter/src/ern_emitter.erl:2010, 246, 2018) — a name the host cannot hold is refused with the limit in its message, as §11.1's new paragraph *Names the host holds* says: a module's Erlang name by the build at its file (`ern_build:module_of/3`), a member's, a foreign member's among them, and a `foreign fn`'s implementation's names by the checker; the emitter cuts its own names to fit (`host_name/2`); regression tests host_name_limit_test, module_name_the_host_cannot_hold_test and longest_names_test.
- **C78** `done`: The Docs chunk keys a function with a requirement by its written arity, not by the arity the module exports (erl/emitter/src/ern_docs.erl:60-67) — `doc_key/1` takes the arity `export/1` gives, the requirement's members counted; regression test docs_chunk_keys_and_types_test.
- **C79** `done`: `ern doc` drops the parentheses around a function-typed result under `with`, so the documented type is a different type (erl/emitter/src/ern_docs.erl:187-189) — `syntax_text` parenthesizes a function-typed result under an outer `with`; regression test docs_chunk_keys_and_types_test.
- **C80** `done`: `ern doc` prints a foreign fn's type without the restrictions §4.7 gives it and §11.5 prints (erl/emitter/src/ern_docs.erl:135-140) — settled before this batch: `ern doc` prints a foreign fn's signature from its scheme, as a `fn`'s.
- **C81** `done`: The emitter meets §5.1's left-to-right order only through the Erlang compiler's actual order, which Erlang's reference manual leaves unspecified (erl/emitter/src/ern_emitter.erl:826-829, 378-383, 452-462 (calls, tuples, lists, binops)) — the module's header states that §5.1's order rests on the host compiler's for calls, tuples, lists and operators, and order_of_evaluation_test pins each form.
- **C82** `done`: A descriptor's shape, shared by four modules, has no `-type`, and `describe/3` is specified as `term()` (erl/emitter/src/ern_descriptor.erl:18) — ern_descriptor owns `-type descriptor()`, which ern_boundary, ern_show and ern_io name in their specs; the described function is tagged `function`, and only the built form is `'fun'`.

Clarity

- **C83** `done`: Prefix `-` on a user type has an unreachable clause, and a user type's operators take two paths that duplicate `ordered/2` (erl/emitter/src/ern_emitter.erl:1152-1153, 1106-1120, 1169-1179, 444-445) — every known or required member goes through `member_applied/3` and `ordered/2`, and the user-type clauses of `binop/5` and `negate/3` are gone.
- **C84** `done`: A function crossing into foreign code is exposed two ways: `{callback, Make}` at top level, the `'fun'` descriptor's exposer when nested (erl/emitter/src/ern_emitter.erl:1278-1280, 1314-1317, 1345-1355) — a function crossing into foreign code is exposed through the `'fun'` descriptor's exposer alone; `callback_descriptor_form/2`, the `callback` clauses and ern_boundary's header lines on them are gone.
- **C85** `done`: ern_descriptor copies `ern_types:replace_variables/2` as `substitute/2`, the glossary's word for applying a Substitution, and copies ern_emitter's `text_binary/3` (erl/emitter/src/ern_descriptor.erl:133-144; erl/emitter/src/ern_emitter.erl:1398-1399) — ern_descriptor calls `ern_types:replace_variables/2`, and `ern_descriptor:cause/3` is the one copy of the fault text's binary.
- **C86** `done`: `ern_descriptor:descriptor/3` returns and threads `Seen`, which never changes on the way back (erl/emitter/src/ern_descriptor.erl:25-96, 118-119) — `descriptor/3` returns the descriptor alone, `Seen` passed down, and `descriptors/3` is a comprehension.
- **C87** `done`: `#emit_context.function_name` holds the Erlang function's name yet is read as the Ernest one, and the record's comment skips six fields (erl/emitter/src/ern_emitter.erl:19-35) — `#emit_context.declaration` holds the declaration's Ernest name, `[Name]` or `[MemberOf, Name]`, from which `function_name/2` makes the Erlang one, and the record's comment documents every field.
- **C88** `done`: `#local_fn{own, extra}` and `instances/2` do not say what they hold: free Ernest names, Erlang variables, and the variables a lifted function takes first (erl/emitter/src/ern_emitter.erl:38, 1522-1526, 1622) — `#local_fn{}` holds `captured`, the Ernest names, and `enclosing`, the Erlang variables, documented at the record; `instances/2` is `captured_variables/2`.
- **C89** `done`: Several yes-or-no functions read as nouns or verbs: `open/1`, `plain/1`, `erlang_guard/3`, `guard_operand/2` (erl/emitter/src/ern_emitter.erl:1966, 1263, 1827, 1846) — `is_open/1`, `is_plain/1`, `is_erlang_guard/3` and `is_guard_operand/2`.
- **C90** `done`: `Named` names two things in neighbouring functions: the type variables the parameters name, and the type a fault's text names (erl/emitter/src/ern_emitter.erl:329 and 1225) — `foreign_return/4`'s list is `ParamVariables` and `check_form/5`'s parameter `Shown`.
- **C91** `done`: The variables the emitter makes reuse one letter for several concepts, and name the scrutinee two ways, in `--emit-erl` output meant for reading (erl/emitter/src/ern_emitter.erl:458, 1433, 1504 ("F"); 689, 885, 1683 ("S"); 493 ("Scrutinee"); 310, 1554 ("E")) — each made variable has one whole-word prefix per concept, `Argument`, `Operand`, `Field`, `Base`, `Supplied`, `Function`, `Scrutinee`, `Class`, `Error`, `Trace`, `Left`, `Checked`, `Zero` and `Tests`, and the golden files are written again.
- **C92** `done`: Functions thread `Context` through four numbered steps, and one numbers from `Context0`, against docs/style.md's numbering rule (erl/emitter/src/ern_emitter.erl:808-809; also 248-261, 412-424, 528-550, 683-696, 1548-1570) — `Context` is numbered from 1, and no function threads it past two steps: the parameters and members are `head_patterns/3`, a foreign body `foreign_body/5`, the supplies `supplied_lambda/4`, a clause's pattern and guard `clause_head/3`, and a receive, a `<-` and an update's base steps of their own.
- **C93** `done`: `supply_form/2` makes up a span and a function type, with a wrong result for `compare`, only to reuse `prelude_value/4` (erl/emitter/src/ern_emitter.erl:869-875) — a prelude member's value is `member_value/3` from its qualified name and arity, with `operator_value/3` for an inline operator; no span or function type is made up.
- **C94** `done`: `arity_of/2`'s failure text names a local function, though three other callers reach it (erl/emitter/src/ern_emitter.erl:725) — `arity_of/2` says "a function used as a value must have a function type".
- **C95** `done`: `statements/3` catches a block that ends in `let p = e` but not in `let p <- e`, which crashes with `function_clause` (erl/emitter/src/ern_emitter.erl:1534-1538) — `statements/3`'s failing clause takes a last `#binding{}` of either operator.
- **C96** `done`: `ern_emitter:erlang_module/1` only wraps `ern_namespace:erlang_module/1`, so one function has two names, with 31 callers on the wrapper (erl/emitter/src/ern_emitter.erl:201-204) — every caller calls `ern_namespace:erlang_module/1`, and ern_emitter's wrapper is gone.
- **C97** `done`: Two comments no longer hold: the module header omits the Docs chunk, and `binop/5`'s counts Int beside "the four ordered prelude types" (erl/emitter/src/ern_emitter.erl:1-4, 1080-1081) — ern_emitter's header names both chunks, and `binop/5`'s comment names the four ordered prelude types.
- **C98** `done`: `ern_emitter_tests` holds the runtime's and the library's tests under the emitter's name (erl/emitter/test/ern_emitter_tests.erl:2390-2845 (Supervisor, E.22), 2846-3110 (Os, E.23), 3122-3160 (the reaper), 3297-3600 (Tcp, E.18), 600-1100 (restarts §6.9, deadlock §8.6, the terminal §8.2)) — `ern_supervisor_tests`, `ern_restart_tests`, `ern_reaper_tests` and `ern_system_module_tests` hold the Supervisor, restart, reaper and deadlock, Os, Fs, Tcp and terminal tests, sharing `ern_emitter_tests:run/3` and `scratch/0`; docs/architecture.md names them.
- **C99** `done`: Test comments cite `findings.md`, which no longer exists, by its review-local ids, and one cites the plan where a section belongs (erl/emitter/test/ern_emitter_tests.erl:773, 1658, 3204, 3348, 3368-3369, 3407, 3463, 3479, 3505, 3535, 3771) — done with C15; the atoms test cites docs/memory.md.
- **C100** `done`: Three test comments describe what the code no longer does or the test does not test (erl/emitter/test/ern_emitter_tests.erl:1307-1309, 3796-3799, 3387-3391) — the three comments say what the code does and the test tests.
- **C101** `done`: `prelude_targets_test` maps every two-part operator to a dummy target, so the remote calls the emitter makes for them go unchecked (erl/emitter/test/ern_emitter_tests.erl:2335-2359) — `prelude_targets_test` treats only Int's arithmetic and negate and the `<>` of String and Bytes as inline, and checks Float's operators and `List.<>` and `Path.<>` against their modules' exports.
- **C102** `done`: The test module holds a raw newline inside a string, an export list out of source order, and a macro between its includes (erl/emitter/test/ern_emitter_tests.erl:683, 3-5, 13-21) — the raw newline is `\n`, the export list is in source order, and `UP` moved with the restart tests, after their includes.

### C, part 4, the runtime with its helper in C, C103 to C135

Defects

- **C103** `done`: `Fs.removeAll` given a link to a directory with a trailing slash follows the link, empties its target, then fails: E.17's "a link is removed, not followed" is broken (erl/runtime/c_src/ern_exec.c:440-455 (`remove_all`), report Appendix E.17) — the helper strips a path's trailing slashes and removes its last name relative to the directory before it, `remove_entry/2`, so a link is removed and never followed; regression test fs_remove_all_link_with_a_slash_test, which fails with the old helper.
- **C104** `done`: A fault sent as an exit signal kills a restarting process instead of restarting it: a mismatched foreign message, or a subscription while the shell holds the terminal. (erl/runtime/src/ern_boundary.erl:354; erl/runtime/src/ern_tty.erl:65, 121; report §6.9, §7.4, §8.4) — decided with the user: the fault takes the bad message's place and lands at the next wait, which `restarting` restarts (§8.4; the log's *The Full Review's Questions, One by One*).
- **C105** `done`: `Os.start` with an empty program name, and `Fs.removeAll` on an empty path, fault "the runtime's helper ern_exec failed" instead of answering `Left(NotFound)` (erl/runtime/c_src/ern_exec.c:279, 469; report Appendix E.17, E.23) — the helper takes an empty program name, which `execvp` finds nowhere, and an empty path, which names nothing, so `Os.start` and `Fs.removeAll` answer `Left(NotFound)`; regression tests os_run_refusals_test and fs_remove_all_link_with_a_slash_test.
- **C106** `done`: Foreign code monitoring a process can see exit terms beyond §8.4's four: `{ern, fault, Cause, Trace}`, `{ern, code_unloaded}` and `{ern, closed}` (erl/runtime/src/ern_rt.erl:1011-1012, 405; erl/runtime/src/ern_tcp.erl:203, 290; report §8.4) — §8.4 lists every exit term the runtime gives: `{ern, fault, Cause, Trace}`, a socket's or a listener's `{ern, closed}`, which is `Returned`, and the shell's `{ern, code_unloaded}` among them; §6.9 says an end the host gives is `Fault(text)`, and E.21 that a trace is twelve frames; regression tests host_exit_reason_test, host_ended_process_test and closed_listener_exit_term_test.
- **C107** `done`: The terminal's settings are read by `sh -c "stty -g"`, which finds `sh` and `stty` through PATH. That contradicts the rule stty/1 states, that only the system's stty runs (erl/runtime/src/ern_tty.erl:348-358, against 326-327) — `settings/0` runs `/bin/sh` by its path over the stty `system_stty/0` finds, never one PATH names; no test reaches it, since only a terminal's settings are read, and the terminal harness drives it.
- **C108** `done`: E.18 omits writes already handed to the writer at `Tcp.close`; their answer depends on the writer draining its queue before the link's exit signal arrives. (erl/runtime/src/ern_tcp.erl:285-290, 243-255; report Appendix E.18) — done with S1: each write the socket holds at its close answers `Left(Closed)`, and E.18 says so.
- **C109** `done`: `Fs.setModified` with a time the host cannot hold answers `Left(Other("bad argument"))`, a case E.17 does not cover, where E.1's `Invalid` is "an argument the host cannot take" (erl/runtime/src/ern_fs.erl:125-134; report Appendix E.1, E.17) — the host's `badarg` and the kernel's `einval` are `Invalid` in `ern_io:host_error/2`, so a time past the host's 64-bit seconds answers `Left(Invalid)`; E.1's `Invalid` and E.17's `setModified` line say so, and that one past a file system's range is kept as it keeps it; regression test fs_set_modified_past_the_host_test.
- **C110** `done`: One host error gets two texts: `Os.start` answers strerror's "Too many open files", while `Fs` and `Tcp` answer "too many open files" (erl/runtime/c_src/ern_exec.c:152-161 (`error_name`) against 309-328 (`posix_name`); erl/runtime/src/ern_os.erl:349) — the helper's two jobs send one name for an error, `posix_name`, which `ern_io:helper_error/1` describes as the file module's errors are: `emfile` is "too many open files" from `Os.start` as from `Fs`; ern_os_tests' expectations changed with it.
- **C111** `done`: Two standard library tests listen on fixed ports 7411 and 7412, so they fail whenever another program on the machine holds either port (erl/runtime/test/ern_stdlib_tests.erl:967, 989) — both tests listen on port 0, the second program asking for the port the first was given.

Clarity

- **C112** `done`: ern_rt's header says four tables hold the run's state, but `make_tables/0` makes six. `ern_callees` and `ern_deliveries` are missing from the header (erl/runtime/src/ern_rt.erl:27-36, 1546-1552) — done with C121: ern_rt's header names its nine tables.
- **C113** `done`: ern_fs's header gives an Entry four fields, but `entry/2` builds six, including mode and user (erl/runtime/src/ern_fs.erl:5-6, 246-247) — ern_fs's header lists the Entry's six fields.
- **C114** `done`: ern_os's comments still say a program dies with "the process that started it", but since `Give` the code watches the program's owner (erl/runtime/src/ern_os.erl:8-9, 321-322, 336-337) — ern_os's three comments say "its owner".
- **C115** `done`: A test comment speaks of "a via proxy", but `via` makes no process (§6.5); the very next test asserts this (erl/runtime/test/ern_rt_tests.erl:742-743) — the test's comment says a message an alarm delivers through `via` is in flight until its delivery process ends.
- **C116** `done`: ern_tcp's comments are out of date. The `#connection{}` comment leaves out the `writes` field, and the header claims every waiting request is counted, though Listen's worker is not (erl/runtime/src/ern_tcp.erl:7-8, 18-24, 45) — `#connection{}`'s comment names `writes`, and the header says which requests are counted and that a listen's caller's call covers it.
- **C117** `done`: ern_stdlib_tests' first comment promises one test per module, but String alone has six tests (erl/runtime/test/ern_stdlib_tests.erl:1-2) — ern_stdlib_tests' first comment says "by module".
- **C118** `done`: `doc_of/1` says it answers `none` for a node with no doc, but a declaration without one answers `undefined`, and `documented/1` depends on that (erl/runtime/test/ern_doc_tests.erl:318, 231) — `doc_of/1`'s comment says it answers `undefined` for a declaration without a doc, which documented/1 looks for, and `none` for a node that carries none.
- **C119** `done`: Test comments cite `findings.md`'s entries (C29, C7, K-15, E15…), but that file is gone, and "C-1" names two different defects. (erl/runtime/test/ern_rt_tests.erl:89, 200, 335; ern_os_tests.erl:9, 38, 95, 178; ern_tcp_tests.erl:200, 217, 266; ern_tty_tests.erl:260; ern_stdlib_tests.erl:45, 263, 296, 924, 1092, 1097; ern_show_tests.erl:20; ern_doc_tests.erl:68) — done with C15.
- **C120** `done`: Source and test comments carry history: "since 2026-09-20", "A regression: …", "the rule of 2026-10-01". These describe the past, not why the code is as it is (erl/runtime/src/ern_tty.erl:24, 272, 429-430; erl/runtime/test/ern_os_tests.erl:9, 145, 162, 203; ern_tcp_tests.erl:66, 139, 337; ern_stdlib_tests.erl:28, 492, 735, 857, 1086, 1143) — the runtime's comments and tests keep each rule and its section, and drop the dates; ern_tty's two stories say why instead.
- **C121** `done`: ern_rt's process rows are positional 5-tuples, updated by field number (`count(3, …)`, `count(4, …)`, `{2, Site}`). The `ern_processes` table also holds five other kinds of row (erl/runtime/src/ern_rt.erl:27-33, 731-732, 936-940, 964-965, 1727) — the restart rows are `ern_restarts`, the proxies' `ern_proxies`, and the terminal's way and the deadlock's victim `ern_launch`, so `live_rows/0` reads `ern_processes` whole; docs/architecture.md and docs/memory.md list the nine tables, and `make load` counts their rows.
- **C122** `dropped`: Runtime values that cross modules are positional tuples: `{via, …}`, `{foreign, …}`, `{foreign_reply, …}`, and a six-part `'fun'` descriptor that has two shapes under one tag. (erl/runtime/src/ern_boundary.erl:17-32, 119, 126, 294; ern_rt.erl:87-92; ern_show.erl:58, 114-115, 133) — decided: *The Erlang Read and Renamed*: a term language, the descriptors and the runtime's forms of a value among them, stays tuples matched by tag, and `-type address()` and ern_boundary's header document them; its one new point, two `'fun'` shapes under one tag, is C82's fix. Same as C82.
- **C123** `done`: ern_rt names the request-making function `Mk`, an abbreviation, where §6.6 calls it `request` (erl/runtime/src/ern_rt.erl:216, 223, 233, 264, 270, 275) — `Mk` is `Request` in ern_rt.
- **C124** `done`: The stdout and stderr host port is named `Port`, against the glossary, and the clock record's `time` field holds a function that reads the clock (erl/runtime/src/ern_rt.erl:1062, 1080-1120, 1385, 1391, 1479) — the stdout and stderr port is `Stream`, its loop `stream_loop/2`, and the clock record's reader of the clock `read_time`.
- **C125** `done`: In ern_fs, `Name` means both a path's text and an error's name, and `Path` means both a `{'Path', _}` value and a raw binary (erl/runtime/src/ern_fs.erl:34, 227-232, 243, 292) — ern_fs names a path's text `Text`, an entry's name `EntryName` and its path `EntryText`, and the helper's error word `ErrorName`.
- **C126** `done`: Several helpers are written twice: `is_utf8` and `utf8`, `name_bytes` and `name`, two `io_error` mappings, and `error_name` beside `posix_name`. `host/0` also copies helper_failed's text three times (erl/runtime/src/ern_fs.erl:213, 218-223, 299-307; ern_os.erl:360, 364, 379, 390-391, 407-408; ern_tcp.erl:428-434; c_src/ern_exec.c:152-161, 309-328) — done with C110: one Io.Error mapping, `ern_io:host_error/2`, with `helper_error/1` for the helper's names; `ern_fs:is_utf8/1` and `name_bytes/1` serve ern_os; `host/0` faults through `helper_failed/0`.
- **C127** `done`: The spawn order has four names: `Spawned` in the header, `spawn_number/0`, `spawn_order/1`, and `Number` in the pattern (erl/runtime/src/ern_rt.erl:29-30, 558-561, 1828-1833) — the spawn order is `SpawnOrder` in the header and the pattern, and `next_spawn_order/0` makes it beside the reader `spawn_order/1`.
- **C128** `done`: ern_tcp_tests calls `Tcp.remote`'s request `peer`, in its helper and in its comment, though the library and the message call it `Remote` (erl/runtime/test/ern_tcp_tests.erl:61-62, 80, 84, 413-414) — ern_tcp_tests' helper is `remote/1`, and its comment says `remote`.
- **C129** `done`: Tests use single letters and abbreviations across multi-line scopes (`T`, `D`, `S`, `L`, `N`, `Tab`, `Conn`, `Bin`), and the laws tests name a host error `Reason` (erl/runtime/test/ern_os_tests.erl:47, 89, 105-106; ern_tcp_tests.erl:15, 72, 97-98, 370; ern_rt_tests.erl:57, 91; ern_tty_tests.erl:106; ern_stdlib_tests.erl:568, 586; ern_laws_tests.erl:1007) — the tests' variables are `Tag`, `Frame`, `Status`, `Connection` and `Bytes`, and the laws tests' host error `Class:Error:Trace`; the queue's table went with C130.
- **C130** `done`: The queue-fed input function is written out four times in the tests: two copies in ern_rt_tests, one in ern_tty_tests, one in ern_stdlib_tests (erl/runtime/test/ern_rt_tests.erl:57-64, 91-98; ern_tty_tests.erl:106-113; ern_stdlib_tests.erl:586-593) — `ern_rt_tests:queued_input/2` is the one queue-fed input, which the four tests share.
- **C131** `done`: ern_doc_tests carries dead weight: `run_example/4` takes an unused `_Cwd`, `erlang_module/1` only forwards to ern_namespace, and `collect/1` and `collect/2` collect alike but return different shapes (erl/runtime/test/ern_doc_tests.erl:122, 128, 148-151, 163-168, 374-375) — `run_example/5` is `run_example_here/4` without `_Cwd`, the `erlang_module/1` wrapper is gone, and one `collect/2` collects.
- **C132** `done`: `exit_program/1` writes a two-condition precondition on one line, where docs/style.md asks for a `case` (erl/runtime/src/ern_rt.erl:1658) — `exit_program/1`'s range check is a `case` that faults.
- **C133** `done`: The helper's `SIGNALS` comment says the constant is past the highest signal number, but the loop includes it, and 64 is Linux's highest signal itself (erl/runtime/c_src/ern_exec.c:83-85, 529) — the `SIGNALS` comment says the highest signal number of a host Ernest runs on.
- **C134** `done`: ern_rt_tests has three small faults: no first comment stating its job, a `wait(counts2)` clause that receives `{counts, …}`, and a proxy test that cites §6.3 (`receive`) (erl/runtime/test/ern_rt_tests.erl:1, 770, 786, 834, 838-839) — ern_rt_tests has its first comment, `wait_counts/0` reads the counts, and the proxy test cites §6.5 and §8.4.
- **C135** `done`: `ern_tcp:listen/5` takes `(Tcp, Host, Owner, Port, Reply)`, while the message and `connect/6` order them Host, Port, …, Owner (erl/runtime/src/ern_tcp.erl:44-45, 74, 137) — `listen/5` takes `(Tcp, Host, Port, Owner, Reply)`, the message's order.

### C, part 5, the shell's Erlang, C136 to C175

Defects

- **C136** `done`: A `let` of the name `it` or `declarations` is taken for an expression or for declarations, since the input's binds tag is the bare name (erl/cli/src/ern_shell.erl:204) — a `let`'s name is tagged `{name, Name}` in `#checked.binds`, so no name stands for the tags `it` or `declarations`; regression test let_of_a_tag_name_test_.
- **C137** `done`: `:load` of a compiled module found under a path with a non-ASCII character ends the shell with status 70 (erl/cli/src/ern_shell.erl:1605, and 1597) — `:load`'s answers decode the path as UTF-8; regression test load_compiled_test_ under `łódź`.
- **C138** `done`: `:load` of a module whose compiled file cannot be read ends the shell with status 70 (erl/cli/src/ern_shell.erl:2091) — `compiled_of/2` refuses a `.erc` it cannot read with the file and the host's reason, and the session goes on; regression test load_compiled_test_.
- **C139** `done`: A binding whose closure captures a function of a reloaded module is neither listed nor forgotten, and faults with the host's `badfun` once that version is purged (erl/cli/src/ern_shell.erl:2030) — a binding runs the version of the module it holds a function of, in its data, a closure's captures, or a binding a function of its value reads (`functions_run/2`, by each local function's `new_uniq`, the code's md5); `holds_fun/2` is gone, and §11.2 says when a binding holds a function of a version; regression test reload_bindings_test_.
- **C140** `done`: A further `:reload` forgets a binding taken from the version it replaces, which stays loaded, and reports it ended (erl/cli/src/ern_shell.erl:2007, end_previous/2, with bindings_of/2 at 2018) — a reload lists the bindings that run the version it replaced and forgets those that run the version it purges, and no other; regression test reload_bindings_test_.
- **C141** `done`: `:reload` refuses a changed module that has come to use a module whose source the source root holds, where `:load` would compile it (erl/cli/src/ern_shell.erl:1876, compile_all/2) — `compile_all/2` gathers what the changed modules have come to use whose sources the source root holds, as `with_sources/3` does for `:load`, and the reload answers "compiled from" for each; regression test reload_new_dependency_test_.
- **C142** `done`: A `let` with a pattern whose line ends unfinished runs at `Enter` instead of taking the next line (erl/cli/src/ern_shell.erl:142) — `needs_more/1` tries the statement reading too; regression test pattern_let_continues_test_.
- **C143** `done`: Each `Tab` after an unknown word and a `.` makes an atom the host keeps for ever, since fields/1 parses with names made (erl/cli/src/ern_shell.erl:1138) — `fields/1` reads its text with `no_new_names` through `input/2`; typing_makes_no_names_test_ covers it.
- **C144** `done`: `Shift-Tab` on a function makes the atom of an Erlang module named for the whole name, `ern@list@filter`, which the host keeps for ever (erl/cli/src/ern_shell.erl:1497) — `beam_on_path/1` seeks a module by its name as a string and a loaded one by an existing atom; typing_makes_no_names_test_ covers `List.filter`, and fails against the old shell.
- **C145** `done`: A failed `:load` leaves the values its bindings evaluated stored for the life of the node (erl/cli/src/ern_shell.erl:1710, withdraw/1) — `withdraw/2` erases the store's keys of the withdrawn module's lets, which its interface lists; regression test stored_values_go_test_.
- **C146** `done`: A binding that a reloaded module no longer declares keeps its value stored for the life of the node (erl/cli/src/ern_shell.erl:1969, reload_one/2) — `dropped_lets/3` keeps the keys of the lets a reload drops until the reload that purges the version that declared them, which erases them; regression test stored_values_go_test_.
- **C147** `done`: Every binding is a persistent term erased when `it` is next replaced, paying at almost every input the scan of all processes the front end's table avoids (erl/cli/src/ern_shell.erl:2282, with 2224, against the comment at 58-66) — the comment on where the shell's state lives says a binding's value is §8.5's store, a persistent term, whose release scans every process, as *The Hardening Built* decided.
- **C148** `done`: `:doc` and `Shift-Tab` show a module's name with the page's type, `Entry`, and not the type the shell prints, `Fs.Entry` (erl/cli/src/ern_shell.erl:1505, entry/2, through module_doc/2 at 1471) — a module's value is shown in `:doc` and `Shift-Tab` with the type `:type` prints, `ern_page:declaration/3` taking the signature, and a type's page its own; the prelude's already agreed; regression test doc_types_as_the_shell_prints_test_.
- **C149** `done`: `Shift-Tab` drops a module's version from a declaration whose doc text holds `*Since `, since it searches the rendered page for it (erl/cli/src/ern_shell.erl:1091) — the brief's version comes from the declaration's documentation entry, `ern_page:declared_since/2`, not from searching the page; regression test brief_module_version_test_.
- **C150** `done`: `Shift-Tab` on a member of a module's type, `Shape.Point.compare`, shows no version, since its module is sought one segment back only (erl/cli/src/ern_shell.erl:1112, module_of_name/2) — `declaring/2` seeks a member's module two segments back; regression test brief_module_version_test_.
- **C151** `done`: `Shift-Tab` inside a call of a function named with a leading `_` shows nothing, the name being taken for a constructor's (erl/cli/src/ern_shell.erl:1167) — a callee is a constructor only where its name begins with `A` to `Z`; regression test underscore_signature_test_.
- **C152** `done`: `:bindings`, `:browse` and completion print a foreign type as `type`, where its declaration prints `foreign type` (erl/cli/src/ern_shell.erl:969) — `type_keyword/1` gives `foreign ` for a declared foreign type, and nothing for a built-in, which the checker also holds as foreign; `:bindings`, `:browse` and completion use it; regression test foreign_type_listed_test_.
- **C153** `done`: input_module_unloaded_test_'s bound passes the very regression it guards against, and two tests' "Not covered" notes no longer hold (test/ern_shell_tests.erl:1330, and 1309, 1337, 1354) — the two tests are bounded at a handful, five modules and sixty atoms, and their notes on MVP 2.65 are gone.
- **C154** `done`: The shell's terminal tests never check that the shell ended, so one that no longer exits passes after the harness kills it (test/ern_shell_tests.erl:2724) — `raw/4` asserts the shell's exit status, 0, through `ern_pty:run/4`, which reads the harness's `status` line.
- **C155** `done`: Two specs do not hold: slot/1 gives `Name` tuples, not binaries, and to_screen/1 gives `'Unit'`, not `ok` (erl/cli/src/ern_shell.erl:626, 2132, and 462) — the specs of slot/1, to_screen/1 and run/4 say what each gives, `ern_rt` exporting `address()`.
- **C156** `done`: terminal_test_'s last assertion repeats the `Killed` match, so its comment's claim, that the session was not ended, is not asserted there (test/ern_shell_tests.erl:2665) — terminal_test_ asserts `Killed` once and the next answer after it, and its comment names the exit status raw/4 asserts.

Clarity

- **C157** `done`: The code for a `let` in a declaring input is never reached, since declarations/1 refuses one: `'$init'`, stored values, keys and three clauses (erl/cli/src/ern_shell.erl:585, with 2164-2171, 512, 285, 2479, 2498) — the code for a `let` in a declaring input is gone, and declarations/1 says once that a declaring input holds none.
- **C158** `done`: one_let/1's comment describes `let T.name`, a member `let` the language does not have (erl/cli/src/ern_shell.erl:269) — one_let/1's sentence on `let T.name` is gone.
- **C159** `done`: The session record's comment says `beams` holds declaring inputs, but it holds every module `:load` and `:reload` compile too; `#checked{}`'s names half its fields (erl/cli/src/ern_shell.erl:43, and 45-47) — `beams`' comment names both kinds of module, and `#checked{}`'s every field.
- **C160** `done`: fault_text/2 and its two catch clauses restate ern_rt:fault_exit_reason/3, which already turns a host error into a fault's cause (erl/cli/src/ern_shell.erl:591, with 488-490 and 1749-1751) — run/4 and initialize/3 catch `Class:Error:Stack` and take the cause from `ern_rt:fault_exit_reason/3`; fault_text/2 is gone.
- **C161** `done`: constructor_scheme/2 repeats constructor_info/2's scan, and one_constructor/2 walks every type where a key lookup would do (erl/cli/src/ern_shell.erl:781, with 1268 and 718) — constructor_scheme/2 is written over constructor_info/2, and one_constructor/2 looks the type up by its key.
- **C162** `done`: The purge of a deleted session module is retried in release/3 and again in collected/1, and its pending modules live in two homes in two forms (erl/cli/src/ern_shell.erl:525-549, and 2262-2295) — collected/1 alone retries a purge; the modules awaiting it, holders and inputs alike, are the kept row `unpurged`, and the numbers free to give again the row `free`, each as a namespace; the session's `free_holders` and `draining` are gone.
- **C163** `done`: is_module_file/2 and session_module/1 restate the rule that names an Erlang module, which ern_namespace:erlang_module/1 owns (erl/cli/src/ern_shell.erl:1012, and 2342) — `ern_namespace:erlang_module_text/1` takes a segment as its text too, and is_module_file/2 and is_session_module/1 use it.
- **C164** `done`: Several names do not say the value they give, and yes-or-no functions do not read as the question (erl/cli/src/ern_shell.erl:242, 1281, 768, 2207, 2199, 2335, 2342, 369, 1775) — reported_diagnostic/4, enclosing_call/1, is_name_text/1, is_open/2, is_unbound/1 with shell.ern's `isUnbound`, is_session_segment/1, is_session_module/1, reply_refusal/4 and kept_values_line/2.
- **C165** `done`: `Held`, `Source`, `Modules`, `Bound`, `Changed`, `Sourceless` and `Unpurged` each name two or three things (erl/cli/src/ern_shell.erl:2167, 2232, 2279, 951, 1669; 158, 1515, 1588; 1825, 1618, 1640; 484, 2216; 1828, 1938; 1832, 1891; 528-529) — each concept has its name: `Found` for an interface's namespace, `Listed`, `FileNamespace`, `LoadedInterfaces`, `HeldModule`, `FunctionModules`, `StillRun`; `InputOrigin`, `Declaring`, `SourceText`, `SourceFile`; `ModuleNames`, `CompiledModules`, `SourceHashes`; `BoundSession`, `Bindings`, `BoundName`; `ChangedSources`, `InterfaceChanged`; `SourcelessLines`, `SourcelessUsers`; the session's field `modules` is `source_hashes`.
- **C166** `done`: A refusal ends in a line feed for `:load` and `:reload` and not for `:forget`, `:browse` and `:doc`; `:browse` also keeps a trailing dot `:load` drops (erl/cli/src/ern_shell.erl:1571, against 909, 930 and 1065) — every refusal the front end answers ends with no line feed, check/3, load/2 and reload/1 trimming theirs at the boundary, and the shell ends each with one, in `say` and `diagnose` alike; `:browse` names a module without its trailing dot.
- **C167** `done`: fields/1 numbers the session's next input before checking, though check_module/6 never reads the number and the session is dropped (erl/cli/src/ern_shell.erl:1140) — fields/1 passes the session as it is.
- **C168** `done`: refused_compiled/2 passes the working directory where ern_build:stdlib_hash/1 takes a source root, with no word on why (erl/cli/src/ern_shell.erl:1657) — the shell's refused_compiled/2 asks for the installed library's hash with no source root, ern_build:stdlib_hash/0, with C176.
- **C169** `done`: Two code comments carry a defect's history, where docs/style.md has a comment say why and cite the report (erl/cli/src/ern_shell.erl:1874, and 2057) — compile_source/3's story is gone; both stories stand in load_and_reload_dependents_test_'s comment.
- **C170** `dropped`: ern_shell.erl does five jobs in 2504 lines, where docs/style.md gives a module one (erl/cli/src/ern_shell.erl:1) — decided: *Where the Toolchain's Modules Split*: a part that threads the module's private record stays with it, and *The Closing of Step 10* kept `ern_shell` whole by that rule; every job the finding names reads `#session`, and it names no part that shares nothing.
- **C171** `done`: Test comments cite entries of a findings.md that no longer exists, and plan item numbers, which a reader cannot open (test/ern_shell_tests.erl:138, 170, 193, 205, 232, 249, 269, 297, 332, 411, 640, 725, 831, 855, 2043, 2078, 2497; test/ern_terminal_tests.erl:52, 132) — done with C15, the plan items' numbers replaced by what each test guards.
- **C172** `done`: ern_pty.py's comment on its `pty` import no longer holds (test/ern_pty.py:48) — ern_pty.py imports `pty` plainly.
- **C173** `done`: The two test modules each write their own copy of the harness's helpers (test/ern_terminal_tests.erl:210-258, and test/ern_shell_tests.erl:2696-2748) — test/ern_pty.erl holds the harness's call and its helpers, `run/4`, `sh/1` and `count/2`, which both suites use; its `sh/1` runs `/bin/sh -c` with the command as one argument.
- **C174** `done`: review_completion_test_ is named for where its cases came from and tests five behaviours (test/ern_shell_tests.erl:1169) — review_completion_test_ is five tests, each named for its behaviour, each waiting for an answer before it types.
- **C175** `done`: The shell's tests leave their homes, sources and inputs under /tmp, and their step files under test/build (test/ern_shell_tests.erl:2379, and 2729) — the shell suite makes its homes, sources, inputs and step files under one directory per run, `ern_pty:run_dir/0`, which `make test-shell` makes and removes.

### C, part 6, the rest of the command line, C176 to C208

Defects

- **C176** `done`: `ern run` and `ern test` refuse every program when the working directory is the standard library's source root, since the runner hashes the library through a source root. (erl/cli/src/ern_cli.erl:1113, with erl/cli/src/ern_build.erl:551 (the shell does the same at erl/cli/src/ern_shell.erl:1657)) — the runner and the shell ask for the installed library's hash with no source root, ern_build:stdlib_hash/0, and a build in the library's own root records none; regression test run_in_the_stdlib_root_test. Same as C168.
- **C177** `done`: In a directory build, one module's namespace clash, stale or unbuilt dependency, or `.erc` held by another module stops every other module, against §11.1. (erl/cli/src/ern_build.erl:74-86 (`build_step`), 261-269 (`parse_all`); the throws at 310, 638, 643, 538) — parse_all/3 and build_step/3 catch a module's refusal and record it as that module's failure, printed `ern build: ...` with the rest; regression test refused_dependency_fails_its_module_alone_test. A misnamed path is refused before any module is parsed, which T1 holds.
- **C178** `done`: `ern doc` takes any doc block whose text ends in "since" and a digit as a `since v` line, even mid-sentence. It renders a wrong *Since* and cuts the sentence. (erl/cli/src/ern_page.erl:151 (`split_since`, used by every page, the manual page, and the shell's `since/1`)) — split_since/1 takes the last line only where the whole line is `since v`, read by is_version/1 with no regular expression; regression test since_line_test in ern_page_tests.
- **C179** `done`: The build's and `ern doc`'s sweep lists the build tree with `file:list_dir`. A name there that is not UTF-8 makes the host print its own WARNING REPORT on standard output. (erl/cli/src/ern_build.erl:720 (`outputs/2`)) — outputs/2 lists with `file:list_dir_all` and passes over a name the host gives as bytes; regression test sweep_passes_over_a_name_not_utf8_test.
- **C180** `done`: The launcher refuses every working directory as "not UTF-8" on a host where `iconv` is not on the path. (bin/ern:30) — bin/ern checks that `iconv` is on the path, as it checks `erl`, and names it when it is missing, and docs/install.md lists it; regression test launcher_names_a_missing_iconv_test.
- **C181** `done`: `make load` counts the rows of four of the runtime's six tables, so a leak in `ern_callees` or `ern_deliveries` passes as flat. (test/ern_load.erl:112, against erl/runtime/src/ern_rt.erl:1547-1552) — done with D1: ern_rt exports tables/0, which make_tables/0 makes and the load's sample sums the rows of.
- **C182** `done`: The installation test hard-codes version 0.2.0 three times, so the release that bumps VERSION fails `make test`. The archive test beside it reads VERSION. (test/ern_integration_tests.erl:403, 409, 436) — install/0 reads VERSION once, as release/0 does, and builds its expected texts from it.
- **C183** `done`: The suites' `tmp()` directories under /tmp are never removed. A concurrent run's `tmp()` can delete another host's directory of the same number. (erl/cli/test/ern_cli_tests.erl:20-24, test/ern_guide_tests.erl:465-470) — erl/app.mk and test/Makefile run each suite under a directory made by mktemp, ERN_TEST_DIR, and remove it when the run ends; each suite's tmp() is under it, named with the OS pid, through ern_pty:run_dir/0. Same as C175.
- **C184** `done`: `make clean` leaves `examples/modules/net/*.erc`, since `**` is `*` under sh. It also leaves `build/pages`, which `make pages` writes. (Makefile:269-272) — make clean removes the examples' `.erc` files with `find examples -name '*.erc' -delete`, and `build/pages` is in its list. Same as D17.
- **C185** `done`: The release archive's Makefile sets `CC = cc`, which overrides a `CC` given in the environment, so `CC=clang make` in the unpacked archive still runs `cc`. (tools/release/Makefile:10) — tools/release/Makefile no longer sets `CC`, with C207.
- **C186** `done`: `stdlib_root_test` builds the whole standard library under EUnit's default five seconds, which the suite's own comment says a whole build exceeded under `make test`. (erl/cli/test/ern_cli_tests.erl:872-877, against the comment at 31-36) — stdlib_root_test_ has the 60 seconds of the other whole build.
- **C187** `done`: `make uninstall`, and `make install` over an old installation, delete whatever stands at each listed path, a `bin/ern` that is no longer Ernest's link among them. (tools/install.sh:142-147, and 113-120 (install uninstalls before its own `bin/ern` check)) — tools/install.sh's is_ours/0 asks whether `bin/ern` is the installation's link; install checks it before it uninstalls, and uninstall removes it only where it is; regression test in installation_test_'s install/0.
- **C188** `done`: No test holds the `§x.y` citations of the Erlang sources, the tests and the Makefiles to the report's headings. The citation test reads only Markdown and Ernest. (test/ern_docs_tests.erl:31) — citations_resolve_test reads toolchain()'s files too, the Erlang sources, includes and tests, the C helper and the Makefiles, and two comments that named a letter as an appendix were reworded. Same as D21.

Clarity

- **C189** `done`: `prelude_namespaces/0` returns the prelude's and the standard library's namespaces, and `dependencies/3`'s comment calls them all "a prelude namespace". (erl/cli/src/ern_build.erl:469-472, 361-371) — taken_namespaces/0 are the namespaces a module may not take and prelude_namespaces/0 the prelude's, and dependencies/3's comment says "a namespace of the prelude or the standard library".
- **C190** `done`: `built/3` returns the modules that failed, not the modules built. (erl/cli/src/ern_build.erl:65-72, 49) — built/3 is failures/3.
- **C191** `done`: Code that never runs or is never called: `compile/3`'s `{errors, ...}` catch, the exports `dependency_interface/4` and `write_whole/3`, and `write_at/4`'s second read of the file's info. (erl/cli/src/ern_build.erl:59-60, 15-17, 902-913) — the unreachable `{errors, ...}` catch and the exports dependency_interface/4 and write_whole/3 are gone, write_whole/3 is folded into /2, and write_at/4 reads the file's info once.
- **C192** `done`: Several yes-or-no functions and a boolean are not named as questions: `dot_name/1`, `stale/3`, `same_file/2`, `journal/0`, and `DirMode`. (erl/cli/src/ern_build.erl:155, 710, 31; erl/cli/src/ern_cli.erl:749, 833) — is_dot_name, is_stale, is_same_file, is_journal and IsDirectory.
- **C193** `done`: Functions named for a value also print, and one is a gerund: `reporting/2` returns run options, and `outcome/2`, `shell_outcome/2` and `tree_status/1` write to a device and answer a status. (erl/cli/src/ern_cli.erl:735, 855-863, 870-888, 650-654) — report_outcome/2, report_shell_outcome/2 and report_tree/1 print and answer a status, and reporting_options/2 gives the run options; run_options/0 stays the run job's specification.
- **C194** `done`: `ern_out:finish/1` names a monitor's reference `Ref`, where the glossary's word is `MonitorRef`. (erl/cli/src/ern_out.erl:26-30) — ern_out:finish/1's reference is `MonitorRef`.
- **C195** `done`: One concept has two names: the roots a dependency is found under are `SearchPath` in ern_build and the load path in its own comment and in ern_cli. (erl/cli/src/ern_build.erl:797-799, 39, 803-806; erl/cli/src/ern_cli.erl:364) — the build's roots, its build root then its load path, are `DependencyRoots` with a comment saying so, and compile_source/4's are its `LoadPath`.
- **C196** `done`: `ern --help` and each job's `--help` differ from §11's synopses. They show Erlang keys as metavariables, hide `--load-path`'s repetition, and misdescribe `test` and `format`. (erl/cli/src/ern_cli.erl:134-144, 287-289, 96-102) — each job's usage begins with §11's synopsis, written by synopsis/3 with the metavariables §11 gives and --load-path's repetition, `ern --help` describes `test` and `format` as §11.2 and §11.6 do, and no line ends in a space where getopt wrapped it; regression test synopses_are_the_reports_test_. Same as T23.
- **C197** `done`: Comments cite "Appendix E.0 rule 6" for the `since` line. E.0 has four numbered admission rules, and the `since` line is shape rule 6, as §11.4 cites it. (erl/cli/src/ern_page.erl:148, 216; erl/cli/test/ern_cli_tests.erl:1669, 1680, 1685 (also ern_shell.erl:1089, test/ern_shell_tests.erl:924, 2166)) — "Appendix E.0 shape rule 6" in the seven files that cited "E.0 rule 6".
- **C198** `done`: About twenty test comments cite entries of `findings.md` (T24, C3-17, C14...), a document that is gone, whose identifiers each review reuses. (erl/cli/test/ern_cli_tests.erl:201, 215, 1042, 1055, 1519, 1563, 1785, 1807, 1817, 1835, 1853, 1875; test/ern_integration_tests.erl:44, 78, 111, 685, 1069; test/ern_docs_tests.erl:177; test/ern_style_tests.erl:56) — done with C15.
- **C199** `done`: Two comments leave a gap waiting on closed MVP 2.99b: the interrupt's stray host line on its item 5, the unrun launchd checks on its item 10. (test/ern_integration_tests.erl:207-210; test/ern_service_tests.erl:134-136) — the interrupt test's comment points at the plan's *Standing gaps* and the launchd comment at MVP 2.99c's item 7.
- **C200** `done`: The Makefiles' comments no longer say what the Makefiles do. (Makefile:1-2, 167-177, 320-321; test/Makefile:1-9, 85-87) — Makefile's and test/Makefile's headers say what each does now, and `make xref`'s comment says it runs the document tests.
- **C201** `done`: Three test modules' first comments do not state the module's job: ern_integration_tests, ern_docs_tests, and ern_cli_tests, which has none. (test/ern_integration_tests.erl:1-4; test/ern_docs_tests.erl:1-4; erl/cli/test/ern_cli_tests.erl:1-8) — each of the three opens with a comment that states its job. Same as C27, C134.
- **C202** `done`: The grammar tests' and the typed generator's names are abbreviations a reader must guess, one of which the glossary refuses: `alt`, `nt`, `t`, `opt`, `rep`, `Expr`, `pwild`, `pcon`, `expr_text`. (test/ern_grammar.erl:17-18 (the `expression()` type), throughout test/ern_grammar_tests.erl and test/ern_grammar_programs_tests.erl; test/ern_typed_programs_tests.erl:1041-1078) — the grammar's tags are `sequence`, `alternatives`, `optional`, `repetition`, `nonterminal` and `terminal`, the patterns' `constructor_pattern`, `cons_pattern`, `list_pattern`, `literal_pattern`, `tuple_pattern`, `variable_pattern` and `wildcard_pattern`, and `Expression`, `expression_text` and `Argument` are whole words.
- **C203** `done`: Helpers are written twice with diverging shapes: `fix/2` and `nonterminals/1` in both grammar suites, and `is_editor_file/1` and `read/1` in ern_docs_tests and ern_style_tests. (test/ern_grammar_tests.erl:169-190, test/ern_grammar_programs_tests.erl:356-397; test/ern_docs_tests.erl:314, 351; test/ern_style_tests.erl:326, 346) — ern_grammar exports nonterminals/1 and fix/2, which both grammar suites call, and the new ern_repository gives the two document suites files/1, which leaves an editor's files out, and read/1.
- **C204** `done`: The typed generator keeps its name counter and the reply round's declarations in the process dictionary, so a function that returns text also declares helpers as a side effect. (test/ern_typed_programs_tests.erl:101, 356-360, 594-595, 997-1000) — the reply round's text functions return their declarations with the text, through enclosed/3, and a fresh name is numbered by the node's unique integers, as a move is, so no counter is carried and no process dictionary of the test's own remains; the generator's choices come from `rand`'s state, which a threaded counter would have left as it is.
- **C205** `done`: `ern_load:main/1` decides its exit status from the shape of the verdict's text, not from the verdict. (test/ern_load.erl:36-45) — main/1 decides the status and the text from `{Status, verdict(Samples)} =:= {0, []}`, computed once.
- **C206** `done`: The recognizer's test says every derived program is a sentence of the grammar, but it checks only the first 200 of more than a thousand. (test/ern_grammar_programs_tests.erl:92-100) — recognizer_accepts_derived_programs_test_ checks every derived program.
- **C207** `done`: The helper's C flags differ between the two Makefiles without a word: the release build drops `-Werror`, and the checkout's `CC ?= cc` changes nothing, since make predefines `CC`. (tools/release/Makefile:17; Makefile:21) — the checkout's Makefile no longer sets `CC`, and a comment of tools/release/Makefile says the archive leaves out `-Werror`, as *One Archive, Compiled Where It Is Installed* decided. Same as C185.
- **C208** `done`: `entry_point/4` returns the Erlang module, and `entry_namespace/1` then rebuilds the namespace from that module's name, though the namespace was in hand. (erl/cli/src/ern_cli.erl:1032-1051, 1102-1108) — entry_point/4 returns the entry's namespace and its function, the Erlang module is made from the namespace, and entry_namespace/1 is gone, with ern_build:namespace/1, which nothing else called.

## The Ernest code

### E, part 1, the standard library, E1 to E34

Defects

- **E1** `done`: `ern doc` prints every foreign primitive's type without its restrictions, so the stdlib pages disagree with `:type`: `Map.get` shows no `k=`, `Clock.monotonic` no `m+`. (stdlib/map.ern:65 (its page, and `man/stdlib/map.md:80`), stdlib/clock.ern:56, and every `export foreign fn` of stdlib/; §11.4, §11.5, §4.7) — done with P4 and N2: a page prints a foreign function's scheme, its restrictions and `Io.show`'s requirement among it, and `Io.show`'s page states the requirement.
- **E2** `done`: `Io.show`'s and `Io.debug`'s pages say `Io.show` at a type variable is a type error, hiding `needs a.show`, the one way a generic function shows its argument. (stdlib/io.ern:172, stdlib/io.ern:188; Appendix E.1) — done with P4 and N2: a page prints a foreign function's scheme, its restrictions and `Io.show`'s requirement among it, and `Io.show`'s page states the requirement.
- **E3** `done`: `Terminal.Event`'s page writes `Enter` as if it were a constructor and never says which `Char` Enter and Backspace arrive as, so a program cannot match them. (stdlib/terminal.ern:38; §8.2 *Keys*) — `Terminal.Event`'s page names the characters §8.2 gives, Enter as `Key('\r')` or `Key('\n')`, Backspace as `Key('\u{7f}')` or `Key('\u{8}')`, Tab as `Key('\t')`, and its example matches Enter with an `or` pattern; `Enter` is no longer written as a constructor.
- **E4** `done`: `since` lines name versions the declarations were not in: OrderedSet and OrderedMap say 0.2.0, and `Char.isAsciiDigit` and `Os.user`, both new after 0.2.0, inherit 0.1.0. (stdlib/ordered_set.ern:40, stdlib/ordered_map.ern:26, stdlib/char.ern:27, stdlib/os.ern:143; also stdlib/tcp.ern:66 and :244, stdlib/fs.ern:306, stdlib/os.ern:107; E.0 shape rule 6) — done with D3: a `since` names the release that first shipped the module or the declaration, by its kind and name, and the release after the last tag where none did, which the doc test holds against the tags; `Tcp.SocketMsg`, `Tcp.remote`, `Fs.makeFile`, the function `Os.environment`, `Markdown.Output` and the template's `emptyStack`, `push` and `pop` say 0.2.0, and OrderedSet, OrderedMap, `Char.digitValue`, `Os.user`, `Path.under` and `Test.equal` say 0.3.0.
- **E5** `done`: Functions that fault have no `### Errors` section: `Io.readLine`, `Io.read`, `Terminal.subscribe`, `Fs.removeAll`, `Os.start`, `Os.run`, `Int.shiftLeft`. (stdlib/io.ern:118, stdlib/io.ern:132, stdlib/terminal.ern:80, stdlib/fs.ern:325, stdlib/os.ern:193, stdlib/os.ern:327, stdlib/int.ern:125; E.0 shape rule 6, §7.4) — `Io.readLine`, `Io.read`, `Terminal.subscribe`, `Fs.removeAll`, `Os.start`, `Os.run` and `Int.shiftLeft` have an `### Errors` section with §7.4's causes, the sentences that said it in the description moved there. A shift beyond the host's integers faults with `Fault("error:system_limit")`, as `*` does at that limit, through a shim as `Int.toFloat`'s, where it had faulted as a raise of `erlang:bsl/2`; E.8's line and §10 say so; regression test int_shift_limit_test.
- **E6** `done`: `Io.Error`'s page gives `NotATerminal` as standard input alone and `Invalid` as U+0000 or a port, though `Terminal.size` and `Fs.setMode` answer them otherwise. (stdlib/io.ern:31, stdlib/io.ern:35; Appendix E.1, E.16, E.17) — E.1 says that `NotATerminal` is standard input for `Terminal.subscribe` and standard output for `Terminal.size`, as E.16 has it, which the code does not yet keep (E35), and that `Invalid` is an argument the host cannot take whole, a mode with bits it does not write among them; `Io.Error`'s page says both. Reading the sentence found the host dropping the bit 0o1000, so that `Fs.setMode(p, 0o1777)` set 0o777 and answered `Right(Unit)`; a mode with it is `Left(Invalid)`, E.17 says so, and fs_set_mode_test holds it.
- **E7** `done`: `Map.mergeWith`'s example shows `Map.toList` of two keys in sorted order, an order E.3 leaves unspecified, where Set's examples sort first. (stdlib/map.ern:195; Appendix E.3) — the example ends in `Map.get` of each merged key, with E26.
- **E8** `done`: `Tcp.write`'s `### Errors` section lists its `Left` answers, `Timeout`, `Closed` and `Other`, which are values, beside the one fault. (stdlib/tcp.ern:197; E.0 shape rules 4 and 6) — `Tcp.write`'s three `Left` answers are in its doc sentence, and `Errors` holds the one fault, on a socket that has ended, closed or killed.
- **E9** `done`: `Int.bitNot` is a `foreign fn` though its own doc gives its Ernest body, `-int - 1`. (stdlib/int.ern:121; Appendix E.8, E.0 rule 1) — `Int.bitNot` is Ernest, `-int - 1`, with an example, and E.8 no longer lists it among the primitives; it costs what the host's `bnot` does.
- **E10** `dropped`: `Float.floor` and `Float.ceil` are foreign though Ernest writes them over `Float.truncate`, as `Float.round` is already written over `floor`. (stdlib/float.ern:142, stdlib/float.ern:146; Appendix E.9, E.0 rule 1) — measured: `floor` in Ernest over `truncate` and `Int.toFloat` cost 4.2 times the host's `floor/1` over a million floats, 58 ms against 14 ms, and `ceil` the same, the loop's own cost in both; past E.0 rule 1's line of three, so both stay primitives, and their pages gained examples.
- **E11** `MVP 2.99d`: `String.toList` and `String.fromUtf8` are foreign though the bit syntax's `utf8` segment decodes UTF-8, over the primitives `toUtf8` and `fromList`. (stdlib/string.ern:498, stdlib/string.ern:517; Appendix E.5, E.0 rule 1, §5.11) — decided with the user: E.0 rule 1's line is three times the host's at the sizes a program meets, or growth; MVP 2.99d's first item measures this function with every other (the log's *The Full Review's Questions, One by One*).
- **E12** `MVP 2.99d`: `Int.toString` and `Int.toStringBase` are host shims, though Ernest writes digits over `/` and `%`, as `String.toIntBase` already reads them back in Ernest. (stdlib/int.ern:150, stdlib/int.ern:185; Appendix E.8, E.0 rule 1) — decided with the user: E.0 rule 1's line is three times the host's at the sizes a program meets, or growth; MVP 2.99d's first item measures this function with every other (the log's *The Full Review's Questions, One by One*).
- **E13** `done`: `String.words` splits at a space inside a grapheme, where `trim` and every search take whole graphemes: `words("a \u{301}b")` gives a word beginning with a combining mark. (stdlib/string.ern:323; Appendix E.5) — `String.words` splits a list of graphemes at those whose first code point is White_Space, as `trim` judges them, so `words("a \u{301}b")` is `["a", "b"]`, an example on its page; E.5 says so, and the library's law for it reads graphemes.
- **E14** `done`: `Fs.Entry`'s first example and both of Test's examples can run but end in no `// =>` line, and Test's two examples repeat one another. (stdlib/fs.ern:56, stdlib/test.ern:10, stdlib/test.ern:22; E.0 shape rule 6) — `Fs.Entry`'s first example ends in its value, Test's module example runs a case made with `Test.equal` and ends in `Passed`, and `Case`'s ends in `Case(name = ..., run = <function>)`.
- **E15** `done`: Report §10 cites Appendix E.4, the `Set` module, for the Unicode tables behind a `Char`'s category and case, which are E.6's. (report/language.md:889, §10) — done with K8.

Clarity

- **E16** `done`: The prelude's `answer` is rebound as a value in three places, one in the module that answers replies on every other line. (stdlib/supervisor.ern:170, stdlib/fs.ern:386, stdlib/tcp.ern:35, stdlib/tcp.ern:158; docs/style.md, glossary, *Ernest*) — the four bindings are `received`, `accepted`, `runsGroup` and `called`.
- **E17** `done`: OrderedSet and OrderedMap name the callback of `any`, `all` and `find` `keep`, where the glossary and List, Map and Set name it `test`. (stdlib/ordered_set.ern:209, :214, :225; stdlib/ordered_map.ern:224, :229, :240; docs/style.md, glossary) — OrderedSet's and OrderedMap's `any`, `all` and `find` name their callback `test`.
- **E18** `done`: `OrderedMap`'s merge names the second map's key `theirs` and its value `value`, beside `mine` for the first's value; the page's example uses `mine` and `theirs` for values. (stdlib/ordered_map.ern:276) — `mergedWith`'s pairs are `#(key, value)` and `#(otherKey, otherValue)`.
- **E19** `done`: Supervisor declares two linked lists of its own, `Held` (`Holding`/`Nobody`) and `Waiting` (`Waiting`/`NoOne`), where lists of replies with `List.foreach` and `List.filterMap` compile and run. (stdlib/supervisor.ern:105, :120, :242, :330; §6.6) — Supervisor's waiting children are a `List(#(Reply(Bool), List(Process)))` walked by `List.filterMap`, and the watcher's held replies a `List(Reply(Unit))` answered by `List.foreach`; the two types and their constructors are gone.
- **E20** `done`: Whether an `Optional` holds a value is tested four ways across the library: `match` in Map, `Optional.isSome` in OrderedMap, `!= None` in String and Bytes. (stdlib/map.ern:58, stdlib/ordered_map.ern:81, stdlib/string.ern:106, stdlib/bytes.ern:110) — Map's, String's and Bytes' `contains` are `Optional.isSome(...)`, as OrderedMap's is.
- **E21** `done`: String's and Path's module pages name their primitives and private helpers in sentences a programmer cannot parse or use: "the private `drop` and `lastGrapheme`", "`separator`, private". (stdlib/string.ern:6, stdlib/path.ern:4) — String's and Path's pages keep what a caller acts on, that every search matches whole graphemes and that a path is `Path(String)`, and leave the primitives to E.5 and E.14. Same as G41.
- **E22** `done`: Supervisor's page spends a paragraph and `Msg`'s doc on the implementation, the watcher, what a child tells, and "the ends of the alarms it sets itself". (stdlib/supervisor.ern:20, stdlib/supervisor.ern:67) — the page's paragraph on how a child tells its supervisor, and `Msg`'s list of messages, are a `//` comment above `Msg`, and the page states E.22's promise that the child that faulted runs again once the siblings its fault restarts have restarted or ended.
- **E23** `done`: Fs's page examples drop every setup call's `Either` with `let _ =`, thirty times, teaching a program to ignore an `Io.Error`, where Os's and Tcp's examples bind with `<-`. (stdlib/fs.ern:17, :61, :110, :137, :156, :183, :203, :336 and the rest) — Fs's page examples bind their setup calls with `let _ <-` in blocks whose value is the `Either`, the three that ended in a pair or a `Bool` ending in `Right(...)`.
- **E24** `done`: Fs's request constructor for `list` is named `List`, on a line that also writes the prelude type `List(Entry)`. (stdlib/fs.ern:76; docs/style.md, glossary) — Fs's request is `ListEntries`, in the module and in the process the runtime runs, and the glossary's rule for a request says that where the function's name is a prelude name the request names what it asks for.
- **E25** `done`: Random writes 2^64 twice as `18446744073709551616` and 2^52 as `4503599627370496.0`, beside `mask` in hexadecimal, and names a helper `words` for what it is made of. (stdlib/random.ern:70, :75, :106, :109) — Random names `drawSpan`, 2^64, and `fractionSpan`, 2^52, and the helper `words` is `spanning`, for the draw it gives.
- **E26** `done`: `Map.mergeWith`'s doc sentence does not parse: "a shared key given the function of the key, the first's value and the second's". (stdlib/map.ern:189) — the sentence says `f(key, first, second)` of the first map's value and the second's, with E7.
- **E27** `done`: `Path.<>` rewrites its first operand, `Path("a//b") <> Path("c")` being `"a/b/c"`, where `withExtension` keeps "the rest as written". (stdlib/path.ern:39; Appendix E.14, §9.6) — E.14 and the page say that `<>` joins the segments of both, `split` then `join`, so `Path("a//b") <> Path("c")` is `Path("a/b/c")`, and that an absolute second is the result as written; `split`'s line says its segments are none empty.
- **E28** `done`: Random's page points at `List.sort` for "a shuffle written with draws" and shows none, where the reading a programmer predicts, a random comparator, cannot be written. (stdlib/random.ern:24) — Random's page no longer points at `List.sort` for a shuffle.
- **E29** `done`: `Os.joined` re-implements `Bytes.join(List.reverse(pieces), <<>>)`. (stdlib/os.ern:371) — `Os.joined` is `Bytes.join(List.reverse(pieces), <<>>)`.
- **E30** `done`: `Bool.not` is written `if bool then false else true`, where the language's `!bool` says it. (stdlib/bool.ern:20; §4.8) — `Bool.not` is `!bool`.

Where the language made the work harder

- **E31** `done`: `Int.pow` answers `Optional` even where the exponent is known non-negative, so string.ern writes a private `power` of its own and a caller unwraps with an invented default. (stdlib/string.ern:445, stdlib/int.ern:162) — decided with the user: no change; `Int.pow` keeps shape rule 4's `Optional`, and `String` its private power for an exponent it knows (the log's *The Full Review's Questions, One by One*).
- **E32** `done`: No call waits without limit yet answers `None` when the callee ends or restarts, so Supervisor polls with an invisible 1000 ms timeout and a `Process.info` check. (stdlib/supervisor.ern:169, stdlib/supervisor.ern:429; §6.6) — decided with the user: no new call; the limit is `retryMs`, its comment saying that an ended or restarted callee answers `None` at once (§6.6), so its value does not matter (the log's *The Full Review's Questions, One by One*).
- **E33** `done`: `List.tryMap` takes only an `Either` step, so `String.toIntBase` invents a `Left(char)` that it discards to stop at the first non-digit. (stdlib/string.ern:419, stdlib/string.ern:425) — `String.toIntBase` reads its digits by a recursion of its own over `Char.digitValue`'s `Optional`, so no `Left` is made to be dropped.
- **E34** `done`: No standard function gives a character's value as a digit in a base, so `String.digitValue` and `Bytes.value` each write the same ranges of `0`-`9`, `a`-`z`, `A`-`Z`. (stdlib/string.ern:454, stdlib/bytes.ern:282) — decided with the user: `Char.digitValue(char, base)` enters by E.0 rule 3, and `String.toIntBase` and `Bytes.fromHex` call it (E.6; the log's *The Full Review's Questions, One by One*).

### E, part 2, the shell, E35 to E65

Defects

- **E35** `done`: With standard output piped and standard input a terminal, the shell paints the live region into the pipe instead of reading lines (shell/shell.ern:201-202; report §11.2 *Editing*, Appendix E.16) — `Terminal.size` asks whether standard output is a terminal first, since the host answers the terminal's size where standard input alone is one, and answers `Left(NotATerminal)` for a terminal with no rows or no columns too, which §8.2, E.1 and E.16 now say; so the shell takes line mode under `| cat`; regression tests no_size_test_ in ern_terminal_tests and piped_output_is_line_mode_test_.
- **E36** `done`: A fault reported while a line is typed is glued onto that line's prompt, and the input goes on with no prompt (shell/shell.ern:568, reached from `keyLoop` at 509) — `keyLoop` hands `reported` the constructor `Noted`, so a fault said while a prompt is pending stands above the region, and `await` and line mode keep `Said`; regression test fault_while_typing_test_, which failed against the code before.
- **E37** `done`: `Tab` with the cursor inside a command's word keeps the text after the cursor beside the completion: `:br|owse` becomes `:browse owse` (shell/shell/complete.ern:42-44, with `applied` at 359-371) — the command's typed word is what stands before the cursor, as a name's is (§11.2: the name before the cursor), so the cursor lands after the completion where it landed inside the word; what follows the cursor stays, `:browse owse`, as Readline leaves it; regression test in Shell.Complete.
- **E38** `done`: `:load` completion inside a namespace of two words lists nothing: `KvParser.` is looked for in `kvparser/`, not `kv_parser/` (shell/shell/complete.ern:172; report §4.2) — `:load` completion asks the front end for a segment's path component, `ern_shell:component/1` over `ern_namespace:component/1`, the inverse of `segment`, so `KvParser.` lists `kv_parser/`; regression test load_completion_of_two_words_test_.
- **E39** `done`: The live region cuts a program's ended line off at the screen's width, but wraps an unended line of the same text onto more rows (shell/shell/region.ern:84 and 175) — `Shell.Region.wrote` splits an ended line into the rows it fills with `filled`, as an unended one, and the design note's *Rows* and *The events* say so; regression test in Shell.Region.
- **E40** `done`: Timing measures a run with `Clock.now`, the clock the host may set, so a clock set during the run gives a wrong time or a negative one (shell/shell.ern:406 and 494; Appendix E.15) — timing reads `Clock.monotonic()` at both ends; no regression test, since a clock set during a run is not made in a test.
- **E41** `done`: `:load` completion offers every directory under the source root that has a valid name, though it holds no module: `Build.`, `Home.`, `Steps.` (shell/shell/complete.ern:182-186; report §11.2 *Completion*) — decided in triage: §11.2 says that `:load` offers a directory of the source root whose name §11.1's path shape makes a namespace, whether or not it holds a module.
- **E42** `done`: A command's argument that the parser cannot finish never takes another line: `Enter` runs `:type List.map([1, 2],` and reports the end of input (shell/shell.ern:1081-1082, also `gathered` at 300-307 for startup files; report §11.2 *Editing*) — decided in triage: §11.2 says that a command is one line. Reading the sentence found the code untrue to it: an unfinished block comment in a command's argument made `Enter` take the next line, and `M-Enter` or a paste gave a command a second line, which then ran. A `:` line now never continues, a command of two lines is refused, `a command is one line`, and only `:type`'s argument is the parser's to refuse; regression tests command_is_one_line_test_ and Shell.Command's refusals.
- **E43** `done`: A `C-k`, `C-u`, `C-w` or `M-d` that kills nothing empties what `C-y` puts back, where Readline leaves the last kill as it was (shell/shell/editor.ern:405-419) — a kill of nothing leaves the last kill, in `killBackTo` and `killForwardTo`; regression test in Shell.Editor.
- **E44** `done`: `C-w` crosses into the line above in a multi-line input, because a line feed does not count as a space (shell/shell/editor.ern:449-450) — `C-w` stops at a tab as at a space, and §11.2 says so; regression test in Shell.Editor.
- **E45** `done`: The screen is not monitored: if it ends, the session goes on writing to nothing and waits five seconds at every prompt (shell/shell.ern:141-159 and 182) — the session monitors the screen, and the screen's end faults the session with its cause, a failure of the shell's own (§11.8); the design note says so; regression test reader_and_screen_ends_test_, which ends the screen through a host function a session declares.
- **E46** `done`: `await` does not receive `ReaderDied`, so if the reader ends while an input runs, no key can interrupt that input (shell/shell.ern:421-466) — `await` takes `ReaderDied`, kills the running input, says the reader's end and leaves; `execute` and `await` answer `Next` for it; regression test reader_and_screen_ends_test_.
- **E47** `done`: The shell prints a hint, "M-Enter adds a line, Enter runs.", that §11.2 does not contain, under a comment that cites §11.2 for it (shell/shell.ern:1052-1059) — §11.2 states the hint, in a wording true where `Enter` has just added the line: `Enter runs a finished input, M-Enter adds a line.` Same as T15.
- **E48** `done`: The report never says how a tab in the input is drawn: §11.5 sets the tab apart from control characters, and the region chooses stops of eight (shell/shell/region.ern:303-312 and 359-372; report §11.2 *Editing*, §11.5) — §11.2 says that in the live region a tab is drawn to the next stop of eight from the start of its row, and that a line written above the region keeps its tabs. Reading the sentence found the input's stops counted from the start of its line, a program's from the start of each row; the input's rows and the rows under it now take the terminal's, each row's own; regression test in Shell.Region.

Clarity

- **E49** `done`: `Shell.Editor.State`'s field `kill` gives the prelude's name `kill` to the text last killed (shell/shell/editor.ern:19, 193, 206) — `Shell.Editor.Editing`'s field is `killed`.
- **E50** `done`: A module is given the kind `Value` so that its completion ends without a dot (shell/shell/complete.ern:149 and 193) — a module keeps the kind `Module`, the namespaces it stands in take the new kind `Namespace`, and the new slot `Modules`, `:browse`'s and `:load`'s, completes a module whole, without the dot.
- **E51** `dropped`: `segment` is a `foreign fn` for work Ernest does in a few lines over `String` and `Char`, and its inverse is written in Ernest, wrongly (item 4) (shell/shell/complete.ern:230-233; Appendix E.0 rule 1) — decided: *The Path Rule Has One Owner*: the shell asks the compiler for a name's segment so that §4.2's rule has one owner, which the finding's argument from E.0 rule 1 was weighed against; the hand-written inverse is E38's defect, fixed there. Same as E38.
- **E52** `done`: The rule that a HOME which is no absolute path names no file exists twice: in Ernest for the history, in Erlang behind `startupFiles` (shell/shell/history.ern:20-24; shell/shell.ern:1316-1320, answered by erl/cli/src/ern_cli.erl:814-822) — the person's startup file is `Shell.History.startup`, beside the history's, under its rule for a HOME that is no absolute path, and named from the working directory in Ernest (§11.5); the host answers only the configuration directory's file, `configStartup`, and whether the two are one file, `isSameFile`, by device and node.
- **E53** `done`: `Shell.Style`'s functions take the colour before the text, which breaks shape rule 1 and the order of `Markdown.render` (shell/shell/style.ern:10-48; Appendix E.0 shape rule 1) — `Shell.Style`'s five functions take the text first and the colour after it, at every call.
- **E54** `done`: Message constructors break the style rule for requests and events: `Typing` and `Height` sent to the screen, and the events `Eof` and `Key` (shell/shell.ern:36, 86, 91, 102; docs/style.md *Ernest*) — the screen's requests are `ShowInput` and `SetHeight`, and the event `InputEnded`; `Key` stays. Same as E55.
- **E55** `done`: `Shell` and `Shell.Editor` use `State`, `Typing`, `Clear` and `Leave` for different things, and both `Shell` and `Shell.Region` have a function `typing` (shell/shell.ern:51, 86, 1066; shell/shell/editor.ern:16, 41-48; shell/shell/region.ern:91; shell/README.md:28) — the editor's `State` is `Editing`, its `Edit`'s `Typing`, `Clear` and `Leave` are `Edited`, `ClearScreen` and `Quit`, the region's `typing` is `edited`, and the README's paragraph on the overlap keeps only `Resized`'s note. Same as E54, H14.
- **E56** `done`: `isKept` names the check that a startup file is the user's own and writable by no one else, using the word the history uses for keeping inputs (shell/shell.ern:259) — `isKept` is `isUsersOwn`, for the file and the directory that are the user's own or the superuser's.
- **E57** `done`: Some names do not say what their function does: `program()` spawns the entry point, `unbound` asks whether `it` was left alone, and `lone` and `midSequence` are questions (shell/shell.ern:174, 1283, 1343; shell/shell/complete.ern:236; shell/shell/editor.ern:104) — `spawnProgram`, `leavesItUnchanged`, `isLone` and `isMidSequence`, the first two in the front end too, `spawn_program/0` and `leaves_it_unchanged/1`.
- **E58** `done`: The reader drops the size a `Resized` event carries, and the screen asks `Terminal.size()` for it again (shell/shell.ern:988-990 and 851) — a comment says why the screen asks for the size itself: of several changes that come together it paints the last alone.
- **E59** `done`: A comment and a doc block in `Shell.Complete` say the opposite of what the code does (shell/shell/complete.ern:410 and 244) — `every`'s comment says each segment matches as the last does, its `[last]` arm is gone, and `complete`'s doc says nothing typed is one segment.
- **E60** `done`: Two pages leave a programmer guessing at arguments: `Shell.Command.completes` expects the word with its `:`, and `Shell.Complete.applied` takes two `String`s in an unstated order (shell/shell/command.ern:172-175; shell/shell/complete.ern:356-362) — `completes`' doc says it takes the word with its `:`, and `applied`'s names the line, the cursor and the typed word.
- **E61** `done`: Two comments cite `findings.md`, a document that exists only while a review is open and is not in this commit (shell/shell/editor.ern:471; shell/shell/history.ern:123) — done with C15.
- **E62** `done`: The shell's README says two false things: that `Shell` holds all that reaches the host but the history file, and that `main` writes the first prompt itself (shell/README.md:36 and 60) — done with H1 and H4.
- **E63** `done`: One five-second wait has three names and an unnamed literal, and `:output` uses the file system's `fileMs` for a call to the screen (shell/shell.ern:310, 333, 949; shell/shell/history.ern:15; shell/shell/complete.ern:199) — the screen's two calls wait `screenMs`, beside `fileMs`.
- **E64** `done`: `Shell.Region.output(region, rows)` is named with a noun, though it gives the tail a number of rows (shell/shell/region.ern:127) — `Shell.Region.output` is `outputSized`.
- **E65** `done`: The help mixes two forms of line: some say what the command shows, some are imperatives that repeat the command's verb (shell/shell/command.ern:52-112) — `:forget`, `:output` and `:quit` say what the command does, as `:browse` and `:load` do.

### E, part 3, the libraries, the examples and the tools, E66 to E108

Defects

- **E66** `cheap`, M: file_sync checks a peer's file against the last listing, not the file now, so a local edit made since that listing is overwritten without a conflict (examples/file_sync.ern:115) — Let the writer compare the peer's mtime with the local file's own, read by `Fs.stat` when the `Put` arrives, and write the `.conflict` file where the local one is newer, in place of the last listing's `seen`.
- **E67** `cheap`, M: snake takes two turns within one tick as a U-turn, so a snake of three or more dies from two quick keys (examples/snake.ern:269) — Keep the direction of the last move beside the one requested and refuse a turn opposite to the last move, with a test of two turns within one tick.
- **E68** `MVP 3.2`: web_server answers each request from one `Tcp.read`, so headers that arrive in a later segment are lost (examples/web_server.ern:93) — Waits on `libs/http`, whose request parser says when a request has arrived whole; the stand-in is not extended meanwhile (the log's *The Web Server Waits for Its Library*), and the example's header names this gap among what waits.
- **E69** `MVP 3.2`: web_server's session id is the connection's number, so any client takes another's session by sending a small number (examples/web_server.ern:216) — Waits on `libs/crypto`'s random bytes, from which a session id no client can guess is drawn (a `Random` seeded from the clock is guessable too); meanwhile "good enough on paper" gives way to a header line saying the id waits for it.
- **E70** `cheap`, S: echo discards the result of its round trips and prints "2000 round trips" even when one has failed (examples/echo.ern:25) — Match `roundTrips`' result and print the error in place of the measurement on `Left`.
- **E71** `cheap`, S: echo measures elapsed time with `Clock.now`, which E.15 says is not elapsed time when the clock is set (examples/echo.ern:24) — Take both readings with `Clock.monotonic()`.
- **E72** `cheap`, M: `ern doc` prints an exported foreign fn's type without its restrictions: `Ets.contains` shows `(Table(k, v), k) -> Bool with m`, which the checker treats as `k=!`, `v!`, `m+` (libs/ets/ets.ern:94 and :181; report §3.9, §4.7, Appendix E (introduction)) — Print an exported `foreign fn`'s type in `ern doc` and `:doc` from its scheme, with the restrictions §4.7 and §3.9 give it, as the checker's messages print it. Same as E1, C80, N4.
- **E73** `cheap`, M: `Ets.size` on an ended table faults with "foreign return does not match Int", not as its Errors section says; `ets:info/2` answers `undefined` (libs/ets/ets.ern:111-121) — Declare `rawInfo`'s result `Foreign.Term` and make `size` fault on `undefined` as its Errors section says, in libs/ets and Appendix D alike, with a regression test.
- **E74** `cheap`, M: An HTML comment, declaration or processing instruction runs to a blank line, so the paragraph after it is swallowed into a `Raw` block (libs/markdown/markdown.ern:196, :527-531 (comment at :498-499)) — End a comment, declaration or processing-instruction block at the line holding its closing mark, as CommonMark 0.31's start conditions 2 to 5 do, keeping the blank-line end for a tag, with a test.
- **E75** `cheap`, S: Ansi.styled's page promises "a style around it stays on", but a colour inside a colour, or italics inside italics, turns the outer one off (libs/ansi/ansi.ern:42-44; report Appendix G.3) — Say in `Ansi.styled`'s page and in G.3 that a style of another kind around the text stays on, and that one of its own kind, or `Bold` around `Dim`, is turned off.
- **E76** `cheap`, S: ern(1)'s SYNOPSIS lists `ern build` twice, because `usages` takes every `ern … [` code span in §11, including §11.1's later directory form (tools/manual.ern:84-99) — Take a usage line only from a code span that opens its paragraph, one per job, so §11.1's second `ern build` span is no SYNOPSIS line. Same as G28.
- **E77** `cheap`, S: file_sync pushes every listed entry, so a subdirectory or a link is read as a file, and a subdirectory reports an error (examples/file_sync.ern:173-181) — Keep only the entries of kind `Fs.File` in `diff`.
- **E78** `cheap`, S: `#` followed by a tab is not read as a heading, against CommonMark 0.31, which allows spaces or tabs after the opening sequence (libs/markdown/markdown.ern:266) — Accept a tab as well as a space after an ATX heading's `#`s, as CommonMark 0.31 does.
- **E79** `cheap`, S: `render` with `Plain` writes `_x_` as `*x*` and `__y__` as `**y**`, though the page says each span is shown as it was written (libs/markdown/markdown.ern:888-889; :97 (`Plain`'s doc)) — Say in `Plain`'s doc and in G.2 that emphasis is written with `*` and strong emphasis with `**`, whichever mark the source used.
- **E80** `cheap`, M: The template module gives a circle's area as three times the radius squared, "since the module has no Float", though `Float.pi` exists (examples/template.ern:92-102) — Give the template a shape whose whole-number area is exact, or an area in `Float` over `Float.pi`, dropping "since the module has no `Float`", and regenerate module_doc_template.md.
- **E81** `cheap`, S: With `Styled`, emphasis inside emphasis turns the italics off for the rest of the outer span (libs/markdown/markdown.ern:888) — Flatten an `Emphasis` inside an `Emphasis` before styling it, as `unstrong` flattens `Strong` in a heading.
- **E82** `cheap`, M: snake's `refill` puts apples anywhere, the snake's own cells included, where `freePoint` avoids them (examples/snake.ern:185-196) — Place each apple `refill` adds where `taken` finds nothing, as `freePoint` does, with a test on a board the snake almost fills.
- **E83** `cheap`, M: A tab after a leading run of digits or marks in text is expanded, though the page says a tab elsewhere than the structure is kept (libs/markdown/markdown.ern:203-219) — Expand a tab only through the indentation, the quote marks and a marker `markerOf` reads, so a tab after `3.14` in text is kept as the page says.
- **E84** `cheap`, S: A lazy `===` under a quoted paragraph makes a setext heading, where CommonMark keeps it paragraph text (libs/markdown/markdown.ern:357, :537) — Do not take a line that `underlineLevel` reads as an underline as a lazy continuation of a quoted paragraph.
- **E85** `cheap`, M: A link destination in angle brackets, `[a](<b c>)`, is not read, and the page does not list it among what stays text (libs/markdown/markdown.ern:736-751) — Read a link destination in angle brackets, `[a](<b c>)`, in `destination`, as CommonMark 0.31 does.
- **E86** `cheap`, S: The REPL answers an empty line with "unexpected end of input" (examples/repl.ern:91) — Pass over a line with no tokens, printing nothing.
- **E87** `cheap`, M: snake's tick is 100 ms plus each tick's work, so the world is updated less than the ten times per second the header states (examples/snake.ern:84-85) — Keep the next tick's deadline on `Clock.monotonic` and set each alarm for what is left of it, so the world steps ten times a second as the header says.
- **E88** `cheap`, M: The shell's `:doc` shows Ansi's and Markdown's pages to a session that cannot call them, and shows no page for Ets on its load path (report §11.2, §11.4 (the shell's `:doc`); libs/*) — Answer `:doc` from the modules the session can name, so that the shell's own `Ansi` and `Markdown` are not documented to a session that cannot call them. Same as T9.

Clarity

- **E89** `cheap`, M: `Ets.contains` is a `foreign fn` whose work is `Optional.isSome(get(table, key))`, as `Map.contains` is Ernest over `get` (libs/ets/ets.ern:94) — Write `Ets.contains` in Ernest over `rawLookup`, as `Map.contains` is over `get` (CLAUDE.md, *Shims*: speed is no reason for a shim), in libs/ets, Appendix D and the guide's §8.3, whose example then shows `toList` as the exported `foreign fn`.
- **E90** `cheap`, S: One concept, the openers of a block, has three names in markdown: `starts()`, the parameter `tries`, and the element `opener` (libs/markdown/markdown.ern:164-178) — Name the openers `openers` as the function, the parameter and the element alike, and rename `begun` and `structured` for what they answer.
- **E91** `done`: Four regression tests in markdown cite "findings.md's E5/E8/E21/E22", a file that no longer exists and whose numbers collide with every later review's (libs/markdown/markdown.ern:1269, :1316, :1325, :1404) — done with C15.
- **E92** `cheap`, S: markdown's `blocksAre` reports a failed parse as only its count of blocks, where `Io.show(blocks)` would show what was read (libs/markdown/markdown.ern:1553-1557) — Fail `blocksAre` with `Test.Failed(Io.show(blocks))`.
- **E93** `cheap`, S: `Markdown.roff`'s page says the header and the NAME line come "from the page", where they come from its `Manual` argument (libs/markdown/markdown.ern:1016) — Write "from the `Manual`" in `Markdown.roff`'s page, as G.2 has it.
- **E94** `cheap`, S: `Markdown.render`'s page lacks a comma, so the label rule reads as if the period depends on the delimiter (libs/markdown/markdown.ern:796-797) — Add the comma: "its number and a period, whichever delimiter it was written with".
- **E95** `cheap`, S: `Template.radius`'s sentence does not say what the function answers (examples/template.ern:104) — Write "The radius of a circle of that diameter, rounded toward zero", and regenerate module_doc_template.md.
- **E96** `cheap`, S: file_sync's `store` repeats the spawn in two arms, and `writer`'s `written : Ack` names the answer it gives, not a write (examples/file_sync.ern:113-123, :142) — Choose the target path and the `Ack` in one `match` and spawn once, and name `writer`'s parameter `ack`.
- **E97** `cheap`, S: snake's `steering` writes the same send and loop four times, once for each arrow (examples/snake.ern:106-127) — Write one arm over a helper from `Terminal.Event` to `Optional(Direction)`, and `Escape or Interrupt` as one arm that leaves.
- **E98** `cheap`, S: web_server's four status and session helpers are its only unannotated functions, and `statusText` answers "400 Bad Request" for every code but 200 (examples/web_server.ern:213-226) — Annotate the four helpers, and write each status code the program has with its own text rather than "400 Bad Request" for every code but 200.
- **E99** `dropped`: file_sync and web_server each carry the same 13-line `errorText`, where tools/manual.ern writes an `Io.Error` with `Io.show` (examples/file_sync.ern:189-202; examples/web_server.ern:190-203) — decided: *`Other` Says the Host's Words*: the words for an error are the program's and the tables stay, two examples with the same lines being two programs that chose alike; neither example calls `Fs.append`, so its `NotAFile` word holds for them.
- **E100** `cheap`, S: The headers of the four "paper programs" still read as speculation: "Assumptions.", "Written against the Ernest report", "good enough on paper" (examples/file_sync.ern:2-13; examples/web_server.ern:2-11, :217; examples/snake.ern:2-16; examples/repl.ern:2-14) — State each of the four headers as fact, dropping "Assumptions.", "Written against the Ernest report" and "Paper program", web_server's "good enough on paper" going with E69.
- **E101** `cheap`, S: tools/manual.ern strips ".3ern" by counting graphemes, where `Path.extension` and `Path.withoutExtension` say it, and checks the sections after building the page (tools/manual.ern:120-126, :48) — Take the page names with `Path.extension` and `Path.withoutExtension`, and check for §11.7 and §11.8 before the page is built.
- **E102** `cheap`, S: echo listens on the fixed port 7345, where port 0 and `Tcp.port` avoid a clash with whatever else holds it (examples/echo.ern:15) — Listen on port 0 and connect to the port `Tcp.port` answers.
- **E103** `cheap`, S: The REPL's parser accepts `let` inside an expression, where it binds nothing, and nothing tells the user (examples/repl.ern:211, :310) — Read `let` only at the start of a line, a line being a `let` or an expression, and refuse it inside an expression with `Unexpected(LetKeyword)`, the grammar comment changing with it.
- **E104** `cheap`, S: Ets names half its raw bindings for the host's function and half for the Ernest operation (libs/ets/ets.ern:56-173) — Name every raw binding for the host function it binds, `rawDeleteAllObjects` and `rawDeleteTable` among them, in libs/ets and Appendix D.
- **E105** `cheap`, S: `render` writes an empty row of a block quote as "│ " with a trailing space (libs/markdown/markdown.ern:827) — Write the bar alone before an empty row of a block quote.

Where the language made the work harder

- **E106** `dropped`: A constant list of openers cannot be a top-level `let` when an opener reaches back to the list, so markdown rebuilds it on every block (libs/markdown/markdown.ern:175-178; report §8.5) — decided: *A Cycle Through a Function Stays One*: §8.5 counts what a named function depends on, called or not, OCaml's finer rule for an initializer that calls nothing was weighed and refused, and the cycle's help names `fn openers() = ...` as the way.
- **E107** `dropped`: With no type aliases, markdown spells `#(Block, List(String))` on 16 lines and the opener's function type twice in full; repl spells its parser's result 8 times (libs/markdown/markdown.ern:161-197; examples/repl.ern:225-295; report §3.1) — decided: *The Release Review's Questions* (and *Gleam Feature Pass*): Ernest has no type aliases, an alias being a second name for one type (principle 2), and a wrapper type is the way; a count of spelled-out types decides nothing.
- **E108** `done`: `Test` has no check that compares an answer with the expected one, so each tested module writes its own, and a failure shows only what the writer chose (report Appendix E.24; libs/markdown/markdown.ern:1553-1572; examples/file_sync.ern:208-217) — decided with the user: `Test.equal(actual, expected)` enters by E.0 rule 3, failing with `expected e, got a` (E.24; the log's *The Full Review's Questions, One by One*).

## The tools

### T, the tools

Defects

- **T1** `cheap`, M: A directory build or format stops at the first misnamed file: nothing is compiled or laid out, one refusal is shown at a time, named from the source root. (report/toolchain.md:19 (§11.1)) — Treat a misnamed path in a directory build or format as that one module's failure, report every such path named from the working directory, and compile or lay out the rest, as §11.1 says of a module that does not compile. Same as C177.
- **T2** `cheap`, M: `ern build` skips a module whose dependency failed and says nothing, so the user sees only the dependency's error and never learns the dependent was not compiled. (report/toolchain.md:19 (§11.1)) — Decided in triage: a directory build writes a line for each module it leaves uncompiled because a module it uses failed, naming that module, and §11.1 states it.
- **T3** `cheap`, M: `ern doc --man src-dir` never removes the page of a top-level module whose source is gone, though it removes a nested module's page. (erl/cli/src/ern_build.erl:772; report/toolchain.md:87 (§11.4)) — Compare the expected and the found page paths after normalizing both, so a top-level module's page whose source is gone is removed, with a test that removes a module at the root.
- **T4** `done`: `:doc` and `Shift-Tab` print a declaration's type as its module's page prints it, not as the shell does, so the type names things the session cannot name (report/toolchain.md:71 (§11.2, Documentation)) — done with C148.
- **T5** `done`: The prelude's page, `:doc` and `Shift-Tab` print the process primitives' types from hand-written strings that lack the checker's marks: `send : ... with m`, not `with m+`. (erl/typer/src/ern_prelude.erl:302, :399; report/toolchain.md:95 (§11.5)) — done with C43.
- **T6** `cheap`, M: A shadowed session type is named `$InputN` by a hidden module count, which does not match the `input N` that diagnostics and fault sites print. (report/toolchain.md:61 (§11.2, Scope); erl/cli/src/ern_shell.erl:165) — Print a shadowed session type under the count of the input that declared it, `$Input4.T`, the number its diagnostics show, as §11.2's example reads, keeping the module's own name a reused slot.
- **T7** `cheap`, M: In the shell, `:load` of a module whose dependency does not compile adds "compile A.Bad first: <absolute .erc path>", advice that does not apply in the shell. (erl/cli/src/ern_build.erl:643; report/toolchain.md:65 (§11.2, Loading)) — After a dependency's diagnostic, answer `:load` with `User is not loaded, since A.Bad does not compile` in place of the build's "compile A.Bad first" and its absolute `.erc` path. Same as T21.
- **T8** `cheap`, M: A doc block's heading of the wrong level is accepted, and it breaks the page: `#` in a declaration's block becomes a `.SH` section of the manual page. (report/toolchain.md:85 (§11.4)) — Refuse, at its `///` line, a heading above the level §11.4 allows, in `ern build` and `ern doc`, the sentence of the refusal added to §11.4.
- **T9** `cheap`, M: In the shell, a module on the load path or under the source root is an unknown name until `:load`, and the error does not say so. (report/toolchain.md:35 (§11.2)) — Give the unknown name and `:browse`'s refusal a help line, `:load Greet puts it in scope`, where the load path or the source root holds the module. Same as E88.
- **T10** `done`: One file gets two namespaces depending on the build mode, so rebuilding one file of a tree just built writes a second module that no sweep removes. (report/toolchain.md:21 (§11.1, Source root)) — decided with the user: the working directory stays the root, a file's namespace is its path from there, and a directory breaking the path shape is refused with the root that leaves it out (§11.1; the log's *The Full Review's Questions, One by One*).
- **T11** `cheap`, M: `ern doc src-dir` does `ern build`'s whole job, writing and sweeping `.erc` files, while `ern doc file.ern` writes none: building is done two ways. (report/toolchain.md:85 (§11.4)) — Decided in triage: `ern doc` writes pages and nothing else in both forms, compiling the tree without writing or sweeping `.erc` files, and §11.4 says so.
- **T12** `cheap`, M: Pressing `Shift-Tab` twice shows a `Since` line that `:doc` does not, though §11.2 says both show the same documentation. (erl/cli/src/ern_shell.erl:1091; report/toolchain.md:71 (§11.2)) — Render one text for `Shift-Tab`'s second press and for `:doc`, the declaration's §11.4 section, without the module's inherited `Since` appended to one of them. Same as C149.
- **T13** `cheap`, S: An option naming a missing directory (`--load-path`, `--config-dir`, the shell's `--source-root`) is accepted without a word, and so is a malformed `ernest.conf`. (report/toolchain.md:29 (§11.2), :124 (§11.7)) — Decided in triage: a `--load-path`, `--config-dir` or `--source-root` that names no directory is refused, naming it, and §11.7 states the refusal.
- **T14** `cheap`, S: Every job silently takes `--` as the end of its options, which §11 does not state. (report/toolchain.md:15 (§11)) — Decided in triage: §11 states that `--` ends a job's options, and that after a program's file every argument is the program's, a `--` among them, as the toolchain does now.
- **T15** `done`: The shell prints "M-Enter adds a line, Enter runs." the first time an input takes a second line, which §11.2 never states, though the code cites §11.2. (shell/shell.ern:1052-1059; report/toolchain.md:67 (§11.2, Editing)) — done with E47: §11.2 states the hint, `Enter runs a finished input, M-Enter adds a line.`, which the shell says.
- **T16** `cheap`, S: `:output /dev/null` is accepted, though §11.2 refuses a path that names neither a terminal nor a file. (shell/shell.ern:343; report/toolchain.md:50 (§11.2)) — Write "a terminal, a device or a file" in §11.2's `:output` item, since *What Erlang Held, Moved* decided that `:output` takes a device and refuses what is neither a file nor a device. Same as S15.
- **T17** `cheap`, S: `--main` takes a function of any module on the load path, so the file and `--main` both name the module to run and may disagree without a word. (report/toolchain.md:29 (§11.2)) — Decided in triage: a `--main` that names a function outside the module of the file given is refused, naming both modules, and §11.2 says so.
- **T18** `dropped`: The directory build deletes files and writes no line for any of them. (report/toolchain.md:25 (§11.1, Cleanup)) — decided: *The Toolchain's Clarity Lines*: a directory build says nothing of what it compiled or removed, as a build that succeeds does in the host's tools, and removes only what a build wrote.
- **T19** `cheap`, M: A doc block typed at the prompt is refused as soon as Enter is pressed, while a line holding only a `//` comment takes another line. (report/toolchain.md:67 (§11.2, Editing)) — Take an input that ends in a doc block as one the parser cannot finish, as §11.2's rule for an input the grammar expects more of says. Same as C5.
- **T20** `dropped`: `:browse M` and `M.` followed by `Tab` twice do the same job: each lists a module's names with their types. (report/toolchain.md:44, :69 (§11.2, Commands and Completion)) — decided: *What `Tab` Shows Stands Under the Line*: a `Tab` listing answers the line being typed, cut to the screen and gone at the next key, and `:browse` is the listing that stays.

Clarity

- **T21** `cheap`, M: Messages name files by absolute path even when they lie under the working directory, and "compile X first" names neither the module that needs X nor its place. (erl/cli/src/ern_build.erl:643, :182; report/toolchain.md:91 (§11.5)) — Name every path in the build's messages from the working directory as §11.5 does, and report an unbuilt dependency at the qualified name that needs it, naming the module. Same as T7.
- **T22** `done`: `ern doc`'s page and `:doc` show a function's type without parameter names, yet the doc text names parameters (`n`, `ms`, `mk`, `v`) that no argument is tied to. (report/toolchain.md:85 (§11.4); erl/typer/src/ern_prelude.erl:302) — decided with the user: a page shows a function's declaration, its parameters named, and the prelude's functions take names (§11.4; the log's *The Full Review's Questions, One by One*).
- **T23** `done`: `ern --help` says `format` follows "the style guide" and that `test` takes a module, and the usage lines differ from §11's. (erl/cli/src/ern_cli.erl:138, :140) — done with C196: each usage line is §11's synopsis, `format` and `test` are described as §11.6 and §11.2 do, and no line ends in a space; regression test synopses_are_the_reports_test_.
- **T24** `cheap`, S: The shell's `:help` says `:load` compiles from source, but `:load` also loads a compiled module from the load path. (shell/shell/command.ern:82) — Write `:load`'s help as "the module by its namespace, from its source or its compiled form".
- **T25** `cheap`, S: `ern doc notes.txt` answers "does not end in .ern", though `ern doc` takes a `.erc` too. (erl/cli/src/ern_build.erl:190) — Refuse in `ern doc` with "notes.txt ends in neither .ern nor .erc".
- **T26** `cheap`, S: `ern format - x.ern` answers "no such file or directory -" instead of saying that `-` stands alone. (report/toolchain.md:99 (§11.6)) — Refuse `-` among other paths as standing alone, and write a missing path first, `x.ern: no such file or directory`, as the other refusals do.
- **T27** `cheap`, S: `ern format -` writes nothing to standard output for a module that does not parse, and §11.6 says only that such a module "is left as it is". (report/toolchain.md:99 (§11.6)) — Decided in triage: on a module that does not parse, `ern format -` writes its input unchanged to standard output with status 1, its diagnostic on standard error, and §11.6 states it.
- **T28** `cheap`, S: The reload message "f, a binding in the previous version; a further reload of it ends them" mixes singular and plural, and hides that `f` runs old code. (erl/cli/src/ern_shell.erl:1990) — Reword the reload's line so that number agrees and the referent is the module, "Geo.Shape: f, a binding, holds the previous version; the next reload of Geo.Shape forgets it".
- **T29** `cheap`, S: With `HOME` unset, the shell says "HOME is no absolute path", and it does not say that no startup file was read. (shell/shell.ern:223; report/toolchain.md:77 (§11.2)) — Say "HOME is not set" where it is unset and "HOME is no absolute path" where it is relative.
- **T30** `cheap`, M: A reserved word used as a name is reported as "expected a name instead of `after`", which does not say that `after` is reserved. (report/toolchain.md:91 (§11.5)) — Report a reserved word where a name or a pattern is expected as "`after` is a reserved word, and names nothing", in the parser and the catalogue. Same as N6.
- **T31** `cheap`, S: A shell ended by standard input that is not UTF-8 prints `fault: ...`, the form of an input's fault, and does not say that the shell has ended. (report/toolchain.md:135 (§11.8)) — Write the shell's end by a standard input that is not UTF-8 as "the shell ends: its standard input is not UTF-8", not as an input's `fault:` line.
- **T32** `cheap`, S: The guide says to see what `ern format --check` wants by formatting a copy, while `ern format - < file` shows it without one. (ernest_guide.md:2366 (guide §9.1)) — Teach `ern format - < file` in the guide's §9.1 as the way to see what `--check` wants.
- **T33** `MVP 3.3`: `Home`, `End` and `Delete` do nothing at the prompt, though the line is said to be edited with Readline's Emacs keys, and Readline binds all three. (report/toolchain.md:67 (§11.2, Editing)) — Waits on item 1, Readline's remaining keys, which takes `Home`, `End` and `Delete` as `C-a`, `C-e` and `C-d`'s deletion by the same argument, §11.2's sentence that they do nothing changing with it.
- **T34** `cheap`, S: A tab after a command's name is not taken as a separator, and the refusal echoes the raw tab. (report/toolchain.md:41 (§11.2, Commands)) — Write a control character in a command's refusal as its escape, as a fault's cause is written; a tab after the name stays refused, as the report allows.

## Security

### S, security

Exposures

- **S1** `done`: `Tcp.close`, and an owner's death, leave the host socket and its unsent bytes open as long as the peer withholds reads, so remote clients can exhaust descriptors. (erl/runtime/src/ern_tcp.erl:287 (and :283 for the owner's death)) — decided with the user: the bytes go while the far end takes them, and are dropped with the connection reset 5 seconds after the last it took or 3 minutes after the end, however the socket ends (E.18; the log's *The Full Review's Questions, One by One*).
- **S2** `cheap`, M: `Fs.copy` creates its destination with the umask's mode rather than the source's, so a copy of a 0600 file can be read by every user. (erl/runtime/src/ern_fs.erl:164) — Decided in triage: `Fs.copy` creates a new destination with the source's permission bits less the umask, set before a byte is written, as cp(1) does, and E.17 says so.
- **S3** `done`: The shell runs a startup file whose group can write it or its directory, so another member of that group runs code as the user at the next `ern shell`. (shell/shell.ern:262) — decided with the user: a group's write stays let through, `$HOME/.ernest` is made its owner's alone in every session, and a startup file is checked as found, before any mode changes (§11.2; the log's *The Full Review's Questions, One by One*).
- **S4** `done`: Subscribing to the terminal, as `ern shell` does at a terminal, runs the first `sh` and `stty` on PATH, though the module refuses PATH's `stty` elsewhere (erl/runtime/src/ern_tty.erl:354) — done with C107.
- **S5** `done`: `Fs.removeAll` of an empty path, a name a client may send, faults its caller as the helper's failure instead of answering an error (erl/runtime/c_src/ern_exec.c:469) — done with C105.

Hardening

- **S6** `done`: `Path.<>` answers an absolute second operand whole and keeps `..`, so `root <> Path(name)` with a client's name reaches any file, and Path has nothing that confines. (stdlib/path.ern:40) — decided with the user: `Path.under(root, path)` answers the path under the root, `None` for an absolute or empty path or one with a `.` or `..` segment (E.14; the log's *The Full Review's Questions, One by One*).
- **S7** `done`: A process of the program that foreign code hands back at another address type is taken as the program's own, unchecked, so ill-typed messages reach its mailbox. (erl/runtime/src/ern_rt.erl:163; §8.4) — decided with the user: a process of the program's whose address foreign code was never given is a bad value where foreign code gives it as an address (§8.4; `docs/soundness.md`; the log's *The Full Review's Questions, One by One*).
- **S8** `dropped`: The standard library takes answers to its own calls unchecked even from a socket or program address foreign code made, so a foreign library's wrong answer reaches the shims. (§8.4; erl/runtime/src/ern_rt.erl:264) — decided: *The Release Review's Security Lines*: the same reader's finding that a library's call to a foreign process is answered unchecked was decided with the user, the runtime's own calls not checked, and §8.4's list of what is unchecked names it.
- **S9** `done`: Fs can create a file only with the umask's mode, so a program that writes a secret leaves it readable by all until a later `setMode`. (Appendix E.17; erl/runtime/src/ern_fs.erl:111) — decided with the user: E.17 states the host's mask and that a file no one else may read is made in a directory only its owner may enter; a function taking a mode waits for a program that needs it (the log's *Later*; the plan's MVP 3.2).
- **S10** `cheap`, L: `Fs.removeAll` holds a descriptor open for each level of the tree, so a tree deeper than the descriptor limit, which any writer of the directory can make, is not removed. (erl/runtime/c_src/ern_exec.c:432) — Walk with a bounded number of descriptors, closing each directory before descending and reopening the parent through `..` checked against its device and inode, still never by a path (E.17), with a test of a chain deeper than the descriptor limit.
- **S11** `done`: The shell makes `~/.ernest` its owner's alone, then reads and appends through a history link already there, so typed inputs go wherever that link points. (shell/shell/history.ern:53 (and :108)) — decided with the user: a history file that is a link, or anything but a regular file of the user's own, is neither read nor written, and the session says so once (§11.2; the log's *The Full Review's Questions, One by One*).
- **S12** `cheap`, S: bin/ern clears ERL_AFLAGS, ERL_FLAGS, ERL_ZFLAGS and ERL_LIBS but not ERL_COMPILER_OPTIONS, which every compile reads. With `.` on the code path, a .beam in the working directory runs. (bin/ern:59; erl/cli/src/ern_shell.erl:2434) — Pass `no_env_compiler_options` to the emitter's and the shell's `compile:forms` and drop `.` from the code path for every job, with a regression test (shown: `ERL_COMPILER_OPTIONS` reaches `ern build`).
- **S13** `cheap`, S: A program's environment gains PWD, which the launcher's sh exports, though §11 says the environment is the one `ern` was started in. (bin/ern:1; erl/runtime/c_src/ern_exec.c:94) — Keep PWD as given under `ERN_GIVEN_PWD` in bin/ern, and put it back or unset it in `given_environment`, as the nine names are, with a test of a program started without PWD.

Clarity

- **S14** `cheap`, S: E.18 says a socket has no options, but every listener sets the host's SO_REUSEADDR, a choice the report does not state. (erl/runtime/src/ern_tcp.erl:83; Appendix E.18) — State in E.18 that a listener reuses its address, the host's SO_REUSEADDR, so a server restarted while its old connections close can listen again.
- **S15** `cheap`, S: `:output` takes any device, `/dev/null` among them, where §11.2 takes only a terminal or a file. (shell/shell.ern:343; §11.2) — Write §11.2's `:output` as MVP 2.99c's item 5 decided it, a terminal, a file or another device, a named pipe refused (*What Erlang Held, Moved*), which the code already does. Same as T16.

Where the language made the work harder

- **S16** `done`: Fs has no read that refuses a link, so a program serving files under a root that others can write cannot stop a planted link from leading out. (Appendix E.17) — decided with the user: `Fs.readUnder` and `Fs.writeUnder` wait for a program serving files from a root others can write (the log's *Later*; the plan's MVP 3.2).
- **S17** `done`: One file whose name is not UTF-8 makes `Fs.list` fail for its whole directory, and no Path can name that file to remove it. (Appendix E.17 (`Fs.list`); §8.2) — decided with the user: the rule stands, whole or an error; a listing by bytes waits for a program that needs it (the log's *Later*; the plan's MVP 3.2).

## The readers' lists

Each list as its reader handed it in. A part of C or of E numbers its findings from 1, as its reader did; its heading gives the numbers they take in the lines above, and a reference to "finding n" within it is to its own number. A tab a reader quoted is written `<TAB>`, since no file of the repository holds one.

### P, the principles

#### Defects

1. **`Peer.spawn` and `Peer.spawnMonitored` are named in ten places, listed nowhere, and a program may take the namespace `Peer`**
   - Place: §8.3 (language.md:733), §3.8, §3.11, §6.2, §6.7, §7.4, §8.7, §10; Appendix E has no `Peer` section
   - Quote: "The module `Peer` acts on a peer by its configured name: `Peer.spawn(name, f)` and `Peer.spawnMonitored(name, f, wrap)`"
   - Wrong: §9 says a function is the prelude's where a rule of the report names it; §3.8, §3.11, §6.7, §8.3 and §8.7 name `Peer.spawn`, and neither §9 nor Appendix E gives it a type or a section. The toolchain refuses it for a later MVP, which the report does not say. §4.2 makes a standard library namespace taken, and `peer.ern` at a source root compiles and runs. The prelude's page carries `Peer`'s error under `spawnMonitored`. A reader who knows §9 predicts a listing with a type, as `spawn` has.
   - Shown by:
     ```
     $ cat peercall.ern
     export fn main() : Unit with Never = {
         let _ = Peer.spawn("foo", fn() : Unit with Never = Unit);
         Unit
     }
     $ ern build peercall.ern
     peercall.ern:2:13: Peer.spawn is not here yet: the module Peer, which acts on peers, arrives in MVP 3.0
     $ cat peerroot/peer.ern
     export fn spawn(name : String) : String = name
     $ ern build peerroot && ern run peerroot/main.erc     # main prints Peer.spawn("foo")
     foo
     $ printf ':doc spawnMonitored\n' | ern shell | grep -A2 Errors
     Errors

     `Fault("peer unreachable")` when the peer is unknown or cannot be reached.
     ```
   - Fix: Give `Peer` its section in Appendix E with both types, or state in §8.3 that the module waits and which section will hold it; take the namespace either way.

2. **The fill `C(..N)` is a second spelling that only shortens, and the names it takes do not appear at the use site**
   - Place: §5.6 (language.md:470), §4.9 (language.md:376)
   - Quote: "`Operations(..Set)`, a *fill*, names a namespace after `..` and takes each field not given beside it from the declaration of its name in that namespace"
   - Wrong: Principle 2 admits a second spelling only where the first would nest, repeat a body, or rebuild what a pattern holds, and "one that only shortens stays out"; the written construction neither nests nor repeats a body. Principle 3 says a top-level binding is visible when its name appears at the use site; `Set.fromList`, `Set.intersection` and `Set.toList` appear nowhere in `Operations(..Set)`. The fill also gives `..` a second meaning decided by what the name after it resolves to (finding 3). A reader who knows the rest of Ernest predicts the written form, which works, requirement supplied and all.
   - Shown by:
     ```
     $ cat fill.ern        # excerpt
     let filled : Operations(OrderedSet.Set(Int), Int) = Operations(..OrderedSet)
     let written : Operations(OrderedSet.Set(Int), Int) =
         Operations(fromList = OrderedSet.fromList,
                    intersection = OrderedSet.intersection,
                    toList = OrderedSet.toList)
     ... Io.println(Io.show(common([4, 2, 3], [3, 4, 5], filled)));
         Io.println(Io.show(common([4, 2, 3], [3, 4, 5], written)))
     $ ern build fill.ern && ern run fill.erc
     [3, 4]
     [3, 4]
     ```
   - Fix: Remove the fill from §5.6 and §4.9, or state in §0 which clause of principle 2 admits it and amend principle 3's sentence on use sites.

3. **A constructor named like a standard library module takes the fill away, and `..Prelude.Set` reaches nothing**
   - Place: §5.6 (language.md:470), §4.2 (language.md:307)
   - Quote: "The name after `..` is a namespace where it is a qualified name of type names alone that names no constructor or binding in scope, and an expression otherwise."
   - Wrong: A nullary constructor after `..` can never be a valid update, since it has no fields to take, yet it wins over the namespace, and the error names an update. §4.2 lets `Prelude.` carry "a namespace of the prelude or the standard library and one of its names", not a namespace alone, so the report is silent on `..Prelude.Set`; the toolchain reads it as a namespace that holds no declaration. The module has no spelling for the fill.
   - Shown by:
     ```
     $ cat fillcon.ern     # excerpt
     type Mode = Set
     let hashed : Operations(Set(Int), Int) = Operations(..Set)
     $ ern build fillcon.ern
     fillcon.ern:5:42: a record update gives at least one field after its `..`
       | = help: give the fields that change; with none, the value after `..` is the record
     $ sed -i 's/(\.\.Set)/(..Prelude.Set)/' fillcon.ern && ern build fillcon.ern
     fillcon.ern:5:55: Operations(..Prelude.Set) lacks fromList: Prelude.Set has no fromList
     ```
   - Fix: In §5.6, read a nullary constructor after `..` as the namespace, or in §4.2 let `Prelude.N` name a namespace after `..`, and say which the error names.

4. **`needs a.show` reaches the bare variable alone, and §11.5's help asks for an annotation no annotation can give**
   - Place: Appendix E.1 (library.md:157), §11.5 (toolchain.md:93)
   - Quote: "on any other type variable, and on a type that contains one, `List(a)` under `needs a.show`, it is a type error"
   - Wrong: §4.9 supplies a derived `Pair.compare` at `Pair(a, b)` from the enclosing requirement, so a reader predicts `Io.show` at `List(a)` or `Optional(a)` supplied the same way under `needs a.show`; nothing a program could write is bought by refusing it. §11.5 prescribes "the request to annotate it" for a type not known whole, and here the value is annotated and the requirement declared, so the help names a fix that cannot apply, against principle 3's "its error names what to write".
   - Shown by:
     ```
     $ cat showlist.ern    # excerpt
     fn showAll(xs : List(a)) : String needs a.show = Io.show(xs)
     fn showOne(x : a) : String needs a.show = Io.show(Some(x))
     $ ern build showlist.ern
     showlist.ern:1:50: Io.show writes a value by its type, which is not known whole here: List(a)
       | = help: annotate the value where it is bound; at a type variable of the signature, a requirement `needs a.show` lets it write the value
     showlist.ern:3:43: Io.show writes a value by its type, which is not known whole here: Optional(a)
     ```
   - Fix: Let `Io.show` write any type whose variables the requirement all name, as §4.9 supplies a derived member; else have §11.5 name a `show` parameter as the fix.

#### Clarity

5. **Principle 3's sentence on top-level bindings does not cover §8.5: a binding no use site names still acts at start**
   - Place: §0 (language.md:38), §8.5 (language.md:764)
   - Quote: "A top-level binding is visible when its name appears at the use site."
   - Wrong: §8.5 evaluates every binding of every module the entry point depends on, so a binding whose name appears at no use site prints, spawns and sends before `main` runs; `main`'s text shows none of it. The behaviour is §8.5's rule; §0's sentence invites the prediction that an unnamed binding does nothing.
   - Shown by:
     ```
     $ cat init/util.ern
     let banner = Io.println("util initialized")
     export fn double(n : Int) : Int = n * 2
     $ cat init/main.ern
     export fn main() : Unit with Never = Io.println(Int.toString(Util.double(21)))
     $ ern build init && ern run init/main.erc
     util initialized
     42
     ```
   - Fix: Add to principle 3 that a module's bindings run when the program starts (§8.5), which is where a service is visible.

6. **`let _ = e` of a pure `e` is accepted, though principle 3 says the compiler refuses what the text alone shows can have no effect**
   - Place: §0 (language.md:38), §5.4 (language.md:458)
   - Quote: "The compiler refuses what the text alone shows can have no effect, a value dropped, a clause that cannot run"
   - Wrong: `let _ = 5` and `let _ = Int.toString(1)` drop values the text shows pure, and the compiler accepts them; §5.4 makes `let _ =` the discard form without saying that it also discards what can have no effect. The two sentences leave the reader to guess which wins.
   - Shown by:
     ```
     $ cat dropped.ern     # excerpt
         let _ = 5;
         let _ = Int.toString(1);
     $ ern build dropped.ern && ern run dropped.erc
     dropped
     ```
   - Fix: Say in §0 or §5.4 that `let _ =` is accepted whatever its value, or refuse a `let _ =` whose initializer is pure.

7. **A module's own qualified name is allowed where nothing hides it, while `Prelude.` is refused there**
   - Place: §4.2 (language.md:289, 307)
   - Quote: "A use site may write a declaration's qualified name: within its own module for any declaration" / "`Prelude.Some` in a module that declares no `Some` is an error."
   - Wrong: Two spellings of one name in one module, `helper()` and `Qual.helper()`, where the second is needed only when a binding hides the first; the prelude's second spelling is refused exactly then, so the two rules decide the same question two ways.
   - Shown by:
     ```
     $ cat qual.ern
     fn helper() : Int = 1
     export fn main() : Unit with Never = Io.println(Int.toString(Qual.helper() + helper()))
     $ ern build qual.ern && ern run qual.erc
     2
     ```
   - Fix: Refuse a module's own qualified name where nothing hides the plain one, as `Prelude.` is refused, or state why the two differ.

8. **`kill` takes an `Address`, `monitor` a `Process`, and the report says why for one only**
   - Place: §6.9 (language.md:644), §9.5 (language.md:853)
   - Quote: "watching a process needs no address, since an address is the permission to send"
   - Wrong: A reader who takes the address as the permission to send predicts that ending a process, which is more than sending, needs the `Process` as `monitor` and `Tcp.give` do, or that both take an address; the report chooses one for each and argues one.
   - Shown by: none
   - Fix: One sentence in §6.9 saying what the address permits beyond sending, or `kill : (Process) -> Unit with m`.

9. **A declared operator member may answer any type, but a requirement's operator must answer the variable, so the one cannot meet the other**
   - Place: §4.8 (language.md:362), §4.9 (language.md:370)
   - Quote: "A member named by an operator has the type `(T, T) -> R`" / "an operator `a.+` the type `(a, a) -> a`"
   - Wrong: `fn Vec.*` answering `Float` is a member by §4.8 and not one `needs a.*` can be supplied with, so a function over `*` is written twice, once with the requirement and once with a parameter; a reader who knows §4.9 predicts members of one shape.
   - Shown by:
     ```
     $ cat member2.ern     # excerpt
     fn Vec.*(a : Vec, b : Vec) : Float = a.x * b.x + a.y * b.y
     fn square(v : a) : a needs a.* = v * v
     ... Io.show(square(Vec(x = 1.0, y = 2.0)))
     $ ern build member2.ern
     member2.ern:7:57: square needs Vec.* : (Vec, Vec) -> Vec, and Vec.* answers Float
     ```
   - Fix: Give §4.8's operator member the shape `(T, T) -> T`, or say in §4.8 that a member of another result type stands outside requirements.

10. **`Io.show` and `Io.debug` are the prelude's under a library namespace, and the shell's prelude listing omits them and `String.compare`**
    - Place: §9.4 (language.md:834), §9 (language.md:786), §11.2 (toolchain.md:44)
    - Quote: "### 9.4 Built-in functions (§6)" listing `Io.show` and `Io.debug`
    - Wrong: Every other prelude function is bare or a member of a prelude type; these two carry a standard library module's name, under a heading that cites §6, which they have nothing to do with. `:browse Prelude`, which "lists the prelude's types and values (§9)", lists 30 functions: not `Io.show`, not `Io.debug`, and not `String.compare`, which §9.6 lists.
    - Shown by:
      ```
      $ printf ':browse Prelude\n' | ern shell | grep -c ' : '
      30
      $ printf ':browse Prelude\n' | ern shell | grep -E 'String\.|show|debug'
      String.<> : (String, String) -> String
      ```
    - Fix: Name the two `show` and `debug` in the prelude or move them to E.1 and out of §9.4's count; have `:browse Prelude` list every function of §9.4 to §9.6.

11. **Five system modules name no primitives, though E.0 rule 1 says each module's section names them**
    - Place: Appendix E.0 rule 1 (library.md:120); E.15, E.17, E.18, E.21, E.23
    - Quote: "each module's section names its *primitives*; in a system module, a function that reaches its process is a primitive"
    - Wrong: E.1 and E.16 name theirs; E.15, E.17, E.18, E.21 and E.23 do not, so which of `Clock.monotonic`, `Fs.list`, `Os.run` or `Process.fromAddress` reaches a process is left to the reader, and the count of primitives cannot be taken from the report.
    - Shown by: none
    - Fix: Each of the five sections names its primitives as E.1 does.

12. **`with m` on a body that needs no process is a second spelling of a pure signature**
    - Place: §3.9 (language.md:245), §11.5 (toolchain.md:95)
    - Quote: "So one annotation can give two behaviours: `fn h(a : Int) : Unit with e = Unit` can be called from pure code"
    - Wrong: `fn k() : Int with m = 5` and `fn k() : Int = 5` are one function, printed alike; the language accepts both spellings and says nothing of which to write, against principle 2's one way.
    - Shown by: none; §11.5's own example `fn k() : Int with m = 5` prints as `() -> Int`
    - Fix: State in §4.5 that `with m` is written only where the body needs it, or that it is the annotation for a function whose effect the body decides.

13. **Appendix A reads `a.compare` by the enclosing signature, which no token shows**
    - Place: Appendix A (language.md:971)
    - Quote: "an `ident`, `.` and `compare` or `negate` where the `ident` is a type variable of the enclosing declaration's signature and the declaration has a requirement"
    - Wrong: Principle 4 dispatches on tokens; this form is decided by the declaration's signature and requirement, three tokens the same either way. The parser reads a selection and rewrites it afterwards, which is bounded but is not what the paragraph says.
    - Shown by: none
    - Fix: Say that the parser reads a selection and that §4.9 makes it a member, and drop the condition from Appendix A's paragraph.

#### Rules that buy little

14. **§6.9's second paragraph, the restart a supervisor asks for, exists for Appendix E.22 alone**
    - Place: §6.9 (language.md:648), E.22 (library.md:549)
    - Quote: "A child of a `Supervisor` (Appendix E.22) also runs `f()` again when its supervisor asks."
    - Wrong: A rule of the language with three private primitives beneath it, `askRestart`, `spawnOrder` and `startCause`, serves one library module. It buys a group restart that keeps every address. Without it a supervisor would kill and spawn its children, and the addresses a service binding holds would change: the language would lose `OneForAll` and `RestForOne` as E.22 has them, and keep `restarting`.
    - Shown by: none
    - Fix: Keep it, and name the three primitives in §6.9 as what the rule asks of the runtime, so that the count outside §9 is the report's.

15. **§8.7, code shipping, exists for `Peer.spawn` alone, which is not there**
    - Place: §8.7 (language.md:772), §10 (language.md:894)
    - Quote: "Only a spawn on a peer ships code"
    - Wrong: Content addressing, resolution, identity and the binding rules bind nothing a program can run (finding 1). They buy the peer's semantics ahead of the peer. Without them the language would lose nothing today and the report a section.
    - Shown by: none
    - Fix: Keep them with §8.3 saying that `Peer` waits, or move them with `Peer` to the section that will hold it.

16. **`export` is required on `abstract type`, where it says nothing**
    - Place: §4.4 (language.md:315), Appendix A
    - Quote: "An abstract type is exported: one the module keeps private is an error."
    - Wrong: The only legal form is `export abstract type`; the word buys a uniform scan for `export` and costs a word that cannot be left out. Without the rule, `abstract type` would mean exported, and a reader scanning for `export` would miss it.
    - Shown by:
      ```
      $ cat abstract.ern
      abstract type Stack(a) = Stack(List(a))
      export let empty = Stack([])
      $ ern build abstract.ern
      abstract.ern:1:1: Stack is an abstract type the module keeps private, which hides its constructors from no module
        | = help: export it, or declare it `type`
      ```
    - Fix: Either is fine; say in §4.4 which the uniform scan is worth.

17. **`needs` and `derives` are reserved where no identifier can stand**
    - Place: §2.4 (language.md:96), Appendix A
    - Quote: "Twenty, grouped by role"
    - Wrong: `needs` follows a `)` or a result type, and `derives` the last constructor; no rule lets an identifier stand there, so both could be contextual as `size` and `big` are (§5.11). Reserving them buys nothing a program can see and costs two identifiers and two of the count.
    - Shown by: none
    - Fix: Make both contextual, keeping the reserved words at eighteen, or say what reserving them buys.

18. **`Prelude` and the shadowing of prelude names exist for shape rule 7**
    - Place: §4.2 (language.md:307), E.0 shape rule 7 (library.md:136), E.25, E.26
    - Quote: "`Prelude` names the prelude's own namespace, so `Prelude.Some` is the prelude's `Some` in a module that declares its own."
    - Wrong: The library shadows a prelude name twice, `OrderedSet.Set` and `OrderedMap.Map`, because shape rule 7 names a type for what it is within its module; shadowing then needs `Prelude.`, a contextual word with a rule of its own. They buy those two names. Without them, with prelude names refused to a module's types, the language would lose shadowing a reader of ML expects and the two modules would name their types `Ordered`.
    - Shown by: none
    - Fix: Keep them, or let shape rule 7 name a type for what it is outside its module too.

19. **Prefix `!` beside `Bool.not`**
    - Place: §2.6 (language.md:152), §4.8 (language.md:364), E.7
    - Quote: "`!` is negation on `Bool`, ... and `Bool.not` (E.7) is the same operation as a function"
    - Wrong: Two spellings of one operation, one in the language; `!` buys one character over `Bool.not(x)` and a form the reader of ML, who writes `not x`, does not predict. Without it the language would lose a prefix operator and the pairing with `&&` and `||`.
    - Shown by: none
    - Fix: Keep one; if `!`, say in §4.8 what it buys over `Bool.not`.

#### Counts

- Reserved words: 20, against 18. Counted from §2.4's table and the lexer's list, 18 words plus `true` and `false`; `needs` and `derives` are the two more (finding 17).
- Contextual words: 14, or 15 with `Prelude`, against 11 or 12. Counted as every quoted lowercase word of Appendix A not in §2.4's table: the eleven bit specifiers and `compare`, `negate` and `show` in `Member`, `DeclName` and `Primary`; `Prelude` by §4.2.
- Prelude types: 21, against 21. Counted from §9.1 (10), §9.2 (3) and §9.3 (8); `:browse Prelude` lists 21.
- Prelude functions: 33, against 33. Counted from §9.4 (6, `Io.show` and `Io.debug` among them), §9.5 (7) and §9.6 (20); `:browse Prelude` lists 30, without `Io.show`, `Io.debug` and `String.compare` (finding 10).
- Primitives outside §9: 4, against 2: the system references (§8.2) and E.22's `askRestart`, `spawnOrder` and `startCause`, which §6.9's restart asked for needs (finding 14). E.0 rule 1 now names 5 sources, against 4: a representation the runtime owns, its path syntax, Unicode's tables, the floating-point library's, and a process of the runtime's.
- Taken namespaces: 28, against 26. Counted by §4.2 as the 26 modules of Appendix E.1 to E.26 and the prelude's `Prelude` and `Address`; the other prelude types with members, `Int`, `Float`, `String`, `Char`, `List`, `Bytes` and `Path`, are already modules. `OrderedSet` and `OrderedMap` are the two more.
- Concepts: 117, against 112. Appendix F has 137 entries, against 132; 20 cite the toolchain or the library alone (admission rule, build root, child, configuration directory, container, diagnostic, grapheme, group, line mode, live region, load path, runner, sequence, shape rule, shim, span, startup file, strategy, supervisor, vocabulary).
- Inferred restrictions: 3, against 3, and printed marks 3, against 3: `=`, `!`, `+` as §11.5 lists them.
- Primitives as Appendix E's sections name them: 86, against 87. Counted from each section's sentence: E.1 10, E.3 6, E.4 6, E.5 14, E.6 10, E.8 9, E.9 15, E.12 7, E.14 2, E.16 2, E.19 1, E.20 1, E.22 3; E.15, E.17, E.18, E.21 and E.23 name none (finding 11), and E.1's `show` and `debug` are counted again among the prelude's functions.
- `foreign fn`s as built: 93, against 93, by `grep -c 'foreign fn' stdlib/*.ern`.
- Listed functions: 305 in Appendix E, against 256, counted as lines of the form `Name.name : type` in its code blocks, values among them, of which E.25 and E.26 hold 44; 20 in Appendix G, against 20.

### K, the cold reader

#### Defects

1. **§8.5's dependency order misses the members a requirement supplies, so a well-typed program reads a binding with no value and faults**
   - Place: report/language.md:764 (§8.5); docs/soundness.md:115 (section 5)
   - Quote: "A binding depends on every top-level `let` its initializer names, and on what every function it names depends on, called or not"
   - Wrong: `T.compare`, which `needs a.compare` supplies to `OrderedSet.fromList` at `T`, is named nowhere in `s`'s initializer, so `s` is evaluated in declaration order, before the `offset` that `T.compare` reads. The run faults with the cause §7.4 gives only to a faulting reload, "the binding has no value, since one before it faulted", though nothing faulted and nothing was reloaded. The argument's "A name is read only after its binding has a value" rests on §8.5 and does not follow from it. An operator's member is followed: the same program with `let x = T(1) + T(2)` over an `fn T.+` that reads `offset` prints `T(13)`.
   - Shown by:
     ```
     type T = T(Int)
     fn T.compare(T(a) : T, T(b) : T) : Ordering = Int.compare(a + offset, b + offset)
     let s = OrderedSet.fromList([T(2), T(1)])
     let offset = 10
     export fn main() : Unit with Never = Io.println(Io.show(OrderedSet.toList(s)))
     // ern run: Main.s:5 faulted: the binding has no value, since one before it faulted
     ```
   - Fix: §8.5: a binding depends also on every member a requirement, a fill (§5.6) or a derived `compare` supplies, in its initializer and in the functions it names, as it does on an operator's.

2. **`restarting` is not process-only, so a pure function restarts its process, emptying its mailbox and ending the calls waiting on it**
   - Place: report/language.md:852 (§9.5), :241 (§3.9); docs/soundness.md:13 (claim 3), :155 (6.3)
   - Quote: "restarting : (RestartLimit, () -> Unit with n) -> () -> Unit with n"
   - Wrong: `n` stands in effect positions alone, and §3.9 makes process-only only the §9.4 and §9.5 functions "whose own effect is a mailbox type"; `restarting`'s own effect is none, so with a pure `f` the function it returns is pure and `fn tryIt(n : Int) : Int` may call it. When `f` faults the process restarts, and §6.9 then empties its mailbox, ends every call waiting on it and cancels its alarms, monitors and subscriptions, all from a function whose type says it "affects nothing" (§0). Claim 3, "a function whose type has no `with` acts through no process", fails, and 6.3's list of what must not be taken for pure omits it.
   - Shown by:
     ```
     fn tryIt(n : Int) : Int = {
         restarting(RestartLimit(restarts = 1, within = 10000), fn() = if n == 0 then fault("boom") else Unit)();
         n
     }
     export fn main() : Unit with Int = { send(self(), 1); let _ = tryIt(0); receive { x -> Unit | after 100 -> Unit } }
     // ern run: Main.main faulted, restarted: boom
     //          Main.main faulted: boom
     ```
   - Fix: §3.9 and §9.5: `restarting`'s `n` is treated as if it stood in a value position, so the function it returns is never pure; 6.3 names it beside `send` and `spawn`.

3. **§9.4 states no restriction on `Io.show` and `Io.debug`, though §3.9 sends the reader to §9 for it and E.1 relies on it**
   - Place: report/language.md:841-842 (§9.4), :245 (§3.9); report/library.md:157 (E.1); docs/soundness.md:185 (6.7)
   - Quote: "Io.show : (a) -> String" and, in §3.9, "Where there is no body, a restriction is given instead: ... stated for the prelude's types and primitives in §9"
   - Wrong: §9 states none for either. E.1 asserts "no reply reaches `Io.show`, whose argument is no reply-carrying type (§6.6)", and nothing in §6.6 or §9 says so. A checker built from the report accepts `let _ = Io.show(reply); Unit`, which drops the reply and breaks claim 4; the toolchain refuses it with `Io.show : (a!) -> String`, a mark the report never gives the function. 6.7's "What has no body is restricted by rule: ... the prelude's by §9" does not follow for these two.
   - Shown by:
     ```
     type Req = Get(reply : Reply(Int))
     fn serve(request : Req) : Unit with m =
         match request { Get(reply = reply) -> { let _ = Io.show(reply); Unit } }
     // ern build: a reply-carrying value, Reply(Int), passed where Io.show duplicates or
     // discards its argument: Io.show : (a!) -> String   (refused by a rule the report lacks)
     ```
   - Fix: §9.4: "the `a` of `Io.show` and `Io.debug` is not reply-carrying (§6.6)", or print the mark in their lines.

4. **§5.9's redundancy rule, read as written, refuses every clause after a guarded one whose pattern covers the type; how a guard counts is unstated**
   - Place: report/language.md:490 (§5.9)
   - Quote: "A clause, or an alternative of one, is *redundant* when it can match no value the clauses and alternatives before it leave unmatched ... guards do not count toward coverage."
   - Wrong: The sentence on guards is about coverage alone. For redundancy, the pattern `n` of a guarded clause leaves no value unmatched, so `n when n > 0 -> 1 | n -> 0` is refused by the rule as written. The section states the needed rule for bitstring patterns and not for guards. The toolchain takes an earlier guarded clause as matching no value and the clause judged by its pattern alone: it accepts the program, accepts two identical guarded clauses, and refuses `_ -> 0 | n when n > 0 -> 1`.
   - Shown by:
     ```
     fn sign(n : Int) : Int = match n { n when n > 0 -> 1 | n -> 0 }
     // ern run: accepted, prints as expected; the text refuses the second clause
     ```
   - Fix: add "For redundancy, a guarded clause before is taken to match no value, and the clause being judged is taken by its pattern alone."

5. **Soundness 6.1's reason that a `fn` may always be generalized does not hold for a local `fn` that captures a block's process**
   - Place: docs/soundness.md:147 (6.1); report/language.md:235 (§3.9)
   - Quote: "A `fn` is always generalized: each call makes its processes anew, so two instances share none."
   - Wrong: `fn get() = c`, declared in a block after `let c = spawn(fn() = cell(None))`, makes no process: every call answers the one `c`. Generalized over the variable in `c`'s type, `get()` would be `Address(Cell(Optional(a)))` at every `a`, the hole 6.1 describes. The checker is sound here by section 3's "quantifies the variables of their type which `Γ` does not hold", not by the reason 6.1 gives, and §3.9 itself says only "generalized over their free type variables", which, read alone, includes the variable of `c`.
   - Shown by:
     ```
     type Cell(a) = Put(a) | Get(reply : Reply(a))
     fn cell(v : a) : Unit with Cell(a) = receive { Put(x) -> cell(x) | Get(reply = r) -> { answer(r, v); cell(v) } }
     export fn main() : Unit with m = {
         let c = spawn(fn() = cell(None));
         fn get() = c;
         send(get(), Put(Some(1)));
         match Address.call(get(), fn(r) = Get(reply = r), 100) { Some(Some(s)) -> Io.println(s) | _ -> Unit }
     }
     // ern build: the argument does not fit Io.println: expected String, found Int  (sound, for another reason)
     ```
   - Fix: §3.9: "over the type variables of their type that no name in scope around them holds"; 6.1 argues from that, with the local `fn` as its example.

6. **§4.6 forbids a top-level initializer to receive; §6.8 lets a `Never` body wait in an `after`-only `receive`, and the toolchain accepts one**
   - Place: report/language.md:352 (§4.6), :638 (§6.8)
   - Quote: "The initializer is a body of mailbox type `Never` (§6.8): it may spawn, send, and call, and it may not receive."
   - Wrong: §6.8, which the sentence cites, says "a `receive` with only an `after` clause is how a `Never` process waits", so the sentence refuses what its citation allows.
   - Shown by:
     ```
     let waited = receive { after 10 -> 1 }
     export fn main() : Unit with Never = Io.println(Int.toString(waited))
     // ern run: 1
     ```
   - Fix: §4.6: "and it receives no message: a `receive` in it has only an `after` clause (§6.8)".

7. **Two of the report's own examples are refused by §4.2: `export fn Distance.+` over a private `Distance`, and `export let log : Address(LogMsg)` over a private `LogMsg`**
   - Place: report/language.md:362 (§4.8), :583-584 (§6.5), :289 (§4.2)
   - Quote: "`Distance.+` when `a : Distance`, for `type Distance = Distance(Int)`. A user type declares its operators in its own module: `export fn Distance.+(Distance(a), Distance(b)) : Distance = Distance(a + b)`"
   - Wrong: §4.2 says "The type of an exported declaration ... may not name a type the module keeps private", and exempts a function's mailbox type alone. As written, both are refused. A reader of §6.5 also learns only by this refusal that a service's message type is exported with its constructors, so every module that sees the service may build its messages.
   - Shown by:
     ```
     type Distance = Distance(Int)
     export fn Distance.+(Distance(a), Distance(b)) : Distance = Distance(a + b)
     // ern build: Distance.+ is exported and its type names Distance, which this module keeps private
     type LogMsg = Log(String)
     export let log : Address(LogMsg) = spawn(restarting(RestartLimit(restarts = 3, within = 5000), logger))
     // ern build: log is exported and its type names LogMsg, which this module keeps private
     ```
   - Fix: write `export type Distance` and `export type LogMsg` in the examples, and say in §6.5 that a service's message type is exported.

8. **§10 cites Appendix E.4, the set module, for the Unicode tables that decide a `Char`'s category and case; those are E.6's**
   - Place: report/language.md:889 (§10)
   - Quote: "(Appendix E.4, E.5, E.16)"
   - Wrong: E.4 is `set.ern`; the `Char` predicates and case mappings are E.6, `char.ern`. Every other section reference in the three files resolves.
   - Shown by: none
   - Fix: "(Appendix E.6, E.5, E.16)".

#### Clarity

9. **A local `fn` that names a parameter which a later `let` of its block shadows: §5.4's two sentences give two answers**
   - Place: report/language.md:460 (§5.4)
   - Quote: "The body of a local `fn` sees the bindings in force at its declaration. ... A `fn` body that references a `let` declared later in the block is a compile-time error."
   - Wrong: `fn f() = x; let x = 5; f() + x` with a parameter `x`: by the first sentence `f`'s `x` is the parameter, by the second the program is refused. The toolchain takes the first and prints 6; a builder must guess.
   - Shown by:
     ```
     fn outer(x : Int) : Int = { fn f() = x; let x = 5; f() + x }
     // ern run: outer(1) prints 6
     ```
   - Fix: "A name a local `fn` reads is the binding in force at its declaration; a later `let` of that name does not reach it."

10. **§4.2 makes two declarations of one name an error only when both are exported; two private ones are left unsaid**
    - Place: report/language.md:289 (§4.2)
    - Quote: "Two exported declarations with the same qualified name are an error."
    - Wrong: `fn f` beside a private `let f` is refused, `value f is declared twice`, by a rule the report does not state.
    - Shown by:
      ```
      fn f(x : Int) : Int = x
      let f = 1
      // ern build: value f is declared twice
      ```
    - Fix: "Two declarations of one name in a module are an error."

11. **§4.2 says a module may declare a type or constructor with a prelude name; whether a function or a `let` may is unsaid**
    - Place: report/language.md:307 (§4.2)
    - Quote: "A module may declare a type or constructor with a prelude name, and the name then means the local one throughout the module."
    - Wrong: `fn send(x : Int) : Int` compiles and hides the prelude's `send` in its module; the lookup order implies it, but the sentence names types and constructors alone.
    - Shown by:
      ```
      fn send(x : Int) : Int = x + 1
      export fn main() : Unit with Never = Io.println(Int.toString(send(1)))
      // ern run: 2
      ```
    - Fix: "A module may declare a name the prelude declares, a type, a constructor, a function or a value, and ..."

12. **§3.9 says nothing of the order in which a module's definitions are inferred, nor that a mutually recursive group is inferred as one**
    - Place: report/language.md:235 (§3.9), :344 (§4.5)
    - Quote: "polymorphic recursion is not, even where the whole signature is written: a recursive call is at the definition's own type."
    - Wrong: `fn useId() = #(id(1), id("a"))` with `fn id(x) = x` declared after it compiles, so definitions are inferred in dependency order and not in source order; `first` and `second`, each calling the other at another type, are refused, so a group is monomorphic within itself. Neither is written; a builder who infers in source order, or who generalizes each definition alone, conforms to the text and decides other programs otherwise.
    - Shown by:
      ```
      fn useId() = #(id(1), id("a"))
      fn id(x) = x                          // accepted: #(1, "a")
      fn first(x) = { let _ = second(1); x }
      fn second(y) = { let _ = first("a"); y }
      // ern build: the argument does not fit first: expected String, found Int
      ```
    - Fix: "Definitions are inferred in dependency order; a group of mutually recursive definitions is inferred together, and each call within the group is at the definition's own type."

13. **Appendix A lets a result annotation carry two `with`s, `(A) -> B with M with N`, a second spelling of `((A) -> B with M) with N`**
    - Place: report/language.md:275 (`Return`), :201 (§3.4)
    - Quote: "Return      = ":" Type [ "with" Type ] ."
    - Wrong: `Type` may be an `FnType` that has taken a `with` of its own, so `fn f() : (A) -> B with Int with Never = fn(a) = B` parses, with mailbox `Never` and result `(A) -> B with Int`; §3.4 writes that type only as `((A) -> B with M) with N` and never mentions the other, against principle 2.
    - Shown by:
      ```
      fn f() : (A) -> B with Int with Never = fn(a) = B
      // ern build: accepted
      ```
    - Fix: §3.4 names the form, or Appendix A's prose refuses a `with` directly after a `with`.

14. **§6.6 says a lambda holding a reply is consumed "as the function argument of `spawnMonitored`", which takes two functions**
    - Place: report/language.md:607 (§6.6)
    - Quote: "consumed exactly once, by a call or as the function argument of `spawn` or `spawnMonitored`"
    - Wrong: `spawnMonitored(f, wrap)` has two function arguments. The toolchain refuses a `wrap` that captures a reply, with a message that says the lambda may be "passed directly to spawn or spawnMonitored", so its own text reads the rule both ways.
    - Shown by:
      ```
      let _ = spawnMonitored(fn() = Unit, fn(d) = Done(down = d, reply = r));
      // ern build: the reply-carrying value r is captured by a lambda that is not called,
      // bound by `let`, or passed directly to spawn or spawnMonitored
      ```
    - Fix: "as the first argument of `spawn` or `spawnMonitored`".

15. **§9.4 is headed "Built-in functions (§6)" and lists `Io.show` and `Io.debug`, which §6 does not define and §9 gives to `io.ern`**
    - Place: report/language.md:834-843 (§9.4), :786 (§9)
    - Quote: "`Address.call` and `Address.callForever` are the runtime's, as the rest of §9.4 and §9.5 are."
    - Wrong: the sentence before it says "`Io.show` and `Io.debug` of §9.4 by `io.ern`", so "the rest of §9.4" is not the runtime's, and the heading's "(§6)" sends a reader to a section that never mentions them.
    - Shown by: none
    - Fix: list the two under a line of their own, and write "as the rest of §9.5 and the process functions of §9.4 are".

16. **A prelude type is used in §3 before §9 defines it, with no pointer: `Optional`, `Path`, `Map`, `Ordering`, `Less`, and `Fault` before §7.3**
    - Place: report/language.md:181 (§3.1), :210 (§3.5), :249 (§3.10)
    - Quote: "`type Snapshot = Snapshot(directory : Path, seen : Map(Path, Int))`"
    - Wrong: a cold reader meets `Optional` and `Fault("...")` in §3.1, `Path` and `Map` in §3.5, and `Ordering` and `Less` in §3.10 as given names; `Fault` is explained in §7.3 and the types in §9.2 and §9.3, and none of those places is cited at the first use.
    - Shown by: none
    - Fix: cite §9.3 at the first use of each type and §7.3 at the first `Fault`.

17. **§2.5 says `\u{...}` denotes a scalar value and excludes surrogates, but not that `'\u{D800}'` is an error**
    - Place: report/language.md:119 (§2.5)
    - Quote: "`\u{...}` denotes a Unicode scalar value, U+0000 through U+10FFFF excluding the surrogates U+D800 through U+DFFF."
    - Wrong: the sentence says what the escape denotes and not what a surrogate escape does, where the same section says of `1_` and `0x1g` that each is an error; the toolchain refuses it.
    - Shown by:
      ```
      Io.println(Io.show('\u{D800}'))
      // ern build: \u{D800} is not a Unicode scalar value
      ```
    - Fix: add "A surrogate, and a value above U+10FFFF, is an error: `'\u{D800}'`."

18. **Soundness 6.4 says a function that returns what it receives, called in an initializer, "waits for ever"; §8.6 faults it with a deadlock**
    - Place: docs/soundness.md:159 (6.4); report/language.md:638 (§6.8), :764 (§8.5), :770 (§8.6)
    - Quote: "A function that returns what it receives, called there, waits for ever."
    - Wrong: `let got = next()` with `fn next() = receive { x -> x }` is accepted at `Never`, which passes §6.8's refusal of a pattern-clause `receive` at `Never` by a call, and the run ends with `Main.got:3 faulted: deadlock`. §8.5's "An initializer that does not terminate prevents the remaining initializers and `main` from running" and §8.6's deadlock fault describe the one case two ways, and §6.8 does not say its refusal is of a `receive` written in the body alone.
    - Shown by:
      ```
      fn next() = receive { x -> x }
      let got = next()
      export fn main() : Unit with Never = Io.println("main ran")
      // ern run: Main.got:3 faulted: deadlock
      ```
    - Fix: 6.4: "waits, and the runtime faults it with `Fault("deadlock")` (§8.6)"; §6.8: "a `receive` with a pattern clause written in it is a type error".

19. **Soundness's (receive) rule drops the guard that its own grammar line gives a `receive` clause**
    - Place: docs/soundness.md:70-71 (section 3), :50
    - Quote: "(receive)  each pᵢ : M binds Γᵢ,  Γ, Γᵢ ⊢ eᵢ : τ ! M,"
    - Wrong: the expression grammar writes `receive { p when e -> e | … }` and §6.3 restricts the guard; the rule types neither it nor its purity, on which 6.3 then relies, "A guard is evaluated while a message is selected (§6.3). ... Each is typed pure."
    - Shown by: none
    - Fix: add `Γ, Γᵢ ⊢ gᵢ : Bool ! pure`, as (match) has.

20. **Appendix E's listings hide the not-reply-carrying mark, so a reader cannot tell from E.2 that `List.size` takes no list of replies**
    - Place: report/library.md:114 (Appendix E), :164 (E.2), :369 (E.10)
    - Quote: "A listing gives each function's type as an annotation writes it, without the inferred restrictions of §3.9: `ern doc` prints every restriction (§11.5)."
    - Wrong: `List.size : (List(a!)) -> Int` and `Optional.withDefault : (Optional(a!), a!) -> a!` refuse a reply where `List.map : (List(a), (a) -> b with e) -> List(b) with e` takes one; which is which can be learned only from the toolchain, and the report is the normative document.
    - Shown by:
      ```
      printf ':type List.size\n:type List.map\n' | ern shell
      > List.size : (List(a!)) -> Int
      > List.map : (List(a), (a) -> b with e) -> List(b) with e
      ```
    - Fix: print the marks in the listings, as §11.5 prints them.

#### Where the language made the work harder

21. **A single-file build is refused for the case of a directory above the file, since the working directory is the source root**
    - Place: report/toolchain.md:21, :23 (§11.1)
    - Quote: "Otherwise single-file mode uses the current directory"
    - Wrong: `ern build tA/main.ern` is refused with `path component tA must be lowercase`, though one file was asked for and the directory names no namespace any module uses; every program here had to live under a lowercase directory or be built with `--source-root`.
    - Shown by:
      ```
      ern build tA/main.ern
      // ern build: tA/main.ern: path component `tA` must be lowercase
      ```
    - Fix: in single-file mode take the file's own directory as the source root, or check the file's name alone.

22. **A constructor of two positional fields is refused, so a message of two parts must name them**
    - Place: report/language.md:205 (§3.5)
    - Quote: "A constructor has no fields, exactly one positional field, or named fields"
    - Wrong: `Done(Down, Reply(Int))` is a syntax error at its comma, and the reader of §0 who knows ML writes it before reading §3.5; I wrote `Done(down : Down, reply : Reply(Int))` and the pattern `Done(down = _, reply = r2)` for what that reader writes `Done(d, r)`. The rule is stated, and it still cost a retry.
    - Shown by:
      ```
      type Msg = Done(Down, Reply(Int))
      // ern build: expected `)` instead of `,`
      ```
    - Fix: none asked; noted as the friction the principle's reader meets.

### G, the register

#### Defects

1. **§11.2 gives the prompt's `let` a reason, "so that a lambda it binds is generalized", that is false: a top-level `let` generalizes a lambda too.**
   - Place: report/toolchain.md:39 (§11.2, *Inputs*)
   - Quote: "A `let` at the prompt binds as a `let` in a block does (§4.6), not as a top-level `let`, so that a lambda it binds is generalized, and stands alone in its input."
   - Wrong: A purpose clause argues instead of stating, and its reason does not tell the two forms apart: §3.9 and §4.6 generalize a top-level `let` whole, and a block `let` only where it binds a lambda. What the block form decides is that any other initializer is not generalized, and that a pattern may be bound. A reader who takes the clause as the rule predicts neither.
   - Shown by:
     ```
     $ printf 'let id = fn(x) = x\n#(id(1), id("a"))\nlet xs = []\n' | bin/ern shell
     > id : (a) -> a
     > #(1, "a") : #(Int, String)
     > input 3:1:1: the type of xs is not determined by this input; it is List(a)
     ```
     At top level `let xs = []` is generalized (§4.6: "The binding generalizes its free type variables").
   - Fix: "A `let` at the prompt binds as a `let` in a block does (§4.6), not as a top-level `let`, and stands alone in its input."

2. **Appendix F's gloss says a foreign process's messages are checked; §8.4 makes the system processes foreign processes whose messages are not checked.**
   - Place: report/language.md:1099 (Appendix F); report/language.md:737 (§8.4)
   - Quote: "**foreign process** — a process foreign code runs, whose messages are checked where they are delivered. §8.4."
   - Wrong: The gloss restates §8.4 and contradicts it. §8.4: "The system processes are foreign processes", and "what passes between them and a program is not checked: ... a message from a system process". Both sentences stand in one normative file.
   - Shown by: none
   - Fix: "**foreign process** — a process whose implementation lies outside the language, the system processes among them; §8.4 says which of its messages are checked. §8.4."

3. **§3.5 and §4.9 both state the rule for `a.member` in a body with a requirement; §3.5's copy names `compare` and `negate` and leaves out operators.**
   - Place: report/language.md:217 (§3.5); report/language.md:370 (§4.9)
   - Quote: "`a.compare` and `a.negate`, where `a` is a type variable of its signature, name the members of the type `a` stands for and select nothing; such a declaration binds no name that is one of its type variables."
   - Wrong: One rule is stated twice, nearly word for word, and the copies have drifted apart. §4.9 ("an operator `a.+` the type `(a, a) -> a`") and Appendix A ("An `ident`, `.` and a `userop` are a type variable's member, `a.+`") make an operator a member expression too.
   - Shown by:
     ```
     fn twice(x : a) : a needs a.+ =
         a.+(x, x)
     ```
     builds, and `Io.println(Int.toString(twice(4)))` prints `8`.
   - Fix: State the rule in §4.9 alone. §3.5 ends: "In a body with a requirement, `a.member` names a member and selects nothing (§4.9)."

4. **§11.6 restates §11.1's path shape as "one word". §11.1 allows several words joined by `_`, and `ern format` accepts `ordered_set.ern`.**
   - Place: report/toolchain.md:99 (§11.6)
   - Quote: "A file named alone is a module when its name ends in `.ern` and is otherwise one word, as §11.1's path shape says"
   - Wrong: The restatement differs from its owner. §11.1: "is one or more words joined by single `_`".
   - Shown by:
     ```
     $ bin/ern format --check ordered_set.ern; echo $?
     ordered_set.ern
     1
     $ bin/ern format --check Bad.ern
     ern format: Bad.ern: path component `Bad` must be lowercase
     ```
     The first file is taken as a module and reported as out of layout. Only the second is refused.
   - Fix: "A file named alone is a module when its name meets §11.1's path shape; one that does not is refused and left as it is."

5. **E.0 rule 1 makes a shim's admission depend on numbers "in the decisions log", a rationale document, and argues one case with `String.trimEnd`.**
   - Place: report/library.md:120 (Appendix E.0, rule 1)
   - Quote: "is admitted only where the Ernest form's cost grows with something the host's does not, measured, with the numbers in the decisions log."
   - Wrong: A normative rule cites its evidence and says where the evidence is kept. The report states rules, and the log holds rationale and is never normative. The next sentences argue for a single admission instead of stating it: "`String.trimEnd` over `graphemes` costs what the text's length costs, where the host reads only the text's end, and so has a primitive beneath it." E.5 already lists that primitive.
   - Shown by: none
   - Fix: End the sentence at "grows with something the host's does not". Delete the `String.trimEnd` sentence.

6. **E.25 states a policy for later implementations, "only where a program's measurement shows the cost", which no program meets as a rule.**
   - Place: report/library.md:599 (Appendix E.25)
   - Quote: "a representation of another shape replaces the list only where a program's measurement shows the cost, with no change a program can see"
   - Wrong: This is a plan and its justification. By its own words, nothing a program can see depends on it.
   - Shown by: none
   - Fix: Delete the clause and keep the costs.

7. **§7.4 restates §8.2's terminal and standard-input fault rules in full, and which section owns a cause's text changes from one cause to the next.**
   - Place: report/language.md:703 (§7.4); report/language.md:691; report/language.md:719, 721 (§8.2)
   - Quote: "A subscription to the terminal after it was read as lines faults the subscriber with `Fault("the terminal is already read as lines")`"
   - Wrong: Four rules stand in full in both §7.4 and §8.2: a subscription after lines, a read after keys, a line that is not UTF-8, and keys that are not UTF-8. §7.4's first paragraph states two of them a third time: "a standard input that cannot be read or keys that are not UTF-8 among them (§8.2), faults the entry process". §8.2 gives the UTF-8 fault's text itself, but for an unreadable standard input it sends the reader to §7.4. Neither section owns these rules.
   - Shown by: none
   - Fix: State each condition and its text once, in §8.2. §7.4 gives each as a list line holding the text and a pointer, as its first list does.

8. **§6.6 comments on itself ("§6.6 names no type") and restates the consumption rule and §3.9's restriction to argue that the rule is general.**
   - Place: report/language.md:628 (§6.6, *Where such a value may stand*)
   - Quote: "§6.6 names no type: a reply stands wherever the rule shows it consumed exactly once, in a list as in a constructor, and a function of a container takes a reply where §3.9's restriction lets it."
   - Wrong: The sentence argues instead of stating, and each of its clauses restates the rule above it or §3.9. A section that cites itself by number reads as a note to a reviewer.
   - Shown by: none
   - Fix: Delete the sentence.

9. **§8.4 announces its own restatement ("as the sentences before say") and gives three reasons in the same paragraph.**
   - Place: report/language.md:737 (§8.4)
   - Quote: "An answer Ernest code gives to a `Reply` foreign code gave crosses into foreign code, as the sentences before say, and no other answer is checked."
   - Wrong: The first half repeats an earlier sentence: "an answer given to a `Reply` foreign code gave ... cross into foreign code". The same paragraph also gives three reasons: "so that what is sent to it is checked as a message foreign code sends", "since the function was given none of that type", and "since its type is the caller's".
   - Shown by: none
   - Fix: "No other answer Ernest code gives is checked." Delete the three clauses of reason.

10. **Appendix F glosses one concept twice, as *member* and *type member*. The *type member* gloss leaves out a derived `compare` and a prelude type's unprefixed members.**
    - Place: report/language.md:1118, 1187 (Appendix F)
    - Quote: "**type member** — a name declared with its type's prefix, `fn Distance.+`, in the type's nested namespace. §4.2."
    - Wrong: §4.2 counts members "declared ... or derived (§3.5)", and in the module of a prelude type "its `compare` and `negate` are declared unprefixed". The gloss is narrower than §4.2 and differs from *member*'s "declared or derived".
    - Shown by: none
    - Fix: Keep one entry, *member*: "an operator, `compare` or `negate` of a type, declared with the type's prefix or derived, in the type's nested namespace. §4.2, §4.5, §4.9."

11. **Five glosses in Appendix F say less than their sections: *fault*, *not-reply-carrying*, *structural equality*, *tail position*, and *type variable*.**
    - Place: report/language.md:1094, 1125, 1176, 1183, 1189 (Appendix F)
    - Quote: "**fault** — a process death with the reason `Fault(cause)`."
    - Wrong: §6.9 says "A restart is not a death", and §7.3 adds "unless the process restarts". §3.9 puts not-reply-carrying on a type variable of a parameter, a result or a held value, where the gloss says "on a parameter". §3.10 makes `==` exact on a foreign type and on `Process`. §10 adds the right operand of `&&` and `||` and the pipe's call to tail position. §3.9 also generalizes a block `let` that binds a lambda, and does not generalize a top-level `let` that calls a process-only function.
    - Shown by: none
    - Fix: Correct each gloss to its section, for example "**fault** — what ends a process, or restarts it, with the reason `Fault(cause)`", or cut each gloss to a name its section cannot contradict.

12. **E.1 restates §9.4's description of `Io.debug` and drops the line feed that §9.4 states and the runtime writes.**
    - Place: report/library.md:157 (Appendix E.1); report/language.md:842 (§9.4)
    - Quote: "`Io.debug` writes `Io.show`'s text to standard error."
    - Wrong: §9.4 says it "prints Io.show's text and a line feed to standard error, then returns the value".
    - Shown by:
      ```
      let _ = Io.debug(1); let _ = Io.debug("a")   // in main
      $ bin/ern run dbg.erc 2>&1 | od -c
      0000000   1  \n   "   a   "  \n
      ```
    - Fix: Delete E.1's sentence, or write "`Io.debug` is §9.4's."

13. **§3.9's paragraph on inferred restrictions says three times that they are printed, and restates what §3.10 says of the equality constraint.**
    - Place: report/language.md:245 (§3.9); report/language.md:251 (§3.10)
    - Quote: "Each prints with its mark (§11.5)." ... "`a!` being how a printed type marks the restriction (§11.5)" ... "The compiler shows them (§11.5)."
    - Wrong: One pointer is given three times. The paragraph's "Each is part of the type scheme and travels with the function value through bindings, branches, and compiled interfaces. Each is checked at instantiation, not at definition." repeats §3.10's "The constraint is part of the type scheme (§3.9). ... A compiled interface carries it across modules. The check is at the concrete application."
    - Shown by: none
    - Fix: Keep "Each prints with its mark (§11.5)" and the scheme sentence in §3.9, and delete the other two pointers. In §3.10, replace the scheme, interface and check sentences with "(§3.9)", and keep its examples.

14. **The sentence "carries no argument the program has not declared ... which a call supplies without writing it" argues for principle 3 and stands in §4.8, §4.9 and E.1.**
    - Place: report/language.md:364 (§4.8); report/language.md:372 (§4.9); report/library.md:157 (E.1)
    - Quote: "Neither takes an argument the program has not declared: on a known type none, and under a requirement what it names, which a call supplies without writing it (§4.9)."
    - Wrong: The sentence defends the design against "nothing invisible" instead of stating a rule. The rule is §4.9's "A call writes nothing for a requirement", and the copies in §4.8 ("It carries no argument the program has not declared: ...") and E.1 restate it.
    - Shown by: none
    - Fix: Delete the sentence from §4.8 and from E.1.

15. **§4.9 and E.0 shape rule 1 give the same advice, take a member as a parameter or declare a requirement, in nearly the same words.**
    - Place: report/language.md:374 (§4.9); report/library.md:127 (E.0, shape rule 1)
    - Quote: "A member is a parameter where any function of its type may be given, `List.sort(list, compare)`, and a requirement where the type's own member is meant."
    - Wrong: In §4.9 this is advice on how to write a function, not a rule of the language. E.0 shape rule 1 owns it as a rule for the library: "A function takes a member as a parameter where any function of its type may be given, `List.sort(list, compare)`, and declares the requirement where the type's own member is meant (§4.9)."
    - Shown by: none
    - Fix: Delete the sentence from §4.9.

16. **§4.9's last paragraph describes an idiom, the operations record, that has no rule of its own, and its one rule repeats E.0 rule 4.**
    - Place: report/language.md:376 (§4.9)
    - Quote: "Code written once over several representations of a type takes an *operations record*"
    - Wrong: "takes" prescribes a style. "Selecting a field of it is §3.5's selection" and "filled from each representation's namespace (§5.6)" restate their sections. "The standard library declares no such record and no function over one (Appendix E.0 rule 4)" repeats E.0 rule 4: "An operations record and a function over one are the program's (§4.9): no module declares one."
    - Shown by: none
    - Fix: Keep one defining sentence for E.0 to cite, "An *operations record* is a record of functions passed as an argument, filled from a namespace (§5.6)", and keep the example. State the library's refusal in E.0 alone.

17. **§6.6's paragraph on where a reply-carrying value may stand gives reasons for three of its rules.**
    - Place: report/language.md:628 (§6.6)
    - Quote: "A selection would drop the fields it leaves and an update the field it replaces, so a pattern takes such a value apart."
    - Wrong: The same paragraph also says "A top-level binding is read by every function and is no obligation, so one whose type is reply-carrying is a type error", and "A type whose operations are the runtime's takes none, since a foreign function's variables carry the restriction (§4.7)". The last restates line 626: "A type whose operations are the runtime's, and `Address`, is never reply-carrying through its arguments".
    - Shown by: none
    - Fix: Write "A top-level binding of reply-carrying type is a type error." Delete the selection sentence and the sentence on the runtime's types.

18. **§6.6's sentence on guards derives a consequence from §5.9 and the rule, instead of stating what a guard may do with a reply.**
    - Place: report/language.md:630 (§6.6, *Patterns and branches*)
    - Quote: "A guard is pure (§5.9) and its value is a `Bool`, so it can neither answer a reply nor hand one on: a guard that takes one does not return, and a guard that falls through has consumed none."
    - Wrong: The sentence is an argument. "A guard that takes one does not return" reads as a rule, but it follows from §3.9 and the result type, and the sentence never says what it adds to the rule.
    - Shown by:
      ```
      fn check(r : Reply(Int)) : Bool = fault("no")
      ... Get(reply = reply) when check(reply) -> Unit
        | Get(reply = reply) -> answer(reply, 1)
      ```
      builds: the guard consumes the reply, and the clause body does not answer it.
    - Fix: Delete the sentence. The rule of consumption covers a guard as it covers any expression.

19. **§6.6 restates its own capture rule, the definition of reply-carrying, and §5.4's rule on statements.**
    - Place: report/language.md:626, 628 (§6.6), against report/language.md:607
    - Quote: "A lambda that captures a reply-carrying value carries the obligation by its capture, not by its type, and so does the name a `let` binds it to; that name is consumed as the lambda is"
    - Wrong: The bullet at line 607 already says this: "which then carries the obligation by its capture (below). The lambda may be bound by a `let`. It, or the name bound to it, is consumed exactly once". Line 628's "`Optional` and `Either` are sum types like any other: `Some(r)` carries a reply" restates line 626's definition, and "is refused as any statement that is not `Unit` is (§5.4)" restates §5.4.
    - Shown by: none
    - Fix: State the capture rule once, with "`let h = g` is a type error". Delete the two other restating sentences.

20. **§4.9 argues "A type has one member of each name, so ..." and adds advice on a second order, which E.25 repeats.**
    - Place: report/language.md:368 (§4.9); report/library.md:599 (E.25)
    - Quote: "A type has one member of each name, so a requirement has one value at a type; a second order on one type is a second type with its own `compare`"
    - Wrong: This is a derivation followed by advice. E.25 repeats the advice: "An order belongs to an element type: a set in another order is a set of another type, `type Descending = Descending(Int)` with its own `compare`".
    - Shown by: none
    - Fix: Keep "A type has one member of each name." Delete the rest here and the advice in E.25.

21. **§4.9 advises and derives where it should state rules: "takes it as a parameter", and "so `let build = ...` meets the error above".**
    - Place: report/language.md:372, 374 (§4.9)
    - Quote: "a function over an operation of another shape takes it as a parameter"
    - Wrong: The quoted clause is advice. "A lambda a `let` binds whose own variable is not the signature's is generalized before a call ties it to the signature's (§4.6), so `let build = fn(xs) = OrderedSet.fromList(xs)`, unannotated, meets the error above" derives its example from §4.6 and §3.9.
    - Shown by: none
    - Fix: Delete the advice, and give the example as an example of the error, without the "so".

22. **§6.9's paragraph on death gives two reasons and a piece of advice, and says twice that a late `monitor` reports `Unknown`.**
    - Place: report/language.md:644 (§6.9)
    - Quote: "the runtime keeps nothing of a process that has ended, so a `monitor` made after the end cannot say how"
    - Wrong: This reason restates "`Unknown` is what a `monitor` made after the end says", earlier in the paragraph. Also in the paragraph: "watching a process needs no address, since an address is the permission to send (§6.5)", and the advice "a result that must not be lost to a `Down` comes as the callee's own answer to a call (§6.6), which its end does not overtake".
    - Shown by: none
    - Fix: Keep "If `p` is already dead, the message is placed at once, with the reason `Unknown`." State the ordering as a rule: "A call's answer is not overtaken by its callee's `Down`." Delete the reasons.

23. **§6.9's paragraph on a restart a supervisor asks for repeats the previous paragraph's list and one of its own sentences.**
    - Place: report/language.md:648, 646 (§6.9)
    - Quote: "It restarts as a fault restarts it: its address kept, its mailbox emptied, every call waiting for an answer from it ended, and what it has asked the runtime for cancelled."
    - Wrong: The list repeats line 646. "A process that computes without waiting takes the restart asked of it when it next waits" restates the paragraph's own "It runs on until it next waits ... and there runs `f()` again". Line 646 also gives a reason: "since it is another's or the runtime's".
    - Shown by: none
    - Fix: "It restarts as a fault restarts it (above)." Keep "one that never waits is never restarted". Delete the "since" clause.

24. **§3.9 counts "five places" where inference asks for an annotation. The list restates rules owned elsewhere, and the shell's rule for inputs is a sixth place.**
    - Place: report/language.md:239 (§3.9)
    - Quote: "Inference asks for an annotation in five places"
    - Wrong: The sentence restates §4.8, §3.5, §4.6, §5.5 and E.1 as a counted list, which any one of them can make out of date. §11.2's input "is refused, with the annotation that would settle it" is not in the list.
    - Shown by:
      ```
      > input 3:1:1: the type of xs is not determined by this input; it is List(a)
        = help: bind it with an annotation that settles the variable, as in `let xs : List(Int) = []`, ...
      ```
    - Fix: Drop the count and the list, and let each owner state its request. Adjust Appendix F's *Hindley-Milner* ("only where §3.9 says") to match.

25. **§3.9's paragraph on inferred restrictions argues twice: a "So" sentence that comments on process-only, and a "since" clause about where the variable stands.**
    - Place: report/language.md:245 (§3.9)
    - Quote: "So one annotation can give two behaviours"
    - Wrong: The "So" sentence restates the inheritance rule just before it as commentary. "since a function the definition returns or holds is read as the definition is" is a reason.
    - Shown by: none
    - Fix: Delete the "So" sentence and the "since" clause.

26. **§11.2 states the configuration directory's default twice in one paragraph, and §11.3 states it a third time.**
    - Place: report/toolchain.md:77 (§11.2, *Startup and history*); report/toolchain.md:81 (§11.3); report/toolchain.md:29
    - Quote: "`--config-dir` names the configuration directory, `./.ernest` by default."
    - Wrong: The same paragraph already says, as an argument, "though `./.ernest` is the configuration directory the option names by default: a directory the shell merely starts in runs nothing of its own". §11.3 owns the default ("The configuration directory is `./.ernest` unless `--config-dir` names another"), and line 29 already points to it.
    - Shown by: none
    - Fix: Delete the paragraph's last sentence and the clause from "though".

27. **§11.2 gives reasons for four of its rules: fault lines, an abstract type at the prompt, `:load` of a loaded module, and the history of `C-c`.**
    - Place: report/toolchain.md:33, 39, 65, 77 (§11.2)
    - Quote: "so that a fault is one line and none of a program's reaches the terminal as itself"
    - Wrong: Each of these is a reason, not a rule. The other three are "since each input is a module of its own (§4.4)", "since each is in scope from the start" and "so that `C-p` recalls it to mend".
    - Shown by: none
    - Fix: Delete the four clauses.

28. **§11.1 writes the `ern build` usage line twice in one paragraph.**
    - Place: report/toolchain.md:19 (§11.1)
    - Quote: "`ern build [--source-root src-root] [--build-root build-root] [--load-path dir]... [--emit-erl] [--short-errors] src-dir` compiles every `.ern` under `src-dir`"
    - Wrong: The paragraph opens with the same usage line, ending in `file.ern | src-dir`, which "compiles a module to `file.erc`, or every module under `src-dir`, as below".
    - Shown by: none
    - Fix: "Given `src-dir`, `ern build` compiles every `.ern` under it in dependency order, ..."

29. **§11.5 gives a reason for when the checking of a block stops, and comments on §9.2 to excuse an apparent exception.**
    - Place: report/toolchain.md:91, 95 (§11.5)
    - Quote: "an error in any other binding does, since what follows may use the name"
    - Wrong: The "since" clause is a reason. "and §9.2 lists `Map(k=, v)` and `Set(a=)` with the mark, though neither is a foreign type" is commentary. "`=` is written on a foreign type's parameter alone (§4.7)" restates §3.9's "the one mark a program writes (§4.7)".
    - Shown by: none
    - Fix: Delete the "since" clause and everything from "and §9.2 lists".

30. **E.0 argues for its rules in three "since" clauses and restates §0's principle 5.**
    - Place: report/library.md:118, 123, 129 (Appendix E.0)
    - Quote: "The vocabulary is admitted whole, since a reader guesses its names in every module that has the operation"
    - Wrong: Two more clauses give reasons: "`Io.debug` is kept alone, since it stands where an expression stands" and "is `from`, since no type names its argument". "None of them counts programs: a function enters when a rule admits it, whether or not a program has asked." restates §0's "How many programs ask for a feature decides nothing".
    - Shown by: none
    - Fix: Delete the three "since" clauses, and the sentence beginning "None of them counts programs".

31. **E.1's paragraph on `Io.show` gives three reasons: why maps and sets print in order, why an effect variable does not matter, and a comparison with operators.**
    - Place: report/library.md:157 (Appendix E.1)
    - Quote: "so that equal maps and equal sets print alike"
    - Wrong: Each is a reason, not a rule. The other two are "An effect variable in the type is no matter, since a function is written `<function>`" and "more than an operator asks (§4.8)".
    - Shown by: none
    - Fix: Delete the three.

32. **Four sentences give the program advice instead of stating a rule: on input of untrusted size, on line endings, and on bounding a program's run.**
    - Place: report/language.md:719 (§8.2); report/library.md:461 (E.17); report/library.md:255 (E.5); report/library.md:564 (E.23)
    - Quote: "a program that reads input of a size it does not trust reads bytes"
    - Wrong: Each tells a program what to do, and none states a rule. The other three are E.17's comment on `Fs.read`, "readRange reads a file of a size the program does not trust in parts"; E.5's "text whose lines may end either way is read with `String.lines`"; and E.23's "a run is bounded as any process is, by an alarm and `kill` (§6.9)".
    - Shown by: none
    - Fix: Delete each.

33. **E.17 and E.18 each restate shape rule 8, which already puts the milliseconds last.**
    - Place: report/library.md:456 (E.17), 482 (E.18), against report/library.md:137 (E.0, shape rule 8)
    - Quote: "The last argument is the milliseconds to wait."
    - Wrong: E.18 says it again: "The last argument of a function that waits is the milliseconds." E.0 shape rule 8 owns the rule.
    - Shown by: none
    - Fix: Delete both sentences.

34. **E.17 and E.18 put reasons and commentary beside their rules: on the `removeAll` walk, a site without a line, what a write's answer means, and framing.**
    - Place: report/library.md:456 (E.17), 482 (E.18)
    - Quote: "so that a directory another process replaces with a link while the walk runs leads it nowhere else"
    - Wrong: The E.17 clause is a reason. E.18 adds "with no line, since the runtime opened it", "which does not mean that the far end has them" and "framing is bitstrings (§5.11)".
    - Shown by: none
    - Fix: State the guarantee as a rule: "a directory replaced by a link while the walk runs is not followed". Delete the rest.

35. **§4.2 argues that the mapping from files to namespaces is one-to-one, and §11.1 and §11.2 restate the word rule and its examples.**
    - Place: report/language.md:287 (§4.2); report/toolchain.md:23, 29
    - Quote: "A word begins with a letter, so the mapping is one-to-one"
    - Wrong: The "so" clause is an argument. §11.1's *Path shape* repeats the examples `http`, `httpv2` and `ordered_set`, with "`ordered_set.ern` for `OrderedSet`", and §11.2 adds "`OrderedSet` as `ordered_set`".
    - Shown by: none
    - Fix: §4.2 states the mapping and points to §11.1 for what a word is. Drop the "so" clause and the repeated examples.

36. **§4.2 derives two lookup rules with "therefore" and "so", and the second leaves unclear which module it hides.**
    - Place: report/language.md:305, 307 (§4.2)
    - Quote: "A module of the program's own is reached by its namespace alone, so a member of the module's own type hides that module's name of the same path."
    - Wrong: Both are derivations, not statements. "In `main.ern`, `Main.Stack.compare` is therefore its own member" also derives an example. In the second, "that module" can be read as the declaring module or as a program module named like the type.
    - Shown by: none
    - Fix: "Where a module declares `T` with a member `T.f`, `T.f` there is that member, and a program module `T`'s `f` cannot be named." Drop the "therefore".

37. **§5.11 states twice how a segment's size is counted, and twice that a value too wide is a compile-time error or a fault.**
    - Place: report/language.md:513, 515 (§5.11)
    - Quote: "A segment's size counts bits, and octets for a `bytes` segment"
    - Wrong: The table's `size(N)` row already says it. "So is a value that does not fit its width: a numeric literal ... is a compile-time error ..., and any other value that does not fit faults at construction or fails to match" restates line 513's "`<<-1>>` is a compile-time error, and `<<n>>` with `n` −1 faults". Its "So is" has two possible antecedents.
    - Shown by: none
    - Fix: Cut the table row to "segment width". State the width rule once, in line 515's form.

38. **§7.4's first paragraph argues and restates: a reason why operators fault, E.0 shape rule 4 in other words, and §7.3's sentence on causes.**
    - Place: report/language.md:691 (§7.4)
    - Quote: "An operator and a construction the grammar gives fault, since the form has no place for a value."
    - Wrong: The "since" clause is a reason. "A function answers a failure as a value: `Optional` where the failure has no cause the program can act on, `Either` where it has one" restates shape rule 4, "A partial operation returns `Optional`; one with a cause returns `Either`", in different words. "The causes are these, each with its text, and a standard library function's section gives its own" restates §7.3.
    - Shown by: none
    - Fix: Delete the "since" clause, keep the `Optional`/`Either` rule in E.0 alone, and write "The causes are these:".

39. **§8.7 states three times that types are told apart by their declarations across nodes.**
    - Place: report/language.md:776, 780 (§8.7)
    - Quote: "Two nodes with identical declarations under the same qualified name interoperate."
    - Wrong: This follows from line 776's "Identical definitions have the same hash on every node" and "A type's hash includes its qualified name". "Two nodes with different declarations under one name hold distinct types" and "two versions of a type never meet in one message" then say the same thing twice more.
    - Shown by: none
    - Fix: Keep *Content addressing*. In *Identity*, keep the `FooMsg` example and the rules for abstract types and addresses.

#### Clarity

40. **§8.4's first paragraph is 603 words long and covers five topics: which crossings are checked, foreign addresses, result variables, callbacks, and what the checks do not confine.**
    - Place: report/language.md:737 (§8.4)
    - Quote: "The system processes are foreign processes: their message types are declared in Ernest"
    - Wrong: One paragraph holds about twenty-five rules. A reader cannot find one by its topic.
    - Shown by: `sed -n 737p report/language.md | wc -w` gives 603.
    - Fix: Split it into a paragraph for each topic, each led by a bold name, as §8.2 and §8.7 are.

41. **E.5's sentence that lists the primitives nests appositives three deep and mixes private primitives with exported ones.**
    - Place: report/library.md:255 (Appendix E.5)
    - Quote: "with `drop`, the string after a count of graphemes, the last grapheme `trimEnd` takes off, found from the string's end, `toLower`, and `toUpper`"
    - Wrong: The reader cannot tell which commas separate items and which open glosses. `drop` is named like an exported function, but the listing has none, and the sentence calls it private only at its end.
    - Shown by: none
    - Fix: Use two sentences: "The primitives are `size`, `graphemes`, `indexOf`, `lastIndexOf`, `toLower`, `toUpper`, `toFloat`, `toList`, `fromList`, `toUtf8` and `fromUtf8`. Three more are private: ..."

42. **§11.2's `:output` item joins four rules in one comma-spliced sentence.**
    - Place: report/toolchain.md:50 (§11.2, *Commands*)
    - Quote: "to the terminal or file `path`, a path that names neither, a pipe among them, being refused, `:output -` sends it back to the live region"
    - Wrong: An absolute clause, an appositive and a new main clause run together, so the item is hard to parse.
    - Shown by: none
    - Fix: Give the item one sentence per rule: what `:output path` does, what it refuses, `:output -`, and `:output` alone.

43. **§6.9's first paragraph, 430 words, joins the ways a process dies, monitors, `wrap`, spawn sites, and ownership of resources.**
    - Place: report/language.md:644 (§6.9)
    - Quote: "There are no other links. A process the program spawns belongs to no one"
    - Wrong: The rules on ownership of resources, which E.18 and E.23 rely on, sit at the end of a paragraph about monitors.
    - Shown by: none
    - Fix: Split it into paragraphs on death, monitors, site, and ownership.

44. **§11.5's paragraph on where a mismatch is reported is 540 words of placements for different errors, written as running prose.**
    - Place: report/toolchain.md:93 (§11.5)
    - Quote: "A type mismatch is reported at the innermost expression whose type is fixed"
    - Wrong: Each sentence is a separate rule for a separate error, so the paragraph reads as a list written as prose.
    - Shown by: none
    - Fix: Keep the mismatch rule as prose, and give the error-by-error placements as a list.

45. **§7.4's second paragraph opens with "These faults come from no operation of the list above", whose "These" points ahead to sentences not yet read.**
    - Place: report/language.md:703 (§7.4)
    - Quote: "These faults come from no operation of the list above."
    - Wrong: The demonstrative points forward, and "no operation of the list" is ambiguous.
    - Shown by: none
    - Fix: "Beside the list, these faults are raised: ..."

46. **§7.4, the section on what causes a fault, holds the rules for values the runtime corrects, which are no faults. §6.3, §6.6 and §6.9 restate them.**
    - Place: report/language.md:691 (§7.4)
    - Quote: "A count or a duration below 0 is none, but a restart window below 1 is 1 (§6.9); a duration has no upper bound, and a moment already past is now"
    - Wrong: A reader looks for these rules where values are defined, and finds them restated in §6.3 ("a time below 0 is 0"), §6.6 ("a time below 0 being 0") and §6.9 ("a count below 0 is none (§7.4)").
    - Shown by: none
    - Fix: Keep the rule in one place, and have the other sections point to it instead of restating it.

47. **§3.9's sentence about type variables named first in a lambda gives "one" and "it" referents that are hard to resolve.**
    - Place: report/language.md:235 (§3.9)
    - Quote: "One named first in a lambda's annotation or a block `let`'s belongs to that lambda or binding, and only a generalized one may name it"
    - Wrong: The first "one" is a type variable, the second a lambda or binding, and "it" the variable again.
    - Shown by: none
    - Fix: "A type variable named first in a lambda's or a block `let`'s annotation belongs to it, and only a lambda that is a `let`'s whole value, generalized, may name one."

48. **§11.1's *Path shape* sentence on modules of several words also gives a nested directory, which is two namespace segments, not one module name of several words.**
    - Place: report/toolchain.md:23 (§11.1)
    - Quote: "A module of several words is one such name, `ordered_set.ern` for `OrderedSet`, or a nested directory, `http/parser.ern` for `Http.Parser`."
    - Wrong: The sentence reads as advice on naming, and puts `Http.Parser`, a module whose last segment is the one word `Parser`, in a list of modules of several words.
    - Shown by: none
    - Fix: Delete the sentence. §4.2 gives the mapping.

#### Sections read

Counted as the whitespace-separated words (`awk` NF, as `wc -w` counts) of every line from the line after a section's heading to the line before the next heading of any level. Code blocks, tables, lists and examples are included, and the heading line is not. A subsection is counted on its own, and a chapter's lead text before its first subsection is counted as a section of its own. CLAUDE.md's *Writing* was read as the measure.

report/language.md:
- §0 Introduction: 657
- §3.9 Type variables and polymorphism: 1179
- §4.2 Namespaces and visibility: 805
- §4.9 Requirements: 1018
- §5.11 Bitstrings: 730
- §6.6 Request-reply: 1368
- §6.9 Death: 837
- §7.4 Causes of faults: 935
- §8.2 System references: 975
- §8.4 Foreign code: 930
- §8.7 Code shipping: 613
- Appendix A, Grammar: 1067 (mostly the grammar; its closing paragraph of prose was read for register)
- Appendix F, Glossary: 2474

report/toolchain.md:
- §11.1 `ern build`: 819
- §11.2 `ern run`, `ern test`, and `ern shell`: 4060
- §11.5 Diagnostics: 1055
- §11.6 `ern format`: 901

report/library.md:
- Appendix E.0, Rules: 1800
- Appendix E.5, `string.ern`: 733
- Appendix E.17, `fs.ern`: 855
- Appendix E.18, `tcp.ern`: 645
- Appendix E.23, `os.ern`: 927

At the threshold, read as well, since another way of counting puts them over 600:
- Appendix E.1, `io.ern`: 600
- Appendix E.25, `ordered_set.ern`: 599 (606 with its heading)
- Appendix D, A Foreign Library: 598

The rest of the three files was read for context. A finding above cites a section under 600 words (§3.5, §3.10, §4.8, §9.4, §11.3) only as the other place of a restatement.

### U, the guide

#### Defects

1. **The guide says running out of memory is a process fault that ends only that process; on the runtime it crashes the whole node, and no document says otherwise.**
   - Place: ernest_guide.md:1474 (§6.3)
   - Quote: "a failure of the runtime, out of memory among them, is one too (report §7.3). A fault ends the process it happens in, and only that process"
   - Wrong: Report §7.3 and §7.4 never mention memory. So the guide states a fact that no document owns, and the fact is false. The host aborts the whole runtime with a crash dump. No `Down` reaches the monitoring process, and every other process dies too.
   - Shown by:
     ```
     $ cat oom.ern   # a worker, watched with spawnMonitored, grows a list for ever; main receives its Down and prints "main saw: ..."
     $ (ulimit -v 3000000; ern run oom.erc); echo $?
     eheap_alloc: Cannot allocate 34385784 bytes of memory (of type "old_heap").
     Crash dump is being written to: erl_crash.dump...done
     1
     ```
     ("main saw:" is never printed.)
   - Fix: Drop "out of memory among them", or have the report state what memory exhaustion does and have the guide point to that.

2. **§3.3's bullet on polymorphism is false: a block `let` that binds a lambda is generalized, and a generalized top-level `let` needs nothing settled. The bullet also contradicts itself.**
   - Place: ernest_guide.md:666 (§3.3)
   - Quote: "a `let` in a block is not [polymorphic] … After `let xs = []` in a block, the element type of `xs` must be settled … compiles with the variable left open; it is a top-level `let`, and one at the prompt, that must be settled"
   - Wrong: Report §4.6 and §3.9 generalize a block `let` that binds a lambda, and §11.2 does the same at the prompt. Report §4.6 lets a block variable that nothing pins stay free. That contradicts "must be settled", which the bullet's next sentence also contradicts. Only a top-level `let` that is not generalized must be settled; `let xs = []` at top level compiles.
   - Shown by:
     ```
     fn both() : #(Int, String) = { let id = fn(x) = x; #(id(1), id("a")) }
     let xs = []
     fn open() : Int = { let ys = []; List.size(ys) }
     // ern build: no error; ern run prints #(1, "a"), 0 and 0
     ```
   - Fix: Restate the bullet from report §4.6. A block `let` is monomorphic unless it binds a lambda, and its open variable may stay free. Only a top-level `let` that is not generalized, and any `let` at the prompt, must be settled.

3. **§2.9 says a library function carries `with m` "only where" it reaches a system process or asks about processes, but `Clock.monotonic` and `Supervisor.group` do neither and still carry it.**
   - Place: ernest_guide.md:563 (§2.9)
   - Quote: "A function carries `with m` only where it reaches a system process or asks the runtime about its processes, as `Process.live` does"
   - Wrong: E.0 shape rule 5 also gives `with m` to a function that spawns a process (`Supervisor.group`) or reads the time without a message (`Clock.monotonic`).
   - Shown by:
     ```
     stdlib/clock.ern:56   export foreign fn monotonic() : Int with m = "ern_rt:monotonic/0"
     stdlib/supervisor.ern:142   export fn group(...) : (() -> Unit with Msg) with m = { let watcher = spawn(watch); ...
     ```
   - Fix: List all four cases of shape rule 5, or point to the rule instead of paraphrasing it as "only where".

4. **The shell's `:doc` prints prelude types without their restriction marks, unlike `:type`; this breaks report §11.2, which the guide's §2.9 relies on.**
   - Place: report §11.2 (*Documentation*, toolchain.md:71); the guide's promise is at ernest_guide.md:567
   - Quote: "A name's documentation is its declaration's section of §11.4's page … showing the type the shell prints for it"
   - Wrong: For the prelude's names (`send`, `kill`, `spawn`, `answer`, `Address.call`, `Io.debug`), `:doc` shows the type with no `!` and no `+`. `:type` shows both marks, and `:doc` of a library name such as `List.sort` or `Io.println` shows them too. §2.9 tells the reader to use `:doc` and that a printed type carries `=`, `!` and `+`.
   - Shown by:
     ```
     $ printf ':type Io.debug\n:doc Io.debug\n:type kill\n:doc kill\n' | ern shell
     > Io.debug : (a!) -> a! with m+
     >     Io.debug : (a) -> a with m
     > kill : (Address(a)) -> Unit with m+
     >     kill : (Address(a)) -> Unit with m
     ```
   - Fix: Print the prelude page's types (§11.4, `:doc`) as §11.5 prints types, with their marks.

5. **The answer to exercise §7.4 says the constructor is visible in `main.ern`, but §7.2 puts `Stack` in `stack.ern`.**
   - Place: ernest_guide.md:2479 (§13, answer to §7.4)
   - Quote: "so every definition in `main.ern` may name the constructor, a helper or a test included"
   - Wrong: This is stale. The stack of §7.2 is `stack.ern (namespace Stack)`, and its prose says "Inside `stack.ern` … any definition may take a `Stack` apart".
   - Shown by: none
   - Fix: Write `stack.ern` for `main.ern`.

6. **The word counter writes by hand a weaker version of `String.words`, so the guide teaches splitting words two ways and gets tabs and newlines wrong.**
   - Place: ernest_guide.md:694 and :714 (§3.6); also §2.10 at :578
   - Quote: "`words` splits on spaces and drops the empty strings two spaces leave"
   - Wrong: E.5 provides `String.words`, which splits at runs of White_Space and leaves no empty part. The guide never names it. Its hand-written `String.split(…, " ") |> List.filter(…)` keeps a tab or a line feed inside a word.
   - Shown by:
     ```
     > String.words("the  cat\tand\nthe hat")
     ["the", "cat", "and", "the", "hat"] : List(String)
     $ ern shell words.erc
     > Words.count("the cat\nthe hat")
     Map.fromList([#("cat\nthe", 1), #("hat", 1), #("the", 1)]) : Map(String, Int)
     ```
   - Fix: Write `words` as `String.words(String.toLower(text))`, and use `String.words` in §2.10.

7. **The §8.5 transcript starts with `erlc -o build`, which fails in a fresh directory because `build/` does not exist yet.**
   - Place: ernest_guide.md:2238 (§8.5)
   - Quote: "$ erlc -o build store_helper.erl"
   - Wrong: `erlc` does not create its output directory. A reader who follows the transcript as shown gets an error at its first line.
   - Shown by:
     ```
     $ erlc -o build store_helper.erl      # no build/ yet
     .../build/store_helper.bea#: error writing file: no such file or directory
     ```
     (After `mkdir build`, the transcript prints `found 42` as shown.)
   - Fix: Run `ern build --build-root build store.ern` first, or add `$ mkdir -p build`.

8. **§8.5 cites E.0 rule 3 for "a data format, a protocol and a pattern language belong to a library", but rule 2 says that.**
   - Place: ernest_guide.md:2246 (§8.5)
   - Quote: "A data format, a protocol and a pattern language each belong to a library outside the standard library (report Appendix E.0 rule 3)"
   - Wrong: E.0 rule 2 ends "A published specification, a date, a pattern language, a format, a protocol, is a library's and no module's vocabulary". Rule 3's "a format" is a buried policy choice, not a data format.
   - Shown by: none
   - Fix: Cite "report Appendix E.0 rule 2".

9. **§6.3 says report §7.4 lists every fault, but §7.3 also counts the causes that standard library sections give, such as the supervisor's.**
   - Place: ernest_guide.md:1474 (§6.3)
   - Quote: "Report §7.4 lists them all"
   - Wrong: Report §7.3 reads "Its causes are those §7.4 lists and those a standard library function's section gives, the supervisor's among them (Appendix E.22)". One example is `supervisor restart limit reached`, which the guide itself shows in §6.6.
   - Shown by: none
   - Fix: "Report §7.4 lists the language's, and a library function's section gives its own (report §7.3)."

10. **§0 says every error has the `file:line:column` form with the source shown, but a module cycle is reported without either.**
    - Place: ernest_guide.md:67 (§0)
    - Quote: "Every error in a program has this form: the position as `file:line:column`, the message, and the source"
    - Wrong: Report §11.1 reports a cycle "with the modules in it", with no position and no source.
    - Shown by:
      ```
      $ ern build --build-root build .     # aa.ern calls Bb.b, bb.ern calls Aa.a
      ern build: module cycle: Aa, Bb
      ```
    - Fix: Write "An error in a module's source has this form".

#### Clarity

11. **§2.9 glosses `m+` as "an effect variable that is never pure", but `self`'s `m` is never pure and carries no mark.**
    - Place: ernest_guide.md:567 (§2.9)
    - Quote: "and an effect variable that is never pure `m+` (§3.5)"
    - Wrong: Report §11.5 marks a process-only effect variable that stands in no value position. One in a value position, `self : () -> Address(m) with m`, is never pure and unmarked. §3.5 says this correctly, so the two sections disagree.
    - Shown by: `> :type self` gives `self : () -> Address(m) with m`
    - Fix: "and a process-only effect variable that stands nowhere else in the type `m+` (§3.5)".

12. **§5.5 says "the system modules deliver so too", then lists `monitor` and `Process.faults`, which belong to no system module.**
    - Place: ernest_guide.md:1250 (§5.5)
    - Quote: "Wherever something arrives later, a system module takes the function that makes your message from its own: `monitor(child, wrap)` (§5.2), … and `Process.faults(wrap)`"
    - Wrong: `monitor` is the prelude's (report §9.5), and `Process` is not a system module (report §8.2 lists Io, Terminal, Clock, Fs, Tcp and Os).
    - Shown by: none
    - Fix: "Wherever something arrives later, the function that asks for it takes the function that makes your message" (report E.0 shape rule 8).

13. **The guide's "shim" means a private `foreign fn` plus an Ernest wrapper, which differs from the report's meaning, and §8.3 binds a function a third way.**
    - Place: ernest_guide.md:2185 (§8.5); ernest_guide.md §8.3 (`export foreign fn contains`)
    - Quote: "A shim is a private `foreign fn` over an Erlang function and an exported Ernest function that gives it the type Ernest wants."
    - Wrong: Appendix F and E.0 rule 1 define a shim as the primitive itself, "a primitive written as a `foreign fn` over the host or as a request to a system process". §8.3 exports a `foreign fn` directly, which is no shim by the guide's own definition.
    - Shown by: none
    - Fix: Use Appendix F's sense of "shim", and say when a `foreign fn` is exported as it is (§8.3) and when it is wrapped (§8.5).

14. **§7.1's *Entry point* paragraph says each entry point gets a module of its own, then runs `check` from a shared `tools.ern` with `--main`.**
    - Place: ernest_guide.md:1751 (§7.1)
    - Quote: "A project with several programs keeps each entry point in a module of its own, and runs `check` of `tools.ern` so: `$ ern run --main Tools.check build/tools.erc`"
    - Wrong: A module of its own per entry point needs no `--main`. The example implies one module that holds several entry points, so the reader is taught both arrangements and told to use neither.
    - Shown by: none
    - Fix: Choose one arrangement: "a module may export several entry points, and `--main` names the one to run".

15. **§6.6 says a sibling that computes without waiting "is not restarted"; the report says it restarts when it next waits, and the child that faulted waits for it.**
    - Place: ernest_guide.md:1647 (§6.6)
    - Quote: "a sibling that computes without waiting is not restarted"
    - Wrong: Report §6.9 and E.22 say such a sibling "takes no restart until it waits … and the child waits with it". Only one that never waits is never restarted, and the faulted child then never runs `f` again.
    - Shown by: none
    - Fix: "a sibling restarts when it next waits, and the child that faulted waits with it; one that never waits is never restarted".

16. **§3.3 says "`*` on `Int` fixes `value : Int`", but the literal `2` fixes the type, not the `*`.**
    - Place: ernest_guide.md:655 (§3.3)
    - Quote: "`*` on `Int` fixes `value : Int`."
    - Wrong: Under report §4.8, an operator fixes nothing; one operand's type determines both operands. The next example, `value + value`, is refused for exactly that reason, so the sentence teaches the opposite of the rule.
    - Shown by: none
    - Fix: "The literal `2` is an `Int`, so `*` is `Int.*` and `value : Int`."

17. **§9.4 says the Emacs mode "indents it as the style guide does", but it indents to `ern format`'s layout and can format on save.**
    - Place: ernest_guide.md:2385 (§9.4)
    - Quote: "highlights Ernest, indents it as the style guide does"
    - Wrong: docs/emacs_mode.md says "Indentation to the layout `ern format` writes (report §11.6)". It also has `ernest-format-on-save-mode`. docs/style.md defers layout to §11.6.
    - Shown by: none
    - Fix: "indents it as `ern format` lays it out (report §11.6)".

18. **In §2.5, "(§8.3)" sends the reader to the guide's §8.3 for exact equality on foreign values, but that section does not explain it.**
    - Place: ernest_guide.md:427 (§2.5)
    - Quote: "on a value of a foreign type, `Foreign.Term` among them, it is the runtime's exact equality (§8.3)"
    - Wrong: The guide's §8.3 only explains `k=`. Exact equality is report §3.10's.
    - Shown by: none
    - Fix: Cite "(report §3.10)".

19. **§4.4's list of `callForever` causes leaves out `callee was closed`.**
    - Place: ernest_guide.md:836 (§4.4)
    - Quote: "with a cause saying it was killed, returned without answering, was restarted by its supervisor, or had ended already"
    - Wrong: Report §6.6 and §7.4 also give `Fault("callee was closed")`, for a socket or listener the program closes. The guide uses sockets in §8.7.
    - Shown by: none
    - Fix: Add "was closed" to the list.

20. **The claim that an adapted address "costs nothing to keep" is in no document.**
    - Place: ernest_guide.md:1227 (§5.5)
    - Quote: "An adapted address is not a process and costs nothing to keep."
    - Wrong: Report §6.5 says nothing of cost. The address holds a function and its captured values, so keeping it costs memory.
    - Shown by: none
    - Fix: "An adapted address is not a process; it is a value, kept like any other."

21. **§0 states distribution's build status ("planned and not yet built") without naming the document that owns it.**
    - Place: ernest_guide.md:131 (§0); the same text is in the README
    - Quote: "**Distribution by content, planned and not yet built.**"
    - Wrong: Docs/development.md's *What the toolchain accepts* and the plan own what is not yet built, and §8 points to them. This sentence does not, and nothing will update it when MVP 3.0 lifts the refusal.
    - Shown by: none
    - Fix: Drop "and not yet built" here and leave §8's pointer to docs/development.md as the only status line.

### N, the newcomer

#### Defects

1. **Guide §13's answer to exercise §7.4 says code in `main.ern` may name `Stack`'s constructor. It should say `stack.ern`; `main.ern` is refused.**
   - Place: ernest_guide.md:2479
   - Quote: "so every definition in `main.ern` may name the constructor, a helper or a test included"
   - Wrong: The exercise asks about a helper in the same file as `Stack`, and §7.2 puts that file at `stack.ern`. A module `main.ern` that names `Stack.Stack` is refused, so the answer teaches the opposite of the rule it answers for.
   - Shown by:
     ```
     $ ern build stack.ern   # §7.2's module plus a private `fn depth`, which matches Stack(items): builds
     $ ern build main.ern    # its main has `let t = Stack.Stack([]);`
     main.ern:4:13: Stack.Stack is the constructor of an abstract type and is not visible outside its module
     ```
   - Fix: Write `stack.ern` in place of `main.ern` in the answer.

2. **The printed type of `Io.show` leaves out its requirement. A generic caller is refused for not declaring `needs a.show`, which no printed type of `Io.show` mentions.**
   - Place: ernest_guide.md:2032 (§7.3); `:type Io.show`, `:browse Io`, `:doc Io.show`
   - Quote: "`shown` declares `needs a.show`"
   - Wrong: `OrderedSet.fromList` prints `needs a.compare`, and a wrapper of my own around `Io.show` prints `needs a.show`. `Io.show` itself prints as `(a!) -> String`, which reads as "works at any type". The requirement is invisible until the compiler refuses the call. `Io.debug` behaves the same way, and `Foreign.from` (§8.5) has a similar condition that its type does not show.
   - Shown by:
     ```
     > :type OrderedSet.fromList
     OrderedSet.fromList : (List(a!)) -> OrderedSet.Set(a!) needs a.compare
     > :type Io.show
     Io.show : (a!) -> String
     > fn shown(x : a) : String needs a.show = Io.show(x)
     shown : (a!) -> String needs a.show
     $ ern build gen.ern     # fn shownAll(list : List(a)) : Unit with m = List.foreach(list, fn(x) = Io.println(Io.show(x)))
     gen.ern:2:43: Io.show needs a.show, which shownAll does not declare; add needs a.show
     > fn d(x : a) : a with m = Io.debug(x)
     input 1:1:26: Io.debug needs a.show, which d does not declare; add needs a.show
     ```
   - Fix: Print `Io.show : (a!) -> String needs a.show`, and `Io.debug`'s requirement likewise, wherever a type is printed.

3. **`:doc` and `ern doc` print a function's type without its parameter names, but the documentation's prose refers to the parameters by name, so a reader cannot tell which argument is which.**
   - Place: ernest_guide.md:189 (`:doc`), ernest_guide.md:2365 (`ern doc`)
   - Quote: "List.take : (List(a!), Int) -> List(a!) / The first `count` elements"
   - Wrong: The prose names `count`, `ms`, "the pad" and "the text", but the signature shows only types. `String.padStart : (String, Int, String) -> String` leaves the newcomer to guess which `String` is the pad, and only the example settles it. A page that `ern doc` writes for my own module does the same.
   - Shown by:
     ```
     > :doc String.padStart
         String.padStart : (String, Int, String) -> String
     The pad's copies in front until the text has that many graphemes, ...
     > :doc Os.run
         Os.run : (Command, Int) -> Either(Io.Error, Finished) with m+
     ... within `ms` milliseconds of its start.
     $ ern doc pad.ern       # export fn first(list : List(a), count : Int) ..., doc "The first `count` items of `list`."
     Docchk.Pad.first : (List(a!), Int) -> List(a!)
     The first `count` items of `list`.
     ```
   - Fix: In the signature that `:doc` and `ern doc` print, show each parameter's name beside its type.

4. **For the same function, `:doc` prints a different type from `:type` and `:browse`: it drops the `+` of `m+` and the `!` of `a!`, marks the guide teaches as meaningful.**
   - Place: ernest_guide.md:567
   - Quote: "A printed type marks ... one that may not carry a reply `a!` ..., and an effect variable that is never pure `m+`"
   - Wrong: `:doc Os.exit`, `:doc Clock.monotonic`, `:doc Io.show` and `:doc Io.debug` print `with m` and `(a)`, but `:type` prints `with m+` and `(a!)`. `:doc Io.println` keeps its `+`, so a newcomer sees two types for one function and cannot tell which is true.
   - Shown by:
     ```
     > :type Os.exit
     Os.exit : (Int) -> a with m+
     > :doc Os.exit
         Os.exit : (Int) -> a with m
     > :type Clock.monotonic
     Clock.monotonic : () -> Int with m+
     > :doc Clock.monotonic
         Clock.monotonic : () -> Int with m
     > :type Io.show
     Io.show : (a!) -> String
     > :doc Io.show
         Io.show : (a) -> String
     ```
   - Fix: Have `:doc` and `ern doc` print a declaration's type from the same inferred type and printer that `:type` uses.

#### Clarity

5. **User-facing messages name "MVP 3.0", which neither the README nor the guide explains, so a newcomer cannot tell what, or when, it is.**
   - Place: `ern run --help`; the compiler's refusal of `Peer.spawn`; ernest_guide.md:2107 (§8)
   - Quote: "Peer.spawn is not here yet: the module Peer, which acts on peers, arrives in MVP 3.0"
   - Wrong: "MVP 3.0" is a milestone of a plan that the newcomer is never shown. For "when", §8 points to `docs/development.md`, a document for developers. The same words appear in `ern run --help`: "its ernest.conf is read from MVP 3.0".
   - Shown by:
     ```
     $ ern build square.ern   # §8.1's program
     square.ern:9:13: Peer.spawn is not here yet: the module Peer, which acts on peers, arrives in MVP 3.0
     $ ern run --help
       --config-dir  the configuration directory, default ./.ernest; its
                     ernest.conf is read from MVP 3.0
     ```
   - Fix: Name the release in user-facing text, "in a later release" or a version number, and say in guide §8 that the compiler refuses `Peer` until then.

6. **The guide never lists the reserved words, and the parser's message does not say that a word is reserved, so `needs` as a field name fails without a clear reason.**
   - Place: ernest_guide.md:2449 (the guide's only mention of reserved words); ernest_guide.md:1802 (`needs` introduced)
   - Quote: "taskrun.ern:6:46: expected a name instead of `needs`"
   - Wrong: I named a field `needs`, a word the guide uses only after a result type. The message says a name was expected, which `needs` looks like, and not why. `after`, `as`, `or`, `when` and `derives` are refused the same way.
   - Shown by:
     ```
     $ ern build taskrun.ern   # type Task = Task(name : String, work : Work, needs : List(String))
     taskrun.ern:6:46: expected a name instead of `needs`
     > let derives = 1
     input 1:1:5: expected a name instead of `derives`
     ```
   - Fix: Say "`needs` is a reserved word" in the message, and list the reserved words in guide §2 or §12.

7. **The guide refers to `Os.read`, `Os.write` and "a program the runtime started" but never shows how to start one. I simulated my tasks with sleeps instead of running commands.**
   - Place: ernest_guide.md:565, ernest_guide.md:1263
   - Quote: "a socket's far end or a program the runtime started can hang unseen, so `Tcp.write`, `Os.read` and `Os.write` take a time too"
   - Wrong: A task runner would naturally run a command per task. `Os.run` and `Os.start` exist (`:browse Os`), but the guide never names them, so a reader who uses only what the guide taught cannot do it.
   - Shown by:
     ```
     $ grep -c 'Os.run\|Os.start' ernest_guide.md
     0
     ```
   - Fix: Add a short example of `Os.run(Os.Command(...), ms)` to §1.3 or §8, beside `Os.arguments` and `Os.exit`.

8. **Guide §7.1's sentence "A module of two words may also be a directory" suggests that `http/parser.ern` is the same module as `http_parser.ern`. It is a different namespace.**
   - Place: ernest_guide.md:1711
   - Quote: "A module of two words may also be a directory, `http/parser.ern` for `Http.Parser`."
   - Wrong: "Also" reads as an alternative spelling of one module. The two files give two modules, `Http.Parser` and `HttpParser`, and both build side by side.
   - Shown by:
     ```
     $ ern build . && ern run user.erc   # http/parser.ern and http_parser.ern each export hello()
     from Http.Parser
     from HttpParser
     ```
   - Fix: Say "A directory adds a namespace segment: `http/parser.ern` is `Http.Parser`, a different module from `http_parser.ern`'s `HttpParser`."

9. **Exercise §3.7 asks what is inferred for `map2` "when called as" an expression whose `address` is never bound. A function's type does not change with one call.**
   - Place: ernest_guide.md:735
   - Quote: "What does the compiler infer for `map2` when called as `map2(fn(n) = send(address, n), 1, 2)`?"
   - Wrong: I could not try the call as written. Binding `address` at the prompt fails (item 10), and the answer (ernest_guide.md:2471) gives `map2`'s general type and then an instantiation, so the question asks two things at once.
   - Shown by:
     ```
     > :type fn(address) = map2(fn(n) = send(address, n), 1, 2)
     fn(address) = map2(fn(n) = send(address, n), 1, 2) : (Address(Int)) -> #(Unit, Unit) with e+
     ```
   - Fix: Give `address` a type in the question, `address : Address(Int)`, and ask for the call's type and what `a`, `b` and `e` become.

10. **The shell's error for an unsettled address underlines only column 1, and its help suggests a list annotation instead of `with Never`.**
    - Place: ernest_guide.md:760
    - Quote: "help: bind it with an annotation that settles the variable, as in `let xs : List(Int) = []`"
    - Wrong: §4.1 says a process that never receives writes `fn() : Unit with Never`, but the message's example is about lists. The single `^` under `l` points at nothing.
    - Shown by:
      ```
      > let address = spawn(fn() = Unit)
      input 4:1:1: the type of address is not determined by this input; it is Address(a)
      1 | let address = spawn(fn() = Unit)
        | ^
        | = help: bind it with an annotation that settles the variable, as in `let xs : List(Int) = []`, or declare a function with `fn`
      ```
    - Fix: Underline the `spawn` call, and for an address suggest `let a : Address(T) = ...` or `fn() : Unit with Never`.

11. **The error for a forgotten reply says "never consumed", but the guide teaches that a reply is "answered".**
    - Place: ernest_guide.md:83
    - Quote: "the reply-carrying value reply is never consumed"
    - Wrong: §0 and §4.2 say a reply is "answered exactly once on every path" and that handing it on "hands the obligation on". The guide never defines "consumed", which appears in prose once, at ernest_guide.md:784. A newcomer who reads this first error does not know that `answer`, or handing the reply on, is what consumes it.
    - Shown by:
      ```
      $ ern build forgot.ern
      forgot.ern:6:9: the reply-carrying value reply is never consumed
      ```
    - Fix: Add a help line, "answer it with `answer(reply, v)`, or hand it on", or say "never answered or handed on".

12. **The help for a missing requirement ends with "add needs a.compare" without backticks. It reads as if a function named `add` needed something.**
    - Place: ernest_guide.md:2026
    - Quote: "fromList needs a.compare, which unique does not declare; add needs a.compare"
    - Wrong: The clause to add is code, but it is printed as prose, so "add needs a.compare" parses as a sentence about `add`. My own program has a function named `add`.
    - Shown by:
      ```
      generic.ern:2:23: fromList needs a.compare, which unique does not declare; add needs a.compare
      ```
    - Fix: Write "add `needs a.compare` after unique's result type", and name `OrderedSet.fromList` in full.

13. **Guide §7.3 prints a whole 145-line standard library module and introduces three new mechanisms in one section, which buries the one a newcomer needs.**
    - Place: ernest_guide.md:1802-1949
    - Quote: "Here is the module whole, `stdlib/ordered_set.ern`, with its doc blocks left out"
    - Wrong: Requirements, the fill `Operations(..Set)` (a second meaning of `..`), and records of closures arrive together, after five pages of set code. I needed only `needs a.compare`, and it took two readings to find it.
    - Shown by: none
    - Fix: Show `fromList`, `firstOfEach` and `contains` only, and point to `:doc OrderedSet` for the rest.

14. **`ern run` on a `.ern` file says only that the name does not end in `.erc`, not that the module must be built first.**
    - Place: ernest_guide.md:147
    - Quote: "ern run: greet.ern does not end in .erc"
    - Wrong: A newcomer who runs the source file learns what is wrong but not what to do.
    - Shown by:
      ```
      $ ern run greet.ern Ada
      ern run: greet.ern does not end in .erc
      ```
    - Fix: Add "build it first: ern build greet.ern".

15. **The guide shows shell errors at `input 2:1:1` without saying that the first number counts the inputs.**
    - Place: ernest_guide.md:459
    - Quote: "input 2:1:1: a `let` pattern must be irrefutable"
    - Wrong: §0 explains `file:line:column`, but at the prompt the "file" is `input 2`, and a newcomer reads three numbers with no key.
    - Shown by:
      ```
      > fn f(w : Word) : Int = String.size(w)
      input 12:1:36: the argument does not fit String.size: expected String, found Word
      ```
    - Fix: Add one sentence to §1.2: "at the prompt, an error's place is `input n:line:column`, n counting the inputs".

16. **Guide §3.3's first bullet ends with an inverted clause that I could not parse on a first reading.**
    - Place: ernest_guide.md:666
    - Quote: "compiles with the variable left open; it is a top-level `let`, and one at the prompt, that must be settled"
    - Wrong: The bullet packs four rules into three sentences, and the last clause puts its subject after "it is".
    - Shown by: none
    - Fix: Split it: "A `let` in a block may leave its variable open. A top-level `let`, and one at the prompt, must settle it."

17. **Guide §6.5 justifies a declaration's place by pointing a newcomer to the project's style guide, a document for the project's workers.**
    - Place: ernest_guide.md:1600
    - Quote: "Its place, after the types and before `main`, is [`docs/style.md`](docs/style.md)'s top-down layout."
    - Wrong: The sentence tells the reader nothing about the program; it cites a rule from another document, and `ern format --help` refers to "the style guide" again.
    - Shown by: none
    - Fix: Drop the sentence, or state the layout in one line of §9.1 beside `ern format`.

18. **The README's opening paragraph presents hash-identified code as one of Ernest's parts. Three lines later it says that feature is "planned and not yet built".**
    - Place: README.md:11
    - Quote: "and Unison's code known by the hash of its definition, which is what lets a message be checked across nodes"
    - Wrong: The present tense reads as a feature I can use. The bullet at README.md:16 takes it back, so the pitch misleads before it corrects.
    - Shown by: none
    - Fix: Say "and, planned, Unison's code known by the hash of its definition".

19. **The README explains its first point by contrast with Gleam, which a reader who does not know Gleam cannot use.**
    - Place: README.md:13
    - Quote: "Gleam types the channel a message travels on; Ernest types the process."
    - Wrong: The contrast is the bullet's last sentence and carries its point, but it assumes Gleam's model. The guide repeats it at ernest_guide.md:128.
    - Shown by: none
    - Fix: Say it in Ernest's own terms: "an address's type is the type of the mailbox it reaches".

#### Where the language made the work harder

20. **`needs`, `derives`, `after`, `as`, `or` and `when` are reserved everywhere, so common English words cannot name a field, a parameter or a binding.**
    - Place: ernest_guide.md:1802 (`needs`), ernest_guide.md:2034 (`derives`)
    - Quote: "A function that needs the order says so after its result type, `needs a.compare`"
    - Wrong: `needs` means something only after a result type, and `derives` only after a type declaration, yet both are refused as a record field. In a task runner, `needs` is the field's natural name; I renamed it `requires`, and my error texts still say "needs".
    - Shown by:
      ```
      $ ern build taskrun.ern   # type Task = Task(name : String, work : Work, needs : List(String))
      taskrun.ern:6:46: expected a name instead of `needs`
      ```
    - Fix: Reserve `needs` and `derives` only where they can begin a clause, or document them as reserved where they are introduced.

21. **Without formatting or interpolation, a one-line summary of four counts takes four `Int.toString` calls and seven `<>`, which `ern format` then lays out as eight lines.**
    - Place: ernest_guide.md:270
    - Quote: "There is no interpolation."
    - Wrong: My report line `6 done, 2 failed, 1 skipped, 0 never ran` is longer as code than any other expression in the program. The guide says interpolation is absent, but it gives no idiom for text built from numbers, such as `String.join` over a list.
    - Shown by:
      ```
      Io.println(Int.toString(Set.size(state.done))
                     <> " done, "
                     <> Int.toString(Set.size(state.failed))
                     <> " failed, "
                     <> Int.toString(List.size(skipped))
                     <> " skipped, "
                     <> Int.toString(List.size(stuck))
                     <> " never ran");
      ```
    - Fix: Show in guide §2.1 the idiom for a line of text built from several values, such as `String.join([...], ", ")`.

#### The program

`taskrun` is a dependency-ordered task runner. It reads tasks from standard input, one per line, as `name work requires...`, where `work` is milliseconds to sleep or `fail` for a task that faults, and `#` begins a comment. It runs each task in its own monitored process once every task it requires has finished, at most `jobs` at a time. An alarm kills a task that runs past `limit` milliseconds, and a stale alarm is dropped. Each start, end, fault and kill is printed with the elapsed time. At the end it reports the tasks skipped because something they require failed, and those that never ran because they wait on a cycle. Bad input or arguments exit with status 2, and any failure, skip or cycle with status 1. The command line is `taskrun [jobs [limit-ms]]`, with defaults 4 and 2000.

```ernest
/// Runs the tasks standard input describes, each once the tasks it needs
/// have finished, a few at a time, and kills one that runs too long.

type Work = Sleep(Int) | Fail

type Task = Task(name : String, work : Work, requires : List(String))

type Settings = Settings(jobs : Int, limit : Int)

type RunnerMsg = Ended(name : String, down : Down) | Overdue(String)

type State =
    State(waiting : Map(String, Task),
          running : Map(String, Address(Never)),
          done : Set(String),
          failed : Set(String),
          origin : Int)

export fn main() : Unit with RunnerMsg =
    match settings(Os.arguments) {
        Left(problem) -> quit(problem)
      | Right(chosen) -> match parseTasks(readLines([])) {
            Left(problem) -> quit(problem)
          | Right(tasks) -> {
                let state =
                    State(waiting = tasks,
                          running = Map.empty,
                          done = Set.empty,
                          failed = Set.empty,
                          origin = Clock.monotonic());
                report(schedule(state, chosen))
            }
        }
    }

fn quit(problem : String) : a with m = {
    Io.printlnError(problem);
    Os.exit(2)
}

fn settings(arguments : List(String)) : Either(String, Settings) =
    match arguments {
        [] -> Right(Settings(jobs = 4, limit = 2000))
      | [jobsText] -> {
            let jobs <- positive(jobsText, "jobs");
            Right(Settings(jobs = jobs, limit = 2000))
        }
      | [jobsText, limitText] -> {
            let jobs <- positive(jobsText, "jobs");
            let limit <- positive(limitText, "limit");
            Right(Settings(jobs = jobs, limit = limit))
        }
      | _ -> Left("usage: taskrun [jobs [limit-ms]] < tasks")
    }

fn positive(text : String, what : String) : Either(String, Int) =
    match String.toInt(text) {
        Some(number) when number > 0 -> Right(number)
      | _ -> Left(what <> " must be a positive number, not " <> text)
    }

fn readLines(acc : List(String)) : List(String) with m =
    match Io.readLine() {
        Some(line) -> readLines(line :: acc)
      | None -> List.reverse(acc)
    }

fn parseTasks(lines : List(String)) : Either(String, Map(String, Task)) = {
    let parsed <- List.tryMap(List.indexed(lines), parseLine);
    let tasks <- List.tryFold(List.filterMap(parsed, fn(task) = task), Map.empty, addTask);
    let _ <- List.tryMap(Map.values(tasks), fn(task) = checkRequires(tasks, task));
    Right(tasks)
}

fn parseLine(#(index, line) : #(Int, String)) : Either(String, Optional(Task)) =
    match String.words(line) {
        [] -> Right(None)
      | first :: _ when String.startsWith(first, "#") -> Right(None)
      | [name] -> Left(at(index) <> name <> " has no duration")
      | name :: workText :: requires -> {
            let work <- parseWork(index, workText);
            Right(Some(Task(name = name, work = work, requires = requires)))
        }
    }

fn parseWork(index : Int, text : String) : Either(String, Work) =
    if text == "fail" then
        Right(Fail)
    else match String.toInt(text) {
        Some(ms) when ms >= 0 -> Right(Sleep(ms))
      | _ -> Left(at(index) <> text <> " is neither a duration in milliseconds nor fail")
    }

fn at(index : Int) : String =
    "line " <> Int.toString(index + 1) <> ": "

fn addTask(tasks : Map(String, Task), task : Task) : Either(String, Map(String, Task)) =
    if Map.contains(tasks, task.name) then
        Left("the task " <> task.name <> " is declared twice")
    else
        Right(Map.put(tasks, task.name, task))

fn checkRequires(tasks : Map(String, Task), task : Task) : Either(String, Unit) =
    match List.find(task.requires, fn(need) = !Map.contains(tasks, need)) {
        Some(missing) -> Left(task.name <> " needs " <> missing <> ", which no line declares")
      | None -> Right(Unit)
    }

//
// Running
//

fn schedule(state : State, chosen : Settings) : State with RunnerMsg = {
    let started = startReady(state, chosen);
    if Map.isEmpty(started.running) then
        started
    else receive {
        Ended(name = name, down = Down(reason = reason)) ->
            schedule(ended(started, name, reason), chosen)
      | Overdue(name) -> {
            overdue(started, name);
            schedule(started, chosen)
        }
    }
}

fn startReady(state : State, chosen : Settings) : State with RunnerMsg = {
    let free = chosen.jobs - Map.size(state.running);
    let ready =
        Map.values(state.waiting)
            |> List.filter(fn(task) =
                               List.all(task.requires, fn(need) = Set.contains(state.done, need)))
            |> List.sort(fn(left, right) = String.compare(left.name, right.name))
            |> List.take(free);
    List.foldLeft(ready, state, fn(acc, task) = start(acc, task, chosen.limit))
}

fn start(state : State, task : Task, limit : Int) : State with RunnerMsg = {
    let name = task.name;
    say(state, "start " <> name);
    let worker = spawnMonitored(fn() = perform(task.work),
                                fn(down) = Ended(name = name, down = down));
    Clock.alarm(limit, fn(_) = Overdue(name));
    State(..state,
          waiting = Map.remove(state.waiting, name),
          running = Map.put(state.running, name, worker))
}

fn perform(work : Work) : Unit with Never =
    match work {
        Sleep(ms) -> receive {
            after ms -> Unit
        }
      | Fail -> fault("the task failed")
    }

fn ended(state : State, name : String, reason : Reason) : State with m = {
    let running = Map.remove(state.running, name);
    match reason {
        Returned -> {
            say(state, "done  " <> name);
            State(..state, running = running, done = Set.put(state.done, name))
        }
      | Fault(cause) -> {
            say(state, "FAIL  " <> name <> ": " <> cause);
            State(..state, running = running, failed = Set.put(state.failed, name))
        }
      | Killed -> {
            say(state, "FAIL  " <> name <> ": killed");
            State(..state, running = running, failed = Set.put(state.failed, name))
        }
      | ProgramEnd or Unknown -> {
            say(state, "FAIL  " <> name <> ": ended unexpectedly");
            State(..state, running = running, failed = Set.put(state.failed, name))
        }
    }
}

fn overdue(state : State, name : String) : Unit with m =
    match Map.get(state.running, name) {
        Some(worker) -> {
            say(state, "kill  " <> name <> ": over its time limit");
            kill(worker)
        }
      | None -> Unit
    }

fn say(state : State, text : String) : Unit with m = {
    let elapsed = Clock.monotonic() - state.origin;
    let rounded = (elapsed + 25) / 50 * 50;
    Io.println(String.padStart(Int.toString(rounded), 6, " ") <> " ms  " <> text)
}

//
// Reporting
//

fn report(state : State) : Unit with m = {
    let lost = doomed(state.waiting, state.failed);
    let names = List.sort(Map.keys(state.waiting), String.compare);
    let #(skipped, stuck) = List.partition(names, fn(name) = Set.contains(lost, name));
    List.foreach(skipped, fn(name) = Io.println("skipped " <> name <> ": a task it needs failed"));
    List.foreach(stuck, fn(name) = Io.println("never ran " <> name <> ": it waits on a cycle"));
    Io.println(Int.toString(Set.size(state.done))
                   <> " done, "
                   <> Int.toString(Set.size(state.failed))
                   <> " failed, "
                   <> Int.toString(List.size(skipped))
                   <> " skipped, "
                   <> Int.toString(List.size(stuck))
                   <> " never ran");
    if Map.isEmpty(state.waiting) && Set.isEmpty(state.failed) then Unit else Os.exit(1)
}

// The failed tasks, and every waiting task that needs one of them, directly
// or through other waiting tasks.
fn doomed(waiting : Map(String, Task), lost : Set(String)) : Set(String) = {
    let grown =
        Map.foldLeft(waiting,
                     lost,
                     fn(acc, name, task) =
                         if List.any(task.requires, fn(need) = Set.contains(lost, need)) then
                             Set.put(acc, name)
                         else
                             acc);
    if Set.size(grown) == Set.size(lost) then lost else doomed(waiting, grown)
}
```

The input `build.tasks`:

```
# name  work  requires...
lex       200
parse     300  lex
check     250  parse
docs      150  parse
codegen   400  check
test      fail codegen
package   100  codegen docs
publish   100  test package
lint      5000 lex
```

Commands, run in /tmp/claude-1001/-home-jocke-projects-ernest/b7738eca-2b4e-47ea-aab4-66895105442d/scratchpad/review/N/prog with `ern` being /home/jocke/projects/ernest/bin/ern:

```
$ ern build taskrun.ern          # first version, with the field `needs`: refused (item 20)
taskrun.ern:6:46: expected a name instead of `needs`
$ ern build taskrun.ern          # after renaming the field to `requires`: built, no other error
$ ern format taskrun.ern         # on a copy; only line breaks changed, adopted above
$ ern format --check taskrun.ern # passes
$ ern run taskrun.erc 2 1000 < build.tasks
     0 ms  start lex
   200 ms  done  lex
   200 ms  start lint
   200 ms  start parse
   500 ms  done  parse
   500 ms  start check
   750 ms  done  check
   750 ms  start codegen
  1150 ms  done  codegen
  1150 ms  start docs
  1200 ms  kill  lint: over its time limit
  1200 ms  FAIL  lint: killed
  1200 ms  start test
2026-10-04T07:48:30.322Z Taskrun.start:141 faulted: the task failed
  1200 ms  FAIL  test: the task failed
  1300 ms  done  docs
  1300 ms  start package
  1400 ms  done  package
skipped publish: a task it needs failed
6 done, 2 failed, 1 skipped, 0 never ran
(exit status 1)
$ printf 'a 100\nb 100 a c\nc 100 b\nd 50 c\n' | ern run taskrun.erc
     0 ms  start a
   100 ms  done  a
never ran b: it waits on a cycle
never ran c: it waits on a cycle
never ran d: it waits on a cycle
1 done, 0 failed, 0 skipped, 3 never ran
(exit status 1)
$ printf 'a 100\nb oops a\n' | ern run taskrun.erc
line 2: oops is neither a duration in milliseconds nor fail
(exit status 2)
$ printf 'a 100\nb 10 zz\n' | ern run taskrun.erc
b needs zz, which no line declares
(exit status 2)
$ printf 'a 100\na 10\n' | ern run taskrun.erc
the task a is declared twice
(exit status 2)
$ ern run taskrun.erc 0 < /dev/null
jobs must be a positive number, not 0
(exit status 2)
$ ern run taskrun.erc 1 2 3 < /dev/null
usage: taskrun [jobs [limit-ms]] < tasks
(exit status 2)
$ ern run taskrun.erc < /dev/null
0 done, 0 failed, 0 skipped, 0 never ran
(exit status 0)
```

It built, after the one rename, and ran as intended on every input above. The timestamped line comes from `ern run`, which reports every fault on standard error (guide §6.3).

### D, the documents

#### Defects

1. **The loads' `rows` sample, as docs/memory.md describes it, counts four of the runtime's six tables, so a row leaked into `ern_callees` or `ern_deliveries` passes the exact count.**
   - Place: docs/memory.md:27; test/ern_load.erl:112
   - Quote: "`rows`, the rows of the runtime's tables `ern_processes`, `ern_calls`, `ern_faults` and `ern_held`"
   - Wrong: `ern_rt` has made six named tables since 2026-09-30 (commit a368713). Rows that grow in `ern_callees` or `ern_deliveries` are caught only if they push memory past the 128 KB noise. The exact "may not grow at all" rule (memory.md:32) never sees them.
   - Shown by:
     ```
     $ grep -n 'ets:new' erl/runtime/src/ern_rt.erl
     1547:    ets:new(?PROCESSES, ...
     1548:    ets:new(?CALLS, ...
     1549:    ets:new(?CALLEES, ...
     1550:    ets:new(?FAULTS, ...
     1551:    ets:new(?HELD, ...
     1552:    ets:new(?DELIVERIES, ...
     $ grep -n 'rows(ern' test/ern_load.erl
     112:      rows => rows(ern_processes) + rows(ern_calls) + rows(ern_faults) + rows(ern_held),
     ```
   - Fix: add `ern_callees` and `ern_deliveries` to the sum in `sample/1`, and name all six tables in memory.md.

2. **docs/architecture.md says `ern_rt` keeps four tables, with deliveries as `{{delivering, Pid}, Target, Starter}` rows of `ern_held`. It keeps six tables, and deliveries have one of their own.**
   - Place: docs/architecture.md:80-85
   - Quote: "It keeps four tables:" and "`{{delivering, Pid}, Target, Starter}` for each delivery on its way"
   - Wrong: ern_rt.erl:1547-1552 makes `ern_processes`, `ern_calls`, `ern_callees`, `ern_faults`, `ern_held` and `ern_deliveries`. A delivery's row is `{{Recipient, Starter, Pid}}` in `ern_deliveries` (ern_rt.erl:627), and each call is kept by callee too, in `ern_callees` (ern_rt.erl:326). Nothing writes a `{delivering, _}` row any more. The document is the owner of "how the code is arranged", and has been stale here since 2026-09-30.
   - Shown by:
     ```
     $ grep -n 'delivering' erl/runtime/src/ern_rt.erl
     445:            delivering ->
     765:%% What the look finds: `delivering`, ...
     772:            delivering;
     ```
     These are the result of `look/0`, and no row has that name.
   - Fix: list the six tables with their rows as the comments at ern_rt.erl:54-75 give them.

3. **Three doc blocks added since 0.2.0 state a version they did not ship in. `OrderedSet` and `OrderedMap` say "since 0.2.0", `Os.user` inherits "since 0.1.0", and no test can catch it.**
   - Place: stdlib/ordered_set.ern:40, stdlib/ordered_map.ern:26, stdlib/os.ern:152; docs/release_review.md:14
   - Quote: "/// since 0.2.0"
   - Wrong: both modules were added on 2026-10-03 (commit 15fe480), after `v0.2.0`, which holds neither. `Os.user` is not in `v0.2.0` either, and has no `since` line of its own. `doc_since_test_` refuses any version above `VERSION`, so the true `0.3.0` cannot be written before the release. Nothing flags an export that is missing from the last tag, so release_review.md's step 5 depends on someone finding each one by hand. Until then, `:doc`, `Shift-Tab` and the pages tell a user something false.
   - Shown by:
     ```
     $ printf ':doc OrderedSet\n' | bin/ern shell | sed -n 2,4p
     > Ernest module OrderedSet

     *Since 0.2.0.*
     $ git show v0.2.0:stdlib/ordered_set.ern
     fatal: path 'stdlib/ordered_set.ern' exists on disk, but not in 'v0.2.0'
     $ git show v0.2.0:stdlib/os.ern | grep -c 'user'
     0
     ```
   - Fix: let the test accept the release after `VERSION`, and require every export missing from the last tag to carry a `since` newer than that tag.

4. **docs/shell_design.md's foreign interface lists `output`, which item 5 rewrote in Ernest. It also leaves out `declaredType`, a foreign function the shell does declare.**
   - Place: docs/shell_design.md:54 (the groups at :52-56)
   - Quote: "**The commands** that reach past the shell: `bindings`, `browse`, `doc` and `output`."
   - Wrong: since d90a5b3, `output` is `fn output(...)` at shell/shell.ern:331, written in Ernest over `Fs.append`, and the shell has no `foreign fn output`. `foreign fn declaredType` (shell/shell.ern:1328, `ern_shell:declared_type/2`) belongs to none of the five groups. The same commit rewrote this note's *Output* section and left this line as it was.
   - Shown by:
     ```
     $ grep -c 'foreign fn output' shell/shell.ern
     0
     $ grep -n 'foreign fn declaredType' shell/shell.ern
     1328:foreign fn declaredType(session : Session, input : String) : Optional(String) with m =
     ```
   - Fix: take `output` out of the commands' group, and put `declaredType` with the functions that read a result.

5. **docs/shell_design.md names three shell functions that no longer exist: `pending`, `offered` and `quietly`. They are now `reportPending`, `namesFor` and `executeQuietly`.**
   - Place: docs/shell_design.md:42, :145, :167
   - Quote: "`pending` says every waiting one before each prompt"; "With nothing typed, `offered` leaves out the prelude's constructors"; "any other goes to `quietly`"
   - Wrong: a reader who looks for these three names finds none of them. shell/README.md:54 already writes `reportPending`.
   - Shown by:
     ```
     $ grep -nE 'fn (pending|offered|quietly)\b' shell/shell.ern shell/shell/*.ern
     $ grep -nE 'fn (reportPending|namesFor|executeQuietly)\b' shell/shell.ern shell/shell/*.ern
     shell/shell/complete.ern:69:fn namesFor(typedWord : String) : List(Name) with m = {
     shell/shell.ern:387:fn executeQuietly(state : State,
     shell/shell.ern:1257:fn reportPending(state : State, screen : Address(ScreenMsg)) : State with ShellMsg =
     ```
   - Fix: write the three names the code has.

6. **docs/operations.md quotes `mixed.ern`'s refusal as "does not fit the callee". `ern build` actually names the function, "does not fit OrderedSet.union".**
   - Place: docs/operations.md:174; docs/scratch/operations.md:309
   - Quote: "`the argument does not fit the callee: expected OrderedSet.Set(Int), found OrderedSet.Set(Descending)`"
   - Wrong: the message has named the callee since the change that §11.5 records ("names the field as written where a message would say `the callee`").
   - Shown by: the document's `mixed.ern`, built as is:
     ```
     $ ern build --short-errors mixed.ern
     mixed.ern:9:66: the argument does not fit OrderedSet.union: expected OrderedSet.Set(Int), found OrderedSet.Set(Descending)
     ```
   - Fix: quote the message exactly as `ern build` prints it.

7. **docs/operations.md says its code is excerpted from the files, but its `ordered_set.ern` block predates the renaming: it writes `x` and `y` where the file has `element`, `head`, `first` and `second`.**
   - Place: docs/operations.md:3 and :42-101; the same block in docs/scratch/operations.md
   - Quote: "The code here is excerpted from the files." and "export fn contains(Set(list) : Set(a), x : a) : Bool needs a.compare ="
   - Wrong: 19 lines of the block appear nowhere in stdlib/ordered_set.ern: those of `firstOfEach`, `contains`, `has`, `put`, `inserted` and `merged`. The `ordered_map.ern` block and the three programs' blocks do match their files. No test holds these excerpts to the files, as `ordered_set_shown_whole_test` does for the guide's copy.
   - Shown by:
     ```
     $ awk '/^```ernest$/{f=1;next} /^```/{f=0} f' docs/operations.md > blocks
     $ cat stdlib/ordered_set.ern stdlib/ordered_map.ern docs/operations/*.ern > files
     $ grep -nvxFf files blocks | grep -v ':$' | wc -l
     19
     ```
   - Fix: copy the block from the file again, and add a test like `ordered_set_shown_whole_test` for every block the note says is excerpted.

8. **docs/operations.md's example of a fill error, `Ops(..Set) lacks isSubset: Set has no isSubset`, cannot happen: `Set` has `isSubset`, and that fill compiles.**
   - Place: docs/operations.md:26; docs/scratch/operations.md:132
   - Quote: "`Ops(..Set) lacks isSubset: Set has no isSubset`"
   - Wrong: stdlib/set.ern:196 exports `isSubset`. The message's form is right, but its example names a field that `Set` has.
   - Shown by:
     ```
     $ cat fill2.ern
     type Ops(s, a) = Ops(fromList : (List(a)) -> s, isSubset : (s, s) -> Bool)
     let hashed : Ops(Set(Int), Int) = Ops(..Set)
     export fn main() : Unit with Never = Unit
     $ ern build fill2.ern; echo $?
     0
     $ ern build --short-errors fill3.ern      # the same, with min : (s) -> Optional(a)
     fill3.ern:3:41: Ops(..Set) lacks min: Set has no min
     ```
   - Fix: use a field that `Set` lacks, such as `min` or `max`.

9. **docs/operations.md's console for `unique` without its requirement shows one error. `ern build` prints a second, spurious one, `Io.show ... not known whole here: a!`, a cascade in the checker.**
   - Place: docs/operations.md:154-157
   - Quote: "usage.ern:17:23: fromList needs a.compare, which unique does not declare; add needs a.compare"
   - Wrong: once `unique`'s body is refused, the call `unique(["b", "a"])` is left at the type `List(a!)`, not at `List(String)`, the instance of its annotation. So `Io.show` of it is refused as well. With the call's type annotated, only the first error comes. The console hides this second error, and the second error is wrong about the program.
   - Shown by:
     ```
     $ cat casc.ern
     fn unique(list : List(a)) : List(a) =
         OrderedSet.toList(OrderedSet.fromList(list))

     export fn main() : Unit with Never =
         Io.println(Io.show(unique(["b", "a"])))
     $ ern build --short-errors casc.ern
     casc.ern:2:23: fromList needs a.compare, which unique does not declare; add needs a.compare
     casc.ern:5:16: Io.show writes a value by its type, which is not known whole here: a!
     $ ern build --short-errors casc2.ern      # main binds `let names : List(String) = unique(...)`
     casc2.ern:2:23: fromList needs a.compare, which unique does not declare; add needs a.compare
     ```
   - Fix: give a definition whose requirement is refused its annotated scheme at its uses, so that no second error follows. The console is then right as written.

10. **docs/operations.md prints `fromList`'s type without the restriction marks. `ern doc`, `:doc` and `:type` print `(List(a!)) -> OrderedSet.Set(a!) needs a.compare`.**
    - Place: docs/operations.md:298
    - Quote: "`ern doc` writes a requirement as declared: `OrderedSet.fromList : (List(a)) -> OrderedSet.Set(a) needs a.compare`"
    - Wrong: the type printer marks `a` as not reply-carrying (§3.9, §11.5), so the type the toolchain shows is not the one quoted.
    - Shown by:
      ```
      $ printf ':type OrderedSet.fromList\n' | bin/ern shell | tail -2
      > OrderedSet.fromList : (List(a!)) -> OrderedSet.Set(a!) needs a.compare
      ```
    - Fix: quote the type exactly as it is printed.

11. **docs/operations.md says MVP 3.0 decides where versions of a type's `compare` meet. The plan puts that question in MVP 3.1, with the normalized definition.**
    - Place: docs/operations.md:316; docs/implementation_plan.md:269-272
    - Quote: "A set sent to a node whose `T.compare` differs is read under that node's; MVP 3.0 decides where versions meet."
    - Wrong: the plan's MVP 3.1 asks "whether a type's identity holds the hash of its `compare`", and cites this very note's *Typing*. MVP 3.0 ships code only between nodes of one build.
    - Shown by: none
    - Fix: name MVP 3.1's normalized definition.

12. **docs/operations.md says E.0 lacks the rule that an operations record comes after the subjects. E.0 shape rule 1 states it, and names the argument `operations`.**
    - Place: docs/operations.md:324; report/library.md:127
    - Quote: "an operations record comes directly after the subjects, ... `common(list, other, ops)`, decided on 2026-10-02 (...) and not yet in E.0."
    - Wrong: report/library.md:127 reads "An operations record (§4.9) comes directly after the subjects, before an accumulator and the callbacks: `common(list, other, operations)`."
    - Shown by: none
    - Fix: say that E.0 shape rule 1 states it, and quote that rule's example.

13. **docs/node_protocol.md says the report places a process with `Where = Local | Peer(String)`. `Where` left the language on 2026-10-01, and the report has no such type.**
    - Place: docs/node_protocol.md:15
    - Quote: "The report places a process with `Where = Local | Peer(String)`, writes text as `String`, and has a `monitor` that answers nothing."
    - Wrong: report §8.3 places work with `Peer.spawn(name, f)` and `Peer.spawnMonitored(name, f, wrap)`, and the plan (:202) records that `Where` left the prelude.
    - Shown by:
      ```
      $ grep -nE '`Where`|Where =|Where\(' report/*.md
      $
      ```
    - Fix: write "The report places a process with `Peer.spawn(name, f)` (§8.3)".

14. **The plan's MVP 3.0 still checks `Peer` "beside the constructor `Peer` of `Where`", a type that the same section says left the prelude.**
    - Place: docs/implementation_plan.md:231-232, against :202-205
    - Quote: "`Peer` as a namespace beside the constructor `Peer` of `Where` is checked against §4.2."
    - Wrong: no constructor `Peer` exists, so the decision this clause describes has nothing left to decide.
    - Shown by: none
    - Fix: drop the clause.

15. **The plan's MVP 3.2 lists the libraries written so far as `libs/ets` and `libs/markdown`. It leaves out `libs/ansi`, Appendix G.3, written on 2026-10-01.**
    - Place: docs/implementation_plan.md:305
    - Quote: "Written: `libs/ets` and `libs/markdown` (Appendix G; `libs/markdown` under \"Done\")."
    - Wrong: `libs/ansi` was written by commit cb554ec on 2026-10-01. It is Appendix G.3, and both `make` and the shell build against it.
    - Shown by: none
    - Fix: add `libs/ansi` (Appendix G.3) to the list.

16. **docs/architecture.md's *Tests* section, the owner of "what each test runs", leaves out the generated grammar programs, the typed programs, the library's laws and the operations programs.**
    - Place: docs/architecture.md:140-155; docs/development.md:11
    - Quote: "`make test` runs every kind below"
    - Wrong: these all run in `make test`, and the section names none of them: test/ern_grammar_tests.erl and test/ern_grammar_programs_tests.erl (`make test-grammar`), test/ern_typed_programs_tests.erl (`make test-typed`), erl/runtime/test/ern_laws_tests.erl, and `operations_test_` (test/ern_integration_tests.erl:1038). They are the three machines that soundness.md:3 rests on.
    - Shown by: none
    - Fix: add an item for each of the three machines, and name `operations_test_` under *Programs*.

17. **docs/development.md's layout of the repository predates MVP 2.99c. Its `test/` entry leaves out the grammar and typed tests, `ern_grammar.erl`, `layout/` and `expected/operations/`, and its `build/` entry leaves out `build/pages`.**
    - Place: docs/development.md:51-59, :76-79, :144; Makefile:266-272
    - Quote: "test/ what spans applications: the integration, document, style, guide, shell and terminal tests, ..." and "make clean remove build products"
    - Wrong: `make pages` writes `build/pages`, and the `clean` target's list does not remove it. So "remove build products" is false as well.
    - Shown by: none
    - Fix: list the missing parts, and add `build/pages` to the `build/` line and to `make clean`.

18. **docs/architecture.md uses names and arities from before the renaming. `run_tests/3` is now `/4`, and `Main`, `Opts`, `Msg`, `Alias` and `To` are names the glossary refuses and the code has dropped.**
    - Place: docs/architecture.md:83, :84, :99, :103, :129
    - Quote: "`run_main(Main, Site, Opts)`"; "`{fault, Msg}`"; "`{Caller, Callee, Alias}`"; "`{Subscriber, To}`"; "`ern test` is `run_tests/3`"
    - Wrong: the code has `run_main(EntryPoint, Site, Options)` (ern_rt.erl:1520), `{ern, fault, Cause}` (:406), `{Caller, Callee, Reply}` (:325), `{Subscriber, Address}` (:703) and `run_tests(Namespace, Loaded, Heading, ErrorDevice)` (ern_cli.erl:898). docs/style.md's glossary refuses `Main`, `Msg`, `Alias` and `To`.
    - Shown by: none
    - Fix: write the code's names: `EntryPoint`, `Options`, `Cause`, `Reply`, `Address` and `run_tests/4`.

19. **docs/memory.md says the reaper wakes ten times a second. While a load samples, it looks once a second, and has since MVP 2.99b's item 26.**
    - Place: docs/memory.md:25; the comment at test/ern_load.erl:138-145
    - Quote: "since the reaper wakes ten times a second to look for a deadlock (§8.6)"
    - Wrong: `mark` is a foreign call, and `counted/0` sees it, so `look/0` answers `delivering`, and the reaper then waits `LOOK_LATER`, 1000 ms (ern_rt.erl:84-85 and :439-446; commit 1930cd2, 2026-10-03). The reason given for reading the reaper until two readings agree assumes the old rate.
    - Shown by: none
    - Fix: give both rates, or drop the rate and keep the rule to read until two readings agree.

20. **docs/full_review.md says its readers read every document and all the code. Yet no brief names `emacs/README.md`, `tools/release/README.md`, `man/README.md`, `assets/README.md`, `test/ern_pty.py` or `tools/install.sh`.**
    - Place: docs/full_review.md:3, :29, :30, :31
    - Quote: "Between them they read the report, the guide, every other document, and all the code" and, in D's brief, "`README.md`, `CLAUDE.md`, `shell/README.md` and `docs/`"
    - Wrong: D's brief stops at `docs/`, and this run had to add the READMEs beside the code by hand. C reads "the Erlang of `test/`", so the Python harness belongs to no reader. E reads "the Ernest code", which `install.sh`, `strip.escript` and `unicode_width.escript` are not.
    - Shown by: none
    - Fix: give D every tracked Markdown file but the report, the guide, the log and `man/`'s generated pages, and give C the scripts under `tools/` and `test/`.

21. **docs/style.md says `make test` holds every Ernest source to `ern format`'s layout. The `docs/operations/*.ern` programs are outside every style test, outside `make format`, and outside the citation test.**
    - Place: docs/style.md, *Ernest*, first paragraph; test/ern_style_tests.erl:122-129 (`modules/0`); Makefile, `ERNEST_SOURCES`; test/ern_docs_tests.erl, `citations_resolve_test`
    - Quote: "`make test` holds every source to it, `make format` restores it"
    - Wrong: `modules/0`, `line_length_test` and `no_tab_test` glob `stdlib`, `examples`, `shell`, `libs`, `tools` and `test`, but not `docs/operations`. `ERNEST_SOURCES` leaves them out too, so neither `make format` nor the Emacs mode's corpus tests reach them. They are laid out today, but nothing keeps them so.
    - Shown by:
      ```
      $ ern format --check usage.ern numeric.ern num.ern; echo $?
      0
      ```
      This passes now, though no test runs it.
    - Fix: add `docs/operations/*.ern` to `modules/0`, to the two line tests, to `ERNEST_SOURCES` and to the citation test's live files.

#### Clarity

22. **docs/operations.md restates §4.9, §3.5, §5.6, E.25 and E.26 as "The specification", a second owner of the report's rules; findings 6 to 12 are its drift.**
    - Place: docs/operations.md:3 and :16-31, *What changes in Ernest* at :318-330; CLAUDE.md, *Who owns each fact*, the line on operations.md
    - Quote: "The report states the forms since 2026-10-02 ...; where this note and the report differ, the report holds." and "MVP 2.99b's item 5 builds it."
    - Wrong: each fact has one owner, and the language's is the report. A note that restates the rules with its own error texts and examples can only drift. Its header also still says "builds it" beside "Item 5 built them on 2026-10-03".
    - Shown by: none
    - Fix: keep the comparison with other languages and the costs, and replace rules 1 to 12 and *What changes in Ernest* with pointers to §4.9, §3.5, §5.6, E.25 and E.26. CLAUDE.md's line on the note says the same.

23. **`docs/operations/usage.ern`, operations.md and its scratch copy name the record `Ops` and `ops`. The report (§4.9, E.0 shape rule 1) and guide §7.3 write `Operations` and `operations`.**
    - Place: docs/operations/usage.ern:10-24; docs/operations.md:25, :109-122, :324; docs/scratch/operations.md
    - Quote: "type Ops(s, a) = Ops(fromList : (List(a)) -> s, intersection : (s, s) -> s, toList : (s) -> List(a))"
    - Wrong: one example's record has two names across the documents, and docs/style.md says "No abbreviation a reader must guess."
    - Shown by: none
    - Fix: name the record `Operations` and its argument `operations`, as the report does.

24. **`assets/README.md` is owned by no entry of CLAUDE.md's *Who owns each fact*, and restates the `<picture>` block that README.md, the guide and the release README each carry.**
    - Place: assets/README.md:1-15; CLAUDE.md, *Who owns each fact*
    - Quote: "The Ernest README logo is supplied in separate light- and dark-theme variants."
    - Wrong: it is a tracked document with no line naming what it owns, and its markup is a fourth copy that nothing holds equal to the other three.
    - Shown by: none
    - Fix: name it in CLAUDE.md as the logo's note, and point at README.md's markup instead of copying it.

25. **The plan's MVP 3.0 lists the check that a supervisor's children run on its node twice, once as the release review's C1-35 and once as a decision of 2026-09-27.**
    - Place: docs/implementation_plan.md:196-198 and :248-251
    - Quote: "`Supervisor.child` refusing a supervisor on another node" and "**A supervisor's children run on its node**, decided 2026-09-27"
    - Wrong: one item appears in two bullets, each with its own wording, within one milestone.
    - Shown by: none
    - Fix: merge the two bullets into one.

26. **docs/principles_review.md says its readers read the report and the guide, not the code, yet sends a reader in doubt to `erl/` and gives L the log.**
    - Place: docs/principles_review.md:3, :12, :21
    - Quote: "and reads the report and the guide, not the code"
    - Wrong: the opening sentence contradicts the note's own *How it runs* and its brief for L.
    - Shown by: none
    - Fix: say "reads the report and the guide; L reads the log; the code only as *How it runs* allows".

27. **The checker names the type whose fields it reads `Owner`, a word the glossary keeps for a resource's process alone.**
    - Place: erl/typer/src/ern_typecheck.erl:694-731 (`at_parameters`) and :2454-2473 (`cannot_derive`); docs/style.md, glossary entries *Owner* and *MemberOf*
    - Quote: "**Owner**: the process that opened a resource or was given it (§6.9, E.18), and nothing else; the type a member belongs to is its MemberOf."
    - Wrong: this code, written after the glossary (the recursive-group rule and `derives`), departs from it in 15 places.
    - Shown by: none
    - Fix: rename it `MemberOf` in `cannot_derive`, and `Declaring` in `at_parameters`.

28. **`mvp_refusals_listed_test` finds only texts that say "in MVP n". `--config-dir`'s help, "its ernest.conf is read from MVP 3.0", names an MVP and slips past it.**
    - Place: erl/cli/test/ern_cli_tests.erl:1709; erl/cli/src/ern_cli.erl:578, :582, :585
    - Quote: "every error text in erl/*/src or in the shell's own Ernest source that names an MVP appears in that document's table", over the pattern `\bin MVP [0-9]`
    - Wrong: CLAUDE.md says that a test holds every such text to development.md's table. Today the table's row happens to cover `ernest.conf`, but a text worded "from MVP" or "until MVP" would never be checked.
    - Shown by: none
    - Fix: match `\bMVP [0-9]` in any string literal.

29. **docs/install.md lists what the release archive holds but leaves out `assets/`. `install.sh release` copies it there beside the README, which shows it.**
    - Place: docs/install.md:50; tools/install.sh:170
    - Quote: "the staged tree without the compiled helper, and beside it the helper's source `ern_exec.c`, `install.sh`, the `Makefile` of `tools/release`, and the `README.md` it installs"
    - Wrong: the list leaves out one directory that the archive holds.
    - Shown by: none
    - Fix: add "and the logo it shows, under `assets/`".

#### Where the language made the work harder

30. **A constructor of two positional fields, `Vec(Float, Float)`, is refused with only the parser's "expected `)` instead of `,`", and no help line names §3.5's rule.**
    - Place: §3.5; the parser's diagnostic for a type declaration
    - Quote: "A constructor has no fields, exactly one positional field, or named fields"
    - Wrong: I wrote this while checking operations.md's `Vec.+` message, as one who knows ML or Gleam would write it. The error names a token, not the rule, so the reader has to find out from §3.5 that the fields must be named or wrapped in a tuple.
    - Shown by:
      ```
      $ cat v2.ern
      type Vec = Vec(Float, Float)

      export fn main() : Unit with Never = Unit
      $ ern build v2.ern
      v2.ern:1:21: expected `)` instead of `,`
      1 | type Vec = Vec(Float, Float)
        |                     ^
      ```
    - Fix: add a help line: "a constructor holds one positional field; name the fields, `Vec(x : Float, y : Float)`, or hold a tuple".

#### Lists in two places

- The README's "What Ernest adds" list and guide §0's: `what_ernest_adds_test` (test/ern_docs_tests.erl).
- emacs/README.md's init lines and the header of emacs/ernest-mode.el: `emacs_installation_test` (test/ern_style_tests.erl).
- The Emacs mode's reserved words and painted operators, and the lexer's: `emacs_mode_mirrors_the_lexer_test`.
- The Emacs mode's table of how tightly each operator binds, and the parser's: `emacs_mode_mirrors_the_parser_test`.
- §11.2 *Commands* and `Shell.Command.commands`: `commands_mirror_test` (test/ern_shell_tests.erl).
- docs/module_doc_template.md and `ern doc examples/template.ern`: `doc_template_test` (erl/cli/test/ern_cli_tests.erl).
- development.md's table of refusals and the code's refusal texts: `mvp_refusals_listed_test`, which only matches "in MVP n" (finding 28).
- The contents lists of the report's three files and the guide, and their headings: `contents_test`.
- stdlib/ordered_set.ern and guide §7.3's copy of it: `ordered_set_shown_whole_test`.
- Appendix E's "The primitives are" sentences and each module's `foreign fn`s: `primitives_test` (erl/typer/test/ern_prelude_tests.erl).
- `ern_prelude:values/0` and the modules' exports: `prelude_targets_test`; the standard library's names: `stdlib_targets_test`.
- The fault causes quoted in §0 to §11 and §7.4's list: `fault_causes_test`.
- THIRD_PARTY_LICENSES and the tracked files that carry an upstream copyright or a generated table: `third_party_test`.
- man/'s pages, their indexes and `VERSION`: `release_pages_test`.
- ern(1) and the report's §11: `manual_pages_test_`.
- The log's index and its headings: `log_index_names_every_section_test`.
- test/diagnostics.md's outputs and what `ern build` prints: the guide tests (`make test-guide`).
- docs/operations.md's excerpts and stdlib/ordered_set.ern, stdlib/ordered_map.ern and docs/operations/*.ern: none; the set excerpt has drifted (finding 7).
- docs/operations.md's printed outputs and test/expected/operations/*.out: none. `operations_test_` holds the programs to the .out files, not to the note, as the note's header claims.
- docs/operations.md's quoted diagnostics and the compiler: none; two have drifted (findings 6 and 8).
- docs/scratch/operations.md and docs/operations.md: none, a copy CLAUDE.md allows. It carries findings 6, 7 and 8 too.
- shell_design.md's groups of the front end's functions and the `foreign fn`s of shell/shell.ern and shell/shell/complete.ern: none; drifted (finding 4).
- architecture.md's runtime tables, memory.md's `rows`, `ern_load:sample/1`, and `ern_rt`'s `ets:new` calls: none; drifted (findings 1 and 2).
- architecture.md's modules per stage and erl/*/src: none; equal today.
- architecture.md's kinds of tests and the Makefile's areas: none; drifted (finding 16).
- development.md's make targets and the Makefile: none; equal today.
- development.md's layout of the repository and the tree: none, since `document_paths_test` checks only that a named path exists; drifted (finding 17).
- memory.md's table of loads, test/Makefile's `LOADS` and test/load/: none; equal today.
- memory.md's named regression tests and the tests: none beyond `document_paths_test`'s paths; equal today.
- emacs_mode.md's table of eight tests, emacs/test/*.el and the Makefile's `EMACS_TESTS` with the typing parts: none; equal today.
- shell/README.md's table of modules and shell/shell/*.ern: none; equal today.
- install.md's installed layout and tools/install.sh: `installation_test_`, in part.
- CLAUDE.md's *Who owns each fact*, development.md's *The documents*, and full_review.md's briefs: none; they differ (findings 20 and 24).
- The `<picture>` logo block in README.md, ernest_guide.md, tools/release/README.md and assets/README.md: none.
- The install steps in README.md and tools/release/README.md: none.
- The readers of full_review.md and their use in release_review.md: none.
- docs/style.md's *(tested)* marks and test/ern_style_tests.erl: none; equal today.
- The plan's standing gaps and `make sections`' output: none, beyond the release review running it by hand; equal today (§3.11, §6.7, §8.7).

### C, part 1, the front end with the Emacs mode; its 1 to 36 are C1 to C36

#### Defects

1. **`ern_ast:free_names` skips a clause's pattern, so a local fn whose pattern's `size(n)` reads an outer name does not capture it, and `ern build` crashes.**
   - Place: erl/parser/src/ern_ast.erl:236
   - Quote: "free_names(#clause{pattern = Pattern, guard = Guard, body = Body}, Bound) -> Bound1 = bound_names(Pattern) ++ Bound, free_names(Guard, Bound1) ++ free_names(Body, Bound1);"
   - Wrong: §5.11 lets a pattern's size read "a block `let`" in scope; the size expression sits inside the pattern, which this clause never walks, so the emitter's closure for a local fn (ern_emitter.erl:1593) misses `n`. The same holds for `statement_free_names` of a `#binding{}`.
   - Shown by:
     ```
     $ cat sizefree.ern
     export fn main() : Unit with m = {
         let n = 8;
         fn first(b : Bytes) : Int = match b {
             <<v:size(n), _:bytes>> -> v
           | _ -> 0
         };
         Io.println(Int.toString(first(<<7, 9>>)))
     }
     $ ern build sizefree.ern
     ern: internal error: exception error: no match of right hand side value
                      #{first => {local_fn,'first$1',[],[],[],[],#{n => 'N_2'}}}
       in function  ern_emitter:name_form/7 (ern_emitter.erl:649)
     ```
   - Fix: walk a pattern's bitstring size expressions with the names bound outside the pattern, in a clause and in a binding.

2. **`ern_ast:free_names` binds a local fn only from the statement after it, not throughout its block (§5.4), and `ern build` crashes on a forward call.**
   - Place: erl/parser/src/ern_ast.erl:250 (and the comment at 224)
   - Quote: "statement_free_names(#fn_declaration{name = Name, params = Params, body = Body}, Bound) -> {free_names(Body, [Name | param_names(Params)] ++ Bound), [Name | Bound]};" and "a local fn's name for the rest of its block and its own body bind"
   - Wrong: §5.4: "A `fn` declared in a block is visible throughout it". A call to a later sibling is reported free in the enclosing block, so an outer local fn is taken to capture an unrelated `let` of the same name declared after it.
   - Shown by:
     ```
     $ cat forward3.ern
     export fn main() : Unit with m = {
         fn outer() : Int = {
             fn first() : Int = second();
             fn second() : Int = 1;
             first()
         };
         let x = outer();
         let second = 5;
         Io.println(Int.toString(x + second))
     }
     $ ern build forward3.ern
     ern: internal error: exception error: bad key: second
       in function  map_get/2
       in call from ern_emitter:'-instances/5-lc$^0/1-0-'/3 (ern_emitter.erl:1635)
     ```
     Without `let second = 5` the same module builds and prints 1.
   - Fix: bind every local fn name of a block for all its statements before walking them, and correct the comment to §5.4's rule.

3. **The formatter strips four columns from a raw string's continuation lines in a body example of a doc block or a CommonMark text, changing the string's value.**
   - Place: erl/format/src/ern_format.erl:106 (dedent at 114-122)
   - Quote: "[dedent(Line, 4) || Line <- Inner]" and "_ -> string:trim(Line, leading, \" \")"
   - Wrong: §11.6 says every token is written as written. A raw string's later lines are not indented by the `fn f() = {` wrapper, yet every line of the wrapper's output is dedented by four, and one shorter than four bytes loses all its leading spaces.
   - Shown by:
     ```
     $ cat rawdoc3.ern
     /// A value.
     ///
     /// ```ernest
     /// let s = `a
     ///     b`;
     /// String.length(s)
     /// ```
     export let x : Int = 1
     $ ern format - < rawdoc3.ern
     ...
     /// let s = `a
     /// b`;
     ...
     ```
     `///  \`;` (one space of content) becomes `/// \`;` the same way.
   - Fix: dedent only the lines that begin a token or comment outside a multi-line token, or lay the example out without the wrapper's indentation.

4. **`ern format` lays out a module whose misplaced doc block the parser refuses, since it removes doc tokens before parsing.**
   - Place: erl/format/src/ern_format.erl:149 (split), 43
   - Quote: "{CodeTokens, Trivia} = lists:partition(fun(Token) -> not is_trivium(Token) end, Tokens)"
   - Wrong: §11.6: "A module that does not parse is left as it is, and its diagnostic is written". `prune_docs` (ern_parser.erl:125) never sees the doc tokens, so a stray doc block, a doc block alone in a file, or one inside a type's positional argument is laid out and exits 0 while `ern build` refuses the module.
   - Shown by:
     ```
     $ cat stray_doc.ern
     export fn main() : Unit with m = {
         /// a stray doc block
         fn helper() : Int = 1;
         Io.println(Int.toString(helper()))
     }
     $ ern build stray_doc.ern
     stray_doc.ern:2:5: a doc block documents nothing here
     $ ern format - < stray_doc.ern; echo $?
     export fn main() : Unit with m = {
         /// a stray doc block
         fn helper() : Int =
             1;
         Io.println(Int.toString(helper()))
     }
     0
     ```
   - Fix: parse the code tokens with the doc tokens kept, as `ern build` does, and take the docs out for the layout afterwards.

5. **The shell refuses a doc block typed alone instead of taking another line, though the declaration it documents can only follow on the next line.**
   - Place: erl/parser/src/ern_parser.erl:125-137
   - Quote: "fail(Position, \"a doc block documents nothing here\", ...)"
   - Wrong: §11.2: an input the parser cannot finish "is one that ends where the grammar expects more", and takes another line. A doc block followed by the end of input is refused, not marked incomplete, so a documented declaration cannot be typed at the prompt.
   - Shown by:
     ```
     $ printf '/// Adds one.\nfn inc(n : Int) : Int = n + 1\n' | ern shell
     > input 1:1:1: a doc block documents nothing here
     1 | /// Adds one.
       | ^^^^^^^^^^^^^
     > inc : (Int) -> Int
     ```
   - Fix: where the token after the doc block is `eof`, throw the diagnostic with `incomplete = true`.

6. **A parenthesized expression's span begins after its `(` but ends at its `)`, so a diagnostic underlines `1 + 2)` and `true)`.**
   - Place: erl/parser/src/ern_parser.erl:829-831
   - Quote: "primary([{'(', _} | Rest]) -> {Expr, Rest1} = expr(Rest), spanned({Expr, expect(Rest1, ')')});"
   - Wrong: §11.5 underlines "the erroneous span"; a span that takes the closing parenthesis and not the opening one is neither the expression nor the parenthesized form. The formatter's `is_parenthesized` (ern_format.erl:275) relies on the lopsided span.
   - Shown by:
     ```
     $ ern build paren_span.ern
     paren_span.ern:1:20: the body does not have the declared result type: expected String, found Int
     1 | fn f() : String = (1 + 2)
       |                    ^^^^^^
     paren_span.ern:5:19: the argument does not fit g: expected Int, found Bool
     5 | fn h() : Int = g((true))
       |                   ^^^^^
     ```
   - Fix: keep the inner expression's span, or span from the `(`, and let the formatter find parentheses from its pairs map; add the case to `spans_test`.

7. **An unclosed or extra bracket earlier in a file is reported as "a doc block documents nothing here" at a later, correctly placed doc block.**
   - Place: erl/parser/src/ern_parser.erl:122-150 (prune_docs, run before parsing)
   - Quote: "Depth counts the open brackets, so that only a declaration keyword outside every bracket is top-level"
   - Wrong: the pre-pass reads the whole file before the parser and stops at the doc block, so the first real error, the bracket, is never reported, and the message blames a correct doc block.
   - Shown by:
     ```
     $ printf 'fn f() : Int = g(1\n\n/// Two.\nfn g(x : Int) : Int = 2\n' > unclosed.ern
     $ ern build unclosed.ern
     unclosed.ern:3:1: a doc block documents nothing here
     $ # the same file without the doc block:
     unclosed2.ern:3:1: expected `)` instead of `fn`
     ```
   - Fix: check a doc block's place where the parser reaches it, or let a later parse error take precedence over the pre-pass's.

8. **The `a < -1` help line is missing where a `<-` stands in place of a block's `;` or `}`, or after a top-level body.**
   - Place: erl/parser/src/ern_parser.erl:971-972 and 178-181
   - Quote: "fail(position(Token), \"expected `;` or `}` instead of \" ++ describe(Token))"
   - Wrong: §11.5: "A `<-` where the parser expects a delimiter has a help line that names `a < -1`". Only `expect/2` gives it; `statements/2` and `declaration/1` fail without it.
   - Shown by:
     ```
     $ printf 'fn f(x : Int) : Bool = { x<-1 }\n' > lt.ern; ern build lt.ern
     lt.ern:1:27: expected `;` or `}` instead of `<-`
     1 | fn f(x : Int) : Bool = { x<-1 }
       |                           ^^
     $ printf 'fn f(x : Int) : Bool = x<-1\n' > lt.ern; ern build lt.ern
     lt.ern:1:25: expected a declaration (type, abstract, fn, let, foreign) instead of `<-`
     ```
     `g(x<-1)`, `[x<-1]` and a guard `y<-1 ->` carry the help line.
   - Fix: give every "instead of `<-`" failure the same help line, through one helper.

9. **The Emacs mode places a bitstring's further items at column 0 or under the call's bracket, where `ern format` aligns them under the first item after `<<`.**
   - Place: emacs/ernest-mode.el:489-500
   - Quote: "(when (memq (char-after) '(?\\( ?\\[))"
   - Wrong: §11.6 counts `<<` among the brackets whose items stand under the first; the syntax table knows no `<<` bracket, so reindenting the formatter's own output moves the line. No source in the corpus breaks a bitstring, so reindent.el and typing.el do not see it.
   - Shown by:
     ```
     $ ern format - < case6.ern
     fn k(x) =
         send(x,
              <<aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa:size(16)-big,
                bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb:bytes>>)
     $ emacs -Q -batch -l reindent_one.el case6f.ern
     case6f.ern:4: was |           bbbb...:bytes>>)|
     case6f.ern:4: now |         bbbb...:bytes>>)|
     ```
     A broken bitstring outside any bracket goes to column 0.
   - Fix: treat `<<` and `>>` as a bracket pair in the indentation's bracket search, and add a broken bitstring to the tests.

10. **The Emacs mode puts the operand after an operator line that ends in a trailing comment at column 0, where `ern format` puts it at the operator's step.**
    - Place: emacs/ernest-mode.el:602-610
    - Quote: "(open content)\n       (t 0)"
    - Wrong: the formatter writes `x\n        + // plus\n        1` and `foo(x)\n        |> // then\n        bar`; the line after the comment is neither a continuation nor after a body opener, so the mode sends it to column 0, though its indentation should follow the formatter's.
    - Shown by:
      ```
      $ ern format - < case4.ern   # fn k(x) = foo(x) |> // then <newline> bar
      fn k(x) =
          foo(x)
              |> // then
              bar
      $ emacs -Q -batch -l reindent_one.el case4f.ern
      case4f.ern:18: was |        bar|
      case4f.ern:18: now |bar|
      ```
    - Fix: a line after one whose code ends in a binary operator carries that operator's expression on, as a line that opens with one does.

11. **The lexer's octal messages read "a octal": "0o needs a octal digit" and "8 is not a octal digit".**
    - Place: erl/lexer/src/ern_lexer.erl:265, 272
    - Quote: "[$0, Prefix] ++ \" needs a \" ++ Name ++ \" digit\""
    - Wrong: the article is built as "a" for every base name, wrong before "octal".
    - Shown by:
      ```
      $ printf 'export let a : Int = 0o8\n' > oct.ern; ern build --short-errors oct.ern
      oct.ern:1:22: 0o needs a octal digit
      $ printf 'export let a : Int = 0o78\n' > oct2.ern; ern build --short-errors oct2.ern
      oct2.ern:1:25: 8 is not a octal digit
      ```
    - Fix: carry the article with the name, `{8, "an octal"}`, or word the messages without one.

12. **The Emacs mode's colours disagree with the lexer twice: `1.0e1_0` is painted only as far as `1.0`, and a `///` after a block comment is painted as an ordinary comment.**
    - Place: emacs/ernest-mode.el:180, 153-154
    - Quote: "\\\\(?:[eE][-+]?[0-9]+\\\\)?\\\\_>" and "(progn (skip-chars-backward \" \\t\") (bolp))"
    - Wrong: §2.5 allows `_` between an exponent's digits (`decimal`), which the lexer test accepts; and the lexer reads `/* c */ /// doc` as a doc block (ern_lexer_tests.erl:214), which the mode paints `font-lock-comment-delimiter-face`.
    - Shown by:
      ```
      $ emacs -Q -batch -l colour_probe.el
      1.0e1_0  at start: font-lock-constant-face
      e1_0     at start: nil
      /// doc  at start: font-lock-comment-delimiter-face
      ```
    - Fix: allow `_` between exponent digits in the regexp, and skip a block comment before `///` as the lexer's `is_after_token` does.

#### Clarity

13. **`ern_ast.hrl` documents a bitstring spec `{unit, integer()}` that the parser refuses and nothing builds.**
    - Place: erl/parser/include/ern_ast.hrl:97
    - Quote: "spec(): {size, Expr} | {unit, integer()} | bytes | int | float"
    - Wrong: `bit_spec/1` refuses `unit` (ern_parser.erl:1137, "there is no `unit` specifier"); the comment no longer holds.
    - Shown by: `grep -rn '{unit,' erl` finds only this comment and an unrelated `calendar` option.
    - Fix: drop `{unit, integer()}` from the comment.

14. **`ern_ast.hrl` holds a "DeclName" comment attached to no record, and `#e_constructor.base` is documented as a record update's alone, leaving out the fill.**
    - Place: erl/parser/include/ern_ast.hrl:18-19, 86
    - Quote: "%% DeclName: name is an ident or a userop atom; member_of is the typename prefix" and "base: the Expr of a record update's `..`, or undefined (report §5.6)"
    - Wrong: the first comment stands above `#module_doc{}` but describes `#fn_declaration{}`'s fields; the second omits the fill, `Ops(..Set)`, whose namespace is parsed into `base` too (ern_parser.erl:842).
    - Shown by: none
    - Fix: move the DeclName lines under `#fn_declaration{}`, and say "the expression after `..`, a record update's base or a fill's namespace".

15. **Sixteen test comments cite entries of a findings.md that no longer exists, "findings.md's P1-23", "findings C17", "C3-29".**
    - Place: erl/lexer/test/ern_lexer_tests.erl:74, 209, 267; erl/parser/test/ern_parser_tests.erl:160, 226, 600, 926; erl/format/test/ern_format_tests.erl:26, 320, 328, 335, 346, 353; erl/utils/test/ern_chunk_tests.erl:16, 30; erl/utils/test/ern_diagnostic_tests.erl:69
    - Quote: "(findings.md's C3-29)"
    - Wrong: the document is removed when a review closes; a reader cannot follow the citation, and the same label, C17, names different findings in two files.
    - Shown by: `ls docs | grep -i finding` prints nothing.
    - Fix: state what the defect was in the comment, which most already do, and drop the labels.

16. **`softline` is a layout element no template ever builds, handled in six places across the printer and the formatter.**
    - Place: erl/format/src/ern_pretty.erl:8, 31, 69, 71, 207, 209; erl/format/src/ern_format.erl:698, 747
    - Quote: "line, softline   a space or nothing on one line"
    - Wrong: dead code; no template in ern_format or ern_docs writes `softline`.
    - Shown by: `grep -n softline erl/format/src/*.erl erl/emitter/src/ern_docs.erl` finds only the handlers.
    - Fix: remove `softline` from the type, the printer, `fits`, `resolve` and `leading_break`.

17. **`#cursor.previous` is said to hold "the code token before" but holds a comment's kind too, and `#trivium`'s comment confuses its `line` field with a kind.**
    - Place: erl/format/src/ern_format.erl:24-27, 29-32 (set at 867, 916)
    - Quote: "the last line written from the source, the code token before" and "its kind, line, block or doc, where it begins"
    - Wrong: `lead_trivia` and `trailing` set `previous = Kind` (`line`, `block`, `doc`); `blank_before` and `trailing` compare it against bracket symbols. The trivium comment makes `line` read as a field.
    - Shown by: none
    - Fix: "previous: the symbol of what was written last, a code token or a comment's kind"; "kind: line, block or doc; line: the line it begins on".

18. **The lexer's main loop names its options parameter `_KeepComments` in its first clause and `Options` in every other.**
    - Place: erl/lexer/src/ern_lexer.erl:99
    - Quote: "lex([], Line, Column, PreviousEnd, Acc, _KeepComments) ->"
    - Wrong: one value, two names, and the first says it is a flag for comments while it is the option list.
    - Shown by: none
    - Fix: `_Options`.

19. **The parser abbreviates type variables as `Vars`, `Var`, `ForeignVars`, `AfterVars`.**
    - Place: erl/parser/src/ern_parser.erl:208-209, 447-456
    - Quote: "{ForeignVars, AfterVars} = separated(AfterParen, ',', fun foreign_var/1)"
    - Wrong: docs/style.md: no abbreviation a reader must guess, and the glossary's TypeVariable; the same file writes `Variables` at 326.
    - Shown by: none
    - Fix: `TypeVariables`, `Parameters`, `AfterParameters`.

20. **`worst` in the Emacs corpus tests holds the last misplaced line, which they print as "last".**
    - Place: emacs/test/flatten.el:16, 35-38; emacs/test/typing.el:37, 58-65
    - Quote: "(setq worst (format \"%s:%d: %s\" ...))" and "(concat \"\\n  last: \" worst)"
    - Wrong: each misplaced line overwrites it, so the name says one thing and the output another.
    - Shown by: none
    - Fix: `last-moved`.

21. **`reads_with_previous` names an index `At`, which the glossary refuses for an index.**
    - Place: erl/format/src/ern_format.erl:821-823
    - Quote: "[element(At, Code#code.texts) || At <- Indexes]"
    - Wrong: docs/style.md glossary: "index ... Not `at`".
    - Shown by: none
    - Fix: `[element(Each, ...) || Each <- [Index - 1, Index]]`, or name the two tokens `Previous` and `Next`.

22. **A token's position is a four-part tuple, and a span a three-part one, read by counting across the lexer, the parser, the formatter and the diagnostics.**
    - Place: erl/utils/src/ern_diagnostic.erl:48, 54-55; read at erl/parser/src/ern_parser.erl:1229, erl/format/src/ern_format.erl:844
    - Quote: "-type position() :: {pos_integer(), pos_integer(), {pos_integer(), pos_integer()}, {pos_integer(), pos_integer()}}."
    - Wrong: docs/style.md: "A value of more than three parts is a record, and so is a tuple of more than two that crosses modules: a positional tuple makes its reader count"; readers write `{_, _, _, End} = position(Next)`.
    - Shown by: none
    - Fix: make position and span records in ern_diagnostic.hrl, or record in the style guide why the token's position is exempt.

23. **`ern_namespace:erlang_module` cites report §4.2 for the `ern@` naming, which the report does not state.**
    - Place: erl/utils/src/ern_namespace.erl:89-90
    - Quote: "%% Report §4.2: the Erlang module a namespace compiles to, `ern@` and the path with `@` for `/`"
    - Wrong: no file of the report contains `ern@`; the name is the toolchain's (docs/style.md).
    - Shown by: `grep -n 'ern@' report/*.md` prints nothing.
    - Fix: cite docs/style.md's rule, or drop the citation.

24. **The Emacs mode cites the wrong report sections: declarations as "section 3", and its reserved words as restating Appendix A.**
    - Place: emacs/ernest-mode.el:296, 62-64, 73
    - Quote: "How a declaration opens, in column zero (report section 3)." and "These restate Appendix A"
    - Wrong: declarations are §4; the reserved words are §2.4 and the operators §2.6.
    - Shown by: none
    - Fix: cite §4, §2.4 and §2.6.

25. **The lexer's symbol list says "max-munch is clause order", but it is a list searched in order, not clauses.**
    - Place: erl/lexer/src/ern_lexer.erl:39
    - Quote: "%% Longest first, so max-munch is clause order."
    - Wrong: the comment names the wrong mechanism.
    - Shown by: none
    - Fix: "Longest first, so the first symbol `symbol/2` finds is the longest."

26. **Three preconditions break the style guide's form: an inverted `andalso`, a two-condition `orelse` chain, and a three-line `orelse`.**
    - Place: erl/lexer/src/ern_lexer.erl:110-112; erl/format/src/ern_format.erl:841-842; erl/parser/src/ern_parser.erl:303-305, 352-357
    - Quote: "is_after_token(Acc, Line) andalso error_at(...)" and "Expected =:= any orelse symbol(Token) =:= Expected orelse error(...)"
    - Wrong: docs/style.md: "A precondition is `Cond orelse fail(...)` on one line; two or more conditions are a `case`."
    - Shown by: none
    - Fix: `not is_after_token(Acc, Line) orelse error_at(...)`; a `case` in `consume`; name the message before the one-line precondition in the parser.

27. **`ern_lexer_tests` and `ern_parser_tests` open with `-module` and no comment stating their job.**
    - Place: erl/lexer/test/ern_lexer_tests.erl:1; erl/parser/test/ern_parser_tests.erl:1
    - Quote: "-module(ern_parser_tests)."
    - Wrong: docs/style.md: "A module has one job, which its first comment states"; the other four test modules of this part have one.
    - Shown by: none
    - Fix: a first line saying what each tests and against which sections.

28. **`misc_errors_test` checks fifteen unrelated refusals, and `errors_test` in the lexer's tests twenty, each under one name.**
    - Place: erl/parser/test/ern_parser_tests.erl:740; erl/lexer/test/ern_lexer_tests.erl:249
    - Quote: "misc_errors_test() ->"
    - Wrong: docs/style.md: "A test function tests one behaviour, is named after it"; a failure names no behaviour.
    - Shown by: none
    - Fix: split them by the rule each refusal checks, `foreign_result_type_test`, `bitstring_specifier_test`, and so on.

29. **The reserved-word test omits `or`, one of §2.4's twenty words.**
    - Place: erl/lexer/test/ern_lexer_tests.erl:32-36
    - Quote: "tokens(\"type abstract with foreign derives match when receive after as \""
    - Wrong: §2.4 lists `or` under pattern matching and `?RESERVED` holds it, but no test of §2.4 checks it.
    - Shown by: none
    - Fix: add `or` to the text and the expected list.

30. **`ern_ast:walk` is said to visit records, but visits every atom-tagged tuple, `{positional, T}`, `{named, Fs}`, `{size, E}`, `{prelude, Q}`.**
    - Place: erl/parser/src/ern_ast.erl:173-176
    - Quote: "a node being a tuple whose first element is its record's name"
    - Wrong: a visitor is handed tuples that are no node; the comment does not warn it.
    - Shown by: none
    - Fix: say "every tuple whose first element is an atom, a record or a tagged part of one".

31. **The Emacs mode writes three walks twice: the previous and the next code line, the first-item and more-items comma searches, and the limit 100 in three loops.**
    - Place: emacs/ernest-mode.el:246-268, 466-487, 365, 386, 422
    - Quote: "(while (and (not found) (zerop (forward-line -1)))" beside "(while (and (not found) (zerop (forward-line 1)))"
    - Wrong: the bodies are the same but for a direction or a bound; the limit is a bare number with the same comment each time.
    - Shown by: none
    - Fix: one `ernest--code-line (direction)`, one `ernest--item-comma-p (open from to)`, and a `defconst` for the walk's limit.

32. **The per-application Makefile is copied byte for byte into every `erl/*/src`.**
    - Place: erl/lexer/src/Makefile:1 (and erl/parser, erl/format, erl/utils)
    - Quote: "# Generic per-application Makefile. Identical in every erl/*/src."
    - Wrong: the four files of this part have one md5sum; a change must be made in each.
    - Shown by: `md5sum erl/{lexer,parser,format,utils}/src/Makefile` prints one hash four times.
    - Fix: one `erl/app.mk` included by a one-line Makefile in each application.

33. **A doc block inside a type's positional argument or a field's annotation is refused as "expected a type instead of doc comment", not as a doc block that documents nothing.**
    - Place: erl/parser/src/ern_parser.erl:129, 1241
    - Quote: "orelse (InType andalso lists:member(symbol(Next), [typename, ident, '|']))" and "describe({doc, _, _}) -> \"doc comment\";"
    - Wrong: §2.2's rule is the one broken, but the message names a type; and the token is called "doc comment" here and "doc block" in every other message.
    - Shown by:
      ```
      $ printf 'type T = A(\n    /// doc\n    Int)\n' > docpos.ern; ern build docpos.ern
      docpos.ern:2:5: expected a type instead of doc comment
      ```
    - Fix: attach a doc in a type only before a constructor, its `|` or a named field's name, so the rest fall to "a doc block documents nothing here"; describe the token as "doc block".

34. **One parser message cites report sections inside the diagnostic, "(§4.8, E.1)", which no other message does.**
    - Place: erl/parser/src/ern_parser.erl:304-305
    - Quote: "\" is not a member: a requirement names compare, negate, an operator or show (§4.8, E.1)\""
    - Wrong: the user's message carries the report's numbering, unlike every other diagnostic of the front end.
    - Shown by: none
    - Fix: drop the parenthesis, or give the rule in a help line.

35. **In typing.el the body of an `unless` is indented as its sibling.**
    - Place: emacs/test/typing.el:47-48
    - Quote: "(unless (string-match-p \"\\\\`[ \\t]*//\" (car (last before)))\n                 (with-temp-buffer"
    - Wrong: `with-temp-buffer` is inside `unless` but stands at its column, so the cut-skipping reads as unconditional.
    - Shown by: none
    - Fix: indent the body two columns further, as `indent-region` in emacs-lisp-mode does.

36. **Missing spec: neither §11.5 nor §2.1 says how an excerpt shows a byte that is not UTF-8, or where "input is not valid UTF-8" stands.**
    - Place: erl/utils/src/ern_diagnostic.erl:133-138; erl/lexer/src/ern_lexer.erl:71-72
    - Quote: "%% Report §11.5: a source's characters, each byte that begins no UTF-8 character as U+FFFD"
    - Wrong: §11.5 names U+FFFD only for U+0080 to U+009F, and §2.1 says only that source text is UTF-8; the placement at the first bad byte and its picture are the code's choices.
    - Shown by: none
    - Fix: add the two sentences to §2.1 and §11.5.

### C, part 2, the checker; its 1 to 35 are C37 to C71

#### Defects

1. **The checker crashes with an internal error when an unannotated fn's result type was fixed by an earlier use and its body gives another type**
   - Place: erl/typer/src/ern_typecheck.erl:3731
   - Quote: "%% the first branch where nothing fixed the type: the expectation is a"
   - Wrong: check_value/3 unifies the placeholder with the declaration's type before the body (line 1802), so for a local fn used earlier in its block, or a group member another member used first, the result type is no longer fresh. check_expr/5 with no rule then calls bound/3, whose `{ok, _} = ern_types:unify(...)` fails, and the build stops with a crash in place of a diagnostic.
   - Shown by:
     ```
     fn main() : Int = {
         let x = h() + 1;
         fn h() = "a";
         x
     }
     $ ern build local_crash.ern
     ern: internal error: exception error: no match of right hand side value
                      {error,{mismatch,{tcon,['Int'],[]},{tcon,['String'],[]}}}
       in function  ern_typecheck:bound/3 (ern_typecheck.erl:5393)
       in call from ern_typecheck:check_expr/5 (ern_typecheck.erl:3735)

     fn g(n : Int) = f(n) + 1
     fn f(n : Int) = if n == 0 then "a" else { let _ = g(n - 1); "b" }
     -> the same crash; with the two declarations swapped, a diagnostic
     ```
   - Fix: check a fn's body with a rule whenever its result type is no longer a fresh variable, through unify_at/6 rather than bound/3.

2. **A reply in a declared type whose field is `List(a)` is not reply-carrying, so `Box(Reply(Int))` for `type Box(a) = Box(List(a))` is dropped silently**
   - Place: erl/typer/src/ern_typecheck.erl:848
   - Quote: "%% Does variable Id reach the type outside function types and the"
   - Wrong: §6.6 makes a declared type reply-carrying where its fields, its arguments substituted, are, and says "`List` is, through its elements". in_reply/3, which computes reply_params, does not follow a List's element as reply_in/3 does (line 998), and the comment of with_reply_params (788-792) says a built-in type's arguments never carry a reply. The parameter is marked as reaching no field, so the box is no obligation and functions over it take no `!`.
   - Shown by:
     ```
     type Box(a) = Box(List(a))
     fn drop(r : Reply(Int)) : Unit = { let b = Box([r]); Unit }
     $ ern build box_list.ern      -> exit 0
     (with type Box(a) = Box(a) and Box(r): "the reply-carrying value b is never consumed")

     > type LBox(a) = LBox(List(a))
     > fn lforget(b : LBox(a)) : Unit = Unit
     > :t lforget
     lforget : (LBox(a)) -> Unit     (over type Box(a) = Box(a): forget : (Box(a!)) -> Unit)
     ```
   - Fix: give in_reply/3 reply_in/3's clause for `{tcon, ['List'], [Element]}`, and correct the comment at 788-792.

3. **A bitstring size naming an earlier segment's variable is counted as a reference to the top-level `let` of that name, so a false initialization cycle is reported**
   - Place: erl/typer/src/ern_typecheck.erl:1224
   - Quote: "references_in(Guard, Env, references_in_pattern(Pattern, Env, Acc, Bound),"
   - Wrong: §5.11: a size's variable "is bound by an earlier segment of the same bitstring". references_in_pattern/4 walks the sizes with the Bound of the clause's surroundings, without the earlier segments' variables, so `size(n)` after `<<n, ...` reads as the top-level `n`, and the §8.5 graph gets an edge the program does not have.
   - Shown by:
     ```
     let n : Int = parse(<<2, 7, 8>>)

     fn parse(bytes : Bytes) : Int =
         match bytes {
             <<n, body:size(n)-bytes>> -> Bytes.size(body)
           | _ -> 0
         }
     $ ern build size_cycle.ern
     size_cycle.ern:1:1: the initializer of n depends on itself, through parse
     (the same module with the let renamed m compiles)
     ```
   - Fix: in references_in_pattern/4, add each segment's variable to Bound for the segments after it, as bit_pattern/3 scopes them.

4. **A `receive` guard's ordering is refused when its operands' type is fixed later in the definition, before operators are resolved**
   - Place: erl/typer/src/ern_typecheck.erl:3770
   - Quote: "case ern_types:resolve(node_type(Left), Env#env.type_state) of"
   - Wrong: §4.8: "An operator is resolved once its definition is inferred". receive_guard/2 reads the left operand's type while the guard is inferred, so a mailbox type a later `send` fixes is still a variable, and the guard is refused as ordering `a`. The same receive placed after the send compiles.
   - Shown by:
     ```
     fn g() = {
         let me = self();
         receive { #(x, y) when x < y -> Unit };
         send(me, #(1, 2))
     }
     $ ern build guard_order.ern
     guard_order.ern:8:28: a `receive` guard orders only Int, Float, String, and Char, not a
     ```
   - Fix: check the ordered type of a receive guard at the definition's end, beside its deferred operator.

5. **The interface hash keeps type declarations' raw variable ids, so adding or reordering a type changes the hash of an equal interface and recompiles dependents**
   - Place: erl/typer/src/ern_interface.erl:58
   - Quote: "%% Quantified variables renumbered and maps as sorted lists, so that equal"
   - Wrong: canonical/2 renumbers the values' schemes but copies `types` as they are, and a #type_info's params and its constructors' schemes hold the checker's ids, which count the type parameters declared before. Two equal interfaces hash apart, and §11.1's "recompiled when the interface of a module it depends on has changed" fires with no change.
   - Shown by:
     ```
     h1/shape.ern: export type Shape(a) = Circle(a) | Square(a)
     h2/shape.ern: type Hidden(b) = Hidden(b)
                   export type Shape(a) = Circle(a) | Square(a)
     (each built in its own directory, so both are the namespace Shape)
     ern_interface:read/1 and hash/1: params [{tvar,27}] against [{tvar,28}]
     equal interfaces: false, equal hashes: false
     ```
   - Fix: renumber each #type_info's params and its constructors' schemes in canonical/2, as canonical_scheme/2 renumbers a value's.

6. **A requirement naming one member twice, `needs a.compare, a.compare`, is accepted and printed twice, where the report is silent**
   - Place: erl/typer/src/ern_typecheck.erl:1713
   - Quote: "|| #member{span = Span, member_of = Variable, name = Member} <- Members]."
   - Wrong: §4.9 says nothing of a member named twice, and CLAUDE.md asks for an error or a sentence where the report is silent, never silent acceptance. requirement_variables/4 keeps every repetition; the scheme carries both, and each use is supplied twice.
   - Shown by:
     ```
     > fn f(x : a, y : a) : Bool needs a.compare, a.compare = x < y
     > :t f
     f : (a, a) -> Bool needs a.compare, a.compare
     ```
   - Fix: refuse the second naming at its span with the first labelled, and add the sentence to §4.9.

7. **The prelude page prints the primitives' signatures from the table's text, without the `m+` mark §11.5 and `:type` print**
   - Place: erl/typer/src/ern_prelude.erl:503
   - Quote: "Values = [entry({function, dotted(QualifiedName), arity(Signature)},"
   - Wrong: §11.5 prints `send : (Address(a), a) -> Unit with m+` and says "`ern doc` prints restrictions the same way"; docs/0 writes each entry's type text as the table holds it, so the pages of `send`, `spawn`, `answer`, `kill`, `Address.call` and `Address.callForever` drop the process-only mark.
   - Shown by:
     ```
     $ printf ':doc send\n:t send\n' | ern shell
         send : (Address(a), a) -> Unit with m
     > send : (Address(a), a) -> Unit with m+
     ```
   - Fix: print each entry's signature from its scheme with ern_types:format_scheme/2, as `:browse Prelude` does.

8. **The prelude table lists `compare` for Int, Float and Char but not `String.compare`, which §9.6 lists beside them**
   - Place: erl/typer/src/ern_prelude.erl:463
   - Quote: "%% §9.6 operations required by the language, documented by their modules"
   - Wrong: `:browse Prelude` shows three of §9.6's four compares; lookup_global/4 gives `Int.compare` the referent {prelude, ...} and `String.compare` a #remote_declaration; values_test does not notice, since the string module's interface supplies the report's line.
   - Shown by:
     ```
     $ printf ':browse Prelude\n' | ern shell | grep compare
     Char.compare : (Char, Char) -> Ordering
     Float.compare : (Float, Float) -> Ordering
     Int.compare : (Int, Int) -> Ordering
     ```
   - Fix: add the `['String', compare]` entry, and have values_test hold the table itself to §9.6.

9. **A non-exhaustive match's missing case prints a named-field constructor bare, `Circle`, which is neither a value nor an accepted pattern**
   - Place: erl/typer/src/ern_exhaust.erl:267
   - Quote: "[] -> atom_to_list(Name);"
   - Wrong: §5.10 refuses "a bare `Circle`" as a pattern, and §5.6 makes a named constructor no value; a positional constructor prints as the pattern `Some(_)`, a named one with no field shown as `Circle`.
   - Shown by:
     ```
     type Shape = Circle(radius : Int) | Square(side : Int)
     fn area(s : Shape) : Int = match s { Square(side = n) -> n * n }
     witness.ern:4:5: match on Shape is not exhaustive; missing Circle
     ```
   - Fix: print `Circle()` where no field is shown.

10. **After a round of solve_deferred solves something, the undetermined-operator error names a later operator in the source than the first**
    - Place: erl/typer/src/ern_typecheck.erl:2096
    - Quote: "false -> unresolved(hd(Left), Env1)"
    - Wrong: each round's fold reverses the list, so after one round Left is in source order and after two in reverse; an unrelated selection that resolves moves the reported error from the first `+` to the second, against the comment "the first one reported".
    - Shown by:
      ```
      type Point = Point(x : Int, y : Int)
      fn f(p, a, b, c, d) = {
          let s = p.x;
          let u = a + b;
          let v = c + d;
          let q : Point = p;
          Unit
      }
      deferred1.ern:6:13: the operand type of `+` is not determined; annotate it
      (without `let s = p.x;`: deferred2.ern:4:13, the first `+`)
      ```
    - Fix: report the unresolved item with the earliest span.

11. **A fresh variable name past `z` is a nested list, so the 26th unnamed variable prints `a1` beside an annotation's own `a1`**
    - Place: erl/typer/src/ern_types.erl:706
    - Quote: "[lists:nth(Count rem 25 + 1, Letters)] ++ [integer_to_list(Count div 25) || Count >= 25]."
    - Wrong: the comprehension gives `[97, "1"]`, not "a1"; fresh_name/2 and format_type/3 compare it with the flat names in `taken`, neither matches the other, and two variables print alike, against §11.5's "avoiding the names in use".
    - Shown by:
      ```
      > fn f(x : a1, p1, p2, ..., p26) : a1 = x
      > :t f
      f : (a1, a!, b!, c!, ..., y!, z!, a1!) -> a1
      ```
    - Fix: return a flat string, the letter followed by integer_to_list(Count div 25) from 25 on.

#### Clarity

12. **ern_typecheck's header lists a post-check of "undetermined block bindings (§4.6)" that does not exist, and omits checks that do**
    - Place: erl/typer/src/ern_typecheck.erl:11
    - Quote: "%% rigidity of annotation variables, undetermined block bindings (§4.6),"
    - Wrong: §4.6 now lets a block binding's variable stay free, and post_checks/3 has no such check; it supplies requirements, runs ern_scope:order/1, holds_no_reply/4 and the pending restrictions, none of which the header names.
    - Shown by: none
    - Fix: list post_checks/3's steps in the order it runs them.

13. **format_result's comment says the parentheses make `with` read as the outer arrow's, the opposite of what they do**
    - Place: erl/typer/src/ern_types.erl:660
    - Quote: "%% effect, so `with` reads as belonging to the outer arrow (report §3.4)."
    - Wrong: the parentheses keep `with` inside the result's own arrow, `(Int) -> ((Int) -> Int with Never)`; §3.4 binds it to the nearest arrow already.
    - Shown by: none
    - Fix: "so that `with` is not read as the outer arrow's".

14. **The printing section's banner says a process-only variable prints unchanged, while format_type/3 marks it `+`**
    - Place: erl/typer/src/ern_types.erl:386
    - Quote: "%% that is process-only prints unchanged in effect position (its restriction"
    - Wrong: format_type/3 (line 635) prints `m+` for a process-only variable in no value position, as §11.5 says.
    - Shown by: none
    - Fix: say that one in no value position prints as `m+`.

15. **Three duplicate-declaration checks are unreachable, since declared_twice/1 has already refused every repeated type, constructor and value**
    - Place: erl/typer/src/ern_typecheck.erl:874
    - Quote: "check_unique_type(Span, Name, #env{local_types = LocalTypes}) ->"
    - Wrong: check/4 runs declared_twice/1 first; the unlabelled "is declared twice" of check_unique_type (874), check_unique_constructor (932) and register_value_name (1153) never fire, and a reader meets two wordings of one error.
    - Shown by:
      ```
      type T = A
      type U = A
      dup2.ern:2:10: constructor A is declared twice
      1 | type T = A
        |          - first declared here      (declared_twice's form, not line 932's)
      ```
    - Fix: remove the three, keeping check_unique_type's refusal of `Prelude`.

16. **format_error/1's clauses for `pure_vs_effect` and `mismatch` are dead, unify_message/5 handling both before it calls format_error**
    - Place: erl/typer/src/ern_types.erl:715
    - Quote: "format_error({pure_vs_effect, _}) ->"
    - Wrong: unify_message/5 is format_error's only caller, and matches both reasons first, so "or the reverse" and "types do not match" are never shown.
    - Shown by: none
    - Fix: remove the two clauses.

17. **by_first_segment/1 filters the first segments by the set of themselves, which keeps them all**
    - Place: erl/typer/src/ern_typecheck.erl:2791
    - Quote: "|| FieldName <- lists:filter(fun(FieldName) -> lists:member(FieldName, Firsts) end,"
    - Wrong: Firsts is the usort of the names Ordered holds, so the filter is a no-op and Firsts is otherwise unused.
    - Shown by: none
    - Fix: iterate over lists:uniq(Ordered) alone.

18. **selection/2 builds an `#e_var{}`, not a selection, for a path update's base**
    - Place: erl/typer/src/ern_typecheck.erl:2782
    - Quote: "selection(Name, Span) ->"
    - Wrong: the name says a field selection, the #e_selection{} update_set/4 builds beside it; the value is a reference to the name `$base`.
    - Shown by: none
    - Fix: write the #e_var{} in place, or name the function for a reference.

19. **`Owner` names a declared type in at_parameters, reach and cannot_derive, where the glossary keeps Owner for a resource's process**
    - Place: erl/typer/src/ern_typecheck.erl:694
    - Quote: "Owner, Params, Group, Env) ->"
    - Wrong: docs/style.md: "Owner: the process that opened a resource or was given it ... and nothing else; the type a member belongs to is its MemberOf." Here it is the type whose fields are read (694-734) and the type whose compare is derived (2451-2474).
    - Shown by: none
    - Fix: `Declaring` in at_parameters/5, `MemberOf` in reach/5 and cannot_derive/4.

20. **A requirement is called `needs` in format_needs/3, needs/1 and the variable `Needs`, where the glossary says Requirement**
    - Place: erl/typer/src/ern_types.erl:522
    - Quote: "-spec format_needs(type(), [{type(), atom()}], type_state()) -> string()."
    - Wrong: docs/style.md: "Requirement: §4.9's requirement ... Not `Needs`". format_needs/3 prints a type with its requirement, ern_typecheck:needs/1 (line 3838) gives a use's requirement, and `Needs` (ern_types.erl:597) holds its text.
    - Shown by: none
    - Fix: rename them for the requirement, as format_with_requirement/3, requirement_of/1 and RequirementText.

21. **ern_reply:value_variables/2 and ern_types:value_variables/2 share a name and differ in what they count and return**
    - Place: erl/typer/src/ern_reply.erl:104
    - Quote: "value_variables(Type, TypeState) ->"
    - Wrong: ern_types's (line 447) gives the ids in value positions, a type argument whose parameter is in no value position left out (§3.9); ern_reply's gives {tvar, Id} terms with repeats and counts every type argument, so `e` in `H(e)` is a value variable here and not there.
    - Shown by: none
    - Fix: use ern_types:value_variables/2 in restricted/4 and drop the local one.

22. **instantiate/2 repeats instance/2's fold, fresh_effect/1 is fresh/1 under a second name, and member_qualified_name/3 is session_member/3 under a second name**
    - Place: erl/typer/src/ern_types.erl:69
    - Quote: "fresh_effect(TypeState) -> fresh(TypeState, [])."
    - Wrong: one operation, two names or two bodies: instantiate/2 (346-352) is instance/2 (359-367) without the requirement; fresh_effect/1 makes the variable fresh/1 makes; ern_typecheck:member_qualified_name/3 (615-617) only calls session_member/3.
    - Shown by: none
    - Fix: define instantiate/2 by instance/2, call fresh/1 for effects, and export session_member/3 under its own name.

23. **value_positions/3 restates value_args/3's choice of the arguments in value positions, and in_value/3 restates it a third time**
    - Place: erl/typer/src/ern_types.erl:469
    - Quote: "#{QualifiedName := IsValue} -> [Arg || {Arg, true} <- lists:zip(Args, IsValue)];"
    - Wrong: the same case over the effect parameters stands at ern_types.erl:455-457 and 468-471, and over the fixpoint's map at ern_typecheck.erl:835-839.
    - Shown by: none
    - Fix: have value_positions/3 and in_value/3 call one helper.

24. **#type_info.params holds integers, atoms or type variables by kind of type and phase of checking, and a reader tests is_tuple to tell**
    - Place: erl/typer/include/ern_types.hrl:62
    - Quote: "%% params: one for each of the type's parameters, in order: a built-in"
    - Wrong: one field, three shapes; param_occurrences/2 (ern_typecheck.erl:806) filters on `is_tuple(Param)` to find the declared types whose constructors declared, and other readers use only its length.
    - Shown by: none
    - Fix: hold the type variables in params always, and the names a declaration writes in a field of their own.

25. **A requirement has two shapes, `{Id, Member}` in a scheme and `{Type, Member}` at an instance, which requirement_text/3 tells apart by is_integer**
    - Place: erl/typer/src/ern_types.erl:536
    - Quote: "{Members, _} = lists:mapfoldl(fun({Id, Member}, Acc) when is_integer(Id) ->"
    - Wrong: one concept goes through one printer in two representations, the shape decided by testing a term's type.
    - Shown by: none
    - Fix: turn a scheme's requirement into `{{tvar, Id}, Member}` before printing, so requirement_text/3 takes one shape.

26. **The variables a pattern binds are found by seven separate walks across the checker**
    - Place: erl/typer/src/ern_scope.erl:66
    - Quote: "%% The variables a pattern binds, each with where it is bound."
    - Wrong: ern_scope has pattern_variables/1 (spans, by a generic tuple walk) beside pattern_names/1 (ern_ast:pattern_bindings/1); ern_reply has bound/1; ern_typecheck has binds/2, check_pattern's BoundAt (4580), binds_at/2 (4618) and the walk of sizes_see_no_sibling/2 (4877), each deciding `as` and `or` again.
    - Shown by: none
    - Fix: one ern_ast function giving each bound name with its span and type, which the others read.

27. **Every failed check rebuilds the prelude, reading each standard library .beam again, to label hidden prelude names**
    - Place: erl/typer/src/ern_typecheck.erl:186
    - Quote: "{PreludeTypes, PreludeConstructors} = prelude_names(),"
    - Wrong: prelude_env/0 parses the prelude and reads every stdlib interface from disk per call; hidden_notes/2 calls it though check/4 has just built it, and prelude_names/0, prelude_values/0, prelude_constructor/1 and prelude_constructors/0 rebuild it on each shell query.
    - Shown by:
      ```
      timer:tc: prelude_env 37 ms (first), prelude_constructor 8 ms,
      check_string of a failing module 20 ms, of a passing one 13 ms
      ```
    - Fix: pass check/4's seeded environment to hidden_notes/2, and build the prelude once per run for the exported queries.

28. **The prelude's documentation names parameters its signatures never show, `v`, `mk`, `ms`, and uses `a` for both the address and the message type**
    - Place: erl/typer/src/ern_prelude.erl:304
    - Quote: "Puts `v` in the mailbox of the process at `a`, and returns at once."
    - Wrong: a prelude entry has a type and no parameter names, so the page shows `send : (Address(a), a) -> Unit with m` and then speaks of `v`, and of `a` as the address; Address.call's `mk(r)` names what §6.6 calls `request`.
    - Shown by:
      ```
      > :doc Address.call
          Address.call : (Address(m), (Reply(a)) -> m, Int) -> Optional(a) with n
      Sends the request `mk(r)`, with a fresh reply `r`, and waits up to `ms`
      ```
    - Fix: give the entries parameter names shown in the signature as a declaration's are, `request` among them, or refer to the arguments by position.

29. **process_only/0 says it lists the primitives whose effect variables are process-only, but leaves out `self` and includes `monitor` and `spawnMonitored`, which need no listing**
    - Place: erl/typer/src/ern_prelude.erl:276
    - Quote: "%% The primitives among values/0 whose effect variables are process-only"
    - Wrong: signature_scheme/3 makes an effect variable that occurs in a value position process-only anyway, as `self`'s, `monitor`'s and `spawnMonitored`'s do; the list is neither every process-only primitive nor only those that need it.
    - Shown by: none
    - Fix: list only those whose effect variable occurs in no value position, and say so.

30. **Test comments cite entries of findings.md, `C2-3`, `R-6`, `P1-1`, though no findings.md is in the tree**
    - Place: erl/typer/test/ern_typecheck_tests.erl:691
    - Quote: "%% checker crashed looking for two variables (findings.md's C2-3)"
    - Wrong: docs/findings.md exists only while a review's findings are open; ten comments in this file and one in ern_prelude_tests.erl:186 now point at nothing.
    - Shown by: none
    - Fix: say in words what each regression was.

31. **warts_audit_test and smaller_silences_test are named after the audits that wrote them, and each tests several behaviours**
    - Place: erl/typer/test/ern_typecheck_tests.erl:1559
    - Quote: "warts_audit_test() ->"
    - Wrong: docs/style.md: a test "tests one behaviour, is named after it". warts_audit_test checks discarded statements, `_` on replies, tuple parameters, a field matched twice, foreign implementation names (again in foreign_implementation_name_test), foreign effects and lambda annotation variables; smaller_silences_test (1486) covers Bool coverage, pipes and selectors.
    - Shown by: none
    - Fix: split each into tests named for their behaviour, dropping the repeated implementation-name cases.

32. **declared_scheme/3 takes the environment first, and set_scope/4 and set_effect_params/2 the type state first, against their modules' state-last order**
    - Place: erl/typer/src/ern_typecheck.erl:3388
    - Quote: "-spec declared_scheme(env(), [atom()], atom()) -> {ok, #scheme{}} | error."
    - Wrong: every other export of ern_typecheck takes env() last, and ern_types's functions take type_state() last (ern_types.erl:486, 493 do not), which a caller must remember function by function.
    - Shown by: none
    - Fix: move the state argument last.

33. **ern_exhaust prints literal and bitstring witnesses and simplifies `{positional, none}`, none of which can occur**
    - Place: erl/typer/src/ern_exhaust.erl:250
    - Quote: "show({con, {lit, Value}, []}, _) ->"
    - Wrong: complete/2 answers `any` for literal and bitstring keys, so a witness holds `_` there, never a literal or `bits`; infer_pattern refuses a positional constructor without its pattern, so the `{positional, none}` of simplify/2 (line 137) is never met. The literal clause would print Erlang syntax.
    - Shown by: none
    - Fix: remove the three clauses.

34. **derived_name/1 restates declaration_text/1, and needer_name/2's four declaration clauses each compute local_name/2**
    - Place: erl/typer/src/ern_typecheck.erl:2914
    - Quote: "derived_name(#env{definition = {_, Name}}) -> Name."
    - Wrong: derived_name/1 is declaration_text/1 without its fallback; needer_name/2 (2908-2912) splits own and remote declarations, with and without member_of, though local_name/2 handles `undefined` itself.
    - Shown by: none
    - Fix: call declaration_text/1, and write needer_name/2 as two clauses over local_name/2.

35. **ern_bitspec names a constant size `Bits`, though for a `bytes` segment it counts octets**
    - Place: erl/typer/src/ern_bitspec.erl:52
    - Quote: "spec_fold({size, #e_literal{kind = int, value = Bits}}, Spec) -> once(size, {const, Bits}, Spec);"
    - Wrong: §5.11: a size counts octets for `bytes`; the module's own unit (line 20) says so, but `{const, Bits}` here, at line 69 and in the header calls the count bits.
    - Shown by: none
    - Fix: name it `Count`, the unit saying what it counts.

### C, part 3, the emitter; its 1 to 31 are C72 to C102

#### Defects

1. **A local fn that reads a local binding, or calls a local fn, named like a top-level declaration crashes the emitter.**
   - Place: erl/emitter/src/ern_emitter.erl:1593
   - Quote: "not is_map_key({undefined, FreeName}, TopNames)"
   - Wrong: `declared_local` drops every free name that is also a top-level name, even where a parameter, a `let` or a local fn of the scope shadows it (§4.2's lookup order, §5.4). The lifted function then lacks that capture. Reading such a variable fails a badmatch in `name_form/7`, line 649. Calling a shadowing local fn leaves its own captures unbound in the emitted Erlang.
   - Shown by:
     ```
     $ cat main.ern                      # in C3/t5
     fn helper() : Int = 1
     export fn main() : Unit with Never = {
         let helper = 5;
         fn f() : Int = helper;
         Io.println(Int.toString(f()))
     }
     $ ern build main.ern
     ern: internal error: exception error: no match of right hand side value
                      #{f => {local_fn,'f$1',[],[],[],[],#{helper => 'Helper_2'}}}
       in function  ern_emitter:name_form/7 (ern_emitter.erl:649)
     $ ern build second.ern   # a local `fn helper() = base` called from a local f
     ern: internal error: exception error: {emitted_erlang_does_not_compile,
                          [{[],[{0,erl_lint,{unbound_var,'Base_3'}}]}]}
     ```
   - Fix: count a free name as top-level only when no parameter, variable, block `let` or local fn in scope binds it, or read the checker's referent (`var`) instead.

2. **A bitstring pattern's size that names an outer variable, which the same pattern also binds elsewhere, crashes the emitter.**
   - Place: erl/emitter/src/ern_emitter.erl:1896-1907, with `size_form/2` at 1947
   - Quote: "{SizeForm, Acc1} = size_form(Spec, Acc)," (§5.11: "A variable bound elsewhere in the same pattern is not in scope in its sizes.")
   - Wrong: patterns bind left to right into one context, so the size reads the variable the enclosing tuple just bound, not the outer one §5.11 names. Erlang then refuses it, because a tuple's pattern variable cannot size a segment.
   - Shown by:
     ```
     $ cat main.ern                      # in C3/t7
     fn pick(n : Int, pair : #(Int, Bytes)) : Int = match pair {
         #(n, <<x:size(n)>>) -> x + n
       | _ -> 0
     }
     export fn main() : Unit with Never = Io.println(Int.toString(pick(8, #(16, <<5>>))))
     $ ern build main.ern
     ern: internal error: exception error: {emitted_erlang_does_not_compile,
                          [{[],[{{2,19},erl_lint,{unbound_var,'N_3','N_1'}}]}]}
     ```
     Expected: `21`.
   - Fix: compile each bitstring's sizes against the variables in scope before the pattern plus those its own earlier segments bind.

3. **A bitstring construction evaluates a segment's size expression twice, so the size's effects happen twice.**
   - Place: erl/emitter/src/ern_emitter.erl:393-395 and 1955-1961
   - Quote: "call_remote(ern_bits, int, [ValueForm, bits_form(Spec, SizeForm), erl_syntax:atom(Sign)]);" beside "erl_syntax:binary_field(Checked, SizeForm, type_specs(Spec))"
   - Wrong: `SizeForm` is placed once in the width check and again as the field's size. §5.1 is strict evaluation, and §5.11 evaluates the segments left to right, each expression once. A `bytes` segment with a size does the same.
   - Shown by:
     ```
     $ cat main.ern                      # in C3/t3
     fn width() : Int with m = { Io.println("width"); 16 }
     export fn main() : Unit with Never = {
         let b = <<5:size(width())>>;
         Io.println(Io.show(b))
     }
     $ ern build main.ern && ern run main.erc
     width
     width
     <<0, 5>>
     ```
   - Fix: bind a size that is not a literal or a variable to a fresh variable before the binary, as `float_operation/5` binds its operands.

4. **A spawn site and an initializer's fault name a function or `let` called `module_info` or `record_info` with the host's `$`.**
   - Place: erl/emitter/src/ern_emitter.erl:1065 (`site/2`), fed by 251, 264 and 346
   - Quote: "text_site([ern_namespace:text(Namespace ++ [Function]), \":\", integer_to_list(Line)]);"
   - Wrong: `function_name` in the context holds `function_atom/1`'s Erlang name, but `site/2` prints it as the Ernest name. §6.9 and §8.5 call for the declaration's qualified name. `function_atom/1`'s comment says the collision is "nothing the program or the report sees".
   - Shown by:
     ```
     $ ern run main.erc     # C3/t1: fn module_info spawns a process that faults
     ... Main.module_info$:4 faulted: x
     Main.module_info$:4
     $ ern run init.erc     # C3/t1: let record_info = 1 / zero()
     ... Init.record_info$:3 faulted: division by zero
     ```
   - Fix: keep the Ernest name, `shown_name`, in the context for `site/2`, apart from the Erlang function name.

5. **A list literal of about a thousand calls fails in the host's compiler, which `$tests` already works around.**
   - Place: erl/emitter/src/ern_emitter.erl:381-383 (`e_list`); compare 138-140
   - Quote: "a list of every call at once passes the host's limit of live values"
   - Wrong: the emitter knows the host's limit and builds `'$tests'/0` a call at a time. A program's own list literal, and likewise a long tuple or argument list, is emitted whole and refused by `beam_validator`. That reaches the user as an internal error.
   - Shown by:
     ```
     $ ern build big.ern     # C3/t7: List.size([f(1), f(2), ..., f(1100), f(0)])
     ern: internal error: exception error: {emitted_erlang_does_not_compile,
          [{"ern@big",[{1,beam_validator,{{ern@big,main,0},{{call,1,{f,2}},9,limit}}}]}]}
     ```
   - Fix: emit a list literal whose elements call as `tests_function/1` builds its list, from the last, one element bound at a time.

6. **Identifiers of the 255 characters §2.3 allows crash the emitter, whose Erlang names add a suffix past the host's atom limit.**
   - Place: erl/emitter/src/ern_emitter.erl:2010, 246, 2018
   - Quote: "list_to_atom(Base ++ \"_\" ++ integer_to_list(Number))."
   - Wrong: §2.3 says "An identifier, a type name, and each segment of a qualified name is at most 255 characters long". A variable gets `_N` added, a lifted local fn `$N`, and a member `T.` in front. Each then passes 255, and `list_to_atom` raises `system_limit`.
   - Shown by:
     ```
     $ ern build long.ern       # C3/t5: let aaa…a (255 a's) = 1
     ern: internal error: exception error: a system limit has been reached
       in function  list_to_atom/1 ... in call from ern_emitter:erlang_variable/2
     $ ern build longtype.ern   # type Taaa…a (255 chars) derives compare
     ... list_to_atom("Taaa…a.compare") in call from ern_emitter:function_name/2
     ```
   - Fix: give variables and lifted functions names that are numbered only, and either fit member names in 255 or lower §2.3's limit for type names.

7. **The Docs chunk keys a function with a requirement by its written arity, not by the arity the module exports.**
   - Place: erl/emitter/src/ern_docs.erl:60-67
   - Quote: "everything else is a function of the module, under the name and arity the emission gives it."
   - Wrong: `doc_key/1` uses `length(Params)`, but the emission adds one parameter per member (`export/1`, ern_emitter.erl:225-227). The host's EEP 48 tools, which §11.1 says read the chunk, look up `unique/2` and find `unique/1`. The comment says otherwise.
   - Shown by:
     ```
     # C3/t6/uniq.ern: export fn unique(list : List(a)) : List(a) needs a.compare; a derived Pair.compare
     docs keys:  {function,unique,1}  {function,'Pair.compare',2}
     exports:    {unique,2}           {'Pair.compare',4}
     ```
   - Fix: add `length(Requirement)` to the key's arity, as `export/1` does.

8. **`ern doc` drops the parentheses around a function-typed result under `with`, so the documented type is a different type.**
   - Place: erl/emitter/src/ern_docs.erl:187-189
   - Quote: "[\"(\", lists:join(\", \", [syntax_text(Param) || Param <- Params]), \") -> \", syntax_text(Result),"
   - Wrong: by §3.4, `with` binds to the nearest arrow. `(Int) -> ((Int) -> Int) with Msg` comes out as `(Int) -> (Int) -> Int with Msg`, which is a pure function returning one with mailbox `Msg`. The fault reaches both a type's fields and a foreign fn's signature in the chunk and on the page.
   - Shown by:
     ```
     $ ern doc shapes.ern     # C3/t6
     type Holder = Holder(make : (Int) -> (Int) -> Int with Msg)      # declared (Int) -> ((Int) -> Int) with Msg
     Shapes.adder : (Int) -> (Int) -> Int with m                      # declared : ((Int) -> Int) with m
     ```
   - Fix: parenthesize a `#t_fn` result where the enclosing function type has an effect.

9. **`ern doc` prints a foreign fn's type without the restrictions §4.7 gives it and §11.5 prints.**
   - Place: erl/emitter/src/ern_docs.erl:135-140
   - Quote: "text([Prefix, atom_to_list(shown_name(MemberOf, Name)), \" : \", syntax_text(Type)]);"
   - Wrong: a foreign fn's signature is its written annotation, while a `fn`'s is its formatted scheme. So `a!`, which §4.7 puts on each variable a parameter holds, is missing, and so is `m+` for its own effect. §11.5 says "`ern doc` prints restrictions the same way".
   - Shown by:
     ```
     $ ern doc ffi.ern     # C3/t6: a foreign fn first, and a fn firstOf of the same type calling it
     Ffi.first : (List(a)) -> a with m
     Ffi.firstOf : (List(a!)) -> a! with m+
     ```
   - Fix: format the foreign fn's `scheme`, as the `fn_declaration` clause does, which also cures finding 8 for foreign fns.

10. **The emitter meets §5.1's left-to-right order only through the Erlang compiler's actual order, which Erlang's reference manual leaves unspecified.**
    - Place: erl/emitter/src/ern_emitter.erl:826-829, 378-383, 452-462 (calls, tuples, lists, binops)
    - Quote: "{CalleeForm, Context1} = expr(Callee, Context), {ArgForms, Context2} = exprs(Args, Context1)," and from the manual, expressions.md: "`Expr1` and `Expr2` ... are evaluated first — in any order"
    - Wrong: where order matters the emitter binds to variables explicitly: pipes, float operations, fields out of order. Elsewhere it hands Erlang an application, tuple, list or operator, and no comment says that order rests on the host compiler. Tests pin calls and pipes only, not operators, lists or tuples.
    - Shown by: none. Today's compiler does keep the order: C3/t8/main.ern prints `ab`/`abc` for each form.
    - Fix: state the reliance in the module comment, and test each form's order, or bind operands where the host promises none.

11. **A descriptor's shape, shared by four modules, has no `-type`, and `describe/3` is specified as `term()`.**
    - Place: erl/emitter/src/ern_descriptor.erl:18
    - Quote: "-spec describe(term(), ern_typecheck:env(), [atom()]) -> term()."
    - Wrong: docs/style.md says "a type shared between modules is a `-type` of its owner". The shape is made here, rebuilt by `built_descriptor/1` and matched by `plain/1` and `crosses/1` in ern_emitter. ern_boundary and ern_io read it. One tag, `'fun'`, names two different 6-tuples, one before building and one after (ern_descriptor.erl:40, ern_emitter.erl:1376).
    - Shown by: none
    - Fix: declare `-type descriptor()` in ern_descriptor, and give the built `'fun'` form a tag of its own, or make it a record.

#### Clarity

12. **Prefix `-` on a user type has an unreachable clause, and a user type's operators take two paths that duplicate `ordered/2`.**
    - Place: erl/emitter/src/ern_emitter.erl:1152-1153, 1106-1120, 1169-1179, 444-445
    - Quote: "negate({tcon, QualifiedName, _}, Form, Context) when length(QualifiedName) > 1 ->"
    - Wrong: the checker gives every negation on a user type a `#known_member{}` (ern_typecheck `operator_member`/`supply`), so `member = undefined` never reaches a user type here. A binop whose known member has no supplies goes to `binop/5`, which writes out the Less/Greater table again. One with supplies goes to `member_applied/3` plus `ordered/2`.
    - Shown by: none
    - Fix: send every known or required member through `member_applied/3` and `ordered/2`, and remove the user-type clauses of `binop/5` and `negate/3`.

13. **A function crossing into foreign code is exposed two ways: `{callback, Make}` at top level, the `'fun'` descriptor's exposer when nested.**
    - Place: erl/emitter/src/ern_emitter.erl:1278-1280, 1314-1317, 1345-1355
    - Quote: "exposed({{tfn, Params, _, _}, Arg}, Context) -> {DescriptorForm, Context1} = callback_descriptor_form(Params, Context),"
    - Wrong: `ern_boundary:expose/3` already exposes a top-level `'fun'` descriptor (ern_boundary.erl:294). The callback form, its builder and its `$type_N` functions are a second way to do one rule (§8.4).
    - Shown by: none
    - Fix: let `exposed/2` treat a function type like any type that `crosses/1`, and remove `callback_descriptor_form/2` and the `callback` clauses.

14. **ern_descriptor copies `ern_types:replace_variables/2` as `substitute/2`, the glossary's word for applying a Substitution, and copies ern_emitter's `text_binary/3`.**
    - Place: erl/emitter/src/ern_descriptor.erl:133-144; erl/emitter/src/ern_emitter.erl:1398-1399
    - Quote: "substitute({tvar, Id} = Type, Substitution) -> maps:get(Id, Substitution, Type);"
    - Wrong: the function is clause for clause `ern_types:replace_variables/2`. It works on a map of replacements, yet it is named `substitute` and its argument `Substitution`. The glossary keeps both words for the type state's substitution. `text_binary/3` appears in both modules with the same body.
    - Shown by: none
    - Fix: call `ern_types:replace_variables/2`, and keep `text_binary` in one module.

15. **`ern_descriptor:descriptor/3` returns and threads `Seen`, which never changes on the way back.**
    - Place: erl/emitter/src/ern_descriptor.erl:25-96, 118-119
    - Quote: "{{abstract, Descriptor}, Seen};"
    - Wrong: each clause returns either the `Seen` it was given or what its children returned, which is also that `Seen`. Seen only grows on the way down, as the comment says ("a sibling is described in full"). The pairs and the `mapfoldl` carry nothing.
    - Shown by: none
    - Fix: make `descriptor/3` return the descriptor alone, and `descriptors/3` a `map`.

16. **`#emit_context.function_name` holds the Erlang function's name yet is read as the Ernest one, and the record's comment skips six fields.**
    - Place: erl/emitter/src/ern_emitter.erl:19-35
    - Quote: "-record(emit_context, {namespace, erlang_module, env, function_name, variables = #{},"
    - Wrong: the name does not say which name it holds, which is the root of finding 4. The comment documents `variables` through `members` but not `namespace`, `erlang_module`, `env`, `function_name`, `counter` or `standard`. `standard` is explained only in `compile/5`'s comment.
    - Shown by: none
    - Fix: rename the field for what it holds, add the Ernest name beside it, and document every field where the record stands.

17. **`#local_fn{own, extra}` and `instances/2` do not say what they hold: free Ernest names, Erlang variables, and the variables a lifted function takes first.**
    - Place: erl/emitter/src/ern_emitter.erl:38, 1522-1526, 1622
    - Quote: "-record(local_fn, {lifted_name, own, extra, references, members = [], snapshot = pending})."
    - Wrong: `own` holds Ernest names, while `extra` and `members` hold Erlang variables. `instances` names the captured variables a closure and a lifted head take, a meaning nothing in the code or §5.4 gives the word. The fields are documented 1,480 lines below the record.
    - Shown by: none
    - Fix: rename them for their contents, for example `captured_names`, `enclosing_variables` and `captured_variables/2`, and document them at the record.

18. **Several yes-or-no functions read as nouns or verbs: `open/1`, `plain/1`, `erlang_guard/3`, `guard_operand/2`.**
    - Place: erl/emitter/src/ern_emitter.erl:1966, 1263, 1827, 1846
    - Quote: "open(#{size := {expr, _}, unit := 1}) -> true;"
    - Wrong: docs/style.md says "a yes-or-no reads as the question". `open(Spec)` reads as an action, and `erlang_guard(Guard, …)` as making a guard.
    - Shown by: none
    - Fix: `is_open/1` (or `leaves_count_open/1`), `is_plain/1`, `is_erlang_guard/3`, `is_guard_operand/2`.

19. **`Named` names two things in neighbouring functions: the type variables the parameters name, and the type a fault's text names.**
    - Place: erl/emitter/src/ern_emitter.erl:329 and 1225
    - Quote: "Named = lists:append([type_variables(ParamType) || ParamType <- ParamTypes])," / "check_form(Type, Named, Form, Prefix, Context) ->"
    - Wrong: `foreign_return/4` passes `ResultType` as `check_form`'s `Named`, right after binding its own `Named` to something else.
    - Shown by: none
    - Fix: `ParamVariables` in `foreign_return/4`, and `Shown` or `NamedType` in `check_form/5`.

20. **The variables the emitter makes reuse one letter for several concepts, and name the scrutinee two ways, in `--emit-erl` output meant for reading.**
    - Place: erl/emitter/src/ern_emitter.erl:458, 1433, 1504 ("F"); 689, 885, 1683 ("S"); 493 ("Scrutinee"); 310, 1554 ("E")
    - Quote: "{[ScrutineeName], Context1} = fresh_variables(1, \"S\", Context),"
    - Wrong: `F_n` is a float operand, a selected field and a field's value. `S_n` is a supplied member and the scrutinee, which elsewhere is `Scrutinee_n`. `E_n` is the parts of an exception and the `Left` of `<-`. §11.1 says `--emit-erl` writes the source "for reading".
    - Shown by: none
    - Fix: one prefix per concept, a whole word: `Operand`, `Field`, `Supplied`, `Scrutinee`, `Class`/`Error`/`Trace`, `Left`.

21. **Functions thread `Context` through four numbered steps, and one numbers from `Context0`, against docs/style.md's numbering rule.**
    - Place: erl/emitter/src/ern_emitter.erl:808-809; also 248-261, 412-424, 528-550, 683-696, 1548-1570
    - Quote: "{WrittenForms, Context0} = exprs(Args, Context),"
    - Wrong: docs/style.md says "A value changing through a function is numbered, `Env1`, `Env2` … past two steps the function is split". Here it reaches `Context4`, and one function starts at `Context0`.
    - Shown by: none
    - Fix: number from 1, and split the longer threads into named steps (the supplies, the pattern, the body).

22. **`supply_form/2` makes up a span and a function type, with a wrong result for `compare`, only to reuse `prelude_value/4`.**
    - Place: erl/emitter/src/ern_emitter.erl:869-875
    - Quote: "prelude_value({1, 1, {1, 1}}, QualifiedName ++ [Member], {tfn, lists:duplicate(member_arity(Member), Type), pure, Type}, Context);"
    - Wrong: `compare` answers `Ordering`, not the type. `List(a)` is given as `{tcon, ['List'], []}`. The span is invented. It works only because `prelude_value` reads nothing but the arity and the first parameter.
    - Shown by: none
    - Fix: give the prelude member's value from its qualified name and arity in a function of its own.

23. **`arity_of/2`'s failure text names a local function, though three other callers reach it.**
    - Place: erl/emitter/src/ern_emitter.erl:725
    - Quote: "fail(Span, \"a local function used as a value must have a function type\")."
    - Wrong: it is also called for a declaration with a requirement taken as a value (684), for `Address.call` as a value (1012), and for a prelude function as a value (1034).
    - Shown by: none
    - Fix: "a function used as a value must have a function type".

24. **`statements/3` catches a block that ends in `let p = e` but not in `let p <- e`, which crashes with `function_clause`.**
    - Place: erl/emitter/src/ern_emitter.erl:1534-1538
    - Quote: "statements([#binding{span = Span, operator = '='}], _Context, _Acc) ->"
    - Wrong: the guard against what the checker refuses covers half the case. A last `<-` binding falls to `expr/2`, which has no `#binding{}` clause.
    - Shown by: none
    - Fix: match `#binding{}` whatever its operator in the failing clause.

25. **`ern_emitter:erlang_module/1` only wraps `ern_namespace:erlang_module/1`, so one function has two names, with 31 callers on the wrapper.**
    - Place: erl/emitter/src/ern_emitter.erl:201-204
    - Quote: "erlang_module(Namespace) -> ern_namespace:erlang_module(Namespace)."
    - Wrong: the emitter is not this function's owner. Callers in cli, shell and tests reach it through either module.
    - Shown by: none
    - Fix: call `ern_namespace:erlang_module/1` everywhere, and drop the export.

26. **Two comments no longer hold: the module header omits the Docs chunk, and `binop/5`'s counts Int beside "the four ordered prelude types".**
    - Place: erl/emitter/src/ern_emitter.erl:1-4, 1080-1081
    - Quote: "then to a BEAM module with the interface as the chunk \"ErnI\"" / "Int and the four ordered prelude types are Erlang's operators"
    - Wrong: `compile/5` also writes `ern_docs`' chunk. The four ordered prelude types of §9.6 are Int, Float, String and Char, so Int is one of them.
    - Shown by: none
    - Fix: name both chunks in the header, and write "the four ordered prelude types, Int, Float, String and Char".

27. **`ern_emitter_tests` holds the runtime's and the library's tests under the emitter's name.**
    - Place: erl/emitter/test/ern_emitter_tests.erl:2390-2845 (Supervisor, E.22), 2846-3110 (Os, E.23), 3122-3160 (the reaper), 3297-3600 (Tcp, E.18), 600-1100 (restarts §6.9, deadlock §8.6, the terminal §8.2)
    - Quote: "%% Report Appendix E.23: Os.run, each program run through ern_exec."
    - Wrong: docs/style.md says "A test module is `<module>_tests`, or names what it tests". Of the module's 177 tests, the 56 between lines 2390 and 3640 alone exercise ern_rt and the standard library, not the emission. A reader looking for the supervisor's tests would not open the emitter's file.
    - Shown by: none
    - Fix: move them into modules named for what they test, for example `ern_supervisor_tests` and `ern_os_tests`, sharing the `run/3` helper.

28. **Test comments cite `findings.md`, which no longer exists, by its review-local ids, and one cites the plan where a section belongs.**
    - Place: erl/emitter/test/ern_emitter_tests.erl:773, 1658, 3204, 3348, 3368-3369, 3407, 3463, 3479, 3505, 3535, 3771
    - Quote: "the test could not do before (findings.md's C38)" / "%% Plan, MVP 2.7, \"Atoms, counted\""
    - Wrong: docs/findings.md is absent from the tree. Ids like C38, C2-7, K-13 and S-H belonged to past reviews and repeat between them. docs/style.md asks for "`%% report §x.y`, or a document's path" above a test.
    - Shown by: `ls docs/findings.md` gives no such file
    - Fix: state what was wrong in words, and cite the report section, `docs/memory.md` for the atoms test.

29. **Three test comments describe what the code no longer does or the test does not test.**
    - Place: erl/emitter/test/ern_emitter_tests.erl:1307-1309, 3796-3799, 3387-3391
    - Quote: "in a receive guard the ordering is a call, a type error by §5.9" / "the emitter orders the top-level lets by what they reference" / "until a foreign function takes its caller's description of the type (MVP 2.99b's item 13)"
    - Wrong: `user_operators_test` has no receive guard, and the rule is §6.3's. The emitter reads the checker's `let_order` and builds no graph, as `initialization_order_test` says. §8.4 states the type-variable rule without an "until".
    - Shown by: none
    - Fix: remove the receive-guard clause, describe the order as read from the checker, and drop the "until".

30. **`prelude_targets_test` maps every two-part operator to a dummy target, so the remote calls the emitter makes for them go unchecked.**
    - Place: erl/emitter/test/ern_emitter_tests.erl:2335-2359
    - Quote: "%% The emission of a prelude name, as ern_emitter makes it; inline operators have no target."
    - Wrong: `Float.+`, `Float.-`, `Float.*`, `Float./` and `Float.negate` compile to `ern@float` functions, and `List.<>` and `Path.<>` to `ern@list`/`ern@path` (ern_emitter.erl:974-976, 1037-1045, 1095-1099). The test sends all of them to `{erlang, is_atom, 1}`. It also restates the emitter's table instead of reading it.
    - Shown by: none
    - Fix: treat only `Int`'s arithmetic and negate and the `String`/`Bytes` `<>` as inline, and check the rest against their modules.

31. **The test module holds a raw newline inside a string, an export list out of source order, and a macro between its includes.**
    - Place: erl/emitter/test/ern_emitter_tests.erl:683, 3-5, 13-21
    - Quote: "run(\"type M = M | Get(reply : Reply(Int))" (the line ends inside the string)
    - Wrong: every other program text writes `\n`. docs/style.md says "One `-export` list at the top, in the order the functions appear", but `opt` is exported before `funs` and `ask_*` before `call_nested_*`, against source order. `-define(UP, …)` splits the `-include_lib` lines.
    - Shown by: none
    - Fix: write `\n"` and close the literal, reorder the export list, and put the define after the includes.

### C, part 4, the runtime with its helper in C; its 1 to 33 are C103 to C135

#### Defects

1. **`Fs.removeAll` given a link to a directory with a trailing slash follows the link, empties its target, then fails: E.17's "a link is removed, not followed" is broken.**
   - Place: erl/runtime/c_src/ern_exec.c:440-455 (`remove_all`), report Appendix E.17
   - Quote: "int root = open(path, DIRECTORY_ONLY);"
   - Wrong: `O_NOFOLLOW` acts on the last component only, and a trailing `/` makes the host resolve the link, so `open` succeeds on the link's target; `empty_directory` deletes everything in it, then `rmdir("link/")` fails with ENOTDIR. The caller gets an error and has lost the target's contents.
   - Shown by:
     ```
     $ mkdir target; echo precious > target/keep.txt; ln -s target link
     Io.show(Fs.removeAll(Path("link/"), 1000))   // Left(Other("not a directory"))
     Io.show(Fs.list(Path("target"), 1000))       // Right([])  -- keep.txt deleted, link still there
     ```
   - Fix: Strip trailing slashes and open the last component with `openat(parent, name, DIRECTORY_ONLY)`, so that it is never resolved through a link.

2. **A fault sent as an exit signal kills a restarting process instead of restarting it: a mismatched foreign message, or a subscription while the shell holds the terminal.**
   - Place: erl/runtime/src/ern_boundary.erl:354; erl/runtime/src/ern_tty.erl:65, 121; report §6.9, §7.4, §8.4
   - Quote: "false -> exit(ern_rt:process_of(Behind), {ern, fault, Cause})"
   - Wrong: §8.4 says such a breach "faults the receiving Ernest process", and §6.9 says that when `f` faults, `restarting` runs it again. An exit signal is not an exception, so neither `restarts/4` nor `run/1` catches it. The process dies with `Fault(cause)` while restarts remain. The tty's `{taken, Cause}` case refuses through the Reply and so is restartable, while its shell-holds case is not.
   - Shown by:
     ```
     %% erl, with erl/runtime/ebin and build/stdlib on the path: a restarting child with
     %% RestartLimit(5, 60000), its address exposed at String, the proxy sent 42
     [{started,'First'},
      {down,{'Down',<0.93.0>,{'Fault',<<"message does not match String">>},<<"M.child:1">>}}]
     ```
   - Fix: Refuse the shell-holds subscription through its Reply as the `taken` case does. Deliver the proxy's mismatch as a priority message that every receive raises, as it takes `'$ern_restart'`.

3. **`Os.start` with an empty program name, and `Fs.removeAll` on an empty path, fault "the runtime's helper ern_exec failed" instead of answering `Left(NotFound)`.**
   - Place: erl/runtime/c_src/ern_exec.c:279, 469; report Appendix E.17, E.23
   - Quote: "if (length < 3)\n        return NULL;" and "if (length < 2)\n        return 1;"
   - Wrong: The helper takes the frame `c\0`, or `p` alone, for a malformed frame and exits 1, so the runtime reports its own failure. E.23 says a program that is not found answers `Left(NotFound)`, and `Fs.remove(Path(""))` does answer that.
   - Shown by:
     ```
     Io.show(Os.start(Os.Command(program = "", arguments = [], input = <<>>)))
     // EmptyNames.main faulted: the runtime's helper ern_exec failed
     Io.show(Fs.remove(Path(""), 1000))      // Left(NotFound)
     Io.show(Fs.removeAll(Path(""), 1000))
     // EmptyPath.main faulted: the runtime's helper ern_exec failed
     ```
   - Fix: Accept an empty name in both jobs and let `execvp` or `open` answer ENOENT, or answer `NotFound` in Erlang before starting the helper.

4. **Foreign code monitoring a process can see exit terms beyond §8.4's four: `{ern, fault, Cause, Trace}`, `{ern, code_unloaded}` and `{ern, closed}`.**
   - Place: erl/runtime/src/ern_rt.erl:1011-1012, 405; erl/runtime/src/ern_tcp.erl:203, 290; report §8.4
   - Quote: "{ern, fault, format("~p:~p", [Class, Error]), trace(Stack)}"
   - Wrong: §8.4 says a process "that faulted [exits] `{ern, fault, Text}`" and lists four terms as "the `Reason` values of §9.3 as the host sees them". A runtime failure or a foreign raise exits with a 4-tuple, a process whose code was unloaded exits with `{ern, code_unloaded}`, and a closed socket or listener, whose Down says `Returned`, exits with `{ern, closed}` rather than `normal`.
   - Shown by:
     ```
     %% erlang:monitor on an ern_rt-spawned process that calls binary_to_integer on "zero"
     {ern,fault,<<"error:badarg">>,<<"    erlang:b"...>>}
     ```
   - Fix: Either list these terms in §8.4, or keep the trace beside the exit, in the reaper's report, and exit with `{ern, fault, Cause}`.

5. **The terminal's settings are read by `sh -c "stty -g"`, which finds `sh` and `stty` through PATH. That contradicts the rule stty/1 states, that only the system's stty runs.**
   - Place: erl/runtime/src/ern_tty.erl:348-358, against 326-327
   - Quote: "[{args, ["-c", "stty -g >&4"]}, nouse_stdio, exit_status,"
   - Wrong: The comment on stty/1 says it is "the system's own stty, not the first that PATH names, which could be any program in any directory the PATH lists". Yet the first subscription runs whatever `stty` PATH names, and its output is later passed back to the system stty.
   - Shown by: none
   - Fix: Run `system_stty()` here as well, for instance `/bin/sh -c 'exec "$0" -g >&4' SttyPath`, and require it, as stty/1 does.

6. **E.18 omits writes already handed to the writer at `Tcp.close`; their answer depends on the writer draining its queue before the link's exit signal arrives.**
   - Place: erl/runtime/src/ern_tcp.erl:285-290, 243-255; report Appendix E.18
   - Quote: "gen_tcp:close(Socket),\n            Writer ! stop,\n            %% report Appendix E.18: a call after the close faults its caller\n            exit({ern, closed});"
   - Wrong: E.18 says close answers "each read or accept ... it holds waiting with `Left(Closed)`", and says nothing of writes. The writer is linked to the socket, and `exit({ern, closed})` kills it, so a write still in its queue is answered either `Left(Closed)` or, through the socket's Down, `Fault("callee was closed")`. The two outcomes are not ordered.
   - Shown by:
     ```
     8 processes, each looping Tcp.write(client, 1 MiB, 60000) to a peer that never reads,
     then Tcp.close(client): 4 Right(Unit), 8 Left(Closed), 8 Fault("callee had ended")
     (the held writes drained in time on this machine; nothing orders it)
     ```
   - Fix: Answer the writes held at close with `Left(Closed)` from the socket process before it exits, and state this in E.18.

7. **`Fs.setModified` with a time the host cannot hold answers `Left(Other("bad argument"))`, a case E.17 does not cover, where E.1's `Invalid` is "an argument the host cannot take".**
   - Place: erl/runtime/src/ern_fs.erl:125-134; report Appendix E.1, E.17
   - Quote: "unit(file:write_file_info(Name, Info, [raw, {time, posix}]));"
   - Wrong: The host's `badarg` reaches the caller as the text "bad argument". `setMode` refuses its own out-of-range argument as `Invalid`, but this time is refused by neither the code nor the report.
   - Shown by:
     ```
     Io.show(Fs.setModified(Path("f.txt"), Int.shiftLeft(1, 80), 1000))   // Left(Other("bad argument"))
     ```
   - Fix: Answer `Left(Invalid)` for a time outside the host's range and say so in E.17, or add the sentence that gives `Other`.

8. **One host error gets two texts: `Os.start` answers strerror's "Too many open files", while `Fs` and `Tcp` answer "too many open files".**
   - Place: erl/runtime/c_src/ern_exec.c:152-161 (`error_name`) against 309-328 (`posix_name`); erl/runtime/src/ern_os.erl:349
   - Quote: "default: return strerror(error);"
   - Wrong: `error_name`, used by start, knows four errno names and sends strerror for every other. `posix_name`, used by remove, sends the name, which `file:format_error` then describes. E.1's `Other(text)` is "the host's description", but the wording changes with the module that met the error.
   - Shown by:
     ```
     ern_os_tests.erl:104 expects <<"fToo many open files">>; :140 expects Other(<<"Argument list too long">>)
     file:format_error(emfile) = "too many open files"; file:format_error(e2big) = "argument list too long"
     ```
   - Fix: Use `posix_name` for both jobs and describe the name in Erlang, as removal_error/1 does.

9. **Two standard library tests listen on fixed ports 7411 and 7412, so they fail whenever another program on the machine holds either port.**
   - Place: erl/runtime/test/ern_stdlib_tests.erl:967, 989
   - Quote: "{'Right', Listener} = Tcp:listen(<<"127.0.0.1">>, 7411),"
   - Wrong: The result depends on the machine. Every other TCP test listens on port 0 and asks `Tcp.port`.
   - Shown by: none
   - Fix: Listen on port 0 and connect to the port `Tcp:port` answers. For the second test, reuse the first run's port.

#### Clarity

10. **ern_rt's header says four tables hold the run's state, but `make_tables/0` makes six. `ern_callees` and `ern_deliveries` are missing from the header.**
    - Place: erl/runtime/src/ern_rt.erl:27-36, 1546-1552
    - Quote: "Four tables hold the run's state."
    - Wrong: The comment no longer matches the code.
    - Shown by: none
    - Fix: Say six, and name `ern_callees` and `ern_deliveries` with the other four.

11. **ern_fs's header gives an Entry four fields, but `entry/2` builds six, including mode and user.**
    - Place: erl/runtime/src/ern_fs.erl:5-6, 246-247
    - Quote: "an Entry's fields are in declared order (report §3.5): path, mtime, size, kind."
    - Wrong: The comment no longer matches E.17's `Entry(path, mtime, size, kind, mode, user)`.
    - Shown by: none
    - Fix: List the six fields, or point to the comment at line 239, which already lists them.

12. **ern_os's comments still say a program dies with "the process that started it", but since `Give` the code watches the program's owner.**
    - Place: erl/runtime/src/ern_os.erl:8-9, 321-322, 336-337
    - Quote: "or until the process that started it dies"
    - Wrong: `given_to/2` moves the monitor to a new owner (E.23), so these three comments no longer hold.
    - Shown by: none
    - Fix: Say "its owner" in all three places.

13. **A test comment speaks of "a via proxy", but `via` makes no process (§6.5); the very next test asserts this.**
    - Place: erl/runtime/test/ern_rt_tests.erl:742-743
    - Quote: "a message on its way through a via proxy is in flight"
    - Wrong: The comment describes a design that was removed. What the test exercises is the alarm's delivery process.
    - Shown by: none
    - Fix: Say "a message an alarm delivers through `via` is in flight until its delivery process ends".

14. **ern_tcp's comments are out of date. The `#connection{}` comment leaves out the `writes` field, and the header claims every waiting request is counted, though Listen's worker is not.**
    - Place: erl/runtime/src/ern_tcp.erl:7-8, 18-24, 45
    - Quote: "A request waiting is a source (report §8.6), counted from its arrival until its answer."
    - Wrong: `listen/5` is spawned without `counted/1`, unlike Connect and Accept, and nothing says why.
    - Shown by: none
    - Fix: Name `writes` in the record's comment, and either count Listen or say why the caller's call row covers it.

15. **ern_stdlib_tests' first comment promises one test per module, but String alone has six tests.**
    - Place: erl/runtime/test/ern_stdlib_tests.erl:1-2
    - Quote: "The stdlib modules of Appendix E, one test per module"
    - Wrong: The comment no longer matches the module.
    - Shown by: none
    - Fix: Say "the stdlib modules of Appendix E, by module".

16. **`doc_of/1` says it answers `none` for a node with no doc, but a declaration without one answers `undefined`, and `documented/1` depends on that.**
    - Place: erl/runtime/test/ern_doc_tests.erl:318, 231
    - Quote: "%% A node's doc block, or none where it carries no doc."
    - Wrong: The function answers `none` only for nodes that cannot carry a doc. For a declaration without one it answers the record's default, `undefined`.
    - Shown by: none
    - Fix: Say "`undefined` for a declaration without one, `none` for a node that carries none", or map `undefined` to `none`.

17. **Test comments cite `findings.md`'s entries (C29, C7, K-15, E15…), but that file is gone, and "C-1" names two different defects.**
    - Place: erl/runtime/test/ern_rt_tests.erl:89, 200, 335; ern_os_tests.erl:9, 38, 95, 178; ern_tcp_tests.erl:200, 217, 266; ern_tty_tests.erl:260; ern_stdlib_tests.erl:45, 263, 296, 924, 1092, 1097; ern_show_tests.erl:20; ern_doc_tests.erl:68
    - Quote: "(findings.md's C-1)"
    - Wrong: `docs/findings.md` exists only while a review is open, so every one of these references is dangling. ern_os_tests:178 and ern_tcp_tests:266 cite the same ID for two different defects.
    - Shown by: none
    - Fix: Remove the IDs, or name the plan item or log entry that recorded each defect.

18. **Source and test comments carry history: "since 2026-09-20", "A regression: …", "the rule of 2026-10-01". These describe the past, not why the code is as it is.**
    - Place: erl/runtime/src/ern_tty.erl:24, 272, 429-430; erl/runtime/test/ern_os_tests.erl:9, 145, 162, 203; ern_tcp_tests.erl:66, 139, 337; ern_stdlib_tests.erl:28, 492, 735, 857, 1086, 1143
    - Quote: "A regression: the signal was turned back on but for the shell."
    - Wrong: docs/style.md: "A comment says why and cites the report section". A date or an old behaviour belongs in the log.
    - Shown by: none
    - Fix: Keep the rule and its section, and drop the date and the story.

19. **ern_rt's process rows are positional 5-tuples, updated by field number (`count(3, …)`, `count(4, …)`, `{2, Site}`). The `ern_processes` table also holds five other kinds of row.**
    - Place: erl/runtime/src/ern_rt.erl:27-33, 731-732, 936-940, 964-965, 1727
    - Quote: "count(3, 1)."
    - Wrong: docs/style.md: "A value of more than three parts is a record". A reader has to count positions to see that 3 is the timed waits. The table's name says processes, but it also holds `reading`, `deadlock_victim`, `{restart, Pid}`, `{proxy, Key}` and `{behind, Pid}` rows, which is why `live_rows/0` selects rows by their arity.
    - Shown by: none
    - Fix: Make the row a record and update it with `#process.timers`, and move the terminal, victim, restart and proxy rows to a table named for them.

20. **Runtime values that cross modules are positional tuples: `{via, …}`, `{foreign, …}`, `{foreign_reply, …}`, and a six-part `'fun'` descriptor that has two shapes under one tag.**
    - Place: erl/runtime/src/ern_boundary.erl:17-32, 119, 126, 294; ern_rt.erl:87-92; ern_show.erl:58, 114-115, 133
    - Quote: "{'fun', Arity, R, Cause, Make, Exposer} | {'fun', Arity, R, Cause, Ps, Causes}"
    - Wrong: docs/style.md: "a tuple of more than two that crosses modules" is a record. `Ps`, `R` and `Causes` are names a reader has to guess. Positions 5 and 6 hold funs in one shape and lists in the other, so `arm/3` and `expose/3` depend on the emitter having converted the descriptor.
    - Shown by: none
    - Fix: Make each of these a record in erl/runtime/include, and give the two `'fun'` shapes tags of their own.

21. **ern_rt names the request-making function `Mk`, an abbreviation, where §6.6 calls it `request`.**
    - Place: erl/runtime/src/ern_rt.erl:216, 223, 233, 264, 270, 275
    - Quote: "call(Address, Mk, Ms) ->"
    - Wrong: docs/style.md says a concept the report names takes the report's name, and allows no abbreviation a reader must guess.
    - Shown by: none
    - Fix: Rename it `Request`.

22. **The stdout and stderr host port is named `Port`, against the glossary, and the clock record's `time` field holds a function that reads the clock.**
    - Place: erl/runtime/src/ern_rt.erl:1062, 1080-1120, 1385, 1391, 1479
    - Quote: "port_loop(Port, Name) ->"
    - Wrong: The glossary says a host port "is named for what it runs: `Helper`, `Stty`", and keeps `Port` for E.18's port number. It also says a moment is a `time`, but `Time()` here is a reader of the clock, not a moment.
    - Shown by: none
    - Fix: Rename them to `Stream` (or `Output`) and to `read_time` / `ReadTime`.

23. **In ern_fs, `Name` means both a path's text and an error's name, and `Path` means both a `{'Path', _}` value and a raw binary.**
    - Place: erl/runtime/src/ern_fs.erl:34, 227-232, 243, 292
    - Quote: "Path = filename:join(Dir, Name),"
    - Wrong: "One concept, one name": in handle/1 `Path` is the Ernest value and `Name` its text, in entries/2 `Path` is the text and `Name` an entry's basename, and in removal_error/1 `Name` is an errno name.
    - Shown by: none
    - Fix: Name them `Text` (or `File`) for the path's text, `EntryName` for a basename and `ErrorName` for the helper's word.

24. **Several helpers are written twice: `is_utf8` and `utf8`, `name_bytes` and `name`, two `io_error` mappings, and `error_name` beside `posix_name`. `host/0` also copies helper_failed's text three times.**
    - Place: erl/runtime/src/ern_fs.erl:213, 218-223, 299-307; ern_os.erl:360, 364, 379, 390-391, 407-408; ern_tcp.erl:428-434; c_src/ern_exec.c:152-161, 309-328
    - Quote: "ern_rt:fault(<<"the runtime's helper ern_exec failed">>)"
    - Wrong: One thing has two names and two bodies, and the copies have already drifted apart (finding 8).
    - Shown by: none
    - Fix: Keep one of each, the shared POSIX mapping in ern_io beside `other/2`, and have `host/0` use `helper_failed()`.

25. **The spawn order has four names: `Spawned` in the header, `spawn_number/0`, `spawn_order/1`, and `Number` in the pattern.**
    - Place: erl/runtime/src/ern_rt.erl:29-30, 558-561, 1828-1833
    - Quote: "Spawned its place in the order of spawns"
    - Wrong: docs/style.md: "One concept, one name, in every module."
    - Shown by: none
    - Fix: Call it the spawn order everywhere: `SpawnOrder`, `spawn_order`.

26. **ern_tcp_tests calls `Tcp.remote`'s request `peer`, in its helper and in its comment, though the library and the message call it `Remote`.**
    - Place: erl/runtime/test/ern_tcp_tests.erl:61-62, 80, 84, 413-414
    - Quote: "peer(Socket) ->\n    ern_rt:call_forever(Socket, fun(Reply) -> {'Remote', Reply} end)."
    - Wrong: The test uses a name the library no longer has, so one thing has two names.
    - Shown by: none
    - Fix: Rename the helper `remote/1` and say `remote` in the comment.

27. **Tests use single letters and abbreviations across multi-line scopes (`T`, `D`, `S`, `L`, `N`, `Tab`, `Conn`, `Bin`), and the laws tests name a host error `Reason`.**
    - Place: erl/runtime/test/ern_os_tests.erl:47, 89, 105-106; ern_tcp_tests.erl:15, 72, 97-98, 370; ern_rt_tests.erl:57, 91; ern_tty_tests.erl:106; ern_stdlib_tests.erl:568, 586; ern_laws_tests.erl:1007
    - Quote: "fun(L) -> {later, L} end, <<"reader">>),\n               receive {later, L} -> Self ! {later, L} end"
    - Wrong: docs/style.md allows one letter only where the whole scope is one line. The glossary keeps `Reason` for §9.3 and calls a host's error an `Error`.
    - Shown by: none
    - Fix: Rename them `Tag`, `Frame`, `Status`, `LaterDown`, `Count`, `Chunks`, `Connection`, `Bytes`, and `Class:Error:Trace`.

28. **The queue-fed input function is written out four times in the tests: two copies in ern_rt_tests, one in ern_tty_tests, one in ern_stdlib_tests.**
    - Place: erl/runtime/test/ern_rt_tests.erl:57-64, 91-98; ern_tty_tests.erl:106-113; ern_stdlib_tests.erl:586-593
    - Quote: "[{_, [Chunk | Rest]}] -> ets:insert(Tab, {queue, Rest}), Chunk;"
    - Wrong: This code could be shorter. Each copy makes its own ETS table, and each test then has to be read to confirm the copy is the same.
    - Shown by: none
    - Fix: Add one helper, `chunks(List, AtEnd)`, that returns the `Next` function, for instance over an `atomics` index or an agent process.

29. **ern_doc_tests carries dead weight: `run_example/4` takes an unused `_Cwd`, `erlang_module/1` only forwards to ern_namespace, and `collect/1` and `collect/2` collect alike but return different shapes.**
    - Place: erl/runtime/test/ern_doc_tests.erl:122, 128, 148-151, 163-168, 374-375
    - Quote: "run_example(ErlangModule, Number, Expected, _Cwd) ->"
    - Wrong: This code could be shorter, and the two `collect` functions differ only in the tag and the result.
    - Shown by: none
    - Fix: Remove the parameter and the wrapper, and use `collect(out, [])` with `iolist_to_binary` where a binary is wanted.

30. **`exit_program/1` writes a two-condition precondition on one line, where docs/style.md asks for a `case`.**
    - Place: erl/runtime/src/ern_rt.erl:1658
    - Quote: "Status >= 0 andalso Status =< 255 orelse fault(<<"an exit status is from 0 to 255">>),"
    - Wrong: docs/style.md: "A precondition is `Cond orelse fail(...)` on one line; two or more conditions are a `case`." Here precedence also decides the meaning.
    - Shown by: none
    - Fix: Write a `case Status >= 0 andalso Status =< 255 of` (or a guard clause) that faults.

31. **The helper's `SIGNALS` comment says the constant is past the highest signal number, but the loop includes it, and 64 is Linux's highest signal itself.**
    - Place: erl/runtime/c_src/ern_exec.c:83-85, 529
    - Quote: "Past the highest signal number of a host Ernest runs on"
    - Wrong: The loop is `for (number = 1; number <= SIGNALS; number++)`, so 64 is the highest number reset, not one past it.
    - Shown by: none
    - Fix: Say "the highest signal number of a host Ernest runs on".

32. **ern_rt_tests has three small faults: no first comment stating its job, a `wait(counts2)` clause that receives `{counts, …}`, and a proxy test that cites §6.3 (`receive`).**
    - Place: erl/runtime/test/ern_rt_tests.erl:1, 770, 786, 834, 838-839
    - Quote: "wait(counts2) ->\n    receive {counts, Before, After} -> {Before, After} after 2000 -> timeout end;"
    - Wrong: docs/style.md says a module's first comment states its job. The tag `counts2` matches no message. The proxy test is about §6.5 and §8.4, not §6.3.
    - Shown by: none
    - Fix: Add the module's comment, give the counts their own `wait_counts/0`, and cite §6.5.

33. **`ern_tcp:listen/5` takes `(Tcp, Host, Owner, Port, Reply)`, while the message and `connect/6` order them Host, Port, …, Owner.**
    - Place: erl/runtime/src/ern_tcp.erl:44-45, 74, 137
    - Quote: "erlang:spawn(fun() -> listen(Tcp, Host, Owner, Port, Reply) end),"
    - Wrong: A reader comparing the call with the message has to reorder the arguments in their head.
    - Shown by: none
    - Fix: Make it `listen(Tcp, Host, Port, Owner, Reply)`.

### C, part 5, the shell's Erlang; its 1 to 40 are C136 to C175

#### Defects

1. **A `let` of the name `it` or `declarations` is taken for an expression or for declarations, since the input's binds tag is the bare name**
   - Place: erl/cli/src/ern_shell.erl:204
   - Quote: "{ok, let_binds(Name, Body), annotated(Name, Body, Annotation)}"
   - Wrong: `#checked.binds` holds a `let`'s name as a bare atom beside the tags `it` and `declarations` (lines 384, 2441, 2447, 2164). So `let it = 5` prints as a value and not as `it : Int`. `:type let it = 5` is answered, where §11.2 refuses a `let`. `let it = []` is not refused as undetermined. `let declarations = 5` runs no body, binds no `declarations`, and puts the wrapper `$input` into the session's scope, which `:bindings` then lists.
   - Shown by:
     ```
     $ printf 'let it = 5\n:type let it = 5\nlet it = []\nlet declarations = 5\n:bindings\n' | bin/ern shell
     > 5 : Int
     > let it = 5 : Int
     > [] : List(a)
     `it` is unchanged: this input did not determine the type of its value
     > $input : () -> Int
     > $input : () -> Int
     it : Int
     ```
   - Fix: Tag a `let`'s name, `{name, Name}`, so that no identifier can stand for the tags `it` and `declarations`.

2. **`:load` of a compiled module found under a path with a non-ASCII character ends the shell with status 70**
   - Place: erl/cli/src/ern_shell.erl:1605, and 1597
   - Quote: "(list_to_binary(relative(File, Session)))/binary"
   - Wrong: A path is a list of code points. `list_to_binary` raises `badarg` for one above U+00FF, and writes Latin-1 for one below it, which the boundary then refuses as not a `String`. Either way the shell faults and exits, where the session should go on. The answer's other lines are built with `unicode:characters_to_binary`.
   - Shown by:
     ```
     $ mkdir -p łódź/src empty; echo 'export fn one() : Int = 1' > łódź/src/m.ern
     $ bin/ern build --source-root łódź/src --build-root łódź/build łódź/src/m.ern
     $ echo ':load M' | bin/ern shell --source-root empty --load-path łódź/build; echo $?
     > fault: foreign function ern_shell:load/2 raised error:badarg
         erlang:list_to_binary/1
         ern_shell:load/3 (ern_shell.erl:1605)
     70
     ```
     Under `jöcke/build` the same `:load` gives `fault: foreign return does not match Either(String, #(Session, String))`, and status 70.
   - Fix: Build both answers with `unicode:characters_to_binary`.

3. **`:load` of a module whose compiled file cannot be read ends the shell with status 70**
   - Place: erl/cli/src/ern_shell.erl:2091
   - Quote: "{ok, Beam} = file:read_file(File),"
   - Wrong: compiled_of/2 asks only whether the file is regular. A file it may not read raises `badmatch` out of the front end, and the shell exits, where an unreadable source is refused and the session goes on (load_unreadable_test_).
   - Shown by:
     ```
     $ bin/ern build --source-root closed/src --build-root closed/build closed/src/m.ern
     $ chmod 000 closed/build/m.erc
     $ printf ':load M\n1 + 1\n' | bin/ern shell --source-root empty --load-path closed/build; echo $?
     > fault: foreign function ern_shell:load/2 raised error:{badmatch,{error,eacces}}
         ern_shell:compiled_of/2 (ern_shell.erl:2091)
     70
     ```
   - Fix: Refuse the `:load` with the file and why it could not be read, and go on.

4. **A binding whose closure captures a function of a reloaded module is neither listed nor forgotten, and faults with the host's `badfun` once that version is purged**
   - Place: erl/cli/src/ern_shell.erl:2030
   - Quote: "holds_fun(Function, ErlangModule) when is_function(Function) ->"
   - Wrong: holds_fun/2 asks a function's own module and not what it captures; fun_modules/2 (line 567) follows the captures. §11.2: a binding that holds a function of the previous version keeps it, the reload names it, and the next reload forgets it. Here the binding is never named, the version is purged under it, and a call runs purged code.
   - Shown by:
     ```
     demo.ern: export fn answer() : Int = 1
     > :load Demo
     > let g = Demo.answer
     > let k : () -> Int = { let f = Demo.answer; fn() = f() }
     (demo.ern made to answer 2) > :reload
     Demo: g, a binding in the previous version; a further reload of it ends them
     (demo.ern made to answer 3) > :reload
     Demo: ended g, a binding in the previous version
     > k()
     > fault: error:{badfun,#Fun<ern@demo.0.103102982>}
     ```
   - Fix: Ask `lists:member(ErlangModule, fun_modules(Value, []))` in bindings_of/2, and remove holds_fun/2.

5. **A further `:reload` forgets a binding taken from the version it replaces, which stays loaded, and reports it ended**
   - Place: erl/cli/src/ern_shell.erl:2007, end_previous/2, with bindings_of/2 at 2018
   - Quote: "Bindings = bindings_of(Session, ErlangModule),"
   - Wrong: bindings_of/2 matches a function of the module of any version. Before the second reload purges version 1, it forgets a binding of version 2 too, though version 2 only becomes the previous version and stays loaded. §11.2 forgets "those bindings" the earlier reload named, and lists the rest as in the previous version.
   - Shown by:
     ```
     > :load Demo
     > spawn(fn() = Demo.tick())
     (demo.ern made to answer 2) > :reload
     Demo: input 2:1, a process in the previous version; a further reload of it ends them
     > let h = Demo.answer
     > h()
     > 2 : Int
     (demo.ern made to answer 3) > :reload
     Demo: ended input 2:1, a process, h, a binding in the previous version
     > h()
     > input 9:1:1: unknown name h
     ```
   - Fix: Forget only the bindings the earlier reload listed, and list those that hold the version now replaced.

6. **`:reload` refuses a changed module that has come to use a module whose source the source root holds, where `:load` would compile it**
   - Place: erl/cli/src/ern_shell.erl:1876, compile_all/2
   - Quote: "case compile_in_order(Session, Changed) of"
   - Wrong: §11.2: "A module a reload loads for the first time is loaded as `:load` loads it", and `:load` compiles a module it uses from its source. compile_all/2 compiles the changed modules alone and seeks the new dependency's `.erc`. The refusal also names the file by its absolute path, where §11.5 names it from the working directory.
   - Shown by:
     ```
     top.ern: export fn answer() : Int = 1      helper.ern: export fn more() : Int = 41
     > :load Top
     (top.ern made to call Helper.more() + 1) > :reload
     > compile Helper first: /tmp/.../C5/r9/helper.erc: no such file or directory
     nothing was reloaded
     ```
   - Fix: Gather the changed modules' unloaded dependencies with sources, as with_sources/3 does for `:load`, before compiling.

7. **A `let` with a pattern whose line ends unfinished runs at `Enter` instead of taking the next line**
   - Place: erl/cli/src/ern_shell.erl:142
   - Quote: "unfinished(ern_parser:parse_expr(Text)) orelse unfinished(ern_parser:parse_string(Text))."
   - Wrong: input/1 reads an input three ways, the third a pattern `let` as a statement (pattern_let/1). needs_more/1 tries only the first two, so `let #(a, b) =` is run alone with the declaration parser's error, and its next line runs as an input of its own. §11.2: an input the parser cannot finish takes the next line, at a terminal and in line mode alike.
   - Shown by:
     ```
     $ printf 'let #(a, b) =\n    #(1, 2)\n' | bin/ern shell
     > input 1:1:5: expected a name instead of `#(`
     1 | let #(a, b) =
       |     ^^
     > #(1, 2) : #(Int, Int)
     ```
   - Fix: Try ern_parser:parse_statement in needs_more/1 as well.

8. **Each `Tab` after an unknown word and a `.` makes an atom the host keeps for ever, since fields/1 parses with names made**
   - Place: erl/cli/src/ern_shell.erl:1138
   - Quote: "{ok, Binds, Expr} ?= input(Head),"
   - Wrong: slot/1 and within/1 read with `no_new_names`, since "the host keeps a name for ever, and a `Tab` is pressed at every word". fields/1 parses the text before the last `.` through input/1, which makes a name of every word. typing_makes_no_names_test_ asks slot, signature and documentation, and not fields.
   - Shown by:
     ```
     at a terminal, `info(Erl.atom("atom_count"))` before and after ten lines
     `zqxalpha.` Tab C-c ... `zqxjuliet.` Tab C-c:
     19264 : Int   (and 19264 for the same input again, before)
     19274 : Int
     escript: ern_shell:fields(<<"zqxNever.">>) -> [], 1 new atom, zqxNever exists
     ```
   - Fix: Parse with `[no_new_names]` in fields/1, answering no fields for an unmet name, and add fields/1 to the test.

9. **`Shift-Tab` on a function makes the atom of an Erlang module named for the whole name, `ern@list@filter`, which the host keeps for ever**
   - Place: erl/cli/src/ern_shell.erl:1497
   - Quote: "ErlangModule = ern_emitter:erlang_module(Namespace),"
   - Wrong: beam_on_path/1 makes the Erlang module's atom for any namespace it is asked about, and module_head/2 (line 1421) asks it of every documented name. Each name a person asks about makes one, and so do any two existing words `a.b`.
   - Shown by:
     ```
     escript, after a warm-up: ern_shell:documentation of <<"List.filter">>,
     <<"List.foldLeft">> and <<"Map.put">>: 3 new atoms;
     ern@list@filter, ern@list@foldleft and ern@map@put exist afterwards
     ```
   - Fix: Seek the file by its name as a string, and a loaded module through `binary_to_existing_atom`.

10. **A failed `:load` leaves the values its bindings evaluated stored for the life of the node**
    - Place: erl/cli/src/ern_shell.erl:1710, withdraw/1
    - Quote: "withdraw(ErlangModule) ->"
    - Wrong: The module is deleted and purged and its processes ended, "so that the session is as it was" (line 1705), but the values of the bindings evaluated before the fault stay under the module's keys (§8.5's store), where no collection reclaims them.
    - Shown by:
      ```
      bad.ern: export let big : List(Int) = List.range(1, 100000)
               export let late : Int = 1 / List.size([])
      > :load Bad
      > Bad.late:2 faulted: division by zero; nothing was loaded
      > Foreign.toList(stored(tuple([Erl.atom("ern@bad"), Erl.atom("big")]), Foreign.from(0)))
      > Some([<foreign>, <foreign>, ...
      (stored is persistent_term:get/2, tuple erlang:list_to_tuple/1)
      ```
    - Fix: Erase the keys of the module's `let`s, which its interface lists, as it is withdrawn.

11. **A binding that a reloaded module no longer declares keeps its value stored for the life of the node**
    - Place: erl/cli/src/ern_shell.erl:1969, reload_one/2
    - Quote: "Session2 = install(Session1, Namespace, Beam, Hash),"
    - Wrong: Nothing erases the key of a top-level `let` the new version dropped. Once the version that declared it is purged, nothing can read it and no collection reclaims it.
    - Shown by:
      ```
      m.ern: export let big : List(Int) = List.range(1, 100000)  export fn one() : Int = 1
      > :load M
      (m.ern made to hold `one` alone, answering 2) > :reload
      > M.one()
      > 2 : Int
      > List.size(Optional.withDefault(Foreign.toList(stored(tuple([Erl.atom("ern@m"), Erl.atom("big")]), Foreign.from(0))), []))
      > 100000 : Int
      ```
    - Fix: When the version that declared a `let` is purged, erase the keys of the lets the new version does not declare.

12. **Every binding is a persistent term erased when `it` is next replaced, paying at almost every input the scan of all processes the front end's table avoids**
    - Place: erl/cli/src/ern_shell.erl:2282, with 2224, against the comment at 58-66
    - Quote: "the host scans every process when a persistent term is replaced, and what an input costs does not grow with the processes the session has"
    - Wrong: bound/3 stores each binding as a persistent term, and each expression input binds `it` in a new holder, so collected/1 erases the previous holder's term at the next input. The host's documentation has erasing a term that is not an immediate start a scan of every process. The module's own argument for keeping per-input state in a table is thus broken by the bindings.
    - Shown by: none
    - Fix: Decide where a binding's value lives with this cost stated, and say it in loaded/1's comment.

13. **`:doc` and `Shift-Tab` show a module's name with the page's type, `Entry`, and not the type the shell prints, `Fs.Entry`**
    - Place: erl/cli/src/ern_shell.erl:1505, entry/2, through module_doc/2 at 1471
    - Quote: "entry(Beam, Name) -> ern_page:declaration(Beam, Name)."
    - Wrong: §11.2: a name's documentation is "showing the type the shell prints for it". session_doc/2 (line 1436) passes the shell's line for a session name. module_doc/2 passes none, so a module's types print unqualified, against `:type` and `:browse`.
    - Shown by:
      ```
      $ printf ':doc Fs.stat\n:type Fs.stat\n' | bin/ern shell
      > Fs.stat

          Fs.stat : (Path, Int) -> Either(Io.Error, Entry) with m+
      ...
      > Fs.stat : (Path, Int) -> Either(Io.Error, Fs.Entry) with m+
      ```
    - Fix: Give a module's section the scheme line the shell prints, as session_doc/2 does.

14. **`Shift-Tab` drops a module's version from a declaration whose doc text holds `*Since `, since it searches the rendered page for it**
    - Place: erl/cli/src/ern_shell.erl:1091
    - Quote: "string:find(unicode:characters_to_binary(Page), <<\"*Since \">>)"
    - Wrong: Whether a declaration has a `since` of its own (Appendix E.0 rule 6) is answered by searching the prose, so the version a brief shows (§11.2) depends on the doc block's wording.
    - Shown by:
      ```
      tick.ern, `since 0.3.0`: "Counts the seconds *since the epoch* began." and
      "Counts the minutes *Since the epoch* began."
      documentation(<<"Tick.seconds">>) holds "*Since 0.3.0.*"
      documentation(<<"Tick.minutes">>) holds no version line
      ```
    - Fix: Ask the declaration's documentation entry whether it carries a `since`, not its rendered text.

15. **`Shift-Tab` on a member of a module's type, `Shape.Point.compare`, shows no version, since its module is sought one segment back only**
    - Place: erl/cli/src/ern_shell.erl:1112, module_of_name/2
    - Quote: "case beam_of(Session, lists:droplast(Segments)) of"
    - Wrong: §11.2 and Appendix E.0 rule 6 give the brief the module's version. module_doc/2 (line 1471) finds a member's page two segments back, but module_of_name/2 finds no module for it, and the brief has no version.
    - Shown by:
      ```
      shape.ern, `since 0.3.0`: export fn Point.compare(...), export fn origin()
      documentation(<<"Shape.origin">>)        -> ... "*Since 0.3.0.*\n"
      documentation(<<"Shape.Point.compare">>) -> ... "Orders two points by x.\n\n"
      ```
    - Fix: Seek a member's module two segments back, as module_doc/2 does.

16. **`Shift-Tab` inside a call of a function named with a leading `_` shows nothing, the name being taken for a constructor's**
    - Place: erl/cli/src/ern_shell.erl:1167
    - Quote: "case not is_integer(Argument) orelse hd(atom_to_list(Name)) < $a of"
    - Wrong: §2.3: an `ident` may begin with `_`, which sorts below `a`, so a call of `_twice` goes to constructor_signature/3 and has no signature.
    - Shown by:
      ```
      at a terminal, after `fn twice(n : Int) : Int = n * 2` and the same as `_twice`:
      `twice(` Shift-Tab   -> twice(n : Int) : Int
      `_twice(` Shift-Tab  -> nothing
      ```
    - Fix: Take a callee for a constructor where its name begins with `A` to `Z`.

17. **`:bindings`, `:browse` and completion print a foreign type as `type`, where its declaration prints `foreign type`**
    - Place: erl/cli/src/ern_shell.erl:969
    - Quote: "abstract_text(#type_info{abstract = true}) -> \"abstract \";"
    - Wrong: declared/1 prints `foreign type Handle`, and bindings/1 promises lines "as an input's own declarations print", but abstract_text/1, used at lines 609, 845 and 959, knows `abstract` alone, though `#type_info{}` has `foreign`.
    - Shown by:
      ```
      > foreign type Handle
      > foreign type Handle
      > :bindings
      type Handle
      > :browse Foreign
      type Foreign.Term
      ```
    - Fix: Give `foreign ` for `#type_info{foreign = true}`, and name the function for the keyword it gives.

18. **input_module_unloaded_test_'s bound passes the very regression it guards against, and two tests' "Not covered" notes no longer hold**
    - Place: test/ern_shell_tests.erl:1330, and 1309, 1337, 1354
    - Quote: "?assert(After - Before =< 50 + 5),"
    - Wrong: The bound allows for a holder of `it` loaded per input, which the session now frees (holders_freed_test_). Fifty inputs load 2 more modules, so a regression that left all fifty loaded, about 52, still passes. input_numbers_reused_test_'s 600 atoms for 200 inputs, where 28 are made, lets the holders' two atoms an input come back unseen. Both notes say step 10 of MVP 2.65 frees the holders, which it has.
    - Shown by:
      ```
      the test's inputs: List.size(loadedModules()) 226, then 228 after 50 inputs
      input_numbers_reused's inputs: atom_count 19240, then 19268 after 200 inputs
      ```
    - Fix: Bound both counts at a handful, and remove the two notes.

19. **The shell's terminal tests never check that the shell ended, so one that no longer exits passes after the harness kills it**
    - Place: test/ern_shell_tests.erl:2724
    - Quote: "[<<\"data \", Data/binary>>] = [Line || <<\"data \", _/binary>> = Line <- Lines],"
    - Wrong: ern_pty.py prints `status timeout` where the program never ended and it was killed. raw/4 keeps only the data, so a shell that `C-d` or `:quit` no longer ends passes every terminal test, only slower; multiline's comment on `C-c` shows the wait. ern_terminal_tests asserts the status.
    - Shown by: none
    - Fix: Assert `status 0` in raw/4.

20. **Two specs do not hold: slot/1 gives `Name` tuples, not binaries, and to_screen/1 gives `'Unit'`, not `ok`**
    - Place: erl/cli/src/ern_shell.erl:626, 2132, and 462
    - Quote: "-spec slot(binary()) -> atom() | {'Fields', [binary()]}."
    - Wrong: fields_of/3 gives `{'Name', Text, Kind, Shown}` tuples, which fields_by_module's test reads. to_screen/1 answers what ern_rt:send/2 answers, `'Unit'`, or what file:write/2 does. run/4 gives an address and is specified `term()`.
    - Shown by: none
    - Fix: Specify what each gives.

21. **terminal_test_'s last assertion repeats the `Killed` match, so its comment's claim, that the session was not ended, is not asserted there**
    - Place: test/ern_shell_tests.erl:2665
    - Quote: "%% the interrupt reached the shell as a key; the session was not ended"
    - Wrong: The assertion under the comment is the one two lines above it again. What shows the session went on is the later `2 : Int` and the shell's exit status, and the status is not asserted.
    - Shown by: none
    - Fix: Assert the exit status there, or remove the repeated match.

#### Clarity

22. **The code for a `let` in a declaring input is never reached, since declarations/1 refuses one: `'$init'`, stored values, keys and three clauses**
    - Place: erl/cli/src/ern_shell.erl:585, with 2164-2171, 512, 285, 2479, 2498
    - Quote: "erlang:function_exported(ErlangModule, '$init', 0) andalso ErlangModule:'$init'()"
    - Wrong: A declaring input holds no `let`, and the emitter exports `'$init'` only for a module with one. So the `'$init'` call, bind/7's scan of stored values, record_uses/3's `Keys`, and the `#let_declaration{}` clauses of exported/1, kind/1 and declared_name/1 never run. value/2's comment, "An input that declares runs its initializers", describes what cannot happen.
    - Shown by: none
    - Fix: Remove them, and say once, at declarations/1, that a declaring input holds no `let`.

23. **one_let/1's comment describes `let T.name`, a member `let` the language does not have**
    - Place: erl/cli/src/ern_shell.erl:269
    - Quote: "A `let` that declares a type member, `let T.name`, is a declaration and not this."
    - Wrong: §4.5: "a `let` declares no member". Appendix A's `LetDecl` takes an `ident`, and `#let_declaration{}` has no `member_of`.
    - Shown by: none
    - Fix: Remove the sentence.

24. **The session record's comment says `beams` holds declaring inputs, but it holds every module `:load` and `:reload` compile too; `#checked{}`'s names half its fields**
    - Place: erl/cli/src/ern_shell.erl:43, and 45-47
    - Quote: "beams: the namespace of an input that declared, to its compiled module,"
    - Wrong: install/4 (line 2048) puts each loaded module's bytes there, which beam_of/2's comment says. The comment over `#checked{}` names four of its eight fields, and `site` nowhere.
    - Shown by: none
    - Fix: Name both kinds of module in the field's comment, and every field of `#checked{}`.

25. **fault_text/2 and its two catch clauses restate ern_rt:fault_exit_reason/3, which already turns a host error into a fault's cause**
    - Place: erl/cli/src/ern_shell.erl:591, with 488-490 and 1749-1751
    - Quote: "fault_text(error, badarith) -> <<\"division by zero\">>;"
    - Wrong: erl/runtime/src/ern_rt.erl:1007 has the same `badarith` and `~p:~p` clauses and the `{ern, fault, ...}` cases. The shell writes them twice more, one concept in three places.
    - Shown by: none
    - Fix: Catch `Class:Error:Stack` and take the cause from ern_rt:fault_exit_reason/3 in both places.

26. **constructor_scheme/2 repeats constructor_info/2's scan, and one_constructor/2 walks every type where a key lookup would do**
    - Place: erl/cli/src/ern_shell.erl:781, with 1268 and 718
    - Quote: "constructor_scheme(QualifiedName, #session{interfaces = Interfaces}) ->"
    - Wrong: constructor_scheme/2 is constructor_info/2 with the scheme taken. one_constructor/2 lists every type of every interface with `maps:to_list` to compare keys, where type_info/2 matches `#{QualifiedName := TypeInfo}`.
    - Shown by: none
    - Fix: Write constructor_scheme/2 over constructor_info/2, and look the type up by its key.

27. **The purge of a deleted session module is retried in release/3 and again in collected/1, and its pending modules live in two homes in two forms**
    - Place: erl/cli/src/ern_shell.erl:525-549, and 2262-2295
    - Quote: "{Purged, Unpurged} = lists:partition(Purgeable, Pending),"
    - Wrong: release/3 retries every pending input's purge, frees its number and forgets its uses. collected/1 does the same again once the input has answered. One concept, a module deleted and awaiting its purge, is the record's `draining` as segments for holders and the table's `unpurged` as namespaces for inputs, and their free numbers are `free_holders` in the record and `free_inputs` in the table.
    - Shown by: none
    - Fix: Leave the retry to collected/1, and keep pending modules and free numbers of both kinds in one place and one form.

28. **is_module_file/2 and session_module/1 restate the rule that names an Erlang module, which ern_namespace:erlang_module/1 owns**
    - Place: erl/cli/src/ern_shell.erl:1012, and 2342
    - Quote: "Beam = \"ern@\" ++ lists:flatten(lists:join(\"@\", filename:split(Relative))) ++ \".beam\","
    - Wrong: The first spells the module's file name from its path, and the second hard-codes the rule's lower-casing of `$Bindings` and `$Input` as `ern@$bindings` and `ern@$input`. A change to the rule breaks both unseen.
    - Shown by: none
    - Fix: Give ern_namespace a string form of the name, and use it in both.

29. **Several names do not say the value they give, and yes-or-no functions do not read as the question**
    - Place: erl/cli/src/ern_shell.erl:242, 1281, 768, 2207, 2199, 2335, 2342, 369, 1775
    - Quote: "which(Text, Diagnostic, DeclarationDiagnostic) ->"
    - Wrong: docs/style.md: a function that gives a value is that value, and a yes-or-no reads as the question. `which/3` and `within/1` name neither the diagnostic nor the enclosing call they give. `words/1`, `open/2`, `unbound/1`, `session_segment/1` and `session_module/1` answer yes or no without `is_`. `carries_reply/4` reads as yes or no and gives a refusal, and `kept_values/2` gives a message.
    - Shown by: none
    - Fix: Rename them for what they give: likelier_diagnostic, enclosing_call, is_name, is_open, is_unbound, is_session_segment, is_session_module, reply_refusal, kept_values_text.

30. **`Held`, `Source`, `Modules`, `Bound`, `Changed`, `Sourceless` and `Unpurged` each name two or three things**
    - Place: erl/cli/src/ern_shell.erl:2167, 2232, 2279, 951, 1669; 158, 1515, 1588; 1825, 1618, 1640; 484, 2216; 1828, 1938; 1832, 1891; 528-529
    - Quote: "{Purged, Held} = lists:partition(fun(Segment) -> Purgeable([Segment]) end,"
    - Wrong: docs/style.md: two concepts never share a name. `Held` is the modules a value's functions belong to, the holders awaiting their purge, and an interface's namespace. `Source` is an input's origin, a file's text and a file's path. `Modules` is the record field from a loaded namespace to its source's hash, bound elsewhere as `Loaded`, and a list of compiled `{Namespace, Beam, Hash}`. `Bound` is a session and a list of bindings. `Changed` and `Sourceless` are each two things in reload/1 and compile_all/2. release/3 names one pending namespace and the list left pending `Unpurged`.
    - Shown by: none
    - Fix: Give each concept its own name, the field `modules` one that says it holds source hashes.

31. **A refusal ends in a line feed for `:load` and `:reload` and not for `:forget`, `:browse` and `:doc`; `:browse` also keeps a trailing dot `:load` drops**
    - Place: erl/cli/src/ern_shell.erl:1571, against 909, 930 and 1065
    - Quote: "A refusal ends in a line feed, as a diagnostic the compiler gives does,"
    - Wrong: The foreign interface gives refusals in two shapes, so the shell's Ernest must know each command's. browse/2 names the text as given where load/2 names it `without_dot`.
    - Shown by:
      ```
      > :browse Zqx.
      > no module Zqx. is in scope
      > :load Zqx.
      > no module Zqx under the source root or on the load path
      ```
    - Fix: Give every refusal one shape, and name the module without its dot in browse/2.

32. **fields/1 numbers the session's next input before checking, though check_module/6 never reads the number and the session is dropped**
    - Place: erl/cli/src/ern_shell.erl:1140
    - Quote: "check_module(Session#session{last_input = Session#session.last_input + 1},"
    - Wrong: The namespace `['$Fields']` is given, and the session check_module/6 gives back is thrown away, so the update does nothing a reader can find.
    - Shown by: none
    - Fix: Pass `Session`.

33. **refused_compiled/2 passes the working directory where ern_build:stdlib_hash/1 takes a source root, with no word on why**
    - Place: erl/cli/src/ern_shell.erl:1657
    - Quote: "StdlibHash = ern_build:stdlib_hash(\".\"),"
    - Wrong: stdlib_hash/1 (erl/cli/src/ern_build.erl:551) answers `none` for the standard library's own source root. The session's source root is `--source-root`, not `.`, so the meaning of the argument here is left to guess.
    - Shown by: none
    - Fix: Pass the session's source root, or say why the working directory is meant.

34. **Two code comments carry a defect's history, where docs/style.md has a comment say why and cite the report**
    - Place: erl/cli/src/ern_shell.erl:1874, and 2057
    - Quote: "A regression: a module that used a changed interface kept running against the previous one, and faulted."
    - Wrong: A history of what once went wrong belongs to the test that guards it. In the code it adds nothing to the rule the function implements.
    - Shown by: none
    - Fix: Move both histories to the tests' comments.

35. **ern_shell.erl does five jobs in 2504 lines, where docs/style.md gives a module one**
    - Place: erl/cli/src/ern_shell.erl:1
    - Quote: "The shell's front end (report §11.2, plan MVP 2.6)"
    - Wrong: It checks and runs inputs, collects the session's modules, answers completion and documentation, compiles, loads and reloads modules, and is the screen's sink. Each has its own state and helpers, and the sections share little but the session.
    - Shown by: none
    - Fix: Split it along those jobs.

36. **Test comments cite entries of a findings.md that no longer exists, and plan item numbers, which a reader cannot open**
    - Place: test/ern_shell_tests.erl:138, 170, 193, 205, 232, 249, 269, 297, 332, 411, 640, 725, 831, 855, 2043, 2078, 2497; test/ern_terminal_tests.erl:52, 132
    - Quote: "(findings.md's T15)"
    - Wrong: docs/findings.md is gone once a review's findings close, and "item 54" or "step 10 of MVP 2.65" names no section. The citations point at nothing.
    - Shown by: none
    - Fix: Name the behaviour or the report section instead.

37. **ern_pty.py's comment on its `pty` import no longer holds**
    - Place: test/ern_pty.py:48
    - Quote: "import pty as _pty  # after the arguments, so a stray ./pty.py cannot shadow it"
    - Wrong: The import stands at the top, before any argument is read, and no position of it keeps a `pty.py` beside the script from shadowing the module, since the script's directory heads `sys.path`.
    - Shown by: none
    - Fix: Import `pty` plainly and drop the comment.

38. **The two test modules each write their own copy of the harness's helpers**
    - Place: test/ern_terminal_tests.erl:210-258, and test/ern_shell_tests.erl:2696-2748
    - Quote: "steps_file(Steps) ->"
    - Wrong: steps_file/1, step/1, sh/1, collect/2, count/2 and the call of ern_pty.py are written twice, differing in how a command is quoted and in whether the status is read (finding 19).
    - Shown by: none
    - Fix: Put the harness's helpers in one module that both tests use.

39. **review_completion_test_ is named for where its cases came from and tests five behaviours**
    - Place: test/ern_shell_tests.erl:1169
    - Quote: "review_completion_test_() ->"
    - Wrong: docs/style.md: a test function tests one behaviour and is named after it. This one tests fields in a pattern, a lone constructor's listing, `:forget` in completion, and that an input's module and an operator are not offered.
    - Shown by: none
    - Fix: Split it into tests named for each behaviour.

40. **The shell's tests leave their homes, sources and inputs under /tmp, and their step files under test/build**
    - Place: test/ern_shell_tests.erl:2379, and 2729
    - Quote: "filename:join(\"/tmp\", Prefix ++ os:getpid() ++ \"_\""
    - Wrong: Every run adds dozens of directories that no test removes but output_to_a_file_test_ and output_appends_test_.
    - Shown by: none
    - Fix: Remove each test's directory as it ends, or make them under a build directory that is cleaned.

### C, part 6, the rest of the command line; its 1 to 33 are C176 to C208

#### Defects

1. **`ern run` and `ern test` refuse every program when the working directory is the standard library's source root, since the runner hashes the library through a source root.**
   - Place: erl/cli/src/ern_cli.erl:1113, with erl/cli/src/ern_build.erl:551 (the shell does the same at erl/cli/src/ern_shell.erl:1657)
   - Quote: "load(Namespace, LoadPath, Loaded, ern_build:stdlib_hash("."))." and "case is_stdlib_root(SourceRoot) of true -> none;"
   - Wrong: `stdlib_hash(".")` answers `none` when `.` is `stdlib/`, so `same_stdlib/3` takes every module built against the real hash as built "against another standard library". A launch's working directory decides whether the program loads, and §11.2 says nothing like that.
   - Shown by:
     ```
     $ cd C6/run && ern build hello.ern && ern run hello.erc      # hi, status 0
     $ cd ~/projects/ernest/stdlib && ern run .../C6/run/hello.erc
     ern run: Hello was compiled against another standard library; build Hello again
     (status 1; ern test gives the same refusal)
     ```
   - Fix: the runner asks for the installed library's hash with no source root, and only the build passes `none` for the library's own root.

2. **In a directory build, one module's namespace clash, stale or unbuilt dependency, or `.erc` held by another module stops every other module, against §11.1.**
   - Place: erl/cli/src/ern_build.erl:74-86 (`build_step`), 261-269 (`parse_all`); the throws at 310, 638, 643, 538
   - Quote: "throw:{errors, File, Diagnostics} ->" (the only class either catches; `fail/1` throws `{cli_error, _}`)
   - Wrong: §11.1: "A module that does not compile does not stop the others: every module is compiled but one that uses a module that failed, and every failure is reported." A `cli_error` escapes both folds, so the job ends at the first one. Modules that do not depend on it are neither compiled nor checked, and their errors are not reported.
   - Shown by:
     ```
     # src/util.ern built, then removed; src/a.ern uses Util; src/zed.ern fine; src/y.ern a type error
     $ ern build --build-root build src
     ern build: no module Util: build/util.erc was compiled from src/util.ern, which no longer exists
     $ ls build            -> util.erc   (no zed.erc, no report of y.ern)
     # src/main.ern declares type Stack beside src/main/stack.ern, plus zed.ern and a failing other.ern
     ern build: main/stack.ern and type Stack in main.ern share the namespace Main.Stack (report §4.2)
     (nothing built, other.ern's error unreported)
     ```
   - Fix: catch `{cli_error, Message}` in `parse_all` and `build_step` as well, and record it as that module's failure, reported with the rest.

3. **`ern doc` takes any doc block whose text ends in "since" and a digit as a `since v` line, even mid-sentence. It renders a wrong *Since* and cuts the sentence.**
   - Place: erl/cli/src/ern_page.erl:151 (`split_since`, used by every page, the manual page, and the shell's `since/1`)
   - Quote: "re:run(Doc, "^(.*?)\\n?since ([0-9][0-9A-Za-z.+-]*)\\s*$", [dotall, ..."
   - Wrong: the `\n` is optional, so `since` need not begin a line. E.0 shape rule 6 says a doc block "ends with the line `since v`".
   - Shown by:
     ```
     /// The seconds elapsed since 1970
     export fn epoch() : Int = ...
     $ ern doc epochs.ern
     ## Epochs.epoch ... *Since 1970.*

     The seconds elapsed
     ```
   - Fix: take the block's last line and treat it as a `since` line only when the whole line is `since v`.

4. **The build's and `ern doc`'s sweep lists the build tree with `file:list_dir`. A name there that is not UTF-8 makes the host print its own WARNING REPORT on standard output.**
   - Place: erl/cli/src/ern_build.erl:720 (`outputs/2`)
   - Quote: "case file:list_dir(Dir) of"
   - Wrong: `sources/1` uses `list_dir_all` for exactly this reason (ern_cli_tests' name_not_utf8_test: "the host left such a name out with a warning of its own on standard output"). The sweep went back to the call that warns. The host's text then appears among a job's output, depending on whether the host flushes it before it halts.
   - Shown by:
     ```
     $ touch "build/notes$(printf '\377').txt"; ern build --build-root build src 2>/dev/null
     =WARNING REPORT==== 4-Oct-2026::10:13:22.073157 ===
     Non-unicode filename <<"notesÿ.txt">> ignored
     ```
   - Fix: use `file:list_dir_all` in `outputs/2` and pass over a binary name, as `files_under/2` does.

5. **The launcher refuses every working directory as "not UTF-8" on a host where `iconv` is not on the path.**
   - Place: bin/ern:30
   - Quote: "if ! pwd -P | iconv -f UTF-8 -t UTF-8 >/dev/null 2>&1; then"
   - Wrong: a missing `iconv` fails the pipeline the same way a bad name does, so the message names the wrong cause and `ern` cannot start at all. The script checks for `erl` but not for `iconv`.
   - Shown by:
     ```
     $ PATH=<every tool of /usr/bin and /bin but iconv>:/usr/local/bin bin/ern --version
     ern: the working directory's name is not UTF-8        (status 1, in an ASCII directory)
     ```
   - Fix: check for `iconv` as for `erl` and name it when it is missing, or test the bytes without it.

6. **`make load` counts the rows of four of the runtime's six tables, so a leak in `ern_callees` or `ern_deliveries` passes as flat.**
   - Place: test/ern_load.erl:112, against erl/runtime/src/ern_rt.erl:1547-1552
   - Quote: "rows => rows(ern_processes) + rows(ern_calls) + rows(ern_faults) + rows(ern_held),"
   - Wrong: the header says that after the warm-up nothing may grow, "the rows of the runtime's tables" among it. `make_tables/0` also makes `ern_callees` and `ern_deliveries`, and nothing counts them. The memory check's 128 KB of noise hides a slow growth of rows.
   - Shown by:
     ```
     $ grep -n 'ets:new(' erl/runtime/src/ern_rt.erl
     ... ?PROCESSES ?CALLS ?CALLEES ?FAULTS ?HELD ?DELIVERIES
     ```
   - Fix: count every table the runtime makes, from one list the runtime exports, so that a table added later is counted too.

7. **The installation test hard-codes version 0.2.0 three times, so the release that bumps VERSION fails `make test`. The archive test beside it reads VERSION.**
   - Place: test/ern_integration_tests.erl:403, 409, 436
   - Quote: "<<"</picture>\n\n# Ernest 0.2.0\n">>" and "{0, <<"ern 0.2.0\n">>}"
   - Wrong: the expected text is the release's own version, which `release/0` (line 466) reads from `../VERSION`. `install/0` fixes it in the source instead.
   - Shown by: none
   - Fix: read VERSION once, as `release/0` does, and build the three expected texts from it.

8. **The suites' `tmp()` directories under /tmp are never removed. A concurrent run's `tmp()` can delete another host's directory of the same number.**
   - Place: erl/cli/test/ern_cli_tests.erl:20-24, test/ern_guide_tests.erl:465-470
   - Quote: "Dir = filename:join(["/tmp", "ern_cli_" ++ integer_to_list(erlang:unique_integer([positive]))]), file:del_dir_r(Dir),"
   - Wrong: every run leaves its directories. A number is unique only within one host, so two runs at once (two checkouts, or two people) share names, and the second one's `del_dir_r` removes the first one's live directory.
   - Shown by:
     ```
     $ ls -d /tmp/ern_cli_* | wc -l     -> 893   (du: 50444 KB)
     $ ls -d /tmp/ern_guide_* | wc -l   -> 1755  (du: 15128 KB)
     ```
   - Fix: one directory per run, named with the OS pid, made at the suite's start and removed at its end.

9. **`make clean` leaves `examples/modules/net/*.erc`, since `**` is `*` under sh. It also leaves `build/pages`, which `make pages` writes.**
   - Place: Makefile:269-272
   - Quote: "examples/*.erc \\ examples/**/*.erc $(EXEC)"
   - Wrong: make runs the recipe with /bin/sh, where `examples/**/*.erc` matches only `examples/*/*.erc`, and `examples/modules/net/` is one level deeper. `build/pages` is missing from the list.
   - Shown by:
     ```
     $ sh -c 'echo examples/**/*.ern' | tr ' ' '\n' | grep -c net/
     0
     ```
   - Fix: `find examples -name '*.erc' -delete`, and add `build/pages` to the `rm -rf`.

10. **The release archive's Makefile sets `CC = cc`, which overrides a `CC` given in the environment, so `CC=clang make` in the unpacked archive still runs `cc`.**
    - Place: tools/release/Makefile:10
    - Quote: "CC = cc"
    - Wrong: an assignment in a Makefile beats the environment, so a packager's compiler is ignored unless it is passed on make's command line. The checkout's Makefile leaves `CC` to the environment.
    - Shown by: none
    - Fix: drop the line; make already defaults `CC` to `cc`.

11. **`stdlib_root_test` builds the whole standard library under EUnit's default five seconds, which the suite's own comment says a whole build exceeded under `make test`.**
    - Place: erl/cli/test/ern_cli_tests.erl:872-877, against the comment at 31-36
    - Quote: "stdlib_root_test() -> ... ern_cli:ern(["build", "--build-root", Dir ++ "/build", "../../../stdlib"])"
    - Wrong: `stdlib_build_sets_its_copy_aside_test_` is wrapped in `{timeout, 60, ...}` because "A build of the whole library ... runs beside every other suite under `make test`, past eunit's five seconds once". The same build here has no wrapper and so can fail under load.
    - Shown by: none
    - Fix: `stdlib_root_test_() -> {timeout, 60, fun stdlib_root/0}.`

12. **`make uninstall`, and `make install` over an old installation, delete whatever stands at each listed path, a `bin/ern` that is no longer Ernest's link among them.**
    - Place: tools/install.sh:142-147, and 113-120 (install uninstalls before its own `bin/ern` check)
    - Quote: "*) rm -f "$root/$f" ;;"
    - Wrong: the check "is there already and is not Ernest's" runs only where no installation is listed. Where one is, `uninstall` has already removed whatever `bin/ern` had become, so the check never fires.
    - Shown by: none
    - Fix: remove `bin/ern` only where it is the link `../lib/ernest/bin/ern`, and run the check for it before `uninstall`.

13. **No test holds the `§x.y` citations of the Erlang sources, the tests and the Makefiles to the report's headings. The citation test reads only Markdown and Ernest.**
    - Place: test/ern_docs_tests.erl:31
    - Quote: "Live = (documents() -- ["docs/findings.md"]) ++ examples() ++ stdlib() ++ shell() ++ tools(),"
    - Wrong: docs/style.md requires every comment to cite the section it implements, and `make sections` counts the tests' citations. A citation in erl/ or test/*.erl that names no heading passes, though one in an Ernest comment would not. Today they all resolve (checked by hand for this part); nothing keeps them so.
    - Shown by: none
    - Fix: add `erl/*/src/*.erl`, `erl/*/test/*.erl`, `erl/*/include/*.hrl`, `test/*.erl` and the Makefiles to `Live`.

#### Clarity

14. **`prelude_namespaces/0` returns the prelude's and the standard library's namespaces, and `dependencies/3`'s comment calls them all "a prelude namespace".**
    - Place: erl/cli/src/ern_build.erl:469-472, 361-371
    - Quote: "prelude_namespaces() -> lists:usort(prelude_only_namespaces() ++ stdlib_namespaces())."
    - Wrong: the name says the prelude's, and the value is every namespace a module may not take. That makes `prelude_only_namespaces` necessary and the comment at 361 false.
    - Shown by: none
    - Fix: rename it `taken_namespaces` (its comment's own words), `prelude_only_namespaces` back to `prelude_namespaces`, and say "a namespace of the prelude or the standard library" at 362.

15. **`built/3` returns the modules that failed, not the modules built.**
    - Place: erl/cli/src/ern_build.erl:65-72, 49
    - Quote: "Failed = built(order(Parsed), Unparsed, BuildModule),"
    - Wrong: a function named for a past participle gives "the value made so" (docs/style.md), and here the value is the failures.
    - Shown by: none
    - Fix: name it `failures/3`, or `build_all/3` with the comment saying it answers the failures.

16. **Code that never runs or is never called: `compile/3`'s `{errors, ...}` catch, the exports `dependency_interface/4` and `write_whole/3`, and `write_at/4`'s second read of the file's info.**
    - Place: erl/cli/src/ern_build.erl:59-60, 15-17, 902-913
    - Quote: "throw:{errors, File, Diagnostics} -> report_errors(Options, File, Diagnostics, ErrorDevice)"
    - Wrong: `parse_all` and `build_step` catch every `{errors, ...}` before it reaches `compile/3`. No module outside ern_build calls `dependency_interface/4`, and only `write_whole/2` calls `write_whole/3`, always with `undefined`. `write_at` calls `file:read_link_info(Place)` twice in a row.
    - Shown by: `grep -rlE 'ern_build:dependency_interface\(|ern_build:write_whole\(' erl shell` finds only `write_whole/2`'s caller in ern_cli.erl:534.
    - Fix: drop the catch clause and the two exports, fold `write_whole/3` into `/2`, and read the info once.

17. **Several yes-or-no functions and a boolean are not named as questions: `dot_name/1`, `stale/3`, `same_file/2`, `journal/0`, and `DirMode`.**
    - Place: erl/cli/src/ern_build.erl:155, 710, 31; erl/cli/src/ern_cli.erl:749, 833
    - Quote: "DirMode = filelib:is_dir(Path),"
    - Wrong: docs/style.md: "a yes-or-no reads as the question, `is_link`". The same modules do this elsewhere (`is_link`, `is_utf8`, `is_stdlib_root`).
    - Shown by: none
    - Fix: `is_dot_name`, `is_stale`, `is_same_file`, `is_journal`, `IsDirectory`.

18. **Functions named for a value also print, and one is a gerund: `reporting/2` returns run options, and `outcome/2`, `shell_outcome/2` and `tree_status/1` write to a device and answer a status.**
    - Place: erl/cli/src/ern_cli.erl:735, 855-863, 870-888, 650-654
    - Quote: "outcome(ErrorDevice, killed) -> io:format(ErrorDevice, "killed~n", []), 1;"
    - Wrong: a function that does something is a verb (docs/style.md). A reader of `Status = outcome(...)` does not expect a line on standard error. `reporting` names neither the value nor the work.
    - Shown by: none
    - Fix: `report_outcome/2`, `report_shell_outcome/2`, `report_tree/1` (or keep the printing apart), and `reported_options/2` for `reporting/2`.

19. **`ern_out:finish/1` names a monitor's reference `Ref`, where the glossary's word is `MonitorRef`.**
    - Place: erl/cli/src/ern_out.erl:26-30
    - Quote: "Ref = erlang:monitor(process, Device),"
    - Wrong: docs/style.md's glossary: "The host's reference to one is a `MonitorRef`".
    - Shown by: none
    - Fix: `MonitorRef`.

20. **One concept has two names: the roots a dependency is found under are `SearchPath` in ern_build and the load path in its own comment and in ern_cli.**
    - Place: erl/cli/src/ern_build.erl:797-799, 39, 803-806; erl/cli/src/ern_cli.erl:364
    - Quote: "SourceRoot is the source root and SearchPath the load path"
    - Wrong: "One concept, one name, in every module" (docs/style.md). The glossary's word is `LoadPath`. Where the build root comes first the value is the build root and then the load path, and the name could say exactly that.
    - Shown by: none
    - Fix: call it `LoadPath` where it is the load path (compile_source), and name the build's `[BuildRoot | LoadPath]` once, with its comment, in one place.

21. **`ern --help` and each job's `--help` differ from §11's synopses. They show Erlang keys as metavariables, hide `--load-path`'s repetition, and misdescribe `test` and `format`.**
    - Place: erl/cli/src/ern_cli.erl:134-144, 287-289, 96-102
    - Quote: "format  lay out modules as the style guide does" and "test    run the tests of a module"
    - Wrong: the usage lines read `[--source-root <source_root>] ... [--load-path <load_path>] [--main <main>]`, where §11.1 and §11.2 write `src-root`, `dir...` and `Qualified.name`. `ern test` takes a directory too. The layout is §11.6's, and docs/style.md says so: the style guide is not its owner.
    - Shown by:
      ```
      $ ern run --help
      Usage: ern run [--config-dir <config_dir>] [--load-path <load_path>]
                     [--main <main>] [--help] file.erc [argument]...
      ```
    - Fix: give each option the report's metavariable and mark the repeatable one; "test  run the tests of a module or of every module under a directory"; "format  lay out modules in the one layout of report §11.6".

22. **Comments cite "Appendix E.0 rule 6" for the `since` line. E.0 has four numbered admission rules, and the `since` line is shape rule 6, as §11.4 cites it.**
    - Place: erl/cli/src/ern_page.erl:148, 216; erl/cli/test/ern_cli_tests.erl:1669, 1680, 1685 (also ern_shell.erl:1089, test/ern_shell_tests.erl:924, 2166)
    - Quote: "%% Appendix E.0 rule 6: a doc block's last line `since v` names the version"
    - Wrong: the citation names one rule two ways, and taken literally it names a rule that does not exist.
    - Shown by: none
    - Fix: "Appendix E.0 shape rule 6" in each.

23. **About twenty test comments cite entries of `findings.md` (T24, C3-17, C14...), a document that is gone, whose identifiers each review reuses.**
    - Place: erl/cli/test/ern_cli_tests.erl:201, 215, 1042, 1055, 1519, 1563, 1785, 1807, 1817, 1835, 1853, 1875; test/ern_integration_tests.erl:44, 78, 111, 685, 1069; test/ern_docs_tests.erl:177; test/ern_style_tests.erl:56
    - Quote: "%% (findings.md's T24)"
    - Wrong: docs/findings.md does not exist at d90a5b3 ("MVP 2.99b closed, and findings.md goes"). A reader cannot look the entry up, and "T24" named a different finding in each review.
    - Shown by: `ls docs/findings.md` gives "No such file or directory".
    - Fix: drop the identifiers. The regression the comment states is enough, or the comment can cite the log entry by title, as some tests already do.

24. **Two comments leave a gap waiting on closed MVP 2.99b: the interrupt's stray host line on its item 5, the unrun launchd checks on its item 10.**
    - Place: test/ern_integration_tests.erl:207-210; test/ern_service_tests.erl:134-136
    - Quote: "a gap whose fix and test wait for MVP 2.99b's item 5 (plan, *Standing gaps*)" and "Written with the unit and not yet run: its checks wait for a Mac (plan, MVP 2.99b's item 10)."
    - Wrong: MVP 2.99b is closed (commit c40943e). Either the gap was settled and the comment is stale, or it is unplanned and recorded only in a comment.
    - Shown by: none
    - Fix: point each comment at the plan entry that now holds the gap, with its date, or remove it where the gap was fixed.

25. **The Makefiles' comments no longer say what the Makefiles do.**
    - Place: Makefile:1-2, 167-177, 320-321; test/Makefile:1-9, 85-87
    - Quote: "# Top-level build. Each application under erl/ has its own src/Makefile; this one just runs them in order."
    - Wrong: the top-level Makefile builds the standard library, the libraries, the shell, the pages, the installation and the release. "The unit tests run first, with the jobs that start no host" puts `test-guide` there, whose sessions start `bin/ern`. test/Makefile says the programs are "compiled with bin/ern build", but they are built in-node through `ern_cli:ern`, and its header leaves out the grammar and typed areas. `make xref`, described as checking citations, runs every test of ern_docs_tests.
    - Shown by: none
    - Fix: rewrite each header for what the file holds now, and either run the citation test alone under `xref` or describe the target as the document tests.

26. **Three test modules' first comments do not state the module's job: ern_integration_tests, ern_docs_tests, and ern_cli_tests, which has none.**
    - Place: test/ern_integration_tests.erl:1-4; test/ern_docs_tests.erl:1-4; erl/cli/test/ern_cli_tests.erl:1-8
    - Quote: "%% Plan, MVP 1: the programs compiled in this node as `ern build` compiles them, and run with bin/ern"
    - Wrong: "A module has one job, which its first comment states" (docs/style.md). ern_integration_tests also covers install, release, signals, streams, locales and Os. ern_docs_tests also covers contents, glossary, licences, the log's index and man/. ern_cli_tests opens on a comment about a macro.
    - Shown by: none
    - Fix: a first comment for each that names its whole job.

27. **The grammar tests' and the typed generator's names are abbreviations a reader must guess, one of which the glossary refuses: `alt`, `nt`, `t`, `opt`, `rep`, `Expr`, `pwild`, `pcon`, `expr_text`.**
    - Place: test/ern_grammar.erl:17-18 (the `expression()` type), throughout test/ern_grammar_tests.erl and test/ern_grammar_programs_tests.erl; test/ern_typed_programs_tests.erl:1041-1078
    - Quote: "-type expression() :: {seq, [expression()]} | {alt, [expression()]} | {opt, expression()} | {rep, expression()} | {nt, atom()} | {t, string() | atom()}."
    - Wrong: docs/style.md: "No abbreviation a reader must guess", and its glossary lists "Alternative ... Not ... `Alt`". `nt` and `t` read as nothing without the comment.
    - Shown by: none
    - Fix: `sequence`, `choice` or `alternatives`, `optional`, `repetition`, `nonterminal`, `terminal`, `Expression`; `wildcard_pattern` and the like for the `p*` tags.

28. **Helpers are written twice with diverging shapes: `fix/2` and `nonterminals/1` in both grammar suites, and `is_editor_file/1` and `read/1` in ern_docs_tests and ern_style_tests.**
    - Place: test/ern_grammar_tests.erl:169-190, test/ern_grammar_programs_tests.erl:356-397; test/ern_docs_tests.erl:314, 351; test/ern_style_tests.erl:326, 346
    - Quote: "is_editor_file(File) -> lists:member(hd(filename:basename(File)), ".#")." vs "is_editor_file([Char | _]) -> Char =:= $. orelse Char =:= $#."
    - Wrong: one takes a path and the other a basename, and one `read/1` answers a binary and the other a list. A fix to one copy misses the other.
    - Shown by: none
    - Fix: the grammar helpers to ern_grammar, which both suites already read; one `read` and one editor-file test where the two document suites share them.

29. **The typed generator keeps its name counter and the reply round's declarations in the process dictionary, so a function that returns text also declares helpers as a side effect.**
    - Place: test/ern_typed_programs_tests.erl:101, 356-360, 594-595, 997-1000
    - Quote: "declare(Declaration) -> put(declarations, [Declaration | get(declarations)])."
    - Wrong: `consumed/3` and `plain/3` read as pure text builders, but what `reply_program/4` writes depends on the order they ran in. That is the invisible state docs/style.md keeps out of the toolchain's data.
    - Shown by: none
    - Fix: return the declarations with the text, and thread the counter through the generator, or say at `plain/3` that it declares.

30. **`ern_load:main/1` decides its exit status from the shape of the verdict's text, not from the verdict.**
    - Place: test/ern_load.erl:36-45
    - Quote: "halt(case Verdict of [Name, _] -> 0; _ -> 1 end)."
    - Wrong: the status depends on `io_lib:format` never answering a two-element list headed by the load's name, which is a property of the text and not of the run.
    - Shown by: none
    - Fix: compute `Flat = {Status, verdict(Samples)} =:= {0, []}` once, and use it for both the text and the status.

31. **The recognizer's test says every derived program is a sentence of the grammar, but it checks only the first 200 of more than a thousand.**
    - Place: test/ern_grammar_programs_tests.erl:92-100
    - Quote: "%% The recognizer itself: every program the grammar derives is a sentence of it" ... "lists:sublist(Programs, 200)"
    - Wrong: the comment claims more than the code checks, and the near-miss oracle trusts the recognizer on all the programs.
    - Shown by: none
    - Fix: check them all, or say "the first two hundred, the smallest" and why that is enough.

32. **The helper's C flags differ between the two Makefiles without a word: the release build drops `-Werror`, and the checkout's `CC ?= cc` changes nothing, since make predefines `CC`.**
    - Place: tools/release/Makefile:17; Makefile:21
    - Quote: "$(CC) -std=c99 -pedantic -O2 -Wall -Wextra -o $(HELPER) ern_exec.c"
    - Wrong: docs/style.md says the helper "compiles with `-pedantic -Wall -Wextra -Werror`". Dropping it on another machine's compiler may be right, but the reason is not stated. `?=` reads as setting a default it never sets.
    - Shown by: none
    - Fix: one comment line in tools/release/Makefile saying why `-Werror` is left out, and drop `CC ?= cc`.

33. **`entry_point/4` returns the Erlang module, and `entry_namespace/1` then rebuilds the namespace from that module's name, though the namespace was in hand.**
    - Place: erl/cli/src/ern_cli.erl:1032-1051, 1102-1108
    - Quote: ""ern@" ++ Path = atom_to_list(ErlangModule), ern_build:namespace(string:split(Path, "@", all))."
    - Wrong: the round trip runs the name rule backwards to recover a value the caller had. A reader has to check that the round trip gives back the same namespace.
    - Shown by: none
    - Fix: have `entry_point/4` return the entry's namespace beside its Erlang module, and drop `entry_namespace/1`.

### E, part 1, the standard library; its 1 to 34 are E1 to E34

#### Defects

1. **`ern doc` prints every foreign primitive's type without its restrictions, so the stdlib pages disagree with `:type`: `Map.get` shows no `k=`, `Clock.monotonic` no `m+`.**
   - Place: stdlib/map.ern:65 (its page, and `man/stdlib/map.md:80`), stdlib/clock.ern:56, and every `export foreign fn` of stdlib/; §11.4, §11.5, §4.7
   - Quote: "Map.get : (Map(k, v), k) -> Optional(v)"
   - Wrong: §11.5 says `ern doc` prints restrictions as the compiler does, and §4.7 gives a foreign function's variables `!` and its own effect `m+`. On one page `Map.contains` reads `(Map(k=!, v!), k=!)` and `Map.get` reads `(Map(k, v), k)`; on Clock's page `now` is `with m+` and `monotonic` is `with m`, which by §11.5's own printing rule would mean a pure function. The same holds for `Set.put`, `Set.contains`, `Foreign.from`, `Io.show`, `Io.debug`, `Process.info`, `Process.live`, `Os.exit`.
   - Shown by:
     ```
     $ printf ':type Map.get\n:type Clock.monotonic\n' | bin/ern shell
     > Map.get : (Map(k=!, v!), k=!) -> Optional(v!)
     > Clock.monotonic : () -> Int with m+
     $ bin/ern doc build/stdlib/map.erc | grep '^Map.get :'
     Map.get : (Map(k, v), k) -> Optional(v)
     $ bin/ern doc build/stdlib/clock.erc | grep 'Int with'
     Clock.now : () -> Int with m+
     Clock.monotonic : () -> Int with m
     ```
   - Fix: make `ern doc` print a foreign function's scheme with §4.7's restrictions, as the shell's `:type` already does.

2. **`Io.show`'s and `Io.debug`'s pages say `Io.show` at a type variable is a type error, hiding `needs a.show`, the one way a generic function shows its argument.**
   - Place: stdlib/io.ern:172, stdlib/io.ern:188; Appendix E.1
   - Quote: "so that in a generic function `Io.show` at the function's type variable is a type error"
   - Wrong: E.1 admits a type variable whose requirement names `show`, and the compiler accepts it; a programmer reading the page concludes that a generic `describe` cannot be written.
   - Shown by:
     ```
     fn describe(value : a) : String needs a.show = "<" <> Io.show(value) <> ">"
     export fn main() : Unit with Never = Io.println(describe(Some(3)))
     $ bin/ern build showreq.ern && bin/ern run showreq.erc
     <Some(3)>
     ```
   - Fix: say on both pages that the type is known whole or is a type variable the declaration's `needs a.show` names, with an example of it.

3. **`Terminal.Event`'s page writes `Enter` as if it were a constructor and never says which `Char` Enter and Backspace arrive as, so a program cannot match them.**
   - Place: stdlib/terminal.ern:38; §8.2 *Keys*
   - Quote: "a key, `Enter` and Backspace among them as their characters"
   - Wrong: there is no `Terminal.Enter`; §8.2 alone says Enter is `Key('\r')` or `Key('\n')`, Backspace `Key('\u{7f}')` or `Key('\u{8}')`, Tab `Key('\t')`. Every line editor needs these, and the page that documents `Event` leaves them out.
   - Shown by: none
   - Fix: name the characters on the page, `Key('\r')` or `Key('\n')` for Enter and `Key('\u{7f}')` or `Key('\u{8}')` for Backspace, with an example that matches Enter.

4. **`since` lines name versions the declarations were not in: OrderedSet and OrderedMap say 0.2.0, and `Char.isAsciiDigit` and `Os.user`, both new after 0.2.0, inherit 0.1.0.**
   - Place: stdlib/ordered_set.ern:40, stdlib/ordered_map.ern:26, stdlib/char.ern:27, stdlib/os.ern:143; also stdlib/tcp.ern:66 and :244, stdlib/fs.ern:306, stdlib/os.ern:107; E.0 shape rule 6
   - Quote: "since 0.2.0"
   - Wrong: v0.2.0 has neither `ordered_set.ern` nor `ordered_map.ern`, nor `isAsciiDigit` nor `Os.user`; they ship first in the next release. `Tcp.SocketMsg`, `Tcp.remote`, `Fs.makeFile` and the function `Os.environment` appeared in 0.2.0 under these names (0.1.0 had `SockMsg`, `peer`, `create` and a `Map` binding) and inherit the module's 0.1.0.
   - Shown by:
     ```
     $ git show v0.2.0:stdlib/ordered_set.ern
     fatal: path 'stdlib/ordered_set.ern' exists on disk, but not in 'v0.2.0'
     $ git show v0.2.0:stdlib/char.ern | grep -c isAsciiDigit
     0
     ```
   - Fix: give the two modules and the two declarations the next release's `since`, and the four renamed declarations `since 0.2.0`.

5. **Functions that fault have no `### Errors` section: `Io.readLine`, `Io.read`, `Terminal.subscribe`, `Fs.removeAll`, `Os.start`, `Os.run`, `Int.shiftLeft`.**
   - Place: stdlib/io.ern:118, stdlib/io.ern:132, stdlib/terminal.ern:80, stdlib/fs.ern:325, stdlib/os.ern:193, stdlib/os.ern:327, stdlib/int.ern:125; E.0 shape rule 6, §7.4
   - Quote: "a line that is not faults the caller"
   - Wrong: shape rule 6 asks for an `Errors` section wherever a function faults. `readLine` and `read` fault with `the standard input is not UTF-8`, `the terminal is already read as keys` and the shell's `the shell holds the terminal; ...`; `subscribe` with `the terminal is already read as lines`; `removeAll`, `start` and `run` where the helper fails, which their prose mentions in passing. `Int.shiftLeft` with a large count faults with a cause that names an Erlang function the program never wrote.
   - Shown by:
     ```
     > Int.shiftLeft(1, 100000000000)
     > fault: foreign function erlang:bsl/2 raised error:system_limit
     ```
   - Fix: add an `Errors` section to each, with the causes §7.4 gives.

6. **`Io.Error`'s page gives `NotATerminal` as standard input alone and `Invalid` as U+0000 or a port, though `Terminal.size` and `Fs.setMode` answer them otherwise.**
   - Place: stdlib/io.ern:31, stdlib/io.ern:35; Appendix E.1, E.16, E.17
   - Quote: "`NotATerminal`, standard input is not a terminal"
   - Wrong: `Terminal.size` answers `Left(NotATerminal)` where standard output is not a terminal (E.16), and `Fs.setMode` answers `Left(Invalid)` for a mode outside 0 to `0o7777` (E.17). E.1's own sentence on `Invalid` has the same gap.
   - Shown by: none
   - Fix: say "standard input or standard output is not a terminal", and add "a mode out of range" to `Invalid`, in E.1 and on the page.

7. **`Map.mergeWith`'s example shows `Map.toList` of two keys in sorted order, an order E.3 leaves unspecified, where Set's examples sort first.**
   - Place: stdlib/map.ern:195; Appendix E.3
   - Quote: "// => [#("a", 3), #("b", 2)]"
   - Wrong: the example holds only because a small Erlang map is sorted; past 32 keys it is not, so the page teaches an order the module does not promise. Set's page wraps every multi-element `toList` in `List.sort` for this reason.
   - Shown by:
     ```
     > List.take(Map.keys(Map.fromList(List.map(List.range(1, 40), fn(n) = #(n, n)))), 8)
     > [18, 4, 34, 12, 19, 29, 13, 2] : List(Int)
     ```
   - Fix: sort the result as Set's examples do, or show `Map.get` of the merged keys.

8. **`Tcp.write`'s `### Errors` section lists its `Left` answers, `Timeout`, `Closed` and `Other`, which are values, beside the one fault.**
   - Place: stdlib/tcp.ern:197; E.0 shape rules 4 and 6
   - Quote: "Answers `Left(Timeout)` when `ms` milliseconds pass first"
   - Wrong: shape rule 6 keeps `Errors` for faults; every other function of the module, `read` among them, states its `Left`s in the sentence and its fault under `Errors`. The fault is also narrowed to "closed with `Tcp.close`", where the others say "ended, closed or killed".
   - Shown by: none
   - Fix: move the three `Left` answers into the doc's sentence and leave under `Errors` the fault on a socket that has ended, closed or killed.

9. **`Int.bitNot` is a `foreign fn` though its own doc gives its Ernest body, `-int - 1`.**
   - Place: stdlib/int.ern:121; Appendix E.8, E.0 rule 1
   - Quote: "Bitwise complement, `-int - 1`."
   - Wrong: E.0 rule 1 admits no primitive for work Ernest writes at a bounded multiple of the host's cost; negation and subtraction are the prelude's.
   - Shown by:
     ```
     fn bitNot(int : Int) : Int = -int - 1
     // equal to Int.bitNot on 0, 1, -1, 6, -7 and two 30-digit numbers: true
     ```
   - Fix: write `bitNot` as `-int - 1` and drop it from E.8's primitives.

10. **`Float.floor` and `Float.ceil` are foreign though Ernest writes them over `Float.truncate`, as `Float.round` is already written over `floor`.**
    - Place: stdlib/float.ern:142, stdlib/float.ern:146; Appendix E.9, E.0 rule 1
    - Quote: "export foreign fn floor(float : Float) : Int ="
    - Wrong: E.0 rule 1 admits a primitive only where the Ernest form's cost grows with something the host's does not; one truncation, one conversion and one comparison is a bounded multiple.
    - Shown by:
      ```
      fn floor(float : Float) : Int = {
          let truncated = Float.truncate(float);
          if Int.toFloat(truncated) > float then truncated - 1 else truncated
      }
      // with ceil likewise: equal to Float.floor and Float.ceil on ±2.5, ±0.5, ±1.0e300,
      // ±4503599627370495.5 and ±5.0e-324: true
      ```
    - Fix: write `floor` and `ceil` in Ernest over `truncate` and drop them from E.9's primitives.

11. **`String.toList` and `String.fromUtf8` are foreign though the bit syntax's `utf8` segment decodes UTF-8, over the primitives `toUtf8` and `fromList`.**
    - Place: stdlib/string.ern:498, stdlib/string.ern:517; Appendix E.5, E.0 rule 1, §5.11
    - Quote: "export foreign fn toList(text : String) : List(Char) ="
    - Wrong: `<<char:utf8, rest:bytes>>` binds a `Char` and refuses surrogates and overlong forms, so both are Ernest at a cost that grows as the host's does. `toList` measured twice the host's cost; `fromUtf8` about a hundred times, still linear, which the decisions log must weigh under rule 1 with these numbers.
    - Shown by:
      ```
      fn decoded(bytes : Bytes, acc : List(Char)) : Optional(List(Char)) =
          match bytes {
              <<char:utf8, rest:bytes>> -> decoded(rest, char :: acc)
            | <<>> -> Some(List.reverse(acc))
            | _ -> None
          }
      // fromUtf8 of <<0xED, 0xA0, 0x80>> and <<0xC0, 0x80>>: None, None
      // 1.2 MB of text: host fromUtf8 2 ms, Ernest 236 ms; host toList 36 ms, Ernest 70 ms
      ```
    - Fix: write `toList` in Ernest over `toUtf8`, and decide `fromUtf8` by rule 1 with the measurement beside it.

12. **`Int.toString` and `Int.toStringBase` are host shims, though Ernest writes digits over `/` and `%`, as `String.toIntBase` already reads them back in Ernest.**
    - Place: stdlib/int.ern:150, stdlib/int.ern:185; Appendix E.8, E.0 rule 1
    - Quote: "export foreign fn toString(int : Int) : String ="
    - Wrong: an `Int` and its text are the language's, not the runtime's representation; halving the digits, as string.ern's `valueOf` does for the inverse, keeps the cost a bounded multiple of the host's.
    - Shown by:
      ```
      // digits(n): below 10^18 by repeated / 10, above by n / 10^k and n % 10^k, k doubled from 18
      // 7^200000 - 12345, 169020 digits: Int.toString 134 ms, Ernest 272 ms, equal: true
      ```
    - Fix: write both in Ernest, by halves, and drop "the writing in a base" from E.8's primitives.

13. **`String.words` splits at a space inside a grapheme, where `trim` and every search take whole graphemes: `words("a \u{301}b")` gives a word beginning with a combining mark.**
    - Place: stdlib/string.ern:323; Appendix E.5
    - Quote: "List.reverse(wordsFrom(toList(text), [], []))"
    - Wrong: the module says every search matches whole graphemes and that a trim removes graphemes whose first code point is White_Space; `words` reads `Char`s, so the grapheme `" \u{301}"` is whitespace to `trim` and a boundary plus a letter to `words`.
    - Shown by:
      ```
      > String.words("a \u{301}b")
      > ["a", "́b"] : List(String)
      > String.trim(" \u{301}b")
      > "b" : String
      ```
    - Fix: split `graphemes(text)` at the graphemes whose first code point is White_Space, as `trim` judges them, and say so in E.5.

14. **`Fs.Entry`'s first example and both of Test's examples can run but end in no `// =>` line, and Test's two examples repeat one another.**
    - Place: stdlib/fs.ern:56, stdlib/test.ern:10, stdlib/test.ern:22; E.0 shape rule 6
    - Quote: "Fs.Entry(path = Path("a.txt"), mtime = 0, size = 5, kind = Fs.File, mode = 0o644, user = 0)"
    - Wrong: shape rule 6 drops `// =>` only for a value of an abstract type, a file or socket read, or a mailbox of its own; these are plain constructions, and an example that would repeat another is left out.
    - Shown by: none
    - Fix: end each in its `// =>` value, `Case(name = "adds", run = <function>)` among them, and keep one of Test's two examples.

15. **Report §10 cites Appendix E.4, the `Set` module, for the Unicode tables behind a `Char`'s category and case, which are E.6's.**
    - Place: report/language.md:889, §10
    - Quote: "(Appendix E.4, E.5, E.16)"
    - Wrong: E.4 is `set.ern`; `Char`'s properties are E.6.
    - Shown by: none
    - Fix: cite Appendix E.6, E.5, E.16.

#### Clarity

16. **The prelude's `answer` is rebound as a value in three places, one in the module that answers replies on every other line.**
    - Place: stdlib/supervisor.ern:170, stdlib/fs.ern:386, stdlib/tcp.ern:35, stdlib/tcp.ern:158; docs/style.md, glossary, *Ernest*
    - Quote: "Some(answer) -> answer"
    - Wrong: the glossary says a prelude name, `answer` among them, is not bound to another concept; in supervisor.ern `answer` is a `Bool` three lines from `answer(reply, ...)`, fs.ern names a parameter `answer`, and Tcp's page examples teach `let answer = Tcp.read(...)`.
    - Shown by: none
    - Fix: name them for what they hold: `runsGroup`, `answered`'s `outcome`, `echoed`, `accepted`.

17. **OrderedSet and OrderedMap name the callback of `any`, `all` and `find` `keep`, where the glossary and List, Map and Set name it `test`.**
    - Place: stdlib/ordered_set.ern:209, :214, :225; stdlib/ordered_map.ern:224, :229, :240; docs/style.md, glossary
    - Quote: "export fn any(Set(list) : Set(a), keep : (a) -> Bool with e)"
    - Wrong: the glossary keeps `keep` for a predicate that keeps and gives `test` to one asked of each element, naming `any`, `all` and `find`; the shell and `ern doc` show the parameter.
    - Shown by: none
    - Fix: rename the six parameters `test`.

18. **`OrderedMap`'s merge names the second map's key `theirs` and its value `value`, beside `mine` for the first's value; the page's example uses `mine` and `theirs` for values.**
    - Place: stdlib/ordered_map.ern:276
    - Quote: "#(#(key, mine) :: rest, #(theirs, value) :: more) -> match k.compare(key, theirs) {"
    - Wrong: `theirs` reads as the other value and is a key; `value` reads as the first's and is the other's, so `f(key, mine, value)` must be traced to be believed.
    - Shown by: none
    - Fix: name them `#(key, value)` and `#(otherKey, otherValue)`.

19. **Supervisor declares two linked lists of its own, `Held` (`Holding`/`Nobody`) and `Waiting` (`Waiting`/`NoOne`), where lists of replies with `List.foreach` and `List.filterMap` compile and run.**
    - Place: stdlib/supervisor.ern:105, :120, :242, :330; §6.6
    - Quote: "type Held = Holding(reply : Reply(Unit), next : Held) | Nobody"
    - Wrong: §6.6 lets a reply stand in a list, and List's functions take one where their restriction allows; the hand-rolled lists are a second way to write a list, with two names for empty, and their walks `settled` and `release` repeat `filterMap` and `foreach`.
    - Shown by:
      ```
      fn release(held : List(Reply(Unit))) : Unit with Msg =
          List.foreach(held, fn(reply) = answer(reply, Unit))
      // settled as List.filterMap over List(#(Reply(Bool), List(Int))): builds, and prints
      // false / released when run
      ```
    - Fix: hold `List(Reply(Unit))` and `List(#(Reply(Bool), List(Process)))` and walk them with `List.foreach` and `List.filterMap`.

20. **Whether an `Optional` holds a value is tested four ways across the library: `match` in Map, `Optional.isSome` in OrderedMap, `!= None` in String and Bytes.**
    - Place: stdlib/map.ern:58, stdlib/ordered_map.ern:81, stdlib/string.ern:106, stdlib/bytes.ern:110
    - Quote: "indexOf(text, part) != None"
    - Wrong: the four `contains` do one thing, and a reader meets three spellings of it, where principle 2 asks for one.
    - Shown by: none
    - Fix: write each as `Optional.isSome(...)`.

21. **String's and Path's module pages name their primitives and private helpers in sentences a programmer cannot parse or use: "the private `drop` and `lastGrapheme`", "`separator`, private".**
    - Place: stdlib/string.ern:6, stdlib/path.ern:4
    - Quote: "The primitives are `isAbsolute` and `separator`, private, the host's separator, both the runtime's"
    - Wrong: the report's section owns which functions are primitives (E.0 rule 1); on the page they name functions the reader cannot call, and String's sentence runs through ten clauses before it reaches what it means for a caller, that searches match whole graphemes.
    - Shown by: none
    - Fix: keep on the page what a caller can act on, "every search matches whole graphemes", and leave the list of primitives to E.5 and E.14.

22. **Supervisor's page spends a paragraph and `Msg`'s doc on the implementation, the watcher, what a child tells, and "the ends of the alarms it sets itself".**
    - Place: stdlib/supervisor.ern:20, stdlib/supervisor.ern:67
    - Quote: "The supervisor does not subscribe to `Process.faults`"
    - Wrong: none of it is a promise a program can rely on or act on; it belongs in `//` comments beside the code, where the module already explains the same mechanism.
    - Shown by: none
    - Fix: move the third paragraph and `Msg`'s list of messages into comments, and say on the page only that `Msg` is what a supervisor takes.

23. **Fs's page examples drop every setup call's `Either` with `let _ =`, thirty times, teaching a program to ignore an `Io.Error`, where Os's and Tcp's examples bind with `<-`.**
    - Place: stdlib/fs.ern:17, :61, :110, :137, :156, :183, :203, :336 and the rest
    - Quote: "let _ = Fs.write(Path("greeting.txt"), String.toUtf8("hello"), 5000);"
    - Wrong: the examples are the page's teaching; `let _ <-` in a block whose value is the `Either` keeps the error and reads as Os's do.
    - Shown by: none
    - Fix: bind setup calls with `let _ <-` and end each example in its `Either`.

24. **Fs's request constructor for `list` is named `List`, on a line that also writes the prelude type `List(Entry)`.**
    - Place: stdlib/fs.ern:76; docs/style.md, glossary
    - Quote: "List(path : Path, reply : Reply(Either(Io.Error, List(Entry))))"
    - Wrong: the glossary's request rule gives `List`, and its prelude-name rule forbids binding `List` to another concept; the reader sees one name as a constructor and a type in one declaration.
    - Shown by: none
    - Fix: name the request `ListDirectory`, and let the glossary's request rule yield to a prelude name.

25. **Random writes 2^64 twice as `18446744073709551616` and 2^52 as `4503599627370496.0`, beside `mask` in hexadecimal, and names a helper `words` for what it is made of.**
    - Place: stdlib/random.ern:70, :75, :106, :109
    - Quote: "words(seed1, bound, value * 18446744073709551616 + draw, span * 18446744073709551616)"
    - Wrong: a reader must count digits to see a power of two, and `words` does not say that it draws until the span covers the bound.
    - Shown by: none
    - Fix: name the constants, `let wordSpan = mask + 1`, and the helper for its result, `drawSpanning`.

26. **`Map.mergeWith`'s doc sentence does not parse: "a shared key given the function of the key, the first's value and the second's".**
    - Place: stdlib/map.ern:189
    - Quote: "The entries of both, a shared key given the function of the key, the first's value and the second's."
    - Wrong: the reader must reconstruct which value the function's result replaces; OrderedMap's says it plainly.
    - Shown by: none
    - Fix: "The entries of both; at a shared key, `f(key, first's value, second's value)`."

27. **`Path.<>` rewrites its first operand, `Path("a//b") <> Path("c")` being `"a/b/c"`, where `withExtension` keeps "the rest as written".**
    - Place: stdlib/path.ern:39; Appendix E.14, §9.6
    - Quote: "if isAbsolute(under) then under else join(split(path) <> split(under))"
    - Wrong: §9.6 says "the second under the first", which a reader takes to keep the first; the page does not say that doubled and trailing separators of the first are dropped.
    - Shown by:
      ```
      > Path.toString(Path("a//b") <> Path("c"))
      > "a/b/c" : String
      ```
    - Fix: say on the page and in E.14 that both operands are rewritten as `split` reads them, or join the second to the first as written.

28. **Random's page points at `List.sort` for "a shuffle written with draws" and shows none, where the reading a programmer predicts, a random comparator, cannot be written.**
    - Place: stdlib/random.ern:24
    - Quote: "`List.sort` for a shuffle written with draws"
    - Wrong: a shuffle needs each element paired with a draw, the seed threaded through a fold, then a sort by the draw; the pointer leaves all of it to guess.
    - Shown by: none
    - Fix: give the shuffle as an example on the module's page, or drop the pointer.

29. **`Os.joined` re-implements `Bytes.join(List.reverse(pieces), <<>>)`.**
    - Place: stdlib/os.ern:371
    - Quote: "List.foldLeft(List.reverse(pieces), <<>>, fn(acc, piece) = acc <> piece)"
    - Wrong: a second way to write a library function the module can call.
    - Shown by: none
    - Fix: `Bytes.join(List.reverse(pieces), <<>>)`.

30. **`Bool.not` is written `if bool then false else true`, where the language's `!bool` says it.**
    - Place: stdlib/bool.ern:20; §4.8
    - Quote: "if bool then false else true"
    - Wrong: the doc itself names prefix `!`; the `if` makes the reader check that the branches are not swapped.
    - Shown by: none
    - Fix: `!bool`.

#### Where the language made the work harder

31. **`Int.pow` answers `Optional` even where the exponent is known non-negative, so string.ern writes a private `power` of its own and a caller unwraps with an invented default.**
    - Place: stdlib/string.ern:445, stdlib/int.ern:162
    - Quote: "// The base to the exponent, 0 or more, by squaring."
    - Wrong: string.ern's private `valueOf` needs a power of the base and re-implements squaring rather than write `Optional.withDefault(Int.pow(base, low), 1)`; writing Int.toString in Ernest (finding 12) I wrote `Optional.withDefault(Int.pow(7, 200000), 0)`, a default that can never be taken. Two copies of exponentiation now differ in shape, and Int's computes one squaring too many at the end.
    - Shown by: none
    - Fix: decide whether a natural-exponent power belongs to Int beside `pow`, or let string.ern call `Int.pow` and accept the unwrap; either way one copy.

32. **No call waits without limit yet answers `None` when the callee ends or restarts, so Supervisor polls with an invisible 1000 ms timeout and a `Process.info` check.**
    - Place: stdlib/supervisor.ern:169, stdlib/supervisor.ern:429; §6.6
    - Quote: "match Address.call(supervisor, request, 1000) {"
    - Wrong: `callForever` faults on a restart in place, and `call` needs a number; the 1000 is no policy of the group, just a value large enough, and a busy supervisor makes the child send its `Join` again, which the watcher's de-duplication then has to absorb.
    - Shown by: none
    - Fix: decide in §6.6 whether `Address.call` without a limit that answers `None` on the callee's end is the program's to write, and if not, comment the constant with why its value does not matter.

33. **`List.tryMap` takes only an `Either` step, so `String.toIntBase` invents a `Left(char)` that it discards to stop at the first non-digit.**
    - Place: stdlib/string.ern:419, stdlib/string.ern:425
    - Quote: "| _ -> Left(char)"
    - Wrong: the step's natural answer is `Optional(Int)`; the code builds an `Either(Char, Int)` and throws its left away, a value made only to satisfy the library's shape.
    - Shown by: none
    - Fix: decide whether E.2's `tryMap` should take an `Optional` step as well, or write `digitIn` to answer `Optional` and test with `List.all` before mapping.

34. **No standard function gives a character's value as a digit in a base, so `String.digitValue` and `Bytes.value` each write the same ranges of `0`-`9`, `a`-`z`, `A`-`Z`.**
    - Place: stdlib/string.ern:454, stdlib/bytes.ern:282
    - Quote: "else if char >= 'a' && char <= 'f' then"
    - Wrong: a module-private function cannot be shared between modules, so the second module copies the first; `Char.isAsciiDigit` was added for one such need, and the digit value is the same need one step further.
    - Shown by: none
    - Fix: weigh a `Char` digit-value function, `(Char, Int) -> Optional(Int)`, against E.0's rules, and let both modules call it.

### E, part 2, the shell; its 1 to 31 are E35 to E65

#### Defects

1. **With standard output piped and standard input a terminal, the shell paints the live region into the pipe instead of reading lines**
   - Place: shell/shell.ern:201-202; report §11.2 *Editing*, Appendix E.16
   - Quote: "match Terminal.size() {"
   - Wrong: §11.2 puts the shell in line mode "when input or output is not a terminal", and `readKeys` decides it by `Terminal.size()`, which E.16 says answers `Left(NotATerminal)` "where standard output is not a terminal". The runtime answers `Right` with standard output a pipe, so `ern shell | tee log` gets key mode, and the log gets cursor moves, erasures and colours.
   - Shown by: in a pseudo-terminal of 24x80, `size.erc` printing `Terminal.size()` to standard error, then the shell typing `1 + 1`:
     ```
     $ ern run size.erc | cat
     Right Size(rows = 24, columns = 80)
     $ ern shell | cat
     ESC[?2004h ESC[J Ernest 0.2.0. ... ESC[J> 1ESC[3C ... ESC[J2ESC[2m : IntESC[22m
     ```
   - Fix: make `Terminal.size` answer `Left(NotATerminal)` for a standard output that is no terminal, as E.16 states, and test the shell under `| cat`.

2. **A fault reported while a line is typed is glued onto that line's prompt, and the input goes on with no prompt**
   - Place: shell/shell.ern:568, reached from `keyLoop` at 509
   - Quote: "say(screen, Shell.Style.fault(state.colour, reportLine(report)));"
   - Wrong: at a prompt `say` sends `Said`, and `Shell.Region.said` commits the pending prompt with the text after it, so the transcript reads `> input 2:1 faulted: late` and the line being typed loses its `> `. `Noted` (region.ern:69) exists for a line written while an input is typed.
   - Shown by: a spawned process that faults 1.5 s later, while `abc` and then `d` are typed:
     ```
     > input 2:1 faulted: late
     abcd
     ```
   - Fix: in `keyLoop`, where a prompt is pending, send the report as `Noted`; keep `Said` in `await`, where none is.

3. **`Tab` with the cursor inside a command's word keeps the text after the cursor beside the completion: `:br|owse` becomes `:browse owse`**
   - Place: shell/shell/complete.ern:42-44, with `applied` at 359-371
   - Quote: "#(commandWord(command, line), command)"
   - Wrong: the typed word handed back is the whole command word, past the cursor, so `applied` takes `wordIndex = cursor - size(typedWord)`, which is negative and which `String.slice` clips to 0. The text after the cursor is kept a second time.
   - Shown by: type `:browse`, `C-b` four times, `Tab`, `Enter`:
     ```
     > :browse owse
     owse is not a module name: each segment of one is words beginning with a capital
     ```
   - Fix: complete the command word up to the cursor, `String.slice(line, 0, cursor)`, and hand that back as the typed word.

4. **`:load` completion inside a namespace of two words lists nothing: `KvParser.` is looked for in `kvparser/`, not `kv_parser/`**
   - Place: shell/shell/complete.ern:172; report §4.2
   - Quote: "fn(path, part) = path <> Path(String.toLower(part))"
   - Wrong: §4.2 writes `KvParser` as `kv_parser`. The first `Tab` offers `KvParser.` through `segment`, and the next looks in a directory that is not there.
   - Shown by: a source root holding `kv_parser/inner.ern` and `http/client.ern`:
     ```
     > :load Http.Client        <- `Http.` and Tab completed it
     > :load KvParser.          <- Tab three times: nothing listed
     no module KvParser under the source root or on the load path
     ```
   - Fix: map a segment to its path component by §4.2's rule, with `_` before each capital after the first and every letter lowercase (item 17 shows it in Ernest).

5. **The live region cuts a program's ended line off at the screen's width, but wraps an unended line of the same text onto more rows**
   - Place: shell/shell/region.ern:84 and 175
   - Quote: "List.map(tailRowsOf(region), fn(line) = clip(expand(line), region.size.columns))"
   - Wrong: `wrote` puts an ended line in the tail whole, and `rowsOf` cuts it off, while `filled` splits an unended one into rows. The live region hides the end of a long line until the line is committed, and two lines a reader cannot tell apart are drawn differently.
   - Shown by: a 24x30 terminal, two background processes printing a 33-character line with `\n` and a 36-character one without:
     ```
     0123456789ABCDEFGHIJ0123456789        <- "xyz" is not shown
     abcdefghijklmnopqrstuvwxyz0123
     456789
     ```
   - Fix: split an ended line into rows with the same `filled` that splits an unended one, so the tail holds rows rather than lines.

6. **Timing measures a run with `Clock.now`, the clock the host may set, so a clock set during the run gives a wrong time or a negative one**
   - Place: shell/shell.ern:406 and 494; Appendix E.15
   - Quote: "let started = Clock.now();"
   - Wrong: E.15 says "The difference of two `now`s is not that time when the clock is set between them". `Clock.monotonic` is the clock whose difference is the time the run took, which `:set timing on` prints (§11.2 *Printing*).
   - Shown by: none
   - Fix: read `Clock.monotonic()` at both ends.

7. **`:load` completion offers every directory under the source root that has a valid name, though it holds no module: `Build.`, `Home.`, `Steps.`**
   - Place: shell/shell/complete.ern:182-186; report §11.2 *Completion*
   - Quote: "Fs.Entry(path = path, kind = Fs.Directory) ->"
   - Wrong: §11.2 says "A namespace is offered only where it holds a name that may stand there". A build root or a data directory under the source root is offered as a namespace, and completing it leads to nothing.
   - Shown by: in a directory holding `build/`, `home/`, `root/`, `src/`, `steps/` and `esc.ern`, where only `root/` and `src/` hold `.ern` files, `:load ` then Tab twice lists:
     ```
     Build.  Esc  Home.  Root.  Src.  Steps.
     ```
   - Fix: offer a directory only where a `.ern` file lies under it, or say in §11.2 that `:load` offers directories without reading them.

8. **A command's argument that the parser cannot finish never takes another line: `Enter` runs `:type List.map([1, 2],` and reports the end of input**
   - Place: shell/shell.ern:1081-1082, also `gathered` at 300-307 for startup files; report §11.2 *Editing*
   - Quote: "!String.isEmpty(String.trim(input)) && !lastLineBlank(input) && needsMore(input)"
   - Wrong: `needsMore` parses the whole command line, `:` included, which is an error and not unfinished, so a command never continues, whether at a terminal, in line mode or in a startup file. §11.2 says nothing about commands here, and the code makes this choice without stating it.
   - Shown by: line mode:
     ```
     > :type List.map([1, 2],
     input 1:1:17: expected an expression instead of end of input
     > input 2:1:10: expected end of input instead of `)`
     ```
   - Fix: ask `needsMore` about the argument of `:type`, or state in §11.2 that a command is one line.

9. **A `C-k`, `C-u`, `C-w` or `M-d` that kills nothing empties what `C-y` puts back, where Readline leaves the last kill as it was**
   - Place: shell/shell/editor.ern:405-419
   - Quote: "kill = String.slice(text, cursor, index - cursor))"
   - Wrong: §11.2 binds these "of GNU Readline's Emacs keys". Readline's kill leaves the kill ring as it was when the span is empty, so `C-a C-k C-k C-y` there puts the line back, and here puts back nothing.
   - Shown by: a probe module that plays keys onto `Shell.Editor.edit` (scratch `E2/root/probe.ern`):
     ```
     "abc" C-a C-k C-e C-k C-y  ->  "" at 0      (Readline: "abc")
     ```
   - Fix: leave `kill` as it was when the span killed is empty.

10. **`C-w` crosses into the line above in a multi-line input, because a line feed does not count as a space**
    - Place: shell/shell/editor.ern:449-450
    - Quote: "String.slice(text, index, 1) != \" \""
    - Wrong: with the cursor after `x` on the second line of `let x = 1⏎x`, `C-w` kills `1\nx` and joins the two rows. §11.2 never says a kill can leave its line, and a reader would not expect it to.
    - Shown by: the same probe:
      ```
      "let x = 1" M-Enter "x" C-w  ->  "let x = " at 8
      ```
    - Fix: treat a line feed as a space, and a tab too, as Readline's `whitespace` does, or state in §11.2 that `C-w` may cross a line.

11. **The screen is not monitored: if it ends, the session goes on writing to nothing and waits five seconds at every prompt**
    - Place: shell/shell.ern:141-159 and 182
    - Quote: "monitor(Process.fromAddress(reader), ReaderDied);"
    - Wrong: the reader's end is reported and ends the session. The screen, the only writer, is one of the shell's own processes, so its fault is not reported, and nothing watches it. A fault in it leaves a session that prints nothing and whose `drain` times out before every prompt.
    - Shown by: none
    - Fix: monitor the screen as the reader is, and finish where it ends.

12. **`await` does not receive `ReaderDied`, so if the reader ends while an input runs, no key can interrupt that input**
    - Place: shell/shell.ern:421-466
    - Quote: "| Interrupted -> {"
    - Wrong: only `keyLoop` receives `ReaderDied`. While an input runs, the session is not told the keys are gone, and an input that never ends holds the session until the host kills it.
    - Shown by: none
    - Fix: receive `ReaderDied` in `await` as well, kill the input, and finish.

13. **The shell prints a hint, "M-Enter adds a line, Enter runs.", that §11.2 does not contain, under a comment that cites §11.2 for it**
    - Place: shell/shell.ern:1052-1059
    - Quote: "Report §11.2: the first input of a session to take a second line says how it is run"
    - Wrong: §11.2 has no such sentence. The hint is often shown just after `Enter` added a line instead of running the input, so "Enter runs" is only half true there.
    - Shown by: none
    - Fix: add the hint and its exact text to §11.2, or remove it.

14. **The report never says how a tab in the input is drawn: §11.5 sets the tab apart from control characters, and the region chooses stops of eight**
    - Place: shell/shell/region.ern:303-312 and 359-372; report §11.2 *Editing*, §11.5
    - Quote: "if code == 9 || code >= 32 && code < 127 || code > 159 then"
    - Wrong: §11.2 draws a control character "as a diagnostic's source draws it (§11.5)", and §11.5 "shows a tab as a space". The region spaces a tab to the next stop of eight, a rule no section states.
    - Shown by: none
    - Fix: state the tab stop in §11.2, or draw a tab as §11.5 does.

#### Clarity

15. **`Shell.Editor.State`'s field `kill` gives the prelude's name `kill` to the text last killed**
    - Place: shell/shell/editor.ern:19, 193, 206
    - Quote: "kill : String,"
    - Wrong: the glossary in docs/style.md says "A prelude name, `Down`, `answer`, `kill`, is not bound to another concept". In `character`, `let State(..., kill = kill) = state` hides the process function behind a `String`.
    - Shown by: none
    - Fix: name the field `killed`.

16. **A module is given the kind `Value` so that its completion ends without a dot**
    - Place: shell/shell/complete.ern:149 and 193
    - Quote: "Some(Name(text = text, kind = Value, shown = text))"
    - Wrong: `Kind` says what a name is. The modules `:browse` and `:load` offer are marked as values only so that `whole` adds no dot, so the field is set to something false to steer another function.
    - Shown by: none
    - Fix: let the argument's completion say that a module is taken whole, for instance through its `Slot`, and keep `kind = Module`.

17. **`segment` is a `foreign fn` for work Ernest does in a few lines over `String` and `Char`, and its inverse is written in Ernest, wrongly (item 4)**
    - Place: shell/shell/complete.ern:230-233; Appendix E.0 rule 1
    - Quote: "asked of the compiler, which owns the rule"
    - Wrong: a `foreign fn` is admitted only where Ernest cannot express the work given the layers beneath it. Splitting at `_` and capitalising can be expressed in Ernest. With one direction foreign and the other written by hand, the rule has two owners anyway.
    - Shown by: the inverse, written and run in scratch:
      ```
      fn component(segment : String) : String =
          String.fromList(List.flatMap(List.indexed(String.toList(segment)), fn(#(index, char)) =
              if index > 0 && Char.isUpper(char) then ['_', Char.toLower(char)] else [Char.toLower(char)]))
      // Http -> http, KvParser -> kv_parser, OrderedSet -> ordered_set
      ```
    - Fix: write both directions in Ernest in one place, or ask the front end for both.

18. **The rule that a HOME which is no absolute path names no file exists twice: in Ernest for the history, in Erlang behind `startupFiles`**
    - Place: shell/shell/history.ern:20-24; shell/shell.ern:1316-1320, answered by erl/cli/src/ern_cli.erl:814-822
    - Quote: "path when Path.isAbsolute(path) -> Some(path <> Path(\".ernest/history\"))"
    - Wrong: the host finds `$HOME/.ernest/startup`, though `Os` and `Path`, which lie beneath the shell, can find it, as `Shell.History.file` does. Only the configuration directory and the test that two paths are one file need the host.
    - Shown by: none
    - Fix: build the person's startup path in Ernest beside `Shell.History.file`, and ask the host only for the configuration directory's file and whether the two are one file.

19. **`Shell.Style`'s functions take the colour before the text, which breaks shape rule 1 and the order of `Markdown.render`**
    - Place: shell/shell/style.ern:10-48; Appendix E.0 shape rule 1
    - Quote: "export fn fault(colour : Markdown.Output, text : String) : String ="
    - Wrong: the subject is the text. A reader expects `text |> Shell.Style.fault(colour)`, as with `Markdown.render(doc, width, colour)`, where the output mode comes last.
    - Shown by: none
    - Fix: write `fault(text, colour)`, and the same for `diagnostic`, `quiet`, `named` and `emphasis`.

20. **Message constructors break the style rule for requests and events: `Typing` and `Height` sent to the screen, and the events `Eof` and `Key`**
    - Place: shell/shell.ern:36, 86, 91, 102; docs/style.md *Ernest*
    - Quote: "| Height(Int)"
    - Wrong: style.md puts "a request in the imperative, `Subscribe`; an event in the past tense, `Resized`". `Height(rows)` asks the screen to set the tail's rows and `Typing` asks it to show a line, while `Eof` and `Key` tell of something that happened.
    - Shown by: none
    - Fix: rename them, for instance `SetRows` and `Show` for the requests, `Ended` and `Pressed` for the events.

21. **`Shell` and `Shell.Editor` use `State`, `Typing`, `Clear` and `Leave` for different things, and both `Shell` and `Shell.Region` have a function `typing`**
    - Place: shell/shell.ern:51, 86, 1066; shell/shell/editor.ern:16, 41-48; shell/shell/region.ern:91; shell/README.md:28
    - Quote: "In `shell.ern`, `Shell.Editor.Typing` is the editor's answer and a bare `Typing` is the screen's message."
    - Wrong: style.md says "two concepts never share a name". The README needs a paragraph to warn of the overlap, which shows the names should differ: the session's state against the line being edited, and the screen's request against the editor's answer.
    - Shown by: none
    - Fix: rename `Shell.Editor.State` to `Line` or `Editing`, and the screen's `Typing` to `Show`.

22. **`isKept` names the check that a startup file is the user's own and writable by no one else, using the word the history uses for keeping inputs**
    - Place: shell/shell.ern:259
    - Quote: "fn isKept(path : Path) : Bool with m ="
    - Wrong: elsewhere "kept" means retained: `Shell.History.kept`, `keptFaults`, `Shell.Editor.keeps`. Here it means safe to run, and the call `isKept(path) && isKept(parent)` does not say what it tests.
    - Shown by: none
    - Fix: name it `isTrusted` or `isOwnersOnly`.

23. **Some names do not say what their function does: `program()` spawns the entry point, `unbound` asks whether `it` was left alone, and `lone` and `midSequence` are questions**
    - Place: shell/shell.ern:174, 1283, 1343; shell/shell/complete.ern:236; shell/shell/editor.ern:104
    - Quote: "foreign fn program() : Optional(Address(Never)) with m ="
    - Wrong: style.md asks for a verb for a function that does something, and a question for a yes-or-no. `let _ = program();` hides a spawn. `unbound` names neither its question nor its meaning, which is that the input did not settle its value's type.
    - Shown by: none
    - Fix: rename them `spawnProgram`, `leavesItUnchanged`, `isLone` and `isMidSequence`.

24. **The reader drops the size a `Resized` event carries, and the screen asks `Terminal.size()` for it again**
    - Place: shell/shell.ern:988-990 and 851
    - Quote: "Key(Terminal.Resized(_)) -> {"
    - Wrong: the event holds the new size (E.16), but the screen's `Resized` carries nothing. The screen asks the host a second time and ignores the resize where that answer is `Left`, and no comment says this is on purpose.
    - Shown by: none
    - Fix: pass the size on as `Resized(Terminal.Size)`, or add a comment saying the latest size is read on purpose.

25. **A comment and a doc block in `Shell.Complete` say the opposite of what the code does**
    - Place: shell/shell/complete.ern:410 and 244
    - Quote: "the last may be unfinished, the ones before it are whole."
    - Wrong: `every` also matches each earlier segment by prefix or abbreviation (`L.fm` reaches `List.filterMap`, as the test `shortModule` checks), and its `[last]` arm repeats the general one. The doc of `complete` says "Nothing typed reaches every name admitted there", but `reaches` admits names of one segment only, as the test `nothingTyped` says.
    - Shown by: none
    - Fix: correct both sentences, and drop the `[last]` arm.

26. **Two pages leave a programmer guessing at arguments: `Shell.Command.completes` expects the word with its `:`, and `Shell.Complete.applied` takes two `String`s in an unstated order**
    - Place: shell/shell/command.ern:172-175; shell/shell/complete.ern:356-362
    - Quote: "Shell.Complete.applied : (String, Int, String, Completion) -> #(String, Int)"
    - Wrong: the page shows only the type. `completes("load")` answers `None`, since the first character is dropped, which the doc block does not say. `applied`'s doc names neither the line nor the typed word.
    - Shown by: none
    - Fix: say in each doc block what each argument is, `":load"` with its colon.

27. **Two comments cite `findings.md`, a document that exists only while a review is open and is not in this commit**
    - Place: shell/shell/editor.ern:471; shell/shell/history.ern:123
    - Quote: "(findings.md's E6)"
    - Wrong: the reference leads nowhere. Each comment already describes the regression it guards against, so the citation adds nothing.
    - Shown by: none
    - Fix: drop the citations and keep the descriptions.

28. **The shell's README says two false things: that `Shell` holds all that reaches the host but the history file, and that `main` writes the first prompt itself**
    - Place: shell/README.md:36 and 60
    - Quote: "all that sends, receives, or reaches the host, but the history file"
    - Wrong: `Shell.Complete` declares seven `foreign fn`s and lists the source root through `Fs`, as README:72 says. `main` writes the first `> ` through `prompt` (shell.ern:185), as every later one is written.
    - Shown by: none
    - Fix: name `Shell.Complete` beside the history file, and drop the contrast between `main` and `prompt`.

29. **One five-second wait has three names and an unnamed literal, and `:output` uses the file system's `fileMs` for a call to the screen**
    - Place: shell/shell.ern:310, 333, 949; shell/shell/history.ern:15; shell/shell/complete.ern:199
    - Quote: "Address.call(screen, fn(reply) = Locate(reply = reply), fileMs)"
    - Wrong: `fileMs` is commented "How long to wait for the file system", but here it limits a call to a process, and `drain` writes `5000` without a name.
    - Shown by: none
    - Fix: add a `screenMs` for the two calls to the screen.

30. **`Shell.Region.output(region, rows)` is named with a noun, though it gives the tail a number of rows**
    - Place: shell/shell/region.ern:127
    - Quote: "export fn output(region : Region, rows : Int) : #(Region, String) ="
    - Wrong: beside `said`, `wrote` and `resized`, the name says neither the event nor the change. `Shell.output` (the `:output` command) and the setting `OutputRows` are other things named with the same word.
    - Shown by: none
    - Fix: name it for the change, for instance `withTailRows`.

31. **The help mixes two forms of line: some say what the command shows, some are imperatives that repeat the command's verb**
    - Place: shell/shell/command.ern:52-112
    - Quote: "about = \"forget a name the session declared, or * for all of them\""
    - Wrong: `:forget name    forget a name...` and `:output path    append...` stand beside `:browse Module  the exports of Module...` and `:load Module    the module by its namespace`, so one list reads in two styles.
    - Shown by: none
    - Fix: use one form throughout.

### E, part 3, the libraries, the examples and the tools; its 1 to 43 are E66 to E108

#### Defects

1. **file_sync checks a peer's file against the last listing, not the file now, so a local edit made since that listing is overwritten without a conflict**
   - Place: examples/file_sync.ern:115
   - Quote: "Some(mine) when mine > mtime -> {"
   - Wrong: `seen` is what this side's listing found up to five seconds ago. B lists f at mtime 0; A edits f (mtime 1); B edits f (mtime 2); A lists and pushes f@1. B finds `seen[f] = 0 < 1`, stores A's older bytes over its newer ones, sets the mtime to 1, and records 1, so its next listing sees nothing changed: B's edit is lost and no `.conflict` file is written. The comment above `store` promises "Newer local file: conflict".
   - Shown by: none
   - Fix: let the writer `Fs.stat` the local file and compare the peer's mtime with that, not with `seen`.

2. **snake takes two turns within one tick as a U-turn, so a snake of three or more dies from two quick keys**
   - Place: examples/snake.ern:269
   - Quote: "match #(player.direction, direction) {"
   - Wrong: `turn` checks the new direction against the one the last key set, not against the direction of the last move. Heading East, Up then Left inside one tick turns North and then West, and the head moves back into the neck. The header names "input faster than ticks" as what the program is meant to handle.
   - Shown by: a test appended to a copy of snake.ern: body (5,5),(4,5),(3,5) heading East, then `applyInput` Turn North and Turn West, then `step`:
     ```
     two turns within one tick: failed: Some(Player(id = 1, body = [Point(x = 4, y = 5), Point(x = 5, y = 5), Point(x = 4, y = 5)], direction = West, score = 0, alive = false))
     ```
   - Fix: keep the direction of the last move beside the requested one, and refuse a turn opposite to the direction of the last move.

3. **web_server answers each request from one `Tcp.read`, so headers that arrive in a later segment are lost**
   - Place: examples/web_server.ern:93
   - Quote: "match Tcp.read(socket, 5000) {"
   - Wrong: `Tcp.read` answers "what has arrived, at least one byte" (E.18). A request whose request line and headers arrive in two segments is parsed from the first alone, so the cookie is ignored and the client gets a new session.
   - Shown by: a first `curl` (sid=0, visit 1), then a client that sends `GET / HTTP/1.1\r\n`, waits 0.3 s, and sends `Cookie: sid=0\r\n\r\n`:
     ```
     HTTP/1.1 200 OK
     content-length: 14
     set-cookie: sid=1; path=/

     Visit number 1
     ```
   - Fix: read until `\r\n\r\n` has arrived, within one deadline, before parsing.

4. **web_server's session id is the connection's number, so any client takes another's session by sending a small number**
   - Place: examples/web_server.ern:216
   - Quote: "SessionId(Int.toString(connection)) // good enough on paper"
   - Wrong: ids are 0, 1, 2… in order. `parseSessionId` accepts any digits, so `Cookie: sid=0` joins the first visitor's session. The comment states the approximation and leaves it in place. The program now compiles and runs as a server, and `Random` exists.
   - Shown by: `curl -H 'Cookie: sid=0' http://127.0.0.1:8080/` from a second client answers `Visit number 2` and `set-cookie: sid=0`.
   - Fix: draw the id from `Random.next` over a seed taken from `Clock.now()` (E.13), and drop the comment.

5. **echo discards the result of its round trips and prints "2000 round trips" even when one has failed**
   - Place: examples/echo.ern:25
   - Quote: "let _ = roundTrips(socket, rounds);"
   - Wrong: `roundTrips` stops at the first failed write or read and answers `Left(error)`. `main` throws that away and reports the full count and the time, which measures nothing in that case.
   - Shown by: none
   - Fix: match the result, and print the error in place of the measurement on `Left`.

6. **echo measures elapsed time with `Clock.now`, which E.15 says is not elapsed time when the clock is set**
   - Place: examples/echo.ern:24
   - Quote: "let started = Clock.now();"
   - Wrong: E.15: "The difference of two `now`s is not that time when the clock is set between them". A duration is `Clock.monotonic`'s.
   - Shown by: none
   - Fix: use `Clock.monotonic()` for both readings.

7. **`ern doc` prints an exported foreign fn's type without its restrictions: `Ets.contains` shows `(Table(k, v), k) -> Bool with m`, which the checker treats as `k=!`, `v!`, `m+`**
   - Place: libs/ets/ets.ern:94 and :181; report §3.9, §4.7, Appendix E (introduction)
   - Quote: "Ets.contains : (Table(k, v), k) -> Bool with m"
   - Wrong: E says "`ern doc` prints every restriction (§11.5)". §4.7 makes a foreign fn's variables not reply-carrying and §3.9 makes it process-only. The Ernest wrappers on the same page print `Ets.put : (Table(k=!, v!), k=!, v!) -> Unit with m+`, so `contains` and `toList` read as if pure code could call them, which it cannot. The same gap shows on any module that exports a `foreign fn`.
   - Shown by:
     ```
     $ ern doc --source-root libs/ets libs/ets/ets.ern | grep -A1 'Ets.contains :'
     Ets.contains : (Table(k, v), k) -> Bool with m
     $ ern build --load-path libs/ets probe.ern   # fn probe(t : Ets.Table(Int, Int)) : Bool = Ets.contains(t, 1)
     probe.ern:2:5: Ets.contains needs a process, and probe is pure
     ```
   - Fix: print a foreign fn's scheme with the restrictions §4.7 and §3.9 give it, as the checker's own messages do (`Boxes.peek : (Boxes.Box(a!)) -> Int with m+`).

8. **`Ets.size` on an ended table faults with "foreign return does not match Int", not as its Errors section says; `ets:info/2` answers `undefined`**
   - Place: libs/ets/ets.ern:111-121
   - Quote: "On a table that has ended, faults as a foreign function that raises does (report §7.4)."
   - Wrong: `ets:info/2` does not raise on a deleted table: it answers the atom `undefined`. `rawInfo` declares `Int`, so the call faults by §7.4's return check. That is another cause from the one the page gives. The shim's declared type is not what its host function answers.
   - Shown by:
     ```
     let table : Ets.Table(String, Int) = Ets.new(); Ets.close(table); Ets.size(table)
     Closed.main faulted: foreign return does not match Int
     ```
   - Fix: declare `rawInfo`'s result as `Foreign.Term` and fault with a cause of the module's own on `undefined`, or state the cause the page now gets.

9. **An HTML comment, declaration or processing instruction runs to a blank line, so the paragraph after it is swallowed into a `Raw` block**
   - Place: libs/markdown/markdown.ern:196, :527-531 (comment at :498-499)
   - Quote: "An HTML block begins with a comment, ... and runs to a blank line."
   - Wrong: in CommonMark 0.31, start conditions 2 to 5 end at the line that holds `-->`, `?>`, `>` or `]]>`. Only conditions 6 and 7 end at a blank line. Neither the module's page nor G.2 states this deviation. A `<!-- note -->` line followed by text hides the text from `render` and `roff` as markup.
   - Shown by:
     ```
     parse  "<!-- c -->\ntext" = [Raw(["<!-- c -->", "text"])]
     ```
   - Fix: end a comment, declaration or processing-instruction block at the line holding its closing mark, and keep the blank-line end for a tag.

10. **Ansi.styled's page promises "a style around it stays on", but a colour inside a colour, or italics inside italics, turns the outer one off**
    - Place: libs/ansi/ansi.ern:42-44; report Appendix G.3
    - Quote: "which is turned off after it by the style's own code, so that a style around it stays on"
    - Wrong: the off codes are per kind (`39` for every colour, `23` for italics). An inner style of the outer's kind ends the outer at the inner's end. The page names Bold and Dim as the only exception.
    - Shown by:
      ```
      Ansi.styled("a" <> Ansi.styled("b", Ansi.Foreground(Ansi.Red)) <> "c", Ansi.Foreground(Ansi.Blue))
      "\u{1B}[34ma\u{1B}[31mb\u{1B}[39mc\u{1B}[39m"     // "c" in the default colour
      ```
    - Fix: say that a style of another kind around it stays on, and that one of its own kind, or Bold around Dim, is turned off.

11. **ern(1)'s SYNOPSIS lists `ern build` twice, because `usages` takes every `ern … [` code span in §11, including §11.1's later directory form**
    - Place: tools/manual.ern:84-99
    - Quote: "|| String.startsWith(code, \"ern \") && String.contains(code, \" [\") then"
    - Wrong: §11.1 writes `ern build [...] file.ern | src-dir` and later, mid-paragraph, `ern build [...] src-dir`. Both pass the test, so the page shows a second, narrower usage line for `build`.
    - Shown by:
      ```
      $ ern run … manual.erc report/toolchain.md 0.2.0 pages > ern.1; man -l ern.1
             ern build [--source-root src-root] [--build-root build-root] [--load-path dir]...
             [--emit-erl] [--short-errors] file.ern | src-dir

             ern build [--source-root src-root] [--build-root build-root] [--load-path dir]...
             [--emit-erl] [--short-errors] src-dir
      ```
    - Fix: take only the code span that opens a paragraph, or one usage line per job, the first.

12. **file_sync pushes every listed entry, so a subdirectory or a link is read as a file, and a subdirectory reports an error**
    - Place: examples/file_sync.ern:173-181
    - Quote: "List.filterMap(entries, fn(entry) = changed(seen, entry))"
    - Wrong: `Fs.list` describes directories, links and others as entries (E.17). `diff` ignores `kind`, so `pusher` reads a directory and prints an error each time its mtime changes. A link is followed and its target copied as a file.
    - Shown by: run in a directory with `a/sub/`:
      ```
      cannot read a/sub: not a regular file
      ```
    - Fix: keep only `entry.kind == Fs.File` in `diff`.

13. **`#` followed by a tab is not read as a heading, against CommonMark 0.31, which allows spaces or tabs after the opening sequence**
    - Place: libs/markdown/markdown.ern:266
    - Quote: "else if !String.startsWith(text, \" \") then"
    - Wrong: `#\tTitle` becomes a paragraph. `structured` expands a tab only after the prefix characters, and `#` is not one of them, so the tab reaches `atx` as it is.
    - Shown by:
      ```
      parse  "#\tTitle" = [Paragraph([Text("#\tTitle")])]
      ```
    - Fix: accept a tab as well as a space after the `#`s, and trim it.

14. **`render` with `Plain` writes `_x_` as `*x*` and `__y__` as `**y**`, though the page says each span is shown as it was written**
    - Place: libs/markdown/markdown.ern:888-889; :97 (`Plain`'s doc)
    - Quote: "`Plain`: Emphasis, strong emphasis and code spans as they are written."
    - Wrong: `Emphasis` and `Strong` do not keep their mark, and `span` always writes `*`. The shell's `:doc` renders `Plain` with this library, so a doc block with `_x_` shows `*x*`.
    - Shown by:
      ```
      parse  "_x_ and __y__" = [Paragraph([Emphasis([Text("x")]), Text(" and "), Strong([Text("y")])])]
      plain  ["*x* and **y**"]
      ```
    - Fix: say that `Plain` writes emphasis with `*`, or keep the mark in the inline.

15. **The template module gives a circle's area as three times the radius squared, "since the module has no Float", though `Float.pi` exists**
    - Place: examples/template.ern:92-102
    - Quote: "three times the radius squared for a circle, since the module has no `Float`"
    - Wrong: `area(circle(_, 2))` is 12, not about 12.57. The reason given is a choice the module made, not a limit of the language. The worked example of a documented module teaches an approximation stated as a fact.
    - Shown by: none
    - Fix: answer `Float` with `Float.pi`, or choose a shape whose integer area is exact (a square, a rectangle).

16. **With `Styled`, emphasis inside emphasis turns the italics off for the rest of the outer span**
    - Place: libs/markdown/markdown.ern:888
    - Quote: "Emphasis(inner) -> marked(output, Ansi.Italic, \"*\", spans(inner, output))"
    - Wrong: `*a _b_ c*` gives italic `a `, `b`, then a plain ` c`. `unstrong` handles the same problem for strong emphasis in a heading, and nothing does it for emphasis in emphasis.
    - Shown by:
      ```
      styled ["\u{1B}[3ma \u{1B}[3mb\u{1B}[23m c\u{1B}[23m"]
      ```
    - Fix: flatten an `Emphasis` inside an `Emphasis`, as `unstrong` flattens `Strong`.

17. **snake's `refill` puts apples anywhere, the snake's own cells included, where `freePoint` avoids them**
    - Place: examples/snake.ern:185-196
    - Quote: "refill(width, height, wanted, Point(x = x, y = y) :: apples, seed2)"
    - Wrong: an apple under the body is not drawn, since a snake cell is drawn first, and cannot be eaten until the body leaves it.
    - Shown by: a test in a copy of snake.ern, a body on 9 of 10 cells, one apple wanted:
      ```
      refill places apples where the snake is: failed: 47 of 50 seeds put the apple on the snake
      ```
    - Fix: draw each apple with `freePoint`, which checks `taken`.

18. **A tab after a leading run of digits or marks in text is expanded, though the page says a tab elsewhere than the structure is kept**
    - Place: libs/markdown/markdown.ern:203-219
    - Quote: "|| Char.isAsciiDigit(char) -> char :: prefixExpanded(rest, column + 1)"
    - Wrong: `prefixExpanded` treats any opening run of space, `>`, `-`, `*`, `+`, `.`, `)` and digits as structure, whether it is a marker or not.
    - Shown by:
      ```
      parse  "3.14\tpi" = [Paragraph([Text("3.14    pi")])]
      ```
    - Fix: expand tabs only through the indentation, the quote marks and a marker that `markerOf` reads.

19. **A lazy `===` under a quoted paragraph makes a setext heading, where CommonMark keeps it paragraph text**
    - Place: libs/markdown/markdown.ern:357, :537
    - Quote: "| line :: rest when continues(line, acc) -> quoted(rest, line :: acc)"
    - Wrong: CommonMark 0.31 says a setext underline cannot be a lazy continuation line. `continues` lets `===` into the quote, and `paragraph` then reads it as an underline.
    - Shown by:
      ```
      parse  "> a\n===" = [Quote([Heading(level = 1, text = [Text("a")])])]
      ```
    - Fix: do not take a line `underlineLevel` reads as a lazy continuation.

20. **A link destination in angle brackets, `[a](<b c>)`, is not read, and the page does not list it among what stays text**
    - Place: libs/markdown/markdown.ern:736-751
    - Quote: "What it does not read is kept as written: an HTML block is a `Raw` block, and inline HTML, an entity, and a link by reference stay in the text."
    - Wrong: CommonMark 0.31 allows `<…>` destinations, spaces included. The text is kept whole and the page says nothing of it.
    - Shown by:
      ```
      parse  "[a](<b c>)" = [Paragraph([Text("[a](<b c>)")])]
      ```
    - Fix: read `<…>` in `destination`, or add it to the page's list of what stays text.

21. **The REPL answers an empty line with "unexpected end of input"**
    - Place: examples/repl.ern:91
    - Quote: "| Right(tokens) -> match parse(tokens) {"
    - Wrong: a blank line is parsed as an expression and reported as an error. A read-evaluate-print loop passes over it.
    - Shown by:
      ```
      $ printf 'let x = 3\n\nx\n' | ern run repl.erc
      3
      unexpected end of input
      3
      ```
    - Fix: answer `Right([])` from `tokenize` with nothing printed.

22. **snake's tick is 100 ms plus each tick's work, so the world is updated less than the ten times per second the header states**
    - Place: examples/snake.ern:84-85
    - Quote: "Clock.alarm(100, fn(_) = Ticked);"
    - Wrong: the header names time drift as something the program is meant to handle. Each alarm is set after the previous tick has been drained, stepped and drawn, so the delay adds up and nothing corrects it.
    - Shown by: none
    - Fix: keep a deadline on `Clock.monotonic` and set `Clock.alarm(Int.max(0, deadline - Clock.monotonic()), …)`, the deadline 100 ms later each tick.

23. **The shell's `:doc` shows Ansi's and Markdown's pages to a session that cannot call them, and shows no page for Ets on its load path**
    - Place: report §11.2, §11.4 (the shell's `:doc`); libs/*
    - Quote: "no documentation for Ets.new"
    - Wrong: the pages `:doc` finds are not the modules the session can name, so a programmer who reads `Ansi.styled` there gets "unknown name" when calling it, and with `--load-path libs/ets` gets no page for Ets.
    - Shown by:
      ```
      $ printf ':doc Ansi.styled\nAnsi.up(2)\n:doc Ets.new\n' | ern shell --load-path libs/ets
      > Ansi.styled ... (the page)
      > input 2:1:1: unknown name Ansi.up
      > no documentation for Ets.new
      ```
    - Fix: answer `:doc` from the modules the session can name, its load path included, and from those alone.

#### Clarity

24. **`Ets.contains` is a `foreign fn` whose work is `Optional.isSome(get(table, key))`, as `Map.contains` is Ernest over `get`**
    - Place: libs/ets/ets.ern:94
    - Quote: "export foreign fn contains(table : Table(k, v), key : k) : Bool with m ="
    - Wrong: E.0 rule 1 admits a primitive beneath an operation Ernest could write only for a measured cost. `ets:lookup` copies the value out where `ets:member` does not, which may be that reason, but neither the module nor its page says so.
    - Shown by: none
    - Fix: write `contains` over `rawLookup`, or state the copying cost that keeps it a shim.

25. **One concept, the openers of a block, has three names in markdown: `starts()`, the parameter `tries`, and the element `opener`**
    - Place: libs/markdown/markdown.ern:164-178
    - Quote: "fn begun(tries : List((String, List(String)) -> Optional(#(Block, List(String)))),"
    - Wrong: style.md: "One concept, one name". `begun` and `structured` do not say what they answer either: the block begun at a line, and the line with its structural tabs expanded.
    - Shown by: none
    - Fix: name the list `openers` everywhere, and `structured` something like `prefixExpandedLine`.

26. **Four regression tests in markdown cite "findings.md's E5/E8/E21/E22", a file that no longer exists and whose numbers collide with every later review's**
    - Place: libs/markdown/markdown.ern:1269, :1316, :1325, :1404
    - Quote: "(findings.md's E22)"
    - Wrong: `docs/findings.md` exists only while a review is open. The citations now point nowhere, and "E5" is this review's numbering too.
    - Shown by: `ls docs` has no findings.md.
    - Fix: say what the defect was and drop the citation, or cite the commit that fixed it.

27. **markdown's `blocksAre` reports a failed parse as only its count of blocks, where `Io.show(blocks)` would show what was read**
    - Place: libs/markdown/markdown.ern:1553-1557
    - Quote: "Test.Failed(Int.toString(List.size(blocks)) <> \" blocks\")"
    - Wrong: a failing parse test says "2 blocks" and nothing of their content. `rowsAre` and `inlinesAre` show the text.
    - Shown by: none
    - Fix: `Test.Failed(Io.show(blocks))`.

28. **`Markdown.roff`'s page says the header and the NAME line come "from the page", where they come from its `Manual` argument**
    - Place: libs/markdown/markdown.ern:1016
    - Quote: "the header and the NAME line from the page"
    - Wrong: "the page" is the output being written. G.2 says "from the `Manual`".
    - Shown by: none
    - Fix: "from the `Manual`".

29. **`Markdown.render`'s page lacks a comma, so the label rule reads as if the period depends on the delimiter**
    - Place: libs/markdown/markdown.ern:796-797
    - Quote: "or its number and a period whichever delimiter it was written with"
    - Wrong: the sentence means a period whatever the delimiter, `1)` included.
    - Shown by: none
    - Fix: "or its number and a period, whichever delimiter it was written with".

30. **`Template.radius`'s sentence does not say what the function answers**
    - Place: examples/template.ern:104
    - Quote: "The radius of a circle across the diameter, toward zero."
    - Wrong: a reader has to guess that the argument is a diameter and the answer is half of it, rounded toward zero.
    - Shown by: none
    - Fix: "The radius of a circle of that diameter, rounded toward zero."

31. **file_sync's `store` repeats the spawn in two arms, and `writer`'s `written : Ack` names the answer it gives, not a write**
    - Place: examples/file_sync.ern:113-123, :142
    - Quote: "let _ = spawn(fn() = writer(conflictPath(here), bytes, mtime, reply, Conflict));"
    - Wrong: the arms differ only in the target path and the `Ack`. "written" reads as a flag or as the bytes.
    - Shown by: none
    - Fix: `let #(target, ack) = match … ;` then one `spawn`, and name the parameter `ack`.

32. **snake's `steering` writes the same send and loop four times, once for each arrow**
    - Place: examples/snake.ern:106-127
    - Quote: "Terminal.ArrowUp -> {"
    - Wrong: the arms differ only in the direction. A function from `Terminal.Event` to `Optional(Direction)` and one arm would say it once, and `Escape or Interrupt` would make one arm of the two that leave.
    - Shown by: none
    - Fix: one arm over a `direction(event)` helper and an `or` pattern for leaving.

33. **web_server's four status and session helpers are its only unannotated functions, and `statusText` answers "400 Bad Request" for every code but 200**
    - Place: examples/web_server.ern:213-226
    - Quote: "if code == 200 then \"200 OK\" else \"400 Bad Request\""
    - Wrong: every other function in the examples states its types. A `StatusCode(404)` would be written as 400.
    - Shown by: none
    - Fix: annotate them, and match the two codes the program has with a fault for any other.

34. **file_sync and web_server each carry the same 13-line `errorText`, where tools/manual.ern writes an `Io.Error` with `Io.show`**
    - Place: examples/file_sync.ern:189-202; examples/web_server.ern:190-203
    - Quote: "errorText is a hand-written rendering for stdout."
    - Wrong: two copies of one table drift apart. Its `NotAFile -> "not a regular file"` is also wrong for `Fs.append`, where E.1 says it means a device.
    - Shown by: none
    - Fix: use `Io.show(error)`, or keep one copy and say why the examples want words.

35. **The headers of the four "paper programs" still read as speculation: "Assumptions.", "Written against the Ernest report", "good enough on paper"**
    - Place: examples/file_sync.ern:2-13; examples/web_server.ern:2-11, :217; examples/snake.ern:2-16; examples/repl.ern:2-14
    - Quote: "Assumptions. Fs and Clock are the standard library's system modules"
    - Wrong: the programs compile, run under test and use real modules. "Assumptions" and "paper" tell a reader that what the header states may not hold.
    - Shown by: none
    - Fix: state what each program uses as fact, and drop "paper" and the dated "Written against" lines.

36. **tools/manual.ern strips ".3ern" by counting graphemes, where `Path.extension` and `Path.withoutExtension` say it, and checks the sections after building the page**
    - Place: tools/manual.ern:120-126, :48
    - Quote: "Some(String.slice(file, 0, String.size(file) - 5))"
    - Wrong: the 5 and the separate `endsWith` restate the extension. The emptiness check of `options` and `exitStatus` comes after the blocks it guards have been built.
    - Shown by: none
    - Fix: filter `Path.extension(entry.path) == Some("3ern")` and take `Path.name(Path.withoutExtension(entry.path))`; check the sections before building.

37. **echo listens on the fixed port 7345, where port 0 and `Tcp.port` avoid a clash with whatever else holds it**
    - Place: examples/echo.ern:15
    - Quote: "let port = 7345;"
    - Wrong: E.18 offers "port 0 asks the system for a free one". A second run, or any program on 7345, makes echo print "cannot listen".
    - Shown by: none
    - Fix: `Tcp.listen("127.0.0.1", 0)` then `Tcp.port(listener)`.

38. **The REPL's parser accepts `let` inside an expression, where it binds nothing, and nothing tells the user**
    - Place: examples/repl.ern:211, :310
    - Quote: "| Let(value = value) -> eval(env, value) // the REPL binds the name, see evaluateLine"
    - Wrong: `let g = (let h = 2)` answers 2, and then `h` is "unbound h". The grammar comment presents `let` as an expression anywhere.
    - Shown by:
      ```
      $ printf 'let g = (let h = 2)\nh\n' | ern run repl.erc
      2
      error: unbound h
      ```
    - Fix: accept `let` only at the start of a line in `parse`, and report `Unexpected(LetKeyword)` elsewhere.

39. **Ets names half its raw bindings for the host's function and half for the Ernest operation**
    - Place: libs/ets/ets.ern:56-173
    - Quote: "foreign fn rawClose(table : Table(k, v)) : Bool with m ="
    - Wrong: `rawInsert`, `rawLookup`, `rawDelete` and `rawInfo` follow `ets`. `rawClear` and `rawClose` follow Ernest, and `rawDelete` deletes a key while `rawClose` calls `ets:delete`.
    - Shown by: none
    - Fix: name each for the host function, `rawDeleteAllObjects`, `rawDeleteTable`, or each for the operation. Appendix D changes with it.

40. **`render` writes an empty row of a block quote as "│ " with a trailing space**
    - Place: libs/markdown/markdown.ern:827
    - Quote: "Quote(inner) -> List.map(render(inner, width - 2, output), fn(row) = \"│ \" <> row)"
    - Wrong: the blank row between two blocks of a quote ends in a space, which `labelled` avoids for items.
    - Shown by:
      ```
      plain  ["│ a", "│ ", "│ b"]
      ```
    - Fix: write "│" alone before an empty row.

#### Where the language made the work harder

41. **A constant list of openers cannot be a top-level `let` when an opener reaches back to the list, so markdown rebuilds it on every block**
    - Place: libs/markdown/markdown.ern:175-178; report §8.5
    - Quote: "a function rather than a `let`, which would be a cycle, since they reach back to it (§8.5)"
    - Wrong: §8.5 counts what a named function depends on "called or not". A list of function values that the initializer never calls is still a cycle, and the workaround is a function that builds the list again at each call.
    - Shown by:
      ```
      let openers : List((List(String)) -> Optional(Int)) = [quoteStart, plainStart]
      cycle.ern:2:1: the initializer of openers depends on itself, through quoteStart, blocks
        = help: `blocks` reads openers when it is called; a `fn openers() = ...` builds the value when it is asked for
      ```
    - Fix: for the language, let an initializer that only names functions, without calling them, not depend on what they depend on.

42. **With no type aliases, markdown spells `#(Block, List(String))` on 16 lines and the opener's function type twice in full; repl spells its parser's result 8 times**
    - Place: libs/markdown/markdown.ern:161-197; examples/repl.ern:225-295; report §3.1
    - Quote: "fn headingStart(line : String, rest : List(String)) : Optional(#(Block, List(String))) ="
    - Wrong: "There are no type aliases" (§3.1), and a one-constructor type would wrap and unwrap every opener. My own openers in cycle.ern repeated the type the same way.
    - Shown by: `grep -c '#(Block, List(String))' libs/markdown/markdown.ern` gives 16.
    - Fix: none in the code. For the language, weigh a transparent alias against principle 2.

43. **`Test` has no check that compares an answer with the expected one, so each tested module writes its own, and a failure shows only what the writer chose**
    - Place: report Appendix E.24; libs/markdown/markdown.ern:1553-1572; examples/file_sync.ern:208-217
    - Quote: "The module declares these two types and no function."
    - Wrong: markdown writes `blocksAre`, `inlinesAre` and `rowsAre`, file_sync an inline `if`, and my snake test `Test.Failed(Io.show(…))`. Each of these decides on its own what a failure shows.
    - Shown by: none
    - Fix: for the library, weigh a `Test.expect(actual, expected)` that needs `a.show` (§4.9) against E.0's rules.

### T, the tools

#### Defects

1. **A directory build or format stops at the first misnamed file: nothing is compiled or laid out, one refusal is shown at a time, named from the source root.**
   - Place: report/toolchain.md:19 (§11.1)
   - Quote: "A module that does not compile does not stop the others: every module is compiled but one that uses a module that failed, and every failure is reported."
   - Wrong: A path-shape error anywhere under `src-dir` ends the job before any module is compiled, so `good.ern` gets no `.erc`. The second bad name shows only after the first is fixed. `ern format dir` does the same and lays out nothing. The refusal names `Big.ern`, relative to the source root, while a diagnostic in the same mode names `src/c.ern`, relative to the working directory.
   - Shown by:
     ```
     $ ls ok
     Big.ern  _x.ern  good.ern  http_2.ern
     $ ern build ok; echo $?; ls ok
     ern build: Big.ern: path component `Big` must be lowercase
     1
     Big.ern  _x.ern  good.ern  http_2.ern
     $ rm ok/Big.ern; ern build ok
     ern build: _x.ern: path component `_x` must be words joined by `_`, ...
     $ ern format .          # Foo.ern beside ok/ugly.ern
     ern format: Foo.ern: path component `Foo` must be lowercase
     $ cat ok/ugly.ern       # untouched
     fn  g() : Int = 2
     ```
   - Fix: Treat a misnamed path as the failure of that one module. Report every such path, named from the working directory, and compile or lay out the rest.

2. **`ern build` skips a module whose dependency failed and says nothing, so the user sees only the dependency's error and never learns the dependent was not compiled.**
   - Place: report/toolchain.md:19 (§11.1)
   - Quote: "every module is compiled but one that uses a module that failed, and every failure is reported"
   - Wrong: The skip is invisible (principle 3). `b.erc` is simply missing, and no line names `B`. A parse failure behaves the same: `user.ern`, which uses the unparsable `Broken`, is skipped without a word.
   - Shown by:
     ```
     $ cat src/b.ern
     export fn two() : Int =
         A.one() + 1
     $ ern build --build-root build src    # a.ern and c.ern have type errors
     src/c.ern:2:9: both operands of `+` must have the same type: expected Int, found Bool
     ...
     src/a.ern:2:5: the body does not have the declared result type: expected Int, found String
     ...
     $ ls build
     d.erc
     ```
   - Fix: Write a line for each module left uncompiled, such as `src/b.ern: not compiled, since A does not compile`, and state that line in §11.1.

3. **`ern doc --man src-dir` never removes the page of a top-level module whose source is gone, though it removes a nested module's page.**
   - Place: erl/cli/src/ern_build.erl:772; report/toolchain.md:87 (§11.4)
   - Quote: "A document or a page `ern doc` wrote of a module under the directory whose source is gone is removed, as the build removes its `.erc`."
   - Wrong: The expected place is `filename:join(filename:dirname("shapes"), "Ernest.Shapes.3ern")`, which is `"./Ernest.Shapes.3ern"`. That never equals the relative path `Ernest.Shapes.3ern`, so the stale page stays for good. A later `ern doc` or `ern build` keeps it too.
   - Shown by:
     ```
     $ ern doc --man --build-root build src     # src/shapes.ern, src/other.ern
     $ rm src/shapes.ern
     $ ern doc --man --build-root build src; ls build
     Ernest.Other.3ern  Ernest.Shapes.3ern  other.erc
     $ erl -noshell -eval 'io:format("~p~n",[filename:join(filename:dirname("shapes"),"Ernest.Shapes.3ern")]),halt().'
     "./Ernest.Shapes.3ern"
     ```
     The same steps with `src/net/http.ern` do remove `build/net/Ernest.Net.Http.3ern`.
   - Fix: Compare the two paths after normalizing both, and add a test that removes a module at the root.

4. **`:doc` and `Shift-Tab` print a declaration's type as its module's page prints it, not as the shell does, so the type names things the session cannot name.**
   - Place: report/toolchain.md:71 (§11.2, Documentation)
   - Quote: "headed by the name as the session writes it and showing the type the shell prints for it"
   - Wrong: `Entry`, `Coin` and `type Error = ...` name nothing in the session. On the same name, `Tab` prints `Fs.Entry` and `Shift-Tab` prints `Entry`, so two displays of one type disagree (principle 1).
   - Shown by:
     ```
     > :doc Fs.stat
         Fs.stat : (Path, Int) -> Either(Io.Error, Entry) with m+
     > :type Fs.stat
     Fs.stat : (Path, Int) -> Either(Io.Error, Fs.Entry) with m+
     > :load Coin
     > :doc Coin.Coin.+
         Coin.Coin.+ : (Coin, Coin) -> Coin
     > :browse Coin
     Coin.Coin.+ : (Coin.Coin, Coin.Coin) -> Coin.Coin
     > :doc Io.Error
         type Error =
             NotFound
     ...
     ```
     At a terminal, `Fs.st` then `Tab` lists `Either(Io.Error, Fs.Entry)`, and `Fs.stat` then `Shift-Tab` shows `Either(Io.Error, Entry)`.
   - Fix: Print the documented type and declaration with the session's printer, as `:type` and `:browse` do.

5. **The prelude's page, `:doc` and `Shift-Tab` print the process primitives' types from hand-written strings that lack the checker's marks: `send : ... with m`, not `with m+`.**
   - Place: erl/typer/src/ern_prelude.erl:302, :399; report/toolchain.md:95 (§11.5)
   - Quote: "`send : (Address(a), a) -> Unit with m+`"
   - Wrong: `ern doc`'s prelude page, `:doc` and `Shift-Tab` print `with m` for `send`, `spawn`, `answer` and `kill`, and `with n` for `Address.call`. `:type`, `:browse Prelude` and the diagnostics print `m+` and `n+`. The page prints `restarting`'s result as `-> () -> Unit with n`, while the shell prints it as `-> (() -> Unit with n)`. The prelude's types have a second source, which has already drifted from the checker's (principle 2).
   - Shown by:
     ```
     > :type send
     send : (Address(a), a) -> Unit with m+
     > :doc send
         send : (Address(a), a) -> Unit with m
     $ grep -n '^send :\|^restarting :' man/stdlib/prelude.md
     383:send : (Address(a), a) -> Unit with m
     > :type restarting
     restarting : (RestartLimit, () -> Unit with n) -> (() -> Unit with n)
     ```
   - Fix: Print the prelude page's signatures from the checker's schemes with §11.5's printer, and delete the strings.

6. **A shadowed session type is named `$InputN` by a hidden module count, which does not match the `input N` that diagnostics and fault sites print.**
   - Place: report/toolchain.md:61 (§11.2, Scope); erl/cli/src/ern_shell.erl:165
   - Quote: "which prints under the input that declared it: `$Input2.T` for the second input's `T`"
   - Wrong: In the session below, the first `T` is input 4 but prints as `$Input1.T`. The second `T` is input 7 but prints as `$Input2.T`. The number is a module slot, which `free_inputs()` reuses, so nothing on the screen gives it.
   - Shown by:
     ```
     $ printf ':set\n1\n2\ntype T = A | B\nlet x = A\n3\ntype T = C\nx\nlet y = C\ntype T = D\ny\nx\nzzz\n' | ern shell
     ...
     > A : $Input1.T
     ...
     > C : $Input2.T
     > A : $Input1.T
     > input 13:1:1: unknown name zzz
     ```
   - Fix: Name a shadowed type by the session's own count, `$Input4.T`, which is the count a diagnostic of that input shows, and say so in §11.2.

7. **In the shell, `:load` of a module whose dependency does not compile adds "compile A.Bad first: <absolute .erc path>", advice that does not apply in the shell.**
   - Place: erl/cli/src/ern_build.erl:643; report/toolchain.md:65 (§11.2, Loading)
   - Quote: "Each module it uses that the session has not loaded is loaded the same way"
   - Wrong: The shell compiles a dependency from its source and needs no `.erc`. The cause is the diagnostic shown just above. The extra line sends the user off to run `ern build` and names a file that will never be needed.
   - Shown by:
     ```
     > :load User          # user.ern uses A.Bad; a/bad.ern has a type error
     a/bad.ern:2:5: the body does not have the declared result type: expected Int, found String
     ...
     compile A.Bad first: /tmp/.../s3/a/bad.erc: no such file or directory
     ```
   - Fix: Answer `User is not loaded, since A.Bad does not compile` once the dependency's diagnostic has been shown.

8. **A doc block's heading of the wrong level is accepted, and it breaks the page: `#` in a declaration's block becomes a `.SH` section of the manual page.**
   - Place: report/toolchain.md:85 (§11.4)
   - Quote: "A declaration's heading is level two, so a heading inside its doc block is level three or deeper; a heading in the module's doc block is level two."
   - Wrong: Nothing checks this rule. `ern build` and `ern doc` accept `#` and `##` in any doc block. A `##` sits beside the declarations' headings, and a `#` becomes a top-level section of the man page.
   - Shown by:
     ```
     $ cat heads.ern
     /// Module.
     ///
     /// # Big

     /// Thing.
     ///
     /// # Level one
     export fn x() : Int =
         1
     $ ern build heads.ern; echo $?
     0
     $ ern doc --man heads.ern | grep -A1 '^\.S[HS]$'
     .SH
     Big
     .SS
     Heads.x
     .SH
     Level one
     ```
   - Fix: Refuse a heading above the allowed level with a diagnostic at its `///` line, in every job that reads doc blocks.

9. **In the shell, a module on the load path or under the source root is an unknown name until `:load`, and the error does not say so.**
   - Place: report/toolchain.md:35 (§11.2)
   - Quote: "runs an interactive shell with every loaded module in scope"
   - Wrong: `ern run` finds `Greet.hi` on the load path when it is used. The shell answers `unknown name Greet.hi` and `no module Greet is in scope`, with no help line pointing to `:load Greet`. A reader who knows `ern run` does not predict this (principle 1).
   - Shown by:
     ```
     $ printf 'Greet.hi()\n:browse Greet\n' | ern shell --load-path ../lib
     > input 1:1:1: unknown name Greet.hi
     1 | Greet.hi()
       | ^^^^^^^^
     > no module Greet is in scope
     $ printf ':load Greet\nGreet.hi()\n' | ern shell --load-path ../lib
     > Greet, from /tmp/.../s4/lib/greet.erc
     > "hi" : String
     ```
   - Fix: Where the load path or the source root holds the module, add the help line `= help: :load Greet puts it in scope`, or load it when it is used, as `ern run` does.

10. **One file gets two namespaces depending on the build mode, so rebuilding one file of a tree just built writes a second module that no sweep removes.**
    - Place: report/toolchain.md:21 (§11.1, Source root)
    - Quote: "Otherwise single-file mode uses the current directory, and directory mode uses the directory passed to `ern build`."
    - Wrong: `ern build src` compiles `src/main.ern` as `Main`, and `ern build src/main.ern` compiles it as `Src.Main`. The second command writes `build/src/main.erc` without a word. That file is never stale, since its source exists. `ern doc d5/coin.ern` titles its page `D5.Coin`. Where both forms write the same `.erc`, the build is refused instead. The rule is stated, but a reader who has just built the directory predicts the module `Main` (principle 1).
    - Shown by:
      ```
      $ ern build --build-root build src
      $ ern build --build-root build src/main.ern; echo $?
      0
      $ find build -type f
      build/main.erc
      build/util.erc
      build/src/main.erc
      $ ern build ok/alias.ern     # after ern build ok
      ern build: ok/alias.erc holds Alias, and this build names the module Ok.Alias; name its source root with --source-root
      ```
    - Fix: Make both modes find the source root in the same way. Failing that, have single-file mode refuse a file in a subdirectory unless `--source-root` is given, and name the namespace the file would get.

11. **`ern doc src-dir` does `ern build`'s whole job, writing and sweeping `.erc` files, while `ern doc file.ern` writes none: building is done two ways.**
    - Place: report/toolchain.md:85 (§11.4)
    - Quote: "`ern doc src-dir` builds the directory as `ern build` does (§11.1)"
    - Wrong: Two jobs compile a tree and delete stale `.erc` files (principle 2). Within one job, the single-file form compiles without writing and the directory form writes (principle 1). `ern doc` removed `build/shapes.erc`, the build's output, without a word.
    - Shown by:
      ```
      $ ern doc shapes.ern > /dev/null; ls
      shapes.ern
      $ ern doc --build-root build src; find build -type f
      build/index.md
      build/net/http.erc
      build/net/http.md
      build/shapes.erc
      build/shapes.md
      ```
    - Fix: Have `ern doc src-dir` read the `.erc` files `ern build` wrote and refuse a stale tree, or make both forms write the same.

12. **Pressing `Shift-Tab` twice shows a `Since` line that `:doc` does not, though §11.2 says both show the same documentation.**
    - Place: erl/cli/src/ern_shell.erl:1091; report/toolchain.md:71 (§11.2)
    - Quote: "`:doc` shows the same documentation."
    - Wrong: `documentation/1` appends the module's `*Since v.*` when a declaration has none of its own, and `:doc` does not.
    - Shown by:
      ```
      > List.sort         (Shift-Tab twice)
      ...
          // => [1, 2, 3]

      Since 0.1.0.
      > :doc List.sort
      ...
          // => [1, 2, 3]
      >
      ```
    - Fix: Render one text for both, and state in §11.2 whether an inherited `since` is shown.

13. **An option naming a missing directory (`--load-path`, `--config-dir`, the shell's `--source-root`) is accepted without a word, and so is a malformed `ernest.conf`.**
    - Place: report/toolchain.md:29 (§11.2), :124 (§11.7)
    - Quote: "`--load-path` adds directories."
    - Wrong: A misspelled root surfaces only later, as `unknown name` (principle 3). The report says nothing of a missing directory, and the toolchain accepts it silently.
    - Shown by:
      ```
      $ ern run --load-path /nonexistent hello.erc
      hello, world
      $ ern build --load-path /nonexistent hello.ern; echo $?
      0
      $ ern run --config-dir /nonexistent hello.erc
      hello, world
      $ echo '{garbage' > .ernest/ernest.conf; ern run ../hello.erc
      hello, world
      $ printf '1\n' | ern shell --source-root /nonexistent
      > 1 : Int
      ```
    - Fix: Refuse a root that is no directory, `ern run: --load-path /nonexistent is no directory`, and state the refusal in §11.7.

14. **Every job silently takes `--` as the end of its options, which §11 does not state.**
    - Place: report/toolchain.md:15 (§11)
    - Quote: "Options are long: `--name`, or `--name value` for one that takes a value."
    - Wrong: The report is silent, and the input is accepted silently. Before the file, `ern run` drops a `--`. After the file, it passes one on to the program.
    - Shown by:
      ```
      $ ern run -- args.erc -- x
      ["--", "x"]
      $ ern build -- hello.ern; echo $?
      0
      ```
    - Fix: State `--` in §11, or refuse it before the file.

15. **The shell prints "M-Enter adds a line, Enter runs." the first time an input takes a second line, which §11.2 never states, though the code cites §11.2.**
    - Place: shell/shell.ern:1052-1059; report/toolchain.md:67 (§11.2, Editing)
    - Quote: "// Report §11.2: the first input of a session to take a second line says how it is run, once"
    - Wrong: The shell says something that §11.2's list of what it says does not hold.
    - Shown by:
      ```
      > 1
      1 : Int
      M-Enter adds a line, Enter runs.
      > (1 +
      ...
      ```
    - Fix: State the hint in §11.2's Editing paragraph, or drop it.

16. **`:output /dev/null` is accepted, though §11.2 refuses a path that names neither a terminal nor a file.**
    - Place: shell/shell.ern:343; report/toolchain.md:50 (§11.2)
    - Quote: "a path that names neither, a pipe among them, being refused"
    - Wrong: The check is `Fs.append`, which takes any device (E.17), so every character device is accepted and only a pipe or a directory is refused.
    - Shown by:
      ```
      > :output fifo1
      cannot write to fifo1: it is no terminal and no file
      > :output /dev/null
      output goes to /dev/null
      ```
    - Fix: Write "a terminal, a device or a file" in §11.2, or refuse a device that is no terminal.

17. **`--main` takes a function of any module on the load path, so the file and `--main` both name the module to run and may disagree without a word.**
    - Place: report/toolchain.md:29 (§11.2)
    - Quote: "or the function `--main` names, anywhere on the load path"
    - Wrong: Here the module to run is named twice (principle 2). A reader predicts that `--main` picks a function of the given file's module (principle 1).
    - Shown by:
      ```
      $ ern run --main Args.main hello.erc
      []
      ```
    - Fix: Refuse a `--main` outside the file's module, naming both modules.

18. **The directory build deletes files and writes no line for any of them.**
    - Place: report/toolchain.md:25 (§11.1, Cleanup)
    - Quote: "`ern build` removes every stale `.erc` from the mirrored build subtree, and each directory of the subtree that the removals leave empty"
    - Wrong: Removing files is something the toolchain does that its user does not see (principle 3). `ern doc src-dir` removes `.erc`, `.md` and `.3ern` files the same way.
    - Shown by:
      ```
      $ find build -type f
      build/main.erc
      build/net/http.erc
      build/old.erc
      $ rm src/old.ern src/net/http.ern; ern build --build-root build src; echo $?
      0
      $ find build
      build
      build/main.erc
      ```
    - Fix: Write a line for each file removed, `removed build/old.erc`, and state it in §11.1.

19. **A doc block typed at the prompt is refused as soon as Enter is pressed, while a line holding only a `//` comment takes another line.**
    - Place: report/toolchain.md:67 (§11.2, Editing)
    - Quote: "An input the parser cannot finish is one that ends where the grammar expects more"
    - Wrong: By §2.2 a doc block needs a declaration after it, so the grammar expects more. The shell refuses the block at once, so a declaration cannot be documented at the prompt, or in a startup file read in line mode, except with `M-Enter`.
    - Shown by:
      ```
      > /// Doubles.
      input 1:1:1: a doc block documents nothing here
      > // a comment
      ...
      ```
    - Fix: Treat an input that ends in a doc block as unfinished.

20. **`:browse M` and `M.` followed by `Tab` twice do the same job: each lists a module's names with their types.**
    - Place: report/toolchain.md:44, :69 (§11.2, Commands and Completion)
    - Quote: "`:browse Module` lists the exports of `Module` with their types"
    - Wrong: One job is done two ways (principle 2), and a long listing is cut to the screen with `and 14 more` in one of them and not in the other.
    - Shown by:
      ```
      > :browse List
      List.<> : (List(a), List(a)) -> List(a)
      ...
      > List.fi   (Tab)
      List.filter : (List(a!), (a!) -> Bool with e) -> List(a!) with e
      ...
      ```
    - Fix: Keep one way to list a module, or state in §11.2 why both exist.

#### Clarity

21. **Messages name files by absolute path even when they lie under the working directory, and "compile X first" names neither the module that needs X nor its place.**
    - Place: erl/cli/src/ern_build.erl:643, :182; report/toolchain.md:91 (§11.5)
    - Quote: "The file is the source's path from the working directory, or its absolute path when it lies outside that directory."
    - Wrong: The stale-module message in the same function uses `shown(Erc)` and is relative. A module with no source at all is reported positioned, `main.ern:2:16: unknown name Nowhere.Thing.name`, while one whose source exists but is not built gets this unpositioned line. `ern build ../hello.erc` objects to the source root before the extension. The report never states the message.
    - Shown by:
      ```
      $ ern build main.ern        # main.ern uses Net.Http; net/http.ern not built
      ern build: compile Net.Http first: /tmp/.../T/p1/net/http.erc: no such file or directory
      $ ern build rodir/hello.ern
      ern build: /tmp/.../T/f3/rodir/hello.erc: permission denied
      $ ern build ../hello.erc    # from T/f1
      ern build: /tmp/.../T/hello.erc is not under the source root /tmp/.../T/f1; --source-root names another
      ```
    - Fix: Name paths as §11.5 does. Report a missing dependency at the qualified name's span, such as `main.ern:3:11: Net.Http is not built: ern build net/http.ern`, and state that message in §11.1.

22. **`ern doc`'s page and `:doc` show a function's type without parameter names, yet the doc text names parameters (`n`, `ms`, `mk`, `v`) that no argument is tied to.**
    - Place: report/toolchain.md:85 (§11.4); erl/typer/src/ern_prelude.erl:302
    - Quote: "with its type (§11.5) in a code block"
    - Wrong: The `.erc` carries each parameter list (§11.1), and only `Shift-Tab` shows it. In `:doc send`, `a` is a parameter in the prose and a type variable in the signature. `List.repeat` says `n`, but its parameter is `count` (stdlib/list.ern:361). The primitives have no parameter names at all, so `Shift-Tab` inside `spawn(` shows `spawn(*() -> Unit with n*) -> Address(n) with m+`, which is the form of neither a declaration nor a call.
    - Shown by:
      ```
      > :doc Address.call
          Address.call : (Address(m), (Reply(a)) -> m, Int) -> Optional(a) with n
      Sends the request `mk(r)`, with a fresh reply `r`, and waits up to `ms`
      > :doc send
          send : (Address(a), a) -> Unit with m
      Puts `v` in the mailbox of the process at `a`, and returns at once.
      man/stdlib/list.md:356: List.repeat : (a!, Int) -> List(a!)
      man/stdlib/list.md:359: `n` copies of the value; `n` below 0 gives none.
      ```
    - Fix: Show the parameter list in the page's code block, `List.repeat(element : a!, count : Int) : List(a!)`, as `Shift-Tab` does, and give the primitives parameter names.

23. **`ern --help` says `format` follows "the style guide" and that `test` takes a module, and the usage lines differ from §11's.**
    - Place: erl/cli/src/ern_cli.erl:138, :140
    - Quote: "format  lay out modules as the style guide does"
    - Wrong: The layout is the one §11.6 states, and a user has no style guide. `ern test` takes a directory too. The usage lines write `[--load-path <load_path>]` without the `...` of a repeated option, `<main>` where §11 writes `Qualified.name`, and `<source_root>` where it writes `src-root`. Two help lines end in a space ("may be ", "its ").
    - Shown by:
      ```
      $ ern --help
        format  lay out modules as the style guide does
        test    run the tests of a module
      $ ern build --help
      Usage: ern build [--source-root <source_root>] [--build-root <build_root>]
                       [--load-path <load_path>] ...
      ```
    - Fix: "format  lay out modules in the layout of report §11.6", "test  run the tests of a module or a directory", and write the usage lines as §11 does.

24. **The shell's `:help` says `:load` compiles from source, but `:load` also loads a compiled module from the load path.**
    - Place: shell/shell/command.ern:82
    - Quote: "the module by its namespace, compiled from its source"
    - Wrong: The help line covers half of what §11.2's Loading paragraph says `:load` does.
    - Shown by:
      ```
      > :load Greet
      Greet, from /tmp/.../s4/lib/greet.erc
      ```
    - Fix: "the module by its namespace, from its source or its compiled form".

25. **`ern doc notes.txt` answers "does not end in .ern", though `ern doc` takes a `.erc` too.**
    - Place: erl/cli/src/ern_build.erl:190
    - Quote: "ern doc: notes.txt does not end in .ern"
    - Wrong: The refusal does not name the job's other accepted input, which its usage line `file.ern | file.erc | src-dir` gives.
    - Shown by:
      ```
      $ ern doc notes.txt
      ern doc: notes.txt does not end in .ern
      ```
    - Fix: "ern doc: notes.txt ends in neither .ern nor .erc".

26. **`ern format - x.ern` answers "no such file or directory -" instead of saying that `-` stands alone.**
    - Place: report/toolchain.md:99 (§11.6)
    - Quote: "`ern format -` lays out the module on standard input and writes it to standard output"
    - Wrong: Among other paths, `-` is read as a file name. The message also puts the path after "directory", unlike `x.ern: permission denied`.
    - Shown by:
      ```
      $ ern format - ugly.ern < copy.ern
      ern format: no such file or directory -
      ```
    - Fix: "ern format: - stands alone: ern format -".

27. **`ern format -` writes nothing to standard output for a module that does not parse, and §11.6 says only that such a module "is left as it is".**
    - Place: report/toolchain.md:99 (§11.6)
    - Quote: "A module that does not parse is left as it is, and its diagnostic is written as §11.5 says."
    - Wrong: For standard input the report does not say what standard output gets. A filter that replaces its input with that output empties it.
    - Shown by:
      ```
      $ printf 'fn f( : Int =\n' | ern format - 2>/dev/null | wc -c
      0
      ```
    - Fix: State in §11.6 what `-` writes for a module that does not parse: the input unchanged, or nothing with status 1.

28. **The reload message "f, a binding in the previous version; a further reload of it ends them" mixes singular and plural, and hides that `f` runs old code.**
    - Place: erl/cli/src/ern_shell.erl:1990
    - Quote: "Geo.Shape: f, a binding in the previous version; a further reload of it ends them"
    - Wrong: The line cannot be read as a sentence, and "it" can refer to the module or to `f`.
    - Shown by:
      ```
      > :reload
      Geo.Shape, compiled again
      Geo.Shape: f, a binding in the previous version; a further reload of it ends them
      ```
    - Fix: "Geo.Shape: f holds the previous version; the next reload of Geo.Shape forgets it".

29. **With `HOME` unset, the shell says "HOME is no absolute path", and it does not say that no startup file was read.**
    - Place: shell/shell.ern:223; report/toolchain.md:77 (§11.2)
    - Quote: "the history is not kept, since HOME is no absolute path"
    - Wrong: `HOME` is not set at all, which the message does not tell apart from a relative `HOME`.
    - Shown by:
      ```
      $ env -u HOME ern shell        (at a terminal)
      Ernest 0.2.0. :help for the commands, :quit to leave.
      the history is not kept, since HOME is no absolute path
      ```
    - Fix: "HOME is not set" where it is unset, and "HOME is no absolute path" where it is relative.

30. **A reserved word used as a name is reported as "expected a name instead of `after`", which does not say that `after` is reserved.**
    - Place: report/toolchain.md:91 (§11.5)
    - Quote: "input 1:1:5: expected a name instead of `after`"
    - Wrong: `after` reads as a name, so the reader cannot tell why it is not one. `fn f(receive : Int)` reports "expected a pattern".
    - Shown by:
      ```
      > let after = 1
      input 1:1:5: expected a name instead of `after`
      > fn f(receive : Int) : Int = receive
      input 3:1:6: expected a pattern instead of `receive`
      ```
    - Fix: "`after` is a reserved word (§2.4), and names nothing".

31. **A shell ended by standard input that is not UTF-8 prints `fault: ...`, the form of an input's fault, and does not say that the shell has ended.**
    - Place: report/toolchain.md:135 (§11.8)
    - Quote: "and with status 1 where it cannot start, a file that does not load or an initializer that faults, or where its standard input faults it (§8.2)"
    - Wrong: The line reads as if one input failed and the session went on, but the shell has exited with status 1.
    - Shown by:
      ```
      $ printf '1\n"\xff"\n2\n' | ern shell; echo $?
      > 1 : Int
      > fault: the standard input is not UTF-8
      1
      ```
    - Fix: "the shell ends: its standard input is not UTF-8".

32. **The guide says to see what `ern format --check` wants by formatting a copy, while `ern format - < file` shows it without one.**
    - Place: ernest_guide.md:2366 (guide §9.1)
    - Quote: "what it wants is what `ern format` writes, seen by formatting a copy"
    - Wrong: The guide teaches a workaround for a job that `-` already does.
    - Shown by:
      ```
      $ ern format - < ugly.ern | diff ugly.ern -
      ```
    - Fix: "what it wants is what `ern format - < file` writes".

33. **`Home`, `End` and `Delete` do nothing at the prompt, though the line is said to be edited with Readline's Emacs keys, and Readline binds all three.**
    - Place: report/toolchain.md:67 (§11.2, Editing)
    - Quote: "A key the terminal sends as an escape sequence, other than these and `Shift-Tab`, does nothing either: `Delete`, `Home`, `End` and the function keys among them."
    - Wrong: The departure is stated, but a reader told "Readline's Emacs keys" presses these keys and nothing happens, and nothing tells them why (principle 1).
    - Shown by:
      ```
      > abc   then Home, then X
      > abcX
      ```
    - Fix: Bind `Home` and `End` to `C-a` and `C-e`, and `Delete` to `C-d`'s deletion.

34. **A tab after a command's name is not taken as a separator, and the refusal echoes the raw tab.**
    - Place: report/toolchain.md:41 (§11.2, Commands)
    - Quote: "A command begins with `:` and is not an Ernest function."
    - Wrong: §11.2 does not say what separates a command from its argument. The shell takes a space but not a tab, and writes the control character back.
    - Shown by:
      ```
      $ printf ':type\t1\n' | ern shell
      > no command :type<TAB>1; :help lists them
      ```
    - Fix: State the separator in §11.2, and write a control character in a refusal as its escape, as fault causes are written.

### X, the diagnostics

#### Defects

1. **An error in a `<-` binding does not stop its block: a later statement's error hides it, and later statements change the types it prints.**
   - Place: test/diagnostics.md:2754; §11.5
   - Quote: "expected Int, found #(Int, a)"
   - Wrong: The pattern is `#(a, b)`. The `Int` in the printed type comes from `Some(a)` on the next line, so the statements after the failed `<-` were checked. §11.5 says "an error in any other binding does [stop the block], since what follows may use the name". When a later statement has an error of its own, the `<-` error is not reported at all, although it follows from nothing ("the checker reports every error that does not follow from another").
   - Shown by:
     ```
     $ cat bind5.ern
     fn f() : Optional(Int) = {
         let x <- 1;
         let z : String = 2;
         Some(x)
     }
     $ ern build bind5.ern
     bind5.ern:3:22: the value does not have the declared type: expected String, found Int
     (nothing is reported for `let x <- 1`)
     $ cat bind6.ern
     fn f(o : Optional(Int)) : Optional(Int) = {
         let #(a, b) <- o;
         let z : String = a;
         Some(1)
     }
     $ ern build bind6.ern
     bind6.ern:2:9: the pattern does not fit the value inside the sum type: expected Int, found #(String, a)
     ```
   - Fix: Check a `<-` binding's value and pattern before the rest of its block, and stop the block on an error there, as §11.5 says.

2. **Printed types rename the variables a declaration's annotations name, `t` to `a` and `m` to `e`, so a single message can show two different variables as `a`.**
   - Place: test/diagnostics.md:1769, 1772, 665, 671; §11.5
   - Quote: "Ops(..Set) fills size with Set.size: expected (a) -> Bool, found (Set(a=!)) -> Int"
   - Wrong: §11.5 says "A type variable is printed under its annotation's name; an unnamed one is `a`, `b`, ... avoiding the names in use." `Ops` declares `size : (s) -> Bool`, but the label says "Ops declares size : (a) -> Bool". That `a` stands beside Set.size's own `a`, so the message reads as if `a` must equal `Set(a)`. `Io.println` prints `with e+` in a label, but `with m+` in the shell's `:type` and in E.1's `with m`.
   - Shown by:
     ```
     $ cat named.ern
     fn g(x : Int, y : t) : t with m = {
         let _ = self();
         y
     }

     fn f() : Unit with Int = g("x", Unit)
     $ ern build named.ern
     named.ern:6:28: the argument does not fit g: expected Int, found String
       |                          - g : (Int, a) -> a with e+
     $ printf ':type Io.println\n' | ern shell
     > Io.println : (String) -> Unit with m+
     ```
   - Fix: Print a callee's or a field's type under its declaration's variable names, and rename a variable only when another variable in the same message already has that name.

3. **The entry for a recursive top-level `let` prints, first and across the whole declaration, a type mismatch that exists only because of the self-dependency error printed after it.**
   - Place: test/diagnostics.md:2606
   - Quote: "recursive use does not match the definition: expected (Bool) -> Int, found (Int) -> Int"
   - Wrong: A `let` may not name itself at all (§4.6), so the mismatch follows from the second error. §11.5 reports only errors that follow from no other, and puts a mismatch "at the innermost expression whose type is fixed: ... an argument", which here is `1`, not the whole `let`. Fixing the mismatch as told still leaves the real error.
   - Shown by:
     ```
     $ cat rec1.ern
     let f = fn(x) = if x then f(true) else 2
     $ ern build rec1.ern
     rec1.ern:1:1: the initializer of f depends on itself
       | = help: a recursive function is declared with `fn f(...) = ...`
     ```
   - Fix: Report only the self-dependency for a top-level `let` that names itself.

4. **§11.5 says a missing requirement's fix is a help line, but §4.9 and every entry of that kind put it in the message, so the report contradicts itself.**
   - Place: §11.5 (report/toolchain.md:93); §4.9 (report/language.md:372); test/diagnostics.md:2160, 2175, 2190, 2204, 2329
   - Quote: "with the help line that adds the requirement, or, under a top-level `let`, that a `fn` declares it"
   - Wrong: None of the five entries has a `help:` line. The fix comes after a `;` in the message, as §4.9 quotes it: "fromList needs a.compare, which unique does not declare; add needs a.compare", and "fromList needs a.compare; a let cannot declare it, so write a fn with the requirement".
   - Shown by: none
   - Fix: Choose one form: put "add needs a.compare" on a `= help:` line, or have §11.5 say that the message ends with the fix.

5. **A rejected call site's error names no parameter and marks the callee, so with two arguments of one type the reader cannot tell which fails.**
   - Place: §11.5 (report/toolchain.md:95); test/diagnostics.md:2143, 2655, 3654, 3914
   - Quote: §11.5: "An error at a rejected call site names the parameter and the origin of its restriction"
   - Wrong: The message says "its argument" and prints the callee's signature. The span covers the callee's name, not the argument. Nothing marks the expression in the callee's body (`a == b`, `#(x, x)`) that caused the restriction.
   - Shown by:
     ```
     $ cat restr2.ern
     fn keep(first, second) = #(first, second, second)

     fn f(r : Reply(Int), s : Reply(Int)) : Unit with m = {
         let #(a, b, c) = keep(r, s);
         answer(a, 1);
         answer(b, 1);
         answer(c, 1)
     }
     $ ern build restr2.ern
     restr2.ern:4:22: a reply-carrying value, Reply(Int), passed where keep duplicates or discards its argument: keep : (a, b!) -> #(a, b!, b!)
     4 |     let #(a, b, c) = keep(r, s);
       |                      ^^^^
     ```
   - Fix: Mark the rejected argument, name its parameter (`second`), and label the use in the callee that gave the restriction where it is in the module.

6. **Eleven catalogue headings cite a report section that does not hold the rule: §3.8 for abstract types, §4.4 for function syntax, §5.2 for `if`, §3.3 and §3.2 for type syntax.**
   - Place: test/diagnostics.md:325, 338 (§3.8, Foreign types); 435, 887 (§4.4, Abstract types); 583 (§5.2, Calls); 914 (§3.3, Lists); 501, 529, 543 (§3.2, Tuples); 1095 (§4.5 for `let`); 515 (§3.2 for the `FnType`/`ParenType` rule of §3)
   - Quote: "### `abstract` before something other than a type (§3.8)"
   - Wrong: A reader who follows the citation to learn the rule lands on another rule. The right sections are §3.6 and §4.4 for abstract types, §4.5 for a function's head, §5.8 for `if`, §2.3 and §4.3 for a type's name, §3 for the type grammar, and §4.2 and §4.6 for a top-level `let`.
   - Shown by: none
   - Fix: Correct the citations in these eleven headings.

7. **"zero is not a member" underlines only the type variable `a`, not `zero`, which is the erroneous part.**
   - Place: test/diagnostics.md:2257
   - Quote: "1 | fn sum(list : List(a)) : a needs a.zero, a.+ =" with a single `^` under the `a` of `a.zero`
   - Wrong: §11.5 says the erroneous span is underlined. The span names the variable, which is valid. The neighbouring entry "b is no type variable of the signature" underlines all of `b.compare`.
   - Shown by: none
   - Fix: Underline `zero`, or all of `a.zero`.

8. **§11.5 says a fill's error is reported "at the construction", but the entries underline the namespace after `..`.**
   - Place: §11.5 (report/toolchain.md:93); test/diagnostics.md:1753, 1769, 1790
   - Quote: "is reported at the construction, naming the field and the namespace or the variable"
   - Wrong: The spans are `Set` and `OrderedSet` inside `Ops(..Set)`, not the construction. The narrower span reads better, but it is not what the report says.
   - Shown by: none
   - Fix: Have §11.5 say "at the namespace after `..`", or underline the construction.

9. **The catalogue has no entry for two diagnostics §11.5 specifies: `Io.show` at a type that is not known whole, and a callee named "the callee".**
   - Place: test/diagnostics.md:1 ("Errors the lexer, the parser and the checker give, each with one small program"); §11.5
   - Quote: "and at any other type that is not known whole (Appendix E.1) with the request to annotate it"
   - Wrong: Both messages exist and are worded well, but no entry shows them, so neither is held to the compiler's output.
   - Shown by:
     ```
     $ cat show.ern
     fn f() : String = Io.show([])
     $ ern build show.ern
     show.ern:1:19: Io.show writes a value by its type, which is not known whole here: List(a)
     $ cat lam.ern
     fn f() : Int = (fn(x : Int) = x)("one")
     $ ern build lam.ern
     lam.ern:1:34: the argument does not fit the callee: expected Int, found String
     ```
   - Fix: Add both programs to the catalogue.

#### Clarity

10. **When a pattern variable hides a reply, the message says only that the reply is "not consumed on this path"; it should label the binder that hides it.**
    - Place: test/diagnostics.md:3819-3836
    - Quote: "the reply-carrying value r is not consumed on this path"
    - Wrong: The underlined body is `Io.println(Int.toString(r))`, which visibly uses `r`. Nothing says that `Some(r)` binds a new `r`. The heading names the cause, but the message does not, and a reader who made this mistake would not see it. §11.5 already labels a use that the module's own declaration hides from the prelude, but has no rule for a local name hidden this way.
    - Shown by: none
    - Fix: Label the pattern's `r`, "this `r` hides the reply `r` bound at line 1", and add the rule to §11.5.

11. **§11.5 defines the help line as "naming the fix", yet sets help lines that name a rule or a reason, so the `Nest` entry gives no fix.**
    - Place: §11.5 (report/toolchain.md:91, 93); test/diagnostics.md:1076, 1090
    - Quote: "= help: no function could walk the type, since a recursive call is at the definition's own type (§3.9)"
    - Wrong: Having written `Deeper(Nest(List(a)))`, a reader learns why it is refused but not what to write. §3.9 itself gives the allowed form, `Deeper(List(Nest(a)))`. §11.5's "a help line saying that no function could walk the type" and "a help line naming the rule" both contradict "at most one `help:` line naming the fix".
    - Shown by: none
    - Fix: Make the help name the fix ("name the type at its parameters, as Deeper(List(Nest(a)))"), and keep the reason in the message.

12. **For an effect variable, "e is no type variable of the signature" is false on its face, since `e` stands in the signature after `with`.**
    - Place: test/diagnostics.md:2285; §4.9
    - Quote: "e is no type variable of the signature"
    - Wrong: The help corrects it, but the message contradicts what the reader sees in `with e`. §4.9 gives one message for two different errors: a variable in effect positions alone, and one the signature does not name.
    - Shown by: none
    - Fix: Give the effect case its own message: "e is an effect variable, and a requirement names a type variable that stands in a value position".

13. **The `Foreign.from` message ends with the type `a!`, which reads as an exclamation, and its help opens with a fix that cannot apply to a signature's type variable.**
    - Place: test/diagnostics.md:2344-2348
    - Quote: "which is not known whole here: a!"; "= help: annotate the value where it is bound; a value of a type variable is given by a `foreign fn` ..."
    - Wrong: `x` is already annotated `: a`, so annotating it more changes nothing. The fix that applies is the help's second clause.
    - Shown by: none
    - Fix: Quote the type in backticks, or move it before the end of the sentence. At a type variable of the signature, give the `foreign fn` clause alone.

14. **Only replies passed to a function get the help on discharging them; `_`, `as`, omitted fields and "never consumed" get none, and "consumed" and "discharged" alternate.**
    - Place: test/diagnostics.md:3585, 3602, 3621, 3640, 3752, 3773; §11.5 (report/toolchain.md:93)
    - Quote: "`_` would discard a reply-carrying value"; "a reply is discharged by answering it, passing it on once, or matching it (§6.6)"
    - Wrong: A reader who wrote `let _ = r` is told what is wrong but not what to do. That is the same fix the call cases name. §6.6 and Appendix F define the word "consumed".
    - Shown by: none
    - Fix: Give every reply-obligation error the same help line, worded with §6.6's "consumed".

15. **The help for `unit` suggests `size(n * 8)`, but in its own program `n` is the segment's value, so the help reads as "the value times 8".**
    - Place: test/diagnostics.md:850, 858
    - Quote: "fn f(n : Int) : Bytes = <<n:size(2)-unit(8)>>" / "write `size(n * 8)`"
    - Wrong: The size written is `2`, and the fix is `size(16)`. The fixed text happens to share its name with the program's variable.
    - Shown by: none
    - Fix: Build the help from the sizes written, "write `size(2 * 8)`", or use a name that cannot clash, "`size(count * 8)`".

16. **When a later statement settles an operand's type, the mismatch message does not label that statement, so the "found" type has no visible source.**
    - Place: test/diagnostics.md:1594, 1993
    - Quote: "the result of `+`: expected String, found Int"
    - Wrong: In `let s : String = a + b; let n : Int = a;` the `Int` comes from line 3, and in the field case `p` is `Point` because of `let q : Point = p` on line 5. Only the annotation that fixed "expected" is labelled. Resolution after inference (§4.8) is new to most readers, and the message hides where the type came from.
    - Shown by: none
    - Fix: Add a label at the use that settled the operand's type, "a is Int here".

17. **The occurs-check messages for `<-` label the block's value but not the two expressions that force the type to contain itself, so the fix is hard to find.**
    - Place: test/diagnostics.md:2790, 2809
    - Quote: "`<-` on an Optional: a type that would contain itself (Optional(a) against a)"
    - Wrong: The cycle comes from `Some(o)` and `Some(y)` sharing one type. The label marks the whole `if` and says "the block's value has type Optional(a)", and it does not say why that is a problem.
    - Shown by: none
    - Fix: Label the two branches, `Some(o)` and `Some(y)`, whose types tie `o` to its own contents.

18. **"expected a, found Int" against a rigid variable has no help line saying that `a` stands for every type.**
    - Place: test/diagnostics.md:2625, 2639
    - Quote: "the body does not have the declared result type: expected a, found Int"
    - Wrong: A reader new to rigid type variables (§3.9, "means every type and is rigid") reads `a` as "to be inferred", and the message does not correct that.
    - Shown by: none
    - Fix: Add the help "a is a type variable of the signature and stands for every type; the body must work for any a".

19. **§11.5's "the line before" does not say which line it precedes, and the output shows the line before the first line shown, so `...` can stand for one blank line.**
    - Place: §11.5 (report/toolchain.md:91); test/diagnostics.md:1108, 1126, 2043
    - Quote: "The source shows a gutter of line numbers, the line before, the erroneous span underlined with `^`"
    - Wrong: Read in that order, the sentence means the line before the erroneous span. In "A value declared twice", line 2 is that line, yet `...` replaces it, which saves no space.
    - Shown by: none
    - Fix: Say "the line before the first line shown", or show the line before the erroneous span.

20. **A type parameter written twice underlines the whole declaration, while a field or variable written twice underlines the second and labels the first.**
    - Place: test/diagnostics.md:1047-1049
    - Quote: "type variable a appears twice among the parameters of Pair"
    - Wrong: In `type Pair(a, b, a)`, the reader must find the two `a`s alone.
    - Shown by: none
    - Fix: Underline the second `a`, and label the first "first written here".

21. **Messages cite the report in two styles, "(§3.9)" and "(report §5.9)".**
    - Place: test/diagnostics.md:2911, against 1076, 2257, 2655
    - Quote: "a guard is pure (report §5.9)"
    - Wrong: One label adds the word "report", and every other citation omits it.
    - Shown by: none
    - Fix: Use one style.

22. **The fill message "leaves a undetermined" does not ask for an annotation, as every other undetermined-type message does, and "a" reads as an article.**
    - Place: test/diagnostics.md:1790; §5.6; §3.9 (report/language.md:239)
    - Quote: "fromList needs a.compare, and the record's type leaves a undetermined"
    - Wrong: The fix is an annotation on `ops`, but only this message about an undetermined type omits "annotate it". §3.9's list of "five places" where inference asks for an annotation does not include this one.
    - Shown by: none
    - Fix: Write "leaves the variable a undetermined; annotate it", and add the case to §3.9's list.

23. **"expected a declaration (type, abstract, fn, let, foreign)" omits `export`, which also begins a declaration.**
    - Place: test/diagnostics.md:305; Appendix A `Declaration`
    - Quote: "expected a declaration (type, abstract, fn, let, foreign) instead of integer 1"
    - Wrong: Appendix A says `Declaration = [ "export" ] ( ... )`.
    - Shown by: none
    - Fix: Add `export` to the list.

24. **"the implementation of size is named module:function/arity, here module:function/1" is hard to read as the form to write.**
    - Place: test/diagnostics.md:1202
    - Quote: "is named module:function/arity, here module:function/1"
    - Wrong: "is named ... here ..." does not say that the string `"tuple_size"` lacks its module and arity, or that `"erlang:tuple_size/1"` is the shape wanted.
    - Shown by: none
    - Fix: Say "write the implementation as module:function/arity, with arity 1 for size, as `erlang:tuple_size/1`".

25. **The `receive` guard that orders `Money` has no help line, while the two other `receive` guard errors suggest receiving the message and matching it.**
    - Place: test/diagnostics.md:3532
    - Quote: "a `receive` guard orders only Int, Float, String, and Char, not Money"
    - Wrong: The fix is the same as for the other two guard errors, but this one does not say it.
    - Shown by: none
    - Fix: Add "= help: receive the message and `match` it".

26. **The heading "A `receive` guard that compares a sum" means an arithmetic sum, but elsewhere the catalogue uses "sum" for a sum type.**
    - Place: test/diagnostics.md:3556
    - Quote: "### A `receive` guard that compares a sum (§6.3)"
    - Wrong: The program is `n + 1 > 2`. The `<-` entries use "sum type" for Either and Optional.
    - Shown by: none
    - Fix: "A `receive` guard that compares a computed value".

#### Judged clear

240 of the 244 entries were judged clear. Each `###` heading of test/diagnostics.md counts as one entry, the three shell sessions among them. An entry was judged clear when its message, labels and help, read beside its program, say what is wrong and point to a change that compiles, or show that no such change exists, as for `g(g)`. A message can be clear and still have a defect: the entries behind findings 1 to 3 are counted clear. Four entries are not clear: the reply hidden by a pattern variable (3819), `Nest` (1065), and the two `<-` occurs checks (2779, 2798).

### S, security

#### Exposures

1. **`Tcp.close`, and an owner's death, leave the host socket and its unsent bytes open as long as the peer withholds reads, so remote clients can exhaust descriptors.**
   - Place: erl/runtime/src/ern_tcp.erl:287 (and :283 for the owner's death)
   - Quote: "'Close' -> _ = closed(Connection), gen_tcp:close(Socket),"
   - Wrong: E.18 says `close` ends the socket's process "and the host's socket closes either way". The process does end at once, but the host closes a port that still holds queued output only once that queue has drained. A peer that stays connected and reads nothing therefore holds the descriptor, and every byte the program wrote, for as long as it likes. A server that writes a reply and closes is held open by each such client.
   - Shown by:
     ```
     // linger2.ern; the client connects with SO_RCVBUF 4096 and never reads
     let written = Tcp.write(socket, Bytes.repeat(<<0>>, 50000000), 2000);   // Right(Unit)
     Tcp.close(socket);
     Io.println("read: " <> Io.show(Tcp.read(socket, 1000)))
     $ ern run linger2.erc
     2026-10-04T08:39:01.188Z Linger2.main faulted: callee was closed       # the process has ended
     $ ss -tn | grep 47124                                                  # sampled every 10 s
     08:39:54  ESTAB 0 1787904 127.0.0.1:47124 127.0.0.1:...                # the host socket has not
     # linger3.ern, the same with a 280 s wait after the close at 08:40:30:
     08:44:58  ESTAB 0 1787904 127.0.0.1:47125 ...                          # still open 4.5 minutes on
     ```
   - Fix: Close the host socket within a stated bound on `close` and on the owner's death, for example a fixed linger or a send timeout that closes, dropping what the peer has not taken, and state the bound in E.18.

2. **`Fs.copy` creates its destination with the umask's mode rather than the source's, so a copy of a 0600 file can be read by every user.**
   - Place: erl/runtime/src/ern_fs.erl:164
   - Quote: "case file:copy({Source, [raw]}, {Destination, [raw]}) of"
   - Wrong: `file:copy` opens a new destination as 0666 less the umask and does not carry the source's permission bits, as cp(1) does. E.17 says nothing of the mode. A program that copies a key, a token or the shell's history publishes it.
   - Shown by:
     ```
     $ printf 'top secret\n' > secret; chmod 600 secret; umask 022
     // copymode.ern
     Io.println("copy: " <> Io.show(Fs.copy(Path("secret"), Path("copy.txt"), 1000)))
     $ ern run copymode.erc; stat -c '%a %n' secret copy.txt
     copy: Right(Unit)
     600 secret
     644 copy.txt
     ```
   - Fix: Create a new destination with no more than the source's permission bits, set before any byte is written, and state the mode in E.17.

3. **The shell runs a startup file whose group can write it or its directory, so another member of that group runs code as the user at the next `ern shell`.**
   - Place: shell/shell.ern:262
   - Quote: "(entry.user == Os.user || entry.user == 0) && Int.bitAnd(entry.mode, 0o002) == 0"
   - Wrong: §11.2 refuses a startup file "another user could change". The check refuses only a file or directory that every user may write. So a group-writable `~/.ernest/startup` is run, and so is a group-writable `~/.ernest` (umask 002) or a shared, setgid project directory named by `--config-dir`. A startup input may declare a `foreign fn`, so it can run anything.
   - Shown by:
     ```
     $ chmod 775 home/.ernest; chmod 664 home/.ernest/startup      # it holds Io.println("startup ran")
     $ printf '1 + 1\n' | HOME=$PWD/home ern shell
     Ernest 0.2.0. :help for the commands, :quit to leave.
     startup ran
     > 2 : Int
     ```
   - Fix: Refuse a file or directory that its group or others may write (mode & 0o022), as ssh's StrictModes does, and write "its group or anyone" in §11.2.

4. **Subscribing to the terminal, as `ern shell` does at a terminal, runs the first `sh` and `stty` on PATH, though the module refuses PATH's `stty` elsewhere.**
   - Place: erl/runtime/src/ern_tty.erl:354
   - Quote: "Stty = open_port({spawn_executable, os:find_executable(\"sh\")}, [{args, [\"-c\", \"stty -g >&4\"]}"
   - Wrong: `stty/1` uses /bin/stty or /usr/bin/stty because "the first that PATH names ... could be any program in any directory the PATH lists". But `settings/0`, which runs first on every subscription, finds `sh` by PATH and lets `sh` find `stty` by PATH. With `.`, an empty entry or a writable directory on PATH, a file named `stty` there runs as the user when a program subscribes or the shell starts at a terminal. Nothing in the command says so.
   - Shown by:
     ```
     $ cat fakebin/stty
     #!/bin/sh
     echo "planted stty ran with: $*" >> planted.log
     exec /bin/stty "$@"
     $ (sleep 5; printf ':quit\r') | PATH=$PWD/fakebin:$PATH script -qc "/bin/stty rows 24 cols 80; ern shell" /dev/null
     $ cat planted.log
     planted stty ran with: -g
     ```
   - Fix: Run `/bin/sh -c "<system_stty()> -g >&4"` with the absolute path `system_stty/0` found, and never a `sh` or `stty` that PATH resolves.

5. **`Fs.removeAll` of an empty path, a name a client may send, faults its caller as the helper's failure instead of answering an error.**
   - Place: erl/runtime/c_src/ern_exec.c:469
   - Quote: "if (length < 2) return 1;"
   - Wrong: An empty path is a frame of `p` alone. The helper refuses that frame by exiting, so ern_fs reports "the runtime's helper ern_exec failed" and the caller faults (§7.4). `Fs.remove` answers `Left(NotFound)` for the same path. E.17 faults only "where the runtime's helper fails", and here it did not fail.
   - Shown by:
     ```
     Io.println("remove: " <> Io.show(Fs.remove(Path(""), 1000)));
     Io.println("removeAll: " <> Io.show(Fs.removeAll(Path(""), 1000)))
     $ ern run empty.erc
     remove: Left(NotFound)
     2026-10-04T08:50:35.596Z Empty.main faulted: the runtime's helper ern_exec failed
     ```
   - Fix: Answer `Left(NotFound)` for an empty path in ern_fs before the helper is started, or have the helper answer `f` with `enoent` for it.

#### Hardening

6. **`Path.<>` answers an absolute second operand whole and keeps `..`, so `root <> Path(name)` with a client's name reaches any file, and Path has nothing that confines.**
   - Place: stdlib/path.ern:40
   - Quote: "if isAbsolute(under) then under else join(split(path) <> split(under))"
   - Wrong: The operator that puts a path under a directory is the natural way to place a client's name under a root. It gives `/etc/hostname` for `Path("root") <> Path("/etc/hostname")`, `root/../x` for `../x`, and the root itself for `""` and `"."`, so a `Fs.removeAll` built this way removes the root or any tree. E.14 and §9.6 document the behaviour. The hazard is that Path has no function beside it that normalizes a path or tests that one path stays under another.
   - Shown by:
     ```
     // serve.ern
     let path = Path("root") <> Path(asked);
     $ ern run serve.erc
     /etc/hostname -> /etc/hostname -> Right(4)
     ../serve.ern -> root/../serve.ern -> Right(412)
     // empty.ern: Path.toString(Path("uploads") <> Path("")) is "uploads"
     ```
   - Fix: Add to Path a function that places a relative path under a root and answers None for an absolute path, an empty one, or one with a `..` or `.` segment.

7. **A process of the program that foreign code hands back at another address type is taken as the program's own, unchecked, so ill-typed messages reach its mailbox.**
   - Place: erl/runtime/src/ern_rt.erl:163; §8.4
   - Quote: "_ -> own_or_foreign(Pid, Pid, Pid, Descriptor, Bound)"
   - Wrong: §8.4 makes an address "foreign unless it names a process of the program", and the program's own only "at the type it crossed at". A pid that crossed as a `Process`, which goes out bare with no proxy, or that foreign code took with `erlang:self/0`, crossed at no address type. Yet `held/3` returns it bare at whatever type the foreign function declares. A message of the wrong type then reaches the process, and the fault surfaces as a raise in a standard library shim. That is the mistake the boundary's checks exist to catch.
   - Shown by:
     ```
     foreign fn first(processes : List(Process)) : Address(Int) = "erlang:hd/1"
     export fn main() : Unit with String = {
         send(first([Process.fromAddress(self())]), 42);
         receive { text -> Io.println("received a String of size " <> Int.toString(String.size(text))) }
     }
     $ ern run confuse.erc
     ... Confuse.main faulted: foreign function string:length/1 raised error:function_clause
     ```
   - Fix: In §8.4 and `held/3`, treat a foreign result that names a process of the program as a bad return unless it came back through a proxy at the type it went out at.

8. **The standard library takes answers to its own calls unchecked even from a socket or program address foreign code made, so a foreign library's wrong answer reaches the shims.**
   - Place: §8.4; erl/runtime/src/ern_rt.erl:264
   - Quote: "and the answer to a call the library makes"
   - Wrong: The runtime knows such an address is foreign, since it holds it as `{foreign, Pid, ...}`. Yet `Tcp.read`'s answer from it is not checked. A foreign socket or TLS library that answers `Right(42)` faults deep in `Bytes.size`, as a raise of `erlang:byte_size/1`.
   - Shown by:
     ```
     %% fake_socket.erl, compiled on the load path: answers each 'Read' with {Reply, {'Right', 42}}
     foreign fn openSocket() : Address(Tcp.SocketMsg) = "fake_socket:open/0"
     match Tcp.read(openSocket(), 1000) { Right(bytes) -> ... Bytes.size(bytes) ... }
     $ ern run --load-path . masquerade.erc
     ... Masquerade.main faulted: foreign function erlang:byte_size/1 raised error:badarg
     ```
   - Fix: Exempt only a library call whose callee is a system process or one the runtime opened, and check the answer to a library call to a foreign address against its Reply's type.

9. **Fs can create a file only with the umask's mode, so a program that writes a secret leaves it readable by all until a later `setMode`.**
   - Place: Appendix E.17; erl/runtime/src/ern_fs.erl:111
   - Quote: "Fs.makeFile : (Path, Bytes, Int) -> Either(Io.Error, Unit) with m // a new file, or none where the path names something"
   - Wrong: `makeFile` and `write` create the file and write its bytes before any `setMode` can run. Under umask 022 the secret is 0644 from its creation, and another user who opens it in that window keeps the descriptor. `ern config` does this right in Erlang by setting the mode before the data. An Ernest program cannot.
   - Shown by:
     ```
     // private.ern
     let made = Fs.makeFile(Path("token"), String.toUtf8("s3cret\n"), 1000);
     $ umask 022; ern run private.erc
     Right(Unit) mode then: Right(Some("644"))
     ```
   - Fix: Give `makeFile`, or a function beside it, the mode the new file is created with, applied before its bytes are written.

10. **`Fs.removeAll` holds a descriptor open for each level of the tree, so a tree deeper than the descriptor limit, which any writer of the directory can make, is not removed.**
    - Place: erl/runtime/c_src/ern_exec.c:432
    - Quote: "error = empty_directory(inner);"
    - Wrong: `remove_entry` recurses with each directory still open. Under the common limit of 1024, a chain of 1200 directories answers `Left(Other("too many open files"))` and is left in place. One deep chain stops a program that cleans a shared or upload directory.
    - Shown by:
      ```
      $ mkdir deep; (cd deep; for i in $(seq 1200); do mkdir d; cd d; done)
      $ (ulimit -n 1024; ern run deep.erc)        # Fs.removeAll(Path("deep"), 60000)
      Left(Other("too many open files"))
      ```
    - Fix: Walk holding a bounded number of descriptors: close each directory before descending, and reopen the parent through `..`, checked against the device and inode it had.

11. **The shell makes `~/.ernest` its owner's alone, then reads and appends through a history link already there, so typed inputs go wherever that link points.**
    - Place: shell/shell/history.ern:53 (and :108)
    - Quote: "let _ <- Fs.makeDir(directory, fileMs); Fs.setMode(directory, 0o700, fileMs)"
    - Wrong: §11.2 makes the directory its owner's alone before the file is read or written. A history file, or a link named history, put there while the directory was open to others stays, and `Fs.append` follows the link. `ern config` refuses such a directory for this reason (erl/cli/src/ern_cli.erl:1204).
    - Shown by:
      ```
      $ chmod 777 home3/.ernest; ln -s $PWD/elsewhere/collected home3/.ernest/history   # collected is 0666
      $ (sleep 5; printf 'let password = "hunter2"\r'; sleep 2; printf ':quit\r') \
          | HOME=$PWD/home3 script -qc "/bin/stty rows 24 cols 80; ern shell" /dev/null
      $ ls -la home3/.ernest; cat elsewhere/collected
      drwx------ ... .
      lrwxrwxrwx ... history -> .../elsewhere/collected
      let password = "hunter2"
      :quit
      ```
    - Fix: Keep no history where the history file is a link or is not the user's own regular file, and say so once, as for a startup file another could change.

12. **bin/ern clears ERL_AFLAGS, ERL_FLAGS, ERL_ZFLAGS and ERL_LIBS but not ERL_COMPILER_OPTIONS, which every compile reads. With `.` on the code path, a .beam in the working directory runs.**
    - Place: bin/ern:59; erl/cli/src/ern_shell.erl:2434
    - Quote: "unset ERL_AFLAGS ERL_FLAGS ERL_ZFLAGS ERL_LIBS"
    - Wrong: The launcher clears the four because they "would change the host, or run code with -eval, with nothing in the command saying so". ERL_COMPILER_OPTIONS does the same to each `compile:forms` the emitter and the shell make, since neither passes `no_env_compiler_options`. `ern build` also keeps the host's `.` on its code path, which only run, test and shell drop. So a parse transform of the named module in the working directory runs during a build.
    - Shown by:
      ```
      $ cat planted.erl      # parse_transform/2 writes PLANTED_RAN; erlc planted.erl
      $ ERL_COMPILER_OPTIONS='[{parse_transform, planted}]' ern build hi.ern; ls PLANTED_RAN
      PLANTED_RAN
      $ printf '1 + 2\n' | ERL_COMPILER_OPTIONS='[{parse_transform, planted}]' ern shell
      > fault: foreign function ern_shell:run/4 raised error:{emitted_erlang_does_not_compile, ... undef_parse_transform ...
      ```
    - Fix: Pass `no_env_compiler_options` to every `compile:forms`, and drop `.` from the code path for every job.

13. **A program's environment gains PWD, which the launcher's sh exports, though §11 says the environment is the one `ern` was started in.**
    - Place: bin/ern:1; erl/runtime/c_src/ern_exec.c:94
    - Quote: "static const char *const names[] = {\"PATH\", \"BINDIR\", \"EMU\", \"PROGNAME\", \"ROOTDIR\","
    - Wrong: dash exports PWD as it runs bin/ern. `given_environment` restores nine names but not PWD. A program started without PWD, or with a stale one, sees the launcher's.
    - Shown by:
      ```
      $ env -i HOME=$HOME PATH=/usr/local/bin:/usr/bin:/bin FOO=bar ern run fds.erc     # Os.run of env
      HOME=/home/jocke
      PATH=/usr/local/bin:/usr/bin:/bin
      PWD=/tmp/.../review/S/os
      FOO=bar
      ```
    - Fix: Keep PWD as given under ERN_GIVEN_PWD in bin/ern, and restore or unset it in `given_environment`.

#### Clarity

14. **E.18 says a socket has no options, but every listener sets the host's SO_REUSEADDR, a choice the report does not state.**
    - Place: erl/runtime/src/ern_tcp.erl:83; Appendix E.18
    - Quote: "Options = [binary, {active, false}, {reuseaddr, true}, {packet, raw},"
    - Wrong: "There are no options" reads as the host's defaults. `reuseaddr` lets a listener bind a port still in TIME_WAIT, and on BSD and macOS it lets a listener bind a more specific address beside a wildcard listener on the same port. That is an unstated semantic choice.
    - Shown by: none
    - Fix: State in E.18 that a listener reuses its address, and what that allows, or drop the option.

15. **`:output` takes any device, `/dev/null` among them, where §11.2 takes only a terminal or a file.**
    - Place: shell/shell.ern:343; §11.2
    - Quote: "match Fs.append(path, <<>>, fileMs) {"
    - Wrong: §11.2 refuses "a path that names neither" a terminal nor a file. The shell tests a path with an append, and E.17 allows an append to every device. So /dev/null, or a disk the user may write, is accepted, and what programs write is lost there.
    - Shown by:
      ```
      $ printf ':output /dev/null\n:output\n' | ern shell
      > output goes to /dev/null
      > output goes to /dev/null
      ```
    - Fix: Refuse a device that is not a terminal in `:output`, or write "a device" in §11.2.

#### Where the language made the work harder

16. **Fs has no read that refuses a link, so a program serving files under a root that others can write cannot stop a planted link from leading out.**
    - Place: Appendix E.17
    - Quote: "A function follows the symbolic links of the paths it is given, but for a path's last segment where it names a link"
    - Wrong: Written in Ernest, the confinement can refuse absolute paths and `..` by hand. But a link `planted -> /etc/hostname` under the root is still read, and a `readLink` check before the read is a race. Only `removeAll` walks refusing links, through the helper.
    - Shown by:
      ```
      fn confined(root : Path, asked : String) : Optional(Path) = {
          let path = Path(asked);
          if Path.isAbsolute(path) || List.any(Path.split(path), fn(segment) = segment == ".." || segment == ".") then
              None
          else
              Some(root <> path)
      }
      $ ln -s /etc/hostname root/planted; ern run confine.erc
      index.txt -> Right(7)
      /etc/hostname -> refused
      ../confine.ern -> refused
      planted -> Right(4)
      ```
    - Fix: Give Fs a read and a write that refuse a link in any segment below a given root, walking by open directories as the helper's removal does.

17. **One file whose name is not UTF-8 makes `Fs.list` fail for its whole directory, and no Path can name that file to remove it.**
    - Place: Appendix E.17 (`Fs.list`); §8.2
    - Quote: "a name that is not UTF-8 answers `Left(NotUtf8(name))`"
    - Wrong: Anyone who can write an upload or shared directory can create one such entry, and it stops a program that cleans that directory. The program lists nothing. Since a Path is a String, it cannot remove the entry by name either, only the whole directory with `removeAll`.
    - Shown by:
      ```
      $ touch uploads/report.txt uploads/notes.txt "uploads/$(printf 'bad\377name')"
      match Fs.list(Path("uploads"), 1000) {
          Right(entries) -> Io.println(Int.toString(List.size(entries)) <> " entries")
        | Left(Io.NotUtf8(name)) -> Io.println("cannot list, for the name " <> Bytes.toHex(name))
        | Left(error) -> Io.println(Io.show(error))
      }
      $ ern run clean.erc
      cannot list, for the name 626164FF6E616D65
      ```
    - Fix: Have `Fs.list` answer the UTF-8 entries with the other names' bytes beside them, and let `remove` take such a name, so that one entry cannot hide the rest.

### H, the shell's guide

#### Defects

1. **The modules table says `Shell` alone reaches the host, but the history file; `Shell.Complete` declares seven foreign functions and lists the source root through `Fs`.**
   - Place: shell/README.md:60
   - Quote: "The processes and the front end's declarations: all that sends, receives, or reaches the host, but the history file."
   - Wrong: `Shell.Complete` declares `names`, `sessionNames`, `sourceRoot`, `sessionTexts`, `slot`, `fields` and `segment` (shell/shell/complete.ern:204-233) and calls `Fs.list` (complete.ern:174). So "the front end's declarations" are not all in `Shell`, and `Shell` is not all that reaches the host. The design note's *Shape* says this correctly ("but the history file and the questions `Shell.Complete` asks of the front end and of `Fs`"). The README drops that clause.
   - Shown by:
     ```
     $ grep -c "foreign fn" shell/shell.ern shell/shell/*.ern
     shell/shell/complete.ern:7
     shell/shell.ern:26
     (every other module: 0)
     $ grep -n "Fs\.list" shell/shell/complete.ern
     174:    match Fs.list(directory, listMs) {
     ```
   - Fix: End the row with "but the history file and the questions `Shell.Complete` asks of the front end and of `Fs`".

2. **"The front end" never says that `Shell.Complete` declares foreign functions, yet it gives `names` as an example, and `names` is not in `shell.ern`.**
   - Place: shell/README.md:78
   - Quote: "The reader's questions, such as `names` and `documentation`, take no `Session`."
   - Wrong: Part 6 (README:14) and this section suggest that every `foreign fn` stands at the foot of `shell.ern`. A reader who looks there for `names` does not find it: it is `Shell.Complete`'s (complete.ern:204), and so are six more that `ern_shell.erl` answers.
   - Shown by:
     ```
     $ grep -n "fn names(" shell/shell.ern shell/shell/*.ern
     shell/shell/complete.ern:204:foreign fn names() : List(Name) with m =
     ```
   - Fix: Add a sentence: `Shell.Complete` declares its own questions of the front end, `names` among them, at shell/shell/complete.ern:204-233.

3. **The README's command for one module's tests fails for `Shell.Region` and `Shell.Style`, because `Ansi` is not on the load path.**
   - Place: shell/README.md:94
   - Quote: "bin/ern test build/shell/shell/editor.erc   # one module's tests"
   - Wrong: The comment offers the line as the way to run any one module's tests. Run the same way, region.erc and style.erc are refused before any test runs. The session test (test/ern_shell_tests.erl:496) passes `--load-path build/libs/markdown --load-path build/libs/ansi` for this reason.
   - Shown by:
     ```
     $ cp -r build/shell bs2      # in the scratch directory
     $ bin/ern test bs2/shell/region.erc; echo $?
     ern test: cannot find module Ansi (ansi.erc) on the load path
     1
     $ bin/ern test bs2/shell/style.erc; echo $?
     ern test: cannot find module Ansi (ansi.erc) on the load path
     1
     $ bin/ern test --load-path build/libs/ansi --load-path build/libs/markdown bs2/shell/style.erc
     ... an empty text takes no colour: passed      (exit 0)
     (command, complete, editor and history pass without the flags)
     ```
   - Fix: Give the load paths in the example, `bin/ern test --load-path build/libs/ansi --load-path build/libs/markdown build/shell/shell/region.erc`, or say which modules need them.

4. **The README says that at a terminal `main` writes the first prompt itself, unlike `prompt`; the code writes it through `prompt`, draining the screen first.**
   - Place: shell/README.md:36
   - Quote: "At a terminal, `main` writes the first `> ` itself, after the startup files. `prompt` writes each later one, after draining the screen. In line mode `lineLoop` writes every prompt through `prompt`, the first among them."
   - Wrong: `main` calls `prompt(screen)` (shell/shell.ern:185), so the first prompt at a terminal is drained and written by `prompt`, as in line mode. The contrast the bullet draws does not exist. The design note's *Start and end*, step 5, agrees with the code.
   - Shown by:
     ```
     $ sed -n 183,186p shell/shell.ern
                 match startup(state, screen) {
                     Continue(state1) -> {
                         prompt(screen);
                         keyLoop(state1, screen)
     ```
   - Fix: "`prompt` writes every prompt, after draining the screen: at a terminal `main` calls it after the startup files, and in line mode `lineLoop` calls it before each line."

5. **The README and five comments in `shell/` cite §9.3 for the modules' `Test` values; §9.3 is "Declared types", and tests are Appendix E.24 and §11.2.**
   - Place: shell/README.md:72
   - Quote: "Each pure module is tested by its `Test` values (§9.3)."
   - Wrong: Report §9.3 declares `Unit`, `Optional`, `Either`, `Ordering`, `Down`, `Reason`, `RestartLimit` and `Path`, and says nothing of tests. `Test.Case` is E.24, and `ern test` is §11.2. The same wrong citation is at shell/shell/editor.ern:7, editor.ern:461, complete.ern:480, region.ern:448 and history.ern:136, and in docs/shell_design.md:9 and :171.
   - Shown by:
     ```
     $ grep -n "^### 9.3" report/language.md
     814:### 9.3 Declared types
     $ grep -n "^### Appendix E.24" report/library.md
     588:### Appendix E.24. `test.ern` (namespace `Test`)
     ```
   - Fix: Cite "Appendix E.24, §11.2" for `Test` values and `ern test` in the README and in each of the comments.

6. **The `ScreenMsg` comment says the reader sends `Said`; it sends only `Noted`. The README points to these comments to learn who sends what.**
   - Place: shell/shell.ern:72
   - Quote: "The shell's own text is `Said`, from the session and the reader, and `Noted` while an input is typed, from the reader"
   - Wrong: README:20 says "The comments on the three mailbox types ... say who sends each message." In the reader's part (shell.ern:953-1232) nothing sends `Said` or calls `say`. The reader's only own text is `Noted`, at lines 1059 and 1110. Only the session sends `Said`.
   - Shown by:
     ```
     $ sed -n 953,1232p shell/shell.ern | grep -c "Said\|say("
     0
     ```
   - Fix: "The shell's own text is `Said`, from the session, and `Noted` while an input is typed, from the reader".

7. **Two regression-test comments cite "findings.md", which this commit does not have. They point nowhere.**
   - Place: shell/shell/editor.ern:471
   - Quote: "a combining mark after a letter left it past the end (findings.md's E6)"
   - Wrong: No findings.md exists anywhere in the tree. history.ern:123 cites "(findings.md's S11)" in the same way. A reader cannot follow either one.
   - Shown by:
     ```
     $ find . -name 'findings*'
     (nothing)
     ```
   - Fix: State the defect in the comment itself and drop the reference to a review's temporary file.

#### Clarity

8. **`showing`'s comment says "the session is told once", but `hint` tells the screen; elsewhere "the session" names the process that holds `State`.**
   - Place: shell/shell.ern:1033
   - Quote: "The screen is told what is being typed, and the session is told once how a multi-line input is run."
   - Wrong: `hint` sends `Noted` to the screen (line 1059), not a `ShellMsg` to the session. The README and this file use "the session" for the process. Here it means the person's session, so a reader goes looking for a message to the session process that does not exist.
   - Shown by: none
   - Fix: "and the person is told once, above the region, how a multi-line input is run."

9. **`Shell.Region`'s header says the screen process holds nothing but the region, but the screen also holds where `:output` sends; the README never mentions it.**
   - Place: shell/shell/region.ern:8
   - Quote: "The screen process in `shell.ern` writes them and holds nothing else"
   - Wrong: `screenLoop(region, destination)` and `plainLoop(destination)` hold `:output`'s path (shell.ern:829-832, 879), and the screen answers `Locate` from it. README:24 says only that the screen writes "the bytes its `Shell.Region.Region` gives back". Neither prepares the reader for the second argument.
   - Shown by: none
   - Fix: In region.ern, "holds nothing else of the drawing"; in README:24, add that the screen also holds where `:output` sends what programs write.

10. **The README puts what a `:` line does in the Commands part, but the `:output` command's `output` and `cannotWrite` stand in the session part.**
    - Place: shell/shell.ern:331
    - Quote: "2. **Commands**: what a `:` line does." (README:10)
    - Wrong: Following `obey`'s `Shell.Command.Output` arm into the Commands part (from line 646) does not find `output`. It is at line 331, between `trouble` and `fromFiles`, under no banner.
    - Shown by: none
    - Fix: Move `output` to the Commands part beside `set`, keeping `cannotWrite` where the screen's `appended` also finds it, or name the exception in README:10.

11. **The README cites *Ordering*, *Queueing* and *The front end's copy* as design-note sections, but they are bold paragraphs inside *Processes* and *The foreign interface*.**
    - Place: shell/README.md:3
    - Quote: "How it is built is the design note, [`docs/shell_design.md`](../docs/shell_design.md), cited by the names of its sections."
    - Wrong: The design note's headings do not include these three names, which README:50, :52 and :78 cite. A reader who scans the headings does not find them.
    - Shown by:
      ```
      $ grep -n "^#" docs/shell_design.md | grep -i "ordering\|queue\|copy"
      (nothing)
      ```
    - Fix: "cited by the names of its sections and paragraphs", or cite "*Processes*, *Ordering*".

12. **The design note's *Line mode* and *Startup files*, to which the README sends the reader, name functions `pending` and `quietly` that the shell does not have.**
    - Place: docs/shell_design.md:42
    - Quote: "`pending` says every waiting one before each prompt."
    - Wrong: The function is `reportPending` (shell.ern:1257), which README:54 names correctly. docs/shell_design.md:167 says "any other goes to `quietly`", and the function is `executeQuietly` (shell.ern:387). A reader who follows README:54's pointer finds names that grep does not.
    - Shown by:
      ```
      $ grep -n "fn pending\|fn quietly\|fn reportPending\|fn executeQuietly" shell/shell.ern
      387:fn executeQuietly(state : State,
      1257:fn reportPending(state : State, screen : Address(ScreenMsg)) : State with ShellMsg =
      ```
    - Fix: Write `reportPending` and `executeQuietly` in the design note.

13. **README:72 says the pure modules are tested by their `Test` values, but the impure `Shell.History` and `Shell.Complete` have them too.**
    - Place: shell/README.md:72
    - Quote: "Each pure module is tested by its `Test` values"
    - Wrong: README:16 says "Each module but `Shell` has its tests at the foot of its file", and `ern test` runs all six. Line 72 suggests that only the four pure ones are tested.
    - Shown by: none
    - Fix: "Each module but `Shell` is tested by its `Test` values (Appendix E.24); of the impure ones, the tests reach the pure parts."

14. **The README's note on names that two modules share leaves out `Resized`, which `shell.ern` uses as `Terminal.Resized` and as a bare `ScreenMsg` constructor on adjacent lines.**
    - Place: shell/README.md:28
    - Quote: "`Typing`, `Clear` and `Leave` are constructors of `Shell.Editor.Edit` and of types in `Shell`"
    - Wrong: shell.ern:988-989 reads `Key(Terminal.Resized(_)) -> send(screen, Resized)`. One is the terminal's event, which carries a size, and the other is the screen's message, which carries none. This is the same kind of reading trap that the note exists to defuse.
    - Shown by: none
    - Fix: Add: "and `Terminal.Resized` is the terminal's event, a bare `Resized` the screen's message".

15. **The README says the Erlang front end serves "what only the compiler knows", but it also answers `write`, `setScreen`, `version`, `startupFiles` and `program`, which are the host's.**
    - Place: shell/README.md:3
    - Quote: "and a front end in Erlang for what only the compiler knows."
    - Wrong: The design note's *The foreign interface* lists those five as "The host's alone". `write` exists because the screen cannot write through `Io` while the sinks are bound to it. A reader who takes the opening sentence at its word is surprised at the foot of `shell.ern`.
    - Shown by: none
    - Fix: "a front end in Erlang for what only the compiler or the host can answer."

16. **A comment in `Shell.Complete` writes "after `:`" for a type annotation's colon, in a program where `:` begins a command.**
    - Place: shell/shell/complete.ern:278
    - Quote: "at any depth: after `:`, `Net` holds no type and is not offered"
    - Wrong: In the shell, a leading `:` is a command, and `argument` handles completion after one. Here the comment means a type position, `TypeName`, and a reader takes it for the command case.
    - Shown by: none
    - Fix: "at any depth: where a type stands, `Net` holds no type and is not offered".

