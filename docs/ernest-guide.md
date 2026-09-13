# Ernest: A Reading Guide

For someone reading Ernest for the first time. Not normative — that is `ernest.md`, the language report. This guide teaches you how to read Ernest so the report and paper programs make sense.

## 0. What Ernest is

A functional language for concurrent programs. Two concepts:

- **Functions**, with Hindley-Milner types and full inference.
- **Processes**, with typed mailboxes, as the only way to affect the world.

Every function runs inside a process. A function that just computes a value is *pure*. A function that sends, receives, or asks who it is uses the process — its type says so, written `(A) -> B with M` where `M` is the mailbox type.

Shorthand for readers coming from other languages:

- **From Erlang** — think gen_servers with static typing, no callback module, and one `receive` form that is exactly Erlang's.
- **From Haskell** — MVars replaced by first-class processes with typed mailboxes, `IO` replaced by process code marked with `with M`.
- **From Gleam** — Gleam's actor model with untyped receive replaced by typed selective receive, and no need for `use`.
- **From Rust** — actors first-class, no lifetime annotations, Hindley-Milner instead of trait-based generics.

## 1. Reading the syntax

Ernest source has three syntactic positions. The same visual shape can mean different things in different positions.

- **Type position** — after `->` (return type), after `:` (annotation), inside another type. Example: the `List(Int)` in `x : List(Int)`.
- **Expression position** — the RHS of `=` in a binding, function bodies, arm bodies. Example: `List.map(xs, ...)`.
- **Pattern position** — the LHS of `=` in a `let`, function parameters, `match`/`recv` arm patterns. Example: `let (x, y) = pair`.

The parser knows which position it's in. So do you, once you notice.

### 1.1 Case matters

Names come in two shapes:

- **Lowercase-first**: `ident` — variable, function, field name. `foo`, `bar_baz`, `x`. Also `typevar` in type position — a type variable like `a` in `List(a)`.
- **Uppercase-first**: `typename` or `conname` — type name or constructor name. Same token class; role decided by position. `Foo`, `Peer`, `CounterMsg`.

So `List(Int)` is a type (uppercase Int is a type name). `List(a)` in a type declaration is a type parameterized by `a` (lowercase, so a type variable).

### 1.2 The six roles of `(...)`

Ernest deliberately uses `(...)` for many things, keeping the grammar LL(1) and disambiguating by position and by the first token inside. There are six roles:

1. **Type application.** `List(Int)`, `Address(CounterMsg)`, `Reply(Int)`. Fills type parameters with concrete types.
2. **Type parameter declaration.** `type List(a) = ...`. Names the type parameters.
3. **Function/lambda call.** `f(x, y)`, `Some(5)`, `List.map(xs, incr)`. Applies a function or constructor to values.
4. **Constructor field declaration.** `type Peer = Peer(dir : Path, seen : Map(Path, Mtime))`. The `:` after the first identifier marks it as a field declaration.
5. **Named field construction or destructuring.** `Peer(dir = d, seen = s)` builds a Peer; `Peer(dir = d)` in a pattern extracts one field. The `=` after the first identifier marks it.
6. **Function type argument list.** `(A, B) -> C`. Groups the argument types.

Plus one more, tuples: `(A, B)` as a type, `(1, "hi")` as a value, `(x, y)` as a pattern.

### 1.3 The disambiguation rule

Given any `Foo(...)` in the source, decide by three questions:

1. **What position am I in?** Type, expression, or pattern?
2. **Is `Foo` uppercase or lowercase?** Uppercase = typename or constructor. Lowercase = ident (variable or function).
3. **What follows the first identifier inside the parens?** `:` = field declaration (only in type declarations). `=` = named field. Otherwise = positional expression, type, or pattern.

Some concrete cases:

- `List(Int)` in type position, uppercase, first thing is a type → **type application**.
- `Some(5)` in expression, uppercase, first thing is a value → **constructor call**.
- `Peer(dir = d)` in expression, `=` after first identifier → **named-field construction**.
- `Peer(dir : Path)` in a `type` declaration, `:` after first identifier → **field declaration**.
- `f(x, y)` in expression, lowercase → **function call**.
- `(x, y)` in expression → **tuple construction**.
- `type Stack(a) = ...` after `type`, lowercase `a` → **type parameter declaration**.

If you get lost reading a `(...)`, ask those three questions.

### 1.4 The unit type `()`

`()` shows up throughout Ernest. Two meanings:

- **As a type**: `()` is the *unit type* — a type with exactly one value.
- **As a value**: `()` is that single value.

Not "no type" (like C's `void`). It's a real type; it just carries no information.

`send(a, v)` returns `()`. `main`'s return type is `()`. Any process function that does work without producing a value returns `()`.

You'll see `() with ()` on `main` — meaning: returns unit, mailbox holds unit. Two unrelated uses of `()` next to each other. Reader-heavy but standard ML notation.

## 2. Reading the counter

The counter is the smallest complete Ernest program. Full listing from Appendix B of the report:

```
type CounterMsg
    = Inc(Int)
    | Get(reply : Reply(Int))
    | Upgrade(migrate : (Int) -> Int, next : (Int) -> () with CounterMsg)

fn counter(n : Int) -> () with CounterMsg = recv {
    Inc(k) -> counter(n + k)
  | Get(reply = r) -> { answer(r, n); counter(n) }
  | Upgrade(migrate = m, next = k) -> k(m(n))
}

fn main(Sys(stdout = out) : Sys) -> () with () = {
    let c = spawn(Local, fn() = counter(0));
    send(c, Inc(5));
    send(c, Inc(3));
    match Address.call(c, fn(r) = Get(reply = r), 1000) {
        Some(n) -> send(out, Line("count is " ++ Int.toText(n)))
      | None    -> send(out, Line("counter is not answering"))
    }
}
```

**What it does:** starts a counter process, sends it two increments, asks for the total, prints it.

### 2.1 The message type

`type CounterMsg = Inc(Int) | Get(reply : Reply(Int)) | Upgrade(...)`

Three ways to talk to the counter:

- `Inc(Int)` — a positional payload. Add this integer to the counter.
- `Get(reply : Reply(Int))` — one named field, `reply`, of type `Reply(Int)`. A `Reply(Int)` is a one-shot address the sender expects to be answered on with an integer.
- `Upgrade(migrate : ..., next : ...)` — two named fields. `migrate` transforms the current state; `next` is a new counter function to run with that transformed state. This is code replacement — the process swaps itself for new code.

### 2.2 The counter loop

`fn counter(n : Int) -> () with CounterMsg = recv { ... }`

A function taking the current state `n`. Returns unit. Runs in a process whose mailbox holds `CounterMsg` values. The body is a single `recv` that waits for a message.

Three arms:

- **`Inc(k)` → `counter(n + k)`**. Recurse with the incremented state. Tail call — no stack growth.
- **`Get(reply = r)` → `{ answer(r, n); counter(n) }`**. Send the current state back via `answer`, then recurse. `answer` is the receiver-side counterpart of `Address.call`: it consumes the one-shot `Reply` capability by sending a value back to the caller.
- **`Upgrade(migrate = m, next = k)` → `k(m(n))`**. Apply the migration to the state, then tail-call the new loop. After this arm executes, the process is no longer running `counter`; it's running whatever `k` is.

### 2.3 The main function

`fn main(Sys(stdout = out) : Sys) -> () with () = { ... }`

The parameter is a pattern: `Sys(stdout = out)` destructures the runtime's `Sys` value and binds its `stdout` field to `out`. The `: Sys` is the type annotation. Return type is unit, mailbox is unit.

The body:

1. **`let c = spawn(Local, fn() = counter(0));`** — Spawn a new process on this node running `counter(0)`. `Local` says "on this node, not a peer." Returns `c : Address(CounterMsg)`.
2. **`send(c, Inc(5));`** — Fire-and-forget. Puts `Inc(5)` in the counter's mailbox and returns immediately.
3. **`send(c, Inc(3));`** — Same. Messages from `main` to `c` arrive in order, so the counter processes `Inc(5)` first, then `Inc(3)`, reaching state 8.
4. **`match Address.call(c, fn(r) = Get(reply = r), 1000) { ... }`** — Synchronous request. `Address.call` allocates a fresh `Reply(Int)`, wraps it in a `Get` via the lambda, sends, waits up to 1000 ms. Returns `Optional(Int)` — `Some(n)` on reply, `None` on timeout.
5. The `match` prints the result or a timeout message.

Expected output: `count is 8`.

### 2.4 Two things the compiler quietly enforces

- **Reply linearity.** In the `Get` arm, `r : Reply(Int)` is a one-shot capability. The type checker requires `r` to be consumed exactly once on every path of the arm — via `answer`, or by being sent as a field of another message, or by being captured in a lambda passed to `spawn`. Miss the `answer` and it's a compile error.
- **Address typing.** `c : Address(CounterMsg)`. You can only `send` values of type `CounterMsg` to `c`. Wrong type is a compile error at the send site.

## 3. Reading ping-pong

Two processes talking to each other.

```
type PongMsg = Ping(n : Int, reply : Reply(Int)) | Stop

fn pong(out : Address(Line)) -> () with PongMsg = recv {
    Ping(n = n, reply = r) -> {
        send(out, Line("pong " ++ Int.toText(n)));
        answer(r, n);
        pong(out)
    }
  | Stop -> ()
}

fn ping(out : Address(Line), pongAddr : Address(PongMsg), n : Int) -> () with m =
    if n == 0 then send(pongAddr, Stop)
    else {
        send(out, Line("ping " ++ Int.toText(n)));
        match Address.call(pongAddr, fn(r) = Ping(n = n, reply = r), 5000) {
            Some(_) -> ping(out, pongAddr, n - 1)
          | None    -> { send(out, Line("pong is not answering")); send(pongAddr, Stop) }
        }
    }

fn main(Sys(stdout = out) : Sys) -> () with () = {
    let pongAddr = spawn(Local, fn() = pong(out));
    let _ = spawn(Local, fn() = ping(out, pongAddr, 3));
    ()
}
```

**What it does:** ping counts down from 3, each iteration sending `Ping(n, reply)` to pong and waiting for the reply. Pong writes to stdout and answers each ping. On ping's counter hitting zero, it sends `Stop` and both processes finish.

**New things it introduces:**

- **Two processes exchanging messages** — pong receives Pings, ping receives replies (via `Address.call`, transparently).
- **Polymorphic mailbox.** `ping`'s signature is `-> () with m` — `m` is lowercase, a type variable. Ping never `recv`s on its own mailbox; it only sends and uses `Address.call`. So its mailbox slot stays free, meaning "ping is callable from any process."
- **Nested match on `Optional`.** The `Address.call` result is `Optional(Int)`; matching on it handles the timeout case with `None`.

## 4. Reading further

Four paper programs live in the repository, progressively more complex:

- **`ernest-tick-game.md`** — a snake game with ticks. Introduces named-field records with `..` update, folds over Maps, per-player processes.
- **`ernest-repl.md`** — a REPL with lexer, parser, and evaluator. Introduces `<-` for chaining `Either`, `try` as a process for evaluation with timeout, `monitor` for detecting child death.
- **`ernest-filesync.md`** — file sync between two nodes. Introduces mutual-address setup via `Link`, `Sys` as values-not-globals, one-process-per-write pattern, spawn-capture of `Reply`.
- **`ernest-webserver.md`** — HTTP server with sessions in an ETS table. Introduces `foreign fn`, opaque types with signatures, session state via a foreign runtime type.

Read them in order — each introduces something the next builds on.

## 5. Where to look for specifics

- **`ernest.md`** — the language report. Normative. Read Section 6 for processes, Section 5 for expressions, Section 3 for types, Section 9 for the prelude.
- **`ernest-decisions.md`** — why the language is the way it is. Dated sections record specific design decisions and their motivating evidence.
- **`ernest-implementation-plan.md`** — how the compiler is being built (Erlang, about eight weeks for MVP 1).

## 6. The seven principles, briefly

If a design choice looks strange, trace it back to one of these:

1. **Least surprise decides, measured in code, not in the rule.**
2. **No variants, unless what remains surprises more.**
3. **Nothing invisible: control flow, communication, and failure are visible in the code or in the type.**
4. **Orthogonal: concepts do not affect one another.**
5. **Simple to parse: the grammar is LL(1), every construct decided by its first token, one role per bracket.**
6. **Few reserved words, but not too few.**
7. **Small: concepts are counted, not primitives.**

The seven are listed in the report's Section 0. Almost every "small" decision in Ernest is one or two of these applied to a specific case.

## 7. Common questions

**Why does `main`'s return look like `-> () with ()`?**
Return type is unit, mailbox type is unit. Two `()` next to each other is not a stutter — the first is the return, the second is the mailbox. Every process function has a `with M` annotation; `main`'s `M` is `()` because nothing ever sends messages of interest to `main`.

**Why does `fn(x) = x + 1` need parens around `(x)`?**
Ernest is n-ary, no currying. `fn` needs to know how many arguments; parens are how you say. `fn(x, y) = x + y` is a two-argument function; `fn(x) = fn(y) = x + y` is a function returning a function — different type. This makes arity visible in every function type.

**Why is there no `import`?**
Every top-level declaration's *qualified name* is its full path — `Net.Http.parse` is defined in `Net/Http.ern`. Files carry their namespace by path. Unqualified names are file-local. Qualified names are program-wide. No `import`, no `pub`, no export list — visibility is in the name.

**Why can `let Right(x) = e` be a type error?**
`Right(x)` is a *refutable* pattern — it might fail if `e` is `Left(...)`. Function parameters and `let` require *irrefutable* patterns (patterns that always match). Refutable destructuring goes in `match`, `recv`, or `<-`, which have defined behavior on failure. This makes failure visible in the code (principle 3).

**Why is the mailbox in the function type?**
So a reader knows, at a glance, whether a function acts through its process. A function without `with M` in its type is *pure* — its result depends only on its arguments, no `send`/`recv`/`self`, no foreign impure call. This is Ernest's answer to the "colored functions" problem: colors are on the arrow, not on the syntax.

## 8. Not covered here

This guide is a first pass. It doesn't cover:

- Distributed programming (`spawn(Peer(...), f)`, `remote(f)`).
- Foreign functions and types (`foreign fn`, `foreign type`).
- Opaque types with signatures.
- Code replacement (`Upgrade` in the counter).
- The full prelude.

Those live in the report and the more complex paper programs. Once the counter and ping-pong read naturally, the rest is small extensions.
