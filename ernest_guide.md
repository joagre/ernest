<picture>
  <source media="(prefers-color-scheme: dark)"
          srcset="assets/ernest-dark.svg">
  <source media="(prefers-color-scheme: light)"
          srcset="assets/ernest-light.svg">
  <img src="assets/ernest-light.svg" alt="Ernest" width="50%">
</picture>

# Programming in Ernest

This guide teaches Ernest to a programmer who has used a functional language. It assumes immutable values, sum types, pattern matching, functions as values and recursion, and shows only how Ernest writes them. Processes and messages it teaches from the start, since their types are what is new; a reader who knows Erlang will recognize the model, and §10 says what carries over. Nothing of Ernest or of its report needs reading first.

Each complete program in the guide compiles as shown and prints what is shown after it, and the guide's tests run every one. A fault's report goes to standard error, so its place among a program's own lines is one run's. A program the compiler refuses is shown with what the compiler says of it. The examples of peers in §8 are fragments, since the toolchain does not run peers yet. The language is defined by the report, in three files under [`report/`](report/language.md), to which the guide points where a question turns on a detail.

**Contents**
<!-- contents -->
- [0. Why Ernest](#0-why-ernest)
- [1. Run a program](#1-run-a-program)
- [2. Compute with immutable values](#2-compute-with-immutable-values)
- [3. Pass behavior](#3-pass-behavior)
- [4. Run a protocol](#4-run-a-protocol)
- [5. Manage process lifetime](#5-manage-process-lifetime)
- [6. Handle failure](#6-handle-failure)
- [7. Organize code](#7-organize-code)
- [8. Cross boundaries](#8-cross-boundaries)
- [9. Tools](#9-tools)
- [10. From Erlang](#10-from-erlang)
- [11. The design](#11-the-design)
- [12. Frequently asked questions](#12-frequently-asked-questions)
- [13. Answers to the exercises](#13-answers-to-the-exercises)
- [14. Reading further](#14-reading-further)
<!-- /contents -->

## 0. Why Ernest

Ernest is a functional language for concurrent programs, built on two ideas. A pure function computes a value from its arguments and does nothing else, and the compiler infers its type. A process runs a function and receives messages of one type in its mailbox, and processes are how a program acts on the world. A function that sends or receives says so in its type, and runs only in a process. Every other rule says how the two appear in each other's code.

The rules let the compiler find, before the program runs, the mistakes concurrent programs are prone to. Four follow, each as a program and what `ern build`, the compiler, says about it.

**A message the process does not take.** The counter receives `CounterMsg`, so the address `spawn` returns takes a `CounterMsg` and nothing else.

```ernest-rejected
type CounterMsg = Inc(Int) | Get(reply : Reply(Int))

fn count(total : Int) : Unit with CounterMsg =
    receive {
        Inc(amount) -> count(total + amount)
      | Get(reply = reply) -> {
            answer(reply, total);
            count(total)
        }
    }

export fn main() : Unit with Never = {
    let counter = spawn(fn() = count(0));
    send(counter, "increment")
}
```

```console
$ ern build message.ern
message.ern:14:19: the argument does not fit send: expected CounterMsg, found String
13 |     let counter = spawn(fn() = count(0));
14 |     send(counter, "increment")
   |     ---- send : (Address(a), a) -> Unit with m+
   |                   ^^^^^^^^^^^
```

An error in a module's source has this form: the position as `file:line:column`, the message, and the source with the error's span underlined with `^`. A span the error depends on is underlined with `-` and labelled, here the type of `send`, whose two arguments must agree. The names in these examples, `spawn`, `send`, `receive`, `Reply`, `answer`, and `with`, are taught in §1 to §4; here only the errors matter.

**A request left unanswered.** A `Get` carries a `Reply(Int)`, in which the counter puts its answer. A reply is answered exactly once on every path. This counter forgets to, and whoever asked would wait.

```ernest-rejected
type CounterMsg = Inc(Int) | Get(reply : Reply(Int))

fn count(total : Int) : Unit with CounterMsg =
    receive {
        Inc(amount) -> count(total + amount)
      | Get(reply = reply) -> count(total)
    }
```

```console
$ ern build forgot.ern
forgot.ern:6:9: the reply-carrying value reply is never consumed
5 |         Inc(amount) -> count(total + amount)
6 |       | Get(reply = reply) -> count(total)
  |         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  | = help: a reply is consumed by answering it, passing it on once, or matching it (§6.6)
```

**Work through a process, in a function that says it does none.** Standard output is a process, so printing is sending it a message. `area` is declared pure, `: Int` with nothing after it, and the compiler holds it to that. A function that sends or receives says so with `with`, as the help line says.

```ernest-rejected
fn area(width : Int, height : Int) : Int = {
    Io.println("computing an area");
    width * height
}
```

```console
$ ern build area.ern
area.ern:2:5: Io.println needs a process, and area is pure
1 | fn area(width : Int, height : Int) : Int = {
  |                                      --- `: Int` with no `with` declares area pure
2 |     Io.println("computing an area");
  |     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  | = help: give area a mailbox type with `with`
```

**A failure dropped.** `Fs.write` returns `Either(Io.Error, Unit)`: the file was written, or the reason it was not. Its last argument, `1000`, is how many milliseconds it may take. A statement in a block must be `Unit`, so the failure cannot pass unseen. `let _ = ...` discards it where that is meant.

```ernest-rejected
export fn main() : Unit with Never = {
    Fs.write(Path("notes.txt"), String.toUtf8("buy milk"), 1000);
    Io.println("saved")
}
```

```console
$ ern build notes.ern
notes.ern:2:5: this statement's value is discarded: expected Unit, found Either(Io.Error, Unit)
1 | export fn main() : Unit with Never = {
2 |     Fs.write(Path("notes.txt"), String.toUtf8("buy milk"), 1000);
  |     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  | = help: `let _ = ...` discards it on purpose
```

These rules come from one design, and most of its parts exist already. The Erlang runtime gives processes, faults delivered as messages to the processes that watch, and code replaced while a program runs. Gleam showed that a statically typed language fits that runtime, and Ernest follows it in much: Hindley-Milner inference, `fn` and the pipe `|>`, the update `Con(..x, f = v)`, and foreign types and functions as the way to Erlang code. Unison identifies code by a hash of its definition and ships to a peer what it lacks. What Ernest adds is where the parts meet:

- **The mailbox in the function's type.** A process receives one type of message, and the functions it runs say so, `with CounterMsg`. An address carries the same type, so every `send` is checked against its receiver: an address's type is the type of the mailbox it reaches.
- **Checked replies.** A request carries a `Reply`, answered exactly once on every path, which the compiler checks as it checks types. `Address.call` waits with a deadline, so an answer that never comes is a case the program handles.
- **Purity in the type.** `with` separates the functions that may send or receive from those that cannot. A pure function computes and returns, and the compiler holds it to that.
- **Distribution by content, planned.** Every function and type is known by a hash of its definition, a type's name included, so a message is checked across nodes as it is within one. Code travels only with a process spawned on a peer, and two versions of a type are two types.

Sections 1 to 8 are eight stages: run a program, compute with values, pass behavior, run a protocol, manage process lifetime, handle failure, organize code, and cross boundaries. Each builds on the ones before it and ends with an exercise, whose answer is in §13. A complete program is shown whole; a fragment is part of the program around it. After the stages come the tools (§9), a word for the Erlang programmer (§10), the design behind the rules (§11), and questions a reader asks (§12).

## 1. Run a program

A program is a module that exports a function `main`. Put this line in `hello.ern`, a file named by lowercase words joined by `_` (§7.1):

```ernest
export fn main() : Unit with Never =
    Io.println("hello, world")
```

Compile and run, with `ern` installed as the [README](README.md) says:

```console
$ ern build hello.ern         # produces hello.erc
$ ern run hello.erc          # runs main()
hello, world
```

`ern` is the whole toolchain, and its first word is the job. `ern build` compiles a `.ern` file to a compiled module, `.erc`. `ern run` loads it and the modules it uses, the standard library among them, starts the runtime's processes, and calls `main`. §9 lists each job's options.

### 1.1 What the line says

`fn` begins a function definition, and `export` makes it visible outside the module. `ern` runs the function `main` of the module it loads; `--main` names another (§7.1).

`: Unit` is the result type, written after the parameters as a parameter's type is written after its name. `Unit` is a type with one value, also written `Unit`, the result of a function whose work is its effect.

`with Never` names the mailbox. A function that sends or receives runs in a process, whose mailbox takes one type of message, and its type says which with `with`. `main` runs in the process the program starts it in, the *entry process*. `Never` is the type with no values, so a process whose mailbox is `Never` receives nothing, which suits a `main` that only sends.

A function a process starts with that never receives, such as `main`, is written `with Never`, and one that only sends, such as `Io.println`, is written `with m`, a type variable, so that a process with any mailbox may call it. Types may also be left out, and the compiler infers them (§3.3).

`Io.println` sends its text to standard output's process, which the runtime provides and `Io` alone reaches. `Io.printlnError` sends to standard error's, so a program whose output another program reads can still report trouble. Sending to a process of the runtime is one of the two ways a program reaches the world; the other is `foreign fn` (§8).

`Io.debug(x)` prints any value as its literal or construction is written, where it has one, to standard error, and returns it, so it wraps an expression where it stands: `let n = Io.debug(f(x))`. It sends, as `Io.println` does, so it cannot hide in a pure function. `Io.show(x)` is the text it prints, and is pure (report Appendix E.1).

### 1.2 The shell

`ern shell` starts a shell. An input is an expression, a declaration, or a `let`. It is checked and run when it is entered, after any input still running, and an expression's value is printed with its type and kept as `it`. The inputs below use lists and functions, which §2 and §3 teach; here only the shell matters.

```console
$ ern shell
Ernest 0.3.0. :help for the commands, :quit to leave.
> 1 + 2
3 : Int
> let xs = [3, 1, 2]
xs : List(Int)
> List.sort(xs, Int.compare)
[1, 2, 3] : List(Int)
> fn square(n : Int) : Int = n * n
square : (Int) -> Int
> List.map(xs, square)
[9, 1, 4] : List(Int)
> Io.println("hello")
hello
```

A value of type `Unit` prints nothing, so the last input shows only what it wrote. An error at the prompt is placed as `input n:line:column`, `n` counting the inputs entered (report §11.2). A command begins with `:`. `:type e` prints the type of `e` without running it, `:doc List.sort` prints the documentation of `List.sort`, and `:help` lists the rest. `ern shell hello.erc` starts the shell with `hello`'s module in scope and its `main` running beside it. A module without `main` is put in scope with nothing running, to be tried at the prompt.

At a terminal the shell edits the line with Readline's Emacs keys, and keeps a history across sessions that `C-r` searches. An input the parser cannot finish takes another line, and `M-Enter` adds one whatever the parser says. What programs write appears in a region at the foot of the screen, apart from the inputs, and a process that faults is reported at the prompt with the place it was spawned. A fault, an error, and a refused command are shown in red and a result's type dimmed, and documentation is styled, unless the environment sets `NO_COLOR`. A line wider than the screen wraps as it is typed.

`Tab` completes the word before the cursor, by its prefix or by its word starts, `S.pS` to `String.padStart`. After a value the session knows and a `.`, it completes the fields the value's type selects: `it.co` to `it.count`. It offers only what may stand there: a command after a leading `:` and what the command takes after it, a type after `:` in an annotation, a constructor in a pattern, a field inside a named constructor's parentheses. A name completed alone is shown under the line with its type, and a second `Tab`, or one with nothing to add, lists the candidates there alphabetically, until the next key. With no word begun, as after `f(`, they are the session's names, the modules in scope, and the prelude's names other than its constructors, and every other name comes from its first letters. At the start of a row `Tab` indents instead. `Shift-Tab` shows the declaration, the first sentence, and the version of the name at the cursor, `String.trim(text : String) : String` and what it does, and pressed again its documentation. Inside a call, on no documented name, it shows the callee's signature with the parameter at the cursor marked, and inside a constructor its fields.

`:load` compiles a module from its source and puts it in scope, and `:reload` compiles and loads again a loaded module whose source has changed. Where one of the changed modules does not compile, `:reload` loads none of them. Both evaluate a module's top-level bindings, so a service it declares starts, and after a reload a service of the new version runs beside the old. Processes running the old version go on running it, and a binding that holds a function of it keeps it, until the next reload of that module, which ends the processes and forgets the bindings.

### 1.3 Reading input

A program's first input is its command line. An entry point takes no arguments: the words after the module on `ern run`'s line are `Os.arguments`, a list of strings. The shell's command line is its own, and in the shell `Os.arguments` is the empty list.

```ernest
export fn main() : Unit with Never =
    match Os.arguments {
        [] -> {
            Io.printlnError("usage: greet name...");
            Os.exit(2)
        }
      | names -> List.foreach(names, fn(name) = Io.println("hello, " <> name))
    }
```

```console
$ ern run greet.erc Ada Grace
hello, Ada
hello, Grace
```

`match` takes the first clause whose pattern fits the value: `[]` fits the empty list, and `names` fits any other and names it (§2.3). A block, `{ ...; ... }`, runs its statements in order (§2.2), and `fn(name) = ...` is a function written in place (§3.2).

`Os.exit(status)` ends the program with that exit status. A program whose `main` returns exits with 0, and one whose entry process faults exits with 1. A variable of the environment is asked for by its name: `Os.environment("HOME")` answers `Some(dir)` where the home directory is set, and `None` where it is not. The directory the program was started in is `Os.workingDirectory`, and a relative path names a file under it.

A program the host has is run with `Os.run`, which gives it its input and answers its exit status and what it wrote once it has ended, or an `Io.Error` where it could not start. Its name is found as the host finds a command, and each argument reaches it as it is, with no shell between:

```ernest
export fn main() : Unit with Never =
    match Os.run(Os.Command(program = "echo", arguments = ["hi"], input = <<>>), 5000) {
        Right(finished) -> Io.print(Optional.withDefault(String.fromUtf8(finished.stdout), ""))
      | Left(error) -> Io.printlnError(Io.show(error))
    }
```

```console
$ ern run echo.erc
hi
```

`Os.start` starts one to talk with while it runs: `Os.write` feeds it, `Os.read` answers what it wrote, piece by piece, and the running program is a process, which `kill` and `monitor` work on (report Appendix E.23).

`Io.readLine()` waits for a line of standard input and answers `Some(line)`, or `None` at its end. A program that reads its input to the end loops:

```ernest
export fn main() : Unit with Never =
    match Io.readLine() {
        Some(line) -> {
            Io.println(String.toUpper(line));
            main()
        }
      | None -> Unit
    }
```

```console
$ printf 'hello\nworld\n' | ern run upper.erc
HELLO
WORLD
```

Standard input is read as UTF-8, and a line that is not faults the process that read it. Input that is not text is read as bytes: `Io.read()` answers `Some(bytes)` with what has arrived, and `Io.write(bytes)` writes bytes to standard output as they are. Lines and bytes come from one stream, so a program can read a line and then the bytes after it. A program reads lines or single keys, not both: `Terminal.subscribe` gives keys as they are pressed, or answers `Left(Io.NotATerminal)` where standard input is not a terminal, so that the program can read lines instead (report §8.2).

### 1.4 Prediction exercise

Consider two variations on hello-world, (a) with no annotation:

```ernest
export fn main() =
    Io.println("hello, world")
```

and (b) with `: Unit`:

```ernest-rejected
export fn main() : Unit =
    Io.println("hello, world")
```

Which of these compile?

## 2. Compute with immutable values

Everything in Ernest is immutable. Bindings introduce names; there is no assignment.

### 2.1 Scalars, Unit, and literals

- **`Int`** — arbitrary precision. Literals: `42`, and in another base `0xFF`, `0o644`, `0b1010`. An `_` between digits groups them: `1_000_000`.
- **`Float`** — IEEE 754 binary64, finite values only. Literal: `3.14`.
- **`Char`** — one Unicode scalar value, a code point other than a surrogate. Literal: `'a'`.
- **`String`** — Unicode text. Literal: `"hello"`, with the escapes `\n`, `\t`, `\\`, `\"`, and `\u{1F600}` among them (report §2.5). `<>` joins two strings, and a type's `toString` makes its text: `"n = " <> Int.toString(3)`. There is no interpolation.
- **`Bytes`** — a sequence of octets, built with the bit syntax: `<<0, 1, 2>>` (§8.6).
- **`Bool`** — `true` or `false`. `&&` and `||` short-circuit, and `!` negates.
- **`Unit`** — one value, also called `Unit`.

A raw string, between backticks, is taken exactly as written, with no escapes, except that a line break in it is a line feed. It is the form for text full of backslashes or quotes, and for text over several lines, since a line break in it is part of the text. The shell prints a string as a `"..."` literal, so it shows what the raw string saved writing:

```console
$ ern shell
Ernest 0.3.0. :help for the commands, :quit to leave.
> let number = `\d+(\.\d+)?`
number : String
> number
"\\d+(\\.\\d+)?" : String
```

`Int` division `/` and remainder `%` by zero fault, and so does `Float` arithmetic whose result would not be finite. `Int.div` and `Int.rem` return `Optional(Int)` instead. A fault ends the process, or restarts it where it was started to restart (§6).

`Int` and `Float` are separate types, and nothing converts between them implicitly: `1 + 2.0` is a type error. Convert with `Int.toFloat`, or with `Float.round`, `Float.floor`, `Float.ceil`, or `Float.truncate`.

### 2.2 Bindings and blocks

A name begins with a lowercase letter or `_`, and eighteen words are reserved and name nothing: `type`, `abstract`, `with`, `foreign`, `match`, `when`, `receive`, `after`, `as`, `or`, `if`, `then`, `else`, `fn`, `let`, `export`, `true` and `false` (report §2.4). At the prompt, as in a block, `let` binds a name:

```console
$ ern shell
Ernest 0.3.0. :help for the commands, :quit to leave.
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

An initializer runs before `main`, in the entry process, as a body that may spawn, send and call, which §4 teaches, but not receive; a top-level `let` that holds a process's address is a service binding, which §6.5 teaches. Constants are evaluated in the order their references need, and otherwise in the order the module declares them, and a cycle among them is an error (report §4.6, §8.5).

### 2.3 Sum types and pattern matching

A type declaration names its cases. `Direction` has four *constructors*, and `match` picks between them:

```ernest
type Direction = North | South | East | West

fn opposite(direction : Direction) : Direction =
    match direction {
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

There are no type aliases. `type Word = String` declares a type whose one value is a nullary constructor named `String`, and no other name for `String`; a type that holds a string is a wrapper, `type Word = Word(String)`, and the compiler's help says so where the two meet.

### 2.4 Named fields, selection, and `..` update

For constructors that carry several things, name each field:

```console
$ ern shell
Ernest 0.3.0. :help for the commands, :quit to leave.
> type Person = Person(name : String, age : Int)
type Person
> let alice = Person(name = "Alice", age = 30)
alice : Person
> let older = Person(..alice, age = 31)
older : Person
> older
Person(name = "Alice", age = 31) : Person
> older.age
31 : Int
```

`older.age` reads one field. `..alice` copies the fields not listed, and `age = 31` overrides one. `..` works on a type with one constructor, since the value might otherwise have been built by another. `alice` is unchanged; `older` is a second `Person` value. Ernest uses `:` for types (`name : String`, and a function's result, `fn age() : Int`) and `=` for values (`name = "Alice"`); `->` stands in a function type, `(Int) -> Int`.

The fields may be given in any order, and are evaluated in the order written; a value prints them in the order the type declares them.

A field of a field is updated through a path:

```console
$ ern shell
Ernest 0.3.0. :help for the commands, :quit to leave.
> type Stats = Stats(indexed : Int, hits : Int)
type Stats
> type Pool = Pool(name : String, stats : Stats)
type Pool
> let pool = Pool(name = "p", stats = Stats(indexed = 0, hits = 0))
pool : Pool
> Pool(..pool, stats.indexed = 1)
Pool(name = "p", stats = Stats(indexed = 1, hits = 0)) : Pool
```

`stats.indexed = 1` is `stats = Stats(..pool.stats, indexed = 1)`, the path written once; `pool` is evaluated once, and each type along the path has one constructor (report §5.6).

A type with several constructors has a field only where every constructor has it, with one type: in `type Shape = Dot(at : Point) | Circle(at : Point, radius : Int)`, `s.at` reads any shape's point, and `s.radius` is refused, since a `Dot` has none; a `match` reads it. An abstract type's fields are its own module's (§7.2).

### 2.5 Lists, tuples, maps, sets

**Lists** are `List(a)`, with `[]` for the empty list and `::`, right-associative, to add an element in front; `<>` joins two lists, as it joins two strings. **Tuples** are `#(...)`, of fixed size and positional. **Maps and sets** have no literal syntax and are built with functions. In the session, `|>` passes a value on as the first argument (§2.8), and `fn(v) = ...` is a function written in place (§3.2):

```console
$ ern shell
Ernest 0.3.0. :help for the commands, :quit to leave.
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

Map keys and set elements need equality. `==` is defined on every type except one that contains a function or an address, and on a value of a foreign type, `Foreign.Term` among them, it is the runtime's exact equality (report §3.10), so a map keyed by addresses is a type error at its first operation; key it by the process behind each address instead (§5.5). In a printed type, a variable that needs equality is marked `=`: `fn equal(a, b) = a == b` prints as `equal : (a=, a=) -> Bool`. An annotation does not write the mark; the compiler infers it from the body.

Ordering is separate: `a < b` asks the type's `compare`, which answers `Less`, `Equal`, or `Greater`. `Int`, `Float`, `String`, and `Char` have one, and a type of your own gets one by declaring it in its module. A function named `Money.compare` is a member of the type `Money` (§7.2):

```ernest
type Money = Money(Int)

fn Money.compare(Money(left) : Money, Money(right) : Money) : Ordering =
    Int.compare(left, right)

export fn main() : Unit with Never =
    Io.println(if Money(3) < Money(5) then "cheaper" else "not cheaper")
```

```console
$ ern run money.erc
cheaper
```

A set in the order of its elements' `compare` is `OrderedSet`, and a map with its keys in order `OrderedMap`; code written once over both kinds of set is §7.3's.

### 2.6 Patterns and irrefutability

The same patterns appear in `match` clauses, `let` bindings, and function parameters. A `let` and a parameter need an *irrefutable* pattern, one that cannot fail to match: a name, `_`, a tuple of irrefutable patterns, the only constructor of its type with irrefutable fields, or an irrefutable pattern with `as`, which comes below.

```console
$ ern shell
Ernest 0.3.0. :help for the commands, :quit to leave.
> let #(x, y) = #(3, 4)
x : Int
y : Int
> let #(Some(a), b) = #(Some(1), 2)
input 2:1:1: a `let` pattern must be irrefutable
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
$ ern shell
Ernest 0.3.0. :help for the commands, :quit to leave.
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

fn axis(direction : Direction) : String =
    match direction {
        North or South -> "vertical"
      | East or West -> "horizontal"
    }

fn step(move : Move) : Int =
    match move {
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
fn parseAndAdd(leftText : String, rightText : String) : Optional(Int) = {
    let left <- String.toInt(leftText);
    let right <- String.toInt(rightText);
    Some(left + right)
}
```

If `String.toInt(leftText)` returns `None`, the whole block evaluates to `None`; the rest is skipped. `parseAndAdd("2", "3")` returns `Some(5)`; `parseAndAdd("2", "oops")` returns `None`.

An Either chain uses `Left(e)` to short-circuit and `Right(v)` to bind and continue:

```ernest
fn positiveInt(text : String) : Either(String, Int) = {
    let number <- Either.fromOptional(String.toInt(text), "not an integer");
    if number > 0 then Right(number) else Left("not positive")
}
```

- `positiveInt("3")` → `Right(3)`.
- `positiveInt("oops")` → `Left("not an integer")`: `String.toInt` returned `None`, which `Either.fromOptional` turned into a `Left`, and the chain stopped.
- `positiveInt("0")` → `Left("not positive")`: the parse succeeded, and the `if` refused the value.

A block is an `Optional` chain or an `Either` chain, never both. To run a step that can fail over every element of a list, `List.tryMap(xs, f)` and `List.tryFold(xs, acc, f)` stop at the first `Left`.

### 2.8 The pipe operator `|>`

Ernest's stdlib is subject-first. `|>` reads left-to-right:

```console
$ ern shell
Ernest 0.3.0. :help for the commands, :quit to leave.
> "abc" |> String.toList |> List.reverse |> String.fromList
"cba" : String
```

`x |> f` is `f(x)`, and `x |> f(a, b)` is `f(x, a, b)`: the pipe inserts the first argument. Parentheses change nothing, so `x |> (f(a))` is `f(x, a)` too. A lambda is parenthesized, `x |> (fn(y) = y + 1)`, since its body would take in a `|>` after it (§3.2), and a function a call computes is applied in writing, `adder(3)(x)`.

### 2.9 The standard library

The standard library is a module per type, `List`, `Map`, `Set`, `String`, `Char`, `Bytes`, `Bool`, `Int`, `Float`, `Optional`, `Either`, `Path`, and a few more, `Random` among them, and the system modules `Io`, `Clock`, `Terminal`, `Fs`, `Tcp`, and `Os`, through which a program uses the runtime's system processes. It is always on the load path, where a program's compiled modules are found (§9.1). The names every module may use without a module's name before them, `Some`, `Left`, `spawn` and `send` among them, are the *prelude*'s (report §9). The library's rules let you guess a name before looking it up (report Appendix E.0):

- **One verb per operation, in every module that has it.** `Map.get(m, k)` and `List.get(xs, 0)`; `size`, `isEmpty`, `contains`, `put`, `remove`, `map`, `filter`, `foldLeft`, `find`, `fromList`, `toList` wherever they apply.
- **Subject first, callbacks last**, so the pipe works: `xs |> List.foldLeft(0, fn(acc, x) = acc + x)`.
- **A conversion is named by the other type.** Between a type and one its module builds on, both directions are the building module's, `String.fromList` and `String.toList`; any other conversion is its argument's module's `toX`: `String.toInt`, `Int.toString`.
- **A partial operation returns `Optional`; one with a cause returns `Either`.** `List.get` and `String.toInt` return `Optional`, `Fs.read` returns `Either(Io.Error, Bytes)`. A program says an `Io.Error` to its user in its own words, with a `match` over its constructors; `Io.show` writes it as a value, `Other("address already in use")`.
- **Pure unless the value lives in a process.** A function carries `with m` where it reaches a system process, spawns a process, as `Supervisor.group` does, asks the runtime about its processes, as `Process.live` does, or reads the time, as `Clock.monotonic` does, and nowhere else (report Appendix E.0 shape rule 5); every function that calls a function it takes is as pure as the function it is given (§3.5). One that delivers later, `Clock.alarm` or `Terminal.subscribe`, takes a pure function to make the message and acts through a process anyway.
- **A `String` is text, not a list.** Its length and positions count what a reader sees as letters, which `String.graphemes` gives one by one; `String.toList` gives its `Char`s.
- **A system process is used through its module**, never by `send`. A function that waits takes a timeout in milliseconds last and may answer `Left(Timeout)`: `Fs.read(path, 5000)`. There is no time that means no limit; a server that waits for as long as it takes asks again on each `Left(Timeout)` (§8.7). A read of standard input and a write to standard output wait without a limit, since those streams are the program's own; a socket's far end or a program the runtime started can hang unseen, so `Tcp.write`, `Os.read` and `Os.write` take a time too (report Appendix E.0 shape rule 8). One that delivers later takes a function that makes the message: `Clock.alarm(100, Tick)` puts `Tick(t)` in the mailbox after 100 ms, `t` being the time it fired, and `Clock.now()` is the time now, in milliseconds since the epoch. A process that only waits a while writes `receive { after ms -> Unit }` (§4.3); `Clock` has no sleep.

What a type does not say, the entry in Appendix E does: `List.sort` is stable, `Map.toList` has no order. In the shell, `:doc List.sort` prints it. `:browse Fs` lists a module's types by name and its functions with their types, and `:doc Fs.Entry` shows a type's declaration, its fields among it. A printed type marks a type variable that needs equality `k=` and one that may not carry a reply `a!` (§2.5, §4.2), and a process-only effect variable that stands nowhere else in the type `m+` (§3.5, report §11.5).

### 2.10 A word counter, by hand

Sections 2 to 5 build one program, a word counter, a stage in each. Here it is values at the prompt: a text, its words, and a count kept in a map.

```console
$ ern shell
Ernest 0.3.0. :help for the commands, :quit to leave.
> let text = "the cat and the hat"
text : String
> let words = String.words(text)
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

```ernest-fragment
type Shape = Dot(name : String) | Circle(name : String, radius : Int)
```

and a value `s : Shape`, which of these compile?

- (a) `s.name`
- (b) `s.radius`
- (c) `Circle(..s, radius = 2)`
- (d) `match s { Circle(radius = r) -> r | Dot() -> 0 }`

## 3. Pass behavior

Functions are values. This section is about writing them and passing them around.

### 3.1 Definitions and arity

```ernest
fn double(value : Int) : Int =
    value * 2

fn hypotenuseSquared(a : Int, b : Int) : Int =
    a * a + b * b
```

A function body is either a single expression (like `value * 2`) or a block; a block's final statement is an expression, without a trailing semicolon. Arguments evaluate strict left-to-right before the call. Top-level declarations stand in any order, so a function may call one declared below it (report §4.5).

Function arity is fixed and part of the type. `hypotenuseSquared(3, 4)` is `25`. `hypotenuseSquared(3)` is a type error, not a partially applied function. To make a unary version, write a lambda: `fn(b) = hypotenuseSquared(3, b)`.

### 3.2 Lambdas and closures

```console
$ ern shell
Ernest 0.3.0. :help for the commands, :quit to leave.
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

A lambda's body extends as far as the text allows: to the `,`, `;`, `:`, `|`, `->`, `{`, `>>`, or closing bracket of the form around it, or to a `then` or `else`.

### 3.3 Type inference and its limits

Ernest infers types Hindley-Milner style. You can omit annotations on parameters and returns:

```ernest
fn double(value) =
    value * 2 // inferred (Int) -> Int
```

The literal `2` is an `Int`, so `*` is `Int.*` and `value : Int`. But **Ernest does not infer a "numeric type" or default to `Int`**:

```ernest-rejected
fn twice(value) =
    value + value // value's type ambiguous — annotate: (value : Int) or (value : Float)
```

Without a source that fixes the type, `value + value` is a type error. Once it is fixed, `+` is that type's: `Int.+` for an `Int`, `Distance.+` for a user type that declares it as a member, `fn Distance.+`, and `Int.+` is also a function value, as in `List.foldLeft(xs, 0, Int.+)` (report §4.8, report §5.6).

Other limits worth knowing:

- A `fn` and a top-level `let` are polymorphic, and so is a `let` in a block that binds a lambda. Another `let` in a block is not, and neither is a top-level `let` whose initializer calls a process-only function, `spawn`, `send`, `Address.call` or `Io.println` among them. After `let xs = []` in a block, the element type of `xs` is settled by an annotation, by a later use in the block, or by `xs` reaching the block's result; where nothing settles it, with `xs` never read, the variable stays open and the block compiles. A top-level `let` that is not polymorphic, and a `let` at the prompt, must have their types settled, by an annotation where nothing else settles them (report §4.6).
- A `fn` declared in a block is visible in the whole block, but may be used only after the `let`s it reads (report §5.4).

### 3.4 Pure functions and functions with a mailbox effect

A function whose type has no `with` is *pure*. It cannot send, receive, spawn, ask for its own address, or call a `foreign fn` that has an effect. A function with `with M` may act through a process whose mailbox takes `M`.

Either kind of function can fault or run for ever: `a / b` with `b = 0` faults although its type is `(Int, Int) -> Int`, and `fault("...")` has every type and faults when it is reached. The `with` says only that a function acts through a process, not whether it can fault (§6).

### 3.5 Higher-order and effect polymorphism

```ernest
fn apply(f, x) =
    f(x)
```

The inferred type is `((a) -> b with e, a) -> b with e`: `apply` has the effect of the function it is given, so `apply(f, x)` is pure when `f` is. `List.map`, `List.foreach`, and every other function of the standard library that calls a function it takes are the same.

An effect variable may stand for a mailbox type or for pure. One that also appears inside `Address`, as in `self : () -> Address(m) with m`, stands for a mailbox type only, since an address needs one. The letters in a printed type mean nothing of their own.

The process operations, `self`, `send`, `spawn`, `spawnMonitored`, `receive`, `answer`, `Address.call`, `Address.callForever`, `monitor`, and `kill`, which §4 and §5 teach, are *process-only*: the function that uses one has a real mailbox type, never pure (report §3.9). A printed type marks such an effect variable with `+` where it stands nowhere else in the type: `:type send` prints `send : (Address(a), a) -> Unit with m+`, and so does a function of yours that calls `send`. `monitor`'s stands in its callback's result too, `(Down) -> m`, where it can only be a mailbox type, and is printed without the mark (report §11.5).

### 3.6 The word counter as functions

The counter becomes functions in a file of its own. A file is a module named after it, so the functions of `words.ern` are `Words.count` and the rest to the code outside it (§7.1).

```ernest
// words.ern
export fn words(text : String) : List(String) =
    String.words(String.toLower(text))

export fn count(text : String) : Map(String, Int) =
    words(text) |> List.foldLeft(Map.empty, fn(counts, w) = add(counts, w, 1))

export fn add(counts : Map(String, Int), word : String, amount : Int) : Map(String, Int) =
    Map.update(counts, word, fn(old) = Optional.withDefault(old, 0) + amount)

export fn top(counts : Map(String, Int), limit : Int) : List(#(String, Int)) =
    Map.toList(counts) |> List.sort(byCount) |> List.take(limit)

fn byCount(#(leftWord, leftCount) : #(String, Int),
           #(rightWord, rightCount) : #(String, Int)) : Ordering =
    if leftCount != rightCount then
        Int.compare(rightCount, leftCount)
    else
        String.compare(leftWord, rightWord)
```

`words` lowers the text and splits it at its whitespace (report Appendix E.5). `count` folds the words into a map with `add`. `top` sorts the pairs by count, most first and by word where counts are equal, and keeps `limit` of them. `byCount` is not exported, and its parameters are patterns that take the pairs apart. `ern shell words.erc` loads the module and runs nothing, since it has no `main`:

```console
$ ern build words.ern
$ ern shell words.erc
Ernest 0.3.0. :help for the commands, :quit to leave.
> Words.count("the cat and the hat")
Map.fromList([#("and", 1), #("cat", 1), #("hat", 1), #("the", 2)]) : Map(String, Int)
> Words.top(Words.count("the cat and the hat"), 2)
[#("the", 2), #("and", 1)] : List(#(String, Int))
```

### 3.7 Prediction exercise

Given:

```ernest
fn map2(f, x, y) =
    #(f(x), f(y))
```

What type does the compiler infer for `map2`, and what does the call `map2(fn(n) = send(address, n), 1, 2)`, with `address : Address(Int)`, bind `a`, `b` and `e` to?

## 4. Run a protocol

A process holds state, receives messages, and answers requests. This section builds a counter.

### 4.1 Message type and receive loop

```ernest
type CounterMsg = Inc(Int) | Get(reply : Reply(Int))

fn count(total : Int) : Unit with CounterMsg =
    receive {
        Inc(amount) -> count(total + amount)
      | Get(reply = reply) -> {
            answer(reply, total);
            count(total)
        }
    }
```

`count` keeps its state in the parameter `total`, and its mailbox takes `CounterMsg`. `receive` waits for a message that matches a clause and evaluates that clause. Both clauses call `count` again with the new state; a tail call does not grow the stack, so the loop runs for ever.

`let counter = spawn(fn() = count(0))` starts a process that runs the lambda, and `counter` is its address. The lambda calls `count`, whose mailbox takes `CounterMsg`, so the address is an `Address(CounterMsg)`, and nothing but a `CounterMsg` can be sent to it. The process runs on this node, the runtime the program runs in; `Peer.spawn(name, f)` starts one on another node (§8). `send(counter, Inc(5))` puts `Inc(5)` in the mailbox of the process at `counter` and returns at once, without waiting for it to be received. `self()` is the address of the process that calls it, so a parent that gives a child its own address takes it first: `let me = self(); spawn(fn() = child(me))`.

A `Reply(Int)` is where an answer goes. The process that asks puts one in its request, and the process that receives the request answers it with `answer(reply, total)`.

**A process that receives nothing.** A process with no `receive` has nothing in it that says what its mailbox takes. It says so itself, with the mailbox type `Never` on its lambda: `spawn(fn() : Unit with Never = work())`. Its address is an `Address(Never)`, to which nothing can be sent. The `main` of hello-world is such a process (§1.1).

**When nothing settles the mailbox.** `spawn`'s type ties its function to the address it returns: the function is a `() -> Unit with n`, and the address an `Address(n)`. A pure function fits wherever one with a mailbox type is expected, so a pure function is spawned too. Its mailbox is then whatever the address is used as, and the first `send` to the address fixes it. Where nothing fixes it the type stays open. In a block that does no harm, and the address of a process nothing sends to may stay open. A top-level `let`, and one at the prompt, must have its type settled, and is refused until an annotation settles it (§3.3). The shell shows an open mailbox as a type variable, and the process that receives nothing as `Never`:

```console
$ ern shell
Ernest 0.3.0. :help for the commands, :quit to leave.
> :type spawn
spawn : (() -> Unit with n) -> Address(n) with m+
> spawn(fn() : Unit = Unit)
<address 84> : Address(a)
`it` is unchanged: this input did not determine the type of its value
> spawn(fn() : Unit with Never = Unit)
<address 87> : Address(Never)
```

### 4.2 A reply is answered once

A `Reply` is an obligation: whoever holds one answers it exactly once, on every path, and the compiler checks it, as §0 showed. `answer(r, v)` answers it. Giving the reply to someone else hands the obligation on with it: sending the message that carries it, passing it to a function, or returning it. A value that contains a reply is *reply-carrying*, as `CounterMsg` is because of `Get`, and the same rule holds for the whole value: it is used exactly once, neither twice nor never.

Sending a request twice consumes its reply twice:

```ernest-rejected
type CounterMsg = Inc(Int) | Get(reply : Reply(Int))

fn twice(counter : Address(CounterMsg), request : CounterMsg) : Unit with m = {
    send(counter, request);
    send(counter, request)
}
```

```console
$ ern build resend.ern
resend.ern:5:19: the reply-carrying value request is consumed twice
3 | fn twice(counter : Address(CounterMsg), request : CounterMsg) : Unit with m = {
4 |     send(counter, request);
  |                   ------- first consumed here
5 |     send(counter, request)
  |                   ^^^^^^^
  | = help: a reply is consumed by answering it, passing it on once, or matching it (§6.6)
```

**What may hold a reply.** Putting a reply in a constructor or a list hands the obligation to the value built. A list may hold a reply, as an `Optional`, an `Either` or any sum type may, and the queue of §4.4 keeps its waiting callers' replies in a list. A constructor with no reply-carrying field, `Stop` in a type whose `Get` carries one, has no obligation to hand on, and neither has the pattern `[]`.

Since each reply is counted, a reply-carrying value is never copied or dropped:

- A function that copies or drops its argument cannot take one. Neither can a `Map` or a `Set`, whose operations are the runtime's.
- It is no operand of `==` or `!=`.
- `_` cannot stand for one in a pattern.
- No field is selected from one, since the selection would drop the other fields. One is not the base of a record update, since the update would drop the field it replaces. A pattern takes such a value apart.

In a printed type, a variable marked `!` is one that may not hold a reply: `dup : (a!) -> #(a!, a!)` for a function that copies its argument, and `List.size : (List(a!)) -> Int` for one that drops a list's elements.

**A reply in a lambda.** Capturing a reply in a lambda hands the obligation to the lambda. The lambda is then used exactly once itself: called once, or given straight to `spawn`.

**Paths that need not answer.** The check is on paths, not on time. A path that calls `fault` need not answer, since the fault ends the process and every call waiting on it at once (§6.5). Nor need a path that calls a function whose result type is a type variable that neither a parameter's type nor its mailbox type names, as `fn die(cause : String) : a = fault(cause)`, since such a function cannot return. A path that faults inside a function whose type says it returns, or waits for ever, must still answer on paper: the compiler reads the type, and the caller's deadline covers a wait (§4.4).

**Paths that may be skipped.** The right operand of `&&` or `||` is skipped where the left decides alone, and what follows a `let p <- e` is skipped where a `None` or a `Left` leaves the block. A reply held there is answered before it or after it, never in it.

Report §6.6 gives the whole discipline.

### 4.3 Selective receive and `after`

`receive` takes the first message that matches a clause and leaves the others in the mailbox for later. Unlike `match`, it need not cover every case, but a clause that can never match is still an error.

```ernest
type Inbox = Data(Int) | Wake

fn waitForData() : Optional(Int) with Inbox =
    receive {
        Data(n) -> Some(n)
      | after 1000 -> None
    }
```

`after 1000` gives up after 1000 milliseconds with no matching message, and `after 0` looks without waiting. Without `after`, the process waits for as long as it takes. A `receive` with only an `after` clause is a timed wait, the one `receive` a process with mailbox `Never` may use.

A guard in `receive` is narrower than one in `match`, since it chooses a message before taking it: it compares and tests only what is already at hand, the variables in scope, a top-level `let`, literals and nullary constructors, joins these with `!`, `&&` and `||`, and calls nothing (report §6.3). For more, receive the message and `match` it.

If a `Wake` is already in the mailbox, `waitForData` leaves it there and waits for a `Data`; a later `receive` can take the `Wake`.

### 4.4 `Address.call`

Synchronous request-reply, used from the caller side:

```console
$ ern shell
Ernest 0.3.0. :help for the commands, :quit to leave.
> :type Address.call
Address.call : (Address(m), (Reply(a)) -> m, Int) -> Optional(a) with n+
```

`Address.call(counter, fn(reply) = Get(reply = reply), 1000)` makes a fresh `Reply`, gives it to the function that builds the request, sends the request to `counter`, and waits up to 1000 ms. It returns `Some(v)` for an answer and `None` for none. `None` does not cancel the work: the recipient may still be computing, so a request that changes state and is sent again may change it twice. An answer that comes late is dropped and never reaches the caller's mailbox, so `Address.call` works whatever that mailbox's type is (report §6.6). `Address.callForever` waits without a deadline and returns the answer itself. When the process called ends or restarts before it answers, either call ends at once: `Address.call` returns `None`, and `Address.callForever` faults its caller, with the callee's cause where it faulted, and otherwise with a cause saying it was killed, returned without answering, was closed, was restarted by its supervisor, or had ended already. A callee that only waits keeps a `callForever` caller waiting too.

A server that cannot answer at once keeps the reply until it can, in a list as well as anywhere else a value waits (§4.2). A queue answers a `Take` with an item it has, or keeps the reply until a `Put` brings one:

```ernest
type QueueMsg = Put(Int) | Take(reply : Reply(Int))

type MainMsg = Took(Int)

// Items no one has asked for yet, and the replies of the callers waiting for
// an item.
fn queueing(items : List(Int), waiting : List(Reply(Int))) : Unit with QueueMsg =
    receive {
        Put(item) -> match waiting {
            reply :: rest -> {
                answer(reply, item);
                queueing(items, rest)
            }
          | [] -> queueing(items <> [item], [])
        }
      | Take(reply = reply) -> match items {
            item :: rest -> {
                answer(reply, item);
                queueing(rest, waiting)
            }
          | [] -> queueing([], waiting <> [reply])
        }
    }

export fn main() : Unit with MainMsg = {
    let queue = spawn(fn() = queueing([], []));
    let me = self();
    let _ = spawn(fn() = send(me, Took(take(queue))));
    send(queue, Put(7));
    receive {
        Took(item) -> Io.println("took " <> Int.toString(item))
    }
}

// Waits for an item, for as long as it takes.
fn take(queue : Address(QueueMsg)) : Int with m =
    Address.callForever(queue, fn(reply) = Take(reply = reply))
```

```console
$ ern run queue.erc
took 7
```

Each reply is answered once on every path: a `Put` answers the first caller waiting, and a `Take` answers at once or hands its reply to the list. `main` cannot wait in the call itself, since it is `main` that puts the item. A process of its own makes the call and sends the answer on as `Took(item)`, and `main` goes on to put. A process that must keep receiving while an answer is on its way calls from such a helper; one with nothing else to do calls.

**Pacing.** A mailbox has no limit. A process that sends faster than its receiver takes messages fills the receiver's mailbox, and the node's memory with it. A call paces its caller, since the caller waits for each answer before it asks again. A stream of messages is paced by a window of credits: the receiver grants a number of messages, and the sender waits for the next grant when it has sent them.

```ernest
type ConsumerMsg = Item(Int) | Last

type ProducerMsg = Credit(Int)

// Sends the items from `next` to `last` while it has credit, and waits for
// more when it has none.
fn produce(consumer : Address(ConsumerMsg),
           next : Int,
           last : Int,
           credit : Int) : Unit with ProducerMsg =
    if next > last then
        send(consumer, Last)
    else if credit == 0 then receive {
        Credit(granted) -> produce(consumer, next, last, granted)
    } else {
        send(consumer, Item(next));
        produce(consumer, next + 1, last, credit - 1)
    }

// Takes the items, granting ten more each time it has taken ten.
fn consume(producer : Address(ProducerMsg), taken : Int, sum : Int) : Unit with ConsumerMsg =
    receive {
        Item(value) -> {
            if (taken + 1) % 10 == 0 then send(producer, Credit(10)) else Unit;
            consume(producer, taken + 1, sum + value)
        }
      | Last -> Io.println("sum " <> Int.toString(sum))
    }

export fn main() : Unit with ConsumerMsg = {
    let me = self();
    let producer = spawn(fn() : Unit with ProducerMsg = produce(me, 1, 100, 0));
    send(producer, Credit(10));
    consume(producer, 0, 0)
}
```

```console
$ ern run pacing.erc
sum 5050
```

However slow the consumer, no more than ten items wait in its mailbox. Where nothing paces a queue, `Process.info` shows it building: for a live process it answers `Some(info)`, and `info.queued` is the number of messages waiting in its mailbox. A write paces its writer as a call does: `Io.println`, and every other write of the system modules, returns once its stream has taken the bytes, so a program's output goes at the pace of what reads it.

**Fan-out.** A process that sends each message to many receivers, as a chat room sends each line to its members, is not paced by any of them. A call to each would pace it by the slowest, and one receiver that stalls would then hold up all the others. So each receiver gets a window of its own. The sender keeps the credit each receiver has left, and sends only to one that has some; each receiver grants more as it takes what it was sent. A receiver that writes each message on to a socket grants once its write has returned, and a write waits while the far end is behind (§8.7), so a client that stops reading stops the grants. A receiver whose credit stays at nothing has stalled, and the sender skips it or drops it, as its protocol says. Either way, no more than its window waits in its mailbox. `Process.info` shows such a queue building, but it is for watching what runs: a program paces its messages with its own protocol.

### 4.5 Running the counter

The counter of §4.1 with a `main` that uses it, in `counter.ern`:

```ernest
type CounterMsg = Inc(Int) | Get(reply : Reply(Int))

fn count(total : Int) : Unit with CounterMsg =
    receive {
        Inc(amount) -> count(total + amount)
      | Get(reply = reply) -> {
            answer(reply, total);
            count(total)
        }
    }

export fn main() : Unit with Never = {
    let counter = spawn(fn() = count(0));
    send(counter, Inc(5));
    send(counter, Inc(3));
    match Address.call(counter, fn(reply) = Get(reply = reply), 1000) {
        Some(total) -> Io.println("count is " <> Int.toString(total))
      | None -> Io.println("counter did not answer")
    }
}
```

```console
$ ern build counter.ern
$ ern run counter.erc
count is 8
```

When `main` returns, or its process ends in any other way, the program ends: every process on the node ends with the reason `ProgramEnd`, which is not a fault, and output still on its way is written first. A program stopped from outside by a termination or a hangup signal ends the same way; the terminal's interrupt ends it at once, and output still on its way may be lost, unless the program reads the terminal's keys, which then deliver the interrupt as a key (report §8.2, §8.6).

The count is 8 because messages from one sender arrive in the order sent: both `Inc`s come before the `Get`. Were the counter too slow, `main` would print `counter did not answer`.

### 4.6 Explicit code replacement

A process can change its code while it runs, keeping its address and its state. The new code arrives in a message that the process's type provides for, as a function value: here one compiled into the program, in the shell one from a module that `:reload` compiled again, and on a peer one that a process spawned there brings, since a function does not cross nodes in a message (§8.2).

The counter of §4.5 gains an `Upgrade` constructor. The program is three parts of one file, `counter.ern`, which replaces the one of §4.5:

```ernest
// counter.ern
type CounterMsg =
    Inc(Int)
  | Get(reply : Reply(Int))
  | Upgrade(migrate : (Int) -> Int, next : (Int) -> Unit with CounterMsg)

fn count(total : Int) : Unit with CounterMsg =
    receive {
        Inc(amount) -> count(total + amount)
      | Get(reply = reply) -> {
            answer(reply, total);
            count(total)
        }
      | Upgrade(migrate = migrate, next = next) -> next(migrate(total))
    }
```

`Upgrade` carries two functions: `migrate` turns the old state into the new, and `next` is the new loop. `next(migrate(total))` is a tail call into the new loop with the migrated state.

A replacement loop that doubles each increment:

```ernest
// counter.ern
fn countTwice(total : Int) : Unit with CounterMsg =
    receive {
        Inc(amount) -> countTwice(total + 2 * amount)
      | Get(reply = reply) -> {
            answer(reply, total);
            countTwice(total)
        }
      | Upgrade(migrate = migrate, next = next) -> next(migrate(total))
    }
```

And a `main` that upgrades after the first `Get`:

```ernest
// counter.ern
export fn main() : Unit with Never = {
    let counter = spawn(fn() = count(0));
    send(counter, Inc(5));
    send(counter, Inc(3));
    match Address.call(counter, fn(reply) = Get(reply = reply), 1000) {
        Some(total) -> Io.println("before upgrade: " <> Int.toString(total))
      | None -> Io.println("timeout")
    };
    send(counter, Upgrade(migrate = fn(total) = total, next = countTwice));
    send(counter, Inc(1));
    match Address.call(counter, fn(reply) = Get(reply = reply), 1000) {
        Some(total) -> Io.println("after upgrade: " <> Int.toString(total))
      | None -> Io.println("timeout")
    }
}
```

```console
$ ern build counter.ern
$ ern run counter.erc
before upgrade: 8
after upgrade: 10
```

The address `counter` is unchanged, and the process behind it now runs `countTwice`, where `Inc(1)` adds 2.

### 4.7 The word counter as a process

A tally is a process that holds the counts and adds to them. `words.ern` continues:

```ernest
// words.ern, continued
export type TallyMsg = Add(Map(String, Int)) | Top(limit : Int, reply : Reply(List(#(String, Int))))

export fn tally(counts : Map(String, Int)) : Unit with TallyMsg =
    receive {
        Add(more) -> tally(Map.foldLeft(more, counts, add))
      | Top(limit = limit, reply = reply) -> {
            answer(reply, top(counts, limit));
            tally(counts)
        }
    }
```

`Add` brings a map of counts, and `Map.foldLeft` adds each word's count in with `add`, which takes the map, a word, and a count, the order the fold gives them. `Top` is a request, so it carries a `Reply`.

```console
$ ern build words.ern
$ ern shell words.erc
Ernest 0.3.0. :help for the commands, :quit to leave.
> let t = spawn(fn() = Words.tally(Map.empty))
t : Address(Words.TallyMsg)
> send(t, Words.Add(Words.count("the cat and the hat")))
> send(t, Words.Add(Words.count("the bat")))
> Address.call(t, fn(reply) = Words.Top(limit = 2, reply = reply), 1000)
Some([#("the", 3), #("and", 1)]) : Optional(List(#(String, Int)))
```

A `send` is `Unit`, which the shell does not print.

### 4.8 Prediction exercise

Does `Address.call(counter, ..., 1000)` returning `None` guarantee the recipient did no work?

## 5. Manage process lifetime

Two processes that talk must also know when the other is done.

### 5.1 Ping-pong

```ernest
type PongMsg = Ping(round : Int, reply : Reply(Int)) | Stop

type MainMsg = PongDone(Down)

export fn main() : Unit with MainMsg = {
    let opponent = spawnMonitored(fn() = pong(), PongDone);
    let _ = spawn(fn() = ping(opponent, 3));
    receive {
        PongDone(_) -> Unit
    }
}

fn ping(opponent : Address(PongMsg), round : Int) : Unit with m =
    if round == 0 then
        send(opponent, Stop)
    else {
        Io.println("ping " <> Int.toString(round));
        match Address.call(opponent, fn(reply) = Ping(round = round, reply = reply), 5000) {
            Some(_) -> ping(opponent, round - 1)
          | None -> {
                Io.println("pong is not answering");
                send(opponent, Stop)
            }
        }
    }

fn pong() : Unit with PongMsg =
    receive {
        Ping(round = round, reply = reply) -> {
            Io.println("pong " <> Int.toString(round));
            answer(reply, round);
            pong()
        }
      | Stop -> Unit
    }
```

`ping` never receives, so its mailbox `m` is any type; it must be a real one, since `Address.call` runs only in a process (§3.5).

`main` starts pong with `spawnMonitored`, which §5.2 explains, so that a `PongDone` arrives when pong ends, and waits for it. Had `main` returned at once, the program would have ended before the two had played, since returning from `main` ends every process (§4.5).

The output is `ping 3`, `pong 3`, `ping 2`, and so on, alternating. Messages from one sender arrive in the order sent, so ping's requests reach pong in order. `Io.println` returns once standard output has taken the line (report §8.2), and ping prints before it calls pong, pong before it answers, so each line is written before the next can be. Two processes whose writes nothing orders, two workers printing as they go, interleave in an order no rule fixes.

### 5.2 `monitor` and `Down`

```console
$ ern shell
Ernest 0.3.0. :help for the commands, :quit to leave.
> :type monitor
monitor : (Process, (Down) -> m) -> Unit with m
> :type spawnMonitored
spawnMonitored : (() -> Unit with n, (Down) -> m) -> Address(n) with m
```

```ernest-prelude
type Down = Down(process : Process, reason : Reason, site : String)

type Reason = Returned | Killed | ProgramEnd | Fault(String) | Unknown
```

`monitor(child, wrap)` puts `wrap(d)` in your mailbox when the process `child` dies, or at once if it is dead already, with the reason `Unknown`, since the runtime keeps nothing of a process that has ended. `child` is a `Process`, the identity of a process, which `Process.fromAddress(a)` gives for an address `a`: watching a process needs no permission to send to it, so a server watches the clients it holds no address to. A process you start yourself is watched from its start with `spawnMonitored(f, wrap)`, `spawn` and `monitor` in one step, so that no end comes before the watch. `wrap` makes your message from the runtime's `Down`: in ping-pong, `PongDone` is a constructor of `MainMsg` that carries one. A `Down` says the process ended, not that it succeeded; its `process` says which, its `reason` says how, and its `site` says where it was spawned, the top-level declaration and the line of the spawn, `Counter.main:19`.

A process that monitors a worker while waiting for its answer gets two messages, the answer and the death, and takes the answer; the death is still in the mailbox when the next worker is monitored. The `Down` names the process it is about, and the worker names itself in its answer, so the wait takes what is about the worker it waits for:

```ernest
type MainMsg = Result(from : Process, value : Int) | Died(Down)

fn work(job : Int) : Int =
    job * job

fn worker(parent : Address(MainMsg), job : Int) : Unit with Never =
    send(parent, Result(from = Process.fromAddress(self()), value = work(job)))

fn runWorker(job : Int) : Optional(Int) with MainMsg = {
    let me = self();
    let child = spawnMonitored(fn() = worker(me, job), Died);
    waitFor(Process.fromAddress(child))
}

fn waitFor(child : Process) : Optional(Int) with MainMsg =
    receive {
        Result(from = w, value = v) when w == child -> Some(v)
      // it returned, so it sent its result first: the result is still to come
      | Died(Down(process = p, reason = Returned)) when p == child -> waitFor(child)
      | Died(Down(process = p)) when p == child -> None
      | _ -> waitFor(child)
    }

fn report(job : Int) : Unit with MainMsg =
    match runWorker(job) {
        Some(v) -> Io.println("job " <> Int.toString(job) <> ": " <> Int.toString(v))
      | None -> Io.println("job " <> Int.toString(job) <> ": the worker died")
    }

export fn main() : Unit with MainMsg = {
    report(1);
    report(2)
}
```

```console
$ ern run jobs.erc
job 1: 1
job 2: 4
```

Anything else is an earlier worker's death, and `waitFor` takes it and passes over it, so that it does not stay in the mailbox.

A `Down` comes from the runtime and not from the process that ended, so it has no order with that process's own messages (§5.1): a worker's last message may arrive after its `Down`. `waitFor` allows for it with the `Down`'s reason. A worker that `Returned` sent its result before it did, so the wait goes on until the result comes. Any other reason, a fault or a kill, ended the worker before it sent one, and the wait answers `None`. A result that should need no such care comes as the worker's answer to a call (§4.4), which its end does not overtake.

`Process.live()` lists the live processes, `Process.info(p)` tells where one was spawned, how many messages wait for it and whether it runs, and `Process.faults(wrap)` sends you every fault as it happens (report Appendix E.21). They are for seeing what runs, and a program is still written with the addresses it was given.

A fault in one process does not affect another, apart from the cases §6.3 lists.

### 5.3 `kill`

```console
$ ern shell
Ernest 0.3.0. :help for the commands, :quit to leave.
> :type kill
kill : (Address(a)) -> Unit with m+
```

`kill(addr)` ends the process at `addr`, and its monitors receive `Down(reason = Killed, ...)`. The process may run a little before it stops. The REPL of [`examples/repl.ern`](examples/repl.ern) kills an evaluation that runs too long.

### 5.4 Deadlock

When every process waits in a `receive` or a `callForever` that nothing can ever satisfy, the entry process faults with `deadlock`, and the program ends. A process waiting for a timer, a key, a socket, or a file is waiting for something that can come, so an idle server is not deadlocked. Report §8.6 gives the exact condition.

### 5.5 A process's addresses

A process has one mailbox, and its mailbox has one type, but the process may be reached through many addresses, each of the type it accepts. `self()` is one: in a process whose mailbox is `GameMsg`, an `Address(GameMsg)`. `via` makes others:

```console
$ ern shell
Ernest 0.3.0. :help for the commands, :quit to leave.
> :type via
via : (Address(b), (a) -> b) -> Address(a)
```

`via(target, convert)` is an `Address(a)`: an `a` sent to it arrives at `target` as `convert(a)`. An adapted address is not a process; it is a value, kept like any other.

**Why.** Whoever sends need not know the type of the mailbox it sends to. A worker written to report to an `Address(Either(String, Int))` knows nothing of your `GameMsg`. Given `via(me, Done)`, its report arrives as `Done(result)`:

```ernest
type GameMsg = Done(Either(String, Int)) | Tick(Int)

fn worker(report : Address(Either(String, Int))) : Unit with m =
    send(report, Right(42))

fn startWorker() : Unit with GameMsg = {
    let me = self();
    let _ = spawn(fn() = worker(via(me, Done)));
    receive {
        Done(Right(n)) -> Io.println("done: " <> Int.toString(n))
      | Done(Left(error)) -> Io.println("failed: " <> error)
      | Tick(_) -> Unit
    }
}
```

A library is used the same way, written against a message type of its own, so a program never needs one message type for all its processes.

**Whatever arrives later is delivered so too.** Wherever something arrives later, the function that asks for it takes the function that makes your message from its own (report Appendix E.0 shape rule 8): `monitor(child, wrap)` (§5.2), `Clock.alarm(ms, wrap)`, which puts `wrap(t)` in your mailbox after `ms` milliseconds, `t` the time it fired, `Terminal.subscribe(wrap)`, which puts every key pressed and every resize in it, and `Process.faults(wrap)`. A constructor with one positional field is a function value, so `Clock.alarm(100, Tick)` delivers `Tick(t)`. A message that needs no value is made by a lambda that ignores it, `Clock.alarm(100, fn(_) = Refresh)` for a constructor `Refresh` without fields.

**Where the function runs.** A `send` to an adapted address applies the function in the sender, at the `send`, which returns once it has; the sender's messages keep their order through it (§5.1). A wrap has no sender to run in, so the runtime applies it as it delivers the message. Either way, a fault in the function is the fault of the process the message is for, not of the one that sent it (report §6.5, report §6.9), so keep the function to shaping the value:

```ernest
type SplitMsg = Half(Int)

fn halves(target : Address(SplitMsg)) : Address(Int) =
    via(target, fn(n) = Half(100 / n))
```

A `0` sent to `halves(t)` faults the process `t` names, with `division by zero`, and the sender goes on.

**What does not deliver.** `Io.readLine`, `Os.read` and `Tcp.read` put nothing in your mailbox. Each is a call, answered to the process that made it, which waits for the answer; two processes that read one socket each get the part that answers their own read. A process that must go on taking messages while input may come gives the reading to a process of its own, which reads and sends what it read to an address it was given:

```ernest
type ChatMsg = Line(Optional(String)) | Said(String)

fn reader(listener : Address(Optional(String))) : Unit with m = {
    let line = Io.readLine();
    send(listener, line);
    match line {
        Some(_) -> reader(listener)
      | None -> Unit
    }
}

fn chat() : Unit with ChatMsg = {
    let me = self();
    let _ = spawn(fn() = reader(via(me, Line)));
    talk()
}

fn talk() : Unit with ChatMsg =
    receive {
        Line(Some(text)) -> {
            Io.println("you: " <> text);
            talk()
        }
      | Line(None) -> Unit
      | Said(text) -> {
            Io.println("them: " <> text);
            talk()
        }
    }
```

**One process behind them all.** Addresses have no equality, since an adapted address holds a function. The process behind an address has: `Process.fromAddress(a)` is a `Process`, the same one through every `via`, which can key a `Map` or be kept in a `Set` and to which nothing can be sent. `kill` takes any of a process's addresses and acts on the process behind it. An address is the authority to reach a process, which is why `kill` takes one; a `Process` is its identity, which anyone may list, and what `monitor`, `Process.info` and `Tcp.give` take: watching a process needs no authority over it.

```ernest
type CountMsg = Counted(Int)

fn oneProcess(me : Address(CountMsg)) : Bool =
    Process.fromAddress(via(me, Counted)) == Process.fromAddress(me)
```

`oneProcess(self())` is `true`, and `via(me, Counted) == me` does not compile.

**Addresses travel.** An address is a value: it goes in a message, a field or a list, as `Link(me)` does in [`examples/file_sync.ern`](examples/file_sync.ern). To another node, an adapted address of your own process goes too, and its function stays here (§8.2).

`Clock.alarm` fires once. A periodic tick is scheduled again after each tick is handled, and only then: a loop that scheduled one on every message would add a timer per key pressed. Two functions keep the two apart:

```ernest
type GameMsg = Tick(Int) | Input(Char)

type World = World(score : Int)

fn step(world : World) : World =
    World(score = world.score + 1)

fn game(state : World) : Unit with GameMsg = {
    Clock.alarm(100, Tick);
    waitForTick(state)
}

fn waitForTick(state : World) : Unit with GameMsg =
    receive {
        Tick(_) -> game(step(state))
      | Input(_) -> waitForTick(state)
    }
```

`game` schedules one alarm and hands over to `waitForTick`, which takes inputs without touching the alarm; only a `Tick` returns to `game`, which schedules the next. `step` reads the world's field by selecting it, `world.score`.

An alarm cannot be cancelled. A process that no longer wants one takes its message when it comes and drops it, since even a cancel could not take back a message already delivered. A deadline for a piece of work carries the work's id, `Clock.alarm(5000, fn(_) = Expired(job))`, and the loop that waits matches every `Expired`, acting on one whose job is still open and dropping the rest; a message that no `receive` takes stays in the mailbox for as long as the process lives (report Appendix E.15).

### 5.6 The word counter at once

Several texts are counted at once, by a worker each, and the tally totals them. `words.ern` gets its `main`:

```ernest
// words.ern, continued
type MainMsg = Counted(Map(String, Int)) | Died(Down)

export fn main() : Unit with MainMsg = {
    let totals = spawn(fn() = tally(Map.empty));
    countAll(totals, ["the cat and the hat", "the bat and the ball", "a cat"]);
    match Address.call(totals, fn(reply) = Top(limit = 3, reply = reply), 1000) {
        Some(best) -> List.foreach(best, fn(#(w, c)) = Io.println(w <> " " <> Int.toString(c)))
      | None -> Io.println("the tally did not answer")
    }
}

fn countAll(totals : Address(TallyMsg), texts : List(String)) : Unit with MainMsg = {
    let me = self();
    List.foreach(texts, fn(text) = {
        let _ = spawnMonitored(fn() = send(me, Counted(count(text))), Died);
        Unit
    });
    collect(totals, List.size(texts))
}

fn collect(totals : Address(TallyMsg), left : Int) : Unit with MainMsg =
    if left == 0 then
        Unit
    else receive {
        Counted(counts) -> {
            send(totals, Add(counts));
            collect(totals, left - 1)
        }
      | Died(Down(reason = Fault(cause))) -> {
            Io.println("a worker faulted: " <> cause);
            collect(totals, left - 1)
        }
      | Died(_) -> collect(totals, left)
    }
```

```console
$ ern build words.ern
$ ern run words.erc
the 4
and 2
cat 2
```

Each worker counts one text and sends the map to `main`, not to the tally. Messages are ordered per sender only (§5.1), so an `Add` a worker sent to the tally could arrive after the `Top` that `main` sends; sent by `main`, they arrive in order. `main` monitors every worker, so one that faults is counted as done and reported. A worker that returned is counted by its `Counted`, so `collect` passes over its `Down`, whichever of the two arrives first (§5.2).

### 5.7 Prediction exercise

Given the ping-pong program, does the runtime guarantee ping and pong's `Io.println` output appears in strictly alternating order?

## 6. Handle failure

Something goes wrong in one of three ways, and each has its place. A failure the caller can act on is a value. A failure another process must act on is a message. What the program did not expect is a fault, which ends the process it happens in, or restarts it in place, and the processes that watch it decide what follows. Nothing is caught: there is no exception to throw and no handler to catch one, so the path a failure takes is always in the code.

### 6.1 A value

A failure the caller can act on is returned: `Optional` when absence is the whole story, `Either` when there is a reason. `<-` passes a `Left` on without a line written for it (§2.7), and a statement cannot drop one (§0).

```ernest
type Config = Config(port : Int, workers : Int)

fn field(text : String, name : String) : Either(String, Int) = {
    let number <- Either.fromOptional(String.toInt(text), name <> " is not a number");
    if number > 0 then Right(number) else Left(name <> " must be positive")
}

fn parse(portText : String, workersText : String) : Either(String, Config) = {
    let port <- field(portText, "port");
    let workers <- field(workersText, "workers");
    Right(Config(port = port, workers = workers))
}

fn show(result : Either(String, Config)) : String =
    match result {
        Right(Config(port = port, workers = workers)) ->
            "port " <> Int.toString(port) <> ", " <> Int.toString(workers) <> " workers"
      | Left(reason) -> "no config: " <> reason
    }

export fn main() : Unit with Never = {
    Io.println(show(parse("8080", "4")));
    Io.println(show(parse("8080", "four")))
}
```

```console
$ ern run config.erc
port 8080, 4 workers
no config: workers is not a number
```

`field` checks one number, `parse` chains two checks and stops at the first `Left`, and `show` is the one place that decides what a failure means.

### 6.2 A message

Between processes a failure is part of the protocol. A request whose work can fail is answered with an `Either`, and the process that asked handles a `Left` as it handles any answer. `Address.call` adds a case of its own, `None`, for an answer that did not come: in time, or at all, since a call ends at once when the process called ends or restarts. A deadline bounds how long the caller waits: `None` says that no answer was obtained, not whether the process called did the work, or will.

```ernest
type ParserMsg = Parse(text : String, reply : Reply(Either(String, Int)))

fn parsing() : Unit with ParserMsg =
    receive {
        Parse(text = text, reply = reply) -> {
            answer(reply, Either.fromOptional(String.toInt(text), text <> " is not a number"));
            parsing()
        }
    }

fn outcome(parser : Address(ParserMsg), text : String) : String with m =
    match Address.call(parser, fn(reply) = Parse(text = text, reply = reply), 1000) {
        Some(Right(n)) -> "parsed " <> Int.toString(n)
      | Some(Left(reason)) -> "refused: " <> reason
      | None -> "no answer in time"
    }

export fn main() : Unit with Never = {
    let parser = spawn(fn() = parsing());
    Io.println(outcome(parser, "42"));
    Io.println(outcome(parser, "forty-two"))
}
```

```console
$ ern run ask.erc
parsed 42
refused: forty-two is not a number
```

The parser refuses the text and goes on serving. A refusal is an answer, not a failure of the parser.

### 6.3 A fault

A fault is what the program did not expect: a division by zero, a `Float` result out of range, a `fault("...")` the program calls on an invariant it finds broken. Report §7.4 lists the language's causes, a library function's section gives its own (report §7.3), and a failure of the runtime, a spawn past the host's limit of processes among them, is one too (report §7.3). Running out of memory is no fault: the host ends the whole program (report §10). A fault ends the process it happens in, and only that process, unless the process restarts (§6.5). A process that monitors it receives a `Down` whose reason is `Fault(cause)`:

```ernest
type MainMsg = WorkerDied(Down)

fn average(total : Int, count : Int) : Int =
    total / count

fn worker(count : Int) : Unit with Never =
    Io.println(Int.toString(average(100, count)))

export fn main() : Unit with MainMsg = {
    let _ = spawnMonitored(fn() = worker(0), WorkerDied);
    receive {
        WorkerDied(Down(reason = Fault(cause), site = site)) ->
            Io.println("the worker spawned at " <> site <> " faulted: " <> cause)
      | WorkerDied(_) -> Io.println("the worker ended")
    }
}
```

```console
$ ern run faults.erc
Faults.main:10 faulted: division by zero
the worker spawned at Faults.main:10 faulted: division by zero
```

`average` is pure and still faults, as §3.4 says a pure function may. The `site` of a `Down` names the top-level declaration in which the process was spawned and the line of the spawn. The first line is `ern run`'s own: it writes every fault to standard error as it happens, the spawn site and the cause, whatever the program does about it. Where standard error goes to a file or a pipe, and not to the journal, each line begins with the time of the fault (report §11.2).

Some faults reach beyond their process. A fault in the entry process ends the program, and `ern run` exits with status 1, as a fault in an initializer does. A fault in a function that makes a message, an adapted address's (§5.5) or the wrap given to `monitor`, `Clock.alarm`, `Terminal.subscribe` or `Process.faults`, is the fault of the process the message is for. The loss of a peer faults every process on it (report §10). A fault in a process that a `callForever` waits on faults the caller with the same cause (report §6.6). A process that is killed, or that ends with the program, has not faulted. A deadlock is a fault of the entry process (§5.4).

### 6.4 Let it crash

A worker need not guard against what it did not expect. It faults, and the process that watches it decides what follows: it tries again, gives up, or ends too. The recovery is written once, in the watcher, and the worker's code is only its work. The watcher supervises the worker, and it is spawn, monitor, and receive:

```ernest
type SupervisorMsg = Result(Int) | Ended(Down)

fn supervise(jobs : List(Int)) : Unit with SupervisorMsg =
    match jobs {
        [] -> Io.println("all jobs done")
      | job :: rest -> {
            let me = self();
            let _ = spawnMonitored(fn() = send(me, Result(100 / job)), Ended);
            Io.println(Int.toString(job) <> ": " <> outcome());
            supervise(rest)
        }
    }

// The worker's answer, or the fault that ended it. A worker that returned
// has sent its answer, so after its end the answer is taken too, whichever
// arrived first, and neither is left for the next worker.
fn outcome() : String with SupervisorMsg =
    receive {
        Ended(Down(reason = Fault(cause), site = _)) -> "failed, " <> cause
      | Ended(_) -> receive {
            Result(n) -> Int.toString(n)
        }
    }

export fn main() : Unit with SupervisorMsg =
    supervise([4, 0, 5])
```

```console
$ ern run jobs.erc
4: 25
Jobs.supervise:8 faulted: division by zero
0: failed, division by zero
5: 20
all jobs done
```

A process for each job is the restart: the job that faulted ends its own worker, and the next job starts with a fresh one. Of the program, only `supervise` prints, so what became of each job is said in one place; the second line is `ern run`'s report of the fault, on standard error. A worker reports by a message to its supervisor, which knows the job and decides what follows.

What must survive a fault lives in the process that does not fault: here the list of jobs is the watcher's. A long-lived process restarts in place instead, which §6.5 shows, and a group of them restarts together under the standard library's `Supervisor`, which §6.6 shows. A process that must not outlive another monitors it and returns when it dies.

### 6.5 A service

A *service* is a process the program reaches by name. The name is a top-level binding whose value is the process's address, `counter` below, so a module sends to the process by writing its name, and `export` says which modules may. It is not a registry: the name is resolved by the compiler, in the module's scope, like any other name, and is typed by its declaration.

```ernest
export type CounterMsg = Add(amount : Int, reply : Reply(Int))

// The service: the program's counter, reached by this name.
export let counter : Address(CounterMsg) = start()

// A counter, restarted in place after a fault. A test calls it for a
// counter of its own.
export fn start() : Address(CounterMsg) with m =
    spawn(restarting(RestartLimit(restarts = 3, within = 5000), fn() = count(0)))

// The counter's loop, which faults on a negative amount.
fn count(total : Int) : Unit with CounterMsg =
    receive {
        Add(amount = amount, reply = reply) -> if amount < 0 then
            fault("a negative amount")
        else {
            answer(reply, total + amount);
            count(total + amount)
        }
    }

export fn main() : Unit with Never = {
    let add =
        fn(amount) = Address.call(counter, fn(reply) = Add(amount = amount, reply = reply), 1000);
    Io.println(Io.show(add(2)));
    Io.println(Io.show(add(-1)));
    Io.println(Io.show(add(3)))
}
```

```console
$ ern run counter.erc
Some(2)
Counter.start:9 faulted, restarted: a negative amount
None
Some(3)
```

`counter` is evaluated before `main` runs, in the entry process, like every top-level `let` (§2.2). An initializer may spawn, send and call, but not receive, so a service's `let` starts its process and nothing waits.

`restarting(RestartLimit(restarts = 3, within = 5000), f)` is a function that runs `f`, and runs it again after a fault, in the same process, with the same address. The new run begins with an empty mailbox, and what the process asked the runtime for, an alarm, a monitor, a subscription, is cancelled (report §6.9). Whoever holds the address keeps it, so nothing is handed out again after a restart. What the loop held is gone: the count starts at zero again, as `Some(3)` shows. After three restarts within five seconds, the next fault ends the process (report §6.9); `restarting(Unlimited, f)` runs `f` again after every fault. A restart is not an end: no `monitor` hears of it, and the process's `Down` comes only when it ends for good.

The call that was waiting when the counter faulted ends at once: `Address.call` answers `None`, and `Address.callForever` would fault the caller with the same cause. A caller that must outlive a service's faults calls with a limit. The second line is `ern run`'s report of the fault, on standard error (§6.3).

`fault` is the fault a program raises when it finds a case it will not handle. The path that calls it does not answer `reply`, and need not (§4.2): the fault ends the counter's process, and the call waiting on it ends at once. `start` is exported beside the binding so that a test can start a counter of its own instead of sharing the program's.

### 6.6 A supervisor

`restarting` restarts one process. A *supervisor* restarts a group of processes, its children, together when one of them faults, and gives up when they fault too often. The standard library's `Supervisor` is one (report Appendix E.22). The program spawns the supervisor and each child, usually as service bindings:

```ernest
// pair.ern
type CounterMsg = Add(amount : Int, reply : Reply(Int))

let group : Address(Supervisor.Msg) =
    spawn(Supervisor.group(Supervisor.OneForAll, RestartLimit(restarts = 3, within = 5000)))

let visits : Address(CounterMsg) = spawn(Supervisor.child(group, fn() = count(0)))

let sales : Address(CounterMsg) = spawn(Supervisor.child(group, fn() = count(0)))

fn count(total : Int) : Unit with CounterMsg =
    receive {
        Add(amount = amount, reply = reply) -> if amount < 0 then
            fault("a negative amount")
        else {
            answer(reply, total + amount);
            count(total + amount)
        }
    }

fn add(counter : Address(CounterMsg), amount : Int) : Optional(Int) with m =
    Address.call(counter, fn(reply) = Add(amount = amount, reply = reply), 1000)

export fn main() : Unit with Never = {
    Io.println(Io.show(add(visits, 2)) <> " " <> Io.show(add(sales, 5)));
    Io.println(Io.show(add(visits, -1)));
    Io.println(Io.show(add(visits, 1)) <> " " <> Io.show(add(sales, 1)))
}
```

```console
$ ern run pair.erc
Some(2) Some(5)
Pair.visits:7 faulted, restarted: a negative amount
None
Some(1) Some(1)
```

`Supervisor.group(strategy, limit)` is the function the supervisor runs, and `Supervisor.child(group, f)` the function a child runs. The program spawns each, as it spawns what `restarting` answers, so the fault line names the child's binding. A child joins the group before `f` runs, and waits until the supervisor has it; after a fault it runs `f` again in place, as under `restarting`.

The strategy says which siblings restart with the child that faulted. `OneForOne` restarts none. `OneForAll` restarts every other child, so `sales` starts from zero too. `RestForOne` restarts the children spawned after it, for services that use the ones before them; the order is the order of the `spawn`s, not of the joins, which the scheduler decides. A sibling runs on until it next waits, in a `receive` or for a call's answer, and restarts there, with the same address, as a fault restarts a process, and the child that faulted waits for it; a sibling that never waits is never restarted (report Appendix E.22). Its restart is not a fault, so `ern run` reports only the fault of `visits`. A call waiting on a sibling as it restarts ends: `Address.call` answers `None`, and `Address.callForever` faults with `callee was restarted` (report §6.6). So for a moment after a fault, a call to a sibling may be answered from its old state, end, or be answered from its new one. The child that faulted runs again only once each sibling has restarted, so a call to it after its fault is answered by the group restarted whole (report Appendix E.22): `add(visits, 1)` is, and `sales` has restarted before `main` asks it. A client that relies on a service's state after a fault takes the state as lost and asks again.

The limit is the group's. When its children have faulted `restarts` times within `within` milliseconds, the next fault makes the supervisor give up: it faults, with `supervisor restart limit reached`. A supervisor is a child like any other, `spawn(Supervisor.child(parent, Supervisor.group(...)))`, so groups form a tree. A supervisor under a parent restarts in place when it gives up, or when its parent restarts it with a sibling, and asks each of its children to restart; every binding keeps its address, and the fault is the parent's to count. A supervisor at the root that gives up dies. A supervisor and its children run on one node; between nodes, a process watches another with `monitor` (§8).

When a supervisor dies, given up, killed, or of a defect of its own, its children are killed after it, the last spawned first, each once the one before has ended; so `kill(group)` stops a group. A killed process runs nothing more, so a child that must finish its work, a file to flush, is sent a message of its own protocol first. A child that returns or is killed leaves the group, and a child may join at any time, so one supervisor also holds the children a program starts while it runs, one per connection.

### 6.7 Prediction exercise

```ernest
fn first(list : List(Int)) : Int =
    match list {
        x :: _ -> x
      | [] -> fault("first of an empty list")
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

export fn parse(text : String) : Optional(Request) =
    if text == "GET /" then Some(Request(method = "GET", path = "/")) else None
```

```ernest
// main.ern  (namespace Main)
export fn main() : Unit with Never =
    match Net.Http.parse("GET /") {
        Some(Net.Http.Request(method = method, path = path)) -> Io.println(method <> " " <> path)
      | None -> Io.println("bad request")
    }
```

`main.ern` names the constructor `Net.Http.Request` by its whole name, as it names the function.

Compile file-by-file and run:

```console
$ ern build net/http.ern              # produces net/http.erc
$ ern build main.ern                  # produces main.erc
$ ern run main.erc                   # net/http.erc is found under main.erc's root, which is on the load path
GET /
```

Or compile the whole tree at once, into `build/`:

```console
$ ern build --build-root build .         # walks the source tree, writes build/net/http.erc and build/main.erc
$ ern run build/main.erc
GET /
```

Directory mode compiles the modules in the order their dependencies need, and a second run compiles again only what changed (§9.1).

**The file's path is its namespace.** A file at `a/b/c.ern` under the source root declares the namespace `A.B.C`: each directory and the file name is one or more lowercase words joined by `_`, and the namespace capitalizes each word and drops the `_`, `ordered_set.ern` for `OrderedSet`. A directory adds a namespace segment: `http/parser.ern` is `Http.Parser`, a module apart from `http_parser.ern`'s `HttpParser`. The source root is `--source-root dir`; without it, the directory `ern build` is given, or for a single file the working directory. A module may not take a namespace the prelude or the standard library has, so `io.ern` at the root is refused (report §4.2, report §11.1).

**Declarations use local names.** In `net/http.ern`, `export fn parse(...)` declares `parse`, which the code outside reaches as `Net.Http.parse`, and the code inside by either name.

**`export` marks the boundary.** A declaration with `export` is visible from other modules, and one without is the module's own. There is no `import` and no export list. The constructors of an exported type are exported with it; an abstract type's constructors are visible only in its own module (§7.2). An exported declaration's type, and the fields of an exported type that is not abstract, may name only exported types. A function's mailbox type is exempt, so an exported `main` may receive a private message type (report §4.2).

**A module's own name hides the prelude's.** A module may declare its own `Unknown`, which then means its own throughout the module; `Prelude.Unknown` still names the prelude's (report §4.2).

**Testing a module.** A test is a top-level `let` of the type `Test.Case(m)`, a name and a function returning `Test.Passed` or `Test.Failed(text)`, which runs in a process whose mailbox type is `m` (report Appendix E.24). `Test.equal(actual, expected)` is the comparison most tests make: `Test.Passed` where the two are equal, and otherwise `Test.Failed("expected 2, got 3")`, each value as `Io.show` writes it:

```ernest
fn add(left : Int, right : Int) : Int =
    left + right

let addsTwo = Test.Case(name = "adds two", run = fn() = Test.equal(add(1, 1), 2))

type Reported = Reported(Int)

let answersBack = Test.Case(name = "a worker answers back", run = fn() = {
    let me = self();
    let _ = spawn(fn() : Unit with Never = send(me, Reported(add(1, 1))));
    receive {
        Reported(n) -> Test.equal(n, 2)
    }
})
```

```console
$ ern build checks.ern
$ ern test checks.erc
adds two: passed
a worker answers back: passed
```

`ern test` runs every test of the module, one at a time in the order the module declares them, each in a process of its own, and prints each as it ends: passed, failed with its text, or faulted with its cause. A test's `run` is `() -> Test.Result with m`: it runs in a process whose mailbox type is `m`, as an entry point does (report §8.1), so it may spawn, send, call and receive. `addsTwo` receives nothing and leaves `m` open, and `ern test` runs it with `Never`; `answersBack` receives a `Reported`, so its type is `Test.Case(Reported)`, which nothing writes. A test left waiting with nothing to wake it is faulted with `deadlock` while the run goes on (report §11.2). Given a directory, `ern test build` runs the tests of every module compiled under it, each module's name on a line before what it writes, and passes over a module that has none.

**Documenting a module.** A `///` block, on lines of its own, documents the declaration on the line after it, and one first in the file, with a blank line after it, documents the module. The text is CommonMark; `ern doc` renders the module as a page, and the shell's `:doc` shows a declaration's part of it, or a module's head, rendered for the terminal. What a module's documentation contains is report Appendix E.0 shape rule 6, and [`docs/module_doc_template.md`](docs/module_doc_template.md) shows it on an example module.

**Entry point.** `ern run main.erc` runs `export fn main`, and `--main` runs another exported function that takes no arguments and returns `Unit`. A module may export several entry points, and `--main` names the one to run, here `check` of `tools.ern`:

```console
$ ern run --main Tools.check build/tools.erc
```

### 7.2 Abstract types

An abstract type keeps its representation to its module: every definition in the module may name its constructor, and no other module can. A type's operations are functions of its module, so a stack is a module of its own, `stack.ern`, whose functions other modules call `Stack.push` and `Stack.pop`. Only an operator, `compare` and `negate` are declared with the type's name before theirs, as report §4.8's `fn Distance.+` is.

```ernest
// stack.ern  (namespace Stack)
export abstract type Stack(a) = Stack(List(a))

export let empty : Stack(a) = Stack([])

export fn push(Stack(items) : Stack(a), item : a) : Stack(a) =
    Stack(item :: items)

export fn pop(Stack(items) : Stack(a)) : Optional(#(a, Stack(a))) =
    match items {
        [] -> None
      | item :: rest -> Some(#(item, Stack(rest)))
    }

export fn size(Stack(items) : Stack(a)) : Int =
    List.size(items)
```

Inside `stack.ern` the operations are `push` and the rest, and any definition may take a `Stack` apart, a private helper or a test included. Outside, they are `Stack.push` and the rest, the type is `Stack.Stack`, and `Stack.Stack([])` is an error: another module sees the type and the operations, never the constructor.

An abstract type is exported, since one its module keeps would hide from no module:

```ernest-rejected
abstract type Stack(a) = Stack(List(a))
```

```console
$ ern build hidden.ern
hidden.ern:1:1: Stack is an abstract type the module keeps private, which hides its constructors from no module
1 | abstract type Stack(a) = Stack(List(a))
  | ^^^^^^^^
  | = help: export it, or declare it `type`
```

The representation may change later, a tree for the list, and the modules that use the stack still work, since none of them could name it.

### 7.3 Code written once over several representations

Code is often written once for a kind of thing that has several representations: a set kept in a hash and a set kept in order, a sum over `Int` and over `Float`. Ernest has three forms for it, and a module of the standard library shows the first.

**A module that declares what it needs.** `OrderedSet` keeps a set's elements in the order of their type's `compare`. A function that needs the order says so after its result type, `needs a.compare`, a *requirement* (report §4.9): in its body `a.compare` is the member of the type `a` stands for, and `<` resolves to it, as both would on a known type. Here are the parts of `stdlib/ordered_set.ern` that show the requirement, with their doc blocks left out; the rest of the module, the functions that need no order among them, is in the file, and `:doc OrderedSet` lists it:

```ernest-fragment
// stdlib/ordered_set.ern  (namespace OrderedSet), in part, its doc blocks left out
export abstract type Set(a) = Set(List(a))

export let empty : Set(a) = Set([])

export fn fromList(list : List(a)) : Set(a) needs a.compare =
    Set(firstOfEach(List.sort(list, a.compare)))

// The first of each run the order calls `Equal` in a sorted list. The sort
// is stable, so the list's earlier occurrence comes first and is the one
// kept, as `put` keeps the element already there.
fn firstOfEach(sorted : List(a)) : List(a) needs a.compare =
    match sorted {
        first :: second :: rest -> if a.compare(first, second) == Equal then
            firstOfEach(first :: rest)
        else
            first :: firstOfEach(second :: rest)
      | _ -> sorted
    }

export fn size(Set(list) : Set(a)) : Int =
    List.size(list)

export fn contains(Set(list) : Set(a), element : a) : Bool needs a.compare =
    has(list, element)

fn has(list : List(a), element : a) : Bool needs a.compare =
    match list {
        [] -> false
      | head :: rest -> match a.compare(element, head) {
            Less -> false
          | Equal -> true
          | Greater -> has(rest, element)
        }
    }

export fn put(Set(list) : Set(a), element : a) : Set(a) needs a.compare =
    Set(inserted(list, element))

fn inserted(list : List(a), element : a) : List(a) needs a.compare =
    match list {
        [] -> [element]
      | head :: rest -> match a.compare(element, head) {
            Less -> element :: list
          | Equal -> list
          | Greater -> head :: inserted(rest, element)
        }
    }

export fn map(Set(list) : Set(a), f : (a) -> b with e) : Set(b) with e needs b.compare =
    fromList(List.map(list, f))

export fn toList(Set(list) : Set(a)) : List(a) =
    list
```

The set is a sorted list and nothing else, so it is data: two sets built in different orders are `==`, a set keys a `Map`, and a set is sent to another node. Its order is its element type's, `Int.compare` for an `OrderedSet.Set(Int)` and `Money.compare` for a set of `Money` (§2.5), so a set carries no order and a call writes none: `OrderedSet.fromList([3, 1, 3])` is `fromList` with `Int.compare`, which the compiler supplies, since the element type is known there. Where the element type is a type variable, the function that calls declares the requirement itself, as `fromList` does for `firstOfEach`, and the member it was given goes along. `List.sort` takes the member as a parameter instead, `a.compare` written, since a sort may be given any order; a function declares the requirement where the type's own member is meant. `map` needs its result's, `b.compare`, since the set it makes is in the results' order; `size`, `toList`, `filter` and the rest need none. `put`, `contains` and `remove` are linear in the set's size, as a sorted list is, and `fromList` is a sort (report Appendix E.25). The ordered map, `OrderedMap`, is written the same way over its keys (report Appendix E.26).

**A program over it.** No line of this program names an order:

```ernest
// usage.ern  (namespace Usage)
type Date = Date(year : Int, month : Int, day : Int) derives compare

type Operations(s, a) =
    Operations(fromList : (List(a)) -> s, intersection : (s, s) -> s, toList : (s) -> List(a))

let hashed : Operations(Set(Int), Int) = Operations(..Set)

let ordered : Operations(OrderedSet.Set(Int), Int) = Operations(..OrderedSet)

fn unique(list : List(a)) : List(a) needs a.compare =
    OrderedSet.toList(OrderedSet.fromList(list))

fn shown(list : List(a)) : Unit with m needs a.show =
    List.foreach(list, fn(x) = Io.println(Io.show(x)))

fn common(list : List(a), other : List(a), operations : Operations(s, a)) : List(a) =
    operations.toList(operations.intersection(operations.fromList(list),
                                              operations.fromList(other)))

export fn main() : Unit with Never = {
    let small = OrderedSet.fromList([3, 1, 3]);
    let both = OrderedSet.union(small, OrderedSet.fromList([2]));
    Io.println(Io.show(OrderedSet.toList(both)));
    Io.println(Io.show(OrderedSet.min(both)));
    Io.println(Bool.toString(both == OrderedSet.fromList([2, 3, 1])));
    Io.println(Io.show(OrderedSet.toList(OrderedSet.filter(both, fn(n) = n % 2 == 1))));
    let doubled = OrderedSet.map(both, fn(n) = n * 2);
    Io.println(Bool.toString(OrderedSet.contains(doubled, 6)));
    Io.println(Io.show(unique(["b", "a", "b"])));
    let dates =
        OrderedSet.fromList([Date(year = 2026, month = 10, day = 2),
                             Date(year = 2025, month = 1, day = 1)]);
    Io.println(Io.show(OrderedSet.min(dates)));
    shown(OrderedSet.toList(dates));
    let ages = OrderedMap.fromList([#("bo", 42), #("al", 7)]);
    Io.println(Io.show(OrderedMap.keys(ages)));
    Io.println(Io.show(OrderedMap.get(OrderedMap.put(ages, "cy", 1), "cy")));
    Io.println(Io.show(common([4, 2, 3], [3, 4, 5], ordered)));
    Io.println(Int.toString(List.size(common([4, 2, 3], [3, 4, 5], hashed))))
}
```

```console
$ ern build usage.ern
$ ern run usage.erc
[1, 2, 3]
Some(1)
true
[1, 3]
true
["a", "b"]
Some(Date(year = 2025, month = 1, day = 1))
Date(year = 2025, month = 1, day = 1)
Date(year = 2026, month = 10, day = 2)
["al", "bo"]
Some(1)
[3, 4]
2
```

`unique` is written once for any element type and declares `needs a.compare`; its call writes nothing, and the compiler supplies `String.compare`. Without the requirement the call is refused, naming what to add:

```ernest-rejected
fn unique(list : List(a)) : List(a) =
    OrderedSet.toList(OrderedSet.fromList(list))
```

```console
$ ern build generic.ern
generic.ern:2:23: fromList needs a.compare, which unique does not declare
1 | fn unique(list : List(a)) : List(a) =
2 |     OrderedSet.toList(OrderedSet.fromList(list))
  |                       ^^^^^^^^^^^^^^^^^^^
  | = help: add `needs a.compare` to unique's signature
```

`shown` declares `needs a.show`. `Io.show` writes a value by its type, which a function generic in that type does not know, so the function names `show` as it would name a member, and each call supplies the type's. `Io.show`'s own type says so, `(a!) -> String needs a.show`, and under the requirement it writes `a` and any type built from it, `List(a)` as well (report §9.4, Appendix E.1).

`Date` derives its order: `derives compare` gives the type the member `compare`, which orders two values by constructor in declaration order and then by field from left to right, each by its type's `compare`, so the dates print by year, then month, then day. A field whose type has no `compare`, an `Optional(Int)`, is refused at the declaration (report §3.5).

`Operations` is an *operations record*: the record of the operations `common` uses, which the program declares, each field's type over the record's parameters, `s` the representation and `a` the element. `Operations(..Set)` fills it from the namespace `Set`, each field not given beside the namespace being the declaration of its name there, at the field's type, and `Operations(..OrderedSet)` from `OrderedSet`, where `fromList`'s requirement is met with `Int.compare`, since the record's type fixes `a`. A field the namespace lacks, or one of another type, is refused where the record is built (report §5.6). `common` is an ordinary function over the record, `operations.fromList` a field read against the parameter's annotation, written once and called with either record; the caller chooses the representation at each call. The standard library declares no such record: a program declares the one it needs, three fields here, and reaches what a representation has beyond it, `OrderedSet.min`, through its module. `ages` is an `OrderedMap`, its keys in order, filled and read as a `Map` is.

**Two orders cannot meet.** An order belongs to a type, since a type has one `compare`. A second order on `Int` is a second type with a `compare` of its own, and the two sets are of two types:

```ernest-rejected
type Descending = Descending(Int)

fn Descending.compare(Descending(left) : Descending, Descending(right) : Descending) : Ordering =
    Int.compare(right, left)

export fn main() : Unit with Never = {
    let up = OrderedSet.fromList([1]);
    let down = OrderedSet.fromList([Descending(1)]);
    Io.println(Int.toString(OrderedSet.size(OrderedSet.union(up, down))))
}
```

```console
$ ern build mixed.ern
mixed.ern:9:66: the argument does not fit OrderedSet.union: expected OrderedSet.Set(Int), found OrderedSet.Set(Descending)
8 |     let down = OrderedSet.fromList([Descending(1)]);
9 |     Io.println(Int.toString(OrderedSet.size(OrderedSet.union(up, down))))
  |                                             ---------------- OrderedSet.union : (OrderedSet.Set(a!), OrderedSet.Set(a!)) -> OrderedSet.Set(a!) needs a.compare
  |                                                                  ^^^^
  | = help: the types differ at Int and Descending
```

**Values of several representations in one list.** An operations record keeps the representation's type, `s`, so that `common` can take two sets of it and give one back; it also keeps the two representations apart. Where values of different representations are to meet in one list or one message, a record of a second kind hides the representation: its functions close over one set, and `put` answers another such record.

```ernest
// bag.ern  (namespace Bag)
/// A set of either representation, which carries its operations and shows
/// no representation, so that a list may hold both.
type Bag(a) = Bag(contains : (a) -> Bool, put : (a) -> Bag(a), toList : () -> List(a))

fn ordered(set : OrderedSet.Set(a)) : Bag(a) needs a.compare =
    Bag(contains = fn(x) = OrderedSet.contains(set, x),
        put = fn(x) = ordered(OrderedSet.put(set, x)),
        toList = fn() = OrderedSet.toList(set))

fn hashed(set : Set(a)) : Bag(a) =
    Bag(contains = fn(x) = Set.contains(set, x),
        put = fn(x) = hashed(Set.put(set, x)),
        toList = fn() = Set.toList(set))

export fn main() : Unit with Never =
    List.foreach([ordered(OrderedSet.empty), hashed(Set.empty)], fn(bag) = {
        let filled = bag.put(2).put(1).put(2);
        Io.println(Io.show(#(List.size(filled.toList()), filled.contains(1))))
    })
```

```console
$ ern build bag.ern
$ ern run bag.erc
#(2, true)
#(2, true)
```

`ordered` declares the requirement, and the lambdas it makes close over the member it was given with the set. What a `Bag` cannot do is what the first kind keeps: nothing can take two bags apart to unite them, and a `Bag` has no `==`, since it holds functions (§2.5). Reach for an operations record where code written once must keep the representation's type, and for a record of closures where values of different representations meet.

In every form the types check what they can: a fill gives every field at its type, a call supplies the member its type has or is refused, and nothing is inferred, since a requirement is written and a member is the type's own, one of each name; a program finds its order where it finds its `+` (report §4.8). A service with state is different: two processes of different representations take one message type, and the caller holds an `Address(M)` (§4).

### 7.4 Prediction exercise

Can a helper in the same file as `Stack`, one that is not declared `Stack.` anything, match `Stack(items)`?

## 8. Cross boundaries

A program reaches outside its node's Ernest code in two ways: to peers over the network, and to foreign code on the same node.

Peers are the language's, and the toolchain does not run them yet: they come with MVP 3.0, the [plan](docs/implementation_plan.md)'s milestone for peers, which a refusal names, and [`docs/development.md`](docs/development.md)'s *What the toolchain accepts* says what a program meets until then. §8.1 and §8.2 describe what peers do, and the examples that spawn on a peer, in §8.1 and §8.4, wait for it.

A node that talks to peers has a configuration, which a node running alone does not need. `ern config` creates it, once, in `./.ernest/`: `ernest.conf`, with this node's network address, its public key and an empty list of peers, and the private key beside it. The command fails if `./.ernest` exists. A peer is added to the list by editing `ernest.conf` (report Appendix C), and its name is what `Peer.spawn(name, f)` takes.

### 8.1 Work on a peer

Work runs on a peer in a process spawned there, and its result comes back as a message. `Peer.spawn(name, f)` spawns `f` on the peer of that name as `spawn(f)` spawns it on this node; the program names the peer, and the runtime chooses no node for it (report §6.7, §8.3):

```ernest-fragment
// square.ern
type Result = Result(Int)

fn heavy(a : Int, b : Int) : Int =
    a * a + b * b

export fn main() : Unit with Result = {
    let me = self();
    let _ = Peer.spawn("foo", fn() = send(me, Result(heavy(3, 4))));
    receive {
        Result(n) -> Io.println("foo computed " <> Int.toString(n))
    }
}
```

With a peer named `foo` in `ernest.conf`, it prints `foo computed 25`. The closure takes `heavy` with it, and `me` still names this process on the peer (§8.2).

A fault in `heavy` is the spawned process's, not the caller's, so a caller that must know spawns with `Peer.spawnMonitored` and receives a `Down` (§5.2). Several computations run at once as several such processes, each sending its result back.

### 8.2 Code shipping

Code goes to a peer one way: in a process spawned there. `Peer.spawn(name, f)` takes `f`'s code with it, and the code every function it and its captures use; the peer uses the code it has, and fetches from the sender what it lacks, before the process starts. A failure to find it faults the caller of `Peer.spawn`, at the call. Every function and type is known by a hash of its definition, a type's name included, so two nodes agree on a type exactly when they declare it the same way (report §8.7).

A message to a peer carries values and no code. A function cannot go to another node, alone or inside a message, and the `send` that would take it there faults with `function cannot cross nodes` (report §3.11). Work that must run on the peer is spawned there. An adapted address of a process on your node may still go to a peer, since its function never leaves your node: what crosses is a reference to the function and the values it captured, and a value the peer sends to it comes back here to be wrapped, on delivery. So `via(self(), Wrap)` handed to a peer works. An adapted address around another node's process cannot cross, since its function would have to leave its node (report §6.5).

In spawned code a system module's reference is the peer's, so `Io.println` prints on the peer, and so is a top-level binding the code names, so a service binding names the peer's service. An address the function captured still names the process it named on this node.

A peer that is lost stays lost: its processes are dead to this node, monitors report `Fault("peer lost")`, and a message in flight may be lost without notice (report §10).

### 8.3 Foreign types and functions

```ernest
// ets.ern
export foreign type Table(k=, v)

export foreign fn toList(table : Table(k, v)) : List(#(k, v)) with m =
    "ets:tab2list/1"
```

External callers write `Ets.Table` and `Ets.toList`. `foreign type` declares a type whose values only foreign functions make and read; Ernest has no constructor for it and cannot match it. `foreign fn` binds a name to a function on the other side, here Erlang's `ets:tab2list/1`. The `=` in `k=` says the keys need equality, since `ets` compares them: a table keyed by functions is a type error at its first operation, as a `Map` is (report §4.7).

The foreign side promises the declared types. A return value of the wrong shape faults the calling process when the function returns, the whole value checked, and a function in it when that function is called; an Erlang exception becomes a fault of the calling process; and a message of the wrong type from foreign code faults its receiver on delivery. Purity is not checked: a `foreign fn` declared without `with` is trusted to have no effect (report §4.7).

In the other direction, an Ernest process's end is an Erlang exit reason, `normal`, `{ern, fault, Text}`, `{ern, killed}`, or `{ern, program_end}`, which Erlang code that monitors it reads (report §8.4).

A value foreign code made and Ernest does not inspect has the foreign type `Foreign.Term`; `Foreign.toInt` and the rest of Appendix E.12 read it, and `Erl.atom(name)` is how an Erlang atom is passed (report §3.8, Appendix E.12, Appendix E.19).

### 8.4 Node-local foreign values

A foreign value belongs to the node that made it, and sending one to another node, alone, inside a message, or among the captures of a function spawned there, faults with `Fault("foreign value cannot cross nodes")`.

An `Ets.Table` of §8.3 is such a value, a table of the node's runtime: `Ets.new()` makes one, `Ets.put` stores an entry, and `Ets.get`, the function §8.5 builds, looks one up. The closure below captures one, so shipping it to the peer `alice` faults with that cause:

```ernest-fragment
export fn main() : Unit with Never = {
    let table = Ets.new();
    Ets.put(table, "answer", 42);
    let _ =
        Peer.spawn("alice",
                   fn() =
                       Io.println(Int.toString(Optional.withDefault(Ets.get(table, "answer"), 0))));
    Unit
}
```

A program that needs such state on another node sends what the state is made of and rebuilds it there: here the entries, from which the peer fills a table of its own.

### 8.5 The shim pattern

A shim is a `foreign fn` over the host (report Appendix F). Where the host's function answers the type Ernest wants, the `foreign fn` is exported as it is, as `toList` is in §8.3. Where it does not, the `foreign fn` stays private and an exported Ernest function gives it the type Ernest wants. Erlang's `ets:lookup` returns a list, since a key matches no entry or one:

```ernest
// ets.ern
export foreign type Table(k=, v)

export fn get(table : Table(k, v), key : k) : Optional(v) with m =
    match rawLookup(table, key) {
        [#(_, value)] -> Some(value)
      | _ -> None
    }

foreign fn rawLookup(table : Table(k, v), key : k) : List(#(k, v)) with m =
    "ets:lookup/2"
```

`rawLookup` is the module's own, and callers use `Ets.get`.

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
export foreign fn lookup(key : String) : Either(String, Int) with m =
    "store_helper:lookup/1"

export fn main() : Unit with Never =
    match lookup("answer") {
        Right(n) -> Io.println("found " <> Int.toString(n))
      | Left(reason) -> Io.println(reason)
    }
```

`ern` finds an Erlang module of your own as a `.beam` in a directory of its load path, which includes the root of the module it runs (report §11.2):

```console
$ ern build --build-root build store.ern
$ erlc -o build store_helper.erl
$ ern run build/store.erc
found 42
```

A helper converts whatever its Erlang function returns to the declared type; Ernest does not. A `foreign fn` that takes a `Foreign.Term` is given one by `Foreign.from(value)`, which gives the value as an argument of its type crosses, so the type must be known where `Foreign.from` is written, as it must for `Io.show`; `Erl.atom(name)` makes an atom (report Appendix E.12, report Appendix E.19).

`libs/ets` is such a library, report Appendix G.1, which Appendix D shows with a shorter documentation, and a program adds it with `--load-path`. A data format, a protocol and a pattern language each belong to a library outside the standard library (report Appendix E.0 rule 2), and report Appendix G lists the libraries there are.

### 8.6 Bitstrings

Building and parsing binary formats:

```ernest
fn frame(bodySize : Int, body : Bytes) : Bytes =
    <<bodySize:size(16)-big, body:bytes>>

fn parseFrame(bytes : Bytes) : Optional(#(Int, Bytes, Bytes)) =
    match bytes {
        <<bodySize:size(16)-big, body:size(bodySize)-bytes, rest:bytes>> ->
            Some(#(bodySize, body, rest))
      | _ -> None
    }
```

Specifiers, joined with `-`:

- **`size(N)`** — width in bits, or in octets for `bytes`.
- **`bytes`** — segment is a nested byte-aligned `Bytes` value.
- **`int`**, **`float`** — numeric (defaults: 8-bit `int`, 64-bit `float`).
- **`utf8`**, **`utf16`**, **`utf32`** — text encoding.
- **`big`**, **`little`** — endianness. A format states its byte order; data in the host's own order comes through foreign code, which converts it.
- **`signed`**, **`unsigned`** — sign.

A segment without specifiers is `int` of size 8, which is why `<<0, 1, 2>>` is three bytes. `int` binds to `Int`, `float` to `Float`, the `utf` forms to `Char`, `bytes` to `Bytes`.

A bitstring's total width is a whole number of bytes, and a value that does not fit its segment's width faults; report §5.11 has the rest of the rules.

A `Bytes` value is read with the `Bytes` module: `Bytes.size`, `Bytes.get` for one octet, `Bytes.slice`, and `Bytes.toList` for all of them. Text crosses with `String.toUtf8` and `String.fromUtf8`.

A stream of bytes, as `Tcp.read` answers it, may end inside a line, and inside a character, so lines are split off the bytes before they become text: `Bytes.split(bytes, <<10>>)` gives the lines, the last part being what has come of the next, as the program of §8.7 does. A frame is taken apart with a pattern, as `parseFrame` does, and not octet by octet with `Bytes.get`.

In a pattern, `size(bodySize)` may name a variable bound by an earlier segment. A `match` over bitstrings ends with a clause that takes anything, as `parseFrame` does, since the checker does not decide whether bitstring patterns cover every `Bytes` value.

### 8.7 Sockets

A server is a listener and a process for each connection. `Tcp.listen(host, port)` answers a listener, and `Tcp.accept(listener, ms)` the next connection, a socket, or `Left(Timeout)` when none came within `ms` milliseconds. No time means no limit, so the loop that accepts takes again after a timeout, and that turn is where it looks at anything else it must.

A socket is read by pulling. `Tcp.read(socket, ms)` answers what has arrived, at least one byte, `Left(Timeout)` when nothing did, and `Left(Closed)` once the connection has closed; nothing the socket receives comes to a mailbox. A process waits on one thing at a time, so one that must wait on its socket and on its mailbox gives the socket to a reader of its own, as §5.5 teaches. One process may read a socket while another writes to it, and a read that waits answers `Left(Closed)` when the socket is closed. A write returns once the socket has taken its bytes, and waits while the far end is behind taking them; it answers `Left(Closed)` once the far end has gone.

Bytes arrive in pieces that need not end where a line ends, so what follows the last line feed waits for the next piece. A server that sends each line back, and says it is still there every ten seconds:

```ernest
type Session = Arrived(Bytes) | Gone | Tick(Int)

export fn main() : Unit with Never =
    match Tcp.listen("127.0.0.1", 7000) {
        Right(listener) -> serve(listener)
      | Left(error) -> Io.printlnError("cannot listen: " <> Io.show(error))
    }

fn serve(listener : Address(Tcp.ListenerMsg)) : Unit with Never =
    match Tcp.accept(listener, 60000) {
        Right(socket) -> {
            let talker = spawn(fn() = session(socket));
            Tcp.give(socket, Process.fromAddress(talker));
            serve(listener)
        }
      | Left(Io.Timeout) -> serve(listener)
      | Left(_) -> Unit
    }

// The session waits on its mailbox, and its reader on the socket.
fn session(socket : Address(Tcp.SocketMsg)) : Unit with Session = {
    let me = self();
    let _ = spawn(fn() = reader(socket, me));
    Clock.alarm(10000, Tick);
    talk(socket, <<>>)
}

fn reader(socket : Address(Tcp.SocketMsg), session : Address(Session)) : Unit with Never =
    match Tcp.read(socket, 60000) {
        Right(bytes) -> {
            send(session, Arrived(bytes));
            reader(socket, session)
        }
      | Left(Io.Timeout) -> reader(socket, session)
      | Left(_) -> send(session, Gone)
    }

fn talk(socket : Address(Tcp.SocketMsg), rest : Bytes) : Unit with Session =
    receive {
        Arrived(bytes) -> {
            let parts = Bytes.split(rest <> bytes, <<10>>);
            List.foreach(List.dropLast(parts, 1), fn(line) = {
                let _ = Tcp.write(socket, line <> <<10>>, 5000);
                Unit
            });
            talk(socket, Optional.withDefault(List.last(parts), <<>>))
        }
      | Tick(_) -> {
            let _ = Tcp.write(socket, String.toUtf8("still here\n"), 5000);
            Clock.alarm(10000, Tick);
            talk(socket, rest)
        }
      | Gone -> Tcp.close(socket)
    }
```

A socket lives until `Tcp.close`, so the session closes it when its reader finds the connection gone. It is owned by the process that accepted it and is killed when its owner dies, so the loop that accepts gives each socket to its session, `Tcp.give`, and a session that faults takes its connection with it. Its process, and the listener's, are the program's: `Process.live` lists them, and a fault in one is reported under the function that opened it, `Tcp.accept` (report Appendix E.18).

### 8.8 Prediction exercise

A process sends a service on another node `Register(fn(x) = x + 1)`, a message with a function in it. What happens, and how does the function get to run on that node?

## 9. Tools

One command, `ern`, whose first word is its job, and a mode for Emacs. `ern --help` lists the jobs and `ern build --help` a job's options; report §11 defines each.

### 9.1 `ern build`, `ern doc` and `ern format`

- `ern build hello.ern` compiles one module to `hello.erc`, beside it.
- `ern build --build-root build src` compiles every module under `src` in dependency order, mirroring the tree into `build`. A module is compiled again only when its source, an interface it depends on, any interface of the standard library, or the compiler has changed, and a `.erc` whose source is gone is removed.
- `--source-root dir` names the directory a module's namespace is read from, as §7.1 describes. `--load-path dir` adds compiled modules from outside the tree, such as a library, and may be given more than once.
- `--short-errors` prints the first line of each error only, `file:line:column: message`, for a tool to read.
- `--emit-erl` writes the Erlang the module compiles to, for reading.
- `ern doc file.ern` writes the module's documentation to standard output as CommonMark. `ern doc src` writes a page for each module under `src` and an `index.md`, and for the standard library's root a `prelude.md` as well. `ern doc --man` renders a manual page instead, to standard output for one module and, for a directory, as a file beside each module, `Ernest.List.3ern`, which `man -l` shows, or `man Ernest.List` once it is installed where `man` looks.
- `ern format file.ern` lays the module out in the one layout report §11.6 states, and `ern format src` every module under `src`; only line breaks and spaces change, and every comment stays where it was. `ern format --check src` names each module not laid out and changes none; `ern format - < file.ern` writes the module as `ern format` would lay it out, to standard output, and changes nothing.

### 9.2 `ern run`, `ern test`, `ern shell` and `ern config`

- `ern run hello.erc` runs `main` and exits with status 0 when it returns. Every fault is printed on standard error as it happens, the spawn site and the cause, and a fault of the entry process makes the status 1 (§6.3); an entry process that is killed prints `killed`, and the status is 1. A signal that stops the program prints nothing and ends `ern run` by that signal, which a shell reports as 128 plus its number, 143 for a termination.
- `--main Module.name` runs another exported function of no arguments instead of `main`.
- `--load-path dir` adds compiled modules and Erlang `.beam` files the program needs (§8.5).
- `ern test module.erc` runs the module's tests, and `ern test dir` those of every module compiled under the directory; it exits with status 1 unless all passed (§7.1).
- `ern shell`, with or without a file, starts the shell (§1.2). A file's `main`, or the function `--main` names, runs beside it; a file without either is loaded with nothing running. `--source-root dir` names where `:load` finds a module's source, and `--config-dir dir` the configuration directory.
- `ern config` makes the configuration a node with peers needs (§8), in `./.ernest` or the directory `--config-dir` names.

### 9.3 The shell

§1.2 teaches inputs, editing and completion. A command begins with `:`, and `:help` lists the commands, among them these: `:type` gives an expression's type and `:doc` a name's documentation, `:browse` lists a module's exports, `:load` and `:reload` compile a module from its source, `:bindings` and `:forget` manage what the session has declared, `:processes` and `:faults` show what runs and what has faulted, `:set` sets the depth and length values are printed to, the rows of the live region, and timing, and `:output` sends what programs write to a terminal or a file. A command may be shortened to a prefix of its name that begins no other, `:br` for `:browse`; `:b` begins `:bindings` too, and the shell says so.

At a terminal the history is kept in `$HOME/.ernest/history`. When the shell starts it runs the inputs in `$HOME/.ernest/startup`, and then, if `--config-dir` names a configuration directory, those in its `startup`. A directory the shell merely starts in runs nothing of its own. A startup line may be a command, and one that fails is reported with its file and line.

### 9.4 Emacs

`emacs/ernest-mode.el` highlights Ernest, indents it as `ern format` lays it out (report §11.6), and lets `M-x compile` with `ern build` jump to each error. [`emacs/README.md`](emacs/README.md) says how to load it, and [`docs/emacs_mode.md`](docs/emacs_mode.md) what it leaves to your own configuration.

### 9.5 Running a program as a service

A program meant to keep running is run in the foreground and left to a service manager, which starts it, restarts it, and keeps what it writes; `ern` has no mode of its own for it. A service here is the operating system's, not §6.5's. Standard output is the program's, and standard error is where `ern run` reports every fault, so the two streams are its log. A unit for systemd, running the web server of [`examples/web_server.ern`](examples/web_server.ern) built into `/srv/web/build`:

```ini
[Unit]
Description=The web server

[Service]
ExecStart=/usr/local/bin/ern run /srv/web/build/web_server.erc
WorkingDirectory=/srv/web
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

systemd keeps both streams in its journal, which stamps every line, and `journalctl -u web` reads them. Where standard error is neither a terminal nor the journal, a file or a pipe, each fault line begins with its time, in UTC: `2026-09-27T14:22:11.836Z WebServer.acceptor:81 faulted: division by zero`. Without a service manager, `nohup` keeps a program running once its terminal has closed:

```console
$ nohup ern run build/web_server.erc >> web.log 2>&1 &
```

`kill` stops the program as §9.2 says: its output is flushed, and `ern run` ends by the signal, which systemd counts as a stop it asked for. A program that ends on its own gives the manager its reason with `Os.exit(status)` (§1.3), and `Restart=on-failure` starts again one that ends with any status but 0. A program whose output can no longer be written, because what reads it has ended, ends too, with status 141, as `ern run app.erc | head -1` shows. `ern` never changes what a program writes, on either stream.

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
- There are no registered names, and addresses cannot be compared; the processes behind them can, `Process.fromAddress(a)`, which is a pid without the right to send. A process is reached through an address it was given, or through a service binding, a top-level binding that holds one (§6.5).
- There are no atoms in the language: constructors are the tags. `Erl.atom` makes one for a foreign call.
- There are no OTP behaviours. A server is a `receive` loop with `Reply`, restarted in place by `restarting` and reached through a service binding (§6.5). A supervision tree is the standard library's `Supervisor`, its children restarted in place so that their bindings keep their addresses (§6.6).
- A running program replaces its code by a message that carries the new function (§4.6). Only the shell's `:reload` loads a new version of a module.
- A function does not travel in a message between nodes: a `send` that would take one to another node faults. Code goes to a peer only with a process spawned there (§8.2).
- ETS is a library outside the standard library, `libs/ets`, since a table is state that processes share.
- Nodes talk over Ernest's own protocol, [`docs/node_protocol.md`](docs/node_protocol.md), not over Erlang distribution, and ship code by content (§8.2).

## 11. The design

Report §0 gives five principles, and the rules of the guide follow from them.

1. **Least surprise decides.** A rule stays when the code it produces is what a reader who knows the rest of Ernest would write, and changes when it is not. That reader knows Ernest first, then types as Standard ML and OCaml have them and values and processes as Erlang has them, and no other language. The other four principles build the language, and this one audits the code they produce.
2. **One way, one job.** The language and the prelude have one way to do each thing: a record is a constructor with named fields, a server is a `receive` loop, a request is a `Reply`. A second spelling enters only where the first would nest, repeat a body, rebuild what a pattern holds, or pair each of a record's fields with the same name in one namespace, which is why `|>`, `<-`, `or`, `as` and the fill `C(..N)` exist and a shorthand that only shortens does not.
3. **Nothing invisible.** Control flow, communication, and failure show in the code or in the type. A top-level binding is visible where its name appears at the use site, which is what makes a service (§6.5) one, or, in a fill, where its namespace appears and the record's type names its field. What the type decides is checked when the program is compiled and what the value decides faults when it runs; the compiler refuses what can have no effect and says nothing about what is merely unused, since there is no warning.
4. **Simple to parse.** Each construct is known by its first token, or by a later one a bounded way ahead, so a reader, like the parser, never has to look far.
5. **Small.** Few concepts, few primitives, few reserved words, counted in the language and not in the library; how many programs want a feature decides nothing; and a feature costs a program that does not use it nothing.

§0 also says how Ernest stands to the runtime beneath it: a rule of the host is Ernest's only where the report states it as Ernest's own, and where the report is silent the runtime carries the host's rule without letting it show.

Principle 3 turns an omission into a statement. Exhaustiveness makes you say what every constructor does; `let _ = e` says a value is dropped on purpose; the reply discipline says where each `Reply` is consumed; `export` says what crosses a module's boundary; `with` says a function acts through a process; a qualified name says which module a name comes from. Several of these tell the compiler nothing it could not work out for itself. What they add is that the decision is written down, where a reader meets it. It is programming on purpose, to borrow P. J. Plauger's phrase for designing deliberately rather than by accident; his subject is software design as a whole, broader than these rules (*Programming on Purpose: Essays on Software Design*, Prentice Hall, 1993).

## 12. Frequently asked questions

**Is there a type class, an interface or a trait?**

No. A function that needs an operation of a type it is generic in names the type's member, `needs a.compare`, and a call writes nothing, since a type has one `compare` and the compiler supplies it; code written once over several representations takes a record the program declares and fills from a representation's module, `Operations(..Set)` (§7.3). Nothing is inferred and nothing is declared an instance.

**Why `fn(x) = ...` for a lambda, and not `x -> ...`?**

It begins with `fn`, so a reader and the parser see a lambda begin at its first word. A function's number of arguments is part of its type, and `fn(x, y)` shows it where the lambda is written, in the form a declaration and a call already have.

## 13. Answers to the exercises

**§1.4.** (a) compiles: inference gives `main` a mailbox effect from the call of `Io.println`. (b) does not compile: `: Unit` with no `with` declares `main` pure, and a pure function cannot call `Io.println`, which sends. It is the mistake of `area` in §0. The `with Never` of hello-world says that `main` runs in a process whose mailbox will never receive. Omitting an annotation is not the same as declaring purity.

**§2.11.** (a) and (d) compile. Every constructor of `Shape` has `name`, with one type, so `s.name` reads it whichever built `s`. (b) is refused: a `Dot` has no `radius`, and the compiler does not take the programmer's word that `s` is a `Circle`. (c) is refused for the same reason: `..s` would copy `name` from a `Circle`, and `s` may be a `Dot`, so `..` is allowed only on a type with one constructor. (d) asks which constructor built `s` and reads `radius` only in the clause where it is there; a pattern may leave out the fields it does not need.

**§3.7.** `map2`'s inferred type is `((a) -> b with e, a, a) -> #(b, b) with e`. The call binds `a = Int`, `b = Unit`, and `e` to the mailbox effect of `send`, the same as the enclosing function's.

**§4.8.** No. The timeout only bounds the caller's wait. The recipient may still be processing the request or may answer later; the late answer is silently discarded but the work done on the recipient side is not undone.

**§5.7.** Yes. `Io.println` returns once standard output has taken the line (report §8.2). Ping prints before it calls pong and waits for the answer, and pong prints before it answers, so each line is written before the next can be. Per-sender order alone would not give it, since the two are two senders to standard output: the call orders them.

**§6.7.** `main` faults with the cause `first of an empty list`, and since it is the entry process the program ends and `ern run` prints the fault, `Main.main faulted: first of an empty list` for a `main` in `main.ern`. To give the case to the caller, return `Optional(Int)`, as `List.get` does: `[] -> None`.

**§7.4.** Yes. The boundary of an abstract type is its module, so every definition in `stack.ern` may name the constructor, a helper or a test included; another module sees the type and its operations, never the constructor.

**§8.8.** The `send` faults the sending process, at the call, with `function cannot cross nodes`: a function does not leave its node inside a message. To give the service the function, spawn a process on its node, which takes the function's code with it, and let that process send the message there: `Peer.spawn(name, fn() = send(service, Register(fn(x) = x + 1)))`.

## 14. Reading further

Four larger programs, each written against the report to try the language on a whole program, in ascending complexity:

- [`examples/snake.ern`](examples/snake.ern) — snake game with tick-based updates; `..` record updates, one process per player, `Clock`, `Terminal`, `Random`.
- [`examples/repl.ern`](examples/repl.ern) — small read-eval-print loop; `<-` for chained parsing, `spawnMonitored` + `kill` for aborting slow evaluation, `Io.readLine`.
- [`examples/file_sync.ern`](examples/file_sync.ern) — file sync between two directories, whose two sides run on one node and would run the same on two; mutual-address setup, one process per file operation, `Fs`.
- [`examples/web_server.ern`](examples/web_server.ern) — HTTP server with sessions in a process that owns a `Map`; request-reply, `Tcp`.

For the language rules themselves, the report is the authority: [`report/language.md`](report/language.md), the language, [`report/toolchain.md`](report/toolchain.md), the toolchain, and [`report/library.md`](report/library.md), the standard library. Appendix F glosses every technical term.

Why Ernest looks as it does, and what was tried and rejected, is in [`decisions.md`](docs/decisions.md), a dated record of the design decisions.
