# The counter, written twice

The first program of [`code_update.md`](../../code_update.md)'s section 4, written and run on 2026-10-07 on one node with the toolchain as it stands, Ernest 0.3.1: a counter with its total as its state, first as the restart alone has it, then as a step function the library runs. Row C1, a change of logic behind an unchanged protocol and state type, runs both ways; row C2, a change of the state's shape, is where the second way stops, and its diagnostic is the experiment's finding.

## The files

- `restart/v1/counter.ern`, `restart/v2/counter.ern`: the counter as a loop with its state in its arguments (report §6.5); version 2 logs each `Add`.
- `service/service.ern`: the library, `Service`, written for this experiment: an `Envelope(m, s)` of the protocol's messages and one `Upgrade`, a `Handle` of the loop's address and the clients' adapted address, `start`, `run`, `address` and `upgrade`. No envelope tag yet, since no protocol changes here.
- `service/v1/counter.ern`, `service/v2/counter.ern`: the counter as a `step` the library runs; version 2 logs each `Add`.
- `service/v3/counter.ern`: version 3, the state's shape changed to a record that also counts the adds, with `migrate`; it compiles.
- `service/v3/upgrade_v3.ern`: the upgrade of a running version 1 or 2 counter to version 3, which does not compile.

## How it was run

Each version is built with `bin/ern build --source-root dir --build-root dir/build dir` over a directory holding `service.ern` and the version's `counter.ern`. The two sessions below are `bin/ern shell --source-root dir` in line mode, the source rewritten between inputs with `Fs.write`, as `test/ern_shell_tests.erl` drives a reload.

## The restart alone

```console
Ernest 0.3.1. :help for the commands, :quit to leave.
> Counter, compiled from counter.ern
> > 3 : Int
> Right(Unit) : Either(Io.Error, Unit)
> Counter, compiled again
Counter: the previous version is held by the process spawned at Counter.counter:7; the next reload of Counter ends it
> 0 : Int
> add 1
> 1 : Int
>
```

The reload evaluates the service binding again (report §11.2), so a second counter starts at 0 and the module's functions reach it: the total of 3 is lost. The first counter runs on, unreachable, until the next reload ends it. A deploy by restart does the same with a node.

## The service upgraded in place

```console
Ernest 0.3.1. :help for the commands, :quit to leave.
> Service, compiled from service.ern
Counter, compiled from counter.ern
> h : Service.Handle(Counter.Msg, Int)
> > 3 : Int
> Right(Unit) : Either(Io.Error, Unit)
> Counter, compiled again
> > 3 : Int
> add 1
> 4 : Int
> 0 : Int
>
```

`h` holds the version 1 service. After the reload, `Service.upgrade(h, Counter.step)` hands it version 2's `step`; its total of 3 is kept, the next `Add` is logged by the new code, and the total is 4. `Counter.total()` answers 0 from the second service the reload's re-evaluation of the binding started, which is today's §11.2; under the concept the plan would send the `Upgrade` instead of evaluating the binding again.

## Row C2 does not compile

`upgrade_v3.ern` sends the running loop an `Upgrade` whose `next` migrates the `Int` to a `Count` and runs version 3's step:

```console
upgrade_v3.ern:10:47: field next: expected (a) -> Unit with Service.Envelope(e, a), found (Int) -> Unit with Service.Envelope(Counter.Msg, Counter.Count)
 9 |         Service.Handle(loop = loop) ->
10 |             send(loop, Service.Upgrade(next = fn(total) = Service.run(Counter.step, Counter.migrate(total))))
   |                        --------------- Upgrade declares next : (s) -> Unit with Service.Envelope(m, s)
   |                                               ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
   | = help: the types differ at Service.Envelope(a, b) and Service.Envelope(Counter.Msg, Counter.Count)
```

The `Upgrade` hands the state to new code through a function whose mailbox type is the loop's, `Envelope(Msg, Int)`, and version 3's loop runs under `Envelope(Msg, Count)`. The state's type is in the mailbox type, so a change of the state's shape in place is a change of the mailbox type, which only `become` makes. What `code_update.md` says of it is its section 2, *A changed state is a changed mailbox type*.

## A second finding, on today's shell

In the service session the reload did not list the version 1 process as holding the previous version, where the restart session's reload did. The library's loop runs `Service.run`, which the reload did not compile again, and holds version 1's `step` in its arguments; the host's `check_process_code` sees a process's code and not a function in its state (the survey's *B8*), so §11.2's listing missed it, and the reload that purges version 1 will leave it to fail at its next `Add` with the host's `undef`. The plan's standing gaps hold it; MVP 3.1 unloads nothing, which closes it.

## The count

| | lines |
|---|---|
| the counter as the restart has it, version 1 | 20 |
| the counter as a step function, version 1 | 20 |
| the library, written once | 34 |
| what version 2 adds, either way | 3 to 4 |
| what the upgrade in place cost the program | one line at the shell, `Service.upgrade(h, Counter.step)` |

What the step function saved here is the total, 3, and what it cost is the library. The store, the protocol change and the chat server are next, and the chat server is where `become` is weighed.
