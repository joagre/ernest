# Programming in Ernest

This guide teaches Ernest to a programmer who knows another language, and it needs nothing beside it. Each complete program in it compiles as shown, and prints what is shown after it. The language is defined by [`ernest_report.md`](ernest_report.md), to which the guide points where a question turns on a detail.

## 0. Why Ernest

Ernest is a functional language for concurrent programs, built on two ideas. A pure function computes a value from its arguments and does nothing else, and the compiler infers its type. A process runs a function and receives messages of one type in its mailbox, and processes are how a program acts on the world. A function that sends or receives says so in its type, and runs only in a process. Every other rule says how the two appear in each other's code.

The rules let the compiler find, before the program runs, the mistakes concurrent programs are prone to. Four follow, each as a program and what `ernc`, the compiler, says about it.

**A message the process does not take.** The counter receives `CounterMsg`, so the address `spawn` returns takes a `CounterMsg` and nothing else.

```ernest-rejected
type CounterMsg = Inc(Int) | Get(reply : Reply(Int))

fn counter(n : Int) -> Unit with CounterMsg = receive {
    Inc(k) -> counter(n + k)
  | Get(reply = r) -> { answer(r, n); counter(n) }
}

export fn main() -> Unit with Never = {
    let c = spawn(Local, fn() = counter(0));
    send(c, "increment")
}
```

```console
$ ernc message.ern
message.ern:10:13: the argument does not fit send: expected CounterMsg, found String
 9 |     let c = spawn(Local, fn() = counter(0));
10 |     send(c, "increment")
   |     ---- send : (Address(a), a) -> Unit with e
   |             ^^^^^^^^^^^
```

Every error in a program has this form: the position as `file:line:column`, the message, and the source with the error's span underlined with `^`. A span the error depends on is underlined with `-` and labelled, here the type of `send`, whose two arguments must agree.

**A request left unanswered.** A `Get` carries a `Reply(Int)`, in which the counter puts its answer. A reply is answered exactly once on every path. This counter forgets to, and whoever asked would wait.

```ernest-rejected
type CounterMsg = Inc(Int) | Get(reply : Reply(Int))

fn counter(n : Int) -> Unit with CounterMsg = receive {
    Inc(k) -> counter(n + k)
  | Get(reply = r) -> counter(n)
}
```

```console
$ ernc forgot.ern
forgot.ern:5:5: the reply-carrying value r is never consumed
4 |     Inc(k) -> counter(n + k)
5 |   | Get(reply = r) -> counter(n)
  |     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^
```

**Work through a process, in a function that says it does none.** The terminal is a process, so printing is sending it a message. `area` is declared pure, `-> Int` with nothing after it, and the compiler holds it to that. A function that sends or receives says so with `with`, as the help line says.

```ernest-rejected
fn area(w : Int, h : Int) -> Int = {
    Io.println("computing an area");
    w * h
}
```

```console
$ ernc area.ern
area.ern:2:5: Io.println needs a process, and area is pure
1 | fn area(w : Int, h : Int) -> Int = {
  |                              --- `-> Int` with no `with` declares area pure
2 |     Io.println("computing an area");
  |     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  | = help: give area a mailbox type with `with`
```

**A failure dropped.** `Fs.write` returns `Either(IoError, Unit)`: the file was written, or the reason it was not. A statement in a block must be `Unit`, so the failure cannot pass unseen. `let _ = ...` discards it where that is meant.

```ernest-rejected
export fn main() -> Unit with Never = {
    Fs.write(Path("notes.txt"), String.toUtf8("buy milk"), 1000);
    Io.println("saved")
}
```

```console
$ ernc notes.ern
notes.ern:2:5: this statement's value is discarded: expected Unit, found Either(IoError, Unit)
1 | export fn main() -> Unit with Never = {
2 |     Fs.write(Path("notes.txt"), String.toUtf8("buy milk"), 1000);
  |     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  | = help: `let _ = ...` discards it on purpose
```

These rules come from one design, and most of its parts exist already. The Erlang runtime gives processes, faults delivered as messages to the processes that watch, and code replaced while a program runs. Gleam showed that a statically typed language fits that runtime, and Ernest follows it in much: Hindley-Milner inference, `fn` and the pipe `|>`, the update `Con(..x, f = v)`, and foreign types and functions as the way to Erlang code. Unison identifies code by a hash of its definition and ships to a peer what it lacks. What Ernest adds is where the parts meet:

- **The mailbox in the function's type.** A process receives one type of message, and the functions it runs say so, `with CounterMsg`. An address carries the same type, so every `send` is checked against its receiver. Gleam types the channel a message travels on; Ernest types the process.
- **Checked replies.** A request carries a `Reply`, answered exactly once on every path, which the compiler checks as it checks types. `Address.call` waits with a deadline, so an answer that never comes is a case the program handles.
- **Purity in the type.** `with` separates the functions that may send or receive from those that cannot. A pure function computes and returns, and the compiler holds it to that.
- **Distribution by content, planned.** Unison's content addressing, on the Erlang runtime. Every function and type is known by a hash of its definition, a type's name included, so a message is checked across nodes as it is within one. Code travels with what uses it: a closure sent to a peer brings the definitions it needs, and the peer fetches what it has not seen. Two nodes need not run the same version of a program, and two versions of a type are two types, never one type read two ways (§8).

The rest of the guide is eight stages: run a program, compute with values, pass behavior, run a protocol, manage process lifetime, handle failure, organize code, and cross boundaries. Each builds on the ones before it and ends with an exercise. A complete program is shown whole; a fragment is part of the program around it.

## 1. Run a program

A program is a module that exports a function `main`. Put this line in `hello.ern`:

```ernest
export fn main() -> Unit with Never = Io.println("hello, world")
```

Compile and run:

```console
$ ernc hello.ern         # produces hello.erc
$ ern hello.erc          # runs main()
hello, world
```

`ernc` compiles one `.ern` file to a `.erc` compiled module. `ern` loads a compiled module, starts the runtime, binds addresses to the `Sys.*` top-level references (report §8.2), and calls `main()`. The standard library is on the load path by default, and so is the root of the module `ern` loads (report §11.2); `--load-path dir` adds more directories.

### 1.1 What the line says

`fn` starts a function definition. `main` is the conventional entry-point name — `ern module.erc` looks for `export fn main` in the loaded module and invokes it. The hello-world program declares one; larger projects can select a different exported entry point with `ern --main Qualified.name module.erc` (see §7.1).

`-> Unit` is the return type. `Unit` is a type with one value, also called `Unit`; it means "no interesting result." `main` in this program does its work, then returns `Unit`.

`with Never` is the mailbox effect. Every process has a mailbox with a fixed message type; `Never` is the type with no values — a mailbox typed `Never` cannot receive anything. `main` here only sends (through `Io.println`), so `Never` fits.

`Io.println` is a stdlib function that sends its argument to a small `Sys.stdout` process the runtime provides. The stdout process receives the text and writes it. `Io.println` writes to `Sys.stdout` only. Diagnostics go to the other sink the runtime provides, `Sys.stderr`, through `Io.printError` and `Io.printlnError`, so a program whose output something else reads can report trouble without corrupting it. To write a string to any other `Address(String)`, a logger say, send to it directly, `send(logger, "starting\n")`; the library has no second print function for that. Messaging to a runtime service is one of two ways Ernest interacts with the outside world (the other is `foreign fn`, §8).

For development output, `Io.debug(x)` prints any value and returns it, so it wraps an expression in place: `let n = Io.debug(f(x))`. It prints the value as the source writes it, by the argument's type: `Io.debug('a')` prints `'a'`, and a named constructor prints with its field names. An address prints as `<address>`, a reply as `<reply>`, and a function as `<function>`. A value of an abstract type prints as `<abstract>` outside its module. Inside a generic function, where the type is a variable, and for a foreign type, it can only go by the runtime's representation, so a `Char` there prints as its code point (report Appendix E.1). It carries `with m` like `Io.println`, so it cannot hide in pure code.

### 1.2 The shell

`ern --shell` starts a shell. An input is an expression or a declaration; it is checked and run when it is entered, and its value is printed with its type.

```console
$ ern --shell
Ernest 0.1.0. :help for the commands, :quit to leave.
> 1 + 2
3 : Int
> let xs = [3, 1, 2]
xs : List(Int)
> List.sort(xs, Int.compare)
[1, 2, 3] : List(Int)
> fn square(n : Int) -> Int = n * n
square : (Int) -> Int
> List.map(xs, square)
[9, 1, 4] : List(Int)
> Io.println("hello")
hello
```

A value of type `Unit` prints nothing, so the last input shows only what it wrote. A command begins with `:`. `:type e` prints the type of `e` without running it, `:doc List.sort` prints the documentation of `List.sort`, and `:help` lists the rest. `ern --shell hello.erc` starts the shell with `hello`'s module in scope and its `main` running beside it.

At a terminal the shell edits the line with Readline's Emacs keys, and keeps a history across sessions that `C-r` searches. `Tab` completes the word before the cursor, by its prefix or by its word starts, `L.fM` to `List.filterMap`, and offers only what may stand there: a type after `:`, a constructor in a pattern, a field inside a constructor's parentheses. `Shift-Tab` shows the type and first sentence of the name at the cursor, and pressed again its documentation. An input the parser cannot finish takes another line. What programs write appears in a region at the foot of the screen, apart from the inputs, and a process that faults is reported at the prompt with the place it was spawned. `:reload` compiles and loads a module whose source has changed, and processes running the old version go on running it.

### 1.3 Prediction exercise

Consider two variations on hello-world, (a) with no annotation:

```ernest
export fn main() = Io.println("hello, world")
```

and (b) with `-> Unit`:

```ernest-rejected
export fn main() -> Unit = Io.println("hello, world")
```

Which of these compile?

Answer: (a) compiles: inference gives `main` a mailbox effect from the call of `Io.println`. (b) does not compile: `-> Unit` with no `with` declares `main` pure, and a pure function cannot call `Io.println`, which sends. It is the mistake of `area` in §0. The `with Never` of hello-world says that `main` runs in a process whose mailbox will never receive. Omitting an annotation is not the same as declaring purity.

## 2. Compute with immutable values

Everything in Ernest is immutable. Bindings introduce names; there is no assignment.

### 2.1 Scalars, Unit, and literals

- **`Int`** — arbitrary precision. Literals: `42`, and in another base `0xFF`, `0o644`, `0b1010`. An `_` between digits groups them: `1_000_000`.
- **`Float`** — IEEE 754 binary64, finite values only. Literal: `3.14`.
- **`Char`** — one Unicode code point. Literal: `'a'`.
- **`String`** — Unicode text. Literal: `"hello"`, with the escapes `\n`, `\t`, `\\`, `\"`, and `\u{1F600}` among them (report §2.5).
- **`Bytes`** — a sequence of octets. Literal: `<<0, 1, 2>>` (§8.6).
- **`Bool`** — `true` or `false`. `&&` and `||` short-circuit, and `!` negates.
- **`Unit`** — one value, also called `Unit`.

A raw string, between backticks, is taken exactly as written, with no escapes. It is the form for text full of backslashes or quotes, and for text over several lines, since a line break in it is part of the text. The shell prints a string as a `"..."` literal, so it shows what the raw string saved writing:

```console
$ ern --shell
Ernest 0.1.0. :help for the commands, :quit to leave.
> let number = `\d+(\.\d+)?`
number : String
> number
"\\d+(\\.\\d+)?" : String
```

`Int` division `/` and remainder `%` by zero fault, and so does `Float` arithmetic whose result would not be finite. `Int.div` and `Int.mod` return `Optional(Int)` instead. A fault ends the process (§6).

`Int` and `Float` are separate types, and nothing converts between them implicitly: `1 + 2.0` is a type error. Convert with `Int.toFloat`, or with `Float.round`, `Float.floor`, `Float.ceil`, or `Float.truncate`.

### 2.2 Bindings and blocks

At the prompt, as in a block, `let` binds a name:

```console
$ ern --shell
Ernest 0.1.0. :help for the commands, :quit to leave.
> let x = 5
x : Int
> let y = x + 1
y : Int
> let area = { let side = 5; side * side }
area : Int
> area
25 : Int
```

A block groups statements between `{` and `}`, separated by `;`. Its value is the last statement, which must be an expression, with no `;` after it. Statements run in order, each to completion. A statement before the last must be `Unit`, and a value dropped on purpose is dropped with `let _ = e`, as in §0.

Shadowing is allowed: a later `let` with the same name hides the earlier one from the next statement on. The original value is unchanged where it was already used; there is no mutation.

**Constants.** A `let` at the top level, outside any `fn`, is a constant, evaluated once before `main` starts. Its name is lowercase like any value's; an uppercase name is a type or a constructor. `export` makes it visible to other modules.

```ernest
let pi : Float = 3.14159265358979
let defaultPort : Int = 8080
export let helloBanner : String = "hello, world"
```

A constant's initializer is pure: setup that sends or spawns belongs in `main`. Constants are evaluated in the order their references need, and a cycle among them is an error (report §8.5).

### 2.3 Sum types and pattern matching

A type declaration names its cases. `Direction` has four *constructors*, and `match` picks between them:

```ernest
type Direction = North | South | East | West

fn opposite(d : Direction) -> Direction = match d {
    North -> South
  | South -> North
  | East -> West
  | West -> East
}
```

The compiler checks that clauses cover every case; a missing case is a type error.

That rule has a shape you will meet again. The report's principle 3, nothing invisible, turns an omission into a statement: exhaustiveness makes you say what every constructor does; `let _ = e` says a value is ignored on purpose; the reply discipline says where each `Reply` is consumed (§4); `export` says what crosses a module's boundary; `with m` says a function acts through a process; a qualified name says which module a name comes from. Several of these tell the compiler nothing it could not work out for itself. What they add is that the decision is written down, where a reader meets it. Principle 1, least surprise, then audits the result. It is programming on purpose, to borrow P.J. Plauger's phrase for designing deliberately rather than by accident — his subject is the whole of software design and broader than any of these rules (*Programming on Purpose: Essays on Software Design*, Prentice Hall, 1993).

Constructors can carry data. `Optional(a)` is the standard example:

```ernest
type Optional(a) = None | Some(a)
```

`Optional(a)` takes a type parameter `a`. `None` carries nothing; `Some(a)` carries one value of type `a`. So `Some(5) : Optional(Int)` and `None : Optional(a)` for any `a`.

Three shapes of constructor, with different usage:

- **Nullary** (`None`, `North`): an ordinary value. Referenced by name.
- **Positional with one field** (`Some(a)`): also a function value of type `(a) -> Optional(a)`. You can pass it: `List.map(xs, Some)` produces `List(Optional(a))`.
- **Named fields** (`Person(name : String, age : Int)`): construction uses the field syntax (`Person(name = "Alice", age = 30)`). Not a function value.

### 2.4 Named fields and `..` update

For constructors that carry several things, name each field:

```console
$ ern --shell
Ernest 0.1.0. :help for the commands, :quit to leave.
> type Person = Person(name : String, age : Int)
type Person
> let alice = Person(name = "Alice", age = 30)
alice : Person
> let older = Person(..alice, age = 31)
older : Person
> older
Person(age = 31, name = "Alice") : Person
```

`..alice` copies the fields not listed, and `age = 31` overrides one. `alice` is unchanged; `older` is a second `Person` value. Ernest uses `:` for types (`name : String`) and `=` for values (`name = "Alice"`); function result types use `->`.

The fields may be given in any order, and are evaluated in the order written. The shell prints them in the order of their names.

### 2.5 Lists, tuples, maps, sets

**Lists** are `List(a)`, with `[]` for the empty list and `::`, right-associative, to add an element in front. **Tuples** are `#(...)`, of fixed size and positional. **Maps and sets** have no literal syntax and are built with functions:

```console
$ ern --shell
Ernest 0.1.0. :help for the commands, :quit to leave.
> let xs = 1 :: [2, 3]
xs : List(Int)
> match xs { [] -> "empty" | head :: _ -> "first is " <> Int.toString(head) }
"first is 1" : String
> let point = #(3, 4)
point : #(Int, Int)
> let #(x, y) = point
x : Int
y : Int
> let m = Map.empty |> Map.put("a", 1) |> Map.put("b", 2)
m : Map(String, Int)
> Map.get(m, "a")
Some(1) : Optional(Int)
> Map.update(m, "a", fn(v) = Optional.withDefault(v, 0) + 1)
Map.fromList([#("a", 2), #("b", 2)]) : Map(String, Int)
> Set.fromList([1, 2, 3])
Set.fromList([1, 2, 3]) : Set(Int)
```

`Map.update` sees the entry as an `Optional`, present or not, and stores what the function returns: the counting idiom in one call.

Map keys and set elements need equality. `==` is defined on every type except one that contains a function or an address, so a map keyed by addresses is a type error. Ordering is separate: `<` needs a `compare` function for the type, which `Int`, `Float`, `String`, and `Char` have (report §3.10).

### 2.6 Patterns and irrefutability

The same patterns appear in `match` clauses, `let` bindings, and function parameters. A `let` and a parameter need an *irrefutable* pattern, one that cannot fail to match: a name, `_`, a tuple of irrefutable patterns, or the only constructor of its type with irrefutable fields.

```console
$ ern --shell
Ernest 0.1.0. :help for the commands, :quit to leave.
> let #(x, y) = #(3, 4)
x : Int
y : Int
> let #(Some(a), b) = #(Some(1), 2)
input:1:1: a `let` pattern must be irrefutable
1 | let #(Some(a), b) = #(Some(1), 2)
  | ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  | = help: use `match` for a pattern that can fail
> type Shape = Rectangle(width : Int, height : Int)
type Shape
> let Rectangle(width = w, height = h) = Rectangle(width = 2, height = 3)
w : Int
h : Int
```

A name in a pattern *introduces* a binding; it does not compare with a variable already bound. To compare, use a guard:

```console
$ ern --shell
Ernest 0.1.0. :help for the commands, :quit to leave.
> let x = 3
x : Int
> match 3 { n when n == x -> "same as x" | _ -> "different" }
"same as x" : String
```

A name appears at most once in a pattern.

A clause may list several patterns separated by `or`; it matches when any of them does. Every alternative binds the same variables at the same types, so the body uses them whichever alternative matched:

```ernest
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

`as` binds the whole value beside its parts: `Some(x) as present` binds `x` to the payload and `present` to the whole `Optional`.

A guard is a pure `Bool` expression. A guard that is `false` passes to the next clause; one that faults faults the process. A guarded clause does not count toward coverage, so a `match` with guards usually ends in an unguarded clause.

### 2.7 `if` and `<-`

`if cond then a else b` is an expression, and both branches have the same type. There is no `if` without `else`. As an operand it is parenthesized: `1 + (if c then a else b)`.

`<-` short-circuits on `Optional`, which is `None | Some(a)` as §2.3 declares it, or on `Either(e, a)`, which is `Left(e) | Right(a)`.

An Optional chain:

```ernest
fn parseAndAdd(a : String, b : String) -> Optional(Int) = {
    let x <- String.toInt(a);
    let y <- String.toInt(b);
    Some(x + y)
}
```

If `String.toInt(a)` returns `None`, the whole block evaluates to `None`; the rest is skipped. `parseAndAdd("2", "3")` returns `Some(5)`; `parseAndAdd("2", "oops")` returns `None`.

An Either chain uses `Left(e)` to short-circuit and `Right(v)` to bind and continue:

```ernest
fn positiveInt(text : String) -> Either(String, Int) = {
    let n <- Either.fromOptional(String.toInt(text), "not an integer");
    if n > 0 then Right(n) else Left("not positive")
}
```

- `positiveInt("3")` → `Right(3)`.
- `positiveInt("oops")` → `Left("not an integer")` — `String.toInt` returned `None`, `Either.fromOptional` turned it into `Left`, and the chain short-circuits.
- `positiveInt("0")` → `Left("not positive")` — the parse succeeded but the explicit branch rejects.

A block is an `Optional` chain or an `Either` chain, never both. To run a step that can fail over every element of a list, `List.tryMap(xs, f)` and `List.tryFold(xs, acc, f)` stop at the first `Left`.

### 2.8 The pipe operator `|>`

Ernest's stdlib is subject-first. `|>` reads left-to-right:

```console
$ ern --shell
Ernest 0.1.0. :help for the commands, :quit to leave.
> "abc" |> String.toList |> List.reverse |> String.fromList
"cba" : String
```

`x |> f` is `f(x)`, and `x |> f(a, b)` is `f(x, a, b)`: the pipe inserts the first argument. A parenthesized right-hand side is a value the pipe applies, so `x |> (adder(3))` is `adder(3)(x)`, and a lambda is written the same way, `x |> (fn(y) = y + 1)`.

### 2.9 The standard library

The standard library is a module per type, `List`, `Map`, `Set`, `String`, `Char`, `Bytes`, `Bool`, `Int`, `Float`, `Optional`, `Either`, `Path`, `Random`, and a few more, and one per system process, `Io`, `Clock`, `Terminal`, `Fs`, `Tcp`. It is always on the load path. Its rules let you guess a name before looking it up (report Appendix E.0):

- **One verb per operation, in every module that has it.** `Map.get(m, k)` and `List.get(xs, 0)`; `size`, `isEmpty`, `contains`, `put`, `remove`, `map`, `filter`, `foldLeft`, `find`, `fromList`, `toList` wherever they apply.
- **Subject first, callbacks last**, so the pipe works: `xs |> List.foldLeft(0, fn(acc, x) = acc + x)`.
- **A conversion is named by the other type**, in the subject's module: `String.toInt`, `Int.toString`.
- **A partial operation returns `Optional`; one with a cause returns `Either`.** `List.get` and `String.toInt` return `Optional`, `Fs.read` returns `Either(IoError, Bytes)`.
- **Pure unless the value lives in a process.** Only the system modules carry `with m`, and every function that takes a function is as pure as the function it is given (§3.5).
- **A `String` is text, not a list.** Its length and positions count what a reader sees as letters; `String.toList` gives its `Char`s.
- **A system process is used through its module**, never by `send`. A function that waits takes a timeout in milliseconds last and may answer `Left(Timeout)`: `Fs.read(path, 5000)`. One that delivers later takes a function that makes the message: `Clock.alarm(100, Tick)` puts `Tick(t)` in the mailbox after 100 ms, `t` being the time it fired.

What a type does not say, the entry in Appendix E does: `List.sort` is stable, `Map.toList` has no order. In the shell, `:doc List.sort` prints it.

### 2.10 A word counter, by hand

Sections 2 to 5 build one program, a word counter, a stage in each. Here it is values at the prompt: a text, its words, and a count kept in a map.

```console
$ ern --shell
Ernest 0.1.0. :help for the commands, :quit to leave.
> let text = "the cat and the hat"
text : String
> let words = String.split(text, " ")
words : List(String)
> words
["the", "cat", "and", "the", "hat"] : List(String)
> let counts = Map.update(Map.empty, "the", fn(n) = Optional.withDefault(n, 0) + 1)
counts : Map(String, Int)
> Map.update(counts, "the", fn(n) = Optional.withDefault(n, 0) + 1)
Map.fromList([#("the", 2)]) : Map(String, Int)
```

`Map.update` counts a word: a word not yet in the map is `None`, and its count starts at 0. Counting every word is a fold over the list with a function, and functions are §3.

### 2.11 Prediction exercise

Given:

```console
$ ern --shell
Ernest 0.1.0. :help for the commands, :quit to leave.
> type Person = Person(name : String, age : Int)
type Person
> let p = Person(name = "Alice", age = 30)
p : Person
> let q = Person(..p, age = 31)
q : Person
```

Does `p` change?

Answer: no. Ernest has no assignment. `q` is a separate `Person` value; `p` is still `Person(name = "Alice", age = 30)`.

## 3. Pass behavior

Functions are values. This section is about writing them and passing them around.

### 3.1 Definitions and arity

```ernest
fn double(n : Int) -> Int = n * 2
fn hypotenuseSquared(a : Int, b : Int) -> Int = a * a + b * b
```

A function body is either a single expression (like `n * 2`) or a block; a block's final statement is an expression, without a trailing semicolon. Arguments evaluate strict left-to-right before the call.

Function arity is fixed and part of the type. `hypotenuseSquared(3, 4)` is `25`. `hypotenuseSquared(3)` is a type error, not a partially applied function. To make a unary version, write a lambda: `fn(b) = hypotenuseSquared(3, b)`.

### 3.2 Lambdas and closures

```console
$ ern --shell
Ernest 0.1.0. :help for the commands, :quit to leave.
> let add1 = fn(x) = x + 1
add1 : (Int) -> Int
> add1(5)
6 : Int
> let n = 10
n : Int
> let addN = fn(x) = x + n
addN : (Int) -> Int
> addN(1)
11 : Int
```

`addN` captures `n`: a lambda closes over the bindings it names.

A lambda's body runs as far as it can, to the `,`, `;`, or closing bracket of the form around it.

### 3.3 Type inference and its limits

Ernest infers types Hindley-Milner style. You can omit annotations on parameters and returns:

```ernest
fn double(n) = n * 2       // inferred (Int) -> Int
```

`*` on `Int` fixes `n : Int`. But **Ernest does not infer a "numeric type" or default to `Int`**:

```ernest-rejected
fn twice(n) = n + n        // n's type ambiguous — annotate: (n : Int) or (n : Float)
```

Without a source that fixes the type, `n + n` is a type error. Once it is fixed, `+` is that type's: `Int.+` for an `Int`, `Distance.+` for a user type that declares it, and `Int.+` is also a function value, as in `List.foldLeft(xs, 0, Int.+)` (report §4.8, report §5.6).

Other limits worth knowing:

- A `fn` and a top-level `let` are polymorphic; a `let` in a block is not. After `let xs = []` in a block, the element type of `xs` must be settled by an annotation or by a later use in the block.
- A `fn` declared in a block is visible in the whole block, but may be used only after the `let`s it reads (report §5.4).

### 3.4 Pure functions and functions with a mailbox effect

A function type without `with M` is *pure*: it cannot perform process operations — no `send`, no `receive`, no `spawn`, no `Address.call`, no effectful `foreign fn`. A function with `with M` may act through a process whose mailbox type is `M`.

Both kinds of function can fault or fail to terminate: `a / b` with `b = 0` faults although its type is `(Int, Int) -> Int`, and `todo("...")` has every type and faults if reached. A fault ends the process; §6 is about what follows.

The mailbox effect says one thing: the function acts through a process. It says nothing about faults.

### 3.5 Higher-order and effect polymorphism

```ernest
fn apply(f, x) = f(x)
```

Inferred type: `((a) -> b with e, a) -> b with e`. The callback's mailbox effect `e` flows through — if `f` is pure, so is `apply(f, x)`; if `f` has effect `M`, `apply(f, x)` has effect `M`. `List.map`, `List.foreach`, and the other combinators in Appendix E work the same way.

An effect variable that appears *only* in effect position (like `e` above) may bind to a mailbox type or to *pure*. An effect variable that also appears in a value position (like `m` in `self : () -> Address(m) with m`) can only bind to a real mailbox type — pure is not a type, so it cannot appear inside `Address(_)`.

The process operations, `self`, `send`, `spawn`, `receive`, `answer`, `Address.call`, `monitor`, `kill`, and `remote`, are *process-only*: the function that uses one has a real mailbox type, never pure (report §3.9).

`ping`'s `m` in §5 is polymorphic but process-only: any real mailbox is admissible, but pure is not.

### 3.6 One spawn corner: pure callbacks

`spawn`'s callback has type `() -> Unit with a`, and the `a` is also the mailbox of the `Address(a)` it returns. A callback declared pure has no mailbox and cannot be spawned. A process that never receives is spawned with the mailbox `Never`:

```console
$ ern --shell
Ernest 0.1.0. :help for the commands, :quit to leave.
> :type spawn
spawn : (Where, () -> Unit with a) -> Address(a) with e
> spawn(Local, fn() -> Unit = Unit)
input:1:14: the argument does not fit spawn: a pure function where one that runs in a process is needed
1 | spawn(Local, fn() -> Unit = Unit)
  | ----- spawn : (Where, () -> Unit with a) -> Address(a) with e
  |              ^^^^^^^^^^^^^^^^^^^
> spawn(Local, fn() -> Unit with Never = Unit)
<address> : Address(Never)
```

### 3.7 The word counter as functions

The counter becomes functions in a file of its own. A file is a module named after it, so the functions of `words.ern` are `Words.count` and the rest to the code outside it (§7.1).

```ernest
// words.ern
export fn words(text : String) -> List(String) =
    String.split(String.toLower(text), " ") |> List.filter(fn(w) = w != "")

export fn count(text : String) -> Map(String, Int) =
    words(text) |> List.foldLeft(Map.empty, fn(counts, w) = add(counts, w, 1))

export fn add(counts : Map(String, Int), word : String, n : Int) -> Map(String, Int) =
    Map.update(counts, word, fn(old) = Optional.withDefault(old, 0) + n)

export fn top(counts : Map(String, Int), n : Int) -> List(#(String, Int)) =
    Map.toList(counts) |> List.sort(byCount) |> List.take(n)

fn byCount(#(w1, c1) : #(String, Int), #(w2, c2) : #(String, Int)) -> Ordering =
    if c1 != c2 then Int.compare(c2, c1) else String.compare(w1, w2)
```

`words` splits on spaces and drops the empty strings two spaces leave. `count` folds the words into a map with `add`. `top` sorts the pairs by count, most first and by word where counts are equal, and keeps `n` of them. `byCount` is not exported, and its parameters are patterns that take the pairs apart. `ern --shell words.erc` loads the module and runs nothing, since it has no `main`:

```console
$ ernc words.ern
$ ern --shell words.erc
Ernest 0.1.0. :help for the commands, :quit to leave.
> Words.count("the cat and the hat")
Map.fromList([#("and", 1), #("cat", 1), #("hat", 1), #("the", 2)]) : Map(String, Int)
> Words.top(Words.count("the cat and the hat"), 2)
[#("the", 2), #("and", 1)] : List(#(String, Int))
```

### 3.8 Prediction exercise

Given:

```ernest
fn map2(f, x, y) = #(f(x), f(y))
```

What does the compiler infer for `map2` when called as `map2(fn(n) = send(addr, n), 1, 2)`?

Answer: `map2`'s inferred type is `((a) -> b with e, a, a) -> #(b, b) with e`. The call binds `a = Int`, `b = Unit`, and `e` to the mailbox effect of `send` — the same as the enclosing function's.

## 4. Run a protocol

A process holds state, receives messages, and answers requests. This section builds a counter.

### 4.1 Message type and receive loop

```ernest
type CounterMsg =
    Inc(Int)
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

A statement has type `Unit`, so a reply-carrying value is never dropped by one: `Get(reply = r); Unit` is a type error.

Consumptions 4 and 5 are why the builder passed to `Address.call` (§4.4) is legal: `fn(r) = Get(reply = r)` places `r` in `Get`, and returning the reply-carrying `CounterMsg` hands the obligation to `Address.call`. `Address.call` in turn consumes the message by sending it to the recipient, transferring the obligation to whichever `receive` clause on the recipient's side eventually binds it. Only `answer(r, v)` finally discharges the underlying `Reply`.

The ownership check is static: it verifies that every syntactically reachable path calls `answer` (or delegates, or shifts). It does not guarantee that execution *reaches* that call at runtime — a path that faults, loops, or waits forever bypasses the answer without invalidating the type check. That is why `Address.call` requires a mandatory timeout (§4.4): the caller must plan for the case where the answer never comes. The check is linearity, not liveness. It proves that every path consumes the reply exactly once, as a move checker does. Whether the path is reached is not provable; the timeout is the answer to that. The one place linearity cannot see, foreign code holding a `Reply`, the runtime covers: a second answer to an answered reply is discarded.

Pattern-matching a reply-carrying scrutinee transfers the obligation to the pattern-bound reply-carrying fields; matching a nullary case (like `Stop` in `PongMsg`, §5) discharges the aggregate obligation with no new binding. A `let` passes the obligation along the same way: after `let r2 = r`, it is `r2` that must be consumed.

A wildcard or omitted reply field, and an `as` alias on a reply-carrying scrutinee, are type errors. Reply-carrying values may not appear as elements of `List`, `Map`, `Set`, `Optional`, or `Either`, or as operands of equality. That last rule is what makes the check decidable, and it has a visible cost: a server that must hold pending replies cannot keep them in a `Map`. It keeps each in a process, one per request, which is what filesync does with one process per write.

A generic helper that duplicates or discards its parameter (`fn dup(x) = #(x, x)`, `fn discard(x) = Unit`) infers a *not-reply-carrying* restriction — the parameter cannot be instantiated to a reply-carrying type. `fn identity(x) = x` passes through without duplication and carries no such restriction. The compiler prints the restriction as a mark on the variable: `dup : (a!) -> #(a!, a!)`, and likewise `equal : (a=, a=) -> Bool` for the equality constraint of §2.5. You never write the marks; you see them in error messages and generated documentation, and `first : (a, b!) -> a` tells you at a glance that `first` cannot be handed a reply as its second argument. No mark appears where it could not matter: in `Optional.withDefault : (Optional(a), a) -> a` the variable `a` is also an `Optional`'s element, which can never be a reply.

Sending a request twice consumes its reply twice:

```ernest-rejected
type CounterMsg = Inc(Int) | Get(reply : Reply(Int))

fn twice(dst : Address(CounterMsg), msg : CounterMsg) -> Unit with m = {
    send(dst, msg);
    send(dst, msg)
}
```

```console
$ ernc resend.ern
resend.ern:5:15: the reply-carrying value msg is consumed twice
4 |     send(dst, msg);
5 |     send(dst, msg)
  |               ^^^
```

### 4.3 Selective receive and `after`

`receive` scans the mailbox for a *matching* message; unmatched messages stay in the mailbox for later. Coverage of the mailbox type is not required (unlike `match`).

```ernest
type Inbox = Data(Int) | Wake

fn waitForData() -> Optional(Int) with Inbox = receive {
    Data(n) -> Some(n)
  | after 1000 -> None
}
```

`after N` gives a millisecond timeout that fires if no clause matches within that window. `after 0` scans without waiting for new messages, and so does any time below 0, so a deadline that has already passed, `deadline - Clock.now()`, needs no check. Without `after`, the process waits indefinitely. A `receive` with only an `after` clause is a timed wait, and is the one `receive` a `Never` process may use.

A guard in `receive` is narrower than one in `match`, since it chooses a message before taking it: it compares variables, literals, and nullary constructors, and calls nothing (report §6.3). For more, receive the message and `match` it.

If a `Wake` is already in the mailbox, `waitForData` skips it — leaves it queued — and waits for a `Data`. Some later `receive` can handle `Wake`.

### 4.4 `Address.call`

Synchronous request-reply, used from the caller side:

```console
$ ern --shell
Ernest 0.1.0. :help for the commands, :quit to leave.
> :type Address.call
Address.call : (Address(a), (Reply(b)) -> a, Int) -> Optional(b) with e
```

`Address.call(c, fn(r) = Get(reply = r), 1000)` allocates a fresh `Reply(a)`, passes it to the builder lambda, sends the resulting message to `c`, and waits up to 1000 ms for the reply; §4.5 uses it. It returns `Some(v)` on success, `None` on timeout.

Four rules:

1. **The deadline starts at invocation.** Build time and send time count against it, and a deadline below 0 is 0.
2. **`None` does not cancel the recipient's work.** The recipient may still be computing; retrying a state-changing request can repeat its effect.
3. **Late answers are silently discarded, and so are second answers.** They never enter the caller's ordinary mailbox. A reply arriving exactly at the deadline may be delivered or discarded — no deterministic tiebreak.
4. **The reply mechanism is private.** `Address.call` works in a process whose declared mailbox is `Never` or any other type; the fresh Reply identifier is separate from the declared mailbox, and reply values never appear there.

For no-timeout callers, `Address.callForever(addr, mk)` waits as long as needed and returns `a` directly (not `Optional(a)`). If the recipient never answers, the caller hangs; that is the point of the name.

### 4.5 Running the counter

The counter of §4.1 with a `main` that uses it, in `counter.ern`:

```ernest
type CounterMsg = Inc(Int) | Get(reply : Reply(Int))

fn counter(n : Int) -> Unit with CounterMsg = receive {
    Inc(k) -> counter(n + k)
  | Get(reply = r) -> { answer(r, n); counter(n) }
}

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

```console
$ ernc counter.ern
$ ern counter.erc
count is 8
```

`spawn(Local, fn() = counter(0))` starts a new process on the current node, running the lambda; the returned `Address(CounterMsg)` is bound to `c`. `Local` versus `Peer("name")` selects where the process runs; peers are in §8. Inside the spawned lambda, `self()` returns the *child's* address, not the parent's — a parent that wants to hand its own address to the child must capture `self()` before spawning: `let me = self(); spawn(Local, fn() = child(me))`.

After the two `send`s and the answered call, `main` returns and the program ends. When `main` returns, every *local* process dies with the reason `ProgramEnd`, which is not a fault; the runtime flushes pending output from system processes and stops. A program stopped from outside, with the terminal's interrupt or the host's termination signal, ends the same way, and the runtime says nothing of its own about it (report §8.6). Workers spawned on peer nodes are unaffected — they run under their peer's runtime.

If the call succeeds, it returns 8: the same sender's two `Inc` messages arrive in order (per-sender FIFO), then `Get` returns the accumulated state, and `main` prints `count is 8`. If the 1000 ms deadline expires before the reply, `main` prints `counter did not answer` — the timeout branch is not dead code.

### 4.6 Explicit code replacement

Ernest processes can update their code without restart. The mechanism is a protocol message the type carries explicitly — no automatic redeployment.

The counter of §4.5 gains an `Upgrade` constructor. The program is three parts of one file, `counter.ern`, which replaces the one of §4.5:

```ernest
// counter.ern
type CounterMsg =
    Inc(Int)
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

```ernest
// counter.ern
fn doublingCounter(n : Int) -> Unit with CounterMsg = receive {
    Inc(k) -> doublingCounter(n + 2 * k)
  | Get(reply = r) -> { answer(r, n); doublingCounter(n) }
  | Upgrade(migrate = m, next = k) -> k(m(n))
}
```

And a `main` that upgrades after the first `Get`:

```ernest
// counter.ern
export fn main() -> Unit with m = {
    let c = spawn(Local, fn() = counter(0));
    send(c, Inc(5));
    send(c, Inc(3));
    match Address.call(c, fn(r) = Get(reply = r), 1000) {
        Some(n) -> Io.println("before upgrade: " <> Int.toString(n))
      | None -> Io.println("timeout")
    };
    send(c, Upgrade(migrate = fn(n) = n, next = doublingCounter));
    send(c, Inc(1));
    match Address.call(c, fn(r) = Get(reply = r), 1000) {
        Some(n) -> Io.println("after upgrade: " <> Int.toString(n))
      | None -> Io.println("timeout")
    }
}
```

```console
$ ernc counter.ern
$ ern counter.erc
before upgrade: 8
after upgrade: 10
```

The address `c` is unchanged; the process behind it is now running `doublingCounter`. After the state 8, `Inc(1)` in the doubling loop adds 2, yielding 10.

### 4.7 The word counter as a process

A tally is a process that holds the counts and adds to them. `words.ern` continues:

```ernest
// words.ern, continued
export type TallyMsg = Add(Map(String, Int)) | Top(n : Int, reply : Reply(List(#(String, Int))))

export fn tally(counts : Map(String, Int)) -> Unit with TallyMsg = receive {
    Add(more) -> tally(Map.foldLeft(more, counts, add))
  | Top(n = n, reply = r) -> { answer(r, top(counts, n)); tally(counts) }
}
```

`Add` brings a map of counts, and `Map.foldLeft` adds each word's count in with `add`, which takes the map, a word, and a count, the order the fold gives them. `Top` is a request, so it carries a `Reply`.

```console
$ ernc words.ern
$ ern --shell words.erc
Ernest 0.1.0. :help for the commands, :quit to leave.
> let t = spawn(Local, fn() = Words.tally(Map.empty))
t : Address(Words.TallyMsg)
> send(t, Words.Add(Words.count("the cat and the hat")))
> send(t, Words.Add(Words.count("the bat")))
> Address.call(t, fn(r) = Words.Top(n = 2, reply = r), 1000)
Some([#("the", 3), #("and", 1)]) : Optional(List(#(String, Int)))
```

A `send` is `Unit`, which the shell does not print.

### 4.8 Prediction exercise

Does `Address.call(c, ..., 1000)` returning `None` guarantee the recipient did no work?

Answer: no. The timeout only bounds the caller's wait. The recipient may still be processing the request or may answer later; the late answer is silently discarded but the work done on the recipient side is not undone.

## 5. Manage process lifetime

The counter is enough for one process. Two processes need coordination.

### 5.1 Ping-pong

```ernest
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

```console
$ ern --shell
Ernest 0.1.0. :help for the commands, :quit to leave.
> :type monitor
monitor : (Address(a), (Down) -> b) -> Unit with b
```

```
type Down = Down(reason : Reason, function : String)
type Reason = Returned | Killed | ProgramEnd | Fault(String)
```

`monitor(child, wrap)` asks the runtime to place `wrap(d)` in *your* mailbox when `child` dies, or at once if it is already dead. `wrap` adapts the runtime's `Down` into your mailbox type — in ping-pong, `PongDone` is a constructor of `MainMsg` that carries a `Down`. `PongDone(_)` accepts any death reason; it signals *termination*, not *success* — a faulting pong would still deliver `PongDone(Down(reason = Fault(_), ...))`. `function` in `Down` is the qualified name of the function that called `spawn` for the dead process, with the line of the call, `Counter.main:19`; for the entry process it is the entry point's name (report §6.9).

`wrap` is a function, so it can carry what you need to tell one death from another. A process that monitors a worker while waiting for its answer gets two messages, the answer and the death, and takes the answer; the death is still in the mailbox when the next worker is monitored. Addresses have no equality, so a `Down` cannot be asked which worker it is about. Give each worker a number and let the wrap close over it:

```ernest
type MainMsg = Result(run : Int, value : Int) | Died(run : Int, down : Down)

fn work(n : Int) -> Int = n * n

fn runWorker(run : Int) -> Optional(Int) with MainMsg = {
    let me = self();
    let child = spawn(Local, fn() -> Unit with Never =
        send(me, Result(run = run, value = work(run))));
    monitor(child, fn(d) = Died(run = run, down = d));
    waitFor(run)
}

fn waitFor(run : Int) -> Optional(Int) with MainMsg = receive {
    Result(run = r, value = v) when r == run -> Some(v)
  | Died(run = r, down = _) when r == run -> None
  | Died(run = _, down = _) -> waitFor(run)
}

fn report(run : Int) -> Unit with MainMsg = match runWorker(run) {
    Some(v) -> Io.println("run " <> Int.toString(run) <> ": " <> Int.toString(v))
  | None -> Io.println("run " <> Int.toString(run) <> ": the worker died")
}

export fn main() -> Unit with MainMsg = {
    report(1);
    report(2)
}
```

```console
$ ern runs.erc
run 1: 1
run 2: 4
```

A death whose run is not the one being waited for is an earlier worker's, and `waitFor` passes over it. This is what the report means by identity being expressed in the protocol: the protocol is yours, and the wrap is where you put the identity in it.

A fault in one process does not affect another, apart from the three cases of §6.3.

### 5.3 `kill`

```console
$ ern --shell
Ernest 0.1.0. :help for the commands, :quit to leave.
> :type kill
kill : (Address(a)) -> Unit with e
```

`kill(addr)` requests termination of the process at `addr`; anyone monitoring receives `Down(reason = Killed, ...)`. It is a scheduling event, not an instantaneous halt — the target may run briefly before the runtime interrupts it. The REPL paper program combines `monitor` and `kill` into a supervised-child pattern that gives up after a timeout.

### 5.4 Deadlock as a safety net

When forward progress is impossible, the entry process faults with `Fault("deadlock")`, and the program ends as on any fault of the entry process, reporting `fault: deadlock`. Progress is impossible when every live process waits in `receive` without `after`, no message is in flight, no monitor waits on a process the runtime did not start, and no system process or connected peer holds a subscription, a timer, a pending I/O, or a computation whose completion would deliver a message. Pending `after`s, network listeners, keyboard subscribers, and a process this node spawned on a peer, while it runs, all count as such a source, so an idle server waiting on external events is not deadlocked. Detection is per node; a distributed deadlock across peers may not be detected.

### 5.5 Adapting messages with `via`

`monitor(child, wrap)` takes a function from the runtime's `Down` to your mailbox type. The standard library's system modules use the same shape wherever something arrives later: `Clock.alarm(ms, wrap)` puts `wrap(t)` in your mailbox after `ms` milliseconds, `t` the time it fired, and `Terminal.subscribe(wrap)` puts every key pressed and every resize in it. A constructor with one positional field is a function value, so `Clock.alarm(100, Tick)` delivers `Tick(t)`, and a message that needs no time is made by a lambda that ignores it, `Clock.alarm(100, fn(_) = Tick)`, as the game below does.

Between your own processes the general form is `via`:

```console
$ ern --shell
Ernest 0.1.0. :help for the commands, :quit to leave.
> :type via
via : ((a) -> b, Address(b)) -> Address(a)
```

`via(convert, target)` returns an `Address(a)` that, on receipt of an `a`, applies `convert` and delivers the resulting `b` to `target`. A worker written to report to an `Address(Either(String, Int))` knows nothing of your `GameMsg`; you hand it `via(Done, self())`, where `Done` is the constructor of `GameMsg` that carries a result, and `Done(r)` arrives in your mailbox. `monitor` and `Clock.alarm` are `via` with `self()` already filled in.

An adapted address is the target and the function, not a process, so adapting costs nothing to keep. `convert` runs where the sending happens, and a fault in it is the target's: the process behind the address dies of it and the sender goes on (report §6.5). Keep `convert` to shaping the value — a constructor, a small function — and leave the work to the receiver.

`Clock.alarm` fires exactly *once*. For a periodic tick, the receiver schedules a new one only after handling the previous. A naive `game` that loops back on every message would create one pending timer per input, so a burst of inputs multiplies the tick rate. Two functions make the boundary explicit:

```ernest
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

### 5.6 The word counter at once

Several texts are counted at once, by a worker each, and the tally totals them. `words.ern` gets its `main`:

```ernest
// words.ern, continued
type MainMsg = Counted(Map(String, Int)) | Died(Down)

export fn main() -> Unit with MainMsg = {
    let totals = spawn(Local, fn() = tally(Map.empty));
    countAll(totals, ["the cat and the hat", "the bat and the ball", "a cat"]);
    match Address.call(totals, fn(r) = Top(n = 3, reply = r), 1000) {
        Some(best) -> List.foreach(best, fn(#(w, c)) = Io.println(w <> " " <> Int.toString(c)))
      | None -> Io.println("the tally did not answer")
    }
}

fn countAll(totals : Address(TallyMsg), texts : List(String)) -> Unit with MainMsg = {
    let me = self();
    List.foreach(texts, fn(text) = {
        let worker = spawn(Local, fn() -> Unit with Never = send(me, Counted(count(text))));
        monitor(worker, Died)
    });
    collect(totals, List.size(texts))
}

fn collect(totals : Address(TallyMsg), left : Int) -> Unit with MainMsg =
    if left == 0 then Unit
    else receive {
        Counted(counts) -> { send(totals, Add(counts)); collect(totals, left - 1) }
      | Died(Down(reason = Fault(cause), function = _)) -> {
            Io.println("a worker faulted: " <> cause);
            collect(totals, left - 1)
        }
      | Died(_) -> collect(totals, left)
    }
```

```console
$ ernc words.ern
$ ern words.erc
the 4
and 2
cat 2
```

Each worker counts one text and sends the map to `main`, not to the tally. Messages are ordered per sender only (§5.1), so an `Add` a worker sent to the tally could arrive after the `Top` that `main` sends; sent by `main`, they arrive in order. `main` monitors every worker, so one that faults is counted as done and reported. `collect` passes over the `Down` of a worker that returned, whose `Counted` has already counted it.

### 5.7 Prediction exercise

Given the ping-pong program, does the runtime guarantee ping and pong's `Io.println` output appears in strictly alternating order?

Answer: no. Per-sender FIFO orders messages from ping to pong and pong to ping, but the two processes both send to `Sys.stdout` — that is fan-in from two senders, and the runtime does not order across senders. Alternation is a *possible* trace, not a guaranteed one.

## 6. Handle failure

Something goes wrong in one of three ways, and each has its place. A failure the caller can act on is a value. A failure another process must act on is a message. What the program did not expect is a fault, which ends the process it happens in, and the processes that watch it decide what follows. Nothing is caught: there is no exception to throw and no handler to catch one, so the path a failure takes is always in the code.

### 6.1 A value

A failure the caller can act on is returned: `Optional` when absence is the whole story, `Either` when there is a reason. `<-` passes a `Left` on without a line written for it (§2.7), and a statement cannot drop one (§0).

```ernest
type Config = Config(port : Int, workers : Int)

fn field(text : String, name : String) -> Either(String, Int) = {
    let n <- Either.fromOptional(String.toInt(text), name <> " is not a number");
    if n > 0 then Right(n) else Left(name <> " must be positive")
}

fn parse(port : String, workers : String) -> Either(String, Config) = {
    let p <- field(port, "port");
    let w <- field(workers, "workers");
    Right(Config(port = p, workers = w))
}

fn show(c : Either(String, Config)) -> String = match c {
    Right(Config(port = p, workers = w)) ->
        "port " <> Int.toString(p) <> ", " <> Int.toString(w) <> " workers"
  | Left(reason) -> "no config: " <> reason
}

export fn main() -> Unit with Never = {
    Io.println(show(parse("8080", "4")));
    Io.println(show(parse("8080", "four")))
}
```

```console
$ ern config.erc
port 8080, 4 workers
no config: workers is not a number
```

`field` checks one number, `parse` chains two checks and stops at the first `Left`, and `show` is the one place that decides what a failure means.

### 6.2 A message

Between processes a failure is part of the protocol. A request whose work can fail is answered with an `Either`, and the process that asked handles a `Left` as it handles any answer. `Address.call` adds a case of its own, `None`, for an answer that did not come in time; a deadline is the only way to tell a slow process from one that will never answer.

```ernest
type ParserMsg = Parse(text : String, reply : Reply(Either(String, Int)))

fn parser() -> Unit with ParserMsg = receive {
    Parse(text = t, reply = r) -> {
        answer(r, Either.fromOptional(String.toInt(t), t <> " is not a number"));
        parser()
    }
}

fn ask(p : Address(ParserMsg), text : String) -> String with m =
    match Address.call(p, fn(r) = Parse(text = text, reply = r), 1000) {
        Some(Right(n)) -> "parsed " <> Int.toString(n)
      | Some(Left(reason)) -> "refused: " <> reason
      | None -> "no answer in time"
    }

export fn main() -> Unit with Never = {
    let p = spawn(Local, fn() = parser());
    Io.println(ask(p, "42"));
    Io.println(ask(p, "forty-two"))
}
```

```console
$ ern ask.erc
parsed 42
refused: forty-two is not a number
```

The parser refuses the text and goes on serving. A refusal is an answer, not a failure of the parser.

### 6.3 A fault

A fault is what the program did not expect: a division by zero, a `todo` reached, a `Float` result out of range. Report §7.4 lists them all. A fault ends the process it happens in, and only that process. A process that monitors it receives a `Down` whose reason is `Fault(cause)`:

```ernest
type MainMsg = WorkerDied(Down)

fn average(total : Int, count : Int) -> Int = total / count

fn worker(count : Int) -> Unit with Never =
    Io.println(Int.toString(average(100, count)))

export fn main() -> Unit with MainMsg = {
    let w = spawn(Local, fn() = worker(0));
    monitor(w, WorkerDied);
    receive {
        WorkerDied(Down(reason = Fault(cause), function = site)) ->
            Io.println("the worker spawned at " <> site <> " faulted: " <> cause)
      | WorkerDied(_) -> Io.println("the worker ended")
    }
}
```

```console
$ ern faults.erc
the worker spawned at Faults.main:9 faulted: division by zero
```

`average` is pure and still faults. A type says what a function returns when it returns, not that it will. The `function` of a `Down` names the function that spawned the process and the line of the call.

Three faults reach beyond their process. A fault in the entry process ends the program: `ern` prints `fault: ` and the cause, and exits with status 1. A fault in the function of an adapted address (§5.5) is the fault of the process the address names. A fault in the callback of `remote` is the fault of the process that called it (§8.1). A process that is killed, or that ends with the program, has not faulted. A deadlock is a fault of the entry process (§5.4).

### 6.4 Let it crash

A worker need not guard against what it did not expect. It faults, and the process that watches it decides what follows: it tries again, gives up, or ends too. The recovery is written once, in the watcher, and the worker's code is only its work. The watcher is a supervisor, and it is spawn, monitor, and receive:

```ernest
type SupMsg = Result(Int) | Ended(Down)

fn supervise(jobs : List(Int)) -> Unit with SupMsg = match jobs {
    [] -> Io.println("all jobs done")
  | job :: rest -> {
        let me = self();
        let worker = spawn(Local, fn() -> Unit with Never = send(me, Result(100 / job)));
        monitor(worker, Ended);
        Io.println(Int.toString(job) <> ": " <> outcome());
        supervise(rest)
    }
}

// The worker's answer, or the fault that ended it. A worker that returned
// sent its answer first, so its end is taken with the answer and is not
// left for the next worker.
fn outcome() -> String with SupMsg = receive {
    Ended(Down(reason = Fault(cause), function = _)) -> "failed, " <> cause
  | Ended(_) -> receive { Result(n) -> Int.toString(n) }
}

export fn main() -> Unit with SupMsg = supervise([4, 0, 5])
```

```console
$ ern jobs.erc
4: 25
0: failed, division by zero
5: 20
all jobs done
```

A process for each job is the restart: the job that faulted ends its own worker, and the next job starts with a fresh one. Only `supervise` prints. A worker's `Io.println` and the supervisor's are two senders to `Sys.stdout`, which the runtime does not order (§5.1), so a worker reports by a message to its supervisor.

What must survive a fault lives in the process that does not fault: here the list of jobs is the supervisor's. A process that restarts a long-lived service gets a new process with a new address, and whoever held the old address must be sent the new one, since there is no registry to look it up in (report §6.5). A process that must not outlive another monitors it and returns when it dies.

### 6.5 Prediction exercise

```ernest
fn first(xs : List(Int)) -> Int = match xs {
    x :: _ -> x
  | [] -> todo("first of an empty list")
}
```

What happens when `main` calls `first([])`, and how would you make the empty list the caller's to handle?

Answer: `main` faults with the cause `todo: first of an empty list`, and since it is the entry process the program ends and `ern` prints `fault: todo: first of an empty list`. To give the case to the caller, return `Optional(Int)`, as `List.get` does: `[] -> None`.

## 7. Organize code

An Ernest program is one or more modules. A module is a `.ern` source file; its path *is* its namespace. Modules may not depend on each other in a cycle; a cycle is a compile-time error (report §4.1).

### 7.1 Modules and namespaces

Two modules:

```ernest
// net/http.ern  (namespace Net.Http)
export type Request = Request(method : String, path : String)

export fn parse(s : String) -> Optional(Request) =
    if s == "GET /" then Some(Request(method = "GET", path = "/"))
    else None
```

```ernest
// main.ern  (namespace Main)
export fn main() -> Unit with Never = match Net.Http.parse("GET /") {
    Some(Net.Http.Request(method = method, path = path)) ->
        Io.println(method <> " " <> path)
  | None -> Io.println("bad request")
}
```

The `Net.Http.Request` in the pattern is a fully qualified constructor reference — same shape as the one that appears in `Net.Http.parse`'s definition, seen from outside the module.

Compile file-by-file and run:

```console
$ ernc net/http.ern              # produces net/http.erc
$ ernc main.ern                  # produces main.erc
$ ern main.erc                   # net/http.erc is found under main.erc's root, which is on the load path
GET /
```

Or in directory mode — compile the whole tree and put outputs under `build/`:

```console
$ ernc --out-dir build .         # walks the source tree, writes build/net/http.erc and build/main.erc
$ ern build/main.erc
GET /
```

Directory mode compiles in dependency order automatically, creates missing subdirectories under `build/`, and, after a successful build, removes `.erc` files whose `.ern` is gone and the directories that empties (`--no-clean` disables the sweep; single-file mode never sweeps). It's the recommended pattern once a project has more than one file. A second run rebuilds only what changed: a module whose source changed, whose dependency's interface changed, or that another version of `ernc` built; any change to a standard library interface rebuilds every module. A change to a dependency's bodies alone leaves its dependents as they are (report §11.1).

**The file's path is its namespace.** A file at `a/b/c.ern` under the source root provides declarations at namespace `A.B.C`. The source root is `--source-root dir`; without it, the current directory when one file is compiled and the directory passed when a tree is. A file of the standard library's own `stdlib/` always takes that directory as its root (report §4.2, report §11.1). Each path segment is one lowercase word; each namespace segment is the path segment with its first letter uppercased and the rest unchanged (`http.ern` → `Http`, `httpv2.ern` → `Httpv2`). A multi-word module is a nested directory, `http/parser.ern` for `Http.Parser` (report §11.1), so the mapping is one-to-one. A module namespace may not coincide with a namespace of the prelude or the standard library, so `io.ern` at the source root is an error, nor with a type namespace of its parent module: `main/stack.ern` is an error when `main.ern` declares `Stack` (report §4.2). Where the parent declares no such type, the child is reached from it by its whole name, `Main.Stack.push` in `main.ern`.

**Declarations use local names.** Inside `net/http.ern`, `export fn parse(...)` declares the function at its local name `parse`; the compiler exports it as `Net.Http.parse`. There is no file-namespace prefix on the declaration itself — repeating `Net.Http.` on every line would just restate the file's path.

**`export` marks the boundary.** A declaration prefixed with `export` is visible from other modules; a declaration without `export` is private to its own file. No `import`, no export list, no `pub`. `export` may prefix any top-level declaration: `fn`, `type`, `abstract type`, `let`, `foreign fn`, or `foreign type`. Constructors of an exported concrete type are exported with the type — `export type Optional(a) = None | Some(a)` makes `None` and `Some` visible to other modules; `type Internal = A | B` keeps the type and both constructors private. An abstract type controls constructor visibility through its `with { ... }` signature, not through `export`: the type name is `export`ed, its accessors are separately `export`ed if they should be public, and the constructor stays visible only to the definitions listed in the signature.

**An exported declaration is made of exported types.** The type of an exported declaration may not name a type its own module keeps private: a caller that holds such a value could neither build one nor print it. Export the type with it, or, where the values should cross the boundary but the constructors should not, declare it `abstract type` (report §4.2, §4.4). A function's effect is not part of this, so an entry point may receive a private message type.

**External references use the qualified name.** A caller outside `net/http.ern` writes `Net.Http.parse`. Inside `net/http.ern`, unqualified `parse` refers to the local declaration, and `Net.Http.parse` works there too (report §4.2), which is how a documentation example is written.

**A module's own name hides the prelude's.** A module may declare its own `Close` or `Entry`, and the name then means its own throughout the module. `Prelude.Close` still names the prelude's, in a pattern, a construction, or a type (report §4.2).

**Testing a module.** A test is a top-level `let` of the prelude type `Test`, a name and a function returning `Passed` or `Failed(text)`:

```ernest
fn add(a : Int, b : Int) -> Int = a + b

let addsTwo = Test(name = "adds two", run = fn() -> TestResult with Never =
    if add(1, 1) == 2 then Passed else Failed("not two"))
```

```console
$ ernc checks.ern
$ ern --test checks.erc
adds two: passed
```

`ern --test module.erc` runs every test of the module, exported or not, each in a process of its own, and prints each as passed, failed with its text, or faulted with its cause. A test runs as a process root, `with Never`, so it may spawn, send, and call; `ern --test` exits 1 unless every test passed; one that needs `receive` spawns a process for it (report §9.3, report §11.2).

**Documenting a module.** A `///` block documents what follows it on the next line: a declaration, a constructor, a named field, or a signature entry. A `///` block first in the file, with a blank line after it, documents the module. The text is CommonMark, and `ernc --doc` renders the module as a page: the title, each declaration's type in a code block, and the text. The documentation travels in the compiled module, so `--doc` reads a `.erc` as well as a `.ern` (report §11.4). An example in a doc block ends with `// => v`, the value `Io.debug` prints, and the standard library's tests run it and compare. An example that cannot run where the page's examples run, because its value is of an abstract type, because it reads a file or a socket, or because it needs a mailbox of its own, carries no such line and is only type-checked. What a module's documentation must contain is Appendix E.0 rule 6 of the report; [`docs/module_doc_template.md`](docs/module_doc_template.md) shows it on a fictive module, generated and kept true by a test (report §2.2 and report §11.4).

**Entry point.** `ern main.erc` looks up `export fn main` in the loaded module and invokes it. `main` is a naming convention, not a reserved specialness — any exported function with the entry-point shape `() -> Unit with M` can be selected. If `tools.ern` exports a `check` function of that shape, run it as:

```console
$ ern --main Tools.check build/main.erc
```

`--main` takes a fully qualified name whose final segment is a lowercase function name (`Tools.check`, not `Tools.Check`). This is how a project with multiple entry points — a service main, a migration main, a bench main — keeps each in its own module.

### 7.2 Abstract types

Abstract types have a private representation and a public signature. Only definitions listed in the `with { ... }` signature can mention the constructor. Any locally declared type — abstract or concrete — creates a nested namespace inside its module, and its members are declared with a single-typename prefix (`fn Stack.push`). Report §4.8 shows the concrete-type variant used for per-type operator overloading (`fn Distance.+`, and so on); an operator is declared with `fn`, never with `let`. From another module an abstract type's constructor is not visible at all: `Main.Stack([])` there is an error, and callers go through the signature.

```ernest
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

export fn Stack.isEmpty(s : Stack(a)) -> Bool = match Stack.pop(s) {
    None -> true
  | Some(_) -> false
}
```

Inside `main.ern` the accessors are written and used with the `Stack.` prefix (`Stack.push(x, s)`). External callers see `Main.Stack` for the type and `Main.Stack.push` for the operation, because `main.ern`'s namespace `Main` prefixes everything the module exports. The type-member namespace is *owned* by the file that declares the type: `Main.Stack.push` is compiled into `main.erc`, not a hypothetical `main/stack.erc`, and the loader consults `main.erc`'s compiled interface to find it.

`Stack.empty`, `Stack.push`, `Stack.pop` are listed in the `with { ... }` signature, so their bodies may name the `Stack` constructor. `Stack.isEmpty` is not listed, and uses the operations instead. A definition that is not listed and names the constructor is refused, even in the same module:

```ernest-rejected
export abstract type Stack(a) = Stack(List(a)) with {
    empty : Stack(a)
}

export let Stack.empty : Stack(a) = Stack([])

export fn Stack.size(Stack(xs) : Stack(a)) -> Int = List.size(xs)
```

```console
$ ernc hidden.ern
hidden.ern:7:22: the constructor Stack of abstract type Stack may appear only in the definitions its signature names
6 | 
7 | export fn Stack.size(Stack(xs) : Stack(a)) -> Int = List.size(xs)
  |                      ^^^^^^^^^
```

An abstract type's representation can change later (a tree, a growable array), and callers built against the signature continue to work as long as each operation's observable contract is preserved.

Two `Stack(a)` declarations on two nodes are one type only when their representation, qualified name, and signature all match (report §8.7). The same signature over a list on one node and a tree on another is two types.

### 7.3 Prediction exercise

Can a helper in the same file as `Stack` — but not listed in the `with { ... }` signature — pattern-match `Stack(xs)`?

Answer: no. Access is granted by the signature, not by the module. The helper can call `Stack.pop`, `Stack.push`, and any other listed operation, but it cannot see the constructor.

## 8. Cross boundaries

Two ways Ernest reaches outside a single node's Ernest code: to peers over the network, and to foreign code on the same node.

A node that talks to peers has a configuration, which a node running alone does not need. `ern --create-config-dir .` creates it, once, in `./.ernest/`: `ernest.conf`, with this node's network address, its public key and an empty list of peers, and the private key beside it. The command fails if `./.ernest` exists. A peer is added to the list by editing `ernest.conf` (report Appendix C), and its name is what `Peer(name)` refers to.

### 8.1 `remote`

Run a pure computation on some peer:

```console
$ ern --shell
Ernest 0.1.0. :help for the commands, :quit to leave.
> :type remote
remote : (() -> a) -> Either(RemoteError, a) with e
```

```
type RemoteError = NoRemotePeer | PeerLost
```

`remote(f)` hands `f` to the runtime, which picks a peer and runs `f()` there. `f` is pure by `remote`'s design — `remote` is a one-shot compute-and-return, not a process; effectful work on a peer goes through `spawn(Peer(...), ...)`.

`remote` has a mailbox effect: `Left(NoRemotePeer)` when no peer is configured for remote computation (`"remote-peer": true`), `Left(PeerLost)` when the peer is lost before the value returns. A fault in the callback faults the caller with the same cause, as calling it locally would: `remote` computes elsewhere and catches nothing. A peer-side resolution failure faults the caller too, with `Fault("peer resolution failed: ...")`, as it does `spawn(Peer(...), ...)`. Work whose fault should not end the caller runs in a process of its own, monitored.

`remote` waits for its answer, so several computations run at once from processes of their own, each calling `remote` and answering when asked. The answers come back in the order they were asked for:

```ernest
type Ask(a) = Ask(reply : Reply(Either(RemoteError, a)))

fn inParallel(fs : List(() -> a)) -> List(Either(RemoteError, a)) with m = {
    let workers = List.map(fs, fn(f) = spawn(Local, fn() -> Unit with Ask(a) = {
        let v = remote(f);
        receive { Ask(reply = r) -> answer(r, v) }
    }));
    List.map(workers, fn(w) = Address.callForever(w, fn(r) = Ask(reply = r)))
}
```

A minimal program that submits a computation:

```ernest
fn heavy(a : Int, b : Int) -> Int = a * a + b * b

export fn main() -> Unit with m = match remote(fn() = heavy(3, 4)) {
    Right(n) -> Io.println("remote returned " <> Int.toString(n))
  | Left(NoRemotePeer) -> Io.println("no remote peer configured")
  | Left(PeerLost) -> Io.println("peer lost")
}
```

This program needs `ernest.conf` to list at least one peer with `"remote-peer": true` before `Right(...)` is possible.

### 8.2 Code shipping

Four operations ship a closure or payload and the code it depends on: `spawn(Peer(name), f)`, `remote(f)` and the return of its result, `send` to a remote address, and `answer(r, v)` to a caller on another node. The peer resolves each referenced hash — it uses cached code if present, or fetches from the sender. Types, functions, and constructors are identified across nodes by content hash; two nodes with identical definitions under the same qualified names agree on identity, and a type's name is part of its identity.

Some consequences the code sees:

- A `Sys.*` name referenced by shipped code resolves *on the peer that runs the code*. A shipped `Io.println` sends to the peer's `Sys.stdout`.
- A captured address value ships as a value — its target is whichever process it pointed to when the closure was formed, not re-resolved on the peer.
- Top-level bindings referenced by shipped code are initialized on demand on the peer, in the peer's environment. `let output = Sys.stdout` gives the sender's stdout on the sender and the peer's on the peer.
- `send` to a remote address returns immediately; a peer-side resolution failure faults the sender *asynchronously*, after `send` has already returned.
- Foreign definitions must be available and compatible on the peer.

Peer loss is *terminal from this node's view*. Once this node declares a peer lost, it treats the processes on that peer as dead. Their existing addresses do not become usable again if the same peer name reappears — a re-appearing peer is a new node instance. Monitors on remote addresses report `Down(reason = Fault("peer lost"), ...)`, and pending `remote` calls return `Left(PeerLost)`. Remote sends are best-effort: in-flight messages can be dropped at peer loss without a delivery notification, and returning from `send` is not evidence that the recipient processed the message. A resolution failure does not, on its own, invalidate unrelated addresses for the same peer — only *actual* peer-loss detection has that effect.

### 8.3 Foreign types and functions

```ernest
// ets.ern
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

### 8.4 Node-local foreign values

Foreign values are bound to the node that made them. Any cross-node transport of a value that transitively contains one faults with `Fault("foreign value cannot cross nodes")` — including a closure that captures such a value.

A `Random.Seed` is such a value. The closure below captures one, so shipping it to the peer `alice` faults:

```ernest
export fn main() -> Unit with Never = {
    let seed = Random.seed(42);
    let _ = spawn(Peer("alice"), fn() -> Unit with Never = {
        let #(n, _) = Random.next(seed, 6);
        Io.println(Int.toString(n))
    });
    Unit
}
```

A program that needs such state on another node sends what the state is made of and rebuilds it there: here the number 42, from which the peer makes its own seed.

### 8.5 The shim pattern

Erlang's `ets:lookup` returns a list because the key might match zero or one entry. Both declarations below live in `ets.ern` (namespace `Ets`), a module of your own:

```ernest
// ets.ern
export foreign type Table(k, v)

export fn lookup(t : Table(k, v), key : k) -> Optional(v) with m =
    match rawLookup(t, key) { [#(_, v)] -> Some(v) | _ -> None }

foreign fn rawLookup(t : Table(k, v), key : k)
    -> List(#(k, v)) with m = "ets:lookup/2"
```

`rawLookup` has no `export`, so it is file-local. `Ets.lookup` is the typed API callers use, by its qualified name.

Erlang's `{ok, V} | {error, R}` convention does not automatically match an Ernest `Either(e, a)`. Ernest's `Either` constructors are `Left(e)` and `Right(a)`, and under the ABI of report §8.4 they encode as `{'Left', e}` and `{'Right', a}` (quoted, source-preserving). Erlang's `{ok, V}` uses the lowercase atom `ok`, which is a different value.

The cleanest fix is a small Erlang-side helper that produces the Ernest-shaped return. For a foreign call whose Ernest declaration is `Either(String, Int)`, the helper's payloads must already match Ernest's ABI: `V` an integer, and `R` a UTF-8 binary, Ernest's `String`:

```erlang
-module(store_helper).
-export([lookup/1]).

lookup(Key) ->
    case find(Key) of
        {ok, V} -> {'Right', V};
        {error, R} -> {'Left', R}
    end.

find(<<"answer">>) -> {ok, 42};
find(Key) -> {error, <<"no entry for ", Key/binary>>}.
```

The Ernest `foreign fn` binds to that helper, and the term it returns is already an Ernest `Either`:

```ernest
// store.ern (namespace Store)
export foreign fn lookup(key : String) -> Either(String, Int) with m = "store_helper:lookup/1"

export fn main() -> Unit with Never = match lookup("answer") {
    Right(n) -> Io.println("found " <> Int.toString(n))
  | Left(reason) -> Io.println(reason)
}
```

`ern` finds an Erlang module of your own as a `.beam` in a directory of its load path, which includes the root of the module it runs (report §11.2):

```console
$ erlc -o build store_helper.erl
$ ernc --out-dir build store.ern
$ ern build/store.erc
found 42
```

If `find/1` returns reasons of another shape (an atom, a nested tuple), the Erlang helper must convert them to the declared Ernest form before returning; the Ernest side does not paper over ABI-shape breaches. In the other direction, a `foreign fn` that takes a `Foreign` is given one by `Foreign.from(value)`, which is the value as the runtime already holds it (Appendix E.12), and `Erl.atom(name)` builds the atoms such an API expects.

Report Appendix D walks `ets.ern` (namespace `Ets`), a library outside the standard library, as its worked example of a shim; the repository ships it under `libs/ets`, and a program adds it with `--load-path` (report §11.1). Its foreign calls happen to already match Ernest's ABI (`[{K, V}]` maps to `List(#(k, v))`, `Bool` to `true`/`false`), so it needs no Erlang wrapper. This is also the shape of every library outside the standard library: JSON, TLS, regular expressions, HTTP are not in Appendix E, by E.0's rules, since each is a namespace of its own with policy inside; they are written as `Ets` is written, by anyone, under a namespace Appendix E does not take, and put on the load path when a program wants them. A foreign library may also hold what the standard library does not: an `Ets` table is state that every process holding it reads and writes (report §4.7), where the standard library keeps report §10's promise that processes share no memory. Which are first-party, and when, is the plan's.

### 8.6 Bitstrings

Building and parsing binary formats:

```ernest
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
- **`bytes`** — segment is a nested byte-aligned `Bytes` value; unit is 8 bits.
- **`int`**, **`float`** — numeric (defaults: 8-bit `int`, 64-bit `float`).
- **`utf8`**, **`utf16`**, **`utf32`** — text encoding.
- **`big`**, **`little`** — endianness. A format states its byte order; data in the host's own order comes through foreign code, which converts it.
- **`signed`**, **`unsigned`** — sign.

A segment without specifiers is `int` of size 8, which is why `<<0, 1, 2>>` is three bytes. `int` binds to `Int`, `float` to `Float`, the `utf` forms to `Char`, `bytes` to `Bytes`.

**Alignment and range rules:**

- A bitstring produces a `Bytes` value; the total bit count must be a multiple of 8.
- A `bytes` segment must itself be byte-multiple, whatever its unit. Sub-octet fields use the `int` specifier (binding to `Int`).
- Compile-time-constant alignment violations are compile-time errors. Dynamic-size violations fault in construction and fail matching in patterns.
- A segment value that does not fit its specified width — an `Int` too large for `size(N)-int` at construction — is a fault.
- Four fixed limits (report §5.11): `unit` is 1 to 256; a `float` segment is 16, 32, or 64 bits; a `utf` segment takes no size; a sizeless `bytes` segment is the last one.

What a `Bytes` value holds is read with the `Bytes` module (Appendix E.20): `Bytes.size` and `Bytes.isEmpty`, `Bytes.get` for one octet, `Bytes.slice`, and `Bytes.toList` and `Bytes.fromList` between a `Bytes` and a `List(Int)`. A `Bytes` is not a container, so its octets go through `toList`, as a `String`'s characters do. Text crosses with `String.toUtf8` and `String.fromUtf8`.

A segment pattern is a variable, `_`, or a literal; a float literal `0.0` matches the bytes of either zero (report §3.1). `size(Expr)` in a pattern is a variable of an earlier segment or the enclosing function, an `Int` literal, or `+`, `-`, `*` of these, evaluated while matching. A `match` over bitstring patterns ends with a `_` or variable clause, as `parseFrame` does: the checker does not decide whether bitstring patterns cover every `Bytes` value.

**Precondition for `frame`/`parseFrame`:** the round trip works when `len` equals `body`'s byte count *and* `len` fits in the length-field width (16 bits, so 0 to 65 535). `parseFrame(frame(1, <<65, 66>>))` returns `Some(#(1, <<65>>, <<66>>))` — a one-byte body and a one-byte remainder, not an error, because `len = 1` was chosen. If `len` doesn't fit the width, `frame` faults at construction.

Bitstrings compile to the runtime's bit syntax (report §5.11, report §10).

### 8.7 Prediction exercise

Suppose `send(remoteAddr, msg)` returns immediately, and 50 ms later the peer reports a resolution failure. What happens to the sending process?

Answer: the runtime faults the sending process asynchronously, after `send` has already returned. Code that followed the `send` may have executed; the fault interrupts the process where it currently is, not at the site of `send`.

## 9. Frequently asked questions

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

## 10. Reading further

Which programs under `examples/` the toolchain runs today is the `PROGRAMS` macro in `test/ern_integration_tests.erl`. The four paper programs below compile today. Three run under test, with fixed input and a bounded run: the REPL, the file sync, and the web server. The snake game waits for a terminal, which no test can give it, so it is only compiled.

The four paper programs, in ascending complexity:

- [`examples/snake.ern`](examples/snake.ern) — snake game with tick-based updates; `..` record updates, one process per player, `Clock`, `Terminal`, `Random`.
- [`examples/repl.ern`](examples/repl.ern) — small read-eval-print loop; `<-` for chained parsing, `monitor` + `kill` for aborting slow evaluation, `Io.readLine`.
- [`examples/filesync.ern`](examples/filesync.ern) — file sync between two nodes; mutual-address setup, one process per file operation, `Fs`.
- [`examples/webserver.ern`](examples/webserver.ern) — HTTP server with sessions in a process that owns a `Map`; request-reply, abstract types, `Tcp`.

Beyond `Io.println` and `Clock`, the paper programs use `Fs`, `Terminal`, `Tcp`, and `Io.readLine`, all of which the toolchain has.

For the language rules themselves, [`ernest_report.md`](ernest_report.md) is the authority. Appendix F glosses every technical term.

For why Ernest looks the way it does — what was tried and rejected — [`decisions.md`](docs/decisions.md) records dated design decisions.
