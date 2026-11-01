# Ernest module Clock

*Since 0.1.0.*

The time, alarms, and the wait for a time.

`now` is the time of day, in milliseconds since the epoch, 1970-01-01 UTC.
`monotonic` is the clock to measure a duration by, since `now` moves when
the host's clock is set, and `monotonicMicros` is the same clock in
microseconds. `alarm` and `alarmAt` put a message in the caller's mailbox
later, and `sleep` waits a time and takes no message.

**Alarms.** An alarm fires once, and `alarm` and `alarmAt` answer it as an
`Alarm`, which `cancel` can end before it fires. A fired alarm's message is
in the mailbox or on its way, and no cancel takes it back. A periodic tick
is set again each time the one before is handled. A restart of the process
that set an alarm cancels it (report §6.9).

**Alarms arrive in the mailbox.** An alarm is delivered into the caller's
mailbox, so `alarm` and `alarmAt` carry `receiving m`, the caller's mailbox
type; reading the time names no mailbox (report §6.1).

## Examples

The time now, in milliseconds since the epoch:

```ernest
Clock.now() > 0
// => true
```

## See also

`Random.seed` for a sequence that differs between runs.

## Clock.Alarm

```ernest
abstract type Alarm
```

*Since 0.8.0.*

An alarm that `alarm` or `alarmAt` set, which the clock holds until it
fires, is canceled, or its process ends. It is bound to its node, and `==`
is the runtime's on it: an alarm equals itself alone (report §3.10, §3.11).

### Examples

```ernest
{
    let alarm = Clock.alarm(60000, fn(_) = Unit);
    alarm == alarm
}
// => true
```

## Clock.now

```ernest
Clock.now() : Int
```

The time now, in milliseconds since the epoch, 1970-01-01 UTC. It moves when
the host's clock is set; `monotonic` measures a duration.

## Clock.monotonic

```ernest
Clock.monotonic() : Int
```

Milliseconds since a moment the runtime chose, which never go back, so the
difference of two readings is the time the host ran between them. Its value
alone says nothing, and `now` is the time of day. Where the host's monotonic
clock stops while the machine is suspended, that time is left out.

### Examples

```ernest
{
    let start = Clock.monotonic();
    Clock.monotonic() - start >= 0
}
// => true
```

## Clock.monotonicMicros

```ernest
Clock.monotonicMicros() : Int
```

*Since 0.4.0.*

Microseconds by the clock `monotonic` reads, which never go back, for a
program that measures what takes less than a millisecond.

### Examples

```ernest
{
    let start = Clock.monotonicMicros();
    Clock.monotonicMicros() - start >= 0
}
// => true
```

## Clock.sleep

```ernest
Clock.sleep(ms : Int) : Unit
```

*Since 0.8.0.*

Waits `ms` milliseconds, counted as `monotonic` counts them, and takes no
message: the mailbox is as it was. A restart asked for (report §6.9)
reaches the wait as it reaches a `receive`, and so does a fault that an
adapted address's function met on its way to this process (report §6.5),
or a foreign message that does not match (report §8.4). A time below 0 is
0, and a time has no upper bound (report §7.4).

### Examples

```ernest
{
    let start = Clock.monotonic();
    Clock.sleep(1);
    Clock.monotonic() - start >= 1
}
// => true
```

## Clock.alarm

```ernest
Clock.alarm(ms : Int, wrap : (Int) -> m) : Alarm receiving m
```

Puts `wrap(time)` in the caller's mailbox after `ms` milliseconds, `time`
the time it fired, and answers the alarm, which `cancel` can end before
then. A constructor of one argument passes as `wrap` as it is:
`Clock.alarm(100, Tick)` for `Tick(Int)`.

### Examples

```ernest
{
    let _ = Clock.alarm(10, fn(_) = "rang");
    receive {
        message -> message
    }
}
// => "rang"
```

## Clock.alarmAt

```ernest
Clock.alarmAt(time : Int, wrap : (Int) -> m) : Alarm receiving m
```

Puts `wrap(time)` in the caller's mailbox at `time`, in milliseconds since
the epoch, `time` then the time it fired, and answers the alarm, which
`cancel` can end before then. A time already past fires at once.

### Examples

```ernest
{
    let time = Clock.now() + 10;
    let _ = Clock.alarmAt(time, fn(fired) = fired);
    receive {
        fired -> fired >= time
    }
}
// => true
```

## Clock.cancel

```ernest
Clock.cancel(alarm : Alarm) : Bool
```

*Since 0.8.0.*

Ends `alarm` where it has neither fired nor ended, and answers `true`: its
message never comes. It answers `false` for any other alarm, one that
fired, one canceled already, and one whose process restarted or ended, and
leaves it as it is; a fired alarm's message is delivered as any alarm's is.
Any process of the node may cancel an alarm it holds.

### Examples

```ernest
{
    let alarm = Clock.alarm(60000, fn(_) = Unit);
    #(Clock.cancel(alarm), Clock.cancel(alarm))
}
// => #(true, false)
```

## Clock.toString

```ernest
Clock.toString(time : Int) : String
```

*Since 0.5.0.*

The time, in milliseconds since the epoch, as RFC 3339 writes it, in UTC to
the millisecond: `2026-10-24T09:21:03.512Z`, as `ern run` writes a time on
its lines (report §11.2). A time before the year 0 is written as the host
writes it, with its year's sign: `-0001-12-31T23:59:59.999Z`. A time
outside the years -9999 to 9999 faults.

### Errors

Faults where `time` is past the year 9999, with the cause `the time is past
the year 9999`, and where it is before the year -9999, with the cause `the
time is before the year -9999`.

### Examples

```ernest
Clock.toString(0)
// => "1970-01-01T00:00:00.000Z"
```

---

Generated by ern 0.8.0-dev from src/stdlib/clock.ern.
