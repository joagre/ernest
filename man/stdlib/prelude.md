# Ernest prelude

*Since 0.1.0.*

The names every module has without writing a module's name: the built-in
types, the types the language's rules name and those whose module is named
after them, the process functions, and `fault` (report §9). An
operation in a type's namespace, `Int.compare`, is documented by that
type's module.

## Examples

```ernest
{
    let counter = spawn(fn() = receive { n -> Io.println(Int.toString(n)) });
    send(counter, 1)
}
```

## Int

```ernest
type Int
```

An integer of any size, on which arithmetic is exact (report §3.1).

### Examples

```ernest
1_000_000 * 1_000_000
// => 1000000000000
```

## Float

```ernest
type Float
```

A finite IEEE 754 double. An operation whose result would not be finite
faults (report §3.1).

### Examples

```ernest
1.5 * 2.0
// => 3.0
```

## Char

```ernest
type Char
```

One Unicode scalar value, written `'a'`.

### Examples

```ernest
Char.toUpper('a')
// => 'A'
```

## String

```ernest
type String
```

Unicode text, whose unit is the grapheme (report Appendix E.5).

### Examples

```ernest
"ab" <> "c"
// => "abc"
```

## Bytes

```ernest
type Bytes
```

A sequence of octets, built and matched with bitstrings (report §5.11).

### Examples

```ernest
Bytes.size(<<1, 2, 3>>)
// => 3
```

## Bool

```ernest
type Bool
```

`true` or `false`.

### Examples

```ernest
!(1 < 2)
// => false
```

## Address

```ernest
type Address(m)
```

Where messages of type `m` are sent: a process, or one seen through a
function with `via`. Addresses have no equality; the process behind
one has, `Process.fromAddress(a)`.

### Examples

```ernest
{
    let a : Address(Int) = spawn(fn() = receive { _ -> Unit });
    send(a, 1)
}
```

## Reply

```ernest
type Reply(a)
```

The address a request carries for its answer, answered exactly once on
every path by `answer` (report §6.6).

### Examples

```ernest
{
    let echo = spawn(fn() = receive { #(n, r) -> answer(r, n) });
    Address.call(echo, fn(r) = #(7, r), 1000)
}
```

## Never

```ernest
type Never
```

The type with no values: a process whose mailbox is `Never` receives
nothing.

### Examples

```ernest
spawn(fn() : Unit with Never = Io.println("hello"))
```

## Process

```ernest
type Process
```

The identity of a process, with equality and no ordering; nothing can
be sent to it. `Process.fromAddress` gives the process behind an
address (report Appendix E.21).

### Examples

```ernest
Process.fromAddress(self()) == Process.fromAddress(via(self(), fn(x) = x))
// => true
```

## List

```ernest
type List(a)
```

A list of values of type `a`: `[]`, or `x :: rest`.

### Examples

```ernest
1 :: [2, 3]
// => [1, 2, 3]
```

## Map

```ernest
type Map(k=, v)
```

A map from keys of type `k`, which need equality, to values of type `v`.

### Examples

```ernest
Map.get(Map.fromList([#("a", 1)]), "a")
// => Some(1)
```

## Set

```ernest
type Set(a=)
```

A set of values of type `a`, which need equality.

### Examples

```ernest
Set.contains(Set.fromList([1, 2]), 2)
// => true
```

## Unit

```ernest
type Unit = Unit
```

The type of a value that says nothing: the result of a function whose
work is its effect. Its one value is written `Unit`.

### Examples

```ernest
Unit
// => Unit
```

## Optional

```ernest
type Optional(a) = None | Some(a)
```

A value that may be absent, `None`, or present, `Some(v)`: the result of
a partial operation (report Appendix E.0 rule 4), and a chain of `<-`
(report §5.5).

### Examples

```ernest
List.get([1, 2], 5)
// => None
```

## Either

```ernest
type Either(e, a) = Left(e) | Right(a)
```

A result, `Right(v)`, or the reason there is none, `Left(e)`: the result
of an operation that fails for a cause, and a chain of `<-` (report §5.5).

### Examples

```ernest
Either.fromOptional(String.toInt("x"), "not a number")
// => Left("not a number")
```

## Ordering

```ernest
type Ordering = Less | Equal | Greater
```

What a `compare` answers, which `<` and the other comparisons read
(report §3.10).

### Examples

```ernest
Int.compare(2, 1)
// => Greater
```

## Down

```ernest
type Down = Down(process : Process, reason : Reason, site : String)
```

What `monitor` delivers when a process ends: which process it was,
how it ended, and where it was spawned, the top-level declaration and
the line of the spawn, `Counter.main:19` (report §6.9).

### Examples

```ernest
{
    let worker = spawn(fn() : Unit with Never = Unit);
    monitor(Process.fromAddress(worker), fn(d : Down) = d);
    receive { Down(reason = r, site = _) -> r }
}
```

## Reason

```ernest
type Reason = Returned | Killed | ProgramEnd | Fault(String) | Unknown
```

How a process ended: its function returned, `kill` ended it, the program
ended while it ran, or it faulted with a cause. Only `Fault` is a fault.

### Examples

```ernest
match Fault("division by zero") {
    Fault(cause) -> cause
  | _ -> "not a fault"
}
// => "division by zero"
```

## RestartLimit

```ernest
type RestartLimit = RestartLimit(restarts : Int, within : Int) | Unlimited
```

How often `restarting` restarts: at most `restarts` times within
`within` milliseconds, the next fault ending the process, or after
every fault where it is `Unlimited` (report §6.9). A count below 0 is
0, and a time below 1 is 1.

### Examples

```ernest
RestartLimit(restarts = 3, within = 5000)
```

## Path

```ernest
type Path = Path(String)
```

A file system path, in the runtime's syntax; the `Path` module takes it
apart (report Appendix E.14).

### Examples

```ernest
Path.name(Path("/tmp/a.txt"))
// => Some("a.txt")
```

## self

```ernest
self() : Address(m) with m
```

The address of the calling process.

### Examples

```ernest
{
    let me = self();
    let _ = spawn(fn() : Unit with Never = send(me, "ready"));
    receive { s -> s }
}
```

## send

```ernest
send(address : Address(a), message : a) : Unit with m+
```

Puts `message` in the mailbox of the process at `address`, and returns
at once. Messages from one sender arrive in the order they were sent
(report §6.4).

### Examples

```ernest
send(self(), 42)
```

## spawn

```ernest
spawn(f : () -> Unit with n) : Address(n) with m+
```

Starts a process on this node that runs `f`, and answers its address.
The function's mailbox type is the address's (report §6.2).

### Examples

```ernest
spawn(fn() = receive { n -> Io.println(Int.toString(n)) })
```

## spawnMonitored

```ernest
spawnMonitored(f : () -> Unit with n, wrap : (Down) -> m) : Address(n) with m
```

Starts a process as `spawn` does, monitored by the caller from its
start: `wrap` of its `Down` is put in the caller's mailbox when it ends,
with its reason, however soon that is (report §6.2, §6.9).

### Examples

```ernest
spawnMonitored(fn() : Unit with Never = Unit, fn(d : Down) = d)
```

## via

```ernest
via(target : Address(b), wrap : (a) -> b) : Address(a)
```

An address that delivers what is sent to it to `target`, turned by
`wrap`. It is not a process. A fault in `wrap` ends the process behind
`target`, not the sender (report §6.5).

### Examples

```ernest
{
    let texts = via(self(), fn(n) = Int.toString(n));
    send(texts, 42)
}
```

## Address.call

```ernest
Address.call(address : Address(m), request : (Reply(a)) -> m, ms : Int) : Optional(a) with n+
```

Sends `request` of a fresh reply to the process at `address`, and waits
up to `ms` milliseconds for the answer: `Some` of it, or `None` when
none came. An answer that comes late is dropped, and the recipient's
work is not cancelled (report §6.6).

### Examples

```ernest
{
    let echo = spawn(fn() = receive { #(n, r) -> answer(r, n) });
    Address.call(echo, fn(r) = #(7, r), 1000)
}
```

## Address.callForever

```ernest
Address.callForever(address : Address(m), request : (Reply(a)) -> m) : a with n+
```

As `Address.call`, but waits without a deadline and answers the answer
itself; if none comes, the caller waits for ever.

### Examples

```ernest
{
    let echo = spawn(fn() = receive { #(n, r) -> answer(r, n) });
    Address.callForever(echo, fn(r) = #(7, r))
}
```

## answer

```ernest
answer(reply : Reply(a), value : a) : Unit with m+
```

Puts `value` in `reply`, which consumes it. A second answer to one reply
is dropped (report §6.6).

### Examples

```ernest
spawn(fn() = receive { #(n, r) -> answer(r, n * 2) })
```

## restarting

```ernest
restarting(limit : RestartLimit, f : () -> Unit with n+) : () -> Unit with n+
```

A function that runs `f()` and, when `f` faults, runs it again in the
same process: the process keeps its address, its mailbox is emptied,
every call waiting for its answer ends, and what the process asked the
runtime for, its alarms, monitors and subscriptions, is cancelled
(report §6.9). A restart is not a death; no `monitor` is told. With
`Unlimited`, `f` runs again after every fault.

### Errors

Under `RestartLimit`, the fault of `f` after the limit's restarts within
its time, with that fault's cause.

### Examples

```ernest
spawn(restarting(RestartLimit(restarts = 3, within = 5000), fn() : Unit with Never = Unit))
```

## monitor

```ernest
monitor(process : Process, wrap : (Down) -> m) : Unit with m
```

Puts `wrap` of a `Down` in the caller's mailbox when `process` ends, or
at once, with the reason `Unknown`, if it has ended. Each call gives one
message (report §6.9). `Process.fromAddress` gives the process behind an
address, and a process one starts is watched from its start with
`spawnMonitored`.

### Examples

```ernest
{
    let worker : Address(Int) = spawn(fn() = receive { _ -> Unit });
    monitor(Process.fromAddress(worker), fn(d : Down) = d)
}
```

## kill

```ernest
kill(address : Address(a)) : Unit with m+
```

Ends the process at `address`, which its monitors see as `Killed`. The
process may run a little before it stops (report §6.9).

### Examples

```ernest
kill(spawn(fn() = receive { _ -> Unit }))
```

## fault

```ernest
fault(cause : String) : a
```

Ends the process with `cause`: it has every type, and nothing
catches the fault (report §7.3, §7.4). It is for an invariant broken
beyond recovery; a failure the caller can handle is an `Optional` or an
`Either`. Code not written yet is `fault("todo: ...")`.

### Errors

`Fault(cause)`.

### Examples

```ernest
fn(xs : List(Int)) : Int = match xs { x :: _ -> x | [] -> fault("never empty here") }
```

---

Generated by ern 0.3.0 from the prelude, report §9.
