# Ernest module Tcp

*Since 0.1.0.*

TCP over its system process, which opens sockets (report §8.2).
A socket is a process: its address can be sent, monitored, killed, and
adapted with `via` like any other. It is owned by the process that
opened it, the caller of `accept` or `connect`, until `Tcp.give` gives
it another, and it lives until `Tcp.close` or until its owner dies,
which kills it; a read after its end faults. Once its connection has closed from the far
end, each read and each write answers `Left(Closed)`.
A listener lives until `Tcp.closeListener`. A read, an accept, or a
connect that times out has taken nothing, so bytes that arrive later
wait for the next read. There are no socket options; framing is
bitstrings (report §5.11). The last argument of a function that waits
is the milliseconds.

## Examples

A listener, a process that echoes what the connection it accepts sends,
and a connection to it, one message each way:

```ernest
{
    let listener <- Tcp.listen("127.0.0.1", 0);
    let port <- Tcp.port(listener);
    let _ = spawn(fn() = match Tcp.accept(listener, 1000) {
        Right(accepted) -> {
            let _ = match Tcp.read(accepted, 1000) {
                Right(bytes) -> Tcp.write(accepted, bytes, 1000)
              | Left(error) -> Left(error)
            };
            Tcp.close(accepted)
        }
      | Left(_) -> Unit
    });
    let client <- Tcp.connect("127.0.0.1", port, 1000);
    let _ <- Tcp.write(client, String.toUtf8("ping"), 1000);
    let received = Tcp.read(client, 1000);
    Tcp.close(client);
    Tcp.closeListener(listener);
    received
}
```

## See also

`Bytes` for what a socket carries, `monitor` for learning that a
socket was closed.

## Tcp.ListenerMsg

```ernest
abstract type ListenerMsg
```

What a listener takes; a program uses `Tcp.accept`, `Tcp.port`, and
`Tcp.closeListener` (report Appendix E.18).

### Examples

```ernest
{
    let listener <- Tcp.listen("127.0.0.1", 0);
    Tcp.closeListener(listener);
    Right(Unit)
}
```

## Tcp.SocketMsg

```ernest
abstract type SocketMsg
```

*Since 0.2.0.*

What a connected socket takes; a program uses `Tcp.read`, `Tcp.write`,
`Tcp.close`, `Tcp.give`, `Tcp.remote`, and `Tcp.local` (report Appendix
E.18).

### Examples

```ernest
Tcp.connect("127.0.0.1", 7000, 1000)
```

## Tcp.Endpoint

```ernest
type Endpoint = Endpoint(host : String, port : Int)
```

An end of a connection: the host's address as text, and the port.

### Examples

```ernest
Tcp.Endpoint(host = "127.0.0.1", port = 7000).port
// => 7000
```

## Tcp.listen

```ernest
Tcp.listen(host : String, port : Int) : Either(Io.Error, Address(ListenerMsg)) with m+
```

A listener on the port of the host's interface that the name or the
address names: `"127.0.0.1"` is the loopback alone, `"0.0.0.0"` every
interface of IPv4, and `"::"` every interface of IPv6. Port 0 asks the
system for a free one, which `Tcp.port` tells. The listener is owned
by the process that calls `listen`, and is killed when it dies.

## Tcp.port

```ernest
Tcp.port(listener : Address(ListenerMsg)) : Either(Io.Error, Int) with m+
```

The port the listener listens on.

### Errors

On a listener that has ended, closed or killed, faults as
`Address.callForever` does on an ended process.

### Examples

```ernest
{
    let listener <- Tcp.listen("127.0.0.1", 0);
    let port <- Tcp.port(listener);
    Tcp.closeListener(listener);
    Right(port > 0)
}
// => Right(true)
```

## Tcp.accept

```ernest
Tcp.accept(listener : Address(ListenerMsg), ms : Int) : Either(Io.Error, Address(SocketMsg)) with m+
```

The next connection to the listener, owned by the caller, or
`Left(Io.Timeout)` when none comes in time, having taken none;
`Left(Io.Closed)` when the listener is closed while it waits.

### Errors

On a listener that has ended, closed or killed, faults as
`Address.callForever` does on an ended process.

### Examples

```ernest
{
    let listener <- Tcp.listen("127.0.0.1", 0);
    let accepted = Tcp.accept(listener, 10);
    Tcp.closeListener(listener);
    accepted
}
```

## Tcp.connect

```ernest
Tcp.connect(host : String, port : Int, ms : Int) : Either(Io.Error, Address(SocketMsg)) with m+
```

A connection to that host and port, owned by the caller, or
`Left(Io.Timeout)` when it is not made in time; one made later is
closed.

## Tcp.read

```ernest
Tcp.read(socket : Address(SocketMsg), ms : Int) : Either(Io.Error, Bytes) with m+
```

What has arrived, at least one byte, or `Left(Io.Closed)` once the
connection has closed and what came before is read, or
`Left(Io.Timeout)` when nothing comes in time, having taken nothing.

### Errors

On a socket that has ended, closed or killed, faults as
`Address.callForever` does on an ended process.

## Tcp.write

```ernest
Tcp.write(socket : Address(SocketMsg), bytes : Bytes, ms : Int) : Either(Io.Error, Unit) with m+
```

Writes the bytes to the socket, and answers `Right(Unit)` once the
socket has taken them, waiting while the connection is behind, at most
`ms` milliseconds. That the socket took them does not mean that the far
end has them. It answers `Left(Io.Timeout)` when `ms` milliseconds pass
first, which does not undo the write: the bytes may still be sent, after
those written before. It answers `Left(Io.Closed)` once the connection
has closed, from either end or by a failure, and `Left(Io.Other(text))`,
the host's reason, when the host refuses the bytes for another.

### Errors

On a socket that has ended, closed or killed, faults as
`Address.callForever` does on an ended process.

## Tcp.close

```ernest
Tcp.close(socket : Address(SocketMsg)) : Unit with m+
```

Closes the socket, which ends its process.

## Tcp.give

```ernest
Tcp.give(socket : Address(SocketMsg), owner : Process) : Unit with m+
```

Makes the process the socket's owner, so that the socket is killed when
that process dies and no longer when the one before did; a process that
has ended already takes it with it at once. Nothing happens on a socket
that has ended.

### Examples

```ernest
{
    let listener <- Tcp.listen("127.0.0.1", 0);
    let port <- Tcp.port(listener);
    let client <- Tcp.connect("127.0.0.1", port, 1000);
    let keeper = spawn(fn() : Unit with Never = receive {
        after 1000 -> Unit
    });
    Tcp.give(client, Process.fromAddress(keeper));
    Tcp.close(client);
    Tcp.closeListener(listener);
    Right(Unit)
}
```

## Tcp.closeListener

```ernest
Tcp.closeListener(listener : Address(ListenerMsg)) : Unit with m+
```

Stops the listener, which ends its process; an accept waiting on it
answers `Left(Io.Closed)`.

## Tcp.remote

```ernest
Tcp.remote(socket : Address(SocketMsg)) : Either(Io.Error, Endpoint) with m+
```

*Since 0.2.0.*

The connection's far end, or `Left(Io.Closed)` once the connection has
closed.

### Errors

On a socket that has ended, closed or killed, faults as
`Address.callForever` does on an ended process.

### Examples

```ernest
{
    let listener <- Tcp.listen("127.0.0.1", 0);
    let port <- Tcp.port(listener);
    let client <- Tcp.connect("127.0.0.1", port, 1000);
    let far = Tcp.remote(client);
    Tcp.close(client);
    Tcp.closeListener(listener);
    Either.map(far, fn(endpoint) = endpoint.port == port)
}
// => Right(true)
```

## Tcp.local

```ernest
Tcp.local(socket : Address(SocketMsg)) : Either(Io.Error, Endpoint) with m+
```

The connection's near end, or `Left(Io.Closed)` once the connection has
closed.

### Errors

On a socket that has ended, closed or killed, faults as
`Address.callForever` does on an ended process.

### Examples

```ernest
{
    let listener <- Tcp.listen("127.0.0.1", 0);
    let port <- Tcp.port(listener);
    let client <- Tcp.connect("127.0.0.1", port, 1000);
    let near = Tcp.local(client);
    Tcp.close(client);
    Tcp.closeListener(listener);
    Either.map(near, fn(endpoint) = endpoint.host)
}
// => Right("127.0.0.1")
```

---

Generated by ern 0.3.0 from tcp.ern.
