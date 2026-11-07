# An error across a library

A proposal for Appendix G.11 and Appendix E.0. Written 2026-11-07; decided with the user
before the report changes, and built in the same milestone or dropped.

## The need

A block's `<-` bindings resolve to one sum type (§5.5). `libs/http` answers its socket
functions with `ReadError`, which is `Protocol(Error)` or `Socket(Io.Error)`, the protocol's
refusal or the socket's own error (G.11). A block typed by that error that writes to the
socket calls `Tcp.write`, whose error is `Io.Error` (E.18), and so lifts it,
`Either.mapLeft(Tcp.write(...), Http.Socket)`: five sites in the library's own three socket
examples, and one at every `Tcp` call of a program whose block is typed by the library's error.
The lift says nothing. `Socket` is the one constructor an `Io.Error` can become there, so the
reader learns from it only that the two types differ (feedback 185, the log's *What the Server
Taught*).

The shape is every library's over a system module. A standard library module whose failures
are the host's adds its cases to `Io.Error`, as E.27 adds `NotListed` and `Unreachable`,
since E.1 is the standard library's to grow. A library cannot, so it wraps the module's error
in its own, and a program over it holds two error types for one resource.

A program's own error type is not the finding. `examples/fetch.ern` lifts each call into a
`String`, the line it prints, and ernest-httpd's `Config` wraps `Fs`'s error as
`Unreadable(Io.Error)`: each lift says which of the program's cases a failure is, which is
the program's meaning and nothing the library can write for it.

ernest-httpd's smoke test shows the shape the other way around. Its `get` writes the request
with `Tcp.write` under `<-`, which types the block `Io.Error`, and then lifts the library's
`ReadError` into `Io.Error`, `Socket(cause)` to its cause and `Protocol(cause)` to
`Other("the response is ...")`. The protocol's refusal, a value with four cases, becomes a
text, since the first `<-` of the block decided its type.

## The three ways

**The library answers `Io.Error` itself.** `Protocol` and `Error` go, and a refusal is an
`Io.Error`, `Invalid` or `Other(text)`. A server acts on the four cases: `Malformed` is
answered with 400, `LineTooLong` with 414, `HeadersTooLarge` with 431 and `BodyTooLarge` with
413 (RFC 9110, RFC 6585, RFC 9112 §3), and §7.4 gives a failure `Either` where it has a cause
the program can act on. The way loses the cause, as the smoke test's `readError` loses it
by hand. Refused, principle 1: a reader of `Either(Io.Error, Request)` predicts the socket's
errors and meets a protocol's refusals written as text.

**A conversion declared at `<-`.** Rust's `?` converts the error through a declared `From`,
so a block's one error type takes every error a conversion reaches. In Ernest it would be a
conversion the checker applies where a `<-`'s error type differs from the block's, found by
the one constructor of the block's type whose field has the `<-`'s error type, or a syntax
naming the conversion, `let p <- e with f`. The first is a conversion a reader cannot see at
the site, which nothing in Ernest has (principle 1). Both are a second way to lift beside
`Either.mapLeft` (principle 2), and a rule of §5.5 and its soundness paragraph for one
library's shape (principle 5). Refused.

**The form stands, and the library reads and writes the socket.** `Http` reads a head and a
body from a socket already, and gains the writes: `writeRequest`, `writeResponse` and
`writeChunk`, each the bytes form's rendering and one `Tcp.write` within the milliseconds,
answering the socket functions' error, whose `Left` at a write is `Socket(error)` alone. An
HTTP message is written to a connection as it is read from one, so the library's operations on
the connection are then whole, and a program over it meets `Io.Error` only where it opens the
connection, `Tcp.listen`, `Tcp.accept` or `Tcp.connect`, before the protocol speaks. The lift is
written once, at a client's connect in the exchange's block, or not at all where the connection
is opened in another function, as `examples/web_server.ern`'s acceptor opens it for the
handler.

Recommended. The language does not change, the library grows by its own protocol's
operations, and each operation has a bytes form and a socket form, `parseRequest` and
`readRequest`, `renderResponse` and `writeResponse`, `chunk` and `writeChunk`.

**A fourth, weighed and set aside.** The socket functions could answer `Either(Io.Error, a)`
with the protocol's refusal inside the value, `Refused(Error)` beside `Read(head, rest)`,
as `Parsed` holds `Incomplete` beside `Parsed`. A server's two failures differ, a refusal is
answered and a socket's error ends the connection, and the type would say so. A client treats
both as one failure, and would convert the refusal into the transport's error to keep its
block one type, which is the smoke test's `readError` made the rule. Set aside, principle 1.

## The rule

A library's error that wraps `Io.Error` is the error of every operation of the library's
protocol on the system module's resource, reading and writing alike, so that a program over
the library meets `Io.Error` from that resource only where it opens it.

## The questions

**The error's name.** `ReadError` names a read's error, and a write's `Left` would be a
`ReadError` too. The type is the error of the functions over a socket, so its name is
`SocketError`, `Protocol(Error) | Socket(Io.Error)`, the constructors unchanged, each saying
which side failed. The recommendation is the one rename: a program's matches on `Http.Socket`
and `Http.Protocol` stand, and a signature naming `Http.ReadError` changes its word.

**Which writes.** `writeRequest(socket, request, body, ms)` and
`writeResponse(socket, response, body, ms)` write what `renderRequest` and `renderResponse`
render, and `writeChunk(socket, bytes, ms)` writes what `chunk` renders, so that a chunked
response is written head and chunks under one error type. The rendering's faults are the
write's, §7.4's for a request the library refuses which the program alone could have kept. No
`write(socket, bytes, ms)`: it would be `Tcp.write` with the lift inside, a second way to write
bytes (principle 2), and the three named writes are the protocol's messages. The bytes forms
stay: a test renders a message without a socket, and ernest-httpd concatenates rendered
requests into one pipelined write.

**Opening the connection.** `listen`, `accept`, `connect`, `listenTls` and `connectTls` stay
`Tcp`'s. HTTP does not own its connection, plain or over TLS, and a server's acceptor gives the
socket to a handler before the protocol speaks (E.18). The library's socket examples take the
socket as given, as a handler does, and the client example's one lift stands at its connect.

**A composition.** Each write is the bytes form and one `Tcp.write`, a composition by E.0
admission rule 4's letter. The admission rules do not reach a library (Appendix G), and the
write enters by the rule above, which asks for it: the library's operations on the connection
are whole or the program lifts. The recommendation names this in the log and not in G.11.

**Where the rule lives.** The rule holds for the next library over a socket, a file or a
program as it holds for `libs/http`, so it is E.0's eleventh shape rule, among those that hold
in a library outside the standard library too, with G.11 naming the three writes. The other
place is a sentence of G.11 alone, which the next library would ask again. The recommendation
is E.0.

**ernest-httpd.** Its floor is 0.9 until MVP 4.4's item 4, and its session is told at the
milestone's end, as items 10 and 11 tell it: its `smoke.ern`'s `get` and `upgrade` write their
requests with `writeRequest` and lose `readError`, its one signature naming `Http.ReadError`
changes its word, and its matches on `Http.Socket` stand. What it does with them is its own
session's.

## What the repository shows

The lift stands in two forms today, and the counts are a check on the shape, not its argument
(§0, principle 5).

| Where | Lifts | What the lift says |
|---|---|---|
| `libs/http`'s three socket examples | 5, `Io.Error` to `Http.Socket` | nothing: the one constructor it can be |
| ernest-httpd's `smoke.ern` | 3, `ReadError` to `Io.Error` | the protocol's refusal, as a text |
| `examples/fetch.ern` | 4, to the line it prints | the program's own words; stays |
| ernest-httpd's `config.ern` | 3, to `Config.Error` | the program's own case; stays |

Under the third way the library's five go, the smoke test's three go, and the client example
keeps one, at its connect.

## What does not change

§5.5, §7 and §7.4; E.1's `Io.Error`, which stays the system modules' and grows for none but
them; E.18's `Tcp`, whose `write` is the only write of bytes to a socket; `Either.mapLeft`,
which stays the one way to lift; the grammar; the soundness paragraph, since no rule of §3
to §9 changes. A program's own error type lifts each call into its case as before.

## The cost

A write renders the message and sends it, one `Tcp.write` of what the bytes form renders,
Ernest around the host's send with no copy the bytes form does not make (E.0 rule 1). Nothing on
`make bench`. The report pays the shape rule, G.11's three functions and one rename; the library
pays three functions, the rename and five examples; `examples/fetch.ern` and
`examples/web_server.ern` pay one write each.

## The build order

1. E.0's shape rule 11 and the sentence naming it among those a library follows, G.11's
   sentences and signatures, the rename, and the log's entry; the sentences read once before
   the code, since no rule of §3 to §9 changes.
2. The three writes with their doc blocks and the rename, `ReadError` to `SocketError`, in
   `libs/http`, a test for each sentence citing G.11, and `make test-library`.
3. The library's five examples, `examples/fetch.ern` and `examples/web_server.ern` written
   with the writes, their headers and `examples/README.md` where they name the form, and
   the read-back over every `.ern` the item wrote, a search over the sources for a lift
   that says nothing.
4. ernest-httpd's session told at the milestone's end, and the proposal kept as the record
   until its milestone's row.
