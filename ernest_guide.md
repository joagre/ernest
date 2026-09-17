# Ernest: A Reading Guide

A crash course for a programmer who wants to read Ernest and predict what a fragment does. It is not the language report — [`ernest_report.md`](ernest_report.md) is where the rules live. This guide surveys the central mechanisms with runnable checkpoints; where a rule has subtlety, it points into the report.

## 0. Orientation

Ernest is a functional language for concurrent programs. Two organizing ideas run through it:

- **Functions** with Hindley-Milner types the compiler figures out for you.
- **Processes** with typed mailboxes, as the language's way to affect the world.

Everything else is a rule for how functions and processes appear in each other's code.

The guide is arranged as seven stages, with a complete runnable program at selected checkpoints (hello, the counter, the module example, the remote example). The complete programs are collected as files under [`examples/`](examples/). Other snippets are illustrative fragments — assembling them into files is left to the reader. Each stage ends with a short prediction exercise. Read the stages in order; each builds on what came before.

## 1. Run a program

For these examples, first create a configuration in a fresh working directory. This step runs once; the command fails if the configuration directory already exists:

```
$ ern --create-config-dir .
```

That generates `./.ernest/` with `ernest.conf` (network address, public key, empty peer list) and the private key. Local examples like the ones below leave the peer list empty; programs that use peers or remote computation edit `ernest.conf` before running.

Now the program itself, `hello.ern`:

```
export fn main() -> Unit with Never = Io.println("hello, world")
```

Compile and run:

```
$ ernc hello.ern         # produces hello.erc
$ ern hello.erc          # runs main()
hello, world
```

`ernc` compiles one `.ern` file to a `.erc` compiled module. `ern` loads a compiled module, starts the runtime, binds addresses to the `Sys.*` top-level references (report §8.2), and calls `main()`. The standard library is on the load path by default; `--load-path dir` adds more directories.

### 1.1 What the line says

`fn` starts a function definition. `main` is the conventional entry-point name — `ern module.erc` looks for `export fn main` in the loaded module and invokes it. The hello-world program declares one; larger projects can select a different exported entry point with `ern --main Qualified.name module.erc` (see §6.1).

`-> Unit` is the return type. `Unit` is a type with one value, also called `Unit`; it means "no interesting result." `main` in this program does its work, then returns `Unit`.

`with Never` is the mailbox effect. Every process has a mailbox with a fixed message type; `Never` is the type with no values — a mailbox typed `Never` cannot receive anything. `main` here only sends (through `Io.println`), so `Never` fits.

`Io.println` is a stdlib function that sends its argument to a small `Sys.stdout` process the runtime provides. The stdout process receives the text and writes it. Messaging to a runtime service is one of two ways Ernest interacts with the outside world (the other is `foreign fn`, §7).

### 1.2 Prediction exercise

Consider two variations on hello-world:

```
export fn main() = Io.println("hello, world")             // (a) no annotation
export fn main() -> Unit = Io.println("hello, world")     // (b) declared pure
```

Which of these compile?

Answer: (a) compiles — inference gives `main` a fresh mailbox effect from `Io.println`'s call. (b) does not compile — the explicit `-> Unit` (without `with M`) declares the function *pure*, and a pure function cannot call `Io.println` (which sends). The `with Never` in the actual hello-world declaration says "this process has a mailbox, but it will never receive." Omitting an annotation is not the same as declaring purity.

## 2. Compute with immutable values

Everything in Ernest is immutable. Bindings introduce names; there is no assignment.

### 2.1 Scalars, Unit, and literals

- **`Int`** — arbitrary precision. Literal: `42`.
- **`Float`** — IEEE 754 binary64, finite range only. Literal: `3.14`.
- **`Char`** — one Unicode code point. Literal: `'a'`.
- **`String`** — a Unicode string. Literal: `"hello"`.
- **`Bytes`** — sequence of octets. Literal: `<<0, 1, 2>>`.
- **`Bool`** — `true` or `false`.
- **`Unit`** — one value, also called `Unit`.

`Float` arithmetic that would produce a non-finite result (overflow, division by zero of a non-zero numerator, `0.0 / 0.0`) *faults*. `Int` division `/` or modulo `%` by zero also faults. `Int.div` and `Int.mod` are the total alternatives that return `Optional(Int)`.

`Int` and `Float` are separate types with no implicit conversion — mixing them in an arithmetic expression is a type error. Cross the boundary explicitly with `Int.toFloat`, `Float.round`, `Float.floor`, or `Float.ceil`; each has a contract in Appendix E of the report (`Int.toFloat` faults on integers outside the finite float range, for instance).

### 2.2 Bindings and blocks

```
let x = 5;
let y = x + 1        // y is 6
```

A block groups statements between `{` and `}`, separated by `;`. Its value is the last statement, which must be an expression — no trailing semicolon. Evaluation is strict and left-to-right: each `;` runs its statement to completion before the next.

```
let area = {
    let side = 5;
    side * side
}                    // area is 25
```

Shadowing is allowed: a later `let` with the same name hides the earlier one from the next statement on. The original value is unchanged where it was already used; there is no mutation.

**Constants.** A `let` declaration at the top level (outside any `fn`) is Ernest's constant form. It is evaluated once at program startup and its value is in scope thereafter. Top-level `let` names are lowercase like any other value binding — no `PI`, no `MAX_CONNECTIONS`; case has one job in Ernest, and uppercase is for types and constructors. Add `export` to make a constant visible from other modules.

```
let pi : Float = 3.14159265358979
let defaultPort : Int = 8080
export let helloBanner : String = "hello, world"
```

Top-level initializers must be pure — no `send`, no `spawn`, no other process effects. Effectful setup belongs in `main`. Initializers run in dependency order before `main` starts: a top-level `let` that references another is evaluated after the one it references. Cycles among top-level `let`s within one module are rejected at compile time; cycles across modules are rejected at load time. A pure initializer can still fault or fail to terminate, in which case `main` never starts — a fault at startup is observed the same way as one during execution (§3.4).

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

Three shapes of constructor, with different usage:

- **Nullary** (`None`, `North`): an ordinary value. Referenced by name.
- **Positional with one field** (`Some(a)`): also a function value of type `(a) -> Optional(a)`. You can pass it: `List.map(xs, Some)` produces `List(Optional(a))`.
- **Named fields** (`Person(name : String, age : Int)`): construction uses the field syntax (`Person(name = "Alice", age = 30)`). Not a function value.

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

Map keys and set elements require equality. Ernest's `==` is defined for every type *except* those containing functions or addresses (report §3.10) — that includes tuples, sums, and constructor fields that transitively contain either. `Map(Address(m), v)` is a type error at instantiation; so is `xs == ys` when `xs` is `List(Address(m))` or any type containing one.

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

A postfix `as ident` binds the whole match alongside its destructured parts: `Some(x) as present` binds `x` to the payload *and* `present` to the whole Optional. Useful when both the interior and the aggregate matter. `as` is not allowed on reply-carrying scrutinees (§4.2).

Guards are pure `Bool` expressions — no mailbox effect. A guard that evaluates to `false` falls through to the next clause; a guard that *faults* faults the enclosing process. Guards do not count toward `match` exhaustiveness — a clause with a guard still needs an unguarded fallback (a wildcard `_` clause, typically) so the compiler can prove coverage.

### 2.7 `if` and `<-`

`if cond then a else b` is an expression. Both branches must have the same type. There is no `if` without `else`.

`<-` short-circuits on `Optional` or `Either`. The prelude defines them as:

```
// prelude, for reference
type Optional(a) = None | Some(a)
type Either(e, a) = Left(e) | Right(a)
```

An Optional chain:

```
fn parseAndAdd(a : String, b : String) -> Optional(Int) = {
    let x <- String.toInt(a);
    let y <- String.toInt(b);
    Some(x + y)
}
```

If `String.toInt(a)` returns `None`, the whole block evaluates to `None`; the rest is skipped. `parseAndAdd("2", "3")` returns `Some(5)`; `parseAndAdd("2", "oops")` returns `None`.

An Either chain uses `Left(e)` to short-circuit and `Right(v)` to bind and continue:

```
fn positiveInt(text : String) -> Either(String, Int) = {
    let n <- Either.fromOptional(String.toInt(text), "not an integer");
    if n > 0 then Right(n) else Left("not positive")
}
```

- `positiveInt("3")` → `Right(3)`.
- `positiveInt("oops")` → `Left("not an integer")` — `String.toInt` returned `None`, `Either.fromOptional` turned it into `Left`, and the chain short-circuits.
- `positiveInt("0")` → `Left("not positive")` — the parse succeeded but the explicit branch rejects.

The compiler picks Optional or Either from the right-hand side's type. One block cannot mix — a block is either an Optional chain or an Either chain, not both.

### 2.8 The pipe operator `|>`

Ernest's stdlib is subject-first. `|>` reads left-to-right:

```
"abc" |> String.chars |> List.reverse |> String.fromChars      // "cba"
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

A function body is either a single expression (like `n * 2`) or a block; a block's final statement is an expression, without a trailing semicolon. Arguments evaluate strict left-to-right before the call.

Function arity is fixed and part of the type. `hypotenuseSquared(3, 4)` is `25`. `hypotenuseSquared(3)` is a type error, not a partially applied function. To make a unary version, write a lambda: `fn(b) = hypotenuseSquared(3, b)`.

### 3.2 Lambdas and closures

```
let add1 = fn(x) = x + 1;
let six = add1(5);         // 6
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
- Top-level `let` initializers must be pure — no mailbox effect. Effectful setup (spawning processes, sending initial messages) belongs in `main`. The runtime evaluates top-level `let` bindings in dependency order before `main` runs.

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

Process operations that require a process context — the prelude primitives `send`, `spawn`, `Address.call`, `answer`, `monitor`, `kill`, `remote`, `parallelRemote`, and the `receive` expression form (with its optional `after` clause) — require the enclosing function's mailbox effect to be non-empty; pure code cannot use any of them.

`ping`'s `m` in §5 is polymorphic but non-empty: any real mailbox is admissible, but the empty effect is not.

### 3.6 One spawn corner: pure callbacks

`spawn`'s callback has type `() -> Unit with n` where `n` also appears in the returned `Address(n)`. A pure callback (no `with`) cannot be spawned — the callback's mailbox must be a real type. To spawn a process that never receives, annotate:

```
spawn(Local, fn() -> Unit with Never = Unit)
```

### 3.7 Prediction exercise

Given:

```
fn map2(f, x, y) = #(f(x), f(y))
```

What does the compiler infer for `map2` when called as `map2(fn(n) = send(addr, n), 1, 2)`?

Answer: `map2`'s inferred type is `((a) -> b with e, a, a) -> #(b, b) with e`. The call binds `a = Int`, `b = Unit`, and `e` to the mailbox effect of `send` — the same as the enclosing function's.

## 4. Run a protocol

A process holds state, receives messages, and answers requests. This section builds a counter.

### 4.1 Message type and receive loop

```
type CounterMsg
    = Inc(Int)
    | Get(reply : Reply(Int))

fn counter(n : Int) -> Unit with CounterMsg = receive {
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

Form 4+5 together justify `Address.call`'s builder callback (§4.4): `fn(r) = Get(reply = r)` places `r` in `Get`, and returning the reply-carrying `CounterMsg` transfers the ownership obligation to `Address.call`. `Address.call` in turn consumes the message by sending it to the recipient, transferring the obligation to whichever `receive` clause on the recipient's side eventually binds it. Only `answer(r, v)` finally discharges the underlying `Reply`.

The ownership check is static: it verifies that every syntactically reachable path calls `answer` (or delegates, or shifts). It does not guarantee that execution *reaches* that call at runtime — a path that faults, loops, or waits forever bypasses the answer without invalidating the type check. That is why `Address.call` requires a mandatory timeout (§4.4): the caller must plan for the case where the answer never comes.

Pattern-matching a reply-carrying scrutinee transfers the obligation to the pattern-bound reply-carrying fields; matching a nullary case (like `Stop` in `PongMsg`, §5) discharges the aggregate obligation with no new binding.

A wildcard or omitted reply field, and an `as` alias on a reply-carrying scrutinee, are type errors. Reply-carrying values may not appear as elements of `List`, `Map`, `Set`, `Optional`, or `Either`, or as operands of equality.

A generic helper that duplicates or discards its parameter (`fn dup(x) = #(x, x)`, `fn discard(x) = Unit`) infers a *not-reply-carrying* restriction — the parameter cannot be instantiated to a reply-carrying type. `fn identity(x) = x` passes through without duplication and carries no such restriction.

An intentional error:

```
fn twice(dst : Address(CounterMsg), msg : CounterMsg) -> Unit with m = {
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

Save the `CounterMsg` type and the `counter` loop from §4.1 together with the following `main` in a single file `counter.ern`. Compile with `ernc counter.ern` and run with `ern counter.erc`.

```
export fn main() -> Unit with m = {
    let c = spawn(Local, fn() = counter(0));
    send(c, Inc(5));
    send(c, Inc(3));
    match Address.call(c, fn(r) = Get(reply = r), 1000) {
        Some(n) -> Io.println("count is " <> Int.toString(n))
      | None -> Io.println("counter did not answer")
    }
}
```

`spawn(Local, fn() = counter(0))` starts a new process on the current node, running the lambda; the returned `Address(CounterMsg)` is bound to `c`. `Local` versus `Peer("name")` selects where the process runs; peers are in §7. Inside the spawned lambda, `self()` returns the *child's* address, not the parent's — a parent that wants to hand its own address to the child must capture `self()` before spawning: `let me = self(); spawn(Local, fn() = child(me))`.

After the two `send`s and the answered call, `main` returns and the program ends. When `main` returns, the runtime kills every *local* process with cause `ProgramEnd`, flushes pending output from system processes, and stops. Workers spawned on peer nodes are unaffected — they run under their peer's runtime.

If the call succeeds, it returns 8: the same sender's two `Inc` messages arrive in order (per-sender FIFO), then `Get` returns the accumulated state, and `main` prints `count is 8`. If the 1000 ms deadline expires before the reply, `main` prints `counter did not answer` — the timeout branch is not dead code.

### 4.6 Explicit code replacement

Ernest processes can update their code without restart. The mechanism is a protocol message the type carries explicitly — no automatic redeployment.

Extend the counter declared in §4.1 with an `Upgrade` constructor (this replaces both the type and the function above):

```
type CounterMsg
    = Inc(Int)
    | Get(reply : Reply(Int))
    | Upgrade(migrate : (Int) -> Int, next : (Int) -> Unit with CounterMsg)

fn counter(n : Int) -> Unit with CounterMsg = receive {
    Inc(k) -> counter(n + k)
  | Get(reply = r) -> { answer(r, n); counter(n) }
  | Upgrade(migrate = m, next = k) -> k(m(n))
}
```

`Upgrade` carries two functions: `migrate` transforms the current state; `next` is the new loop. `k(m(n))` is a tail call into the new loop with the migrated state. The process and its address continue; only the code changes.

A replacement loop that doubles each increment:

```
fn doublingCounter(n : Int) -> Unit with CounterMsg = receive {
    Inc(k) -> doublingCounter(n + 2 * k)
  | Get(reply = r) -> { answer(r, n); doublingCounter(n) }
  | Upgrade(migrate = m, next = k) -> k(m(n))
}
```

And a `main` that upgrades after the first `Get`. This `main` replaces the one from §4.5, just as the `CounterMsg` and `counter` above replace the ones from §4.1. Put the whole file together, recompile, and rerun.

```
export fn main() -> Unit with m = {
    let c = spawn(Local, fn() = counter(0));
    send(c, Inc(5));
    send(c, Inc(3));
    match Address.call(c, fn(r) = Get(reply = r), 1000) {
        Some(n) -> Io.println("before upgrade: " <> Int.toString(n))    // 8
      | None -> Io.println("timeout")
    };
    send(c, Upgrade(migrate = fn(n) = n, next = doublingCounter));
    send(c, Inc(1));
    match Address.call(c, fn(r) = Get(reply = r), 1000) {
        Some(n) -> Io.println("after upgrade: " <> Int.toString(n))     // 10
      | None -> Io.println("timeout")
    }
}
```

The address `c` is unchanged; the process behind it is now running `doublingCounter`. After the state 8, `Inc(1)` in the doubling loop adds 2, yielding 10.

### 4.7 Prediction exercise

Does `Address.call(c, ..., 1000)` returning `None` guarantee the recipient did no work?

Answer: no. The timeout only bounds the caller's wait. The recipient may still be processing the request or may answer later; the late answer is silently discarded but the work done on the recipient side is not undone.

## 5. Manage process lifetime

The counter is enough for one process. Two processes need coordination.

### 5.1 Ping-pong

```
type PongMsg = Ping(n : Int, reply : Reply(Int)) | Stop
type MainMsg = PongDone(Down)

export fn main() -> Unit with MainMsg = {
    let pongAddr = spawn(Local, fn() = pong());
    let _ = spawn(Local, fn() = ping(pongAddr, 3));
    monitor(pongAddr, PongDone);
    receive { PongDone(_) -> Unit }
}

fn ping(pongAddr : Address(PongMsg), n : Int) -> Unit with m =
    if n == 0 then send(pongAddr, Stop)
    else {
        Io.println("ping " <> Int.toString(n));
        match Address.call(pongAddr, fn(r) = Ping(n = n, reply = r), 5000) {
            Some(_) -> ping(pongAddr, n - 1)
          | None -> { Io.println("pong is not answering"); send(pongAddr, Stop) }
        }
    }

fn pong() -> Unit with PongMsg = receive {
    Ping(n = n, reply = r) -> {
        Io.println("pong " <> Int.toString(n));
        answer(r, n);
        pong()
    }
  | Stop -> Unit
}
```

`ping`'s mailbox `m` is polymorphic — ping never `receive`s. It is polymorphic but non-empty: `ping` uses `Address.call`, which requires a real mailbox effect. Any concrete `m` works; the empty effect does not.

The `main` process monitors `pongAddr` and waits for its termination. Returning from `main` immediately after the two spawns *may* terminate the children before their work finishes — the runtime does not order `main`'s return against the children's first send. Waiting for a monitor notification keeps `main` alive until the monitored process ends, whether it returned normally, faulted, or was killed. `PongDone(_)` accepts every death reason.

One possible successful trace of the stdout is: `ping 3`, `pong 3`, `ping 2`, `pong 2`, `ping 1`, `pong 1`. The runtime's FIFO guarantee applies per-sender (ping's messages arrive at pong in send order, and pong's answers arrive at ping in send order), but the two processes' `Io.println` calls come from different senders to `Sys.stdout`, so their interleaving is scheduling-dependent. The alternating trace is one such interleaving.

### 5.2 `monitor` and `Down`

```
monitor : (Address(a), (Down) -> m) -> Unit with m

type Down = Down(reason : Reason, function : String)
type Reason = Returned | Killed | ProgramEnd | Fault(String)
```

`monitor(child, wrap)` asks the runtime to place `wrap(d)` in *your* mailbox when `child` dies. `wrap` adapts the runtime's `Down` into your mailbox type — in ping-pong, `PongDone` is a constructor of `MainMsg` that carries a `Down`. `PongDone(_)` accepts any death reason; it signals *termination*, not *success* — a faulting pong would still deliver `PongDone(Down(reason = Fault(_), ...))`.

A fault in one process does not affect another (no automatic supervision), except that a fault in `main` ends the program and terminates its local processes with `ProgramEnd`.

### 5.3 `kill`

```
kill : (Address(a)) -> Unit with m
```

`kill(addr)` requests termination of the process at `addr`; anyone monitoring receives `Down(reason = Killed, ...)`. It is a scheduling event, not an instantaneous halt — the target may run briefly before the runtime interrupts it. The REPL paper program combines `monitor` and `kill` into a supervised-child pattern that gives up after a timeout.

### 5.4 `Deadlock` as a safety net

The runtime ends a program with the error `Deadlock` when forward progress is impossible: every live process is waiting in `receive` without `after`, no message is in flight, and no live system process or connected peer holds a subscription, timer, pending I/O, or in-progress computation that could deliver a message. Pending `after`s, network listeners, keyboard subscribers, and running peer computations that owe this node a reply all count as "message in flight" — an idle server waiting on external events is not deadlocked. Detection is per-node; a distributed deadlock across peers may not be detected.

### 5.5 Adapting messages with `via`

Suppose the runtime's clock accepts an `After` request that fires once:

```
// excerpt from the prelude's ClockMsg — the full type has more variants
After(ms : Int, to : Address(Unit))
```

The clock will send `Unit` to `to` after `ms` milliseconds. If your process's mailbox holds `GameMsg`, not `Unit`, `via` bridges the shapes:

```
via : ((a) -> b, Address(b)) -> Address(a)
```

`via(convert, target)` returns an `Address(a)` that, on receipt of an `a`, applies `convert` and delivers the resulting `b` to `target`. For the clock:

```
send(Sys.clock, After(ms = 100, to = via(fn(_) = Tick, self())))
```

- `self()` is the current process's `Address(GameMsg)`.
- `fn(_) = Tick` is `(Unit) -> GameMsg`.
- `via(...)` builds `Address(Unit)`.
- The clock, 100 ms later, sends `Unit` to the wrapper, which produces `Tick`, which arrives at your mailbox.

`monitor`'s second parameter has the same shape — `via` is the general form.

The clock's `After` fires exactly *once*. For a periodic tick, the receiver schedules a new one only after handling the previous. A naive `game` that loops back on every message would create one pending timer per input, so a burst of inputs multiplies the tick rate. Two functions make the boundary explicit:

```
type GameMsg = Tick | Input(Char)
type World = World(score : Int)

fn step(World(score = n) : World) -> World = World(score = n + 1)

fn game(state : World) -> Unit with GameMsg = {
    send(Sys.clock, After(ms = 100, to = via(fn(_) = Tick, self())));
    waitForTick(state)
}

fn waitForTick(state : World) -> Unit with GameMsg = receive {
    Tick -> game(step(state))
  | Input(_) -> waitForTick(state)
}
```

`game` schedules exactly one clock request, then hands off to `waitForTick`. Inputs are handled without touching the pending timer; only a `Tick` returns to `game`, which schedules the next one. `step` destructures the world with a pattern — Ernest does not generate field-accessor functions.

### 5.6 Prediction exercise

Given the ping-pong program, does the runtime guarantee ping and pong's `Io.println` output appears in strictly alternating order?

Answer: no. Per-sender FIFO orders messages from ping to pong and pong to ping, but the two processes both send to `Sys.stdout` — that is fan-in from two senders, and the runtime does not order across senders. Alternation is a *possible* trace, not a guaranteed one.

## 6. Organize code

An Ernest program is one or more modules. A module is a `.ern` source file; its path *is* its namespace.

### 6.1 Modules and namespaces

Two modules:

```
// net/http.ern  (namespace Net.Http)
export type Request = Request(method : String, path : String)

export fn parse(s : String) -> Optional(Request) =
    if s == "GET /" then Some(Request(method = "GET", path = "/"))
    else None
```

```
// main.ern  (namespace Main)
export fn main() -> Unit with Never = match Net.Http.parse("GET /") {
    Some(Net.Http.Request(method = method, path = path)) ->
        Io.println(method <> " " <> path)
  | None -> Io.println("bad request")
}
```

The `Net.Http.Request` in the pattern is a fully qualified constructor reference — same shape as the one that appears in `Net.Http.parse`'s definition, seen from outside the module.

Compile file-by-file and run:

```
$ ernc net/http.ern              # produces net/http.erc
$ ernc main.ern                  # produces main.erc
$ ern --load-path . main.erc     # --load-path adds the current directory to the load path
GET /
```

Or in directory mode — compile the whole tree and put outputs under `build/`:

```
$ ernc -o build .                # walks the source tree, writes build/net/http.erc and build/main.erc
$ ern --load-path build build/main.erc
GET /
```

Directory mode compiles in dependency order automatically, creates missing subdirectories under `build/`, and removes stale `.erc` outputs whose source is gone (`--no-clean` disables the sweep). It's the recommended pattern once a project has more than one file.

**The file's path is its namespace.** A file at `a/b/c.ern` provides declarations at namespace `A.B.C`. Each path segment is lowercase; each namespace segment is the *canonical typename form* — the path segment with its first ASCII letter uppercased and the rest preserved (`http.ern` → `Http`, `http_server.ern` → `Http_server`). The mapping is one-to-one, and the report scopes the collision rule to namespace segments: two path segments whose lowercase forms coincide is a compile-time error (report §4.2).

**Declarations use local names.** Inside `net/http.ern`, `export fn parse(...)` declares the function at its local name `parse`; the compiler exports it as `Net.Http.parse`. There is no file-namespace prefix on the declaration itself — repeating `Net.Http.` on every line would just restate the file's path.

**`export` marks the boundary.** A declaration prefixed with `export` is visible from other modules; a declaration without `export` is private to its own file. No `import`, no export list, no `pub`. `export` may prefix any top-level declaration: `fn`, `type`, `abstract type`, `let`, `foreign fn`, or `foreign type`. Constructors of an exported concrete type are exported with the type — `export type Optional(a) = None | Some(a)` makes `None` and `Some` visible to other modules; `type Internal = A | B` keeps the type and both constructors private. An abstract type controls constructor visibility through its `with { ... }` signature, not through `export`: the type name is `export`ed, its accessors are separately `export`ed if they should be public, and the constructor stays visible only to the definitions listed in the signature.

**External references use the qualified name.** A caller outside `net/http.ern` writes `Net.Http.parse`. Inside `net/http.ern`, unqualified `parse` refers to the local declaration.

**Entry point.** `ern main.erc` looks up `export fn main` in the loaded module and invokes it. `main` is a naming convention, not a reserved specialness — any exported function with the entry-point shape `() -> Unit with M` can be selected. If `tools.ern` exports a `check` function of that shape, run it as:

```
$ ern --load-path build --main Tools.check build/main.erc
```

`--main` takes a fully qualified name whose final segment is a lowercase function name (`Tools.check`, not `Tools.Check`). This is how a project with multiple entry points — a service main, a migration main, a bench main — keeps each in its own module.

### 6.2 Abstract types

Abstract types have a private representation and a public signature. Only definitions listed in the `with { ... }` signature can mention the constructor. Any locally declared type — abstract or concrete — creates a nested namespace inside its module, and its members are declared with a single-typename prefix (`fn Stack.push`). Report §4.8 shows the concrete-type variant used for per-type operator overloading (`fn Distance.+`, and so on).

```
// main.ern  (namespace Main)
export abstract type Stack(a) = Stack(List(a)) with {
    empty : Stack(a);
    push : (a, Stack(a)) -> Stack(a);
    pop : (Stack(a)) -> Optional(#(a, Stack(a)))
}

export let Stack.empty : Stack(a) = Stack([])
export fn Stack.push(x : a, Stack(xs) : Stack(a)) -> Stack(a) = Stack(x :: xs)
export fn Stack.pop(Stack(xs) : Stack(a)) -> Optional(#(a, Stack(a))) =
    match xs { [] -> None | x :: rest -> Some(#(x, Stack(rest))) }
```

Inside `main.ern` the accessors are written and used with the `Stack.` prefix (`Stack.push(x, s)`). External callers see `Main.Stack` for the type and `Main.Stack.push` for the operation, because `main.ern`'s namespace `Main` prefixes everything the module exports. The type-member namespace is *owned* by the file that declares the type: `Main.Stack.push` is compiled into `main.erc`, not a hypothetical `main/stack.erc`, and the loader consults `main.erc`'s compiled interface to find it.

`Stack.empty`, `Stack.push`, `Stack.pop` are listed in the `with { ... }` signature, so their bodies may name the `Stack` constructor. Anyone else — including an unlisted helper in the same module — cannot:

```
export fn Stack.size(Stack(xs) : Stack(a)) -> Int = List.size(xs)   // rejected: Stack.size is not in the signature
export fn Stack.isEmpty(s : Stack(a)) -> Bool = match Stack.pop(s) { // accepted: uses public operations
    None -> true
  | Some(_) -> false
}
```

An abstract type's representation can change later (a tree, a growable array), and callers built against the signature continue to work as long as each operation's observable contract is preserved.

An abstract type's qualified name and exported signature participate in its identity — not *only* its private representation. Matching signatures alone do not guarantee cross-node representation compatibility: two implementations may present the same operations while storing values as a list on one node and a tree on another. Representation changes must follow the code-shipping and type-identity rules in report §8.7.

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

A minimal program that submits a computation:

```
fn heavy(a : Int, b : Int) -> Int = a * a + b * b

export fn main() -> Unit with m = match remote(fn() = heavy(3, 4)) {
    Right(n) -> Io.println("remote returned " <> Int.toString(n))
  | Left(NoRemotePeer) -> Io.println("no remote peer configured")
  | Left(PeerLost) -> Io.println("peer lost or callback failed")
}
```

This program needs `ernest.conf` to list at least one peer with `"remote-peer": true` before `Right(...)` is possible.

### 7.2 Code shipping

`spawn(Peer(name), f)`, `remote(f)`, and any `send` whose destination is a remote address ship the closure or message payload and the code it depends on. The peer resolves each referenced hash — it uses cached code if present, or fetches from the sender. Types, functions, and constructors are identified across nodes by content hash; two nodes with structurally identical definitions agree on identity.

Some consequences the code sees:

- A `Sys.*` name referenced by shipped code resolves *on the peer that runs the code*. A shipped `Io.println` sends to the peer's `Sys.stdout`.
- A captured address value ships as a value — its target is whichever process it pointed to when the closure was formed, not re-resolved on the peer.
- Top-level bindings referenced by shipped code are initialized on demand on the peer, in the peer's environment. `let output = Sys.stdout` gives the sender's stdout on the sender and the peer's on the peer.
- `send` to a remote address returns immediately; a peer-side resolution failure faults the sender *asynchronously*, after `send` has already returned.
- Foreign definitions must be available and compatible on the peer.

Peer loss is *terminal from this node's view*. Once this node declares a peer lost, it treats the processes on that peer as dead. Their existing addresses do not become usable again if the same peer name reappears — a re-appearing peer is a new node instance. Monitors on remote addresses report `Down(reason = Fault("peer lost"), ...)`, and pending `remote` calls return `Left(PeerLost)`. Remote sends are best-effort: in-flight messages can be dropped at peer loss without a delivery notification, and returning from `send` is not evidence that the recipient processed the message. A callback or resolution failure that returned `PeerLost` does not, on its own, invalidate unrelated addresses for the same peer — only *actual* peer-loss detection has that effect.

### 7.3 Foreign types and functions

```
// ets.ern
export foreign type Table(k, v)

export foreign fn member(t : Table(k, v), key : k) -> Bool with m = "ets:member/2"
```

External callers write `Ets.Table` and `Ets.member`. `foreign type` declares a type whose values are made and used only by foreign functions — no Ernest-side constructor, no pattern match. `foreign fn` binds a name to an implementation on the other side (here, Erlang's `ets:member/2`).

Ernest treats the foreign boundary as a *promise*: the declared type is what comes back, the mailbox effect is honest, a pure declaration means no effects. The following three breaches are checked at runtime; purity remains a trusted promise:

- **Wrong return type.** *Checked at runtime.* The declared type is Ernest's contract; a value the foreign side hands over that does not match faults the *receiving* Ernest process on first observation.
- **Thrown exception.** *Checked at runtime.* Erlang exits and throws become `Fault` on the calling process.
- **Wrong message from a foreign process.** *Checked at runtime.* A message that doesn't match the *destination's* declared mailbox type faults the receiver on first observation.
- **Purity.** *Not checked.* Declaring `foreign fn` without `with M` is a promise the foreign side cannot enforce mechanically. Reserve pure declarations for functions that genuinely have no effect.

### 7.4 Node-local foreign values

Foreign values are bound to the node that made them. Any cross-node transport of a value that transitively contains one faults with `Fault("foreign value cannot cross nodes")` — including a closure that captures such a value.

```
let t = Ets.new();
spawn(Peer("alice"), fn() = Ets.insert(t, "x", 1))   // fault: t is captured
```

Programs that need to share table-like state across nodes serialize the contents and rebuild on the peer.

### 7.5 The shim pattern

Erlang's `ets:lookup` returns a list because the key might match zero or one entry. Both declarations below live in `ets.ern` (namespace `Ets`):

```
// ets.ern
export fn lookup(t : Table(k, v), key : k) -> Optional(v) with m =
    match rawLookup(t, key) { [#(_, v)] -> Some(v) | _ -> None }

foreign fn rawLookup(t : Table(k, v), key : k)
    -> List(#(k, v)) with m = "ets:lookup/2"
```

`rawLookup` has no `export`, so it is file-local. `Ets.lookup` is the typed API callers use (imported by qualified name `Ets.lookup`).

Erlang's `{ok, V} | {error, R}` convention does not automatically match an Ernest `Either(e, a)`. Ernest's `Either` constructors are `Left(e)` and `Right(a)`, and under §8.4's ABI they encode as `{'Left', e}` and `{'Right', a}` (quoted, source-preserving). Erlang's `{ok, V}` uses the lowercase atom `ok`, which is a different value.

The cleanest fix is a small Erlang-side helper that produces the Ernest-shaped return. For a foreign call whose Ernest declaration is `Either(String, Int)`, the helper's payloads must already match Ernest's ABI: `V` must be an `Int`-shaped integer, and `R` must be a UTF-8 binary (Ernest `String`). The helper is a fragment — the surrounding `find/1`, module name, and export list depend on the caller's setup:

```erlang
%% Erlang helper (fragment); requires find/1 to return an integer on {ok, _}
%% and a UTF-8 binary on {error, _}
lookup(Key) ->
    case find(Key) of
        {ok, V}    -> {'Right', V};
        {error, R} -> {'Left', R}
    end.
```

The Ernest `foreign fn` binds to that helper — the returned term already matches Ernest's ABI, no decoder needed:

```
// store.ern (namespace Store)
export foreign fn lookup(key : String) -> Either(String, Int) with m = "store_helper:lookup/1"
```

If `find/1` returns reasons of another shape (an atom, a nested tuple), the Erlang helper must convert them to the declared Ernest form before returning; the Ernest side does not paper over ABI-shape breaches.

Report Appendix D walks a full `ets.ern` reference implementation (namespace `Ets`). Its foreign calls happen to already match Ernest's ABI (`[{K, V}]` maps to `List(#(k, v))`, `Bool` to `true`/`false`), so it needs no Erlang wrapper.

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

**Alignment and range rules:**

- A bitstring produces a `Bytes` value; the total bit count must be a multiple of 8.
- A `bits` or `bytes` segment binding to a `Bytes` value must itself be byte-multiple. Sub-octet fields use the `int` specifier (binding to `Int`).
- Compile-time-constant alignment violations are compile-time errors. Dynamic-size violations fault in construction and fail matching in patterns.
- A segment value that does not fit its specified width — an `Int` too large for `size(N)-int` at construction — is a fault.

`size(Expr)` in a pattern evaluates in the scope of earlier-bound segment variables plus the enclosing scope. The expression is pure (no mailbox effect); a fault in it faults the process.

**Precondition for `frame`/`parseFrame`:** the round trip works when `len` equals `body`'s byte count *and* `len` fits in the length-field width (16 bits, so 0 to 65 535). `parseFrame(frame(1, <<65, 66>>))` returns `Some(#(1, <<65>>, <<66>>))` — a one-byte body and a one-byte remainder, not an error, because `len = 1` was chosen. If `len` doesn't fit the width, `frame` faults at construction.

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

Every top-level declaration lives at a namespace determined by its file's path. A file at `a/b/c.ern` provides declarations at namespace `A.B.C`; the declaration itself is written with a local name, and the compiler exports it (if marked `export`) as `A.B.C.name`. Code anywhere refers to the declaration by its full name. `export` marks visibility outside the module; without it, a declaration is private. No `import`, no export list — the qualified name IS the reference.

**Why parenthesized lambdas after `|>`?**

A lambda's body is greedy — it extends until the enclosing form's separator. Without parens, `x |> fn(y) = y + 1 |> f` would either eat the second `|>` into the body or split confusingly. Parens make the boundary explicit.

**Why write `fn(x) = ...` for lambdas instead of `x -> ...`?**

Ernest is n-ary: every function has a specific number of arguments recorded in its type. `fn(x)` says "one argument"; `fn(x, y)` says "two." The chosen syntax makes arity visible at the definition site, and the parenthesized form matches ordinary calls.

## 9. Reading further

The four paper programs, in ascending complexity:

- [`examples/tick_game.ern`](examples/tick_game.ern) — snake game with tick-based updates; `..` record updates, one process per player.
- [`examples/repl.ern`](examples/repl.ern) — small read-eval-print loop; `<-` for chained parsing, `monitor` + `kill` for aborting slow evaluation.
- [`examples/filesync.ern`](examples/filesync.ern) — file sync between two nodes; mutual-address setup, one process per write, `Sys.fs`.
- [`examples/webserver.ern`](examples/webserver.ern) — HTTP server with sessions in ETS; `foreign fn`, abstract types, ETS accessed through foreign functions.

The paper programs assume runtime references beyond the required `Sys.stdout` and `Sys.clock` — `Sys.fs`, `Sys.keys`, `Sys.net`, and an ETS backend are program-specific dependencies that each program names in its own assumptions.

For the language rules themselves, [`ernest_report.md`](ernest_report.md) is the authority. Appendix F glosses every technical term.

For why Ernest looks the way it does — what was tried and rejected — [`decisions.md`](docs/decisions.md) records dated design decisions.
