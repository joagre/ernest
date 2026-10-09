# Findings: the principles review of 2026-10-09

[`principles_review.md`](principles_review.md)'s five readers, run on 2026-10-09 over commit `d38d11c8`, each a session of its own on the most advanced model, reading cold and editing nothing: P, the principles, in two parts, the language (P1 to P21) and the library (P40 to P63), with [`mvp3.1.md`](../proposals/nodes_and_code/mvp3.1.md) and [`mvp3.2.md`](../proposals/nodes_and_code/mvp3.2.md) read as proposed additions and peers read for the first time; K, the cold reader, over the whole report and the soundness argument (K1 to K25); W, where the guide works hard (W1 to W36); and L, the log's 667 entries as families (L1 to L77). Their whole lists stand below the lines. L read the log whole, which cost most of the review; `principles_review.md` now bounds it to the entries since the last review.

A line per finding, by family, naming its reader's letter and number and carrying its decision, in the review's words: `sentence`, a rule added to §0 or E.0; `report`, a rule changed or removed; `kept`, with the principle; `guide`; `fix`, a defect or two sections disagreeing, built by the batch that follows the decisions; `log`; `later`; until decided, `to decide`. The decisions are taken with the user in two rounds, the sentences first, then each family under the principles as they then read.

## Round one: the sentences proposed

| | Where | Sentence | Proposed by | Decision |
|---|---|---|---|---|
| S1 | §7.4 | A request a rule of this report refuses, which the program alone could have kept, faults the process that made it; an argument the host cannot take whole is `Left(Invalid)`; one outside the function's own domain is `None` or is corrected as this section says; what the world refuses is a value with its cause. No value is corrected unsaid. | L Family 1; P3, P4 (S3); K20 | accepted: §7.4, replacing "a refused request faults" |
| S2 | §10 and E.0 rule 1 | What the runtime adds to an operation of the host costs a fraction of it, never a multiple, and grows with nothing but the operation's own input; a system process costs its message where the process holds what the operation needs, and none where the host answers without one. | L Family 2; P1's S6 in part | accepted: §10 two bullets and E.0 rule 1's clause; the two prelude ratios of L58 then get their verdict |
| S3 | §11.2 | The runtime writes on standard error, unasked, what a program cannot learn and an operator must, a fault, a node's connections and their loss, the host's failure that ends the program; nothing of a program's own act, and nothing the host says of itself. | L Family 3 | accepted: §11.2 |
| S4 | E.0 preamble | A module is the standard library's where its functions are E.0's to admit and refuse, and a library's where it is over a published specification or a policy, where it needs what §10 refuses the standard library, or where its only user is another library. | L Family 4; P48 (a type enters by rule 1 or by a rule of §3 to §9 naming it) | accepted, three: the module's place by the configuration clause and not by its users, the type's admission, rule 3's clause on a link |
| S5 | §11 | A job reads from the directory it is started in only what its command line names; nothing there configures a job or runs in it unasked, and a program is a node only where `--config-dir` says so. | L Family 5 | accepted: §11 |
| S6 | §0, principle 5 | Every function the prelude or a library names is a value; what cannot be is a form of the grammar and a word of §2.4, counted as one. | P2 (S2); K19, P63 | accepted, reworded: a function that is no value is a primitive named where the report states it and counted; not a form of the grammar |
| S7 | §0, principle 5 | No rule of the language exists for the runtime's or a library's convenience: a cost the runtime cannot bear is a limit the report states, never a form the compiler refuses. | P9, P16, P40 (P1's S6) | accepted: principle 5; mvp3.2.md's table rule goes, a stated limit in its place |
| S8 | §0, principle 2 | A reserved word has one meaning wherever it stands; where one word opens a narrower form, the narrower rule says what bounds it. | P6 (S4); W24; L70 | refused: §0's host paragraph and S2 decide it, and §6.3 states the bound; the guide gains W24's sentence |
| S9 | §0, principle 3 | What a call supplies without writing it is a member alone, reached by a type as an operator is; everything else a call writes. | P5 (S5); W2 | refused: §4.9 and E.0 shape rule 1 are the sentence; P5 and W2 kept |
| S10 | §9 | The prelude is §9's list; a rule elsewhere that names a library function names it as the library's, by its namespace. | P8 (S9); K10 | accepted as a change to §9 (report): the list is the prelude, and a rule naming a library function names it as the library's |
| S11 | §0, principle 3 | A wait on another process ends by a time the program writes or by that process's end; the runtime chooses no time of its own. | P1's S8 (the end that waits, `callForever`); P61; L73 | refused: the runtime chooses stated times, the detector's, the dial's, a socket's bound; P61 to round two, L73 and W4 kept |
| S12 | §0, principle 1 | A literal is spelled as Erlang spells it; where Erlang has no spelling, the report states the one it takes. | P15 (S10) | refused: the literals are neither reader's; P15 to round two |
| S13 | §0, principle 2 | A literal form, and `if` beside `match` on `Bool`, enter where the reader of principle 1 writes them; a function stands beside the operator that is its spelling, and no other pair. | P1's S1 (P13, P14) | refused: principle 2's clauses and §9.6 hold it; P13 to round two as a question of fact, P14 kept |
| S14 | §0, principle 3 | A program's text says what it does; its configuration says where; a program that is no node writes nothing of it. | P1's S7 | refused: §8.3 and §8.7 are the rule, and a design is not a principle |
| S15 | E.0 rule 1 | Where a function of the host does exactly an operation's work on a value the language owns, the operation is a shim as on any other value. | P2's 1 (P44); K's restatement of rule 1 | refused: rule 1's own text keeps an operation on a value the language owns in Ernest within its line, and the reply discipline decides `reverse`; see P44 |
| S16 | E.0 rule 2 | A map adds `keys`, `values`, `update`, `merge` and `mergeWith`; `remove` takes what `get` takes. | P2's 2 and 3 (P55, P45) | accepted: the map's five words; `remove` takes the index or key `get` takes, a set its element; `List.remove` by index, report and code |
| S17 | E.0 rule 3 | A numeric policy is the one §2.5 and §3.1 give the language's literals and arithmetic, ties to even among them. | P2's 5 | refused: rule 4 and principle 2 refuse a second rounding; E.9 states its own |
| S18 | E.0 rule 4 | A function whose body is calls of functions already here and the language's operators, with no case of its own, is a composition whatever its length; the pairs rule 4 names move to rule 2's vocabulary. | P2's 6; K's restatement of rule 4 | accepted, both: rule 4 by "no case of its own"; the pairs as rule 2's vocabulary, two-constructor predicates and a stream's line and bytes forms; `Io.debug` by name |
| S19 | E.0 shape rule 1 | A time that is the operation's own subject, an alarm's, comes first; one that bounds a wait comes last. | P2's 8 | accepted: shape rule 1 |
| S20 | E.0 shape rule 2 | A function that starts a process of the module's and answers its address is `start`; one that makes an entry of the file system is `make`. `contains` takes a run of the container's own type; `size` counts the units its section names. | P2's 9; K17 | accepted, both: `start` and `make`; `contains` and `size` on a type read through `toList` |
| S21 | E.0 shape rule 3 | An encoding's two directions stand in the module of the type encoded; a conversion is named by the other type and exists once. | P2's 10 (P56); K18 | accepted: shape rule 3; E.20's own sentence goes |
| S22 | E.0 shape rule 4 | A fault a section gives is for a misuse the text alone shows, never for a value the caller could not know before the call. | P2's 11 | refused: S1 says it where shape rule 4 points |
| S23 | E.0 shape rule 5 | A function is pure where its result depends on its arguments alone and it changes nothing; one that reads or changes what is outside its arguments while it runs carries `with m`. | K's restatement of shape rule 5 | accepted: shape rule 5 as a definition; the preface's exception for libraries goes |
| S24 | E.0 shape rule 8 | `Timeout` is `Io.Error`'s, and a function that answers it answers `Either(Io.Error, a)`; a wait is bounded by milliseconds last unless the wait's failure ends the program or the runtime holds the answer; `callForever` is the one named exception. | P2's 12 (P43, L64); K's restatement of shape rule 8 | accepted: shape rule 8 restated; `Peer.Failure` goes and `Io.Error` gains its constructors, reversing P5 of MVP 3.0's review with L64's reason |
| S25 | E.0 rule 1 | Its value is the host's: the operation reads or writes what the host owns, or is work a host function does exactly. | K's restatement of rule 1 | accepted: rule 1 as a definition, the list its examples; E.22 admitted by rule 3 |
| S26 | E.0 rule 3 | No policy is buried in it: a choice its result depends on is an argument, or its section states it whole. | K's restatement of rule 3 | accepted: rule 3 as a definition |

## Round two: the families

### 1. A failure the program meets

| | Finding | Decision |
|---|---|---|
| P3 | §7.4 does not say which refusals fault and which answer a value; "a refused request" is defined nowhere, and the report goes both ways (`Peer.offer` faults, `NotListed` is a value, `Left(NotATerminal)`). | S1 |
| P4 | A negative duration or count is corrected unsaid (`after -1` runs, `Address.call(..., -5)` answers `None`); Erlang faults, §0's host paragraph names a coerced value as what a check meets. | S1 |
| K20 | "A refused request faults the process that made it" names a kind of failure defined nowhere. | S1 |
| L69 | A time below 0 is 0, a restart window below 1 is 1, a measuring window below 1 was a fault then 1 by analogy: §7.4 names "a restart window" where the rule is of every window. | S1; fix: §7.4 says "a window" |
| K22 | Shape rule 4 is read two ways in one day, P7 and K22 of MVP 3.0's review, which is the cost of the missing sentence. | S1 |

### 2. What Ernest adds to an operation of the host

| | Finding | Decision |
|---|---|---|
| P44 | `List.reverse`, `contains`, `indexed`, `zip` and `unzip` are Ernest loops where the host does each exactly; E.0 rule 1 as decided in MVP 2.99d makes them shims. | kept, after a build showed the cost: a shim narrows the scheme to `a!`, so a list of replies could no longer be reversed, which the log's *No Mark Lifts a Foreign Function's Restriction* (2026-10-06) decided for `reverse` already, a closed family; the other four measure within rule 1's line as Ernest, 0.95 to 1.4 times the host's, and stay by the rule's own text |
| L58 | `spawnMonitored` at 7 times and a `monitor` of an ended process at 15.6 times the host's stand with no verdict, since the report has no line to measure them against. | planned: MVP 3.1's item 8 measures the two against §10's rule, each to end at a fraction or as a message by design with its reason in the log |
| L68 | A `Down`'s site refused as a frame the host's operation lacks, a call's note frame added for a rule of §6.6: the sentence that admits a frame for a rule of the report is written nowhere. | kept: S2 admits a frame where the node holds what the rule of §6.6 needs |
| L59 | `Path.<>` kept at 2.4 times the host's; "the prelude's line" of 2 is CLAUDE.md's "a fraction", which the report does not state. | kept: S2 is the line, a fraction, and the ratio stands under it |
| P9, P40 | MVP 3.2's table rule, `Ets.Table(k, v)` refused where it holds a function, exists so that a unit may be let go: a rule of the language for the runtime's convenience, and a compiler that names one library's type. | decided by S7: the table rule goes from mvp3.2.md, and a stated limit replaces it, a unit a table's function holds is never let go |
| P16 | §8.7's `measures` and §6.9's restart-asked-for paragraph exist for a library. | kept: `measures` decided on 2026-10-09 (P6 of MVP 3.0's review), the node starts the host's services whoever reads them; the restart paragraph is §6.9's since the runtime makes the restart |

### 3. What the runtime writes unasked

| | Finding | Decision |
|---|---|---|
| P61 | The end of MVP 3.1 waits for its subscribers without bound and in silence, where shape rule 8 names an unbounded wait. | report, on mvp3.1.md: when termination arrives the node says once that it waits for its subscribers and how many, and says each as it answers or ends; no timer of the runtime's |
| K14 | §8.7 gives a carrier that cannot start no cause text, where §7.4 gives every fault its text. | fix: §7.4 states the text, §8.7 points at it |

### 4. Standard library or library

| | Finding | Decision |
|---|---|---|
| P48 | No rule of E.0 admits a type; E.25 and E.26 stand by §3.10's mention. | S4 |
| L67 | `Load.runQueue` was admitted to Appendix E by rule 1 and is a library three weeks later with no sentence saying why. | S4 |
| L4 | `Fs.removeAll` was removed on danger and a count, which no rule of E.0 names. | S4: rule 3's clause on a link |
| P49 | `Erl` is a namespace for one function, `atom`, beside `Foreign`. | report: `Foreign.atom`, E.19 folded into E.12, shape rule 3's example changed; 28 namespaces |
| P57 | `Terminal.columns` reads ECMA-48's sequences in the standard library, where rule 2 makes a specification a library's. | kept: a terminal is the specification, and the module that drives it skips what the terminal does not show to measure what it shows; stated on E.16's page, no clause in rule 2 |
| P58 | `Float.toString` is called a primitive and is an adapter in `ern`'s Erlang, with no numbers in the log. | fix by measurement, as rule 1 says: the layout in Ernest over the host's shortest form as a private primitive, measured; the adapter stays only with its numbers in the log and E.9 saying the host's function is private beneath it |

### 5. What a job takes from where it is started

| | Finding | Decision |
|---|---|---|
| L5 | Five rules agree, `./.ernest`, the startup file, the host's flags, and the sentence they follow is unwritten. | S5 |

### 6. What crosses between nodes, and the proposals

| | Finding | Decision |
|---|---|---|
| P1 | `Code.running(f)` as proposed is unsound: a lambda written in `f` and spawned has a mailbox type of its own, and an `f` whose mailbox type is a variable lets the caller choose the type of every process listed. | fix, in mvp3.2.md: a frame of `f` itself alone, and `f`'s mailbox type known whole where `running` is written, as `Peer.key` is refused otherwise |
| P41 | `Code.running` admits one arity, `((s) -> Unit with m)`, where §6.10 writes a loop with whatever state it carries. | report, on mvp3.2.md: `Code.running` is a form checked as `Peer.spawn`'s function is, taking a top-level declaration's name of any arity whose result is `Unit with m`, counted as a primitive by S6 |
| P52 | `Code.Hash` is abstract with no `toString`, so `Code.hashes` answers values a program cannot show; `load` and `hashes` have no caller in the proposal; `running` is `with n` where `Process.live` is `with m+`. | fix: `running` is `with n+`; report, on mvp3.2.md: `Hash` is a `String`, the digest in hexadecimal; `load` and `hashes` stay, the deploy tool their caller |
| P19 | `Standing`'s forwarder drops a send while the service is away, against §6.2's one silence; and for a program that is no node, a subscriber waiting with nothing in flight while the end waits is a deadlock §8.6 gives to an entry process that has died. | kept for the drop, a policy stated whole on the library's page; report, on mvp3.1.md: a deadlock during the end is no fault, the end waits as section 5 says |
| P53 | `Standing.start`'s `ms` does two jobs, bounds a find and spaces the retries, where shape rule 8 makes it bound one request. | report, on mvp3.1.md: the forwarder finds again when a message arrives while the service is away, each find bounded by `ms`, and waits on no clock of its own |
| P59 | "closure" in mvp3.1.md names a definition with everything it references, where the reader of principle 1 knows a closure as a function with its captured environment, and §3.11 speaks of captures. | report, on the proposals: "reach", a definition's reach being the definition with everything it references, transitively |
| P20, P60 | The proposals' examples name `List.each` and `List.length`, which the library lacks (`foreach`, `size`), and `Peer.peers`, which §8.3's list of `Peer`'s operations does not name. | fix |
| K1 | E.27's `Refused(text)` is a failure no rule gives and the runtime never answers, so every `match` on a `Failure` covers a case no program meets. | kept: `docs/development.md`'s table lists it as MVP 3.2's, the peer's refusal of a closure; E.27 says so until then |
| K5 | §8.7's "a peer whose module is of another version answers `NotLoaded`" is unreachable under §8.7's own handshake, every module being in the fingerprint. | fix: the version clause goes; the frame names the module, and a peer that lacks it answers `NotLoaded` |
| K16 | E.27 restates §3.11's spawnable functions and drops the local `fn`. | fix: E.27 points at §3.11 |
| K19 | §3.11 refuses `Peer.spawn` as a value and gives no error text. | fix: the text the compiler gives, stated |
| P63 | E.27 lists `Peer.spawn` and `Peer.spawnMonitored` with a function type, and they are no values. | fix: E.27 says a form, not a value (§3.11), until S6 decides |
| P2 | `Peer.spawn` and `Peer.spawnMonitored` are the two named functions of §9 that are not values. | kept, with S6: decided on 2026-10-09, `restarting` admitted, the mark on function types *Later*'s |
| W6 | The guide must explain that a spawn on a peer takes a form, resolves names two ways, and runs only where the peer ran the initializers. | kept: the forms as P2; the rule by module is MVP 3.1's item 4 |
| L52 | `NotLoaded` by module "lasts one milestone" and shaped `Load`, `Balancer` and the tests meanwhile. | kept: MVP 3.1's item 4 |
| L66 | *Placing Work Without `Where`* recommended the library spawn and refused a place type; *Load and Balancer* built `Place` and the program spawns; the reversal's argument is recorded nowhere. | log |

### 7. Forms and second spellings

| | Finding | Decision |
|---|---|---|
| P10 | `Address.call` and `callForever` are qualified where `send`, `answer`, `kill`, `monitor`, `via` and `spawn` are bare. | kept: `call` and `callForever` are the two operations of the type `Address`, whose namespace §4.2 takes for them, as `List`'s is for `map` |
| P12 | A local `fn` and a `let`-bound lambda overlap and differ in a table: recursion, shadowing, a requirement, a reply's capture. | kept: a `fn` is a declaration and a lambda a value, which §5.4 states, and each difference follows from it |
| P13 | A prelude type's members are declared two ways, `export fn Int.+` prefixed, `compare` and `negate` unprefixed, where a user type writes `fn Coin.compare`. | kept: §4.2 states the two spellings, and each is forced, `fn Int.compare` in `int.ern` being the module's own qualified name, which §4.2 refuses, and an operator declarable only in the member form; the derivation goes to the log |
| P14 | `let _ = e` stands beside `e;` for a `Unit` value (W19 counts it eleven times in the guide). | S13, then decided |
| P15 | The raw string's backtick comes from no language the reader knows. | S12, then decided |
| P18 | `Prelude.` is written only where a name is hidden, which makes `Prelude` a reserved name §2.4 does not count. | kept: `Prelude` is counted among the taken namespaces, and §4.2 states the rule |
| P21 | A named constructor is no function value, by §3.5's "there is no canonical order", though the same sentence makes the order the type's identity. | kept: applying a named-field constructor by position would hide the names the type declared (principle 3), and §3.5 says the order is no contract |
| P5, W2 | Two mechanisms for code written once over several types, the requirement and the operations record, overlapping at `compare`; the guide teaches the pair four ways. | S9, then decided |
| P6, W24, L70 | One word `when`, two guards: a `receive` guard calls nothing, a `match` guard is any pure expression; the way around removes the message. | S8, then decided |
| W8 | `type Word = String` compiles and means a nullary constructor named `String`, where the ML reader predicts an alias. | report: a constructor named as a type in scope is refused, its help saying there are no type aliases (§3.1); a checker rule with its test |
| W12 | A constructor with one positional field is a function, one with named fields is not; wrap constructors are single-positional for it. | kept, with P21 |
| W13 | The pipe fills the outermost call; a lambda is not an operand. | kept: §5.7, principle 4; the guide's sentence stays |
| W25 | No partial application, so a lambda. | kept: §5.2 |
| P17, K8 | §11.5 says `=` is written on a foreign type's parameter alone; §4.7 writes it in a foreign function's parameters too. | fix |
| K11 | §2.4 names `needs` and `derives` as read by position; Appendix A reads `compare`, `negate` and `show` by position too. | fix: §2.4 names them |
| K3 | Appendix A admits `C(..e)` with no field, which §5.6 forbids for an update and needs for a fill; the compiler refuses it with a text the report lacks. | fix: §5.6 states the error |
| K7 | A type parameter no field holds, `Peer.Key(m)`, is in no position of §3.9. | fix: §3.9, a type argument whose parameter occurs in no field is a value position; built, the checker read it as an effect position, and §4.7 gained the clause that a foreign function's not-reply-carrying falls on no such parameter, since it holds no values |
| K12 | §4.9 does not say what `a.show` is in a body. | fix |

### 8. The prelude

| | Finding | Decision |
|---|---|---|
| P8 | §9's criterion as written admits thirteen functions and four types §9 does not list. | S10 |
| K10 | §4.2's taken namespaces are "every type that has a member in §9, as `Int` and `Address` do"; `Address` has no member. | fix: "every type whose namespace §9 fills" |
| K2 | §9.4, §9.5, §6.2 and §6.6 list the prelude's types without the marks §11.5 prints; §6.2 and §6.6 restate §9 verbatim, where the drift lives. | fix: the marks as the compiler prints them, built, with `marked_prelude_test` holding §9.4 to §9.6, §6.2 and §6.6 to the compiler; report: §6.2 and §6.6 point at §9 and restate no listing, so one copy exists |

### 9. The library's vocabulary

| | Finding | Decision |
|---|---|---|
| P43, L64 | `Peer.Failure` beside `Io.Error`: the two cannot share a `match` arm, and a block that reads a file and finds a peer converts one into the other, the ceremony *The Error of Input and Output* refused. | S24, then decided again |
| P45 | `List.remove` is by value where `List.get` is by index. | S16 |
| P46 | `Char.isDigit` accepts digits nothing else in the library reads; `isAsciiDigit` beside it. | kept: two questions, the category Nd by the host's table and the ten digits a number's text holds; the page says which function reads which |
| P47 | `Json.parse` keeps a repeated member's first value; every `fromList` keeps the last. | fix: the last |
| P50 | `Int.div` and `Int.rem` pair an operator with its `Optional` form; `Float` has no such pair, and rule 4 names no such pair. | report: rule 2's vocabulary names the pair, an operator that faults comes with its `Optional` form in its type's module, and `Float.div` enters, `None` where `/` faults |
| P51 | `List.foldRight`'s step takes the element first; every other step takes the accumulator first. | report and code: the step is `(b, a) -> b`, its uses in the library and the guide turned |
| P54 | A socket ends two ways, `close` and `kill`; a program by `kill` alone. | fix: one sentence of E.23, a program ends by its own exit or by `kill`, and has no `close` since nothing of it is left half open |
| P55 | Rule 2's map vocabulary lacks `update` and `mergeWith`, which E.3 and E.26 share. | S16 |
| P56, K18 | `Bytes.fromHex` stands where shape rule 3 does not put it; E.20 states a shape rule of its own. | S21 |
| P62 | `dropLast` has no mirror `takeLast`. | report: `takeLast` enters rule 2's sequence vocabulary and E.2, beside `dropLast` |
| K17 | Shape rule 2's text exceptions are wrong for `Bytes`. | S20 |
| K13 | `Io.Error`'s `Refused` is answered by no function the report names. | fix: E.18 at `Tcp.connect` |
| K4 | E.17 carries four sentences for a recursive removal no function of E.17 makes, and one on a file's mode that states what a program does. | fix: the sentences go |
| P42 | `Load.cpu`'s page misstates the host's measure, which is per calling process and since boot at a first call. | fix: the page says so |
| W20 | `Io.Error` has no text; the guide says a program speaks in its own words and writes `Io.show(error)` five times. | guide: the guide's sentence matches its examples, a program writes an `Io.Error` with `Io.show` or in its own words by a `match` |

### 10. Replies and waits

| | Finding | Decision |
|---|---|---|
| W3 | The reply discipline forces five shapes the guide must teach: no `<-` in a handler that holds a reply, a list where a map is predicted, no field selection, a process of its own for a call in `main`, `fault` by its type. | kept, all five: §6.6 doing its one job, argued one by one in *The Type System Argued*; the map by *No Mark Lifts a Foreign Function's Restriction*; the guide's paragraphs are `guide` lines |
| W4 | Every wait on another party takes a time and nothing delivers what a read answers: retry loops, a sleep idiom, a reader process twice. | kept: shape rule 8, decided in *The Waits Family's Rules*; S11 refused |
| W5 | An alarm fires once and cannot be cancelled: two functions, an id idiom, a stale-`Expired` clause in every receive. | kept: E.15, a cancel could not take back a message delivered |
| L73 | §6.2's `send` to another node waits while the host's buffer is full, with no limit and no name saying so, against shape rule 8's own clause. | kept: the host's rule taken and stated in §6.2, §0's host paragraph |
| K9 | §6.6 never names a `receive`'s `after` clause as a branch the reply check reads. | fix |

### 11. Processes, monitors and restarts

| | Finding | Decision |
|---|---|---|
| P7 | "A monitor is the one link between processes; there is no other" (§6.9) is false three times: a resource dies with its owner, `callForever` faults with its callee, a fault in an adapted address's function is the target's. | fix: §6.9 and §7.3 say what holds |
| P11, W14 | `kill` takes an address, `monitor` a `Process`; `Process.fromAddress` six times in the guide. | report: §6.5 gains the sentence, an address is the permission to send to a process and to kill it; a `Process` is its identity, which a `Down` carries and a monitor watches |
| W1 | A `Down` has no order with its process's messages; the guide teaches the race four times. | kept: §6.9's departure, stated; the runtime's own `Down` works across restarts and nodes alike |
| W15 | `via`: a fault in its function strikes the target though it ran in the sender; one step more across nodes. | kept: §6.5, decided twice |
| W16 | A restart in place keeps the address and loses the mailbox; a sibling that never waits is never restarted; no graceful stop. | kept: §6.9 and E.22; the graceful stop is MVP 3.1's `Os.terminating` for the program's end |
| W17 | The program spawns supervisor and children itself; recovery is taught three ways. | kept: E.22, *The `Supervisor`'s Shape* |
| L62, L74 | A socket's unsent bytes are bounded by 3 minutes the host lacks, where memory is not bounded; the sentence that tells them apart, §6.9's owner paragraph, is cited by neither. | log: §6.9's owner paragraph named as the rule each is an instance of |
| K15 | §8.7 ends a process "as soon as its answer arrives" by a way §6.9 does not list. | fix: killed |

### 12. The guide

| | Finding | Decision |
|---|---|---|
| W23 | §7.1 says a module's code names its own declarations "by either name"; §4.2 says the plain name alone. | fix |
| W7 | An open mailbox type has three defaults; `: Unit` means pure, so every `main` writes `with Never`. | guide: one rule since 2026-10-09, `Never` for a spawn and the entry point; §4.1's paragraph and transcript say so |
| W9 | Three marks in printed types, none writable but one, taught in five places. | guide: one place |
| W10 | Operators and selectors resolve by operand type with no default; a block `let` generalizes only a lambda. | kept: §4.8 and §3.9 |
| W11 | Code replacement is demonstrated with code the program held from the start. | kept until MVP 3.2's spawn with code reaches the guide |
| W18 | A service program that lives sixty seconds, and a peer that runs a dummy. | kept until MVP 3.1: a `main` of mailbox type `Never` waits by `Os.terminating` and its message; the guide's store takes that shape in MVP 3.1's item 8 |
| W21 | One sum type per block, bridged by `Either.fromOptional`. | kept: §5.5 |
| W22 | Calling Erlang's `{ok, V} | {error, R}` needs an Erlang helper. | later: a conversion in `Foreign` for the host's `{ok, V} | {error, R}`, when a second program meets the convention outside the guide's example |
| W26 to W36 | Bitstrings' host order and catch-all, `..` on one constructor, an abstract type exported, unbounded mailboxes, keys or lines, `Io.debug` impure, a spawn site that does not cross, a PEM key as one JSON string, "service" twice, `let me = self()` nine times, examples annotated where the report's are not. | kept, each by its section; W36 `guide` |
| W's list | The rules of the report the guide never teaches and never uses, by section. | guide: read when the guide is next written to; no rule changes for being untaught |

### 13. The log

| | Finding | Decision |
|---|---|---|
| L22, L23 | Two entries name MVP 3.0 for a condition MVP 3.2 now owns. | log |
| L40 | Whether `ern build` writes `Dbgi` into a user's module is open with no owner. | planned: MVP 3.1's item 2, which decides what an `.erc` holds, decides whether a user's module carries debug information |
| L42 | §5.1's left-to-right order rests on a host behaviour its manual leaves open, pinned by a test. | log: the host paragraph names the case |
| L50 | The missing JSON library that kept `ern config` in Erlang exists now. | log |
| L53 to L55 | Three entries describe a deploy the plan set aside and carry no superseded mark. | log: superseded marks |
| L72 | One host defect worked around against two that were not; the sentence that tells them apart, a defect that stops a well-typed program from building, is unwritten. | log: the reason restated where it stands, the project's rule and not the report's |
| L75, L76, L77 | Reversals and likenesses recorded with their reasons. | log, no change |

### 14. The soundness argument

| | Finding | Decision |
|---|---|---|
| K21 | Section 5 says a socket takes a wrap; it takes none. | fix |
| K22 | Section 2 argues from a proxy the report does not name; §8.4's sentence gives the step. | fix |
| K23 | I3 has no place for the callee node's note or the caller's watch; "counted with the caller" is asserted. | fix: I3 and the configuration gain the runtime's record of a call, which answers nothing |
| K24 | Section 6.4 leaves unsaid what a `(Down) -> Never` wrap does once `main` has begun. | fix |
| K25 | Section 6.8 cites the wrong half of §8.4 for a variable result. | fix |

### What "consistent" means

K: the word is in neither the report nor the argument; what stands for it is principle 1's prediction, principle 2's one way, and one build on every node. Agreement between two of the report's own sentences is required nowhere and kept by tests outside the report; the authority ordering lives in CLAUDE.md, so a reader with the report alone resolves a conflict by guessing. Decided: `sentence`, in the report's preface, which each file opens with: where the prose and Appendix A differ, Appendix A holds; where Appendix A is ambiguous, §0 decides.

---


# Reader P, part 1: the language

# Principles review, reader P, part 1

Read cold at commit d38d11c8, 2026-10-09: `report/language.md` §0 to §10 and Appendices A, B, F; `report/toolchain.md` §11 and Appendix C; `proposals/nodes_and_code/mvp3.1.md` and `mvp3.2.md` as proposed additions. Nothing else was read but the code where a rule needed confirming (`stdlib/int.ern`, `stdlib/peer.ern`, `stdlib/list.ern`, the `stdlib/` and `libs/` listings), as what is built. Seventeen scratch programs were built under `readers/p1/src/` with `bin/ern`; where a finding names one, its diagnostic or output is quoted as `ern` gave it. No node was started.

Principle 4 first, since it has no finding: the grammar of Appendix A dispatches on the first token everywhere but at the places its last paragraph names, and each of those is a one- or two-token look (`fn` + identifier or `(`; `ident` + `.` + `userop`; `ident` + `=` or `:` after a constructor's `(`; `|` + `after`; `.` after an uppercase token). Two places read a whole construct before deciding: a parenthesized list of types is an `FnType` when `->` follows its `)`, and a constructor's parenthesized argument becomes a call of its value when a second expression follows. Both keep what they parsed and reinterpret the node; neither re-reads a token, so neither is backtracking, and the prose names both. The `-` that separates bitstring specifiers never meets binary `-`, since it stands only after a `BitSpec`. The one lexical trap, `a<-1`, is named and has its help line.

## Findings, most serious first

**P1. `Code.running` is unsound as proposed.** `proposals/nodes_and_code/mvp3.2.md` §2 and §6: "`Code.running : ((s) -> Unit with m) -> List(Address(m)) with n`" and "keeps the processes with a frame of `f`'s hash, or of a lambda written in `f`"; §8 tests "a lambda's process under its enclosing function". A lambda written in `f` and spawned has a mailbox type of its own, not `f`'s, so the list types a process of mailbox `Other` as `Address(Msg)`; and an `f` whose effect is a variable, a pure function or a process-only polymorphic one, leaves `m` free, so the caller chooses the mailbox type of every process listed.

```ernest
type Msg = Tick

type Other = Beat

fn worker() : Unit with Msg = {
    let _ = spawn(fn() = other()); // a lambda written in worker
    receive { Tick -> worker() }
}

fn other() : Unit with Other = receive { Beat -> other() }

fn quiet(n : Int) : Unit = Unit
// Code.running(worker) : List(Address(Msg)) lists other's process; send(p, Tick) puts a Msg in an Other mailbox.
// Code.running(quiet) : List(Address(m)) for whatever m the caller likes.
```

A reader who knows §6.1 predicts that an `Address(m)` names a process whose mailbox is `m`, which is the one promise `send` has (§6.5). Fix: keep a process for a frame of `f` itself alone, and refuse an `f` whose mailbox type is not known whole where `Code.running` is written, as `Peer.key` is refused (§3.11, §8.7); a frame of a `with Msg` function is then sound, since §6.1 lets it run only in a `Msg` process.

**P2. Two of §9's functions are not values.** `language.md` §3.11: "`Peer.spawn` and `Peer.spawnMonitored` are called where they are named, and are not taken as values"; and "The function a spawn on a peer starts is the name of a top-level `fn` or `foreign fn` declaration ... a lambda written in the same definition ... or a `fn` declared in the same definition ... Any other expression is refused, a function that came as a parameter, in a message or from a call among them". §9.5 lists them beside `spawn`, of which §6.9 says "Where `spawn` is passed as a value". So §9 holds two names that are forms, with a parameter whose argument is restricted by its syntax, which no type shows.

```ernest
fn start(f : () -> Unit with Never) : Unit with m =
    match Peer.spawn("w", f, 1000) { Left(_) -> Unit | Right(_) -> Unit }
// t7.ern:3:27: Peer.spawn starts f, a function that came as a value, whose captures the compiler does not see

export fn main() : Unit = { let s = Peer.spawn; Unit }
// t8.ern:3:13: Peer.spawn is called where it is named, so that the compiler sees the function it starts
```

A reader who knows §5.6 ("A qualified operator is a function value") and §6.9 predicts that every named function is a value and that `Peer.spawn` takes an `f` as `spawn` does. The departure is stated, and its reason is sound: a function's captures are not in its type, and a foreign type's values cannot be told from the host's at run time, so the check must be at compile time and must see the function. Fix: either the mark on function types for what a closure captures, which decides the question in the type, or a §9.5 that lists the two apart from the functions, as forms, with §2.4 counting the cost; the §0 sentence S2 below decides which.

**P3. §7.4 does not say which refusals fault and which answer a value, and the report goes both ways.** `language.md` §7.4: "A function faults only where it cannot return, where its result is a `Float` the finite range cannot hold, or where the failure is the runtime's own, a boundary crossed, a limit of the host met" and, in the same paragraph, "A refused request faults the process that made it". §8.7: an offer "under a key a living process holds faults the caller with `Fault("counter is offered by a living process")`"; `stdlib/peer.ern` has `offer : (Key(m), Address(m)) -> Unit with n`, so there is no value to answer. Yet §8.2 refuses a subscription with `Left(NotATerminal)`, and §8.7 answers a key the configuration does not list with `NotListed`, a value. A second offer could return; it is refused for the program's own mistake. "Refused request" has no entry in Appendix F and no rule that tells it from a request answered `Left`.

```ernest-fragment
let _ = Peer.offer(key, self());
Peer.offer(key, self())   // faults the caller: "counter is offered by a living process"
Terminal.subscribe(Wrap)  // answers Left(NotATerminal): a refusal, as a value
```

A reader who knows §7.1 predicts that a failure the caller can act on, trying another key or another process, is a value. Fix: one sentence in §7.4 that names the line, "A failure the program can act on is a value; the program's own mistake, and the runtime's, is a fault", and `Peer.offer`'s fault, as a program's mistake, then stands under it by that line and not by "refused request", which goes.

**P4. A negative duration or count is corrected unsaid.** `language.md` §7.4: "A count or a duration below 0 is none, and a restart window is corrected as §6.9 says ...; no other value is corrected unsaid." So `receive { after -1 -> e }` waits not at all and `Address.call(a, r, -5)` ends its wait at once. Built and run:

```ernest
export fn main() : Unit with m = {
    receive { after -1 -> Io.println("after -1 ran") };
    match Address.call(spawn(fn() = serve()), fn(reply) = Get(reply = reply), -5) {
        Some(n) -> Io.println("answered") | None -> Io.println("none")
    }
}
// prints: after -1 ran / none
```

§0's host paragraph says that an outcome which "would be silent, a truncation, a coerced value" is "met by a check on the value or a refusal of the form"; this is Ernest's own coerced value, by Ernest's own rule. The reader of principle 1 knows processes as Erlang has them, and Erlang's `receive ... after -1` is a `badarg`: that reader predicts a fault. Principle 3 says a rule the value decides is "a value, a message, or a fault when it runs"; a correction is none of the three. Fix: `Fault("a duration is 0 or more")` at the `after`, the call, the find and the spawn, and the restart limit's `restarts` and `within` likewise, with §7.4's sentence rewritten to "no value is corrected".

**P5. Two mechanisms for code written once over several types.** `language.md` §4.9 states the requirement, "`fn fromList(list : List(a)) : Set(a) needs a.compare`", and in the same section the operations record, "Code written once over several representations of a type takes an *operations record*". The requirement reaches `compare`, `negate`, the operators and `show`; the record reaches anything. At `compare` the two overlap: `Operations(compare : (a, a) -> Ordering)` filled by `..Int` says what `needs a.compare` says.

```ernest
fn unique(list : List(a)) : List(a) needs a.compare = OrderedSet.toList(OrderedSet.fromList(list))

type Ord(a) = Ord(compare : (a, a) -> Ordering)
fn unique2(list : List(a), ord : Ord(a)) : List(a) = ...   // the same job, the second way
```

A reader who knows principle 2 predicts one mechanism. What the requirement buys over a parameter is one thing a parameter cannot: `x < y` and `-x` resolved on a type variable (§4.8, §5.1), so that an operator keeps its spelling in generic code; the rest, `fromList(xs)` for `fromList(xs, Int.compare)`, only shortens, which principle 2 names as the one thing that stays out. Fix: §4.9's first sentence should say what the requirement is for, "a requirement exists so that an operator, `compare` and `negate` resolve on a type variable as they do on a type; what a call writes stays written", and `show` should then be weighed against that sentence, since it is no member and no operator.

**P6. One word `when`, two guards.** `language.md` §5.9: "A guard is a `Bool` expression with no mailbox effect that sees the pattern's variables and the enclosing scope." §6.3: "a `receive` guard is a *guard expression*. Its operands are the variables in scope ..., literals, negative numeric literals, and nullary constructors ... A guard expression calls nothing and cannot fault", and `<` in it compares "the types whose `compare` §9.6 provides" alone. Built:

```ernest
fn isBig(n : Int) : Bool = n > 10
fn loop() : Unit with Msg = receive { Num(n) when isBig(n) -> Unit | Num(_) -> loop() }
// t1.ern:8:21: a `receive` guard combines `true`, `false`, Bool variables, and comparisons with `!`, `&&`, and `||`, and calls nothing
//   = help: receive the message and `match` it
fn wait(limit : Coin) : Unit with Msg = receive { Paid(c) when c < limit -> Unit | Paid(_) -> wait(limit) }
// t17.ern:10:22: a `receive` guard orders only Int, Float, String, and Char, not Coin
```

The same `when` over the same pattern on the same type is a different language in the two forms, and the help line says the second is the first: "receive the message and `match` it". The reader who knows `match` predicts its guard; the reader who knows Erlang predicts the restriction, so principle 1 splits and does not decide, while principle 2 counts two concepts, "guard" and "guard expression", both in Appendix F. The restriction is the host's, taken as Ernest's own without the sentence that says so. Fix: state in §6.3 why the guard is narrower, "a guard selects without removing, so it calls nothing that could fault or wait", so the reader has the rule and not only the list; the §0 sentence S4 decides whether a narrower form under one word is admitted at all.

**P7. "A monitor is the one link between processes; there is no other" is false three times in the report.** `language.md` §6.9. In the same section: a resource "belongs to the process that opened it or was given it, and is killed when that process dies", a link. §6.6: `Address.callForever` "faults the caller: with the callee's cause where the callee faulted", a link that carries the cause. §6.5: a fault in an adapted address's function "is the target's ...: the process `addr` names dies of it, and the sender goes on", though §7.3 says "A fault ends the process that meets it" and the sender is the process that meets it. Built and run:

```ernest
let adapted = via(t, fn(n : Int) = Wrap(n / 0));
send(adapted, 1);
Io.println("sender lives");
// prints: sender lives / T14.main:7 faulted: division by zero / Fault("division by zero")
```

A reader who knows §7.3 predicts the sender dies. Each rule has a reason, and each is stated where it stands; the sentence in §6.9 and the sentence in §7.3 are the defects. Fix: §6.9, "A monitor is the one link a program makes between two processes; a resource ends with its owner, and the caller of `callForever` with its callee"; §7.3, "A fault ends the process that meets it, or, for a function applied on a message's way (§6.5, §6.9), the process the message is for."

**P8. §9's criterion for the prelude admits thirteen functions and four types §9 does not list.** `language.md` §9: "a function is the prelude's where a rule of this report names it", and "A type is the prelude's when the language's rules name it". Rules of §1 to §8 name `Int.div`, `Int.rem`, `Int.toFloat`, `Float.round`, `Float.truncate`, `Float.floor`, `Float.ceil` (§3.1 states their behaviour), `Process.fromAddress` (§6.5, §6.9), `Foreign.from` (§4.7, §8.4), `Terminal.subscribe` (§8.2), `Os.exit`, `Os.start` (§8.6), `Os.workingDirectory` (§7.4); and the types `Foreign.Term` (§3.8), `Supervisor` (§6.9), `Terminal.Event` (§8.2) and `Peer.Failure` (§6.7). §9 says only of `Peer`'s five that they "are the library's the same way". The count of principle 5 depends on the criterion, and the criterion as written gives 51 functions and 26 types, not 38 and 22. A reader predicts that the list and the criterion agree. Fix: drop the criterion's first clause; "The prelude is what §9 lists; a rule elsewhere that names a library function names it as the library's, by its namespace."

**P9. A proposed rule of the language exists for the runtime's convenience.** `mvp3.2.md` §5 and §6: "A table holds no function. The compiler refuses `Ets.Table(k, v)` where `k` or `v` holds a function type", because "every holder of a function is a process, and the host's check sees it" when a unit is let go. A program that never ships code, on a node or not, loses function-valued tables so that a node may unload units; principle 5 says a feature costs a program that does not use it nothing. A reader who knows §3.11 predicts that a table, which never leaves its node, holds what the node holds. Fix: the §0 sentence S6; under it the rule becomes a limit the report states, "a unit a table's function holds is never let go", and the refusal goes.

**P10. `Address.call` is qualified; `send`, `answer`, `kill`, `monitor`, `via`, `spawn` are bare.** `language.md` §9.4 and §9.5. Built: `let _ = call(a, fn(reply) = Get(reply = reply), 100)` gives `t9.ern:6:13: unknown name call`. Both call functions are "the runtime's, as the process functions of §9.4 and §9.5 are" (§9), yet they alone carry a type's namespace, and `Address` is otherwise a namespace of no module. A reader who knows `send(a, v)` predicts `call(a, request, ms)`. Fix: `call` and `callForever` bare in §6.6 and §9.5, or every process function under `Address.`; one of the two.

**P11. `kill` takes an address, `monitor` a `Process`.** `language.md` §6.9: "`monitor(p, wrap)` ... `p` is a `Process`, the identity of a process (Appendix E.21), which `Process.fromAddress(a)` gives for an address `a`; `kill` takes the address (§6.5)." Built: `monitor(a, Gone)` with `a : Address(Never)` gives `t2.ern:6:13: the argument does not fit monitor: expected Process, found Address(Never)`. A reader who knows `kill(a)` predicts `monitor(a, wrap)`, as Erlang's `monitor` takes the pid it would `exit`. The reason holds, a `Down` carries a `Process` because `Down` has no type argument for `m`, so watching again needs the identity, but §6.5 and §6.9 never say it. Fix: one sentence in §6.5, "An address is the permission to send to a process and to kill it; a `Process` is its identity, which a `Down` carries and a monitor watches", so the reader predicts the two handles before meeting them.

**P12. A local `fn` and a `let`-bound lambda overlap, and differ in a table the reader must learn.** `language.md` §4.6, §5.4, §6.6, §4.9: a block `fn` sees its own name and may not shadow a name in scope; a `let` lambda may not name itself and may shadow; both are generalized (§3.9); a `fn` declares a requirement (§4.9) and a `let` cannot; "A local `fn` may not capture a reply-carrying value" while a lambda may. Built: `fn g() : Unit with m = answer(reply, 1); g()` gives `t4.ern:3:5: the reply-carrying value reply is captured by a local function`, and `let g = fn() = answer(reply, 1); g()` compiles. A reader who knows one named local function predicts one set of rules; the reader of SML and OCaml predicts `let` and `let rec`. Principle 2 names four grounds for a second spelling, and recursion is none of them. Fix: state in §5.4 what a block `fn` is for, "a block `fn` exists for recursion and for a requirement; a function used once is a `let`", or let a block `let` that binds a lambda see its own name and drop block `fn`.

**P13. A prelude type's members are declared two ways.** `language.md` §4.2: "`export fn Float.+` in `float.ern` declares `Float.+`, and its `compare` and `negate` are declared unprefixed"; §4.8: "In that module the prefix is allowed on an operator only". `stdlib/int.ern` as built: `export fn Int.+(...)`, `export fn negate(...)`, `export fn compare(...)`. A user type writes `fn Coin.compare` (built, t16, runs). A reader who knows `fn Coin.compare` predicts `fn Int.compare` in `int.ern`; the grammar's `DeclName` admits it. Fix: allow the prefix on every member in a prelude type's module, and the unprefixed spelling goes; `Int.compare` and `Int.negate` are then declared as `Int.+` is.

**P14. `let _ = e` stands beside `e;` for a `Unit` value.** `language.md` §5.4: "a value is discarded with `let _ = e` (§5.10), whatever `e` is, a pure one among them". Built: `let _ = Io.println("x"); Io.println("y")` compiles. Two spellings of one statement, where principle 3 admits `let _ =` as the mark of a value shown unused and `Io.println` yields none. Fix: refuse `let _ =` on an expression of type `Unit`, "nothing is discarded; write the expression", as a non-`Unit` statement is refused the other way.

**P15. The raw string's spelling comes from no language the reader knows.** `language.md` §2.5: "A raw string, `` `\d+\.\d+` ``, is a `String` whose text is taken as written". Principle 2: "A literal form enters where the reader of principle 1 predicts it"; that reader knows values as Erlang has them, whose raw string is `"""` since OTP 27, and types as SML and OCaml have them, with `{|...|}` in OCaml. Neither predicts a backtick. Fix: Erlang's triple quote, or a sentence in §2.5 that states the departure and what decided it.

**P16. Two rules of the language exist only for a library.** `language.md` §8.7: `measures` "names which of the host's measures run on the node, `cpu`, `memory` and `disk`", with their parameters, which no rule of §1 to §10 uses; it exists for the balancer under `libs/`. §6.9: "A child of a `Supervisor` (Appendix E.22) also runs `f()` again when its supervisor asks ...", a paragraph of the language that defines the behaviour of one library type. Each is a rule that exists only for another. Fix: `measures` to Appendix C and G alone, named in §8.7 by one line; the restart-asked paragraph to E.22, with §6.9 keeping the one sentence a reader must not miss, "a restart asked of a process by the library's supervisor restarts it as a fault does, and counts against no limit".

**P17. Three marks are printed in every type and can be written in one place.** `language.md` §11.5: "In a printed type a variable with the equality constraint is `a=`, one that is not reply-carrying `a!`, and a process-only effect variable ... `m+` ... A printed type is not an annotation, and no mark can be written in one; `=` is written on a foreign type's parameter alone (§4.7)." §4.7 writes it in a foreign function's parameters too. A reader who copies `discard : (a!) -> Unit` from `ern doc` into an annotation is refused. The asymmetry is forced, since the other two are inferred from a body a foreign function lacks, and §4.7 says so; §11.5's sentence does not. Fix: §11.5, "no mark but `=`, and that in a foreign declaration alone (§4.7)".

**P18. `Prelude.` is written only where a name is hidden, and `Prelude` is a reserved name outside §2.4.** `language.md` §4.2: "`Prelude.Some` in a module that declares no `Some` is an error" and "No module and no type is named `Prelude`". Built: `Prelude.Some(1)` gives `t15.ern:2:40: Prelude.Some is written only where the module hides the prelude's Some`. The same section refuses a module's own qualified name within it. The rule buys one spelling for each name in each place and nothing else: a program that moves a function between modules changes spellings, and a reader of OCaml predicts a qualified name is always allowed. It exists for principle 2 alone, and `Prelude` is a reserved name §2.4's count of eighteen leaves out. Fix: count `Prelude` with the reserved names (nineteen, or "eighteen words and one name"), and either keep the refusal with that cost in the log, or admit the longer spelling as a spelling, not a second way.

**P19. The proposals add a silence and leave the end's deadlock undefined.** `mvp3.1.md` §2: `Standing.start` "answers `via` of that process ... A send to it while the service is away is dropped." §6.2 of the report calls the language's one silence "an act on what has ended, or cannot be reached"; the forwarder has not ended and is reached, and drops the message with no value, message or fault. It is a library, and the proposal says every rule holds of its address, but principle 3 binds what the library does with a message it took. Also §6 of 3.1: "Once every reply is answered or its subscriber has ended, the end is MVP 3.0's"; for a program that is no node, §8.6 detects a deadlock and faults "the entry process", which at the end has died; whether a subscriber that waits in a `receive` with nothing in flight while the end waits is a deadlock, and whose fault it is, is not said. Fix: `Standing` keeps or answers, never drops, since a `call` through it already answers `None`; §8.6 in 3.1 says what a deadlock during the end is.

**P20. The proposals' examples name what the library lacks or §8.3 does not list.** `mvp3.2.md` §3: `List.length(old)` and `List.length(nodes)`; the library has `List.size` (`stdlib/list.ern`, and §4.4's example). `Peer.peers()` is in `stdlib/peer.ern` but not among the `Peer` operations §8.3 and §9 enumerate. Fix: `List.size`, and `Peer.peers` named in §8.3's list.

**P21. A named constructor is neither a value nor a function, by a rule that buys little.** `language.md` §5.6: "A named constructor is neither; it appears only in construction syntax", and §3.5: "There is no canonical order", though the same sentence makes the declared order "part of the type's identity". So `List.map(xs, fn(x) = Wrap(x = x))` where `List.map(xs, Some)` is written. The reader of SML predicts a constructor is a function. The order is canonical for storage, transport, `show` and identity; the one thing it is not canonical for is making the constructor a function. Fix: drop "There is no canonical order", and let a named constructor stand as a function value over its fields in declared order, or state what the refusal buys.

## Counts, with how they were counted

- **Reserved words: 18.** §2.4's table. Appendix A quotes sixteen of them and §2.5's `bool` the other two; checked by listing every quoted lowercase word of Appendix A. Beside them one reserved *name*, `Prelude` (§4.2), which no count holds (P18). The proposals add none.
- **Words read by position: 13, 16 with Appendix A's `compare`, `negate`, `show`.** The eleven `BitSpec` words, `needs`, `derives`; and `compare`, `negate`, `show` in `Member`, `DeclName` and `TypeDecl`. Appendix A's quoted lowercase words are exactly the reserved words and these sixteen. The proposals add none.
- **Taken top-level namespaces: 29; 35 with Appendix G.** `Prelude`; the eight prelude types with members in §9, `Int`, `Float`, `Char`, `String`, `Bytes`, `List`, `Path`, `Address`; and the twenty module namespaces of `stdlib/` not among them (`Bool`, `Clock`, `Either`, `Erl`, `Foreign`, `Fs`, `Io`, `Map`, `Optional`, `OrderedMap`, `OrderedSet`, `Os`, `Peer`, `Process`, `Random`, `Set`, `Supervisor`, `Tcp`, `Terminal`, `Test`), counted from the directory as built since Appendix E was not read. `libs/` holds six (`Ansi`, `Balancer`, `Ets`, `Json`, `Load`, `Markdown`). MVP 3.1 adds `Standing` under `libs/` (36 with G); MVP 3.2 adds `Code` to the standard library (30, 37).
- **Prelude functions: 33; 38 with `Peer`'s five.** §9.4: 4 + `Io.show`, `Io.debug` = 6; §9.5: 7; §9.6: 5 + 1 + 4 + 1 + 4 + 4 + `fault` = 20. By §9's criterion as written, 13 more (P8): 51. MVP 3.1 adds `Os.terminating`, named by §8.6's rule, so one more by the criterion (39/52); MVP 3.2 adds `Code.load`, `Code.hashes`, `Code.running`, named by §8.7's and §11.2's rules (42/55).
- **Prelude types: 21; 22 with `Peer.Key(m)`.** §9.1: 10; §9.2: 3; §9.3: 8. By the criterion as written, `Foreign.Term`, `Supervisor`, `Terminal.Event`, `Peer.Failure` (P8): 26. MVP 3.2 adds `Code.Hash` (23/27).
- **Primitives outside §9: 7.** Counted as the operations the language gives that no function of §9 and no module's member provides: structural `==`/`!=`, `&&`, `||`, `::`, `|>`, `<<>>` construction and matching, `receive` with `after`. Not counted: `!`, prefix `-`, `<` `<=` `>` `>=`, which resolve to `Bool.not`, `negate` and `compare`; and the forms `.f`, `..`, the fill, `<-`, `as`, `or`, which are concepts, not operations. The proposals add primitives to modules, not outside §9: 3.1 the end's subscription behind `Os.terminating`; 3.2 the stack walk behind `Code.running` and the code exchange.
- **Concepts: 132.** Appendix F has 152 entries. Nineteen cite no section of §0 to §10: eight the toolchain's (build root, diagnostic, line mode, live region, load path, runner, span, startup file) and eleven the library's (admission rule, child, container, grapheme, group, sequence, shape rule, shim, strategy, supervisor, vocabulary); less "primitive": 132. Twenty of the 132 are the node's words, read here for the first time (bound type, carrier, configuration directory, connection, detector, dial, fingerprint, frame, gateway, handshake, key, loss, measure, node, note, offer, peer, remote computation, start number, tick): 112 without them. The last count's 116 lies between, so its method held a few entries with a language citation as the toolchain's or the library's, most likely among compiled interface, configuration directory, entry point, `Prelude`, standard library, system module, system process, system reference and measure. MVP 3.1 adds hash, identity, closure, unit, code table, cookie and subscriber, and removes fingerprint: +6, 138. MVP 3.2 adds exchange and bare node: +2, 140.

## The rules: what each buys, what is lost without it, whether §0 admits the opposite

"Opposite" says whether §0 as written would admit the opposite rule as well; where it would, the principles do not decide, and a sentence under S below is proposed. *Little* marks a rule whose answer is little; *another* marks one that exists only for another rule, document or component.

| Rule | Buys | Lost without it | Opposite admitted? | Mark |
|---|---|---|---|---|
| §2.1 UTF-8 source, control characters refused everywhere | one encoding, nothing invisible in the text | nothing | No: P3 | |
| §2.2 `///` doc blocks; a blank line decides the module's | one documentation form | nothing | Partly: an explicit module-doc marker is admitted too; P3 argues against whitespace with meaning | little |
| §2.3 ASCII identifiers | no confusable names | names in other scripts | Yes: OCaml's reader has ASCII, Erlang's has Unicode atoms | |
| §2.3 case decides the token class | first-token dispatch (P4) | the parser's simplicity | No: P4 | |
| §2.4 eighteen reserved words | the count | — | No: P5 | |
| §2.5 literals carry no sign; `-` is prefix | one negation | `-1` as a token | No: P2 | |
| §2.5 `0x`, `0o`, `0b` lowercase; `_` groups digits | OCaml's reader predicts them | nothing | No: P1 | |
| §2.5 raw strings in backticks | regexes and paths as written | the same with escapes | Yes: P1 names no language with backticks (P15) | |
| §2.5 no overloaded literals | HM without defaults | `1` as a `Float` | No: P3 ("no default") | |
| §2.6 max-munch; `a < -1` | a simple lexer | `a<-1` | No: P4 | |
| §2.6 prefix `-` and `!` not twice without parentheses | nothing a reader needs | `- -x` | Yes: OCaml admits `- -x` | little |
| §2.6 `\|` never a binop; `::` right-assoc; `\|>` loosest | OCaml's reader predicts them | — | No: P1 | |
| §3 `(` read whole; `->` decides `FnType` | no lookahead at `(` | — | No: P4 | |
| §3.1 `Int` unbounded; `/` truncates; `%` takes the dividend's sign | Erlang's reader predicts them | — | No: P1 | |
| §3.1 no `Infinity`, `NaN`, `-0.0`; a fault instead | `==` an equivalence on `Float`; `compare` total | IEEE's special values | Mostly no: Erlang faults on `Inf`/`NaN`; `-0.0` Erlang keeps, P3 drops as a value that prints apart and compares equal | |
| §3.2 `#(` tuples of two or more | no lookahead at `(` | `(a, b)` the reader predicts | No: P4 over P1 | |
| §3.4 arity in the type; no partial application | call sites that show every argument; Erlang's functions | currying | No: P1's split (a function value is a value, Erlang's) | |
| §3.4 `with` binds to the nearest arrow | one reading | — | No: P4 | |
| §3.5 one positional field or named fields; order is identity | no positional records beside tuples | `Pair(a, b)` positional | No: P2 (the tuple is the one positional product) | |
| §3.5 "There is no canonical order"; a named constructor is no value | nothing | `List.map(xs, Wrap)` | Yes (P21) | little |
| §3.5 `derives compare`, and nothing else | ordered containers of records without a hand-written `compare` | writing it | Partly: deriving nothing is admitted; deriving everything is refused by P3; a word for one member is P5's cost | |
| §3.5 a selector needs the field on every constructor | total selection | partial selectors | No: P3 | |
| §3.6, §4.4 abstract types exported, never private | a refusal of a form with no effect | nothing | No: P3 | |
| §3.7 `Never` ordinary; `fault : (String) -> a` | OCaml's reader predicts `'a` for divergence | — | No: P1 | |
| §3.8, §3.11 bound types refused at the three operations | a value that cannot cross is refused before it starts | run-time faults | No: P3 | |
| §3.9 generalize `fn`, top-level `let`, block `let` of a lambda; pin the rest | no value restriction as a concept | `let xs = []` polymorphic in a block | Yes: OCaml's value restriction is admitted too; "pinning" is a concept of its own | |
| §3.9 annotation variables rigid; one in a non-generalized lambda refused | one meaning for a named variable | `fn(x : a) = x` inline | No: P2 (one meaning) | |
| §3.9 no polymorphic recursion | simpler inference | functions over nested types | Yes: OCaml admits it with a full annotation, SML not | little |
| §3.9 effect polymorphism; pure fits effectful | one function type with one mark | — | No: P2, P3 | |
| §3.9 the three inferred restrictions | soundness of `==`, purity and replies | — | No: P3 | |
| §3.10 `==` structural; none on functions and addresses | `==` means one thing | `a == b` on addresses, which Erlang's reader predicts; hence `Process` (P5's cost) | Yes: Erlang admits pid equality; the choice forces `Process` and `fromAddress` | |
| §3.10 ordering through `compare` per type; none on `Bool`, `Optional`, `Path` | no invisible structural order | `true < false` (t11) | No: P3 | |
| §3.11 `Peer.spawn`'s function restricted by syntax; not a value | the capture check at compile time | a function in a message spawned on a peer | Yes (P2, S2) | |
| §4.1 module = file; acyclic | a simple build | mutual recursion across files | No: P4's spirit; Erlang admits cycles | |
| §4.2 files are namespaces; `export`; no `import` | one way to name a thing | import lists, aliases | No: P2 | |
| §4.2 taken namespaces | the library's names stay the library's | shadowing modules | No: P3 | |
| §4.2 `Prelude.` only where hidden; own qualified name refused | one spelling per place | a mechanical refactor's stability | Yes (P18) | little |
| §4.2 type members a nested namespace; coincidence with a module refused | one owner per name | — | No: P2 | |
| §4.5 one clause per `fn`; irrefutable parameters | one place to branch | Erlang's and OCaml's clauses, which P1's reader predicts | Decided by §0's order: P2 constructs, P1 audits | |
| §4.5 `with m` over a pure body refused | one annotation for pure | — | No: P2 | |
| §4.6 top-level `let` as a `Never` body; services at initialization | services without a registry | a registry | No: P3 | |
| §4.6 later `let` shadows; a block `fn` may not | an unambiguous hoisted `fn` | one shadowing rule | Yes; small | little |
| §4.7 foreign declarations; purity promised; `a=` written | the host reached with the types promised | — | No | |
| §4.8 operators resolve by operand type; undetermined refused (t10) | no numeric classes, no defaults | `fn add(a, b) = a + b` unannotated | No: P3 | |
| §4.8 the operator set closed; `==`, `<` not definable | one meaning each | user operators | No: P2 | |
| §4.8 prelude type's `compare`, `negate` unprefixed | nothing | one spelling (P13) | Yes | little |
| §4.9 requirements beside operations records | `<`, `-` on a type variable | writing `compare(a, b) == Less` | Yes (P5, S5) | |
| §4.9 a top-level `let` declares no requirement | forced: no signature | — | No | another |
| §5.1 strict, left to right, callee first | Erlang's order | — | No: P1 (OCaml is right to left; values are Erlang's) | |
| §5.3 lambda body the longest `Expr` | no lookahead | — | No: P4 | |
| §5.4 non-last statement is `Unit` (t13); `let _ =` discards | a dropped value is refused | — | No: P3 | |
| §5.4 `let _ =` admitted on `Unit` too (t6) | nothing | — | Yes (P14) | little |
| §5.4 block `fn` beside `let` lambda | recursion, a local requirement | one named local function | Yes (P12) | |
| §5.5 `<-` on `Either` and `Optional` alone | a sequence where `match` would nest | `let*` over any type | No: P2 names it; P5 refuses the general form | |
| §5.6 all fields given; `..p` update; paths | no half-built values | — | No: P3 | |
| §5.6 the fill `C(..N)` | a record filled from a namespace in one line | writing each field | P2 and P3 were each given a clause to admit it; as written they decide for it | |
| §5.7 the pipe fills the first slot; constructions not filled | `x \|> f(a)` reads | — | No: P1 with §3.4's arity | |
| §5.8 `if` beside `match` on `Bool` | what every reader writes | — | Yes by P2's letter; P1 decides in practice (S1) | |
| §5.9 coverage and redundancy are errors; guards count for neither | nothing silent | warnings | No: P3 ("there is no warning") | |
| §5.9 or-patterns; §5.10 `as` | a body not repeated; a value not rebuilt | — | No: P2 names both | |
| §5.11 bitstrings with eleven position words | Erlang's bit syntax | functions over `Bytes` | No: P1 (values as Erlang's) over P5 | |
| §6.1 the mailbox type the only mark on a function type | one effect | — | No: P2, P5 | |
| §6.2 `spawn`, `spawnMonitored`, `Peer.spawn`, `Peer.spawnMonitored` | a reason from the start; a node named only where one is | one spawn with a place, costing every local spawn a word | No: P5 | |
| §6.2 the one silence: an act on what has ended | Erlang's `!` | a fault on a dead address | No: P1 | |
| §6.3 the receive guard expression | selection without removal, as Erlang has it | guards that call | Yes (P6, S4) | |
| §6.3 `after` evaluated on entry; no upper bound | — | — | No | |
| §6.5 `via` beside a forwarding process | a typed sub-address without a process | one way to adapt | Yes: §0 does not say whether an adapter is a value or a process; costs §6.4's exception, §6.5's fault target, §8.7's extra hop | |
| §6.5 no registry; a service is a binding or a key | nothing invisible reaches a process | names | No: P3 | |
| §6.6 `call` with a time, `callForever` without; the reply consumed once | an answer at most once, visible | — | No: P3; `callForever` is Erlang's `call` with `infinity` | |
| §6.6 `Address.call` qualified, the rest bare | nothing | one naming (P10) | Yes | little |
| §6.7 remote computation is a spawn with the node named | nothing placed invisibly | a scheduler | No: P3 | |
| §6.9 `monitor` takes a `Process`, `kill` an `Address` | watching again from a `Down` | one handle (P11) | Yes; the reason is sound and unstated | |
| §6.9 `restarting` in the prelude; its cancellations | a service that keeps its address | — | No: P3 (the word is written) | |
| §6.9 the restart asked for by a `Supervisor` | E.22's behaviour | — | — (P16) | another |
| §6.9 resources die with their owner | no leaked sockets | — | No: P3; §6.9's "one link" sentence is the defect (P7) | |
| §6.10 code replacement by a message alone | one mechanism | hot code loading | No: P2, P3 | |
| §7 no exceptions; value, message or fault | failure visible | `try` | No: P3 | |
| §7.4 "a refused request faults" | — | — | Yes (P3, S3) | |
| §7.4 a negative count or duration is none | nothing | a fault Erlang's reader predicts | Yes (P4, S3) | little |
| §8.1 `main`'s shape; `--main` | — | — | No | |
| §8.2 system references as private bindings of modules | ambient use without threading | passing `stdout` everywhere | No: P3 as amended | |
| §8.2 the terminal claimed for keys or lines, first claim stands | one reader | — | No: P3 | |
| §8.3, §8.7 peers, keys and `keys` in configuration; `find` in its order | a program that names no topology | the text showing where a service is | Yes: §0 does not say where topology lives (S7) | |
| §8.7 `measures` | the balancer's input | — | — (P16) | another |
| §8.7 `Peer.offer` faults under a held key | — | `Left(Held)` | Yes (P3, S3) | |
| §8.7 one build per connection, by fingerprint | a message's type known the same at both ends | mixed builds (3.1 lifts it by hash) | No: P3 | |
| §8.7 `NotLoaded` by module | a spawn that starts only what is whole | — | No: P3 | |
| §8.5 the standard library initialized whole | one order | start-up time | No: P5 is about text, not time | |
| §8.6 the end at the entry process's death; `ProgramEnd`; deadlock a fault | a program that ends where its text ends | — | No: P3 | |
| §9 the prelude's criterion | — | — | Yes (P8, S9) | |
| §10 the runtime's requirements | — | — | No | |
| §11 one command; long options; refusals that name the fix | — | — | No: P2, P3 | |
| 3.1 a hash names a definition; a type's hash covers its name, a function's not | nodes of different builds | — | No: P3 (nominal types, structural code) | |
| 3.1 `Os.terminating`; the end waits for its subscribers, ends on their death | a process told before the end | a `terminate` callback with a timeout | Yes: §0 says nothing of the runtime's own waits (S8); the shape is `callForever`'s | |
| 3.1 `Standing.start` | a client with no code of its own | — | Partly (P19): a drop by a living process | |
| 3.1 the shell's two versions of a type | a process keeps its code | — | No: P3 | |
| 3.2 code crosses with a spawn, verified by hash | a bare node; a fix from the shell | copying builds | No: P3 (the same call, slower once) | |
| 3.2 `Code.load`, `Code.hashes`, `Code.running` | an upgrade tool in Ernest | — | `running` as proposed: no (P1 refuses it as unsound) | |
| 3.2 a table holds no function | a unit let go | function-valued tables | Yes (P9, S6) | another |

## Proposed sentences for §0

Each decides a question the table marks "Yes" and names the finding it settles.

- **S1** (to principle 2; `if`, P14, P13): "A literal form, and `if` beside `match` on `Bool`, enter where the reader of principle 1 writes them; a function stands beside the operator that is its spelling, and no other pair stands."
- **S2** (to principle 5; P2): "Every function the prelude or a library names is a value, taken, passed and stored as any function is. What cannot be is a form of the grammar and a word of §2.4, and is counted as one."
- **S3** (to principle 3; P3, P4): "A failure the program can act on is a value; the program's own mistake, and the runtime's, is a fault; no value is corrected unsaid."
- **S4** (to principle 2; P6): "A reserved word has one meaning wherever it stands. Where one word opens a narrower form, the narrower rule says what bounds it, and the reader it answers to."
- **S5** (to principle 3; P5): "What a call supplies without writing it is a member alone, reached by a type as an operator is; everything else a call writes."
- **S6** (to principle 5; P9, P16): "No rule of the language exists for the runtime's or a library's convenience: a cost the runtime cannot bear is a limit the report states, never a form the compiler refuses."
- **S7** (to principle 3; §8.3, §8.7, the bare node): "A program's text says what it does; its configuration says where. The text names a place by the configuration's name, and a program that is no node writes nothing of it."
- **S8** (to principle 3; 3.1's end, `callForever`): "A wait on another process ends by a time the program writes or by that process's end; the runtime chooses no time of its own."
- **S9** (to principle 5; P8): "The prelude is §9's list. A rule elsewhere that names a library function names it as the library's, by its namespace."
- **S10** (to principle 1; P15): "A literal is spelled as Erlang spells it, since a literal is a value; where Erlang has no spelling, the report states the one it takes."

---

# Reader P, part 2: the library

# Principles review, reader P part 2: Appendix E and G, and MVP 3.1 and 3.2, against §0

Read cold at commit d38d11c8 on 2026-10-09: §0, §9, the whole of library.md (D, E.0, E.1 to E.27, G.1 to G.6), Appendix F, then proposals/nodes_and_code/mvp3.1.md and mvp3.2.md. Where a rule's meaning was in doubt, stdlib/, libs/ and erl/ were read as what is built. Nine probe programs ran under bin/ern in the reader's scratch directory; their outputs are quoted. Nothing in the repository was edited and no node was started.

## Findings, most serious first

**P40. A compiler rule names a library's type.** mvp3.2 §5.6 and §6: "The compiler refuses `Ets.Table(k, v)` where `k` or `v` holds a function type." Appendix D shows `Table(k=, v)` with "type parameters the implementation never sees", and §4.7 lets a foreign type's parameters be any type. Under the proposal the compiler carries one library's name and a rule for it alone, so that the host's `check_process_code` sees every holder of a function (principle 5: a concept for one library; principle 1: a reader of D predicts any argument). Program: `let handlers : Ets.Table(String, (Int) -> Int) = Ets.new()`, which compiles today and is refused under MVP 3.2 by a rule no page of `Ets` can state as its own. A reader predicts that what a foreign type may hold is §4.7's to say, for every foreign type alike. Fix: a sentence of §4.7, "a foreign type's argument holds no function type", stated once for every foreign type, with `Ets.Table` as its example; or no let-go of units, which MVP 3.1 does without.

**P41. `Code.running` admits one arity.** mvp3.2 §2: `Code.running : ((s) -> Unit with m) -> List(Address(m)) with n`. Arity is part of a function type (§3.4), so only a loop of one parameter can be named. Program: `fn serve(total : Int, log : List(String)) : Unit with Msg = receive { ... }` and `Code.running(serve)`, a type error, where `Code.running(count)` with `count(total : Int)` is accepted. A reader predicts any process loop, as §6.10 writes them with whatever state they carry. Fix: `Code.running` is a form the compiler checks as it checks `Peer.spawn`'s function (§3.11), taking a declaration's name of any arity whose result is `Unit with m`; or the page states the limit, and a loop of two parameters is written over a tuple.

**P42. `Load.cpu` hides a per-caller state its page misstates.** G.4: "`cpu` the fraction of the processor's time busy since the previous call on the node". The shim is `cpu_sup:util/0` (libs/load/load.ern), whose page says the utilisation is since the last call to `util` by the calling process, and that a process's first call answers the utilisation since the system booted. So two processes measuring do not interfere, as G.4's sentence says they do, and each one's first reading is of the machine's whole life (principle 3; E.0 rule 1's "exactly is by the host function's own documentation: its edge cases"; shape rule 6). Program: `spawn(fn() = Io.debug(Load.cpu()))` twice on a node that runs `cpu`: each prints the fraction since boot. A reader predicts a measure of the moment, the same for every caller. Fix: the page says "since this process's previous call, and at its first call since the system started"; or `cpu(window)` as `schedulers(window)`, two readings around the window in one process, which is the measure a balancer wants.

**P43. `Peer.Failure` is a second error type beside `Io.Error`.** E.1: "`Error` is the error of every system module." E.27: `type Failure = NotListed | Unreachable | Refused(String) | Timeout | NotOffered | OtherType | NotLoaded`, with `Timeout` and `Refused` spelled again, and `Unreachable` spelled a third time beside `Reason`'s. Shape rule 8 says a function that waits "answers `Left(Timeout)`" without naming whose. Program (errs.ern): `fn describe(error : Io.Error) : String = match error { Timeout -> "late" | _ -> "other" }` applied to `Peer.find`'s `Left(failure)` is refused, "the argument does not fit describe: expected Io.Error, found Peer.Failure", and the clause itself is "unknown constructor Timeout" in a module that writes both. A reader who knows E.1 predicts `Peer.find : (Key(m), Int) -> Either(Io.Error, Address(m))`. Fix: E.1's sentence gains "but `Peer`, whose failures are its own (E.27)", and shape rule 8 says `Timeout` is `Io.Error`'s where a function answers that type; or `NotListed`, `NotOffered`, `OtherType` and `NotLoaded` join `Io.Error` and `Failure` goes.

**P44. E.0 rule 1 and E.2 disagree over the list operations the host does exactly.** Rule 1: "Where a function of the host does exactly an operation's work, the operation is a primitive, a shim of that function, so that a program runs at the host's speed." E.2: "The primitives are `size`, `unique`, and a function of the host's beneath `sort` ... The rest is Ernest." `List.reverse` is a fold (stdlib/list.ern:416) where `lists:reverse/1` is exact; `List.contains` is a loop over `==`, which compiles to `=:=` (ern_emitter.erl:1309), where `lists:member/2` is exact; `indexed` is `lists:enumerate/2` from 0, `zip` is `lists:zip/3` with `trim`, `unzip` is `lists:unzip/1`, each exact by its page. Rule 1's exemption for a value the language owns reaches only what the host does *almost*. Program: `List.reverse(List.range(1, 1_000_000))`. A reader who knows rule 1 and Erlang predicts the BIF's speed. Fix: E.2 names `reverse`, `contains`, `indexed`, `zip` and `unzip` primitives; or rule 1 gains "an operation on a value the language owns that is one pass with the language's constructors stays Ernest though the host does it exactly", and E.2 keeps `size` and `unique` by that sentence's exception.

**P45. `List.remove` is by value where `List.get` is by index.** E.2: `List.get : (List(a!), Int) -> Optional(a!) // by index from 0` and `List.remove : (List(a=!), a=!) -> List(a=!) // the first occurrence`. Shape rule 2 says "`get` for lookup by index or key, `put` for insertion, `remove`", and nothing of what `remove` takes; on `Map` and `Set` the two agree. Program: `List.remove([10, 20, 30], 1)` is `[10, 20, 30]`, while `List.get([10, 20, 30], 1)` is `Some(20)`. A reader who has written `get` predicts `[10, 30]`. Fix: shape rule 2 gains "`remove` takes what `get` takes, an index or a key, and a removal by value is the program's over `filter` or a loop"; `List.remove` then takes an index, an index outside the list leaving the list as it was.

**P46. `Char.isDigit` accepts digits nothing else in the library reads.** E.6: "`isDigit` is general category Nd ... `isAsciiDigit` is the digits `0` to `9` alone, those `String.toInt` reads", and `digitValue` reads "0 to 9, then a letter". Two overlapping predicates for one word (principle 2), and the wider one has no consumer: Markdown is the only user of either outside `Char`, and it uses `isAsciiDigit`. Program (probe.ern): `Char.isDigit('\u{663}')` is `true`, `Char.digitValue('\u{663}', 10)` is `None`, `String.toInt("\u{663}")` is `None`. A reader predicts that a digit `isDigit` admits has a `digitValue`. Fix: `isDigit` is the digits `0` to `9` and `isAsciiDigit` goes; or `digitValue` and `String.toInt` read every Nd digit by its numeric value, and `isAsciiDigit` goes.

**P47. `Json.parse` keeps a repeated member's first value; every `fromList` keeps the last.** G.6: "where a text names a member twice the first is kept"; E.3: `Map.fromList // a later pair wins`; E.26: "a later pair's value wins". The choice is one line of erl/json/src/ern_json.erl, which pushes members and hands the reversed list to `maps:from_list/1`. Program (dup.ern): `Json.parse("{\"a\":1,\"a\":2}")` is `Right(Object(Map.fromList([#("a", Integer(1))])))`; `Map.fromList([#("a", 1), #("a", 2)])` is `Map.fromList([#("a", 2)])`; `OrderedMap` likewise. A reader who knows `Map.fromList` predicts `Integer(2)`. Fix: keep the last, as the library's `fromList`s do, by reversing the accumulator before `maps:from_list`; or the page says why JSON differs.

**P48. No rule of E.0 admits a type.** The four admission rules admit functions; a type enters by being the runtime's (rule 1) or by a mention: E.25 and E.26, 44 declarations in two namespaces, "Nothing is a primitive: the module is Ernest over `List`", stand in Appendix E because §3.10 names "an ordered set or map". What they buy: a set or map in the order of a `compare`, which merges what `compare` calls `Equal`, as data. What a program has without them: `List.sort(Set.toList(set), compare)`, a pipe of two, and a wrapper type for an order that is not `==`'s. Program: the two modules' pages, read for the rule that let them in; none is cited. A reader who knows rule 4 predicts that a container written whole over `List` in a page is a library's, as `Markdown` is. Fix, a sentence for E.0: "A type enters Appendix E where rule 1 makes it the runtime's, or where a rule of §3 to §9 names it; any other type, with its structure's vocabulary, is a library's." E.25 and E.26 pass by §3.10; the next type is decided by E.0 and not by a mention.

**P49. `Erl` is a namespace for one function.** E.19: `Erl.atom : (String) -> Foreign.Term`, and shape rule 3 names it. E.12's `Foreign` holds the rest of the host boundary; the runtime is one, "for the BEAM runtime" (§8.4), so the neutral-and-BEAM split names no second thing (principle 5). Program: `erl.ern` at a source root is refused as a taken namespace, for `atom`. A reader predicts `Foreign.atom`. Fix: `Foreign.atom`, E.19 folded into E.12, shape rule 3's example changed; 28 taken namespaces.

**P50. `Int.div` and `Int.rem` pair with `/` and `%`, and `Float` has no such pair.** §7.4: "`Int.div` and `Int.rem`, Appendix E.8, return `Optional` instead." Rule 4 names the pairs it admits whole, and an operator with its `Optional` form is not among them; `1.0 / 0.0` faults as `1 / 0` does (§7.4, "float arithmetic error"), and E.9 has no `div`. Program: `Int.div(1, 0)` is `None`; `Float.div(1.0, 0.0)` is an unknown name. A reader who knows `Int.div` predicts `Float.div`. Fix: rule 4 names the pair, "an operator that faults with its `Optional` form", and `Float.div` enters; or `Int.div` and `Int.rem` go, a program writing the zero test.

**P51. `List.foldRight`'s step takes the element first; every other step takes the accumulator first.** E.2: `List.foldRight : (List(a), b, (a, b) -> b with e) -> b with e // from the right, the element first`, beside `foldLeft`'s `(b, a) -> b`, `Map.foldLeft`'s `(b, k, v) -> b`, `Set.foldLeft`'s and `tryFold`'s `(b, a) -> ...`. It is OCaml's convention; principle 1 says the reader knows Ernest first. Program (probe.ern): `List.foldRight([1, 2, 3], [], fn(element, acc) = element :: acc)` and `List.foldLeft([1, 2, 3], [], fn(acc, element) = element :: acc)`, the two lambdas mirror images. A reader predicts `(b, a) -> b`. Fix: `(b, a) -> b`; or shape rule 1 says "a fold's step takes the accumulator on the side the fold comes from".

**P52. `Code.hashes` answers values a program cannot show, and `load` and `hashes` have no caller.** mvp3.2 §2: `Code.hashes : (Path) -> Either(Io.Error, List(#(String, Code.Hash)))`. A `Hash` is a type of the module's (written `Code.Hash` in its own listing, against shape rule 7's form); if abstract, `Io.show` writes it `<abstract>` outside its module (E.1), and no `toString` is given, so a program can compare two hashes and print neither. No example of the proposal calls `load` or `hashes`; `running` has one. `Code.running` is `with n` where `Process.live`, which also "asks the runtime about its processes", is `with m+` (shape rule 5). Program: `Io.println(Io.show(Code.hashes(path)))` prints `Right([#("count", <abstract>), ...])`. A reader predicts a hash is text or has one. Fix: `Hash` is a `String`, the digest in hexadecimal, or has `Hash.toString`; `load` and `hashes` wait for the program that needs them (E.0 counts no programs, but a function is there "where a reader who knows the type looks for it", and none looks yet); `running` is `with n+`.

**P53. `Standing.start`'s `ms` does two jobs, and the second is a wait by a clock.** mvp3.1 §2: "finds the key within `ms` ... and finds again when the service ends or its node is lost, waiting `ms` between failed finds." Shape rule 8's milliseconds "bound that one request". Program: `Standing.start(Counter.key, 5000)` with a service that comes back after 100 ms is reached after up to 5 s. A reader predicts `ms` bounds a find and nothing else. Fix: the forwarder finds on demand, when a message arrives while the service is away, each find bounded by `ms`, and waits for nothing else; a call through it then triggers its own find within the call's time.

**P54. A socket ends two ways and a program one.** E.18: `Tcp.close` answers waiting reads with `Left(Closed)` and ends the process with `Returned`; `kill` ends it as any process, "a call waiting on it faulting as §6.6 says". E.23 gives a running program `kill` alone, and `closeInput`, which closes its input and not it. Program: `Tcp.close(socket)` beside `kill(program)`, with a reader waiting on each: the first gets `Left(Closed)`, the second faults with `Fault("callee was killed")`. A reader of E.23 predicts a socket ends by `kill` alone; one of E.18 predicts `Os.stop`. Fix: E.23 says why a program has no `stop`, that its reader sees `Exited` once the program ends of its own; or E.18 loses `close`, a reader of a killed socket getting `Left(Closed)` by a sentence of §6.6's.

**P55. Rule 2's map vocabulary is short of E.3 and E.26.** E.0 rule 2: "A map adds `keys`, `values`, and `merge`." E.3 and E.26 both have `update` and `mergeWith`, so the two modules share a vocabulary the rule does not state, and a third map would not know to. Fix: "A map adds `keys`, `values`, `update`, `merge`, and `mergeWith`."

**P56. `Bytes.fromHex` stands where shape rule 3 does not put it.** Shape rule 3: "Any other conversion is its argument's module's `toX`". `Bytes.fromHex : (String) -> Optional(Bytes)` takes a `String` and stands in `Bytes`, by E.20's own sentence, "one encoding ... whose two directions stand in the module of what is encoded". A reader of shape rule 3 alone looks in `String`. Fix: shape rule 3 gains E.20's sentence, "an encoding's two directions stand in the module of the type encoded, `toHex` and `fromHex`".

**P57. `Terminal.columns` reads a specification in the standard library.** E.16: "An escape sequence takes none: `ESC [` to its final byte, or `ESC` and the byte after it ... `columns` reads its sequences in a string; the library `Ansi` writes them." Rule 2's last sentence: "A published specification ... a protocol, is a library's and no module's vocabulary." Program: `Terminal.columns(Ansi.styled("ab", Bold))` is `2` only because `Terminal` knows ECMA-48's CSI. A reader of rule 2 predicts the stripping in `Ansi`. Fix: `columns` counts text alone and `Ansi.columns` strips its own sequences first; or rule 2 names the exception, the sequences the terminal's own module must skip to measure what the terminal shows.

**P58. `Float.toString` is called a primitive and is an adapter.** E.9: "The primitives are `toString`, ..." The shim is `ern_float:to_string/1`, `ern`'s own Erlang over `float_to_list(F, [short])`, whose layout differs: the host writes `1.0e15`, E.9 writes `1000000000000000.0` (probe.ern confirms E.9's). Rule 1 allows the difference closed in the host's language "only where that Ernest measurably costs, with the numbers in the decisions log, or where Ernest cannot close it"; relaying a dozen characters is Ernest's to do. Fix: E.9 says the host's function is private beneath `toString`, as E.5 says of `sliced`, and either the log has the numbers or the layout is Ernest over it.

**P59. "closure" names what §3.11 calls captures' opposite.** mvp3.1 §1: "A definition's *closure* is the definition with everything it references, transitively." The reader of principle 1 knows SML and OCaml, where a closure is a function with its captured environment, and §3.11 speaks of "the captures of a lambda". Fix: "reach" or "dependencies" in the proposal and the glossary lines it plans.

**P60. The examples name functions Appendix E does not have.** mvp3.2 §3: `List.each(nodes, ...)`, `List.length(old)`, `List.each(old, ...)`. E.2 has `foreach` and `size`. Fix: the names; the proposal's examples compile before the plan is written from them, as scratch/answer.md's did.

**P61. The end waits without bound and in silence.** mvp3.1 §5.8: "A subscriber that neither answers nor ends holds the program until a second termination, the interrupt, or the service manager's patience, which kills." Shape rule 8 makes a function that waits without a limit say so in its name; the runtime's own wait at `ern stop` has no name and no line. Fix: the node says on its standard error which subscriber it still waits for, once, after a time §8.6 states, as it says a peer was lost; or `ern stop --within ms`.

**P62. `dropLast` has no mirror.** E.0 rule 2's sequence vocabulary lists `take`, `drop`, `dropLast` and no `takeLast`; `dropLast(xs, n)` is `take(xs, size(xs) - n)` as `takeLast` would be `drop(xs, size(xs) - n)`. Program: `List.dropLast([1, 2, 3], 1)` is `[1, 2]`; `List.takeLast` is an unknown name. A reader who sees one predicts the other. Fix: both or neither; rule 4 says neither.

**P63. E.27 lists `Peer.spawn` with a function type, and it is no value.** §3.11: "`Peer.spawn` and `Peer.spawnMonitored` are called where they are named, and are not taken as values"; `let starter = Peer.spawn` is refused with "Peer.spawn is called where it is named, so that the compiler sees the function it starts" (value.ern). E.27's listing gives the two a type as it gives `Peer.find`, which is a value. Fix: a mark or a sentence in E.27's listing, "a form, not a value (§3.11)", so that the reader of the page is not surprised at the first fold over peers.

## Counts

Given as the brief's were, each with the reading used.

| What | 2026-10-08 | Now | With the proposals |
|---|---|---|---|
| taken top-level namespaces (`Prelude`, `Address`, and E.1 to E.27's 27) | 29 | 29 | 30, with `Code` |
| with Appendix G's | 35 (six) | 35 | 37, with `Code` and `Standing` |
| prelude functions (§9.4's 6, §9.5's 7, §9.6's 20) | 33 | 33 | 34, with `Os.terminating`, which §8.6 would name; 35 where §6.10 names `Code.running` |
| with `Peer`'s five | 38 | 38 | 39, or 40 |
| prelude types (§9.1's 10, §9.2's 3, §9.3's 8) | 21 | 21 | 21: `Code.Hash` is the module's by §9's test, as `Random.Seed` is |
| with `Peer.Key(m)` | 22 | 22 | 22 |
| primitives outside §9: the rule-named functions a module of Appendix E provides, `Io.show`, `Io.debug` and `Peer`'s five | 7 | 7 | 8, with `Os.terminating`; 9 with `Code.running` |
| Appendix E's listed functions | | 313 (E.1 counts 8; with `show` and `debug`, 315) | 318, with `Os.terminating` and `Code`'s three |
| Appendix E's listed types | | 25 | 26, with `Code.Hash` |
| Appendix G's listed functions and types | | 30 and 12 | 31 and 12, with `Standing.start` |
| primitives of E.0's sense, counted from each section's naming of them | | 155 | 159 |
| Appendix F's entries | | 152 | 159: hash, identity, closure, unit, code table, exchange, bare node |

Of principle 5's three counts, the language's, the proposals add no reserved word, no primitive of the language's and no concept of the language's; their seven concepts are the toolchain's and the runtime's, and one of them, P40's, would be the compiler's.

## E.0's rules: what each buys, what goes without it, and whether it admits the opposite

| Rule | Buys a program | Lost without it | Admits the opposite as written | Sentence proposed |
|---|---|---|---|---|
| Admission 1, the runtime's | The host's speed and tables; `String`, `Float`, `Fs`, `Map` exist at all | Everything over the host, or a slow Ernest copy of it | Not as a rule; but E.2 practises the opposite for five operations the host does exactly (P44), and E.9 calls an adapter a primitive (P58) | "Where a function of the host does exactly an operation's work on a value the language owns, the operation is a shim as on any other value: `List.reverse` is `lists:reverse/1`." |
| Admission 2, the vocabulary | A function is where the reader looks; one name per operation across six kinds | Ad hoc names, a map with `insert` and a set with `add` | Yes: `Map.update` and `mergeWith` are neither in nor out (P55); what `remove` takes is unsaid (P45); the sequence list has `dropLast` and not its mirror (P62) | "A map adds `keys`, `values`, `update`, `merge`, and `mergeWith`." and "`remove` takes what `get` takes." |
| Admission 3, the general operation | `Float.sqrt`, `Map.update`, `Float.pi` | Nothing beyond structure | Yes: any policy "stated whole" is admitted, so `round` to even and `round` away from zero are both in by the letter; E.13's generator is admitted by naming itself | "A numeric policy is the one §2.5 and §3.1 give the language's own literals and arithmetic, ties to even among them." |
| Admission 4, not a composition | A library a reader can hold whole | Nothing a program cannot write in a line | Yes: a composition of three calls is in by the letter (`average` over `foldLeft` and `size`), a conversion is exempt whatever it composes (`String.toInt` is `toIntBase(text, 10)`), and `Io.debug` is in by name | "A function whose body is calls of functions already here and the language's operators, with no case of its own, is a composition whatever its length; one with a case of its own, `Int.div`, `Os.run`, is not." |
| Shape 1, the order | `x \|> f(a)` reads; one order per function | Argument-order variants | Little room: `Clock.alarm(ms, wrap)` and `Fs.read(path, ms)` differ because an alarm's time is its subject, which the rule leaves to be inferred | "A time that is the operation's own subject, an alarm's, comes first; one that bounds a wait comes last (shape rule 8)." |
| Shape 2, the verbs | One verb per job; `put`, `remove`, `get` on every container | `add`, `insert`, `push`, `append` side by side | Yes for creation: `new` (Ets), `make` (Fs), `start` (Os, Balancer, Standing), `group` (Supervisor), `listen`, `connect`, `seed` are all admitted | "A function that starts a process of the module's and answers its address is `start`; one that makes an entry of the file system is `make`." |
| Shape 3, conversions | `toX`, `fromX` found by the other type's name | `parse`, `read`, `of`, `from` scattered | Yes: an encoding's placement is E.20's own sentence (P56) | "An encoding's two directions stand in the module of the type encoded." |
| Shape 4, `Optional`, `Either`, fault | Failure visible in the type | Faults for absent keys | Yes: §7.4 defers a fault to each section, so a section may fault where it could return; `Balancer.start([])` does, though its list may come from `Peer.peers()` | "A fault a section gives is for a misuse the text alone shows, never for a value the caller could not know before the call." |
| Shape 5, purity | The `with` mark means what it says; `Terminal.columns` and `Random.next` are pure | Every library function `with m` for safety | No; the proposal's `Code.running` without `+` is a slip (P52) | none |
| Shape 6, the page | A module read without the report | Pages that cite and do not state | No; P42 is a page that misstates, which the rule forbids | none |
| Shape 7, a type's name | `Seed`, `Key(m)`, `Table(k, v)`, not `RandomSeed` | Module names repeated in types | No; `Code.Hash` written in its own listing is a slip (P52) | none |
| Shape 8, waiting | Every wait bounded and visible; `None` for a call, `Left(Timeout)` for the rest | Hangs and ad hoc timeouts | Yes: `Left(Timeout)` of any error type (P43); a second meaning for `ms` (P53); the runtime's own unbounded wait (P61) | "`Timeout` is `Io.Error`'s; a function that answers it answers `Either(Io.Error, a)`." |
| Shape 9, no `Bool` choice | `render(doc, Plain)` reads at the call | `f(x, true)` | No | none |

Rules whose answer is little: none of the four admission rules, each of which bounds the library in a way the others do not. Of the shape rules, 7 and 9 buy little that 6 does not already, since a page that states its type's name and its argument's constructors makes both visible; they cost nothing and stay.

## Each module's admission

| Module | Admitted by | Buys | Lost without it | Verdict |
|---|---|---|---|---|
| E.1 `Io` | Rule 1, the system processes; §9.4 names `show`, `debug` | Output and input | The program cannot speak | Needed. `Io.debug` is admitted by name (rule 4), the one function that exists for the writer at the keyboard |
| E.2 `List` | Rules 1 and 2 | The language's own type's vocabulary | Every program writes its folds | Needed; P44, P45, P51, P62 |
| E.3 `Map`, E.4 `Set` | Rule 1, the runtime's representations | Dictionaries and sets at the host's speed | Lists of pairs | Needed; P55 |
| E.5 `String` | Rule 1, Unicode's tables | Graphemes, case, search | No text beyond bytes | Needed |
| E.6 `Char` | Rule 1, Unicode's tables | Categories and case | No lexer | Needed; `isAsciiDigit` exists for `String.toInt`'s digits and Markdown (P46); `digitValue` has no caller in stdlib or libs and exists for a program that reads a number by hand, which rule 3 admits |
| E.7 `Bool` | Rule 2, the type's operations | `not` as a value, `toString` | `if b then false else true` | Little, but the type's own two; stays |
| E.8 `Int`, E.9 `Float` | Rule 1, the host's arithmetic and library | Bits, powers, trigonometry | Nothing numeric | Needed; P50, P58 |
| E.10 `Optional`, E.11 `Either` | Rule 2, the sum-type vocabulary | `map`, `andThen`, `withDefault` as values beside `<-` and `match` | Nesting | Needed; `Either.fromOptional` exists for `<-` in a block of `Either` |
| E.12 `Foreign`, E.19 `Erl` | Rule 1 | The boundary for a library's shims | Appendix D cannot be written | Needed; `Erl` is one function (P49) |
| E.13 `Random` | Rule 3 by its own clause, "E.13's generator" | A seed that is a value and the same everywhere | `rand` behind a system process, or a library | Admitted by naming itself; a sentence that admits it by a property would be "a generator whose seed is a value enters, since the runtime's own is a process's state" |
| E.14 `Path` | Rule 1, the host's syntax | Segments, extensions, `under` | String surgery on paths | Needed |
| E.15 `Clock`, E.16 `Terminal`, E.17 `Fs`, E.18 `Tcp`, E.23 `Os` | Rule 1, the system processes | Time, keys, files, sockets, programs | Nothing effectful | Needed; P54, P57 |
| E.20 `Bytes` | Rules 1 and 2 | Octets with text's vocabulary | Bit syntax alone | Needed; P56 |
| E.21 `Process` | Rule 1; §6.5 and §6.9 name `fromAddress` | Identity, a snapshot, the fault stream | No monitor by address, no observability | Needed; `fromAddress` exists for `monitor`, which §6.9 says |
| E.22 `Supervisor` | Rule 1, four private primitives of the runtime's; §6.9 names it | OTP's restart strategies | A program cannot write it: `askRestart` is the runtime's alone | Needed where asked restarts are wanted; the proposal's refusal is a stated misuse |
| E.24 `Test` | §11.2 names it | `ern test` | No tests | Needed; one function, exists for the toolchain |
| E.25 `OrderedSet`, E.26 `OrderedMap` | §3.10's mention; no rule of E.0 (P48) | Order by `compare`, as data | `List.sort(Set.toList(s), compare)` | Stays by the mention; E.0 should decide the next one |
| E.27 `Peer` | Rule 1; §3.11, §6.7, §8.7 name five | Nodes at all | No distribution | Needed; P43, P63 |
| G.1 `Ets` | A library; rule 1's shape | Shared tables at the host's speed | A process per table | Right as a library; P40 would reach into it |
| G.2 `Markdown`, G.3 `Ansi`, G.6 `Json` | Libraries, by rule 2's last sentence | Three specifications | The shell and `ern doc` | Right as libraries; P47 |
| G.4 `Load` | A library over the host's measures | A balancer's measure | Nothing | Right as a library; P42 |
| G.5 `Balancer` | A library; pure Ernest | Placement in turn or by measure | Each program's own | Right as a library; `start([])`'s fault against shape rule 4's sentence above |
| Proposed `Os.terminating` | Rule 1, Os's process; §8.6 would name it | A service writes what it keeps before the end | No ordered stop | Admitted; P61 |
| Proposed `Standing` | A library | A client that survives its service's restart without a loop of its own | Every client's monitor-and-find loop | Right as a library; P53 |
| Proposed `Code` | Rule 1, the code table and the host's stacks; §6.10 would name `running` | `running`: §6.10's upgrade for every process on a function | `running`: an upgrade by hand per address | `running` admitted (P41 fixed); `load` and `hashes` exist for no caller yet (P52) |
| Proposed E.22 refusal | §7.4's shape, a misuse the text shows | One child function per process, said once | A child reading its outer child's cause | Admitted |

Functions that exist only for another: `Char.isAsciiDigit` (for `String.toInt`, said on its page), `Process.fromAddress` (for `monitor`, said in §6.9), `Either.fromOptional` (for `<-`), `Erl.atom` and all of `Foreign` (for a library's shims, which is their job), `Test.equal` (for `ern test`), `Io.debug` (for the writer, kept by name), and in the proposal `Code.load` and `Code.hashes` (for a caller not yet shown).

## The sentences proposed for E.0, gathered

1. Rule 1: "Where a function of the host does exactly an operation's work on a value the language owns, the operation is a shim as on any other value: `List.reverse` is `lists:reverse/1`."
2. Rule 2: "A map adds `keys`, `values`, `update`, `merge`, and `mergeWith`."
3. Rule 2 or shape rule 2: "`remove` takes what `get` takes, an index or a key."
4. Rule 2's last sentence, if `Terminal.columns` stays: "The terminal's own module skips the sequences it must to measure what the terminal shows, and names no other."
5. Rule 3: "A numeric policy is the one §2.5 and §3.1 give the language's own literals and arithmetic, ties to even among them."
6. Rule 4: "A function whose body is calls of functions already here and the language's operators, with no case of its own, is a composition whatever its length; one with a case of its own is not." And, if `Int.div` stays: "an operator that faults, with its `Optional` form" among the pairs.
7. A fifth sentence of the admission rules: "A type enters Appendix E where rule 1 makes it the runtime's, or where a rule of §3 to §9 names it; any other type, with its structure's vocabulary, is a library's."
8. Shape rule 1: "A time that is the operation's own subject, an alarm's, comes first."
9. Shape rule 2: "A function that starts a process of the module's and answers its address is `start`; one that makes an entry of the file system is `make`."
10. Shape rule 3: "An encoding's two directions stand in the module of the type encoded, `Bytes.toHex` and `Bytes.fromHex`."
11. Shape rule 4: "A fault a section gives is for a misuse the text alone shows, never for a value the caller could not know before the call."
12. Shape rule 8: "`Timeout` is `Io.Error`'s; a function that answers it answers `Either(Io.Error, a)`."

---

# Reader K: the cold reader

# Reader K: the cold reader

Read at commit d38d11c8: `report/language.md`, `report/toolchain.md`, `report/library.md`, then `docs/soundness.md`. The code was opened only to settle what a rule means (`stdlib/peer.ern`, `stdlib/fs.ern`, `erl/runtime/src/ern_peer.erl`, `ern_fs.erl`, `ern_io.erl`, `erl/cli/src/ern_cli.erl`), and probe programs were compiled with `bin/ern build` under `/tmp/claude-1001/-home-jocke-projects-ernest/19c47eed-8ea0-4c41-a53b-4a6b691355c5/readers/k/t/`. No node was started; the shell was run once in line mode, without `--config-dir`, to print types.

Defects first, most serious first. Matters of clarity alone are left out.

## Findings

**K1. E.27's `Refused(text)` is a failure no rule gives and the runtime never answers.**
`library.md`, Appendix E.27: `type Failure = NotListed | Unreachable | Refused(String) | Timeout | NotOffered | OtherType | NotLoaded`, and "`Refused(text)`, the peer refused what was sent, with its reason"; "a spawn [meets] `NotListed`, `Unreachable`, `Timeout`, `Refused` and `NotLoaded`". §8.7 **A spawn** lists every way a spawn's wait ends (answer, no connection, loss, time out, `NotLoaded`) and never a refusal; §8.7 **Connections** makes a refused connection `Unreachable`; a faulty frame ends the connection, which is a loss. `grep -rn "'Refused'" erl/` finds the constructor built only in `ern_io.erl:33` for `Io.Error`, never for `Peer.Failure`. So every `match` on a `Failure` must cover a case no program can meet (§5.9 coverage), and nothing says when it would. Fix: drop `Refused(String)` from `Failure` and the sentence that glosses it, or write in §8.7 the one thing a peer refuses and the text it sends.

**K2. §9.4, §9.5, §6.2 and §6.6 list the prelude's types without the marks §11.5 prescribes and §3.9 says §9 states.**
`language.md` §3.9: a restriction with no body to infer it from is "stated for the prelude's types and primitives in §9. Each prints with its mark (§11.5)". §11.5: "a process-only effect variable that occurs in no value position [is printed] `m+`: ... `send : (Address(a), a) -> Unit with m+`". §9.4 prints `send : (Address(a), a) -> Unit with m`, `spawn ... with m`; §9.5 `Address.call ... with n`, `answer ... with m`, `kill ... with m`, `restarting : (RestartLimit, () -> Unit with n) -> () -> Unit with n`; §9.4 `Io.debug : (a!) -> a! with m needs a.show` marks `!` and not `+` in one line. `printf ':type send\n:type restarting\n:type Io.debug\n:quit\n' | bin/ern shell` prints `send : (Address(a), a) -> Unit with m+`, `restarting : (RestartLimit, () -> Unit with n+) -> () -> Unit with n+`, `Io.debug : (a!) -> a! with m+ needs a.show`. Appendix E's listings carry the marks (`Io.print ... with m+`, `Supervisor.child : (Address(Msg), () -> Unit with m+) -> () -> Unit with m+`), so the report prints one primitive two ways. Fix: mark §9.4, §9.5, §6.2 and §6.6 as §11.5 prints them (`send`, `spawn`, `answer`, `Address.call`, `Address.callForever`, `kill` with `+`; `restarting` with `n+` at both occurrences; `Io.debug` with `m+`), and keep one copy: §6.2 and §6.6 restate §9.4 and §9.5 verbatim, which is where the drift lives.

**K3. Appendix A admits `C(..e)` with no field, which §5.6 forbids for an update and needs for a fill.**
`language.md` Appendix A: `Fields = ".." Expr [ "," UpdateSet { "," UpdateSet } ] | FieldSet { "," FieldSet }`. §5.6: "`Snapshot(..p, seen = s)`, a *record update*, takes the unlisted fields from `p`; at least one field follows `..`", and "a namespace may stand alone after `..`". Whether `..X` is an update or a fill is decided by what `X` names (§5.6), after parsing, so the grammar cannot carry the "at least one" rule, and by the authority rule the grammar wins: a conforming parser accepts `Snapshot(..p)`, and the report names no error for it. The compiler refuses it: `t/upd.ern` gives `a record update gives at least one field after its `..`` with a help line the report does not have. Fix: §5.6: "A record update with no field after `..` is a type error", placed with the other type errors of the paragraph, so the grammar stays as it is.

**K4. E.17 carries two paragraphs' worth of rules for operations it does not list.**
`library.md`, Appendix E.17: "The walk holds a bounded number of descriptors however deep the tree: it closes a directory as it enters one below it, and comes back through the lower one's `..`, which it checks, by device and inode, to be the directory it left. A directory moved while the walk is in it ends the walk with `Left(NotFound)`. It waits the milliseconds it is given once, for the whole removal." No function of E.17 walks a tree: `Fs.remove` is "a file, a link, or an empty directory", `stdlib/fs.ern` documents it so, and `ern_fs.erl:71` is `file:del_dir`. In the same section, "One that no other user may read is made in a directory only its owner may enter, whose mode `setMode` sets before the file is made" states what a program does, not what `Fs` does; it reads as the history file's rule of §11.2 left behind. A builder of a conforming `Fs` must guess which function walks and waits. Fix: delete the four sentences, or list the recursive removal they describe.

**K5. §8.7's "a peer whose module is of another version answers `NotLoaded`" is unreachable under §8.7's own handshake.**
`language.md` §8.7 **A spawn**: "at the version the function was compiled in, which the frame names with the module, so that a peer whose module is of another version answers `NotLoaded`". §8.7 **Connections**: the fingerprint is "the checksum of every compiled module on its load path", and "Two nodes connect only where their fingerprints are equal, which the handshake proves before anything passes". Two connected nodes therefore hold every module at one version; the one module a peer can lack is a shell's input module (§11.2), which is absent, not of another version. `ern_peer.erl:306` compares the function's module digest all the same. Fix: strike the version clause, leaving "where the peer has its module on its load path ... and every top-level `let` ... has its value there", or state that it guards against a peer that breaks §8.7, as §8.4's **What is checked** says of a faulty peer's message.

**K6. §11.2 runs a directory's modules each "in a runtime of its own" and all "one node"; §8.3 makes a node one runtime.**
`toolchain.md` §11.2: "Each module is run as `ern test file.erc` runs it, in a runtime of its own ... Under `--config-dir` the runs are one node, which keeps its connections between them." `language.md` §8.3: "A *node* is one running runtime"; Appendix F: "runtime — the system that runs Ernest programs"; "runner — what `ern run`, `ern test` and `ern shell` start: it starts the system processes and calls the entry point". Read with §8.3, one node of several runtimes is a contradiction; what `ern_cli.erl` does (`tree_tests`, `ern_rt:run_main` once per module inside one `as_node`) is the runner started afresh per module in one runtime. Fix: §11.2: "each with the runner started afresh" in place of "in a runtime of its own".

**K7. §3.9 leaves a type parameter that no field holds in no position, and E.27's `Key(m)` is one.**
`language.md` §3.9: "A value position is an argument, a result, a tuple component, or a type argument whose parameter occurs in a value position of its type's fields ... A variable that occurs only in effect positions ranges over the mailbox types and pure. A variable that also occurs in a value position ranges over types alone." `stdlib/peer.ern:65`: `export abstract type Key(m) = Key(name : String, text : String)`; E.27 lists `Peer.key : (String) -> Key(m)` and `Peer.offer : (Key(m), Address(m))`. In `Key(m)` the variable `m` occurs in no value position and no effect position, so neither sentence says what it ranges over, whether it may be pure, or how it prints. `t/phantom.ern`, a user type `type Tag(m) = Tag(name : String)` with `fn tag(name : String) : Tag(m)`, compiles with no word. Fix: §3.9: "A type argument whose parameter occurs in no field is a value position", which makes `Key(m)`'s `m` range over types alone, as `Address(m)`'s does.

**K8. §11.5 says the equality mark is written "on a foreign type's parameter alone"; §4.7 and §3.9 write it in a foreign function's parameters too.**
`toolchain.md` §11.5: "no mark can be written in one; `=` is written on a foreign type's parameter alone (§4.7)". `language.md` §4.7: "A type variable written with `=` in a parameter's type, `a=` in `foreign fn member(element : a=, list : List(a)) : Bool`"; §3.9: "written on a foreign type's parameter, `k=`, or on a type variable in a foreign function's parameters, `a=`, the one mark a program writes"; §3: `ListedType = typevar "=" | Type`. Fix: §11.5: "`=` is written in a foreign declaration alone, on a foreign type's parameter or in a foreign function's parameters (§4.7)".

**K9. §6.6 never names a `receive`'s `after` clause as a branch the reply check reads.**
`language.md` §6.6: "An `if`, `match`, `receive`, or block whose value is reply-carrying consumes it or hands it on in every branch", and the paragraph names `&&`, `||` and `<-` as branches, never `after`. A reader who knows the rest of Ernest can argue either way: the `after` clause runs no clause body, so it binds no obligation, but an obligation open before the `receive` must be consumed on it or not. `t/afterobl.ern` (a `reply` answered in a clause and dropped in `after 10 -> Unit`) is refused: "the reply-carrying value reply is not consumed on this path". Fix: §6.6: "... in every branch, a `receive`'s `after` clause among them".

**K10. §4.2's taken namespaces are "every type that has a member in §9, as `Int` and `Address` do"; `Address` has no member.**
`language.md` §4.2 **Taken namespaces**: "The prelude's namespaces are `Prelude` and the name of every type that has a member in §9, as `Int` and `Address` do". §4.5: a member is "an operator of §2.6, `compare` (§3.10), and `negate` (§5.1)"; `Address.call` and `Address.callForever` are §9.5's functions in the `Address` namespace and no member, as `Process`'s functions of E.21 are none. A builder reading "member" as §4.5 defines it frees `address.ern`, which the next sentence forbids. Fix: "the name of every type whose namespace §9 fills, as `Int` and `Address`".

**K11. §2.4 names `needs` and `derives` as the words read by position and no others; Appendix A reads three more.**
`language.md` §2.4: "`needs` and `derives` are words of Appendix A read by position, as a bitstring's specifiers are (§5.11), and identifiers everywhere else". Appendix A: `Member = typevar "." ( userop | "compare" | "negate" | "show" )`, `DeclName = ident | typename "." ( userop | "compare" | "negate" )`, `TypeDecl ... [ "derives" "compare" ]`. Whether `fn show(x)` or `let compare = ...` is legal is decided by Appendix A (they are `ident`s) and must be guessed from §2.4. Fix: §2.4: "`needs`, `derives`, and `compare`, `negate` and `show` after a dot in a member's name or a requirement, are words of Appendix A read by position".

**K12. §4.9 does not say what `a.show` is in a body.**
`language.md` §4.9: "The member is written `a.member` where `a` is a type variable of the signature of a declaration with a requirement", and "`show`, which is no member but `Io.show` and `Io.debug`". Appendix A parses `a.show` as a selection on the name `a`, which such a declaration cannot bind. The compiler refuses `t/showvar.ern` with `unknown name a` and a help that names `a.compare`. Fix: §4.9: "`a.show` names nothing in a body: under `needs a.show` the value is written with `Io.show`."

**K13. `Io.Error`'s `Refused` is answered by no function the report names.**
`library.md` E.1 glosses `NotATerminal`, `NotAFile`, `Exists`, `NotUtf8`, `Invalid` and `Other` and not `Refused`; E.18 says of `connect` only that it takes `host, port` and that a timed-out connect "has taken nothing". `ern_io.erl:33` maps `econnrefused` to it. Fix: E.18, at `Tcp.connect`: "`Left(Refused)` where the far end refuses the connection".

**K14. §8.7 gives a carrier that cannot start no cause text, where §7.4 gives every other fault its text.**
`language.md` §8.7 **Its start and its end**: "an initializer that faults ends the node as it ends a program, and so does a carrier that cannot start, its port taken among the reasons, the cause naming the host's reason". §7.4 lists each cause with its text and has none for this; §8.5 says how an initializer's fault is reported and nothing says how this one is. Fix: §7.4: "A node whose carrier cannot start ends before `main` runs with `Fault("the node cannot listen: r")`, `r` the host's reason" (or the text the runtime writes), and §8.7 points at it.

**K15. §8.7 ends a process by a way §6.9 does not list.**
`language.md` §8.7 **A spawn**: "Where the time runs out ... the process may have started: where the connection lasts, it is ended as soon as its answer arrives". §6.9: "A process dies when its function returns, when `kill` is called on it, on a fault (§7.3), or when the program ends (§8.6). Its `Reason` (§9.3) says which". A process the peer started for a spawn that timed out dies by none of the four as the program wrote them, and its `Reason`, which a monitor made from its own `self()` or a `Down` the peer's fault report carries would show, is a guess (`Killed`, as `{ern, killed}` in §8.4 suggests). Fix: §8.7: "it is killed as soon as its answer arrives (§6.9)".

**K16. E.27 restates §3.11's spawnable functions and drops one of the three.**
`library.md` E.27: "`f` is a function's name or a lambda written in the same definition". `language.md` §3.11: "the name of a top-level `fn` or `foreign fn` declaration, which captures nothing; a lambda written in the same definition, at the spawn or bound by a `let` whose name the spawn writes; or a `fn` declared in the same definition, whose captures are checked as a lambda's". A reader of E.27 alone refuses a local `fn` and accepts a parameter's name. Fix: E.27 names §3.11 and restates nothing, as the owner rule has it.

**K17. Shape rule 2's exceptions for text are stated in E.0 and are wrong for `Bytes`.**
`library.md` E.0 shape rule 2: "`contains` on text finds a substring of any length, not an element, the empty text being in every text, and `size` on text counts graphemes, not the `Char`s `toList` gives (E.5)". E.20: `Bytes.contains : (Bytes, Bytes) -> Bool // an empty second is always there`, a run of octets, not an element, which the shape rule's text-only exception does not admit. Fix: the restatement below; E.5 and E.20 each keep their unit.

**K18. E.20 states a shape rule that shape rule 3 lacks.**
`library.md` E.20: "`toHex` and `fromHex` are one encoding, Bytes written as text, whose two directions stand in the module of what is encoded, as `String.toUtf8` and `String.fromUtf8` stand in `String`'s." Shape rule 3 admits `fromX` only "between a type and one its module builds on"; `Bytes` builds on no `String`, so `Bytes.fromHex` is admitted by a sentence in E.20 and by nothing in E.0, where every other shape is decided. Fix: the restatement below.

**K19. §3.11 refuses `Peer.spawn` as a value and gives no error, where §0 asks for one.**
`language.md` §3.11: "`Peer.spawn` and `Peer.spawnMonitored` are called where they are named, and are not taken as values." §0 principle 3: "Where a check refuses a program that would run, the rule is stated and its error names what to write." The report states the rule and no error; `t/peerval2.ern` gets `Peer.spawn is called where it is named, so that the compiler sees the function it starts` with a help line, which the report does not own. A pipe-filled call, `"store" |> Peer.spawn(work, 1000)` (`t/pipespawn.ern`), is accepted, which §5.7 ("A call is filled") lets a reader predict, so that case needs no word. Fix: give the error's text in §3.11 or §11.5.

**K20. §7.4's "A refused request faults the process that made it" names a kind of failure defined nowhere.**
`language.md` §7.4: "A refused request faults the process that made it; a failure no request stands behind ... faults the entry process". No section defines a refused request; the sentence reads as the rule behind the terminal's two faults of §8.2 and `Peer.offer`'s, but a builder cannot tell which other faults it makes. Fix: "A request a system process refuses, §8.2's terminal claims and §8.7's offer among them, faults the process that made it".

**The argument (`docs/soundness.md`), where a step does not follow from the rules it cites.**

**K21. Section 5, "Messages the runtime delivers": "A `monitor`, a `spawnMonitored`, an alarm, a subscription and a socket each take a function from what they deliver to the caller's mailbox type (Appendix E.0 shape rule 8)."** A socket (E.18) takes no wrap: `Tcp.read`, `Tcp.accept` and the rest are calls, and their answers reach the caller by the (call) and (answer) steps and §6.6's private identifier, not through the mailbox. I1 holds for sockets, by another step than the one cited. Fix: strike "and a socket", or say a socket answers calls.

**K22. Section 2: "An address of the program's comes back from foreign code only as the proxy it crossed behind: ... at any other the proxy checks what is sent through it against that type."** The report has no proxy. §8.4 says: "An address of the program's that foreign code gives back is the program's own at the type it crossed at, and foreign at any other. What is sent to it at another type is checked as a message foreign code sends." That rule gives the step; the proxy is the code's way of keeping it. Fix: cite §8.4's sentence and drop the mechanism.

**K23. Section 7: "the note a callee's node keeps holds the reply only to end the call, as the caller's monitor does on one node, and is counted with the caller."** I3 as section 4 states it: an unanswered `r` "occurs at most once in the configuration: in one process's expression, counted through the closures it holds, or in one message". §8.7 **Calls** has the callee's node keep "a note that this caller waits, with its reply"; §6.6 has the caller's node watch the callee. Both are a second occurrence of `r` the configuration of section 3 has no place for, and "counted with the caller" is asserted, not shown. Fix: widen I3 and the configuration: "or in the runtime's record of the call that made it, on the caller's node (§6.6) and, across nodes, in the note on the callee's (§8.7), which answers nothing", then the sentence follows.

**K24. Section 6.4: "a wrap `(Down) -> Never` cannot return a message".** It follows and hides the step beside it: such a wrap is written, `fn(d) = fault("the service died")`, and `spawnMonitored(f, fn(d) = fault(...))` or `monitor` in an initializer is accepted at `Never`. When the process dies, after `main` has begun, the runtime applies the wrap to deliver to the entry process and the wrap faults; §6.9 makes that "the fault of the process it delivers to", so `main` faults. The conclusion "Nothing therefore reaches the entry process's mailbox before `main` runs" stands; the one act an initializer has on `main`'s process after `main` starts is left unsaid, and 6.4 is where a reader looks for it. Fix: add the sentence.

**K25. Section 6.8 and §3.9: "a foreign function that returns at such a variable faults at the boundary (§8.4)".** It follows for a result that is the bare variable, which §8.4's `cast` shows, and §8.4's next sentence weakens it for a result that holds the variable: "a foreign function whose result is `List(a)` and empty ... returns". A function `fn first() : a = match empty() { x :: _ -> x | [] -> first() }`, with `foreign fn empty() : List(a)`, returns no value and 6.8's claim holds, but by non-termination, not by the boundary. The step is sound; the citation names the wrong half of §8.4. Fix: "faults at the boundary or returns no value of it (§8.4, **Type variables**)".

## Appendix E.0, the rules restated

Each rule below holds a list inside it; the list is a rule stated at the level of its cases. The restatement is one rule from which the cases follow, and names the one exception the report must keep where there is one.

**Admission rule 1, "it reaches a representation the runtime owns, a table of the host's, its path syntax, Unicode's tables or the floating-point library's, or a process of the runtime's (§8.2, E.21, E.22), or a function of the host does its work".**
Restated: "Its value is the host's: the operation reads or writes what the host owns, or is work a host function does exactly." A representation, a table, a syntax, a process of the runtime's are what the host owns; the list becomes examples and E.22, whose supervisor is Ernest, leaves it. Nothing to keep.

**Admission rule 3, "A policy the program passes as an argument without a default is not buried ... A choice the section states whole and a program could make otherwise, E.13's generator, is not buried, and neither is a text form the language's own literals read back."**
Restated: "No policy is buried in it: a choice its result depends on is an argument, or its section states it whole so that a program can make another." Ernest has no default argument (§5.2), so "without a default" falls out; the generator and `Float.toString`'s form are both a choice the section states whole. Nothing to keep.

**Admission rule 4, "A function outside rule 2's vocabulary, shape rule 2's operations, and shape rule 3's conversions that is one call ... A pair is admitted whole as the vocabulary is: a predicate of a two-constructor type with the other constructor's, `isSome` and `isNone`, `isLeft` and `isRight`, a print with its line form, `print` and `println`, `printError` and `printlnError`, and a text operation with its bytes form, `print` and `write`, `readLine` and `read`. `Io.debug` is kept alone."**
Restated, rule 4: "It is not a composition: a function that rules 2 and 3 do not name, and that is one call of a function already here or a pipe of two, is not added." The pairs move to rule 2, where the vocabulary lives: "A predicate over a type of two constructors comes with the other constructor's; an operation on a stream of text comes with its line form and its bytes form." `isSome`/`isNone`, `isLeft`/`isRight`, `print`/`println`/`write`, `printError`/`printlnError`/`writeError`, `readLine`/`read` then fall out. `Io.debug` needs no sentence: it is no stream operation, so no pair is owed it. Nothing to keep.

**Shape rule 2, "`contains` on text finds a substring of any length, not an element, the empty text being in every text, and `size` on text counts graphemes, not the `Char`s `toList` gives (E.5)".**
Restated: "On a container read through `toList` (admission rule 2), `contains` takes a run of the container's own type and finds it anywhere, the empty run being in every container, and `size` counts the units its section names." E.5 then says graphemes and E.20 octets, and `Bytes.contains` is admitted by the rule and not against it. Nothing to keep.

**Shape rule 3, "Between a type and one its module builds on, both directions are the building module's, `fromX` and `toX`: `String.fromList` and `String.toList`, `Map.fromList`, `Either.fromOptional`", with E.20's "one encoding ... whose two directions stand in the module of what is encoded".**
Restated: "A conversion is named by the other type and exists once. Where one type is built from the other, or is the other's encoding as text, both directions are that type's module's, `fromX` and `toX`; every other conversion is its argument's module's `toX`." `Either(e, a)` is built from `Optional(a)` and an `e`, `String` from `List(Char)`, `Map` from a list of pairs, and UTF-8 and hexadecimal are encodings, so `String.fromUtf8` and `Bytes.fromHex` fall out and E.20's sentence goes. Nothing to keep.

**Shape rule 5, "a function that reaches a system reference of §8.2, spawns a process, as `Supervisor.group` does, asks the runtime about its processes (E.21), or reads the time, as `Clock.monotonic` does without a message, carries `with m`, and nothing else does".**
Restated: "A function is pure where its result depends on its arguments alone and it changes nothing (§0, §4.7). One that reads or changes what is outside its arguments while it runs, a mailbox, the runtime's records, the host's clock, a table of the host's, the node's peers, carries `with m`." The four cases fall out, and so do G.1's reads of a table (`Ets.get ... with m+`), `Peer.peers`, G.4's `Load.runQueue`, which the list as written does not admit; `Os.environment` stays pure, since it reads a value bound when the program starts (E.23), as `Terminal.columns`, `Io.show` and `Process.fromAddress` stay pure. Nothing to keep; rule 5 then holds in a library too, which the sentence before the shape rules now excepts it from.

**Shape rule 8, "A function that waits on what another party holds, a file, a socket, a peer, or a program the runtime started, takes the milliseconds ... One that waits on a stream of the program's own, standard input, standard output, standard error and the terminal, waits without a limit, and the stream's failure ends the program (§8.2). One answered from what the runtime holds answers at once."**
Restated: "A function that waits takes the milliseconds as its last argument, after any callback, which bound that one request, and answers `Left(Timeout)` when they pass, unless the wait's failure ends the program (§8.2), or the runtime holds the answer, in which case it takes none." Files, sockets, peers and programs are what the first clause covers; standard input, standard output, standard error and the terminal are what §8.2 ends the program for; `Tcp.port`, `Terminal.size` and `Os.closeInput` are answered from what the runtime holds. The exception to keep: "`Address.callForever` waits on another party without a limit and says so in its name", the one function the rule admits against itself.

## What "consistent" means in this report

The word is not in the report, nor in `docs/soundness.md` (`grep -i consisten report/ docs/soundness.md` finds nothing). What stands for it is said in three places, each a different thing:

1. **§0 principle 1** gives the only test: "A design surprises when a reader who knows the rest of Ernest would predict different code from the same requirement." Consistency here is a reader's prediction of code, not the agreement of two rules; a rule that contradicts another is a defect only where it makes a reader write the wrong program.
2. **§0 principle 2**, "One way, one job ... no two concepts that overlap", is consistency as the absence of a second spelling, which is what Appendix E.0's admission rule 4 and shape rule 2 ("One verb per operation") enforce for the library.
3. **§3.11, §8.7 and §10**: "every node runs one build", "known at both ends and the same at both", "the handshake proves before anything passes". Across nodes consistency means one build, and it is the one place the report has it checked rather than promised.

Where it is assumed and not said:

- **The three files.** Each opens with "The three files are one report, and each is normative." That asserts they agree; nothing in the report says what holds where two sections disagree. The authority ordering, Appendix A over the prose and §0 over an ambiguity, is in `CLAUDE.md`, outside the report, so a reader who has the report alone resolves K3 by guessing.
- **The listings and the compiler.** Appendix E opens with "A listing gives each function's type as §11.5 prints it", and §3.9 says the prelude's restrictions are "stated ... in §9" and "Each prints with its mark (§11.5)". That the listing and what `ern` prints are one is assumed; Appendix E is held to it by `ern doc`'s test, §9 by nothing, and §9 drifted (K2). The same signatures are written twice more, in §6.2 and §6.6, which is restating by the report's own standard (`CLAUDE.md`, *Restating*); where one copy is held and the others are not, the copies are where inconsistency enters.
- **Appendix F.** "the section is normative" assumes each gloss says what its section says; F's "member" and §4.2's "member" (K10) show the glossary and a section drifting apart under one word.
- **A section and its restatement in another.** E.27 restates §3.11 (K16) and §6.2 restates §9.4; the report trusts the two to agree and has no test that they do.
- **An order's laws.** §3.10 says of a program's `compare` that "the laws are the program's promise, and nothing checks them", and E.25 says what breaks when they fail; this is the one place the report says plainly that a consistency it relies on is assumed.
- **The argument.** `docs/soundness.md` states its claims over "the rules of `report/language.md` in its revision of 9 October 2026" and argues from them; that the rules it cites are themselves consistent it takes as given, and K21 to K25 are where a cited rule and the step drawn from it part.

So "consistent" in this report means, where it means anything stated: a reader who knows Ernest predicts the code (§0.1), there is one way to write it (§0.2), and every node runs one build (§8.7). Agreement between two of the report's own sentences is nowhere stated as a requirement; it is assumed by the opening line of each file and kept, where it is kept, by tests outside the report.

---

# Reader W: where the guide works hard

# Reader W: the guide read against the report

Repository at d38d11c8. Read: `guide/language.md` whole, and `report/language.md`, `report/toolchain.md`, `report/library.md` whole. Two programs were run under `readers/w/` to settle two facts (W8, W23). Line numbers are the guide's.

Each item gives the place (section, line, quote), the rule of the report that made the sentence or the shape necessary, and what the guide would say if the rule were otherwise. Most serious first. Where several sentences of the guide serve one rule they are one item.

## Findings

**W1. The `Down` of a worker and its last message race, and the guide teaches the race four times.**
Place: §5.2 l.1246–1292, "the worker's last message may arrive after its `Down`", the `waitFor` loop with a clause for `Returned`, a clause for any other reason, and a sweep clause `_ -> waitFor(child)`; §6.4 l.1622–1631, `outcome()` with a nested `receive` and a three-line comment explaining it; §5.6 l.1471 `Died(_) -> collect(totals, left)` and l.1483 "whichever of the two arrives first"; exercise §5.7(b) l.1489 and its answer l.2730, "A run seldom shows the second line, but the order is not promised, so the clause stays." Also l.1292 "Where the result is the worker's answer to a call, no such care is needed."
Rule: §6.9 "A `Down` comes from the runtime and has no order with the messages the ended process sent (§6.4). The answer to a call (§6.6) is not overtaken by the callee's `Down`."
Otherwise: were a `Down` delivered after every message its process sent to the same receiver (as Erlang orders an exit signal behind the dying process's messages), `waitFor` would be two clauses, `outcome` one `receive`, §5.6's third clause would go, exercise 5.7(b) would have one answer, and l.1292 would not need to say that a call is safe where a send is not. As it stands a result by message and a result by call have two ordering guarantees, and the guide must teach which is which.

**W2. Code written once over several representations is taught four ways, and the parts of the rule that make it four are each explained.**
Place: §7.3 l.1927–2191, the table at l.1931 ("A requirement", "an operations record", "a record of closures"), l.2191 "A service with state needs none of the three", the FAQ l.2712, exercise §7.4(b).
Rule: §4.9, a requirement "names `compare`, `negate`, an operator of §2.6, or `show`... and nothing else"; §4.9's operations record paragraph; E.0 rule 4 "An operations record and a function over one are the program's: no module declares one."
Otherwise: if a requirement could name any function of a type's module, l.2090 ("`fromList` and `intersection` are a module's functions, not members, so an algorithm... takes them another way") and the 60 lines of `common.ern` would go, and the record of closures would be taught as the ordinary closure it is. Four sentences inside the section are rationale for sub-rules:
- l.1994 "A requirement is always written: the compiler infers none", l.1972, and l.2231 (every helper in `ordered_set.ern` redeclares `needs a.compare`), against l.447 "An annotation does not write the mark; the compiler infers it from the body" for `=`. Rule: §4.9 "A requirement is never inferred" beside §3.9/§11.5, where the three restrictions are inferred and cannot be written. Two opposite conventions for two things a reader sees as one kind; were both inferred, the rejected `largestOf` (l.1974–1992) and the `needs` on `firstOfEach` and `has` would go.
- l.2027 "`show` is no member a type declares: every type can be shown... so the function declares `needs a.show`". Rule: E.1/§9.4 `Io.show : (a!) -> String needs a.show`. Were `Io.show` the runtime's representation printer (Erlang's `~p`), `shown` would need no requirement; the rule exists so that an abstract type prints `<abstract>` and a `Set` as `Set.fromList`.
- l.2065–2088 "An order belongs to a type, since a type has one `compare`. A second order on `Int` is a second type", with the rejected `Descending` program. Rule: §3.10 (one `compare` per type), E.25 "An order belongs to an element type". Were an ordered set given its order as a value, `type Descending = Descending(Int)` and its `fn Descending.compare` would go, and so would the warning that two sets "cannot meet".
- l.1970 "`List.sort` takes its order as a parameter, since a sort may be given any order; a function declares a requirement where the type's own member is meant." Rule: E.0 shape rule 1. Two ways to pass an order, and the guide says when each.

**W3. The reply discipline forces five shapes the guide must teach around.**
Place and rule, each §6.6:
(a) l.874 "A reply is not consumed in a part that may be skipped. It is consumed before that part or after it, or the `<-` is written as a `match`." Rule: "what follows a `let p <- e` in its block is a branch a `Left` or a `None` skips... which is written as a `match`". The language's own failure-chaining form (§5.5, admitted under principle 2) is unavailable in exactly the request handlers that hold replies. Were `<-` admitted with an open reply, the guide would teach one way to chain a failure.
(b) l.863 "Neither can a `Map` or a `Set`, whose operations are the runtime's", and §4.4 l.920 `waiting : List(Reply(Int))`, l.911 "in a list as well as anywhere else a value waits". Rule: E.3/E.4, every `k` and `v` marked `!`. A server that answers by request id scans a list; a reader of the report predicts a map keyed by id. Were the runtime's map known not to copy or drop a value, the list would be a `Map`.
(c) l.866 "No field is selected from one, since the selection would drop the other fields. One is not the base of a record update, since the update would drop the field it replaces. A pattern takes such a value apart." Rule: "Anywhere else it is a type error: ... as the value a field is selected from, and as the base of a record update". A `Top(limit = limit, reply = reply)` is always taken apart by pattern; `request.text` is refused. The two "since" clauses are rationale.
(d) l.958 "`main` cannot wait in the call itself, since it is `main` that puts the item. A process of its own makes the call and sends the answer on as `Took(item)`", and the shape `let _ = spawn(fn() = send(me, Took(take(queue))))` at l.941. Rule: "A call's reply travels by an identifier private to the call, never through the caller's mailbox." A process that must keep receiving while it asks spawns a helper to ask for it. The guide's own §5.2 and §5.6 answer the same need the other way, a worker sending `Result`/`Counted` to the parent's address, so an answer is taught two ways: a checked `Reply` that blocks, and an unchecked address that races (W1). Were a request able to carry `via(self(), Took)` as its reply, the helper would go.
(e) l.872 "A path that faults inside a function whose type says it returns, or waits for ever, is still written with its answer: the compiler reads the type, not the run", with `fn die(cause : String) : a = fault(cause)`. Rule: "A call to a function whose result type is a type variable that neither a parameter's type nor its mailbox type names consumes every obligation open on its path". The guide must teach that `fault` is special only by its type.

**W4. Every wait on another party takes a time, and nothing delivers what a read answers, so the guide teaches retry loops, a sleep idiom, and a reader process twice.**
Place: §2.9 l.589 "There is no time that means no limit. A server that waits for as long as it takes asks again on each `Left(Timeout)`"; l.589 "A read of standard input and a write to standard output wait without a limit, since those streams are the program's own. A socket's far end or a program the runtime started can hang unseen, so `Tcp.write`, `Os.read` and `Os.write` take a time too"; l.590 "A process that only waits a while writes `receive { after ms -> Unit }`; `Clock` has no sleep"; §5.5 l.1360 "**What does not deliver.** `Io.readLine`, `Os.read` and `Tcp.read` put nothing in your mailbox... gives the reading to a process of its own" and the `reader`/`chat` program l.1362–1392; §8.7 l.2534 "`accept` has no form without a time, so the loop that accepts takes again after a timeout", l.2536 "A process waits on one thing at a time, so one that must wait on its socket and on its mailbox gives the socket to a reader of its own", and the clauses `Left(Io.Timeout) -> serve(listener)` l.2556 and `Left(Io.Timeout) -> reader(socket, recipient)` l.2576, which exist only to re-enter.
Rule: E.0 shape rule 8 (milliseconds last, `Left(Timeout)`, "One that waits without a limit on another party says so in its name"); E.18 (a socket is read by a call, "There are no options"); E.15 (no sleep).
Otherwise: had `accept` and `read` a form without a time beside the timed one, as `Address.callForever` stands beside `Address.call`, the two retry clauses and l.2534 would go; could a socket deliver to a mailbox as `Terminal.subscribe` delivers keys, the reader process and its `via` would go in both programs, and l.1360 would not have to list which functions deliver and which are pulled. The guide itself shows the asymmetry: keys are delivered (l.259, l.1347), lines are pulled (l.1360).

**W5. An alarm fires once and cannot be cancelled, so a game loop is two functions and every loop must drop stale alarms.**
Place: §5.5 l.1407 "`Clock.alarm` fires once. A periodic tick is scheduled again after each tick is handled, and only then: a loop that scheduled one on every message would add a timer per key pressed. Two functions keep the two apart", the `game`/`waitForTick` split l.1409–1427; l.1431 "An alarm cannot be cancelled. A process that no longer wants one takes its message when it comes and drops it, since even a cancel could not take back a message already delivered. A deadline... carries the work's id... the loop that waits matches every `Expired`... a message that no `receive` takes stays in the mailbox for as long as the process lives."
Rule: E.15 "An alarm fires once, and a program cannot cancel it: a process that no longer wants it ignores the message, and a periodic tick is scheduled after the previous one is handled."
Otherwise: with a cancel or a periodic alarm (both of which the Erlang reader predicts, `erlang:cancel_timer`, `timer:send_interval`), the two-function shape, the id-in-message idiom, the stale-`Expired` clause in every `receive`, and the warning about a mailbox that fills would go. The "since even a cancel could not take back a message already delivered" is a design argument in a teaching text.

**W6. A spawn on a peer takes a function that is not a value, resolves its free names two ways, and runs only where the peer has run initializers, and the guide explains each.**
Place: §8.1 l.2314 "The spawn takes with it the values the lambda captured, `me` here, and nothing more... a top-level binding it names is the peer's, so a service binding names the peer's service; `me` still names this process"; l.2316 "The compiler must see what the function captures, so the function a spawn on a peer starts is written where the spawn can see it... A function that came as a value, a parameter or a message, is refused"; l.2316 "So the work a peer runs is written in a module the peer's program depends on too, or in one that, with every module it depends on, has no top-level `let` the peer's program has not run", repeated word for word in the §8.8 answer l.2736; l.2276 "on `foo` a program `idle.erc` beside it whose `main` waits for a message that never comes"; §8.4 l.2398–2400.
Rule: §3.11 "The function a spawn on a peer starts is the name of a top-level `fn`..., a lambda written in the same definition..., or a `fn` declared in the same definition... Any other expression is refused... since its captures are not in its type. `Peer.spawn` and `Peer.spawnMonitored` are called where they are named, and are not taken as values"; §8.7 "In the spawned function a top-level `let` and a declaration's name are the peer's, a value it captured is the spawner's"; §8.7 "`NotLoaded`... nothing is initialized because a peer asked"; §11.2 "a node without one arrives in MVP 3.1".
Otherwise: were a function type to carry what its value captured, `Peer.spawn` would take any `f : () -> Unit with m` as its type E.27 writes already promises, and the sentence beginning "The compiler must see" would go. Were top-level names resolved as a closure resolves them, the warning at l.2314 would go but a service binding would have to cross. Did a peer initialize a module on a spawn's demand, the two sentences on where the work is written would go. Could a node start without a program, `idle.erc` would go. The guide handles the fingerprint silently ("run from one directory", l.2276): a reader would not predict that two different programs must share a directory for their nodes to connect (§8.7, the checksum of every compiled module on the load path).

**W7. An open mailbox type has three defaults, so the guide needs a transcript, and `: Unit` means pure, so every `main` writes `with Never`.**
Place: §4.1 l.817–831, "**A process that receives nothing.**... **When nothing settles the mailbox.**... In a block that does no harm... A top-level `let`, and one at the prompt, must have its type settled", with the shell transcript `<address 84> : Address(a)` and "`it` is unchanged"; §8.1 l.2316 "A process spawned so that never receives needs no annotation: where nothing else names the mailbox type of the address the spawn answers, it is `Never`"; §1.1 l.163–165; §1.4 l.261–277 and its answer l.2722 "Omitting an annotation is not the same as declaring purity"; §0 l.92 the `area` program; §3.3 l.720.
Rule: §8.1 (an entry point's open `m` is `Never`); §3.11 (a peer spawn's open mailbox is `Never`); §6.2 (a local spawn's `n` "is then what the context makes it"; "A process that never receives is spawned with `fn() : Unit with Never = ...`"); §4.6 and §11.2 (a top-level `let` and a prompt binding must be settled); §4.5 "The result annotation is omitted, or is `: T` for a pure function, or `: T with M`".
Otherwise: held one rule everywhere, an open mailbox of a spawned function is `Never`, §4.1's second paragraph would be one sentence and the transcript would go, and the guide would not teach that a peer spawn and a local spawn differ here. Left a result annotation without `with` to inference, hello-world would read `export fn main() : Unit =`, and §0's `area`, §1.4 and l.2722 would go; as it is, every `main` of the guide carries `with Never` that §8.1 does not require (§1.4(a) compiles), because the alternative spelling means something else.

**W8. `type Word = String` compiles and means another thing, which the guide must warn of.**
Place: §2.3 l.375 "There are no type aliases. `type Word = String` declares a type whose one value is a nullary constructor named `String`, and no other name for `String`;... the compiler's help says so where the two meet."
Rule: §3.1 "There are no type aliases"; §2.3 "`conname` and `typename` begin with an uppercase letter and are the same token"; Appendix A `Constructor = conname [...]`.
Verified: `type Word = String` alone builds with status 0; a `Word` meeting a `String` is refused with the help the guide names. A reader who knows SML or OCaml predicts an alias, and the report states the departure, but the departure is accepted silently at the declaration. Were a nullary constructor whose name is a type in scope refused at its declaration, or aliases admitted, the sentence would go.

**W9. Three marks in printed types, none of them writable but one, taught in five places.**
Place: §2.5 l.447 "In a printed type, a variable that needs equality is marked `=`... An annotation does not write the mark"; §2.9 l.594 "**Marks in a printed type.**"; §3.5 l.741 "**In a printed type.** A printed type marks a process-only effect variable with `+` where it stands only after `with`... Where the variable is also a callback's result type, as in `monitor`'s `(Down) -> m`, it is a type and so never pure, and is printed without the mark"; §4.2 l.868 "a variable marked `!`"; §8.3 l.2390 "The `=` in `k=` says the keys need equality... marks the variable the same way, once, in its parameters".
Rule: §11.5 "In a printed type a variable with the equality constraint is `a=`, one that is not reply-carrying `a!`, and a process-only effect variable that occurs in no value position `m+`... A printed type is not an annotation, and no mark can be written in one; `=` is written on a foreign type's parameter alone (§4.7)"; §3.9.
Otherwise: were the restrictions not shown, or shown and writable, the five passages would be one or none; as it is the guide must teach a notation the programmer reads and may not write, with one exception (`=` in a foreign declaration) and one irregularity (`+` printed on `send`'s `m` and not on `monitor`'s).

**W10. Operators and selectors resolve by the operand's type and nothing defaults, and a block `let` generalizes only a lambda.**
Place: §3.3 l.682 "But **Ernest does not infer a "numeric type" or default to `Int`**" with the rejected `twice`; l.697 "A field read is the same: `fn age(person) = person.age` is refused until `person : Person` says whose field it is"; l.699–718, the three rules of what is polymorphic and the rejected `one = List.take`.
Rule: §4.8 "there is no numeric type to generalize over... An operand type still undetermined then... is a type error"; §3.5 selection resolved as an operator's operand is; §3.9 "a `let` in a block that binds a name to a lambda" is generalized, "another `let` in a block is not".
Otherwise: a reader of SML predicts `+` defaults to `Int`; of OCaml, that `let one = List.take` is polymorphic, since the value restriction admits a variable. Resolved `+` to `Int.+` where nothing fixes it, or generalized a block `let` bound to a name as a lambda is, the two rejected programs and the bold warning would go.

**W11. Code replacement is demonstrated with code the program held from the start, and nothing else can bring new code to a running program but the shell.**
Place: §4.6 l.1046–1115, `countTwice` compiled in the same `counter.ern` as `count`; l.1048 "here one compiled into the program, in the shell one from a module that `:reload` compiled again, and on a peer one that a process spawned there brings, since a function does not cross nodes in a message"; §10 l.2691 "Only the shell's `:reload` loads a new version of a module."
Rule: §6.10 "The language has no other mechanism for code replacement. The shell's reload (§11.2)..."; §8.7 (every node runs one build, the fingerprint).
Otherwise: a reader of the report predicts a demonstration in which a new version reaches a running program; none can be written outside `ern shell`, since a peer with new code cannot connect and `ern reload` rereads `ernest.conf` only. Could `ern reload` load a module as the shell does, §4.6 would show a second build and l.2691 would go. The example's shape, both loops in one file and an `Upgrade` sent from the same `main`, is what no reader predicts under the name.

**W12. A constructor has one positional field or named ones, and only the single-positional one is a function.**
Place: §2.3 l.372 "several values without names are a tuple, `Point(#(Int, Int))`"; l.373 "**Named fields**... Not a function value"; §5.5 l.1347 "A constructor with one positional field is a function value, so `Clock.alarm(100, Tick)` delivers `Tick(t)`. A message that needs no value is made by a lambda that ignores it, `Clock.alarm(100, fn(_) = Refresh)`".
Rule: §3.5 "A constructor has no fields, exactly one positional field, or named fields"; §5.6 "A nullary constructor is a value. A single-positional constructor is a function value. A named constructor is neither".
Otherwise: a reader of SML predicts `Point(Int, Int)`; of Haskell, a record constructor that is a function. Every wrap constructor in the guide is single-positional (`Died(Down)`, `PongDone(Down)`, `Tick(Int)`, `Line(Optional(String))`) because a named one would need `fn(d) = Died(down = d)`, which the guide never shows. Admitted several positional fields, l.372's last sentence would go; made a nullary constructor a `() -> T` or a named one a function, l.1347's last sentence would go.

**W13. The pipe fills the first slot of the outermost call, and a lambda is not an operand.**
Place: §2.8 l.573 "A lambda is parenthesized, `x |> (fn(y) = y + 1)`, since its body would take in a `|>` after it (§3.2), and a function a call computes is applied in writing, `adder(3)(x)`."
Rule: §5.7 "In a chained call the pipe fills the outermost call: `x |> f(a)(b)` is `f(a)(x, b)`. A function a call computes is applied in writing"; "A lambda is no operand and must be parenthesized".
Otherwise: a reader of OCaml predicts `x |> adder(3)` is `adder(3)(x)`; here it is `adder(x, 3)`. Were `|>` application, both sentences would go, and `x |> f(a, b)` would need currying, which §5.2 refuses.

**W14. An address has no equality and `monitor` takes a `Process`, so `Process.fromAddress` is written six times and explained twice.**
Place: §5.2 l.1244 "`child` is a `Process`... watching a process needs no permission to send to it, so a server watches the clients it holds no address to"; §5.5 l.1394 "**One process behind them all.** Addresses have no equality, since an adapted address holds a function... An address is the authority to reach a process, which is why `kill` takes one; a `Process` is its identity"; §2.5 l.447 "a map keyed by addresses is a type error at its first operation; key it by the process behind each address instead"; the conversions at l.1255, 1260, 1400, 2553.
Rule: §3.10 "Addresses have no equality"; §6.5/E.21 `Process.fromAddress`; §6.9 "`monitor(p, wrap)`... `p` is a `Process`"; §9.5 `kill : (Address(a)) -> Unit`.
Otherwise: a reader of Erlang predicts one pid for sending, watching and comparing. Had an address identity equality on the process behind it and did `monitor` take an address, the paragraph at l.1394, the "since" at l.1244 and the six conversions would go. The guide's argument (authority against identity) is the design's own.

**W15. `via`: a "Why" paragraph, a fault that strikes the target though the function ran in the sender, and an order exception across nodes.**
Place: §5.5 l.1326 "**Why.** Whoever sends need not know the type of the mailbox it sends to"; l.1349 "A `send` to an adapted address applies the function in the sender... Either way, a fault in the function is the fault of the process the message is for, not of the one that sent it... so keep the function to shaping the value", with `halves` l.1351–1358; §6.3 l.1602; §8.2 l.2378 "**Order.**... a message to an adapted address made on another node is wrapped on that node, a step more, so a message sent straight after it to the target's own address can arrive first... A protocol that must keep the order sends both through the same address."
Rule: §6.5 "`f` is applied on the node where `via(addr, f)` was made: by the `send`, in the sender... A fault in `f` is the target's"; §6.5/§8.7 "one exception... a message sent straight after it can pass it".
Otherwise: a reader of Erlang predicts that code which crashes in the sender's process crashes the sender; the report states the departure and the guide must warn. Were a fault in `f` the sender's, the warning would be ordinary; did the function always run at the receiving end, the order exception and its workaround would go. A heading "Why" is the rationale the brief asks for by name.

**W16. Restart in place: what a restart keeps and loses, a sibling that never waits, and no graceful stop.**
Place: §6.5 l.1695 "The new run begins with an empty mailbox, and what the process asked the runtime for... is cancelled... What the loop held is gone... A restart is not an end: no `monitor` hears of it"; l.1697 "A caller that must outlive a service's faults calls with a limit"; §6.6 l.1752 "A sibling runs on until it next waits... A sibling that never waits is never restarted"; l.1754 "a call to a sibling may be answered from its old state, end, or be answered from its new one"; l.1760 "A killed process runs nothing more, so a child that must finish its work, a file to flush, is sent a message of its own protocol first."
Rule: §6.9 restarting ("Its mailbox is emptied... A restart is not a death, and no `monitor` is told of it"); E.22 ("It runs on until it next waits"); §6.9 "A monitor is the one link between processes; there is no other"; §6.6 (`callForever` faults with the callee's cause, `call` answers `None`).
Otherwise: were a restart a kill and a respawn (OTP), the bindings would lose their addresses and §6.5's service idiom would go; the five warnings exist because the address is kept. Had a process a hook at its end (`trap_exit`, `terminate/2`), l.1760's idiom would go. Two ways to call, with the guide saying which survives a callee's fault.

**W17. The program spawns the supervisor and each child itself, and recovery is taught three ways.**
Place: §6.6 l.1709–1714 `let group : Address(Supervisor.Msg) = spawn(Supervisor.group(...))`, `let visits = spawn(Supervisor.child(group, fn() = count(0)))`; l.1744 "The program spawns each itself, as it spawns the function `restarting` gives (§6.5), so the fault line names the child's binding"; §6.4 l.1648 "What must survive a fault lives in the process that does not fault... A long-lived process restarts in place instead, which §6.5 shows, and a group of them restarts together under... `Supervisor`, which §6.6 shows."
Rule: E.22 "The caller spawns the supervisor and each child: a child's site (§6.9) and its place are the caller's, and a service binding names it (§6.5)"; §6.9 `restarting`, `monitor`.
Otherwise: a reader of OTP predicts `Supervisor.start(children)`; the shape is explained at l.1744. Did the supervisor spawn its children, l.1744 would go and the fault line would name the supervisor. Recovery by a watcher, by `restarting`, and by `Supervisor` are three forms the guide must place against one another.

**W18. A service program that lives sixty seconds, and a peer that runs a dummy.**
Place: §8.2 l.2344–2349 `Peer.offer(Counter.key, counter); receive { after 60000 -> Unit }`; §8.1 l.2276 `idle.erc` "whose `main` waits for a message that never comes".
Rule: §6.8 "a `receive` with only an `after` clause is how a `Never` process waits"; Appendix A, a `receive` has a clause or an `after`; §8.6 "A program that is to keep running waits in `main`"; §11.2 "a node runs a program... a node without one arrives in MVP 3.1".
Otherwise: a `main : Unit with Never` cannot wait indefinitely except by looping on `after`, so the store's service expires after a minute, which the guide does not say and no reader predicts of a service example; and the peer needs a program invented for it. With an unbounded wait for a `Never` process, or a node that starts without a program, both shapes would go.

**W19. `let _ = e` and `else Unit` as recurring shapes.**
Place: §0 l.111, §2.2 l.325 (the form taught); `let _ = spawn(...)` at l.1061, 1190, 1585, 1616, 2408; `{ let _ = spawnMonitored(...); Unit }` l.1452–1455; `{ let _ = Tcp.write(...); Unit }` l.2584–2587, 2591; `if ... then send(producer, Credit(10)) else Unit;` l.986.
Rule: §5.4 "An expression that is not the last statement has type `Unit`; a value is discarded with `let _ = e`"; §6.2 `spawn` answers an address; §5.8 no `if` without `else`.
Otherwise: a fire-and-forget spawn and a write whose answer is not wanted each cost a `let _ =`, and a conditional statement an `else Unit`; the report's principle 3 chooses this. The guide teaches the form twice and writes it eleven times.

**W20. `Io.Error` has no text, and the guide says one thing and does another.**
Place: §2.9 l.582 "A program says an `Io.Error` to its user in its own words, with a `match` over its constructors; `Io.show` writes it as a value, `Other("address already in use")`"; `Io.show(error)` written to the user at l.229, 2266, 2363, 2411, 2546.
Rule: E.1 (no conversion of `Error` to text); E.0 rule 3 (a wording is a policy the library refuses).
Otherwise: a `toString` on `Io.Error` would end the sentence and the five calls would read as the guide advises. As it is, two ways are taught and the examples use the one set aside.

**W21. One sum type per block, bridged by `Either.fromOptional`.**
Place: §2.7 l.560 "A block is an `Optional` chain or an `Either` chain, never both"; the bridge at l.551 and §6.1 l.1503.
Rule: §5.5 "All `<-` bindings in one block resolve to the same sum type."
Otherwise: the bridge is taught in two sections because an `Optional` step cannot stand in an `Either` block without a reason being supplied, which is the rule's point; a reader meets the conversion before the chain.

**W22. The host's commonest convention needs Erlang written by hand.**
Place: §8.5 l.2452–2491 "Erlang's `{ok, V}` and `{error, R}` are not an Ernest `Either`... A small Erlang helper returns the Ernest shape", with `store_helper.erl` and `erlc -o build store_helper.erl`.
Rule: E.19 "An API that answers `{ok, V}` or `{error, R}` needs an Erlang helper that rewrites the answer"; E.12 (no reading of an atom but `==` on `Foreign.Term`).
Otherwise: a shim in `Erl` that rewrote `{ok, V} | {error, R}` to `Either` once, host-side, would end the helper and the `erlc` line; a reader of the report predicts that calling Erlang needs no Erlang.

**W23. The guide contradicts §4.2 on a module's own qualified name.**
Place: §7.1 l.1844 "`export fn parse(...)` declares `parse`, which the code outside reaches as `Net.Http.parse`, and the code inside by either name."
Rule: §4.2 "A use site may write a declaration's qualified name: elsewhere for an exported one, and within its own module only where a binding hides the declaration's plain name... the qualified form there is an error whose help names the plain one."
Verified: `Net.Http.parse(text)` inside `net/http.ern` is refused, `Net.Http.parse is written only where a binding hides parse`, help `nothing here hides it; write parse`. The sentence should read "and the code inside by its plain name". This is a wrong statement, not a rationale, and the only one found.

**W24. A `receive` guard is a second guard language, and the way around changes the program.**
Place: §4.3 l.894 "A guard in `receive` is narrower than one in `match`, since it chooses a message before taking it... and calls nothing (report §6.3). For more, receive the message and `match` it."
Rule: §6.3 guard expression; §5.9 a `match` guard is any pure `Bool` expression.
Otherwise: were a `receive` guard a pure expression as a `match` guard is, the paragraph would go. The way around taught removes the message from the mailbox, which a guard would not, so it is not the same program; the guide does not say so.

**W25. No partial application, so a lambda.**
Place: §3.1 l.648 "`hypotenuseSquared(3)` is a type error, not a partially applied function. To make a unary version, write a lambda."
Rule: §5.2 "a call never yields a partially applied function."
Otherwise: a reader of OCaml predicts currying; the sentence and its workaround exist for that reader.

**W26. Bitstrings: no host order, and a catch-all clause always.**
Place: §8.6 l.2519 "A format states its byte order; data in the host's own order comes through foreign code, which converts it"; l.2530 "A `match` over bitstrings ends with a clause that takes anything... since the checker does not decide whether bitstring patterns cover every `Bytes` value."
Rule: §5.11 (`big`, `little` only; "For coverage a bitstring pattern, at any depth, counts as matching no value").
Otherwise: with Erlang's `native`, l.2519's second sentence would go; counted `<<rest:bytes>>` as covering, a `match` whose last bitstring clause takes any `Bytes` would need no `_`.

**W27. `..` only on a type with one constructor, with its reason.**
Place: §2.4 l.396 "`..` works on a type with one constructor, since the value might otherwise have been built by another"; §13 l.2724 (c).
Rule: §5.6 "`..` is allowed only on a type with one constructor; on any other it is a type error."
Otherwise: the "since" is rationale; a rule that admitted `..` under a clause that had matched the constructor would end it.

**W28. An abstract type must be exported, with its reason and a rejected program.**
Place: §7.2 l.1911 "An abstract type is exported, since one its module keeps would hide from no module", l.1913–1923.
Rule: §4.4 "An abstract type is exported: one the module keeps private is an error."
Otherwise: admitted as harmless, the rejected program would go; principle 3 refuses what can have no effect, and the guide must explain the refusal of a declaration the reader thinks harmless.

**W29. Unbounded mailboxes: forty lines of pacing and fan-out.**
Place: §4.4 l.960–1007 "**Pacing.** A mailbox has no limit... **Fan-out.**..."; l.1005 "`Process.info` shows such a queue building... but it is for watching what runs: a program paces its messages with its own protocol."
Rule: §10 "Mailboxes are unbounded; a program is responsible for its own backpressure."
Otherwise: the rule is Erlang's and the reader predicts it; the passage is what the rule leaves to the program, and the guide must teach a credit protocol. The warning against `Process.info` as flow control follows from E.21's purpose.

**W30. The terminal is read as keys or as lines, not both.**
Place: §1.3 l.259 "A program reads lines or single keys, not both: `Terminal.subscribe` gives keys as they are pressed, or answers `Left(Io.NotATerminal)`... so that the program can read lines instead."
Rule: §8.2 "The first claim stands, and a claim the other way faults the process that makes it."
Otherwise: the sentence exists because the second claim is a fault, not a value.

**W31. `Io.debug` is not pure.**
Place: §1.1 l.169 "It sends, as `Io.println` does, so it cannot hide in a pure function. `Io.show(x)` is the text it prints, and is pure."
Rule: §9.4 `Io.debug : (a!) -> a! with m`; E.0 shape rule 5.
Otherwise: a reader who knows Haskell's `trace` predicts a pure debug print; the guide must say it is not, which is the design's consistency.

**W32. A spawn site does not cross nodes.**
Place: §8.1 l.2318 "Its `site` is empty for a process of another node; that node's standard error reports the fault with the site."
Rule: §6.9 "With the reason `Unknown` or `Unreachable` it is the empty string, and so it is for a process of another node."
Otherwise: a reader predicts a string travels; did the site cross, the sentence would go.

**W33. A PEM key as one JSON string.**
Place: §8.1 l.2289 "the key `ern config` printed written as one JSON string, its line breaks `\n`", and the configuration at l.2291–2304.
Rule: §11.3 and Appendix C, `"public-key": "<PEM public key>"`.
Otherwise: were the key printed and listed as one line of base64, the sentence and the escaped configuration would go.

**W34. "Service" in two senses.**
Place: §9.5 l.2644 "A service here is the operating system's, not §6.5's."
Rule: §6.5 names a top-level binding that holds an address a *service*.
Otherwise: the disambiguation exists because the report's word is the operator's word for another thing.

**W35. `main` returning ends the program, and `let me = self()` before every spawn.**
Place: §5.1 l.1223 "Had `main` returned at once, the program would have ended before the two had played"; §4.1 l.813 "a parent that gives a child its own address takes it first: `let me = self(); spawn(fn() = child(me))`", written at l.940, 993, 1258, 1335, 1375, 1451, 1615, 2261, 2562.
Rule: §8.6 "The program ends when the entry process dies"; §6.2 "`self()` inside `f` is the new process's address; a parent that wants replies binds `let me = self();` before `spawn`."
Otherwise: both are Erlang's, and the Erlang reader predicts them; the guide repeats the idiom nine times because `spawn` takes a thunk.

**W36. Examples whose shape differs from the report's own.**
Place: §7.2 l.1892–1906, the stack with `Stack(items) : Stack(a)` on every parameter and `export let empty : Stack(a)`, where the report's §4.4 writes `fn push(Stack(items), item)` and `export let empty = Stack([])`; §2.5 l.454 `fn Money.compare(Money(left) : Money, Money(right) : Money)` where §4.8's member omits the annotations; §7.3 l.2170 `bag.put(2).put(1).put(2)`, a method chain in a functional language, admitted by Appendix A's `Primary { Call | Select }`.
Rule: §4.5 "Annotations may be omitted where they can be inferred."
Otherwise: a reader of the report predicts the report's shapes; the guide's annotations are a choice the guide does not explain.

Two passages are rationale by design and are not counted above: §11 l.2696–2708, the design chapter, which restates §0 and argues principle 3 ("Several of these tell the compiler nothing it could not work out for itself"), and the FAQ l.2716 on `fn(x) =`. §0 l.129–134 argues the design as an introduction does.

## Rules of the report the guide never teaches and never uses

By section. A rule "used" means a program or transcript of the guide depends on it; "taught" means a sentence states it.

§2 Lexical elements
- §2.1 a byte-order mark is stripped; a control character is an error in a comment as elsewhere.
- §2.2 block comments `/* ... */`, which nest; `////` begins an ordinary comment; a doc block above a `fn` in a block, or second before the first declaration, is an error.
- §2.3 identifiers are ASCII; a name or segment is at most 255 characters.
- §2.5 the exponent forms `1.0e-9`, `1e10`; a float literal beyond the finite range is an error, one that rounds to zero is `0.0`; `_` anywhere but between digits is an error; a letter after a number is an error.
- §2.6 max-munch and `a<-1` against `a < -1`; the precedence table; prefix `-` and `!` apply once, `-(-x)`.

§3 Types
- §3.1 no negative zero; `Int.toFloat` faults beyond the finite range; a float segment pattern `0.0` matches either zero.
- §3.4 `with` binds to the nearest arrow; the parenthesized form `((A) -> B) with M`.
- §3.5 `derives compare` on a parameterized type gives the member a requirement (`Pair.compare needs a.compare, b.compare`).
- §3.9 a type variable in an annotation is rigid; naming one in a lambda's annotation that is not a `let`'s whole value is an error (`List.map(xs, fn(x : a) = x)`); polymorphic recursion is refused; a recursive group is inferred together; the recursive type parameter rule (`Nest`, `Flip` refused); an expression of pure function type takes a fresh effect variable (`Upgrade(migrate = double, next = done)`), used at l.1099 and never taught; a `foreign fn` effect-polymorphic in a callback; restrictions "checked at instantiation, not at definition".
- §3.10 the four laws of an order and "the program's promise"; a `compare` outside the type's namespace gives no ordering; `Bool`, `Optional` and `Path` have no ordering; the union of constraints across branches.
- §3.11 a `Peer.key` of a bound type is refused (used in the §8.8 answer only).

§4 Declarations
- §4.2 a module may not write its own declaration's qualified name (the guide says the opposite, W23); a type's members as a nested namespace and the `main/stack.ern` conflict; `Prelude.` only where a name is hidden, and `Prelude.List.<>` past a member; the order of unqualified lookup; two declarations of one name in a module.
- §4.5 `with m` over a body that does not act through a process is an error (`fn k() : Int with m = 5`); `fn T.f` in a block is an error.
- §4.6 `<-` at top level is refused.
- §4.7 `Foreign.from(r)` on a reply is a type error; a foreign function's type variables are not reply-carrying (`a!`); a second mark, or one outside the parameters, is an error.
- §4.8 `T.negate` and prefix `-` on a user type (§5.1); the member shapes `(T, T) -> R`, `(T) -> R`, and `Vec.+` on a parameterized type; `fn add(a, b) = a + b` in a block refused; an operator's result does not determine its operands; `%` on `Float` and `<>` on `Int` refused.
- §4.9 a requirement on a variable that stands in the result type alone; a parameter, `let` or pattern variable named as a type variable of a declaration with a requirement is an error; `let f = OrderedSet.fromList` at top level refused; a derived `compare`'s own requirement supplied at a use.

§5 Expressions
- §5.1 a callee is evaluated before its arguments; the order in `x |> f(a)(b)`.
- §5.4 two local `fn`s of one name; a local `fn` named as a parameter or variable in scope; a local `fn` used before a `let` it reads is evaluated.
- §5.5 `let p : T <- e`.
- §5.6 `..Prelude.N` refused; a namespace alone after `..`; `C()` and `C(a, b)` are calls of the constructor's value; a construction is not filled by the pipe, `x |> Some` is `Some(x)`.
- §5.7 a `match`, `receive` or block as the pipe's operand.
- §5.9 redundancy where a bitstring pattern stands in an earlier clause; `as` inside an or-pattern, `Some(1) as x or Some(2) as x`.
- §5.10 a negative literal pattern; `None()`, `Some`, `Some()` and a bare `Circle` refused; `x :: rest as all`.
- §5.11 `signed` and `unsigned`; a literal that does not fit is a compile-time error (`<<-1>>`); what `size(Expr)` may name; `utf8`, `utf16`, `utf32` segments; float widths 16, 32, 64; `Fault("segment overflow")` and `Fault("bitstring not byte-aligned")`.

§6 Processes
- §6.1 two different concrete effects in one body are a type error.
- §6.2 a `send` to a process that has ended does nothing, locally ("The one silence in the language"); a `send` to a peer waits while the host's buffer is full.
- §6.3 `after`'s time is evaluated on entry; a time has no upper bound.
- §6.6 a top-level binding of reply-carrying type is an error; `as` on a reply-carrying scrutinee is an error; a local `fn` may not capture a reply; `fn next() = receive { x -> x }` consumes nothing; `send` hands the obligation to the `receive` clause that binds it (used, not stated).
- §6.8 a function whose mailbox is a variable, called at `Never`, waits for a message that cannot come and the entry process faults with `deadlock`.
- §6.9 `kill` across nodes reaches a process as `send` does; a process the host ends has `Fault(text)`; `spawn` passed as a value counts as written where its name is; each `monitor` call produces one message; what a restart leaves alive ("what it spawned, opened or put in a table lives on"); the innermost `restarting` and nested limits; a window below 1 is 1; a `Supervisor`'s restart runs `f()` again and not an inner `restarting`.
- §6.10 the cross-node `Upgrade` by a spawned process (shown only in the §8.8 answer, for `Register`).

§7 Errors
- §7.4 the list of causes (the guide points at it); a count or a duration below 0 is none, a moment past is now; `Os.exit` outside 0 to 255 faults; the terminal's two claim faults by name; `Fault("the standard input is not UTF-8")` named at l.259 only in effect.

§8 Programs
- §8.1 a result type that is a type variable is taken as `Unit`.
- §8.2 a last line without a line feed is a line and keeps a carriage return; `Terminal.Event`'s constructors (`ArrowUp` to `ArrowRight`, `Escape`, `Pasted`, `Resized`, `Interrupt`); **Keys**, **Paste** and **Interrupt** as paragraphs; **Text from the host** (`NotUtf8`).
- §8.4 **What is checked** (the standard library and the system processes are not); **Addresses and answers** (a foreign address; an address at another type); **Type variables** (a result variable no parameter names matches no value); the `Set` ABI; `{ern, closed}`, `{ern, code_unloaded}`.
- §8.5 the standard library is initialized whole; a dependency through a member an operator resolves to or a fill supplies; the fault report of an initializer, `Init.bad:3 faulted: ...`.
- §8.7 the configuration's refusals (file modes, duplicate names and keys, address families, numbers too large); `ernest.pid`; `listen` on port 0; `measures`; **What it says**, by line (pointed at); a reload's effects on added, removed and renamed peers, and that `listen` and the node's key cannot change; the fingerprint's contents; the gateway and the six frames; the notes of a call; the 1 MB buffer and a `send` that waits; a large value crossing in pieces; a spawn whose time runs out "may have started"; "A monitored spawn that fails leaves no monitor"; `Refused(text)`; `Peer.peers`; a key's type text `Counter.Box(Int)`.

§9 Prelude
- `Path.<>`, `Int.negate`, `Float.negate`, `Bytes.<>`; `Unknown` as a reason (named in the `Reason` listing only; its meaning taught at l.1244).

§10 Runtime requirements
- preemptive scheduling; `Fault("error:system_limit")` on an `Int` beyond the host; Unicode's tables are the host's, of its version.

§11 Toolchain
- §11.1 the host's 255-character names for a module or member; a cycle reported with its modules; "a module that uses a module that failed" is reported in its own line.
- §11.2 `$Input2.T` and a shadowed session type; line mode; `:output`; `:set` and its values (named at l.2630 only); the reload's forgetting of a binding and its two messages; `Fault("its code was unloaded")` and `Fault("the binding has no value, since one before it faulted")`; two tests of one name refused; `ern test --config-dir`; the shell's refusals in a node (`:load`, `Peer.key` at a session type); `--main` of another module refused.
- §11.5 where each error is placed (the guide shows diagnostics without stating the placement rules); the help lines of the restriction errors.
- §11.6 the layout rules (pointed at).
- §11.8 status 70 and 130; `ern format --check`'s status.

Appendix E
- E.0 shape rule 6 (documentation, pointed at), 7, 9 (no `Bool` that chooses); E.0 rule 1's shim test (taught as "the shim pattern" in §8.5 without the three-times rule).
- E.5 `size` on text in graphemes is taught; `padStart`/`padEnd` shortening, `toUpper("ß")`, `lines`, `split` on `"\r\n"` are not.
- E.6 `Char`: no function used or taught.
- E.8 `bitAnd`.. `shiftRight`, `pow`, `toStringBase`; E.9 the trigonometric functions, `Float.toString`'s form.
- E.13 `Random` (named at l.577 and l.2742 only).
- E.14 every `Path` function (`Path("...")` is written; `join`, `split`, `parent`, `under`... never).
- E.15 `alarmAt`; E.16 `Terminal.size`, `Terminal.columns`.
- E.17 every function but `write` (l.115) and `read`'s name (l.582); `Entry`, `Kind`, the link rules, the permission rules.
- E.18 `connect`, `port`, `remote`, `local`, `closeListener`; the 5-second and 3-minute drain; `Fault("callee was closed")` by name.
- E.20 `toHex`, `fromHex`, `indexOf`, `replace`, `join`, `repeat`.
- E.21 `FaultReport`'s fields, `Info`'s `activity`, `trace`.
- E.23 `user`, `give`, `closeInput`, `Output`'s constructors, `Finished`'s fields but `stdout`; `Os.start`'s process-group rule.
- E.27 `peers`; `Refused`.

Appendix G
- G.2 `Markdown`, G.3 `Ansi`, G.4 `Load`, G.6 `Json`: never mentioned. G.5 `Balancer` named once (l.2318). G.1 `Ets` as the §8.5 example.

---

# Reader L: the log as families

# Reader L: the log read as a set

Commit `d38d11c8`, 2026-10-09. Read: `docs/decisions.md` whole, 667 entries, the index first; `report/language.md` (§0 above all), `report/toolchain.md`, `report/library.md`. Nothing else. Nothing edited.

The last principles review (2026-10-01) added sixteen sentences, five of them §0's and one §0's host paragraph, and closed fifteen families. Those sentences are taken as given below: a family one of them decides is listed briefly, with the entries since 2026-10-01 read against it, and no sentence is proposed where §0 already has one. The entries since 2026-10-07, the peer proposal and MVP 3.0, and the two days of its close, were read with care, since no review has read them.

The hand-in is in three parts: the families, the one with the most undecided entries first; the entries decided on cost, time or for now (L1 onward); the pairs of entries that decided alike cases differently (numbered on).

An entry is "undecided" here when the principle or the sentence it cites would have implied the opposite verdict as well, so that the verdict rests on the entry's own argument and not on a sentence of the report.

---

## Part 1. The families

### Family 1. A failure the program meets: a fault, a `Left`, a `None`, or a corrected value

**The sentence that exists.** §7.4's opening (*A Failure's Shape*, 2026-10-01): a function answers a failure as a value, `Optional` without a cause and `Either` with one; a function faults only where it cannot return, where its `Float` leaves the finite range, or where the failure is the runtime's own; an operator and a construction fault; "a refused request faults the process that made it"; a count or a duration below 0 is none, a window is corrected as §6.9 says, a moment past is now, and nothing else is corrected unsaid. E.0 shape rule 4 says a function faults only as §7.4 says.

**Entries and the principle each cites.**

- *A Program Ends With `Os.exit`* (§7.4, principle 3): a status outside 0 to 255 faults. Decided: `exit` cannot return.
- *A Failure's Shape*; *The Failure Family's Rules*: `Io.Error` gains `Exists`, `NotAFile`, `NotUtf8`, `Invalid`; a port out of range answers `Left(Invalid)`; `Int.toFloat`, `exp` and `pow` fault beyond the range; `Path.name` answers `None` for the root. Decided by the sentence.
- *The Report Rewritten for Peers*; *The Module Peer*: `Peer.offer` under a key a living process holds faults, `Fault("k is offered by a living process")`; `Peer.offer` of another node's process faults; `Peer.find` answers `Unreachable`, `NotOffered`, `OtherType` as values. Principle cited: §7.4's "a refused request faults" for the faults, and "a spawn faults for nothing the network or the peer does" for the values.
- *Load and Balancer*: `Balancer.start([])` faults; `Balancer.pick` answers `None`.
- *MVP 3.0's Findings Decided*, E3: `Balancer.serve` for a place the balancer was not started over faults its process, "since a pick that answers an unlisted place routes around the mistake". No principle cited beyond CLAUDE.md's rule against routing around.
- *MVP 3.0's Findings Decided*, P7 and K22: `Load.schedulers` over a window below 1. "A fault was decided first, on a reading of §7.4 that it does not hold"; corrected to 1 by analogy with the restart window (principle 1). The sentence as written was read two ways in one day.
- *The `Supervisor`'s Shape*; *The Requirement Built*; E.22: a second process running a group faults, `a group runs in one process`; a child whose supervisor ended faults; a child on another node faults before it joins. No principle cited for fault over value.
- *`Tcp.listen` Names Its Interface*; *The Failure Family's Rules*: a port out of range, a host with U+0000, a path with U+0000, a mode with bit `0o1000`: `Left(Invalid)`, "an argument the host cannot take whole", which Erlang answers with `badarg`.
- *`Int.pow` Keeps Its `Optional`* (The Full Review's Questions, E31): a negative exponent is `None`, by shape rule 4. Decided.
- *Atoms, Counted*; E.19: `Erl.atom` of a text past 255 characters faults as a foreign function that raises does. Decided: the host's raise.
- *A Claim of the Terminal the Other Way Faults Its Caller*: the second claim faults the asker. Decided by §7.4's "a refused request".

**Does the sentence decide?** Not whole. "A refused request faults the process that made it" is the clause the faults of `Peer.offer`, `Balancer.serve`, `Supervisor.group` and the terminal rest on, and it does not say what a refused request is: `Tcp.listen` on a port in use is a request the host refuses and answers `Left(Other(...))`; `Fs.makeFile` on a path that exists is refused and answers `Left(Exists)`; a port out of range is refused and answers `Left(Invalid)`; `Peer.offer` under a held key is refused and faults. Read with the verdicts, the line the log drew is this: a request that breaks a rule of the report, which the program alone could have kept, faults; an argument the host cannot take whole is `Left(Invalid)`; one outside the function's own domain is `None` or is corrected where §7.4 names the correction; and what the world refuses, a port in use, a file that exists, a peer that offers nothing, is a value with its cause. Four kinds, and §7.4 names two of them. K22 shows the cost of the missing sentence: a verdict taken on a reading of §7.4 and reversed the same day.

**Proposed sentence, §7.4,** in place of "A refused request faults the process that made it": "A request a rule of this report refuses, which the program alone could have kept, faults the process that made it: an offer under a key a living process holds, a second process running a group, a claim of the terminal the other way. An argument the host cannot take whole is `Left(Invalid)`, and one outside the function's own domain is `None` or is corrected as this section says; what the world refuses, a port in use or a file that exists, is a value with its cause." E.0 shape rule 4 gains nothing: it already points at §7.4.

### Family 2. What Ernest adds to an operation of the host

**The sentence that exists.** None in the report. CLAUDE.md holds the rule (*What Ernest Adds to a Host Call*, 2026-09-29): a check, a count or a table row around a native call never costs a multiple of it; an operation Erlang makes without a message makes none in Ernest; only a system process costs a message by design; no scan grows with anything but the operation's own input; `make bench` measures it. E.0 rule 1 holds the library's half, three times the host's or growth the host's lacks, since *The Full Review's Questions, One by One* (E11, E12). §0's host paragraph says only where a check's cost falls, "on that form alone", not how much it may be.

**Entries and the principle each cites.** Each cites CLAUDE.md's cost rule, a measurement, or principle 5, and none a sentence of the report:

- *The Message Check Moves to the Point of Exposure*: a hop from 1.5 to 4.6 microseconds refused; the proxy at exposure taken.
- *Receive Guards Are Guard Expressions*: a buffer and a scan on every `receive` for ever refused (principle 5); now an instance of the host paragraph.
- *What Ernest Adds to a Host Call*: the call written in place; the shape check; a call's monitor its reply's alias; the table keyed by the caller.
- *The Runtime's Own Is Not Checked*: the library's foreign returns and the runtime's calls unchecked, `Map.get` 63 to 24 nanoseconds.
- *A Value Is Checked Where It Crosses*: a reply checked only where it came from foreign code, by its form.
- *Supervision Stays in the Reaper*: `spawn`, `monitor` and a call's row kept through the reaper, 4.9 microseconds against the host's 1.5, "the round trip at a spawn is the supervision itself".
- *Three Scans on a Value*; *Char Reads the Host's Tables*: regular expressions and whole-string splits replaced; an undocumented host module taken for speed, pinned by tests.
- *A Check at the Boundary Lasts as Long as Its Process*: a proxy per distinct address kept for the process's life.
- *The Reaper's Look at Rest*: the look by its cause, 1.1% to 0.3% of a core; the exact count "can follow if a program's rest is ever what is measured".
- *The Hardening Built*: the session as table rows (an input's cost grew with the processes alive); a binding's holder kept a persistent term by the numbers.
- *Spawn Keeps Its Wait*: 3.4 times the host's spawn kept, since the wait is the back-pressure, "a system process's message by design".
- *The Prelude Measured*: every prelude function beside the host's; `spawnMonitored` at 7 times and a `monitor` of an ended process at 15.6 times "nothing of these is changed before the user decides"; *Spawn Keeps Its Wait* decided `spawn` and `monitor`'s wait, and the two ratios stand unaddressed.
- *The Emitted Code Measured*: the count around a foreign function with a mailbox type, 380 nanoseconds, lifted for ten functions by `-waits_on_nothing`, since `Clock.now` at 7.5 times the host's read was "a count costing a multiple of the call".
- *Clock.now Reads the Host's Clock*: a system process's message removed, "allowed by design, and this one was no design".
- *The Boundary Rebuilt Every Float*: 72 to 16 milliseconds on a megabyte of JSON; the check states §3.1's rule and the repair is the exception.
- *A Peer's Down Has No Site*: a monitor of Ernest's own, a frame answering with the site, refused as "a message to an operation the host makes without one".
- *Calls Across Nodes*: a note frame sent to the callee's node for every call, and read by a restart, accepted: "the restart on a node costs that one exchange more".
- *The Tests, the Costs and the Guide*: `make bench` between two nodes, a TLS ping at 1.4, a call at 1.3, the gateway's step 24 of 118 microseconds.
- *`Address.ask` Is Taken Out*: the cost named and set beside the principles, "a feature the principles admit is worth such a price, and one they do not admit is not worth less of it".

**Does the principle decide?** No principle of §0 speaks of cost, so none of these verdicts follows from the report; each follows from CLAUDE.md's rule and a measurement, and the two that read the rule's "by design" clause came out opposite: `spawn`'s message is by design and `Clock.now`'s was not, with the line drawn in the entry, that a process whose message gives the operation nothing is no design. The rule and that line are the project's and not the language's, which is why `spawnMonitored` at 7 times and a monitor of an ended process at 15.6 times stand with no verdict: the report has nothing to measure them against. §10 already states one cost rule, that tail calls take constant stack space, so a cost rule has a place there.

**Proposed sentences, §10,** as two bullets: "What the runtime adds to an operation of the host, a check, a count or a row, costs a fraction of that operation and never a multiple, and grows with nothing but the operation's own input. A system process costs its message where the process holds what the operation needs, and no message where the host answers without one." And, in E.0 rule 1, after "in a system module, a function that reaches its process is a primitive": "A system module's function reaches its process only where the process holds what it answers, an alarm or a request in flight; what the host answers without a process, the time, a size, a table, is read without one."

### Family 3. What the runtime writes unasked

**The sentence that exists.** None general. Each case is stated where it stands: §11.2, every fault of every process on standard error; §8.6, the runtime prints nothing of its own about a signal; §8.7, a node says on its standard error that a peer connected, was lost, refused or replaced, and what a reload did, and "the host's own reports of its nodes are not written"; §10, the host's message when memory is exhausted; §11.2, a line's time where standard error is neither a terminal nor a journal.

**Entries and the principle each cites.**

- *A Signal Says Nothing* (§8.6): the host's `SIGTERM received` note removed; nothing printed about a signal.
- *The Shell Reports a Fault*, then *Every Fault Reaches Standard Error* (principle 3): a fault nobody monitored was visible nowhere; `ern run` prints every fault, and a restart `restarted`. Principle 3 as written says failure is visible in the code or in the type; a fault line on standard error is neither, so the sentence that admits it is §11.2's own.
- *Running as a Service*: a time on each line where no terminal and no journal stamps it; a program's own output never changed (principle 3).
- *A Fault at the Program's End*: a fault after the entry process's death is not reported.
- *Exhausting Memory Ends the Program* (The Full Review's Questions, U1; §0's host paragraph): the host's message written, no crash dump.
- *The Carrier*: a node's lines for a connection, a loss, a refusal, a replacement; the host's own reports dropped by a filter, its handshake refusal turned into the node's line; a message to the gateway naming no process "is dropped, and the node says so".
- *A Node's End and Its Reload*: a reload's lines, each peer added, removed or renamed, "and a reload that changes no peer still says it read the file, since its signal carries nothing back".
- *A Dial Answered Under Another Name* (§8.7): "neither node says it, since the host refuses it without a reason a node can read".

**Does the principle decide?** No. The verdicts are consistent, and the rule they follow is unwritten: the runtime writes on standard error what a program cannot learn and an operator must, a fault, a node's connections, the host's failure that ends the program, and never a program's own act, a message dropped by §6.2's silence among them, nor what the host says of itself. Principle 3 is cited for the faults, but it is about the program's view, and this is the operator's; §6.2's one silence is about what the program is told, and a node's loss line is written while the program's `send` stays silent. Without the sentence the next door, a line for a dropped message, a line for a sender held at a full buffer, is argued from scratch, as a node's lines were.

**Proposed sentence, §11.2,** before "`ern run` reports every fault": "The runtime writes on standard error, unasked, what a program cannot learn and an operator must, a fault of a process, a node's connections and their loss, and the host's failure that ends the program; it writes nothing of a program's own act, a message dropped among them, and nothing the host says of itself." §8.7's and §8.6's sentences become its instances.

### Family 4. Standard library or library: where a module goes

**The sentence that exists.** E.0's preamble and rule 2: a function enters Appendix E when a rule admits it; a published specification is a library's; a policy buried in a function is refused (rule 3); Appendix G: a library is "what anyone writes on Appendix D's pattern", written when wanted (*Libraries As They Are Wanted*). CLAUDE.md: a library is written when our work needs it, when someone asks, or when we want it.

**Entries and the principle each cites.**

- *Ets Is a Library* (§10, E.0 rule 1): a table shared between processes is refused by §10, so `Ets` leaves the standard library. Decided.
- *The Web Server Waits for Its Library*; *`libs/markdown`, Written at Once*; *The Library Family's Rules* (E.0 rule 2): HTTP, CommonMark and ECMA-48 are specifications, a library's. Decided.
- *`Clock.monotonic` Is In, and `Udp` Is Placed* (E.0 rule 1): `Udp` is a module of Appendix E, dated. Decided.
- *A `Supervisor` in the Standard Library, and `fault`* (E.0 rule 3): a policy passed as an argument is not buried; the standard library's. Decided.
- *No Remote Computation in the Language* (E.0 rule 1): "what a program needs to place work on a lightly loaded node is two facts only the runtime has... They enter with `Peer` in MVP 3.0, `Peer.nodes` and `Peer.runQueue`, by E.0's first admission rule. ... The policy over them is a library, `libs/balancer`".
- *Load and Balancer*: `Load.runQueue`, `schedulers`, `cpu`, `memory`, `disk` built as `libs/load`, Appendix G.4, "their shape agreed with the user before they were built". No rule cited for the library over the standard library; *MVP 3.0's Findings Decided* P6 says "G.4 reads them, and is informative as every library is".
- *The Module Json* (E.0 rule 2): a published format, a library's; its primitives an application `erl/json`, "the only such application". Decided by rule 2.
- *Fs.removeAll Removed*: "A function whose failure is the whole file system is too dangerous for the library to carry, and none of our Ernest code used it." Admitted on 2026-09-28 by rule 3 (*What `Fs` Holds*), built in C by *The Release Review's Questions* (C1-3), removed with no rule of E.0 cited; the second reason is a count, which principle 5 says decides nothing.

**Does the principle decide?** Not for two. `Load.runQueue` reaches the runtime, which rule 1 admits, and *No Remote Computation* placed it in Appendix E by that rule; three weeks later it is a library with no sentence saying why, and E.0 as written would have put it beside `Process.info`. `Fs.removeAll`'s removal names danger, which no rule of E.0 names; rule 3's "a choice the library would be making for the program" could carry it, whether a tree's links are followed being such a choice, if the entry said so. The rest is decided.

**Proposed sentence, E.0's preamble,** after "a function enters when a rule admits it": "A module is the standard library's where its functions are E.0's to admit and refuse, and a library's where it is over a published specification or a policy, where it needs what §10 refuses the standard library, or where its only user is another library." The last clause would make `Load`'s place a rule, since `Balancer` is its user; without it `Load` belongs in Appendix E, and one of the two should give. For `Fs.removeAll`, the verdict needs a reason E.0 holds, which rule 3 can give in one clause: "and so is a function whose definition chooses for the program what the file system does with a link."

### Family 5. What a job takes from where it is started

**The sentence that exists.** Instances only: §11.2, `./.ernest/startup` is not run without `--config-dir`; §8.3, a program started without `--config-dir` is no node; §11.1, single-file mode takes the current directory as the source root; §11.3, `ern config` creates `./.ernest` by default; §11, `ern` starts the host without the environment's `ERL_*` flags.

**Entries and the principle each cites.**

- *The Startup Inputs, Two Files* (no principle): the person's file and the node's both run.
- *A Directory Runs Nothing of Its Own* (principle 1): the node's `startup` runs only where `--config-dir` names it; "Vim's `exrc` is off by default, and git clones no hooks".
- *The Security Reader's Decisions*: the host's flags from the environment cleared by `bin/ern` (principle 3).
- *The Node's Directory*: `ern config` keeps its default `./.ernest`, "which makes no node until a run names it, as a default directory that makes a node is left out on purpose".
- *MVP 3.0's Findings Decided*, P8: `./.ernest` is no program's directory; "nothing read it".
- *A Startup File's Group Keeps Its Write* (S3): a team's directory runs what the team writes, "as `make` in a checkout the team writes runs the team's Makefile".

**Does the principle decide?** No. Principle 1's reader of processes knows Erlang, whose `erl` read `.erlang` from the current directory for decades; the verdict rests on Vim and git, which are neither of principle 1's sources, and on security, which §0 does not name. The verdicts agree, and the rule they follow is unwritten.

**Proposed sentence, §11,** beside the environment's flags: "A job reads from the directory it is started in only what its command line names, a file or a root; nothing there configures a job or runs in it unasked, and a program is a node only where `--config-dir` says so."

### Family 6. What crosses between nodes, and what a node answers

**The sentences that exist.** §3.11, the bound type and the compiler's three refusals; §6.2, a send to an unreachable node vanishes; §6.5, an adapted address crosses as a reference and its function runs where it was made; also §6.6, a call across nodes and its notes; §6.9, `Unreachable` and the empty site; §8.7 whole, the node, its configuration, start and end, connections, frames, loss, addresses, messages, calls, spawn, key; §10's new bullets; E.27.

**Entries and the principle each cites.**

- *Code Travels Only With a Spawn* (principles 1 and 3): a function bound to its node; a message between nodes is values only. Decided, and §3.11 states it.
- *The Peer Proposal Is MVP 3.0's Design*: the four rules of its section 1, Erlang's process semantics taken whole, nothing invisible and the program decides, a protocol is a type, what crosses is identified and never named. The reasons are `nodes.md`'s, which this reader does not read.
- *The Report Rewritten for Peers*: an adapted address crosses whatever node its target is on, since "where a target lives is not a type, so no refusal replaces the fault"; §8.7 is *Nodes*; a node detects no deadlock; `Unreachable` in `Reason`. Decided by §3.11's rule that the compiler refuses and the runtime checks nothing at a send.
- *The Bound Type in the Checker* (principles 2, 3, 5): the function a spawn starts is one the checker sees; `Peer.spawn` is not a value; a key's and a spawned mailbox's type known whole; a key's text qualifies every name. Decided by §3.11 as it now reads, which lists the forms.
- *MVP 3.0's Findings Decided*, P1 three times in one day (the form stays; then a restriction on the type scheme by principle 1; then the form stays again by principle 5, "work of the order of effect polymorphism"), A3 and C11 (a local `fn` admitted as a lambda is, principle 1), A5 and K1 (a free mailbox type is `Never`, one rule for three, principle 1), A1 (a key at a session type refused in a shell node until MVP 3.1), K23 (an adapted address of an earlier start is dead, §8.7's one rule), K17 and S2 (a name resolved at the dial alone), S1 twice (a listed key is its own node alone, by the host's own check, the dialing side left as it is).
- *A Peer's Down Has No Site, and Peer Comes First* (principle 1, the cost rule): the site crosses in no `Down`. Stated as a departure in §6.9.
- *The Module Peer*: `NotLoaded` by module "lasts one milestone"; a function's module checked at its version; a node carries its whole build; a find's answer is the host's; a late answer the spawner's gateway's; `Refused` stays though nothing answers it; order through an adapted address made on another node kept, with one step more stated.
- *Addresses, Messages and Monitors Across Nodes*: the runtime changed nowhere; "a send to an address of a node not listed vanishes, which only a monitor shows", left as §6.2's rule.
- *Calls Across Nodes*: the gateway records the notes itself; the second note goes wherever the call ends, so that no note outlives its call (the memory rule).
- *A Node's End and Its Reload* (§8.7): the end in order adds no frame; a monitor made while a node stops gives `Unknown`; a rename is said.
- *MVP 3.0's Findings Decided*, P3 (principle 3): a node is no peer of itself, since a find that could land locally "would make one operation of a local one and one over the network".

**Does the principle decide?** §3.11 and §8.7 decide these as they now stand, and they were written from the proposal, so the family is one the sentences came with. Three notes. P1's three verdicts in a day show that nothing in §0 says what a function type carries of a closure; the verdict rests on cost and on principle 5's count, and *Later* holds the mark. P3 cites principle 3, which as written does not decide it: a `Peer.find` that could answer the node's own offer is as visible in the code as one that cannot, and nothing is hidden by it; the reason is principle 2's, two operations under one name, or principle 1's, and E.27's sentence, "the running node is no peer of itself", is what decides. And *The Module Peer*'s rule by module is a rule the report states for one milestone, with its lifting dated, which is the form CLAUDE.md asks for a gap; it shapes two libraries meanwhile, `Load` and `Balancer` holding no binding, and the test lets' bindings sent the libraries' tests to the integration tests (*A test is a binding*). No sentence is proposed: the family's sentences are §3.11's and §8.7's, decided with the proposal, and the open question, a mark for what a closure captures, is Later's with its condition.

### Family 7. The host's rule

**The sentence that exists.** §0's host paragraph (*The Host Paragraph*, 2026-10-01), with its clause of 2026-10-02 that an outcome while the host starts is the host's.

**Entries since the sentence, and the principle each cites.** *The Host Family's Rules* (negative zero stays out, the normalization halved; Unicode's version stated); *An alarm at a time follows the clock* and *A signal in the host's first moments is the host's limit* (MVP 2.99b's Questions, host paragraph); *§0: an outcome while the host starts is the host's* (the paragraph's own gap, closed); *Exhausting Memory Ends the Program* (U1); *A closed socket lets go within a bound* (S1, C108): the host's 5 seconds with "an end the host lacks", 3 minutes, decided with the user and no principle cited; *A Fault at the Program's End* (§8.6); *String Stands on the Host* (the host does not keep its page, so E.5's searches stay Ernest's); *Char Reads the Host's Tables* (an undocumented module taken, pinned by tests); *OTP's Compiler, Worked Around* (a narrow workaround of a host defect, stated and dated); *The Carrier* (the host's `wait_pending`, its handshake refusal turned into the node's line); *MVP 3.0's Findings Decided* K9 (`memory`'s whole minutes refused rather than rounded, `disk`'s milliseconds kept exact), C4 and C1 (the host's defaults, a silent exception and a removed handler, replaced by the report's rule), S1 (the digest in the host part so the host's own check binds it).

**Does the paragraph decide?** Yes, for all but two. The socket's 3 minutes is a bound Ernest adds where the host holds a descriptor for ever; the paragraph speaks of a value truncated or coerced, not of a resource held, and the sentence that carries the bound is §6.9's owner family's, "what the host will not reclaim on its own ... belongs to a process and ends with it", which the entry does not cite. And *OTP's Compiler, Worked Around* is a workaround of a defect, which the paragraph does not reach (a defect is no rule of the host) and CLAUDE.md refuses; it stands as decided with the user, dated by its test. Both are in Part 2.

### Family 8. The reader

**The sentence that exists.** Principle 1's three sentences (*The Reader Principle 1 Means*).

**Entries since, and the source each cites.** *The Reader Family's Rules* (every rule stands, reasons restated); *The Key and the Hard Link* (Erlang's `maps:merge_with` and OCaml's `Map.union` pass the key); *The Operations Note Rewritten* and *The Order Bound Once* (OCaml's functor applied once, Erlang's `ordsets`); *MVP 2.99b's Questions, One by One* (`monitor` takes a `Process`: `erlang:monitor(process, Pid)`; `let me = self()`: `Self = self()`; a test may receive: `main` does; `Test.` stays, Standard ML and OCaml write names qualified); *The Full Review's Questions* (`let _ = e`, `with m` only where the body acts, the blank line gives the first doc block to the module: OCaml's special comments); *A Record Type That Fits Stays on One Line*; *`Address.ask` Is Taken Out*; *A Local `fn` Is a Lambda with a Name, at a Spawn Too* (A3, principle 1); *A Free Mailbox Type at `Peer.spawn` Is `Never`* (one rule for three, principle 1).

**Does the principle decide?** Yes, with two misreadings of the sentence. *A Record Type That Fits Stays on One Line* cites "Gleam's and OCaml's formatters, which principle 1's readers know": Gleam is no source of principle 1, and `docs/style.md` keeps it a guide to the code's form, so the layout stands on OCaml's and on §11.6's bracket rule alone, which the entry also gives. *`Address.ask` Is Taken Out* says "`gen_server:send_request` is another language's form, and a form is not admitted because another language has it", but Erlang is principle 1's own source for processes, so the sentence that refuses the ask is the principle's first, the reader knows Ernest first and writes the helper from `spawn`, `call` and `send`, which the entry also gives; the "another language" clause does not apply to Erlang. Neither changes a verdict. No sentence is proposed.

### Family 9. A second spelling, and the forms

**The sentence that exists.** Principle 2's two sentences, with the fourth clause of 2026-10-04 (the fill) and principle 3's fill clause.

**Entries since.** *The Forms Family's Rules* (`with Never` beside `with m`; parentheses after `|>` change nothing; `1e10`); *The Full Review's Questions* (the fill kept, the clause added, P2; a module's own qualified name only where hidden, P7; `with m` only where the body acts, P12; `needs` and `derives` read by position, P17; `-(-x)`, one prefix; K13, no second `with` after a function result); *MVP 2.99b's Questions* (a path in a record update, admitted by the nest clause; `let me = self()` kept; `let _ = e` kept, `foreach`'s callback `Unit`; no `askForever`); *The Requirement, the Fill and the Set as Data* (a default argument refused as "a form Ernest has nowhere else"); *The Path Built*; *A Record Type That Fits Stays on One Line*.

**Does the principle decide?** Yes, each by a clause of the sentence, the fill by the clause written for it the same day, which is the one addition to the principle since the review. No sentence is proposed.

### Family 10. Compiled, run, or silent

**The sentence that exists.** Principle 3's third to fifth sentences.

**Entries since.** *The Compiled Family's Rules* (a stray doc block an error; two help lines); *The Grammar Generated Against* (a block ending in `let` is the grammar's; `Foo()` a call of a value refused by the checker; a type's parameters distinct); *The Type System Argued* (a recursive type at its own parameters refused at the declaration; `fn next() = receive { x -> x }` consumes nothing; a top-level reply refused); *A Type Reached Through Another Module's Interface* (the checker fails closed, status 70, where it had let `==` through); *The Bound Type in the Checker* (three refusals, compile time); *The Boundary Trusts a Type Variable* (the trust stated, a run-time silence the report names); *A Binding of a Previous Version Is Forgotten* (the shell forgets a binding the reload's type change made unsound, naming MVP 3.1); *MVP 3.0's Findings Decided* A1.

**Does the principle decide?** Yes. The two for-now verdicts, the binding forgotten and the key at a session type refused, name their milestone, which is the form the rule asks. No sentence is proposed.

### Family 11. Who holds what is waited for

**The sentence that exists.** E.0 shape rule 8's criterion (*What Waits With a Limit*).

**Entries since.** *The Waits Family's Rules* (`Address.call` keeps `Optional`; `Tcp.subscribe` refused; `Tcp.readForever` refused); *MVP 2.99b's Questions* (`Address.ask` with milliseconds after the callback; one budget over several waits is the composing function's, E32's `retryMs`); *`Address.ask` Is Taken Out*; *The Module Peer* and E.27 (`find` and `spawn` take milliseconds, another party; `offer` and `peers` answer at once); *Load and Balancer* (`pick(balancer, ms)`, `schedulers(window)` waits the window it is given); *Clock.now Reads the Host's Clock* (answered at once, no process).

**Does the criterion decide?** Yes. `Balancer.pick` asks the program's own process with a limit and answers `None`, which is a call's shape under §6.6; `Load.schedulers` waits its window by its meaning. No sentence is proposed.

### Family 12. Members, operators and requirements

**The sentences that exist.** §4.5, §4.8 and §4.9 (*Members, Operators, and No Hidden Argument*; *The Requirement Written into the Report*).

**Entries since.** *The Members Family's Rules*; *The Operations Specification Read* (a member's shape under a requirement fixed by rule; `show` a requirement's word); *The Requirement, the Fill and the Set as Data* (a default argument refused; `needs a.compare` admits nothing else; `derives compare`); *The Requirement Built*; *The Operators as Shims, Built* and *The Operators Stay Ernest* (four verdicts in four entries, ending with §9.6's rule that the operator is the primitive and the function of its name is written with it); *The Verb Per Kind* (`Path.<>` a member §4.8 admits for any type); *`Io.show` states its requirement* (P4); *A measuring window* and the rest are elsewhere.

**Do the sentences decide?** Yes. The operators' four verdicts ended in a sentence, §9.6's, and *The Operators Stay Ernest* names what the earlier sentence could not see, that a shim of the host's operator documented a path the compiled code never takes. No sentence is proposed.

### Family 13. The prelude

**The sentence that exists.** §9's opening (*What the Prelude Holds*).

**Entries since.** *The Prelude Family's Rules* (`Test` leaves; `Path` and `Process` stay); *`Address.ask` Is Taken Out* (§9: "a helper provides an ask's result"); *The Report Rewritten for Peers* (`Unreachable` in `Reason`; `Peer`'s functions the library's "the same way", named by §3.11 and §8.7); *The Sixteen Sentences Read Back* (`Io.show` and `Io.debug` listed in §9.4). Decided by the sentence. No sentence is proposed.

### Family 14. The one silence

**The sentences that exist.** §6.2 and §8.2's *Text from the host* (*The One Silence*).

**Entries since.** *The Silence Family's Rules* (`Os.environment` asks by name; `via`'s fault stays the target's); *The Report Rewritten for Peers* and §6.2 as it now reads (a message or a `kill` to an unreachable or unlisted node vanishes; what waited to be sent is dropped at a loss); *The Module Peer* (a late answer to a find is dropped by the alias; a spawn's late answer ends its process); *The Carrier* (a message to the gateway naming no process is dropped, and the node says so); E.27 ("in a program that is no node an offer is accepted, and nothing finds it").

**Do the sentences decide?** Yes, by their letter, with one loose fit: an offer accepted on a node that has no peers "asks nothing back" and acts on nothing that has ended, so §6.2's sentence covers it by its spirit and not its words; a program that offers on no node learns nothing. The report states it in E.27, so it is no silence unsaid. No sentence is proposed.

### Family 15. Who owns a process

**The sentence that exists.** §6.9's last paragraph (*Who Owns a Process*).

**Entries since.** *The Owner Family's Rules* (a `Down` names its process; `kill` beside `close`; `spawnMonitored` and `Unknown` stay); *The Full Review's Questions* (a closed socket lets go within a bound; `spawnMonitored` and `Unknown` stay, fourth of the rules that buy little); *The Hardening Built* (a resource killed at its owner's death, returns at its close, stated); *The Bound Type in the Checker* (a resource is three message types, bound); *The Module Peer* (a monitored spawn's process waits on the peer for its spawner's monitor, so that no link ties the two). Decided by the sentence. No sentence is proposed.

### Family 16. The reply discipline

**The sentence that exists.** §6.6 and §3.9 as *The Reply Discipline Names No Type* wrote them, and the ten gaps *The Type System Argued* closed.

**Entries since.** *The Type System Argued* (a function returning its mailbox type; the restriction's reach; skipped paths; a hidden name; selection and update; a top-level reply; a guard gets no rule; an operand is a member's parameter; a foreign callback's result stays the foreign code's); *The Replies Generated*; *A Foreign Function Marks Its Equality* and *No Mark Lifts a Foreign Function's Restriction* (`List.reverse` stays Ernest at 2.4 to 4.6 times the host's, since a mark that widens a scheme on foreign code's word is refused); *The Bound Type in the Checker* (a lambda capturing a reply refused at `Peer.spawn`, since a spawn that fails leaves the reply held by no one); *Calls Across Nodes* (`Crash(reply = _) -> fault(...)` refused and left, since a pattern binds every reply field and the check is by name); *The Full Review's Questions* E19 (two linked lists of replies become `List`s).

**Does the sentence decide?** Yes. No sentence is proposed.

### Family 17. Declared order, what a value shows, one door

**The sentences that exist.** §3.5 (*No Canonical Order*), E.1 (*A Value Shows Itself at a Known Type*), §3.8 (*One Door for the Host's Values*).

**Entries since.** *The Order, Show and Door Families*; *`Io.show` states its requirement, and writes what it names* (P4, N2: `needs a.show`, composed at a type built from the variables); *`Io.show` keeps its type known whole* (feedback 84); *The Boundary Trusts a Type Variable* (`Foreign.from` at a known type, as `Io.show`); *The Module Json* (the host's terms through primitives, since `Foreign` cannot take a map apart, and widening `Foreign` set aside by principle 2). Decided. No sentence is proposed.

### Family 18. A restart and a reload

**The sentences that exist.** §6.9 (*A Restart Begins Afresh*; a restart cancels what the process asked for) and §11.2's loading and reloading.

**Entries since.** *The Release Review's Restarts*; *The Full Review's Questions* C104 (a bad foreign message's fault lands at the next wait, which `restarting` restarts, rather than a third way to end); *`restarting` is process-only* (K2); *A Binding of a Previous Version Is Forgotten*; *The Full Review's Questions* C139 and C140 (a reload tells which bindings run a version by the version each holds); *A Node's End and Its Reload* (a node's reload is of its configuration, not its code); *The Three Proposals Reviewed Before Anything Is Built* ("under MVP 3.1 a reload is a load of what changed with nothing purged, which is what a deploy does on a node, and neither changes code under a running process"). Decided by §6.9 and §11.2, the binding forgotten being for now (Part 2). No sentence is proposed.

### Family 19. What can still deliver

**The sentence that exists.** §8.6's list of what proves progress possible, and "a node detects no deadlock".

**Entries since.** *The Reaper's Look at Rest*; *The Supervisors Load Sampled at Rest*; *The Library Stands on the Host* (a standard library function whose effect is only its callback's is not counted as foreign code, since what waits is Ernest); *The Emitted Code Measured* (`-waits_on_nothing`); *The Report Rewritten for Peers* (a node detects none, being reachable from outside); *The Module Peer* (`Peer.offer` and `Peer.peers` wait on nothing). Decided by §8.6, whose list the count follows. No sentence is proposed; the list is a list, as the earlier review left it, and the verdicts since fit it.

### Family 20. The foreign boundary

**The sentence that exists.** §8.4 as it now reads: what is checked, addresses and answers, functions, type variables, "the checks catch a foreign side's mistake and confine nothing".

**Entries since.** *The Boundary Trusts a Type Variable*; *The Hardening Built* (forged handles dropped; a crafted `.erc` refused by reading its bytes); *The Full Review's Questions* S7 (an address foreign code was never given is a bad value, but an `Address(Never)`); *An Abstract Type's Private Fields Travel in Its Interface* (the descriptor builder reads them; the interface's hash takes them); *The Boundary Rebuilt Every Float* (a float matches only where it is no negative zero, and the repair is the exception); *The Module Peer* (`Peer`'s own addresses unchecked, the standard library's). Decided by §8.4. No sentence is proposed.

### Family 21. The shell as a program like another

**The sentence that exists.** None in the report; CLAUDE.md's *Shims*: the shell's work is written in Ernest, `foreign` only what the host alone can do, a missing function is a gap to fill. The report has the consequences, E.21's `Process.live`, `info` and `faults`, E.16's `subscribe` answering `Left(NotATerminal)`, E.17's `Entry.user` and E.23's `Os.user`.

**Entries.** *Where `foreign` Stops*; *The Live Processes Are a Library Function*; *Every Fault Is Delivered to Whoever Subscribes*; *A Subscription Says Whether It Has Keys*; *The Path Rule Has One Owner* (one exception, the compiler's own rule asked of the compiler); *What Erlang Held, Moved* (`:output` through `Fs.append`); *The Hardening Built* (a startup file's owner through a `foreign fn` of the shell's, then `Fs.Entry.user` and `Os.user`, item 23); *The Node's Directory* (`ern config` and the directory stay Erlang, "a JSON library in Ernest is written when Ernest code first meets JSON"); *The Module Json* (it did, the same week, for a test's `ernest.conf`).

**Does the rule decide?** It is CLAUDE.md's and decides each, by moving a door into the library where a program might want what the shell wanted. It is a rule of the project and not of the language, which is right: the report cannot say in what language the shell is written. No sentence is proposed; the one entry it leaves open is in Part 2 (L50).

### Family 22. Names

**The sentence that exists.** `docs/style.md`'s rules and glossary; §4.2 for a file of two words; E.0 shape rule 2 for a verb.

**Entries.** *Names Are the First Documentation*; *The Glossary Drafted*; *The Erlang Read and Renamed*, *The Erlang Read Again*, *The Ernest Read and Renamed*, *The Ernest Read Again*, *Three Names Decided*, *The Renamings Kept Whole*, *The Sweep Takes the Form Too*; *The Report's and the Guide's Blocks Read*; *The Path Built* (`namespace` for the AST's prefix, `route` for a derived compare's indexes); *MVP 3.0's Findings Decided* P9 (`Peer.nodes` becomes `Peer.peers`, §8.3's words). Decided by `style.md`, the report's word where the report names a concept. No sentence is proposed.

### Family 23. The project's method

Reviews, plans, measurements and the documents' shape: *A Review Before Each Release*, *Coherence Apart From the Release*, *Enough Coherence*, *A Lean Review*, *A Full Review Now and Then*, *A Full Review Runs at the User's Word*, *The Release Review* and its four follow-ups, *The Principles Review*, *The Attack Plan*, *A Release After the Review*, *The Release Review Before 0.2.0*, *0.3.0* and *0.3.1*, *The Full Review Run*, *The Full Review's Questions*, *MVP 2.99c Weighed Before It Starts*, *The Language Argued Before Peers*, *The Report in Three Files*, *The Examples Are for a Reader*, *The Manual Pages Teach*, *The Guide Staged for Its Reader*, *The Report's Feedback, Three Points*, *A Release Carries No History*, *The Release Has a README of Its Own*, *The Logo Installed, and the Reviews' Models*, *The Three Proposals Reviewed Before Anything Is Built*, *The Coordinator's Section of the Report*, *The Deploy Is MVP 3.2*, *The Milestones After 3.0, Weighed Again*, *The Guide in Two Files*, *MVP 3.0 Read Without a Release*, *The Plan Rewritten from the Split Proposals*, *Nodes a Failed Test Left Running*, *The Tests Wait on What They Mean*, *A Program's Own Test of Two Nodes*. These cite no principle and need none: they decide how the work is done and where a sentence lives, and CLAUDE.md owns them. One exception is substantive and principle-based: *The Milestones After 3.0, Weighed Again* set the operations layer aside by principles 1 and 5, which decide it as written, Erlang's reader expecting a rollout outside the runtime and eight concepts for a few nodes. Its consequences for earlier entries are in Part 2 (L53 to L55).

---

## Part 2. Entries decided on cost, on time, or for now

Each with whether its reason still holds on 2026-10-09. "Superseded" means a later entry replaced the verdict and the reason is moot; "holds" means the reason given still carries the verdict as the report stands.

- **L1.** *Packages* (2026-09-13): the load path "for MVP 1 and MVP 2", content addressing for MVP 3, no package manager ever. Reason: content addressing is coming. Holds in shape, changed in form: MVP 3.0 runs one build per deployment by its fingerprint, and the hash for each definition is MVP 3.1's first item (*The Plan Rewritten from the Split Proposals*); *A Library Is Fetched by Its URL* decided the fetcher on principles. The load path remains the one mechanism, as the entry said it would.
- **L2.** *Remote Ergonomics*: `Task(a)` "rejected for now". Superseded; `remote` went.
- **L3.** *Ambient Sys, Five Principles*: a captured stdout for tests "acceptable now; if this hurts three paper programs, revisit". Superseded by the system modules and `fn start()` beside a service binding.
- **L4.** *Numeric Semantics and Fault Rules*: `Int.mod` kept because a rename "would be a rename affecting Appendix E and paper programs". Superseded: `Int.rem`.
- **L5.** *Four "Partly Resolved" Tails*: cross-node deadlock detection rejected as "machinery cost without a paper-program need". Superseded by a rule: a node detects no deadlock (§8.6), argued from reachability, which holds whatever the cost.
- **L6.** *Equality Policy for Polymorphic Types* and *Annotations Describe Shape*: the constraint kept out of the annotation grammar as a principle-5 cost, "a future addition of constraint syntax is not precluded". Holds under a better reason: §3.9 makes a restriction inferred and never written by principle 2 (*The Reply Discipline Names No Type*), with the one exception a body cannot show, `a=` in a foreign function's parameters.
- **L7.** *Deadlock Is Quiescence*: the reaper looks every hundred milliseconds. Superseded by *The Reaper's Look at Rest*: the look by its cause, measured at 0.3% of a core, and an exact count named as what would follow "if a program's rest is ever what is measured".
- **L8.** *The Message Check Moves to the Point of Exposure*: a hop at 1.5 to 4.6 microseconds refused, the proxy taken. Holds; §8.4 states the proxy and its life.
- **L9.** *Receive Guards Are Guard Expressions*: a buffer and a scan on every `receive` for ever refused. Holds, and §0's host paragraph now decides it without the cost.
- **L10.** *Diagnostics* (2026-09-18): colour "before there is an editor to show it" not taken. Reason changed: the shell colours and `ern build`'s diagnostics stay plain because tools read them (§11.2), a reason stated.
- **L11.** *System Modules*: sockets as processes rather than a shim over `gen_tcp`, "an echo server decides that on a number". Decided by *`Tcp`, Measured*, 1.8 times raw, and kept; the ownership `gen_tcp` hides is now §6.9's stated owner. Holds.
- **L12.** *Shims Where the Runtime Owns the Representation*: `List.sort` a shim for speed. Reversed, then restored under E.0 rule 1's measured line: `sort` closes a stability around the host's sort (E.2). Holds by the rule, not by the entry's reason.
- **L13.** *The Spike: How an Input Sees the Session*: a `persistent_term` write scans the node, "a cost worth remembering rather than acting on". Acted on in *The Hardening Built*: the session became table rows (an input's cost grew with the processes alive), and a binding's holder stayed a persistent term by the numbers. Holds as decided there.
- **L14.** *The Shell's Smaller Rules*: the atom and module tables grow with a session, "a property rather than a defect". Superseded by *An Input's Number Is Given Again*, *Atoms, Counted* and *The Shell's Code Memory*: the growth was a defect and was fixed at its cause.
- **L15.** *OTP 29, and Why the Terminal Stays Ours*: "the terminal handling stays ours for now". Decided by *The Terminal Module, and `io_ansi` Measured Again*: `io_ansi` does not fit. Holds.
- **L16.** *The Terminal Module*: a resize noticed by asking five times a second, "a wake-up every 200 ms in one system process". Superseded by *No OTP in the Toolchain*: a signal handler, the rule read past its reason.
- **L17.** *Two Panes, Painted by the Shell*: a pane keeps a thousand lines. Superseded by the live region.
- **L18.** *Documentation Is Shown as CommonMark*: unrendered until a renderer exists. Overturned the same day by *`libs/markdown`, Written at Once*.
- **L19.** *Libraries As They Are Wanted*: the libraries deferred since "the language is still moving" and a library written now is code every later decision must carry. Holds, and CLAUDE.md states it; `json`, `load` and `balancer` were written as MVP 3.0 wanted them.
- **L20.** *The Web Server Waits for Its Library*: `web_server.ern` keeps a hand-written HTTP subset as a stand-in, "writing `libs/http` now would pull a milestone". Holds as a dated gap, now MVP 3.4's; the example still carries a published protocol by hand, which the rule against a specification in a program names, with the header that says it waits.
- **L21.** *A Supervisor Is Told by Its Own Children*: a notice rather than a subscription to `Process.faults`, whose cost grows with supervisors times faults. Holds.
- **L22.** *An Input's Number Is Given Again*: the lexer's atoms kept by principle 5, "what would change it is a program that compiles code it makes at run time, which peers in MVP 3.0 might make". MVP 3.0 compiles nothing at run time, one build per node; MVP 3.2's code with a spawn, the bare node and `Code.load` will. Holds until then; the condition names the wrong milestone now.
- **L23.** *The Shell's Code Memory*: the host's lambda entries kept, "MVP 3.0 checks the receiving side against it". MVP 3.0 ships no code, so no check was needed and none is recorded; the check belongs to MVP 3.2 and no entry says so. Holds; the pointer is stale.
- **L24.** *The Build's First Group*: a wrapper trapping the interrupt weighed and left "for output that is usually written already". Decided for good by *A signal in the host's first moments* (MVP 2.99b's Questions): no forwarding launcher, the window the host's and stated. Holds.
- **L25.** *A Signal Ends a Job*: the host's window of 0.05 to 0.2 seconds, a launcher "weighed in MVP 2.99". Decided as L24; §8.6 states the window and the fix is OTP's (`docs/otp_bugs.md`). Holds.
- **L26.** *One Run Under Load*: three runs under load cut to one, three quarters of an hour to twenty minutes, giving up "a race rare enough to miss one run". Holds; the races found since came from removed sleeps (*The Tests Wait on What They Mean*), not from load.
- **L27.** *No Mac for the First Release*: "no Mac is to be had". Holds, still: launchd's checks are written and have not run (*The Service Manager's Checks*, *The Release Review Before 0.3.1*); the README says macOS is expected to work and not verified.
- **L28.** *A Lean Review*: the review cut to three readers for a day's cost. Revised by *A Full Review Now and Then* and *A Full Review Runs at the User's Word*: both kinds stand, the full one at the user's word since it costs a day of readers and a milestone of work. Holds.
- **L29.** *What `Fs` Holds*, a file read in parts: a file as a process refused in part as "a concept no program here has asked for", `readRange` taken. Holds on principles 3 and 5, which the entry also cites; the count clause was not restated in phase 6.
- **L30.** *The Code's Cheap Lines*: the helper wakes every 50 milliseconds once a program has closed its outputs, a signal pipe refused as "a second way the helper learns of an exit". Superseded by *MVP 2.99d's First Measurements*: woken by `SIGCHLD` through a pipe, 52 to 2.1 milliseconds. The reason did not hold against the measurement.
- **L31.** *Make Runs `ern build` Every Time*: 5 seconds for a `make` with nothing to do, accepted for one rule (principle 2). Holds.
- **L32.** *The Reaper's Look at Rest*: the look by its cause over an exact count, "the least that needs less". Holds, with its condition.
- **L33.** *The Shell's Second Round*: four parts to MVP 3.3, three of which "may be taken sooner". Holds; the shell as a node arrived with MVP 3.0 in part (`ern shell --config-dir`), and `:trace`, the kill ring and completion by type wait.
- **L34.** *Enough Coherence*: the grammar's generated programs "wait for MVP 3.9 with the other generators". Superseded: built in MVP 2.99c (*The Grammar Generated Against*).
- **L35.** *The First Release Is for Others*: the argument, the typed generator and the laws "are MVP 3.9's". Superseded: built in MVP 2.99c (*The Language Argued Before Peers*).
- **L36.** *A Result Is Annotated With `:`*: the respelling "follows the first release rather than holding it". Superseded by *The First Release Follows MVP 2.99*: it came before.
- **L37.** *The Release Review's Questions*, R-1, R-2 and C1-4: `Io.show` through a type variable, a foreign function's variable and `Foreign.from` left as they were "until then", the release shipping with the behaviour stated. Superseded: *A Value Shows Itself at a Known Type* and *The Boundary Trusts a Type Variable* decided each for good.
- **L38.** *The Release Review's Questions*, R-23: the inferred restrictions' marks "decided in MVP 2.99b's item 4". Decided by *The Reply Discipline Names No Type* and *The Process-Only Mark*. Moot.
- **L39.** *The Release Review's Questions*, R-27: the built-in operators as shims "not before the tag". Built and reverted the same day (*The Operators Stay Ernest*). Moot.
- **L40.** *One Archive, Compiled Where It Is Installed*: "whether `ern build` should write `Dbgi` into a user's module at all is the compiler's question, which the review weighs". No later entry decides it; the installed tree is stripped and a user's build is not. Open, with no owner named.
- **L41.** *What Erlang Held, Moved*: `:output` through `Fs.append` at 113 microseconds a line kept, "what would change the verdict is a program whose output at `:output` outruns that". Holds.
- **L42.** *The Full Review's Questions*, C81: §5.1's left-to-right order of a call's arguments rests on the host compiler's order, which its manual leaves open; binding each argument "would cost every call and the emitted code's reading", so a test pins the host's order. Holds while the test passes; it is a rule of the report kept by a behaviour the host does not promise, a case §0's host paragraph does not name, and the one place where a host upgrade could falsify a sentence of §5 with the toolchain's tests the only guard.
- **L43.** *The Full Review's Questions*, S13: no compiled launcher, which would keep `PWD`, "a second program to build and install for one variable"; §11 states the exception. Holds.
- **L44.** *The Full Review's Questions*, S16: `Fs.readUnder` and `writeUnder` wait "when a program serving files from a root others can write is written", the helper per call costing a millisecond against a read of tens of microseconds. Holds as cost; the deferral is shaped by a program's asking, which principle 5's sentence says decides nothing, and *Later* states the condition in those terms.
- **L45.** *The Full Review's Questions*, S9: no function makes a file with a mode, since the helper's cost "`makeFile` itself may not pay"; the race-free way with what `Fs` has is stated. Holds; *Later* names what would change it, a program's need.
- **L46.** *The Hardening Built*: a binding's holder stays a persistent term, recommended kept by the numbers and decided the same day. Holds.
- **L47.** *OTP's Compiler, Worked Around*: a module the host's validator refuses is compiled again with the type pass off, that module alone, until the host stops refusing the shape, when its test fails and it goes. For now; holds, and it is the one workaround of a host defect the log records as built, against CLAUDE.md's rule, with its date and its exit stated.
- **L48.** *The Service Manager's Checks* and *The Boundary Trusts a Type Variable*: the launchd agent written and not run, "which the user runs". Holds, as L27.
- **L49.** *A Binding of a Previous Version Is Forgotten*: the shell forgets a binding whose type a reload changed, in place of MVP 3.1's identity by hash, "not an afternoon"; the refusal names MVP 3.1. For now; holds, and its price is stated.
- **L50.** *The Node's Directory*: `ern config` and the directory's reading stay Erlang, since "a JSON library and a library for X.509" were missing and the format should have one owner. Half gone: `libs/json` exists since *The Module Json*, five days later; X.509 is still the host's. The one-owner reason holds; the missing-library reason, which CLAUDE.md says is a gap to fill and then write in Ernest, holds for X.509 alone.
- **L51.** *The Node's Directory*: the launcher boots the host twice for a node, a second boot accepted over parsing options in `sh` or a carrier of Ernest's own. Holds.
- **L52.** *The Module Peer*: `NotLoaded` by module "lasts one milestone", per declaration needing a table and a walk "where MVP 3.1's hashes make the rule exact for nothing more"; `Refused` stays though nothing answers it. For now; holds, and the rule shaped `Load`, `Balancer` and the tests meanwhile (*A test is a binding*).
- **L53.** *The Coordinator's Section of the Report*: `ern deploy`, `ern stop`, `ern status` and `ern state` to a section after §11.8. Superseded by *The Milestones After 3.0, Weighed Again*, which set the coordinator aside; `ern stop` alone came, in §11.2. The entry carries no superseded mark.
- **L54.** *The Deploy Is MVP 3.2, and the Milestones After It Renumbered*: superseded by *The Milestones After 3.0* and *The Plan Rewritten from the Split Proposals*, which gave 3.2 another subject; no mark on the entry.
- **L55.** *The Guide in Two Files*: `guide/deployment.md` "written with MVP 3.1 and 3.2", for a configuration directory whole, a reload, code by its hash, and "MVP 3.2's drain, coordinator and ordered rolling restart". The last three went with the operations layer; the file's subject is smaller than the entry says, and no entry says so.
- **L56.** *The Tests Wait on What They Mean*: the polls kept, each with its reason, the flush every millisecond, `ern_tty`'s two seconds, `ern_tcp`'s closer once a second, the load harness's 100 milliseconds. Hold as stated; the closer's second serves E.18's five seconds "at a fifth of them", a chosen fraction.
- **L57.** *A Peer's Down Has No Site*: a monitor of Ernest's own refused on the cost rule. Holds; §6.9 states the departure.
- **L58.** *The Prelude Measured*: `spawnMonitored` at 7 times and a `monitor` of an ended process at 15.6 times the host's "nothing of these is changed before the user decides". *Spawn Keeps Its Wait* decided `spawn`'s and `monitor`'s wait; the two ratios stand without a verdict, and the report has no line to measure them against (Family 2).
- **L59.** *Kept Only for Speed, Taken Out* and *Path.<> Is Split Then Join*: `Path.<>` at 2.4 times `filename:join` kept as plain code, "past the prelude's line, which yields here to the code reading as its rule". Holds under E.0 rule 1's three-times line; the "prelude's line" of 2 is CLAUDE.md's "a fraction", which the report does not state (Family 2).
- **L60.** *Spawn Keeps Its Wait*: `spawn` at 3.4 times the host's kept, measured as the back-pressure, 0.74 seconds against 52 without it. Holds.
- **L61.** *A Release Carries No History* and *The Release Has a README of Its Own*: installing is said in two documents no test holds equal, accepted. Holds.
- **L62.** *A closed socket lets go within a bound* (The Full Review's Questions, S1, C108): the host's 5 seconds and a 3-minute end the host lacks, "decided with the user", no principle cited. Holds; E.18 states both numbers, and §6.9's owner sentence is the rule it is an instance of (Family 7).
- **L63.** *The Release Review's Wrong Results*: `String.drop` a private primitive "decided with the user over those numbers", 51 milliseconds against 2.6 seconds. Holds under rule 1's measured exception.

---

## Part 3. Alike cases decided differently

- **L64.** *The Error of Input and Output* against *MVP 3.0's Findings Decided*, P5. The first made one error type for `Fs`, `Tcp` and `Terminal`, `Io.Error`, because E.0 shape rule 8 promises `Left(Timeout)` as one constructor and a block's `<-` takes one error type, so that a function reading a file and writing a socket converts nothing. The second gave `Peer` its own `Failure`, with its own `Timeout` and `Refused`, since its failures "name what a node answers, which `Other(text)` would hide", and "that `Timeout` and `Refused` recur is a likeness of words, not of types". Each reason refutes the other: `Tcp` too has failures `Other(text)` hides, which *The Failure Family's Rules* answered by adding constructors to `Io.Error` rather than a type, and a block that reads a file and then finds a peer now converts one error into the other, the ceremony the first entry refused. One of the two reasons should decide both.
- **L65.** *A Program's Command Line Is `Os`'s* against *The Silence Family's Rules*. The first made `Os.arguments` and `Os.environment` values, "fixed for a run, so they are values, not processes", and an argument that is not UTF-8 refuses the run while a variable that is not UTF-8 is left out. The second made `Os.environment` a function of a name, so that a value that is not UTF-8 faults its asker, while `arguments`, `workingDirectory` and `user` stay values bound at start. Alike facts of a run, two shapes; the reason given, where a fault should land, is stated in §8.2 and decides it, but no sentence says when a fact of a run is a value and when a function, and the next such fact, a node's `measures` or the host's mask, is argued from scratch.
- **L66.** *Placing Work Without `Where`* against *Load and Balancer*. The first recommended that the library spawn, `Balancer.spawn(measure, f)`, so that "the branch is written once, inside the library, and no node type exists", and refused a node type `Here | Named(String)` as a second way beside `spawn(f)`; it said MVP 3.0 decides it. The second built `Place = Here | On(String)` and has the program branch at every pick, "with `spawn` for `Here` and with `Peer.spawn` for `On(name)`" (G.5), the shape the first entry said a caller would have to write; "their shape agreed with the user before they were built", and no entry records the argument that reversed the recommendation or why the second way the first refused is not one. The reversal is sound, since `Place` is a library's type and `spawn(f)` stays the one local spawn, but it is undecided in the log.
- **L67.** *No Remote Computation in the Language* against *Load and Balancer*. The first admitted `Peer.nodes` and `Peer.runQueue` to the standard library "by E.0's first admission rule" and made the policy over them a library; the second placed `Load.runQueue`, `schedulers`, `cpu`, `memory` and `disk` in `libs/load`, with the rule-1 argument unchanged and no reason for the library given (Family 4).
- **L68.** *A Peer's Down Has No Site, and Peer Comes First* against *Calls Across Nodes*. Both add or refuse a frame of the runtime's for information the host's operation does not carry across nodes. The first refuses a frame answering with a dead process's site as "a message to an operation the host makes without one", which the cost rule refuses. The second adds a note frame to every call to another node's process, and has a restart read the gateway, "the restart on a node costs that one exchange more", so that a request that faults its callee ends its call (§6.9). The reasons differ in what the frame buys, a log line against a rule of §6.6, and that is the right line; but the cost rule as CLAUDE.md states it, "an operation Erlang makes without a message makes none in Ernest", would have refused both, and the sentence that admits the note, a frame for a rule of the report, is written nowhere (Family 2).
- **L69.** *A Time Below 0 Is 0* against *No Limit Is `Unlimited`* against *MVP 3.0's Findings Decided*, P7 and K22. A quantity below its floor: a time below 0 is 0; a restart window below 1 is 1, since a window of none would be `Unlimited` written otherwise; a measuring window below 1 was first a fault, "on a reading of §7.4 that it does not hold", then 1 by analogy with the restart window. §7.4 now states the first two, and G.4 the third by analogy; the sentence names "a restart window" where the rule is of every window (Family 1).
- **L70.** *Guards and Bitstring Size Expressions: Pure, No Fault Swallow* against *Receive Guards Are Guard Expressions*. A `match` guard that faults faults the process; a `receive` guard calls nothing and cannot fault. Alike constructs, two rules; §0's host paragraph now makes the second an instance, since the host makes a failing guard false, a silence met by a refusal of the form, and §6.3 states the departure. Decided since 2026-10-01; listed because the two sections still state the two rules apart, and a reader of §5.9 meets the `match` rule without the reason the `receive` rule departs from it.
- **L71.** *`Int.pow` keeps its `Optional`, and `String` its private power* (E31) against *`Char.digitValue` gives a digit's value in a base* (E34), both in *The Full Review's Questions*. Two modules each held a private copy of work a library function does. For the digit ranges the copies were replaced by an admitted function, rule 3; for the power the private copy stays, since calling `Int.pow` "would write a `None` branch that cannot come". Alike cases, opposite verdicts, each argued; the line between them, a copy that avoids an impossible branch stays and one that repeats a definition goes, is drawn in the entries and nowhere in E.0.
- **L72.** *OTP's Compiler, Worked Around* against *A Port Lost While It Starts* and *String Stands on the Host*. Three host defects met in a week. The compiler's is worked around, narrowly, dated to the host's fix; the port's line stands in the plan's gaps until a release of OTP that Ernest requires has the fix, "Ernest adds nothing around it"; the `string` module's unkept page is answered by keeping the searches Ernest's and filing the report. The first departs from the other two and from CLAUDE.md's rule against routing around a defect; the entry says why, a program that would not build otherwise, and that reason, a defect that stops a well-typed program from building at all, is the sentence that would tell the cases apart, and it is not written.
- **L73.** *Backpressure* (2026-09-13) against §6.2 as *The Report Rewritten for Peers* wrote it. The first refused a `send` that blocks on a full mailbox on principle 3, "the block is invisible in the code"; *Back Pressure, Again* kept the mailbox unbounded and made the system's writes wait for their stream, one rule. §6.2 now has a `send` to another node wait "while what waits to be sent to that node exceeds the host's buffer", a blocking send between processes, taken from the host and stated. The waits family's sentence, a write to another party is bounded by its milliseconds, does not reach it, since a `send` takes none; the host paragraph admits it as a rule taken and stated. Decided, and the one place where the report's `send` may wait with no limit and no name saying so, against shape rule 8's own clause that an unbounded wait on another party is named.
- **L74.** *Exhausting Memory Ends the Program* against *A closed socket lets go within a bound*. Both meet a limit the host leaves to the program. For memory, a bound per process was refused as "a policy the library would choose for every program", and the host's end is taken and stated. For a socket's unsent bytes, a bound of 3 minutes the host lacks is added, for every program. The reasons can be told apart, a heap bound would still leave the node to die while the socket bound reclaims one descriptor, but the entries do not tell them apart, and the sentence that would, §6.9's owner paragraph, is cited by neither.
- **L75.** *The Live Processes Are a Library Function* against *`monitor` takes a `Process`* (MVP 2.99b's Questions). The first refused monitoring a `Process` as "a second `monitor`" and "an observation of what one holds no address to"; the second made `monitor` take a `Process`, since §6.5 grants by an address the permission to send and watching needs none. A reversal with its reason; listed since the first entry's two reasons were each answered by a sentence of the report, §6.5's, that stood when the first was written.
- **L76.** *Two Visibilities Are Enough* against *`Char.isAsciiDigit` is restored*. A one-line helper written in two modules, `answered` in `fs.ern` and `tcp.ern`, is kept twice, since E.0 rule 4 refuses it as one call; a two-comparison lambda written eight times is admitted by rule 3. The rules decide both, and the line is rule 4's "one call or a pipe of two"; listed since a reader of the two entries sees a count of copies deciding in one and refused in the other, and the sentence that tells them apart is E.0's, not the entries'.
- **L77.** *The Reader Family's Rules* against *A Record Type That Fits Stays on One Line*. The first restated forty entries so that no neighbour decides; the second, four days later, cites Gleam's formatter as a reader of principle 1 (Family 8). No verdict changes.

---

## In sum

Twenty-three families. Fifteen are decided by a sentence the last review wrote or the report already had, and the entries since 2026-10-01 fit them, the peer rules of §3.11 and §8.7 among them, which came with their sentences. Five lack a deciding sentence and have one proposed above: a program's mistake as fault or value (Family 1, §7.4, the largest, with K22's reversal in a day as its evidence); what Ernest adds to an operation of the host (Family 2, §10 and E.0 rule 1, the rule being CLAUDE.md's today and two prelude ratios standing with no verdict); what the runtime writes unasked (Family 3, §11.2); standard library or library (Family 4, E.0's preamble, with `Load` and `Fs.removeAll` the two verdicts no rule carries); what a job takes from where it is started (Family 5, §11). Three are the project's and not the language's, names, the method and the shell as a program, and need no sentence of the report.

Sixty-three entries decided on cost, time or for now (L1 to L63): twenty-two superseded or moot, thirty-five hold as stated, and six deserve a line: L22 and L23 name MVP 3.0 for a condition MVP 3.2 now owns; L40 (`Dbgi` in a user's module) is open with no owner; L42 keeps §5.1 by a host behaviour its manual leaves open; L50's missing JSON library exists now; L53 to L55 describe a deploy the plan set aside and carry no superseded mark.

Fourteen pairs (L64 to L77). Four need a verdict or a sentence: L64 (`Io.Error` against `Peer.Failure`), L66 (`Place` against the recommendation of *Placing Work Without `Where`*), L67 (`Load` in a library against rule 1), L72 (a host defect worked around against two that were not). The rest are decided with their reasons and are listed so that the reasons are read side by side.

---
