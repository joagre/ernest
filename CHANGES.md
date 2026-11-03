# Changes

Each release's note, newest first, from 0.7.0 on: what the release is, and each change in one line naming where it is read.

## 0.9.0, 2026-11-03

Ernest 0.9.0 is the release of the first program built against an installed Ernest by a repository of its own: ernest-httpd, which serves ernest-lang.org over TLS since 2026-11-02, and what it asked of Ernest on its way, TLS in `Tcp`, a program under a pseudo-terminal in `Os`, four libraries, `base64`, `crypto`, `time` and `http`, and seventeen lines of feedback decided the days they came. With it come what the release review before it decided, a constructor shown with its module's name, a read given no time that has run out as it begins, and the report's sentences for every silence its readers found.

A program written for 0.8.0 changes these things. Its modules are built again, since `ern run`, `ern test` and `Code.load` refuse a compiled form another build of `ern` wrote. A node of 0.9.0 and one of 0.8.0 do not connect, as two minor releases never do. `Io.show` writes a constructor outside the prelude with its module's name, `Io.Timeout` for what was `Timeout`, so a program that reads `show`'s text, or a test that compares against it, sees the name. `Tcp.read` and `Os.read` given no time answer `Left(Timeout)` whatever has arrived, as every wait does; a poll gives them a millisecond.

`Json.parse`'s `UnexpectedByte` and `UnexpectedSequence` carry where they begin, `at = Position(line, column)`, and the sequence is a `String`. `Http.render` is `Http.renderResponse`, `Time.civil` is `Time.toCivil`, and `Time.weekday` takes a `Civil`. A module named `ernest.ern`, or under `ernest/`, is refused, the namespace being the toolchain's own. A clause whose guard is the literal `false` is refused as a redundant clause.

Until 1.0 a release may refuse a program the previous release accepted, as the plan says. The report of this release is what holds. What changed since 0.8.0 is the report's diff, `git diff v0.8.0 v0.9.0 -- report/`, and why is the decision log's entries after *The Release Review Before 0.8.0* in `docs/log.md`.

What changed:

### The language and the report

- `Ernest` a taken namespace, the shell standing under it as `Ernest.Shell`: §4.2, §11.1, §12.7; the log's *Four Lines From the Deployment*.
- A clause whose guard is the literal `false` redundant: §5.9; *The Release Review Before 0.8.0*.
- The caller of `Os.exit` neither told nor waited for, a termination once the end has begun cutting the wait short, and a program under a terminal counting as a computation: §8.6; *A Program After Its Exit*, *The Release Review Before 0.9.0*.
- A value reclaimed by its process's collection, in the host's two generations: §10; *Four Lines From the Deployment*, *The Release Review Before 0.9.0*.
- An archive's version text naming its commit: §11.7; *An Archive Says Its Commit*.
- A listener's family, and a node's: §12.5, Appendix E.18; *Four Lines From the Deployment*.
- The toolchain's own units listed, and an attach refused by a node that could not load them: §11.2, §12.7; *Four Lines From the Deployment*, *The Release Review Before 0.9.0*.

### The toolchain and the shell

- An IPv4-mapped `listen` refused by `ern config` and the node: §12.5; *The Release Review Before 0.9.0*.
- `ernest.pid` made for its owner alone, and `ern stop` and `ern reload` checking the directory as the node does: §12.5; *The Release Review Before 0.9.0*.
- The shell's modules under `src/shell/ernest/`, `Ernest.Shell`: §11.2; *Four Lines From the Deployment*.
- The terminal tests' harness an Ernest program over `Os.startTerminal`: *The Harness in Ernest*.

### The library

- `Tcp.listenTls` and `Tcp.connectTls`, one socket over TLS or not, `Verified(caFile)` and `Unverified`: Appendix E.18; *TLS in `Tcp` and a Terminal in `Os`*, *Two Lines on TLS*.
- `Os.startTerminal`, `Os.resize`, `closeInput` as a hangup, a program's process living on after its exit, `Os.user`, `Os.exit`'s caller: Appendix E.23; *TLS in `Tcp` and a Terminal in `Os`*, *A Program After Its Exit*, *The Hangup's Order*.
- `Tcp.write` as the host's send, the endpoints of a closed connection, a read or an accept whose caller ended: Appendix E.18; *A Close, an Exit and a Write*, *Three Flakes Read*.
- `libs/base64`, `libs/crypto`, `libs/time` and `libs/http`: Appendix G.8 to G.11; *The Four Libraries*.
- `Json`'s errors carrying a `Position`, a broken literal or escape named at the byte that breaks it, and a too-long number found in one pass: Appendix G.6; *The Error's Place*, *The Release Review Before 0.9.0*.
- `Io.show` writing a constructor outside the prelude with its module's name: Appendix E.1; *The Release Review Before 0.9.0*.
- A read given no time having run out as it begins, in `Tcp` and `Os` as everywhere: Appendix E.0 shape rule 8, E.18; *The Release Review Before 0.9.0*.
- `Fs.setMode`, a path through a file, a loop of links and a long name: Appendix E.17; *A Path Through a File*.
- `Io.writeError`, `Terminal.width`, `Supervisor.child`, `Random.nextFloat`'s bounds: Appendix E.1, E.19, E.21, E.12; *Three Lines From the Server*.
- `Path.join` writing its segments as given: Appendix E.14; *A Path Through a File*.
- `Http`'s response readers reading a fold and a body to the close as RFC 9112 has a client read them, its renderers faulting on a value that would break the message, a status of three digits, one empty line before a request skipped: Appendix G.11; *The Release Review Before 0.9.0*.

### The runtime

- A program's process group killed when the program is reaped, a pinned certificate taken sent alone or at a chain's end, and a CA file read before the dial: Appendix E.23, E.18; *The Release Review Before 0.9.0*.
- A fault's trace keeping its callers' frames, which the host's type pass had cut: §7.3, Appendix E.21; *The Release Review Before 0.9.0*.
- `ernest.pid` made for its owner alone, and a termination once the end has begun cutting the wait short: §12.5, §8.6; *The Release Review Before 0.9.0*.
- `resize` answering `Closed` after the exit or the hangup: Appendix E.23; *The Release Review Before 0.9.0*.
- A load's evaluator counting a running program and an open connection only: Appendix E.28; *The Release Review Before 0.9.0*.

What the review did not run: the service manager's checks under launchd, since no Mac was at hand; on macOS the archive is expected to work and is not yet verified.

The newcomer's program is `pindex`, a parallel inverted-index builder in four modules of 409 lines: a crawler runs a monitored worker for each file, at most a given number at once, an index process keeps each word's files and answers lookups by a call, the index is written to a file and renamed over it, and the command line answers a word a line from standard input with the files it is in; its tests cover the tokenizer, the index, a killed index and a crawl with an unreadable and a broken file. It built at the first try, its nine tests passed, and it ran; it is published beside the archive.

## 0.8.0, 2026-11-01

Ernest 0.8.0 is the release of the pun: a field given or matched by the variable of its own name is written once, `Desk(=local)`. With it come what its day decided, a `receive` that always receives with `Clock.sleep` as the one wait for a time, an alarm that can be canceled, a `receive` guard that reads a field, a doc example run at its own mailbox type, and what the release review before it decided. Its row in the plan is https://github.com/joagre/ernest/blob/v0.8.0/docs/plan.md, and what Ernest is and why is https://github.com/joagre/ernest/blob/v0.8.0/guide/why.md.

A program written for 0.7.0 changes these things. Its modules are built again, since `ern run`, `ern test` and `Code.load` refuse a compiled form another build of `ern` wrote. A node of 0.8.0 and one of 0.7.0 do not connect, as two minor releases never do. A `receive` with an `after` clause alone is refused and is written `Clock.sleep(ms)`; a function that waited so receives nothing now, and a `receiving e` written on it is refused. `Clock.alarm` and `Clock.alarmAt` answer an `Alarm`, so a site that drops it writes `let _ =`. A request whose only field is its reply is declared positional and passed to `Address.call` bare, which the style asks for and the style test holds, as it holds the pun.

Until 1.0 a release may refuse a program the previous release accepted, as the plan says. The report of this release is what holds. What changed since 0.7.0 is the report's diff, `git diff v0.7.0 v0.8.0 -- report/`, and why is the decision log's entries after *The Release Review Before 0.7.0* in `docs/log.md`.

What changed:

### The language and the report

- The pun, `=f` for `f = f`, in a construction, an update, a fill and a pattern: §5.6, §5.10, Appendix A; the log's *The Pun*.
- Principle 2's sentence admitting a field paired with the name that gives or binds it: §0; *The Pun*, *The Release Review Before 0.8.0*.
- A `receive` always receives, `Clock.sleep` the one wait for a time, a `Never` body sleeping: §3.9, §4.6, §6.3, §6.8, Appendix A; *A `receive` Always Receives*.
- A guard reading a field selected from a variable in scope or a top-level `let`: §6.3; *The Pun's Opening Round*.
- `Alarm` bound to its node, with the runtime's equality, a resource: §3.10, §3.11; *An Alarm Can Be Canceled*.
- A restart and a foreign fault reaching a sleep and a load's wait: §6.9, §8.4; *The Release Review Before 0.8.0*.
- A wait in a function the runtime applies being the applying process's own: §6.5, §6.9; *The Release Review Before 0.8.0*.
- A sleep's cost growing with the messages waiting: §10; *The Release Review Before 0.8.0*.
- What a load's undoing kills having ended before the load answers: Appendix E.28; *`make version`, Appendix D Whole, the Settler's Restart*.
- Appendix D written whole, with `made`, `owned` and `contains`: Appendix D; *`make version`, Appendix D Whole, the Settler's Restart*.

### The toolchain and the shell

- A doc example running at the mailbox type of its function, and shape rule 6's one test for one that stays compiled: §11.2, Appendix E.0; *Ernest 0.8.0, a Small Release*.
- The help for a `receive` with an `after` clause alone naming `Clock.sleep`: §6.3, §11.5; *A `receive` Always Receives*.
- The shell's line at a binding's end naming the site alone: §11.2; *The Pun's Opening Round*.
- The style test refusing `f = f` and a one-field request with a named reply: `guide/style.md`; *The Pun*, *Ernest 0.8.0, a Small Release*.
- `make version V=x.y.z`, with `VERSION` naming the release the checkout works toward: `docs/release_review.md`; *`make version`, Appendix D Whole, the Settler's Restart*.

### The library

- `Clock.sleep`: Appendix E.15; *A `receive` Always Receives*.
- `Clock.Alarm` and `Clock.cancel`, `alarm` and `alarmAt` answering an `Alarm`: Appendix E.15; *An Alarm Can Be Canceled*.
- `Utilization.schedulers` receiving nothing: Appendix G.4; *The Pun's Opening Round*.
- `Receiving` covering a process in `Clock.sleep`: Appendix E.21; *The Release Review Before 0.8.0*.
- Nine examples of the library showing their values, the clock's among them: Appendix E.0; *Ernest 0.8.0, a Small Release*.

### The runtime

- `Clock.sleep` holding the timed mark, a restart asked for and a fault in the mailbox reaching it: §6.9, Appendix E.15; *A `receive` Always Receives*.
- An alarm canceled by any process of its node, and ending with its setter's restart: Appendix E.15; *An Alarm Can Be Canceled*.

What the review did not run: the service manager's checks under launchd, since no Mac was at hand; on macOS the archive is expected to work and is not yet verified. `make sanitize` was not run, the helper being unchanged since 0.7.0.

The newcomer's program is `scheduler`, a job scheduler in two modules of 335 lines: a scheduler process runs at most `capacity` jobs at once, each in a monitored worker under a deadline by `Clock.alarm`, kills a worker that overruns and retries a failed job up to its attempts, keeping a caller's `Reply` until the job ends; the command line takes jobs as `name=sleep/ms|sum/n|fail/text`. Beside the archive as `scheduler.ern` and `jobs.ern`: `ern build --build-root build .` in their directory, then `ern test build/scheduler.erc`, then `ern run build/jobs.erc nap=sleep/300 add=sum/100 slow=sleep/2000 bad=fail/boom quick=sleep/100`.

## 0.7.0, 2026-10-31

Ernest 0.7.0 is the release of a shell attached to a running node: `ern shell --config-dir dir --attach name` runs each input on a listed peer, lists its processes and loads and reloads its modules, while the operator's machine keeps the terminal and the files. It also brings the report pared to the language, with the runtime's mechanism a chapter of its own, and what the release review before it decided. Its row in the plan is https://github.com/joagre/ernest/blob/v0.7.0/docs/plan.md, and what Ernest is and why is https://github.com/joagre/ernest/blob/v0.7.0/guide/why.md.

A program written for 0.6.0 changes these things. Its modules are built again, since `ern run`, `ern test` and `Code.load` refuse a compiled form another build of `ern` wrote. A node of 0.7.0 and one of 0.6.0 do not connect, as two minor releases never do; a configuration directory 0.6.0 made serves as it is, but `ern config` now writes a `listen` only with `--listen`, so a directory that peers must reach is made with it.

`ern test` exits with status 1 where a process faulted during the run, a service binding starting under it as under `ern run`. A node whose carrier cannot start ends as a job that cannot start, with status 1 and no fault. In a shell, `Os.exit` faults a process an input started, a site carries its session's namespace, `let p <- e` is taken at the prompt, and `:quit` leaves an attached shell with its node running on. `restarting` called in a function the runtime applies faults, and a foreign function typed by its callback receives through it alone. Four library functions are new, each marked `since 0.7.0`.

Until 1.0 a release may refuse a program the previous release accepted, as the plan says. The report of this release is what holds. What changed since 0.6.0 is the report's diff, `git diff v0.6.0 v0.7.0 -- report/`, and why is the decision log's entries after *The Release Review Before 0.6.0* in `docs/log.md`.

What changed:

### The language and the report

- The runtime's mechanism in chapter 12, §10 in `toolchain.md`: §10, §12; the log's *The Report Pared, Built*.
- The `Peer` functions' contracts under E.27: Appendix E.27; *The Second Cut, §8.7 to E.27*.
- §12.1's keys and §12.3's causes binding every runtime: §12; *The Argument's Four Decisions*.
- A restart in a function the runtime applies refused: §6.9, §7.4; *The Argument's Four Decisions*.
- A foreign function typed by its callback receiving through it alone: §4.7; *The Argument's Four Decisions*.
- A deadlock while a load's evaluator waits faulting the evaluator: §8.6; *The Argument's Four Decisions*.
- A session's namespace carrying its number, and on a node the node's key: Appendix H; *The Attached Shell's Sentences*, *Sites, Sessions and Their Names*.
- An address the permission to send, a `Process` what `Process.kill` ends: §6.5; *Reload, Services and Tests*.
- The report's paragraphs, none past 150 words: the log's *The Report Pared, Built*.

### The toolchain and the shell

- The attached shell, `ern shell --attach name`: §11.2 *The attached shell*, §11.7, §11.8; *The Attached Shell's Cut*, *The Attached Shell's Sentences*, *The Attached Shell, Built*, *The Attached Shell, Tested*.
- The attach waiting twice a dial's time: §11.2; *The Shell's Own Node*.
- Sessions numbered, a site carrying its session's namespace: §11.2 *Faults*, *Startup and history*; *Sites, Sessions and Their Names*.
- A reload said at every session's prompt: §11.2 *The attached shell*; *Sites, Sessions and Their Names*.
- `:quit` leaving every shell, `:detach` none: §11.2 *Commands*; *One Word to Leave*.
- `:processes` with each process's activity: §11.2 *Commands*; *The Shell's Second Round, Decided Again*.
- A binding input's process living while its name is in scope, and what it owned said at its end: §11.2 *Inputs*; *The Shell's Second Round, Decided Again*, *The Input's Process*.
- `let p <- e` at the prompt, and `it` after a `Left`: §11.2 *Inputs*; *`<-` at the Prompt*, *The Input's Process*.
- A prompt's binding read on the session's node: §11.2 *Inputs*; *The Input's Process*.
- An expression's input one unit, an input's cost flat in the session: §11.2 *Inputs*; *A Line-Mode Input's Cost*, *An Expression's One Unit, and an Input's Cost Flat*.
- A load evaluating in an evaluator that ends with its work: §11.2 *Loading and reloading*; *The Argument's Four Decisions*, *Sites, Sessions and Their Names*.
- A compiled form taken by `:load` judged by its source's digest: §11.2 *Loading and reloading*; *The Release Review's Code Fixes*.
- `:doc` documenting the code the node loaded: §11.2 *Commands*; *The Claims, the README and the Tour*.
- `Os.exit` by session, and from the shell's own code ending the shell: §11.2, Appendix E.23; *The Attached Shell's Sentences*, *The Library's Lines*.
- `ern config` without `--listen` writing no `listen`: §11.3; *The Shell's Own Node*.
- A carrier that cannot start refusing the job, an end of the program with its subscribers told: §12.5, §8.6, §11.8; *The Shell's Own Node*, *The Release Review Before 0.7.0*.
- The protocol's version moving at a release whose frames differ: §12.5; *The Release Review Before 0.7.0*.
- `ern test` red where a process faulted, and a service binding started under it: §11.2, §11.8; *Reload, Services and Tests*.
- `ern run` and `ern test` refusing a compiled form another build wrote: §11.2; *One Function per Initializer*.
- A private function or binding refused as private: §11.5; *The Claims, the README and the Tour*.
- A field read in a `receive` guard answered with a help naming the `let` before the `receive`: §6.3; *The Release Review's Code Fixes*.
- A block's `let` whose initializer names its own name reported as a cycle: §4.6.
- A standard library shim called as the host's function at the call site: §11.1; *The Emitter's Calls Against the Host's, Built*.
- Each initializer a function of its own, and the build's cost linear in its functions: §11.1; *The Build's Cost per Function*, *One Function per Initializer*.

### The library

- `Process.kill`: Appendix E.21; *Reload, Services and Tests*.
- `Process.owned` and `Ets.owned`: Appendix E.21, G.1; *The Input's Process*.
- `Test.until`, yielding between its runs: Appendix E.24, E.0 shape rule 8; *What the Newcomer's Feedback Left*, *`Test.until`, Built*, *The Library's Lines*.
- `Code.load` evaluating in an evaluator, the load undone where its caller ends while it waits: Appendix E.28; *The Argument's Four Decisions*, *Sites, Sessions and Their Names*, *The Release Review Before 0.7.0*.
- `Process.live` and `Process.faults` leaving sessions' own processes, evaluators and a process that has ended out: Appendix E.21; *The Session's Screen and the Toolchain's Units, Built*, *Sites, Sessions and Their Names*.
- A shim's raise traced from the caller's line: Appendix E.21; *The Emitter's Calls Against the Host's, Built*, *The Release Review's Code Fixes*.
- `Peer.compute` never drawing an attached shell's own node: Appendix E.27; *The Attached Shell's Own Node, Quiet*.

### The runtime

- A session's screen, a write going to its writer's session: §12.1; *The Session's Screen and the Toolchain's Units, Built*.
- The toolchain's own units loaded from the node's tree, the frame saying whose a unit is: §12.6, §12.7; *The Session's Screen and the Toolchain's Units, Built*, *The Shell's Own Node*.
- An attached shell's own node telling no utilization and saying nothing of its session's node: §12.5, E.27; *The Attached Shell's Own Node, Quiet*.
- A detached session's units that declare a function kept for the node's life: §11.2 *What a node holds*; *The Detach Keeps What Declares a Function*.
- An attached shell's last lines on rows of their own, and a shell's end losing none: §11.2; *The Attached Shell's Last Row*, *The End's Lines Reach the Screen*.

What the review did not run: the service manager's checks under launchd, since no Mac was at hand; on macOS the archive is expected to work and is not yet verified.

The newcomer's program is `auction`, an auction house whose house process opens lots and takes bids by a call, and sells each lot to its highest bidder at its deadline, writing the sale to a ledger; one module beside the archive: `ern build auction.ern && ern test auction.erc`, then `ern run auction.erc demo`, where three robots bid for two lots. Run as a node with `--config-dir`, the house takes lots and bids from an attached shell's prompt, `Auction.open("a lamp", 10, 60)`, its ledger `sales.log` in the node's working directory.
