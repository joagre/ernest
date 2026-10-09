# Findings: MVP 3.0 read without a release

The plan's MVP 3.0, item 13 (the log's *MVP 3.0 Read Without a Release*). Three of [`release_review.md`](release_review.md)'s readers, run on 2026-10-08 as [`full_review.md`](full_review.md) runs them, over commit `a6612bf9`: the report's reader, K and P as one, on the most advanced model, over §3.11, §8.3, §8.7, §6.10's peer part, §11's node jobs, §11.3, Appendix C, E.27 and G.4 to G.6; the argument's reader, A, on the most advanced model, over `soundness.md`'s section 7 beside the report; and the guide's reader, U, on the model below, over chapter 8, its examples run. The code's reader ran on 2026-10-09 over what changed since `v0.3.1`, in two parts, C over `erl/` and `test/`, and E and S as one over `stdlib/`, `libs/`, `shell/` and the node's code, the range chosen since the full review had read the code whole on 2026-10-05; its lines stand after the guide's. Each reader read cold, its brief and its files and nothing that argues for them, and edited nothing; the scratch programs the lines name are under the session's scratchpad, `readers/kp`, `readers/arg` and `readers/u`.

A line per finding, by area, each naming its reader's letter and number and carrying its decision: `cheap`, fixed in the plan's MVP 3.0 item 14, the shape of the fix in the line; a milestone's number, planned there; `done`; or `dropped`, with the reason. Every line was decided on 2026-10-09 (the log's *MVP 3.0's Findings Decided*). Each reader's whole list stands below the lines.

## The argument

| | Finding | Decision |
|---|---|---|
| A1 | Two shells that are nodes, each declaring a `type T` at the prompt, connect under one fingerprint, offer and find a key at it by its text, and a `Put("boom")` reaches a `receive` typed `Put(Int)`, which faulted in `+`: claim 1 breaks for a shell that is a node, and section 7's "under one build the text names one declaration" is false there. Shown by two shells. | cheap: a shell that is a node refuses `Peer.key` at a type that names a session declaration, naming MVP 3.1 as `:load` does (§11.2, `docs/development.md`'s table); `soundness.md`'s section 7 then holds for the shell node too, and section 8 says so |
| A2 | The standard library is outside the fingerprint, so two nodes of one `ern` version with different standard libraries connect, and a standard library type may be two declarations under one text. | cheap: section 7 names the assumption beside "a peer is trusted whole": every node runs one installation of `ern`, which its version names, the standard library in it |
| A3 | "A declaration's name, which captures nothing" misreads §5.4, where a local `fn` is a declaration and captures; the toolchain refuses the case, as a function that came as a value, against the report's letter. | cheap: §3.11 and section 7 say "a top-level `fn` or `foreign fn` declaration" |
| A4 | "No bound value crosses" is contradicted two sentences later: an adapted address's captures, which may be bound values, cross as payload; what holds is that nothing on the other node reaches them. | cheap: §3.11, §6.5 and section 7 say a bound value is never used on another node, and that an adapted address's captures cross as payload no operation on another node reaches (with K15) |
| A5 | §6.10's cross-node `Upgrade` example is refused by the rule section 7 restates, the lambda's mailbox type being a variable; `with Never` builds. | cheap: §3.11 takes a free mailbox type at `Peer.spawn` as `Never`, as §6.2 does for `spawn` and §8.1 for the entry point, in the checker; a variable constrained elsewhere but not known whole stays refused; §6.10's example then compiles (with K1) |
| A6 | How a peer tells that it lacks a session's module, "at the version the function was compiled in", is a claim of the runtime no section states; the frame of §8.7 carries no version. | cheap: §8.7's spawn sentence says the frame names the function's module and its version, and that a peer with the module at another version answers `NotLoaded`; section 7 cites it. MVP 3.1's hash replaces both |
| A7 | §11.2 says modules are loaded "on demand"; the argument needs the load path read whole at the fingerprint, which the runtime does and no sentence states. | cheap: §11.2 and §8.7 say a node reads every module of its load path at its start, and the fingerprint is of those (with K5) |
| A8 | I3 does not count the callee node's note, which holds a reply; a third place beside the expression and the message. | cheap: one sentence of section 7, the note holds the reply only to end the call and is counted with the caller |
| A9 | The sources of a remote address leave out the values a spawned function captured. | cheap: section 7 adds the values a function spawned on a peer captured |
| A10 | Section 8 cites MVP 3.1's hashes, outside the report, and omits what A1 shows section 7 does not answer. | cheap: section 8 cites nothing outside the report, and names what section 7 leaves |

## The report

| | Finding | Decision |
|---|---|---|
| P1 | `Peer.spawn` and `Peer.spawnMonitored` are not values, and their function is a declaration's name or a same-definition lambda, both only for the capture check; `restarting(Unlimited, work)` cannot be spawned on a peer without a wrapping lambda. | MVP 3.1, item 1: whether what a function captures becomes a restriction of its type scheme (§3.9), so that `Peer.spawn` takes a function value, or the form stays; the spawn by hash carries captured values and asks the same of a capture that is a function. The form stays meanwhile, stated |
| P2 | The compiler names four library types as resources in §3.11, and `key` is a fourth value the compiler makes; no rule lets a library say its type is bound. | cheap: `Ets.Table` is a `foreign type`, bound by §3.8's rule already, so its name goes from §3.11 and from the checker's list; the three resource message types are processes the runtime starts and stay |
| P3 | A node cannot find its own offer and `Peer.spawn` cannot name the running node, so placement-independent code writes two operations, and G.5's `Place` exists for that alone. | dropped: a find that answered the node's own offer, or a spawn that named the running node, would make one operation of a local one and one over the network (principle 3); a local `send` and `spawn` stay total and free, and a program for either place writes it as G.5 does (the log's *MVP 3.0's Findings Decided*, and *Later*) |
| P4 | In a spawned function a top-level name is the peer's and a captured one the spawner's, stated; but §6.10 calls two `fn` declarations "top-level bindings", which Appendix F reserves for a `let`. | cheap: §8.7 says "a top-level `let` and a declaration's name are the peer's"; §6.10 says "names the service and the new functions by their declarations" |
| P5 | `Peer.Failure` overlaps `Io.Error` (`Refused`, `Timeout`) and `Reason` (`Unreachable`), unexplained. | dropped: `Io.Error` is the system modules' error, and `Peer.Failure` names what a node answers, `NotListed`, `NotOffered`, `OtherType`, `NotLoaded`, which `Other(text)` would hide in a string; two constructor names recurring is a likeness of words (the log's *MVP 3.0's Findings Decided*) |
| P6 | `measures` is a rule of the normative report, in §8.7 and Appendix C, serving the informative G.4 alone. | dropped: the rule is the node's, whose configuration starts the host's services, stated whoever reads them; G.4 reads them and is informative as every library is |
| P7 | `Load.schedulers(ms)` puts milliseconds last for a window, E.0 shape rule 8's shape for a bounded wait; `memory`'s minutes rule is one measure's. | cheap: `Load.schedulers`'s parameter is named `window` on its page, and a window below 1 ms faults as §7.4 says of a duration (with K22); `check-interval`'s whole-minute rule holds for `memory` and `disk` alike (with K9) |
| P8 | `./.ernest` for a program that is no node is a concept no job reads. | cheap: §11.3 and Appendix F drop `./.ernest` as a program's directory; a program without `--config-dir` is no node, and `ern config` without it makes `./.ernest`, which a later `--config-dir ./.ernest` names |
| P9 | `Peer.nodes` answers "the names of the peers" where §8.3 makes a node this runtime and a peer another. | cheap: `Peer.nodes` becomes `Peer.peers`, in E.27, `stdlib/peer.ern`, the guide, the tests and `mvp3.2.md`'s example |
| P10 | Principle 4: nothing; no grammar added. | done |
| K1 | §6.10's example does not compile (A5). | cheap: with A5 |
| K2 | A peer's `public-key` that does not decode crashes `ern` at start, `internal error … asn1 … wrong_tag`, exit 70, and on `ern reload` crashes the signal handler, after which the node takes no signal: `ern stop` exits 0 and the node runs on. | cheap: a `public-key` that does not decode breaks a rule of §8.7's paragraph, refused at start and at reload naming the file and the rule; the signal handler never crashes, and a test holds both |
| K3 | A reload's line has no time and names no peer added, removed or renamed, and the host's `Undefined handle_info in ern_signals … {'EXIT',#Port<…>,normal}` warning is printed on standard output at every reload; `os_mon`'s `cpu_sup … Erlang has closed` line at the end with `cpu` measured. | cheap: the reload line carries its time and each peer added, removed or renamed; the signal handler takes the port's exit silently; `os_mon`'s line at the end is not written |
| K4 | `ern test --config-dir dir` with a test that waits forever hangs, where `ern test` says `faulted: deadlock`; §11.2's "the run goes on" and §8.6's "a node detects no deadlock" meet without a sentence. | cheap: §11.2 says that on a node a test that waits forever is not found, since a node detects no deadlock (§8.6) |
| K5 | A node refuses to start for a `.erc` on its load path the program never uses, whose dependency is missing, `cannot find module Load`; `ern run` without a configuration runs. | cheap: with A7, §8.7's **Connections** says the fingerprint reads each module of the load path and refuses a module whose dependency the path lacks |
| K6 | `Refused` is among what a find passes over in §8.7 and not in E.27, and no sentence has a peer answer it to a spawn. | cheap: `Refused` goes from §8.7's find sentence; E.27 and `docs/development.md`'s row already say no operation answers it until MVP 3.1 |
| K7 | Appendix B says a message to a worker on another node faults the sender; §3.11 refuses the address as bound, so no process on another node can hold it. | cheap: Appendix B says a worker on another node cannot be given it, `Address(WorkerMsg)` being bound (§3.11) |
| K8 | §8.3's "every node runs the same compiled program, whole" is false: nodes of one build run different programs, and `NotLoaded` by binding happens only then. | cheap: §8.3 says "Every node runs one build (§8.7)" |
| K9 | The node checks rules the report does not state (a key naming no peer, a nameless peer, `measures` not an object, two peers with one key), and accepts `disk`'s `check-interval` of 90000 where it refuses `memory`'s, the host counting minutes for both. | cheap: §8.7 states each refusal the node makes, a key naming no peer, a peer without a name, `measures` not an object, two peers with one key; `disk`'s `check-interval` is held to whole minutes as `memory`'s is |
| K10 | A reload refuses a file that parses and changes neither key nor listen, for a rule of the configuration; §8.7 states two reasons. | cheap: §8.7's reload sentence says "a file that breaks a rule of **Its configuration**, or that changes either" |
| K11 | `ernest.pid` outlives a refused start. | cheap: `ernest.pid` is written once the node will run, or removed on a refused start, with a test |
| K12 | §8.7's terms without a glossary line: fingerprint, handshake, detector, tick, frame, note, offer, the start's number, dial, measure, carrier; "key" is three things. | cheap: Appendix F gains fingerprint, handshake, detector, tick, frame, note, offer, the start's number, dial, measure and carrier; the node's key, a `keys` entry and a service key each have their words in §8.7 |
| K13 | `Peer.key` at a type not known whole asks for an annotation, absent from §3.9's list; "where it is written" is loose, a later use in the definition fixing the type. | cheap: §3.9's list gains `Peer.key`, and §8.7 says "once its definition is inferred (§4.8)" |
| K14 | "The peer has its module" means "on its load path". | cheap: §8.7 says "on its load path (§11.2)" |
| K15 | "A value of a bound type never crosses" beside "crosses with the values its function captured as payload" (A4). | cheap: with A4 |
| K16 | The loss arithmetic: four ticks of 15 s is 60, not 45 to 75. | cheap: §8.7 gives the host's figure as the host states it, found between 45 and 75 seconds after the last traffic, since the silence begins anywhere in an interval |
| K17 | Resolution at read time is best-effort and unsaid: a name that does not resolve is accepted. | cheap: with S2, a name is not resolved when read, and §8.7 says its family is checked at each dial, where the name is resolved |
| K18 | Appendix C leaves `measures`' shape to be guessed. | cheap: Appendix C shows `measures` with `cpu`, `memory` and `disk` |
| K19 | §9's criterion admits the `Peer` functions and `Peer.Key(m)`; its list omits them. | cheap: §9 names `Peer`'s functions and `Peer.Key(m)` as the library's, as it names `Io.show` |
| K20 | §11.2's "starts the host twice" and the refusal of `ern run --config-dir dir` with no `.erc` state no rule a program sees. | cheap: the two sentences go from §11.2 |
| K21 | G.6's error words and the host's answers differ: `\ud800` answers `UnexpectedEnd`, `1e400` `UnexpectedSequence(<<"1.0e400">>)`. | cheap: `Json.parse` answers `UnexpectedSequence` for a lone surrogate escape, as G.6 says, and G.6 says a number the host cannot read is answered in the host's spelling |
| K22 | `Load.schedulers(0)` and `(-5)` answer a number; what a zero window measures is unsaid. | cheap: with P7 |
| K23 | Silences: the node's `public-key` against `certificate.pem`; which host version the fingerprint digests and whether a `.beam` is in it; an adapted address made on a node since restarted; `Peer.offer` in a program that is no node, accepted and unfindable; a `measure` outside 0.0 to 1.0. | cheap: five sentences, one each: the node's key is `key.pem`, and a `public-key` that differs from the certificate's is refused with the file and the rule; the fingerprint digests the host's release and every `.erc` and `.beam` on the load path; an adapted address carries its maker's start number, so a message to one made by an earlier start is dropped; `Peer.offer` in a program that is no node is accepted and nothing finds it; a measure outside 0.0 to 1.0 is taken as its nearer bound |

P's counts, against the counts of 2026-09-28: reserved words 18, unchanged; words read by position 13, or 16 with Appendix A's `compare`, `negate`, `show`; taken top-level namespaces 29, `Peer` the one added, 35 with Appendix G's six; prelude functions 33, or 38 with the five `Peer` functions §9's criterion admits; prelude types 21, or 22 with `Peer.Key(m)`; primitives outside §9 7, three added by nodes; concepts 116 by Appendix F's 141 entries without the toolchain's, the library's and "primitive", 19 of them nodes', 11 of those without an entry. The reader's table of the rules, each with what it buys and what would be lost, is in its list below; it names as buying little or existing only for another: P1's two restrictions, §8.3's "same program, whole", §6.10's remote `Upgrade` under one build, the read-time family check, `measures`, `./.ernest`, §11.2's "host twice", G.5's `Place`, and E.27's `Refused`.

## The guide

| | Finding | Decision |
|---|---|---|
| U1 | §6.3: "The loss of a peer faults every process on it" is false; nothing faults but a `callForever`. | cheap |
| U2 | §8.2: a node's end gives `Unreachable`; the report and the run say `ProgramEnd`. | cheap |
| U3 | §0's "Distribution by content, planned" says code crosses by hash; the report and the guide say no code crosses, and the roadmap is the plan's. | cheap: §0's bullet says what is built, one build on every node, values cross and code does not, a bound value refused at a key or a spawn; the Unison clause goes |
| U4 | The preface says the toolchain does not run peers yet. | cheap |
| U5 | §8.1 and §8.8: "a module with no top-level `let`" is enough for a peer; a module it depends on may have one. Shown. | cheap |
| U6 | §4.1 writes `Peer.spawn(name, f)`, two arguments. | cheap |
| U7 | §8.3's list of exit reasons is written as complete and lacks `{ern, fault, Cause, Trace}`, `{ern, closed}` and `{ern, code_unloaded}`. | cheap |
| U8 | §8.2's loss paragraph: "No process of your own dies of it" beside a `callForever` that faults. | cheap |
| U9 | §8's intro defers to a deployment guide "which comes with MVP 3.1", which does not exist, for what §9.2 teaches. | cheap: the MVP clause and the deferral go; §9.2 and the report's §8.7 and §11.2 are pointed at |
| U10 | §8.7's socket reader is written over `Address(Session)` where §5.5's, which it cites, knows nothing of its listener's mailbox: a job taught two ways. | cheap: §8.7's reader is written over `Address(Optional(Bytes))` with `via(me, Arrived)`, as §5.5's is |
| U11 | §10 sends the reader to `proposals/nodes_and_code/nodes.md` for the reasons. | cheap |
| U12 | The chapter never says what the peer runs, nor what "the same build" means, nor the two-node setup on one machine. | cheap: a paragraph with the two-node setup on one machine and its console |
| U13 | "No time means no limit" reads as the opposite of what is meant. | cheap |
| U14 | A listener's site is `Tcp.listen`, not `Tcp.accept`. | cheap |
| U15 | `Foreign.from` compared with `Io.show`, which takes a type variable. | cheap |
| U16 | §10 omits the key as the third way a process is reached. | cheap |
| U17 | A value that does not fit a segment's width fails to match in a pattern and faults only when built. | cheap |
| U18 | "Two ways" out of a node's Ernest code; bytes and TCP are a third. | cheap |

## The code

| | Finding | Decision |
|---|---|---|
| C1 | A reload that raises anything but a refusal removes the signal handler, so the node no longer answers `ern stop`; `ern_carrier:reload/0` catches only `cli_error`. | cheap: `reload/0` catches every class, says the reload was refused, and keeps the configuration; a test holds it |
| C2 | A configuration file that is there but cannot be read makes `ern` crash with an internal error, status 70, not a refusal. | cheap: each file is read through a helper that refuses with the file and the rule |
| C3 | A reload's measures keep the parameters of the file before it, since `os_mon` is stopped and never unloaded. | cheap: `application:unload(os_mon)` after the stop, with a test |
| C4 | A frame the gateway's worker cannot handle kills the worker silently; the connection stays up and every later frame from that peer is lost, against §8.7's faulty frame. | cheap: an exception in `work/1` is `unreadable` and ends the connection; `frame/2` checks each frame's fields; a find or spawn while no run is in progress answers `Unreachable` |
| C5 | `Peer.find` and `Peer.spawn` with a time past the host's limit fault with `timeout_value`, and the spawn leaks its row. | cheap: wait in slices against the deadline, as `ern_rt:waited_answer/3` does |
| C6 | A spawner killed while it waits leaves its row, and a late answer does not end the process on the peer. | cheap: the process is ended when the waiter is gone; the row holds the peer's node and goes on its loss |
| C7 | A node refused after its start has begun leaves `ernest.pid` behind (with K11). | cheap: with K11 |
| C8 | A spawner can wait forever when the connection is lost as its answer is handed over, the gateway killing the worker mid-frame. | cheap: the gateway sends the worker `stop` in place of a kill |
| C9 | `ern_waits:until/2` hangs when the process ends while it waits, though it promises `ended`. | cheap: a monitor beside the trace |
| C10 | A node test that fails leaves its nodes running for good. | cheap: a cleanup that kills every `ernest.pid` under the test's base directory, in `try ... after` |
| C11 | The checker refuses a block-local `fn` as the spawned function with a message that calls it a value. | cheap: with A3, §3.11 says a top-level declaration, and the refusal says a local `fn` is not one |
| C12 | A note for a callee the runtime does not watch is never let go when that callee dies unanswered. | cheap: the reaper watches a callee missing from the process table, as `offer/3` does |
| C13 | Comments in `ern_rt` that no longer hold: nine tables for thirteen, a note's comment inside another's, two first lines for `tables/0`, paragraphs run together. | cheap |
| C14 | A refusal comment in `ern_node` and a test comment that no longer hold, naming a milestone no case names. | cheap |
| C15 | `ern_cli`'s header lists the jobs without `reload` and `stop`, and a cross-reference names a function that was renamed. | cheap |
| C16 | One fact in two places: `family/1` in `ern_node` and `ern_carrier`, the directory's file names spelled out in `ern_carrier`, the UTC stamp built twice. | cheap: each in its owner |
| C17 | Names against the glossary: `Pid` for the path of `ernest.pid`, `Process` for a host process number, `Monitor` for a `MonitorRef`, `dir` for the `ConfigDir`, `Text1` for another value, `quoted/1` for shell and JSON quoting. | cheap |
| C18 | A refusal's wording is broken, `measures' memory' check-interval`, which a test enshrines. | cheap |
| C19 | `read/1` gets the user's id by the second element of the whole host snapshot, starting the helper at every start and reload for the uid alone. | cheap: the uid alone |
| C20 | A fixed wait in `test/ern_load.erl`, `timer:sleep(100)`, which nothing derives from what it waits for. | dropped: item 11 kept it, the one pause after the load harness's collections, which nothing the host reports shows, with its measurement beside it (the log's *The Tests Wait on What They Mean*); item 14 checks that the comment states the measurement |
| E1 | `Json.parse` faults on a numeral of some 1.2 million digits, the host's `system_limit`, in place of `Left`. | cheap: the integer decoder catches `system_limit` and answers `UnexpectedSequence`, and G.6 says so |
| E2 | `String.toInt` and `toIntBase` fault on a huge input in place of `None`. | cheap: the shim catches `system_limit` as it catches `badarg`, and E.5 says so |
| E3 | `Balancer.pick` can answer a place the balancer was never started over, since a measuring process may register any place. | cheap: `Balancer.serve` for a place the balancer was not started over faults the serving process, naming the place; G.5 says so |
| E4 | `Load.schedulers` leaves the host's wall-time flag counted up when another process had it on, state no collection reclaims. | cheap: every `setFlag(true)` is paired with `setFlag(false)` |
| E5 | `Bytes.join` and `Bytes.repeat` are quadratic loops where their `String` twins became shims; host functions do exactly the work. | cheap: shims on `binary:copy/2` and `iolist_to_binary(lists:join(...))`, measured in `make bench`'s table |
| E6 | `Load.spent` projects a three-tuple by bare position, which position is active and which total invisible. | cheap: a named record or a comment |
| E7 | The load-path paragraph is restated verbatim in the three new library headers. | cheap: one owner, Appendix G's introduction, which the three point at |
| E8 | `Json.format`'s object ordering is the shim's law, not the host's, said nowhere. | cheap: a sentence on the page |
| E9 | The host's `Int` is not unbounded, faulting near 1.2 million digits, and the contracts cannot say it; nothing else of the changed Ernest asked for a workaround. | cheap: with E1 and E2, the sentence goes where E.5's `toInt` and G.6's `parse` state their errors |
| S1 | Exposure: a holder of a listed key may connect under any node name, since `verify/3` accepts by the key alone, so a peer removed by `ern reload` keeps a connection opened under a fabricated name, and one peer may present another's digest. | cheap: `verify/3` requires the handshake's node name to equal the name of the certificate's key, so a listed key is its own node alone; a test with a client under a fabricated name |
| S2 | Hardening: a peer's host name is resolved when the configuration is read, so a reload can block on DNS. | cheap: with K17, a name is not resolved when read; its family is checked at each dial, where §8.7 already resolves it, and K17's sentence says so |
| S3 | Hardening: a huge numeral in `ernest.conf` crashes the start with `system_limit` in place of a refusal. | cheap: the reader catches it and refuses with the file and the rule |

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

---


# Reader C: the Erlang code and tests changed since v0.3.1 (erl/, test/)

Read whole: ern_node.erl and ern_node.hrl, ern_carrier.erl, ern_gateway.erl, ern_epmd.erl, ern_signals.erl, ern_cli.erl (the changed parts and what they call), ern_peer.erl, ern_rt.erl, the diff of ern_boundary.erl, ern_bound.erl, the diff of ern_typecheck.erl, ern_json.erl, ern_waits.erl, ern_peers_host.erl, ern_peer_tests.erl, the comments and cases of ern_node_tests.erl and ern_carrier_tests.erl, and the helpers of ern_nodes_tests.erl. The diff of ern_shell.erl was skimmed. Every finding below was checked against HEAD (358014eb). Where a command shows the finding, it was run in the scratch directory. Every node I started was stopped or killed.

## Defects

**C1. A reload that raises anything but a refusal removes ern's signal handler, so the node no longer answers `ern stop`.**
- Where: ern_signals.erl:73-78 runs `ern_carrier:reload()` inside the gen_event handler. ern_carrier.erl:199-206 catches only `throw:{cli_error, Refusal}`.
- What happens: any other exception crashes the handler, and gen_event deletes it. SIGTERM and SIGHUP are still set to `handle`, but no handler is left to act on them, so both are ignored. No line is said either.
- Exceptions that reach it today include:
  - the bare `{ok, _} = file:read_file` matches of C2;
  - `ern_os:host()`'s `ern_rt:fault`, a `{ern, fault, _}` throw (ern_node.erl:163).
- Shown:
  ```
  ern run --config-dir node waits.erc &      # a node that waits
  chmod 000 node/ernest.conf; ern reload --config-dir node    # status 0, the node says nothing
  chmod 600 node/ernest.conf; ern stop --config-dir node      # status 0
  ```
  The node was still running three seconds after the stop, and only `kill -KILL` ended it.
- Fix: in `reload/0`, catch every class. Say the reload was refused, naming the host's reason for a non-refusal, and keep the configuration as it was.

**C2. A configuration file that is there but cannot be read makes `ern` crash with an internal error, not a refusal.**
- Where: ern_node.erl:208 (`{ok, Pem} = file:read_file(... ?KEY)`), :222 (the certificate) and :358 (`ernest.conf`).
- What happens: `owned/4` checks the type, the owner and the write bits, but not that the owner can read the file. A key at mode 000 passes `owned` and then fails the match. Separately, `ern_os:host()` can raise a fault, not a `cli_error`, from the same `read/1`.
- Shown: `chmod 000 a/private-key.pem; ern run --config-dir a prog.erc` prints `ern: internal error: exception error: no match of right hand side value {error,eacces} in function ern_node:private_key/1` and exits with status 70. The same happens for certificate.pem, at line 222.
- Fix: read each file through one helper that turns `{error, E}` into `ern_build:refused(Path, E)`.

**C3. A reload's measures keep the parameters of the file before it.**
- Where: ern_node.erl:339-344, with `measures_changed/3` at 291-300.
- What happens:
  - The comment says "the application's own defaults are loaded first, and then set over".
  - On a reload, os_mon is only stopped, not unloaded, so `application:load(os_mon)` answers `already_loaded`.
  - `application:set_env` values from the earlier file stay set.
  - So a reload from `"memory": {"check-interval": 120000}` to `"memory": {}` keeps the 2-minute interval, not the host's default. The same holds for each `almost-full`.
- Shown: `erl -noshell -eval 'application:load(os_mon), application:set_env(os_mon, memory_check_interval, 2), application:stop(os_mon), io:format("~p ~p~n", [application:load(os_mon), application:get_env(os_mon, memory_check_interval)]), halt().'` prints `{error,{already_loaded,os_mon}} {ok,2}`.
- Fix: `application:unload(os_mon)` after the stop in `measures_changed/3`, so each start loads the defaults.

**C4. A frame the gateway's worker cannot handle kills the worker silently, and every later frame from that peer is lost until the connection drops.**
- Where: ern_peer.erl:209-230 matches only each frame's tag. ern_gateway.erl:74-96 spawns each worker unlinked, and `worker/2` keeps handing frames to its pid after it has died.
- What happens: the report's rule is that "a frame the gateway cannot read is faulty, and the node ends the connection" (§8.7). Instead, a frame that raises leaves the connection up and black-holes the peer's find, spawn, spawn answer and adapted-address frames.
- How it is reached today: under `ern test dir --config-dir`, between two runs, the runtime's tables are gone. A peer's find (`ern_rt:offered`) or spawn (`ern_rt:initialized`) then raises badarg. A malformed `{answer, Ref, X}` raises function_clause in `ended/1`. If the waiting row exists, the bad answer is passed on and faults the spawner in `started/3`, a spawn faulting for what a peer did.
- Shown, with no run in progress: `ern_peer:frame(self(), {find, <<"k">>, <<"Int">>, self()})` gives `{'EXIT',{badarg,_}}`. With the spawns table present, `ern_peer:frame(self(), {answer, make_ref(), garbage})` gives `{'EXIT',{function_clause,_}}`.
- Fix:
  - in `work/1`, treat an exception from `ern_peer:frame/2` as `unreadable`, which ends the connection;
  - check each frame's fields in `frame/2`'s guards;
  - answer `Unreachable` for a find or spawn that arrives while no run is in progress.

**C5. `Peer.find` and `Peer.spawn` with a time past the host's limit fail with a runtime error, and the spawn leaks a row.**
- Where: ern_peer.erl:116 (`after Ms`) and :172 (`after left(Deadline)`).
- What happens:
  - The host's `receive ... after` takes at most 16#FFFFFFFF ms; ern_rt keeps `?SLICE` and `remaining/1` for exactly this (E.0 rule 8: a time has no upper bound).
  - Both waits pass the whole time, so a larger one raises `timeout_value`. That is a fault, where the module promises a spawn and a find fault for nothing.
  - The spawn has already inserted its `ern_spawns` row (line 156). The gateway owns that table and outlives the run, so the row is never removed.
- Shown: a node listing peer `b` under key `k` runs `Peer.spawn("b", fn() : Unit with Never = Unit, 5000000000)`. It printed `Big.main faulted: error:timeout_value` from `ern_peer:spawn_answer/3 (ern_peer.erl:172)` and exited with status 1.
- Fix: wait in slices of at most `?SLICE` against the deadline, as `ern_rt:waited_answer/3` does, through an exported `ern_rt:remaining/1`.

**C6. A spawner killed while it waits leaves its row, and the answer that comes later does not end the process on the peer.**
- Where: ern_peer.erl:156 and :220-225 (`[{_, Waiting}] -> Waiting ! {Ref, Answer}`).
- What happens:
  - The row is removed only by the waiter's own `given_up/2` or by an answer.
  - If the waiting process is killed or faults while it waits, its row stays. When the answer arrives it is sent to a dead process.
  - For a spawn that is not monitored, the peer's process runs on, unowned, while the connection lasts. ern_peer's own comment (line 232) says "a process the spawner no longer waits for is ended as its answer arrives".
  - If no answer ever comes (the connection was lost first), the row is memory no collection reclaims.
- Shown by reading.
- Fix: on an answer, end the process where `Waiting` is not alive. Keep the peer's node in the row and drop its rows on `nodedown` in the gateway.

**C7. A node refused after its start has begun leaves `ernest.pid` behind.**
- Where: ern_cli.erl:865-880.
- What happens:
  - `ern_node:start/2` writes `ernest.pid` and starts the measures at line 865.
  - `whole_build(LoadPath)` (869) and `ern_carrier:list/1` run before the `try ... after` that removes the file (875).
  - A refusal from `whole_build` is common: one stale module anywhere on the load path triggers it. It skips the removal, although §8.7 and this function's own comment say the pid file goes "however it ends".
- Shown: in a build of prog, A and B, B was rebuilt with a new export. Then `ern run build/prog.erc` printed `ran`, but `ern run --config-dir ../node build/prog.erc` printed `ern run: A was compiled against another B; build A again` and exited with status 1. `node/ernest.pid` remained, naming the dead host.
- Fix: open the `try ... after ern_node:stop(ConfigDir)` directly after `ern_node:start/2`.

**C8. A spawner can wait forever when the connection is lost as its answer is handed over.**
- Where: ern_gateway.erl:54-56 (`exit(Worker, kill)` on nodedown) and ern_peer.erl:179-183 (`[] -> receive {Ref, Answer} -> Answer end`, with no time limit).
- What happens:
  - The worker takes the row (line 221), and only then sends to the waiting process (222).
  - A `kill` that lands between the two leaves no row and no message.
  - The spawner's DOWN, from the same loss, then enters `given_up/2`, finds no row, and waits for an answer that will never come.
- Shown by reading; the window is narrow.
- Fix: on nodedown, have the gateway send the worker `stop`, which it takes after the frames before it, rather than killing it mid-frame.

**C9. `ern_waits:until/2` hangs when the process ends while it waits, though it promises `ended`.**
- Where: erl/runtime/test/ern_waits.erl:30, `receive {trace, Pid, out, _} -> ...`.
- What happens: with only the `running` flag, a process that exits is traced as `in` and never as `out`, so the receive never matches.
- Shown: `Pid = spawn(fun() -> receive go -> ok end end)`, then `ern_waits:until(Pid, fun() -> false end)` in another process, then `Pid ! go`. Three seconds later the waiter was still in `ern_waits:held/2`, with `[{trace,Pid,in,_}]` in its mailbox.
- Fix: monitor `Pid` as well and answer `ended` on its `DOWN`, or trace `exiting` and match `out_exited`.

**C10. A node test that fails leaves its nodes running for good.**
- Where: test/ern_nodes_tests.erl:130-141 starts each node through `/bin/sh -c "ern run ..."`. No test has a cleanup, so `kill -TERM` (lines 240, 538) runs only on success, and `kill -STOP` at 926 leaves a stopped node on a failure before `-CONT`.
- What happens: a node detects no deadlock (§8.6), so a node whose test failed, or was cut off by eunit's timeout, waits indefinitely, and so does its `tee`.
- Shown: an `erl` that opened the same `sh -c "ern run --config-dir ... waits.erc ..."` port and then halted. Its node was still listed by `ps` afterwards, and I stopped it with `ern stop`.
- Fix: wrap each test in `{setup, ..., Cleanup}` or `try ... after`, and have the cleanup kill every `ernest.pid` under the test's base directory.

**C11. The checker refuses a block-local `fn` as the spawned function, and its message describes it wrongly.**
- Where: ern_bound.erl:131-133 marks the block's `fn` names as `value`, and :177-186 refuses them.
- What happens:
  - §3.11 admits "the name of a `fn` ... declaration, which captures nothing". It is silent on a `fn` declared inside the definition.
  - The checker refuses such a function, saying it "came as a value, whose captures the compiler does not see". It did not come as a value, and its captures are as visible as a lambda's.
- Shown:
  ```
  fn main() : Unit with Never = {
      fn work() : Unit with Never = Io.println("working");
      let r = Peer.spawn("b", work, 1000); ... }
  ```
  `ern build` refuses it with `Peer.spawn starts work, a function that came as a value, whose captures the compiler does not see`.
- Fix: decide it in the report. Either treat a local `fn` as a `let`-bound lambda, checking its captures, or refuse it with a message of its own that names a local `fn`.

**C12. A note for a callee the runtime does not watch is never let go when that callee dies without answering.** (By reading.)
- Where: ern_rt.erl:2295-2299 (`note_call`) and :2324 (`drop_callee_notes`, run only from the reaper's `down/3` for monitored processes).
- What happens:
  - A foreign process's address of an unbound type crosses (§3.11), and can be called from another node.
  - If that process dies unanswered, the caller's `DOWN` runs `closed/1`, which sends no second note.
  - The callee's node never learns of the death, so its `ern_notes` and `ern_callees` rows stay.
- Fix: in `note_call`, ask the reaper to watch a callee missing from `?PROCESSES`, as `offer/3` does with `watch_offered`, and drop its notes on that `DOWN`.

## Clarity

**C13. Comments in ern_rt that no longer hold or are misplaced.**
- ern_rt.erl:31 says "Nine tables hold a launch's state". `tables/0` (1704) lists thirteen, and the header's list leaves out `ern_offers`, `ern_offered`, `ern_initialized` and `ern_notes`.
- The comment at 103-107 describes three tables, but `?NOTES`, with its own comment, sits between `?OFFERS` and `?OFFERED`/`?INITIALIZED` (108-115).
- Lines 1700-1702 are two stacked first lines for `tables/0`.
- The `address()` type's comment (129-130) runs straight into the system processes' comment.
- Lines 906-912 run two paragraphs together, "...reached from outside. / What the look finds:".
- Fix: update the header to thirteen tables, regroup the macros with their comments, and drop the extra lines.

**C14. A refusal comment and a test comment that no longer hold.**
- ern_node.erl:24-25: "what a later milestone adds to it, which is refused until then". No field is treated apart; every unknown field gets "has the unknown field X".
- ern_node_tests.erl:123-124: "a field a later milestone gives a meaning names that milestone". No case does (`drain` and `coordinator` are plain unknown fields).
- Fix: drop both clauses, or add the later fields with the MVP named in the error text (CLAUDE.md, *Defects and gaps*).

**C15. ern_cli's header and a cross-reference are out of date.**
- ern_cli.erl:1-3 lists the jobs as "build and doc ..., run, test and shell (§11.2), and config (§11.3)". It leaves out `reload` and `stop`, which this change added.
- Line 28 cites `(reporting/2)`; the function is `reporting_options/2`.
- Fix: name all nine jobs and correct the reference.

**C16. One fact kept in two places.**
- `family/1` appears in both ern_node.erl:448 and ern_carrier.erl:79.
- ern_carrier.erl:50-51 and 212 spell `"certificate.pem"`, `"private-key.pem"` and `"ernest.conf"`, although ern_node says it is "the one owner of its shape".
- The UTC time stamp, `calendar:system_time_to_rfc3339(...)` with `" "`, is written out in both ern_cli.erl:900 and ern_carrier.erl:302.
- Fix:
  - export the family and the file paths from ern_node (or store the family in `#configuration{}`);
  - write the stamp once, in a function both modules call.

**C17. Names that depart from docs/style.md's glossary or name two things one way.**
- In ern_node.erl:148, 240-285, `Pid` names the path of `ernest.pid`, as in `taken(Pid)` and `living(Pid)`. The glossary says Pid is the host's process. An OS process number there is `Process`, which the glossary reserves for the Ernest value.
- `Monitor` holds a monitor reference at ern_peer.erl:106, 158 and 255, and at ern_peer_tests.erl:24. The glossary says `MonitorRef`.
- The configuration directory is `#configuration.dir` (ern_node.hrl) and `Dir` in `ern_carrier:boot_flags/2`. The glossary says ConfigDir, "Not `Dir`".
- In ern_node.erl:375 and 482, `Text1` is not a later step of `Text` but another value. A numbered name is "nothing else".
- `quoted/1` in ern_cli means shell quoting and in ern_node JSON quoting.
- Fix: rename them to `PidFile`, `MonitorRef`, `config_dir`/`ConfigDir`, `ListenText`/`AddressText`, and `shell_quoted`/`json_quoted`.

**C18. A refusal's wording is broken.**
- ern_node.erl:585-594 builds `"measures' memory' check-interval is not ..."`, and ern_node_tests.erl enshrines it. "memory'" is not a possessive.
- Fix: `Shown ++ "'s check-interval"`, giving "measures' memory's check-interval", or "the check-interval of measures' memory".

**C19. `read/1` gets the user's id by the second element of the whole host snapshot.**
- Where: ern_node.erl:163, `element(2, ern_os:host())`.
- What it costs: a helper process, every environment variable, a persistent-term write of the umask, and a fault-class failure (C2). It costs this at every start and every reload, only for the uid, and the positional read hides what the value is.
- Fix: add an `ern_os` function that answers the user's id alone, or match `{'Host', User, _}`.

**C20. A fixed wait with a chosen number.**
- Where: test/ern_load.erl:122, `timer:sleep(100)`.
- What is wrong: CLAUDE.md allows a time only "derived from what it waits for, never a number chosen". The comment argues why 100 ms is enough, from one measurement, but nothing derives it.
- Fix: derive it, for example from a second sample that agrees with the first, or record the exception in the log as the rule asks.

---


# Reader ES — findings

Repository read cold at HEAD. Scope: Ernest sources changed since v0.3.1 (Part E),
the node's new Erlang code (Part S). I edited nothing.

---

## PART E — the Ernest code

### Defects

**E1. `Json.parse` faults instead of answering `Left` on a long numeral (untrusted-input DoS).**
`libs/json/json.ern:93` (`parse`), `erl/json/src/ern_json.erl:37`
(`integer => fun(Digits) -> {'Integer', binary_to_integer(Digits)} end`).
The page and report both say a number with no fraction or exponent is "an `Integer`, of any
size." The host's `binary_to_integer/1` raises `error:system_limit` at roughly 1.2 million
digits, and `json:decode` does not catch it, so the whole `parse` call faults rather than
returning an `Error`. Since `Json` is meant for data that comes from a file or the network,
a crafted text crashes the parsing process.
Shown: a program that runs `Json.parse(String.repeat("9", 1300000))` faults with
`foreign function ern_json:parse/1 raised error:system_limit` (reproduced with `ern run`).
Fix: in `ern_json:parse/1` catch `error:system_limit` from the integer decoder and return
`{'Left', {'UnexpectedSequence', Digits}}` (the same error the host already gives for a
too-large real), or reword the report/page to admit the host's integer ceiling.

**E2. `String.toInt`, `String.toIntBase` and `Bytes.fromList` fault on a huge input instead of
answering `None`/the declared result.** `stdlib/string.ern:443` (`integer` →
`ern_string:to_integer/2`, `binary_to_integer/2`). `to_integer/2` catches `error:badarg` but
not `error:system_limit`, so a string of ~1.3M digits faults the caller
(`foreign function ern_string:to_integer/2 raised error:system_limit`) rather than returning
`None`. The report has `toInt : (String) -> Optional(Int)` with no fault listed.
Shown: `String.toInt(String.repeat("9", 1300000))` faults under `ern run`.
Fix: widen the `catch` in `ern_string:to_integer/2` to `error:badarg; error:system_limit -> 'None'`.

**E3. `Balancer.pick` can return a place the balancer was never started over.**
`libs/balancer/balancer.ern:120` (`Register` accepts any `place`) and `:152` (`chosen`
answers a measured place directly). `start` builds its round-robin set from the given
`places`, but `serve`/`Register` records whatever place the measuring process names, and a
pick that draws measures returns that place verbatim. So a typo —
`Balancer.serve(balancer, Balancer.On("elsewhere"), busy)` where the balancer was started
over `[Here, On("a"), On("b")]` — makes every measured pick answer `Some(On("elsewhere"))`.
Shown: a program that starts a balancer over three places, installs one measure on an
unlisted place, and calls `pick` six times prints `[Some(On("elsewhere")), ...]`.
Nothing in the page warns of this. Fix: in `Register`, ignore a `place` not in the
balancer's started set (keep the set in the loop's state and drop unknown registrations),
or document that a measure defines a pickable place.

**E4. `Load.schedulers` leaves the node-global `scheduler_wall_time` flag enabled when another
process already had it on.** `libs/load/load.ern:69-82`. `setFlag(flag, true)` increments the
calling process's wall-time counter and returns the old global state in `kept`; when
`kept` is `true` the function returns without ever calling `setFlag(flag, false)`, so the
counter it just added is never released. The host keeps the measurement enabled "as long as
there is at least one process alive with a counter value larger than zero," so a process
that calls `schedulers` while measurement is already on leaves the flag raised after the
original enabler stops — CPU overhead the host's own page warns against leaving on, and a
state no collection reclaims until the process dies. Fix: decrement unconditionally —
always pair the enabling `setFlag(true)` with a `setFlag(false)` after measuring, regardless
of `kept` (the global stays on only while some other counter is non-zero, which is correct).

**E5. `Bytes.join` and `Bytes.repeat` are still quadratic hand-written loops, while the twin
`String` operations were turned into host shims.** `stdlib/bytes.ern:231-235` (`join` folds
`acc <> separator <> part`) and `:238-241` (`repeat` folds `acc <> bytes`). Each `<>`
copies the whole accumulator, so both cost the square of the output size. The same release
replaced `String.repeat` with `binary:copy/2` and `String.join` with
`lists:join/2` + `iolist_to_binary`. A host function does exactly this work for bytes too
(`binary:copy/2`; `iolist_to_binary(lists:join(sep, parts))`), so by E.0 rule 1 and the
cost principle these should be shims. Fix: make `Bytes.repeat` a `binary:copy/2` shim and
`Bytes.join` an `iolist_to_binary`/`lists:join` composition, as `String` now is.

### Clarity — shorter, clearer, or names that do not say what they are

**E6. `Load.spent` reads tuple fields by bare position with throwaway patterns.**
`libs/load/load.ern:83-86,94`. The three-int tuple is projected with
`fn(#(_, _, time)) = time` for one field and `fn(#(_, time, _)) = time` for another, so the
reader must count tuple positions to know that position 2 is active time and position 3 is
total. A named record (`#scheduler{id, active, total}`) or at least a comment at the tuple's
origin would say what the numbers are. Not wrong, but the meaning is invisible at the call.

**E7. `Load` repeats the installation paragraph, verbatim, in three library headers.**
`libs/load/load.ern:5-13`, `libs/balancer/balancer.ern:4-12`, `libs/json/json.ern:4-12`
carry the identical "put it on its load path … `--load-path` … Under `/usr/local`" block.
This is a documented restatement across modules; a single owner (one library-usage note the
headers point at) would keep it from drifting. Low priority — module docs are teaching text.

**E8. `Json` object round-trip relies on an undocumented sort in the Erlang primitive.**
`erl/json/src/ern_json.erl:61-63` sorts members with `lists:keysort(1, ...)` so `format`
writes "in the order of their names' code points." The page states the order but the sort
lives only in the shim; the law is fine, just note that `format`'s ordering is the shim's,
not the host `json:format`'s (the host leaves object order to the program). No change needed
beyond awareness; the behaviour matches the page.

### The language made the code harder than it should be

**E9. Nothing found that the language forced into a workaround.** The changed Ernest reads
as a thinning: most hand-written loops (`List.size`, `List.sort`, `Map.*`, `Set.*`,
`String.split/join/toInt`, `Bytes.indexOf/split/replace/toHex/fromHex`, `Path.split`) became
host shims or short compositions, which is the shimming rule working as intended. The one
place the language shows a seam is E1/E2: the host's `Int` is not truly "of any size"
(it faults at ~1.2M digits), and the Ernest contracts (`Optional(Int)`, `Either(Error, …)`)
cannot express that ceiling, so the code either catches the host's `system_limit` or leaks a
fault. That is a report-silence to close (see E1 fix), not a workaround in the code.

---

## PART S — security of the node's code

Core check is sound: `ern_carrier:verify/3` refuses a TLS peer whose public key no `#peer{}`
lists (`{fail, not_listed}`), and the server sets `fail_if_no_peer_cert`. A party holding no
listed key cannot connect. The findings below concern parties that do, or did, hold a listed
key, and the configuration/boundary surface.

**S1. (Exposure) De-listing a peer and reloading does not sever a connection the peer opened
under a non-canonical node name — revocation via `ern reload` is defeated.**
`erl/cli/src/ern_carrier.erl:208-228` (`changed/2` disconnects only `name(Old)` =
`<keydigest>@node.ernest`) together with `verify/3:266-273`, which accepts a peer by the
cert's **key alone** and never binds it to the node name asserted in the handshake. The
carrier name is `name(PublicKey)` for the node's own dialing, but an inbound dialer chooses
its own name; the node accepts it as long as the presented key is listed. A key-holder who
connects under a fabricated name (e.g. `ghost@node.ernest`) is accepted, and when the
operator later removes that peer from `ernest.conf` and reloads, `changed/2` calls
`disconnect_node(name(Old))` on the canonical digest name — not on the fabricated name — so
the existing connection stays up. Over it, ordinary Erlang distribution gives full node
access.
Shown (in an isolated scratch dir, both nodes and the client killed afterwards): node A lists
peer B; a client presenting B's key and the build cookie connects as `ghost@node.ernest`;
A logs "the node ghost connected"; B is then removed from `ernest.conf` and `ern reload` is
run ("the peer b was removed"); the client remains `connected=true` and an `erpc:call` to
`os:cmd` still runs on A after the removal. (The build cookie is not a secret — any
compatible build computes it — so the only secret required is the peer's private key.)
The report §8.7 promises "a peer removed … has its connection ended," which this does not
deliver for a connection under a name other than the key's canonical digest.
Fix: in `verify/3`, bind identity to the key — reject the connection unless the handshake's
node name equals `name(certificate_key)` — so a listed key can only ever be its own canonical
node; then `disconnect_node(name(Old))` reliably severs it, and `named/1`/logs cannot be
spoofed. (This also closes peer-to-peer impersonation: today a holder of peer B's key can
present peer C's digest as its node name and be logged and treated as C.)

**S2. (Hardening) `ern_node:address/4` resolves peer host names via `inet:getaddrs` during
configuration read and reload, so a reload can block on DNS.** `erl/cli/src/ern_node.erl`
`address/4` (the `same_family`/`getaddrs` branch). A peer whose `network-address` is a name
is resolved while `ernest.conf` is parsed — which runs synchronously inside `reload/0` on the
hangup path. A slow or hostile resolver for a listed host name stalls the reload (and thus
the handling of SIGHUP). The input is a listed peer's text, so this is hardening, not an
exposure; but a reload that can hang on the network is worth a bounded resolve or deferring
the family check to dial time.

**S3. (Hardening) Config JSON integers are read with `binary_to_integer` and fault on a huge
numeral.** `erl/cli/src/ern_node.erl` `configuration/1` uses `json:decode` with only
object decoders, so numbers fall to the host default (`binary_to_integer`), which raises
`error:system_limit` on a ~1.2M-digit value; `measures`' `check-interval` would then fault
the node start rather than giving the clean `fail/3` diagnostic. `ernest.conf` is an
owner-only trusted file, so this is hardening (same host ceiling as E1/E2), but the node's
"every field checked" promise reads as total and this one path can crash instead of refuse.

No exposure was found in `ern_signals`, in `ern_epmd` (it only answers from the trusted
configuration), in the `ern_boundary` value-arming path for peer frames, or in
`ern_gateway`'s frame dispatch (unreadable frames end the connection and are logged; the
`when node(From) =/= node()` guards hold). `ern_node:read/owned` correctly refuses a
directory or file that is another user's, world-writable, or (for the key) group/other
readable, matching report §8.7/§11.2.
