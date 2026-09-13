# Paper Program 1: Web Server with Sessions

Written against the Ernest report, September 2026, to see where the specification chafes.

## Assumptions About the Runtime's System Processes

`ClockMsg` and `Sys` are the report's. Assumed types for `net`:

```
type Port     = Port(Int)
type NetMsg   = Listen(port : Port, acceptor : Address(ConnMsg))
type ConnMsg  = Conn(Address(SockMsg))
type SockMsg  = Read(reply : Reply(Bytes)) | Write(Bytes) | Close
type Tick     = Tick
```

## The Program

```
// Pure code: HTTP parsing and sessions ---------------------------

type Request = Request(method : Text, path : Text, headers : List((Text, Text)))

opaque type StatusCode = StatusCode(Int) with {
    ok : StatusCode;
    notFound : StatusCode;
    render : (StatusCode) -> Text
}

let StatusCode.ok = StatusCode(200)
let StatusCode.notFound = StatusCode(404)
fn StatusCode.render(StatusCode(n)) = Int.toText(n)

type Response = Response(status : StatusCode, headers : List((Text, Text)), body : Text)

type ParseError = BadEncoding | BadRequestLine | BadHeader(Text)

fn parse(b : Bytes) -> Either(ParseError, Request) = {
    let t <- Either.fromOptional(Text.fromUtf8(b), BadEncoding);
    let lines = Text.lines(t);
    let (method, path) <- requestLine(lines);
    let headers <- headerLines(lines);
    Right(Request(method = method, path = path, headers = headers))
}

fn requestLine(lines : List(Text)) -> Either(ParseError, (Text, Text)) = todo("on paper")
fn headerLines(lines : List(Text)) -> Either(ParseError, List((Text, Text))) = todo("on paper")
fn render(r : Response) -> Bytes = todo("on paper")
fn cookie(r : Request, name : Text) -> Optional(Text) = todo("on paper")
fn withCookie(name : Text, value : Text, r : Response) -> Response = todo("on paper")

opaque type SessionId = SessionId(Text) with {
    fresh : (Int) -> SessionId;
    parse : (Text) -> Optional(SessionId);
    text : (SessionId) -> Text
}

fn SessionId.fresh(n) = SessionId(Int.toText(n))   // good enough on paper
fn SessionId.parse(t) = if Text.all(t, Char.isDigit) then Some(SessionId(t)) else None
fn SessionId.text(SessionId(t)) = t

type Session = Session(Int)            // number of visits

// The session store: an ETS table, Appendix D of the report --------

// The sweeper: clears the table every ten minutes.
fn sweeper(clock : Address(ClockMsg), sessions : Ets.Table(SessionId, Session)) -> () with Tick = {
    send(clock, After(ms = 600000, to = via(fn(_) = Tick, self())));
    recv { Tick -> Ets.clear(sessions) };
    sweeper(clock, sessions)
}

// One process per connection --------------------------------------

fn handler(sessions : Ets.Table(SessionId, Session), seq : Int, sock : Address(SockMsg)) -> () with m = {
    match Address.call(sock, fn(r) = Read(reply = r), 5000) {
        Some(bytes) -> match parse(bytes) {
            Left(_) -> {
                send(sock, Write(render(Response(status = StatusCode.notFound, headers = [], body = ""))));
                send(sock, Close)
            }
          | Right(req) -> {
                let id = match Optional.flatMap(cookie(req, "sid"), SessionId.parse) {
                    Some(sid) -> sid
                  | None      -> SessionId.fresh(seq)
                };
                let visits = match Ets.lookup(sessions, id) { Some(Session(n)) -> n + 1 | None -> 1 };
                Ets.insert(sessions, id, Session(visits));
                let body = "Visit number " ++ Int.toText(visits);
                send(sock, Write(render(withCookie("sid", SessionId.text(id),
                                        Response(status = StatusCode.ok, headers = [], body = body)))));
                send(sock, Close)
            }
        }
      | None -> send(sock, Close)                      // the client never answered
    }
}

// Acceptor ------------------------------------------------------

fn acceptor(sessions : Ets.Table(SessionId, Session), seq : Int) -> () with ConnMsg = recv {
    Conn(sock) -> { let _ = spawn(Local, fn() = handler(sessions, seq, sock)); acceptor(sessions, seq + 1) }
}

fn main(Sys(clock = clock, net = net) : Sys) -> () with () = {
    let sessions = Ets.new();
    let _ = spawn(Local, fn() = sweeper(clock, sessions));
    let acc = spawn(Local, fn() = acceptor(sessions, 0));
    send(net, Listen(port = Port(8080), acceptor = acc))
}
```

## What Chafed

**1. Reply addresses.** `via(Data, self())` and `via(FoundSession, self())`. A `reply f` was introduced to avoid `self` and dropped again as a second spelling; `contramap` was renamed `via`.

**2. Timeout and filter.** A handler waiting for a client that does not answer closes the socket after 5 s. The first version had `recv` as a function with a mandatory timeout: `sessions` and `acceptor` got a `Timeout` arm that was never reached, and the handler wrote every selective receive as a filter lambda plus a match, the same match twice. Now `recv` is a form with arms and `after`; the handler's two receives are a line shorter each, and `sessions` is three arms.

**3. Opaque types with a signature.** The first version called `SessionId.parse` without defining it; with the indentation rule that went unnoticed on paper, with the signature it showed. The signature also forced the return type for invalid text: `Optional(SessionId)`, not a garbage value. Validation is declared with the type, not where it is used.

**4. Errors in `parse`.** Three steps that can fail. The first version had `?`; without it, two functions with one match each; with `let x <- e` it is four lines in one function, and `Text.fromUtf8`'s error is converted to `BadEncoding` with `Either.mapLeft` on the same line. The handler then matches on `Either` once and turns the error into a 404.

**5. The handler dies, the socket closes.** `net` monitors the handler per the ports model. If the handler dies, `net` closes the socket. It is not visible in the code and that is right. With a total prelude the handler dies only of a fault; a parse error is a `Left` and a 404.

**6. The session store: process, then table.** The first version kept sessions in a process with `Lookup`, `Put`, and `Sweep`; every request sent two messages there, waited for one with a second timeout, and the process was the bottleneck the decision log calls the ETS problem, with sharding as the answer. That was the right first version: a process is what the language has for state with many clients. When `foreign fn` arrived and Appendix D gave `Ets.ern`, the store became a table: `Ets.lookup` and `Ets.insert` in the handler, one `recv` fewer, no `FoundSession`, no second timeout, and no bottleneck. The cost is the one the report makes visible: `handler` reads and writes what other handlers write, and its mailbox type says so. The two versions are the value-versus-process-versus-table decision in twenty lines, and the guide should show both.

**7. The braces.** The handler is four levels of nested match, and with braces it shows. In layout syntax the same nesting would have been invisible, not absent. That is an argument for breaking the handler's steps into named functions, not an argument against braces. With `after` in the arm, the time limits came to stand last in every `recv`, after what they guard; it reads better than before.

**8. What did not chafe.** Pure code was pure: `parse`, `render`, `cookie` without a mailbox type. In the process version, selective receive let the handler wait for `FoundSession` without caring that a `Data` might be ahead of it. Closing over `sessions` and `sock` in `spawn` was natural, and a table handle closes over as easily as an address.

## Adopted into the Report

`via`; `recv` as a form with `after`; system processes monitor their clients; signature on opaque types; `let x <- e`. The code has been transferred to syntax revision 3 (n-ary functions, `fn`, parentheses in types), to the grammar audit (named fields in parentheses, `let`, single `Int`), and, on 13 September, to an ETS table for the session store, and to `Reply(Bytes)` on `SockMsg.Read` with `Address.call` in the handler; `HandlerMsg` and the `Data(Bytes)` wrapper are gone, and the reply obligation is now on the socket's implementation, not on discipline.
