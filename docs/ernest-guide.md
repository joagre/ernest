# Ernest: A Reading Guide

A guide for someone reading Ernest for the first time. Not the language report — the report `ernest.md` is where the rules live. This guide is meant to be read at a slow pace, one section at a time, with the code examples in front of you. Nothing is a summary; everything shows a concrete piece of Ernest and then talks about what it does.

## 0. Two ideas

Ernest is a functional language for concurrent programs. Two ideas run through it:

- **Functions** with types the compiler figures out for you.
- **Processes** with typed mailboxes, as the only way a program affects the world.

That's the whole vocabulary. Everything else in the language is a rule for how functions and processes show up in each other.

Take a moment on that. "Functions" you probably know. "Processes" means small independent units of computation, each with its own mailbox, each running concurrently with the rest. If that idea is new, don't worry — we'll build it up slowly.

## 1. A very small program

Here is a complete Ernest program.

```
fn main() -> () with () = Io.println("hello, world")
```

When Ernest runs this, it prints `hello, world` followed by a newline to standard output. Let's read it one piece at a time.

### `fn main`

`fn` starts a function definition. `main` is its name. `main` is special: it is the function Ernest calls when the program starts.

### No parameters

Inside the parens: nothing. `main` takes no arguments.

### The return annotation

Now the arrow:

```
-> () with ()
```

Two things. The first `()` is the return type. The second `()`, after `with`, is the mailbox type.

`()` is a type — pronounced "unit." It has exactly one value, also written `()`. It's Ernest's way of saying "no interesting information here." When a function returns `()`, it means "the function did its work, no result to hand back."

Every function in Ernest runs inside a process, and every process has a mailbox. That mailbox has a type — the type of messages it can receive. The `with M` at the end of a function's arrow says "this function acts through the process it runs in, whose mailbox type is `M`."

`main`'s mailbox type is `()`. Nothing meaningful goes into it. That's normal — most `main` functions never receive messages themselves; they spawn children who do.

Read the whole arrow like this: "returns nothing meaningful, running in a process with an uninteresting mailbox."

### The body

```
= Io.println("hello, world")
```

The `=` marks the start of the body. Here the body is a single expression — a call to `Io.println`, a function from the standard library that writes text to standard output followed by a newline. `Io` is a namespace from the standard library (Appendix E of the report lists them all). Bodies with more than one statement need braces; single-expression bodies like this one don't.

### The big idea

Ernest has no built-in "print." What `Io.println` does is send its argument as a message to a small stdout process the runtime provides. That process receives the text and writes it out.

You do not "print" or "write" in Ernest. You send a message to a process. That process — running concurrently, elsewhere — receives the message and does the actual writing. There is no hidden syscall. If you want to touch anything outside your own function, you send a message to a process that touches it for you.

Take a breath. This idea is going to keep coming back. Everything else in Ernest builds on it.

## 2. Types

Programs need to describe the shape of the data they work with. Ernest lets you declare types with named cases.

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
  | East  -> West
  | West  -> East
}
```

`match` looks at `d` and picks the arm whose pattern matches. Each arm is a case: a pattern on the left of `->`, an expression on the right. The first arm whose pattern matches gets its expression evaluated, and the whole `match` expression takes that value.

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
- `Some("hello")` is a value of type `Optional(Text)`.
- `None` is a value of type `Optional(a)` for any `a` — since `None` doesn't carry anything, `a` is free to be whatever.

`Optional` shows up whenever a function might not have a value to give you — like looking up a key in a map, or parsing a number.

### 2.2 Constructors with named fields

Sometimes a constructor carries several things, and each one deserves a name. Ernest lets you say:

```
type Person = Person(name : Text, age : Int)
```

One constructor, `Person`, with two named fields: `name` of type `Text`, and `age` of type `Int`.

To make one:

```
Person(name = "Alice", age = 30)
```

Notice the difference between the type declaration and the value:

- **Declaration**: `Person(name : Text, age : Int)`. Colons mark field types.
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
fn greet() -> () with m = Io.println("hi")
```

Same shape as `double`, but with two differences: the return arrow has `with m`, and the body calls `Io.println`, which internally sends a message.

The `with m` at the end of the arrow marks: this function acts through the process it runs in. It doesn't just compute a value from its arguments; it produces observable effects (sending a message).

The `m` is lowercase — a *type variable*, like `a` in `Optional(a)`. It means: this function's mailbox type isn't fixed to a specific value; it works with any mailbox. `greet` sends a message but doesn't care what messages the enclosing process itself receives — the enclosing process is what will run this call and pay the mailbox cost.

If a function receives messages (uses `recv`), its mailbox type is not free — it has to match the arm patterns. We'll see that soon.

Take a moment: **pure or process is a property of the function type, not of the syntax.** A reader glancing at a function type knows whether calling it can send messages, receive them, or fault. Nothing is hidden.

### 3.3 Type inference

Every function example you have seen so far has type annotations on its parameters and return. In truth those are optional. Ernest has Hindley-Milner type inference — the compiler figures out types from how you use values.

```
fn double(n) = n * 2
```

That's a legal Ernest function. The compiler sees `n * 2`, notes that `*` is defined on `Int`, and concludes `n : Int` and the result is `Int`. The inferred type is `(Int) -> Int`, exactly as if you had written it out.

In practice you'll still annotate top-level functions, because a signature at the top of a definition is what a reader looks at first. But local `let` bindings, lambdas, and small helpers can skip annotations without loss.

Inference is also what picks specific types for the type variables you saw earlier — the `a` in `Optional(a)`, the `m` in `with m`. At each call site the compiler works out what those stand for from the arguments passed in.

## 4. A process

Now the interesting part. Let's build a small process — a counter.

We'll build it in stages: first a counter that only accepts updates (fire-and-forget), then extend it so callers can also ask for its current state (request-reply).

### 4.1 The message type

A counter is a process that holds a number. To start, let's say it accepts one kind of message: "please add `k` to my state."

We declare that as a type:

```
type CounterMsg = Inc(Int)
```

One constructor, `Inc`, carrying an `Int` positionally. This is a *mailbox type* — the set of message shapes a process can receive.

### 4.2 The counter function

Now the counter itself.

```
fn counter(n : Int) -> () with CounterMsg = recv {
    Inc(k) -> counter(n + k)
}
```

Read it slowly.

`fn counter(n : Int)` — a function taking the counter's current state as an integer parameter.

`-> ()` — returns nothing meaningful (unit).

`with CounterMsg` — runs in a process whose mailbox type is `CounterMsg`. That means this function can only run in a process that expects `CounterMsg` values.

`= recv { ... }` — the body is a `recv` expression. `recv` waits for a message and dispatches on it.

One arm:

```
Inc(k) -> counter(n + k)
```

If the incoming message is `Inc(k)`, bind `k` to the integer inside, and recursively call `counter(n + k)`. That "recursively" is a tail call — Ernest guarantees tail-call optimization, so this doesn't grow the stack. The counter just keeps looping forever, each iteration remembering the new state as `n`.

This is Ernest's **fire-and-forget** shape: a sender calls `send(c, Inc(5))`, which returns immediately, and there is no callback path back. The counter processes the message eventually — soon, but with no ordering guarantee against the sender's next statement other than "the counter's mailbox sees my messages in the order I sent them."

### 4.3 Asking questions: `Reply`

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

The extended counter grows a second `recv` arm:

```
fn counter(n : Int) -> () with CounterMsg = recv {
    Inc(k)         -> counter(n + k)
  | Get(reply = r) -> { answer(r, n); counter(n) }
}
```

The `Get` arm binds the `Reply(Int)` field to `r`, then:

- `answer(r, n)` — sends `n` back through the reply address. This "uses up" the reply capability.
- `counter(n)` — loop again, state unchanged.

The block `{ answer(r, n); counter(n) }` runs both in sequence, and the block's value is the value of the last statement (`counter(n)`, which returns unit). That's what the arm's body evaluates to.

`answer` is another prelude function. Its job is exactly this: consume a `Reply(a)` value by sending a specific `a` back to the caller.

### 4.4 The compiler checks the reply

The compiler enforces something you might miss on first read: **every `Reply(Int)` bound in a `recv` arm must be used exactly once, on every path.**

Look at the `Get` arm again: it binds `r` from the incoming message, then calls `answer(r, n)`. Good — used once.

If we had written this instead:

```
Get(reply = r) -> counter(n)     // forgot to answer!
```

That would be a type error. `r` would be bound but never used. The compiler would refuse to compile the counter.

That check catches a whole category of silent bugs: a caller that sends a request, waits for a reply that never comes, and eventually times out with no useful diagnostic. Ernest makes it impossible to write a receiver that forgets to answer — the type system remembers for you.

The consumption doesn't have to be direct or in the same arm. There are three legal forms:

1. **`answer(r, v)` directly** — what the counter does.
2. **Delegating** — passing `r` as a field of another message. Whoever receives that message is now responsible for answering.
3. **Spawning** — capturing `r` in a lambda passed to `spawn` (§5). A child process runs later and calls `answer` when it's ready.

The exactly-once check follows `r` through all three. In the spawning case, the compiler checks the *child's* body for exactly-once consumption — a spawned child whose body forgets to answer is a type error. The `filesync` paper program uses this form: an incoming write request is handed to a `writer` process that performs the file I/O in the background and calls `answer` when it finishes, so the process handling `recv` doesn't block on disk.

## 5. Running the counter

We have the counter *function*. Now we need to *run* it in a process, and send it some messages.

Here's `main` again, this time doing exactly that:

```
fn main() -> () with () = {
    let c = spawn(Local, fn() = counter(0));
    send(c, Inc(5));
    send(c, Inc(3));
    match Address.call(c, fn(r) = Get(reply = r), 1000) {
        Some(n) -> Io.println("count is " ++ Int.toText(n))
      | None    -> Io.println("counter is not answering")
    }
}
```

If you want to send to a different address (a logger, a capture buffer for testing) instead of stdout, `Io.printlnTo(addr, "hi")` takes an explicit `Address(Text)`.

Four things happen. Let's walk through them.

### 5.1 Spawn

```
let c = spawn(Local, fn() = counter(0));
```

`spawn` starts a new process. It takes two arguments:

- `Local` — where to run the new process. `Local` means "on this same node." There's also `Peer("some-name")` for remote spawning, which we won't cover here.
- `fn() = counter(0)` — a function of no arguments. When the new process starts, this is what it runs.

Result: an *address* to the new process, bound to `c`. Its type is `Address(CounterMsg)` — you can send `CounterMsg` values to it.

Notice: `fn() = counter(0)` is a lambda. It looks like an ordinary function declaration but without a name. Its body just calls `counter(0)`. When the process starts, this lambda runs, which calls `counter`, which enters the `recv` loop.

### 5.2 Send

```
send(c, Inc(5));
send(c, Inc(3));
```

Two calls to `send`, each putting one message in the counter's mailbox.

`send` is fire-and-forget. It returns immediately (with unit `()`), whether or not the counter has processed the previous message yet. The messages queue up in the mailbox in the order sent, and the counter handles them in that same order.

By the time both `send`s return, the counter has probably not yet finished processing them — but that's fine. Its `recv` loop will get to them soon enough.

### 5.3 Address.call

Now for the interesting part:

```
match Address.call(c, fn(r) = Get(reply = r), 1000) {
    Some(n) -> ...
  | None    -> ...
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

### 5.4 Text concatenation

One small thing in the success case:

```
"count is " ++ Int.toText(n)
```

`Int.toText` converts an integer to its text representation. `"8"`, in this case.

`++` is text concatenation. Both operands must be `Text`. Result is `Text`. So this expression is `"count is 8"`. `Io.println` then sends that to stdout with a newline appended.

Take a moment. This is a complete Ernest program that uses two processes (main, plus the counter it spawned), passes messages between them, and prints the result. It's about twenty lines.

## 6. Two processes talking

The counter has main talking to it. Let's look at two processes talking to each other.

This is the ping-pong program from Appendix B of the report.

```
type PongMsg = Ping(n : Int, reply : Reply(Int)) | Stop

fn pong() -> () with PongMsg = recv {
    Ping(n = n, reply = r) -> {
        Io.println("pong " ++ Int.toText(n));
        answer(r, n);
        pong()
    }
  | Stop -> ()
}

fn ping(pongAddr : Address(PongMsg), n : Int) -> () with m =
    if n == 0 then send(pongAddr, Stop)
    else {
        Io.println("ping " ++ Int.toText(n));
        match Address.call(pongAddr, fn(r) = Ping(n = n, reply = r), 5000) {
            Some(_) -> ping(pongAddr, n - 1)
          | None    -> { Io.println("pong is not answering"); send(pongAddr, Stop) }
        }
    }

fn main() -> () with () = {
    let pongAddr = spawn(Local, fn() = pong());
    let _ = spawn(Local, fn() = ping(pongAddr, 3));
    ()
}
```

Same building blocks as the counter, but arranged for two processes.

### 6.1 The message type

`PongMsg` has two constructors:

- `Ping(n : Int, reply : Reply(Int))` — "ping me with this number and answer with an int."
- `Stop` — "please shut down."

### 6.2 The pong process

`pong` is the receiver. Its mailbox type is `PongMsg`. Its `recv` has two arms:

- On `Ping`, print `"pong <n>"`, answer the reply with `n`, then loop.
- On `Stop`, return (which ends the process — its function has finished).

### 6.3 The ping process

`ping` is the sender. Its parameters are the pong process's address and a countdown `n`.

If `n` is `0`, send `Stop` and finish. Otherwise:

- Print `"ping <n>"`.
- Do `Address.call` on `pongAddr` with a `Ping` message. Wait up to 5 seconds.
- On success, recurse with `n - 1`.
- On timeout, print an error and tell pong to stop.

Notice `ping`'s return type: `-> () with m`. That `m` is lowercase — a type variable — meaning ping's mailbox type is *polymorphic*, unconstrained. Ping never `recv`s on its own mailbox. It only sends and uses `Address.call`. So the type checker leaves the mailbox slot free.

### 6.4 Main starts them

```
let pongAddr = spawn(Local, fn() = pong());
let _ = spawn(Local, fn() = ping(pongAddr, 3));
()
```

- Spawn pong first, get its address.
- Spawn ping, passing pong's address in.
- Discard ping's returned address with `let _ = ...`. `main` doesn't need it.
- Return `()`.

`main` returns. The two spawned processes are still running. When the last of them finishes, the program ends.

Output: alternating "ping 3", "pong 3", "ping 2", "pong 2", "ping 1", "pong 1".

## 7. Chaining with `<-`

Consider a function that parses two numbers from text and adds them. Each parse can fail; failure returns `None`.

Written with nested `match`:

```
fn parseAndAdd(a : Text, b : Text) -> Optional(Int) =
    match Text.toInt(a) {
        None -> None
      | Some(x) -> match Text.toInt(b) {
            None -> None
          | Some(y) -> Some(x + y)
        }
    }
```

Each `None` case just propagates. The nested `match` grows a diagonal for every step. Half the code says nothing.

Ernest gives you `<-`, a special binding form that reads short-circuit-on-failure:

```
fn parseAndAdd(a : Text, b : Text) -> Optional(Int) = {
    let x <- Text.toInt(a);
    let y <- Text.toInt(b);
    Some(x + y)
}
```

Read it left-to-right:

- `let x <- Text.toInt(a)`: if the right-hand side is `Some(v)`, bind `x` to `v` and continue. If it is `None`, the whole block evaluates to `None`; nothing after this line runs.
- Same for `y`.
- Reach the last line — `Some(x + y)` — which is what the block returns.

`<-` also works with `Either`. On `Left(e)` it short-circuits to `Left(e)`; on `Right(v)` it binds `v` and continues.

```
fn parse(toks : List(Token)) -> Either(ParseError, Expr) = {
    let (e, rest) <- expr(toks);
    match rest {
        [] -> Right(e)
      | t +: _ -> Left(Unexpected(t))
    }
}
```

The compiler picks Optional or Either from the right-hand side's type. You don't have to say which — one form covers both.

`<-` isn't a general escape or exception. It is specifically for `Optional` and `Either`, the two prelude types where "no value" or "error" is an expected branch that should propagate without ceremony. Anything else you handle with `match`.

## 8. Common questions

Some things that trip readers up on first pass.

**Why does `main` need `-> () with ()`? That's two `()` in a row.**

The first `()` is the return type — unit. The second `()` (after `with`) is the mailbox type — also unit. They're not repeating; they're two different pieces of information that both happen to be `()`. If `main`'s mailbox held `CounterMsg`, it would read `-> () with CounterMsg` — still unit return, different mailbox.

**Why do lambdas need `fn(x) = ...`? Why can't I just write `x -> x + 1`?**

Because Ernest is n-ary — every function has a specific number of arguments, and that count is part of the type. `fn(x)` says "one argument"; `fn(x, y)` says "two." If Ernest let you write `x -> ...` and stack arrows for multiple arguments, the type of a two-argument function would look the same as the type of a one-argument function returning a function, and you'd have to look at the definition to tell them apart. Ernest keeps arity visible in the type.

**Why can `let Right(x) = e` be a type error?**

`Right(x)` is a *refutable* pattern — it might fail to match if `e` happens to be `Left(...)`. Function parameters and `let` bindings need patterns that *always* match, because there's no place to put the failure case. If you want to handle both `Right` and `Left`, use `match` or `<-` — both give the failure a home.

**Why is there no `import`?**

Every top-level declaration's *qualified name* is where it lives. A **module** is a single Ernest source file (ending in `.ern`) — the unit that carries a namespace. `fn Net.Http.parse(b) = ...` lives in the module `Net/Http.ern`, and any code anywhere refers to it by that full name. A module's path is its namespace. Unqualified names (`fn helper(x) = ...`) are visible only inside their own module. No `import`, no `pub`, no export list.

**Why is the mailbox type in the function type?**

So you never have to guess. Look at any function type: `(A) -> B` is pure — no messages, no side effects. `(A) -> B with M` is process code — it uses `send`, `recv`, or `self`. Every function's type tells you at a glance whether it can affect the world; you never have to look inside.

## 9. Reference: the roles of parens

By now you have seen `(...)` in many places. Once you have read a few programs, this feels natural. But here it is as a lookup table:

Given `Foo(...)`, what does the `(...)` mean? Three things decide:

- **Where you are** — type position, expression position, pattern position.
- **`Foo`'s case** — uppercase (typename or constructor) vs lowercase (variable or function).
- **The first identifier inside the parens, followed by** — `:` (field declaration), `=` (named field), or neither (positional).

The six roles:

1. **Type application** (in type position, uppercase): `List(Int)`, `Address(CounterMsg)`.
2. **Type parameter declaration** (in `type` declaration): `type List(a) = ...`.
3. **Function or constructor call** (in expression position): `f(x)`, `Some(5)`.
4. **Field declaration** (in `type` declaration, `:` after ident): `type Peer = Peer(dir : Path)`.
5. **Named field** (in expression or pattern, `=` after ident): `Peer(dir = d)`.
6. **Function type argument list** (in type position): `(A, B) -> C`.

Plus tuples: `(A, B)` as a type, `(1, "hi")` as a value, `(x, y)` as a pattern.

This is a lot, but you rarely have to consciously disambiguate. The context tells you.

## 10. Syntactic quirks, once

A short reference of syntactic patterns that don't come from other languages, or that could surprise a reader coming from most languages.

**Two positional fields are forbidden.** A constructor may carry zero fields, one positional field, or any number of *named* fields, but exactly two positional fields is a type error.

```
type Pair = Pair(Int, Int)               // rejected
type Pair = Pair(x : Int, y : Int)       // required
type Pair = Pair((Int, Int))             // single positional payload, a tuple, allowed
```

Reason: positions carry no meaning; names do. A constructor with two things in it wants to say which is which.

**`:` in declarations, `=` in construction.** Two different punctuation marks with strict roles.

```
type Peer = Peer(dir : Path, seen : Map(Path, Mtime))   // :  declares field types
Peer(dir = ".", seen = Map.empty)                       // =  binds field values
```

Same in function definitions and calls: `fn f(x : Int) = ...` and `f(3)`. Colons introduce types, equals bind values.

**`+:` for list cons.** Prepend one element to a list. Works in expressions and in patterns.

```
let xs = 1 +: [2, 3]        // xs is [1, 2, 3]

match ys {
    [] -> "empty"
  | head +: rest -> "head is " ++ Int.toText(head)
}
```

Right-associative: `a +: b +: c` is `a +: (b +: c)`. There is no in-line operator for appending two lists; use `List.append`.

**`..` for record update.** Given a record value, produce a new one with some fields replaced. The old fields are copied.

```
Player(..p, dir = North)                    // copy of p with dir changed
Player(..p, alive = false, score = 0)       // multiple field changes at once
```

**`-` is prefix negation and binary subtraction.** Both roles on the same token, decided by position. Literal `-1` is `-` applied to `1`; there is no negative literal.

**Whitespace and newlines are inert.** Ernest is not layout-sensitive. Statements in a block are separated by `;`, arms of `match` and `recv` by `|`, and that's the whole of the structural punctuation.

**`{}` has two role families.** Blocks separate statements with `;` (`{ let x = 1; x + 1 }`); `match` and `recv` arm containers separate arms with `|` (`match e { pat -> expr | pat -> expr }`). Two families, two internal delimiters, decided by what appears after the opening brace.

**Sixteen reserved words:** `type`, `opaque`, `with`, `match`, `when`, `if`, `then`, `else`, `recv`, `after`, `fn`, `let`, `foreign`, `as`, `true`, `false`. Everything else — `send`, `spawn`, `self`, `remote`, `Sys`, `Io`, `List`, and the rest — is an ordinary name.

**Doc comments start with `///`.** Three slashes to end of line; the toolchain (`ernc --doc`) extracts them to Markdown grouped by declaration.

## 11. Remote computation

So far every function has run in the process that called it. When you have peers — other machines running Ernest — you can hand off a pure computation to run on one of them.

```
remote : (() -> a) -> Either(RemoteError, a)
```

Give it a pure, zero-argument function. The runtime picks a peer and evaluates the function there, returning `Right(value)` on success or `Left(err)` if no peer is available or the peer is lost.

```
fn main() -> () with () = {
    match remote(fn() = heavy(1, 2, 3)) {
        Right(n) -> Io.println("got " ++ Int.toText(n))
      | Left(_)  -> Io.println("no remote available")
    }
}
```

Two things to notice:

- **`remote` is pure.** No `with M` on its type. You can call it from pure functions. From the caller's perspective, `remote(f)` is a slow function call that might fail — nothing about processes or mailboxes is involved.
- **The function passed in must be pure.** It runs on a peer that has never seen your process; there is no way for it to send or receive messages back to you. The argument type `() -> a` — no `with M` — enforces this.

Peers are configured in `ernest.conf` at start-up. Which peer runs which computation, and by what criterion, the language does not say — that is the runtime's choice.

### 11.1 Parallel remote

For a batch of independent computations:

```
parallelRemote : (List(() -> a)) -> List(Either(RemoteError, a))
```

Runs the functions in parallel across peers and returns the results in input order — one `Either` per input.

```
fn main() -> () with () = {
    let jobs = [fn() = crunch(1), fn() = crunch(2), fn() = crunch(3)];
    let results = parallelRemote(jobs);
    List.foreach(results, fn(r) = match r {
        Right(n) -> Io.println("ok: " ++ Int.toText(n))
      | Left(_)  -> Io.println("failed")
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

## 12. Reading further

Once "hello world," the counter, and ping-pong feel readable, the language's four paper programs are the next step. They're in the same repository:

- **`ernest-tick-game.md`** — a snake game with tick-based updates. Introduces named-field records with `..` update syntax, folds over `Map`, one process per player.
- **`ernest-repl.md`** — a small read-eval-print loop. Uses `<-` heavily (see §7 above) and introduces `try` as a supervised child process, `monitor` for detecting child death.
- **`ernest-filesync.md`** — file synchronization between two nodes. Introduces mutual-address setup via a `Link` message, ambient runtime references beyond `Sys.stdout` (a filesystem process at `Sys.fs`), one process per write.
- **`ernest-webserver.md`** — HTTP server with sessions in an ETS table. Introduces `foreign fn` for foreign function calls, opaque types with signatures.

Read them in that order. Each introduces something the next builds on.

For the language rules themselves, `ernest.md` (the report) is the authority. Its Section 3 covers types, Section 5 covers expressions, Section 6 covers processes, Section 9 lists the small prelude, and Appendix E documents the standard library (`Io.println`, `List.map`, and so on — the everyday helpers, written in Ernest, that ship with the compiler). It's shorter than most language reports — under ten pages of prose — and each sentence carries weight.

For "why is Ernest the way it is," `ernest-decisions.md` records dated design decisions and their evidence. If a rule seems arbitrary, that document explains what pressured it.

For "how the compiler works," `ernest-implementation-plan.md` sketches the MVP 1 roadmap: about eight weeks of one-person work, with a hand-written parser.

## 13. The five principles, once

Ernest is built on five principles, in order. They're in the report's Section 0. Almost every design decision comes back to one or two of them.

1. **Least surprise decides — measured by the resulting code, not by the rule.**
2. **One way, one job — in the language and prelude. No variants for the same thing, no two concepts that overlap in what they express, unless what remains surprises more. The standard library, being ordinary Ernest code, may pair functions for convenience.**
3. **Nothing invisible. Control flow, communication, and failure are visible in the code or in the type. An ambient value is visible when its name appears at the use site; a hidden effect is not.**
4. **Simple to parse: recursive descent, first-token dispatch, small bounded lookahead where the grammar demands it, no backtracking.**
5. **Small: few concepts, few primitives, few reserved words — but not too few.**

If you find yourself asking "why is Ernest like this?" — trace back to one of these. Usually one or two suffice.

That's it for the guide. Take your time with the paper programs, and if something looks wrong, it might really be wrong — bugs in the report or the examples have been found and fixed before, and can be again.
