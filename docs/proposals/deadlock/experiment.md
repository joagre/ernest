# What §8.6's check does, run

The programs of 2026-11-09, run before the proposal's nine questions were taken, on `ern` 0.10.0's checkout and OTP 29. Each shows a sentence of [`proposal.md`](proposal.md)'s Part 1. The code is under [`experiment/`](experiment/).

Each program is built with `ern build` and run with `ern run`. The three of program 4 take `--libs-dir libs`, where `libs/later/ebin` holds `later.erl` compiled. Standard error went to a pipe, so each of its lines began with its time, which is left out below.

## The four programs

**1. A long computation**, `long.ern`. `main` calls a worker with `Address.callForever`, and the worker computes for four seconds and answers.

```console
$ ern run long.erc
128202696
```

The answer came after 4.2 s, with status 0 and no fault. A computing process is not waiting, so the look answers that the program runs.

**2. A hand-off through a cycle**, `handoff.ern`. `main` calls the second. The second hands `main`'s reply to a worker and then calls `main`. The worker computes for three seconds and answers `main`, and `main` answers the second.

```console
$ ern run handoff.erc
the worker holds main's reply, and computes
main is answered 41
the second is answered 42
all finished
```

The cycle of two calls without a limit stood for three seconds in a correct program, which ended after 3.2 s with status 0. A fault from that cycle would have killed it.

**3. A stuck part**, `stuck.ern`. Two servers call each other without a limit and a third process calls the first, beside `main`, which sets an alarm five times, a second apart, and writes each one's `Process.status`. Then `main` waits for a message none can send.

```console
$ ern run stuck.erc
Stuck.main:14 Process.Calling, Stuck.main:15 Process.Calling, Stuck.main:17 Process.Calling
Stuck.main:14 Process.Calling, Stuck.main:15 Process.Calling, Stuck.main:17 Process.Calling
Stuck.main:14 Process.Calling, Stuck.main:15 Process.Calling, Stuck.main:17 Process.Calling
Stuck.main:14 Process.Calling, Stuck.main:15 Process.Calling, Stuck.main:17 Process.Calling
Stuck.main:14 Process.Calling, Stuck.main:15 Process.Calling, Stuck.main:17 Process.Calling
the ticks are over, and main waits
Stuck.main faulted: deadlock
    Stuck.main:19
    1 process of Stuck.main:14 waits in Stuck.firstLoop:52
    1 process of Stuck.main:15 waits in Stuck.secondLoop:60
    1 process of Stuck.main:17 waits in Stuck.main:17
```

While the alarm could deliver, the three hung with no word, and `Calling` said nothing of on whom. The fault came 0.3 s after the last tick, with status 1. Its lines say where each process waits and not on whom.

**4. The false alarm**, in three programs. In `alarm.ern` a foreign function starts a host process that sends `main` its message after three seconds, and nothing monitors that process.

```console
$ ern run --libs-dir libs alarm.erc
Alarm.main faulted: deadlock
    Alarm.main:12
```

The fault came 0.33 s after the start, with status 1, for a program that would have gone on.

`watched.ern` is the same with a monitor of the host process, which the foreign function answers as a `Process`.

```console
$ ern run --libs-dir libs watched.erc
done
```

It ended after 3.2 s with status 0.

`timer.ern` asks the host's own timer, `erlang:send_after/3`, for the message, §8.6's other case. It faults as `alarm.ern` does, after 0.33 s.

## What a start time costs a call

`since.erl` times, on the host alone, what the call's mark costs with the monotonic time beside it, against a call's round trip as the runtime makes it: a monitor with an alias, a send and a receive. Each number is the best of five runs, five million iterations for the marks and half a million for the round trip, 5.6 s in all.

| | ns |
|---|---|
| the empty loop | 10.0 |
| the call's mark as it is put now, a pair | 27.4 |
| the mark with the monotonic time in milliseconds | 50.8 |
| the mark with the host's native time | 49.4 |
| a call's round trip | 742.0 |

The start time adds 23 ns, 3% of the host's round trip. `make bench` cannot show a difference of that size, since its rows move by up to a fifth between two runs (the log's *The Rows That Grew*).

## What the runtime already keeps

Read in `src/runtime/ern_rt.erl` the same day.

- A waiting caller keeps its call under a key of its own dictionary: the callee and the reply (`called/2`). The callee is the process behind the address, through every adapted address (`watched/1`), or a compute's gateway (`compute/4`).
- A call with a limit puts the timed mark around its wait, and `callForever` puts none (`call/4`, `timed/0`). A compute puts the foreign mark and not the timed one.
- `Process.status` reads the call's key in the one read that gives the host's status (`status/1`), and the look reads it in its second read (`still/2`).

So the callee and the limit are read from the caller's own state, and nothing new is written on a call's path for them.

## Not shown

The status premise of Part 1 is as it was read in OTP 29.1.2's source. No program here shows it. `Peer.computeAt` around `Process.status`, by which a program reads a callee on its own node, was not run, since it needs two nodes.
