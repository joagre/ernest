# Ernest: A Reading Guide

A guide for someone reading Ernest for the first time. Not the language report — the report `ernest.md` is where the rules live. This guide is meant to be read at a slow pace, one section at a time, with the code examples in front of you. Nothing is a summary; everything shows a concrete piece of Ernest and then talks about what it does.

## 0. Two ideas

Ernest is a functional language for concurrent programs. Two ideas run through it:

- **Functions** with types the compiler figures out for you.
- **Processes** with typed mailboxes, as the only way a program affects the world.

That's the whole vocabulary. Everything else in the language is a rule for how functions and processes show up in each other.

Take a moment on that. "Functions" you probably know. "Processes" means small independent units of computation, each with its own mailbox, each running concurrently with the rest. If that idea is new, don't worry — we'll build it up slowly.

## 1. A very small program

Here is a complete Ernest program. Let's not try to understand it all at once.

```
fn main(Sys(stdout = out) : Sys) -> () with () = {
    send(out, Line("hello, world"))
}
```

When Ernest runs this, it prints `hello, world` to standard output. Let's read it one piece at a time.

### `fn main`

`fn` starts a function definition. `main` is its name. `main` is special: it is the function Ernest calls when the program starts.

### The parameter

Inside the parens comes `main`'s one parameter:

```
Sys(stdout = out) : Sys
```

The parameter's type is `Sys`. That's the type the runtime hands to `main` when the program starts.

But we're not just naming the parameter (like `sys : Sys`). We're using a *pattern*: `Sys(stdout = out)`. This pattern says "this is a `Sys`, and I want to reach into it and pull out its `stdout` field, calling the result `out`."

What is `Sys`? A type the runtime supplies. It carries the "system processes" available to a program — things like `stdout` (which prints), `clock`, and possibly others depending on the runtime. Instead of scattering them as global variables, they arrive together in one `Sys` value, and the program picks out what it needs.

After this parameter is parsed, `main`'s body has one local variable in scope: `out`, the address of the stdout process.

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
= {
    send(out, Line("hello, world"))
}
```

The `=` marks the start of the body. What follows is a block — braces around a sequence of statements. This block has just one statement.

The statement is `send(out, Line("hello, world"))`. Let's take it apart.

`send` is a built-in function. It takes two arguments: an address, and a message to put in that address's mailbox. It returns immediately — `send` is fire-and-forget.

`out` is the address of the stdout process. We got it from the parameter pattern.

`Line("hello, world")` is the message. `Line` is a *constructor* from Ernest's prelude. It's defined as:

```
type Line = Line(Text)
```

That is: `Line` is a type with one constructor, also called `Line`, that wraps a single piece of `Text`. Constructing a `Line` value: `Line("hello, world")`. Simple as that.

Why wrap it? Because the stdout process's mailbox expects `Line` values, not raw `Text`. Wrapping is Ernest's way of saying "this text is meant to be printed as a line." If we later add a `Bytes` message type for binary output, stdout can handle both without confusion.

### The big idea

The most important thing to notice: **`out` is an address, not a stream.**

In most languages, you write to stdout by calling a function like `print` or a method like `stdout.write`. In Ernest, you *send a message* to a *process*. That process — running concurrently, elsewhere — receives the message and does the actual printing.

This is what "processes are the only way to affect the world" means. There is no hidden syscall inside Ernest. If you want to touch anything outside your own function, you send a message to a process that touches it for you.

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

There is one shape that comes up a lot: a type with just one constructor that wraps just one value.

```
type Line = Line(Text)
```

This is the `Line` we saw in the "hello world" program. `Line` (the type) is really "a `Text` with a label." No extra data, no alternatives — just a Text wearing a Line jacket.

Why do this? Two reasons. First, type safety: the compiler will not let you send a raw `Text` where a `Line` is expected. Second, meaning: `Line("hello")` reads as "a line to print," not just "some text."

Many prelude types are wrappers: `Line`, `Reply(a)` (which we'll meet later), and so on.

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
fn greet(out : Address(Line)) -> () with m = send(out, Line("hi"))
```

Same shape as `double`, but with two differences: the return arrow has `with m`, and the body calls `send`.

The `with m` at the end of the arrow marks: this function acts through the process it runs in. It doesn't just compute a value from its arguments; it produces observable effects (sending a message).

The `m` is lowercase — a *type variable*, like `a` in `Optional(a)`. It means: this function's mailbox type isn't fixed to a specific value; it works with any mailbox. `greet` sends a message but doesn't care what messages the enclosing process itself receives.

If a function receives messages (uses `recv`), its mailbox type is not free — it has to match the arm patterns. We'll see that soon.

Take a moment: **pure or process is a property of the function type, not of the syntax.** A reader glancing at a function type knows whether calling it can send messages, receive them, or fault. Nothing is hidden.

## 4. A process

Now the interesting part. Let's build a small process — a counter.

We'll do it in stages.

### 4.1 The message type

A counter is a process that holds a number and lets people ask it questions. What kinds of messages can it receive? Let's say two, for now:

- `Inc(k)` — please add `k` to my state.
- `Get(r)` — please tell me your current state, replying to address `r`.

We declare that as a type:

```
type CounterMsg
    = Inc(Int)
    | Get(reply : Reply(Int))
```

`Inc` carries an `Int` positionally. `Get` carries one named field — `reply` of type `Reply(Int)`.

`Reply(Int)` is a new type. It comes from Ernest's prelude. It represents "a one-shot address the receiver will send an `Int` back to." Think of it as a stamped return envelope: whoever gets it must fill it in exactly once with an `Int`, and only then does the caller get their answer.

`Reply(a)` is very different from `Address(a)`:

- `Address(a)` is a long-lived reference. You can send to it many times.
- `Reply(a)` is one-shot. Someone gave it to you *just to answer this one question*. When you answer, it's used up.

The compiler will check that every `Reply(a)` we receive gets answered exactly once. More on that when we see it in action.

### 4.2 The counter function

Now the counter itself.

```
fn counter(n : Int) -> () with CounterMsg = recv {
    Inc(k)          -> counter(n + k)
  | Get(reply = r)  -> { answer(r, n); counter(n) }
}
```

Read it slowly.

`fn counter(n : Int)` — a function taking the counter's current state as an integer parameter.

`-> ()` — returns nothing meaningful (unit).

`with CounterMsg` — runs in a process whose mailbox type is `CounterMsg`. That means this function can only run in a process that expects `CounterMsg` values.

`= recv { ... }` — the body is a `recv` expression. `recv` waits for a message and dispatches on it.

Two arms:

**Arm one:**

```
Inc(k) -> counter(n + k)
```

If the incoming message is `Inc(k)`, bind `k` to the integer inside, and recursively call `counter(n + k)`. That "recursively" is a tail call — Ernest guarantees tail-call optimization, so this doesn't grow the stack. The counter just keeps looping forever, each iteration remembering the new state as `n`.

**Arm two:**

```
Get(reply = r) -> { answer(r, n); counter(n) }
```

If the incoming message is `Get`, pull out its `reply` field into `r`. Then:

- `answer(r, n)` — send `n` back through the reply address. This "uses up" the reply capability.
- `counter(n)` — loop again, state unchanged.

The block `{ answer(r, n); counter(n) }` runs both in sequence, and the block's value is the value of the last statement (`counter(n)`, which returns unit). That's what the arm's body evaluates to.

`answer` is another prelude function. Its job is exactly this: consume a `Reply(a)` value by sending a specific `a` back to the caller.

### 4.3 The compiler checks the reply

The compiler enforces something you might miss on first read: **every `Reply(Int)` bound in a `recv` arm must be used exactly once, on every path.**

Look at the `Get` arm again: it binds `r` from the incoming message, then calls `answer(r, n)`. Good — used once.

If we had written this instead:

```
Get(reply = r) -> counter(n)     // forgot to answer!
```

That would be a type error. `r` would be bound but never used. The compiler would refuse to compile the counter.

That check catches a whole category of silent bugs: a caller that sends a request, waits for a reply that never comes, and eventually times out with no useful diagnostic. Ernest makes it impossible to write a receiver that forgets to answer — the type system remembers for you.

## 5. Running the counter

We have the counter *function*. Now we need to *run* it in a process, and send it some messages.

Here's `main` again, this time doing exactly that:

```
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

`++` is text concatenation. Both operands must be `Text`. Result is `Text`. So this expression is `"count is 8"`.

Then we wrap it: `Line("count is 8")`. And send it to stdout: `send(out, Line("count is 8"))`.

Take a moment. This is a complete Ernest program that uses two processes (main, plus the counter it spawned), passes messages between them, and prints the result. It's about twenty lines.

## 6. Two processes talking

The counter has main talking to it. Let's look at two processes talking to each other.

This is the ping-pong program from Appendix B of the report.

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

`ping` is the sender. Its parameters are `out`, the pong process's address, and a countdown `n`.

If `n` is `0`, send `Stop` and finish. Otherwise:

- Print `"ping <n>"`.
- Do `Address.call` on `pongAddr` with a `Ping` message. Wait up to 5 seconds.
- On success, recurse with `n - 1`.
- On timeout, print an error and tell pong to stop.

Notice `ping`'s return type: `-> () with m`. That `m` is lowercase — a type variable — meaning ping's mailbox type is *polymorphic*, unconstrained. Ping never `recv`s on its own mailbox. It only sends and uses `Address.call`. So the type checker leaves the mailbox slot free.

### 6.4 Main starts them

```
let pongAddr = spawn(Local, fn() = pong(out));
let _ = spawn(Local, fn() = ping(out, pongAddr, 3));
()
```

- Spawn pong first, get its address.
- Spawn ping, passing pong's address in.
- Discard ping's returned address with `let _ = ...`. `main` doesn't need it.
- Return `()`.

`main` returns. The two spawned processes are still running. When the last of them finishes, the program ends.

Output: alternating "ping 3", "pong 3", "ping 2", "pong 2", "ping 1", "pong 1".

## 7. Common questions

Some things that trip readers up on first pass.

**Why does `main` need `-> () with ()`? That's two `()` in a row.**

The first `()` is the return type — unit. The second `()` (after `with`) is the mailbox type — also unit. They're not repeating; they're two different pieces of information that both happen to be `()`. If `main`'s mailbox held `CounterMsg`, it would read `-> () with CounterMsg` — still unit return, different mailbox.

**Why do lambdas need `fn(x) = ...`? Why can't I just write `x -> x + 1`?**

Because Ernest is n-ary — every function has a specific number of arguments, and that count is part of the type. `fn(x)` says "one argument"; `fn(x, y)` says "two." If Ernest let you write `x -> ...` and stack arrows for multiple arguments, the type of a two-argument function would look the same as the type of a one-argument function returning a function, and you'd have to look at the definition to tell them apart. Ernest keeps arity visible in the type.

**Why can `let Right(x) = e` be a type error?**

`Right(x)` is a *refutable* pattern — it might fail to match if `e` happens to be `Left(...)`. Function parameters and `let` bindings need patterns that *always* match, because there's no place to put the failure case. If you want to handle both `Right` and `Left`, use `match` or `<-` — both give the failure a home.

**Why is there no `import`?**

Every top-level declaration's *qualified name* is where it lives. `fn Net.Http.parse(b) = ...` lives in the file `Net/Http.ern`, and any code anywhere refers to it by that full name. Files carry their namespace in their path. Unqualified names (`fn helper(x) = ...`) are file-local. No `import`, no `pub`, no export list.

**Why is the mailbox type in the function type?**

So you never have to guess. Look at any function type: `(A) -> B` is pure — no messages, no side effects. `(A) -> B with M` is process code — it uses `send`, `recv`, or `self`. Every function's type tells you at a glance whether it can affect the world; you never have to look inside.

## 8. Reference: the roles of parens

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

## 9. Reading further

Once "hello world," the counter, and ping-pong feel readable, the language's four paper programs are the next step. They're in the same repository:

- **`ernest-tick-game.md`** — a snake game with tick-based updates. Introduces named-field records with `..` update syntax, folds over `Map`, one process per player.
- **`ernest-repl.md`** — a small read-eval-print loop. Introduces `<-` for chaining `Either`, using `try` as a supervised child process, `monitor` for detecting child death.
- **`ernest-filesync.md`** — file synchronization between two nodes. Introduces mutual-address setup via a `Link` message, `Sys` passed as an explicit value, one process per write.
- **`ernest-webserver.md`** — HTTP server with sessions in an ETS table. Introduces `foreign fn` for foreign function calls, opaque types with signatures.

Read them in that order. Each introduces something the next builds on.

For the language rules themselves, `ernest.md` (the report) is the authority. Its Section 3 covers types, Section 5 covers expressions, Section 6 covers processes, Section 9 lists every prelude function. It's shorter than most language reports — under ten pages of prose — and each sentence carries weight.

For "why is Ernest the way it is," `ernest-decisions.md` records dated design decisions and their evidence. If a rule seems arbitrary, that document explains what pressured it.

For "how the compiler works," `ernest-implementation-plan.md` sketches the MVP 1 roadmap: about eight weeks of one-person work, with a hand-written parser.

## 10. The seven principles, once

Ernest is built on seven principles, in order. They're in the report's Section 0. Almost every design decision comes back to one or two of them.

1. **Least surprise decides, measured in code, not in the rule.**
2. **No variants, unless what remains surprises more.**
3. **Nothing invisible: control flow, communication, and failure are visible in the code or in the type.**
4. **Orthogonal: concepts do not affect one another.**
5. **Simple to parse: the grammar is LL(1), every construct is decided by its first token, and each bracket has one role.**
6. **Few reserved words, but not too few.**
7. **Small: concepts are counted, not primitives.**

If you find yourself asking "why is Ernest like this?" — trace back to one of these. Usually one or two suffice.

That's it for the guide. Take your time with the paper programs, and if something looks wrong, it might really be wrong — bugs in the report or the examples have been found and fixed before, and can be again.
