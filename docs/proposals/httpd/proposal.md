# ernest-httpd, the server for ernest-lang.org

A starting point, written 2026-10-26 from the first discussion, and read back on 2026-10-30 against the report, the plan and the host, its findings applied the same day. It states what the server does and what it leaves out; the reasons are given where a choice was made, and stay here until the proposal is decided.

## What it is for

`ernest-httpd` serves one site, ernest-lang.org: static pages generated from Markdown (MVP 4.2), and one WebSocket per visitor that connects xterm.js in the browser to a shell on the server. It implements what that needs of HTTP/1.1 and nothing more. It is a program written in Ernest, in a repository of its own, `ernest-httpd` (decided 2026-10-26), under Ernest's own license (decided 2026-10-27), built against an installed Ernest; `examples/web_server.ern` is its smallest ancestor, whose hand-written parser `libs/http` replaces.

## From the plan's MVP 4.1

What the plan's MVP 4.1 states of the server, held here as the proposal's own, the plan's section to become a line pointing here once the proposal is decided (2026-10-26):

- The server is a program in a repository of its own, decided with the user on 2026-10-10 (the log's *ehttpd and the Website*), the first program built against an installed Ernest by a build of its own, which the examples cannot be. Its own plan lives in its repository.
- What it lacks is added where it belongs and never worked around in Erlang or behind a `foreign fn`: a function the standard library lacks enters by E.0's admission rules, our need the occasion and the rules deciding; a format or a protocol is a library's; what the prelude or the language lacks goes to `language_feedback.md` first and is discussed before any code goes around it.
- Each library it asks for is an Ernest source root under `src/libs/<name>/`, whose build ends every job's load path, with `src/stdlib/`'s test discipline, documented to `docs/module_doc_template.md` with its executed examples as its first user, and a section in Appendix G.
- The plan's separate `libs/tls` is replaced by TLS in `Tcp` (below). The plan's other named libraries, `libs/regex`, `libs/uri`, `libs/zlib`, the `Fs` functions and `Udp`, are not the server's and stay in the plan.

## HTTP/1.1

RFC 9110 states HTTP's semantics and RFC 9112 its HTTP/1.1 message syntax.

**What it implements.**

- The methods `GET` and `HEAD`. Any other method answers 405 with `Allow: GET, HEAD`.
- A request target in origin form, and one in absolute form taken by its path, which RFC 9112 asks a server to accept.
- `Host`, required of HTTP/1.1: a 1.1 request without it answers 400, and a 1.0 request without it, which HTTP/1.0 allows, is served as the canonical host (decided 2026-10-27).
- Persistent connections by default for HTTP/1.1, and for 1.0 only where it sent `Connection: keep-alive`, as RFC 9112 has it (decided 2026-10-27); `Connection: close` honored, and requests answered in the order they came, which a loop that reads one request at a time gives.
- Every response with `Content-Length`, `Date` and a `Content-Type` from a small table of extensions, which the configuration may extend, text types with `; charset=utf-8`. `Http.render` writes `Content-Length` from the body's size unless the response's headers carry one, which a `HEAD` response does, the file's size with no body (decided 2026-10-30).
- `Last-Modified` from the file, and `If-Modified-Since` answered with 304.
- A directory answered by its `index.html`; one asked for without its trailing slash answers 301 to the path with it, so that its page's relative links resolve; one without `index.html` answers 404, with no listing. A path that names no file answers 404, and a path holding `..` is refused with 400.
- The path is percent-decoded first, then normalized, then checked for `..`, so that `/%2e%2e/` is refused as `/../` is; an encoded slash, `%2F`, answers 400, since no name on the site holds one; the query is ignored (decided 2026-10-27).
- A name beginning with `.` answers 404, `/.well-known/` on the redirect listener aside, so that nothing like a `.git` or an editor's backup is ever served (decided 2026-10-27).
- An error answers a short body of plain text, and a 404 the root's `404.html` where it exists, with the status 404 (decided 2026-10-27).
- No `Cache-Control`: `Last-Modified` and 304 make a revisit a cheap check, and headers by path wait for a measured need (decided 2026-10-27).
- The content types built in are `html`, `css`, `js`, `json`, `svg`, `png`, `ico`, `woff2`, `txt` and `wasm`, the configuration adding the rest (decided 2026-10-27).
- The errors a log's reader needs: 400, 404, 405, 408 on a request that comes too slowly, 413 on a request with a body, 414 and 431 past the limits, 421 on a host it does not serve, 500, and 505 on another version.

**What it leaves out.**

- A request body. A request that carries one, by a `Content-Length` above zero or any `Transfer-Encoding`, answers 413 and its connection is closed; a `Content-Length: 0` is no body and is served (decided 2026-10-30). The refusal stands since nothing on the site takes input over HTTP. That leaves out chunked request decoding and `Expect: 100-continue` too.
- Chunked responses, since every file has a size.
- Ranges, `ETag`, content negotiation, trailers and HTTP/2.
- Compression, until the site's pages are measured and a first visit is found slow (decided 2026-10-27). Its shape is known and changes nothing here: the site's generator writes `page.html.gz` beside `page.html` through the host's `zlib`, and the server sends the `.gz` file where `Accept-Encoding` names `gzip`, with `Content-Encoding: gzip` and `Vary: Accept-Encoding`, compressing nothing itself.

## WebSocket

RFC 6455, for xterm.js.

**What it implements.**

- The upgrade's handshake on the configured path. `Sec-WebSocket-Accept` is the SHA-1 of the client's key and a fixed string, written in base64.
- An `Origin` check against the origins the configuration allows, since a WebSocket is not held to the browser's same-origin rule.
- Text and binary frames, the client's masking, continuation frames, which a server must accept, and the three forms of a payload's length.
- Ping and pong, and the closing handshake.
- A limit on a message's size, past which the connection closes with 1009.

**What it leaves out.** Extensions, `permessage-deflate` among them, and subprotocols, which xterm.js's attach addon does not ask for.

Behind the socket stands a shell in a container per visitor (`../site/decisions.md`). The pseudo-terminal is the server's: `Os` gains a start under a pseudo-terminal of a given size, and a resize, which the runtime's helper gives by the host's `forkpty` and `TIOCSWINSZ`, and `ernest-httpd` runs `podman run -it --rm` on it, podman giving the container its own terminal and forwarding each resize. The socket carries the terminal's bytes both ways, and a few messages beside them, a resize from xterm.js's fit addon among them (*The live shell's server side*).

## The live shell's server side

Moved here from the site's decisions on 2026-10-26, where the page's side of the shell stays (`../site/decisions.md`, *The live shell*); the pseudo-terminal is the WebSocket's other end, above.

- One operating-system container per visitor, shared by every page: allocated when the shell first opens, reused after.
- The image holds `ern`, the standard library, `src/libs/`, the examples and a scratch directory, and nothing secret, since a `foreign fn` reads the image and the environment.
- The container has no network but loopback, so that the guide's `Tcp` examples, which talk to themselves, run.
- The scratch directory is a size-capped tmpfs, counted into the visitor's memory, so that a program that writes without end ends its own session and no other.
- The language is whole in the container: no module is forbidden, since nothing done through `Fs`, `Os`, `Tcp` or a `foreign fn` leaves the container, and a shell with fewer modules would be a second mode of the language that the guide's examples would not run in (decided 2026-10-13).
- A session lives five minutes from the visitor's last key or click on Extend: one deadline, which either moves; an alarm cannot be canceled (E.15), so the session counts its alarms and ignores a stale one. A warning comes after four quiet minutes, and Extend serves a visitor whose program runs without their typing; a visitor who walked away does neither, and the session ends a minute after the warning (decided 2026-10-27, in place of an idle time with a key's answer and a total of 30 minutes). There is no total cap: a session kept alive by keys holds one of the shells the cap allows, and no more.
- A second tab takes the session over, and the first says so.
- A fixed number of containers; when all are taken, the shell is unavailable. A visitor's starts are limited to a count within milliseconds, `RestartLimit`'s shape, the visitor being the remote address and not the cookie, which a visitor resets by clearing it (decided 2026-10-27). The numbers come with the host.
- Stop and Restart are the page's buttons; what they end, the visitor's container, is the server's.

There is no pool and no manager (decided 2026-10-26).

Measured on 2026-10-13, when the container per visitor was decided (moved here from `../shell/attached.md` on 2026-10-27), on an eight-core machine: a bare `erl` with nothing loaded is 71 MB, a bare Ernest node listening 87 MB, and a program's run 72 MB at its peak and 0.6 seconds from start to exit. So a visitor's shell is a BEAM of about 90 MB that starts in under a second. On the web machine of two cores and 2 GB, the system and the site's own node take about 300 MB, which leaves ten or twelve shells at a cap of 128 MB each. Memory is the first and cheapest thing to add if the site ever wants more.

What other systems do, read the same day:

- **The Go and Rust playgrounds** run each submission in a fresh sandbox with time, memory and output limits and no network, and keep nothing; a container or a VM per run.
- **Try Elixir, Try OCaml and Jupyter's kernels** run one process per visitor behind a web terminal, each with its own limits; one runtime per user, not one for all.
- No system known then runs strangers' sessions on one shared runtime without a process-level wall; those that share one runtime trust their users.

A session outlives a connection (decided 2026-10-27), since moving to another page closes the WebSocket and the site's decisions keep a visitor's shell across pages: `Sessions` holds a session process for each cookie, which starts its command under a terminal and owns it, and which ends, killing the program with it, at its lifetime's alarm or at Stop.

A session starts its command at the page's first resize and not at the connection, so that the shell starts at the panel's size and not a guessed one (decided 2026-10-27). A connection attaches to its session and detaches when it closes, the lifetime running whether one is attached or not; a second tab is a second attach, which detaches the first and tells it so.

The server knows terminals and not containers: its configuration says that a WebSocket path runs a command under a terminal for each connection, at most so many at once, with a session's lifetime, and the container is the command's, `podman run -it --rm` with its flags and its image. So `ernest-httpd` stays a general server, a static site and web terminals, and nothing of ernest-lang.org's sandbox is in its code. Pre-started containers are decided only if a container's start is measured slow.

`Sessions` counts the shells running and each visitor's starts. A session's cookie is set on the WebSocket's 101 response where the request carried none, so that the static pages set no cookie and the privacy line can say that the shell alone does (decided 2026-10-27). It is drawn from `Crypto.randomBytes`, so it cannot be guessed as the web-server example's can, and is sent `Secure`, `HttpOnly` and `SameSite=Strict`.

**What the page and the server say** over the one WebSocket (decided 2026-10-27):

- **Binary frames are the terminal's bytes**, both ways and nothing else, reaching xterm.js and the pseudo-terminal untouched.
- **Text frames are small JSON messages**, read and written through `libs/json`. From the page, `{"resize": [rows, columns]}`, `{"extend": true}` and `{"stop": true}`; from the server, `{"warning": 60}`, the seconds left, at which the page shows Extend.
- **The close code says why a session ended**, from RFC 6455's range for applications: 4001 expired, 4002 taken over by another tab, 4003 unavailable where no shell is free, and 4004 stopped. A close without one of them, or a lost connection, is *disconnected*. Restart is the page's Stop and a new connection, which starts a new session.

## TLS

The site is served over HTTPS, and `ernest-httpd` terminates TLS itself. `Tcp` gains two functions that open a socket over TLS, `Tcp.listenTls(host, port, certificate, key)` and `Tcp.connectTls(host, port, verify, ms)`, and answers the same socket address as a plain one, so that reading, writing, accepting and closing are one set of functions for both (E.18, principle 2). They are two functions and not a `Bool`, by E.0 shape rule 9.

The host's `ssl` does the work, whose functions mirror `gen_tcp`'s, so the runtime's socket process holds either kind; a program that is no node starts `ssl` at its first TLS call, and a node has it already for its carrier.

`Tcp.accept` answers the socket once the TCP connection is accepted, and the handshake runs in the socket's own process, as the host splits `ssl:transport_accept` from `ssl:handshake`, so that a slow client holds no accept loop; the first `read` or `write` waits for it, and a failed handshake answers there as `Other(text)`, the words `ssl` gives, since no program acts on it otherwise than on another failed connection. `listenTls` answers `Left(Other(text))`, the host's words, for a certificate or a key the host refuses, as a failed handshake does (decided 2026-10-30). The certificate and key are files, renewed by certbot outside the server, which a restart reads again.

This replaces the plan's separate `libs/tls`, which named the choice to be made when it was written.

## Limits against a crowd

Decided 2026-10-27, each number the configuration's.

- **Open connections** have a cap, and a smaller one per remote address. The listener monitors each connection it spawns and counts their `Down`s, and stops accepting at the cap, so that the excess waits at the kernel, in the listener's backlog and past it by retransmitted SYNs, since `Tcp.listen` states no backlog and the host's default is small, and costs the server nothing; it answers no 503, which would spend work on the clients there are too many of.
- **Every write has a deadline**, `Tcp.write`'s milliseconds, so that a client that asks and never reads loses its connection.
- **Headers on every response**, a list of names and values in the configuration, the same for every response: `Strict-Transport-Security`, `X-Content-Type-Options: nosniff` and a `Content-Security-Policy` that allows what xterm.js needs, `wss:` for the shell's socket among it. The server has no headers of its own opinion.
- **No rate limit on requests.** A static file is cheap, the shells have their caps and start limits, and a flood past these is the network's to stop.

## Security

Decided 2026-10-27, beside what the sections above decide of the path, the hosts, the limits, the socket's origin and the cookie.

**What the server writes from a client's bytes.**

- A line of the access log escapes `"`, `\` and every byte outside printable ASCII as `\xHH`, as Apache's does, so that no request forges a line.
- A redirect's `Location` is built from the canonical host and a target the parser accepted, and a target holding a control byte answers 400, so that no client splits a response.
- Two `Host` headers, or a header folded over two lines, answer 400; with bodies refused, request smuggling has nothing else to work with. The host joins a folded header into one value that holds the fold, so `libs/http` answers `Malformed` for a value holding CR or LF, and scans nothing before the shim (checked 2026-10-30).
- A 500's body is its plain line alone; the fault and its trace go to standard error and never to the client.

**The WebSocket.**

- A message's fragments count toward its limit as they arrive, and a control frame past RFC 6455's 125 bytes is a protocol error.
- A detached session stops reading its terminal, so that its program blocks on output as on a full terminal and nothing is buffered without bound while no tab is attached; reading resumes at the next attach.

**TLS and keys.**

- TLS 1.2 and 1.3 alone, with the host's default ciphers.
- The private key is readable by the server's user alone, which `Config` checks at the start, as a node checks its own key.

**The host.**

- Rootless podman under a dedicated unprivileged user, the container `--read-only`, `--cap-drop=ALL` and `--security-opt=no-new-privileges`; `--network none` keeps loopback, as the site's decisions ask.
- The unit takes `ProtectSystem=strict`, `PrivateTmp` and `ReadWritePaths` narrowed to the log's directory and to podman's storage and run directories, which `ProtectSystem=strict` makes read-only with the rest and which are found at deployment, and leaves out `NoNewPrivileges=yes`, which breaks rootless podman's setuid `newuidmap`, saying so in a comment.

## Hosts, port 80 and the certificate

Decided 2026-10-27.

- **The hosts.** The configuration names a `canonical-host`, `ernest-lang.org`, and its `redirect-hosts`, `www.ernest-lang.org`, `ernest-lang.se` and `www.ernest-lang.se`. On HTTPS a request to a redirect host answers 301 to `https://` and the canonical host with the same target. A host that is neither answers 421. A redirect is built from the configured host alone and never from the one a request sent, so that a forged `Host` cannot make the server a redirector to anywhere.
- **Port 80** is a listener of a third kind beside plain and TLS, `redirect`. A request under `/.well-known/acme-challenge/` is served from a configured directory, for any of the hosts, so that certbot's `--webroot` mode renews without the server stopping and without the port. Every other request answers 301 to `https://` and the canonical host with the same target. With `Strict-Transport-Security` sent on HTTPS, a browser that has visited once does not use port 80 again.
- **One certificate** names all four hosts, which Let's Encrypt issues as one file and one key, so the server chooses no certificate by name. The `.se` names must be in it, since a browser that tries HTTPS first checks the certificate before it sees a redirect.
- **A renewal is a restart.** Certbot's deploy hook, which runs only when the certificate was renewed, about once in 60 days, copies the certificate and the key to the server's directory, owned by the server's user and the key readable by it alone, since certbot's own are root's, and then restarts the server (decided 2026-10-30); the live shells end, their pages showing *disconnected*. A reload without restarting would need `Tcp` to give an accepted socket new certificates, machinery in the standard library for one event in two months, decided only if a site's shells must not drop.

## The libraries it asks for

- **`libs/http`**: a shim over `erlang:decode_packet/3` with `http_bin`, which reads a request line and one header at a time and answers `more` where the bytes end. Ernest closes the difference, a header's name as a string where the host gives some as atoms, and the host's limits on a line stated; rendering a response is Ernest. No server loop. Its client half's first use beside the tests is an example of the repository's, `fetch`, a command-line tool that fetches JSON over HTTPS with `Verified(caFile)` and prints a report, which the plan names.
- **`libs/time`**: the calendar alone, a shim over the host's `calendar`: a moment of `Clock` as its civil date and time in UTC, and back. A format is its owner's, written over it: RFC 9110's date is `libs/http`'s and the Common Log Format's is the server's (decided 2026-10-27). Dates are a library's (E.0 rule 2), so `Clock` stays as it is: `Clock.toString` was admitted as the one text form the runtime's own lines write, and nothing more of a calendar enters it.
- **`libs/crypto`**: a SHA-1 digest and strong random bytes, shims over `crypto`.
- **`libs/websocket`**: the handshake's key and the frames, decoded and encoded, which the server and a client share.
- **`libs/base64`**: a shim over `base64`.

## The functions, a first cut

Names and shapes by E.0's shape rules, each a draft for the discussion and none decided.

- **`libs/http`.**
  - `Request`, a method, a target, a version and headers, and `Response`, a status, headers and a body as `Bytes`.
  - `Http.parseHead(bytes) : Either(Http.Error, Head)`, `Head` either `Incomplete` or the request with the bytes after it, a shim over `decode_packet` driven a line at a time.
  - `Http.readHead(socket, carried, limits, ms) : Either(Http.ReadError, #(Request, Bytes))`, written over `parseHead`: `carried` the bytes left after the last request, so a pipelined one is kept, and `ms` bounding the whole head and not each read, so a client that sends a byte a second meets 408. `Http.ReadError` is `Head(Http.Error)` or `Socket(Io.Error)`. It reads one head and returns; accepting, dispatching, keeping a connection and logging are the server's. The two timeouts map onto two reads: `Connection` waits for a request's first bytes with `Tcp.read` under the idle deadline, closing quietly when it passes, and then calls `readHead` with those bytes carried under the head deadline, which alone answers 408 (decided 2026-10-30).
  - `Http.header(request, name) : Optional(String)`, by name in any case.
  - `Http.render(response) : Bytes` and `Http.reason(status) : String`.
  - For a client, the tests' first: a request rendered, and a response's head read from a socket as `readHead` reads a request's.
  - `Http.Error`, saying what is wrong and no status: `Malformed`, `TargetTooLong` and `HeadersTooLarge`. Which status each answers is the server's, 400, 414 and 431 in `Connection`, since a client meets the same errors and answers none (decided 2026-10-27). A version other than 1.0 or 1.1 parses, and the server answers it 505.
  - `Http.date(time) : String` and `Http.parseDate(text) : Optional(Int)`, RFC 9110's form, `Sun, 06 Nov 1994 08:49:37 GMT`, written over `Time.civil` with the English names of days and months the RFC fixes, for `Date`, `Last-Modified` and `If-Modified-Since` (decided 2026-10-27).
- **`libs/websocket`**, a library of its own and not the server's, since a client wants it too.
  - `WebSocket.accept(key) : String`.
  - `WebSocket.decode(bytes, role, limit) : Either(WebSocket.Error, Decoded)`, `Incomplete` or a frame with the bytes after it, as `Head` carries those after a request; `role`, `FromClient` or `FromServer` by shape rule 9, decides which masking it refuses.
  - `WebSocket.Error`: `ProtocolError`, `TooBig` and `NotUtf8`, and `WebSocket.closeCode(error)`, 1002, 1009 and 1007, which RFC 6455 itself assigns, so the mapping is the protocol's and the library's.
  - `WebSocket.encode(frame) : Bytes`, a `Frame` one of text, binary, continuation, ping, pong and close, unmasked as a server sends one; and `WebSocket.encodeMasked(frame, key) : Bytes` for a client, whose every frame RFC 6455 has masked with a four-byte key the client draws, `key` drawn by the caller from `Crypto.randomBytes` so that the pure library holds no randomness (decided 2026-10-30).
- **`libs/crypto`**: `Crypto.sha1(bytes)`, a digest, and `Crypto.randomBytes(count)`, bytes from the host's strong random source, each a shim over `crypto`, and nothing more until something asks (decided 2026-10-27); the server uses the one for the WebSocket's handshake and the other for a session's cookie.
- **`libs/base64`**: `Base64.encode(bytes) : String` and `decode(text) : Optional(Bytes)`.
- **`libs/time`**, a library and not the standard library's, by E.0's rule for a module over a published specification or a policy and E.15's sentence that nothing of dates but `Clock.toString` is the standard library's (decided 2026-10-26).
  - `Time.civil(time) : Civil`, its year, month, day, hour, minute, second and weekday in UTC, and `Time.fromCivil(civil) : Optional(Int)`, `None` for a date the calendar has not, from which a program writes any form it owns.
- **`Tcp`**: `listenTls` and `connectTls`, as decided; `connectTls`'s `verify` is `Verified(caFile)` or `Unverified`, a constructor and not a `Bool` by shape rule 9 (decided 2026-10-27).
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
- **`Shell`**: one WebSocket connection, the handshake through `libs/websocket`, attached to its session, bytes both ways and a resize passed on, and its detach at its close.
- **`Sessions`**: the session processes by cookie, each owning its command under `Os.startTerminal` with its timers, and the counts of shells running and of each visitor's starts.
- **`AccessLog`**: the process that writes the lines of Common Log Format, their date its own over `Time.civil`, to the configured file, by its path and in batches, so that lines from many connections never interleave.

Five of them are processes for the program's life or a connection's, the listener, a connection, a shell and the two that hold state; `Static` and `Config` are functions over their file reads, where the tests begin.

## How it is tested

Decided 2026-10-27.

- **The libraries**, in Ernest's repository, with the standard library's discipline: doc examples and `Test.Case`s run by `ern test`. `Http.parseHead` and `WebSocket.decode` are pure, bytes in and values out, the RFCs' own examples among them, RFC 6455's handshake key and its accept value first.
- **`Static` and `Config`**, as functions over a scratch directory: a path to its response, a bad file to its refusal.
- **The running server**, started on port 0 and talked to by a client in Ernest: `libs/http` gains a request rendered and a response's head read, `readHead`'s twin, and `libs/websocket`'s `FromServer` role is used from the other side, the same code a user's client would want. No test is written in Python, which would be the gap `ern_pty.py` meets. `curl` stays as one smoke test, run by hand against the deployed site.

## Configuration

One JSON file, read through `libs/json`, named on the command line:

- the listeners, each an address, a port and a kind, `tls` with the certificate's and key's paths, `redirect` with the ACME challenge's directory, or `plain`, for development;
- the root the files are served from;
- the timeouts, for a request's head and for an idle connection;
- the limits, on a request line, on the headers and on a WebSocket message;
- extensions added to the table of content types;
- the WebSocket's path, its allowed origins and the command that runs a visitor's shell, and the shell's numbers: the most at once, the starts per visitor, a session's lifetime and its warning;
- the canonical host and the redirect hosts;
- the caps on open connections, in all and per remote address, and the deadline of a write;
- the headers sent on every response;
- the access log's path.

A file that breaks a rule is refused at the start, the message naming the field.

An exhaustive example, in `ernest.conf`'s style, its keys in kebab case and its times in milliseconds (2026-10-27):

```json
{
  "listeners": [
    { "kind": "tls", "address": "0.0.0.0", "port": 443,
      "certificate": "/etc/letsencrypt/live/ernest-lang.org/fullchain.pem",
      "key": "/etc/letsencrypt/live/ernest-lang.org/privkey.pem" },
    { "kind": "tls", "address": "::", "port": 443,
      "certificate": "/etc/letsencrypt/live/ernest-lang.org/fullchain.pem",
      "key": "/etc/letsencrypt/live/ernest-lang.org/privkey.pem" },
    { "kind": "redirect", "address": "0.0.0.0", "port": 80,
      "acme-challenge": "/srv/ernest-httpd/acme" },
    { "kind": "redirect", "address": "::", "port": 80,
      "acme-challenge": "/srv/ernest-httpd/acme" }
  ],
  "root": "/srv/ernest-lang.org/site",
  "canonical-host": "ernest-lang.org",
  "redirect-hosts": ["www.ernest-lang.org", "ernest-lang.se", "www.ernest-lang.se"],
  "timeouts": { "head": 10000, "idle": 60000, "write": 30000 },
  "limits": {
    "request-line": 8192, "headers": 16384,
    "connections": 1024, "connections-per-address": 32
  },
  "content-types": { ".wasm": "application/wasm" },
  "headers": {
    "Strict-Transport-Security": "max-age=31536000",
    "X-Content-Type-Options": "nosniff",
    "Content-Security-Policy": "default-src 'self'; connect-src 'self' wss://ernest-lang.org"
  },
  "access-log": "/var/log/ernest-httpd/access.log",
  "shell": {
    "path": "/shell/session",
    "origins": ["https://ernest-lang.org"],
    "command": ["podman", "run", "-it", "--rm", "--network", "none",
                "--read-only", "--cap-drop=ALL", "--security-opt=no-new-privileges",
                "--memory", "128m", "--pids-limit", "128", "ernest-shell"],
    "most-at-once": 10,
    "starts": { "count": 10, "within": 3600000 },
    "lifetime": 300000, "warning": 60000,
    "message-limit": 65536
  }
}
```

Each address family has listeners of its own, `0.0.0.0` and `::`, so that nothing depends on the kernel's dual stack. The podman flags are the site's, an example of the command's and no rule of the server's; the ten shells at 128 MB are the measure's for the web machine of 2 GB (*The live shell's server side*).

## The log

The log is a file the configuration names (decided 2026-10-27, superseding standard output the same day). `AccessLog` writes by the path and holds no file open: each write is `Fs.append`, which opens, appends and closes, so that logrotate's ordinary rotation, a rename and a new file, needs no signal and no reload, the next append opening the new file by its name, and no line is lost.

`AccessLog` appends in batches, every line waiting in its mailbox in one append, so that a busy server opens the file once for many lines and the cost per line falls as the load rises; what has arrived decides the batch, and no timer.

Every request is a line of Common Log Format, `host - - [10/Oct/2026:13:55:36 +0000] "GET / HTTP/1.1" 200 2326`, written in UTC, so that logs of two machines agree and the library needs no time zone. A WebSocket's line is written when it closes, its status 101 and its byte count the frames' payloads.

## Under systemd

`ernest-httpd` runs in the foreground, under a unit of `Type=exec`. It writes its access log to the configured file, which logrotate rotates with no `postrotate`, and what goes wrong to standard error, which the journal keeps. It exits with a status that is not 0 when it fails, so that `Restart=on-failure` restarts it. `SIGTERM` stops it in order through `Os.termination`: the listener closes, the requests under way are answered, and the WebSockets are closed with 1001. It binds 80 and 443 through `AmbientCapabilities=CAP_NET_BIND_SERVICE`, as no root.

It is run as `ern run ernest-httpd.erc /etc/ernest-httpd/config.json`, the configuration's path its one argument, which the unit's `ExecStart` says, and the unit's `TimeoutStopSec` stands above the write deadline, so that an orderly stop ends before systemd kills it (decided 2026-10-27).

A change of configuration is a restart. A static site restarts in about a second, and reloading would mean running the server as a node, since `SIGHUP` is a reload only for a node (§8.6). `Type=notify` would need a Unix datagram socket, which Ernest lacks, and `Type=exec` serves.

## The order of work

Decided 2026-10-27, for the plan once the proposal is ready.

1. **The report first**, in Ernest's repository: `Tcp.listenTls` and `connectTls` in E.18, `Os.startTerminal` and `Os.resize` in E.23 through E.0's admission rules, and a section in Appendix G for each of the five libraries.
2. **The runtime's two additions**: TLS in `Tcp`'s socket process, its handshake after `accept`, and the C helper's `forkpty` and resize behind `Os`, the only changes to the standard library and the riskiest work, before anything stands on them.
3. **The five libraries**: `base64` and `crypto`, which `websocket` needs; `time`; `http` with its client half; then `websocket`.
4. **An installation from the checkout**, `make install` into a prefix, which exists (`docs/design/install.md`), and which `ernest-httpd` builds against, since it is built against an installed Ernest and never against the source tree; a gap the server finds in a library is fixed in the checkout and installed again, with no release between (decided 2026-10-27, in place of a release at this step).
5. **`ernest-httpd`**, in its own repository: `Config` and `Static` as pure functions; `Listener`, `Connection` and `AccessLog`, serving the site over plain HTTP; TLS, the redirect listener and the hosts; `Shell` and `Sessions` last, since they stand on the rest.
6. **The deployment**: the systemd unit, certbot's certificate for the four names, the podman image, and the smoke test against the deployed site.
7. **A release of Ernest**, 0.8.0, when the server first serves the site, carrying the libraries after their first real user has shaped them; 0.7.0 is the attached shell's, MVP 4.0's, which comes first on the road (decided 2026-10-30).

The site's content, MVP 4.2, runs beside any of it, since its generator needs nothing of the server. The terminal tests dropping `ern_pty.py` for `Os.startTerminal` is an item of its own after step 2.

## Decided so far

- TLS in `Tcp`, by two functions answering the same socket (2026-10-26).
- `libs/time` for the dates, a library and not the standard library's, `Clock` unchanged (2026-10-26); the calendar alone, each format with its owner, RFC 9110's in `libs/http` and the log's in the server (2026-10-27).
- A change of configuration is a restart (2026-10-26).
- The pseudo-terminal on the server through a new start in `Os`, podman inside it (2026-10-26).
- The errors: a failed handshake is `Other(text)`, run in the socket's process after `accept`; `Http.Error` saying what is wrong, the server mapping it to a status, and `WebSocket.Error` with the close code RFC 6455 assigns (2026-10-26, the statuses moved to the server 2026-10-27).
- `Http.readHead` in the library beside the parser, bounding the whole head (2026-10-26).
- `Os.startTerminal`'s contract: one address with `start`, one stream out, `resize` answering `NotATerminal` on pipes, `closeInput` a hangup, no `TERM` of the runtime's (2026-10-26).
- The repository is `ernest-httpd` (2026-10-26).
- No container pool and no manager: a process per shell owns its command under a terminal, one counting process limits them, and the container is the command's (2026-10-26).
- A canonical host and its redirect hosts, port 80 a redirect listener serving the ACME challenge, one certificate for all four names, a renewal a restart (2026-10-27).
- The limits, each configurable: a cap on connections in all and per address by counting `Down`s, a deadline on every write, the configured headers on every response, and no rate limit; a directory's slash and its missing index (2026-10-27).
- `libs/crypto` is `sha1` and `randomBytes`; the session's cookie random and `Secure`, `HttpOnly`, `SameSite=Strict`; `connectTls`'s `verify` a constructor (2026-10-27).
- A session outlives a connection: a session process per cookie owns the shell, connections attach and detach, a second tab's attach detaches the first (2026-10-27).
- A session's lifetime five minutes from the last key or Extend, one timer, warned after four quiet minutes (2026-10-27).
- The socket's protocol: binary frames the terminal's bytes, text frames JSON for a resize, Extend, Stop and the warning, and close codes 4001 to 4004 for why a session ended (2026-10-27).
- The access log a configured file, appended by its path in batches of what is waiting, so that logrotate needs no signal (2026-10-27).
- The configuration's exhaustive example; starts limited to a count within milliseconds by remote address; a session started at the page's first resize; a listener per address family (2026-10-27).
- The path decoded before its check and `%2F` refused, dot files 404, error bodies plain with the root's `404.html`, no `Cache-Control`, the cookie set on the 101, how it is run with `TimeoutStopSec`, the built-in content types, Ernest's license (2026-10-27).
- The security section: log lines escaped, `Location` from an accepted target, ambiguous requests refused, error bodies bare, fragments counted as they come, a detached session not read, TLS 1.2 and 1.3, the key's mode checked, rootless podman locked down, and the unit's hardening without `NoNewPrivileges` (2026-10-27).
- HTTP/1.0: a request without `Host` served as the canonical host, its connection closed after the response unless it asked to keep it (2026-10-27).
- No compression until measured; its shape precompressed files the generator writes and the server chooses between (2026-10-27).
- The running server tested by a client in Ernest, `libs/http` gaining a request's rendering and a response's head read (2026-10-27).
- The order of work: the report, the runtime, the libraries, an installation from the checkout, `ernest-httpd` and its deployment, then a release when the site is served (2026-10-27).
- Files under a root no one else writes: a path holding `..` refused, and no check of links, so the plan's `Fs.readUnder` waits for a root others can write (2026-10-26).
- The read-back's findings: the server's release 0.8.0 after the attached shell's 0.7.0; `encodeMasked` for a client with the caller's key; the example's shells ten at 128 MB as measured; the deploy hook copying the certificate and key to the server's user, and the unit's `ReadWritePaths` taking podman's directories; `Decoded` carrying the bytes after the frame; a folded header refused by its value; `Content-Length: 0` no body; `HEAD`'s length from its headers; the idle and head deadlines on two reads; `listenTls`'s `Other(text)`; stale alarms ignored; the backlog the host's; `fetch.ern` kept (2026-10-30).
