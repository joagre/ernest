# Kill Darlings

*Tentative: under discussion since 2026-10-14, and nothing of it is decided.*

Three changes to the type system, each weighed for what it costs against what it buys, in the order they would be built: the reply's obligation goes (section 2); the mark on every function that acts goes, and `with` becomes `receiving` (section 3); and receiving kept composing across a process, as it does today (section 4). Section 5 reads §0 against them, section 6 says what building them costs, and section 7 what to find out first.

## 1. What a type must carry

A process that receives must know what can arrive, or its messages are not type-safe. That is the one fact about processes a type system cannot do without: the type of what is received, wherever something receives.

Everything else is a choice. Ernest's concurrency is safe without it: values are immutable, nothing is shared, and everything that touches the world goes through a process. That holds whatever a function's type says.

## 2. The reply's obligation goes

**Today.** A `Reply(a)` is answered exactly once on every path (§6.6). The checker follows each reply through blocks, `match`, guards, `let`s and functions, refuses one used twice or not at all, and infers the not-reply-carrying restriction on every type variable that could hold one, printed `!`. Across nodes, a reply a failed spawn held is ended for its caller (§8.7).

**What the rule buys.** "At most once" buys nothing: the runtime lets go of a call's identity once the call returns, so a second or late answer is dropped. "At least once" catches a forgotten answer when the program is compiled. That half spreads `!`: Ernest has no borrowing, so `List.size` on a list of replies drops them as surely as a server that forgets one, and 89 of the standard library's 517 signatures carry the mark, `List.size(list : List(a!)) : Int` among them, for a concern their readers seldom have.

**The change.** The obligation goes, and everything else stays:

- `Reply(a)` stays an abstract type of the prelude. A message type with a `Reply(Int)` field still says that its sender waits, and for an `Int`, and a server holding one can answer it and do nothing else.
- `answer : (Reply(a), a) -> Unit` stays a primitive. Only the runtime reaches the call's identity; `send` cannot.
- `Address.call` and `Address.callForever` stay, and so do their rules at run time: the deadline, `None` or a fault where the callee ends before it answers, a late or second answer dropped.
- The not-reply-carrying restriction goes, with `!` and §6.6's rules for where a reply may stand. A server keeps pending replies in a list or a map and answers each when it can.

A constructor is a function, so the common case is the constructor's name, and a lambda is needed only for a request that carries more than its reply, `fn(reply) = Add(amount = 5, reply = reply)`:

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

A callback that receives makes its caller receive, so `List.map` and its kind keep an effect variable; one that stands where nothing receives is none. Effect variables and subsumption stay; the process-only mark `+` leaves most types.

**What it gives up.** A signature no longer shows that a function acts: a library function may print or send without its type saying so, as in ML and Erlang. The word pure goes, or comes to mean "receives nothing". Guards, members and bitstring sizes still cannot receive, but may send or print, as an OCaml guard may; a guard that does so is visible in its own code. A function a peer computes no longer shows whether it acts on the peer.

**The principles.** Principle 1: the ML and Erlang reader predicts this, and today's mark is the departure that reader trips on. Principle 2: the mark has one job. Principle 3: communication stays visible where `send` is written, the standard Ernest already sets for failure, which a type never shows. Principle 5: "a feature costs a program that does not use it nothing: no argument, no word, and no name of it is written there"; a sender does not use its mailbox, and its type names none.

**Other systems.** Erlang, Elixir, SML, OCaml and F# mark nothing; Erlang keeps its guards free of effects by a fixed list of allowed functions. Akka Typed's `Behavior[T]` is the type of what an actor receives, and it sends through an `ActorRef[U]` its own type does not mention: this change's split exactly. Gleam marks nothing, and receives through `Subject` values a process owns, folded into one type at the receive by a selector; Ernest folds them where they are sent, by an adapted address or a wrap, and keeps a process's protocol one type. Haskell puts every action in `IO`, which lazy evaluation needs; Koka and Unison make effects their organizing idea.

## 4. Receiving composes across a process

A function that receives is tied to its caller's mailbox type, so a library cannot wait on messages of its own inside the calling process: `gathered` in the guide's §8.1 works only where the mailbox is `GatherMsg`. Ernest's answer is already there. The library's receiving runs in a process of its own, and the caller gets the result by a call, which leaves the caller's mailbox untouched. That is Erlang's `gen_server` idiom, and it costs one spawn and one call. [`programs/gather_today.ern`](programs/gather_today.ern) is `gathered` written so, under today's language, thirty lines, and `main_today.ern` runs it.

A design that lets a process receive on typed *conversations* beside its mailbox, each a tag on the host's one queue as Erlang's aliases are, `Reply` one of them, and a clause of `receive` naming its source, was weighed and set aside. It would add a concept, a check at every spawn that a conversation stays in its process, and a form of `receive`, to do inside a process what a process and a call already do; principle 5 decides, and principle 2 agrees. What would change it is a program that a process and a call cannot write well, found while writing the tour.

## 5. The principles read again

Today's design rests less on the five principles than on a premise: Ernest's first sentence speaks of pure functions, and pure means "affects nothing". Sections 2 and 3 keep the principles and drop the premise, so §0 is read again before any of them is decided:

- §0's opening, processes "the only way to affect the world", stays true at run time; the sentence that defines pure goes or changes, and the project's own description with it.
- Principle 3's "visible in the code or in the type" is read as visible where it happens, as failure already is. If that is its meaning, the principle says so.
- A principle may have to say what a type carries: what keeps values and messages safe, and nothing more (section 1).

Where reading §0 again shows a principle a change breaks, the two are weighed against each other there.

## 6. What it costs to build

No complete rework. The parser, the Hindley-Milner core, most of the emitter, the runtime's processes, nodes and exchange of code, the shell, and the logic of the libraries stay. What changes is the type system's layer of effects, the processes' interface, and a large part of the documents. Measured on 2026-10-14, roughly:

| Change | What changes | Size | Risk |
|---|---|---|---|
| The reply's obligation (section 2) | Mostly deletion: `ern_reply.erl`, 520 lines, about 28 places in the checker, the restriction and its `!`. §6.6 keeps a call's rules at run time; §3.9, §11.5 and the soundness argument lose their parts on replies; the rejected programs and the catalog of diagnostics change with them. | a few days | low |
| The mark on every action (section 3) | The checker: an action no longer sets an effect, and only `receive`, `self` and a wrap do. The word: lexer, parser, formatter, printer, Emacs mode. Every Ernest source: about 1,670 lines that write `with`, mostly by rote, the compiler naming the rest. The report's §0, §3.9, §4.5, §6.1, §9.4, §9.5, every signature of Appendix E, §11.5, Appendix A's token; the guide's chapters 2 to 4. | one to two weeks | medium, mostly a sweep |

Every definition's hash changes, since Appendix H's forms hold types and effects, which costs nothing between releases. The two together are about one milestone, the size of MVP 3.2's four weeks, and land best after 0.4.0 and before the tour, MVP 3.3, which teaches processes and would otherwise be written twice.

## 7. Before deciding

1. Find what the obligation check and purity checking have caught: the rejected programs under `test/` and the log's entries on replies, guards and members.
2. Write a server that holds pending replies, a server with a supervisor and a burst of computes gathered under today's design and under sections 2 and 3, and read them side by side.
3. Read the standard library's, the shell's and the examples' signatures under section 3: how many lose their mark, and how many keep it.
4. Settle the reply rule for guards on its new basis, and check the soundness argument for effects against it.
5. Decide whether §8.7's held replies stay: they end a call whose reply a failed spawn took, and rest on a reply's type, not on the obligation.
6. Read §0 again, as section 5 says.
