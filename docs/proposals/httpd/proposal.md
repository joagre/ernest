# ernest-httpd, the server for ernest-lang.org

A starting point, written 2026-10-26 from the first discussion. It states what the server does and what it leaves out; the reasons are given where a choice was made, and stay here until the proposal is decided.

## What it is for

ehttpd serves one site, ernest-lang.org: static pages generated from Markdown (MVP 4.2), and one WebSocket per visitor that connects xterm.js in the browser to a shell on the server. It implements what that needs of HTTP/1.1 and nothing more. It is a program written in Ernest, in a repository of its own, `ernest-httpd` (decided 2026-10-26), built against an installed Ernest; `examples/web_server.ern` is its smallest ancestor, whose hand-written parser `libs/http` replaces.

## From the plan's MVP 4.1

What the plan's MVP 4.1 states of ehttpd, held here as the proposal's own, the plan's section to become a line pointing here once the proposal is decided (2026-10-26):

- ehttpd is a program in a repository of its own, decided with the user on 2026-10-10 (the log's *ehttpd and the Website*), the first program built against an installed Ernest by a build of its own, which the examples cannot be. Its own plan lives in its repository.
- What it lacks is added where it belongs and never worked around in Erlang or behind a `foreign fn`: a function the standard library lacks enters by E.0's admission rules, our need the occasion and the rules deciding; a format or a protocol is a library's; what the prelude or the language lacks goes to `language_feedback.md` first and is discussed before any code goes around it.
- Each library it asks for is an Ernest source root under `src/libs/<name>/`, whose build ends every job's load path, with `src/stdlib/`'s test discipline, documented to `docs/module_doc_template.md` with its executed examples as its first user, and a section in Appendix G.
- The plan's separate `libs/tls` is replaced by TLS in `Tcp` (below). The plan's other named libraries, `libs/regex`, `libs/uri`, `libs/zlib`, the `Fs` functions and `Udp`, are not ehttpd's and stay in the plan.

## HTTP/1.1

RFC 9110 states HTTP's semantics and RFC 9112 its HTTP/1.1 message syntax.

**What it implements.**

- The methods `GET` and `HEAD`. Any other method answers 405 with `Allow: GET, HEAD`.
- A request target in origin form, and one in absolute form taken by its path, which RFC 9112 asks a server to accept.
- `Host`, required: a request without it answers 400.
- Persistent connections by default, `Connection: close` honored, and requests answered in the order they came, which a loop that reads one request at a time gives.
- Every response with `Content-Length`, `Date` and a `Content-Type` from a small table of extensions, which the configuration may extend.
- `Last-Modified` from the file, and `If-Modified-Since` answered with 304.
- A directory answered by its `index.html`; one asked for without its trailing slash answers 301 to the path with it, so that its page's relative links resolve; one without `index.html` answers 404, with no listing. A path that names no file answers 404, and a path holding `..` is refused with 400.
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

## The live shell's server side

Moved here from the site's decisions on 2026-10-26, where the page's side of the shell stays (`../site/decisions.md`, *The live shell*); the pseudo-terminal is the WebSocket's other end, above.

- One operating-system container per visitor, shared by every page: allocated when the shell first opens, reused after.
- The image holds `ern`, the standard library, `src/libs/`, the examples and a scratch directory, and nothing secret, since a `foreign fn` reads the image and the environment. No network but loopback, so that the guide's `Tcp` examples, which talk to themselves, run. The scratch directory is a size-capped tmpfs, counted into the visitor's memory, so that a program that writes without end ends its own session and no other. The language is whole in the container: no module is forbidden, since nothing done through `Fs`, `Os`, `Tcp` or a `foreign fn` leaves the container, and a shell with fewer modules would be a second mode of the language that the guide's examples would not run in (decided 2026-10-13).
- A session ends after five minutes without input at the prompt, a program running without input among them, after a five-second warning that a key press answers, or after 30 minutes in all.
- A second tab takes the session over, and the first says so.
- A fixed number of containers; when all are taken, the shell is unavailable. Starts per visitor are limited. The numbers come with the host.
- Stop and Restart are the page's buttons; what they end, the visitor's container, is the server's.

There is no pool and no manager (decided 2026-10-26). Each visitor's shell is a WebSocket connection, a process, which starts its command under a terminal and owns it, and which ends, killing the program with it, when the connection closes, a timeout's alarm comes or Stop is pressed. The server knows terminals and not containers: its configuration says that a WebSocket path runs a command under a terminal for each connection, at most so many at once, with an idle and a total time, and the container is the command's, `podman run -it --rm` with its flags and its image. One small process counts the shells running and each visitor's starts, and holds the cookie that names a session, so that a second tab takes it over. So `ernest-httpd` stays a general server, a static site and web terminals, and nothing of ernest-lang.org's sandbox is in its code. Pre-started containers are decided only if a container's start is measured slow.

## TLS

The site is served over HTTPS, and ehttpd terminates TLS itself. `Tcp` gains two functions that open a socket over TLS, `Tcp.listenTls(host, port, certificate, key)` and `Tcp.connectTls(host, port, verify, ms)`, and answers the same socket address as a plain one, so that reading, writing, accepting and closing are one set of functions for both (E.18, principle 2). They are two functions and not a `Bool`, by E.0 shape rule 9. The host's `ssl` does the work, whose functions mirror `gen_tcp`'s, so the runtime's socket process holds either kind; a program that is no node starts `ssl` at its first TLS call, and a node has it already for its carrier. `Tcp.accept` answers the socket once the TCP connection is accepted, and the handshake runs in the socket's own process, as the host splits `ssl:transport_accept` from `ssl:handshake`, so that a slow client holds no accept loop; the first `read` or `write` waits for it, and a failed handshake answers there as `Other(text)`, the words `ssl` gives, since no program acts on it otherwise than on another failed connection. The certificate and key are files, renewed by certbot outside the server, which a restart reads again.

This replaces the plan's separate `libs/tls`, which named the choice to be made when it was written.

## Limits against a crowd

Decided 2026-10-27, each number the configuration's.

- **Open connections** have a cap, and a smaller one per remote address. The listener monitors each connection it spawns and counts their `Down`s, and stops accepting at the cap, so that the excess waits in the kernel's backlog and costs the server nothing; it answers no 503, which would spend work on the clients there are too many of.
- **Every write has a deadline**, `Tcp.write`'s milliseconds, so that a client that asks and never reads loses its connection.
- **Headers on every response**, a list of names and values in the configuration, the same for every response: `Strict-Transport-Security`, `X-Content-Type-Options: nosniff` and a `Content-Security-Policy` that allows what xterm.js needs. The server has no headers of its own opinion.
- **No rate limit on requests.** A static file is cheap, the shells have their caps and start limits, and a flood past these is the network's to stop.

## Hosts, port 80 and the certificate

Decided 2026-10-27.

- **The hosts.** The configuration names a `canonical-host`, `ernest-lang.org`, and its `redirect-hosts`, `www.ernest-lang.org`, `ernest-lang.se` and `www.ernest-lang.se`. On HTTPS a request to a redirect host answers 301 to `https://` and the canonical host with the same target. A host that is neither answers 421. A redirect is built from the configured host alone and never from the one a request sent, so that a forged `Host` cannot make the server a redirector to anywhere.
- **Port 80** is a listener of a third kind beside plain and TLS, `redirect`. A request under `/.well-known/acme-challenge/` is served from a configured directory, for any of the hosts, so that certbot's `--webroot` mode renews without the server stopping and without the port. Every other request answers 301 to `https://` and the canonical host with the same target. With `Strict-Transport-Security` sent on HTTPS, a browser that has visited once does not use port 80 again.
- **One certificate** names all four hosts, which Let's Encrypt issues as one file and one key, so the server chooses no certificate by name. The `.se` names must be in it, since a browser that tries HTTPS first checks the certificate before it sees a redirect.
- **A renewal is a restart.** Certbot's deploy hook, which runs only when the certificate was renewed, about once in 60 days, restarts the server; the live shells end, their pages showing *disconnected*. A reload without restarting would need `Tcp` to give an accepted socket new certificates, machinery in the standard library for one event in two months, decided only if a site's shells must not drop.

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
  - `Http.readHead(socket, carried, limits, ms) : Either(Http.ReadError, #(Request, Bytes))`, written over `parseHead`: `carried` the bytes left after the last request, so a pipelined one is kept, and `ms` bounding the whole head and not each read, so a client that sends a byte a second meets 408. `Http.ReadError` is `Head(Http.Error)` or `Socket(Io.Error)`. It reads one head and returns; accepting, dispatching, keeping a connection and logging are the server's.
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
- **`Os`**, its contract decided on 2026-10-26:
  - `Os.startTerminal(command, size) : Either(Io.Error, Address(ProgramMsg))`, the `Command` `start` takes and the address it answers, so that `read`, `write`, `kill`, `monitor` and `give` serve both (principle 2); `size` is `Terminal`'s type for a terminal's rows and columns.
  - One stream out: a pseudo-terminal merges standard output and standard error, so `read` answers `Stdout(bytes)` alone, then `Exited(status)`, which the page states.
  - `Os.resize(program, size) : Either(Io.Error, Unit)`: the host sets the terminal's size and the program's foreground process is told, as a resized xterm tells its shell; on a program `start` started it answers `Left(NotATerminal)`.
  - `closeInput` hangs the terminal up, the program sent the hangup a closed xterm sends, stated on the page.
  - The terminal starts in the operating system's ordinary mode, echoing and by lines, and the runtime sets no `TERM`: the command's environment does.
  - The runtime's C helper does the work by the host's `forkpty` and the size's `ioctl` (E.0 rule 1), on Linux and macOS. The terminal tests' `ern_pty.py` could then go, a later item's work.

## The program's modules, a first sketch

A guess at `ernest-httpd`'s modules by the jobs above, each with one job as the style guide asks (2026-10-27); none decided.

- **`Main`**: reads the arguments, loads the configuration, starts the rest, and stops in order at `Os.termination`, closing the listeners, finishing the requests under way and closing the shells with 1001.
- **`Config`**: the JSON read through `libs/json` into one record, and every rule it checks, so that a bad file is refused at the start with its field named.
- **`Listener`**: one per listen address, plain or TLS, accepting and spawning a connection for each socket, and nothing else.
- **`Connection`**: a socket's life, reading heads through `Http.readHead` with the bytes carried over, keeping the connection or closing it, the idle deadline, and handing each request to `Static` or, at an upgrade on the shell's path, to `Shell`.
- **`Static`**: a request to a response, the path resolved under the root and `..` refused, the index file, the table of content types, `Last-Modified` and 304.
- **`Shell`**: one WebSocket session, the handshake through `libs/websocket`, the command started by `Os.startTerminal`, bytes both ways, a resize to `Os.resize`, and its end by a close, an alarm or Stop.
- **`Sessions`**: the counting process, holding the shells running, each visitor's starts and the cookie that names a session.
- **`AccessLog`**: the process that owns the log file and writes each line of Common Log Format through `libs/time`, so that lines from many connections never interleave.

Five of them are processes for the program's life or a connection's, the listener, a connection, a shell and the two that hold state; `Static` and `Config` are functions over their file reads, where the tests begin.

## Configuration

One JSON file, read through `libs/json`, named on the command line:

- the listen address and port, and the TLS certificate's and key's paths;
- the root the files are served from;
- the timeouts, for a request's head and for an idle connection;
- the limits, on a request line, on the headers and on a WebSocket message;
- extensions added to the table of content types;
- the WebSocket's path, its allowed origins and the command that runs a visitor's shell;
- the canonical host and the redirect hosts, and the ACME challenge's directory;
- the caps on open connections, in all and per remote address, and the deadline of a write;
- the headers sent on every response.

A file that breaks a rule is refused at the start, the message naming the field.

## The log

The log is written to standard output, which the journal keeps and rotates, and to no file of the server's (decided 2026-10-27). Every request is a line of Common Log Format, `host - - [10/Oct/2026:13:55:36 +0000] "GET / HTTP/1.1" 200 2326`, written in UTC, so that logs of two machines agree and the library needs no time zone. A WebSocket's line is written when it closes, its status 101 and its byte count the frames' payloads.

## Under systemd

ehttpd runs in the foreground, under a unit of `Type=exec`. It writes its access log to standard output and what goes wrong to standard error, both of which the journal keeps and rotates. It exits with a status that is not 0 when it fails, so that `Restart=on-failure` restarts it. `SIGTERM` stops it in order through `Os.termination`: the listener closes, the requests under way are answered, and the WebSockets are closed with 1001. It binds 80 and 443 through `AmbientCapabilities=CAP_NET_BIND_SERVICE`, as no root.

A change of configuration is a restart. A static site restarts in about a second, and reloading would mean running ehttpd as a node, since `SIGHUP` is a reload only for a node (§8.6). `Type=notify` would need a Unix datagram socket, which Ernest lacks, and `Type=exec` serves.

## Decided so far

- TLS in `Tcp`, by two functions answering the same socket (2026-10-26).
- `libs/time` for the dates, a library and not the standard library's, `Clock` unchanged (2026-10-26).
- A change of configuration is a restart (2026-10-26).
- The pseudo-terminal on the server through a new start in `Os`, podman inside it (2026-10-26).
- The errors: a failed handshake is `Other(text)`, run in the socket's process after `accept`; `Http.Error` and `WebSocket.Error` named by the status and the close code they answer (2026-10-26).
- `Http.readHead` in the library beside the parser, bounding the whole head (2026-10-26).
- `Os.startTerminal`'s contract: one address with `start`, one stream out, `resize` answering `NotATerminal` on pipes, `closeInput` a hangup, no `TERM` of the runtime's (2026-10-26).
- The repository is `ernest-httpd` (2026-10-26).
- No container pool and no manager: a process per shell owns its command under a terminal, one counting process limits them, and the container is the command's (2026-10-26).
- A canonical host and its redirect hosts, port 80 a redirect listener serving the ACME challenge, one certificate for all four names, a renewal a restart (2026-10-27).
- The limits, each configurable: a cap on connections in all and per address by counting `Down`s, a deadline on every write, the configured headers on every response, and no rate limit; the log to standard output; a directory's slash and its missing index (2026-10-27).
- Files under a root no one else writes: a path holding `..` refused, and no check of links, so the plan's `Fs.readUnder` waits for a root others can write (2026-10-26).
