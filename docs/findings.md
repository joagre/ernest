# The findings of the full review

Found on 2026-10-24 by the full review's twenty readers over commit `1329d1d2`, run as [`full_review.md`](full_review.md) says: P on the most advanced model, every other reader on the one below; the report, the newcomer's path and the code read again only where they changed since `fb2324e8`, the release review before 0.4.0, and every other area whole. A line names its reader's letter and number, several where several readers found one thing, and carries its decision: `fix`, a line nobody would argue about once the finding is read, made in the milestone that works through the list, prose on the most advanced model and code as batches on the one below; `decide`, a rule, a sentence of §0 or E.0, what an error text means or a fix that could go two ways, discussed with the user one at a time with the recommendation the line gives; `dropped`, with the reason; `done`, with the date, once made. Nothing is built until the sorting is read. Each reader's whole list stands below the lines, since a line is too short to fix from. The file goes when every line is done, dropped or planned.

## The lines

**The language and the report's rules** (P, K, C2, N, B)

- B1 `fix`, first of all: a block `let` that binds a lambda whose inner lambda applies an operator to a parameter typed by a later call is generalized over the operator's result type, so `fn strings() : List(String) = { let f = fn(n) = List.map([1], fn(d) = d + n); f(6) }` compiles and puts an `Int` where a `String` should be, faulting inside `String.toUpper`, and the shell's printer dies on it (status 70). A soundness hole in §3.9's generalization: a variable a pending operator (§4.8) still constrains is held by that operator and is not generalized; the soundness paragraph on generalization says so, and the shell survives a fault in its own printer.
- K1 `decide`: a `foreign fn ... receiving M` may deliver anything into the caller's mailbox, and nothing checks it (`sendRaw(me(), 42)` into a `String` mailbox faults inside the library), so the soundness argument's claim 2 rests on a promise §4.7 and §8.4 never state. Recommendation: state the third promise of foreign code in §4.7 and §8.4, that a foreign function receiving `M` delivers values of `M` alone, and add it to soundness §2, by principle 5's cost rule, since a check on every delivery would cost a multiple of the host's send.
- K2 `fix`: §4.5's new sentence admits by its letter `fn f() : Unit = send(self(), 5)` and a `receive` in a spawned lambda, which the checker refuses; the sentence states the condition the checker applies, that the variable stays unfixed and nothing in the body but `self`'s or `monitor`'s result has a type holding it, and the soundness paragraph derives its premise from that condition.
- P1, K21, C2-C2 `decide`: a lambda whose body calls `self` or `monitor` without showing the address is refused where a function that receives nothing is expected, while the same body as a `fn` or a `let`-bound lambda is accepted, and the message says the lambda "receives". Recommendation: §4.5's sentence binds a `fn` and a lambda alike and the checker reads a lambda's variable at the lambda's end as it reads a `fn`'s, by principle 1, a named function and a lambda being one thing (§3.9, §4.6).
- P3, K21, G's passing note on §4.5 `fix`: §0, §6.1 and E.0 shape rule 5 say a function that "gives out its address" involves its mailbox, and §4.5 now types `kill(self())` as receiving nothing; the three say "gives out its address through its type", §6.1's last sentence "calls no `self` whose address its type carries", and §4.5's second paragraph "written only where the body involves its mailbox (§6.1)".
- P2, K13, C2-C4 `decide`: §4.6's lone-effect-variable rule gives `twice(fn(x : Int) = x)` the type `#((Int) -> Int receiving Never, ...)`, says nothing of a leftover process-only variable, which the code makes `Never`, and disagrees with the code on a parameter's function type. Recommendation: one sentence, "an effect variable left in its type that stands in no value position is none", the `Never` sentence going since §6.2 already makes an unfixed `Address(n)` `Never`, "once §6.2 has made it `Never`" restored before the error, and the parameter case stated as the code has it; by principle 1.
- P10 `fix`, with P2: the rule that an effect variable nothing fixes is none is stated three ways in §3.9, §4.5 and §4.6; §3.9 states it once and the other two cite it with their examples.
- P4, K22 `decide`: a `kill` goes through a process of the runtime's own, so a message the killer sends after it may be handled first, which §10 states and §6.9 does not, against Erlang's signal order a reader predicts. Recommendation: §6.9 states the reorder in one sentence beside "asynchronous", by principle 1; the alternative, the host's exit signal with the call's record read by a monitor, is a runtime redesign for a case eight runs never showed.
- P5, K15 `fix`: `main/stack.ern` depends on `main.ern` through §4.2's type-member rule, which §11.1's definition of a dependency does not state, and the compiler reads the parent's source rather than its `.erc`; §11.1 states the dependency and how it is read.
- K6 `decide`: two modules with one function body share a hash, so a spawn written in `Alpha.start` reports `Beta.start:2`, and "first declared" is undefined across modules. Recommendation: §6.9 and Appendix H state that the site is the definition's first declaration in the build's dependency order (§11.1), which is deterministic, since a site is the definition's and a definition is its hash; by principle 1, the surprise named rather than hidden.
- K14 `decide`: a peer refuses a reach that names a ground binding (§11.1) with `NotLoaded`, "the binding Main.limit has no value here", though the code holds its value. Recommendation: a ground binding has its value wherever its code is, so the reach check passes it, stated in §8.7 and §11.1; by principle 1.
- P8 `decide`: after a faulting reload `let a = 2` keeps a value and `let b = 2 * 1` does not, the ground term's one visible effect. Recommendation: the ground term becomes the language's, §4.6 saying a binding whose initializer is a literal needs no evaluation and always has its value, and §8.5 and §11.2 following, since a reader should not read the toolchain for a semantic distinction (principle 3); the alternative, every changed binding without a value, has no getter to fault for a ground one.
- P7 `decide`: the host's atom `ok` is `Unit` at a return's top and nowhere else, a second host spelling the ABI table does not show. Recommendation: keep the rule, which buys helper-less shims over the host's commonest answer, and put the line in §8.4's ABI table, `Unit` as `'Unit'`, or `ok` at a return's top; by principle 1, the two spellings standing where the reader looks.
- P9 `fix`: the toolchain's libraries stand on every load path yet their namespaces are neither taken nor said to be hidden by a program's module of the name, which hides them; §4.2 gains the sentence, and Appendix G's "Informative" is qualified, its list being what §11.1 and §11.2 put on the load path.
- K23 `decide`: `Code.running` gives `Address(Never)` for a function that receives nothing and refuses a process-only one, though both run in a process whose mailbox type they do not know. Recommendation: `Never` for both, in §3.11 and E.28, by principle 1.
- P11 `decide`: `Address.call` and `Address.callForever` are the prelude's two qualified functions, which takes the namespace `Address` and needs a shell sentence of its own. Recommendation: keep them, since `call` alone says less than `Address.call` to a reader who knows the rest and `call` is a word a program wants for its own; the shell's clause stays. Weighed on principle 1 against principle 5's count.
- P-L4 `decide`: Appendix D, the worked foreign library, is `libs/ets` written out, which G.1 lists again. Recommendation: G.1 names Appendix D as the listing and drops its own documentation, so that each rule stands once.
- P-L6 `dropped`: `Code.running(f)` requiring `f`'s result type to be `Unit` is the language's shape of a function a process runs, `spawn` taking `() -> Unit` (§6.2), not a relic.
- K7, E11, E12, E25 `decide`: `Test.faults` waits for `run`'s end without a limit against E.0 shape rule 8, takes its callback first against rule 1, names its mailbox variable `n`, hides the unlimited wait behind its name, and reuses the word of `Process.faults`, which subscribes, for an assertion. Recommendation: keep the name, which reads as a verb, "the run faults with the cause"; E.24 states that the call is the subject, so the callback comes first, that the wait is for the caller's own work, as a direct call's is, and names the parameter; `receiving m`; the page says it waits however long. By principle 1 against a second word.
- E10 `fix`: `List.mapFold` answers `#(acc, list)` where F# and Erlang answer the list first; E.2 states the departure, the accumulator first as `foldLeft`'s step has it (E.0 shape rule 10 as G3 corrects it).
- P7's neighbor G's §8.6 note `decide`: §8.6 says whether a user-provided foreign process counts as a system process "is the runtime's choice", an unstated semantic choice. Recommendation: state it, a foreign process the runtime did not start counting as a source while a monitor of it stands, as the reaper has it.
- N21 `decide`: a process restarted in place keeps its `Process` and address and no monitor is told, so a lock, a fork or a lease held for it is never freed, and the newcomer's dinner deadlocked until the protocol carried knowledge of restarts. Recommendation: a monitor is told of a restart with a reason `Restarted`, the monitor standing, one constructor added to `Reason`; by principle 3, nothing invisible, since the restart is invisible to exactly the processes that need to see it. The log's entry on restarts in place is read first.
- N22 `decide`: a `Reply` names no caller, so a server that must watch its caller needs the caller to put its own `Process` in the request, which nothing checks. Recommendation: keep, a request carrying `Process.current()` where a protocol needs it, and the line goes to `language_feedback.md`; by principle 5.
- N23 `decide`: a monitor cannot be taken back, so a server that monitors each caller piles up monitors. Recommendation: keep for now and record in `language_feedback.md`; a `demonitor` is weighed when a second program asks, by principle 5.
- N24, N3, B-H2 `decide` and `fix`: a function that only pauses must carry `receiving e`, and so must every caller, since a timed receive reads the mailbox (§3.9), which the newcomer found against principle 1; the guide never shows the annotation and the compiler's help names no type. Recommendation: the rule stands, the one silence; the guide's §3.5 shows `fn pause(ms : Int) : Unit receiving e = ...` and the help says `receiving Never` for an entry point and `receiving e` for a helper (`fix`); the feeling goes to `language_feedback.md`.
- N25 `decide`: tuples, lists and `Optional` have no order, so a record with an optional field cannot derive `compare`. Recommendation: `Optional`, `Either` and `Ordering` derive `compare` in §9.3, and a tuple and a list have a `compare` where every component has one, stated in §3.10 and §9; by principle 1, what OCaml and Erlang give a reader expects. A design question for the user.
- N26 `decide`: `Address.call` answers `None` for a time run out and for a callee ended alike. Recommendation: keep, §6.6's rule that `None` says nothing, recorded in `language_feedback.md`.
- E22, E23, E24 `decide`: waiting for one process's end from a function that receives nothing costs a process and a call; a library cannot mark the processes whose faults it expects, so `Test.faults`'s are known by their site's text in Erlang and in Ernest alike (C5-C19, S5, E13); a spawn needs a wrapper to drop a result. Recommendation: the runtime marks a process whose faults are expected in its row, asked for by a primitive `Test.faults` uses, so that no text is matched (principle 3); the other two go to `language_feedback.md`.
- U-L1, U-L2 `decide`: `Process.status` answers `None` for an ended process and for another node's alike, and a held service cannot be ended from the `Process` its holder gives, since `kill` takes an address. Recommendation: both to `language_feedback.md`, E.21 stating the two `None`s.
- L's close, M9 `decide`: supervision and in-place upgrade exclude each other (deployment §5.3), and the gain of the mailbox in the type over a typed handle is asserted and never shown. Recommendation: the first to `language_feedback.md`; for the second, `why.md` shows the refused program a handle cannot refuse, `fn main() : Unit receiving OtherMsg = count(0)`, a receiving function called in a process of another type (`fix`).

**The report's prose** (P, K, G)

- P6, K4, K5, G1, G2 `fix`: the sweep of the notes and the gateway left dangling text: Appendix F's **frame** lists fourteen frames with "a call's two notes" and no `kill`, §8.7's **What passes** and **A loss** still name the notes, E.27 opens on "the node's gateway", one §8.7 sentence no longer parses, and **subscription** lacks the end's; each is rewritten to what §8.7 now states.
- K3, K24, D4 `fix`: `soundness.md` dates itself 21 October, its §6.1 states the rule §4.6 replaced, its §5 says every address is made in three ways though `Code.running` makes one, and it keeps history ("when the mark on sending went", "MVP 3.0"); rewritten to the report as it stands, the date moving with each rule.
- K8 `fix`: §11.8 says `ern test` exits 0 for a module with no tests, though a failing doc example exits 1; "unless every case passed, and 0 for a module with neither tests nor examples".
- K9, P-L8 `fix`: Appendix H lists `{var, Reference, Supplies, Held}` and never defines `Held`, and states no order for a derived `compare`'s requirement though the order is hashed; both stated as the code has them.
- K10 `fix`: §10's new bullet on a call's wait contradicts the bullet that nothing grows with other work; the general bullet names the exception.
- K11 `fix`: §11.1's link sentence leaves out the libraries' builds, and its lambda sentence leaves out `Peer.compute` and `Peer.computeAt`.
- K12, P12, C4-C2 `fix`: E.21's trace rules contradict one another, twelve innermost frames cannot end with the outermost, runtime frames are "left out wherever they stand" and then kept for a failure, a run of identical frames collapses unstated, and a unit's own helper frames print in host form; E.21 states the cap, the end, the collapse and a runtime frame's form, and the runtime leaves a unit's helper frames out.
- K16 `fix`: §11.2 does not say a doc example with `// =>` runs at `Never`; one sentence.
- K17, C5-C16 `fix`: §8.7's "the latest `ms` ... from its ask" is ambiguous and the code counts each frame's `ms` from its coming; §8.7 and the time-out text say what the code does.
- K18, T3, T13, T16 `decide`: `ern config --peer-dir` without `--config-dir` silently writes `./.ernest/ernest.conf`, `ern config` creates missing parents, `.ernest` names the shell's directory and the node's default alike, and §11.2 does not say what a `--libs-dir` directory named `foo-1.0-rc1` is. Recommendation: `ern config` requires `--config-dir` as `reload` and `stop` do, the default `./.ernest` going with the three guards the report keeps for it, and a missing parent is refused; the `--libs-dir` rule stated; by principles 2 and 1.
- K19 `fix`: §6.5's new sentence reads as the arrival case alone; it states the three cases outright, the sender's, the target's and the kept process's, `Process.current` in `f` with them, and the soundness paragraph names the kept process.
- K20 `fix`: §3.9's "a function that receives never stands where ..." reads as `receiving Never`; "stands nowhere one that receives nothing is expected".
- K25, E1, E26, U-V4, D6 `fix`: relics of the libraries named with `--load-path`: G.3's "and so needs it on the load path", E.0 shape rule 6's example, Appendix D's root beside G.1's namespace, every library page's load-path paragraph and `markdown.ern`'s sentence on `ansi`, the plan's MVP 4.1 sentence and the guide's "with no flag" reassurances; each goes.
- K26 `fix`: Appendix F's **trace** gloss is wrong for a host frame, and §11.5's "report's signature" is a typo.
- P13 `fix`: §8.7 states what a peer does with a telling the same sentence says never comes; the second half goes.
- P14 `fix`: Appendix F's **load path** covers two kinds of root under one word since `--libs-dir`; the gloss names both.
- P-L2, P-L3, P-L7 `fix`: Appendix A's `Member` production lists `show`, which §4.9 says is no member, so the production is named for what it holds; §9.4's heading "Built-in functions (§6)" holds `Io.show` and `Io.debug`; §6.2 says in one line that `spawnMonitored` closes the race a `monitor` after the start would leave.
- G3 `fix`: E.0 shape rule 10 "departs only where its section states the reason" obliges the report to argue; "states the departure".
- G4 to G8, G10 to G35 `fix`, the register batch on the most advanced model, one section at a sitting for the larger ones (G9's E.27, G10's §7.4, G13's limits, G17's crossing, G32's since-clauses, G33's so-that clauses): arguments, purpose clauses, restatements and teaching sentences, each with the sentence G gives.
- G9 `fix`: E.27 restates §8.7 paragraph by paragraph; it opens by naming the functions that act as §8.7 states and keeps what §8.7 lacks.
- G36 to G41 `fix`: Appendix H's "above", `Code.running`'s typing rule in §3.11, §8.7's two obscure sentences and misplaced sentence, and E.0 rule 1 binding the library to the log.
- G's passing notes `fix`: §4.8's last paragraph, §4.7's third, §6.10's how-to, E.19's history note, E.24's and G.1's since-clauses, Appendix E's opening and §9's.

**The guide, the tour, the README and the FAQ** (U, L, M, N, B)

- L1, N1, M1 `fix`: `faq.md` says there is no selective receive, which §4.3 of the guide teaches and the toolchain does; the clause goes, the answer saying a `receive` takes the first message a clause matches.
- L8, N2, M5, D2, U5 `fix`: the README, the guide's §0 and §12 and `guide/README.md` count the claims with a program three ways; `why.md`'s wording stands in each, and `language.md` drops the count.
- L2, M3 `fix`: the tour's chapter 4 works only when the second bad amount comes within five seconds of the first; `within` becomes a length a reader meets, and the sentence says so, the tour's test holding the program.
- L3, U1, M25, B-C2 `fix`: `why.md` says the deadlock is found in the shell, which §11.2 denies, and the README, the guide's §5.4, the FAQ and the deployment guide never say a node detects none; each says it once.
- M2 `fix`: the tour's chapter 8 says an orderly `ern stop` gives `Unreachable`; it gives `ProgramEnd`, as the deployment guide says in three places.
- M4 `fix`: the guide's §1.5 opens on §0's counter, a refused program whose names are not exported; it names the tour's `counter.ern`, and stands before §1.4's exercise.
- L4 `fix`: a `Down` may overtake the dead process's last message, which the guide's §10 never lists under what differs from Erlang; a bullet citing §5.2.
- L5 `fix`: deployment §6 says looking "changes nothing on the node" where each lambda sent is kept (§4.2).
- L6, L7, N4, U15 `fix`: `why.md` understates what `ms` bounds, gives two costs for one foreign call, says "pays nanoseconds" of nothing, uses "the look" undefined and restates the runtime note's costs in Erlang's words; one sentence each, citing the note.
- L9, N19, M6, M7, M8, U7 `fix`: cross-references to the wrong section: §8.3 for a loss (§8.2), §6.6 for tests (§7.1), §6.4 for ownership (§8.7), §5.3 for `Process.status` (§5.2), report §8.2 for an adapted address's node (§8.7), §9.3 for a socket given to an input (report §11.2), `Bytes` and field selection swapped in §1.3, and the FAQ's §11 for one rule counted three times.
- L10, M17 `fix`: the tour's "another machine" is another node.
- L11, M13 `fix`: the tour rests two message orders on per-sender order where the senders are two inputs; the sentences name the rule that orders them, the first input having ended before the second began.
- L12 `fix`: no document says what a running server does when its state's type changes; one paragraph in the guide's §8.9, a new process and the clients moved, as §8.2 says of a stored state.
- L13 `fix`: no section says how a fleet moves to a new `ern` or OTP major; a paragraph in deployment §5 states the rule as it stands, two floors never connect, so a fleet moves whole or as a second fleet beside the first.
- L14 `fix`, with N21: the guide never says how a client learns a `restarting` service lost its state; one sentence, as N21 decides it.
- L15 `fix`: a FAQ line on what stands for `global` and `pg`: a find names one holder per node, and a group across nodes is a program's own.
- L16 `fix`: two WAN questions answered in the deployment guide as §8.7 has them: whether a `send` to a lost peer waits for the dial, and that the silence window is the host's and not tuned.
- L17 to L26, L28 to L31 `fix`: the clarity lines of the Erlang programmer, each with its sentence: §10 against §13(c), the garden-path §4.6 sentence (N12, M11, M19), "distribution" in two senses (M23), `placed.ern`'s fallback, "constant" for a top-level binding, `why.md`'s deadlock trace line, the run-on sentences, the exit statuses as a list, §5.2's one-line fix, "any program on the floor", the tour's "holds none of its code", "one with room" for the pick, `Code.running` as a form, and the FAQ's supervisor answer missing the sibling rule.
- L27, M20, U16 `fix`: deployment §8 lists three nodes by editing four files after §2.1 taught `--listen` and `--peer-dir`; it uses them and edits what they cannot write.
- M10 `fix`: the closed set of a requirement's members stands in the guide's §7.3 alone; one sentence in `why.md` and the FAQ.
- M11 `fix`: glosses added since 0.4.0 sit mid-clause in eight sentences that no longer parse; each gloss a sentence of its own.
- M12 `fix`: nothing near §7.2's `Stack` says a module value does not reach a bare node; one sentence pointing at §8.1.
- M14, M15, M16, M18, M21, M22, M26, M27 `fix`: "no registry" against offer and find, "checked" for a reply, "the shell's process ends", a caption without a verb, a missing word and a run-on in deployment §1.2, "which says" on the wrong noun, reader-facing pages citing the log and the plan (U14), `countTwice` undefined in `why.md`.
- M28 `decide`: §4.4 at 180 lines, §8.1 at 225, §8.2's 75-line store, `why.md`'s hash section and the tour's sieve are too long for what they show. Recommendation: leave them, each sentence teaching a rule the guide needs, and cut the tour's sieve to a short compute; the user reads.
- N5, B-C1, T1, L22 `decide`: a deadlock's report shows the entry process's trace alone, at the last call before the wait, so a developer finds the cycle only by knowing the program. Recommendation: the deadlock's fault lists each waiting process by its site and the function it waits in (§8.6), a plan item, by principles 1 and 3, costing nothing while the program works; and E.21 and the guide state now that a waiting frame names the last call before the wait, since the host's stack has no frame for a receive.
- N6 `fix`: literal patterns are used and never taught; a sentence and an example in §2.6.
- N7 `decide`: §2 and §3 use `self`, `monitor`, `Address` and `Never` before processes exist. Recommendation: the process half of §3.4 and §3.5 moves to §4.1, one sentence pointing ahead; by principle 1 for the newcomer.
- N8, M24 `fix`: §4.1's "a process that receives nothing" cannot be rebuilt from the text; an example for each case.
- N9, U-V2 `fix`: §4.4's pacing lambda carries an annotation it does not need; dropped.
- N10 `fix`: how `receiving` binds when a result is a function; one sentence with the parenthesized form.
- N11, N13, N14, N15, N20 `fix`: "applied in writing", a doc example never shown, `OrderedSet.Set` unexplained, §4.1's example not matching its sentence, §6.4's unbounded inner wait with `site = _`, and §5.3's `kill(addr)`.
- N16 `decide`: a definition that uses a failed one draws a second error, "the type a is not known whole here", that only follows from the first. Recommendation: the checker reports nothing of a use whose type is unknown because its definition failed, by principle 1.
- N17 `decide`: the README shows no line of Ernest before six claims full of unexplained terms. Recommendation: `why.md`'s twenty-line counter and its refusal go into the README, by principle 1 for the newcomer.
- N18 `fix`: two claims open on another system; each opens on what Ernest does.
- U2 `fix`: the guide's §9.3 says a find gives the old service's address after a reload, which a node cannot find of itself; "which a binding made before the reload holds".
- U3 `fix`: deployment §6 reads `Process.status` of another node's process, which answers `None`; the status is asked on the peer with `Peer.computeAt`.
- U4 `fix`: deployment §7's table of what a node says lacks the unreadable-frame line, the exchange's time-out line, the compute form of "not loaded", the end's lines and the family refusal; the rows, or a sentence that the table selects and §8.7 and §11.2 are the whole.
- U6 `fix`: the guide's §14 says the snake has one process per player; it points at `examples/README.md` instead of restating.
- U8, U9 `fix`: `guide/style.md` says `ern format` takes no option and lists six of the eight shape rules it names.
- U10, U11, U12, U13 `fix`: `why.md` calls a socket a system process and says every module's bindings are evaluated; the guide's §4.5 says a hangup ends a program and §8.4 says every remote address came from a find or a spawn (and report §3.11 the same; K's area).
- U14, M26 `fix`: the installed FAQ and deployment guide cite the plan's MVP 4.0 and "yet"; they say what the shell does today.
- U17, U18 `fix`: §8.2 says the store and the desk hold the library the board needs; deployment §6 loads the program's module at the operator's shell without saying a load runs its bindings.
- U-C1 to U-C14 `fix`: "the principles the guide ends with (§11)", "five documents for three readers", the names the glossary refuses in guide blocks (`m`, `t`, `p`, `n`, `Left(failure)` beside `Left(error)`, events not in the past tense), `guide/style.md`'s own unstated exceptions, two programs named `jobs.erc` and two modules `Store`, deployment §1.2's partial refusal list and its Appendix F citation, the undated measured numbers, the quotation of a file an installation lacks, the reload transcript's input count, the garbled §8 sentence, "though not receive", `ern stop` for a program that is no node, "since October 2025", and "give it a moment, about a second" where the node gives no signal.
- U-V1, U-V5, U-V6 `fix`: §12's one-line pointer, §1.4's exercise whose answer is that nothing differs, and §0's "the principles the guide ends with".
- H1 to H12 `fix`: `src/shell/README.md` against the code: `Noted`'s senders, where `Shell.Complete`'s declarations stand, where `output` and `cannotWrite` stand, the source root, which modules use which, every caller of `prompt`, the recurring names, `readKeys` and `Start`, what the screen writes, `kept` as the limit, the `Address(Never)` citations, and the `Shell` row.
- H-P1 `decide`: `C-d` on an empty line while an input runs kills the run at once, against `await`'s comment that the end of input waits. Recommendation: the code stands and the comment follows it, `C-d` ending the shell as `:quit` would, under §11.2.
- H-P2 `fix`: a typo in `editor.ern`.

**The documents** (D, E, C, K)

- D1, D28 `fix`: `full_review.md` counts twelve and nineteen readers and lists fifteen in twenty-two parts, and D's list leaves out three files; the counts and the list follow the document, and `tour/README.md` is D's.
- D3 `fix`: `development.md` says a test holds `why.md`'s list equal to the README's, and none does; the test is written, since the lists have drifted (D2).
- D5 `done` 2026-10-24: the plan and the log dated the race fix 2026-10-25; the commit is 2026-10-24, and both say so.
- D7, D8 `fix`: the plan calls MVP 4.4 the first milestone after 0.5.0 and conditions it on a promise MVP 3.9 no longer makes, and MVP 4.0 says nothing of it goes into 0.4.0, which shipped.
- D9, D's leftover 2 `fix`: MVP 3.9's done items keep whole paragraphs, the nodes' note citing files the sweep removed; each done item becomes its one line, the paragraphs going as CLAUDE.md's sweep rule says.
- D10, D11, C4-C16 `fix`: the runtime's design note lists the persistent terms incompletely and calls them one word each, omits the `ending` row and the `#launch{}` fields `stderr` and `node`, says `ern_restarts` is read by a restart where a supervisor reads it, lacks the start cause among the dictionary's keys, and `architecture.md` omits the table's main row; each follows the code.
- D12, D13, D14, C2-C6 `fix`: `architecture.md`'s golden fixtures sentence, four drifted arities in `architecture.md` and `docs/style.md`, and "three modules" of `erl/shared`.
- D15 `fix`: `development.md` says `make test-full` runs the areas one after another; it describes the two phases.
- D16 `decide`: `development.md` and the Makefile say `make bench` whole runs before a commit that closes a plan item, which CLAUDE.md's *Tests* never took up. Recommendation: the sentence goes from both; `make bench` runs before a release and when a change touches a measured path, as the release review says.
- D17, E15, C6-C12 `fix`: the release archive's README omits the tour and still says of the guide "start there"; it gives the three ways in as the repository's README does.
- D18, D19, D20, D21 `fix`: "the two READMEs beside the code" where five stand, `development.md`'s layout missing four test modules and `tools/paragraphs.sh`, the underscore rule's second exception for the logos, and `assets/README.md`'s uses of the logo that do not exist yet.
- D22 `fix`: `principles_review.md` and `memory.md` keep a `later` decision CLAUDE.md's "nothing is kept for later" removed; "an item of a milestone, or `dropped`", and the log entry cited by its title.
- D23 `decide`: the site proposal is stale in three places, MVP 3.3 "writes" the tour and a list of four held by a test that does not exist. Recommendation: the three lines change at the proposal's next sitting with the user, dated as `decisions.md` says.
- D24 `dropped`: `ernest_host/ponderings.md` is a dated record, headed "Counted on 2026-10-12".
- D25, D26, D27, D33, D34, D35 `fix`: a link text with the file's old name, two plan lines citing documents that are gone without "as it stood at", three descriptions of the diagnostics catalog, MVP 3.9's "Done" cell holding prose, "every kind below" where the last subsection is outside, and `libs/markdown` recorded twice.
- D29 `fix`: CLAUDE.md's owner table has no row for `examples/README.md`.
- D30 `decide`: `docs/style.md`'s toolchain glossary restates mechanism and reasons the design notes and the log own, and the restatements have drifted (D11). Recommendation: each entry keeps the name, what it names and where the code holds it, and points at the note for the mechanism; a batch on the most advanced model.
- D31 `fix`: the runtime's design note gives two reasons, against CLAUDE.md's "states no why"; the reasons move to the log.
- D32 `fix`: the plan says `ernest_host/` goes as its milestone closes, and it has none; the sentence says the user ends it.
- D's leftovers 1, 3, 8, 11 `fix`: history inside `full_review.md`'s procedure, MVP 4.3's "since 2026-10-13" moved line, `principles_review.md`'s MVP 3.0 reminder, and `emacs_mode.md`'s "roadmap entry".
- D's table `fix`: the lists that live in two places without a test gain one where cheap, the six claims (D3), the review's readers, the runtime's tables with their rows, the shell's modules, the bench's parts (C6-C20) and the memory loads; the rest are named in `development.md` as kept equal by hand.
- E1 `fix`: with K25 above, the six library pages.
- E3, E4, E6, E7, E8, E16, E18 `fix`: the Peer pages' timing rule said badly or not at all, `Code.running`'s page lacking the `Never` case, a `FaultReport`'s trace empty for a host-ended process unstated in E.21 and the page, `Code.load`'s two missing answers, `Utilization.runQueue`'s missing contrast, "the host's stack" for the trace, and the `Test` page's "What it prints".
- E5 `fix`: for a peer a reload removed, `FaultReport.spawnedBy` is `None` in the runtime and the page where E.21 says the node's name, and the shell's line differs from `ern run`'s; E.21 states `None` for a peer no longer listed, §11.2 that the shell's line then omits it, and the shell's wording follows `ern run`'s.
- E9 `decide`: `:faults` now lists up to a hundred faults each with its trace, which §11.2 does not say. Recommendation: `:faults` lists the lines without traces, stated in §11.2; by principle 1, a listing being a listing.
- E14, E17, E19, E20, E21, E27, E28 `fix`: `examples/README.md`'s drifting counts and overclaim, the shell's "one line" comment, the shell README's third glossary (the two names move to `docs/style.md`), a doc block citing a whole file, `tools/paragraphs.sh`'s skip after an item, `"cubes"` for `"squares"`, and a `FaultReport` example with an empty trace.
- H's and C's doc lines: with their areas.

**The toolchain's code** (C1 to C6, S)

- S1 `fix`, first among the code: `ern test` makes each doc example's working directory in the shared temp directory with the umask's mode, so under umask 000, or 002 with a shared primary group, another local user plants a link where an example writes, shown with a planted `note.txt`; the directory is made as `ern_node:create/2` makes the configuration directory, mode 0700 and checked empty, before `set_cwd`.
- S2, C5-C4 `fix`: a relative `--config-dir` is resolved against the working directory each doc example sets, so a reload during an example is refused; the directory is made absolute once at the node's start.
- S3 `decide`: group write is trusted on the configuration directory, `ernest.conf` and `certificate.pem`, and `--peer-dir` lists whichever key a group-writable certificate certifies, shown by swapping one. Recommendation: refuse group write on all three as OpenSSH's StrictModes does, and write the two files 0644 at create, stated in §11.3; by principle 1 against the report's trust in the user's group.
- S4 `fix`: a peer's site text goes raw into the node's lines and the shell's, and a name with `\n` forges trace lines; written through `ern_show:controls` and escaped before joining.
- S6 `fix`: a compute's answer from a peer, `{Alias, faulted, Cause, Trace}`, is not checked as two UTF-8 binaries, and a bad one kills the reaper; taken only when both are, else `Left(Other(...))`.
- S7, C4-C19 `fix`: a peer's kill frame reaches any pid of this node, the reaper among them; acted on only for a pid with a row in `ern_processes`.
- C1-C1 `fix`: `:doc` of a type's member looks in the beam of a module that does not exist and shows no parameter names.
- C1-C2, C4-C9, T35 `decide`: a host function is written `erlang:div/2` in a cause and `erlang:'div'/2` in a trace, and §8.4 and E.21 write it both ways too. Recommendation: the host's own form, quoted where the host quotes, everywhere, aligning §8.4's example, since "as the host names it" is what both say.
- C1-C3, C6-C5, C2-C7, C3-C3, C6-C4, C1-C17 `fix`: test comments cite `docs/findings.md`, `docs/proposals/tour/outline.md`, "the proposal's section N", bare finding ids, plan items and a function that does not exist; each cites the log entry or the report, and the documents test's path check extends to the comments of the toolchain's sources.
- C1-C4 `fix`: no test shows that ending a subscription ends a call its wrap makes; written.
- C1-C5 `fix`: a pattern's second positional field gets no help where the declaration's does; a help in pattern terms, and §11.5 says so.
- C1-C6, C1-C7, C1-C8, C3-C4, C3-C5, C3-C6, C3-C7, C4-C7, C4-C8, C5-C10, C5-C11, C5-C12, C5-C18, C4-R1, C5-C9 `fix`: comments that no longer hold: a function called a member, the `in_foreign` wrapper's paragraphs and the `-waits` lists' paragraphs that outlived them, a count where a key is set, `ern_descriptor`'s header, `code/4`'s rows, `run_main/3`'s outcomes, four stale citations, a hanging comment, `parse_module/3`, the host's split, a measured ratio in a comment.
- C1-C9, C1-C10, C1-C11, C1-C12, C1-C13, C1-C14, C1-C15, C1-C16 `fix`: `ern_namespace`'s swapped names and wide spec, `module_doc/2`'s second lookup, the prelude listing's repeated line, `fault_cause/3`'s unstated invariant, an unparseable test comment, the parser's indirect messages, the module doc's job.
- C2-C1 `fix`: whether a recursive group checks depends on `digraph`'s member order, which changes from run to run, since a `: T` member checked first binds another member's effect to none; components ordered by declaration, `: T` members checked after the others.
- C2-C3 `fix`: two definitions with one scheme and one printed type hash differently when one carries an annotation, since the form writes an elided effect variable as a variable; the form writes it as none, and the test that claims otherwise holds a case that shows it.
- C2-C5, C2-C8, C2-C9, C2-C10, C2-C11, C2-C12, C2-C13, C2-C14, C2-C15, C2-C16 `fix`: `added_interface/2`'s reaches, an export with no outside caller, `bound_to/3`'s impossible branch and name, three names that do not say the work, a stale banner, literal newlines in a test, the `: T` switch living in a diagnostics record, a guard help that cannot apply, layout, and two `scheme_arity` functions.
- C2's leftovers `fix`: `value_position` kept in the restriction list becomes a field of its own on `#type_variable{}`, and the per-definition state copied field by field becomes one `#scope{}` record.
- C3-C1 `fix`: a foreign fn declared in a startup file gets its line unshifted in a trace.
- C3-C2, B6 `fix`: a unit made from forms, the shell's second unit of a name, `Code.load`'s and an arrival's, gives a foreign function's frame no line, and a compute on a peer shows `Int./:52` for the program's own operator frame; the recorded foreign declarations and the code frame carry the source, with the protocol's version, and the arrival keeps the program's frames.
- C3-C8, C6-C10, C1-C17's waits `fix`: tests that wait on chosen numbers, `after 5000` where `after 0` serves, limits of 60 and 90 where the suite counts steps, and `after 2000` twice in the terminal's tests.
- C3's observation `decide`: a program's function called back from foreign code runs under the FOREIGN mark, so a `receive` in it with nothing in flight never faults `deadlock`. Recommendation: as §8.6 states it, the callback being inside foreign code; recorded, no change.
- C3-C9 to C3-C19, C3-R1 to C3-R5 `fix`: the emitter's walk written twice, the interface rebuilt, `literal_value/2`, `calls/3`'s parameter, the sites row found by a trick, a field read under two spellings, names that mean two things (`raised`, `Named`, `Linked`, `Unit`), `--emit-erl`'s causes as bytes, mid-sentence wraps, the `#linked` comment, the module header's missing export, `ern_descriptor`'s unread causes, `session_offset` as a number, the context's duplicated fields.
- C4-C1 `fix`: a fault in an adapted address's function sends a message to a foreign target where §6.5 says an exit signal; a target without a row is ended with `exit(Pid, Fault)`.
- C4-C3 `decide`: a caller the host ends while it waits leaves its callee row and, for a compute, the peer is no longer told, since `delivered_down/3` stopped running `uncalled`. Recommendation: the reaper drops a host-ended process's call as it did at fb2324e8 and tells the peer, since §8.7 promises it and the reaper sees every end anyway.
- C4-C4 `fix`: a toolchain line sent between the flush and the stop of standard error's process is lost; `say/2` becomes a call under a monitor with the outside device as fallback.
- C4-C5 `fix`: a monitor asked by an old run's delivery after the reaper's `new_run` stands into the new run; the asking process is kept beside the monitor and canceled with its delivery.
- C4-C6, C4-C10, C4-C11, C4-C12, C4-C13, C4-C14, C4-C15, C4-C17, C4-R2 to C4-R5 `fix`: `killed/2`'s spec, near-names (`site_name`/`sites_name`, `monitor_made`/`monitor_kept`/`monitors_kept`, `gateway_answer`/`gateway_answered`), the foreign bracket written seven times, `kill_all/1` through the prelude's `kill`, `initializer_name/3`, a test re-implementing EUnit's output, comments citing plan items, two `-receives` entries justified wrongly, the peer waits' brackets that guard a look a node never runs (a kind for "a wait only a node makes"), every `restarting` writing a row only a supervisor reads, `said/1` beside `say/2`, and `'$ern_start'` as a literal.
- C4-C18 `fix`: the trace of a fault a system process asks for is the entry process's stack as found; E.21 says so.
- C4's observation `fix`: the look's cost at many processes, one `process_info` ask each until the `TIMED` holder is found, is stated in the runtime's design note.
- C5-C1 `fix`: `ern test` finds doc examples by a regular expression that is not CommonMark, so `~~~ernest` and an indented fence are skipped or split wrongly, and three fence readers disagree; one CommonMark fence reader shared by the parser, the formatter and the examples.
- C5-C2 `fix`: `Code.load` marks the evaluation of the bindings as foreign code, so a deadlock in a loaded binding hangs a program forever; the mark covers the reading and placing alone.
- C5-C3 `fix`: a misplaced `.erc` under a node's load path still gets the "missing at its own path" message; each component is checked for shape first.
- C5-C5, C5-C6 `fix`: `+0.4.0` and `00.4.0` are taken as releases; the client-side dial check crashes inside `ssl` where it finds no dialing process, and rests on an undocumented `ssl` monitor, which the comment names with the OTP release.
- C5-C7, C5-C8, C5-C13, C5-C14, C5-C15, C5-C17, C5-C20, C5-C21, C5-C23, C5-C24, C5-C25 `fix`: `Owner` and `Module` for other things, two names for the type-members function, the clash message naming a path that may not exist, the gateway's `Telling` holding three kinds and its timer message, the default `listen` written twice, the unstated rule for where an example's declarations end (stated in §11.2), the carrier parsing a version text the toolchain built, **Dialed** in the glossary, a shape loop that cannot fail standing where C5-C3's check is missing, two delegates to `ern_namespace`, and two shapes of each fault outcome.
- C5-C22 `decide`: the code frame carries `References` the arrival recomputes and never uses. Recommendation: drop it from §8.7 and the frame at the next protocol version bump, with C3-C2's.
- C6-C1, C6-C6 `fix`: `ern_last_run` says "No row moved" when every row changed shape and matched nothing, and labels the release's number "last".
- C6-C2 `fix`: nothing depends on the `libs` target, so a removed library's build stays on every load path; `all` depends on it.
- C6-C3 `decide`: `ern_spawn_costs`'s model of the reaper writes rows and tables the runtime no longer has. Recommendation: drop the model's rows, since a model that drifts measures nothing, keeping the whole-runtime rows.
- C6-C7 `fix`: the libraries' tests run twice in `make test-full`; `libs_test_` keeps what it alone asserts.
- C6-C8 `decide`: about sixty nodes tests state a bare `{waits, N}` nothing checks, and the machine tests' waits have no bound. Recommendation: the harness counts a test's steps and fails past its count, and `ern_machine`'s waits take `wait_ms()`; a harness item.
- C6-C9, C6-C31 `fix`: tests still name the libraries with `--load-path`.
- C6-C11, C6-C13, C6-C14, C6-C15, C6-C16, C6-C17, C6-C21, C6-C22, C6-C23, C6-C24, C6-C27, C6-C28, C6-C29, C6-C33, C6-C34, C6-C36 `fix`: a store left running, a bench row described that is gone, stale Makefile comments and counts, style test patterns missing the fixtures, wrong ordinals and arities, comments mangled by a citation replacement, the host command repeated, the node jobs listed twice, names against the glossary, a leftover of the `in_foreign` wrapper, hard-coded copies of owned values, two computations of the files beside a refused program, an ambiguous comment and a reused glossary name, a gone document exempted, a `nodes_test` clause with no caller.
- C6-C18, C6-C19, C6-C20 `fix`: `median_range/1` four times with two medians, `looped/1` three times, the nodes harness's helpers copied across three test modules, and the bench parts listed in three places; one bench harness module and one nodes harness.
- C6-C25 `fix`: the test harness's exports have no specs; `docs/style.md`'s rule holds for `test/` too, and the specs are written.
- C6-C26 `fix`: `test/fixtures/bench/parser.ern` copies `examples/repl.ern` with nothing holding them equal; a test does.

**The Ernest code** (E)

- E2 `fix`: `Test.faults` leaves its judge and `run`'s process alive when its caller ends first, shown by the next test's `Process.live()`; the judge monitors the caller and kills `run`'s process at the caller's end.
- E13 `fix`: the shell's `isExpected` says neither what it tests nor who expects; with E23's decision it goes, or is named for what it tests meanwhile.
- E's pages and comments: with *The documents* above.

**The tools** (T)

- T2, B8 `decide`: a faulted doc example's trace names the generated `$Example1.docShown:5`, `ern test` reports `passed` for an example it only compiled, a one-line `// => v` is never checked, and an untagged block is silently no example. Recommendation: a compile-only example reports `compiled`, the frames name the case and the doc block's line, and §11.2 and E.0 shape rule 6 say the `// => v` line stands alone at the end; by principle 3.
- T4 `fix`: `ern doc` writes `Generated by ern 0.4.0` from a development build whose `--version` says `0.4.0-dev`; one version text.
- T5, T22 `fix`: a `.erc` of another namespace gets two wrong messages, and a single-file build from the project root silently takes `Src.` from the working directory; the namespace is tested before staleness, the `--source-root` hint given only where the option was not, and an unknown name gets a help naming the nearer source root.
- T6, T14, T27, T28, T36, T37, T38 `fix`: a read-only directory blamed on the file, `Hello.erc`'s message differing from `Hello.ern`'s, the vendored option parser's messages, "no such file" in two spellings, `ern run` with no arguments not naming the bare node, the family message stating both branches, and a footer naming the source by base name.
- T7 `fix`: `:load` writes its path absolute or from the source root, neither of §11.5's forms.
- T8, T20 `fix`: a run of `ern doc` removes only the kind of file it writes, and `ern doc` has no `--verbose` though it compiles, compares and deletes; the sweep removes both kinds and rewrites `index.md`, and `--verbose` is added under §11.4.
- T9 `fix`: a module cycle in single-file mode gets advice that leads in a circle; the cycle is reported.
- T10, T29 `fix`: the entry-point refusal says `() -> Unit` where an entry point may receive, and cites the report; the shell's help calls `--main` the entry point.
- T11, T12 `fix`: a killed test prints `faulted: Killed`, which §11.2 gains a sentence for, `killed`; the `killed` line of `ern run` has no time and no site in a log.
- T15 `decide`: `ern reload` exits 0 when the node refuses the reload, the refusal appearing only on the node's standard error. Recommendation: `ern reload` reads the directory as the node would and refuses with status 1 before signaling, as `ern config --peer-dir` already reads it, §11.2's sentence changing; by principles 1 and 3.
- T17 `decide`: `ern config` is two jobs under one word, creating a directory and listing a peer, with `--config-dir` meaning the directory made in one and the one written in the other. Recommendation: keep, listing a peer being a change of the configuration, which `config` names; stated in §11.3.
- T18 `decide`: `:set output n` sets the live region's rows and `:output path` sets where programs write. Recommendation: `:set rows n`, by principle 1.
- T19 `dropped`: a version number marks the previous version for a type and the current one for a site; a site is fixed at the spawn and cannot follow a later version, so the asymmetry stands, and §11.2 states both rules.
- T21 `fix`: the shell changes `$HOME/.ernest`'s mode silently in line mode, which keeps no history; only where a history is kept.
- T23 `fix`: `ern doc --build-root`'s help says "where the compiled tree goes" and the one directory is both where documents go and where `.erc` files are read; the help says so, and whether the two roles stay one is §11.4's to state.
- T24 `dropped`: `ern shell file.erc` is a program with a prompt, the shell being the entry point (§11.2), not a second `:load`; the deployment guide's warning stays.
- T25 `fix`: `--libs-dir` is given once while the guide compares it to `ERL_LIBS`, a list; the guide drops the comparison.
- T26 `fix`: `ern --help build` is refused and `ern build --help x.ern` accepted; one rule.
- T30 `decide`: `--short-errors` is a second form of the diagnostics. Recommendation: drop it, since the full form's first line is already the machine-readable one and the Emacs mode reads it; by principle 2 for the toolchain's one layout.
- T31, T32, T-L2 `dropped`: `export` at the prompt is §11.2's stated exception so a module's text pastes; standard error's format following its destination is the operator's own choice stated in §11.2; `--emit-erl` is for reading.
- T33, T34 `fix`: `:output -` in line mode names a region that does not exist; `ern --version` refuses a working directory that is not UTF-8.

**The diagnostics** (X): 266 of 272 entries judged clear

- X1 to X10 `fix`: the helps that lead in a circle or to a second error, the false `()` help, a label's variable named otherwise than the message's, a missing label, two §3.11 messages stating the rule as what happened, seven helps that give the reason and no fix, a help that does not fit too many arguments, spans wider than the error, and a label that repeats the message.
- X11 to X29 `fix`: the helps and wordings X gives, each line's text as it stands in the list: specifier and escape lists, a route for a variable twice in a pattern, "annotate it" naming nothing, the lexer's two words for one concept.
- X30 `decide`: report citations appear in some messages and helps and in every §3.11 help, and in none else. Recommendation: no citation in any message, since a user who made the mistake wants the fix and not the section, except the §3.11 helps, whose rule has no short name; stated in §11.5.
- X31 `fix`: three §11.5 rules have no program in the catalog; added.

**The broken program** (B)

- B2 `fix`: a spawn or compute written inside a top-level `let`'s lambda always fails with "the spawner's node no longer holds the function's reach", so no `Test.Case` can test work on a peer; such a lambda gets an identity the code table holds, as one in a `fn` has.
- B3 `fix`: a caller waiting in `callForever` on a process of a peer stopped in order ends silently with `ProgramEnd`, or faults nothing; the caller faults with §6.6's cause for a callee that ended.
- B4 `decide`: the shell prints `fault: division by zero` with no trace for an input's own fault, where `ern run` prints the trace and a process spawned at the prompt gets one. Recommendation: the trace beneath the `fault:` line, §11.2's sentence changing; by principle 1.
- B5 `fix`: faults already on their way are dropped when the entry process's fault ends the program, against §11.2's "every fault, as it happens"; the end writes the reports the reporter holds before it exits.
- B6 `decide`, with C3-C2: a fault carried back from a compute names neither the peer nor the caller's `computeAt` line. Recommendation: the carried fault's trace adds the caller's frame, and the cause says "on the peer foo"; §8.7's sentence on a compute's fault states it.
- B7 `fix`: a segment overflow's frame has no line and its cause names no segment; the line is given and the cause says what did not fit.
- B9 `fix`: the fault that makes a supervisor give up is reported `restarted` though the child was never restarted.
- B10 `dropped`: frames vanish where the host's compiler removes `+ 0`; the host's own, which the guide's §6.3 names for tail calls alone, and nothing of Ernest's to state.
- B11 `fix`: `Process.live()` in the shell lists the shell's own processes, against E.21.
- B-C3 `decide`: a fault passed back through a call repeats the callee's cause word for word, so three lines say `division by zero` and only the host's frame shows the origin. Recommendation: §6.6's cause names the callee, "division by zero, the fault of the callee Ledger.start:6"; by principle 1.
- B-C4 `decide`: a socket's and a listener's faults speak of a "callee". Recommendation: the cause names the socket, E.18's texts.
- B-C5, B-C6, B-C7, B-C13 `dropped`: a foreign fault's values are left out on purpose, a value being large or not the program's to show; `NotLoaded` names nothing since the peer's line does; an `Io.Error` carries no path the program does not already hold; a spawn's site is the declaration the `spawn` is written in (§6.9).
- B-C8 `decide`: `:faults` prints identical lines for different processes of one site. Recommendation: each line carries its time, as `ern run`'s does in a log.
- B-C9 `dropped`: a test that loops forever is not found, as §11.2 says of a node, and a spin is no wait for the look to see; no limit per test.
- B-C10 `fix`: with L3, the guide says a wait on another node's process is never a deadlock.
- B-C11 `fix`: after a failed `:load`, the shell's help suggests the command that just failed.
- B-C12 `fix`: a negative time answers `Left(Timeout)` at once, which the report does not say; E.0 shape rule 8 says so.
- B-H1 `fix`: a field read on a lambda parameter with no annotation is reported at the operator with "annotate it"; the message names the parameter.
- B-H3 `decide`: finding what a hung process waits on takes `List.map(Process.live(), Process.status)`. Recommendation: `:processes` shows each process's activity, a shell item for MVP 4.3.

## The readers' lists

Each reader's whole list, as handed in. A path a list names is in the reader's scratch directory of the day, not in the repository.

### Reader P


Read: `report/language.md`, `report/toolchain.md`, `report/library.md` whole (70,190 words), and the diff from fb2324e8 (`changed.diff`). Findings concern rules the diff touched or that the changed text newly bears on; the counts are over the whole report. Every program below was written under `tmp/review/P/t*/` and run with `bin/ern` (0.4.0-dev); nothing in the repository was touched. Defects first (P1–P6, P8), then matters of clarity (P7, P9–P14); the suspected leftovers and the "what it buys" table follow.

#### Findings

**P1. A wrap that calls `self()` is accepted as a named `fn` and refused as a lambda** (language.md §4.5, §3.9; defect by principles 1 and 2).

§4.5: "`: T` stands over the body of a `fn` that calls `self`, `monitor` or another function whose type holds its mailbox type in a value position, where the body neither waits nor has that variable in a value position of the signature: `fn f() : Unit = kill(self())` has type `() -> Unit`." The rule is written for a `fn`; a lambda whose context binds its effect to none meets the value-position mark while the definition is still being inferred and is refused. `t1/d.ern`:

```ernest
type Msg = Done
fn w(d : Down) : Msg = { kill(self()); Done }            // accepted: w : (Down) -> Msg
export fn named(p : Process) : Unit receiving Msg = { monitor(p, w); receive { Done -> Unit } }
export fn lambda(p : Process) : Unit receiving Msg = {
    monitor(p, fn(d) = { kill(self()); Done });          // refused
    receive { Done -> Unit }
}
```

`ern build` answers `the argument does not fit monitor: a function that receives where one that receives nothing is needed`, labeling `monitor : (Process, (Down) -> m) -> Unit receiving m`, while `named` with the same body builds and `:browse` prints `(Process) -> Unit receiving D2.Msg`. A reader who knows that a `let`-bound or named function and a lambda are one thing in Ernest (§3.9, §4.6) predicts both accepted; and the error says the lambda "receives", which §4.5 says the same body does not. Fix: §4.5's sentence binds "a `fn` or a lambda", and the checker lets the value-position mark stand to the lambda's end as it does to a `fn`'s, so that the context's none binds it there.

**P2. A top-level `let` whose type holds one effect variable in two function types gets `receiving Never`** (language.md §4.6; defect by principle 1).

§4.6: "an effect variable left in its type that occurs nowhere but as one function type's effect is none, so that the function receives nothing; a type variable left that stands in no value position (§3.9) is `Never`". Per §3.9, "A type argument of a built-in or foreign type is a value position", so `Address(n)`'s `n` is a value position and the second sentence covers nothing but an effect variable in two or more function types, which it makes `Never`. `t1/e.ern`:

```ernest
fn twice(f) = #(f, f)
export let p = twice(fn(x : Int) = x)
```

`:browse E` prints `E.p : #((Int) -> Int receiving Never, (Int) -> Int receiving Never)`. Calling a component from `main` (`t1/e2.ern`) is refused, `f needs a mailbox, and main receives nothing`. A reader predicts `#((Int) -> Int, (Int) -> Int)`: a function receiving nothing stands anywhere, and nothing here fixes a mailbox. Fix: one sentence, "an effect variable left in its type that stands in no value position is none", dropping "one function type's"; the `Never` sentence goes, since §6.2 already makes an unfixed `Address(n)` `Never` and every other left variable is the type error the paragraph ends with.

**P3. §6.1, §0 and E.0 shape rule 5 contradict §4.5's new rule, and §4.5 contradicts itself** (language.md §6.1, §0, §4.5; library.md E.0 shape rule 5; defect: two normative sentences, one program).

§6.1: "A function that contains no `receive`, calls no `self`, asks for no delivery and none of whose calls determines a mailbox type receives nothing", and its first paragraph: a function whose mailbox is involved "gives out its address by `self`". §0 and shape rule 5 say "gives out its address". §4.5 now gives `fn f() : Unit = kill(self())` the type `() -> Unit` (`t1/a.ern` builds; `:browse A` prints `A.f : () -> Unit`). Within §4.5, the first paragraph says the function has that type "as it has with `: Unit receiving m`", and the next says `receiving M` over a body that does not receive "is an error"; `t1/b.ern`, `fn g() : Unit receiving m = kill(self())`, builds and prints `() -> Unit`, so "receives" in the second paragraph means "involves its mailbox", which the sentence does not say. The new rule is right by principle 5 ("A type carries what keeps values and messages safe ... and nothing of what a function does": an address that reaches no one through the type needs no mark); the older sentences are stale. Fix: §6.1 "gives out its address through its type"; §6.1's last sentence "calls no `self` whose address its type carries"; §4.5 paragraph 2 "written only where the body involves its mailbox (§6.1)"; shape rule 5 and §0 likewise.

**P4. A `kill` now travels through a runtime process, so a message sent after it may be handled first; §10 states this and §6.9, the owner, does not** (language.md §10, §6.9, §8.7 "What passes"; principles 1 and 5).

§10: "A `kill` costs a process of the runtime's own, which reads the killed process's call (§6.6) before it ends it; a message the killer sends after the `kill` may reach the process before it ends (§6.9)". §6.9 says only "`kill` is asynchronous: the target may run until the runtime interrupts it", which is weaker: a reader who knows Erlang predicts that an exit signal and a later message from one sender keep their order, so `kill(p); send(p, Hello)` never handles `Hello`. `t5/kill_order.ern` prints a line if `Hello` is handled; in eight runs it never was, so the report states a possibility the runtime seldom shows. The process exists for §8.7's compute ("the caller ends ... its node tells the peer, which kills the process"), which needs the killed caller's call record: a rule of the language's ordering bent for another rule's bookkeeping, which §0's principle 5 forbids unless stated as a limit. Fix: §6.9 states the reorder in one sentence beside "asynchronous", or the kill goes to the host's exit signal and the record is read by the runtime's monitor on the caller, keeping the host's order; §10 then drops the sentence.

**P5. The shared type namespace of §4.2 makes `main/stack.ern` depend on `main.ern`, a dependency §11.1 does not state, and it is read as no other is** (language.md §4.2; toolchain.md §11.1, §11.5; defect of statement).

§4.2: "A member of an exported type and an exported value of the module of its name ... may not share a name: `main/stack.ern` exporting `compare` while `main.ern` exports `Stack` with a `compare` is an error, reported in `main/stack.ern`." §11.1: "A module depends on each module a qualified name in its source names, and on each module that declares a type the interface of a module it depends on names" — `main/stack.ern` names nothing of `Main`. `t4/`: `ern build main/stack.ern` with no `main.erc` present reports `Main.Stack.compare is a member of the type Stack in main.ern`, so the compiler reads `main.ern`'s source; `t9/`, an ordinary unbuilt dependency, is refused with `compile A first, which B uses: a.erc: no such file or directory`. Directory mode finds the clash when `main.ern` gains `derives compare` later, so the dependency is real and recorded; the report does not say so. Fix: §11.1 adds "a module depends on the module whose namespace its own stands directly under, where that module declares a type of its name (§4.2)", and says whether it is read from its `.erc` as every dependency is.

**P6. Stale words from the swept note and gateway mechanisms** (library.md E.27; language.md Appendix F "frame", §8.7 "A loss"; defect: dangling definitions).

The diff removed the glossary's **gateway** and **note** and §8.7's gateway paragraph, and made the `kill` the fifteenth frame. Left behind: E.27 opens "Over the runtime's record of the node's peers and of its offers, and the node's gateway (§8.7)", which §8.7 no longer defines; Appendix F **frame** lists "a call's two notes" and fourteen items, without the `kill`; §8.7 "A loss" drops "the peer's notes and its utilization". Fix: E.27 "and the node's runtime (§8.7)"; **frame** "that a call waits and that it is over, a `kill` of a process of another node"; "A loss" "the calls it holds for the peer and its utilization".

**P7. The atom `ok` is a second host spelling of `Unit`, at one position, for a program's shims alone** (language.md §8.4 "What is checked", §7.4; principle 2 at the boundary, principle 1).

"A foreign function's return declared `Unit` that is the atom `ok` ... is `Unit`: the check takes it, and a library's foreign function, which is not checked, answers `Unit` itself ... Nothing else takes `ok`." The ABI table says a nullary constructor is the atom of its spelling, `'Unit'`; the reader who knows the table predicts `ok` is a bad value. `t6/ok_unit.ern` over `io:put_chars/1` shows the check converts: `u == Unit` is `true` and `Io.show(u)` is `Unit`, so the value is sound. What it buys: a shim over an `ok`-answering host function without an Erlang helper. What it costs: a rule by position (a return's top, a function value's result, and nowhere else) and by caller (not the standard library's shims, which the rule itself warns must answer `'Unit'`). Recommendation: either the ABI table carries the line, `Unit` ← `'Unit'`, or `ok` at a return's top, so that the two spellings stand where the reader looks, or the rule goes and Appendix D's `: Bool` + `let _ =` shape stands.

**P8. The ground term of §11.1 is observable: `let a = 2` keeps a value after a faulting reload and `let b = 2 * 1` does not** (toolchain.md §11.1, §11.2; language.md §8.5; principles 1 and 5).

§11.2: a binding whose hash a faulting reload changed "is then without a value ... one compiled to its value (§11.1) has it". `t8/`: in the shell, after `:reload` of a module whose new first binding faults, `M.a` (`let a = 2`) answers `2 : Int` and `M.b` (`let b = 2 * 1`) answers `fault: the binding has no value, since one before it faulted`; the shell's own report line spells the rule out. The reader predicts the two bindings alike: both are new and both stand after the fault. The ground term exists for the compiler's convenience (reading a constant without a call); its one visible effect is this corner. Fix: either every binding whose hash the reload changed is without a value, the ground one's getter faulting as the others' do, or the ground term becomes the language's: §4.6 says what it is and §8.5 that it needs no evaluation, since a reader of the language should not have to read the toolchain for a semantic distinction.

**P9. The toolchain's libraries stand on every load path, yet their namespaces are neither taken nor said to be hidden by a program's module of the name** (library.md Appendix G; toolchain.md §11.1, §11.2; language.md §4.2; clarity, and a mismatch of status).

Appendix G is "Informative", yet §11.1 and §11.2 make its list normative: "after them stands the build of each library of the toolchain's own (Appendix G)". `t7/json.ern`, a program's module `Json` at its source root, builds and `Json.f()` runs from it: the program's `Json` hides `libs/json` by the load path's order, which §4.2's taken-namespace rule does not mention. A reader who has just read that `fs/entry.ern` is refused for standing under `Fs` (verified: `fs/entry.ern stands under the standard library namespace Fs`) may predict `json.ern` refused too. Fix: §4.2 one sentence, "a library's namespace (Appendix G) is not taken: a module of its name under the source root or a `--load-path` root hides it"; Appendix G's "Informative" qualified, "the list of libraries is what §11.1 and §11.2 put on the load path".

**P10. The rule "an effect variable nothing fixes is none" is now stated three times in three shapes** (language.md §3.9 "fresh effect variable", §4.5, §4.6; clarity).

§3.9 states it for an expression ("takes a fresh effect variable in its place, which the context binds"), §4.5 for a `fn`'s end, §4.6 for a top-level `let`'s end, each in its own words, and P1 and P2 are where the three disagree. §3.9 owns inference. Fix: one sentence in §3.9, "an effect variable that nothing has fixed by the end of its definition, and that stands in no value position of the signature, is none", and §4.5 and §4.6 cite it with their examples.

**P11. `Address.call` and `Address.callForever` are the prelude's two qualified functions, and the diff adds a shell special case for them** (language.md §9.5, §4.2; toolchain.md §11.2 "`:browse Address` the prelude's functions under `Address`"; principles 2 and 5).

Every other prelude function is bare: `send`, `answer`, `kill`, `adapted`, `monitor`, `spawn`. The two calls live under `Address`, which §4.2 therefore lists as a taken namespace ("`address.ern` at the source root is an error") though no module provides it, and the shell needs a sentence of its own to browse it. I suspect a module `address.ern` once held them and the prefix stayed when §9 made them the runtime's ("`Address.call` and `Address.callForever` are the runtime's, as the process functions of §9.4 and §9.5 are"). Fix: `call` and `callForever` bare in §9.5, as `answer` is; `Address` leaves the taken list; the `:browse Address` clause goes.

**P12. E.21's trace rule says a runtime frame is "left out wherever it stands" and then that some are kept** (library.md E.21; clarity).

"A frame of the runtime's ... is left out wherever it stands, and the twelve are counted without it. A fault whose cause names a host error ... keeps the runtime's frames above the program's outermost frame." Whether "above" means inner or outer is not said, and the first sentence admits no exception. Fix: "left out, but for a fault whose cause names a host error, which keeps the runtime's frames between the program's innermost frame and the host's".

**P13. §8.7 states what a peer does when a node breaks a promise the same sentence makes** (language.md §8.7 "Its start and its end"; clarity).

"A node that has said it ends tells no peer how busy it is after; a peer told so by a node after its word takes the node to go on, and the close of its connection for a loss." The second half is a rule for a telling the first half says never comes. If it exists for a node of another build, say so; otherwise drop it.

**P14. The load path now holds two kinds of root under one name** (toolchain.md §11.2, Appendix F "load path"; clarity).

`--libs-dir` adds each application's `ebin` as a root of the load path, under which, by §11.2's first paragraph, modules "are found by namespace", and the glossary now defines the load path as both the roots of modules and "the directories a `foreign fn`'s `.beam` is found in". An `ebin` holds no `.erc`, so nothing breaks, but the one word covers two things. `--libs-dir` itself is a second spelling of `--load-path lib/*/ebin`, bought by the host's `name-version` layout and its duplicate check; the toolchain is not bound by principle 2, so this is a note, not a finding.

#### Suspected leftovers

Things kept because nothing broke, in the shape of a decision made when the language was small. I cannot read the log; each is a suspicion with its reason.

- **L1. `Address.` on two prelude functions** — P11.
- **L2. `show` in the member grammar.** `Member = typevar "." ( userop | "compare" | "negate" | "show" )`, while §4.9 says `show` "is no member but `Io.show` and `Io.debug`" and "`a.show` names nothing in a body". Requirements were shaped for members; `show` took the shape later. Harmless, but the reader meets a member that is none.
- **L3. §9.4's heading "Built-in functions (§6)"** holds `Io.show` and `Io.debug`, provided by `io.ern` and no part of §6. A heading from when `show` was built in.
- **L4. Appendix D restates G.1.** D is "A Foreign Library", the `Ets` module written out; G.1 is `libs/ets`, the same library listed as Appendix G lists the others ("which Appendix D shows with a shorter documentation"). D predates G; the report states each rule once, and D is now a teaching text inside it. Either D becomes the one listing of `Ets` or it names a pattern G does not.
- **L5. The lone-effect rule stated three times** — P10.
- **L6. `Code.running(f)` requires `f`'s result type to be `Unit`** (§3.11, E.28). Any function may be on a process's stack; `Unit` is the shape of "the function a process runs" from when `running` was conceived for §6.10's loops. The diff touched the rule (`Never` for a function receiving nothing) and kept the shape.
- **L7. `spawnMonitored` beside `spawn` and `monitor`** in the prelude. The pairing closes the race §6.9 implies (a `monitor` after the process ended gives `Unknown`), so it is one job, not two; the report never says that, by its own rule of stating no why, and a reader of principle 2 will ask. One line in §6.2, "monitored before it can end", would settle it.
- **L8. Appendix H lists `{var, Reference, Supplies, Held}`** among expressions and explains `Type` for `Address.call` but never `Held`. Not in the diff; noted since Appendix H's version moved to 2 in it.

#### Counts

**Reserved words: 18**, §2.4's table (`type abstract receiving foreign match when receive after as or if then else fn let export true false`), the count the section itself gives. Beside them, **16 words read by position**: `needs derives compare negate show` (5) and the bitstring specifiers `size bytes int float utf8 utf16 utf32 big little signed unsigned` (11); `Prelude` is a reserved namespace name ("No module and no type is named `Prelude`") and `_` a token. Appendix A's operator and delimiter tokens: 36 (§2.6's two lines, 19 and 17).

**Primitives, the prelude's: 21 types and 33 functions, and 5 forms.** Types: §9.1's 10 (`Int Float Char String Bytes Bool Address Reply Never Process`), §9.2's 3 (`List Map Set`), §9.3's 8 declared (`Unit Optional Either Ordering Down Reason RestartLimit Path`, with 18 constructors). Functions: §9.4's 4 (`self send spawn spawnMonitored`) and the 2 it lists from `io.ern` (`Io.show Io.debug`), §9.5's 7 (`adapted Address.call Address.callForever answer restarting monitor kill`), §9.6's 20 (`Int`'s 5 operators and `negate`, `Float`'s 4 and `negate`, four `<>`, four `compare`, `fault`). Forms, §0's "named function that is no value", called where named: `Peer.spawn Peer.spawnMonitored Peer.compute Peer.computeAt Code.running`, 5 (E.27 says `Peer.service` is a value). Counting method: each name in §9's listings once, an operator member once as a function, system references none (§9.7 binds none).

**Concepts: about 70** at the grain of "a rule a reader must hold to predict a program", counted by walking §2–§10 and listing each notion with its own rule, not each term; §0's own count is 2. Types (17): base types, tuples, lists, function types with arity, the mailbox type, sum types with positional and named fields, abstract types, `Address`/`Reply`/`Never`, foreign types, HM generalization and rigid annotation variables, effect polymorphism and none, process-only, the equality constraint, ordering through `compare` and the order laws, `derives compare`, bound types and crossing, value and effect positions. Declarations (12): module as file and namespace, export, taken namespaces, type members as nested namespaces, `Prelude` and shadowing, `fn`, top-level `let` with its generalization rule, foreign declarations, operator resolution, requirements, operations records and fills, selectors. Expressions (11): blocks and statements, block `let` and shadowing, `<-`, construction with record update and paths, pipe, `if`, `match` with or-patterns, guards, coverage and redundancy, patterns with `as` and irrefutability, bitstrings, lambdas, local `fn`. Processes (17): process and mailbox, `self`/`send`/`spawn`, `spawnMonitored`, `receive` with `after` and guard expressions, message order, addresses and adapted addresses, services, request-reply, remote computation, `Never` as a mailbox, death and reasons, `kill`, `monitor` and `Down` and spawn sites, resource ownership, `restarting`, code replacement, the one silence. Errors (3): value, message, fault with cause and trace. Programs (10): entry point, system references and modules, terminal claiming, peers and nodes, the foreign boundary and its checks and ABI, initialization order, termination and subscribers, deadlock, the node's configuration/floor/connection/loss/hash/reach/frame/exchange/offer/find/utilization (one concept at this grain, a dozen at Appendix F's), bare node. Runtime (2): code table and unit, ground term. Appendix F holds 163 entries; the standard library has 27 modules (E.1–E.28 less the folded E.19), 356 exported signatures over Appendices E and G (lines `Name.fn : ...` in library.md), 4 admission and 10 shape rules; Appendix G has 6 libraries (G.1–G.7 less the removed G.5).

#### What each diff-touched rule buys

Asked of the rules the diff touched: what it buys a program, what the language loses without it. "Little" and "for another" are marked.

- **§4.5 `: T` over a body that calls `self`** — buys the drop of a vacuous `receiving m` on a function whose address reaches no one through its type; without it every such function carries a mark that protects nothing (principle 5). Right; P1 and P3 are its edges.
- **§4.6 lone effect variable none** — buys the predicted type for `let xs = List.map(..., fn(x) = fn() = x)`; the "one function type" clause buys nothing and loses P2. **Little, for the clause.**
- **§4.6 unfixed variable in no value position is `Never`** — covers nothing §6.2 does not (P2). **Little.**
- **§3.11, E.28 `Code.running` of a function receiving nothing answers `Address(Never)`** — buys soundness: the old unfixed variable could be pinned by a later `send`. Verified `:type Code.running(W.worker) : List(Address(Never))`.
- **§3.11 `Peer.computeAt`'s result type bound** — closes an omission; nothing lost.
- **§4.2 "nor stand under" a taken namespace** — buys that a qualified name beginning with a standard library namespace is always the library's; without it `Fs.Entry` could be a program's module.
- **§4.2 a module shares the namespace of a type of its name** — buys the prelude's shape (`Map` the type beside `Map` the module) for programs and removes a refusal; costs the hidden dependency of P5.
- **§6.5, §6.9 `self()` and `monitor` in a wrap or an adapted function are the recipient's** — closes a gap the type system almost forbids reaching (a wrap receives nothing, so only a `self()` whose type nothing fixes gets there); cheap to state.
- **§6.7, §8.7, E.27 "and the step of the attempt"** — buys honesty about a host time, as §0 "Time" requires.
- **§6.9 `restarting` runs the `f` given, after an upgrade** — a consequence stated; buys predictability. The alternative, restarting the upgraded `next`, would need the runtime to track a tail call, which principle 3 refuses.
- **§6.9 site of two functions with one body, and `bare node`** — closes two gaps.
- **§7.3, E.21, §8.4 ABI, §10 trace** — buys diagnosis; §10 states the cost (64 frames per raise). P12 is its wording.
- **§7.4, §8.4 `ok` is `Unit`** — buys helper-less shims over `ok`-answering host functions, for a program's shims only. **For the host's convention; little against its two spellings** (P7).
- **§7.4, §8.4 fault texts naming the function** — buys a better cause; nothing lost.
- **§8.4 a message by host identity is unchecked** — states a promise that was silent.
- **§8.6 a process inside foreign code is not waiting** — buys a correct look through a blocking foreign call; the alternative, declaring it per `foreign fn`, would be a word on every shim (principle 5).
- **§8.7 memory `check-interval` a multiple of 60000** — buys a refusal in place of a silent truncation (§0 "The host").
- **§8.7 "the one that measures left out"** — a correction of a count.
- **§8.7 a node that said it ends tells no utilization** — closes an order; the defensive half is P13. **For another node's breach.**
- **§8.7 refused for answering another peer's dial; the key of the peer dialed** — buys that a dial reaches the peer meant and no other; a security rule, cheap.
- **§8.7 a patch changes no type, admitted unhashed** — states the assumption the floor already made.
- **§8.7 fifteen frames, the `kill`** — exists so that the killed process's call record is read (P4). **For another rule (the compute's kill).**
- **§8.7 gateway and notes gone from the text** — a sweep; P6 is what it left.
- **§8.7 frames carry `ms`; the exchange waits no longer than the latest** — buys bounded memory on the peer; nothing lost.
- **§8.7 compute: the node tells the peer, which kills** — the same mechanism, now without the note vocabulary.
- **§8.7 one address per name at each type's hash** — buys an upgrade with both versions offered; without it a new-version service could not stand while an old-version client still finds the old.
- **§8.7, E.27 `setUtilization` 0.0 or above** — buys consistency with a scale that passes 1.0 ("above it work waiting").
- **§8.7 compute ties: the first drawn** — a correction; a random tie was already random.
- **§10 a call's wait reads the mailbox** — states a cost that grows; required by §0's principle 5 on costs.
- **§10 a `kill` costs a runtime process** — P4.
- **§11.1 ground term** — buys speed of reading a constant; the language loses nothing without it; P8 is its leak. **For the toolchain.**
- **§11.1 dependency order ties broken by path** — buys a deterministic build order; cheap.
- **§11.1, §11.2 the toolchain's libraries on every load path** — buys "a program names none of them" (principle 5's "no word written"); P9 is its silence.
- **§11.1, §11.2 `--verbose`** — buys visibility of a job's decisions on request; nothing lost.
- **§11.2 `--libs-dir`** — buys the host's `name-version` layout and its duplicate check; a second spelling of `--load-path`. **For the host's layout** (P14).
- **§11.2 `ern test` runs doc examples as cases** — buys that shape rule 6's `// => v` is checked by the toolchain and not by a reader; the empty working directory buys isolation.
- **§11.2 `Test.faults`'s process not reported** — a consequence of E.24; without it every fault test writes a line.
- **§11.2 a fault line before the next prompt in line mode** — buys a deterministic transcript.
- **§11.2 `:browse Address`** — P11. **For another (the two qualified prelude functions).**
- **§11.2 a ground binding keeps its value after a faulting reload** — P8.
- **§11.3 `--listen`, `--peer-dir`** — buys a two-node setup on one machine without an edit of `ernest.conf`; a convenience, cheap and stated whole.
- **§11.4 no field list for an abstract type** — a correction (constructors are not visible outside).
- **§11.5 new diagnostics** — buy named fixes; nothing lost.
- **E.0 `mapFold` in the sequence vocabulary, E.2 `List.mapFold`** — buys a word for a fold that answers both; admitted through rule 2, so rule 4's composition refusal does not reach it.
- **E.0 shape rule 6 `ern test` runs examples** — see §11.2.
- **E.22 `Supervisor.child` loses `m+`** — a consequence of process-only for a wait alone; right.
- **E.24 `Test.faults`** — buys a fault test without a spawn-monitor-receive dance in every test module; its type carries no mailbox, so it is one function where the dance was six lines.
- **E.28 `Code.load`'s errors regrouped, `hashes` lower-case** — clarity and a determinate text.
- **Appendix H version 2: annotations out, the checker's types in** — buys that two definitions differing only in an annotation hash alike, as they mean alike; the types on `let`, `<-` and a lambda buy the peer a compile from the form without inference. Right.
- **Appendix F additions** — see P6 for the entries that were not swept.

### Reader K


Ernest full review, at 1329d1d2. I read the three report files whole and then `docs/soundness.md`. Each finding involves text the diffs from fb2324e8 changed, or text the changed text newly bears on. Every program below is in this directory and was run with `bin/ern`.

The list has four parts:

- **Defects**, K1 to K12, most serious first: rules that disagree, steps of the argument that do not follow, and dangling text.
- **Silences**, K13 to K19: places where a builder of a conforming toolchain must guess.
- **Clarity**, K20 to K26.
- **Kept from an earlier stage**, after the list.

#### Defects

**K1. Foreign messages sent by host identity: the argument lacks the promise its claim 2 needs.**

- Where: language.md §8.4 **What is checked** (new sentence); docs/soundness.md §2.
- Quote: "A message foreign code sends to a process by its host identity, which a foreign function's implementation has as its caller, crosses nothing and is not checked: a foreign function without `receiving` promises to deliver none (§4.7)."
- What is wrong: §4.7 lets a `foreign fn ... receiving M` deliver into the caller's mailbox, and nothing checks what it delivers. The soundness argument lists only two promises of foreign code: values at a type variable, and no delivery without `receiving`. It also says "A message foreign code sends that fails the check does not enter the mailbox as a value". That sentence is false for these messages. Claim 2 then fails for a program the checker accepts, and so does claim 1 (a primitive given a value of another type).
- Program `ff/main.ern`:
  ```
  foreign fn me() : Foreign.Term receiving String = "erlang:self/0"
  foreign fn sendRaw(to : Foreign.Term, message : Int) : Int receiving String = "erlang:send/2"
  export fn main() : Unit receiving String = { let _ = sendRaw(me(), 42); receive { text -> Io.println(String.toUpper(text)) } }
  ```
  The `receive` binds `text : String` to 42, and the program faults inside the library: `foreign function ern_string:to_upper/1 raised error:{badarg,42}`.
- The same gap holds for any process whose pid foreign code obtains, for example through `Foreign.term(process)`.
- Fix: state the third promise in §4.7 and §8.4, and add it to soundness §2. Or check such messages on delivery.

**K2. §4.5's new exception admits programs that are unsound or undefined.**

- Where: language.md §4.5, second paragraph.
- Quote: "`: T` stands over the body of a `fn` that calls `self`, `monitor` or another function whose type holds its mailbox type in a value position, where the body neither waits nor has that variable in a value position of the signature".
- Case (a), `p1/main.ern`: `fn f() : Unit = send(self(), 5)` meets the conditions as written. The body calls `self`, does not wait, and the signature `() -> Unit` holds no variable once `m` is fixed to `Int`. Read so, `f` is `() -> Unit` and can be called from `main : Unit receiving String`, which would put 5 in a `String` mailbox. The toolchain refuses it ("self needs a mailbox, and f receives nothing"). The text does not.
- Case (b), `p4/t.ern`: `fn f() : Unit = { let me = self(); let _ = spawn(fn() = receive { x -> send(me, x) }); Unit }` also meets the conditions, since the receive belongs to a spawned lambda. §3.9 agrees, since the generalized scheme holds `m` only in an effect position. At the instance none, `spawn`'s `n` is none, which is no type, and §6.2 gives it no meaning. The toolchain refuses this too.
- The soundness paragraph rests on "nothing in it has the variable's type", which is false for (b), where `x : m`. Its three listed conditions do not imply that premise: a receive in a spawned function neither fixes the variable nor makes `f` process-only.
- Fix: state the condition the checker applies, that the variable is left unfixed and no expression of the body but `self`'s or `monitor`'s result has a type holding it. Then derive the soundness premise from that condition.

**K3. Soundness §6.1 still states the rule §4.6 replaced.**

- Where: docs/soundness.md §6.1; language.md §4.6.
- Quote (soundness): "one whose initializer is a call ... has the type the call gives, a variable left in it being an error (§3.9, §4.6)".
- What is wrong: §4.6 now makes a leftover effect variable of one function type none, and any other variable in no value position `Never`. No paragraph argues either of these, and the cited sentence no longer follows from §4.6.
- Fix: rewrite §6.1 for the three cases.

**K4. The call's notes were removed from §8.7, but four references to them remain.**

- Where: language.md §8.7 **What passes**, which still lists "that a call waits, and that it is over"; §8.7 **A loss**, "drops what waited to be sent, the peer's notes and its utilization"; Appendix F **frame**, "a call's two notes".
- Appendix F **note** is deleted, so these frames and "notes" are now defined nowhere.
- docs/soundness.md §3 *Configurations* says "the note that node keeps of the call (§8.7)", and §7 says "the note a callee's node keeps being part of the runtime's record of the call". Both cite a rule §8.7 no longer states.
- Fix: restore one sentence defining the two frames, or remove the frames, "the peer's notes" and the soundness citations.

**K5. The gateway is gone from §8.7, but references to it remain, and the glossary misses the new kill frame.**

- Where: library.md E.27, first sentence: "Over the runtime's record of the node's peers and of its offers, and the node's gateway (§8.7)". §8.7 and Appendix F no longer define a gateway.
- The rewritten §8.7 sentence "a message to a node's runtime that names no process of a peer names no connection" can no longer be parsed.
- Appendix F **frame** lists 14 frames. §8.7 now has fifteen; the `kill` frame is missing.
- Fix: E.27 "and the runtime's carrier"; reword the §8.7 sentence; add the kill frame to **frame**.

**K6. Identical function bodies in two modules give a spawn site that names the wrong module.**

- Where: language.md §6.9; toolchain.md Appendix H.
- Quotes: §6.9, "Two functions with one body are one definition (§8.7), and a spawn written in either counts as written in the first declared". Appendix H, "within their module a reference to either is to the first declared".
- What is wrong: across modules, "first declared" is undefined.
- Program `p5/` (`alpha.ern` and `beta.ern` each `export fn start() : Address(Never) = spawn(fn() = fault("boom"))`):
  - Both processes report `Beta.start:2 faulted: boom`, with the trace `Beta.start:2`.
  - Both `Down` sites read `Beta.start:2`, though one spawn is written in `Alpha.start`.
  - This contradicts §6.9's own first sentence ("the top-level declaration in which the `spawn` ... is written") and misleads an operator (principle 1).
- Fix: state the rule across modules, or keep the site per declaration.

**K7. `Test.faults` disagrees with E.0's shape rules.**

- Where: library.md E.24.
- Signature: `Test.faults : (() -> a receiving n, String) -> Result`.
- Shape rule 8: it waits without a limit for another party, the process running the call. Shape rule 8 says `Address.callForever` is "the one wait on another party without a limit". If waiting for a process's end counts as "the runtime holds the answer", the section should say so.
- Shape rule 1: the callback comes first, though "callbacks last". This holds unless the call is the subject, which E.24 does not say.
- "it runs `run`" names a parameter the listing does not name.
- Fix: give it a time, or state both departures in E.24, and name the parameter.

**K8. §11.8's exit status for `ern test` ignores doc examples.**

- Where: toolchain.md §11.8.
- Quote: "`ern test` exits with status 1 unless every test passed, and with status 0 for a module that has none".
- What is wrong: §11.2 now runs doc examples as cases, and §11.2 also says "a module with neither tests nor examples prints `no tests`". By §11.8 a module with no tests and a failing example exits 0.
- Program `ex/bad.ern`: the toolchain exits 1.
- Fix: "unless every case passed, ... for a module with neither tests nor examples".

**K9. Appendix H leaves two parts of the hashed term unstated.**

- Where: toolchain.md Appendix H, **Expressions**: `{var, Reference, Supplies, Held}`.
- What is wrong: this node is listed and nowhere defined, so a conforming toolchain cannot reproduce the hash. The prose explains only the `Type` variant.
- **Definitions** now say "`Requirement` lists `{Number, Member}` in the order the requirement names them", so order is hashed. The order of a derived `compare`'s requirement is stated nowhere: "the members its fields' comparisons reach" (Appendix H) and §3.5 give no order. So the hash of `type P(a, b) = P(x : b, y : a) derives compare` is undetermined.
- Fix: define `Held`, and state the order, for example parameter order.

**K10. §10 contradicts itself.**

- Where: language.md §10.
- Quote of the new bullet: "A call's wait reads the caller's mailbox ...: its cost grows with the messages waiting".
- It contradicts the bullet three above: "grows with nothing but the operation's own input".
- Fix: state the call's wait as the exception, in the general bullet.

**K11. Two sentences of §11.1 lag behind newer rules.**

- Where: toolchain.md §11.1.
- "Cross-module references link at load, against `.erc` files under `build-root` and the `--load-path` roots" leaves out the toolchain libraries' builds, which two sentences earlier now join the search.
- "A lambda or a local `fn` that a `Peer.spawn` or `Peer.spawnMonitored` starts is compiled..." leaves out `Peer.compute` and `Peer.computeAt`. §8.7 cites §11.1 for a lambda a compute runs.
- Fix: add both.

**K12. E.21's trace rules contradict one another.**

- Where: library.md E.21, the `trace` paragraph.
- "the innermost twelve frames ... ending with the outermost frame of the program's code" cannot hold for a stack deeper than twelve. `tr/m5.ern` (mutual recursion, depth 20) shows twelve frames that do not end with `main`.
- "A frame of the runtime's ... is left out wherever it stands" is then contradicted by "keeps the runtime's frames above the program's outermost frame". The text does not say whether kept frames count toward the twelve, or how a runtime frame is written: neither the Ernest form nor `m:f/a:line` applies.
- Observed, not stated anywhere: self-recursion of depth 50 (`tr/m50.ern`) shows `deep:2` only twice and then `main`, so runs of identical frames are collapsed.
- Fix: state the cap, the end, the collapse and the runtime frame's form.

#### Silences: where a builder must guess

**K13. §4.6 does not say what a leftover process-only effect variable becomes, and its clauses lost their order with §6.2.**

- Where: language.md §4.6, new text.
- By the first clause ("occurs nowhere but as one function type's effect is none"), a process-only effect variable left in a binding that is not generalized becomes none, which contradicts §3.9's "never none". By §3.9's "treated as if it occurred in a value position", it is an error.
- The toolchain makes it `Never`. Program `p4/t4.ern`: `let w = mkWaiter(10)` gives "w needs mailbox Never".
- The old text said "once a spawned function's unfixed mailbox type is `Never`", which ordered §6.2 before the error. The new clauses read `Address(n)` as a value position, so `let p = spawn(...)` falls under "any other is a type error", unless §6.2 applies first, which the text no longer says.
- Fix: name the process-only case, and restore "once §6.2 has made it `Never`".

**K14. Does a ground binding have its value on a peer?**

- Where: toolchain.md §11.1 (ground terms) and §11.2 ("one compiled to its value (§11.1) has it"); language.md §8.7 ("only where every top-level binding its reach names ... has its value there").
- What is wrong: the report does not say.
- Program `nodes/main.ern`, `Peer.computeAt("b", fn() = limit + 1, 5000)` with `let limit = 10`, against a bare node: it answers `Left(NotLoaded)`, and the peer says "the binding Main.limit has no value here", though the code holds the value.
- Fix: say whether a ground binding needs evaluating on a peer, and for `Code.load`.

**K15. The type/module name clash rule has no stated dependency.**

- Where: language.md §4.2, **Type members**: "...is an error, reported in `main/stack.ern`".
- What is wrong: reporting it there requires reading `main.ern` while compiling `main/stack.ern`. §11.1's definition of a dependency does not include this (`main/stack.ern` names nothing of `Main`), and neither does its recompilation rule. Meanwhile `main.ern` may itself use `Main.Stack`, which works against §4.1's acyclicity.
- Programs `ns/`: the toolchain reads `main.ern` even for `ern build main/stack.ern` alone, and recompiles `main/stack.ern` when `main.ern` changes.
- "the member where the type `Stack` has one ... in `main.ern` and elsewhere alike" is also unclear for a private `Stack`. Program `ns2/`: elsewhere the toolchain takes the module's `compare`.
- Fix: state the relation in §11.1 and "where the use site sees the member".

**K16. The mailbox type of a running doc example is unstated.**

- Where: toolchain.md §11.2 (examples); library.md E.0 shape rule 6.
- Program `ex/waits.ern`: an example with `// =>` that receives fails with "docExample needs mailbox Int, and the mailbox here is Never". The same example without `// =>` passes, compiled at its own mailbox type.
- §11.2 does not say examples run at `Never`. E.0 says such an example "cannot run", but not what `ern test` does when it has a `// =>`.
- Fix: one sentence in §11.2.

**K17. "The latest `ms`" in the exchange is ambiguous.**

- Where: language.md §8.7 **The exchange**, new paragraph.
- Quote: "no longer than the latest `ms` of the frames that wait on them, from its ask".
- What is wrong: "latest" can mean the last frame to arrive or the furthest deadline. When two spawns share an exchange, one reading can cut the earlier, longer spawn short.
- Fix: "the furthest deadline among them, each `ms` counted from ...".

**K18. Two option rules are silent.**

- `ern config --peer-dir` without `--config-dir` (§11.3, §11.7) is not covered. The toolchain defaults to `./.ernest` and refuses with `ern config: .ernest: no such file or directory`, which is not §11.7's form.
- §11.2 `--libs-dir` does not say what a directory under `dir` named neither `name` nor `name-version` with dotted digits is: `foo-bar`, `foo-1.0-rc1`. The toolchain accepts `foo`, `foo-bar` and `foo-1.0-rc1` side by side without the refusal of two directories for one application.
- Fix: state both.

**K19. `self` and `Process.current` in an adapted function are covered for one case only.**

- Where: language.md §6.5, new sentence: "`self()` in `f` is the address of the process that owns what `f` opens there".
- It covers the arrival case only. When `f` runs "by the send, in the sender", the owner is unstated; the toolchain gives the sender (`p2/main.ern`).
- `Process.current()` in `f` on arrival is unstated: E.21 names only a wrap's recipient.
- A `monitor` in `f` where the target is on another node delivers to the process kept for the address. What a fault in that wrap does is unstated.
- The soundness paragraph's cases ("a process of the program's of mailbox type `M`, and ... an adapted address's function the runtime runs for it") miss the kept process, whose address `self` then answers.

#### Clarity

**K20. "A function that receives never" reads as a function receiving `Never`.**

- Where: language.md §3.9, Effect polymorphism.
- Quote: "and a function that receives never stands where one that receives nothing is expected".
- What is wrong: in a language with the type `Never`, this reads as "a function receiving `Never` stands where ...", the opposite of the rule. Soundness §6.2 says "the converse is refused", and `p4/t3.ern` is refused.
- Fix: "a function that receives stands nowhere one that receives nothing is expected".

**K21. Rules for typing a function that calls `self` are at odds.**

- §0 and §6.1 say a function that "gives out its address" or "asks for a message to be delivered into it" names the mailbox. §6.1's table reads `(A) -> B` as "receives nothing". §4.5 now types `kill(self())` and `monitor(p, fn(d) = fault("x"))` without the mark.
- The same body as an unbound lambda is refused ("a function that receives where one that receives nothing is needed", `p2/` first version), while a `fn` or a `let`-bound lambda (`p3/`) is accepted. The report states only the `fn` case.
- Fix: one sentence in §6.1 and §4.5 covering both.

**K22. The kill-ordering departure from Erlang is stated in §10 only.**

- Where: language.md §10, which says "a message the killer sends after the `kill` may reach the process before it ends (§6.9)".
- What is wrong: §6.9 does not state this. It departs from Erlang's signal order, so by principle 1 it belongs in §6.9 as a rule.

**K23. `Code.running` treats two like cases differently.**

- Where: language.md §3.11; library.md E.28.
- `Never` is given "for a function that receives nothing, which runs in a process whose mailbox type it does not know". A process-only function (`m+`) runs in such a process just as much, and is refused (`p6/main.ern`).
- Either the reason or the refusal should change.

**K24. The soundness document has gone stale in three places.**

- Its header says the argument is over "their revision of 21 October 2026", but it argues text of 23 and 24 October.
- Its §5 says "every address to the process is made in one of three ways", yet `Code.running` makes addresses on one node and is argued only in §7.
- It keeps history in the argument: "when the mark on sending went", "Nothing in a type now says", "MVP 3.0 runs".

**K25. Library text lags behind the shared load path.**

- G.3's "and so needs it on the load path" no longer applies, since every library is on every load path.
- Appendix D's example module is namespace `Ets`, as is G.1's library, which now stands on every load path. D's example `main` binds to G.1 unless D's root is added.

**K26. Two small wording errors.**

- Appendix F **trace**: "a frame a line written as a spawn site is" is wrong for a host frame (E.21: `lists:nth/2:213`).
- §11.5's example "a type variable of report's signature" reads as a typo. Another function name would do.

#### Kept from an earlier stage

I can see only the report, so these are suspicions, each with its reason.

- **The note frames and "the peer's notes"** in §8.7, the glossary's "a call's two notes", and soundness §3 and §7. The mechanism's prose went, apparently to a design note, and these remain because nothing broke (K4).
- **"The node's gateway"** in E.27, and the "message to a node's runtime" sentence in §8.7. They are what is left of the removed gateway paragraph (K5).
- **G.3's "so needs it on the load path"**, and Appendix D's advice to add a library root while sharing G.1's namespace. Both are from before every library stood on every job's load path (K25).
- **§11.1's "a `Peer.spawn` or `Peer.spawnMonitored`"**, written before compute existed, and its link sentence written before the libraries joined the search (K11).
- **§11.8's "every test passed ... a module that has none"**, written before examples ran as cases (K8).
- **§4.5's "An annotation without `receiving` on a function that receives is a type error"** stands first, while the next sentences carve out `self` and `monitor`. It is the rule from before "process-only for a wait alone", kept and qualified.
- **`Code.running`'s refusal of a process-only function** while it gives `Never` for one that receives nothing (K23). The process-only mark looks like a survival from when a wait was the only way to involve the mailbox. The `m+` that `Supervisor.child` lost in this diff points the same way.
- **`{var, Reference, Supplies, Held}`** in Appendix H, with no prose. It is either a remnant of form version 1 or a node added for ground terms without its sentence (K9).
- **Soundness's history phrases** ("when the mark on sending went", "now", "MVP 3.0") and its 21 October date (K24).

### Reader G


I read the repository at commit 1329d1d2: `report/language.md`, `report/toolchain.md`, `report/library.md` and CLAUDE.md's *Writing*, and nothing else. I edited nothing.

#### How I counted

A section runs from its heading line (`#`, `##` or `###`) to the next heading line of any of those levels, the heading line excluded. A `#` line inside a fenced block is not a heading. Where a chapter or an appendix has text before its first `###`, that text counts as a section of its own, for example §11 before §11.1. An appendix with no `###` is one section: A, B, C, D, F and H.

Words are whitespace-separated tokens, as `wc -w` counts them. The first figure counts everything, fenced grammar, listings and examples included, and decides the 600-word cut. The second figure counts only what lies outside fences.

#### Sections read (36 over 600 words)

- **language.md:** §0 860/860; §3.9 1215/1215; §3.11 770/770; §4.2 907/878; §4.9 958/884; §5.11 710/674; §6.9 1010/1010; §7.4 1073/1073; §8.2 976/976; §8.4 1241/1241; §8.6 756/756; §8.7 5696/5696; §10 888/888; App. A 1133/414; App. F 3553/3553.
- **toolchain.md:** §11 before §11.1 684/684; §11.1 1846/1846; §11.2 7111/7111; §11.4 813/813; §11.5 1548/1548; §11.6 1017/1017; App. H 1964/1828.
- **library.md:** App. D 609/183; E.0 2627/2627; E.1 757/629; E.2 673/116; E.5 782/287; E.17 848/360; E.18 761/590; E.21 673/534; E.22 610/570; E.23 1104/960; E.25 616/364; E.27 1222/962; E.28 607/542; G.2 878/757.
- **Just under the cut, read anyway:** §3.10 559, §4.8 573, §6.5 569, E.26 562.

No finding in §0 (the principles are the report's grounds by design), §4.2, §5.11, E.2, E.18 or G.2. §11.4 and §11.6 had only clauses that state an effect.

#### Defects

**G1. App. F, `frame`: the restated list has drifted.** The gloss reads "a message to an adapted address, a spawn and its answer, a compute, a find, a utilization, a telling, a call's two notes, a node's end, and the exchange's four". That is 14 frames. §8.7 *What passes* counts "Fifteen frames" and includes "a `kill` of a process of another node".
Fix: "- **frame** — a message of the runtime's own between nodes, one of the fifteen §8.7 lists. §8.7."

**G2. App. F, `subscription`: drifted.** The gloss says "to the terminal for its events or to the runtime for its faults". §6.9 adds a third kind, "to the program's end (Appendix E.23)", and the `subscriber` gloss includes it.
Fix: "- **subscription** — a process's standing request to be told of the terminal's events, of faults, or of the program's end, ended when the process dies or restarts. §6.9, §8.2, Appendix E.21, E.23."

**G3. E.0 shape rule 10 requires rationale.** It reads "departs only where its section states the reason". This obliges the report to argue, against *Writing*. §0 principle 1 asks only that the report state "the departure as a rule".
Fix: "..., Ernest takes it, and departs only where its section states the departure."

**G4. §3.11, last paragraph, argues soundness.** It reads "...as payload, which no operation on another node reaches: they are touched only on the node that made it", then "...carries nothing of its type, which is known at both ends and the same at both: every address of another node's process came from a find or a spawn, which compare types by hash, ... So a message between nodes is values only". These are premises leading to "So": an argument, not a rule.
Fix: "No other operation is checked, and nothing is looked through at a send; the values an adapted address's function captured are touched only on the node that made it (§6.5). A value crosses carrying nothing of its type, and needs no code on the node it reaches."

**G5. §8.7 *Connections*, the floor, argues and makes a promise.** It reads "a patch release of `ern` adds nothing and fixes, so two patch levels stand on one floor; a patch changes no type of the standard library's, ... which the floor admits unhashed." The conclusion already follows from the floor's definition, and the rest is a promise with its reason attached.
Fix: "A patch release changes no type of the standard library's, no foreign declaration's type and no form's version."

**G6. §11.1, fifth paragraph, gives advice with its argument.** It reads "a new build goes in a directory of its own: a node reads a definition's form from its `.erc` as a peer first asks for it (§8.7), and a build written over it leaves the node unable to ship a definition it has not shipped before, the spawn failing with `Other`." That is a recommendation and its reason, and the one sentence holds four rules.
Fix: "A node reads its build's units from its build directory at its start alone (§10), and a compiled module after it only through `Code.load` (Appendix E.28). A node reads a definition's form from its `.erc` when a peer first asks for it (§8.7); where the `.erc` has been written over since the node started, the spawn fails with `Other`."

**G7. §8.4 *What the checks do* is a paragraph of purpose.** It reads "The checks catch a foreign side's mistake and confine nothing: foreign code runs within the runtime, and what it does there on purpose is not checked."
Fix: "**What the checks do.** The checks confine nothing: what foreign code does within the runtime, beyond what crosses, is not checked."

**G8. §11.2 justifies its list of the runtime's lines.** It reads "The runtime writes on standard error, unasked, what a program cannot learn and an operator must:".
Fix: "The runtime writes on standard error, unasked: a fault of a process, ..."

**G9. E.27 restates §8.7 paragraph by paragraph.**
- The offer paragraph is nearly verbatim, its purpose clause included: "so that the caller may monitor the holder and offer again at its end".
- The find's order and failures, the spawn's `NotLoaded` and `Other`, and the compute's "two at random", fault, `Other(text)` and kill all appear in both.
- E.27's "A node has no name for itself: work run on the running node is `f()`" repeats §8.7's "A node has no name for itself, and the work a program runs on its own node is `f()`".
- "fault for nothing the network or the peer does" appears in both.

§9 makes §8.7 the owner of these rules.
Fix: E.27 opens with "`offer`, `find`, `spawn`, `spawnMonitored`, `computeAt`, `compute` and `utilization` act as §8.7 states, and answer as the listing gives." It drops those paragraphs and keeps only what §8.7 lacks: the behavior in a program that is no node, the order of failures, `peers` and `name`.

**G10. §7.4 restates causes owned elsewhere, against its own scope.**
- The `callForever` bullet repeats §6.6's seven causes.
- The last two paragraphs repeat §8.2's terminal and standard-input faults, which §7.4's own second paragraph already names.
- `Peer.setUtilization`, `Os.exit` and the working directory restate E.27 and E.23, although §7.4 says "a standard library function's section gives its own". E.23 restates them back.
- The copies have begun to differ: §7.4 writes `Fault("the standard input could not be read: ...")` where §8.2 writes `...: r")`, `r` the host's reason.

Fix: each cause is stated once, in its rule's section.
- The §7.4 bullet becomes "`Address.callForever` whose callee has ended, or ends or restarts before it answers: the cause §6.6 gives."
- §7.4's last two paragraphs go.
- The library causes, with their texts, stand in E.27 and E.23 alone.

**G11. §7.4 and §8.4 both state when foreign values are checked, and the `ok` rule.**
- §7.4 has "A foreign function's return is checked ... when the function returns, and a reply ... when `Address.call` ... returns it ... a function value in it is checked when it is called" and "...the host's atom `ok` is `Unit` (§8.4)".
- §8.4 has "An answer foreign code gives to a call is checked when `Address.call` or `Address.callForever` returns it" and "takes `ok` at its top as a return does (§7.4)".

Each cites the other for the same rule.
Fix: §7.4 keeps the cause texts alone: "A mismatch at a check of §8.4 faults the calling process: `Fault(\"the return of foreign function m:f/n does not match T\")`, ...". Its sentences on when values are checked and on `ok` go.

**G12. §8.7 *Calls* restates §6.6.** It reads "`Address.call` answers `None`, which says that no answer came and nothing of whether the request was received or ran ... The call's time bounds the wait for the answer and nothing before it (§6.6)", and "Where the callee restarts or ends first, the caller is told so and the call ends." "The caller monitors the callee while it waits, so ..." offers the mechanism as a reason.
Fix: "**Calls.** A `Reply` crosses as the host's alias, which takes one answer and drops any other; a loss ends a call as §6.6 says, and where the host's buffer for the peer is full, the caller waits in the send first. A restart in place ends every call whose request came before it, but for a request through an adapted address made on a third node."

**G13. The load limits and the line at four fifths are stated five times.** The places are §8.7 *What it says*, §10 ("so a node sent code without end nears a limit of the host's, said once at four fifths"), §11.2's limits paragraph (the owner), §11.2's reload paragraph ("...when it nears one, as above") and §11.2 *What a node holds*.
Fix:
- §11.2's limits paragraph keeps the rule.
- The reload paragraph's sentence goes.
- *What a node holds* keeps only "a load or an arrival that would pass one fails as one the node cannot load (§8.7)".
- §8.7 becomes "A node that nears a limit of the host's on the code it holds says so (§11.2)."
- §10 becomes "each unit adds to the host's counts of module names, export entries, function entries and atoms, which never fall in the host's life (§11.2)."

**G14. That a `Test.faults` process's fault goes unreported is said three times, twice with its reason.** §11.2's `ern test` paragraph has "is not reported, since the test's answer carries it". §11.2's fault report has "those `Test.faults` started ... excepted". E.24 has "No job reports ..., since the test's answer carries it (§11.2)."
Fix: the exception stays only in §11.2's fault report. E.24 becomes "No job reports a fault of a process `faults` started (§11.2)."

**G15. "One definition" is stated four times.**
- §6.9: "Two functions with one body are one definition (§8.7), and a `spawn` written in either counts as written in the first declared".
- §8.7: "so two functions with one body are one definition".
- App. H: "Two definitions whose forms are one term are one definition: ... the first declared, whose spawn sites (§6.9) its processes carry".
- E.28: "the two being one definition (Appendix H)".

Fix: App. H owns it.
- §8.7 becomes "A function's own name and its positions are not in its hash (Appendix H)."
- §6.9 becomes "A `spawn` written in either of two definitions that are one (Appendix H) counts as written in the first declared."
- E.28 drops its clause.

**G16. "An address of an earlier start is dead" is restated with a purpose clause.** §8.7 *Its start and its end* has "puts in every address, so that an address of an earlier start is dead". §8.7 *Addresses* states the rule. App. F `start number` repeats the purpose clause.
Fix: §8.7 becomes "Each start of a node has a number of its own, which the host draws and puts in every address (**Addresses**)." The gloss becomes "- **start number** — the number the host gives each start of a node, carried in every address of its processes. §8.7."

**G17. What crosses between nodes is stated in seven places.**
- §3.11: external term format; "values only ... needs no code".
- §8.3: "code crosses ... with a spawn and a compute alone".
- §8.4: "Cross-node transport uses the runtime's external term format".
- §8.7 *Messages*: "A value crosses in the runtime's external term format ... not looked into (§3.11)".
- §8.7 *The exchange*: "Code crosses with a spawn and a compute and nowhere else: a find ships nothing, a message ships nothing".
- §8.7's service paragraphs: "a find ships no code".
- §10: "No compiled code crosses between nodes: nodes stand on one floor, ... (§8.7); a definition crosses as its form, ... and a message carries values only (§3.11)". This one argues after the colon.

Fix: the format goes in §8.4, "values only" in §3.11, and "code crosses with a spawn and a compute alone" in §8.7 *The exchange*.
- §8.7 *Messages* becomes "A large value crosses in pieces, and other senders' messages pass between them (§8.4)."
- The service paragraph drops "and a find ships no code".
- §10 becomes "- No compiled code crosses between nodes; a definition crosses as its form (§8.7)."

**G18. §10's last bullet restates §8.7's loss and message rules.** It reads "runs the loss as §8.7 says: one `Down` with `Unreachable` for each monitor ..., each waiting call ended, and what waited to be sent dropped. A message between nodes arrives at most once ... An address outlives a loss ... The runtime sends nothing a second time and retries nothing." "Retries nothing" is also §0 *Time*.
Fix: "- The runtime detects the loss of a connection on both of its nodes, at once where it is closed and within 45 to 75 seconds where it falls silent, and runs the loss, carries messages and keeps addresses as §8.7 says."

**G19. §11.2 and §8.7 each say a shell-typed function has a hash and crosses, each citing the other.** §11.2 has "A function typed at the shell has a hash as any definition has (§8.7), and a spawn or a compute of it ... carries it". §8.7 has the same sentence with "(§11.2)".
Fix: drop the sentence from §8.7.

**G20. "A node reads every module of its load path at its start" is in §11.2 twice and §8.7 once.** §11.2's `--verbose` paragraph has "a node's start reads every module of its load path so (§8.7)", and the next paragraph has "A node reads every module of its load path at its start (§8.7), where a program loads one on demand."
Fix: drop the second §11.2 sentence.

**G21. Facts about what makes a node are restated widely.**
- "A program started without `--config-dir` is no node" appears in §8.3, §8.7 (second paragraph), §11 ("a program is a node only where `--config-dir` says so"), §11.2 ("and without it the program is no node") and §11.3.
- "Hangup is a reload" appears in §8.6, §8.7 *A reload* and §11.

Fix: §8.3 keeps the first and §8.6 the second; the other places drop them. §8.7 *A reload* opens with "`ern reload --config-dir dir` sends the node named by `ernest.pid` the hangup signal ...".

**G22. §3.9 and §3.11 state the same refusal, each citing the other.** §3.9 has "A `Peer.spawn`, ... whose function captured a value whose type holds a type variable is refused (§3.11)". §3.9's paragraph is about where inference asks for an annotation, which this is not.
Fix: drop the sentence from §3.9.

**G23. §8.5 and §8.7 both say when a node listens.** §8.5 has "A node (§8.3) runs its initializers so, and listens to its peers only once all have their values (§8.7)." §8.7 has "A node runs its initializers as a program does (§8.5), and listens and dials only once they all have their values, so that ... and so does a carrier that cannot start ... with the cause §7.4 gives". The last part repeats §7.4.
Fix: §8.7 becomes "A node listens and dials only once its initializers have their values (§8.5): a find, a spawn, a compute or a utilization in an initializer answers `Unreachable`."

**G24. E.1 restates §4.8 and §4.9 as an assurance of principle 5.** E.1 has "Neither takes an argument the program has not declared: on a known type none, and under a requirement what it names, which a call supplies without writing it (§4.9)." §4.8 says nearly the same, and §4.9 has "A call writes nothing for a requirement." E.1's "A type variable no requirement names `show` for is a type error" restates §4.9.
Fix: drop both E.1 sentences. The preceding sentence ("supplied there as any requirement is (§4.9)") covers them.

**G25. E.25 restates §3.10's promise.** E.25 has "The element type's `compare` is the program's promise: an order (§3.10) ... Nothing checks it." §3.10 already says "...the laws are the program's promise, and nothing checks them."
Fix: "The program promises that the element type's `compare` is an order (§3.10) that says `Equal` only where `==` holds, where the type has `==`."

**G26. §8.7 restates itself.**
- *Messages* has "...send the same way, so that everything one process sends keeps its order", and the next paragraph states that order.
- The find has "Where a service lives is the configuration's: ... two peers that offer one service are asked in the list's order", which repeats *Its configuration* and the find's first sentence.

Fix: "A call, a find, a spawn, a compute, a utilization and an `answer` send the same way." The "Where a service lives" sentence goes.

**G27. App. H says twice that the form's version is part of the floor, and argues from it twice.** It reads "the form's version is part of the floor, so two nodes that connect hash alike", and then "it is part of the floor (§8.7), so it moves with a minor release at the earliest".
Fix: the second paragraph ends at "compiles it from the form". *The version* reads "The form's version is 2, and is part of the floor (§8.7). It moves with the release in which anything that runs before hashing changed: ...".

**G28. §11.1 and §11.2 restate the recompilation rule.**
- §11.1 has "so a dependent is recompiled where such a position has moved" and "...where such a value has changed". Both repeat its own "recompiled when ... the interface of a module it depends on has changed".
- §11.2 `:reload` has "compiles again ... as `ern build` would (§11.1): one that uses a module whose interface the reload changes, and one whose forms reference a definition whose hash it changes."

Fix: drop the two §11.1 clauses. §11.2 reads "It compiles again a loaded module where `ern build` would recompile it (§11.1)."

**G29. §11.5 restates §3.9 and §4.7.** It reads "One that occurs in a value position is never none, and is not marked" and "`=` is written in a foreign declaration alone, on a foreign type's parameter or in a foreign function's parameters (§4.7)."
Fix: "A process-only effect variable that occurs in a value position is not marked: `self : () -> Address(m) receiving m`. A printed type is not an annotation, and no mark can be written in one (§4.7)."

**G30. App. A and §3 both decide `FnType` against `ParenType`, and the `=` mark.** §3 has "...a `->` after its `)` makes it an `FnType`; otherwise it is a `ParenType`". App. A has "A parenthesized list of types is an `FnType` when `->` follows its `)`, and otherwise a `ParenType` (§3)."
Fix: App. A keeps it. §3 reads "A parenthesized list of types is decided as Appendix A says, and a `ParenType` holds exactly one `Type`; the `=` mark is §3.10's equality constraint, written in a foreign function's parameters alone (§4.7)."

**G31. Smaller restatements.**
- §6.9 "a window below 1 is 1, and a count is corrected as §7.4 says". Fix: "a window and a count are corrected as §7.4 says."
- §6.9 "A monitor is the one link ...; a resource ends with its owner, and the caller of `callForever` with its callee." Fix: "A monitor is the one link a program makes between two processes."
- §8.7 *What passes*, "one to an adapted address made on another node ... takes §6.5's one step more, ... in the process kept for the address and the sending node (§6.5)". Fix: "A message between nodes costs what the host's send costs (§10)."
- §11.2 "`ern shell --config-dir dir` with no `.erc` is a bare node with a prompt, which dials from its prompt and is not refused without `listen`; a bare node whose `ernest.conf` has no `listen` is refused." Fix: "`ern shell --config-dir dir` with no `.erc` is a bare node with a prompt (§8.7)."

**G32. Reason clauses: "since", or a reason after a colon. The fix drops each.**
- (a) §3.9 "waits on the mailbox all the same, so the function around it ... is *process-only*". Fix: "A function whose body holds a `receive` that reads no type from its process's mailbox, one with an `after` clause alone or one whose patterns are wildcards or variables that nothing fixes, is *process-only* where nothing else fixes its mailbox type: ..."
- (b) §3.11 "Any other expression is refused, ... since its captures are not in its type." Fix: end the sentence at "from a call among them".
- (c) §3.11 "holding no type variable, since every process listed has it as its mailbox type, or `Never` for a function that receives nothing, which runs in a process whose mailbox type it does not know (§6.2)". Fix: "holding no type variable, or `Never` for a function that receives nothing (§6.2)".
- (d) §8.4 "A message from a peer is not checked on arrival: its type is known at both ends and the same at both (§3.11), and ...". Fix: "A message from a peer is not checked on arrival; a value of another type a faulty peer sends is met where the receiving process matches on it (§8.7)."
- (e) §8.4 "the atom `ok`, which the host's functions answer for nothing, is `Unit`". Fix: drop the relative clause.
- (f) §8.4 "...is not checked: a foreign function without `receiving` promises to deliver none (§4.7)". Fix: "crosses nothing and is not checked (§4.7)".
- (g) §8.6 "is not waiting, since the foreign side may still deliver to it". Fix: "A process inside foreign code (§8.4) is not waiting; the runtime reads that from the process, and no foreign call declares it."
- (h) §8.6 "A node (§8.3) detects no deadlock: it can be reached from outside, ...". Fix: "A node (§8.3) detects no deadlock."
- (i) §8.7 `measures`, "since the host's memory measure counts minutes where its disk measure takes any interval". Fix: "for `memory` a multiple of 60000".
- (j) §8.7 bare node, "refused at its start, since it never dials; the shell's, which dials from its prompt (§11.2), is not". Fix: "refused at its start, but for the shell's (§11.2)".
- (k) §8.7 exchange, "and answers nothing, since the spawner's own wait has ended". Fix: "and answers nothing".
- (l) §8.7 "crosses whole in one code frame, since its members are hashed as one (Appendix H)". Fix: "A mutually recursive group crosses whole in one code frame (Appendix H)."
- (m) §8.7 "linked on the peer to a fault that names it, which no process reaches, since a spawn whose reach names it is answered `NotLoaded` before it starts". Fix: "is linked on the peer to a fault that names it".
- (n) §8.7 compute, "(§7.3), since no caller waits for it". Fix: end at "(§7.3)".
- (o) §8.7 loss, "so a silence is found between 45 and 75 seconds ..., since the silence begins anywhere in an interval". Fix: "a silence is found between 45 and 75 seconds after the last traffic, as the host states it".
- (p) §8.7 service, "A peer cannot name another node's binding, so a service ...". Fix: "A service that peers are to reach is offered as a `Peer.Service(m)`".
- (q) §11.1 "since a unit's functions are named by their position and an Ernest function is called by its name". Fix: end at "a module `ern@` and a path".
- (r) §11.2 "on a node a test that waits forever is not found, since a node detects no deadlock (§8.6)". Fix: "on a node a test that waits forever is not found (§8.6)".
- (s) §11.2 "`, spawned by the peer desk`, since the site is the spawner's and names a file of another build". Fix: drop the since-clause.
- (t) §11.2 "written before the next prompt, since the shell reads a line whole". Fix: drop the since-clause.
- (u) E.23 "has no `close`, since nothing of it is left half open as a socket's far end is". Fix: "A program ends by its own exit or by `kill`, and has no `close`."
- (v) E.27 "is not bound, since the value crosses back, for `computeAt` as for `compute` (§3.11)". Fix: "and its result type is as §3.11 says".
- (w) App. H *What is left out*, "the annotations, since a function's scheme and a binding's hold their types, and ...". Fix: "the annotations".
- (x) App. H opening, "The term holds no map, so its bytes follow from the format's rules ...". Fix: "The term holds no map."
- (y) App. D "No operation names a mailbox type, since none receives (E.0 shape rule 5)." Fix: "No operation names a mailbox type (E.0 shape rule 5)."

**G33. Purpose clauses: "so that".**
- (a) §8.7, the end: "the node stops in order, so that every `Down` already on its way crosses ..., so that the peer says it ended and not that it was lost". Fix: "the node stops in order: every `Down` already on its way crosses before its connections close, and the node tells each connected peer that it ends, a frame of its own, which the peer says as an end and not a loss."
- (b) §8.7 and E.27 "so that the caller may monitor the holder and offer again at its end". Fix: drop it in both.
- (c) E.27 "a peer not heard from left out, so that a program writes a rule of its own over them". Fix: end at "left out".
- (d) §10 "A call's wait reads the caller's mailbox, so that a restart asked for is taken there (§6.9)". Fix: "A call's wait reads the caller's mailbox, where a restart asked for is taken (§6.9), and its cost grows with the messages waiting."
- (e) §11.1 "by their position in it, so that a unit adds one name to the host's". Fix: "A unit names its functions by their position in it, and adds one name to the host's, its own (§10)".
- (f) §11.1 "exports every binding's getter, so that a received definition (§8.7) reads ...". Fix: "exports every binding's getter, through which a received definition (§8.7) reads a binding of its module".
- (g) §11.2 `ern stop`, "so that no signal reaches a process whose number the file names by chance". Fix: drop it.
- (h) §11.2 `:load`, "so that what a binding opens stays open as it does under `ern run`". Fix: replace "so that" with a semicolon.
- (i) §11.2 *What a node holds*, "so that the node ships a definition onward as its own, ...". Fix: replace "so that" with a semicolon.
- (j) §11.2 load path, "a root each, so that a program names none of them". Fix: "a root each; a program names none of them".
- (k) E.0 rule 1 "so that a program runs at the host's speed wherever the host does the work". Fix: drop it.
- (l) E.0 rule 3 "or its section states it whole so that a program can make another". Fix: "or its section states it whole".
- (m) E.0 shape rule 6 "..., so that the page is read without the report." Fix: "It states a fact before it cites the report for it."
- (n) E.22 "once each of them has restarted or ended, so that a call to it after its fault is answered by the group restarted whole". Fix: "...or ended; a call to it after its fault is answered by the group restarted whole".
- (o) App. H *Supplies*, "so that two bodies that print differently hash differently". Fix: drop it.

**G34. Sentences that teach a use instead of stating a rule.**
- (a) E.17 "a program that is to keep a whole file or none writes beside it and renames over it." Fix: drop it.
- (b) E.22 "and between nodes a process watches another with `monitor`." Fix: drop it.
- (c) §8.7 "a program that is to go on watching calls `monitor` again, on the process the `Down` names". Fix: "A monitor does not outlive a loss: the loss gave its `Down`. A monitor made while the process's node is out of reach or not listed gives its `Down` with `Unreachable` once the dial has failed."
- (d) §8.7 "Which peer a program gives its work is the program's to say, by a name, or by the utilizations its node holds." Fix: drop it.
- (e) §8.7 and E.27 "the work a program runs on its own node is `f()`". Fix: "A node has no name for itself." in §8.7, and drop the sentence from E.27.
- (f) E.25 "A set carried into another representation goes through that representation's `fromList` of its `toList`." Fix: drop it.
- (g) E.28 "A program moves the processes it lists by its own send to each, as §6.10 moves ...". Fix: drop it.
- (h) E.23 `termination`, "which answers the reply once it has written what it keeps". Fix: "at the end the runtime delivers `wrap(reply)` to the process, and the end waits as §8.6 says."
- (i) E.21 listing, "`Process.current` ... // the running process, for a function that needs its identity and not its mailbox". Fix: "// the running process, or a wrap's recipient".
- (j) §4.9 "Code written once over several representations of a type takes an *operations record*: ...". This is an idiom, not a rule. Fix: "An *operations record* is a record a program declares of the operations it uses on a type, filled from each representation's namespace (§5.6) and passed as an argument."

**G35. E.5 gives a contract rule as a consequence of how the module is written.** It reads "The rest is Ernest over them, so every search matches whole graphemes:".
Fix: "The rest is Ernest over them. Every search matches whole graphemes: `String.contains(\"e\\u{301}\", \"e\")` is `false`, ..."

#### Clarity

**G36. App. H points the wrong way.** It reads "is in the form of the function that shows it (above)". The rule is stated below, under *Supplies*.
Fix: "... in the form of the function that shows it (**Supplies**)."

**G37. §3.11 holds `Code.running`'s typing rule, which is not about serialization.** E.28 and its listing state the rule again.
Fix: §3.11 keeps "`Code.running` is called where it is named (Appendix E.28)", and the typing rule stands in E.28 alone.

**G38. §8.7 `utilization` has an obscure phrase:** "the processes running or ready to run, the one that measures left out".
Fix: "the processes running or ready to run, the measuring process left out, over the number of schedulers".

**G39. §8.7 has an obscure sentence:** "a peer told so by a node after its word takes the node to go on, and the close of its connection for a loss."
Fix: "A peer that hears a telling from a node after the node said it ends takes the node to go on, and the close of its connection for a loss."

**G40. §8.7 has a sentence under the wrong heading.** "A node reads every module of its load path at its start, and is refused where ..." stands under *Connections*.
Fix: move it to *Its start and its end*.

**G41. E.0 rule 1 binds the library to a document outside the report.** It reads "only where that Ernest measurably costs, with the numbers in the decisions log".
Fix: "only where that Ernest measurably costs, or where Ernest cannot close it: ...".

#### Seen in passing, under 600 words (outside the brief)

- **§4.8, last paragraph.** It restates the section's own third paragraph and §4.9 ("It carries no argument the program has not declared ..."), and has "since each is generalized (§3.9, §4.6)".
- **§4.5.** "it is an error, since the function receives nothing and `: T` is its one annotation".
- **§4.7, third paragraph.** It restates §3.9's "Where there is no body, a restriction is given instead".
- **§6.10, paragraphs 2 to 4.** A how-to told through "so ... so": "A function does not cross nodes as a value (§3.11), so a process on another node is sent its `Upgrade` by ..." and "A type that carries `Upgrade` ... is bound to its node (§3.11), so a process reached from another node ... is offered through an adapted address".
- **E.19.** A history note, not a rule: "The module `Erl` went into Appendix E.12 on 9 October 2026".
- **E.24.** "so that a test may receive as an entry point may (§8.1)".
- **G.1.** "since none receives".
- **Appendix E's opening.** "so that the marks are part of its contract".
- **§9's opening.** "how common an operation is puts it nowhere" restates §0 principle 5.
- **§8.6, for another reader rather than the register.** "Whether a user-provided foreign process counts like a system process here is the runtime's choice" leaves a semantic choice unstated.

### Reader U


I found 18 defects: 2 are false outright and 16 are wrong, stale or out of place. There are also 14 matters of clarity, 6 suspected leftovers and 2 places where the language got in the way.

What I read: all of `guide/` (`language.md`, `why.md`, `faq.md`, `deployment.md`, `style.md`, `README.md`). I checked it against the three report files, `src/stdlib/`, the node lines in `erl/`, `examples/` and the gap table in `docs/development.md`. I ran programs under `t1` to `t7` in this directory with `bin/ern`.

#### Defects: false or stale statements, facts outside their owner, jobs taught two ways

**U1. `why.md` says a deadlock is found in the shell. The report says it is not, and the shell does not find it.**
- Where: `guide/why.md:15`, "under `ern run`, `ern test` and the shell". `guide/why.md:300`, "and in the shell (report §8.6, §11.2)".
- What is wrong: report §11.2 says "A deadlock is not detected while a shell holds the terminal". It also says the terminal is the shell's "at a terminal and in line mode alike", so the shell always holds it.
- Shown by: t7, `dead.ern` with the entry point renamed to `start`. `:load Dead` then `Dead.start()` reported nothing in 12 seconds. The same program under `ern run` faulted with `deadlock` in 0.48 s.
- Fix: drop "and the shell" in both places, and cite §11.2's exception.

**U2. Guide §9.3 says a find gives the old service's address after a reload. It cannot.**
- Where: `guide/language.md:3062`, "`kill(old)`, `old` the old one's address, which a find of the service gives".
- What is wrong: the old and the new service both run on the shell's own node. `Peer.find` asks only the peers that `ernest.conf` lists (E.27, §8.7). A node is no peer of itself, and a configuration that lists its own key is refused. So no find answers the node's own offer.
- `Peer.offer`'s `Left(holder)` is a `Process`, and `kill` does not take one.
- Fix: "`old` the old one's address, which a binding made before the reload holds".

**U3. Deployment §6 says `Process.status(p)` names the site of a process the list gave. At the shell it answers `None`.**
- Where: `guide/deployment.md:283`, "`Process.status(p)` on a process the list gave names the site it was spawned at". Also `deployment.md:354`, "whose `Process.status` names its site in `Counter.serve`".
- What is wrong: the processes come from `Peer.computeAt("b", fn() = Process.live(), 5000)`, so they are b's. E.21 says `status` answers `None` "for one on another node".
- Shown by: t5, `look.ern`, two real nodes. A local `Process.status(p)` printed `None` for both of foo's processes. `Peer.computeAt("foo", fn() = Process.status(p), 5000)` printed `Right(Some(Status(site = "bare node", ...)))` for one of them.
- Fix: show `Peer.computeAt("b", fn() = Process.status(p), 5000)`.

**U4. Deployment §7, "What a node says", leaves out lines the runtime writes.**
- Missing lines:
  - `the peer b sent a frame this node cannot read, and its connection was ended`, from `ern_gateway:outcome/2` (report §8.7).
  - `the peer a's spawn at Site was not loaded: its time ran out before the function's reach arrived`, from `ern_exchange` `?TIMED_OUT` (§8.7, The exchange).
  - The compute form of every "not loaded" line, `the peer a's compute at Site ...`.
  - The end's other lines (§11.2): `the end waits for X too`, `the subscriber X answered`, `ended without answering`, `restarted without answering`, `is no longer waited for`, and `the end was cut short, N subscriber unanswered: ...`.
  - The line for a dial refused for its address family (§8.7).
- §4.3's list also lacks the time-out line.
- Fix: add the rows, or say that the table is a selection and name §8.7 and §11.2 as the whole.

**U5. Three documents count `why.md`'s claims three ways.**
- Where:
  - `guide/README.md:8`: "six claims, five of them with a program and its output".
  - `guide/language.md:34` and `:92`: "six claims, the first four with a program".
  - `guide/why.md:3`: "four of them with a program and one with its file".
- What is wrong: claim 3, the WAN, has a JSON file and no program. Claim 5, the deadlock, has a program and its output. So `README.md` is wrong, and `language.md` is wrong twice.
- Ownership: `guide/README.md` owns what each guide is, per CLAUDE.md's owner table. `language.md` restates the count outside its owner.
- Fix: `README.md` "four with a program, one with its file". `language.md` names `why.md` and drops the count.

**U6. The guide's §14 says the snake game has "one process per player". It has one value.**
- Where: `guide/language.md:3168`.
- What is wrong: `examples/snake.ern`'s header says "The whole game is one value, `World`". Its one `spawn`, at line 81, is the terminal's subscriber. `examples/README.md`'s table says "a world that is one value".
- §14 restates that table's descriptions for four programs, and the copy has drifted.
- Fix: point at `examples/README.md` and drop the descriptions, or correct snake's.

**U7. Six cross-references point at the wrong section.**
- `language.md:872` and `:1581`, "(§8.3)" for a node out of reach. The guide's §8.3 is foreign types; the loss is §8.2, *A loss*.
- `language.md:1031`, "`Process.status` (§5.3)". `Process.status` is taught in §5.2; §5.3 is `kill`.
- `language.md:1389`, "(report §6.5, §8.2)" for where an adapted address's function is applied from another node. Report §8.2 is system references; the rule is §8.7's.
- `language.md:2705`, "as a socket is given to one (§9.3)". The guide's §9.3 says nothing of sockets. The rule is report §11.2, *Inputs*, and the guide teaches `Tcp.give` in §8.7.
- `faq.md:17`, "what a process opened ends with it (the guide's §6.4)". §6.4 is "Let it crash". Ownership is taught in §8.7 and stated in report §6.9.

**U8. `guide/style.md` says `ern format` takes no option.**
- Where: `guide/style.md:7`, "`ern format` writes one layout and takes no option (report §11.6)".
- What is wrong: it takes `--check` and `--short-errors`, and `-`, and the same paragraph uses `ern format --check src`. Report §11.6 says "The layout has no options".
- Fix: "writes one layout, which has no options".

**U9. `guide/style.md` names eight shape rules and lists six.**
- Where: `guide/style.md:11`, "shape rules 1 to 5, 7, 9 and 10 bind a library ... :".
- What is wrong: the list after the colon gives rules 1, 2, 3, 4, 9 and 10. It leaves out rule 5, that a type names a mailbox only where the function's own mailbox is involved. It also leaves out rule 7, that an exported type is listed and named for what it is, never for its module.
- Fix: add the two.

**U10. `why.md` calls a socket and a running program system processes.**
- Where: `guide/why.md:329`, "a timer, a socket, a file and a running program are system processes that count what they hold".
- What is wrong: E.18 says "Sockets and listeners are foreign processes (§8.4) but not system processes". E.23 makes a running program a process "as a `Tcp` socket is". §8.6 names "system process, listener or socket" apart.
- Fix: say the clock, the file system, TCP and Os are system processes, and a socket and a running program are processes of the runtime, each counting what it holds.

**U11. `why.md` says every module's bindings are evaluated before `main`.**
- Where: `guide/why.md:57`, "every top-level binding of every module evaluated in dependency order (report §8.5)".
- What is wrong: §8.5 evaluates the standard library and the modules the entry point's module depends on. It says "another module the program does not depend on is not initialized".
- Fix: "of the standard library and of every module the program uses".

**U12. Guide §4.5 says a hangup ends a program. On a node it is a reload.**
- Where: `guide/language.md:1071`, "A program stopped from outside by a termination or a hangup signal ends the same way".
- What is wrong: §8.6 and §8.7 say that for a node a hangup is a reload, and the end tells subscribers first.
- Fix: "a termination, and a hangup where the program is no node, ends it the same way, its subscribers told first".

**U13. Guide §8.4 says every remote address came from a find or a spawn.**
- Where: `guide/language.md:2737`.
- What is wrong: a compute's value can be an address. The tour's chapter 6 does exactly this: `Peer.computeAt("foo", fn() = Counter.start(), 5000)` gives an `Address(Counter.ClientMsg)`. An address also arrives in a message, and the guide's own next sentence lists the compute's checks.
- Report §3.11 has the same omission. That belongs to the report's reader.
- Fix: "from a find, a spawn or a compute, or in a message".

**U14. Plan facts restated in the installed guide.**
- Where: `guide/faq.md:93`, "a shell attached to a running node is planned (the plan's MVP 4.0)". `guide/deployment.md:287`, "What a shell cannot do yet is attach ...".
- What is wrong: `docs/development.md:338`'s gap table owns this, and the plan owns when. The FAQ ships in `share/doc/ernest`, where "the plan's MVP 4.0" is plain text no installation can follow. When the milestone moves, both go stale silently.
- Fix: say what the shell does today, and drop the milestone and "yet".

**U15. `why.md` restates the runtime design note's costs, in Erlang's words.**
- Where: `guide/why.md:333`.
- What is wrong:
  - "costs what the host's call costs and a `try`" uses an Erlang word. The guide's §10 tells the same reader "There are no exceptions, no `catch`, and no `try`".
  - "a mark a process leaves ... as it enters foreign code through a callback, a timed receive or a call" garbles the three marks, `FOREIGN`, `TIMED` and `CALL`, into three ways of entering foreign code.
- Ownership: the costs are `docs/design/runtime.md`'s.
- Fix: one sentence that cites the note, without the `try`.

**U16. One job taught two ways: making nodes on one machine.**
- Where: `guide/deployment.md:327` to `:335`.
- What is wrong: §8 makes `b` and `c` with the default `listen`, then sets their ports and lists the peers by editing the files. §2.1 (`deployment.md:127`) and the language guide's §8.1 teach `ern config --listen` and `--peer-dir` for the same job.
- Fix: §8 uses `--listen` and `--peer-dir`. It edits only what those cannot write: `b` and `c` listing `a` and `ops` without an address, and `ops` without `listen`.

**U17. Guide §8.2 says the store and the desk hold the library the board needs.**
- Where: `guide/language.md:2703`, "so the store and the desk hold the library `board.erc` needs with no flag".
- What is wrong: G.7's proxy is spawned on the caller's node and ends with its caller. Only the board's node needs `libs/proxy`, and the guide never says which node the board runs on.
- Fix: "the board's node holds the library with no flag".

**U18. Deployment §6 loads the program's module at the operator's shell without saying what a load runs.**
- Where: `guide/deployment.md:259` to `:266`, `:load Counter` at the operator's shell. The reason given is only that a file's `main` is not wanted.
- What is wrong: `:load` evaluates the module's top-level bindings and its dependencies' (§11.2; the guide's own §9.3). A program module with a service binding or an offer, as the language guide's §8.2 store has, then starts a second service on the operator's node.
- Fix: say so, and load a module that declares the types alone.

#### Matters of clarity

**C1.** `language.md:92` says "the five principles the guide ends with (§11)". §12 to §14 follow §11.

**C2.** `guide/README.md:3` says "five documents for three readers". Its own table names five readers.

**C3. Two names for an `Io.Error`, and other names `guide/style.md` refuses.**
- `Left(failure)` stands in `language.md` §8.1, §8.2's desk and `why.md`. `Left(error)` stands in §1.3, §8.2's store and §8.7.
- Other names the glossary refuses stand in guide blocks:
  - `m` for a map, §2.5.
  - `t` for a tally's address, §4.7.
  - `p` for a process, §5.2.
  - `n` for a count, §2.10.
  - Events not in the past tense: `Tick`, `Input`, `Wake`, `Last` and `Credit`.
- `docs/style.md` says the guide's blocks follow `guide/style.md`'s names, so naming is taught two ways.

**C4. `guide/style.md`'s own rules have unstated exceptions.**
- It says "`e` for an effect", while E.11 and `List.tryMap` and `tryFold` use `e` for `Either`'s error and `x` for the effect.
- "**ms** (E.23)" cites `Os`. The rule is E.0 shape rule 8.
- The example `Key(Terminal.Event)` sits beside Terminal's own `Key(Char)`.

**C5. Programs and modules share names.**
- §5.2 and §6.4 both build `jobs.erc`, and §5.7(b) means §5.2's.
- §8.2 and §8.5 are both a module `Store` in `store.ern`.
- A reader building along overwrites one with the other.

**C6. Deployment §1.2's refusal list is partial.**
- It leaves out a service naming an unlisted peer, the commonest slip, a bad `utilization` or `utilization-interval`, a duplicate service, a number too large, and a `public-key` that is not the private key's.
- On address families, it leaves out "IPv4 where it has no listener" and the family check at each dial.
- It cites "(report Appendix F)" for "listen", which Appendix F does not hold.

**C7. The deployment guide's measured numbers carry no date and no owner.**
- The numbers: §3.2's 1.2 packets a second, §3.4's 250 and 650 ms, §4.1's 7/9/23 and 17/27/72 ms, §4.2's 260 days and 416 upgrades, and §6's "close to a second" and "a few hundred µs". `why.md` adds "nanoseconds".
- None names a date or a log entry, and no test holds any of them, so they go stale silently.

**C8. The guide quotes `src/stdlib/ordered_set.ern`, which an installation does not ship.**
- §7.3's quotation of the file is held by no test, though it matches today.
- An installation has no `src/stdlib`, so "the rest of the module is in the file" names a file the installed reader lacks.

**C9.** `why.md`'s reload transcript does not show how the session began. Its numbering, `input 4`, implies `ern shell counter.erc`; a counted `:load` makes it `input 5` (t3).

**C10.** `language.md:2311`: "each service's name lists the peers that may offer it, hold a process under that name for peers to find" is garbled.

**C11.** `language.md:323`: "though not receive". §4.6 allows an `after`-only `receive` in an initializer.

**C12.** `language.md:2695`: "where a second `ern stop` cuts the wait short", said "for a node and for a program that is none alike". `ern stop` takes only a node.

**C13.** `faq.md:31`: "since October 2025" is a dated external fact that no document owns.

**C14. The guide tells the reader to wait a fixed time where the node gives no signal.**
- `language.md:2376`: "give it a moment to listen, about a second".
- A node with a fixed port says nothing when it listens (deployment §8: "Each says nothing until a peer connects").
- That gap belongs in the plan, not in a fixed wait in the guide.

#### Suspected leftovers of an earlier stage

**V1. Guide §12 is a one-line pointer to `faq.md`.**
- The FAQ evidently lived in §12, and the heading stays to hold its number.
- The intro already links `faq.md`, and `:94` still lists §12.

**V2. The pacing example annotates a lambda that needs no annotation.**
- Where: §4.4, `language.md:1020`, `spawn(fn() : Unit receiving ProducerMsg = produce(...))`.
- Shown by: t6. Without the annotation it compiles and prints `sum 5050`.
- It is the guide's only lambda annotated with `receiving`, and nothing explains it. I suspect an older rule that fixed a spawned lambda's mailbox only by annotation.

**V3.** §8.2's "the store and the desk hold the library `board.erc` needs" (U17). I suspect a stage when a library had to be on the peer, or named with `--load-path`.

**V4. "With no flag" reassurances.**
- They stand in §8.2, §8.5, §9.1 and §9.2. Appendix D still opens on `--load-path`.
- I suspect a stage when the toolchain's libraries needed the flag.

**V5. The §1.4 prediction exercise.**
- (a) and (b) give the same type, and the answer is that nothing differs.
- I suspect it dates from when sending to standard output's process touched `main`'s type, an earlier `Sys` threading. Low confidence.

**V6.** §0's "the principles the guide ends with" (C1). I suspect it dates from when §11 was last.

#### Where the language made the work harder

**L1. `Process.status` answers `None` for another node's process, with no sign of which kind of `None`.**
- `None` is the same answer as for an ended process (t5). E.21 says a `Process` "names its node", but nothing reads the node.
- A program cannot tell "ended" from "elsewhere" without a `Peer.computeAt`, and that answer mixes the compute's own ended process with live ones.

**L2. At the shell, a held service cannot be ended from the `Process` its holder gives.**
- Found while checking U2. `Peer.offer`'s `Left(holder)` is a `Process`, which `monitor` takes and `kill` refuses.
- A service waiting on an old version's holder can be moved only through an address kept before the reload.

#### Checked and found right

- The §1.4 answer: `receive { after 10 -> Unit }` under `: Unit` is refused, and compiles bare or under `receiving m` (t1).
- The §8.8 answer's diagnostic, word for word, and its spawn (t2).
- `why.md`'s reload transcript, all but its input count (t3).
- `pause : (Int) -> Unit receiving e+`, `:browse Fs` and `:doc Fs.Entry`.
- The FAQ's `this clause can never match` and its `adapted(counter, fn(Tick) = Inc(1))` example (t4).
- `why.md`'s foreign-return fault text.
- The refusal lines quoted by the guide:
  - a node's own key as a peer's;
  - two peers with one key;
  - `ern config` on an existing directory;
  - `ern run` on a held `ernest.pid`;
  - `ern stop` with `no such file`, and with `no node holds it` after a `kill -9`.
- The node lines the deployment guide's §7 does list, found in `ern_carrier`.

### Reader N


The program's source is in this directory as `dinner.ern`. Repository at 1329d1d2. I read `README.md`, `guide/language.md`, `guide/why.md` and `guide/faq.md`, in that order, and nothing else. I ran every exercise, then wrote one program.

#### The program

`dinner.ern` is the dining philosophers, three ways, in 362 lines.

- A fork and the waiter are one process type, a *guard*. A guard is a counting semaphore: callers wait on a `Reply` in a queue, and it monitors the processes that hold it, so one that ends lets go.
- Each philosopher is a process spawned with `spawnMonitored`. It thinks and eats by timed waits, with random times from `Random`.
- The table, `main`, keeps a ledger through an `adapted` address and answers calls. It kills everyone at a `Clock.alarm` deadline (`--patience`). A clumsy philosopher faults under `restarting`.

**It ran.**

- `ordered` and `waiter`, with any `--seats` and `--meals`, finish and print a summary.
- `naive` ends within half a second in `Dinner.main faulted: deadlock`, exit status 1.
- `naive --patience 500` kills every philosopher and reports.
- `--clumsy` restarts the philosopher. Past the restart limit it gives up, the monitors free its forks, and the others finish.
- `ern format --check` passes.

The other files in my scratch directory:

- `ex/` holds the exercises and the small checks cited below.
- `exp/dinner.ern` is the dinner with the restart handling taken out (N21).

**The exercises.** Every one's answer in §13 matched what the compiler and runtime did: §1.4, §2.11, §3.7, §4.8 (b) and (c), §6.7, §7.4 (c) and §8.8.

#### The documents

**N1. faq.md:35 says there is no selective receive. The guide teaches it.**
- The FAQ, "Why one mailbox per process": "there is no selective receive, and a loop takes the next message of its type, whatever it is."
- The guide says the opposite three times. §4.3 is titled "Selective receive and `after`": "`receive` takes the first message that matches a clause and leaves the others in the mailbox". §10 says "`receive` selects a message by pattern and leaves the others in the mailbox". §13's answer to §4.8 (c) depends on it.
- What runs agrees with the guide. In `ex/sel.ern`, a `Wake` sent before a `Data` is passed over by a `receive` for `Data` and taken by a later one; it prints `Some(3)`, then `true`.
- Fix: delete the clause, or say what is meant, perhaps that there is no second mailbox to receive from.

**N2. The number of claims with a program differs in three places, and two of them are wrong.**
- README.md:15 says "six claims ... the first five with a program".
- language.md:34 and :92 say "six claims, the first four with a program".
- why.md:3 says "four of them with a program and one with its file".
- In why.md, claims 1, 2, 4 and 5 have a program, claim 3 has a file, and claim 6 has neither. So why.md is right; the README and the guide are not.
- Fix: use why.md's wording in all three places.

**N3. The guide never shows how to annotate a function that only waits a while.**
- §3.5 (language.md:731) prints `pause : (Int) -> Unit receiving e+`. But §2.9 says the one mark a program writes is `=`, and writing `receiving e+` is refused: `expected = instead of +`.
- §4.3 calls the timed wait "the one `receive` a process with mailbox `Never` may use". §13's answer to §1.4 (language.md:3132) says such a `main` "would need `receiving` in (b)" without saying receiving what. The compiler's help says only "give main its mailbox type with `receiving`".
- So the natural guess is `receiving Never`. It compiles, and then the helper cannot be called from any process that has a mailbox: `pause2 needs mailbox Never, and the mailbox here is M`.
- The annotation that works, `receiving e`, I found by trying. It is needed again on every caller: in the dinner, `run`, `dine` and `pause` all carry it.
- Fix: give the annotated form in §3.5, `fn pause(ms : Int) : Unit receiving e = receive { after ms -> Unit }`, and the same words in the compiler's help.

**N4. The deadlock claim leans on words the reader is never given, and on a count with nothing it counts.**
- README.md:21 and why.md:15 both say "a program at work pays nanoseconds for the question". Nanoseconds per what: per receive, per call, per foreign call? And in the README, "the question" points back at nothing.
- why.md:331 says "the look may be late but is never wrong". "The look" is defined nowhere.
- why.md:333 explains the cost in the runtime's own terms: "a mark a process leaves in its own state as it enters foreign code through a callback, a timed receive or a call", "costs ... a `try`", "The log's *The Sitting on §8.6's Bookkeeping*".
- Fix: something like "each timed receive, call or foreign call costs a few nanoseconds, so that when the program goes quiet the runtime can tell whether anything can still deliver"; and define "the look" or drop the word.

**N5. The deadlock fault does not say where anyone waits.** The README promises "a fault and a trace". `ern run dinner.erc naive` prints:

```
Dinner.main faulted: deadlock
    Dinner.host:314
    Dinner.serve:302
```

- That is the entry process's own stack and nothing else. Nothing names the five philosophers, or says that each waits in `Address.callForever` inside `take`.
- I found the cycle only because I knew my program. I could read this message but not use it.
- Fix: list each waiting process by its spawn site and the function it waits in, or have why.md and §5.4 say that only the entry process's trace is shown.

**N6. Literal patterns are used but never taught.**
- My argument parser matches `"naive" -> ...` and `"--clumsy" :: rest`, and both compile.
- The guide never shows a string or integer literal as a pattern. §2.6's list (language.md:457) has names, `_`, tuples, constructors and `as`. I relied on what ML does.
- Fix: one sentence and an example in §2.6.

**N7. §2 and §3 teach mailbox ideas before processes exist.**
- §2.5 (language.md:434): "key it by the process behind each address instead (§5.5)".
- §3.3, at its end: "a mailbox type nothing fixed is `Never`, ... as a spawned function's is".
- §3.4 (language.md:716): "gives out its address by `self`, asks for a message to be delivered into its mailbox, as `monitor` does".
- §3.5: `Address`, and process-only effect variables.
- On a first reading each of these is a word with nothing behind it yet.
- Fix: move the process half of §3.4 and §3.5 to §4.1, leaving one sentence that points ahead.

**N8. §4.1's "A process that receives nothing" (language.md:810) is too abstract to follow.**
- The passage: "A call of the definition fixes `n` too, where `n` stands in a parameter's type ... Where `n` is the definition's own mailbox type, the process the definition runs in fixes it."
- I could not rebuild the rule from it, and the example that follows shows only the `Never` case.
- Fix: a three-line example for each case.

**N9. §4.4's pacing program uses a form never taught, and does not need it.**
- language.md:1020 writes `spawn(fn() : Unit receiving ProducerMsg = produce(me, 1, 100, 0))`: a lambda with a result annotation, and no reason given.
- Without the annotation the program compiles and prints `sum 5050` (`ex/pacing.ern`).
- Fix: drop the annotation, or say why it is there.

**N10. The guide never says how `receiving` binds when a result is itself a function.**
- `fn dinerProcess(diner : Diner) : () -> Unit` refused the function `restarting` returned.
- Writing `: () -> Unit receiving e` attaches `receiving` to the result type. Writing `(() -> Unit) receiving M` attaches it to the function being defined.
- The shell prints `f : () -> () -> Unit receiving M`, which reads either way.
- Fix: one sentence in §3.5, with the parenthesized form.

**N11. §2.8 (language.md:560) says "a function a call computes is applied in writing, `adder(3)(x)`".** "Applied in writing" does not parse. I took it to mean: `x |> adder(3)` would be `adder(x, 3)`, so write `adder(3)(x)`. Fix: say that.

**N12. Three sentences I had to read several times.**
- §4.6 (language.md:1077): "in the shell one from a module that `:reload`, the shell's command that compiles a changed module again (§9.3), compiled, and on a peer, ...". The verb "compiled" arrives after an inserted clause.
- why.md:129: "Here the counter is the module `Counter`, and `CounterMsg` gained a `Reset` between the two spawns, both processes run, and a message of the new type ...". Three facts, joined by commas.
- §4.4's sentence on `callForever`, which lists six causes in one breath.
- Fix: split each one.

**N13. §7.1 (language.md:1930) runs "the module's doc examples", "one that ends in `// => v`", but never shows one.**
- I could not tell what a doc example is or where it goes: an indented block inside `///`? A fenced one?
- I saw the form only in the output of `:doc Random`.
- Fix: a three-line `///` block that holds an example.

**N14. §7.3 writes `OrderedSet.Set(Int)` (language.md:2159 on) and never says why.**
- Why is the type `Set` inside `OrderedSet`, when §7.2's is `Stack.Stack`? And why does `Set(Int)` need no module at all?
- Only why.md, in *Abstract types*, says that `Set` is the prelude's type.
- Fix: one sentence in §2.5 or §7.3.

**N15. §4.1's example (language.md:821) shows a different case from its sentence.**
- The sentence: a `let` at the prompt whose type is open "is refused until an annotation settles it".
- The example: `List.reverse([])`, an expression, which is accepted with a note.
- The refusal itself, which I did see ("the type of xs is not determined by this input; it is List(a)"), is not shown.
- Fix: show `let xs = []` and its error.

**N16. Exercise §2.11 printed a follow-on error I did not understand.**
- I built (b) and (c) with a `main` that passes the result to `Io.debug`.
- After the real error came a second one: "the type a is not known whole here, and Io.debug writes a value by its type ... a requirement `needs a.show` lets it write the value".
- It only follows from the first error. It uses "known whole" and `needs`, which the guide reaches only in §7.3 and §8.4. See `ex/sb.ern` and `ex/sc.ern`.
- Fix: report nothing further about a definition whose type already failed.

**N17. The README shows no line of Ernest.**
- README.md:32 says "The counter that shows the first claim, with its output, and the rest of the argument are Why Ernest".
- Before I have seen a single program, the README gives the six claims as prose, full of terms not yet explained: requirements, peers, a node's key.
- Fix: put why.md's twenty-line counter and its refusal in the README.

**N18. Two claims open on another system before saying what Ernest does.**
- why.md:198: "A reader who knows another language looks for a type class, an interface or a trait. Three things stand in their place".
- faq.md:9: "Gleam's typed messaging is a library over the runtime's processes, well made too."
- Fix: open with what Ernest does: "A type's members are the functions declared under its name ...", and "In Ernest the process is the language: ...".

**N19. Two FAQ answers: one rule counted three times, and a wrong citation.**
- faq.md:105 lists one rule three times, "a failure dropped, an `Either` result left unread ..., a value discarded without `let _`", and cites §11 for it.
- faq.md:17 cites "the guide's §6.4" for "what a process opened ends with it". §6.4 is *Let it crash*. The rule is in §6.5 (a restart cancels what the process asked for) and §8.7 (a socket is killed with its owner).
- Fix: make the three items one, and cite §8.7.

**N20. Small slips in the examples.**
- §6.4's `outcome()` takes `Ended(_)` and then waits for `Result(n)` with no limit. A worker that was killed sent no result, so the wait never ends: the very case §5.2 just warned about.
- `site = _` in the same pattern does nothing, since a pattern may leave fields out.
- §5.3 writes `kill(addr)`, the kind of abbreviation the style rules refuse.
- Fix: match `Ended(Down(reason = Returned))` before the inner `receive`, and write `kill(address)`.

#### The language

**N21. `restarting` and monitors do not work together.**
- A process restarted in place keeps its `Process` and its address, and "no monitor hears of it" (§6.5). So a process that holds something for it, a lock, a fork, a lease, never learns that its holder restarted and forgot.
- In the dinner, a clumsy philosopher that faults while holding two forks restarts, asks for its first fork again, and queues behind itself.
- With the restart handling taken out (`exp/dinner.ern`), every `--clumsy` run ended in `Dinner.main faulted: deadlock` after the first restart.
- To get past it I had to put knowledge of restarts into the protocol:
  - the fork answers at once a holder that asks again (dinner.ern:112);
  - every run starts by putting down whatever an earlier run might have held (dinner.ern:161).
- In Erlang a restart gives a new pid, and the lock's monitor fires.
- The principle at stake is 3, nothing invisible: the restart is invisible to exactly the processes that need to see it.

**N22. A server cannot learn who is calling it.**
- A `Reply` names no caller. So a fork that must watch its holder needs the caller to put its own `Process` in the request: `Acquire(by = Process.current(), reply = reply)` (dinner.ern:134).
- Nothing checks that field. Any process can send `Release(someoneElse)` and free a fork it does not hold.
- Erlang's call hands the server `From`.

**N23. A monitor cannot be taken back.**
- The prelude has `monitor` and no way to undo one (`:browse Prelude`).
- A server that monitors its caller on every request piles up monitors, and later `Down`s, for as long as the caller lives.
- The guard therefore keeps a `Set(Process)` of who it already watches, and drops an entry at its `Down` (dinner.ern:102).
- The guide says an alarm cannot be canceled (§5.5), and says nothing either way about a monitor.

**N24. Sleeping counts as receiving.**
- A function that only pauses, `receive { after ms -> Unit }`, must carry `receiving e`, and so must every function that calls it, though no message is ever taken.
- `Address.callForever` also waits, and carries nothing.
- `Clock` has no sleep (§2.9).
- In the dinner, `run` and `dine` carry `receiving e` only because philosophers think. With `: Unit` the build fails: "`receive` needs a mailbox".
- The principle at stake is 1, least surprise: the FAQ teaches that `receiving` means "reads this process's mailbox".

**N25. Tuples, lists and `Optional` have no order.**
- I met this while exploring, not in the dinner.
- In the shell, `#(1, 2) < #(1, 3)`, `[1] < [2]` and `Some(1) < Some(2)` are each "`<` is not defined on ...".
- `type Entry = Entry(name : String, age : Optional(Int)) derives compare` is refused: "Optional(Int) has no compare" (`ex/dc.ern`). So a record with an optional field cannot derive an order.
- §3.6's `byCount` writes by hand what a `compare` on pairs would give.
- Both Erlang's term order and OCaml's `compare` provide it.

**N26. `Address.call` cannot say why there was no answer.**
- It answers `None` when the time ran out, and also when the callee ended or restarted.
- So a philosopher's question to the table at the start of a run cannot tell a slow table from a gone one. In the dinner I took 0 meals, which is harmless there.

#### The names

**N27. Asking for later deliveries has three shapes of name.** `Terminal.subscribe(wrap)`, `Os.termination(wrap)` and `Process.faults(wrap)`, beside `monitor` and `Clock.alarm(ms, wrap)`. From its name I would not have guessed that `Os.termination` subscribes to anything. Expected: `Os.subscribeTermination` and `Process.subscribeFaults`, or `subscribe` throughout.

**N28. `adapted(target, convert)` is a prelude adjective that makes a new address**, while the other operation on addresses is `Address.call`. Expected: `Address.adapt` or `Address.map`.

**N29. Of the three remote operations, two name a peer and one does not.** `Peer.spawn(name, f, ms)` names its peer, `Peer.compute(f, ms)` names none, and `Peer.computeAt(name, f, ms)` names one. Expected: `Peer.compute(name, ...)` to match `Peer.spawn`, and `Peer.computeAnywhere` for the one the node picks.

**N30. `OrderedSet.Set`, while §7.2's module `Stack` declares `Stack.Stack`.** Expected: `OrderedSet.OrderedSet`, or a prelude type `OrderedSet(a)` as `Set(a)` is.

**N31. `Random.nextInt(seed, bound)` draws "from 0 to `bound`, both included".** The word `bound`, as in Java's `nextInt(bound)`, predicts a limit left out. My first `Random.nextInt(seed, 3)` was meant as 0 to 2. Expected: `nextInt(seed, low, high)`, or the parameter named `last`, as `List.range` names its own.

**N32. `Io.printlnError`.** Expected: `Io.printError` or `Io.eprintln`. Here "println" is glued to "Error".

**N33. `Reason.Unknown`, and the shape of `Address.call`.**
- `Unknown` is the reason given when the process had already ended at the time of `monitor`. Expected: `AlreadyEnded` or `NoProcess`.
- `Address.call` answers `Optional`. §2.9's rule says a function that waits "may answer `Left(Timeout)`", and `Fs.read`, `Peer.find` and `Tcp.read` do. Expected: `Either(Io.Error, a)`.

**N34. Smaller ones.**
- `answer(reply, v)`: expected `reply`, the type's own word and Erlang's `gen_server:reply`.
- `Process.live()`: expected `Process.list()` or `Process.all()`.
- `Clock.monotonic()` is in milliseconds, while its sibling is `monotonicMicros`: expected `monotonicMillis`.
- `self()` gives an address and `Process.current()` the process: expected the two to share a word.
- `List.foldRight` takes its callback as `(b, a) -> b`: expected `(a, b) -> b`, as in ML.

### Reader L


Read in order: README.md, guide/why.md, tour/README.md (programs under tour/1 to tour/8), guide/faq.md, then the sections of guide/language.md and guide/deployment.md that changed since fb2324e8, whole. That is nearly all of language.md (not §7.2 to §7.4) and all of deployment.md. Two claims were checked by running programs in the scratch directory with bin/ern (0.4.0-dev); the runs are cited where they are used.

#### Defects

**L1. The FAQ says there is no selective receive; the guide teaches it.**
faq.md:35: "a `receive` is a `match` over that type and the compiler can say what is left out; there is no selective receive, and a loop takes the next message of its type, whatever it is."
Against this:
- language.md:837 has a section titled "4.3 Selective receive and `after`".
- language.md:839: "`receive` takes the first message that matches a clause and leaves the others in the mailbox for later. Unlike `match`, it need not cover every case".
- §10 (language.md:3083) lists it under what carries over from Erlang.
- §13(c) (language.md:3148) says a `Reset` with no clause "waits there for a clause that never comes".
- language.md:1474 says "a message that no `receive` takes stays in the mailbox for as long as the process lives".

Both halves of the FAQ sentence are contradicted. It is the first thing an Erlang programmer checks, and this answer is new since 0.4.0.
Fix: rewrite faq.md:35 to say what §4.3 says.

**L2. The tour's restart limit works only at machine speed (a demo arranged to work).**
tour/README.md:233: "The limit allows one restart in five seconds, so the next fault is the end:". The transcript then shows "the counter ended: Fault(...)".

A reader typing along makes the second fault two inputs after the first: a `get`, then `inc -1`, with time to read in between. That gap is almost surely more than 5 s. The counter then restarts a second time and the watcher prints nothing.

Checked: the same counter under `RestartLimit(restarts = 1, within = 5000)`, with 6 s between two faults, printed "faulted, restarted" both times and was alive afterwards (scratch run/window.ern).

The chapter's lesson, a watcher told of the end, fails for the reader it is written for.
Fix: say the second `inc -1` must come within five seconds of the first fault, or give a longer `within`.

**L3. Deadlock detection is off on a node, and only why.md says so.**
why.md:15 says "under `ern run`, `ern test` and the shell; a node is left to its peers", and why.md:329 says "never on a node". These say the same thing without the exception:
- README.md:21: "A program in which every process waits for a message none can send ends with a fault and a trace".
- language.md:1349 (§5.4): "the entry process faults with `deadlock`, and the program ends".
- faq.md:59.

deployment.md never mentions it. Every production deployment the deployment guide teaches is a node, so the guide promises the operator something the node never does.

The tour shows the claim under `ern test` (ch. 5), the one place it holds.
Fix: add "not on a node (a program started with `--config-dir`)" to README.md:21, §5.4 and faq.md:59, and add a line in deployment.md.

**L4. §10 hides a weaker ordering than Erlang's: a `Down` may overtake the dying process's last message.**
language.md:1284: "A `Down` comes from the runtime and not from the process that ended, so it has no order with that process's own messages". In Erlang a 'DOWN' arrives after every message the dead process sent the monitor's owner.

The guide's own programs carry extra code because of this:
- `waitFor` with its `Returned` clause (§5.2);
- the `owed` counter in `gather` (§4.4, §8.1);
- the inner `receive` in `outcome` (§6.4).

Yet §10's "What carries over" (language.md:3085) says only "`monitor` delivers a message when a process dies". "What differs" says nothing of the ordering. An Erlang programmer writes the Erlang pattern and gets a rare race.
Fix: add a bullet under "What differs" in §10 that cites §5.2.

**L5. deployment.md §6 says looking changes nothing, which §4.2 contradicts.**
deployment.md:285: "Looking costs what one compute costs and changes nothing on the node."

But §4.2 (deployment.md:199, 205) says each definition that crosses becomes a unit the node keeps for its life. Each one uses a module name, exports, a function entry per lambda and an atom, none given back.

Every look typed at the ops shell is a lambda that crosses. A sentence just before (deployment.md:281) admits "the lambda's crossing".
Fix: "changes nothing of the program's state; each new lambda it sends is kept, as §4.2 counts".

**L6. why.md understates what `ms` bounds in `Peer.compute`.**
why.md:158: "answers the value, or `Left` with the reason where no peer can be reached within `ms`".

The guide (language.md:2390) says `ms` bounds the whole wait. When it runs out, "the process is killed there". A remote process that dies before answering gives `Left(Other(text))`.

Read why.md alone and a long computation looks safe under a short `ms`.
Fix: "answers the value within `ms` milliseconds, or `Left` with the reason".

**L7. why.md gives two costs for one foreign call.**
why.md:333: "A foreign call that answers at once costs what the host's call costs and a `try`."
why.md:96-98 (and faq.md:67) say the runtime checks each answer, and "a check walks the value it checks, and costs with its size".

In context, line 333 means the deadlock look's own cost. Read on its own it states a foreign call's whole cost.
Fix: "costs the look nothing beyond a `try`", or name the check.

**L8. Three documents count the claims with programs three ways.**
- README.md:15: "six claims ..., the first five with a program".
- why.md:3: "four of them with a program and one with its file".
- language.md:34 and :92: "the first four with a program".

In why.md the third claim (WAN) has a file and the fifth (deadlock) has a program. So "the first four" is wrong, and README's "five" counts the file as a program.
Fix: use why.md:3's wording in all three.

**L9. Four cross-references point at the wrong section.**
- language.md:872 and :1581 (both new) cite "(§8.3)" for a node out of reach. The guide's §8.3 is *Foreign types and functions*; the loss of a peer is §8.2, *A loss*.
- tour/README.md:328 cites "(the guide's §6.6)" for `ern test`. §6.6 is *A supervisor*; tests are taught in §7.1, *Testing a module*.
- faq.md:17 cites "(the guide's §6.4)" for "what a process opened ends with it". §6.4 says nothing of it; §8.7 (language.md:2945) does.

Fix: §8.2, §7.1, §8.7.

**L10. The tour says another machine where it means another node.**
tour/README.md:350: "a process on another machine that has run since chapter 2". `foo` is on the same machine, at 127.0.0.1:8655; tour:124 says "three nodes on one machine".
Fix: "on another node".

**L11. The tour's reason for the order of chapter 8's two messages is not the guide's rule.**
tour/README.md:553: "the `report` in between was answered after the `Upgrade`, since both went from the shell to the counter in that order."

Each prompt input runs in a process of its own. language.md:2705 says "the caller is the input's process". Checked: `Process.current()` at two prompts gave `<process 104>` and `<process 107>`. So the `Upgrade` (sent from input `Counter.move()`) and the `report` come from two senders.

§5.1's per-sender order does not cover that. The result holds because the first input ended before the second began. The sentence cites a guarantee that does not apply.
Fix: "since the first input had sent the `Upgrade` before the second began".

#### Questions the documents do not answer

**L12. The first question I asked: how does a running server change the shape of its state?**
In §4.6 and §8.9, `Upgrade(migrate : (Int) -> Int, next : (Int) -> Unit receiving CounterMsg)`. The guide says "`migrate` turns the old state into the new" (language.md:1101) and "carries the total from the old loop's shape to the new, and here the shape is the same" (language.md:3006).

The state type is in the message type, and a process keeps its message type for life (why.md:125, faq.md:23). So no `migrate` can ever change the shape. "Here" suggests that somewhere it can, but no document shows where.

An Erlang programmer adds a field to a gen_server's state in `code_change` all the time. The only answer I could piece together: write the state out, start a new process, move the clients. §8.2, language.md:2697, says this for a stored state, not for a live upgrade.
Fix: one paragraph in §4.6 or §8.9 that says what to do when the state's type changes.

**L13. How is a fleet moved to a new `ern` or a new OTP major?**
deployment.md:139 says nodes on two floors do not connect. The table at deployment.md:307 gives the move "Install one release of each on both."

On a WAN of nodes that is a partition, or stopping everything at once. Erlang runs mixed OTP releases in one cluster for exactly this. No section says how an operator rolls a toolchain upgrade.
Fix: a paragraph in deployment.md §5 on upgrading the toolchain across nodes.

**L14. How does a client learn that a `restarting` service lost its state?**
language.md:1761: "A restart is not an end: no `monitor` hears of it". language.md:1824: "a client that relies on a service's state after a fault takes the state as lost and asks again".

The guide never says how the client learns of the fault. A client subscribed to a service, which the restart forgets, is never told. Only a call that was waiting at that moment sees `None`.
Fix: one sentence saying how a client finds out, or that it cannot.

**L15. What stands in for `global` and `pg`?**
The FAQ and §10 answer for registered names (a top-level binding) and for services (find by name across listed peers). Neither says how a group of processes spread over nodes is joined, listed or broadcast to, which is what `pg` does. Neither says whether a find names one holder across the whole configuration, as `global` does, or one per node (language.md:2667, "one holder on a node").
Fix: a FAQ line under "Where are ETS, tracing, ...".

**L16. Two questions a WAN raises.**
- Does a `send` to a lost peer block the sender while it dials again (up to 7 s, deployment.md:153)? language.md:2675 says "a later `send` dials again". language.md:806 says `send` "returns at once". Erlang's auto-connect blocks the sender, so the question is the first an Erlang programmer asks.
- Can the 45 to 75 s silence detection (deployment.md:147) be tuned for a WAN, as `net_ticktime` can? No entry of `ernest.conf` is said to set it.

#### Clarity

**L17. §10 and §13(c) read as a contradiction.** language.md:3093: "a message the process does not take is a compile error, not a message that sits in the mailbox for ever". language.md:3148 shows a message of the right type that no clause takes, sitting in the mailbox for ever. "Does not take" means "not of its type", which a hurried reader does not see. Fix: "a message not of the mailbox's type".

**L18. A garden-path sentence.** language.md:1077: "in the shell one from a module that `:reload`, the shell's command that compiles a changed module again (§9.3), compiled, and on a peer ...". I read it three times. Fix: split it into three sentences, one for each place a new function comes from.

**L19. "Distribution" means two things.** language.md:2313: "one major release of OTP, the Erlang distribution Ernest runs on". In a chapter on nodes, an Erlang programmer reads "the Erlang distribution" as the distribution protocol. Fix: "OTP, the Erlang release Ernest runs on".

**L20. It reads as though `Peer.compute` runs the work locally.** language.md:2416: "at both the work runs here, `heavy(n)`". This is `placed.ern`'s fallback, not `Peer.compute`'s doing. Fix: "at both, `placed.ern` runs the work here".

**L21. A "constant" that spawns and calls.** language.md:311 calls a top-level `let` a constant, and :323 says its initializer may spawn, send and call. I tripped on a constant that starts a process. Fix: call it a top-level binding, as §6.5 does.

**L22. why.md's deadlock trace looks like the wrong line.** why.md:323-324 prints `Dead.main:7`, the `spawn` line, not the `receive` on line 8. The tour explains this at tour:328 ("the line of the last call before the wait"); why.md does not. An Erlang programmer reads it as a broken trace. Fix: carry the tour's half-sentence over.

**L23. A run-on sentence in why.md.** why.md:129: "Here the counter is the module `Counter`, and `CounterMsg` gained a `Reset` between the two spawns, both processes run, and a message ...". Fix: split it after "two spawns".

**L24. deployment.md:81, the exit statuses, cannot be parsed in one reading.** "with 1 when its entry process *faults*, ends on an error it did not expect, a division by zero among them, or is killed or the program exhausts the host's memory, by the termination signal itself when termination ends it, ...". Fix: a list, one status a line.

**L25. deployment.md §5.2 is vague about the one-line fix.** deployment.md:234: "loads the fixed module with `:load` and spawns the function that applies it on each peer". It never says that a running process keeps the old code unless it has a door (§5.3). An Erlang programmer expects `l(Mod)` and the next fully qualified call to pick up the fix. Fix: say what "the function that applies it" does, and that it needs the door.

**L26. "Any program on the floor" is too wide.** deployment.md:183: "a bare node is a worker that any program on the floor can give work to by its name". Only a listed peer can connect (deployment.md:133). Fix: "any listed peer on its floor".

**L27. deployment.md §8 has the operator hand-edit four files.** deployment.md:335 asks for listen ports and peer lists edited by hand, while §2.1 (deployment.md:127) has just taught `--listen` and `--peer-dir` for exactly this. The reason, no address for `a` and `ops`, is left for the reader to work out. Fix: one clause saying why the flags are not used.

**L28. The tour's foo does hold code by the end.** tour:3 says "a node that holds none of its code", and tour:570 "the node that holds none of this program's code runs its new code". By chapter 8, `foo` holds `count`, `count2`, `move`, `start` and `Tally`, which crossed. Fix: "a node started with none of its code".

**L29. "One with room" claims more than the pick does.** why.md:12 says "goes to one with room", why.md:167 "whichever had room when the row was asked for", and tour:513 says the same. The pick is the less busy of two drawn at random, by tellings up to two intervals old (language.md:2414). Fix: "the less busy of two peers drawn at random".

**L30. `Code.running(f)` looks like a call and is not.** language.md:2953 calls it "a *form*, a call the compiler reads by a rule of its own". Nothing at the call site shows that. I tripped on a library-looking call that is compiled specially. The documents should say so where it is first used, in the tour's chapter 8 (tour:528).

**L31. The FAQ's supervisor answer leaves out the largest difference from OTP.** faq.md:21 names two differences, no `simple_one_for_one` and no shutdown timeout. It omits language.md:1820: a sibling under `OneForAll` "runs on until it next waits ... A sibling that never waits is never restarted". OTP kills siblings at once. Fix: add that sentence to faq.md:21.

#### The brief's questions

**Where I would close the page.**
- README.md:24, "not for an OTP application". If I had come to add Ernest to a running OTP system I would stop there. That is honest, and it is said first.
- faq.md:93, "There is no tracing and no `observer`", with deployment.md:287 (no attach, no `remsh`) and faq.md:17 (no `sys`). For production I would close the page here. A node I cannot trace or attach to is a node I cannot run.
- deployment.md:240: a service under `restarting` cannot be moved to new code in place. It falls back to the old code at its next fault, and must be replaced by a new service beside the old. Supervised and hot-upgradable are the two things I need together, and the guide says I get one or the other. I kept reading because the type story is good.

**The first question the documents do not answer.** L12, how a live server changes its state's type. After it: L13, L14, L15, L16.

**What Erlang cannot do, shown.**
- A typed mailbox checked at the send, including across versions: tour ch. 5's refusal of `Counter.apply(far, ...)` with `Counter$3.CounterMsg`, and why.md's shell session.
- A spawn refused at compile time because its mailbox type holds a function (tour ch. 6).
- A spawn on a bare node that carries its code by hash (tour ch. 2, 6, 7).
- `Code.running` by hash, the same address before and after, and versions side by side with nothing purged and no process killed at a third load (tour ch. 8). In Erlang the third load kills what runs the oldest version.
- A foreign return checked against its declared type at the crossing (tour ch. 7).
- A deadlock as a fault with a trace under `ern test` (tour ch. 5), but see L3.
- A node that only dials, keys in place of a cookie, and no mesh, in one file with no epmd. Erlang can do this, but only with inet_tls_dist, a custom epmd module and `-connect_all false`.

**What only restates what I have.**
- `Address.call` is `gen_server:call`, and the late reply dropped is OTP 24's aliases.
- `monitor`/`Down` and `Unreachable` are `noconnection`. The 45 to 75 s window is `net_ticktime`.
- `restarting` is a one-child supervisor, and `Supervisor` has OTP's three strategies with fewer features.
- Credit windows are what everyone writes.
- `Os.termination` is SIGTERM handling with a prep_stop. The atom and module-table limits, and restarting a node to reclaim them, are Erlang's own.
- §10's "What carries over" says so honestly.

**Sentences I suspect of a trick.**
- L2, the restart window that only a test harness meets.
- L3: the deadlock is shown under `ern test`; on a node it never fires, and README does not say so.
- L11: the right outcome under the wrong rule.
- L5: "changes nothing on the node".
- tour:502, `Peer.utilizations()` gives `#("bar", 0.25, 387)` for a bare node that has just answered one tiny compute, so that `foo` is picked twice. The page says "in this run", but nothing explains an idle node at a quarter busy.
- README.md:21 and why.md:15: "pays nanoseconds". No number is on any page I was given; the figure is in docs/, which a reader of why.md is sent to.

**Sentences in the guide I tripped on or did not believe.**
- Tripped on: L17 to L21 and L30, plus deployment L24 to L27.
- Did not believe:
  - language.md:3098, "a registry exists so that a name can be looked up again after the process behind it has died and been replaced". Registries such as gproc, pg and via names also exist to find a process by a key that is only known at run time, a user's session for one.
  - language.md:1284, the `Down` ordering (L4), until I accepted it as Ernest's rule and not Erlang's.
  - language.md:1101, `migrate` (L12).

**What convinced me.**
- The type errors. `the argument does not fit Counter.apply: expected Address(Counter.CounterMsg), found Address(Counter$3.CounterMsg)` with its help line is something no typed Erlang I have seen manages across a hot reload.
- Tour ch. 6's refusal of a spawn whose mailbox type holds a function, and ch. 8's move by hash with the address kept.
- The documents are candid about the limits: no observer, no attach, versions never purged, the atom tables, `None` not saying whether the work ran.

**Would I try Ernest?** Yes, for a new, small distributed tool or a side project across a laptop and a server. Not yet to replace an OTP system in production. The reasons: no tracing or attach; supervision and in-place upgrade exclude each other (deployment.md:240); a sibling restart that waits for the sibling (L31); the floor rule with no rolling path (L13); and the state-shape question (L12).

### Reader M


Read at 1329d1d2: README.md, guide/why.md, tour/README.md (programs of chapters 4 and 5 run in scratch), guide/faq.md, then the sections of guide/language.md and guide/deployment.md that changed since fb2324e8 (they touch almost every section, so both files were read whole), and guide/README.md from the diff. Four things were checked by running `bin/ern` in the scratch directory, never in the repository: M2, M3, M6 and M12.

#### Defects

**M1. faq.md:35 and :43 contradict the guide on selective receive.** faq.md:35 says "a `receive` is a `match` over that type and the compiler can say what is left out; there is no selective receive, and a loop takes the next message of its type, whatever it is". The clause after the semicolon is new since fb2324e8. The guide teaches the opposite:
- §4.3 (language.md:837-855) is titled "Selective receive and `after`". It says "`receive` takes the first message that matches a clause and leaves the others in the mailbox for later. Unlike `match`, it need not cover every case", and `waitForData` leaves a `Wake` waiting.
- §10 (:3083): "`receive` selects a message by pattern and leaves the others in the mailbox".
- §13's answer (c) (:3148): "a `receive` need not" cover its type.
- faq.md:43 itself speaks of "a guard, which runs while a message is selected".

A Gleam reader who asks the FAQ how one mailbox per process works is told the reverse of §4.3. Fix: drop "there is no selective receive, ..." from faq.md:35, and say instead that a `receive` takes the first message a clause matches.

**M2. tour/README.md:582 gives the wrong reason after an orderly stop.** After `ern stop --config-dir foo` the tour says "a process that monitored the counter would have heard a `Down` with the reason `Unreachable`". Four places say an orderly end gives `ProgramEnd`: deployment.md:151 (§2.3, the very section the tour cites there), the `ended` row of deployment §7 (:299), deployment §8 (:385), and language.md:2673 (§8.2).

I checked it in scratch. tour/4's `watch` was set on a counter spawned on a bare node, then the node was stopped with `ern stop`. The shell printed `the counter ended: ProgramEnd`. Fix: `ProgramEnd`.

**M3. tour/README.md:219-241 (chapter 4): the restart limit only works if the reader types fast.** The tour says "The limit allows one restart in five seconds, so the next fault is the end". Between the two faulting inputs the reader types and reads `Counter.apply(counter, "get")`. At the pace of someone working along (the tour asks for "about three [hours] to do along"), more than five seconds pass. Then the second fault restarts the counter again, and the watcher prints nothing.

I checked it in scratch, piping the chapter's inputs into `ern shell` with about 7 s between the faults. It printed `faulted, restarted` twice, and `the counter ended` never came. With 1 s between the faults it printed what the tour shows. Fix: tell the reader to send the second bad amount within five seconds, or give the tour's `within` a length a typist can meet, and update its sentence.

**M4. language.md:245 (§1.5) shows a session that cannot be reproduced from §0.** The section opens "The counter of §0, run on a node that holds none of its code". §0's counter is a refused program (`message.ern`, an `ernest-rejected` block), and its `count` and `CounterMsg` are not exported. The session's `:load Counter` followed by `Counter.count(0)` therefore fails. I tried it in scratch with §0's declarations saved as counter.ern, and got `unknown name Counter.count`. The session is really the tour's tour/1/counter.ern.

The new §1.5 also comes after §1.4's exercise, although §0 says each stage "ends with an exercise". Fix: "The tour's counter, `counter.ern`, whose type and loop are exported, ...", and put §1.5 before the exercise.

**M5. The pages disagree on how many of why.md's claims have a program.**
- why.md:3 says "six claims, four of them with a program and one with its file". This matches its own content: claims 1, 2, 4 and 5 have a program, claim 3 has a JSON file, and claim 6 has nothing.
- README.md:15 says "the first five with a program".
- language.md:34 and :92 say "six claims, the first four with a program". This is wrong, since claim 3 has no program and claim 5 has one.
- guide/README.md:14 says "five of them with a program and its output". This is wrong, since claim 3 has no output.

Fix: use why.md:3's wording in all four.

**M6. language.md:194 (§1.3) swaps two cross-references.** The sentence reads "`<<>>` is the empty bytes (§2.4), and `finished.stdout` a field of the record `Os.run` answers (§2.1)". `Bytes` and `<<...>>` are taught in §2.1, and field selection in §2.4. Fix: swap the two.

**M7. faq.md:17 cites the wrong section.** It says "`terminate`'s work is the runtime's, since what a process opened ends with it (the guide's §6.4)". §6.4, *Let it crash*, says nothing about what a process opened. §8.7 (:2945) says it of a socket, and §6.5 (:1759) says what a restart cancels. Fix: cite §8.7.

**M8. tour/README.md:55 cites the wrong section.** It says "the type and the loop are exported so that the prompt can name `Counter.Inc` and `Counter.count` (the guide's §4.1)". §4.1 has no `export`; exporting is taught in §7.1. Fix: cite §7.1.

#### Matters of clarity

**M9. The gain of the mailbox in the type over a Gleam `Subject` is asserted, never shown.** The claim that "A function that receives runs only in a process of its mailbox's type" appears in five places: why.md:11 and :61, faq.md:11 and :39, and tour/README.md:57 ("`count` runs only in a process of that type").

The one refused program, why.md:63-87, binds the spawn's result to an `Address(OtherMsg)`. A typed handle refuses that too. Tour chapter 1's refused `send(counter, "five")` is likewise one a `Subject` refuses. No page shows a receiving function refused where a design built on handles would accept it.

So tour/README.md:3's promise, "what the program has just done that your language cannot", does not hold for this reader in chapter 1. Fix: none in the language. The page needs a refused program of that kind, or the claim stated without the contrast.

**M10. The requirement's closed set appears only in language.md §7.3.** §7.3 (:2056) says "A requirement names `compare`, `negate`, an operator, or `show`, and nothing else", and §7.2 (:1948) says much the same. why.md:14 and :232 ("A generic function names the operations it needs of its type") and faq.md:87 ("A type's members are the functions declared under its name in its own module") both read as if any function declared under a type's name could be required.

For this reader the closed set is the one fact that shows a requirement is not a type class, and why.md and the FAQ never state it. Fix: one sentence in why.md's section and one in the FAQ answer, naming the four.

**M11. Glosses added since fb2324e8 sit mid-clause and leave sentences that do not parse.**
- language.md:1077 (§4.6): "in the shell one from a module that `:reload`, the shell's command that compiles a changed module again (§9.3), compiled, and on a peer, a node the program's configuration lists (§8), one that a spawn there brings".
- :872 (§4.4): "with the callee's cause, the text that says what went wrong (§6.3), where it faulted, and otherwise ...".
- :2311 (§8): "the peers that may offer it, hold a process under that name for peers to find (§8.2), in the order a *find*, the lookup of a service by its name (§8.2), asks them".
- :2412 (§8.1): "1.0 every scheduler, a thread of the host that runs processes, busy, below it room ...".
- :2414 (§8.1): "a utilization older than two intervals of the peer that told it, which each *telling*, the message that carries one, names, is not used".
- :72 (§0): "`spawn`, `send`, `receive`, an address, where a `send` goes, `Reply`, ...".
- :184 (§1.3): "A program the host has, the Erlang runtime Ernest runs on and the operating system under it, is run with `Os.run`". This reads as if the program were the runtime.
- deployment.md:63 (the list of operations, each with its gloss), :81 (the exit-status sentence, where "or is killed" is left hanging after the gloss of *faults*), and :169.

Fix: give each gloss a sentence of its own.

**M12. Nothing near the `Stack` examples says a module value does not reach a bare node.** tour/README.md:316 says "`empty` is a function and not a value, since a module's values belong to the node that loaded it", and language.md:2396 says the same. Yet why.md:206 and language.md:1954 (§7.2) teach `export let empty = Stack([])` with no caveat.

I checked it in scratch. A compute on a bare node using why.md's `Stack` answered `Left(NotLoaded)`, and the peer said "the binding Stack.empty has no value here". From §7.2 or why.md alone I could not tell that the showcase module is one a bare node cannot use, or which of my own values must be functions. Fix: one sentence at §7.2's `Stack` pointing to §8.1's rule.

**M13. tour/README.md:553 and :570 rest message order on something the guide does not promise.** At :553 the tour says "the `report` in between was answered after the `Upgrade`, since both went from the shell to the counter in that order". By language.md:2705 each input runs in "the input's process", so `move()` and the next `apply` are two senders. §5.1 and §5.6 promise order per sender only: "Messages are ordered per sender only". The same holds at :570, for a send made on `foo` followed by a message from node `a`. I did not believe either sentence as written. Fix: name the rule that orders them.

**M14. "No registry" reads as false to a reader from a BEAM language.** faq.md:19 says "that is why there is no registry", language.md:1714 (§6.5) says "It is not a registry", and §10 (:3098) says "There are no registered names". Yet §8.2's `Peer.offer` and `Peer.find` register a process under a name, with "one holder on a node" (:2667), and §10 (:3102) itself names them. To me offer and find are a registry, so the sentence reads false until §8.2. Fix: "no registry on a node".

**M15. faq.md:53 says replies are "checked".** The sentence is "Whether a reply is answered is checked as the program runs, not by the compiler." The next answer (:57) says nothing checks it, and that the caller's deadline ends the wait. I did not believe "checked". Fix: "is not checked; the caller's call bounds its wait".

**M16. tour/README.md:128 says the shell's process ends.** It says "the `match` ... ends the shell's process on anything else". The shell lives on; what ends is the input's process (language.md:2705). Fix: "ends the input's process".

**M17. tour/README.md:350 puts `foo` on another machine.** It says "a process on another machine that has run since chapter 2". In the tour, `foo` is on this machine, at 127.0.0.1:8655. Fix: "on another node".

**M18. tour/README.md:267 has no verb.** It reads "`counter.ern`'s type, its loop, the helper that writes a report, and two tests; `apply` grows a key ...". I read it twice before I saw it is a caption for the block below. Fix: "Below are ...".

**M19. why.md:129 is a run-on sentence.** It reads "Here the counter is the module `Counter`, and `CounterMsg` gained a `Reset` between the two spawns, both processes run, and a message of the new type to the old process is refused ...". Fix: split it.

**M20. deployment.md §8 (:335) lists the nodes by hand.** It has the reader edit four files to list three nodes on one machine. §2.1 (:127), the tour and language.md §8.1 have just taught `ern config --listen` and `--peer-dir`, under the words "Two nodes on one machine list each other without an edit". Fix: use them in §8, and leave by hand only what they cannot write.

**M21. deployment.md:133 has a missing word and a run-on.** It reads "a certificate that names another than its key gives is refused", then runs on through two colons. Fix: "another host", as the row at :306 says, and split the sentence.

**M22. deployment.md:385 attaches "which says" to the wrong noun.** The sentence is "the one that hears it is the shell, connected to `b` alone, since it computed on `b` and never dialed `c`, which says `the peer b ended`". Here "which says" lands on `c`. Fix: end with "; the shell says `the peer b ended`".

**M23. language.md:2313 uses "distribution" in two senses.** It says "one major release of OTP, the Erlang distribution Ernest runs on". The same chapter, the FAQ (:73) and §10 use "Erlang's distribution" for how nodes talk. Fix: "the Erlang release".

**M24. language.md:810 (§4.1) is a sentence I could not use.** It reads "Where `n` is the definition's own mailbox type, the process the definition runs in fixes it." I could not build a program it describes. Fix: an example.

**M25. language.md §5.4 says nothing about nodes.** §5.4 says "the entry process faults with `deadlock`". why.md:15 and :329 say the look runs "never on a node". The tour's shell is a node (`ern shell --config-dir a`), and the page does not say whether the look runs there. Fix: one clause in §5.4.

**M26. Reader-facing pages send a newcomer to the developers' log, design notes and plan.** why.md:333 cites "the design note of the runtime" and "The log's *The Sitting on §8.6's Bookkeeping*". faq.md:31 cites *The Hash's Parents*, faq.md:95 cites *Back Pressure, Again*, and faq.md:93 cites "the plan's MVP 4.0". Outside the project these titles mean nothing, "The Sitting" above all.

**M27. why.md:122 sends `countTwice` without defining it.** `countTwice` is defined in language.md §4.6. Fix: name §4.6.

**M28. Several passages are too long for what they show.**
- language.md §4.4 is headed `Address.call` but runs 180 lines: `callForever`, a queue, a library that waits, pacing and fan-out.
- §8.1 runs 225 lines.
- §8.2's store is a 75-line program for one point.
- why.md's *Code known by its hash* makes four points in 70 lines.
- Tour chapter 7 spends 25 lines of sieve on invented work, only to show a compute.

#### What each document shows that Gleam lacks, and where it only asserts it

- **README**: names the six claims and shows nothing, as it should.
- **why.md**:
  - *Mailbox*: shown is that `spawn` types the address from the function, with no init handshake as Gleam's `actor.start` has. Asserted only is that the function runs only in a process of its type (M9). The foreign check is quoted, not run.
  - *Hash*: shown are the shell's versions side by side and the refusal across a reload, with its reason. The bare-node spawn and the compute are fragments, run later in the tour. `Upgrade(next : (Int) -> Unit receiving CounterMsg)` is the one place where the effect in a function type says something a plain `fn(Int) -> Nil` field would not.
  - *WAN*: a file, the rest asserted.
  - *Abstract types*: the same as Gleam's opaque type.
  - *Requirement*: shown with its output and its refusal.
  - *Operations record*: what I would write in Gleam, except for the `..Set` fill.
  - *Deadlock*: shown, and new to me.
  - *Little else*: asserted.
- **Tour**:
  - Ch. 1: nothing Gleam lacks; the refusal is one a `Subject` gives.
  - Ch. 2: code carried to a bare node, shown.
  - Ch. 3: reload keeping bindings, shown.
  - Ch. 4: restart in place keeping the address, shown, but see M3. `monitor`'s wrap is Gleam's selector mapping.
  - Ch. 5: requirement supplied, deadlock in a test, a new protocol refused across versions, all shown.
  - Ch. 6: a bound type refused at `Peer.spawn`, shown. This is also where the cost of one mailbox type shows: the protocol split into `ClientMsg` and `CounterMsg` with an adapted address, where I would hold two subjects.
  - Ch. 7: the foreign check asserted with a quoted message, not run; placement by utilization, shown.
  - Ch. 8: `Code.running(count)` answering `List(Address(CounterMsg))`, shown, and an upgrade carried to a node that never had the code.
- **faq.md**: the Gleam answer is fair, and its "Being the language buys ..." is asserted. The type-class answer is asserted and leaves out the closed set (M10). The one-mailbox answer contradicts the guide (M1).
- **The guide's changed sections**: §4.4's "A library that waits" shows the cost honestly. §7.3 shows the closed set, `derives compare` and `needs a.show`. §8.9 shows `Code.running`.

#### Does the mailbox in the function's type buy anything over a `Subject`, on the page?

Three gains are visible:
- `spawn` types the address from the function, with no handshake.
- `Code.running(f)` hands back addresses typed by `f`'s mailbox (tour ch. 8, §8.9), which no handle could give.
- An `Upgrade` field's type says the new loop reads this mailbox.

A test case's type carrying its mailbox (tour :330) is shown, but I saw nothing it buys.

The costs are shown just as plainly:
- A library that waits must be a process and a call (§4.4's `gathered`, 30 lines with an `owed` count).
- One type per mailbox means wrappers and adapted addresses (§5.5, tour ch. 6), where I would select over two subjects.

The refusal a `Subject` design would miss is never shown (M9).

#### Is a requirement convincing as not a type class?

From why.md and the FAQ alone, no. What they show is a constraint the compiler resolves at the call, from a function declared under the type's name, with `derives compare` beside it, and that is the part of a type class I know.

From §7.3, yes. The set is closed, four names, and no program adds a fifth. That fact is missing where a doubter reads first (M10).

#### What convinced me, and would I try Ernest

Convinced:
- The deadlock found as a test's fault (tour ch. 5).
- Code carried by hash to a node that holds none of it, and `Code.running` typed by the function (tour ch. 2 and 8).
- A protocol change refused across a reload, with its reason.
- A find that compares the message type's hash and answers `OtherType`.

Not convinced: that the mailbox in the type, by itself, catches what my `Subject` misses. The pages assert it and never show it.

Would I try it? For a program across machines with code upgraded in place, which I would not write in Gleam, yes. That is a work pool over two machines like tour ch. 7 and 8. For what I write in Gleam on one node today, not yet.

### Reader D


I read every Markdown file the brief names, and checked each against the report and the code. I did not open `docs/log.md`. One grep run over `docs/*.md` matched the log by accident and printed a few of its lines. No finding below rests on them. Where a finding depends on the log, it says so and stays a suspicion.

#### Defects: false or stale statements

**D1.** `docs/full_review.md:3`, "Twelve readers", and `:79`, "Nineteen readers, counting the code's parts".
- **What is wrong:** the document lists fifteen readers: P, K, G, U, N, L, M, D, C, E, T, X, S, H and B. Counting C's six parts and E's three, that makes twenty-two sessions. Both counts are left over from the first version of the document, `b7d34c0f`.
- **Shows it:** `grep -c '^- \*\*[A-Z], ' docs/full_review.md` prints 15.
- **Fix:** "Fifteen readers"; "Twenty-two readers, counting the code's parts".

**D2.** `README.md:15`, "six claims that Why Ernest argues, the first five with a program".
- **What is wrong:** why.md's third claim, *A distribution built for a WAN*, shows a configuration block and no program. The programs stand under claims 1, 2, 4 and 5. `guide/language.md:92` says "the first four with a program", which is also wrong, and it contradicts the README.
- **Shows it:** `awk '/^### /{s=$0} /^```ernest/{c[s]++} END{for(k in c) print c[k], k}' guide/why.md` shows no WAN section.
- **Fix:** "four of them with a program", in both places.

**D3.** `docs/development.md:29-30`, "why.md, the argument for the design, its list held equal to the README's".
- **What is wrong:** no test holds the two lists equal. `grep -rn why.md test erl/*/test` finds only `ern_guide_tests`, which compiles why.md's examples. The site proposal claims the same test: `docs/proposals/site/decisions.md:82-84` and `:316-317`.
- **Fix:** write the test, or say "kept equal by hand".

**D4.** `docs/soundness.md:5`, "in their revision of 21 October 2026".
- **What is wrong:** `report/language.md` and `report/library.md` are dated 24 October, and `report/toolchain.md` 23 October. The argument itself was rewritten on 24 October for §3.9, §4.5, §6.5 and §6.9 (commits 6cc3b429 and 684471c2).
- **Shows it:** `sed -n 3p report/*.md`.
- **Fix:** "24 October 2026", and update the date with each rule change.

**D5.** `docs/plan.md:157`, "Two nodes tests race, found 2026-10-24, done 2026-10-25".
- **What is wrong:** the commit that did it, 1329d1d2, is dated 2026-10-24 02:03, and today is 2026-10-24.
- **Shows it:** `git log -1 --format=%ad 1329d1d2`.
- **Fix:** "done 2026-10-24".

**D6.** `docs/plan.md:236-239`, MVP 4.1: each library "is an Ernest source root under `src/libs/<name>/` that a program adds with `--load-path`".
- **What is wrong:** this has been false since MVP 3.28. Every library's build ends every job's load path, and a program names none. That is report §11.1 and §11.2, and `development.md:11`, `:79-81` and `:323`, `design/install.md:30` and `examples/README.md:40` all say so.
- **Fix:** "...whose build ends every job's load path, so that a program names none".

**D7.** `docs/plan.md:341`, MVP 4.4, "The first milestone after Ernest 0.5.0", and `:349`, "Conditions before it is built: the language promised (MVP 3.9)".
- **What is wrong:** the table (row MVP 4.0) and MVP 4.0's section (`:187`) both call 4.0 the first milestone after 0.5.0. `docs/proposals/ernest_host/README.md:20` calls 4.4 "the plan's last milestone". MVP 3.9 is now "a release with no promise of stability" (`:72`, `:83-88`, `:163-166`), so the condition cannot be met by it.
- **Fix:** "The last milestone, after 0.5.0", and restate the condition, for example "the language held still, as 1.0 will say".

**D8.** `docs/plan.md:195-197`, MVP 4.0, "Nothing of it goes into 0.4.0, whose notes say what the shell does not yet do".
- **What is wrong:** 0.4.0 shipped on 2026-10-18, and MVP 4.0 comes after 0.5.0.
- **Fix:** "into 0.5.0".

**D9.** `docs/plan.md:100-101` and `:104-108`, MVP 3.9's done item *The nodes' design note*.
- **The text:** "the proposals stay as the record ... until the sweep below", then "Its sources, in order: ... `mvp3.0.md` to `mvp3.2.md` ...; `nodes.md` and `code.md` ...; `set_aside/` ...; `experiments/` ...; `other_systems.md`".
- **What is wrong:** the item is done, and the sweep removed `docs/proposals/nodes_and_code/` (`:124-129`). This is a done item's paragraph citing files that are gone, which CLAUDE.md's *A step forward sweeps* says should go. `document_paths_test` skips the plan, so nothing caught it.
- **Fix:** cut both sentences.

**D10.** `docs/design/runtime.md:35`, "The host's persistent terms, one word each and replaced rarely, ...: the system processes' pids, the holder of a source, and the toolchain's own modules; a top-level binding's value".
- **What is wrong:** the list is incomplete, and "one word each" is false.
  - `own_modules` is a map of every toolchain beam (`ern_rt.erl:1929-1937`).
  - The runtime also keeps `ern_peer`'s `names`, `nodes`, `named` and `services`, maps that are replaced at each configure, a reload among them (`ern_peer.erl:86-90`).
  - It also keeps `ern_tty`'s `found` and `ern_os`'s `umask`.
- **Shows it:** `grep -rn "persistent_term:put" erl/runtime/src`.
- **Fix:** list them all, and replace "one word each" with what is actually true, for example "small, set once a launch or a reload".

**D11.** `docs/architecture.md:168`, the `ern_launch` row lists `{reading, Kind}`, `{entry_process, Pid}`, `{deadlock_victim, Pid}`, `{ending, Runner, Launch}`, `{wait_over}` and `{utilization, Utilization}`.
- **What is wrong:** it omits the table's main row, `#launch{}` keyed `launch` (`ern_rt.erl:245`, `:3163`), which line 234 of the same document names. The other descriptions are incomplete in other ways:
  - `design/runtime.md:30` omits the `{ending, ...}` row, and lists the `#launch{}` fields without `stderr` and `node`.
  - The glossary's *Launch* in `docs/style.md` calls `#launch{}` "the one row of `ern_launch`" and omits `stderr`.
- **Fix:** add the `#launch{}` row to architecture.md; add the ending row to runtime.md; in the glossary, "its main row", with every field.

**D12.** `docs/architecture.md:339`, "test/fixtures/golden holds the Erlang emitted for `hello` and `services` of `test/fixtures/programs` (`golden_names/0`)".
- **What is wrong:** `golden_names/0` (`ern_emitter_tests.erl:246`) lists every program of `test/fixtures/programs` plus `hello` and `services`, which live under `examples/`. `development.md:265-267` has it right.
- **Fix:** use development.md's wording.

**D13.** Function arities that have drifted:
- `architecture.md:179`: `run_tests/5` is `/6` (`ern_cli.erl:1458`), and line 312 of the same file says `/6`.
- `architecture.md:308`: `recorded_uses/3` is `/4` (`ern_build.erl:1120`), and `built/3` is `/4` (`ern_build.erl:180`).
- `docs/style.md:74`: `unfixed_mailboxes/1` is `/2`.
- `docs/style.md:138`: `ern_canonical:recorded_source/2` is `/1`, as `architecture.md:147` says.
- **Shows it:** dump every `{M,F,A}` from the beams' `debug_info`; the script is in the scratch directory under `tools/`, `funs.escript` and `refs.py`.
- **Fix:** correct each arity.

**D14.** `docs/development.md:46`, "shared, the three modules beneath every stage".
- **What is wrong:** `erl/shared/src` holds four modules: `ern_chunk`, `ern_diagnostic`, `ern_namespace` and `ern_tree`. `architecture.md:17-20` lists all four.
- **Shows it:** `ls erl/shared/src`.
- **Fix:** "the four modules".

**D15.** `docs/development.md:110-111`, `make test-full`: "build, then the unit tests, then every area below, one after another".
- **What is wrong:** `Makefile:237-242` runs test-guide, the Emacs tests, the unit tests, test-library, test-docs, test-grammar and test-typed side by side in one phase. Only test-shell and the six program parts run one after another.
- **Fix:** describe the two phases.

**D16.** `docs/development.md:209-210`, "make bench whole is the closing run before a commit that closes a plan item"; the comment at `Makefile:339-341` says the same.
- **What is wrong:** which run a commit needs belongs to CLAUDE.md's *Tests*, as development.md itself says at `:282`. CLAUDE.md's *Tests* and *Closing an item* name `make test-full` and no bench run. So either CLAUDE.md lacks a rule, or development.md states a stale one.
- **Fix:** decide it, and state it once in CLAUDE.md, with development.md pointing there.

**D17.** `tools/release/README.md:26-38`, *Where to begin*.
- **What is wrong:** it omits the tour, which `design/install.md:23` installs as `share/doc/ernest/tour/` and which `README.md:28` puts first of its three ways in (MVP 3.3, 2026-10-24). It still says of the guide "Start there".
- **Fix:** add `share/doc/ernest/tour/README.md`, and give the three ways in as README.md does.

**D18.** `docs/README.md:3` and `docs/development.md:9`, "the two READMEs that stand beside the code".
- **What is wrong:** besides `src/shell/README.md` and `editors/emacs/README.md`, the repository has `examples/README.md`, `tools/release/README.md` and `assets/README.md`, which no index lists.
- **Shows it:** `git ls-files | grep README.md$`.
- **Fix:** list all five, or drop the count.

**D19.** `docs/development.md`, the layout's lists.
- **What is wrong:** the `test/` entry (`:52-59`) omits the tour's tests (`ern_tour_tests`), the installation's (`ern_install_tests`), the manual pages' (`ern_manual_tests`), and the bench's memory (`ern_last_run`, `ern_measure_tests`). The `tools/` entry (`:85-89`) omits `tools/paragraphs.sh`, which `make paragraphs` and `make test-docs` run.
- **Fix:** add them.

**D20.** `docs/development.md:97`, "A file that is not a module is named with underscores, but for the Emacs mode's".
- **What is wrong:** all six logos in `assets/` are hyphenated, `ernest-combined-light.svg` among them, and so are the site proposal's icons.
- **Shows it:** `git ls-files | grep -e '-'`.
- **Fix:** name the logos as a second exception.

**D21.** `assets/README.md:7-11`, where each logo is used.
- **What is wrong:**
  - It says `ernest-mark.svg` is used in "a document's navigation, and the site's header". No tracked document outside the site proposal uses it.
  - `ernest-avatar-64.png` is "the site's favicon", but the site does not exist yet (MVP 4.2).
  - The full logo appears in "the guides", but only `guide/language.md` and `guide/deployment.md` show it, not why.md, faq.md or style.md.
- **Shows it:** `git grep -n ernest-mark -- ':!assets' ':!docs/proposals'` finds nothing.
- **Fix:** mark the site's uses as planned, and name the two guides.

**D22.** `docs/principles_review.md:36`, the decision "`later`, to the log's *Later* with what would change it"; and `docs/memory.md:96`, "*A let-go of a node's units* under its *Later*".
- **What is wrong:** CLAUDE.md's *Design* says "nothing is kept for later", and `plan.md:9-11` says "nothing stands between". I suspect the log's *Later* list belongs to an earlier rule; I cannot check without the log.
- **Fix:** replace `later` with "an item of a milestone, or `dropped`", and cite the log entry by its title in memory.md.

**D23.** The site proposal is stale against the repository:
- `docs/proposals/site/README.md:52-53`, "The tour, whose document MVP 3.3 writes; until then the prototype has no tour pages", and `decisions.md:223-224`, "named when MVP 3.3 writes it". MVP 3.3 is done.
- `decisions.md:82-84` speaks of "the guide's §0 list 'What Ernest adds' ... which the documents test holds equal to ... the README's". Guide §0 is "What the compiler refuses" and holds no such list, and no test holds one.
- `decisions.md:306-323` speaks of "the README's list of four ...; Why's four pieces ... as the documents test finds it". why.md has six claims, and no test reads them.
- **Fix:** bring these lines up to date at the proposal's next sitting; decisions.md says a decision changes there, with its date.

**D24.** `docs/proposals/ernest_host/ponderings.md:40`, "no records in the runtime's data (plain tuples and maps); ... no process dictionary", and `:64`, "the thirteen frames".
- **What is wrong:** since MVP 3.29 the look's marks live in the process dictionary (`FOREIGN`, `TIMED`, `CALL`, and `#acting{}`). The runtime keeps records: `#launch{}`, `#reaper{}`, `#kept{}`, `#waited_for{}`. The frames are fifteen.
- **Severity:** low. Section 3 is headed "Counted on 2026-10-12", and a pondering is a record.
- **Fix:** none, or "as of 2026-10-12" on the frames line.

**D25.** `docs/plan.md:42`, the MVP 2.6 row's link text, `[shell_design.md](design/shell.md)`.
- **What is wrong:** the link text keeps a name the file no longer has.
- **Fix:** `design/shell.md`.

**D26.** `docs/plan.md:325`, "`findings.md`'s C1-2", and `:332`, "`language_feedback.md`'s entries 97 and 98".
- **What is wrong:** neither document holds these now. findings.md is gone, and language_feedback.md is empty, its next entry 149. The table rows cite findings.md "as it stood at" a commit, and these two lines do not.
- **Fix:** add "as it stood at `<commit>`" to each.

**D27.** Three descriptions of `docs/diagnostics.md` disagree:
- `docs/README.md:18` says it catalogs "the errors the lexer, the parser and the checker give".
- `docs/diagnostics.md:3` says "the lexer, the parser, the checker and the build".
- `development.md:268` says "the front end's errors".
- **Fix:** use the catalog's own wording everywhere.

#### Clarity and ownership

**D28.** `docs/full_review.md:46`, D's brief.
- **What is wrong:** it says D reads "every tracked Markdown file but the report, the guide, the log and docs/man's generated pages". The list that follows omits `ACKNOWLEDGMENTS.md`, `examples/README.md` and `tour/README.md`, so the rule and the list disagree, about tour/ above all.
- **Fix:** list them all, and say whether `tour/` is D's.

**D29.** CLAUDE.md's *Who owns each fact* has no row for `examples/README.md`.
- **What is wrong:** `README.md:64` and `development.md:44-45` point at it as the list of example programs by topic, so a kind of fact has an owner that the table does not name.
- **Fix:** add the row.

**D30.** `docs/style.md`'s toolchain glossary restates mechanism and reasons that `design/runtime.md`, `design/nodes.md` and the log own.
- **Examples:** *Launch* ("which goes with its table at the end so that no launch erases a persistent term"), *Killed* (the kill's steps), *Look, Key* (what the look reads and when), *Waiting* and *Kept*.
- **What is wrong:** those restatements have already drifted (D11).
- **Fix:** keep each entry to the name, what it names and where the code holds it, and point at the note for the mechanism.

**D31.** CLAUDE.md says the runtime's design note "states no why".
- **What is wrong:** `runtime.md:35` ("since replacing or erasing a larger term makes every process scan its heap") and `:59` ("which is why a launch reads the host's facts again") both give reasons.
- **Fix:** move the reasons to the log, or relax the CLAUDE.md line.

**D32.** `docs/plan.md:131-134`, "The attached shell's, the site's and `ernest_host/` stay for the milestones after 0.5.0, each going as its milestone closes".
- **What is wrong:** `ernest_host/` is "nothing planned" (its README) and has no milestone to close.
- **Fix:** say what ends it.

**D33.** `docs/plan.md:72`, MVP 3.9's "Done" cell.
- **What is wrong:** it holds "the end of the planned road, 2026-10-13; the split of `make test` done 2026-10-13, taken early", which is not a date done.
- **Fix:** move the text to the section.

**D34.** `docs/architecture.md:333`, "`make test-full` runs every kind below".
- **What is wrong:** the last subsection below is *Outside `make test-full`*.
- **Fix:** "every kind below but the last subsection's".

**D35.** `docs/plan.md:43` and `:74` both record `libs/markdown`, done 2026-09-25, under MVP 4.1, once as a row of its own and once in MVP 4.1's row.
- **Fix:** keep one.

#### Kept for a reason an earlier milestone had

I cannot read the log, so each of these is a suspicion, with its reason.

1. `full_review.md:3`: "The first, on 2026-09-28, read the code only where it had changed..." is history inside a procedure, and the reader counts of D1 date from that first run.
2. `plan.md`, MVP 3.9: the done items keep whole paragraphs. They are the nodes' note with its gone sources (D9), the proposals' sweep, the process-only mark, `self` and `monitor`, and the two tests' race. CLAUDE.md says a done item's paragraph goes in the step's commit.
3. `plan.md:320-321`, MVP 4.3 item 4: "A shell attached to a running node: MVP 4.0's since 2026-10-13" is kept only to say it moved.
4. `plan.md:236-239`: "that a program adds with `--load-path`" predates MVP 3.28's default load path (D6).
5. `plan.md:341` and `:349`: MVP 4.4 as "first after 0.5.0", with "the language promised (MVP 3.9)", from when MVP 3.9 was to be 1.0 and the back end came first (D7).
6. `plan.md:195-197`: "Nothing of it goes into 0.4.0" predates the 0.4.0 release (D8).
7. `principles_review.md:36` and `memory.md:96`: the log's *Later* list, which CLAUDE.md's "nothing is kept for later" seems to have removed (D22).
8. `principles_review.md:18`: "It reads peers too, built in MVP 3.0 (the log's *MVP 3.0 Read Without a Release*)" is a reminder from when peers were new. §8.3 and §8.7, which P reads anyway, now hold them.
9. `docs/README.md:3` and `development.md:9`: "the two READMEs beside the code" predates `examples/README.md` (2026-10-17), `tools/release/README.md` and `assets/README.md` (D18).
10. `development.md:209-210`: "make bench whole is the closing run before a commit that closes a plan item" is a milestone's rule (plan MVP 3.295) that CLAUDE.md never took up (D16).
11. `design/emacs_mode.md:5`: "The plan's MVP 2.9 is its roadmap entry", though MVP 2.9 is now a done row and no longer an entry of the roadmap.
12. The site proposal's "MVP 3.3 writes" lines, and its "list of four" (D23).
13. This one is in the code, outside my area, for reader C: `test/ern_docs_tests.erl:57-60` still exempts `docs/guide_feedback.md` from the citation check, a document that no longer exists.

#### Lists that live in two places, and the test that holds each

| List | Places | Test |
|---|---|---|
| The six claims | README.md:17-22, guide/why.md:11-16, why.md's `###` headings | none (development.md claims one, D3) |
| The logo's `<picture>` block | assets/README.md, README.md, tools/release/README.md, guide/language.md, guide/deployment.md | none |
| The Emacs mode's init lines | editors/emacs/README.md, ernest-mode.el's header | `emacs_installation_test` (test/ern_style_tests.erl) |
| Reserved words and operators; precedence | ernest-mode.el, the lexer; the parser | `emacs_mode_mirrors_the_lexer_test`, `emacs_mode_mirrors_the_parser_test` |
| The Emacs mode's eight tests | design/emacs_mode.md's table, editors/emacs/test/, Makefile `EMACS_TESTS` and typing | none |
| The runtime's shared tables | design/runtime.md, `ern_rt:tables/0` | `runtime_tables_test` (names only) |
| The tables, with their rows | architecture.md's *The tables*, runtime.md's list, the code | none (drifted, D11) |
| The fifteen frames | design/runtime.md, report §8.7 *What passes*, the gateway, peer and exchange code | `runtime_frames_test`; nodes.md's "fifteen" and the glossary's frame names: none |
| Modules by stage and the runtime's shims | architecture.md's tables, erl/*/src | none (complete today) |
| The processes | architecture.md's *The processes*, the code | none |
| The code table's keys | architecture.md:263, ern_code's header | none |
| The shell's foreign functions, 37 | design/shell.md's *The foreign interface*, `foreign fn`s in shell.ern and complete.ern | none (equal today) |
| The shell's commands | `Shell.Command.commands`, report §11.2 *Commands* | `commands_mirror_test` (test/ern_shell_tests.erl) |
| The shell's modules | src/shell/README.md's table, src/shell/shell/*.ern | none |
| The loads | memory.md's table, test/Makefile `LOADS` and the shell's load | none |
| The memory regression tests | memory.md:119-122, the test modules | none beyond `document_paths_test`'s paths |
| Refusals for a later MVP | development.md's table, the code's texts | `mvp_refusals_listed_test` (erl/cli/test/ern_cli_tests.erl), one direction only |
| The first-party libraries | development.md:79-81, plan.md:242-245, src/libs/, Appendix G | none |
| The bench's parts, the six program parts, the bench's tables | development.md, Makefile `BENCH_PARTS` and `PROGRAM_PARTS`, test/Makefile | none |
| The review's readers | full_review.md, release_review.md, the counts | none (drifted, D1) |
| The documents | docs/README.md, docs/, development.md's layout, CLAUDE.md's owner table | none |
| The tour's programs | tour/README.md's blocks, tour/1/ to tour/8/ | `tour_blocks_shown_test` |
| A documented module | docs/module_doc_template.md, `ern doc`'s page | ern_cli_tests.erl around :3920 |
| The diagnostics catalog | docs/diagnostics.md's outputs, the compiler | `diagnostics_test_` (test/ern_guide_tests.erl) |
| The manual pages | docs/man/, `make man`, docs/man/README.md's release | `pages_test` |
| docs/style.md's tested rules; the `-receives` kinds | docs/style.md, the code | test/ern_style_tests.erl; `receives_test` |
| Borrowed files | THIRD_PARTY_LICENSES, the tracked files | `third_party_test` |
| The report's contents lists | the contents lists, the headings | `contents_test` |
| The installed tree; the launcher's flags | design/install.md, tools/install.sh; install.md, bin/ern | `installation_test_` for part of the tree; none for the flags |
| The peers' wait time | test/fixtures/peers/harness.ern's `waitMs`, `ern_nodes_tests`' `?WAIT_MS` | `fixtures_wait_ms_test` |
| The release review's six machines | release_review.md, the Makefile's targets | none |

### Reader C1


Read at 1329d1d2, only where the code changed since fb2324e8. I read each changed function whole, with the functions it calls and its tests. The lexer, the formatter, `erl/json`, `ern_tty_signal` and `editors/emacs` did not change, so I did not read them.

**The brief names a file that does not exist.** It lists `erl/cli/test/ern_shell_tests.erl`, but the shell's tests are `test/ern_shell_tests.erl`, and `changed.diff` left that file out. I read its changes with `git diff fb2324e8 1329d1d2 -- test/ern_shell_tests.erl` (231 lines; saved as `shell_tests.diff`).

#### Defects

**C1. `:doc` of a type's member shows no parameter names, though `ern doc` shows them.**
- Where: `erl/cli/src/ern_shell.erl:1649` `parameters/3`, which `module_doc/2` reaches through `module_signature/4` (1866) and Shift-Tab reaches through `call_signature/3` (1523).
- The code: `Keys = [entry_name([Name]) | [entry_name([lists:last(Namespace), Name]) || ...]]` is looked up in `beam_of(Session, Namespace)`.
- What is wrong: a member's entry `Point.compare` lives in the beam of the type's module, `Shape`. The code looks in the beam of `Shape.Point`, a module that usually does not exist, so it finds nothing and the signature drops to the colon form. Report §11.2 (toolchain.md:200) says a name's documentation shows "a function's [declaration] as the page shows it".
- Shown by: `shape.ern` declares `export type Point = Point(x : Int, y : Int)`, `/// Orders two points by x.` above `export fn Point.compare(left : Point, right : Point) : Ordering = Int.compare(left.x, right.x)`, and `export fn norm(point : Point) : Int = point.x + point.y`. Then `ern shell --source-root .` with `:load Shape`, `:doc Shape.Point.compare` and `:doc Shape.norm` prints:
  - `Shape.Point.compare : (Shape.Point, Shape.Point) -> Ordering`
  - `Shape.norm(point : Shape.Point) : Int`

  `ern doc shape.erc` prints `Shape.Point.compare(left : Point, right : Point) : Ordering`.
- Not run: the Shift-Tab signature of `Shape.Point.compare(`. It goes through the same lookup, so I expect the same loss.
- Fix: look up the `Type.name` key in the beam of `lists:droplast(Namespace)`, as `module_doc/2`'s member branch reads the entry.

**C2. One host function is written two ways, in a fault's cause and in its trace.**
- Where: `erl/runtime/src/ern_rt.erl:2318` `trace_line/1`. This is the runtime reader's file, but the defect comes from not using this part's new `ern_namespace:host_function_text/3` (`ern_namespace.erl:120`).
- The code: `Host = io_lib:format("~tw:~tw/~B", ...)`, while `host_function_text/3` uses `"~ts:~ts/~B"`.
- What is wrong: report §8.4 (language.md:944) defines "named as the host names it" by `erlang:+/2`, unquoted, and E.21 (library.md:682) writes a host frame "as the host names it". The trace instead quotes any atom that needs quotes.
- Shown by: `foreign fn quot(a : Int, b : Int) : Int = "erlang:div/2"` with `main` calling `Io.println(Io.show(quot(1, List.size([]))))`. `ern run` prints the cause as `foreign function erlang:div/2 raised error:badarith`, and the trace's first frame as `erlang:'div'/2`.
- Fix: `trace_line/1` writes the frame with `ern_namespace:host_function_text/3`.

**C3. A test comment no longer holds, and it cites a file that is gone.**
- Where: `test/ern_shell_tests.erl:1872-1882`, `private_mailbox_type_test_`.
- The comment: "as the constructor's assertion, written 2026-10-23 after the code, holds `unknown constructor Plain.Add` (docs/findings.md's S2)".
- What is wrong: the assertion now matches `":1:1: Plain.Add is a constructor of Plain.Msg, a type Plain keeps private\n"`, and `docs/findings.md` does not exist.
- Fix: say that the assertion holds §11.5's private-constructor text, and drop the citation.

**C4. No test shows that ending a subscription ends a call its wrap makes.**
- Where: `erl/runtime/src/ern_tty.erl:219`, `unsubscribe/3`.
- The change: `exit(Courier, kill)` became `ern_rt:killed(Courier, kill)`. Its comment says "a call the subscriber's wrap makes in it ends with it (ern_rt:killed/2)".
- What is missing: no test in `ern_tty_tests` or elsewhere covers it. A wrap that makes a call, followed by the subscriber's end or restart, would leave the call's records behind if the change were undone, and nothing would fail.
- Fix: add a test in which a wrap waits in `Address.callForever` on a process that never answers. End the subscriber, and assert that the callee's row and the caller's `CALL` key are gone.

**C5. The report and the code differ on the help for a second positional field in a pattern.**
- Where: `erl/parser/src/ern_parser.erl:1272` `no_second_positional/1`, against toolchain.md:278.
- The code: `fail(Position, "a constructor has exactly one positional field")`, with no help line.
- What is wrong: §11.5 says the `,` "is reported as a second positional field in a declaration is", and the declaration's report has a help line (`ern_parser.erl:377`). The test's reason for leaving the help out ("a pattern does not change the declaration") argues against the declaration's wording, not against having a help.
- Shown by: `type V = V(#(Int, Int))` with `match v { V(x, y) -> x + y }` prints the message and no `help:`.
- Fix: give the pattern a help in pattern terms, `` match the tuple, `V(#(x, y))`, or the fields by name, `V(x = ...)` ``. Or say in §11.5 that the pattern's report has no help.

**C6. A comment changed in this diff calls a non-member a member.**
- Where: `erl/cli/src/ern_shell.erl:1840-1841` (`module_doc/2`, changed) and 1836 (`entry_name/1`).
- The comments: "One of a module's type's members on the load path, `Net.Http.Request.method`", and "a member as `Stack.push`".
- What is wrong: §4.5 (language.md:435) declares a member "only for ... an operator of §2.6, `compare`, and `negate`". The parser refuses `fn Stack.push` (`member_names_test`), and `Main.Stack.push` in `shared_namespace_test_` is the module's function.
- Fix: use a member in both examples, `Shape.Point.compare` and `Point.compare`.

**C7. A wait was guarded against a deadlock fault that the shell cannot raise.**
- Where: `erl/cli/src/ern_shell.erl:3882-3885`, above `holder/3`.
- The comment: "Report §8.6: the host's compiler waits ... so that `Deadlock` is not declared over a binding being made."
- What is wrong: the shell holds the terminal from its start (`src/shell/shell.ern:152` and `:1128`), and `ern_rt:look/0` does nothing while a holder is recorded (`ern_rt.erl:1866`; report toolchain.md:112, "A deadlock is not detected while a shell holds the terminal"). The paragraph was the reason for the `in_foreign` wrapper, which this diff removed, and it now argues for nothing.
- Fix: drop the paragraph, or replace it with one line saying that the shell holds the terminal, so no look runs (§11.2).

#### Clarity, names, specs

**C8. A comment in `ern_tty.erl` documents an attribute that was removed.**
- Where: `erl/runtime/src/ern_tty.erl:33-35`, "Report §8.6: Terminal.size asks the host's `user` process ... so it needs no key of the look's."
- What is wrong: this paragraph replaced the removed `-waits([size/0])`. It stands above nothing, with a blank line before the `-receives` comment, which breaks guide/style.md's rule that a comment stands directly above its declaration. It also repeats the module doc's lines 6-8.
- Fix: move it above `size/0`, cut to its one fact, or drop it.

**C9. Two pairs of names in `ern_namespace` swap the same words and do not say how they differ.**
- Where: `erl/shared/src/ern_namespace.erl:141` and 163, 136 and 157.
- The pairs: `segment_text/1` gives a segment as a string, and `text_segment/1` gives one as a binary. `text/1` gives a name as a string, and `text_segments/1` gives its segments as binaries.
- Fix: name the new pair for its role, a peer's frame, as `frame_segment/1` and `frame_segments/1`, or for its type, `segment_binary/1` and `binary_segments/1`. They have 17 callers; `segment_text/1` has 2.

**C10. `site_text/2`'s spec allows strings that `text/1`'s spec does not.**
- Where: `ern_namespace.erl:148` against 134.
- What is wrong: `site_text/2`'s spec takes `[atom() | binary() | string()]` and passes the list to `text/1`, whose spec takes `[atom() | binary()]`.
- Why strings are allowed: only `ern_rt:trace_line/1` passes them. It hands over a finished text as a one-segment "qualified name", `site_text([Host], Line)` and `site_text([Name], Line)`, where `Host` is a deep char list from `io_lib:format`.
- Fix: give `site_text` the name's text, so that a caller writes `text(QualifiedName)` first, and keep both specs narrow.

**C11. One lookup is written twice, and `Member` names two things in it.**
- Where: `erl/cli/src/ern_shell.erl:1451` `declaring/2` and 1846 `module_doc/2`.
- What is wrong: both changed functions resolve a qualified name to the member's entry first and then to the module's value. They test the same condition two ways: `TypeNamespace =/= []` in one, `length(Segments) >= 3` in the other. `Member` holds the segments `[Point, compare]` in `declaring/2`, and a page lookup, `{ok, Page} | none`, in `module_doc/2`. Neither is a §4.5 member.
- Fix: have `module_doc/2` take `{Beam, EntryName}` from one resolver shared with `declaring/2`, and name the lookup `MemberPage`.

**C12. The prelude listings repeat one line's formatting.**
- Where: `ern_shell.erl:1201` `prelude_namespace_listing/2` against `prelude_listing/1` (1180) and `browse/3`'s values.
- What is wrong: the line `[ern_namespace:text(QualifiedName), " : ", ern_types:format_scheme(Scheme, TypeState)]` is written three times. `prelude_namespace_listing/2` is `prelude_listing/1`'s value part filtered by namespace.
- Fix: one `value_lines(Values, TypeState)` helper.

**C13. `fault_cause/3` depends on an invariant that nothing states.**
- Where: `ern_shell.erl:824`, `{ern, fault, Cause, _Trace} = ern_rt:fault_exit_reason(Class, Error, Stack)`.
- What is wrong: `fault_exit_reason/3` also returns `{ern, carried, _, _}` (`ern_rt.erl:2220`), and its spec says only `tuple()`. The match holds because a carried throw never reaches an input's or an evaluator's catch, and nothing says so.
- Fix: write `{'Fault', Cause} = ern_rt:reason(ern_rt:fault_exit_reason(...))`, or narrow the runtime's spec.

**C14. A test comment cannot be parsed.**
- Where: `test/ern_shell_tests.erl:3528-3530`, `stored_values_go_test_`.
- The comment: "and a fault at the prompt first makes the one term a host's first trace or look makes, the runtime's own modules (ern_rt's own_modules/0)".
- Fix: "the input `1 / List.size([])` faults first, so that the persistent term the runtime makes at its first trace or look, its own modules (ern_rt:own_modules/0), exists before the count begins".

**C15. The parser's new messages are put together indirectly, and quote code unevenly.**
- Where: `ern_parser.erl:683-687` and 1004-1008.
- What is wrong: the `fn` clause gets its fixed message through `instead("expected a type", Token)`, though the token is always `fn`, so the message is always "`fn` is a reserved word, and names nothing". The `()` clause calls `describe(Token)` on a token that is always `)`. Within one help line, `fn` is in backticks and `(Int) -> Int` is not.
- Fix: write the messages literally, and quote both pieces of code in the help.

**C16. `ern_namespace`'s module doc no longer states its job.**
- Where: `ern_namespace.erl:1-8`, "the one mapping between a path's components and a namespace's segments ... Also a qualified name as the source writes it".
- What is wrong: this diff adds `host_function_text/3` (a host function's text), `site_text/2` (a spawn site or a trace frame) and `text_segments/1` (a peer frame's name). None of them is that mapping.
- Fix: name them in the doc block, or move `host_function_text/3` beside its users.

#### Leftovers: things kept for a reason an earlier milestone had

- **C7 and C8** above: the reasons for the `in_foreign` wrapper and the `-waits` list, kept after the mechanisms went.
- **C6** above: the member examples `Stack.push` and `Request.method` date from when a type's member could be any function. §4.5 now allows only operators, `compare` and `negate`.
- **C10** above: `site_text/2` accepts strings only for `ern_rt`'s one-segment use.

**C17. Stale citations in unchanged code, found in passing.**
- `erl/cli/src/ern_shell.erl:1`: the module doc cites "plan MVP 2.6". `test/ern_terminal_tests.erl:5` says "Plan, MVP 2.6.". That milestone is long finished, and docs/style.md asks a comment to cite the report section.
- `ern_shell.erl:752`: cites `ern_emitter:compile/5`, which does not exist. The emitter exports `unit/1` and others.
- `erl/runtime/test/ern_tty_tests.erl:82`: "(finding D1's read-back)". `test/ern_shell_tests.erl` cites bare finding ids, W1, W17, V8, V11, S3, V4 and V1, at lines 1977, 2005, 2075, 2608, 2645, 2735, 2854, 2908, 3698, 3871 and 4324. No reader can resolve these now that the findings files are gone.
- `ern_shell.erl:3866`: `value_key/2`'s comment says "the type that owns it". The glossary keeps "own" for a resource's process and calls the type a member belongs to its MemberOf.
- `erl/runtime/test/ern_tty_tests.erl:119` (`wait/1`) and 248 (`wait_atom/1`): both use `after 2000`, a chosen number with no reason beside it. This diff removed the same bound from `stty/1` and `settings/2`.

**Outside my part, for routing.** These still cite the deleted `docs/findings.md`:
- `erl/emitter/test/ern_emitter_tests.erl:638`
- `erl/checker/test/ern_typecheck_tests.erl:1126` and `:3770`
- `test/ern_docs_tests.erl:53-56` and `:299`, which still special-case the path

#### Read and found sound

- **Receives.** `ern_shell`'s and `ern_tty`'s `-receives` attributes name every `receive` that can wait, each under a fitting kind.
- **Terminal.** `stty/1` and `settings/2` wait with no bound. A port's leftover message no longer matters to the look.
- **Shell.** `fault_cause/3` drops the trace, and §11.2 gives an input's fault its cause alone. `kept_values_line/2` matches §11.2's ground-binding sentence, and `reload_keeps_ground_values_test_` holds it.
- **Browse.** `:browse Address` is per toolchain.md:127.
- **Docs order.** Putting the member first in `declaring/2` and `module_doc/2` follows §4.2.
- **Load path.** `ern_tree:libraries/0` is per §11.1 and §11.2.
- **Parser.** The `fn` and `()` help lines are per §11.5.
- **Unit tests.** I ran `ern_parser_tests` and `ern_tty_tests` with eunit from `/tmp`. All passed but two parser tests that read `examples/` relative to the working directory, which my run did not give them.

I changed nothing in the repository. The programs for C1, C2 and C5 are under `t1/`, `t2/` and `t3/`.

### Reader C2


Read at 1329d1d2: the changes since fb2324e8 in `changed.diff`. That covers ern_types.hrl, ern_bound, ern_canonical, ern_interface, ern_typecheck, ern_types and their tests. I read each changed function whole, with what it calls and its tests. I ran programs with the repository's built beams loaded read-only from scratch, and `bin/ern build` in scratch. Nothing in the repository was written.

#### Defects

**C1. Whether a recursive group checks depends on the order its members are checked in, and that order changes from run to run.**
Places: `ern_typecheck.erl:1343`, `Components = digraph_utils:strong_components(Graph),`; `check_group/2` at 1531 checks the members in that order; `use_effect/4` at 4695 decides at the call.
- `use_effect/4` lets a `: T` caller's call stand only where the callee's effect variable is already marked `value_position`. Where it is not marked yet, the call unifies the variable with none.
- So, in a group, a `: T` member checked before an unannotated member that calls `self` binds that member's effect to none. The member's own `self()` is then refused.
- On OTP 29, `strong_components` gives the members of a component in a different order on each VM start.

Shown: put `fn a(n : Int) = { kill(self()); b(n) }` and `fn b(n : Int) : Unit = a(n)` in `group.ern`. Six runs of `rm -f group.erc; ern build group.ern` exited 1, 1, 0, 1, 0, 1. Each failure said `group.ern:1:24: self needs a mailbox, and this function receives nothing`. The message is also wrong: `a` declares nothing, and the help says "give the function its mailbox type".
- `erl -eval` over a two-vertex cycle prints `[[b,a]]` or `[[a,b]]` from run to run.
- The same program with `fn a(n : Int) : Unit = ...` is always accepted. So adding the inferred annotation changes the verdict.
- Before this change the order already made diagnostics vary from run to run, though not verdicts. `fn a(n : Int) = { receive { after 1 -> Unit }; b(n) }` with the same `b` reports "a needs a mailbox, and b receives nothing" in some runs and "`receive` needs a mailbox, and this function receives nothing" in others.
- The test's note says it "does not cover a recursive group whose other member fixes the variable". Here no member fixes it.

Fix: order each component by declaration order in `dependency_groups/2`, and in `check_group/2` check the members written `: T` after the others.

**C2. A lambda that calls `self` or `monitor` is refused where a function that receives nothing is expected, though the same body bound by `let` or declared with `fn` is accepted. The messages print a type that hides the reason.**
Places: `infer(#e_lambda{})` at `ern_typecheck.erl:4298` marks the lambda's variables, and nothing at the lambda's end reads or drops the mark. `elided_own_effect/3` at `ern_types.erl:339-364` checks `process_only` only; its comment still says "unrestricted". `bound_to/3` at `ern_typecheck.erl:1653` fails silently.
- With `fn run(f : () -> Unit) : Unit = f()`:
  - `fn g() : Unit = run(fn() = kill(self()))` is refused: "the argument does not fit run: a function that receives where one that receives nothing is needed".
  - `fn g() : Unit = { let k = fn() = kill(self()); run(k) }` is accepted, and so is `fn k() = kill(self())` with `run(k)`.
- `type Job = Job(run : () -> Unit)` with `Job(run = fn() = kill(self()))` is refused the same way.
- With `fn id(x : a) : a = x`:
  - `let k = id(fn() = kill(self()))` is refused with "the type of k is not determined (() -> Unit) ... annotate it". The printed type holds nothing undetermined.
  - Following the advice, `let k : () -> Unit = id(...)` is refused with "a function that receives where one that receives nothing is needed".
- By §3.9's letter, the lambda's variable "occurs only in effect positions" of the lambda's type, so it ranges over none too.

Fix: at a lambda's end, read its effect variable as `standing_read/2` reads a `: T` fn's. Where it stands free, the lambda's value takes none for its effect, opened as any such function type is, and the body keeps the variable. Also stop `elided_own_effect/3` eliding a marked variable outside generalization.

**C3. Two definitions with one scheme and one printed type get two hashes when one carries an annotation.**
Places: `ern_canonical.erl:943`, `{TypeForm, Walk3} = type(Type, Walk2)` (the lambda), and 995 (a `let`).
- A lambda's or a `let`'s node type keeps its own effect variable free where nothing fixed it. Generalization writes that variable as none in the scheme.
- The form writes it `{variable, N}`, a variable the scheme does not quantify.
- Shown:
  - `let f = fn(x : Int) = x + 1` hashes `1d4d35ca…`.
  - `let f : (Int) -> Int = fn(x : Int) = x + 1` hashes `5ff128be…`.
  - Both have the scheme `{scheme, [], {arrow, [Int], none, Int}, []}` and print `(Int) -> Int`. The first's lambda holds `{arrow, [Int], {variable, 1}, Int}`.
  - Likewise `fn g(n : Int) : Int = { let h = fn(x) = x + 1; h(n) }` against `fn(x : Int) : Int`, and `fn make() = fn() = Io.println("k")` against `fn make() : () -> Unit = ...`.
- `annotation_left_out_test` claims sources that differ only in such an annotation are one definition. It passes only because each of its lambdas is fixed by a call.

Fix: write as none, in every type a form holds, an effect variable that no scheme of the definition quantifies. Or bind each variable that generalization elides to none in the type state.

**C4. §4.6 and the code disagree on an effect variable left in a parameter's function type.**
Place: `never_in_no_value_position/2` at `ern_typecheck.erl:1642` takes its nones from `ern_types:elided/2`, which keeps "one within a parameter's type".
- §4.6 says "an effect variable left in its type that occurs nowhere but as one function type's effect is none".
- `fn make() : ((() -> Unit receiving e) -> Unit) = fn(g) = Unit` with `export let k = make()` gives `k : (() -> Unit receiving Never) -> Unit`. By §4.6 it is `(() -> Unit) -> Unit`.

Fix: add "outside a parameter" to §4.6, which is the code's and §11.5's rule, or follow §4.6 in the code.

**C5. Low. `added_interface/2` replaces lets and terms of the module given but not its reaches.**
Place: `ern_typecheck.erl:612`, `reaches = maps:merge(Env#env.reaches, Reaches),`. The next lines drop `maps:keys(Values)` from `lets` and `terms` first.
- `ern_canonical:interface/2` keeps only non-empty reaches.
- So a value replaced by one whose reach is empty keeps the reach of the value it replaced. Example: M's member `T.f` over the module M.T's `f` when M.T's interface comes first, a case `add_interface/2`'s comment says it handles.

Fix: `reaches = maps:merge(maps:without(maps:keys(Values), Env#env.reaches), Reaches)`.

**C6. The glossary cites two arities the code no longer has.**
- `docs/style.md:138` (Sourced) cites `ern_canonical:recorded_source/2`. It is `/1` now, with `session_source/2` beside it.
- `docs/style.md:74` (Unfixed) cites `unfixed_mailboxes/1`. It is `/2`.

Fix: correct both lines.

**C7. Two test comments cite a file that no longer exists.**
`ern_typecheck_tests.erl:1126` and `:3770` cite "docs/findings.md's S2" and "S1". `docs/findings.md` is gone.

Fix: cite the log entry, or drop the parenthesis.

#### Clarity, names, shorter code

**C8.** `ern_types.erl:12` exports `effect_variables/1`. Its two outside callers, `signature_scheme/2` and `mark_process_only/2` in ern_typecheck, were removed. Only ern_types calls it now. Fix: unexport it.

**C9.** `bound_to/3` and the comment over `never_in_no_value_position/2` at `ern_typecheck.erl:1636`, "one whose restriction Never does not meet is left free", describe no case: unification with `Never` never fails on a restriction. What is left free is a variable that refuses none, one process-only or marked.
- The name `bound_to` does not say the call may do nothing.
- It sits beside `bound/3`, the unification that cannot fail.
- The glossary gives "Bound" to §3.11.

Fix: correct the comment, and rename it, for example `bound_where_possible`.

**C10.** Names that do not say the work:
- `never_in_no_value_position/2` binds nones first, then Nevers. A name such as `settled_call_type` fits.
- `add_interface/2` and `added_interface/2` are one letter apart for two steps, dropping the shadowed values and adding. Suggest `without_shadowed/2` before `add_interface/2`.
- `standing_read/2` reads as a noun, but it refuses calls. The style wants a verb: `read_standing/2`.

**C11.** The banner at `ern_canonical.erl:723` says "Types and annotations". The annotation walk is gone. Fix: "Types".

**C12.** `code_running_never_test` at `ern_typecheck_tests.erl:977-999` has literal newlines inside its string literals, for example `"...work(n - 1)` followed by a line holding `",`. Every other test writes `\n`. Its last assertion checks only `{error, _}`. Fix: write `\n` and assert the message.

**C13.** Since this change, the `: T` rule is decided by `#effect_origin{declared_none}` (`ern_typecheck.erl:119`, 2386, 4721). The record is documented as "what an effect error names", its labels and help. Fix: keep the switch in an `#env{}` field of its own.

**C14.** The help in `?GUARD_CALLS_HELP` (`ern_typecheck.erl:175`) offers first "bind what the guard needs with a `let` before the `receive`". That cannot apply where the guard's call takes the pattern's own binding, as in the test's own `N(k) when big(k)`. Fix: word the first branch for what does not come from the message.

**C15.** Layout:
- A comment at `ern_typecheck.erl:2339`, "Report §11.5: the labels an error carries...", stands over `checked_body/5`'s own comment, apart from `effect_origin/6`, which it describes. It sat beside the removed `mark_process_only/2`.
- Two blank lines follow `declaration_name/1`.
- The export lists break oddly: `unit_reaches/2,` alone at `ern_canonical.erl:37`, and `let_order/1,` alone at `ern_typecheck.erl:27`.

**C16. Another part's code.** `ern_compile:scheme_arity/2`, over `#scheme{}`, stands beside the new `ern_canonical:scheme_arity/1`, over a form. That is one concept in two functions.

#### Kept for a reason a later rule removed (suspected)

- **`value_position` in the restriction list** (`ern_types.erl:22-27`). The list was made for §3.9's two scheme restrictions, so every reader of it must remember the third:
  - `generalize/3` drops it.
  - `elided_own_effect/3` and the printer ignore it, which gives C2's misleading types.
  - The interface and the form trust that generalization dropped it.

  Suspected cause: the list was at hand. A field of its own on `#type_variable{}` would keep it out of schemes by construction.
- **Per-definition state copied field by field.** Adding `standing` took nine edits:
  - the `#env{}` and `#post_check{}` records;
  - `demand/2`'s clean env and `restore_scope/2`;
  - both `check_value/3` clauses;
  - `post/3`;
  - `post_checks/3`, twice.

  This is a shape from when a definition had two or three such fields. A `#scope{}` sub-record would make saving and restoring one assignment.
- **Group member order taken from `digraph`.** It did no harm while order only chose which error came first. Since `standing` it decides the verdict (C1).
- **`#effect_origin{}` as the place a typing switch lives** (C13): a diagnostics record reused because it already travels with the effect.
- **The export of `ern_types:effect_variables/1`** (C8).
- **`bound_to/3`'s error branch for `Never`** (C9): it can never be taken.
- **Low confidence.** `lookup_global/4` at `ern_typecheck.erl:6067` tests `lookup_type(QualifiedName, Env) =:= undefined` before taking a name as the prelude's. No prelude value shares a type's qualified name (checked against `ern_prelude:values()`). Since `#env.declaring` now records every interface value, "not in `declaring`" may be the test that was meant.

#### Checked and sound, for the record

- The new `standing` reading. A standing variable that is fixed later, waits, is held by a parameter, the result, a capture or an enclosing definition, is refused at the call.
- A wrap returning a foreign polymorphic value under the new rule faults at the return check ("does not match a"), and nothing reaches the mailbox. I ran it under `ern run`.
- `Code.running` at Never with a fixed expected type gives an ordinary mismatch, not a crash.
- No added line passes 100 columns, and no British spelling was added.

Scratch: the probe programs are under this directory: `try/` holds the helper modules and scripts; `prog1/leak.ern` is the foreign-return probe; `prog2/group.ern` is C1's program.

### Reader C3


Scope: what `changed.diff` shows changed since fb2324e8. I read each changed function whole, with the functions it calls and its tests: ground terms, session lines, the foreign call, `raised/1`, float operations, the `$ern_fault` clause, the `Unit` word, named causes, the `'$code'` rows, `ern_docs`' abstract constructors, and the changed tests. Programs were run from the scratch directory through `bin/ern` and through a probe module on the toolchain's ebin path. The repository was not touched.

#### Defects

**C1. A foreign fn declared in a shell startup file gets the wrong line in a trace.**
- Place: `erl/emitter/src/ern_compile.erl:358-370`, `foreign_functions/3`: `{Line, Column, _} = ern_diagnostic:span(Span), ... source = {Line, Column, none}`.
- What is wrong: `unit/5` now moves each definition's lines by the session offset (`session_lined/2`, line 282). Foreign functions keep the line within their input. The change also put a foreign function's call and its raises at that `Source` (`foreign_body/6`), so the trace writes the unshifted line. Report §11.2 and E.21 count lines "within the file for an input of a startup file".
- Shown by: a startup file holding `1 + 1` / `foreign fn boom(x : String) : Int = "erlang:binary_to_integer/1"` / `fn go() : Unit = { let _ = boom("x"); Unit }`, then `let p = spawn(go)` typed at the prompt (`HOME=<scratch>/home ern shell`). The trace prints `boom:1` and `go:3`. It should print `boom:2`.
- Fix: in `unit/5`, add `SessionOffset` to each foreign function's source line, as `session_lined/2` does for definitions.

**C2. A unit made from forms gives a foreign function's frame no line.**
- Place: `ern_compile.erl:133-139` (`from_compiled/5`) and `recorded/2` (lines 309-313); the same holds for `erl/cli/src/ern_arrival.erl:228,262`.
- What is wrong: the `.erc`'s recorded foreign declarations, `{QualifiedName, Scheme, HostModule, HostFunction, Printing}`, carry no source. A unit loaded beside another of its name (the shell, `Code.load`) or made by an exchange therefore builds `#foreign_function{source = none}`. Its definitions' frames keep their lines.
- Shown by: a probe compiled `foreign fn boom...` / `fn go...` / `main` once directly and once through `from_compiled/5`. Direct trace: `erlang:binary_to_integer/1 M.boom:1 M.go:2 M.main:3`. From the compiled form: `... M.boom M.go:2 M.main:3`.
- Fix: record `{Line, Column, none}` with each foreign declaration in `#recorded{}` and in the code frame, and put it in `#foreign_function.source` in `from_compiled/5` and in `ern_arrival`.

**C3. A test comment cites a file that no longer exists.**
- Place: `erl/emitter/test/ern_emitter_tests.erl:638`: "(the skeptics' read of 2026-10-23, docs/findings.md's L21 and M13)".
- What is wrong: `docs/findings.md` is gone.
- Fix: cite the log entry that decided it, or drop the parenthesis.

**C4. A comment still describes the removed foreign-call counting.**
- Place: `ern_emitter.erl:1679`, `function_value/2`: "...the body alternatives share or a foreign call counted, is called where it is made...".
- What is wrong: `ern_rt:in_foreign(fun() -> Call end)` is gone. The emitter makes no fun for a foreign call now.
- Fix: drop "or a foreign call counted".

**C5. A comment speaks of a count where the code sets a key.**
- Place: `ern_emitter.erl:1031-1032`, `timed_receive/4`: "a timed receive counts itself in before, and out first in every body, so the reaper knows it is not waiting".
- What is wrong: it sets and erases the look's TIMED key (`ern_rt:timed/0`, `untimed/0`). There is no count, and the glossary refuses `Count` for the look's keys.
- Fix: "a timed receive holds the look's TIMED key from before it waits until the first thing every body does".

**C6. `ern_descriptor`'s header claims users it no longer has.**
- Place: `erl/emitter/src/ern_descriptor.erl:1-5` ("what the foreign boundary checks a value against, what a checker exposes an address with, and what `Io.show`, `Io.debug` and the shell print a value by") and 14-17.
- What is wrong: its only caller is `ern_shell:run/4` (`ern_shell.erl:684`), which prints an input's value through `ern_show`. The boundary's descriptors and `Io.show`/`Io.debug`'s come from the emitter's own `described/4`, built from forms. `docs/architecture.md` already calls it "the shell's descriptors". The relic behind this is R1.
- Fix: the header says it is the shell's describer of a checked type, for printing.

**C7. `code/4`'s comment does not match the rows it writes.**
- Place: `ern_emitter.erl:704` and `:710`.
- What is wrong: "none for an input of a shell's session" — the row is `{sites, []}`, the empty namespace. The atom `none` means something else everywhere in this code. "The last three rows are the unit's, which unit/1 adds" — `syntax/1` adds them.
- Fix: say "the empty namespace" and "syntax/1".

**C8. A new test waits on a chosen number.**
- Place: `ern_emitter_tests.erl:680`, `trace_keeps_the_runtime_of_a_failure_test`: `receive {stack_here, Stack} -> Stack after 5000 -> error(no_stack) end`.
- What is wrong: CLAUDE.md says never to choose a number for a wait. The message is sent inside the program before `run/1` returns. `float_fault_everywhere_test` in the same file reads such a message with `after 0`. Lines 3488 and 3507 have the same unchanged pattern.
- Fix: `after 0`.

**Observation, not a defect by the report's letter.**
- What happens: a program's function that crosses into foreign code and comes back runs under the wrapper `called/2`, which sets the FOREIGN key. So a receive in it with nothing in flight never faults `deadlock`; the program hangs.
- Shown by: `foreign fn first(fs : List((Int) -> Int receiving Int)) : (Int) -> Int receiving Int = "erlang:hd/1"`, then in `main`, `first([fn(x) = receive { n -> n + x }])(1)`. It ran until the 30 s timeout. The same lambda called directly faults `deadlock` at once.
- Why it is as specified: §8.6 reads "a crossing back into Ernest code" as being inside foreign code, so this follows the report. Principle 1 may question it. It is for the user to decide.

#### Clarity: code that could be shorter, and names

**C9. One walk written twice.**
- Place: `ern_emitter.erl:128-134` (`ground_terms/2`) and `:205-217` (`context/1`, `own_context/1`).
- What is wrong: the two functions walk the bindings with the same comprehension. `own_context/1` exists only for `ground_terms/2`, and it enumerates `Placed`/`ForeignPlaced` again after `syntax/1` already has.
- Fix: `ground_terms/2` reads `#own.grounds` of `context(Unit)` by position, and `own_context/1` folds into `context/1`.

**C10. `compile/5` rebuilds an interface it already has the parts for.**
- Place: `ern_compile.erl:76` and `:96-108`.
- What is wrong: `compile/5` calls `interface/5`, which builds a second `#unit{}` and a second link, though `compile/5` holds the full unit. A module with exported lets builds its link three times per build: in `ern_build`, in compile's `interface/5`, and in `unit/5`. I measured interface/5 at 13 ms against 900 ms for compile on 800 functions, so speed is not the issue; clarity is.
- Fix: `compile/5` sets `terms` from `ern_emitter:ground_terms(Unit, Lets)` on its own unit, and `interface/5` stays for `ern_build`.

**C11. `literal_value/2` does nothing.**
- Place: `ern_emitter.erl:487-488`.
- What is wrong: canonical forms already hold a string literal as a binary (`ern_canonical:literal/2`), and `unicode:characters_to_binary/1` of a binary returns it unchanged.
- Fix: `{term, Value}`, and drop the function.

**C12. `calls/3` has a redundant parameter.**
- Place: `ern_emitter.erl:803-805`.
- What is wrong: the `Standard` argument repeats `#unit.standard`, now that the unit itself is passed.
- Fix: match `#unit{standard = true}`.

**C13. The sites row is found through a trick.**
- Place: `ern_emitter.erl:175`, `{sites, site_name([], Unit)}`.
- What is wrong: it gets the sites' namespace by asking `site_name/2` for the name of an empty declaration.
- Fix: a `site_namespace(Unit)` function, which `site_name/2` uses too.

**C14. A record field read twice under two spellings.**
- Place: `ern_emitter.erl:619`.
- What is wrong: `maps:get(QualifiedName, Own#own.names)` sits inside `init_function/2`, whose head already binds `Names`.
- Fix: use `Names`.

**C15. Names that mean two things.**
- `raised/1` (`ern_emitter.erl:1556`) builds a form that throws a fault. In the same module, `Raised` is the `ern_boundary:raised` call in `foreign_call/6` and `built_descriptor/1`, and the handler's variable list in `called/2`. In `ern_boundary`, `raised/4,6` turns a host exception into a fault. Suggest `thrown_fault/1`.
- `Named` is new in two places: in `foreign_body/6` (`:560`) it is the host function's text, and in `ern_compile:interface/5` (`:98`) it is the definitions the link is made of. Beside them, `Named` in `link/5` and `from_compiled/5` maps references to qualified names, and `init_function`'s `Named` is the `initializing` call. Suggest `HostText` and `Linking`.
- `Linked` (`ern_compile.erl:102`) is a canonical map, not a `#linked{}`.
- `Unit` (`ern_emitter.erl:1965`) is the form of the atom `'Unit'`, where everywhere else in the module `Unit` is the `#unit{}`. Suggest `UnitForm`.
- `named_cause/2` (`ern_emitter.erl:2125`) and `ern_boundary:named/2` are one function under two names. The glossary records both; this is low.
- Tests: the frames of a trace are split by `lines/1` (`:690`), by local `Frames` funs (`:531`, `:1693`), and by inline `binary:split(Trace, <<"\n">>, [global, trim])` in four more tests. Fix: one helper, `frames/1`.

**C16. `--emit-erl` shows causes as bytes.**
- Place: `ern_emitter.erl:2057-2087`.
- What is wrong: `built_descriptor` writes each cause with `erl_syntax:abstract`, so the output shows `<<116, 104, 101, ...>>`. `check_form`'s cause reads `<<"the return of ...">>`.
- Fix: write a binary leaf with `string_binary/1`.

**C17. Comment lines break mid-sentence.**
- Place: `ern_compile.erl:48-50` ("is not kept either. The chunk records / beside the build's facts whether the module / builds") and `ern_emitter.erl:797-799` ("A peer's / spawn reads a reach's / bindings").
- Fix: rewrap the lines.

**C18. The `#linked` comment still says every binding is read through its getter.**
- Place: `ern_unit.hrl:80-81`: "kind, function or value, a binding read through its getter (§4.6)".
- What is wrong: a binding with a `term` is read as its value, not through its getter.
- Fix: say so in the `kind` sentence.

**C19. The module header leaves out a new export.**
- Place: `ern_compile.erl:1-14`.
- What is wrong: the header lists what the module gives, and `interface/5`, the interface with ground terms that `ern_build` writes, is not in the list.
- Fix: add it.

#### Kept for an earlier reason (suspected, from the code alone)

**R1. `ern_descriptor` computes causes no one reads.**
- What is there: the causes in its function, address and Reply descriptors, which call `ern_types:format` for every type, and the exports `describe/4` (its holes are always `[]`) and `cause/3`, which no module calls.
- Why I suspect a relic: its one user, `ern_show`, reads no cause. It looks left over from when the emitter described the typed tree; the emitter now describes forms, and the boundary's descriptors come from there. This change added the named-cause wording to it as well, a third copy beside `ern_emitter:return_cause/2` and `argument_cause/2`.
- Fix: the shell's describer gives the structure alone, or the shell describes through the emitter.

**R2. `#unit.session_offset` holds a number the emitter never reads.**
- What is there: since the lines moved to `ern_compile:session_lined/2`, the emitter only tests the field against `false`, in `site_name/2`.
- Fix: make it a boolean that says the unit is a shell input.

**R3. `#emit_context.namespace` and `.erlang_module` duplicate the unit.**
- What is there: they copy `#unit.namespace` and `#unit.name`. The patterns at `ern_emitter.erl:375` and `:535` match both `namespace` and `unit`.
- Why I suspect a relic: the fields look older than the context's `unit` field.

**R4. `literal_value/2` (C11)** looks older than canonical forms holding strings as binaries.

**R5. `calls/3`'s `Standard` argument (C12)** dates from when `calls/3` took the Erlang module's name and not the unit.

#### Checked and found sound

- Ground terms: a list of 1000 elements, a tuple of 300, `-0.0` given as `0.0`, a UTF-8 string, a ground `let` read in a match guard, a `receive` guard and a bitstring size, and a dependent rebuilt when another module's ground value changes (`ern build --verbose`).
- `Unit` and `ok` at a return's top and nowhere else.
- An Int `/` or `%` by a literal zero keeps "division by zero"; the host keeps the `div` frame.
- Every receive-clause and `raised/1` path ends in the right `{ern, fault, ...}` shape.
- The `called/2` FOREIGN count is balanced by `after`.
- The new exports have specs, and the export order holds.
- Not checked: the log entries the tests cite, since the log is not to be read.

The probe sources and programs are in `work/`: `probe.erl`, `probe2.erl`, `probe3.erl`, `p1.txt` to `p7.txt`, and `home/.ernest/startup` for C1.

### Reader C4


I read every changed function in ern_rt, ern_boundary, ern_code, ern_peer, ern_os, ern_io, ern_fs, ern_tcp and ern_show, with what each calls and its tests. I read them against docs/style.md, docs/design/runtime.md and the report sections they cite: §6.5, §6.6, §6.9, §7.3, §7.4, §8.4, §8.6, §8.7, §10 and E.21. ern_exec.c did not change.

I tested by building and running small programs, under `t/` in this directory.

#### Defects

**C1. A fault in an adapted address's function sends a message to a foreign target. Report §6.5 says the target should be ended by an exit signal.**
- Where: erl/runtime/src/ern_rt.erl:308, `sent({fault, Pid, Fault}) -> Pid ! {'$ern_fault', Fault};`. The kept path on the maker's node goes through the same clause.
- Rule: §6.5 says "a target the runtime did not start, a foreign process (§8.4), has no wait of Ernest's and is ended by the fault as an exit signal".
- Now: every target gets the `'$ern_fault'` message. A foreign process ignores it and lives on.
- Shown by t/p6/main.ern. It host-spawns a process with `timer:sleep(infinity)`, monitors it, and sends 1 to `adapted(sleeper, fn(x : Int) = x / 0)`. The program waits forever (`timeout 10` gives exit 124). The control t/p6b, which uses `kill(sleeper)` instead, prints the Down.
- This clause was touched in this window, when the fault became a whole fault term. The behavior is older.
- Fix: in `sent/1`, end a target that has no `ern_processes` row with `exit(Pid, Fault)`. Keep the message for the program's own processes.

**C2. A trace shows the runtime's frames that live inside a unit, under host names. Appendix E.21 says to leave them out.**
- Where: ern_rt.erl:2302 `traced/1` and 2314 `trace_line/1`. `trace/1` leaves out `own_modules()` only.
- Problem: a frame of a unit's emitted helper is neither the program's nor the host's, and `ern_code:function_text/3` gives `none` for it. Such helpers are the boundary's wrapper fun inside `'$type_N'/0`, `'$spawned'/2` and an arrival's `'$lacked_K'`. These frames are printed in host form.
- E.21 says "A frame of the runtime's, which is neither Ernest code nor the host's, is left out wherever it stands".
- Shown by t/p8/main.ern, which passes `inc` to `lists:map/2` over an atom:
  ```
  Main.main faulted: an argument of Main.inc from foreign code does not match Int
      ern@main:'-$type_1/0-fun-0-'/3
      lists:map/2:2384
      Main.mapList:1
      Main.main:12
  ```
- Fix: in `trace/1`, also leave out a frame of a unit, meaning a module that exports `'$code'/0`, whose function `function_text/3` cannot name.

**C3. A caller that the host ends while it waits leaves its call behind. For a compute, the peer is no longer told, which §8.7 promises.**
- Where: ern_rt.erl:1272. `delivered_down/3` says "A process that ended leaves no call", and it no longer runs `uncalled(Pid)`. At fb2324e8 it did.
- How a process can end this way: report §6.9 names "A process the host ends otherwise, killed by foreign code or by the end of a process it is linked to". Such a process runs neither `after` nor `killed/2`.
- What is left:
  - for a callee on this node, its `ern_callees` row, until the callee restarts or the launch ends;
  - for a compute or a remote call, no second note.
- What §8.7 says (language.md:1086): "Where the caller's time runs out, or the caller ends or restarts while it waits, its node tells the peer, which kills the process".
- `undelivered/2` says the same leftover is "outside §8.4's promise" for a delivery. Neither the program's processes nor §8.7 say so.
- Fix: one of two.
  - Hold the note on the peer's side by a monitor of the caller, so that any end lets the note go and kills the compute. At this node's end, `ets:match_delete(?CALLEES, {{'_', Pid}, '_'})` for an end the runtime did not give.
  - Or, if the leftover is accepted, state that exemption in §8.7 and in this comment.

**C4. A line of the toolchain's own can be lost at a launch's end, and a comment admits it.**
- Where: ern_rt.erl:3648-3655, `end_program/4`.
- The comment reads: "one sent the moment before is written by standard error's process, unless it is still in that process's mailbox as the process is stopped".
- Problem: a `say/2` call between `sink_flushed(stderr)` and the switch of `#launch.stderr` to `none` sends its line to the stderr process. `stop/1` then kills that process with `exit(Pid, kill)`, and the line is dropped silently. Such a call can come from the gateway on a node, for example "the peer X ended".
- Fix: make `say/2` a call on the stderr process (`{'Write', Line, Reply}`) under a monitor, and write through `Outside` when the process has gone. Toolchain lines are rare, so the round trip costs little.

**C5. Suspected race, found by reading and not shown: a monitor asked by an old run's delivery can stand in the new run.**
- Where: ern_rt.erl:1213-1223, `is_caller_live/2`.
- How it happens:
  1. A restart's `fresh_run` asks the reaper and the clock at once.
  2. The reaper handles `new_run` first. Its `abandoned/1` ends only the deliveries that exist at that moment.
  3. The clock then fires an alarm for the restarting process before it handles its own `new_run`.
  4. That delivery's wrap calls `monitor`. The ask reaches the reaper after `new_run`, while the delivery and its recipient are both alive.
  5. The reaper makes the monitor, and it stands into the new run.
- Rule: §6.9 says "What the process has asked the runtime for is canceled, with what is on its way to it". The function's comment covers only deliveries that the reaper's own `abandoned/1` ended. A teller's delivery can do the same.
- This could not happen before this window, when a wrap's monitor belonged to the delivery itself.
- Fix: keep the asking process beside a monitor made for another, and cancel the monitors a delivery asked for when `abandoned/1` ends that delivery.

**C6. The spec of `killed/2` is wrong for its first clause.**
- Where: ern_rt.erl:976, `killed(Pid, ExitReason) when Pid =:= erlang:self() -> exit(Pid, ExitReason);`.
- The spec says `-> ok`, but `exit/2` returns `true` in a process that survives it, one that traps exits or is given `normal`.
- A `{found, _}` reaching this clause would exit with a malformed reason. Nothing reaches it today.
- Fix: end the clause with `ok`, and guard it to the exit reasons it can take.

#### Comments that no longer hold

**C7. The contract of `run_main/3` describes fault outcomes that have changed.**
- Where: ern_rt.erl:2815-2822 and 3194-3197.
- The doc reads "{fault, Cause} if it faulted … and {fault, Cause, Trace} where the fault was a failure of the runtime or a foreign function's raise". The comment on `entry_outcome` reads "the host's stack beside a failure of the runtime".
- Now: every fault of Ernest's gives `{fault, Cause, Trace}`, a deadlock among them (`deadlock_test` expects `{fault, <<"deadlock">>, <<>>}`). `{fault, Cause}` is left only for an end the host gave.
- Fix: rewrite both from `entry_end/2` as it stands.

**C8. Four stale citations.**
- ern_rt.erl:4009 says `dependencies_of/1` is "counted as a foreign call". Since `load/1` lost `in_foreign`, nothing counts it.
- ern_boundary.erl:292 cites "(result/3)". The function is `result/4`.
- ern_rt.erl:1314 and 1708 cite `died/3`. The function is `died/4`. These lines did not change in this window; I noticed them on the way.
- ern_rt.erl:2137-2146, the `entered_foreign/0` comment, lists the waits that mark themselves but leaves out Code.load's (erl/cli/src/ern_code_load.erl:62).
- Fix: correct each one.

#### Matters of clarity and naming

**C9. One host function is written two ways.**
- A cause uses `ern_namespace:host_function_text/3` (`~ts`): `erlang:div/2`, `ern@main:-main/0-fun-0-/1`.
- A trace uses `trace_line/1` (`~tw`): `erlang:'div'/2`, `ern@main:'-main/0-fun-0-'/1`.
- The report does the same: §8.4 writes `erlang:+/2`, while E.21 writes `erlang:'div'/2`.
- Fix: choose one form, the quoted `~tw` since it reads unambiguously, for both, and align the report's examples.

**C10. Some names say half their work, or name two things one way.**
- ern_code.erl:680 `site_name/4` and 709 `sites_name/2` differ by one letter and do different work. Elsewhere, `ern_emitter:site_name/2` and `ern_compile:sites_name/4` are other functions again.
- ern_rt.erl `monitor_made/4`, `monitor_kept/4` and `monitors_kept/3` are three near-names for steps of keeping one monitor.
- `is_caller_live(Caller, From)` also checks `From`.
- ern_peer.erl:183/187 `gateway_answer/3` and `gateway_answered/3` differ by a suffix: the first marks the wait as foreign code, the second waits.
- Fix: name each by its work.

**C11. The bracket around a foreign wait is written out by hand seven times.**
- The bracket is `ern_rt:entered_foreign(), try X after ern_rt:left_foreign() end`.
- Sites: ern_rt.erl:790 and 3572, ern_peer.erl:184, 249 and 856, ern_code.erl:1055, and ern_os.erl:446.
- Fix: a helper taking the wait would say it once. See also R2.

**C12. `kill_all/1` calls the prelude's `kill/1` for each pid.**
- Where: ern_rt.erl:1598, `lists:foreach(fun kill/1, Pids)`.
- Problem: `kill/1` carries an acting process's exit and a remote kill frame, neither of which applies to local pids that `started_by/1` found.
- Fix: call `killed(Pid, {ern, killed})`.

**C13. `initializer_name/3` could be shorter and clearer.**
- Where: ern_code.erl:670.
- Problem: it recomputes `lists:last(Begun)` for every element of `Code` and filters on `Begun =/= []` inside the comprehension.
- Fix: a `case` on `Begun` that binds the last element once.
- In the same place, `function_text/3` and the new `bound_name/2` test `erlang:module_loaded(Unit)`. That test adds nothing, because `function_exported/3` is false for a module that is not loaded.

**C14. ern_doc_tests.erl:105-109 hand-writes what EUnit already gives.**
- `passed/2` re-implements `eunit_proc:get_output/0` (`group_leader() ! {get_output, self()}`). Fix: use `?capturedOutput`.
- `tmp/0` (line 95) leaves its directories under `/tmp` when `ERN_TEST_DIR` is unset, which is any run that does not go through `make`.

**C15. Comments cite plan items, which the plan sweeps away.**
- ern_rt.erl:3967 cites "MVP 3.27's measure of the spawn".
- ern_rt_tests cites "MVP 3.27 item 3" three times.
- Fix: cite the log entry that keeps the measure.

**C16. The design note differs from the code in four places.**
- It says `ern_restarts` is "read by a recipient's restart". Its reader is a supervisor's `ask_restart/1`.
- Its list of what a process keeps in its dictionary lacks the start cause (`'$ern_start'`). `restartable/0` and `is_restarting/0` now read it in place of that table.
- It says "Ernest's where the code table holds it as a unit". The code tests for an export of `'$code'/0`.
- It says persistent terms are "one word each", but `own_modules` is a map. The map is put once and never replaced, so it costs nothing, but the sentence is wrong.

**C17. Two `-receives` entries are justified by something other than their kind.**
- ern_os.erl:16-22 justifies `user/0` under `own_process` with "on a node only, which looks for no deadlock". That is not the kind's definition: "a process that is no program's".
- `end_with_program/0` is listed as `answered_at_once`, but its receive is never reached.

**C18. Question: what trace should a fault that a system process asks for carry?**
- Where: `entry_end/2`, `{fault, Launch, Cause}` → `found_fault/2`.
- Now: the fault carries the entry process's stack at whatever moment it is found. §7.3 and E.21 say the trace is "where the fault was met", and this one was met in the system process.
- This needs a decision in E.21 or §8.2.

**C19. Robustness: a peer's kill frame can name any pid of this node.**
- Where: ern_peer.erl:543, `frame(_From, {kill, Pid})`.
- Any pid of this node is accepted, the gateway's worker and the reaper among them. A compliant peer never sends such a frame. The comment in `kill/1`, "any address given here is a program's", no longer holds for this path.
- Fix: correct the comment, or refuse a pid of the runtime's own processes.

#### Kept for a reason a later rule removed (suspected; the log was not read)

**R1. The paragraphs that justified the `-waits` lists outlived them.**
- Where: ern_code.erl:59, ern_io.erl:10, ern_os.erl:16 and ern_peer.erl:32.
- Each now stands detached above a `-receives` block it partly restates. ern_io's is attached to no code.
- Suspicion: the attribute went and its explanation stayed because nothing broke.
- Fix: drop them, or fold what they say into the `-receives` comments.

**R2. The foreign brackets around the peer waits guard a look that never runs.**
- The waits: find, spawn, utilization, `held/4`'s spawner's word, and `ern_rt:compute/3`.
- These waits happen only where peers are configured. That is `ern_cli:run_node` alone, which sets `#launch.node`, and §8.6 says a node detects no deadlock. Elsewhere `node_of/1` is `none` or the node is `nonode@nohost`, and they answer before waiting.
- The brackets, the split functions they need (`gateway_answered/3`, `spawner_word/2`), and `compute_wait_is_no_deadlock_test`'s fake gateway exist because the `-receives` rule demands a kind for every receive.
- Fix: a kind for "a wait only a node makes" would say this without code.

**R3. Every `restarting` writes an `ern_restarts` row and an alias that only a supervisor reads.**
- The process now reads whether it restarts from its own dictionary (`'$ern_start'`). The only reader of the row and the alias is `ask_restart/1` (E.22).
- Every restarting function still makes the shared row and the alias, supervised or not.
- Suspicion: a relic of when the row also answered `is_restarting/0`.

**R4. `said/1` (ern_rt.erl:3103) stands beside `say/2` (3115) as a second way to write a toolchain line on standard error.**
- `said/1` sends to the stderr process with no fallback.

**R5. `'$ern_start'` is written as a literal.**
- The look's keys got macros in this window (`?FOREIGN`, `?TIMED`, `?CALL`), but the start cause is still written as a literal in five places.

#### An observation, not a defect

An idle program whose only pending wait is a timed receive is a common server shape. Each look of such a program now takes the full snapshot and then asks processes one by one until it reaches the one holding `TIMED`. Each ask is a `process_info` signal to the process it asks. The old row count answered this from a table. CLAUDE.md's look rule mandates the new shape. Its cost per look at many processes is not stated, in the log entry named or in the note.

#### Checked and found sound

- `killed/2`'s suspend, read and exit, including two kills at once and kills of trapping socket processes.
- The CALL key's life on every path through a call, a compute, a restart and a kill.
- The look's second read (`still/1`).
- The traces for divisions, initializers, lambdas and List.map callbacks (t/p1, t/p4, t/p5).
- The float and integer badarith causes.
- Foreign sleeps and timed receives, which are no deadlock (t/p7).
- The launch row in place of persistent terms.
- The reaper's map-of-sets bookkeeping.
- `drawn/1`, the new frame shapes, and the busy-port drain.

### Reader C5


Read: every function `changed.diff` touches (fb2324e8..1329d1d2) in `ern_arrival`, `ern_build`, `ern_carrier`, `ern_cli`, `ern_code_load`, `ern_epmd`, `ern_examples` (new, read whole), `ern_exchange`, `ern_gateway`, `ern_node`, `ern_out`, `ern_page`, `ern_signals`, with the functions they call and their tests (`ern_carrier_tests`, `ern_cli_tests`, `ern_code_load_tests`, `ern_exchange_tests`, `ern_node_tests`). I read them against `docs/style.md`, report §2.2, §4.2, §8.6, §8.7, §11 to §11.8, Appendix C, E.0 shape rule 6, E.24, E.28, and `docs/design/nodes.md` and `code.md`. Programs were run under this directory (`t1` to `t8`).

#### Defects

**C1. `ern test` finds doc examples by a regular expression that is not CommonMark, so it skips some examples and splits others wrongly.**
Place: `erl/cli/src/ern_examples.erl:249`, `fences/1`.
Quote: `re:run(Doc, "```ernest\\n(.*?)\\n```", [global, dotall, ...])`.
What is wrong: §2.2 says a doc block is CommonMark 0.31, and §11.2 says the examples run are its fenced `ernest` blocks. The regex knows only three backticks directly followed by `ernest` and a line feed, closed by a line feed and three backticks. So:
- a `~~~ernest` fence is never run;
- a fence whose info string has trailing spaces is never run;
- a fence indented inside a list item is not closed at its own closing fence, and the capture runs on to the next fence anywhere in the block.

An example that should fail can therefore pass in silence, and a valid doc block can produce a failure that makes no sense. The toolchain now has three fence readers that disagree: `ern_parser:fence_of/1` (CommonMark: backticks or tildes, three or more, up to three spaces of indent), `ern_format:fences/1` (a "```ernest" prefix, indented blocks dedented) and this regex. The formatter lays out an indented example that `ern test` never runs.
Shown by: `t2/tilde.ern` holds three fences, `~~~ernest` (expects 7), "````ernest" (expects 8) and "```ernest" followed by two spaces (expects 9), each over `Tilde.twice(3)`. `ern test tilde.erc` prints only `Tilde example 1: failed: expected 8, got 6`; the 7 and the 9 never run. `t2/fence.ern` holds a fence inside a list item followed by a plain fence: the job prints `Fence example 1: failed: unterminated raw string`, where CommonMark has three examples. No current source under `src/` uses these forms, so the gap is latent for the project's own code and real for any program's docs.
Fix: read fences line by line with one CommonMark rule (fence character and length, indent of up to three spaces stripped from the content, first word of the info string `ernest`, a closing fence of the same character at least as long). Share it with `ern_parser`'s `fence_of/1` and, ideally, with the formatter.

**C2. A deadlock in a binding that `Code.load` evaluates hangs forever in a program that is not a node.**
Place: `erl/cli/src/ern_code_load.erl:62` to `72`, `load/1`, with the comment at lines 41 to 44.
Quote: `ern_rt:entered_foreign(), try ... evaluated(Placed) ... after ern_rt:left_foreign()`, and "its caller is inside foreign code for the look while it runs (load/1), whatever the bindings it evaluates wait on".
What is wrong: the whole load, the evaluation of the bindings included, is marked as foreign code, so the look (§8.6) never sees the binding's wait. §8.6 has the runtime read foreign code "from the process, and from a crossing back into Ernest code", and a binding is Ernest code. The code makes an unstated choice that the report contradicts.
Shown by: `t8/lib/plug/stuck.ern` (`let stuck : Int = Address.callForever(spawn(silent), Ask)`, where `silent` never answers), loaded by `main.ern` through `Code.load`:
- `ern run main.erc` waits until `timeout 20` kills it (status 124);
- the same `callForever` written in `main` itself (`main2.ern`) faults with `deadlock` in 0.6 s.

Fix: mark only the reading, placing and loading as foreign and leave the mark around `evaluated/1`. Or, if E.28 ("A node's code after its start") means `Code.load` is for nodes alone, refuse it outside a node and say so in E.28.

**C3. A node reading its load path still names a module "missing at its own path" when a misplaced `.erc` breaks the path-shape rule.**
Place: `erl/cli/src/ern_cli.erl:1856`, `placed/4`.
Quote: `Components = filename:split(filename:rootname(ern_build:relative(File, Root))), _ = held_chunk(ern_namespace:namespace(Components), File, Beam)`.
What is wrong: `ern_namespace:namespace/1` title-cases a component that is no path segment. A file at `lp/Net/http.erc` that holds `Net.Http` therefore gets the namespace it holds and passes `held_chunk`. `whole_build` then looks for `lp/net/http.erc` and fails with exactly the message the function's comment says it avoids. A component such as `bad-dir` gives the namespace `Bad-dir.X` in the refusal. §11.2: "The path-shape rule of §11.1 applies to every `.erc` opened as a module and to each directory between its load-path root and it." This is what is left of the release review's fix (`misplaced_module_test_`), which covers a well-shaped path only.
Shown by (in `t5`, after `ern config --config-dir c --listen 127.0.0.1:0`):
- with `lp/Net/http.erc`, `ern run --config-dir c --load-path lp` prints `ern run: cannot find module Net.Http (net/http.erc) on the load path: a node reads every module of its load path`;
- with `lp/bad-dir/x.erc`, it prints `lp/bad-dir/x.erc holds Net.Http, not Bad-dir.X; build it again from its source root`.

Fix: check each component of the file's path under its root with `ern_build:shape/2` before `held_chunk`, as `ern_cli:shaped/2` does for `ern format`.

**C4. On a node, a reload during a doc example is refused when `--config-dir` is relative.**
Place: `erl/cli/src/ern_examples.erl:104` (`ok = file:set_cwd(Dir)`) together with `erl/cli/src/ern_cli.erl:1139` (`as_node` keeps `ConfigDir` as given) and `ern_carrier:reload/0`, which reads `#configuration.config_dir`.
What is wrong: while an example runs, the host's working directory is the example's temporary directory. A hangup then makes the node read `c/ernest.conf` relative to that directory.
Shown by (in `t7`): run `ern test --config-dir c slow.erc`, whose one example waits four seconds, then `ern reload --config-dir c` while it waits. The job's standard error says `the reload was refused, and the configuration stays as it was: c: no such file or directory`. `doc_example_directory_test` says it does not cover a node.
Fix: hold the configuration directory absolute from the node's start (`ern_build:absolute/1` in `as_node`), and keep writing paths with `shown/1`.

**C5. A version text that is not three plain whole numbers is still taken as a release.**
Place: `erl/cli/src/ern_carrier.erl:137`, `release/1`.
Quote: `[{Major, ""}, {Minor, ""}, {Patch, ""}] when Major >= 0, ...` over `string:to_integer(Part)`.
What is wrong: `string:to_integer("+1")` is `{1, []}` and `string:to_integer("01")` is `{1, []}`. So `+0.4.0` and `00.4.0` are accepted, and each stands on `0.4`'s floor, while the refusal says "three whole numbers". The test lists `-1.3.1` but not these.
Fix: accept a part only when every character is a digit.

**C6. When the client-side check finds no dialing process, it crashes instead of refusing the dial, and the check rests on an undocumented `ssl` behavior.**
Place: `erl/cli/src/ern_carrier.erl:394`, `dialed/0`.
Quote: `[Host] = [Host || {process, Pid} <- Monitored, ...]`.
What is wrong: the comment says "a check that finds none fails, and the dial with it". In fact a badmatch is raised inside `ssl`'s connection process: `ssl_handshake:apply_fun/5` calls the verify fun with no catch. The carrier's logger filter ignores a `{proc_lib, crash}` that is not `net_kernel`'s, so the host's crash report reaches standard error, against §11.2 ("nothing the host says of itself"). The check also relies on `ssl`'s connection process monitoring its user (`ssl_gen_statem`'s `user_application` monitor), which `ssl` does not document. Today the dial and `ssl:connect` happen in one setup process in OTP 29's `inet_tls_dist:do_setup/7`.
Fix: answer `{fail, not_dialed}` and say a line where no host or more than one is found, and name the reliance on `ssl`'s monitor in the comment, with the OTP release it was read from.

#### Clarity, names and comments

**C7. In `ern_examples`, two variables are named for something other than what they hold.**
Place: `erl/cli/src/ern_examples.erl:58` to `66`.
What is wrong:
- `{Owner, Docs} <- documented(...)` names the declaration that documents an example. The glossary's **Owner** is "the process that opened a resource or was given it ... and nothing else".
- `Module = case lists:keymember(inside, 2, Examples) of true -> module_source(...)` holds the module's source, or why there is none. In `example/4` and `checked/3`, `Module` is an `#example_module{}`.

Fix: `Declaration` (or `Documented`), and `Source`.

**C8. `ern_build` gives the "members of a type" function two names, and uses one of those names for something else.**
Place: `erl/cli/src/ern_build.erl:589`, `727`, `758`.
What is wrong: in `parsed_module/4` the function is bound as `Members` and passed to `member_clash/2`, whose parameter is `Members`. It is also passed to `dependencies/4`, whose parameter is `TypeMembers`. Meanwhile `named_modules/4` binds `Members` to the module's own members list (`local_members/1`).
Fix: `TypeMembers` throughout, and `OwnMembers` for the list.

**C9. A comment carries a measured ratio, which will go stale.**
Place: `erl/cli/src/ern_build.erl:745`, `compiled_dependencies/1`.
Quote: "since reading them costs some ten times what the rest of an example's finding does".
What is wrong: the same diff removed "36 milliseconds for the 91 modules" from `ern_carrier:code_digest/0`'s comment. A number belongs in the log.
Fix: drop the ratio, and keep the reason, which is that the namespaces are read once.

**C10. A comment hangs between the export list and the includes.**
Place: `erl/cli/src/ern_code_load.erl:41` to `44`.
What is wrong: the comment that stood over the removed `-waits([load/1])` attribute is now attached to nothing.
Fix: move it to `load/1`. C2 may change it anyway.

**C11. A comment no longer says what the code does.**
Place: `erl/cli/src/ern_build.erl:567`, `parse_module/3`.
Quote: "its namespace checked against its parent's source as it stands".
What is wrong: the namespace check went. The module's exported values are now checked against the members of its parent's type (`member_clash/2`).
Fix: say so.

**C12. A test's comment no longer holds.**
Place: `erl/cli/test/ern_cli_tests.erl:1004`, `libs_dir_one_of_each_name_test`.
Quote: "Where the report is silent, three of one name are named all, their count in figures".
What is wrong: §11.2 now says "Two or more directories of one application's name ... are refused, naming them", so the report is not silent. The message carries no count.
Fix: rewrite the sentence.

**C13. The member-clash message names the parent as a path under the source root.**
Place: `erl/cli/src/ern_build.erl:616`.
Quote: `" in " ++ module_path(Parent) ++ ".ern"`.
What is wrong: the error's header names the child from the working directory (`src/main/stack.ern:4:8:`), but the body says `in main.ern`. Where the parent was read from a `.erc` on the load path, the body names a `.ern` that exists nowhere. The removed `clash/5` used `shown/1`.
Fix: name the module, `in the module Main`, or its file through `shown/1` where there is one. §11.5's example would follow.

**C14. The gateway's `Telling` holds three kinds of thing, and its timer message is not the glossary's.**
Place: `erl/cli/src/ern_gateway.erl:189` to `191`, `261`.
What is wrong: `Telling` now holds a moment, `none` or `departed`. The glossary's **Ms, Deadline** says "a timer's message is `deadline` in every module", and `ern_exchange` follows it in this diff, but the gateway's timer still sends `{tell, Telling}`.
Fix: a field named for the moment (`Deadline`) beside a separate `departed` state, and `{deadline, ...}`.

**C15. The default `listen` is written twice, and `config/3` has one branch too many.**
Place: `erl/cli/src/ern_cli.erl:1047` to `1054` and `897`; `erl/cli/src/ern_node.erl:52` to `66`.
What is wrong: the default `0.0.0.0:8654` is `?LISTEN` in `ern_node` and is written again in `config_options/0`'s help text. `config/3` keeps a `{undefined, undefined}` branch and a `{Listen, undefined}` branch that differ only by `create/1` versus `create/2`.
Fix: one branch, `create(ConfigDir, Listen)`, with the default named once.

**C16. The exchange's time-out text and its start point read differently from what the code does.**
Place: `erl/cli/src/ern_exchange.erl:106`, `asked/4`.
What is wrong:
- `?TIMED_OUT` says "before the function's reach arrived" even where the reach arrived and only code frames were still lacking.
- §8.7 says the time runs "from its ask". The code counts each frame's `ms` from that frame's coming and takes the latest.

Fix: name both in §8.7, or in the text, "before the function's reach and code arrived".

**C17. An unstated rule decides where an example's declarations end.**
Place: `erl/cli/src/ern_examples.erl:395`, `declared/1`.
What is wrong: the declarations are "the paragraphs before its last blank line, where they parse". So an example that declares a `type` and whose expression holds a blank line falls back to the whole body as an expression, and fails. E.0 shape rule 6 states no such rule.
Fix: take the longest prefix of paragraphs that parses as declarations, and state the rule in §11.2.

**C18. A comment says the host's application names are split the host's way, but they are not.**
Place: `erl/cli/src/ern_build.erl:1207`, `application_name/1`.
Quote: "as the host splits it (code_server's split_base/1 and is_vsn/1)".
What is wrong: the host's `split/2` drops empty tokens and `string:split/3` keeps them. So the host reads `foo--1.0` and `foo-1.` as `foo`, and this code reads them as `foo-` and `foo-1.`. The code follows the report's reading, "name-version".
Fix: drop the claim, or cite the report.

**C19. Matching the text of a site to drop `Test.faults` faults.**
Place: `erl/cli/src/ern_cli.erl:1205`.
Quote: `report_fault({'FaultReport', _, <<"Test.faults:", _/binary>>, ...}) -> ok`.
What is wrong: it is exact for today's standard library. But it decides by a function's name in the site text where the runtime already has a notion of an end that is carried, which a compute uses. The shell must repeat the match to honor §11.2.
Fix: the runtime marks the processes `Test.faults` starts, or `faults` starts them through a primitive whose faults are carried.

**C20. The carrier parses back a version text the toolchain itself built from known parts.**
Place: `erl/cli/src/ern_carrier.erl:121` to `147`.
What is wrong: `ern_release:version_text/0` writes `?VERSION ++ ?MARK`, and `cookie/2` splits it at `-` and parses three numbers. That parse is where the release review found the badmatch that `release/1` now refuses.
Fix: `ern_release` exports the parts (the release's numbers, and whether the build is a development one), and the carrier parses nothing.

**C21. A new concept that recurs across modules has no glossary entry.**
Place: `ern_carrier:dialing/1` and `dialed/0`, `ern_epmd:address_please/3`, `docs/style.md`.
What is wrong: the host a dial dials, recorded under `{ern_carrier, dialed}`, recurs across two modules, and the glossary has no entry for it.
Fix: add **Dialed**.

#### Kept for a reason a later rule removed (suspected)

**C22. The code frame's `References`.**
Place: `erl/cli/src/ern_exchange.erl:301`.
Quote: `References = referenced(Forms)` with the comment "a check on the frame alone: the arrival reads its references from the forms themselves".
Why I suspect it: the frame carries the hashes its forms name (§8.7: "and the identities it references"). The receiver recomputes them from the verified forms, refuses a frame where they differ, and uses them no further. The field likely served an arrival that linked from the frame before `ern_arrival` read references from the forms. It now costs bytes and a check.
Fix: drop it from §8.7 and the frame, with a protocol version bump.

**C23. `program/3`'s shape loop.**
Place: `erl/cli/src/ern_cli.erl:1322`.
Quote: `Components = filename:split(filename:rootname(ern_build:module_path(Namespace))), lists:foreach(... ern_build:shape(File, Component) ...)`.
Why I suspect it: the components are derived from the namespace, and the line before already requires the file to be at `module_path(Namespace)`. So for any `.erc` that `ern` writes, the check cannot fail. It likely dates from when the components came from the file's path. It is the check C3 lacks, standing where it does nothing.

**C24. `ern_build:module_path/1` and `ern_build:segment/1`.**
Place: `erl/cli/src/ern_build.erl:430` to `438`.
Why I suspect it: both are one-line delegates to `ern_namespace`. The code calls the same function 20 times through `ern_build` and 14 times directly, one thing named two ways. This diff already folded the `texts/1` copies of `ern_arrival` and `ern_exchange` into `ern_namespace:text_segments/1`. The same step fits here.

**C25. Two shapes of each fault outcome.**
Place: `ern_cli:ended_reason/1` (five clauses, lines 1526 to 1532) and the two delegating clauses of `report_shell_outcome/2` (1420, 1427).
Why I suspect it: they exist because `ern_rt`'s outcome type keeps `{fault, Cause}` beside `{fault, Cause, Trace}` and `{initializer_fault, Site, Cause}` beside its four-field form. Its comment still says the trace comes "where the fault was a failure of the runtime or a foreign function's raise". Every fault has carried a trace since §7.3 and E.21, `<<>>` where the host ended the process otherwise. One shape each, the trace always present, would take four clauses out of the CLI. The runtime is another part's.

#### Read and found sound

- `--verbose` as §11.1 and §11.2 state it (tried on a build, a single-file build and a run).
- `--libs-dir` order and its refusals.
- `ern config --listen` and `--peer-dir`, against §11.3 and Appendix C (tried: another family refused, nested `measures` kept, the peer listed last).
- The exchange's time and its re-arming.
- The gateway's `departing`.
- The build's deterministic order (`ordered/2`), whose namespace order agrees with the path order on every case I tried.
- `member_clash/2` and the `M.T.name` dependency rule against §4.2.
- `ern_out`'s drain through a busy port.
- The abstract type's items left off the page.
- Every new export has a `-spec`, and every new `-receives` list matches its module's waits.

### Reader C6


I read commit 1329d1d2, the changes since fb2324e8 (changed.diff), and read each changed function or target whole with what it calls. The parallel readers' slots were full, so I read the whole part myself.

I checked every hand-stated wait count that names its waits, and each held: runbook 28, tour 81, chapter_1 8, told_boundary 5, exchange 19, pair_program 31, stdin 7, among others. The roughly sixty nodes tests that state a bare number I sampled, not counted.

`test/ern_shell_tests.erl` may belong to part 5 (the shell's tests); its findings here are C5, C10 and C29.

#### Defects

**C1. `ern_last_run` says "No row moved" when it compared nothing.**
- Place: `test/ern_last_run.erl:172-177` (`moved/2`) and `:145-148`.
- What is wrong: a row is matched only by `{TitleShape, Shape, Place, Compared}`. A row whose shape changes is skipped silently, for example by a rename, a new column, or a ratio printed `5.41x` where it was `5.4`. A table whose rows all changed shape is reported as "No row moved by more than a fifth since the last run".
- This diff made such a change. `ern_bench`'s ratio went from `~7.1f` to `~6.2fx`, which also switches the table from `numbers` to `ratios`, so the first comparison after it was blind.
- Shown by: in scratch, `erlc -o beams test/ern_last_run.erl`, then write last/bench.txt with a ratio of `5.0` and bench.txt with `9.00x`. Calling `ern_last_run:compared("lr", ["bench.txt"])` printed "No row moved by more than a fifth since the last run".
- Fix: name the rows and tables on either side that matched nothing, and say "No row moved" only when every row matched.

**C2. `make` no longer removes a gone library's build, which stays on every load path.**
- Place: `Makefile:66-70`, the `libs:` target.
- What is wrong: `shell` and `tools` now depend on `lib-ansi lib-markdown`, and nothing depends on `libs` (`grep -n 'libs\b' Makefile test/Makefile tools/install.sh`). Its loop, "A library whose directory is gone has its build removed with it", never runs under `make`, so the comment no longer holds.
- Consequence: `ern_tree:libraries/0` puts every directory under `build/libs` on every job's load path. A library removed from `src/libs/` stays usable by every program until `make clean`.
- Fix: make `all` (or `manual`) depend on `libs`, or move the loop into a target `all` runs.

**C3. `ern_spawn_costs`'s model of the reaper no longer models the runtime.**
- Place: `test/ern_spawn_costs.erl`, lines below.
- The process row: the model writes 7 fields, `{Pid, Site, Timers, Foreign, Order, Root, Peer}` (`rowed/5:456-460`, `row/1:728`, `root/3:464`). The runtime writes 5, `{Pid, Site, SpawnOrder, Root, Peer}` (`ern_rt.erl:1155`).
- The tables: the model keeps a `calls` table (`tables():389`, `ending/2:569`, `held_ended/3:674`, and the "its call taken" rows at `:716` and `:781`). The runtime has none, since the call is the `$ern_call` key, and it lacks `ern_notes`. Its `callees` table lacks the runtime's write concurrency.
- `parent/0` (`:371`) returns the raw `$ern_acting` value, where `ern_rt:parent/0` matches an `#acting{}` record and its marks.
- The comments cite `table_kind/1` (`:385`) and `monitored/5` (`:8`, `:504`). They are now `table_options/1` and `monitored/6`.
- Consequence: the model and "each alone" tables in spawn.txt, spawn_monitored.txt and monitor.txt measure pieces the runtime no longer has, and leave out the ones it has.
- Shown by: `grep -n 'ets:insert(?PROCESSES' erl/runtime/src/ern_rt.erl; grep -n '^tables()' -A3 erl/runtime/src/ern_rt.erl`.
- Fix: rebuild the model from `ern_rt` as it stands, or drop the model tables.

**C4. Comments cite documents that are gone, and no test catches them.**
- `test/ern_tour_tests.erl:2` cites "docs/proposals/tour/outline.md, sections 3 and 5". There is no `docs/proposals/tour/` at HEAD. "the outline" is then the authority at `:11`, `:48`, `:75`, `:100`, `:106`, `:111` and `:148`, where `tour/README.md` owns the tour.
- `test/ern_shell_tests.erl:1880` cites "docs/findings.md's S2", which is not tracked.
- "the proposal's section N" appears in:
  - `test/ern_nodes_tests.erl:876, 4473, 4626, 4635, 4669, 4691, 4842`;
  - `test/fixtures/peers/desk.ern:425, 509, 526`;
  - `test/ern_node_costs.erl:1-2` ("the peer proposal's section 9").
- Why no test fails: `ern_docs_tests` checks paths that documents name, not paths in code comments.
- Fix: cite `tour/README.md`, the section or the log entry. Extend the path check to the comments of `toolchain()`'s sources.

**C5. A test comment states an assertion the test no longer makes.**
- Place: `test/ern_shell_tests.erl:1878-1880`: "the constructor's assertion, written 2026-10-23 after the code, holds `unknown constructor Plain.Add`".
- What is wrong: the assertion at `:1900` holds ":1:1: Plain.Add is a constructor of Plain.Msg, a type Plain keeps private".
- Fix: state what `:1900` holds, and drop the findings.md citation.

**C6. The comparison against the release's run labels the release's number "last".**
- Place: `test/ern_last_run.erl:160`, `"  ~ts: last ~ts, now ~ts"`, used for both references.
- What is wrong: under "Moved ... since the release's run" a row reads "last 5000.0, now 6500.0". The test holds the wrong word at `test/ern_last_run_tests.erl:216-219`.
- Fix: print the reference's name, "release 5000.0".

**C7. The libraries' tests run twice in `make test-full`.**
- Place: `Makefile:277-285` (`test-library`: `bin/ern test build/libs`) and `test/ern_integration_tests.erl:612-622` (`libs_test_`: `ern test --load-path ../build/libs/ansi ../build/libs`).
- What is wrong: both run every library's tests and examples, one in each phase. That is two ways to do one job (principle 2), at double the cost.
- Fix: keep `test-library`, and cut `libs_test_` down to what it alone asserts (modules named before their cases, nothing faulted).

**C8. The hand-stated wait counts are not checked, and several do not follow the harness's unit.**
- About sixty nodes tests pass `{waits, N}` with a bare number and do not name the waits (`connect_test_` 9, `bound_test_` 14, `reload_test_` 21). The next edit cannot keep such a number true.
- `test/ern_machine_tests.erl:50, 88` give `{waits, 6}` and name nothing. By `?WAIT_MS`'s own unit ("a node's line, its end, ... or runs a command to its end"), `two_nodes/1` makes about 14 steps and `picked/1` about 27, since each `configured`, `edited` and `listed` runs commands.
- `ern_machine:seen/2`, `ended/1` and `run/2` have no bound of their own (`test/ern_machine.erl:189-198, 262-277`). So "a step that fails is told by its own bound" does not hold there.
- Fix: have the harness count the steps a test makes and fail past its count. Give `ern_machine`'s waits `wait_ms()` bounds when tests call them.

**C9. Tests still name the toolchain's libraries with `--load-path`.**
- Places:
  - `test/ern_integration_tests.erl:18` (`?BUILD`), `:91`, `:101-103`, `:616`, `:654-671`;
  - `test/ern_manual_tests.erl:31-35`;
  - `test/ern_nodes_tests.erl:27` (`?LIBRARIES`, used at `:352` and `:1241`);
  - `test/ern_node_costs.erl:23, 58-62, 116-118`, which is new code.
- What is wrong: every library's build already ends every load path (§11.1, §11.2; `ern_build.erl:1158` appends `ern_tree:libraries()`), which is why the Makefile dropped `LIB_PATH`. These runs pass the same directory twice, and none tests what a user does, which is to name no flag.
- Fix: drop the flags and the helpers.

**C10. New `ern_shell_tests` tests choose their limits as numbers.**
- Places: `browse_address`, `float_fault_at_prompt`, `expected_fault_not_reported`, `libs_dir_in_the_shell`, `libraries_in_the_shell` and `reload_keeps_ground_values` at 60, and `shared_namespace` at 90 with `pty(..., 30, ...)` (`:454, 497, 560, 600, 765, 3010, 3030, 3737`).
- What is wrong: the integration and nodes tests now derive every limit from `wait_ms()` steps, so one suite bounds its tests two ways.
- Fix: count steps, as `ern_integration_tests:waits/1` does.

**C11. Run locally, `ern_node_costs` leaves the store running when the desk fails.**
- Place: `test/ern_node_costs.erl:31-34`.
- What is wrong: `main([Dir])` runs `measured/4` with no `try ... after`, while `main([Dir, File])` clears in an `after`.
- Fix: wrap it the same way.

**C12. The release README does not name the tour.**
- Place: `tools/release/README.md`, "Where to begin".
- What is wrong: it lists the guides, the examples, the pages and the report. `tools/install.sh:32` also installs `tour/`, which the README never mentions.
- Fix: add a line for `share/doc/ernest/tour/README.md`.

**C13. docs/development.md describes a bench-foreign row that is gone.**
- Place: *Building*, `make bench`: "the call and its count by eight processes at once beside one".
- What is wrong: `test/ern_foreign_costs.erl:21-25` says the count "was measured before it went". The rows are now the host's call, the foreign fn and the look's key.
- Fix: describe those three rows.

**C14. Stale comments in the Makefiles and their lists.**
- `test/Makefile:249` says "the Erlang twins of the two": there are three.
- `test/machines/machines.txt:1-2` omits `make bench-pick`, which reads the file.
- `Makefile:223-224` breaks a sentence mid-wrap ("so the longest come first. The\n# areas").
- `Makefile:227` says "the six side by side": the second phase now holds seven.
- `Makefile:403-404` says a compiled module and a crash dump "are left wherever a run put them". That reads as kept, though the command removes them.
- Fix: reflow, and correct each count and wording.

**C15. `ern_style_tests` leaves some code files outside the line and tab rules.**
- Place: `test/ern_style_tests.erl:48-53` and `:67-72`.
- What is wrong: the patterns omit `test/fixtures/**/*.erl` (the twins, the probes, `ern_peers_host.erl`, the target modules) and `test/machines/*.sh`. docs/style.md marks both rules *(tested)*. All of these files comply today.
- Fix: add both patterns.

#### Clarity

**C16. Wrong ordinals and stale arities in the bench headers.**
- `test/ern_restarting_costs.erl:1` says "fifth part": it is the sixth.
- `test/ern_burst_costs.erl:1` says "fifth": it is the seventh.
- `test/ern_foreign_costs.erl:1` says "sixth": it is the eighth.
- The arities: `burst:8` cites `monitored/5` (now `/6`), `restarting:104` cites `table_kind/1` (now `table_options/1`), and `foreign:9` cites `check_form/6` (now `/5`).
- `ern_node_costs.erl:13` says "not part of `make test`" where the others say `test-full`.
- Fix: name each part by its target and correct the arities.

**C17. Comments mangled by a citation replacement.**
- `test/ern_pick_costs.erl:1-2` reads "the push's experiment of / the push's experiment".
- `test/fixtures/bench/pick.ern:2-3` reads "the push's / push's experiment".
- Several comments begin "the push's experiment:" where a reference once stood (`:42`, `:56`), and the header's lines 20-24 wrap mid-sentence.
- "the push's pick" (`:6`; `pick.ern:10, 73`) gives a second name to §8.7's pick (`ern_peer:picked/0`).
- Fix: rewrite the headers and say "`Peer.compute`'s pick".

**C18. One helper copied across the bench modules.**
- `median_range/1` exists four times: `spawn:865`, `program:155`, `language:156`, `pick:503`. Pick's averages the two middle values of an even count where the others take the upper, so one name gives two medians.
- The twin table is copied (`program:141`, `language:142`).
- `looped/1` exists three times (`call:170`, `rule:134`, `foreign:221`).
- `downs/1` and `ends/1` are the same function (`spawn:301`, `burst:199`).
- The other parts reach the shared harness through two parts' modules: `ern_spawn_costs:launched/timed/measured/table/at_once` and `ern_foreign_costs:compiled/2`.
- Fix: one bench harness module that holds each of these once.

**C19. The nodes harness's helpers are copied.**
- `address/1` exists in `ern_nodes_tests:119`, `ern_deployment_tests:703` and `ern_tour_tests:185`.
- `configuration/1` exists in deployment `:706`, tour `:181` and machine_tests `:78`; `peer/3` in nodes and tour.
- The backoff `answering` exists in `ern_deployment_tests:676-698` and `ern_machines:304-337`.
- `wait_ms_text/0` exists in nodes `:226` and integration `:1871`. The steps arithmetic exists twice, in `{waits, N}` and in `waits/1`.
- `ern_nodes_tests`'s `made/edit/lists/peer` duplicate `ern_machine_node:configured/edited/listed`, which work on `ern_machine:local()` too.
- Fix: export one of each from the harness.

**C20. The bench parts are listed in three places, and some names differ.**
- `Makefile:351`, `test/Makefile:268` and docs/development.md each list the parts, and no test holds them equal. A third spelling sits in `test/Makefile:113-114`.
- The parts `nodes`, `rules` and `programs` run `ern_node_costs`, `ern_rule_costs` and `ern_program_costs`.
- Fix: rename the modules after their parts and derive `BENCH_BEAMS` from `BENCH_PARTS`.

**C21. test/Makefile repeats its host command.**
- `test/Makefile:200, 271, 357, 376` repeat `erl -noinput -pa ../erl/*/ebin -pa $(EBIN)`.
- `ACROSS` is `PRINTED` but for one removal.
- `bench-library` depends on `benched`, which it does not use.
- Fix: define the command once, and narrow `bench-library`'s prerequisites.

**C22. The launcher and `ern_cli` keep the same list of node jobs.**
- Place: `bin/ern:84-92` (`run | test | shell`) and `erl/cli/src/ern_cli.erl:98` (`["run","test","shell"]`).
- What is wrong: node_flags now runs only when the launcher matched, so its check repeats the launcher's.
- Fix: keep one list.

**C23. Names that do not say what their value is.**
- `ern_machines.erl:215, 221` use `Reason` for a host exit reason, which the glossary calls `ExitReason`.
- `ern_machine:load/1`, and `Loads` beside `LoadsDir` (`ern_code_costs:82, 87`), clash with the glossary's "Not `Load`, which loads code". Rename them `load_average/1` and `LoadAverages`.
- `ern_pick_costs:314` names a fun `Interval1`, though docs/style.md keeps numbered names for changing values.
- `pick.ern:17`'s mailbox type `Done` should be `PickMsg = Answered(...)`.
- `counter.ern:14, 44` names the loop `count` and a parameter `count`; rename the loop `serve`.
- `ern_last_run:131`'s parameter `None` is a format text.
- `ern_measure:236`'s `foreign/2` now measures no foreign call; rename it `host_side/2`.

**C24. A leftover of the removed `in_foreign` wrapper.**
- Place: `test/ern_measure.erl:146-150`: `{Types, Scenarios} = {types(), scenarios(Dir)}`, under a comment on the wrapper's old deadlock.
- Fix: two plain bindings.

**C25. Missing specs on the test harness's exports.**
- `ern_nodes_tests` exports 25 functions with no specs, and `ern_integration_tests` 6.
- `ern_deployment_tests` specs `cataloged/4` but not the new `job/2`, `keyed/1` and `answering/1`.
- The new tools spec every export.
- Fix: state one rule for `test/` in docs/style.md.

**C26. A fixture copies `examples/repl.ern`, and nothing keeps the two equal.**
- Place: `test/fixtures/bench/parser.ern` is repl.ern's lexer, parser and evaluator with the comments cut.
- Shown by: `diff <(sed -n '/^fn tokenize/,$p' examples/repl.ern) <(sed -n '/^fn tokenize/,$p' test/fixtures/bench/parser.ern)`, which shows only comments differ today.
- Fix: a test holding them equal, or a header that says it is a dated copy.

**C27. Hard-coded copies of values another file owns.**
- `ern_program_costs:43` writes "400 by 300 pixels, two rays a pixel", which repeats raytracer.ern's lets, and calls `io_lib:format(..., [])`.
- `ern_rule_costs`'s source repeats `after 1000`, and `ern_call_costs`'s repeats `10000`, beside their `?MS`.
- `desk.ern` repeats `7000` and `75000`, the harness's `?DIAL_MS`/`?DETECTOR_MS`, with no test holding them equal.
- `test/fixtures/session/basic.out:1` holds "Ernest 0.4.0-dev.", which every version bump must edit; `ern_tour_tests` reads `ern_release:version_text()` instead.
- Fix: derive each from its owner, or substitute it in the test.

**C28. `ern_guide_tests` computes the files beside a refused program two ways.**
- What is wrong: `check/1` uses `group/2`'s joined `{tree, Heading}` files. `rewrite/2`, which writes docs/diagnostics.md, appends each named block, so a file shown in two blocks would be written as its last block alone. No such heading exists today.
- Fix: one function for both.

**C29. An ambiguous comment and a reused glossary name.**
- `ern_style_tests.erl:189`: "all but one with `after 0`" reads as "all but one receive".
- `ern_tour_tests.erl:430`: `told/2` reuses the glossary's name for a telling.
- Fix: reword the comment, and rename the function `unasked/2`.

#### Kept for a reason an earlier milestone had

These are suspected from the code alone; I did not read the log.

- **C30.** The `libs:` target (C2) served `shell: libs` and `tools: libs`. The split into `lib-ansi`/`lib-markdown` dependencies orphaned it.
- **C31.** The `--load-path ../build/libs/...` flags (C9) date from before every library's build ended every load path. New code in `ern_node_costs` still follows that shape.
- **C32.** Bench rows that measure forms the runtime no longer uses. development.md's bench text says a number measured once to settle a design is the log's.
  - `ern_spawn_costs` names its pieces "as MVP 3.1 wrote it" and "since" (`:54-72`, `:850-863`).
  - `ern_restarting_costs` has "the row looked for", "written, read and deleted ... as before" (`:190-192`) and "the same without priority" (`:208`).
- **C33.** `ern_docs_tests.erl:53-56` exempts `docs/guide_feedback.md`, which closed at add12b33. Fix: drop it from the list.
- **C34.** `ern_nodes_tests.erl:62-70` keeps `nodes_test(Seconds, ...)` with "as the deployment guide's tests give it", but no caller passes seconds now (`grep -n 'nodes_test(' test/*.erl | grep -v '{waits'`). Fix: fold the clause in and drop the sentence.
- **C35.** The double run in C7: `libs_test_` predates `test-library` and the doc examples.
- **C36.** The job list repeated in C22: `node_flags`'s check predates the launcher's case.

### Reader E


Full review at 1329d1d2. Area: `src/stdlib/`, `src/shell/`, `src/libs/`, `examples/`, `tools/`, and the `ern doc` page of each module read. I read the diff fb2324e8..1329d1d2 (`changed.diff`) with each changed function whole, what it calls and its page: `Test`, `List.mapFold`, `Peer`, `Process.FaultReport`, `Code.load`, and the shell's `reported`, `isExpected`, `reportLine`. I also read the README and tool changes, and the report sections they implement: E.0, E.2, E.21, E.24, E.27, E.28, G, §3.11, §6.9, §7.3, §7.4, §8.7 and §11.2. I also checked the report's own diff since fb2324e8 for rules this area should have followed. Probe programs are under `try1/` to `try5/` in the scratch directory. Every run was fast: a build about 0.3 s, a test run about 0.6 s.

#### Defects

**E1. Every library page still tells the programmer to put the library on the load path.**
- Place: `src/libs/ansi/ansi.ern:9-10`, `ets/ets.ern:9-10`, `json/json.ern:4-5`, `markdown/markdown.ern:11-14`, `proxy/proxy.ern:4-5` and `utilization/utilization.ern:9-10`.
- Quote: "A program puts the library on its load path when it is compiled and when it is run; report Appendix G says where an installation keeps it." Markdown adds: "It styles text with `libs/ansi`, which a run needs on the load path beside it (report Appendix G.2)."
- What is wrong: §11.2 and Appendix G now put each library's build on every job's load path, "so that a program names none of them". The step swept `examples/snake.ern`, `examples/README.md` and `src/shell/README.md`, but left the libraries' own pages. Those pages are also the installed man pages.
- Command: `cp build/libs/ets/ets.erc /tmp/x/ && bin/ern doc /tmp/x/ets.erc` prints the sentence. `ern build snake.ern` with no `--load-path` builds and runs.
- Fix: replace the paragraph with "The library stands on every job's load path, so a program names it with no option (report Appendix G)", and drop markdown's sentence about ansi.
- Report relics of the same rule, outside this area: G.3's "and so needs it on the load path", and E.0 shape rule 6's example "as a library's place on the load path".

**E2. `Test.faults` leaves two processes alive when its caller ends first.**
- Place: `src/stdlib/test.ern:113-127`.
- What is wrong: the judge and `run`'s process outlive a caller that ends before `run` does. That happens to a test the deadlock look faults, and to a shell input the interrupt ends.
  - The caller has no address of either process, so it cannot end them. The judge does not monitor its caller.
  - The page says only that "a process it spawns lives on after it". `computeAt`, by contrast, kills its process when its caller ends.
- Program (`try3/probe.ern`): a test `Test.faults(waitsForever, "division by zero")` faults with `deadlock`. The next test lists the live sites: `["Probe.$tests", "Test.faults:120", "Test.faults:118", "sites"]`.
- Fix: the judge also monitors the caller (`Process.current()` taken before the spawn) and kills `run`'s process when the caller ends. Otherwise the page and E.24 must state that both processes live on.

**E3. The Peer pages say the timing rule badly or not at all.**
- Place: `src/stdlib/peer.ern:26-27`, `:163-165` (spawn), `:228-230` (computeAt), `:152-159` (find) and `:261` (utilization).
- Quotes: the module paragraph says "A find, a spawn, a compute and a utilization wait at most the milliseconds they are given". `spawn` and `computeAt` say "answered within `ms` milliseconds and the step of the attempt, the opening of a connection among them (report §8.7)".
- What is wrong, in four parts:
  - §8.7 now lets the answer come later than `ms` by the runtime's own step of dialing. That holds "for a find, a compute and a utilization as for a spawn", so the module paragraph is now false.
  - "The step of the attempt" means nothing on the page alone. E.0 shape rule 6 asks that a page be read without the report.
  - "The opening of a connection among them" now reads as part of that step. §8.7 counts the opening within `ms`, and only the dial's first steps beside it.
  - `utilization`'s page leaves the phrase out although E.27 states it for a utilization, and `find`'s page leaves it out too.
- Fix: say it once in the module paragraph: "each waits for the peer at most `ms`, the opening of a connection among them; the runtime's own first steps of a dial come beside, so an answer may come later than `ms` by them". Then drop the phrase from `spawn` and `computeAt`.

**E4. `Code.running`'s page lacks the `Never` case that §3.11 and E.28 now state.**
- Place: `src/stdlib/code.ern:108-117`.
- Quote: "`f` is the name of a top-level `fn` of any arity whose result type is `Unit`; where it receives, `receiving m`, `m` holds no type variable, and every process listed has the mailbox type `m`."
- What is wrong: since fb2324e8, §3.11 and E.28 say that a function that receives nothing gives `List(Address(Never))`. The code does this and the page does not say it.
- Program (`try4/main.ern`): `let found : List(Address(Int)) = Code.running(loop)`, with `loop` receiving nothing, is refused with "expected List(Address(Int)), found List(Address(Never))".
- Fix: add "for one that receives nothing, `m` is `Never`, since it runs in a process whose mailbox type it does not know".

**E5. For a peer a reload removed, `FaultReport.spawnedBy` follows neither E.21 nor `ern run`.**
- What the report says: E.21 says `spawnedBy` names such a peer "by its node as §8.7's lines name one".
- What the code does: the runtime answers `None` (`erl/runtime/src/ern_peer.erl:105-114`, whose comment says "or a peer a reload has removed since"). The page agrees with the runtime and not with E.21: `src/stdlib/process.ern:55-57`, "as the configuration lists it (report §8.7), or `None`".
- The shell's line therefore drops the spawner (`src/shell/shell.ern:695-698`). `ern run`'s line names it, ", spawned by the node X" (`ern_cli:report_fault/3` through `ern_carrier:named/1`). That breaks §11.2's "as `ern run` does".
- Even under E.21 as written, the shell's fixed ", spawned by the peer " would call a node a peer.
- Fix: decide it in E.21. Either `None` for a peer no longer listed, with §11.2 saying the shell's line then omits it, or a `spawnedBy` that carries the phrase. Then make the runtime, the page and the shell agree.

**E6. The report and the page do not say that a `FaultReport`'s trace can be empty.**
- Place: `src/stdlib/process.ern:54-62`. The runtime case is `erl/runtime/src/ern_rt.erl:1734-1740`.
- What is wrong: E.21 and the page say the trace is "the innermost twelve frames ... ending with the outermost frame of the program's code". The runtime gives `<<>>` for a process the host ended otherwise (§6.9). The old page said when the trace was empty. The new one says nowhere, yet its example still uses `trace = ""`. Where the report is silent, the rule is to add the sentence.
- Fix: add to E.21 and the page: "and is empty for a process the host ended, which met no fault (§6.9)".

**E7. `Code.load`'s changed paragraph leaves out two of E.28's answers and reads ambiguously.**
- Place: `src/stdlib/code.ern:74-82`.
- Quote: "and a directory or a file at a module's path that holds another module (report §11.2) answer `Left(Invalid)`, and a module the load path lacks `Left(NotFound)`".
- What is missing: E.28's `NotFound` "for a path with no file", which only the example shows, and "for a file the host cannot read the host's error". The words "a directory or a file at a module's path that holds another module" also read as one phrase.
- Program (`try2/main.ern`): `Code.load(Path("sub"))` with `sub` a directory answers `Left(Invalid)`, and `Code.load(Path("/etc/shadow"))` answers `Left(Denied)`.
- Fix: write "a directory, a file at a module's path that holds another module, ... answer `Left(Invalid)`; a path with no file, or a module the load path lacks, `Left(NotFound)`; a file the host cannot read, the host's error".

**E8. `Utilization.runQueue`'s page lacks G.4's new contrast with the node's own measure.**
- Place: `src/libs/utilization/utilization.ern:37-38`.
- What is wrong: G.4 now says `runQueue` leaves the running processes out, where the node's own `run-queue` measure counts them and leaves the measuring one out. A program comparing `runQueue` with `Peer.utilization` cannot learn this from the page.
- Fix: add the sentence.

**E9. §11.2 does not say whether `:faults` shows each fault's trace.**
- Place: `src/shell/shell.ern:838-847`.
- What is wrong: `:faults` lists each kept fault through `reportLine`, which now appends the trace. So each of up to 100 kept faults takes up to 13 lines, where before a fault with one of the language's own causes took one. The report is silent on this.
- Fix: add one sentence to §11.2's `:faults` item, with the trace or without it, and match the code to it.

#### Clarity

**E10. `List.mapFold` takes its name from languages whose shape it does not take.**
- Place: `src/stdlib/list.ern:211-236`, and E.2.
- What is wrong: F#'s `List.mapFold` and Erlang's `lists:mapfoldl` both answer the mapped list first, and their step answers `(mapped, acc)`. Ernest answers `#(acc, list)`, and its step answers `#(acc, mapped)`, which is the order of Haskell's `mapAccumL` and OCaml's `fold_left_map`. A reader who knows the word predicts the other order. E.0 shape rule 10 asks the section to state its reason for departing, and E.2 states none.
- Fix: E.2 states the reason in one sentence (the accumulator stays first, as in `foldLeft`'s step), or the order follows F# and Erlang.

**E11. `Test.faults` reuses the word of `Process.faults` for an unrelated operation.**
- Place: `src/stdlib/test.ern:113`, and E.24.
- What is wrong: `Process.faults(wrap)` subscribes to fault reports. `Test.faults(run, cause)` checks that a call faults. The style guide asks for "one concept, one name, in every module", and E.0 shape rule 10 asks for the predicted word. A reader who knows `Process.faults` would not predict an assertion.
- Fix: take it to the report as a name question, for example a name that reads as the check. Recommendation: weigh it there before more code calls it.

**E12. `Test.faults` names its mailbox type variable `n`.**
- Place: `src/stdlib/test.ern:113`, and E.24's listing.
- Quote: `run : () -> a receiving n`.
- What is wrong: `run` runs in a process of its own, so `n` is that process's mailbox type. `guide/style.md` names a mailbox type `m`, as `Case(m)`'s `run` and `Peer.spawn`'s `f` have it. No other variable in the signature needs `m`.
- Fix: write `receiving m` in E.24, then in the code.

**E13. The shell's `isExpected` says neither what it tests nor who expects.**
- Place: `src/shell/shell.ern:677-681`.
- Quote: `fn isExpected(report) = String.startsWith(report.site, "Test.faults:")`.
- What is wrong: the predicate answers whether `Test.faults` started the process. The same site-text test also stands in Erlang at `erl/cli/src/ern_cli.erl:1205`, so one fact has two owners in two languages (see E23).
- Fix: rename it to `isTestFaults` or `startedByTestFaults`.

**E14. The new "Run one" section of `examples/README.md` can drift, overclaims, and comes too early for an installation.**
- Place: `examples/README.md:7-23`.
- Drift: the console quotes the counts of `hello.ern` and `tally.ern` (`95 495 3375 tally.ern`). They change with any edit of either file, and no test holds the block (`test/ern_docs_tests.erl` strips console blocks). They are right today.
- Overclaim: "Two commands run any program here" is not true of `upgrade/`, which is built as a directory, nor of the two node programs, which need configuration directories.
- Order: in an installation, the instruction to copy the directory first is the README's last paragraph, after commands that fail in a read-only tree.
- Fix: count a fixed input or hold the block by a test; write "most programs here"; move the copy sentence above "Run one".

**E15. `tools/release/README.md`'s "Where to begin" omits the tour.**
- Place: `tools/release/README.md:27-38`.
- What is wrong: the list names every installed document but one. `tools/install.sh:32` installs `tour/`, and the repository's README lists the tour.
- Fix: add "`share/doc/ernest/tour/README.md` is the tour, one program grown through eight chapters".

**E16. `computeAt`'s Errors section uses the old word.**
- Place: `src/stdlib/peer.ern:247-248`.
- Quote: "The caller's node reports it once, with the host's stack that crossed with it."
- What is wrong: §7.3, §11.2 and the glossary now call it the trace.
- Fix: write "with the trace that crossed with it".

**E17. A comment in the shell still says a fault is one line.**
- Place: `src/shell/shell.ern:709-711`.
- Quote: "so that a fault is one line and none of a program's reaches the terminal as itself".
- What is wrong: a fault's report now carries its trace beneath the line.
- Fix: write "so that a fault's line, and each frame of its trace, is one line".

**E18. The `Test` module page's "What it prints" is incomplete.**
- Place: `src/stdlib/test.ern:8-13`.
- What is missing: the trace that `ern test` now prints beneath a faulted test's line, as §11.2 says. `try3/probe3.ern` prints `crashes: faulted: division by zero` and then two indented frames. The page also leaves out how a module's own examples are named, `Math example 1`.
- Fix: add both.

**E19. `src/shell/README.md` adds a third glossary.**
- Place: `src/shell/README.md:87-92`, "The shell's own names", which holds `cursor` and `serial`.
- What is wrong: CLAUDE.md's *Style* puts a name that recurs across modules in `guide/style.md`'s glossary or in `docs/style.md`'s, the toolchain's. The shell's Ernest is the toolchain's.
- Fix: move the two names to `docs/style.md`'s *Ernest* glossary, or state the exception in CLAUDE.md.

**E20. `Shell.History`'s doc block cites a whole file.**
- Place: `src/shell/shell/history.ern:8`.
- Quote: "(docs/log.md)".
- What is wrong: the citation names no entry, where the repository's comments cite "the log's *Title*". It was renamed mechanically from `docs/decisions.md`.
- Fix: name the entry.

**E21. `tools/paragraphs.sh` counts some non-prose lines after a list item.**
- Place: `tools/paragraphs.sh:27-28`.
- What is wrong: a line at or below an item's indentation starts a new paragraph with `skip = 0`, without the skip test. A heading, a table row or an HTML line directly after an item is then counted as prose. `<!-- /contents -->` after the contents lists in `report/*.md` and `guide/language.md` is such a line, harmless today. A CommonMark lazy continuation (an unindented line still in the item) is split from its item, so such an item is undercounted; none exist in the tree.
- Fix: write `skip = ($0 ~ /^(#|\||<)/)` in that branch.

#### Where the language made the code harder

**E22. Waiting for one process's end, from a function that receives nothing, costs a second process and a call.**
- Place: `src/stdlib/test.ern:61-64` and `:113-127`.
- What is hard: `Test.faults` must spawn a judge, which `spawnMonitored`s `run` and is called with `Address.callForever`. A `Down` reaches only a mailbox, and `faults` has none. Each check costs a process and a call, and the judge outlives its caller (E2).
- What is missing: nothing in the library waits for one process's end outside the caller's mailbox.

**E23. A library cannot mark the processes whose faults it expects.**
- What is hard: `Test.faults`'s processes are known only by their spawn site's text, `"Test.faults:"`. That text is matched in Erlang (`ern_cli.erl:1205`) and in Ernest (`shell.ern:681`).
- A program's own `Process.faults` subscriber, such as a logger or its own supervisor, receives those expected faults and can only copy the text match.
- The site depends on which top-level declaration the `spawn` is written in. Moving the spawn into a helper of `test.ern` would silently change it; the tests in `ern_cli_tests` and `ern_shell_tests` would catch that.

**E24. A spawn needs a wrapper to throw away a result.**
- Place: `src/stdlib/test.ern:114-117`.
- Quote: `let call = fn() = { let _ = run(); Unit }`.
- What is hard: a spawned function must return `Unit`, so running a function only for its fault takes a lambda and a `let _`. Minor.

**E25. `Test.faults` is a second wait without a limit, hidden behind its name.**
- What is surprising: E.0 shape rule 8 calls `Address.callForever` "the one wait on another party without a limit". `Test.faults` hides a second one. The deadlock look catches a `run` that waits forever. It does not catch one that loops, and a node detects no deadlock.
- The design is arguable: `run` is the caller's own work, as a direct call is. But a reader who knows rule 8 would not predict it.
- Fix: the page says "it waits for `run` to end, however long".

#### Things kept for a reason a later rule removed

**E26. The libraries' load-path paragraphs.** This is E1: the six pages and markdown's ansi sentence, written when a program named each library with `--load-path`. In the report, G.3's "and so needs it on the load path" and E.0 shape rule 6's "as a library's place on the load path" are the same relic.

**E27. `Peer.offer`'s example uses the service name `"cubes"`.**
- Place: `src/stdlib/peer.ern:137`.
- What I suspect: every other example in the module uses `"squares"`, and the rename came in this diff. It looks like a relic of doc examples run in one program, where the module example's offer of `"squares"` would have made this offer answer `Left`. Now each example is a program of its own (§11.2).
- Fix: harmless; `"squares"` again for consistency, or leave it.

**E28. `process.ern`'s `FaultReport` example builds `trace = ""`.**
- Place: `src/stdlib/process.ern:64-73`.
- What I suspect: an empty trace was the rule "beneath the language's own causes" until this diff. Now only a process the host ended has one (E6).
- Fix: harmless as a construction; a trace of one frame, `"Main.worker:3"`, would read truer.

**E29. Two stale terms.** The comment "so that a fault is one line" (E17) and "the host's stack" in `computeAt`'s Errors section (E16) are wording from before the trace existed.

**E30. The same `Test.faults` filter in two places.** Not a relic, but the same kind of debt: the filter in `ern_cli.erl:1205` and the one in `shell.ern:681` both exist only because the site text is the one handle (E23).

### Reader T


Full review, reader T (the tools), at commit 1329d1d2. Every job ran under /home/jocke/.claude/jobs/6cf4db19/tmp/review/T with `ern` = /home/jocke/projects/ernest/bin/ern (`ern --version`: `ern 0.4.0-dev`). Each finding gives the command, what it did, what was expected, and a one-line fix. T1 to T14 are defects, most serious first. T15 to T38 are findings under the brief and matters of clarity, also most serious first. After them comes a list of things suspected to be left over from an earlier stage.

#### Defects

**T1. A deadlock's trace names the wrong line: the last call before the `receive`, or the function's head, never the `receive` (principle 3).**
- Command: `ern run dl2.erc`, where `main` holds `Io.println(...)` on line 6 and `receive { Tick -> Unit }` on line 7. It prints `Dl2.main faulted: deadlock` with the trace line `Dl2.main:6`.
- More cases. With the `receive` on line 4 as the body's first statement, the trace says `:3`, the `fn` head. A `receive` inside `fn waitHere` (head on line 3, `receive` on line 4) gives `Dl.waitHere:3`. `ern test` shows the same: a test whose `run` is a `receive` on line 4 prints `Waits.stuck:3`.
- Expected: the `receive`'s line, since §0 says a receive is visible "at the line that receives".
- Fix: the emitter gives each `receive` a line of its own in the code's line table, so the waiting frame names it.

**T2. The trace of a faulted doc example names the toolchain's generated functions and their lines, which the user never wrote (principles 3 and 1).**
- Command: `ern test ex2.erc`, where the example's second line, `let b = 10 / (a - 1);`, is line 5 of `ex2.ern`.
- It prints `Ex2.f example 1: faulted: division by zero`, then the trace `erlang:'div'/2`, `$Example1.docExample:3`, `$Example1.docShown:7`.
- A second case: an example that calls a faulting function ends its trace in `$Example4.docShown:5`. The `4` counts examples across the module, while the case is named `Ex.boom example 1`.
- Expected: frames that name the example as its case does, at the line of the `.ern` that holds it, `Ex2.f example 1` at `ex2.ern:5`, and no frame of the wrapper.
- Fix: write the example's frames with the case's name and the doc block's line, and drop the wrapper frame `docShown`.

**T3. `ern config --peer-dir b`, given without `--config-dir`, silently writes `./.ernest/ernest.conf`, a file the command line never named.**
- Command: in a directory that holds `.ernest` from an earlier `ern config`, run `ern config --peer-dir b`. It exits with status 0, prints nothing, and appends `b` to `./.ernest/ernest.conf`.
- Expected: a refusal, `--config-dir is required: it names the directory written`, the way `ern reload` and `ern stop` require it. §11.3 says the peer is listed in "the directory `--config-dir` names, which exists", which reads as if `--config-dir` were given.
- Fix: make `--config-dir` required with `--peer-dir`.

**T4. `ern doc` writes a version that `ern --version` does not have.**
- Commands: `ern --version` prints `ern 0.4.0-dev`, and the shell's banner is `Ernest 0.4.0-dev.`. `ern doc src/net/http.ern` ends with `Generated by ern 0.4.0 from http.ern.`, and `ern doc --man` writes `.TH ... "Ernest 0.4.0"` with the comment `Generated by ern 0.4.0`.
- Expected: one version text everywhere. §11.4 says the document "names `ern`'s version", which is `0.4.0-dev`. As it stands, a development build's documents claim to come from a release.
- Fix: the document and the page take the same version text that `--version` prints.

**T5. A build over a `.erc` of another namespace gives two wrong messages.**
- Setup: `ern build src/net/http.ern` from the project root, with no source root given, writes `src/net/http.erc` holding `Src.Net.Http`.
- First message: `ern build --source-root src src/main.ern` refuses with `no module Net.Http: src/net/http.erc was compiled from src/src/net/http.ern, which no longer exists`. That path was never written; the file holds another module and is not stale.
- Second message: `ern build --source-root src src/net/http.ern` refuses with `src/net/http.erc holds Src.Net.Http, and this build names the module Net.Http; name its source root with --source-root`, although `--source-root` was given.
- Expected: one message, `src/net/http.erc holds Src.Net.Http, not Net.Http`, together with the remedy that applies here, removing that file.
- Fix: test the namespace a `.erc` holds before its staleness, and give the `--source-root` hint only when that option was not given.

**T6. In a read-only directory, `ern format` refuses a writable file and names the file as the cause.**
- Command: `ern format rodir/m.ern`, where `m.ern` is `rw-rw-r--` and `rodir` is `555`. It prints `ern format: rodir/m.ern: permission denied`, and `ls -l` shows that the file is writable.
- `ern build rodir/m.ern --source-root rodir` prints `rodir/m.erc: permission denied` for a file that does not exist.
- Expected: the directory named as the cause, `rodir: permission denied, and m.ern is written whole by a rename there`, or wording to that effect.
- Fix: when the temporary file cannot be created, name the directory.

**T7. `:load` writes its path in neither of the forms §11.5 allows.**
- Command: `ern shell --source-root src --load-path build`, then `:load Net.Http`. It answers `Net.Http, from /home/.../T/p2/build/net/http.erc`, an absolute path, though the file lies under the working directory.
- Command: `ern shell --source-root src`, then `:load Net.Http`. It answers `Net.Http, compiled from net/http.ern`, a path from the source root that does not exist from the working directory.
- Expected: paths from the working directory, `build/net/http.erc` and `src/net/http.ern`, as `--verbose` and the diagnostics write them.
- Fix: write both answers' paths through the one function §11.5's rule uses.

**T8. A run of `ern doc` removes only the kind of file it writes, so stale files of the other kind stay.**
- Commands: run `ern doc --build-root docs src` and `ern doc --man --build-root docs src`, then rename `net/http.ern`.
- The next CommonMark run removes `net/http.md` but keeps `net/Ernest.Net.Http.3ern`.
- A later man run removes the old page but keeps the stale `net/web.md`, and `index.md` still lists `Net.Web`.
- Expected, from §11.4's "A document or a page `ern doc` wrote of a module under the directory whose source is gone is removed": either run removes both kinds.
- Fix: the sweep removes stale documents and stale pages alike, and rewrites `index.md` where it lists a module that is gone.

**T9. In single-file mode, a module cycle gets advice that leads in a circle.**
- Command: `ern build --source-root src src/a.ern`, where `A` uses `B` and `B` uses `A`. It says `compile B first, which A uses: src/b.erc: no such file or directory`.
- `ern build --source-root src src/b.ern` then says `compile A first, which B uses`.
- Directory mode reports `module cycle: A, B` correctly.
- Expected: the cycle reported in single-file mode too, or at least advice that can be followed.
- Fix: before giving the advice, follow the named module's source imports, and report a cycle where one is found.

**T10. The entry-point refusal misstates the rule, and it cites the report.**
- Command: `ern run --main Main.nope build/main.erc` prints `no exported function Main.nope; an entry point is an exported fn of type () -> Unit (report §8.1)`.
- The same text follows `Net.Http.parse is not an entry point: its type is ...`, and `ern shell` prints it too.
- `export fn main() : Unit receiving Msg` runs as an entry point, so `() -> Unit` is wrong.
- No other message of any job cites the report.
- Fix: `an entry point is an exported fn of no parameters whose result is Unit`, without the citation.

**T11. `ern test` reports a killed test as `faulted: Killed`.**
- Command: `ern test waits.erc`, with a test whose `run` is `{ kill(self()); Test.Passed }`. It prints `killed: faulted: Killed`.
- §11.2 names three outcomes, `passed`, `failed`, and `faulted` with the cause, and is silent on a kill.
- `Killed` is a `Reason` apart from `Fault`. `ern run` prints `killed` for a killed entry process, and the shell prints `Killed` for an interrupted input.
- Fix: add the sentence to §11.2, a test that is killed prints `killed`, and print that.

**T12. The `killed` line has neither a time stamp nor a site in a log.**
- Command: `ern run --main Faulty.killer faulty.erc 2> k.err` writes the bare line `killed`. Every other runtime line in such a file begins with the time, and a fault's line names the process.
- Expected: `2026-...Z Faulty.killer killed`, or the like.
- Fix: write the line through the same writer as a fault's line.

**T13. `ern config` creates missing parent directories without saying so.**
- Command: `ern config --config-dir no/such/parent` exits with status 0. It creates `no` and `no/such`, mode 775, as well as `parent`.
- §11.3 says only that the job "creates the directory". The report is silent on parents, so as it stands a typo in the path creates a tree.
- Fix: refuse a parent that does not exist, `no/such: no such directory`, and say so in §11.3.

**T14. `ern run Hello.erc` gives a different message from the one §11.1's path-shape rule gives.**
- Command: `ern run Hello.erc`, a module `Hello` at a capitalized path, says `Hello.erc is not at the path of its namespace Hello`.
- `ern build Hello.ern` says ``Hello.ern: path component `Hello` must be lowercase``, and §11.2 says the same rule applies to every `.erc` opened as a module.
- Fix: check the path shape before checking the namespace, and give `ern build`'s message.

#### Findings under the brief, and clarity

**T15. `ern reload` exits with status 0 when the node refuses the reload (principles 3 and 1).**
- Command: with a node running, write `{ not json` into `a/ernest.conf` and run `ern reload --config-dir a`. It prints nothing and exits with status 0.
- The refusal, `the reload was refused, and the configuration stays as it was: a/ernest.conf: is not JSON`, appears only on the node's standard error, which may be a journal on another terminal.
- `ern stop` waits for the outcome, and its status says the node ended. A user who knows `ern stop` predicts the same of `ern reload`, and the operator does not see the result of the command they ran.
- The report allows this: "`ern reload`'s exit status says only that the signal was delivered".
- Fix: `ern reload` reads the directory as the node reads it (the reading `ern config --peer-dir` already does) and refuses, with status 1 and the node's message, before it signals.

**T16. `.ernest` names two unrelated directories (principle 1).**
- `$HOME/.ernest` is the shell's per-user directory, holding `startup` and `history`. `./.ernest` is `ern config`'s default node configuration directory.
- Command: run `ern config` from `$HOME` after any shell session at a terminal, or with a startup file. It refuses: `ern config: .ernest exists`.
- The report needs special rules to keep the two apart: "Without `--config-dir`, `./.ernest/startup` is not run" and "`.ernest/` under a load-path root is not a module".
- Fix: drop the default, so `ern config` requires `--config-dir` as `reload` and `stop` do (see L1), or give one of the two directories another name.

**T17. `ern config` is two jobs under one word (principle 2).**
- Its help line reads "create the configuration directory, or list a peer in it". `--config-dir` means "the directory made" in one job and "the one written" in the other.
- `--listen` belongs to the first job alone, and is refused beside `--peer-dir`. `--peer-dir` turns off key generation and the printing of the key.
- Each other job word does one job.
- Fix: a job of its own for listing a peer, `ern peer --config-dir a --peer-dir b`, or state in §0 why `config` may be two.

**T18. `:set output n` and `:output path` are two commands about "output" that set different things (principles 2 and 1).**
- `:set output n` sets the number of rows of the live region. `:output path` sets where programs' output goes.
- `:help` lists them three lines apart, with no way to tell them apart from the word.
- Fix: rename the setting after what it sets, `:set rows n` or `:set region n`.

**T19. A version number marks the previous version for a type but the current version for a site (principle 1).**
- Command: `:load Counter`, `let c = Counter.start()`, edit the source, `:reload`, `let d = Counter.start()`, then `:processes`.
- `:processes` lists `Counter$2.start:11` for `d`, the current version, and `Counter.start:10` for `c`, the old one.
- For types it is the reverse: `c : Address(Counter$1.Msg)` is the old version and `Counter.Msg` the current.
- The unnumbered name therefore means "current" for a type and "first" for a site. The report states both rules.
- Fix: number every version's sites after the first load, so `Counter$1.start:10`, or else unnumber the current version's sites.

**T20. Files are deleted silently, and `ern doc` cannot say what it decided (principle 3).**
- Commands: remove `src/other.ern` and run `ern build --build-root build src`. The build deletes `build/other.erc` and says nothing; only `--verbose` shows `removed build/other.erc`.
- `ern doc src` deletes stale documents silently too (see T8).
- `ern doc` takes no `--verbose` at all, though it compiles, reads `.erc` files, compares times against "any file of the toolchain's own code", and deletes files. `ern build`, `run`, and `test` can each say what they decided.
- Fix: give `ern doc` the option `--verbose`, as `ern build` has it. Consider saying `removed` without the flag, since a deletion is an act the user did not ask for by name.

**T21. The shell changes the mode of `$HOME/.ernest` silently, even in line mode, which keeps no history (principle 3).**
- Command: `HOME=home1 ern shell < script`, with `home1/.ernest` at mode 755. After the run the directory is 700, and nothing was said.
- Line mode neither reads nor writes the history, which is the only thing the mode protects.
- Fix: change the mode only where the session keeps a history, and say so once when a mode is changed.

**T22. A single-file build from a project root silently picks a namespace from the working directory, and its error hides that it did (principles 3 and 1).**
- Command: from the project root, `ern build src/main.ern` compiles `Src.Main`. It fails with `unknown name Net.Http.parse` and no help line.
- `ern build src/net/http.ern` succeeds, and writes a `Src.Net.Http` that then blocks the right build (T5).
- Only `--verbose` shows `source root .`.
- Fix: where a qualified name is unknown and a source root nearer the file would make it known, add a help line, `this module is Src.Main; --source-root src makes it Main`.

**T23. `ern doc --build-root` has two roles, and its help states neither of them correctly (principles 1 and 2).**
- The help says "where the compiled tree goes", but `ern doc` writes no compiled tree.
- The one directory is both where the documents go and where `.erc` files are looked for, so documents cannot go to `docs/` while the build in `build/` is read; every `.erc` is compiled again.
- Fix: correct the help line to "where the documents go, and where a current `.erc` is read from". Consider a separate output directory, or say in §11.4 why the two roles are one.

**T24. `ern shell file.erc` is a second way to load a module, with the side effect of spawning `main` (principle 2).**
- It is `:load` plus a spawn of `main`, or of the function `--main` names.
- The deployment guide (§6 and §8) has to warn operators off it: "a file given to `ern shell` would run its `main` beside the prompt, which is not wanted here, so the module is loaded at the prompt instead".
- Fix: either drop the file argument, leaving `:load` and a typed `spawn(Main.main)`, or state in §11.2 why both are kept.

**T25. `--libs-dir` may be given once, while `--load-path` repeats, and the guide compares `--libs-dir` to `ERL_LIBS`, which takes a list (principle 1).**
- Command: `ern run --libs-dir libs --libs-dir libs hello.erc` refuses with `--libs-dir is given more than once`.
- The guide's §9.2 says `--libs-dir` "adds the Erlang applications under dir ... as the host's `ERL_LIBS` would". A program whose applications sit in two trees has no way to name both.
- Fix: make it repeatable as `--libs-path`, under the `-path` naming rule, or drop the `ERL_LIBS` comparison from the guide.

**T26. `--help` is refused beside other words at the top level but accepted beside them after a job (principle 1).**
- `ern --help build` refuses with `--help stands alone`.
- `ern build --help x.ern`, `ern build x.ern --help`, and `ern build --help --verbose` all print the help and exit with status 0.
- Fix: refuse `ern <job> --help` given with another word, as the top level does, or accept extra words at both levels.

**T27. The option parser's messages are not the toolchain's (clarity).**
- `ern build --build-root` prints `missing option argument: --build-root <build_root>`, and every other option does the same, `<load_path>`, `<config_dir>`, `<listen>`, while the usage writes `build-root`, `dir`, and `address:port`.
- `ern build --frob` prints `invalid option: --frob`, and `ern build --check x.ern` prints `invalid option: --check` without naming the job that takes the option.
- `ern build a.ern b.ern` prints `one file or directory argument is required`, though two were given.
- Fix: write these messages in the usage's words: `--build-root takes a value: --build-root build-root`; `--check is not an option of ern build; ern format takes it`; `ern build takes one file or directory, and was given 2`.

**T28. A missing file is refused in two spellings (clarity).**
- `ern run`, `ern test`, and `ern doc` print `no such file x.erc`.
- `ern build` and `ern format` print `x.ern: no such file or directory`.
- `--load-path p1/hello.erc`, a file, is refused as `no such directory`, where `not a directory` is the case.
- Fix: one form, `path: no such file`, and `path: not a directory` for an option.

**T29. The shell's help calls `--main` the entry point (clarity).**
- `ern shell --help` says `--main  the entry point, a qualified exported function`.
- §11.2 says the shell is the entry point and that `--main` "names the function to spawn". The shell's refusal says `... is not an entry point` too.
- Fix: `the function spawned beside the shell, from the file loaded`.

**T30. `--short-errors` is a second form of the same diagnostics (principle 2, low).**
- The full form's first line is already `file:line:column: message`, which a tool reads. The guide's §9.4 says the Emacs mode reads `ern build`'s errors through `M-x compile`.
- Fix: drop the option, or state in §11.5 the tool that needs it (see L4).

**T31. `export` at the prompt is accepted though it has no effect (principle 3, low).**
- `export fn f() : Int = 1` and `export let z = 3` are both accepted silently.
- §11.2 allows this ("`export` at the prompt adds nothing"). §0 principle 3 says the compiler "refuses what the text alone shows can have no effect".
- Fix: refuse the word with a help line, or state in §11.2 the reason the exception exists, presumably so that a module's text can be pasted at the prompt.

**T32. Standard error's format depends on where standard error goes (principle 1, low).**
- The same `ern run` prints time-stamped lines to a pipe or a file, and plain lines to a terminal or to the stream that `JOURNAL_STREAM` names. No option chooses.
- A test that reads the lines sees a different format than the person who ran the program by hand.
- Fix: none required. Note that this is the only case in which the content of the toolchain's output, beyond color, changes with where the output goes.

**T33. In line mode, `:output -` answers `output goes to the live region`, though line mode has no live region (clarity, low).**
- Fix: say `output goes to standard output` in line mode.

**T34. `ern --version` and `ern --help` refuse to run in a working directory whose name is not UTF-8 (principle 1, low).**
- Both print `ern: the working directory's name is not UTF-8` and exit with status 1, though neither reads the directory. The report states the refusal.
- Fix: exempt the two options.

**T35. A trace mixes the host's frame syntax with Ernest's (question).**
- `faults: faulted: division by zero` is followed by `erlang:'div'/2` and then `Main.t3:9`. The first frame is in Erlang's notation, quotes included, and names a BIF in place of `Int./`.
- I could not read E.21 to check whether this frame is intended.
- Fix, if it is not: drop the host's frames for a fault Ernest names, or write them as Ernest writes a call.

**T36. `ern run` with no arguments says `one .erc file argument is required`, though `ern run --config-dir dir` with no `.erc` is a bare node (clarity, low).**
- Fix: `a .erc is required, or --config-dir for a bare node`.

**T37. The message for a peer of the other address family states the rule rather than the case (clarity, low).**
- `ern config --config-dir b --peer-dir v6` says `... is IPv6, and this node runs over IPv4, its listener's family or IPv4 where it has none`, though `b` has a listener.
- Fix: say only the branch that applies, `its listener's family`.

**T38. A document's footer names the source by its base name alone (clarity, low).**
- `Generated by ern 0.4.0 from http.ern.` names a file under `src/net/`, and two modules `net/http.ern` and `http.ern` both footer as `http.ern`. The comment at the head of `--emit-erl`'s output does the same.
- Fix: write the path the `.erc` records, or the path from the working directory.

#### Suspected leftovers from an earlier stage

- **L1. `ern config`'s default `./.ernest`.** A node now needs `--config-dir` explicitly ("a program is a node only where `--config-dir` says so"). So a `./.ernest` made by default must always be named again, and the report carries three guards that only such a directory needs: `./.ernest/startup` is not run, `.ernest/` under a load-path root is not a module, and "nothing there configures a job". I suspect the default dates from a stage when a program picked up `./.ernest` on its own. It also causes T3 and T16.
- **L2. `--emit-erl`, and the `-dialyzer(no_return).` attribute in its output.** The compiler now makes a unit from the definitions' canonical forms (§11.1), and the `.erl` "carries no interface" and is "for reading". I suspect the option dates from the stage when the compiler emitted Erlang source and compiled it, and the dialyzer attribute from someone running dialyzer over that source.
- **L3. The vendored option parser's messages.** `missing option argument: --x <x_y>` and `invalid option` (T27) read like a getopt library's wording, kept because nothing broke. Every other message of the toolchain is in its own register.
- **L4. `--short-errors`.** It may date from before the full form's first line was fixed as `file:line:column: message`, or from an editor mode that could not skip the source lines (T30).
- **L5. The version in `ern doc`'s output without `-dev` (T4).** The document writer seems to take the release number from a source older than the `-dev` mark that `--version` and the shell now print.
- **L6. `(report §8.1)` and "of type () -> Unit" in the entry-point refusal (T10).** These are the only report citation in any message, and they predate entry points that may receive. They look like a development-stage message.
- **L7. The shell's change to the mode of `$HOME/.ernest` in line mode (T21).** It is the history's reason, applied where no history is kept.
- **L8. Help texts copied between jobs.** `ern doc --build-root` "where the compiled tree goes" (T23) reads as copied from `ern build`. `ern shell --main` "the entry point" (T29) reads as copied from `ern run`, from before the shell became the entry point.

### Reader X

#### Diagnostics review (reader X): 266 of 272 entries clear

I read all 272 entries of `docs/diagnostics.md`, at commit 1329d1d2, against `report/toolchain.md` §11.5 and the report sections each entry cites. I did not read the code, the log, the plan or the proposals.

**Count.** 266 of 272 entries are clear: having made the mistake, I would know the fix from the message. These six are not:
- *An equality mark in parentheses* (X2)
- *A private type in an exported signature* (X1)
- *An escape the language does not have* (X13)
- *A bitstring specifier the language does not have* (X12)
- *Something that is no bitstring specifier* (X11)
- *A known type without the member* (X14)

21 of the clear entries still carry a defect, listed under X3 to X10.

Entries are named by their catalog headings.

#### Defects

**X1. A private type in an exported signature, with A private abstract type: the help's second fix goes in a circle.**
- The message is `f is exported and its type names Box, which this module keeps private`. The help is `export Box, or declare it `abstract type` so that its constructors stay private (report §4.4)`.
- Taking the second fix alone, `abstract type Box = Box(Int)` without `export`, is refused by *A private abstract type*. §4.4 says an abstract type is exported, and one the module keeps private is an error.
- That entry's help, `export it, or declare it `type``, leads back to the program refused first.
- Fix: `= help: export Box, or export it as `export abstract type Box` so that its constructors stay private`

**X2. An equality mark in parentheses: the help leads to a second error.**
- `fn f(x : (a=)) : Int = 1` gives `a type in parentheses takes no equality mark`. The help is `the mark stands in a list of types, as List(a=) or (a=) -> Bool`.
- In this plain `fn`, both forms the help offers are refused by *An equality mark outside a foreign function*, with `the equality mark is written in a foreign function's parameters alone` (§3, §4.7).
- Fix, outside a foreign function: `= help: write a; the mark is written in a foreign function's parameters alone`. Keep the present help inside a foreign function's parameters.

**X3. Empty parentheses where a type stands: the help states something false.**
- The help is `the type whose one value is written () is Unit`.
- §3.1 says Unit's only value is `Unit`. *Empty parentheses where an expression stands* refuses `()` with `Unit's one value is written Unit`, so the two helps contradict each other.
- Fix: `= help: the type with one value is Unit, and its value is written Unit`

**X4. A filled field of another type: the expected type uses a variable the program never writes.**
- The message is `Ops(..Set) fills size with Set.size: expected (a) -> Bool, found (Set(b=)) -> Int`. The label in the same diagnostic says `Ops declares size : (s) -> Bool`.
- So one variable prints as `s` in the label and as `a` in the message. §11.5 says a type variable is printed under its annotation's name.
- The annotation `Ops(Set(Int))` also fixes `s`, and §5.6 fills "at the field's type".
- Fix: `... expected (Set(Int)) -> Bool, found (Set(Int)) -> Int`. At the least, `(s) -> Bool`.

**X5. A body at another type than its uses gave its result: the span that fixed the expectation has no label.**
- The message is `the body does not have the result type h's uses give it: expected Int, found String`.
- Line 2, `let x = h() + 1;`, is shown only as the line before, with nothing marked on it. §11.5 says the label marks the span that fixed the expectation. *An operator whose result is used at another type* labels such a later use.
- Fix: underline `h()` on line 2 with the label `this use gives h's result as Int`.

**X6. Two §3.11 messages state the rule as though it were what happened.**
- *A spawn on a peer of a function a call answers* says `Peer.spawn starts a function written where the compiler sees what it captures: a declaration's name, or a lambda or a `fn` written in this definition`. Read plainly, it says the opposite of the case. Its sibling entries name the expression and what is wrong with it.
  - Fix: `Peer.spawn starts job(), a function a call answers, whose captures the compiler does not see`
- *`Code.running` of a lambda* says `Code.running lists the processes that run a declaration, named where the call is written`. It never says that the argument is a lambda, though its siblings do (`and f is a local, whose function is no declaration`).
  - Fix: `Code.running lists the processes that run a declaration, and fn() = Unit is a lambda, which is no declaration`

**X7. Seven §3.11 helps give the reason and name no fix.**
§11.5 says a help line names the fix. Each help below explains why instead.
- *A service at a type bound to its node*: `a service's message type crosses to the node's peers, so ...`
  - Fix: `= help: hold no function in Msg; send a value that crosses, which the process acts on`
- *A capture whose type holds a type variable*: `a value a spawn on a peer captures has a type known whole, since ...`
  - Fix: `= help: capture a value whose type is known whole: compute List.size(values) before the spawn and capture that`
- *A capture of a type bound to its node*: `... give the process what crosses`
  - Fix: `= help: compute what the process needs, describe(1), before the spawn and capture that, or spawn on this node`
- *A spawned process whose mailbox type is bound to its node*: `the spawn answers an address that may cross ...`
  - Fix: `= help: keep the socket on this node and send the peer values that cross, or spawn the process on this node`
- *A compute whose function answers a value bound to its node*: `the value crosses back ...; answer what crosses`
  - Fix: `= help: answer a value that crosses, from which this node builds the function`
- *A compute's process whose mailbox type is bound to its node*: `the function a peer runs ... has a mailbox type that crosses`
  - Fix: as for the spawned process above.
- *`Code.running` of a function whose result type is not `Unit`*: `a process runs a function whose result type is `Unit``
  - Fix: `= help: name the function the processes run, a top-level `fn` whose result type is `Unit``

**X8. A call with the wrong number of arguments, A call of a callee that is no name, A call of a selected field: the help does not fit the case shown.**
- Each passes two arguments where one is taken, and each adds `help: a call supplies all the arguments`.
- That help speaks to a call with too few arguments (§5.2). With too many, it names no fix.
- Fix: give it only for too few, as `= help: a call supplies all the arguments; there is no partial application`. For too many, give none, or `= help: g takes one argument; two values passed as one are a tuple, g(#(1, 2))`.

**X9. Spans that underline more than the error (§11.5: "the erroneous span underlined").**
- *A field the constructor lacks* underlines the whole construction `Point(x = 1, y = 2)`. Its pattern twin and *A field given twice* underline the field alone.
  - Fix: underline `y = 2`.
- *`!` on a value that is no Bool* says "the operand of `!`" but underlines `!1`. The `&&` and `||` entries underline the operand alone.
  - Fix: underline `1`.
- Lesser cases:
  - *An operator member of the wrong shape* underlines the whole declaration, while *A `compare` that returns no Ordering*, the same §4.8 error, underlines the type that breaks the shape. Fix: underline `b : Int`.
  - *A member of a type the module does not declare* and *A type named `Prelude`* underline whole declarations where only the name is wrong. Fix: underline the name.

**X10. A function that receives, called in a guard: the label repeats the error.**
- The label `a guard receives nothing (report §5.9)` underlines the same span as the `^` and repeats the message's own words.
- §11.5 keeps a label for a second span. This is also the only label in the catalog that cites the report.
- Fix: drop the label, or put it under `when` alone: `the guard receives nothing`.

#### Matters of clarity

**X11. Something that is no bitstring specifier.**
- `<<b:1>>` gives `expected a bitstring specifier instead of integer 1`. Writing a size as `X:8` is an Erlang programmer's first mistake here, and the `unit` entry already helps with Erlang's `unit`.
- Fix: `= help: a size is written size(1)`

**X12. A bitstring specifier the language does not have.**
- `unknown bitstring specifier `wide`` gives no list of the specifiers.
- Fix: `= help: a specifier is size(N), bytes, int, float, utf8, utf16, utf32, big, little, signed or unsigned`

**X13. An escape the language does not have.**
- `unknown escape \a` does not say how to write a bell.
- Fix: `= help: the escapes are \', \", \\, \n, \r, \t and \u{...}; a bell is \u{7}`

**X14. A known type without the member, and A derived compare over a field without one.**
- `fromList needs List(Int).compare, and List(Int) has no compare` and `Date.compare cannot be derived: Optional(Int) has no compare` say why, not what to do. Both texts are the report's (§4.9, §3.5); the help line is free.
- Fix: `= help: List(Int) has no ordering; a Set needs equality alone, or declare a type with a compare of your own`
- Fix: `= help: declare `fn Date.compare` yourself, or hold a field whose type has a compare`

**X15. A variable twice in one pattern.**
- `variable x appears twice in the pattern` gives no route to what the writer meant: Erlang's `{X, X}` matches equal pairs. §5.10 says equality is written in a guard.
- Fix: `= help: bind two names and compare them in a guard, #(x, y) when x == y`

**X16. A value of a type's namespace that is a member's name.**
- `Main.Stack.compare is a member of the type Stack in main.ern` is the text §11.5 fixes. Nothing says that the reader's own `compare` is also `Main.Stack.compare`.
- Fix: `= help: this module's compare is Main.Stack.compare too; rename it`

**X17. A constructor named as a type.**
- The help `there are no type aliases (report §3.1)` says what is missing, not what to write. The text is fixed by §3.1, so the change goes through the report.
- Fix: `= help: there are no type aliases; a type that holds a String is written type Word = Word(String)`

**X18. A top-level `let` whose initializer is no value and whose type is not determined.**
- The fix, `annotate it`, ends a very long sentence.
- Fix: `the type of inbox, Address(Optional(a)), is not determined` with `= help: annotate it, let inbox : Address(Optional(Int)) = ...`

**X19. A function type written with `fn`.**
- ``fn` is a reserved word, and names nothing` reads oddly where a type is expected, and only the help rescues it.
- Fix: `expected a type instead of the reserved word `fn``, which is the shape the `foreign` entry already uses.

**X20. Help examples that do not fit the program.**
- *A compute whose function's result type holds a type variable* suggests `fn() : Int = ...` for `fn() = []`.
  - Fix: `fn() : List(Int) = []`
- Several `Code.running` helps write `Code.running(count)`, a name no program declares, while *`Code.running` taken as a value* writes `Code.running(f)`. In *`Code.running` of a local*, the local is bound to `loop`.
  - Fix: `= help: name the top-level fn itself, Code.running(loop)`

**X21. A positional constructor matched without its field.**
- `Some has one positional field; write Some(p)` does not show how to match any `Some`, as the bare `Circle` entry does with `Circle()`.
- Fix: `... write Some(_) to match any Some`

**X22. `Io.show` at a type not known whole.**
- The help `annotate the value where it is bound` does not fit: `[]` is bound nowhere, and Appendix A has no annotation of an expression.
- Fix: `= help: bind it with an annotation, let list : List(Int) = [], then show it; ...`

**X23. A recursive type named at its parameters in another order.**
- It says `Flip is named at Flip(b, a)`, the whole type. Its sibling says `Nest is named at List(a)`, the arguments alone.
- Fix: `Flip is named at (b, a) in its own fields, ...`

**X24. A `receive` guard that compares a computed value.**
- `... compares variables, literals, and nullary constructors` leaves out the top-level `let` and the negative literal that §6.3 allows.
- Fix: `... compares variables, top-level lets, literals, and nullary constructors`

**X25. A parameter pattern that does not fit its annotation, A `<-` pattern that does not fit the value inside, A `let` pattern that does not fit the value.**
- Each says `found #(a, b)` for a pattern that binds `a` and `b`, so the type reads as the pattern repeated.
- Fix: print it with names the pattern does not bind, `found #(c, d)`.

**X26. A field of a value whose type is not determined.**
- `...; annotate it` names nothing. The thing to annotate is `p`.
- Fix: `...; annotate p`
- The fill entry's `annotate it` is the report's text (§5.6). There `it` reads as the variable `a`, but the thing to annotate is `ops`.

**X27. `==` on functions.**
- `it contains a function, an address or a reply` is generic, for a type that is itself a function.
- Fix: ``==` is not defined on () -> Int, a function type`

**X28. A member whose Erlang name the host cannot hold.**
- `the member's Erlang name ...` does not name the member; only the caret under `derives compare` does.
- Fix: `the Erlang name of the derived member compare, its type's name and its own joined by `.`, is 256 characters long, ...`

**X29. The lexer messages use two words for one concept.**
- A line break is `newline` in the string and character messages, but `a line break cannot follow `\`` elsewhere.
- A character literal is `char literal` in messages and `character literal` in the catalog's headings.
- `hex digits` stands beside `hexadecimal digit`.
- `unterminated` stands where the headings say "never closes".
- Quoting varies: `'§'` in single quotes, `p` and `\a` bare, where other messages use backticks.
- Fix: one word for each concept, and backticks for quoting, as in `a line break in a string; use \n` and `` `p` cannot follow a number directly ``.

**X30. Report citations are scattered.**
- Citations such as `(report §3.9)`, `(report §4.8, E.1)`, `(report §3.1)`, `(report §4.4)`, `(report §5.6)` and `(report §5.9)` appear in some messages, helps and one label, and in every §3.11 help.
- Most diagnostics cite nothing.
- Fix: decide one place for a citation, or none, and hold every message to it.

#### Coverage, outside the brief

**X31. Three §11.5 rules have no program in the catalog, so their messages cannot be judged:**
- the rejection of a process-only function (`m+`) where one that receives nothing is expected;
- a restriction broken where the callee is not a name, `pair()(r)`, or by a later use;
- an effect error naming `self` or a wrap.

### Reader S


I found one real exposure in the changed code: `ern test` makes each doc example's working directory with whatever mode the umask gives, in the shared temp directory, so another local user can plant links where the example writes. I confirmed it by experiment. Everything else below is a defect or a hardening point that the report's trust model (peers fully trusted, foreign code trusted) does not count as an exposure.

**Scope gap in the diff I was given.**
- `changed.diff` leaves out four files of the node that the brief names: `ern_carrier.erl`, `ern_gateway.erl`, `ern_exchange.erl` and `ern_arrival.erl`. All four changed in the range.
- It also leaves out code that the changed functions call: `ern_epmd.erl` (calls the new `ern_carrier:dialing/1`), `ern_examples.erl` (new, called by `ern_cli`'s example runner), and `ern_build:load_path/1`.
- I read their diffs with read-only `git diff` and saved them in the scratch directory as `node_extra.diff` and `build_examples.diff`.
- All experiments ran under `try/` in the scratch directory, with `bin/ern` pointed only at scratch paths. No process is left running.

#### Real exposures

**S1. The doc-example directory is made with the umask's mode in the shared temp directory, so another local user can plant links where the example writes.**
- **Place.** `erl/cli/src/ern_examples.erl:125-131` (`made_directory/1`) and `:94-110` (`in_directory/3`):
  - `case file:make_dir(Dir) of ok -> {ok, Dir}; ...`
  - then `ok = file:set_cwd(Dir)`
- **What is wrong.**
  - The directory is `$TMPDIR/ern_example_<OS pid>_<small counter>`, with mode 0777 minus the umask. Each example program then runs with it as the node's working directory.
  - Under umask 000 anyone can write it. Under umask 002 with a primary group shared with other users, the group can.
  - Such a user can watch the temp directory (inotify) and plant a link or a file under the name an example uses. The example then writes, chmods or reads through it as the user running `ern test`.
- **Why it matters here.** The light run before every commit reaches it: `make test` runs `make test-library`, which runs `bin/ern test build/stdlib`, and so every standard-library example.
  - E.17's example runs `Fs.write(Path("private.txt"), <<>>)` and then `Fs.setMode(Path("private.txt"), 0o600)`. A planted link `private.txt -> ~/.bashrc` gets its target truncated and set to 0600.
  - The `greeting.txt` example writes "hello" through a planted link.
  - A planted `shelf` link sends `Fs.write(Path("shelf/one.txt"))` into another directory.
- **Input that shows it.**
  - With `umask 000; TMPDIR=<scratch> ern test build/slow.erc`, `stat` showed the example's directory as `drwxrwxrwx`.
  - I wrote a module whose example waits 3 s and then runs `Fs.write(Path("note.txt"), ...)`. During the wait I ran `ln -s $PWD/victim.txt $D/note.txt` in the example's directory. Afterwards `victim.txt` held "written by an example".
- **Not exploitable** under umask 022, or under Ubuntu's 002 with a private group per user.
- **Fix.** Do what `ern_node:create/2` already does for the configuration directory, before `set_cwd`:
  1. `file:make_dir(Dir)`
  2. `file:change_mode(Dir, 8#700)`
  3. refuse unless `file:list_dir_all(Dir) =:= {ok, []}`

#### Defects and hardening (no exposure under the report's trust model)

**S2. A node's relative `--config-dir` is resolved against the working directory each doc example sets.** This is a defect, not an exposure.
- **Place.**
  - `erl/cli/src/ern_cli.erl:1145`: `as_node/5` and `run_node/5` keep `ConfigDir` exactly as typed.
  - `erl/cli/src/ern_carrier.erl:254-255`: `reload/0` runs `ern_node:read(ConfigDir)` against the current working directory.
  - `ern_examples.erl:104` changes that working directory for the whole host during each example.
- **Input that shows it.** I ran `ern test --config-dir node build/slow.erc` (one example that waits 4 s) and `ern reload --config-dir node` at 2.5 s. The node said: `the reload was refused, and the configuration stays as it was: node: no such file or directory`. It had read `<example dir>/node/ernest.conf`.
- **Why it is not an exposure.** Another user cannot plant a configuration there: `owned/4` requires files owned by the user or root, and a reload refuses a changed key.
- **Fix.** Make `ConfigDir` absolute once, in `as_node/5` or in the record `ern_node:read/1` returns. `boot_flags/1` already does this for the key and the certificate.

**S3. Group write is trusted, and `--peer-dir` extends that trust to another directory's certificate.** The rule is the report's, so this is a design question rather than a code defect.
- **Place.**
  - `erl/cli/src/ern_node.erl:317` (`owned/4`): `Info#file_info.mode band 8#002 =:= 0` refuses only world write.
  - `add_peer/2` (`:161`) and `peer_read/1` (`:195`) list whichever key the peer directory's `certificate.pem` certifies.
  - `create/2` writes `ernest.conf` and `certificate.pem` with the umask's mode: 0664 under umask 002, as on this machine.
- **What is wrong.**
  - A listed peer "may run anything" on the node (report §8.7). Today only the directory's 0700 mode protects these files.
  - Suppose the user opens the directory to the group (`chmod g+rx`), say to share the public key. Any group member can then add their own key to `ernest.conf`.
  - A group member can also swap the peer directory's certificate before `ern config --peer-dir` reads it.
  - Either way they get code execution as the node's user.
- **Input that shows it.** I made `victimpeer` group-accessible and copied another node's `certificate.pem` over its own file (still mode `-rw-rw-r--` as created). `ern config --config-dir a2 --peer-dir victimpeer` exited 0 and listed the copied certificate's key.
- **Comparison.** OpenSSH's StrictModes refuses group-writable authorized keys.
- **Recommendation.** Refuse group write (`band 8#022`) on the directory, `ernest.conf` and `certificate.pem`, at least for `--peer-dir`. Write both files with mode 0644 at create.

**S4. Text from a peer goes raw into the node's lines.** This is hardening; peers are trusted.
- **Place.**
  - A spawn or compute frame's `Site` is checked only with `ern_fs:is_utf8(Site)` (`ern_peer.erl:495`, `:511`).
  - It is then printed raw in three places:
    - `ern_cli.erl:1217` (`report_fault/3`): `[stamp(Stamped), Site, Faulted, ...]`
    - `ern_gateway.erl:494`: `" at ", Site, " was not loaded: "`
    - `src/shell/shell.ern:701`: `report.site <> phrase`
  - `ern_rt:traced/1` (`:2302`) joins frame names with `\n` before anything escapes them. A name from an arrival is the peer's UTF-8 text (`ern_code:recorded_name`), so a name holding `\n` becomes forged frame lines once `indented_trace/1` splits on `\n`.
- **Input that shows it.** A peer spawn whose `Site` is `<<"Main.w:1\e[2J\n2026-... the peer x connected">>`, and whose process then faults.
- **Why it matters.** Elsewhere the code treats the same kind of text as "any bytes" and escapes it (`ern_peer:qualified_text/1`).
- **Fix.** Write the site through `ern_show:controls(Site, line)` in those three places, or refuse a site with control characters in `frame/2`. Escape each name in `trace_line/1` before joining.

**S5. A fault report is suppressed by matching the site's text.** This is hardening.
- **Place.**
  - `ern_cli.erl:1205`: `report_fault({'FaultReport', _, <<"Test.faults:", _/binary>>, ...}) -> ok`
  - `src/shell/shell.ern:670` and `:680` (`isExpected`)
- **Input that shows it.** A peer spawn frame with `Site = <<"Test.faults:1">>`, which `frame/2` accepts. That process's faults vanish from the node's standard error and from the shell's `:faults`.
- **Fix.** Mark the processes that `Test.faults` spawns in their row, or refuse a frame's site that starts with that prefix.

**S6. A compute's answer from a peer bypasses the checks frames get.** This is hardening against a faulty peer.
- **Place.**
  - `erl/runtime/src/ern_rt.erl:844` (`answer_taken/1`): `{_, faulted, Cause, Trace} -> {faulted, Cause, Trace}`
  - then `:796`: `fault(Cause, Trace)`
- **What is wrong.**
  - Neither part is checked as a UTF-8 binary.
  - The report of the faulted process runs in the reaper: `died/4`, then `report/5`, then the launch's reporter, `ern_cli:report_fault/3`. There `ern_show:controls(Cause, line)` and `indented_trace/1` (`binary:split`) raise on a non-binary, and the reaper dies with them.
  - The `Down` delivered also carries `Fault(Cause)` with something that is not a String where a String belongs.
- **Input that shows it.** A peer answers a compute with `{Alias, faulted, 42, foo}`. I found this by reading; I did not run it.
- **Why it matters.** For a frame it cannot read, the gateway ends the faulty peer's connection. This answer goes to the alias directly, so the gateway never sees it.
- **History.** The weakness predates the range (the old code ran `iolist_to_binary(Trace)`); this change only gave it a new form.
- **Fix.** In `answer_taken/1`, take `faulted` only when both parts are UTF-8 binaries; otherwise answer `Left(Other(...))`.

**S7. A peer's kill frame reaches any process of the host.** This is hardening, low priority.
- **Place.** `erl/runtime/src/ern_peer.erl:543`: `frame(_From, {kill, Pid}) when is_pid(Pid), node(Pid) =:= node() -> 'Unit' = ern_rt:kill(Pid)`
- **What is wrong.** `ern_rt:kill/1` assumes "any address given here is a program's" (§8.2), which a frame does not guarantee. The kill suspends and ends the gateway, the exchange, the reaper or a system process just the same.
- **Fix.** Act only on pids that have a row in `ern_processes`, and treat any other as an unreadable frame.

#### Read and found sound

- **The carrier's binding of the answering certificate to the host dialed.**
  - `ern_epmd:address_please/3` records the dialed host through `ern_carrier:dialing/1`.
  - `verify/3` now knows which side it checks. On the client, `answered(client, ...)` compares the host given by the certificate's key with `dialed/0`.
  - A missing or ambiguous dialed host makes the `[Host] =` match crash, so the dial fails closed.
  - On the server, OTP 29's `inet_tls_dist:allowed_nodes` binds the claimed node name to the certificate's name, and `names_own_host/1` holds that name to the key.
- **The boundary.**
  - The new `unit` descriptor: `result/4` takes `ok` only at the top of a function value's result.
  - `matches(unit, _)` takes `'Unit'` alone, in arguments, messages and nested values.
  - The named causes in `raised/4`, `argument/5`, `host_name/1` and `program_name/1` are sound.
- **`ern config`.**
  - `--listen` is validated before the directory is made.
  - In `add_peer/2`, the new entry goes through `peer/3` and both directories go through `owned/4`.
  - The listed key comes from the certificate, after `names_own_host`.
  - The rewrite goes through `write_whole/2`, which keeps the file's mode and follows a link, as §11 says.
  - Edge cases `.`, `b/` and `/` behaved correctly.
- **The `Ms` that spawn and compute frames now carry.** `deadline/1` clamps it at 0 and `remaining/1` waits in slices, so no exchange is held longer than before.
- **No new input paths in the rest.**
  - `ern_tty`: the stty wait is now untimed, deliberately.
  - `ern_os`: `host_read/1` adds no new parsing.
  - `ern_tcp` and `ern_fs`: only `-receives` attributes changed.
  - `src/shell/shell/history.ern`: only a comment changed.
  - `bin/ern`: the node-flag pass now runs only for `run`, `test` and `shell`.
  - `ern_build:application_ebins/1` (`--libs-dir`) refuses names that are not UTF-8.

### Reader H


Commit 1329d1d2. I read `src/shell/README.md` first and whole, then `shell.ern` and the six modules under `src/shell/shell/`, with `report/language.md` and `report/library.md` as the language I know. I opened nothing under `erl/` or `docs/`. I checked only that the README's link targets exist; all of them do.

Most of the README holds. The six parts of `shell.ern`, the three processes, "One input, end to end" step by step, line mode, the abstract types, which modules are pure, the tests at each module's foot, and the idioms all match the code. The findings below are the places where it did not.

#### Defects: the README, or a comment it sends me to, says something false

**H1. The comment on `ScreenMsg` names the wrong sender of `Noted`, and the README sends readers to that comment.**
- README.md:20 says: "The comments on the three mailbox types, `ShellMsg`, `ReaderMsg` and `ScreenMsg`, say who sends each message."
- shell.ern:73-74 says: "The shell's own text is `Said`, from the session alone, and `Noted` while an input is typed, from the reader".
- What is wrong: the session sends `Noted` too. `keyLoop` (shell.ern:597-598) handles a fault report with `reported(state, screen, report, Noted)`. The comment on `reported` itself (shell.ern:664-665) says "`Noted` where a prompt is pending". So someone who follows the README's pointer learns the wrong message flow.
- Fix: rewrite the comment as "`Noted`, from the reader while an input is typed and from the session for a fault said while a prompt is pending".

**H2. `Shell.Complete`'s foreign declarations are not at the foot of `complete.ern`.**
- README.md:76 says: "`Shell.Complete` declares its own questions of the front end, `names` among them, at the foot of `complete.ern`."
- What is wrong: the declarations (`names`, `sessionNames`, `sourceRoot`, `sessionTexts`, `slot`, `fields`, `segment`, `component`) stand at complete.ern:240-277, between `listMs` and `isLone`. The foot of the file holds the tests (complete.ern:539-738), as README.md:16 itself says of every module. The two sentences contradict each other, and I looked in the wrong place.
- Fix: write "after `sourceModules` in `complete.ern`".

**H3. `output` and `cannotWrite` are not beside the functions that write to the screen.**
- README.md:10 says: "but `:output`'s `output` and `cannotWrite`, which stand in the session's part beside the functions that write to the screen."
- What is wrong: they stand at shell.ern:392-428, after `trouble` and before `fromFiles`, among the functions that read the startup files and the history. The functions that write to the screen (`diagnose`, `say`, `refuse`, `printLines`) are at shell.ern:731-762, three hundred lines further on.
- Fix: write "which stand in the session's part after `trouble`, among the startup files' functions".

**H4. The README names the wrong directory as the source root.**
- README.md:16 says: "A file's path under the source root `shell/` gives its module's name: `shell/command.ern` there, `src/shell/shell/command.ern` in the repository, is `Shell.Command`."
- What is wrong: the source root is `src/shell/`. The README's own build lines put `shell/editor.erc` under the build root `build/shell` (README.md:101), and `shell/command.ern` is the path under the root. In this README, though, `shell/` is the link to `src/shell/shell/` (README.md:3). Under that directory `command.ern` would be the module `Command`. I was lost here.
- Fix: write "the source root, `src/shell/`".

**H5. The list of which modules use which is incomplete.**
- README.md:70 says: "Of the others, two use another: `Shell.Editor` reads ... `Shell.History.kept`, and `Shell.Complete` reads from `Shell.Command` what each command takes and where a command's word ends."
- What is wrong, first: `Shell.Style` uses `Markdown` as well, since every function it has takes a `Markdown.Output` (style.ern:11-65). That makes three modules, not two.
- What is wrong, second: `Shell.Complete` reads more from `Shell.Command` than the README says. It reads the table itself, with each command's name and help line (`Shell.Command.commands` and `Shell.Command.line`, complete.ern:104-109), and `:set`'s words (`Shell.Command.settings`, complete.ern:189).
- Fix: write "three use another: ..., `Shell.Complete` reads `Shell.Command`'s table, what each command takes and where its word ends, and `Shell.Style` takes `Markdown.Output`".

**H6. `prompt` does not write every prompt, and its callers are listed short.**
- README.md:36 says: "`prompt` writes every prompt, after draining the screen: at a terminal `main` calls it after the startup files, and in line mode `lineLoop` before each line."
- What is wrong, first: in line mode `moreLines` writes the continuation prompt `... ` itself, with a bare `Said("... ")` and no drain (shell.ern:1501). At a terminal, `... ` is the region's `continuation` (region.ern:41).
- What is wrong, second: at a terminal `main` is not the only caller. `taking` calls `prompt` after each input (shell.ern:614, 622), and `keyLoop` calls it after `C-c` (shell.ern:592). Step 7 of "One input" does not name the caller either.
- Fix: write "`prompt` writes every `> `, after draining the screen: at a terminal `main` after the startup files, `taking` after each input and `keyLoop` after `C-c`; in line mode `lineLoop` before each line, and `moreLines` writes `... ` itself."

#### Clarity: places where I was lost or the wording misleads

**H7. `serial` does not recur across modules, and some names that do recur are not listed.**
- README.md:89-92 says: "Two names recur across the shell's modules ...: cursor ... serial".
- What is wrong: `serial` appears only in shell.ern. Meanwhile some unlisted names do recur across modules, one concept each: `color` for a `Markdown.Output` (shell.ern and style.ern), and `typedWord` (shell.ern:1348-1372 and complete.ern).
- Fix: write "`cursor` recurs across the modules, and `serial` is `Shell`'s", and add `color` if it counts as one of the shell's own names.

**H8. "Start and end" does not say how line mode is chosen, or where the reader's `Start` comes from.**
- README.md:22-24 and 30-38 say: "The reader is `reader`, then `readLoop`".
- What is wrong: before `readLoop`, `reader` waits in a `receive` for `Start` (shell.ern:1132-1141), and the README never mentions it. `main` sends `Start` only after the startup-file paths are found and the history is read (shell.ern:186-188). How line mode is chosen is in `readKeys` (shell.ern:212-223): either `Terminal.size()` fails, or the reader answers `SubscriptionRefused`. The README never names `readKeys`.
- Fix: add a bullet: "`readKeys` spawns the reader where standard output has a size, and line mode is the answer `SubscriptionRefused` or no size; the reader then waits for `main`'s `Start`, sent after the history is read."

**H9. Not every message to the screen writes bytes, and the bytes come from functions, not from the `Region` value.**
- README.md:24 says: "For each message it writes the bytes its `Shell.Region.Region` gives back".
- What is wrong: `Redirect`, `Locate` and `Flush` write nothing. A `Wrote` while `:output` names a file is appended there, and nothing is written to the terminal (shell.ern:984-987). The bytes are given back by `Shell.Region`'s functions (`said`, `wrote` and the rest); the `Region` is only the value they take.
- Fix: write "For each message that changes what is shown it writes the bytes `Shell.Region`'s function for that message gives back".

**H10. `kept` is the history's limit, not its length.**
- README.md:70 says: "`Shell.Editor` reads the history's length, `Shell.History.kept`".
- What is wrong: `kept` is the most inputs the history keeps (history.ern:10-12: "how many inputs the history keeps"). It is not how long the history is now.
- Fix: write "the history's limit".

**H11. The `Address(Never)` idiom cites only half of what it states.**
- README.md:82 says: "Nothing can be sent to it, but it can be killed (§6.8)."
- What is wrong: §6.8 says nothing can be sent to an `Address(Never)`. That an address carries the permission to kill is §6.5, and `kill` is §6.9.
- Fix: cite "§6.8, §6.5".

**H12. The `Shell` row of the table understates what `Shell.History` covers.**
- README.md:60 says: "all that sends, receives, or reaches the host, but the history file and the questions `Shell.Complete` asks".
- What is wrong: `Shell.History` reaches the host for the person's directory as well, not just the history file. It makes the directory and sets its mode (`keepOwn` and `makeDirectory`, history.ern:37-45 and 103-111), and it reads `HOME` and `Os.user`. The README's own `Shell.History` row says "The person's directory and the history file in it".
- Fix: write "but the person's directory and the history file in it, and the questions ...".

#### Seen in passing, outside the brief (code, found by reading, not run)

**P1. Defect: `C-d` on an empty line while an input runs kills the run at once, against `await`'s own comment.**
- The reader returns after sending `InputEnded` (shell.ern:1212-1213). Its monitor (shell.ern:191) then delivers `ReaderDied(Down(reason = Returned))`.
- `await` takes any `ReaderDied` (shell.ern:521-525), kills the input and leaves. `readerEnd` says nothing for `Returned`, so the kill is silent.
- The comment at shell.ern:545-546 says "an input typed meanwhile, and the end of input, are left in the mailbox: they wait for this one, and run after it".
- Fix: either leave a `ReaderDied` whose reason is `Returned` in the mailbox while an input runs (match only the other reasons in `await`), or change the comment to say that `C-d` ends the run.

**P2. Typo: editor.ern:7 says "The reader holds a `Editing`".**
- Fix: "an `Editing`".

#### Not checked, under the review's rules

- The names of the §11.2 paragraphs the README cites (*Editing*, *Faults*), since §11.2 is in `report/toolchain.md`, which was not open to me.
- The section names cited from the design note (*Processes*, *Start and end*, *Ordering*, *Queueing*, *Line mode*, *The foreign interface*, *The front end's copy*, *Testing*).
- That `Markdown` and `Ansi` have `Test` values.
- What `make test-shell` runs.
- That the Erlang functions the declarations name exist.

### Reader B


The programs are in this directory, one directory per area. I ran each with `/home/jocke/projects/ernest/bin/ern` (`ern 0.4.0-dev`, repository at 1329d1d2), with `HOME` set to `B/home`. The two nodes were made with `ern config` and `--peer-dir`, as the deployment guide's §2.1 shows: `a` at 127.0.0.1:47611 and the bare node `foo` at 127.0.0.1:47612. No node is left running, and nothing in the repository was touched.

**Short answer.** Under `ern run` and `ern test`, a developer can usually find the line. That held for:
- a fault deep in a chain of calls
- a fault inside a lambda
- a division by zero
- a foreign raise
- a fault in a top-level binding's initializer
- a restarted process

Four places fall short:
- **The shell** prints no trace when an input faults.
- **Faults carried from a peer** lose frames.
- **Deadlocks** are reported at the entry process only.
- **Two defects** make a broken program print nothing, or something false.

#### Defects

**B1. A type soundness hole: a well-typed program puts an `Int` where a `String` should be.** I found it while writing the lambda program. The trigger is a `let` inside a block that binds a lambda, whose body uses an operator inside an inner lambda that gets its parameter type from a call. The checker then generalizes over the operator's result type. Repro `lambda/iso/u7.ern`:
```
fn strings() : List(String) = {
    let f = fn(n) = List.map([1], fn(d) = d + n);
    f(6)
}
export fn main() : Unit =
    List.forEach(strings(), fn(text) = Io.println(String.toUpper(text)))
```
It compiles, and running it gives:
```
U7.main faulted: foreign function ern_string:to_upper/1 raised error:{badarg,7}
    string:uppercase/1:650
    ern_string:to_upper/1:177
    String.toUpper:308
    U7.main:7
    List.forEach:255
```
The output blames the standard library and never points at `strings`.

In the shell it is worse:
- `:type { let f = fn(n) = List.map([1], fn(d) = d + n); f }` prints `(Int) -> List(a)`.
- Printing a `List(String)` bound to `f(6)` faults the shell's own printer: `foreign function ern_shell:show/3 raised error:badarg`, with a trace through `Shell.show`, `Shell.printResult` and `Shell.lineLoop`.
- The shell then exits with status 70.

Other forms:
- **Also unsound:** `apply(fn(d) = n + d, 1)` (`u6.ern`), and `/` in place of `+` (`unsound.ern`).
- **Correctly refused:** `Int.+(n, d)` written out (`u8.ern`), a top-level `let` (`u9.ern`), a top-level `fn` (`u10.ern`), and an inner parameter with a type annotation (`unsound2.ern`).

Fix: resolve a pending operator before generalizing a block's lambda `let`, or leave out of the generalization the variables it still constrains. The shell should also survive a fault in its own printer.

**B2. A spawn or compute written inside a top-level `let`'s lambda always fails, so `ern test --config-dir` cannot test any work on a peer.**
- `peer/in_let.ern` has `let job = fn() = Peer.computeAt("foo", fn() = heavy(4), 5000)`.
  - Running it prints `Left(Other("the spawner's node no longer holds the function's reach"))`.
  - `foo` writes `the peer a's compute at InLet.job:4 was not loaded: the spawner's node no longer holds the function's reach`.
  - The same compute written in a `fn` returns `Right(16)`.
- Every `Test.Case` is such a `let`. All four tests in `peer/remote_tests.ern` fail this way under `ern test --config-dir a`, although `ern test --help` advertises `--config-dir` as "the tests run on a node".
- The text misleads: the deployment guide's §4.3 says this line means the spawner let go of the code, and "Nothing to do here".

Fix: give such a lambda an identity the code table holds, as a lambda inside a `fn` has.

**B3. When a peer is stopped in order, a process waiting on it in `callForever` ends silently, with the reason `ProgramEnd`.** In `peer/remote.ern`, `heldLoud` spawns a process on `foo` that keeps the reply and never answers, then calls it with `Address.callForever`. I then ran `ern stop --config-dir foo`.
- Node `a` exits with status 1 and writes no fault line at all (3 runs out of 3).
- With a helper process making the call (`heldHelper`), main's monitor reads `helper ended: ProgramEnd`. That is the reason meant for the end of the process's own program, yet `a`'s program runs on, and no fault is reported.
- Killing `foo` with `kill -9` instead gives the right output: `Remote.heldLoud faulted: callee is unreachable`, with frame `Remote.heldLoud:114`.

Fix: fault the caller with a cause saying the callee ended with its node, as a callee that ends locally does.

**B4. The shell drops the trace of an input's own fault.** `ern run --main Prices.second prices.erc` (in `lambda/`) prints:
```
Prices.second faulted: division by zero
    erlang:'div'/2
    Prices.labels:10
    Prices.labels:11
    List.map:141
    List.map:141
    Prices.second:25
```
The same call typed at the prompt prints only `fault: division by zero`. Every input fault I tried behaves the same:
- `Totals.numbers(Path("bad.txt"))` prints `fault: not a number: seven`.
- `Host.config(["1","x"])` prints `fault: foreign function erlang:binary_to_integer/1 raised error:badarg`.
- `Ledger.forever()` prints `fault: division by zero`.
- `Peer.computeAt("foo", fn() = half(0), 5000)` prints `fault: division by zero`, and no peer is named.
- `fn f(n : Int) : Int = 1 + 10 / n`, then `f(0)`, prints `fault: division by zero`.

`:load Settings`, whose binding faults, prints `Settings.maximum:13 faulted: not a number: twenty; nothing was loaded`, without the frames `Settings.parsed:7` and `Settings.limit:11` that `ern run` shows. A process spawned at the prompt does get a full trace (`input 8:1 ... input 4:1 / g:1 / input 8:1`), so the shell is able to print one.

Fix: print the input's trace under `fault:`.

**B5. Faults already on their way are dropped when the entry process's fault ends the program.** In `indirect/indirect.ern`, processes a, b and c each `callForever` the next, and c divides by zero.
- **`chain3`:** main calls `a` with a time limit and gets `None`, so `a` has ended; main then faults itself. Only c's line (`Indirect.chain3:94`) and main's are written; the faults of b and a are lost (3 runs out of 3).
- **`chain`:** main waits in `callForever`. The same two faults are lost (5 runs out of 5).
- **`chain4`:** main returns normally instead, and all three faults are written.

This contradicts guide §6.3 and §9.2, which say `ern run` writes every fault as it happens.

**B6. Faults on a peer lose the program's own frames.**
- **Operators:** the same chain run locally (`Remote.local`) shows `erlang:'div'/2`, `Remote.ratio:12`, `Remote.scaled:15`, `Remote.heavy:18`. Run on `foo` (by compute, by spawn and by call), the frame where `/` is written, `Remote.ratio:12`, is replaced by `Int./:52`, a line of the standard library's source.
- **Foreign declarations:** the frame loses its line, `Remote.parseInt` against `Remote.parseInt:8` locally.
- **The caller's side of a compute:** it names neither the peer nor the line of the `computeAt`. `Remote.deep faulted: division by zero` reads like a local fault. The whole trace of the failing foreign compute is `erlang:binary_to_integer/1` then `Remote.parseInt`, with no line and no frame of the caller.

Fix: keep the frames and lines in definitions that arrive on a peer, and add the caller's frame and "on the peer foo" to the fault a compute carries back.

**B7. A segment overflow's frame has no line, and its cause names no segment.** `misc/frame.ern` puts 300 into an 8-bit segment, in a function that builds three bitstrings:
```
Frame.main faulted: segment overflow
    Frame.frame
    Frame.message:10
    Frame.main:15
```
`Frame.frame` is a frame of Ernest code with no line, which report E.21 promises to every such frame. Neither the segment nor the value can be found from the output. Fix: give the frame its line, and say something like `300 does not fit 8 bits`.

**B8. `ern test` reports `passed` for doc examples it never ran.**
- `Halves2.half(4) // => 3` written on one line is only compiled, and reported `passed` although the value is 2 (`tests/doc/halves2.ern`).
- `Halves2.ratio(1, 0)` with no `// =>` line is reported `passed` although it divides by zero.
- A code block without the `ernest` tag is silently not an example.
- Only `// => v` on its own line is checked (`halves3.ern`), and the guide's "one that ends in `// => v`" also reads as the one-line form.
- A checked example that faults shows the internal frame `$Example1.docShown:5` (`halves4.ern`).

Fix: report a compile-only example as `compiled`, not `passed`, and name its frame by its declaration and its line in the file.

**B9. The fault that makes a supervisor give up is reported as `restarted`.** In `restart/crashy.ern`, `supervised` uses `restarts = 1`. Its output:
- `Crashy.visits:31 faulted, restarted: division by zero`, for the second fault of `visits`
- `Crashy.group:29 faulted: supervisor restart limit reached`

The child was never restarted: the group died and took it.

**B10 (low). Frames vanish for calls that are not tail calls.** In `foreign/host.ern`, with `parseInt(text) + 0` and `port(...) + 0`, the trace has no `Host.port:18` and no `Host.config:21`. With `+ 1` and `* 2` both frames appear, so the host's optimizer apparently removes the arithmetic and the frame with it. Guide §6.3 says only a function whose last act is a call leaves no frame.

**B11 (low). `Process.live()` in the shell lists the shell's own processes.** It includes `Shell.main` and `Shell.main:142`, against E.21's "those a program spawned"; `:processes` meanwhile says no process is running.

#### Matters of clarity

**C1. A deadlock is reported at the entry process only, and at the wrong line.** In `deadlock/locks.ern`, two accounts each `callForever` the other, and main waits for a total. The entire report is:
```
Locks.main faulted: deadlock
    Locks.main:36
```
- Line 36 is a `spawn`. The `receive` is line 37, because a waiting frame names the last call before the wait (E.21), which the guide never says.
- The cycle is the two accounts, `Locks.main:30` and `Locks.main:31`, each `Calling` with one `Audit` queued. Nothing names them, and `--verbose` adds nothing.

Suggest: write each waiting process's site, activity and frame, as Go's runtime does.

**C2. A deadlock or a stuck input in the shell is never reported.**
- `ern shell locks.erc` runs `main` beside the prompt; it deadlocks and nothing is ever said.
- The input `Locks.lonely()` hangs, and every later input waits behind it.
- At a terminal, `C-c` prints `Killed`, with no trace of where the input was waiting.
- Driven through a pipe, the shell never ends, even after its input has run out; `timeout` killed it after 30 s.
- `:processes` shows sites only, not what each process waits on.

**C3. A fault passed back through a call repeats the callee's cause word for word.**
- `Ledger.forever faulted: division by zero` points at `Ledger.ask:48`, a line with no division in it.
- In B5's chain, three lines say `division by zero`, and only the `erlang:'div'/2` frame shows which one is the origin.
- Across nodes, the origin appears only on the other node's standard error.

Suggest: `division by zero, the fault of the callee Ledger.start:6`.

**C4. Socket and listener faults speak of a "callee".**
- A `Tcp.read` after `Tcp.close` prints `Divide.main:66 faulted: callee was closed`.
- In the shell, when the input's process ends, the listener it owned is killed, and the accepting process prints `Divide.main:65 faulted: callee was killed` at `Divide.serve:6`.

Neither line mentions a socket or a listener.

**C5. Foreign faults leave out the values.**
- The wrong-shape fault (`the return of foreign function erlang:binary_to_list/1 does not match Int`) does not show the value returned.
- A raise drops the argument the host would show, `<<"eighty">>`.
- `Foreign.atom` given 300 characters prints `erlang:binary_to_atom/1 raised error:system_limit`, not the plain 255-character rule.

**C6.** `Left(NotLoaded)` names nothing on the caller's side; only `foo`'s standard error names the binding (`peer/loaded.ern`).

**C7.** An `Io.Error` carries no path: the program's own fault reads `cannot read: NotFound` (`file/totals.ern`).

**C8.** `:faults` prints identical lines for different processes spawned at the same site, with no process and no time.

**C9.** A test that loops for ever is never ended or named (`tests/spin/spin.ern`). After `first: passed` there is silence, even on `SIGINT`, and there is no time limit per test.

**C10.** A wait across nodes that nothing can satisfy (`Remote.held`) hangs silently. Guide §5.4 could say that a wait on another node's process is never treated as a deadlock.

**C11.** After a failed `:load Settings`, the shell's help suggests `:load Settings puts it in scope`, the command that just failed.

**C12.** The report says nothing about a negative timeout; `Fs.read(path, -5)` answers `Left(Timeout)` (`file/edges.ern`).

**C13.** A process spawned inside a helper function is sited at the helper (`Sites.launch:6`), not at the caller that asked for it (`misc/sites.ern`).

#### Where the language made the programs harder to write

**H1.** `let ratio = fn(line) = Int.toString(line.total / line.count)` is refused with "the operand type of `/` is not determined; annotate it", underlining the division. The real cause is the field read on a lambda parameter with no type annotation, and the message does not say what to annotate.

**H2.** `main : Unit` with `receive { after 500 -> Unit }` is refused, and the help says only "give main its mailbox type with `receiving`". It does not say that `Never` is the type to give.

**H3.** Finding what a hung process waits on takes `List.map(Process.live(), Process.status)`, since `:processes` shows no activity and no queue length.

**H4.** Work on a peer cannot be tested with `Test.Case` at all, because of B2.

#### What reads well

Every local case tried under `ern run` and `ern test` leads to the line:
- chains (`call/ledger.ern`)
- lambdas, named by their declaration with an exact line (`lambda/prices.ern`)
- monitor and alarm wraps (`wrapped`, `alarmed`)
- an adapted address's function, whose trace shows the sender's `send` line
- a foreign raise and a wrong return shape
- an initializer's fault, in every job
- a restart past its limit
- `Test.faults` with the wrong cause

`callee returned without answering` and `callee is unreachable` say exactly what happened. A peer's report of a process another node spawned names both the site and the spawner. Every command ran in about 1.3 s or less.
