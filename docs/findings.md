# The findings of the tour's outline

Found on 2026-10-23 while writing MVP 3.3's outline, [`proposals/tour/outline.md`](proposals/tour/outline.md), against report §3.11, §6.10, §11.2 and Appendix H, and by the spike that ran its sessions the same day. Each line stays until a plan item decides it, and carries what became of it once decided; the file goes when every line is done, dropped or planned.

## The lines

**The documents**

- T1 `fix`, done 2026-10-23: `why.md`'s fragment under *Code known by its hash*, `Peer.spawn("foo", fn() = count(0), 5000)`, stands after the message type that carries `Upgrade`, at which the spawn is refused as bound to its node (report §3.11); it is a fragment, which nothing checks. The fix, decided 2026-10-23: the sentence before the fragment names the first claim's counter, whose messages carry no function.
- T2 `planned`: the plan's MVP 3.3 sketch, items 2 and 7, has the counter spawned on the peer in chapter 2 moved to new code in chapter 7, and the refusal across versions and the `Upgrade` in one chapter. A process keeps its mailbox type for life, a type that carries `Upgrade` is bound, and the refusal is a type change where the move is a loop change, so neither can be built (the outline's section 1). The plan's sketch is rewritten from the outline when the outline is decided.

**The toolchain's messages**

- S1 `fix`: `a.compare(b)` written on a value of a type variable under `needs k.compare` is refused with `the type whose field compare is read is not determined; annotate it`, and an annotation does not help; the fix is `k.compare(a, b)` (report §4.9), which the help should name where a requirement on the variable is in force.
- S2 `fix`: a constructor of a private type named at the prompt, `Counter.Inc`, is refused with `unknown constructor Counter.Inc`, while the shell prints the type's name in an address's type; the message should say the type is not exported (report §4.2).

## The skeptics' read of `why.md` and `faq.md`

Found on 2026-10-23 by the full review's readers L, the Erlang programmer, and M, the Gleam programmer, MVP 3.296's item 3, over `guide/why.md` and `guide/faq.md` alone; each ran `bin/ern` on the programs and on probes of its own. A line's place is the document's line on that day. `fix` lines are prose made at once and shown to the user first; `decide` lines are the list decided with the user; `drop` lines stand with their reason.

**The documents**

- L1, M18 `fix`: why.md 18, "is not mixed with Elixir or Gleam code; What ships with Erlang/OTP", a capital after a semicolon, and a sentence that reads as "no hex libraries" against faq.md 69, which reaches one through `foreign fn`. The sentence says that a program's own code is Ernest and that the host's libraries, hex among them, are reached through declarations.
- L2 `fix`: why.md 18 never names what an OTP programmer finds in place of supervisors, releases, `sys` and the rest; the sentence points at the guide's §10 and the FAQ.
- L3, M14 `fix`: why.md 15, "pays nothing for the question", against 241, "costs it nanoseconds" and a `try` on a foreign call. The headline says nanoseconds at work and the look only when idle.
- L4 `fix`: why.md 15 reads as a runtime guarantee, and 239 says the look never runs on a node, which `docs/design/runtime.md` confirms. The headline says under `ern run`, `ern test` and the shell, a node being left to its peers.
- L5, M15 `fix`: why.md 237, "On Erlang that program waits forever ... every call there carries a default of five seconds": a bare `receive` waits forever, and `gen_server:call` exits after five seconds naming the timeout and not the cause, while the program above it gives `Address.call` a deadline of its own. The sentence says so.
- L6 `fix`: why.md 58, "runs its function again in place after a fault, keeping its address": the mailbox is emptied and the function begins from its start (report §6.9), which the sentence says; L tested a queued `Get` answered `None`.
- L8, L26 `fix`: why.md 87 and faq.md 83, the `Upgrade` changes the loop and not the messages, and nothing says what a change of the messages is: a process keeps its mailbox type for life, so a protocol change is a new process. One sentence in each.
- L9 `fix`: why.md 99 shows `Reset` refused and lets the reader think the old constructors still reach the old process; `Counter.Inc` is refused the same way, which the prose says.
- L10 `fix`: why.md 89 and faq.md 85, "Nothing is purged", stated with no word on when a node restarts; both point at the deployment guide's §4.2.
- L11, M5 `fix`: why.md 104, "whose messages carry no function and so may cross", three lines before a spawn carries a function: a spawned function crosses as code by its hash, a function in a message would cross as a value, and none does (the guide's §8.4). One clause.
- L12 `fix`: why.md 104 and 124, "holds none of its code", "Nothing was installed": the peer holds the same `ern` and OTP, the standard library and the host's modules the program's foreign declarations name, and of the program nothing (report §8.7). The sentence says what it holds.
- L13 `fix`: why.md 118, `render(scene, row)` ships `scene` with every call, unsaid; a clause says the captured values cross with each call.
- L14 `fix`: why.md 115, what a fault in the computed function does is unanswered: it is the caller's (report §8.7). One clause.
- L17 `fix`: why.md 145 and faq.md 87, how a service's protocol evolves across deployments: a service of a new message type is a new service, found by the new hash, while the old runs on for the finders of the old. One sentence in the FAQ.
- L20, L31 `fix`: why.md 60 and faq.md 71 say what is free at the boundary and not what is paid: a check walks the value, so it costs with the value's size. One clause.
- L24, M17 `fix`: faq.md 17 and why.md 56, the order in which top-level bindings across modules are made: dependency order (report §8.5). One clause.
- L25 `fix`: faq.md 23, "no links": what ends a worker when its owner ends is nothing but the program's end, and a worker that must end with its owner monitors it. One clause.
- L27 `fix`: faq.md 39, a `receive` is a `match` over the type, so there is no selective receive; the answer names it.
- L29 `fix`: faq.md 57 and 61, a reply after the deadline is discarded (report §6.6); the second half of the answer is the host's reply-once alias restated, which stands.
- L30, M21 `fix`: faq.md 69, how a hex package reaches a program: built by its own tools, and `--libs-dir dir` puts each `dir/*/ebin` on the load path (report §11.2). Two sentences.
- L22, L23 `fix`: faq.md 15 and 19, a `gen_server` is `sys`, `code_change` and `terminate` beside its loop, and the supervisor is one sentence. The answer says what stands for each and what has nothing: the loop and the typed call; the `Upgrade` message for `code_change`; a monitor's `Down` for `terminate`; no `sys`; and `Supervisor`'s three strategies, its limit and its children restarted in place, with what it lacks named (Appendix E.22).
- M3, M2 `fix`: why.md 11 and 24, the gain over a typed channel is on the page and unsaid: `spawn(fn() = count(0))` is typed from `count`'s own type, and a function that receives runs only in a process of its mailbox's type, so `let other : Address(OtherMsg) = spawn(fn() = count(0))` is refused, `the value does not have the declared type: expected Address(OtherMsg), found Address(CounterMsg)`. The refusal goes on the page.
- M7 `fix`: why.md 115, "the less busy of two peers drawn", the two unexplained: two drawn at random and the less busy taken spreads work with no central choice. One clause.
- M10 `fix`: why.md 205, the refusal that shows the difference is not shown: `sorted([Green, Red])` on a type without `compare` is refused at the call, `sorted needs Color.compare, and Color has no compare`. It goes on the page.
- M11 `fix`: why.md 14 and 187, "the one operation": a requirement names the members it needs, several with commas; a type's members are declared in its own module; a requirement is written and never inferred (report §4.5, §4.9). The sentences say so.
- M16 `fix`: why.md 239, "never wrong" asserted: it reports no deadlock that is not one, since a process it cannot see is read as able to deliver. One clause.
- M22, L28 `fix`: faq.md 41 to 43, the one-mailbox answer gives the adapted address, which the reader has as a wrapping function; the gain is that the type is in the function, which the answer says.
- M25 `fix`: why.md 89 to 101, the counter's type is `CounterMsg` in every program and `Msg` in the transcript; the transcript is run again with `CounterMsg`, with the tour's build.
- L19, M9 `decide`: why.md 14 and 233, faq.md 91, "there is no type class, interface or trait" and "No.": both readers read a member declared under the type's name, one per type, supplied at the call, as a one-method class with implicit coherent instances and no hierarchy, and believe neither sentence. A design question of wording.
- M12 `decide`: why.md 237, "No program shows this claim", the one claim neither language has; M's ten-line program ended in 0.6 s with the fault. Whether the claim gets its program.
- L7 `decide`: why.md 29, `restarting(Unlimited, ...)` on a program that never faults reads as a crash loop made harmless; whether the first program writes a `RestartLimit`.
- M19, M20 `decide`: faq.md 7 to 11, the Gleam answer lists what Ernest has beyond Gleam and nothing Gleam has that Ernest lacks, nor what the process being the language buys over a library; whether it says both.
- M23 `decide`: faq.md 25 to 35, the Unison answer is the longest and its last three paragraphs are history; whether they move to the log.
- L32 `decide`: faq.md has no question on tables, tracing, `observer`, back pressure or releases; whether one is added, answered as things stand.
- L21, M13 `decide`: a fault's trace shows the runtime's own frames, `ern_rt:call_forever/3:639`, above the program's; whether the runtime's own frames are cut from a program's trace, a toolchain change.
- L15, L16 `decide`: why.md 13 and 128, faq.md 77, the WAN claim says nothing of the transport under loss, of a node that only dials, or of reconnection; whether a sentence of the report's facts goes in (report §8.7, Appendix C).
- M4 `decide`: why.md 64, the hash section opens on an upgrade message the reader's language has; whether the section is reordered.
- M6 `decide`: why.md 106 and 117, the two `Peer` fragments have no console block; whether they point at the tour's chapter 2 once it exists.
- M1 `drop`: why.md 11 names what a `Subject` gives; the sentence also says the receive is checked and the function's type names the mailbox, and M3's refusal beside it shows the difference.
- M8, L18 `drop`: why.md 155, the abstract type is Gleam's opaque type and Dialyzer's `-opaque` with teeth; it is one of the three things the claim names and stays shown, in six lines.
- M24 `drop`: faq.md 93, the lambda question is not a Gleam programmer's; the FAQ answers every reader's.
