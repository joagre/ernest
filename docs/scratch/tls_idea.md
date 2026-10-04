# TLS beside `Tcp`: an idea, and whether an operations record fits

*A working note of 2026-10-04, not a decision. Nothing here is built. The plan owns the decision: it names a TLS library under MVP 3.2 and leaves open whether a TLS socket is `Tcp`'s socket type or one of its own. This note argues one answer, and reports an experiment with the other. A link marked* report *leads to the section of Ernest's language report that states the rule.*

## What exists

The standard library has `Tcp` ([report E.18](https://github.com/joagre/ernest/blob/main/report/library.md#appendix-e18-tcpern-namespace-tcp)). Four facts about it carry the question.

- **A socket is a process.** `Tcp.connect` and `Tcp.accept` answer an `Address(Tcp.SocketMsg)`, and `Tcp.read`, `Tcp.write` and `Tcp.close` send to that address or call it. A socket can be sent, monitored and killed as any process can.
- **`SocketMsg` is an abstract type.** Its constructors are `Tcp`'s alone ([report §4.4](https://github.com/joagre/ernest/blob/main/report/language.md#44-abstract-types)), so no other module can make a message a socket takes, and no process outside the runtime can pass for a socket.
- **`Tcp` has no options.** A program frames its own protocol; the socket carries bytes.
- **The socket process is the runtime's**, written in Erlang over `gen_tcp`.

Two things beyond `Tcp` bear on it. Erlang's `ssl` can turn a connected TCP socket into a TLS one, on the client's side and on the server's. And the planned peers (MVP 3.0) speak TLS to each other inside the runtime, so the runtime comes to depend on `ssl` either way.

## The question

Is a TLS socket the same type as a TCP socket, or a type of its own?

Everything else follows from the answer: where the code lives, what a library over a byte stream is written against, and how much a program writes.

## Design A: one socket type, upgraded in place

`Tls` adds no `listen`, `accept` or `connect`. A program opens a connection with `Tcp` and then asks for TLS on it:

```ernest-fragment
Tls.client : (Address(Tcp.SocketMsg), Tls.Trust, Int) -> Either(Io.Error, Unit) with m
Tls.server : (Address(Tcp.SocketMsg), Tls.Identity, Int) -> Either(Io.Error, Unit) with m

type Trust = System(host : String) | Pinned(certificate : Bytes) | Unverified
type Identity = Identity(certificate : Bytes, key : Bytes)
```

After `Tls.client(socket, Tls.System("example.org"), 5000)` answers `Right(Unit)`, the same address carries encrypted bytes, and `Tcp.read`, `Tcp.write`, `Tcp.close`, `Tcp.give` and `Tcp.remote` serve it as before. The last argument is the handshake's limit in milliseconds, as every waiting function of the library takes one.

**Where it lives.** In the standard library, as `tls.ern` beside `tcp.ern`, with the transport inside the runtime's socket process. Only that process can answer `SocketMsg`, and the handshake is work the host alone can do, which is the standard library's first admission rule ([report E.0](https://github.com/joagre/ernest/blob/main/report/library.md#appendix-e0-rules)). `Tls.client` and `Tls.server` are primitives that reach the socket process, as `Tcp.listen` and `Tcp.connect` reach TCP's.

**The policy is an argument.** What argued for a library was that TLS carries choices. The `Trust` value puts the choice at the call, where a reader sees it:

- `System(host)`: the operating system's certificate store, the host name checked, and the name sent to the server.
- `Pinned(certificate)`: one certificate and nothing else.
- `Unverified`: no check, written in full by the program that wants it.

The plan's sentence today is "Certificate verification is the caller's to ask for". This design reverses it: verification is what the short spelling gives, and its absence is what must be asked for. Protocol versions and ciphers are the host's defaults, with no option, as `Tcp` has none.

**For it.**

- One way to read and write a byte stream. A library over a stream, an HTTP client first, is written once and does not know which it has.
- It is what an address already means in Ernest. The type of an address is the protocol its process speaks, and a TLS socket speaks the same protocol as a TCP one: read, write, close. Two processes of different representation behind one message type is how a service with state varies in Ernest ([report §6.5](https://github.com/joagre/ernest/blob/main/report/language.md#65-addresses) has the address and its type).
- The smallest surface: two functions and two types.
- A protocol that begins in the clear and then switches, SMTP's STARTTLS or PostgreSQL's, needs nothing more.

**Against it.**

- TLS enters the standard library and the runtime, where the plan had it as a library. The standard library grows by a module whose subject is a published protocol.
- The runtime's socket process must carry two transports, `gen_tcp` and `ssl`.
- A type does not say whether a socket is encrypted. A function that must have TLS cannot ask for it in its signature.
- No third party can supply a socket of another kind, an in-memory one for a test, since `SocketMsg` is `Tcp`'s. That is true today without TLS.

## Design B: a socket type of its own, and an operations record

Here `Tls` is a library with its own `Tls.SocketMsg` and its own `read`, `write` and `close`, and `Tcp` is untouched. Code over both is written once through a record of functions ([report §4.9](https://github.com/joagre/ernest/blob/main/report/language.md#49-requirements)). The experiment below asked whether that works and what it costs.

### The experiment

A stand-in module, `Secure`, declares a socket type of its own and `read`, `write` and `close` with `Tcp`'s names and parameter orders. It does no TLS; it stands for a module that would. Both programs below were compiled and run with the toolchain as it stands on 2026-10-04.

**An operations record**, the operations beside the data:

```ernest-fragment
type Stream(s, m) =
    Stream(read : (s, Int) -> Either(Io.Error, Bytes) with m,
           write : (s, Bytes, Int) -> Either(Io.Error, Unit) with m,
           close : (s) -> Unit with m)

fn plain() : Stream(Address(Tcp.SocketMsg), m) = Stream(..Tcp)

fn secure() : Stream(Address(Secure.SocketMsg), m) = Stream(..Secure)

fn echoed(stream : Stream(s, m), near : s, far : s) : Either(Io.Error, Bytes) with m = {
    let _ = stream.write(near, String.toUtf8("hi"), 1000);
    let got = stream.read(far, 1000);
    stream.close(near);
    stream.close(far);
    got
}
```

Over a real loopback connection, `echoed(plain(), near, far)` printed `Right(<<104, 105>>)`, the bytes of `hi`.

**A record of closures**, each value carrying its operations:

```ernest-fragment
type Connection(m) =
    Connection(read : (Int) -> Either(Io.Error, Bytes) with m,
               write : (Bytes, Int) -> Either(Io.Error, Unit) with m,
               close : () -> Unit with m)

fn plain(socket : Address(Tcp.SocketMsg)) : Connection(m) =
    Connection(read = fn(ms) = Tcp.read(socket, ms),
               write = fn(bytes, ms) = Tcp.write(socket, bytes, ms),
               close = fn() = Tcp.close(socket))

fn greet(connection : Connection(m)) : Either(Io.Error, Unit) with m =
    connection.write(String.toUtf8("hi"), 1000)
```

This ran too, with the same output.

### What the experiment showed

- **Both forms work today, with no change to the language.** The fill takes `read`, `write` and `close` from each module by name.
- **The record needs the effect as a parameter.** Each operation acts through its caller's process, so its type carries `with m`, and a record's fields may name only the record's parameters. Without `m` the declaration is refused: `type variable m is not a parameter of the type`. So the record is `Stream(s, m)`, and every function over it is generic in both.
- **The fill holds the two modules to one vocabulary.** `Stream(..Secure)` is accepted only because `Secure` names its functions as `Tcp` does, with the same parameter orders. A TLS library would be bound to `Tcp`'s names by every program's record, and nothing in either module says so.
- **Every function over a stream gains a parameter.** With the operations record it takes the record and the socket, `echoed(stream, near, far)`, and its signature gains `s` and `m`. An HTTP client's every function would carry them.
- **For sockets, the closure form is the better of the two.** An operations record earns its type parameter where an operation must see inside two values of one representation, as a union of two sets does. No operation on sockets takes two: a socket is read, written and closed alone. The closure form hides the socket's type, lets a list hold connections of both kinds, and passes one value where the other passes two.
- **What is not read, write or close stays outside either record.** `Tcp.give`, `Tcp.remote`, `Tcp.local`, monitoring the socket's process and killing it need the address, so the record grows a field for each, or the program keeps the address beside the record.

### For and against

**For it.**

- TLS stays a library. The standard library and the runtime's socket process do not change, and the abstract boundary of `SocketMsg` is respected with no private encoding shared.
- A function can require TLS in its signature, since the type differs.
- A record of closures admits what design A cannot: a connection that is no socket at all. A test of an HTTP client could run over a `Connection` built from two lists of bytes, with no network.

**Against it.**

- Two ways to read a byte stream, `Tcp.read` and `Tls.read`, and a third spelling through the record. Ernest's second principle is one way for one job.
- Every program that wants code over both declares the record, since the standard library declares none ([report E.0](https://github.com/joagre/ernest/blob/main/report/library.md#appendix-e0-rules), rule 4). Two libraries over streams would each declare their own, and a program using both would convert between them.
- The record does the work the address already does. `Address(SocketMsg)` is a value that carries its operations, dispatched by the process behind it. Wrapping it in a record of closures builds by hand what the process model gives.
- A STARTTLS upgrade changes the socket's type in the middle of a conversation, so the program holds a new value and the old one must not be used again, which nothing checks.

## Verdict

Design A. An operations record is the right tool for pure data in several representations, where the representations must meet. A socket is not that. It is a process, and a process already hides its representation behind its message type: that is the form the language has for a service whose implementation varies. A TLS socket and a TCP socket are one protocol with two implementations, which is one address type.

The experiment is still worth keeping for one thing. A record of closures over a connection is the way to give a library a connection that is no socket, for a test. That is a decision for the HTTP library when it is written, and it is independent of TLS: with design A such a record would have one constructor function over `Tcp`, not two.

## Not checked, and open

- How much of the runtime's socket process changes when the transport beneath it is `ssl`. It reads with the socket in passive mode and switches to one message at a time while a read waits; `ssl` offers both, but the code was not read with that in mind.
- Whether `ssl`, `crypto` and `public_key` are in a release as it is built today, and what starting them costs a program that never uses TLS. Starting them at the first `Tls` call would cost such a program nothing.
- The form of `Identity` and of `Pinned`'s certificate: PEM bytes as read from a file is the guess here.
- Client certificates, protocol negotiation (ALPN) and session resumption. None is in the sketch. The peers of MVP 3.0 authenticate both sides and do so inside the runtime, not through this module.
- What a socket is after a handshake that fails. The guess is that it is closed, and each later `Tcp.read` answers `Left(Closed)`.
- Whether `Tls` in the standard library is acceptable at all, against the rule that a published protocol is a library's work. The argument here is that the protocol is the host's and the module is two primitives; the counter-argument is the line the plan drew.
