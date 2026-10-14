# Kill Darlings

*Tentative: under discussion since 2026-10-14, and nothing of it is decided.*

Three changes to the type system, each weighed for what it costs against what it buys, in the order they would be built: the reply's obligation goes (section 2); the mark on every function that acts goes, and `with` becomes `receiving` (section 3); and a process receives on conversations beside its mailbox (section 4). Section 5 reads §0 against them, section 6 says what building them costs, and section 7 what to find out first.

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

**Other systems.** Erlang, Elixir, SML, OCaml and F# mark nothing; Erlang keeps its guards free of effects by a fixed list of allowed functions. Akka Typed's `Behavior[T]` is the type of what an actor receives, and it sends through an `ActorRef[U]` its own type does not mention: this change's split exactly. Gleam marks nothing, and receives through `Subject` values (section 4). Haskell puts every action in `IO`, which lazy evaluation needs; Koka and Unison make effects their organizing idea.

## 4. Conversations

**Where to fold.** A receive needs one type, so many sources are folded into one, where a message is sent or where it is received. Ernest folds where it is sent: every source makes the receiver's one mailbox type, directly, through a wrap, or through an adapted address. For it: a process's protocol is one type, readable in one place; `receive` needs nothing in hand; one queue keeps the order of arrival; one address serves every input. Against it: receiving code does not compose, since a function that receives is tied to its caller's mailbox type, so `gathered` in the guide's §8.1 works only in a process whose mailbox is `GatherMsg`, and a library that waits on something of its own spawns a helper process; every kind of input becomes a constructor of the one type; and a call's answer is not in it, which is why `Reply` exists.

Gleam folds where it is received: each conversation has a typed `Subject` of its own, and a selector maps several into one type at the receive. For it: receiving code composes, and a reply is an ordinary subject. Against it: what a process accepts is spread over the subjects it owns, a subject is carried in hand, and the type system does not say which process owns one.

**The change.** A process keeps one public protocol, its mailbox, and folds its own conversations where it receives them:

- A *conversation* is a typed inbox a process opens, holds and receives from. Its address travels anywhere; the conversation never leaves its process.
- The mailbox is the process's first conversation, opened at its spawn, `self()` its address.
- A clause of `receive` names the conversation it reads, and reads the mailbox where it names none. That one form covers one conversation, several and the mailbox, and a `receive` whose clauses all name conversations gives its function no `receiving`.
- `Reply(a)` is a conversation of one answer: `Address.call` opens one, puts its address in the request, receives one answer and closes it.
- `adapted` stays the one way to fold a type into another, into the mailbox or into a conversation: `adapted(address(c), Ended)`.

```ernest
receive {
    results: Computed(piece) -> …
  | results: Ended(down) -> …
  | Lookup(key = key, reply = reply) -> …
  | after 1000 -> …
}
```

On the host a conversation is a tag, a fresh reference, on messages in the process's one host mailbox, as Erlang's aliases are, and a receive on several is one selective receive matching several tags: every source shares one queue in arrival order, and no rule of fairness is needed. It costs the grammar an optional `ident ":"` before a clause's pattern; the checker types each clause against its source and unifies the results as now; the emitter writes one host receive. A conversation must stay in its process, so a spawn that captures one is refused, on the analysis of captures a spawn on a peer already has; a clause that names a closed conversation never matches, which is stated.

Ernest gains a concept and loses one, `Reply` becoming a case of `Conversation`. `gathered` becomes a library function that opens a conversation of its own private type and works in any process; the helper process mostly goes.

**Wraps are the open question.** `monitor(p, Ended)` and `adapted(self(), Ended)` do one fold two ways today, and a wrap can only deliver into the caller's mailbox. If every function that delivers later takes an `Address(T)` instead, `monitor`, `Clock.alarm`, `Terminal.subscribe`, `Process.faults` and `Os.termination` among them, the fold has one way and a conversation can receive them, at the cost of `adapted(self(), Ended)` in the common case, and a monitor that can deliver to a third process, which Erlang's cannot.

**The proxy stays.** A conversation is the receiving side inside a process; `libs/proxy` (Appendix G.7) keeps one address for a service that moves, and its hop stays. Its inside grows simpler: the service's messages in its mailbox, its finds and the service's `Down` in a conversation of their own.

**The principles.** Principle 2: one concept where there are two, the mailbox and `Reply`, and one fold where there are two if wraps go. Principle 3: the public protocol stays one type, and a conversation is a value in the code that holds it. Principle 5: the count stays, and falls by the wrap if wraps go. Principle 1: Erlang's aliases and Gleam's subjects are the precedent.

**Its test.** It holds only if five programs read well under it: `gathered` as a library; a server that answers some calls after others; a supervisor; a call from inside a server; and the proxy. The first two, and the fourth inside the second, are under [`programs/`](programs/), written as the design would have them and compiled by nothing.

## 5. The principles read again

Today's design rests less on the five principles than on a premise: Ernest's first sentence speaks of pure functions, and pure means "affects nothing". Sections 2 to 4 keep the principles and drop the premise, so §0 is read again before any of them is decided:

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
| Conversations (section 4) | The runtime: an inbox for each conversation, its receive and its close, `Reply` made one. The checker: `Conversation(T)` and the check at every spawn. The grammar: a clause's source. If wraps go, every function that delivers later and every use of one. The proxy rewritten; the report's §6.3 and §6.6 and the guide's chapters 4 and 5 rewritten. | three to four weeks, after its programs | higher: new semantics |

Every definition's hash changes, since Appendix H's forms hold types and effects, which costs nothing between releases. The first two together are about one milestone, the size of MVP 3.2's four weeks; conversations one of their own. All of it lands best after 0.4.0 and before the tour, MVP 3.3, which teaches processes and would otherwise be written twice.

## 7. Before deciding

1. Find what the obligation check and purity checking have caught: the rejected programs under `test/` and the log's entries on replies, guards and members.
2. Write a server that holds pending replies, a server with a supervisor and a burst of computes gathered under today's design and under sections 2 and 3, and read them side by side.
3. Read the standard library's, the shell's and the examples' signatures under section 3: how many lose their mark, and how many keep it.
4. Settle the reply rule for guards on its new basis, and check the soundness argument for effects against it.
5. Decide whether §8.7's held replies stay: they end a call whose reply a failed spawn took, and rest on a reply's type, not on the obligation.
6. Write section 4's five programs, and decide whether wraps go.
7. Read §0 again, as section 5 says.
