# Ernest: A Reading Guide

A crash course for a programmer who wants to read Ernest and predict what a fragment does. It is not the language report — [`ernest_report.md`](ernest_report.md) is where the rules live. This guide surveys the central mechanisms with runnable checkpoints; where a rule has subtlety, it points into the report.

## 0. Orientation

Ernest is a functional language for concurrent programs. Two organizing ideas run through it:

- **Functions** with Hindley-Milner types the compiler figures out for you.
- **Processes** with typed mailboxes, as the language's way to affect the world.

Everything else is a rule for how functions and processes appear in each other's code.

The guide is arranged as seven stages: run a program, compute with values, pass behavior, run a protocol, manage process lifetime, organize code, cross boundaries. A complete runnable program appears at selected checkpoints (hello, the counter, the module example, the remote example). The complete programs are collected as files under [`examples/`](examples/); §9 says which of them the toolchain runs today. Other snippets are illustrative fragments — assembling them into files is left to the reader. Each stage ends with a short prediction exercise. Read the stages in order; each builds on what came before.

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

`ernc` compiles one `.ern` file to a `.erc` compiled module. `ern` loads a compiled module, starts the runtime, binds addresses to the `Sys.*` top-level references (report §8.2), and calls `main()`. The standard library is on the load path by default, and so is the root of the module `ern` loads (report §11.2); `--load-path dir` adds more directories.

### 1.1 What the line says

`fn` starts a function definition. `main` is the conventional entry-point name — `ern module.erc` looks for `export fn main` in the loaded module and invokes it. The hello-world program declares one; larger projects can select a different exported entry point with `ern --main Qualified.name module.erc` (see §6.1).

`-> Unit` is the return type. `Unit` is a type with one value, also called `Unit`; it means "no interesting result." `main` in this program does its work, then returns `Unit`.

`with Never` is the mailbox effect. Every process has a mailbox with a fixed message type; `Never` is the type with no values — a mailbox typed `Never` cannot receive anything. `main` here only sends (through `Io.println`), so `Never` fits.

`Io.println` is a stdlib function that sends its argument to a small `Sys.stdout` process the runtime provides. The stdout process receives the text and writes it. `Io.println` writes to `Sys.stdout` only. Diagnostics go to the other sink the runtime provides, `Sys.stderr`, through `Io.printError` and `Io.printlnError`, so a program whose output something else reads can report trouble without corrupting it. To write a string to any other `Address(String)`, a logger say, send to it directly, `send(logger, "starting\n")`; the library has no second print function for that. Messaging to a runtime service is one of two ways Ernest interacts with the outside world (the other is `foreign fn`, §7).

For development output, `Io.debug(x)` prints any value and returns it, so it wraps an expression in place: `let n = Io.debug(f(x))`. It prints the value as the source writes it, by the argument's type: `Io.debug('a')` prints `'a'`, and a named constructor prints with its field names. An address prints as `<address>`, a reply as `<reply>`, and a function as `<function>`. A value of an abstract type prints as `<abstract>` outside its module. Inside a generic function, where the type is a variable, and for a foreign type, it can only go by the runtime's representation, so a `Char` there prints as its code point (report Appendix E.1). It carries `with m` like `Io.println`, so it cannot hide in pure code.

### 1.2 Prediction exercise

Consider two variations on hello-world:

```
export fn main() = Io.println("hello, world")             // (a) no annotation
export fn main() -> Unit = Io.println("hello, world")     // (b) declared pure
```

Which of these compile?

Answer: (a) compiles — inference gives `main` a fresh mailbox effect from `Io.println`'s call. (b) does not compile — the explicit `-> Unit` (without `with M`) declares the function *pure*, and a pure function cannot call `Io.println` (which sends). `ernc` says so in the form every error takes (report §11.5): the file, line, and column, the message, then the source with the offending span underlined, the annotation that caused it labelled, and a help line:

```
hello.ern:1:28: Io.println needs a process, and main is pure
1 | export fn main() -> Unit = Io.println("hello, world")
  |                     ---- `-> Unit` with no `with` declares main pure
  |                            ^^^^^^^^^^^^^^^^^^^^^^^^^^
  | = help: give main a mailbox type with `with`
```
 The `with Never` in the actual hello-world declaration says "this process has a mailbox, but it will never receive." Omitting an annotation is not the same as declaring purity.

## 2. Compute with immutable values

Everything in Ernest is immutable. Bindings introduce names; there is no assignment.

### 2.1 Scalars, Unit, and literals

- **`Int`** — arbitrary precision. Literals: `42`, and in another base `0xFF`, `0o644`, `0b1010`, the prefix lowercase. An `_` between two digits groups them, in any number: `1_000_000`, `0xFFFF_FFFF`, `3.141_592`. A letter or digit right after a number is an error, so `12px` and `0b102` are rejected, and so is an `_` anywhere but between two digits, as in `1_` or `0x_FF`.
- **`Float`** — IEEE 754 binary64, finite range only, with one zero: `0.0 * -1.0` is `0.0`. Literal: `3.14`.
- **`Char`** — one Unicode code point. Literal: `'a'`.
- **`String`** — a Unicode string. Literal: `"hello"`. Escapes: `\n`, `\r`, `\t`, `\\`, `\"`, `\'`, `\u{1F600}`. A raw string is written between backticks; see below.
- **`Bytes`** — sequence of octets. Literal: `<<0, 1, 2>>` (a bitstring, §7.6 below; report §5.11).
- **`Bool`** — `true` or `false`. `&&` and `||` short-circuit, `!` negates, and `Bool.not` is `!` as a function, the way `Int.negate` is prefix `-`.
- **`Unit`** — one value, also called `Unit`.

A raw string, between backticks, is taken exactly as written: a backslash is a backslash, and a line break is a line break. It is the form for text full of backslashes or quotes, and for text over several lines:

```
let number = `\d+(\.\d+)?` // a regular expression, not "\\d+(\\.\\d+)?"
let path = `C:\Users\ada\notes.txt`
let fixture = `{
    "name": "ada",
    "tags": ["a", "b"]
}`
```

A raw string has no escapes at all, so it cannot contain a backtick; build such a string from `"..."` pieces with `<>`. A line break inside it is a line feed whatever the file's line endings are (report §2.5). There is no regular expression syntax in the language: a pattern is a raw string given to a library.

`Float` arithmetic that would produce a non-finite result (overflow, division by zero of a non-zero numerator, `0.0 / 0.0`) *faults*. `Int` division `/` or modulo `%` by zero also faults. `Int.div` and `Int.mod` are the total alternatives that return `Optional(Int)`.

`Int` and `Float` are separate types with no implicit conversion — mixing them in an arithmetic expression is a type error. Cross the boundary explicitly with `Int.toFloat`, `Float.round`, `Float.floor`, `Float.ceil`, or `Float.truncate`; each has a contract in Appendix E of the report (`Int.toFloat` faults on integers outside the finite float range, for instance).

### 2.2 Bindings and blocks

Inside a block:

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

Top-level initializers must be pure — no `send`, no `spawn`, no other process effects. Effectful setup belongs in `main`. Initializers run in dependency order before `main` starts: a top-level `let` that references another is evaluated after the one it references. A cycle among top-level `let`s, within a module or across modules, is a compile-time error. A pure initializer can still fault or fail to terminate, in which case `main` never starts — a fault at startup is observed the same way as one during execution (§3.4).

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
let c = Map.update(m, "a", fn(v) = Optional.withDefault(v, 0) + 1);   // "a" is 2
let s = Set.fromList([1, 2, 3])
```

`Map.update` sees the entry as an `Optional`, present or not, and stores what the function returns: the counting idiom in one call.

Map keys, set elements, and the keys of an `Ets` table require equality. Ernest's `==` is defined for every type *except* those containing functions or addresses (report §3.10) — that includes tuples, sums, and constructor fields that transitively contain either. `Map(Address(m), v)` is a type error at the first `Map` operation on it; so is `xs == ys` when `xs` is `List(Address(m))` or any type containing one.

Ordering is separate from equality: `a < b` goes through the type's `compare` function, and only `Int`, `Float`, `String`, and `Char` have one in the prelude. `<` on a type without `compare` is a type error (report §3.10).

### 2.6 Patterns and irrefutability

The same patterns appear in `match` clauses, `let` bindings, and function parameters. Bindings and parameters need *irrefutable* patterns — patterns that always match:

- `_` and identifiers are irrefutable.
- A tuple pattern is irrefutable iff every component pattern is.
- A single-constructor type's constructor pattern is irrefutable iff every field pattern is.
- An irrefutable pattern with `as` is irrefutable.

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

A clause may list several patterns separated by `or`; it matches when any of them does. Every alternative binds the same variables at the same types, so the body uses them whichever alternative matched:

```
type Direction = North | South | East | West
type Move = Forward(Int) | Back(Int) | Stay

fn axis(d : Direction) -> String = match d {
    North or South -> "vertical"
  | East or West -> "horizontal"
}

fn step(m : Move) -> Int = match m {
    Forward(n) or Back(n) when n > 0 -> n
  | _ -> 0
}
```

A guard after the alternatives sees the shared variables. The same works in `receive`. `Some(x) or None -> x` is a type error, since `None` binds no `x` (report §5.9).

A postfix `as ident` binds the whole match alongside its destructured parts: `Some(x) as present` binds `x` to the payload *and* `present` to the whole Optional. Useful when both the interior and the aggregate matter. `as` is not allowed on reply-carrying scrutinees (§4.2).

Guards are pure `Bool` expressions with no mailbox effect. A guard that evaluates to `false` falls through to the next clause. A guard that *faults* faults the enclosing process; it never turns into a silent `false`.

A `receive` guard is narrower, because it selects a message without taking it out of the mailbox. It is a *guard expression*: comparisons of variables, literals, and nullary constructors, joined by `&&` and `||`, with the orderings on `Int`, `Float`, `String`, and `Char` only, and no calls (report §5.9). When you need more, receive the message and `match` it.

Guards do not count toward `match` exhaustiveness. A clause with a guard still needs an unguarded fallback, typically a wildcard `_` clause, so the compiler can prove coverage.

### 2.7 `if` and `<-`

`if cond then a else b` is an expression. Both branches must have the same type. There is no `if` without `else`. Like `match`, `receive`, and `fn`, it is not an operand: write `1 + (if c then a else b)`, not `1 + if c then a else b`.

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

The compiler picks Optional or Either from the right-hand side's type or, failing that, from the block's type. One block cannot mix — a block is either an Optional chain or an Either chain, not both.

`<-` works in a block, one step at a time. To run a step that can fail over every element of a list, `List.tryMap(xs, f)` and `List.tryFold(xs, acc, f)` do the same short-circuit: the first `Left` ends them.

### 2.8 The pipe operator `|>`

Ernest's stdlib is subject-first. `|>` reads left-to-right:

```
"abc" |> String.toList |> List.reverse |> String.fromList      // "cba"
```

`x |> f` is `f(x)`. `x |> f(a, b)` is `f(x, a, b)` — pipe inserts as the first argument. `x |> f(a)(b)` is `f(a)(x, b)`, inserted into the *outermost* call. A parenthesized call is a plain call: `x |> (f(a))` is `f(x, a)`.

**A lambda after `|>` must be parenthesized:** `x |> (fn(y) = y + 1)`. Without parens, the lambda's body extends greedily and swallows the rest of the expression.

### 2.9 The standard library

Report Appendix E lists the library: a module per namespace, mostly one per type, `List`, `Map`, `Set`, `String`, `Char`, `Bytes`, `Bool`, `Int`, `Float`, `Optional`, `Either`, `Foreign`, `Random`, `Path`, `Ets` for tables of the runtime, `Erl` for what a shim needs from Erlang, and one per system process, `Io`, `Clock`, `Keys`, `Fs`, `Tcp`. It is on the load path by default. Its rules, in Appendix E.0, are what let you guess a name before looking it up:

- **One verb per operation, in every module that has it.** `empty`, `size`, `isEmpty`, `contains`, `get` for lookup by index or key, `put` for insertion, `remove`, `map`, `filter`, `filterMap`, `foldLeft`, `foreach`, `any`, `all`, `find`, `fromList`, `toList`. A sum type has `withDefault`, `map`, and `andThen`. `Map.get(m, k)` and `List.get(xs, 0)` are the same verb; `Map.put` and `Set.put` likewise. A list adds order and position: `reverse`, `sort`, `take`, `drop`, `dropLast`, `last`, `span`, `partition`, `unique`, `indexed`, `repeat`, `zip`, `unzip`, `flatMap`, `range`, and `tryMap` and `tryFold` for a step over `Either` that can fail. A path adds its segments: `join`, `split`, `parent`, `name`, `extension`, `withExtension`, `isAbsolute`. A filesystem adds files and directories: `read`, `write`, `append`, `list`, `stat`, `makeDir`, `remove`, `rename`, `copy`.
- **Subject first, callbacks last, accumulator between**, so the pipe works: `xs |> List.foldLeft(0, fn(acc, x) = acc + x)`.
- **Conversions are named by the other type and live in the subject's module.** `String.toInt`, `Int.toString`, `String.fromList`. Several policies are several names: `Float.round`, `Float.floor`, `Float.ceil`, `Float.truncate`. A conversion to text has its inverse where the text form is unambiguous and the type has no other way in, which is why `String.toBool` and `String.toIntBase` stand beside `Bool.toString` and `Int.toStringBase`, and why a `Char` needs none, `String.toList` being its way in.
- **A type a module declares is named for what it is within the module**, never for the module: `Random.Seed`, not `Random.RandomSeed`.
- **A partial operation returns `Optional`; one with a cause returns `Either`.** `List.get`, `Map.get`, `String.toInt`, `Char.fromInt` return `Optional`. Nothing in the library faults beyond what report §7.4 lists.
- **Pure unless the value lives in a process or in the runtime.** The system modules `Io`, `Clock`, `Keys`, `Fs`, and `Tcp` carry `with m`, and so does `Ets`, whose tables the runtime holds; every other module is pure, and every function that takes a function is effect-polymorphic (§3.5).
- **A `String` is not a container.** Its characters are reached through `String.toList`: `List.all(String.toList(t), Char.isDigit)`. Text has its own operations instead: `startsWith`, `endsWith`, `replace`, `slice`, `padStart`, `padEnd`, `repeat`, `split`, `join`, `lines`, `trim`, `toLower`, `toUpper`; a `Char` has its predicates and its case, `isDigit`, `isAlpha`, `isSpace`, `isUpper`, `isLower`, `toUpper`, `toLower`.
- **`Random` has a pure interface.** `Random.next(seed, n)` returns a draw between 0 and `n` inclusive and the next seed; `Random.seed(42)` makes a seed, `Random.nextFloat(seed)` draws above 0.0 and below 1.0, and the same seed gives the same sequence.
- **A system process is used through its module, never by `send`.** `Clock.alarm(100, fn(_) = Tick)`, `Fs.read(path, 5000)`, `Tcp.accept(listener, 60000)`. A function that waits takes the milliseconds last and answers `Left(Timeout)`; `Clock.now`, `Tcp.listen`, and `Io.readLine` take none, the first two answer at once and the third waits for the user. One that delivers later takes a function to your mailbox type, as `monitor` does (§5.2). `Keys.subscribe` and `Io.readLine` are the same terminal, in raw and in line mode: a program uses one or the other, and one that uses both ends with `Fault("the terminal is already read as lines")`, or `as keys` (report §8.2). A socket is an `Address(SockMsg)`, a process, so it can be monitored, killed, and adapted with `via` like any other.

What the type does not say, the comment on the signature in Appendix E says: `List.remove` removes the first occurrence, `Map.toList` has no order, `List.sort` is stable.

### 2.10 Prediction exercise

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

Lambda body is the longest expression up to the enclosing form's delimiter: `,`, `;`, `|`, `)`, `}`, `]`, `>>`, `then`, or `else`.

### 3.3 Type inference and its limits

Ernest infers types Hindley-Milner style. You can omit annotations on parameters and returns:

```
fn double(n) = n * 2       // inferred (Int) -> Int
```

`*` on `Int` fixes `n : Int`. But **Ernest does not infer a "numeric type" or default to `Int`**:

```
fn twice(n) = n + n        // n's type ambiguous — annotate: (n : Int) or (n : Float)
```

Without a source that fixes the type, `n + n` is a type error. Once it is fixed, `+` is that type's: `Int.+` for an `Int`, `Distance.+` for a user type that declares it, and `Int.+` is also a function value, as in `List.foldLeft(xs, 0, Int.+)` (report §4.8, report §5.6).

Other limits worth knowing:

- `fn` definitions and top-level `let` values generalize over free type variables. Block `let` bindings are monomorphic — a block `let xs = []` types `xs : List(a)` with `a` to be resolved by an annotation, by later use in the block, or by escape through the block's return; a variable none of these resolves is a type error at the binding. `let _ = e` binds no variable, so nothing in the type of `e` needs resolving: `let _ = spawn(Local, fn() = worker())` is legal with the mailbox type unresolved, as ping-pong does in §5.1.
- Local `fn` names inside a block are visible throughout the block, but you cannot *use* one — call it, obtain it as a value, pass it, store it — before the `let` bindings it references have been evaluated. Passing a local function to another counts as using it: if `g`'s body reads a `let` that comes after `h(g)` but before `g`'s declaration, `h(g)` is the error. A `let` after `g`'s declaration is already an error in `g`'s body (report §5.4).
- Top-level `let` initializers must be pure — no mailbox effect. Effectful setup (spawning processes, sending initial messages) belongs in `main`. The runtime evaluates top-level `let` bindings in dependency order before `main` runs.

### 3.4 Pure functions and functions with a mailbox effect

A function type without `with M` is *pure*: it cannot perform process operations — no `send`, no `receive`, no `spawn`, no `Address.call`, no effectful `foreign fn`. A function with `with M` may act through a process whose mailbox type is `M`.

Both kinds of function can fault or fail to terminate. `a / b` with `b = 0` faults despite the type being `(Int, Int) -> Int`. `todo("...")` compiles at any type and faults if reached. Ernest has no local exception handler: expected failures are values (`Optional`, `Either`) or protocol messages; a fault terminates the process and is observed by other processes through monitoring (§5).

The mailbox effect says one thing: the function acts through a process. It says nothing about faults.

### 3.5 Higher-order and effect polymorphism

```
fn apply(f, x) = f(x)
```

Inferred type: `((a) -> b with e, a) -> b with e`. The callback's mailbox effect `e` flows through — if `f` is pure, so is `apply(f, x)`; if `f` has effect `M`, `apply(f, x)` has effect `M`. `List.map`, `List.foreach`, and the other combinators in Appendix E work the same way.

An effect variable that appears *only* in effect position (like `e` above) may bind to a mailbox type or to *pure*. An effect variable that also appears in a value position (like `m` in `self : () -> Address(m) with m`) can only bind to a real mailbox type — pure is not a type, so it cannot appear inside `Address(_)`.

Process operations that require a process context — `self`, `send`, `spawn`, `Address.call`, `Address.callForever`, `answer`, `monitor`, `kill`, `remote`, `parallelRemote`, a `foreign fn` whose effect is its own, and the `receive` expression form — are *process-only*: they require the enclosing function's mailbox effect to be a real mailbox type, so pure code cannot use any of them. A `foreign fn` whose effect variable is also one of its parameters' callback effect is not one of them: the effect is the callback's, so the function is pure when the callback is (report §3.9).

`ping`'s `m` in §5 is polymorphic but process-only: any real mailbox is admissible, but pure is not.

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

`Reply(a)` is a built-in one-shot address: someone hands it over with a request; the receiver puts one value in it, exactly once. Unlike `Address(a)`, a `Reply(a)` is *linear*: the compiler checks that every one is consumed exactly once.

### 4.2 Reply is linear

The compiler enforces: **a `Reply(a)` must be consumed exactly once on every path, wherever it is bound: a `receive` clause, a parameter, a pattern, a `let`, a call's result, or a capture.** The rule generalizes to *reply-carrying types* — any type that transitively contains a `Reply`. `CounterMsg` above is reply-carrying because `Get` has a `Reply` field.

Six ways to consume:

1. `answer(r, v)` — the only primitive that finally discharges the reply.
2. Passing to a function whose parameter type is reply-carrying (delegates the obligation).
3. Sending with `send(a, v)` (shifts to the recipient's `receive` clause).
4. Placing into a constructor or tuple of reply-carrying type — the constructed value inherits the obligation.
5. Returning from a function whose declared return type is reply-carrying — shifts to the caller.
6. Capturing in a lambda. The lambda is then reply-carrying itself: consumed exactly once, by a call or as `spawn`'s direct argument, and it may be bound with `let` but appear nowhere else, since its type does not show the capture. `let g = fn() = worker(r); spawn(Local, g)` is fine; calling `g()` after that is consuming it twice.

A reply-carrying value neither bound nor consumed is a type error: `Get(reply = r); Unit` consumes `r` into a message and then drops the message.

Consumptions 4 and 5 are why the builder passed to `Address.call` (§4.4) is legal: `fn(r) = Get(reply = r)` places `r` in `Get`, and returning the reply-carrying `CounterMsg` hands the obligation to `Address.call`. `Address.call` in turn consumes the message by sending it to the recipient, transferring the obligation to whichever `receive` clause on the recipient's side eventually binds it. Only `answer(r, v)` finally discharges the underlying `Reply`.

The ownership check is static: it verifies that every syntactically reachable path calls `answer` (or delegates, or shifts). It does not guarantee that execution *reaches* that call at runtime — a path that faults, loops, or waits forever bypasses the answer without invalidating the type check. That is why `Address.call` requires a mandatory timeout (§4.4): the caller must plan for the case where the answer never comes. The check is linearity, not liveness. It proves that every path consumes the reply exactly once, as a move checker does. Whether the path is reached is not provable; the timeout is the answer to that. The one place linearity cannot see, foreign code holding a `Reply`, the runtime covers: a second answer to an answered reply is discarded.

Pattern-matching a reply-carrying scrutinee transfers the obligation to the pattern-bound reply-carrying fields; matching a nullary case (like `Stop` in `PongMsg`, §5) discharges the aggregate obligation with no new binding. A `let` passes the obligation along the same way: after `let r2 = r`, it is `r2` that must be consumed.

A wildcard or omitted reply field, and an `as` alias on a reply-carrying scrutinee, are type errors. Reply-carrying values may not appear as elements of `List`, `Map`, `Set`, `Optional`, or `Either`, or as operands of equality. That last rule is what makes the check decidable, and it has a visible cost: a server that must hold pending replies cannot keep them in a `Map`. It keeps each in a process, one per request, which is what filesync does with one process per write.

A generic helper that duplicates or discards its parameter (`fn dup(x) = #(x, x)`, `fn discard(x) = Unit`) infers a *not-reply-carrying* restriction — the parameter cannot be instantiated to a reply-carrying type. `fn identity(x) = x` passes through without duplication and carries no such restriction. The compiler prints the restriction as a mark on the variable: `dup : (a!) -> #(a!, a!)`, and likewise `equal : (a=, a=) -> Bool` for the equality constraint of §2.5. You never write the marks; you see them in error messages and generated documentation, and `first : (a, b!) -> a` tells you at a glance that `first` cannot be handed a reply as its second argument. No mark appears where it could not matter: in `Optional.withDefault : (Optional(a), a) -> a` the variable `a` is also an `Optional`'s element, which can never be a reply.

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

`after N` gives a millisecond timeout that fires if no clause matches within that window. `after 0` scans without waiting for new messages. Without `after`, the process waits indefinitely. A `receive` with only an `after` clause is a timed wait, and is the one `receive` a `Never` process may use.

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
3. **Late answers are silently discarded, and so are second answers.** They never enter the caller's ordinary mailbox. A reply arriving exactly at the deadline may be delivered or discarded — no deterministic tiebreak.
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

`ping`'s mailbox `m` is polymorphic — ping never `receive`s. It is polymorphic but process-only: `ping` uses `Address.call`, which requires a real mailbox effect. Any concrete `m` works; pure does not.

The `main` process monitors `pongAddr` and waits for its termination. Returning from `main` immediately after the two spawns *may* terminate the children before their work finishes — the runtime does not order `main`'s return against the children's first send. Waiting for a monitor notification keeps `main` alive until the monitored process ends, whether it returned normally, faulted, or was killed. `PongDone(_)` accepts every death reason.

One possible successful trace of the stdout is: `ping 3`, `pong 3`, `ping 2`, `pong 2`, `ping 1`, `pong 1`. The runtime's FIFO guarantee applies per-sender (ping's messages arrive at pong in send order, and pong's answers arrive at ping in send order), but the two processes' `Io.println` calls come from different senders to `Sys.stdout`, so their interleaving is scheduling-dependent. The alternating trace is one such interleaving.

### 5.2 `monitor` and `Down`

```
monitor : (Address(a), (Down) -> m) -> Unit with m

type Down = Down(reason : Reason, function : String)
type Reason = Returned | Killed | ProgramEnd | Fault(String)
```

`monitor(child, wrap)` asks the runtime to place `wrap(d)` in *your* mailbox when `child` dies, or at once if it is already dead. `wrap` adapts the runtime's `Down` into your mailbox type — in ping-pong, `PongDone` is a constructor of `MainMsg` that carries a `Down`. `PongDone(_)` accepts any death reason; it signals *termination*, not *success* — a faulting pong would still deliver `PongDone(Down(reason = Fault(_), ...))`. `function` in `Down` is the qualified name of the function that called `spawn` for the dead process, with the line of the call, `Counter.main:19`; for the entry process it is the entry point's name (report §6.9).

`wrap` is a function, so it can carry what you need to tell one death from another. A process that monitors a worker while waiting for its answer gets two messages, the answer and the death, and takes the answer; the death is still in the mailbox when the next worker is monitored. Addresses have no equality, so a `Down` cannot be asked which worker it is about. Give each worker a number and let the wrap close over it:

```ernest
let child = spawn(Local, fn() -> Unit with Never = send(me, Result(run = run, value = work())));
monitor(child, fn(d) = Died(run = run, down = d));
```

A message whose run is not the one being waited for is an earlier worker's, and is ignored. This is what the report means by identity being expressed in the protocol: the protocol is yours, and the wrap is where you put the identity in it.

A fault in one process does not affect another (no automatic supervision), except that a fault in `main` ends the program and terminates its local processes with `ProgramEnd`.

### 5.3 `kill`

```
kill : (Address(a)) -> Unit with m
```

`kill(addr)` requests termination of the process at `addr`; anyone monitoring receives `Down(reason = Killed, ...)`. It is a scheduling event, not an instantaneous halt — the target may run briefly before the runtime interrupts it. The REPL paper program combines `monitor` and `kill` into a supervised-child pattern that gives up after a timeout.

### 5.4 `Deadlock` as a safety net

The runtime ends a program with the error `Deadlock` when forward progress is impossible: every live process waits in `receive` without `after`, no message is in flight, and no live system process or connected peer holds a subscription, a timer, a pending I/O, or a computation that could deliver a message. Pending `after`s, network listeners, keyboard subscribers, and running peer computations that owe this node a reply all count as such a source, so an idle server waiting on external events is not deadlocked. Detection is per node; a distributed deadlock across peers may not be detected.

### 5.5 Adapting messages with `via`

`monitor(child, wrap)` takes a function from the runtime's `Down` to your mailbox type. The standard library's system modules use the same shape wherever something arrives later: `Clock.alarm(ms, wrap)` puts `wrap(Unit)` in your mailbox after `ms` milliseconds, and `Keys.subscribe(wrap)` puts every key pressed in it.

```
Clock.alarm(100, fn(_) = Tick)
```

Between your own processes the general form is `via`:

```
via : ((a) -> b, Address(b)) -> Address(a)
```

`via(convert, target)` returns an `Address(a)` that, on receipt of an `a`, applies `convert` and delivers the resulting `b` to `target`. A worker written to report to an `Address(Either(String, Int))` knows nothing of your `GameMsg`; you hand it `via(Done, self())`, where `Done` is the constructor of `GameMsg` that carries a result, and `Done(r)` arrives in your mailbox. `monitor` and `Clock.alarm` are `via` with `self()` already filled in.

`Clock.alarm` fires exactly *once*. For a periodic tick, the receiver schedules a new one only after handling the previous. A naive `game` that loops back on every message would create one pending timer per input, so a burst of inputs multiplies the tick rate. Two functions make the boundary explicit:

```
type GameMsg = Tick | Input(Char)
type World = World(score : Int)

fn step(World(score = n) : World) -> World = World(score = n + 1)

fn game(state : World) -> Unit with GameMsg = {
    Clock.alarm(100, fn(_) = Tick);
    waitForTick(state)
}

fn waitForTick(state : World) -> Unit with GameMsg = receive {
    Tick -> game(step(state))
  | Input(_) -> waitForTick(state)
}
```

`game` schedules exactly one clock request, then hands off to `waitForTick`. Inputs are handled without touching the pending timer; only a `Tick` returns to `game`, which schedules the next one. `step` destructures the world with a pattern; Ernest does not generate field-accessor functions.

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
$ ern main.erc                   # net/http.erc is found under main.erc's root, which is on the load path
GET /
```

Or in directory mode — compile the whole tree and put outputs under `build/`:

```
$ ernc --out-dir build .         # walks the source tree, writes build/net/http.erc and build/main.erc
$ ern build/main.erc
GET /
```

Directory mode compiles in dependency order automatically, creates missing subdirectories under `build/`, and, after a successful build, removes `.erc` files whose `.ern` is gone and the directories that empties (`--no-clean` disables the sweep; single-file mode never sweeps). It's the recommended pattern once a project has more than one file. A second run rebuilds only what changed: a module whose source changed, whose dependency's interface changed, or that another version of `ernc` built; any change to a standard library interface rebuilds every module. A change to a dependency's bodies alone leaves its dependents as they are (report §11.1).

**The file's path is its namespace.** A file at `a/b/c.ern` under the source root provides declarations at namespace `A.B.C`. The source root is `--source-root dir`; without it, the current directory when one file is compiled and the directory passed when a tree is. A file of the standard library's own `stdlib/` always takes that directory as its root (report §4.2, report §11.1). Each path segment is one lowercase word; each namespace segment is the path segment with its first letter uppercased and the rest unchanged (`http.ern` → `Http`, `httpv2.ern` → `Httpv2`). A multi-word module is a nested directory, `http/parser.ern` for `Http.Parser` (report §11.1), so the mapping is one-to-one. A module namespace may not coincide with a namespace of the prelude or the standard library, so `io.ern` at the source root is an error, nor with a type namespace of its parent module: `main/stack.ern` is an error when `main.ern` declares `Stack` (report §4.2).

**Declarations use local names.** Inside `net/http.ern`, `export fn parse(...)` declares the function at its local name `parse`; the compiler exports it as `Net.Http.parse`. There is no file-namespace prefix on the declaration itself — repeating `Net.Http.` on every line would just restate the file's path.

**`export` marks the boundary.** A declaration prefixed with `export` is visible from other modules; a declaration without `export` is private to its own file. No `import`, no export list, no `pub`. `export` may prefix any top-level declaration: `fn`, `type`, `abstract type`, `let`, `foreign fn`, or `foreign type`. Constructors of an exported concrete type are exported with the type — `export type Optional(a) = None | Some(a)` makes `None` and `Some` visible to other modules; `type Internal = A | B` keeps the type and both constructors private. An abstract type controls constructor visibility through its `with { ... }` signature, not through `export`: the type name is `export`ed, its accessors are separately `export`ed if they should be public, and the constructor stays visible only to the definitions listed in the signature.

**External references use the qualified name.** A caller outside `net/http.ern` writes `Net.Http.parse`. Inside `net/http.ern`, unqualified `parse` refers to the local declaration, and `Net.Http.parse` works there too (report §4.2), which is how a documentation example is written.

**Testing a module.** A test is a top-level `let` of the prelude type `Test`, a name and a function returning `Passed` or `Failed(text)`:

```
let addsTwo = Test(name = "adds two", run = fn() -> TestResult with Never =
    if add(1, 1) == 2 then Passed else Failed("not two"))
```

`ern --test module.erc` runs every test of the module, exported or not, each in a process of its own, and prints each as passed, failed with its text, or faulted with its cause. A test runs as a process root, `with Never`, so it may spawn, send, and call; `ern --test` exits 1 unless every test passed; one that needs `receive` spawns a process for it (report §9.3, report §11.2).

**Documenting a module.** A `///` block documents what follows it on the next line: a declaration, a constructor, a named field, or a signature entry. A `///` block first in the file, with a blank line after it, documents the module. The text is CommonMark, and `ernc --doc` renders the module as a page: the title, each declaration's type in a code block, and the text. The documentation travels in the compiled module, so `--doc` reads a `.erc` as well as a `.ern` (report §11.1). An example in a doc block ends with `// => v`, the value `Io.debug` prints, and the standard library's tests run it and compare. An example that cannot run where the page's examples run, because its value is of an abstract type, because it reads a file or a socket, or because it needs a mailbox of its own, carries no such line and is only type-checked. What a module's documentation must contain is Appendix E.0 rule 6 of the report; [`docs/module_doc_template.md`](docs/module_doc_template.md) shows it on a fictive module, generated and kept true by a test (report §2.2 and report §11.4).

**Entry point.** `ern main.erc` looks up `export fn main` in the loaded module and invokes it. `main` is a naming convention, not a reserved specialness — any exported function with the entry-point shape `() -> Unit with M` can be selected. If `tools.ern` exports a `check` function of that shape, run it as:

```
$ ern --main Tools.check build/main.erc
```

`--main` takes a fully qualified name whose final segment is a lowercase function name (`Tools.check`, not `Tools.Check`). This is how a project with multiple entry points — a service main, a migration main, a bench main — keeps each in its own module.

### 6.2 Abstract types

Abstract types have a private representation and a public signature. Only definitions listed in the `with { ... }` signature can mention the constructor. Any locally declared type — abstract or concrete — creates a nested namespace inside its module, and its members are declared with a single-typename prefix (`fn Stack.push`). Report §4.8 shows the concrete-type variant used for per-type operator overloading (`fn Distance.+`, and so on); an operator is declared with `fn`, never with `let`. From another module an abstract type's constructor is not visible at all: `Main.Stack([])` there is an error, and callers go through the signature.

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

Two `Stack(a)` declarations on two nodes are one type only when their representation, qualified name, and signature all match (report §8.7). The same signature over a list on one node and a tree on another is two types.

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

`parallelRemote` preserves input order in the result list. Each callback is pure; the batch call has a mailbox effect. The signature has no timeout; a callback that does not return keeps the call from returning.

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

Four operations ship a closure or payload and the code it depends on: `spawn(Peer(name), f)`, `remote(f)` and the return of its result, `send` to a remote address, and `answer(r, v)` to a caller on another node. The peer resolves each referenced hash — it uses cached code if present, or fetches from the sender. Types, functions, and constructors are identified across nodes by content hash; two nodes with structurally identical definitions agree on identity.

Some consequences the code sees:

- A `Sys.*` name referenced by shipped code resolves *on the peer that runs the code*. A shipped `Io.println` sends to the peer's `Sys.stdout`.
- A captured address value ships as a value — its target is whichever process it pointed to when the closure was formed, not re-resolved on the peer.
- Top-level bindings referenced by shipped code are initialized on demand on the peer, in the peer's environment. `let output = Sys.stdout` gives the sender's stdout on the sender and the peer's on the peer.
- `send` to a remote address returns immediately; a peer-side resolution failure faults the sender *asynchronously*, after `send` has already returned.
- Foreign definitions must be available and compatible on the peer.

Peer loss is *terminal from this node's view*. Once this node declares a peer lost, it treats the processes on that peer as dead. Their existing addresses do not become usable again if the same peer name reappears — a re-appearing peer is a new node instance. Monitors on remote addresses report `Down(reason = Fault("peer lost"), ...)`, and pending `remote` calls return `Left(PeerLost)`. Remote sends are best-effort: in-flight messages can be dropped at peer loss without a delivery notification, and returning from `send` is not evidence that the recipient processed the message. A callback or resolution failure that returned `PeerLost` does not, on its own, invalidate unrelated addresses for the same peer — only *actual* peer-loss detection has that effect.

### 7.3 Foreign types and functions

```
// cache.ern
export foreign type Table(k, v)

export foreign fn member(t : Table(k, v), key : k) -> Bool with m = "ets:member/2"
```

External callers write `Ets.Table` and `Ets.member`. `foreign type` declares a type whose values are made and used only by foreign functions — no Ernest-side constructor, no pattern match. `foreign fn` binds a name to an implementation on the other side (here, Erlang's `ets:member/2`).

Ernest treats the foreign boundary as a *promise*: the declared type is what comes back, the mailbox effect is honest, a pure declaration means no effects. Of the four promises below, three are checked at runtime and purity is not:

- **Wrong return type.** *Checked at runtime.* The declared type is Ernest's contract; a value the foreign side hands over that does not match faults the *receiving* Ernest process on first observation.
- **Thrown exception.** *Checked at runtime.* Erlang exits and throws become `Fault` on the calling process.
- **Wrong message from a foreign process.** *Checked at runtime.* A message that doesn't match the *destination's* declared mailbox type faults the receiver on delivery. Messages from the system processes are not checked (report §8.4). A message between two Ernest processes was already checked by `send`'s type, so nothing is checked at delivery.
- **Purity.** *Not checked.* Declaring `foreign fn` without `with M` is a promise the foreign side cannot enforce mechanically. Reserve pure declarations for functions that genuinely have no effect.

In the other direction, an Ernest process's death is an Erlang exit reason: `normal` when it returned, `{ern, fault, Text}` when it faulted, `{ern, killed}` and `{ern, program_end}` for the other two ends (report §8.4). Erlang code that monitors an Ernest process reads these.

A value foreign code made and Ernest does not inspect has the built-in type `Foreign`; `Foreign.toInt` and the rest of Appendix E.12 read it, and `Erl.atom(name)` is how an Erlang atom is passed (report §3.7, Appendix E.19).

### 7.4 Node-local foreign values

Foreign values are bound to the node that made them. Any cross-node transport of a value that transitively contains one faults with `Fault("foreign value cannot cross nodes")` — including a closure that captures such a value.

```
let t = Ets.new();
spawn(Peer("alice"), fn() = Ets.insert(t, "x", 1))   // fault: t is captured
```

Programs that need to share table-like state across nodes serialize the contents and rebuild on the peer.

### 7.5 The shim pattern

Erlang's `ets:lookup` returns a list because the key might match zero or one entry. Both declarations below live in `cache.ern` (namespace `Cache`), a module of your own:

```
// ets.ern
export fn lookup(t : Table(k, v), key : k) -> Optional(v) with m =
    match rawLookup(t, key) { [#(_, v)] -> Some(v) | _ -> None }

foreign fn rawLookup(t : Table(k, v), key : k)
    -> List(#(k, v)) with m = "ets:lookup/2"
```

`rawLookup` has no `export`, so it is file-local. `Ets.lookup` is the typed API callers use, by its qualified name.

Erlang's `{ok, V} | {error, R}` convention does not automatically match an Ernest `Either(e, a)`. Ernest's `Either` constructors are `Left(e)` and `Right(a)`, and under the ABI of report §8.4 they encode as `{'Left', e}` and `{'Right', a}` (quoted, source-preserving). Erlang's `{ok, V}` uses the lowercase atom `ok`, which is a different value.

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

If `find/1` returns reasons of another shape (an atom, a nested tuple), the Erlang helper must convert them to the declared Ernest form before returning; the Ernest side does not paper over ABI-shape breaches. In the other direction, a `foreign fn` that takes a `Foreign` is given one by `Foreign.from(value)`, which is the value as the runtime already holds it (Appendix E.12), and `Erl.atom(name)` builds the atoms such an API expects. Where a shim keeps Erlang's convention as a type, it declares the result `Erl.Result(v, r)`, which is `Ok(v) | Error(r)`, and its helper rewrites `{ok, V}` and `{error, R}` to those constructors (report Appendix E.19).

Report Appendix D walks the standard library's own `ets.ern` (namespace `Ets`, Appendix E.21) as its worked example of a shim. Its foreign calls happen to already match Ernest's ABI (`[{K, V}]` maps to `List(#(k, v))`, `Bool` to `true`/`false`), so it needs no Erlang wrapper. This is also the shape of every library outside the standard library: JSON, TLS, regular expressions, HTTP are not in Appendix E, by E.0's rules, since each is a namespace of its own with policy inside; they are written as `Ets` is written, by anyone, under a namespace Appendix E does not take, and put on the load path when a program wants them. Which are first-party, and when, is the plan's.

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

A segment without specifiers is `int` of size 8, which is why `<<0, 1, 2>>` is three bytes. `int` binds to `Int`, `float` to `Float`, the `utf` forms to `Char`, `bits` and `bytes` to `Bytes`.

**Alignment and range rules:**

- A bitstring produces a `Bytes` value; the total bit count must be a multiple of 8.
- A `bits` or `bytes` segment binding to a `Bytes` value must itself be byte-multiple. Sub-octet fields use the `int` specifier (binding to `Int`).
- Compile-time-constant alignment violations are compile-time errors. Dynamic-size violations fault in construction and fail matching in patterns.
- A segment value that does not fit its specified width — an `Int` too large for `size(N)-int` at construction — is a fault.
- Four fixed limits (report §5.11): `unit` is 1 to 256; a `float` segment is 16, 32, or 64 bits; a `utf` segment takes no size; a sizeless `bits` or `bytes` segment is the last one.

What a `Bytes` value holds is read with the `Bytes` module (Appendix E.20): `Bytes.size` and `Bytes.isEmpty`, `Bytes.get` for one octet, `Bytes.slice`, and `Bytes.toList` and `Bytes.fromList` between a `Bytes` and a `List(Int)`. A `Bytes` is not a container, so its octets go through `toList`, as a `String`'s characters do. Text crosses with `String.toUtf8` and `String.fromUtf8`.

A segment pattern is a variable, `_`, or a literal; a float literal `0.0` matches the bytes of either zero (report §3.1). `size(Expr)` in a pattern is a variable of an earlier segment or the enclosing function, an `Int` literal, or `+`, `-`, `*` of these, evaluated while matching. A `match` over bitstring patterns ends with a `_` or variable clause, as `parseFrame` does: the checker does not decide whether bitstring patterns cover every `Bytes` value.

**Precondition for `frame`/`parseFrame`:** the round trip works when `len` equals `body`'s byte count *and* `len` fits in the length-field width (16 bits, so 0 to 65 535). `parseFrame(frame(1, <<65, 66>>))` returns `Some(#(1, <<65>>, <<66>>))` — a one-byte body and a one-byte remainder, not an error, because `len = 1` was chosen. If `len` doesn't fit the width, `frame` faults at construction.

Bitstrings compile to the runtime's bit syntax (report §5.11, report §10).

### 7.7 Prediction exercise

Suppose `send(remoteAddr, msg)` returns immediately, and 50 ms later the peer reports a resolution failure. What happens to the sending process?

Answer: the runtime faults the sending process asynchronously, after `send` has already returned. Code that followed the `send` may have executed; the fault interrupts the process where it currently is, not at the site of `send`.

## 8. Frequently asked questions

**Why is `main`'s mailbox usually `Never`?**

`Never` is the type with no values; a mailbox typed `Never` cannot receive. `main` that only spawns and sends carries `with Never` to say so. If `main` is written with a polymorphic `with m`, the runtime instantiates `m` to `Never`.

**When do I write `with Never` and when `with m`?**

`with Never` is for a process root that never receives: `main`, or the function a spawn lambda calls. A function with mailbox `Never` can only be called where the mailbox is `Never`, so a send-only helper that other process code calls, like `Io.println`, stays polymorphic with `with m` and takes the caller's mailbox type.

**Why can `let Right(x) = e` be a type error?**

`Right(x)` is refutable — it might fail if `e` is `Left(...)`. `let` and function parameters need irrefutable patterns. Use `match` or `<-` for refutable cases.

**Why is there no `import`?**

Every top-level declaration lives at a namespace determined by its file's path under the source root. A file at `a/b/c.ern` provides declarations at namespace `A.B.C`; the declaration itself is written with a local name, and the compiler exports it (if marked `export`) as `A.B.C.name`. Code anywhere refers to the declaration by its full name. `export` marks visibility outside the module; without it, a declaration is private. No `import`, no export list — the qualified name IS the reference.

**Why parenthesized lambdas after `|>`?**

A lambda's body is greedy — it extends until the enclosing form's separator. Without parens, `x |> fn(y) = y + 1 |> f` would either eat the second `|>` into the body or split confusingly. Parens make the boundary explicit.

**Why write `fn(x) = ...` for lambdas instead of `x -> ...`?**

Ernest is n-ary: every function has a specific number of arguments recorded in its type. `fn(x)` says "one argument"; `fn(x, y)` says "two." The chosen syntax makes arity visible at the definition site, and the parenthesized form matches ordinary calls.

## 9. Reading further

Which programs under `examples/` the toolchain runs today is the `PROGRAMS` macro in `test/ern_integration_tests.erl`. The four paper programs below compile today. They are not run under test yet: two run until stopped, one waits for a terminal, and one serves until a client stops coming, so running them needs fixed input and a bounded run.

The four paper programs, in ascending complexity:

- [`examples/snake.ern`](examples/snake.ern) — snake game with tick-based updates; `..` record updates, one process per player, `Clock`, `Keys`, `Random`.
- [`examples/repl.ern`](examples/repl.ern) — small read-eval-print loop; `<-` for chained parsing, `monitor` + `kill` for aborting slow evaluation, `Io.readLine`.
- [`examples/filesync.ern`](examples/filesync.ern) — file sync between two nodes; mutual-address setup, one process per file operation, `Fs`.
- [`examples/webserver.ern`](examples/webserver.ern) — HTTP server with sessions in the standard library's `Ets`; `foreign fn`, abstract types, `Tcp`.

Beyond `Io.println` and `Clock`, the paper programs use `Fs`, `Keys`, `Tcp`, `Io.readLine`, and `Ets` (Appendix E.21), all of which the toolchain has.

For the language rules themselves, [`ernest_report.md`](ernest_report.md) is the authority. Appendix F glosses every technical term.

For why Ernest looks the way it does — what was tried and rejected — [`decisions.md`](docs/decisions.md) records dated design decisions.
