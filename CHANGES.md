# Changes

Each release's note, newest first, from 0.7.0 on: what the release is, what a program written for the release before changes, and each change in one line naming the section where it is read.

## 0.10.0, 2026-11-10

Ernest 0.10.0 is the release of what building and running ernest-httpd taught. A node lives at the host's limits, of processes, of ports and of open files, each request past a limit answered with the host's refusal. A qualified name resolves from the writer's namespace outward and is written in its shortest form. `kill` takes a `Process`. `Process.run` answers a worker's value or the reason it ended, and `Test.capture` what a run wrote. A program is started with its environment and its working directory, and sent a signal. Text is read from bytes that are not all UTF-8. `libs/uri` reads a URI reference, and `Http` reads a target and cookies and writes to a socket. A listener takes the largest backlog the host keeps. What the host logs goes to standard error. With it come the sentences of the report that were silent, and what was decided before the release.

A program written for 0.9.0 changes these things. Its modules are built again, since `ern run`, `ern test` and `Code.load` refuse a compiled form another build of `ern` wrote. A node of 0.10.0 and one of 0.9.0 do not connect, as two minor releases never do. `kill` takes a `Process` and `Process.kill` went, so a site that holds an address writes `kill(Process.fromAddress(worker))`. A qualified name is written in its shortest resolving form from its module's place: one written longer is refused, and its help writes the short one. No segment of a module's namespace is a taken one at any depth, so a module at `fides/io.ern` is renamed. `Os.Command` has `environment` and `workingDirectory`, so a command written whole names them, and `Os.command(program, arguments)` writes one with the defaults, updated with `..` for a field it sets.

`Http.ReadError` is `SocketError`. A pipe into a parenthesized pipe is a value applied, `x |> (a |> f)` being `f(a)(x)`, so a program that meant `f(x, a)` writes `x |> f(a)`. An `or` inside a pattern is refused, and the clause's alternatives are written out whole. A `receive` in the function given to `Test.faults`, where nothing fixed its mailbox type, is refused as a spawned function's is. `Terminal.subscribe` answers `Left(Other(text))` where the terminal's mode cannot be set, and a request of `Fs`, `Tcp`, `Os` or `Terminal` at a full table of processes answers `Left(Other("error:system_limit"))`. A job the hangup ends exits with 129, and one whose standard output or standard error can no longer be written with 141.

Until 1.0 a release may refuse a program the previous release accepted. The report of this release is what holds. What changed since 0.9.0 is the report's diff, `git diff v0.9.0 v0.10.0 -- report/`.

What changed:

### The language and the report

- A qualified name resolved from the writer's namespace outward, written in its shortest resolving form, and no segment of a module namespace a taken one at any depth: §4.2, §11.1, §11.5, Appendix F.
- `kill` taking a `Process`, and a `Process` the identity `kill` ends: §6.5, §6.9, §9.5, Appendix E.21.
- A pipe's right-hand side, and a lambda, an `if` or a pipe in parentheses a value applied: §5.7, §5.1, Appendix H.
- An `or` standing between a clause's whole patterns: §5.10, §11.5.
- A restart going on without a wrap the runtime has no room to apply: §6.9.
- A request a rule refuses faulting its process, a failure no request stands behind faulting the entry process, and a failure in the runtime faulting with the host's class and reason: §7.4.
- A refused load's values taken back, and a read of one faulting: §7.4, §11.2, Appendix E.28.
- The shell's code crossing to the node it attaches to as a program's does, and a top-level binding staying the node's: §4.6, §8.7, §11.2, §12.7.
- A value reclaimed in two generations, a waiting process collected where the host lets go a value it references, and what a `kill`, a wrap's delivery and a raise cost: §10.
- A wait of the node's own on what the host does not signal a time the report states: §0.
- A use site's qualified name in its shortest resolving form, and the root tie by the load path: §4.2.
- A patch release's floor stated once: §8.7, §12.5.
- The report's glossary: `authority`, `interrupt`, `percent-encoding`, `termination`, `URI reference`, and `segment` with TCP's: Appendix F.

### The toolchain and the shell

- A word of the command line that is not UTF-8 refused, and a `.erc` whose code the host will not load no compiled module, compiled again by a build and refused by a run: §11, §11.1, §11.2, Appendix E.28.
- What the host logs as a warning or worse written on standard error, and which of its reports are not written: §11, §11.2, §12.1.
- The cases a module is recompiled in, a qualified name that would resolve elsewhere among them: §11.1.
- `--verbose` of `ern run` and `ern test`: §11.2.
- An example's declarations the longest run of its first paragraphs that parses: §11.2.
- A node holding the shell of its own build from its start, and the shell's start line: §11.2.
- A load or an arrival past the host's limits ending the node with status 1: §11.2, §11.8.
- A reloaded module's two versions, and a peer finding a definition in the latest version whose bindings have their values: §11.2.
- `:processes` listing each process's memory: §11.2, Appendix E.21.
- The help lines for a name written longer than its shortest form, and for a root module a nearer one hides: §11.5.
- A type name printed plain where it is the module's own or the prelude's: §11.5.
- The formatter's rules for a line opening with a bracket or `else`, and for an item that opens a brace: §11.6.
- The statuses: the hangup's 129, a stream that is gone's 141, the shell's and an attached shell's: §11.8.
- The runtime's schedulers, the limit of open files, and what a run loads at its start: §12.
- Keys the host can no longer read ending the program by the hangup's signal, a subscription claiming the terminal as it is made and giving the claim back where it is refused, and the host's log handler writing through the job's standard output: §12.1.
- `limits` in `ernest.conf`, the node's limits of processes and ports, what a full table answers, a node that dials from a full table, the carrier's acceptor at the limit of open files, and what a node says: §12.5, Appendix C.
- The cookie on the node's command line: §12.5.
- A code frame carrying the host's module and function of each foreign declaration: §12.7.
- A `Segment`'s form, and a pipe's callee the right-hand side's head: Appendix H.

### The library

- `String.stripPrefix`, `String.stripSuffix`, `String.drop`, `Bytes.drop`: Appendix E.5, E.20.
- `String.fromUtf8Lossy` and `String.fromUtf8Piece`: Appendix E.5.
- `Process.run`, `Process.status`'s `memory`, `Process.live`'s processes, a waiting frame's line, and what `Process.faults` delivers: Appendix E.21.
- `Test.capture`, and `Test.faults` running its function as `Process.run` does, marked: Appendix E.24.
- `Os.command`, `Os.signal`, `Os.Command`'s `environment` and `workingDirectory`, a program found in the environment it starts with, a write after an exit no read has taken, and an empty `workingDirectory` `Invalid`: Appendix E.23.
- `Fs.makeTempDir`: Appendix E.17.
- `Json.encode`, and `format`'s order of an object's members: Appendix G.6.
- `libs/uri`, `Uri.parse`, `Uri.parseAuthority` and `Uri.decode`: Appendix G.12.
- `Http.target`, `Http.cookies`, `Http.cookie`, `Http.chunk`, `Http.writeRequest`, `Http.writeResponse`, `Http.writeChunk`, `Http.http11`, `Http.defaultLimits`, `SocketError`, and a head read on from the line under way: Appendix G.11, E.0 shape rule 11.
- `Code.running` finding the processes of a definition of `f`'s name whose mailbox type is `f`'s, on any version: Appendix E.28.
- `Code.load` answering `Left(Invalid)` for a `.erc` the host will not load: Appendix E.28.
- A listener's backlog, and what the kernel does past it: Appendix E.18.
- A socket's end at a full table, the host's TLS loaded as the host loads it, and a run's first request over TLS at a full table: Appendix E.18.
- `Float.atan2` at the origin: Appendix E.9.
- `Terminal.subscribe` where the host cannot serve it: Appendix E.16, §12.1.
- `Foreign.atom` past the host's atoms: Appendix E.12.
- `Supervisor`'s restart limit counted as `restarting` counts: Appendix E.22.
- A value the host gives once as the program starts a value, `Os.arguments`: Appendix E.0 shape rule 2.
- `Other(text)` holding a file of the host's own as the host writes it: Appendix E.1, E.18.
- The eleventh shape rule, a library's error that wraps `Io.Error`: Appendix E.0.

### The runtime

- A program's process group killed as the host reports its exit, before its outputs end: Appendix E.23.
- A restart ending the captures its run began, as the caller's end does, and a capture written back at the run's end: Appendix E.24, §8.6.
- A `receive` without an `after` the host's own, its waiting frame naming the last call before the wait: Appendix E.21.
- A socket's closer made with the socket, the gateway's worker as the connection opens, and a peer's restart waited for in the worker: §12.5, Appendix E.18.
- A stream that can no longer be written ending the program, by the hangup's signal where it was a terminal: §12.1, §11.8.

## 0.9.0, 2026-11-03

Ernest 0.9.0 is the release of the first program built against an installed Ernest by a repository of its own: ernest-httpd, which serves ernest-lang.org over TLS, and what it asked of Ernest on its way, TLS in `Tcp`, a program under a pseudo-terminal in `Os`, and four libraries, `base64`, `crypto`, `time` and `http`. With it come a constructor shown with its module's name, a read given no time that has run out as it begins, and sentences of the report where it was silent.

A program written for 0.8.0 changes these things. Its modules are built again, since `ern run`, `ern test` and `Code.load` refuse a compiled form another build of `ern` wrote. A node of 0.9.0 and one of 0.8.0 do not connect, as two minor releases never do. `Io.show` writes a constructor outside the prelude with its module's name, `Io.Timeout` for what was `Timeout`, so a program that reads `show`'s text, or a test that compares against it, sees the name. `Tcp.read` and `Os.read` given no time answer `Left(Timeout)` whatever has arrived, as every wait does; a poll gives them a millisecond.

`Json.parse`'s `UnexpectedByte` and `UnexpectedSequence` carry where they begin, `at = Position(line, column)`, and the sequence is a `String`. `Http.render` is `Http.renderResponse`, `Time.civil` is `Time.toCivil`, and `Time.weekday` takes a `Civil`. A module named `ernest.ern`, or under `ernest/`, is refused, the namespace being the toolchain's own. A clause whose guard is the literal `false` is refused as a redundant clause.

Until 1.0 a release may refuse a program the previous release accepted. The report of this release is what holds. What changed since 0.8.0 is the report's diff, `git diff v0.8.0 v0.9.0 -- report/`.

What changed:

### The language and the report

- `Ernest` a taken namespace, the shell standing under it as `Ernest.Shell`: §4.2, §11.1, §12.7.
- A clause whose guard is the literal `false` redundant: §5.9.
- The caller of `Os.exit` neither told nor waited for, a termination once the end has begun cutting the wait short, and a program under a terminal counting as a computation: §8.6.
- A value reclaimed by its process's collection, in the host's two generations: §10.
- An archive's version text naming its commit: §11.7.
- A listener's family, and a node's: §12.5, Appendix E.18.
- The toolchain's own units listed, and an attach refused by a node that could not load them: §11.2, §12.7.

### The toolchain and the shell

- An IPv4-mapped `listen` refused by `ern config` and the node: §12.5.
- `ernest.pid` made for its owner alone, and `ern stop` and `ern reload` checking the directory as the node does: §12.5.
- The shell's modules under `src/shell/ernest/`, `Ernest.Shell`: §11.2.

### The library

- `Tcp.listenTls` and `Tcp.connectTls`, one socket over TLS or not, `Verified(caFile)` and `Unverified`: Appendix E.18.
- `Os.startTerminal`, `Os.resize`, `closeInput` as a hangup, a program's process living on after its exit, `Os.user`, `Os.exit`'s caller: Appendix E.23.
- `Tcp.write` as the host's send, the endpoints of a closed connection, a read or an accept whose caller ended: Appendix E.18.
- `libs/base64`, `libs/crypto`, `libs/time` and `libs/http`: Appendix G.8 to G.11.
- `Json`'s errors carrying a `Position`, a broken literal or escape named at the byte that breaks it, and a too-long number found in one pass: Appendix G.6.
- `Io.show` writing a constructor outside the prelude with its module's name: Appendix E.1.
- A read given no time having run out as it begins, in `Tcp` and `Os` as everywhere: Appendix E.0 shape rule 8, E.18.
- `Fs.setMode`, a path through a file, a loop of links and a long name: Appendix E.17.
- `Io.writeError`, `Terminal.width`, `Supervisor.child`, `Random.nextFloat`'s bounds: Appendix E.1, E.19, E.21, E.12.
- `Path.join` writing its segments as given: Appendix E.14.
- `Http`'s response readers reading a fold and a body to the close as RFC 9112 has a client read them, its renderers faulting on a value that would break the message, a status of three digits, one empty line before a request skipped: Appendix G.11.

### The runtime

- A program's process group killed when the program is reaped, a pinned certificate taken sent alone or at a chain's end, and a CA file read before the dial: Appendix E.23, E.18.
- A fault's trace keeping its callers' frames, which the host's type pass had cut: §7.3, Appendix E.21.
- `ernest.pid` made for its owner alone, and a termination once the end has begun cutting the wait short: §12.5, §8.6.
- `resize` answering `Closed` after the exit or the hangup: Appendix E.23.
- A load's evaluator counting a running program and an open connection only: Appendix E.28.

## 0.8.0, 2026-11-01

Ernest 0.8.0 is the release of the pun: a field given or matched by the variable of its own name is written once, `Desk(=local)`. With it come a `receive` that always receives, with `Clock.sleep` as the one wait for a time, an alarm that can be canceled, a `receive` guard that reads a field, and a doc example run at its own mailbox type.

A program written for 0.7.0 changes these things. Its modules are built again, since `ern run`, `ern test` and `Code.load` refuse a compiled form another build of `ern` wrote. A node of 0.8.0 and one of 0.7.0 do not connect, as two minor releases never do. A `receive` with an `after` clause alone is refused and is written `Clock.sleep(ms)`; a function that waited so receives nothing now, and a `receiving e` written on it is refused. `Clock.alarm` and `Clock.alarmAt` answer an `Alarm`, so a site that drops it writes `let _ =`. A request whose only field is its reply is declared positional and passed to `Address.call` bare, which the style asks for and the style test holds, as it holds the pun.

Until 1.0 a release may refuse a program the previous release accepted. The report of this release is what holds. What changed since 0.7.0 is the report's diff, `git diff v0.7.0 v0.8.0 -- report/`.

What changed:

### The language and the report

- The pun, `=f` for `f = f`, in a construction, an update, a fill and a pattern: §5.6, §5.10, Appendix A.
- Principle 2's sentence admitting a field paired with the name that gives or binds it: §0.
- A `receive` always receives, `Clock.sleep` the one wait for a time, a `Never` body sleeping: §3.9, §4.6, §6.3, §6.8, Appendix A.
- A guard reading a field selected from a variable in scope or a top-level `let`: §6.3.
- `Alarm` bound to its node, with the runtime's equality, a resource: §3.10, §3.11.
- A restart and a foreign fault reaching a sleep and a load's wait: §6.9, §8.4.
- A wait in a function the runtime applies being the applying process's own: §6.5, §6.9.
- A sleep's cost growing with the messages waiting: §10.
- What a load's undoing kills having ended before the load answers: Appendix E.28.
- Appendix D written whole, with `made`, `owned` and `contains`: Appendix D.

### The toolchain and the shell

- A doc example running at the mailbox type of its function, and shape rule 6's one test for one that stays compiled: §11.2, Appendix E.0.
- The help for a `receive` with an `after` clause alone naming `Clock.sleep`: §6.3, §11.5.
- The shell's line at a binding's end naming the site alone: §11.2.
- The style test refusing `f = f` and a one-field request with a named reply: `guide/style.md`.

### The library

- `Clock.sleep`: Appendix E.15.
- `Clock.Alarm` and `Clock.cancel`, `alarm` and `alarmAt` answering an `Alarm`: Appendix E.15.
- `Utilization.schedulers` receiving nothing: Appendix G.4.
- `Receiving` covering a process in `Clock.sleep`: Appendix E.21.
- Nine examples of the library showing their values, the clock's among them: Appendix E.0.

### The runtime

- `Clock.sleep` holding the timed mark, a restart asked for and a fault in the mailbox reaching it: §6.9, Appendix E.15.
- An alarm canceled by any process of its node, and ending with its setter's restart: Appendix E.15.

## 0.7.0, 2026-10-31

Ernest 0.7.0 is the release of a shell attached to a running node: `ern shell --config-dir dir --attach name` runs each input on a listed peer, lists its processes and loads and reloads its modules, while the operator's machine keeps the terminal and the files. It also brings the report pared to the language, with the runtime's mechanism a chapter of its own.

A program written for 0.6.0 changes these things. Its modules are built again, since `ern run`, `ern test` and `Code.load` refuse a compiled form another build of `ern` wrote. A node of 0.7.0 and one of 0.6.0 do not connect, as two minor releases never do; a configuration directory 0.6.0 made serves as it is, but `ern config` now writes a `listen` only with `--listen`, so a directory that peers must reach is made with it.

`ern test` exits with status 1 where a process faulted during the run, a service binding starting under it as under `ern run`. A node whose carrier cannot start ends as a job that cannot start, with status 1 and no fault. In a shell, `Os.exit` faults a process an input started, a site carries its session's namespace, `let p <- e` is taken at the prompt, and `:quit` leaves an attached shell with its node running on. `restarting` called in a function the runtime applies faults, and a foreign function typed by its callback receives through it alone. Four library functions are new, each marked `since 0.7.0`.

Until 1.0 a release may refuse a program the previous release accepted. The report of this release is what holds. What changed since 0.6.0 is the report's diff, `git diff v0.6.0 v0.7.0 -- report/`.

What changed:

### The language and the report

- The runtime's mechanism in chapter 12, §10 in `toolchain.md`: §10, §12.
- The `Peer` functions' contracts under E.27: Appendix E.27.
- §12.1's keys and §12.3's causes binding every runtime: §12.
- A restart in a function the runtime applies refused: §6.9, §7.4.
- A foreign function typed by its callback receiving through it alone: §4.7.
- A deadlock while a load's evaluator waits faulting the evaluator: §8.6.
- A session's namespace carrying its number, and on a node the node's key: Appendix H.
- An address the permission to send, a `Process` what `Process.kill` ends: §6.5.

### The toolchain and the shell

- The attached shell, `ern shell --attach name`: §11.2 *The attached shell*, §11.7, §11.8.
- The attach waiting twice a dial's time: §11.2.
- Sessions numbered, a site carrying its session's namespace: §11.2 *Faults*, *Startup and history*.
- A reload said at every session's prompt: §11.2 *The attached shell*.
- `:quit` leaving every shell, `:detach` none: §11.2 *Commands*.
- `:processes` with each process's activity: §11.2 *Commands*.
- A binding input's process living while its name is in scope, and what it owned said at its end: §11.2 *Inputs*.
- `let p <- e` at the prompt, and `it` after a `Left`: §11.2 *Inputs*.
- A prompt's binding read on the session's node: §11.2 *Inputs*.
- An expression's input one unit, an input's cost flat in the session: §11.2 *Inputs*.
- A load evaluating in an evaluator that ends with its work: §11.2 *Loading and reloading*.
- A compiled form taken by `:load` judged by its source's digest: §11.2 *Loading and reloading*.
- `:doc` documenting the code the node loaded: §11.2 *Commands*.
- `Os.exit` by session, and from the shell's own code ending the shell: §11.2, Appendix E.23.
- `ern config` without `--listen` writing no `listen`: §11.3.
- A carrier that cannot start refusing the job, an end of the program with its subscribers told: §12.5, §8.6, §11.8.
- The protocol's version moving at a release whose frames differ: §12.5.
- `ern test` red where a process faulted, and a service binding started under it: §11.2, §11.8.
- `ern run` and `ern test` refusing a compiled form another build wrote: §11.2.
- A private function or binding refused as private: §11.5.
- A field read in a `receive` guard answered with a help naming the `let` before the `receive`: §6.3.
- A block's `let` whose initializer names its own name reported as a cycle: §4.6.
- A standard library shim called as the host's function at the call site: §11.1.
- Each initializer a function of its own, and the build's cost linear in its functions: §11.1.

### The library

- `Process.kill`: Appendix E.21.
- `Process.owned` and `Ets.owned`: Appendix E.21, G.1.
- `Test.until`, yielding between its runs: Appendix E.24, E.0 shape rule 8.
- `Code.load` evaluating in an evaluator, the load undone where its caller ends while it waits: Appendix E.28.
- `Process.live` and `Process.faults` leaving sessions' own processes, evaluators and a process that has ended out: Appendix E.21.
- A shim's raise traced from the caller's line: Appendix E.21.
- `Peer.compute` never drawing an attached shell's own node: Appendix E.27.

### The runtime

- A session's screen, a write going to its writer's session: §12.1.
- The toolchain's own units loaded from the node's tree, the frame saying whose a unit is: §12.6, §12.7.
- An attached shell's own node telling no utilization and saying nothing of its session's node: §12.5, E.27.
- A detached session's units that declare a function kept for the node's life: §11.2 *What a node holds*.
- An attached shell's last lines on rows of their own, and a shell's end losing none: §11.2.
