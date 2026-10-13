## But why?

Aren't there enough langauages built on BEAM already? Ernest argues no. Not because it brings an
unique feature to the table, but because of its synthesis:

- Any number of module revisions allowed. Not only old/new.
- Code transfers freely between nodes. No need modules to be available on all nodes.
- Non-meshed TLS based distribution.
- Hindley-Milner typing and typed mailboxes.
- Call-reply process semantics using linear/static type checking. No more handle_call.
- Load balanced computing.

Some of the above other BEAM languages support, other are provided by Unison, Akka

The synthesis is new.

## Any number of module revisions allowed

(Unison but no Unison cloud, load changes name, upgrade,  deployment hard to automate)

## Code transfers freely between nodes

(code roams in spawn, bare nodes possible, ...)

...

## Non-meshed TLS based distribution

...

## Hindley-Milner typing and typed mailboxes

*Types in Ernest describe not only the shape of data but which process code belongs to and what a
value is allowed to do.*

Every expression in an Ernest program has a type, and the compiler finds it. This is
Hindley-Milner inference, the type system of the ML family: you write the program, and the
compiler works out, from how each value is used, the most general type that fits.

A function written once works at every type its body allows. `fn apply(f, x) = f(x)` needs no
annotation, and the compiler gives it the type `((a) -> b with e, a) -> b with e`: a function from
`a` to `b` and an `a`, giving a `b`, where `a` and `b` stand for any types and `e` for whatever
effect `f` has, pure included. A use of `apply` that does not fit is an error before the program
runs, and Ernest code that compiles has no type check left to fail at run time; what crosses from
Erlang is checked at the border.

A signature is welcome, and the examples here write them, because a signature is also
documentation. The compiler checks a written signature against what it inferred and reports a
mismatch at the line where the body disagrees.

That much Ernest shares with its family. What follows is what an Ernest type says beyond the
shape of data. Each point states the rule and its price, then shows a program and what the
compiler says about it.

- **A mailbox's type reaches the code that runs behind it.** An Ernest program acts on the world
  through processes. Printing a line, reading a file, starting a program: each is a message to one
  of the runtime's own processes, so a function that prints is already a piece of a process, and
  its type says so with `with`.

  Every process has one mailbox, and the mailbox has a type. The
  compiler checks the code inside a process against that type, so a function written for one
  mailbox cannot run behind another. A function whose type names no mailbox needs no process at
  all: it only computes, and the compiler holds it to that, which is why the first example below
  is refused. The effect is inferred, and a pure function passes wherever an effectful one is
  expected, so the cost is one word in a signature.

  The rule has two prices, and both are the rule working as designed. A debug print is an effect
  too: a pure function that must print is given a mailbox, and its callers follow. And a process
  receiving from several sources declares one type for them all; a source that speaks another type
  is given an adapted address, which turns each of its messages into one of the process's own,
  written where the reader sees it.

```
fn double(x : Int) : Int = {
    Io.println("doubling");
    x * 2
}
```

The Ernest compiler:
`pure.ern:2:5: Io.println needs a process, and double is pure`

```
type CounterMsg = Inc(Int) | Reset
type AckMsg = Ack

fn waitForAck() : Unit with AckMsg =
    receive {
        Ack -> Unit
    }

fn count(total : Int) : Unit with CounterMsg =
    receive {
        Inc(amount) -> {
            waitForAck();
            count(total + amount)
        }
      | Reset -> count(0)
    }
```

The Ernest compiler:
`ack.ern:12:13: waitForAck needs mailbox AckMsg, and the mailbox here is CounterMsg`

```
type CounterMsg = Inc(Int) | Reset | Logged(String)

fn count(total : Int) : Unit with CounterMsg =
    receive {
        Inc(amount) -> count(total + amount)
      | Reset -> count(0)
      | Logged(line) -> {
            Io.println(line);
            count(total)
        }
    }

// an address a logger can send plain strings to; each arrives here as Logged(line)
fn lines() : Address(String) with CounterMsg = adapted(self(), Logged)
```

See $X in the guide, and $Y in the report.

- **A requirement can stand in for a type.** A function generic in a type may need something of
  that type: a sort needs its elements compared, a sum needs them added, a printer needs them
  shown. The requirement is written once, in the signature, with `needs`. Wherever the function is
  used, the compiler supplies the comparison or the addition that belongs to the actual type. A
  type has one `compare` and one `+`, so a call means the one its type has. An order other than
  the type's own is passed as a function, as `List.sort` takes one.

```
fn largest(first : a, rest : List(a)) : a needs a.compare =
    List.foldLeft(rest, first, fn(best, x) = if x > best then x else best)

fn sum(first : a, rest : List(a)) : a needs a.+ =
    List.foldLeft(rest, first, a.+)

largest(3, [1, 4, 1])        // 4, with Int.compare
sum(1.5, [2.5])              // 4.0, with Float.+
```

See $X in the guide, and $Y in the report.

- **Operators belong to the types they work on.** `+`, `<` and the rest work on integers and floats
  alike, and on your own types once you give them the operation. An operator is a named member of
  the type, `Tally.+`, resolved by the operand's type.

```
type Tally = Tally(lines : Int, words : Int, bytes : Int)

fn Tally.+(left : Tally, right : Tally) : Tally =
    Tally(lines = left.lines + right.lines,
          words = left.words + right.words,
          bytes = left.bytes + right.bytes)

Tally(1, 2, 3) + Tally(4, 5, 6)   // Tally(5, 7, 9)
```

See $X in the guide, and $Y in the report.

- **The compiler knows what a value may be used for.** Some values can be tested for equality,
  some cannot: `==` on two functions is an error at the line where it is written. Some values can
  leave their node, some cannot: a function or an open socket is stopped at the type the moment it
  would be sent to another machine. The compiler infers these facts and prints them as marks on
  type variables, `k=` for a type whose values can be tested with `==` and `a!` for one that
  carries no reply. The marks are inferred; a program writes one only in a foreign declaration,
  where there is no body to infer from.

```
fn f(g : () -> Int) : Bool = g == g
```

The Ernest compiler:
`example.ern:1:30: == is not defined on () -> Int: it contains a function or an address`

```
fn startWith(name : String, describe : (Int) -> String) : Unit with m = {
    let _ = Peer.spawn(name, fn() : Unit with Never = Io.println(describe(1)), 1000);
    Unit
}
```

The Ernest compiler:
`example.ern:2:66: the function Peer.spawn starts captures describe, a function, which is bound to its node`

See $X in the guide, and $Y in the report.

- **Ordering is defined once per type, and a derived order is an order by construction.** Every
  type that can be ordered has its one `compare`, in the type's own namespace. The compiler
  writes it for you with `derives compare`, and an order it writes is an order whenever the orders
  of its fields are. An order you write by hand is your promise, and the report states what you
  promise.

```
type Date = Date(year : Int, month : Int, day : Int) derives compare

Date(2026, 10, 13) < Date(2026, 11, 1)     // true, through Date.compare
List.sort(dates, Date.compare)             // by year, then month, then day
```

See $X in the guide, and $Y in the report.

## Call-reply process semantics

(Reply/answer,replaces gen_server and supervsor)

## Load balanced computing

...

## FAQ

Q: It looks like Glean?
A: Yes, Gleam has an attarctive syntax

...
