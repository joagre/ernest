# Ernest: Decision Log

The reasoning behind the language report in [`ernest_report.md`](../ernest_report.md): what was taken from Unison and Erlang, what was tried and rejected, what is deferred, and what is undecided. The report says what holds; this document says why. The language was called Actorson until 12 September 2026.

**A note on principle numbering.** Some dated entries below reference "principle N" using the count at the time they were written. The count changed on 2026-09-14 from seven principles to five (see *Ambient Sys, Five Principles*), and one entry from 2026-09-12 renamed "principle 5" as what is now principle 4 (simple to parse). Read older references in that light; the current numbering lives in [`ernest_report.md`](../ernest_report.md) §0.

**A note on terminology.** On 2026-09-15 four names changed report-wide: match/recv "arms" became "clauses" (matching Erlang/Haskell/SML tradition); "bit arrays" became "bitstrings" (matching Erlang's name for the same `<<...>>` syntax); constructor "payloads" became "fields" (except message-payload uses); top-level values in `Sys.*` and elsewhere lost the "ambient" adjective, becoming "top-level bindings" / "top-level references". Later the same day the cons operator `+:` became `::` and the string-concat operator `++` became `<>` (see *List and Concat Operators*), the reserved word `recv` was spelled out as `receive` (see *`recv` → `receive`*), `opaque` became `abstract` (see *`opaque` → `abstract`*), tuples got a `#(...)` prefix (see *Tuples: `#(...)` Prefix*), the string type `Text` was renamed to `String` (see *`Text` → `String`*), and the unit type/value `()` was renamed to `Void` (see *`()` → `Void`*). Historical entries below use the older syntax; the current forms live in [`ernest_report.md`](../ernest_report.md). On 2026-09-17 the unit type/value `Void` became `Unit` (see *`Void` → `Unit`*); entries dated before that keep `Void`.

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

The toolchain went into the report as section 11, as a contract rather than a manual: the commands, their arguments, the files they read and write, and nothing about output, exit codes, or the REPL's appearance; it defines what a program is in practice, and section 8's `Sys` and peers need an address. Distributed programming does not go into the report: a report says what holds, and how to build is another genre. It becomes a third document, [`ernest_guide.md`](../ernest_guide.md), with distributed programming as one chapter beside error handling and process design, written from the paper programs once the compiler runs them.

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

**Language.** What [`ernest_report.md`](../ernest_report.md) defines: syntax, types, processes, evaluation rules, the five principles. This is the small, hard part. It doesn't change with new libraries.

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

**Paper programs updated.** `Map.delete` → `Map.remove` in [`examples/tick_game.ern`](../examples/tick_game.ern); `Optional.flatMap` → `Optional.andThen` in [`examples/webserver.ern`](../examples/webserver.ern). The implementation plan's note on `<-` desugaring reads `Optional.andThen` now.

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

## Sixth-Round Review Response: Type-Member Ownership, Concrete Operators, Path Rules, 2026-09-16

Sixth round flagged six items (NR01–NR06) plus small consistency edits.

**NR01 — Type-member namespace ownership.** Under the new module system, `abstract type Stack` in `main.ern` produces the qualified name `Main.Stack.push`, but §11.2's lowercase-path-mirror rule would look for it at `main/stack.erc`. Ambiguous: the operation is compiled into `main.erc`, not a separate file.

- **State ownership in the compiled interface.** Taken. §4.2 now says: "A type-member namespace belongs to the file that declares the type. `abstract type Stack` in `main.ern` (namespace `Main`) means the type `Main.Stack` and every member `Main.Stack.*` is defined by `main.erc`; the compiled interface records that ownership so `Main.Stack.push` loads from `main.erc`, not from a hypothetical `main/stack.erc`." §11.2 mirrors: "For a type-member reference `A.B.C.T.member`, the loader consults the compiled interface of `a/b/c.erc` (which owns type `T`); the loader does not look for `a/b/c/t.erc`."
- **Collision rule.** Also taken: if `main/stack.ern` declares any `Main.Stack.*` symbol, the two files collide on the same qualified name — compile-time error at load.

**NR02 — Concrete-type operators.** Previous wording said the single-typename declaration prefix was "for abstract-type accessors". §4.8 promises per-type arithmetic operators, but concrete types couldn't declare them under any legal form.

- **Extend the type-name-prefix rule to any locally declared type.** Taken. §4.2 rewritten: "Type-member declarations carry the type's prefix. A locally declared type `T` — whether concrete (§4.3) or abstract (§4.4) — creates a nested namespace `T` inside its module. Members of `T` are declared with `T.` as a single-typename prefix (`fn Distance.+`, `let Stack.empty`, `fn Stack.push`)." §4.4 reworded to make the abstract-type-specific rule an *additional* restriction (signature-listed constructor access), not the whole rule.
- **§4.8 updated** to cite the concrete example: `export fn Distance.+(Distance(a), Distance(b)) -> Distance = Distance(a + b)`.

**NR03 — Canonical namespace capitalization.** Previous "case-preserving typename form" was under-specified.

- **First-letter-cap, one-to-one with lowercase paths.** Taken. §4.2: "each namespace segment is the *canonical typename form* of the corresponding path segment — the segment with its first ASCII letter uppercased and the rest preserved. `http.ern` → `Http`; `http_server.ern` → `Http_server`; `httpv2.ern` → `Httpv2`."
- **Case-collision scope clarified.** Applies to path-derived module segments (trivially satisfied under canonical form). Type-member namespace segments are the programmer's choice and may differ in case at their author's discretion.

**NR04 — Output paths and cleanup with an explicit source root.** Reviewer's counterexample: `ernc -I src -o build src/net` should write `build/net/http.erc` (mirroring the source root), not `build/http.erc` (mirroring the argument). Cleanup should not treat `build/main.erc` as orphaned when `src/main.ern` still exists.

- **Explicit formula: `output = build-dir / relpath(source-file, source-root)`.** Taken.
- **Default `build-dir` = source root when `-o` omitted.** Taken.
- **Cleanup scope = the build subtree mirroring the compiled source subtree.** Taken. `ernc -I src -o build src/net` sweeps `build/net/`, not `build/`.

**NR05 — Path validation scope.** Reading the previous wording literally, `--load-path .` with `.ernest/` under `.` would reject `.ernest/` as an invalid namespace segment.

- **Apply path shape to files considered as modules only.** Taken. §11.1: "For each `.ern` file the compiler considers as a module, and each intermediate directory component between it and the source root, the name must match [the shape rule]. ... Files outside module consideration (`.ernest/` configuration, README files, editor artifacts) are ignored — the shape rule does not scan a tree looking for offenders, it validates each path that is being compiled or loaded." §11.2 parallel.

**NR06 — Appendix D decoding claim.** Previous text said a shim could decode `{ok, V}` from a raw return via an Ernest `match`. `Foreign` is opaque; ordinary `match` cannot destructure raw atoms.

- **Retract the raw-decode claim.** Taken. Rewrote the paragraph: "An API returning that shape needs a foreign adapter that returns the declared Ernest representation — either an Erlang helper module that rewrites `{ok, V}` to `{'Right', V}` before it crosses the boundary, or explicitly declared foreign decoding functions on the Ernest side. An ordinary Ernest `match` cannot destructure the raw `{ok, _}` term directly."
- **Rephrased the "An Erlang-side module is needed only to catch" sentence** to apply specifically to this ETS example.

**Small consistency edits:**

- §4.2: local declaration wording now says "the compiler exports it as `Net.Http.parse` *when the declaration is marked `export`*".
- §4.4: signature-listed constructor access separated from `export` visibility. A signature entry can be private (no `export`) if used only inside the module.
- Appendix E headings: `Io.ern` → `io.ern` (namespace `Io`), same for `List.ern`, `Map.ern`, `Set.ern`, `String.ern`, `Char.ern`, `Bool.ern`, `Int.ern`, `Float.ern`, `Optional.ern`, `Either.ern`, `Foreign.ern`. File names in lowercase per §11.1; namespace spelling remains capitalized.
- Appendix F glossary: `Reply(a)` entry expanded to list all six consumption forms and note the reply-carrying-types extension. `top-level binding` entry distinguishes user-declared (module-scoped, with `export` for external visibility) from runtime-provided (`Sys.*`, prelude, in scope everywhere).

**Cost.** Six paragraph-level edits plus Appendix E heading sweep plus two glossary rewrites. No new grammar production; the type-member-prefix rule was already in `DeclName` (single-typename prefix), the change is that concrete types can use it too.

**Principle 1 (least surprise).** A reader can now predict, from a qualified name like `Main.Stack.push`, which file compiles it and where the loader finds it — from a rule the report states rather than by filesystem probing.

**Principle 2 (one way).** The type-member-prefix rule applies uniformly to concrete and abstract types; §4.4 adds a restriction (signature-listed constructor access) on top of the general rule instead of being a separate rule.

## `ernc` Directory-Mode Cleans Stale `.erc` Outputs, 2026-09-16

Author asked whether `ernc` should delete `.erc` outputs in `build/` whose source `.ern` no longer exists under `src/`. Real risk: `ern` finds `.erc` files by namespace-to-path mapping on the load path, so a stale `.erc` for a deleted source silently gets loaded and linked against current sources — silent version skew, mysterious runtime errors.

**Choices weighed:**

- **Clean sweep of stale `.erc` after successful directory-mode build.** Taken. Only `.erc` files and directories that become empty are removed. Extension-scoped so the user's non-Ernest files in `build/` are safe.
- **Leave stale outputs; require `rm -rf build/` manually.** Rejected. Silent version skew is worse than automatic cleanup for a tool that owns its output extension.
- **Manifest file listing produced outputs.** Rejected. Adds hidden state; a wrong or missing manifest fails silently. The source-tree + build-tree + extension rule is self-explanatory.
- **Delete any file not currently produced.** Rejected. Would nuke user files (READMEs, tarballs, editor backups) placed under `build/`.

Taken: extension-scoped cleanup. `--no-clean` for the rare "keep stale outputs" case.

**Effect on §11.1:** one new paragraph ("Build-directory cleanup"). Cleanup applies only in directory mode (`ernc [-o build] src-dir`), not single-file mode. Only `.erc` files and directories that become empty after removing them are touched; any other file is left alone.

**Cost.** One paragraph in the report. Implementation: one walk over `build/` after compilation.

**Principle 1 (least surprise).** A user who removes a source file and rebuilds gets a `build/` that mirrors the source. No detective work to figure out why an obsolete function is still being called.

**Principle 3 (nothing invisible).** The compiler's ownership of `.erc` is stated. The user knows exactly what will be removed and what won't.

## `main` De-Specialization; Source Root; No More "Root Namespace", 2026-09-16

Author noticed that "root namespace" appeared in several places (guide §6.1, report §4.2) without being defined. The term was overloaded:

1. The **prelude and built-ins** (`List`, `Optional`, `send`, ...) — unnamed top of the hierarchy provided by the runtime.
2. **`main.ern`** — where I had claimed the file's declarations weren't nested under any typename.

Under strict file-mirrors-namespace (§4.2), `main.ern` at the source root should map to namespace `Main` (typename form of the filename stem), same as any other file. The claim that `main.ern` was at "root" was a special case that predated the file-mirrors-namespace rule.

**Choices weighed:**

- **Keep `main.ern` as a special-case root file.** Rejected. Adds an ad-hoc rule to the module system; §8.1 already contradicted §4.2 on this point.
- **De-specialize `main`.** Taken. `main` is a naming convention; any file can declare `export fn main`. Runtime picks via `ern module.erc` (defaults to the loaded module's `main`) or `ern --main Qualified.Name` override.
- **Require `--main` at every run.** Rejected. More explicit but verbose for the common case; the default-plus-override pattern matches Java, Node, Rust binaries.

**What changes.**

- **§8.1 rewritten.** Entry point is a `fn () -> Void with m` in any module. Runtime resolves it as `export fn main` in the loaded module, or via `--main Qualified.Name`. Multiple entry-point modules per project are legal (a service main, a migration main, a bench main).
- **§4.2 clarified.** Every user declaration lives at some namespace determined by its file's path. A file at the source root has a single-segment namespace (`main.ern` at namespace `Main`, `net.ern` at `Net`). The prelude occupies the unnamed top of the hierarchy — provided by the runtime, not by user code.
- **§11.1 gains an `-I src-root` flag** explicitly. Namespace is derived from path relative to the source root; default is the current directory (single-file mode) or the directory passed to directory mode.
- **§11.2 gains `--main Qualified.Name` flag.** Default entry is `export fn main` in the loaded module.

**Ripple effects:**

- Every existing `fn main() = ...` in paper programs, guide checkpoints, and Appendix B examples now needs `export` — otherwise `ern` can't find it. `sed` handled the mechanical rename.
- Guide §1.1: "`main` is special" → "`main` is the conventional entry-point name".
- Guide §6.1 example: comments changed from `// main.ern  (root namespace)` to `// main.ern  (namespace Main)`. Added an "Entry point" paragraph explaining `ern` lookup and `--main`.
- Guide §6.2 Stack example: acknowledged that external names would be `Main.Stack.push` because `main.ern`'s namespace `Main` prefixes everything. Internal use is unchanged.
- §4.4 abstract types example updated to reflect the namespace.

**Cost.** ~30 lines edited across the report and guide, sed pass on paper programs. No new mechanism; a simplification of an inconsistency.

**Principle 2 (one way).** File-mirrors-namespace is the single rule. `main.ern` is no longer an exception.

**Principle 1 (least surprise).** A reader looking at `main.ern` no longer wonders why its rules differ from every other file. `main` is just a function name that the runtime looks up.

## `export` Keyword; Declarations Use Local Names, 2026-09-16

Under strict file-mirrors-namespace (R17), every qualified declaration repeated its file's path prefix — `fn Net.Http.parse` in `net/http.ern`. Redundant with the path enforcement itself.

**Choices weighed:**

- **Keep the qualified declaration form.** Rejected. High redundancy scales badly with namespace depth; refactoring a namespace touches every declaration in every file.
- **Drop the qualified form; use a visibility keyword.** Taken. Reserved word 16 → 17: `export`. Declarations in a file use local names; the compiler exports `export`-marked ones at the file's namespace.
- **Rely on naming convention (uppercase leading char) for visibility.** Rejected. Ernest's identifier rules already use uppercase for typenames and lowercase for `ident`, so a leading-case convention isn't free. A dedicated word (`export`) is clearer and language-enforced.
- **Underscore-prefix for private (`_helper`).** Rejected. Convention-only, not language-enforced; `_ident` is already a valid identifier that isn't a wildcard.

**What changes.**

Grammar:

```
Declaration = [ "export" ] ( TypeDecl | AbstractDecl | FnDecl | LetDecl | ForeignDecl ) .
FnDecl      = "fn" DeclName "(" [ Param { "," Param } ] ")" [ Return ] "=" Expr .
LetDecl     = "let" DeclName [ ":" Type ] "=" Expr .
DeclName    = [ typename "." ] ( ident | binop ) .
```

`DeclName` allows an *optional single* typename prefix — for abstract-type accessors only. The file-namespace path prefix is never written in a declaration.

Semantics:

- A file at `a/b/c.ern` provides declarations at namespace `A.B.C`.
- Declarations without `export` are private to the module.
- `export fn foo(...) = ...` in `net/http.ern` is exported as `Net.Http.foo`.
- Abstract-type accessors carry the type name as prefix: `fn Stack.push(...)` — this remains the one qualified-declaration form, needed because an abstract type creates a nested namespace inside its module.
- Constructor visibility follows the declaring type.
- Cross-module references use `Net.Http.foo` unchanged.

**Effect on the report.**

- §2.4: reserved words 16 → 17, `export` added.
- §3 top grammar block and Appendix A: `Declaration` gains optional `export`; declaration-name productions use `DeclName` (single-typename prefix maximum). `QTypeName` production removed as no longer referenced by declarations.
- §4.2 rewritten around "files are namespaces; declarations are local; `export` marks the boundary".
- §4.4 abstract types clarified: the type creates a nested namespace, accessor definitions use the type-name prefix.
- §4.6 top-level `let` reworded to reference `DeclName`.
- §4.7 foreign declarations note `export` support.
- Appendix D (Ets.ern) rewritten with `export` on the interface and local names throughout; `raw` bindings unqualified without `export`.

**Effect on the guide.**

- §6.1 Net.Http example rewritten with `export type Request`, `export fn parse` and no file-namespace prefix. New paragraphs: "files are namespaces; declarations are local; `export` marks the boundary; external references use the qualified name".
- §6.2 Stack example uses `export abstract type Stack(a) = ...` with `export fn Stack.push(...)` accessors — the single-typename prefix pattern.
- §7.3 foreign example: `export foreign type Table(k, v)`, `export foreign fn member(...)` in `ets.ern`.
- §7.5 shim: `foreign fn rawLookup(...)` unqualified (private), `export foreign fn lookup(...)` for Store.
- FAQ "no import" answer rewritten to reference `export`.

**Effect elsewhere.**

- Paper programs (Appendix B in report, examples/repl, filesync, webserver, tick_game; the Erlang comparison, since removed): no change needed. These are single-file programs at the root namespace; their `fn StatusCode.render(...)` etc. are abstract-type accessors, which keep the type-name-prefix form. `export` is optional in a single-file program (nothing else references them).
- Implementation plan: reserved words count updated 16 → 17.

**Cost.** ~40 lines of edits in the report, ~30 in the guide, one new reserved word. No new type-system mechanism.

**Principle 2 (one way).** The file's namespace is stated once — by the file's path — instead of repeated on every qualified declaration.

**Principle 5 (small).** Reserved word count +1. In exchange, the report loses a whole failure mode (mismatched declaration prefix vs file path) and refactoring becomes proportional to the change.

## `ernc` Directory Mode; Output Dir Auto-Creation; Path-Shape Rejection, 2026-09-16

Three toolchain decisions to complete the lowercase-paths story:

**Choices weighed:**

- **`ernc` compiles a whole tree.** Taken. `ernc [-o build-dir] src-dir` walks the source, compiles in dependency order, mirrors the tree under `build-dir`. This avoids recursive-make and keeps dependency tracking in the compiler that already knows the graph.
- **Auto-create output directories.** Taken. `ernc` runs `mkdir -p` for `build-dir` and any missing intermediates. Matches standard compiler behavior (Rust, Go, etc.); saves users from "output directory does not exist" papercuts.
- **Rejected: leave directory creation to the user.** Bad ergonomics for a common case; the rare wrong-place-creation is caught by a wrong `-o` argument, not by the OS.
- **Reject non-lowercase source paths at compile time.** Taken. Consistent with the case-fold-collision compile-time error from the previous entry. `ernc` errors on `lib/Net/http.ern` with a specific message naming the failing component.
- **Rejected: silently lowercase source paths.** Would leave the on-disk convention wrong and cause confusion in editors and shell tools.
- **Rejected: warn but accept.** Warnings are ignored; the whole point of the lowercase rule is portability, and portability is not a soft requirement.
- **Boundary: apply the rule below the source/load root, not to the root itself.** Taken. `Lib/net/http.ern` is fine; `lib/Net/http.ern` is not. The root is the user's choice of packaging location; below the root, the compiler is authoritative.

**Effect on §11.1:**

- Added `-o build-dir` flag and directory-mode: `ernc [-o build-dir] src-dir` compiles the tree.
- Auto-create output directory and intermediates.
- New "Path shape" paragraph: each `.ern`/`.erc` filename stem and each intermediate directory component below the root must match `[a-z][a-z0-9_]*`. Extensions are exactly `.ern` and `.erc`. Violation is a compile-time error with a specific message.

**Effect on §11.2:**

- Runner enforces the same path-shape rule on load-path directories. `.erc` files or directories whose names fail the rule are rejected at load.

**Cost.** Two paragraphs (one new in §11.1, one clause added to §11.2). No new mechanism beyond the compiler's existing dependency-graph work.

**Principle 1 (least surprise).** A macOS or Windows developer opening an Ernest project sees `lib/net/http.ern` consistently. The compiler stops silent variants from creeping in.

**Principle 3 (nothing invisible).** Path shape rejection happens loudly at compile time; no hidden lowercasing, no runtime path-search that might succeed for one filesystem and fail for another.

## Lowercase Load-Path Segments, 2026-09-16

Author noticed that the guide's §6.1 example (`net/Http.ern` under the previously written mirror rule) implied a filesystem convention that would silently break on case-insensitive filesystems (macOS default, Windows). Two Ernest typenames differing only in case (`Http` vs `HTTP`) sit as distinct files on Linux but collide on macOS — a portability trap the language spec should not enable.

**Choices weighed:**

- **Case-preserved paths (`Net/Http.erc`).** Direct mirror of qualified names, zero mental translation. Rejected — silent portability failure across filesystems.
- **Lowercase paths (`net/http.erc`) with compile-time case-fold-collision error.** Portable across all mainstream filesystems; `Http` and `HTTP` in the same program produce a compile-time error regardless of OS. Aligns with BEAM's own lowercase-atom module names. Small mental translation between code and paths, comparable to Java's package-vs-class case rule.
- **Some case-preserved, some lowercased.** Rejected — a partial rule needs its own conventions and would surprise readers more than either uniform rule.

Taken: lowercase paths, with case-fold collision as a compile-time error.

**Effect on the report:**

- §4.2: `Net/Http.ern` → `net/http.ern`; `Net/Http/Header.ern` → `net/http/header.ern`. Added: "namespace segments are typenames in the source, and path segments on the load path are their lowercase forms; two namespace segments in the same program whose lowercase forms coincide is a compile-time error."
- §11.2: replaced the example-only mention with a rule: "the compiled module for namespace `A.B.C` is `a/b/c.erc` on the load path, where each path segment is the lowercase of the corresponding namespace segment."
- Guide §6.1 updated to match (paths lowercased; the compile-time collision noted).

**Why this preserves the file-beside-directory (Java-style) layout (§A of the earlier discussion):** the change is purely path-casing. `Net.foo` still lives in `net.ern` at the top level, `Net.Http.foo` still lives in `net/http.ern`. Only the casing of the path components changed.

**Cost.** Two sentence rewrites in the report, two in the guide. No new mechanism.

**Principle 1 (least surprise).** A macOS developer trying an example a Linux developer wrote no longer hits a filesystem mystery; the case-fold rule is caught at compile time on every OS.

**Principle 5 (small).** The one-sentence rule replaces implicit convention.

## Guide Round 3: Example Repairs, Setup Concreteness, Small Wording, 2026-09-15

Third-round guide review closed most concerns. Three example repairs plus small edits applied:

**Example repairs:**

- **§4.6 Upgrade syntax error.** A semicolon appeared between a match clause's expression and the next `|`. Semicolons separate block statements; match clauses use `|`. Removed the errant semicolon.

- **§5.5 game example — accessor and timer multiplication.** Two bugs:
  - `World.score(w)` assumed an auto-generated accessor. Replaced with pattern destructuring: `fn step(World(score = n) : World) -> World = World(score = n + 1)`.
  - The single-function `game` scheduled a new `After` timer on every entry, including the `Input(_)` branch that loops back. A burst of inputs would multiply pending timers. Split into two functions: `game` schedules exactly one timer, then hands off to `waitForTick`, which handles inputs without re-scheduling. Only a `Tick` returns control to `game`.

- **§2.7 Either example — filesystem-based `readAndParse`.** Was declared pure (`-> Either(FileError, Config)`) but called `Fs.read`, which requires an effect; also referenced undefined `Fs.read`, `FileError`, `Config`, `parseConfig`, and used `|>` before its introduction in §2.8. Replaced with a self-contained pure `positiveInt : (String) -> Either(String, Int)` using only `String.toInt` and `Either.fromOptional`, with three expected outcomes stated explicitly.

**Setup and command corrections:**

- **§1 configuration setup.** Previous wording claimed the report requires `.ernest/` to exist. Report §11 documents the setup command but does not explicitly state the missing-directory behavior. Rewrote as a concrete procedure: `ern --create-config-dir .` before the first run; the peer list can remain empty for local examples. The setup step is placed before `ern hello.erc`.

- **§6.1 command option order.** Changed `ern main.erc -pa .` to `ern -pa . main.erc` to match the option-before-positional convention documented in report §11.

**Small wording:**

- **§0 checkpoint promise.** Softened from "each checkpoint has a complete example" to "complete runnable program at selected checkpoints (hello, counter, modules, remote); other snippets are illustrative fragments". Matches what the guide actually delivers.
- **§1.2 exercise.** Reformulated to distinguish `fn main() = ...` (inference gives an effect, compiles) from `fn main() -> Void = ...` (explicitly pure, rejected). Shows the exact code each answer applies to.
- **§3.5.** `after` is a clause of `receive`, not a standalone expression form. Rewrote as "the `receive` expression form (with its optional `after` clause)".
- **§7.3.** "Two of these are runtime-checked" (three items followed) corrected to "The following three breaches are checked at runtime; purity remains a trusted promise".
- **§7.5.** Shim payload precondition stated: `V` must be integer-shaped, `R` a UTF-8 binary for `Either(String, Int)`. `find/1` labelled as a fragment dependency; noted that ABI-shape breaches must be converted on the Erlang side.

**Cost.** Six section edits. No new content, no structural change.

## Guide Round 2: Targeted Corrections, Runnable Checkpoints, Coverage Gaps, 2026-09-15

The reviewer's follow-up on the rewritten guide closed most items but flagged focused corrections still needed. Applied all in place:

**High — corrections against the spec:**

- **UG07 abstract-type identity.** Old wording "hashed by name and signature, *not by* private representation" was wrong. Report §8.7 says "not *just* by private representation" — the abstraction boundary is *added to* content identity, not substituted for it. Guide §6.2 rewritten: name and signature participate in identity; matching signatures do not guarantee cross-node compatibility with different representations.
- **UG09 opaque foreign decoding.** Old wording implied `Foreign` values could be pattern-matched with ordinary tuple/atom patterns; the `Foreign` library does not expose such projections. Replaced with an Erlang-side helper example (`{'Right', V}` / `{'Left', R}`) that matches Ernest's §8.4 ABI. Also introduced correct `Left`/`Right` constructors (not the non-existent `Ok`).
- **UG02 Address.call vs answer distinction.** Old wording said Address.call "finally discharges" the obligation, conflating consumption with answering. §4.2 now says Address.call *consumes by sending*, transferring the obligation to the recipient; only `answer` finally discharges the `Reply`. Restored static-check qualification: the ownership check does not guarantee execution reaches the answer at runtime — timeouts are the caller's safety net.
- **UG06 counter output conditional.** Guide claimed `count is 8` was deterministic; the reachable `None` timeout branch shows it isn't. §4.5 now says "if the call succeeds, 8" and "if the deadline expires, the timeout branch prints". §5.1's shutdown wording softened from "would kill both children before either sends" to "may terminate the children before their work finishes".
- **§6.1 qualified-name claim.** Old text said "top-level declarations use their qualified name at every reference"; too strong. Cross-module references use qualified names; within a module, unqualified lookup applies (module's own unqualified → enclosing namespace → prelude).
- **§3.5 `receive` is syntax.** Old list treated `receive` as one of the "prelude primitives". Split into "prelude primitives (`send`, `spawn`, ...)" and "expression forms (`receive`, `after`)".

**Medium — coverage additions:**

- §2.1: Int/Float separate types, no implicit numeric conversion; `Int.toFloat` and Float→Int conversions with contract pointers.
- §2.2: strict left-to-right evaluation; final expression of a block has no trailing semicolon.
- §2.5/2.6: equality restrictions extend to any type containing functions or addresses (not just direct Map/Set parameters); guards don't count toward `match` exhaustiveness.
- §2.7: Prelude `Optional` and `Either` definitions given; one successful/failed Either example added.
- §3.1: strict-evaluation and no-trailing-semicolon note.
- §3.3: top-level `let` initializers must be pure; effectful setup belongs in `main`.
- §4.5: `self()` inside a spawn returns the child's address; capture parent's `self()` before spawning if the child needs it.
- §5.4: new "Deadlock as a safety net" subsection (per-node detection, external event sources prevent false conclusion).
- §7.6: dynamic segment-value-doesn't-fit-width fault stated; frame precondition extended to include length field width fitting.

**Runnable checkpoints:**

- §3.2 lambda example rewritten as valid block with `let` separators.
- §4.6 Upgrade example completed with a `doublingCounter` replacement loop and a full `main` that upgrades after the first `Get`, sends `Inc(1)`, and verifies the state becomes 10.
- §6.1 modules example: `parse` replaced with a tiny working body; compilation-in-dependency-order shown with `ernc`/`ern` invocations.
- §7.1 added a runnable `remote(fn() = heavy(3, 4))` program with all three `Either` cases handled.

**Editorial:**

- §1.2 exercise reformulated to a concrete language question (can pure `main` call `Io.println`?).
- §2.3 nullary/positional/named constructor uses split into three distinct rows.
- §5.5 ClockMsg presented as an excerpt of the prelude type. `GameMsg`, `World`, `step` given minimal working definitions.
- §7.3 foreign-boundary promises split into runtime-checked (three) vs not-checked (purity).
- §9 reading-further: "ETS as a foreign process" → "ETS accessed through foreign functions".
- §1 configuration claim: replaced "you don't need it for local programs" with the report's actual toolchain contract (directory must exist; peer list can be empty).

**Cost.** Ten targeted section edits, no structural change. Guide grew slightly to accommodate the completed examples and coverage bullets but remains far shorter than the original.

## Guide Rewrite: Crash-Course Structure, All UG Corrections, Upgrade Example, 2026-09-15

The reviewer's guide review flagged twelve items (UG01–UG12) plus editorial repairs. Rather than patch in place, restructured the guide as a seven-stage crash course per UG12, applying all corrections and adding UG11's `Upgrade` demonstration.

**Structural change (UG12).** Old ordering: 0 intro → 1 hello → 2 types → 3 functions → 4 abstract types → 5–7 counter and ping-pong → 8 monitor → 9 via → 10 <- → 11 remote → 12 foreign → 13 bitstrings → 14 toolchain → 15 FAQ. New ordering: 0 orientation → 1 run a program (with `ernc`/`ern` right beside hello-world) → 2 compute with immutable values → 3 pass behavior → 4 run a protocol → 5 manage process lifetime → 6 organize code (modules + abstract types moved here) → 7 cross boundaries (peers, foreign, bitstrings together) → 8 FAQ → 9 reading further. Each stage ends with a prediction exercise.

**Correctness fixes applied:**

- **UG01** — Removed "reveals whether a call can send/receive/fault". §3.4 now says pure functions cannot perform process operations, but can fault or fail to terminate. Error model paragraph added distinguishing values-as-failure (Optional, Either), protocol-message failure, and process-fault + monitoring. §5.2 notes `main`-fault exception to "one process's fault doesn't affect another". §1.2 no longer claims all external effect requires messaging — `foreign fn` is the other explicit boundary.

- **UG02** — Removed `Reply(a)` from wrapper examples (§2.3 mentions it separately as a built-in with special rules, not comparable to `UserId`). §2.3 restated constructor-as-function rule: only single-positional constructors are function values; nullary and named-fields are not. §4.2 lists all six consumption forms (constructor placement, function return added), extends discipline to reply-carrying types, states pattern-match ownership transfer and nullary-case discharge, adds the `twice` counter-example.

- **UG03** — `hypotenuse` → `hypotenuseSquared`. `area(Point(x, y) : Point)` → `Rectangle(width = w, height = h)` with named fields. `let (e, rest) <-` → `let #(e, rest) <-`. Tuple/single-constructor irrefutability made recursive. Pattern rules added: identifiers are fresh bindings, no repeated names within one pattern, guards pure/faulting.

- **UG04** — §3.3 gained inference boundaries: `twice(n)` needs annotation; block `let` monomorphic; arity strictness; local-fn init rule; equality restrictions on Map/Set keys. §3.5 covers effect polymorphism with the `apply` example; distinguishes empty-capable `e` from process-constrained `m` (like `ping`'s). §3.6 states the spawn pure-callback restriction. §2.8 added the parenthesized-lambda-after-pipe rule.

- **UG05** — §4.3 introduces selective receive with `after` syntax, contrasts with exhaustive `match`. §4.4 states four Address.call rules: deadline start, no cancel of recipient work, silent late-answer discard with no tiebreak, private reply mechanism separate from declared mailbox.

- **UG06** — Softened scheduling claims. Counter output stated deterministically as `count is 8` (per-sender FIFO with one sender). Ping-pong stdout output labelled as *one possible successful trace*, with cross-sender scheduling explained. Clock example fixed as one-shot with re-arming shown explicitly. `kill` described through termination reason + monitor notification, no "immediately" implication.

- **UG07** — §6.2 abstract-type access centered on signature. Rejected `Stack.size` (unlisted, mentions constructor) and accepted `Stack.isEmpty` (uses public operations) examples added. Representation-change note qualified to require preserving observable contracts.

- **UG08** — §7.1 restated `remote`'s pure-callback reason as "compute-and-return by design", not "no communication back". "Also pure" removed. §7.2 adds NoRemotePeer vs PeerLost distinction (latter covers resolution failure and callback fault). Code-shipping consequences: `Sys.*` peer resolution, captured-address value preserved, top-level bindings peer-local, remote-send async fault, foreign compat requirement.

- **UG09** — §7.3 "wrong message from a foreign process" clarified as destination's mailbox type. Foreign fault delivered to receiving Ernest process on first observation. §7.5 shim pattern shows why `{ok, V}` doesn't auto-adapt to `Either` under the new §8.4 ABI: raw return declared as `Foreign` and decoded, or Erlang-side helper produces quoted-atom form. Also fixed inherited report inconsistency in Appendix D.

- **UG10** — §7.6 specifiers now include `unit(N)`. Alignment rules stated: total 8-bit alignment for the bitstring; `bits`/`bytes` segments binding `Bytes` must be byte-multiple; sub-octet fields use `int` binding to `Int`. Compile-time vs runtime alignment violation distinguished. `size(Expr)` purity stated; fault propagates. Frame/parseFrame precondition (`len` = body byte count) explained with the example of what `parseFrame(frame(1, <<65, 66>>))` actually returns. "Native speed" replaced with "compiles to BEAM's bit syntax".

- **UG11** — §4.6 explicit code replacement: `Upgrade` constructor with `migrate` and `next` fields, receive clause `k(m(n))`. Stated the extension replaces the earlier declaration.

**Editorial repairs:**

- "That's the whole vocabulary" → "these are the two organizing ideas".
- §2.4 qualifies `:`/`=` distinction: function result types use `->`.
- FAQ's n-ary/currying claim replaced with concrete "makes arity visible" reasoning.
- "under ten pages" and "eight weeks" claims removed.
- `via` argument order in §5.4 matches signature: converter first, target second.
- `todo` explained at first use (§6.1).
- Remote-spawning pointer added instead of "we won't cover here".

**Cost.** Guide dropped from 1150 lines / ~9800 words to 793 lines / ~5600 words — down about 40% in word count while adding selective receive, Address.call rules, higher-order effect example, `Upgrade` demonstration, and the coverage gaps the reviewer flagged.

**What is not in the guide.** Detailed report semantics (content-hash SCC grouping, exact ABI table, `Address.callForever` corner cases) — the guide points to the report for them. Paper-program depth beyond the introduction — the paper programs cover that themselves.

**Related report edit (Appendix D).** Reviewer's UG09 flagged an inherited report inconsistency: Appendix D's intro claimed `{ok, V}` auto-maps to an Ernest sum, contradicting §8.4's quoted-atom rule. Fixed in the same round.

## Fifth-Round Cleanup: Function Hash Preserves Eval Order, Underflow Threshold, Sqrt Removal, 2026-09-15

Fifth-round review closed N01/N02/N03/N04 core issues. Three precise corrections in the changed wording:

**N01 clarification — function-body normalization must preserve source evaluation order.**

The previous wording said normalization "sorts named fields into canonical order" without limiting the scope. Read literally, this could reorder construction expressions inside function bodies — two versions of `make()` that differ only in the source order of `Packet(left = ..., right = ...)` vs `Packet(right = ..., left = ...)` would hash identically despite different observable fault ordering (`todo("left")` vs `todo("right")` first).

- **Distinguish declarations/layouts from function bodies.** Taken. §8.7 now has a separate "Normalization" paragraph stating: declarations and layouts use lexicographic ASCII field-name order (matching §3.5 and §8.4); function bodies preserve source evaluation order of construction expressions.
- Rejected: sort everywhere, including bodies. Would erase observable fault/effect ordering.

§3.5 also updated to say "lexicographic ASCII field-name order" so both sections use identical wording.

**N04 correction — subnormal rounding threshold.**

The previous text said "a tiny result rounds to a subnormal, or to signed zero if smaller than the smallest subnormal". Wrong threshold: under round-to-nearest ties-to-even, `0.75 × smallest_subnormal` rounds *up* to the smallest subnormal (nearer to it than to zero). Only about half the values in the subnormal range round to zero.

- **Restate as rounding rule.** Taken. §3.1 now says arithmetic uses IEEE 754 binary64 round-to-nearest ties-to-even, and gradual underflow rounds to subnormal or signed zero "according to the rounding rule". No specific threshold given; the rule itself defines the outcome.
- Also updated `Int.toFloat` to say "round to nearest, ties to even".

**Cleanup — remove `sqrt` mention.**

The report declares no `sqrt` operation. §§3.1 and 7.4 mentioned it as an example fault case; removed to keep the fault list consistent with the operations actually in scope (`+`, `-`, `*`, `/`).

**Cost.** Two sentence rewrites (§3.1, §8.7), two smaller edits (§3.5, §7.4). No new syntax, no new operation.

**Principle 1 (least surprise).** Two definitions of `make()` that would behave differently at runtime now have different hashes, so cached-by-hash execution does not silently substitute one for the other.

## Fourth-Round Review Response: Canonical Field Order, Injective Tags, Function-Value Init, Underflow, 2026-09-15

Fourth-round review closed most items. Four remaining findings plus a batch of small corrections:

**N01 (High) — Named-field layout must match content-hash normalization.**

Three rules were in tension: (§3.5) named-field order carries no meaning; (§8.7) content hashing strips the ordering; (§8.4) the ABI stores fields in declaration order. Two nodes declaring the same-named type with reordered same-typed fields would agree on hash but disagree on layout — silent field swap on transport.

- **Canonical order = sorted by field name.** Taken. Applies to hashing, ABI storage, cross-node transport. Source-order evaluation of field expressions preserved (§5.1); values are then placed into canonical positions.
- Rejected: make layout part of type identity (would drop the "declaration order carries no meaning" promise).
- Rejected: pick some other order (declaration on primary node, alphabetical elsewhere, etc.) — inconsistent.

Effect: §3.5, §8.4, §8.7 all updated.

**N02 (High) — Constructor tag encoding must distinguish `Ready` from `READY`.**

Old rule: atom is lowercase source name. Broken: `type Status = Ready | READY` both map to atom `ready`.

- **Preserve source spelling in a quoted BEAM atom** (e.g., `'Ready'` vs `'READY'`). Taken. Injective mapping; matches BEAM's quoted-atom form.
- Rejected: hash-suffix atoms (`ready_H1234`) — ugly on wire and expensive to compare.
- Rejected: refuse case-differing constructor names — a lexical restriction that breaks §2.3's identifier rules.

Effect: §8.4 ABI updates from `c` (lowercase) to `'C'` (source-preserving quoted atom).

**N03 (Medium) — Function-value use before initialization.**

R07's earlier fix caught direct calls but not `invoke(read)` where `read` is passed as a function value. The eventual invocation is through `f`, not a call edge between local named functions.

- **Extend the rule from "called" to "used" (called, obtained as a value, passed, stored, returned, captured).** Taken. Uses references-between-local-fns as the dependency graph — same graph as before, but for uses rather than calls only.

Effect: §5.4 rule broadened.

**N04 (Medium) — Underflow to signed zero is finite, not a fault.**

§3.1 and §7.4 listed "underflow past the smallest subnormal" as a fault. But IEEE gradual underflow rounds tiny results to subnormals or signed zero — zero is finite. `1.0e-300 * 1.0e-300` rounds to positive zero, no fault.

- **Distinguish overflow / div-by-zero of non-zero numerator / `0.0/0.0` / `sqrt(-x)` (fault) from gradual underflow to signed zero (finite, no fault).** Taken. Aligns with IEEE.
- Rejected: fault on underflow past subnormal — contradicts the finite-only domain (which admits signed zero).

Also added `Int.toFloat` overflow contract: faults on out-of-range integers with `Fault("Int out of Float range")`.

**Small corrections applied:**

- §6.2 spawn example: `fn() : Void with Never = Void` → `fn() -> Void with Never = Void` (grammar requires `->` for return annotation).
- §8.4 ABI: added `Map(k, v)` and `Set(a)` as opaque runtime handles backed by BEAM's `maps`.
- §6.6 late answers: qualifier added — cross-node foreign-value fault (§3.8) still applies to `answer`.
- §7.4 heading: "The total prelude" → "Prelude operations and faults" (body already describes exceptions).
- §5.3 lambda termination: `,`, `;`, `|`, `)`, `}` list extended to include `]` and `>>` for list/bitstring contexts.
- Appendix A canonical parse: the sentence for constructor-argument consumption in QName replaced by the reviewer's suggested wording.
- Appendix E.10/E.11 effect polymorphism: `Optional.map`, `Optional.andThen`, `Either.map`, `Either.mapLeft`, `Either.andThen` signatures now show explicit effect variables.

**Cost.** Eight section edits, five signature updates in Appendix E. No new syntax, no new keyword, no new type-system machinery.

**Principle 1 (least surprise).** Two nodes exchanging a value now have consistent field layout. Two case-differing constructors round-trip distinctly. A local function value used before its captures are initialized is rejected.

**Principle 5 (small).** Canonical order and injective atom mapping are ABI conventions, not new language concepts. The underflow correction removes a spurious fault case.

## Mint-Condition Audit: Grammar Notes, Main Default, Guide Sync, 2026-09-15

Pre-implementation audit against the "can I write a hand-written recursive-descent + Pratt parser from Appendix A alone?" standard. Findings and their fixes:

**G1: QName's constructor suffix vs Call.** `Some(x)` had two grammatically-admissible parses — QName-with-suffix or QName followed by `Unary`'s `Call`. Value semantics matches for single-positional constructors, so the reviewer accepted this as editorial. **Fix:** Appendix A epilogue now states the greedy rule explicitly: "When a `conname` is followed by `(`, the parser consumes the `(...)` as part of `QName`'s optional constructor-fields suffix, not as a subsequent `Call`."

**G2/G3: Max-munch tokens and `|` not a binop.** §2.6 gained a paragraph after the operator list: max-munch tokens listed (`>>`, `<-`, `->`, `==`, `!=`, `<=`, `>=`, `&&`, `||`, `|>`, `<>`, `::`, `#(`, `<<`, `..`); `|` explicitly stated as a delimiter that terminates the Pratt loop.

**P1: `main` mailbox default.** §8.1 said `m` is polymorphic when `main` uses `Address.call` without its own receive protocol, but did not say what the runtime instantiates polymorphic `m` to. **Fix:** added: "When `m` is left polymorphic in the source, the runtime instantiates it to `Never` — the main process's mailbox is send-only unless the program explicitly gives out `self()`."

**Guide sync (P2).** `ernest_guide.md` audit found three items:

- `Float` bullet in the base-types section still said "IEEE 754 double precision" without the finite-only restriction. Updated.
- Two spots ("When `main` returns, the runtime kills every process still alive" and the `ern [options] file.erc` description) missed the local/remote scoping from R12. Updated to say "every *local* process still alive"; noted remote workers survive.
- No stale `NaN`/`Infinity`/`isNaN` references.
- No stale terminology (recv, opaque, Nat, Text, Empty, +:, ++, "payload" as constructor field).

**Paper programs trace (P3).**

Traced Appendix B (Counter, Ping-pong, Worker) and all four paper programs (`examples/filesync.ern`, `examples/webserver.ern`, `examples/tick_game.ern`, `examples/repl.ern`) against current rules:

- All `spawn(Local, fn() = worker())` cases have a non-pure callback (`worker` has some effect). U01 primitive-non-empty rule satisfied. No stale pure-spawn callbacks.
- Reply-carrying `receive` clauses in filesync (`syncer` matching `SyncMsg`) bind reply fields (`Put(ack = ack)` binds `ack`; `Tick`, `Listed(_)`, `Link(_)` nullary or non-reply-carrying fields discharge the scrutinee's obligation).
- The `mk` callback pattern (`fn(r) = Get(reply = r)`) works under U03: `r` consumed by placement into reply-carrying constructor; return discharges to `Address.call` runtime.
- No Float usage in paper programs, so finite-only Float change has no downstream effect.
- All patterns work under new reply-carrying discipline.
- No wildcard-omitted-field cases that would be rejected by U03.
- No `as`-on-reply-carrying patterns.

**Grammar/static-check implementability summary.**

- Grammar is fully first-token dispatchable with bounded lookahead (max: 2 tokens after `(` for FnType/ParenType disambiguation, and 2 tokens after `(` for Constructor field-list dispatch).
- Type inference is HM plus three inferred restrictions (equality, non-empty, not-reply-carrying) that attach to type schemes and travel through unification.
- Reply-ownership is a compositional per-function flow analysis over the typed AST.
- R07 early-call check is a local-fn dependency-graph analysis in each block.
- Guard purity is enforced by the effect checker.
- Bitstring per-segment alignment: constant-fold at compile time; dynamic guard at runtime.
- Content hashing uses SCC-group scheme (§8.7).

**Cost of this pass.** Three sentences added to the report (§2.6, §8.1, Appendix A epilogue). Three sentences updated in the guide (`Float` bullet, two termination scopes). No new syntax, no new type-system machinery.

**Report ready for Phase 1.1 implementation.**

## Third-Round Review Response: Float Finite-Only, ABI Table, Restriction Propagation, Assorted Repairs, 2026-09-15

Third-round review flagged remaining tails on U01, U03, U05, U07, U09; a concrete example for R07; new grammar corrections for R18; and asked for an ABI table (R16 narrowed). Also: pure spawn callback (U01), remote worker lifetime (R12), and connected-peer deadlock exclusion (R13). This decision groups all response edits.

**Float domain: commit to finite-only.**

The reviewer's core U05 concern: §3.1 promised `Infinity` and `NaN` values, but native BEAM raises `badarith` for them and Erlang's external term format encodes only finite floats. The two positions are inconsistent.

- **Commit to finite-only Float.** Taken. `Float` values are IEEE 754 doubles restricted to the finite range. Arithmetic that would produce a non-finite result faults with `Fault("float arithmetic error")`. Aligns with BEAM natively; no runtime extension needed.
- **Commit to full-IEEE with runtime extension.** Rejected — larger implementation footprint for edge cases no paper program stresses.

Consequences:

- §3.1 rewrites arithmetic to fault on overflow/div-by-zero/`0.0 / 0.0`.
- §3.10 loses the "Float follows IEEE 754 as a specific exception" paragraph — equality is structural for Float, no NaN concern.
- §3.10 loses the "`Map(Float, v)` and `Set(Float)` are rejected" clause — Float equality is reflexive without NaN, so it is a valid key.
- §7.4's Float item now covers `Float` arithmetic faults; `Float.compare/round/floor/ceil` are total.
- `Float.isNaN` removed from Appendix E.9 — no NaN to check.

**R07 revised — early-call before initialization.**

The reviewer's concrete case: a local `fn` is called before a `let` it captures has been evaluated. Under the whole-block-visibility rule adopted earlier, this typechecked; the reviewer flagged it as unsound.

- **Reject early-call.** Taken. §5.4 gains a sentence: "A local `fn` may only be *called* after every `let` binding it references — directly or through calls to other local `fn`s in the same block — has been evaluated." The check follows local-function call edges to include indirect dependencies.

**R18 grammar cleanups.**

- `[ "-" ] literal` → `literal | "-" ( int | float )` in both grammar blocks. Prevents `-"text"` and `-true` at grammar level.
- `ParenType` parsing prose reworded: "consume the common `(` and comma-separated content, then inspect the next token" — matches the reviewer's request for a bounded-consumption description over lookahead-through-parens.
- Pipe/lambda edge cases added to §5.7: `x |> f(a)(b)` inserts into the outermost call — `f(a)(x, b)`. `x |> (f(a))` is `f(x, a)`.
- Constructor-call ambiguity: the reviewer downgraded to editorial. `Some(x)` has one canonical parse via `QName`'s constructor-suffix branch, and semantics matches a call for single-positional constructors. No change needed beyond noting this.

**R16 narrowed — ABI table.**

The reviewer accepted the trust boundary (foreign side delivers declared types; breach is a fault) and asked instead for a normative representation table.

- **Compact ABI table in §8.4.** Taken. Covers base values, nullary/positional/named constructors, tuples, lists, `Void`, addresses/replies (opaque), foreign values, function values (opaque). Same-named constructors of different types share a lowercase atom; the receiving side's declared type disambiguates. Faults for malformed foreign returns are delivered to the receiving Ernest process on first observation.

**U01 pure spawn callback.**

The reviewer's concrete case: `spawn(Local, work)` where `work : () -> Void` (pure). Under the non-empty rule for primitives, `spawn`'s `n` (from `Address(n)`) must be a mailbox type, so a pure callback fails to unify.

- **Reject; require `with Never` annotation.** Taken. §6.2 gains a sentence explaining that the callback's mailbox effect must be a real mailbox type; a spawned process that never receives is annotated `with Never`.

**U01 & U03 propagation through function values.**

The reviewer's ask: non-empty and not-reply-carrying restrictions must survive wrappers, function values, and compiled module interfaces — same treatment as equality (U04).

- **Consolidate all three restrictions under one propagation rule.** Taken. New §3.9 paragraph "Inferred restrictions propagate through function values, branches, and modules" naming the three restrictions (equality, non-empty effect, not-reply-carrying) and stating: they are part of the type scheme, travel with the function value, preserved across compiled interfaces, and surfaced in diagnostics. Rejected: a special user-writable constraint syntax (violates principle 5).

**U03 match decomposition transfer.**

The reviewer asked for explicit language: matching a reply-carrying scrutinee transfers the obligation to the pattern-bound fields; matching a nullary reply-carrying-sum constructor (like `Stop` in `PongMsg`) discharges the obligation with no new binding.

- **Added to §6.6.** Taken. One sentence in the pattern-matching paragraph.

**U07 three sub-issues.**

- *Recomputed top-level values need not match sender's.* Fixed. §8.7 no longer claims "the per-node result matches the sender's". It now states the initializer runs in the peer's environment and results may differ; each initializer evaluated at most once per node per code version.
- *PeerLost naming and effect on held addresses.* Kept the unified `PeerLost` (no new error constructor). Added: "`Left(PeerLost)` signals that this specific `remote` operation did not complete; it does not invalidate other `Address` values held for the same peer, which are only invalidated by actual peer-loss detection (§10)." Rejected: split into `RemoteFailed` vs `PeerLost` (adds error surface).
- *Remote-send failure timing.* Explicit: `send` returns immediately (§6.2), so a peer-side resolution failure faults the sending process *asynchronously* after `send`'s return.

**U09 three repairs.**

- §7.4 opening softened to the reviewer's suggested wording: "Partial operations in the prelude generally return `Optional` or `Either`. The operations listed below deliberately fault on specified inputs or runtime conditions. Absence of a mailbox effect does not guarantee absence of faults."
- Remote-send resolution failure added to the §7.4 fault list.
- Bitstring fault clause updated to include per-segment alignment (U08).
- §8.5 cycle-phase text now states both phases together: within-module compile-time; cross-module load-time.

**R12 remote worker lifetime + local scope.**

- §8.6 termination paragraph scopes `ProgramEnd` to *local* processes and adds: "Remotely spawned workers on peer nodes are unaffected by the initiating program's exit — they run independently under their peer's runtime."

**R13 connected-peer channel prevents deadlock.**

- §8.6 deadlock paragraph now includes connected peers with pending outgoing computations as "messages in flight" — a program awaiting a reply from a still-computing peer is not deadlocked.

**Cost.**

- Twelve section edits ranging from one sentence to a full paragraph.
- One new inline ABI table in §8.4 (about 15 lines).
- One new propagation paragraph in §3.9.
- No new keyword, no new type, no new operator.
- Grammar changes: one refinement (numeric-only `-` prefix) plus one parsing description rewrite.

**Principle 5 (small).** Float finite-only is a net simplification: removes IEEE exception paragraph, removes Map/Set Float restriction, removes `Float.isNaN` from stdlib. R16 adds an ABI table but it replaces spec folklore with 15 lines.

**Principle 2 (one way).** Three restrictions (equality, non-empty, not-reply-carrying) share one propagation rule rather than being separate special cases. `PeerLost` remains one signal for all remote failures.

**Principle 3 (nothing invisible).** Match decomposition transfer, remote-send timing, peer-local top-level initialization, remote worker lifetime, and connected-peer deadlock exclusion are all now stated.

**Still open — reviewer input requested (unchanged from previous round):**

- R07 — reviewer's concrete example was addressed. The general early-call rejection rule handles it.
- Nothing else pending.

## Four "Partly Resolved" Tails: Blocks, Reply Timing, Termination, Deadlock Scope, 2026-09-15

Four remaining tails from the reviewer's "Partly Resolved" cells that we can decide ourselves. R16's tail was already covered by §8.4 + §10 (foreign side delivers declared types; representation is documented) — no change needed. R07's "local recursive functions" and R18's "constructor-call ambiguity" tails need a concrete example from the reviewer and stay open.

**R07 tail — local `fn` in a block.**

- **`fn` declared inside a block is visible throughout the block; `let` remains sequential.** Taken. Matches the top-level rule; mutual and self-recursion between local `fn`s just work. A `fn` body referencing a later `let` is a compile-time error.
- Rejected: purely sequential `fn` (visible only after declaration) — would break mutual recursion inside blocks and diverge from the top-level rule.

**R11 tail — timeout deadline start and races.**

- **Clock starts when `Address.call` is invoked; construction time counts against the deadline.** Taken. Most natural reading of "wait up to `ms` milliseconds".
- **Race between reply and timeout has no deterministic tiebreak.** Taken. Runtime-scheduling-dependent; either outcome (`Some(v)` or `None`) is legal. Reviewer's concern that a spec should acknowledge the race is addressed by stating the non-guarantee.
- Rejected: clock starts after the outgoing send. Would let arbitrarily-slow `mk` callbacks starve the timeout.
- Rejected: deterministic tiebreak. Requires runtime coordination for no practical benefit.

**R12 tail — output draining, `main` fault, peer shutdown.**

- **Runtime flushes pending output on system processes before program exit.** Taken. Standard behavior; no user surprise from a buffered final `Io.println`.
- **`main` faulting = program end, with the fault's cause reported on the exit indicator.** Taken. Same termination path as return, plus a diagnostic.
- **No coordinated shutdown signal to peers; they see `PeerLost` per R14.** Taken. Consistent with the "loss is terminal from observer's view" policy.
- Rejected: no output draining. Would surprise callers whose last output vanishes.
- Rejected: cross-node coordinated shutdown. Adds a distributed protocol for a fault model that's deliberately simple.

**R13 tail — deadlock scope and foreign event registration.**

- **Deadlock detection is per-node.** Taken. Cross-node deadlock detection requires distributed consensus, which Ernest does not commit to. A program deadlocked in a distributed sense may not be detected.
- **`Sys.*` system processes count as external event sources by default; user-provided foreign event sources are runtime-dependent.** Taken. Keeps the language spec neutral about specific runtimes' foreign-process discipline.
- Rejected: cross-node deadlock detection. Machinery cost without a paper-program need.

**Effect on the report.**

- §5.4 (Blocks): one sentence added about `fn`-in-block visibility vs `let` sequentiality.
- §6.6: new "Deadline start and races" paragraph after "Timeout rationale".
- §8.6: termination paragraph extended (output draining, `main` fault, no peer shutdown). Deadlock paragraph extended (per-node scope, foreign-event registration policy).

**Cost.** Four short paragraphs / paragraph extensions. No new syntax, no new operation, no new fault kind.

**Still open (need reviewer input).**

- R07's "local recursive functions interacting with sequential bindings" — the phrase suggests a specific example the reviewer has in mind that's not covered by the general rule we adopted. Ask.
- R18's constructor-call ambiguity — no concrete example was given. Ask.

**R16's tail** — the reviewer wanted "the complete value representation, validation rules, and trust boundary". §8.4 states: "the foreign side delivers the declared types, and a breach is a fault." §10 states: "The representation of values is fixed and documented, so that foreign code can produce and consume them." Both are already in the report; nothing to add.

**Principle 3 (nothing invisible).** Four folklore behaviors (block-`fn` visibility, timeout start, output draining, deadlock scope) are now stated rather than implied.

**Principle 5 (small).** No new mechanism, no new syntax.

## Effect Variables: Primitives Are Non-Empty (U01 Soundness Fix), 2026-09-15

Discovered during the final audit. The U01 rule "effect-only variables can bind to empty" opens a soundness hole for prelude primitives:

```
fn foo() = spawn(Local, fn() = worker())
```

Inference gives `foo : () -> Address(a) with m` (effect-polymorphic — `spawn`'s outer effect var flows up). Called from pure code, `m` unifies with empty, so `foo`'s call typechecks as pure — but `spawn` creates a process, which is not pure. Same for `send`, `Address.call`, `answer`, `remote`, `monitor`, `kill`.

The paper programs don't hit this (their `main` is effectful, and other primitive-using functions have concrete effects), but the type system's soundness requires closing the hole.

**Choices weighed:**

- **State that primitives' outer effect variables cannot bind to empty — treat them as value-position variables for U01 purposes.** Taken. One sentence in §3.9. No new syntax, no new mechanism.
- **Add a new syntactic marker for non-empty effect variables (e.g., `with m*`).** Rejected — new syntax for a rule that only applies to a fixed list of prelude primitives.
- **Change primitive signatures to force non-empty via value position** (e.g., include a `Address(m)` argument that anchors `m`). Rejected — awkward parameters, ugly signatures.
- **Ignore the hole because paper programs don't hit it.** Rejected — soundness matters even if unexercised; a future paper program could hit it silently.

Taken: state the exception in §3.9 as prose. The type checker treats primitives' outer effect variable as if it were in a value position — pure code cannot invoke them.

**Effect on §3.9.** One sentence added after the value/effect-position rule.

**Cost.** One sentence. No new syntax. No effect on paper programs (they weren't invoking primitives from pure code).

**Principle 3 (nothing invisible).** The soundness rule was implicit in the type checker's semantics; now stated in the report.

**Principle 5 (small).** No new syntactic marker, no new kind of variable. The exception is a rule of the prelude, described in prose.

## Grammar: Negative Numeric Patterns and Lambda-After-Pipe Parens, 2026-09-15

The reviewer's R18 (open since earlier round): "The substantive parsing issues remain, including negative numeric patterns, an unparenthesized lambda after a pipe, and constructor-call ambiguity." Addressing the two clear ones.

**Negative numeric patterns.**

§2.5 states "Literals carry no sign; `-` is a prefix operator." That made `-1` an expression (`negate(1)`), not a literal. Grammar allowed `literal` in patterns but not a signed variant, so `match n { -1 -> ... }` failed to parse. Users had to fall back to a guard (`n when n == -1 -> ...`).

Options weighed:
- **Allow `[ "-" ] literal` in `AtomPat`.** Taken. One-char grammar change; scope of `-` is limited to patterns.
- **Change §2.5 to admit signed literals globally.** Rejected — reintroduces the "should `-1 - 2` parse as `(-1) - 2` or `-(1 - 2)`?" ambiguity that motivated §2.5's rule.
- **Require guards for negative matches.** Rejected — noisy for a natural pattern.

**Unparenthesized lambda after pipe.**

§5.7 said the RHS of `|>` "may be a name, a qualified name, a lambda, or a call". But grammar-wise, `Lambda` is at the `Expr` level, not the `Primary`/`Unary` level that binops consume. `x |> fn(y) = y + 1` failed to parse.

Options weighed:
- **Require the lambda to be parenthesized: `x |> (fn(y) = y + 1)`.** Taken. Parenthesized expressions already reach `Primary` via `"(" Expr ")"`; nothing new in the grammar. Fixes the prose to match the grammar.
- **Add `Lambda` to `Primary` (allow bare lambdas in binops).** Rejected — `Lambda`'s body is a greedy `Expr`, so `x |> fn(y) = y + 1 |> f(z)` would parse ambiguously (does the lambda body extend through the second pipe or not?). Requires special termination rules; adds parser complexity for a rare shape.
- **Special-case `|>` in the grammar.** Rejected — same greedy-body problem, and pipe-specific rules violate the "small, uniform grammar" principle.

Taken: prose fixed to say "a parenthesized lambda", with a note explaining why parens are required.

**Constructor-call ambiguity.**

The reviewer flagged this without a concrete example. The current grammar disambiguates constructor calls with bounded lookahead — after `Foo(` in an expression, peek past the first identifier: `=` means named fields, anything else means a positional single-Expr (per Appendix A's epilogue). Nullary constructors (`Foo` bare, no parens) are unambiguous. Not addressing without a specific ambiguity to fix — the grammar's current disambiguation rule appears to cover the cases we know.

**Effect on the report.**

- Grammar (both copies, §5 and Appendix A): `AtomPat` gains `[ "-" ] literal` alternative.
- §5.7 prose: "a lambda" → "a parenthesized lambda", with the reason.
- §5.10 prose: negative-numeric-pattern example added to the atomic-patterns paragraph.

**Cost.** Two grammar-character additions, two prose sentences. No new keyword, no new syntactic form.

**Principle 4 (simple to parse).** The `[ "-" ] literal` addition stays under bounded lookahead — `-` followed by a numeric literal in a pattern is unambiguous. The lambda-parens rule keeps the grammar first-token-decidable at the pipe RHS.

**Principle 1 (least surprise).** A reader who writes `match n { -1 -> ... }` now sees it parse. A reader who writes `x |> (fn(y) = ...)` sees it parse and understands from the prose why bare lambdas need parens.

## Modules: Nested Namespace Ownership and Cross-Module Type Info, 2026-09-15

The reviewer's R17 (open since earlier round): three asks — nested namespace ownership, locating compiled modules, cross-module type information.

**Nested namespace ownership.** §4.2 said a module's path is its namespace and that "sub-namespaces are the dots", but didn't say whether `Net/Http.ern` could declare `Net.Http.Header.parse` (extending into a deeper namespace) or whether that must live in `Net/Http/Header.ern`.

- **Strict path-based ownership**: `A.B.C.name` belongs exclusively to `A/B/C.ern`. Taken.
- **Prefix-based**: any module whose path is a prefix of the qualified name can declare. Rejected — finding a declaration would require searching multiple candidate files.
- **Any module can declare any qualified name**: only same-full-name is a conflict. Rejected — chaotic; principle 1 (least surprise) says the location of a declaration should be predictable from its name.

Taken (strict): a declaration `A.B.C.name` where `A`, `B`, `C` are typename segments belongs to `A/B/C.ern`. Declaring into a sub-namespace deeper than the module's own path is forbidden.

**Locating compiled modules.** §11.2 already spells the rule ("compiled modules on the load path, found by namespace, `Net.Http.parse` in `Net/Http.erc`"). No change needed.

**Cross-module type information.** §11.1 said "a program is compiled module by module; cross-module names are resolved at load", which left compile-time type checking of dependent modules unspecified.

- **Compiled `.erc` files carry inferred type information for qualified declarations.** Taken. The compiler reads type info from dependent modules' `.erc` files on the load path. Compilation is in dependency order.
- **Require full signatures on all qualified top-level declarations.** Rejected — the grammar allows omitted signatures on `fn`; requiring them for exported names would introduce a two-tier `fn` rule.
- **Whole-program compilation.** Rejected — §11.1 already commits to module-by-module compilation.

**Effect on the report.**

- *§4.2*: extended to state strict path-based ownership. `Net.Http.parse` and `Net.Http.Request` live in `Net/Http.ern`; `Net.Http.Header.parse` lives in `Net/Http/Header.ern`.
- *§11.1*: extended to state that `.erc` carries type info for qualified declarations, and that compilation proceeds in dependency order.

**Cost.** One sentence extended in §4.2, one sentence extended in §11.1.

**Principle 1 (least surprise).** A reader who sees `Net.Http.Header.parse` in code can predict its source file without searching.

**Principle 3 (nothing invisible).** Cross-module type information is now stated to be part of the compiled form, rather than left as implementation folklore.

## Distributed Failure: One Simple Model, Loss Is Terminal, 2026-09-15

The reviewer's R14 (open since earlier round): "§10 still describes node loss as actual process death. Disconnection, delivery guarantees, reconnection, and remote process survival need distinct contracts."

Four questions to answer:

1. **Disconnection vs. loss** — is there a transient disconnection state distinct from permanent loss?
2. **Delivery guarantees** — what does `send` promise across nodes?
3. **Reconnection** — if a peer reappears, do addresses reactivate?
4. **Remote process survival** — do processes on a lost node continue running?

**Choices weighed:**

- **Erlang model: loss is terminal from the observer's view, no reconnection, no delivery guarantee beyond best-effort.** Taken.
- **Rich distributed model with transient-disconnection, reconnection, delivery acks.** Rejected. Adds concepts (Session, transient state, ack protocol) for a fault model that Ernest deliberately keeps simple (§6.9 has no linking beyond monitors; §10 already commits to unreliable best-effort delivery in spirit).
- **Persistent addresses that reactivate on reconnection.** Rejected — introduces address-identity questions across time; the existing address model (§6.5) is "possession is permission to send", not "addresses have persistent identity beyond node lifetime".
- **Guaranteed delivery via runtime buffering.** Rejected — mailboxes are unbounded per program's responsibility (§10); adding a network-level delivery guarantee would add another buffering layer and shift responsibility.

Taken: one policy answers all four questions.

- Loss is terminal from the observing node's view. What the lost peer's processes are actually doing is unobservable; treating loss as terminal is the honest answer.
- A peer that reappears with the same name is a new instance; addresses held before the loss are unrelated to it.
- `send` is best-effort while the peer is reachable. No guarantee, no ack, no retry.
- In-flight messages at the moment of loss are dropped without notification. This matches how `send` to a dead local process behaves (§6.2: "sending to a process that has died has no effect").

**Effect on §10.** The single bullet on peer loss is extended from one sentence to three, covering all four sub-questions:

- Loss detected → processes treated dead with `Fault("peer lost")`, monitors deliver, pending `remote` returns `Left(PeerLost)`.
- Reappearance is a new instance; no reconnection.
- `send` best-effort while reachable; in-flight messages at loss are dropped.

**Cost.** One bullet extended. No new mechanism. Cross-reference to §6.9 for monitor delivery.

**Principle 2 (one way).** One policy for all four questions rather than four separate contracts.

**Principle 3 (nothing invisible).** The four sub-questions had implicit-Erlang-behavior answers before; now stated explicitly. No hidden guarantees to invoke; no ambiguous reactivation semantics.

**Principle 5 (small).** No new concept added — the simpler answer stays.

## Guards and Bitstring Size Expressions: Pure, No Fault Swallow, 2026-09-15

The reviewer's R10 (open since the earlier round): §5.9 said "a failed guard falls through" but didn't define permitted effects, fault handling, or the scope and evaluation rules for guards. Same gap for bitstring pattern `size(Expr)`.

**Choices weighed:**

- **Guards are pure `Bool` expressions; guard faults propagate.** Taken.
- **Guard faults treated as match failure (Erlang model).** Rejected — silently swallowing a fault would violate principle 3 (nothing invisible); Ernest's total prelude means guard faults are rare, so making them explicit costs little.
- **Guards can carry mailbox effects (send/receive within a guard).** Rejected — matching semantics would depend on mailbox side effects, which is surprising and hard to reason about.
- **`size(Expr)` restricted to identifier references only (no arbitrary expressions).** Rejected — grammar already allows `Expr`; restricting it would forbid natural forms like `size(len - 4)`; the "pure, no effect" rule already covers the concerning cases.
- **Fault in `size(Expr)` treated as match failure.** Rejected — consistency with guards: pattern-embedded expressions have the same fault-propagation rule.

Taken: both guards and size expressions are pure (no mailbox effect, enforced by the type checker), fault propagates the same as any faulting expression in the enclosing scope.

**Effect on §5.9.**

New paragraph after the existing match-clause text:

- A guard is an expression of type `Bool` with no mailbox effect — the type checker rejects `send`, `receive`, `spawn`, `Address.call`, and any other effect-carrying operation in a guard.
- The guard sees the pattern-bound variables of its clause and the enclosing scope.
- A guard that evaluates to `false` falls through; a guard that faults faults the enclosing process — no fall-through for faults.
- Same rules for `receive` guards.

**Effect on §5.11.**

The "Patterns and construction" paragraph extended:

- `size(Expr)` evaluates `Expr` in the scope of earlier-bound segment variables and the enclosing scope.
- The expression must be pure and produce a non-negative `Int`.
- Negative or out-of-range size fails the match.
- Fault in `Expr` faults the enclosing process.

**Cost.** One new paragraph in §5.9, one extended sentence in §5.11. Both rely on existing type-checker machinery (mailbox-effect tracking).

**Principle 3 (nothing invisible).** Guard and size-expression faults now visibly propagate rather than being silently swallowed.

**Principle 5 (small).** No new syntax, no new operation, no new fault. Reuses the type checker's existing effect-tracking to enforce purity in guards and size expressions.

## Function-Type Grouping: `ParenType` Overrides Nearest-Arrow, 2026-09-15

The reviewer's R05 (open since the earlier round): "There is no grouping rule for expressing an effectful function that returns a pure function. The nearest-arrow rule remains unchanged."

§3.4 states `with` binds to the nearest arrow, so `(A) -> (B) -> C with M` is "pure function returning function with mailbox M". There was no way to write the opposite — a function with mailbox M returning a pure function — because the grammar had no parenthesized-type production.

**Choices weighed:**

- **Add `ParenType = "(" Type ")"` as a grammar alternative.** Taken. Parenthesizing the returned function type binds `with` to the outer arrow: `(A) -> ((B) -> C) with M`.
- **Change the default to outermost-arrow binding.** Rejected — `List.map`'s natural signature `(List(a), (a) -> b with e) -> List(b) with e` reads intuitively under nearest-arrow (each `with e` belongs to its own arrow); flipping the default would surprise the common case to fix the rare case.
- **Introduce a new grouping syntax (`⟨Type⟩` or similar).** Rejected — parens are the natural grouping token; introducing new syntax for a rare case violates principle 5.
- **Leave R05 open.** Rejected — the paper programs don't yet hit this, but the language should have an answer for a straightforward question.

**Grammar change.** Both grammar blocks (§3 top, Appendix A) get a new alternative:

```
Type = TypeAtom | FnType | ParenType .
ParenType = "(" Type ")" .
```

Parsing: `FnType` and `ParenType` both start with `(`. The parser distinguishes at the matching `)` — one-token lookahead: if `->` follows, it's `FnType`; else, it's `ParenType` (which then requires exactly one `Type` inside).

**Prose change.** §3.4 extended: "Parentheses group a type to override the default: `(A) -> ((B) -> C) with M` is a function with mailbox `M` returning a pure function."

**Cost.** One grammar production, one sentence of prose. Bounded lookahead (matches principle 4). No effect on existing programs — the paper programs don't use return-position function types where the outer needs its own effect. No new keyword, no new type.

**Principle 1 (least surprise).** A reader who wants the opposite of `with` binding can now reach for the natural fix — parens — instead of hunting for a special syntax that doesn't exist.

**Principle 4 (simple to parse).** The added production keeps the parser under bounded lookahead: one token after `)`.

## Fault List and Initialization: Extend §7.4, Acknowledge Partial Init, 2026-09-15

The reviewer's U09 flagged two things:

1. §7.4 opens by declaring "no built-in function faults" then lists five exceptions. The recent U05 and U07 changes added Float→Int fault and `spawn(Peer, ..)` resolution-failure fault; those weren't in the §7.4 inventory.
2. §8.5 derives order-independence of initialization from purity. But pure ≠ total: initializers can fault (`todo`, division by zero) or fail to terminate. §8.5 was silent on what happens in those cases.

**Choices weighed:**

- **Extend §7.4's list to include the newly-added faults; add a paragraph in §8.5 acknowledging partial initialization.** Taken.
- **Rewrite §7.4's opening to soften "no built-in function faults".** Rejected — the "list of deliberate exceptions" reading is fine when the list is complete; softening the opening loses the design principle it states.
- **Make initializers strict-total (reject nonterminating initializers statically).** Rejected — undecidable in general, and `todo` initializers are useful during development.
- **Serialize initialization order deterministically.** Rejected — order-independence is a real property of pure initializers when they all terminate successfully; serialization would only affect which fault gets reported first, and the report already says "unspecified" for that case.

**Effect on §7.4.** One item added, one item extended:

- The Float item now covers `Float.round/floor/ceil` fault (added in U05 but not previously listed here).
- New item: `spawn(Peer(...), ...)` fault the caller on unknown/unreachable peer (§6.2) or peer-side resolution failure (§8.7 — missing `Sys.x`, incompatible foreign, unresolvable code hash).

The opening "Five deliberate exceptions" changed to just "Deliberate exceptions" — the count is no longer accurate and locking it in was accidental.

**Effect on §8.5.** Two new paragraphs:

- *Failure during initialization*: purity does not imply totality; an initializer that faults ends the program before `main`; a nonterminating initializer prevents other initializers from being reached; which of two independent faulting initializers is reported is unspecified.
- *Dependency graph*: the graph is symbolic — binding `p` depends on binding `q` if `p`'s initializer references `q` by name in a resolvable position; a called function contributes its own references. Cross-module cycles caught at load time.

**Cost.** One list item added, one extended, two paragraphs in §8.5. No new mechanism, no new syntax.

**Principle 3 (nothing invisible).** The previously-unlisted faults are now in the report's inventory. Initialization failure was folklore; now stated.

## Bitstring `bits` Segments Must Be Byte-Aligned When Binding to `Bytes`, 2026-09-15

The reviewer's U08 flagged a hole in §5.11's alignment story: the earlier fix required the *total* bit count of a construction to be a multiple of 8, but a single `bits` segment could still bind a sub-octet slice to a variable of type `Bytes`:

```
<<part:size(3)-bits, _:size(5)>> -> Some(part)
```

The scrutinee is one aligned octet, but `part` would be a 3-bit "Bytes" — outside `Bytes`'s declared octet-only domain (§3.1).

**Choices weighed:**

- **Restrict `bits`/`bytes` segments binding to `Bytes` to byte-multiple sizes; sub-octet fields use `int`.** Taken. Preserves `Bytes` as strictly octet-sequence, matches the reviewer's suggestion.
- **Remove `bits` specifier entirely, keep only `bytes`.** Rejected — grammar change; `bits` still reads naturally for known-bit-length declarations and matches Erlang's precedent.
- **Add a new "BitString" type distinct from `Bytes` (sub-octet allowed).** Rejected — adds a new type for a use case no paper program stresses.
- **Allow sub-octet `bits` to bind to `Bytes` with silent zero-padding.** Rejected — silent padding violates principle 3 (nothing invisible) and creates a value that can't be re-serialized round-trip.

Taken: the existing byte-alignment rule extends from whole-bitstring to per-segment when the segment binds to `Bytes`.

**Effect on §5.11.**

One paragraph extended, one sentence added:

- The "Byte alignment" paragraph now states that every `bits`/`bytes` segment binding to `Bytes` must be byte-multiple (construction or pattern).
- Sub-octet fields must use `int` (binds to `Int`).
- Compile-time-constant violations are compile-time errors; dynamic-size violations fault at construction or fail to match in patterns.

**Cost.** Two sentences. No new type, no new specifier, no new fault (existing `bitstring not byte-aligned` covers dynamic construction; pattern match-failure covers dynamic patterns).

**Effect on paper programs.** None: no paper program uses sub-octet `bits` segments binding to `Bytes`.

**Principle 1 (least surprise).** A reader who trusts `Bytes` is octets can now trust that pattern extraction preserves this — no accidental sub-octet Bytes values leak through the matcher.

**Principle 2 (one way).** One alignment rule covers construction and extraction uniformly.

## Code Shipping Boundaries: Transport, Failure Channels, Runtime Bindings, 2026-09-15

The reviewer's U07 flagged five sub-issues in §8.7, each observable in cross-node code:

1. §3.11 says code travels with functions in messages, but §8.7 said "sending closures in messages ship nothing" without qualifying "in local messages".
2. `spawn(Peer, ..)`'s resolution-failure semantics were ambiguous: "fault on the shipped process" — but the process doesn't exist yet.
3. Missing `Sys.*`, incompatible foreign, or a fault in `remote`'s callback weren't among the two `RemoteError` cases.
4. Foreign-value transport rule named only remote `send` and `spawn`; missed thunks capturing foreign values, remote results, and cross-node replies.
5. Top-level bindings on the peer: shipped code may reach a node where they aren't initialized.

Plus: the phrase "`f` is pure (it must be, to be safely serialized and run on a peer)" in §6.7 confuses purity (about execution effects) with transportability (about values). `spawn` already ships effectful functions.

**Choices weighed:**

- **Consolidate all remote-transport failures into the two existing `RemoteError` cases (`NoRemotePeer`, `PeerLost`) for `remote`, and into "caller fault" for `spawn(Peer, ..)`.** Taken. Avoids expanding the error enum for edge cases; matches the existing §6.2 rule that an unreachable peer faults the caller.
- **Add specific `RemoteError` cases (`MissingSys`, `MissingForeign`, `CallbackFault`).** Rejected — bloats the error surface; the caller mostly just wants "the peer didn't do it".
- **Broaden the foreign-value rule to any cross-node transport, one sentence.** Taken.
- **Peer-side top-level bindings: computed on demand from the shipped initializer.** Taken — consistent with content addressing (initializer is pure per §4.6, per-node result matches).
- **Ship the sender's already-computed top-level values.** Rejected — introduces a separate transport channel and blurs the per-node initialization story from §8.5.
- **Explain `Sys.*` name reference vs captured value.** Added one sentence — captures capture values (not names), so a captured `Sys.stdout` still points to the sender.
- **Fix §6.7's "safely serialized" wording.** Replaced with the correct reason: `remote` is a one-shot compute-and-return, effectful work goes through `spawn`.

**Effect on the report.**

Six focused edits, no new machinery:

- *§8.7 intro*: the "ship nothing" sentence now qualifies to local sends; remote sends use the same peer-ship contract.
- *§8.7 Dependency resolution*: any resolution failure — missing dep, missing `Sys.x`, incompatible foreign, `remote`-callback fault — surfaces as `Left(PeerLost)` for `remote` and as a caller fault for `spawn(Peer, ..)`. Remote-`send` payload uses the same contract; failure faults the sending process.
- *§8.7 Runtime bindings*: added the name-vs-captured-value distinction and the on-demand initialization rule for peer-side top-level bindings.
- *§3.8*: extended the foreign-value cross-node rule to cover all transport paths (spawn, remote send, remote result, cross-node answer, captured closure values).
- *§7.4*: updated the fault-list cross-reference to the extended rule.
- *§6.7*: replaced "must be pure to be safely serialized" with "`f` is pure by `remote`'s design — the operation is a one-shot compute-and-return; effectful work goes through `spawn`".

**Cost.** Six sentence-level edits. No new error constructor, no new function, no new syntax.

**Principle 2 (one way).** Remote failures collapse into two error paths (`RemoteError` for `remote`, caller fault for `spawn`). Foreign-value transport is one uniform rule.

**Principle 3 (nothing invisible).** Top-level bindings on peer, captured-value vs name-reference distinction, and the remote-`send` shipping path are all stated rather than left as folklore.

## Content Hashing: Recursive Groups and Abstract-Type Boundaries, 2026-09-15

The reviewer's U06: §8.7's content-hash rule read `H(f) = hash(def(f), H(f))` for a recursive function, which has no finite construction. Related asks: how does normalization treat named-field order, local variable names, qualified references? What about abstract types with identical representations declared independently?

**Choices weighed:**

- **Hash strongly connected components as groups.** Taken. Standard scheme (Unison's approach). Internal references use positional indices; external references use hashes; group is hashed as a whole; each member derives its identity from the group hash. Finite, consistent across nodes.
- **Skip recursion in the hash and use name-based identity for recursive definitions.** Rejected — breaks content addressing for exactly the case where it matters most (mutually recursive types often carry protocols and change together).
- **Fixpoint iteration.** Rejected — no finite construction unless you cap iterations, and any cap is arbitrary.

For abstract types:

- **Hash by representation only.** Rejected — two independently declared `Stack` types with the same private representation would silently interoperate, defeating the abstraction boundary.
- **Hash by qualified name only.** Rejected — same-named types with different signatures would collide, and the content-hash story would lose consistency for concrete types.
- **Hash by qualified name plus exported signature.** Taken. Two nodes declaring the same-named abstract type with the same interface are equivalent; different names or different signatures mean different types.

**Effect on §8.7.**

Two new paragraphs, each two-to-four lines:

- *Recursive definitions*: SCC-group hashing with internal indices, external hashes, group hash. Normalization strips α-conversion and named-field order (§3.5); preserves qualified names of external references.
- *Abstract types*: hashed by qualified name plus exported signature, not by private representation. Independent `Stack` declarations with the same guts are not silently interchangeable.

**Cost.** Two paragraphs, no new syntax, no new primitives. The report doesn't prescribe the hashing algorithm — just states the equivalence it establishes.

**What is NOT specified.** The exact hash function, the byte-level layout of the normalized form, the string encoding — all implementation details. The report specifies the equivalence classes; the toolchain decides how to compute them.

**Principle 5 (small).** The report gains one new mechanism concept (SCC-group hashing) and one clarification (abstract-type nominal identity). The alternative — leaving recursion undefined and abstract-type identity implicit — would leave two silent implementation traps.

**Principle 3 (nothing invisible).** Recursive-group identity and abstract-type nominal boundary are now both visible in the report rather than implementation folklore.

## Float Semantics: Minimal Reparation, Reject the Bloat, 2026-09-15

The reviewer's U05 flagged seven gaps in the Float story: `Float.floor(1.0/0.0)` and `Float.round(0.0/0.0)` returning `Int` with no defined outcome for non-finite inputs; `Int.toFloat` for integers outside the finite range; subnormal preservation; bitstring encoding of non-finite values; Map/Set semantics for NaN and -0.0 keys; recursive structural equality with Floats inside; and a `§4.8`/`§3.10` cross-reference for `<` versus `Float.compare`.

**Decision policy.** Closing every gap by extending the report would add: an explicit full-IEEE representation clause, subnormal/gradual-underflow prose, bit-pattern preservation for bitstrings and cross-node transport, a new `Float.isFinite` function, prose about recursive equality, and a full §4.8 cross-reference — several paragraphs and one new primitive, for a rare-in-paper-programs set of edge cases. That contradicts principles 2 (one way, one job) and 5 (small): the report already commits to "IEEE 754 double precision" and lets IEEE speak for itself where a specific rule doesn't apply.

**Choices weighed:**

- **Answer every gap.** Rejected. Would inflate §3.1 and §3.10 by ~30 lines and add machinery (a new function, representation prose) for edge cases no paper program stresses.
- **Retreat to a finite-only Float.** Rejected. Changes existing spec; requires arithmetic that faults on the finite/non-finite boundary, which loses the IEEE simplicity the language currently promises.
- **Minimal reparation: two edits, defer the rest to "IEEE per §3.1".** Taken.

**Applied edits:**

- *§3.1*: extend the existing fault sentence (`Float.compare` faults on NaN) to include the parallel — `Float.round`, `Float.floor`, `Float.ceil` fault on NaN or ±Infinity. Motivation is the same in both cases: `Ordering` has no unordered case, `Int` has no infinity. One sentence, no new function.
- *§3.10*: state that Float cannot be a `Map`/`Set` key — the existing container-key equality constraint already requires reflexivity, and Float's IEEE equality is not reflexive on NaN. This makes the failure explicit rather than leaving Map with a Float key silently broken.

**Deliberately not addressed:**

- Subnormals: `signed zero` on underflow is a coarse summary; IEEE handles the finer detail per §3.1's "IEEE 754 double precision" commitment.
- Bitstring `float` segments: the grammar admits them; the runtime uses IEEE — no separate prose needed.
- Recursive equality: covered by "Float follows IEEE 754 as a specific exception" applying to Floats wherever they appear.
- Runtime representation: an implementation detail. A platform whose native floats don't cover the domain must handle it; the report doesn't dictate how.
- `Int.toFloat` overflow: IEEE round-to-nearest is the default behavior, no separate prose.
- No `Float.isFinite` added — `Float.isNaN` covers the guard for the two fault points we specify; adding `isFinite` waits until a paper program needs it.
- §4.8 cross-reference for `<` versus `Float.compare`: §3.10 already states the operator behavior; §4.8's "ordering uses each type's `compare`" is loose but reads correctly in context (Float's operators are not literally implemented through `compare`; the operator's own rule wins per §3.10). If this bites a paper program, revisit.

**Cost.** One sentence extended, one sentence added. No new function, no new type-system machinery.

**Principle 5 (small).** The report keeps its Float story to two paragraphs in §3.1 plus one in §3.10. IEEE 754 speaks for the rest.

**Principle 2 (one way).** The two edits keep the existing pattern (Float→Int and Float ordering share the "fault on undefined output" rule; Map/Set constraint applies uniformly to any type that fails reflexivity).

## Equality Constraints Propagate Through Values, Branches, and Modules, 2026-09-15

The reviewer's U04: §3.10 said equality constraints are inferred from `==` usage and checked at each call site, but did not specify what happens when a constrained function is stored, returned, branched on, or exported.

The paradigm example:

```
fn equal(x, y) = x == y      // constrained on x's type
fn always(x, y) = true       // unconstrained
fn choose(flag) = if flag then equal else always
```

Three questions were open:

- What constraint does the result of `choose` carry? At the application of the returned function to addresses, is the error at the application site — or lost?
- What happens at intermediate calls where the argument type is still polymorphic (e.g., a function that passes a callback through several layers)?
- How does a compiled module's interface convey the constraint on an exported polymorphic value?

**Choices weighed:**

- **Constraints are part of the type scheme and travel with the value.** Taken. Branch unification takes the union; module boundaries preserve them; intermediate polymorphic calls are still checked at eventual instantiation. This is essentially Haskell-style constraint propagation with exactly one built-in constraint (equality) and no user-defined type classes.
- **Constraints are inferred locally per call and never travel.** Rejected — `let f = equal; f(addr1, addr2)` would either type-check (loss of guarantee) or force a runtime check (not Ernest's model).
- **A user-defined type-class layer.** Rejected — one built-in constraint doesn't justify the machinery.
- **Widen printed function types to admit constraints as syntax.** Rejected — the annotation grammar stays simple; diagnostics carry the extra information.

Taken: propagation with a single Eq constraint. No new syntax, no new mechanism beyond what the type checker already needs to represent the constraint internally.

**Effect on §3.10.**

Two new paragraphs after the instantiation-time explanation:

- *Propagation*: constraints are part of the type scheme; `let f = equal` inherits `equal`'s constraint; `if flag then equal else always` unifies branches and takes the union of constraints (so the result of `choose` is constrained); module interfaces encode constraints; call chains through several polymorphic intermediaries are still checked at the eventual application.
- *Diagnostics*: printed types mark the constrained form so `equal` and `always` are visibly distinguishable; error messages identify which parameter's constraint failed; `ernc --doc` shows the constraint.

**What is NOT in the report.** The exact printed syntax for a constrained type is left to the toolchain — "the printer marks the constrained form" without prescribing whether that means `(a, a) -> Bool where equal(a)` or a keyword prefix or another form. The annotation grammar does not admit constraint syntax; this is deliberate to keep hand-written `fn` signatures uncluttered.

**Cost.** Two paragraphs in §3.10. No change to inference machinery — the compiler already infers the constraint per §3.10's current text; the new rules describe how the constraint flows through standard HM operations (substitution, unification, generalization). Compiled interfaces gain a field for equality constraints on polymorphic exports.

**Principle 1 (least surprise).** The old rule said "checked at each call site" without saying what "the type" of a stored function was. A reader would assume the constraint is lost when a function is stored — which would be a surprise once they hit `let f = equal; f(addr1, addr2)`. Now the answer is stated: constraint travels with the value, error at application.

**Principle 3 (nothing invisible).** Printed types and diagnostics show the constraint even though annotations cannot. Two shapes that look the same in a written signature (`(a, a) -> Bool`) but behave differently at runtime would otherwise be indistinguishable — now the tooling makes the difference visible.

## Block Bindings: Escape Path and Wildcard Rule, 2026-09-15

The reviewer's U02: §4.6's block-binding rule was too strict. It said "if any variable remains free at the block's end, the binding is a type error at its site" — but this rejects two legitimate HM cases:

```
fn empty() = []            // typechecks; fn generalizes.
fn namedEmpty() = {
    let xs = [];           // xs : List(a), 'a' unresolved at block's end
    xs
}                          // rejected by the old rule; should be identical to empty().
```

And a wildcard discard:

```
let _ = spawn(Local, fn() = ping(pongAddr, 3))
```

Here `spawn` returns `Address(m')` where `m'` is a fresh polymorphic variable (ping doesn't receive; its mailbox is polymorphic in `ping`'s signature, and the spawned lambda's mailbox inherits that). Under the old rule, `_` binds nothing but the free `m'` was still flagged as unresolved — forcing the programmer to add a fake mailbox annotation just to satisfy the check.

**Choices weighed:**

- **Add an escape path and a wildcard rule to the existing rule.** Taken.
- **Generalize block `let` like Haskell's `let`.** Would let `namedEmpty`'s `xs` become a polymorphic value locally. Rejected — this is the classic *ML value restriction* problem and its cousins; it complicates the type checker and blurs the pure/effectful boundary. The current rule (`fn` generalizes, block `let` doesn't) is deliberate.
- **Default the discarded variable to a specific type (e.g., `Never`).** Cheap trick but arbitrary. Rejected — the wildcard is the natural mechanism; making `_` discard cleanly is better than picking a default.

**Effect on §4.6.** The old single-sentence rule is replaced by three explicit resolution paths and a wildcard clause:

- *Resolution by later use*: standard HM, unchanged.
- *Escape to enclosing scope via the block's result*: a variable appearing in the block's result type is carried out to the surrounding `fn` (or top-level `let`) and generalized there. This is standard HM behavior — the old rule accidentally blocked it.
- *Explicit annotation*: unchanged.
- *Wildcard discard*: `let _ = e` does not bind a name, so any unresolved variables in `e` never propagate anywhere and need no resolution.

Also stated: type parameters of the enclosing `fn` are not "unresolved" — they are quantified at their binding site and appear in the block's environment.

**Consequences for existing programs.**

- `namedEmpty` and analogous shapes now typecheck. Users who write `let xs = []; xs` inside a body get the same type as `fn empty() = []`.
- The revised ping-pong example (`let _ = spawn(Local, fn() = ping(pongAddr, 3))`) typechecks cleanly. No annotation on the spawned lambda needed.
- Programs that write `let m = Map.empty` and then neither use `m` nor return it still error, because the unification variable is genuinely unconstrained — the rule is only more permissive for legitimate resolutions.

**Cost.** Six lines of prose expanded to about fifteen. No new type-system machinery — the escape path is standard HM; the wildcard rule is one sentence.

**Principle 1 (least surprise).** A reader who knows HM predicts that `fn namedEmpty() = { let xs = []; xs }` should be polymorphic just like `fn empty() = []`. The old rule surprised them. Now the two forms behave identically.

**Principle 3 (nothing invisible).** The wildcard `_` was doing invisible work before — its "does not bind a variable" property was implicit. Now it is explicit in the binding rule.

## Effect-Variable Kinds: One Kind, Position Controls Admissibility, 2026-09-15

The reviewer's U01 flagged that the earlier §3.9 formulation "position distinguishes kind" was insufficient. Concretely:

- `self : () -> Address(m) with m` requires the two occurrences of `m` to name the *same* mailbox type; if they are variables of different kinds this relationship is lost.
- An effect variable may become empty, but `Address(empty)` is not a well-formed value type.
- The pure-vs-effectful callback compatibility rule was implicit.

**Options weighed:**

- **Two syntactic kinds distinguished by position.** The status-quo phrasing. Rejected because it makes the `self` signature ill-formed: two variables of different kinds cannot refer to the same underlying value.
- **Implicit conversion between mailbox types and effects.** A "coercion" whenever a value type appears after `with`. Adds a new concept (subtyping/coercion) for one edge case; violates *one way, one job*. Rejected.
- **A separate row/lattice of effects with unification rules.** Row polymorphism, effect algebras. Rejected as far too much machinery for a language that has exactly one effect per function.
- **One kind of variable; position controls admissibility.** Taken.

Under the taken model:

- Type variables are one kind (as HM has). Unification is standard.
- A variable in a *value position* (arguments, results, tuple components, inside `Address(_)`, `Reply(_)`, `List(_)`, etc.) resolves to a value type.
- A variable in an *effect position* (after `with`) is used as the caller's mailbox effect. Effect positions additionally admit *empty* (no mailbox).
- A variable that appears in any value position cannot instantiate to empty. That's a well-formedness check at instantiation, orthogonal to unification.
- A variable that appears only in effect positions can instantiate to a mailbox type or to empty.

This resolves the reviewer's three concrete cases:

- **`self : () -> Address(m) with m`.** `m` appears in `Address(m)` — value position — so at every call site `m` resolves to a value type, and the effect position after `with m` receives the same value. The two occurrences share by unification, no coercion needed.
- **`apply : ((a) -> b with e, a) -> b with e`.** `e` appears only in effect positions, so it may be empty. Pure callback → `e = empty` → pure call. Effectful callback → `e = M` → outer effect `M`.
- **`spawn(Local, fn() = Void)`.** `spawn : (Where, () -> Void with n) -> Address(n) with m`. `n` is in `Address(n)` — value position, so it must resolve to a value type. A pure lambda has type `() -> Void` (empty effect); unifying with `() -> Void with n` where `n` must be non-empty leaves the lambda's mailbox as a fresh variable (or requires the programmer to annotate, e.g. `fn() : Void with Never = Void`). The subsequent block-boundary rule (§4.6, still under U02) decides what happens if that fresh variable remains free.

**Two callbacks with independent effects.** Ernest has no effect union — a function has exactly one mailbox effect or none. Two effectful callbacks with distinct effect variables in the same body unify their effect variables with the outer function's single effect. Two concretely different effect types in that position is a type error.

**Effect on Appendix E.** Higher-order combinators were shown as pure-callback-only (`List.map : (List(a), (a) -> b) -> List(b)`) despite §3.9 promising effect polymorphism. The signatures now spell the effect variable explicitly (`List.map : (List(a), (a) -> b with e) -> List(b) with e`, similarly for `List.foreach`, `List.filter`, `List.filterMap`, `List.foldLeft`, `List.find`, `List.any`, `List.all`, `List.span`, `List.sort`, `Map.map`, `Map.foldLeft`, `String.all`). No behavior change — the type checker was going to infer them this way anyway — but a reader consulting Appendix E now sees the polymorphism the language provides.

**Cost.** One paragraph added to §3.9, one bullet removed from the "annotations describe shape" list (kind distinction is no longer a hidden thing — the model has one kind), a dozen signature updates in Appendix E. No change to HM machinery.

**Principle 2 (one way).** Effect variables and value type variables were being described as two things sharing one syntax. Now they are one thing with a single well-formedness rule attached — the same variable can appear in both positions, and the positions constrain admissibility.

**Principle 3 (nothing invisible).** The old formulation left the two `m` in `self` implicitly linked by an unstated rule. Now the link is explicit: value-position usage constrains the whole variable.

## Reply Ownership Extends to Reply-Carrying Types, 2026-09-15

The reviewer's follow-up round flagged U03 as *Critical*: the exactly-once discipline on `Reply(a)` was formulated on bare `Reply(a)` values only. A message that *contains* a `Reply(a)` could be duplicated, dropped, or aliased without any variable of type `Reply(a)` ever being in scope. The paradigm example:

```
type Request = Get(reply : Reply(Int))

fn twice(dst : Address(Request), request : Request) -> Void with m = {
    send(dst, request);
    send(dst, request)
}
```

No variable here has type `Reply(Int)`, so the old binding-site check saw nothing to enforce. Yet the second `send` reuses a value whose Reply has already been transferred to the recipient. Related gaps: pattern-matching `Get()` silently drops the reply; `Get(reply = r) as whole` aliases the reply through `whole`; `Address.call`'s `mk` callback returns a message containing the reply but the four listed consumption forms did not include "return through a message-building expression".

**Choices weighed:**

- **Extend the taint through the type (value-agnostic, per-type discipline).** A type is reply-carrying if it is `Reply(a)` or has any reply-carrying field/component transitively. Reply-carrying values are affine regardless of which constructor they carry. Simple to check (needs only the type, not the value), matches how Rust treats enums whose variants contain linear fields. Slight over-approximation: `Stop` values of a reply-carrying `PongMsg` cannot be duplicated with `let msg = Stop; send(a, msg); send(a, msg)` even though `Stop` carries no Reply — but no paper program does this, and freshly constructing `Stop` inline twice is fine. Taken.
- **Value-based check (per-constructor).** Only actually-Reply-holding constructors' values are affine; `Write(bytes)` and `Close` of `SockMsg` are freely duplicable. More permissive, but the checker needs case analysis over constructor to know which values need tracking. Complicates the compositional check across function boundaries: `fn f(msg : SockMsg) = ...` cannot tell which constructor the caller supplied. Rejected on parsing/complexity grounds.
- **Runtime-only exactly-once.** Rejected — the report's second bullet in §3.9 states the exactly-once check is static; a runtime guard is a weaker guarantee.
- **Substructural annotations on types (`linear`/`affine` keyword).** Rejected — adds new syntax for a rare enough constraint that "the type transitively mentions `Reply`" already suffices as the trigger.

Taken: extend the discipline to reply-carrying types (option 1). This is the minimum change that catches all the reviewer's counterexamples with no new syntax.

**Consumption forms.** The list needed a form for the `mk` callback of `Address.call`, which was previously handwaved as "embedding the reply in the message it builds". Two new forms:

- *Placing into a constructor/tuple*: the constructed value inherits the obligation and is itself subject to the discipline.
- *Returning from a function whose return type is reply-carrying*: shifts the obligation to the caller's binding site.

**Pattern rules.**

- Matching a reply-carrying value must bind every reply-carrying field: wildcard/omitted for a `Reply`-declared field is a static error (would silently drop).
- `as` on a reply-carrying scrutinee is a static error (alias would duplicate).

**Legal-positions update.** Reply-carrying values are banned from prelude container types (`List`, `Map`, `Set`, `Optional`, `Either`). Other user-defined types can carry them because their construction and destructuring are checked by the same field-binding rule; the container ban singles out these five because their operations (map, get, put) must be able to store, look up, and duplicate freely.

**Effect on Appendix B.**

- Counter: `Address.call(c, fn(r) = Get(reply = r), 1000)` — mk consumes r by placing into `Get`; the returned `CounterMsg` inherits the obligation, discharged by `Address.call`. ✓
- Ping-pong: same shape. ✓
- All `receive` clauses in both examples bind reply fields explicitly. ✓

The `twice` counterexample and the `Get()` pattern omission are now static errors, as the reviewer required.

**Cost.** One paragraph added (reply-carrying types), two consumption forms added, two pattern rules added, one summary-line update on line 212. Total: about twenty lines of prose in §6.6, one word in §3.9.

**Principle 3 (nothing invisible).** The exactly-once guarantee is now visible in the type — reply-carrying types are recognized by structure, not by ad-hoc "message" convention. The old phrasing had a hidden asymmetry: the discipline followed the *variable name*, so wrapping a Reply in a struct erased the discipline. Now it follows the *type*.

## Appendix D (ETS) Fixes: Syntax Sweep and Native Type, 2026-09-15

The reviewer's fourteenth finding: Appendix D (the `Ets.ern` shim) still used pre-sweep syntax in several places, and one raw binding had a native argument-type mismatch that would fail at runtime on BEAM.

**Syntax problems.**

The terminology sweep on 2026-09-15 renamed tuples to require the `#(...)` prefix and the unit type/value to `Void`. Appendix D was not updated at that time. Remnants:

- `(key, value)` on the wire and in the row type — should be `#(key, value)` and `#(k, v)`.
- `[(_, v)]` in the match pattern for a singleton list — should be `[#(_, v)]`.
- Three occurrences of the old unit literal `()` at the end of block-let sequences — should be `Void`.

**Native argument-type mismatch.**

`rawNew` was bound to `ets:new/2`:

```
foreign fn rawNew(name : String, opts : List(Foreign)) -> Ets.Table(k, v) with m = "ets:new/2"
```

And called as `rawNew("ernest", ...)`. But `ets:new(Name, Options)` on BEAM requires `Name :: atom()` — an atom, not a binary. Since Ernest's `String` is a UTF-8 binary on the ABI (§10), the call would pass `<<"ernest">>` where an atom is expected, and `ets:new` would crash with `badarg`. The Ernest declaration typechecks but the underlying Erlang call is ill-formed.

**Choices weighed:**

- **Pass an atom.** Change the call site to `rawNew(atom("ernest"), ...)` and change the parameter type to `Foreign`. Matches Erlang's expectation and keeps the shim's shape (raw binding is `Foreign`-typed and opaque; the wrapper `Ets.new` presents a typed interface).
- **Make `rawNew` accept a `String` and let the runtime convert.** Rejected — the ABI (§10) does not silently convert between binaries and atoms, and it should not: `binary_to_atom` allocates in the atom table and is a policy call, not a coercion. The programmer should say when a value crosses that boundary.
- **Drop the name argument entirely** by wrapping `ets:new/2` under a fixed name in Erlang. Rejected — that reintroduces the Erlang wrapper module the appendix explicitly avoids ("No Erlang module is needed").

Taken: pass an atom through `atom("ernest")`, and re-type the parameter as `Foreign`.

**Effect on Appendix D.**

Six lines changed:

- `rawNew("ernest", ...)` → `rawNew(atom("ernest"), ...)` at the call site.
- `name : String` → `name : Foreign` in the raw declaration.
- Three `(k, v)` and `[(_, v)]` → `#(k, v)` and `[#(_, v)]` for the row tuple type/value and the pattern.
- Three `; ()` → `; Void` at block-let tails.

**Cost.** Six edits, no semantic change. The appendix now typechecks under the current grammar and runs cleanly on BEAM.

**Principle 4 (small).** The shim is a worked example of the foreign story; syntax drift in it undermines that role. Fixed now, and the sweep-index preamble at the top of this document already lists the syntax renames, so future readers see why old syntax elsewhere is a bug rather than a variant.

## Code Shipping: Dependency, Type-Version, and Runtime-Binding Contracts, 2026-09-15

The reviewer's thirteenth finding: §10 stated "a node ships code to a peer that lacks it, identified by content" as a runtime guarantee, but the report said nothing about *how* the ship works. Three concrete questions were unanswered:

1. **Dependencies.** A shipped closure `f` calls `g`, which calls `h`. Does the ship include `g` and `h`? What if the peer has some of them but not others? What if the peer has a differently-defined `h` under the same name?
2. **Type versions.** A shipped closure has type `Address(FooMsg) -> Int`. The peer has its own `FooMsg`. If the peer's `FooMsg` differs from the sender's — extra constructor, renamed field, different field type — what happens?
3. **Runtime bindings.** A shipped closure references `Sys.stdout` or `Sys.clock`. Do these resolve to the *sender's* system processes (as if captured) or to the *peer's* (as if late-bound)?

Without answers, `spawn(Peer(...), f)` and `remote(f)` are underspecified: two implementations could reasonably differ, and a programmer cannot reason about what happens when a shipped closure runs.

**Choices weighed:**

- **Content addressing (Unison model).** Every function, constructor, and type has a hash of its normalized definition and its dependencies' hashes. Two nodes with structurally identical definitions share the same hash and interoperate; any change to the definition or its transitive dependencies changes the hash and breaks interoperation. Ship-time dependency resolution: peer fetches missing hashes from sender before running the closure.
- **Named modules with versions (npm-style).** Each module has a version string; shipping requires version compatibility. Rejected — versions are a metadata layer that content addressing subsumes, and it introduces the "dependency hell" problem Unison was designed to eliminate.
- **Whole-module baseline (Erlang release model).** Every peer runs the same compiled release; no shipping needed. Rejected — the report already commits to peers not needing to hold the same code (§10), because that assumption doesn't hold for a mixed federation of nodes.
- **Sender-side runtime bindings.** Shipped closure captures `Sys.stdout` from the sender, and messages route back over the network. Rejected — a shipped `Io.println("hello")` sending output to the sender is bizarre and would surprise every reader. Late-bind to the peer's `Sys.*` instead.
- **Peer-side runtime bindings (taken).** `Sys.*` resolves on the peer that runs the code. Missing `Sys.x` on peer is a fault at resolution.

Taken: content addressing, peer-side `Sys.*`, ship-time dependency resolution, foreign code is per-node.

**Effect on the report.**

New §8.7 *Code shipping*, five paragraphs:

- Scope: peer ship only. Within-node `spawn(Local, f)` and closures-in-messages ship nothing.
- *Content addressing*: definitions carry a content hash; structurally identical → same hash; any change → different hash.
- *Dependency resolution*: peer resolves hashes transitively before running; missing hashes fetched from sender; `spawn`/`remote` return only after success. Unreachable sender → `Left(PeerLost)` or fault.
- *Type identity*: types identified by hash; peer's local `FooMsg` under the same source name but different structure is unrelated.
- *Runtime bindings*: `Sys.*` resolves on the peer that runs the code; a missing `Sys.x` is a fault at resolution.
- *Foreign code*: `foreign fn` and `foreign type` are not shipped; peer must have compatible foreign definitions.

Also §10's line about code shipping now points to §8.7 for the details.

**Cost.** One new subsection, five paragraphs. Two of the questions (types and runtime bindings) were already implicit in the design; §8.7 makes them explicit and consistent. Dependency resolution as a distinct concept is new but small — it is the mechanism the runtime already needed for the "no prior installation" promise in §10.

**Principle 3 (nothing invisible).** The ship contract used to be one bullet in §10 that said "it just works". Now the reader can trace what happens: hashes on the wire, resolution before execution, peer-local `Sys.*` and foreign code.

## Deadlock Detection Distinguishes Idle Server From Deadlocked Program, 2026-09-15

The reviewer's twelfth finding: §8.6's deadlock rule was too broad. It said "if no process can run, all are waiting in `receive` without `after`, and no messages are in flight, the runtime ends the program with the error `Deadlock`. A pending `after` or clock counts as a message in flight." An idle web server — every user process in `receive`, waiting for a TCP connection from `Sys.tcp` — satisfies every clause and would be spuriously killed with `Deadlock`, because only `after` and clock timers were listed as exemptions. The web-server paper program (Paper Program 1) hits this exactly.

**Choices weighed:**

- **Extend the exemption to any registered future delivery from a system process** — pending `after`s, pending clock timers, network listeners, keyboard subscribers, pending I/O. Keeps the deadlock check useful (still catches cycles of `Address.call` on user processes with no external event source) and lets idle servers idle.
- **Remove deadlock detection entirely.** Erlang has none, and the runtime is one primitive smaller. Rejected — deadlock is a real bug that beginners hit, and a runtime message is a better diagnostic than "the program silently does nothing forever". The value of the check is disproportionate to its cost.
- **Narrow deadlock to a wait-for cycle among `Address.call` operations.** Precise, but harder for the runtime to build and detect, and misses the "everyone in `receive`, no one sending, no external source" case that the current rule already catches.
- **Add a `system-process` predicate to the type system.** Rejected — too much surface for a runtime-only concern. The runtime already knows which addresses are `Sys.*`; that is where the classification belongs.

Taken: the exemption is generalized. Any subscription, timer, or pending I/O held by a live system process counts as a message in flight.

**Effect on §8.6.**

The old sentence "A pending `after` or clock counts as a message in flight" is replaced. The new rule reads:

- Forward progress must be impossible: every live process in `receive` without `after`, no message in flight, and no live system process holds a subscription/timer/pending I/O whose completion would deliver a message to a live process.
- Pending `after`s, clock timers, network listeners, keyboard subscribers, and any similar registered future delivery from a system process count as messages in flight.
- An idle server waiting for external events is not deadlocked.

**Cost.** One sentence, some prose. The runtime already needs to know about pending `after`s and clock timers; extending to Sys.tcp listeners and Sys.keys subscribers is the same kind of bookkeeping.

**Principle 1 (least surprise).** The web-server paper program stopped looking like it "compiles but always crashes with Deadlock the moment main goes to sleep". Now the semantic matches what the reader expects: idle is idle, deadlock is deadlock.

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

## `Void` → `Unit`, 2026-09-17

A read-through of the whole report applied principle 1 to the report's own vocabulary. `Never` is the type with no values; `Void`, which means "nothing" in plain English, named the type with exactly one value. A reader who knows `Never` predicts that `Void` is its cousin; it is the opposite. The mismatch shows most in message types: `After(ms : Int, to : Address(Void))` is an address that receives a signal, but reads as an address that receives nothing, which is what `Address(Never)` means. The Haskell collision (`Void` is the empty type there) was the trigger; the within-Ernest reading was the argument.

**Considered:** the list from *`()` → `Void`* again. `Unit` was set aside then as "abstract to programmers without PLT background". Re-weighed:

- `Unit` is the standard name for the concept in every typed functional language, so it is the one name a reader can look up and be sure of.
- Kotlin uses exactly Ernest's shape: a type `Unit` whose single value is also written `Unit`.
- It is descriptive in the one way that matters, a type with one (unit) element. `Void` describes the wrong thing.
- Counting the audience an HM language on BEAM draws (Gleam, Elixir, OCaml, Rust, Kotlin, Scala, Haskell): `Unit` has three friends and no enemy; `Void` has one friend (Swift) and one active enemy (Haskell).
- `Nil` stays out because Elixir readers hear absence, which is `None`. `()` stays out for the parenthesis overload recorded in the earlier entry.

**Taken:** `Unit`.

**Effect.** `type Unit = Unit` in §9.3; every `Void` in the report, the guide, and `examples/` became `Unit`. §3.1 now says in one sentence that `Unit` is not the empty type. §8.4 lost its special ABI line for the unit value: `Unit` is an ordinary nullary constructor and maps to the quoted atom `'Unit'` like every other, which also removes the contradiction between the old lowercase `void` atom and the constructor rule in the same section. The implementation plan's ABI paragraph was brought in line with §8.4 at the same time.

## Report Read-Through Fixes, 2026-09-17

A full read of the report against its own principles, Wirth-report practice, and the vocabulary of readers from other typed languages. Each fix below names the section it changed. Design questions the read raised but did not settle are listed at the end.

**Grammar and lexical.**

- §2.3 gives `letter`, `digit`, `hexdigit`, `ident`, `typename`, `conname`, and `typevar` as EBNF productions, as Oberon does, instead of prose. §2.5's `\u{...}` bound of one to six hex digits moved into the production.
- §2.5 adds the `\r` escape. Raw U+000D was already excluded from literals, so `"\r\n"` had no spelling except `\u{d}`; the web server needs it. The float exponent admits `+` as well as `-`.
- §2.6 adds `.` to the delimiter list; `QName`, `TypeAtom`, and `DeclName` all use it.
- §2.6 introduces `userop = "+" | "-" | "*" | "/" | "%" | "<>"`, the operators a type may define for itself (§4.8). `Signature`, `DeclName`, and `QName` use it instead of `binop`, and `DeclName` and `QName` require a typename prefix on an operator. Before, a bare `+` parsed as a primary expression and `fn +(a, b)` as a declaration, neither with a meaning; and `Int.|>` or `Int.==` were grammatical though §2.6 and §4.8 forbade them. This also removes a hazard for the Pratt loop, which would otherwise meet a binop token in operand position.
- `ForeignParam = ident ":" Type` replaces `Param` in `ForeignDecl`. §4.7 said foreign parameters are annotated; the grammar had them optional and admitted patterns.
- Appendix A's commentary names the third lookahead spot: after `fn`, an identifier means a declaration and `(` a lambda.

**Semantics stated where they were implied.**

- §3.4: `with` binds to the nearest arrow in a declaration's return annotation too, with the two spellings shown.
- §3.10: `a < b` is `T.compare(a, b) == Less`; a type without `compare` has no ordering and `<` on it is a type error; the prelude's four `compare` functions are named. §4.8's "built into the language, not per-namespace" for the comparisons was contradicted by "uses each type's `compare`" in the same sentence; it now says they cannot be defined per type and resolve through `compare`.
- §4.6's top-level `let` paragraph limited type-member prefixes to abstract types, contradicting §4.2 and §4.8, and read as if `let empty` silently became `let Stack.empty`. Rewritten.
- §5: `fn`, `if`, `match`, and `receive` are alternatives of `Expr`, not `Primary`, so `1 + if ...` is a syntax error. Stated, since OCaml, Haskell, and Rust accept the unparenthesized form.
- §5.11: a segment with no specifier is `int` of size 8; the value type of each specifier is listed.
- §6.6: `let` transfers a reply obligation as `match` does, and an `if`, `match`, `receive`, or block whose value is reply-carrying is subject to the discipline at the site where its value is bound or consumed. Neither case was covered.
- §6.9: `monitor` on an already-dead process delivers immediately, and each call produces one message. Erlang's rule; least surprise on BEAM.
- §9.1 lists `Foreign` with the built-in types. §9.3 had `type Foreign` with no constructors, which `TypeDecl` does not admit.
- §9.6 adds `Bytes.<>`, which the glossary already named. Appendix E.5 adds `String.trim` and `String.toLower`, which §5.7 already used.
- Appendix D no longer mentions `Ok(v)` and `Error(r)`, constructors that exist nowhere in the report.
- §8.1 and §11.2 write `--main Qualified.name`; §11.2's own rule requires a lowercase final segment.

**Terminology for readers from other languages.**

- §6.6 says in its first paragraph that `Reply(a)` is a linear type and that the section spells out consumption. The rules were all there; the word was not.
- §3.10 says the equality constraint is a qualified type, `Eq a =>` in Haskell's spelling, inferred and never written.
- §3.9 says plainly that *empty* is not a type, that an effect-only variable ranges over mailbox types plus empty, and that this is the one departure from plain Hindley-Milner. The "one kind of variable" heading stays, but the text no longer claims more than it delivers.
- §3.9 states that the three inferred, unwritable restrictions are a deliberate exception to principle 3, in exchange for shape-only signatures.
- §6.1 gains a three-row table contrasting `(A) -> B`, `(A) -> B with M`, and `(A) -> B with m`. §6.8 says `with Never` is for process roots and that a send-only helper meant to be called from process code stays polymorphic, because a `Never` function can only be called where the mailbox is `Never`. The guide hinted at this under `ping`; the report never said it.

**Structure.**

- The "Diagnostics" paragraph of §3.10 and the diagnostics clause of §3.9 moved to a new §11.5. They described compiler output, not the language.
- The "Timeout rationale" paragraph of §6.6 moved here: the mandatory timeout on `Address.call` returns `Optional(a)` so an answer that never arrives has somewhere to land; `Address.callForever` opts out of that by name, and the caller accepts that the call may hang.
- The header carries a full revision date, "Revision of 17 September 2026", instead of a month.
- Alignment padding in the code blocks of §9.6 and Appendix E collapsed to single spaces, per the style guide.

**Guide synced the same day.** `ernest_guide.md` was read against the revised report. Fixed: a stale sentence claiming a lowercase-collision rule between path segments (§11.1 requires lowercase, so none can collide); "cannot be stored" for `Reply`, now "linear"; "imported by qualified name" where there is no import. Added for sync: string escapes, ordering through `compare`, non-operand forms, the complete process-only list, `let` passing a reply obligation, `after`-only `receive` under `Never`, `monitor` on a dead process, bitstring defaults, and a FAQ entry on `with Never` versus `with m`. Two things the guide stated that the report did not were added to the report: `kill` is asynchronous (§6.9), and §6.8's send-only example is now `Io.println`, since `ping` is a spawn root rather than a helper.

**Decided the same day, after asking:**

- *`Never` and `after`.* §6.8 banned every `receive` under `Never`, and an `after`-only `receive` is the language's only sleep, so a `Never` process could not pause. Now a `receive` with only an `after` clause is legal under `Never`; a pattern clause is still a type error. It matches nothing, so nothing invisible is admitted.
- *Shadowing and uniqueness.* §4.2's lookup order already made local declarations win over the prelude but never said shadowing was legal; the tick game's `type Key = Up | Down | Left | Right` shadows three prelude constructors. §4.2 now says a module may shadow prelude names, that the local one is meant wherever the name is unqualified in that module, and that within a module type names and constructor names must each be unique, because nothing but the name identifies a constructor. Type-directed disambiguation was rejected: it is not first-token, and it costs the checker a case analysis for a convenience nobody asked for.
- *"empty" → "pure", "non-empty" → "process-only".* The distinguished value an effect variable may take when a function has no mailbox was called *empty*, and the restriction on the process primitives *non-empty*. "Empty" evokes the empty type, which is `Never`. The value is now called *pure*, and the restriction *process-only*, in §3.9, §11.5, and the guide. Entries dated before 2026-09-17 keep the old words.

## Five Sentences From the First Implementation, 2026-09-17

The lexer, parser, and type checker were written against the report the same day as the read-through. No rule failed; the grammar's lookahead claims held on every example. Five places were silent and the checker had to choose; the report now says what it chose.

- *§6.6, reply-carrying through parameters.* A declared type is reply-carrying at any instantiation whose argument is (`Box(Reply(Int))`); a built-in type never is through its arguments (`Address(PongMsg)` is an address). The first implementation propagated through built-in arguments too and flagged every counter's address as a reply.
- *§5.5, when `<-` is resolved.* After inference of the enclosing definition, from `e`'s type or, failing that, the block's type. Inside a recursive group `e`'s type can be a placeholder when the binding is met.
- *§6.1, a function none of whose calls determines an effect.* It is pure. The guide's `fn double(n) = n * 2 // inferred (Int) -> Int` assumed it; the report had not said it.
- *§6.6, passing a reply to a polymorphic parameter.* It is consumption, at that instantiation; the callee's not-reply-carrying restriction (§3.9) rejects a callee that would duplicate or discard it. This is what makes `identity` usable on a reply and `first` not.
- *§4.5, a type-member name on a block-local fn.* The grammar admits it through `DeclName`; it is now an error, since a local function has no type to be a member of.

## Warts Audit, 2026-09-17

After the first implementation, the checker was read again for approximations and unstated choices, with the rule now in CLAUDE.md: none may remain. Seven were found. Two needed the report:

- *§6.6, a reply-carrying expression neither bound nor consumed.* `Get(reply = r); Unit` consumed `r` into a message and dropped the message. The discipline spoke of binding sites only; it now covers unbound expressions, and `_` over a reply-carrying value anywhere.
- *§3.9, type variables in lambda annotations.* Signature variables scope over the whole definition, lambdas included, and stay rigid there; a name new in a lambda's annotation is that lambda's own and is not rigid, since a lambda is not generalized and so cannot be as polymorphic as an annotation would claim. The checker had given lambdas fresh variables for every name, so a definition's `a` used in a lambda was a different type.

Five were bugs against the report as written: the not-reply-carrying flag was inferred only for bare-variable parameters, so a discarded variable inside a tuple pattern escaped it; an abstract type's signature accepted a member less general than declared, because the signature's variables were not rigid; duplicate field names in a constructor pattern were not rejected; `foreign fn ... with m` did not get the process-only flag of §3.9; and the lexer treated `////` as a plain comment, which the report does not say.

## `Down`'s `function` Field and the Already-Dead Reason, 2026-09-17

Writing the runtime needed two things §6.9 had not said. `Down(reason, function)` never defined `function`: the runtime cannot name the function a process ran, since `spawn` takes an arbitrary lambda, but it does know where the lambda was spawned, so `function` is the qualified name of the spawning function with the line of the `spawn` call, `Counter.main:19`, and the entry point's name for the entry process. And a process that died before `monitor` was called reports the cause of its death: the runtime remembers how every process it started ended. The first draft said `Fault("died before monitor")` instead; the first test showed why not: a worker that returns at once is already dead when the next line monitors it, and a fault for a normal return is the surprise principle 1 forbids. Remembering costs one monitor per process and one table row for the program's lifetime.

## Acyclic Modules and Interface-Based Recompilation, 2026-09-17

Two sentences in §11.1, prompted by a reviewer's question about compile times. The module dependency graph is acyclic, and a cycle is a compile-time error: dependency-order compilation presumed it, and §8.5's load-time cycle check is thereby confined to initializers. And `ernc` recompiles a module when its source or the interface of a dependency changed, not when a dependency's file is newer, so a body-only edit does not cascade through dependents; this is OCaml's `.cmi` fingerprint and Rust's, and it is what makes separate compilation worth having. The mechanism, hashes stored in the `.erc` beside the interface and a canonical form for interfaces, is in the plan, not the report.

## Long Options and `--emit erl`, 2026-09-17

§11 gets one sentence: options are long, `--name value`. The report had `-I` and `-o` on `ernc` and long names everywhere else; `-I` means "add an include path" in every C-family compiler, which the source root is not, so the least surprising spelling is `--source-root`, and `--out-dir` is what rustc and the TypeScript compiler call the mirrored output directory, matching the report's own "build-dir". Short aliases can be added later without changing anything. `--emit erl` writes the module's Erlang source instead of the `.erc`, in rustc's `--emit` shape, for reading the compiler's output; `--doc` stays its own mode because it writes to stdout, not into the build tree.

`--repl` became `--shell` the same day: it is one more option of `ern`, given with any of the others, and what it adds is a shell process in the running program, as the Erlang shell is a process in a running node, not a loop that replaces the program. A bare `ern --shell` is the special case with nothing loaded.

## Three Sentences From the Toolchain Audit, 2026-09-17

Running the toolchain against small programs found three places where the report was silent or said too much.

- §4.2: a module namespace may not coincide with a prelude namespace. A file `io.ern` compiled without complaint and was unreachable, since `Io.println` resolved to the prelude; the least surprising reading is that the file is an error, not that the prelude loses.
- §5.4: a local `fn` body sees the bindings in force at its declaration. §4.6's shadowing rule already implied it, but the checker had been reading "the `let` bindings it references" by name, which accepted `let x = 1; let y = f(); let x = 2; fn f() = x; y` although `f` uses the second `x` before it exists. One sentence removes the doubt; the checker follows binding instances, and so does the compiler, which had been rejecting any local `fn` over a rebound name rather than guess.
- §8.5: the load-time clause for cross-module `let` cycles is gone. With §11.1's acyclic module graph such a cycle cannot exist, so the sentence described a check that could never fire.

## One-Word Module Names, 2026-09-17

§11.1's path shape rule loses underscores: a segment is a lowercase letter followed by lowercase letters and digits. Under the old rule `net/http_server.ern` gave `Net.Http_server`, a namespace segment that reads neither as a word nor as a typename. The alternative, converting `http_server` to `HttpServer`, is a hidden rewrite of the name the user typed, against "nothing invisible", and not one-to-one without a second rule about digits (`x_1` and `x1` would both give `X1`). Forbidding the underscore is the smaller rule: nothing is rewritten, the mapping stays trivially one-to-one, and a multi-word module is written as the nesting it usually is, `http/parser.ern` for `Http.Parser`, with the one-word spelling as the visible fallback. Go's package convention, made a rule. The four examples with underscores in their names were renamed: `pingpong`, `upgrade`, `snake`, `kvparser`.

## `--doc` Prints Types, 2026-09-17

§11.5 already said that `ernc --doc` shows the inferred restrictions "the same way" as error messages, which presumes it prints types; §11.4 said only that it extracts doc comments. §11.4 now says what is listed and that each entry carries its type: every exported declaration, documented or not, since a module's documentation is its interface, and every documented private one. The tool type-checks the file, so it takes the source root and build directory of a compilation and fails on a type error like one.

## Types Print as the Module Writes Them, 2026-09-17

The printer behind error messages and `--doc` qualified a module's own types with the module's namespace, `Stack.Stack(a)` inside `stack.ern`. §11.5 now says a type name is printed as the module would write it, which is §4.2's naming rule applied to output rather than a printing convention of its own: local and prelude names bare, other modules' names qualified, and a local type that shadows a prelude name qualified, since that is the one case where the bare name would be ambiguous in a message that can mention both.

## Type Variables Keep Their Names, 2026-09-17

The printer named every variable afresh, `a`, `b`, `e`, so `--doc` showed `new : () -> Table(a, b) with e` for a function declared `-> Table(k, v) with m`. That is a rewrite of the source with no information in it, and in documentation the author's names are the information. §11.5 now says a variable prints under its annotation's name, with the fresh names for the rest. The checker already holds the names, since §3.9's rigid variables come from the annotation; they now stay on the variable, travel in the scheme into the interface, and are left out of the interface hash, since renaming `k` to `key` is not a change a dependent should recompile for.

## Appendix E: Three Rules and a Consistency Pass, 2026-09-18

The growth rule, a function enters when three programs write it by hand, was made for language features, where adding is dangerous; for a library it produces a minimal set, not a complete one, and a library function is cheap to add and expensive to lack. Appendix E now states three rules in its preamble: in when the value lives in the runtime or when the hand-written version is the same few lines every time; one function per job; the same name for the same operation in every module that has it, container first, `isX`, `toX`/`fromX`, `Optional` for partial operations, `compare` for order. Read with them, the appendix was inconsistent: `Set` had no higher-order functions, `Map` half of `List`'s, `String` had `all` but not `any`, `String.chars`/`fromChars` where every other module says `toList`/`fromList`, and `Map` could not be built from a list. Added: `List.zip`, `flatMap`, `range`; `Map.filter`, `any`, `all`, `find`, `fromList`, `toList`; `Set.map`, `filter`, `foldLeft`, `any`, `all`, `find`; `String.toUpper`, `split`, `join`, `any`; renamed `String.chars` and `fromChars` to `toList` and `fromList`. Not added, by the second rule: `List.foldRight`, `Optional.orElse`, `Int.pow`, and `Float` mathematics beyond the operators, which is a namespace of its own and waits for a program that needs it.

## Appendix E: Admission and Shape Rules, 2026-09-18

The three rules of the morning's entry left two judgments open: "the same few lines every time" has no test, and "the same name for the same operation" had no vocabulary behind it. The draft still had `Map.put` beside `Set.add`, `List.at` beside `Map.get`, `Io.printlnTo(addr, s)` beside `Io.println(s)`, and `List.remove` and `Char.isAlpha` with contracts the Erlang modules chose and the appendix did not state. Appendix E.0 now states four admission rules and six shape rules in their place.

**Admission.** Runtime-bound (the closed list of shims); algebra-complete (a container provides the container vocabulary, or says which item it lacks and why; a conversion has its inverse); corpus-driven (one program under `examples/` is enough, when the hand-written version has no policy choice); and no compositions (one pipe of two functions is not a function). The corpus rule replaces the three-uses rule for good: a library function is cheap to add and expensive to lack, and the corpus is the measure, not a count.

**Shape.** Subject first, callbacks last, accumulator between; one verb per operation, with the vocabulary listed; conversions named by the other type and living in the subject's module, several policies being several names; partial returns `Optional`, faults only per §7.4; pure unless the value lives in a process; every contract the type does not state is in the signature's comment.

**Why not Erlang's or Gleam's list.** Erlang's stdlib is shaped by the absence of static types: the `lists:key*` family exists because tuples-as-records had no type, and `{ok, V} | {error, R}` is a runtime protocol where Ernest has `Optional`, `Either`, and `<-`. Gleam's is the nearest model but has no effect system, no linear `Reply`, and no `Never`, so its combinators cannot say whether a callback sends; every Ernest combinator does. What neither has is what follows from Ernest's own concepts, `via`, `monitor`, a pure `Random`.

**Six decisions the rules could not make.**

- Insertion is `put` in both `Map` and `Set`; `Set.add` is renamed.
- Lookup is `get` by index and by key; `List.at` is renamed.
- `Io.printTo` and `Io.printlnTo` take the string first and the sink second, so the pipe works as it does for `Io.println`. The process primitives of §9.4 and §9.5 stay address-first; they are prelude, not stdlib, and `send(a, v)` is not a subject-first transformation.
- `String` is not a container; its character operations go through `toList`. `String.any` and `String.all` are the stated exception, by the corpus rule: every parser tests the characters of a string.
- `Char.isDigit`, `isAlpha`, and `isSpace` use Unicode categories, the honest reading of a `Char` that is a code point. The Erlang modules were ASCII-only and did not say so.
- `Random` is a pure stdlib module, not a system process as the plan's MVP 2.5 step 1 recommended: a generator's state does not live in the runtime, and only the pure form is repeatable in a test. `Seed` is a concrete type so `Random.Seed(42)` works as the snake program already wrote it; `Random.next(seed, n)` draws between 0 and `n` inclusive, total on every `n`, inclusive like `List.range`.

**Added by the rules.** `Map.filterMap`, `Map.foreach`, `Set.filterMap`, `Set.foreach` by algebra; `String.toFloat`, `String.toBool`, `Char.fromInt`, `Float.min`, `Float.max` by inverse and by the same vocabulary in every module; `Random` by the corpus. **Removed.** `List.head`: it is `List.get(xs, 0)` and `x :: _` in a pattern, two ways already. Contracts stated: `List.remove` removes the first occurrence; `List.take` and `drop` treat a negative count as zero; `String.split` on an empty separator gives the string alone; `String.lines` adds no empty line for a final line feed; `Float.toString` prints the shortest decimal that reads back; `List.sort` is stable.

**Prelude and stdlib.** §9 now says that a prelude operation in a type's namespace is provided by that type's stdlib module. The prelude lists what must exist; the stdlib module is where it lives. The question "prelude or stdlib" is about which document guarantees a name, never about the code.

**Cost.** Appendix E rewritten, one sentence in §9, the snake program's `Seed` and `Random.next`, the plan's MVP 2.5 entry. Under `lib/`: three renames, two argument swaps, three Unicode predicates, nine new functions, and one new module, pending.

## Appendix E: Read Back Against Its Own Rules, 2026-09-18

The appendix of the previous entry, read against the rules it opens with, disagreed with them in three places. `Io.printTo` and `Io.printlnTo`: no program writes them, and each is one `send`, so admission rules 3 and 4 both reject them; the argument-order decision above was about two functions the rules exclude, and a reader would have met `send(out, s)` beside `Io.printlnTo(s, out)` in one program. Removed; printing to a sink other than `Sys.stdout` is `send(a, s)`. `List.take`, `drop`, `sort`, `zip`, `flatMap`, `range`, and `last` were admitted by no rule: rule 2 named only the container vocabulary, and a list also has order and position. Rule 2 now lists the sequence vocabulary. `String.any` and `String.all` were an exception to "`String` is not a container" on the rule's first application, and a second way beside `toList |> List.all`. Removed. Also: `String.toBool` came from the inverse clause applied mechanically and no program reads a `Bool` from text; the clause now says "when programs read that type from text", and `toBool` is gone. E.13 states that only the low 64 bits of a seed take part, which the code did and the appendix did not say. The `Char` predicates decide ASCII without the regular expression.

## System Modules, 2026-09-18

The report had `Sys.stdout` and `Sys.clock` as addresses, `Io.println` over the first, and the paper programs writing `send(Sys.clock, After(ms = 100, to = via(fn(_) = Tick, self())))` and `Address.call(Sys.fs, fn(r) = Read(path = p, reply = r), 10000)` by hand. Principle 1: a reader who knows `Io.println` predicts `Clock.alarm` and `Fs.read`, not a send. Principle 2: `Io.println` already exists so that nobody writes the send; the same holds for every system process. Rule, in §8.2 and Appendix E.0: a system reference is used through the standard library module of its name, never by `send`; `send` is for the program's own protocols. The message types stay in §9.3 because the module's bodies send them, because a foreign process must know the ABI it speaks, and because `via` and `monitor` need the address to exist.

**Shapes.** A function that delivers later takes a function from the message to the caller's mailbox type and delivers to the caller, `monitor`'s shape: `Clock.alarm(ms, wrap)`, `Keys.subscribe(wrap)`. The clock's functions are `alarm` and `alarmAt`, not `after` and `at`: `after` is a reserved word (§2.4) and so never an identifier, which the first build found. `via` remains the general form between user processes and is what these are with `self()` filled in. A function that waits takes the milliseconds last and answers `Left(Timeout)`: `Fs.read(path, ms)`, `Tcp.accept(listener, ms)`. One error type, `IoError`, for `Fs` and `Net`, because the prelude is one module and its constructor names are unique across its types, and because a program renders errors in its own words; a `toString` for it would be message text, which is policy and stays out. `Entry.mtime` is an `Int` in the clock's milliseconds, not a wrapper, so `>` compares it. `Key` is a keyboard's keys, `Char(c)` and the named ones, not a game's. A socket is `Address(SockMsg)`, not an abstract `Socket`: the type says it is an address, and an abstract type would need an escape hatch the moment a program wants to `via` or `monitor` it; `Socket` as a name would be a type alias, which §3.1 forbids. `Tcp` has no options; framing is bitstrings. The module is `Tcp`, not `Net`: it is TCP and nothing else, `Udp` is its own module when a program needs one, and `Net` is the namespace of the report's own example `net/http.ern` (§4.2), which the first build refused as a prelude collision.

**Processes, not a foreign shim over `gen_tcp`.** The shim is faster and cheaper to write, but brings Erlang's hidden ownership, a socket dying with its controlling process, which principle 3 forbids, and a socket that cannot be monitored, killed, adapted with `via`, or sent to a peer. A read through a socket process costs two hops, a few hundred nanoseconds each on BEAM with binaries over 64 bytes shared, against a syscall; the module hides which, so `Tcp.read` and `Tcp.write` can become foreign calls on the socket's port later without a program changing, and the plan says an echo server decides that on a number.

**`Random` over `rand`.** The morning's SplitMix64 existed so that a seed could be a plain `Int` that travels between nodes and gives the same sequence everywhere; no program asked for that, and writing a generator of our own is exactly what E.0's first rule now says not to do where the runtime's implementation is the one to trust. `Seed` is a foreign type made by `Random.seed`, node-bound like any foreign value.

**Lesson, in CLAUDE.md as a rule.** The drift came from applying the principles to the language only and reading the result back after committing: `send` to system processes, a generator of our own, a reserved word as a function name. The rule is to read the resulting code back as a reader would, before reporting it.

**MVP 1.** `Clock` and `Path` ship now as Erlang modules; the other four references and their modules type-check and `ernc` refuses them with "is not in MVP 1", listed in the README's table, until MVP 2.5 step 4.

## The Erlang Standard Library, Read for Ernest, 2026-09-18

The question that started the day: which of Erlang's modules belong in Ernest's standard library for MVP 2.5, as pure Ernest or as a shim, with the library a sweet spot and not Erlang's accretion. The roadmap that came out of it is plan MVP 2.5 step 5; this entry is the reading and the reasons. OTP 27 has 218 modules in `stdlib`, `kernel`, `erts`, and `crypto`; about 180 are OTP's own machinery, the compiler front end, the shell, `logger`, distribution, the behaviours, supervisors, code loading, which Ernest's concepts or toolchain replace. The forty user-facing ones sort into six bins under Appendix E.0.

- **Already an Appendix E module.** `lists` is `List`; `maps`, `dict`, `orddict`, `gb_trees`, `proplists` are `Map`; `sets`, `ordsets`, `gb_sets` are `Set`; `string` and `unicode` are `String` and `Char`; `math` and the float BIFs are `Float`; the integer BIFs are `Int`; `rand` is `Random`; `io` for output is `Io`; `ets` is `Ets`, Appendix D. Erlang has five map-likes and three set-likes by history; Ernest has one of each.
- **A system process with a module**, §8.2 and E.15 to E.18: `file` and `filelib` are `Fs`; `gen_tcp`, `socket`, `inet` are `Tcp`; `io` for input is `Io.readLine`; `timer` is `Clock`; the keyboard is `Keys`. Of `timer`, `send_after` is `Clock.alarm` and `sleep` is `receive { after ms -> Unit }`, which §6.8 names; `send_interval` is absent on purpose, since a tick scheduled after the previous one is handled is the only shape that neither drifts nor multiplies under a burst of input, as the snake program and guide §5.5 show; `cancel` is absent because an alarm is one message a process can ignore, and a cancel would need a handle and a race. E.15 states both.
- **A new pure module the corpus asked for.** `filename` is `Path`, E.14, which filesync had declared with `todo` bodies.
- **Libraries on the foreign-library pattern, not stdlib.** `base64`, `json`, `uri_string`, `re`, `crypto`, `zlib`, `dets`, `calendar`, `digraph`, `sofs`. Each is a namespace of its own and passes no E.0 rule; `re` is the one a reader may expect in core, and Gleam moved it out for the same reason.
- **Wait for a program.** `binary` as a `Bytes` module once bitstrings show what a protocol needs beyond `<>`; `array` and `queue` until something needs indexed access or a FIFO, since two lists is five lines; `Float.sqrt` and its family; a `Time` module over the clock's milliseconds when a program formats a timestamp; `Sys.args` and `Sys.env` when a program reads them, see below.
- **Out.** `gen_server`, `gen_statem`, `gen_event`, `supervisor`, `proc_lib`, `sys`, `logger`, `application`, `code`, `rpc`, `erpc`, `global`, `pg`, `net_kernel`, `persistent_term`, `atomics`, `counters`, every `erl_*`. A supervisor in Ernest is fifteen lines of `spawn`, `monitor`, and `receive`, an idiom for the guide. Two positions among the outs: `io_lib` and `io:format`, no format strings, `<>` and the `toString` functions being the one way, as in Gleam; and `ms_transform` and `qlc`, no match specifications or query comprehensions, since `Ets` in Appendix D is a key-value table and a query language over it is a library's to add.

**Calibration.** Gleam's core, the BEAM stdlib readers call sweet, is `bit_array`, `bool`, `dict`, `dynamic`, `float`, `function`, `int`, `io`, `list`, `option`, `order`, `pair`, `result`, `set`, `string`, `string_tree`, `uri`. Ernest after MVP 2.5 has the same set under its own names minus six: `function` and `pair` are compositions and patterns here, the two builders are unnecessary with BEAM's binary append, `uri` is a library, and `dynamic/decode` is what `Foreign` and a JSON library cover between them. It has what Gleam lacks: `Random` behind a pure interface, `Ets`, `Path`, effect-polymorphic combinators, and the system modules over typed processes. Nineteen modules; Erlang's user-facing surface is twice that, from history rather than need.

**`Sys.args` and `Sys.env`** wait for the first command-line program, in the plan's list, rather than entering now: they are two lines, but nothing under `examples/` reads them, and the corpus rule is the rule.

## Gleam's Standard Library, Compared, 2026-09-18

Gleam stdlib v1.0.5, the BEAM library readers call sweet, read module by module against Appendix E. At module level Ernest has Gleam's set under its own names minus `function`, `pair`, `string_tree`, `bytes_tree`, `uri`, and `dynamic/decode`, which are patterns, compositions, or libraries here, and has `Char`, `Random`, `Path`, and the system modules, which are separate packages in Gleam. `Map` and `Set` match `dict` and `set` function for function, with `find`, `any`, `all`, and `filterMap` on top. `Optional` and `Either` are thinner than `option` and `result` because `<-` does what `use` and `result.try` do, and the rest are compositions.

At function level `String` had eighteen functions to Gleam's thirty-nine and `List` twenty-three to sixty-two, and the gap held things a reader reaches for without thinking. Admitted, each needing recursion or the runtime and so not a composition: `String.startsWith`, `endsWith`, `replace`, `slice`, `padStart`, `padEnd`, `repeat`; `List.partition`, `unique`, `indexed`, `repeat`, `unzip`, `tryMap`, `tryFold`; `Map.merge`, since `Set` had `union` and `Map` had no way to combine two; `Set.isSubset`, set algebra rule 2 implies. `indexed` is one function where Gleam has `index_map` and `index_fold`, since the pair list feeds `map` and `foldLeft` as they are. `tryMap` and `tryFold` are what `<-` cannot do inside a `map`. The pad functions take a `Char`, one job, where Gleam's take a string. The new verbs, `partition`, `unique`, `indexed`, `repeat`, `unzip`, `tryMap`, `tryFold`, `merge`, `isSubset`, `startsWith`, `endsWith`, `replace`, `slice`, `padStart`, `padEnd`, are in E.0's sequence vocabulary or are one type's algebra.

Not admitted: Gleam's other thirty `list` functions, compositions (`first`, `rest`, `flatten`, `count`, `map2`) or specialities (`permutations`, `window`, `transpose`); `order`, since `Ordering.reverse` is `fn(a, b) = compare(b, a)`; `pair`; `function.identity`; `bool.guard`; `string.inspect`; `bit_array`'s base64, a library. Sent to the plan's bins: `Float.looselyEquals`, the honest float comparison, waiting for a program that compares floats; and stderr, which Gleam's `io` has as `print_error` and `println_error` and Ernest removed on 2026-09-14, restored as `Sys.stderr` with `Io.printError` and `Io.printlnError` at the first command-line program.

## Path by Its Structure, 2026-09-18

`Path` entered Appendix E by the corpus rule with the three functions filesync had written, `join`, `toString`, `withSuffix`, and nothing else, because rule 2's vocabulary named containers and sequences only. That is the too-minimalistic failure of the morning on a smaller scale, and `withSuffix` was a composition, `Path(Path.toString(p) <> s)`, that rule 4 excludes; the corpus had carried it in. E.14 now has what a path's structure gives and every path library agrees on, `filename`, Gleam's `filepath`, Rust's `Path`: `join`, `split`, `parent`, `name`, `extension`, `withExtension`, `isAbsolute`, `toString`. Left out: `absname` and `expand`, which read the working directory and are `Fs`'s, and `nativename`, since a `Path` is already in the runtime's syntax. `withSuffix` is gone; filesync writes the composition.

Rule 2 now says each kind of type has a vocabulary, lists text's and a path's beside the container's and the sequence's, and ends with the sentence that closes the gap: a type that enters by rule 3 still gets its structure's vocabulary, not only the functions the program wrote.

## Fs by Its Structure, and the Table, 2026-09-18

`Fs` had the three functions filesync wrote, as `Path` had, and the question about `filelib` found it: everything in `filelib` touches the filesystem and so is `Fs`'s by rule 8, but `Fs` had no vocabulary to receive it. E.17 now has what a filesystem's files and directories give and `file`, `filelib`, Gleam's `simplifile`, and Rust's `std::fs` agree on: `read`, `write`, `append`, `list`, `stat`, `makeDir`, `remove`, `rename`, `copy`. `stat` answers `is_dir`, `is_file`, `last_modified`, and `file_size` at once, so `Entry` in §9.3 carries `size` and `isDir` beside `mtime`; `makeDir` has `ensure_dir`'s semantics. Left out: `wildcard`, a glob language that is a library's; `fold_files`, five lines over `list`; `watch`, waiting for a program that must not poll, since filesync polls on a tick; `absname` and `expand`, waiting with the working directory. Rule 2 gains the filesystem line. §8.2 says `keys` and `stdin` are the same terminal, which the report had left unsaid.

The pattern behind `Path` and `Fs` is that a module admitted by the corpus rule got the corpus's functions and nothing else, and the function-level decisions from reading `filename`, `filelib`, and `timer` had been made in conversation only. The plan's MVP 2.5 step 5 is now a table, one row per user-facing OTP module, with what Appendix E took, what waits and on what trigger, and what is out and why, so that a decision of this kind has a place to be recorded and a place to be found.

## The Final Pass, 2026-09-18

Appendix E read one last time against E.0 and against `gleam_stdlib` v1.0.5, OTP 27, Elixir's core, and Haskell's `base`, module by module. It holds: every module has its structure's vocabulary, every verb means one thing everywhere, every partial operation returns `Optional`, every contract the type does not state is a comment. `List` has thirty functions to `Data.List`'s hundred, `Enum`'s hundred, and `gleam/list`'s sixty-two, and what is not there is a composition the pipe writes or a speciality. `Optional` and `Either` are thin because `<-` is what the other twenty in `option` and `result` imitate. No type classes, no laziness, no format strings, no registry, no exceptions: positions the report states.

Four things came out. `Map.update`, the counting idiom of get then put, is in snake's `applyInput` and in every word count, a `match` around two calls rather than a pipe of two, so rule 3 admits it and rule 4 does not exclude it; Gleam's `upsert`, Rust's entry. `Char.isUpper`, `isLower`, `toUpper`, `toLower`: `String` had the case operations and `Char` none, against "one verb in every module that has it"; Unicode shims, and a character whose case mapping is several, `ß`, maps to itself. `eunit` had no row in the plan's table, and Ernest will need a `Test` module the day the first test is written in Ernest; the row waits on that. The other OTP applications, `ssl` to `snmp`, `observer` to `parsetools`, got rows as libraries and tooling, so the table has every application and not only the two the question started from.

## Paring the Report, 2026-09-18

The report was complete and three times over its own measure: sections 0 to 11 without code blocks or tables were 13,084 words, about thirty-three pages, against the ten pages of "Measure" below. The long sections stated a rule, restated it with examples, then defended it. One pass, every heading kept, every code block kept byte for byte, every cut inside a section, the mirror tests and the section citations proving nothing normative moved: 7,635 words after, 81 sections, median 76 words, the longest, §6.6, 548. The rest is rules, and a further cut would remove rules, so the measure is revised below rather than the report cut past it.

What left the report, by section, and lives here now:

- §3.1: `Int.mod` gives `%`'s result and a mathematical modulo is written in Ernest when needed; the finite `Float` domain is BEAM's, and a program that needs non-finite arithmetic handles those cases before they arise.
- §3.2: the `#(` prefix keeps tuples distinct from grouping and from function types.
- §3.5: names are required past one field because position alone would hide what a field means; canonical order is what lets two nodes that declare a type with reordered fields agree on layout.
- §3.9: annotations describe shape only, so the inferred restrictions stay out of the annotation grammar and are shown by the compiler instead; the process-only restriction on the primitives is a rule of the prelude, not of the grammar; unification does the rest once the value-position rule ties the two occurrences of `m`.
- §3.10: the equality constraint is `Eq a => (a, a) -> Bool` in Haskell's spelling, inferred and never written; checking at instantiation matches the check on concrete types.
- §4.2: canonical namespace segments are one-to-one with lowercase paths so the compiler and the loader agree on a spelling; a declaration carries no namespace prefix because repeating `Net.Http.` on every line would restate the file's path.
- §5.7: the pipe reads left to right, which suits subject-first call chains; an unparenthesized lambda after `|>` would swallow the rest of the expression.
- §5.11: a `bits` segment bound to `Bytes` must be byte-sized because a 3-bit `Bytes` value does not exist; size-dependent matches are what protocol parsing is; bitstrings compile to BEAM's bit syntax so its optimizer handles prefix-heavy matches.
- §6.3: coverage is not required so that a `receive` can wait for one reply in the middle of a protocol without losing other messages.
- §6.6: `callForever` opts out of the timeout by name, as a `receive` without `after` does; the reply-carrying property is by type because the checker cannot tell which constructor a value holds; `as` on a reply-carrying scrutinee would duplicate the obligation, and a wildcard would drop it silently.
- §6.7: `remote` is a one-shot compute-and-return, which is why `f` is pure; its failure modes expose runtime state, which is why `remote` itself carries a mailbox effect; a caller that wants cancellation or per-task timeouts spawns processes.
- §7.4: `todo` exists so an unfinished function can be declared before it is written.
- §8.1: a project may have several entry-point modules, a service main, a migration main, a bench main.
- §8.4: preserving a constructor's case in its atom makes the tag injective.
- §8.5: purity does not imply totality.
- §8.6: `Sys.*` processes count as external event sources by default; whether a user-provided foreign event source does is a runtime's decision.
- §8.7: hashing a recursive group by position gives a finite construction; an abstract type's signature is in its hash because the abstraction boundary is part of its identity; a captured address ships as a value because captures capture values, not names.
- §11.1, §11.2: the path-shape rule validates each path compiled or loaded and does not scan a tree; `--create-config-dir .` does not conflict with `--load-path .`.

## What the Reply Check Guarantees, 2026-09-18

A reviewer's objection: exactly-once answering cannot be checked statically. Half true, and the report says which half. That `answer` is *reached* cannot be checked by any static system: a fault, a loop, a `receive` that never matches, or a `kill` bypasses it, which is the halting problem, and §6.6 states that the check is static in flow, not in dynamics. The "at least once" half is therefore handled dynamically, by the timeout of `Address.call`, with `callForever` opting out by name. The "at most once" half and "every path consumes" are what linear types check soundly, as Rust checks moves and session types check channels: a second use on any path is a type error, and the positions where a reply could be consumed any number of times, `List`, `Map`, `Set`, `Optional`, `Either`, a lambda called twice, are forbidden. The one hole the checker cannot see is foreign code holding a `Reply` handle, and the runtime closes it: a `Reply` is an alias that deactivates on the first answer, so a second answer is discarded like a late one. §6.6 now says so.

**Why the static half is decidable.** Because the language restricts where a `Reply` may live. A reply-carrying value may be a parameter, a `receive`-bound variable, a constructor field or tuple component, a capture of a lambda handed to `spawn`, or the result of a function typed to return it; it may not be an element of a `List`, `Map`, `Set`, `Optional`, or `Either`, an operand of `==`, or an `as` alias; consumption is one of six syntactic forms. With no aliasing and no collections, "consumed exactly once on every path" is a syntactic property of each function body. The check runs per function and crosses no call: an obligation handed to a callee is discharged by the callee's parameter type, and the callee is checked at its own definition; a polymorphic function that would duplicate or drop its argument gets the not-reply-carrying restriction of §3.9, and instantiating it with a reply is a type error at the call. This is the construction of Rust's move checking, sound for the same reason. The price is expressiveness: a server cannot hold pending replies in a `Map`, it holds each in a process, filesync's one process per write. That is a trade to argue with, not an impossibility. The falsifiable form of the claim: an Ernest program the checker accepts that answers one `Reply` twice, or drops one on a path. If one exists, the check is wrong.

## Diagnostics, 2026-09-18

Before 3.4, since 3.4 is about where an error is reported and what expectation it names, and both are spans and labels. The format is what every compiler has converged on by 2026, Rust's shape in Elm's spirit: a first line a tool parses, `file:line:column: message`, unchanged from before so the README's table test and editors keep working; the source with a gutter and one line of context; the span underlined, not a caret at a column, since a token or expression has a width; a second span with a label where the message depends on one, the declaration that fixed an expectation or a first use; one help line naming the fix. Not taken: error codes with `--explain` pages, which pay off at Rust's scale and cost a numbering scheme, principle 5; Elm's chatty register, since the error should sound like the report; colour before there is an editor to show it; auto-detecting a terminal to change the output, which would be an invisible difference, so `--errors short` is an option instead. The diagnostic is data before it is text, so the terminal renderer and a later JSON renderer for an LSP are two views of one record. Spans required an end position per node, which the AST did not have: the lexer now gives each token its end and the end of the token before it, and the parser closes every node's span from the token before the rest, one helper at every node's return, with no change to the parser's shape.

## Type Error Placement, 2026-09-18

Plan 3.4, done. Bidirectional checking at the boundaries where a type is known, an expected-type argument threaded through branches, clauses, and blocks to the leaf, rather than inferring up and unifying at the enclosing node; §11.5 states where a mismatch is reported so the placement is a rule, not a quality. Both whole types stay in the message, since at a leaf they are short and a reader compares them as written; the differing part is the help line only when the types differ inside, because printing only the part hid what the argument was, `expected String, found Int` for a `Stack(Int)` where a `Stack(String)` was wanted. Arguments are checked one at a time against the parameter types of a known callee, so the old whole-function-type messages, `expected (Int) -> Int, found (String) -> a`, are gone, and the callee's type is the label instead. An effect error had said "process code called from a pure function" wherever the checker stood; it now names the callee and what is pure, since the fix depends on which, a `with` on a function, a different place for a `let`, a value computed before a guard. The parser's mandated diagnostics carried the fix after a semicolon; the help line is that fix, the message the rule, one shape for every stage. An operator expression's span moved from its operator to its left operand: a label on a guard or a mismatch on a whole `a + b` underlines the expression, and the operands' own spans were already right. Not taken: reporting the first use of a variable as a label, which the earlier §11.5 text named as an example and no message needed, since the checker has no per-variable origin table; the example left the report with it. A second label per diagnostic, which §11.5 allows, no placement needed.

## Later

Planned or considered, not in the language today.

- **Persistent data structures in the standard library.** Everything is immutable, so `Map.put` on a large map must share structure (Clojure) or be O(n). A requirement on the stdlib, not the language, but it must exist from the start; otherwise every stateful process is slow in a way the code does not show.
- **Content addressing, MVP 3.** Every definition gets a hash, and code follows messages to nodes that lack it. Not a core concept but the answer to how a node gets code; Erlang's module distribution is Erlang's weak point. Gives `Upgrade` over the network, types to nodes that have never seen them, and version mixing as an error at connection instead of undefined at `send`. Names as metadata and the codebase as a database remain outside.
- **Cross-version message types, MVP 3.** Two nodes with different versions of the same type. Undefined today because MVP 1 and MVP 2 are single-node. Two shapes considered for MVP 3: *reject at send* (each message carries the type hash, receiver refuses unknown hashes, sender gets a `Fault` or `Left` back — simpler runtime, forces version alignment) and *fetch on receipt* (receiver fetches unknown type definitions from the sender, closer to Unison — more flexible, more complex because types have transitive dependencies). Leaning reject-at-send for MVP 3, fetch-on-receipt as MVP 4+ if paper programs need it. Decision waits for MVP 3.
- **Local state in pure code.** Unison's `{State}` is not mutation but threading that the handler does for you; `Scope.ref` is real mutation for algorithms on arrays, Haskell's `ST`. Ernest has recursion and accumulators, and state lives in processes. Two reasons to want more: convenience (three counters as arguments), where the answer is to write the argument; performance (update in place), where the answer is persistent data structures, already a requirement. `let mut` is not introduced for either; the tick game confirmed it: three counters became a fold with a tuple accumulator, and when the tuple grows the answer is a named type with `..`. Unison's only real mutation in pure code is `{Scope}` with `Ref` and mutable arrays; it can be removed without losing any capability, only a constant, and a second effect would be abilities back. If a mutable array is needed anyway, it is a process that owns it, Erlang's ETS. To be tested further in the Unison week: an algorithm with three counters without `{State}`.
- **`Erl` in the stdlib.** `Erl.atom : (String) -> Foreign` and `type Erl.Result(v, r) = Ok(v) | Error(r)`, so that shims do not redeclare them. A stdlib module (`stdlib/erl.ern`), not a language addition, admitted by the first rule of Appendix E.0 since an atom's value lives in the runtime; in the plan under MVP 2.5, step 4.
- **`Slot(a)` for language-level credit.** One-shot capability parallel to `Reply(a)`: a consumer allocates and grants slots to a producer via message, the producer sends by consuming a slot per message through `useSlot(s, v)`, and the consumer refills after processing. Same linearity check as `Reply(a)` — a `Slot` bound in an arm is consumed exactly once on every path. The compiler enforces that a producer does not send without permission. Deferred: only helps producer-consumer patterns, and the credit protocol as convention has not been written three times yet. When it has, this is the shape to reach for; see Backpressure above.
- **Idioms for the guide, not the report.** Links and supervisors: `monitor(child, Died)` and returning on `Died` is a link; a supervisor is fifteen lines of `spawn`, `monitor`, and `receive`. Parallel remote computation: `remote(f)` waits, so ten at once are ten local processes each calling `remote` and replying, which is what Unison does under `Remote.fork` and `await`, visibly.
- **Canonical formatter.** A gofmt-style formatter — mechanically simple given the recursive-descent grammar, small bounded lookahead, and no layout sensitivity. One canonical style, no configuration; killing style debates on day one is easier than after a community forms. A toolchain item, not a language item; expected as part of the `ern` binary. The guide will point at it when it lands.
- **A measure of the specification's length.** Wirth's Oberon report is sixteen pages and shrank with every revision. If this document, without examples, grows past ten pages, one concept too many has come in.

## Paper Programs and Measurements

- [`examples/webserver.ern`](../examples/webserver.ern): web server with sessions. Gave `via`, timeout in receiving, signature on opaque types (which caught a call to an undefined `SessionId.parse` on paper). The process-then-table progression showed the value-versus-process-versus-table decision in twenty lines. Rewritten on 13 September with an ETS table for the session store, the first program to use `foreign fn`, and with `Reply(Bytes)` on `SockMsg.Read`, dropping the `HandlerMsg`/`Data(Bytes)` wrapper.
- [`examples/filesync.ern`](../examples/filesync.ern): file sync between two nodes. Gave `monitor` and `kill` as functions, `Sys` as values, named fields, the clock with a value, backpressure as convention (a credit protocol in about ten lines per producer). Seven matches on `Either` across the whole program, none nested; five process loops in two programs where the earlier `recvFor` timeout arm was never reached; `sys` threaded as the first argument of six functions was the price of no dynamic binding.
- [`examples/snake.ern`](../examples/snake.ern), then `tick_game.ern`: snake game with ticks. Gave definitions in blocks (closes `where`), `At` and `Now`, `Sys` as the runtime's type, the value-versus-process criterion (one process per player was parallelism nobody asked for), the answer on local state (three counters became a fold with a tuple accumulator; when the tuple grows, a named type with `..`), and the case against `Nat`.
- [`examples/repl.ern`](../examples/repl.ern): REPL with lexer, parser, evaluator, and `try` as a process. Gave `<-`, the warning about `self` in `spawn`, `TryError`. The evidence for `<-`: without it, 43 of 140 lines of pure code were `Left(e) -> Left(e)`, thirty percent that said nothing; with it, the same code is fifteen lines against twenty-four.
- All paper programs: `spawn(Local, ...)` after placement became an argument.
- The web server comparison (an Erlang version of the same program, removed 2026-09-17): the same web server in Erlang. Without type signatures six percent more characters, almost all in the filter function (45 characters each time, twice), which was subsequently dropped when `recv` became a form with arms and `after`.

## Form of the Report

The language report is self-contained: no references to other languages, no history. The order runs from characters to programs, so that every term is defined before it is used: introduction with principles, notation, lexical elements, types, declarations and scope, expressions, processes, errors, programs, prelude, runtime requirements, grammar as an appendix, examples as an appendix. The grammar was written in full in EBNF, which found two ambiguities the prose had hidden: `match Peer { ... }` (constructor with fields, or `match` on the value `Peer`; the rule became that a constructor followed by `{` is always field construction, and `match (Peer) { ... }` for the other), and `after` as the first arm in `recv` (forbidden; `after` is last). The prelude was written as a list, which forced the contents of `Down`: `Down { reason : Reason, function : Text }` with `Reason = Returned | Killed | ProgramEnd | Fault(Text)`, and that `monitor` reports normal death as well. Containers are taken as the first argument in the prelude.

What stood in the specification as reasoning, comparison, or guidance has moved here; see "Reasons Lifted Out of the Report."

## Measure

The report's prose, sections 0 to 11 without code blocks and tables, stays under 8,500 words, about twenty-one pages, with no section over 600 words; it is measured the same way after every pass and recorded here. The limit was 8,000 until §11.5 gained the error format on 2026-09-18, a rule the report had never stated, which is what a limit is raised for. Oberon's ten pages was the measure when the language part was six pages and 2,100 words, and 3,200 words with distribution and the toolchain; the report since gained the reply discipline, bitstrings, system references, code shipping, the standard library's rules, and a toolchain, and after the paring of 2026-09-18 and the placement rule in §11.5 it is 8,167 words of rule in 81 sections at a median of 76 words. A section that grows past 600 words is restating something.

## Next Steps

The paper phase is done: web server, file sync, snake, REPL, and the web server compared with Erlang. The background queue was dropped; it existed for backpressure, which waits. The Unison and Gleam weeks were dropped. MVP 1 is done through plan 3.3, 2026-09-17, and 3.5, the paring of the report, 2026-09-18: the chain from `.ern` to BEAM holds, the nine example programs run through `ernc` and `ern`, and the standard library is Erlang under the ABI. Appendix E has its rules, 2026-09-18, and plan 3.4, type error placement, is done the same day. Next: MVP 2, the whole report on one node; then MVP 2.5, the standard library in Ernest under `stdlib/`, with the report edits its step 1 names first; then MVP 2.6, the first four libraries under `libs/`, driven by one command-line program, with their appendix in the report.
