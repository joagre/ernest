# Ernest: Decision Log

The reasoning behind the language report in `ernest.md`: what was taken from Unison and Erlang, what was tried and rejected, what is deferred, and what is undecided. The report says what holds; this document says why. The language was called Actorson until 12 September 2026.

## Starting Point

Erlang has the right concurrency model but is old in everything else: dynamically typed, no abstract data types, OTP turns the program inside out. Unison has the right language core (types, minimal syntax) but the wrong concurrency layer: a Haskell inheritance of threads, MVar, TVar, STM, and Promise that overlap one another and lack identity and address.

The goal is a language that is minimal in concepts, not in primitives: few things to understand, each orthogonal, nothing that is a special case of something else.

## Kept from Unison

- Hindley-Milner with inference. Signatures optional.
- Parametric polymorphism, sum types, product types.
- Pattern matching with exhaustiveness checking.
- The type distinguishes pure code from process code.
- Structural equality and serialization over all data values. Functions have no equality: `f == g` is a type error, not false. `Address` has none either, since `via(f, a)` is an address with a function inside; identity is part of the protocol, an id in the message or in the `monitor` wrapper.
- Tail calls are guaranteed. Every process loop is a tail call; the last expression of a block, a `match` arm, and a `recv` arm is in tail position. A runtime without the guarantee cannot run the language.
- Evaluation order: strict, left to right, arguments before the call.
- Recursive types, mutually recursive types and functions, type constructors with parameters. No polymorphic recursion; that is HM.

## Dropped from Unison

- IO, Threads, STM, TVar, MVar, Promise, Remote. Replaced by Proc.
- Exception. See Errors in the report.
- Abilities as a mechanism: user-defined effects, handlers, row-polymorphic effect sets. With a single context there is nothing to generalize over.
- Type classes. Equality is structural; ordering is a function per type.
- Universal ordering across type boundaries (Erlang's term order, Unison's `Universal.<`). Ordering exists per type in its namespace, `Nat.compare`, `Text.compare`, `Money.compare`, and `<` is resolved like `+`. Functions that need an ordering take it as an argument: `List.sort(xs, Nat.compare)`. `Map(k, v)` is built on a structural hash of the key and needs only equality.
- Rank-n types, existential types.
- Documentation and test types; those are tooling questions.
- Content addressing and the codebase as a database. Text files and names; see Namespaces in the report and Later below.
- UCM. One command suffices.
- Subtyping. See Addresses in the report.
- Delayed computations (`'`, `!`, `do`). A lambda from `()` does the same.
- Records as generated functions (`Peer.dir`, `Peer.dir.set`, `Peer.dir.modify`). See named fields in the report.
- Layout-sensitive syntax.
- Macros.

## Tried and Rejected

- The address as an argument to the process instead of a process context and `self`. Rejected: purity should be visible in the type. Thunks were dropped instead; `spawn` takes a function from `()`.
- `recv` as a function with a filter `msg -> Optional a`, first with a mandatory timeout and `Received a = Timeout | Got a`, then as `recv` and `recvFor`. Rejected: every unbounded wait got a dead `Timeout` arm, five times in two programs, and every selective receive wrote the same match twice, 45 characters each time, the only large cost in the comparison with Erlang. `recv` is a form, like `match`.
- `?` for `Either`. Rejected: it requires an early return from a function, a concept the language otherwise lacks. `<-` in a block is the form without it.
- Exceptions with `catch`. Rejected: control flow not visible in the type, a second error model beside `Either`, and error information that is dynamically typed instead of a sum type. Without `catch`, "throw" is just process death with a cause, and that exists: kind three. Exceptions are simplest for the writer; `Either` for the reader.
- A dying prelude (`Nat.div(n, 0)` kills the process, Erlang's model). Rejected in favor of a total one: a death should be something that happened to the process, never something it did. A choice, not a necessity.
- Go's line-end rule. Rejected: `;` mandatory, no whitespace rule.
- Two variants of partial built-in functions. Rejected: the prelude is total.
- `reply f` as a separate operation for `via f self`. Rejected: a second spelling.
- Records as generated field functions, and positional product types without names. Rejected: the first creates names out of syntax, the second turns positions into invisible information. Named fields in the constructor instead; a constructor with two positional fields (`Ping n from`) survived one day as a "deliberate variant" and was dropped for the same reason.
- Dropping `if then else` as a variant of `match` on `Bool`, Gleam's choice. Rejected after one day: `match n == 0 { true -> | false -> }` surprises more than the variant. That case set the limit in principle two.
- A naming rule instead of a signature on opaque types. Rejected: the signature gives the interface a place; a declaration does not break the expression rule.
- System addresses as global names bound per node. Rejected: it would be the only dynamic binding in the language. `main` receives them as values.
- `contramap` as a name. Rejected: category theory's word; `via`.
- Indentation under the type as ownership marker for opaque types. Rejected: the same rule without a word for the interface and without a place to read it.
- `spawn` taking a state and a step function so that the runtime owns the loop. Rejected: gen_server in a new costume.
- Causal message ordering (Pony). Rejected: costs in the runtime; pairwise ordering as on BEAM.
- `use Net.Http` as a namespace abbreviation. Outside until it hurts; a variant.
- Application by juxtaposition and currying, `f x y`. Rejected: arity is invisible, and `f x` as a value is a surprise to everyone but ML readers. See Syntax Revision 3.
- `try` as the word for the error chain, and propagation to the function boundary. Rejected: early return, and a word that means exceptions.
- The word "effect" for `{Proc(m)}`. Changed to process context: an effect can have handlers, sets, and user definition, and `{Proc(m)}` can do none of that.

The rule that decided most often: no variants. Next: nothing invisible. The rule that stopped it: least surprise, once.

## Syntax Revision 3, 2026-09-12

A separate syntax document with numbered decisions (D1 to D44) was tested against the specification and adopted with three changes. What was taken:

- **D44, D7 to D10.** N-ary functions, `f(x, y)`, no currying and no partial application. Reason: currying makes arity invisible and produces the most confusing error messages in the ML family; `f x y` in a language without partial application is a form that lies. `fn` as a word is the price of parentheses. `let` was taken first (D38: to distinguish generalized `fn` from monomorphic binding) and then dropped: `fn` already marks the function, so `x = e;` cannot be confused, and `let` was four characters per line with no job.
- **D20 to D25.** Types with parentheses, `List(a)`, constructors `Some(x)`, `with { ...; ... }` with the same separator rule as blocks.
- **D32.** `after millis` in the arm instead of `recv millis { }`.
- **D40.** No existential types. This found a hole: `ClockMsg` with `msg : a` where `a` is not a parameter of the type. The clock sends `()`; the receiver writes `via(fn(_) = Tick, self())`.
- **D41.** No `-` on `Nat`; `Nat.sub` returns `Optional`. The tick game paid the price on two lines. Superseded by the grammar audit: `Nat` was dropped altogether.
- **D34, D21, D22, D33, D37, D38, D39.** Already our decisions, in their form.

What was changed:

- **D36 rejected.** `try` propagates to the function boundary: that is early return, the concept that felled `?`, and it leaves `try` inside a lambda undefined. Block semantics kept: `x <- e` rewrites the rest of the block, locally, no exit from the function. The word `try` dropped; it means exceptions in every language but Zig.
- **D43 softened.** Nullary and single-field constructors are values, `List.map(xs, Some)`; they are ordinary polymorphic functions. Named constructors are not (no argument order), operators only when qualified (`Nat.+`).
- **D42 in part.** `Address` gets no equality at all, since `via(f, a) == a` has no right answer; identity is part of the protocol.

After the revision the specification was pared down to rules: explanations, "What does not exist," and the notes on the principles moved here; program termination was defined (Go's rule: the program ends when `main` returns, `Deadlock` when nothing can run). 2,700 words became 2,100.

Remaining verification debt from the document: A1, an EBNF with precedence that tests the lambda's extent (D11), is now Appendix A of the report. A2, transferring the examples, is done.

## Grammar Audit, 2026-09-12

The complete EBNF was read rule by rule for ambiguity. Two real ambiguities, three imprecisions, two gaps; all fixed in the report.

- **`{` had two roles.** Blocks and arm lists, and field construction `Peer { dir = d }`. In `match Peer { ... }` the parser could not tell whose `{` it was, and the fix was a note outside the grammar. Named fields now use parentheses, `Peer(dir = d)`, `Peer(seen = s)` in patterns, `Peer(..p, x = e)` for update, `Peer(dir : Path)` in declarations. One bracket per role: `(` for calls, arguments, tuples, and payloads; `{` for blocks and arm lists; `[` for lists.
- **Signed literals.** `+1` and `-1` as `Int` literals made `a+1` two tokens and `a + 1` three: a whitespace rule in disguise. Fixed by removing `Nat`: one integer type, `Int`, arbitrary precision, literals without sign, `-` as a prefix operator. `Nat` had promised non-negativity in the type and delivered `pred` with 0 as floor in the tick game; one type fewer and one lexer rule fewer. Totality stays where it belongs: `Int.div` and `Int.mod` return `Optional`, and so do `/` and `%`.
- **`recv` could be empty or begin with `|`.** Rewritten so that an empty `recv` cannot be written.
- **`Pattern "+:" Pattern` was left-recursive.** Rewritten right-recursively; the parser is a Pratt loop with one operator, no semantic change.
- **Statements without `let` required re-reading.** `Some(x) = e` against `Some(x) == e`: the parser had to read an expression and reinterpret it as a pattern. `let` returned: the grammar is LL(1) throughout, and "simple to read and simple to parse" outranks four characters per line. The earlier removal weighed the wrong thing.
- **`Name` allowed too much.** `ident { "." ident }` admitted `p.x`, which has no meaning. Now `{ typename "." } ( ident | binop )`: namespace segments are type names, and `Int.+` is grammar rather than a lexer rule.
- **Text literals had no escapes.** Five: `\"`, `\\`, `\n`, `\t`, `\u{...}`. Source is UTF-8, `Text` is code points; graphemes and normalization belong to the library.

- **Division.** Three positions in one day. `/` on `Int` returning `Optional` was consistent with the total prelude and failed least surprise: `a / b` as a `Maybe` is a form that lies. Then "an operator never fails": no `/` on `Int`, `Int.div` returns `Optional`. It lasted an hour: `Int.div(a, b)` in every program is what a language gets laughed at for, and least surprise is the principle that decides, not one derived from it. Final: `/` and `%` on `Int` exist and fault on zero, kind three, `Fault("division by zero")`, the one deliberate exception to "a death is never something the process did," recorded in the report beside the other deliberate exceptions. `Int.div` and `Int.mod` return `Optional` for those who want to handle zero, as Rust's `checked_div`.
- **Block comments.** `/* ... */`, nesting. Lexer only; the grammar and LL(1) are untouched. `/*` wins over `/` by longest match.

Second pass, after the first fixes:

- **`type Bool = false | true`** broke the constructor rule (uppercase). `true` and `false` are literals of `Bool`, reserved; fourteen words. Gleam's `True` lost to every other language's `true`.
- **`type Millis = Int`** was a type alias, and the grammar has none: it parsed as a sum type with a nullary constructor called `Int`. Aliases would be a concept; `Millis` was dropped, `ms : Int`.
- **Qualified references** were missing in `TypeAtom`, `Constr`, and `AtomPat`, and `Name` and `Constr` both began with an uppercase token, so `Primary` was not LL(1). One rule, `Ref = { typename "." } ( ident | binop | conname [ payload ] )`: after each uppercase token, `.` continues, otherwise the segment is final and its case says function or constructor.
- **`Fields` could be empty**, admitting `Peer()` and `Peer(..p)` with a prose note forbidding one of them. Rewritten so neither can be written; a pattern may still omit all fields, `Closure()`.
- **`Signature` took a qualified `Name`**; signatures are unqualified and live in the type's namespace, so `( ident | binop )`, and `+ : (Money, Money) -> Money` declares `Money.+`.

The principles were revised on the same day. Three times in two days a rule that looked clean on paper fell to code (`if`, `let`, division), each time on least surprise, each time after a derived rule had been allowed to outrank it; principle 1 now says "measured in code, not in the rule." And `let` and the bracket decision followed a principle nobody had written: simple to parse. It is principle 5: LL(1), every construct decided by its first token, one role per bracket. Seven principles.

**Pure HM, checked.** Every construct was walked against Algorithm W. Textbook: n-ary arrows, nominal named fields, `fn` generalized and `let` monomorphic, binding groups for mutual recursion, exhaustiveness as a separate pass. Two additions, both closed: a context variable κ on every arrow, generalized when free (pure means callable anywhere, and callbacks run in the caller's context), and one post-inference resolution pass that picks `Int.+`, checks `==`, and chooses `Either.andThen` or `Optional.flatMap` for `<-`. No type classes, no subtyping, no rows, no rank-n. A third addition was looked for and not found.

- **Visibility.** The report first said every top-level declaration is visible program-wide and hiding is by nesting; then the obvious rule appeared: an unqualified top-level name, `fn helper(`, is file-local, a qualified one, `fn Net.Http.parse(`, is program-wide. No `pub`, no export list, visibility in the name (principle 3), and a file gains the one meaning every reader already assumes it has.

What was already clean: mandatory `else` leaves no dangling `else`; the lambda is at `Expr` level and cannot be called without parentheses, so its extent is maximal munch and unambiguous; `|` and `||` are separated by longest match; `.` in names and `.` in floats by digits never beginning a name; `->` occurs only in types and arms, never in the same position. Remaining fragility, not ambiguity: `((Int, Int)) -> Int` against `(Int, Int) -> Int` differs by one parenthesis level; the compiler suggests the other reading on arity errors.

## Distribution, 2026-09-13

The day-two decision, "this is Erlang, where you say which node," was revised into two things, one from each side. A process is placed explicitly: `spawn(Where, f)` with `Where = Local | Peer(name)`, placement visible on the line (principle 3), one function rather than `spawn`, `spawnOn`, `spawnRemote` (principle 2), and `Local` written on every local spawn because running here is a decision too. A remote computation is Unison's: `remote(f)` evaluates a pure `f` on a peer the runtime chooses by load among those configured for it, and returns the value. Three types were tried for `remote` in an hour. First a reply address, `remote(f, reply)`: honest but visible plumbing the developer has no use for. Then `->{Proc(m)}`: the caller waits, so it seemed like process code. Then the observation that every call runs in a process: the context marks use of the process's own mailbox and identity, and `remote` uses neither, so it is pure, `(() -> a) -> Either(RemoteError, a)`, with failure over the boundary in the type. That observation sharpened the definition of the context in section 6, which had been missing. Peers, their names, addresses, keys, and the `remote-peer` flag live in `ernest.conf`, outside the language. Code follows by content hash, MVP 3; peers need not share code. Tools: `ernc` compiles to `.erc`, `ern` runs, as `erl`.

## Toolchain and Guide

The toolchain went into the report as section 11, as a contract rather than a manual: the commands, their arguments, the files they read and write, and nothing about output, exit codes, or the REPL's appearance; it defines what a program is in practice, and section 8's `Sys` and peers need an address. Distributed programming does not go into the report: a report says what holds, and how to build is another genre. It becomes a third document, `ernest-guide.md`, with distributed programming as one chapter beside error handling and process design, written from the paper programs once the compiler runs them.

## FFI, 2026-09-13

The report said "no FFI": foreign code was a process, the boundary was the mailbox. That is pure and consistent, and heavy: every Erlang library would be a message type plus a process, and ETS, which exists to avoid messages, would get them back. Four approaches were weighed. A, foreign processes with hand-written send and receive. B, foreign processes plus an `Address.call` in the prelude, one line per operation, with the runtime short-circuiting to a direct call; correct, and still a process per library. C, foreign pure functions only, `foreign fn` with a purity promise, direct calls, for hashes and math and JSON; not for anything with state. D, Gleam's `@external`: direct calls to anything, the type declared on the Ernest side, the Erlang side trusted. Gleam can do D without lying because it promises nothing about purity; Ernest does.

Taken: D with the context. A `foreign fn` with `->{Proc(m)}` may do anything, and the context says so; a `foreign fn` without context promises purity, kind 3 if it lies. That widens what `{Proc(m)}` means, from "uses its own mailbox and identity" to "acts through its process", which is what an effect marker means everywhere else and the reading the report's readers had anyway; `remote` stays pure, since its result depends on its argument alone. `foreign type` gives handles for pids, references, ports, and table ids: no constructors, identity equality, usable only through foreign functions, Gleam's external types. A prelude type `Foreign` with `Optional`-returning accessors covers data the program cannot type in advance, Gleam's `Dynamic`. The representation of values is fixed as an ABI in the plan; Erlang functions with `{ok, _} | {error, _}` conventions get a wrapper module, as Gleam's stdlib does. The reason for choosing Gleam's road over the process boundary: a language on BEAM gets a library exactly as fast as wrapping an Erlang module is cheap, and Gleam proved it in a year. `Address.call`, request and reply as a function, stays out of the report and goes under Later; it is the idiom every program wrote by hand. An `Ets.ern` shim is Appendix D of the report. Its first version had six lines of Erlang to adapt conventions; the second has none: raw bindings are file-local `foreign fn`s and the library is Ernest over them, because the representation already matches Erlang's, `{ok, V}` being a constructor tagged `ok`. Renaming is the declaration's name, reordering and reshaping are Ernest functions, and Erlang is needed only to catch exceptions into `Either`. What chafed was nothing in the language and one thing outside it: a table's lifetime follows the creating process, which the type cannot say.

## Review, 2026-09-13

Four remarks from a first outside reading, all taken.

- Scientific float notation was missing; `1.0e-9` added to the literal grammar.
- The namespace in a declaration did not have to match the file, which would have forced the loader to index every unit. Now a file's path is its namespace: `Net/Http.ern` holds `Net.Http.*`, possibly deeper, and the loader is a path lookup. Java's and Go's rule; the prefix in the declaration still carries visibility, so it is not redundant with the path.
- "Constructs from head and tail" was vague; `x +: xs` is now defined, and `[a, b]` as `a +: b +: []`.
- The context appeared in section 3 before process, mailbox, and context were defined, and `{Proc(M)}` looked like a set of one. Section 0 now defines the three words in three sentences before types are used, and the syntax is `(A) -> B with M`, `fn counter(n : Int) -> () with CounterMsg`: no braces, no `Proc`, no new word, since there is exactly one kind of context and all it needs to name is the mailbox. `with` gains a second role, after a return type, in a different position from `opaque type ... with { }`. The braces were the last piece of Unison's notation for effect sets, kept for two weeks after the sets were gone.

## MVP Split, 2026-09-13

Exhaustiveness checking moved from MVP 2 to MVP 1: two days, and it is the check that shaped `recv` and `if`; a first user, who will be the author, should not form habits the report forbids. The ownership rule stays in MVP 2. MVP 2 got a budget before MVP 1 starts, about four weeks, with `Float` and type-directed resolution marked as the piece most likely to double.

## The Word, 2026-09-13

The mark on a function type has had four names: effect (Unison's, struck because it promised handlers and sets), process context, context, and now mailbox type. "Context" fell because in type theory a context is Γ, the typing environment, and "the context is inferred" reads to that reader as a sentence about environments; the same collision as "effect", quieter. "Mailbox type" names what is on the page, `M`, and cannot be read as anything else. The rule did not change; only the word.

## Colliding Words, 2026-09-13

Three more words that mean something else to a type-theory reader, found on the same pass as "context". "Kind" (an error of kind 3) is the type of a type; the three errors now have names for what they are, a value, a message, a fault, and "an exception is a fault" replaces a number that pointed at a list. "Reference" (a sequence of uppercase segments) is a pointer, an Erlang `make_ref`, an ML `ref`; it is now a qualified name, `QName` in the grammar. "Unit" (a compiled unit) collided with the unit type `()` two sections earlier; a `.erc` is a compiled file. Checked and kept: signature, prelude, irrefutable, arity, tail position, sum type, all with their standard meanings.

## Patterns, 2026-09-13

The report listed the pattern forms but never said that `let`, `match`, `recv`, and parameters share them, that they nest, or that an identifier in a pattern always binds a new variable. Now said, in one paragraph. One rule was missing outright: a variable at most once per pattern. Erlang's `{X, X}` is an equality test; that is a hidden comparison, and Ernest writes equality in a guard.

## `as`, 2026-09-13

`p as c` binds the whole of what `p` matches. At top level it is a variant of two `let`s; nested, `Some(Peer(dir = d) as peer)`, nothing else reaches the whole without reconstructing it, which an opaque type forbids. Left out at first since no paper program needed it; taken the same day because the first outside reader reached for it, and Haskell, OCaml, Rust, and Gleam all have it. Sixteen words. Elixir's `^x`, comparing against a bound variable, stays out: sugar for `when`.

## Against Gleam, 2026-09-13

Gleam feature by feature. Two changes: line comments are `//`, since `/* */` was already C's and `--` had a trap, `x--y` lexing as a comment; and `todo : (Text) -> a` in the prelude, a fault the process chose, the second deliberate exception beside division, because every paper program had written `= ...` for the function not yet written. Noted for later, already: byte patterns, string prefix patterns, `Address.call`, doc comments. Deliberately absent: `use` in general, `|>`, labelled arguments, `let assert`, `panic`, field access, `import`, `pub`, type aliases, `case` with several subjects. One disagreement kept: Gleam's `/` on `Int` returns `0` for a zero divisor; Ernest faults.

## Request-Reply, 2026-09-13

The report had `Address(m)` and `send`, no type-level story for request-reply. Every paper program wrote the pattern by hand: a `reply : Address(m')` field in the request, a `send(r, v)` in the arm, hope the arm remembers. The receiver-side forgetting was invisible, caught only by the caller's timeout. Principle 3 (nothing invisible) was paid for control flow and failure but not for the most common communication pattern.

Four options weighed. Session types: catch every protocol shape and are the machinery for it; too large, principle 7. CAF's `replies_to::with`: the actor type declares which requests it answers with which types — the reply obligation lives on the receiver's type, not on the message. Two types tracking one relationship, principle 2. Ada rendezvous: the arm's return is the reply, at the price of killing selective receive; struck three months ago and again here. Do nothing plus `Address.call` in the prelude: ergonomics for the caller, nothing for the receiver; the position for a day.

Taken: `Reply(a)`, a distinct type with local uniqueness. Made by `Address.call`; consumed by `answer` or by being forwarded as a message field. A `Reply(a)` bound in a receive arm must be consumed exactly once on every path of the arm's expression; the check is a flow analysis within the arm, propagating through function calls when a helper takes a `Reply(a)` parameter. Not general linear typing: `Reply(a)` is the one linear type, and only inside a receiving arm.

What this catches: forgetting to reply, replying twice, leaking a `Reply` into a data structure. What it does not catch: replying with the wrong content, replying to the wrong caller — but neither is possible, since the content type is `a` and the caller is baked into the `Reply` value. `Address.call` takes a mandatory timeout: `Optional(a)` in the return, no way for the caller to forget the failure mode. Erlang's default of five seconds picked wrong.

Why `Reply(a)` is not `Address(a)` with a rule: an `Address(a)` can be stored, aliased, and answered any number of times; a `Reply(a)` cannot. A shared type would either weaken addresses or add a "one-shot" flag that reads as a variant. Distinct types. `Reply(a)` costs one type name, two primitives, one type-checker pass.

`remote(f)` does not use `Reply`: `remote`'s reply is the function's return value, delivered synchronously; there is no reply address to lose track of. `remote` and `Reply` address orthogonal problems.

`Address.call` moves from Later into the report. It had been listed under Later because the paper programs had not written it three times yet; the receiver-side hole made the wait unnecessary. It is now in the prelude with `Reply(a)` and a mandatory timeout.

Spawn-capture. The receive-then-worker-then-reply pattern — a process receives a request, spawns a worker to do the work, the worker answers the caller — captures the `Reply` in the lambda handed to `spawn`. This is the shape file sync's `store`/`writer` reached and the shape any request that offloads to a worker reaches, and the language should let it be written directly rather than routed through an `Ack` wrapper. So spawn-capture is a third form of consumption: from the arm's perspective, capturing a `Reply(a)` in a lambda passed to `spawn` consumes it; the spawned lambda's body must in turn consume the captured `Reply` on every path, checked at the lambda's definition. Higher-order use beyond `spawn` remains a type error, since counting invocations of a callback is not general: `List.map` might call zero, one, or many times, `Optional.map` zero or one, and only `spawn` guarantees exactly one, in a new process. The MVP 1 restriction is written as: the spawn's second argument must be a direct `fn() = ...` expression, not a lambda bound in a `let` and passed by name, so that the check does not have to follow function values.

## Backpressure, 2026-09-13

The mailbox is unbounded. A fast producer and a slow consumer fill memory until the node dies. In practice this is a corner case — most systems have natural rate limits, most gen_servers are I/O-bound with fast enough consumers — but the failure mode when it happens is severe: a node OOM. Four mechanisms were weighed, plus one variant on `spawn`.

**Bounded mailboxes with block-on-full (Go, Occam).** `send` blocks until the receiver has space. Cycles deadlock, and the block is invisible in the code — a reader cannot look at a `send` and know whether it will happen now or in ten seconds. Principle 3. Rejected.

**`send` returning `Either(Full, ())`.** The failure is visible in the type, principle 3 satisfied. But every send site becomes a match, and the 99% that succeed pay the cost of the 1% that fail. Principle 1. Rejected.

**Runtime backpressure (Pony).** When a mailbox exceeds a threshold, the runtime pauses processes sending to it, and the pause propagates backward through the actor graph; an actor may be paused because something five hops away is slow. Debugging becomes archaeology, cycles deadlock. Principle 3, hard. Rejected.

**Silent drop (D's `ignore`).** Data loss without notification. Rejected against principle 3 without discussion.

**Spawn-time mailbox bound with sender-fault.** `spawn` takes an optional capacity; on overflow, the *sending* process faults, philosophically consistent with `/` and `%` on `Int` with a zero divisor. Loud instead of silent. Buys: a documented capacity contract, monitor-visible failure, no propagation, no muting. Costs: the sender does not know at send-time whether the receiver is bounded, and so cannot defensively check; and the most common overload case — an acceptor rejects the 101st connection with a 503 and keeps serving the 100 — is exactly the case where the acceptor should *not* die. The one narrow use it serves ("loudly detect that a process has been flooded; kill and let the supervisor restart") is a supervision pattern that a monitor plus a runtime hook on mailbox depth already covers, with more control over which party dies. Deferred; recorded here so the shape is known.

Taken: convention. The mailbox is unbounded (§10), and backpressure is application code: a credit protocol where the consumer sends the producer permission to send k messages at a time, and the producer waits for acks before continuing. Roughly ten lines per producer. Nothing in the language, nothing in the runtime. The failure mode without backpressure is a node OOM — noisy in the logs, same as Erlang. The idiom belongs in the guide, not the report.

`Slot(a)` — a language-level answer parallel to `Reply(a)` — is sketched under Later. If a paper program writes the credit protocol three times, revisit.

## Reasons Lifted Out of the Report

- `recv` is Erlang's `receive`: selective receive lets a process wait for a specific reply in the middle of a protocol without losing other messages; without it every process becomes a state machine, gen_server turned inside out. `recv` therefore does not require coverage, unlike `match`: the two forms share their syntax but not their semantics, since a `match` that finds no arm is a fault and a `recv` that finds no arm leaves the message in the mailbox. Cost O(n) in the mailbox, and a growing mailbox is not visible in the code, the same cost as in Erlang; the backpressure decision above covers the same problem from the sender's side.
- Braces and `;`: Gleam is the precedent. `if` is kept because its absence surprises more than its presence (Gleam's choice tried for a day).
- Two positional fields are forbidden because positions are invisible information and names are visible.
- Signature on opaque types instead of a naming rule: the interface gets a place.
- `via`: a narrower interface is a function, not a type rule; the adapter can do more than forward.
- The clock sends `()` because `msg : a` would be an existential type.
- `-` is absent on `Nat` for the sake of totality; `Int` exists for counting downward.
- Program termination when `main` returns is Go's rule, least surprise for everyone but Erlang readers; `Deadlock` is free on one node and the best deadlock protection there is.
- "What does not exist," formerly a section of the report: exceptions, macros, type classes, subtyping, effect systems, currying, existential types, mutation, layout, dynamic binding, session types, shared caches (the ETS problem), runtime-driven code replacement, content addressing. FFI was on the list until 13 September; see FFI.

## Later

Planned or considered, not in the language today.

- **Persistent data structures in the standard library.** Everything is immutable, so `Map.put` on a large map must share structure (Clojure) or be O(n). A requirement on the stdlib, not the language, but it must exist from the start; otherwise every stateful process is slow in a way the code does not show.
- **Content addressing, MVP 3.** Every definition gets a hash, and code follows messages to nodes that lack it. Not a core concept but the answer to how a node gets code; Erlang's module distribution is Erlang's weak point. Gives `Upgrade` over the network, types to nodes that have never seen them, and version mixing as an error at connection instead of undefined at `send`. Names as metadata and the codebase as a database remain outside.
- **Local state in pure code.** Unison's `{State}` is not mutation but threading that the handler does for you; `Scope.ref` is real mutation for algorithms on arrays, Haskell's `ST`. Ernest has recursion and accumulators, and state lives in processes. Two reasons to want more: convenience (three counters as arguments), where the answer is to write the argument; performance (update in place), where the answer is persistent data structures, already a requirement. `let mut` is not introduced for either; the tick game confirmed it: three counters became a fold with a tuple accumulator, and when the tuple grows the answer is a named type with `..`. Unison's only real mutation in pure code is `{Scope}` with `Ref` and mutable arrays; it can be removed without losing any capability, only a constant, and a second effect would be abilities back. If a mutable array is needed anyway, it is a process that owns it, Erlang's ETS. To be tested further in the Unison week: an algorithm with three counters without `{State}`.
- **`Erl` in the prelude.** `Erl.atom : (Text) -> Foreign` and `type Erl.Result(v, r) = Ok(v) | Error(r)`, so that shims do not redeclare them. Library, not language; in the plan under MVP 2.
- **Byte patterns.** Erlang's bit syntax, `<<Len:16, Body:Len/binary, Rest/binary>>`, is pattern matching over `Bytes`, and the single largest reason protocol code is written in Erlang. Ernest has `Bytes` and only functions to take it apart, four lines where Erlang writes one. Not a concept but a notation for something the language can already do, one more form in `AtomPat` with a small grammar inside; the addition Erlang readers will ask for first, and the one deliberately left for after the parser exists.
- **`Slot(a)` for language-level credit.** One-shot capability parallel to `Reply(a)`: a consumer allocates and grants slots to a producer via message, the producer sends by consuming a slot per message through `useSlot(s, v)`, and the consumer refills after processing. Same linearity check as `Reply(a)` — a `Slot` bound in an arm is consumed exactly once on every path. The compiler enforces that a producer does not send without permission. Deferred: only helps producer-consumer patterns, and the credit protocol as convention has not been written three times yet. When it has, this is the shape to reach for; see Backpressure above.
- **Idioms for the guide, not the report.** Links and supervisors: `monitor(child, Died)` and returning on `Died` is a link; a supervisor is fifteen lines of `spawn`, `monitor`, and `recv`. Parallel remote computation: `remote(f)` waits, so ten at once are ten local processes each calling `remote` and replying, which is what Unison does under `Remote.fork` and `await`, visibly.
- **Tests as values.** Unison's `test>` is one line, run by the codebase and cached per hash. Vanished with the codebase; a tooling question, but it is missed.
- **A measure of the specification's length.** Wirth's Oberon report is sixteen pages and shrank with every revision. If this document, without examples, grows past ten pages, one concept too many has come in.

## Open Questions

Not addressed in the report. Each needs a decision before the runtime is written.

- **No registry.** No global names, not even the system addresses; everything is threaded as arguments from `main`. Whoever has an address may send, no one else can find it; that is the whole security model. It decides program structure and should be stated as a principle, since someone will ask for `register` the first time two parts of a program cannot reach each other.
- **A message whose type does not exist at the receiver.** Two nodes with different versions of the same type. Undefined before MVP 3; the type is not part of the message. See content addressing under Later.
- **Tests.** How a test is written, run, and reported is undecided. A runtime flag for deterministic scheduling stood in the report as an inheritance from Unison's handler-swapping model and was removed; it is a runtime feature to decide with the runtime, not a language requirement.
- **Packages and dependencies between projects.** A program is files with one `main`; nothing more.
- **Canonical formatting**, like gofmt. Mentioned on day one, not decided.

Minor: what `Address` carries (node, process). Code loading before MVP 3: Erlang's `code:load`, modules on both sides. Idiom to write down: a start message for processes that need each other's addresses (file sync, finding 1).

## Paper Programs and Measurements

- `ernest-webserver.md`: web server with sessions. Gave `via`, timeout in receiving, signature on opaque types; rewritten on 13 September with an ETS table for the session store, the first program to use `foreign fn`.
- `ernest-filesync.md`: file sync between two nodes. Gave `monitor` and `kill` as functions, `Sys` as values, named fields, the clock with a value, backpressure as convention.
- `ernest-tick-game.md`: snake game with ticks. Gave definitions in blocks, `At` and `Now`, `Sys` as the runtime's type, the value-versus-process criterion, the answer on local state, and the case against `Nat`.
- `ernest-repl.md`: REPL with lexer, parser, evaluator, and `try` as a process. Gave `<-`, the warning about `self` in `spawn`, `TryError`.
- All paper programs: `spawn(Local, ...)` after placement became an argument.
- `ernest-comparison-webserver.md`: the same web server in Erlang. Without type signatures six percent more characters, almost all in the filter function, which was subsequently dropped.

## Form of the Report

The language report is self-contained: no references to other languages, no history. The order runs from characters to programs, so that every term is defined before it is used: introduction with principles, notation, lexical elements, types, declarations and scope, expressions, processes, errors, programs, prelude, runtime requirements, grammar as an appendix, examples as an appendix. The grammar was written in full in EBNF, which found two ambiguities the prose had hidden: `match Peer { ... }` (constructor with fields, or `match` on the value `Peer`; the rule became that a constructor followed by `{` is always field construction, and `match (Peer) { ... }` for the other), and `after` as the first arm in `recv` (forbidden; `after` is last). The prelude was written as a list, which forced the contents of `Down`: `Down { reason : Reason, function : Text }` with `Reason = Returned | Killed | ProgramEnd | Fault(Text)`, and that `monitor` reports normal death as well. Containers are taken as the first argument in the prelude.

What stood in the specification as reasoning, comparison, or guidance has moved here; see "Reasons Lifted Out of the Report."

## Measure

The report without code blocks should stay under ten pages, Oberon's measure. At the split the language part was six pages; after paring, 2,100 words; as a report with distribution and toolchain, 3,200 words of prose, of which the prelude and the grammar are lists.

## Next Steps

The paper phase is done: web server, file sync, tick game, REPL, and the web server compared with Erlang. The background queue was dropped; it existed for backpressure, which waits. The Unison and Gleam weeks were dropped. Next: `counter` written by hand against the report, then a parser that reads Appendix A, then MVP 1 according to the implementation plan.
