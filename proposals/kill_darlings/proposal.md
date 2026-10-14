# Kill Darlings

*Tentative: under discussion since 2026-10-14, and nothing of it is decided.*

Three darlings of Ernest's type system, each weighed for what it costs against what it buys: the mark on every function that acts (sections 1 to 8), the reply mark `!` (section 9), and the reply's obligation (section 10). Section 11 sets Gleam's answers beside Ernest's, section 12 weighs where many sources are folded into one type, with conversations as a middle design, and section 13 says what building it costs.

## 1. The question

A function type in Ernest marks every function that acts. A function that sends, receives, prints, reads a file or asks for its own address carries `with M`.

The mark does two jobs at once. It says that the function acts, and it names the mailbox of the process the function runs in.

For a function that receives, the two jobs agree. `fn next(a) = receive { 1 -> a }` is `(a) -> a with Int`: it acts, and `Int`s arrive in its mailbox.

For a function that only sends, they come apart. `fn foo(a) = send(a, 1)` is `(Address(Int)) -> Unit with e+`. The function acts, but it never uses its mailbox, so the mailbox is a variable that stands for nothing. What it sends is not after `with` at all: it is in the address, `Address(Int)`.

A reader who knows ML and Erlang predicts `(Address(Int)) -> Unit`. That reader also reads `with` as the messages the function deals with, which for a sender are the ones it sends. Both readings are wrong in Ernest today, and neither ML nor Erlang marks a function that acts.

## 2. What a type must carry

A process that receives must know what can arrive, or its messages are not type-safe. That is the one fact about processes a type system cannot do without: the type of the mailbox, wherever something takes from it.

Everything else is a choice. Ernest's concurrency is safe without it: values are immutable, nothing is shared, and everything that touches the world goes through a process. That holds whatever a function's type says.

## 3. Three designs

1. **Every action marked**, Ernest today. A function that sends, prints or reads a file says so with `with`. A function without the mark is pure: it computes and affects nothing.
2. **The mailbox alone**, proposed here. A function type names a mailbox only where the function's own mailbox is involved. Sending and every other action are ordinary, as in ML and Erlang.
3. **The mailbox as a value**, as Gleam's subjects are. A receiving function takes an `Inbox(M)` parameter, and no type carries an effect. It threads a capability through every receiving function, which Ernest already refused for the standard streams when it made them ambient.

## 4. The proposal

A function type names its process's mailbox where the function's own mailbox is involved, and nowhere else:

- it receives from it, by `receive`;
- it gives out its address, by `self`;
- it asks for a message to be delivered into it through a wrap: `monitor`, `spawnMonitored`, `Clock.alarm`, `Terminal.subscribe`, `Process.faults`, `Os.termination`;
- or it calls a function that does one of these, as today.

Every other action carries no mark: `send`, `spawn`, `kill`, `answer`, `Address.call`, printing, files, sockets and clocks.

The mark is written `receiving M` in place of `with M`. It says what it means: the messages that arrive. `in M` was weighed and set aside, since a reader who knows ML reads `in` as `let ... in`.

```
fn foo(a) = a                                   foo : (a) -> a
fn foo(a) = receive { 1 -> a }                  foo : (a) -> a receiving Int
fn foo(a) = send(a, 1)                          foo : (Address(Int)) -> Unit
fn foo() = Io.println("foo")                    foo : () -> Unit
fn foo(a, b) = receive { 1 -> send(b, 1.0) }    foo : (a!, Address(Float)) -> Unit receiving Int
```

The prelude and the standard library read:

```
self           : () -> Address(m) receiving m
send           : (Address(a), a) -> Unit
spawn          : (() -> Unit receiving n) -> Address(n)
spawnMonitored : (() -> Unit receiving n, (Down) -> m) -> Address(n) receiving m
monitor        : (Process, (Down) -> m) -> Unit receiving m
kill           : (Address(a)) -> Unit
answer         : (Reply(a), a) -> Unit
Address.call   : (Address(m), (Reply(a)) -> m, Int) -> Optional(a)
Io.println     : (String) -> Unit
Clock.alarm    : (Int, (Int) -> m) -> Unit receiving m
List.map       : (List(a), (a) -> b receiving e) -> List(b) receiving e
```

A callback that receives makes its caller receive, so `List.map` and its kind keep a variable. A variable that stands where nothing receives is none, as it is pure today.

The reply restriction, `a!`, stays as it is. It does not depend on effects.

## 5. Weighed against the principles

- **Principle 1.** The reader who knows ML and Erlang predicts this design. Today's mark is the departure that reader trips on.
- **Principle 2.** The mark has one job. `receiving M` is the mailbox and nothing else.
- **Principle 3.** Communication stays visible in the code that does it, where `send` is written. That is the standard Ernest already sets for failure: a function may fault, and its type does not say so.
- **Principle 5.** "A feature costs a program that does not use it nothing: no argument, no word, and no name of it is written there." A sender does not use its mailbox, and under this proposal its type names none. The process-only mark, `+`, leaves most types.

## 6. What it gives up

- A signature no longer shows that a function acts. A library function may print or send without its type saying so, as in ML and Erlang.
- The word pure leaves the language, or comes to mean "receives nothing".
- Guards, members and bitstring sizes are checked today to compute and do nothing more. Under the proposal they still cannot receive, but they may send or print, as an OCaml guard may. A guard that sends is visible in its own code.
- The reply rule for guards rests today on a guard being pure: it can neither answer a reply nor hand one on. It needs another basis, the reply restriction applied to the guard directly.
- A function a peer computes no longer shows in its type whether it acts on the peer.

## 7. The principles themselves

The current design rests less on the five principles than on a premise. Ernest's first sentence speaks of pure functions, and pure means "affects nothing". The proposal keeps the principles and drops the premise.

So the principles may have to change with it, and §0 is read again before the proposal is decided:

- §0's opening, functions with Hindley-Milner types and processes with typed mailboxes, "the only way to affect the world", stays true at run time. The sentence that defines pure goes or changes.
- Principle 3's "visible in the code or in the type" is read as visible where it happens, as failure already is. If that is its meaning, the principle says so.
- A principle may have to state what a type carries, perhaps: a type carries what keeps values and messages safe, and nothing more.
- The project's own description, pure functions and processes with typed mailboxes, changes with it.

Where reading §0 again shows a principle the proposal breaks, the two are weighed against each other there.

## 8. Other systems

- **Erlang and Elixir.** No mark. Guards are limited to a fixed set of built-in functions, which is how Erlang keeps them free of effects.
- **SML, OCaml and F#.** No mark. A `when` guard may do anything.
- **Akka Typed.** An actor's `Behavior[T]` is the type of what it receives. It sends through an `ActorRef[U]` that its own type does not mention. That is this proposal's split exactly.
- **Gleam.** No mark. A process receives through a `Subject(msg)` value, design 3.
- **Haskell.** Every action is in `IO`, which lazy evaluation needs.
- **Koka and Unison.** Effects are the organizing idea, as rows and as abilities.

## 9. A second darling: `!`

The reply restriction prints as `!`. It falls on a type variable whose value a function uses twice or not at all, since a `Reply` is answered exactly once (§6.6). So it falls on every generic function that ignores or copies a value: 89 of the standard library's 517 signatures carry it.

```
List.size(list : List(a!)) : Int
List.isEmpty(list : List(a!)) : Bool
Either.isLeft(either : Either(e!, a!)) : Bool
Io.show(value : a!) : String needs a.show
```

A reader of `List.size` asks what the mark is, and it says only that a list of replies has no size. The mark is a cost of the same kind as `with e`: a word on many signatures for a concern their readers seldom have. Elsewhere `!` reads as strictness, in Haskell, or as the type with no values, in Rust.

One way out keeps the rule and stops printing the mark. The checker still refuses a reply used twice or not at all, and its error says why where a reply is involved. That trades principle 3's visibility in the type for a fifth of the library's signatures without the mark.

Whether the rule itself is worth its cost, the static check that a reply is answered exactly once, is section 10's question. If the rule goes, the mark goes with it, and this section's question with it.

## 10. A third darling: the reply's obligation

**What Ernest does today.** A `Reply(a)` is answered exactly once on every path (§6.6). The checker follows each reply through blocks, `match`, guards, `let`s and functions, and refuses one used twice or not at all. It infers the not-reply-carrying restriction, `!`, on every type variable that could hold one. Across nodes, a reply that a failed spawn held is ended for its caller (§8.7).

**What the rule buys.** It has two halves.

"At most once" buys nothing. The runtime lets go of a call's identity once the call returns, so a second or late answer is dropped and never reaches the caller's mailbox.

"At least once" catches a forgotten answer when the program is compiled. That half is the one that spreads `!`. Ernest has no borrowing, so a function that looks at a value without using it, `List.size` on a list of replies, drops it as surely as one that forgets it.

**The proposal.** The obligation goes, and everything else stays:

- `Reply(a)` stays an abstract type of the prelude. A message type with a `Reply(Int)` field still says that its sender waits, and for an `Int`. A server holding one can answer it and do nothing else: not send to it, monitor it or kill it.
- `answer : (Reply(a), a) -> Unit` stays a primitive of the prelude. Only the runtime reaches the call's identity, and `send` cannot.
- `Address.call` and `Address.callForever` stay as they are, and so do their rules at run time: the deadline, `None` or a fault where the callee ends before it answers (§6.6), and a late or second answer dropped.
- The not-reply-carrying restriction goes, and with it `!` and §6.6's rules for where a reply may stand.

**The common case is short.** A constructor is a function, so a request whose only field is the reply is written with the constructor's name:

```ernest
type CounterMsg = Inc(Int) | Get(Reply(Int))

match Address.call(counter, Get, 1000) {
    Some(total) -> Io.println("total " <> Int.toString(total))
  | None -> Io.println("no answer")
}
```

A lambda is needed only for a request that carries more than its reply: `fn(reply) = Add(5, reply)`. The guide teaches the constructor's form first.

**What a forgotten answer becomes.** `Address.call` returns `None` at its deadline. `Address.callForever` faults where the callee ends, as today, but a callee that lives on without answering holds its caller for as long as it lives. That is the one silent failure the proposal adds. It is stated where `callForever` is: a program that cannot bound its wait accepts it, as Erlang's `infinity` timeout does.

**What it means.**

- §6.6 keeps what a call does and loses its obligation rules.
- §3.9's three inferred restrictions become two, §11.5's `!` goes, and section 9's question goes with it.
- 89 signatures of the standard library lose `!`. `List.size` works on a list of replies.
- A server keeps pending replies in its state, in a list or a map, and answers each when it can.
- The checker loses its analysis of replies, and the soundness argument its part on them.

**Weighed against the principles.**

- **Principle 5.** A rule of the language goes, one of three inferred restrictions with it, and a mark on a fifth of the library.
- **Principle 3** cuts both ways. "A rule the type decides is checked when the program is compiled", and "answered once" is a rule a type can decide. But "one the value decides is a value, a message, or a fault when it runs" covers a forgotten answer just as well: `None` at the deadline, or a fault where the callee ends. `callForever`'s wait while the callee lives is the exception, and it is stated.
- **Principle 1.** The Erlang reader predicts it: `gen_server:call` and `gen_server:reply`, which nothing checks.
- **Principle 2.** `answer` and `send` stay two names for two jobs: answering a call, and messaging a process.

**Other systems.**

- **Erlang.** `handle_call` returns the reply, so the common case cannot forget it. A deferred reply goes through `gen_server:reply(From, Reply)`, which nothing checks. Every call has a timeout, five seconds unless `infinity` is given.
- **Akka Typed.** Its ask makes a temporary `ActorRef` and takes a timeout, and nothing checks that the actor answers.
- **Session types and Rust's moves.** They check such an obligation when the program is compiled, at the price Ernest pays today.

## 11. Beside Gleam

Gleam runs on the same host and answers the same questions. Set side by side, the questions this proposal touches come apart into five:

1. **Marking a function that acts.** Gleam marks none: its `send` is `fn(Subject(a), a) -> Nil`. Design 2 takes this answer.
2. **The reply's obligation.** Gleam's `process.call` builds the request around a fresh subject for the answer, as `Address.call` builds it around a fresh `Reply`, and nothing checks that the answer comes. Section 10 takes this answer.
3. **One mailbox or many subjects.** Here the two differ by choice.
   - Gleam: a process owns any number of typed `Subject`s, and waits on several at once through a selector, which maps each into one type. A receiving function needs the subject in hand, as a parameter or in its state, and the type system does not say which process owns one.
   - Ernest: a process has one mailbox of one type. `receive` needs nothing in hand, and the process's whole protocol is one type, `with CounterMsg`, or `receiving CounterMsg` under design 2. Every source is folded into that type when it is sent, by an adapted address or a wrap.

   Both fold many sources into one type before a receive, as Hindley-Milner needs one: Gleam where it receives, Ernest where it sends. Ernest keeps its answer.
4. **Moving what a process receives.** Neither does. A Gleam subject sent to another process lets that process send to it, never receive from it. In both, a backlog moves as a value: drained from the mailbox into a list by a selective receive, sent in one message, and the senders told the new address or finding it by a service's name.
5. **A channel that fills while it is passed around.** Neither has one. It would be mutable state, and both keep a process's incoming messages inside the process.

So the proposal takes Gleam's answers where Gleam is simpler, the first two, and keeps Ernest's where the two differ by choice, the third.

## 12. Conversations: where to fold

A receive needs one type, so many sources are folded into one, either where a message is sent or where it is received. Ernest folds where it is sent, and Gleam where it is received.

**Folding where it is sent, as Ernest does.** Every source makes the receiver's one mailbox type: directly, through a wrap, or through an adapted address.

- For: a process's protocol is one type, readable in one place; `receive` needs nothing in hand; one queue keeps the order of arrival; one address serves every input, across nodes and as a service; a wrong type is refused where the message is made.
- Against: receiving code does not compose, since a function that receives is tied to its caller's mailbox type, and `gathered` in the guide's §8.1 works only in a process whose mailbox is `GatherMsg`; every kind of input becomes a constructor of that type; a call's answer is not in it, which is why `Reply` exists; and naming the one mailbox is why `with m` stands on every function that acts.

**Folding where it is received, as Gleam does.** Every conversation has a typed subject of its own, and a selector maps several into one type at the receive.

- For: receiving code composes, since a library opens its own subject and receives on it whatever the caller's types; a reply is an ordinary subject; no type carries an effect.
- Against: what a process accepts is spread over the subjects it owns; a subject is carried in hand; the type system does not say which process owns one; messages for a subject nobody selects stay in the mailbox.

**The middle design: conversations.** A process keeps one public protocol and folds its conversations where it receives them.

- A conversation is a typed inbox a process opens, holds and receives from. Its address travels anywhere, and the conversation never leaves its process.
- The mailbox is the process's first conversation, opened at its spawn, `self()` its address. A clause of `receive` names the conversation it reads, and reads the mailbox where it names none (**The select** below).
- `Reply(a)` is a conversation of one answer. `Address.call` opens one, puts its address in the request, receives one answer and closes it, and a late answer is dropped, as it is today.

Ernest gains a concept and loses one: `Reply` becomes a case of `Conversation`. Receiving code composes, so `gathered` becomes a library function that opens its own conversation of its own private type, and works in any process. The helper process a function needs today to wait on something of its own mostly goes.

**`adapted` stays** as the one way to fold a type into another, for any target: `adapted(self(), Ended)` into the mailbox, `adapted(address(c), Ended)` into a conversation.

**Wraps are the open question.** `monitor(p, Ended)` and `adapted(self(), Ended)` do one fold two ways today, and a wrap, `(Down) -> m`, can only deliver into the caller's mailbox. If every function that delivers later takes an `Address(T)` instead, `monitor`, `Clock.alarm`, `Terminal.subscribe`, `Process.faults` and `Os.termination` among them, the fold has one way and a conversation can receive them:

```ernest
monitor(child, adapted(self(), Ended))     // into the mailbox, today's monitor(child, Ended)
monitor(child, address(downs))             // into a conversation
```

The common case grows by `adapted(self(), …)`. An address also lets a monitor deliver to a third process, which Erlang does not, and that is weighed on its own.

**The select.** On the host a conversation is no queue of its own but a tag, a fresh reference, on messages in the process's one host mailbox, as Erlang's aliases are, and a receive on it is a selective receive on the tag. So every conversation and the mailbox share one queue in arrival order, and a receive over several is one host receive matching several tags: the earliest arrival wins, and no rule of fairness is needed. The syntax is a clause that names its source, the mailbox being the source a clause does not name:

```ernest
receive {
    results: Computed(piece) -> …
  | results: Ended(down) -> …
  | Lookup(key = key, reply = reply) -> …
  | after 1000 -> …
}
```

That form covers one conversation, several and the mailbox, so `receive c { … }` is not needed and there is one `receive`. It costs the grammar an optional `ident ":"` before a clause's pattern; the checker types each clause against its source, the named `Conversation(t)` or the mailbox, and unifies the results as it does now; the emitter writes one host receive whose patterns carry each source's tag. A clause that names a conversation another process holds is refused by the check that a conversation stays in its process; one that names a closed conversation never matches, which is stated.

**The proxy stays.** `libs/proxy` (Appendix G.7) is a process that keeps one address for a service across its end and its return. A conversation is the receiving side inside a process, so it does not remove the proxy's hop. It makes the proxy simpler inside: the service's messages arrive in its mailbox, and its finds and the service's `Down` in a conversation of their own, so it needs no message type beyond the service's. The hop itself is a different question, whether an address can follow a process that moves.

**What it costs.**

- A conversation must stay in its process. One captured by a lambda and spawned on the same node would let another process receive on it. That needs a check that it is bound to its process, as §3.11 checks a spawn on a peer, at every spawn.
- A process that waits on its mailbox and a conversation at once, a server that serves while a call of its own is out, wants a select. It is rarer than in Gleam, since a library folds its own sources into its conversation's one type with `adapted`, but it is not never. The select is below.

**Weighed against the principles.**

- **Principle 2.** One concept, the conversation, where there are two today, the mailbox and `Reply`. If wraps go, one fold where there are two.
- **Principle 3.** A process's public protocol stays one type, and a conversation is a value in the code that holds it.
- **Principle 5.** The count stays, with `Conversation` in place of `Reply`, and falls by the wrap if wraps go.
- **Principle 1.** Erlang's aliases and Gleam's subjects are the reader's precedent.

**Its test.** It holds only if five programs read well under it, written before it is decided: `gathered` as a library; a server that answers some calls after others; a supervisor; a call made from inside a server; and the proxy. The first two, and the fourth inside the second, are under [`programs/`](programs/), `gather.ern` and `cache.ern`, written as the design would have them and compiled by nothing. What they do not show is a server that serves its mailbox while a call of its own is out, the select left open above.

## 13. What it costs to build

It is no complete rework. The parser, the Hindley-Milner core, most of the emitter, the runtime's processes, nodes and exchange of code, the shell, and the logic of the standard library and the libraries stay. What changes is the type system's layer of effects, the processes' interface, and a large part of the documents. The figures were measured on 2026-10-14 and are rough.

| Part | What changes | Size | Risk |
|---|---|---|---|
| The reply's obligation goes (section 10) | Mostly deletion: `ern_reply.erl`, 520 lines, about 28 places in the checker, the not-reply-carrying restriction and its `!`. §6.6, 1,330 words, keeps a call's rules at run time; §3.9, §11.5 and the soundness argument lose their parts on replies; the rejected programs and the catalog of diagnostics change with them. | a few days | low |
| `!` printed or not (section 9) | Nothing, once the obligation goes. | none | none |
| The mailbox alone, `receiving` for `with` (sections 1 to 8) | The checker: a send or an action no longer sets an effect, and only `receive`, `self` and a wrap do; effect variables and subsumption stay, and most of process-only goes. The word: the lexer, the parser, the formatter, the printer and the Emacs mode. Every Ernest source: about 1,670 lines that write `with`, across the standard library, the libraries, the shell, the examples and the tests, mostly by rote, the compiler naming the rest. The report's §0, §3.9, §4.5, §6.1, §9.4, §9.5, every signature of Appendix E, §11.5 and Appendix A's token; the guide's chapters 2 to 4. | one to two weeks | medium, mostly a sweep |
| Conversations (section 12) | The runtime: an inbox for each conversation, a receive on it and its close, and `Reply` made a conversation of one answer. The checker: `Conversation(T)`, and at every spawn the check that a conversation stays in its process, on the analysis of captures that a spawn on a peer already has. The syntax: a clause's source. If wraps go, every function that delivers later and every use of one. The proxy, rewritten. The report's §6.3 and §6.6, and the guide's chapters 4 and 5, rewritten. | three to four weeks, after its five programs | higher: new semantics |

Every definition's hash changes, since Appendix H's forms hold types and effects. That costs nothing between releases, since each release stands on its own floor.

**The order.**

1. The reply's obligation first. It is deletion, depends on nothing else, and makes the type system smaller at once.
2. The mailbox alone next. It is the largest sweep, of a kind already known.
3. Conversations last, and only once their five programs read well.

The first two together are about one milestone, the size of MVP 3.2's four weeks; conversations are one of their own. All of it lands best after 0.4.0 and before the tour, MVP 3.3, which teaches processes and would otherwise be written twice.

## 14. Before deciding

1. Read the signatures of the standard library, the shell, the examples and the libraries under the proposal: how many lose their mark, and how many keep it.
2. Find what purity checking has caught: a guard, a `compare`, a size expression or a library function that acted where it should not have. The tests' rejected programs and the log are the places to look.
3. Write two programs under both designs and read them side by side: a server with a supervisor, and a burst of computes gathered.
4. Settle the reply rule for guards on its new basis, and check the soundness argument for effects against it.
5. Read §0 again, as section 7 says.
6. Decide whether `!` is printed, as section 9 says, unless section 10 takes it away.
7. Find what the obligation check has caught: the rejected programs under `test/` and the log's entries on replies.
8. Write a server that holds pending replies, under both designs, and read the two side by side.
9. Decide whether §8.7's held replies stay. They end a call whose reply a failed spawn took, and they rest on a reply's type, not on the obligation.
10. Write section 12's five programs under conversations, and decide whether wraps go.
