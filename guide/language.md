<picture>
  <source media="(prefers-color-scheme: dark)"
          srcset="../assets/ernest-combined-dark.svg">
  <source media="(prefers-color-scheme: light)"
          srcset="../assets/ernest-combined-light.svg">
  <img src="../assets/ernest-combined-light.svg" alt="Ernest" width="520">
</picture>

# Programming in Ernest

This guide teaches Ernest to a programmer who has used a functional language. It assumes immutable values, sum types, pattern matching, functions as values and recursion, and shows only how Ernest writes them. Processes and messages it teaches from the start, since their types are what is new; a reader who knows Erlang will recognize the model, and §10 says what carries over. Nothing of Ernest or of its report needs reading first.

Each complete program in the guide compiles as shown and prints what is shown after it, and the guide's tests run every one. Where a process fails, `ern run` reports it on standard error, and where that line falls among the program's own lines may differ from run to run. A program the compiler refuses is shown with what the compiler says of it. The language is defined by the report, in three files under [`report/`](../report/language.md), to which the guide points where a question turns on a detail.

**Contents**
<!-- contents -->
- [0. What the compiler refuses](#0-what-the-compiler-refuses)
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
- [12. Answers to the exercises](#12-answers-to-the-exercises)
- [13. Reading further](#13-reading-further)
<!-- /contents -->

Beside the guide: [Why Ernest](why.md), the argument for the design, and [Frequently asked questions](faq.md).

## 0. What the compiler refuses

Ernest is a functional language for concurrent programs, built on two ideas. A function computes a value from its arguments, and the compiler infers its type. A process runs a function and receives messages in its mailbox, and processes are how a program acts on the world. A function that receives says so in its type, and runs only in a process whose mailbox takes what it receives. A process receives messages of one type, which the compiler checks every send against, and a process started on another node brings its code along: nothing is installed there first. Every other rule says how the two appear in each other's code.

The rules let the compiler find, before the program runs, the mistakes programs are prone to. Two follow, each as a program and what `ern build`, the compiler, says about it.

**A message the process does not take.** The counter receives `CounterMsg`, so the address `spawn` returns, where a `send` goes, takes a `CounterMsg` and nothing else.

```ernest-rejected
type CounterMsg = Inc(Int) | Get(Reply(Int))

fn count(total : Int) : Unit receiving CounterMsg =
    receive {
        Inc(amount) ->
            count(total + amount)
      | Get(reply) -> {
            answer(reply, total);
            count(total)
        }
    }

export fn main() : Unit = {
    let counter = spawn(fn() = count(0));
    send(counter, "increment")
}
```

```console
$ ern build message.ern
message.ern:15:19: the argument does not fit send: expected CounterMsg, found String
14 |     let counter = spawn(fn() = count(0));
15 |     send(counter, "increment")
   |     ---- send : (Address(a), a) -> Unit
   |                   ^^^^^^^^^^^
```

An error in a module's source has this form: the position as `file:line:column`, the message, and the source with the error's span underlined with `^`. A span the error depends on is underlined with `-` and labeled, here the type of `send`, whose two arguments must agree. The names in these examples, `spawn`, `send`, `receive`, an address, `Reply`, `answer`, and `receiving`, are taught in §1 to §4; here only the errors matter.

**A failure dropped.** `Fs.write` returns `Either(Io.Error, Unit)`, a value that is `Right(Unit)` or `Left(error)` (§2.7): the file was written, or the reason it was not. Its last argument, `1000`, is how many milliseconds it may take, after which it answers `Left(Io.Timeout)`. A statement in a block must be `Unit`, so the failure cannot pass unseen. `let _ = ...` discards it where that is meant.

```ernest-rejected
export fn main() : Unit = {
    Fs.write(Path("notes.txt"), String.toUtf8("buy milk"), 1000);
    Io.println("saved")
}
```

```console
$ ern build notes.ern
notes.ern:2:5: this statement's value is discarded: expected Unit, found Either(Io.Error, Unit)
1 | export fn main() : Unit = {
2 |     Fs.write(Path("notes.txt"), String.toUtf8("buy milk"), 1000);
  |     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  | = help: `let _ = ...` discards it on purpose
```

These rules come from one design. [Why Ernest](why.md), beside this guide, argues what Ernest adds to the parts it takes from Erlang, ML and Unison; the first refusal above is its first claim at work, and the second is the principle that nothing is invisible, a failure among it (§11).

Sections 1 to 8 are eight stages: run a program, compute with values, pass behavior, run a protocol, manage process lifetime, handle failure, organize code, and cross boundaries. Each builds on the ones before it and ends with an exercise, whose answer is in §12. A complete program is shown whole; a fragment is part of the program around it. After the stages come the tools (§9), a word for the Erlang programmer (§10), the design behind the rules (§11), the answers (§12), and further reading (§13).

## 1. Run a program

A program is a module that exports a function `main`. Put this line in `hello.ern`, a file named by lowercase words joined by `_` (§7.1):

```ernest
export fn main() : Unit =
    Io.println("hello, world")
```

Compile and run, with `ern` installed as the [README](../README.md) says:

```console
$ ern build hello.ern         # produces hello.erc
$ ern run hello.erc          # runs main()
hello, world
```

`ern` is the whole toolchain, and its first word is the job. `ern build` compiles a `.ern` file to a compiled module, `.erc`. `ern run` loads it and the modules it uses, the standard library among them, starts the runtime's processes, and calls `main`. §9 lists each job's options.

### 1.1 What the line says

`fn` begins a function definition, and `export` makes it visible outside the module. `ern` runs the function `main` of the module it loads; `--main` names another (§7.1).

`: Unit` is the result type, written after the parameters as a parameter's type is written after its name. `Unit` is a type with one value, also written `Unit`, the result of a function whose work is its effect.

`main` runs in the process the program starts it in, the *entry process*. A function that receives messages says so after its result type, `receiving` and the type it receives (§3.4, §4.1); one that only sends, as `main` does here through `Io.println`, says nothing. Types may also be left out, and the compiler infers them (§3.3).

`Io.println` sends its text to standard output's process, which the runtime provides and `Io` alone reaches. `Io.printlnError` sends to standard error's, so a program whose output another program reads can still report trouble. Sending to a process of the runtime is one of the two ways a program reaches the world; the other is `foreign fn` (§8).

`Io.debug(x)` prints a value as its literal or construction is written, where it has one, to standard error, and returns it, so it wraps an expression where it stands: `let n = Io.debug(f(x))`. `Io.show(x)` is the text it prints (report Appendix E.1). The type of each says `needs a.show`, a requirement, which a call at a known type meets with nothing written and §7.3 teaches.

### 1.2 The shell

`ern shell` starts a shell. An input is an expression, a declaration, or a `let`. It is checked and run when it is entered, after any input still running, and an expression's value is printed with its type and kept as `it`. The inputs below use lists and functions, which §2 and §3 teach; here only the shell matters.

```console
$ ern shell
Ernest 0.6.0. :help for the commands, :quit to leave.
> 1 + 2
3 : Int
> let xs = [3, 1, 2]
xs : List(Int)
> List.sort(xs)
[1, 2, 3] : List(Int)
> fn square(n : Int) : Int = n * n
square : (Int) -> Int
> List.map(xs, square)
[9, 1, 4] : List(Int)
> Io.println("hello")
hello
```

A value of type `Unit` prints nothing, so the last input shows only what it wrote. An error at the prompt is placed as `input n:line:column`, `n` counting what is entered, commands among them (report §11.2). A command begins with `:`. `:type e` prints the type of `e` without running it, `:doc List.sort` prints the documentation of `List.sort`, and `:help` lists the rest. `ern shell hello.erc` starts the shell with `hello`'s module in scope and its `main` running beside it. A module without `main` is put in scope with nothing running, to be tried at the prompt.

At a terminal the shell edits the line with Readline's Emacs keys, stands the cursor for a moment on the bracket a typed `)`, `]` or `}` closes, and keeps a history across sessions that `C-r` searches. An input the parser cannot finish takes another line, and `M-Enter` adds one whatever the parser says. `C-c` ends the input that runs, which answers `Killed`, and abandons a line being typed.

What programs write appears in a region at the foot of the screen, apart from the inputs, and a process that faults, that meets an error it did not expect (§6.3), is reported at the prompt with the place it was spawned. An input that faults itself is reported as `fault:` and its cause, the fault's trace beneath.

A fault, an error, and a refused command are shown in red and a result's type dimmed, and documentation is styled, unless the environment sets `NO_COLOR`. A line wider than the screen wraps as it is typed.

`Tab` completes the word before the cursor, and `Shift-Tab` shows what the name at the cursor is: its declaration and the first sentence of its documentation. §9.3 has the rest of the shell: completion in full, the other commands, and loading a module from its source.

### 1.3 Reading input

A program's first input is its command line. `main`, the *entry point*, the function the program starts with, takes no arguments: the words after the `.erc` file on `ern run`'s line are `Os.arguments`, a list of strings. The shell's command line is its own, and in the shell `Os.arguments` is the empty list.

```ernest
export fn main() : Unit =
    match Os.arguments {
        [] -> {
            Io.printlnError("usage: greet name...");
            Os.exit(2)
        }
      | names ->
            List.forEach(names, fn(name) = Io.println("hello, " <> name))
    }
```

```console
$ ern run greet.erc Ada Grace
hello, Ada
hello, Grace
```

`match` takes the first clause whose pattern fits the value: `[]` fits the empty list, and `names` fits any other and names it (§2.3). A block, `{ ...; ... }`, runs its statements in order (§2.2), and `fn(name) = ...` is a function written in place (§3.2).

`Os.exit(status)` ends the program with that exit status. A program whose `main` returns exits with 0, and one whose entry process faults exits with 1. A variable of the environment is asked for by its name: `Os.environment("HOME")` answers `Some(dir)` where the home directory is set, and `None` where it is not, the two values of `Optional` (§2.3). The directory the program was started in is `Os.workingDirectory`, and a relative path names a file under it.

The *host* is the Erlang runtime Ernest runs on and the operating system under it. A program the host has is run with `Os.run`, which gives it its input and answers its exit status and what it wrote once it has ended, or an `Io.Error` where it could not start. Its name is found as the host finds a command, and each argument reaches it as it is, with no shell between:

```ernest
export fn main() : Unit =
    match Os.run(Os.Command(program = "echo", arguments = ["hi"], input = <<>>), 5000) {
        Right(finished) -> Io.print(Optional.withDefault(String.fromUtf8(finished.stdout), ""))
      | Left(error) -> Io.printlnError(Io.show(error))
    }
```

`Os.Command(program = ..., ...)` builds a value by naming its fields (§2.4), and `Right(finished)` and `Left(error)` are the two cases of `Either` (§2.7); `<<>>` is the empty bytes (§2.1), `finished.stdout` a field of the record `Os.run` answers (§2.4), and `String.fromUtf8` answers an `Optional`, `None` for bytes that are not UTF-8, which `Optional.withDefault` turns into `""` (§2.3).

```console
$ ern run echo.erc
hi
```

`Os.start` starts one to talk with while it runs: `Os.write` feeds it, `Os.read` answers what it wrote, piece by piece, and the running program is a process, which `kill` ends and `monitor` watches (§5.2, §5.3; report Appendix E.23).

`Io.readLine()` waits for a line of standard input and answers `Some(line)`, or `None` at its end. A program that reads its input to the end loops:

```ernest
export fn main() : Unit =
    match Io.readLine() {
        Some(line) -> {
            Io.println(String.toUpper(line));
            main()
        }
      | None ->
            Unit
    }
```

```console
$ printf 'hello\nworld\n' | ern run upper.erc
HELLO
WORLD
```

Standard input is read as UTF-8, and a line that is not faults the process that read it. Input that is not text is read as bytes: `Io.read()` answers `Some(bytes)` with what has arrived, and `Io.write(bytes)` writes bytes to standard output as they are. Lines and bytes come from one stream, so a program can read a line and then the bytes after it. A program reads lines or single keys, not both: `Terminal.subscribe` gives keys as they are pressed, or answers `Left(Io.NotATerminal)` where standard input is not a terminal, so that the program can read lines instead (report §12.1).

### 1.4 A taste of the rest

The tour's counter, `counter.ern`, whose type and loop are exported, run on a node started with none of its code. `foo` is a node started with a configuration directory and no program, and the shell is a node too, started with its own; `Peer.spawn` starts `count` on `foo`, which is sent the code it lacks, and answers `Right` with an address like any other, or `Left` with the reason it could not; `let far <-` binds the address inside a `Right`, and shows a `Left` and binds nothing (§2.7). Started as a node, the shell says where it listens before its first line:

```console
$ ern shell --config-dir a
listening on 0.0.0.0:8654
Ernest 0.6.0. :help for the commands, :quit to leave.
> :load Counter
Counter, compiled from counter.ern
> let far <- Peer.spawn("foo", fn() = Counter.count(0), 5000)
the peer foo connected
far : Address(Counter.CounterMsg)
> send(far, Counter.Inc(5))
> Address.call(far, Counter.Get, 1000)
Some(5) : Optional(Int)
```

How the nodes are made and listed is §8.1, and the whole picture in an evening is [the tour](../tour/README.md), whose chapter 2 these lines are.

### 1.5 Prediction exercise

Consider hello-world written with `Io.debug`, which prints its argument and returns it (§1.1), (a) with no annotation:

```ernest
export fn main() =
    Io.debug("hello, world")
```

and (b) with `: Unit`, as §1 writes `main`:

```ernest-rejected
export fn main() : Unit =
    Io.debug("hello, world")
```

Which of these compile, what type does each give `main`, and which can `ern run` run?

## 2. Compute with immutable values

Everything in Ernest is immutable. Bindings introduce names; there is no assignment.

### 2.1 Scalars, Unit, and literals

- **`Int`** — arbitrary precision. Literals: `42`, and in another base `0xFF`, `0o644`, `0b1010`. An `_` between digits groups them: `1_000_000`.
- **`Float`** — IEEE 754 binary64, finite values only. Literal: `3.14`.
- **`Char`** — one Unicode scalar value, a code point other than a surrogate. Literal: `'a'`.
- **`String`** — Unicode text. Literal: `"hello"`, with the escapes `\n`, `\t`, `\\`, `\"`, and `\u{1F600}` among them (report §2.5). `<>` joins two strings, and a type's `toString` makes its text: `"n = " <> Int.toString(3)`. There is no interpolation.
- **`Bytes`** — a sequence of octets, written between `<<` and `>>`, one octet per number: `<<0, 1, 2>>` (§8.6).
- **`Bool`** — `true` or `false`. `&&` and `||` short-circuit, and `!` negates.
- **`Unit`** — one value, also called `Unit`.

A raw string, between backticks, is taken exactly as written, with no escapes, except that a line break in it is a line feed. It is the form for text full of backslashes or quotes, and for text over several lines, since a line break in it is part of the text. The shell prints a string as a `"..."` literal, so it shows what the raw string saved writing:

```console
$ ern shell
Ernest 0.6.0. :help for the commands, :quit to leave.
> let number = `\d+(\.\d+)?`
number : String
> number
"\\d+(\\.\\d+)?" : String
```

`Int` division `/` and remainder `%` by zero fault, and so does `Float` arithmetic whose result would not be finite. `Int.div` and `Int.rem` return `Optional(Int)` instead. A fault ends the process, or restarts it where it was started to restart (§6).

`Int` and `Float` are separate types, and nothing converts between them implicitly: `1 + 2.0` is a type error. Convert with `Int.toFloat`, or with `Float.round`, `Float.floor`, `Float.ceil`, or `Float.truncate`.

### 2.2 Bindings and blocks

A name begins with a lowercase letter or `_`, and eighteen words are reserved and name nothing: `type`, `abstract`, `receiving`, `foreign`, `match`, `when`, `receive`, `after`, `as`, `or`, `if`, `then`, `else`, `fn`, `let`, `export`, `true` and `false` (report §2.4). At the prompt, as in a block, `let` binds a name:

```console
$ ern shell
Ernest 0.6.0. :help for the commands, :quit to leave.
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

**Top-level bindings.** A `let` at the top level, outside any `fn`, is a *top-level binding*, whose value is set once, before `main` starts. Its name is lowercase like any value's; an uppercase name is a type or a constructor. `export` makes it visible to other modules.

```ernest
let pi : Float = 3.14159265358979

let defaultPort : Int = 8080

export let helloBanner : String = "hello, world"
```

Top-level bindings are evaluated before `main`, in the order their references need, and otherwise in the order the module declares them. A cycle among them is an error (report §4.6, §8.5).

A top-level binding whose initializer is a *constant*, a literal, a negated number literal, a constructor of no fields, or a constructor, a tuple or a list of constants, as each of the three above is, is not evaluated: it has its value from the program's start, and wherever its code is, on another node too (§8.1, report §4.6).

An initializer may do more than compute. It runs in the entry process, as a body whose mailbox type is `Never` (§4.1): it may spawn, send, call and wait a while, and takes no message. A top-level `let` that holds a process's address is a *service binding*. §6.5 teaches both, once §4 has taught processes.

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
- **Positional** (`Some(a)`): one value, and the constructor is also a function, `(a) -> Optional(a)`, so it can be passed: `List.map(xs, Some)`. A constructor takes one positional value or named fields; several values without names are a tuple, `Point(#(Int, Int))`, `#(Int, Int)` a tuple type (§2.5).
- **Named fields** (`Person(name : String, age : Int)`): construction uses the field syntax (`Person(name = "Alice", age = 30)`). Not a function value.

There are no type aliases, and `type Word = String` is refused: it would declare a nullary constructor named `String`, and the compiler refuses a constructor named as a type in scope other than its own (report §3.1). A type that holds a string is a wrapper, `type Word = Word(String)`.

The prelude's types are in scope in every module (§2.9), so a constructor may not take one's name: `type Command = Set(key : String, value : String) | Clear` is refused for its `Set`, and the constructor is named otherwise, `Assign`.

### 2.4 Named fields, selection, and `..` update

For constructors that carry several things, name each field:

```console
$ ern shell
Ernest 0.6.0. :help for the commands, :quit to leave.
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
Ernest 0.6.0. :help for the commands, :quit to leave.
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
Ernest 0.6.0. :help for the commands, :quit to leave.
> let xs = 1 :: [2, 3]
xs : List(Int)
> match xs { [] -> "empty" | head :: _ -> "first is " <> Int.toString(head) }
"first is 1" : String
> let point = #(3, 4)
point : #(Int, Int)
> let #(x, y) = point
x : Int
y : Int
```

A map and a set are built from the empty one, or from a list:

```console
> let scores = Map.empty |> Map.put("a", 1) |> Map.put("b", 2)
scores : Map(String, Int)
> Map.get(scores, "a")
Some(1) : Optional(Int)
> Map.update(scores, "a", fn(score) = Optional.withDefault(score, 0) + 1)
Map.fromList([#("a", 2), #("b", 2)]) : Map(String, Int)
> Set.fromList([1, 2, 3])
Set.fromList([1, 2, 3]) : Set(Int)
```

`Map.update` sees the entry as an `Optional`, present or not, and stores what the function returns: the counting idiom in one call. A present entry is changed the same way and an absent one left absent: `Map.update(map, key, fn(found) = Optional.map(found, f))`.

Map keys and set elements need equality. `==` is defined on every type except one that contains a function, an address or a reply, the `Reply` an answer goes back on (§4.2). On a value of a foreign type, `Foreign.Term` (§8.3) among them, it is the runtime's exact equality (report §3.10). A map keyed by addresses is a type error at its first operation, since an address has no equality; key it by the process behind each address instead (§5.5). The compiler infers which type variables need equality, and a printed type marks them (§2.9).

Ordering is separate: `a < b` asks the type's `compare`, which answers an `Ordering`: `Less`, `Equal`, or `Greater`. `Int`, `Float`, `String` and `Char` have one; `Optional` and `Either` have one where their element types do, `None` before `Some` and `Left` before `Right`, and a tuple and a list where every component's type does, component by component from the left, a shorter list before a longer one it begins; `Bool`, `Map` and `Set` have none. A type of your own gets one by `derives compare` on its declaration (§7.3), or by declaring `compare` in its module.

`compare(a, b)` is the function form of `<`, which answers the `Ordering` itself. A function named `Money.compare` is a member of the type `Money` (§7.2):

```ernest
type Money = Money(Int)

fn Money.compare(Money(left), Money(right)) : Ordering =
    compare(left, right)

export fn main() : Unit =
    Io.println(if Money(3) < Money(5) then "cheaper" else "not cheaper")
```

```console
$ ern run money.erc
cheaper
```

In the body, `compare` compares the two `Int`s, by `Int`'s order: `compare` and `<` choose by the type of their operands. They are how a program reaches `Money.compare`, whose name stands in its declaration alone (report §4.5).

A set in the order of its elements' `compare` is `OrderedSet`, and a map with its keys in order `OrderedMap`; code written once over both kinds of set is §7.3's. `Set` is the prelude's type, which every module names without a module's name (§2.9), so the type of the module `OrderedSet` is written with its module's name, `OrderedSet.Set`.

### 2.6 Patterns and irrefutability

The same patterns appear in `match` clauses, `let` bindings, and function parameters. A `let` and a parameter need an *irrefutable* pattern, one that cannot fail to match: a name, `_`, a tuple of irrefutable patterns, the only constructor of its type with irrefutable fields, or an irrefutable pattern with `as`, which comes below.

```console
$ ern shell
Ernest 0.6.0. :help for the commands, :quit to leave.
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
Ernest 0.6.0. :help for the commands, :quit to leave.
> let x = 3
x : Int
> match 3 { n when n == x -> "same as x" | _ -> "different" }
"same as x" : String
```

A literal is a pattern too, and matches the value equal to it: a number, a character, a string, `true` or `false`. A list pattern takes literals as it takes names:

```ernest
fn reply(words : List(String)) : String =
    match words {
        ["hello"] -> "hello to you"
      | "add" :: numbers -> "adding " <> Int.toString(List.size(numbers)) <> " numbers"
      | _ -> "pardon?"
    }
```

A name appears at most once in a pattern. A pattern of a constructor with named fields may leave out the fields it does not need: `Rectangle(width = w)` binds one field of the `Rectangle` above, and `Rectangle()` matches any.

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

A guard after the alternatives sees the shared variables. The same works in `receive`, the `match` over a process's messages (§4.1). `Some(x) or None -> x` is a type error, since `None` binds no `x` (report §5.9).

`as` binds the whole value beside its parts: `Some(x) as present` binds `x` to the payload and `present` to the whole `Optional`.

A guard is a `Bool` expression that receives nothing. A guard that is `false` passes to the next clause; one that faults faults the process. A guarded clause does not count toward coverage, so a `match` with guards usually ends in an unguarded clause.

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

At the prompt the session is the rest of the block: `let p <- e` binds what is inside a `Some` or a `Right`, and shows a `None` or a `Left` as an expression's value is shown, binding nothing and leaving `it` as it was (report §11.2):

```console
$ ern shell
Ernest 0.6.0. :help for the commands, :quit to leave.
> let n <- String.toInt("42")
n : Int
> let m <- String.toInt("forty-two")
None : Optional(Int)
```

A block is an `Optional` chain or an `Either` chain, never both. To run a step that can fail over every element of a list, `List.tryMap(xs, f)` and `List.tryFold(xs, acc, f)` stop at the first `Left`.

### 2.8 The pipe operator `|>`

Ernest's stdlib is subject-first. `|>` reads left-to-right:

```console
$ ern shell
Ernest 0.6.0. :help for the commands, :quit to leave.
> "abc" |> String.toList |> List.reverse |> String.fromList
"cba" : String
```

`x |> f` is `f(x)`, and `x |> f(a, b)` is `f(x, a, b)`: the pipe inserts the first argument. Parentheses change nothing, so `x |> (f(a))` is `f(x, a)` too. A lambda is parenthesized, `x |> (fn(y) = y + 1)`, since its body would take in a `|>` after it (§3.2), and a function a call computes is applied by writing its arguments after the call, `adder(3)(x)`, since `x |> adder(3)` is `adder(x, 3)`.

### 2.9 The standard library

The standard library is a module per type, `List`, `Map`, `Set`, `String`, `Char`, `Bytes`, `Bool`, `Int`, `Float`, `Optional`, `Either`, `Path`, and the rest that report Appendix E lists, `Random` among them, and the system modules `Io`, `Clock`, `Terminal`, `Fs`, `Tcp`, and `Os`, through which a program uses the runtime's *system processes*, the processes the runtime starts for a program, standard output's and the clock's among them. It is always on the load path, where a program's compiled modules are found (§9.1).

The names every module may use without a module's name before them, `Some`, `Left`, `spawn` and `send` among them, are the *prelude*'s (report §9). The library's rules let you guess a name before looking it up (report Appendix E.0):

- **One verb per operation, in every module that has it.** `Map.get(m, k)` and `List.get(xs, 0)`; `remove` takes the key, `Map.remove(m, k)`, and a list's removal by index is `List.removeAt(xs, 0)`; `size`, `isEmpty`, `contains`, `put`, `map`, `filter`, `fold`, `forEach`, `find`, `fromList`, `toList` wherever they apply, and `foldLeft` in place of `fold` where the container has an order, as a list has.
- **Subject first, callbacks last**, so the pipe works: `xs |> List.foldLeft(0, fn(acc, x) = acc + x)`.
- **A conversion is named by the other type.** Where one type is built from the other, or the other is its encoding, both directions are that type's module's, `String.fromList` and `String.toList`, `Bytes.toHex` and `Bytes.fromHex`; any other conversion is its argument's module's `toX`: `String.toInt`, `Int.toString`.
- **A partial operation returns `Optional`; one with a cause returns `Either`.** `List.get` and `String.toInt` return `Optional`, `Fs.read` returns `Either(Io.Error, Bytes)`. A program writes an `Io.Error` with `Io.show`, as a value, `Io.Other("address already in use")`, or in its own words by a `match` over its constructors. `Io.Error` is no prelude type, so its constructors are written with the module's name, `Io.Timeout`, `Io.NotFound`, in a pattern as in an expression (report §4.2).
- **A `String` is text, not a list.** Its length and positions count what a reader sees as letters, which `String.graphemes` gives one by one; `String.toList` gives its `Char`s.

Three more rules concern processes, and are for after §4:

- **A system process is used through its module**, never by `send`.
- **A function that waits takes a timeout in milliseconds, last**, and may answer `Left(Io.Timeout)`: `Fs.read(path, 5000)`. `Io.Timeout` is `Io.Error`'s, whichever module answers it, `Peer.find` (§8.2) among them.

  No time given to a system module means no limit. A server that waits for as long as it takes asks again on each `Left(Io.Timeout)` (§8.7).

  A read of standard input and a write to standard output wait without a limit, since those streams are the program's own. A socket's far end or a program the runtime started can hang unseen, so `Tcp.write`, `Os.read` and `Os.write` take a time too (report Appendix E.0 shape rule 8).
- **A function that delivers later takes a function that makes the message.** `Clock.alarm(100, Ticked)` puts `Ticked(time)` in the mailbox after 100 ms, `time` being the moment it fired. The function that makes the message receives nothing; the one that takes it, `Clock.alarm` or `Terminal.subscribe`, asks for a delivery into the caller's mailbox, and its type says so, `receiving m` (§4.1). `Clock.now()` is the time now, in milliseconds since the epoch. A process that only waits a while writes `receive { after ms -> Unit }` (§4.3); `Clock` has no sleep.

What a type does not say, the entry in Appendix E does: `List.sort` is stable, `Map.toList` has no order. In the shell, `:doc List.sort` prints it. `:browse Fs` lists a module's types by name and its functions with their types, and `:doc Fs.Entry` shows a type's declaration, its fields among it.

**Marks in a printed type.** A printed type marks what the compiler infers of a type variable, and an annotation writes no mark. A variable marked `=`, `a=`, needs equality (§2.5): `fn equal(a, b) = a == b` prints as `equal : (a=, a=) -> Bool`. The one mark a program writes is `=` on a foreign declaration's type variable, since the compiler cannot see what the Erlang compares (§8.3, report §11.5).

### 2.10 A word counter, by hand

Sections 2 to 5 build one program, a word counter, a stage in each. Here it is values at the prompt: a text, its words, and a count kept in a map.

```console
$ ern shell
Ernest 0.6.0. :help for the commands, :quit to leave.
> let text = "the cat and the hat"
text : String
> let words = String.words(text)
words : List(String)
> words
["the", "cat", "and", "the", "hat"] : List(String)
> let counts = Map.update(Map.empty, "the", fn(count) = Optional.withDefault(count, 0) + 1)
counts : Map(String, Int)
> Map.update(counts, "the", fn(count) = Optional.withDefault(count, 0) + 1)
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

A block may declare a `fn` of its own, `{ fn square(n : Int) : Int = n * n; square(3) }`. It is visible in the whole block, but may be used only after the `let`s it reads (report §5.4).

### 3.2 Lambdas and closures

```console
$ ern shell
Ernest 0.6.0. :help for the commands, :quit to leave.
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

A lambda's body extends as far as the text allows: to the `,`, `;`, `:`, `|`, `->`, `{`, `>>`, or closing bracket of the form around it, or to a `then` or `else`. A `{` the body itself opens, a block's or a `match`'s, `fn() = { ... }` or `fn(x) = match x { ... }`, is the body's, and the body runs to its closing `}`.

### 3.3 Type inference and its limits

Ernest infers types Hindley-Milner style. You can omit annotations on parameters and returns:

```ernest
fn double(value) =
    value * 2 // inferred (Int) -> Int
```

The literal `2` is an `Int`, so `*` is `Int.*` and `value : Int`. But **Ernest does not infer a "numeric type" or default to `Int`**:

```ernest-rejected
fn twice(value) =
    value + value
```

```console
$ ern build twice.ern
twice.ern:2:5: the operand type of `+` is not determined; annotate value
1 | fn twice(value) =
2 |     value + value
  |     ^^^^^^^^^^^^^
```

Without a source that fixes the type, `value + value` is a type error, and `(value : Int)` or `(value : Float)` fixes it. A field read is the same: `fn age(person) = person.age` is refused until `person : Person` says whose field it is. Once the type is fixed, `+` is that type's: `Int.+` for an `Int`, and `Distance.+` for a user type that declares it as a member, `fn Distance.+` (report §4.8, report §5.6). A member's name stands in its declaration alone, so where a function is wanted a lambda passes the operation, `List.foldLeft(xs, 0, fn(sum, x) = sum + x)` (report §4.5).

**What is polymorphic.** A polymorphic name may be used at one type here and at another there.

- A `fn` is polymorphic.
- A top-level `let` is polymorphic where its initializer is a value: a literal, a name, a lambda, or a constructor applied to values, `let empty = []`.
- A top-level `let` whose initializer calls a function has the type the call gives, and is polymorphic where that type holds no function, foreign value, address or reply. `let empty = emptyMap()`, `emptyMap` a foreign function that answers the host's empty map, a `Map(k, v)`, is polymorphic; `let shared = spawn(fn() = cell(None))`, an address, is not (report §4.6).
- A `let` in a block is polymorphic only where it binds a lambda. Any other `let` in a block has one type.

```console
$ ern shell
Ernest 0.6.0. :help for the commands, :quit to leave.
> { let pair = fn(x) = #(x, x); #(pair(1), pair("a")) }
#(#(1, 1), #("a", "a")) : #(#(Int, Int), #(String, String))
> { let one = List.take; #(one([1, 2], 1), one(["a"], 1)) }
input 2:1:46: the argument does not fit one: expected List(Int), found List(String)
1 | { let one = List.take; #(one([1, 2], 1), one(["a"], 1)) }
  |                                          --- one : (List(Int), Int) -> List(Int)
  |                                              ^^^^^
  | = help: the types differ at Int and String
```

`pair` binds a lambda and is used at `Int` and at `String`. `one` binds another function's value, so its first use settles its type, and the second is refused.

**A type nothing settles.** After `let xs = []` in a block, the element type of `xs` is settled by an annotation, by a later use in the block, or by `xs` reaching the block's result. Where nothing settles it, with `xs` never read, the type stays open and the block compiles.

A top-level `let` that is not polymorphic, and a `let` at the prompt, must have their types settled, by an annotation where nothing else settles them. A top-level `let` settles an effect variable nothing else settles by where it stands: one left as a function type's effect is none, so `let p = twice(fn(x : Int) = x)`, with `fn twice(f) = #(f, f)`, is `#((Int) -> Int, (Int) -> Int)`; and one left as a type argument is `Never`, the mailbox type of a process that receives nothing (§4.1), as a spawned function's is (report §4.6).

### 3.4 Functions that receive

A function whose type has `receiving M` receives messages of the type `M`, and one whose type has no `receiving` receives nothing and runs in any process; what receiving is, once processes are taught, is §4.1's. Either may send, spawn, print, or call another process (§4).

Either kind of function can fault or run forever: `a / b` with `b = 0` faults although its type is `(Int, Int) -> Int`, and `fault("...")` has every type and faults when it is reached. `receiving` says only that a function receives, not whether it can fault (§6).

### 3.5 Higher-order and effect polymorphism

```ernest
fn apply(f, x) =
    f(x)
```

The inferred type is `((a) -> b receiving e, a) -> b receiving e`: `apply` receives where the function it is given receives, so `apply(f, x)` receives nothing when `f` receives nothing. Written out, it is `fn apply(f : (a) -> b receiving e, x : a) : b receiving e = f(x)`. An annotation without the `receiving e`, `f : (a) -> b`, takes only a function that receives nothing. `List.map`, `List.forEach`, and every other function of the standard library that calls a function it takes are the same.

An effect variable may stand for a mailbox type or for none; one that must stand for a mailbox type is §4.1's. The letters in a printed type mean nothing of their own.

Where a function's result is itself a function, a `receiving` after the result is the result's: `fn later() : () -> Unit receiving e` answers a function that receives. Parenthesized, the result leaves the `receiving` to the function declared: `fn first() : (() -> Unit) receiving e` receives, and answers a function that receives nothing. A printed type is parenthesized the same way (report §4.5).

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
    Map.toList(counts) |> List.sortBy(fn(#(word, count)) = #(-count, word)) |> List.take(limit)
```

`words` lowers the text and splits it at its whitespace (report Appendix E.5). `count` folds the words into a map with `add`. `top` sorts the pairs by count, most first and by word where counts are equal, and keeps `limit` of them.

`List.sortBy` orders the pairs by a key, which the lambda makes of each pair, its parameter a pattern that takes the pair apart. The key is a tuple, the count made negative, so that the larger comes first, beside the word. A tuple is ordered component by component from the left, as a list is, where each component's type is ordered, so the word decides between equal counts (report §3.10, Appendix E.2). `ern shell words.erc` loads the module and runs nothing, since it has no `main`:

```console
$ ern build words.ern
$ ern shell words.erc
Ernest 0.6.0. :help for the commands, :quit to leave.
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
type CounterMsg = Inc(Int) | Get(Reply(Int))

fn count(total : Int) : Unit receiving CounterMsg =
    receive {
        Inc(amount) ->
            count(total + amount)
      | Get(reply) -> {
            answer(reply, total);
            count(total)
        }
    }
```

`count` keeps its state in the parameter `total`, and its mailbox takes `CounterMsg`. `receive` waits for a message that matches a clause and evaluates that clause. Both clauses call `count` again with the new state; a tail call does not grow the stack, so the loop runs forever.

`let counter = spawn(fn() = count(0))` starts a process that runs the lambda, and `counter` is its address. The lambda calls `count`, whose mailbox takes `CounterMsg`, so the address is an `Address(CounterMsg)`, and nothing but a `CounterMsg` can be sent to it. The process runs on this node, the runtime the program runs in; `Peer.spawn(name, f, ms)` starts one on another node (§8).

`send(counter, Inc(5))` puts `Inc(5)` in the mailbox of the process at `counter` and returns at once, without waiting for it to be received. A send to a process of another node waits only where what waits to go to that node fills the host's buffer for it (report §6.2). `self()` is the address of the process that calls it, so a parent that gives a child its own address takes it first: `let me = self(); spawn(fn() = child(me))`.

A `Reply(Int)` is where an answer goes. The process that asks gets one from `Address.call`, which puts it in the request and waits for the answer (§4.4), and the process that receives the request answers it with `answer(reply, total)`. §4.5 runs the counter whole.

**What receives.** A function whose type has `receiving M` involves the mailbox of the process it runs in, whose type is `M`: it runs a `receive`, gives out the process's address through its type, as `self` does, asks for a message to be delivered into the mailbox, as `monitor` does, or calls a function that does one of these (report §6.1). A function that calls `self` and keeps the address to itself receives nothing: `fn stop() = kill(self())` is a `() -> Unit` (report §3.9).

An effect variable that also appears inside `Address`, the type of an address to a process whose mailbox is `m`, as in `self : () -> Address(m) receiving m`, stands for a mailbox type only, since an address needs one (§3.5). The `Address(m)` shows it, and a printed type marks nothing more.

**A timed wait.** A `receive` with an `after` clause alone waits on the mailbox and reads no type from it (§4.3). Its effect variable is *process-only*, a mailbox type and never none, since the wait is on a mailbox. A printed type marks such a variable `+`, `receiving e+`, where no `Address` in the type shows it already (report §3.9, report §11.5). Written out, such a function carries `receiving e`, and so does every function that calls it:

```ernest
fn pause(ms : Int) : Unit receiving e =
    receive {
        after ms -> Unit
    }

fn rest() : Unit receiving e =
    pause(10)
```

`pause` prints as `pause : (Int) -> Unit receiving e+`. Written `fn rest() : Unit = pause(10)`, the caller is refused, `pause needs a mailbox, and rest receives nothing`. An entry point that waits so is `: Unit receiving Never`, its mailbox the one nothing can be sent to (below). A top-level `let` whose type leaves a process-only variable unsettled is refused until an annotation settles it (§3.3, report §4.6).

**A process that receives nothing.** A process with no `receive` has nothing in it that says what its mailbox takes. `spawn`'s type ties its function to the address it returns: the function is a `() -> Unit receiving n`, and the address an `Address(n)`. A function that receives nothing fits wherever one with a mailbox type is expected, so it is spawned as any other, and the definition the spawn is written in fixes `n`:

- The first `send` to the address fixes it: in `{ let worker = spawn(fn() = Unit); send(worker, 5); worker }`, `worker` is an `Address(Int)`.
- A call of the definition fixes it where it stands in a parameter's type: `fn start(f) = spawn(f)` is an `(() -> Unit receiving n) -> Address(n)`, and `start(fn() = count(0))` an `Address(CounterMsg)`.
- The process the definition runs in fixes it where it is the definition's own mailbox type: `fn standIn(here : Bool) = if here then self() else spawn(fn() = Unit)` is a `(Bool) -> Address(m) receiving m`, which called in the counter answers an `Address(CounterMsg)`.

Where nothing fixes it by the end of the definition the spawn is written in, or of the input at the prompt, the process receives nothing and its mailbox type is `Never`, one rule for every process: one spawned here or on a peer (§8.1), and `main` (§1.1). Its address is an `Address(Never)`, to which nothing can be sent:

```console
$ ern shell
Ernest 0.6.0. :help for the commands, :quit to leave.
> let worker = spawn(fn() = Unit)
worker : Address(Never)
```

A top-level `let`, and one at the prompt, must have its type settled, and is refused until an annotation settles it (§3.3):

```console
$ ern shell
Ernest 0.6.0. :help for the commands, :quit to leave.
> let xs = []
input 1:1:1: the type of xs is not determined by this input; it is List(a)
1 | let xs = []
  | ^^^^^^^^^^^
  | = help: bind it with an annotation that settles the variable, as in `let xs : List(Int) = []`, or declare a function with `fn`
> let xs : List(Int) = []
xs : List(Int)
```

An expression at the prompt whose type stays open is run, and the shell shows the open type and keeps `it` as it was:

```console
> List.reverse([])
[] : List(a)
`it` is unchanged: this input did not determine the type of its value
```

### 4.2 A reply

A `Reply` in a message type says that whoever sends the message waits for an answer, and for what: a `Get(Reply(Int))` is answered with an `Int`. `answer(reply, v)` is the one operation on a reply: it sends `v` to the caller waiting on it, by a way private to the call and never through the caller's typed mailbox. A second answer to a reply is dropped, and so is an answer that comes after the caller stopped waiting (report §6.6).

A reply is a value. A server that cannot answer yet keeps it until it can, as anything else it keeps: in a parameter of its loop, in a list, a map or a message, or captured by a lambda. The queue of §4.4 keeps its waiting callers' replies in a list. A caller whose reply is never answered waits until its call's deadline, or, in `Address.callForever`, for as long as the callee lives (§4.4).

### 4.3 Selective receive and `after`

`receive` takes the first message that matches a clause and leaves the others in the mailbox for later. Unlike `match`, it need not cover every case, but a clause that can never match is still an error.

```ernest
type Inbox = Data(Int) | Woke

fn waitForData() : Optional(Int) receiving Inbox =
    receive {
        Data(n) -> Some(n)
      | after 1000 -> None
    }
```

`after 1000` gives up after 1000 milliseconds with no matching message, and `after 0` looks without waiting. Without `after`, the process waits for as long as it takes. A `receive` with only an `after` clause is a timed wait, the one `receive` a process with mailbox `Never` may use.

A guard in `receive` is narrower than one in `match`, since it chooses a message before taking it: it compares and tests only what is already at hand, the variables in scope, a top-level `let`, literals and nullary constructors, joins these with `!`, `&&` and `||`, and calls nothing (report §6.3). For more, receive the message and `match` it. That is another program: the message is then out of the mailbox, where a guard that does not hold would have left it for a later `receive`.

If a `Woke` is already in the mailbox, `waitForData` leaves it there and waits for a `Data`; a later `receive` can take the `Woke`.

### 4.4 `Address.call`

Synchronous request-reply, used from the caller side:

```console
$ ern shell
Ernest 0.6.0. :help for the commands, :quit to leave.
> :type Address.call
Address.call : (Address(m), (Reply(a)) -> m, Int) -> Optional(a)
```

`Address.call(counter, Get, 1000)` makes a fresh `Reply`, gives it to the function that builds the request, here `Get`, a positional constructor and so a function (§2.3), sends the request to `counter`, and waits up to 1000 ms. A request that carries more than its reply, or whose reply is a named field, is built by a lambda: `fn(reply) = Add(amount = 5, reply = reply)`. A request called from many places is built by a function of its own, `fn add(amount) = fn(reply) = Add(amount = amount, reply = reply)`, and each call is `Address.call(counter, add(5), 1000)`.

The call returns `Some(v)` for an answer and `None` for none. `None` does not cancel the work: the recipient may still be computing, so a request that changes state and is sent again may change it twice. An answer that comes late is dropped and never reaches the caller's mailbox, so `Address.call` works whatever that mailbox's type is (report §6.6).

`Address.callForever` waits without a deadline and returns the answer itself. When the process called ends or restarts before it answers, either call ends at once: `Address.call` returns `None`, and `Address.callForever` faults its caller. A callee that faulted gives the caller its cause, the text that says what went wrong (§6.3), unchanged; `ern run`'s line of the caller's fault names the callee's spawn site after the cause: `division by zero, the fault of the callee Ledger.start:6`. Otherwise the caller's cause says how the callee ended: it was killed, returned without answering, was closed, was restarted (§6.5), had ended already, ended with its program, its node ended in order, or is unreachable, its node out of reach (§8.2). A callee that lives on without answering holds a `callForever` caller for as long as it lives, one that only waits as much as one that dropped the reply.

A server that cannot answer at once keeps the reply until it can, in a list as well as anywhere else a value waits (§4.2). A queue answers a `Take` with an item it has, or keeps the reply until a `Put` brings one:

```ernest
type QueueMsg = Put(Int) | Take(reply : Reply(Int))

type MainMsg = Took(Int)

// Items no one has asked for yet, and the replies of the callers waiting for
// an item.
fn queueing(items : List(Int), waiting : List(Reply(Int))) : Unit receiving QueueMsg =
    receive {
        Put(item) ->
            match waiting {
                reply :: rest -> {
                    answer(reply, item);
                    queueing(items, rest)
                }
              | [] ->
                    queueing(items <> [item], [])
            }
      | Take(reply = reply) ->
            match items {
                item :: rest -> {
                    answer(reply, item);
                    queueing(rest, waiting)
                }
              | [] ->
                    queueing([], waiting <> [reply])
            }
    }

export fn main() : Unit receiving MainMsg = {
    let queue = spawn(fn() = queueing([], []));
    let me = self();
    let _ = spawn(fn() = send(me, Took(take(queue))));
    send(queue, Put(7));
    receive {
        Took(item) -> Io.println("took " <> Int.toString(item))
    }
}

// Waits for an item, for as long as it takes.
fn take(queue : Address(QueueMsg)) : Int =
    Address.callForever(queue, fn(reply) = Take(reply = reply))
```

```console
$ ern run queue.erc
took 7
```

A `Put` answers the first caller waiting, and a `Take` answers at once or keeps its reply in the list. `main` cannot wait in the call itself, since it is `main` that puts the item. A process of its own makes the call and sends the answer on as `Took(item)`, and `main` goes on to put. A process that must keep receiving while an answer is on its way calls from such a helper; one with nothing else to do calls.

A kept reply outlives a caller that ends. `Reply.process(reply)` is the caller's `Process`, the identity of a process, which §5.2 teaches, and which the server may monitor to drop the reply of a caller that has ended (report §6.6).

**A library that waits.** A function that receives is tied to the mailbox type of the process it runs in, so a function that must wait on messages of its own, from whatever process calls it, is a process and a call. The library spawns a process whose mailbox is its own, and the caller gets the result by a call, which leaves the caller's mailbox as it was. `gathered` runs `f` on each number in a process of its own and collects the pieces as they come, in any process. It uses `spawnMonitored` and `Down`, which §5.2 teaches: a process started and watched, whose end comes back as a message:

```ernest
// gather.ern
export type Piece(a) = Piece(n : Int, value : a)

type GatherMsg(a) = Collect(Reply(List(Piece(a)))) | Computed(Piece(a)) | Ended(Down)

export fn gathered(numbers : List(Int), f : (Int) -> a receiving e) : List(Piece(a)) = {
    let gatherer = spawn(fn() = run(numbers, f));
    Address.callForever(gatherer, Collect)
}

fn run(numbers : List(Int), f : (Int) -> a receiving e) : Unit receiving GatherMsg(a) =
    receive {
        Collect(reply) -> {
            let me = self();
            List.forEach(numbers, fn(n) = {
                let _ =
                    spawnMonitored(fn() = send(me, Computed(Piece(n = n, value = f(n)))), Ended);
                Unit
            });
            answer(reply, gather(List.size(numbers), 0, []))
        }
    }

// A helper that returned has sent its piece, and its Down keeps no order with
// that message, so the gather ends once every helper has ended and each one
// that returned has been heard from. owed counts the helpers that returned
// and whose piece has not come; it is below 0 while a piece is ahead of its end.
fn gather(running : Int,
          owed : Int,
          pieces : List(Piece(a))) : List(Piece(a)) receiving GatherMsg(a) =
    if running == 0 && owed == 0 then
        pieces
    else receive {
        Computed(piece) -> gather(running, owed - 1, piece :: pieces)
      | Ended(Down(reason = Returned)) -> gather(running - 1, owed + 1, pieces)
      | Ended(_) -> gather(running - 1, owed, pieces)
    }
```

```ernest
// collect.ern
export fn main() : Unit =
    Gather.gathered([3, 1, 2], fn(n) = n * n)
        |> List.sortBy(fn(piece) = piece.n)
        |> List.forEach(fn(piece) =
                            Io.println(Int.toString(piece.n) <> ": " <> Int.toString(piece.value)))
```

```console
$ ern run collect.erc
1: 1
2: 4
3: 9
```

`GatherMsg` is the library's own and stays private: the caller sees `gathered`'s signature and nothing of how it waits. `Collect` is a constructor, and a constructor is a function, so it stands where `Address.callForever` wants the function that builds the request. `gather` ends on what it waits for, each helper's end and each piece, and needs no deadline of its own. The helper whose `f` faults sends no piece, and its `Down` says so.

**Pacing.** A mailbox has no limit. A process that sends faster than its receiver takes messages fills the receiver's mailbox, and the node's memory with it. A call paces its caller, since the caller waits for each answer before it asks again. A stream of messages is paced by a window of credits: the receiver grants a number of messages, and the sender waits for the next grant when it has sent them.

```ernest
type ConsumerMsg = Item(Int) | Finished

type ProducerMsg = Granted(Int)

// Sends the items from `next` to `last` while it has credit, and waits for
// more when it has none.
fn produce(consumer : Address(ConsumerMsg),
           next : Int,
           last : Int,
           credit : Int) : Unit receiving ProducerMsg =
    if next > last then
        send(consumer, Finished)
    else if credit == 0 then receive {
        Granted(granted) -> produce(consumer, next, last, granted)
    } else {
        send(consumer, Item(next));
        produce(consumer, next + 1, last, credit - 1)
    }

// Takes the items, granting ten more each time it has taken ten.
fn consume(producer : Address(ProducerMsg), taken : Int, sum : Int) : Unit receiving ConsumerMsg =
    receive {
        Item(value) -> {
            if (taken + 1) % 10 == 0 then send(producer, Granted(10)) else Unit;
            consume(producer, taken + 1, sum + value)
        }
      | Finished ->
            Io.println("sum " <> Int.toString(sum))
    }

export fn main() : Unit receiving ConsumerMsg = {
    let me = self();
    let producer = spawn(fn() = produce(me, 1, 100, 0));
    send(producer, Granted(10));
    consume(producer, 0, 0)
}
```

```console
$ ern run pacing.erc
sum 5050
```

However slow the consumer, no more than ten items wait in its mailbox. Where nothing paces a queue, `Process.status` (§5.2) shows it building: for a live process it answers `Some(status)`, and `status.queued` is the number of messages waiting in its mailbox. A write paces its writer as a call does: `Io.println`, and every other write of the system modules, returns once its stream has taken the bytes, so a program's output goes at the pace of what reads it.

**Fan-out.** A process that sends each message to many receivers, as a chat room sends each line to its members, is not paced by any of them. A call to each would pace it by the slowest, and one receiver that stalls would then hold up all the others. So each receiver gets a window of its own. The sender keeps the credit each receiver has left, and sends only to one that has some; each receiver grants more as it takes what it was sent.

A receiver that writes each message on to a socket grants once its write has returned, and a write waits while the far end is behind (§8.7), so a client that stops reading stops the grants. A receiver whose credit stays at nothing has stalled, and the sender skips it or drops it, as its protocol says. Either way, no more than its window waits in its mailbox. `Process.status` shows such a queue building, but it is for watching what runs: a program paces its messages with its own protocol.

### 4.5 Running the counter

The counter of §4.1 with a `main` that uses it, in `counter.ern`:

```ernest
type CounterMsg = Inc(Int) | Get(Reply(Int))

fn count(total : Int) : Unit receiving CounterMsg =
    receive {
        Inc(amount) ->
            count(total + amount)
      | Get(reply) -> {
            answer(reply, total);
            count(total)
        }
    }

export fn main() : Unit = {
    let counter = spawn(fn() = count(0));
    send(counter, Inc(5));
    send(counter, Inc(3));
    match Address.call(counter, Get, 1000) {
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

When `main` returns, or its process ends in any other way, the program ends: every process on the node ends with the reason `ProgramEnd`, one of the reasons a `Down` carries (§5.2), which is not a fault, and output still on its way is written first. A program stopped from outside by a termination signal ends the same way, and so does one that is no node at a hangup signal, which a node takes as a reload (§9.2); the terminal's interrupt ends it at once, and output still on its way may be lost, unless the program reads the terminal's keys, which then deliver the interrupt as a key (report §8.6, report §12.1, report §12.4).

The count is 8 because messages from one sender arrive in the order sent: both `Inc`s come before the `Get`. Were the counter too slow, `main` would print `counter did not answer`.

### 4.6 Explicit code replacement

A process can change its code while it runs, keeping its address and its state. The new code arrives in a message that the process's type provides for, as a function value. Here the function is one compiled into the program. In the shell it is one from a module that `:reload` compiled, the shell's command that compiles a changed module again (§9.3). On a peer, a node the program's configuration lists (§8), it is one that a spawn there brings, since a function value does not cross in a message but a spawn carries its code (§8.1, §8.4).

The counter of §4.5 gains an `Upgrade` constructor. The program is three parts of one file, `counter.ern`, which replaces the one of §4.5:

```ernest
// counter.ern
type CounterMsg =
    Inc(Int)
  | Get(Reply(Int))
  | Upgrade(migrate : (Int) -> Int, next : (Int) -> Unit receiving CounterMsg)

fn count(total : Int) : Unit receiving CounterMsg =
    receive {
        Inc(amount) ->
            count(total + amount)
      | Get(reply) -> {
            answer(reply, total);
            count(total)
        }
      | Upgrade(migrate = migrate, next = next) ->
            next(migrate(total))
    }
```

`Upgrade` carries two functions: `migrate` turns the old state into the new, and `next` is the new loop. `next(migrate(total))` is a tail call into the new loop with the migrated state.

A replacement loop that doubles each increment:

```ernest
// counter.ern
fn countTwice(total : Int) : Unit receiving CounterMsg =
    receive {
        Inc(amount) ->
            countTwice(total + 2 * amount)
      | Get(reply) -> {
            answer(reply, total);
            countTwice(total)
        }
      | Upgrade(migrate = migrate, next = next) ->
            next(migrate(total))
    }
```

And a `main` that upgrades after the first `Get`:

```ernest
// counter.ern
export fn main() : Unit = {
    let counter = spawn(fn() = count(0));
    send(counter, Inc(5));
    send(counter, Inc(3));
    match Address.call(counter, Get, 1000) {
        Some(total) -> Io.println("before upgrade: " <> Int.toString(total))
      | None -> Io.println("timeout")
    };
    send(counter, Upgrade(migrate = fn(total) = total, next = countTwice));
    send(counter, Inc(1));
    match Address.call(counter, Get, 1000) {
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

export fn tally(counts : Map(String, Int)) : Unit receiving TallyMsg =
    receive {
        Add(more) ->
            tally(Map.fold(more, counts, add))
      | Top(limit = limit, reply = reply) -> {
            answer(reply, top(counts, limit));
            tally(counts)
        }
    }
```

`Add` brings a map of counts, and `Map.fold` adds each word's count in with `add`, which takes the map, a word, and a count, the order the fold gives them. `Top` is a request, so it carries a `Reply`.

```console
$ ern build words.ern
$ ern shell words.erc
Ernest 0.6.0. :help for the commands, :quit to leave.
> let tally = spawn(fn() = Words.tally(Map.empty))
tally : Address(Words.TallyMsg)
> send(tally, Words.Add(Words.count("the cat and the hat")))
> send(tally, Words.Add(Words.count("the bat")))
> Address.call(tally, fn(reply) = Words.Top(limit = 2, reply = reply), 1000)
Some([#("the", 3), #("and", 1)]) : Optional(List(#(String, Int)))
```

A `send` is `Unit`, which the shell does not print.

### 4.8 Exercises

**(a)** Does `Address.call(counter, ..., 1000)` returning `None` guarantee the recipient did no work?

**(b)** A relay stands in front of the counter of §4.1 and passes every message on:

```ernest
type CounterMsg = Inc(Int) | Get(Reply(Int))

fn relay(counter : Address(CounterMsg)) : Unit receiving CounterMsg =
    receive {
        Inc(amount) -> {
            send(counter, Inc(amount));
            relay(counter)
        }
      | Get(reply) -> {
            send(counter, Get(reply));
            relay(counter)
        }
    }
```

Who answers a `Get` sent to the relay? With `answer(reply, 0)` written after the relay's `send`, what does a caller of the relay get?

**(c)** Add a request `Reset` to §4.1's `CounterMsg`: it answers the total and sets it to zero. Write its clause in `count`. Then leave the clause out and predict: does the program still compile, and what happens to a `Reset` sent to that counter?

## 5. Manage process lifetime

Two processes that talk must also know when the other is done.

### 5.1 Ping-pong

```ernest
type PongMsg = Ping(round : Int, reply : Reply(Int)) | Stop

type MainMsg = PongDone(Down)

export fn main() : Unit receiving MainMsg = {
    let opponent = spawnMonitored(fn() = pong(), PongDone);
    let _ = spawn(fn() = ping(opponent, 3));
    receive {
        PongDone(_) -> Unit
    }
}

fn ping(opponent : Address(PongMsg), round : Int) : Unit =
    if round == 0 then
        send(opponent, Stop)
    else {
        Io.println("ping " <> Int.toString(round));
        match Address.call(opponent, fn(reply) = Ping(round = round, reply = reply), 5000) {
            Some(_) ->
                ping(opponent, round - 1)
          | None -> {
                Io.println("pong is not answering");
                send(opponent, Stop)
            }
        }
    }

fn pong() : Unit receiving PongMsg =
    receive {
        Ping(round = round, reply = reply) -> {
            Io.println("pong " <> Int.toString(round));
            answer(reply, round);
            pong()
        }
      | Stop ->
            Unit
    }
```

`ping` receives nothing, and calls and sends all the same, so its type names no mailbox (§3.4).

`main` starts pong with `spawnMonitored`, which §5.2 explains, so that a `PongDone` arrives when pong ends, and waits for it. Had `main` returned at once, the program would have ended before the two had played, since returning from `main` ends every process (§4.5).

The output is `ping 3`, `pong 3`, `ping 2`, and so on, alternating. Messages from one sender arrive in the order sent, so ping's requests reach pong in order. `Io.println` returns once standard output has taken the line (report §12.1), and ping prints before it calls pong, pong before it answers, so each line is written before the next can be. Two processes whose writes nothing orders, two workers printing as they go, interleave in an order no rule fixes.

### 5.2 `monitor` and `Down`

```console
$ ern shell
Ernest 0.6.0. :help for the commands, :quit to leave.
> :type monitor
monitor : (Process, (Down) -> m) -> Unit receiving m
> :type monitorService
monitorService : (Process, (Down) -> m) -> Unit receiving m
> :type spawnMonitored
spawnMonitored : (() -> Unit receiving n, (Down) -> m) -> Address(n) receiving m
```

```ernest-prelude
type Down = Down(process : Process, reason : Reason, site : String)

type Reason = Returned | Killed | ProgramEnd | Fault(String) | Unknown | Unreachable | Restarted
```

`monitor(child, wrap)` puts `wrap(d)` in your mailbox when the process `child` dies, or at once if it is dead already, with the reason `Unknown`, since the runtime keeps nothing of a process that has ended. `child` is a `Process`, the identity of a process, which `Process.fromAddress(a)` gives for an address `a`: watching a process needs no permission to send to it, so a server watches the clients it holds no address to. A process you start yourself is watched from its start with `spawnMonitored(f, wrap)`, `spawn` and `monitor` in one step, so that no end comes before the watch. `monitorService(child, wrap)` watches as `monitor` does and is told of each restart in place too, with the reason `Restarted` (§6.5). `demonitor(child)` ends every watch you hold on `child`; a `Down` already in your mailbox stays, and none comes after (report §6.9).

`wrap` makes your message from the runtime's `Down`: in ping-pong, `PongDone` is a constructor of `MainMsg` that carries one. A `Down` says the process ended, not that it succeeded; its `process` says which, its `reason` says how, and its `site` says where it was spawned, the top-level declaration and the line of the spawn, `Counter.main:19`.

A process that monitors a worker while waiting for its result gets two messages, the result and the death. A `Down` comes from the runtime and not from the process that ended, so it has no order with that process's own messages (§5.1): the worker's last message may arrive after its `Down`. Whichever comes second is still in the mailbox when the next worker is monitored. The `Down` names the process it is about, and the worker names itself in its result, so the wait takes what is about the worker it waits for:

```ernest
type MainMsg = Result(from : Process, value : Int) | Died(Down)

fn work(job : Int) : Int =
    job * job

fn worker(parent : Address(MainMsg), job : Int) : Unit =
    send(parent, Result(from = Process.current(), value = work(job)))

fn runWorker(job : Int) : Optional(Int) receiving MainMsg = {
    let me = self();
    let child = spawnMonitored(fn() = worker(me, job), Died);
    waitFor(Process.fromAddress(child))
}

fn waitFor(child : Process) : Optional(Int) receiving MainMsg =
    receive {
        Result(from = sender, value = value) when sender == child -> Some(value)
      // the Down came before the result; a worker that returned has sent it, so go on waiting
      | Died(Down(process = process, reason = Returned)) when process == child -> waitFor(child)
      | Died(Down(process = process)) when process == child -> None
      | _ -> waitFor(child)
    }

fn report(job : Int) : Unit receiving MainMsg =
    match runWorker(job) {
        Some(value) -> Io.println("job " <> Int.toString(job) <> ": " <> Int.toString(value))
      | None -> Io.println("job " <> Int.toString(job) <> ": the worker died")
    }

export fn main() : Unit receiving MainMsg = {
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

Where the `Down` comes first, `waitFor` reads its reason. A worker that `Returned` sent its result before it did, so the wait goes on until the result comes. Any other reason, a fault or a kill, ended the worker before it sent one, and the wait answers `None`. Where the result is the worker's answer to a call (§4.4), no such care is needed: a call's answer is never overtaken by the callee's end.

`Process.live()` lists the live processes, `Process.status(process)` tells where one was spawned, how many messages wait for it and whether it runs, and `Process.faults(wrap)` sends you every fault as it happens (report Appendix E.21). They are for seeing what runs, and a program is still written with the addresses it was given.

A fault in one process does not affect another, apart from the cases §6.3 lists.

### 5.3 `kill`

```console
$ ern shell
Ernest 0.6.0. :help for the commands, :quit to leave.
> :type kill
kill : (Address(a)) -> Unit
```

`kill(address)` ends the process at `address`, and its monitors receive `Down(reason = Killed, ...)`. The process may run a little before it stops. The REPL of [`examples/repl.ern`](../examples/repl.ern) kills an evaluation that runs too long.

### 5.4 Deadlock

When every process waits in a `receive` or a `callForever` that nothing can ever satisfy, the entry process faults with `deadlock`, and the program ends. A process waiting for a timer, a key, a socket, or a file is waiting for something that can come, so an idle server is not deadlocked. Report §8.6 gives the exact condition.

A delivery that foreign code arranges for after its call has returned, from a timer or a process of the host's, is one the runtime does not see coming, so `ern run` and `ern test` fault a program that waits for it alone with `deadlock` (§8.3).

The fault's trace is the entry process's. A waiting frame names the line of the last call before the wait, since a wait leaves no frame of its own (report Appendix E.21): in a function that spawns and then waits in a `receive`, the frame names the `spawn`'s line. Beneath the trace the report lists the other processes left waiting, a line for each spawn site and the frame they wait in, with their count, as [`examples/lease_broker.ern`](../examples/lease_broker.ern) run with the argument `deadlock` writes of its three clients: `3 processes of LeaseBroker.started:349 wait in LeaseBroker.holding:367` (report §12.4).

A node detects no deadlock, so a program started with `--config-dir` goes on waiting where every process waits, and a wait on another node's process, which only a node can make, is never found to be one (report §8.6). Nor does a shell detect one while it holds the terminal (report §11.2).

### 5.5 A process's addresses

A process has one mailbox, and its mailbox has one type, but the process may be reached through many addresses, each of the type it accepts. `self()` is one: in a process whose mailbox is `GameMsg`, an `Address(GameMsg)`. `adapted` makes others:

```console
$ ern shell
Ernest 0.6.0. :help for the commands, :quit to leave.
> :type adapted
adapted : (Address(b), (a) -> b) -> Address(a)
```

`adapted(target, convert)` is an `Address(a)`: an `a` sent to it arrives at `target` as `convert(a)`. An adapted address is not a process; it is a value, kept like any other.

**Why.** Whoever sends need not know the type of the mailbox it sends to. A worker written to report to an `Address(Either(String, Int))` knows nothing of your `GameMsg`. Given `adapted(me, Done)`, its report arrives as `Done(result)`:

```ernest
type GameMsg = Done(Either(String, Int)) | Ticked(Int)

fn worker(report : Address(Either(String, Int))) : Unit =
    send(report, Right(42))

fn startWorker() : Unit receiving GameMsg = {
    let me = self();
    let _ = spawn(fn() = worker(adapted(me, Done)));
    receive {
        Done(Right(n)) -> Io.println("done: " <> Int.toString(n))
      | Done(Left(error)) -> Io.println("failed: " <> error)
      | Ticked(_) -> Unit
    }
}
```

A library is used the same way, written against a message type of its own, so a program never needs one message type for all its processes.

**Whatever arrives later is delivered so too.** Wherever something arrives later, the function that asks for it takes the function that makes your message from its own (report Appendix E.0 shape rule 8): `monitor(child, wrap)` (§5.2), `Clock.alarm(ms, wrap)`, which puts `wrap(time)` in your mailbox after `ms` milliseconds, `time` the moment it fired, `Terminal.subscribe(wrap)`, which puts every key pressed and every resize in it, and `Process.faults(wrap)`.

A constructor with one positional field is a function value, so `Clock.alarm(100, Ticked)` delivers `Ticked(time)`. A message that needs no value is made by a lambda that ignores it, `Clock.alarm(100, fn(_) = Refresh)` for a constructor `Refresh` without fields.

**Where the function runs.** A `send` to an adapted address applies the function in the sender, at the `send`, which returns once it has, on the node that made the address; from another node it is applied as the message arrives, in a process of the runtime's (report §6.5, §8.7). The sender's messages keep their order through it (§5.1). A wrap has no sender to run in, so the runtime applies it as it delivers the message. Either way, a fault in the function is the fault of the process the message is for, not of the one that sent it (report §6.5, report §6.9), so keep the function to shaping the value:

```ernest
type SplitMsg = Half(Int)

fn halves(target : Address(SplitMsg)) : Address(Int) =
    adapted(target, fn(n) = Half(100 / n))
```

A `0` sent to `halves(t)` faults the process `t` names, with `division by zero`, and the sender goes on.

In the function, `self()`, `Process.current()` and `monitor` are those of the process that owns what the function opens: the sender's, where the `send` applies it; the target's, where it is applied as the message arrives, as a wrap's are its recipient's; and those of the runtime's process that applies it, where the target is on another node than the one that made the address (report §6.5, report §6.9).

**What does not deliver.** `Io.readLine`, `Os.read` and `Tcp.read` put nothing in your mailbox. Each is a call, answered to the process that made it, which waits for the answer; two processes that read one socket each get the part that answers their own read. A process that must go on taking messages while input may come gives the reading to a process of its own, which reads and sends what it read to an address it was given:

```ernest
type ChatMsg = Line(Optional(String)) | Said(String)

fn reader(listener : Address(Optional(String))) : Unit = {
    let line = Io.readLine();
    send(listener, line);
    match line {
        Some(_) -> reader(listener)
      | None -> Unit
    }
}

fn chat() : Unit receiving ChatMsg = {
    let me = self();
    let _ = spawn(fn() = reader(adapted(me, Line)));
    talk()
}

fn talk() : Unit receiving ChatMsg =
    receive {
        Line(Some(text)) -> {
            Io.println("you: " <> text);
            talk()
        }
      | Line(None) ->
            Unit
      | Said(text) -> {
            Io.println("them: " <> text);
            talk()
        }
    }
```

**One process behind them all.** Addresses have no equality, since an adapted address holds a function. The process behind an address has: `Process.fromAddress(a)` is a `Process`, the same one through every adapted address, which can key a `Map` or be kept in a `Set` and to which nothing can be sent. `kill` takes any of a process's addresses and acts on the process behind it.

An address is the authority to reach a process, which is why `kill` takes one; a `Process` is its identity, which anyone may list, and what `monitor`, `Process.status` and `Tcp.give` (§8.7) take: watching a process needs no authority over it.

```ernest
type CountMsg = Counted(Int)

fn oneProcess(me : Address(CountMsg)) : Bool =
    Process.fromAddress(adapted(me, Counted)) == Process.fromAddress(me)
```

`oneProcess(self())` is `true`, and `adapted(me, Counted) == me` does not compile.

**Addresses travel.** An address is a value: it goes in a message, a field or a list, as `Link(me)` does in [`examples/file_sync.ern`](../examples/file_sync.ern). To another node, an adapted address of your own process goes too, and its function stays here (§8.2).

`Clock.alarm` fires once. A periodic tick is scheduled again after each tick is handled, and only then: a loop that scheduled one on every message would add a timer per key pressed. Two functions keep the two apart:

```ernest
type GameMsg = Ticked(Int) | Typed(Char)

type World = World(score : Int)

fn step(world : World) : World =
    World(score = world.score + 1)

fn game(state : World) : Unit receiving GameMsg = {
    Clock.alarm(100, Ticked);
    waitForTick(state)
}

fn waitForTick(state : World) : Unit receiving GameMsg =
    receive {
        Ticked(_) -> game(step(state))
      | Typed(_) -> waitForTick(state)
    }
```

`game` schedules one alarm and hands over to `waitForTick`, which takes the keys typed without touching the alarm; only a `Ticked` returns to `game`, which schedules the next. `step` reads the world's field by selecting it, `world.score`.

An alarm cannot be canceled. A process that no longer wants one takes its message when it comes and drops it, since even a cancel could not take back a message already delivered. A deadline for a piece of work carries the work's id, `Clock.alarm(5000, fn(_) = Expired(job))`, and the loop that waits matches every `Expired`, acting on one whose job is still open and dropping the rest; a message that no `receive` takes stays in the mailbox for as long as the process lives (report Appendix E.15).

### 5.6 The word counter at once

Several texts are counted at once, by a worker each, and the tally totals them. `words.ern` gets its `main`:

```ernest
// words.ern, continued
type MainMsg = Counted(Map(String, Int)) | Died(Down)

export fn main() : Unit receiving MainMsg = {
    let totals = spawn(fn() = tally(Map.empty));
    countAll(totals, ["the cat and the hat", "the bat and the ball", "a cat"]);
    match Address.call(totals, fn(reply) = Top(limit = 3, reply = reply), 1000) {
        Some(best) -> List.forEach(best, fn(#(w, c)) = Io.println(w <> " " <> Int.toString(c)))
      | None -> Io.println("the tally did not answer")
    }
}

fn countAll(totals : Address(TallyMsg), texts : List(String)) : Unit receiving MainMsg = {
    let me = self();
    List.forEach(texts, fn(text) = {
        let _ = spawnMonitored(fn() = send(me, Counted(count(text))), Died);
        Unit
    });
    collect(totals, List.size(texts))
}

fn collect(totals : Address(TallyMsg), left : Int) : Unit receiving MainMsg =
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
      | Died(_) ->
            collect(totals, left)
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

### 5.7 Exercises

**(a)** The ping-pong program prints `ping 3`, `pong 3`, `ping 2`, and so on (§5.1). Move pong's `Io.println` below its `answer`. Is the alternation still guaranteed?

**(b)** Take the clause for `Returned` out of §5.2's `waitFor`. Which lines can `jobs.erc` then print for job 1?

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
      | Left(reason) ->
            "no config: " <> reason
    }

export fn main() : Unit = {
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

Between processes a failure is part of the protocol. A request whose work can fail is answered with an `Either`, and the process that asked handles a `Left` as it handles any answer. `Address.call` adds a case of its own, `None`, for an answer that did not come: in time, or at all, since a call ends at once when the process called ends or restarts, or its node goes out of reach (§8.2). A deadline bounds how long the caller waits: `None` says that no answer was obtained, not whether the process called did the work, or will.

```ernest
type ParserMsg = Parse(text : String, reply : Reply(Either(String, Int)))

fn parsing() : Unit receiving ParserMsg =
    receive {
        Parse(text = text, reply = reply) -> {
            answer(reply, Either.fromOptional(String.toInt(text), text <> " is not a number"));
            parsing()
        }
    }

fn outcome(parser : Address(ParserMsg), text : String) : String =
    match Address.call(parser, fn(reply) = Parse(text = text, reply = reply), 1000) {
        Some(Right(n)) -> "parsed " <> Int.toString(n)
      | Some(Left(reason)) -> "refused: " <> reason
      | None -> "no answer"
    }

export fn main() : Unit = {
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

A fault is what the program did not expect: a division by zero, a `Float` result out of range, a `fault("...")` the program calls on an invariant it finds broken. Report §7.4 lists the language's causes, a library function's section gives its own (report §7.3), and a failure of the runtime, a spawn past the host's limit of processes among them, is one too (report §7.3). Running out of memory is no fault: the host ends the whole program (report §10).

A fault ends the process it happens in, and only that process, unless the process restarts (§6.5). A process that monitors it receives a `Down` whose reason is `Fault(cause)`:

```ernest
type MainMsg = WorkerDied(Down)

fn average(total : Int, count : Int) : Int =
    total / count

fn worker(count : Int) : Unit =
    Io.println(Int.toString(average(100, count)))

export fn main() : Unit receiving MainMsg = {
    let _ = spawnMonitored(fn() = worker(0), WorkerDied);
    receive {
        WorkerDied(Down(reason = Fault(cause), site = site)) ->
            Io.println("the worker spawned at " <> site <> " faulted: " <> cause)
      | WorkerDied(_) ->
            Io.println("the worker ended")
    }
}
```

```console
$ ern run faults.erc
Faults.main:10 faulted: division by zero
    erlang:'div'/2
    Faults.average:4
    Faults.worker:7
the worker spawned at Faults.main:10 faulted: division by zero
```

`average` receives nothing and still faults, as §3.4 says any function may. The `site` of a `Down` names the top-level declaration in which the process was spawned and the line of the spawn. The first four lines are `ern run`'s own: it writes every fault to standard error as it happens, a line of the spawn site and the cause, whatever the program does about it.

Beneath the line it writes the fault's trace, where the fault was met, a frame a line, the innermost first: the host's division, in `average` at line 4, which `worker` called at line 7. A frame of the program is named as a spawn site is, a lambda's by the declaration it is written in, and the trace ends with the program's outermost frame, the runtime's own frames left out but where the cause names a host error, a failure of the runtime or a foreign function's raise (report §7.4, Appendix E.21). A function whose last act is a call leaves no frame, since the call takes its place, as a tail call does in §4.1, so the lambda that called `worker` is not among them: a trace shows where the process stood, not every call that led there.

Where standard error goes to a file or a pipe, and not to a service manager's journal (§9.5), each line begins with the time of the fault (report §11.2).

Some faults reach beyond their process. A fault in the entry process ends the program, and `ern run` exits with status 1, as a fault in an initializer does. A fault in a function that makes a message, an adapted address's (§5.5) or the wrap given to `monitor`, `Clock.alarm`, `Terminal.subscribe` or `Process.faults`, is the fault of the process the message is for. The loss of a peer faults no process, but one waiting in `Address.callForever` on one of its processes (§8.2, report §8.7). A fault in a process that a `callForever` waits on faults the caller with the same cause, and the caller's line names the callee's spawn site after the cause, `, the fault of the callee` and the site; a `Down` of the caller carries the cause alone (report §6.6, report §11.2).

A process that is killed, or that ends with the program, has not faulted. A deadlock is a fault of the entry process (§5.4).

### 6.4 Let it crash

A worker need not guard against what it did not expect. It faults, and the process that watches it decides what follows: it tries again, gives up, or ends too. The recovery is written once, in the watcher, and the worker's code is only its work. The watcher supervises the worker, and it is spawn, monitor, and receive:

```ernest
type SupervisorMsg = Result(Int) | Ended(Down)

fn supervise(jobs : List(Int)) : Unit receiving SupervisorMsg =
    match jobs {
        [] ->
            Io.println("all jobs done")
      | job :: rest -> {
            let me = self();
            let _ = spawnMonitored(fn() = send(me, Result(100 / job)), Ended);
            Io.println(Int.toString(job) <> ": " <> outcome());
            supervise(rest)
        }
    }

// The worker's answer, or how it ended. A worker that returned has sent its
// answer, so after its end the answer is taken too, whichever arrived first,
// and neither is left for the next worker; one that ended otherwise sent none.
fn outcome() : String receiving SupervisorMsg =
    receive {
        Ended(Down(reason = Returned)) ->
            receive {
                Result(value) -> Int.toString(value)
            }
      | Ended(Down(reason = Fault(cause))) ->
            "failed, " <> cause
      | Ended(Down(reason = reason)) ->
            "ended, " <> Io.show(reason)
    }

export fn main() : Unit receiving SupervisorMsg =
    supervise([4, 0, 5])
```

```console
$ ern run tasks.erc
4: 25
Tasks.supervise:9 faulted: division by zero
    erlang:'div'/2
    Tasks.supervise:9
0: failed, division by zero
5: 20
all jobs done
```

A process for each job is the restart: the job that faulted ends its own worker, and the next job starts with a fresh one. Of the program, only `supervise` prints, so what became of each job is said in one place; the second line, with the trace beneath it, is `ern run`'s report of the fault, on standard error. A worker reports by a message to its supervisor, which knows the job and decides what follows.

What must survive a fault lives in the process that does not fault: here the list of jobs is the watcher's. A long-lived process restarts in place instead, which §6.5 shows, and a group of them restarts together under the standard library's `Supervisor`, which §6.6 shows. A process that must not outlive another monitors it and returns when it dies.

### 6.5 A service

A *service* is a process the program reaches by name. The name is a top-level binding whose value is the process's address, `counter` below, so a module sends to the process by writing its name, and `export` says which modules may. It is no registry on the node: the name is resolved by the compiler, in the module's scope, like any other name, and is typed by its declaration. It needs none, because `restarting` keeps the process's address across its faults: the binding is made once and stays good, where a registry exists to find the new process behind an old name.

```ernest
export type CounterMsg = Add(amount : Int, reply : Reply(Int))

// The service: the program's counter, reached by this name.
export let counter : Address(CounterMsg) = start()

// A counter, restarted in place after a fault. A test calls it for a
// counter of its own.
export fn start() : Address(CounterMsg) =
    spawn(restarting(RestartLimit(restarts = 3, within = 5000), fn() = count(0)))

// The counter's loop, which faults on a negative amount.
fn count(total : Int) : Unit receiving CounterMsg =
    receive {
        Add(amount = amount, reply = reply) ->
            if amount < 0 then
                fault("a negative amount")
            else {
                answer(reply, total + amount);
                count(total + amount)
            }
    }

export fn main() : Unit = {
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
    Counter.count:16
None
Some(3)
```

`counter` is evaluated before `main` runs, in the entry process, like every top-level `let` (§2.2). An initializer may spawn, send and call, and takes no message, so a service's `let` starts its process and nothing waits.

`restarting(RestartLimit(restarts = 3, within = 5000), f)` is a function that runs `f`, and runs it again after a fault, in the same process, with the same address. The new run begins with an empty mailbox, and what the process asked the runtime for, an alarm, a monitor, a subscription, is canceled (report §6.9). Whoever holds the address keeps it, so nothing is handed out again after a restart. What the loop held is gone: the count starts at zero again, as `Some(3)` shows.

After three restarts within five seconds, the next fault ends the process (report §6.9); `restarting(Unlimited, f)` runs `f` again after every fault. The binding then names an ended process for the rest of the run, an `Address.call` to it answering `None` at once, and the program goes on unless a process that monitors the service acts on its end, by ending the program or by starting a new service. A restart is not an end: no `monitor` hears of it, and the process's `Down` comes only when it ends for good; a service monitor hears of it, as the end of this section shows.

A client is not told of a restart, and a call waiting at it ends at once: `Address.call` answers `None`, as the call waiting when the counter faulted does here, and `Address.callForever` would fault the caller with the same cause, `a negative amount`, which the caller's line follows with `, the fault of the callee Counter.start:9` (report §6.6). A caller that must outlive a service's faults calls with a limit. The second line, with the trace beneath it, is `ern run`'s report of the fault, on standard error (§6.3).

`fault` is the fault a program raises when it finds a case it will not handle. The path that calls it does not answer `reply`: the fault ends the counter's process, and the call waiting on it ends at once. `start` is exported beside the binding so that a test can start a counter of its own instead of sharing the program's.

A process that keeps something for another, a lease it lent or a lock it granted, must hear of the other's restart, since the new run holds nothing of the old one. `monitorService(process, wrap)` is a *service monitor*: a monitor that is told of each restart too, with the reason `Restarted`, and stands until the process ends or its node is lost (§8.2), each of which it is told of as `monitor` is (report §6.9):

```ernest
type MainMsg = Watched(Down)

type HolderMsg = Hold(lease : Int) | Use(lease : Int)

// A holder of leases, restarted in place, which faults on a lease it does
// not hold.
fn hold(leases : List(Int)) : Unit receiving HolderMsg =
    receive {
        Hold(lease = lease) ->
            hold(lease :: leases)
      | Use(lease = lease) ->
            if List.contains(leases, lease) then hold(leases) else fault("no such lease")
    }

// What the holder was lent, taken back when the service monitor tells of
// a restart, since the new run holds none of it, or of the end.
fn takeBack(lent : List(Int)) : Unit receiving MainMsg =
    receive {
        Watched(Down(reason = reason)) ->
            Io.println(Io.show(reason) <> ", taken back: " <> Io.show(lent))
    }

export fn main() : Unit receiving MainMsg = {
    let holder = spawn(restarting(Unlimited, fn() = hold([])));
    monitorService(Process.fromAddress(holder), Watched);
    send(holder, Hold(lease = 1));
    send(holder, Hold(lease = 2));
    send(holder, Use(lease = 3));
    takeBack([1, 2]);
    kill(holder);
    takeBack([])
}
```

```console
$ ern run lease.erc
Lease.main:24 faulted, restarted: no such lease
    Lease.hold:12
Restarted, taken back: [1, 2]
Killed, taken back: []
```

`main` lends the holder two leases and asks it to use a third, which faults it. The service monitor tells `main` of the restart, and `main` takes back what the old run held. The monitor stands, so the `kill` is told too; a `monitor` in its place would have told only the `Killed`.

The `Restarted` reaches the watcher before anything the new run sends: the restart waits until each service monitor's wrap has placed its message, so a wrap that does not finish holds the restart up (report §6.9).

### 6.6 A supervisor

`restarting` restarts one process. A *supervisor* restarts a group of processes, its children, together when one of them faults, and gives up when they fault too often. The standard library's `Supervisor` is one (report Appendix E.22). The program spawns the supervisor and each child, usually as service bindings:

```ernest
// pair.ern
type CounterMsg = Add(amount : Int, reply : Reply(Int))

let group : Address(Supervisor.GroupMsg) =
    spawn(Supervisor.group(Supervisor.OneForAll, RestartLimit(restarts = 3, within = 5000)))

let visits : Address(CounterMsg) = spawn(Supervisor.child(group, fn() = count(0)))

let sales : Address(CounterMsg) = spawn(Supervisor.child(group, fn() = count(0)))

fn count(total : Int) : Unit receiving CounterMsg =
    receive {
        Add(amount = amount, reply = reply) ->
            if amount < 0 then
                fault("a negative amount")
            else {
                answer(reply, total + amount);
                count(total + amount)
            }
    }

fn add(counter : Address(CounterMsg), amount : Int) : Optional(Int) =
    Address.call(counter, fn(reply) = Add(amount = amount, reply = reply), 1000)

export fn main() : Unit = {
    Io.println(Io.show(add(visits, 2)) <> " " <> Io.show(add(sales, 5)));
    Io.println(Io.show(add(visits, -1)));
    Io.println(Io.show(add(visits, 1)) <> " " <> Io.show(add(sales, 1)))
}
```

```console
$ ern run pair.erc
Some(2) Some(5)
Pair.visits:7 faulted, restarted: a negative amount
    Pair.count:15
None
Some(1) Some(1)
```

`Supervisor.group(strategy, limit)` is the function the supervisor runs, its mailbox type `Supervisor.GroupMsg`, which the module keeps abstract, and `Supervisor.child(group, f)` the function a child runs. The program spawns each itself, as it spawns the function `restarting` gives (§6.5), so the fault line names the child's binding. A child joins the group before `f` runs, and waits until the supervisor has it. After a fault it runs `f` again in place, as under `restarting`.

**Which siblings restart.** The strategy says which siblings restart with the child that faulted:

- `OneForOne` restarts none.
- `OneForAll` restarts every other child, so `sales` starts from zero too.
- `RestForOne` restarts the children spawned after it, for services that use the ones before them. The order is the order of the `spawn`s, not of the joins, which the scheduler decides.

**How a sibling restarts.** A sibling runs on until it next waits, in a `receive` or for a call's answer, and restarts there, with the same address, as a fault restarts a process. A sibling that never waits is never restarted (report Appendix E.22). Its restart is not a fault, so `ern run` reports only the fault of `visits`. The child that faulted waits meanwhile, and runs again only once each sibling has restarted, so a sibling busy in a long computation keeps it down, and a call to it answers `None` until every sibling has reached a wait.

**What a caller sees.** A call waiting on a sibling as it restarts ends: `Address.call` answers `None`, and `Address.callForever` faults with `callee was restarted` (report §6.6). So for a moment after a fault, a call to a sibling may be answered from its old state, end, or be answered from its new one.

A call to the child that faulted, made after its fault, is answered by the group restarted whole (report Appendix E.22): `add(visits, 1)` is, and `sales` has restarted before `main` asks it. A request that reaches the child before its fault, behind the message that faults it, is lost with the mailbox the restart empties, and its call answers `None`. A restart keeps the address and loses the state, so a client that relies on a service's state after a fault takes the state as lost and asks again.

**The limit.** The limit is the group's. When its children have faulted `restarts` times within `within` milliseconds, the next fault makes the supervisor give up: it faults, with `supervisor restart limit reached`.

**A tree of groups.** A supervisor is a child like any other, `spawn(Supervisor.child(parent, Supervisor.group(...)))`, so groups form a tree. A supervisor under a parent restarts in place when it gives up, or when its parent restarts it with a sibling, and asks each of its children to restart; every binding keeps its address, and the fault is the parent's to count. A supervisor at the root that gives up dies. A supervisor and its children run on one node; between nodes, a process watches another with `monitor` (§8).

**Stopping a group.** When a supervisor dies, given up, killed, or of a defect of its own, its children are killed after it, the last spawned first, each once the one before has ended; so `kill(group)` stops a group. A killed process runs nothing more, so a child that must finish its work, a file to flush, is sent a message of its own protocol first.

**Who is in a group.** A child that returns or is killed leaves the group, and a child may join at any time, so one supervisor also holds the children a program starts while it runs, one per connection.

### 6.7 Exercise

Given:

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
export fn main() : Unit =
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

**The file's path is its namespace.** A file at `a/b/c.ern` under the source root declares the namespace `A.B.C`: each directory and the file name is one or more lowercase words joined by `_`, and the namespace capitalizes each word and drops the `_`, `ordered_set.ern` for `OrderedSet`. A directory adds a namespace segment: `http/parser.ern` is `Http.Parser`, a module apart from `http_parser.ern`'s `HttpParser`.

The source root is `--source-root dir`; without it, the directory `ern build` is given, or for a single file the working directory. A module may not take a namespace the prelude or the standard library has, so `io.ern` at the root is refused (report §4.2, report §11.1).

**Declarations use local names.** In `net/http.ern`, `export fn parse(...)` declares `parse`, which the code outside reaches as `Net.Http.parse`, and the code inside by its plain name (report §4.2).

**`export` marks the boundary.** A declaration with `export` is visible from other modules, and one without is the module's own. There is no `import` and no export list. The constructors of an exported type are exported with it; an abstract type's constructors are visible only in its own module (§7.2). An exported declaration's type, and the fields of an exported type that is not abstract, may name only exported types. A function's mailbox type is exempt, so an exported `main` may receive a private message type (report §4.2).

**A module's own name hides the prelude's.** A module may declare its own `Unknown`, which then means its own throughout the module; `Prelude.Unknown` still names the prelude's (report §4.2).

**Testing a module.** A test is a top-level `let` of the type `Test.Case(m)`, a name and a function returning `Test.Passed` or `Test.Failed(text)`, which runs in a process whose mailbox type is `m` (report Appendix E.24). `Test.equal(actual, expected)` is the comparison most tests make: `Test.Passed` where the two are equal, and otherwise `Test.Failed("expected 2, got 3")`, each value as `Io.show` writes it:

```ernest
/// The sum of two integers.
///
/// ```ernest
/// add(1, 2)
/// // => 3
/// ```
fn add(left : Int, right : Int) : Int =
    left + right

let addsTwo = Test.Case(name = "adds two", run = fn() = Test.equal(add(1, 1), 2))

type Reported = Reported(Int)

let answersBack = Test.Case(name = "a worker answers back", run = fn() = {
    let me = self();
    let _ = spawn(fn() = send(me, Reported(add(1, 1))));
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
Checks.add example 1: passed
```

`ern test` runs every test of the module, one at a time in the order the module declares them, each in a process of its own, and prints each as it ends: passed, failed with its text, faulted with its cause, or killed.

It then runs the module's doc examples as cases (report §11.2). A doc example is an `ernest` block in a declaration's doc block, the `///` lines above it (below), and is named by the declaration, `Checks.add example 1`. One whose last line is `// => v`, alone on its line, passes where `Io.show` of its value is `v`; one without the line is reported `compiled` where it compiles. An exported declaration's example is compiled in a module of its own, as a caller's code is, so it writes the module's names as a caller writes them, `Checks.add(1, 2)`; a private declaration's is compiled inside the module, and writes them bare, as `add`'s does above.

`Test.faults(run, cause)` tests that a call faults: `Test.Passed` where `run` faults with `cause`, and otherwise `Test.Failed` naming what came instead, `expected the fault division by zero, got a return`. `run` runs in a process of its own, whose fault no job reports, `ern test`, `ern run` or the shell, since the test's answer carries it (report Appendix E.24).

A test's `run` is `() -> Test.Result receiving m`: it runs in a process whose mailbox type is `m`, as an entry point does (report §8.1), so it may spawn, send, call and receive. `addsTwo` receives nothing and leaves `m` open, and `ern test` runs it with `Never`; `answersBack` receives a `Reported`, so its type is `Test.Case(Reported)`, which nothing writes. A test left waiting with nothing to wake it is faulted with `deadlock` while the run goes on (report §11.2).

Given a directory, `ern test build` runs the tests of every module compiled under it, each module's name on a line before what it writes, and passes over a module that has neither tests nor examples.

**Documenting a module.** A `///` block, on lines of its own, documents the declaration on the line after it, and one first in the file, with a blank line after it, documents the module. The text is CommonMark; `ern doc` renders the module as a page, and the shell's `:doc` shows a declaration's part of it, or a module's head, rendered for the terminal. What a module's documentation contains is report Appendix E.0 shape rule 6, and [`docs/module_doc_template.md`](../docs/module_doc_template.md) shows it on an example module.

**Entry point.** `ern run main.erc` runs `export fn main`, and `--main` runs another exported function that takes no arguments and returns `Unit`. A module may export several entry points, and `--main` names the one to run, here `check` of `tools.ern`:

```console
$ ern run --main Tools.check build/tools.erc
```

### 7.2 Abstract types

An abstract type keeps its representation to its module: every definition in the module may name its constructor, and no other module can. A type's operations are functions of its module, so a stack is a module of its own, `stack.ern`, whose functions other modules call `Stack.push` and `Stack.pop`. Only the six operators `+`, `-`, `*`, `/`, `%` and `<>`, `compare` and `negate` are declared with the type's name before theirs, as report §4.8's `fn Distance.+` is.

```ernest
// stack.ern  (namespace Stack)
export abstract type Stack(a) = Stack(List(a))

export let empty = Stack([])

export fn push(Stack(items), item) =
    Stack(item :: items)

export fn pop(Stack(items)) =
    match items {
        [] -> None
      | item :: rest -> Some(#(item, Stack(rest)))
    }

export fn size(Stack(items)) =
    List.size(items)
```

Inside `stack.ern` the operations are `push` and the rest, and any definition may take a `Stack` apart, a private helper or a test included. Outside, they are `Stack.push` and the rest, the type is `Stack.Stack`, and `Stack.Stack([])` is an error: another module sees the type and the operations, never the constructor.

`empty` is a constant, a constructor applied to an empty list, so it has its value wherever its code is, on a bare node too (§2.2). A binding whose initializer computes, `let limit = 1024 * 1024` or `let index = Map.empty`, has its value only on a node that loaded the module: a spawn or a compute on a bare node whose function names it is not started there, and a module meant for such work makes such a value a function, `limit()` (§8.1).

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

Code is often written once for a kind of thing that has several representations: a set kept in a hash and a set kept in order, a sum over `Int` and over `Float`. Ernest has three forms for it, each for a need of its own:

| The need | The form |
|---|---|
| A type's own operation, in a function generic in the type | a *requirement*, `needs a.compare` |
| One algorithm over several representations | an *operations record* |
| Values of several representations in one list | a record of closures |

**A requirement.** A function generic in a type may need the type's own operation: its order, to find the largest of a list. It says so after its result type, `needs a.compare`, a *requirement* (report §4.9):

```ernest
// largest.ern  (namespace Largest)
fn largest(first : a, rest : List(a)) : a needs a.compare =
    List.foldLeft(rest, first, fn(best, x) = if x > best then x else best)

fn largestOf(list : List(a)) : Optional(a) needs a.compare =
    match list {
        [] -> None
      | first :: rest -> Some(largest(first, rest))
    }

fn sorted(list : List(a)) : List(a) needs a.compare =
    List.sort(list)

export fn main() : Unit = {
    Io.println(Int.toString(largest(3, [8, 5])));
    Io.println(largest("pear", ["fig", "apple"]));
    Io.println(Io.show(largestOf([1.5, 0.5])));
    Io.println(Io.show(sorted([3, 1, 2])))
}
```

```console
$ ern build largest.ern
$ ern run largest.erc
8
pear
Some(1.5)
[1, 2, 3]
```

In the body, an operator resolves to the member of whatever type `a` stands for, as it would on a known type: `x > best` in `largest` is `a.compare`, and `compare(x, best)` would answer its `Ordering`. The member's name, `a.compare`, stands in the requirement and in no expression. `List.sort` declares `needs a.compare` too, and the call in `sorted` writes nothing for it: `sorted`'s own requirement supplies it.

A call writes nothing for the requirement. `largest(3, [8, 5])` is `largest` with `Int.compare`, which the compiler supplies, since the element type is known there, and the next call is supplied `String.compare`. Where the element type is itself a type variable, the calling function declares the requirement too, as `largestOf` does for `largest`, and the member it was given goes along. Without the requirement the call is refused, naming what to add:

```ernest-rejected
fn largest(first : a, rest : List(a)) : a needs a.compare =
    List.foldLeft(rest, first, fn(best, x) = if x > best then x else best)

fn largestOf(list : List(a)) : Optional(a) =
    match list {
        [] -> None
      | first :: rest -> Some(largest(first, rest))
    }
```

```console
$ ern build generic.ern
generic.ern:7:31: largest needs a.compare, which largestOf does not declare
6 |         [] -> None
7 |       | first :: rest -> Some(largest(first, rest))
  |                               ^^^^^^^
  | = help: add `needs a.compare` to largestOf's signature
```

A requirement is always written: the compiler infers none, and a body that uses `>` on an `a` without it is refused the same way. Equality is no requirement but the runtime's own on every type that has it (§2.5), so it is inferred and marked, `fn same(a, b) = a == b` being `(a=, a=) -> Bool` (§2.9).

A requirement names `compare`, `negate`, one of the six operators of §7.2, or `show`, and nothing else. Several are separated by commas, `needs a.+, a.compare`. A sum is written once for `Int`, for `Float`, and for any type that declares a `+`:

```ernest
// members.ern  (namespace Members)
type Date = Date(year : Int, month : Int, day : Int) derives compare

fn sum(first : a, rest : List(a)) : a needs a.+ =
    List.foldLeft(rest, first, fn(total, x) = total + x)

fn shown(list : List(a)) : Unit needs a.show =
    List.forEach(list, fn(x) = Io.println(Io.show(x)))

export fn main() : Unit = {
    Io.println(Int.toString(sum(1, [2, 3])));
    Io.println(Float.toString(sum(0.5, [1.5])));
    let dates = [Date(year = 2026, month = 10, day = 2), Date(year = 2025, month = 1, day = 1)];
    shown(List.sort(dates))
}
```

```console
$ ern build members.ern
$ ern run members.erc
6
2.0
Date(year = 2025, month = 1, day = 1)
Date(year = 2026, month = 10, day = 2)
```

`Date` gets its order from its declaration. `derives compare` gives the type the member `compare`, which orders two values by constructor in declaration order and then by field from left to right, each by its type's `compare`, so the dates print by year, then month, then day. A field whose type has no `compare`, a `Bool`, is refused at the declaration (report §3.5).

`shown` declares `needs a.show`. `show` is no member a type declares: every type can be shown. `Io.show` writes a value by its type, which a function generic in `a` does not know, so the function declares `needs a.show`, and each call supplies it for its type. `Io.show`'s own type says so, `(a) -> String needs a.show`, and under the requirement it writes `a` and any type built from it, `List(a)` as well (report §9.4, Appendix E.1).

**A module built on a requirement.** The standard library's `OrderedSet` keeps a set's elements in the order of their type's `compare`, and each of its functions that needs the order declares `needs a.compare`. A program uses it without naming an order:

```ernest
// sets.ern  (namespace Sets)
fn unique(list : List(a)) : List(a) needs a.compare =
    OrderedSet.toList(OrderedSet.fromList(list))

export fn main() : Unit = {
    let small = OrderedSet.fromList([3, 1, 3]);
    let both = OrderedSet.union(small, OrderedSet.fromList([2]));
    Io.println(Io.show(OrderedSet.toList(both)));
    Io.println(Io.show(OrderedSet.min(both)));
    Io.println(Bool.toString(both == OrderedSet.fromList([2, 3, 1])));
    let doubled = OrderedSet.map(both, fn(n) = n * 2);
    Io.println(Bool.toString(OrderedSet.contains(doubled, 6)));
    Io.println(Io.show(unique(["b", "a", "b"])));
    let ages = OrderedMap.fromList([#("bo", 42), #("al", 7)]);
    Io.println(Io.show(OrderedMap.keys(ages)))
}
```

```console
$ ern build sets.ern
$ ern run sets.erc
[1, 2, 3]
Some(1)
true
true
["a", "b"]
["al", "bo"]
```

`OrderedSet.fromList([3, 1, 3])` is `fromList` with `Int.compare`, and `unique`, generic in its element, declares the requirement and passes it on. `map` needs its result's order, `b.compare`, since the set it makes is in the results' order; `size`, `toList`, `filter` and the rest need none.

The set is a sorted list and nothing else, so it is data: two sets built in different orders are `==`, a set keys a `Map`, and a set is sent to another node. `put`, `contains` and `remove` are linear in the set's size, as a sorted list is, and `fromList` is a sort (report Appendix E.25). `OrderedMap` is written the same way over its keys, filled and read as a `Map` is (report Appendix E.26).

An order belongs to a type, since a type has one `compare`. A second order on `Int` is a second type with a `compare` of its own, and two sets in two orders are of two types, which cannot meet:

```ernest-rejected
type Descending = Descending(Int)

fn Descending.compare(Descending(left) : Descending, Descending(right) : Descending) : Ordering =
    compare(right, left)

export fn main() : Unit = {
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
  |                                             ---------------- OrderedSet.union : (OrderedSet.Set(a), OrderedSet.Set(a)) -> OrderedSet.Set(a) needs a.compare
  |                                                                  ^^^^
  | = help: the types differ at Int and Descending
```

**An operations record.** A requirement names a type's members and nothing else. `fromList` and `intersection` are a module's functions, not members, so an algorithm written once over two representations of a set takes them another way: as a record, which the program declares.

```ernest
// common.ern  (namespace Common)
type Operations(s, a) =
    Operations(fromList : (List(a)) -> s, intersection : (s, s) -> s, toList : (s) -> List(a))

let hashed : Operations(Set(Int), Int) = Operations(..Set)

let ordered : Operations(OrderedSet.Set(Int), Int) = Operations(..OrderedSet)

fn common(list : List(a), other : List(a), operations : Operations(s, a)) : List(a) =
    operations.toList(operations.intersection(operations.fromList(list),
                                              operations.fromList(other)))

export fn main() : Unit = {
    Io.println(Io.show(common([4, 2, 3], [3, 4, 5], ordered)));
    Io.println(Int.toString(List.size(common([4, 2, 3], [3, 4, 5], hashed))))
}
```

```console
$ ern build common.ern
$ ern run common.erc
[3, 4]
2
```

`Operations` is an *operations record*: the record of the operations `common` uses, each field's type over the record's parameters, `s` the representation and `a` the element. The parameter `s` keeps one call to one representation. `intersection : (s, s) -> s` takes two sets of it and gives a third, so `common` can pass what `fromList` made to `intersection` and its result to `toList`, and cannot mix a hashed set with an ordered one.

`Operations(..Set)` fills the record from the namespace `Set`: each field not given beside the namespace is the declaration of its name there, at the field's type. `Operations(..OrderedSet)` fills it from `OrderedSet`, where `fromList`'s requirement is met with `Int.compare`, since the record's type fixes `a`. A field the namespace lacks, or one of another type, is refused where the record is built (report §5.6).

`common` is an ordinary function over the record, and `operations.fromList` a field read, which the parameter's annotation makes possible (§3.3). It is written once and called with either record, so the caller chooses the representation at each call. The standard library declares no such record: a program declares the one it needs, three fields here, and reaches what a representation has beyond it, `OrderedSet.min`, through its module.

**A record of closures.** An operations record keeps the representations apart: a list of sets is a list of one representation. Where values of different representations are to meet in one list or one message, a record of a second kind hides the representation. Its fields are functions that close over the value:

```ernest
// shapes.ern  (namespace Shapes)
type Shape = Shape(name : String, area : () -> Float)

fn circle(radius : Float) : Shape =
    Shape(name = "circle", area = fn() = Float.pi * radius * radius)

fn square(side : Float) : Shape =
    Shape(name = "square", area = fn() = side * side)

export fn main() : Unit =
    List.forEach([circle(1.0), square(2.0)],
                 fn(shape) = Io.println(shape.name <> ": " <> Float.toString(shape.area())))
```

```console
$ ern build shapes.ern
$ ern run shapes.erc
circle: 3.141592653589793
square: 4.0
```

A circle and a square are both a `Shape`, since the radius and the side are not in the type: each is captured by the function in its record. The list holds both, and `shape.area()` runs the function the value carries.

The same form serves the two sets, where an operation answers another such record: `put` closes over one set and answers a `Bag` over the next.

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

export fn main() : Unit =
    List.forEach([ordered(OrderedSet.empty), hashed(Set.empty)], fn(bag) = {
        let filled = List.foldLeft([2, 1, 2], bag, fn(acc, x) = acc.put(x));
        Io.println(Io.show(#(List.size(filled.toList()), filled.contains(1))))
    })
```

```console
$ ern build bag.ern
$ ern run bag.erc
#(2, true)
#(2, true)
```

`ordered` declares the requirement, and the lambdas it makes close over the member it was given with the set.

A record of closures gives up what an operations record keeps:

- The representation is hidden, so nothing can take two bags apart to unite them. An operation over two of them needs a design of its own, as one that goes through `toList`.
- The value holds functions, so it has no `==` (§2.5) and does not go to another node (§8.4).

Reach for an operations record where code written once must keep the representation's type, and for a record of closures where values of different representations meet.

A service with state needs none of the three: two processes of different representations take one message type, and the caller holds an `Address(M)` (§4).

**For the curious: how `OrderedSet` is written.** The module is Ernest over `List`, and its source shows a requirement at work in a library. Here are the parts of `src/stdlib/ordered_set.ern` that carry it, with their doc blocks left out; the rest of the module is in that file of the repository, which an installation does not ship, and `:doc OrderedSet` lists it:

```ernest-fragment
// src/stdlib/ordered_set.ern  (namespace OrderedSet), in part, its doc blocks left out
export abstract type Set(a) = Set(List(a))

export fn fromList(list : List(a)) : Set(a) needs a.compare =
    Set(firstOfEach(List.sort(list)))

// The first of each run the order calls `Equal` in a sorted list. The sort
// is stable, so the list's earlier occurrence comes first and is the one
// kept, as `put` keeps the element already there.
fn firstOfEach(sorted : List(a)) : List(a) needs a.compare =
    match sorted {
        first :: second :: rest ->
            if compare(first, second) == Equal then
                firstOfEach(first :: rest)
            else
                first :: firstOfEach(second :: rest)
      | _ ->
            sorted
    }

export fn contains(Set(list) : Set(a), element : a) : Bool needs a.compare =
    has(list, element)

fn has(list : List(a), element : a) : Bool needs a.compare =
    match list {
        [] ->
            false
      | head :: rest ->
            match compare(element, head) {
                Less -> false
              | Equal -> true
              | Greater -> has(rest, element)
            }
    }

export fn map(Set(list) : Set(a), f : (a) -> b receiving e) : Set(b) receiving e needs b.compare =
    fromList(List.map(list, f))
```

`fromList` declares the requirement, which `List.sort` declares too and is supplied from it. `firstOfEach` and `has` are helpers generic in the element, so each declares the requirement too, which `compare` reaches in their bodies, and the member goes along from the exported function that calls it. `map` declares `needs b.compare`, the order of the set it builds.

### 7.4 Exercises

**(a)** Can a private helper in `stack.ern` match `Stack(items)`? And which may `main.ern` write: `Stack.Stack([1])`, or `Stack.push(Stack.empty, 1)`?

**(b)** §7.3 has two records of sets, `hashed` and `ordered` in `common.ern`, and two bags, `hashed(Set.empty)` and `ordered(OrderedSet.empty)` in `bag.ern`. Which pair can stand in one list, and why?

**(c)** With `sorted` of §7.3, write `firstTwo`, which answers the two smallest elements of a list. What does its signature declare, and what does the call `firstTwo([3, 1, 2])` write for the order?

## 8. Cross boundaries

A program reaches outside its node's Ernest code in three ways: to peers over the network, to foreign code on the same node, and by bytes over TCP to any host (§8.6, §8.7).

A *node* is a program started with `--config-dir`, and its *peers* are the nodes its `ernest.conf` lists (report §8.3). `ern config` makes the directory once: `ernest.conf` with the node's `listen` address and its public key, no peer and no service yet, and the private key and a certificate beside it.

A peer has a name, which the program uses, a public key and a network address. A peer on the same machine is added by `ern config --peer-dir`, which reads all three from the peer's directory; one on another machine by editing the file, with the key `ern config` printed on the peer's machine (report §11.3). Under `services`, each service's name lists the peers that may offer it, in the order a *find* asks them (report §8.7, Appendix C). A peer offers a service by holding a process under its name for peers to find, and a find is the lookup of a service by its name (§8.2).

Two nodes connect when the first operation needs it, over TLS, each accepting the other by its listed key alone, and only where both stand on one *floor*, one minor release of `ern`, any patch, on one major release of OTP, the Erlang release Ernest runs on; their builds may differ (§8.2). What a node says on its standard error is report §12.5's, and `ern reload` and `ern stop` are §9.2's; this chapter teaches what a program writes.

Every example here runs on a program that is no node too: without a configuration a program has no peers, and `Peer.find`, `Peer.spawn` and `Peer.compute` answer `Left(Io.NotListed)`.

### 8.1 Work on a peer

Work runs on a peer by the peer's name. `Peer.computeAt(name, f, ms)` runs `f` in a process started on the peer named `name`, and answers its value within `ms` milliseconds, or an `Io.Error` that says why not; the program names the peer, and the runtime chooses no node for it (report §6.7, §8.7, Appendix E.27):

```ernest
// square.ern
fn heavy(a : Int, b : Int) : Int =
    a * a + b * b

export fn main() : Unit =
    match Peer.computeAt("foo", fn() = heavy(3, 4), 5000) {
        Right(value) -> Io.println("foo computed " <> Int.toString(value))
      | Left(error) -> Io.println("no foo: " <> Io.show(error))
    }
```

```console
$ ern run square.erc
no foo: NotListed
```

With a peer named `foo` in `ernest.conf`, it prints `foo computed 25`. Two nodes on one machine run here from one directory: `square.erc` on the node `a`, and `foo` a *bare node*, started from its configuration directory with no program, which holds nothing of `square`'s and is sent `heavy` by the compute (report §8.7). Both stand on one floor, the same `ern` under the same OTP.

A node reads every module of its load path at its start, its program's directory and every directory beneath it among it, and refuses to start where an `.erc` there holds a module of another namespace than its path gives, one built from another source root (the deployment guide's §5.1). What a peer must hold itself is the host's part, the Erlang modules a foreign declaration calls; Ernest definitions are sent to it (report §8.7). Each node has a configuration directory of its own, and each lists the other:

```console
$ ern config --config-dir a
-----BEGIN PUBLIC KEY-----
MCowBQYDK2VwAyEAxPrYwmRdoys5yu9UJVah/ssQO8AeM8Sz8XSW+1BQOVg=
-----END PUBLIC KEY-----
$ ern config --config-dir foo --listen 127.0.0.1:8655
-----BEGIN PUBLIC KEY-----
MCowBQYDK2VwAyEAbcsDUdMBCWTaHU5iYs2EHT4fDQzaUBer/dL+n5DPJrk=
-----END PUBLIC KEY-----
$ ern config --config-dir a --peer-dir foo
$ ern config --config-dir foo --peer-dir a
```

`a` listens on `0.0.0.0:8654`, as made, and `foo` on a port of its own, since two nodes on one machine cannot share one. `--peer-dir` reads the peer's directory: the peer's name is the directory's, its key is its certificate's, and its address is its `listen`, with `127.0.0.1` for `0.0.0.0`, since the peer is on this machine (report §11.3). `a/ernest.conf` then reads:

```json
{
  "listen": "0.0.0.0:8654",
  "public-key": "-----BEGIN PUBLIC KEY-----\nMCowBQYDK2VwAyEAxPrYwmRdoys5yu9UJVah/ssQO8AeM8Sz8XSW+1BQOVg=\n-----END PUBLIC KEY-----\n",
  "peers": [
    {
      "name": "foo",
      "network-address": "127.0.0.1:8655",
      "public-key": "-----BEGIN PUBLIC KEY-----\nMCowBQYDK2VwAyEAbcsDUdMBCWTaHU5iYs2EHT4fDQzaUBer/dL+n5DPJrk=\n-----END PUBLIC KEY-----\n"
    }
  ],
  "services": {}
}
```

`foo/ernest.conf` lists `a` the same way, at `127.0.0.1:8654`; the node whose operation first needs the other dials it, opens the connection to it, as the report's word is (Appendix F).

What `--peer-dir` does not write is written by hand: `services`, §8.2's, and a peer on another machine, its key the one `ern config` printed there, as one JSON string with its line breaks `\n` (the deployment guide's §2.1). One key listed under two names is refused, `two peers have one public-key, and two nodes with one key are one node`.

Start `foo` first, in a terminal of its own, with `ern run --config-dir foo`. A node says where it listens as it begins to, `listening on 127.0.0.1:8655`, and a compute that reaches `foo` before it listens answers `Left(Io.Unreachable)`. Each terminal shows its own node's lines: `foo`'s says `the peer a connected` as `a` dials it, and `the peer a ended` when `a`'s run ends. Then, in another:

```console
$ ern run --config-dir a square.erc
listening on 0.0.0.0:8654
the peer foo connected
foo computed 25
$ ern stop --config-dir foo
```

The compute takes with it the values the lambda captured, and nothing more. The peer is sent `heavy`, with every definition it reaches, before the process starts, and holds each by its *hash*, the digest of its definition by which nodes know code (report §8.7, *The exchange*, by which a spawn or a compute carries to a peer the definitions it lacks; the deployment guide's §4.1).

On the peer the function has the peer's system processes, so an `Io.println` in it prints there, and a top-level binding it names is the peer's, so a service binding names the peer's service. Its value crosses back at the type the compiler found where `compute` is written, which is known whole there and is bound to no node (§8.4).

A fault in `heavy` is the caller's, as if `heavy(3, 4)` had faulted here: the caller faults with its cause, unchanged, and this node reports the fault once, its line naming the peer after the cause, `, on the peer foo`, and beneath it the trace that crossed with it, followed by the caller's frame where the compute is written; the peer writes nothing of it (report §8.7, report §11.2).

Where the process ends on the peer before it answers, killed or with the peer's program, the compute answers `Left(Io.Other(text))`, `text` the process's reason; where the caller stops waiting, its time run out or its process ended, the process is killed there.

The compiler must see what the function captures, so the function a compute or a spawn on a peer runs is written where it can see it: a declaration's name, or, in the same definition, a lambda written at the compute or bound by a `let`, a local `fn`, or `restarting` applied to one of these. A function that came as a value, a parameter or a message, is refused (report §3.11).

The function runs on the peer once the peer holds it and what it reaches, which cross where the peer lacks them, and only where every top-level binding the function reaches has its value on the peer and every module a foreign declaration it reaches calls is there; otherwise the compute answers `Left(Io.NotLoaded)`, and the peer says on its standard error what it lacked. A binding the function does not reach keeps it from no peer, whatever its module holds (report §8.7, Appendix E.27).

So a value a spawned function needs from where it was written is a parameter, a local it captures, or a constant: a binding whose initializer is a constant, `let limit = 10` or `let empty = Stack([])`, has its value wherever its code is (§2.2), and any other binding is the node's own. The standard library's bindings have their values on every node, since every node holds the library from its start, so `Map.empty` is a `let`, where a program's own value that names it, `let index = Map.empty`, is a function when it is spawned with on a bare node, `index()`.

A `let` typed at the shell's prompt is a binding of the shell's node, which no peer has: after `let below = 2000`, `Peer.computeAt("foo", fn() = below + 1, 5000)` answers `Left(Io.NotLoaded)`, and `{ let n = below; Peer.computeAt("foo", fn() = n + 1, 5000) }` answers `Right(2001)`, the value crossing as a local the lambda captures (§9.3).

**Which peer.** A computation needs room more than a place, so `Peer.compute(f, ms)` names no peer: the node picks one, and runs `f` there as `Peer.computeAt` runs it on the peer named (report §8.7, Appendix E.27):

```ernest
// placed.ern
export fn computed(n : Int) : Either(Io.Error, Int) =
    match Peer.compute(fn() = heavy(n), 5000) {
        Left(Io.Unreachable) or Left(Io.NotListed) -> Right(heavy(n))
      | result -> result
    }

fn heavy(n : Int) : Int =
    n * n
```

The node picks by what its peers tell it. A node that lists peers tells each one it is connected to how busy it is every `utilization-interval` milliseconds its `ernest.conf` names, 5000 where it names none, and holds the last utilization each peer told it with the moment it came (report Appendix C, Appendix E.27). How busy is on one scale: 1.0 is every scheduler busy, below it room and above it work waiting. A scheduler is a thread of the host that runs processes. The node measures as its `"utilization"` entry says, and by its run queue where it says nothing, the processes running or ready to run with the one measuring left out.

`Peer.compute` draws two of the peers whose utilizations the node may use, at random, and takes the less busy, the first drawn where the two are equal. A *telling* is the message that carries a peer's utilization, and names the peer's interval. A utilization older than two of its peer's intervals is not used, and a peer's loss drops its utilization.

Where no peer has told a utilization the node may use, the compute answers `Left(Io.Unreachable)`, and where the node lists no peer, as a program that is no node lists none, `Left(Io.NotListed)`; at both, `placed.ern` runs the work here, `heavy(n)`: a node has no name for itself, and `compute` takes none. `Peer.utilization(name, ms)` asks one peer how busy it is now, where the node's table holds what each said last.

A rule of the program's own is a function over `Peer.utilizations()`, the utilizations the node holds, each peer's name, its utilization and the milliseconds since it came, in the configuration's order, a peer not heard from left out. The least busy of them all:

```ernest
// least.ern
export fn computed(n : Int) : Either(Io.Error, Int) =
    match List.minimumBy(Peer.utilizations(), fn(#(_, utilization, _)) = utilization) {
        Some(#(name, _, _)) -> Peer.computeAt(name, fn() = heavy(n), 5000)
      | None -> Right(heavy(n))
    }

fn heavy(n : Int) : Int =
    n * n
```

The rule takes the utilizations as the node holds them, one older than the pick would use among them, and names the same peer for every compute between two tellings, so a burst sent within one interval lands whole on the first peer the minimum finds. A rule that spreads a burst draws, as the pick does, or filters by the age the list gives.

Another rule is another function beside it; none is a line of `ernest.conf`. A process is placed where it is to live, by a deployment's decision, so `Peer.spawn` always names its peer.

**Many at once.** A compute is a call, and its caller waits for it. It is §4.4's `gathered` with a compute as each helper's work. Work spread over the peers at once is a process for each piece, which computes and sends its piece home, spawned monitored so that its fault comes home too (§6.4). `Placed.computed` is each helper's whole work, so a piece that finds no peer runs here:

```ernest
// gathered.ern
type Piece = Piece(n : Int, value : Either(Io.Error, Int))

type GatherMsg = Computed(Piece) | Ended(Down)

fn gathered(numbers : List(Int)) : List(Piece) receiving GatherMsg = {
    let me = self();
    List.forEach(numbers, fn(n) = {
        let _ =
            spawnMonitored(fn() = send(me, Computed(Piece(n = n, value = Placed.computed(n)))),
                           Ended);
        Unit
    });
    gather(List.size(numbers), 0, [])
}

// A helper that returned has sent its piece, and its Down keeps no order with
// that message, so the gather ends once every helper has ended and each one
// that returned has been heard from. owed counts the helpers that returned
// and whose piece has not come; it is below 0 while a piece is ahead of its end.
fn gather(running : Int, owed : Int, pieces : List(Piece)) : List(Piece) receiving GatherMsg =
    if running == 0 && owed == 0 then
        pieces
    else receive {
        Computed(piece) -> gather(running, owed - 1, piece :: pieces)
      | Ended(Down(reason = Returned)) -> gather(running - 1, owed + 1, pieces)
      | Ended(_) -> gather(running - 1, owed, pieces)
    }

export fn main() : Unit receiving GatherMsg =
    gathered([3, 1, 2])
        |> List.sortBy(fn(piece) = piece.n)
        |> List.forEach(fn(piece) =
                            Io.println(Int.toString(piece.n) <> ": " <> Io.show(piece.value)))
```

```console
$ ern run gathered.erc
1: Right(1)
2: Right(4)
3: Right(9)
```

The pieces arrive in the order their computes end, so each carries its number, and `main` sorts them. A helper whose compute faulted sends no piece: its number is missing from the list, and `ern run` reports the fault, as it reports every fault (§6.3).

In a burst the draw of two matters. Every piece reads the utilizations told before the burst began, so `least.ern`'s rule would send them all to one peer, where `Peer.compute` draws two peers at random for each piece and spreads them among three peers or more (report Appendix E.27). With two peers the draw takes both each time, so a burst within one telling goes to the one less busy at it.

A program that knows how busy it is better than its node's measure does, by a queue's depth or work it has promised, says so with `Peer.setUtilization`, a number at or above 0.0 on the same scale: from then on its node tells its peers that number, and answers it to a `Peer.utilization`, until the program sets it again or its run ends. A number below 0.0 faults the caller (report Appendix E.27).

**A result that comes later.** A program that is not to wait for the value spawns a process that computes it and sends it back, one message later:

```ernest
// later.ern
type Msg = Computed(Int)

fn heavy(n : Int) : Int =
    n * n

export fn main() : Unit receiving Msg = {
    let me = self();
    let _ = spawn(fn() = send(me, Computed(heavy(5))));
    Io.println("asked");
    receive {
        Computed(value) -> Io.println("computed " <> Int.toString(value))
    }
}
```

```console
$ ern run later.erc
asked
computed 25
```

On a peer the process is spawned there by `Peer.spawn(name, f, ms)`, which answers the new process's address within `ms` milliseconds, or the failure, and the result comes back as the same message:

```ernest
// sent.ern
type Msg = Computed(Int)

fn heavy(n : Int) : Int =
    n * n

export fn main() : Unit receiving Msg = {
    let me = self();
    match Peer.spawn("foo", fn() = send(me, Computed(heavy(5))), 5000) {
        Right(_) ->
            receive {
                Computed(value) -> Io.println("foo computed " <> Int.toString(value))
            }
      | Left(error) ->
            Io.println("no foo: " <> Io.show(error))
    }
}
```

```console
$ ern run sent.erc
no foo: NotListed
```

What the function captures, and where it runs, is as for a compute: `me` crosses, and still names this process. A process spawned so that it never receives needs no annotation: nothing fixes its mailbox type, which is then `Never` (§4.1).

A fault in it is the process's, not the caller's, so a caller that must know spawns with `Peer.spawnMonitored` and receives a `Down` (§5.2). One spawned `restarting` is watched through its restarts with `monitorService`, as §6.5's holder is (§8.2). Its `site` is empty for a process of another node; that node's standard error reports the fault with the site (report §6.9). Several computations run at once as several such processes, each sending its result back.

### 8.2 Services across nodes

On one node a service is a top-level binding that holds an address (§6.5). A peer cannot name your bindings, so a service that peers reach is offered as a `Peer.Service`, its name and its message type, declared where the type is:

```ernest
// counter.ern
export type Msg = Add(Int) | Get(reply : Reply(Int))

export let service : Peer.Service(Msg) = Peer.service("counter")
```

```ernest
// store.ern
type Msg = Request(Counter.Msg) | Terminating(Reply(Unit)) | HolderEnded(Down)

type Ended = Ended(Down)

let counter : Address(Msg) = spawn(fn() = {
    Os.termination(Terminating);
    serve()
})

// The counter offered as the service, each request wrapped in `Request`, and told of the
// program's end through `Os.termination` (*The end*, below),
// and counting on from the count kept. Where a process holds the service,
// the counter waits for its end, its requests waiting in its mailbox, and
// offers again, so that it reads the count the holder kept last.
fn serve() : Unit receiving Msg =
    match Peer.offer(Counter.service, adapted(self(), Request)) {
        Right(_) ->
            count(kept())
      | Left(holder) -> {
            monitor(holder, HolderEnded);
            receive {
                HolderEnded(_) -> serve()
              | Terminating(reply) -> answer(reply, Unit)
            }
        }
    }

fn count(total : Int) : Unit receiving Msg =
    receive {
        Request(Counter.Add(amount)) ->
            count(total + amount)
      | Request(Counter.Get(reply = reply)) -> {
            answer(reply, total);
            count(total)
        }
      | Terminating(reply) -> {
            match keep(total) {
                Right(_) -> Unit
              | Left(error) -> Io.printlnError("the count was not kept: " <> Io.show(error))
            };
            answer(reply, Unit)
        }
    }

// The count at the last end, read from the file `count`: 0 where there is
// none, at the first start, and a fault where it holds no number, since
// nothing of the store's wrote it.
fn kept() : Int =
    match Fs.read(Path("count"), 1000) {
        Right(bytes) ->
            match Optional.andThen(String.fromUtf8(bytes), String.toInt) {
                Some(total) -> total
              | None -> fault("the file count holds no number")
            }
      | Left(Io.NotFound) ->
            0
      | Left(error) ->
            fault("the file count cannot be read: " <> Io.show(error))
    }

// The count written beside the file `count` and renamed over it, so that
// the file holds the old count or the new, whole.
fn keep(total : Int) : Either(Io.Error, Unit) = {
    let _ <- Fs.write(Path("count.new"), String.toUtf8(Int.toString(total)), 1000);
    Fs.rename(Path("count.new"), Path("count"), 1000)
}

export fn main() : Unit receiving Ended = {
    monitor(Process.fromAddress(counter), Ended);
    receive {
        Ended(_) -> Unit
    }
}
```

```ernest
// desk.ern
export fn main() : Unit =
    match Peer.find(Counter.service, 5000) {
        Right(counter) -> {
            send(counter, Counter.Add(5));
            match Address.call(counter, fn(reply) = Counter.Get(reply = reply), 1000) {
                Some(total) -> Io.println("the counter is at " <> Int.toString(total))
              | None -> Io.println("no answer")
            }
        }
      | Left(error) ->
            Io.println("no store: " <> Io.show(error))
    }
```

```ernest
// board.ern
export fn main() : Unit = {
    let counter = Proxy.start(Counter.service, 5000);
    send(counter, Counter.Add(5));
    match Address.call(counter, fn(reply) = Counter.Get(reply = reply), 1000) {
        Some(total) -> Io.println("the counter is at " <> Int.toString(total))
      | None -> Io.println("no answer")
    }
}
```

```console
$ ern run desk.erc
no store: NotListed
```

On two nodes the desk finds the store. The store's directory is made with `ern config --config-dir store --listen 127.0.0.1:8655`, and the desk's with `ern config --config-dir desk`, its `listen` removed since it only dials; `--peer-dir` lists each in the other's file, and the desk's names the service, `"services": {"counter": ["store"]}`. The store runs in a terminal of its own:

```console
$ ern run --config-dir store store.erc
listening on 127.0.0.1:8655
the peer desk connected
the peer desk ended
the peer desk connected
the peer desk ended
the end waits for 1 subscriber: Store.counter:6
the subscriber Store.counter:6 answered
```

The desk and the board run in another, each as the node `desk`, and `ern stop` ends the store:

```console
$ ern run --config-dir desk desk.erc
the peer store connected
the counter is at 5
$ ern run --config-dir desk board.erc
the peer store connected
the counter is at 10
$ ern stop --config-dir store
```

`Peer.offer(service, address)` lets the store's peers find the counter as the service for as long as its process lives. The counter offers `adapted(self(), Request)`, an address of `Counter.Msg` whose messages arrive in its mailbox wrapped in `Request` (§5.5), so a peer sees the protocol alone and the counter's own type holds the end's message and a holder's `Down` beside it.

A service has one holder on a node: the offer answers `Right(Unit)` where it took the service, and `Left(holder)`, that process, where a living process holds it already, as the previous version's counter does after `:reload` (§9.3). The counter then monitors the holder, waits for its end with its requests left in its mailbox, and offers again; it reads what was kept only once it holds the service, so it reads what the holder wrote last. A `restarting` loop keeps its address and its offer through its restarts (report §6.9).

`Peer.find(service, ms)` asks the peers the desk's `ernest.conf` lists under `"counter"`, in that order, and answers the first address offered under the name at the service's message type; a peer out of reach, offering nothing, or offering the name at another type is passed over, and where none offers it the find answers the last failure met, or `Left(Io.Timeout)`. Where a service lives is the configuration's: `"services": {"counter": ["store"]}` on the desk, and no find names a node.

The address found is used as any other: `send`, `Address.call`, `monitor` and `kill` reach the store's process as they reach one here, nothing checks a message on arrival, since the find compared the service's type, and the address is as good on a third node it is sent to (report §8.4, §8.7).

`monitorService` reaches it too: a service monitor on a process of another node is told of each of its restarts, by the runtime's own frames, before anything the new run sends, and of its end and of a loss as `monitor` is (report §6.9, §8.7). [`examples/lease_broker.ern`](../examples/lease_broker.ern) runs its broker and its clients on two nodes so.

**A loss.** A connection breaks or a peer falls silent; a node that ends in order is no loss, a monitor on its processes gives `ProgramEnd`, and a `callForever` on one of them faults with `callee ended with its program`. A peer that fell silent is given up in 45 to 75 seconds, and one whose connection closed is given up at once (report §8.7, report §12.6).

Each node then ends what it held with the other and nothing else: every monitor on the peer's processes gives one `Down` with the reason `Unreachable` and an empty `site`, every call waiting on one of them answers `None`, and a `callForever` faults with `callee is unreachable`; what waited to be sent is dropped, and a later `send` dials again, and vanishes only where the dial fails. No other process of your own dies of it.

A restart of a process that a process of another node monitors or calls waits for that node's answer, at the latest until a loss or the peer's end (report §6.9, §8.7). A peer that falls silent so holds the restart up until it is given up, though the fault's line has said `restarted` at once.

The address outlives the loss: once the nodes connect again, which the next operation that needs it does, the same address reaches the same process, for as long as it lives and its node has not been started again. A monitor does not outlive it: a program that goes on watching calls `monitor`, or `monitorService`, again, on the process the `Down` named, and while the peer stays out of reach the new monitor answers `Unreachable` once the dial has failed.

`Unreachable` says the process may be alive, which a replacement would make two. Three rules keep that harmless: replace at `Unreachable` only work that may run twice; let a process spawned on a peer watch whoever it works for, and end when told `Unreachable`, which it is, since both nodes run the loss; and keep what must exist once on one named node, found there as a service, unavailable while that node is out of reach rather than started again elsewhere.

**Order.** What one process sends another arrives in the order it was sent, through whichever addresses, with one exception: a message to an adapted address made on another node is wrapped on that node, a step more, so a message sent straight after it to the target's own address can arrive first (report §6.5, §8.7). A protocol that must keep the order sends both through the same address.

**Two builds.** A service holds the hash of its message type beside its name, and the find asks each peer for what it offers under the name and compares the hash: a peer that offers `counter` at another type is passed over as one offering nothing is, and where every listed peer does, the find answers `Left(Io.OtherType)`. A store built with one constructor more in `Counter.Msg` is, to a desk of the earlier build, a service it cannot find, never one that reads its messages wrongly; the desk is rebuilt and started again.

Nodes of different builds connect, since the floor and not the build is what the handshake proves (report §8.7).

**The end.** `ern stop` is termination, as a service manager's stop is ([*Running Ernest*, section 1.5](deployment.md#15-under-a-service-manager)), and the counter itself is told of it: `Os.termination(Terminating)` subscribes the calling process, and at the end the runtime puts `Terminating(reply)` in its mailbox, waits until the reply is answered, and only then ends the program.

Told, the counter writes its total to `count.new` beside the kept file, renames it over `count`, answers, and ends; a rename replaces a file whole, so `count` holds the old count or the new, whatever cuts the write short (report Appendix E.17).

It reads `count` when it begins to count: no file is the first start, and 0, and a file that holds no number was written by nothing of the store's, so the counter faults with its cause rather than begin at 0 unsaid.

While the end waits every process runs on, and a peer still finds and calls the store. Nothing of the runtime's times the wait: a second `ern stop`, and the interrupt, end the program at once. `ern stop` itself returns once the node has ended, so a script that restarts a node writes `ern stop --config-dir foo && ern run --config-dir foo store.erc`.

The runtime says on standard error whom the end waits for, each subscriber by its spawn site, `the end waits for 1 subscriber: Store.counter:6`, and each as it answers, `the subscriber Store.counter:6 answered`, for a node and for a program that is none alike; where a second termination cuts the wait short, a second `ern stop` for a node, it names the subscribers that went unanswered (report §8.6, report §11.2, Appendix E.23).

What the program keeps is its own: the runtime holds no state and reads none back, a state of more parts is written in the form the program chooses, `Json` (report Appendix G.6) among them, and where a new build changes the shape, the program's own code reads the old one.

The store's `main` offers nothing and subscribes to nothing: it waits for its counter's end, so the store ends with a counter that faults. A program that is to keep running waits so for what it serves, or, where it waits on nothing else, for the end's own message; a `receive` with `after` alone would end it on time, not on purpose.

**A service that comes back.** When the store is stopped and started again the address the desk found is dead: it died with its process, and each start of a node is a number of its own in every address (report §8.7).

A client that is to go on calling the counter finds it again, or holds a *proxy* for the service from the library `Proxy` (report Appendix G.7), on the load path as every library of the toolchain's is (§9.1); a node reads every module of its load path at its start, so the board's node holds the library with no flag.

`Proxy.start(Counter.service, 5000)` in `board.ern` answers the proxy's address, an `Address(Counter.Msg)`. Behind it the proxy's process finds the service and forwards each message to the service found. When that service ends or its node is lost, the proxy finds it again at the next message, on whichever listed peer offers it, one find under way at a time. The proxy's process ends with the one that called `start`, so at the shell's prompt, where the caller is the input's process, a proxy is started in a process that lives on, as a socket is given to one (report §11.2).

A find that answers `Io.OtherType`, the service offered at another type, faults the process, and the fault's line names the service: that is what the board of an older build sees against a store whose protocol changed.

A message that comes while the service is away, and whose find fails, is lost as a message to an ended process is, so a call through the proxy's address answers `None` at its own time, which says nothing of whether the request ran (report §8.7), and a client asks again with a request that is harmless run twice.

The proxy is one process more on the message's way, so a message through it may pass one sent to the service directly; a program that is to monitor the service holds the address `Peer.find` gives.

### 8.3 Foreign types and functions

```ernest
// ets.ern
export foreign type Table(k=, v)

export foreign fn toList(table : Table(k, v)) : List(#(k, v)) =
    "ets:tab2list/1"
```

External callers write `Ets.Table` and `Ets.toList`. `foreign type` declares a type whose values only foreign functions make and read; Ernest has no constructor for it and cannot match it. `foreign fn` binds a name to a function on the other side, here Erlang's `ets:tab2list/1`, written as Erlang names a function: module, `:`, name, `/` and the number of arguments.

The `=` in `k=` says the keys need equality, since `ets` compares them: a table keyed by functions is a type error at its first operation, as a `Map` is (report §4.7). A `foreign fn` whose Erlang compares the values of a type variable marks the variable the same way, once, in its parameters, the one mark a program writes (§2.9): `foreign fn member(element : a=, list : List(a)) : Bool = "lists:member/2"` cannot be given a function.

The foreign side promises the declared types. A return value of the wrong shape faults the calling process when the function returns, the whole value checked, and a function in it when that function is called; an Erlang exception becomes a fault of the calling process; and a message of the wrong type that foreign code sends to an address the program gave it faults its receiver on delivery.

A `foreign fn` declared `receiving M` may deliver into the calling process's mailbox, and is trusted to deliver values of `M` alone; one declared without `receiving` is trusted neither to receive from that mailbox nor to deliver into it; and nothing checks either promise (report §4.7).

In the other direction, an Ernest process's end is an Erlang exit reason, `normal`, `{ern, fault, Cause, Trace}` for every fault, its cause and its trace as text, `{ern, killed}` and `{ern, program_end}` among them, which Erlang code that monitors it reads; report §12.2 lists them all.

A value foreign code made and Ernest does not inspect has the foreign type `Foreign.Term`; `Foreign.toInt` and the rest of Appendix E.12 read it, and `Foreign.atom(name)` is how an Erlang atom, the host's symbol, a name that is its own value, is passed (report §3.8, Appendix E.12).

### 8.4 Values bound to their node

A value crosses to another node as a value, and some cannot: a function, a foreign value, a `Foreign.Term` or an `Ets.Table` of §8.3, a *resource*, a thing of the host's a process opened and owns, a socket, a listener or a program `Os.start` started among them, and an address or a reply whose message type holds one of these. Their types are *bound* to the node, and nothing of a bound type leaves it.

Every address a program holds of another node's process came from a find, a spawn or a compute, or in a message, and the compiler refuses what would let a bound value cross: a service at a bound type, a spawn or a compute whose function captures a bound value, or one whose type is not known whole, a spawn whose mailbox type is bound, and a compute whose result type is bound or not known whole (report §3.11). So a message to another node is of a type that crosses, by construction, and nothing is checked at a `send`.

The listener below is a resource, so the lambda that captures it cannot be spawned on `alice`:

```ernest-rejected
export fn main() : Unit =
    match Tcp.listen("127.0.0.1", 7000) {
        Right(listener) -> {
            let _ = Peer.spawn("alice", fn() = serve(listener), 5000);
            Unit
        }
      | Left(error) ->
            Io.printlnError("cannot listen: " <> Io.show(error))
    }

fn serve(listener : Address(Tcp.ListenerMsg)) : Unit =
    match Tcp.accept(listener, 60000) {
        Right(socket) -> Tcp.close(socket)
      | Left(_) -> Unit
    }
```

```console
$ ern build bound.ern
bound.ern:4:54: the function Peer.spawn starts captures listener, whose type Address(Tcp.ListenerMsg) is bound to its node, since it holds the address of a listener
3 |         Right(listener) -> {
4 |             let _ = Peer.spawn("alice", fn() = serve(listener), 5000);
  |                                                      ^^^^^^^^
  | = help: compute what the process needs of listener before the spawn and capture that, or spawn on this node (report §3.11)
```

A program that needs such a thing on another node makes it there: the spawned function opens the listener on `alice`, with the address to bind captured in its place. State in a table crosses the same way, as the entries it is made of, from which the peer fills a table of its own (§8.5).

### 8.5 The shim pattern

A shim is a `foreign fn` over the host (report Appendix F). Where the host's function answers the type Ernest wants, the `foreign fn` is exported as it is, as `toList` is in §8.3. Where it does not, the `foreign fn` stays private and an exported Ernest function gives it the type Ernest wants. Erlang's `ets:lookup` returns a list, since a key matches no entry or one:

```ernest
// ets.ern
export foreign type Table(k=, v)

export fn get(table : Table(k, v), key : k) : Optional(v) =
    match rawLookup(table, key) {
        [#(_, value)] -> Some(value)
      | _ -> None
    }

foreign fn rawLookup(table : Table(k, v), key : k) : List(#(k, v)) =
    "ets:lookup/2"
```

`rawLookup` is the module's own, and callers use `Ets.get`.

Erlang's `{ok, V}` and `{error, R}` are not an Ernest `Either`, whose values are `{'Right', V}` and `{'Left', R}` (report §12.2).

A small Erlang helper returns the Ernest shape, with an integer for `Int` and a UTF-8 binary for `String`:

```erlang
-module(entries_helper).
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
// entries.ern (namespace Entries)
export foreign fn lookup(key : String) : Either(String, Int) =
    "entries_helper:lookup/1"

export fn main() : Unit =
    match lookup("answer") {
        Right(n) -> Io.println("found " <> Int.toString(n))
      | Left(reason) -> Io.println(reason)
    }
```

`ern` finds an Erlang module of your own as a `.beam` in a directory of its load path, which includes the root of the module it runs (report §11.2):

```console
$ ern build --build-root build entries.ern
$ erlc -o build entries_helper.erl
$ ern run build/entries.erc
found 42
```

A helper converts whatever its Erlang function returns to the declared type; Ernest does not. A `foreign fn` that takes a `Foreign.Term` is given one by `Foreign.term(value)`, which gives the value as an argument of its type crosses, so the type must be known where `Foreign.term` is written; `Foreign.atom(name)` makes an atom (report Appendix E.12).

`libs/ets` is such a library, report Appendix G.1, which Appendix D shows with a shorter documentation, and a program names it with no flag, since the toolchain's libraries are on the load path already (§9.1). A data format, a protocol and a pattern language each belong to a library outside the standard library (report Appendix E.0 rule 2), and report Appendix G lists the libraries there are.

### 8.6 Bitstrings

Building and parsing binary formats:

```ernest
fn frame(bodySize : Int, body : Bytes) : Bytes =
    <<bodySize:size(16)-big, body:bytes>>

fn parseFrame(bytes : Bytes) : Optional(#(Int, Bytes, Bytes)) =
    match bytes {
        <<bodySize:size(16)-big, body:size(bodySize)-bytes, rest:bytes>> ->
            Some(#(bodySize, body, rest))
      | _ ->
            None
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

A bitstring's total width is a whole number of bytes, and a value that does not fit its segment's width fails to match in a pattern and faults when it is built; report §5.11 has the rest of the rules.

A `Bytes` value is read with the `Bytes` module: `Bytes.size`, `Bytes.get` for one octet, `Bytes.slice`, and `Bytes.toList` for all of them. Text crosses with `String.toUtf8` and `String.fromUtf8`.

A stream of bytes, as `Tcp.read` answers it, may end inside a line, and inside a character, so lines are split off the bytes before they become text: `Bytes.split(bytes, <<10>>)` gives the lines, the last part being what has come of the next, as the program of §8.7 does. A frame is taken apart with a pattern, as `parseFrame` does, and not octet by octet with `Bytes.get`.

In a pattern, `size(bodySize)` may name a variable bound by an earlier segment. A `match` over bitstrings ends with a clause that takes anything, as `parseFrame` does, since the compiler does not decide whether bitstring patterns cover every `Bytes` value.

### 8.7 Sockets

A server is a listener and a process for each connection. `Tcp.listen(host, port)` answers a listener, and `Tcp.accept(listener, ms)` the next connection, a socket, or `Left(Io.Timeout)` when none came within `ms` milliseconds. `accept` has no form without a time, so the loop that accepts takes again after a timeout, and that turn is where it looks at anything else it must.

A socket is read by pulling. `Tcp.read(socket, ms)` answers what has arrived, at least one byte, `Left(Io.Timeout)` when nothing did, and `Left(Io.Closed)` once the connection has closed; nothing the socket receives comes to a mailbox. A process waits on one thing at a time, so one that must wait on its socket and on its mailbox gives the socket to a reader of its own, as §5.5 teaches.

One process may read a socket while another writes to it, and a read that waits answers `Left(Io.Closed)` when the socket is closed. A write returns once the socket has taken its bytes, and waits while the far end is behind taking them; it answers `Left(Io.Closed)` once the far end has gone.

Bytes arrive in pieces that need not end where a line ends, so what follows the last line feed waits for the next piece. A server that sends each line back, and says it is still there every ten seconds:

```ernest
type Session = Arrived(Optional(Bytes)) | Ticked(Int)

export fn main() : Unit =
    match Tcp.listen("127.0.0.1", 7000) {
        Right(listener) -> serve(listener)
      | Left(error) -> Io.printlnError("cannot listen: " <> Io.show(error))
    }

fn serve(listener : Address(Tcp.ListenerMsg)) : Unit =
    match Tcp.accept(listener, 60000) {
        Right(socket) -> {
            let talker = spawn(fn() = session(socket));
            Tcp.give(socket, Process.fromAddress(talker));
            serve(listener)
        }
      | Left(Io.Timeout) ->
            serve(listener)
      | Left(_) ->
            Unit
    }

// The session waits on its mailbox, and its reader on the socket.
fn session(socket : Address(Tcp.SocketMsg)) : Unit receiving Session = {
    let me = self();
    let _ = spawn(fn() = reader(socket, adapted(me, Arrived)));
    Clock.alarm(10000, Ticked);
    talk(socket, <<>>)
}

// What the socket gives, and None once the connection has gone, sent to an
// address that knows nothing of the session's mailbox.
fn reader(socket : Address(Tcp.SocketMsg), recipient : Address(Optional(Bytes))) : Unit =
    match Tcp.read(socket, 60000) {
        Right(bytes) -> {
            send(recipient, Some(bytes));
            reader(socket, recipient)
        }
      | Left(Io.Timeout) ->
            reader(socket, recipient)
      | Left(_) ->
            send(recipient, None)
    }

fn talk(socket : Address(Tcp.SocketMsg), rest : Bytes) : Unit receiving Session =
    receive {
        Arrived(Some(bytes)) -> {
            let parts = Bytes.split(rest <> bytes, <<10>>);
            List.forEach(List.dropLast(parts, 1), fn(line) = {
                let _ = Tcp.write(socket, line <> <<10>>, 5000);
                Unit
            });
            talk(socket, Optional.withDefault(List.last(parts), <<>>))
        }
      | Ticked(_) -> {
            let _ = Tcp.write(socket, String.toUtf8("still here\n"), 5000);
            Clock.alarm(10000, Ticked);
            talk(socket, rest)
        }
      | Arrived(None) ->
            Tcp.close(socket)
    }
```

A socket lives until `Tcp.close`, so the session closes it when its reader finds the connection gone. It is owned by the process that accepted it and is killed when its owner dies, so the loop that accepts gives each socket to its session, `Tcp.give`, and a session that faults takes its connection with it. Its process, and the listener's, are the program's: `Process.live` lists them, and a fault in one is reported under the function that opened it, `Tcp.listen` for the listener and `Tcp.accept` for a socket (report Appendix E.18).

### 8.8 Prediction exercise

A service `Registry`, with `type Msg = Register((Int) -> Int)` and a binding `registry` that holds its address, runs on the peer `foo`. A program on another node declares `let service : Peer.Service(Registry.Msg) = Peer.service("registry")`, means to find the service by it, and to send `Register(fn(x) = x + 1)`. What happens, and how does the function get to the service?

### 8.9 A service moved to new code

A process changes its code by a message of its own type that carries the new loop (§4.6). Across a program, the processes running a function are listed by `Code.running(f)`, a *form*, a call the compiler reads by a rule of its own: `f` names a top-level `fn`, and the list holds the addresses of the processes on this node whose stack holds a frame of `f` at that moment, among the innermost 64 frames the host keeps, so a process whose frame of `f` lies deeper is not listed (report §3.11, Appendix E.28). A tool moves every counter by sending each its `Upgrade`:

```ernest
type CounterMsg =
    Inc(Int)
  | Get(reply : Reply(Int))
  | Upgrade(migrate : (Int) -> Int, next : (Int) -> Unit receiving CounterMsg)

export fn main() : Unit = {
    let counter = spawn(fn() = count(0));
    send(counter, Inc(2));
    let _ = Address.call(counter, fn(reply) = Get(reply = reply), 1000);
    let old = Code.running(count);
    List.forEach(old, fn(process) = send(process, Upgrade(migrate = fn(n) = n, next = count2)));
    Io.println(Int.toString(List.size(old)) <> " moved");
    send(counter, Inc(3));
    Io.println("total: " <> Io.show(Address.call(counter, fn(reply) = Get(reply = reply), 1000)))
}

fn count(total : Int) : Unit receiving CounterMsg =
    receive {
        Inc(amount) ->
            count(total + amount)
      | Get(reply = reply) -> {
            answer(reply, total);
            count(total)
        }
      | Upgrade(migrate = migrate, next = next) ->
            next(migrate(total))
    }

fn count2(total : Int) : Unit receiving CounterMsg =
    receive {
        Inc(amount) -> {
            Io.println("inc " <> Int.toString(amount));
            count2(total + amount)
        }
      | Get(reply = reply) -> {
            answer(reply, total);
            count2(total)
        }
      | Upgrade(migrate = migrate, next = next) ->
            next(migrate(total))
    }
```

```console
$ ern run moved.erc
1 moved
inc 3
total: Some(5)
```

`count2` is the new loop, written beside the old. `Code.running(count)` lists the one counter, which waits in `count`'s `receive`; the call to `Get` before it makes sure the counter is there and not still starting. `migrate` carries the total from the old loop to the new. The order of the moves is the program's, and nothing of the runtime orders them.

The state's type is in the message type, `next : (Int) -> Unit receiving CounterMsg`, and a process keeps its mailbox type for life, so no `Upgrade` gives a running server a state of another type. A server whose state takes a new type is a new process of the new build, started from the old one's state. The old one gives its state up in answer to a request of its own protocol, or writes it to a file the new one reads, as §8.2's store keeps its count. The clients are then given the new process's address, or find it again as a service (§8.2).

On a peer, the tool cannot send the `Upgrade` from here, since a function value does not cross in a message (§8.4). It spawns on the peer a process that moves the peer's counters there, naming `count`, `count2` and `Upgrade` by their declarations; what the peer lacks, `count2` among it, crosses with the spawn (§8.1), so a fix reaches a node that never had it:

```ernest-fragment
let _ = Peer.spawn(node, fn() = List.forEach(Code.running(count),
                                            fn(process) = send(process, Upgrade(migrate = fn(n) = n, next = count2))),
                   5000)
```

A type that carries `Upgrade` holds a function, so it is bound to its node (§8.4). A process reached from another node, a service or one spawned on a peer, is offered through an adapted address (§5.5) of a type without it, and its upgrade is sent on its own node.

New code that is not in the program's build comes by `Code.load(path)`, which loads a compiled module and its *reach*, every definition its code names, directly or through others, on the running node and evaluates their bindings (report Appendix E.28). The example `examples/upgrade` is the whole of it, a counter's two builds, [`v1/counter.ern`](../examples/upgrade/v1/counter.ern) and [`v2/counter.ern`](../examples/upgrade/v2/counter.ern), and the second's tool moving the first's counters here and on every peer, and the deployment guide's §5.3 is the operator's side of the move.

## 9. Tools

One command, `ern`, whose first word is its job, and a mode for Emacs. `ern --help` lists the jobs and `ern build --help` a job's options; report §11 defines each.

### 9.1 `ern build`, `ern doc` and `ern format`

- `ern build hello.ern` compiles one module to `hello.erc`, beside it.
- `ern build --build-root build src` compiles every module under `src` in dependency order, mirroring the tree into `build`. A module is compiled again only when its source, an interface it depends on, another module's exported names and types, a definition of another module its code uses, any interface of the standard library, or the compiler has changed, and a `.erc` whose source is gone is removed.
- `--source-root dir` names the directory a module's namespace is read from, as §7.1 describes. `--load-path dir` adds compiled modules from outside the tree, such as a library of your own, and may be given more than once; the toolchain's libraries, report Appendix G, are on the load path already, after every directory it adds.
- `--emit-erl` writes the Erlang the module compiles to, for reading.
- `ern doc file.ern` writes the module's documentation to standard output as CommonMark. `ern doc src` writes a page for each module under `src` and an `index.md`, and for the standard library's root a `prelude.md` as well. `ern doc --man` renders a manual page instead, to standard output for one module and, for a directory, as a file beside each module, `Ernest.List.3ern`, which `man -l` shows, or `man Ernest.List` once it is installed where `man` looks.
- `ern format file.ern` lays the module out in the one layout report §11.6 states, and `ern format src` every module under `src`; only line breaks and spaces change, and every comment stays where it was. `ern format --check src` names each module not laid out and changes none; `ern format - < file.ern` writes the module as `ern format` would lay it out, to standard output, and changes nothing.

### 9.2 `ern run`, `ern test`, `ern shell` and `ern config`

- `ern run hello.erc` runs `main` and exits with status 0 when it returns. Every fault is printed on standard error as it happens, the spawn site and the cause, and a fault of the entry process makes the status 1 (§6.3); an entry process that is killed prints its site and `killed`, `Hello.main killed`, and the status is 1.

  A termination tells the processes that subscribed with `Os.termination` first (§8.2), and the runtime says on standard error that it waits for them and each as it answers; of the signal itself it prints nothing, and `ern run` ends by it, which a shell reports as 128 plus its number, 143 for a termination.
- `--main Module.name` runs another exported function of no arguments instead of `main`.
- `--load-path dir` adds compiled modules and Erlang `.beam` files the program needs (§8.5); the toolchain's libraries are on the load path already, after it.
- `--libs-dir dir` adds the Erlang applications under `dir`, each one's `ebin`: one flag where a program's foreign functions call several of them (report §11.2).
- `ern test module.erc` runs the module's tests, and `ern test dir` those of every module compiled under the directory; it exits with status 1 unless all passed (§7.1).
- `ern shell`, with or without a file, starts the shell (§1.2). A file's `main`, or the function `--main` names, runs beside it; a file without either is loaded with nothing running. `--source-root dir` names where `:load` finds a module's source, and `--config-dir dir` the configuration directory.
- `ern config --config-dir dir` makes the configuration a node with peers needs (§8) in the directory `dir`, listening where `--listen address:port` says; `ern config --config-dir dir --peer-dir other` lists the node of `other`, a directory of this machine, in `dir`'s (§8.1, report §11.3). `ern run --config-dir dir` runs the program as that node, and `ern reload --config-dir dir` and `ern stop --config-dir dir` have the running node read its configuration again, or end, `ern stop` returning once it has (report §11.2). `ern reload` reads the directory as the node would, and refuses a configuration the node would refuse, with status 1, before it signals.

### 9.3 The shell

§1.2 teaches inputs and the first commands. A command begins with `:`, and `:help` lists the commands, among them these: `:type` gives an expression's type and `:doc` a name's documentation, `:browse` lists a module's exports, `:load` puts a module in scope and `:reload` brings in what changed, `:bindings` and `:forget` manage what the session has declared, `:processes` and `:faults` show what runs and what has faulted, `:faults` a line for each fault without its trace, `:set` sets the depth and length values are printed to, the rows of the live region, `:set rows`, and timing, and `:output` sends what programs write to a terminal or a file.

An input runs in a process of its own, and at a terminal `C-c` ends it, which answers `Killed`, the session and its bindings kept (report §11.2).

A command may be shortened to a prefix of its name that begins no other, `:br` for `:browse`; `:b` begins `:bindings` too, and the shell says so.

**Completion.** `Tab` completes the word before the cursor, by its prefix or by its word starts, `S.pS` to `String.padStart`. After a value the session knows and a `.`, it completes the fields the value's type selects: `it.co` to `it.count`. It offers only what may stand there: a command after a leading `:` and what the command takes after it, a type after `:` in an annotation, a constructor in a pattern, a field inside a named constructor's parentheses.

A name completed alone is shown under the line with its type, and a second `Tab`, or one with nothing to add, lists the candidates there alphabetically, until the next key. With no word begun, as after `f(`, they are the session's names, the modules in scope, and the prelude's names other than its constructors, and every other name comes from its first letters. At the start of a row `Tab` indents instead.

`Shift-Tab` shows the declaration, the first sentence, and the version of the name at the cursor, `String.trim(text : String) : String` and what it does, and pressed again its documentation. Inside a call, on no documented name, it shows the callee's signature with the parameter at the cursor marked, and inside a constructor its fields.

**Loading and reloading.** `:load Words` puts the module `Words` in scope: it compiles `words.ern` under the source root, or takes a compiled form beside it or on the load path where one is as new as the source, and says which, `Words, compiled from words.ern` or `Words, from words.erc`. Nothing is loaded by being named, since a load evaluates the module's bindings, which may start processes; a name not in scope is answered with the `:load` that would put it there.

`:reload` compiles and loads again each loaded module whose source has changed, and with it each loaded module that uses one or whose code references a definition the change changes; where one of them does not compile, `:reload` loads none of them. A declaration of the session's that references what changed is compiled again too, and one that no longer compiles leaves scope while the reload goes on (report §11.2).

Both evaluate a module's top-level bindings, so a service it declares starts, and after a reload a service of the new version runs beside the old. One that offers a service, as §8.2's counter does, finds the service held by the old one, and waits on the old one's end to take it.

`kill(old)`, `old` the old one's address, which a binding made before the reload holds, ends the old one, as does a request of its protocol that makes it write what it keeps and end; the service moves to the new one at the old one's `Down`. What the old one counted since it last wrote is lost at a `kill`, which is why a service that must lose nothing writes at each change, or on request.

Processes running the old version go on running it, and a binding that holds a function of it keeps it: a reload unloads nothing. A binding made before a reload keeps the type it was checked under. Where the reload changed a type, the binding's type is the previous version's, which prints as `Counter$1.Msg`, and a message of the new version sent to it is a type error.

At a terminal the history is kept in `$HOME/.ernest/history`. When the shell starts it runs the inputs in `$HOME/.ernest/startup`, and then, if `--config-dir` names a configuration directory, those in its `startup`. A directory the shell merely starts in runs nothing of its own. A startup line may be a command, and one that fails is reported with its file and line.

### 9.4 Emacs

`editors/emacs/ernest-mode.el` highlights Ernest, indents it as `ern format` lays it out (report §11.6), and lets `M-x compile` with `ern build` jump to each error. [`editors/emacs/README.md`](../editors/emacs/README.md) says how to load it and what it leaves to your own configuration.

### 9.5 Running a program as a service

A program meant to keep running is left to the operating system's service manager, which starts it, restarts it and keeps what it writes; a service here is the operating system's, not §6.5's. The deployment guide, *Running Ernest*, teaches it in its [section 1.5](deployment.md#15-under-a-service-manager): a unit for systemd, the journal that keeps both streams, a stop, a reload and a restart, and the statuses a manager reads.

## 10. From Erlang

Ernest runs on the Erlang runtime, and a program in it is processes that send messages, as in Erlang. What an Erlang programmer knows mostly carries over. What differs is where the types reach.

**What carries over.**

- A process is a function that loops by a tail call and keeps its state in its arguments.
- `receive` selects a message by pattern and leaves the others in the mailbox. `after` gives a timeout in milliseconds.
- Messages from one sender arrive in the order they were sent.
- `monitor` delivers a message when a process dies, whatever the reason, and `monitorService` at each restart in place too (§6.5). `kill` ends a process from outside.
- `Address.call` is `gen_server:call` with a timeout, which answers `None` for a timeout and for the callee's end alike, and `Address.callForever` is the call without one, whose fault carries the callee's cause, or how else the callee ended (§4.4).
- The shell's `:load` is `c()` and `l()` as needed, compiling where the source is newer and loading the compiled form where it is not; nothing loads by being named, since loading a module runs its top-level bindings, which Erlang's modules have none of.
- Integers are exact and unbounded. On `Int`, `/` is Erlang's `div` and `%` is `rem`.
- A `foreign fn` calls an Erlang function directly, `"ets:lookup/2"`, and the values cross as report §12.2 lists: a constructor is a tagged tuple or an atom, and a `String` is a UTF-8 binary.

**What differs.**

- A mailbox has a type, so a message not of the mailbox's type is a compile error, not a message that sits in the mailbox forever; one of its type that no clause takes still sits there (§4.8).

- A function says in its type whether it receives, `receiving M`, and one that only sends says nothing (§3.4).
- There are no exceptions, no `catch`, and no `try`. A failure is a value, a message, or a fault (§6).
- There are no links and no exit signals, only monitors. A process that must die with another monitors it and returns.
- A `Down` comes from the runtime and not from the process that ended, so it may arrive before that process's last message to the watcher, where Erlang's `'DOWN'` comes after it (§5.2).
- There are no registered names on a node, and none are needed: a registry exists so that a name can be looked up again after the process behind it has died and been replaced, and `restarting` restarts a process in place, so its address stays good across its faults and a top-level binding can hold it for the program's life (§6.5).

  Addresses cannot be compared; the processes behind them can, `Process.fromAddress(a)`, which is a pid without the right to send.

  A process is reached through an address it was given, through a service binding, a top-level binding that holds one (§6.5), or, from another node, by the name it is offered under (§8.2).
- There are no atoms in the language: constructors are the tags. `Foreign.atom` makes one for a foreign call.
- There are no OTP behaviors. A server is a `receive` loop with `Reply`, restarted in place by `restarting` and reached through a service binding (§6.5). A supervision tree is the standard library's `Supervisor`, its children restarted in place so that their bindings keep their addresses (§6.6).
- A running program replaces its code by a message that carries the new function (§4.6). A new version of a module arrives by the shell's `:reload`, by `Code.load` (report Appendix E.28), or with a peer's spawn or compute (§8.1).
- A function value does not travel to another node in a message: the compiler refuses a service or a spawn that would take one; a spawn or a compute names its function by hash and carries to the peer the definitions it lacks (§8.1, §8.4).
- ETS is a library outside the standard library, `libs/ets`, since a table, owned by the process that made it, is state that every process of its node reads and writes.
- Nodes talk over Erlang's distribution, over TLS, with no port mapper, no mesh, and a rule that accepts a peer by its listed key; nodes of different builds connect where they run one minor release of `ern` on one major release of OTP, share what they share by hash, and a spawn or a compute carries to a peer the code it lacks (report §8.7). The reasons are the decisions log's, [`docs/log.md`](../docs/log.md).

## 11. The design

Report §0 gives five principles, and the rules of the guide follow from them.

1. **Least surprise decides.** A rule stays when the code it produces is what a reader who knows the rest of Ernest would write, and changes when it is not. That reader knows Ernest first, then types as Standard ML and OCaml have them and values and processes as Erlang has them, and no other language. The other four principles build the language, and this one audits the code they produce.
2. **One way, one job.** The language and the prelude have one way to do each thing: a record is a constructor with named fields, a server is a `receive` loop, a request is a `Reply`. A second spelling enters only where the first would nest, repeat a body, rebuild what a pattern holds, or pair each of a record's fields with the same name in one namespace, which is why `|>`, `<-`, `or`, `as` and the fill `C(..N)` exist and a shorthand that only shortens does not.
3. **Nothing invisible.** Control flow, communication, and failure show in the code or in the type, where they happen. A top-level binding is visible where its name appears at the use site, which is what makes a service (§6.5) one, or, in a fill, where its namespace appears and the record's type names its field. What the type decides is checked when the program is compiled and what the value decides faults when it runs; the compiler refuses what can have no effect and says nothing about what is merely unused, since there is no warning.
4. **Simple to parse.** Each construct is known by its first token, or by a later one a bounded way ahead, so a reader, like the parser, never has to look far.
5. **Small.** Few concepts, few primitives, few reserved words, counted in the language and not in the library; how many programs want a feature decides nothing; a feature costs a program that does not use it nothing; and a type carries what keeps messages safe, and nothing of what a function does.

§0 also says how Ernest stands to the runtime beneath it: a rule of the host is Ernest's only where the report states it as Ernest's own, and where the report is silent the runtime carries the host's rule without letting it show.

Principle 3 turns an omission into a statement. Exhaustiveness makes you say what every constructor does; `let _ = e` says a value is dropped on purpose; `export` says what crosses a module's boundary; `receiving` says a function receives from its process's mailbox; a qualified name says which module a name comes from.

Several of these tell the compiler nothing it could not work out for itself. What they add is that the decision is written down, where a reader meets it. It is programming on purpose, to borrow P. J. Plauger's phrase for designing deliberately rather than by accident; his subject is software design as a whole, broader than these rules (*Programming on Purpose: Essays on Software Design*, Prentice Hall, 1993).

## 12. Answers to the exercises

**§1.5.** (a) compiles, and gives `main` the type `() -> String`: `Io.debug` returns its argument, and inference takes the body's type. It sends to standard error's process, and a function that only sends receives nothing, so its type names no mailbox. `ern run` refuses it, since an entry point is a function of no arguments that returns `Unit` (§7.1). (b) is refused when it is built: `: Unit` declares the result, and the body is a `String`. With `Io.println`, as §1 writes it, both compile to `() -> Unit`, and `ern run` runs both. A `main` that waits a while, `receive { after 10 -> Unit }`, compiles as (a), and under `: Unit` needs `receiving Never` beside it (§4.1).

**§2.11.** (a) and (d) compile. Every constructor of `Shape` has `name`, with one type, so `s.name` reads it whichever built `s`.

(b) is refused: a `Dot` has no `radius`, and the compiler does not take the programmer's word that `s` is a `Circle`.

(c) is refused for the same reason: `..s` would copy `name` from a `Circle`, and `s` may be a `Dot`, so `..` is allowed only on a type with one constructor.

(d) asks which constructor built `s` and reads `radius` only in the clause where it is there; a pattern may leave out the fields it does not need.

**§3.7.** `map2`'s inferred type is `((a) -> b receiving e, a, a) -> #(b, b) receiving e`. The call binds `a = Int`, `b = Unit`, and `e` to none: the function only sends, so it receives nothing, and nor does the call.

**§4.8.** (a) No. The timeout only bounds the caller's wait. The recipient may still be processing the request or may answer later; the late answer is silently discarded but the work done on the recipient side is not undone.

(b) The counter answers: the relay sends the `Get` on with its reply, and the counter answers it as it answers any `Get`. With `answer(reply, 0)` after the `send` the program still compiles, and the reply is answered twice: the caller gets the answer that comes first, most likely the relay's `0`, since the counter answers only once it has taken the `Get`, and the other is dropped (§4.2). Nothing checks it, so a relay leaves the answer to the process it hands the reply to.

(c) The type gains `Reset(Reply(Int))`, and `count` the clause `Reset(reply) -> { answer(reply, total); count(0) }`. Without the clause the program still compiles. A `receive` takes the messages its clauses match and leaves the others in the mailbox (§4.3), so the `Reset` waits there for a clause that never comes: its caller's `Address.call` answers `None` at its deadline, and the counter goes on serving `Inc` and `Get`. A `match` must cover its type; a `receive` need not, and a protocol's new request is the programmer's to give a clause.

**§5.7.** (a) No. As written, pong prints before it answers, and `Io.println` returns once standard output has taken the line (report §12.1), so ping, which waits for the answer, cannot print its next line first. With the print below the `answer`, ping is free to print `ping 2` while pong has still to print `pong 3`. The two are two senders to standard output, and nothing orders them: the call did, and it has returned.

(b) `job 1: 1` or `job 1: the worker died`. The result comes from the worker and the `Down` from the runtime, two senders, so either may be received first (§5.1). Where the `Down` comes first, the wait answers `None` though the worker did its work, and the result arrives afterwards, for the next wait to pass over. The clause tells the two ends apart by the `Down`'s reason. A run seldom shows the second line, but the order is not promised, so the clause stays.

**§6.7.** `main` faults with the cause `first of an empty list`, and since it is the entry process the program ends and `ern run` prints the fault, `Main.main faulted: first of an empty list` for a `main` in `main.ern`. To give the case to the caller, return `Optional(Int)`, as `List.get` does: `[] -> None`.

**§7.4.** (a) Yes. The boundary of an abstract type is its module, so every definition in `stack.ern` may name the constructor, a helper or a test included. `main.ern` writes `Stack.push(Stack.empty, 1)`: another module sees the type and its operations, never the constructor, so `Stack.Stack([1])` is refused.

(b) The two bags. A list's elements have one type. `hashed` is an `Operations(Set(Int), Int)` and `ordered` an `Operations(OrderedSet.Set(Int), Int)`: an operations record keeps the representation in its type, so the two records are of two types, and a list of both is refused. Both bags are a `Bag(Int)`, since a record of closures hides the representation in its functions.

(c) `fn firstTwo(list : List(a)) : List(a) needs a.compare = List.take(sorted(list), 2)`. It calls `sorted` at its own type variable, so it declares the requirement and passes on the member it is given. The call writes nothing: the compiler supplies `Int.compare`.

**§8.8.** The build stops at the service: `Peer.service names a service at Registry.Msg, which is bound to its node, since it holds a function` (§8.4). The registry's address is bound too, so no process on `foo` can be given it. The spawn names the service's binding instead, which on `foo` is `foo`'s own: `Peer.spawn("foo", fn() = send(Registry.registry, Registry.Register(fn(x) = x + 1)), 5000)`. The function may be written in any module: the spawn carries to `foo` what it lacks, and runs since `Registry.registry` has its value there (§8.1, report §8.7).

## 13. Reading further

The programs under [`examples/`](../examples/README.md) are complete, each larger than a section can hold, and [`examples/README.md`](../examples/README.md) lists them by topic, with what each shows.

For the language rules themselves, the report is the authority: [`report/language.md`](../report/language.md), the language, [`report/toolchain.md`](../report/toolchain.md), the toolchain, and [`report/library.md`](../report/library.md), the standard library. Appendix F glosses every technical term.

Why Ernest looks as it does, and what was tried and rejected, is in [`docs/log.md`](../docs/log.md), a dated record of the design decisions.
