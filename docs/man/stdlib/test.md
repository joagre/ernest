# Ernest module Test

*Since 0.2.0.*

Tests, which `ern test` runs.

A test is a top-level `let` of type `Case`, exported or not, in any module:
`let adds = Test.Case(name = "adds", run = fn() = Test.equal(1 + 1, 2))`.
Build the module, then run `ern test` on its `.erc`, or on a directory to
run the tests of every module under it (report §11.2).

**What it prints.** `ern test` prints a line for each test as the test ends:
`adds: passed`, `divides: failed: expected 4, got 3`, or `crashes: faulted:
division by zero`, the fault's trace beneath it, a frame a line, each
indented by four spaces. After the tests it runs the module's doc examples,
a line each named by the declaration the example documents and the
example's number among that declaration's: `Math.add example 1: passed`, or
`Math.add example 2: failed: expected 4, got 3`; the module's own examples
are `Math example 1` and on. It exits with status 1 unless every test and
every example passed.

**One test at a time.** The tests run in the order the module declares them,
each in a process of its own, so a test may spawn, send and receive. A test
that faults or deadlocks is reported as `faulted` with the cause, counts as
not passed, and the run goes on with the next (report Appendix E.24).

Most tests compare a value with the one expected, which `equal` does, and
`faults` tests that a call faults with the cause expected. `until` runs a
test again until it passes or its milliseconds end, for an effect the test
has nothing to wait on. A test that wants another text answers `Failed`
with its own.

## Examples

A test run by hand, as `ern test` runs it:

```ernest
{
    let adds = Test.Case(name = "adds", run = fn() = Test.equal(1 + 1, 2));
    adds.run()
}
// => Test.Passed
```

## Test.Case

```ernest
type Case(m) = Case(name : String, run : () -> Result receiving m)
```

A test: its name, which `ern test` prints, and the function it runs, in a
process whose mailbox type is `m`. A test that receives nothing leaves `m`
open, and runs with `Never`.

### Examples

```ernest
Test.Case(name = "the empty list is empty",
          run = fn() = if List.isEmpty([]) then Test.Passed else Test.Failed("not empty"))
// => Test.Case(name = "the empty list is empty", run = <function>)
```

## Test.Result

```ernest
type Result = Passed | Failed(String)
```

A test's answer: `Passed`, or `Failed` with what went wrong.

### Examples

```ernest
if 1 + 1 == 2 then Test.Passed else Test.Failed("1 + 1 is not 2")
// => Test.Passed
```

## Test.Captured

```ernest
type Captured = Captured(stdout : Bytes, stderr : Bytes)
```

*Since 0.10.0.*

What a call `capture` ran wrote: to standard output, and to standard
error, each in the order it was written.

## Test.equal

```ernest
Test.equal(actual : a=, expected : a=) : Result needs a.show
```

*Since 0.3.0.*

`Passed` where `actual` equals `expected`, and otherwise `Failed` naming
both as `Io.show` writes them, the expected first: `expected 3, got 2`. It
needs `a.show`, which a call at a known type supplies without writing it
(report §4.9, §9.4).

Where the two texts begin alike and then differ, the failure says at
which character, counted from 1: the first that differs, or the one past
the shorter text's end.

### Examples

```ernest
#(Test.equal(List.size([1, 2]), 2), Test.equal(1 + 1, 3))
// => #(Test.Passed, Test.Failed("expected 3, got 2"))
```

```ernest
Test.equal([1, 2, 3], [1, 2, 4])
// => Test.Failed("expected [1, 2, 4], got [1, 2, 3], differing at character 8")
```

## Test.faults

```ernest
Test.faults(run : () -> a receiving m, cause : String) : Result
```

*Since 0.5.0.*

`Passed` where a call of `run` faults with `cause`, and otherwise `Failed`
naming the cause expected and what came instead: another cause, a return,
or the reason the process ended with as `Io.show` writes it, `expected the
fault division by zero, got Killed`.

`run` runs in a process of its own, monitored, whose end gives the answer
(report §6.9). `faults` waits for that end however long it takes, as a
direct call of `run` would. Where the caller ends first, the process is
killed; a process `run` spawns lives on after it. No job reports a fault of
a process `faults` started, since the test's answer carries it (report
§11.2).

### Examples

```ernest
Test.faults(fn() = 1 / 0, "division by zero")
// => Test.Passed
```

```ernest
Test.faults(fn() = 1 + 1, "division by zero")
// => Test.Failed("expected the fault division by zero, got a return")
```

```ernest
Test.faults(fn() = 1.0 / 0.0, "division by zero")
// => Test.Failed("expected the fault division by zero, got the fault float arithmetic error")
```

## Test.until

```ernest
Test.until(run : () -> Result receiving m, ms : Int) : Result receiving m
```

*Since 0.7.0.*

Runs `run` again until it answers `Passed` or `ms` milliseconds have passed
since the call, and answers the last `Result`: `Passed`, or the last
`Failed`, which says what the test saw, in place of a `Timeout` (report
Appendix E.0 shape rule 8).

`run` runs once at least, in the caller's process, and again after a
`Failed`, the caller yielding the scheduler between runs and waiting for
nothing else, so that what the test waits for gets the scheduler: the wait
is the test's own running. It is how a test waits for an effect that has
no order with what the test can wait on: what a server did with a `Down`
the runtime delivered it (report §6.9).

### Examples

```ernest
Test.until(fn() = Test.equal(1 + 1, 2), 1000)
// => Test.Passed
```

```ernest
Test.until(fn() = Test.equal(1 + 1, 3), 10)
// => Test.Failed("expected 3, got 2")
```

## Test.capture

```ernest
Test.capture(run : () -> a receiving m) : #(a, Captured) receiving m
```

*Since 0.10.0.*

`run`'s value, and what was written to standard output and standard error
while it ran, as `Os.run` answers a program's: how a test reads a line the
code it tests writes, which then stands neither among the test's lines nor
in a shell's live region.

`run` runs in the caller's process. What is captured is what the caller's
chain writes: the process at the head of the caller's spawns, a test's own
under `ern test`, and every process that one started, directly or through
one it started, a server the test started before the call among them. A
write by any other process, a system process's own or a service's, goes
where it went (report Appendix E.24).

Where two captures of one chain run at once, the one begun last takes the
chain's writes until it returns. Where the caller ends before `run`
returns, a fault among the ways, what was captured is written where it
would have gone.

### Examples

```ernest
{
    let #(_, captured) = Test.capture(fn() = Io.printlnError("listening on 8080"));
    String.fromUtf8Lossy(captured.stderr)
}
// => "listening on 8080\n"
```

---

Generated by ern 0.10.0-dev from src/stdlib/test.ern.
