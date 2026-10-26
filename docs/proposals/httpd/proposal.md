# ehttpd, the server for ernest-lang.org

A starting point, written 2026-10-26 from the first discussion. It states what the server does and what it leaves out; the reasons are given where a choice was made, and stay here until the proposal is decided.

## What it is for

ehttpd serves one site, ernest-lang.org: static pages generated from Markdown (MVP 4.2), and one WebSocket per visitor that connects xterm.js in the browser to a shell on the server. It implements what that needs of HTTP/1.1 and nothing more. It is a program written in Ernest, in a repository of its own, built against an installed Ernest; `examples/web_server.ern` is its smallest ancestor, whose hand-written parser `libs/http` replaces.

## HTTP/1.1

RFC 9110 states HTTP's semantics and RFC 9112 its HTTP/1.1 message syntax.

**What it implements.**

- The methods `GET` and `HEAD`. Any other method answers 405 with `Allow: GET, HEAD`.
- A request target in origin form, and one in absolute form taken by its path, which RFC 9112 asks a server to accept.
- `Host`, required: a request without it answers 400.
- Persistent connections by default, `Connection: close` honored, and requests answered in the order they came, which a loop that reads one request at a time gives.
- Every response with `Content-Length`, `Date` and a `Content-Type` from a small table of extensions, which the configuration may extend.
- `Last-Modified` from the file, and `If-Modified-Since` answered with 304.
- A directory answered by its `index.html`, a path that names no file by 404, and a path holding `..` refused with 400.
- The errors a log's reader needs: 400, 404, 405, 408 on a request that comes too slowly, 413, 414 and 431 past the limits, 500, 501 on a transfer coding it does not know, and 505 on another version.

**What it leaves out.**

- A request body. A request that carries one, by `Content-Length` or `Transfer-Encoding`, is refused and its connection closed, since nothing on the site takes input over HTTP. That leaves out chunked request decoding and `Expect: 100-continue` too.
- Chunked responses, since every file has a size.
- Ranges, compression, `ETag`, content negotiation, trailers and HTTP/2.

## WebSocket

RFC 6455, for xterm.js.

**What it implements.**

- The upgrade's handshake on the configured path. `Sec-WebSocket-Accept` is the SHA-1 of the client's key and a fixed string, written in base64.
- An `Origin` check against the origins the configuration allows, since a WebSocket is not held to the browser's same-origin rule.
- Text and binary frames, the client's masking, continuation frames, which a server must accept, and the three forms of a payload's length.
- Ping and pong, and the closing handshake.
- A limit on a message's size, past which the connection closes with 1009.

**What it leaves out.** Extensions, `permessage-deflate` among them, and subprotocols, which xterm.js's attach addon does not ask for.

Behind the socket stands a shell in a container per visitor (`../site/decisions.md`). The pseudo-terminal is the server's: `Os` gains a start under a pseudo-terminal of a given size, and a resize, which the runtime's helper gives by the host's `forkpty` and `TIOCSWINSZ`, and ehttpd runs `podman run -it --rm` on it, podman giving the container its own terminal and forwarding each resize. The socket's frames carry the terminal's bytes both ways and a resize from xterm.js's fit addon.

## TLS

The site is served over HTTPS, and ehttpd terminates TLS itself. `Tcp` gains two functions that open a socket over TLS, `Tcp.listenTls(host, port, certificate, key)` and `Tcp.connectTls(host, port, verify, ms)`, and answers the same socket address as a plain one, so that reading, writing, accepting and closing are one set of functions for both (E.18, principle 2). They are two functions and not a `Bool`, by E.0 shape rule 9. The host's `ssl` does the work, whose functions mirror `gen_tcp`'s, so the runtime's socket process holds either kind; a program that is no node starts `ssl` at its first TLS call, and a node has it already for its carrier. `Tcp.accept` answers the socket once the TCP connection is accepted, and the handshake runs in the socket's own process, as the host splits `ssl:transport_accept` from `ssl:handshake`, so that a slow client holds no accept loop; the first `read` or `write` waits for it, and a failed handshake answers there as `Other(text)`, the words `ssl` gives, since no program acts on it otherwise than on another failed connection. The certificate and key are files, renewed by certbot outside the server, which a restart reads again.

This replaces the plan's separate `libs/tls`, which named the choice to be made when it was written.

## The libraries it asks for

- **`libs/http`**: a shim over `erlang:decode_packet/3` with `http_bin`, which reads a request line and one header at a time and answers `more` where the bytes end. Ernest closes the difference, a header's name as a string where the host gives some as atoms, and the host's limits on a line stated; rendering a response is Ernest. No server loop.
- **`libs/time`**: a shim over the host's `calendar`, a moment of `Clock` written in Common Log Format's form and in RFC 9110's, `Sun, 06 Nov 1994 08:49:37 GMT`, and that form read back for `If-Modified-Since`. Dates are a library's (E.0 rule 2), so `Clock` stays as it is: `Clock.toString` was admitted as the one text form the runtime's own lines write, and nothing more of a calendar enters it.
- **`libs/crypto`**: SHA-1 for the WebSocket's handshake, a shim over `crypto:hash/2`, beside what the plan names for it.
- **`libs/websocket`**: the handshake's key and the frames, decoded and encoded, which the server and a client share.
- **`libs/base64`**: a shim over `base64`.

## The functions, a first cut

Names and shapes by E.0's shape rules, each a draft for the discussion and none decided.

- **`libs/http`.**
  - `Request`, a method, a target, a version and headers, and `Response`, a status, headers and a body as `Bytes`.
  - `Http.parseHead(bytes) : Either(Http.Error, Head)`, `Head` either `Incomplete` or the request with the bytes after it, a shim over `decode_packet` driven a line at a time.
  - `Http.header(request, name) : Optional(String)`, by name in any case.
  - `Http.render(response) : Bytes` and `Http.reason(status) : String`.
  - `Http.Error`, named by what the server answers: `Malformed`, 400, `TargetTooLong`, 414, and `HeadersTooLarge`, 431. A version other than 1.0 or 1.1 parses, and the server answers it 505.
- **`libs/websocket`**, a library of its own and not the server's, since a client wants it too.
  - `WebSocket.accept(key) : String`.
  - `WebSocket.decode(bytes, role, limit) : Either(WebSocket.Error, Decoded)`, a frame or `Incomplete`; `role`, `FromClient` or `FromServer` by shape rule 9, decides which masking it refuses.
  - `WebSocket.Error`, named by the close code: `ProtocolError`, 1002, `TooBig`, 1009, and `NotUtf8`, 1007.
  - `WebSocket.encode(frame) : Bytes`, a `Frame` one of text, binary, continuation, ping, pong and close.
- **`libs/crypto`**: `Crypto.sha1(bytes)`, `sha256(bytes)`, `hmac(key, bytes)` and `randomBytes(count)`, each a shim over `crypto`.
- **`libs/base64`**: `Base64.encode(bytes) : String` and `decode(text) : Optional(Bytes)`.
- **`libs/time`**, a library and not the standard library's, by E.0's rule for a module over a published specification or a policy and E.15's sentence that nothing of dates but `Clock.toString` is the standard library's (decided 2026-10-26).
  - `Time.httpDate(time) : String` and `Time.fromHttpDate(text) : Optional(Int)`, over a `Clock` time.
  - `Time.commonLog(time) : String`.
  - `Time.civil(time) : Civil`, its year, month, day, hour, minute and second in UTC, from which a program writes any other form.
- **`Tcp`**: `listenTls` and `connectTls`, as decided.
- **`Os`**: `startTerminal(program, arguments, rows, columns, ms)`, answering a program as `start` does, and `resize(program, rows, columns)`.

## Configuration

One JSON file, read through `libs/json`, named on the command line:

- the listen address and port, and the TLS certificate's and key's paths;
- the root the files are served from;
- the timeouts, for a request's head and for an idle connection;
- the limits, on a request line, on the headers and on a WebSocket message;
- extensions added to the table of content types;
- the WebSocket's path, its allowed origins and the command that runs a visitor's shell;
- where the access log is written.

A file that breaks a rule is refused at the start, the message naming the field.

## The log

Every request is a line of Common Log Format, `host - - [10/Oct/2026:13:55:36 +0000] "GET / HTTP/1.1" 200 2326`, written in UTC, so that logs of two machines agree and the library needs no time zone. A WebSocket's line is written when it closes, its status 101 and its byte count the frames' payloads.

## Under systemd

ehttpd runs in the foreground, under a unit of `Type=exec`. It writes its access log to the configured file or to standard output, and what goes wrong to standard error, which the journal keeps. It exits with a status that is not 0 when it fails, so that `Restart=on-failure` restarts it. `SIGTERM` stops it in order through `Os.termination`: the listener closes, the requests under way are answered, and the WebSockets are closed with 1001. It binds 80 and 443 through `AmbientCapabilities=CAP_NET_BIND_SERVICE`, as no root.

A change of configuration is a restart. A static site restarts in about a second, and reloading would mean running ehttpd as a node, since `SIGHUP` is a reload only for a node (§8.6). `Type=notify` would need a Unix datagram socket, which Ernest lacks, and `Type=exec` serves.

## Decided so far

- TLS in `Tcp`, by two functions answering the same socket (2026-10-26).
- `libs/time` for the dates, a library and not the standard library's, `Clock` unchanged (2026-10-26).
- A change of configuration is a restart (2026-10-26).
- The pseudo-terminal on the server through a new start in `Os`, podman inside it (2026-10-26).
- The errors: a failed handshake is `Other(text)`, run in the socket's process after `accept`; `Http.Error` and `WebSocket.Error` named by the status and the close code they answer (2026-10-26).
- Files under a root no one else writes: a path holding `..` refused, and no check of links, so the plan's `Fs.readUnder` waits for a root others can write (2026-10-26).
