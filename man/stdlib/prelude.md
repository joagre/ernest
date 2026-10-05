# Ernest prelude

*Since 0.1.0.*

The names every module has without writing a module's name.

The prelude holds the types every program meets, `Int`, `String`, `List`,
`Optional`, `Either` and the rest; the types the language's own rules
name, `Down`, `Reason` and `RestartLimit`; the functions that start
processes and talk to them, `spawn`, `send`, `Address.call` and the rest;
and `fault` (report §9).

An operation in a type's namespace, `Int.compare` or `String.<>`, belongs to
that type's module, and is documented on its page.

## Examples

A process started, and a number sent to it:

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
1_000_000_000_000 * 1_000_000_000_000
// => 1000000000000000000000000
```

## Float

```ernest
type Float
```

A double-precision floating-point number, always finite. An operation
whose result would not be, an overflow or a division by zero, faults with
the cause `float arithmetic error`. There is no infinity, no NaN and no
negative zero (report §3.1).

### Examples

```ernest
1.5 * 2.0
// => 3.0
```

## Char

```ernest
type Char
```

One Unicode scalar value, written `'a'`. A letter as a reader sees it may
be several, a letter and its accent; `String.graphemes` gives those
whole.

### Examples

```ernest
Char.toUpper('a')
// => 'A'
```

## String

```ernest
type String
```

Unicode text, held as UTF-8. Its length and positions count graphemes,
what a reader sees as one letter, so `"é"` has size 1 however its accent
is encoded (report Appendix E.5).

### Examples

```ernest
"ab" <> "c"
// => "abc"
```

## Bytes

```ernest
type Bytes
```

A sequence of bytes, as a file or a socket holds them. Bitstrings build
it and take it apart: `<<1, 2, 3>>`, and `<<length:size(16), rest:bytes>>`
in a pattern (report §5.11).

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

Where messages of type `m` are sent: a process, or a process seen through
a function with `via`. Holding an address is the permission to send to
the process and to kill it. Addresses have no equality; the process
behind one has, `Process.fromAddress(a)`.

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

Where the answer to a request goes. `Address.call` makes one and puts it
in the request, and the process that receives the request answers it with
`answer`. A reply is answered exactly once on every path, or handed on,
and the compiler checks it (report §6.6).

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

The type with no values. A process whose mailbox type is `Never`
receives nothing, and nothing can be sent to its address.

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

A map from keys of type `k` to values of type `v`. The `=` in `k=` says
that the key type needs equality. A map is a value, and the module `Map`
holds its operations.

### Examples

```ernest
Map.get(Map.fromList([#("a", 1)]), "a")
// => Some(1)
```

## Set

```ernest
type Set(a=)
```

A set of values of type `a`. The `=` in `a=` says that the element type
needs equality. A set is a value, and the module `Set` holds its
operations.

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

A value that may be absent, `None`, or present, `Some(v)`. A function
that may have no answer answers one, `List.get` past the end among them
(report Appendix E.0 rule 4). In a block, `let x <- e` takes the value
out of a `Some`, and the block answers `None` at the first `None` (report
§5.5).

### Examples

```ernest
List.get([1, 2], 5)
// => None
```

## Either

```ernest
type Either(e, a) = Left(e) | Right(a)
```

A result, `Right(v)`, or the reason there is none, `Left(e)`. An
operation that can fail for a cause answers one. In a block, `let x <- e`
takes the value out of a `Right`, and the block answers the first `Left`
(report §5.5).

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

How a process ended, as `Down` says it.

- `Returned`: its function returned, or, for a socket or a listener, the
  program closed it.
- `Killed`: `kill` ended it, or its owner's death, for a socket, a
  listener or a running program.
- `ProgramEnd`: the program ended while it ran.
- `Fault(cause)`: it faulted, with that cause.
- `Unknown`: it had ended before `monitor` was called, and how is not
  known.

Only `Fault` counts as a fault: `ern run` reports it, and `restarting`
restarts after it.

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

How often a process restarts, which `restarting` and `Supervisor.group`
take (report §6.9). `RestartLimit(restarts, within)` restarts at most
`restarts` times within `within` milliseconds, and the next fault then
ends the process. `Unlimited` restarts after every fault. A count below 0
is 0, and a time below 1 is 1.

### Examples

```ernest
RestartLimit(restarts = 3, within = 5000)
```

## Path

```ernest
type Path = Path(String)
```

A file system path, as the operating system writes it, `/tmp/a.txt`. The
`Path` module joins paths and takes them apart (report Appendix E.14).

### Examples

```ernest
Path.name(Path("/tmp/a.txt"))
// => Some("a.txt")
```

## self

```ernest
self() : Address(m) with m
```

The address of the calling process. A process gives it to another that
is to answer or tell it something: `let me = self()`, then
`spawn(fn() = worker(me))`.

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

Puts `message` in the mailbox of the process at `address`, and returns at
once, without waiting for it to be received.

Messages from one sender arrive in the order they were sent; between two
senders there is no order (report §6.4). Sending to a process that has
ended does nothing.

### Examples

```ernest
send(self(), 42)
```

## spawn

```ernest
spawn(f : () -> Unit with n) : Address(n) with m+
```

Starts a process that runs `f`, and answers its address. The process
runs beside the caller, on this node, and `spawn` returns at once.

The address takes the messages `f`'s mailbox type names. A process that
receives nothing says so with `with Never` on its function: `spawn(fn() :
Unit with Never = Io.println("hi"))` (report §6.2). The process ends when
`f` returns, faults, or is killed.

### Examples

A process that receives an `Int`, so that its address is an
`Address(Int)`:

```ernest
spawn(fn() = receive { n -> Io.println(Int.toString(n)) })
```

## spawnMonitored

```ernest
spawnMonitored(f : () -> Unit with n, wrap : (Down) -> m) : Address(n) with m
```

Starts a process as `spawn` does, and watches it from its first moment:
`wrap(d)` is put in the caller's mailbox when it ends, `d` the `Down`
that says how. Unlike `spawn` followed by `monitor`, no end of the
process can come before the watch (report §6.2, §6.9).

### Examples

```ernest
spawnMonitored(fn() : Unit with Never = Unit, fn(d : Down) = d)
```

## via

```ernest
via(target : Address(b), wrap : (a) -> b) : Address(a)
```

An address that turns each message with `wrap` and delivers it to
`target`. It is no process of its own.

A process whose mailbox takes `Msg` hands out `via(self(), Wrap)` to take
a message of another type as one of its own, wrapped in its constructor
`Wrap`. A fault in `wrap` ends the process behind `target`, not the
sender (report §6.5).

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

Asks the process at `address` and waits for its answer: `Some(answer)`,
or `None` where none came within `ms` milliseconds.

`request` is given a fresh `Reply` and builds the message that carries
it, `fn(reply) = Get(reply = reply)`. The process that receives the
message answers it with `answer`.

`None` does not cancel the work: the process asked may still do it, and
an answer that comes late is dropped. Where that process has ended, or
ends or restarts before it answers, the call answers `None` at once.
The clock starts at the call. The request is made and sent whatever the
time, and `ms` bounds only the wait for the answer, which ends at once
where the time has already passed (report §6.6).

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

Asks as `Address.call` does, and waits for the answer without a deadline,
answering the answer itself. A process asked that lives and never
answers keeps the caller waiting for ever.

### Errors

Faults where the process asked has ended, or ends or restarts before it
answers (report §6.6):

- with that process's own cause, where it faulted;
- `callee was killed`, where `kill` or its owner's death ended it;
- `callee returned without answering`, where its function returned;
- `callee was closed`, where the program closed it, a socket or a
  listener;
- `callee was restarted`, where a supervisor asked it to restart;
- `callee had ended`, where it had ended before the call.

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

Answers a request: sends `value` to the caller waiting on `reply`.

A reply is answered exactly once on every path, or handed on, and the
compiler checks it (report §6.6). A caller that has stopped waiting,
after its deadline or its end, never sees the answer, and the process
that answers is not told.

### Examples

```ernest
spawn(fn() = receive { #(n, r) -> answer(r, n * 2) })
```

## restarting

```ernest
restarting(limit : RestartLimit, f : () -> Unit with n+) : () -> Unit with n+
```

A function that runs `f`, and runs it again in the same process each time
it faults. A program spawns what it answers: `spawn(restarting(limit, f))`.

The process keeps its address across a restart, so whoever holds it keeps
it. Everything else starts afresh: the mailbox is emptied, every call
waiting for the process's answer ends, and what the process asked the
runtime for, its alarms, monitors and subscriptions, is cancelled. What
`f` held is gone (report §6.9).

A restart is not a death: no `monitor` is told, and the process's `Down`
comes only when it ends for good. `RestartLimit(restarts = n, within = t)`
allows `n` restarts within `t` milliseconds, and `Unlimited` restarts
after every fault.

### Errors

Under `RestartLimit`, the fault past the limit ends the process, with
that fault's cause.

### Examples

A worker that faults on `0`, and runs again, at most three times in five
seconds:

```ernest
spawn(restarting(RestartLimit(restarts = 3, within = 5000), fn() : Unit with Int = receive {
    n -> Io.println(Int.toString(100 / n))
}))
```

## monitor

```ernest
monitor(process : Process, wrap : (Down) -> m) : Unit with m
```

Watches a process: `wrap(d)` is put in the caller's mailbox when
`process` ends, `d` the `Down` that says how.

A process that has already ended is reported at once, with the reason
`Unknown`. Each call watches once and gives one message (report §6.9).
`Process.fromAddress(a)` gives the process behind an address, and a
process the caller starts itself is watched from its start with
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

Ends the process at `address`. Its monitors see the reason `Killed`.

`kill` returns at once, and the process may run a little before it stops.
Killing a process that has ended does nothing (report §6.9).

### Examples

```ernest
kill(spawn(fn() = receive { _ -> Unit }))
```

## fault

```ernest
fault(cause : String) : a
```

Ends the calling process with `cause`. It has every type, so it stands
wherever a value is expected, and nothing catches the fault (report
§7.3).

Use it for an invariant broken beyond recovery. A failure the caller can
handle is an `Optional` or an `Either`. Code not written yet is
`fault("todo: ...")`.

### Errors

Always faults, with `cause` as the cause.

### Examples

```ernest
fn(xs : List(Int)) : Int = match xs { x :: _ -> x | [] -> fault("never empty here") }
```

---

Generated by ern 0.3.1 from the prelude, report §9.
