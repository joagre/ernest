# Findings: MVP 3.0 read without a release

The plan's MVP 3.0, item 13 (the log's *MVP 3.0 Read Without a Release*). Three of [`release_review.md`](release_review.md)'s readers, run on 2026-10-08 as [`full_review.md`](full_review.md) runs them, over commit `a6612bf9`: the report's reader, K and P as one, on the most advanced model, over §3.11, §8.3, §8.7, §6.10's peer part, §11's node jobs, §11.3, Appendix C, E.27 and G.4 to G.6; the argument's reader, A, on the most advanced model, over `soundness.md`'s section 7 beside the report; and the guide's reader, U, on the model below, over chapter 8, its examples run. The code's reader has not run: whether it reads the code whole, as `full_review.md`'s C, E and S do, or what changed since `v0.3.1`, is a decision of the user's, named in the plan's item 13. Each reader read cold, its brief and its files and nothing that argues for them, and edited nothing; the scratch programs the lines name are under the session's scratchpad, `readers/kp`, `readers/arg` and `readers/u`.

A line per finding, by area, each naming its reader's letter and number and carrying its decision: `cheap`, fixed in the item that works through the list; a milestone's number, planned there; `done`; or `dropped`, with the reason. The decisions are given as the list is worked, design questions with the user one at a time; until then a line's decision is `to decide`. Each reader's whole list stands below the lines.

## The argument

| | Finding | Decision |
|---|---|---|
| A1 | Two shells that are nodes, each declaring a `type T` at the prompt, connect under one fingerprint, offer and find a key at it by its text, and a `Put("boom")` reaches a `receive` typed `Put(Int)`, which faulted in `+`: claim 1 breaks for a shell that is a node, and section 7's "under one build the text names one declaration" is false there. Shown by two shells. | to decide |
| A2 | The standard library is outside the fingerprint, so two nodes of one `ern` version with different standard libraries connect, and a standard library type may be two declarations under one text. | to decide |
| A3 | "A declaration's name, which captures nothing" misreads §5.4, where a local `fn` is a declaration and captures; the toolchain refuses the case, as a function that came as a value, against the report's letter. | to decide |
| A4 | "No bound value crosses" is contradicted two sentences later: an adapted address's captures, which may be bound values, cross as payload; what holds is that nothing on the other node reaches them. | to decide |
| A5 | §6.10's cross-node `Upgrade` example is refused by the rule section 7 restates, the lambda's mailbox type being a variable; `with Never` builds. | to decide |
| A6 | How a peer tells that it lacks a session's module, "at the version the function was compiled in", is a claim of the runtime no section states; the frame of §8.7 carries no version. | to decide |
| A7 | §11.2 says modules are loaded "on demand"; the argument needs the load path read whole at the fingerprint, which the runtime does and no sentence states. | to decide |
| A8 | I3 does not count the callee node's note, which holds a reply; a third place beside the expression and the message. | to decide |
| A9 | The sources of a remote address leave out the values a spawned function captured. | to decide |
| A10 | Section 8 cites MVP 3.1's hashes, outside the report, and omits what A1 shows section 7 does not answer. | to decide |

## The report

| | Finding | Decision |
|---|---|---|
| P1 | `Peer.spawn` and `Peer.spawnMonitored` are not values, and their function is a declaration's name or a same-definition lambda, both only for the capture check; `restarting(Unlimited, work)` cannot be spawned on a peer without a wrapping lambda. | to decide |
| P2 | The compiler names four library types as resources in §3.11, and `key` is a fourth value the compiler makes; no rule lets a library say its type is bound. | to decide |
| P3 | A node cannot find its own offer and `Peer.spawn` cannot name the running node, so placement-independent code writes two operations, and G.5's `Place` exists for that alone. | to decide |
| P4 | In a spawned function a top-level name is the peer's and a captured one the spawner's, stated; but §6.10 calls two `fn` declarations "top-level bindings", which Appendix F reserves for a `let`. | to decide |
| P5 | `Peer.Failure` overlaps `Io.Error` (`Refused`, `Timeout`) and `Reason` (`Unreachable`), unexplained. | to decide |
| P6 | `measures` is a rule of the normative report, in §8.7 and Appendix C, serving the informative G.4 alone. | to decide |
| P7 | `Load.schedulers(ms)` puts milliseconds last for a window, E.0 shape rule 8's shape for a bounded wait; `memory`'s minutes rule is one measure's. | to decide |
| P8 | `./.ernest` for a program that is no node is a concept no job reads. | to decide |
| P9 | `Peer.nodes` answers "the names of the peers" where §8.3 makes a node this runtime and a peer another. | to decide |
| P10 | Principle 4: nothing; no grammar added. | done |
| K1 | §6.10's example does not compile (A5). | to decide |
| K2 | A peer's `public-key` that does not decode crashes `ern` at start, `internal error … asn1 … wrong_tag`, exit 70, and on `ern reload` crashes the signal handler, after which the node takes no signal: `ern stop` exits 0 and the node runs on. | to decide |
| K3 | A reload's line has no time and names no peer added, removed or renamed, and the host's `Undefined handle_info in ern_signals … {'EXIT',#Port<…>,normal}` warning is printed on standard output at every reload; `os_mon`'s `cpu_sup … Erlang has closed` line at the end with `cpu` measured. | to decide |
| K4 | `ern test --config-dir dir` with a test that waits forever hangs, where `ern test` says `faulted: deadlock`; §11.2's "the run goes on" and §8.6's "a node detects no deadlock" meet without a sentence. | to decide |
| K5 | A node refuses to start for a `.erc` on its load path the program never uses, whose dependency is missing, `cannot find module Load`; `ern run` without a configuration runs. | to decide |
| K6 | `Refused` is among what a find passes over in §8.7 and not in E.27, and no sentence has a peer answer it to a spawn. | to decide |
| K7 | Appendix B says a message to a worker on another node faults the sender; §3.11 refuses the address as bound, so no process on another node can hold it. | to decide |
| K8 | §8.3's "every node runs the same compiled program, whole" is false: nodes of one build run different programs, and `NotLoaded` by binding happens only then. | to decide |
| K9 | The node checks rules the report does not state (a key naming no peer, a nameless peer, `measures` not an object, two peers with one key), and accepts `disk`'s `check-interval` of 90000 where it refuses `memory`'s, the host counting minutes for both. | to decide |
| K10 | A reload refuses a file that parses and changes neither key nor listen, for a rule of the configuration; §8.7 states two reasons. | to decide |
| K11 | `ernest.pid` outlives a refused start. | to decide |
| K12 | §8.7's terms without a glossary line: fingerprint, handshake, detector, tick, frame, note, offer, the start's number, dial, measure, carrier; "key" is three things. | to decide |
| K13 | `Peer.key` at a type not known whole asks for an annotation, absent from §3.9's list; "where it is written" is loose, a later use in the definition fixing the type. | to decide |
| K14 | "The peer has its module" means "on its load path". | to decide |
| K15 | "A value of a bound type never crosses" beside "crosses with the values its function captured as payload" (A4). | to decide |
| K16 | The loss arithmetic: four ticks of 15 s is 60, not 45 to 75. | to decide |
| K17 | Resolution at read time is best-effort and unsaid: a name that does not resolve is accepted. | to decide |
| K18 | Appendix C leaves `measures`' shape to be guessed. | to decide |
| K19 | §9's criterion admits the `Peer` functions and `Peer.Key(m)`; its list omits them. | to decide |
| K20 | §11.2's "starts the host twice" and the refusal of `ern run --config-dir dir` with no `.erc` state no rule a program sees. | to decide |
| K21 | G.6's error words and the host's answers differ: `\ud800` answers `UnexpectedEnd`, `1e400` `UnexpectedSequence(<<"1.0e400">>)`. | to decide |
| K22 | `Load.schedulers(0)` and `(-5)` answer a number; what a zero window measures is unsaid. | to decide |
| K23 | Silences: the node's `public-key` against `certificate.pem`; which host version the fingerprint digests and whether a `.beam` is in it; an adapted address made on a node since restarted; `Peer.offer` in a program that is no node, accepted and unfindable; a `measure` outside 0.0 to 1.0. | to decide |

P's counts, against the counts of 2026-09-28: reserved words 18, unchanged; words read by position 13, or 16 with Appendix A's `compare`, `negate`, `show`; taken top-level namespaces 29, `Peer` the one added, 35 with Appendix G's six; prelude functions 33, or 38 with the five `Peer` functions §9's criterion admits; prelude types 21, or 22 with `Peer.Key(m)`; primitives outside §9 7, three added by nodes; concepts 116 by Appendix F's 141 entries without the toolchain's, the library's and "primitive", 19 of them nodes', 11 of those without an entry. The reader's table of the rules, each with what it buys and what would be lost, is in its list below; it names as buying little or existing only for another: P1's two restrictions, §8.3's "same program, whole", §6.10's remote `Upgrade` under one build, the read-time family check, `measures`, `./.ernest`, §11.2's "host twice", G.5's `Place`, and E.27's `Refused`.

## The guide

| | Finding | Decision |
|---|---|---|
| U1 | §6.3: "The loss of a peer faults every process on it" is false; nothing faults but a `callForever`. | to decide |
| U2 | §8.2: a node's end gives `Unreachable`; the report and the run say `ProgramEnd`. | to decide |
| U3 | §0's "Distribution by content, planned" says code crosses by hash; the report and the guide say no code crosses, and the roadmap is the plan's. | to decide |
| U4 | The preface says the toolchain does not run peers yet. | to decide |
| U5 | §8.1 and §8.8: "a module with no top-level `let`" is enough for a peer; a module it depends on may have one. Shown. | to decide |
| U6 | §4.1 writes `Peer.spawn(name, f)`, two arguments. | to decide |
| U7 | §8.3's list of exit reasons is written as complete and lacks `{ern, fault, Cause, Trace}`, `{ern, closed}` and `{ern, code_unloaded}`. | to decide |
| U8 | §8.2's loss paragraph: "No process of your own dies of it" beside a `callForever` that faults. | to decide |
| U9 | §8's intro defers to a deployment guide "which comes with MVP 3.1", which does not exist, for what §9.2 teaches. | to decide |
| U10 | §8.7's socket reader is written over `Address(Session)` where §5.5's, which it cites, knows nothing of its listener's mailbox: a job taught two ways. | to decide |
| U11 | §10 sends the reader to `proposals/nodes_and_code/nodes.md` for the reasons. | to decide |
| U12 | The chapter never says what the peer runs, nor what "the same build" means, nor the two-node setup on one machine. | to decide |
| U13 | "No time means no limit" reads as the opposite of what is meant. | to decide |
| U14 | A listener's site is `Tcp.listen`, not `Tcp.accept`. | to decide |
| U15 | `Foreign.from` compared with `Io.show`, which takes a type variable. | to decide |
| U16 | §10 omits the key as the third way a process is reached. | to decide |
| U17 | A value that does not fit a segment's width fails to match in a pattern and faults only when built. | to decide |
| U18 | "Two ways" out of a node's Ernest code; bytes and TCP are a third. | to decide |

---


# Reader: the soundness argument's section 7, "Across nodes"

Read cold at commit a6612bf9: `docs/soundness.md` sections 1 to 8 against `report/language.md` (§3.11, §5.4, §6.2, §6.5, §6.6, §6.9, §6.10, §8.3, §8.4, §8.5, §8.6, §8.7, §9, §10), `report/toolchain.md` (§11.1, §11.2, §11.3, Appendix C) and `report/library.md` (E.0, E.12, E.21, E.22, E.27, G.1). Programs were run under this directory with `bin/ern 0.3.1`: `a2.in`/`b2.in` (two shell nodes), `t1`–`t3` (spawn captures), `ondemand/` (a module replaced under a running node), `t610/` (§6.10's example); node configurations in `nodes/a` and `nodes/b`.

Most serious first.

## Steps that do not follow

**A1. "Under one build the text names one declaration" is false for a shell that is a node, and a find then gives an address of another type.**
Place: `docs/soundness.md` line 223; `report/toolchain.md` §11.2 line 31; `report/language.md` §8.7 lines 806 and 820; `report/library.md` E.27 line 664.
Step: "Every node runs one build, whole, which the handshake proves before anything passes ... So a type on one node is the declaration of the same qualified name on every other ... under one build the text names one declaration, so an address a find gives has the type `Address(m)` of the key, which is the mailbox type of the process it names, and I2 holds of it."
What is wrong: §11.2 makes `ern shell --config-dir dir` "a node like any other, whose inputs find, call and send to its peers' services", and lets an input "declare what a module may". §8.7's fingerprint is "the checksum of every compiled module on its load path"; a session's module is on no load path, so two shells whose sessions declare different types have equal fingerprints and connect. §8.7 and E.27 refuse `Peer.key` only "where that type is not fully known there, or is bound": a key at a session type is allowed, and its text is the same in every session that declares a type of that name. The step's premise, one declaration per text, fails exactly where §11.2 says the rules of nodes apply unchanged.
Program (two shell nodes, `nodes/a` listing `b`, `nodes/b` listing `a` with `"keys": {"x": ["a"]}`):
```
# shell a (a2.in)                                   # shell b (b2.in)
type T = Put(Int)                                    type T = Put(String)
fn loop() : Unit with T =                            let k : Peer.Key(T) = Peer.key("x")
    receive { Put(n) -> { Io.println("a's loop took a message");
                          Io.println(Int.toString(n + 1)); loop() } }
let p = spawn(loop)                                  match Peer.find(k, 5000) {
Peer.offer(Peer.key("x"), p)                             Right(a) -> { send(a, Put("boom")); Io.println("sent") }
                                                       | Left(e) -> Io.println("find failed") }
```
Run: `ern shell --config-dir nodes/a < a2.in` (kept open), then `ern shell --config-dir nodes/b < b2.in`. Shell b printed `sent Put("boom") to a's process`; shell a printed `a's loop took a message` and then `input 3:1 faulted: division by zero`. A `receive` typed against `Put(Int)` bound `n` to a `String`, and `+` was given a value of another type: claim 1 and I1 break. The cause reported is not one §7.4 gives for `+` either (the host's `badarith` surfaces as "division by zero").
Section 8's "Sessions" bullet (line 233) says section 7 answers the question "for nodes under one build"; it does not for this node.
Fix: §8.7 or §11.2: in a shell that is a node, `Peer.key` at a type the session declares is refused, naming MVP 3.1 as `:load` does; section 7 then says a shell node offers and finds at the build's types alone, and section 8 lists the shell node as left meanwhile.

**A2. The handshake proves less than "one build": the standard library is not in the fingerprint.**
Place: `docs/soundness.md` line 223; `report/language.md` §8.7 line 806; `report/toolchain.md` §11.1 line 19.
Step: "two nodes whose builds differ never connect (§8.7)".
What is wrong: §8.7's fingerprint is "the checksum of every compiled module on its load path ... the standard library is not in it, `ern`'s version standing for it", while §11.1 itself contemplates "another build of `ern`, another version or the same version's code changed". Two nodes of one `ern` version whose standard libraries differ (one tree patched and rebuilt, `ern --version` unchanged) connect, and a type the standard library declares, `Fs.Entry`, `Peer.Failure`, a `Tcp` message type, may be two declarations under one text; a key at one, a message holding one, or a spawned build function that sends one then crosses as A1's does.
Program: not run here (needs two installations); the command: change a constructor of a standard library type on one machine, `make`, start a node on each, offer and find a key at that type.
Fix: put the standard library's module digests, or the digest of `ern`'s own code, in the fingerprint; or section 7 names "the same standard library on every node" as assumed, beside "a peer is trusted whole".

**A3. "A declaration's name, which captures nothing" does not follow: a local `fn` is a declaration and captures.**
Place: `docs/soundness.md` line 225; `report/language.md` §3.11 line 261, §5.4 lines 464 and 466.
Step: "Its function is a declaration's name, which captures nothing, or a lambda written in the definition, whose captures are the locals its body names, and the spawn is refused where one of them is bound".
What is wrong: §3.11 admits "the name of a `fn` or `foreign fn` declaration, which captures nothing"; §5.4 says "A statement is a `fn` declaration" and that a local `fn` "sees the bindings in force at its declaration", so a local `fn` is a declaration that captures, and by the report's letter `Peer.spawn("b", work, ms)` with `fn work() = ... g(1) ...`, `g` a lambda bound before it, carries a function to the peer. The toolchain refuses it (`t1/main.ern`), but as "a function that came as a value, whose captures the compiler does not see", against the report's letter and in the safe direction. The argument's step rests on a reading of "declaration" the report does not state.
Fix: §3.11 and section 7: "the name of a top-level `fn` or `foreign fn` declaration".

**A4. "No bound value crosses" is contradicted two sentences later and by §3.11.**
Place: `docs/soundness.md` line 225; `report/language.md` §3.11 line 261.
Step: "That no bound value crosses is by the three refusals. ... An adapted address crosses with its captured values as payload".
What is wrong: `via`'s function may capture a function or a table (nothing refuses it: "No other operation is checked, and nothing is looked through at a send"), and §3.11 says in one breath "A value of a bound type never crosses" and "an adapted address crosses with the values its function captured as payload". The terms of bound values do cross. What keeps I1 and I2 is weaker and is what the argument should state: nothing on the other node reaches the payload but a `send` through the address, which goes back to the node that made it (§6.5, §8.7), and `Process.fromAddress` looks "through every via" to the process (E.21).
Fix: section 7 and §3.11: "no bound value crosses *as a value*; an adapted address carries its captures as payload, which no operation on another node reaches".

## Where section 7 and the rules disagree, and where the report is silent on what section 7 assumes

**A5. §6.10's cross-node example is refused by the rule section 7 restates.**
Place: `report/language.md` §6.10 line 685 against §3.11 line 261; `docs/soundness.md` line 225.
Step: section 7: "A spawn is refused where its function's mailbox type is bound or holds a type variable". §6.10: "`let _ = Peer.spawn(name, fn() = send(Counter.service, Upgrade(migrate = Counter.double, next = Counter.count2)), 5000)`".
What is wrong: the lambda's mailbox type is `send`'s effect variable, and §3.11 refuses a spawn on a peer whose mailbox type "holds a type variable there". `t610/src` builds §6.10's example as written and is refused: `Peer.spawn starts a process whose mailbox type a is not known whole here`; `t610/src_annot`, with `fn() : Unit with Never = send(...)`, builds. The one code-replacement path across nodes the report gives does not compile, and section 7, which reads §3.11 and is asked to read §6.10, does not say so.
Fix: §6.10's example: `fn() : Unit with Never = send(...)`.

**A6. How a peer tells that it does not "have" a session's module is a claim of the runtime no section states.**
Place: `docs/soundness.md` line 223; `report/language.md` §8.7 line 818; `report/toolchain.md` §11.2 line 31.
Step: "a peer runs a spawned function only where it has the function's module, at the version the function was compiled in ... so another shell's module of the same host name starts nothing (§8.7, §11.2)".
What is wrong: §8.7's frame carries "`f` as a reference to its code, its module and its place there, the values it captured, and the spawn's site", and no version; §11.2 says only that a session's module is one "which no peer has". Under one build the fingerprint fixes a build module's version, but what makes a session module one "no peer has" when the peer is another shell with a module of the same host name is stated nowhere; the argument supplies it. The toolchain does it (`Peer.spawn("a", f, 5000)` from shell b, with `fn f` declared at both prompts, answered `Left(NotLoaded)`), on a rule the report does not hold it to.
Fix: §8.7: what the frame names a module by, so that a session's module is named as no other node names one (a name of the session's own, or the module's digest), and section 7 cites that.

**A7. The report says modules are loaded "on demand"; the argument needs them loaded at the fingerprint.**
Place: `docs/soundness.md` line 223; `report/toolchain.md` §11.2 line 31; `report/language.md` §8.7 line 806.
Step: "Every node runs one build, whole, which the handshake proves".
What is wrong: §11.2 says `ern run` "loads the module and, on demand, the modules on the load path", and §8.7 computes the fingerprint "at its start"; a module the program does not depend on, spawned later by a peer (§8.7 allows it where it has no bindings), would then be read from disk after the fingerprint was taken, and a rebuild under a running node would escape the handshake. The step holds only where a node reads its load path whole at start. It does: in `ondemand/`, node a ran `main.erc` (no dependency on `Extra`), `extra.erc` on its load path was replaced by a build with `Put(String)` while it ran, and a spawn of `Extra.f` from node b ran the version a had at start (`v1 got 2`). The report is silent on it, and section 7 assumes it.
Fix: §11.2 or §8.7: a node reads every module of its load path at its start, and the fingerprint is of those.

## Clarity

**A8. I3 does not count the callee node's note, which holds the reply.**
Place: `docs/soundness.md` lines 57, 109 and 225; `report/language.md` §8.7 line 816.
Step: "A reply crosses inside a message, to one holder, as on one node ... I3 holds with the processes of every node as one configuration."
What is wrong: §8.7: "A call to a process of another node sends that node a note that this caller waits, with its reply, and the node keeps the note until the call is over." I3 counts a reply in "one process's expression ... or in one message"; the note is a third place, absent from the configuration of section 3. The note answers nothing, so I3's consequence stands, but the step is not made.
Fix: one sentence: the note holds the reply only to end the call, as the caller's monitor does on one node, and is counted with the caller.

**A9. The sources of a remote address are listed incompletely.**
Place: `docs/soundness.md` line 223; `report/language.md` §8.7 line 818.
Step: "every one it holds came from a find, from a spawn, or inside a message whose type was agreed by one of the two".
What is wrong: a function spawned on a peer carries "the values it captured", which hold addresses too (`let me = self()` captured, a found address captured), remote from the peer's view; the same reasoning covers them (unbound captures, one build), but the enumeration misses them.
Fix: add "or in the values a function spawned on a peer captured".

**A10. Section 8 cites what is outside the report.**
Place: `docs/soundness.md` line 233.
Step: "which section 7 answers for nodes under one build and MVP 3.1's hashes answer for code that crosses".
What is wrong: the argument is "of the report"; MVP 3.1 and its hashes are in no section, and the bullet leaves out what A1 shows section 7 does not answer.
Fix: "which section 7 answers for a program's nodes under one build, and leaves for a shell that is a node".

## Checked and holding

- A lambda that captures a reply is refused at `Peer.spawn` (`t2`), as §6.6's letter (first argument of `spawn` or `spawnMonitored` only) requires; so a reply crosses inside a message alone, as section 7 says.
- A lambda at the spawn that captures a function is refused (`t3`), as §3.11 says.
- A function declared at one shell's prompt is not started by another shell of the same build (`Left(NotLoaded)`), as section 7 says, though on a rule the report does not state (A6).

---

# Readers P and K: the node sections of the report, at a6612bf9 (2026-10-08)

Read: report/language.md, report/toolchain.md, report/library.md, whole, then §3.11, §8.3, §8.7, §6.10's peer sentence, §11.2's node jobs, §11.3, Appendix C, E.27 and G.4 to G.6 with care. Programs were tried under `/tmp/.../scratchpad/readers/kp/` (`t/`, `two/`, `clean/`, `scan/`, `dlo/`, `q/`, `j/`, and the configuration directories `n1`, `nA`, `nB`, `nC`, `v_*`); the toolchain is `bin/ern`, version 0.3.1, with `build/libs/load` and `build/libs/json` on the load path where a program needs them. Line numbers are the files' at this commit.

## P, the principles

### Defects

**P1. (1, 5) Two names of the standard library are not functions.** language.md §3.11 l.261: "`Peer.spawn` and `Peer.spawnMonitored` are called where they are named, and are not taken as values", and "The function a spawn on a peer starts is the name of a `fn` or `foreign fn` declaration ... or a lambda written in the same definition". Every other operation of Ernest is a function value (§4.8 l.370: "every other operation is a function"), `spawn` among them (§6.9 l.656: "Where `spawn` is passed as a value"). A reader who knows the rest of Ernest writes what §6.5 l.591 shows, `spawn(restarting(RestartLimit(...), logger))`, and on a peer `Peer.spawn(name, restarting(limit, logger), ms)`; it is refused, and so is `let s = Peer.spawn`:

    fn work() : Unit with Never = Unit
    export fn main() : Unit with Never = {
        let _ = Peer.spawn("store", restarting(Unlimited, work), 1000);   // refused: "starts a function written where the compiler sees what it captures"
        let s = Peer.spawn;                                                // refused: "is called where it is named"
        Unit
    }

The program must write `fn() : Unit with Never = restarting(Unlimited, work)()`. The two restrictions exist for one thing, the capture check of §3.11; neither buys a program anything of its own. Fix: either name the form in §5.2 as a third kind of callable (a form that reads as a call), or make "crosses" a restriction of the lambda's type scheme, as not-reply-carrying is (§3.9), so that `Peer.spawn` is an ordinary function whose parameter carries the restriction and a function that came as a value is refused by its type.

**P2. (5) The count of what the compiler makes grew by a kind, and the compiler names four library types.** library.md E.27 l.664: "`key`, a value the compiler makes"; language.md §8.7 l.820: "`Peer.key("counter")` makes one at the type the compiler finds where it is written". With `Io.show`/`Io.debug` (E.1) and `Foreign.from` (E.12) that is a fourth name whose value the compiler writes from the use's type. §3.11 l.261 also has the compiler know `Ets.Table` (an informative library's type, G.1), `Tcp.SocketMsg`, `Tcp.ListenerMsg` and `Os.ProgramMsg` by name as resources, a list no rule lets a library extend: a library's own handle (a port it opens through a `foreign fn`) crosses, and nothing says it may not. Fix: a rule by which a type says it is bound (a foreign type is already bound; make a resource's message type `foreign type`, or add one word to its declaration), so the compiler names nothing.

**P3. (2) One service, two ways to reach it, and one place, two ways to spawn at it.** language.md §6.5 l.586: a process reaches a service "through a top-level binding ... or, from another node, through a key"; §8.7 l.820: "Only what a node offers can be found"; library.md E.27 l.664: "the running node is no peer of itself". So a node cannot `Peer.find` its own offer, and `Peer.spawn` cannot name the running node. Code written once for "wherever the counter is" writes both, and G.5 l.749 shows the same split for spawning: "with `spawn` for `Here` and with `Peer.spawn` for `On(name)`", with a type `Place = Here | On(String)` that exists only because of it. A reader who knows Erlang (`spawn(node(), F)`, a registry that answers for the local node too) predicts one operation. What the split buys: a local `send` and `spawn` stay total and free. Fix: let a node list itself under a name in `ernest.conf`'s `keys` (a find that reaches the running node answers its own offer), or state in §8.7 that placement-independent code is written as G.5 writes it.

**P4. (1, 3) In a spawned function one name means two processes.** language.md §8.7 l.818: "In the spawned function a top-level binding is the peer's, a value it captured is the spawner's". `fn() = send(service, m)` sends to the peer's service; `let s = service; fn() = send(s, m)` to the spawner's. A reader who knows Erlang predicts a closure to carry the values of its free names, so `service`, a value computed at initialization (§4.6), would be the spawner's; Ernest departs, and states it, but §6.10 l.685 then calls `Counter.double` and `Counter.count2`, two `fn` declarations, "top-level bindings", where Appendix F l.1238 says a top-level binding is "a value bound at file scope by a `let`". Fix: §8.7 says "a top-level `let` and a declaration's name are the peer's"; §6.10 says "names the service and the new functions by their declarations".

**P5. (2) Two error types overlap.** library.md E.27 l.668: `type Failure = NotListed | Unreachable | Refused(String) | Timeout | NotOffered | OtherType | NotLoaded`; E.1 l.148: `type Error = ... | Refused | ... | Timeout | ...`. `Timeout` and `Refused` now name one thing in two types, and `Unreachable` is `Reason`'s word too (§9.3 l.865). E.1 says "`Error` is the error of every system module", and `Peer` is none, so the letter holds, but a reader predicts either `Either(Io.Error, ...)` with `Other(text)` or a `Failure` with no constructor `Io.Error` has. Fix: decide which, and say in E.27 why `Peer` has its own.

**P6. (5, "exists only for another") `measures` is a rule of the normative report for an informative library.** language.md §8.7 l.798 (the `measures` section, its three names, `check-interval`, `almost-full`), l.804 ("A change to `measures` starts or stops the host's services it names") and toolchain.md Appendix C l.183 serve library.md G.4 alone, which is "Informative" (G l.681): nothing of the language or the runtime reads a measure. Fix: either G.4 is normative (a standard library module), or `measures` and its rules leave §8.7 and Appendix C for the library's own page.

### Clarity

**P7. (2, 1) One shape, two meanings; one name, two units.** library.md G.4 l.741: `Load.schedulers : (Int) -> Float with m+`, "over the next `ms` milliseconds, which it waits for": milliseconds last is E.0 shape rule 8's shape (l.140) for a bounded wait that answers `Left(Timeout)`; here they are a window and the answer a `Float`. language.md §8.7 l.798: "`check-interval`, in milliseconds, and for `memory` a whole number of minutes": one parameter, one name, and a unit rule for one measure only (see K9 for what the node does with `disk`'s).

**P8. (5) A directory a program "has" and nothing reads.** toolchain.md §11.3 l.85: "a program started without `--config-dir` is no node, and `./.ernest` is its directory"; Appendix F l.1127 the same. `ern config` creates it by default, and no job reads it without `--config-dir` (§11.2 l.81: "Without `--config-dir`, `./.ernest/startup` is not run"). The concept buys nothing; drop the sentence, or let `ern run` take `./.ernest` where it exists.

**P9. (1) `Peer.nodes` answers peers.** library.md E.27 l.674: "the names of the peers, in the configuration's order"; §8.3 l.745 defines a node as this runtime and a peer as another. A reader looks for `Peer.peers` or `Peer.names`.

**P10. (4) Nothing to report.** The sections add no grammar; Appendix A is as it was. Appendix C is JSON, read by the host.

### P's counts, and how each was counted

- **Reserved words: 18**, the words in §2.4's table (language.md l.81 to l.88), counted by hand; unchanged. `needs` and `derives` (l.90) are read by position and are not reserved.
- **Words read by position: 13**, the 11 bitstring specifiers of `BitSpec` (Appendix A l.1011 to l.1015: `size`, `bytes`, `int`, `float`, `utf8`, `utf16`, `utf32`, `big`, `little`, `signed`, `unsigned`) and `needs`, `derives` (§2.4 l.90). Appendix A has three more terminals that are identifiers elsewhere, `compare`, `negate`, `show` (`Member` l.961, `DeclName` l.966): 16 by that count. The node sections added none. (The brief's 12 counted the specifiers alone; I cannot reproduce 12.)
- **Taken top-level namespaces: 29**: `Prelude`, the eight prelude types with a member in §9 (`Int`, `Float`, `Char`, `String`, `Bytes`, `List`, `Path`, `Address`; §4.2 l.297, §9.5, §9.6), and the 27 module namespaces of E.1 to E.27 (`grep -c '^### Appendix E\.[0-9]*\. \`' library.md` = 27), of which seven coincide with the eight. `Peer` (E.27) is the one the node sections add. The six libraries of Appendix G (`Ets`, `Markdown`, `Ansi`, `Load`, `Balancer`, `Json`) are not taken by §4.2's words; 35 with them, the brief's number.
- **Prelude functions: 33**, the names of §9.4 to §9.6 (l.877 to l.917): 4 in §9.4 and `Io.show`, `Io.debug` (6), 7 in §9.5, 20 in §9.6 (`Int.+ - * / %` 5, `Int.negate`, `Float.+ - * /` 4, `Float.negate`, four `<>`, four `compare`, `fault`). 31 without `Io.show` and `Io.debug`, which `io.ern` provides. By §9 l.824's own criterion ("a function is the prelude's where a rule of this report names it, or where no declaration ... could give it its meaning") `Peer.key`, `Peer.offer`, `Peer.find`, `Peer.spawn` and `Peer.spawnMonitored` are the prelude's too, 38; see K19.
- **Prelude types: 21**: 10 in §9.1 (`Int`, `Float`, `Char`, `String`, `Bytes`, `Bool`, `Address`, `Reply`, `Never`, `Process`), 3 in §9.2, 8 in §9.3 (`Unit`, `Optional`, `Either`, `Ordering`, `Down`, `Reason`, `RestartLimit`, `Path`). The node sections added a constructor, `Reason`'s `Unreachable`, and no type; `Peer.Key(m)` is named by rules (§3.11, §8.7) and is E.27's, 22 by §9 l.828's criterion. (The brief's 25 I cannot reproduce from the listing.)
- **Primitives outside §9: 7**: the type-directed `Io.show`/`Io.debug` (E.1), `Foreign.from` (E.12), `Peer.key` (E.27, "a value the compiler makes"), `Peer.spawn`/`Peer.spawnMonitored` (§3.11, checked and not values), the supervisor's restart request (E.22 `askRestart`), the system references (§8.2), and the compiler's list of resource types (§3.11). The node sections added three of the seven.
- **Concepts: 116**: Appendix F has 141 entries (`grep -c '^- \*\*'` from l.1105); minus 11 of the toolchain (build root, compiled interface, configuration directory, diagnostic, line mode, live region, load path, runner, source root, span, startup file), 13 of the library (admission rule, child, container, grapheme, group, sequence, shape rule, shim, standard library, strategy, supervisor, system module, vocabulary) and "primitive". The node sections' entries: bound type, connection, gateway, key, loss, node, peer, remote computation (8). §8.7 uses 11 more terms without an entry: fingerprint, handshake, detector, tick, carrier, frame, note, offer, the start's number, dial, measure (see K12), 19 node concepts in all. (The brief's 90/79 is of an older glossary; the entries have grown by 51 since, most not from nodes.)

### P's table of the rules

Each rule of the sections: what it buys a program, and what the language would lose without it. "Little" and "only for another" are marked.

| Rule (place) | Buys a program | Lost without it |
|---|---|---|
| A message may hold a function (§3.11 l.261) | `Upgrade` and callbacks in messages on one node | code replacement (§6.10) |
| A bound type: function, foreign, resource, address/reply of one (§3.11) | a message from a peer needs no code and names no dead handle | a value on a peer that cannot be used there, met at run time |
| The three refused operations: key of a bound type, spawn capturing a bound value or a type variable, spawn with a bound mailbox (§3.11) | the refusal at compile time, not a fault at a send | the same faults at run time |
| Key type and spawned mailbox type known whole (§3.11, §8.7) | a key's text and a typecheck at both ends | a key found at any type |
| The spawned function is a declaration's name or a same-definition lambda; `Peer.spawn` not a value (§3.11) | nothing of its own: **only for** the capture check (P1) | nothing, if the check were a restriction of the type |
| Nothing looked through at a send; an adapted address crosses as reference and payload (§3.11, §6.5) | a send between nodes costs the host's send | a scan of every message |
| Values cross in the external term format with no type (§3.11, §8.4) | messages are values only; one build at both ends | a typed wire format |
| A node is a program with `--config-dir`; without it, no peers (§8.3) | a program is a node by how it is started, not by its text | a program that is a node by itself |
| `Peer` acts by a peer's listed name (§8.3) | no address or key in the program; the operator moves a peer by editing a file | hosts in the code |
| "Every node runs the same compiled program, whole" (§8.3) | nothing: false as a rule (K8); **exists only to** make "no code crosses" plausible | nothing |
| A remote `Upgrade` by a spawn on the peer naming the build's functions (§6.10 l.685) | switching a remote loop within one build | nothing a program can use now: no new code reaches a node (one build; a node-shell has no `:reload`), so **little** |
| Identity by a self-signed key; `ern config`; copies are one node; permissions refused (§8.7 l.796) | authentication, and a stolen directory found | impersonation |
| `listen`, one family, port 0 (§8.7 l.798) | a node that only dials; a test node on any port | the operator picks ports |
| A peer by name, key, address; no address means never dialled (§8.7 l.798) | a peer behind a NAT that dials in | every peer reachable both ways |
| Family check when read; name resolved at each dial (§8.7 l.798) | a peer that moves without a restart | — ; the read-time check is best-effort (K17), **little** |
| `keys`: which peers may offer a name, in order (§8.7 l.798) | where a service lives is the operator's | a registry in the code |
| `measures` (§8.7 l.798, l.804; App. C) | **only for** G.4 (P6) | nothing of the language |
| Refusals at start naming file and rule (§8.7 l.798) | a wrong file found before anything runs | a node that runs wrong |
| A start number in every address (§8.7 l.800) | an address of an earlier start is dead | messages to a reborn node's old processes |
| Listen and dial only after the initializers (§8.7 l.800) | a spawn never reaches a binding without a value | spawns in a half-initialized node |
| `ernest.pid` (§8.7 l.800) | `ern reload`/`ern stop` by directory | the operator finds the pid |
| A node stops in order; `Down`s cross first (§8.7 l.800, §8.6) | a peer's monitor says `ProgramEnd`, not `Unreachable` | a program that cannot tell an end from a loss |
| What a node says, one line each, with time (§8.7 l.802) | an operator's log | silence |
| Reload: hangup; what each change does; key and listen fixed (§8.7 l.804) | peers added and removed without a restart | a restart for every change |
| One connection, TLS 1.3, listed keys only, not transitive (§8.7 l.806) | a closed set of nodes | a mesh the program did not ask for |
| Fingerprint equality before anything passes (§8.7 l.806) | one build at both ends, so no type crosses | a message a peer cannot read |
| Six frames; one gateway, a worker per peer (§8.7 l.808) | a peer's slow adapted function delays that peer alone | one process for all peers |
| A faulty frame ends the connection; a message to no process is dropped and said (§8.7 l.808) | a loss rather than a hang | — |
| Loss: ticks every 15 s, four silent intervals; closes found at once; dial given up after 7 s (§8.7 l.810) | a bound on silence (K16 on the numbers) | a hang on a silent peer |
| A loss gives `Unreachable` to each monitor, ends each call, drops the buffer, and nothing else (§8.7 l.810) | one event, stated whole | a program guessing what a loss did |
| No reconnect in the background; next operation dials (§8.7 l.810) | no traffic the program did not ask for | — |
| An address outlives a loss; a monitor does not (§8.7 l.812) | the same address after a loss | a program that must find again; the second half exists for the runtime (nothing to redo), the program pays a `monitor` again |
| 1 MB buffer; a full buffer blocks the sender (§8.7 l.814) | backpressure the program sees as a slow send | unbounded memory |
| Order kept per sender; never dropped alone; at most once (§8.7 l.814) | Erlang's guarantees, stated | — |
| A call's two notes; a restart ends its calls (§8.7 l.816) | `None`/`callee was restarted` across nodes as on one | a call that waits forever on a restarted callee |
| A spawn's frame, time bound, late answer kills, `NotLoaded` by module (§8.7 l.818) | a bounded spawn with a value answer | a spawn that faults for the network |
| A key: name and type text; offer while alive; fault on a double offer; find in `keys`' order; failures passed over (§8.7 l.820) | a service found by name at its type, with the configuration deciding where | a registry, or addresses in files |
| `--config-dir` on run/test/shell; host started twice (§11.2 l.31) | one option makes a node; the second sentence states no rule (K20) | — |
| `:load`/`:reload` refused in a node shell, MVP named (§11.2 l.31) | an honest refusal | a shell of another build on the carrier |
| `ern reload`, `ern stop` (§11.2 l.35) | the two signals by name | `kill -HUP`/`-TERM` by pid |
| `ern config` makes key, certificate, `ernest.conf`, prints the public key (§11.3) | one command to a node | hand-made keys |
| `./.ernest` for a non-node (§11.3 l.85) | nothing (P8), **little** | nothing |
| Appendix C's example | the file's shape | guessing (`measures` still guessed, K18) |
| E.27's six functions and `Failure` | the node's operations as values and a failure a program matches on | — ; `Refused` unproduced (K6) |
| `Peer.nodes()` | the peers' names without reading the file | `Fs` and `Json` over `ernest.conf` |
| G.4 `Load` | a load for a balancer | — ; `schedulers`' shape (P7) |
| G.5 `Balancer`, `Place` | a worked placement | — ; `Place` exists only because `Peer.spawn` excludes the running node (P3) |
| G.6 `Json` | the configuration's format for programs | a program writing a parser (which E.0 forbids) |

Rules whose answer is little or that exist only for another: the two restrictions on `Peer.spawn`'s function (P1); §8.3's "same compiled program, whole" (K8); §6.10's remote `Upgrade` sentence; the family check at read time (K17); `measures` (P6); `./.ernest` for a non-node (P8); §11.2's "starts the host twice" (K20); G.5's `Place` (P3); E.27's `Refused` (K6).

## K, the cold reader

### Defects

**K1. A normative example does not compile.** language.md §6.10 l.685: "`let _ = Peer.spawn(name, fn() = send(Counter.service, Upgrade(migrate = Counter.double, next = Counter.count2)), 5000)`". §3.11 l.261: "the mailbox type of a process spawned on a peer [is] known whole where [it is] written: one that holds a type variable there is refused". The lambda's effect is a process-only variable (`send`'s `m+`), not known whole; `bin/ern build t1.ern` says `Peer.spawn starts a process whose mailbox type a is not known whole here ... give the function its mailbox type, fn() : Unit with Never = ...`. §6.2 l.566 and §8.1 l.721 take a free mailbox type as `Never` for a local spawn and an entry point; §3.11 does not. Fix: write `fn() : Unit with Never = send(...)` in §6.10, or let §3.11 take a free effect as `Never` as §8.1 does.

**K2. A peer's public key that is no key crashes `ern` at start and disarms the node on reload.** language.md §8.7 l.798: "A node refuses to start where `ernest.conf` ... breaks a rule of this paragraph ... the refusal names the file and the rule"; l.804: "a file that changes either, or that does not parse, is refused, and the old configuration stays". With a peer whose `public-key` is a PEM whose body is altered (`v_badkey/ernest.conf`): `ern run --config-dir v_badkey n.erc` prints `ern: internal error: exception error: no match of right hand side value {error,{asn1,{{wrong_tag,...` and exits 70, a failure of `ern` itself by §11 l.15. On `ern reload` with the same change, the node prints the host's crash report on standard output (`** gen_event handler ern_signals crashed. ... Last event was: sighup ... {ern_node,public_key_der,3,...}`), keeps running, and takes no further signal: `ern stop --config-dir nA` exited 0 and the node ran on to its own end (`A2.out`: `A: done`, `A2 exit 0`). Fix: a public key that does not decode breaks a rule of the paragraph, refused at start and at reload with the file and the rule; the handler never crashes.

**K3. The node says what the report does not list, on the wrong stream and without the time, and not what it lists.** language.md §8.7 l.802: a node says on its standard error "what a reload did ... Each line ... its time first"; l.804: "The node says ... that it read `ernest.conf` again and each peer added, removed or renamed"; l.802: "the host's own reports of its nodes are not written". Observed on a reload that added a valid peer `c` (`A4.err`): the one line `ernest.conf was read again`, no time, no `c`; and on standard output (`A4.out`) the host's `=WARNING REPORT==== ... ** Undefined handle_info in ern_signals ** Unhandled message: {'EXIT',#Port<0.6>,normal}`, which every reload prints, refused or not. A node whose `measures` names `cpu` prints the host's `[os_mon] cpu supervisor port (cpu_sup): Erlang has closed` as it ends. Fix: the signal handler takes the port's exit silently; the reload line carries the time and each peer added, removed or renamed; os_mon's line is swallowed at the node's end.

**K4. A deadlocking test never ends on a node.** toolchain.md §11.2 l.33: "A deadlock while a test runs (§8.6) is that test's fault, and the run goes on with the next test"; language.md §8.6 l.792: "A node (§8.3) detects no deadlock". Neither says which wins under `ern test --config-dir`. `dlo/dl.ern` (a test whose `run` is `receive { _ -> Test.Passed }` at `Test.Case(Int)`): `ern test dl.erc` prints `waits: faulted: deadlock`; `ern test --config-dir n1 dl.erc` hangs (killed by `timeout 20`). Fix: §11.2 says that on a node a test that waits forever is not found, or `ern test --config-dir` keeps the detector for the test's process.

**K5. A node refuses to start for a `.erc` the program never uses.** language.md §8.7 l.806: "the checksum of every compiled module on its load path". A root holding `n.erc` (which names nothing) and an unused `t7.erc` (which names `Load`, not on the path): `ern run --config-dir v_nolisten n.erc` says `ern run: cannot find module Load (load.erc) on the load path`, exit 1; `ern run n.erc` from the same root runs. No sentence says a node resolves the dependencies of modules on its path that it does not load, nor that a stray `.erc` refuses the node. Fix: state it under **Connections** (the fingerprint reads each module and refuses a module whose dependency the path lacks), or digest the code alone.

**K6. `Refused` is met by a find in §8.7 and never in E.27, and nothing produces it.** language.md §8.7 l.820: "The find passes over `Unreachable`, `Refused`, `NotOffered` and `OtherType`"; library.md E.27 l.664: "a find meets `NotListed`, `Unreachable`, `Timeout`, `NotOffered` and `OtherType`, and a spawn `NotListed`, `Unreachable`, `Timeout`, `Refused` and `NotLoaded`". E.27 l.677: "`Refused(text)`, the peer refused what was sent, with its reason" — no sentence of §8.7's **A spawn** (l.818) has a peer refuse a spawn; a handshake refusal is `Unreachable` (l.806, E.27 l.677). Fix: drop `Refused` from §8.7's find sentence; say in l.818 when a peer answers `Refused` (a process the host cannot start?), or remove the constructor.

**K7. Appendix B describes a fault no rule produces in a situation no rule allows.** language.md Appendix B l.1092: "Sent to a worker on another node, the message faults the sender (§3.11)". §3.11 l.261: "No other operation is checked, and nothing is looked through at a send", and `WorkerMsg` holds a function, so `Address(WorkerMsg)` is bound ("an `Address(m)` ... whose `m` is bound") and no process on another node can hold it: `t9.ern` is refused at the capture, `whose type Address(WorkerMsg) is bound to its node, since it holds an address whose message type holds a function`. Fix: "A worker on another node cannot be given it: `Address(WorkerMsg)` is bound (§3.11)".

**K8. §8.3 and §8.7 disagree on what is the same on every node.** language.md §8.3 l.745: "Every node runs the same compiled program, whole"; §8.7 l.806 proves only that the load paths' modules are equal, and l.818 answers `NotLoaded` "where a binding of that module, or of one it depends on, has no value on the peer", which by §8.5 l.786 ("another module the program does not depend on is not initialized") happens only where peers run different programs of one build. Shown with `two/`: node A runs `a.erc`, node B `b.erc`, one root; from B, `Peer.spawn("a", Extra.job, 5000)` (Extra has a `let`, A's program does not depend on it) answers `NotLoaded`, and `Peer.spawn("a", Plain.job, 5000)` (no `let`) runs on A. Fix: §8.3 says "Every node runs one build (§8.7)", and §10 l.940 already does.

**K9. The node checks rules the report does not state, and lets one through that the host truncates.** language.md §8.7 l.798 lists the refusals. Observed refusals with no sentence: `key "counter" names "ghost", which is no peer's name` (`v_keys_unlisted`); `a peer has no name` (`v_emptyname`); `measures is not a JSON object` (`v_meas_list`); `two peers have one public-key, and two nodes with one key are one node` (reload 1 of `nA`; perhaps l.798's "names a ... key twice", but "key" there could be a `keys` entry). And `disk`'s `check-interval: 90000` is accepted (`v_meas_disk` ran) though the host counts minutes for `disk` as for `memory`, whose `90000` is refused (`measures' memory' check-interval is not a whole number of minutes`); §0 l.39 has a silent truncation met by a check. Fix: state each refusal in l.798; refuse `disk`'s too.

**K10. A reload refuses more than the two reasons stated.** language.md §8.7 l.804: "a file that changes either, or that does not parse, is refused, and the old configuration stays". The node refuses a file that parses and changes neither (`the reload was refused, and the configuration stays as it was: ... two peers have one public-key`). Fix: "a file that breaks a rule of **Its configuration**, or that changes either, is refused".

**K11. `ernest.pid` outlives a refused start.** language.md §8.7 l.800: "A node writes its process number to `ernest.pid` ... and removes it at its exit". After K5's refusal `n1/ernest.pid` held the dead process's number; the next start overwrote it ("a file a dead one left"), so it is recoverable, but the sentence does not hold. Fix: write the file once the node will run, or remove it on a refused start.

### Clarity

**K12. Terms of §8.7 without a glossary line, and one word for three things.** language.md Appendix F l.1105: "Every technical term this report introduces". §8.7 uses: fingerprint (l.806), handshake (l.806), the detector (l.810, "when the detector finds it silent", before any sentence names what it is), tick (l.810), frame (l.808), note (l.816), offer (l.820), the start's number (l.800), dial, measure (l.798); §10 l.937 and §11.2 l.31 use carrier. None has an entry. And "key" is the node's key (l.796), an entry of `keys` (l.798) and a service key `Peer.Key(m)` (l.820): l.798's "names a peer or a key twice" cannot be read without guessing which.

**K13. `Peer.key`'s annotation request is not in §3.9's list, and "where it is written" is loose.** language.md §3.9 l.243 lists where inference asks for an annotation; `Peer.key` at a type not known whole (§8.7 l.820, E.27 l.664) is missing, though the toolchain asks (`annotate the key where it is bound`, `t3b.ern`). "at the type the compiler finds where it is written": a later use in the same definition does fix it (`t3.ern`: `let k = Peer.key("counter"); Peer.offer(k, service)` compiles), and so does `let mk = Peer.key; let k : Peer.Key(Msg) = mk("counter")` (`q2.ern`). Fix: add `Peer.key` to §3.9's list, and say "once its definition is inferred (§4.8)".

**K14. "the peer has its module" is on its load path.** language.md §8.7 l.818: "A function spawned on a peer runs there only where the peer has its module". "Has" is neither loaded nor initialized: `Plain.job` (K8) runs on a peer whose program never names `Plain`. Say "on its load path (§11.2)".

**K15. A bound value does cross, as payload.** language.md §3.11 l.261: "A value of a bound type never crosses" and, in the same paragraph, "an adapted address crosses with the values its function captured as payload"; §6.5 l.584 likewise. Say "is never used on another node", or "crosses only as the payload of an adapted address".

**K16. The loss arithmetic does not give its numbers.** language.md §8.7 l.810: "a tick is sent where nothing else was for 15 seconds; a peer from which nothing came in four such intervals is lost, so a silence is found in 45 to 75 seconds"; §10 l.941 "within 45 to 75 seconds". Four intervals of 15 s is 60 s, and a check at each tick finds a silence between 60 and 75 s after the last traffic. Either the rule is told in other terms than the host's or 45 is wrong.

**K17. Resolution at read time is best-effort and unsaid.** language.md §8.7 l.798: "a peer whose address is of the other family, or whose name resolves only to it, is refused when the configuration is read" and "a name is resolved by the host at each dial". A name that does not resolve at read time is accepted (`v_dns`, `no.such.host.invalid`, the node ran). Say what an unresolvable name does when read, and that the family of a name is checked only where it resolves then.

**K18. Appendix C leaves `measures`' shape to be guessed.** toolchain.md Appendix C l.183: "`measures`, absent here, names the host's measures ... each with the host's parameters under it" — an object keyed by measure name with `{}` for `cpu` was a guess that happened to be right (a list is refused, K9). Fix: show `"measures": {"cpu": {}, "memory": {"check-interval": 60000, "almost-full": 0.8}}`.

**K19. §9's criterion admits the `Peer` functions and its list omits them.** language.md §9 l.824: "a function is the prelude's where a rule of this report names it, or where no declaration ... could give it its meaning"; l.828 the same for a type. §3.11, §6.2, §6.7, §8.3 and §8.7 name `Peer.spawn`, `Peer.spawnMonitored`, `Peer.key`, `Peer.offer`, `Peer.find` and `Peer.Key(m)`, and E.27 l.664 says `key` is "a value the compiler makes". Fix: §9 says why they are the library's (as it says of `Io.show`), or lists them.

**K20. Two sentences of §11.2 state no rule a program sees.** toolchain.md §11.2 l.31: "The host takes a node's carrier only as it starts, so `ern` starts the host twice" (how the launcher works); and the refusal of `ern run --config-dir dir` "with no `.erc`" names a form the usage line already requires. Clarity only.

**K21. G.6's error words and the host's answers differ.** library.md G.6 l.762: "`UnexpectedSequence` is an escape that writes no character"; `Json.parse("\"\\ud800\"")` and `Json.parse("\"\\ud800x\"")` answer `UnexpectedEnd` (`j/t8b.ern`); `Json.parse("1e400")` answers `UnexpectedSequence(<<"1.0e400">>)`, the host's spelling, which "as the host gives it" covers, not the first. Informative appendix.

**K22. `Load.schedulers` over no time.** library.md G.4 l.737: "over the next `ms` milliseconds, which it waits for"; `Load.schedulers(0)` answers 0.057 and `Load.schedulers(-5)` 0.06 (`t/t7.ern`), a fraction of nothing. Say what a window of 0 measures, or answer for `ms` below 1 what §7.4 says of a duration.

### Silences a conforming toolchain must fill (not shown above)

- §8.7 l.798: what a node does with a `public-key` field of its own that differs from `certificate.pem` ("its key is the one `ernest.conf` and the certificate name" names two sources).
- §8.7 l.806: which "host's version" the fingerprint digests (the emulator's, the release's), and whether a `.beam` on the load path (§11.2 l.31) is "a compiled module" in it.
- §8.7 l.812: an adapted address made on a node that has since restarted: the start's number is "in every address"; whether it is in the maker's reference, so that the message is dropped rather than applied by the new start, is unsaid.
- E.27 l.664: `Peer.offer` in a program that is no node is accepted (`t/t6.ern`: the second offer faults as a living process holds the key) and nothing can find it; fine, but unsaid.
- G.5 l.749: a `measure` that answers outside 0.0 to 1.0.

---

# Reader U: the guide's chapter 8, at a6612bf9 (2026-10-08)

11 defects and 7 clarity points. Most of chapter 8's examples work exactly as the text says; the defects are false sentences around them, two inside chapter 8 and two elsewhere in the guide, and a stale preface line. Scratch programs are under the scratchpad's `readers/u/s1` to `s12`; for the two-node tests `nodeA` listened on 127.0.0.1:18654 and listed the peer `foo` (renamed `store` for the §8.2 test) with B's key, `nodeB` on 127.0.0.1:18655 listing `desk` with A's key; no node is left running.

What works as the chapter says: §8.1 `square.ern` prints `no foo: NotListed` alone and `foo computed 25` on two nodes; §8.2 `desk.ern` prints `no store: NotListed` alone and on two nodes `the counter is at 5`, then `10`; §8.4's rejected example gives the guide's error byte for byte; §8.5's three console commands give `found 42`; §8.6's `frame` and `parseFrame` work; §8.7's server echoes `hello` and `world` sent in pieces and writes `still here` at 10.0 s; §8.8's answer's error text is exact and its `Peer.spawn` works on two nodes.

## Defects

**U1. Line 1602 (§6.3):** "The loss of a peer faults every process on it (report §10)." False under either reading of "it": report §8.7 says "nothing else ends, but a process waiting in `Address.callForever`", §8.6 says "A process this program spawned on a peer runs on there", §10 says nothing of the kind, and the guide's own line 2336 says "No process of your own dies of it". Shown by `s4/watch.ern`: A killed with `kill -9` while its process waited on B, B wrote `the peer desk was lost: it closed` and no fault line; B killed instead, A's monitor got `Unreachable` and nothing on A faulted. Fix: "The loss of a peer faults no process, but one waiting in `Address.callForever` on one of its processes (§8.2, report §8.7)."

**U2. Line 2336 (§8.2, *A loss*):** "A connection breaks, a peer falls silent, or a node ends. … every monitor on the peer's processes gives one `Down` with the reason `Unreachable`". Report §8.6 and §8.7 say "A node that ends is no loss to its peers … A peer's monitor on one of its processes gives `ProgramEnd`." Shown by `s4/watch.ern` on A, then `ern stop --config-dir nodeB`: A prints `ProgramEnd site=[]`; only `kill -9` of B gives `Unreachable site=[]`. Fix: drop "or a node ends", and add that a node ending in order is no loss: a monitor on its processes gives `ProgramEnd`.

**U3. Line 134 (§0):** "**Distribution by content, planned.** Every function and type is known by a hash of its definition … Code travels only with a process spawned on a peer, and two versions of a type are two types." Contradicts the report and the guide: report §8.3 "Every node runs the same compiled program, whole, and no code crosses between nodes"; §10 "No code crosses between nodes"; §8.4 a message from a peer is not checked on arrival; the guide's own lines 2276 and 2654 say "no code crosses". "Planned" also restates the roadmap, the plan's fact; line 129's Unison clause ("ships to a peer what it lacks") only sets up this bullet. Fix: replace the bullet with what is built: one build on every node, values cross and code does not, and a bound value is refused at a key or a spawn; drop the Unison clause.

**U4. Line 13 (preface):** "The examples of peers in §8 are fragments, since the toolchain does not run peers yet." Stale: the toolchain runs peers, and §8.1 and §8.2 are complete programs with console output, which `test/ern_guide_tests.erl` runs. What the toolchain does not do yet is `docs/development.md`'s fact. Fix: delete the sentence.

**U5. Line 2278 (§8.1):** "So the work a peer runs is written in a module the peer's program depends on too, or in one with no top-level `let`." The §8.8 answer at line 2696 repeats it. Report §8.7 requires every top-level `let` "of that module and of every module it depends on" to have its value on the peer; a module with no `let` of its own still fails when a module it uses has a binding the peer never ran. Shown in `s3/`: `lazy.ern` holds `export let base : Int = 10`; `nolet.ern` has no `let` and calls `Lazy.add`; `sq2.ern` has no `let` and spawns `fn() … Nolet.compute()` on `foo`, which runs `idle.erc` from the same directory; A prints `no foo: NotLoaded`. Fix: "…or in one whose module, and every module it depends on, has no top-level `let` the peer's program has not run"; line 2696 the same way.

**U6. Line 813 (§4.1):** "`Peer.spawn(name, f)` starts one on another node (§8)." The arity is wrong: Appendix E.27 gives `Peer.spawn : (String, () -> Unit with m, Int) -> …`, and §8.1 writes `Peer.spawn(name, f, ms)`. Fix: `Peer.spawn(name, f, ms)`.

**U7. Line 2356 (§8.3):** "an Ernest process's end is an Erlang exit reason, `normal`, `{ern, fault, Text}`, `{ern, killed}`, or `{ern, program_end}`". Written as complete; report §8.4's ABI also has `{ern, fault, Cause, Trace}` (a runtime failure or a foreign raise), `{ern, closed}` and `{ern, code_unloaded}`; Erlang code that matches the three-tuple misses every foreign raise. Shown by `s10/reasons.ern` with `s10/reason_watch.erl`: a process faulting in `erlang:hd([])` exits `{ern,fault,<<"foreign function erlang:hd/1 raised error:badarg">>,Trace}`; one dividing by zero exits `{ern,fault,<<"division by zero">>}`. Fix: add `{ern, fault, Cause, Trace}`, or say "among them" and point at report §8.4.

**U8. Line 2336:** "…a `callForever` faults with `callee is unreachable` … No process of your own dies of it." The paragraph contradicts itself: a fault ends the process (report §7.3), and report §8.7 says "nothing else ends, but a process waiting in `Address.callForever` …, which faults". Fix: "No other process of your own dies of it."

**U9. Line 2245 (§8 intro):** "What a node says on its standard error, `ern reload` and `ern stop`, and running nodes day to day are the deployment guide's, which comes with MVP 3.1". Which MVP brings what is the plan's fact; `guide/` holds only `language.md`; and §9.2 (line 2585) teaches `ern reload` and `ern stop`, §8.1 (line 2280) what a node's standard error says of a fault, both working (`ern reload` printed `ernest.conf was read again`). Fix: drop the MVP clause and the deferral, and point at §9.2 and report §8.7, §11.2.

**U10. Lines 2498 and 2530 (§8.7) against lines 1360 to 1392 (§5.5): a job taught two ways.** Line 2498 says "…gives the socket to a reader of its own, as §5.5 teaches", but the two sections write the reader differently: §5.5's reader knows nothing of its listener's mailbox, `reader(listener : Address(Optional(String)))`, given `via(me, Line)`, its stated reason at line 1326 "Whoever sends need not know the type of the mailbox it sends to"; §8.7's reader takes `Address(Session)` and builds the session's own `Arrived(bytes)` and `Gone`. Fix: write §8.7's reader over `Address(Optional(Bytes))` with `via(me, Arrived)`, or drop "as §5.5 teaches" and say why it differs.

**U11. Line 2654 (§10):** "The reasons are [`proposals/nodes_and_code/nodes.md`]'s." CLAUDE.md gives rationale to `docs/decisions.md`; `proposals/` is not authoritative, and this directory is the one under discussion for MVP 3.1; line 2706 already sends the reader to `decisions.md`. Fix: point at the decisions log, or drop the sentence.

## Clarity

**U12. Lines 2245 and 2276:** "only where both run the same build" and "With a peer named `foo` in `ernest.conf`, it prints `foo computed 25`." The chapter never says what program the peer runs, nor that "the same build" means the same compiled modules on the load path with the same `ern` and OTP (report §8.7). Shown: B running `idle.erc` from `s3/` while A runs `square.erc` from `s1/`, A prints `no foo: Unreachable`, B says `the peer desk was refused: it runs another build`. Also unsaid: two nodes on one machine need two `listen` ports, both defaulting to `0.0.0.0:8654` (report §11.3); the PEM that `ern config` prints goes into the JSON as one string with `\n`; one key listed under two peer names is refused, `two peers have one public-key, and two nodes with one key are one node`. Fix: a short paragraph with the two-node setup and its console.

**U13. Line 2496:** "No time means no limit, so the loop that accepts takes again after a timeout". Read literally, leaving the time out means no limit, the opposite of what is meant (E.0 shape rule 8). Fix: "`accept` has no form without a time, so…"

**U14. Line 2559:** "a fault in one is reported under the function that opened it, `Tcp.accept`". The sentence covers the listener too, and by Appendix E.18 a listener's site is `Tcp.listen`. Fix: name both.

**U15. Line 2455:** "the type must be known where `Foreign.from` is written, as it must for `Io.show`". `Io.show` takes a type variable through `needs a.show` (report §9.4); Appendix E.12 says of `Foreign.from` that no requirement names it. Fix: drop the comparison.

**U16. Line 2648 (§10):** "There are no registered names … A process is reached through an address it was given, or through a service binding". Leaves out the third way report §6.5 names, a key from another node, which §8.2 teaches. Fix: add "or, from another node, by the key it is offered under (§8.2)".

**U17. Line 2486:** "a value that does not fit its segment's width faults". Report §5.11: a literal that does not fit is a compile-time error, and in a pattern a value that does not fit fails to match; only building one faults. Fix: "…faults when it is built, and fails to match in a pattern".

**U18. Line 2243:** "A program reaches outside its node's Ernest code in two ways". §8.6 and §8.7, bytes and TCP to any host, are a third way. Fix: "in three ways", naming the third.
