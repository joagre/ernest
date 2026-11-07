# Ernest module Http

*Since 0.9.0.*

HTTP/1.1's messages as RFC 9112 writes them: a request's or a response's
head read from bytes or from a socket, the body after it, and a head and a
body written, with a request's target and cookies and RFC 9110's dates and
status phrases.

Use it to serve HTTP over `Tcp`, or to speak it to a server. A server
reads a request's head with `readRequest` and its body with
`readRequestBody`, its target with `target` and a cookie with `cookie`,
and writes its response with `renderResponse`, a body in chunks with
`chunk`; a client writes its request with `renderRequest` and reads the
response with `readResponse` and `readResponseBody`. `parseRequest` and
`parseResponse` read a head from bytes a program already holds.

The library stands on every job's load path, so a program names it with
no option (report Appendix G).

**A head.** A line ends in a line feed, with or without a carriage return
before it. A request's method and target and a header's name are kept as
written, and a header's value without the white space around it. A head
that passes its `Limits` is refused at the bytes that pass them, so that
a reader holds no more of a head than the limits allow.

**The bytes after a head or a body.** A socket answers what has arrived,
which may run past the head, into its body, or past the body, into a
second request a client sent before the first's answer. A reader answers
those bytes, and the next reader is given them as `carried`, which it
reads before the socket.

**Waiting.** The milliseconds a reader is given bound the whole head, or
the whole body, and not each read from the socket, so that a client that
sends a byte a second meets them.

**A body.** The head's headers frame it: the chunked coding, else
`Content-Length`. Where they carry neither, a request has no body, and a
response's runs to the connection's close, as it does where its last
transfer coding is not chunked. A response of status 1xx, 204 or 304 has
no body, whatever its headers. Nor has one to a `HEAD` request, which
its reader cannot know: a client that sent `HEAD` reads no body.

## Examples

A request's head read from bytes:

```ernest
{
    let bytes = String.toUtf8("GET /hello.txt HTTP/1.1\r\nHost: www.example.com\r\n\r\n");
    match Http.parseRequest(bytes, Http.defaultLimits) {
        Right(Http.Parsed(head = request)) ->
            #(request.method, request.target, Http.header(request.headers, "host"))
      | _ ->
            #("", "", None)
    }
}
// => #("GET", "/hello.txt", Some("www.example.com"))
```

A response written, its `Content-Length` added:

```ernest
{
    let response =
        Http.Response(version = Http.http11,
                      status = 200,
                      headers = [Http.Header(name = "Content-Type", value = "text/plain")]);
    String.fromUtf8(Http.renderResponse(response, String.toUtf8("Hello")))
}
// => Some("HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 5\r\n\r\nHello")
```

## See also

`Tcp` for the sockets the readers read, `Bytes` for what they answer,
`Uri` for a target's components.

## Http.Version

```ernest
type Version = Version(major : Int, minor : Int)
```

A version of HTTP, `HTTP/1.0` being `Version(major = 1, minor = 0)`;
`http11` is HTTP/1.1.

### Examples

```ernest
Http.Version(major = 1, minor = 0)
// => Http.Version(major = 1, minor = 0)
```

- `Version`
  - `major : Int`: The number before the point.
  - `minor : Int`: The number after the point.

## Http.http11

```ernest
Http.http11 : Version
```

*Since 0.10.0.*

HTTP/1.1, the version of the messages RFC 9112 writes.

A server answers an HTTP/1.0 request in HTTP/1.1 too, the highest
version it speaks whose major number is not above the request's (RFC
9110, section 2.5).

### Examples

```ernest
Http.http11
// => Http.Version(major = 1, minor = 1)
```

## Http.Header

```ernest
type Header = Header(name : String, value : String)
```

A header: its name, which a reader keeps as written, and its value.

### Examples

```ernest
Http.Header(name = "Content-Type", value = "text/html")
// => Http.Header(name = "Content-Type", value = "text/html")
```

- `Header`
  - `name : String`: The name, which `header` and `headers` compare in any case.
  - `value : String`: The value, without the white space before and after it.

## Http.Request

```ernest
type Request = Request(method : String, target : String, version : Version, headers : List(Header))
```

A request's head: its method, its target, its version and its headers,
in their order.

### Examples

```ernest
{
    let request =
        Http.Request(method = "GET",
                     target = "/",
                     version = Http.http11,
                     headers = [Http.Header(name = "Host", value = "example.com")]);
    #(request.method, request.target, request.headers)
}
// => #("GET", "/", [Http.Header(name = "Host", value = "example.com")])
```

- `Request`
  - `method : String`: The method, `GET`, `POST` or another, as the client wrote it.
  - `target : String`: The target as the client wrote it: a path with its query, an
absolute URI, a host and a port, or `*`.
  - `version : Version`: The version of HTTP the request is written in.
  - `headers : List(Header)`: The headers, in their order.

## Http.Response

```ernest
type Response = Response(version : Version, status : Int, headers : List(Header))
```

A response's head: its version, its status and its headers, in their
order. The status line's phrase is the status's, which `reason` gives.

### Examples

```ernest
Http.Response(version = Http.http11, status = 404, headers = [])
// => Http.Response(version = Http.Version(major = 1, minor = 1), status = 404, headers = [])
```

- `Response`
  - `version : Version`: The version of HTTP the response is written in.
  - `status : Int`: The status, 200 for success.
  - `headers : List(Header)`: The headers, in their order.

## Http.Limits

```ernest
type Limits = Limits(line : Int, headers : Int)
```

The most bytes a head may take: of any of its lines, the line ending
among them, and of its header lines together, theirs among them.
A program with no reason to choose its own passes `defaultLimits`.

### Examples

```ernest
Http.Limits(line = 4096, headers = 16384)
// => Http.Limits(line = 4096, headers = 16384)
```

- `Limits`
  - `line : Int`: The most bytes of any line; a limit below 1 lets no line in.
  - `headers : Int`: The most bytes of the header lines together.

## Http.defaultLimits

```ernest
Http.defaultLimits : Limits
```

*Since 0.10.0.*

The limits a head is read within where a program has no reason to
choose its own: a line of 8192 bytes, past the 8000 that RFC 9112,
section 3, recommends a recipient read in a request line, and header
lines of 65536 bytes together.

### Examples

```ernest
Http.defaultLimits
// => Http.Limits(line = 8192, headers = 65536)
```

## Http.Error

```ernest
type Error = Malformed | LineTooLong | HeadersTooLarge | BodyTooLarge
```

Why a head or a body is refused.

### Examples

```ernest
Http.parseRequest(String.toUtf8("GET /\r\n\r\n"), Http.defaultLimits)
// => Left(Http.Malformed)
```

- `Malformed`: A first line that is no request line or no status line, a request
line with no version and a status line whose status is not three
digits among them; a header line with no name or no `:`; a header
value holding a carriage return, a line feed or a NUL, a request's
header folded over two lines among them, or bytes that are not UTF-8;
or a body whose framing cannot be read.
- `LineTooLong`: A first line past the limit of a line.
- `HeadersTooLarge`: A header line past the limit of a line, or header lines past the
limit of the headers together.
- `BodyTooLarge`: A body past the limit its reader is given.

## Http.Parsed

```ernest
type Parsed(a) = Incomplete | Parsed(head : a, rest : Bytes)
```

What reading a head from bytes found: `Incomplete` where the bytes end
before the head does, else the head and the bytes after it.

### Examples

```ernest
Http.parseRequest(String.toUtf8("GET / HTTP/1.1\r\n"), Http.defaultLimits)
// => Right(Http.Incomplete)
```

- `Incomplete`: The bytes end before the head's empty line.
- `Parsed`: The head, and the bytes after its empty line.

## Http.ReadError

```ernest
type ReadError = Protocol(Error) | Socket(Io.Error)
```

Why reading from a socket found no head or no body: `Protocol` for what
was read, `Socket` for the socket's error.

### Examples

```ernest
Http.Socket(Io.Timeout)
// => Http.Socket(Io.Timeout)
```

- `Protocol`: The head or the body read is refused.
- `Socket`: The socket answered an error: `Timeout` where the milliseconds passed,
`Closed` where the connection closed first.

## Http.parseRequest

```ernest
Http.parseRequest(bytes : Bytes, limits : Limits) : Either(Error, Parsed(Request))
```

The request whose head `bytes` begin with, and the bytes after the head,
or `Incomplete` where they end before the head's empty line.

The request line is three words parted at runs of spaces and tabs: the
method, the target and the version, `HTTP/`, a digit, `.` and a digit,
which is read as written, `HTTP/2.0` as `Version(major = 2, minor = 0)`.
A line without a version, as HTTP/0.9 wrote it, or whose third word is
no version, `HTTP/1.10` among them, is `Malformed`, and so is a status
line. One empty line before the request line is skipped, as RFC 9112,
section 2.2 has a server skip it, and a second is `Malformed`.

A first line past `limits.line` bytes is `LineTooLong`. A header line past
it, and header lines past `limits.headers` bytes together, are
`HeadersTooLarge`. Each is found at the bytes that pass the limit, before
the line's end has come.

### Examples

Two requests a client sent at once, the second in the bytes after the
first's head:

```ernest
{
    let bytes = String.toUtf8("GET /a HTTP/1.1\r\n\r\nGET /b HTTP/1.1\r\n\r\n");
    match Http.parseRequest(bytes, Http.defaultLimits) {
        Right(Http.Parsed(head = first, =rest)) -> #(first.target, String.fromUtf8(rest))
      | _ -> #("", None)
    }
}
// => #("/a", Some("GET /b HTTP/1.1\r\n\r\n"))
```

## Http.parseResponse

```ernest
Http.parseResponse(bytes : Bytes, limits : Limits) : Either(Error, Parsed(Response))
```

The response whose head `bytes` begin with, and the bytes after the head,
or `Incomplete` where they end before the head's empty line, read as
`parseRequest` reads a request's.

The status is three digits, and a status line whose status is not is
`Malformed`, as a request line is; the line's phrase is dropped. A
header folded over two lines is read with each fold, a line break and
the white space around it, replaced by one space (RFC 9112, section
5.2), where `parseRequest` refuses it.

### Examples

```ernest
{
    let bytes = String.toUtf8("HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\n\r\n");
    match Http.parseResponse(bytes, Http.defaultLimits) {
        Right(Http.Parsed(head = response)) -> #(response.status, response.headers)
      | _ -> #(0, [])
    }
}
// => #(404, [Http.Header(name = "Content-Length", value = "0")])
```

## Http.readRequest

```ernest
Http.readRequest(socket : Address(Tcp.SocketMsg), carried : Bytes, limits : Limits, ms : Int) : Either(ReadError, #(Request, Bytes))
```

The request whose head `socket` sends after the bytes `carried`, read
within `ms` milliseconds, and the bytes read after its head.

`carried` is what an earlier read took past its head, and is read first;
the socket is read only where it holds no whole head. The milliseconds
bound the whole head and not each read. `Socket(Timeout)` is the
milliseconds passed before the head ended, `Socket(Closed)` the
connection closed before it, and `Protocol(error)` the head refused, as
`parseRequest` refuses it, at the bytes that pass the limits, though no
line feed comes after them.

### Examples

A server that reads one request and answers its target:

```ernest
{
    let listener <- Either.mapLeft(Tcp.listen("0.0.0.0", 8080), Http.Socket);
    let socket <- Either.mapLeft(Tcp.accept(listener, 60000), Http.Socket);
    let #(request, _) <- Http.readRequest(socket, <<>>, Http.defaultLimits, 10000);
    let response = Http.Response(version = Http.http11, status = 200, headers = []);
    let body = String.toUtf8(request.target);
    let written = Tcp.write(socket, Http.renderResponse(response, body), 5000);
    Tcp.close(socket);
    Either.mapLeft(written, Http.Socket)
}
```

## Http.readResponse

```ernest
Http.readResponse(socket : Address(Tcp.SocketMsg), carried : Bytes, limits : Limits, ms : Int) : Either(ReadError, #(Response, Bytes))
```

The response whose head `socket` sends after the bytes `carried`, read
within `ms` milliseconds, and the bytes read after its head, as
`readRequest` reads a request's.

A response of status 1xx is an interim one, which a server may send
before its final response: a client that reads one reads again, given
the bytes this read answers as `carried`, for the response after it.

### Examples

A client that asks for a page and reads the response and its body, which
may run to the connection's close:

```ernest
{
    let socket <- Either.mapLeft(Tcp.connect("example.com", 80, 5000), Http.Socket);
    let request =
        Http.Request(method = "GET",
                     target = "/",
                     version = Http.http11,
                     headers = [Http.Header(name = "Host", value = "example.com")]);
    let _ <-
        Either.mapLeft(Tcp.write(socket, Http.renderRequest(request, <<>>), 5000), Http.Socket);
    let #(response, carried) <- Http.readResponse(socket, <<>>, Http.defaultLimits, 10000);
    let #(body, _) <- Http.readResponseBody(socket, carried, response, 1000000, 10000);
    Tcp.close(socket);
    Right(body)
}
```

## Http.readRequestBody

```ernest
Http.readRequestBody(socket : Address(Tcp.SocketMsg), carried : Bytes, request : Request, limit : Int, ms : Int) : Either(ReadError, #(Bytes, Bytes))
```

The body of `request`, which `socket` sends after the bytes `carried`,
read within `ms` milliseconds, and the bytes read after it; at most
`limit` bytes.

Where `Transfer-Encoding` names `chunked` last, the chunks are decoded,
each chunk's extensions and the trailers after the last chunk dropped;
where it names another coding last, names `chunked` twice or stands
beside a `Content-Length`, the body is `Protocol(Malformed)` (RFC 9112,
sections 6.1 and 6.3). Otherwise `Content-Length` gives the body's size:
one that is no decimal number, or two that name different numbers, are
`Protocol(Malformed)`. Where the headers carry neither, the request has
no body: the answer is an empty body and `carried` as it was, and the
socket is not read.

A client whose request carries `Expect: 100-continue` may hold its body
back until the server answers with status 100 (RFC 9110, section
10.1.1): a server that reads such a body writes a response of status 100
first, or the read waits on the client.

`carried` is what the head's reader took past the head, and is read
first. The milliseconds bound the whole body and not each read.
`Socket(Timeout)` is the milliseconds passed before the body ended, and
`Socket(Closed)` the connection closed before it.

`limit` counts the body's bytes as they come, the chunks' sizes, their
extensions and the trailers among them. A body past it is
`Protocol(BodyTooLarge)`, found at the bytes that pass it, or at once
where `Content-Length` or a chunk's size passes it.

### Examples

A server that reads one request and its body, and answers the body's
size:

```ernest
{
    let listener <- Either.mapLeft(Tcp.listen("0.0.0.0", 8080), Http.Socket);
    let socket <- Either.mapLeft(Tcp.accept(listener, 60000), Http.Socket);
    let #(request, carried) <- Http.readRequest(socket, <<>>, Http.defaultLimits, 10000);
    let #(body, _) <- Http.readRequestBody(socket, carried, request, 1000000, 10000);
    let response = Http.Response(version = Http.http11, status = 200, headers = []);
    let size = String.toUtf8(Int.toString(Bytes.size(body)));
    let written = Tcp.write(socket, Http.renderResponse(response, size), 5000);
    Tcp.close(socket);
    Either.mapLeft(written, Http.Socket)
}
```

## Http.readResponseBody

```ernest
Http.readResponseBody(socket : Address(Tcp.SocketMsg), carried : Bytes, response : Response, limit : Int, ms : Int) : Either(ReadError, #(Bytes, Bytes))
```

The body of `response`, which `socket` sends after the bytes `carried`,
read within `ms` milliseconds, and the bytes read after it; at most
`limit` bytes, read as `readRequestBody` reads a request's.

A response of status 1xx, 204 or 304 has no body, whatever its headers:
the answer is an empty body and `carried` as it was, and the socket is
not read. Nor has a response to a `HEAD` request, which the reader
cannot know: a client that sent `HEAD` reads no body.

Where the headers carry neither `Transfer-Encoding` nor `Content-Length`,
or `Transfer-Encoding` names a coding other than `chunked` last, the body
runs to the connection's close, and no bytes come after it (RFC 9112,
section 6.3).

## Http.header

```ernest
Http.header(headers : List(Header), name : String) : Optional(String)
```

The first value under `name` in `headers`, the names compared in any
case; `None` where no header has the name.

### Examples

```ernest
Http.header([Http.Header(name = "Content-Type", value = "text/html")], "content-type")
// => Some("text/html")
```

## Http.headers

```ernest
Http.headers(headers : List(Header), name : String) : List(String)
```

Every value under `name` in `headers`, in their order, the names compared
in any case.

### Examples

```ernest
Http.headers([Http.Header(name = "Set-Cookie", value = "a=1"),
              Http.Header(name = "Host", value = "example.com"),
              Http.Header(name = "set-cookie", value = "b=2")],
             "Set-Cookie")
// => ["a=1", "b=2"]
```

## Http.cookies

```ernest
Http.cookies(headers : List(Header)) : List(#(String, String))
```

*Since 0.10.0.*

The pairs of every `Cookie` header in `headers`, RFC 6265's, in order:
each value parted at `;`, each part trimmed of the white space around it
and parted at its first `=`, the cookie's name before it and its value
after.

A part with no `=` is dropped. A value is kept as written, its quotes
among them.

### Examples

```ernest
Http.cookies([Http.Header(name = "Cookie", value = "theme=dark; sid=\"a=b\""),
              Http.Header(name = "cookie", value = "lang=sv")])
// => [#("theme", "dark"), #("sid", "\"a=b\""), #("lang", "sv")]
```

## Http.cookie

```ernest
Http.cookie(headers : List(Header), name : String) : Optional(String)
```

*Since 0.10.0.*

The value of the first cookie named `name` in the `Cookie` headers of
`headers`, as `cookies` reads them, the names compared exactly; `None`
where no cookie has the name.

### Examples

```ernest
Http.cookie([Http.Header(name = "Cookie", value = "sid=31d4d96e; theme=dark")], "sid")
// => Some("31d4d96e")
```

## Http.target

```ernest
Http.target(request : Request) : Optional(Uri.Reference)
```

*Since 0.10.0.*

The request's target read as a URI reference, in the form RFC 9112 has
a server read it by the method; `None` for a target of no form.

A `CONNECT` request's target is an authority alone, read as a reference
with that authority and an empty path. An `OPTIONS` request's `*` is the
path `*`. A target that begins with `/` is origin form, a path and a
query with no scheme and no authority, and one that begins with `//` is
such a path too. Any other target is absolute form, which has a scheme.
A target with a fragment is of no form.

Whether the scheme and the `Host` header name the server is the
server's to decide.

### Examples

```ernest
{
    let request =
        Http.Request(method = "GET",
                     target = "/search?q=ernest",
                     version = Http.http11,
                     headers = []);
    Optional.map(Http.target(request), fn(reference) = #(reference.path, reference.query))
}
// => Some(#("/search", Some("q=ernest")))
```

```ernest
{
    let request =
        Http.Request(method = "CONNECT",
                     target = "example.com:443",
                     version = Http.http11,
                     headers = []);
    Optional.andThen(Http.target(request), fn(reference) = reference.authority)
}
// => Some(Uri.Authority(userinfo = None, host = "example.com", port = Some(443)))
```

## Http.renderResponse

```ernest
Http.renderResponse(response : Response, body : Bytes) : Bytes
```

The response's head and `body` after it, as bytes to write: the status
line, each header as `name: value`, an empty line and the body, each line
ending in a carriage return and a line feed.

The status line is the response's version, its status and `reason`'s
phrase for it. Where the headers carry neither `Content-Length` nor
`Transfer-Encoding`, and the status is no 1xx, 204 or 304, a
`Content-Length` of the body's size is written after them (RFC 9110,
section 8.6). A header's value is written as given.

A head that would not read back as written is a program's own error,
and faults the caller, its cause naming the header or the status: a
header's name that is no token, one or more of the ASCII letters and
digits and of ``!#$%&'*+-.^_`|~`` (RFC 9110, section 5.6.2), a header's
value holding a carriage return, a line feed or U+0000, a status that is
not three digits, from 100 to 999 (RFC 9112, section 4), and a body that
is not empty given with a status of 1xx, 204 or 304.

### Examples

A response of no content, which carries no `Content-Length`:

```ernest
{
    let response = Http.Response(version = Http.http11, status = 204, headers = []);
    String.fromUtf8(Http.renderResponse(response, <<>>))
}
// => Some("HTTP/1.1 204 No Content\r\n\r\n")
```

## Http.renderRequest

```ernest
Http.renderRequest(request : Request, body : Bytes) : Bytes
```

The request's head and `body` after it, as bytes to write, as
`renderResponse` writes a response's: the request line, its method, its
target and its version, then the headers, an empty line and the body.

Where the body is not empty and the headers carry neither
`Content-Length` nor `Transfer-Encoding`, a `Content-Length` of the
body's size is written after them; a body is written whatever the
method.

A header faults the caller as `renderResponse` says, and so do a
method and a target `parseRequest` would refuse, its cause naming the
word: a method that is no token, an empty one among them, and a target
that is empty or holds a character outside U+0021 to U+007E, the
visible ASCII characters RFC 3986 writes a target in, `/café` among
them, whose `é` a client writes `%C3%A9`.

### Examples

```ernest
{
    let request =
        Http.Request(method = "POST",
                     target = "/items",
                     version = Http.http11,
                     headers = [Http.Header(name = "Host", value = "example.com")]);
    String.fromUtf8(Http.renderRequest(request, String.toUtf8("{}")))
}
// => Some("POST /items HTTP/1.1\r\nHost: example.com\r\nContent-Length: 2\r\n\r\n{}")
```

## Http.chunk

```ernest
Http.chunk(bytes : Bytes) : Bytes
```

*Since 0.10.0.*

One chunk of the chunked transfer coding, RFC 9112, section 7.1: the
size of `bytes` in hexadecimal, a carriage return and a line feed, the
bytes, and a carriage return and a line feed.

Empty bytes write the last chunk and an empty trailer section,
`0\r\n\r\n`, since no other chunk is empty. A head that names
`Transfer-Encoding: chunked` is rendered with an empty body, and the
chunks are written after it.

### Examples

```ernest
#(String.fromUtf8(Http.chunk(String.toUtf8("Hello, world"))), String.fromUtf8(Http.chunk(<<>>)))
// => #(Some("C\r\nHello, world\r\n"), Some("0\r\n\r\n"))
```

## Http.reason

```ernest
Http.reason(status : Int) : String
```

RFC 9110's phrase for `status`, `Not Found` for 404, from its section 15;
`""` for a status it does not name.

306 and 418, which the RFC keeps as unused, have none.

### Examples

```ernest
#(Http.reason(404), Http.reason(299))
// => #("Not Found", "")
```

## Http.date

```ernest
Http.date(time : Int) : String
```

`time`, in milliseconds since the epoch, as RFC 9110's IMF-fixdate writes
it, in UTC: `Sun, 06 Nov 1994 08:49:37 GMT`.

The milliseconds within the second are dropped. A year is four digits,
and one outside 0 to 9999, which the form cannot write, is written with
as many as it has, a year before 0 with its sign before them.

### Examples

```ernest
Http.date(784111777000)
// => "Sun, 06 Nov 1994 08:49:37 GMT"
```

## Http.parseDate

```ernest
Http.parseDate(text : String) : Optional(Int)
```

The time, in milliseconds since the epoch, that `text` writes as an
HTTP date; `None` for a text of no such form.

The three forms RFC 9110 has a recipient read are read: IMF-fixdate,
`Sun, 06 Nov 1994 08:49:37 GMT`, RFC 850's, `Sunday, 06-Nov-94 08:49:37
GMT`, and asctime's, `Sun Nov  6 08:49:37 1994`. A text is read in its
form's case and spacing alone, and its day of the week must be its
date's. A date or a time of day the calendar has not, a 60th second
among them, is `None`.

RFC 850's year of two digits is the latest year with those digits in
which the text's date and time of day are not more than 50 years after
`Clock.now` (RFC 9110, section 5.6.7).

### Examples

The three forms of one time, and a day of the week that is not its date's:

```ernest
#(Http.parseDate("Sun, 06 Nov 1994 08:49:37 GMT"),
  Http.parseDate("Sunday, 06-Nov-94 08:49:37 GMT"),
  Http.parseDate("Sun Nov  6 08:49:37 1994"),
  Http.parseDate("Mon, 06 Nov 1994 08:49:37 GMT"))
// => #(Some(784111777000), Some(784111777000), Some(784111777000), None)
```

---

Generated by ern 0.10.0-dev from src/libs/http/http.ern.
