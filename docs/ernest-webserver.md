# Paper Program 1: Web Server with Sessions

Written against the Ernest report, September 2026. A web server with sessions.

## Assumptions About the Runtime's System Processes

`ClockMsg` is the report's. `Sys.clock` is an ambient reference (report §8); this paper program additionally assumes the runtime provides `Sys.net : Address(NetMsg)`:

```
type Port = Port(Int)
type NetMsg = Listen(port : Port, acceptor : Address(ConnMsg))
type ConnMsg = Conn(Address(SockMsg))
type SockMsg = Read(reply : Reply(Bytes)) | Write(Bytes) | Close
type Tick = Tick
```

## The Program

```
//
// Types
//
type Request = Request(method : Text, path : Text, headers : List((Text, Text)))
type Response = Response(status : StatusCode, headers : List((Text, Text)), body : Text)
type ParseError = BadEncoding | BadRequestLine | BadHeader(Text)
type Session = Session(Int) // number of visits

opaque type StatusCode = StatusCode(Int) with {
    ok : StatusCode;
    notFound : StatusCode;
    render : (StatusCode) -> Text
}

opaque type SessionId = SessionId(Text) with {
    fresh : (Int) -> SessionId;
    parse : (Text) -> Optional(SessionId);
    text : (SessionId) -> Text
}

//
// Program
//
fn main() -> () with () = {
    let sessions = Ets.new();
    let _ = spawn(Local, fn() = sweeper(sessions));
    let acc = spawn(Local, fn() = acceptor(sessions, 0));
    send(Sys.net, Listen(port = Port(8080), acceptor = acc))
}

//
// Processes
//
// The sweeper: clears the session table every ten minutes.
fn sweeper(sessions : Ets.Table(SessionId, Session)) -> () with Tick = {
    send(Sys.clock, After(ms = 600000, to = via(fn(_) = Tick, self())));
    recv { Tick -> Ets.clear(sessions) };
    sweeper(sessions)
}

fn acceptor(sessions : Ets.Table(SessionId, Session), seq : Int) -> () with ConnMsg = recv {
    Conn(sock) -> {
        let _ = spawn(Local, fn() = handler(sessions, seq, sock));
        acceptor(sessions, seq + 1)
    }
}

// One process per connection: reads a request, writes a response, closes.
fn handler(
    sessions : Ets.Table(SessionId, Session),
    seq : Int,
    sock : Address(SockMsg)
) -> () with m = {
    match Address.call(sock, fn(r) = Read(reply = r), 5000) {
        Some(bytes) -> match parse(bytes) {
            Left(_) -> {
                let notFound = Response(status = StatusCode.notFound, headers = [], body = "");
                send(sock, Write(render(notFound)));
                send(sock, Close)
            }
          | Right(req) -> {
                let id = match Optional.andThen(cookie(req, "sid"), SessionId.parse) {
                    Some(sid) -> sid
                  | None -> SessionId.fresh(seq)
                };
                let visits = match Ets.lookup(sessions, id) {
                    Some(Session(n)) -> n + 1
                  | None -> 1
                };
                Ets.insert(sessions, id, Session(visits));
                let body = "Visit number " ++ Int.toText(visits);
                let bytes = Response(status = StatusCode.ok, headers = [], body = body)
                    |> withCookie("sid", SessionId.text(id))
                    |> render;
                send(sock, Write(bytes));
                send(sock, Close)
            }
        }
      | None -> send(sock, Close) // the client never answered
    }
}

//
// Pure code: HTTP parsing and rendering
//
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

//
// Opaque-type definitions
//
let StatusCode.ok = StatusCode(200)
let StatusCode.notFound = StatusCode(404)
fn StatusCode.render(StatusCode(n)) = Int.toText(n)

fn SessionId.fresh(n) = SessionId(Int.toText(n)) // good enough on paper
fn SessionId.parse(t) = if Text.all(t, Char.isDigit) then Some(SessionId(t)) else None
fn SessionId.text(SessionId(t)) = t
```
