# Kill Darlings

*Decided with the user on 2026-10-14, sections 2 and 3 and section 4's library; built as MVP 3.26 (the plan) before 0.4.0's tag, by the log's *Kill Darlings*. This is the record of its design and does not change again; the report owns the rules once built.*

Three changes to the type system, each weighed for what it costs against what it buys, in the order they would be built: the reply's obligation goes (section 2); the mark on every function that acts goes, and `with` becomes `receiving` (section 3); and receiving kept composing across a process, as it does today (section 4). Section 5 reads §0 against them, section 6 says what building them costs, section 7 what the guide teaches, and section 8 what to find out first.

## 1. What a type must carry

A process that receives must know what can arrive, or its messages are not type-safe. That is the one fact about processes a type system cannot do without: the type of what is received, wherever something receives.

Everything else is a choice. Ernest's concurrency is safe without it: values are immutable, nothing is shared, and everything that touches the world goes through a process. That holds whatever a function's type says.

## 2. The reply's obligation goes

**Today.** A `Reply(a)` is answered exactly once on every path (§6.6). The checker follows each reply through blocks, `match`, guards, `let`s and functions, refuses one used twice or not at all, and infers the not-reply-carrying restriction on every type variable that could hold one, printed `!`. Across nodes, a reply a failed spawn held is ended for its caller (§8.7).

**What the rule buys.** "At most once" buys nothing: the runtime lets go of a call's identity once the call returns, so a second or late answer is dropped. "At least once" catches a forgotten answer when the program is compiled. That half spreads `!`: Ernest has no borrowing, so `List.size` on a list of replies drops them as surely as a server that forgets one, and 111 of the standard library's 359 functions and bindings carry the mark, and 8 of the libraries' 28, `List.size(list : List(a!)) : Int` among them, for a concern their readers seldom have. The record holds no program in which the check caught a mistake of anyone's, and seventeen defects of the check itself ([`findings.md`](findings.md), item 1).

**The change.** The obligation goes, and everything else stays:

- `Reply(a)` stays an abstract type of the prelude. A message type with a `Reply(Int)` field still says that its sender waits, and for an `Int`, and a server holding one can answer it and do nothing else.
- `answer : (Reply(a), a) -> Unit` stays a primitive. Only the runtime reaches the call's identity; `send` cannot.
- `Address.call` and `Address.callForever` stay, and so do their rules at run time: the deadline, `None` or a fault where the callee ends before it answers, a late or second answer dropped.
- The not-reply-carrying restriction goes, with `!` and §6.6's rules for where a reply may stand. A server keeps pending replies in a list or a map and answers each when it can.

A constructor is a function, so where the request's one field is positional the common case is the constructor's name, today already, and a lambda is needed only for a request that carries more than its reply, `fn(reply) = Add(amount = 5, reply = reply)`, or whose field is named:

```ernest
type CounterMsg = Inc(Int) | Get(Reply(Int))

match Address.call(counter, Get, 1000) {
    Some(total) -> Io.println("total " <> Int.toString(total))
  | None -> Io.println("no answer")
}
```

**What a forgotten answer becomes.** `None` at `Address.call`'s deadline. `Address.callForever` faults where the callee ends, as today, but a callee that lives on without answering holds its caller for as long as it lives: the one silent failure the change adds, stated where `callForever` is, as Erlang's `infinity` timeout is.

**The principles.** Principle 5: a rule goes, one of three inferred restrictions with it, and a mark on a fifth of the library. Principle 3 cuts both ways: "answered once" is a rule a type can decide, but "one the value decides is a value, a message, or a fault when it runs" covers `None` at the deadline and a fault at the callee's end; `callForever`'s wait is the exception, stated. Principle 1: the Erlang reader predicts `gen_server:call` and `gen_server:reply`, which nothing checks. Principle 2: `answer` and `send` stay two names for two jobs.

**Other systems.** Erlang's `handle_call` returns the reply, so the common case cannot forget it; a deferred `gen_server:reply` is unchecked; every call has a timeout. Akka Typed's ask makes a temporary `ActorRef` with a timeout, unchecked. Gleam's `process.call` builds the request around a fresh subject, as `Address.call` does around a fresh `Reply`, unchecked. Session types and Rust's moves check such an obligation, at the price Ernest pays today.

## 3. The mark on every action goes

**Today.** A function that sends, receives, prints, reads a file or asks for its own address carries `with M`. The mark does two jobs: it says the function acts, and it names the mailbox of the process it runs in. For a function that receives the two agree: `fn next(a) = receive { 1 -> a }` is `(a) -> a with Int`. For one that only sends they come apart: `fn foo(a) = send(a, 1)` is `(Address(Int)) -> Unit with e+`, where `e` names a mailbox the function never uses, and what it sends is in the address, not after `with`. A reader who knows ML and Erlang predicts `(Address(Int)) -> Unit`, and reads `with` as the messages the function deals with. Both readings are wrong today.

**The change.** A function type names its process's mailbox where the function's own mailbox is involved, and nowhere else: it receives from it, gives out its address by `self`, asks for a message to be delivered into it, or calls a function that does one of these. Every other action carries no mark: `send`, `spawn`, `kill`, `answer`, `Address.call`, printing, files, sockets and clocks. The mark is written `receiving M`, which says what it means; `in M` was set aside, since the ML reader reads `in` as `let ... in`.

```
fn foo(a) = a                                   foo : (a) -> a
fn foo(a) = receive { 1 -> a }                  foo : (a) -> a receiving Int
fn foo(a) = send(a, 1)                          foo : (Address(Int)) -> Unit
fn foo() = Io.println("foo")                    foo : () -> Unit
fn foo(a, b) = receive { 1 -> send(b, 1.0) }    foo : (a, Address(Float)) -> Unit receiving Int

self           : () -> Address(m) receiving m
send           : (Address(a), a) -> Unit
spawn          : (() -> Unit receiving n) -> Address(n)
monitor        : (Process, (Down) -> m) -> Unit receiving m
Address.call   : (Address(m), (Reply(a)) -> m, Int) -> Optional(a)
Io.println     : (String) -> Unit
List.map       : (List(a), (a) -> b receiving e) -> List(b) receiving e
```

A callback that receives makes its caller receive, so `List.map` and its kind keep an effect variable; one that stands where nothing receives is none. Effect variables and subsumption stay. Of the standard library's 135 marked functions, 58 lose the mark and 77 keep `receiving`: 9 receive themselves, 56 through a callback, 7 in a parameter's or result's type, and 5 only because they call `self()` for the caller's identity, `Tcp.listen`, `Tcp.accept`, `Tcp.connect`, `Os.start` and `Os.run` ([`findings.md`](findings.md), item 3). For those five, and `Proxy.start`, `Process.current : () -> Process` enters E.21, the host's own identity of the running process by rule 1, so that a function that needs its identity and not its mailbox names none; `self` stays for the address.

**What the restriction keeps.** Today a top-level `let` "whose initializer calls a process-only function" is not generalized (§3.9, §4.6), and that is what keeps `let shared = spawn(fn() = cell(None))` from a type `Address(CellMsg(a))` at which a `String` is put and an `Int` read. With no action setting an effect, that sentence catches nothing, so §4.6 takes ML's value restriction instead: a top-level `let` generalizes only where its initializer is a value, a literal, a name, a lambda, or a constructor applied to values; one whose initializer is a call has the type the call gives, determined or refused as §4.6 refuses an undetermined type today. The reader who knows ML predicts it. Eight top-level `let`s in the repository's Ernest call a function, each of a determined type.

The process-only restriction survives in one place: a `receive` with an `after` clause alone waits on its mailbox, and its function's `receiving m`, `m` in no value position, is never none, so that a guard cannot wait. It is printed `+` there and nowhere else. `restarting` and `Supervisor.child` need it no longer: a function that receives nothing may restart. §3.11's `Code.running(f)` asks of `f` a result type `Unit receiving m`; it asks `Unit` alone, since a worker that only sends has no mark.

The record holds no program in which purity checking caught a mistake of anyone's, and eight defects of the effect checker ([`findings.md`](findings.md), item 1).

**What it gives up.** A signature no longer shows that a function acts: a library function may print or send without its type saying so, as in ML and Erlang. The word pure goes: a function without `receiving` receives nothing, and is called nothing else. Guards, members and bitstring sizes still cannot receive, but may send or print, as an OCaml guard may; a guard that does so is visible in its own code. A function a peer computes no longer shows whether it acts on the peer.

**What stays sound.** The one claim section 1 keeps is argued on its own: every message a `receive` matches is of its process's mailbox type. An address to a process is made by `self`, whose type is the function's own `receiving m`, or by `spawn`, whose `Address(n)` is the started function's `receiving n`, or by `adapted`, which maps into one of these; `send` checks its value against the address; a wrap's result unifies with the mailbox of the function that asks for it; and a call of a function `receiving M` unifies `M` with the caller's. Each of these holds today and none of them names an action, so none changes. The guards' reply rule, that a guard can neither answer a reply nor hand one on, kept the obligation sound in guards, and goes with the obligation: a guard may call `answer` as it may call `send`, and a second answer is dropped as any is.

**The principles.** Principle 1: the ML and Erlang reader predicts this, and today's mark is the departure that reader trips on. Principle 2: the mark has one job. Principle 3: communication stays visible where `send` is written, the standard Ernest already sets for failure, which a type never shows. Principle 5: "a feature costs a program that does not use it nothing: no argument, no word, and no name of it is written there"; a sender does not use its mailbox, and its type names none.

**Other systems.** Erlang, Elixir, SML, OCaml and F# mark nothing; Erlang keeps its guards free of effects by a fixed list of allowed functions. Akka Typed's `Behavior[T]` is the type of what an actor receives, and it sends through an `ActorRef[U]` its own type does not mention: this change's split exactly. Gleam marks nothing, and receives through `Subject` values a process owns, folded into one type at the receive by a selector; Ernest folds them where they are sent, by an adapted address or a wrap, and keeps a process's protocol one type. Haskell puts every action in `IO`, which lazy evaluation needs; Koka and Unison make effects their organizing idea.

## 4. Receiving composes across a process

A function that receives is tied to its caller's mailbox type, so a library cannot wait on messages of its own inside the calling process: `gathered` in the guide's §8.1 works only where the mailbox is `GatherMsg`. Ernest's answer is already there. The library's receiving runs in a process of its own, and the caller gets the result by a call, which leaves the caller's mailbox untouched. That is Erlang's `gen_server` idiom, and it costs one spawn and one call. [`programs/gather_today.ern`](programs/gather_today.ern) is `gathered` written so, under today's language, thirty lines, and `main_today.ern` runs it. The report changes nothing for it, since it uses only what the report states; what the guide teaches is section 7's.

A design that lets a process receive on typed *conversations* beside its mailbox, each a tag on the host's one queue as Erlang's aliases are, `Reply` one of them, and a clause of `receive` naming its source, was weighed and set aside. It would add a concept, a check at every spawn that a conversation stays in its process, and a form of `receive`, to do inside a process what a process and a call already do; principle 5 decides, and principle 2 agrees. What would change it is a program that a process and a call cannot write well, found while writing the tour.

What the set-aside design was for, moving a backlog of messages to another process, is a library of two functions over today's language, under `libs/` by E.0 and not in Appendix E: `drained(keep)`, every message of the caller's mailbox that `keep` says, taken in arrival order by a selective receive with `after 0`, and `refilled(messages)`, which puts them into the caller's own mailbox behind what it holds. A channel is then a `List(m)`, a value sent anywhere. It moves what has arrived, never what will arrive; redirecting the senders is the program's protocol. The tour's rolling upgrade, MVP 3.3, is the program that needs it, and it is written there, named for its subject, `Mailbox`: `Channel` would name an object the library does not have, since the value is a list and the subject is the caller's mailbox.

## 5. The principles read again

Today's design rests less on the five principles than on a premise: Ernest's first sentence speaks of pure functions, and pure means "affects nothing". Sections 2 and 3 keep the principles and drop the premise, so §0 is read again before any of them is decided:

- §0's opening, processes "the only way to affect the world", stays true at run time; the sentence that defines pure goes or changes, and the project's own description with it.
- Principle 3's "visible in the code or in the type" is read as visible where it happens, as failure already is. If that is its meaning, the principle says so.
- A principle may have to say what a type carries: what keeps values and messages safe, and nothing more (section 1).

Where reading §0 again shows a principle a change breaks, the two are weighed against each other there. The reading is `docs/principles_review.md`'s, which reads §0 against what it decided.

## 6. What it costs to build

No complete rework. The parser, the Hindley-Milner core, most of the emitter, the runtime's processes, nodes and exchange of code, the shell, and the logic of the libraries stay. What changes is the type system's layer of effects, the processes' interface, and a large part of the documents. Measured on 2026-10-14, roughly:

| Change | What changes | Size | Risk |
|---|---|---|---|
| The reply's obligation (section 2) | Mostly deletion: `ern_reply.erl`, 520 lines, about 28 places in the checker, the restriction and its `!`. §6.6 keeps a call's rules at run time; §3.9, §11.5 and the soundness argument lose their parts on replies; the rejected programs and the catalog of diagnostics change with them. | a few days | low |
| The mark on every action (section 3) | The checker: an action no longer sets an effect, and only `receive`, `self` and a wrap do. The word: lexer, parser, formatter, printer, Emacs mode. Every Ernest source: about 1,670 lines that write `with`, mostly by rote, the compiler naming the rest. The report's §0, §3.9, §3.11, §4.5, §4.6, §6.1, §9.4, §9.5, every signature of Appendix E, E.21 and E.28, §11.5, Appendix A's token; the guide, as section 7 says. | one to two weeks | medium, mostly a sweep |

Every definition's hash changes, since Appendix H's forms hold types and effects, which costs nothing between releases. The two together are about one milestone, the size of MVP 3.2's four weeks.

**When.** Before the 0.4.0 tag, as a milestone of its own after MVP 3.2's nine items, which reopens the decision of 2026-10-13 that nothing more goes into 0.4.0. A release that is for others should not ship a mark the next release removes: 0.4.0's man pages, README and notes would otherwise document `with m+` and `a!`, every 0.4.0 program would break at 0.5.0 on each `with` line, and the tour, MVP 3.3, would teach processes twice. The tag slips about three weeks. The five speed changes before the tag run meanwhile, by agents, since they touch `ern doc`, the Makefile and the reading of `.erc`s and not the checker.

**How each is built**, as CLAUDE.md has it: the report first, its revision date and the soundness paragraph of each rule changed in the same commit; then the log; then the code, by an agent from the settled report text; then `make test-full`. Beyond the table, each change touches: `docs/soundness.md`, where the one claim section 1 keeps, that a message received is of the mailbox's type, is argued as a paragraph of its own and not left as what remains; `docs/style.md`'s glossary and Appendix F, where *obligation*, *pure function* and *process-only* go or change and *receiving* enters; `test/diagnostics.md`, written again by `make diagnostics`; the Emacs mode's keywords; the guide, as section 7 says; and `man/`, written again at the release. Programs under `proposals/` that the tests run are swept with the sources.

## 7. The guide

The guide changes with the report, section by section, and the language guide alone: the deployment guide teaches no type.

**For section 2.** The guide's §4.2, *A reply is answered once*, is rewritten under a new title, *A reply*: a `Reply` in a message type says its sender waits and for what, `answer` is the one thing a server does with it, and a reply is a value a server keeps until it can answer, in a list as anywhere else. The guide's counter declares `Get(Reply(Int))`, positional, in its seven declarations, so that the guide's §4.4 teaches `Address.call(counter, Get, 1000)` first and the lambda after it for a request that carries more. The queue example stays, its sentence "each reply is answered once on every path" going. `callForever`'s paragraph gains the one sentence that a callee that lives on without answering holds its caller. The guide's §0's *A request left unanswered* compiles and goes, and *Checked replies* leaves *What Ernest adds*; the guide's §2.9's *Marks in a printed type* loses `a!`; the guide's §6.7's exercise (b), a reply dropped, goes, and the guide's §4.8's (b), a reply answered twice, compiles and is asked otherwise, with their answers in the guide's §13.

**For section 3.** The guide's §0's first example, `send : (Address(a), a) -> Unit with m+`, is shown without its mark, *Work through a process, in a function that says it does none* goes, *Purity in the type* leaves *What Ernest adds*, and "a pure function says so in its type" goes: a function that receives names what it receives, `receiving Int`, and one that only sends names nothing, as in ML and Erlang, said once where `with` is first met. `README.md`'s lines of *What Ernest adds* change with the guide's, which `what_ernest_adds_test` holds equal. The guide's §1.1's "one that only sends, such as `Io.println`, is written `with m`" goes, and its paragraph on `with Never`; the guide's §1.4's prediction (b) flips. The guide's §2.2 lists `receiving` among the reserved words; the guide's §2.6's "a guard is a pure `Bool` expression", the guide's §2.9's *Pure where the result depends on the arguments alone* and the `m+` half of *Marks in a printed type* go; the guide's §3.3 states the value restriction in place of the process-only rule for a top-level `let`; the guide's §3.4, *Pure functions and functions with a mailbox effect*, becomes *Functions that receive*; the guide's §3.5 keeps effect polymorphism for callbacks that receive and loses *Process-only* and the `+` mark but for the timed wait. Every signature the guide prints, four `:type` consoles and five console lines among them, is written again as the shell then prints it, which `make test-guide` holds the guide to, and every `main() : Unit with Never`, 28 of them, loses its mark. [`findings.md`](findings.md), item 6, lists the rest line by line.

**For section 4.** A passage in the guide's §4.4, after `Address.call` and the queue, *A library that waits*: a function that must wait on messages of its own, from whatever process calls it, is a process and a call, with `gather_today.ern` as `gather.ern` beside a `collect.ern` that runs it, written and checked by `make test-guide` on 2026-10-14 and kept as [`guide_passage.md`](guide_passage.md), and three sentences after the console: the library's message type stays private, `Collect` stands as the function that builds the request, and `gather` ends on what it waits for and needs no deadline. The guide's §8.1's *Many at once* then says it is the guide's §4.4's `gathered` with a compute as each helper's work, and keeps its burst. This passage does not wait on sections 2 and 3: it is written once the proposal is decided either way, and loses only `with m` on `gathered` and `with e` on `f` under section 3.

Each chapter's prediction exercises are read again for a prediction the changes alter, the guide's §1.4's, §3.7's and §4.8's first.

## 8. Before deciding

Items 1, 2, 3 and 6 of the first list are read: [`findings.md`](findings.md), with the three programs under both designs beside it in [`programs/`](programs/). What is left:

1. Decide whether §8.7's held replies stay: they end a call whose reply a failed spawn took, and rest on a reply's type, not on the obligation.
2. Read §0 again, as section 5 says.
3. Decide the three rules section 3 adds from the findings: the value restriction for a top-level `let`, `Process.current`, and the timed wait as the one place process-only survives.
4. Before the sweep, read the guide's chapters 0 to 4 against section 7 and findings item 6, so that nothing it teaches is taught twice or against the new rule.
