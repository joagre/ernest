# Paper Program 1: Web Server with Sessions

Written against the Ernest report, September 2026. A web server with sessions.

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
                let id = match Optional.andThen(cookie(req, "sid"), SessionId.parse) {
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
