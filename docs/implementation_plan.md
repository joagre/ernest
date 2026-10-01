# Ernest Implementation Plan

The roadmap: what will be built, in what order, and what is built already. Why anything is the
way it is belongs to [`decisions.md`](decisions.md), what the language is to
[`ernest_report.md`](../ernest_report.md), how the code is arranged to
[`architecture.md`](architecture.md), and the commands and what the toolchain does not do yet
to [`development.md`](development.md).

Read "Where we are" first. The milestones to come follow in order, then what is in no
milestone, the standing gaps, and what is done.

---

## Where we are

**MVP 2.99b is under way**: what the release review left, the code's names read and made to read,
the decision on how code written once works over several representations, which
[`operations.md`](operations.md) weighs, and running as a service. Its first item makes every
run of `make test` trusted. Between its items 3 and 4 runs the principles review, the report
and the guide read against §0 and §0 against what it decided, a milestone of its own;
its readers ran on 2026-09-30, on `57b8356`, and it was worked on 2026-10-01 in seven phases
and closed (the log's *The Attack Plan* and *The Principles Review Closed*); the review before
a release ran the same day, and Ernest 0.2.0, the second release, is tagged `v0.2.0` on
2026-10-01 (the log's *The Release Review Before 0.2.0*), the last milestone done; MVP 2.99b
resumes at item 4, the namespace of two words, and then the operations, decided and built,
item 5. Ernest 0.1.0, the first release, is tagged `v0.1.0` and was published on
2026-09-30 with MVP 2.99; MVP 2.9, MVP 2.61, `libs/markdown` and MVP 2.8 were taken out of
order. Each has its paragraph under "Done".

---

## Milestones

| | What | State |
|---|---|---|
| MVP 1 | the chain: parser, types, BEAM | done 2026-09-18, tag `mvp1` |
| MVP 2 | the rest of the report on one node | done 2026-09-19 |
| MVP 2.5 | a complete standard library | done 2026-09-20 |
| MVP 2.6 | the shell | done 2026-09-25 |
| MVP 2.61 | the guide as the user's document | done 2026-09-24, out of order |
| MVP 2.65 | the language and the toolchain read back | done 2026-09-26 |
| MVP 2.66 | the standard library's `Supervisor` | done 2026-09-27 |
| MVP 2.7 | a program started from a command line, and the appendix of libraries | done 2026-09-28 |
| MVP 2.8 | the formatter | done 2026-09-28, out of order |
| MVP 2.9 | an Emacs major mode | done 2026-09-23, out of order |
| MVP 2.95 | manual pages, an installation, the review | done 2026-09-28 |
| MVP 2.96 | a result annotation written with `:`, and a process's addresses taught | done 2026-09-29 |
| MVP 2.98 | what the first review left | done 2026-09-30 |
| MVP 2.99 | a restart begins afresh, and the first release | done 2026-09-30, tag `v0.1.0` |
| MVP 2.99b | what the release review left, names that read among it; operations records: `Set`'s record and an ordered set; running as a service | the decisions before anything is built (`operations.md`) |
| The principles review | the report and the guide against §0, and §0 against what it decided | done 2026-10-01 |
| Ernest 0.2.0 | the review's rules shipped as one, after the release review | done 2026-10-01, tag `v0.2.0` |
| MVP 2.99c | the language argued: the type system's argument, generated programs, the grammar and the library's laws as machines | moved from MVP 3.9 on 2026-10-01 |
| MVP 3.0 | peers: distributed code and the node protocol | |
| MVP 3.1 | content addressing | |
| MVP 3.2 | the libraries, as they are wanted | `libs/markdown` done 2026-09-25 |
| MVP 3.3 | the shell's second round | |
| MVP 3.9 | the review before 1.0: the full review, the numbering decided once, the promise | |

---

## MVP 2.99b (what the release review left, operations records, and running as a service), about three and a half weeks

What the release review left, the naming of all the code among it, moved here from MVP 2.99d
on 2026-09-30 so that it comes before anything is built on the released code (the log's
*Names Are the First Documentation*); how code written once works over several
representations of one thing, decided here, after the first release (the log's *The
Contract's Decision After the First Release*), over what [`operations.md`](operations.md)
proposes and compares with type classes; and a program on one node run under a
service manager, which was MVP 2.99c until the two milestones became one on 2026-09-30. It had
moved from MVP 2.7 on 2026-09-27 (the log's *Running as a Service*), from MVP 3.0 on
2026-09-28, since it needs no peer (the log's *MVP 3.0 Is Distributed Code and the Node
Protocol*), and from MVP 2.99 on 2026-09-29, so that the first release came first. The items
run in this order, each needing the ones before it (the log's *MVP 2.99b's Order*): the tests
trusted, then the namespace of two words, decided already and needing nothing before it, then
every other decision, the operations' with what they build, since that changes no Erlang,
then the Erlang renamed, then the rest of what is built, then the Ernest renamed over it, then
the guide last. The namespace moved from the tenth item to the fourth on
2026-10-01, items 4 to 9 becoming 5 to 10 (the log's *The Namespace Item First*); items 11
and 12, the operations' build, joined item 5 on 2026-10-02, and their numbers stand (the
log's *The Operations Decided and Built*); item 17, the soak, was removed the same day,
`make load` standing for it (the log's *MVP 2.99b Read After the Review*).
The principles review, a milestone of its own below, ran between items 3 and 4, since the
operations' decision, item 5, is decided under the principles it sharpens (decided
2026-09-30, the log's *The Principles Review*).

1. **The host's port helper's intermittent failure**, done 2026-10-01 (the log's *A Port Lost
   While It Starts*). The line `interrupt_test_` met is the child OTP's helper forks for a
   port: an interrupt that ends the host while a port starts leaves it waiting for the host's
   acknowledgement, and it reports that on standard error. Reproduced. Its fix is OTP's, which
   the user takes to OTP's maintainers (decided 2026-10-01); the test interrupts a program that
   has started, and the start's case stands in *Standing gaps*. `filesync_test_`'s failure was
   the example's own race, a peer's file taken before the first listing and stored with no
   conflict, fixed with `filesync_first_listing_test_`.
2. **The style guides and the glossary, a decision with the user**, done 2026-10-01 (the log's
   *The Glossary Drafted*). [`style.md`](style.md)'s *Glossary* names the concepts several
   modules name, one name each, the report's where it has one; in the six places the code
   departed from the report, the report's word was taken with the user, and the user read the
   guide and the glossary the same day. Items 7 and 15 correct it as they read the code name by
   name, each area's commit carrying its change. Three diagnostics say "return type" or
   "declared to return" where the report says result type; they are text a user reads, not
   names, and change in the attack plan's phase 4 with the defects, the tests and
   `test/diagnostics.md` with them.
3. **The places the language made the review's work harder**, done 2026-10-01 (the log's *The
   Release Review's Harder Places*): of the fourteen lines of [`findings.md`](findings.md)
   marked `2.99b` that are not hardening, two are language feedback 75 and 76, decided in the
   attack plan's phase 5, and twelve are dropped there with their reasons.
4. **A file's words joined by `_` name one namespace segment** (decided 2026-09-29, the log's
   *A Namespace From Words Joined by `_`*): `ordered_set.ern` provides `OrderedSet`, each
   word capitalized and the `_` dropped, a directory's name too, `net/http_client.ern`
   providing `Net.HttpClient`. §4.2's and §11.1's path shape gain it, a word being a
   lowercase letter followed by lowercase letters and digits and a `_` standing only between
   two words, so that no two files name one namespace (language feedback 74, decided with
   the user 2026-09-30); `ern build`, `:load`, completion, `ern doc` and the manual pages'
   names follow, the shell finding `ordered_set.ern` for `OrderedSet`. Before item 5's
   file, and before the Ernest renaming, which may give a module a name of two words. Moved
   before the operations' decision on 2026-10-01, since it is decided, needs nothing before
   it, and gives that decision a file that exists (the log's *The Namespace Item First*).

   With it, in the same code, a defect found 2026-10-02 (the log's *A Type Reached Through
   Another Module's Interface*): the build gives the checker the interfaces of the modules a
   source names, and none of the modules whose types those interfaces name. A program that
   receives `Boxes.Box`, a type whose field holds a function, from `Maker.make()` without
   naming `Boxes` compiles `Maker.make() == Maker.make()` and runs it, which §3.10 makes a
   type error, and selects no field of such a type. §11.1 gains the sentence that a module
   depends on each module that declares a type named in the interface of a module it depends
   on; `ern build`, `ern run`'s check, `:load` and the shell give the checker those interfaces
   and rebuild when they change; and the checker no longer reads a type it has no
   declaration for as a built-in one, which made its equality check pass, but fails as the
   toolchain's own defect. A regression test for each of the three.
5. **The operations, decided and built**, decided with the user before anything of it is built
   (language feedback 64, 70 and 71, which the decision closed on 2026-10-02), and then built. Two parts were decided by the
   principles review on 2026-10-01 (the log's *Members, Operators, and No Hidden Argument*): a
   type's operations are functions of its module, a member only an operator, `compare` or
   `negate`, which decides **when a type's operation is a member and when a module function**
   (`findings.md`'s U8, moved here 2026-09-29); and no operator carries a hidden argument, so
   the proposal's ordering restriction, inferred on a type variable as the equality restriction
   is, is out, and an ordered set takes its order visibly. Whether a restriction may be written
   in an annotation (`findings.md`'s R-23, placed here with the user 2026-09-30) was decided
   the same day: no second way beside inference (the log's *The Reply Discipline Names No
   Type*), and the process-only mark is `m+` (the log's *The Process-Only Mark*).
   [`operations.md`](operations.md) was rewritten under the two rules on 2026-10-01 (the log's
   *The Operations Note Rewritten* and *The Order Bound Once*), and again on 2026-10-02 (the
   log's *MVP 2.99b's Questions, One by One*), and what it specifies is this item's decision:
   the record in `set.ern` holding the twelve operations of a set's vocabulary whose types name
   only its parameters, with no generic function in the library, code written once being the
   program's; `OrderedSet.Set(a)` in `ordered_set.ern`, its order written once, where the
   program binds its record, `let ints = OrderedSet.operations(Int.compare)`, an operation
   that needs the order a field of that record and no function of the module taking it, so
   that nothing past the binding falls on the program, its `map` and `filterMap` taking the
   result's record; an order belonging to an element type, so that a second order is a
   second type and two sets of different orders cannot meet; and no order for tuples, lists,
   `Optional` and `Either`, since their `compare` would compare a type variable, which
   reverses what was decided on 2026-09-29 (the log's *Operations Records*). Two parts of
   2026-09-29 stand: `put` keeps the element already in the set, and `foldLeft` stays out of
   the record. Decided with the user on 2026-10-02, one by one (the log's *MVP 2.99b's
   Questions, One by One*): the record holds the vocabulary; the type is
   `OrderedSet.Set(a)`; §3.10 stands, with no order for tuples, lists, `Optional` and
   `Either`; an operations record comes directly after the subjects, before an accumulator and
   callbacks, a clause of E.0's shape rule 1; and the representation is a sorted list, its
   costs stated in its section.

   Once decided, it is built in the report's order. The report first: E.0 shape rule 1's
   clause for a record, E.4's record, §11.5's message naming a selected callee as written,
   `ints.union`, and a section of its own at the end of Appendix E for `ordered_set.ern`, which
   states the departure principle 1 asks for. Then `set.ern` gains its record,
   `Set.Operations(s, a)` and `Set.operations`, its functions unchanged. Then `OrderedSet` in
   the standard library, the record's second representation, with its tests and its page. `Map` gains a record with a second representation, and not before. Nothing in
   the checker, the emitter or the runtime changes (`operations.md`'s *What it costs to
   build*), so the build does not wait for item 7, which renames the Erlang before the
   toolchain's changes so that they are written once; the code is written in the glossary's
   names. Items 11 and 12, `set.ern` over its record and `OrderedSet`, joined this item on
   2026-10-02 (the log's *The Operations Decided and Built*).
6. **The service's two decisions, with the user**: what an alarm at a time does when the
   host's wall clock jumps, since deadlines use the monotonic clock and a time does not
   (`Clock.alarmAt`, Appendix E.15); and whether a launcher passes a termination or hangup
   that comes while the host starts, which the host drops (*Standing gaps* below), on to the
   host until the host has taken it, at the price of a second process between a service
   manager and the program.
7. **Names that read, in Erlang**, about a week: every module under `erl/` and `test/` read
   for its names and renamed where a name does not say what its value or its work is, a
   variable, a function, a record and its fields, by the glossary, which it corrects as it
   goes (item 2), each name that differs from the report's brought to the user. Area by area, a commit each that changes names and nothing else, the area's tests green before the next; the code grows
   longer, and the line stays at 100 characters. Before the toolchain's changes below, so that
   they are written in the new names. A full sweep by [`style.md`](style.md), every name read,
   decided with the user 2026-10-02 (the log's *The Renamings Kept Whole*).
8. **The hardening the code readers found** (C1-5, C1-9, C1-10, C3-26 to C3-31; and 0.2.0's C-1,
   a read's and a write's timers in `Os` and a write's in `Tcp` cancelled when the request is
   answered, as the socket's read cancels its own), in the new names; `findings.md` goes when this item and items 7, 15, 19 and 20 are done, with MVP 2.99b. With it the shell's and `ern
   test`'s `persistent_term` replaced at each input and each test, each replacement a scan of
   every process by the host (C3-39): what changes per input or per test moves to a table, and
   what a binding's holder keeps, which a read must not copy, is measured against a table and
   decided with the user with the numbers. With it the reaper's sample in `make load`, which on
   2026-10-01 read 1,472 bytes above its baseline in about one round in twenty-five of the
   programs and the processes loads, its heap, its queue and its monitors unchanged and the next
   round back at the baseline, so that a load fails at random when its last round is one: what
   holds the bytes is found by sampling the reaper's `monitored_by` and its collection's figures
   at such a round, its stack ruled out (nine words), and the measure counts what holds a wait
   and nothing else.
9. **The runtime's part of running as a service**: what item 6's decisions build, and a
   stream on a full or failing device ending the program, as §8.2 says, with status 141, as
   §11.8 says. On 2026-10-02 a program whose standard error was `/dev/full` lost the line, ran
   on and exited with status 0, and so did one whose standard output was. Beside item 8, in the
   same code.
10. **A service manager's checks**: a systemd unit, start and stop, a stop asked for ending the
    program by its signal, `Restart=on-failure` after a program ends with `Os.exit(1)`, and the
    journal showing fault lines without a doubled time; and a launchd plist on macOS, with the
    same checks.
11. **`set.ern` over its record**: joined item 5 on 2026-10-02 (the log's *The Operations
    Decided and Built*).
12. **`OrderedSet` in the standard library**: joined item 5 on 2026-10-02.
13. **The boundary at a type variable**, what remains of it. A foreign function's result at a
    type variable its parameters name, which §8.4 lets through unchecked, is decided under
    §4.8's rule of no hidden argument: a check where the function is instantiated at a known
    type, or the trust stated (R-2, placed here 2026-10-01). On 2026-10-02 `foreign fn weird(x
    : a) : a = "erlang:length/1"` applied to a list was accepted and faulted inside `List.size`
    with the host's `case_clause` and its stack. And `Foreign.from` exposes its value at the
    caller's type, a proxy for each address in it and a check for each function, as a foreign
    function's argument is (C1-4, decided with the user 2026-09-30). The rest was done by the
    principles review's edits: `Io.show` and `Io.debug` on a type variable are refused, and
    `Io.debug` writes through `Io`'s stream process to standard error (the log's *A Value Shows
    Itself at a Known Type*).
14. **The built-in operators as shims** (`findings.md`'s R-27, decided with the user
    2026-09-30): each operator §9.6 gives `Int`, `Float`, `String` and `Bytes`, their
    `negate`, and the `compare` of `Int`, `Float`, `String` and `Char` become a `foreign fn`
    over the host's operation, or over a helper in the runtime's Erlang where the host has
    none of the shape, `String.<>` and the `compare`s, since the operation is the host's alone
    (Appendix E.0 rule 1). §9.6's sentences that such a body is no recursive call go, and so
    does the checker's case for them; an operator costs what it costs now, which `make bench`
    measures. After item 13 and before item 15, so that the Ernest is read as it stays. Kept,
    decided with the user 2026-10-02 (the log's *MVP 2.99b's Questions, One by One*).
15. **Names that read, in Ernest**: the standard library, the shell, the libraries and the
    examples, read and renamed as item 7 renames the Erlang, a type, a constructor and a field
    among the names, the glossary corrected as it goes and each name that differs from the
    report's brought to the user, after items 5, 13 and 14 so that the code they write is read once
    with the rest. A name the report states, an exported function's or a constructor's, changes only
    through the report. Among it the shell's `obey`, which writes each refusal eight times,
    the editor's names that mean two things, `back`, `from` and `step`, and what
    `complete.ern` repeats (C3-35 to C3-37). A full sweep by [`style.md`](style.md), as item 7
    is, decided with the user 2026-10-02 (the log's *The Renamings Kept Whole*).
16. **The guide's §7.3**, over the finished code and its names: it says "operations record"
    and shows code written once, a representation's own functions beside the record's, two
    ordered sets of two orders, two element types, that cannot meet in a record's `union`, and
    values of several representations in one list. Its examples compile and run under the
    guide's checks. What Ernest cannot express goes to
    [`language_feedback.md`](language_feedback.md) and is decided with the user before the
    section goes around it. The guide's §7.3 was decided 2026-09-28 (the log's *§7.3 Written
    Around an Ordered Set*); §7.2 states the rule for a type's operations since the principles
    review's edits.
17. **A soak of hours**: removed on 2026-10-02; `make load` stands for it (the log's *MVP
    2.99b Read After the Review*).
18. **Two library shapes the log's reasons left open**, done 2026-10-01 (the log's *The Key
    and the Hard Link*): `Map.mergeWith`'s function takes the key, as Erlang's `maps:merge_with`
    and OCaml's `Map.union` pass it (principle 1, E.3), and `Fs.makeHardLink` makes a hard link,
    the host's alone (E.0 rule 1, E.17). Each verdict had rested on a neighbour or a count,
    which phase 6 found (the log's *The Log Read Against Its Reasons*).
19. **`ern test` over a directory** (0.2.0's N-12), a decision with the user: whether `ern test`
    takes a directory and runs the tests of every module under it, as `ern build` walks a tree
    (§11.2), the form a newcomer predicted (principle 1). Recommended: yes, about a day, after
    the release.
20. **The feedback the reviews left** ([`language_feedback.md`](language_feedback.md)'s entries
    76 to 88: the first release review's N-C8, the principles review's W-13, W-31, W-34 and
    W-38, and 0.2.0's review's L-1 to L-3 and C-14 to C-18), and four of 0.2.0's rules that
    buy little ([`findings.md`](findings.md)): §2.6's `-(-x)`, §3.9's polymorphic recursion
    refused under a full signature, §2.2's blank line that gives the first doc block to the
    module, and `spawnMonitored` with `Unknown`. Each is decided as item 3 decided the first
    release's fourteen: a report change, a "Later" entry, or a line that it was weighed and
    left alone, with the user one at a time; about two days, after item 5's decision, which
    closed entries 64, 70 and 71 on 2026-10-02. With it `language_feedback.md` holds no entry and `findings.md`
    goes (the log's *Both Lists Close With MVP 2.99b*).

---

## MVP 2.99c (the language argued), about three weeks

The core language argued sound and generated against, before peers build on it, moved here
from MVP 3.9 on 2026-10-01 (the log's *The Language Argued Before Peers*). After MVP 2.99b,
since the review's phase 5 and the operations records are the last changes to the type system
on one node, and before MVP 3.0, whose code shipping and type identity extend the argument
rather than begin it. The machines first, cheapest first, since each finds concrete defects
in a day or two, and the argument last, written over a parser and a checker the machines have
shaken (reordered 2026-10-01).

1. **The grammar generated against.** A thousand programs generated from Appendix A as round 2
   leaves it, reaching every alternative, parsed, and each near miss refused with a diagnostic
   (the log's *Enough Coherence*). A machine of `make test`.
2. **Well-typed programs generated.** Programs generated to type-check run under the runtime and
   end by returning, by a cause of §7.4, or by a deadlock; a host error that is none of those is
   a finding in the checker or the runtime. A machine of `make test` once it runs in its time.
3. **The standard library's laws as properties**, generated against each module's contract as
   round 2 leaves it: `String.split` then `String.join` gives the string back, `List.sort` is
   stable, a search matches whole graphemes, and the rest its sections and doc blocks state. A
   machine of `make test`, a module at a time.
4. **The type system argued.** A written argument that a well-typed program does not go wrong:
   the core calculus, then effects and mailbox types, the reply discipline's linearity as §6.6
   now states it, naming no type and a list element among the places a reply stands, and where
   rules meet, generalization against effects, a pure function standing for one with a mailbox,
   a reply captured by a lambda, an operator resolved where its operand's type is known and
   carrying nothing hidden. Where it cannot be made, that is a finding; a model a machine
   checks follows only if the argument meets a rule it cannot settle.

---

## MVP 3.0 (peers: distributed code and the node protocol), about three weeks

Designed in [`node_protocol.md`](node_protocol.md), which owns the protocol. The note is
tentative, and was brought to the report on 2026-09-28, each change a line marked *Changed*;
what it still asks of the report, listed below, and its open questions are decided before any
of it is built.

Nodes that reach each other, a spawn on a peer that ships code (§8.7), and messages between
them that carry values (§3.11). Code is shipped only between nodes running the same build,
§8.7's easiest case, and a peer whose build differs is refused with an error naming 3.1. Split
from MVP 3.1 on 2026-09-20. It holds distributed code and the node protocol alone, decided
2026-09-28 (the log's *MVP 3.0 Is Distributed Code and the Node Protocol*).

A full review ([`full_review.md`](full_review.md)) runs before it, since others build on
it, and what the review finds is worked through before its work begins (2026-09-29, the
log's *A Full Review Now and Then*).

- **The distribution notes' rewrite, read with the user before any of it is built.** Brought to
  the report on 2026-09-28, the two notes also gained design no one has weighed: a `spawned`
  and a `kill` frame, `demonitor` kept to the runtime, the spawn site in the spawn frame, the
  hash modules named `ern#<base32>`, and new open questions, the protocol note's 5, 7 to 12
  and 15 to 21, and the distribution note's 8 to 17 (the second read-back, 2026-09-30, placed
  here with the user the same day).
- The module `Peer`, with `Peer.spawn(name, f)` and `Peer.spawnMonitored(name, f, wrap)` (§8.3),
  in a section added at the end of Appendix E; the checker's refusal of a name of `Peer` goes,
  and the guide's examples in §8.1 and §8.4 are compiled again (2026-10-01, the log's *The Rules
  That Exist for Another*). It spawns over the peers in `ernest.conf`, authenticated with the
  configured keys: the connection is `ssl`, with the peer's public key from `ernest.conf` as the only
  trust, read with `public_key`, inside `ern`; a program never sees either module.
- Peer loss as §10 says: every process on the lost peer dead with `Fault("peer lost")`, its
  monitors delivered; a peer that reappears is a new instance.
- `Supervisor.child` refusing a supervisor on another node, `Fault("a child runs on its
  supervisor's node")`, which Appendix E.22 states and no code can reach before peers exist
  (the release review's C1-35, 2026-09-30).
- **Placement by load, in `Peer` and a library** (feedback items 14 and 25, decided in MVP
  2.66; the log's *No Remote Computation in the Language*). `Peer.nodes` answers the nodes
  a program can place work on, the running node first, then each peer of `ernest.conf` in its
  order. How a program places work on the node chosen, since `Where` left the prelude on
  2026-10-01, is this item's decision, made with the user when it is built; the recommendation
  is that the library spawn on the node it chooses, `Balancer.spawn(measure, f)`, so that no
  node type exists (the log's *Placing Work Without `Where`*). `Peer.runQueue : () -> Int with m` answers how many processes
  wait to run on the node that evaluates it. Both are shims by E.0 rule 1, stated in `Peer`'s
  section of Appendix E.
- **`libs/balancer`**, in Ernest over those two. `Balancer.pick(measure)` draws two nodes at
  random from `Peer.nodes()`, spawns on each a process that evaluates `measure()` there and
  sends the number back, and answers the node with the lower number, the first on a tie. A
  node lost before it answers is dropped and another drawn; the running node always answers,
  and with one node `pick` answers it without measuring. `measure : () -> Int with m`, so the
  common call is `Balancer.pick(Peer.runQueue)`. Its module page states the cost, two round
  trips per `pick`.
- **What the protocol note asks of the report**, each decided before it is built: whether
  `Reason` gains `Unreachable` for a lost peer whose process may live on (the note's question 6,
  §9.3, §6.9), and whether §6.4 states that what arrives is an unbroken prefix of what was sent,
  a sender told nothing of a drop, as the note's section 8 promises.
- **Where a node's configuration is read**, decided before `ernest.conf` is: its default,
  `./.ernest`, is the directory a program starts in, whose `ernest.conf` would name the peers
  and keys the node trusts, as its `startup` ran inputs until MVP 2.95 (§11.2, §11.3; the log's
  *A Directory Runs Nothing of Its Own*). Recommended: the default goes, and a node reads a
  configuration directory only where `--config-dir` names it. With it goes where the node's
  private key lives, which `ern config` writes there by default, into the working tree, where
  a commit can take it (the security reader's S-H, 2026-09-29); nothing reads the key before
  this milestone.
- **`Peer.find(name, fn() = M.service)`**: a peer's service is found by reading its binding on
  the peer, decided in MVP 2.65's step 5 (the log's *A Peer's Service Is Found Through Its
  Binding* and *`Peer.find` Stands*). Built here with §8.7's two sentences on a node's own
  initialization and on a definition that differs by hash. It answers a failure rather than
  faulting, `Peer.Failure = NoSuchPeer | Lost`, `Peer`'s own; `Peer` as a namespace beside the
  constructor `Peer` of `Where` is checked against §4.2.
- **When a module's top-level bindings run**, decided with §8.7's sentence on a node's own
  initialization: whether one rule serves both nodes, where the node a program starts on runs
  those of every module the entry point depends on, though their names may appear nowhere at a
  use (§8.5, principle 3), and a peer runs them lazily (a reader's finding, P4).
- **Code travels only with a spawn**, decided 2026-09-27 (§3.11, §6.5, §8.7; the log's *Code
  Travels Only With a Spawn*). A value that holds a function faults at the operation that
  would take it to another node, `function cannot cross nodes`, found by the walk that finds a
  foreign value; the function a spawn starts, with its captures, is shipped. An adapted address
  crosses as its target's address and its function's `{hash, env}`, and the node where it was
  made applies the function on delivery; one made around another node's process faults.
- **Shipped code and the host's lambda entries**, noted 2026-09-27 (the log's *The Shell's
  Code Memory*): OTP keeps an entry for each lambda of each version of a module it loads, up
  to 524,288, for as long as the node lives. A node that receives code loads one version per
  definition, by its hash, and `docs/memory.md` gains a load of peers spawning the same and
  new definitions.
- **A supervisor's children run on its node**, decided 2026-09-27 (Appendix E.22; the log's
  *The `Supervisor`'s Shape*): `Supervisor.child` asks the runtime, through a private shim,
  whether `sup` is on the child's node, and faults with `a child runs on its supervisor's
  node` before the child joins when it is not.

---

## MVP 3.1 (content addressing), about four weeks

Designed in [`code_distribution.md`](code_distribution.md), which owns it. The note is
tentative, and was brought to the report on 2026-09-28; its open questions are decided here,
report first. Its question 9 meets the code as it stands: whether a node running hash modules
keeps embedded mode, which loads nothing from the code path on demand, where §11.2 finds a
`foreign fn`'s Erlang module on the load path. The toolchain has no IR: `ern_emitter` goes from
the typed AST to Erlang's abstract format in one traversal, and whether an IR is introduced or
the typed AST canonicalized is part of the decision on the normalized definition below.

The milestone is §8.7's identity in full:

- **The normalized definition, decided first**: the typed tree or the untyped one, and what
  becomes of the effect variables, which are inferred and
  never written. With it, whether a type's identity holds the hash of its `compare`, so that
  a value ordered under one order is not read under another where versions meet (on one
  node MVP 2.99b's item 5 left it the program's, which names both orders, the log's *MVP
  2.99b's Questions, One by One*). Whether `ern_iface:hash/1`, which hashes a canonical interface, grows into
  the definition hash or a second scheme stands beside it is part of that decision.
- Every definition gets a hash of its typed AST; modules are named by hash, with a registry
  per node `{Hash -> Module}`. A function spawned on a peer carries its hash, and a node that
  lacks it fetches the code from the sender. Erlang's module distribution is not used.
- Hash modules never change, and versions coexist on a node for as long as a process runs one
  ([`code_distribution.md`](code_distribution.md) section 8). The shell's reload then ends
  nothing: §7.3's unloading cause, §7.4's `Fault("its code was unloaded")` and §11.2's
  second-reload rule go, with the test that pins them.
- **The loader's one `code_server`**, measured under the loader's batches before it is relied
  on, and **normalization**, given a test suite of its own (the note's section 6 and risk 1).
- **A node whose atoms near the host's limit**, decided with the hash modules: the note's
  section 10.2 drains and restarts it, which CLAUDE.md's rule that memory no collection
  reclaims is fixed at its cause, never by a cap, questions (a reader's finding).
- Two nodes with different versions of one type never meet in a message, decided 2026-09-27
  (§8.7, *Identity*): an address carries its mailbox type's hash and is obtained only through
  typed operations. A frame that breaks it comes from a faulty peer and tears the connection
  down (node protocol, section 4.2).
- The library fetcher, decided 2026-09-19: `ern fetch name url` fetches a library's source
  tree from a git URL into a directory on the load path, compiles it, and records the hashes of
  its definitions. No resolver, no semver, no lockfile beyond those hashes, and no registry.

---

## MVP 3.2 (the libraries, as they are wanted)

A library not yet written waits, and is written when our work needs it, MVP 3.0 and 3.1 among
that work, when someone asks for it, or when we want it, decided 2026-09-25 (the log's
*Libraries As They Are Wanted*). Each is an Ernest source root under `libs/<name>/` that a
program adds with `--load-path`, with `stdlib/`'s test discipline, documented in one pass to
[`module_doc_template.md`](module_doc_template.md) with its executed examples as its first
user, and a section in the appendix of libraries. Own repositories come later, when there is a
package story. Written: `libs/ets` and `libs/markdown` (Appendix G; `libs/markdown` under
"Done"). Named so far:

- **`libs/json`**, pure Ernest: a `Json` type, a parser over `String` returning `Either`, a
  printer.
- **`libs/base64`**, a shim over `base64`.
- **`libs/tls`**, a shim over `ssl` and `public_key`: `listen`, `accept`, `connect`. Whether
  it answers `Tcp`'s `Address(SocketMsg)`, its foreign process then speaking an encoding private
  to `Tcp` (E.18), or a socket type of its own with its own `read`, `write` and `close`, is
  decided when it is written. Certificate verification is the caller's to ask for.
- **`libs/http`**, Ernest over `Tcp` and `Tls`: request and response types, their parsing and
  rendering in both directions, and a client. No server loop; that is the webserver example's,
  whose hand-written parser and renderer the library replaces (feedback item 55; the log's *The
  Web Server Waits for Its Library*). With it, `examples/fetch.ern`, a command-line tool that
  fetches JSON over HTTPS and prints a report, and `Time` in Appendix E over the clock's
  milliseconds.
- **`libs/regex`**, a shim over `re`, a library and never syntax: `Regex.compile : (String) ->
  Either(RegexError, Regex)`, `Regex` a foreign type.
- **`libs/crypto`**, a shim over `crypto` for hashes, HMAC and random bytes; **`libs/uri`**,
  pure Ernest or a shim over `uri_string`; **`libs/zlib`**, a shim over `zlib`.
- **`Udp`**, a system module of Appendix E beside `Tcp` and not a library, admitted by E.0
  rule 1 and written as wanted too, with `Tcp`'s shapes: a socket an address, a read pulled
  with a time, a datagram `Bytes` (the log's *`Clock.monotonic` Is In, and `Udp` Is
  Placed*).

---

## MVP 3.3 (the shell's second round), about three weeks

The shell's later work that its parts' merits take, decided with the user 2026-09-30 (the
log's *The Shell's Second Round*), in this order. The first three need nothing of MVP 3.0 or
3.1 and may be taken earlier where the user wants them.

1. **Readline's remaining keys**, about a day: the kill ring with `M-y` cycling the earlier
   kills, `C-t` and `M-t` transposing, and `M-u`, `M-l` and `M-c` for case, each a change to
   `Shell.Editor`'s pure `edit`, with key-stream tests.
2. **`:trace f`**, about two days: each call of `f` and each return printed, the values by
   their types (§11.2).
3. **Completion by type**, about one to two weeks: a `match`'s clauses, a mailbox's
   constructors, the functions after `|>`, and an argument's bindings. It needs the checker to
   check an unfinished input, designed first.
4. **A shell attached to a running node**, about a week: each input run on the peer, over MVP
   3.0's peers and MVP 3.1's shipping of code. The shell's design does not assume it runs on
   the node whose code it evaluates.
5. **Whether the session owns what its inputs open**, a decision with the user: a socket and
   a running program an input opens end with the input's process, their owner (§11.2), and
   the session could own them instead, so that they live until it ends, by a way the shell
   names an owner for its inputs (`findings.md`'s C1-2, placed here 2026-09-30).

---

## MVP 3.9 (the review before 1.0)

What a promise of stability needs and a first release could leave out (the log's *The First
Release Is for Others*), after the language was argued in MVP 2.99c:

- **The full review**, every reader over the whole of its area ([`full_review.md`](full_review.md)),
  and its findings worked.
- **The numbering decided once.** Whether the report's section numbers have drifted enough since
  0.1.0 to renumber, with the mapping table written first and one commit that rewrites every
  citation, in the report, the guide, the log, the code, the tests and the diagnostics; or the
  numbers kept for good (the log's *The Language Argued Before Peers*).
- **The promise**: what 1.0 holds stable, stated in the report's §0 and the release's notes.

---

## Not in any MVP

`Slot(a)`, a one-shot credit parallel to `Reply(a)`, is out on principles 2 and 5; the log
holds its shape if the verdict is revisited. String interpolation is declined for now on
principles 2, 3 and 4. Erlang scheduling hints are out: a priority breaks §10's rule that a
process cannot prevent others from running, and the memory options of a spawn change no
meaning; a program reaches either through `foreign fn` (the log's *Scheduling Hints Are the
Host's*). A library is not found by its name: its URL is the one way to say where it comes
from, and an index of libraries is others' to publish (the log's *A Library Is Fetched by Its
URL*). No HTTP
server, ever, and no database connectors: those are libraries for others to write on Appendix
D's pattern.

Three parts of the shell's later work are out (the log's *The Shell's Second Round*): the
grey suggestion, a third way into the history beside `Up` and `C-r` (principle 2), told from
what was typed by colour alone, which the plain mode lacks; re-running an input by number, a
second way to name an input, which `Up` or `C-r` and `Enter` already re-run (principle 2);
and a report of a program's quiescence at the prompt, since a later input may send to any
waiting process, so the report would be a guess (§11.2 detects no deadlock while a shell holds
the terminal). The rest is MVP 3.3's.

---

## Standing gaps

- **§3.11, §6.7 and §8.7 have no citing test**, which `make sections` lists. All three are MVP
  3.0 and 3.1 material and unbuilt, since 2026-10-01 a spawn on a peer being `Peer.spawn`'s,
  which §8.3 introduces and a test of its refusal cites; anything else it lists is a gap.
- **A termination or hangup that comes while the host starts**, before any of `ern` runs, is
  dropped by the host, on this machine in the first 0.2 seconds (report §11). A launcher that
  passes a signal on to the host until the host has taken it would close it, and is decided in
  MVP 2.99b's item 6 (2026-09-29, placed there 2026-09-30).
- **A signal that ends the host while it starts a port**, for a host program, for `ern_exec`,
  or for OTP's lookup of the host's name, leaves a line of OTP's helper on standard error,
  `erl_child_setup: failed with error 32 on line 284`, where §8.6 has the runtime print
  nothing (found 2026-10-01). Every run starts two such ports before `main`, and a program
  that starts host programs meets it while it runs. A port closed while it starts would
  leave the same line by OTP's source, and was not met in thirty tries. Its fix is OTP's: the
  child exits silently when the host is gone, as the helper does, which the user takes to
  OTP's maintainers (decided 2026-10-01, the log's *A Port Lost While It Starts*). Ernest adds
  nothing around it, and the gap stands until a release of OTP that Ernest requires has it.

---

## Done

A paragraph a milestone: what it delivered, and where its reasons are.

### MVP 1 — the chain (done 2026-09-18, tag `mvp1`)

Parser, types and BEAM proved with the report's language unchanged, a subset accepted: no
`Float`, no ownership rule for abstract types, no foreign code, no `Tcp`, no distribution, and
exhaustiveness checking from the start. A hand-written lexer and a precedence-climbing parser,
Hindley-Milner with an effect slot (§3.9), the reply discipline (§6.6), one Erlang module per
Ernest module, and one diagnostic record from every stage (§11.5);
[`architecture.md`](architecture.md) says how they are arranged, and the log's entries of
2026-09-17 and 2026-09-18 why.

### MVP 2 — the rest of the report on one node (done 2026-09-19)

Each item a rule MVP 1 refused or did not check: `Float` and operators on user types (§3.1,
§4.8, §5.1); `foreign fn` and `foreign type`, checked at the boundary (§4.7, §8.4); bitstrings
(§5.11); pattern alternatives (§5.9); `Io.debug` (E.1); raw strings (§2.5); abstract-type
ownership (§4.4); the reply discipline through function values (§6.6); `Deadlock` as global
quiescence (§8.6); and nine points from the consistency pass. The log's entries of 2026-09-19
hold the arguments.

### MVP 2.5 — a complete standard library (done 2026-09-20)

Twenty-one modules in Ernest under E.0's rules; the system processes, each used through its
Appendix E module and never by `send`; the checker reading the standard library's compiled
interfaces as any dependency's; the shape of a module's documentation,
[`module_doc_template.md`](module_doc_template.md), carried in the `.erc`'s EEP 48 chunk; and
four paper programs, three under test. `Tcp` was measured at 1.8 times raw Erlang with a
process per socket, and the processes kept. Erlang's standard library was read module by
module against Appendix E (the log's *The Erlang Standard Library, Read for Ernest* and *Fs by
Its Structure, and the Table*). The toolchain's
naming, `ern_<thing>` and `ern@<namespace>`, was done on the way (the log's *One Token for the
Project*).

### MVP 2.9 — an Emacs major mode (done 2026-09-23, out of order)

`emacs/ernest-mode.el` and its tests, run by `make test-emacs`;
[`emacs_mode.md`](emacs_mode.md) owns the mode. It gave the style guide six indentation rules,
and a test holds the mode's word lists equal to the lexer's.

### The report read as a Wirth report (done 2026-09-23 and 2026-09-24)

The report read as a Wirth report and against §0: its plain errors fixed and about thirty
issues decided one at a time, each a report change with its entry in the log. The largest: a
statement other than a block's last has type `Unit`, and a value is discarded with `let _ = e`
(§5.4); `Ets` left the standard library for `libs/ets` (§10, E.0 rule 1); a fault is a death
with `Fault(cause)`, every cause listed in §7.4, a deadlock the entry process's (§8.6);
`Prelude.X` reaches a shadowed prelude name (§4.2); a parenthesized right side of `|>` is a
value (§5.7); §9 states what makes a type the prelude's; a `String`'s unit is a grapheme
(E.5); the bit syntax dropped `bits` and `native` (§5.11); and §6.6 was rewritten top-down.

### MVP 2.61 — the guide as the user's document (done 2026-09-24, out of order)

The guide rewritten to teach Ernest on its own, in nine steps: every example checked by
`test/ern_guide_tests.erl`, an opening that shows four mistakes the compiler finds, one running
example, a section on failure with a supervisor, pages for the tools and for the Erlang
programmer, a two-reader sweep, and a cold read by a reader new to Ernest. It changed §11.2 and
§11.5 and fixed two defects of the toolchain; the log has each.

### MVP 2.6 — the shell (done 2026-09-25)

The shell, an Ernest program under `shell/`, designed in [`shell_design.md`](shell_design.md)
and specified by §11.2; the guide to its code is [`shell/README.md`](../shell/README.md). Five
checkpoints: expressions (2026-09-20); bindings, the commands, fault reports and the startup
files (2026-09-20); the terminal and its live region (2026-09-21); the line editor, the history
and its search, multi-line input and paste (2026-09-21); and completion and documentation
(2026-09-24). Then a closing sweep by two readers, a session of real use and an independent
review, whose thirteen and five findings each became a rule of §11.2 with a regression test,
and a last sweep of the documents. On the way it built `test/ern_pty.py`, the pseudo-terminal
harness every terminal test runs through, turned `Keys` into `Terminal`, split `make test`
into areas, and found about twenty defects in the toolchain. The log's entries from 2026-09-20
to 2026-09-25 hold every argument.

### `libs/markdown` — a CommonMark renderer (done 2026-09-25, now under MVP 3.2)

Pure Ernest, about five hundred lines: `Markdown.parse` reads CommonMark 0.31's blocks and
inlines, and `Markdown.render` lays them out at a width, with the terminal's styles or as
written; where it is simpler than the specification, its doc block says so. It is a library by
E.0, and Appendix G.2 is its section. The shell renders `:doc` and `Shift-Tab` with it.

### The code read back after the shell (done 2026-09-25)

Every line of Ernest under `shell/`, `stdlib/` and `libs/`, and of Erlang under `erl/`, read
for what goes against the principles, for clumsy code and for defects: about twenty-five
defects fixed, each with a regression test, and the report's §2.3, §7.4 and §11.2 changed first
where a fix needed a rule. The shell gained `Shell.Command` and
[`shell/README.md`](../shell/README.md). The log's *The Code Read Back* has the decisions; the
Ernest questions went to the feedback list, and the Erlang ones to MVP 2.65's step 8.

### MVP 2.65 — the language and the toolchain read back (done 2026-09-26)

Every entry the shell and the libraries raised in
[`language_feedback.md`](language_feedback.md) was decided on §0's principles, and a standard
library entry on E.0's rules, each ending in a report change, a "Later" entry in the log, or a
line saying it was weighed and left alone. Ten steps: the list consolidated (step 1); the
report read cold, its plain half written in (step 2; the log's *The Report Read Cold, Its Plain
Half*); five themes, names and namespaces (step 3), expressions, patterns and types (step 4),
processes and the system (step 5; *Names, Restarts and Supervision*), the standard library
under E.0 (step 6; *A Shim Reaches the Representation*, *A Name Follows the Vocabulary* and
*What the Library Lacked*) and the toolchain (step 7; *One Tool, the Job Its First Word*); the
Erlang code's open questions (step 8); the cold read's last findings (step 9; *The Cold Read's
Last Findings*); and the build (step 10). The build had a gate that read steps 5 to 9 whole,
its findings G1 to G16 (*A Gate Before the Build*); a ledger of rows A1 to E1, with decisions
L1 to L8 (*What the Ledger Found*); the report changed in one pass (*The Report Pass of Step
10*) and read cold again (*The Report Read Cold After the Pass*), feedback items 55 to 58
decided with it; the toolchain first, then the rest in six groups (the log's entries from *The
Build's First Group* to *The Build's Sixth Group*); and a closing sweep (*The Closing of Step
10*). What it gave the language: the abstract type's boundary at its module, field selection,
a pure function standing for one with a mailbox, services as top-level bindings with
`restarting` and `fault` and no registry, `Process` and every fault delivered, the system
references in their modules, standard input as bytes, and one tool, `ern`. The log's entries
of 2026-09-25 and 2026-09-26 hold every decision.

### MVP 2.66 — the standard library's `Supervisor` (done 2026-09-27)

Its opening decided the three questions left in the feedback list. `remote` left the language,
placement by load going to MVP 3.0's `Peer.nodes`, `Peer.runQueue` and `libs/balancer` (items
14 and 25; §6.7; the log's *No Remote Computation in the Language*). The command line is
`Os`'s, with `Os.run` and `Os.exit`, built in MVP 2.7 (item 16; the log's *A Program's Command
Line Is `Os`'s* and *A Program Ends With `Os.exit`*). The build is `stdlib/supervisor.ern`
(Appendix E.22): `Supervisor.group(strategy, limit)` and `Supervisor.child(sup, f)`, each
spawned by its caller; one limit, the group's; three strategies; children that join at any
time; a supervisor restarted in place restarting its subtree; and `kill(sup)` stopping a group
through a watcher, the last child first. A sibling restarts at its next wait, through a
priority message every wait takes (§6.9; `callee was restarted` in §6.6 and §7.4; the log's *A
Sibling Restarts at Its Next Wait* and *The `Supervisor`'s Shape*). `examples/services.ern`
and the guide's §6.6 show it. Feedback item 61, how a client knows that a group's restart is
over, stays as it is (the log's *The `Supervisor`'s Shape*).

### MVP 2.8 — the formatter (done 2026-09-28)

`ern format` lays out each module named, every module under a directory, or standard input,
changing only line breaks and spaces, and `--check` names each module not laid out (report
§11.6; the log's *What the Formatter Keeps*). `make format` lays out every source and the
Ernest blocks of the report and the guide, and `formatted_test_` holds all of them to it. The
layout is [`style.md`](style.md)'s (the log's *Layout for the Reader*). The Emacs mode indents
as the formatter lays out, from a table of how tightly each operator binds that a test holds
equal to the parser's, and `ernest-format-on-save-mode` lays out a buffer as it is saved
([`emacs_mode.md`](emacs_mode.md); the log's *Format on Save*). Built ahead of MVP 2.7's last
two items (the log's *The Formatter Before the Release*).

### MVP 2.7 — a program started from a command line, and the appendix of libraries (done 2026-09-28)

`Os` gives a program its command line, its environment, its working directory, its exit status
and the programs it runs, a running program being a process (§8.2, §8.6, §11, Appendix E.23;
the log's *A Program's Command Line Is `Os`'s*, *A Program Ends With `Os.exit`*, *`Os.run` Runs
Through a Helper in C*, *A Running Program Is a Process*, *The Environment Read Through the
Helper*, *What Building `Os` Found* and *The Working Directory*). `make load` holds the
runtime's processes, the `Supervisor`, `Tcp`, `Os`, `Fs`, `Clock` and the shell to no growth,
and the reading behind it fixed four growths, the shell's code memory and a false deadlock
([`memory.md`](memory.md); the log's *What the Loads Found*, *The Shell's Code Memory* and
*Atoms, Counted*). A program meant to keep running runs in the foreground under a service
manager: a stream that has gone ends it with status 141, `ern`'s fault lines carry the time
where standard error is a file, and a stop ends it by its signal (guide §9.5; the log's
*Running as a Service*). Appendix G lists the libraries under `libs/`, held to their
interfaces (the log's *The Libraries in the Report*). A mailbox stays unbounded, and a write
waits for its stream (the log's *Back Pressure, Again*). The list of what Ernest adds stays at
four (the log's *What Ernest Adds Stays at Four*). The guide was read in order by a reader new
to it, and what it used before teaching is now taught first or points ahead (the log's *The
Guide Read in Order*). `Fs.watch` stays out (the log's *Later*).

### MVP 2.95 — manual pages, an installation, and the review (done 2026-09-28)

`ern doc --man` writes a module's manual page, `Ernest.List(3ern)`, and `ern(1)` is §11
(report §11, §11.4, Appendix G.2; the log's *Manual Pages Named `Ernest.List`*, *`ern(1)` Is
§11* and *What Building the Manual Pages Found*). `make install` installs Ernest under
`PREFIX`, and `make release` writes one archive for every system, compiled where it is
installed ([`install.md`](install.md); the log's *`bin/ern` Is a Launcher*, *The Layout Under
the Prefix* and *One Archive, Compiled Where It Is Installed*). The review ran a machine for
every check and twelve readers, and is now [`release_review.md`](release_review.md)'s one page (the log's *A
Lean Review*); `make test` went from 280 seconds to under a minute (the log's *The Time of
`make test`*). The readers' findings that lose data, expose a user or break a program were
fixed, each with a regression test, and the rest were MVP 2.98's (`findings.md`, under MVP
2.98 below; the log's entries from *The Sweep Removes What a Build Wrote* to *An Unfinished
Line Leaves the Region a Row at a Time*). Three entries of the language feedback were decided: names stay
qualified and the shell's completion moved into `Shell.Complete`, `List.intersperse` is
refused, and `Fs` sees a symbolic link (the log's *What MVP 2.95 Takes From the Rest* and
*What `Fs` Holds*). An intermittent failure of the guide's diagnostics was EUnit's capture,
not the toolchain's. It is verified on Linux alone (the log's *No Mac for the First
Release*), and the release itself is MVP 2.99's (the log's *The First Release Follows MVP
2.99*).

### MVP 2.96 — a result annotation written with `:`, and a process's addresses taught (done 2026-09-29)

A function's result annotation is written `: T`, as a parameter's is, in every head; a
function type keeps its arrow, and `->` after a head's `)` is refused with the spelling that
replaces it (Appendix A's `Return`, §3.4, §4.5, §8.1; the log's *A Result Is Annotated With
`:`*). 2,154 heads were respelled in one move, and `Shift-Tab`'s signature, which names the
parameters as a head does, writes its result after `:`. The guide's §5.5 teaches that a
mailbox has one type and a process many addresses, made with `via`: why, the system modules'
wraps, where the function runs, what does not deliver, the one process behind them all, and
addresses that travel; a `send` applies an adapted address's function in the sender, and the
runtime a wrap as it delivers (§6.5, §6.9; the log's *A Process's Addresses, Taught in
Order*).

### MVP 2.98 — what the first review left (done 2026-09-30)

Every finding of the first review that MVP 2.95 left was fixed or decided, and `findings.md`
went: its lines with what was done stand at commit `b7d34c0`, and its readers' lists in the
file's history up to commit `08edfda` (the log's entries of 2026-09-29 and 2026-09-30, from
*The Report's Cheap Lines* to *`closeListener` Names What It Closes*). The report's
contradictions and silent cases were decided with the user, each argued in the log's entry
of its name. The formatter lays a type of one constructor as it lays several, `==` reads a
function through a type's arguments, and `Fs` gained `create`, `removeAll`, `setModified`,
`readRange` and `append` (E.17). The foreign boundary checks only what crosses, the runtime's
own left unchecked, and a check lasts as long as the process behind it (§8.4); what Ernest
adds to a host call is measured by `make bench`, and supervision stays in the reaper.
`RestartLimit` gained `Unlimited` (§6.9), `Io.Error`'s `Other` says the host's words (E.1),
and a supervisor's group restarts whole (E.22). Erlang's scheduling hints and a registry of
libraries are out, and the shell's later work is MVP 3.3's. A load samples a node at rest,
the loads flat within 15 KB ([`memory.md`](memory.md)), and make runs `ern build` every
time, its own rule deciding by content (§11.1).

### MVP 2.99 — a restart begins afresh, and the first release (done 2026-09-30, tag `v0.1.0`)

Ernest 0.1.0, the first release, for programs on one node, installed from its archive (the
log's *The First Release Is for Others* and *The First Release Follows MVP 2.99*). A restart
became a new run in all but its address (§6.9, *A Restart Begins Afresh*), and `ern(1)` gained
the sections man-pages(7) names (§11.7, §11.8, *`ern(1)` Has Its Sections*). The release review
ran as [`release_review.md`](release_review.md) says (*The Release Review*), and its findings were fixed area by
area, the security lines first, and its questions decided with the user one at a time (the
log's entries from *The Release Review's Security Lines* to *The Release Review's
Questions*). Among what they decided: `String.split` reads the string once over a private
primitive (E.5); `Fs.removeAll` walks a tree by the directories it has opened, the C helper's
second job (E.17); a socket is owned by the process that opened it, and `Tcp.give` passes it
on (E.18); an address foreign code gives back is the program's own only at the type it went
out at (§8.4); a bitstring literal that does not fit is a compile-time error (§5.11); and
`Prelude.T.name` reaches the standard library's namespaces (§4.2). What the review left is
MVP 2.99b's, its first, third and eighth items, and [`findings.md`](findings.md) holds it
until they are done.

### The principles review (done 2026-10-01)

The report and the guide read against §0, and §0 against what it decided, as
[`principles_review.md`](principles_review.md) says; decided 2026-09-30 (the log's *The
Principles Review*), its readers run that day on `57b8356`, and worked on 2026-10-01 in the
seven phases the log's *The Attack Plan* gives: the principles' sentences and the sections',
MVP 2.99b's items 1 to 3, the defects, the families' rules and the edits they asked for, the
log, and the closure, whose counts and bench are the log's *The Principles Review Closed*.
Each family is closed by its entry and is not reopened before 1.0 but by a program that shows
a case it did not. What it leaves is dated: the `since` lines of what it added, written with
`VERSION` at the release (the release review's step 5); `Udp` to MVP 3.2 (the log's
*`Clock.monotonic` Is In, and `Udp` Is Placed*); placing work without `Where` to MVP 3.0 (the
log's *Placing Work Without `Where`*); and the guide's §7.3 to MVP 2.99b's item 16. The
release review ran next, and Ernest 0.2.0 shipped the review's rules as one (the log's *A
Release After the Review*); MVP 2.99b resumes at item 4, the namespace of two words, and then the
operations, decided and built, item 5.

### Ernest 0.2.0 — the review's rules shipped as one (done 2026-10-01, tag `v0.2.0`)

Ernest 0.2.0, the second release, after the review before a release ran as
[`release_review.md`](release_review.md) says on `067ef80` (the log's *The Release Review
Before 0.2.0*). Its machines passed, and its readers, the report's, a newcomer's, who wrote a
key-value cache whose entries expire after a time or with the process that leased them, and
the code's over what changed since `691b4d6`, found 55 lines: 33 fixed before the tag, none a
defect in what a program computes, and the rest planned, asked, recorded or dropped as
[`findings.md`](findings.md) says. What a program written for 0.1.0 changes is in the
release's notes. What the release leaves: the timers `Os` and `Tcp` leave armed after an
answer, with MVP 2.99b's item 8; the glossary's five names, with items 7 and 15; `ern test`
over a directory, item 19; and four of the six rules that buy little, item 20, the principles review having decided the other two.
After the tag, `man/` took 0.2.0's pages as CommonMark, which GitHub shows, and each release
writes them again (`release_review.md`'s step 5; the log's *The Release's Pages in `man/`*).
