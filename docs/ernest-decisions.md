# Ernest: Decision Log

The reasoning behind the language report in [`ernest.md`](ernest.md): what was taken from Unison and Erlang, what was tried and rejected, what is deferred, and what is undecided. The report says what holds; this document says why. The language was called Actorson until 12 September 2026.

**A note on principle numbering.** Some dated entries below reference "principle N" using the count at the time they were written. The count changed on 2026-09-14 from seven principles to five (see *Ambient Sys, Five Principles*), and one entry from 2026-09-12 renamed "principle 5" as what is now principle 4 (simple to parse). Read older references in that light; the current numbering lives in [`ernest.md`](ernest.md) §0.

**A note on terminology.** On 2026-09-15 four names changed report-wide: match/recv "arms" became "clauses" (matching Erlang/Haskell/SML tradition); "bit arrays" became "bitstrings" (matching Erlang's name for the same `<<...>>` syntax); constructor "payloads" became "fields" (except message-payload uses); top-level values in `Sys.*` and elsewhere lost the "ambient" adjective, becoming "top-level bindings" / "top-level references". Later the same day the cons operator `+:` became `::` and the string-concat operator `++` became `<>` (see *List and Concat Operators*), the reserved word `recv` was spelled out as `receive` (see *`recv` → `receive`*), `opaque` became `abstract` (see *`opaque` → `abstract`*), tuples got a `#(...)` prefix (see *Tuples: `#(...)` Prefix*), the string type `Text` was renamed to `String` (see *`Text` → `String`*), and the unit type/value `()` was renamed to `Void` (see *`()` → `Void`*). Historical entries below use the older syntax; the current forms live in [`ernest.md`](ernest.md).

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
- Universal ordering across type boundaries (Erlang's term order, Unison's `Universal.<`). Ordering exists per type in its namespace, `Int.compare`, `Text.compare`, `Money.compare`, and `<` is resolved like `+`. Functions that need an ordering take it as an argument: `List.sort(xs, Int.compare)`. `Map(k, v)` is built on a structural hash of the key and needs only equality.
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

- **`type Bool = false | true`** broke the constructor rule (uppercase). `true` and `false` are literals of `Bool`, reserved; sixteen words. Gleam's `True` lost to every other language's `true`.
- **`type Millis = Int`** was a type alias, and the grammar has none: it parsed as a sum type with a nullary constructor called `Int`. Aliases would be a concept; `Millis` was dropped, `ms : Int`.
- **Qualified references** were missing in `TypeAtom`, `Constr`, and `AtomPat`, and `Name` and `Constr` both began with an uppercase token, so `Primary` was not LL(1). One rule, `Ref = { typename "." } ( ident | binop | conname [ payload ] )`: after each uppercase token, `.` continues, otherwise the segment is final and its case says function or constructor.
- **`Fields` could be empty**, admitting `Peer()` and `Peer(..p)` with a prose note forbidding one of them. Rewritten so neither can be written; a pattern may still omit all fields, `Closure()`.
- **`Signature` took a qualified `Name`**; signatures are unqualified and live in the type's namespace, so `( ident | binop )`, and `+ : (Money, Money) -> Money` declares `Money.+`.

The principles were revised on the same day. Three times in two days a rule that looked clean on paper fell to code (`if`, `let`, division), each time on least surprise, each time after a derived rule had been allowed to outrank it; principle 1 now says "measured in code, not in the rule." And `let` and the bracket decision followed a principle nobody had written: simple to parse. It is principle 5: LL(1), every construct decided by its first token, one role per bracket. Seven principles.

**Pure HM, checked.** Every construct was walked against Algorithm W. Textbook: n-ary arrows, nominal named fields, `fn` generalized and `let` monomorphic, binding groups for mutual recursion, exhaustiveness as a separate pass. Two additions, both closed: a context variable κ on every arrow, generalized when free (pure means callable anywhere, and callbacks run in the caller's context), and one post-inference resolution pass that picks `Int.+`, checks `==`, and chooses `Either.andThen` or `Optional.flatMap` for `<-`. No type classes, no subtyping, no rows, no rank-n. A third addition was looked for and not found.

- **Visibility.** The report first said every top-level declaration is visible program-wide and hiding is by nesting; then the obvious rule appeared: an unqualified top-level name, `fn helper(`, is file-local, a qualified one, `fn Net.Http.parse(`, is program-wide. No `pub`, no export list, visibility in the name (principle 3), and a file gains the one meaning every reader already assumes it has.

What was already clean: mandatory `else` leaves no dangling `else`; the lambda is at `Expr` level and cannot be called without parentheses, so its extent is maximal munch and unambiguous; `|` and `||` are separated by longest match; `.` in names and `.` in floats by digits never beginning a name; `->` occurs only in types and arms, never in the same position. Remaining fragility, not ambiguity: `((Int, Int)) -> Int` against `(Int, Int) -> Int` differs by one parenthesis level; the compiler suggests the other reading on arity errors.

Principle 5's first-token dispatch is stretched at exactly one place: after `T(` the parser peeks past the first identifier for `=`, `:`, or otherwise, to decide fields versus expression versus declaration payload. Factoring the grammar to avoid this was considered: a bracket per role (rejected in this same audit — `{` had two roles); a leading marker on named fields, `T(.dir = d)` (adds a character per field, and moves the lookahead to `.` versus `..` for spread — the same peek in a different place, unless spread is also changed, at which point `*p` collides with multiplication in argument position); type-directed parsing (breaks the parser / type-checker separation Ernest deliberately keeps); a leading marker on positional (single-positional constructors are the most common shape and would pay the cost of the exceptional case). Each costs more than the exception. Tolerated deliberately, documented in Appendix A's closing paragraph.

## Distribution, 2026-09-13

The day-two decision, "this is Erlang, where you say which node," was revised into two things, one from each side. A process is placed explicitly: `spawn(Where, f)` with `Where = Local | Peer(name)`, placement visible on the line (principle 3), one function rather than `spawn`, `spawnOn`, `spawnRemote` (principle 2), and `Local` written on every local spawn because running here is a decision too. A remote computation is Unison's: `remote(f)` evaluates a pure `f` on a peer the runtime chooses by load among those configured for it, and returns the value. Three types were tried for `remote` in an hour. First a reply address, `remote(f, reply)`: honest but visible plumbing the developer has no use for. Then `->{Proc(m)}`: the caller waits, so it seemed like process code. Then the observation that every call runs in a process: the context marks use of the process's own mailbox and identity, and `remote` uses neither, so it is pure, `(() -> a) -> Either(RemoteError, a)`, with failure over the boundary in the type. That observation sharpened the definition of the context in section 6, which had been missing. Peers, their names, addresses, keys, and the `remote-peer` flag live in `ernest.conf`, outside the language. Code follows by content hash, MVP 3; peers need not share code. Tools: `ernc` compiles to `.erc`, `ern` runs, as `erl`.

## Toolchain and Guide

The toolchain went into the report as section 11, as a contract rather than a manual: the commands, their arguments, the files they read and write, and nothing about output, exit codes, or the REPL's appearance; it defines what a program is in practice, and section 8's `Sys` and peers need an address. Distributed programming does not go into the report: a report says what holds, and how to build is another genre. It becomes a third document, [`ernest-guide.md`](ernest-guide.md), with distributed programming as one chapter beside error handling and process design, written from the paper programs once the compiler runs them.

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

Spawn-capture. The receive-then-worker-then-reply pattern — a process receives a request, spawns a worker to do the work, the worker answers the caller — captures the `Reply` in the lambda handed to `spawn`. This is the shape file sync's `store`/`writer` reached and the shape any request that offloads to a worker reaches, and the language should let it be written directly rather than routed through an `Ack` wrapper. So spawn-capture is a third form of consumption: from the arm's perspective, capturing a `Reply(a)` in a lambda passed to `spawn` consumes it; the spawned lambda's body must in turn consume the captured `Reply` on every path, checked at the lambda's definition. Higher-order use beyond `spawn` remains a type error, since counting invocations of a callback is not general: `List.map` might call zero, one, or many times, `Optional.map` zero or one, and only `spawn` guarantees exactly one, in a new process. The MVP 1 restriction is narrow and applies only when the spawned lambda captures a `Reply(a)`: in that case the spawn's second argument must be a direct `fn() = ...` expression at the call site, not a lambda bound in a `let` and passed by name, so the check does not have to follow function values. Spawns of non-Reply-capturing lambdas are unaffected.

## Backpressure, 2026-09-13

The mailbox is unbounded. A fast producer and a slow consumer fill memory until the node dies. In practice this is a corner case — most systems have natural rate limits, most gen_servers are I/O-bound with fast enough consumers — but the failure mode when it happens is severe: a node OOM. Four mechanisms were weighed, plus one variant on `spawn`.

**Bounded mailboxes with block-on-full (Go, Occam).** `send` blocks until the receiver has space. Cycles deadlock, and the block is invisible in the code — a reader cannot look at a `send` and know whether it will happen now or in ten seconds. Principle 3. Rejected.

**`send` returning `Either(Full, ())`.** The failure is visible in the type, principle 3 satisfied. But every send site becomes a match, and the 99% that succeed pay the cost of the 1% that fail. Principle 1. Rejected.

**Runtime backpressure (Pony).** When a mailbox exceeds a threshold, the runtime pauses processes sending to it, and the pause propagates backward through the actor graph; an actor may be paused because something five hops away is slow. Debugging becomes archaeology, cycles deadlock. Principle 3, hard. Rejected.

**Silent drop (D's `ignore`).** Data loss without notification. Rejected against principle 3 without discussion.

**Spawn-time mailbox bound with sender-fault.** `spawn` takes an optional capacity; on overflow, the *sending* process faults, philosophically consistent with `/` and `%` on `Int` with a zero divisor. Loud instead of silent. Buys: a documented capacity contract, monitor-visible failure, no propagation, no muting. Costs: the sender does not know at send-time whether the receiver is bounded, and so cannot defensively check; and the most common overload case — an acceptor rejects the 101st connection with a 503 and keeps serving the 100 — is exactly the case where the acceptor should *not* die. The one narrow use it serves ("loudly detect that a process has been flooded; kill and let the supervisor restart") is a supervision pattern that a monitor plus a runtime hook on mailbox depth already covers, with more control over which party dies. Deferred; recorded here so the shape is known.

Taken: convention. The mailbox is unbounded (§10), and backpressure is application code: a credit protocol where the consumer sends the producer permission to send k messages at a time, and the producer waits for acks before continuing. Roughly ten lines per producer. Nothing in the language, nothing in the runtime. The failure mode without backpressure is a node OOM — noisy in the logs, same as Erlang. The idiom belongs in the guide, not the report.

`Slot(a)` — a language-level answer parallel to `Reply(a)` — is sketched under Later. If a paper program writes the credit protocol three times, revisit.

## No Registry, 2026-09-13

Erlang has `register(atom, pid)` for local processes and `global` for cluster-wide names. Elixir has `Registry` with typed via-tuples. Akka has a receptionist. Ernest has none. The rule: a process reaches another only through an address it holds or received in a message, and possession of the address is the permission to send.

This is a capability model. Every `send` in the program has a visible provenance — a reader can trace back through the chain of who gave the address to whom, ultimately to `main` or `Sys`. A registry would break that: names are strings, and any code that can construct the string can send to the process, and the type checker cannot verify at send that the name resolves to a process with the compatible mailbox type. The property is worth its cost; manual propagation is the shape principle 3 asks for.

**Circular dependencies use a start message.** Two processes that must know each other cannot both be spawned with the other's address, since one is spawned first. The pattern is the `Link` message: spawn both, then send each the other's address; each waits in a `start` phase for the `Link` before entering its loop. File sync writes this in four lines and it generalizes to more processes. The idiom belongs in the guide.

Alternatives considered.

**Named spawn returning an ordinary `Address` with a global name (Erlang's `register`).** An implicit registry. The address's security property is broken because anyone constructing the name — a `Text` — can send. Principle 3, hard. Rejected.

**`NamedPeer(name)` as a distinct address type.** The type checker cannot verify at send that the name resolves to a process with the compatible mailbox type without a global type-name registry. Two types where there was one, plus either invisibility or a much larger mechanism. Principle 2 and either principle 3 or principle 7. Rejected.

**Erlang's `global` module.** Distributed quorum protocol nobody uses in practice. Not a model to copy.

**Akka Typed's receptionist.** Actors register with typed service keys; consumers get notified when matching services register. Solves observability well but adds a registry-plus-notification protocol on top of the actor model. Deferred; if it appears in three programs, revisit.

**Named spawn purely for observability (trace/log names, no lookup).** If the runtime chooses to expose process names as a debug hook, that is not a language mechanism — the name is invisible to code, cannot be used to send, and adds no concept to the report. Left to the runtime and the toolchain.

Taken: no registry. The `Link` idiom for mutual references, threaded arguments from `main` for the rest, and observability handled by the runtime's debug facilities without a language-level name.

## Remote Ergonomics, 2026-09-13

Two scenarios have been raised as limitations of `remote(f)`.

**Fire-and-forget: "start something on a peer, don't wait for it."** Not a gap in `remote`, because `remote(f)` is for pure computation whose value the caller uses. A fire-and-forget scenario always has side effects — write to a file, send a message, update a table — and side effects live in process code, not in `remote`. The answer is `spawn(Peer(name), f)` with the returned `Address` discarded: `let _ = spawn(Peer("worker"), fn() = doThing())`. The primitive already exists, and it types the situation correctly: impure computation runs in a process with a mailbox.

**Parallel-then-join: "start N pure computations simultaneously, wait for all."** A real ergonomic gap in the current primitives. Written by hand today: spawn N local processes, each computing `remote(fi)` and sending the result to a common address, then `recv` N times, threading indices to preserve order. Ten to fifteen lines per use.

Four options weighed.

**A `Task(a)` type with `remoteFork` and `await`.** Unison's answer. Clean at the use site but adds a new concept and two primitives; the concept has to interact with equality, serialization, closure capture, cross-node transfer, and every other language rule. Principle 7 (small). Principle 2 (no variants): `remote(f)` and `remoteFork(f)` are two ways to start a remote computation. Rejected for now.

**Change `remote` to return `Task(a)` uniformly.** Kills the current synchronous shape and forces the Task concept everywhere. Semantics change plus principle 7 tension. Rejected.

**A stdlib helper, `List.parallelRemote(fs)`.** No language extension. The library implements the spawn plus recv gather internally, presenting one function that returns the ordered list of results. The runtime may special-case for direct scheduling.

**Do nothing.** Rely on hand-written pattern in each program.

Taken: the stdlib helper, deferred to Later. Writing the pattern by hand is bounded (ten to fifteen lines) and no paper program has written it three times. `Task(a)` remains available if paper programs demand richer control — cancellation, timeouts per task, interleaved arrivals rather than all-at-once — and `List.parallelRemote` is the smaller answer if what is needed is only parallel-then-join.

## Tests, 2026-09-13

Ernest has no test story today. Every language has to answer this eventually; the question is what shape fits.

Options considered.

**Tests as values.** A test is a term of a prelude type, and the toolchain discovers all top-level bindings of that type and runs them. Unison's `test>` is the reference; the specific `test>` form relied on the codebase-as-database and vanished with it, but the underlying idea is portable.

**Naming convention.** Functions named `test_something` are tests. Rust and Go's shape without their attribute machinery. Rejected: naming rules are invisible in the type, principle 3, and Ernest has not leaned on them elsewhere.

**A `test` keyword.** `test "adds two" = ...` as a declaration form. A seventeenth reserved word for one library-level concern. Principle 6. Rejected.

**Nothing.** Tests are just functions; the user writes a `main` that runs them. No discovery, no reporting, no toolchain integration. Too weak.

Taken: tests as values. A test is a top-level binding of a specific prelude type; the toolchain discovers them by scanning types. No new keyword, no naming rule, no attribute; consistent with "everything is a value" and with visibility being in the name — a top-level binding is what it is by its type, not by decoration.

The concrete prelude type is deferred to MVP 1 Phase 3, when the toolchain is being written and paper programs can inform the API. Candidate shape: `type Test = Test(name : Text, run : () -> Test.Result)` with `type Test.Result = Passed | Failed(Text)`. Deciding the exact ergonomics without a paper program that writes tests would be the rule not measured in code, principle 1. Deterministic scheduling for tests, which stood briefly in the report as a runtime flag, remains a runtime feature to decide with the runtime, not a language requirement.

## Packages, 2026-09-13

A program is a set of files with one `main`; today there is no mechanism to depend on another project's code. The question is what that mechanism should be.

Content addressing is already committed to in MVP 3: every definition is identified by a hash of its typed AST, and a message with a function carries the hash so peers can fetch what they lack. That commits Ernest to a Unison-shape answer to dependencies eventually — code is identified by hash, versions of the same function coexist as distinct hash-addressed values, no manual version bounds.

Options for the interim.

**A versioned package manager.** Cargo, Cabal, npm, Hex. Manifest with dependencies, resolver, lockfile, registry. Solves the discovery and version-management problem at real cost: semver arguments, dependency hell, tooling weight. Rejected: content addressing is coming and would supersede all of this. Building it twice would be waste.

**A simple load-path model.** `-pa dir ...` locates compiled `.erc` files by namespace. This is what section 11 already describes. Users manage the load path themselves; two projects share code by pointing at each other's build outputs. Enough for MVP 1 and MVP 2, honest about what it is — not a package manager, a search path.

**Nothing.** Users copy files. Rejected: the load path is a small enough concept and already in the report.

Taken: the load path for MVP 1 and MVP 2, content addressing for MVP 3 and beyond. No versioned package manager, ever. The question of how to discover code someone else wrote — a registry that indexes content-addressed definitions by name — is a tooling question, not a language question. If it becomes essential, it lives in the guide and the runtime, not the report.

## Three Layers, 2026-09-13

Ernest is now organized in three layers, made explicit after the discussion prompted by `send(out, Line("hello"))` reading as heavy for a simple print.

**Language.** What [`ernest.md`](ernest.md) defines: syntax, types, processes, evaluation rules, the five principles. This is the small, hard part. It doesn't change with new libraries.

**Prelude.** What the language requires to exist because the report references it. Section 9 lists these: `Optional`, `Either`, `Ordering`, `Down`, `Reason`, `ClockMsg`, `RemoteError`, `Foreign`; the built-in parameterized types `List`, `Map`, `Set` (plus `Address`, `Reply`, `Never` covered in section 3); the process operations `via`, `Address.call`, `answer`, `remote`, `monitor`, `kill`; and the specific operations the report calls out — `Int.div`, `Int.mod`, the four `compare` functions, `todo`. Nothing else.

**Standard library.** Ernest code that ships with the compiler and lives on the load path. Section 9 lists the modules; Appendix E documents their exported signatures. `Io.print`, `Io.println`, `Io.printTo`, `Io.printlnTo`; every `List.*`, `Map.*`, and `Set.*` operation; text and character utilities; numeric utilities; Optional and Either helpers; Foreign inspection. All written in Ernest, using nothing but the language and prelude. A program that never references any of these names does not depend on the standard library; a program that does depends on `stdlib/` being present on the load path.

The prelude had grown to include roughly forty convenience functions on the built-in container and text types. The realization: none of these are language-required. The report doesn't say `List.map` must exist; the paper programs use it, but that is a program's choice. Moving them to the standard library makes the report smaller, gives implementers a clear boundary — "prelude is what the report needs, stdlib is what the ecosystem provides" — and lets the standard library grow at a different pace from the language.

`Line` is dropped. The `Line` wrapper type stopped earning its keep once `Io.println` in the standard library became the idiomatic way to print. `stdout : Address(Text)` is smaller and reads better: `send(out, "hello\n")` beats `send(out, Line("hello"))`. The runtime writes each `Text` to standard output as bytes, and newlines are the sender's responsibility. If we ever want to distinguish output classes (log levels, colors), we introduce a message type at that point, when the paper programs demand it.

Growth rule for the standard library: same as the deferrals in Later. When a paper program writes the same pattern three times, promote it to a stdlib module. Do not speculatively add.

## Ambient Sys, Five Principles, 2026-09-14

`Sys` is no longer a value threaded through the program. The runtime's system processes are exposed as top-level ambient references: `Sys.stdout : Address(Text)` and `Sys.clock : Address(ClockMsg)` in the report's prelude; paper-program runtimes may add `Sys.fs`, `Sys.stdin`, `Sys.keys`, a stderr sink, and the like. `main` takes no arguments: `fn main() -> () with ()`. The `Sys` type declaration is gone.

**Why.** Threading `sys : Sys` (or `out : Address(Text)`) through every function that prints was ugly. The counter, ping-pong, filesync, tick-game, and REPL each carried the same parameter chain to no end. The rule that forced it — "nothing invisible" read as "no ambient values" — was the wrong reading. Ernest already has `self()`, which returns per-process state without being passed; nobody calls it invisible because it has a name at the use site. `Sys.stdout` is a sibling: an ambient value with a name at the use site. What "nothing invisible" actually rules out is *hidden effects* — a call like `println("x")` that names no address. Ambient by name is fine.

The purity boundary that used to be defended by the threading is defended by the mailbox effect on `send`. Pure functions have no mailbox slot; they cannot call `send` regardless of whether they can name `Sys.stdout`. Naming an address is not sending to it.

**Cost.** Testing loses the trivial `main(testSys)` swap. A test that wants to capture stdout has to run the program with a runtime that provides a captured stdout process — configuration replaces injection. Acceptable now; if this hurts three paper programs from now, revisit with a per-process ambient rather than a node-wide constant.

**Refinement of principle 3.** "Nothing invisible" is now stated as: control flow, communication, and failure are visible in the code or in the type; an ambient value is visible when its name appears at the use site; a hidden effect is not. This is what the principle should have said from the start — the earlier wording read as banning ambience, which contradicted `self`.

**Consolidation of principles: seven to five.** The seven had drift:

- "No variants" and "orthogonal" both said "one way to do a thing." Merged into principle 2: *one way, one job*.
- "Few reserved words" and "small" both said "small." Merged into principle 5: *small* — concepts, primitives, reserved words.

Result:

1. Least surprise decides — measured by the resulting code, not by the rule.
2. One way, one job — in the language and prelude. No variants for the same thing, no two concepts that overlap in what they express, unless what remains surprises more. The standard library, being ordinary Ernest code, may pair functions for convenience.
3. Nothing invisible. Control flow, communication, and failure are visible in the code or in the type. An ambient value is visible when its name appears at the use site; a hidden effect is not.
4. Simple to parse: recursive descent, first-token dispatch, small bounded lookahead where the grammar demands it, no backtracking.
5. Small: few concepts, few primitives, few reserved words — but not too few.

**Io.ern surface.** The stdlib pairs an ambient form with an explicit-address form. `Io.print` and `Io.println` take just `Text` and send to `Sys.stdout`; `Io.printTo` and `Io.printlnTo` take `(Address(Text), Text)` for a specific sink (a logger, a capture buffer, an alternate stream). Both are useful and neither is a variant of the other — the argument list distinguishes them, the same way `print` and `fprint` differ in C.

**What did not change.** `self()` is still `self()`, a nullary function with parens; it can't become a value because it depends on the current process. `Sys.stdout` is a value because it's node-wide, not per-process. If we ever need per-process ambient stdout (test isolation), we'll pay for it then, likely by giving `Sys.stdout` a call form or by extending `spawn` to accept a per-child ambient override.

## Standard Library Baseline, 2026-09-14

Appendix E was audited for naming, argument order, and coverage. The growth rule ("three uses before promoting") continues to apply to further additions; this audit set the initial baseline so the appendix reads complete rather than skeletal.

**Renames for consistency.**

- `Optional.flatMap` → `Optional.andThen`. Same monadic-bind operation as `Either.andThen`; unifying the name kills a variant. `andThen` reads better in code than `flatMap` and matches Elm and Rust precedent (`and_then`).
- `Map.delete` → `Map.remove`. Ernest already uses `remove` for `Set` and `List`; `delete` was the odd verb out.

**Argument order.** Kept subject-first throughout — the container or subject is the first argument, callbacks last, initial values in the middle for folds. Already consistent; nothing to change.

**Additions.** Each is well-established across Elm, Rust, and Haskell stdlibs and closes an obvious gap:

- List: `all`, `find`, `take`, `drop`, `isEmpty`, `append`, `last`.
- Map: `keys` (paired with `values`), `contains`, `isEmpty`.
- Set: `isEmpty`, `fromList` (paired with `toList`), `union`, `intersect`, `difference`.
- Text: `size`, `isEmpty`, `contains`.
- Char: `toInt` (code point), `isSpace`.
- Int: `abs`, `min`, `max`.
- Float: `abs`, `ceil`.
- Optional: `withDefault`, `isSome`, `isNone`.
- Either: `isLeft`, `isRight`, `toOptional`, `withDefault`.

**Deferred to the growth rule.** These would round out the modules but haven't yet been written three times in a paper program: `List.zip/flatMap/concat/range/repeat/foldRight`, `Set.map/filter/foldLeft`, `Text.split/trim/replace/startsWith/endsWith/toLower/toUpper`, `Char.toUpper/toLower/isUpper/isLower/isAlphaNum`, `Int.pow`, `Float.sqrt/pow/min/max/truncate`, `Optional.orElse/toList`.

**Paper programs updated.** `Map.delete` → `Map.remove` in [`ernest-tick-game.md`](ernest-tick-game.md); `Optional.flatMap` → `Optional.andThen` in [`ernest-webserver.md`](ernest-webserver.md). The implementation plan's note on `<-` desugaring reads `Optional.andThen` now.

## `parallelRemote` in the Prelude, 2026-09-14

`parallelRemote` is promoted from Later (stdlib) to the report's prelude, alongside `remote`. Signature:

```
parallelRemote : (List(() -> a)) -> List(Either(RemoteError, a))
```

**Why prelude, not stdlib.**

- **Symmetry with `remote`.** Concurrency and remote computation are first-order concepts in Ernest, and the prelude should show the pair, not just the singular. `remote(f)` runs one; `parallelRemote(fs)` runs many. Together they are the two ways the language reaches other nodes.
- **Runtime-optimizable.** Written in Ernest it is spawn plus recv gather — 10–15 lines. Written by the runtime it can schedule directly to peers, skipping the local process ceremony. Placing it in the prelude signals that the runtime is expected to provide it, not that programs synthesize it.
- **Pure like `remote`.** The type has no mailbox effect. The result depends on the inputs alone; the caller waits as it would for any computation. Pure code can call it, which matters for algorithms that fan out remote computations from pure helpers.

**Why not a keyword.** Concurrency's prominence in Ernest is real, but wrapping `parallelRemote` in a reserved word costs one against principle 5's small-count. `remote` is a function; `send` is a function; `spawn` is a function. `parallelRemote` fits the same pattern. Elevation belongs in section 6's prose and the type, not in the grammar.

**Growth-rule note.** The three-uses rule applies to promoting stdlib functions; the prelude has a different bar (the report names it). `parallelRemote` earns its slot because it is the second half of the remote-computation story, not because a paper program used it three times. If a paper program written after this decision does not use it, revisit.

## `Address.callForever` in the Prelude, 2026-09-14

`Address.callForever` is added to the prelude alongside `Address.call`:

```
Address.callForever : (Address(m), (Reply(a)) -> m) -> a with n
```

Same operation as `Address.call` without the timeout: the caller waits as long as needed and receives `a` directly, not wrapped in `Optional`.

**Why.** The original request-reply design mandated a timeout so callers couldn't forget the failure case. That property is preserved for the default — `Address.call(addr, mk, ms)` still returns `Optional(a)`. But `recv` without `after` and `remote` (which has no timeout) both allow "wait forever," and denying `Address.call` the same option was inconsistent. `Address.callForever` restores the symmetry by naming the choice at the call site: the caller has decided that hanging on a missing answer is acceptable in this context.

**Not a variant of `Address.call`.** Two operations with different return types and different guarantees — `Optional(a)` vs `a`. Similar to how `remote(f)` and `parallelRemote(fs)` share a purpose but aren't variants of each other; argument shape and return type distinguish them.

**Static-check relationship.** The linearity check on `Reply(a)` is static; the mandatory timeout on `Address.call` compensates for the fact that execution may not reach `answer` at runtime. `Address.callForever` accepts that risk by name — the caller has made the decision explicitly.

**Growth-rule note.** No paper program has needed this yet. Added on consistency-with-`recv`-and-`remote` grounds, not on three-uses. If a paper program written after this decision doesn't reach for it, revisit.

## Against Labeled Function Arguments, 2026-09-14

Ernest does not adopt labeled parameters — Gleam's `pub fn f(name label: T)`, Swift's `f(name: T)`, Python's keyword arguments. The feature is small in isolation but attracts default values, optional parameters, variadic labels, and positional-vs-keyword-only markers by ongoing community pressure. Python, Swift, and Elixir each took the first step and then took the next several. Rust has held the line for years and pays for that discipline with every fresh RFC.

**Ernest's alternative for wide signatures**: named fields on a constructor. A function that would benefit from labels wraps its parameters in a small config record:

```
type CallOptions = CallOptions(timeout : Int, retry : Bool)
fn call(addr : Address(m), mk : (Reply(a)) -> m, opts : CallOptions) -> Optional(a) with n
```

Call site: `call(counter, mkGet, CallOptions(timeout = 1000, retry = false))`. Labeled at the site, ordering doesn't matter, one type declaration pays for it.

**Named honestly: this costs more than labeled args would.** Gleam has both named fields on constructors *and* labeled function arguments — clear evidence that the constructor pattern alone leaves an ergonomic gap. Introducing a type for every wide function is more friction than adding a label. Common cases like `List.foldLeft(list, init, folder)` or `Address.call(addr, mk, timeout)` don't reach for a wrapper type; positional works, but a label at the timeout would help readability at zero declaration cost. Labeled args also give tools something to bind against — completion, better error messages — that constructors don't offer as directly.

Ernest chooses the higher-activation-cost path deliberately. The design pressure to introduce a type when a signature grows past three or four parameters is treated as a *win* — it forces the shape onto the type system, where readers find it — but that's a values-driven trade, not a claim that constructors close the ergonomic gap. Gleam's decision reflects a different weighting on adoption-friendliness. Both are defensible; Ernest picks the narrower one.

**Principle alignment.**

- Principle 2 (one way, one job): labeled args and constructor named-fields would be two mechanisms for the same call-site labeling job.
- Principle 5 (small): fewer language concepts and no machinery for defaults, optionals, keyword-only, etc.
- Growth rule: no paper program has written a signature wide enough to need labels. Adding them speculatively is exactly what the rule was written to prevent.

**Not adopted alongside**: default parameter values, optional parameters, variadic parameters. All rejected on the same slippery-slope grounds. If a paper program writes a five-parameter signature with two bools three times without wrapping them in a type, revisit.

## Pipe Operator `|>`, 2026-09-14

`|>` is added to the report as a syntactic form: `x |> f` is `f(x)`; `x |> f(a, b)` is `f(x, a, b)`. Left-associative, lowest-precedence (below `||`).

**Why.**

- **Reads left to right.** Stdlib call chains like `input |> Text.trim |> Text.toLower |> Text.chars` beat the equivalent nested calls `Text.chars(Text.toLower(Text.trim(input)))` on both scan direction and diff-friendliness. Every modern typed FP language on the ML/OCaml/Elm/F#/Gleam/Elixir spectrum has this operator for the same reason.
- **Subject-first stdlib was already lined up for it.** `List.map(list, f)`, `Map.get(map, key)`, `Text.chars(text)` — the subject-first argument-order convention Ernest committed to in the stdlib audit is exactly what pipes want. `xs |> List.map(f)` = `List.map(xs, f)`. The two decisions were made independently; the pipe is the payoff.
- **Small cost.** One operator, one grammar rule, one precedence slot. No new type-system machinery. The desugaring is syntactic and happens at parse time or in an early lowering pass.

**How it desugars.**

- `x |> f` → `f(x)` (f as function value or bare name).
- `x |> f(a, b, ...)` → `f(x, a, b, ...)` (first-argument insertion).
- `x |> (fn(y) = e)` → `(fn(y) = e)(x)` (lambda as RHS).

The type checker validates that `x`'s type matches the target's first argument.

**LL(1) impact.** None. `|>` is a `binop` and slots into `BinExpr`'s existing `Unary { binop Unary }` production. The desugaring is post-parse.

**Not qualifiable.** `Int.|>` and similar are rejected. `|>` is a syntactic form, not a namespaced function — unlike `Int.+` or `Text.<>` which are ordinary function names an operator lookup resolves to.

**Not adopted from Gleam/Elm at the same time**: labeled function arguments, `use` for arbitrary callbacks, function-capture `f(_, y)`. Waiting for a paper program to write those patterns three times, per the growth rule.

## Bit Arrays in the Report, MVP 2 in the Plan, 2026-09-14

`<<...>>` for bit-array construction and pattern matching is promoted from `Later` into the report. Grammar shape lives in Appendix A; the specifier list and one worked example are in §5.

**Why now.**

The `Later` entry from 2026-09-13 said "the addition Erlang readers will ask for first, and the one deliberately left for after the parser exists." The intent was to defer exploration. What changed: Gleam has been through the exploration in an adjacent typed-FP-on-BEAM context — same runtime, same type system character — and settled on the shape (`<<value:specifier-specifier-size(n)>>`, dash-combined specifiers, the specifier vocabulary size/unit/bits/bytes/int/float/utf8/utf16/utf32/big/little/native/signed/unsigned). We're not exploring; we're borrowing. That flips the cost calculus.

**What we adopt.**

- Delimiters `<<` and `>>` as new lexer tokens; longest-match rules them apart from `<` and `>`.
- `BitExpr` in `Primary` and `BitPat` in `AtomPat` — the same shape, one for construction, one for pattern.
- `BitSpec` as a small internal grammar: `size(N)`, `unit(N)`, and eleven keyword-like specifiers.
- Specifier names are role-scoped: they are ordinary identifiers outside `<<...>>`. Reserved-word count stays at sixteen.

**What we don't touch.**

- No new type — bit arrays construct and destructure `Bytes` values.
- No new tokens outside `<<`, `>>`.
- No JavaScript-target compromises: Ernest is BEAM-only, so the full specifier set is available with no lowering caveats. Gleam had to make compromises on JS output; we don't.

**LL(1) impact.** `<<` is a new first-token in expression and pattern positions, dispatched at the same level as `[` and `(`. Bounded lookahead only inside the specifier list (the closed set of keyword-like idents), which is a local decision, not a grammar-wide one. The two bounded-lookahead spots documented in principle 4 — constructor payload and FnType-vs-tuple — remain the only two.

**Implementation.** MVP 2, budgeted at 4 days: lexer tokens, grammar, type checking against `Bytes`, direct compilation to BEAM's bit syntax. The runtime's decades-mature bit-syntax optimizer does the heavy lifting; Ernest's compiler is a translator.

**Naming.** Section 5's paragraph title is "Bit arrays" (Gleam's term, cleaner than Erlang's "bit strings" which collides with `Text`).

## `Sys.stderr`, `Io.eprint`, `Io.eprintln` Removed, 2026-09-14

Same rationale as `Set(a)`. The stderr trio was inherited on "obvious symmetry with stdout" grounds. No paper program sends anything to stderr; no `Io.eprint*` call anywhere. The paper-program preambles that named `Sys.stderr` did so only because the report required it, not because they used it.

Removed:
- Report §9 loses `Sys.stderr` from "System references."
- §8's "System references" paragraph updated to list only `Sys.stdout` and `Sys.clock`; a stderr sink is now named as a paper-program-supplied assumption if needed.
- Appendix E.1 `Io.ern` loses `Io.eprint` and `Io.eprintln`.
- Paper programs' assumption paragraphs updated.
- README and plan updated.

**When it comes back.** When a paper program needs to write a diagnostic to a distinct stream from normal output. A runtime that provides a stderr process can still expose it as `Sys.stderr` under the "paper program names extra assumptions" rule (§8); it doesn't have to be language-required.

## `Set(a)` Removed From the Prelude, 2026-09-14

`Set(a)` and `stdlib/Set.ern` are removed. Neither the language grammar nor any paper program uses them. `List` earns its slot through grammar (`[]`, `+:`); `Map` earns its slot by being used in `tick-game` and `filesync`. `Set` was in the prelude only because "every stdlib has one" — the speculative-addition rationale the growth rule was written to prevent.

**Consequences.**

- Report §9 loses one line under "Built-in parameterized types."
- Appendix E loses subsection E.4 `Set.ern`; downstream subsections renumber E.5–E.11 down to E.4–E.10.
- §8's "like `List`, `Map`, and `Set` they are in scope everywhere" becomes "like `List` and `Map`."
- README's prelude and stdlib lists updated.

**When Set comes back.** When a paper program writes the pattern three times — graph work (visited-set traversal), tag membership at scale, deduplication of large streams — Set gets added back with a rationale entry. Until then it stays out. The growth rule cuts both ways: it defends against speculative addition and against retention out of habit.

**A note on cost.** `Set` had cross-node serialization as a runtime-provided type. Bringing it back later means either reasserting that runtime property or accepting `foreign type Set(a)` with the node-local constraint. Neither is expensive to reverse; the removal is not painting a corner.

## Against OTP as a Language Feature, 2026-09-14

Ernest does not adopt OTP's behaviours — `gen_server`, `gen_statem`, `supervisor`, `application` — as first-class language constructs. Supervision, request-reply servers, state machines, and restart strategies are ordinary Ernest programs written over the language primitives: `spawn`, `monitor`, `kill`, `Reply(a)`, `recv after`, and message types.

**Why.**

- **Small language.** OTP is a large surface with strong opinions accreted over three decades. Absorbing it into the report would double its length and force the language to have a view on restart policies, state-machine shapes, application boot order, and code loading — none of which Ernest wants to prescribe.
- **The primitives already reach.** Twenty lines of Ernest build a one-child supervisor with a timeout; forty lines build a three-child restart-on-fault. The `REPL` paper program shows the pattern with `monitor(child, Died) ... after 2000 -> { kill(child); Left(Timeout) }`. Composition of primitives, not new machinery.
- **Typed where OTP is not.** Ernest's supervision is written in code whose types the compiler checks — the parent's mailbox statically knows it receives `Died(Down)`, and `Reply(a)` linearity catches receivers that forget to answer. OTP's gen_server contract is convention checked by tests, not by types.
- **No canonical restart policy is one policy too many.** OTP encodes "one for one, one for all, rest for one" as options; Ernest treats these as expressible in ordinary code and lets programs choose their own shape where it fits.

**Cost, named honestly.**

- No canonical supervisor. Programs by different authors will structure supervision differently. The three-uses rule will likely surface a `Supervisor.ern` in the stdlib once a few paper programs write the shape; that is fine, but it will not be baked into the language.
- Adoption cost for experienced Erlang and Elixir developers. Familiar shapes must be re-expressed. The win — static guarantees OTP does not offer — is not obvious until the developer has written a few Ernest programs and felt the difference.
- The Ernest ecosystem provides shims for the libraries that ship with the Erlang/OTP distribution — `ets`, `crypto`, `base64`, `inets`, `filelib`, and similar — via the `foreign type` / `foreign fn` model of Appendix D. Third-party Erlang libraries (Cowboy, Ranch, Broadway) and the Elixir ecosystem are deliberately out of scope for the language project; a user who needs them writes their own shim, or a community writes one over time. The scope is narrow on purpose: the standard distribution is stable and small, third-party ecosystems are large and moving. Anyone can add a shim; the language project itself commits only to the standard-distribution shims.

**What this is not.**

- Not a claim that OTP is bad. OTP is the reason Erlang is used in production; its wisdom is real. Ernest's position is that the wisdom lives in patterns programmers can build, not in language mechanisms that constrain everyone. The pattern's shape is Ernest's, the wisdom is inherited.
- Not a claim that Ernest replaces Erlang. On BEAM, Ernest and Erlang coexist. An Ernest program that needs an Erlang OTP library uses a shim; an Erlang program that needs an Ernest type calls it through the same runtime.

## `Set(a)` Restored, 2026-09-15

`Set(a)` is put back into the prelude and stdlib. This reverses the 2026-09-14 removal (see the *`Set(a)` Removed From the Prelude* entry above).

**Why the removal was wrong.**

The 2026-09-14 removal applied the growth rule ("three uses before promoting to stdlib") to `Set(a)`. That was misuse of the rule. The growth rule is designed to prevent speculative *stdlib convenience functions* — someone adds `List.zipWithIndex` on aesthetic grounds, it accumulates. `Set(a)` is not a convenience function; it is a **fundamental container type** on par with `List(a)` and `Map(k, v)`. The right question is not "have paper programs used it three times?" but "would a reader expect this to exist in a typed FP language on BEAM?"

**Least surprise argues for `Set`.** Every stdlib in every typed FP language provides one: Elm's `Set`, Rust's `HashSet`/`BTreeSet`, Haskell's `Data.Set`, OCaml's `Set`, Gleam's `set`. A reader who wants deduplication, membership testing, or graph-work visited-tracking arrives at Ernest and looks for `Set(a)`. Not finding it is a genuine surprise — exactly what principle 1 rules against. That the four current paper programs don't happen to need it is a fact about the four programs, not about the language.

**The cross-node argument still applies.** `Set(a)` is runtime-provided with structural equality on `a` and cross-node serialization. That's the same standing as `List(a)` and `Map(k, v)`. Making Set a `foreign type` in stdlib would lose cross-node semantics. Keeping it as a built-in prelude type is the coherent design.

**Effect.** §9 prelude regains the `Set(a)` line. §8's "System references" paragraph reads "like `List`, `Map`, and `Set`" again. Appendix E gets a restored §4 `Set.ern`; downstream sections renumber E.5–E.12. README's prelude and stdlib lists gain Set back.

**Rule clarification.** The growth rule applies to *stdlib convenience functions*, not to fundamental container types. Adding `List.zipWithIndex` needs three-uses justification. Adding `Set(a)` doesn't, because a reader expects it. This distinction should have been named in the growth-rule entry originally.

## Section 0 Rewrite, 2026-09-15

External review found §0 too vague for a normative document — "in order" undefined, "surprise" unexplained for a first-time reader, "not too few" unfalsifiable. Rewrote §0's third paragraph and principle list. Content of the principles is unchanged; wording of §1, §2, §5 changes, and the intro paragraph gains a tie-breaking rule.

**Intro paragraph.** Replaced "The language is built on five principles, in order. The reader comes first." with a two-sentence statement of principle 1's role: it is the final arbiter that audits the effect of applying principles 2–5, measuring what a reader of Ernest code sees. This states operationally what "in order" was left to mean, and folds the "reader comes first" slogan into a sentence that earns its keep by explaining *why* principle 1 has the arbiter role.

Why *backstop* and not *lexicographic priority*. Two reasons. First, the log shows principle 1 acting as an audit over the results of applying 2–5 (see *Grammar Audit, 2026-09-12* for `if/then/else` and `Int` division), not as a first-choice tiebreaker over 2–5 in isolation. Second, lexicographic priority does not make sense across all pairs — "least surprise" does not sensibly override "simple to parse" (§4 has its own hard constraint the parser must satisfy). The right relation is: 2–5 are constructive; 1 audits.

**Principle 1.** Gains one sentence defining "surprise" — a design surprises when a reader who knows the rest of Ernest would predict different code from the same requirement. Prior wording ("measured by the resulting code, not by the rule") hinted at this but assumed the reader already knew what the contrast was with.

**Principle 2.** Loses the escape clause "unless what remains surprises more". Redundant once the intro paragraph states principle 1's backstop role; §2 now reads as a strict rule with the override located in the meta-rule rather than embedded in the rule itself.

**Principle 5.** Loses "but not too few". In this log the lower bound on smallness has always come from another principle — §4 stopped `let` from being dropped for four characters per line (see *Grammar Audit*); §1 stopped `Int.div(a, b)` from being the every-day form for division. §5 has never enforced its own floor. The qualifier claimed a role §5 does not play, and read as unfalsifiable in a document that otherwise names its tests.

**Not changed.** Principles 3 and 4 verbatim. Numbering unchanged (still five).

**Downstream.** `CLAUDE.md` line 11 updated to name the backstop framing (principles 2–5 constructive, principle 1 auditing). No change to the guide's §16 reference or to README's principle mention — both already read correctly against the new §0.

## Terminology Sweep, 2026-09-15

External review flagged the report as using informal or Ernest-invented terminology where a strict PLT / BEAM convention exists. Four names changed report-wide.

**arms → clauses.** `match` and `recv` branches were called *arms* (Rust and Scala 3 usage). Erlang, Haskell, and SML call them *clauses*; the same word applies to guarded alternatives, `receive` branches, and function heads. Since Ernest is on BEAM the Erlang convention wins. Grammar rules `Arm` and `AfterArm` renamed to `Clause` and `AfterClause`; every prose mention in §5, §6, §11, and the guide follows. §3's existing sentence "A function has one clause" now aligns with the new terminology (it was previously the only use of the word in the report).

**bit arrays → bitstrings.** The `<<...>>` construction/pattern-match syntax is directly Erlang's bitstring syntax, and the runtime compiles to BEAM's bit syntax. Erlang and Elixir both call the values *bitstrings*; calling them *bit arrays* in prose was inconsistent with the shape and the target platform. Grammar rule names `BitExpr`, `BitPat`, `BitSpec`, `BitSegE`, `BitSegP` are unchanged — the `Bit` prefix is short and still accurate.

**constructor payload → constructor field.** *Payload* was used both for what a constructor carries and for what a message carries when sent between nodes. The constructor sense is informal; standard PLT usage is *field* (Rust) or *constructor argument* (Haskell). Switched constructor uses to *field*. Message-payload uses (§3 foreign-value crossing rule; §7 fault causes) stay — that sense is standard networking terminology.

**ambient → top-level (or dropped).** *Ambient* was Ernest's chosen word for values in scope everywhere at the top level (`Sys.stdout`, `List`, `Map`, `Set`). Non-standard in PLT literature; *implicit* carries Scala baggage that misleads (Ernest's ambients are named at the use site, unlike Scala implicits). Renamed to *top-level binding* (§0), *top-level values* (§8), *top-level references* (§8, §11); in Appendix E "the ambient forms" became "the plain forms"; in paper programs "ambient runtime reference" became "runtime reference". Principle 3's operative rule — *visible when its name appears at the use site* — is unchanged; only the noun.

**What did not change.** `Address(m)`, `Reply(a)`, `Down`, `Peer`, `fault`, `with M` — these are Ernest's names for concepts the language introduces (or deliberately distinguishes from cognates in other languages). The audit found them non-standard *because they are new*; renaming would either lose meaning or copy an established name that carries different semantics. They stay.

**Historical entries.** Older dated entries below use the pre-rename words. The preamble at the top of this document now covers both this and the earlier principle-numbering shift.

## List and Concat Operators, 2026-09-15

External review kept pushing on `+:` (cons). The `+` character reads as arithmetic-adjacent — commutative, numeric — and cons is neither. The same objection extends to `++` (text concat). Two changes, taken together because the second falls out of the first.

**`+:` → `::` for cons.** Universal in typed-FP tradition: OCaml, SML, F#, Scala, Elm, Idris, Roc, Coq, PureScript. The one language that uses `:` alone for cons is Haskell, and Haskell can only do that because it uses `::` for type annotation (Ernest uses `:` for type annotation, so `::` is available for cons — the mirror image of Haskell). Cons is a grammar-level operator, right-associative, defined by the `ConsPat` production; renaming is a lexer/parser change, no semantic change. No collision: `::` is a new token, `:` is unchanged.

**`++` → `<>` for concat.** Gleam (Ernest's closest BEAM cousin) uses `<>` for text concat. Haskell uses it for any semigroup. Elixir uses it for bitstring/text. No `+` character, no arithmetic connotation. The tempting alternative was `@` (OCaml/SML/F#), but `@` in those languages means *list append* specifically — using it for text would surprise ML readers.

**And `<>` is overloaded, unlike `++` was.** `++` in the old design was Text-only (`Text.++`); list append lived at `List.append` with no operator form. That was inconsistent — some operators were type-overloaded (arithmetic across `Int`/`Float`), some were type-specific (`++`), some had no operator at all (`List.append`). The new `<>` uses the same type-directed name resolution as `+`: `Text.<>` for `Text`, `List.<>` for `List(a)`, `Bytes.<>` for `Bytes` (added when a paper program needs it). `List.append` in Appendix E becomes `List.<>`.

**Net result.** Operators that use `+` characters are exactly the arithmetic ones (`+`, `-`, `*`, `/`, `%`). Operators for sequence composition (`::` for cons, `<>` for concat) have neither `+` nor arithmetic connotation. Answers the mentor's objection completely, and closes the `List.append`/`Text.++` inconsistency along the way.

**Downstream.** Grammar rule `ConsPat = AtomPat [ "::" ConsPat ] .` (was `"+:"`). Section 2's binop rule lists `"<>" | "::"` in place of `"++" | "+:"`. Operator table updated. Precedence table updated (`<>` sits where `++` sat; `::` where `+:` sat). §5 patterns and §3 lists updated. Appendix E line `List.append : (List(a), List(a)) -> List(a)` is now `List.<>`. Guide §2.4 (lists), §13 (bitstrings), and the four paper programs updated.

**Not renamed.** Everything else in the operator table — `+ - * / % == != < <= > >= && || |>` — is unchanged. Prefix `-` is unchanged.

## Section 2 Tightening, 2026-09-15

External review found eight underspecified corners in §2. All eight closed with minimal additions; nothing changed semantically, only made explicit.

1. **Whitespace is now defined.** Space (U+0020), tab (U+0009), line feed (U+000A), carriage return (U+000D). Nothing else. Matches Go's minimal set; principle 5.
2. **BOM at file start is stripped.** One-line concession to Windows editors that add U+FEFF; without it, first-line errors would confuse users who don't know their editor added a byte. Least-surprise applied to real-world tooling.
3. **`_` alone is the wildcard, not an identifier.** Previous rule "`ident` begins with a lowercase letter or `_`" admitted `_` alone; §5's wildcard rule also admitted `_` alone. Resolution: identifier starting with `_` needs at least one further character. Same rule Rust and Roc use.
4. **`\u{...}` bounds stated.** Unicode scalar value: U+0000 to U+10FFFF, excluding surrogates U+D800-U+DFFF. Without this, `"\u{D800}"` would silently produce malformed UTF-8.
5. **Newlines in string literals forbidden.** `character` inside `char`/`text` literals excludes U+000A and U+000D; use `\n` or concatenation. Multi-line strings would have required either raw-string syntax (a second literal form — principle 2) or accepting silent newline handling (principle 3, hidden effect on whitespace). The minimal choice is the strictest.
6. **Integer literals are decimal only.** No `0x`, `0o`, `0b`. No digit separators (`1_000_000`). Principle 5. The standard library provides base parsing where needed. If bit-protocol paper programs demand hex, revisit; the growth rule applies.
7. **Prefix `-` precedence stated.** Tighter than any binary operator. Was implicit from Appendix A's `Unary = [ "-" ] Primary { Call }`; now stated in §2's precedence sentence.
8. **All eight follow the principles.** The additions define what was left undefined (principle 3 — nothing invisible, applied to the spec itself). None introduces new syntax (principle 5). The wildcard resolution and BOM handling reduce surprise for expected users (principle 1). No parser complication (principle 4) — every change is either a lexer constant table (whitespace set), a well-formedness check (Unicode scalar bounds), or a one-line early strip (BOM).

## `recv` → `receive`, 2026-09-15

External review found `recv` unnecessarily abbreviated. The saved three characters buy nothing: `receive` is Erlang's word for the same construct, and pattern-matching on a receive is not a hot inner-loop typing exercise. Renamed the reserved word.

**Effect.** §2's reserved-word list swaps `recv` for `receive` (still sixteen words). Grammar rule `RecvExpr` becomes `ReceiveExpr`. Every use of `receive { ... }` in §6, the guide, the four paper programs, and the implementation plan is updated. Erlang's `gen_tcp:recv/3` in the Erlang comparison stays — it's a foreign function name.

**Why the abbreviation existed.** Historically Ernest inherited `recv` from the pre-2026-09-12 version when it was a function taking a filter lambda. The function became a form with clauses on 2026-09-13; the abbreviation stayed by inertia. No principle argued for keeping it, and one — least surprise — argued against.

## `opaque` → `abstract`, 2026-09-15

External review objected: `opaque` describes the *property* (representation not visible from outside), not the *concept* (abstract data type). The mentor comes from Lisp and ML, where the standard term is *abstract type* — used in SML/OCaml module-signature literature, and in every textbook treatment of the concept back to Liskov's CLU.

Considered:

- **Keep `opaque`.** Precedent: Scala 3, Gleam, Racket. Modern FP-keyword lineage — three languages. But describes the effect, not the essence; the mentor's objection is real.
- **`abstract`.** ML tradition. Names the concept directly. Downside: OOP baggage — "abstract class" in Java/C# means "must be extended". Ernest has no inheritance, no classes, no methods, so the collision is *nominal* only. Reader has to reset once, not repeatedly.
- **`adt`.** Correct as an acronym but obscure. Principle 1 loss for first-time readers who don't know the jargon.
- **`encapsulate` / `sealed` / `private`.** Ernest-invented or borrowed from OOP methodology, without the meaning matching. Principle 1 loss on all three.
- **Drop the keyword entirely.** Let the presence of `with { ... }` on a type imply hiding. Fifteen keywords (principle 5). But intent becomes invisible — a reader has to know that `with` means opaque (principle 3 loss).

Taken: `abstract`. Ernest's type system is ML-family (Hindley-Milner, sum types, patterns) more than Scala/Gleam-family; the mentor's vocabulary is the audience's vocabulary; and the OOP collision is nominal since Ernest has no inheritance to attach "abstract" to. Naming the concept (ADT) beats describing the property (opacity) when the concept is well-established.

**Effect.** Reserved word `opaque` → `abstract` (still sixteen keywords). Grammar rule `OpaqueDecl` → `AbstractDecl`. Every `opaque type` in the report, guide, four paper programs, and implementation plan updated. §3 and §4's paragraph header "Opaque types" → "Abstract types". Prose adjective uses ("an opaque modification time") also updated to "abstract" for consistency — in context, "abstract" reads as "representation-hidden", which is the intended meaning.

**Not renamed.** No collision with any other keyword, so nothing else moves.

## Tuples: `#(...)` Prefix, 2026-09-15

External review flagged Ernest's parenthesis overloading. `(...)` played eight roles: grouping, function call, constructor call, tuple value, tuple type, function type argument list, type application, unit. Two real warts followed from letting `()` do both grouping and tuple formation: (a) the "tuples must have at least two elements" rule (no room for `(x)` alongside `(x)` grouping); (b) the fragile `(A, B) -> C` vs. `((A, B)) -> C` distinction (function of two args vs. function of one tuple, differ by one paren level).

Considered:

1. **Status quo.** Live with both warts.
2. **`#(...)` prefix on tuples** (Gleam convention). `#(a, b)` for value, `#(A, B)` for type, `#(p, q)` for pattern. Two-element minimum goes away; the paren-fragility goes away.
3. **Drop positional tuples entirely.** Force named-field records for every multi-value shape. Extends §3's "position hides intent" rule uniformly.
4. **Curly braces for tuples** (Erlang/Elixir). `{a, b}`. Collides with block/clause-list use of `{}` in Ernest — rejected outright.

Taken: option 2. Counted uses across the four paper programs, prelude, and report: roughly 30-40 tuple sites, most of them transient pairs (`(digits, rest)` from `List.span`, `(v, r2)` from a parser step, `(acc, apples)` in a fold accumulator). Dropping tuples (option 3) would have added about nine new named types to hold what today are transient values, plus turning every destructure and construction into multi-word constructor syntax. The cost was real and disproportionate: option 3 loses ergonomic pairs where they're useful, in exchange for a principle that §3 already applies to declared types.

Option 2 fixes both warts for the price of one `#` character per tuple site and one lexer/parser change:

- `#(x)`, `#(x, y)`, `#(x, y, z)`, ... — all legal; no minimum.
- `(A, B) -> C` — unambiguously function type (two args).
- `(#(A, B)) -> C` — unambiguously function type taking one tuple.
- `(e)` — unambiguously grouping.
- `()` — unit, unchanged.
- Empty tuple `#()` is not a thing — unit `()` covers zero-value case (principle 2, one way one job).

**Grammar.** `TupleType = "#(" Type { "," Type } ")" .` added; `TypeAtom`'s old `"(" Type "," Type { "," Type } ")"` removed. `Tuple = "#(" Expr { "," Expr } ")" .` (was `"(" Expr "," Expr { "," Expr } ")"`). `AtomPat`'s tuple form gets the `#` prefix.

**Not affected.** Type application `List(a)`, function call `f(x, y)`, constructor call `Some(x)`, function type `(A, B) -> C`, unit `()`, grouping `(e)`. All still use plain parens — each is now unambiguous from first-token dispatch or the presence of `->`.

**Bonus.** The decisions-log entry from 2026-09-12 (Grammar Audit) noted that `(A, B) -> C` vs `((A, B)) -> C` was a "remaining fragility" with a compiler suggestion on arity errors. The suggestion becomes unnecessary — the two forms are now clearly different (one uses `#`, the other doesn't).

## `Text` → `String`, 2026-09-15

External review pointed out that `Text` is Ernest-invented for the concept every mainstream language (Java, C#, JavaScript, Python, Rust, Go, Swift, Kotlin, Gleam, OCaml, SML, F#) calls `String`. The `Text` name comes from Haskell's `Data.Text`, which exists specifically to distinguish an efficient Unicode representation from the older, slower `String = [Char]`. Ernest has no such alternative representation to distinguish from — there is exactly one string type — so the Haskell motivation doesn't apply here.

The mentor's principle-1 argument: a programmer arriving at Ernest looks for `String` and doesn't find it. The `Text` → `String` mapping is one they have to learn for no local reason.

**Considered:**

- **Keep `Text`.** Haskell/PureScript precedent. Distinguishes semantic "Unicode text" from the byte-oriented meaning `String` has in older-C tradition. But Ernest already has `Bytes` for that role — there's no ambiguity to prevent.
- **`Str` (Roc's choice).** Terse. No baggage. But short abbreviations tend to read as unfriendly for the most-used type.
- **`String` (universal).** Every mainstream language. `Bytes` disambiguates from the older byte-string sense.

Taken: `String`. The Haskell motivation for `Text` doesn't apply — Ernest doesn't have two competing string representations — and universal convention beats invented distinction for Ernest's audience. Principle 1.

**Effect.** Type `Text` → `String`. Every reference in the report, guide, four paper programs, and implementation plan updated. Module file `Text.ern` → `String.ern` (Appendix E.5). Every function name that mentioned `Text` (`Int.toText`, `Char.toText`, `Bool.toText`, `String.toUtf8`, etc.) becomes the `String`-suffixed form. Lexical category `text` → `string` in §2's literals block and in `binop`/`literal` composition. Prose "text literal" becomes "string literal"; English uses of "text" (source text, "writes text to stdout") stay as English.

**Not renamed.** `SessionId.text` in the webserver paper program is a domain-specific getter on an abstract type — kept as-is (renaming it would change API meaning, not spelling).

## `()` → `Void`, 2026-09-15

External review continued: after the tuple `#(...)` rename removed one use of `()`, the unit type/value still overloaded parens for a third meaning (function call `f()`, empty argument list `() -> C`, and unit itself). Every process function's signature carried two of them: `-> () with () = ...`. For a non-ML reader, the pattern read as noise.

**Considered:**

- **Keep `()`.** ML/Haskell/OCaml/Rust tradition. Compact. Confusing for non-experts and adds a third meaning to `()`.
- **`Unit`.** Scala/Kotlin tradition. Named type, more readable, but abstract to programmers without PLT background. Doesn't fundamentally address the "why is this thing here twice?" question — just renames it.
- **`Empty`.** Plain English. But *type-theoretically wrong*: "empty type" in PLT literature means the uninhabited type (which Ernest already calls `Never`). Adopting `Empty` for a one-value type would collide with type-theory readers' expectations.
- **`Nothing`.** Two collisions: Scala/Kotlin `Nothing` is the bottom type (uninhabited, = Ernest's `Never`); Haskell `Nothing` is Maybe's no-value case (= Ernest's `None`). Both meanings are more common than "unit type"; using `Nothing` for unit would surprise readers from both worlds.
- **`Void`.** Swift/Java precedent (Swift's `Void` IS the unit type); C/C++/C#/TypeScript familiarity. "Void" reads as "no meaningful return," which is *exactly* what Ernest's unit is used for. No collision with Ernest's `Never` (which is truly uninhabited).

Taken: `Void`. The name says what the value means (no meaningful return) rather than what the type contains (which is what `Empty`/`Nothing` would suggest, misleadingly). Swift's use as a typealias for the unit type is direct precedent. C-family readers get it instantly; ML-family readers pay one bit of new vocabulary.

**Effect.** Prelude gains `type Void = Void` in §9.3. Grammar §3, §5, and Appendix A drop the `"()"` production from `TypeAtom`, `Primary`, and `AtomPat` — `()` no longer means unit as a type or value. Every `-> ()` becomes `-> Void`; every `with ()` initially became `with Void` on process functions; every `Address(())` becomes `Address(Void)`; every bare `()` value becomes `Void`.

**Refinement, same day: `with Void` → `with Never` for send-only functions.** With `Void` and `Never` now both plainly named, the difference between them mattered for signatures. `Void` (one-value type) as a mailbox says "the mailbox holds `Void` values, could receive them in principle" — invisible information. `Never` (uninhabited) says "the mailbox holds no values, statically cannot receive" — nothing invisible (principle 3). Every `main` and other send-only function in the paper programs and report was updated from `with Void` to `with Never`. `Address.call`-using functions kept polymorphic `with m` (the pattern already used by `ping` in ping-pong). §8.1 rewrote the "usually" guidance to name three cases: `Never` for send-only, a message type for receivers, polymorphic `m` for request-reply without a receive protocol. The `submitter` example on line 832 that previously stood alone with `with Never` is now the canonical shape rather than an outlier.

`main`'s canonical signature for a spawn-and-return program is `fn main() -> Void with Never = ...`.

**Not affected.** `()` remains as *empty argument list* in `f()` (call), `fn() = ...` (lambda), `() -> C` (function type with zero args). That's universal in every language with parenthesized calls and can't be changed. But `()` now means exactly *one* thing (empty argument list) instead of three.

**Compared to the tuple `#(...)` decision.** Same aesthetic — reduce parenthesis overloading. Together, the two changes turn `()` from a multi-role symbol back into a single-role one.

## `remote` Is Not Pure, 2026-09-15

An external reviewer caught a genuine contradiction: §0 defines *pure* as "result depends only on its arguments, and it affects nothing"; §6.7 claimed `remote` and `parallelRemote` were pure. But `remote(fn() = 42)` can return `Right(42)`, `Left(NoRemotePeer)`, or `Left(PeerLost)` depending on peer configuration and connection state — its result does *not* depend on the argument alone. Two calls at different times can return different values. The report contradicted its own purity definition.

**Two clean resolutions weighed:**

- **Drop the error return.** Redefine `remote : (() -> a) -> a` with the runtime falling back to local evaluation on any failure. That would make `remote` genuinely pure (an invisible evaluation strategy). Rejected: production distributed systems need to distinguish "no peer configured" from "peer disappeared mid-computation" — those are different operational problems with different responses. Hiding them behind fallback would make the API unhelpful for the reason distribution exists.

- **Add a mailbox effect.** `remote : (() -> a) -> Either(RemoteError, a) with m`. Admits what `remote` really is: an observable service that exposes runtime state through its return. Only callable from process code.

Taken: the second. `remote` and `parallelRemote` gain `with m`. The argument `f` stays pure (it must be, to serialize and run on a peer with no local context). §6.7 prose rewritten: `f` is pure but `remote` is not.

**Corrected the earlier `parallelRemote` decision entry.** The 2026-09-14 entry that positioned `parallelRemote` in the prelude claimed "Pure like `remote`" as one justification. That claim was already wrong on 2026-09-14; the reviewer surfaced it. The other justifications (symmetry with `remote`, runtime-optimizable) stand.

**Downstream.** Guide §11's two `main` functions that called `remote` and `parallelRemote` had been `with Never` after the earlier send-only sweep; both are now `with m` polymorphic. The Never sweep pattern (send-only → Never) still holds for functions that only `send` — but a function that calls `remote` is no longer send-only, so it doesn't fit that pattern.

**Principle 3** carried this decision: the effect was invisible in the type. Now it's visible.

## Effect Polymorphism Specified, 2026-09-15

The reviewer's second finding: the report allowed `List.map` with an effectful callback but had no rule for how an ordinary higher-order function like `fn apply(f, x) = f(x)` acquires its callback's effect. §6.1 said *"a function that calls a function with mailbox type M gets mailbox type M"* — fine when M is concrete, but silent when M is a type variable (the case that makes `apply` typable at all).

The report already used effect variables informally: `send : ... with m`, `Address.call : ... with n`, `ping(...) -> Void with m`. But it never said *effect variables exist as a language concept*. That's what needed spelling out.

**Choice weighed:** Full row-polymorphic effects (Koka style) vs. Ernest's one-effect-per-function model.

Ernest's model is single-effect. Adding effect polymorphism means promoting the effect slot to admit type variables, generalized like other type variables. Standard HM extension — comparable in complexity to record polymorphism, not to full effect systems.

**Alternative representations weighed:** an explicit `Pure` effect marker on every function type (uniform but verbose), vs. keeping "pure = no `with` syntax" (compact but requires a substitution rule for empty effect). Chose the second — matches Ernest's existing compactness bias, cost is a small extra rule in the type-printer.

**Effect.** §3.9 gains an *Effect polymorphism* paragraph:

- Function types have an effect slot; the slot's inhabitant is either a mailbox type or *empty*.
- Effect variables are type variables in that slot, generalized alongside other type variables in a `fn` definition.
- Empty effect has no syntax — a function type without `with M` has it. Effect variable bound to empty is elided at print time.
- Effect variables use the same lowercase identifier syntax; position in the type distinguishes their kind.

§6.1's mailbox-inference sentence expanded from one line to four: concrete/variable/pure calls each have a rule, and multi-call unification is stated explicitly.

**Consequence.** `fn apply(f, x) = f(x)` now has a specifiable inferred type: `((a) -> b with e, a) -> b with e`. `List.map`, `List.foreach`, `Map.map`, and user combinators follow the same rule. No stdlib special-casing.

**Implementation cost.** Modest. Standard HM extension: unification of function types acquires a fourth check (effect slot), substitution treats empty as a nullary term, generalization applies to effect vars, pretty-printer elides empty.

**Principle 3** again — an implicit inference rule made explicit in the type system.

## `Reply` Ownership Made Compositional, 2026-09-15

The reviewer's third finding: §6.6 gave a consumption rule for `Reply(a)` bound in a `receive` clause, but not for other bindings — function parameters, the `mk` callback of `Address.call`, helper calls, aliases, closures. The compiler could reject some obvious duplications but the rules were incomplete. The reviewer asked how the compiler prevents duplication through those routes while permitting delegation to a helper.

The rule that closes the gap was already in the implementation plan (*"Function signatures that take Reply(a) propagate the obligation, and a function that binds a Reply(a) without consuming it is an error at its own definition"*) — but the report didn't lift it to the normative level.

**Two paths weighed:**

- **Compositional static check.** Every binding of a `Reply(a)` — receive clause, function parameter, spawn-lambda capture — creates a static exactly-once obligation at that binding site. Delegation to a helper is legal consumption; the helper is itself checked at its definition. No analysis crosses call boundaries.
- **Runtime one-shot acceptance.** Compiler checks positions only. Runtime tracks answered replies; second `answer` on the same reply faults.

The reviewer noted these are different guarantees. Chose the first — matches Ernest's static bias (principle 3, nothing invisible) and the impl plan already assumed it. Runtime one-shot would silently degrade Reply from a static contract to a dynamic one.

**Effect.** §6.6 rewritten. Two paragraphs replace the old "Where Reply(a) may appear" and "Linearity" sections:

- **Legal positions** — same set as before, but written as a single rule with the aliasing prohibition explicit.
- **Exactly-once obligation** — every binding creates the obligation, checked at the binding site. Four consumption forms enumerated: `answer`, delegation to a helper with `Reply(a)` parameter, message-field send, spawn-lambda capture. Composition is spelled out: each function checked at its own definition. The `mk` callback of `Address.call` is a case of the same rule — its `Reply(a)` parameter obligates it to consume exactly once, which it does by embedding the reply in the built message.

Guide §5.4 updated: the "three legal forms" list becomes four (delegation to a helper split out from message-field send), and the compositional nature is stated explicitly.

**Principle 3** carried this decision: the missing rules made a category of Reply misuse invisible in the type system. Now the rule set is closed.

## Equality Policy for Polymorphic Types, 2026-09-15

The reviewer's fourth finding: equality on functions and addresses is banned (§3.10), but §3.10 didn't say what happens when a polymorphic function uses `==` on a type variable, or how container-key equality requirements propagate. `List.contains` uses `==` internally on its `a` — what does that mean for the type? `Map(k, v)` "requires equality on k" — checked when?

**Considered:**

- **Explicit typeclass-style constraint syntax.** `List.contains : Eq(a) => (List(a), a) -> Bool`. Adds a new type-level feature. Rejected — Ernest has consciously said no to typeclasses (decisions log entry against them earlier), and adding constraint syntax opens the door to more.
- **Ban polymorphic equality.** Only allow `==` on concrete types. Users must monomorphize; `List.contains` becomes per-type. Rejected — makes stdlib design absurd.
- **Runtime check.** `==` on functions faults at runtime, not compile time. Rejected — Ernest's static bias (principle 3).
- **Instantiation-time constraint check with no new syntax.** A polymorphic function that uses `==` gains an implicit equality constraint on the relevant type variable; the constraint is checked at each call site when the variable is instantiated. No new type syntax. Documented in prose plus Appendix E comments where relevant.

Taken: the fourth. §3.10 gains an *Equality on polymorphic types* paragraph specifying:

- Implicit equality constraint inferred from `==` usage.
- Constraint not in the type syntax; checked at instantiation.
- `Map(k, v)` and `Set(a)` propagate the same constraint on `k`/`a`.
- Stdlib functions like `List.contains` and `List.remove` propagate through their type parameter.
- Check is at instantiation, not at generalization — a polymorphic `equal` type-checks, and each call site verifies the substituted type.

Appendix E signatures for `List.contains` and `List.remove` gain a `// requires equality on a` comment pointing to §3.10. `Map` and `Set` type-header comments already carried the equivalent note.

**Tension acknowledged.** Not writing the constraint in the type syntax has a principle-3 cost — the requirement is invisible in signatures. The comment mitigates it, but a reader without §3.10 in mind might miss it. Judged worth the trade against the alternative of adding typeclass-adjacent syntax (principle 5, and the earlier decision against typeclasses).

## Annotations Describe Shape, 2026-09-15

The reviewer's fifth finding: some types the compiler infers cannot be written using Ernest's annotation grammar. Three cases exist after today's earlier fixes:

- Equality constraints on type variables induced by `==` usage (added in the equality-policy entry above).
- Exactly-once obligations on `Reply(a)` parameters (added in the Reply-ownership entry above).
- Kind distinction between value-type variables and effect variables — same identifier syntax, position in the type distinguishes.

All three are inferred from function bodies and callee signatures, not written by the user.

**Alternatives:**

- **Add constraint syntax** (Haskell-style `Eq(a) =>` or similar). Adds a type-level feature. Ernest has said no to typeclasses and adding constraint syntax opens that door.
- **Restrict inference** to only produce writable types. Would force users to monomorphize `==` and reject polymorphic Reply-taking helpers. Breaks reasonable stdlib design.
- **Document the split.** Say explicitly: annotations describe shape, inferred constraints follow from usage. Reader knows to look at the body (or documentation) for the full picture.

Taken: the third. §3.9's Effect-polymorphism block gains a closing paragraph naming the three cases where inference produces properties not in the annotation grammar. A reader who wonders "does this signature capture everything?" gets an honest answer: no, but here's what's missing and where to look for it.

**Cost.** Principle-3 partial loss — the constraints are not fully visible in signatures. The report acknowledges the loss and points at the sources. Comment annotations in Appendix E (for the equality constraint) mitigate for the stdlib.

**What this rules out.** A future addition of constraint syntax is not precluded. If Ernest later grows typeclass-like features, the "annotations describe shape" note becomes historical; the grammar would express more. This report simply documents the current state honestly.

## Polymorphic Empty Values and Monomorphic `let`, 2026-09-15

The reviewer's sixth finding: Ernest has many polymorphic empty values (`[]`, `None`, `Map.empty`, `Set.empty`, `Ets.new()` results) that a user typically wants to bind before using. §3.9 said flatly *"a `let` binding is not [generalized]"* and §4.6 said *"A binding is monomorphic"*. Left the question open: what happens when the RHS has free type variables that no immediate context pins down?

Two related sub-questions:

1. **What about `let m = Map.empty` in a block?** Both `k` and `v` are free at binding time.
2. **What about `let Map.empty = ...` at top level?** Prelude values need polymorphism to be reusable.

**Alternatives:**

- **Default free variables** to some type (`Never`, some placeholder). Silent, principle-3 problem.
- **Value restriction (SML style).** `let` generalizes when RHS is syntactically a value. Adds a distinction to the language.
- **Distinguish top-level from block `let`.** Top-level generalizes (needed for the prelude); block `let` stays monomorphic but allows free variables during inference, resolved by later use in the block. Type error if any variable remains free at block's end.
- **Reject bindings with unresolvable free variables.** Same as the third but stated as a rule.

Taken: the third. §3.9 corrected to distinguish top-level from block `let`. §4.6 gains a *Free type variables in a binding* paragraph specifying:

- Block `let` is monomorphic; free variables are unification variables during the block's type check, pinned down by later uses of the binding.
- If any variable remains free at block's end, the binding is a type error at its site.
- Two user recourses: type annotation on the `let`, or use in a context that determines the type.
- Top-level `let` may be generalized so polymorphic prelude values work: `let Stack.empty : Stack(a) = Stack([])` declares a polymorphic constant.

**Cost.** Small but real. The report previously suggested a uniform "let is not generalized" rule; now there is a top-level/block distinction. Argued for by necessity — prelude values need to be polymorphic — and by matching HM's usual value-restriction pragmatics. Reader gains one rule to learn; loses one uniformity.

**Consequence for paper programs.** All existing `let m = Ets.new()` and similar patterns already work: the subsequent usage (`Ets.insert`, etc.) resolves the free variables within the block. No paper-program change needed.

## Top-Level Initialization Specified, 2026-09-15

The reviewer's seventh finding: the report never said what happens between "the runtime loads the modules" and "the runtime calls `main`". Top-level `let` bindings need their initializers evaluated somewhere in there, but the semantics — when, in what order, in what process, with what effects allowed — was silent.

**Questions the specification had to answer:**

- Are top-level `let` initializers pure, or may they have mailbox effects?
- In what order are they evaluated?
- Are `Sys.*` references available to them?
- What about cycles?

**Alternatives:**

- **Effectful top-level lets in an implicit init process.** Adds a runtime concept (the init process, its mailbox). Also raises "which effects are allowed at init? Can it receive?" — a small design space that grows.
- **Lazy top-level lets.** Not evaluated until first access. Solves the ordering problem but shifts effect handling to the first accessor, and its effect leaks into the accessor's type. Fragile.
- **Pure top-level lets, eager, dependency-ordered.** Every initializer must be pure. The runtime evaluates them in topological order after Sys is bound and before `main` runs. Cycles are a compile-time error.

Taken: the third. It matches the paper programs (none has an effectful top-level `let` today), the stdlib (all constants), and Ernest's preference for statically-obvious semantics. Effectful setup belongs in `main` — where the reader looks for it anyway.

**Effect on the report.**

- §4.6 states the "must be pure" rule for top-level `let` initializers and points at §8.5.
- §8 gains a new §8.5 *Initialization* subsection specifying evaluation order, cycle rules, and `Sys` availability. Old §8.5 *Program termination* renumbered to §8.6.

**Cost.** Small. Adds one subsection, one rule. Rules out one flexibility (effectful init) that no paper program uses.

**Principle 3** carried this decision: the semantics of top-level `let` was genuinely undefined; readers had to guess. Now spelled out.

## Numeric Semantics and Fault Rules, 2026-09-15

The reviewer's eighth finding: fault rules and numeric edge cases were inconsistent or incomplete. Several genuine gaps:

- Integer division convention for negative operands was unspecified (`-7 / 3` — `-2` or `-3`?).
- `Int.mod` vs `%` — same convention? Not stated.
- Float division by zero — fault or IEEE?
- `NaN == NaN` — §3.10 said equality is structural; IEEE says false.
- `Float.compare(NaN, x)` — return what?
- Float overflow/underflow — unspecified.

**Choices made:**

- **Integer division: truncated toward zero.** Matches BEAM (`div`, `rem`), C, Java, Go. `-7 / 3 = -2`, `-7 % 3 = -1`. Chosen for platform consistency (BEAM) and minimum surprise for readers from C-family languages. Alternative (floored, matches Python/Haskell) rejected — less common in Ernest's audience.
- **`Int.mod` gives rem-semantics.** Same as `%`. The name overlaps with mathematical modulo (which is always non-negative), but changing to `Int.rem` would be a rename affecting Appendix E and paper programs, and readers from most languages find the current name intuitive. Documented in §3.1.
- **Float division by zero: IEEE 754.** Produces `Infinity` or `NaN`, does not fault. Faults are for BEAM-level catastrophes and one-of-a-kind partial operations, not for cases IEEE handles.
- **NaN in `==`: IEEE semantics as a stated exception to structural equality.** `NaN == NaN` is `false`. §3.10 acknowledges the exception explicitly rather than hiding it — structural equality is not literally true for Float, and pretending otherwise would surprise every reader from every mainstream language.
- **`Float.compare` on NaN: fault.** `Ordering` has no unordered case. IEEE's totalOrder was considered but rejected — it would let a program silently sort NaN into either extreme, which is worse than a fault. `Float.isNaN` (added to Appendix E.9) exists so callers can guard.

**Effect on the report.**

- §3.1 gains three paragraphs specifying Int arithmetic (unbounded, truncated division), Float arithmetic (IEEE, no fault on `/0`, `Float.compare` faults on NaN), and the Int/Float non-mixing rule.
- §3.10 gains a paragraph acknowledging Float's IEEE equality as an exception to structural.
- §7.4's "three deliberate exceptions" becomes four, with the `Float.compare`-on-NaN case added and Float arithmetic's non-fault behavior mentioned.
- Appendix E.9 gains `Float.isNaN : (Float) -> Bool`.

**Cost.** Moderate additions. The report was silent on real cases that any compiler must handle; now the answers are stated. No paper program is affected (none used negative division or NaN operations).

**Principle 3** again — undefined semantics is invisible in the type system and in the runtime behavior. Every gap surfaced by the reviewer was a real inference problem where a user reading Ernest code could not predict the outcome.

## `Bytes` and Bitstring Alignment, 2026-09-15

The reviewer's ninth finding: `Bytes` is defined as "a sequence of octets" (§3.1), but `<<...>>` syntax allowed arbitrary bit counts and was documented as producing a `Bytes` value. `<<x:size(4)>>` produces 4 bits — not a valid octet sequence. Contradiction.

The reviewer also noted the specifier defaults were conflated: the table row for `bits` and `bytes` said both "segment is a nested bitstring" — but BEAM distinguishes them by unit (1 bit for `bits`, 8 bits for `bytes`), and the difference matters for the size calculations.

**Alternatives:**

- **Rename `Bytes` to `Bitstring`.** Match Erlang's terminology — Erlang's `bitstring()` allows any bit count; `binary()` is the byte-aligned subset. Would follow the naming precedent we set when we renamed the notation to "bitstring" earlier. Cost: wide rename affecting Text.toUtf8, foreign fn returns, ETS entries, etc.
- **Split into `Bytes` and `Bitstring`.** Keep `Bytes` for byte-aligned, add `Bitstring` for arbitrary. `<<...>>` produces whichever fits, chosen at compile time from segment sizes. Cost: two types where one might suffice.
- **Restrict `<<...>>` to byte-aligned.** Keep `Bytes` = octets. Non-aligned constructions are a compile-time error (constant sizes) or a runtime fault (dynamic sizes). Simplest change; matches every paper-program use, which are all byte-aligned anyway.

Taken: the third. Ernest's paper programs are byte-aligned; forbidding non-alignment is a real restriction but has no cost in current use, and keeps the type system simple. Users who need bit-level manipulation without byte alignment must fall back to `foreign fn` and Erlang's `bitstring()`.

**Effect on the report.**

- §5.11's specifier table separates `bits` (unit 1) from `bytes` (unit 8) — the BEAM distinction, previously conflated.
- §5.11 gains a *Byte alignment* paragraph: total bit count must be a multiple of 8, compile-time error for constant-size violations, runtime fault for dynamic ones.
- §7.4's deliberate exceptions expands from four to five: bitstring construction faults on segment overflow or non-alignment.

**Cost.** One new fault case; a small restriction on `<<...>>` uses (all paper programs still work). Reader gets a `Bytes` type they can trust to be byte-aligned.

**What this rules out.** Bit-level manipulation without byte-alignment (e.g., building a 7-bit-total value) is not expressible in Ernest. If a paper program ever needs it, revisit — either add a `Bitstring` type as sibling to `Bytes`, or lift the alignment restriction.

## Reply Timeout Semantics: Late Answers and Mailbox Isolation, 2026-09-15

The reviewer's tenth finding: §6.6 said `Address.call` has a timeout and that a `Reply(a)`'s fresh identifier isolates it from the caller's mailbox, but never said what happens *after* the timeout. If the recipient answers late — after `Address.call` has returned `None` — where does the value go? Does it land in the mailbox as a stray message? Fault? Silently vanish?

Similar question about isolation: what exactly does "the caller's mailbox type is unaffected" mean? Can a reply value ever leak into the typed mailbox?

**Choices weighed:**

- **Silent discard.** Runtime deregisters the fresh identifier on timeout; incoming values tagged with it are dropped before reaching the mailbox. Simple, invisible to caller and callee.
- **Late reply becomes a stray message in the mailbox.** Would violate the mailbox type; not viable.
- **Late reply faults.** Punishes the recipient for slowness — often not their fault (network, scheduling). Not a good match for cooperative multi-process design.
- **Late reply arrives in a hidden auxiliary queue that the caller can inspect.** New concept, more surface. Rejected — no paper program has motivated this need.

Taken: silent discard. Matches BEAM's `gen_server:call` convention, matches Ernest's static isolation guarantee ("the caller's mailbox type is unaffected"), and requires no new concepts.

**Effect on §6.6.**

- New paragraph *Late answers* — after timeout the runtime deregisters the Reply's fresh identifier and silently discards subsequent `answer(r, v)` values. Applies to both `Address.call` (returns `None`) and `Address.callForever` (caller dies while waiting). The recipient's `answer` call itself always succeeds — the recipient cannot observe whether the caller is still waiting.
- New paragraph *Mailbox isolation* — the fresh identifier is known only to the allocating `Address.call`. Reply values reach the waiting call via that identifier; they never appear in the caller's declared mailbox, and the caller's mailbox type does not include them. Other messages flow normally.

**Cost.** Two paragraphs. No paper program change; the semantics matches what everyone was implicitly assuming. Now stated.

**Principle 3.** The behavior after timeout was invisible in the type system and undefined in the report. Explicit now.

## Ping-Pong Example: Main Must Wait For Workers, 2026-09-15

The reviewer's eleventh finding: Appendix B's ping-pong example spawns `pong` and `ping`, then returns from `main` — but per §8.6 the program ends when `main` returns, and any live process is killed with `ProgramEnd`. The example that is supposed to demonstrate two processes exchanging messages actually kills both before the first `send` goes out. The guide's §7.4 compounded the problem by asserting "when the last of them finishes, the program ends", which contradicts §8.6.

**Options weighed:**

- **`main` waits by monitoring pong.** Uses `monitor(pongAddr, PongDone)` and a `receive` in `main`. Pong dies with `Returned` when it processes `Stop`; `main` receives `PongDone(_)` and returns. Ping is on its way out at that point; if it's still alive it gets killed with `ProgramEnd`, which is correct — ping's work is done.
- **`main` calls `ping` directly instead of spawning it.** Cleaner shape (one spawn, one call), but leaves a race: `send(pongAddr, Stop)` is fire-and-forget, so pong may not have received `Stop` when `ping` returns and `main` returns and pong is killed with `ProgramEnd`. The example would then have unpredictable output.
- **Rely on message delivery being fast enough in practice.** Rejected — the report does not promise ordering between `send` completion and subsequent process death by `ProgramEnd`, and a tutorial example must not depend on unspecified timing.
- **Change §8.6 so the program ends only when all live processes have died.** Rejected — that is a big semantic change (implicit linking of all processes) that shifts responsibility for termination away from `main`. Erlang got by without it; Ernest can too.

Taken: monitor. Pedagogically this is a bonus — `monitor` is a real Ernest primitive that beginners will need anyway, and a "wait for a worker to finish" pattern is the most natural place to introduce it.

**Effect on the report and the guide.**

- Appendix B ping-pong: `main` now has mailbox `MainMsg = PongDone(Down)`. After the two spawns, `monitor(pongAddr, PongDone)` and `receive { PongDone(_) -> Void }`.
- Guide §7.4: same code change; prose replaced. The old prose ("`main` returns. The two spawned processes are still running. When the last of them finishes, the program ends.") was factually wrong per §8.6 and is now replaced by an explanation of why `main` has to wait on a real signal, and what `monitor` does.

**Cost.** Two extra lines in `main`, one new mailbox constructor, one paragraph of prose in the guide.

**Principle 1 (least surprise).** The old example silently exhibited a subtle interaction between §8.6 (program termination) and the naive spawn-and-return shape that a beginner would assume works. Now the example teaches the correct pattern the first time.

## `Bool.ern` Added, 2026-09-14

New stdlib module for boolean operations. Two functions:

```
Bool.not     : (Bool) -> Bool
Bool.toText  : (Bool) -> Text
```

**Why.** No boolean negation existed anywhere. `&&` and `||` are language operators, and `Bool` has `true`/`false` literals, but flipping a boolean required `if cond then false else true` or a full `match`. Every real program eventually wants `not`.

**Why stdlib, not operator.** Prefix `!` would work (parallel to prefix `-` for numeric negation, resolving via type-directed lookup to `Bool.not`), but a function is enough: `flag |> Bool.not` reads clearly, and function-value use cases (`List.filter(xs, Bool.not)`) benefit from having the name. Also honest: no paper program has written negation three times, so the language-surface path fails the growth rule. Stdlib is the low-cost place.

**Placement.** Appendix E.6, between `Char.ern` and `Int.ern`, grouped with basic scalar-value modules. Downstream renumbered: Int→E.7, Float→E.8, Optional→E.9, Either→E.10, Foreign→E.11.

**Naming.** Matches Ernest's stdlib convention: `Bool.not` (camelCase-ish since it's a single word), `Bool.toText` (matches `Int.toText`, `Float.toText`, `Char.toText`).

## Bit Operators as Stdlib Functions, 2026-09-14

Bit operators are added to `Int.ern` as ordinary functions, not to the language as operators:

```
Int.bitAnd     : (Int, Int) -> Int
Int.bitOr      : (Int, Int) -> Int
Int.bitXor     : (Int, Int) -> Int
Int.bitNot     : (Int) -> Int
Int.shiftLeft  : (Int, Int) -> Int
Int.shiftRight : (Int, Int) -> Int // arithmetic (sign-preserving)
```

**Why stdlib, not operators.** Symbol operators (`&`, `|`, `^`, `<<`, `>>`) are blocked: `<<` and `>>` are bit-array delimiters. Keyword operators (Erlang's `band`, `bor`, `bxor`, `bnot`, `bsl`, `bsr`) would add six reserved words and push the count from 16 to 22 — a 37% growth that principle 5 does not want. Stdlib functions cost zero language surface, and pipes make them read cleanly: `flags |> Int.bitAnd(mask) |> Int.shiftRight(4)`.

**Why now.** Bit operations are the natural companion to bit arrays. A program that pattern-matches on protocol bytes will want to compute checksums, mask flag fields, and extract bit ranges — bit arrays cover pattern matching, bit operators cover the arithmetic. Added on that symmetry, not on paper-program pull. Same growth-rule exception as `parallelRemote` and `Address.callForever`: if no paper program reaches for them within a few programs, revisit.

**Naming.** `Int.bitAnd`/`bitOr`/`bitXor`/`bitNot` — camelCase, matches Ernest's stdlib style (`Int.abs`, `Int.toText`). Erlang's `band`/`bor` are cryptic; Ernest chooses the readable form. `shiftLeft`/`shiftRight` for the shifts, with `shiftRight` being arithmetic (sign-preserving), consistent with BEAM's `bsr`.

**No logical shift-right.** For arbitrary-precision `Int`, logical shift right is not well-defined without a bit width. Programs that need bit-width-specific operations should mask first: `x |> Int.bitAnd(0xffff) |> Int.shiftRight(4)`. If a paper program needs a proper 32-bit or 64-bit logical shift three times, we add a `Bytes`-oriented library or fixed-width Int type at that point.

## Gleam Feature Pass, 2026-09-14

A systematic survey of Gleam's language features to check what Ernest is missing that its principles would embrace. Recording the conclusions so future work doesn't redo the analysis.

**Adopted from Gleam** (each has its own entry above):

- Pipe operator `|>` — see the entry.
- Bit arrays (`<<...>>` with the Erlang/Gleam specifier vocabulary) — see the entry.

**Rejected on principle**:

- **Labeled function arguments** — see the dedicated entry. Constructor named-fields are Ernest's higher-activation-cost alternative; the pressure to introduce a type when a signature widens is treated as a design win.
- **Type aliases** (`type UserId = Int`) — banned by §3. Wrapper types (`type UserId = UserId(Int)`) do the type-safety job without opening the aliasing machinery.
- **`panic` and `assert` as separate primitives** — Gleam has three fault-inducers (`todo`, `panic`, `assert`); Ernest has one (`todo(msg)`). Three intents collapsed to one mechanism keeps §7's "three deliberate fault exceptions" list from becoming four.
- **`let assert Pattern = expr`** — Gleam allows bypassing irrefutable-pattern requirement in `let`. Ernest requires irrefutable patterns in `let` deliberately; the fallback to `match` or `<-` is the point.

**Deferred under the growth rule**:

- **`use x <- callback(args)`** — generalizes Ernest's `<-` from Optional/Either to arbitrary continuations. Useful for resource acquisition, transactions, DB queries. Alternative today is just writing the lambda, six characters longer. Wait for three paper-program uses.
- **Function capture `f(_, y)`** — shorthand for `fn(x) = f(x, y)`. Useful for pipes when the value isn't the first argument. Ernest's subject-first stdlib reduces the need. Wait for pull.
- **List spread in construction `[..list, x, y]`** — Ernest has `+:` for prepend and `List.append` for concatenation; the construct-with-spread middle case is missing. Small ergonomic gap. Wait for pull.

**Handled differently but equivalently**:

- String concatenation (Gleam `<>`, Ernest `++`).
- Match syntax (Gleam `case ... { pat if guard -> ... }`, Ernest `match ... { pat when guard -> ... }`).
- List patterns (Gleam `[first, ..rest]`, Ernest `first +: rest`).
- Discard variables (both allow `_name` as unused-signaling binding).

**Not needed**:

- `const` declarations — Ernest has top-level `let`.
- `echo` keyword — Ernest has `Io.println`.
- String interpolation — neither language has it; both use concatenation.

**Ernest's genuine wins over Gleam** (worth noting so we don't lose them under future pressure):

- Typed mailboxes at the language level (`Address(m)`) — Gleam's `Subject(a)` is library-level.
- `Reply(a)` linearity with three consumption forms — Gleam has no static analog.
- Mailbox effect in the function type (`with M`) — Gleam does not track effects.
- Content-addressed code distribution (planned MVP 3).
- Smaller reserved-word count (16 vs Gleam's more permissive keyword set).

**Conclusion.** The substantive Gleam pass is done. Future adds should pass through the growth rule (three paper-program uses) or a specific principle-driven argument. Cosmetic imitation of Gleam is not a reason.

## Reasons Lifted Out of the Report

- `recv` is Erlang's `receive`: selective receive lets a process wait for a specific reply in the middle of a protocol without losing other messages; without it every process becomes a state machine, gen_server turned inside out. `recv` therefore does not require coverage, unlike `match`: the two forms share their syntax but not their semantics, since a `match` that finds no arm is a fault and a `recv` that finds no arm leaves the message in the mailbox. Cost O(n) in the mailbox, and a growing mailbox is not visible in the code, the same cost as in Erlang; the backpressure decision above covers the same problem from the sender's side.
- Braces and `;`: Gleam is the precedent. `if` is kept because its absence surprises more than its presence (Gleam's choice tried for a day).
- Two positional fields are forbidden because positions are invisible information and names are visible.
- Signature on opaque types instead of a naming rule: the interface gets a place.
- `via`: a narrower interface is a function, not a type rule; the adapter can do more than forward.
- The clock sends `()` because `msg : a` would be an existential type.
- One integer type, `Int`, with arbitrary precision — not `Nat` and `Int`. `Nat` promised non-negativity in the type at the price of a partial `-` returning `Optional`, which the tick game paid for and the grammar audit found also required signed literals to disappear. Totality lives in the prelude, not in a second numeric type.
- Program termination when `main` returns is Go's rule, least surprise for everyone but Erlang readers; `Deadlock` is free on one node and the best deadlock protection there is.
- Foreign values are node-local. A closure capturing a foreign value cannot be shipped to another node; the runtime faults at send with `Fault("foreign value cannot cross nodes")`. The alternative — silent transfer with late-failing operations on the far side, Erlang's shape — hides the error many hops from its cause and fails principle 3. Type-level tracking of "node-local" values was rejected: it would be a large mechanism for a narrow case.
- "What does not exist," formerly a section of the report: exceptions, macros, type classes, subtyping, effect systems, currying, existential types, mutation, layout, dynamic binding, session types, shared caches (the ETS problem), runtime-driven code replacement, content addressing. FFI was on the list until 13 September; see FFI.

## Later

Planned or considered, not in the language today.

- **Persistent data structures in the standard library.** Everything is immutable, so `Map.put` on a large map must share structure (Clojure) or be O(n). A requirement on the stdlib, not the language, but it must exist from the start; otherwise every stateful process is slow in a way the code does not show.
- **Content addressing, MVP 3.** Every definition gets a hash, and code follows messages to nodes that lack it. Not a core concept but the answer to how a node gets code; Erlang's module distribution is Erlang's weak point. Gives `Upgrade` over the network, types to nodes that have never seen them, and version mixing as an error at connection instead of undefined at `send`. Names as metadata and the codebase as a database remain outside.
- **Cross-version message types, MVP 3.** Two nodes with different versions of the same type. Undefined today because MVP 1 and MVP 2 are single-node. Two shapes considered for MVP 3: *reject at send* (each message carries the type hash, receiver refuses unknown hashes, sender gets a `Fault` or `Left` back — simpler runtime, forces version alignment) and *fetch on receipt* (receiver fetches unknown type definitions from the sender, closer to Unison — more flexible, more complex because types have transitive dependencies). Leaning reject-at-send for MVP 3, fetch-on-receipt as MVP 4+ if paper programs need it. Decision waits for MVP 3.
- **Local state in pure code.** Unison's `{State}` is not mutation but threading that the handler does for you; `Scope.ref` is real mutation for algorithms on arrays, Haskell's `ST`. Ernest has recursion and accumulators, and state lives in processes. Two reasons to want more: convenience (three counters as arguments), where the answer is to write the argument; performance (update in place), where the answer is persistent data structures, already a requirement. `let mut` is not introduced for either; the tick game confirmed it: three counters became a fold with a tuple accumulator, and when the tuple grows the answer is a named type with `..`. Unison's only real mutation in pure code is `{Scope}` with `Ref` and mutable arrays; it can be removed without losing any capability, only a constant, and a second effect would be abilities back. If a mutable array is needed anyway, it is a process that owns it, Erlang's ETS. To be tested further in the Unison week: an algorithm with three counters without `{State}`.
- **`Erl` in the stdlib.** `Erl.atom : (Text) -> Foreign` and `type Erl.Result(v, r) = Ok(v) | Error(r)`, so that shims do not redeclare them. A stdlib module (`stdlib/Erl.ern`), not a language addition; in the plan under MVP 2.
- **`Slot(a)` for language-level credit.** One-shot capability parallel to `Reply(a)`: a consumer allocates and grants slots to a producer via message, the producer sends by consuming a slot per message through `useSlot(s, v)`, and the consumer refills after processing. Same linearity check as `Reply(a)` — a `Slot` bound in an arm is consumed exactly once on every path. The compiler enforces that a producer does not send without permission. Deferred: only helps producer-consumer patterns, and the credit protocol as convention has not been written three times yet. When it has, this is the shape to reach for; see Backpressure above.
- **Idioms for the guide, not the report.** Links and supervisors: `monitor(child, Died)` and returning on `Died` is a link; a supervisor is fifteen lines of `spawn`, `monitor`, and `recv`. Parallel remote computation: `remote(f)` waits, so ten at once are ten local processes each calling `remote` and replying, which is what Unison does under `Remote.fork` and `await`, visibly.
- **Canonical formatter.** A gofmt-style formatter — mechanically simple given the recursive-descent grammar, small bounded lookahead, and no layout sensitivity. One canonical style, no configuration; killing style debates on day one is easier than after a community forms. A toolchain item, not a language item; expected as part of the `ern` binary. The guide will point at it when it lands.
- **A measure of the specification's length.** Wirth's Oberon report is sixteen pages and shrank with every revision. If this document, without examples, grows past ten pages, one concept too many has come in.

## Paper Programs and Measurements

- [`ernest-webserver.md`](ernest-webserver.md): web server with sessions. Gave `via`, timeout in receiving, signature on opaque types (which caught a call to an undefined `SessionId.parse` on paper). The process-then-table progression showed the value-versus-process-versus-table decision in twenty lines. Rewritten on 13 September with an ETS table for the session store, the first program to use `foreign fn`, and with `Reply(Bytes)` on `SockMsg.Read`, dropping the `HandlerMsg`/`Data(Bytes)` wrapper.
- [`ernest-filesync.md`](ernest-filesync.md): file sync between two nodes. Gave `monitor` and `kill` as functions, `Sys` as values, named fields, the clock with a value, backpressure as convention (a credit protocol in about ten lines per producer). Seven matches on `Either` across the whole program, none nested; five process loops in two programs where the earlier `recvFor` timeout arm was never reached; `sys` threaded as the first argument of six functions was the price of no dynamic binding.
- [`ernest-tick-game.md`](ernest-tick-game.md): snake game with ticks. Gave definitions in blocks (closes `where`), `At` and `Now`, `Sys` as the runtime's type, the value-versus-process criterion (one process per player was parallelism nobody asked for), the answer on local state (three counters became a fold with a tuple accumulator; when the tuple grows, a named type with `..`), and the case against `Nat`.
- [`ernest-repl.md`](ernest-repl.md): REPL with lexer, parser, evaluator, and `try` as a process. Gave `<-`, the warning about `self` in `spawn`, `TryError`. The evidence for `<-`: without it, 43 of 140 lines of pure code were `Left(e) -> Left(e)`, thirty percent that said nothing; with it, the same code is fifteen lines against twenty-four.
- All paper programs: `spawn(Local, ...)` after placement became an argument.
- [`ernest-comparison-webserver.md`](ernest-comparison-webserver.md): the same web server in Erlang. Without type signatures six percent more characters, almost all in the filter function (45 characters each time, twice), which was subsequently dropped when `recv` became a form with arms and `after`.

## Form of the Report

The language report is self-contained: no references to other languages, no history. The order runs from characters to programs, so that every term is defined before it is used: introduction with principles, notation, lexical elements, types, declarations and scope, expressions, processes, errors, programs, prelude, runtime requirements, grammar as an appendix, examples as an appendix. The grammar was written in full in EBNF, which found two ambiguities the prose had hidden: `match Peer { ... }` (constructor with fields, or `match` on the value `Peer`; the rule became that a constructor followed by `{` is always field construction, and `match (Peer) { ... }` for the other), and `after` as the first arm in `recv` (forbidden; `after` is last). The prelude was written as a list, which forced the contents of `Down`: `Down { reason : Reason, function : Text }` with `Reason = Returned | Killed | ProgramEnd | Fault(Text)`, and that `monitor` reports normal death as well. Containers are taken as the first argument in the prelude.

What stood in the specification as reasoning, comparison, or guidance has moved here; see "Reasons Lifted Out of the Report."

## Measure

The report without code blocks should stay under ten pages, Oberon's measure. At the split the language part was six pages; after paring, 2,100 words; as a report with distribution and toolchain, 3,200 words of prose, of which the prelude and the grammar are lists.

## Next Steps

The paper phase is done: web server, file sync, tick game, REPL, and the web server compared with Erlang. The background queue was dropped; it existed for backpressure, which waits. The Unison and Gleam weeks were dropped. Next: `counter` written by hand against the report, then a parser that reads Appendix A, then MVP 1 according to the implementation plan.
