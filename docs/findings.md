# Findings of the release review before 0.10.0

The review of 2026-11-10 over commit `7e7cdee1`, run as [`reviews/release.md`](reviews/release.md) says. A fresh clone built in 8 seconds and ran `make test-full` green in 414 seconds, alone on the machine. Over the same commit, in that clone: `make sections` empty; `make service` green under systemd, launchd's checks waiting for a Mac; `make load` flat in 61 seconds; `make sanitize` green in 321 seconds, once clang was installed on nike; `make test-browser` green in 9 seconds, under the readers' load. The bench ran three times on the idle machine after the readers ended.

Twelve readers, each a session of its own given its brief and its files, all on the stronger model: P and K over the report's diff since v0.9.0, K over the argument's paragraphs for the eleven rules of §3 to §9 that changed; N the newcomer; L and M over the README, *Why Ernest*, the tour, the questions and the guide's changed chapters; U over what teaches the changed rules; and the code's reader in six parts, C1 the runtime with its helper, C101 the nodes, the command line and the shared modules, C201 the compiler, C301 the standard library and the shell, C401 the libraries, and C501 the site's generator, read whole on the user's word.

## The lines

A line is `fix`, made in the review's round; `decide`, with the user, in the batch the last section names; `felt`, a line of `docs/language_feedback.md`; or `dropped`, with the reason; and `done` with the date once made. S1 to S4 are the sessions' own.

### The report

- P9, K4 — Appendix F's *shape rule* says "one of the ten rules"; E.0 has eleven. fix: "one of the rules". done 2026-11-10.
- P12 — E.21's `Process.run` says nothing of a mailbox type nothing fixed. fix: the type is `f`'s, `Never` where nothing fixed it (§6.2), once the code is read for it. done 2026-11-10: E.21 says so; the code read, the checker gave the function given to `Process.run` or `Test.faults` no such rule, so a `receive` in one with nothing fixing its mailbox compiled and met the deadlock when run, and is now refused as a spawned function's is, `run_mailbox_is_never_test`.
- P14 — E.1's `Other(text)` for a file promises Ernest's words, and E.18 states the host's term for `ssl.app`. fix: E.1 names E.18's exception, a file of the host's own. done 2026-11-10.
- P15 — "a `.erc` whose code the host will not load" names no case, in §11, §11.1 and E.28. fix: §11 names the cases once, a code chunk damaged or compiled for another major release of OTP. done 2026-11-10.
- P16 — §4.2's "A module namespace may not coincide with a namespace of the prelude or the standard library" is held by the sentence after it. fix: the first goes. done 2026-11-10.
- P17, K10 — §11.8 and §12.1 end a job "by the hangup's signal" with no status, where SIGPIPE's and SIGINT's are given. fix: the status the code gives, stated in §11.8 and cited from §12.1. done 2026-11-10.
- P-H — Appendix H's "a pipe whose callee is ... a lambda" reads as the lambda applied to the value, where `1 |> (fn(a) = fn(b) = a + b)(2)` is filled as a chained call. fix: one sentence, the callee being the chained call's head. done 2026-11-10.
- K3 — §4.2's *Declarations are local* shows `Net.Http.parse`, which *Qualified lookup* refuses inside `Net.Http`. fix: "its shortest resolving form", showing `Http.parse`. done 2026-11-10.
- K9 — §6.9's restart waits until each service monitor's wrap has placed its message, and §7.4 has a wrap the runtime has no room to apply fault the watcher, placing nothing. fix: §6.9 states what the code does then, as §8.6 says of the end. done 2026-11-10.
- K11 — §11's "what it logs as it ends the job" against §11.2's and §11.8's "its message". fix: §11 names the one line written. done 2026-11-10.
- K12 — §8.7 and §12.5 cite each other for the patch-release rule. fix: §12.5 states it, §8.7 cites it. done 2026-11-10.
- K13 — §11.5's "printed whole ... the module's own types and the prelude's unqualified" reads against §4.2's "print a name whole". fix: §4.2 says it once, §11.5 cites it. done 2026-11-10.
- K14 — §4.2's "where `Command.parse` resolves" and the root tie decided by load-path order. fix: "resolves to it", and the tie's rule cited where it is stated. done 2026-11-10.
- K16 — E.24's `Test.faults` "runs `run` as `Process.run` runs a function", where only `Process.run` reports the fault. fix: "as `Process.run` runs one, but marked". done 2026-11-10.
- U3 — the cookie stands on a node's command line, which `ps` shows, in the deployment guide's §2.2 and the questions, and in no report section. fix: one sentence in §12.5, which the two guides cite. done 2026-11-10.
- K5, C4 — an empty `workingDirectory` answers `Left(Other(": NotFound"))`, a line naming no directory, where E.23 makes an empty variable name `Invalid`. fix: `Invalid`, refused before the helper; E.23's sentence names it. done 2026-11-10 in the runtime; E.23's sentence done 2026-11-10.
- P10 — §11.1's "a node reads its build's units from its build directory at its start alone". fix: the build's and the shell's, at its start and never after. done 2026-11-10.
- P2 — `Test.capture` captures a service's writes under `ern run`, which E.24 says it does not. decide, D2. decided 2026-11-10: E.24 states the head by job; the report's sentence done 2026-11-10.
- P3, K1 — §7.4 and §12.5 make a full table at a `Terminal` request a value, where §12.1 and §12.3 fault the entry process at the subscription. decide, D4. decided 2026-11-10: a subscription the table leaves no room for is a value, a key after it the entry process's fault; §12.1 and §12.3 and the runtime done 2026-11-10.
- P5 — §12.5's listener retries after 7 seconds at the limit of open files, against §0's "retries nothing". decided 2026-11-10: the acceptor stays, and §0's *Time* says the runtime retries nothing of a program's and a wait of the node's own on what the host does not signal is a time the report states; done 2026-11-10.
- P6, K15 — a root module a nearer namespace hides is out of reach, and the diagnostic says only `unknown name Top.Shell.Util.g`. decide, D8. decided 2026-11-10: the rule stands; the help names the hiding module; done 2026-11-10.
- P13 — `String.fromUtf8Piece(<<245>>)` holds a byte that begins no character as a piece not yet finished. decide, D9. decided 2026-11-10: dropped, decided in the log's *Text from Bytes* (principle 2).
- P18, K8 — every node holds the shell's units from its start. decide, D6. decided 2026-11-10: dropped, decided in the log's *A Node Holds the Shell* and *Lean at the Limits*.
- P1 — `Os.Command`'s five fields cost every program that starts one two features it does not use (§0 principle 5). decide, D7. decided 2026-11-10: `Os.command` in E.23 and at its 53 sites; done 2026-11-10.
- P4, K2 — E.18 states that a run's first TLS call at a full table may never answer, against shape rule 8. dropped: decided in the log's *A Program's TLS at a Full Table* and *Lean at the Limits*; the defect is OTP's (`docs/otp_bugs.md`, 17).
- P7 — a file named after a taken namespace is refused at any depth. dropped: decided in the log's *Relative Names*; the release's note tells a program to rename such a module.
- P8 — a load past one of the host's limits ends the node. dropped: decided in the log's *A Load Past the Host's Limits*.
- P11 — text and octets have `drop` without `take`. dropped: decided in the log's *A Text after Its Prefix*.
- S7 — §11.2 parts an example by its paragraphs' first tokens, and `ern test` takes the longest run of first paragraphs that parses as declarations, so an example whose body holds a blank line passes there and would not by the report's rule (C501's round, run by the session). decide, D17. decided 2026-11-10: §11.2 states the parse rule; done 2026-11-10.

### The argument

- K6 — "so a process reads it only with its value" does not follow while a refused load leaves its evaluated bindings without a value. decide, D10. decided 2026-11-10: the read faults as §7.4 says, stated in §11.2, E.28 and the argument; done 2026-11-10.
- K7 — the `Code.running` paragraph rests on a mailbox type's hash, which a function that receives nothing does not have. decide, D11. decided 2026-11-10: E.28 says the definitions at `Never` count; done 2026-11-10.

### The guide, the tour, the README and the questions

- U1 — the language guide's §5.5 says `kill` takes any of a process's addresses; it takes a `Process`. fix. done 2026-11-10.
- U2 — §9.1's list of what compiles a module again lacks §11.1's qualified name that now resolves elsewhere and the `.erc` that is no compiled module, and says one case twice. fix. done 2026-11-10.
- U4 — the deployment guide never says that a node with a full table of processes ends with status 1 when it dials a peer. fix: §1.4's status 1 and §7's table. done 2026-11-10.
- U5 — the deployment guide's opening lists the machines its numbers were measured on, and §6 quotes two it does not list. fix: "each says which" alone. done 2026-11-10.
- U6, U7 — citations left at the old section: §6.3's §7.3 for §7.4, the deployment guide's §6 cites §12.7 for §11.2's *The attached shell*. fix. done 2026-11-10.
- U9 — §8.6 says a stream may end inside a character, and names neither `String.fromUtf8Piece` nor `fromUtf8Lossy`. fix: one sentence naming `fromUtf8Piece`. done 2026-11-10.
- M1 — the tour names four of *Why Ernest*'s claims by their old order. fix: each by its title. done 2026-11-10.
- M2 — the tour writes Gleam's `process.receive(subject)` with one argument. fix: the two-argument form. done 2026-11-10.
- M3 — the README and *Why Ernest* say Gleam's `process.receive` panics for any subject not owned; the page excepts a named one. fix: "a subject it did not make". done 2026-11-10.
- M4 — §4.4's "it was closed" among a callee's ends, before any closing is taught. fix: name the kind of process that closes. done 2026-11-10.
- M5, L10, N8 — §4.1's `fn stop() = kill(Process.fromAddress(self()))` is a `() -> Unit`, with no clause saying why, and `kill` and `fromAddress` not yet taught. fix: the clause, and the two sections cited. done 2026-11-10.
- M7 — the questions' answer for a Gleam reader maps no everyday type: `Result` to `Either` with its parameters the other way round, `Option`, `Nil`, `Pid`. fix: one line. done 2026-11-10.
- M8 — *Why Ernest* asserts that `spawn` gives a typed address and never names the handshake a Gleam spawn needs. fix: one sentence. done 2026-11-10.
- M10 — §7.3's *How `OrderedSet` is written* quotes forty lines for one sentence. fix: `fromList` and `map`. done 2026-11-10.
- M13 — the tour's terminals: a second and a third, and chapter 1's shell not said quit. fix. done 2026-11-10.
- M14 — the questions' three systems and three clauses do not match. fix: each its clause. done 2026-11-10.
- N1 — `Counter.main:59` and `Counter$2.main:59` in the language guide's §9.3 and the deployment guide's §5.3; the spawn is on line 60. fix. done 2026-11-10.
- N2 — §8.1 says §4.4's `gathered` spawns monitored; it runs each piece under `Process.run`. fix. done 2026-11-10.
- N3 — the README's two "four commands" count two different sets. fix. done 2026-11-10.
- N4, N5 — a deadline given with nothing saying what it counts: the README's `Peer.spawn(..., 5000)` and `Address.call(..., 1000)`, with `let far <-` untaught, and §1.3's `Os.run(..., 5000)`. fix. done 2026-11-10.
- N7 — §3.3's `spawn(fn() = cell(None))`, with `cell` defined nowhere. fix. done 2026-11-10.
- N9 — §8.1's `board.ern` calls `Proxy.start` eighty lines before a proxy is taught. fix: a pointer. done 2026-11-10.
- N10 — the rule for a `callForever` caller's fault line stands whole in §4.4, §6.3 and §6.5. fix: stated in §6.3, cited from the others. done 2026-11-10.
- N11 — §13 *Reading further* names the log for "why Ernest looks as it does" and not *Why Ernest* or the questions. fix. done 2026-11-10.
- N12 — the README's opening claim opens on what three systems lack. fix: the three additions first. done 2026-11-10.
- N13 — §1.3's `Os.arguments` is not said to be a binding. fix: the guide's line; the naming rule is D14's. done 2026-11-10.
- N14 — the README says the questions are a Gleam or Erlang programmer's; they are a Unison programmer's too. fix. done 2026-11-10.
- N15 — §7.3's "`:doc OrderedSet` lists it", where `:doc` shows documentation. fix. done 2026-11-10.
- L1 — a host library's timer or unmonitored process that answers after its call returns is the one false deadlock, said only in the deadlock's claim. fix: one sentence where *Why Ernest* and the questions teach foreign code. done 2026-11-10.
- L2 — *Why Ernest*'s WAN claim does not say it is Erlang's own distribution underneath. fix: the questions' sentence cited. done 2026-11-10.
- L4 — *Why Ernest* does not say a peer tells its utilization again. fix: every `utilization-interval`. done 2026-11-10.
- L5 — the README's console needs `foo` running, which it never says. fix. done 2026-11-10.
- L6 — the deployment guide's systemd unit names no `PATH` for an OTP outside `/usr/local`. fix: one line. done 2026-11-10.
- L7 — §8.1's trace across a compute reads as one frame printed twice. fix: the sentence says which is the peer's. done 2026-11-10.
- L8 — the tour explains one run's 0.25 after the fact. fix: "the numbers are one run's". done 2026-11-10.
- L9 — *Why Ernest*'s first program writes `Upgrade(=next)` before the guide teaches the pun. fix: a clause under the block. done 2026-11-10.
- L14 — the tour's chapter 2 session stands in the README, the guide's §1.4 and the tour, and no test holds the guide's copy. fix: a test holds it. done 2026-11-10.
- L16 — the questions restate *Why Ernest*'s closed-set paragraph. fix: the questions point at it. done 2026-11-10.
- U8, M15 — `Code.running`'s "earlier definition" and its printed type in §8.9. decide, D11. decided 2026-11-10: the guide's "another version" and the printed type is not the rule; done 2026-11-10.
- L3, M6 — `show` is "no member" in three documents, and the compiler's message lists it among what a requirement names. decide, D12. decided 2026-11-10: the message "is not what a requirement names" and the clause on what `Io.show` reads from the type; done 2026-11-10.
- M9, M12 — *Why Ernest*'s code-travels claim carries the guide's operational rules; its requirements section never grants the likeness to a type class. decide, D13. decided 2026-11-10: both; done 2026-11-10.
- M11, N6 — the trace frame `Process.run:259`. decide, D1. decided 2026-11-10: the guide's §6.3 says a library frame names the library's source's line; done 2026-11-10.
- L11, L12, L13 — a pipe in parentheses, a sibling that never waits, a `Down` with no order: tripped on, each stated. dropped: no change asked.
- L15 — the `other.ern` refusal twice. dropped: a test holds the two.
- L17 — a prompt's `let` and a peer's `NotLoaded` stated in four places. dropped: the tour and the guides teach, and a teaching document restates (CLAUDE.md, *Restating*).
- M-K — `--load-path` beside `--libs-dir`. dropped: the reader found a use for each.
- N-F — the formatter breaks `| None -> Unit` where another clause is a block, which the guide does not state. dropped: §11.6 owns the layout, and the guide cites it.

### The runtime and its helper

- C1 — a restart ends the process's subscriptions and not its captures, so a `Test.capture` whose `run` faulted in a restarting process swallows every later write until the program ends, and its collector grows. fix: the restart lets the captures go as the caller's end does, the capture's row keeping its caller; E.24 says a restart ends a capture, as §6.9 begins a run afresh. done 2026-11-10 in the runtime, narrower: a restart ends the captures its run began, and one begun before an inline `restarting` stands, since ending it would leave its `captured` a dead collector; E.24's sentence in the design session.
- C3 — `captured/1` waits on the collector with no monitor. fix: a monitor, the caller faulted on its `DOWN`. done 2026-11-10.
- C5 — `limited` names four shapes in five modules, and `ern_peer:limited/0` copies `ern_io`'s. fix: the copy goes, `limited` the value alone. done 2026-11-10.
- C6 — `taken/1` and `taken/2` in `ern_rt` name two things. fix: `input_taken/1`. done 2026-11-10.
- C7 — each write reads the writer's row twice, and `docs/design/runtime.md` counts the screens' lookup alone. fix: the root read once; the note's count. done 2026-11-10.
- C8 — `gone/1` sends through `launch_runner/0` as `told_runner/2` does. fix: `told_runner(gone, Name)`. done 2026-11-10.
- C9 — `kill_program` kills the group and then the program, which leads its group. dropped: under pipes a program may join another group of its session, the helper's among them, which the group's kill misses, so the second kill stays; its comment now says so and `kill_reaches_a_program_out_of_its_group_test_` holds it (E.23's "`kill` stops it", principle 1).
- C10 — `wait_for_let_go`'s comment lacks `'p'`. fix. done 2026-11-10.
- C11 — `ern_tty`'s "a kill from outside among the ways, which gave the settings back", where a KILL gives nothing back. fix: "where it could". done 2026-11-10.
- C12 — three words for ending what a refused subscription made in `ern_tty`, and `let_go` meaning three things across the runtime. fix: one word each. done 2026-11-10.
- C13 — `ern_code` drops the mailbox hash from a function's row and reads it again from every holder at each `Code.running`. dropped: a name finds a definition's other versions only through its unit's code list, so keeping the hash in the row removes no read of those lists, and a row holding a name and a mailbox for every function is a cost every run pays for a rare call (the log's *Lean at the Limits*).
- C14 — `wait_for_deliveries/0` waits for the fault courier too. fix: the name says so. done 2026-11-10 by the glossary's **Delivery**, which names the reports; the name stands in the shell's foreign declaration and its design note.
- C2 — the helper kills the program's group only once both outputs have ended, so after `Os.signal` a child holding the output outlives the program, against E.23's "killed with it". decide, D3. Done 2026-11-10: the helper kills the group as the host reports the exit, `group_killed_at_the_exit_test_`.
- C15 — a terminal with no `stty` is subscribed with no mode set. decide, D4. decided 2026-11-10: a subscription whose mode cannot be set answers `Left(Other(text))`; §12.1 and the runtime done 2026-11-10.
- C16 — one host reason, two texts, by which table was full. decide, D4. decided 2026-11-10: dropped, E.1's rule gives each text.
- C17 — `kill(Process.fromAddress(program))` at every probe. dropped: decided in the log's *`kill` Takes a `Process`*, its cost stated there.
- C18 — `Terminal.Size(24, 80)` refused for named fields. dropped: the rule, its message clear.
- C1-S — `Fs.makeTempDir`'s directory stands with the mask's mode before its own. dropped: E.17 states the order, nothing can be written there in the window, and the host makes no directory with a mode.

### The nodes and the command line

- C101 — §12.5's accept at a full table of ports has no test. fix: a nodes test over `accepting_nodes(Base, <<"ports">>)`. done 2026-11-10.
- C102 — in a job that starts no run, the host's first warning at a full table of processes raises inside the log handler, which the host then removes. fix: the sayer started in `ern_out:take/0`. done 2026-11-10.
- C103 — the node's own `nodeup` is filtered in the gateway and in the carrier. fix: the carrier's clause, comment and test line go. done 2026-11-10.
- C104 — `limit_filter/2` drops reports that are no limit's. fix: named for what it drops. done 2026-11-10.
- C105 — `Ended` in `ern_gateway` holds peers that never ended, and `ended/3` means a `DOWN`. fix: named for what each holds. done 2026-11-10.
- C106 — `?PROTOCOL` is the frames' version in the carrier and the transport's name in `ern_tls_dist`. fix: `?TRANSPORT` in the second. done 2026-11-10.
- C107 — a peer's certificate is decoded three times for one field. fix: one plain decode. done 2026-11-10.
- C108 — the carrier's comment says a refused connection's line names a peer, where `opened/4` names none. fix. done 2026-11-10.
- C109 — `quiet_signals/0`'s comment gives a test as the one case, and the launcher's first start is the one that matters. fix. done 2026-11-10.
- C110 — `ern_chunk:read/2` takes a file name no caller passes. fix: bytes alone. done 2026-11-10.
- C111 — before the handshake proves a key, idle connections can hold every slot for the dial's time. dropped: the host's own acceptor has the same bound, and nothing regressed.
- S4 — in the launcher's first start the host's own handler writes a warning or an error on standard output before `ern-node-flags`, and `bin/ern` drops every flag (C101's round, C109's rest). fix: `node_flags/0` takes the handler as `ern_out:logged/0` does. done 2026-11-10.

### The compiler

- C201 — the `#env{}` comment names `own_shortest/4`; it is `/2`. fix. done 2026-11-10.
- C202 — `inner_or/1`'s comment and a parser test reason from a `match` in a size, which §5.11 refuses. fix: the comment says a size holds no pattern of the clause's; the test's example goes. done 2026-11-10.
- C203 — `binexpr_loop/3`'s comment says a pipe fills a parenthesized call, which `combine/4` no longer does. fix: the comment goes. done 2026-11-10.
- C204 — `#emit_context{}`'s comment lacks `in_lambda`. fix. done 2026-11-10.
- C205 — the checker's answer joined with the too-long errors in two modules. fix: in `ern_typecheck:check` once. done 2026-11-10, as `check_resolved/5`, since `check/5` is the shell's.
- C206 — the caller-site arity in three places. fix: `ern_emitter:site_arity/1`. done 2026-11-10.
- C207 — one span formula in `ern_resolve` and `ern_typecheck`. fix: `ern_resolve:name_span/2` exported. done 2026-11-10.
- C208 — `mailbox_hash/1` nests three cases. fix: one case over two tests. done 2026-11-10.
- C209 — `namespace = Namespace, written = Namespace` at 13 sites. fix: `qualified/2`. done 2026-11-10, as `namespaced/2`, since `qualified/1` and `/3` read a name from tokens.
- C210 — `too_long/…`'s spec types its span as `term()`. fix. done 2026-11-10.
- C211 — `segment_value` names two things in the formatter and the emitter. fix: `hugging_segment/1` in the formatter. done 2026-11-10.
- C212, C213 — `too_long_or_not/5` and four names around one idea in `ern_resolve`. fix. done 2026-11-10.
- C214 — `docs/code_style.md`'s **HelpText** names `ern_parser:pattern_text/1`, which the parser does not export. fix: the entry. done 2026-11-10.
- C216 — `Process.live()` lists a run's judge. decide, D1. decided 2026-11-10: E.21 says `live` lists the entry process; done 2026-11-10.
- C218 — `List.length` is an unknown name with no help. decide, D14. decided 2026-11-10: dropped, a help names a fix the compiler knows.
- C215, C217 — `ern_rt:caller_site/0` a declaration's target only; a probe polling `Process.status`. dropped: by design, noted by the reader.

### The standard library and the shell

- C301 — the shell's help after an unknown name offers `:load Foo` for a `.erc` that holds another module, which `:load` refuses. fix: `is_form_loadable/2` over `compiled_of/2`. done 2026-11-10.
- C302 — a declaring input whose spawn alone meets a full table stays loaded and recorded for the session's life. fix: the catch undoes the three records, as `withdraw_load/2` undoes a load's. done 2026-11-10.
- C304 — `fromUtf8Lossy`'s page and E.5 say a byte that begins no character is one U+FFFD; a character the bytes end inside is one a byte. fix: the page and E.5. done 2026-11-10.
- C305 — `Test.equal`'s character count is over the texts as shown, quotes included. fix: the page and E.24 say so. done 2026-11-10.
- C306 — four top-level `let`s of the shell became functions with no comment why. fix: one comment citing the log's *The Shell Attaches as a Program Spawns*. done 2026-11-10.
- C307 — `test.ern`'s `wanted` and `got` beside `expected` and `actual`. fix: `expectedText`, `actualText`. Its `faulted` stays: the log's *The Release Review Before 0.9.0* made a participle with an effect a verb. done 2026-11-10.
- C308 — a filter-only comprehension as an `if`, and a source that is a device refused as "is a directory". fix: a `case`; "is not a regular file". done 2026-11-10.
- S3 — an input whose compile meets a full table loses its namespace number, two atoms each time, which no collection reclaims (C301's round). fix: `spawnInput` answers the session, and the number goes back to `free`. done 2026-11-10, C302 undone the same way.
- C309 — `Os.signal`'s `Left(Closed)` after the exit, and a program that handles the signal, have no test. fix. done 2026-11-10.
- C303 — `Process.run`'s judge is a plain spawn at the library's line, listed by `Process.live()` and framed in a fault's trace. decide, D1. decided 2026-11-10: E.21 states the judge and the library's frame, as the log's *A Worker's Value or Its End Built* decided; done 2026-11-10.
- C312 — `environment = [], workingDirectory = Os.workingDirectory` at 52 sites. decide, D7. decided 2026-11-10: `Os.command`, with P1; done 2026-11-10.
- C310 — what was kept: C301 and C308. dropped: those lines hold it.
- C311 — `Fs.makeTempDir` before its mode, and `rand:bytes`. dropped: as C1-S.
- C313 — `kill(Process.fromAddress(...))` at 25 sites. dropped: as C17.
- C314 — `Io.debug(x);` refused as a statement. dropped: the rule, whose message names it.

### The libraries

- C401 — a head whose last line the host cannot read waits for the next byte, so `readRequest` answers `Socket(Timeout)` at its deadline where G.11 says `Protocol(Malformed)`. fix: where the field reader answers more and the bytes hold a line feed, ask again with a byte that begins no fold, and answer `Malformed` where that is unreadable. done 2026-11-10, wider: a field `headerOf` refuses is refused at once too.
- C402 — the first line's shim does work the Ernest does again. decide, D16. done 2026-11-10: the shim kept, its comment saying what the host contributes, the host's DEL and its empty line closed around it.
- C403 — `taken` two things, a parameter `headers` hiding the function, a local `sized` hiding the top-level one. fix: each renamed. done 2026-11-10.
- C404 — `libs/ansi` writes the introducer two ways. fix: a comment naming the log's *The Shell Attaches as a Program Spawns*. done 2026-11-10.
- C405 — two checks in `renderResponse` as statements beside four `check` functions. fix: `checkStatus` and `checkBodiless`. done 2026-11-10.
- C406 — a silent default for a case said not to come, in `chunk` and `dayName`. fix: a fault with its cause. done 2026-11-10, `monthName` among them.
- C408 — `renderResponse`'s page says a head that would not read back faults; two such heads are written. fix: the page names the four checks. done 2026-11-10.
- C409, C410 — "regression tests, written with the code", and a comment's history of the replaced shim. fix. done 2026-11-10.
- C411 — no case splits the empty line's `\r\n` across the carried bytes with the limit spent. fix: one case. done 2026-11-10.
- S5, S6 — a header name holding U+007F is accepted, the host's table reading DEL as a token character, and the head's empty line passes `line = 1`, where `decode_packet` checks no size on a buffer that is exactly CRLF (C401's round). fix: each refused in Ernest around the host, as G.11's token and limit say. done 2026-11-10: a method's and a name's DEL refused in the shim, where the Ernest cost a browser's head 2 µs in 9; an empty first line held to its limit; the head's last empty line under a limit of one is unreachable, since no first line fits in one byte.
- C407 — `cookies` keeps a name's and a value's spaces and an empty name. decide, D15. decided 2026-11-10: RFC 6265bis's reading; G.11 and the library done 2026-11-10.
- C412 — a byte-a-packet client rescans its buffer within the limits. dropped: bounded as G.11 states.
- C401-L4 — a broken JSON literal's position is built before a guard may drop it. dropped: an error path.

### The site's generator

- C501 — a link that begins with `/` is read as relative and led to a GitHub path that does not exist, silently. fix: refused, with the text the reader gives. done 2026-11-10.
- C502 — a page that opens with a bold label is described by the label, `§1.5.`. fix: the label passed over. done 2026-11-10.
- C503 — a block holding a blank line inside a body is offered for copying alone. fix: a paragraph counts as a declaration only where its first token stands at the first column. done 2026-11-10.
- C504 — the code and the design note cite §11.3 for §11.2's reading of an example. fix. done 2026-11-10.
- C505 — five exports no other module uses. fix: each made private. done 2026-11-10.
- C506, C507, C508, C509 — `lifetime`, `lines`, `Shown` and `Owner` each name more than one thing. fix: `lifetimeText`, `summaries` and `others`, `Anchored`, `Cited`. done 2026-11-10: `lifetimeText`, `summaries` and `toolchain`, `Anchored` then gone with C511, `Cited`.
- C510 — `Document.tested : Bool` chooses where `Book` passes a function. fix: `Document.placing`. done 2026-11-10.
- C511 — a heading list paired by position, built four ways. fix: a `Placed` carries its `Headed`. done 2026-11-10.
- C512 — page writers named as nouns beside participles. fix: participles throughout. done 2026-11-10.
- C513 — a module page finds its first sentence twice and its signatures twice. fix. done 2026-11-10.
- C514 — `found`, `heading`, `report` and `page` hold what their names do not say. fix. done 2026-11-10.
- C515 — a link to a directory goes to `blob/`. fix: `tree/`. done 2026-11-10.
- C516 — two numbered headings of one text would collide unseen. fix: keyed by the numbered slugs. done 2026-11-10: the anchors computed once, as GitHub numbers them; a heading whose anchor `Char` cannot compute now leaves every later one unknown, so a numbered document is refused where it stands before two headings sharing digits, none today.
- C517, C518 — the shim's header names the wrong module; a report page called a chapter. fix. done 2026-11-10.
- C519 — the site's test copies the working tree's `site/` whole and needs the repository's history unsaid. fix: `git ls-files site`; the header says so. done 2026-11-10.
- C520 — a comment states a reason the design note does not. fix: the note's sentence, the comment citing it. done 2026-11-10.
- C521, C522 — an HTML block a document writes goes into the page as it is, and `escaped` leaves `'`. fix: the design note says the first; `'` escaped. done 2026-11-10: the note says the first; `'` stays, the note saying every attribute is quoted with `"`, where escaping it would rewrite every page's apostrophes.

### The machines and the review's documents

- S1 — without clang, `make sanitize` ends on the shell's `clang: not found`, where `make test-browser` says what it lacks with status 2. fix: the same. done 2026-11-10.
- S4 — the decisions' sentences read cold (the design session's own): the no-value cause said "since one before it faulted" where a refused load's evaluator or caller was killed and nothing faulted; G.11 cited RFC 6265bis for a reading the draft does not give; §11.2's example rule was wider than `ern_examples:declared/3`. fix: the cause `since its load did not finish`, the citation gone, the rule "empty lines, short of its last paragraph"; the sentences and the cause's text done 2026-11-10.
- S2 — `docs/reviews/full.md` puts `findings.md` "beside this one", in `docs/reviews/`, where CLAUDE.md's owner table and every review put it in `docs/`. fix: `docs/findings.md`. done 2026-11-10.
- B1 — the bench: `String.stripPrefix` costs 4.9 times `string:prefix/2` in all three runs, three walks of the prefix where the host's one, new at 0.10.0. The host's function is not exact: over 1,000,000 random texts it differs in 135, answering `nomatch` for a whole pair of regional indicators, U+1F1EA U+1F1EA before U+1F1F8, and the rest for a prefix that ends inside a conjunct, U+0915 U+094D of U+0915 U+094D U+0915, against `string:to_graphemes/1`'s own clusters. decide, D18; the host's two answers to `docs/otp_bugs.md`. decided 2026-11-10: the Ernest stays, the host's function inexact both ways; `docs/otp_bugs.md`'s 21st done 2026-11-10.

### Felt

Each line is a feedback entry, decided by MVP 4.16's item 12.

- C401-L1 — a byte's class is written by hand in every library: seven range tests over `src/libs/`. felt, feedback 237, sharpening the log's *The Libraries' Shims Read Against E.0 Rule 1*, which counted two sites.
- C523-a — `List.flatMap(lines, fn(each) = each)` at 13 sites of the generator. felt, feedback 238, sharpening the log's *What MVP 2.95 Takes From the Rest*.
- C523-b — `let _ <- List.tryMap(...)`, a failing walk whose list is thrown away, five times. felt, feedback 239.
- C523-c — a refusal's text built by `<>` with `Path.toString` and `Io.show`, eight times. felt, feedback 240.
- C523-d — text walked by `String.toList`, 17 times, for want of a span or a character at an index. felt, feedback 241.
- N-L1 — a function whose result only reports costs `let _ = ...; Unit` where the result is not wanted. felt, feedback 242.
- N-L2 — `Bool` has no `compare`, so a record of flags cannot be sorted or derive `compare`. felt, feedback 243, sharpening the log's *One Name for Every Order*.
- N-L5 — `Peer.offer` answers `Either(Process, Unit)`, a `Left` that is no failure. felt, feedback 244.
- C401-L2 — a local that hides one of its module's top-level names is silent. felt, feedback 245.
- C401-L3 — a check that faults has no form of its own. felt, feedback 246.
- C524 — `Char` gives no Unicode category, so no question's heading can hold a dash or a `§`. felt, feedback 247, sharpening feedback 219's verdict.
- N-L3 — a constructor takes one positional field or named fields. dropped: the rule of §3.5, "no fields, exactly one positional field, or named fields".
- N-L4 — a name written in its shortest resolving form. dropped: decided in the log's *Relative Names*.

## The decisions, in batches

Each is argued with the user, the argument before the verdict, after the log is searched and the program run. A batch holds lines that one decision settles; the rest stand alone.

- **D1, `Process.run`'s judge and a library's frame in a trace:** C303, C216, M11, N6. Decided 2026-11-10: as the log's *A Worker's Value or Its End Built* decided, stated in E.21 and the guide.
- **D2, a service's writes in a capture under `ern run`:** P2. Decided 2026-11-10: E.24 states the head by job.
- **D3, a program's group at its exit:** C2. Decided 2026-11-10: the helper kills the group as the host reports the exit, before the outputs end, and reaps the program as it sends the exit, as E.23 says. Built the same day.
- **D4, a terminal's subscription the host cannot serve, and the texts of a full table:** P3, K1, C15, C16. Decided 2026-11-10: a subscription the table leaves no room for, or whose mode cannot be set, is a value; a key after it faults the entry process (§7.4); the texts stay E.1's.
- **D5, the listener's retry against §0's *Time*:** P5, sharpening the log's *The Carrier's Acceptor at a Full Table*. Decided 2026-11-10: the acceptor stays; §0's *Time* gains the node's own wait on what the host does not signal, a time the report states, since the alternatives, resuming on a program's close or a reserve descriptor, miss the host's own files or race.
- **D6, the shell's units from a node's start:** K8, P18, sharpening the log's *A Node Holds the Shell* against *Lean at the Limits*. Decided 2026-11-10: dropped, the two entries stand with their measurements.
- **D7, `Os.Command`'s two inherited fields:** P1, C312, sharpening feedback 184's verdict. Decided 2026-11-10: `Os.command(program, arguments)`, since principle 5's sentence outranks E.0 rule 4's refusal of a shortening; the record stays the one form of a command whole.
- **D8, a root module a nearer one hides:** P6, K15. Decided 2026-11-10: the rule stands (*Relative Names*); the help names the hiding module.
- **D9, a piece that can begin no character:** P13. Decided 2026-11-10: dropped (*Text from Bytes*).
- **D10, a refused load's window in the argument:** K6. Decided 2026-11-10: the read faults as §7.4 says; §11.2, E.28, §7.4 and the argument say so.
- **D11, what `Code.running` lists:** K7, U8, M15. Decided 2026-11-10: the definitions at `Never` count; the guide follows.
- **D12, `show` in a requirement:** L3, M6. Decided 2026-11-10: the message says what a requirement names; the documents say what `Io.show` reads from the type.
- **D13, *Why Ernest*'s claims:** M9, M12. Decided 2026-11-10: both.
- **D14, the newcomer's names:** the eleven N lists apart, N13's bindings beside functions, C218's unknown `List.length`. Decided 2026-11-10: the names stand (*Names Read as a Newcomer Reads Them*, *The Library's Lines*); E.0 rule 2 says what the host gives at start is a value; C218 dropped.
- **D15, a cookie's spaces and an empty name:** C407. Decided 2026-11-10: RFC 6265bis's reading.
- **D16, `Http`'s first line read by the host or by Ernest:** C402. Decided 2026-11-10: the shim stays under E.0 rule 1, since Ernest alone cost 6.3 times the host on the first line and took the smallest head past the line; the Ernest closes the host's DEL and its empty line.
- **D17, an example's paragraphs:** S7, §11.2's first-token rule against `ern test`'s longest run that parses (`ern_examples:declared/3`), and the site's first-token rule with C503's continuation. Decided 2026-11-10: §11.2 states the parse rule, which the site's first-token reading approximates and its tests hold over the repository's blocks.
- **D18, `String.stripPrefix` past E.0 rule 1's line:** B1. The host's `string:prefix/2` cannot be its shim, being inexact both ways; the Ernest at 4.9 times stays, said in the log, or an adapter compares the bytes and reads the boundary at the prefix's end from its last grapheme and what follows, every boundary before it the prefix's own. Decided 2026-11-10: the Ernest stays; `docs/otp_bugs.md`'s 21st.

## The readers' lists

Each list as its reader handed it in, kept whole, since a line is too short to fix from.

### P

```text
# Reader P: the report's diff since v0.9.0, against the report and §0

Read: `S/diffs/report.diff` whole, then `R/report/language.md`, `toolchain.md` and `library.md` whole. Programs tried under `S/readers/P/t1` to `t12` with `R/bin/ern` (build with `--source-root d --build-root d/build d`, then `ern run d/build/main.erc`). Nothing in `docs/log/`, `docs/plan.md`, `docs/proposals/`, `docs/language_feedback.md` or `CHANGES.md` was read, so "the last counts the log records" are not compared here; the counts below are given with how each was taken.

## Defects

**P1. `Os.Command` makes every program that starts a program pay for two features it does not use (§0 principle 5; Appendix E.23).** `type Command = Command(program : String, arguments : List(String), input : Bytes, environment : List(#(String, String)), workingDirectory : Path)`. §0 principle 5: "A feature costs a program that does not use it nothing: no argument, no word, and no name of it is written there." §5.6: "All fields are given, each once", and E.23 exports no `Command` value to update from, so every `Os.start`, `Os.startTerminal` and `Os.run` site now writes `environment = [], workingDirectory = Os.workingDirectory` (the standard library's own examples in `src/stdlib/os.ern:31-35, 88, 139` do). Program `t1`: `Os.run(Os.Command(program = "true", arguments = [], input = <<>>), 1000)` is refused, `main.ern:2:18: missing fields environment, workingDirectory`. A reader who knows the rest of Ernest predicts a command of a program and its arguments. Fix: export a value to update from, `Os.command : (String, List(String)) -> Command` with empty input, no variable set and `Os.workingDirectory`, so a site writes `Os.command("true", [])` and `Os.Command(..Os.command("sh", args), environment = [...])` only where it uses the feature; or state in §0 that a record's field is no such cost, which the principle's own sentence denies.

**P2. `Test.capture` captures a service's writes under `ern run`, which E.24 says it does not (Appendix E.24).** "It captures what the caller's chain writes: the process at the head of the caller's spawns, a test's own under `ern test` (§11.2), and every process that one started ... A write by any other process, a system process's own or a service's, goes where it went." Under `ern run` the head of `main`'s chain is the entry process, which runs the initializers (§8.5) and so spawned every service; the service is in the chain. Program `t6`: `let logger = spawn(fn() = loop())` at top level, `Test.capture(fn() = { send(logger, "hi"); ... })` in `main`; the capture answers `<<"service: hi\n", "child\n", "me\n">>`. Fix: state the head by job, the test's process under `ern test` and the entry process under `ern run`, and drop "or a service's", or exclude the initializers' spawns from every chain.

**P3. Two rules for `Terminal.subscribe` at a full table of ports (§12.1 Keys, §12.3 against §12.5 and §7.4).** §12.1: "Where a full table of ports leaves no room to read the keys, at the subscription or at any key after it, the entry process faults with `Fault("the standard input could not be read: system_limit")`", and §12.3 says the same. §12.5: "A request of `Fs`, `Tcp`, `Os` or `Terminal` that the table leaves no room to serve ... answers `Left(Other("error:system_limit"))` (Appendix E.1), and the process that made it lives on, as at a full table of ports", and §7.4: "a full table of the host's that a request of `Fs`, `Tcp`, `Os` or `Terminal` needs room in, is a value with its cause (§12.5)." At the subscription both cannot hold. The host's reason is also spelled two ways for one event, `system_limit` in §12.1 and `error:system_limit` in §12.5 and E.1. Fix: decide one; the subscription answers `Left(Other("error:system_limit"))` and lives on, as every other request of a system module does, and the entry process faults only for a key after it, where no request stands behind the failure.

**P4. A full table of processes at a run's first TLS call hangs TCP's process with no time, against §0 *Time* and E.0 shape rule 8 (Appendix E.18).** "At a full table of processes (§12.5) the host's start may end the run ... or never answer, its milliseconds notwithstanding, and hold every later request that reaches TCP's process." §0: "A wait of the program's ends by the program's time, by the party it waits on, or by a time of the host's that the report states as the host states it"; shape rule 8: a function that waits "answers `Left(Timeout)` when they pass". The sentence admits a wait that ends by none of the three and takes every later `Tcp` request with it. The same sentence makes the full table exit with "70 where it ends a process of its own that `ern` needs (§11.8)", and §11 says "A failure of `ern` itself is a defect of the toolchain": a limit the program met is reported as a defect. Fix: TCP's process starts the host's TLS in a process of its own and answers the caller within its milliseconds, `Left(Timeout)` or `Left(Other(text))`; and a process of `ern`'s ended by the table is status 1 with the host's message, as §11.8's other limits are.

**P5. The node's listener retries on a time the runtime chose, against §0 *Time* (§12.5).** "A connection the operating system's limit of open files (§12) keeps the node's listener from taking waits unaccepted. The node tries to take it again each time 7 seconds have passed, the time after which §8.7 gives up a dial that nothing answers, and says once that a connection waits." §0: "the runtime chooses no time of its own and retries nothing." Borrowing the dial's number does not make it the party's time or the host's: the host's accept answers `emfile` and says nothing when a file closes. Fix: either §0 gains the exception in one sentence, or the node stops its listener at the limit and says so, taking connections again only when a program's act closes a file.

**P6. A root module hidden by a nearer one is out of reach, and the diagnostic does not say so (§4.2 Qualified lookup, §11.5).** "The nearer namespace wins where two hold the first segment. The farther is reached from there only by a name whose first segment is found above it ... and one at the root is out of reach." Program `t9`: `util.ern` exporting `g`, `top/shell/util.ern` exporting `f`, and `top/shell.ern` writing `Util.g()`: `top/shell.ern:1:62: unknown name Top.Shell.Util.g`, with no help. Adding `top/shell/util.ern` to a program that compiled takes a root module away from `Top.Shell` with no spelling that brings it back, since the shortest-form rule forbids any other spelling and the root's own name is the one taken. A reader who knows OCaml and SML predicts that a longer path reaches what a shorter one hides. The rule buys `Command.parse` for `Ernest.Shell.Command.parse` inside a tree and a build without `--source-root`; it costs this loss, P7's ban, and a recompile that depends on the tree. Fix, the least: the diagnostic names the hidden module, ```Util` here is `Top.Shell.Util`; the root's `Util` is out of reach from `Top.Shell` ``. The larger question, whether a nearer module may hide a farther that is in use, is the user's.

**P7. A program may hold no file named `map.ern`, `set.ern`, `test.ern`, `process.ern`, `code.ern`, `os.ern`, `string.ern`, `list.ern`, `path.ern`, `io.ern` or `random.ern` at any depth (§4.2 Taken namespaces).** "No segment of a module namespace, at any depth, is a taken one, `Ernest` among them: `fs/entry.ern`, `fides/io.ern` and `fides/ernest.ern` are errors as `io.ern` is." Program `t3`: `app/test.ern` beside `app/main.ern` is refused, `ern build: app/test.ern takes the standard library's namespace Test`. Before the diff only a root module or one under a taken namespace was refused, so `game/map.ern` and `app/test.ern` compiled; the ban exists only so that P6's nearer-wins rule cannot hide the prelude's `Map` from `Game.Player`, a rule that exists for another. Thirty-one names are taken (the count below), several of them the commonest module names a program has. Fix: state the ban's reason beside it in the log and name it in `CHANGES.md` as a change a 0.9.0 program must make; or let a taken first segment resolve at the root always, which keeps `Map.get` one thing and frees the file names.

**P8. `Code.load` and an `atom` can end the node where every other failure of theirs is a value (Appendix E.28, E.12, §11.2).** E.28: "A load that would pass one of the host's limits on what it loads ends the node (§11.2)"; E.12: "An `atom` past that number ends the node, as a load past it does"; §11.2: "A load or an arrival that would pass one of the host's limits on what it loads (above) ends the node at once, as exhausted memory does (§10), with status 1". At v0.9.0 such a load "fails as one the node cannot load (§8.7)". `Code.load` answers `Left` for every other refusal, and §7.4 makes "a limit of the host met" a fault of the process; a reader predicts `Left(Other(text))`, or a fault, not the node's end. An arrival ending the node means a peer's spawn can end it. Fix: state the departure's reason as a rule the reader can predict from, that the host gives no count before it loads, or refuse the load where the count the node reads (§11.2's four fifths) leaves no room.

## Clarity

**P9. The glossary counts ten shape rules; E.0 has eleven (Appendix F).** "**shape rule** — one of the ten rules that give a function of the standard library its shape." E.0: "Eleven *shape rules* give a function its shape." Fix: "one of the eleven rules", or drop the count.

**P10. §11.1 still says a node reads units at its start from its build directory alone (§11.1).** "A node reads its build's units from its build directory at its start alone, and a compiled module after it through `Code.load` (Appendix E.28) or a shell's `:load` (§11.2)." §8.7 and §11.2 now have the node read the shell's definitions from `ern`'s own build at its start too. Fix: "from its build directory and the shell's from `ern`'s at its start".

**P11. Text and octets gain `drop` without `take` (Appendix E.0 rule 2, E.5, E.20).** "Text adds `startsWith`, ..., `slice`, `drop`, ...". A sequence's vocabulary pairs `take` and `drop`; a reader who knows `List.take` beside `List.drop` looks for `String.take` and `Bytes.take`, and finds `slice(s, 0, n)`. Rule 4 admits "the vocabulary whole, whether or not one of its functions composes others". Fix: add `take` to the text vocabulary and to E.5 and E.20, or state in rule 2 why text takes `drop` alone.

**P12. `Process.run` does not say what an unfixed mailbox type of `f` is (Appendix E.21).** `Process.run : (() -> a receiving m) -> Either(Reason, a)`; §6.2 says a spawned function's unfixed `n` is `Never`, and §3.11 says so for a peer's spawn, but E.21 says nothing for `run`, though it is "a monitored spawn at that site". Program `t11` runs `Process.run(fn() = { send(adapted(me, Addr), self()); 0 })` and fixes `m` by the send; the unfixed case has no sentence. Fix: "the process's mailbox type is `f`'s, `Never` where nothing fixed it (§6.2)".

**P13. `fromUtf8Piece` holds back a byte that can begin no character (Appendix E.5).** "They wait wherever a byte's form asks for more than the piece holds, even where no character can follow: `String.fromUtf8Piece(<<245>>)` is `#("", <<245>>)`." Program `t8` confirms it. `0xF5` to `0xFF` begin no UTF-8 character, so a reader who knows Unicode's replacement practice predicts `#("\u{FFFD}", <<>>)`; the rule is the host decoder's, stated as a departure. It costs a reader of a stream a wait of one piece on such a byte. Fix: either keep and say in E.5 that it is the host's decoder's form, or close the difference in Ernest for `0xF5` to `0xFF` and a lead byte whose continuation is already wrong.

**P14. E.1 and E.18 disagree on what `Other(text)` holds for a file the host refuses (Appendix E.1, E.18).** E.1: "where the host writes a term for a file it refuses, it holds the file's name and what is wrong on one line, in Ernest's words"; E.18: "the host gives a file of its own that it could not read as one not found, `Other("{ssl,{\"no such file or directory\",\"ssl.app\"}}")`". The second is a host term promised raw. Fix: `Other("ssl.app: NotFound")`, as E.18 writes `cert.pem: NotFound`, or say in E.1 that a file of the host's own is the exception.

**P15. "Code the host will not load" names no case (§11, §11.1, Appendix E.28).** "A `.erc` whose code the host will not load is no compiled module to a job that loads it", and E.28: "A file whose code alone the host will not load answers its definitions all the same, which its forms give (§11)." Nothing says what the host will not load: a `.beam` of another major release of OTP is the case a reader guesses. Fix: name it once in §11, "a `.erc` whose code was compiled for another major release of OTP".

**P16. §4.2's two sentences on taken namespaces restate each other (§4.2).** "A module namespace may not coincide with a namespace of the prelude or the standard library." is subsumed by the later "No segment of a module namespace, at any depth, is a taken one". Fix: keep the second and the list of what is taken, drop the first.

**P17. §12.1's standard output rule names the hangup where no hangup was sent (§12.1, §11.8).** "Where the stream is a terminal, the program ends by the hangup's signal, whether the write or the hangup comes first (§11.8)." A terminal that can no longer be written is a hangup's case, and the sentence reads as if a write could fail at a terminal with no hangup; what the program does then, and its status, is said only as "by the hangup's signal". Fix: one sentence in §11.8 giving the status, 128 plus `SIGHUP`'s number, as the interrupt's is given, and §12.1 citing it.

**P18. Every node holds the shell's seven units though nothing attaches (§8.7, §11.2 What a node holds).** "A node holds the definitions of the shell of its own build of `ern` from its start, read from that build, by hash in its code table (§8.7), in scope nowhere". `R/build/shell` is 1.2 MB in seven `.erc` files, read by every `ern run --config-dir` and by every `ern test --config-dir`, for the attach that may never come. The rule's reason, that an attach from another release crosses the shell by the exchange and the node must hold the shell of its own build to lack none, is not in the report, and §0's cost sentence is about a program's text. Fix: none in the report if the cost is decided; the log's measure of it belongs beside §11.2's sentence in the runtime's design note, not here.

## Where the language made the work harder

- `t1`, `t6`: a constructor of another module's type is written qualified, `Os.Command`, `Test.Captured`; the diagnostic's help names it, so the cost is one build. The two fields of P1 are the cost that stays.
- `t4`, `t12`: `x |> (a |> f)`, `x |> (f)(a)` and `x |> (adder(2))` each do what §5.7 says, and `1 |> (fn(a) = fn(b) = a + b)(2)` is filled as a chained call, `(fn(a) = ...)(1, 2)`, refused for its arity; Appendix H's "A pipe whose callee is ... a lambda is `{call, ...}`" reads as if the lambda were applied to the value instead. One sentence in H, that the callee is the chained call's head, would settle it.

## Kept for an earlier reason

- Appendix F's "ten rules" (P9).
- §11.1's "at its start alone" (P10).
- §4.2's first taken-namespace sentence (P16).
- E.19 and G.5 stand as `Unused` by the numbering rule, rightly.
- §12.6's count of seventeen frames stands though a spawn's frame lost its "toolchain's own" field: the count is unchanged, rightly.

## Counts, each with how it was taken

- **Reserved words: 18**, §2.4's table read word by word: `type`, `abstract`, `receiving`, `foreign`; `match`, `when`, `receive`, `after`, `as`, `or`; `if`, `then`, `else`; `fn`, `let`; `export`; `true`, `false`.
- **Words read by position: 16**: §2.4's five, `needs`, `derives`, `compare`, `negate`, `show`, and §5.11's eleven specifiers, `size`, `bytes`, `int`, `float`, `utf8`, `utf16`, `utf32`, `big`, `little`, `signed`, `unsigned`.
- **Taken top-level namespaces: 31**, by §4.2: `Prelude`, `Ernest`, the prelude types whose namespace §9 fills that are no standard library module, `Address` and `Reply`, and the 27 standard library namespaces, `Int`, `Float`, `String`, `Char`, `List`, `Bytes`, `Path`, `Optional`, `Either` and `Process` among them. A library's namespace, eleven of them, is not taken.
- **The prelude: 21 types, 18 functions, 22 members.** Types: §9.1's ten, §9.2's three, §9.3's eight. Functions: §9.4's four with `Io.show` and `Io.debug`, which §9 calls the prelude's (16 without them), §9.5's ten, and §9.6's `fault` and `compare`. Members, §9.6's `T.f` lines: `Int.+ - * / %` and `Int.negate` (6), `Float.+ - * /` and `Float.negate` (5), the four `<>`, and seven `compare`s.
- **The standard library: 27 modules, 351 declarations in the listings, 28 types.** Counted by a script over `library.md`'s Appendix E code blocks: a line `Mod.name :` is a declaration (values among them, `Os.arguments`, `Float.pi`, `Map.empty`), a line beginning `type`, `abstract type` or `foreign type` a type. Per module: Io 8/1, List 36, Map 22, Set 20, String 36, Char 12, Bool 1, Int 15, Float 21, Optional 5, Either 8, Foreign 8/1, Random 3/1, Path 10, Clock 8/1, Terminal 3/2, Fs 17/2, Tcp 13/4, Bytes 18, Process 7/3, Supervisor 2/2, Os 15/5, Test 4/3, OrderedSet 22/1, OrderedMap 22/1, Peer 12/1, Code 3. Since v0.9.0: String +5 (`stripPrefix`, `stripSuffix`, `drop`, `fromUtf8Lossy`, `fromUtf8Piece`), Bytes +1 (`drop`), Fs +1 (`makeTempDir`), Process +1 −1 (`run` in, `kill` to the prelude), Os +1 and a type (`signal`, `Signal`), Test +1 and a type (`capture`, `Captured`); `Command` +2 fields, `Status` +1 field; E.0 shape rules 10 to 11.
- **The libraries under `src/libs/`: 11, 62 declarations, 24 types**, by the same script over Appendix G: Ets 10/1, Markdown 4/6, Ansi 7/2, Utilization 5, Json 3/3, Proxy 1, Base64 2, Crypto 2, Time 3/2, Http 22/8, Uri 3/2; `ls R/src/libs` agrees on the eleven. Since v0.9.0: Uri new (3/2), Http +9 (`http11`, `defaultLimits`, `writeRequest`, `writeResponse`, `writeChunk`, `target`, `cookies`, `cookie`, `chunk`) with `ReadError` renamed `SocketError`, Json +1 (`encode`).

```

### K

```text
# Reader K: the report's diff since v0.9.0, and the soundness argument

Read: `S/diffs/report.diff` against `R/report/`, `S/diffs/soundness.diff` and `R/docs/soundness.md` whole, and the sections the diff changed in §3 to §9 with what they cite. Programs were tried under `S/readers/K/` with `R/bin/ern`; every example the diff adds that I ran computed as the report states (`String.fromUtf8Piece`, `fromUtf8Lossy`, `stripPrefix`, `drop`, `Test.equal`'s "differing at", `Float.atan2(0.0, 0.0)`, `Uri.parse`, `Uri.decode`, `Json.encode`, `Http.target`, `Http.cookies`, `Http.chunk`, `Fs.makeTempDir`, the pipe's `x |> (a |> f)`, the outward lookup's `Top.Net.Http.get`).

## Defects

**K1. §7.4 and §12.1 disagree on a terminal request at a full table.** `language.md` §7.4 (line 894): "a full table of the host's that a request of `Fs`, `Tcp`, `Os` or `Terminal` needs room in, is a value with its cause (§12.5)". `toolchain.md` §12.1 **Keys** (line 555): "Where a full table of ports leaves no room to read the keys, at the subscription or at any key after it, the entry process faults with `Fault("the standard input could not be read: system_limit")`", repeated in §12.3 (line 621). A `Terminal.subscribe` is a request of `Terminal`; at a full table of ports it faults the entry process, not the caller, and answers no value, though `Terminal.subscribe` answers `Either(Io.Error, Unit)` and E.16's signature names only `NotATerminal`. §12.5 (line 647) says the same as §7.4 and adds "as at a full table of ports". Fix: §7.4 and §12.5 say "of processes" and except the keys, naming §12.1; or §12.1 answers the subscription `Left(Other("error:system_limit"))` as the other three modules do.

**K2. E.18 states a hang that breaks shape rule 8 and §12.5 for every later `Tcp` request.** `library.md` E.18 (line 677): "At a full table of processes (§12.5) the host's start may end the run, with status 1 ... or never answer, its milliseconds notwithstanding, and hold every later request that reaches TCP's process." Shape rule 8 (E.0, line 218) promises `Left(Timeout)` when the milliseconds pass, and §12.5 (line 647) promises `Left(Other("error:system_limit"))` with the caller living on; E.18 (line 693) excepts "a run's first over TLS". A rule that makes two others unreachable, for every request after it, is a documented defect, not a rule. Fix: start the host's TLS at the run's start, as §12 (line 531) has the run load the toolchain's own Erlang, so that the first `listenTls` or `connectTls` is no exception; or bound the wait so that shape rule 8 holds.

**K3. §4.2's "Declarations are local" names a form the "Qualified lookup" refuses.** `language.md` §4.2 (line 375): "A use site may write a declaration's qualified name: elsewhere for an exported one, and within its own module only where a binding hides the declaration's plain name", with `fn parse` in `net/http.ern` "exported as `Net.Http.parse`" the only qualified name the paragraph shows. Under **Qualified lookup** (line 407) the first segment is looked up from the writer's namespace outward, so within `Net.Http` the shortest resolving form of its own `parse` is `Http.parse`, and `Net.Http.parse` is "written longer" (line 411), an error. Shown: `S/readers/K/q1/src/net/http.ern`, `export fn twice(parse : String) : Optional(Int) = Net.Http.parse(parse)`, refused with `Net.Http.parse is written longer than its shortest resolving form ... help: write Http.parse`; `Http.parse(parse)` compiles. The same holds for a sibling, `Net.Client` writing `Net.Http.parse`. A reader of line 375 guesses the long form. Fix: line 375 says "its shortest resolving form (**Qualified lookup**)", and shows `Http.parse` for the module's own hidden name.

**K4. The glossary counts ten shape rules; E.0 has eleven.** `language.md` Appendix F (line 1488): "**shape rule** — one of the ten rules that give a function of the standard library its shape." `library.md` E.0 (line 182): "Eleven *shape rules* give a function its shape", rule 11 added in this diff. Fix: "one of the eleven rules", or "one of the rules".

**K5. E.23 is silent on an empty `workingDirectory`, and the toolchain's answer names no directory.** `library.md` E.23 (line 820): "The program runs in `workingDirectory`, a relative one resolved against `Os.workingDirectory`", and (line 838) a directory the program cannot be started in answers `Left(Other(text))`, "the directory and what is wrong on one line, `build: NotFound`". Nothing says what `Path("")` is, the natural default a program writes. Shown: `S/readers/K/q4/runos.ern`, `Os.run(Os.Command(... workingDirectory = Path("")), 2000)` answers `Left(Io.Other(": NotFound"))`, a line that names no directory, where `Path(".")` runs in `Os.workingDirectory`. By E.14, `Os.workingDirectory <> Path("")` is `Os.workingDirectory`. Fix: E.23 says an empty `workingDirectory` is `Os.workingDirectory`, or that it is `Left(Invalid)` as a path holding U+0000 is; either way the answer never writes `": NotFound"`.

## The argument

**K6. "So a process reads it only with its value" does not follow during a refused load.** `docs/soundness.md` section 7, *Code that crosses* (line 309): a binding the peer holds without its value is linked to its holder, "which a later spawn's check reads where the code reads it, valued or not (§11.2), so a process reads it only with its value". §11.2 **Loading and reloading** (toolchain.md line 260) has a refused `:load` leave "every binding the load evaluated ... without a value again, in a unit the node held before the load as in one the load brought", while "a process running before the load runs on". A peer's spawn whose reach names such a binding, checked between the binding's evaluation and the refusal, finds it valued, starts, and reads it after the refusal took the value back; E.28's `Code.load` refuses the same way (library.md line 1019). The report says what that read does only for "a binding a faulting reload left without a value" (§7.4, line 910); for a refused load it is silent, and claim 1 (line 11) says a process never "reads a binding that has no value". No program shows it, since it needs two nodes and a load that faults after a spawn's check. Fix: §11.2 and E.28 state what a read of such a binding does, §7.4's cause among the candidates, and the soundness paragraph names the window and the fault it ends in.

**K7. The argument's `Code.running` paragraph rests on a hash E.28 gives no function that receives nothing.** `docs/soundness.md` line 291 lists "a definition of `f`'s name ... whose mailbox type has `m`'s hash, of whichever version", and E.28 (library.md line 1025) "a definition of `f`'s qualified name whose mailbox type is `f`'s, by the type's hash". For an `f` that receives nothing or is process-only, `m` is `Never` (line 1029) and the definition has no mailbox type to hash, so which earlier versions of `f`'s name are listed is unstated: one that received nothing, one process-only, one receiving a type. The argument's next paragraph (line 293) holds whatever is listed, since the addresses are `Address(Never)`; the report, not the argument, leaves the builder to guess. Fix: E.28 says which definitions of `f`'s name count where `f` names no mailbox type.

## What a later rule left behind

**K8. Every node holds the shell's units from its start, though the shell now crosses by the exchange.** `toolchain.md` §11.2 **The attached shell** (line 340): "A node holds the definitions of the shell of its own build of `ern` from its start, read from that build, by hash in its code table (§8.7), in scope nowhere", and in the same paragraph "The shell's definitions ... cross to the node as any program's do, by the exchange (§8.7, §12.7), a node of the shell's build lacking none of them"; **What a node holds** (line 316) and §8.7 (language.md line 1014) say the same. The read at start existed for the rule this diff removed, §12.7's *The toolchain's own units*, under which nothing of the toolchain's crossed. Now that the exchange carries them, the read at start spares one exchange at an attach of the same build, and costs every `ern run --config-dir` and every bare node the shell's units in memory and in the host's counts of module names, exports, functions and atoms (§10, line 34), which never fall. Fix: a node reads nothing of the shell's at its start; an attach sends the shell's reach as any spawn does, and `--verbose` (line 146) loses "and the shell's".

## Clarity: where a builder guesses, and where the rules are silent

**K9. §6.9's restart wait on a wrap the runtime has no room to apply.** `language.md` §6.9 (line 815): the restarting process "waits until each service monitor's `wrap` has placed its message"; §7.4 (line 906): a delivery through a wrap the runtime has no room to make "faults the process it is for ... at its next wait". Whether the restart waits for such a delivery, which places nothing, is unstated. Fix: §6.9 says the restart waits for it no longer, as §8.6 (line 972) says of the end.

**K10. "Ends by the hangup's signal" gives no status where SIGPIPE's and SIGINT's are given.** `toolchain.md` §11.8 (line 521) gives 141 for a stream and 130 for the interrupt, and (line 523) "A job whose keys the host can no longer read, or whose terminal can no longer be written, ends by the hangup's signal, on a node as elsewhere (§12.1)"; §12.1 (lines 539, 555) says the same. A node takes a hangup as a reload (§8.6 line 978), so a builder guesses whether the job raises `SIGHUP` on itself with the handler reset, so that a shell reports 129, or exits with 129. Fix: say it as the SIGPIPE sentence does, "with status 129, 128 plus the number of `SIGHUP`", or that the job ends itself by the signal.

**K11. "Its message" against "what it logs as it ends the job".** `toolchain.md` §11 (line 68): the host's "what it logs as it ends the job (§11.8)" is not written; §11.2 (line 320) writes "The host's message ... `no more index entries in atom_tab (max=1048576)`", and §11.8 (line 521) "writing nothing of the host's but its message". Which of the lines the host prints at a crash is "its message" and which is "what it logs" is a guess for one who builds the runtime. Fix: §11 names the one line that is written, the host's reason line, and says the rest is what is not.

**K12. §8.7 and §12.5 each cite the other for the patch-release rule.** `language.md` §8.7 (line 1006): "A patch release changes no type of the standard library's, no foreign declaration's type, no form's version (Appendix H) and no version of the protocol (§12.5)"; `toolchain.md` §12.5 (line 677): "A patch release changes none of these (§8.7)". Neither owns it. Fix: one states it and the other cites it.

**K13. §11.5 prints a type name "whole" and "unqualified" in one sentence.** `toolchain.md` §11.5 (line 1054): "A type name is printed whole, as §4.2 prints a name in a diagnostic: the module's own types and the prelude's unqualified, and other modules' by their whole name"; `language.md` §4.2 (line 411): "A diagnostic, a trace, a site, `ern doc` and the shell print a name whole." Whole means not shortened to the resolving form, but the sentence reads against itself. Fix: §4.2 says "whole, the module's own and the prelude's plain", and §11.5 cites it.

**K14. "Where `Command.parse` resolves" should say "resolves to it", and the root's order is stated elsewhere.** `language.md` §4.2 (line 411): "a name written longer, `Ernest.Shell.Command.parse` where `Command.parse` resolves, is an error". Where the shorter form resolves to another declaration, a nearer `Command`, the longer form is the shortest resolving form of its declaration and no error; the sentence should say so. And (line 407) at the root "the modules of the source root and of each load path root, the prelude's namespaces, the standard library's and the toolchain's libraries' stand", where two may hold the first segment at one distance, a program's `json.ern` and the library `Json`; the tie is decided by the load path's order, said under **Taken namespaces** (line 385) and §11.2 (line 142) and not here. Fix: "where `Command.parse` resolves to it", and "at the root, in the load path's order (§11.2)".

**K15. A root module a nearer namespace shadows is reachable by no name.** `language.md` §4.2 (line 407): "one at the root is out of reach". From `Top.Shell`, the root's `Util` cannot be named once `top/util.ern` or `top/shell/util.ern` exists, and adding either file rebinds `Util.x` in `Top.Shell` with a recompilation (§11.1 line 103) and no diagnostic. The rule is stated; a reader from Rust or Go, where a crate or module path is absolute, expects a form that reaches the root, and principle 1 may ask for a diagnostic where a new file changes what a written name means. Fix, if any: a design decision, in the log; the report is consistent as it stands.

**K16. E.24's "as `Process.run` runs a function" needs its exception beside it.** `library.md` E.24 (line 873): `Test.faults` "runs `run` as `Process.run` runs a function"; E.21 (line 760): in `Process.run` "A fault in `f` is the process's own, reported as any fault is (§7.3, §11.2)"; E.24 then says `Test.faults`'s process "is marked as the runtime starts it, and its fault reaches no job's report". Shown: `S/readers/K/q3/run.ern`, `Process.run(fn() = fault("boom"))` writes `Run.main:4 faulted: boom` on standard error and answers `Left(Fault("boom"))`; `Test.faults(fn() = fault("boom"), "boom")` writes nothing. Both as stated; the "as" misleads for one sentence. Fix: "as `Process.run` runs one, but marked".

## Where the language made the work harder

Little Ernest was written. Two refusals cost a retry, each by a stated rule: `Io.debug(Process.run(fn() = 5))` is refused since `Either(Reason, a)` is not known whole (§3.9), so every probe of `Process.run` carries an annotation; and a probe file named `os.ern` at the root is refused as the standard library's namespace (§4.2). Neither is a finding.

```

### N

```text
# Reader N: the newcomer, from the README through the guide, the argument and the questions, to a program

Read at commit 7e7cdee1: `README.md`, then `guide/language.md` alone with its exercises run against `bin/ern`, then `guide/why.md` and `guide/faq.md`. Every exercise's answer matched §12. The program is an expiring cache, under `S/readers/N/expiring/`, described at the end.

Defects stand first, then matters of clarity. The two lists the brief asks for apart, what the language made harder and the names I could not predict, follow the findings.

## Defects

**N1.** `guide/language.md:3174` and `guide/deployment.md:331`: "`Counter.main:59` for the counter `examples/upgrade`'s tool spawns". The spawn is on line 60: `grep -n 'spawn(fn() = count(0))' examples/upgrade/v2/counter.ern` gives `60:`. A site is the spawn's line, as `Cache.start:17` and `P6.waits:2` showed for my own files, so the number the guide and the deployment guide quote, four times, is stale by one. Fix: write `Counter.main:60` and `Counter$2.main:60` in both files, and hold the number with a test, or quote the site without its line.

**N2.** `guide/language.md:2585`: "Work spread over the peers at once is §4.4's `gathered` with a compute as the work: a process for each piece, which computes and sends its piece home, spawned monitored so that its fault comes home too (§6.4)". `gathered` spawns nothing monitored: its helper runs the piece under `Process.run` (line 1042) and sends `Ran(n, Left(reason))` where it faulted, and §6.4 uses `Process.run` too, not `spawnMonitored`. Fix: "each helper runs its piece under `Process.run`, so a fault comes home as a `Left` (§5.2)".

**N3.** `README.md:33` against `README.md:108`: "Two configuration directories make the pair, four `ern config` commands of the kind the tour shows", then "Two nodes on one machine take four more commands: `ern config --config-dir` ..., `ern config --peer-dir` ..., `ern run --config-dir` ..., and `ern stop --config-dir`". Two different fours: the first is the guide's §8.1, four `ern config` lines; the second counts two `ern config` commands with a run and a stop. A reader who takes the README at its word expects four `ern config` commands at line 108 and finds two. Fix: line 33 "four `ern config` lines, two for each directory, which §8.1 of the guide shows"; line 108 "four more commands: two `ern config` ... and `ern run --config-dir` and `ern stop --config-dir`".

## Clarity

**N4.** `README.md:40-45`: `Peer.spawn("foo", fn() = Counter.count(0), 5000)` and `Address.call(far, Counter.Get, 1000)`: two counts with nothing that says what they count, and `let far <-` relied on before any word says what `<-` does. The README is the first page a stranger reads, and these are its first numbers. Fix: one sentence after the session, "the last argument of each is a deadline in milliseconds, and `let far <-` binds what the spawn's `Right` holds".

**N5.** `guide/language.md:185-194`: `Os.run(Os.Command(...), 5000)`. Line 185 says what `Os.run` answers and nothing of its last argument; the rule that a function that waits takes its milliseconds last is §2.9's (line 627), five pages on. §0 explained `Fs.write`'s `1000` in its own sentence (line 73); this one is a count without what it counts. Fix: at line 185, "and answers, within its milliseconds, its exit status and what it wrote".

**N6.** `guide/language.md:1788`: the trace `Process.run:259`. The frame names a line of `src/stdlib/process.ern`, which line 2402 says "an installation does not ship", so the reader of the installed guide is given a number that leads nowhere, and §6.3's account of a trace (line 1747) says nothing of a library frame. Fix: in §6.3, one sentence: "a frame of the standard library names its line in the library's source, which the repository holds and an installation does not", or print a library frame without its line.

**N7.** `guide/language.md:743`: "`let shared = spawn(fn() = cell(None))`, an address, is not". `spawn` is taught in §4.1 and `cell` is defined nowhere; the sentence is in §3.3, where a reader has met neither. Fix: "`let shared = spawn(...)`, an address (§4.1), is not", with no `cell`.

**N8.** `guide/language.md:858`: "`fn stop() = kill(Process.fromAddress(self()))` is a `() -> Unit`". `kill` is §5.3's and `Process.fromAddress` §5.5's, and the sentence names neither section, where every other forward use in §4.1 does. Fix: add "(§5.3, §5.5)".

**N9.** `guide/language.md:2769-2778`: `board.ern` calls `Proxy.start(Counter.service, 5000)`, and the first word of what a proxy is comes at line 2853, eighty lines on, with nothing at the code that points there. Between them the reader runs `desk.erc` and the store and wonders what `board` was for. Fix: one line before `board.ern`: "`board.ern` reaches the store through a proxy, *A service that comes back*, below".

**N10.** `guide/language.md:956`, `1751` and `1848`: the rule that a `callForever` caller's fault line names the callee's spawn site after the cause, `, the fault of the callee ...`, is stated whole three times, in §4.4, §6.3 and §6.5. Fix: state it once, in §6.3, and cite it from the other two.

**N11.** `guide/language.md:3328-3336`, *Reading further*, lists the examples, the projects, the report and `docs/log/` "why Ernest looks as it does", and not `why.md` or `faq.md`, though §0 (line 93) and §11 send the reader to `why.md` for the argument; §10's last bullet (line 3276) names the log for reasons too. A reader finishing the guide is sent past the argument written for them to a dated record. Fix: §13 names `why.md` and `faq.md` first, and the log as the dated record behind them.

**N12.** `README.md:15`: "It takes Unison's code known by the hash of its definition, Gleam's kind of types and Erlang's processes, and adds what none of them has." The claim opens on what the three lack, and what Ernest does follows in the next three sentences. Fix: state the three additions first, then "which none of the three has".

**N13.** `guide/language.md:161`: "`Os.arguments`, a list of strings". Nothing says it is a binding and not a function, and the library has both shapes under one kind of name, `Os.arguments`, `Os.user`, `Os.workingDirectory` and `Map.empty` without parentheses beside `Clock.now()`, `Process.live()`, `Process.current()` and `Peer.peers()` with them. My first write was `Os.arguments()`, refused with `Os.arguments is not a function; it has type List(String)`, a clear message for an avoidable stumble. Fix: at line 161, "a binding, not a function, as `Os.workingDirectory` is"; and `guide/style.md` or Appendix E.0 states which names are bindings, if a rule exists.

**N14.** `README.md:71`: "The questions a Gleam or Erlang programmer asks first are answered here", where `guide/README.md`'s row for `faq.md` says "from Gleam, from Erlang or from Unison" and the FAQ has a Unison question. Fix: "a Gleam, Erlang or Unison programmer".

**N15.** `guide/language.md:2402`: "the rest of the module is in that file of the repository, which an installation does not ship, and `:doc OrderedSet` lists it". `:doc OrderedSet` lists the module's documentation, not its source; "lists it" reads as if the source were shown. Fix: "and `:doc OrderedSet` shows its documentation".

### Kept for an earlier reason

I found nothing in my four files that a later rule plainly removed. The one candidate is N11: `guide/language.md`'s §10 and §13 send the reader to `docs/log/` for the reasons, a pointer that reads as written before `why.md` existed, since §0 and §11, written with it, point at `why.md`.

## Apart: where the language, not the guide, made the program harder than expected

**L1.** A function whose result only reports, and whose call is wanted for its effect, costs a `let _ = ...; Unit` at every site that does not care: `Clock.cancel` answers `Bool` and `Clock.alarm` a `Clock.Alarm`. My `cancel` helper is six lines around one call (`cache.ern:57-63`), and `main.ern` drops an alarm the same way; the guide's own code does it at lines 1557, 1568, 3082-3083 and 3088-3089. The rule is principle 3's and I would keep it, but the count is what it costs.

**L2.** `Bool` has no `compare` (line 460), so `List.sort([true, false])` is refused, `sort needs Bool.compare, and Bool has no compare`, and so is `derives compare` on a record with a `Bool` field (line 2234). Every ML orders `Bool`, `false` before `true`; a reader from one expects it, and a record of flags cannot be sorted or kept in an `OrderedSet` without a wrapper type.

**L3.** A constructor takes one positional field or named fields: `type Point = Point(Int, Int)` is refused. The help is good, `name the fields, or hold a tuple`, but it is the first thing a reader from any ML writes.

**L4.** A name must be written in its shortest resolving form: `Shop.Order.parse` inside `shop/cart.ern` is refused, `written longer than its shortest resolving form`. A function moved from one directory to another has every reference to its siblings rewritten, and a reader cannot write the whole name to be clear.

**L5.** `Peer.offer` answers `Either(Process, Unit)`: a `Left` that is the holder, not a failure. Under §2.9's rule, "one with a cause returns `Either`", a `Left` is read as a cause, and here it is a process to monitor. Met in the guide's store, not in my program.

## Apart: names of the prelude and the library whose word I could not have predicted, with the word I expected

- `adapted(target, wrap)`: expected `Address.adapt` or `adapt`. A past participle among the prelude's imperatives, `spawn`, `send`, `answer`, `kill`, `monitor`.
- `restarting(limit, f)`: expected `restart` or `restartable`. The same shape; if the rule is that a participle answers a value and an imperative acts, nothing says so.
- `Os.termination(wrap)`: expected `Os.onTermination` or `Os.subscribe`. Three deliveries, three shapes: `Terminal.subscribe(wrap)`, `Process.faults(wrap)`, `Os.termination(wrap)`.
- `Address.call` beside a bare `send`: expected `call` in the prelude, as `send` and `spawn` are, since every process program makes the three.
- `Process.run(f)`: expected `Process.await` or `Process.runAndWait`; "run" does not say that it waits for the process's end and answers `Either(Reason, a)`.
- `Test.until(run, ms)`: expected `Test.eventually`; "until" reads as "until what?" before the documentation says "until it passes".
- `Tcp.give` and `Os.give`: expected `transfer` or `handOver`; guessable once read.
- `Os.arguments`, `Os.user`, `Os.workingDirectory`, `Map.empty` as bindings against `Clock.now()`, `Process.live()`, `Peer.peers()` as functions: the word does not tell which (N13).
- `Io.show`: expected `toString` or `Io.display`; Haskell's word, learned at once.
- `List.dropLast`, `List.takeLast`: expected `dropRight`, `takeRight`.
- `String.size`, `List.size`: expected `length`; the rule is stated and holds.

## The program

`S/readers/N/expiring/`: `cache.ern` (82 lines) and `main.ern` (18 lines), 100 lines in all. An expiring cache: a process holding `String` entries, each put with a time to live, expired by a `Clock.alarm` whose message carries the put's stamp so that a stale alarm after a renewal is dropped; `get`, `size`, three tests with `Test.Case`, one of them `Test.until`, and a `main` in a second module that reads two entries before and after the short-lived one expires.

- Built: yes, `ern build --build-root build .`, 0.36 s, at the first attempt.
- Tests: yes, `ern test build`, three of three passed.
- Ran: yes, `ern run build/main.erc` printed `2 held, token Some("xyz"), user Some("ada")` then `1 held, token None, user Some("ada")`.
- `ern format --check .` names both files: the formatter breaks `| None -> Unit` onto two lines where another clause of the `match` is a block, and one `<>` per line in a long chain. The guide's code follows that layout; nothing in the guide states it, and §9.1 points at report §11.6.

Exercises run under `S/readers/N/ex/`, every one matching §12. No process of mine is left running.

```

### L

```text
# Reader L: the Erlang veteran in a hurry

Read in order: README.md, guide/why.md, tour/README.md with tour/1 to tour/8, guide/faq.md, guide/language.md (all but §11), guide/deployment.md §1 and §4 to §8, at 7e7cdee1. Every program and console of the README, why.md and the tour was run with R/bin/ern in S/readers/L/: the tour's chapters 2 to 8 ran whole, two bare nodes, a shell and an attached shell, in 8 seconds (S/readers/L/tour_run.sh, output in tour_run.out), and every line matched the page but the machine's own numbers (24 schedulers, utilizations). why.md's eight programs and three refusals matched to the character.

**Defects: none.** No console, program, error text or exit status in my area differs from what the documents show. Everything below is clarity, then what is kept twice, then the persona's report.

## Clarity

- **L1.** guide/why.md:16 and :293, guide/language.md §5.4:1435. "any library of the host's, a package from hex among them, is reached through declarations" (16) and, 277 lines later, "The one false deadlock is a delivery that foreign code arranges for after its call has returned, a host timer's or that of a host process nothing monitors" (293). The two sentences collide for the reader they are written for: an Erlang veteran's hex library answers through `erlang:send_after` and gen_server timers, so under `ern run` and `ern test` a program that waits on it alone faults. Shown by S/readers/L/probes/timer.ern, a `foreign fn` over `erlang:send_after/3` then a `receive`: `Timer.main faulted: deadlock`, exit 1. The fact is stated, but only inside the deadlock claim; the foreign-code paragraph (why.md:167-176) and faq.md's "How does Ernest talk to Erlang" (75-81) say nothing of it. Fix: one sentence in each, "a delivery a host timer or an unmonitored host process arranges after the call has returned is unseen, and `ern run` and `ern test` fault a program that waits for it alone".

- **L2.** guide/why.md §"A distribution built for a WAN":178-205. The first question this reader asks of the section, "is this Erlang distribution underneath, with epmd and a cookie, or a protocol of your own?", is not answered there; its one hint is "as the host's distribution finds a silence" (203). The answer stands in faq.md:85-87 ("Nodes talk over Erlang's own distribution ... one port per node ... no port mapper ... the cookie ... is the digest of the floor") and guide §10:3276. Confirmed: `ps` on a node shows `-setcookie <64 hex digits>`. Fix: that faq sentence, or a pointer to it, at the head of the WAN claim.

- **L3.** guide/why.md:379 against :418, faq.md:105 against :107, guide/language.md:2205 against :2236. The compiler says "`hash` is not a member: a requirement names `+`, ..., `compare`, `negate` or `show`", and three documents say "`show` is no member" or "`show`, which is no member". A reader who met the message holds `show` for a member; the documents say the opposite. Shown by `fn hashed(x : a) : Int needs a.hash = 0` at the prompt. Fix: the message reads "`hash` is not what a requirement names: ...", or the documents say "which no type declares" in place of "no member".

- **L4.** guide/why.md:37-39. "the less busy of two peers drawn at random from those that have told the node how busy they are ... A peer tells the node as it connects" and then "the one that last reported itself less busy". Nothing in why.md says a peer tells again, so the reader asks how stale a telling may be; the answer, every `utilization-interval` milliseconds and 5000 by default, is the tour's chapter 7 (528-530) and guide §8.1:2563. Fix: "as it connects and every five seconds after, `utilization-interval`".

- **L5.** README.md:33-46. "On a second node, `foo`, which holds none of the counter's code, `Peer.spawn` starts `count` ... Two configuration directories make the pair, four `ern config` commands". That `foo` must be running, `ern run --config-dir foo` in a terminal of its own, is said nowhere on the page; a reader who makes the two directories and types the console gets `Left(Io.Unreachable)` (S/readers/L/probes/n/unreach.ern: `left: Io.Unreachable`, in 0.66 s). Fix: "with `foo` started in a terminal of its own by `ern run --config-dir foo`" after "four `ern config` commands".

- **L6.** guide/deployment.md §1.5:118-130, the systemd unit. `ern` is a shell script that stops with "erl, of Erlang/OTP 29, is not on the path" (R/bin/ern:51-52), and the unit sets no `Environment=PATH=`. Under systemd's default path an OTP under `/usr/local` is found and one from kerl, which README.md:104 names as a way to install it, is not. Fix: one line under the unit, "where OTP is not under `/usr/local`, `Environment=PATH=...` names its `bin`".

- **L7.** guide/language.md §8.1:2537, "beneath it the trace that crossed with it, followed by the caller's frame where the compute is written". Run, the two read as one frame printed twice: `Cf.main faulted: division by zero, on the peer foo` / `erlang:'div'/2` / `Cf.main:2` / `Cf.main:2` (S/readers/L/probes/n/cf.ern). Nothing in the output marks where the peer's trace ends. Fix: the sentence says the last two frames may read alike, the lambda's on the peer and the caller's here.

- **L8.** tour/README.md:530. "`bar` reads 0.25 with no work of yours: its first telling came as the connection opened, with the processes that opened it counted as running, and its next, five seconds later, reads it idle." An explanation of one run's number, after the fact, and the one sentence of the tour I suspected: in my run `bar` read 0.0417 at 102 ms and `foo` 0.0833 at 1790 ms, on 24 schedulers. Fix: "the numbers are one run's, and the first telling, made as the connection opened, counts the processes that opened it".

- **L9.** guide/why.md:66, `Upgrade(=next) -> next(total)`. The pun `=next` stands in the first program of the why, two documents before guide §2.4 explains it; this reader took it for a typo. Fix: "`=next`, a field bound to a variable of its own name" in the sentence under the block, or `Upgrade(next = next)`.

- **L10.** guide/language.md §4.1:858. "A function that calls `self` and keeps the address to itself receives nothing: `fn stop() = kill(Process.fromAddress(self()))` is a `() -> Unit`." True (`:type stop` gives `() -> Unit`), and tripped on: `self : () -> Address(m) receiving m` was shown two lines above, and the guide gives no clause for why the `m` does not reach `stop`. Fix: "since the `m` of `self` reaches no type of `stop`'s".

- **L11.** guide/language.md §2.8:610. "Parentheses around a call change nothing, so `x |> (f(a))` is `f(x, a)` too." True (`5 |> (adder(3))` is refused with "adder takes 1 argument, not 2"), and the opposite of what a Gleam reader expects; the sentence after it, a pipe in parentheses being a value, makes the rule hard to hold. No fix beyond the sentence; noted as a trip.

- **L12.** guide/faq.md:29 and guide/language.md §6.6:1951. "A sibling that never waits is never restarted." A sentence this reader did not believe makes `OneForAll` usable for a child in a long computation; the guide states the consequence ("a sibling busy in a long computation keeps it down"). Argued nowhere; no fix proposed.

- **L13.** guide/language.md §5.2:1379, §10:3265. "A `Down` comes from the runtime and not from the process that ended, so the report gives it no order with that process's own messages ... where Erlang's `'DOWN'` comes after it", and the test idiom is `Test.until`, a poll (1414). Stated plainly; noted under *restates less* below. No fix proposed.

## Kept twice

No copy, helper, check or rule in my area could be dated to an earlier milestone's reason; what follows is what stands in two or more places, each with what holds it.

- **L14.** The tour's chapter 2 session stands three times: README.md:36-46, guide/language.md §1.4:236-246 and tour/README.md:123-135, all added 2026-10-23 with the tour. test/ern_tour_tests.erl runs the README's console and test/ern_docs_tests.erl holds the README's program to tour/2/counter.ern; I found no test that holds the guide's §1.4 copy to either.

- **L15.** The `other.ern` refusal, README.md:52-60 and guide/why.md:157-165, one console twice; test/ern_guide_tests.erl holds the why's.

- **L16.** The closed-set paragraph, guide/why.md:418 and guide/faq.md:109, one argument twice, the faq's pointing at the why's and restating it.

- **L17.** The rule that a prompt's `let` is the session node's and a peer answers `Left(Io.NotLoaded)` with `the binding $Session1.below has no value here`, stated in tour/README.md:532, guide/language.md §8.1:2547, §9.3:3212 and guide/deployment.md §4.3:246.

## The persona's report

**Where I would close the page.** faq.md:21 and :113: "`sys`, its suspend, its state read from outside and its trace, has nothing in its place" and "there is no tracing and no `observer`". An operator of years reads that as the end of the page, and the attached shell with `:processes` and `Process.status` (deployment §6) is what the page offers in its place. Second, guide/why.md:75 with faq.md:21: a process under `restarting` "is back on its old loop at its next fault", where an Erlang supervisor restarts into the module as loaded; the operator's answer, deployment §5.3, is a second service beside the old.

**The first question each document does not answer.** README: how `foo` got started (L5). why.md: whether this is Erlang distribution underneath (L2), and in the mailbox claim, what happens past three restarts in five seconds (answered in faq.md:25 and guide §6.5:1846). The tour: none; it answers each as it goes. faq.md: none. The guide: why an address has no equality where a pid has, asked at §2.5:458 and answered at §5.5:1531.

**What Erlang cannot do, shown.** A function refused before the run for the mailbox it would read, `count needs mailbox CounterMsg, and the mailbox here is OtherMsg`, with no address in sight (README, why.md:157, tour chapter 1). A process started on a node that holds none of its code, with no `nl`, no code path and no release there (tour chapter 2, and the attached shell of chapter 8 moving a fix on it). A send to a process of a previous version refused with the version named, `Counter$3.CounterMsg` (tour chapter 5). A deadlock ended with a trace naming every waiting process by its spawn site (why.md:230-235, tour chapter 5's test). A find that compares the protocol's hash and answers `Io.OtherType` rather than deliver a wrong shape (guide §8.2). Two nodes that trust each other by a listed key, with no shared secret and no port mapper (tour chapter 2).

**What only restates what I have.** `receive` with selective match and `after`, per-sender order, `monitor`, `kill`; `restarting` with `RestartLimit` is `max_restarts` and `max_seconds`; `Supervisor`'s three strategies; `Address.call` is `gen_server:call` with a timeout; TLS distribution with peer verification is `inet_tls_dist` with `verify_peer`; `ern reload` is a hangup that rereads a file; `Os.termination` is `terminate/2` at shutdown; §4.2's atom and module tables are the host's I know.

**Where it gives less than Erlang.** No links and no exit signals (faq.md:33). A `Down` with no order against the dead process's messages (L13). No `sys`, no trace, no `observer` (faq.md:21, 113). A restart under `restarting` reverts an upgrade (why.md:75). No purge: a node reloaded without end grows (why.md:77, deployment §4.2). The 45-to-75-second silence window with "no setting shortens the window" (why.md:203), where `net_ticktime` is mine to set. A supervisor's child is killed, never asked (faq.md:27). No `global`, no `pg` (faq.md:115).

**Sentences suspected of a trick.** None held up: every console in my area ran as printed. Two arrangements the documents themselves name: the tour's chapter 6 spawns both counters plain "with no `restarting` around them" (470) so that chapter 8's move is not undone by a fault, and the README's `foo` is running before the page begins (L5). The one explained number is L8.

**What convinced me.** The tour: chapters 2 to 8 ran to the line on my machine in 8 seconds, two bare nodes, a shell that is a node, a fix reaching a counter on a node that never held the program, from a shell attached to it, and the node's end told to every shell. The compiler's three refusals at the right place: the mailbox, the previous version, and `Peer.spawn` of a type that holds a function. `ern build .` in 0.3 s and `ern test` naming the planted deadlock with both processes.

**Would I try it.** Yes, for a new system of a few nodes I own, written from the start in it, and for the typed mailbox alone. Not yet for a system I must trace in production, or one whose host libraries answer through their own timers under `ern test` (L1).

Processes started: two bare nodes, two shells and one node in probes, all ended by `ern stop` or `:quit` and waited on by process number; none left running. Nothing in either repository was edited.

```

### M

```text
# Reader M: the Gleam programmer, before 0.10.0

Read at 7e7cdee1: README.md, guide/why.md, tour/README.md with tour/1 to tour/8, guide/faq.md, guide/language.md (every chapter but 11), guide/deployment.md §1 and §4 to §8. Every program of Why Ernest, the tour's chapters 1, 5, 6 and 8 at the shell and under `ern test`, and the guide's §4 to §6 programs were run with R/bin/ern in S/readers/M/; each printed what its page shows. The Gleam lines were checked against gleam_erlang v1.3.0's `gleam/erlang/process` page as it stands today.

## Defects

**M1. tour/README.md, four claim numbers are the old order's.** Why Ernest reordered its six claims since v0.9.0 (code travels is now the first, the mailbox the second, the deadlock the fourth, abstract types the fifth); the tour was renumbered in four places and not in four others. Line 143: "That is the second claim of *Why Ernest*: a process started on another node brings its code along" (the first). Line 331: "That is the fourth claim of *Why Ernest*. A generic function names the operations it needs" (the fifth). Line 347: "that is the fifth claim of *Why Ernest*, a program in which every process waits ... is a deadlock, found" (the fourth). Line 468: "`Tally` ... crossed with the compute, as `count` did with the spawn in chapter 2, the second claim once more" (the first). Shown by `git -C R diff v0.9.0 7e7cdee1 -- guide/why.md tour/README.md`. Fix: second→first at 143, fourth→fifth at 331, fifth→fourth at 347, second→first at 468; or name each claim by its title, which no reorder breaks.

**M2. tour/README.md line 72, a Gleam call that is not Gleam's.** "since `process.receive(subject)` compiles wherever a subject is in hand". In gleam_erlang v1.3.0 `receive` is `receive(from subject: Subject(message), within timeout: Int)`; the one-argument wait is `receive_forever(subject)`. README line 50 and why.md line 141 write `process.receive(subject, 1000)`, which is Gleam's. Fix: write the two-argument form here too.

## Clarity

**M3. README.md line 50 and guide/why.md line 141, the Gleam page says it both ways.** "`process.receive(subject, 1000)` compiles wherever a subject is in hand, and panics at run time in a process that does not own it." The v1.3.0 page's Panics section agrees, "This function will panic if a process tries to receive with a non-named subject that it does not own", but the same function's body says "If a process that does not own the Subject attempts to receive with it then it will not receive a message", and a named subject (`named_subject`, new in 1.x) is excepted. A Gleam reader who checks finds the page contradicting itself and the sentence true of the ordinary subject only. Fix: "a subject it did not make" in place of "a subject", so that the sentence is the one the page's Panics section states.

**M4. guide/language.md line 960, a callee that "was closed".** The list of how a callee ended reads "it was killed; it returned without answering; it was closed; it was restarted ...". Nothing before this says what closing a process is; I read on to §8.7 to guess a socket's. Fix: name the kind of process that closes, "it was closed, a socket's or a listener's process", or drop the line here.

**M5. guide/language.md line 858, an example stands where its rule should.** "A function that calls `self` and keeps the address to itself receives nothing: `fn stop() = kill(Process.fromAddress(self()))` is a `() -> Unit`." The sentence before it says that answering the process's own address, "as `self` does", involves the mailbox, so the example contradicts the rule as the page states it. The shell confirms `stop : () -> Unit`; the rule that makes it so, an effect variable that stands nowhere else in the type is none, is not written. Fix: one sentence stating that rule before the example.

**M6. guide/language.md line 2236, why.md line 418, faq.md line 107: `needs a.show`, which I did not believe.** "`show` is no member a type declares: every type can be shown. `Io.show` writes a value by its type, which a function generic in `a` does not know, so the function declares `needs a.show`." In Gleam `string.inspect(x)` takes any `x` with nothing declared, and the page does not say what the type gives `show` that the value in hand does not, when `Io.debug` prints that same value as its construction. Three documents state the rule and none says where the type is needed. Fix: one clause naming what `Io.show` reads from the type and cannot from the value, with the report section that owns it.

**M7. guide/faq.md, "It looks like Gleam", the mapping a Gleam reader needs most is missing.** The answer maps `Subject` to the address, `process.call` to `Address.call` and the opaque type to the abstract type, and not the types a Gleam program is made of: `Result(value, error)` is `Either(e, a)` with the parameters the other way round (`Either.fromOptional : (Optional(a), e) -> Either(e, a)`), `Option` is `Optional`, `Nil` is `Unit`, `Pid` is `Process`. The reversed `Result` is the one a Gleam reader writes wrong on the first day. Fix: one line in the answer giving the four names, the order of `Either`'s parameters said.

**M8. guide/why.md line 141 and faq.md line 9: the gain over a `Subject` that a Gleam reader feels most is asserted in one sentence and shown against nothing.** "`spawn` takes the address's type from the function, `spawn(fn() = count(0))` being an `Address(CounterMsg)` and nothing else". What this removes in Gleam is the handshake: `process.spawn` answers a `Pid`, so the child makes a `new_subject()` and sends it back to its parent before anyone can send to it, or the program reaches for the actor package. The tour's chapter 1 shows the Ernest side in one line, `counter : Address(Counter.CounterMsg)`, and no document names the handshake it stands in for; the refusal of `count` in the wrong mailbox is argued at length instead. Fix: one sentence in why.md's mailbox section naming what a Gleam spawn must do to get a typed address back.

**M9. guide/why.md lines 33 to 39 and 75 to 77, an argument that becomes a manual.** The code-travels claim's program is five lines, and around it stand `Left(Io.NotLoaded)` with what the peer says, `Left(Io.Unreachable)` before any peer has told its utilization, the draw of two among three peers or more and what it does with two, `, on the peer foo` in the fault's line, and that `restarting` runs the old loop after a move and that versions are never purged. Each is a rule of the guide's §8.1 or §9.3, which the sentences cite. Too long for what it shows: the claim is made by line 33's first sentence and the tour's chapter 2. Fix: keep the claim, its program and the shell session; leave the operational sentences to the guide, which already holds them.

**M10. guide/language.md lines 2402 to 2444, forty lines of library source for one sentence.** "For the curious: how `OrderedSet` is written" quotes `fromList`, `firstOfEach`, `contains`, `has` and `map` to show that helpers generic in the element declare the requirement too, which the paragraph after it states in one sentence. Fix: keep `fromList` and `map`, eight lines, and the paragraph.

**M11. guide/language.md line 1788, a frame into a file the reader cannot open.** The trace shows `Process.run:259`, a line of the standard library's source, which §7.3 says "an installation does not ship"; the number will move with the library, and the guide's test will hold the page to it. Fix: say in the sentence under it that the line is the library's own, which a reader does not follow.

**M12. guide/why.md line 299 and 418, faq.md lines 105 to 109: "None of them is a type class", where it convinces and where it only asserts.** What convinces is what the closed set rules out: no class declared, no instance, no functor or monad built on one, a member declared in its type's own module alone, with the refusals of `a.hash` and `fn String.negate` shown at the prompt. What is asserted and not argued is the mechanism, which a Gleam reader knows from the discussions that kept classes out of Gleam: a requirement propagates through every generic caller as a constraint does (`largestOf` must declare `needs a.compare` for `largest`, §7.3 line 2181), and the compiler supplies the member by type at each call. The documents say what a requirement is not and never say that it is that mechanism with a fixed set of classes and one instance a type. Fix: one sentence in why.md's section granting the likeness and naming the two things that differ, the closed set and the member's home.

**M13. tour/README.md line 15 against line 120, the terminals.** Line 15 counts "your own, the shell's, from chapter 2 one for each of two nodes, and in chapter 8 one for a shell attached", the shell's second; line 120 says "In a second terminal `ern run --config-dir foo`, in a third `ern run --config-dir bar`", and "the shell, started again in your directory" without saying that chapter 1's shell is quit first. Fix: "in two more terminals" at line 120, and "`:quit` the shell of chapter 1 and start it again" where the shell starts.

**M14. guide/faq.md line 101, three systems and three clauses, unmatched.** "Erlang's funs, Scala's spores and Gleam's `const` make a top-level name the receiving node's, a local an explicit capture and a constant part of the code." Gleam has no receiving node, so the first clause is not its; a Gleam reader guesses that the third is. Fix: give each system its clause.

**M15. guide/language.md line 3109, the printed type of a form.** `:type Code.running` prints `(a) -> List(Address(m))`, a type in which nothing ties `a` to `m`, beside the sentence that calls it a form the compiler reads by a rule of its own. A reader who types `:type` first sees a function that takes anything. Fix: say in §8.9 that its printed type is not the rule, and where the rule is.

## Where writing Ernest was harder

None of my own: the programs run were the documents', transcribed as shown, and each built and printed its page's lines at the first try. The one thing felt in the transcribing is §1.3's `Os.Command`, five fields at every call to run `echo`, `workingDirectory = Os.workingDirectory` and `environment = []` among them; a Gleam programmer has no default arguments either, so it is noted and not counted.

## Kept for a reason an earlier milestone had

Looked for in the documents read, and found one candidate. `ern run --help` and §9.2 list `--load-path dir`, "compiled modules and Erlang `.beam` files", beside `--libs-dir dir`, "the Erlang applications under `dir`, each one's `ebin`": two flags that both put host code on the load path. §8.5's `entries_helper.beam` is a bare file and no application, so each has a use; named here since it is the one place in these documents where two commands do one thing.

## Chapter by chapter, as the Gleam programmer

- **README.** Shows in twelve lines of a shell what Gleam has not: a loop started on a node that holds none of its code, by a name and a hash. The refusal of `count` under `OtherMsg` is shown too. Asserts the Gleam panic (M3).
- **Why Ernest.** *Code travels* is shown by the tour and the shell session with `Counter$1.CounterMsg`, and over-told (M9). *The mailbox in the function's type* shows the refusal, the foreign check and the `Reply`; what it only asserts is the spawn (M8). *A WAN* is a configuration file and prose, as it says; a Gleam programmer who chose no distribution reads "a listed peer is trusted whole" and "one that may spawn on a node may run anything on it" as the sentence to decide on. *A deadlock is found* is the chapter that shows the most: two programs, two traces, and the one false case named. *Abstract types and requirements* is argued whole (M12).
- **The tour.** The best of the five documents: eight chapters, every line of every session reproducible, the planted deadlock and the version refusal both real. Chapters 6 and 8 together show what a `Subject` cannot say, a loop that takes its own next loop in its type and a process moved on a node that never had the new code. Its claim numbers are stale (M1).
- **The FAQ.** Honest about what Gleam has that Ernest lacks; misses the mapping of the everyday types (M7). "A sibling restarts only when it next waits" and "a child is killed, not asked to stop" are the two sentences a Gleam programmer who has used `gleam_otp` stops at, and both are stated plainly.
- **The guide, §0 to §10.** §3.5's effect variable is where the mailbox-in-the-type costs: every higher-order function carries `receiving e`, and every `receive` with a wildcard is `receiving e+`; the page shows both and hides neither. §4.4's "A library that waits" shows the price of one mailbox a process, a process and a call where Gleam makes a `Subject` in the caller, and says so. §5.5's `adapted` is the second channel a Gleam process would open, as a value. §6.5 and §6.6 show in-place restart with the address kept, which `gleam_otp`'s supervisor does not give a caller. §8.9 and deployment §5.3 are honest that a service under `restarting` falls back to its old loop at its next fault, which is the limit of the hot-code story. §7.3 is thorough and long (M10).
- **Deployment §1, §4 to §8.** For a reader who chose no distribution: §4.2's atom-table arithmetic and §7's table of lines are the two pages that make the choice look worth revisiting, since they say what fails and what to do. §8 runs end to end as written.

## Gleam lines checked

`process.receive(subject, 1000)`, `Subject`, `process.call` panicking at its deadline, `try_call` not named (it is gone from v1.3.0), `use`, type aliases, labeled arguments, `"inc " <> rest`, `gleam add`, the opaque type, `//` comments and `|>`: each is Gleam's as its documentation stands. The one that is not is M2's `process.receive(subject)`.

## What convinced me

The deadlock, which I saw end a test in a third of a second where my test runner waits; the version refusal, `Counter$3.CounterMsg`, which Gleam's reload-free world cannot even pose; and that every session I replayed printed its page. The mailbox in the function's type buys, on the page, exactly two things over a `Subject`: a typed address from `spawn` with no handshake, and the refusal of a receiving function in the wrong process. Both are real, and the second is small; the first is the one I would miss going back, and the one the documents argue least. The requirement is not a type class in what it lets a program build, and it is one in how it works; the documents convince me of the first by saying the second nowhere. I would try Ernest for a program of two or three nodes I run myself, which is what the tour is, and not yet for one with a supervisor I must upgrade in place, which the documents are honest enough to say is not what the move gives.

```

### U

```text
# Reader U: the guide against the rules the report changed since v0.9.0

Read at commit 7e7cdee1, against `report/` and `src/stdlib/`, with programs run under `bin/ern` in `S/readers/U/`.

Sections read: `guide/language.md` §0, §1.1 to §1.5, §2.8, §2.9, §4.4 (*A library that waits*, *Pacing*), §5.2 to §5.5, §6.3 to §6.6, §7.1, §8 (opening), §8.1 (opening), §8.3 to §8.7, §8.9, §9.1 to §9.5, §10, §11, §12; `guide/why.md`, `guide/faq.md`, `guide/deployment.md`, `guide/style.md` and `guide/README.md` whole.

Verified true by running: §2.8's pipe forms (`1 |> (3 |> adder)` is `adder(3)(1)`, `1 |> (fn(y) = y + 1)`); §5.3's `kill : (Process) -> Unit` and §5.2's `Process.run` type at the prompt; §6.4's trace ending in `Process.run:259`; §7.1's `Test.Failed("expected 2, got 3")` (no `differing at` where the texts differ at the first character; `differing at character 8` for the lists); §7.1's shortest-form error and its help `write \`Order.parse\``; §1.3's `Os.arguments` empty at the prompt; §6's `:processes` line `site receiving N bytes`; the start line `Ernest v, session 1. :help for help.`.

## Defects

**U1.** `guide/language.md:1531` (§5.5, *One process behind them all*): "`kill` takes any of a process's addresses and acts on the process behind it." False since §9.5 made `kill : (Process) -> Unit` and Appendix E.21 dropped `Process.kill`; two lines later the same section says `kill` ends a `Process`, and §5.3 says `kill(Process.fromAddress(worker))`. Shows: `printf ':type kill\n' | ern shell` answers `kill : (Process) -> Unit`. Kept from before `kill` took the identity, since no program in the guide writes it. Fix: "`kill` takes the process behind any of them, `kill(Process.fromAddress(a))`."

**U2.** `guide/language.md:3187` (§9.1): "A module is compiled again only when its source, an interface it depends on, another module's exported names and types, a definition of another module its code uses, any interface of the standard library, or the compiler has changed". Stale: report §11.1's list has two more cases, a qualified name in its source that would now resolve to another module or to none than its `.erc` records (§4.2's lookup), and a `.erc` that is no compiled module (§11). "Only when" makes the omission false. The list predates qualified lookup. Also "an interface it depends on" and "another module's exported names and types" are one case said twice. Fix: "... when its source, an interface it depends on, a definition of another module its code uses, the module a qualified name in it resolves to, any interface of the standard library or the compiler has changed, or when its `.erc` is no compiled module (report §11.1)."

## Facts owned by no document, or restated outside their owner

**U3.** `guide/deployment.md:168` (§2.2) and `guide/faq.md:87`: the cookie "every node's command line carries and `ps` shows, `-setcookie` and the digest". No report section says the cookie stands on the host's command line or that `ps` shows it: §12.5 says only what the cookie is the digest of. The fact is the code's (`src/nodes/ern_carrier.erl:76`) and is stated in two guides. Fix: either add one sentence to §12.5 *Connections* ("The cookie stands on the node's command line, which the host shows") and cite it from both, or cut the `ps` clause from the FAQ and keep it in the deployment guide alone, citing the code.

**U4.** `guide/deployment.md:104` (§1.4) and §7's table: the operator guide teaches `limits` (§1.2) and the two `refused` lines a full table leaves (§7), but nowhere that a node whose table of processes has no room ends with status 1 when it dials a peer, its peers seeing a loss (report §12.5, §11.8). §1.4's list of statuses, "A node exits with (report §11.8)", gives status 1's causes and omits this one. Fix: add to §1.4's status-1 item "and when it dials a peer with its table of processes full (section 1.2)", and a row to §7 or a sentence under the `table of processes is full` row saying what the node does at its own dial.

## Clarity

**U5.** `guide/deployment.md:17`: "The numbers quoted were measured on one machine of eight cores, and across three machines wired on one LAN, and each says which." §6 (line 347) quotes an attach "on an idle machine of twelve cores" and "on one of two", neither of which the preamble lists. Fix: name the twelve-core and two-core machines in the preamble, or drop the enumeration and keep "each says which".

**U6.** `guide/language.md:1712` (§6.3): "a failure of the runtime, a spawn past the host's limit of processes among them, is one too (report §7.3)". §7.4 owns that sentence (the diff's new paragraph in §7.4); §7.3 is *Faults*. Fix: cite §7.4.

**U7.** `guide/deployment.md:345` (§6): "The shell's code crosses to the node as a program's does, so a node of another release of `ern` on the shell's floor runs it (report §12.7)." The sentence's owner is now §11.2 *The attached shell*; §12.7's paragraph *The toolchain's own units*, which the citation once pointed at, went in this release. The citation is kept from that milestone. Fix: cite §11.2, *The attached shell*.

**U8.** `guide/language.md:3109` (§8.9): `Code.running(f)` lists processes on `f` "or of an earlier definition of its name whose message type is `f`'s". Report Appendix E.28 says "on whichever version of its module the node holds": a later version's processes are listed too where `f` is the older. "Earlier" fits the section's move and narrows the rule. Fix: "or of another version of its name with the same message type".

**U9.** `guide/language.md:3019` (§8.6): "A stream of bytes ... may end inside a line, and inside a character, so lines are split off the bytes before they become text". The character case is what Appendix E.5's new `String.fromUtf8Piece` reads, and the guide names neither it nor `fromUtf8Lossy` here, though §1.3 uses `fromUtf8Lossy` for a program's output. Not false; a reader of §8.6 is left to find the function. Fix: one sentence naming `String.fromUtf8Piece` for a stream of text whose pieces cut a character (report Appendix E.5).

## Kept for a reason an earlier milestone had

U1 (kill on addresses), U2 (the recompilation list) and U7 (the §12.7 citation) above. Nothing else in the guides' sections read serves a rule the report has since removed; §10's `Foreign.atom` is E.12's, and E.19 is cited nowhere.

## Where the language made the work harder

None. The probes (`S/readers/U/pipe.ern`, `tasks.ern`, `checks.ern`, `q/`) wrote as the guide teaches, and each refusal met was the one the guide predicts.

## Jobs taught two ways

None found. Where two functions meet one need (`String.fromUtf8` and `fromUtf8Lossy`, `Process.run` and `spawnMonitored` with a `receive`), the guide teaches them as two jobs and §5.7's exercise contrasts them on purpose.

```

### C1

```text
# C1: the runtime and its helper since v0.9.0

Read: `S/diffs/code1-runtime.diff` whole, and in R `src/runtime/c_src/ern_exec.c`, `ern_os.erl`, `ern_tty.erl`, `ern_io.erl` whole, the changed parts of `ern_rt.erl`, `ern_tcp.erl`, `ern_code.erl`, `ern_fs.erl`, `ern_peer.erl`, `ern_float.erl`, `ern_string.erl`, the test diffs, `docs/code_style.md`, `docs/design/runtime.md`, and report Appendix E.23, E.24, §12.1, §12.5. The programs are under `S/readers/C1/` (`probe.ern` to `probe5.ern`, built and run with `R/bin/ern`); every process they started has ended with its run. Nothing in R or the main checkout was edited.

Most serious first. Defects, then matters of clarity, then what writing Ernest made harder, then the security part.

## Defects

**C1.** `src/runtime/ern_rt.erl:1627` (`new_run/3`), beside `capture_writes/0` at 2340 and `collect/3` at 2358. A restart ends the restarting process's subscriptions, `faults_ended(Pid)`, `ets:delete(?TERMINATING, Pid)`, but not its captures. A `Test.capture` whose `run` faults in a restarting process leaves its collector standing: the chain's every write from then on goes to the collector, which answers each and keeps it, and nothing is written until the process ends, for a server never. Shown by `S/readers/C1/probe5.ern`: a `restarting(Unlimited, worker)` whose capture's `run` divides by zero; after the restart every line `main` prints is swallowed and comes out only at the program's end, after the worker is killed, out of order:
    ```
2026-11-10T08:47:26 Probe5.main:56 faulted, restarted: division by zero
worker: in the capture before the fault          <- written back at the program's end
worker: after the restart, is this line seen?    <- idem
5 main after the worker's restart                <- idem; nothing of main's reached stdout after the restart
    ```
The collector's `Taken` grows with every write meanwhile, memory no collection reclaims. Appendix E.24 says a capture ends where the caller ends, and §6.9 that a restart is no death, so the report does not decide it either; it does not say what a fault in `run` does to the capture. Fix: `new_run/3` lets go the captures of the restarting process as `let_go/2` does at the caller's end (the collectors keyed by the process's chain head whose caller is `Pid`, which the collector knows and the table does not: keep the caller in the row, `{Key, Collector, Caller}`), and one sentence in E.24: a restart of the caller ends the capture as its end does.

**C2.** `src/runtime/c_src/ern_exec.c:1016` and `report_exit` at 540, against Appendix E.23, `start` ("The processes the program started that are still in its process group are killed with it"). The helper kills the program's group only in `report_exit`, which runs once *both outputs have ended*; a child of the program that holds its stdout open keeps the outputs from ending, so the group is killed only after that child has ended by itself, and `read` waits for it. `Os.signal(Termination)` on `sh -c "sleep 31"` ends `sh` at once, but `sleep` lives on with the pipe, `Os.read(program, 3000)` answers `Left(Timeout)`, and `Exited(143)` comes after 31 seconds. Shown by `S/readers/C1/probe4.ern`, whose `ps` after the signal lists `sleep 31` alone, reparented:
    ```
plain sleep 31 term: Right(Unit)
plain sleep 31 read 3 s: Left(Io.Timeout)
2219275    2299 2219274 S    sleep 31
    ```
Either the sentence or the helper is wrong. If the sentence stands, the fix is in `exit_seen` (line 500): kill the group, `kill(-program, SIGKILL)`, as the exit is first seen, and reap in `report_exit` as now; the children's late output is lost then, which E.23's `read` ("once the program has exited and its standard output and standard error have both ended") would also need to say. If the helper stands, E.23's sentence says "killed once its outputs have ended". The old helper did the same, but `signal` is new and makes it the common case. A design question for the user, with a recommendation to kill at the exit: a process that outlives a program it was killed with is what `kill` promises against.

**C3.** `src/runtime/ern_rt.erl:2351` (`captured/1`). The caller sends `{collect, Alias}` and waits for `{Alias, Captured}` with no monitor of the collector. A collector that has ended answers nothing, and the caller waits for ever in a receive of the runtime's own (listed under `answered_at_once`). The collector ends without answering where its `true = ets:delete(?CAPTURES, Key)` at 2364 raises, the tables gone at the run's end, or where foreign code kills it. Low: today the caller is being killed by the same end. Fix: monitor the collector in `captured/1` and fault the caller, `the capture's collector has ended`, on its `DOWN`, as `restore/1` and `sink_flushed/1` monitor what they ask.

**C4.** `src/runtime/ern_os.erl:676` (`directory_error/2`) with `is_taken/4` at 125. A `workingDirectory` of `Path("")` passes `is_taken` and reaches the helper, whose `chdir("")` fails, and the answer is `Left(Other(": NotFound"))`, a line that names no directory. Shown by `S/readers/C1/probe.ern`, probe 4. E.23 says an empty variable name is `Invalid`; an empty directory is the same kind of word. Fix: `is_taken/4` refuses `Directory =:= <<>>` as it refuses an empty name, and E.23's `Invalid` sentence names the empty `workingDirectory`.

## Clarity, and what could be shorter

**C5.** One name, four shapes: `limited/0` in `ern_io.erl:104` answers `{'Other', ...}`, `ern_peer.erl:690` the same value again, `ern_tcp.erl:157` `{'Left', ern_io:limited()}`, `ern_rt.erl:3605` `limited(Reply)` refuses a reply, and `ern_fs.erl:30` `limited(Message)` answers a request. `ern_peer:limited/0` restates `ern_io:limited/0` line for line; `ern_exchange.erl:387` is its one caller and could call `ern_io`'s. Fix: drop `ern_peer:limited/0`, and name the other three by what each does with the limit, `refused_limited`, `answered_limited`, or keep `limited` for the value alone.

**C6.** `src/runtime/ern_rt.erl:3707` `taken/1`, the input a read took from an opened port, and 2382 `taken/2`, one stream's bytes of a capture: one name, two things, in one module. Fix: `read_from/1` or `input_taken/1` for the first.

**C7.** `src/runtime/ern_rt.erl:3428` (`is_taken/3`). Each write reads the writer's row twice, `capture_of/1` through `chain_head/1` and `screen_of/1` each calling `root_of/1`, before the ordered-set `prev` and the screens lookup. Shorter and half the lookups: read the root once in `is_taken` and pass it to both. The design note's "two lookups, about a tenth of a microsecond" (runtime.md line 71) counts the screens alone and no longer holds for a write: it is four now.

**C8.** `src/runtime/ern_rt.erl:3461` (`gone/1`) sends `{gone, Launch, Name}` through `launch_runner/0` while `told_runner/2` at 4667 does the same and says whether a run is in progress; `stream_gone/1` and `terminal_gone/0` go through `told_runner`. One way kept from before `told_runner` existed. Fix: `gone(Name) -> _ = told_runner(gone, Name), dropping().`

**C9.** `src/runtime/c_src/ern_exec.c:251` (`kill_program`): `kill(-program, SIGKILL)` then `kill(program, SIGKILL)`. The program is its group's leader under pipes (`setpgid` in both parent and child) and under a terminal (`setsid`), so the group kill reaches it, and `report_exit` at 546 kills the group alone. The second kill is from before the program always led its group. Fix: drop it.

**C10.** `src/runtime/c_src/ern_exec.c:334`, `wait_for_let_go`'s comment: "A run's last frame sent, 'x', 'f' or 't'", while the header at 48 says "'x', 'f', 'p' or 't'", and `main` at 913 calls it after 'p'. Fix: add 'p' to the comment.

**C11.** `src/runtime/ern_tty.erl:136`, the clause's comment: "the holder ended of itself, a kill from outside among the ways, which gave the settings back". The holder traps HUP, INT, QUIT and TERM, so a kill from outside that ends it is a KILL, after which nothing gave the settings back. Fix: "which gave the settings back where it could".

**C12.** `src/runtime/ern_tty.erl`: three words for ending what a refused subscription made: `let_go_of/3` at 210 kills the courier, `ended/1` at 387 kills the reader, `let_go/1` at 517 closes the holder; and `let_go` is a timer's in `ern_os.erl:542` and a capture's in `ern_rt.erl:2377`. The glossary names none. Fix: one word for "end what was made for a subscription that was refused", `unmade`, and `let_go` for one thing.

**C13.** `src/runtime/ern_code.erl:389` (`rows/3`) drops the function's mailbox hash, the sixth element, from the `{hash, Hash}` row, and `running/1` at 1040 reads it back by calling every holder's `'$code'/0` again through `listed/1` at 1054, a list built for each `Code.running`. Shorter: keep the mailbox hash in the row, `{function, Function, Arity, Reach, Mailbox}`, and read the rows.

**C14.** `src/runtime/ern_rt.erl:2159` (`wait_for_deliveries/0`) now also waits for the caller's fault courier to have delivered its reports (`waited_reports/0`), which the name does not say; its two callers in `ern_rt_tests.erl` took the place of `ern_waits:delivered/1` for that reason. Low. Fix: say so in the name or the glossary's **Delivery** entry, which names the function.

**C15.** `src/runtime/ern_tty.erl:409` (`raw_mode(none)`): where standard input is a terminal but neither `/bin/stty` nor `/usr/bin/stty` exists, `hold/0` answers `{ok, none}`, no mode is set, and `?PASTE_ON` is still written; keys then come in the line mode with paste bracketing asked. A host without `stty` is none Ernest runs on. Low; the old code did the same. Fix: none, or refuse the subscription where no `stty` is found, as `NotATerminal` is refused.

**C16.** `src/runtime/ern_os.erl:115` and `ern_tty.erl:508`: a port the host refuses answers `ern_io:host_error(system_limit, fun file:format_error/1)`, `Other("a system limit was hit, probably not enough ports")`, where a process the host refuses answers `Other("error:system_limit")` everywhere else. §12.5 states both (toolchain.md 647 and 651), so this is no defect; one host reason, `system_limit`, has two texts in `Io.Error` by which table was full. Noted for the design session, not for a fix here.

## What writing Ernest made harder

**C17.** A running program's address is `Address(ProgramMsg)` and `kill` takes a `Process`, so a program that starts a program and kills it writes `kill(Process.fromAddress(program))` each time (`probe.ern`, `probe3.ern`, `probe4.ern`), where E.23 says "`kill` stops it" as of a process. `Os.run` does the same inside. Not of this diff, but met at every probe; for `docs/language_feedback.md`.

**C18.** `Terminal.Size(24, 80)` is refused for named fields, `Size(rows = value, columns = value)`, as the checker says, while `Os.Exited(143)` prints positionally; the message is clear and the rule is §5.6's. Nothing to fix; noted as the one other stop.

## Security

Read against §8.4, §11.2, §11.3, E.17, E.18, E.23 as far as the runtime holds them. No real exposure found in what changed.

- The foreign boundary (`ern_boundary.erl`) changed only its include and a comment.
- A program's arguments, environment and directory reach the helper as frames the runtime builds; `is_taken/4` (`ern_os.erl:125`) refuses U+0000 in every word, an empty variable name and one holding `=`, and the helper's `set_variable` and `read_command` refuse the same again (`ern_exec.c:599`, 625). A `PATH` in `environment` decides where the program is found, which E.23 states. The helper's `chdir` precedes `execvp`, as E.23 states.
- A peer's `{kill, Pid}` frame is carried out for a local pid the runtime started alone (`ern_peer.erl` `frame/2`, `ern_rt:is_started/1`); `{restarted, Alias}` only where `node(Alias) =:= node(From)`; the spawn and compute frames lost the `Own` boolean and nothing else, their site still checked as UTF-8.
- The terminal's holder runs `/bin/sh -c` on a fixed script with the system's `stty` by path, `"$1"` and `"$found"` quoted (`ern_tty.erl:67`); nothing of a program's reaches it.
- `Fs.makeTempDir` (`ern_fs.erl:310`) draws sixteen hexadecimal digits from `rand:bytes/1`, under a parent `TMPDIR` names. Hardening only: the directory stands with the mask's mode between `file:make_dir` and `file:change_mode`, a window in which another user can enter and list it but write nothing, since `make_dir` takes no mode; E.17 states the order, so nothing to fix.
- `ern_os:signal/2`, `locked/2` and `node_signaled/3` pass numbers and a path from the configuration directory, unchanged since 0.9.0.
- A socket's input (`ern_tcp.erl`) changed in no reading path; the host's TLS process now hibernates after 1 ms, which E.18 states.

## What exists for a reason an earlier milestone had

- `ern_exec.c:251`, the second `kill(program, SIGKILL)` (C9).
- `ern_rt.erl:3461`, `gone/1`'s own send to the runner beside `told_runner/2` (C8).
- `ern_peer.erl:690`, `limited/0` beside `ern_io:limited/0` (C5).
- `ern_code.erl:389` and 1054: the mailbox hash dropped from the row and read again from `'$code'/0` (C13).
- `ern_tty.erl:409`, `?PASTE_ON` written with no mode set (C15).

```

### C101

```text
# C101: the nodes, the command line and the shared modules since v0.9.0

Read: `S/diffs/code2-nodes-cli.diff` whole; `src/nodes/*.erl`, `src/nodes/include/ern_node.hrl`, `src/toolchain/cli/ern_cli.erl`, `ern_out.erl`, `ern_signals.erl`, the changed parts of `ern_build.erl` and `ern_examples.erl`, `src/shared/ern_chunk.erl`, `ern_literal.erl`, `ern_tree.erl`, and their tests, against `docs/code_style.md`, `docs/design/nodes.md`, `docs/design/install.md`, report §11, §11.3, §11.8, §12, §12.5 to §12.8, Appendix C, §4.2 and §2.5; the host's `inet_tls_dist`, `net_kernel`, `dist_util` and `erts/dist.c` where the acceptor rests on them. No real exposure found in the part (S); what untrusted input reaches is listed under C111.

## Defects

C101. `src/nodes/ern_tls_dist.erl:116-118`, `{error, system_limit} -> ern_carrier:say_later("a connection was refused: this node's table of ports is full")`. The branch that report §12.5 states, "an `accept` that would do so closes the connection it took, which the node says of its own listener's", has no test: `test/ern_nodes_tests.erl` calls `accepting_nodes/2` with `<<"processes">>` (line 2269) and `none` (2317) only, so the port-table limit at the acceptor is never run. The host does answer so, and takes the connection: `erl +Q 1024 -noshell -eval '{ok, L} = gen_tcp:listen(0, [{active,false}]), {ok, P} = inet:port(L), Fill = fun F(H) -> case gen_tcp:listen(0, []) of {ok, S} -> F([S|H]); {error, E} -> {E, H} end end, {E, Held} = Fill([]), [H1|_] = Held, ok = gen_tcp:close(H1), {ok, _} = gen_tcp:connect({127,0,0,1}, P, [], 1000), io:format("~p ~p ~p~n", [E, gen_tcp:accept(L, 2000), gen_tcp:accept(L, 500)]), halt().'` prints `system_limit {error,system_limit} {error,timeout}`. Fix: a nodes test `accept_at_a_full_port_table_` over `accepting_nodes(Base, <<"ports">>)` whose keeper fills the store's ports with listeners, holding the line and the next spawn once freed.

C102. `src/toolchain/cli/ern_out.erl:72-77`, `log/2` ends in `ern_rt:say_later(Text, fun ern_cli:error_line/1)`, and its comment says "A raise here would have the host remove the handler for the rest of the job." `ern_rt:later_sayer/0` (`src/runtime/ern_rt.erl:4370-4382`) spawns the sayer where none runs, and no run has started it in `ern build`, `ern doc`, `ern format` and `ern config`: there the first warning the host logs at a full table of processes raises `error:system_limit` inside the handler, and the host removes `default`, so nothing the host logs after it is written, against report §11 ("What the host logs as a warning or worse, a job writes on standard error"). Fix: start the sayer in `ern_out:take/0`, where the job has room, or catch `error:system_limit` in `log/2` and write the line through `ern_cli:error_line/1` at once.

C103. `src/nodes/ern_carrier.erl:581-582`, `said({nodeup, Node, _}) when Node =:= node() -> none;` and the comment's sentence at 573-574, "The node's own start comes as a connection too, and is none". The gateway now reads the own node's `nodeup` itself (`src/nodes/ern_gateway.erl:232`, `{nodeup, Node, _} = Event when Node =/= node()`, and 244), so the clause is reached from nowhere but `ern_carrier_tests:260`: a check kept because nothing broke. The host does send the own node's `nodeup` (`erts/emulator/beam/dist.c:5040`), so one of the two filters is needed, not both. Fix: drop the gateway's guard and its fallthrough clause, letting `said/1` decide as it did, or drop the carrier's clause, its comment sentence and the test's line.

## Clarity: names, comments and shorter code

C104. `src/toolchain/cli/ern_cli.erl:1624-1628`, `limit_filter/2`'s clauses for `{erl_prim_loader, file_error}` and `"beam/beam_load.c("`. The name says a limit, but these two drop the loader's report of a file it could not read and the emulator's of a module it would not load, which a damaged `.erc` causes with no limit near (`ern_cli_tests:cannot_load_named_test`), and `job/6`'s comment at 230 names the work as "the host's report of an outcome the job says in a line of its own". One name for two kinds of work. Fix: name the function for what it drops, `said_in_own_words/2` or `host_report_filter/2`, or split the two kinds into two filters.

C105. `src/nodes/ern_gateway.erl:110-113` and 242, "`Ended` each peer that told this node it ends, or that this node refused as it connected", `Ended#{Node => refused}`. A peer refused as it connected never ended, so `Ended` now names two things, which `going_on/2` and the `nodedown` clause (206-210) tell apart by the value; and `ended/3` at 499 is a third meaning, a monitored process's `DOWN`, in the same module. Fix: a map named for what it holds, `Words` with values `ends | refused`, and `down/3` for the `DOWN`.

C106. `src/nodes/ern_tls_dist.erl:33`, `-define(PROTOCOL, tls).`, beside `src/nodes/ern_carrier.erl:24`, `-define(PROTOCOL, 6).` One macro name for two things in two modules of the nodes: the carrier's is the frames' protocol version in the cookie (§12.5), this one the host's name for the transport in the `accept` message. Fix: `?PROTOCOL_VERSION` in the carrier, or `?TRANSPORT` here.

C107. `src/nodes/ern_carrier.erl:550-551`, `certified(Der) -> host_named(host(certificate_key(public_key:pkix_decode_cert(Der, otp)))).` The DER is decoded as `otp`, then `certificate_key/1` (508-511) encodes it back to DER and decodes it as `plain`: three codec passes for one field the DER holds once. Fix: `#'Certificate'{tbsCertificate = Tbs} = public_key:pkix_decode_cert(Der, plain), host_named(host(public_key:der_encode('SubjectPublicKeyInfo', Tbs#'TBSCertificate'.subjectPublicKeyInfo)))`, and `certificate_key/1` the same from the certificate's own DER.

C108. `src/nodes/ern_carrier.erl:553-555`, "the line of a peer refused as its connection opens ... Named as a line names it (named/1, certified/1)". `ern_tls_dist:opened/4` (line 142) passes `["a connection" | From]`, no peer, as §12.5 asks ("A line of a connection the node did not take names no peer"), so the comment no longer holds for every caller. Fix: "Named a peer as a line names it, or `a connection from` its address while the key is not yet known".

C109. `src/toolchain/cli/ern_cli.erl:1569-1574`, "the level set here matters only in a host that took no streams, a test's". The launcher's first start, `node_flags/0`, takes no streams either, and there the host's own handler writes to the `user` device, which is standard output, the one stream that "carries the flags alone" (line 100): the line matters there most, since a notice written before `ern-node-flags` would make `bin/ern` (line 140) drop every flag and the second start refuse the node. Fix: name the first start in the comment, or have `node_flags/0` take the host's handler as `ern_out:logged/0` does.

C110. `src/shared/ern_chunk.erl:45-49`, "the chunk Name of the compiled module Beam, its bytes or its file", `-spec read(binary() | file:filename(), binary())`. Every caller passes bytes (`ern_cli.erl:1461`, `ern_interface.erl:39`, `ern_canonical.erl:1376`, `ern_prelude.erl:911`, `ern_docs.erl:20`); the file half is a width nothing uses, and `beam_lib:chunks` given a name would add `.beam` to it, as the carrier's comment at 186 warns. Fix: `-spec read(binary(), binary())` and "its bytes".

## Security: hardening, no exposure

C111. `src/nodes/ern_tls_dist.erl:92-96` and 188-189, `accepting/4` holds at most `schedulers_online` handshakes, each `given/3` waiting `net_kernel:connecttime()`, 7 s, for a peer that sends nothing. Before the TLS handshake proves a key, any host that can reach the listener can hold every slot by opening that many idle connections every 7 s, and a listed peer's dial then waits in the backlog past its own 7 s and fails as a refused one. This is the bound the host's own acceptor has (`inet_tls_dist:fam_accept`, `MaxPending = schedulers_online`), so it is no regression, and the node says nothing of it. Hardening, if wanted: a shorter time for the TLS handshake than for the whole setup, or a line once when every slot has waited a full time.

What I read for exposures and found sound: the rule `ern_carrier:verify/3` is called for every certificate of a chain but one the host validated, the leaf always as `valid_peer`, and TLS 1.3's CertificateVerify binds the leaf's key, so a chain whose root carries a listed key gains nothing; `ern_node:owned/4` refuses the directory and each file by owner and mode before `ernest.conf` is read, `ern config --peer-dir` reads a peer's directory the same way and never its key, and a peer's name is its directory's basename after `..` and `.` are resolved; `ernest.conf`'s numbers are bounded (`integer/2`), its fields known, and `limits` makes atoms of known names alone; a peer's address in a refusal line comes from `inet:peername`, a peer's name in a line from this node's own file, and an unlisted node's from its key's digest or escaped (`controls/1`); the gateway's frames from a peer are matched by shape with `node(From) =/= node()` and `node(Alias) =:= node(From)`; the exchange's frames and a peer's `telling` are a listed peer's, whom the design trusts whole.

## Kept for a reason an earlier milestone had

- C103's clause and comment sentence in `ern_carrier:said/1`.
- `ern_cli:quiet_signals/0`'s level line is still needed (C109), but its comment gives the old reason.
- `ern_chunk:read/2`'s filename half (C110).
- Nothing else found: `ern_code_load:own/1`, `ern_exchange:own_loaded/3`, `ern_carrier:is_test/1`, `ern_build:nearer_roots/4` and `names_a_source/2`, `ern_cli:application_code/1` and `names/1` went with their reasons.

## Measured, no finding

- Against a v0.9.0 clone built in `S/readers/C101/v090`: `ern run` of a hello world 203-231 ms there, 216-238 ms here; `ern build src/stdlib` full 887/905 ms, no-op 212/214-226 ms; `ern build src/shell` full 1433/1456 ms, no-op 218-225/255-272 ms; `ern doc src/stdlib` 947/1015 ms. The climb (`ern_build:holds_in/2`, which lists a namespace's tree anew at each question) adds at most 40 ms to the shell's no-op build.
- `ern_chunk:is_loadable/2` over the standard library's 27 `.erc`: 3.8 ms in all, so `current/6`'s and `found/2`'s extra `prepare_loading` costs nothing to see.
- `ern_code:load_runtime/0` loads 52 modules in 53 ms at a run's start, which the hello world's time against v0.9.0 does not show, since they were loaded at first call before.
- `ern_literal:float_text/1` on the edges of E.9 (`1.0e-4`, `9.9999e-5`, `1.0e16`, `9999999999999998.0`, `5.0e-324`, `1.7976931348623157e308`) writes what E.9 states; `-0.0` writes `0.0`, as v0.9.0's did.
- `ern config --peer-dir b/.`, `--peer-dir dir/c/` and `--peer-dir a/..` name the peers `b`, `c` and refuse `a/..`.

## Where Ernest made the work harder

None: the part is Erlang, and the only Ernest written was a one-line hello world.

```

### C201

```text
# C201: the compiler since v0.9.0

Reader C201, the third part of the code's reader: the checker, the emitter, the parser, the formatter and the lexer, against `docs/code_style.md` and the report sections their comments cite. Read whole: `ern_resolve.erl` (new), the diff's hunks of `ern_typecheck.erl`, `ern_canonical.erl`, `ern_emitter.erl`, `ern_compile.erl`, `ern_parser.erl`, `ern_format.erl`, `ern_ast.hrl`, `ern_prelude.erl`, `ern_interface.erl`, `ern_docs.erl`, `ern_lexer.erl` and their tests, with §4.2, §5.7, §5.10, §6.9, §7.3, §11.5, §11.6, E.21, E.28 and Appendix H beside them.

Tried, under `S/readers/C201/p` with `R/bin/ern`: an `or` inside a tuple, a list, a `let` and a parameter (refused with the help §11.5 states; the clause written out is accepted); `x |> (a |> f)` and `10 |> (3 |> g)` of a two-argument `g` (`f(a)(x)` runs; the second is refused as a call of one argument); the bitstring hug with and without a size (laid out as §11.6 says); `kill` on an address (refused, `expected Process`); `Process.callerSite()` from a program (refused as private); `Process.run` called, named as a value, passed to `List.map` and nested, each process sited at the line where `run` is written; a tree where `Top.Shell` writes `Shell.name()` beside a parameter `name` (accepted) and `Top.Shell.name()` and `Shell.T` (refused with the help); a member named in an expression; and `Code.running` of a function with a timed receive in its body (listed) and of one whose lambda holds the timed receive (not listed). Every rule the diff implements behaved as the report states. No defect of behavior was found; the findings are comments that no longer hold, a test that tests no program, copies and names.

## Defects

**C201.** `src/toolchain/checker/ern_typecheck.erl:103-105`, the `#env{}` comment: "written qualified in, and in no longer form (own_shortest/4)". The function is `own_shortest/2` (line 6938). A comment that no longer holds. Fix: write `own_shortest/2`.

**C202.** `src/toolchain/parser/ern_parser.erl:1397-1399`, `inner_or/1`'s comment: "a size's expression holds clauses of its own, whose `or` stands between whole patterns"; and `src/toolchain/parser/test/ern_parser_tests.erl:475-477`, the last assertion of `or_inside_a_pattern_test`, `fn f(<<x:size(match n { 1 or 2 -> 8 })>>) = x`. §5.11 admits no `match` in a size: the checker refuses it, "a size in a pattern is a variable, a top-level `let`, an Int literal, or `+`, `-`, `*` of them" (shown by `or_size.ern` under `S/readers/C201/p`). The skip of the size in `parts/1` is right, since a size is an expression and no part of the clause's pattern, but the comment reasons from a program that cannot exist, and the test passes on a parse of one. Fix: say the size is an expression and holds no pattern of the clause's; replace the test's example by one the checker accepts, or drop it.

**C203.** `src/toolchain/parser/ern_parser.erl:977-979`, in `binexpr_loop/3`: "report §5.7: parentheses around the right-hand side change nothing, so a parenthesized call is a call the pipe fills, as an unparenthesized one is". Since this diff `combine/4` (line 1011) fills no `#e_call{pipe = true}`, so a pipe in parentheses is not filled, which `combine/4`'s own comment says. The comment at the loop overstates and stands at the wrong place, above an operator-generic step. Fix: delete it, leaving `combine/4`'s.

**C204.** `src/toolchain/emitter/ern_emitter.erl:81-89`: the `#emit_context{}` comment documents `guard` and `caller_site`, and not `in_lambda` (line 89, set at 1154, read by `wait_prefix/1` at 1277). Fix: add a line, "in_lambda: whether the expression being compiled stands in a lambda's body, by which a timed receive's wait is named (wait_prefix/1)".

## Copies and code that could be shorter

**C205.** `src/toolchain/checker/ern_typecheck.erl:252-256` and `src/toolchain/cli/ern_build.erl:1162-1166`: the same three-clause `case {check(...), TooLong}` that joins the checker's answer with the too-long errors, `{ok, ...}` kept where `TooLong` is `[]`, else `{error, TooLong}` or `{error, lists:sort(TooLong ++ Diagnostics)}`. One copy. Fix: give `ern_typecheck:check/4` the `TooLong` list as a fifth argument and do the join there; `ern_build:checked/2` and `check/3` then each call it in one line.

**C206.** `src/toolchain/emitter/ern_compile.erl:597-603`, `site_arity/1`, and `src/toolchain/emitter/ern_emitter.erl:913-917`, inside `arity/1`: the same `case caller_sited(QualifiedName) of true -> 1; false -> 0 end`, and `caller_sited_value/3` (line 1468) subtracts the same 1 from `value_arity/2` to strip it again. Fix: export `site_arity/1` from `ern_emitter` beside `caller_sited/1`, call it in `arity/1`, in `ern_compile:linked/4` and in `caller_sited_value/3`, and delete `ern_compile:site_arity/1`.

**C207.** `src/toolchain/checker/ern_resolve.erl:272-275`, `name_span/2`, and `src/toolchain/checker/ern_typecheck.erl:5704-5707`, `constructor_name_span/1`: one formula, `{Line, Column, {Line, Column + length(ern_namespace:text(Written))}}`, the span of a name as written from where its node begins. Fix: export `ern_resolve:name_span/2` and have `constructor_name_span/1` call it with `Written ++ [Name]`.

**C208.** `src/toolchain/checker/ern_canonical.erl:152-171`, `mailbox_hash/1`: three cases nested three deep to say "Never's hash where the effect is none or a process-only variable; none where it holds a variable; the effect's hash otherwise". Fix: a function `is_never(Effect, Quantified)` for the first two branches, then one `case` of three clauses over `{is_never(...), holds_variable(Effect)}`; the comment then reads as the code does.

**C209.** `src/toolchain/parser/ern_parser.erl`: `namespace = Namespace, written = Namespace` is written at 13 construction sites of `#e_var{}`, `#e_constructor{}`, `#p_constructor{}` and `#t_named{}`. A form repeated at site after site, which the next node that carries a qualified name will repeat again. Fix: one helper per record is no shorter; a `qualified/2` that sets both fields on any of the four records (`setelement` by the record's field index, or a function clause per record) is, and names the fact once: a parsed name's `written` is its `namespace`.

## Names and specs

**C210.** `src/toolchain/checker/ern_resolve.erl:265`: `-spec too_long(term(), [atom()], [atom()], [atom()])`. The first parameter is a Span (the glossary's), which the checker's `fail/4` types `ern_diagnostic:position() | ern_diagnostic:span()`. Fix: that type.

**C211.** `src/toolchain/formatter/ern_format.erl:574-578`, `segment_value/1`: it answers the last segment's value where that value may hug, and `none` where a size or a type follows, so its name says less than its work; and `src/toolchain/emitter/ern_emitter.erl:3538`, `segment_value/4`, names a different thing, a segment's value form. One name for two things across the toolchain. Fix: in the formatter, `hugging_segment/1` or `bare_last/1`, with the comment it has.

**C212.** `src/toolchain/checker/ern_resolve.erl:246-250`, `too_long_or_not/5`: a name that says what the function may not do. It answers a namespace, and an error beside it where the written form is longer than the shortest. Fix: `held_to_shortest/5`, or fold it into `named/6` as two clauses on the shortest's length.

**C213.** `src/toolchain/checker/ern_resolve.erl`: `resolved/3` (37), `qualifiers/3` (50), `resolutions/3` (105) and `qualifier_resolved/4` (117) are four names around one idea; `qualifiers/3` is `resolutions/3` with the shortest forms dropped, as `resolved/3`'s second answer is. Fix: name the internal one for what it adds, `with_shortest/3`, or have `qualifiers/3` be the one list and `resolved/3` ask the shortest forms where it rewrites; either leaves two names.

**C214.** `docs/code_style.md:77`, the glossary's **HelpText**: "a pattern's is written whole, `ern_parser:pattern_text/1`", a function the module does not export (`ern_parser.erl:11-12`); the entry reads as naming a place the checker's helps may call, as `ern_ast:help_text/1` is. Fix: say it is the parser's own, or export it where a checker help comes to need a pattern written whole.

## Kept past its reason

**C215.** `src/runtime/ern_rt.erl:616-622`, `caller_site/0`, with `src/stdlib/process.ern:296-299`, `foreign fn callerSite()`: a function that exists to be a declaration's target and is never called, since `ern_emitter:callee/5` (line 1687) replaces the call by its qualified name in `run`'s body. This is E.21's design, not a leftover, and the three places that must agree on the names, `caller_sited/1` (`['Process', run]`), the `callee` clause (`['Process', callerSite]`) and `process.ern`, are held together by `process_run_test` alone. Noted, no fix asked: a second caller-sited declaration would be the moment to hold the list by a test. Nothing else in the compiler's diff exists for a reason a later rule removed: the `check/3` entry that resolves alone is the tests' and `check_string`'s, and `is_primitive/1`'s `kill` is still the runtime's.

## Where the language made the probes harder

**C216.** A probe that waits for every live process to be `Receiving` by polling `Process.status` spun on itself, since `Process.live()` listed the entry process; E.21 says `live` answers "the processes a program spawned", which the entry process is not in so many words (§8.1 says the runner starts it). The runtime's reader's area; raised here as a sentence to read, not a defect found.

**C217.** Polling `Process.status` in a loop was the one way, in a program, to wait for another process to reach a receive; the emitter's own test reaches for a foreign `ern_waits:waiting/1`. Not a gap the report leaves, since §8.6 gives a program nothing to wait on but a message, and noted only as what the probe cost.

**C218.** `List.length` is "unknown name List.length" with no help; the name is `List.size`. A help that names the module's nearest name is §11.5's and E.0's to weigh, not this diff's.

```

### C301

```text
# C301: the standard library and the shell since v0.9.0

Read: `S/diffs/code4-stdlib-shell.diff` whole; in R, `src/shell/ern_shell.erl`'s changed regions whole (`spawn_input`, the load checks, the reload, `compiled_of` and the source access, `holder_bound` and `collect`), `src/shell/ernest/shell.ern`'s session, reader and screen, `history.ern` whole, `src/shell/test/ern_shell_host_tests.erl`, the stdlib files the diff touches, the shims they call (`ern_string:drop/2`, `decoded/1`, `ern_fs:temp_dir/1`, `ern_os`'s start, signal and command checks, `ern_exec.c`'s variable, directory and exec steps, `ern_rt`'s `capture_writes`, `captured`, `spawn_monitored/3`, `caller_site/0`, `expected/1`, `host_cause/2`), their tests under `src/runtime/test/` and `test/`, the pages `ern doc` wrote, and the report's E.5, E.17, E.21, E.23, E.24 and §11.2 sentences for each. Probes under `S/readers/C301/` (`strings.ern`, `osy.ern`, `procs.ern`, `tempdir.ern`), built and run with `R/bin/ern`; every one's output matched the pages, except where a finding says.

## Defects

**C301.** `src/shell/ern_shell.erl:2337-2355`, `is_form_loadable/2`: `{ok, #{interface := #interface{namespace = Held}}} -> ern_chunk:is_loadable(ern_namespace:erlang_module(Held), Beam)`. It answers true for a `.erc` at the module's path that holds another module, so the help after an unknown name says `:load Foo puts it in scope` where `:load Foo` then refuses the file as holding another module (`compiled_of/2`, line 4538, `held_another`). The two functions walk the load path twice for one question, the first from before the shell refused a form the host will not load. Fix: write `is_form_loadable(Session, Relative)` over `compiled_of/2`, `case compiled_of(Session, Namespace) of {ok, _, _, _} -> true; _ -> false end`, which is shorter and carries both refusals.

**C302.** `src/shell/ern_shell.erl:1257-1310`, `input_spawned/4`, and its `try` in `spawn_input/4`: the unit is loaded (`code:load_binary`, `unit_loaded`), recorded (`record_uses`) and its text kept (`keep({input_text, Namespace}, ...)`) before `ern_rt:spawn(Body, ...)`. Where the spawn alone raises `error:system_limit`, the catch answers the fault but the declaring input's unit stays loaded, recorded as kept (`is_kept(declarations, _)` is true, line 1572) and its text kept, never joined, and no collection lets it go while the session lives. The test (`test/ern_shell_tests.erl:2323`) says it does not cover this case, since the compiler's process has just ended; that is a race, not a rule. Fix: spawn the input's process, or reserve it, before the unit is recorded, or undo the three records in the catch as `withdraw_load/2` undoes a load's.

**C303.** `src/stdlib/process.ern:247-259`, `Process.run`: the judge is `spawn(fn() = {...})`, a process of the caller's chain with the site of that line of `process.ern`. `Process.live()` and `:processes` list it while the run waits, as `Process.run:247 receiving ...`, and a fault in `f` carries the frame `Process.run:259` in its trace. Probe, `S/readers/C301/procs.ern`: `List.size(Process.live())` is 2 before, 5 during a run (caller, asker, judge, worker, main); the trace of `Process.run(fn() = 1 / 0)` is `erlang:'div'/2`, `Procs.main:6`, `Process.run:259`. The report's E.21 names the worker's site alone, and §11.2 gives no reader a way to open `process.ern` at a line. Fix: give the judge the caller's site too (`spawnMonitoredAt`'s with its own wrap, or a `spawnAt` the runtime answers), and decide in E.21 whether a frame of the library's own Ernest stands in a trace, as a frame of the runtime's does not.

## Clarity

**C304.** `src/stdlib/string.ern:572-573`, `fromUtf8Lossy`: "each byte that begins no character shown as one U+FFFD". A character the bytes never finish is shown byte by byte: `String.fromUtf8Lossy(<<226, 130>>)` is two U+FFFD, and `<<240, 159, 152>>` three (probe), which the test's comment states (`from_utf8_lossy_test`, "a cut character shows byte by byte where nothing can finish it") and the page does not. Fix: one sentence on the page and in E.5, "the bytes of a character the stream ends inside are each one U+FFFD".

**C305.** `src/stdlib/test.ern:76-78` and E.24: "the failure says at which character, counted from 1". The count is over the texts as `Io.show` writes them, quotes included: `Test.equal("abc", "abd")` says `differing at character 4` (probe), where a programmer comparing strings reads 3. Fix: "counted from 1 in the texts as shown".

**C306.** `src/shell/ernest/shell.ern:236` (`fn defaults()`), `:567` (`fn localMs()`), `src/shell/ernest/shell/command.ern:51` (`fn commands()`), `:219` (`fn settingsAbout()`): four top-level `let`s became functions with no comment saying why, and `commands()` builds its table again at each `pick`, each completion and each `:help`. A reader who knows §4.6 sees a binding whose initializer is no constant and asks what a `let` would have cost. Fix: one comment at `commands()` naming the rule (a shell binding's value crossing to the node, or the log entry).

**C307.** Names. `src/shell/ernest/shell.ern:770`, `fn faulted(state, screen, cause, trace, started, printing)`: a past participle for a function that says the fault, says the time and collects; the guide names what does something as a verb, `sayFaulted`. `src/stdlib/test.ern:99-100`, `let wanted = Io.show(expected); let got = Io.show(actual)`: two names for each of `equal`'s two concepts within one function; `expectedText`, `actualText`, or `parting(expected, actual)` over the texts.

**C308.** `src/shell/ern_shell.erl:4627`, `entry_kind(Session, Path, 'Link') -> [file || is_source(Session, Path)]`: a filter-only comprehension as an `if`; `case is_source(...) of true -> [file]; false -> [] end` reads plain. `:4648`, `file_error('NotAFile') -> eisdir`: a source that is a device or a pipe is refused as "is a directory"; from when `NotAFile` meant a directory alone. Fix: `{text, "is not a regular file"}`.

**C309.** Tests. `Os.signal`'s `Left(Closed)` once the program has exited (E.23, `src/stdlib/os.ern:566`) and a program that handles the signal have no test beyond the page's example; `src/runtime/test/ern_os_tests.erl` sends `SendSignal` only under a helper that ends. The probe holds both (`Right(#(Os.Exited(0), Left(Io.Closed)))`; a `sh` with a `trap` answers `got` and `Exited(7)`). Fix: a test in `ern_os_tests.erl` citing E.23.

**C310.** Kept for a reason an earlier milestone had: the two in C301 and C308 (a second walk of the load path, and `NotAFile` as `eisdir`). Nothing else in my part: `trouble`'s `Io.NotLoaded` line (`shell.ern:586`) still names a `Peer` error; `spawnMonitoredAt` is the prelude's host function declared again for a site the prelude cannot pass; `String.sliced` and `decoded` are the primitives E.5 names.

## Security

**C311.** No real exposure found. Read: `Os.start`'s checks (`ern_os:is_taken/4`, NUL in the name, each argument, each value and the directory; a name empty or holding `=`), the helper's `setenv` before `chdir` before `execvp` (so a `PATH` in `command.environment` decides where the program is found, probe: `Left(NotFound)` with `PATH=/nonexistent`, as E.23 says); `Fs.makeTempDir` (`TMPDIR` relative makes the directory under the working directory and answers a relative path; one that names a file answers `Left(NotFound)` by `Fs`'s rule; a name that exists is drawn again); the history (`$HOME/.ernest` made `0o700`, the file refused as a link or another's before it is read or appended). Hardening, decided by E.17's own sentence: `ern_fs:temp_dir/1` makes the directory under the mask and sets `0o700` after, so under a mask of `0o000` another user may enter it and make an entry before the mode is set; the host has no `make_dir` with a mode, so closing it means the helper or an umask the runtime holds. `rand:bytes(8)` is not a cryptographic draw; harmless, since an existing name only makes the shim draw again.

## Where the language made the work harder

**C312.** `Os.Command` has five fields and no default: 52 sites in 15 files write `environment = [], workingDirectory = Os.workingDirectory`, every example on `Os`'s page among them. A record field with a default (§5.6 has none) or an `Os.command(program, arguments)` in E.23 would carry the common case.

**C313.** `kill : (Process) -> Unit` (§9) makes every kill of an address `kill(Process.fromAddress(address))`, 25 sites, 10 in the library, `kill(Process.fromAddress(supervisor))` on `Supervisor`'s page among them. The report decided it; the reading is that the common case got longer.

**C314.** Writing the probes: `Io.debug(x);` as a statement is refused, "this statement's value is discarded", so a probe needs its own `show`; and `after` is a reserved word a reader meets only at `receive`.

```

### C401

```text
# C401: the libraries since v0.9.0, against Appendix G

Read: `S/diffs/code5-libs.diff` whole; `http.ern`, `json.ern`, `uri.ern`, `base64.ern`, `ern_http.erl`, `ern_json.erl`, `ern_uri.erl` and `ern_http_tests.erl` whole; the deleted `erl/http/src/ern_http.erl` and its tests, for what moved; Appendix E.0 and G; E.18 for `Tcp.read`; the pages under `docs/man/libs/{http,json,uri}/`. Probes under `S/readers/C401/` (`probe_uri.ern`, `probe_json.ern`, `probe_http.ern`, `probe_dates.ern`), built and run with `R/bin/ern`. No process left running.

The move of the three shims' work into Ernest is sound: every head the deleted Erlang tests read is read by a case in `http.ern`, the new shims do only what E.0 rule 1 leaves the host (a line's split by `decode_packet`, `json`'s terms and raises, `uri_string`'s map), and no reference to `erl/`, `ern_base64` or `ern_json:parse` survives outside the log. The security probes found no real exposure: both framings beside each other, `chunked` twice, a non-chunked last coding in a request, a `Content-Length` of two values, an obs-fold in a request, a bare CR, NUL and non-UTF-8 in a value, white space before a `:`, a raw UTF-8 byte and a control in a target are each refused; a hexadecimal chunk size past the limit and a `Content-Length` past it are refused at once; `Uri.parse` refuses a second `#`, `@` twice, a port that is not digits, a `%` without two digits and every character outside the RFC's; `Json.parse` of 200 000 nested arrays reads in 66 ms with no stack to blow.

## Defects

**C401.** `src/libs/http/http.ern:477-508` (`headerLines`), with `ern_http.erl:read_field`. A head whose last line the host cannot read is not refused until the byte after it comes: `decode_packet(httph_bin, <<"junk\r\n">>)` answers `{more, _}` (it holds every line's verdict, an `http_error`'s too, until it sees whether a fold follows), so `headerLines` answers `Partway`, `parseRequest` answers `Incomplete` for bytes that can never complete, and on a socket `readRequest` waits for the deadline and answers `Socket(Timeout)` where the report's answer is `Protocol(Malformed)` ("a header line ... the host cannot read"). Shown by `probe_dates.ern`: `"GET / HTTP/1.1\r\njunk\r\n"` and `"GET / HTTP/1.1\r\n\r\r\n"` each answer `Left(Http.Socket(Io.Timeout))` after 501 ms with `ms = 500`, while `"\r\r\n"` as a first line is `Malformed` at once. Fix: where `readField` answers `More` and `bytes` holds a line feed, ask the host once more with a byte that begins no fold appended, `readField(bytes <> <<'X':utf8>>, size)`, and answer `Left(Malformed)` where that answers `Unreadable`; otherwise keep `Partway`.

## Clarity and design

**C402.** `src/libs/http/http.ern:358-363` (`readFirst`) and `ern_http.erl:read_first`, against E.0 rule 1. For the first line the host's `http_bin` is not the function exactly, and the Ernest does its work again: `words` parts the line, `isVersion` reads `HTTP/d.d` (and has the two digits in hand that `RequestLine(major, minor)` carries back), `isStatus` the status, `isTarget` the target. What the shim is left to do is find the line feed within `packet_size`, which `http.ern:1034-1052` (`line`) already does in Ernest for a chunk's lines with a limit. The header line's shim earns its place (fold detection, the token check of the name, the split at `:`); the first line's is a primitive the Ernest closes by redoing it. Fix: read the first line with `line`'s way, the limit as `packetSize` gives it, and drop `read_first/2`, `RequestLine` and `StatusLine` from `Line`; or state in `readFirst`'s comment what the host still contributes.

**C403.** Names that say two things. (a) `http.ern:327` `Heading.taken : Int`, "the bytes their lines took", beside `http.ern:1056` `fn taken(reading, bytes, count)`, "the first `count` bytes": one name, two meanings. Rename the function `firstBytes` or the field `headerBytes`. (b) `http.ern:1102` `fn headers(headers : List(Header), name)`: the parameter is named as the function, so `cookies` at `http.ern:1130` must write `Http.headers(headers, "Cookie")` inside `Http` itself, the one self-qualified name in the libraries. Name the parameter `fields`, as `framing` at `http.ern:944` already does. (c) `http.ern:1818` `let sized = fn(count) = ...` in the test `namedValues` shadows the top-level `fn sized(size : String)` at `http.ern:2705`, which the body tests use; a reader meets two `sized`s of different types. Rename the local `requestOf` or `lineOf`.

**C404.** `src/libs/ansi/ansi.ern:155,165`: `clearBelow = "\u{1b}[J"` and `clearScreen = "\u{1b}[2J\u{1b}[H"` were `sequence("J")` and `sequence("2J") <> sequence("H")`; `sequence` at `ansi.ern:168` still writes the introducer for `styled` and `move`. The CSI is now written two ways in one module, and nothing says why the two constants may not call `sequence` (a reader guesses §4.6's constant). Fix: a one-line comment above `clearBelow` naming the rule, or keep the calls if the rule does not bind them.

**C405.** `http.ern:1261-1272` (`renderResponse`): two statements of the form `if ... then fault(...) else Unit;` beside `checkMethod`, `checkTarget` and `checkHeader`, which are functions named for what they check. Fix: `checkStatus(status)` and `checkBodiless(status, body)` in the same shape, so the five checks read alike.

**C406.** Silent defaults for cases the comment says cannot come: `http.ern:1408` `Optional.withDefault(Int.toStringBase(Bytes.size(bytes), 16), "")`, which would write a chunk of no size line, and `http.ern:1743` `None -> ""` in `dayName`, which would write `, 06 Nov ...`. `json.ern:259` faults in the same situation (`numberIndex`), the honest form. Fix: `fault` with a cause in both, or a comment on `chunk` as `dayName` has.

**C407.** `http.ern:1129-1133` (`cookies`) and the report's G.11. `probe_http.ern`: `cookies([Header("Cookie", "a = 1; =2; b")])` is `[#("a ", " 1"), #("", "2")]`, so `cookie(headers, "a")` is `None` and `cookie(headers, "")` is `Some("2")`. This is what the report states (the part trimmed, then parted), and no browser sends either; but RFC 6265bis §5.6 trims the name and the value each, and a name of no characters is dropped. Fix: either, decided with the user; the page should then say which, since today it says only "a value kept as written".

**C408.** `http.ern:1238-1246` (`renderResponse`'s `Errors`): "A head that would not read back as written is a program's own error, and faults the caller", but a value with white space around it, `" padded "`, is written as given and reads back `"padded"`, and a `Content-Length: 999` given with a body of one byte is written as given (`probe_http.ern`), neither faulting. The report says "otherwise a value is written as given", so the code is right and the sentence over-promises. Fix: "A head whose line structure would not read back ..." or list the four checks as the sentence's subject.

**C409.** "Regression tests, written with the code" at `http.ern:1754`, `uri.ern:244-245` and `ern_http_tests.erl:4-5`: CLAUDE.md's *Tests* makes a regression test one written after the code, and the libraries' own case comments keep that sense ("a regression test, written after the code", `json.ern:604`). Fix: "Written with the code" in the three section comments, and "regression test" only on the cases that were.

**C410.** `http.ern:2182-2184`: "A regression test, of the shim the Ernest replaced: the limit was found only after the line's end." The history of the replaced shim is the log's; `docs/code_style.md` has a comment cite the log entry by title where the history matters. Fix: name the entry, or cut the clause after "regression test".

**C411.** `http.ern:2179-2214` and the `limits` tests: no case reads a request whose empty line is split as `"\r"` then `"\n"` across `carried` and the socket with a headers limit already spent (`headerLines` gives the head's end the line's limit by `isHeadEnd`, which answers true for `<<'\r'>>` alone). `everySplit` covers the split at every byte, but with the default limits only. Fix: one case of `headersInLine`'s shape with `carried = head <> "\r"`, `headers = 6`.

## Hardening (no exposure found)

**C412.** `http.ern:799-806` (`readOn`), `824-834` (`received`), `1034-1052` (`line`): each read appends to the bytes so far and `line` scans the whole buffer for a line feed again, so a client that sends one byte a packet costs the reader O(n²) in the limit, and `toClose` at `1066-1073` tests the limit only after a read, so one read may pass it by the read's size. Both are bounded by `ms` and the limits, as the report states them; noted, no fix asked.

## Where the language made the work harder

**L1.** A byte's class is written by hand in every library, since a bitstring pattern binds an `Int` and `Char.isAsciiDigit`, `Char.digitValue` take a `Char`: `isDigit` at `http.ern:661` and `json.ern:267`, `isHexDigit` at `json.ern:466`, `digit` at `uri.ern:232` (whose comment at 229-231 says `Char.digitValue` was tried and cost too much), `isCharacter` and `place` at `base64.ern:118-146`, `isBlank` at `http.ern:578`. Count over `src/libs/`: seven range tests of the form `byte >= 0x30 && byte <= 0x39`. A `Char` predicate over a code point, or a `Bytes` vocabulary for a byte's class, would take them all out; this is `docs/language_feedback.md`'s.

**L2.** Shadowing is silent: a local `let sized = fn ...` hides a top-level `fn sized` (C403c), and a parameter named `headers` hides the module's own `headers` so that the module writes its own name qualified (C403b). Nothing warns, and `ern format` keeps both. A warning where a local binding hides a top-level name of the module would have caught both as they were written.

**L3.** A check that faults has no form of its own: `if cond then fault(cause) else Unit;` as a statement (`http.ern:1261-1272`), or a function wrapping it (`checkMethod`, `checkTarget`, `checkHeader`). Four such functions in one module suggest a shape the library lacks, `Io.assert`-like or `cond || fault(cause)` as a statement; weighed against E.0 rule 4 it may still be refused, but it was felt.

**L4.** `json.ern:368-457`: `Broken` carries its `error`, whose `position` is O(n) over the text, built before the guard at `json.ern:178` or `186-188` may discard it, because a record cannot hold a value to be computed later without a lambda field. Harmless (an error path), but the shape was chosen for the type, not the work.

```

### C501

```text
# C501: the site's generator

Read whole at 7e7cdee1: `tools/site.ern`, `tools/site/*.ern`, `tools/site/ern_site.erl`, `site/templates/` with its README, `test/ern_site_tests.erl` with `test/fixtures/site/`, `docs/design/site.md`, against `docs/code_style.md`, `guide/style.md`, E.0, §2, §4.2, §11.2 and §11.4. `make -C R site TAG=HEAD CONFIG=…` ran once: 13 s, of which the generator alone over the checkout is 3.8 s for 90 pages (its 90 `git log` spawns cost 0.4 s). Each module's page was read as `ern doc` writes it. Experiments ran the generator over copies of HEAD's tree with one change each, under `S/readers/C501/` (`tree-*`, `out-*`).

## Defects

**C501.** `tools/site/links.ern:517-535`, `resolved`: `#("", _) -> Right(acc)`. A link that begins with `/`, a site address written in a document, is read as relative to the source's directory and silently led to a GitHub path that does not exist. `[Why](/why/)` appended to `guide/faq.md` builds without a word and writes `href="https://github.com/joagre/ernest/blob/HEAD/guide/why"`; `[x](/report/language.html#6.5)` gives `…/blob/HEAD/guide/report/language.html#6.5` (`S/readers/C501/out-absolute/faq/index.html`). CLAUDE.md's *Defects and gaps*: never accept silently. Fix: `resolved` answers `Left(source <> " links to " <> link <> ", an absolute path; a link written for GitHub is relative")` for a link whose first segment is empty, or `mapped` takes a leading `/` as the site's own address and leaves it to `Check`.

**C502.** `tools/site/run.ern:226-291`, `described` and `firstSentence`: "its `.`, `?` or `!` of prose that a space or the inlines' end follows". The guide's chapter 12 opens `**§1.5.** (a) compiles…`, so `/guide/12.html` is described as `§1.5.`: `grep description R/build/site/guide/12.html` gives `<meta name="description" content="§1.5.">`, and `og:description` the same. A shared link shows a label. Fix: `firstProse`/`firstSentence` pass over a `Strong` that opens the paragraph and ends in `.`, a label, as they pass over a paragraph that is emphasis whole, and end the sentence in the text after it.

**C503.** `tools/site/code_block.ern:167-173`, `isOneInput`: "a top-level `let` beside another declaration is more than one, and so are declarations followed by an expression", read from `paragraphs(lines)`, the lines between blank lines. A blank line inside a function's body makes the body's rest a paragraph of kind `Body`, so a block the shell takes as one input gets Copy alone. Appending to `guide/faq.md` a block `fn pair(value : Int) : #(Int, Int) = {` / `let doubled = value * 2;` / blank / `#(value, doubled)` / `}` writes `<pre class="code"><code>` with no `data-shell` (`S/readers/C501/out-inner-blank/faq/index.html`), where `fn double…` beside it gets `data-shell="paste"`. The rule applied is §11.2's reading of an `ern test` example (toolchain.md line 162), not what the shell takes, which is the whole paste (§11.2 *Inputs*). No block of today's pages is caught: the eleven Copy-alone `ernest` blocks of the guide, Why and the questions that name no file and hold an inner blank line each hold a top-level `let` beside declarations (guide 6, 7, Why's counter and operations), or are fragments or prelude blocks. `site/unrunnable.md` cannot catch an over-refusal, since the test runs offered blocks alone. Fix: a paragraph counts as a declaration or the body only where its first token stands at column 1 of its first line and is no closing delimiter, read from the lexer's positions the block is already lexed by; or the block is lexed once and split at top-level tokens at column 1.

**C504.** `tools/site/code_block.ern:156-160` ("as report §11.3 reads an example's") and `docs/design/site.md:224` ("which the generator reads from the block's paragraphs (report §11.3)"). §11.3 is *Configuration setup*; the paragraph rule is §11.2's, `report/toolchain.md` line 162, under `ern test`. Fix: cite §11.2 in both, and in the design note say the rule is `ern test`'s reading of an example.

## Clarity: the Ernest

**C505.** Exports nothing outside their module uses, kept from an earlier stage of the generator: `Html.html`, `Html.inline`, `Links.declaration` (`named` is what `Run` uses), `Run.committed`, `Template.tokens` (`fill` uses it; the test has its own regex). `export` says another module calls it. Fix: drop the `export` and the `///` of each; the same goes for the design note's *The templates* sentence where none reads it.

**C506.** `lifetime` names two things: `tools/site.ern:199-206` `Shell(lifetime : Int, warning : Int, within : Int)` are milliseconds, and `tools/site/run.ern:29-30` `Run(shellPath : String, lifetime : String)` is the spoken form, `5 minutes`. guide/style's glossary: `ms` for milliseconds. Fix: `Run.lifetimeText` (what `data-lifetime` carries), and the `Shell`'s three stay as the configuration names them, with their unit in the type's doc as now.

**C507.** `lines` names three things: a page's lines, `Template.Line` (the glossary's **Line**); `tools/site/book.ern:29` `Book.lines : Map(String, List(Markdown.Inline))`, each chapter's own line from the opening's list; and `tools/site/library.ern:21` `Library.lines : List(List(Markdown.Block))`, the README's items that name no group, the toolchain's. Fix: `Book.summaries` (or `chapterLines`, the function's name) and `Library.others` or `toolchain`.

**C508.** `Shown` is two types: `tools/site/links.ern:41` (how a document is shown, `Book | Numbered | Slugged | Whole`) and `tools/site/document.ern:32` (a placed block with its anchor). One concept, one name, in every module. Fix: `Document.Anchored`.

**C509.** `tools/site/links.ern:44` `type Owner = Report | Guide | Deployment | Bare`, "Whose section a `§` names". guide/style's glossary gives `owner` to the process a resource belongs to, and docs/code_style's **Owner** says "and nothing else"; `sectionWord` answers an `owner`. Fix: `Cited`, the document a `§` cites, `cited : Cited`.

**C510.** `tools/site/document.ern:28` `tested : Bool` chooses between `CodeBlock.placed` and `CodeBlock.copied` (`documentWritten`, line 73), where `tools/site/book.ern:68` takes the choice as `placing : (List(Markdown.Block)) -> List(CodeBlock.Placed)`. Two ways for one choice, and the one a `Bool` makes is what E.0 shape rule 9 refuses an exported function. Fix: `Document.placing`, as `Book` has it.

**C511.** `tools/site/html.ern:24-41` `body(blocks, shift, headed)`: "one for each heading in order; a heading past the list's end has neither an anchor nor a class". The parallel list is built four ways: `Document.paired` then `headed` (document.ern:78-81, 112-118), `Book.numberHeaded` (book.ern:264-270), `Library.declared`'s third component (library.ern:259-281) and `Report.blockLines` calling `Html.body([each], 0, [Headed…])` a block at a time (report.ern:112-127). A `Placed` that carries its heading's `Headed` (`headed : Optional(Html.Headed)`, set where `given` is) removes the pairing by position, `Document.Shown`, `paired` and the four builders. Shorter and clearer.

**C512.** Writers named as nouns beside writers named as participles: `Book.guide`, `Book.tour`, `Report.report`, `Library.library(run, library)`, `Document.documents`, `Document.projects` each write pages and answer `Either(String, Unit)`, while `Site.homeWritten`, `shellWritten`, `notFoundWritten`, `Run.pageWritten`, `Book.written`, `contentsWritten` do the same work under the participle. guide/style: a function that does something is a verb, and one concept one name. `Library.library` shares its parameter's name. Fix: `Book.guideWritten`, `tourWritten`, `Report.written`, `Library.written`, `Document.written`, `projectsWritten`, or verbs throughout.

**C513.** `tools/site/library.ern:176-225` `moduleWritten` finds the module's first sentence twice, `Run.described(module.path, blocks)` for the description and `Run.firstSentence(firstProse(linked))` for the `Row`'s purpose; and `moduleDeclarations` (line 71) runs `CodeBlock.documented` over every module's blocks to find the signatures, which `moduleWritten` runs again. Fix: the purpose's plain text is the description, `Html.plain(purpose)`, and the declarations are read from the `documented` the page keeps.

**C514.** Names that do not say what they hold: `tools/site/run.ern:147` `sidebar(…, found : List(Entry))`, `entries`; `tools/site/code_block.ern:62` `Walk.heading : Int`, "the count of the headings so far", `headings`; `tools/site/report.ern:19` `File.report : String`, the report's name, `name`; `tools/site/links.ern:34` `Declaration.page : String`, an address beside the type `Page`, `address`, as `Library.Module.address` is.

**C515.** `tools/site/links.ern:512-513` `github(tag, path)` writes `blob/` for a directory too: `examples/` becomes `…/blob/<tag>/examples`, which GitHub redirects to `tree/`. The design says "to the file on GitHub"; a link to a directory is one to the directory. Fix: `tree/` where `namedFile` found no README and the path names a directory, or say in the design note that GitHub redirects it.

**C516.** `tools/site/links.ern:141-155` `numbered`: where two numbered headings give the same digits, each is keyed by `slugBase`, the GitHub slug without the `-1` that `slugged` gives a second heading of one text; two such headings of one text would collide in `Map.fromList` without a word. No document has them. Fix: key by `slugged`'s numbered slugs, computed once for the document.

## Clarity: the shim, the templates, the test, the note

**C517.** `tools/site/ern_site.erl:1` "tools/site.ern's one foreign function": the `foreign fn lexed` is `Site.CodeBlock`'s, `tools/site/code_block.ern:555`. Fix the sentence.

**C518.** `site/templates/README.md:10` "`page.html` | a chapter of the tour, the guide or the report" and `docs/design/site.md:163` "every chapter of the tour, the guide and the report": a report page is a file whole (*The root*, line 46), not a chapter. Fix: "a chapter of the tour or the guide, a file of the report".

**C519.** `test/ern_site_tests.erl:285-299` `head/0` copies the working tree's `site/` over the export whole, an untracked file under it among them, and `-define(TAG, "52dd8971…")` dates every expected page from this checkout's history, so `make test-site` fails in a shallow clone or an export, which the header's comment does not say. Fix: copy the tracked files of `site/` (`git ls-files site`), and say in the header that the test needs the repository's history at that commit.

**C520.** `tools/site.ern:88-89` "The library's pages are written first, so that the pages it read go then, which every later collection of the run would otherwise copy": a why about the runtime's memory, which the design note's *The generation* does not state. The reason holds, since a later `let … <-` lambda captures `library` until its last use, but it is the design note's to own. Fix: one sentence there, the comment citing it.

## Security

Every text of a document reaches the page through `Template.escaped` (`Html.inline`, `CodeBlock.written`, `transcriptLine`, every `Plain` token), and every address a page writes is the generator's or escaped; `Links.resolved` refuses `..` above the repository and `Check.targetOf` keeps a `..` above the site as "no file of the site". No real exposure; one wrong link (C501) and two hardenings.

**C521.** Hardening. `tools/site/html.ern:65-66` `Markdown.Raw(lines) -> List.map(lines, Template.Verbatim)` and `tools/site.ern:474-489` `symbolOf` write a document's HTML block and an icon file's attributes and children into the page as they are. Today none reaches a page: the `<picture>` blocks stand before each title and `withoutContents` drops the markers, and the icons are vendored (`grep` over `R/build/site` finds no raw line). The design note's *The templates* ("A `*_html` token takes only HTML the generator makes from the repository") covers neither. Fix: the design note says an HTML block a document writes is written as it is, or `Html.html` refuses a `Raw` block that is not one of the two markers.

**C522.** Hardening. `tools/site/template.ern:158-163` `escaped` leaves `'`, so a value holds where every attribute is double-quoted, as every template and every element the generator writes is. Fix: say so in `escaped`'s doc, or write `'` as `&#39;` too.

## Where the language made the work harder

**C523.** `List.flatMap(lines, fn(each) = each)` stands 13 times across the generator (E.0 rule 4 refuses `List.concat` as a composition); `let _ <- List.tryMap(…)`, a failing `forEach` whose list is thrown away, 5 times (no `List.tryForEach`); a refusal's text is built by `<>` 8 times as `"cannot read " <> Path.toString(path) <> ": " <> Io.show(error)`, and a long one is laid one operand a line by `ern format` (`Html.heading`'s 14-line chain, `Run.copied`'s 7-line message) since there is no `String.format`; `String.toList` 17 times to walk characters (`Links.digits`, `textEnded`, `slugPiece`, `isTokenName`, `namesFile`), since `String` has no `span`, `takeWhile` or character at an index. CLAUDE.md's *Defects and gaps* sends a repeated form to `docs/language_feedback.md`; the first and the last two most.

**C524.** `Char` gives no Unicode category (E.6), so `tools/site/links.ern:258-280` refuses the site at any heading of Why, the questions, Install, Releases or Projects that holds a character outside ASCII that is no letter or digit: `### A question — with a dash` and `### What does §6.5 say?` appended to `guide/faq.md` each stop the build with "whose Unicode category its GitHub anchor turns on, which Char does not give" (`S/readers/C501/out-dash-heading`, `out-section-heading`). The design note states the refusal (*Anchors*), so it is decided; it stays here as the gap's cost: an em dash, a curly apostrophe or a `§` can stand in no question's heading until `Char.category` or `Char.isPunctuation` exists.

```
