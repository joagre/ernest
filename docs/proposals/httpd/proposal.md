# What ernest-httpd asks of Ernest

Begun 2026-10-26 as the server's whole proposal and split on 2026-10-30, when the server's repository was made: this half holds what the server asks of Ernest, TLS in `Tcp`, a pseudo-terminal in `Os`, five libraries, the installation it builds against and the release, each a change to Ernest's report and tree; the server itself, what of HTTP/1.1 and WebSocket it implements, its sessions, its limits, its configuration, its log and its life under systemd, is its own repository's proposal, https://github.com/joagre/ernest-httpd/blob/main/docs/proposals/basic/proposal.md. The reasons are given where a choice was made, and stay here until the proposal is decided.

## What it is for

`ernest-httpd` serves one site, ernest-lang.org: static pages generated from Markdown (MVP 4.2), and one WebSocket per visitor that connects xterm.js in the browser to a shell on the server. It is a program written in Ernest, in a repository of its own, `ernest-httpd` (decided 2026-10-26), under Ernest's own license (decided 2026-10-27), built against an installed Ernest; `examples/web_server.ern` is its smallest ancestor, whose hand-written parser `libs/http` replaces. What follows is what it needs of Ernest.

## From the plan's MVP 4.1

What the plan's MVP 4.1 stated of the server before 2026-10-30, held here as the proposal's own; the plan's section is this proposal's order of work since that day:

- The server is a program in a repository of its own, decided with the user on 2026-10-10 (the log's *ehttpd and the Website*), the first program built against an installed Ernest by a build of its own, which the examples cannot be. Its own plan lives in its repository.
- What it lacks is added where it belongs and never worked around in Erlang or behind a `foreign fn`: a function the standard library lacks enters by E.0's admission rules, our need the occasion and the rules deciding; a format or a protocol is a library's; what the prelude or the language lacks goes to `language_feedback.md` first and is discussed before any code goes around it.
- Each library it asks for is an Ernest source root under `src/libs/<name>/`, whose build ends every job's load path, with `src/stdlib/`'s test discipline, documented to `docs/module_doc_template.md` with its executed examples as its first user, and a section in Appendix G.
- The plan's separate `libs/tls` is replaced by TLS in `Tcp` (below). The plan's other named libraries, `libs/regex`, `libs/uri`, `libs/zlib`, the `Fs` functions and `Udp`, are not the server's and stay in the plan.

## TLS

The site is served over HTTPS, and `ernest-httpd` terminates TLS itself. `Tcp` gains two functions that open a socket over TLS, `Tcp.listenTls(host, port, certificate, key)` and `Tcp.connectTls(host, port, verify, ms)`, and answers the same socket address as a plain one, so that reading, writing, accepting and closing are one set of functions for both (E.18, principle 2). They are two functions and not a `Bool`, by E.0 shape rule 9.

The host's `ssl` does the work, whose functions mirror `gen_tcp`'s, so the runtime's socket process holds either kind; a program that is no node starts `ssl` at its first TLS call, and a node has it already for its carrier.

`Tcp.accept` answers the socket once the TCP connection is accepted, and the handshake runs in the socket's own process, as the host splits `ssl:transport_accept` from `ssl:handshake`, so that a slow client holds no accept loop; the first `read` or `write` waits for it, and a failed handshake answers there as `Other(text)`, the words `ssl` gives, since no program acts on it otherwise than on another failed connection. `listenTls` answers `Left(Other(text))`, the host's words, for a certificate or a key the host refuses, as a failed handshake does (decided 2026-10-30). The certificate and key are files, renewed by certbot outside the server, which a restart reads again.

This replaces the plan's separate `libs/tls`, which named the choice to be made when it was written.

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

## How it is tested

Decided 2026-10-27.

- **The libraries**, in Ernest's repository, with the standard library's discipline: doc examples and `Test.Case`s run by `ern test`. `Http.parseHead` and `WebSocket.decode` are pure, bytes in and values out, the RFCs' own examples among them, RFC 6455's handshake key and its accept value first.
- **The running server** is tested in its repository by a client in Ernest, so `libs/http` gains a request rendered and a response's head read, `readHead`'s twin, and `libs/websocket`'s `FromServer` role is used from the other side, the same code a user's client would want.

## The order of work

Decided 2026-10-27, the plan's MVP 4.1 since 2026-10-30; the server's own steps are its plan's, in its repository.

1. **The report first**, in Ernest's repository: `Tcp.listenTls` and `connectTls` in E.18, `Os.startTerminal` and `Os.resize` in E.23 through E.0's admission rules, and a section in Appendix G for each of the five libraries.
2. **The runtime's two additions**: TLS in `Tcp`'s socket process, its handshake after `accept`, and the C helper's `forkpty` and resize behind `Os`, the only changes to the standard library and the riskiest work, before anything stands on them.
3. **The five libraries**: `base64` and `crypto`, which `websocket` needs; `time`; `http` with its client half; then `websocket`.
4. **The release archive the server builds against**: `ernest-httpd` builds against Ernest installed from `make release`'s `ern-VERSION.tar.gz` (`docs/design/install.md`) and never against the source tree, as a user does, so that what is opaque, badly described or missing in the installation's documents is met as a user meets it and comes here as a line of `language_feedback.md`; a gap is fixed in the checkout and the archive made again, with no public release between (decided 2026-10-30, in place of an installation from the checkout decided 2026-10-27). How the server's repository installs and uses the archive is its own.
5. **A release of Ernest**, 0.8.0, when the server first serves the site, carrying the libraries after their first real user has shaped them; 0.7.0 is the attached shell's, MVP 4.0's, which comes first on the road (decided 2026-10-30).

The site's content, MVP 4.2, runs beside any of it, since its generator needs nothing of the server. The terminal tests dropping `ern_pty.py` for `Os.startTerminal` is an item of its own after step 2.

## Decided so far

- TLS in `Tcp`, by two functions answering the same socket (2026-10-26).
- `libs/time` for the dates, a library and not the standard library's, `Clock` unchanged (2026-10-26); the calendar alone, each format with its owner, RFC 9110's in `libs/http` and the log's in the server (2026-10-27).
- The pseudo-terminal on the server through a new start in `Os`, podman inside it (2026-10-26).
- The errors: a failed handshake is `Other(text)`, run in the socket's process after `accept`; `Http.Error` saying what is wrong, the server mapping it to a status, and `WebSocket.Error` with the close code RFC 6455 assigns (2026-10-26, the statuses moved to the server 2026-10-27).
- `Http.readHead` in the library beside the parser, bounding the whole head (2026-10-26).
- `Os.startTerminal`'s contract: one address with `start`, one stream out, `resize` answering `NotATerminal` on pipes, `closeInput` a hangup, no `TERM` of the runtime's (2026-10-26).
- `libs/crypto` is `sha1` and `randomBytes`; the session's cookie random and `Secure`, `HttpOnly`, `SameSite=Strict`; `connectTls`'s `verify` a constructor (2026-10-27).
- The running server tested by a client in Ernest, `libs/http` gaining a request's rendering and a response's head read (2026-10-27).
- The order of work: the report, the runtime, the libraries, an installation from the checkout, `ernest-httpd` and its deployment, then a release when the site is served (2026-10-27).
- Files under a root no one else writes: a path holding `..` refused, and no check of links, so the plan's `Fs.readUnder` waits for a root others can write (2026-10-26).
- The read-back's findings: the server's release 0.8.0 after the attached shell's 0.7.0; `encodeMasked` for a client with the caller's key; the example's shells ten at 128 MB as measured; the deploy hook copying the certificate and key to the server's user, and the unit's `ReadWritePaths` taking podman's directories; `Decoded` carrying the bytes after the frame; a folded header refused by its value; `Content-Length: 0` no body; `HEAD`'s length from its headers; the idle and head deadlines on two reads; `listenTls`'s `Other(text)`; stale alarms ignored; the backlog the host's; `fetch.ern` kept (2026-10-30).
