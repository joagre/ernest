# Findings of the release review before 0.9.0

The review of 2026-11-02 over commit `09a01215`, run as [`release_review.md`](release_review.md) says: the fresh clone built and ran `make test-full` green in 13 minutes 33 seconds, after a first run found `docs/clean_room.md` naming the untracked reply file as a path; `make sections` empty; `make sanitize` green in 11 minutes, the helper changed; `make load` flat in 74 seconds; `make service` green; `make bench` three runs with the machine idle, in the log's entry.

Ten readers, the principles reader P on the most advanced model and the others on the one below, each a session of its own given its brief and its files: P and K over the report's diff since v0.8.0, K over the argument's changed paragraph too, N the newcomer, L and M the Erlang and the Gleam programmer, U the guide over what teaches the rules that changed, and the code's reader in four parts, C1 the runtime with its helper and S's questions, C2 the rest of the toolchain and the tests, E3 the standard library's, the shell's and the examples' Ernest, E4 the four new libraries and `Json`. Their lists are under *The lists*; a line names its reader's letter and number, C1-, C2-, E3- and E4- for the code's parts.

## The lines

A line is `fix`, made in the review's round; `decide`, with the user, the argument before the verdict; a milestone's number, planned there; or `dropped`, with the reason; and `done` with the date once made.

### The report's rules, the session

- P3, K13, E3-6 — E.14's prose, comment and code disagree on `join`: "each segment as given" against "a root first stays a root" and "the inverse of split", and an empty first segment makes the path absolute. fix: the prose states the root case and the empty segment, the comment loses "the inverse of split", the page shows `["", "b"]` and `".."`. done 2026-11-03.
- P6, K-C2 — E.1 states a constructor's fields in declared order twice. fix: once. done 2026-11-03.
- P7, K-C1 — E.5 states the whole-grapheme search twice. fix: one paragraph, both examples. done 2026-11-03.
- P10, K15, K-C7 — §11.2's two refusals, `could not start the shell` and `could not load the shell`, both the spawn's `Other(text)`, with no word on which comes when and what `text` is, and one node called "peer" and "node". fix: the first where the session's root ends before the session starts, its text the root's reason as `Io.show` writes it, the second where the spawn answers `Other`; "node" in both. done 2026-11-03.
- P12, K10 — Appendix F lacks the pseudo-terminal, the hangup and a listener's family, and its "taken namespace", "subscription" and "redundant" predate §4.2, §8.6 and §5.9. fix. done 2026-11-03.
- K1, K2 — E.18 says `connectTls` refuses a CA file it cannot read as `listenTls` does, and a directory answers what `Fs` answers; the code reads the file after the dial, so a closed port answers `Refused` and a directory the host's text. fix, with the runtime: the file is read before the dial, its errors as `Fs`'s (E.17, not E.1) and winning over the dial's; E.18 says so. done 2026-11-03.
- K4 — the argument's new paragraph says the caller of `Os.exit` dies with `ProgramEnd` as the rest do, and that the end waits on nothing that cannot come; a subscriber may kill the caller, and one that calls the caller forever never answers. fix: "killed or with `ProgramEnd`", and the second claim narrowed to the caller's own reply. done 2026-11-03.
- K7 — "the toolchain's own units" is never listed; the runtime takes the shell and `libs/ansi`, `libs/markdown` and `libs/ets`. fix: §12.7 lists them. done 2026-11-03.
- K8 — §11.7 covers no dirty tree at the tag, which the archive marks `.dirty`. fix. done 2026-11-03.
- K9 — E.17's `Invalid` misses a path longer than the host holds, and "the segment before its last" reads as one segment where any does, a trailing separator among them. fix. done 2026-11-03.
- K11 — G.11 writes `Version(2, 0)`, which does not compile. fix: named fields. done 2026-11-03.
- K12 — E.18's 3-minute bound against its new TLS sentence. fix: over TLS a close that queues behind bytes the far end has not taken has no bound but the runtime's end. done 2026-11-03.
- K16 — §4.2 does not say a program cannot name `Ernest.*`, and the diagnostic for it advises compiling `Ernest`. fix, with the checker: the sentence, and the diagnostic saying the name is the toolchain's. done 2026-11-03.
- K17, C2-6 — §4.2 and §11.1 place neither the shell's source root nor its build root, nor say which root provides which namespace; the standard library's root accepts `ernest.ern`. fix, with the cli: each root, its build root and its namespaces stated; `ernest.ern` refused under the standard library's root. done 2026-11-03.
- K18 — E.1's `NotLoaded` misses a toolchain unit the peer's tree lacks, and contradicts §12.7 on a faulting toolchain binding. fix. done 2026-11-03.
- K21 — E.18 is silent on whether `host` is sent as the server name and how an address is checked. fix: a name is sent and checked, an address checked against the certificate's addresses. done 2026-11-03.
- K22 — E.18 and §12.5 do not say which family a name that resolves to both gives a listener; `localhost` gives IPv4. fix: the family of the first address the host resolves it to. done 2026-11-03.
- K-C3 — E.23's list of what `run` is over lacks `kill`. fix. done 2026-11-03.
- K-C4 — G.10's "a 24th hour or a 60th second" and "written negative". fix. done 2026-11-03.
- K-C6 — G.11's "one of more words". fix. done 2026-11-03.
- K-C9 — §5.9's "the literal `false`": `(false)` is the literal, `!true` is not. fix: parentheses do not count. done 2026-11-03.
- K-C10 — E.23's "until the program that started it ends" names two programs with one word. fix. done 2026-11-03.
- U2 — a node's `listen` on an IPv4-mapped address is written by `ern config` and fails the node with a raw host term, where `Tcp.listen` answers `Invalid`. fix, with the cli: refused by `ern config --listen` and when the configuration is read; §12.5 and the deployment guide's §1.2 say so. done 2026-11-03.
- C2-5, E4-9, K20 — G.11 says a request line is "parted at spaces" where the code parts at runs of spaces and tabs, and the shim's comment claims a bare carriage return parts words, which the host refuses first. fix: "parted at runs of spaces and tabs"; the comment. done 2026-11-03.
- C2-7, E4-7, K20 — a status of two or four digits is read; RFC 9112 has three. fix, with the library: `Malformed` otherwise; G.11 says so. done 2026-11-03.
- E4-5 — a request carrying both `Transfer-Encoding` and `Content-Length`, or `chunked` twice, is read by the chunked coding and the rest answered for the next request: request smuggling for a keep-alive server. fix, with the library: `Malformed`; G.11 says so. done 2026-11-03.
- E4-12 — an RFC 850 two-digit year is decided by its year where RFC 9110 decides by its moment. fix, with the library: the moment; G.11 says so. done 2026-11-03.
- E4-20 — `Json.UnexpectedSequence` holds `Bytes` that are always UTF-8, shown as numbers. fix, with the library: a `String` field, `text`; G.6 and the page. done 2026-11-03.
- P8, E4-14, K-C5 — `Http.render` beside `renderRequest`, where every other pair names both kinds. fix, with the library and the examples: `renderResponse`; G.11; the server adapts at its next archive. done 2026-11-03.
- E3-5 — a negative time is clamped to none by the runtime, which no rule states; `snake.ern` clamps by hand. fix: shape rule 8 says a time below zero is none; the example's clamp goes. done 2026-11-03.
- P1 — §5.9 reads a guard that is the literal `false` and leaves `when true` and `if false then` unread, while principle 3 promises the reading for all three; built 2026-11-02 after the last review's P2. dropped, decided 2026-11-03: §5.9 stays as built, one literal refused for one reason, the sleep it would write back; `when true` and `if false` do what they say, as in every language the developer comes from; the argument in the log.
- P2, E3-4, C1-4 — `resize` once the program has exited answers `Right(Unit)` where `write` answers `Left(Closed)`; the order of its three answers is unstated, and a failed helper is to fault its callers but `NotATerminal` and `Invalid` are answered before the helper is asked. decided 2026-11-03: `Left(Closed)` after the exit or the hangup; `NotATerminal`, then `Invalid`, then `Closed`, the first two answered without the helper; E.23 the session's, the runtime agent R's. done 2026-11-03.
- P4, K6 — a read given no time answers what has arrived, E.18's own exception to shape rule 8, and the code gives it to `Os.read` too, which E.23 does not say. decided 2026-11-03: no exception, in `Tcp` and `Os` alike; E.18's sentence the session's, the shims agent R's. done 2026-11-03.
- P5, N2 — `Io.show` writes a constructor by its name alone, so the shell's echo `Timeout : Io.Error` cannot be typed back, a test compares against `"NotFound"`, and `Set.fromList([1])` prints qualified beside it. decided 2026-11-03: qualified outside the prelude, the full name the one form that resolves from anywhere, which MVP 4.15's item 6 does not change; E.1 the session's, the code and the golden outputs agent S's. done 2026-11-03.
- P9 — hex is `Bytes`'s and base64 a library's, one specification placed both ways. decided 2026-11-03: kept, the clause in shape rule 3, the session's. done 2026-11-03.
- K3 — once `Os.exit` began the end, one termination does nothing and a second cuts it short, with the exit's status; §8.6's "a second termination" can be read either way, and the status is unstated. decided 2026-11-03: a termination once the end has begun cuts it short whoever began it, the status the exit's where `Os.exit` began it and 143 where a termination did; §8.6 the session's, the runtime agent R's. done 2026-11-03.
- K5 — §10's new bullet says a value is reclaimed at the process's next collection; the host collects by generation, and a value that survived one goes at a full sweep. decided 2026-11-03: §10 states the two generations and that a process is collected as it allocates; item 1 measures first; the session's. done 2026-11-03.
- K14 — an evaluator and an exited program, or a socket whose far end closed, keep each other alive until the program ends, one pair per `Code.load`. decided 2026-11-03: E.28 counts a running program and an open connection; the session's and agent R's. done 2026-11-03.
- E4-6 — `parseResponse` refuses a folded header and `readResponseBody` refuses a last coding that is not chunked, where RFC 9112 has a client replace the fold and read to the close; G.11 states both without saying they depart. decided 2026-11-03: the RFC's way in a response, a fold replaced by a space and a last coding that is not chunked read to the close, the request's refusals kept; G.11 the session's, the library agent L's. done 2026-11-03.
- E4-8, K19 — `render` writes a header value holding CR LF as two headers, a method or target holding a space as is, and a body after 1xx, 204 or 304, each invisible to the writer. decided 2026-11-03: a fault for each; G.11 the session's, the library agent L's. done 2026-11-03.
- E4-10 — an empty line before a request line is refused where RFC 9112 has a server skip at least one. decided 2026-11-03: one skipped, two `Malformed`; G.11 the session's, agent L's. done 2026-11-03.
- E4-19, K-C5 — `Time.civil` beside `fromCivil` where shape rule 3 pairs `toX` with `fromX`, and `weekday` takes a time where a program holds a `Civil`. decided 2026-11-03: `toCivil` and `weekday(civil)`; G.10 the session's, agent L's; the server's access log names `Time.civil` and adapts at its next archive. done 2026-11-03.
- C1-3 — bytes in the kernel's send buffer escape E.18's bound and reset, since the closer reads the driver's queue alone. decided 2026-11-03: E.18 says so; the session's. done 2026-11-03.
- C1-6 — the closer samples the socket once a second, a chosen number. decided 2026-11-03: kept, a fifth of the window, derived and said; agent R's. done 2026-11-03.
- U12 — the manual pages are named `Ernest.X` while `Ernest.*` is the toolchain's namespace since §4.2, so the shell's would be `Ernest.Ernest.Shell`. decided 2026-11-03: kept, §11.4 saying the prefix is the manual's and no namespace and that the shell's modules have no page; the session's. done 2026-11-03.
- P11 — `listenTls` and `connectTls` where a constructor argument would do. dropped: decided in the log's *TLS in `Tcp` and a Terminal in `Os`*, shape rule 2's `closeListener` the precedent.
- S4 — a TLS handshake waits without bound until the program's read or close. dropped: E.18's design, the program's milliseconds bound it.
- K-C8 — a failed handshake's text carries the host's source position and changes with each OTP release. dropped: E.18 says the host's words.

### The guide, the tour, the questions, the argument and the README, one agent on the most advanced model

- U1 — guide §8.7 says a write waits while the far end takes its bytes; E.18 says the host takes a write whole. fix. done 2026-11-03.
- U3 — `guide/style.md` cites the guide's §5.4 for rebinding, which is §2.2. fix. done 2026-11-03.
- U4 — §5.9's literal `false` is not taught, and §2.6 says such a guard passes to the next clause. fix, after P1. done 2026-11-03.
- U5 — §8.6's end is taught for a termination alone: a return of `main` and an `Os.exit` tell the subscribers too, and the caller of `Os.exit` is not told. fix. done 2026-11-03.
- U6, M3, L1 — guide §7.1 drops "nor stand under one". fix. done 2026-11-03.
- U7 — TLS and a listener's family are not taught in §8.7. fix: one paragraph citing E.18. done 2026-11-03.
- U8 — `Os.startTerminal` and a running program as a wait are not taught in §1.3 and §5.4. fix. done 2026-11-03.
- U9 — deployment §6 names three attach refusals of §11.2's four. fix. done 2026-11-03.
- U10 — guide §7.1's teaching example parses HTTP by hand, from before G.11. fix: a domain that is no protocol. done 2026-11-03.
- U11 — `guide/style.md`'s glossary says "not `at`" where G.6's field is `at : Position`, and has no position. fix: `position` entered, `at` the field that holds one. done 2026-11-03.
- U13 — that a program's module hides a toolchain library is not taught. fix: one sentence in §7.1. done 2026-11-03.
- U14 — guide §3.2's `add1` against the style's own rule. fix: `increment`. done 2026-11-03.
- U15 — "for all of them of its family" in deployment line 42, §12.5 and E.18's comment. fix: "every interface of its family". done 2026-11-03.
- U17 — guide §8.2 says a message to a service away is lost where G.7 sends it to the last address held. fix. done 2026-11-03.
- M1, L3 — deployment §6's `r` is a placeholder nothing introduces. fix: "followed by the node's reason". done 2026-11-03.
- M6, M17 — a generic function must write `needs a.show` for an operation every type has, and the page does not say why. fix: one sentence. done 2026-11-03.
- M7, N8 — the FAQ's "`Address.call` is the prelude's too, so every receive is checked" does not follow. fix: the reason kept, the clause dropped.
- M8 — the FAQ offers `Reply` as a difference from Gleam's `Subject` where it is a likeness, and leaves out that a call answers `None` at its deadline where Gleam's panics. fix. done 2026-11-03.
- M9 — why.md presents the upgrade door as the claim where the hash is. fix: the door ordinary, the hash what finds the processes on old code. done 2026-11-03.
- M10 — the cost of a fix inside a loop's reach is stated last in tour chapter 8. fix: stated where chapter 6 introduces the door. done 2026-11-03.
- M11 — tour line 333 leaves a reader unable to say whether `Tally(Map.empty)` is a constant. fix. done 2026-11-03.
- M13 — tour chapter 7's two paragraphs on an artifact of connecting, chapter 6's four on the adapted address, two opening sentences of 90 words, and why.md's three paragraphs on what the runtime counts. fix where cheap: the sentences split, the artifact's paragraphs cut. done 2026-11-03.
- M14 — deployment §6's `chown -R` leaves unsaid that later edits are the superuser's too. fix. done 2026-11-03.
- M15 — guide line 890 drops "that is not polymorphic". fix. done 2026-11-03.
- M16 — the FAQ's "signatures optional" where a requirement is never inferred. fix: qualified. done 2026-11-03.
- L2 — deployment §4.2 and §6 disagree on what a node keeps of a shell's inputs. fix: §4.2 says an input's code goes as §6 says while its counts stay. done 2026-11-03.
- L4 — the FAQ maps `code_change` to the upgrade message without saying a restart runs the function the process was started with. fix: one sentence citing deployment §5.3. done 2026-11-03.
- L5 — a silent peer holds a local service down 45 to 75 seconds, said in §2.3 and a table cell alone. fix: why.md's WAN claim names the window. done 2026-11-03.
- L6 — whether a `foreign fn` at an attached prompt may reach the host's tools is unsaid. fix: the FAQ says it reaches any host function and nothing of Ernest's vouches for it. done 2026-11-03.
- L7 — a fleet moves to a new minor whole, said in deployment §5.1 alone. fix: the FAQ's WAN answer points at it. done 2026-11-03.
- L8 — the FAQ does not say what a child does instead of `terminate`. fix: nothing does; state the runtime does not own is lost. done 2026-11-03.
- L9 — "almost nothing" of the deadlock check's cost, with no number and no measure an installed user can run. fix: why.md names what is measured and the bench that measures it. done 2026-11-03.
- L10 — why.md's "goes to a peer with room" where the draw is the less busy of two at random, and the first compute before any utilization answers `Unreachable`, unnamed where `Peer.compute` is introduced. fix: both said. done 2026-11-03.
- L11 — a binding that is no constant does not cross and fails at run time with `NotLoaded`, unsaid in why.md's claim. fix. done 2026-11-03.
- L12 — §8.9 says nothing of processes old code spawns after the move. fix: one sentence. done 2026-11-03.
- L14 — a node reads every `.erc` beneath its program's directory, unsaid where a node is first started. fix: deployment §1.3. done 2026-11-03.
- L15 — processes a test started outlive it, unsaid. fix: guide §7.1. done 2026-11-03.
- L16 — the FAQ says no shared secret where `ps` shows a cookie; deployment §2.2 explains it. fix: the FAQ points there. done 2026-11-03.
- N3 — guide §0 says a failure cannot pass unseen, and one bound to a name never read does. fix. done 2026-11-03.
- N6 — guide §3.3's foreign `emptyMap` example beside the library's `Map.empty`. fix: a function of the program's own. done 2026-11-03.
- N7 — "no time given to a system module means no limit" where every wait takes milliseconds. fix: say which functions take no time. done 2026-11-03.
- N9 — "the same `ern`" in why.md and the guide where the floor is one minor release. fix: "the same floor". done 2026-11-03.
- N10 — two citations of §4.8, an exercise, for §4.3's rule. fix. done 2026-11-03.
- N11 — guide §1.4 opens on a fragment and its session cannot be run where it stands. fix. done 2026-11-03.
- N12 — "prelude", "node", "effect variable", `Killed`, `Never` and "the process behind each address" used before the text says what they are. fix: a clause at the first use; §3.5 opens on the effect variable. done 2026-11-03.
- N13 — five paragraphs open on what Ernest lacks. fix: each leads with Ernest's rule. done 2026-11-03.
- N14 — five sentences read three times. fix. done 2026-11-03.
- M4 — the central demonstration of the first claim shows nothing a `Subject` lacks; what the mailbox in the type buys is stated and never shown. decided 2026-11-03: the program shows the receive on another process's mailbox refused; the prose agent G2's. done 2026-11-03.
- M5 — "the closed set is what sets a requirement apart from a class" asserts the distinction four times and no program shows it. decided 2026-11-03: one sentence on what the closed set rules out, the FAQ and the README citing it; agent G2's. done 2026-11-03.
- M10, second half — `count2` in the tour and `examples/upgrade/v2` beside the style's "no variable's name ends in a number". decided 2026-11-03: the rule covers a function; the successor named for what changed in the tour, the example, §8.9 and `Code.load`'s page; agent G2's and the session's. done 2026-11-03.
- M12, L13 — a captured prompt binding does not cross, and what a later input needs of an old version must be bound before the reload: two rules taught as workarounds. decided 2026-11-03: stated as rules where the prompt's bindings are taught, the tour and why.md citing them; agent G2's. done 2026-11-03.
- L10, second half — `Unreachable` for a peer that has reported no utilization yet. decided 2026-11-03: kept; E.27 already says a peer with no utilization to use is `Unreachable`, and the guide's agent named it where `compute` is introduced. done 2026-11-03.
- N17 — a library function that waits must be a process and a call. dropped: decided, the mailbox in the type; the guide teaches it and the FAQ states the cost.
- N18 — order between senders. dropped: guide §4.5 states order per sender.
- N's seven names, `adapted`, `termination`, `makeFile`, `monitorService`, `until`, `under` and `Entry.user`. decided 2026-11-03, each searched across the report, the code and the guide: all kept: `adapted` is the log's *The Adapted Address*; `termination` names the event as E.23's subscriptions do; `makeFile` is `makeDir`'s pair; `monitorService` watches §6.5's service; `until` is the wait's word; `under` is the glossary's; `user` is the host's word for the owner.
- M2, L17, N4 — the README names 0.8.0 as the latest release. the release step.

### The runtime and its helper, one agent

- C1-1 — a program that exits by itself leaves its process group running, which E.23 says is killed with it. fix: the helper kills the group when it reaps. done 2026-11-03.
- C1-2 — `Verified` refuses a pinned far-end certificate that is not self-signed, which E.18 takes. fix: `unknown_ca` taken as `selfsigned_peer` is, where the file holds the certificate sent, the name checked; a test. done 2026-11-03.
- C1-5 — a terminal that cannot be made the program's controlling terminal is reported as the program failing to start, and `dup2` is unchecked. fix: the child says which step failed; the parent answers the terminal's failure; `dup2` through the failure path. done 2026-11-03.
- S1, S3 — `ernest.pid` is made group-writable under umask 002, and a group member's number is what `ern stop` signals; the lock follows links. fix: 0644 and `O_NOFOLLOW`; the node refuses a file not its caller's or that others may write. done 2026-11-03.
- S2 — `ern stop` and `ern reload` signal whatever holds the lock of a directory the node itself would refuse. fix: §12.5's directory and file check before the signal. done 2026-11-03.
- N1 — the trace of a `fault(...)` drops its caller frames where a host error keeps them. fix, after the diagnosis: the whole stack; a regression test. diagnosed 2026-11-03 as the emitter's, a fault emitted as a throw in place letting the host's type pass make its callers tail calls; built by the toolchain's agent. built 2026-11-03 by the toolchain's agent: a fault is a call of ern_rt:fault/1 in a try with an empty after.
- C1, tests — `tls_closed_socket_sends_what_it_took` waits 9 seconds where ssl's close takes 10; `piece_ahead_of_the_down_kept_test` rests on two senders' order. fix: the wait from E.18's bound; the order made explicit. done 2026-11-03.
- C1, names and leftovers — `failed[2]` shadows `failed`, three functions one; `arm` beside `write_limit`, a timer cancel spelled out three times, a waiting read a record here and a tuple there; `answered` ends the source unnamed; participles for functions that act; `is_taken`, `tls`, `inet` name no work; `server_name` and `reference` parse twice; a wrap broken at `%% alert's`; "A socket over TLS always is" no longer holds; `enotdir` redundant; the tree removal's comments and codes. fix. done 2026-11-03.
- K1, K2, the code — the CA file read before the dial, its errors `Fs`'s. fix. done 2026-11-03.

### The libraries and their primitives, one agent

- C2-1, E4-1 — `ern_json`'s search for a too-long integer is quadratic, a minute for 2.5 MB, and finds the digits inside a real. fix: compared only where a number begins, the number then skipped; a test with a real holding the digits. done 2026-11-03.
- E4-2 — a broken literal, `[t]` or `[tru, 1]`, answers the host's `UnexpectedEnd` with no position or the wrong byte. fix: the first byte that differs from the literal, at its offset; the host's quirk drafted for `docs/otp_bugs.md`. done 2026-11-03.
- E4-3 — `readHead` parses the head from its first byte after every read, quadratic for a client pacing small packets. fix: parsed again only where the new bytes hold a line feed. done 2026-11-03.
- E4-4 — the limit on all headers is found a line late. fix: the host given `min(line, headers - taken)` a line. done 2026-11-03.
- E4-5, C2-7, E4-7, E4-12 — as the report's lines say. fix. done 2026-11-03.
- E4-9, C2-5 — the shim's comment on a bare carriage return. fix. done 2026-11-03.
- E4-11 — `json.ern`'s tests cite no section. fix: G.6. done 2026-11-03.
- E4-18 — `<<59>>`, `<<10>>`, `<<13>>`. fix: the characters. done 2026-11-03.
- E4-20, P8 — as the report's lines say. fix. done 2026-11-03.
- E4-21 — `json.ern`'s page lacks a "Use it" paragraph, `See also` and a word on errors. fix. done 2026-11-03.
- E4-22 — the `Http` page leaves unsaid that a 1xx is read again with `carried` and that `Expect: 100-continue` waits for the server's 100. fix: two sentences; the chunked encoder and the target's decoding are feedback 210. done 2026-11-03.
- E4-23 — `fn version11()` beside `let testLimits`. fix. done 2026-11-03.
- C2-K4 — `Line`, `Headers` and `Count` in `ern_http`. fix: `LineLimit`, `HeadersLimit`, `Taken`. done 2026-11-03.
- C2-K5 — `white_space/1` and a sentence without its object in `ern_json`. fix. done 2026-11-03.
- C2-K7 — a test's comment records the approach set aside. fix: the reason alone. done 2026-11-03.
- E4-13 — `Http.header` beside the type `Header` and the field `headers`. dropped: `header(headers, name)` reads as the header named, and the module's one dodge is its own.
- E4-15 — `Parsed(head, rest)` against `#(Request, Bytes)`, and `BodyTooLarge` in `Error`. dropped: a read never answers `Incomplete`, and the type is shared with the body's read.
- E4-24 — `ern doc` from the root titles the page by its path. dropped: §11.1's single-file rule; `--source-root` names the root.

### The rest of the toolchain, the tests, the standard library's pages, the shell and the examples, one agent

- C2-2 — the archive's mark is read from the checkout after the build, a flake while the user edits. fix: read before and after, either accepted. done 2026-11-03.
- C2-3 — an expect holding a line feed is split and its second line dropped. fix: refused; the one site's `\n` dropped.
- C2-4 — the harness reads a control sequence two ways. fix: one parameter reader. done 2026-11-03.
- C2-8 — `free_ipv6_port` picks and closes a port before the node binds. fix: port 0 and `bound_port`. done 2026-11-03.
- C2-K1 — `taken_namespaces/0` is not §4.2's taken. fix: `given_namespaces`. done 2026-11-03.
- C2-K2, U16 — three forms for the refusal's owner. fix: "the standard library's namespace Io", "the prelude's namespace Int", "the toolchain's namespace Ernest"; the catalog written anew. done 2026-11-03.
- C2-K3 — `family_alone(none)` redundant; `listen_options/1` uncommented. fix. done 2026-11-03.
- C2-K6 — `http_scenarios/0`'s comment says a pair each. fix. done 2026-11-03.
- C2-K8 — the steps file has no reason since no shell reads the harness's arguments. fix: the steps passed as arguments. done 2026-11-03.
- C2-K9 — the harness's default size passed at four sites; `screen/3` and `pty/3` take a size in two shapes. fix. done 2026-11-03.
- C2-K10, C2-K11, C2-K12 — the harness's functions named as values; `Options.ms` optional and passed beside the options; the escape spelled two ways; "One step, the build."; `free_ipv6_port` a copy. fix. done 2026-11-03.
- K16, the code — the diagnostic for a program naming `Ernest.*`. fix. done 2026-11-03.
- K17, C2-6, the code — `ernest.ern` under the standard library's root. fix. done 2026-11-03.
- U2, the code — `ern config --listen` and the node refuse a mapped address. fix. done 2026-11-03.
- N5 — an error names one type variable with two letters. fix. done 2026-11-03.
- E3-1 — the shell's README and a comment name `detached` and `ended`. fix. done 2026-11-03.
- E3-2, E3-3, E3-7, E3-18 — `fetch.ern`'s authority ends only at `/`, an IPv6 literal fails, a missing CA file prints `NotFound`, the body limit is a bare number; `web_server.ern` cuts a cookie's value at its first `=`. fix; the parsing by hand is feedback 210. done 2026-11-03.
- E3-5 — `snake.ern`'s clamp of a negative time. fix, with shape rule 8. done 2026-11-03.
- E3-6, E3-9, E3-10, E3-11, E3-12, E3-14, E3-15, E3-16 — the pages: `Path.join`'s empty segment and `..`; `connectTls`'s garbled sentence; "`TERM` is not set"; `kill` after `Exited`; `close`, `listenTls`'s key, a handshake the far end closes and `connectTls` in `Tcp`'s module doc; `Code.load`'s table case; `Terminal` in `Os`'s see-also, `input` echoed, the hangup's order at `closeInput`; `Fs`'s "so does". fix. done 2026-11-03.
- E3-13 — `startRefusal`'s duplicate arm and repeated prefix. fix. done 2026-11-03.
- E3-8 — fifteen functions of the shell and `fetched` do something and are named as participles, beyond the three renamed 2026-11-02. decided 2026-11-03: `guide/style.md` says a function with an effect is a verb whatever it answers (agent G2), and the shell's fifteen and `fetched` are renamed (agent S). done 2026-11-03.
- E3-17 — `startTerminal` says it starts a terminal. dropped: shape rule 2's suffix, decided in the log.
- C2-8, second half — `tcp_tls_test` assumes nothing listens on port 1. dropped: a privileged port no user's program binds.

### Planned and felt

- E4-26, E4-27, E4-25 — `ern_http` runs the whole head loop in Erlang and `ern_json` its scans, where E.0 rule 1 has Ernest close the difference; `Base64.decode`'s strictness scan could be Ernest. MVP 4.15, item 8: the libraries' shims read against rule 1, each measured.
- E4-16, E4-17 — `Limits` and `Version` restated at site after site, the body's limit a bare `Int`. MVP 4.15, item 3, feedback 186.
- E4-29 — `Either.mapLeft(..., Http.Socket)` at eleven sites. MVP 4.15, item 4, feedback 185.
- E3-20 — 136 fully qualified sibling names in the shell. MVP 4.15, item 6, feedback 204.
- E3-19 — the shell's `foreign fn decoded`. MVP 4.15, item 7, feedback 206.
- E3-22 — `Os.Command` cannot set a program's environment or working directory; an editor under a terminal needs `TERM`. feedback 207. decided 2026-11-03: MVP 4.15, item 9, its form decided there. done 2026-11-03.
- E3-23 — nothing closes what a block opened on every way out of it; `fetch.ern` leaves its socket on each `Left`. feedback 208.
- N16 — a monitored worker's result or `Down`, in either order, written at five sites. feedback 209.
- E3-21, E4-22 — two examples parse a URL and a cookie by hand and get them wrong; `libs/http` has no chunked encoder and no target decoding. feedback 210.
- N15 — no temporary directory in `Fs` or `Os`, and `Test.equal`'s failure shows two values with no difference marked. feedback 211.
- E4-28, N20, L — a one-armed `if` for an effect writes `else Unit`, eight sites. feedback 212.
- K, language — `kill` takes an `Address` where `monitor` takes a `Process`. feedback 213.
- K, language, second — `match Tcp.port(l) { Right(p) -> p | Left(_) -> 0 }`. dropped: `Either.withDefault`.

### The round, K over the review's own diff, 2026-11-03

- R1 — §11.8 against §8.6 on the status of an end a termination cuts short. fix: the status of what began the end, in both. done 2026-11-03.
- R2, R27 — shape rule 3's reason for hex false, and "rule 2" ambiguous. fix: a spelling of the type's own content against a wire form; "admission rule 2". done 2026-11-03.
- R3 — `weekday` faulting where §7.4 answers `None`; the renderers' "program's own error" no term of §7.4. fix: `Optional(Weekday)`; the renderers' faults as §7.4's refused request. done 2026-11-03, agent L.
- R4 — the guide had a lambda's local crossing as a constant does. fix: as a value. done 2026-11-03.
- R5 — §12.7's set and a program's reach into it. fix: a program's reach crosses as any program's does, said; the name kept, Appendix F listing the set. done 2026-11-03.
- R6, R7 — E.23's helper exception lacked a write; shape rule 8 did not say "before any other answer", E.27 orders otherwise, E.17 silent. fix. done 2026-11-03.
- R8 — the argument cited §6.8. fix: §6.6 and §8.6. done 2026-11-03.
- R9 — E.1's example bare. fix: `Main.Snap`. done 2026-11-03.
- R10 — the style's effect split contradicted shape rule 2's verbs. fix: a function that does something is a verb; one that only computes is its value or shape rule 2's verb. done 2026-11-03.
- R11 — G.10 "over `civil`". fix. done 2026-11-03.
- R12 — `renderRequest` writing what `parseRequest` refuses. fix: refused alike. done 2026-11-03, agent L.
- R13 — §11.1's build roots stated twice. fix: once. done 2026-11-03.
- R14, R17 — §12.5's refusals without their texts or the superuser's exemption; the mapped address unbracketed. fix: §11.3 states the texts, the helper excepts the superuser, the example bracketed. done 2026-11-03.
- R15 — Appendix F's `hangup` one of two meanings. fix: both. done 2026-11-03.
- R16 — the FAQ cited the guide's §8.3. fix: report §11.2. done 2026-11-03.
- R18 to R28 — clarity: E.17's trailing separator, §10's "young", the guide's antecedents and wordings, the tour's constant, "those four", the claim's wording, the deployment guide's two sentences, G.11's "whose moment", §2.9's no-time functions. fix. done 2026-11-03.
- R29 — no ascription on an expression. feedback 218.


## The lists

### Reader P (the principles), release review before 0.9.0, read at 09a01215 (the report identical at 4ecd6a23)

§0 whole, then the report's diff since v0.8.0, each changed section whole. Appendix A, E.0 and §9 unchanged. Probes under readers/P/ (when_false.ern, when_true.ern, if_false.ern, when_and.ern, resize.ern, read0.ern, join.ern, show.ern, ernest.ern, ernest/shell.ern).

#### Defects

P1. §5.9, language.md:642: "A clause whose guard is the literal `false` is redundant whatever its pattern; a guard of any other form is not read for redundancy." Reads one spelling of a dead branch and leaves its two neighbors unread, while principle 3 promises the reading for all three. Shown: `x when false -> 1 | _ -> 2` refused; `x when true -> 1 | _ -> 2` compiles and prints 1 though `_` never runs; `if false then 1 else n` compiles though `1` never runs; the report silent on `if` with a literal condition. What it buys: a disabled clause written `when false` refused, which nobody writes but to disable a clause.

Fix, one of two: drop the sentence and read no guard (a literal guard a comment's job; §0's "text" means patterns); or read the three literals alike and state it in §5.8 too. The first is smaller; principle 5.

P2. E.23, library.md:789, `resize`: "once the terminal is hung up or the program has exited it sizes nothing and answers `Right(Unit)`", beside `write`, which answers `Left(Closed)` once the program has exited, and `resize`'s own `Left(NotATerminal)`. Shown by resize.ern: after `true` exited, resize Right(Unit), write Left(Closed), read Right(Exited(0)). A reader who knows write predicts Left(Closed). Principle 3: an operation that did nothing answers that it did; a caller's convenience is no reason (principle 5). Fix: resize once hung up or exited answers Left(Closed).

P3. E.14, library.md:548 and 557: the prose says `join(["root", "/x"])` is `Path("root//x")`, "written as it is", while the listing's comment says `Path.join : ... // the segments as a path, the inverse of split`. Shown by join.ern: `Path.split(Path.join(["root", "/x"]))` is `["root", "x"]`; `join(split(p)) == p` false. Fix: the comment says "the inverse of split for segments that are not empty and hold no separator".

#### Clarity

P4. E.18, library.md:668: "A read given no time answers the bytes that have arrived, and `Left(Timeout)` where none have", against shape rule 8 and §7.4 (a wait given none has run out as it begins), which Os.read, Fs.read, accept and Address.call keep. Shown by read0.ern. A poll that `Tcp.read(s, 1)` gives within a millisecond; the cost a second meaning of "no time" for one function (principle 2). Fix: drop the sentence, or make it every wait's in shape rule 8.

P5. E.1, library.md:258: "A constructor is written by its name alone, `File` for `Fs.File` outside its module as within it", against line 254 "each value as its literal or construction is written" and §4.2 (a module declaring its own `File` writes the other `Fs.File`). Shown by show.ern: in a module with `type Kind = File | Dir`, `Io.show(File)` and `Io.show(Fs.File)` both print `File`. Fix: line 254 says "as its construction is written in a module that hides nothing", or show qualifies a constructor of another module's.

P6. E.1, library.md:254 and 258: the first Io.show paragraph already states a named constructor with its fields in declared order, the new paragraph states it again. Fix: keep the new clause in the first paragraph, drop the restated half.

P7. E.5, library.md:365 and 367: the new "A search for a second string ... whole graphemes ... `"/"` is not in `"/\u{301}"`" and the primitives paragraph's "Every search matches whole graphemes: `String.contains("e\u{301}", "e")` is false" state one rule twice. Fix: one paragraph, both examples.

P8. G.11, library.md:1182–1183: `render(response, body)` beside `renderRequest(request, body)`, while every other pair names both kinds (parseRequest/parseResponse, readRequest/readResponse, readRequestBody/readResponseBody). Fix: `renderResponse`. Lesser: three verbs for writing a value as text, `Json.format`, `Http.render`, `Http.date` (a noun beside `parseDate`).

P9. G.8 beside E.20: RFC 4648 defines base16 and base64 in one document; hex is `Bytes.toHex`/`fromHex` in the standard library (shape rule 3, an encoding) and base64 a library's `Base64.encode`/`decode`. One specification placed both ways. Fix: name in E.0 which rule wins for an encoding, and place both by it.

P10. §11.2, toolchain.md:306 and 308: "`ern shell: the peer foo could not start the shell: text` where the session's root ends before the session starts" and "`ern shell: the node foo could not load the shell: r`"; both arrive as the spawn's Other(text) (§12.7, E.27) and the report does not say how the shell tells them apart. Fix: say what distinguishes them (a monitor's Down for the first, the spawn's Left for the second), or one line for both.

P11. E.18 as a shape: listenTls/connectTls beside listen/connect, four primitives where two and a type would do; shape rule 9's `render(doc, Plain)` has a reader predict `connect(host, port, Tls(verification), ms)`; shape rule 2's closeListener supports the suffix too; the choice is not stated. Not a defect.

P12. Appendix F got no line since 0.8.0 but "version text", though E.23 introduces the program under a pseudo-terminal and its hangup, and E.18 a listener's family and a socket's handshake (F's "handshake" is the carrier's alone).

#### Writing Ernest

None the language caused.

#### Kept for a reason an earlier milestone had

Nothing in the changed sections.

#### The counts

- Reserved words: 18 (§2.4), unchanged.
- Contextual words: 5 read by position (needs, derives, compare, negate, show) + 11 bitstring specifiers = 16; unchanged; the recorded 12 was counted another way.
- Taken top-level namespaces: Prelude 1, Address and Reply 2, standard library modules 27, Ernest 1 = 31 (30 at v0.8.0; the change is Ernest); the recorded 35 counted another way.
- Prelude (§9): 21 types; 18 functions that are values; 22 members that are no values. Unchanged.
- Standard library: 27 modules; 342 functions (338 at v0.8.0; new: Tcp.listenTls, Tcp.connectTls, Os.startTerminal, Os.resize); 25 listed types (24; new Tcp.Verification).
- Libraries: 10 under 11 sections, G.5 removed (6 under 7 at v0.8.0; new Base64, Crypto, Time, Http); 49 functions (29); 21 types (10; Json.Position and the new libraries' twenty).

#### Each changed rule, what it buys

§4.2 Ernest taken: a program's Shell meets nothing of the shell's; fine. §5.9 literal false: little (P1). §8.6 Os.exit's caller: necessary. §8.6 startTerminal a computation: necessary. §10 reclamation: fine. §11.1/§11.2/§12.7 the shell's root and a node that cannot load the shell: buys the truth; P10. §11.7 version text: fine. §12.5/E.18 family: fine. E.1 errors: fine; constructor by name alone P5, P6. E.5 graphemes: P7. E.14 join: P3. E.17: fine. E.18 TLS: P11; handshake/linger/endpoints fine; write as the host's send fine; read given no time P4; a read whose caller ended necessary. E.23: fine but resize after exit P2. E.28: fine. G.6: fine. G.8–G.11: P8, P9; Time's UTC-only policy fine.

### Reader K (the cold reader), release review before 0.9.0, read at 09a01215

Note: the brief's list of changed sections was off (E.0, E.4, E.12, E.19, E.21, E.27 untouched; §10, §11.7, E.5, E.14, E.28 changed and unlisted); every changed section was read. Programs under readers/K/.

#### Defects

K1. E.18 (library.md:652): connectTls does not refuse a CA file holding no certificate; `Verified(Path("/etc/hostname"))` or a key file is never refused: against a TLS server the handshake answers Left(Other("TLS client: ... Bad Certificate\n selfsigned_peer")) (tls3.ern), against a plain port Left(Timeout) (tls2.ern); the file is read only after the connection, so towards a closed port Verified(nope.pem) answers Refused, not NotFound; the order unstated. Fix: check the CA file as listenTls checks its files, before the dial; state the order.

K2. E.18 (:648): a directory as listenTls's certificate or connectTls's CA file answers Left(Other("/etc: illegal operation on a directory")), the host's text, where the report says what Fs answers (NotAFile); the citation says E.1 where Fs is E.17. Fix: NotAFile (and Invalid) as Fs; cite E.17.

K3. §8.6 (language.md:958), §11.2's ern stop: "a second termination" left to guess: once an Os.exit began the end and a subscriber holds its reply, one SIGTERM does nothing, only a second cuts the wait short, and the program exits with the Os.exit status (hold.ern); a node in this state ignores the first ern stop. The exit status when a termination cuts an exit-begun end short unstated. Fix: say whether a termination during such an end counts as the second, and the status.

K4. soundness.md's new paragraph: (a) "waits in the call ... until it dies with ProgramEnd as the rest do": a subscriber can kill the caller (exitkill.ern prints Down(reason = Killed), status 3); (b) "so the end waits on nothing that cannot come" holds only for the caller's own reply: a subscriber that callForevers the exit caller hangs the program until two terminations (exitwait.ern); §8.6's "no deadlock" and "the end's own answers are in flight" false there. Fix: "until it dies, killed or with ProgramEnd"; narrow (b).

K5. §10 (toolchain.md:22) new bullet "A value no process reaches any longer is reclaimed at its process's next collection" is false under the host's generational collector: a value that survived one collection goes only at a full sweep (fullsweep_after 65535; the runtime sets none); "until its next work" undefined. Fix: state the host's rule (young data at the next minor collection, old at a full sweep), or set the flag and say so.

K6. Shape rule 8 (library.md:224) against E.18 (:668) and E.23: rule 8 says a time below zero is none and a wait given none has run out as it begins; E.18 says a read given no time answers the bytes that have arrived; the code goes further (zero.ern): Tcp.read(s, -5) answers the waiting bytes; Os.read(p, 0) answers Stdout(...), which E.23 does not state. Fix: the exception in rule 8 and in E.23, or none. (= P4)

K7. §12.7, §8.7, F "toolchain's own units", §4.2: which units are the toolchain's own is never defined; the runtime picks the shell plus libs/ansi, markdown and ets (ern_code.erl own_builds/0), not json, proxy, http; a spawn whose reach is in Ets and one in Json behave differently between builds. Fix: list the set in §12.7.

K8. §11.7 (toolchain.md:468): a checkout at the tag with uncommitted changes uncovered; install.sh writes +commit.dirty. Fix: "or whose tree has uncommitted changes".

K9. E.17 (:613): a path of short names longer than the host holds is Invalid too (lib1.ern, 6000 bytes), silent; "a path whose segment before its last names anything but a directory" reads as the next-to-last only, while /etc/passwd/x/y and /etc/passwd/ are NotFound. Fix: "any segment before its last"; the trailing separator and the long path.

K10. Owners stale: F "taken namespace" (language.md:1484) lacks Ernest; "subscription" (F:1477) and E.23's termination paragraph (:800) end a subscription at death or restart only, lacking §8.6's "ends at the call" of Os.exit; "redundant" (F:1443) lacks §5.9's literal false. Fix: one clause each.

K11. G.11 (:1153): "Version(2, 0)" does not compile (named fields). Fix: Version(major = 2, minor = 0).

K12. E.18 (:660): the 3-minute bound against the new TLS sentence "the host sends on until the far end takes them"; which holds over TLS unstated. Fix: state the bound over TLS.

K13. E.14 (:546): the prose "each segment as given, one separator between them" makes join(["/", "etc"]) "//etc" where the code gives "/etc" (the comment's "a root first stays a root", unstated in prose); join(["", "x"]) is "/x" (principle 1). Fix: state the root case; decide the empty first segment. (= P3, E6)

K14. E.28 (:965) with E.23 (:794): an evaluator and an exited program's process, or a socket whose far end closed, keep each other alive until the program ends, one pair per Code.load. Fix: count only running programs and open connections, or state it.

K15. §11.2 (toolchain.md:306): "could not start the shell: text" where the case is now the session's root ending before the session starts; what text is goes unsaid. Fix: name it.

K16. §4.2: whether a program may name Ernest.* unsaid: `Ernest.Shell.Style.quiet` "unknown name"; `Ernest.Shell.main` "compile Ernest first, which Usesh uses: ernest.erc: no such file", advice §4.2 forbids (ns/usesh.ern). Fix: state it; the diagnostic says so.

K17. §4.2 and §11.1: the shell's source root and build root never placed (§11.1 gives build/stdlib only); which root may provide which namespace unsaid. Fix: state each root, its build root and its namespaces. (= C2-6)

K18. E.1 (:236) NotLoaded incomplete and contradicting §12.7: a toolchain unit the peer's tree lacks (§11.2, §12.7 answer NotLoaded) uncovered; a binding without a value NotLoaded while §12.7 makes a faulting toolchain binding Other. Fix: both cases.

K19. G.11 (:1163): render writes what parse refuses: `X: a\r\nSet-Cookie: evil` splits; a body after 204/304. Fix: refuse (state which) or state the caller checks. (= E4-8)

K20. G.11: `GET  / HTTP/1.1` (two spaces) parses; status of two digits parses. Fix: state or refuse. (= C2-5/7, E4-7/9)

K21. E.18: how connectTls uses host silent: a Verified connect to an IP checks the certificate's IP entry (passed against 127.0.0.1); whether host is sent as SNI unsaid. Fix: state both.

K22. E.18 and §12.5: which family a host name gives a listener: Tcp.listen("localhost", 0) took IPv4 only (fam.ern). Fix: state it.

#### Clarity

K-C1. E.5 restated (= P7). K-C2. E.1 restated (= P6). K-C3. E.23 (:774) "run over start, closeInput and read" should name kill. K-C4. G.10 (:1137): "a 24th hour or a 60th second" → "hour 24, second 60"; "is written negative" → "is negative". K-C5. Time.civil → toCivil; Http.render lopsided (= P8, E4-14, E4-19). K-C6. G.11 (:1155) "one of more words" → "more than three words". K-C7. §11.2 "the peer foo" vs "the node foo" for one node. K-C8. E.18: a failed handshake's Other(text) carries OTP's source position and a newline, changing with each OTP release. K-C9. §5.9 "the literal false": (false) counts, !true not; say parentheses do not count. K-C10. E.23 (:794) "until the program that started it ends": "program" names both.

#### Where the language made the work harder
- kill takes an Address, monitor a Process: `monitor(b, Gone)` with b : Address(Never) refused; Process.fromAddress needed (exitkill.ern).
- `match Tcp.port(l) { Right(p) -> p | Left(_) -> 0 }` repeated in every probe.

#### Kept because nothing broke: K-C1, K-C2, K-C3, K10.

### Reader N (the newcomer), release review before 0.9.0, read at 09a01215

Every exercise done and checked against §12. Program: `pindex`, a parallel inverted-index builder, 409 lines in four modules (index.ern, crawl.ern, pindex.ern, checks.ern) under readers/N/pindex/, using files and the test library; built, its tests passed (9 cases) and it ran. Probes under readers/N/ex/ (tr/tr.ern, tr/tr2.ern, p3.ern, p4.ern).

#### Defects

N1. The trace of a `fault(...)` drops every caller frame (guide §6.3 line 1766 says the trace ends with the program's outermost frame; holds for a host error, not for fault). tr2.ern: `worker3` does `first([]) + 1`, not a tail call, `first` calls fault; the output shows `Tr2.main:22 faulted: first of an empty list` / `Tr2.first:4` and no `Tr2.worker3`; the entry process the same (main -> worker -> first shows only Tr.first:4). `--emit-erl`: fault compiles to `erlang:throw({ern, fault, ...})`. Fix: keep the whole stack for a fault call, as for a host error.

N2. A constructor outside the prelude prints without its module, so the shell's echo cannot be typed back: `> Io.Timeout` prints `Timeout : Io.Error`; typing `Timeout` back is refused (`unknown constructor Timeout ... help: write Io.Timeout`); yet `Set.fromList([1])` prints qualified. The same in a Test.equal failure (`Indexed(file = ...)` for Crawl.Indexed), guide §8.1's `no foo: NotListed`, Fs.Entry's doc example (`kind = File`). The test had to compare against the string "NotFound". Fix: print a constructor as code outside its module writes it, or reword §1.1 line 126. (cf. P5)

N3. Guide §0 line 73: "A statement in a block must be Unit, so the failure cannot pass unseen", yet `let saved = Fs.write(Path("ro/x.txt"), <<1>>, 1000); Io.println("saved")` builds, prints saved, exits 0 (p4.ern); §11 principle 3 explains ("says nothing about what is merely unused"). Fix: "a statement cannot drop a failure; one bound to a name the code never reads is not reported (§11)".

N4. README line 121 "0.8.0 is the latest release" beside banners 0.9.0. (= M2, L17)

N5. One error message uses two letters for one type variable (p3.ern, Done takes Int, passed as spawnMonitored's wrap): `expected (Down) -> a, found (Int) -> Msg`, the signature under it `(Down) -> m`. Fix: name the variable as the signature shown beside it does.

N6. Possible leftover: guide §3.3 line 740's foreign `emptyMap` example beside the library's Map.empty; §8.1 line 2569 "so Map.empty is a let" reads as though it once was a function. Fix: an Ernest function of the program's own as the example.

#### Clarity

N7. Guide §2.9 line 624 "No time given to a system module means no limit", yet every Fs/Tcp/Os wait takes ms and §8.7 line 3049 says accept has no form without a time. Fix: say which functions take no time (Io.readLine, Io.read, ...) and that those wait without limit.

N8. faq.md line 7 "and Address.call is the prelude's too" against guide §2.9 line 611's definition of the prelude's names (usable without a module's name). Fix: drop the clause, or say the module Address belongs to the prelude. (cf. M7)

N9. why.md line 154 ("the same ern on the same OTP") and guide line 2511 ("the same ern under the same OTP") where line 2486 defines the floor as one minor release, any patch. Fix: "on the same floor".

N10. Guide §10 line 3275 and faq line 61 cite "(§4.8)" for "a request no clause takes waits in the mailbox"; §4.8 is the exercise; the rule is §4.3, the answer in §12. Fix: cite §4.3.

N11. Guide §1.4 line 228 opens on a fragment with no verb ("The tour's counter, counter.ern, whose type and loop are exported, run on a node started with none of its code."), and its session needs a and foo, which nothing there makes (only points at §8.1). Fix: "This session runs the tour's counter on foo ...; §8.1 makes a and foo first."

N12. Words used before the text says what they are: "prelude" (§0 line 75, defined §2.9 line 611); "node" (§0 line 37, defined §1.4); "effect variable" (§3.3 line 760, before §3.5, which never defines it plainly as the e of receiving e); Killed (§1.2 line 151, taught §5.2); Never (§2.2 line 327, taught §4.1); "the process behind each address" (§2.5 line 453, taught §5.5); "gives out the process's address through its type, as self does" (§4.1 line 855, unparsable). Fix: a clause at the first use; §3.5 opening with the definition.

N13. Paragraphs opening on what Ernest lacks: guide §2.3 line 361 ("There are no type aliases"), §10 lines 3279, 3280, 3287, 3288; faq line 7 opens on Gleam, line 9 on "Being the language buys what a library cannot". Fix: lead with Ernest's rule.

N14. Sentences read three times: guide 1166 "So does one that is no node at a hangup signal" and 2488 "a program that is no node" (better "a program run without --config-dir"); line 93 "the principle that nothing is invisible, a failure among it"; line 779 (a top-level let settling effect variables, too dense for §3); lines 1017 and 1496–1511 (where an adapted address's function runs); README line 125's install sentence of five clauses.

N15. Wanted and not found: (a) a scratch directory for a test: fixtures go into the working directory, so a second ern test run fails at Fs.makeDir with Exists; no temporary directory in Os or Fs; (b) a Test.equal failure that points at the difference: two 400-character tuples on one line, diffed by eye.

#### Where the language made the program harder

N16. The result-or-Down bookkeeping written once more for every monitored worker: a worker that returns sends its result and its Down comes in either order, so every waiter passes over Down(reason = Returned), records any other end, takes the result. Sites: guide §4.4 gather, §5.2 waitFor, §6.4 outcome (grep -c "reason = Returned" gives 3), §5.6 collect's pass-over, and Crawl.running: five. No prelude or library form runs f monitored and answers its value or its end. Candidate for docs/language_feedback.md.

N17. A library function that waits must be a process and a call: Crawl.crawl spawns a coordinator (waiting, plus Begin) and callForevers it, since a receive in crawl would impose CrawlMsg on every caller's mailbox; the guide teaches it (§4.4) and the FAQ admits the cost; two functions and a constructor the logic does not need.

N18. Order between senders made Index.add a call where a send would do (a worker's Added overtaken by main's later Lookup; order holds per sender); nothing in the types warns of the send-based version. Erlang has the same rule.

N19. A dropped Either bound to an unread name compiles silently (N3 from the program: the walk test's `let made = {...}` first never read).

N20. Small: `if String.isEmpty(word) then Unit else match ...;` needs the `then Unit` (no if without else); a fileOf helper that `outcome.file` makes needless (the reader's own miss of §2.4).

#### Names whose word could not be predicted, with the word expected

- `adapted(target, f)`: expected Address.adapt or Address.map.
- `Os.termination(wrap)` (subscribes): expected Os.onTermination or Os.subscribeTermination, as Terminal.subscribe.
- `Fs.makeFile` (writes only where the name is free): expected Fs.create or Fs.writeNew.
- `monitorService`: expected monitorRestarts ("service" already means §6.5's binding).
- `Test.until`: expected Test.eventually.
- `Path.under(root, path)`: expected Path.within or Path.safeJoin.
- `Fs.Entry.user`: expected owner or uid.

#### The program

Built (each module ~0.8 s), `ern test ../build` 9 passed, the run indexed 4 files, 13 words in 17 ms, wrote out.txt, answered lookups; usage exit 2; a missing directory "cannot list nodir: NotFound" exit 1. Surprises: the one-frame trace (N1); every module compiled on its first build (Int.max, Fs.Directory existed where guessed). Sources under readers/N/pindex/.

### Reader L (the Erlang programmer), release review before 0.9.0, read at 09a01215

Scratch under readers/L/; nodes stopped.

#### Defects

L1. guide/language.md:2056 (§7.1): the taken-namespace rule stated more narrowly than enforced; the compiler refuses namespaces under the standard library's and under Ernest (`io/extra.ern`: "stands under the standard library namespace Io"; `ernest/tool.ern`: "stands under the toolchain's namespace Ernest"). Fix: "or one beneath it", `ernest/shell.ern` the example. (= M3, U6)

L2. deployment §4.2 (line 230) against §6 (line 343) on what a node keeps of a shell's inputs: §4.2 "A node keeps every unit of code it loads ... the ones a program or a shell attached to it loaded, for its life", and "each input a unit (section 6), moves them"; §6 "`b` lets an input's code go ... once its answer is in, where the input neither declares nor builds a function value". Fix: §4.2 says an input's code goes as §6 says while its counts stay.

L3. deployment §6 (line 341): placeholder `r` undefined; §7 defines Site, Q, M, N. Fix: write "followed by the node's reason" or define r. (= M1)

#### Clarity

L4. Restart and hot upgrade do not compose; where L would close the page. FAQ:19 maps code_change to the message carrying the new loop, not saying a process under restarting/Supervisor moved so goes back to the old loop at its next fault (tour:468, deployment §5.3:277). Fix: FAQ:19 says in one sentence that a restart runs the function the process was started with, citing deployment §5.3.

L5. A silent remote peer holds a local service down 45 to 75 s, no setting changes it (deployment §2.3 ~180, §7 table line 357); why.md and FAQ never mention it under the WAN claim. Fix: why.md's WAN claim names the window and points at §2.3.

L6. No tracing, no observer, no sys (FAQ:19, FAQ:103), and the docs do not say whether a `foreign fn` at an attached prompt may reach the host's tools: `foreign fn info(item : Foreign.Term) : Int = "erlang:system_info/1"` works; `dbg:tracer/0` accepted. Fix: one FAQ sentence on what a foreign fn at an attached prompt may and may not do.

L7. A new minor of ern or a new OTP major stops the whole fleet (deployment §5.1:261, §2.2); before 1.0 every release is a minor; why.md's WAN claim and the FAQ's WAN answer silent. Fix: one line in the FAQ's WAN answer pointing at §5.1.

L8. FAQ:25-27, guide §6.6 (1980): a sibling that never waits is never restarted; with OneForAll a runaway sibling keeps a faulted child down for good (OTP's brutal_kill); and "a child is killed, not asked to stop" leaves unanswered how a child flushes a buffer when its supervisor dies. Fix: the FAQ names what a child does instead of terminate, or says nothing does.

L9. What does Ernest cost over Erlang: README:106 and why.md:416 give no number, and an installed user cannot run make bench. Measured (readers/L/benchdir/bench.ern vs b.erl, loaded machine): 100,000 spawns 0.88–1.1 s vs 0.17–0.23 s (~5x); 100,000 calls 0.23–0.5 s vs 0.12–0.2 s (~1.5–2.5x); spawns cost the same under --config-dir. Fix: why.md gives the measured ratio or says what "almost nothing" is measured against.

L10. The compute demo is arranged to work (tour:509, 524-526, why.md:10, 165): tour ch. 7 warms up with computeAt on both peers; without it the first Peer.compute answers Left(Unreachable) while computeAt reaches the peer (readers/L/nodes/main.ern). The error's name says unreachable when no utilization has been reported yet; "goes to a peer with room" is not what the page shows (all three went to foo; with two peers the draw is fixed); whether a compute is retried elsewhere unsaid. Fix: why.md:10 says "the less busy of two drawn at random", and the Unreachable case named where Peer.compute is introduced.

L11. Code that crosses fails with a bare Left(NotLoaded), the reason on the other machine (tour:333, 530, deployment §4.1): `export let empty : Tally(String) = Tally(Map.empty)` used in a compute on foo answers Left(NotLoaded); foo's stderr says "the binding Tally.empty has no value here". Nothing refuses it at build time. Fix: why.md's code-by-hash claim says a non-constant binding does not cross and fails at run time.

L12. Hot upgrade's ceremony (tour:578-580, guide §8.9 line 3182, examples/upgrade/v2): every fix a count2 beside count, kept until Code.running(count) is empty on every node, which no document says how to check; Code.running sees only processes whose stack holds the frame now; processes old code spawns after the move uncovered. Fix: one sentence in §8.9 on processes spawned after the move.

L13. After :reload the old process is reachable only if prepared beforehand (why.md:129-150): "what a later input will need of the old version is bound before the reload" is a workaround as prose; confirmed (send(old, Counter.Inc(1)) refused; Address.call(old, oldGet, 1000) bound before works). The refusal's help does not say so.

L14. A node reads every .erc beneath its program's directory, unlike ern run without a configuration (deployment §5.1:263): `ern run --config-dir nodes/a bench.erc` refused for an unrelated nodes/main.erc: "nodes/main.erc holds Main, not Nodes.Main". Fix: say it in §1.3.

L15. Tests share a node (tour:349: the first test's counter outlived its test and is in the second's deadlock trace). Fix: guide §7.1 says processes a test started outlive it.

L16. why.md:11 and FAQ:83 say no shared secret, yet ps shows -setcookie <hex>; only deployment §2.2 (166) explains the cookie is the public floor digest. Fix: FAQ:83 points at §2.2.

L17. README:121 "0.8.0 is the latest release". (= M2)

#### Shows what Erlang cannot: typed sends and receiving functions refused before the run; deadlock trace under run and test (off a node); code by hash to a bare node; Peer.spawn refused for a node-bound mailbox; foreign returns checked; per-key TLS, no epmd; Code.running typed.

#### Restates Erlang: restarting/Supervisor minus brutal_kill and shutdown; Address.call = gen_server:call, None covering timeout, fault and dead callee alike (dead calls answer at once, readers/L/dead_call.ern); 45–75 s = net_ticktime; 1 MB buffer = busy_dist_port; unbounded mailboxes; Ets; no pg; global = first peer in configuration order.

#### Language made programs harder: little. `let _ =` to discard a spawn's address; `if ... then fault(...) else Unit;` clumsy; the friction was tooling (L11).

#### Kept for a removed reason: none.

Verdict: convinced by mailbox types with code by hash and the deadlock trace; would try for a new small distributed tool; not a production WAN service yet (L4, L5, L6, L7).

### Reader M (the Gleam programmer), release review before 0.9.0, read at 09a01215

#### Defects

M1. guide/deployment.md §6, the attach-failure paragraph added since v0.8.0: "`ern shell: the node b could not load the shell: r`, with the node's reason". The `r` is a bare placeholder that nothing introduces; the other messages in the same paragraph are quoted literally. Fix: write the line with a real reason, or with a placeholder the text names.

M2. README.md:121: "0.8.0 is the latest release". Every banner prints `Ernest 0.9.0`. Fix: change it in the release commit.

M3. guide/language.md §7.1, the changed sentence: "A module may not take a namespace the prelude or the standard library has, nor `Ernest`, the toolchain's own, so `io.ern` and `ernest.ern` at the root are refused". The toolchain also refuses every namespace under these (`ern build ernest/foo.ern`: "stands under the toolchain's namespace Ernest"; `io/foo.ern`: "stands under the standard library namespace Io"). Report §4.2 says "with every namespace under it"; the guide drops that. Fix: add "or one under it", with `ernest/shell.ern` as the example.

#### Clarity

M4. The central demonstration of the first claim (README.md:46-70, guide/why.md:61-85, tour/README.md:63-72), `count` called by a `main` whose mailbox takes another type is refused, shows nothing Gleam's Subject lacks: in Gleam the loop takes its `Subject(CounterMsg)` as an argument, so a caller holding a `Subject(OtherMsg)` is refused too. What the mailbox-in-type buys is stated but never shown: a receive on a Subject another process owns (Gleam catches at run time); a spawn handing back a typed address with no handshake; the refusal of `Peer.spawn` for a node-bound mailbox (tour ch. 6 shows). README line 102's "the compiler checks every message against the mailbox it will reach" is what Gleam does. Fix: show the one mistake a Subject lets through and Ernest refuses.

M5. The case that a requirement is "not a class" rests on one sentence, "the closed set is what sets a requirement apart from a class", stated four times (why.md:12, why.md:326, faq.md:99, README bullet). On the page: closed set of requirements, open set of types meeting one (`fn T.compare`, `derives compare`), compiler supplies the operation at each call, one `compare` per type in its module. To a Gleam reader that is a type class with built-in classes and user instances, orphan rule included; Elm's `comparable` opened to user types. docs/man/stdlib/ordered_set.md:25: a reversed order of strings needs a wrapper type with its own `compare`, Haskell's `Down`. What would convince: no class can be declared, so no tower of abstractions. Fix: say what the closed set rules out.

M6. why.md:12 and :326, faq.md:99: "`show`, which is no member but every value's through `Io.show`". `fn shown(x : a) : String = Io.show(x)` is refused ("Io.show needs a.show, which shown does not declare"); with `needs a.show` it accepts every type, functions included (`<function>`). The requirement can never fail yet must be written, and the page does not say why. Fix: one sentence saying a generic function writes `needs a.show` and what that buys.

M7. faq.md:7: "`spawn` and `monitor` are the prelude's ... and `Address.call` is the prelude's too, so every spawn and every receive is one the compiler checks". The "so" does not follow. Fix: drop the prelude clause, keep the reason (the mailbox in the function's type).

M8. faq.md:9: "Gleam's `Subject` is a value a process makes; the one channel an Ernest program makes is a `Reply`, which a caller makes and hands over in its request." To a Gleam reader a `Reply(Int)` is a reply Subject and `Address.call` is `process.call`. Offers a likeness as a difference. A real difference unmentioned: Ernest's call answers `None` at its deadline where Gleam's panics. Fix: say the likeness plainly and name the real difference.

M9. why.md:98-125, "Code known by its hash": the upgrade door `Upgrade(next)` with a tail call is plain closures in a message, which any Gleam actor can write. The hash enters only at `Code.running` and versions side by side; tour ch. 8 shows it. Fix: say the door is ordinary and the hash is what lets a program find the processes on old code.

M10. tour/README.md:578-580: a fix inside `count`'s reach changes `count`'s hash and `Code.running(count)` finds none. Every fix to a running loop is a new top-level loop, the old loop with every callee byte-identical until no node runs it. Stated as the last paragraph but one of ch. 8. Fix: state it where ch. 6 introduces the door. Related: `count2` (tour, examples/upgrade/v2) beside guide/style.md's new "No variable's name ends in a number"; a reader cannot tell whether the rule covers a function.

M11. tour/README.md:333, why `empty` is a function: "`Map.empty` ... on every node" yet it is no literal; unclear whether `Tally(Map.empty)` would work on `foo`. Fix: say outright whether that binding is a constant, and why not.

M12. tour/README.md:530: after `let below = 200000`, `Peer.compute(fn() = Counter.primes(below), 5000)` answers `Left(Io.NotLoaded)`; the tour teaches `{ let n = below; ... }` as the way through. A captured local crosses, a captured prompt binding does not: a workaround written in prose. Fix: decide it as a gap, or state the rule where the shell's bindings are taught.

M13. Too long: tour ch. 7 lines 524-528 (why `bar` reads 0.25); tour ch. 6 lines 462-468 (adapted address's extra hop); tour/README.md:13 and :17 (single sentences of 90+ words); why.md:410-416 (what the runtime counts).

M14. guide/deployment.md §6, the new `chown -R` sentence leaves unsaid that every later `--peer-dir` and `ern reload` of `b` needs the superuser again; section 8's reload step shows `ern config --config-dir b --peer-dir d` with no `sudo`. Fix: one clause.

M15. guide/language.md:890 (unchanged): "A top-level `let`... must have its type settled" drops the "that is not polymorphic" qualifier line 760 has; tour ch. 5's `let countsPerKey : Test.Case(m)` looks like a contradiction. Low.

#### Where the language made the programs harder

M16. faq.md:35 "types inferred with signatures optional", yet `fn sorted(list) = List.sort(list)` is refused ("sort needs a.compare, at a type variable no requirement can name"), the help says annotate. why.md says a requirement is never inferred; the FAQ reads unqualified.

M17. As M6: `needs a.show` must be written for an operation every type satisfies.

#### Chapter by chapter

Shown and new: code crossing to a bare node, the deadlock fault with waiting-process lines, the foreign return check (`foreign fn systemTime() : String` faults "the return of foreign function erlang:system_time/0 does not match String"; why.md and tour ch. 7 assert rather than run it). Only asserted: claim 1 against a Subject (M4), requirement against class (M5). Ch. 1 same as Gleam apart from M4; ch. 2 two key files, no cluster, code crossing; ch. 3 nothing new; ch. 4 `restarting` keeping the address; ch. 5 deadlock in a test, reload refusing an old protocol; ch. 6 the cost of one mailbox type shown honestly; ch. 7 compute placement; ch. 8 strongest, its cost (M10) late. FAQ fair; M7 and M8 not believed.

Convinced by: the deadlock fault; a spawn carrying its code to a bare node and the attached shell moving a running counter; the foreign-answer check. Would try it for a program that spans nodes; would not move a single-node Gleam service.

### Reader U (the guide), release review before 0.9.0, read at 09a01215

Scratch programs under readers/U/.

#### Defects

U1. guide/language.md §8.7, line 3053: "A write returns once the socket has taken its bytes, and waits while the far end is behind taking them" is false since E.18 changed: the host takes a write whole, the milliseconds bound only the wait behind earlier writes. Shown by readers/U/wr.ern: a 10 MB write to a far end that never reads answers Right(Unit) in 1 ms; the next 1-byte write Left(Timeout) in 105 ms. Fix: "A write returns once the host has taken its bytes, whatever their size, and waits, within its milliseconds, only behind earlier writes the far end has not yet taken."

U2. §12.5, E.18 and code: `Tcp.listen("::ffff:127.0.0.1", 0)` answers Left(Invalid) (checked, readers/U/mapped.ern), but `ern config --config-dir n1 --listen '[::ffff:127.0.0.1]:0'` writes it and exits 0, and `ern run --config-dir n1` fails with a raw host term: `ern run: the node's carrier did not start: {{shutdown,{failed_to_start_child,net_kernel,{'EXIT',nodistribution}}},...}`. A port in use gets `its listen address 127.0.0.1:47123 is in use`. §12.5 says nothing of a mapped listen; deployment.md §1.2's list of refused files does not name it. Fix: refuse it when the configuration is read and in `ern config --listen`; the sentence in §12.5 and the line in deployment.md §1.2.

U3. guide/style.md line 19: "which the language guide's §5.4 provides" — §5.4 is Deadlock; rebinding is the guide's §2.2 ("Shadowing is allowed", line 311), report §4.6. Fix: cite §2.2.

U4. §5.9's literal-false rule is not taught: guide §2.6 line 548 says "A guard that is `false` passes to the next clause"; §2.3 line 345 gives as the only reason a clause can never match the clauses above it. Shown by readers/U/g.ern: `0 when false -> 1` refused in match and receive; `k when !true` accepted. Fix: in §2.6, "A clause whose guard is the literal `false` can never match, and is refused as §2.3's is; no other guard is read for it."

U5. §8.6's end and Os.exit taught only for termination: §4.5 line 1166, §8.2 *The end*, §9.2 line 3215 say the subscribers are told at a termination; none says a return of main or an Os.exit tells them, nor that the caller of Os.exit is neither told nor waited for. Shown by readers/U/ex.ern. Fix: in §8.2's *The end*, "every end tells them, a return of `main`, an `Os.exit` and a termination alike, except that the caller of the `Os.exit` that began it is not told".

U6. guide/language.md §7.1 line 2056 drops §4.2's "nor stand under one". `ern build ernest/foo.ern`: "stands under the toolchain's namespace Ernest"; `fs/entry.ern`: "stands under the standard library namespace Fs". Fix: "...may not take, nor stand under, a namespace...; `io.ern`, `fs/entry.ern`, `ernest.ern` and `ernest/shell.ern` are refused". (= M3)

U7. E.18's TLS and the listener's family not taught: §8.7 *Sockets* never says listenTls/connectTls give sockets served by the same functions, nor that a listener takes its own address's family alone (a server for both opens "0.0.0.0" and "::" on one port). Fix: one short paragraph after the example, citing E.18.

U8. E.23's terminal not taught: §1.3 line 202 names Os.start alone; §5.4 line 1450's list of what a process can wait for lacks a running program (§8.6 counts startTerminal). Checked code against E.23 in readers/U/pty.ern (stty size 24 80 CR LF; resize on a piped program Left(NotATerminal)). Fix: a clause in §1.3 and "a program it started" in §5.4.

U9. guide/deployment.md §6 line 339 names three attach refusals; §11.2 has a fourth, `ern shell: the peer foo could not start the shell: text`, whose condition changed this release. Fix: add it.

#### Clarity, and things a later rule left behind

U10. guide/language.md §7.1 lines 2017–2033 and 2054: the teaching example writes its own `Net.Http.Request` and `Net.Http.parse("GET /")`, naming `http/parser.ern`; G.11 ships Http.Request and parseRequest, and the guide's §8.5 says a protocol belongs to a library. A leftover from before G.11. Fix: move the example to a domain that is no protocol, e.g. `shop/order.ern`.

U11. guide/style.md's glossary says "**index**: ... Not `at`"; G.6's new field is `at : Position`; no glossary entry for a line-and-column position (G.6 and §11.5). Fix: decide the name; add `position`/`at` or rename the field.

U12. Manual-page names against the taken `Ernest` namespace: guide §9.1 line 3208 (`man Ernest.List`), restating toolchain.md's *Manual pages*: every page `Ernest.` + module. Since §4.2 `Ernest.X` is the toolchain's; `Ernest.Net.Http(3ern)` reads as a namespace no program may have; the shell's page would be `Ernest.Ernest.Shell`. Fix: the report decides the prefix; the guide follows.

U13. That a program's module hides a toolchain library is not taught (§4.2's last paragraph; G.8–G.11 add Time, Http, Crypto, Base64). Shown by readers/U/hide/: a program's own time.ern makes `Time.weekday(0)` "unknown name Time.weekday". Fix: one sentence in §7.1.

U14. guide/language.md §3.2 line 694: `let add1 = fn(x) = x + 1` breaks style.md's new "No variable's name ends in a number". Fix: `increment`.

U15. guide/deployment.md line 42: "for all of them of its family" awkward, copied from §12.5; E.18's signature comment the same. Fix: "every interface of its family".

U16. §4.2's refusal texts worded three ways: "takes the standard library namespace Io", "takes the prelude namespace Address", "takes the toolchain's namespace Ernest". Fix: one form.

U17. guide/language.md §8.2 line 2883: "A message that comes while the service is away, and whose find fails, is lost as a message to an ended process is" — G.7 says it goes to the last address held and reaches the service where its node is back. Fix: "...goes to the last address held, and is lost unless that node is back".

#### Where the language made the work harder

None. (`Bytes.fromList` answers an Optional; `Os.Exited` written with its module's name.)

### Reader C1 (the runtime, with S's questions), release review before 0.9.0, read at 09a01215

Probes under readers/C1/ (group.ern, pin/pin.erl, pin/exp.erl, kq.erl, hostile/). A `sleep 300` it left was killed by its number.

#### C: defects

C1-1. A program's process group outlives it once the program exits by itself: ern_exec.c:996-1006 after reaping sends 'x' and returns without kill(-program, SIGKILL); E.23 says the group is killed with it and run leaves no process behind. Shown by group.erc: `Os.run(Command("sh", ["-c", "sleep 300 > /dev/null 2>&1 & echo $!"]), 5000)`; after ern run returned, sleep 300 still ran in the program's group. Same under a terminal for a member ignoring the hangup. Fix: after 'x' the helper waits for fd 0 to end and kills the group, or kills the group when it reaps; else E.23 reworded.

C1-2. `Verified` refuses a pinned far-end certificate that is not self-signed: ern_tcp.erl:310-327 verify/4 takes a held certificate only on {bad_cert, selfsigned_peer}; E.18 says "where the file holds the far end's own certificate, self-signed or not"; a leaf signed by a CA the file lacks reaches verify/4 as {bad_cert, unknown_ca} and fails (pin/pin.erl: `{error,{tls_alert,{unknown_ca,...}}}`). The test covers self-signed only. Expired pinned self-signed still refused (fine). Fix: treat unknown_ca as selfsigned_peer when the file holds the certificate as sent, name checked; else the report says "self-signed, a CA or not".

C1-3. Bytes in the kernel's send buffer escape E.18's bounds and reset: close_socket/2 and lingering/5 (616-663) read send_pend, the driver's queue only; a write that fits the kernel buffer leaves send_pend 0, the socket closed plainly, the kernel sending on as an orphan (kq.erl: after 64 KB to a far end never reading, send_pend 0; after close + 7 s, ss shows FIN-WAIT-1 holding 61441 bytes, no reset). Fix: watch the kernel's queue (TCP_INFO / SIOCOUTQ via raw getopt), or E.18 states the host's handling of the kernel's buffer.

C1-4. Resize after the helper has failed answers instead of faulting: ern_os.erl:467-482 resize/4 and 491-493 over/2: E.23 says once the helper fails the caller of resize faults; in over/2 a start-started program answers Left(NotATerminal), an out-of-range size Left(Invalid); the comment "whatever the program's state" unstated by the report. Fix: fault every resize in over/2, or the sentence in E.23.

C1-5. A terminal that cannot be made the program's controlling terminal is reported as the program failing to start: ern_exec.c:755-756 setsid()/ioctl(TIOCSCTTY) failure goes through child_failed's 'f' path, EPERM becoming Left(Denied); the header says 't' reports the terminal's failure. dup2 calls unchecked in both branches. Fix: the child sends which step failed; the parent answers 't' for the terminal steps; dup2 failures through child_failed.

C1-6. The closer polls on a chosen number: ern_tcp.erl:52-54, 651-655 LINGER_CHECK 1000, a fixed sleep the report does not state (*No fixed sleep*); makes the 5 s bound 5 to 6 s and holds a drained socket up to 1 s. Fix: wait on the report's own 5 s window sampling send_pend at its end; prim_inet:subscribe(S, [subs_empty_out_q]) would wake at the drain but is undocumented (the user's word).

#### C: tests that can fail under load

- `piece_ahead_of_the_down_kept_test` (ern_os_tests.erl): needs the fake 'o' frame to reach the suspended program process before the reader's DOWN, two senders Erlang does not order; works by the BEAM's causal delivery on one node.
- `tls_closed_socket_sends_what_it_took`: `gone(HostSockets, 9000)` shorter than the 10 s ssl's close waits; fails any run where ssl:close takes them.
- `evaluators_outlive_no_ending_process` 5 s for 400 evaluators; terminal_kill_test and wait/1 helpers 5 s each: failure bounds, extreme load only.
- `terminal_test` relies on sh echoing as dash does; macOS /bin/sh is bash with readline.

#### C: clarity and names

- ern_exec.c:682 `int failed[2]` in main shadows the function failed(int, int); failed, not_started and no_terminal are one function (not_started(e) = failed(e, 0)). Fix: `start_failure[2]`, one function taking the tag.
- ern_tcp names one thing two ways: arm/2 arms a read's timer, write_limit/2 a write's; `erlang:cancel_timer(T, [{async,true},{info,false}])` spelled out three times (700, 791, 802) where ern_os has let_go/1; a waiting read #read{} in ern_tcp, a 3-tuple in ern_os. Fix: one arm/2 keyed by kind, one let_go/1.
- Three names for answering in ern_os: ern_rt:answer, respond/2, answered/2 (respond plus source_end). Fix: rename answered/2 to say it ends the source.
- Past participles for functions that act and return nothing: ern_os spawned/5, started/5, answered/2, killed/1; ern_tcp counted/1.
- Names not saying their work: ern_os is_taken/1 (whether the host takes the kind's size); ern_tcp tls/3 (starts ssl if needed then runs the request); ern_tcp inet/1 (answers ssl for TLS).
- Two copies of one parse: ern_tcp server_name/1 and reference/1 both parse the host and trim trailing dots.
- ern_tcp.erl:836-838 a comment line holding only `%% alert's` (broken wrap).
- ern_tcp.erl:614 "A socket over TLS always is" handed to a closer no longer holds when getstat fails (the `_ ->` branch).

#### Kept for a reason a later rule removed

- ern_os.erl:531 `not_started(<<"enotdir">>) -> 'NotFound'`: ern_io:host_error(enotdir, _) now answers NotFound; redundant.
- ern_os.erl:129-130 "jobs are Os's programs and Fs's removal of a tree" and ern_exec.c:264 "Both jobs send it": the tree removal left with fc251a39; posix_name entries ENOTEMPTY and EBUSY arise from no job (EISDIR and EROFS still from lock's open).

#### S: real exposures

S1. ernest.pid is group-writable under umask 002 and ern stop/reload signal whatever number it holds: ern_exec.c:609 opens with O_RDWR|O_CREAT|O_CLOEXEC, 0666; under umask 002 (Ubuntu's default) the file is -rw-rw-r-- (seen in C1/hostile); record locks advisory, so a group member rewrites the number while the node holds the lock; the owner's next stop/reload signals that process as the owner. §12.5 refuses a file of its directory that anyone but its owner may write, yet the node makes one. Fix: create with 0644 (or 0600) and O_NOFOLLOW; in node mode fstat and refuse one not the caller's or others may write.

S2. ern stop/reload --config-dir D trust a directory the node would refuse: ern_node.erl:453 calls ern_os:node_signaled with no ownership check; the helper's node job (ern_exec.c:646-678) trusts any lock holder. Shown: a sleep 300 locked under hostile/ernest.pid by the helper's lock job, then `ern_exec node hostile/ernest.pid 15` killed the sleep (exit 0); the cross-user part argued, not run. Fix: stop and reload apply §12.5's directory and file check before signaling, or the helper checks the file's owner as in S1.

#### S: hardening

S3. The lock and node jobs follow symlinks at ernest.pid; the directory check makes this hardening only. Fix: O_NOFOLLOW.

S4. A TLS accept's handshake runs with infinity (ern_tcp.erl:480): a client that connects and never sends its hello holds a socket process, a writer, ssl's processes and an fd until the program closes; each close then holds a closer for ssl's 10 s; bounded only by the program's read timeouts, which ernest-httpd must always set.

#### Where the language made the work harder
None.

### Reader C2 (the toolchain outside the runtime), release review before 0.9.0, read at 09a01215

Probes under readers/C2/ (j2.escript, q.escript, ns/, steps1).

#### Defects

C2-1. erl/json/src/ern_json.erl:74-87 `number_offset/2`: a too-long integer looked for by its digits at any offset outside a string. Quadratic: `[A, B]` with A = 1,262,592 nines and B one more takes 57,772 ms (B alone 685 ms); a 2.5 MB text a minute of CPU, and Json.parse reads what a peer sends. And wrong: a real is not thrown, so `[1.<Big>, <Big>]` answers Position(1, 4), inside the real's fraction, where the integer begins at column 5000006. Fix: compare only where a number begins (the byte before starts no number), skip the whole number; linear; add a test of a real holding the digits.

C2-2. test/ern_install_tests.erl `made_from/1` (new): the expected mark is read from the checkout after install.sh made the archive; an edit or a HEAD move between the two reads fails release(); a real flake in this repository, where the user edits while tests run. Also a copy of install.sh's rule (208-214). Fix: install.sh writes its mark and ref into the archive and the test asserts the shape `""|+<8 hex>[.dirty]`, or read made_from before and after and accept either.

C2-3. test/ern_pty.erl:62 `step({expect, Text})` writes a text holding a line feed as two lines, the harness drops the second as blank; ern_shell_tests.erl:271 `{expect, "Counter.start() : Address(Counter.Msg)\n"}` waits for the text without its \n; under the terminal it arrives as \r\n so an honored \n could never be met. The harness hides a wrong test (the Python did the same). Fix: refuse a step text holding \n in step/1; drop the \n at 271.

C2-4. test/fixtures/pty/pty.ern:492-503 `controlled/3` reads at most two parameters while `afterParameters/1` (color stripping for an expect) takes any number: `printf "\033[1;31;40mgot $x\033[0m\n"` meets the expect `got a` but --screen paints `[1;31;40mgot a`. Fix: one parameter reader for both, the first two read as numbers.

C2-5. G.11 "A request line is three words parted at spaces", but erl/http/src/ern_http.erl:20 ?IS_SPACE parts at spaces, tabs and CR (test :53 asserts `"GET  /x\tHTTP/1.1 "`; comment cites RFC 9112 §3). `parse_request(<<"GET\t/\tHTTP/1.1\r\n\r\n">>, L)` answers Parsed. Fix: the report names tabs and a bare CR, or the code parts at spaces alone.

C2-6. §4.2 "their files provide those namespaces", but ern_build.erl:973 `taken_by/2` splits unevenly: the standard library's root provides every taken namespace, Ernest among them (src/stdlib/ernest.ern accepted); the shell's root provides Ernest alone (src/shell/io.ern refused). Fix: the report says which root provides which; refuse Ernest under the standard library's root if so.

C2-7. `ern_http:parse_response` accepts a status not three digits (`HTTP/1.1 20 OK` → 20, `2000` → 2000); RFC 9112 status-code = 3DIGIT; G.11 silent. Fix: Malformed outside 100..999, or the sentence in G.11.

C2-8. Load-sensitive new tests: ern_nodes_tests.erl:1410 `free_ipv6_port/0` picks and closes a port before the node binds (ipv6_test, ipv6_beside_ipv4's PortA), as free_port; ern_system_module_tests.erl `tcp_tls_test` assumes nothing listens on 127.0.0.1:1. Fix: port 0 and bound_port/1; refuse on a port the test holds closed.

#### Clarity

C2-K1. ern_build.erl:992 `taken_namespaces/0` no longer means §4.2's taken, since Ernest is taken and not in it; kept from before. Fix: `given_namespaces`.

C2-K2. Owners named in two tables with two spellings: `own_roots/0` "the standard library's"/"the shell's"; `taken_by/2` "prelude"/"standard library"/"toolchain's", so messages read `takes the toolchain's namespace Ernest` beside `takes the prelude namespace Int` and `stands under the standard library namespace Io`. Fix: one form. (= U16)

C2-K3. ern_carrier.erl:271 `family_alone(none) -> []` redundant (ern_node:family(none) is inet, answers []); `listen_options/1` has no comment.

C2-K4. ern_http.erl: `Line` the line limit in parse/3, headers/6, packet_size/2 and the line's bytes in first/3; `Headers` in parse/3 an Int limit; `Count` a byte total. Fix: LineLimit, HeadersLimit, Taken.

C2-K5. ern_json.erl:59 `white_space/1` answers what follows: `after_white_space`; :130 "The first lone high surrogate's escape outside" lost "inside a string".

C2-K6. test/ern_measure.erl `http_scenarios/0`'s comment says "each reader over a loopback pair of its own" but four readers share one pair.

C2-K7. erl/base64/test/ern_base64_tests.erl `exactly_written/0`'s comment records the approach set aside and its timing; belongs in the log.

C2-K8. test/ern_pty.erl:53 the steps file is a leftover: the shell that read `>` is gone (spawn_executable); the new comment gives no reason. Fix: pass the steps as arguments, or state the reason.

C2-K9. One size in two shapes, sometimes for nothing: `[screen, {size, 24, 80}]` (nodes 3663, 4678, 4719) and `[{size, 24, 80}]` (shell bracket_shown) pass the default; `screen/3` takes {Rows, Columns} while pty/3 takes [{size, Rows, Columns}].

C2-K10. pty.ern functions that act named as values: stepped, taken, expected, opened, ended; guide/style.md's verb rule as 4ecd6a23 applied it. Fix: takeSteps, take, awaitText, awaitPut, awaitEnd.

C2-K11. pty.ern: Options.ms is Optional(Int) and passed again beside options to drive (parsed could answer the ms apart); the escape spelled `<<0x1B>>` and `'\u{1B}'`.

C2-K12. ern_nodes_tests.erl: `changed_release/3`'s comment ends "One step, the build." (cryptic); `free_ipv6_port/0` repeats free_port/0. Fix: `free_port(Address)`.

#### Kept for a reason that is gone
taken_namespaces/0 (K1); the steps file (K8); family_alone(none) (K3).

### Reader E part 3 (src/stdlib, src/shell, examples), release review before 0.9.0, read at 09a01215

Probes under readers/E3/ (probe1–3.ern, fetch and web_server built and run there).

#### Defects

E1. src/shell/README.md:43 names `detached` and `ended`, renamed by 4ecd6a23 to `detachNode` and `end`; the comment above `leave`, shell.ern:1462, says "(detached)". Fix: write detachNode and end in both.

E2. examples/fetch.ern:106-112 `targetOf`: the authority ends only at `/`; per RFC 3986 also at `?` and `#`; an IPv6 literal fails since `hostAndPort` splits at the first `:`. Shown: `https://httpbin.org?x=1` → "cannot connect to httpbin.org?x=1: non-existing domain"; `https://[::1]:8443/` → "not a host and a port: [::1]:8443". Fix: end the authority at the first of / ? #, port after a closing ]; or narrow the header's promise. See E21.

E3. fetch.ern:214-221 `errorText`: connectTls answers Left(NotFound) for a CA file it cannot read, printed raw: "fetch: cannot connect to example.com: NotFound". Fix: map NotFound and Denied to "cannot read the certificates in <file>".

E4. E.23's resize and the page: once exited "answers Right(Unit)"; a size outside 0..65535 Left(Invalid); only NotATerminal says "whatever the size". The runtime picks Invalid after exit, unstated (probe1). Fix: one sentence stating the order. (P2 asks for Left(Closed) after exit.)

E5. src/stdlib/os.ern:574 `collect`: `read(program, deadline - Clock.monotonic())` can be negative; the runtime clamps to 0 (ern_rt:deadline), neither shape rule 8 nor E.23 states it; snake.ern clamps by hand with Int.max, so the repository waits two ways. Shown: Os.read(p, -1) → Left(Timeout); Os.run(cmd, -5) → Left(Timeout). Fix: shape rule 8 says a negative time is no time.

E6. path.ern:54-66 and E.14: `Path.join(["", "b"])` is "/b", which follows from "written as given", unwarned; the page's example shows a separator but not the ".." it warns about (probe2: "/b", "root//x", "a/../b"). Fix: one sentence and an example for the empty segment, and one with "..".

E7. examples/web_server.ern:143 cuts a cookie's value at its first `=` (`String.split(..., "=")`, `key :: value :: _`); a base64 value loses its tail. Fix: String.splitOnce.

#### Clarity, names, pages

E8. The verb rename (4ecd6a23) stopped at three; still participles doing something: `ownMarked()` (shell.ern:2508), `letGoSaid` (:814), `painted` (:1348, sends then loops), `answered`/`refused`/`diagnosed` (print then answer Next), `appended`, `appendedThere`, `remembered`, `listed`, `outputTried`, `located` (calls on the local half or the screen), `keysRead` (:380, spawns), and fetch.ern's `fetched` (network I/O) beside fail/report. By the library's precedent (Fs.read, Tcp.connect) a function with an effect is a verb even when it answers a value. Fix: apply the rule to the whole set, or state where the line falls.

E9. tcp.ern:320-325, connectTls page: "It answers Left(Other(text)) where the handshake fails, …, in the host's words, for a file of certificates it cannot read or refuses what listenTls answers for its files, and otherwise as connect does" does not parse. Fix: two sentences.

E10. os.ern:324 startTerminal page: "`TERM` is not set" reads as the child has none; E.23 means the runtime sets none. Fix: "the runtime sets no TERM; the program inherits the environment as under start".

E11. The Os page never tells a programmer to kill a program after reading Exited (since 8be9ad32 the process lives on until killed or its owner dies); start/read/write/closeInput examples leave the process; only run says it kills. Fix: a sentence on start and a kill in one example.

E12. tcp.ern:391-392 (close) and 271-301: the page lacks E.18's close sending taken bytes up to 5 s, 10 over TLS; a key not the certificate's not refused by listenTls but failing each handshake; a handshake the far end closes answering Closed; module doc :9 "accept and connect answer a socket's address" lacks connectTls; write page's "what the host takes and holds back is what the socket does" opaque, 8 KB mark without the 4 KB one. Fix: a sentence each.

E13. shell.ern:2088-2093 `startRefusal`: `Unreachable -> refusal(name, Io.Unreachable) | ProgramEnd -> refusal(name, Io.Unreachable)` duplicate arm; the function exists since 5fbf4327 changed refusal's Io.Other arm, and repeats the "ern shell: the peer " prefix in a third arm: kept for a reason a later rule removed. Fix: `Unreachable or ProgramEnd -> …`, share the prefix.

E14. code.ern:75-77 Code.load page: "lives on while it owns what a binding opened, a listener or a running program" drops E.28's socket, table and proxy, and that a table keeps it until the program's end. Fix: list the table case.

E15. os.ern:34-37, 320-330: See also lacks Terminal; the terminal paragraph says it echoes "what write gives it" but command.input is echoed too (probe3: Stdout("hi\r\n") from input "hi\n"); closeInput page lacks E.23's sentence that a program may see its input's end before the hangup. Fix: three edits.

E16. fs.ern:21-24: "…is Left(Io.NotFound), as a path that names nothing is, and so does a path through a loop of links" — agreement. Fix: "and so is".

E17. The name startTerminal says it starts a terminal; it starts a program under one. Listed for the decision; none needed if the name stays.

E18. fetch.ern:88: the 10 MB body limit is an unnamed literal beside the named limits. Fix: name it.

E19. shell.ern:2353 foreign fn decoded does work Ernest could do (E.0 rule 1): feedback 206, open.

#### Where the language made the code harder

E20. Every reference from one shell module to another fully qualified, 136 in all (Command 45, Editor 41, Region 21, History 13, Style 10, Complete 6; shell.ern 110, complete.ern 26, editor.ern 3), since there is no import; the move under Ernest lengthened each and rewrapped about twenty lines. Feedback 204, decided (relative names, MVP 4.15 item 6); the count for its verdict.

E21. Two examples write parts of published specifications by hand and get them wrong: fetch.ern parses URLs (RFC 3986, E2); web_server.ern parses the Cookie header (RFC 6265, E7). libs/http has neither a URL nor a cookie reader. Belong in docs/language_feedback.md by CLAUDE.md's rule.

E22. Os.Command cannot set a program's environment or working directory; an editor under startTerminal needs TERM; the only way is `env TERM=... vi` or `sh -c 'cd …'` in the arguments: a gap.

E23. Nothing makes a socket close on every way out of a block that uses `<-` (fetch.ern:66-92): Tcp.close reached only on success; each earlier Left leaves without closing, the socket waiting for its owner's end. A server copying it keeps a socket per failed fetch. No form cleans up whatever way the block is left; the correct code nests each step or spawns a process per fetch.

### Reader E4 (base64, crypto, time, http, json), release review before 0.9.0, read at 09a01215

Probes under readers/E4/ (p1.ern to p12.ern).

#### Defects

E4-1. Json's position for a too-long integer that follows a real: ern_json.erl number_offset/2's comment holds for integers only; a real holding the digits is read without error and the search finds the digits in it (p11: `[0.<1.3M nines>, <same>]` answers Position(1, 4), the integer at column 1300005; `[1<digits>e-1300000, <digits>]` column 3). Fix: accept only an occurrence standing as a whole number token, no number byte before, no digit/./e/E after. (= C2-1)

E4-2. Json's UnexpectedEnd and UnexpectedByte for a broken literal are the host's quirks passed through: `[\n\n nul]` and `[t]` answer UnexpectedEnd with no position though the text does not end inside its value; `[tru, 1]` answers UnexpectedByte(114, column 3) where the byte that cannot stand is the `,`. Raw json:decode gives the same. Fix: close the difference in the shim (name the first byte that differs from the literal at its offset) or state the host's rule in G.6; report it in docs/otp_bugs.md either way.

E4-3. readHead parses the head again from its first byte after every read (http.ern:332-349, the comment says so): one parse of a 64 KB head of 580 lines 1.4 ms; every 64-byte prefix (1015 parses) 714 ms; a client pacing small packets keeps a scheduler busy for the deadline (on loopback reads merge; p7). Against CLAUDE.md's cost rule. Fix: parse again only when the new bytes hold a line feed; better, the primitive answers how far it read and the lines already read are carried.

E4-4. The limit on all headers together is found only after the line that passes it ends, plus one byte; the page (http.ern:223-226) and G.11 say "found at the bytes that pass the limit, before the line's end has come". p12 with Limits(line = 100, headers = 10): `GET / HTTP/1.1\r\nX: a\r\n` + 90 Y's answers Incomplete, so with a complete 96-byte second line. Fix: give the host packet_size = min(line, headers - count) per header line (ern_http.erl:372); its {error, invalid} already maps to HeadersTooLarge.

E4-5. A request with both Transfer-Encoding and Content-Length is read by the chunked coding alone and the bytes after answered for the next request (http.ern:472-490); RFC 9112 §6.1 says the server MUST close after such a request; the page silent: request smuggling for a keep-alive server. p10: `te("chunked") + Content-Length: 3` reads hello, rest "". Also `Transfer-Encoding: chunked, chunked` decoded once with no error. Fix: Protocol(Malformed) for both; G.11 says so.

E4-6. The response readers break two MUSTs of RFC 9112: parseResponse refuses a folded header (`X: a\r\n b` → Malformed) where §5.2 says a user agent MUST replace the fold with spaces; readResponseBody answers Malformed where the last transfer coding is not chunked, where §6.3 rule 4 reads to the close. G.11 states both; neither says it departs from the RFC. A report decision to weigh again (principle 1). Fix: replace a fold with a space in a response (keep refusing in a request); read to the close.

E4-7. A status of any number of digits is read and a leading zero dropped (p2: `HTTP/1.1 1000 X` → 1000, `99` → 99, `0200` → 200); RFC 9112 three digits; G.11 silent. Fix: Malformed unless three digits; the sentence in G.11. (= C2-7)

E4-8. render and renderRequest write whatever they are given: `render(Response(status = 204), "oops")` writes a body after 204, read as the next response; `Header(name = "X", value = "a\r\nSet-Cookie: evil")` written as two lines (response splitting); a method or target holding a space or CRLF written as is. G.11 "written as given"; the failure invisible (principle 3). Fix: refuse such a value (fault or Either), drop or refuse a body for 1xx, 204, 304; state it in G.11.

E4-9. G.11 "three words parted at spaces" vs the code and page ("between spaces or tabs"): runs of spaces and tabs accepted (`GET\t/\tHTTP/1.1`, `GET  /  HTTP/1.1`); the shim's comment (ern_http.erl:349-352) claims bare CRs part words, but the host refuses them first (`GET\r/\rHTTP/1.1` → Malformed). Fix: G.11 "parted at runs of spaces and tabs"; the comment corrected. (= C2-5)

E4-10. An empty line before a request line is refused (`\r\nGET / HTTP/1.1\r\n\r\n` → Malformed); RFC 9112 §2.2 says a server SHOULD ignore at least one (a client sending CRLF after a POST body makes its next pipelined request Malformed). A report decision. Fix: skip one empty line.

E4-11. json.ern's tests (135-242) cite no report section, the Position cases among them; make sections passes only through ern_nodes_tests.erl:6466 and fixtures/peers/pair.ern. Fix: `// report Appendix G.6` on each case.

E4-12. An RFC 850 two-digit year decided by its year, not its moment (http.ern:869-875): RFC 9110 §5.6.7 says "more than 50 years in the future"; on 2026-11-02 `31-Dec-76` is read as 2076, 50.2 years ahead. G.11 states the year rule. Fix: compare the moment, or G.11 says it departs.

#### Clarity

E4-13. Http.header and Http.headers share their words with the type Header and the field headers (`Http.headers(request.headers, "Set-Cookie")`); the module's own framing(fields : List(Header), ...) dodges it; shape rule 10. Fix: value and values.

E4-14. render the only Response function not naming its kind; a reader predicts renderResponse. (= P8)

E4-15. parseRequest answers Parsed(head, rest), readRequest #(Request, Bytes) for the same; Error holds BodyTooLarge, which parseRequest/parseResponse never answer.

E4-16. readRequestBody(socket, carried, request, limit, ms) takes two Ints side by side; the head's limits a record, the body's a bare Int. Fix: a body field in Limits.

E4-17. Repeated forms by count: `Http.Limits(line = 8192, headers = 65536)` 11 times in http.ern + once each in fetch.ern and web_server.ern; `Http.Version(major = 1, minor = 1)` 28 times across tracked files. Constants (E.0 rule 3). (= feedback 186, MVP 4.15 item 3)

E4-18. Bytes as bare numbers: `<<59>>`, `<<10>>`, `<<13>>` (http.ern:527, 552, 571); `<<';':utf8>>` says what it is.

E4-19. Time's names: civil/fromCivil predicts toCivil; weekday takes an epoch time, not a Civil, so a program holding a Civil goes fromCivil (Optional) then weekday.

E4-20. Json.UnexpectedSequence(bytes : Bytes) holds bytes always UTF-8 (the input is a String): shows as `<<92, 117, 49, 50, 34, 93>>`; for 1e999 the host's spelling `1.0e999`, the page says "the host's spelling" with no example. Fix: a String field; an example.

E4-21. json.ern's module page lacks a "Use it ..." paragraph, See also, and a word on errors and positions, which shape rule 6 asks and the four new pages have.

E4-22. Http's page leaves a programmer unable to: write a chunked response (no encoder); split or percent-decode a target; know a 1xx from readResponse means reading again with carried; know a request with Expect: 100-continue waits on its body until the deadline unless the server writes a 100.

E4-23. `fn version11()` (http.ern:937) a function where `let testLimits` beside it is a let.

E4-24. `bin/ern doc src/libs/http/http.ern` from the root titles the page "Ernest module Src.Libs.Http.Http"; docs/man shows "Http". The toolchain's.

#### E.0 rule 1 and the shims

E4-25. Base64.decode could be Ernest: its strictness checks (count, alphabet, where = stands, unused bits) are a scan Ernest can write; after them base64:decode/1 cannot raise; G.8's reason "the host raises on a text it cannot read" holds only for an unchecked text. 900,000 random texts compared: the shim is correct.

E4-26. ern_http does far more in Erlang than G.11 describes: the whole head loop (limit accounting, word split, is_target, is_value, trimmed); G.11 says "a primitive over decode_packet, a line at a time ... the rest is Ernest". Only the one-line decode needs Erlang (atoms).

E4-27. ern_json computes the line and column, the too-long number's offset and the lone surrogate in Erlang (at/2, number_offset, lone_escape), all on the error path; the shim could answer the host's offset and leave the scans to Ernest.

#### Where the language made it harder

E4-28. A one-armed if for an effect: `if ending == Closes then Tcp.close(client) else Unit;` (http.ern:1334).

E4-29. Every Tcp call in a reader's `<-` chain needs `Either.mapLeft(..., Http.Socket)`: 8 sites in http.ern's examples, 3 in fetch.ern. (= feedback 185, MVP 4.15 item 4)

Leftovers: none.
