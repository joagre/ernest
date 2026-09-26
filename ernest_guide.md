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

Every error in a program has this form: the position as `file:line:column`, the message, and the source with the error's span underlined with `^`. A span the error depends on is underlined with `-` and labelled, here the type of `send`, whose two arguments must agree. The names in these examples, `spawn`, `send`, `Reply`, and `with`, are taught in §1 to §4; here only the errors matter.

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

**A failure dropped.** `Fs.write` returns `Either(IoError, Unit)`: the file was written, or the reason it was not. Its last argument, `1000`, is how many milliseconds it may take. A statement in a block must be `Unit`, so the failure cannot pass unseen. `let _ = ...` discards it where that is meant.

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
- **Distribution by content, planned and not yet built.** Unison's content addressing, on the Erlang runtime. Every function and type is known by a hash of its definition, a type's name included, so a message is checked across nodes as it is within one. Code travels with what uses it: a closure sent to a peer brings the definitions it needs, and the peer fetches what it has not seen. Two nodes need not run the same version of a program, and two versions of a type are two types, never one type read two ways (§8).

Sections 1 to 8 are eight stages: run a program, compute with values, pass behavior, run a protocol, manage process lifetime, handle failure, organize code, and cross boundaries. Each builds on the ones before it and ends with an exercise, whose answer is in §13. A complete program is shown whole; a fragment is part of the program around it. After the stages come the tools (§9), a word for the Erlang programmer (§10), the design behind the rules (§11), and questions a reader asks (§12).

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

`ernc` compiles a `.ern` file to a compiled module, `.erc`. `ern` loads it and the modules it uses, the standard library among them, starts the runtime's processes, and calls `main`. §9 lists both tools' options.

### 1.1 What the line says

`fn` begins a function definition, and `export` makes it visible outside the module. `ern` runs the function `main` of the module it loads; `--main` names another (§7.1).

`-> Unit` is the result type. `Unit` is a type with one value, also written `Unit`, the result of a function whose work is its effect.

`with Never` names the mailbox. A function that sends or receives runs in a process, whose mailbox takes one type of message, and its type says which with `with`. `main` runs in the program's first process, the *entry process*. `Never` is the type with no values, so a process whose mailbox is `Never` receives nothing, which suits a `main` that only sends.

Two ways of writing `with` follow, and the guide's programs use both. A function that starts a process that never receives, such as `main` or the function a spawned process runs, is written `with Never`; a lambda spawned for such a process is written `fn() -> Unit with Never = ...`, since no `receive` in it settles its mailbox type. A function that only sends, such as `Io.println`, is written `with m`, a type variable, so that a process with any mailbox may call it.

`Io.println` sends its text to `Sys.stdout`, a process the runtime provides, which writes it. `Io.printlnError` sends to `Sys.stderr`, so a program whose output another program reads can still report trouble. Sending to a process of the runtime is one of the two ways a program reaches the world; the other is `foreign fn` (§8).

`Io.debug(x)` prints any value as the source would write it and returns it, so it wraps an expression where it stands: `let n = Io.debug(f(x))`. It sends, as `Io.println` does, so it cannot hide in a pure function (report Appendix E.1).

### 1.2 The shell

`ern --shell` starts a shell. An input is an expression, a declaration, or a `let`. It is checked and run when it is entered, after any input still running, and an expression's value is printed with its type and kept as `it`.

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

A value of type `Unit` prints nothing, so the last input shows only what it wrote. A command begins with `:`. `:type e` prints the type of `e` without running it, `:doc List.sort` prints the documentation of `List.sort`, and `:help` lists the rest. `ern --shell hello.erc` starts the shell with `hello`'s module in scope and its `main` running beside it. A module without `main` is put in scope with nothing running, to be tried at the prompt.

At a terminal the shell edits the line with Readline's Emacs keys, and keeps a history across sessions that `C-r` searches. An input the parser cannot finish takes another line. What programs write appears in a region at the foot of the screen, apart from the inputs, and a process that faults is reported at the prompt with the place it was spawned. A fault, an error, and a refused command are shown in red and a result's type dimmed, and documentation is styled, unless the environment sets `NO_COLOR`. A line wider than the screen wraps as it is typed.

`Tab` completes the word before the cursor, by its prefix or by its word starts, `S.pS` to `String.padStart`. It offers only what may stand there: a command after a leading `:` and what the command takes after it, a type after `:` in an annotation, a constructor in a pattern, a field inside a named constructor's parentheses. A name completed alone is shown under the line with its type, and a second `Tab`, or one with nothing to add, lists the candidates there alphabetically, until the next key. With nothing typed they are the session's names, the modules, and the prelude's names, and every other name comes from its first letters; at the start of a row `Tab` indents instead. `Shift-Tab` shows the type, the first sentence, and the version of the name at the cursor, and pressed again its documentation. Inside a call, on no documented name, it shows the callee's signature with the parameter at the cursor marked, and inside a constructor its fields.

`:load` compiles a module from its source and puts it in scope, and `:reload` compiles and loads again a loaded module whose source has changed. Where one of the changed modules does not compile, `:reload` loads none of them. Processes running the old version go on running it, and a binding that holds a function of it keeps it, until the next reload of that module, which ends the processes and forgets the bindings.

### 1.3 Reading input

`Io.readLine()` waits for a line of standard input and answers `Some(line)`, or `None` at its end. A program that reads its input to the end loops:

```ernest
export fn main() -> Unit with Never = match Io.readLine() {
    Some(line) -> { Io.println(String.toUpper(line)); main() }
  | None -> Unit
}
```

```console
$ printf 'hello\nworld\n' | ern upper.erc
HELLO
WORLD
```

An entry point takes no arguments, so a program's input comes on standard input. A program reads lines or single keys, not both: `Terminal.subscribe` gives keys as they are pressed (report §8.2).

### 1.4 Prediction exercise

Consider two variations on hello-world, (a) with no annotation:

```ernest
export fn main() = Io.println("hello, world")
```

and (b) with `-> Unit`:

```ernest-rejected
export fn main() -> Unit = Io.println("hello, world")
```

Which of these compile?

## 2. Compute with immutable values

Everything in Ernest is immutable. Bindings introduce names; there is no assignment.

### 2.1 Scalars, Unit, and literals

- **`Int`** — arbitrary precision. Literals: `42`, and in another base `0xFF`, `0o644`, `0b1010`. An `_` between digits groups them: `1_000_000`.
- **`Float`** — IEEE 754 binary64, finite values only. Literal: `3.14`.
- **`Char`** — one Unicode scalar value, a code point other than a surrogate. Literal: `'a'`.
- **`String`** — Unicode text. Literal: `"hello"`, with the escapes `\n`, `\t`, `\\`, `\"`, and `\u{1F600}` among them (report §2.5). `<>` joins two strings, and a type's `toString` makes its text: `"n = " <> Int.toString(3)`. There is no interpolation.
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

The compiler checks that clauses cover every case; a missing case is a type error. So is a clause that can never match, because the clauses above it take every value it would: after `North -> South`, a second `North -> ...` is never reached.

Constructors can carry data. `Optional(a)` is the standard example:

```ernest
type Optional(a) = None | Some(a)
```

`Optional(a)` takes a type parameter `a`. `None` carries nothing; `Some(a)` carries one value of type `a`. So `Some(5) : Optional(Int)` and `None : Optional(a)` for any `a`.

Three shapes of constructor, with different usage:

- **Nullary** (`None`, `North`): an ordinary value. Referenced by name.
- **Positional** (`Some(a)`): one value, and the constructor is also a function, `(a) -> Optional(a)`, so it can be passed: `List.map(xs, Some)`. A constructor takes one positional value or named fields; several values without names are a tuple, `Point(#(Int, Int))`.
- **Named fields** (`Person(name : String, age : Int)`): construction uses the field syntax (`Person(name = "Alice", age = 30)`). Not a function value.

### 2.4 Named fields, selection, and `..` update

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
> older.age
31 : Int
```

`older.age` reads one field. `..alice` copies the fields not listed, and `age = 31` overrides one. `..` works on a type with one constructor, since the value might otherwise have been built by another. `alice` is unchanged; `older` is a second `Person` value. Ernest uses `:` for types (`name : String`) and `=` for values (`name = "Alice"`); function result types use `->`.

The fields may be given in any order, and are evaluated in the order written. The shell prints them in the order of their names.

A type with several constructors has a field only where every constructor has it, with one type: in `type Shape = Dot(at : Point) | Circle(at : Point, radius : Int)`, `s.at` reads any shape's point, and `s.radius` is refused, since a `Dot` has none; a `match` reads it. An abstract type's fields are its own module's (§7.2).

### 2.5 Lists, tuples, maps, sets

**Lists** are `List(a)`, with `[]` for the empty list and `::`, right-associative, to add an element in front. **Tuples** are `#(...)`, of fixed size and positional. **Maps and sets** have no literal syntax and are built with functions. In the session, `|>` passes a value on as the first argument (§2.8), and `fn(v) = ...` is a function written in place (§3.2):

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

Map keys and set elements need equality. `==` is defined on every type except one that contains a function or an address, so a map keyed by addresses is a type error. In a printed type, a variable that needs equality is marked `=`: `List.contains : (List(a=), a=) -> Bool`. An annotation does not write the mark; the compiler infers it from the body.

Ordering is separate: `a < b` asks the type's `compare`, which answers `Less`, `Equal`, or `Greater`. `Int`, `Float`, `String`, and `Char` have one, and a type of your own gets one by declaring it in its module. A function named `Money.compare` is a member of the type `Money` (§7.2):

```ernest
type Money = Money(Int)

fn Money.compare(Money(a) : Money, Money(b) : Money) -> Ordering = Int.compare(a, b)

export fn main() -> Unit with Never =
    Io.println(if Money(3) < Money(5) then "cheaper" else "not cheaper")
```

```console
$ ern money.erc
cheaper
```

### 2.6 Patterns and irrefutability

The same patterns appear in `match` clauses, `let` bindings, and function parameters. A `let` and a parameter need an *irrefutable* pattern, one that cannot fail to match: a name, `_`, a tuple of irrefutable patterns, the only constructor of its type with irrefutable fields, or an irrefutable pattern with `as`, which comes below.

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
- `positiveInt("oops")` → `Left("not an integer")`: `String.toInt` returned `None`, which `Either.fromOptional` turned into a `Left`, and the chain stopped.
- `positiveInt("0")` → `Left("not positive")`: the parse succeeded, and the `if` refused the value.

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

The standard library is a module per type, `List`, `Map`, `Set`, `String`, `Char`, `Bytes`, `Bool`, `Int`, `Float`, `Optional`, `Either`, `Path`, `Random`, and a few more, and the system modules `Io`, `Clock`, `Terminal`, `Fs`, and `Tcp`, through which a program uses the runtime's system processes. It is always on the load path. Its rules let you guess a name before looking it up (report Appendix E.0):

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

A lambda's body extends as far as the text allows: to the `,`, `;`, `|`, `>>`, or closing bracket of the form around it, or to a `then` or `else`.

### 3.3 Type inference and its limits

Ernest infers types Hindley-Milner style. You can omit annotations on parameters and returns:

```ernest
fn double(n) = n * 2       // inferred (Int) -> Int
```

`*` on `Int` fixes `n : Int`. But **Ernest does not infer a "numeric type" or default to `Int`**:

```ernest-rejected
fn twice(n) = n + n        // n's type ambiguous — annotate: (n : Int) or (n : Float)
```

Without a source that fixes the type, `n + n` is a type error. Once it is fixed, `+` is that type's: `Int.+` for an `Int`, `Distance.+` for a user type that declares it as a member, `fn Distance.+`, and `Int.+` is also a function value, as in `List.foldLeft(xs, 0, Int.+)` (report §4.8, report §5.6).

Other limits worth knowing:

- A `fn` and a top-level `let` are polymorphic; a `let` in a block is not. After `let xs = []` in a block, the element type of `xs` must be settled by an annotation, by a later use in the block, or by `xs` reaching the block's result.
- A `fn` declared in a block is visible in the whole block, but may be used only after the `let`s it reads (report §5.4).

### 3.4 Pure functions and functions with a mailbox effect

A function whose type has no `with` is *pure*. It cannot send, receive, spawn, ask for its own address, or call a `foreign fn` that has an effect. A function with `with M` may act through a process whose mailbox takes `M`.

Either kind of function can fault or run for ever: `a / b` with `b = 0` faults although its type is `(Int, Int) -> Int`, and `todo("...")` has every type and faults when it is reached. The `with` says only that a function acts through a process, not whether it can fault (§6).

### 3.5 Higher-order and effect polymorphism

```ernest
fn apply(f, x) = f(x)
```

The inferred type is `((a) -> b with e, a) -> b with e`: `apply` has the effect of the function it is given, so `apply(f, x)` is pure when `f` is. `List.map`, `List.foreach`, and every other function of the standard library that takes a function are the same.

An effect variable may stand for a mailbox type or for pure. One that also appears inside `Address`, as in `self : () -> Address(m) with m`, stands for a mailbox type only, since an address needs one. The letters in a printed type mean nothing of their own.

The process operations, `self`, `send`, `spawn`, `receive`, `answer`, `Address.call`, `Address.callForever`, `monitor`, `kill`, and `remote`, are *process-only*: the function that uses one has a real mailbox type, never pure (report §3.9).

### 3.6 One spawn corner: a callback's mailbox

`spawn`'s callback has type `() -> Unit with n`, and the `n` is also the mailbox of the `Address(n)` it returns. A pure function fits wherever one with a mailbox type is expected, so a pure callback is spawned too, and its mailbox is whatever the address is used as. When nothing says, the type of the address is not determined. A process that never receives is spawned with the mailbox `Never`:

```console
$ ern --shell
Ernest 0.1.0. :help for the commands, :quit to leave.
> :type spawn
spawn : (Where, () -> Unit with n) -> Address(n) with m
> spawn(Local, fn() -> Unit = Unit)
<address> : Address(a)
`it` is unchanged: this input did not determine the type of its value
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

`counter` keeps its state in the parameter `n`, and its mailbox takes `CounterMsg`. `receive` waits for a message that matches a clause and evaluates that clause. Both clauses call `counter` again with the new state; a tail call does not grow the stack, so the loop runs for ever.

A `Reply(Int)` is where an answer goes. The process that asks puts one in its request, and the process that receives the request answers it with `answer(r, n)`.

### 4.2 A reply is answered once

A `Reply` is an obligation: whoever holds one answers it exactly once, on every path, and the compiler checks it, as §0 showed. The obligation moves with the value. Sending a message that carries a reply, passing it to a function, returning it, or putting it in a constructor hands the obligation on; only `answer(r, v)` discharges it. A value that contains a reply is *reply-carrying*, as `CounterMsg` is because of `Get`, and the same rule holds for it.

The check is on paths, not on time. A path that faults or waits for ever never answers, and no compiler can see that; the caller's deadline covers it (§4.4).

Since each reply is counted, a reply-carrying value is never copied or dropped. It cannot be an element of a `List`, a `Map`, a `Set`, an `Optional`, or an `Either`, nor an operand of `==` or `!=`, and `_` cannot stand for one in a pattern. A server with many requests pending keeps each reply in a process of its own, as the queue of §4.4 does. In a printed type, a variable marked `!` is one that may not hold a reply, as in `dup : (a!) -> #(a!, a!)` for a function that copies its argument. Report §6.6 gives the whole discipline.

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

`receive` takes the first message that matches a clause and leaves the others in the mailbox for later. Unlike `match`, it need not cover every case, but a clause that can never match is still an error.

```ernest
type Inbox = Data(Int) | Wake

fn waitForData() -> Optional(Int) with Inbox = receive {
    Data(n) -> Some(n)
  | after 1000 -> None
}
```

`after 1000` gives up after 1000 milliseconds with no matching message, and `after 0` looks without waiting. Without `after`, the process waits for as long as it takes. A `receive` with only an `after` clause is a timed wait, the one `receive` a process with mailbox `Never` may use.

A guard in `receive` is narrower than one in `match`, since it chooses a message before taking it: it compares variables, literals, and nullary constructors, tests a `Bool` variable, and joins these with `!`, `&&` and `||`; it calls nothing (report §6.3). For more, receive the message and `match` it.

If a `Wake` is already in the mailbox, `waitForData` leaves it there and waits for a `Data`; a later `receive` can take the `Wake`.

### 4.4 `Address.call`

Synchronous request-reply, used from the caller side:

```console
$ ern --shell
Ernest 0.1.0. :help for the commands, :quit to leave.
> :type Address.call
Address.call : (Address(m), (Reply(a)) -> m, Int) -> Optional(a) with n
```

`Address.call(c, fn(r) = Get(reply = r), 1000)` makes a fresh `Reply`, gives it to the function that builds the request, sends the request to `c`, and waits up to 1000 ms. It returns `Some(v)` for an answer and `None` for none. `None` does not cancel the work: the recipient may still be computing, so a request that changes state and is sent again may change it twice. An answer that comes late is dropped and never reaches the caller's mailbox, so `Address.call` works whatever that mailbox's type is (report §6.6). `Address.callForever` waits without a deadline and returns the answer itself; if none comes, the caller waits for ever.

A server that cannot answer at once keeps the reply in a small process that answers later, since a reply-carrying value cannot wait in a list (§4.2). A queue answers a `Take` with an item it has, or spawns a waiter that holds the reply until a `Put` brings one:

```ernest
type QueueMsg = Put(Int) | Take(reply : Reply(Int))
type WaiterMsg = Item(Int)
type MainMsg = Took(Int)

// Items no one has asked for yet, and the callers waiting for an item, each
// a process that holds its caller's reply.
fn queue(items : List(Int), waiters : List(Address(WaiterMsg))) -> Unit with QueueMsg =
    receive {
        Put(x) -> match waiters {
            w :: rest -> { send(w, Item(x)); queue(items, rest) }
          | [] -> queue(items <> [x], [])
        }
      | Take(reply = r) -> match items {
            x :: rest -> { answer(r, x); queue(rest, waiters) }
          | [] -> {
                let w = spawn(Local, fn() -> Unit with WaiterMsg =
                    receive { Item(x) -> answer(r, x) });
                queue([], waiters <> [w])
            }
        }
    }

export fn main() -> Unit with MainMsg = {
    let q = spawn(Local, fn() = queue([], []));
    let me = self();
    let _ = spawn(Local, fn() -> Unit with Never =
        send(me, Took(Address.callForever(q, fn(r) = Take(reply = r)))));
    send(q, Put(7));
    receive { Took(x) -> Io.println("took " <> Int.toString(x)) }
}
```

```console
$ ern queue.erc
took 7
```

The waiter's lambda captures `r` and is given straight to `spawn`, which hands the obligation to the new process. The queue keeps the waiters' addresses, which may be in a list.

### 4.5 Running the counter

The counter of §4.1 with a `main` that uses it, in `counter.ern`:

```ernest
type CounterMsg = Inc(Int) | Get(reply : Reply(Int))

fn counter(n : Int) -> Unit with CounterMsg = receive {
    Inc(k) -> counter(n + k)
  | Get(reply = r) -> { answer(r, n); counter(n) }
}

export fn main() -> Unit with Never = {
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

`spawn(Local, fn() = counter(0))` starts a process on this node that runs the lambda, and returns its `Address(CounterMsg)`. `Local` says where the process runs; `Peer(name)` is another node (§8). Inside the lambda, `self()` is the new process's address, so a parent that gives the child its own address takes it first: `let me = self(); spawn(Local, fn() = child(me))`.

When `main` returns, the program ends: every process on the node ends with the reason `ProgramEnd`, which is not a fault, and output still on its way is written first. A program stopped from outside, by the terminal's interrupt or a signal, ends the same way (report §8.6).

The count is 8 because messages from one sender arrive in the order sent: both `Inc`s come before the `Get`. Were the counter too slow, `main` would print `counter did not answer`.

### 4.6 Explicit code replacement

A process can change its code while it runs, keeping its address and its state. The new code arrives in a message that the process's type provides for, as a function value: here one compiled into the program, in the shell one from a module that `:reload` compiled again, and with peers one shipped from another node (§8.2).

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

`Upgrade` carries two functions: `migrate` turns the old state into the new, and `next` is the new loop. `k(m(n))` is a tail call into the new loop with the migrated state.

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
export fn main() -> Unit with Never = {
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

The address `c` is unchanged, and the process behind it now runs `doublingCounter`, where `Inc(1)` adds 2.

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

## 5. Manage process lifetime

Two processes that talk must also know when the other is done.

### 5.1 Ping-pong

```ernest
type PongMsg = Ping(n : Int, reply : Reply(Int)) | Stop
type MainMsg = PongDone(Down)

export fn main() -> Unit with MainMsg = {
    let pongAddr = spawnMonitored(Local, fn() = pong(), PongDone);
    let _ = spawn(Local, fn() = ping(pongAddr, 3));
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

`ping` never receives, so its mailbox `m` is any type; it must be a real one, since `Address.call` runs only in a process (§3.5).

`main` monitors pong and waits for it to end. Had `main` returned at once, the program would have ended before the two had played, since returning from `main` ends every process (§4.5).

The output is likely `ping 3`, `pong 3`, `ping 2`, and so on, but not certain. Messages from one sender arrive in the order sent, so ping's requests reach pong in order. Ping and pong are two senders to `Sys.stdout`, and between senders there is no order.

### 5.2 `monitor` and `Down`

```console
$ ern --shell
Ernest 0.1.0. :help for the commands, :quit to leave.
> :type monitor
monitor : (Address(a), (Down) -> m) -> Unit with m
> :type spawnMonitored
spawnMonitored : (Where, () -> Unit with n, (Down) -> m) -> Address(n) with m
```

```ernest-prelude
type Down = Down(reason : Reason, function : String)
type Reason = Returned | Killed | ProgramEnd | Fault(String) | Unknown
```

`monitor(child, wrap)` puts `wrap(d)` in your mailbox when `child` dies, or at once if it is dead already, with the reason `Unknown`, since the runtime keeps nothing of a process that has ended. A process you start yourself is watched from its start with `spawnMonitored(Local, f, wrap)`, `spawn` and `monitor` in one step, so that no end comes before the watch. `wrap` makes your message from the runtime's `Down`: in ping-pong, `PongDone` is a constructor of `MainMsg` that carries one. A `Down` says the process ended, not that it succeeded; its `reason` says how, and its `function` names the function that spawned it and the line, `Counter.main:19`.

`wrap` is a function, so it can carry what you need to tell one death from another. A process that monitors a worker while waiting for its answer gets two messages, the answer and the death, and takes the answer; the death is still in the mailbox when the next worker is monitored. Addresses have no equality, so a `Down` cannot be asked which worker it is about. Give each worker a number and let the wrap close over it:

```ernest
type MainMsg = Result(run : Int, value : Int) | Died(run : Int, down : Down)

fn work(n : Int) -> Int = n * n

fn runWorker(run : Int) -> Optional(Int) with MainMsg = {
    let me = self();
    let _ = spawnMonitored(Local, fn() -> Unit with Never =
        send(me, Result(run = run, value = work(run))), fn(d) = Died(run = run, down = d));
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

A death whose run is not the one being waited for is an earlier worker's, and `waitFor` passes over it. Identity is part of the protocol you write, and the wrap is where you put it.

A fault in one process does not affect another, apart from the three cases of §6.3.

### 5.3 `kill`

```console
$ ern --shell
Ernest 0.1.0. :help for the commands, :quit to leave.
> :type kill
kill : (Address(a)) -> Unit with m
```

`kill(addr)` ends the process at `addr`, and its monitors receive `Down(reason = Killed, ...)`. The process may run a little before it stops. The REPL of [`examples/repl.ern`](examples/repl.ern) kills an evaluation that runs too long.

### 5.4 Deadlock

When every process waits in a `receive` that nothing can ever satisfy, the program ends with `fault: deadlock`. A process waiting for a timer, a key, a socket, or a file is waiting for something that can come, so an idle server is not deadlocked. Report §8.6 gives the exact condition.

### 5.5 Adapting messages with `via`

`monitor`'s `wrap` is a function to your mailbox type, and the system modules take one wherever something arrives later: `Clock.alarm(ms, wrap)` puts `wrap(t)` in your mailbox after `ms` milliseconds, `t` the time it fired, and `Terminal.subscribe(wrap)` puts every key pressed and every resize in it. A constructor with one positional field is a function value, so `Clock.alarm(100, Tick)` delivers `Tick(t)`, as the game below does. A message that needs no time is made by a lambda that ignores it, `Clock.alarm(100, fn(_) = Refresh)` for a constructor `Refresh` without fields.

Between your own processes the general form is `via`:

```console
$ ern --shell
Ernest 0.1.0. :help for the commands, :quit to leave.
> :type via
via : ((a) -> b, Address(b)) -> Address(a)
```

`via(convert, target)` is an `Address(a)`: an `a` sent to it arrives at `target` as `convert(a)`. A worker written to report to an `Address(Either(String, Int))` knows nothing of your `GameMsg`; you give it `via(Done, self())`, and its result arrives as `Done(r)`. An adapted address is not a process and costs nothing to keep. A fault in `convert` ends the target's process, not the sender's (report §6.5), so keep `convert` to shaping the value.

`Clock.alarm` fires once. A periodic tick is scheduled again after each tick is handled, and only then: a loop that scheduled one on every message would add a timer per key pressed. Two functions keep the two apart:

```ernest
type GameMsg = Tick(Int) | Input(Char)
type World = World(score : Int)

fn step(w : World) -> World = World(score = w.score + 1)

fn game(state : World) -> Unit with GameMsg = {
    Clock.alarm(100, Tick);
    waitForTick(state)
}

fn waitForTick(state : World) -> Unit with GameMsg = receive {
    Tick(_) -> game(step(state))
  | Input(_) -> waitForTick(state)
}
```

`game` schedules one alarm and hands over to `waitForTick`, which takes inputs without touching the alarm; only a `Tick` returns to `game`, which schedules the next. `step` reads the world's field with a pattern.

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
        let _ = spawnMonitored(Local, fn() -> Unit with Never = send(me, Counted(count(text))),
            Died);
        Unit
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

Each worker counts one text and sends the map to `main`, not to the tally. Messages are ordered per sender only (§5.1), so an `Add` a worker sent to the tally could arrive after the `Top` that `main` sends; sent by `main`, they arrive in order. `main` monitors every worker, so one that faults is counted as done and reported. A worker that returned is counted by its `Counted`, so `collect` passes over its `Down`, whichever of the two arrives first.

### 5.7 Prediction exercise

Given the ping-pong program, does the runtime guarantee ping and pong's `Io.println` output appears in strictly alternating order?

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

A fault is what the program did not expect: a division by zero, a `todo` reached, a `Float` result out of range. Report §7.4 lists them all, and a failure of the runtime, out of memory among them, is one too (report §7.3). A fault ends the process it happens in, and only that process. A process that monitors it receives a `Down` whose reason is `Fault(cause)`:

```ernest
type MainMsg = WorkerDied(Down)

fn average(total : Int, count : Int) -> Int = total / count

fn worker(count : Int) -> Unit with Never =
    Io.println(Int.toString(average(100, count)))

export fn main() -> Unit with MainMsg = {
    let _ = spawnMonitored(Local, fn() = worker(0), WorkerDied);
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
        let _ = spawnMonitored(Local, fn() -> Unit with Never = send(me, Result(100 / job)),
            Ended);
        Io.println(Int.toString(job) <> ": " <> outcome());
        supervise(rest)
    }
}

// The worker's answer, or the fault that ended it. A worker that returned
// has sent its answer, so after its end the answer is taken too, whichever
// arrived first, and neither is left for the next worker.
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

## 7. Organize code

A program is one or more modules. A module is a `.ern` file, and its path is its namespace. Two modules may not depend on each other, directly or through others (report §4.1).

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

`main.ern` names the constructor `Net.Http.Request` by its whole name, as it names the function.

Compile file-by-file and run:

```console
$ ernc net/http.ern              # produces net/http.erc
$ ernc main.ern                  # produces main.erc
$ ern main.erc                   # net/http.erc is found under main.erc's root, which is on the load path
GET /
```

Or compile the whole tree at once, into `build/`:

```console
$ ernc --out-dir build .         # walks the source tree, writes build/net/http.erc and build/main.erc
$ ern build/main.erc
GET /
```

Directory mode compiles the modules in the order their dependencies need, and a second run compiles again only what changed (§9.1).

**The file's path is its namespace.** A file at `a/b/c.ern` under the source root declares the namespace `A.B.C`: each directory and the file name is one lowercase word, and the namespace capitalizes each. A module of two words is a directory, `http/parser.ern` for `Http.Parser`. The source root is `--source-root dir`; without it, the directory `ernc` is given, or for a single file the working directory. A module may not take a namespace the prelude or the standard library has, so `io.ern` at the root is refused (report §4.2, report §11.1).

**Declarations use local names.** In `net/http.ern`, `export fn parse(...)` declares `parse`, which the code outside reaches as `Net.Http.parse`, and the code inside by either name.

**`export` marks the boundary.** A declaration with `export` is visible from other modules, and one without is the module's own. There is no `import` and no export list. The constructors of an exported type are exported with it; an abstract type's constructors are visible only in its own module (§7.2). An exported declaration's type, and the fields of an exported type that is not abstract, may name only exported types. A function's mailbox type is exempt, so an exported `main` may receive a private message type (report §4.2).

**A module's own name hides the prelude's.** A module may declare its own `Close`, which then means its own throughout the module; `Prelude.Close` still names the prelude's (report §4.2).

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

`ern --test` runs every test of the module, each in a process of its own, and prints each as passed, failed with its text, or faulted with its cause. A test runs in a process, so it may spawn and send (report §11.2).

**Documenting a module.** A `///` block documents the declaration on the line after it, and one first in the file, with a blank line after it, documents the module. The text is CommonMark; `ernc --doc` renders the module as a page, and the shell's `:doc` shows a declaration's part of it, or a module's head, rendered for the terminal. What a module's documentation contains is report Appendix E.0 rule 6, and [`docs/module_doc_template.md`](docs/module_doc_template.md) shows it on an example module.

**Entry point.** `ern main.erc` runs `export fn main`, and `--main` runs another exported function that takes no arguments and returns `Unit`. A project with several programs keeps each entry point in a module of its own:

```console
$ ern --main Tools.check build/main.erc
```

### 7.2 Abstract types

An abstract type keeps its representation to its module: every definition in the module may name its constructor, and no other module can. A type's operations are declared with its name before theirs, `fn Stack.push`, and the type is then a namespace inside its module; report §4.8 declares operators on a type the same way, `fn Distance.+`.

```ernest
// main.ern  (namespace Main)
export abstract type Stack(a) = Stack(List(a))

export let Stack.empty : Stack(a) = Stack([])
export fn Stack.push(x : a, Stack(xs) : Stack(a)) -> Stack(a) = Stack(x :: xs)
export fn Stack.pop(Stack(xs) : Stack(a)) -> Optional(#(a, Stack(a))) =
    match xs { [] -> None | x :: rest -> Some(#(x, Stack(rest))) }

export fn Stack.size(Stack(xs) : Stack(a)) -> Int = List.size(xs)
```

Inside `main.ern` the operations are `Stack.push` and the rest, and any definition may take a `Stack` apart, a private helper or a test included. Outside, they are `Main.Stack.push`, and `Main.Stack([])` is an error: another module sees the type and the operations, never the constructor.

An abstract type is exported, since one its module keeps would hide from no module:

```ernest-rejected
abstract type Stack(a) = Stack(List(a))
```

```console
$ ernc hidden.ern
hidden.ern:1:1: Stack is an abstract type the module keeps private, which hides its constructors from no module
1 | abstract type Stack(a) = Stack(List(a))
  | ^^^^^^^^
  | = help: export it, or declare it `type`
```

The representation may change later, a tree for the list, and the modules that use the stack still work, since none of them could name it.

### 7.3 One contract, several representations

Code is often written once for a kind of thing that has several representations: a shape that is a circle or a square, a set kept in a hash or kept sorted. Ernest writes such a contract as a record of functions, a type whose fields are the operations, in one of two forms.

**Values that carry their operations.** Each value is a record whose functions close over what it is made of, so a list may hold values of different representations:

```ernest
// shapes.ern  (namespace Shapes)
/// A shape, whatever it is made of.
type Shape = Shape(name : String, area : () -> Float)

fn circle(radius : Float) -> Shape =
    Shape(name = "circle", area = fn() = 3.14159 * radius * radius)

fn square(side : Float) -> Shape = Shape(name = "square", area = fn() = side * side)

export fn main() = List.foreach([circle(1.0), square(2.0)], fn(s) =
    Io.println(s.name <> " " <> Float.toString(s.area())))
```

```console
$ ernc shapes.ern
$ ern shapes.erc
circle 3.14159
square 4.0
```

`s.area()` runs the function the shape was built with, and the code that takes a `Shape` knows nothing of radii or sides. A function may take two shapes and use what each gives, its `name` and its `area`. It cannot see either shape's radius or side, and it cannot require that the two are of one representation. An operation that needs to see inside two values of one representation, as the union of two sets does, takes the second form.

**Operations passed beside the data.** The contract is a type in a module of its own, and the representation is a type parameter, `s`, which the code that uses the contract keeps. `union` takes two values of type `s` and gives a third:

```ernest
// sets.ern  (namespace Sets)
/// What a set is to code written once for every representation.
export type Operations(s, a) = Operations(
    empty : s, add : (s, a) -> s, has : (s, a) -> Bool, union : (s, s) -> s)
```

Each representation depends on the contract and exports an `operations()` that fills it in. What a representation needs goes in through `operations`, here the ordered set's `compare`; `operations` is a function in both, though the hashed set takes nothing, so that the two read alike:

```ernest
// sets/hashed.ern  (namespace Sets.Hashed)
/// The built-in `Set`, as a `Sets.Operations`.
export fn operations() -> Sets.Operations(Set(a), a) = Sets.Operations(
    empty = Set.empty, add = Set.put, has = Set.contains, union = Set.union)
```

```ernest
// sets/ordered.ern  (namespace Sets.Ordered)
/// A list kept in the order of a `compare`, as a `Sets.Operations`.
export abstract type Sorted(a) = Sorted(List(a))

export fn operations(compare : (a, a) -> Ordering) -> Sets.Operations(Sorted(a), a) =
    Sets.Operations(
        empty = Sorted([]),
        add = fn(Sorted(xs), x) = Sorted(merge(xs, [x], compare)),
        has = fn(Sorted(xs), x) = List.any(xs, fn(y) = compare(x, y) == Equal),
        union = fn(Sorted(xs), Sorted(ys)) = Sorted(merge(xs, ys, compare)))

fn merge(xs : List(a), ys : List(a), compare : (a, a) -> Ordering) -> List(a) =
    match #(xs, ys) {
        #([], _) -> ys
      | #(_, []) -> xs
      | #(x :: xrest, y :: yrest) -> match compare(x, y) {
            Less -> x :: merge(xrest, ys, compare)
          | Equal -> x :: merge(xrest, yrest, compare)
          | Greater -> y :: merge(xs, yrest, compare)
        }
    }

/// The elements in ascending order, which no other set here gives.
export fn toList(Sorted(xs) : Sorted(a)) -> List(a) = xs
```

Code written once takes the record, and the caller chooses the representation at the call:

```ernest
// main.ern  (namespace Main)
fn dedupe(operations : Sets.Operations(s, a), xs : List(a)) -> List(a) = {
    let #(_, kept) = List.foldLeft(xs, #(operations.empty, []), fn(acc, x) = {
        let #(seen, out) = acc;
        if operations.has(seen, x) then acc else #(operations.add(seen, x), x :: out)
    });
    List.reverse(kept)
}

fn fromList(operations : Sets.Operations(s, a), xs : List(a)) -> s =
    List.foldLeft(xs, operations.empty, operations.add)

export fn main() = {
    Io.println(String.join(dedupe(Sets.Hashed.operations(), ["b", "a", "b", "c"]), " "));
    let numbers = Sets.Ordered.operations(Int.compare);
    Io.println(String.join(List.map(dedupe(numbers, [3, 1, 3, 2]), Int.toString), " "));
    let both = numbers.union(fromList(numbers, [3, 1]), fromList(numbers, [2, 3]));
    Io.println(String.join(List.map(Sets.Ordered.toList(both), Int.toString), " "))
}
```

```console
$ ernc --out-dir build .
$ ern build/main.erc
b a c
3 1 2
1 2 3
```

`fromList` is written once, and what it gives back is of the caller's representation: here a `Sets.Ordered.Sorted(Int)`, which `union` merges with another and `Sets.Ordered.toList` reads. Reach for the first form when values of different representations meet, in one list or one message. Reach for the second when code written once must keep the representation's type, to take two values of it or to give one back.

In both, the types check each record where it is built: `circle` and `Sets.Hashed.operations()` must give every field, each of its type, or the module is refused. The code that takes the record sees only what it lists, never a radius, a `Set` or a sorted list. What a representation needs goes in when it is built, a radius or a `compare`, and what it has beyond the contract, as `Sets.Ordered.toList`, is reached through its module. Equality is inferred, as everywhere (§2.5). The annotation of `Sets.Hashed.operations` does not write it, and its type carries it from `Set.put`: `Sets.Hashed.operations : () -> Sets.Operations(Set(a=), a=)`. Nothing checks a module beyond the record it builds: a representation need export nothing else. A service with state is different: two processes of different representations take one message type, and the caller holds an `Address(M)` (§4).

### 7.4 Prediction exercise

Can a helper in the same file as `Stack`, one that is not declared `Stack.` anything, match `Stack(xs)`?

## 8. Cross boundaries

A program reaches outside its node's Ernest code in two ways: to peers over the network, and to foreign code on the same node.

Peers are the language's, and the toolchain runs one node until they are built, in MVP 3.0. Until then the configuration is not read, `spawn(Peer(name), f)` faults with `peer unreachable`, and `remote` answers `Left(NoRemotePeer)`; §8.1 and §8.2 describe what peers will do.

A node that talks to peers has a configuration, which a node running alone does not need. `ern --create-config-dir .` creates it, once, in `./.ernest/`: `ernest.conf`, with this node's network address, its public key and an empty list of peers, and the private key beside it. The command fails if `./.ernest` exists. A peer is added to the list by editing `ernest.conf` (report Appendix C), and its name is what `Peer(name)` refers to.

### 8.1 `remote`

`remote` runs a pure function on a peer the runtime chooses:

```console
$ ern --shell
Ernest 0.1.0. :help for the commands, :quit to leave.
> :type remote
remote : (() -> a) -> Either(RemoteError, a) with m
```

```ernest-prelude
type RemoteError = NoRemotePeer | PeerLost
```

`f` is pure, since `remote` computes a value and returns it; work with effects on a peer runs in a process spawned there, `spawn(Peer(name), f)`.

`remote` answers `Left(NoRemotePeer)` when no peer takes remote computation, and `Left(PeerLost)` when the peer is lost before it answers. A fault in `f` faults the caller with the same cause, as a local call would; work whose fault should not end the caller runs in a process of its own, monitored.

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

export fn main() -> Unit with Never = match remote(fn() = heavy(3, 4)) {
    Right(n) -> Io.println("remote returned " <> Int.toString(n))
  | Left(NoRemotePeer) -> Io.println("no remote peer configured")
  | Left(PeerLost) -> Io.println("peer lost")
}
```

With a peer that `ernest.conf` lists with `"remote-peer": true`, it prints `remote returned 25`. On one node it answers the other case:

```console
$ ern remote.erc
no remote peer configured
```

### 8.2 Code shipping

A closure or a message sent to a peer takes the code it needs with it: the peer uses the code it has, and fetches from the sender what it lacks. Every function and type is known by a hash of its definition, a type's name included, so two nodes agree on a type exactly when they declare it the same way (report §8.7). A `Sys.*` name in shipped code is the peer's, so a shipped `Io.println` prints on the peer, while an address the closure captured still names the process it named. A `send` to a peer returns at once, and a failure to resolve the code there faults the sender later.

A peer that is lost stays lost: its processes are dead to this node, monitors report `Fault("peer lost")`, and a message in flight may be lost without notice (report §10).

### 8.3 Foreign types and functions

```ernest
// ets.ern
export foreign type Table(k=, v)

export foreign fn member(t : Table(k, v), key : k) -> Bool with m = "ets:member/2"
```

External callers write `Ets.Table` and `Ets.member`. `foreign type` declares a type whose values only foreign functions make and read; Ernest has no constructor for it and cannot match it. `foreign fn` binds a name to a function on the other side, here Erlang's `ets:member/2`. The `=` in `k=` says the keys need equality, since `ets` compares them: a table keyed by functions is a type error at its first operation, as a `Map` is (report §4.7).

The foreign side promises the declared types. A return value of the wrong shape faults the Ernest process that receives it, when it first looks at it; an Erlang exception becomes a fault of the calling process; and a message of the wrong type from foreign code faults its receiver on delivery. Purity is not checked: a `foreign fn` declared without `with` is trusted to have no effect (report §4.7).

In the other direction, an Ernest process's end is an Erlang exit reason, `normal`, `{ern, fault, Text}`, `{ern, killed}`, or `{ern, program_end}`, which Erlang code that monitors it reads (report §8.4).

A value foreign code made and Ernest does not inspect has the built-in type `Foreign`; `Foreign.toInt` and the rest of Appendix E.12 read it, and `Erl.atom(name)` is how an Erlang atom is passed (report §3.7, Appendix E.19).

### 8.4 Node-local foreign values

A foreign value belongs to the node that made it, and sending one to another node, alone or inside a message or a closure, faults with `Fault("foreign value cannot cross nodes")`.

A `Random.Seed` is such a value. The closure below captures one, so shipping it to the peer `alice` faults with that cause; on one node, today, the spawn faults with `peer unreachable` first:

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

A shim is a private `foreign fn` over an Erlang function and an exported Ernest function that gives it the type Ernest wants. Erlang's `ets:lookup` returns a list, since a key matches no entry or one:

```ernest
// ets.ern
export foreign type Table(k=, v)

export fn lookup(t : Table(k, v), key : k) -> Optional(v) with m =
    match rawLookup(t, key) { [#(_, v)] -> Some(v) | _ -> None }

foreign fn rawLookup(t : Table(k, v), key : k)
    -> List(#(k, v)) with m = "ets:lookup/2"
```

`rawLookup` is the module's own, and callers use `Ets.lookup`.

Erlang's `{ok, V}` and `{error, R}` are not an Ernest `Either`, whose values are `{'Right', V}` and `{'Left', R}` (report §8.4).

A small Erlang helper returns the Ernest shape, with an integer for `Int` and a UTF-8 binary for `String`:

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

A helper converts whatever its Erlang function returns to the declared type; Ernest does not. A `foreign fn` that takes a `Foreign` is given one by `Foreign.from(value)`, and `Erl.atom(name)` makes an atom (report Appendix E.12, report Appendix E.19).

`libs/ets` is such a library, written out in report Appendix D, and a program adds it with `--load-path`. JSON, TLS, regular expressions and HTTP are libraries of the same kind, outside the standard library, since each carries policy of its own (report Appendix E.0).

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

A bitstring's total width is a whole number of bytes, and a value that does not fit its segment's width faults; report §5.11 has the rest of the rules.

A `Bytes` value is read with the `Bytes` module: `Bytes.size`, `Bytes.get` for one octet, `Bytes.slice`, and `Bytes.toList` for all of them. Text crosses with `String.toUtf8` and `String.fromUtf8`.

In a pattern, `size(len)` may name a variable bound by an earlier segment. A `match` over bitstrings ends with a clause that takes anything, as `parseFrame` does, since the checker does not decide whether bitstring patterns cover every `Bytes` value.

### 8.7 Prediction exercise

Suppose `send(remoteAddr, msg)` returns immediately, and 50 ms later the peer reports a resolution failure. What happens to the sending process?

## 9. Tools

Two commands and a shell, and a mode for Emacs. Report §11 defines each option.

### 9.1 `ernc`, the compiler

- `ernc hello.ern` compiles one module to `hello.erc`, beside it.
- `ernc --out-dir build src` compiles every module under `src` in dependency order, mirroring the tree into `build`. A module is compiled again only when its source, an interface it depends on, any interface of the standard library, or the compiler has changed, and a `.erc` whose source is gone is removed.
- `--source-root dir` names the directory a module's namespace is read from, as §7.1 describes. `--load-path dir` adds compiled modules from outside the tree, such as a library.
- `--errors short` prints the first line of each error only, `file:line:column: message`, for a tool to read.
- `--doc file.ern` writes the module's documentation as CommonMark. `--doc src` writes a page for each module under `src` and an `index.md`, and for the standard library's root a `prelude.md` as well.
- `--emit erl` writes the Erlang the module compiles to, for reading.

### 9.2 `ern`, the runner

- `ern hello.erc` runs `main` and exits with status 0 when it returns. A fault of the entry process is printed as `fault: ` and its cause, and the status is 1 (§6.3).
- `--main Module.name` runs another exported function of no arguments instead of `main`.
- `--load-path dir` adds compiled modules and Erlang `.beam` files the program needs (§8.5).
- `--test module.erc` runs the module's tests and exits with status 1 unless all passed (§7.1).
- `--shell`, with or without a file, starts the shell (§1.2). A file's `main`, or the function `--main` names, runs beside it; a file without either is loaded with nothing running. `--source-root dir` names where `:load` finds a module's source, and `--config-dir dir` the configuration directory.
- `--create-config-dir .` makes the configuration a node with peers needs (§8).

### 9.3 The shell

An input is an expression, a declaration, or a `let`, and a command begins with `:`. `:help` lists the commands, among them these: `:type` gives an expression's type and `:doc` a name's documentation, `:browse` lists a module's exports, `:load` and `:reload` compile a module from its source, `:bindings` and `:forget` manage what the session has declared, `:processes` and `:faults` show what runs and what has faulted, `:set` sets the depth and length values are printed to and turns timing on and off, and `:output` sends what programs write to another window. A command may be shortened to a prefix of its name that begins no other, `:br` for `:browse`; `:b` begins `:bindings` too, and the shell says so. Inputs entered while another runs wait, and run in the order entered.

At a terminal the line is edited with Readline's Emacs keys. `Tab` completes a name, `Shift-Tab` shows its type and documentation, `C-r` searches the history, and `M-Enter` adds a line to the input. At a terminal the history is kept in `$HOME/.ernest/history`. When the shell starts it runs the inputs in `$HOME/.ernest/startup` and then those in the configuration directory's `startup`, `./.ernest` by default. A startup line may be a command, and one that fails is reported with its file and line.

### 9.4 Emacs

`emacs/ernest-mode.el` highlights Ernest, indents it as the style guide does, and lets `M-x compile` with `ernc` jump to each error. [`docs/emacs_mode.md`](docs/emacs_mode.md) says how to load it and what it leaves to your own configuration.

## 10. From Erlang

Ernest runs on the Erlang runtime, and a program in it is processes that send messages, as in Erlang. What an Erlang programmer knows mostly carries over. What differs is where the types reach.

**What carries over.**

- A process is a function that loops by a tail call and keeps its state in its arguments.
- `receive` selects a message by pattern and leaves the others in the mailbox. `after` gives a timeout in milliseconds.
- Messages from one sender arrive in the order they were sent.
- `monitor` delivers a message when a process dies, whatever the reason. `kill` ends a process from outside.
- `Address.call` is `gen_server:call` with a timeout, and `Address.callForever` is the call without one.
- Integers are exact and unbounded. On `Int`, `/` is Erlang's `div` and `%` is `rem`.
- A `foreign fn` calls an Erlang function directly, `"ets:lookup/2"`, and the values cross as report §8.4 lists: a constructor is a tagged tuple or an atom, and a `String` is a UTF-8 binary.

**What differs.**

- A mailbox has a type, so a message the process does not take is a compile error, not a message that sits in the mailbox for ever.
- A reply is checked: a request's `Reply` is answered exactly once on every path (§4.2).
- A function says in its type whether it may send or receive (§3.4).
- There are no exceptions, no `catch`, and no `try`. A failure is a value, a message, or a fault (§6).
- There are no links and no exit signals, only monitors. A process that must die with another monitors it and returns.
- There are no registered names, and addresses cannot be compared. A process is reached through an address it was given.
- There are no atoms in the language: constructors are the tags. `Erl.atom` makes one for a foreign call.
- There are no OTP behaviours. A server is a `receive` loop with `Reply`, and a supervisor is §6.4's fifteen lines.
- A running program replaces its code by a message that carries the new function (§4.6). Only the shell's `:reload` loads a new version of a module.
- ETS is a library outside the standard library, `libs/ets`, since a table is state that processes share.
- Nodes will talk over Ernest's own protocol and ship code by content, not over Erlang distribution (§8.2).

## 11. The design

Report §0 gives five principles, and the rules of the guide follow from them.

1. **Least surprise decides.** A rule stays when the code it produces is what a reader who knows the rest of Ernest would write, and changes when it is not. The other four principles build the language, and this one audits the code they produce.
2. **One way, one job.** The language and the prelude have one way to do each thing: a record is a constructor with named fields, a server is a `receive` loop, a request is a `Reply`.
3. **Nothing invisible.** Control flow, communication, and failure show in the code or in the type.
4. **Simple to parse.** Each construct is known by its first token, or by a later one a bounded way ahead, so a reader, like the parser, never has to look far.
5. **Small.** Few concepts, few primitives, few reserved words.

Principle 3 turns an omission into a statement. Exhaustiveness makes you say what every constructor does; `let _ = e` says a value is dropped on purpose; the reply discipline says where each `Reply` is consumed; `export` says what crosses a module's boundary; `with` says a function acts through a process; a qualified name says which module a name comes from. Several of these tell the compiler nothing it could not work out for itself. What they add is that the decision is written down, where a reader meets it. It is programming on purpose, to borrow P. J. Plauger's phrase for designing deliberately rather than by accident; his subject is software design as a whole, broader than these rules (*Programming on Purpose: Essays on Software Design*, Prentice Hall, 1993).

## 12. Frequently asked questions

**Why is there no `import`?**

A name from another module is always written in full, `Net.Http.parse`, so a reader sees where it comes from (principle 3), and a module's path says what its names are. An `import` would add a second way to write each of them.

**Why is a lambda after `|>` in parentheses?**

A lambda's body extends as far as the text allows, so `x |> fn(y) = y + 1 |> f` would take `|> f` into the body. The parentheses end it.

**Why `fn(x) = ...` for a lambda, and not `x -> ...`?**

A function's number of arguments is part of its type, and `fn(x, y)` shows it where the lambda is written, in the form a declaration and a call already have.

## 13. Answers to the exercises

**§1.4.** (a) compiles: inference gives `main` a mailbox effect from the call of `Io.println`. (b) does not compile: `-> Unit` with no `with` declares `main` pure, and a pure function cannot call `Io.println`, which sends. It is the mistake of `area` in §0. The `with Never` of hello-world says that `main` runs in a process whose mailbox will never receive. Omitting an annotation is not the same as declaring purity.

**§2.11.** No. Ernest has no assignment. `q` is a separate `Person` value; `p` is still `Person(name = "Alice", age = 30)`.

**§3.8.** `map2`'s inferred type is `((a) -> b with e, a, a) -> #(b, b) with e`. The call binds `a = Int`, `b = Unit`, and `e` to the mailbox effect of `send`, the same as the enclosing function's.

**§4.8.** No. The timeout only bounds the caller's wait. The recipient may still be processing the request or may answer later; the late answer is silently discarded but the work done on the recipient side is not undone.

**§5.7.** No. Per-sender FIFO orders messages from ping to pong and pong to ping, but the two processes both send to `Sys.stdout`, two senders to one process, and the runtime does not order across senders. Alternation is a *possible* trace, not a guaranteed one.

**§6.5.** `main` faults with the cause `todo: first of an empty list`, and since it is the entry process the program ends and `ern` prints `fault: todo: first of an empty list`. To give the case to the caller, return `Optional(Int)`, as `List.get` does: `[] -> None`.

**§7.4.** Yes. The boundary of an abstract type is its module, so every definition in `main.ern` may name the constructor, a helper or a test included; another module sees the type and its operations, never the constructor.

**§8.7.** The runtime faults the sending process asynchronously, after `send` has already returned. Code that followed the `send` may have executed; the fault interrupts the process where it currently is, not at the site of `send`.

## 14. Reading further

The four paper programs below compile under test, `COMPILES` in `test/ern_integration_tests.erl`. Three of them run there with fixed input and a bounded run: the REPL, the file sync, and the web server. The snake game is played under a pseudo-terminal by `test/ern_terminal_tests.erl`.

The four paper programs, in ascending complexity:

- [`examples/snake.ern`](examples/snake.ern) — snake game with tick-based updates; `..` record updates, one process per player, `Clock`, `Terminal`, `Random`.
- [`examples/repl.ern`](examples/repl.ern) — small read-eval-print loop; `<-` for chained parsing, `monitor` + `kill` for aborting slow evaluation, `Io.readLine`.
- [`examples/filesync.ern`](examples/filesync.ern) — file sync between two directories, whose two sides run on one node and would run the same on two; mutual-address setup, one process per file operation, `Fs`.
- [`examples/webserver.ern`](examples/webserver.ern) — HTTP server with sessions in a process that owns a `Map`; request-reply, type members, `Tcp`.

Beyond `Io.println` and `Clock`, the paper programs use `Fs`, `Terminal`, `Tcp`, and `Io.readLine`, all of which the toolchain has.

For the language rules themselves, [`ernest_report.md`](ernest_report.md) is the authority. Appendix F glosses every technical term.

Why Ernest looks as it does, and what was tried and rejected, is in [`decisions.md`](docs/decisions.md), a dated record of the design decisions.
