# Ernest module Tcp

*Since 0.1.0.*

TCP connections: listening for them, making them, and moving their bytes.

Use `listen` and `accept` to serve connections, and `connect` to make one.
`read` and `write` move bytes over a connection, and `close` ends it. A
connection carries bytes, and a program frames its messages with bitstrings
(report §5.11); there are no socket options.

**A socket is a process.** `accept` and `connect` answer a socket's address.
It can be sent in a message and killed like any other, and
`monitor(Process.fromAddress(socket), wrap)` tells when it ends. A listener
is a process too.

**Ownership.** A socket belongs to the process that opened it, and is killed
when its owner dies. Ownership decides only that: any process that holds the
address may read, write and close it. `give` hands a socket to another
process, so that it dies with that one instead, as an accepting loop gives
each socket to the process that serves it. A listener belongs to the process
that called `listen`.

**A connection that closes, and a socket that ends.** When the far end
closes the connection, or the network fails, the socket lives on: each read
answers `Left(Closed)` once what came before is read, and each write answers
`Left(Closed)`. The socket ends only with `close` or its owner's death, and
a listener with `closeListener` or its owner's death. A read waiting when
`close` ends the socket answers `Left(Closed)`, and a call after the end
faults.

**A wait that times out takes nothing.** The last argument of a function
that waits is the milliseconds it waits. A read, an accept or a connect that
times out has taken nothing, so bytes that arrive later wait for the next
read (report Appendix E.18).

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
// => Right(<<112, 105, 110, 103>>)
```

## See also

`Bytes` for what a socket carries, `monitor` for learning that a socket
has ended.

## Tcp.ListenerMsg

```ernest
abstract type ListenerMsg
```

What a listener's process takes. Its constructors are hidden, so a program
uses `Tcp.accept`, `Tcp.port` and `Tcp.closeListener` on it (report Appendix
E.18).

### Examples

A listener's address, which `accept`, `port` and `closeListener` take:

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

What a connected socket's process takes. Its constructors are hidden, so a
program uses `Tcp.read`, `Tcp.write`, `Tcp.close`, `Tcp.give`, `Tcp.remote`
and `Tcp.local` on it (report Appendix E.18).

### Examples

A socket's address, which `read`, `write`, `close`, `give`, `remote` and
`local` take:

```ernest
Tcp.connect("127.0.0.1", 7000, 1000)
```

## Tcp.Endpoint

```ernest
type Endpoint = Endpoint(host : String, port : Int)
```

One end of a connection: the host's address as text, and the port.

### Examples

```ernest
Tcp.Endpoint(host = "127.0.0.1", port = 7000).port
// => 7000
```

## Tcp.listen

```ernest
Tcp.listen(host : String, port : Int) : Either(Io.Error, Address(ListenerMsg)) with m+
```

Listens for connections on `port` of the interface `host` names, and answers
the listener's address.

`host` is an address or a name: `"127.0.0.1"` is the loopback alone,
`"0.0.0.0"` every interface of IPv4, and `"::"` every interface of IPv6. A
name is looked up, its IPv4 address before its IPv6 one. Port 0 asks the
host for a free port, which `port` tells. The listener belongs to the
process that calls `listen`, and is killed when that process dies.

It answers `Left(Invalid)` for a port outside 0 to 65535 or a host that
holds U+0000, and `Left(Other(text))` where the host refuses, in the host's
words: `Left(Other("address already in use"))` for a port another listener
holds, `Left(Other("non-existing domain"))` for a name not found.

## Tcp.port

```ernest
Tcp.port(listener : Address(ListenerMsg)) : Either(Io.Error, Int) with m+
```

The port the listener listens on: the one `listen` was given, or the one the
host chose for port 0. While the listener lives it answers a `Right`.

### Errors

Faults where the listener has ended, as `Address.callForever` does: with the
cause `callee had ended`, or `callee was closed` where `closeListener` ended
it as the call was made.

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

Waits at most `ms` milliseconds for the next connection to the listener, and
answers its socket, which belongs to the caller. It answers `Left(Timeout)`
where none comes in time, having taken none, and `Left(Closed)` where the
listener is closed while it waits.

### Errors

Faults where the listener has ended, as `Address.callForever` does: with the
cause `callee had ended`, or `callee was closed` where `closeListener` ended
it as the call was made.

### Examples

No connection comes within 10 milliseconds:

```ernest
{
    let listener <- Tcp.listen("127.0.0.1", 0);
    let accepted = Tcp.accept(listener, 10);
    Tcp.closeListener(listener);
    accepted
}
// => Left(Timeout)
```

## Tcp.connect

```ernest
Tcp.connect(host : String, port : Int, ms : Int) : Either(Io.Error, Address(SocketMsg)) with m+
```

Connects to `port` on `host`, within `ms` milliseconds, and answers the
socket, which belongs to the caller. `host` is an address or a name, as
`listen` takes it.

It answers `Left(Timeout)` where the connection is not made in time, and
closes one made later. It answers `Left(Refused)` where nothing listens
there, `Left(Invalid)` for a port outside 0 to 65535 or a host that holds
U+0000, and `Left(Other(text))` for the host's other reasons,
`Left(Other("non-existing domain"))` for a name not found.

## Tcp.read

```ernest
Tcp.read(socket : Address(SocketMsg), ms : Int) : Either(Io.Error, Bytes) with m+
```

Waits at most `ms` milliseconds for bytes from the connection, and answers
what has arrived, at least one byte. It answers `Left(Closed)` once the
connection has closed and all that came before is read, and `Left(Timeout)`
where nothing comes in time, having taken nothing.

### Errors

Faults where the socket has ended, as `Address.callForever` does: with the
cause `callee had ended`, or `callee was closed` where `close` ended it as
the call was made.

## Tcp.write

```ernest
Tcp.write(socket : Address(SocketMsg), bytes : Bytes, ms : Int) : Either(Io.Error, Unit) with m+
```

Writes `bytes` to the connection, and answers `Right(Unit)` once the socket
has taken them, waiting while the connection is behind, at most `ms`
milliseconds. That the socket took them does not mean that the far end has
them.

It answers `Left(Timeout)` where the milliseconds pass first, which does not
undo the write: the bytes may still be sent, after those written before. It
answers `Left(Closed)` once the connection has closed, from either end or by
a failure, and `Left(Other(text))` where the host refuses the bytes for
another reason, in its words.

### Errors

Faults where the socket has ended, as `Address.callForever` does: with the
cause `callee had ended`, or `callee was closed` where `close` ended it as
the call was made.

## Tcp.close

```ernest
Tcp.close(socket : Address(SocketMsg)) : Unit with m+
```

Closes the connection and ends the socket's process. On a socket that has
ended already it does nothing.

## Tcp.give

```ernest
Tcp.give(socket : Address(SocketMsg), owner : Process) : Unit with m+
```

Makes `owner` the socket's owner, so that the socket is killed when `owner`
dies, and no longer when the owner before did. Where `owner` has ended
already the socket is killed at once. On a socket that has ended it does
nothing.

### Examples

A connection given to the process that serves it, so that the socket dies
with its session; the session greets the client and closes:

```ernest
{
    let listener <- Tcp.listen("127.0.0.1", 0);
    let port <- Tcp.port(listener);
    let client <- Tcp.connect("127.0.0.1", port, 1000);
    let socket <- Tcp.accept(listener, 1000);
    let session = spawn(fn() : Unit with Never = {
        let _ = Tcp.write(socket, String.toUtf8("hello"), 1000);
        Tcp.close(socket)
    });
    Tcp.give(socket, Process.fromAddress(session));
    let greeting = Tcp.read(client, 1000);
    Tcp.close(client);
    Tcp.closeListener(listener);
    greeting
}
// => Right(<<104, 101, 108, 108, 111>>)
```

## Tcp.closeListener

```ernest
Tcp.closeListener(listener : Address(ListenerMsg)) : Unit with m+
```

Stops the listener and ends its process. An `accept` waiting on it answers
`Left(Closed)`. On a listener that has ended already it does nothing.

## Tcp.remote

```ernest
Tcp.remote(socket : Address(SocketMsg)) : Either(Io.Error, Endpoint) with m+
```

*Since 0.2.0.*

The far end of the connection, or `Left(Closed)` once the connection has
closed.

### Errors

Faults where the socket has ended, as `Address.callForever` does: with the
cause `callee had ended`, or `callee was closed` where `close` ended it as
the call was made.

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

The near end of the connection, or `Left(Closed)` once the connection has
closed.

### Errors

Faults where the socket has ended, as `Address.callForever` does: with the
cause `callee had ended`, or `callee was closed` where `close` ended it as
the call was made.

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

Generated by ern 0.3.1 from tcp.ern.
