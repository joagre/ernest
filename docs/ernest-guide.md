# Ernest: A Reading Guide

A crash course for a programmer who wants to read Ernest and predict what a fragment does. It is not the language report — [`ernest.md`](ernest.md) is where the rules live. This guide surveys the central mechanisms with runnable checkpoints; where a rule has subtlety, it points into the report.

## 0. Orientation

Ernest is a functional language for concurrent programs. Two organizing ideas run through it:

- **Functions** with Hindley-Milner types the compiler figures out for you.
- **Processes** with typed mailboxes, as the language's way to affect the world.

Everything else is a rule for how functions and processes appear in each other's code.

The guide is arranged as seven checkpoints. Each checkpoint has a complete example, the tools it needs, and a short prediction exercise at the end. Read them in order; each builds on what came before.

## 1. Run a program

Here is a complete Ernest program, `hello.ern`:

```
fn main() -> Void with Never = Io.println("hello, world")
```

Compile and run:

```
$ ernc hello.ern         # produces hello.erc
$ ern hello.erc          # runs main()
hello, world
```

`ernc` compiles one `.ern` file to a `.erc` compiled module. `ern` loads a compiled module, starts the runtime, binds addresses to the `Sys.*` top-level references (report §8.2), and calls `main()`. The standard library is on the load path by default; `-pa dir` adds more directories.

`ernest.conf` and a node's private key live in `./.ernest/` by default. `ern --create-config-dir dir` generates a fresh pair; peers and remote computation are configured there. You don't need it for local programs.

### 1.1 What the line says

`fn` starts a function definition. `main` is special — it is the function the runtime calls when the program starts.

`-> Void` is the return type. `Void` is a type with one value, also called `Void`; it means "no interesting result." `main` in this program does its work, then returns `Void`.

`with Never` is the mailbox effect. Every process has a mailbox with a fixed message type; `Never` is the type with no values — a mailbox typed `Never` cannot receive anything. `main` here only sends (through `Io.println`), so `Never` fits.

`Io.println` is a stdlib function that sends its argument to a small `Sys.stdout` process the runtime provides. The stdout process receives the text and writes it. Messaging to a runtime service is one of two ways Ernest interacts with the outside world (the other is `foreign fn`, §7).

### 1.2 Prediction exercise

Does `ern hello.erc` fault if `Sys.stdout` is missing?

Answer: no — the runtime always provides `Sys.stdout` (report §8.2). A `foreign fn` referencing a `Sys.*` name that the runtime does not provide is a name-resolution error at compile time, not a runtime fault.

## 2. Compute with immutable values

Everything in Ernest is immutable. Bindings introduce names; there is no assignment.

### 2.1 Scalars, Void, and literals

- **`Int`** — arbitrary precision. Literal: `42`.
- **`Float`** — IEEE 754 binary64, finite range only. Literal: `3.14`.
- **`Char`** — one Unicode code point. Literal: `'a'`.
- **`String`** — a Unicode string. Literal: `"hello"`.
- **`Bytes`** — sequence of octets. Literal: `<<0, 1, 2>>`.
- **`Bool`** — `true` or `false`.
- **`Void`** — one value, also called `Void`.

`Float` arithmetic that would produce a non-finite result (overflow, division by zero of a non-zero numerator, `0.0 / 0.0`) *faults*. `Int` division `/` or modulo `%` by zero also faults. `Int.div` and `Int.mod` are the total alternatives that return `Optional(Int)`.

### 2.2 Bindings and blocks

```
let x = 5;
let y = x + 1        // y is 6
```

A block groups statements between `{` and `}`, separated by `;`. Its value is the last statement, which must be an expression:

```
let area = {
    let side = 5;
    side * side
}                    // area is 25
```

Shadowing is allowed: a later `let` with the same name hides the earlier one from the next statement on. The original value is unchanged where it was already used; there is no mutation.

### 2.3 Sum types and pattern matching

Declare a type with named cases:

```
type Direction = North | South | East | West
```

Four *constructors*. Pick between them with `match`:

```
fn opposite(d : Direction) -> Direction = match d {
    North -> South
  | South -> North
  | East -> West
  | West -> East
}
```

The compiler checks that clauses cover every case; a missing case is a type error.

Constructors can carry data. `Optional(a)` is the standard example:

```
type Optional(a) = None | Some(a)
```

`Optional(a)` takes a type parameter `a`. `None` carries nothing; `Some(a)` carries one value of type `a`. So `Some(5) : Optional(Int)` and `None : Optional(a)` for any `a`.

**A constructor with one positional field is a function value.** `Some` on its own has type `(a) -> Optional(a)`; you can pass it as an argument (`List.map(xs, Some)` produces `List(Optional(a))`). Constructors with named fields, and nullary constructors, are not function values — they only appear at their construction sites.

`Reply(a)`, which you'll meet in §4, is a built-in one-shot address with its own ownership rules — it is *not* a wrapper type like a user-defined `type UserId = UserId(Int)`, despite the similar shape.

### 2.4 Named fields and `..` update

For constructors that carry several things, name each field:

```
type Person = Person(name : String, age : Int)

let alice = Person(name = "Alice", age = 30);
let older = Person(..alice, age = 31)          // "Alice", 31
```

`..alice` copies unlisted fields; `age = 31` overrides. `alice` is unchanged — the block just names a second `Person` value. Ernest uses `:` for types (`name : String`) and `=` for values (`name = "Alice"`); function result types use `->`.

Field declaration order carries no meaning (report §3.5). The compiler stores fields in canonical order (sorted by name) internally, and evaluates field expressions in source order.

### 2.5 Lists, tuples, maps, sets

**Lists** with `List(a)`, `[]` empty, `::` right-associative cons:

```
let xs = 1 :: [2, 3];               // [1, 2, 3]
match xs {
    [] -> "empty"
  | head :: rest -> "first is " <> Int.toString(head)
}
```

**Tuples** with `#(...)` prefix — fixed size, positional:

```
let point = #(3, 4);                 // #(Int, Int)
let #(x, y) = point                  // x = 3, y = 4
```

**Maps and sets** — no literal syntax; build with functions:

```
let m = Map.empty |> Map.put("a", 1) |> Map.put("b", 2);
let n = Map.get(m, "a");             // Some(1)
let s = Set.fromList([1, 2, 3])
```

Map keys and set elements require equality — the type parameter cannot be instantiated to a function or address type (report §3.10). `Map(Address(m), v)` is a type error at instantiation.

### 2.6 Patterns and irrefutability

The same patterns appear in `match` clauses, `let` bindings, and function parameters. Bindings and parameters need *irrefutable* patterns — patterns that always match:

- `_` and identifiers are irrefutable.
- A tuple pattern is irrefutable iff every component pattern is.
- A single-constructor type's constructor pattern is irrefutable iff every field pattern is.

```
let #(x, y) = point;                              // irrefutable
let #(Some(x), y) = pair                          // type error: Some can fail
let Rectangle(width = w, height = h) = rect       // irrefutable if Rectangle is the only constructor
```

Identifiers in patterns *introduce fresh bindings* — they do not compare with existing variables. To compare, use a guard:

```
match m {
    n when n == x -> "same as x"
  | _ -> "different"
}
```

Each variable appears at most once in a pattern. Repeated names within one pattern are a type error.

Guards are pure `Bool` expressions — no mailbox effect. A guard that evaluates to `false` falls through to the next clause; a guard that *faults* faults the enclosing process.

### 2.7 `if` and `<-`

`if cond then a else b` is an expression. Both branches must have the same type. There is no `if` without `else`.

`<-` short-circuits on `Optional` or `Either`:

```
fn parseAndAdd(a : String, b : String) -> Optional(Int) = {
    let x <- String.toInt(a);
    let y <- String.toInt(b);
    Some(x + y)
}
```

If the right-hand side is `None`, the whole block evaluates to `None`; the rest of the block is skipped. Same for `Either`: `Left(e)` short-circuits; `Right(v)` binds and continues.

The compiler picks Optional or Either from the right-hand side. One block cannot mix — a block is either an Optional chain or an Either chain, not both.

### 2.8 The pipe operator `|>`

Ernest's stdlib is subject-first. `|>` reads left-to-right:

```
input |> String.trim |> String.toLower |> String.chars
```

`x |> f` is `f(x)`. `x |> f(a, b)` is `f(x, a, b)` — pipe inserts as the first argument. `x |> f(a)(b)` is `f(a)(x, b)`, inserted into the *outermost* call.

**A lambda after `|>` must be parenthesized:** `x |> (fn(y) = y + 1)`. Without parens, the lambda's body extends greedily and swallows the rest of the expression.

### 2.9 Prediction exercise

Given:

```
let p = Person(name = "Alice", age = 30);
let q = Person(..p, age = 31)
```

Does `p` change?

Answer: no. Ernest has no assignment. `q` is a separate `Person` value; `p` is still `Person(name = "Alice", age = 30)`.

## 3. Pass behavior

Functions are values. This section is about writing them and passing them around.

### 3.1 Definitions and arity

```
fn double(n : Int) -> Int = n * 2
fn hypotenuseSquared(a : Int, b : Int) -> Int = a * a + b * b
```

Function arity is fixed and part of the type. `hypotenuseSquared(3, 4)` is `25`. `hypotenuseSquared(3)` is a type error, not a partially applied function. To make a unary version, write a lambda: `fn(b) = hypotenuseSquared(3, b)`.

### 3.2 Lambdas and closures

```
let add1 = fn(x) = x + 1;
add1(5)                    // 6

let n = 10;
let addN = fn(x) = x + n   // closure captures n
```

Lambda body is the longest expression up to the enclosing form's separator (`,`, `;`, `|`, `)`, `}`, `]`, `>>`).

### 3.3 Type inference and its limits

Ernest infers types Hindley-Milner style. You can omit annotations on parameters and returns:

```
fn double(n) = n * 2       // inferred (Int) -> Int
```

`*` on `Int` fixes `n : Int`. But **Ernest does not infer a "numeric type" or default to `Int`**:

```
fn twice(n) = n + n        // n's type ambiguous — annotate: (n : Int) or (n : Float)
```

Without a source that fixes the type, `n + n` is a type error.

Other limits worth knowing:

- `fn` definitions and top-level `let` values generalize over free type variables. Block `let` bindings are monomorphic — a block `let xs = []` types `xs : List(a)` with `a` to be resolved by later use in the block, or by escape through the block's return.
- Local `fn` names inside a block are visible throughout the block, but you cannot *use* one — call it, obtain it as a value, pass it, store it — before the `let` bindings it references have been evaluated. The check follows references between local functions, so an early `invoke(read)` that eventually needs a later `let` is rejected at the point where `read` is obtained.

### 3.4 Pure functions and functions with a mailbox effect

A function type without `with M` is *pure*: it cannot perform process operations — no `send`, no `receive`, no `spawn`, no `Address.call`, no effectful `foreign fn`. A function with `with M` may act through a process whose mailbox type is `M`.

Both kinds of function can fault or fail to terminate. `a / b` with `b = 0` faults despite the type being `(Int, Int) -> Int`. `todo("...")` compiles at any type and faults if reached. Ernest has no local exception handler: expected failures are values (`Optional`, `Either`) or protocol messages; a fault terminates the process and is observed by other processes through monitoring (§5).

The mailbox effect is *not* a purity-vs-effect flag decoupled from sending and receiving: it says the function acts through a process, distinguishing pure computation from process-mediated behavior. It does not itself label a call as fallible.

### 3.5 Higher-order and effect polymorphism

```
fn apply(f, x) = f(x)
```

Inferred type: `((a) -> b with e, a) -> b with e`. The callback's mailbox effect `e` flows through — if `f` is pure, so is `apply(f, x)`; if `f` has effect `M`, `apply(f, x)` has effect `M`. `List.map`, `List.foreach`, and the other combinators in Appendix E work the same way.

An effect variable that appears *only* in effect position (like `e` above) may bind to a mailbox type or to *empty* (pure). An effect variable that also appears in a value position (like `m` in `self : () -> Address(m) with m`) can only bind to a real mailbox type — `Address(empty)` is not a well-formed type.

Prelude primitives that require a process context — `send`, `receive`, `spawn`, `Address.call`, `answer`, `monitor`, `kill`, `remote`, `parallelRemote` — additionally require *their* outer effect variable to be non-empty; pure code cannot invoke them.

`ping`'s `m` in §5 is polymorphic but non-empty: any real mailbox is admissible, but the empty effect is not.

### 3.6 One spawn corner: pure callbacks

`spawn`'s callback has type `() -> Void with n` where `n` also appears in the returned `Address(n)`. A pure callback (no `with`) cannot be spawned — the callback's mailbox must be a real type. To spawn a process that never receives, annotate:

```
spawn(Local, fn() -> Void with Never = Void)
```

### 3.7 Prediction exercise

Given:

```
fn map2(f, x, y) = #(f(x), f(y))
```

What does the compiler infer for `map2` when called as `map2(fn(n) = send(addr, n), 1, 2)`?

Answer: `map2`'s inferred type is `((a) -> b with e, a, a) -> #(b, b) with e`. The call binds `a = Int`, `b = Void`, and `e` to the mailbox effect of `send` — the same as the enclosing function's.

## 4. Run a protocol

A process holds state, receives messages, and answers requests. This section builds a counter.

### 4.1 Message type and receive loop

```
type CounterMsg
    = Inc(Int)
    | Get(reply : Reply(Int))

fn counter(n : Int) -> Void with CounterMsg = receive {
    Inc(k) -> counter(n + k)
  | Get(reply = r) -> { answer(r, n); counter(n) }
}
```

`counter` takes its state as the parameter `n`. Its mailbox type is `CounterMsg`. `receive` waits for a matching message and evaluates the clause's expression. Both clauses tail-call `counter` with the new state; Ernest guarantees tail-call optimization.

`Reply(a)` is a built-in one-shot address: someone hands it over with a request; the receiver puts one value in it, exactly once. Unlike `Address(a)`, a `Reply(a)` cannot be stored.

### 4.2 Reply ownership

The compiler enforces: **a `Reply(a)` bound in a `receive` clause must be consumed exactly once on every path.** The rule generalizes to *reply-carrying types* — any type that transitively contains a `Reply`. `CounterMsg` above is reply-carrying because `Get` has a `Reply` field.

Six ways to consume:

1. `answer(r, v)` — the only primitive that finally discharges the reply.
2. Passing to a function whose parameter type is reply-carrying (delegates the obligation).
3. Sending with `send(a, v)` (shifts to the recipient's `receive` clause).
4. Placing into a constructor or tuple of reply-carrying type — the constructed value inherits the obligation.
5. Returning from a function whose declared return type is reply-carrying — shifts to the caller.
6. Capturing in a lambda passed directly to `spawn`.

Form 4+5 together justify `Address.call`'s builder callback (§4.4): `fn(r) = Get(reply = r)` places `r` in `Get`, and the returned reply-carrying `CounterMsg` transfers the obligation to `Address.call`, whose runtime finally discharges it.

Pattern-matching a reply-carrying scrutinee transfers the obligation to the pattern-bound reply-carrying fields; matching a nullary case (like `Stop` in `PongMsg`, §5) discharges the aggregate obligation with no new binding.

A wildcard or omitted reply field, and an `as` alias on a reply-carrying scrutinee, are type errors. Reply-carrying values may not appear as elements of `List`, `Map`, `Set`, `Optional`, or `Either`, or as operands of equality.

A generic helper that duplicates or discards its parameter (`fn dup(x) = #(x, x)`, `fn discard(x) = Void`) infers a *not-reply-carrying* restriction — the parameter cannot be instantiated to a reply-carrying type. `fn identity(x) = x` passes through without duplication and carries no such restriction.

An intentional error:

```
fn twice(dst : Address(CounterMsg), msg : CounterMsg) -> Void with m = {
    send(dst, msg);
    send(dst, msg)      // rejected: msg is reply-carrying, already consumed
}
```

### 4.3 Selective receive and `after`

`receive` scans the mailbox for a *matching* message; unmatched messages stay in the mailbox for later. Coverage of the mailbox type is not required (unlike `match`).

```
type Inbox = Data(Int) | Wake

fn waitForData() -> Optional(Int) with Inbox = receive {
    Data(n) -> Some(n)
  | after 1000 -> None
}
```

`after N` gives a millisecond timeout that fires if no clause matches within that window. `after 0` scans without waiting for new messages. Without `after`, the process waits indefinitely.

If a `Wake` is already in the mailbox, `waitForData` skips it — leaves it queued — and waits for a `Data`. Some later `receive` can handle `Wake`.

### 4.4 `Address.call`

Synchronous request-reply, used from the caller side:

```
match Address.call(c, fn(r) = Get(reply = r), 1000) {
    Some(n) -> Io.println("count is " <> Int.toString(n))
  | None -> Io.println("counter did not answer")
}
```

`Address.call` allocates a fresh `Reply(a)`, passes it to the builder lambda, sends the resulting message to `c`, and waits up to 1000 ms for the reply. It returns `Some(v)` on success, `None` on timeout.

Four rules:

1. **The deadline starts at invocation.** Build time and send time count against it.
2. **`None` does not cancel the recipient's work.** The recipient may still be computing; retrying a state-changing request can repeat its effect.
3. **Late answers are silently discarded.** They never enter the caller's ordinary mailbox. A reply arriving exactly at the deadline may be delivered or discarded — no deterministic tiebreak.
4. **The reply mechanism is private.** `Address.call` works in a process whose declared mailbox is `Never` or any other type; the fresh Reply identifier is separate from the declared mailbox, and reply values never appear there.

For no-timeout callers, `Address.callForever(addr, mk)` waits as long as needed and returns `a` directly (not `Optional(a)`). If the recipient never answers, the caller hangs; that is the point of the name.

### 4.5 Running the counter

```
fn main() -> Void with m = {
    let c = spawn(Local, fn() = counter(0));
    send(c, Inc(5));
    send(c, Inc(3));
    match Address.call(c, fn(r) = Get(reply = r), 1000) {
        Some(n) -> Io.println("count is " <> Int.toString(n))
      | None -> Io.println("counter did not answer")
    }
}
```

`spawn(Local, fn() = counter(0))` starts a new process on the current node, running the lambda; the returned `Address(CounterMsg)` is bound to `c`. `Local` versus `Peer("name")` selects where the process runs; peers are in §7.

After the two `send`s and the answered call, `main` returns and the program ends. When `main` returns, the runtime kills every *local* process with cause `ProgramEnd`, flushes pending output from system processes, and stops. Workers spawned on peer nodes are unaffected — they run under their peer's runtime.

The output here is deterministic: with initial state 0, the counter processes `Inc(5)` and `Inc(3)` in order (per-sender FIFO), so the `Get` call returns 8, and `main` prints `count is 8`.

### 4.6 Explicit code replacement

Ernest processes can update their code without restart. The mechanism is a protocol message the type carries explicitly — no automatic redeployment.

Extend the counter declared in §4.1 with an `Upgrade` constructor (this replaces both the type and the function above):

```
type CounterMsg
    = Inc(Int)
    | Get(reply : Reply(Int))
    | Upgrade(migrate : (Int) -> Int, next : (Int) -> Void with CounterMsg)

fn counter(n : Int) -> Void with CounterMsg = receive {
    Inc(k) -> counter(n + k)
  | Get(reply = r) -> { answer(r, n); counter(n) }
  | Upgrade(migrate = m, next = k) -> k(m(n))
}
```

`Upgrade` carries two functions: `migrate` transforms the current state; `next` is the new loop. `k(m(n))` is a tail call into the new loop with the migrated state. The process and its address continue; only the code changes. A sender that wants to replace the counter's code sends `Upgrade(migrate = ..., next = newCounter)`.

### 4.7 Prediction exercise

Does `Address.call(c, ..., 1000)` returning `None` guarantee the recipient did no work?

Answer: no. The timeout only bounds the caller's wait. The recipient may still be processing the request or may answer later; the late answer is silently discarded but the work done on the recipient side is not undone.

## 5. Manage process lifetime

The counter is enough for one process. Two processes need coordination.

### 5.1 Ping-pong

```
type PongMsg = Ping(n : Int, reply : Reply(Int)) | Stop
type MainMsg = PongDone(Down)

fn main() -> Void with MainMsg = {
    let pongAddr = spawn(Local, fn() = pong());
    let _ = spawn(Local, fn() = ping(pongAddr, 3));
    monitor(pongAddr, PongDone);
    receive { PongDone(_) -> Void }
}

fn ping(pongAddr : Address(PongMsg), n : Int) -> Void with m =
    if n == 0 then send(pongAddr, Stop)
    else {
        Io.println("ping " <> Int.toString(n));
        match Address.call(pongAddr, fn(r) = Ping(n = n, reply = r), 5000) {
            Some(_) -> ping(pongAddr, n - 1)
          | None -> { Io.println("pong is not answering"); send(pongAddr, Stop) }
        }
    }

fn pong() -> Void with PongMsg = receive {
    Ping(n = n, reply = r) -> {
        Io.println("pong " <> Int.toString(n));
        answer(r, n);
        pong()
    }
  | Stop -> Void
}
```

`ping`'s mailbox `m` is polymorphic — ping never `receive`s. It is polymorphic but non-empty: `ping` uses `Address.call`, which requires a real mailbox effect. Any concrete `m` works; the empty effect does not.

The `main` process monitors `pongAddr` and waits for its death — if `main` returned right after the two spawns, the runtime would kill ping and pong before either sends its first message. Monitor is the reliable "wait for the work to finish" pattern.

One possible successful trace of the stdout is: `ping 3`, `pong 3`, `ping 2`, `pong 2`, `ping 1`, `pong 1`. The runtime's FIFO guarantee applies per-sender (ping's messages arrive at pong in send order, and pong's answers arrive at ping in send order), but the two processes' `Io.println` calls come from different senders to `Sys.stdout`, so their interleaving is scheduling-dependent. The alternating trace is one such interleaving.

### 5.2 `monitor` and `Down`

```
monitor : (Address(a), (Down) -> m) -> Void with m

type Down = Down(reason : Reason, function : String)
type Reason = Returned | Killed | ProgramEnd | Fault(String)
```

`monitor(child, wrap)` asks the runtime to place `wrap(d)` in *your* mailbox when `child` dies. `wrap` adapts the runtime's `Down` into your mailbox type — in ping-pong, `PongDone` is a constructor of `MainMsg` that carries a `Down`. `PongDone(_)` accepts any death reason; it signals *termination*, not *success* — a faulting pong would still deliver `PongDone(Down(reason = Fault(_), ...))`.

A fault in one process does not affect another (no automatic supervision), except that a fault in `main` ends the program and terminates its local processes with `ProgramEnd`.

### 5.3 `kill`

```
kill : (Address(a)) -> Void with m
```

`kill(addr)` requests termination of the process at `addr`; anyone monitoring receives `Down(reason = Killed, ...)`. It is a scheduling event, not an instantaneous halt — the target may run briefly before the runtime interrupts it. The REPL paper program combines `monitor` and `kill` into a supervised-child pattern that gives up after a timeout.

### 5.4 Adapting messages with `via`

Suppose the runtime's clock sends `Void` to a designated address after a delay:

```
type ClockMsg = After(ms : Int, to : Address(Void))
```

Your mailbox holds `GameMsg`, not `Void`. `via` bridges the shapes:

```
via : ((a) -> b, Address(b)) -> Address(a)
```

`via(convert, target)` returns an `Address(a)` that, on receipt of an `a`, applies `convert` and delivers the resulting `b` to `target`. For the clock:

```
send(Sys.clock, After(ms = 100, to = via(fn(_) = Tick, self())))
```

- `self()` is the current process's `Address(GameMsg)`.
- `fn(_) = Tick` is `(Void) -> GameMsg`.
- `via(...)` builds `Address(Void)`.
- The clock, 100 ms later, sends `Void` to the wrapper, which produces `Tick`, which arrives at your mailbox.

`monitor`'s second parameter has the same shape — `via` is the general form.

The clock's `After` fires exactly *once*. For a periodic tick, the receiver re-arms itself:

```
fn game(state : World) -> Void with GameMsg = {
    send(Sys.clock, After(ms = 100, to = via(fn(_) = Tick, self())));
    receive {
        Tick -> game(step(state))
    }
}
```

Each iteration schedules the next tick before waiting.

### 5.5 Prediction exercise

Given the ping-pong program, does the runtime guarantee ping and pong's `Io.println` output appears in strictly alternating order?

Answer: no. Per-sender FIFO orders messages from ping to pong and pong to ping, but the two processes both send to `Sys.stdout` — that is fan-in from two senders, and the runtime does not order across senders. Alternation is a *possible* trace, not a guaranteed one.

## 6. Organize code

An Ernest program is one or more modules. A module is a `.ern` source file; its path *is* its namespace.

### 6.1 Modules and namespaces

Two modules:

```
// Net/Http.ern
type Net.Http.Request = Request(method : String, path : String)
fn Net.Http.parse(s : String) -> Optional(Net.Http.Request) = todo("parser")
```

(`todo("...")` compiles at any type and faults with `Fault("todo: ...")` if reached — a placeholder for an unwritten body.)

```
// main.ern
fn main() -> Void with Never = match Net.Http.parse("GET /") {
    Some(req) -> Io.println("parsed")
  | None -> Io.println("bad request")
}
```

Top-level declarations use their qualified name at every reference — no `import`, no export list, no `pub`. A declaration `A.B.C.name` belongs exclusively to `A/B/C.ern`; `Net.Http.Header.parse` would live in `Net/Http/Header.ern`, not in `Net/Http.ern`.

Unqualified names (`fn helper(x) = ...`) are visible only inside their own module.

### 6.2 Abstract types

Abstract types have a private representation and a public signature. Only definitions named in the signature can mention the constructor:

```
abstract type Stack(a) = Stack(List(a)) with {
    empty : Stack(a);
    push : (a, Stack(a)) -> Stack(a);
    pop : (Stack(a)) -> Optional(#(a, Stack(a)))
}

let Stack.empty : Stack(a) = Stack([])
fn Stack.push(x : a, Stack(xs) : Stack(a)) -> Stack(a) = Stack(x :: xs)
fn Stack.pop(Stack(xs) : Stack(a)) -> Optional(#(a, Stack(a))) =
    match xs { [] -> None | x :: rest -> Some(#(x, Stack(rest))) }
```

`Stack.empty`, `Stack.push`, `Stack.pop` are listed in the `with { ... }` signature, so their bodies may name the `Stack` constructor. Anyone else — including an unlisted helper in the same module — cannot:

```
fn Stack.size(Stack(xs) : Stack(a)) -> Int = List.size(xs)   // rejected: Stack.size is not in the signature
fn Stack.isEmpty(s : Stack(a)) -> Bool = match Stack.pop(s) { // accepted: uses public operations
    None -> true
  | Some(_) -> false
}
```

An abstract type's representation can change later (a tree, a growable array), and callers built against the signature continue to work as long as each operation's observable contract is preserved.

Abstract types are hashed by their qualified name plus their exported signature, not by their private representation. Two nodes that both declare a same-named `Stack` under the same signature interoperate; different signatures produce different types (report §8.7).

### 6.3 Prediction exercise

Can a helper in the same file as `Stack` — but not listed in the `with { ... }` signature — pattern-match `Stack(xs)`?

Answer: no. Access is granted by the signature, not by the module. The helper can call `Stack.pop`, `Stack.push`, and any other listed operation, but it cannot see the constructor.

## 7. Cross boundaries

Two ways Ernest reaches outside a single node's Ernest code: to peers over the network, and to foreign code on the same node.

### 7.1 `remote` and `parallelRemote`

Run a pure computation on some peer:

```
remote         : (() -> a) -> Either(RemoteError, a) with m
parallelRemote : (List(() -> a)) -> List(Either(RemoteError, a)) with m

type RemoteError = NoRemotePeer | PeerLost
```

`remote(f)` hands `f` to the runtime, which picks a peer and runs `f()` there. `f` is pure by `remote`'s design — `remote` is a one-shot compute-and-return, not a process; effectful work on a peer goes through `spawn(Peer(...), ...)`.

Both operations have a mailbox effect: `Left(NoRemotePeer)` when no peer is configured, `Left(PeerLost)` when the peer becomes unreachable *or* when peer-side dependency resolution fails *or* when the callback faults on the peer. `PeerLost` signals that this specific operation did not complete; it does not invalidate other `Address` values held for the same peer (which only die on actual peer-loss detection).

`parallelRemote` preserves input order in the result list. Each callback is pure; the batch call has a mailbox effect. There is no per-job timeout — a nonterminating callback prevents the whole list from returning.

### 7.2 Code shipping

`spawn(Peer(name), f)`, `remote(f)`, and any `send` whose destination is a remote address ship the closure or message payload and the code it depends on. The peer resolves each referenced hash — it uses cached code if present, or fetches from the sender. Types, functions, and constructors are identified across nodes by content hash; two nodes with structurally identical definitions agree on identity.

Some consequences the code sees:

- A `Sys.*` name referenced by shipped code resolves *on the peer that runs the code*. A shipped `Io.println` sends to the peer's `Sys.stdout`.
- A captured address value ships as a value — its target is whichever process it pointed to when the closure was formed, not re-resolved on the peer.
- Top-level bindings referenced by shipped code are initialized on demand on the peer, in the peer's environment. `let output = Sys.stdout` gives the sender's stdout on the sender and the peer's on the peer.
- `send` to a remote address returns immediately; a peer-side resolution failure faults the sender *asynchronously*, after `send` has already returned.
- Foreign definitions must be available and compatible on the peer.

### 7.3 Foreign types and functions

```
foreign type Ets.Table(k, v)

foreign fn Ets.member(t : Ets.Table(k, v), key : k) -> Bool with m = "ets:member/2"
```

`foreign type` declares a type whose values are made and used only by foreign functions — no Ernest-side constructor, no pattern match. `foreign fn` binds a name to an implementation on the other side (here, Erlang's `ets:member/2`).

Ernest treats the foreign boundary as a *promise*: the declared type is what comes back, the mailbox effect is honest, a pure declaration means no effects. The runtime enforces the promise with faults:

- **Wrong return type.** The declared type is Ernest's contract; the runtime faults the *receiving* Ernest process on first observation of a malformed value.
- **Thrown exception.** Erlang exits and throws become `Fault` on the calling process.
- **Wrong message from a foreign process.** A message that doesn't match the *destination's* declared mailbox type faults the receiver on first observation.

Purity itself is not verifiable — declaring `foreign fn` without `with M` is a promise the foreign side cannot enforce mechanically. Reserve pure declarations for functions that genuinely have no effect.

### 7.4 Node-local foreign values

Foreign values are bound to the node that made them. Any cross-node transport of a value that transitively contains one faults with `Fault("foreign value cannot cross nodes")` — including a closure that captures such a value.

```
let t = Ets.new();
spawn(Peer("alice"), fn() = Ets.insert(t, "x", 1))   // fault: t is captured
```

Programs that need to share table-like state across nodes serialize the contents and rebuild on the peer.

### 7.5 The shim pattern

Erlang's `ets:lookup` returns a list because the key might match zero or one entry:

```
fn Ets.lookup(t : Ets.Table(k, v), key : k) -> Optional(v) with m =
    match rawLookup(t, key) { [#(_, v)] -> Some(v) | _ -> None }

foreign fn rawLookup(t : Ets.Table(k, v), key : k)
    -> List(#(k, v)) with m = "ets:lookup/2"
```

The raw binding is unqualified (`rawLookup`), so it is file-local. `Ets.lookup` is the typed API a caller uses.

Erlang's `{ok, V} | {error, R}` convention does not automatically match an Ernest `Either` — Ernest's `Ok(v)` encodes as `{'Ok', v}` (quoted, source-preserving; report §8.4), and Erlang's `{ok, V}` uses the lowercase atom `ok`. A shim that converts must either declare the raw return as `Foreign` and decode with pattern matching, or wrap the Erlang call in a helper module that produces the quoted-atom form.

Report Appendix D walks a full `Ets.ern` reference implementation.

### 7.6 Bitstrings

Building and parsing binary formats:

```
fn frame(len : Int, body : Bytes) -> Bytes =
    <<len:size(16)-big, body:bytes>>

fn parseFrame(bytes : Bytes) -> Optional(#(Int, Bytes, Bytes)) = match bytes {
    <<len:size(16)-big, body:size(len)-bytes, rest:bytes>> -> Some(#(len, body, rest))
  | _ -> None
}
```

Specifiers, joined with `-`:

- **`size(N)`** — width in units.
- **`unit(N)`** — bits per size unit; default 1.
- **`bits`** — segment is a nested `Bytes` value; unit is 1 bit.
- **`bytes`** — segment is a nested byte-aligned `Bytes` value; unit is 8 bits.
- **`int`**, **`float`** — numeric (defaults: 8-bit `int`, 64-bit `float`).
- **`utf8`**, **`utf16`**, **`utf32`** — text encoding.
- **`big`**, **`little`**, **`native`** — endianness.
- **`signed`**, **`unsigned`** — sign.

**Alignment rules:**

- A bitstring produces a `Bytes` value; the total bit count must be a multiple of 8.
- A `bits` or `bytes` segment binding to a `Bytes` value must itself be byte-multiple. Sub-octet fields use the `int` specifier (binding to `Int`).
- Compile-time-constant alignment violations are compile-time errors. Dynamic-size violations fault in construction and fail matching in patterns.

`size(Expr)` in a pattern evaluates in the scope of earlier-bound segment variables plus the enclosing scope. The expression is pure (no mailbox effect); a fault in it faults the process.

**Precondition for `frame`/`parseFrame`:** the round trip works when `len` equals `body`'s byte count. `parseFrame(frame(1, <<65, 66>>))` returns `Some(#(1, <<65>>, <<66>>))` — a one-byte body and a one-byte remainder, not an error. The programmer chooses `len` deliberately.

Bitstrings compile to BEAM's bit syntax so the platform's mature bit-syntax optimizer handles the code.

### 7.7 Prediction exercise

Suppose `send(remoteAddr, msg)` returns immediately, and 50 ms later the peer reports a resolution failure. What happens to the sending process?

Answer: the runtime faults the sending process asynchronously, after `send` has already returned. Code that followed the `send` may have executed; the fault interrupts the process where it currently is, not at the site of `send`.

## 8. Frequently asked questions

**Why is `main`'s mailbox usually `Never`?**

`Never` is the type with no values; a mailbox typed `Never` cannot receive. `main` that only spawns and sends carries `with Never` to say so. If `main` is written with a polymorphic `with m`, the runtime instantiates `m` to `Never`.

**Why can `let Right(x) = e` be a type error?**

`Right(x)` is refutable — it might fail if `e` is `Left(...)`. `let` and function parameters need irrefutable patterns. Use `match` or `<-` for refutable cases.

**Why is there no `import`?**

Every top-level declaration's *qualified name* is where it lives. A declaration `A.B.C.name` is in `A/B/C.ern`; code anywhere refers to it by that full name. Unqualified names are private to their module. No `import`, no `pub`, no export list.

**Why parenthesized lambdas after `|>`?**

A lambda's body is greedy — it extends until the enclosing form's separator. Without parens, `x |> fn(y) = y + 1 |> f` would either eat the second `|>` into the body or split confusingly. Parens make the boundary explicit.

**Why write `fn(x) = ...` for lambdas instead of `x -> ...`?**

Ernest is n-ary: every function has a specific number of arguments recorded in its type. `fn(x)` says "one argument"; `fn(x, y)` says "two." The chosen syntax makes arity visible at the definition site, and the parenthesized form matches ordinary calls.

## 9. Reading further

The four paper programs, in ascending complexity:

- [`ernest-tick-game.md`](ernest-tick-game.md) — snake game with tick-based updates; `..` record updates, one process per player.
- [`ernest-repl.md`](ernest-repl.md) — small read-eval-print loop; `<-` for chained parsing, `monitor` + `kill` for aborting slow evaluation.
- [`ernest-filesync.md`](ernest-filesync.md) — file sync between two nodes; mutual-address setup, one process per write, `Sys.fs`.
- [`ernest-webserver.md`](ernest-webserver.md) — HTTP server with sessions in ETS; `foreign fn`, abstract types, ETS as a foreign process.

The paper programs assume runtime references beyond the required `Sys.stdout` and `Sys.clock` — `Sys.fs`, `Sys.keys`, `Sys.net`, and an ETS backend are program-specific dependencies that each program names in its own assumptions.

For the language rules themselves, [`ernest.md`](ernest.md) is the authority. Appendix F glosses every technical term.

For why Ernest looks the way it does — what was tried and rejected — [`ernest-decisions.md`](ernest-decisions.md) records dated design decisions.
