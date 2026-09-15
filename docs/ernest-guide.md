# Ernest: A Reading Guide

A guide for someone reading Ernest for the first time. Not the language report — the report [`ernest.md`](ernest.md) is where the rules live. This guide is meant to be read at a slow pace, one section at a time, with the code examples in front of you. Nothing is a summary; everything shows a concrete piece of Ernest and then talks about what it does.

## 0. Two ideas

Ernest is a functional language for concurrent programs. Two ideas run through it:

- **Functions** with types the compiler figures out for you.
- **Processes** with typed mailboxes, as the only way a program affects the world.

That's the whole vocabulary. Everything else in the language is a rule for how functions and processes show up in each other.

"Functions" you probably know. "Processes" means small independent units of computation, each with its own mailbox, each running concurrently with the rest.

## 1. A very small program

Here is a complete Ernest program.

```
fn main() -> Void with Never = Io.println("hello, world")
```

When Ernest runs this, it prints `hello, world` followed by a newline to standard output.

### 1.1 The line, piece by piece

`fn` starts a function definition. `main` is its name; `main` is special — it is the function Ernest calls when the program starts. The empty parens say `main` takes no arguments.

The return annotation `-> Void with Never` has two parts. The first `Void` is the return type; the second, after `with`, is the mailbox type. `Void` is a type with exactly one value — also called `Void` — that means "no interesting information here." So `main` returns `Void`: the function did its work, no result to hand back.

Every function in Ernest runs inside a process, and every process has a mailbox with a type — the type of messages it can receive. The `with M` at the end of a function's arrow says "this function acts through the process it runs in, whose mailbox type is `M`." `main`'s mailbox type here is `Never` — a type with no values, meaning the process cannot receive anything at all. That fits a `main` that only spawns children and sends: it never calls `receive`, so the type says so.

The `=` marks the start of the body. Here the body is a single expression: a call to `Io.println`, a function from the standard library that writes text to standard output followed by a newline. `Io` is a namespace from the standard library (Appendix E of the report lists them all). Single-expression bodies don't need braces; longer bodies do.

### 1.2 The big idea

Ernest has no built-in "print." What `Io.println` does is send its argument as a message to a small stdout process the runtime provides. That process receives the text and writes it out.

You do not "print" or "write" in Ernest. You send a message to a process. That process — running concurrently, elsewhere — receives the message and does the actual writing. There is no hidden syscall. If you want to touch anything outside your own function, you send a message to a process that touches it for you.

This idea keeps coming back. Everything else in Ernest builds on it.

## 2. Types

Ernest starts with a small set of built-in scalar types:

- **`Int`** — integers of arbitrary precision.
- **`Float`** — IEEE 754 double precision, finite values only. Arithmetic that would produce a non-finite result (overflow, division by zero, `0.0 / 0.0`) faults.
- **`Char`** — one Unicode code point.
- **`String`** — a Unicode string.
- **`Bytes`** — a sequence of octets.
- **`Bool`** — `true` or `false`.

Literals look how you'd expect: `42`, `3.14`, `'a'`, `"hello"`, `true`.

The prelude also declares `Void` — a type with exactly one value, also called `Void`. Functions that have nothing meaningful to return use it (`main` is one). It's not a base type but you'll see it from §1 onward.

You'll meet three built-in generic collections shortly: `List(a)` for immutable linked lists, `Map(k, v)` for immutable dictionaries, and `Set(a)` for immutable sets. `Address(m)`, `Reply(a)`, and `Never` are process-related built-ins we'll see in section 5.

Beyond the built-ins, programs need to describe their own data shapes. Ernest lets you declare types with named cases.

Here is a simple one:

```
type Direction = North | South | East | West
```

Four cases, called *constructors*. A value of type `Direction` is one of these four things: `North`, `South`, `East`, or `West`.

You can pick between them with `match`:

```
fn opposite(d : Direction) -> Direction = match d {
    North -> South
  | South -> North
  | East -> West
  | West -> East
}
```

`match` looks at `d` and picks the clause whose pattern matches. Each clause is a case: a pattern on the left of `->`, an expression on the right. The first clause whose pattern matches gets its expression evaluated, and the whole `match` expression takes that value.

### 2.1 Constructors that carry data

Sometimes a constructor is not just a label — it carries a value with it. Ernest's `Optional` type is like this:

```
type Optional(a) = None | Some(a)
```

Two constructors. `None` is a plain label. `Some(a)` carries one value inside.

That `(a)` after `Optional` needs a moment. It says "the type `Optional` takes a parameter." The parameter is called `a`. `a` is a *type variable* — it stands for any type.

Then in `Some(a)`, the `a` says: "when you make a `Some`, put a value of type `a` inside."

Both `a`s are the same type variable. That ties the parameter of `Optional` to what a `Some` carries.

Practical uses:

- `Some(5)` is a value of type `Optional(Int)`.
- `Some("hello")` is a value of type `Optional(String)`.
- `None` is a value of type `Optional(a)` for any `a` — since `None` doesn't carry anything, `a` is free to be whatever.

`Optional` shows up whenever a function might not have a value to give you — like looking up a key in a map, or parsing a number.

### 2.2 Constructors with named fields

Sometimes a constructor carries several things, and each one deserves a name. Ernest lets you say:

```
type Person = Person(name : String, age : Int)
```

One constructor, `Person`, with two named fields: `name` of type `String`, and `age` of type `Int`.

To make one:

```
Person(name = "Alice", age = 30)
```

Notice the difference between the type declaration and the value:

- **Declaration**: `Person(name : String, age : Int)`. Colons mark field types.
- **Value**: `Person(name = "Alice", age = 30)`. Equals signs give field values.

Same overall shape (a constructor, then a parenthesized list), different punctuation depending on whether we're describing the shape or building a value.

Ernest keeps this consistent: `:` for types, `=` for values.

### 2.3 Wrapper types

There is one shape that comes up: a type with just one constructor that wraps just one value.

```
type UserId = UserId(Int)
```

This is a *wrapper* over `Int`. A `UserId` value is really "an `Int` with a label." No extra data, no alternatives — just an integer wearing a UserId jacket.

Why do it? Two reasons. First, type safety: the compiler will not let you pass a raw `Int` where a `UserId` is expected. Second, meaning: `UserId(42)` reads as "the user whose id is 42," not just "an integer."

The prelude type `Reply(a)`, which we'll meet later, is another example of a wrapper. Wrapper types are a small, useful pattern.

### 2.4 Lists

Lists are Ernest's built-in linked collection: `List(a)` is a list whose elements have type `a`. `[]` is the empty list; `[1, 2, 3]` is a list of three `Int` elements.

Lists build up by prepending. The operator is `::`:

```
let xs = 1 :: [2, 3]; // xs is [1, 2, 3]
let ys = 0 :: xs // ys is [0, 1, 2, 3]
```

`::` is right-associative, so `1 :: 2 :: 3 :: []` reads left-to-right as building `[1, 2, 3]` — which is exactly how `[1, 2, 3]` is defined.

Lists decompose with pattern matching:

```
match xs {
    [] -> "empty"
  | head :: rest -> "first is " <> Int.toString(head)
}
```

The first clause matches the empty list. The second clause binds `head` to the first element and `rest` to the remainder.

Common list operations live in `List.ern` (Appendix E of the report): `List.map`, `List.filter`, `List.foldLeft`, `List.foreach`, and so on. Since they're subject-first (`List.map(list, f)`, not `List.map(f, list)`), they compose naturally with `|>`.

### 2.5 Maps and Sets

Two more built-in immutable collections. Both require equality on their key/element type.

- **`Map(k, v)`** — a dictionary from keys of type `k` to values of type `v`.
- **`Set(a)`** — a set of elements of type `a`.

Neither has literal syntax; you build them with functions from their modules:

```
let m = Map.empty |> Map.put("alice", 30) |> Map.put("bob", 25);
Map.get(m, "alice") // Some(30)

let s = Set.fromList([1, 2, 3]);
Set.contains(s, 2) // true
```

Both modules are subject-first and live in Appendix E of the report (`Map.ern`, `Set.ern`).

### 2.6 Tuples

A tuple is a fixed-size positional group of values, each with its own type. Tuples use a `#(...)` prefix to keep them clearly distinct from expression grouping `(e)` and from function types `(A, B) -> C`:

```
let point : #(Int, Int) = #(3, 4);
let entry : #(String, Int) = #("Alice", 30)
```

The type `#(A, B)` is a two-tuple; `#(A, B, C)` a three-tuple; and one-tuples `#(A)` are also legal — the `#` makes the shape unambiguous.

Destructure with a pattern:

```
let #(x, y) = point;
let #(name, age) = entry
```

Tuples are useful when a function needs to return more than one value without introducing a named type:

```
fn divmod(a : Int, b : Int) -> #(Int, Int) = todo("quotient and remainder")
```

For anything where positions carry different meanings that a reader would benefit from seeing, prefer a named-fields constructor (`Person(name : String, age : Int)`) over a tuple. Tuples are for genuinely positional data — 2D points, key-value pairs, multi-value returns — where the position itself is the interpretation.

## 3. Functions

The syntax you saw in `main` works for any function.

```
fn double(n : Int) -> Int = n * 2
```

Read left to right:

- `fn double` — declaring a function named `double`.
- `(n : Int)` — one parameter, `n`, of type `Int`.
- `-> Int` — returns `Int`.
- `= n * 2` — the body.

If the body is a single expression, you don't need braces. If it's a sequence of statements, wrap them in `{ ... }`:

```
fn hypotenuse(a : Int, b : Int) -> Int = {
    let sqA = a * a;
    let sqB = b * b;
    sqA + sqB
}
```

The `;` separates statements. The last statement is the block's value — here, `sqA + sqB`, which is what `hypotenuse` returns.

### 3.1 Pure functions

`double` and `hypotenuse` don't touch the outside world. They just take numbers and return numbers. Their types don't have a `with M` on the arrow, and Ernest calls them *pure*.

A pure function's result depends only on its arguments. Nothing else. It doesn't send messages, doesn't ask what process it's in, doesn't read files. Its type is a promise: give me the same arguments, I'll give you the same result.

### 3.2 Functions that act through the process

Now compare with a function that uses the runtime:

```
fn greet() -> Void with m = Io.println("hi")
```

Same shape as `double`, but with two differences: the return arrow has `with m`, and the body calls `Io.println`, which internally sends a message.

The `with m` at the end of the arrow marks: this function acts through the process it runs in. It doesn't just compute a value from its arguments; it produces observable effects (sending a message).

The `m` is lowercase — a *type variable*, like `a` in `Optional(a)`. It means: this function's mailbox type isn't fixed to a specific value; it works with any mailbox. `greet` sends a message but doesn't care what messages the enclosing process itself receives — the enclosing process is what will run this call and pay the mailbox cost.

If a function receives messages (uses `receive`), its mailbox type is not free — it has to match the clause patterns. We'll see that soon.

Take a moment: **pure or process is a property of the function type, not of the syntax.** A reader glancing at a function type knows whether calling it can send messages, receive them, or fault. Nothing is hidden.

### 3.3 Type inference

Every function example you have seen so far has type annotations on its parameters and return. In truth those are optional. Ernest has Hindley-Milner type inference — the compiler figures out types from how you use values.

```
fn double(n) = n * 2
```

That's a legal Ernest function. The compiler sees `n * 2`, notes that `*` is defined on `Int`, and concludes `n : Int` and the result is `Int`. The inferred type is `(Int) -> Int`, exactly as if you had written it out.

In practice you'll still annotate top-level functions, because a signature at the top of a definition is what a reader looks at first. But local `let` bindings, lambdas, and small helpers can skip annotations without loss.

Inference is also what picks specific types for the type variables you saw earlier — the `a` in `Optional(a)`, the `m` in `with m`. At each call site the compiler works out what those stand for from the arguments passed in.

### 3.4 Match and if

We've been using `match` and `if` in examples without introducing them. Two expression forms.

**`match`** takes a value and a list of pattern clauses:

```
match e {
    pat -> expr
  | pat -> expr
}
```

The first clause whose pattern matches `e` gets its expression evaluated, and the whole `match` takes that value. The compiler checks that the clauses cover every possible shape of `e`; a missing case is a type error.

A clause can also have a **guard** — a `when` expression between the pattern and `->`, giving a condition the clause's variables must satisfy:

```
match x {
    n when n > 0 -> "positive"
  | n when n < 0 -> "negative"
  | _ -> "zero"
}
```

The pattern binds first, then the guard is evaluated with those bindings in scope. If the guard is `false`, the clause fails and the next clause is tried. Guards do not count toward exhaustiveness — the compiler still requires a fall-through clause (here, `_`) that matches without a guard. Guards work the same way in `receive` clauses.

**`if`** is an expression, not a statement:

```
if cond then a else b
```

`cond` is a `Bool`; if `true`, the whole expression takes `a`, otherwise `b`. Both branches must have the same type. There is no `if` without `else` — an if-expression always has a value.

Because both are expressions, you can bind their results:

```
let x = if flag then 1 else 2;
let name = match user { Some(u) -> u | None -> "guest" };
```

**Patterns everywhere, with a rule.** The same patterns you see in `match` clauses also appear in `let` bindings and in function parameters. But there is a distinction: patterns in `let` and function parameters must be **irrefutable** — they must always match. Tuple patterns are irrefutable (a tuple always has the shape you spelled), and so are wrapper patterns like `Snapshot(seen = s)` when there is only one constructor:

```
let #(x, y) = point; // fine — tuples always destructure
fn area(Point(x, y) : Point) -> Int = x * y // fine — Point has one constructor
```

Refutable patterns are a type error in these positions:

```
let Right(v) = e // type error — e might be Left(...)
```

That's the "decompose versus compare" line. `let` and function parameters *decompose* a value whose shape you already know; `match` and `receive` (and `<-`, §10) *compare* a value against several shapes and let each clause handle its case. If you need to peek at a sum type, reach for `match`.

### 3.5 The pipe operator `|>`

Ernest's standard library is subject-first: `List.map(list, f)`, `String.chars(s)`, `Map.get(map, key)`. When you compose several such calls, the expression reads inside-out:

```
String.chars(String.toLower(String.trim(input)))
```

The pipe operator flips the reading direction:

```
input |> String.trim |> String.toLower |> String.chars
```

Same value, read left to right. `x |> f` is exactly `f(x)`. When the right-hand side already has arguments, the pipe inserts its left-hand side as the *first* argument: `xs |> List.map(f)` is `List.map(xs, f)`.

Two rules of thumb:

- Use `|>` when the reading direction adds real clarity — usually three or more chained transformations, or a chain that mixes stdlib functions with your own.
- Don't force it. `Int.toString(n)` is fine as a single call; `n |> Int.toString` is longer and no clearer.

`|>` is the lowest-precedence binary operator, below `||`. So `a + b |> f` is `f(a + b)`, and `a |> b |> c` is `c(b(a))` — chains build left-associatively.

## 4. Abstract types

Sometimes you want a type whose values look like a specific shape from inside your module but appear abstract to callers. Someone can hold a value of the type, pass it around, and use functions on it — but they cannot construct it directly, cannot pattern-match on its shape, and cannot see what's inside.

Ernest gives you this with `abstract type`:

```
abstract type Stack(a) = Stack(List(a)) with {
    empty : Stack(a);
    push : (a, Stack(a)) -> Stack(a);
    pop : (Stack(a)) -> Optional(#(a, Stack(a)))
}
```

Read top-down:

- `abstract type Stack(a) = Stack(List(a))` — declares a type with one constructor, `Stack`, holding a `List(a)`.
- `with { ... }` — the signature. It lists the names allowed to see the constructor.

The names in the signature (`empty`, `push`, `pop`) live in the `Stack` namespace: `Stack.empty`, `Stack.push`, `Stack.pop`. Their definitions may reference the raw `Stack(_)` constructor to build and destructure values. Anyone else who writes `Stack(...)` gets a type error.

The definitions:

```
let Stack.empty : Stack(a) = Stack([])
fn Stack.push(x : a, Stack(xs) : Stack(a)) -> Stack(a) = Stack(x :: xs)
fn Stack.pop(Stack(xs) : Stack(a)) -> Optional(#(a, Stack(a))) =
    match xs { [] -> None | x :: rest -> Some(#(x, Stack(rest))) }
```

`Stack(x :: xs)` and `Stack(xs)` inside these definitions name the constructor because their names appear in the signature. A caller outside `Stack` cannot do this. They must use `Stack.empty`, `Stack.push`, and `Stack.pop`.

Why abstract? Two reasons.

- **Abstraction.** You can change the internal representation later — a tree, a growable array, anything — without breaking callers, as long as the signature stays the same.
- **Invariants.** If a value can only be built by your functions, your functions can enforce invariants that the constructor alone wouldn't preserve — a sorted list, a non-empty stack, whatever the type calls for.

Abstract types show up in the web server paper program (abstract `StatusCode`, `SessionId`) and are the standard way to bundle a type with its allowed operations.

## 5. A process

A small process — a counter. First a version that only accepts updates (fire-and-forget), then one that also answers callers who ask for its current state (request-reply).

### 5.1 The message type

A counter is a process that holds a number. To start, let's say it accepts one kind of message: "please add `k` to my state."

We declare that as a type:

```
type CounterMsg = Inc(Int)
```

One constructor, `Inc`, carrying an `Int` positionally. This is a *mailbox type* — the set of message shapes a process can receive.

### 5.2 The counter function

Now the counter itself.

```
fn counter(n : Int) -> Void with CounterMsg = receive {
    Inc(k) -> counter(n + k)
}
```

`fn counter(n : Int)` — a function taking the counter's current state as an integer parameter.

`-> Void` — returns nothing meaningful (unit).

`with CounterMsg` — runs in a process whose mailbox type is `CounterMsg`. That means this function can only run in a process that expects `CounterMsg` values.

`= receive { ... }` — the body is a `receive` expression. `receive` waits for a message and dispatches on it.

One clause:

```
Inc(k) -> counter(n + k)
```

If the incoming message is `Inc(k)`, bind `k` to the integer inside, and recursively call `counter(n + k)`. That "recursively" is a tail call — Ernest guarantees tail-call optimization, so this doesn't grow the stack. The counter just keeps looping forever, each iteration remembering the new state as `n`.

This is Ernest's **fire-and-forget** shape: a sender calls `send(c, Inc(5))`, which returns immediately, and there is no callback path back. The counter processes the message eventually — soon, but with no ordering guarantee against the sender's next statement other than "the counter's mailbox sees my messages in the order I sent them."

### 5.3 Asking questions: `Reply`

Fire-and-forget is fine for updates, but sometimes you want to *ask* the process something — its current value, for instance. That requires an answer, and fire-and-forget has no place to put one.

Ernest's tool for this is `Reply(a)`, a one-shot address the receiver fills in exactly once. Think of it as a stamped return envelope: the caller hands it over with the request; the receiver puts a value in it and sends it back.

Extend the counter's message type:

```
type CounterMsg
    = Inc(Int)
    | Get(reply : Reply(Int))
```

`Get` carries one named field, `reply : Reply(Int)`. The sender allocates a fresh `Reply(Int)` when it wants to ask; the counter fills it in with the current state.

Two things distinguish `Reply(a)` from `Address(a)`:

- `Address(a)` is a long-lived reference; you can send to it many times.
- `Reply(a)` is one-shot; someone gave it to you *just to answer this one question*, and once you answer, it's used up.

The extended counter grows a second `receive` clause:

```
fn counter(n : Int) -> Void with CounterMsg = receive {
    Inc(k) -> counter(n + k)
  | Get(reply = r) -> { answer(r, n); counter(n) }
}
```

The `Get` clause binds the `Reply(Int)` field to `r`, then:

- `answer(r, n)` — sends `n` back through the reply address. This "uses up" the reply capability.
- `counter(n)` — loop again, state unchanged.

The block `{ answer(r, n); counter(n) }` runs both in sequence, and the block's value is the value of the last statement (`counter(n)`, which returns unit). That's what the clause's body evaluates to.

`answer` is another prelude function. Its job is exactly this: consume a `Reply(a)` value by sending a specific `a` back to the caller.

### 5.4 The compiler checks the reply

The compiler enforces something you might miss on first read: **every `Reply(Int)` bound in a `receive` clause must be used exactly once, on every path.**

Look at the `Get` clause again: it binds `r` from the incoming message, then calls `answer(r, n)`. Good — used once.

If we had written this instead:

```
Get(reply = r) -> counter(n) // forgot to answer!
```

That would be a type error. `r` would be bound but never used. The compiler would refuse to compile the counter.

That check catches a whole category of silent bugs: a caller that sends a request, waits for a reply that never comes, and eventually times out with no useful diagnostic. Ernest makes it impossible to *syntactically* forget to answer — the type system remembers for you.

The consumption doesn't have to be direct or in the same clause. There are four legal forms:

1. **`answer(r, v)` directly** — what the counter does.
2. **Passing to a helper** — calling `helper(r, ...)` where `helper` has a parameter of type `Reply(Int)`. The obligation moves to the helper, which is checked at its own definition.
3. **Message field** — sending `r` as a field of another message. Whoever's `receive` clause eventually binds it takes over the obligation.
4. **Spawning** — capturing `r` in a lambda passed directly to `spawn` (§6). A child process runs later and calls `answer` when it's ready; the compiler checks the child's body for exactly-once consumption.

The exactly-once check is *compositional*: it doesn't chase functions across call boundaries. Each function is checked at its own definition. A function that takes `Reply(a)` and correctly consumes it is a valid delegation target from anywhere. The `filesync` paper program uses form 4: an incoming write request is handed to a `writer` process that performs the file I/O in the background and calls `answer` when it finishes, so the process handling `receive` doesn't block on disk.

**One caveat.** The check is static. It verifies that every syntactically reachable path calls `answer` (or delegates, or spawns), but it can't tell whether execution will *actually* reach that call at runtime. A path that enters an infinite loop, faults, or waits forever will bypass the answer without the compiler knowing. That's why `Address.call` requires a mandatory timeout (§6.3): the caller must plan for the case where the answer never comes — bug, fault, or a receiver that answers only on February 32.

## 6. Running the counter

We have the counter *function*. Now we need to *run* it in a process, and send it some messages.

Here's `main` again, this time doing exactly that:

```
fn main() -> Void with m = {
    let c = spawn(Local, fn() = counter(0));
    send(c, Inc(5));
    send(c, Inc(3));
    match Address.call(c, fn(r) = Get(reply = r), 1000) {
        Some(n) -> Io.println("count is " <> Int.toString(n))
      | None -> Io.println("counter is not answering")
    }
}
```

If you want to send to a different address (a logger, a capture buffer for testing) instead of stdout, `Io.printlnTo(addr, "hi")` takes an explicit `Address(String)`.

Four things happen. Let's walk through them.

### 6.1 Spawn

```
let c = spawn(Local, fn() = counter(0));
```

`spawn` starts a new process. It takes two arguments:

- `Local` — where to run the new process. `Local` means "on this same node." There's also `Peer("some-name")` for remote spawning, which we won't cover here.
- `fn() = counter(0)` — a function of no arguments. When the new process starts, this is what it runs.

Result: an *address* to the new process, bound to `c`. Its type is `Address(CounterMsg)` — you can send `CounterMsg` values to it.

Notice: `fn() = counter(0)` is a lambda. It looks like an ordinary function declaration but without a name. Its body just calls `counter(0)`. When the process starts, this lambda runs, which calls `counter`, which enters the `receive` loop.

### 6.2 Send

```
send(c, Inc(5));
send(c, Inc(3));
```

Two calls to `send`, each putting one message in the counter's mailbox.

`send` is fire-and-forget. It returns immediately (with `Void`), whether or not the counter has processed the previous message yet. The messages queue up in the mailbox in the order sent, and the counter handles them in that same order.

By the time both `send`s return, the counter has probably not yet finished processing them — but that's fine. Its `receive` loop will get to them soon enough.

### 6.3 Address.call

Now for the interesting part:

```
match Address.call(c, fn(r) = Get(reply = r), 1000) {
    Some(n) -> ...
  | None -> ...
}
```

`Address.call` is a prelude function that does a synchronous request-reply. It takes three arguments:

- `c` — the address to send to.
- `fn(r) = Get(reply = r)` — a lambda that, given a fresh `Reply(Int)` `r`, builds the message to send.
- `1000` — how many milliseconds to wait for the reply.

What happens under the hood: `Address.call` creates a fresh `Reply(Int)` for us, calls our lambda with it to construct the `Get` message, sends the message to `c`, and blocks waiting for the reply — up to 1000 ms.

The result is `Optional(Int)`:

- `Some(n)` if the counter answered within 1000 ms.
- `None` if it timed out.

We `match` on the result. On success, we print `"count is 8"` (or whatever the counter's state is). On timeout, we print an error.

The timeout is mandatory in `Address.call` — you can't accidentally wait forever. The `Optional` result forces you to handle the "no answer" case somehow, whether that's giving up, retrying, or reporting the error.

If you genuinely want no timeout — a startup wait for a critical service, say, where nothing else can happen until this answer arrives — the prelude also has `Address.callForever(addr, mk)`. It waits as long as it takes and returns the answer directly, not wrapped in `Optional`. If the receiver never answers, the caller hangs; that's the point of the name. Use it when the caller has explicitly decided to wait, not by default.

### 6.4 String concatenation

One small thing in the success case:

```
"count is " <> Int.toString(n)
```

`Int.toString` converts an integer to its string representation. `"8"`, in this case.

`<>` is concatenation. It works on `String`, `List`, and `Bytes`, resolved by the operand types (`String.<>` here, `List.<>` for lists). Both operands are `String` here, so the result is `String` — `"count is 8"`. `Io.println` then sends that to stdout with a newline appended.

Take a moment. This is a complete Ernest program that uses two processes (main, plus the counter it spawned), passes messages between them, and prints the result. It's about twenty lines.

### 6.5 What happens when `main` returns

The counter's `receive` loops forever — but `main` doesn't. Once the `match` on `Address.call`'s result finishes and `main` reaches its end, the program ends.

When `main` returns, the runtime kills every *local* process still alive — the counter, any local workers you spawned — with cause `ProgramEnd`. System processes release their resources. The node stops. Workers you spawned on peer nodes are unaffected — they run under their own runtime.

If you want a program that keeps running, `main` must not return: it can spawn processes and then `receive` forever, or run its own loop. The counter above finishes quickly because we exit deliberately after asking a single question.

There is a second termination case: **deadlock**. If every process is waiting in `receive` without an `after`, and no messages are in flight, the runtime ends the program with `Deadlock`. It's the safety net for "everyone is waiting for someone who is waiting for everyone."

## 7. Two processes talking

The counter has main talking to it. Let's look at two processes talking to each other.

This is the ping-pong program from Appendix B of the report.

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

Same building blocks as the counter, but arranged for two processes.

### 7.1 The message type

`PongMsg` has two constructors:

- `Ping(n : Int, reply : Reply(Int))` — "ping me with this number and answer with an int."
- `Stop` — "please shut down."

### 7.2 The pong process

`pong` is the receiver. Its mailbox type is `PongMsg`. Its `receive` has two clauses:

- On `Ping`, print `"pong <n>"`, answer the reply with `n`, then loop.
- On `Stop`, return (which ends the process — its function has finished).

### 7.3 The ping process

`ping` is the sender. Its parameters are the pong process's address and a countdown `n`.

If `n` is `0`, send `Stop` and finish. Otherwise:

- Print `"ping <n>"`.
- Do `Address.call` on `pongAddr` with a `Ping` message. Wait up to 5 seconds.
- On success, recurse with `n - 1`.
- On timeout, print an error and tell pong to stop.

Notice `ping`'s return type: `-> Void with m`. That `m` is lowercase — a type variable — meaning ping's mailbox type is *polymorphic*, unconstrained. Ping never `receive`s on its own mailbox. It only sends and uses `Address.call`. So the type checker leaves the mailbox slot free.

### 7.4 Main starts them and waits

```
let pongAddr = spawn(Local, fn() = pong());
let _ = spawn(Local, fn() = ping(pongAddr, 3));
monitor(pongAddr, PongDone);
receive { PongDone(_) -> Void }
```

- Spawn pong first, get its address.
- Spawn ping, passing pong's address in. Discard ping's returned address with `let _ = ...`; `main` doesn't need it.
- Call `monitor(pongAddr, PongDone)`: ask the runtime to send `PongDone(d)` to `main`'s mailbox when pong dies, where `d : Down` describes the cause.
- Wait for that message, then return.

Why the wait? The report says the program ends when `main` returns; any live process is then killed with cause `ProgramEnd` (report §8.6). If `main` returned right after the two spawns, ping and pong would both be killed before the first message went out. `main` has to stay alive until the work is done, and that means waiting on a real signal — here, pong's death.

`MainMsg = PongDone(Down)` is `main`'s mailbox type: exactly one shape of message, the monitor notification. Pong dies with reason `Returned` when it processes `Stop`, so `PongDone(_)` matches and `main` returns.

Output: alternating "ping 3", "pong 3", "ping 2", "pong 2", "ping 1", "pong 1".

### 7.5 Message ordering

Ernest guarantees one ordering property: **messages from one process to another arrive in sending order.** If ping sends `Ping(3)` then `Ping(2)` to pong, pong will see `Ping(3)` before `Ping(2)`. This is per-sender FIFO.

Between *different* senders there is no ordering. If two processes both send messages to pong, pong will see both, but their relative order is whatever the runtime decides. When you have fan-in from multiple sources, this is the property to plan around — usually with a sequence number in the message payload if the order matters.

The counter and ping-pong examples don't rely on cross-sender ordering; each has a single sender talking to each receiver.

## 8. Watching another process

When you spawn a child process, it runs concurrently with the parent. Sometimes the parent needs to know when the child stops — did it finish, did it crash, was it killed. Ernest's tool for this is `monitor`.

Processes die for one of four reasons:

- **`Returned`** — the function finished normally.
- **`Killed`** — another process called `kill` on them.
- **`ProgramEnd`** — the whole program is shutting down.
- **`Fault(msg)`** — an unhandled error, with a message describing what went wrong.

There is no shared exception mechanism and no automatic propagation. A fault in one process does not affect another. If you want to know a process has died, you explicitly ask.

```
monitor : (Address(a), (Down) -> m) -> Void with m
```

`monitor(child, wrap)` sets up a watch. When `child` dies, the runtime places `wrap(d)` in *your* mailbox, where `d : Down` carries the cause.

```
type Down = Down(reason : Reason, function : String)
type Reason = Returned | Killed | ProgramEnd | Fault(String)
```

The typical pattern:

```
type ParentMsg = Died(Down) | ...

fn parent() -> Void with ParentMsg = {
    let child = spawn(Local, fn() = someWork());
    monitor(child, Died);
    receive {
        Died(Down(reason = r)) -> // handle the child's exit
            ...
      | ...
    }
}
```

`monitor(child, Died)` says: "when the child dies, wrap a `Down` in `Died(_)` and put it in my mailbox." `Died` is a constructor from the parent's own message type, which is why `Died(Down)` is one of `ParentMsg`'s cases. The runtime turns the child's death into a message *you* defined.

### 8.1 `kill`

```
kill : (Address(a)) -> Void with m
```

`kill(addr)` terminates the process at `addr` immediately. Anyone monitoring that process receives `Down(reason = Killed, ...)`.

The REPL paper program combines `monitor` and `kill` in a supervised-child pattern: the parent spawns a child to evaluate an expression, monitors it, and either receives `Result(...)` or, after a timeout, calls `kill(child)` and gives up. Watching plus killing plus `after` is enough to build a "run this, but abort if it takes too long" primitive without any special language support.

### 8.2 No cascades

A fault in one process doesn't automatically bring down others. There are no links, no supervision trees baked into the language. Every process decides for itself what to do when a watched one dies. Ernest chose the explicit shape so death handling is visible in the code, not implicit in the setup.

## 9. Adapting messages with `via`

Here's a concrete puzzle. Suppose your process's mailbox speaks `GameMsg`, and you want the runtime's clock to nudge you every 100 milliseconds so that a `Tick` shows up in your `receive`. How do you set that up?

Look at the clock's request shape:

```
After(ms : Int, to : Address(Void))
```

"After `ms` milliseconds, send `Void` to `to`." The clock will send `Void` — the unit value — to whatever address you hand it. But your mailbox holds `GameMsg`, not `Void`. There's a shape mismatch, and neither side wants to change: the clock sends what it sends, your mailbox is what it is.

You could work around this by spawning a whole extra process that receives `Void` from the clock and forwards `Tick` to you. That works, but it's a lot of ceremony to translate one shape into another. Ernest has a much smaller tool for this: `via`.

### 9.1 What `via` does

`via` builds a *wrapper address*. You give it:

- a target address (some `Address(b)` — where the message should eventually land), and
- a converter function `(a) -> b` (how to translate the incoming shape into the target shape).

It returns a wrapper of type `Address(a)`. When anyone sends a value `v : a` to the wrapper, the runtime applies the converter and the result — an `a` turned into a `b` — lands in the target mailbox.

```
via : ((a) -> b, Address(b)) -> Address(a)
```

Two type variables: `a` is the shape the wrapper accepts from the outside; `b` is the shape the mailbox holds on the inside. `via` sits between them and translates.

### 9.2 The clock example, step by step

Applied to the clock problem:

```
send(Sys.clock, After(ms = 100, to = via(fn(_) = Tick, self())))
```

Read that from the inside out:

- `self()` is your process's own address. Its type is `Address(GameMsg)` because your mailbox speaks `GameMsg`.
- `fn(_) = Tick` is a lambda: takes any input, ignores it (`_`), returns `Tick`. Its type is `(a) -> GameMsg` for some `a`.
- `via(fn(_) = Tick, self())` builds the wrapper. Its type is `Address(Void)` — an address that accepts `Void`. Under the hood, when something sends `Void` to it, the wrapper calls `fn(_) = Tick`, and `Tick` lands in your `GameMsg` mailbox.
- The outer `After(ms = 100, to = ...)` hands that wrapper to the clock as the notification target.

100 milliseconds later, the clock sends `Void` to the wrapper. The wrapper turns it into `Tick`. Your mailbox receives `Tick`, and your `receive` clause matching on `Tick` fires.

The clock never learned about `Tick`. Your process never had to accept `Void`. `via` sat between them, translating each message as it passed.

### 9.3 A reply example

The pattern comes back whenever a service replies into a mailbox that speaks a different shape. The filesystem process in the `filesync` paper program takes a `reply` field:

```
List(path : Path, reply : Address(Either(FsError, List(Entry))))
```

`fs` sends the reply as an `Either(FsError, List(Entry))`. Your process's mailbox is `SyncMsg`, one of whose cases is `Listed(Either(FsError, List(Entry)))`. You want the reply wrapped as `Listed(...)` so it lands in your normal `receive`:

```
send(Sys.fs, List(path = dir, reply = via(Listed, self())))
```

Here `Listed` is being used as a function — a constructor with one field is itself a one-argument function from the field type to the constructed value. `via(Listed, self())` builds a wrapper the fs can reply to; the wrapper applies `Listed`; the result lands in your mailbox.

### 9.4 `monitor`'s `wrap` is a specific `via`

`monitor(child, wrap)` from §8 has a second argument of type `(Down) -> m`. That's the same shape as `via`'s converter — a function that turns an incoming value into your mailbox type. `monitor` is essentially `via` baked into an API that knows the incoming value is always a `Down`.

`via` is the general form. Any time another process is going to speak in a shape that isn't your mailbox type — the clock, the fs, a reply from a foreign service — this is the primitive that closes the gap without a translator process in the middle.

## 10. Chaining with `<-`

Consider a function that parses two numbers from a string and adds them. Each parse can fail; failure returns `None`.

Written with nested `match`:

```
fn parseAndAdd(a : String, b : String) -> Optional(Int) =
    match String.toInt(a) {
        None -> None
      | Some(x) -> match String.toInt(b) {
            None -> None
          | Some(y) -> Some(x + y)
        }
    }
```

Each `None` case just propagates. The nested `match` grows a diagonal for every step. Half the code says nothing.

Ernest gives you `<-`, a special binding form that reads short-circuit-on-failure:

```
fn parseAndAdd(a : String, b : String) -> Optional(Int) = {
    let x <- String.toInt(a);
    let y <- String.toInt(b);
    Some(x + y)
}
```

Read it left-to-right:

- `let x <- String.toInt(a)`: if the right-hand side is `Some(v)`, bind `x` to `v` and continue. If it is `None`, the whole block evaluates to `None`; nothing after this line runs.
- Same for `y`.
- Reach the last line — `Some(x + y)` — which is what the block returns.

`<-` also works with `Either`. On `Left(e)` it short-circuits to `Left(e)`; on `Right(v)` it binds `v` and continues.

```
fn parse(toks : List(Token)) -> Either(ParseError, Expr) = {
    let (e, rest) <- expr(toks);
    match rest {
        [] -> Right(e)
      | t :: _ -> Left(Unexpected(t))
    }
}
```

The compiler picks Optional or Either from the right-hand side's type. You don't have to say which — one form covers both.

`<-` isn't a general escape or exception. It is specifically for `Optional` and `Either`, the two prelude types where "no value" or "error" is an expected branch that should propagate without ceremony. Anything else you handle with `match`.

## 11. Remote computation

So far every function has run in the process that called it. When you have peers — other machines running Ernest — you can hand off a pure computation to run on one of them.

```
remote : (() -> a) -> Either(RemoteError, a)
```

Give it a pure, zero-argument function. The runtime picks a peer and evaluates the function there, returning `Right(value)` on success or `Left(err)` if no peer is available or the peer is lost.

```
fn main() -> Void with m = {
    match remote(fn() = heavy(1, 2, 3)) {
        Right(n) -> Io.println("got " <> Int.toString(n))
      | Left(_) -> Io.println("no remote available")
    }
}
```

Two things to notice:

- **`remote` has a mailbox effect.** Its type is `(() -> a) -> Either(RemoteError, a) with m` — call it from process code, not from a pure function. The `Left(...)` cases expose runtime state (peer configuration, network) and that observability is what the `with m` captures.
- **The function passed in must be pure.** It runs on a peer that has never seen your process; there is no way for it to send or receive messages back to you. The argument type `() -> a` — no `with M` — enforces this.

Peers are configured in `ernest.conf` at start-up. Which peer runs which computation, and by what criterion, the language does not say — that is the runtime's choice.

### 11.1 Parallel remote

For a batch of independent computations:

```
parallelRemote : (List(() -> a)) -> List(Either(RemoteError, a)) with m
```

Runs the functions in parallel across peers and returns the results in input order — one `Either` per input.

```
fn main() -> Void with m = {
    let jobs = [fn() = crunch(1), fn() = crunch(2), fn() = crunch(3)];
    let results = parallelRemote(jobs);
    List.foreach(results, fn(r) = match r {
        Right(n) -> Io.println("ok: " <> Int.toString(n))
      | Left(_) -> Io.println("failed")
    })
}
```

Also pure. Each input succeeds or fails on its own, so one peer's loss doesn't take the whole batch with it.

### 11.2 A different distribution: `spawn(Peer(name), ...)`

If you want a stateful *process* running on a specific peer rather than a pure computation on any peer, that is the other form of `spawn`:

```
spawn(Peer("worker-a"), fn() = counter(0))
```

Returns an `Address` you can `send` messages to, exactly like a local process. Two ways to reach across nodes, then: `remote`/`parallelRemote` for pure computation the runtime places, and `spawn(Peer(name), ...)` for a process at a named location. They serve different purposes and the language keeps them distinct.

## 12. Foreign types and functions

Ernest runs on BEAM, the Erlang runtime. Sometimes you want to call code that lives in Erlang directly — an ETS table, a crypto library, a filesystem call, a JSON parser. `foreign type` and `foreign fn` are the boundary between Ernest code and everything else on the node.

### 12.1 Foreign types

`foreign type T` declares a type whose values are made and used only by foreign functions. There are no constructors and no way to inspect a value; you can hold it, pass it, and send it, but not look inside. From Ernest's side, a foreign value is a black box with a type.

```
foreign type Ets.Table(k, v)
```

The type may take parameters (`k`, `v` here). The parameters are meaningful to Ernest — the compiler uses them for type checking — but the Erlang implementation on the other side of the boundary is unaware of them. Given `Ets.insert(t, "a", 1)`, the compiler fixes `t : Ets.Table(String, Int)`; a call with different types on the next line is a type error before the code ever runs.

### 12.2 Foreign functions

`foreign fn` declares a function whose implementation is in the runtime, not in Ernest source. The body is a string reference to the implementation:

```
foreign fn Ets.member(t : Ets.Table(k, v), key : k) -> Bool with m = "ets:member/2"
```

The type is annotated in full — parameters, return, mailbox effect if any. A `foreign fn` with `with M` may do anything a normal process function can do. A pure `foreign fn` — no `with M` — is a stronger promise, described next.

### 12.3 The purity contract and its enforcement

Ernest treats the foreign boundary strictly. A `foreign fn` declaration is a *promise from the foreign side*: values of the declared shape come back, effects match the mailbox annotation, and a pure declaration means genuinely pure. The foreign side can break the promise three ways, and the runtime handles all three the same — the surprise becomes a `Fault`, not a silent misinterpretation:

- **Wrong type.** A `foreign fn` declared to return `Int` actually returns something else. The runtime raises a `Fault` at the call site rather than propagating a mistyped value into Ernest code.
- **Thrown exception.** Erlang code that throws or exits — the runtime catches and rewrites the escape into a `Fault` carrying the reason.
- **Wrong message shape.** A foreign process sends a value that doesn't match its declared mailbox type. The receiving process gets a `Fault` on the offending message.

Purity itself isn't verifiable — Ernest can't inspect an Erlang function to check for side effects. Purity is a declaration you make about foreign code, and code that lies about purity misleads its callers. Reserve `with M` for anything that touches the outside world; leave it off only when you're sure.

### 12.4 Node-local values

Foreign values are bound to the node that made them. Sending a foreign value across a node boundary is a fault at the boundary, with cause `Fault("foreign value cannot cross nodes")`:

```
let t = Ets.new(); // t lives on the current node
send(remoteAddr, Payload(t)) // fault: t cannot cross
```

The rule extends transitively. A closure that captures a foreign value counts as containing one, so `spawn` to a peer or `send` to a remote address is a fault even if the foreign value never appears in the message directly:

```
let t = Ets.new();
spawn(Peer("alice"), fn() = Ets.insert(t, "x", 1)) // fault: t is captured
```

The type system doesn't track "node-local" as a distinct kind — that would require a second type axis across the whole language, principle 5. The runtime enforces it at the boundary when it matters. Programs that need to share table-like state across nodes must serialize what the table holds (e.g. as a `List(#(k, v))`) and rebuild on the peer.

### 12.5 The shim pattern

A raw `foreign fn` gives you Erlang's return shape as-is. A shim is the Ernest-side wrapper that reshapes it into something Ernest reads naturally. Erlang's `ets:lookup(Table, Key)` returns a list — a list because the key might match zero or one entry:

```
fn Ets.lookup(t : Ets.Table(k, v), key : k) -> Optional(v) with m =
    match rawLookup(t, key) { [#(_, v)] -> Some(v) | _ -> None }

foreign fn rawLookup(t : Ets.Table(k, v), key : k)
    -> List(#(k, v)) with m = "ets:lookup/2"
```

The raw binding is unqualified (`rawLookup`) so it's file-local, invisible outside the module; the exported `Ets.lookup` is the typed API a caller uses. Argument reordering, `{ok, _} | {error, _}` becoming `Either`, discarding return values you don't care about, renaming to match Ernest's conventions — all of it happens in ordinary Ernest code layered over the raw `foreign fn` bindings. Erlang stays where it fits; Ernest speaks its own vocabulary at the API.

The `webserver` paper program shows the whole pattern: `Ets.ern` is a thin Ernest library over Erlang's `ets` module. Report Appendix D walks the file top-to-bottom as a reference implementation.

## 13. Bitstrings

Working with binary formats — network protocol headers, file signatures, checksums — means both **building** outgoing bytes and **parsing** incoming ones at the bit level. Ernest's syntax for this is `<<...>>`, used symmetrically for construction and pattern matching.

**Building** a length-prefixed frame:

```
fn frame(len : Int, body : Bytes) -> Bytes =
    <<len:size(16)-big, body:bytes>>
```

**Parsing** one back apart:

```
fn parseFrame(bytes : Bytes) -> Optional(#(Int, Bytes, Bytes)) = match bytes {
    <<len:size(16)-big, body:size(len)-bytes, rest:bytes>> -> Some(#(len, body, rest))
  | _ -> None
}
```

Same shape, different role. In an expression position, each segment names a value and how to lay it out; in a pattern position, each segment names a binder and the layout it must match. Segments are evaluated (or matched) left to right.

A bitstring is a comma-separated list of *segments* between `<<` and `>>`. Each segment is followed optionally by a colon and a dash-separated list of *specifiers* that describe the segment's shape.

### 13.1 Specifiers

- **`size(N)`** — the segment's width, in units.
- **`bits`**, **`bytes`** — the segment is a nested bitstring; `bytes` implies unit(8).
- **`int`**, **`float`** — numeric (default `int` is 8-bit, `float` is 64-bit).
- **`utf8`**, **`utf16`**, **`utf32`** — text encoding.
- **`big`**, **`little`**, **`native`** — endianness.
- **`signed`**, **`unsigned`** — sign.

Combine with `-`: `x:signed-big-size(16)` is a 16-bit signed big-endian integer. Specifier names carry that role only inside `<<...>>`. Outside a bitstring, `size` and `int` are just ordinary identifiers.

In construction, a segment whose value doesn't fit its specified width is a fault. In pattern matching, a segment whose layout doesn't match causes the clause to fail (the next clause is tried).

### 13.2 Size-dependent matches

The `parseFrame` example uses `size(len)` where `len` was bound by the preceding segment. This is what makes bitstring pattern matching powerful for wire protocols: match a length field, then use that length to consume the body that follows.

```
<<len:size(16)-big, body:size(len)-bytes, rest:bytes>>
```

The compiler tracks the dependency; segments must be laid out in the order the sizes are learned.

### 13.3 When to reach for bitstrings

Wire protocols, binary file formats, packet headers, checksums, extracting flag bits. For anything higher-level — plain text, structured data, records — the ordinary types (`String`, `List`, named-fields constructors) are more natural.

Bitstrings compile directly to BEAM's bit syntax, so the runtime's mature optimizer handles prefix-heavy protocol matches at native speed.

## 14. Toolchain and configuration

### 14.1 Commands

Two commands run the show: `ernc` compiles and `ern` runs.

**`ernc file.ern`** compiles one module to `file.erc`. Compilation is per-module; cross-module names resolve at load time.

**`ern [options] file.erc`** loads the compiled module, starts the runtime, binds addresses to the `Sys.*` top-level references (report §8.2), and calls `main()`. When `main` returns, all *local* processes are killed with cause `ProgramEnd` and the node stops; remotely spawned workers on peer nodes continue under their own runtime.

Common `ern` options:

- `-pa dir` — add a directory to the load path. The standard library is on the load path by default; use `-pa` to add your own compiled modules.
- `--config-dir dir` — where to look for `ernest.conf` and the node's private key. Defaults to `./.ernest/`.
- `--repl` — start a read-eval-print loop with the same loading rules.
- `--create-config-dir dir` — create `dir/.ernest/` with a freshly generated `ernest.conf` and private key, and exit.

`ernc --doc file.ern` extracts doc comments (`///`) from the module and writes them to stdout as Markdown, grouped by declaration.

### 14.2 `ernest.conf`

Peers, network addresses, and cryptographic identity are configured outside the language, in `ernest.conf`. It's a JSON file created by `ern --create-config-dir` and then edited by hand:

```json
{
  "network-address": "145.32.64.6:8654",
  "public-key": "<PEM public key>",
  "peers": [
    {
      "name": "foo",
      "network-address": "145.32.64.7:8654",
      "public-key": "<PEM public key>",
      "remote-peer": true
    }
  ]
}
```

- `network-address` and `public-key` — this node's identity. Peers authenticate each other with the configured keys.
- `peers` — the list of known peers. Each has a name (referenced by `Peer("foo")` in `spawn`, see §11.2), a network address, a public key, and a `remote-peer` flag.
- `remote-peer: true` — the peer accepts remote computation. `remote(f)` picks among peers flagged true.

The private key lives beside `ernest.conf` in the same directory, `private-key.pem`, readable only by the owner.

## 15. Common questions

Some things that trip readers up on first pass.

**Why is `main`'s mailbox type usually `Never`, not `Void`?**

`Never` is the type with no values — a mailbox of type `Never` cannot receive anything. Ernest uses it in `main`'s signature to say "this function only spawns and sends, it never `receive`s." That's a static guarantee visible in the type. `Void` (the one-value type) would technically compile but wouldn't carry the same information — it would say "the mailbox holds `Void` values, which are meaningless." If `main` did receive a real message type, `with SomeMsg` would replace `with Never`.

The submitter example in §6 of the report uses the same pattern for the same reason: send-only processes carry `with Never`.

**Why do lambdas need `fn(x) = ...`? Why can't I just write `x -> x + 1`?**

Because Ernest is n-ary — every function has a specific number of arguments, and that count is part of the type. `fn(x)` says "one argument"; `fn(x, y)` says "two." If Ernest let you write `x -> ...` and stack arrows for multiple arguments, the type of a two-argument function would look the same as the type of a one-argument function returning a function, and you'd have to look at the definition to tell them apart. Ernest keeps arity visible in the type.

**Why can `let Right(x) = e` be a type error?**

`Right(x)` is a *refutable* pattern — it might fail to match if `e` happens to be `Left(...)`. Function parameters and `let` bindings need patterns that *always* match, because there's no place to put the failure case. If you want to handle both `Right` and `Left`, use `match` or `<-` — both give the failure a home.

**Why is there no `import`?**

Every top-level declaration's *qualified name* is where it lives. A **module** is a single Ernest source file (ending in `.ern`) — the unit that carries a namespace. `fn Net.Http.parse(b) = ...` lives in the module `Net/Http.ern`, and any code anywhere refers to it by that full name. A module's path is its namespace. Unqualified names (`fn helper(x) = ...`) are visible only inside their own module. No `import`, no `pub`, no export list.

## 16. Reading further

Once "hello world," the counter, and ping-pong feel readable, the language's four paper programs are the next step. They're in the same repository:

- **[`ernest-tick-game.md`](ernest-tick-game.md)** — a snake game with tick-based updates. Introduces named-field records with `..` update syntax, folds over `Map`, one process per player.
- **[`ernest-repl.md`](ernest-repl.md)** — a small read-eval-print loop. Uses `<-` heavily (see §10) and combines `monitor` and `kill` (see §8) into a `try` process that aborts a slow evaluation.
- **[`ernest-filesync.md`](ernest-filesync.md)** — file synchronization between two nodes. Introduces mutual-address setup via a `Link` message, runtime references beyond `Sys.stdout` (a filesystem process at `Sys.fs`), one process per write.
- **[`ernest-webserver.md`](ernest-webserver.md)** — HTTP server with sessions in an ETS table. Introduces `foreign fn` for foreign function calls, abstract types with signatures.

Read them in that order. Each introduces something the next builds on.

For the language rules themselves, [`ernest.md`](ernest.md) (the report) is the authority. §0 states the five principles Ernest is built on; §3 covers types, §5 expressions, §6 processes, §9 the small prelude, and Appendix E the standard library (`Io.println`, `List.map`, and so on — the everyday helpers, written in Ernest, that ship with the compiler). Appendix F is a glossary of every technical term the report introduces, with a pointer to where it's defined. It's shorter than most language reports — under ten pages of prose — and each sentence carries weight. If you find yourself asking "why is Ernest like this?" — the principles in §0 usually answer it.

For "why is Ernest the way it is," [`ernest-decisions.md`](ernest-decisions.md) records dated design decisions and their evidence. If a rule seems arbitrary, that document explains what pressured it.

For "how the compiler works," [`ernest-implementation-plan.md`](ernest-implementation-plan.md) sketches the MVP 1 roadmap: about eight weeks of one-person work, with a hand-written parser.

That's it for the guide. Take your time with the paper programs, and if something looks wrong, it might really be wrong — bugs in the report or the examples have been found and fixed before, and can be again.
