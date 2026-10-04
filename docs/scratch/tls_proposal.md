# TLS for Ernest: a proposal

*A working note of 2026-10-04, not a decision. Nothing here is built. The plan owns the decision: it names a TLS library under MVP 3.2 and leaves open whether a TLS socket is `Tcp`'s socket type or one of its own. This note proposes an answer. A link marked* report *leads to the section of Ernest's language report that states the rule.*

## The proposal in short

1. **A TLS socket is a `Tcp` socket.** One type, `Address(Tcp.SocketMsg)`, and `Tcp.read`, `Tcp.write` and `Tcp.close` serve both.
2. **TLS is an upgrade of a connected socket.** A program connects or accepts with `Tcp`, then calls `Tls.client` or `Tls.server` on the socket.
3. **Trust is an argument.** The call says which certificates it accepts, and accepting any is spelled `Unverified`.
4. **`Tls` is a module of the standard library**, two functions and two types, with the transport inside the runtime's socket process.
5. **It is built on Erlang's `ssl`**, and no part of TLS is written in Ernest. That is an exception to the rule that Ernest is used wherever it can express the work, taken for security, and recorded as one.
6. **No operations record.** One was tried for this and works, but the address already does its job. The last section reports the experiment.

## What exists

The standard library has `Tcp` ([report E.18](https://github.com/joagre/ernest/blob/main/report/library.md#appendix-e18-tcpern-namespace-tcp)). Four facts about it carry the design.

- **A socket is a process.** `Tcp.connect` and `Tcp.accept` answer an `Address(Tcp.SocketMsg)`, and `Tcp.read`, `Tcp.write` and `Tcp.close` send to that address or call it. A socket can be sent, monitored and killed as any process can.
- **`SocketMsg` is an abstract type.** Its constructors are `Tcp`'s alone ([report §4.4](https://github.com/joagre/ernest/blob/main/report/language.md#44-abstract-types)), so no other module can make a message a socket takes, and no process outside the runtime can pass for a socket.
- **`Tcp` has no options.** A program frames its own protocol; the socket carries bytes.
- **The socket process is the runtime's**, written in Erlang over `gen_tcp`.

Two things beyond `Tcp` bear on it. Erlang's `ssl` can turn a connected TCP socket into a TLS one, on the client's side and on the server's. And the planned peers (MVP 3.0) speak TLS to each other inside the runtime, so the runtime comes to depend on `ssl` either way.

## The module

```ernest-fragment
Tls.client : (Address(Tcp.SocketMsg), Tls.Trust, Int) -> Either(Io.Error, Unit) with m
Tls.server : (Address(Tcp.SocketMsg), Tls.Identity, Int) -> Either(Io.Error, Unit) with m

type Trust = System(host : String) | Pinned(certificate : Bytes) | Unverified
type Identity = Identity(certificate : Bytes, key : Bytes)
```

`Tls` has no `listen`, `accept` or `connect`; those stay `Tcp`'s. The last argument of each function is the handshake's limit in milliseconds, as every waiting function of the library takes one.

A client:

```ernest-fragment
fn fetch(host : String) : Either(Io.Error, Bytes) with m = {
    let socket <- Tcp.connect(host, 443, 5000);
    let _ <- Tls.client(socket, Tls.System(host), 5000);
    let _ <- Tcp.write(socket, request(host), 5000);
    let bytes = Tcp.read(socket, 5000);
    Tcp.close(socket);
    bytes
}
```

A server, for one connection:

```ernest-fragment
fn serve(listener : Address(Tcp.ListenerMsg), identity : Tls.Identity)
    : Either(Io.Error, Unit) with m = {
    let socket <- Tcp.accept(listener, 60000);
    let _ <- Tls.server(socket, identity, 5000);
    let _ <- Tcp.write(socket, String.toUtf8("hello\n"), 5000);
    Tcp.close(socket);
    Right(Unit)
}
```

Both are the plain-TCP programs with one line added. Without the `Tls` line each compiles and runs today.

### What the functions promise

- **After `Right(Unit)`** the same address carries encrypted bytes. `Tcp.read` answers what the far end sent in the clear, `Tcp.write` encrypts, `Tcp.close` ends the session and the connection, and `Tcp.give`, `Tcp.remote` and `Tcp.local` are unchanged. The socket's owner and its lifetime are as before.
- **After `Left(error)`** the socket is closed, and each later `Tcp.read` answers `Left(Closed)`. A handshake that failed leaves no half-encrypted socket to use by mistake.
- **A second upgrade** of one socket answers `Left`.
- **Bytes already read** before the upgrade stay read. A protocol that begins in the clear and then switches, SMTP's STARTTLS or PostgreSQL's, reads its preamble with `Tcp.read`, calls `Tls.client`, and goes on.

### Trust

What argued for a library was that TLS carries choices. The `Trust` value puts the choice at the call, where a reader sees it:

- `System(host)`: the operating system's certificate store, the host name checked, and the name sent to the server.
- `Pinned(certificate)`: one certificate and nothing else.
- `Unverified`: no check, written in full by the program that wants it.

The plan's sentence today is "Certificate verification is the caller's to ask for". The proposal reverses it: verification is what the short spelling gives, and its absence is what must be asked for. Protocol versions and ciphers are the host's defaults, with no option, as `Tcp` has none.

`Identity` holds a server's certificate and its private key as PEM bytes, read with `Fs.read` from wherever the program keeps them.

## Where it lives, and why

In the standard library, as `tls.ern` beside `tcp.ern`. Two rules decide it.

- **Only the runtime's socket process can answer `SocketMsg`.** A library outside could give a TLS socket `Tcp`'s type only by copying an encoding private to `Tcp`, which is the coupling the abstract boundary exists to prevent.
- **TLS is the host's implementation and not ours**, for the reasons the next section gives. `Tls.client` and `Tls.server` are primitives that reach the socket process, as `Tcp.listen` and `Tcp.connect` reach TCP's, so the module holds two doors to the host and no protocol.

## What it is built on

There are two ways to build it.

1. **A shim over `ssl`.** The runtime's socket process calls Erlang's `ssl` application, which brings `crypto` and `public_key` with it as its own dependencies. A program sees none of the three, only `Tls.client` and `Tls.server`.
2. **TLS written in Ernest over new libraries.** A `Crypto` library gives the primitives, the ciphers, the key exchange, the signatures and the hashes; a `PublicKey` library reads certificates; and the handshake, the record layer and the validation of a certificate chain are Ernest code over them.

**What the project's rules say.** Read strictly, they point to the second. A `foreign fn` is admitted where Ernest cannot express the work given the layers beneath it ([report E.0](https://github.com/joagre/ernest/blob/main/report/library.md#appendix-e0-rules), rule 1), and given the primitives beneath it a TLS handshake is ordinary programming: a state machine, some parsing, some framing of bytes. Erlang's own `ssl` is that, Erlang over `crypto`. So "the host alone can do it" is not the reason for the shim.

**Why the proposal takes the first all the same.**

- **A defect in a TLS implementation is a security hole.** Validating a certificate chain, refusing a downgrade and handling alerts are where implementations have failed for twenty years. `ssl` has had that hardening, and one written here would begin without it.
- **Constant time cannot be promised.** Some comparisons must take the same time whatever their input, or they leak a secret. Nothing in Ernest, or in the Erlang machine beneath it, promises that of code a program writes.
- **It does not end.** Each new attack on TLS would be this project's to answer, for a language whose subject is something else.
- **It is large.** A TLS 1.3 client alone, with the parsing of certificates and the validation of their chain, is thousands of lines before a first HTTPS request is answered.
- **The runtime uses `ssl` in any case.** The peers of MVP 3.0 speak to each other over `ssl` inside the runtime, and two implementations of TLS in one system are worse than one.

The reason is that Ernest should not write TLS, not that it cannot. That is an exception to the `foreign` rule, and it is recorded as one, with this argument, in the decisions log, as each departure from a rule is. Performance is no part of the argument.

**The libraries.**

- **`Crypto` stands on its own.** The plan names it for hashes, HMAC and random bytes, which programs want whether or not they use TLS. `Tls` does not depend on it.
- **No `PublicKey` library is needed.** `Pinned` and `Identity` take PEM bytes, read with `Fs.read`, and the runtime hands them to the host.
- **Nothing of `ssl`, `crypto` or `public_key` shows in an Ernest signature.** The module's types are `Trust`, `Identity`, `Io.Error` and `Tcp`'s socket.

### What it takes to build

- **The socket process learns a second transport.** It touches its socket in about ten places: sending, closing, asking for the next message, the three messages a socket delivers, the two endpoint queries, the pending-bytes check before a close, and handing the socket to another process. `ssl` has a counterpart for each. The state gains one field, which transport, set by the upgrade. This is an estimate from the calls the file makes, not from a reading of its logic.
- **`ssl` is started at the first `Tls` call**, with `crypto` and `public_key`, so a program that never uses TLS pays nothing at startup.
- **A release depends on the host's `ssl` application.** Ernest runs on the Erlang/OTP installed on the machine. `ssl` is part of standard OTP, and some distributions package it apart; where it is missing, `Tls.client` answers `Left` naming it.
- **The report gains a section for `tls.ern`** at the end of Appendix E, and E.18 a sentence that a socket may have been upgraded. The plan's MVP 3.2 loses its TLS library, and its HTTP library is written over `Tcp` alone.

## For and against

**For it.**

- One way to read and write a byte stream. A library over a stream, an HTTP client first, is written once and does not know which it has.
- It is what an address already means in Ernest. The type of an address is the protocol its process speaks, and a TLS socket speaks the same protocol as a TCP one: read, write, close. Two processes of different representation behind one message type is how a service with state varies in Ernest ([report §6.5](https://github.com/joagre/ernest/blob/main/report/language.md#65-addresses) has the address and its type).
- The smallest surface: two functions and two types.
- STARTTLS needs nothing more.

**Against it.**

- TLS enters the standard library and the runtime, where the plan had it as a library.
- The runtime's socket process carries two transports.
- A type does not say whether a socket is encrypted, so a function that must have TLS cannot ask for it in its signature. A query, `Tls.secured(socket) : Bool`, would let it check; it is not in the proposal, and is the first thing to add if a program needs it.
- No third party can supply a socket of another kind, an in-memory one for a test, since `SocketMsg` is `Tcp`'s. That is true today without TLS; the next section has an answer for the library that wants one.

## Considered and not taken: a socket type of its own, with an operations record

The alternative is a `Tls` library with its own `Tls.SocketMsg` and its own `read`, `write` and `close`, `Tcp` untouched, and code over both written once through a record of functions ([report §4.9](https://github.com/joagre/ernest/blob/main/report/language.md#49-requirements)). It was tried.

### The experiment

A stand-in module, `Secure`, declares a socket type of its own and `read`, `write` and `close` with `Tcp`'s names and parameter orders. It does no TLS; it stands for a module that would. Both programs below were compiled and run with the toolchain as it stands on 2026-10-04, over a real loopback connection, and each printed `Right(<<104, 105>>)`, the bytes of `hi`.

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

### What it showed

- **Both forms work today, with no change to the language.** The fill takes `read`, `write` and `close` from each module by name.
- **The record needs the effect as a parameter.** Each operation acts through its caller's process, so its type carries `with m`, and a record's fields may name only the record's parameters. Without `m` the declaration is refused: `type variable m is not a parameter of the type`. So the record is `Stream(s, m)`, and every function over it is generic in both.
- **The fill holds the two modules to one vocabulary.** `Stream(..Secure)` is accepted only because `Secure` names its functions as `Tcp` does, with the same parameter orders. A TLS library would be bound to `Tcp`'s names by every program's record, and nothing in either module says so.
- **Every function over a stream gains a parameter.** With the operations record it takes the record and the socket, and its signature gains `s` and `m`. An HTTP client's every function would carry them.
- **For sockets, the closure form is the better of the two.** An operations record earns its type parameter where an operation must see inside two values of one representation, as a union of two sets does. No operation on sockets takes two.
- **What is not read, write or close stays outside either record.** `Tcp.give`, `Tcp.remote`, `Tcp.local`, monitoring the socket's process and killing it need the address.

### Why it is not taken

- **Two ways to read a byte stream**, `Tcp.read` and `Tls.read`, and a third spelling through the record. Ernest's second principle is one way for one job.
- **Every program declares the record**, since the standard library declares none ([report E.0](https://github.com/joagre/ernest/blob/main/report/library.md#appendix-e0-rules), rule 4). Two libraries over streams would each declare their own.
- **The record does the work the address already does.** `Address(SocketMsg)` is a value that carries its operations, dispatched by the process behind it. A record of closures around it builds by hand what the process model gives.
- **A STARTTLS upgrade would change the socket's type** in the middle of a conversation, leaving an old value that must not be used again, which nothing checks.

An operations record is the right tool for pure data in several representations, where the representations must meet. A socket is a process, and a process already hides its representation behind its message type.

### What is kept from it

A record of closures admits a connection that is no socket at all. A test of an HTTP client could run over a `Connection` built from two lists of bytes, with no network. That is a decision for the HTTP library when it is written, and it is independent of TLS: under this proposal the record has one constructor function over `Tcp`, which serves plain and encrypted sockets alike.

## Left out, and open

- **Client certificates, protocol negotiation (ALPN) and session resumption** are not in the proposal. ALPN comes with HTTP/2, if that is ever wanted. The peers of MVP 3.0 authenticate both sides, and do so inside the runtime, not through this module.
- **Two decisions that are the user's.** The plan drew TLS as a library, and the proposal moves it into the standard library. And the `foreign` rule, read strictly, asks for TLS in Ernest; the proposal takes the host's instead and asks that the exception be recorded with its argument. Neither is settled by this note.
- **The socket process was not read line by line.** The estimate of ten places comes from the calls it makes.
- **The error for a refused certificate.** `Io.Error` has no constructor for it today; whether it gains one or the refusal is `Other(text)` is decided when the module is written.
