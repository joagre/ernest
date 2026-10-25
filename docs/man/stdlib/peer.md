# Ernest module Peer

*Since 0.4.0.*

Other nodes: a service offered to this node's peers, found on a peer, a
process started on one, a function run on one for its value, and how busy
each is.

A program is a node when it runs with `--config-dir`, and its peers are the
nodes its configuration directory's `ernest.conf` lists, each by a name.
What a program does with another node's process, a send, a call, a monitor,
a `kill`, it does as with one of its own; this module gives it the address
of such a process to begin with (report §8.7).

A service is offered under its name at its message type, and found on the
peers `ernest.conf`'s `services` lists for the name, in that order. Where a
service lives is the configuration's: a find names no node.

Work on a peer is a process spawned there, whose result reaches another
process as a message, or a function run there for its value, which the
caller waits for as for a call's answer. A spawn names its peer, and so
does `computeAt`; `compute` runs on a peer the node picks by the
utilizations it holds. Each node that lists peers tells them how busy it
is every `utilization-interval` of its `ernest.conf`, and holds what each
told it: `compute` draws two of them and takes the less busy, and
`utilizations` answers the table, over which a program writes a rule of
its own. A program that knows how busy it is better than its node's
measure says so with `setUtilization` (report §8.7, Appendix E.27).

A find, a spawn, a compute and a utilization wait for the peer at most the
milliseconds they are given, the opening of a connection among them, and
answer what they found or an `Io.Error`, which the program matches on. The
runtime's own first steps of a dial come beside that time, and end at the
latest where a dial that nothing answers is given up, so an answer may come
later than it by them (report Appendix E.27).

None faults for what the network or a peer does, and a compute faults only
for a fault in the function it runs. A program that is no node has no peers,
so they answer `NotListed`; a node dials only once its bindings have their
values, so in an initializer they answer `Unreachable`, and a node holds no
utilization until a peer has told it one.

## Examples

A service offered, and found; on a program that is no node, which lists no
peer, the find answers `NotListed`:

```ernest
{
    let service : Peer.Service(Int) = Peer.service("squares");
    let _ = Peer.offer(service, spawn(fn() : Unit receiving Int = receive {
        _ -> Unit
    }));
    Peer.find(service, 1000)
}
// => Left(NotListed)
```

A worker started on the peer named `worker`, which a program that is no node
does not list:

```ernest
Peer.spawn("worker", fn() = Io.println("working"), 5000)
// => Left(NotListed)
```

A value computed on a peer the node picks, and on the peer named `worker`:

```ernest
#(Peer.compute(fn() = 6 * 7, 5000), Peer.computeAt("worker", fn() = 6 * 7, 5000))
// => #(Left(NotListed), Left(NotListed))
```

## See also

`Address.call` for a call to a process of another node, `monitor` for
learning that one ended or that its node went out of reach.

## Peer.Service

```ernest
abstract type Service(m)
```

A service as the node's peers name it: the name it is offered and found
under, and the hash of its message type, which the compiler gives where
the service is made. A `Service` is made by `service` alone, its type
abstract. It starts nothing, and crosses to other nodes as any value of
an unbound type does.

### Examples

```ernest
{
    let service : Peer.Service(Int) = Peer.service("squares");
    Peer.find(service, 0)
}
// => Left(NotListed)
```

## Peer.service

```ernest
Peer.service(name : String) : Service(m)
```

A service of the name, at the message type the compiler finds where it is
written, which is known whole there and crosses to other nodes. The
service holds the name and the type's hash, which a find compares. One
type has one hash whichever module writes the service.

### Examples

```ernest
{
    let service : Peer.Service(String) = Peer.service("names");
    Peer.find(service, 0)
}
// => Left(NotListed)
```

## Peer.name

```ernest
Peer.name(service : Service(m)) : String
```

The name the service was made with.

### Examples

```ernest
{
    let service : Peer.Service(Int) = Peer.service("squares");
    Peer.name(service)
}
// => "squares"
```

## Peer.offer

```ernest
Peer.offer(service : Service(m), address : Address(m)) : Either(Process, Unit)
```

Lets this node's peers find the address as the service, for as long as its
process lives, and answers `Right(Unit)`. The address names a process of
this node, an adapted address's target among them, and is offered at the
service's message type. Where a living process's address is offered under
the service's name and type already, the offer answers `Left(holder)`,
that process, which the caller may monitor and offer again at its end.

### Errors

An address of another node's process faults the caller with
`Fault("a node offers only its own processes")`.

### Examples

```ernest
{
    let service : Peer.Service(Int) = Peer.service("squares");
    let first = spawn(fn() : Unit receiving Int = receive {
        _ -> Unit
    });
    let second = spawn(fn() : Unit receiving Int = receive {
        _ -> Unit
    });
    #(Peer.offer(service, first),
      Peer.offer(service, second) == Left(Process.fromAddress(first)))
}
// => #(Right(Unit), true)
```

## Peer.find

```ernest
Peer.find(service : Service(m), ms : Int) : Either(Io.Error, Address(m))
```

The first address a peer `ernest.conf` lists for the service's name offers
under it at the service's type, by its hash, within `ms` milliseconds. The
peers are asked in the order the configuration lists them, each given the
time left, and one that cannot be reached, offers nothing under the name,
or offers it at a type of another hash, another version of the type, is
passed over; where no peer offers it, the last of these is answered, and
`Left(Timeout)` where the time runs out. A find meets `NotListed`,
`Unreachable`, `Timeout`, `NotOffered` and `OtherType`.

## Peer.spawn

```ernest
Peer.spawn(name : String, f : () -> Unit receiving m, ms : Int) : Either(Io.Error, Address(m))
```

A process started on the peer of that name, running `f`, its address
answered within `ms` milliseconds. `f` is a declaration's name, a lambda or
a `fn` written in the same definition, or `restarting` over one of these, as
report §3.11 says, and what it captured crosses to the peer; the peer's own
top-level bindings and system processes are those `f` reaches there. A peer
that lacks `f`, or a definition `f` reaches, is sent it before the process
starts, a function a shell typed among them. `f` runs only where every
top-level binding it reaches has its value on the peer and every module a
foreign declaration it reaches calls is there; otherwise the spawn answers
`NotLoaded`, and the peer says on its standard error what it lacked. A
binding `f` does not reach keeps it from no peer. A process whose answer
came too late is killed as it comes, and where the connection was lost
meanwhile it runs on. A spawn meets `NotListed`, `Unreachable`, `Timeout`,
`NotLoaded` and `Other`, the last where the peer cannot take the code it was
sent. `spawn` is called where it is named, and is no value.

## Peer.spawnMonitored

```ernest
Peer.spawnMonitored(name : String, f : () -> Unit receiving m, wrap : (Down) -> n, ms : Int) : Either(Io.Error, Address(m)) receiving n
```

As `spawn`, the caller monitoring the process from its start: `wrap(d)` is
placed in the caller's mailbox when it ends, or when its node goes out of
reach. A spawn that fails leaves no monitor.

### Examples

```ernest
Peer.spawnMonitored("worker", fn() = Unit, fn(down) = down, 5000)
```

## Peer.compute

```ernest
Peer.compute(f : () -> a receiving m, ms : Int) : Either(Io.Error, a)
```

The value of `f()`, run on a peer this node picks, as `computeAt` runs it
on the peer named. Of the peers whose utilizations the node holds, each
told within two of the intervals at which that peer tells, two are drawn
at random and the less busy taken, the first drawn of two equally busy;
a single one is taken as it is. Where no peer is listed the compute
answers `NotListed`, and where none has told a utilization the node may
use, `Unreachable`; once the peer is picked, the compute is `computeAt`'s,
and meets what it meets. `compute` is called where it is named, and is no
value.

### Errors

A fault in `f` faults the caller with its cause, as `computeAt` says.

### Examples

A value computed where there is room, or here where no peer has told how
busy it is, as in a program that is no node:

```ernest
match Peer.compute(fn() = 6 * 7, 5000) {
    Right(value) -> value
  | Left(_) -> 6 * 7
}
// => 42
```

## Peer.computeAt

```ernest
Peer.computeAt(name : String, f : () -> a receiving m, ms : Int) : Either(Io.Error, a)
```

The value of `f()`, run in a process started on the peer of that name as
`spawn` starts one, answered within `ms` milliseconds. `f` is what a spawn's
may be, as report §3.11 says, and its result type is known whole where
`computeAt` is written and is not bound to its node, since the value crosses
back. The peer runs `f` only where it would start it for a spawn; otherwise
the compute answers `NotLoaded`, and the peer says on its standard error
what it lacked. Where the process ends before it answers, killed or with the
peer's program, the compute answers `Left(Other(text))`, `text` its `Reason`
as `Io.show` writes it, `"Killed"` or `"ProgramEnd"`. Where the time runs
out, or the caller ends while it waits, the process is killed where it still
runs; where the connection was lost, it runs on. A compute meets
`NotListed`, `Unreachable`, `Timeout`, `NotLoaded` and `Other`. `computeAt`
is called where it is named, and is no value; work on the running node is
`f()`.

### Errors

A fault in `f` faults the caller with its cause, as if `f()` had faulted
in it. The caller's node reports it once, with the trace that crossed with
it, and the peer reports nothing of it.

### Examples

```ernest
Peer.computeAt("worker", fn() = 6 * 7, 5000)
// => Left(NotListed)
```

## Peer.utilization

```ernest
Peer.utilization(name : String, ms : Int) : Either(Io.Error, Float)
```

How busy the peer of that name is, answered within `ms` milliseconds: a
`Float` on one scale, 1.0 every scheduler busy, below it room, above it
work waiting. The peer measures it as its `ernest.conf`'s `utilization`
says: by default the processes running or ready to run, over its
schedulers, or the fraction of its schedulers' time spent running
processes since it last read it, which never passes 1.0 (report §12.8);
or, where the peer's program set one with `setUtilization`, that number.
A utilization asks the peer now, where `utilizations` answers what the
peers last told; it meets `NotListed`, `Unreachable` and `Timeout`.

### Examples

```ernest
Peer.utilization("worker", 1000)
// => Left(NotListed)
```

## Peer.peers

```ernest
Peer.peers() : List(String)
```

The names of the peers this node lists, in the configuration's order. The
running node is no peer of itself, and a program that is no node has none.

### Examples

```ernest
Peer.peers()
// => []
```

## Peer.utilizations

```ernest
Peer.utilizations() : List(#(String, Float, Int))
```

The utilizations this node holds of its peers, each peer's name, its
utilization as its last telling said it, and the milliseconds since the
telling came, in the configuration's order. Each peer tells it every
`utilization-interval` of its own `ernest.conf`; a peer not heard from
since its connection opened is left out, and so is one whose connection
was lost. A utilization older than two of its peer's intervals, which
`compute` does not use, is answered as it is, with its age, so that a
rule of the program's own sees what the node sees (report Appendix E.27).

### Examples

The work run on the least busy of the peers that told how busy they
are, or here, as in a program that is no node, which holds none:

```ernest
match List.sortBy(Peer.utilizations(), fn(#(_, utilization, _)) = utilization) {
    #(name, _, _) :: _ -> Peer.computeAt(name, fn() = 6 * 7, 5000)
  | [] -> Right(6 * 7)
}
// => Right(42)
```

## Peer.setUtilization

```ernest
Peer.setUtilization(utilization : Float) : Unit
```

Sets the utilization this node tells its peers, and answers them when
they ask, from now on and until it is set again or the program's run ends,
in place of the measure its `ernest.conf`'s `utilization` names, which the
node tells before the first and between two runs. `utilization` is on the
node's scale, at or above 0.0: 0.0 idle, 1.0 every scheduler busy, and above
it work waiting; what it counts, a queue's depth or work promised, is the
program's. The next telling carries it (report Appendix E.27). In a program
that is no node it is accepted, and no peer is told it.

### Errors

A number below 0.0 faults the caller with
`Fault("a utilization is 0.0 or above")`.

### Examples

```ernest
Peer.setUtilization(0.25)
// => Unit
```

---

Generated by ern 0.6.0-dev from src/stdlib/peer.ern.
