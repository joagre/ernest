# Ernest module Supervisor

*Since 0.1.0.*

A group of processes, restarted together when one of them faults.

Use it where processes depend on one another, so that a fault in one must
restart others too, or where independent processes should share one restart
limit and stop together, one child per connection among them. A single
process that restarts alone is `restarting`'s work. Spawn `group(strategy,
limit)` as the supervisor, then spawn `child(supervisor, f)` for each child,
`f` the work it does. The caller spawns each, as it spawns what `restarting`
answers, so a fault line names the binding that holds the process (report
§6.9), and a service binding can reach it (report §6.5).

**What restarts.** A child that faults runs `f` again in place, keeping its
address, as under `restarting`. The `Strategy` says which of its siblings
restart with it. The child that faulted runs again once each of those
siblings has restarted or ended, so a call to it after its fault is answered
by the group restarted whole.

**When a sibling restarts.** A sibling restarts at its next wait, a
`receive` or a call waiting for its answer, and runs on until then; a
sibling that never waits never restarts. It keeps its address, and its
mailbox is emptied, as every restart empties it (report §6.9).

**The limit.** A group whose children fault more often than `limit` allows
faults itself. A supervisor that is itself a child of another group then
restarts in place, and asks each of its own children to restart.

**Stopping a group.** `kill(supervisor)` stops the group: when a supervisor
dies, its children are killed after it, the last spawned first, each once
the one before has ended. A child that must finish its work first is sent a
message of its own protocol before, since a killed process runs nothing
more.

## Examples

A group of one, a child that answers, and the group stopped. The child's
mailbox takes a bare `Reply(Int)`, so the call makes its message with
`fn(reply) = reply`:

```ernest
{
    let supervisor =
        spawn(Supervisor.group(Supervisor.OneForOne,
                               RestartLimit(restarts = 3, within = 5000)));
    let echo = spawn(Supervisor.child(supervisor, fn() : Unit with Reply(Int) = receive {
        reply -> answer(reply, 42)
    }));
    let answered = Address.callForever(echo, fn(reply) = reply);
    kill(supervisor);
    answered
}
// => 42
```

## See also

`restarting`, which restarts one process in place; `kill`; `monitor`.

## Supervisor.Strategy

```ernest
type Strategy = OneForOne | OneForAll | RestForOne
```

What else a child's fault restarts: nothing, under `OneForOne`; every other
child, under `OneForAll`; or the children spawned after it, under
`RestForOne`. The order is the one the runtime spawned them in, whatever
order they joined in.

### Examples

A group whose later children use the earlier ones, restarted from the child
that faulted onwards:

```ernest
spawn(Supervisor.group(Supervisor.RestForOne, RestartLimit(restarts = 3, within = 5000)))
```

## Supervisor.Msg

```ernest
abstract type Msg
```

What a supervisor takes. Its constructors are hidden; only this module makes
them.

### Examples

```ernest
{
    let supervisor : Address(Supervisor.Msg) =
        spawn(Supervisor.group(Supervisor.OneForOne,
                               RestartLimit(restarts = 3, within = 5000)));
    kill(supervisor)
}
// => Unit
```

## Supervisor.group

```ernest
Supervisor.group(strategy : Strategy, limit : RestartLimit) : (() -> Unit with Msg) with m+
```

The function a supervisor runs, for the caller to spawn:
`spawn(Supervisor.group(strategy, limit))`. The children's faults are
counted against `limit` as `restarting` counts a process's (report §6.9).

Spawn the function `group` answers once. A second process that runs the same
function faults, even after the first has ended; a second group is a second
call of `group`. The call also spawns a process that keeps the group's
children and kills them when the supervisor dies. A restart of the
supervisor does not end it, and `Process.live` lists it.

A supervisor that is itself a child restarts in place, and asks each of its
children to restart; they keep their order.

### Errors

Faults where the children's faults pass `limit`, with the cause `supervisor
restart limit reached`, and in a second process that runs it, with the cause
`a group runs in one process`.

### Examples

```ernest
spawn(Supervisor.group(Supervisor.OneForAll, RestartLimit(restarts = 5, within = 10000)))
```

## Supervisor.child

```ernest
Supervisor.child(supervisor : Address(Msg), f : () -> Unit with m+) : () -> Unit with m+
```

The function a child runs, for the caller to spawn:
`spawn(Supervisor.child(supervisor, f))`. It joins `supervisor`'s group,
waiting until the supervisor has it, then runs `f`. After a fault it runs
`f` again in place, until the group gives up. A child that returns or is
killed leaves the group.

### Errors

Faults where `supervisor` has ended before the child joins, with the cause
`the supervisor has ended`.

### Examples

```ernest
{
    let supervisor =
        spawn(Supervisor.group(Supervisor.OneForOne,
                               RestartLimit(restarts = 3, within = 5000)));
    spawn(Supervisor.child(supervisor, fn() : Unit with Int = receive {
        _ -> Unit
    }))
}
```

---

Generated by ern 0.3.1 from supervisor.ern.
